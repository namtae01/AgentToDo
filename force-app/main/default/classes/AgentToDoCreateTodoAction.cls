/**
 * Agent Action: CreateTodo
 * 새 일정을 생성합니다.
 *
 * 주의: 이 액션은 사용자가 제목과 마감 일시를 확인한 뒤에만 호출되어야 합니다.
 * 확인 게이트는 Agent Script 의 schedule_change 서브에이전트가 담당합니다.
 */
public with sharing class AgentToDoCreateTodoAction {
  public class Request {
    @InvocableVariable(
      label='제목'
      description='일정 제목. 예: 고객 제안서 최종 검토'
      required=true
    )
    public String subject;

    @InvocableVariable(
      label='마감 일시'
      description='일정의 마감 날짜와 시각. 사용자가 확인한 값이어야 합니다.'
      required=true
    )
    public Datetime dueAt;

    @InvocableVariable(
      label='우선순위'
      description='High, Medium, Low 중 하나. 비워 두면 Medium.'
      required=false
    )
    public String priority;

    @InvocableVariable(
      label='카테고리'
      description='Work, Meeting, Development, Review 중 하나. 비워 두면 Work.'
      required=false
    )
    public String category;
  }

  public class Result {
    @InvocableVariable(
      label='성공 여부'
      description='일정이 실제로 생성되었으면 true.'
    )
    public Boolean success;

    @InvocableVariable(
      label='TODO 번호'
      description='생성된 일정의 번호. 예: TODO-0022'
    )
    public String todoNumber;

    @InvocableVariable(
      label='제목'
      description='생성된 일정의 제목. 사용자 확인용으로 그대로 알려 주세요.'
    )
    public String subject;

    @InvocableVariable(
      label='마감 일시'
      description='생성된 일정의 마감 일시를 사람이 읽는 형식으로 표현한 값.'
    )
    public String dueAtText;

    @InvocableVariable(
      label='오류 메시지'
      description='생성에 실패한 이유. 성공 시 빈 문자열.'
    )
    public String errorMessage;
  }

  @InvocableMethod(
    label='Create Todo'
    description='새 일정을 생성합니다. 사용자가 제목과 마감 일시를 모두 확정한 뒤에만 호출하세요. 날짜나 시각이 모호하면 먼저 되물으세요.'
    category='AgentToDo'
  )
  public static List<Result> run(List<Request> requests) {
    List<Result> results = new List<Result>();
    for (Request req : requests) {
      Result r = new Result();
      try {
        AgentToDo_Task__c created = AgentToDoActionService.createTodo(
          req.subject,
          req.dueAt,
          req.priority,
          req.category
        );
        r.success = true;
        r.todoNumber = created.Name;
        r.subject = created.Subject__c;
        r.dueAtText = AgentToDoActionService.formatWhen(created.Due_At__c);
        r.errorMessage = '';
      } catch (Exception e) {
        // 예외를 던지지 않고 결과로 돌려주어야 에이전트가 사용자에게 이유를 설명할 수 있습니다.
        r.success = false;
        r.todoNumber = '';
        r.subject = '';
        r.dueAtText = '';
        r.errorMessage = e.getMessage();
      }
      results.add(r);
    }
    return results;
  }
}
