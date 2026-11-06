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
    background_color: "#07080c",
    theme_color: "#07080c",
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
<meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover, user-scalable=no">
<meta name="apple-mobile-web-app-capable" content="yes">
<meta name="mobile-web-app-capable" content="yes">
<meta name="apple-mobile-web-app-status-bar-style" content="black-translucent">
<meta name="apple-mobile-web-app-title" content="Zastrzyki">
<meta name="theme-color" content="#07080c">
<link rel="manifest" href="manifest.webmanifest">
<link rel="apple-touch-icon" href="icon-180.png">
<title>Zastrzyki</title>
<style>
  :root {
    --bg:#07080c; --glass:rgba(255,255,255,.06); --glass2:rgba(255,255,255,.1); --stroke:rgba(255,255,255,.09);
    --text:#f5f6fa; --muted:#8e94a3;
    --green:#34e08a; --red:#ff5267; --orange:#ffab2e; --blue:#5b8cff; --grey:#6b7180;
    --reta1:#7b5cff; --reta2:#c04dff; --testo1:#ff7a2e; --testo2:#ffb02e;
  }
  * { box-sizing:border-box; -webkit-tap-highlight-color:transparent; -webkit-user-select:none; user-select:none; }
  html, body { margin:0; background:var(--bg); color:var(--text); overscroll-behavior:none; }
  body { font:16px/1.4 -apple-system, BlinkMacSystemFont, "SF Pro Text", "Segoe UI", system-ui, sans-serif; min-height:100vh; overflow-x:hidden; }
  .blobs { position:fixed; inset:0; z-index:0; pointer-events:none; overflow:hidden; }
  .blobs i { position:absolute; border-radius:50%; filter:blur(70px); opacity:.45; animation:float 18s ease-in-out infinite alternate; }
  .blobs i:nth-child(1) { width:340px; height:340px; background:var(--reta1); top:-120px; left:-100px; }
  .blobs i:nth-child(2) { width:300px; height:300px; background:var(--testo1); top:40%; right:-160px; opacity:.25; animation-delay:-6s; }
  .blobs i:nth-child(3) { width:260px; height:260px; background:#1fc6a8; bottom:-120px; left:10%; opacity:.18; animation-delay:-12s; }
  @keyframes float { to { transform:translate(40px, 60px) scale(1.15); } }

  main { position:relative; z-index:1; padding: calc(env(safe-area-inset-top) + 18px) 18px calc(env(safe-area-inset-bottom) + 110px); max-width:560px; margin:0 auto; }
  .view { display:none; }
  .view.active { display:block; animation:viewIn .45s cubic-bezier(.2,.9,.3,1.2); }
  @keyframes viewIn { from { opacity:0; transform:translateY(14px) scale(.98); } }

  .hello { color:var(--muted); font-size:15px; font-weight:500; }
  h1 { font-size:34px; line-height:1.1; margin:2px 0 20px; font-weight:800; letter-spacing:-.02em; }
  h2 { font-size:13px; text-transform:uppercase; letter-spacing:.1em; color:var(--muted); margin:26px 4px 10px; font-weight:700; }
  .glass { background:var(--glass); border:1px solid var(--stroke); border-radius:24px; padding:18px; backdrop-filter:blur(20px); -webkit-backdrop-filter:blur(20px); }

  /* hero dose card */
  .dose { position:relative; border-radius:28px; padding:22px; margin-bottom:14px; overflow:hidden; color:#fff;
          box-shadow:0 20px 50px -20px var(--c1); animation:pop .5s cubic-bezier(.2,.9,.3,1.3) both; }
  .dose::before { content:""; position:absolute; inset:0; background:linear-gradient(135deg, var(--c1), var(--c2)); z-index:-2; }
  .dose::after { content:""; position:absolute; width:220px; height:220px; right:-60px; top:-70px; border-radius:50%; background:rgba(255,255,255,.14); z-index:-1; }
  .dose.reta { --c1:var(--reta1); --c2:var(--reta2); }
  .dose.testo { --c1:var(--testo1); --c2:var(--testo2); }
  .dose .badge { display:inline-flex; align-items:center; gap:6px; background:rgba(0,0,0,.22); padding:6px 12px; border-radius:99px; font-size:13px; font-weight:700; }
  .dose .badge.late { background:rgba(255,40,70,.9); animation:blink 1.6s ease-in-out infinite; }
  @keyframes blink { 50% { opacity:.65; } }
  .dose .name { font-size:42px; font-weight:900; letter-spacing:-.03em; margin:14px 0 2px; }
  .dose .when { opacity:.85; font-weight:500; }
  .dose .acts { display:flex; align-items:center; gap:12px; margin-top:22px; }
  .donebtn { flex:1; position:relative; border:0; border-radius:20px; padding:18px; font:inherit; font-size:19px; font-weight:800; color:#111; background:#fff; cursor:pointer;
             box-shadow:0 10px 24px -8px rgba(0,0,0,.4); transition:transform .15s; }
  .donebtn::after { content:""; position:absolute; inset:-4px; border-radius:24px; border:2px solid rgba(255,255,255,.7); animation:ring 2s ease-out infinite; }
  @keyframes ring { from { opacity:.9; transform:scale(.96); } to { opacity:0; transform:scale(1.12); } }
  .skipbtn { border:0; background:rgba(0,0,0,.2); color:#fff; font:inherit; font-weight:700; border-radius:16px; padding:18px 18px; cursor:pointer; }
  button:active, .press:active { transform:scale(.95); }
  @keyframes pop { from { opacity:0; transform:translateY(20px) scale(.94); } }

  .allgood { text-align:center; padding:30px 20px; animation:pop .5s cubic-bezier(.2,.9,.3,1.3) both; }
  .allgood .e { font-size:64px; display:inline-block; animation:flex 2.4s ease-in-out infinite; }
  @keyframes flex { 0%,100% { transform:rotate(0) scale(1); } 20% { transform:rotate(-12deg) scale(1.12); } 40% { transform:rotate(8deg) scale(1.05); } }
  .allgood .t { font-size:24px; font-weight:800; margin-top:8px; }
  .next { display:inline-flex; align-items:center; gap:10px; margin-top:16px; padding:10px 16px; border-radius:99px; background:var(--glass2); font-weight:600; }
  .dot { width:10px; height:10px; border-radius:50%; display:inline-block; }
  .dot.reta { background:linear-gradient(135deg,var(--reta1),var(--reta2)); } .dot.testo { background:linear-gradient(135deg,var(--testo1),var(--testo2)); }

  .stats { display:grid; grid-template-columns:repeat(3,1fr); gap:10px; }
  .stat { text-align:center; padding:16px 8px; }
  .stat b { display:block; font-size:28px; font-weight:900; letter-spacing:-.02em; }
  .stat span { font-size:12px; color:var(--muted); font-weight:600; }

  .week { display:grid; grid-template-columns:repeat(7,1fr); gap:6px; }
  .wday { text-align:center; padding:10px 0 12px; border-radius:16px; background:var(--glass); border:1px solid var(--stroke); }
  .wday .n { font-size:11px; color:var(--muted); font-weight:700; text-transform:uppercase; }
  .wday .d { font-size:18px; font-weight:800; margin:2px 0 6px; }
  .wday .dot { width:8px; height:8px; }
  .wday.today { background:var(--glass2); border-color:rgba(255,255,255,.35); }
  .wday .dot.done { background:var(--green); box-shadow:0 0 10px var(--green); }

  /* calendar */
  .cal-head { display:flex; align-items:center; justify-content:space-between; margin-bottom:12px; }
  .cal-head b { font-size:20px; font-weight:800; text-transform:capitalize; }
  .nav { width:40px; height:40px; border-radius:14px; border:0; background:var(--glass2); color:var(--text); font-size:20px; cursor:pointer; }
  .grid { display:grid; grid-template-columns:repeat(7,1fr); gap:5px; }
  .grid.anim { animation:viewIn .35s ease; }
  .wd { text-align:center; font-size:11px; font-weight:700; color:var(--muted); padding:4px 0 6px; text-transform:uppercase; }
  .day { aspect-ratio:1; border-radius:14px; display:flex; flex-direction:column; align-items:center; justify-content:center; font-size:15px; font-weight:600; color:#c8ccd6; position:relative; }
  .day.empty { visibility:hidden; }
  .day.isToday { box-shadow:inset 0 0 0 2px var(--text); color:#fff; }
  .day .tag { font-size:8.5px; font-weight:900; margin-top:1px; letter-spacing:.04em; }
  .day[data-day] { cursor:pointer; }
  .day.done { background:linear-gradient(135deg, rgba(52,224,138,.35), rgba(52,224,138,.15)); color:#fff; } .day.done .tag { color:var(--green); }
  .day.done::after { content:"✓"; position:absolute; top:2px; right:5px; font-size:10px; color:var(--green); font-weight:900; }
  .day.skip { background:rgba(107,113,128,.25); } .day.skip .tag { color:#aab; }
  .day.miss { background:linear-gradient(135deg, rgba(255,82,103,.4), rgba(255,82,103,.15)); color:#fff; } .day.miss .tag { color:#ff8a9a; }
  .day.due { background:linear-gradient(135deg, rgba(255,171,46,.45), rgba(255,171,46,.15)); color:#fff; animation:blink 1.6s infinite; } .day.due .tag { color:var(--orange); }
  .day.plan .tag.reta { color:#a58bff; } .day.plan .tag.testo { color:#ffb067; }
  .day.past-plan .tag { color:var(--grey); }
  .legend { display:flex; flex-wrap:wrap; gap:8px 14px; margin-top:14px; font-size:12px; color:var(--muted); font-weight:600; }
  .legend i { display:inline-block; width:9px; height:9px; border-radius:3px; margin-right:5px; }
  .hist { display:flex; flex-direction:column; gap:8px; }
  .hrow { display:flex; align-items:center; gap:12px; padding:12px 14px; border-radius:16px; background:var(--glass); border:1px solid var(--stroke); }
  .hrow .ic { width:36px; height:36px; border-radius:12px; display:flex; align-items:center; justify-content:center; font-size:17px; flex-shrink:0; }
  .hrow .ic.reta { background:linear-gradient(135deg,var(--reta1),var(--reta2)); } .hrow .ic.testo { background:linear-gradient(135deg,var(--testo1),var(--testo2)); }
  .hrow .tx { flex:1; } .hrow .tx b { display:block; } .hrow .tx span { font-size:13px; color:var(--muted); }
  .pill { font-size:12px; font-weight:800; padding:5px 10px; border-radius:99px; }
  .pill.done { background:rgba(52,224,138,.18); color:var(--green); } .pill.miss { background:rgba(255,82,103,.18); color:var(--red); }
  .pill.skip { background:rgba(107,113,128,.25); color:#bbc; } .pill.due { background:rgba(255,171,46,.2); color:var(--orange); }

  /* settings */
  .row { display:flex; justify-content:space-between; align-items:center; gap:12px; padding:12px 0; }
  .row + .row { border-top:1px solid var(--stroke); }
  .row .l b { display:block; } .row .l span { font-size:13px; color:var(--muted); }
  select { font:inherit; font-weight:700; background:var(--glass2); color:var(--text); border:0; border-radius:12px; padding:10px 12px; -webkit-appearance:none; appearance:none; }
  .btn { width:100%; border:0; border-radius:18px; padding:16px; font:inherit; font-size:17px; font-weight:800; color:#fff; cursor:pointer;
         background:linear-gradient(135deg,var(--blue),#8a5bff); box-shadow:0 14px 30px -12px var(--blue); }
  .btn.ghost { background:var(--glass2); box-shadow:none; }
  .ok-line { display:flex; align-items:center; gap:10px; font-weight:700; margin-bottom:14px; }
  .ok-line .live { width:10px; height:10px; border-radius:50%; background:var(--green); box-shadow:0 0 0 0 rgba(52,224,138,.6); animation:live 1.8s infinite; }
  @keyframes live { to { box-shadow:0 0 0 12px rgba(52,224,138,0); } }
  ol { padding-left:22px; margin:10px 0 0; } ol li { margin:8px 0; color:#d3d6de; }
  .sched { display:flex; gap:8px; margin-top:4px; flex-wrap:wrap; }
  .sched span { display:inline-flex; align-items:center; gap:8px; padding:8px 12px; border-radius:12px; background:var(--glass2); font-weight:700; font-size:14px; }

  /* tab bar */
  .tabbar { position:fixed; z-index:5; left:50%; transform:translateX(-50%); bottom:calc(env(safe-area-inset-bottom) + 12px); display:flex; gap:4px; padding:6px;
            border-radius:26px; background:rgba(22,24,32,.72); border:1px solid var(--stroke); backdrop-filter:blur(24px) saturate(1.6); -webkit-backdrop-filter:blur(24px) saturate(1.6);
            box-shadow:0 20px 40px -10px rgba(0,0,0,.6); }
  .tab { border:0; background:transparent; color:var(--muted); font:inherit; font-size:11px; font-weight:700; padding:8px 18px; border-radius:20px; display:flex; flex-direction:column; align-items:center; gap:3px; cursor:pointer; position:relative; transition:color .2s, background .25s; }
  .tab svg { width:24px; height:24px; }
  .tab.active { color:#fff; background:rgba(255,255,255,.12); }
  .tab .cnt { position:absolute; top:3px; right:12px; min-width:18px; height:18px; padding:0 5px; border-radius:9px; background:var(--red); color:#fff; font-size:11px; line-height:18px; animation:pop .4s cubic-bezier(.2,.9,.3,1.5); }

  /* overlays */
  .ov { position:fixed; inset:0; z-index:20; display:flex; align-items:center; justify-content:center; padding:24px; background:rgba(0,0,0,.55);
        backdrop-filter:blur(8px); -webkit-backdrop-filter:blur(8px); opacity:0; pointer-events:none; transition:opacity .25s; }
  .ov.open { opacity:1; pointer-events:auto; }
  .ov.sheet { align-items:flex-end; padding:0; }
  .modal { width:100%; max-width:380px; background:#151821; border:1px solid var(--stroke); border-radius:30px; padding:26px 22px 20px; text-align:center;
           transform:scale(.85) translateY(20px); transition:transform .45s cubic-bezier(.2,.9,.3,1.35); }
  .ov.open .modal { transform:none; }
  .ov.sheet .modal { max-width:560px; border-radius:30px 30px 0 0; padding-bottom:calc(env(safe-area-inset-bottom) + 22px); transform:translateY(100%); transition:transform .4s cubic-bezier(.2,.9,.3,1.05); text-align:left; }
  .ov.sheet.open .modal { transform:none; }
  .grab { width:40px; height:5px; border-radius:3px; background:#3a3f4c; margin:-12px auto 16px; }
  .modal .big { font-size:72px; line-height:1; }
  .modal .t { font-size:24px; font-weight:900; margin:12px 0 6px; letter-spacing:-.01em; }
  .modal .s { color:var(--muted); margin-bottom:20px; }
  .modal .btns { display:flex; flex-direction:column; gap:10px; }
  .mb { border:0; border-radius:16px; padding:16px; font:inherit; font-size:17px; font-weight:800; cursor:pointer; color:#fff; background:var(--glass2); }
  .mb.green { background:linear-gradient(135deg,#2bd47f,#18b8a0); color:#04150c; }
  .mb.red { background:linear-gradient(135deg,#ff5267,#ff7a45); }
  .mb.plain { background:transparent; color:var(--muted); }
  .checkwrap { width:110px; height:110px; margin:0 auto; border-radius:50%; background:linear-gradient(135deg,#2bd47f,#18b8a0); display:flex; align-items:center; justify-content:center;
               box-shadow:0 0 0 0 rgba(43,212,127,.5); animation:burst 1s ease-out .2s; }
  @keyframes burst { from { box-shadow:0 0 0 0 rgba(43,212,127,.6); } to { box-shadow:0 0 0 40px rgba(43,212,127,0); } }
  .checkwrap svg path { stroke-dasharray:60; stroke-dashoffset:60; animation:draw .5s ease-out .25s forwards; }
  @keyframes draw { to { stroke-dashoffset:0; } }
  #confetti { position:fixed; inset:0; z-index:30; pointer-events:none; }
  .toast { position:fixed; left:50%; top:calc(env(safe-area-inset-top) + 12px); z-index:40; transform:translate(-50%,-150%); background:rgba(30,33,44,.92); color:#fff; padding:12px 18px;
           border-radius:99px; font-weight:700; font-size:15px; border:1px solid var(--stroke); backdrop-filter:blur(20px); -webkit-backdrop-filter:blur(20px);
           transition:transform .45s cubic-bezier(.2,.9,.3,1.3); white-space:nowrap; }
  .toast.show { transform:translate(-50%,0); }
  .muted { color:var(--muted); font-size:14px; }
</style>
</head>
<body>
<div class="blobs"><i></i><i></i><i></i></div>
<main>
  <section class="view active" id="v-today">
    <div class="hello" id="hello"></div>
    <h1 id="title">Zastrzyki</h1>
    <div id="now"><div class="glass muted">Ładuję…</div></div>
    <h2>Twoje wyniki</h2>
    <div class="stats" id="stats"></div>
    <h2>Ten tydzień</h2>
    <div class="week" id="week"></div>
  </section>

  <section class="view" id="v-cal">
    <div class="hello">Historia</div>
    <h1>Kalendarz</h1>
    <div class="glass">
      <div class="cal-head"><button class="nav" id="prev">‹</button><b id="month"></b><button class="nav" id="next">›</button></div>
      <div class="grid" id="grid"></div>
      <div class="legend">
        <span><i style="background:var(--green)"></i>zrobione</span>
        <span><i style="background:var(--red)"></i>olane</span>
        <span><i style="background:var(--orange)"></i>dziś</span>
        <span><i style="background:var(--reta1)"></i>Reta</span>
        <span><i style="background:var(--testo1)"></i>Testo</span>
        <span><i style="background:var(--grey)"></i>pominięte</span>
      </div>
    </div>
    <h2>Ostatnie zastrzyki</h2>
    <div class="hist" id="hist"></div>
  </section>

  <section class="view" id="v-set">
    <div class="hello">Ustawienia</div>
    <h1>Przypomnienia</h1>
    <div class="glass" id="notif"></div>
    <h2>Godziny</h2>
    <div class="glass">
      <div class="row"><div class="l"><b>Przypomnienie</b><span>w dniu zastrzyku i codziennie do skutku</span></div><select id="hour"></select></div>
      <div class="row"><div class="l"><b>Drugie przypomnienie</b><span>jeśli dalej nie odhaczone</span></div><select id="hour2"></select></div>
    </div>
    <h2>Plan</h2>
    <div class="glass">
      <div class="sched"><span><i class="dot reta"></i>Wtorek: Reta</span><span><i class="dot reta"></i>Piątek: Reta</span><span><i class="dot testo"></i>Niedziela: Testo</span></div>
    </div>
  </section>
</main>

<nav class="tabbar">
  <button class="tab active" data-tab="v-today"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="m18 2 4 4M17 7l3-3M19 9 8.7 19.3a2.4 2.4 0 0 1-3.4 0l-.6-.6a2.4 2.4 0 0 1 0-3.4L15 5M9 11l4 4M5 19l-3 3M14 4l6 6"/></svg>Dziś<span class="cnt" id="cnt" hidden></span></button>
  <button class="tab" data-tab="v-cal"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><rect x="3" y="4" width="18" height="18" rx="3"/><path d="M16 2v4M8 2v4M3 10h18"/></svg>Kalendarz</button>
  <button class="tab" data-tab="v-set"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M6 8a6 6 0 0 1 12 0c0 7 3 9 3 9H3s3-2 3-9M10.3 21a1.94 1.94 0 0 0 3.4 0"/></svg>Powiadom.</button>
</nav>

<div class="ov" id="celebrate"><div class="modal">
  <div class="checkwrap"><svg width="56" height="56" viewBox="0 0 24 24" fill="none" stroke="#04150c" stroke-width="3.2" stroke-linecap="round" stroke-linejoin="round"><path d="M5 12.5l4.5 4.5L19 7.5"/></svg></div>
  <div class="t" id="celT"></div><div class="s" id="celS"></div>
  <div class="btns"><button class="mb green" data-close>Jazda 💪</button></div>
</div></div>

<div class="ov" id="confirm"><div class="modal">
  <div class="big">🤔</div><div class="t" id="cfT"></div><div class="s" id="cfS"></div>
  <div class="btns"><button class="mb red" id="cfYes">Tak, pomiń</button><button class="mb plain" data-close>Anuluj</button></div>
</div></div>

<div class="ov sheet" id="sheet"><div class="modal" id="sheetBody"></div></div>
<canvas id="confetti"></canvas>
<div class="toast" id="toast"></div>

<script>
${shared}
const DN = ["niedziela","poniedziałek","wtorek","środa","czwartek","piątek","sobota"];
const DS = ["nd","pn","wt","śr","cz","pt","sb"];
const MN = ["styczeń","luty","marzec","kwiecień","maj","czerwiec","lipiec","sierpień","wrzesień","październik","listopad","grudzień"];
const CHEERS = [["Brawo, byku!","Kolejny odhaczony. Tak się robi formę."],["Maszyna! 🦾","Zastrzyk zaliczony, lecisz dalej."],["Zrobione ✅","Systematyczność to jest klucz."],["Petarda! 🔥","Seria rośnie, nie odpuszczaj."],["Szacun 💪","Ciało ci podziękuje."]];
let S = null; let view = null; let pendingSkip = null;
const $ = (id) => document.getElementById(id);
const fmt = (iso) => { const [y,m,d] = iso.split("-"); return DN[weekday(iso)] + " " + Number(d) + "." + m; };
const daysBetween = (a, b) => Math.round((new Date(b) - new Date(a)) / 864e5);
const standalone = window.navigator.standalone === true || matchMedia("(display-mode: standalone)").matches;
const isIOS = /iPhone|iPad|iPod/.test(navigator.userAgent) || (navigator.platform === "MacIntel" && navigator.maxTouchPoints > 1);
const ICON = { reta: "💉", testo: "💪" };

function toast(t) { const el = $("toast"); el.textContent = t; el.classList.add("show"); clearTimeout(toast.h); toast.h = setTimeout(() => el.classList.remove("show"), 2200); }
function openOv(id) { $(id).classList.add("open"); }
function closeOv(id) { $(id).classList.remove("open"); }

async function api(path, body) {
  const r = await fetch(path, body ? { method: "POST", headers: { "content-type": "application/json" }, body: JSON.stringify(body) } : { cache: "no-store" });
  if (!r.ok) throw new Error("HTTP " + r.status);
  return r.json();
}

async function load() {
  try { S = await api("api/state"); }
  catch (e) { $("now").innerHTML = '<div class="glass">Brak internetu. Spróbuj za chwilę.</div>'; return; }
  if (!view) view = S.today.slice(0, 7);
  render();
}

function statusOf(dose) {
  const m = S.marks[dose.id];
  if (m) return m.s === "done" ? "done" : "skip";
  if (dose.date > S.today) return "plan";
  if (dose.date < S.settings.start) return "past-plan";
  return dose.date === S.today ? "due" : "miss";
}

function computeStats() {
  const all = dosesBetween(S.settings.start, S.today).reverse();
  let streak = 0;
  for (const d of all) {
    const st = statusOf(d);
    if (st === "due") continue;
    if (st === "done") streak++; else break;
  }
  const past = all.filter((d) => statusOf(d) !== "due");
  const done = past.filter((d) => statusOf(d) === "done").length;
  const pct = past.length ? Math.round((done / past.length) * 100) : 100;
  return { streak, done, pct };
}

function render() {
  const pending = pendingDoses(S.settings.start, S.today, S.marks);
  try { if (navigator.setAppBadge) pending.length ? navigator.setAppBadge(pending.length) : navigator.clearAppBadge(); } catch (e) {}
  const cnt = $("cnt"); cnt.hidden = !pending.length; cnt.textContent = pending.length;
  const h = new Date().getHours();
  $("hello").textContent = (h < 5 ? "Dobranoc" : h < 12 ? "Dzień dobry" : h < 18 ? "Cześć" : "Dobry wieczór") + " · " + fmt(S.today);
  $("title").textContent = pending.length ? (pending.length > 1 ? "Masz zaległości" : "Czas na zastrzyk") : "Jesteś na bieżąco";

  let out = "";
  if (pending.length) {
    pending.forEach((p, i) => {
      const late = daysBetween(p.date, S.today);
      const badge = late === 0 ? '<span class="badge">⏰ Dziś</span>' : '<span class="badge late">⚠️ Zaległe ' + late + " " + (late === 1 ? "dzień" : "dni") + "</span>";
      out += '<div class="dose ' + p.type + '" style="animation-delay:' + i * 0.08 + 's">' + badge +
        '<div class="name">' + ICON[p.type] + " " + NAMES[p.type] + '</div><div class="when">' + fmt(p.date) + '</div>' +
        '<div class="acts"><button class="donebtn" data-done="' + p.id + '">Zrobione ✓</button><button class="skipbtn" data-skip="' + p.id + '">Pomiń</button></div></div>';
    });
  } else {
    const next = dosesBetween(addDays(S.today, 1), addDays(S.today, 8))[0];
    const inDays = next ? daysBetween(S.today, next.date) : 0;
    out = '<div class="glass allgood"><div class="e">💪</div><div class="t">Wszystko odhaczone</div><div class="muted">Odpoczywaj, dam znać, jak przyjdzie pora.</div>' +
      (next ? '<div class="next"><i class="dot ' + next.type + '"></i>' + NAMES[next.type] + " " + (inDays === 1 ? "jutro" : "za " + inDays + " dni") + " · " + fmt(next.date) + "</div>" : "") + "</div>";
  }
  $("now").innerHTML = out;

  const st = computeStats();
  $("stats").innerHTML =
    '<div class="glass stat"><b>' + st.streak + (st.streak >= 3 ? "🔥" : "") + '</b><span>z rzędu</span></div>' +
    '<div class="glass stat"><b style="color:var(--green)">' + st.done + '</b><span>zrobione</span></div>' +
    '<div class="glass stat"><b style="color:' + (st.pct >= 80 ? "var(--green)" : st.pct >= 50 ? "var(--orange)" : "var(--red)") + '">' + st.pct + '%</b><span>skuteczność</span></div>';

  // week strip, Monday..Sunday of current week
  const mon = addDays(S.today, -((weekday(S.today) + 6) % 7));
  let w = "";
  for (let i = 0; i < 7; i++) {
    const d = addDays(mon, i), t = SCHEDULE[weekday(d)];
    let dot = "";
    if (t) { const s = statusOf({ date: d, type: t, id: d + "|" + t }); dot = '<i class="dot ' + (s === "done" ? "done" : t) + '"' + (s === "miss" ? ' style="background:var(--red)"' : "") + "></i>"; }
    w += '<div class="wday' + (d === S.today ? " today" : "") + '"' + (t ? ' data-day="' + d + "|" + t + '"' : "") + '><div class="n">' + DS[weekday(d)] + '</div><div class="d">' + Number(d.slice(8)) + "</div>" + (dot || '<i class="dot" style="opacity:0"></i>') + "</div>";
  }
  $("week").innerHTML = w;
  renderCal(false);
  renderHist();
  renderNotif();
  renderSettings();
}

function renderCal(anim) {
  const [y, m] = view.split("-").map(Number);
  $("month").textContent = MN[m - 1] + " " + y;
  const first = view + "-01";
  const daysIn = new Date(Date.UTC(y, m, 0)).getUTCDate();
  const lead = (weekday(first) + 6) % 7;
  let h = ["pn","wt","śr","cz","pt","sb","nd"].map((d) => '<div class="wd">' + d + "</div>").join("");
  for (let i = 0; i < lead; i++) h += '<div class="day empty"></div>';
  for (let d = 1; d <= daysIn; d++) {
    const iso = view + "-" + String(d).padStart(2, "0");
    const t = SCHEDULE[weekday(iso)];
    let cls = "day", tag = "";
    if (t) { cls += " " + statusOf({ date: iso, type: t, id: iso + "|" + t }); tag = '<span class="tag ' + t + '">' + (t === "reta" ? "RETA" : "TESTO") + "</span>"; }
    if (iso === S.today) cls += " isToday";
    h += '<div class="' + cls + '"' + (t ? ' data-day="' + iso + "|" + t + '"' : "") + ">" + d + tag + "</div>";
  }
  const g = $("grid"); g.innerHTML = h;
  if (anim) { g.classList.remove("anim"); void g.offsetWidth; g.classList.add("anim"); }
}

function renderHist() {
  const all = dosesBetween(S.settings.start, S.today).reverse().slice(0, 12);
  const label = { done: "Zrobione", miss: "Olane", skip: "Pominięte", due: "Dziś" };
  $("hist").innerHTML = all.length ? all.map((d) => {
    const s = statusOf(d); const m = S.marks[d.id];
    const at = m && m.at ? " · " + new Date(m.at).toLocaleTimeString("pl-PL", { hour: "2-digit", minute: "2-digit" }) : "";
    return '<div class="hrow press" data-day="' + d.id + '"><div class="ic ' + d.type + '">' + ICON[d.type] + '</div><div class="tx"><b>' + NAMES[d.type] + "</b><span>" + fmt(d.date) + at + '</span></div><span class="pill ' + s + '">' + label[s] + "</span></div>";
  }).join("") : '<div class="muted">Tu pojawi się historia.</div>';
}

function openSheet(id) {
  const [date, type] = id.split("|");
  if (date > S.today) { toast("📅 To dopiero " + fmt(date)); return; }
  const cur = S.marks[id];
  $("sheetBody").innerHTML = '<div class="grab"></div><div style="display:flex;align-items:center;gap:14px;margin-bottom:18px"><div class="hrow" style="padding:0;border:0;background:none"><div class="ic ' + type + '" style="width:52px;height:52px;font-size:24px;border-radius:16px">' + ICON[type] + '</div></div><div><div class="t" style="margin:0">' + NAMES[type] + '</div><div class="muted">' + fmt(date) + " · " + (cur ? (cur.s === "done" ? "zrobione ✓" : "pominięte") : "nieodhaczone") + "</div></div></div>" +
    '<div class="btns"><button class="mb green" data-done="' + id + '">Zrobione ✓</button><button class="mb" data-skipnow="' + id + '">Pominięte</button>' +
    (cur ? '<button class="mb" data-undo="' + id + '">Cofnij odhaczenie</button>' : "") + '<button class="mb plain" data-close>Anuluj</button></div>';
  openOv("sheet");
}

async function mark(id, s) {
  ["sheet", "confirm"].forEach(closeOv);
  const prev = S.marks[id];
  if (s) S.marks[id] = { s, at: new Date().toISOString() }; else delete S.marks[id];
  render();
  if (s === "done") celebrate();
  try { await api("api/mark", { id, status: s || null }); if (s !== "done") toast(s === "skip" ? "Pominięte" : "↩️ Cofnięte"); }
  catch (e) { if (prev) S.marks[id] = prev; else delete S.marks[id]; render(); closeOv("celebrate"); toast("⚠️ Nie zapisało się, brak netu?"); }
}

function celebrate() {
  const c = CHEERS[Math.floor(Math.random() * CHEERS.length)];
  const st = computeStats();
  $("celT").textContent = c[0];
  $("celS").textContent = c[1] + (st.streak >= 2 ? " Seria: " + st.streak + " z rzędu 🔥" : "");
  const cw = document.querySelector(".checkwrap"); const clone = cw.cloneNode(true); cw.replaceWith(clone);
  openOv("celebrate");
  confetti();
}

function confetti() {
  const cv = $("confetti"), ctx = cv.getContext("2d"), dpr = window.devicePixelRatio || 1;
  cv.width = innerWidth * dpr; cv.height = innerHeight * dpr; ctx.scale(dpr, dpr);
  const colors = ["#34e08a", "#7b5cff", "#c04dff", "#ffab2e", "#ff5267", "#5b8cff", "#ffffff"];
  const P = Array.from({ length: 140 }, () => ({
    x: innerWidth / 2, y: innerHeight * 0.42, vx: (Math.random() - 0.5) * 16, vy: -Math.random() * 15 - 4,
    r: Math.random() * 6 + 4, c: colors[(Math.random() * colors.length) | 0], a: Math.random() * 6, va: (Math.random() - 0.5) * 0.4, life: 0,
  }));
  let t0 = performance.now();
  (function step(t) {
    ctx.clearRect(0, 0, innerWidth, innerHeight);
    for (const p of P) {
      p.vy += 0.38; p.vx *= 0.99; p.x += p.vx; p.y += p.vy; p.a += p.va;
      ctx.save(); ctx.translate(p.x, p.y); ctx.rotate(p.a); ctx.fillStyle = p.c;
      ctx.globalAlpha = Math.max(0, 1 - (t - t0) / 2600); ctx.fillRect(-p.r / 2, -p.r / 4, p.r, p.r / 2); ctx.restore();
    }
    if (t - t0 < 2600) requestAnimationFrame(step); else ctx.clearRect(0, 0, innerWidth, innerHeight);
  })(t0);
}

function renderNotif() {
  const el = $("notif");
  if (!("serviceWorker" in navigator)) { el.innerHTML = '<div class="muted">Ta przeglądarka nie obsługuje powiadomień.</div>'; return; }
  if (isIOS && !standalone) {
    el.innerHTML = '<b style="font-size:18px">📲 Najpierw dodaj apkę na ekran</b><ol>' +
      '<li>Na dole Safari kliknij <b>Udostępnij</b> (kwadrat ze strzałką).</li>' +
      '<li>Wybierz <b>Do ekranu początkowego</b>, potem <b>Dodaj</b>.</li>' +
      '<li>Otwórz apkę <b>Zastrzyki</b> z ekranu i włącz tu powiadomienia.</li></ol>';
    return;
  }
  const perm = ("Notification" in window) ? Notification.permission : "unsupported";
  if (perm === "granted") {
    el.innerHTML = '<div class="ok-line"><span class="live"></span>Powiadomienia włączone</div><button class="btn ghost" id="test">Wyślij testowe powiadomienie</button>';
  } else if (perm === "denied") {
    el.innerHTML = '<b>🔕 Powiadomienia zablokowane</b><div class="muted" style="margin-top:6px">Włącz je w Ustawienia → Powiadomienia → Zastrzyki.</div>';
  } else {
    el.innerHTML = '<div style="font-size:18px;font-weight:800;margin-bottom:6px">🔔 Włącz przypomnienia</div><div class="muted" style="margin-bottom:16px">Bez tego apka nie przypomni ci o zastrzyku.</div><button class="btn" id="enable">Włącz powiadomienia</button>';
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
  if (ask) toast("🔔 Powiadomienia włączone");
}

function showTab(id) {
  document.querySelectorAll(".view").forEach((v) => v.classList.toggle("active", v.id === id));
  document.querySelectorAll(".tab").forEach((t) => t.classList.toggle("active", t.dataset.tab === id));
  window.scrollTo({ top: 0 });
}

document.addEventListener("click", async (e) => {
  const t = e.target.closest("[data-tab],[data-done],[data-skip],[data-skipnow],[data-undo],[data-day],[data-close],#prev,#next,#enable,#test,#cfYes,.ov");
  if (!t) return;
  if (t.dataset.tab) return showTab(t.dataset.tab);
  if (t.dataset.done) return mark(t.dataset.done, "done");
  if (t.dataset.skipnow) return mark(t.dataset.skipnow, "skip");
  if (t.dataset.undo) return mark(t.dataset.undo, null);
  if (t.dataset.skip) {
    pendingSkip = t.dataset.skip; const [d, ty] = pendingSkip.split("|");
    $("cfT").textContent = "Pominąć " + NAMES[ty] + "?"; $("cfS").textContent = fmt(d) + ". Nie będę już o nim przypominać.";
    return openOv("confirm");
  }
  if (t.id === "cfYes") return mark(pendingSkip, "skip");
  if (t.dataset.day) return openSheet(t.dataset.day);
  if (t.hasAttribute("data-close")) return document.querySelectorAll(".ov").forEach((o) => o.classList.remove("open"));
  if (t.classList.contains("ov")) { if (e.target === t) t.classList.remove("open"); return; }
  if (t.id === "prev" || t.id === "next") {
    const [y, m] = view.split("-").map(Number); const d = new Date(Date.UTC(y, m - 1 + (t.id === "next" ? 1 : -1), 1));
    view = d.toISOString().slice(0, 7); renderCal(true); return;
  }
  if (t.id === "enable") { t.disabled = true; try { await subscribe(true); } catch (err) { toast("Błąd: " + err.message); t.disabled = false; } return; }
  if (t.id === "test") { t.disabled = true; try { await subscribe(false); const r = await api("api/test", {}); toast(r.sent ? "📨 Wysłane, zaraz przyjdzie" : "Brak zapisanych telefonów"); } catch (err) { toast("Błąd: " + err.message); } t.disabled = false; return; }
});

for (const id of ["hour", "hour2"]) $(id).addEventListener("change", async () => {
  const hour = Number($("hour").value); const v2 = $("hour2").value; const hour2 = v2 === "" ? null : Number(v2);
  try { const r = await api("api/settings", { hour, hour2 }); S.settings = r.settings; toast("✅ Zapisane"); } catch (e) { toast("Nie zapisało się"); }
});

if ("serviceWorker" in navigator) navigator.serviceWorker.register("sw.js");
document.addEventListener("visibilitychange", () => { if (document.visibilityState === "visible") load(); });
load().then(() => { if (window.Notification && Notification.permission === "granted" && "serviceWorker" in navigator) subscribe(false).catch(() => {}); });
</script>
</body>
</html>`;
}
