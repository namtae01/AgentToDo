/**
 * Agent Action: CompleteTodo
 * TODO 번호로 지정한 일정을 완료 처리합니다.
 */
public with sharing class AgentToDoCompleteTodoAction {
  public class Request {
    @InvocableVariable(
      label='TODO 번호'
      description='완료 처리할 일정의 번호. TODO-0007 형식입니다.'
      required=true
    )
    public String todoNumber;
  }

  public class Result {
    @InvocableVariable(
      label='성공 여부'
      description='완료 처리에 성공했으면 true.'
    )
    public Boolean success;

    @InvocableVariable(
      label='이미 완료됨'
      description='호출 시점에 이미 완료 상태였으면 true. 이 경우 "방금 완료했다"고 말하지 말고 이미 완료된 일정이라고 알려 주세요.'
    )
    public Boolean alreadyDone;

    @InvocableVariable(label='TODO 번호' description='대상 일정의 번호.')
    public String todoNumber;

    @InvocableVariable(
      label='제목'
      description='대상 일정의 제목. 사용자 확인용으로 함께 알려 주세요.'
    )
    public String subject;

    @InvocableVariable(
      label='오류 메시지'
      description='실패 이유. 성공 시 빈 문자열.'
    )
    public String errorMessage;
  }

  @InvocableMethod(
    label='Complete Todo'
    description='TODO 번호로 지정한 일정을 완료 처리합니다. 대상이 하나로 특정되지 않으면 먼저 일정을 조회해 사용자에게 확인하세요.'
    category='AgentToDo'
  )
  public static List<Result> run(List<Request> requests) {
    List<Result> results = new List<Result>();
    for (Request req : requests) {
      Result r = new Result();
      try {
        Boolean wasDone =
          AgentToDoActionService.findByNumber(req.todoNumber).Status__c ==
          'Done';
        AgentToDo_Task__c record = AgentToDoActionService.completeByNumber(
          req.todoNumber
        );
        r.success = true;
        r.alreadyDone = wasDone;
        r.todoNumber = record.Name;
        r.subject = record.Subject__c;
        r.errorMessage = '';
      } catch (Exception e) {
        r.success = false;
        r.alreadyDone = false;
        r.todoNumber = req.todoNumber;
        r.subject = '';
        r.errorMessage = e.getMessage();
      }
      results.add(r);
    }
    return results;
  }
}
