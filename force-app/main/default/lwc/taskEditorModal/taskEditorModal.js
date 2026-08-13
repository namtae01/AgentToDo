import { LightningElement, api, track } from "lwc";

const PRIORITIES = [
  { label: "High", value: "High" },
  { label: "Medium", value: "Medium" },
  { label: "Low", value: "Low" }
];

const CATEGORIES = [
  { label: "Work · 일반 업무", value: "Work" },
  { label: "Meeting · 회의", value: "Meeting" },
  { label: "Development · 개발", value: "Development" },
  { label: "Review · 검토", value: "Review" }
];

export default class TaskEditorModal extends LightningElement {
  @api defaultDateKey;

  @track form = {
    subject: "",
    date: "",
    time: "09:00",
    priority: "Medium",
    category: "Work",
    description: ""
  };

  error = null;

  connectedCallback() {
    this.form.date = this.defaultDateKey || this.todayKey();
  }

  get priorityOptions() {
    return PRIORITIES;
  }

  get categoryOptions() {
    return CATEGORIES;
  }

  get hasError() {
    return !!this.error;
  }

  todayKey() {
    const d = new Date();
    return `${d.getFullYear()}-${`${d.getMonth() + 1}`.padStart(2, "0")}-${`${d.getDate()}`.padStart(2, "0")}`;
  }

  handleChange(event) {
    const field = event.target.dataset.field;
    this.form = { ...this.form, [field]: event.target.value };
  }

  handleClose() {
    this.dispatchEvent(new CustomEvent("close"));
  }

  handleSave() {
    const { subject, date, time } = this.form;
    if (!subject || !subject.trim()) {
      this.error = "일정 제목을 입력해 주세요.";
      return;
    }
    if (!date) {
      this.error = "날짜를 선택해 주세요.";
      return;
    }

    // 날짜와 시간 입력을 하나의 Datetime 으로 합쳐 Apex 로 넘깁니다.
    const [year, month, day] = date.split("-").map(Number);
    const [hour, minute] = (time || "09:00").split(":").map(Number);
    const dueAt = new Date(year, month - 1, day, hour || 0, minute || 0, 0);

    if (Number.isNaN(dueAt.getTime())) {
      this.error = "날짜 또는 시간 형식이 올바르지 않습니다.";
      return;
    }

    this.error = null;
    this.dispatchEvent(
      new CustomEvent("save", {
        detail: {
          subject: subject.trim(),
          dueAt: dueAt.toISOString(),
          priority: this.form.priority,
          category: this.form.category,
          description: this.form.description
        }
      })
    );
  }
}
