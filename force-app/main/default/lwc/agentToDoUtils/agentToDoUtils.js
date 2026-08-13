/**
 * AgentToDo 화면 전반에서 쓰는 순수 함수 모음.
 * 날짜 계산과 색상 판정을 한곳에 모아 컴포넌트 간 규칙이 어긋나지 않게 합니다.
 */

const WEEKDAY_KO = ["일", "월", "화", "수", "목", "금", "토"];
const WEEKDAY_EN = ["SUN", "MON", "TUE", "WED", "THU", "FRI", "SAT"];

/** 'YYYY-MM-DD' 형식의 로컬 날짜 키. 캘린더 셀과 일정을 묶는 기준입니다. */
export function dateKey(value) {
  const d = value instanceof Date ? value : new Date(value);
  if (Number.isNaN(d.getTime())) {
    return null;
  }
  const y = d.getFullYear();
  const m = `${d.getMonth() + 1}`.padStart(2, "0");
  const day = `${d.getDate()}`.padStart(2, "0");
  return `${y}-${m}-${day}`;
}

/** 24시간제 'HH:MM'. */
export function formatTime(value) {
  const d = new Date(value);
  if (Number.isNaN(d.getTime())) {
    return "";
  }
  return `${`${d.getHours()}`.padStart(2, "0")}:${`${d.getMinutes()}`.padStart(2, "0")}`;
}

/** '2026.08.13 THU' — 우측 패널 머리말용. */
export function formatDateStamp(value) {
  const d = new Date(value);
  if (Number.isNaN(d.getTime())) {
    return "";
  }
  const y = d.getFullYear();
  const m = `${d.getMonth() + 1}`.padStart(2, "0");
  const day = `${d.getDate()}`.padStart(2, "0");
  return `${y}.${m}.${day} ${WEEKDAY_EN[d.getDay()]}`;
}

/** '2026년 8월 13일 · 목요일' — 헤더용. */
export function formatDateLong(value) {
  const d = new Date(value);
  if (Number.isNaN(d.getTime())) {
    return "";
  }
  return `${d.getFullYear()}년 ${d.getMonth() + 1}월 ${d.getDate()}일 · ${WEEKDAY_KO[d.getDay()]}요일`;
}

/** '2026년 8월' — 캘린더 제목용. */
export function formatMonthTitle(year, month) {
  return `${year}년 ${month + 1}월`;
}

/**
 * 일정 칩 색상 판정. 우선순위는 기한 초과 > 높은 우선순위 > 회의 > 일반 업무 순입니다.
 * 기한 초과는 어떤 유형이든 가장 먼저 눈에 띄어야 하므로 최상위입니다.
 */
export function toneOf(task) {
  if (!task) {
    return "default";
  }
  if (task.isOverdue) {
    return "overdue";
  }
  if (task.priority === "High") {
    return "high";
  }
  if (task.category === "Meeting") {
    return "meeting";
  }
  return "default";
}

/** 상태 API 값 → 한글 라벨. */
export function statusLabel(status) {
  if (status === "Done") {
    return "완료";
  }
  if (status === "In Progress") {
    return "진행 중";
  }
  return "대기";
}

/** 좌측 메뉴별로 보여줄 일정을 걸러냅니다. */
export function filterByMenu(tasks, menu, todayKey) {
  const rows = tasks || [];
  if (menu === "today") {
    return rows.filter((t) => dateKey(t.dueAt) === todayKey);
  }
  if (menu === "mine") {
    return rows.filter((t) => !t.isReceived && t.status !== "Done");
  }
  if (menu === "received") {
    return rows.filter((t) => t.isReceived && t.status !== "Done");
  }
  if (menu === "done") {
    return rows.filter((t) => t.status === "Done");
  }
  return rows;
}

/** 검색어를 제목·카테고리·요청자·번호에 대해 매칭합니다. */
export function matchesSearch(task, term) {
  if (!term) {
    return true;
  }
  const needle = term.trim().toLowerCase();
  if (!needle) {
    return true;
  }
  return [
    task.subject,
    task.category,
    task.requestedByName,
    task.todoNumber,
    task.description
  ]
    .filter((v) => !!v)
    .some((v) => v.toLowerCase().includes(needle));
}

/**
 * 템플릿에서 쓸 수 있도록 표시용 속성을 미리 계산해 붙입니다.
 * LWC 템플릿은 복잡한 표현식을 지원하지 않으므로 문자열/클래스는 여기서 만듭니다.
 */
export function decorateTask(task) {
  const tone = toneOf(task);
  const done = task.status === "Done";
  return {
    ...task,
    tone,
    timeLabel: formatTime(task.dueAt),
    statusText: statusLabel(task.status),
    isDone: done,
    toneClass: `chip chip--${tone}`,
    dotClass: `dot dot--${tone}`,
    rowClass: done ? "agenda-item agenda-item--done" : "agenda-item",
    checkClass: done ? "check check--on" : "check",
    showRequester: !!task.requestedByName,
    showAgentBadge: !!task.createdByAgent
  };
}

/**
 * 표시할 달의 6주 x 7일 격자를 만듭니다.
 * 앞뒤 달의 날짜도 채워 캘린더가 항상 같은 높이를 유지하게 합니다.
 */
export function buildMonthGrid(year, month) {
  const first = new Date(year, month, 1);
  const start = new Date(year, month, 1 - first.getDay());
  const cells = [];
  for (let i = 0; i < 42; i++) {
    const d = new Date(
      start.getFullYear(),
      start.getMonth(),
      start.getDate() + i
    );
    cells.push({
      key: dateKey(d),
      day: d.getDate(),
      weekday: d.getDay(),
      inMonth: d.getMonth() === month
    });
  }
  return cells;
}

/** 이번 주(일요일 시작) 범위. */
export function weekRange(base) {
  const d = base instanceof Date ? base : new Date(base);
  const start = new Date(
    d.getFullYear(),
    d.getMonth(),
    d.getDate() - d.getDay()
  );
  const end = new Date(
    start.getFullYear(),
    start.getMonth(),
    start.getDate() + 6
  );
  return { start, end };
}
