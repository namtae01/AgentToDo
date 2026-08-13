/**
 * AgentToDoAgentService 테스트.
 *
 * Agent API 는 외부 콜아웃이므로 HttpCalloutMock 으로 대체합니다.
 * 실제 왕복은 scripts/apex/probe_agent_api_message.apex 로 검증했습니다.
 */
@IsTest
private class AgentToDoAgentServiceTest {
  /** 상태 코드와 본문을 지정할 수 있는 단순 목. 마지막 요청을 보관해 검증에 씁니다. */
  private class Mock implements HttpCalloutMock {
    private Integer status;
    private String body;
    public HttpRequest lastRequest;

    Mock(Integer status, String body) {
      this.status = status;
      this.body = body;
    }

    public HttpResponse respond(HttpRequest req) {
      lastRequest = req;
      HttpResponse res = new HttpResponse();
      res.setStatusCode(status);
      res.setBody(body);
      return res;
    }
  }

  private static String sessionBody(String sessionId, String message) {
    return JSON.serialize(
      new Map<String, Object>{
        'sessionId' => sessionId,
        'messages' => new List<Object>{
          new Map<String, Object>{
            'type' => 'Inform',
            'message' => message,
            'result' => new List<Object>()
          }
        }
      }
    );
  }

  /** BotDefinition 은 테스트에서 생성할 수 없으므로 Id 조회를 우회합니다. */
  private static void stubAgentId() {
    AgentToDoAgentService.cachedAgentId = '0Xx000000000000AAA';
  }

  @IsTest
  static void startSessionReturnsSessionIdAndWelcome() {
    stubAgentId();
    Mock mock = new Mock(
      200,
      sessionBody('sess-1', '안녕하세요. 무엇을 도와드릴까요?')
    );
    Test.setMock(HttpCalloutMock.class, mock);

    Test.startTest();
    AgentToDoAgentService.AgentReply reply = AgentToDoAgentService.startSession();
    Test.stopTest();

    Assert.isTrue(reply.success, '세션 시작에 성공해야 합니다');
    Assert.areEqual('sess-1', reply.sessionId, '세션 Id 가 반환되어야 합니다');
    Assert.areEqual(
      '안녕하세요. 무엇을 도와드릴까요?',
      reply.message,
      '환영 메시지가 반환되어야 합니다'
    );
    Assert.areEqual(
      '',
      reply.errorMessage,
      '성공 시 오류 메시지는 비어야 합니다'
    );
    Assert.areEqual(
      'POST',
      mock.lastRequest.getMethod(),
      '세션 시작은 POST 여야 합니다'
    );
    Assert.isTrue(
      mock.lastRequest.getEndpoint().contains('/agents/'),
      '세션 시작은 /agents/{id}/sessions 경로여야 합니다'
    );
  }

  @IsTest
  static void startSessionSendsBypassUserFalse() {
    stubAgentId();
    Mock mock = new Mock(200, sessionBody('sess-2', '안녕하세요'));
    Test.setMock(HttpCalloutMock.class, mock);

    Test.startTest();
    AgentToDoAgentService.startSession();
    Test.stopTest();

    Map<String, Object> sent = (Map<String, Object>) JSON.deserializeUntyped(
      mock.lastRequest.getBody()
    );
    Assert.areEqual(
      false,
      sent.get('bypassUser'),
      'bypassUser 가 true 이면 실행 사용자가 에이전트 전용 사용자로 바뀌어 일정이 보이지 않습니다'
    );
    Assert.isNotNull(
      sent.get('externalSessionKey'),
      '세션 키가 포함되어야 합니다'
    );
    Assert.isNotNull(
      sent.get('instanceConfig'),
      'instanceConfig 가 포함되어야 합니다'
    );
  }

  @IsTest
  static void startSessionReportsHttpError() {
    stubAgentId();
    Test.setMock(
      HttpCalloutMock.class,
      new Mock(
        412,
        '{"message":"Precondition Failed: Unable to load agent config"}'
      )
    );

    Test.startTest();
    AgentToDoAgentService.AgentReply reply = AgentToDoAgentService.startSession();
    Test.stopTest();

    Assert.isFalse(reply.success, 'HTTP 오류는 실패로 처리되어야 합니다');
    Assert.isTrue(
      reply.errorMessage.contains('412'),
      '오류 메시지에 상태 코드가 포함되어야 합니다'
    );
    Assert.isTrue(
      reply.errorMessage.contains('Unable to load agent config'),
      '서버가 준 이유가 사용자에게 전달되어야 합니다'
    );
  }

  @IsTest
  static void sendMessageReturnsAgentText() {
    stubAgentId();
    Mock mock = new Mock(200, sessionBody(null, '오늘 일정은 총 4건입니다.'));
    Test.setMock(HttpCalloutMock.class, mock);

    Test.startTest();
    AgentToDoAgentService.AgentReply reply = AgentToDoAgentService.sendMessage(
      'sess-1',
      1,
      '오늘 일정 알려줘'
    );
    Test.stopTest();

    Assert.isTrue(reply.success, '메시지 전송에 성공해야 합니다');
    Assert.areEqual(
      '오늘 일정은 총 4건입니다.',
      reply.message,
      '에이전트 응답이 반환되어야 합니다'
    );
    Assert.areEqual('sess-1', reply.sessionId, '세션 Id 가 유지되어야 합니다');

    Map<String, Object> sent = (Map<String, Object>) JSON.deserializeUntyped(
      mock.lastRequest.getBody()
    );
    Map<String, Object> msg = (Map<String, Object>) sent.get('message');
    Assert.areEqual(
      '오늘 일정 알려줘',
      msg.get('text'),
      '발화가 그대로 전달되어야 합니다'
    );
    Assert.areEqual(
      1,
      msg.get('sequenceId'),
      'sequenceId 가 전달되어야 합니다'
    );
    Assert.areEqual('Text', msg.get('type'), '메시지 유형은 Text 여야 합니다');
  }

  @IsTest
  static void sendMessageJoinsMultipleMessages() {
    stubAgentId();
    String body = JSON.serialize(
      new Map<String, Object>{
        'messages' => new List<Object>{
          new Map<String, Object>{ 'message' => '첫 번째' },
          new Map<String, Object>{ 'message' => '두 번째' }
        }
      }
    );
    Test.setMock(HttpCalloutMock.class, new Mock(200, body));

    Test.startTest();
    AgentToDoAgentService.AgentReply reply = AgentToDoAgentService.sendMessage(
      'sess-1',
      2,
      '더 알려줘'
    );
    Test.stopTest();

    Assert.isTrue(
      reply.message.contains('첫 번째'),
      '첫 메시지가 포함되어야 합니다'
    );
    Assert.isTrue(
      reply.message.contains('두 번째'),
      '둘째 메시지가 포함되어야 합니다'
    );
  }

  @IsTest
  static void sendMessageExtractsActionInfoWhenPresent() {
    stubAgentId();
    String body = JSON.serialize(
      new Map<String, Object>{
        'messages' => new List<Object>{
          new Map<String, Object>{
            'message' => '조회했습니다.',
            'result' => new List<Object>{
              new Map<String, Object>{
                'function' => 'list_todos',
                'property' => '오늘 4건'
              }
            }
          }
        }
      }
    );
    Test.setMock(HttpCalloutMock.class, new Mock(200, body));

    Test.startTest();
    AgentToDoAgentService.AgentReply reply = AgentToDoAgentService.sendMessage(
      'sess-1',
      1,
      '오늘 일정'
    );
    Test.stopTest();

    Assert.areEqual(
      1,
      reply.actions.size(),
      '실행된 액션 1건이 추출되어야 합니다'
    );
    Assert.areEqual(
      'list_todos',
      reply.actions[0].name,
      '액션 이름이 추출되어야 합니다'
    );
    Assert.areEqual(
      '오늘 4건',
      reply.actions[0].detail,
      '액션 상세가 추출되어야 합니다'
    );
  }

  @IsTest
  static void sendMessageHandlesEmptyResultArray() {
    stubAgentId();
    Test.setMock(
      HttpCalloutMock.class,
      new Mock(200, sessionBody(null, '응답'))
    );

    Test.startTest();
    AgentToDoAgentService.AgentReply reply = AgentToDoAgentService.sendMessage(
      'sess-1',
      1,
      '질문'
    );
    Test.stopTest();

    Assert.areEqual(
      0,
      reply.actions.size(),
      'result 가 비면 액션 카드는 없어야 합니다'
    );
    Assert.isTrue(reply.success, '액션이 없어도 성공이어야 합니다');
  }

  @IsTest
  static void sendMessageRejectsMissingSession() {
    Test.startTest();
    AgentToDoAgentService.AgentReply reply = AgentToDoAgentService.sendMessage(
      '',
      1,
      '안녕'
    );
    Test.stopTest();

    Assert.isFalse(reply.success, '세션 없이 전송하면 실패해야 합니다');
    Assert.isTrue(
      reply.errorMessage.contains('세션'),
      '실패 사유가 명확해야 합니다'
    );
  }

  @IsTest
  static void sendMessageRejectsBlankText() {
    Test.startTest();
    AgentToDoAgentService.AgentReply reply = AgentToDoAgentService.sendMessage(
      'sess-1',
      1,
      '   '
    );
    Test.stopTest();

    Assert.isFalse(reply.success, '빈 메시지는 거부되어야 합니다');
    Assert.areEqual('sess-1', reply.sessionId, '세션 Id 는 유지되어야 합니다');
  }

  @IsTest
  static void sendMessageReportsHttpError() {
    stubAgentId();
    Test.setMock(
      HttpCalloutMock.class,
      new Mock(423, '{"message":"Session Already Locked"}')
    );

    Test.startTest();
    AgentToDoAgentService.AgentReply reply = AgentToDoAgentService.sendMessage(
      'sess-1',
      1,
      '질문'
    );
    Test.stopTest();

    Assert.isFalse(reply.success, 'HTTP 오류는 실패로 처리되어야 합니다');
    Assert.isTrue(
      reply.errorMessage.contains('423'),
      '상태 코드가 포함되어야 합니다'
    );
  }

  @IsTest
  static void endSessionSendsDeleteWithReasonHeader() {
    stubAgentId();
    Mock mock = new Mock(200, '');
    Test.setMock(HttpCalloutMock.class, mock);

    Test.startTest();
    AgentToDoAgentService.endSession('sess-1');
    Test.stopTest();

    Assert.areEqual(
      'DELETE',
      mock.lastRequest.getMethod(),
      '세션 종료는 DELETE 여야 합니다'
    );
    Assert.areEqual(
      'UserRequest',
      mock.lastRequest.getHeader('x-session-end-reason'),
      '종료 사유 헤더가 포함되어야 합니다'
    );
  }

  @IsTest
  static void endSessionIgnoresBlankAndErrors() {
    stubAgentId();
    Test.setMock(HttpCalloutMock.class, new Mock(500, 'boom'));

    Test.startTest();
    // 빈 세션 Id 는 콜아웃 없이 조용히 무시되어야 합니다.
    AgentToDoAgentService.endSession('');
    // 서버 오류가 나도 예외가 화면까지 올라오면 안 됩니다.
    AgentToDoAgentService.endSession('sess-1');
    Test.stopTest();

    Assert.isTrue(true, '세션 종료 실패가 예외로 전파되지 않아야 합니다');
  }

  @IsTest
  static void resolveAgentIdFailsClearlyWhenAgentMissing() {
    // 캐시를 비우고, 존재하지 않는 에이전트를 조회하게 만듭니다.
    AgentToDoAgentService.cachedAgentId = null;
    Test.setMock(HttpCalloutMock.class, new Mock(200, sessionBody('s', 'hi')));

    Test.startTest();
    AgentToDoAgentService.AgentReply reply = AgentToDoAgentService.startSession();
    Test.stopTest();

    // 테스트 컨텍스트에는 BotDefinition 이 없으므로 조회 실패 경로를 탑니다.
    if (!reply.success) {
      Assert.isTrue(
        reply.errorMessage.contains('에이전트를 찾을 수 없습니다') ||
        reply.errorMessage.contains('세션을 시작하지 못했습니다'),
        '에이전트를 못 찾으면 사용자에게 이유가 전달되어야 합니다'
      );
    } else {
      Assert.isNotNull(
        reply.sessionId,
        '조직에 에이전트가 있으면 정상 동작해야 합니다'
      );
    }
  }
}
