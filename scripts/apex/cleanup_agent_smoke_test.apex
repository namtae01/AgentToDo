// Phase 3c 스모크 테스트로 변경된 데이터를 정리합니다.
// 실행: sf apex run -o s-test -f scripts/apex/cleanup_agent_smoke_test.apex
//
//  - TODO-0004(권한 모델 점검): 시드 데이터인데 에이전트 테스트로 완료됨 → Ready 로 원복
//  - TODO-0022(에이전트 연동 리허설): 3a 의 REST 직접 호출 리허설용 → 삭제
//  - TODO-0023(코드 리뷰): 에이전트가 대화로 생성한 레코드 → Ready 로 두어
//    화면에서 "Agent 생성" 배지가 어떻게 보이는지 확인할 수 있게 남깁니다.

List<AgentToDo_Task__c> toRevert = [
    SELECT Id, Name, Status__c, Completed_At__c, Last_Agent_Action__c
    FROM AgentToDo_Task__c
    WHERE Name IN ('TODO-0004', 'TODO-0023')
];
for (AgentToDo_Task__c r : toRevert) {
    r.Status__c = 'Ready';
    r.Completed_At__c = null;
    r.Last_Agent_Action__c = (r.Name == 'TODO-0023') ? 'CreateTodo' : null;
}
if (!toRevert.isEmpty()) {
    update toRevert;
    for (AgentToDo_Task__c r : toRevert) {
        System.debug('원복: ' + r.Name + ' → Ready');
    }
}

List<AgentToDo_Task__c> toDelete = [SELECT Id, Name FROM AgentToDo_Task__c WHERE Name = 'TODO-0022'];
if (!toDelete.isEmpty()) {
    System.debug('삭제: ' + toDelete[0].Name);
    delete toDelete;
}

System.debug('총 일정: ' + [SELECT COUNT() FROM AgentToDo_Task__c] + '건');
System.debug('Agent 생성 일정: ' + [SELECT COUNT() FROM AgentToDo_Task__c WHERE Created_By_Agent__c = true] + '건');
