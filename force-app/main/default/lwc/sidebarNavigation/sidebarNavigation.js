import { LightningElement, api } from "lwc";

const SECTIONS = [
  {
    key: "today",
    label: "TODAY",
    items: [
      {
        menu: "today",
        label: "오늘",
        icon: "utility:clock",
        countKey: "todayCount"
      },
      {
        menu: "calendar",
        label: "캘린더",
        icon: "utility:event",
        countKey: null
      }
    ]
  },
  {
    key: "schedule",
    label: "SCHEDULE",
    items: [
      {
        menu: "mine",
        label: "내 일정",
        icon: "utility:list",
        countKey: "myTaskCount"
      },
      {
        menu: "received",
        label: "받은 작업",
        icon: "utility:share_post",
        countKey: "receivedTaskCount"
      },
      {
        menu: "done",
        label: "완료 일정",
        icon: "utility:check",
        countKey: "doneCount"
      }
    ]
  },
  {
    key: "agent",
    label: "AGENT",
    items: [
      {
        menu: "assistant",
        label: "AI 어시스턴트",
        icon: "utility:einstein",
        countKey: null
      }
    ]
  }
];

export default class SidebarNavigation extends LightningElement {
  @api activeMenu = "calendar";
  @api summary = {};
  @api userName = "";
  @api userTitle = "";

  get sections() {
    const s = this.summary || {};
    return SECTIONS.map((section) => ({
      ...section,
      items: section.items.map((item) => {
        const count = item.countKey ? s[item.countKey] : null;
        const isActive = item.menu === this.activeMenu;
        return {
          ...item,
          isActive,
          count,
          showCount: count !== null && count !== undefined && count > 0,
          itemClass: isActive ? "nav-item nav-item--active" : "nav-item"
        };
      })
    }));
  }

  get completionRate() {
    return (this.summary && this.summary.weekCompletionRate) || 0;
  }

  get progressStyle() {
    return `width: ${this.completionRate}%;`;
  }

  get progressLabel() {
    const s = this.summary || {};
    const total = s.weekTotalCount || 0;
    const done = s.weekDoneCount || 0;
    return `${total}개 중 ${done}개 일정 완료`;
  }

  get initials() {
    const name = (this.userName || "").trim();
    if (!name) {
      return "AT";
    }
    // 한글 이름은 성을 제외한 이름 두 글자, 영문은 이니셜 두 글자를 씁니다.
    const parts = name.split(/\s+/);
    if (parts.length > 1) {
      return (parts[0][0] + parts[1][0]).toUpperCase();
    }
    return name.slice(0, 2).toUpperCase();
  }

  handleClick(event) {
    const menu = event.currentTarget.dataset.menu;
    this.dispatchEvent(new CustomEvent("menuselect", { detail: { menu } }));
  }
}
