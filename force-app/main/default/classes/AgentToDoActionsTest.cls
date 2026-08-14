/**
 * AgentToDo Agent Action 4종과 공용 서비스 테스트.
 *
 * 기한 초과(Is_Overdue__c)는 수식 필드라 직접 세팅할 수 없으므로
 * 과거 마감 + 미완료 조합으로 만들어 검증합니다.
 */
@IsTest
private class AgentToDoActionsTest {
  private static AgentToDo_Task__c build(
    String subject,
    Datetime dueAt,
    String status
  ) {
    return new AgentToDo_Task__c(
      Subject__c = subject,
      Due_At__c = dueAt,
      Status__c = status,
      Priority__c = 'Medium',
      Category__c = 'Work'
    );
  }

  // ── ListMyTodos ─────────────────────────────────────────────

  @IsTest
  static void listTodosDefaultsToTodayScope() {
    insert new List<AgentToDo_Task__c>{
      build(
        '오늘 A',
        Datetime.newInstance(Date.today(), Time.newInstance(9, 0, 0, 0)),
        'Ready'
      ),
      build(
        '오늘 B',
        Datetime.newInstance(Date.today(), Time.newInstance(15, 0, 0, 0)),
        'Ready'
      ),
      build('내일', Datetime.now().addDays(1), 'Ready')
    };

    AgentToDoListTodosAction.Request req = new AgentToDoListTodosAction.Request();
    req.scope = null;

    Test.startTest();
    List<AgentToDoListTodosAction.Result> out = AgentToDoListTodosAction.run(
      new List<AgentToDoListTodosAction.Request>{ req }
    );
    Test.stopTest();

    Assert.areEqual(1, out.size(), '요청 1건에 결과 1건이 대응해야 합니다');
    Assert.areEqual(
      2,
      out[0].count,
      'scope 를 비우면 오늘 마감 2건만 나와야 합니다'
    );
    Assert.isTrue(
      out[0].todos.contains('오늘 A'),
      '목록 문자열에 제목이 포함되어야 합니다'
    );
    Assert.isFalse(
      out[0].todos.contains('내일'),
      '오늘 범위 밖 일정은 제외되어야 합니다'
    );
    Assert.isTrue(
      out[0].todoNumbers.contains('TODO-'),
      'TODO 번호 목록이 채워져야 합니다'
    );
  }

  @IsTest
  static void listTodosOpenScopeExcludesDone() {
    insert new List<AgentToDo_Task__c>{
      build('미완료 1', Datetime.now().addDays(3), 'Ready'),
      build('미완료 2', Datetime.now().addDays(4), 'In Progress'),
      build('완료됨', Datetime.now().addDays(5), 'Done')
    };

    AgentToDoListTodosAction.Request req = new AgentToDoListTodosAction.Request();
    req.scope = 'open';

    Test.startTest();
    List<AgentToDoListTodosAction.Result> out = AgentToDoListTodosAction.run(
      new List<AgentToDoListTodosAction.Request>{ req }
    );
    Test.stopTest();

    Assert.areEqual(2, out[0].count, 'open 범위는 완료 건을 제외해야 합니다');
    Assert.isFalse(
      out[0].todos.contains('완료됨'),
      '완료된 일정은 목록에 없어야 합니다'
    );
  }

  @IsTest
  static void listTodosReturnsEmptyStringWhenNoRows() {
    AgentToDoListTodosAction.Request req = new AgentToDoListTodosAction.Request();
    req.scope = 'today';

    Test.startTest();
    List<AgentToDoListTodosAction.Result> out = AgentToDoListTodosAction.run(
      new List<AgentToDoListTodosAction.Request>{ req }
    );
    Test.stopTest();

    Assert.areEqual(0, out[0].count, '데이터가 없으면 0건이어야 합니다');
    Assert.areEqual(
      '',
      out[0].todos,
      '0건이면 빈 문자열이어야 에이전트가 지어내지 않습니다'
    );
    Assert.areEqual(
      '',
      out[0].todoNumbers,
      '0건이면 번호 목록도 비어야 합니다'
    );
  }

  @IsTest
  static void listTodosHandlesBulkRequests() {
    insert build(
      '오늘 건',
      Datetime.newInstance(Date.today(), Time.newInstance(10, 0, 0, 0)),
      'Ready'
    );

    AgentToDoListTodosAction.Request a = new AgentToDoListTodosAction.Request();
    a.scope = 'today';
    AgentToDoListTodosAction.Request b = new AgentToDoListTodosAction.Request();
    b.scope = 'open';

    Test.startTest();
    List<AgentToDoListTodosAction.Result> out = AgentToDoListTodosAction.run(
      new List<AgentToDoListTodosAction.Request>{ a, b }
    );
    Test.stopTest();

    Assert.areEqual(2, out.size(), '요청 수와 결과 수가 같아야 합니다');
    Assert.areEqual(1, out[0].count, '첫 요청은 오늘 1건');
    Assert.areEqual(1, out[1].count, '둘째 요청은 미완료 1건');
  }

  // ── GetOverdueTodos ─────────────────────────────────────────

  @IsTest
  static void overdueActionReturnsOnlyPastIncomplete() {
    insert new List<AgentToDo_Task__c>{
      build('지각 1', Datetime.now().addDays(-5), 'Ready'),
      build('지각 2', Datetime.now().addDays(-2), 'In Progress'),
      build('과거 완료', Datetime.now().addDays(-3), 'Done'),
      build('미래', Datetime.now().addDays(5), 'Ready')
    };

    Test.startTest();
    List<AgentToDoOverdueTodosAction.Result> out = AgentToDoOverdueTodosAction.run(
      new List<AgentToDoOverdueTodosAction.Request>{
        new AgentToDoOverdueTodosAction.Request()
      }
    );
    Test.stopTest();

    Assert.areEqual(2, out[0].count, '과거 미완료 2건만 기한 초과여야 합니다');
    Assert.isTrue(
      out[0].todos.contains('기한 초과'),
      '목록 줄에 기한 초과 표시가 있어야 합니다'
    );
    Assert.isFalse(
      out[0].todos.contains('과거 완료'),
      '완료된 과거 일정은 제외되어야 합니다'
    );
    Assert.isFalse(
      out[0].todos.contains('미래'),
      '미래 일정은 제외되어야 합니다'
    );
  }

  // ── CreateTodo ──────────────────────────────────────────────

  @IsTest
  static void createTodoMarksAgentProvenance() {
    AgentToDoCreateTodoAction.Request req = new AgentToDoCreateTodoAction.Request();
    req.subject = '코드 리뷰';
    req.dueAt = Datetime.now().addDays(1);
    req.priority = 'High';
    req.category = 'Review';

    Test.startTest();
    List<AgentToDoCreateTodoAction.Result> out = AgentToDoCreateTodoAction.run(
      new List<AgentToDoCreateTodoAction.Request>{ req }
    );
    Test.stopTest();

    Assert.isTrue(out[0].success, '생성에 성공해야 합니다');
    Assert.isTrue(
      out[0].todoNumber.startsWith('TODO-'),
      'TODO 번호가 채번되어야 합니다'
    );
    Assert.areEqual('코드 리뷰', out[0].subject, '제목이 반향되어야 합니다');
    Assert.isNotNull(
      out[0].dueAtText,
      '마감 일시가 사람이 읽는 형식으로 반환되어야 합니다'
    );

    AgentToDo_Task__c saved = [
      SELECT
        Created_By_Agent__c,
        Last_Agent_Action__c,
        Priority__c,
        Category__c,
        Status__c
      FROM AgentToDo_Task__c
      LIMIT 1
    ];
    Assert.isTrue(
      saved.Created_By_Agent__c,
      'Agent 생성 플래그가 기록되어야 합니다'
    );
    Assert.areEqual(
      'CreateTodo',
      saved.Last_Agent_Action__c,
      '실행된 Action 이름이 기록되어야 합니다'
    );
    Assert.areEqual('High', saved.Priority__c, '우선순위가 반영되어야 합니다');
    Assert.areEqual(
      'Review',
      saved.Category__c,
      '카테고리가 반영되어야 합니다'
    );
    Assert.areEqual('Ready', saved.Status__c, '새 일정은 Ready 여야 합니다');
  }

  @IsTest
  static void createTodoNormalizesKoreanAndUnknownValues() {
    AgentToDoCreateTodoAction.Request req = new AgentToDoCreateTodoAction.Request();
    req.subject = '기획 회의';
    req.dueAt = Datetime.now().addDays(2);
    req.priority = '높음';
    req.category = '회의';

    Test.startTest();
    AgentToDoCreateTodoAction.run(
      new List<AgentToDoCreateTodoAction.Request>{ req }
    );
    Test.stopTest();

    AgentToDo_Task__c saved = [
      SELECT Priority__c, Category__c
      FROM AgentToDo_Task__c
      LIMIT 1
    ];
    Assert.areEqual(
      'High',
      saved.Priority__c,
      '한국어 우선순위가 피클리스트 값으로 정규화되어야 합니다'
    );
    Assert.areEqual(
      'Meeting',
      saved.Category__c,
      '한국어 카테고리가 피클리스트 값으로 정규화되어야 합니다'
    );
  }

  @IsTest
  static void createTodoReportsErrorInsteadOfThrowing() {
    AgentToDoCreateTodoAction.Request noSubject = new AgentToDoCreateTodoAction.Request();
    noSubject.subject = '   ';
    noSubject.dueAt = Datetime.now().addDays(1);

    AgentToDoCreateTodoAction.Request noDate = new AgentToDoCreateTodoAction.Request();
    noDate.subject = '제목 있음';
    noDate.dueAt = null;

    Test.startTest();
    List<AgentToDoCreateTodoAction.Result> out = AgentToDoCreateTodoAction.run(
      new List<AgentToDoCreateTodoAction.Request>{ noSubject, noDate }
    );
    Test.stopTest();

    // 예외를 던지면 에이전트가 사용자에게 이유를 설명할 수 없으므로 결과로 돌려줘야 합니다.
    Assert.isFalse(out[0].success, '제목이 없으면 실패해야 합니다');
    Assert.isTrue(
      out[0].errorMessage.contains('제목'),
      '실패 사유에 제목이 언급되어야 합니다'
    );
    Assert.isFalse(out[1].success, '마감 일시가 없으면 실패해야 합니다');
    Assert.isTrue(
      out[1].errorMessage.contains('마감'),
      '실패 사유에 마감 일시가 언급되어야 합니다'
    );
    Assert.areEqual(
      0,
      [SELECT COUNT() FROM AgentToDo_Task__c],
      '실패 시 레코드가 생성되지 않아야 합니다'
    );
  }

  // ── CompleteTodo ────────────────────────────────────────────

  @IsTest
  static void completeTodoByNumberSucceeds() {
    AgentToDo_Task__c t = build(
      '완료 대상',
      Datetime.now().addDays(1),
      'Ready'
    );
    insert t;
    String todoNo = [SELECT Name FROM AgentToDo_Task__c WHERE Id = :t.Id].Name;

    AgentToDoCompleteTodoAction.Request req = new AgentToDoCompleteTodoAction.Request();
    req.todoNumber = todoNo;

    Test.startTest();
    List<AgentToDoCompleteTodoAction.Result> out = AgentToDoCompleteTodoAction.run(
      new List<AgentToDoCompleteTodoAction.Request>{ req }
    );
    Test.stopTest();

    Assert.isTrue(out[0].success, '완료 처리에 성공해야 합니다');
    Assert.isFalse(
      out[0].alreadyDone,
      '처음 완료하는 건이므로 alreadyDone 은 false 여야 합니다'
    );
    Assert.areEqual(
      '완료 대상',
      out[0].subject,
      '대상 제목이 반환되어야 합니다'
    );

    AgentToDo_Task__c saved = [
      SELECT Status__c, Completed_At__c, Last_Agent_Action__c
      FROM AgentToDo_Task__c
      WHERE Id = :t.Id
    ];
    Assert.areEqual('Done', saved.Status__c, '상태가 Done 이어야 합니다');
    Assert.isNotNull(saved.Completed_At__c, '완료 일시가 기록되어야 합니다');
    Assert.areEqual(
      'CompleteTodo',
      saved.Last_Agent_Action__c,
      '실행된 Action 이름이 기록되어야 합니다'
    );
  }

  @IsTest
  static void completeTodoIsIdempotentAndFlagsAlreadyDone() {
    AgentToDo_Task__c t = build('이미 완료', Datetime.now().addDays(1), 'Done');
    t.Completed_At__c = Datetime.now().addDays(-1);
    insert t;
    String todoNo = [SELECT Name FROM AgentToDo_Task__c WHERE Id = :t.Id].Name;

    AgentToDoCompleteTodoAction.Request req = new AgentToDoCompleteTodoAction.Request();
    req.todoNumber = todoNo;

    Test.startTest();
    List<AgentToDoCompleteTodoAction.Result> out = AgentToDoCompleteTodoAction.run(
      new List<AgentToDoCompleteTodoAction.Request>{ req }
    );
    Test.stopTest();

    Assert.isTrue(out[0].success, '이미 완료된 건도 오류가 아니어야 합니다');
    Assert.isTrue(
      out[0].alreadyDone,
      '이미 완료 상태였음을 알려야 에이전트가 "방금 완료했다"고 잘못 말하지 않습니다'
    );
  }

  @IsTest
  static void completeTodoReportsUnknownNumber() {
    AgentToDoCompleteTodoAction.Request req = new AgentToDoCompleteTodoAction.Request();
    req.todoNumber = 'TODO-9999';

    Test.startTest();
    List<AgentToDoCompleteTodoAction.Result> out = AgentToDoCompleteTodoAction.run(
      new List<AgentToDoCompleteTodoAction.Request>{ req }
    );
    Test.stopTest();

    Assert.isFalse(out[0].success, '없는 번호는 실패해야 합니다');
    Assert.isTrue(
      out[0].errorMessage.contains('TODO-9999'),
      '실패 사유에 찾지 못한 번호가 나와야 합니다'
    );
  }

  @IsTest
  static void completeTodoRejectsBlankNumber() {
    AgentToDoCompleteTodoAction.Request req = new AgentToDoCompleteTodoAction.Request();
    req.todoNumber = '';

    Test.startTest();
    List<AgentToDoCompleteTodoAction.Result> out = AgentToDoCompleteTodoAction.run(
      new List<AgentToDoCompleteTodoAction.Request>{ req }
    );
    Test.stopTest();

    Assert.isFalse(out[0].success, '빈 번호는 실패해야 합니다');
    Assert.isTrue(
      out[0].errorMessage.contains('TODO 번호'),
      '실패 사유가 명확해야 합니다'
    );
  }

  // ── 서비스 계층 ─────────────────────────────────────────────

  @IsTest
  static void serviceScopesQueriesToRunningUser() {
    // 실행 사용자 소유가 아닌 레코드는 조회되지 않아야 합니다.
    User other = [
      SELECT Id
      FROM User
      WHERE IsActive = TRUE AND Id != :UserInfo.getUserId()
      LIMIT 1
    ];
    AgentToDo_Task__c mine = build('내 것', Datetime.now().addDays(1), 'Ready');
    AgentToDo_Task__c theirs = build(
      '남의 것',
      Datetime.now().addDays(1),
      'Ready'
    );
    theirs.OwnerId = other.Id;
    insert new List<AgentToDo_Task__c>{ mine, theirs };

    Test.startTest();
    List<AgentToDo_Task__c> rows = AgentToDoActionService.queryByScope('open');
    Test.stopTest();

    Assert.areEqual(1, rows.size(), '실행 사용자 소유 1건만 조회되어야 합니다');
    Assert.areEqual(
      '내 것',
      rows[0].Subject__c,
      '타인 소유 일정은 조회되지 않아야 합니다'
    );
  }

  @IsTest
  static void serviceWeekScopeCoversCurrentWeek() {
    Date weekStart = Date.today().toStartOfWeek();
    insert new List<AgentToDo_Task__c>{
      build(
        '주 시작일',
        Datetime.newInstance(weekStart, Time.newInstance(9, 0, 0, 0)),
        'Ready'
      ),
      build(
        '주 종료일',
        Datetime.newInstance(
          weekStart.addDays(6),
          Time.newInstance(20, 0, 0, 0)
        ),
        'Ready'
      ),
      build(
        '다음 주',
        Datetime.newInstance(
          weekStart.addDays(9),
          Time.newInstance(9, 0, 0, 0)
        ),
        'Ready'
      )
    };

    Test.startTest();
    List<AgentToDo_Task__c> rows = AgentToDoActionService.queryByScope('week');
    Test.stopTest();

    Assert.areEqual(
      2,
      rows.size(),
      '이번 주 경계 안쪽 2건만 조회되어야 합니다'
    );
  }

  @IsTest
  static void serviceFormattingHandlesEmptyInput() {
    Test.startTest();
    String formatted = AgentToDoActionService.formatList(
      new List<AgentToDo_Task__c>()
    );
    String numbers = AgentToDoActionService.numbersOf(null);
    String whenText = AgentToDoActionService.formatWhen(null);
    Test.stopTest();

    Assert.areEqual('', formatted, '빈 목록은 빈 문자열이어야 합니다');
    Assert.areEqual('', numbers, 'null 목록도 빈 문자열이어야 합니다');
    Assert.areEqual('', whenText, 'null 일시는 빈 문자열이어야 합니다');
  }

  @IsTest
  static void serviceStatusLabelsAreKorean() {
    Test.startTest();
    String done = AgentToDoActionService.statusLabel('Done');
    String progress = AgentToDoActionService.statusLabel('In Progress');
    String ready = AgentToDoActionService.statusLabel('Ready');
    Test.stopTest();

    Assert.areEqual('완료', done, 'Done 은 완료로 표기되어야 합니다');
    Assert.areEqual(
      '진행 중',
      progress,
      'In Progress 는 진행 중으로 표기되어야 합니다'
    );
    Assert.areEqual('대기', ready, 'Ready 는 대기로 표기되어야 합니다');
  }
}
