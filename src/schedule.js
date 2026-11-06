// Shared between the worker and the browser (injected via toString()).
// Weekday (0 = Sunday) -> dose type.
export const SCHEDULE = { 2: "reta", 5: "reta", 0: "testo" };
export const NAMES = { reta: "Reta", testo: "Testo" };

export function addDays(iso, n) {
  const d = new Date(iso + "T12:00:00Z");
  d.setUTCDate(d.getUTCDate() + n);
  return d.toISOString().slice(0, 10);
}

export function weekday(iso) {
  return new Date(iso + "T12:00:00Z").getUTCDay();
}

// All scheduled doses with from <= date <= to.
export function dosesBetween(from, to) {
  const out = [];
  for (let d = from; d <= to; d = addDays(d, 1)) {
    const t = SCHEDULE[weekday(d)];
    if (t) out.push({ date: d, type: t, id: d + "|" + t });
  }
  return out;
}

export function pendingDoses(start, today, marks) {
  return dosesBetween(start, today).filter((x) => !marks[x.id]);
}
