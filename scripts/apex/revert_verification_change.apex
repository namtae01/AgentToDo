// Phase 2 UI 검증 중 완료 처리한 TODO-0021 을 시드 상태(Ready)로 되돌립니다.
// 실행: sf apex run -o s-test -f scripts/apex/revert_verification_change.apex
List<AgentToDo_Task__c> rows = [
    SELECT Id, Name, Status__c, Completed_At__c
    FROM AgentToDo_Task__c
    WHERE Subject__c = '버전 0.1 회고'
    LIMIT 1
];
for (AgentToDo_Task__c r : rows) {
    r.Status__c = 'Ready';
    r.Completed_At__c = null;
}
if (!rows.isEmpty()) {
    update rows;
    System.debug('되돌림: ' + rows[0].Name + ' → Ready');
}
