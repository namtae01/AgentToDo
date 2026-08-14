import { LightningElement, api } from "lwc";

export default class ScheduleSummary extends LightningElement {
  @api summary = {};

  get tiles() {
    const s = this.summary || {};
    return [
      {
        key: "today",
        index: "1",
        label: "오늘 일정",
        value: s.todayCount || 0,
        unit: "건",
        tone: "blue"
      },
      {
        key: "overdue",
        index: "2",
        label: "기한 초과",
        value: s.overdueCount || 0,
        unit: "건",
        tone: "red"
      },
      {
        key: "progress",
        index: "3",
        label: "진행 중",
        value: s.inProgressCount || 0,
        unit: "건",
        tone: "amber"
      },
      {
        key: "week",
        index: "4",
        label: "이번 주 완료",
        value: s.weekDoneCount || 0,
        unit: `${s.weekTotalCount || 0}건 중`,
        tone: "purple"
      }
    ].map((t) => ({
      ...t,
      badgeClass: `tile__badge tile__badge--${t.tone}`
    }));
  }
}
