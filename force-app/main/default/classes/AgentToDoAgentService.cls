/**
 * AgentToDo LWC 대화 패널과 Agentforce Agent API 사이의 연결 계층.
 *
 * 호출 경로:
 *   agentAssistantDrawer (LWC)
 *     → AgentToDoAgentService (이 클래스)
 *       → Named Credential: AgentToDo_Agent_API
 *         → External Credential (OAuth 2.0 · Client Credentials)
 *           → External Client App (Run As: 남 경태)
 *             → https://api.salesforce.com/einstein/ai-agent/v1
 *
 * 스트리밍 엔드포인트(/messages/stream, SSE)는 Apex 콜아웃으로 다루기 어려워
 * 동기 엔드포인트를 사용합니다.
 */
public with sharing class AgentToDoAgentService {
  private static final String AGENT_DEVELOPER_NAME = 'AgentToDo_Svc_Assistant';
  private static final String BASE = 'callout:AgentToDo_Agent_API/einstein/ai-agent/v1';

  /** Agent API 상한이 120초입니다. 그보다 짧게 잡으면 긴 추론에서 잘립니다. */
  private static final Integer TIMEOUT_MS = 120000;

  @TestVisible
  private static Id cachedAgentId;

  public class AgentServiceException extends Exception {
  }

  // ─────────────────────────────────────────────────────────────
  // DTO
  // ─────────────────────────────────────────────────────────────

  public class AgentAction {
    @AuraEnabled
    public String name;
    @AuraEnabled
    public String detail;
  }

  public class AgentReply {
    @AuraEnabled
    public String sessionId;
    @AuraEnabled
    public String message;
    @AuraEnabled
    public List<AgentAction> actions;
    @AuraEnabled
    public Boolean success;
    @AuraEnabled
    public String errorMessage;
  }

  // ─────────────────────────────────────────────────────────────
  // 공개 API
  // ─────────────────────────────────────────────────────────────

  /** 새 대화 세션을 열고 에이전트의 환영 메시지를 반환합니다. */
  @AuraEnabled
  public static AgentReply startSession() {
    try {
      Map<String, Object> body = new Map<String, Object>{
        'externalSessionKey' => newSessionKey(),
        'instanceConfig' => new Map<String, Object>{
          'endpoint' => URL.getOrgDomainUrl().toExternalForm()
        },
        'streamingCapabilities' => new Map<String, Object>{
          'chunkTypes' => new List<String>{ 'Text' }
        },
        // 서비스 에이전트지만 전용 사용자가 아니라 토큰의 Run As 사용자로 실행해야
        // 실제 일정 소유자의 데이터를 다룰 수 있습니다.
        'bypassUser' => false
      };

      HttpResponse res = send(
        'POST',
        '/agents/' + resolveAgentId() + '/sessions',
        body,
        null
      );
      if (res.getStatusCode() != 200) {
        return failure(
          null,
          describeHttpError('세션을 시작하지 못했습니다', res)
        );
      }

      Map<String, Object> parsed = (Map<String, Object>) JSON.deserializeUntyped(
        res.getBody()
      );
      AgentReply reply = toReply(parsed);
      reply.sessionId = (String) parsed.get('sessionId');
      return reply;
    } catch (Exception e) {
      return failure(null, '세션을 시작하지 못했습니다: ' + e.getMessage());
    }
  }

  /**
   * 사용자 발화를 에이전트에 전달하고 응답을 반환합니다.
   * sequenceId 는 세션 내에서 1부터 증가하는 값이며 호출자가 관리합니다.
   */
  @AuraEnabled
  public static AgentReply sendMessage(
    String sessionId,
    Integer sequenceId,
    String text
  ) {
    if (String.isBlank(sessionId)) {
      return failure(null, '세션이 없습니다. 대화를 다시 시작해 주세요.');
    }
    if (String.isBlank(text)) {
      return failure(sessionId, '보낼 메시지가 비어 있습니다.');
    }

    try {
      Map<String, Object> body = new Map<String, Object>{
        'message' => new Map<String, Object>{
          'sequenceId' => (sequenceId == null ? 1 : sequenceId),
          'type' => 'Text',
          'text' => text
        }
      };

      HttpResponse res = send(
        'POST',
        '/sessions/' + sessionId + '/messages',
        body,
        null
      );
      if (res.getStatusCode() != 200) {
        return failure(
          sessionId,
          describeHttpError('응답을 받지 못했습니다', res)
        );
      }

      AgentReply reply = toReply(
        (Map<String, Object>) JSON.deserializeUntyped(res.getBody())
      );
      reply.sessionId = sessionId;
      return reply;
    } catch (Exception e) {
      return failure(sessionId, '응답을 받지 못했습니다: ' + e.getMessage());
    }
  }

  /** 세션을 종료합니다. 실패해도 화면 동작을 막지 않도록 예외를 던지지 않습니다. */
  @AuraEnabled
  public static void endSession(String sessionId) {
    if (String.isBlank(sessionId)) {
      return;
    }
    try {
      send(
        'DELETE',
        '/sessions/' + sessionId,
        null,
        new Map<String, String>{ 'x-session-end-reason' => 'UserRequest' }
      );
    } catch (Exception e) {
      System.debug(
        LoggingLevel.WARN,
        '세션 종료 실패(무시): ' + e.getMessage()
      );
    }
  }

  // ─────────────────────────────────────────────────────────────
  // 내부
  // ─────────────────────────────────────────────────────────────

  /**
   * 에이전트 Id 를 하드코딩하지 않고 DeveloperName 으로 조회합니다.
   * 에이전트를 다시 만들어도 코드를 고칠 필요가 없습니다.
   */
  @TestVisible
  private static Id resolveAgentId() {
    if (cachedAgentId != null) {
      return cachedAgentId;
    }
    // BotDefinition 은 사용자 데이터가 아니라 구성 메타데이터이므로 USER_MODE 대상이 아닙니다.
    List<BotDefinition> rows = [
      SELECT Id
      FROM BotDefinition
      WHERE DeveloperName = :AGENT_DEVELOPER_NAME
      LIMIT 1
    ];
    if (rows.isEmpty()) {
      throw new AgentServiceException(
        AGENT_DEVELOPER_NAME +
        ' 에이전트를 찾을 수 없습니다. 게시·활성화 상태를 확인해 주세요.'
      );
    }
    cachedAgentId = rows[0].Id;
    return cachedAgentId;
  }

  private static HttpResponse send(
    String method,
    String path,
    Object body,
    Map<String, String> extraHeaders
  ) {
    HttpRequest req = new HttpRequest();
    req.setEndpoint(BASE + path);
    req.setMethod(method);
    req.setHeader('Accept', 'application/json');
    req.setTimeout(TIMEOUT_MS);
    if (body != null) {
      req.setHeader('Content-Type', 'application/json');
      req.setBody(JSON.serialize(body));
    }
    if (extraHeaders != null) {
      for (String k : extraHeaders.keySet()) {
        req.setHeader(k, extraHeaders.get(k));
      }
    }
    return new Http().send(req);
  }

  /**
   * Agent API 응답에서 사용자에게 보여줄 메시지와 실행된 액션 정보를 뽑아냅니다.
   * 여러 메시지가 오면 줄바꿈으로 잇습니다.
   */
  private static AgentReply toReply(Map<String, Object> parsed) {
    AgentReply reply = new AgentReply();
    reply.success = true;
    reply.errorMessage = '';
    reply.actions = new List<AgentAction>();

    List<String> texts = new List<String>();
    Object rawMessages = parsed.get('messages');
    if (rawMessages instanceof List<Object>) {
      for (Object o : (List<Object>) rawMessages) {
        Map<String, Object> m = (Map<String, Object>) o;
        String text = (String) m.get('message');
        if (String.isNotBlank(text)) {
          texts.add(text);
        }
        collectActions(m.get('result'), reply.actions);
      }
    }
    reply.message = String.join(texts, '\n\n');
    return reply;
  }

  /**
   * 응답의 result 배열에서 실행된 액션 이름을 수집합니다.
   *
   * 참고: 동기 엔드포인트는 액션 실행 정보를 항상 채워 주지는 않습니다
   * (검증 시 result 가 빈 배열로 왔습니다). 값이 있을 때만 카드로 표시하고,
   * 없으면 대화 메시지만 보여 줍니다.
   */
  private static void collectActions(
    Object rawResult,
    List<AgentAction> collected
  ) {
    if (!(rawResult instanceof List<Object>)) {
      return;
    }
    for (Object o : (List<Object>) rawResult) {
      if (!(o instanceof Map<String, Object>)) {
        continue;
      }
      Map<String, Object> r = (Map<String, Object>) o;
      AgentAction a = new AgentAction();
      a.name = firstNonBlank(
        new List<Object>{ r.get('function'), r.get('name'), r.get('type') }
      );
      a.detail = firstNonBlank(
        new List<Object>{
          r.get('property'),
          r.get('value'),
          r.get('description')
        }
      );
      if (String.isNotBlank(a.name)) {
        collected.add(a);
      }
    }
  }

  private static String firstNonBlank(List<Object> candidates) {
    for (Object c : candidates) {
      if (c != null) {
        String s = String.valueOf(c);
        if (String.isNotBlank(s)) {
          return s;
        }
      }
    }
    return '';
  }

  private static String describeHttpError(String prefix, HttpResponse res) {
    String detail = res.getBody();
    if (String.isNotBlank(detail)) {
      try {
        Map<String, Object> parsed = (Map<String, Object>) JSON.deserializeUntyped(
          detail
        );
        if (parsed.containsKey('message')) {
          detail = String.valueOf(parsed.get('message'));
        }
      } catch (Exception ignored) {
        // 본문이 JSON 이 아니면 원문을 그대로 씁니다.
      }
    }
    if (String.isNotBlank(detail) && detail.length() > 300) {
      detail = detail.substring(0, 300);
    }
    return prefix + ' (HTTP ' + res.getStatusCode() + ') ' + detail;
  }

  private static AgentReply failure(String sessionId, String message) {
    AgentReply reply = new AgentReply();
    reply.sessionId = sessionId;
    reply.success = false;
    reply.message = '';
    reply.errorMessage = message;
    reply.actions = new List<AgentAction>();
    return reply;
  }

  private static String newSessionKey() {
    return String.valueOf(Crypto.getRandomLong()) +
      '-' +
      String.valueOf(Datetime.now().getTime());
  }
}
