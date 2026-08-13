import { LightningElement, api } from "lwc";
import {
  formatTime,
  formatDateLong,
  statusLabel,
  toneOf
} from "c/agentToDoUtils";

export default class TaskDetailDrawer extends LightningElement {
  @api task;

  get dateLabel() {
    return this.task ? formatDateLong(this.task.dueAt) : "";
  }

  get timeLabel() {
    return this.task ? formatTime(this.task.dueAt) : "";
  }

  get statusText() {
    return this.task ? statusLabel(this.task.status) : "";
  }

  get toneClass() {
    return `accent accent--${toneOf(this.task)}`;
  }

  get isDone() {
    return this.task && this.task.status === "Done";
  }

  get completeLabel() {
    return this.isDone ? "완료됨" : "완료 처리";
  }

  get agentCreatedText() {
    return this.task && this.task.createdByAgent
      ? "예 · AgentToDo Assistant"
      : "아니오";
  }

  get agentActionText() {
    return (this.task && this.task.lastAgentAction) || "실행 기록 없음";
  }

  get requesterText() {
    return (this.task && this.task.requestedByName) || "본인";
  }

  get descriptionText() {
    return (
      (this.task && this.task.description) || "등록된 상세 설명이 없습니다."
    );
  }

  get overdueText() {
    return this.task && this.task.isOverdue ? "기한 초과" : "정상";
  }

  handleClose() {
    this.dispatchEvent(new CustomEvent("close"));
  }

  handleComplete() {
    if (this.isDone) {
      return;
    }
    this.dispatchEvent(
      new CustomEvent("complete", { detail: { recordId: this.task.recordId } })
    );
  }

  handleAskAgent() {
    this.dispatchEvent(new CustomEvent("askagent"));
  }
}
