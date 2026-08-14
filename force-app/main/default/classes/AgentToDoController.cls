/**
 * AgentToDo 워크스페이스 화면의 단일 진입점 컨트롤러.
 *
 * 읽기는 한 번의 왕복으로 워크스페이스 전체(일정 목록 + 요약 지표)를 반환하고,
 * 쓰기는 개별 메서드로 분리했습니다. 모든 SOQL/DML 은 USER_MODE 로 실행되어
 * 실행 사용자의 CRUD/FLS 와 공유 규칙을 그대로 따릅니다.
 */
public with sharing class AgentToDoController {
  /** 한 번에 로드할 최대 일정 수. 데모 규모를 넘어서면 월 단위 페이징으로 전환해야 합니다. */
  @TestVisible
  private static final Integer MAX_ROWS = 500;

  // ─────────────────────────────────────────────────────────────
  // DTO
  // ─────────────────────────────────────────────────────────────

  public class TaskDTO {
    @AuraEnabled
    public String recordId;
    @AuraEnabled
    public String todoNumber;
    @AuraEnabled
    public String subject;
    @AuraEnabled
    public Datetime dueAt;
    @AuraEnabled
    public String priority;
    @AuraEnabled
    public String status;
    @AuraEnabled
    public String category;
    @AuraEnabled
    public String description;
    @AuraEnabled
    public Boolean isOverdue;
    @AuraEnabled
    public Boolean createdByAgent;
    @AuraEnabled
    public String lastAgentAction;
    @AuraEnabled
    public String requestedByName;
    @AuraEnabled
    public Boolean isReceived;
    @AuraEnabled
    public Datetime completedAt;
  }

  public class SummaryDTO {
    @AuraEnabled
    public Integer todayCount;
    @AuraEnabled
    public Integer overdueCount;
    @AuraEnabled
    public Integer inProgressCount;
    @AuraEnabled
    public Integer weekDoneCount;
    @AuraEnabled
    public Integer weekTotalCount;
    @AuraEnabled
    public Integer weekCompletionRate;
    @AuraEnabled
    public Integer myTaskCount;
    @AuraEnabled
    public Integer receivedTaskCount;
    @AuraEnabled
    public Integer doneCount;
  }

  public class WorkspaceDTO {
    @AuraEnabled
    public List<TaskDTO> tasks;
    @AuraEnabled
    public SummaryDTO summary;
    @AuraEnabled
    public String userName;
    @AuraEnabled
    public String userTitle;
  }

  // ─────────────────────────────────────────────────────────────
  // 읽기
  // ─────────────────────────────────────────────────────────────

  /**
   * 현재 사용자가 접근 가능한 일정 전체와 화면 상단 요약 지표를 반환합니다.
   * 캘린더·목록·요약이 모두 같은 데이터를 재사용하므로 왕복을 한 번으로 묶었습니다.
   */
  @AuraEnabled(cacheable=true)
  public static WorkspaceDTO getWorkspace() {
    try {
      Id currentUserId = UserInfo.getUserId();

      List<AgentToDo_Task__c> records = [
        SELECT
          Id,
          Name,
          Subject__c,
          Due_At__c,
          Priority__c,
          Status__c,
          Category__c,
          Description__c,
          Is_Overdue__c,
          Created_By_Agent__c,
          Last_Agent_Action__c,
          Completed_At__c,
          Requested_By__c,
          Requested_By__r.Name
        FROM AgentToDo_Task__c
        WITH USER_MODE
        ORDER BY Due_At__c ASC
        LIMIT :MAX_ROWS
      ];

      List<TaskDTO> tasks = new List<TaskDTO>();
      for (AgentToDo_Task__c r : records) {
        tasks.add(toDto(r, currentUserId));
      }

      WorkspaceDTO result = new WorkspaceDTO();
      result.tasks = tasks;
      result.summary = summarize(tasks);
      result.userName = UserInfo.getName();
      result.userTitle = currentUserTitle();
      return result;
    } catch (Exception e) {
      throw new AuraHandledException(
        '일정을 불러오지 못했습니다: ' + e.getMessage()
      );
    }
  }

  // ─────────────────────────────────────────────────────────────
  // 쓰기
  // ─────────────────────────────────────────────────────────────

  /** 새 일정을 생성하고 생성된 레코드를 반환합니다. */
  @AuraEnabled
  public static TaskDTO createTask(
    String subject,
    Datetime dueAt,
    String priority,
    String category,
    String description
  ) {
    if (String.isBlank(subject)) {
      throw new AuraHandledException('일정 제목을 입력해 주세요.');
    }
    if (dueAt == null) {
      throw new AuraHandledException('마감 일시를 입력해 주세요.');
    }
    try {
      AgentToDo_Task__c record = new AgentToDo_Task__c(
        Subject__c = subject.trim(),
        Due_At__c = dueAt,
        Priority__c = String.isBlank(priority) ? 'Medium' : priority,
        Category__c = String.isBlank(category) ? 'Work' : category,
        Description__c = description,
        Status__c = 'Ready'
      );
      Database.insert(record, AccessLevel.USER_MODE);
      return readOne(record.Id);
    } catch (DmlException e) {
      throw new AuraHandledException(
        '일정을 저장하지 못했습니다: ' + e.getDmlMessage(0)
      );
    }
  }

  /** 일정을 완료 처리합니다. 이미 완료된 일정은 그대로 반환합니다. */
  @AuraEnabled
  public static TaskDTO completeTask(String taskId) {
    return applyStatus(taskId, 'Done');
  }

  /** 일정 상태를 변경합니다. Done 으로 바뀔 때 완료 일시를 함께 기록합니다. */
  @AuraEnabled
  public static TaskDTO updateStatus(String taskId, String status) {
    return applyStatus(taskId, status);
  }

  // ─────────────────────────────────────────────────────────────
  // 내부 헬퍼
  // ─────────────────────────────────────────────────────────────

  private static TaskDTO applyStatus(String taskId, String status) {
    if (String.isBlank(taskId)) {
      throw new AuraHandledException('대상 일정을 찾을 수 없습니다.');
    }
    Set<String> allowed = new Set<String>{ 'Ready', 'In Progress', 'Done' };
    if (!allowed.contains(status)) {
      throw new AuraHandledException('허용되지 않은 상태입니다: ' + status);
    }
    try {
      AgentToDo_Task__c record = new AgentToDo_Task__c(
        Id = (Id) taskId,
        Status__c = status,
        Completed_At__c = (status == 'Done') ? Datetime.now() : null
      );
      Database.update(record, AccessLevel.USER_MODE);
      return readOne(record.Id);
    } catch (DmlException e) {
      throw new AuraHandledException(
        '상태를 변경하지 못했습니다: ' + e.getDmlMessage(0)
      );
    }
  }

  private static TaskDTO readOne(Id recordId) {
    List<AgentToDo_Task__c> rows = [
      SELECT
        Id,
        Name,
        Subject__c,
        Due_At__c,
        Priority__c,
        Status__c,
        Category__c,
        Description__c,
        Is_Overdue__c,
        Created_By_Agent__c,
        Last_Agent_Action__c,
        Completed_At__c,
        Requested_By__c,
        Requested_By__r.Name
      FROM AgentToDo_Task__c
      WHERE Id = :recordId
      WITH USER_MODE
      LIMIT 1
    ];
    if (rows.isEmpty()) {
      throw new AuraHandledException('저장된 일정을 다시 읽지 못했습니다.');
    }
    return toDto(rows[0], UserInfo.getUserId());
  }

  private static TaskDTO toDto(AgentToDo_Task__c r, Id currentUserId) {
    TaskDTO d = new TaskDTO();
    d.recordId = r.Id;
    d.todoNumber = r.Name;
    d.subject = r.Subject__c;
    d.dueAt = r.Due_At__c;
    d.priority = r.Priority__c;
    d.status = r.Status__c;
    d.category = r.Category__c;
    d.description = r.Description__c;
    d.isOverdue = r.Is_Overdue__c;
    d.createdByAgent = r.Created_By_Agent__c;
    d.lastAgentAction = r.Last_Agent_Action__c;
    d.completedAt = r.Completed_At__c;
    d.requestedByName = (r.Requested_By__c == null)
      ? null
      : r.Requested_By__r.Name;
    // 타인이 요청한 작업만 "받은 작업"으로 분류합니다.
    d.isReceived = (r.Requested_By__c != null &&
    r.Requested_By__c != currentUserId);
    return d;
  }

  private static SummaryDTO summarize(List<TaskDTO> tasks) {
    Date today = Date.today();
    Date weekStart = today.toStartOfWeek();
    Date weekEnd = weekStart.addDays(6);

    SummaryDTO s = new SummaryDTO();
    s.todayCount = 0;
    s.overdueCount = 0;
    s.inProgressCount = 0;
    s.weekDoneCount = 0;
    s.weekTotalCount = 0;
    s.weekCompletionRate = 0;
    s.myTaskCount = 0;
    s.receivedTaskCount = 0;
    s.doneCount = 0;

    for (TaskDTO t : tasks) {
      Date due = (t.dueAt == null) ? null : t.dueAt.date();
      Boolean isDone = (t.status == 'Done');

      if (due == today) {
        s.todayCount++;
      }
      if (t.isOverdue == true) {
        s.overdueCount++;
      }
      if (t.status == 'In Progress') {
        s.inProgressCount++;
      }
      if (isDone) {
        s.doneCount++;
      }
      // 사이드바 배지는 각 메뉴가 실제로 보여줄 건수와 같아야 합니다.
      // "내 일정"·"받은 작업" 화면은 완료 건을 제외하므로 집계에서도 제외합니다.
      if (!isDone) {
        if (t.isReceived == true) {
          s.receivedTaskCount++;
        } else {
          s.myTaskCount++;
        }
      }
      if (due != null && due >= weekStart && due <= weekEnd) {
        s.weekTotalCount++;
        if (isDone) {
          s.weekDoneCount++;
        }
      }
    }

    if (s.weekTotalCount > 0) {
      s.weekCompletionRate = (Integer) Math.round(
        (Decimal.valueOf(s.weekDoneCount) / Decimal.valueOf(s.weekTotalCount)) *
        100
      );
    }
    return s;
  }

  private static String currentUserTitle() {
    List<User> rows = [
      SELECT Title
      FROM User
      WHERE Id = :UserInfo.getUserId()
      WITH USER_MODE
      LIMIT 1
    ];
    String title = rows.isEmpty() ? null : rows[0].Title;
    return String.isBlank(title) ? 'AgentToDo User' : title;
  }
}
