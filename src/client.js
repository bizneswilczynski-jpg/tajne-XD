import { SCHEDULE, NAMES, addDays, weekday, dosesBetween, pendingDoses } from "./schedule.js";

const shared = `
const SCHEDULE = ${JSON.stringify(SCHEDULE)};
const NAMES = ${JSON.stringify(NAMES)};
${addDays.toString()}
${weekday.toString()}
${dosesBetween.toString()}
${pendingDoses.toString()}
`;

export function manifest() {
  return {
    name: "Zastrzyki",
    short_name: "Zastrzyki",
    start_url: "./",
    scope: "./",
    display: "standalone",
    background_color: "#0f1115",
    theme_color: "#0f1115",
    icons: [
      { src: "icon-180.png", sizes: "180x180", type: "image/png" },
      { src: "icon-512.png", sizes: "512x512", type: "image/png" },
    ],
  };
}

export function swJs() {
  return `
self.addEventListener("install", () => self.skipWaiting());
self.addEventListener("activate", (e) => e.waitUntil(self.clients.claim()));
self.addEventListener("push", (event) => {
  let d = {};
  try { d = event.data ? event.data.json() : {}; } catch (e) {}
  const title = d.title || "💉 Zastrzyk";
  const opts = { body: d.body || "Wejdź i odhacz zastrzyk.", icon: "icon-180.png", tag: "dose", renotify: true, data: { url: d.url || "./" } };
  event.waitUntil((async () => {
    try { if (self.navigator.setAppBadge && d.badge) await self.navigator.setAppBadge(d.badge); } catch (e) {}
    await self.registration.showNotification(title, opts);
  })());
});
self.addEventListener("notificationclick", (event) => {
  event.notification.close();
  const url = new URL((event.notification.data && event.notification.data.url) || "./", self.registration.scope).href;
  event.waitUntil((async () => {
    const all = await self.clients.matchAll({ type: "window", includeUncontrolled: true });
    for (const c of all) { if ("focus" in c) { c.navigate && c.navigate(url).catch(() => {}); return c.focus(); } }
    return self.clients.openWindow(url);
  })());
});
`;
}

export function pageHtml() {
  return `<!doctype html>
<html lang="pl">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
<meta name="apple-mobile-web-app-capable" content="yes">
<meta name="mobile-web-app-capable" content="yes">
<meta name="apple-mobile-web-app-status-bar-style" content="black-translucent">
<meta name="apple-mobile-web-app-title" content="Zastrzyki">
<meta name="theme-color" content="#0f1115">
<link rel="manifest" href="manifest.webmanifest">
<link rel="apple-touch-icon" href="icon-180.png">
<title>Zastrzyki</title>
<style>
  :root { --bg:#0f1115; --card:#1a1d24; --line:#2a2e38; --text:#f2f3f5; --muted:#9aa0ab;
          --green:#2ecc71; --red:#ff4d4f; --orange:#ff9f1a; --blue:#4c8dff; --grey:#5c6370; }
  * { box-sizing:border-box; -webkit-tap-highlight-color:transparent; }
  body { margin:0; background:var(--bg); color:var(--text); font:16px/1.4 -apple-system, BlinkMacSystemFont, "SF Pro Text", system-ui, sans-serif;
         padding: calc(env(safe-area-inset-top) + 16px) 16px calc(env(safe-area-inset-bottom) + 24px); }
  h1 { font-size:28px; margin:4px 0 16px; }
  h2 { font-size:15px; text-transform:uppercase; letter-spacing:.06em; color:var(--muted); margin:24px 0 8px; font-weight:600; }
  .card { background:var(--card); border-radius:16px; padding:16px; margin-bottom:12px; }
  .dose { display:flex; flex-direction:column; gap:12px; }
  .dose .t { font-size:20px; font-weight:700; }
  .dose .s { color:var(--muted); font-size:14px; }
  .dose.overdue { border:2px solid var(--red); }
  .dose.today { border:2px solid var(--orange); }
  .row { display:flex; gap:8px; }
  button { font:inherit; border:0; border-radius:12px; padding:14px 16px; font-weight:600; color:#fff; background:var(--line); cursor:pointer; }
  button.big { flex:1; font-size:18px; padding:16px; }
  button.ok { background:var(--green); color:#062b14; }
  button.blue { background:var(--blue); }
  button:disabled { opacity:.5; }
  .allgood { text-align:center; padding:24px 16px; }
  .allgood .e { font-size:44px; }
  .allgood .t { font-size:20px; font-weight:700; margin-top:6px; }
  .muted { color:var(--muted); font-size:14px; }
  .cal-head { display:flex; align-items:center; justify-content:space-between; margin-bottom:8px; }
  .cal-head b { font-size:18px; }
  .cal-head button { padding:8px 14px; }
  .grid { display:grid; grid-template-columns:repeat(7, 1fr); gap:4px; }
  .wd { text-align:center; font-size:12px; color:var(--muted); padding:4px 0; }
  .day { aspect-ratio:1; border-radius:10px; display:flex; flex-direction:column; align-items:center; justify-content:center; font-size:14px; position:relative; }
  .day.empty { visibility:hidden; }
  .day.isToday { outline:2px solid var(--text); outline-offset:-2px; }
  .day .tag { font-size:10px; font-weight:800; margin-top:2px; letter-spacing:.02em; }
  .day.done { background:rgba(46,204,113,.22); } .day.done .tag { color:var(--green); }
  .day.skip { background:rgba(92,99,112,.3); } .day.skip .tag { color:#c0c4cc; }
  .day.miss { background:rgba(255,77,79,.22); } .day.miss .tag { color:var(--red); }
  .day.due  { background:rgba(255,159,26,.25); } .day.due .tag { color:var(--orange); }
  .day.plan .tag { color:var(--blue); }
  .day.past-plan .tag { color:var(--grey); }
  .legend { display:flex; flex-wrap:wrap; gap:10px 14px; margin-top:12px; font-size:13px; color:var(--muted); }
  .legend i { display:inline-block; width:10px; height:10px; border-radius:3px; margin-right:5px; vertical-align:-1px; }
  .stats { display:flex; gap:8px; margin-top:12px; }
  .stats div { flex:1; background:var(--bg); border-radius:10px; padding:10px; text-align:center; }
  .stats b { display:block; font-size:20px; }
  select { font:inherit; background:var(--bg); color:var(--text); border:1px solid var(--line); border-radius:10px; padding:10px; }
  label.set { display:flex; justify-content:space-between; align-items:center; gap:12px; padding:8px 0; }
  .sheet-bg { position:fixed; inset:0; background:rgba(0,0,0,.55); display:none; align-items:flex-end; z-index:10; }
  .sheet-bg.open { display:flex; }
  .sheet { background:var(--card); width:100%; border-radius:20px 20px 0 0; padding:20px 16px calc(env(safe-area-inset-bottom) + 20px); display:flex; flex-direction:column; gap:10px; }
  .sheet .t { font-size:20px; font-weight:700; margin-bottom:6px; }
  ol { padding-left:20px; margin:8px 0 0; } ol li { margin:6px 0; }
  .toast { position:fixed; left:16px; right:16px; bottom:calc(env(safe-area-inset-bottom) + 16px); background:#fff; color:#000; padding:14px; border-radius:12px; text-align:center; font-weight:600; display:none; z-index:20; }
</style>
</head>
<body>
<h1>💉 Zastrzyki</h1>
<div id="now"><div class="card muted">Ładuję…</div></div>

<h2>Kalendarz</h2>
<div class="card">
  <div class="cal-head"><button id="prev">‹</button><b id="month"></b><button id="next">›</button></div>
  <div class="grid" id="grid"></div>
  <div class="legend">
    <span><i style="background:var(--green)"></i>zrobione</span>
    <span><i style="background:var(--red)"></i>niezrobione</span>
    <span><i style="background:var(--orange)"></i>dziś</span>
    <span><i style="background:var(--blue)"></i>zaplanowane</span>
    <span><i style="background:var(--grey)"></i>pominięte</span>
  </div>
  <div class="stats" id="stats"></div>
  <p class="muted" style="margin:12px 0 0">Kliknij dzień z zastrzykiem, żeby go odhaczyć albo poprawić.</p>
</div>

<h2>Powiadomienia</h2>
<div class="card" id="notif"></div>

<h2>Ustawienia</h2>
<div class="card">
  <label class="set"><span>Przypomnienie o</span><select id="hour"></select></label>
  <label class="set"><span>Drugie przypomnienie tego samego dnia</span><select id="hour2"></select></label>
  <p class="muted" style="margin:8px 0 0">Wt i pt: Reta. Nd: Testo. Jak nie odhaczysz, przypomnienie wraca codziennie, aż klikniesz „Zrobione”.</p>
</div>

<div class="sheet-bg" id="sheetBg"><div class="sheet" id="sheet"></div></div>
<div class="toast" id="toast"></div>

<script>
${shared}
const DN = ["niedziela","poniedziałek","wtorek","środa","czwartek","piątek","sobota"];
const MN = ["styczeń","luty","marzec","kwiecień","maj","czerwiec","lipiec","sierpień","wrzesień","październik","listopad","grudzień"];
let S = null; let view = null;
const $ = (id) => document.getElementById(id);
const fmt = (iso) => { const [y,m,d] = iso.split("-"); return DN[weekday(iso)] + " " + Number(d) + "." + m; };
const standalone = window.navigator.standalone === true || matchMedia("(display-mode: standalone)").matches;
const isIOS = /iPhone|iPad|iPod/.test(navigator.userAgent) || (navigator.platform === "MacIntel" && navigator.maxTouchPoints > 1);

function toast(t) { const el = $("toast"); el.textContent = t; el.style.display = "block"; clearTimeout(toast.h); toast.h = setTimeout(() => el.style.display = "none", 2200); }

async function api(path, body) {
  const r = await fetch(path, body ? { method: "POST", headers: { "content-type": "application/json" }, body: JSON.stringify(body) } : { cache: "no-store" });
  if (!r.ok) throw new Error("HTTP " + r.status);
  return r.json();
}

async function load() {
  try { S = await api("api/state"); }
  catch (e) { $("now").innerHTML = '<div class="card">Brak połączenia z internetem. Spróbuj za chwilę.</div>'; return; }
  if (!view) view = S.today.slice(0, 7);
  render();
}

function render() {
  const pending = pendingDoses(S.settings.start, S.today, S.marks);
  try { if (navigator.setAppBadge) pending.length ? navigator.setAppBadge(pending.length) : navigator.clearAppBadge(); } catch (e) {}
  // Now / to-do
  let h = "";
  if (pending.length) {
    for (const p of pending) {
      const days = Math.round((new Date(S.today) - new Date(p.date)) / 864e5);
      const when = days === 0 ? "dziś, " + fmt(p.date) : "zaległe od " + fmt(p.date) + " (" + days + " " + (days === 1 ? "dzień" : "dni") + ")";
      h += '<div class="card dose ' + (days === 0 ? "today" : "overdue") + '"><div><div class="t">' + NAMES[p.type] + '</div><div class="s">' + when + '</div></div>' +
           '<div class="row"><button class="big ok" data-mark="' + p.id + '" data-s="done">✅ Zrobione</button>' +
           '<button data-mark="' + p.id + '" data-s="skip">Pomiń</button></div></div>';
    }
  } else {
    const next = dosesBetween(addDays(S.today, 1), addDays(S.today, 8))[0];
    h = '<div class="card allgood"><div class="e">💪</div><div class="t">Wszystko odhaczone</div>' +
        (next ? '<div class="muted" style="margin-top:6px">Następny: <b>' + NAMES[next.type] + '</b>, ' + fmt(next.date) + '</div>' : "") + '</div>';
  }
  $("now").innerHTML = h;
  renderCal();
  renderNotif();
  renderSettings();
}

function statusOf(dose) {
  const m = S.marks[dose.id];
  if (m) return m.s === "done" ? "done" : "skip";
  if (dose.date > S.today) return "plan";
  if (dose.date < S.settings.start) return "past-plan";
  return dose.date === S.today ? "due" : "miss";
}

function renderCal() {
  const [y, m] = view.split("-").map(Number);
  $("month").textContent = MN[m - 1] + " " + y;
  const first = view + "-01";
  const daysIn = new Date(Date.UTC(y, m, 0)).getUTCDate();
  const lead = (weekday(first) + 6) % 7;
  let h = ["pn","wt","śr","cz","pt","sb","nd"].map((d) => '<div class="wd">' + d + "</div>").join("");
  for (let i = 0; i < lead; i++) h += '<div class="day empty"></div>';
  let done = 0, miss = 0;
  for (let d = 1; d <= daysIn; d++) {
    const iso = view + "-" + String(d).padStart(2, "0");
    const t = SCHEDULE[weekday(iso)];
    let cls = "day", tag = "";
    if (t) {
      const dose = { date: iso, type: t, id: iso + "|" + t };
      const st = statusOf(dose);
      if (st === "done") done++; if (st === "miss") miss++;
      cls += " " + st; tag = '<span class="tag">' + (t === "reta" ? "RETA" : "TESTO") + "</span>";
    }
    if (iso === S.today) cls += " isToday";
    h += '<div class="' + cls + '"' + (t ? ' data-day="' + iso + '|' + t + '"' : "") + ">" + d + tag + "</div>";
  }
  $("grid").innerHTML = h;
  $("stats").innerHTML = '<div><b style="color:var(--green)">' + done + '</b><span class="muted">zrobione</span></div>' +
                         '<div><b style="color:var(--red)">' + miss + '</b><span class="muted">niezrobione</span></div>';
}

function openSheet(id) {
  const [date, type] = id.split("|");
  if (date > S.today) { toast("To dopiero " + fmt(date)); return; }
  const cur = S.marks[id];
  $("sheet").innerHTML = '<div class="t">' + NAMES[type] + " · " + fmt(date) + '</div>' +
    '<div class="muted">' + (cur ? (cur.s === "done" ? "Odhaczone jako zrobione" : "Pominięte") : "Nieodhaczone") + "</div>" +
    '<button class="big ok" data-mark="' + id + '" data-s="done">✅ Zrobione</button>' +
    '<button class="big" data-mark="' + id + '" data-s="skip">Pominięte</button>' +
    (cur ? '<button class="big" data-mark="' + id + '" data-s="">Cofnij (nieodhaczone)</button>' : "") +
    '<button class="big" id="cancel" style="background:transparent">Anuluj</button>';
  $("sheetBg").classList.add("open");
}
function closeSheet() { $("sheetBg").classList.remove("open"); }

async function mark(id, s) {
  closeSheet();
  const prev = S.marks[id];
  if (s) S.marks[id] = { s, at: new Date().toISOString() }; else delete S.marks[id];
  render();
  try { await api("api/mark", { id, status: s || null }); toast(s === "done" ? "Zapisane 💪" : s === "skip" ? "Pominięte" : "Cofnięte"); }
  catch (e) { if (prev) S.marks[id] = prev; else delete S.marks[id]; render(); toast("Nie zapisało się, brak netu?"); }
}

function renderNotif() {
  const el = $("notif");
  if (!("serviceWorker" in navigator)) { el.innerHTML = '<div class="muted">Ta przeglądarka nie obsługuje powiadomień.</div>'; return; }
  if (isIOS && !standalone) {
    el.innerHTML = '<b>Najpierw dodaj apkę do ekranu początkowego</b><ol>' +
      '<li>Na dole Safari kliknij <b>Udostępnij</b> (kwadrat ze strzałką do góry).</li>' +
      '<li>Wybierz <b>Dodaj do ekranu początkowego</b>, potem <b>Dodaj</b>.</li>' +
      '<li>Otwórz apkę <b>Zastrzyki</b> z ekranu i włącz tu powiadomienia.</li></ol>';
    return;
  }
  const perm = ("Notification" in window) ? Notification.permission : "unsupported";
  if (perm === "granted") {
    el.innerHTML = '<div style="margin-bottom:12px">✅ Powiadomienia włączone</div><button class="blue" id="test">Wyślij testowe powiadomienie</button>';
  } else if (perm === "denied") {
    el.innerHTML = '<div class="muted">Powiadomienia są zablokowane. Włącz je w Ustawienia → Powiadomienia → Zastrzyki.</div>';
  } else {
    el.innerHTML = '<button class="big blue" id="enable" style="width:100%">🔔 Włącz powiadomienia</button>';
  }
}

function renderSettings() {
  const opts = (sel, allowNone) => (allowNone ? '<option value="">wyłączone</option>' : "") +
    Array.from({ length: 24 }, (_, h) => '<option value="' + h + '"' + (sel === h ? " selected" : "") + ">" + String(h).padStart(2, "0") + ":00</option>").join("");
  $("hour").innerHTML = opts(S.settings.hour, false);
  $("hour2").innerHTML = opts(S.settings.hour2, true);
}

function b64uToBytes(s) { s = s.replace(/-/g, "+").replace(/_/g, "/"); while (s.length % 4) s += "="; return Uint8Array.from(atob(s), (c) => c.charCodeAt(0)); }

async function subscribe(ask) {
  const reg = await navigator.serviceWorker.ready;
  if (ask) { const p = await Notification.requestPermission(); if (p !== "granted") { renderNotif(); return; } }
  let sub = await reg.pushManager.getSubscription();
  if (!sub) sub = await reg.pushManager.subscribe({ userVisibleOnly: true, applicationServerKey: b64uToBytes(S.vapidPublic) });
  await api("api/subscribe", { subscription: sub.toJSON() });
  renderNotif();
  if (ask) toast("Powiadomienia włączone 🔔");
}

document.addEventListener("click", async (e) => {
  const t = e.target.closest("[data-mark],[data-day],#prev,#next,#enable,#test,#cancel,#sheetBg");
  if (!t) return;
  if (t.dataset.mark) return mark(t.dataset.mark, t.dataset.s);
  if (t.dataset.day) return openSheet(t.dataset.day);
  if (t.id === "prev" || t.id === "next") {
    const [y, m] = view.split("-").map(Number); const d = new Date(Date.UTC(y, m - 1 + (t.id === "next" ? 1 : -1), 1));
    view = d.toISOString().slice(0, 7); renderCal(); return;
  }
  if (t.id === "enable") { t.disabled = true; try { await subscribe(true); } catch (err) { toast("Błąd: " + err.message); t.disabled = false; } return; }
  if (t.id === "test") { t.disabled = true; try { await subscribe(false); const r = await api("api/test", {}); toast(r.sent ? "Wysłane, zaraz przyjdzie" : "Brak zapisanych telefonów"); } catch (err) { toast("Błąd: " + err.message); } t.disabled = false; return; }
  if (t.id === "cancel" || (t.id === "sheetBg" && e.target === t)) closeSheet();
});

for (const id of ["hour", "hour2"]) $(id).addEventListener("change", async () => {
  const hour = Number($("hour").value); const v2 = $("hour2").value; const hour2 = v2 === "" ? null : Number(v2);
  try { const r = await api("api/settings", { hour, hour2 }); S.settings = r.settings; toast("Zapisane"); } catch (e) { toast("Nie zapisało się"); }
});

if ("serviceWorker" in navigator) {
  navigator.serviceWorker.register("sw.js").then(() => {
    if (window.Notification && Notification.permission === "granted" && S) subscribe(false).catch(() => {});
  });
}
document.addEventListener("visibilitychange", () => { if (document.visibilityState === "visible") load(); });
load().then(() => { if (window.Notification && Notification.permission === "granted" && "serviceWorker" in navigator) subscribe(false).catch(() => {}); });
</script>
</body>
</html>`;
}
