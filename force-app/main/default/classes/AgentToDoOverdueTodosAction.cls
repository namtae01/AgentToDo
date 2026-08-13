/**
 * Agent Action: GetOverdueTodos
 * 마감이 지났는데 완료되지 않은 일정을 조회합니다.
 */
public with sharing class AgentToDoOverdueTodosAction {
  public class Request {
    @InvocableVariable(
      label='사용 안 함'
      description='이 액션은 입력이 필요하지 않습니다. 항상 현재 사용자 기준으로 조회합니다.'
      required=false
    )
    public String unused;
  }

  public class Result {
    @InvocableVariable(
      label='건수'
      description='기한이 지난 일정 건수. 0이면 지연된 일정이 없습니다.'
    )
    public Integer count;

    @InvocableVariable(
      label='기한 초과 일정 목록'
      description='한 줄에 하나씩: TODO번호 | 제목 | 마감 일시 | 우선순위 | 상태 | 기한 초과.'
    )
    public String todos;

    @InvocableVariable(
      label='TODO 번호 목록'
      description='기한 초과 일정의 TODO 번호를 쉼표로 구분한 문자열.'
    )
    public String todoNumbers;
  }

  @InvocableMethod(
    label='Get Overdue Todos'
    description='마감 일시가 지났는데 아직 완료되지 않은 일정을 조회합니다. 기한 초과, 지연, 늦은 일정 확인 요청에 사용하세요.'
    category='AgentToDo'
  )
  public static List<Result> run(List<Request> requests) {
    List<Result> results = new List<Result>();
    for (Request req : requests) {
      List<AgentToDo_Task__c> rows = AgentToDoActionService.queryOverdue();
      Result r = new Result();
      r.count = rows.size();
      r.todos = AgentToDoActionService.formatList(rows);
      r.todoNumbers = AgentToDoActionService.numbersOf(rows);
      results.add(r);
    }
    return results;
  }
}
