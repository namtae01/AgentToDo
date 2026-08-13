import { LightningElement, api } from "lwc";
import {
  dateKey,
  buildMonthGrid,
  formatMonthTitle,
  toneOf,
  matchesSearch
} from "c/agentToDoUtils";

/** 한 셀에 직접 노출할 일정 수. 넘치면 "+N개 더보기"로 접습니다. */
const MAX_CHIPS_PER_DAY = 3;

const WEEKDAYS = ["일", "월", "화", "수", "목", "금", "토"];

export default class AgentToDoCalendar extends LightningElement {
  @api tasks = [];
  @api year;
  @api month;
  @api selectedDateKey;
  @api searchTerm = "";

  expandedDayKey = null;

  get monthTitle() {
    return formatMonthTitle(this.year, this.month);
  }

  get weekdays() {
    return WEEKDAYS.map((label, index) => ({
      label,
      key: label,
      className:
        index === 0
          ? "weekday weekday--sun"
          : index === 6
            ? "weekday weekday--sat"
            : "weekday"
    }));
  }

  /** 날짜키 → 일정 배열. 격자를 만들 때마다 다시 계산하지 않도록 한 번만 묶습니다. */
  get tasksByDate() {
    const map = {};
    (this.tasks || []).forEach((t) => {
      const key = dateKey(t.dueAt);
      if (!key) {
        return;
      }
      if (!map[key]) {
        map[key] = [];
      }
      map[key].push(t);
    });
    Object.keys(map).forEach((key) => {
      map[key].sort((a, b) => new Date(a.dueAt) - new Date(b.dueAt));
    });
    return map;
  }

  get cells() {
    const byDate = this.tasksByDate;
    const today = dateKey(new Date());

    return buildMonthGrid(this.year, this.month).map((cell) => {
      const dayTasks = byDate[cell.key] || [];
      const expanded = this.expandedDayKey === cell.key;
      const shown = expanded ? dayTasks : dayTasks.slice(0, MAX_CHIPS_PER_DAY);
      const hiddenCount = dayTasks.length - shown.length;

      const classes = ["cell"];
      if (!cell.inMonth) {
        classes.push("cell--muted");
      }
      if (cell.key === this.selectedDateKey) {
        classes.push("cell--selected");
      }
      if (cell.key === today) {
        classes.push("cell--today");
      }

      const dayClasses = ["cell__day"];
      if (cell.key === today) {
        dayClasses.push("cell__day--today");
      } else if (cell.weekday === 0) {
        dayClasses.push("cell__day--sun");
      } else if (cell.weekday === 6) {
        dayClasses.push("cell__day--sat");
      }

      return {
        ...cell,
        className: classes.join(" "),
        dayClass: dayClasses.join(" "),
        chips: shown.map((t) => this.toChip(t)),
        hiddenCount,
        hasHidden: hiddenCount > 0,
        moreLabel: `+${hiddenCount}개 더보기`
      };
    });
  }

  toChip(task) {
    const tone = toneOf(task);
    const highlighted =
      !!this.searchTerm && matchesSearch(task, this.searchTerm);
    const classes = [`chip`, `chip--${tone}`];
    if (task.status === "Done") {
      classes.push("chip--done");
    }
    if (highlighted) {
      classes.push("chip--hit");
    }
    return {
      recordId: task.recordId,
      subject: task.subject,
      className: classes.join(" "),
      dotClass: `chip__dot chip__dot--${tone}`
    };
  }

  // ── 이벤트 ──────────────────────────────────────────────

  handlePrevMonth() {
    this.emitMonth(-1);
  }

  handleNextMonth() {
    this.emitMonth(1);
  }

  emitMonth(delta) {
    const d = new Date(this.year, this.month + delta, 1);
    this.dispatchEvent(
      new CustomEvent("monthchange", {
        detail: { year: d.getFullYear(), month: d.getMonth() }
      })
    );
  }

  handleToday() {
    this.dispatchEvent(new CustomEvent("gotoday"));
  }

  handleCellClick(event) {
    const key = event.currentTarget.dataset.key;
    this.dispatchEvent(
      new CustomEvent("dateselect", { detail: { dateKey: key } })
    );
  }

  /** 빈 날짜를 더블클릭하면 그 날짜로 새 일정 등록을 엽니다. */
  handleCellDblClick(event) {
    const key = event.currentTarget.dataset.key;
    this.dispatchEvent(
      new CustomEvent("addtask", { detail: { dateKey: key } })
    );
  }

  handleChipClick(event) {
    event.stopPropagation();
    const recordId = event.currentTarget.dataset.id;
    this.dispatchEvent(new CustomEvent("taskselect", { detail: { recordId } }));
  }

  handleMoreClick(event) {
    event.stopPropagation();
    const key = event.currentTarget.dataset.key;
    this.expandedDayKey = this.expandedDayKey === key ? null : key;
  }
}
