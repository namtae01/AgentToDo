/**
 * Agent Action: ListMyTodos
 * 실행 사용자의 일정을 범위별로 조회합니다.
 */
public with sharing class AgentToDoListTodosAction {
  public class Request {
    @InvocableVariable(
      label='조회 범위'
      description='today = 오늘 마감 일정, week = 이번 주 마감 일정, open = 완료되지 않은 전체 일정. 비워 두면 today.'
      required=false
    )
    public String scope;
  }

  public class Result {
    @InvocableVariable(
      label='건수'
      description='조회된 일정 건수. 0이면 해당 범위에 일정이 없습니다.'
    )
    public Integer count;

    @InvocableVariable(
      label='일정 목록'
      description='한 줄에 하나씩: TODO번호 | 제목 | 마감 일시 | 우선순위 | 상태. 건수가 0이면 빈 문자열입니다.'
    )
    public String todos;

    @InvocableVariable(
      label='TODO 번호 목록'
      description='조회된 일정의 TODO 번호를 쉼표로 구분한 문자열.'
    )
    public String todoNumbers;
  }

  @InvocableMethod(
    label='List My Todos'
    description='현재 사용자의 일정을 조회합니다. 오늘 일정 브리핑, 이번 주 일정 확인, 남은 할 일 목록 요청에 사용하세요.'
    category='AgentToDo'
  )
  public static List<Result> run(List<Request> requests) {
    List<Result> results = new List<Result>();
    for (Request req : requests) {
      List<AgentToDo_Task__c> rows = AgentToDoActionService.queryByScope(
        req.scope
      );
      Result r = new Result();
      r.count = rows.size();
      r.todos = AgentToDoActionService.formatList(rows);
      r.todoNumbers = AgentToDoActionService.numbersOf(rows);
      results.add(r);
    }
    return results;
  }
}
