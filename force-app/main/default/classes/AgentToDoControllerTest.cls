/**
 * AgentToDoController 단위 테스트.
 *
 * 기한 초과(Is_Overdue__c)는 수식 필드이므로 직접 세팅할 수 없습니다.
 * 과거 마감 + 미완료 상태로 레코드를 만들어 수식이 실제로 계산되는지 검증합니다.
 */
@IsTest
private class AgentToDoControllerTest {
  private static AgentToDo_Task__c buildTask(
    String subject,
    Datetime dueAt,
    String status,
    String priority,
    String category
  ) {
    return new AgentToDo_Task__c(
      Subject__c = subject,
      Due_At__c = dueAt,
      Status__c = status,
      Priority__c = priority,
      Category__c = category
    );
  }

  /**
   * 오늘 2건, 진행 중 1건, 완료 1건, 미래 1건.
   *
   * 오늘 날짜 항목은 실행 시각에 따라 기한 초과가 될 수도, 안 될 수도 있습니다.
   * 그래서 이 시드로는 기한 초과 건수를 단정하지 않고,
   * overdueCountIsIndependentOfRunTime() 에서 오늘 항목 없이 따로 검증합니다.
   */
  private static void seed() {
    Datetime todayNoon = Datetime.newInstance(
      Date.today(),
      Time.newInstance(12, 0, 0, 0)
    );
    Datetime todayAfternoon = Datetime.newInstance(
      Date.today(),
      Time.newInstance(13, 0, 0, 0)
    );
    Datetime lastWeek = Datetime.now().addDays(-7);
    Datetime nextWeek = Datetime.now().addDays(7);

    insert new List<AgentToDo_Task__c>{
      buildTask('오늘 대기 건', todayNoon, 'Ready', 'High', 'Review'),
      buildTask(
        '오늘 진행 건',
        todayAfternoon,
        'In Progress',
        'Medium',
        'Development'
      ),
      buildTask('지난주 미완료 건', lastWeek, 'Ready', 'High', 'Work'),
      buildTask('지난주 완료 건', lastWeek, 'Done', 'Low', 'Meeting'),
      buildTask('다음주 예정 건', nextWeek, 'Ready', 'Medium', 'Work')
    };
  }

  @IsTest
  static void getWorkspaceReturnsTasksAndSummary() {
    seed();

    Test.startTest();
    AgentToDoController.WorkspaceDTO result = AgentToDoController.getWorkspace();
    Test.stopTest();

    Assert.isNotNull(result, '워크스페이스가 반환되어야 합니다');
    Assert.areEqual(
      5,
      result.tasks.size(),
      '시드한 5건이 모두 조회되어야 합니다'
    );
    Assert.isNotNull(result.summary, '요약 지표가 포함되어야 합니다');
    Assert.areEqual(
      UserInfo.getName(),
      result.userName,
      '현재 사용자 이름이 반환되어야 합니다'
    );
    Assert.isNotNull(
      result.userTitle,
      '직함은 비어 있어도 기본값이 채워져야 합니다'
    );

    // 마감 일시 오름차순 정렬 확인
    for (Integer i = 1; i < result.tasks.size(); i++) {
      Assert.isTrue(
        result.tasks[i - 1].dueAt <= result.tasks[i].dueAt,
        '일정은 마감 일시 오름차순으로 정렬되어야 합니다'
      );
    }
  }

  @IsTest
  static void summaryCountsAreAccurate() {
    seed();

    Test.startTest();
    AgentToDoController.SummaryDTO s = AgentToDoController.getWorkspace()
      .summary;
    Test.stopTest();

    Assert.areEqual(2, s.todayCount, '오늘 마감인 일정은 2건이어야 합니다');
    Assert.areEqual(1, s.inProgressCount, '진행 중 일정은 1건이어야 합니다');
    Assert.areEqual(1, s.doneCount, '완료 일정은 1건이어야 합니다');
    Assert.areEqual(
      4,
      s.myTaskCount,
      '내 일정 배지는 목록 화면과 같은 기준(완료 제외)이어야 하므로 5건 중 완료 1건을 뺀 4건이어야 합니다'
    );
    Assert.areEqual(
      0,
      s.receivedTaskCount,
      '요청자가 없으므로 받은 작업은 0건이어야 합니다'
    );
    Assert.isTrue(
      s.weekCompletionRate >= 0 && s.weekCompletionRate <= 100,
      '완료율은 0~100 범위여야 합니다'
    );
  }

  /**
   * 기한 초과 집계는 실행 시각에 흔들리면 안 되므로 오늘 날짜 항목 없이 검증합니다.
   * 과거 미완료 1건만 기한 초과여야 하고, 과거 완료 건과 미래 건은 제외되어야 합니다.
   */
  @IsTest
  static void overdueCountIsIndependentOfRunTime() {
    insert new List<AgentToDo_Task__c>{
      buildTask(
        '과거 미완료',
        Datetime.now().addDays(-5),
        'Ready',
        'High',
        'Work'
      ),
      buildTask(
        '과거 진행 중',
        Datetime.now().addDays(-4),
        'In Progress',
        'High',
        'Work'
      ),
      buildTask('과거 완료', Datetime.now().addDays(-3), 'Done', 'Low', 'Work'),
      buildTask(
        '미래 대기',
        Datetime.now().addDays(5),
        'Ready',
        'Medium',
        'Work'
      )
    };

    Test.startTest();
    AgentToDoController.SummaryDTO s = AgentToDoController.getWorkspace()
      .summary;
    Test.stopTest();

    Assert.areEqual(
      2,
      s.overdueCount,
      '과거 미완료 2건(대기·진행 중)만 기한 초과여야 합니다'
    );
    Assert.areEqual(1, s.doneCount, '완료는 1건이어야 합니다');
    Assert.areEqual(0, s.todayCount, '오늘 마감인 일정은 없어야 합니다');
  }

  @IsTest
  static void weekCompletionRateIsZeroWhenNoTasksThisWeek() {
    // 이번 주에 걸치지 않도록 충분히 먼 미래 한 건만 생성합니다.
    insert buildTask(
      '먼 미래 건',
      Datetime.now().addDays(60),
      'Ready',
      'Low',
      'Work'
    );

    Test.startTest();
    AgentToDoController.SummaryDTO s = AgentToDoController.getWorkspace()
      .summary;
    Test.stopTest();

    Assert.areEqual(0, s.weekTotalCount, '이번 주 일정이 없어야 합니다');
    Assert.areEqual(
      0,
      s.weekCompletionRate,
      '분모가 0이면 완료율은 0이어야 합니다'
    );
  }

  @IsTest
  static void createTaskInsertsRecordWithDefaults() {
    Datetime due = Datetime.now().addDays(1);

    Test.startTest();
    AgentToDoController.TaskDTO created = AgentToDoController.createTask(
      '  새 일정  ',
      due,
      null,
      null,
      '설명입니다'
    );
    Test.stopTest();

    Assert.isNotNull(created.recordId, '생성된 레코드 Id가 반환되어야 합니다');
    Assert.areEqual(
      '새 일정',
      created.subject,
      '제목의 앞뒤 공백은 제거되어야 합니다'
    );
    Assert.areEqual(
      'Medium',
      created.priority,
      '우선순위 미지정 시 Medium 이 기본값이어야 합니다'
    );
    Assert.areEqual(
      'Work',
      created.category,
      '카테고리 미지정 시 Work 가 기본값이어야 합니다'
    );
    Assert.areEqual(
      'Ready',
      created.status,
      '새 일정은 Ready 상태로 생성되어야 합니다'
    );
    Assert.isNotNull(created.todoNumber, '자동 번호가 채번되어야 합니다');
    Assert.isTrue(
      created.todoNumber.startsWith('TODO-'),
      '자동 번호는 TODO- 로 시작해야 합니다'
    );
  }

  @IsTest
  static void createTaskRejectsBlankSubject() {
    Boolean threw = false;

    Test.startTest();
    try {
      AgentToDoController.createTask(
        '   ',
        Datetime.now(),
        'High',
        'Work',
        null
      );
    } catch (AuraHandledException e) {
      threw = true;
    }
    Test.stopTest();

    Assert.isTrue(
      threw,
      '제목이 비어 있으면 AuraHandledException 이 발생해야 합니다'
    );
    Assert.areEqual(
      0,
      [SELECT COUNT() FROM AgentToDo_Task__c],
      '레코드가 생성되지 않아야 합니다'
    );
  }

  @IsTest
  static void createTaskRejectsNullDueDate() {
    Boolean threw = false;

    Test.startTest();
    try {
      AgentToDoController.createTask('제목만 있음', null, 'High', 'Work', null);
    } catch (AuraHandledException e) {
      threw = true;
    }
    Test.stopTest();

    Assert.isTrue(
      threw,
      '마감 일시가 없으면 AuraHandledException 이 발생해야 합니다'
    );
    Assert.areEqual(
      0,
      [SELECT COUNT() FROM AgentToDo_Task__c],
      '레코드가 생성되지 않아야 합니다'
    );
  }

  @IsTest
  static void completeTaskSetsDoneAndTimestamp() {
    AgentToDo_Task__c t = buildTask(
      '완료 대상',
      Datetime.now().addDays(1),
      'Ready',
      'High',
      'Work'
    );
    insert t;

    Test.startTest();
    AgentToDoController.TaskDTO updated = AgentToDoController.completeTask(
      t.Id
    );
    Test.stopTest();

    Assert.areEqual('Done', updated.status, '상태가 Done 으로 바뀌어야 합니다');
    Assert.isNotNull(updated.completedAt, '완료 일시가 기록되어야 합니다');
    Assert.areEqual(
      false,
      updated.isOverdue,
      '완료된 일정은 기한 초과가 아니어야 합니다'
    );
  }

  @IsTest
  static void completeTaskClearsOverdueFlag() {
    // 과거 마감 + 미완료 → 기한 초과 상태에서 시작
    AgentToDo_Task__c t = buildTask(
      '지각한 일정',
      Datetime.now().addDays(-3),
      'Ready',
      'High',
      'Work'
    );
    insert t;
    Assert.areEqual(
      true,
      [SELECT Is_Overdue__c FROM AgentToDo_Task__c WHERE Id = :t.Id]
      .Is_Overdue__c,
      '완료 전에는 기한 초과여야 합니다'
    );

    Test.startTest();
    AgentToDoController.TaskDTO updated = AgentToDoController.completeTask(
      t.Id
    );
    Test.stopTest();

    Assert.areEqual(
      false,
      updated.isOverdue,
      '완료하면 기한 초과가 해제되어야 합니다'
    );
  }

  @IsTest
  static void updateStatusToInProgressLeavesCompletedAtNull() {
    AgentToDo_Task__c t = buildTask(
      '진행 전환',
      Datetime.now().addDays(2),
      'Ready',
      'Medium',
      'Work'
    );
    insert t;

    Test.startTest();
    AgentToDoController.TaskDTO updated = AgentToDoController.updateStatus(
      t.Id,
      'In Progress'
    );
    Test.stopTest();

    Assert.areEqual(
      'In Progress',
      updated.status,
      '상태가 In Progress 로 바뀌어야 합니다'
    );
    Assert.isNull(
      updated.completedAt,
      '완료가 아니면 완료 일시는 비어 있어야 합니다'
    );
  }

  @IsTest
  static void updateStatusRejectsUnknownValue() {
    AgentToDo_Task__c t = buildTask(
      '잘못된 상태',
      Datetime.now().addDays(2),
      'Ready',
      'Medium',
      'Work'
    );
    insert t;
    Boolean threw = false;

    Test.startTest();
    try {
      AgentToDoController.updateStatus(t.Id, 'Cancelled');
    } catch (AuraHandledException e) {
      threw = true;
    }
    Test.stopTest();

    Assert.isTrue(threw, '허용되지 않은 상태 값은 거부되어야 합니다');
    Assert.areEqual(
      'Ready',
      [SELECT Status__c FROM AgentToDo_Task__c WHERE Id = :t.Id].Status__c,
      '거부된 요청은 레코드를 변경하지 않아야 합니다'
    );
  }

  @IsTest
  static void updateStatusRejectsBlankId() {
    Boolean threw = false;

    Test.startTest();
    try {
      AgentToDoController.updateStatus('', 'Done');
    } catch (AuraHandledException e) {
      threw = true;
    }
    Test.stopTest();

    Assert.isTrue(threw, '대상 Id 가 비어 있으면 거부되어야 합니다');
  }

  @IsTest
  static void receivedTaskIsClassifiedByRequester() {
    User requester = [
      SELECT Id
      FROM User
      WHERE IsActive = TRUE AND Id != :UserInfo.getUserId()
      LIMIT 1
    ];

    AgentToDo_Task__c mine = buildTask(
      '내가 만든 일정',
      Datetime.now().addDays(1),
      'Ready',
      'Medium',
      'Work'
    );
    AgentToDo_Task__c received = buildTask(
      '남이 요청한 일정',
      Datetime.now().addDays(2),
      'Ready',
      'High',
      'Review'
    );
    received.Requested_By__c = requester.Id;
    insert new List<AgentToDo_Task__c>{ mine, received };

    Test.startTest();
    AgentToDoController.WorkspaceDTO result = AgentToDoController.getWorkspace();
    Test.stopTest();

    Assert.areEqual(
      1,
      result.summary.receivedTaskCount,
      '타인이 요청한 1건만 받은 작업이어야 합니다'
    );
    Assert.areEqual(
      1,
      result.summary.myTaskCount,
      '나머지 1건은 내 일정이어야 합니다'
    );

    for (AgentToDoController.TaskDTO t : result.tasks) {
      if (t.subject == '남이 요청한 일정') {
        Assert.isTrue(
          t.isReceived,
          '요청자가 타인이면 받은 작업으로 표시되어야 합니다'
        );
        Assert.isNotNull(t.requestedByName, '요청자 이름이 채워져야 합니다');
      } else {
        Assert.isFalse(t.isReceived, '요청자가 없으면 내 일정이어야 합니다');
        Assert.isNull(
          t.requestedByName,
          '요청자가 없으면 이름도 비어야 합니다'
        );
      }
    }
  }

  @IsTest
  static void agentMetadataIsExposedToUi() {
    AgentToDo_Task__c t = buildTask(
      '에이전트가 만든 일정',
      Datetime.now().addDays(1),
      'Ready',
      'High',
      'Work'
    );
    t.Created_By_Agent__c = true;
    t.Last_Agent_Action__c = 'CreateTodo';
    insert t;

    Test.startTest();
    AgentToDoController.WorkspaceDTO result = AgentToDoController.getWorkspace();
    Test.stopTest();

    Assert.areEqual(1, result.tasks.size(), '1건이 조회되어야 합니다');
    Assert.isTrue(
      result.tasks[0].createdByAgent,
      'Agent 생성 플래그가 그대로 노출되어야 합니다'
    );
    Assert.areEqual(
      'CreateTodo',
      result.tasks[0].lastAgentAction,
      '실행된 Agent Action 이름이 그대로 노출되어야 합니다'
    );
  }
}
