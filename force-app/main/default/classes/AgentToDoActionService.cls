/**
 * AgentToDo Agent Action 들이 공유하는 조회·변경 로직.
 *
 * Apex 클래스 하나에 @InvocableMethod 는 하나만 둘 수 있어 Action 마다 클래스를 나눴습니다.
 * 같은 SOQL/DML 이 네 벌로 복제되는 것을 막기 위해 실제 동작은 전부 여기에 모읍니다.
 *
 * 보안 규칙 (Agent Spec 의 "실행 사용자와 데이터 범위" 참조):
 *   - 모든 조회/변경은 WITH USER_MODE + 실행 사용자 소유 레코드로 제한합니다.
 *   - 어떤 Action 도 사용자 Id 를 입력으로 받지 않습니다. 받으면 프롬프트 주입으로
 *     타인의 일정을 열람할 수 있는 통로가 생깁니다.
 */
public with sharing class AgentToDoActionService {
  @TestVisible
  private static final Integer MAX_ROWS = 50;

  public class ActionException extends Exception {
  }

  // ─────────────────────────────────────────────────────────────
  // 조회
  // ─────────────────────────────────────────────────────────────

  /**
   * scope 별 일정 조회.
   * today = 오늘 마감, week = 이번 주 마감, open = 미완료 전체. 기본값 today.
   */
  public static List<AgentToDo_Task__c> queryByScope(String scope) {
    String normalized = String.isBlank(scope)
      ? 'today'
      : scope.trim().toLowerCase();
    Id owner = UserInfo.getUserId();

    if (normalized == 'open') {
      return [
        SELECT
          Id,
          Name,
          Subject__c,
          Due_At__c,
          Priority__c,
          Status__c,
          Category__c,
          Is_Overdue__c
        FROM AgentToDo_Task__c
        WHERE OwnerId = :owner AND Status__c != 'Done'
        WITH USER_MODE
        ORDER BY Due_At__c ASC
        LIMIT :MAX_ROWS
      ];
    }

    Date rangeStart = Date.today();
    Date rangeEnd = Date.today();
    if (normalized == 'week') {
      rangeStart = Date.today().toStartOfWeek();
      rangeEnd = rangeStart.addDays(6);
    }

    Datetime from1 = Datetime.newInstance(
      rangeStart,
      Time.newInstance(0, 0, 0, 0)
    );
    Datetime to1 = Datetime.newInstance(
      rangeEnd.addDays(1),
      Time.newInstance(0, 0, 0, 0)
    );

    return [
      SELECT
        Id,
        Name,
        Subject__c,
        Due_At__c,
        Priority__c,
        Status__c,
        Category__c,
        Is_Overdue__c
      FROM AgentToDo_Task__c
      WHERE OwnerId = :owner AND Due_At__c >= :from1 AND Due_At__c < :to1
      WITH USER_MODE
      ORDER BY Due_At__c ASC
      LIMIT :MAX_ROWS
    ];
  }

  /** 미완료 상태에서 마감이 지난 일정. */
  public static List<AgentToDo_Task__c> queryOverdue() {
    Id owner = UserInfo.getUserId();
    return [
      SELECT
        Id,
        Name,
        Subject__c,
        Due_At__c,
        Priority__c,
        Status__c,
        Category__c,
        Is_Overdue__c
      FROM AgentToDo_Task__c
      WHERE OwnerId = :owner AND Is_Overdue__c = TRUE
      WITH USER_MODE
      ORDER BY Due_At__c ASC
      LIMIT :MAX_ROWS
    ];
  }

  // ─────────────────────────────────────────────────────────────
  // 변경
  // ─────────────────────────────────────────────────────────────

  /** 일정을 생성하고 생성된 레코드를 다시 읽어 반환합니다. */
  public static AgentToDo_Task__c createTodo(
    String subject,
    Datetime dueAt,
    String priority,
    String category
  ) {
    if (String.isBlank(subject)) {
      throw new ActionException('일정 제목이 필요합니다.');
    }
    if (dueAt == null) {
      throw new ActionException('마감 일시가 필요합니다.');
    }

    AgentToDo_Task__c record = new AgentToDo_Task__c(
      Subject__c = subject.trim(),
      Due_At__c = dueAt,
      Priority__c = normalizePriority(priority),
      Category__c = normalizeCategory(category),
      Status__c = 'Ready',
      // 상세 드로어의 "Agent 생성 여부"·"실행된 Agent Action" 표시 근거가 됩니다.
      Created_By_Agent__c = true,
      Last_Agent_Action__c = 'CreateTodo'
    );
    Database.insert(record, AccessLevel.USER_MODE);

    List<AgentToDo_Task__c> rows = [
      SELECT
        Id,
        Name,
        Subject__c,
        Due_At__c,
        Priority__c,
        Status__c,
        Category__c,
        Is_Overdue__c
      FROM AgentToDo_Task__c
      WHERE Id = :record.Id
      WITH USER_MODE
      LIMIT 1
    ];
    if (rows.isEmpty()) {
      throw new ActionException('생성한 일정을 다시 읽지 못했습니다.');
    }
    return rows[0];
  }

  /**
   * TODO 번호로 일정을 완료 처리합니다.
   * 이미 완료된 건은 변경하지 않고 그대로 돌려주어, 에이전트가
   * "방금 완료했다"고 잘못 말하지 않도록 합니다.
   */
  public static AgentToDo_Task__c completeByNumber(String todoNumber) {
    AgentToDo_Task__c record = findByNumber(todoNumber);
    if (record.Status__c == 'Done') {
      return record;
    }
    record.Status__c = 'Done';
    record.Completed_At__c = Datetime.now();
    record.Last_Agent_Action__c = 'CompleteTodo';
    Database.update(record, AccessLevel.USER_MODE);
    return record;
  }

  /** TODO 번호로 단건 조회. 못 찾으면 사용자에게 보여줄 메시지와 함께 실패합니다. */
  public static AgentToDo_Task__c findByNumber(String todoNumber) {
    if (String.isBlank(todoNumber)) {
      throw new ActionException('TODO 번호가 필요합니다.');
    }
    String normalized = todoNumber.trim().toUpperCase();
    Id owner = UserInfo.getUserId();

    List<AgentToDo_Task__c> rows = [
      SELECT
        Id,
        Name,
        Subject__c,
        Due_At__c,
        Priority__c,
        Status__c,
        Category__c,
        Completed_At__c,
        Last_Agent_Action__c
      FROM AgentToDo_Task__c
      WHERE OwnerId = :owner AND Name = :normalized
      WITH USER_MODE
      LIMIT 1
    ];
    if (rows.isEmpty()) {
      throw new ActionException(
        normalized + ' 번호의 일정을 찾을 수 없습니다.'
      );
    }
    return rows[0];
  }

  // ─────────────────────────────────────────────────────────────
  // 표현
  // ─────────────────────────────────────────────────────────────

  /**
   * 에이전트가 그대로 인용하거나 재구성할 수 있는 줄 단위 요약.
   *
   * 구조화된 객체 대신 문자열을 돌려주는 이유: @InvocableVariable 로 커스텀 객체를
   * 주고받으려면 Custom Lightning Type 정의가 필요합니다. 이 에이전트가 하는 일은
   * 목록을 읽어 사람에게 말해 주는 것이므로, 원시 타입만 써서 호환성 문제를 없앴습니다.
   */
  public static String formatList(List<AgentToDo_Task__c> rows) {
    if (rows == null || rows.isEmpty()) {
      return '';
    }
    List<String> lines = new List<String>();
    for (AgentToDo_Task__c r : rows) {
      lines.add(
        r.Name +
          ' | ' +
          r.Subject__c +
          ' | ' +
          formatWhen(r.Due_At__c) +
          ' | ' +
          r.Priority__c +
          ' | ' +
          statusLabel(r.Status__c) +
          (r.Is_Overdue__c == true ? ' | 기한 초과' : '')
      );
    }
    return String.join(lines, '\n');
  }

  /** 대화 변수 last_todo_numbers 에 넣을 번호 목록. */
  public static String numbersOf(List<AgentToDo_Task__c> rows) {
    if (rows == null || rows.isEmpty()) {
      return '';
    }
    List<String> numbers = new List<String>();
    for (AgentToDo_Task__c r : rows) {
      numbers.add(r.Name);
    }
    return String.join(numbers, ',');
  }

  public static String formatWhen(Datetime value) {
    if (value == null) {
      return '';
    }
    return value.format('M월 d일 HH:mm');
  }

  public static String statusLabel(String status) {
    if (status == 'Done') {
      return '완료';
    }
    if (status == 'In Progress') {
      return '진행 중';
    }
    return '대기';
  }

  // ─────────────────────────────────────────────────────────────
  // 입력 정규화 — 에이전트가 임의 문자열을 넘겨도 피클리스트를 깨지 않게 합니다.
  // ─────────────────────────────────────────────────────────────

  @TestVisible
  private static String normalizePriority(String value) {
    if (String.isBlank(value)) {
      return 'Medium';
    }
    String v = value.trim().toLowerCase();
    if (v == 'high' || v == '높음' || v == '긴급') {
      return 'High';
    }
    if (v == 'low' || v == '낮음') {
      return 'Low';
    }
    return 'Medium';
  }

  @TestVisible
  private static String normalizeCategory(String value) {
    if (String.isBlank(value)) {
      return 'Work';
    }
    String v = value.trim().toLowerCase();
    if (v == 'meeting' || v == '회의') {
      return 'Meeting';
    }
    if (v == 'development' || v == '개발') {
      return 'Development';
    }
    if (v == 'review' || v == '검토') {
      return 'Review';
    }
    return 'Work';
  }
}
