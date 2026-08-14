import { LightningElement, track, wire } from "lwc";
import { refreshApex } from "@salesforce/apex";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import { subscribe, unsubscribe, onError } from "lightning/empApi";
import CURRENT_USER_ID from "@salesforce/user/Id";

import getWorkspace from "@salesforce/apex/AgentToDoController.getWorkspace";
import createTask from "@salesforce/apex/AgentToDoController.createTask";
import completeTask from "@salesforce/apex/AgentToDoController.completeTask";

import {
  dateKey,
  formatDateLong,
  filterByMenu,
  matchesSearch
} from "c/agentToDoUtils";

const MENU_TITLES = {
  today: "오늘",
  calendar: "캘린더",
  mine: "내 일정",
  received: "받은 작업",
  done: "완료 일정"
};

export default class AgentToDoShell extends LightningElement {
  @track activeMenu = "calendar";
  @track selectedDateKey = dateKey(new Date());
  @track visibleYear = new Date().getFullYear();
  @track visibleMonth = new Date().getMonth();
  @track searchTerm = "";

  @track selectedTask = null;
  @track showEditor = false;
  @track showAssistant = false;

  tasks = [];
  summary = {};
  userName = "";
  userTitle = "";
  isLoading = true;
  loadError = null;

  wiredResult;

  /**
   * 에이전트가 보내는 UI 명령 채널.
   *
   * 에이전트는 서버에서 실행되어 화면을 직접 바꿀 수 없고, Agent API 동기
   * 응답에는 어떤 액션이 실행됐는지가 실리지 않습니다. 그래서 네비게이션
   * 액션이 발행한 플랫폼 이벤트를 여기서 구독해 화면을 전환합니다.
   */
  uiCommandChannel = "/event/AgentToDo_UI_Command__e";
  uiCommandSubscription = null;

  connectedCallback() {
    onError((error) => {
      // 구독이 끊겨도 앱의 나머지 기능은 그대로 쓸 수 있어야 합니다.
      // eslint-disable-next-line no-console
      console.error("AgentToDo UI 명령 채널 오류", JSON.stringify(error));
    });

    subscribe(this.uiCommandChannel, -1, (message) => {
      this.handleUiCommand(message);
    })
      .then((response) => {
        this.uiCommandSubscription = response;
      })
      .catch(() => {
        // 구독 실패 시 화면 전환만 동작하지 않고 나머지는 정상입니다.
      });
  }

  disconnectedCallback() {
    if (this.uiCommandSubscription) {
      unsubscribe(this.uiCommandSubscription);
      this.uiCommandSubscription = null;
    }
  }

  /** 플랫폼 이벤트 수신 — 내 사용자에게 보낸 navigate 명령만 처리합니다. */
  handleUiCommand(message) {
    const payload =
      message && message.data && message.data.payload
        ? message.data.payload
        : null;
    if (!payload) {
      return;
    }
    // 플랫폼 이벤트는 구독자 전원에게 전달되므로 대상 사용자를 반드시 확인합니다.
    if (payload.Target_User_Id__c !== CURRENT_USER_ID) {
      return;
    }
    if (payload.Command__c !== "navigate") {
      return;
    }

    const screen = payload.Screen__c;
    if (screen === "assistant") {
      this.showAssistant = true;
      return;
    }
    if (MENU_TITLES[screen]) {
      this.activeMenu = screen;
      this.selectedTask = null;
    }
  }

  @wire(getWorkspace)
  handleWorkspace(result) {
    this.wiredResult = result;
    const { data, error } = result;
    if (data) {
      this.tasks = data.tasks || [];
      this.summary = data.summary || {};
      this.userName = data.userName;
      this.userTitle = data.userTitle;
      this.loadError = null;
      this.isLoading = false;
      this.syncSelectedTask();
    } else if (error) {
      this.loadError = this.readError(error);
      this.isLoading = false;
    }
  }

  // ── 파생 상태 ────────────────────────────────────────────────

  get todayKey() {
    return dateKey(new Date());
  }

  get headerDate() {
    return formatDateLong(new Date());
  }

  get pageTitle() {
    return MENU_TITLES[this.activeMenu] || "캘린더";
  }

  get isCalendarView() {
    return this.activeMenu === "calendar";
  }

  /** 검색어가 적용된 전체 일정. 캘린더와 목록이 같은 기준을 쓰도록 한곳에서 계산합니다. */
  get visibleTasks() {
    return this.tasks.filter((t) => matchesSearch(t, this.searchTerm));
  }

  /** 목록형 화면(오늘·내 일정·받은 작업·완료 일정)에 뿌릴 일정. */
  get listTasks() {
    return filterByMenu(this.visibleTasks, this.activeMenu, this.todayKey);
  }

  get listIsEmpty() {
    return !this.isLoading && this.listTasks.length === 0;
  }

  /** 우측 패널에 보여줄, 선택된 날짜의 일정. */
  get agendaTasks() {
    return this.visibleTasks.filter(
      (t) => dateKey(t.dueAt) === this.selectedDateKey
    );
  }

  get hasError() {
    return !!this.loadError;
  }

  get assistantButtonClass() {
    return this.showAssistant ? "fab fab--active" : "fab";
  }

  // ── 이벤트 처리 ──────────────────────────────────────────────

  handleMenuSelect(event) {
    const menu = event.detail.menu;
    if (menu === "assistant") {
      this.showAssistant = true;
      return;
    }
    this.activeMenu = menu;
    this.selectedTask = null;
  }

  handleSearch(event) {
    this.searchTerm = event.target.value;
  }

  handleDateSelect(event) {
    this.selectedDateKey = event.detail.dateKey;
  }

  handleMonthChange(event) {
    this.visibleYear = event.detail.year;
    this.visibleMonth = event.detail.month;
  }

  handleGoToday() {
    const now = new Date();
    this.visibleYear = now.getFullYear();
    this.visibleMonth = now.getMonth();
    this.selectedDateKey = dateKey(now);
  }

  handleTaskSelect(event) {
    const id = event.detail.recordId;
    this.selectedTask = this.tasks.find((t) => t.recordId === id) || null;
  }

  handleDrawerClose() {
    this.selectedTask = null;
  }

  handleEditorOpen(event) {
    // 빈 날짜를 눌러 들어온 경우 그 날짜를 기본값으로 씁니다.
    if (event && event.detail && event.detail.dateKey) {
      this.selectedDateKey = event.detail.dateKey;
    }
    this.showEditor = true;
  }

  handleEditorClose() {
    this.showEditor = false;
  }

  handleAssistantOpen() {
    this.showAssistant = true;
  }

  handleAssistantClose() {
    this.showAssistant = false;
  }

  async handleTaskCreate(event) {
    const form = event.detail;
    try {
      await createTask({
        subject: form.subject,
        dueAt: form.dueAt,
        priority: form.priority,
        category: form.category,
        description: form.description
      });
      this.showEditor = false;
      this.selectedDateKey = dateKey(form.dueAt);
      await this.reload();
      this.toast("일정을 추가했습니다", form.subject, "success");
    } catch (error) {
      this.toast("일정을 추가하지 못했습니다", this.readError(error), "error");
    }
  }

  async handleTaskComplete(event) {
    const recordId = event.detail.recordId;
    try {
      await completeTask({ taskId: recordId });
      await this.reload();
      this.toast("완료 처리했습니다", "", "success");
    } catch (error) {
      this.toast("완료 처리하지 못했습니다", this.readError(error), "error");
    }
  }

  // ── 내부 ────────────────────────────────────────────────────

  async reload() {
    if (this.wiredResult) {
      await refreshApex(this.wiredResult);
    }
  }

  /** 새로고침 후에도 열려 있던 상세 드로어가 최신 값을 보여주도록 맞춥니다. */
  syncSelectedTask() {
    if (!this.selectedTask) {
      return;
    }
    const fresh = this.tasks.find(
      (t) => t.recordId === this.selectedTask.recordId
    );
    this.selectedTask = fresh || null;
  }

  readError(error) {
    if (!error) {
      return "알 수 없는 오류";
    }
    if (error.body && error.body.message) {
      return error.body.message;
    }
    if (error.message) {
      return error.message;
    }
    return String(error);
  }

  toast(title, message, variant) {
    this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
  }
}
