/**
 * Agent Action: NavigateToScreen
 *
 * 에이전트가 AgentToDo 앱의 화면을 전환합니다. 에이전트는 서버에서 실행되어
 * 브라우저를 직접 조작할 수 없으므로, 플랫폼 이벤트를 발행해 LWC 가 구독하는
 * 방식으로 신호를 보냅니다.
 *
 * Agent API 동기 엔드포인트가 액션 실행 정보(result)를 돌려주지 않기 때문에
 * "에이전트가 이 액션을 호출했다"는 사실을 LWC 가 응답에서 알아낼 수 없습니다.
 * 그래서 응답 경로가 아니라 별도의 푸시 채널을 씁니다.
 */
public with sharing class AgentToDoNavigateAction {
  /** LWC 의 activeMenu 값과 1:1 로 대응합니다. 여기 없는 값은 전환하지 않습니다. */
  private static final Map<String, String> SCREEN_LABELS = new Map<String, String>{
    'today' => '오늘',
    'calendar' => '캘린더',
    'mine' => '내 일정',
    'received' => '받은 작업',
    'done' => '완료 일정',
    'assistant' => 'AI 어시스턴트'
  };

  /** 자연어 표현 → 화면 키. 에이전트가 한국어 화면 이름을 그대로 넘겨도 받습니다. */
  private static final Map<String, String> ALIASES = new Map<String, String>{
    '오늘' => 'today',
    '오늘 일정' => 'today',
    '캘린더' => 'calendar',
    '달력' => 'calendar',
    '내 일정' => 'mine',
    '나의 일정' => 'mine',
    '받은 작업' => 'received',
    '받은작업' => 'received',
    '완료 일정' => 'done',
    '완료' => 'done',
    'ai 어시스턴트' => 'assistant',
    '어시스턴트' => 'assistant'
  };

  public class Request {
    @InvocableVariable(
      label='화면'
      description='전환할 화면. today(오늘), calendar(캘린더), mine(내 일정), received(받은 작업), done(완료 일정) 중 하나입니다. 사용자가 한국어 화면 이름으로 말해도 그대로 넘기면 됩니다.'
      required=true
    )
    public String screen;
  }

  public class Result {
    @InvocableVariable(
      label='성공 여부'
      description='화면 전환 신호를 보냈으면 true.'
    )
    public Boolean success;

    @InvocableVariable(
      label='화면 이름'
      description='실제로 전환한 화면의 한국어 이름. 사용자에게 이 이름으로 알려 주세요.'
    )
    public String screenLabel;

    @InvocableVariable(
      label='오류 메시지'
      description='전환하지 못한 이유. 존재하지 않는 화면이면 사용 가능한 화면 목록이 들어 있습니다.'
    )
    public String errorMessage;
  }

  @InvocableMethod(
    label='Navigate To Screen'
    description='AgentToDo 앱의 화면을 전환합니다. 사용자가 특정 화면으로 이동하거나 보여 달라고 요청할 때 사용하세요. 오늘, 캘린더, 내 일정, 받은 작업, 완료 일정 화면을 지원합니다.'
    category='AgentToDo'
  )
  public static List<Result> run(List<Request> requests) {
    List<Result> results = new List<Result>();
    List<AgentToDo_UI_Command__e> events = new List<AgentToDo_UI_Command__e>();

    for (Request req : requests) {
      Result r = new Result();
      String key = resolveScreen(req == null ? null : req.screen);

      if (key == null) {
        r.success = false;
        r.screenLabel = '';
        r.errorMessage =
          '전환할 수 없는 화면입니다. 사용 가능한 화면: ' +
          String.join(new List<String>(SCREEN_LABELS.values()), ', ');
        results.add(r);
        continue;
      }

      events.add(
        new AgentToDo_UI_Command__e(
          Command__c = 'navigate',
          Screen__c = key,
          // 플랫폼 이벤트는 구독자 전원에게 전달되므로 대상을 명시합니다.
          Target_User_Id__c = UserInfo.getUserId()
        )
      );

      r.success = true;
      r.screenLabel = SCREEN_LABELS.get(key);
      r.errorMessage = '';
      results.add(r);
    }

    if (!events.isEmpty()) {
      List<Database.SaveResult> saveResults = EventBus.publish(events);
      // 발행 실패는 사용자에게 알려야 합니다. 성공했다고 말한 뒤 화면이 그대로면
      // 무엇이 잘못됐는지 알 수 없습니다.
      Integer index = 0;
      for (Integer i = 0; i < results.size(); i++) {
        if (results[i].success != true) {
          continue;
        }
        if (index < saveResults.size() && !saveResults[index].isSuccess()) {
          results[i].success = false;
          results[i].errorMessage = '화면 전환 신호를 보내지 못했습니다.';
        }
        index++;
      }
    }

    return results;
  }

  /** 화면 키 또는 한국어 이름을 정규화합니다. 못 알아보면 null. */
  @TestVisible
  private static String resolveScreen(String raw) {
    if (String.isBlank(raw)) {
      return null;
    }
    String normalized = raw.trim().toLowerCase();
    if (SCREEN_LABELS.containsKey(normalized)) {
      return normalized;
    }
    if (ALIASES.containsKey(normalized)) {
      return ALIASES.get(normalized);
    }
    // 따옴표나 조사가 붙어 오는 경우를 위해 부분 일치도 허용합니다.
    for (String alias : ALIASES.keySet()) {
      if (normalized.contains(alias)) {
        return ALIASES.get(alias);
      }
    }
    return null;
  }
}
