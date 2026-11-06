import { generateVapidKeys, sendPush } from "./push.js";
import { SCHEDULE, NAMES, addDays, weekday, dosesBetween, pendingDoses } from "./schedule.js";
import { pageHtml, swJs, manifest } from "./client.js";
import { ICON_180, ICON_512 } from "./icons.js";

const TZ = "Europe/Warsaw";
const SUBJECT = "mailto:przypominajka@example.com";
const DAY_NAMES = ["nd", "pn", "wt", "śr", "cz", "pt", "sb"];

function warsawNow(date = new Date()) {
  const p = Object.fromEntries(
    new Intl.DateTimeFormat("en-CA", {
      timeZone: TZ, year: "numeric", month: "2-digit", day: "2-digit", hour: "2-digit", hourCycle: "h23",
    }).formatToParts(date).map((x) => [x.type, x.value])
  );
  return { date: `${p.year}-${p.month}-${p.day}`, hour: Number(p.hour) };
}

async function getJSON(env, key, fallback) {
  const v = await env.STATE.get(key, "json");
  return v ?? fallback;
}
const putJSON = (env, key, v) => env.STATE.put(key, JSON.stringify(v));

async function getSettings(env) {
  return getJSON(env, "settings", { hour: 10, hour2: null, start: env.START_DATE || warsawNow().date });
}

async function getVapid(env) {
  let v = await getJSON(env, "vapid", null);
  if (!v) { v = await generateVapidKeys(); await putJSON(env, "vapid", v); }
  return v;
}

function fmt(iso) {
  const [, m, d] = iso.split("-");
  return `${DAY_NAMES[weekday(iso)]} ${Number(d)}.${m}`;
}

function buildMessage(pending, today) {
  const todays = pending.filter((p) => p.date === today);
  const old = pending.filter((p) => p.date !== today);
  if (old.length === 0) {
    const what = todays.map((p) => NAMES[p.type]).join(" + ");
    return { title: `💉 Dziś zastrzyk: ${what}`, body: "Jak zrobisz, wejdź i kliknij „Zrobione”." };
  }
  const list = pending.map((p) => `${NAMES[p.type]} (${fmt(p.date)})`).join(", ");
  return { title: "💉 Nie odhaczyłeś zastrzyku!", body: `Zaległe: ${list}. Zrób i kliknij „Zrobione”.` };
}

async function notifyAll(env, { force = false } = {}) {
  const now = warsawNow();
  const settings = await getSettings(env);
  const marks = await getJSON(env, "marks", {});
  const pending = pendingDoses(settings.start, now.date, marks);
  let msg;
  if (pending.length) msg = buildMessage(pending, now.date);
  else if (force) msg = { title: "✅ Test powiadomień", body: "Działa! Nic nie masz do zrobienia na teraz." };
  else return { sent: 0, pending: 0 };

  const subs = await getJSON(env, "subs", []);
  const vapid = await getVapid(env);
  const keep = [];
  const results = [];
  for (const sub of subs) {
    let status;
    try { status = await sendPush(sub, { ...msg, badge: pending.length, url: "./" }, vapid, SUBJECT); }
    catch (e) { status = "error: " + e.message; }
    results.push(status);
    if (status !== 404 && status !== 410) keep.push(sub);
  }
  if (keep.length !== subs.length) await putJSON(env, "subs", keep);
  return { sent: subs.length, pending: pending.length, results };
}

const json = (v, status = 200) =>
  new Response(JSON.stringify(v), { status, headers: { "content-type": "application/json", "cache-control": "no-store" } });

function png(b64) {
  const bin = atob(b64);
  const bytes = new Uint8Array(bin.length);
  for (let i = 0; i < bin.length; i++) bytes[i] = bin.charCodeAt(i);
  return new Response(bytes, { headers: { "content-type": "image/png", "cache-control": "public, max-age=604800" } });
}

async function handle(request, env) {
  const url = new URL(request.url);
  const base = `/${env.KEY}`;
  if (url.pathname === base) return Response.redirect(url.origin + base + "/", 302);
  if (!url.pathname.startsWith(base + "/")) return new Response("Not found", { status: 404 });
  const path = url.pathname.slice(base.length + 1);
  const method = request.method;

  if (path === "" && method === "GET")
    return new Response(pageHtml(), { headers: { "content-type": "text/html; charset=utf-8", "cache-control": "no-cache" } });
  if (path === "sw.js")
    return new Response(swJs(), { headers: { "content-type": "text/javascript", "cache-control": "no-cache" } });
  if (path === "manifest.webmanifest")
    return new Response(JSON.stringify(manifest()), { headers: { "content-type": "application/manifest+json" } });
  if (path === "icon-180.png") return png(ICON_180);
  if (path === "icon-512.png") return png(ICON_512);

  if (path === "api/state" && method === "GET") {
    const [settings, marks, vapid] = await Promise.all([getSettings(env), getJSON(env, "marks", {}), getVapid(env)]);
    return json({ today: warsawNow().date, settings, marks, vapidPublic: vapid.publicKey });
  }

  if (method !== "POST") return new Response("Not found", { status: 404 });
  const body = await request.json().catch(() => ({}));

  if (path === "api/mark") {
    const { id, status } = body;
    if (!/^\d{4}-\d{2}-\d{2}\|(reta|testo)$/.test(id || "")) return json({ error: "bad id" }, 400);
    const [date, type] = id.split("|");
    if (SCHEDULE[weekday(date)] !== type) return json({ error: "no dose that day" }, 400);
    const marks = await getJSON(env, "marks", {});
    if (status === "done" || status === "skip") marks[id] = { s: status, at: new Date().toISOString() };
    else delete marks[id];
    await putJSON(env, "marks", marks);
    return json({ ok: true, marks });
  }

  if (path === "api/settings") {
    const s = await getSettings(env);
    const okHour = (h) => Number.isInteger(h) && h >= 0 && h <= 23;
    if (okHour(body.hour)) s.hour = body.hour;
    if (body.hour2 === null || okHour(body.hour2)) s.hour2 = body.hour2;
    await putJSON(env, "settings", s);
    return json({ ok: true, settings: s });
  }

  if (path === "api/subscribe") {
    const sub = body.subscription;
    if (!sub?.endpoint || !sub?.keys?.p256dh || !sub?.keys?.auth) return json({ error: "bad subscription" }, 400);
    const subs = (await getJSON(env, "subs", [])).filter((s) => s.endpoint !== sub.endpoint);
    subs.push({ endpoint: sub.endpoint, keys: sub.keys });
    await putJSON(env, "subs", subs.slice(-5));
    return json({ ok: true });
  }

  if (path === "api/test") return json(await notifyAll(env, { force: true }));

  return new Response("Not found", { status: 404 });
}

export default {
  fetch: (request, env) => handle(request, env),

  async scheduled(event, env, ctx) {
    const now = warsawNow(new Date(event.scheduledTime));
    const s = await getSettings(env);
    if (now.hour === s.hour || (s.hour2 !== null && now.hour === s.hour2)) {
      ctx.waitUntil(notifyAll(env));
    }
  },
};

// exported for tests
export { warsawNow, buildMessage, notifyAll };
