import { LightningElement, api } from "lwc";
import { decorateTask, formatDateStamp } from "c/agentToDoUtils";

/**
 * 우측 "오늘의 일정" 패널이자, 목록형 메뉴(오늘·내 일정·받은 작업·완료 일정)의 본문입니다.
 * variant="list" 로 쓰면 날짜 머리말과 브리핑 카드를 감춥니다.
 */
export default class DailyAgenda extends LightningElement {
  @api tasks = [];
  @api dateKey;
  @api heading;
  @api variant = "panel";

  get isPanel() {
    return this.variant !== "list";
  }

  get items() {
    return (this.tasks || [])
      .slice()
      .sort((a, b) => new Date(a.dueAt) - new Date(b.dueAt))
      .map(decorateTask);
  }

  get hasItems() {
    return this.items.length > 0;
  }

  get dateStamp() {
    return this.dateKey ? formatDateStamp(this.dateKey) : "";
  }

  get title() {
    return this.heading || "오늘의 일정";
  }

  get countLabel() {
    const total = this.items.length;
    const high = this.items.filter((t) => t.priority === "High").length;
    return `전체 ${total}건 · 높은 우선순위 ${high}건`;
  }

  /** 브리핑 문구는 데이터에서 직접 만듭니다. 에이전트 호출 없이도 의미가 있어야 합니다. */
  get briefing() {
    const overdue = this.items.filter((t) => t.isOverdue).length;
    const pending = this.items.filter((t) => !t.isDone).length;
    if (!this.hasItems) {
      return "선택한 날짜에 등록된 일정이 없습니다.";
    }
    if (overdue > 0) {
      return `기한이 지난 일정이 ${overdue}건 있습니다. 먼저 처리하는 것이 좋습니다.`;
    }
    if (pending === 0) {
      return "이 날짜의 일정을 모두 완료했습니다.";
    }
    return `남은 일정 ${pending}건이 있습니다. 우선순위가 높은 것부터 진행하세요.`;
  }

  handleSelect(event) {
    const recordId = event.currentTarget.dataset.id;
    this.dispatchEvent(new CustomEvent("taskselect", { detail: { recordId } }));
  }

  handleComplete(event) {
    event.stopPropagation();
    const recordId = event.currentTarget.dataset.id;
    this.dispatchEvent(
      new CustomEvent("taskcomplete", { detail: { recordId } })
    );
  }

  handleAskAgent() {
    this.dispatchEvent(new CustomEvent("askagent"));
  }
}
