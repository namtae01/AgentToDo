import { LightningElement, api, track } from "lwc";

import startSession from "@salesforce/apex/AgentToDoAgentService.startSession";
import sendMessage from "@salesforce/apex/AgentToDoAgentService.sendMessage";
import endSession from "@salesforce/apex/AgentToDoAgentService.endSession";

/**
 * AgentToDo Assistant 대화 패널.
 *
 * Agentforce Agent API 에 연결되어 있습니다. 패널을 열면 세션을 시작하고,
 * 발화를 보내면 에이전트가 Apex Agent Action 을 실행한 뒤 응답을 돌려줍니다.
 * 패널을 닫으면 세션을 종료합니다.
 */
const QUICK_PROMPTS = [
  { key: "brief", label: "오늘 브리핑", text: "오늘 일정을 브리핑해줘." },
  { key: "overdue", label: "기한 초과", text: "기한이 지난 일정을 알려줘." },
  {
    key: "create",
    label: "일정 만들기",
    text: "내일 오후 3시에 일정 하나 만들어줘."
  }
];

export default class AgentAssistantDrawer extends LightningElement {
  @api tasks = [];
  @api summary = {};

  @track messages = [];
  draft = "";
  nextId = 1;

  sessionId = null;
  sequenceId = 0;
  isBusy = false;
  connectError = null;

  // ── 수명 주기 ───────────────────────────────────────────────

  connectedCallback() {
    this.openSession();
  }

  disconnectedCallback() {
    // 세션을 남기면 서버 자원이 붙잡히므로 패널을 닫을 때 정리합니다.
    if (this.sessionId) {
      endSession({ sessionId: this.sessionId }).catch(() => {
        // 종료 실패는 사용자 경험에 영향이 없으므로 조용히 넘어갑니다.
      });
      this.sessionId = null;
    }
  }

  async openSession() {
    this.isBusy = true;
    this.connectError = null;
    try {
      const reply = await startSession();
      if (reply.success) {
        this.sessionId = reply.sessionId;
        this.sequenceId = 0;
        if (reply.message) {
          this.pushAgent(reply.message, reply.actions);
        }
      } else {
        this.connectError = reply.errorMessage;
      }
    } catch (error) {
      this.connectError = this.readError(error);
    } finally {
      this.isBusy = false;
    }
  }

  // ── 파생 상태 ───────────────────────────────────────────────

  get quickPrompts() {
    return QUICK_PROMPTS;
  }

  get canSend() {
    return (
      !!this.draft && !!this.draft.trim() && !!this.sessionId && !this.isBusy
    );
  }

  get isDisabled() {
    return !this.canSend;
  }

  get hasError() {
    return !!this.connectError;
  }

  get statusText() {
    if (this.connectError) {
      return "● 연결되지 않음";
    }
    if (!this.sessionId) {
      return "● 연결 중...";
    }
    return "● 일정 데이터와 연결됨";
  }

  get statusClass() {
    return this.connectError
      ? "identity__status identity__status--error"
      : "identity__status";
  }

  // ── 입력 ────────────────────────────────────────────────────

  handleDraftChange(event) {
    this.draft = event.target.value;
  }

  handleKeyDown(event) {
    if (event.key === "Enter" && !event.shiftKey) {
      event.preventDefault();
      this.handleSend();
    }
  }

  handleQuick(event) {
    const key = event.currentTarget.dataset.key;
    const prompt = QUICK_PROMPTS.find((p) => p.key === key);
    if (prompt && !this.isBusy && this.sessionId) {
      this.submit(prompt.text);
    }
  }

  handleSend() {
    if (!this.canSend) {
      return;
    }
    const text = this.draft.trim();
    this.draft = "";
    this.submit(text);
  }

  handleClose() {
    this.dispatchEvent(new CustomEvent("close"));
  }

  handleRetry() {
    this.openSession();
  }

  // ── 대화 ────────────────────────────────────────────────────

  async submit(text) {
    this.pushUser(text);
    this.isBusy = true;
    this.sequenceId += 1;

    try {
      const reply = await sendMessage({
        sessionId: this.sessionId,
        sequenceId: this.sequenceId,
        text
      });

      if (reply.success) {
        this.pushAgent(reply.message, reply.actions);
        // 에이전트가 일정을 생성·완료 처리했을 수 있으므로 화면을 갱신합니다.
        this.dispatchEvent(new CustomEvent("refresh"));
      } else {
        this.pushAgent(reply.errorMessage, [], true);
      }
    } catch (error) {
      this.pushAgent(this.readError(error), [], true);
    } finally {
      this.isBusy = false;
    }
  }

  pushUser(text) {
    this.messages = [
      ...this.messages,
      {
        id: `m${this.nextId++}`,
        text,
        cssClass: "bubble bubble--user",
        actions: [],
        hasActions: false
      }
    ];
  }

  pushAgent(text, actions, isError) {
    const list = (actions || []).map((a, index) => ({
      key: `a${this.nextId}-${index}`,
      name: a.name,
      detail: a.detail
    }));
    this.messages = [
      ...this.messages,
      {
        id: `m${this.nextId++}`,
        text: text || "(응답이 비어 있습니다)",
        cssClass: isError ? "bubble bubble--error" : "bubble bubble--agent",
        actions: list,
        hasActions: list.length > 0
      }
    ];
  }

  readError(error) {
    if (!error) {
      return "알 수 없는 오류가 발생했습니다.";
    }
    if (error.body && error.body.message) {
      return error.body.message;
    }
    if (error.message) {
      return error.message;
    }
    return String(error);
  }

  renderedCallback() {
    const list = this.template.querySelector(".thread");
    if (list) {
      list.scrollTop = list.scrollHeight;
    }
  }
}
