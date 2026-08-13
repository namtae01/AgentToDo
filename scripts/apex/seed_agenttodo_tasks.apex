// AgentToDo 시드 데이터
// 실행: sf apex run -o s-test -f scripts/apex/seed_agenttodo_tasks.apex
// 멱등성: 기존 AgentToDo_Task__c 를 모두 삭제한 뒤 다시 생성합니다.
// 기준 월: 2026년 8월 (목업과 동일). 오늘은 2026-08-13(목).

// ── 기존 데이터 정리 ────────────────────────────────────────────────
List<AgentToDo_Task__c> existing = [SELECT Id FROM AgentToDo_Task__c LIMIT 10000];
if (!existing.isEmpty()) {
    delete existing;
    System.debug('삭제된 기존 일정: ' + existing.size() + '건');
}

// ── 요청자로 쓸 사용자 조회 (없으면 null 로 둠) ──────────────────────
Map<String, Id> userByAlias = new Map<String, Id>();
for (User u : [
    SELECT Id, Username
    FROM User
    WHERE IsActive = true
      AND Username IN ('jwjang.eafc6020fb96@agentforce.com', 'shshin.eafc6020fb96@agentforce.com')
]) {
    userByAlias.put(u.Username, u.Id);
}
Id requesterA = userByAlias.get('jwjang.eafc6020fb96@agentforce.com');
Id requesterB = userByAlias.get('shshin.eafc6020fb96@agentforce.com');

// ── 헬퍼: 한 건 생성 ────────────────────────────────────────────────
List<AgentToDo_Task__c> rows = new List<AgentToDo_Task__c>();

// 로컬 헬퍼가 없는 익명 Apex 특성상 인라인으로 구성합니다.
// (day, hour, minute, 제목, 우선순위, 카테고리, 상태, 요청자)
List<List<Object>> spec = new List<List<Object>>{
    // 지난 일정 — 완료된 것과 기한 초과된 것이 섞여 있습니다
    new List<Object>{ 3,  10,  0, '월간 계획 수립',            'Medium', 'Work',        'Done',        null },
    new List<Object>{ 5,  14,  0, '패키지 구조 정리',          'Medium', 'Development', 'Done',        null },
    new List<Object>{ 7,  11,  0, 'Flow Action 설계',          'High',   'Development', 'Done',        null },
    new List<Object>{ 10,  9,  0, '권한 모델 점검',            'High',   'Review',      'Ready',       null },
    new List<Object>{ 11, 15,  0, 'Apex 테스트 보완',          'High',   'Development', 'In Progress', null },
    new List<Object>{ 12,  9, 30, '고객 제안서 최종 검토',      'High',   'Review',      'Done',        null },
    new List<Object>{ 12, 14,  0, 'AgentToDo 화면 리뷰',       'Medium', 'Meeting',     'Done',        null },
    new List<Object>{ 12, 16, 30, 'Apex Action 테스트',        'High',   'Development', 'In Progress', null },
    new List<Object>{ 12, 18,  0, '개발 일지 정리',            'Low',    'Work',        'Done',        null },
    // 오늘 (8/13)
    new List<Object>{ 13,  9, 30, '스크래치 오그 배포',        'High',   'Development', 'In Progress', null },
    new List<Object>{ 13, 13,  0, '데일리 스탠드업',           'Medium', 'Meeting',     'Ready',       null },
    new List<Object>{ 13, 16,  0, 'LWC 컴포넌트 설계 리뷰',    'High',   'Review',      'Ready',       requesterA },
    new List<Object>{ 13, 18, 30, '개발 일지 정리',            'Low',    'Work',        'Ready',       null },
    // 앞으로의 일정
    new List<Object>{ 14, 11,  0, 'UI 검토 회의',              'Medium', 'Meeting',     'Ready',       requesterB },
    new List<Object>{ 17, 10,  0, 'Prompt Template 작성',      'Medium', 'Development', 'Ready',       null },
    new List<Object>{ 19, 14,  0, 'Action 설명 개선',          'Medium', 'Development', 'Ready',       null },
    new List<Object>{ 19, 17,  0, '주간 리뷰',                 'Low',    'Meeting',     'Ready',       null },
    new List<Object>{ 21, 15,  0, 'Managed 2GP 생성',          'High',   'Development', 'Ready',       requesterA },
    new List<Object>{ 24, 10,  0, '설치 테스트',               'Medium', 'Review',      'Ready',       null },
    new List<Object>{ 26, 14,  0, '회귀 테스트',               'Medium', 'Development', 'Ready',       null },
    new List<Object>{ 28, 16,  0, '버전 0.1 회고',             'Low',    'Meeting',     'Ready',       null }
};

for (List<Object> s : spec) {
    Integer day    = (Integer) s[0];
    Integer hour   = (Integer) s[1];
    Integer minute = (Integer) s[2];
    String  title  = (String)  s[3];
    String  prio   = (String)  s[4];
    String  cat    = (String)  s[5];
    String  status = (String)  s[6];
    Id      reqBy  = (Id)      s[7];

    Datetime dueAt = Datetime.newInstance(2026, 8, day, hour, minute, 0);

    AgentToDo_Task__c t = new AgentToDo_Task__c(
        Subject__c      = title,
        Due_At__c       = dueAt,
        Priority__c     = prio,
        Category__c     = cat,
        Status__c       = status,
        Requested_By__c = reqBy
    );
    if (status == 'Done') {
        t.Completed_At__c = dueAt.addMinutes(45);
    }
    rows.add(t);
}

// 목업의 "Agent 생성" 배지를 재현할 한 건
rows[5].Created_By_Agent__c  = true;
rows[5].Last_Agent_Action__c = 'CreateTodo';
rows[8].Last_Agent_Action__c = 'CompleteTodo';

insert rows;

// ── 결과 확인 ───────────────────────────────────────────────────────
System.debug('생성된 일정: ' + rows.size() + '건');
for (AggregateResult ar : [
    SELECT Status__c s, COUNT(Id) c FROM AgentToDo_Task__c GROUP BY Status__c
]) {
    System.debug('  ' + ar.get('s') + ': ' + ar.get('c') + '건');
}
System.debug('기한 초과: ' + [SELECT COUNT() FROM AgentToDo_Task__c WHERE Is_Overdue__c = true] + '건');
System.debug('받은 작업: ' + [SELECT COUNT() FROM AgentToDo_Task__c WHERE Requested_By__c != null] + '건');
