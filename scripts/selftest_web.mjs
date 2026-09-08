#!/usr/bin/env node
/**
 * Web 构建交互体验自测（v0.1.2 后续）：真实鼠标事件走完整玩家流程，
 * 每步截图 + 面板栈信标（window.__DSH_PANEL_STATE__）确定性断言。
 * 零第三方依赖（Node >= 22 原生 WebSocket）。
 *
 * 用法：node scripts/selftest_web.mjs
 * 依赖：本机 godot 与 google-chrome（与 capture_screens_web.mjs 相同）。
 */
import { spawn, execFile } from "node:child_process";
import { mkdtemp, mkdir, writeFile, readFile, rm } from "node:fs/promises";
import { setTimeout as sleep } from "node:timers/promises";
import http from "node:http";
import os from "node:os";
import path from "node:path";
import { fileURLToPath } from "node:url";

const REPO_ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const GODOT_BIN = process.env.GODOT_BIN ?? "godot";
const CHROME_BIN = process.env.CHROME_BIN ?? "google-chrome";
const HOST = "127.0.0.1";
const PORT = 8973;
const OUT_DIR = path.join(REPO_ROOT, "docs/playtest/screenshots/2026-09-08-v0.1.3-selftest");
const SETTLE_MS = 900;

const MIME = {
  ".html": "text/html; charset=utf-8",
  ".js": "text/javascript",
  ".wasm": "application/wasm",
  ".pck": "application/octet-stream",
  ".png": "image/png",
  ".svg": "image/svg+xml",
};

function run(cmd, args) {
  return new Promise((resolve, reject) => {
    execFile(cmd, args, { cwd: REPO_ROOT, maxBuffer: 64 * 1024 * 1024 }, (err, stdout, stderr) => {
      if (err) reject(new Error(`${cmd} ${args.join(" ")}\n${stdout}\n${stderr}`));
      else resolve();
    });
  });
}

function startStaticServer() {
  const server = http.createServer((req, res) => {
    const url = new URL(req.url, `http://${HOST}:${PORT}`);
    const file = path.join(REPO_ROOT, "build/web", path.normalize(decodeURIComponent(url.pathname)));
    if (!file.startsWith(path.join(REPO_ROOT, "build/web"))) {
      res.writeHead(403).end();
      return;
    }
    readFile(file)
      .then((buf) => {
        res.writeHead(200, {
          "Content-Type": MIME[path.extname(file)] ?? "application/octet-stream",
          "Cross-Origin-Opener-Policy": "cross-origin",
          "Cross-Origin-Embedder-Policy": "require-corp",
        });
        res.end(buf);
      })
      .catch(() => res.writeHead(404).end());
  });
  return new Promise((resolve) => server.listen(PORT, HOST, () => resolve(server)));
}

function startChrome() {
  const profile = mkdtemp(path.join(os.tmpdir(), "dsh-selftest-chrome-"));
  return profile.then((dir) => new Promise((resolve, reject) => {
    const child = spawn(CHROME_BIN, [
      "--headless=new", "--remote-debugging-port=0", `--user-data-dir=${dir}`,
      "--no-first-run", "--disable-gpu-sandbox", "--hide-scrollbars", "--window-size=390,844", "about:blank",
    ], { stdio: ["ignore", "pipe", "pipe"] });
    let buf = "";
    const timer = setTimeout(() => reject(new Error("Chrome 启动超时")), 30000);
    child.stderr.on("data", (d) => {
      buf += d.toString();
      const m = buf.match(/DevTools listening on (ws:\/\/\S+)/);
      if (m) { clearTimeout(timer); resolve({ child, wsUrl: m[1], profile: dir }); }
    });
  }));
}

class Cdp {
  constructor(wsUrl) { this.ws = new WebSocket(wsUrl); this.id = 0; this.pending = new Map(); }
  async connect() {
    await new Promise((res, rej) => {
      this.ws.addEventListener("open", res, { once: true });
      this.ws.addEventListener("error", rej, { once: true });
    });
    this.ws.addEventListener("message", (ev) => {
      const msg = JSON.parse(ev.data);
      if (msg.id && this.pending.has(msg.id)) {
        const { resolve, reject } = this.pending.get(msg.id);
        this.pending.delete(msg.id);
        msg.error ? reject(new Error(msg.error.message)) : resolve(msg.result);
      }
    });
  }
  send(method, params = {}, sessionId) {
    const id = ++this.id;
    return new Promise((resolve, reject) => {
      this.pending.set(id, { resolve, reject });
      this.ws.send(JSON.stringify({ id, method, params, ...(sessionId ? { sessionId } : {}) }));
      setTimeout(() => { if (this.pending.has(id)) { this.pending.delete(id); reject(new Error(`CDP 超时: ${method}`)); } }, 30000);
    });
  }
}

// ---------- 断言与记录 ----------
const results = [];
function check(name, ok, detail = "") {
  results.push({ name, ok, detail });
  console.log(`  ${ok ? "✔" : "✘"} ${name}${detail ? ` (${detail})` : ""}`);
  if (!ok) process.exitCode = 1;
}

// ---------- 交互自测主流程 ----------
const server = await startStaticServer();
const { child, wsUrl, profile } = await startChrome();
const cdp = new Cdp(wsUrl);
await cdp.connect();

const { targetId } = await cdp.send("Target.createTarget", { url: "about:blank" });
const { sessionId } = await cdp.send("Target.attachToTarget", { targetId, flatten: true });
await cdp.send("Page.enable", {}, sessionId);
await cdp.send("Runtime.enable", {}, sessionId);
await cdp.send("Emulation.setDeviceMetricsOverride", { width: 390, height: 844, deviceScaleFactor: 2, mobile: true }, sessionId);
await cdp.send("Page.navigate", { url: `http://${HOST}:${PORT}/index.html?selftest=1` }, sessionId);

// 等引擎就绪（无 shot 参数，__DSH_SHOT_READY__ 不会置位——selftest 用面板信标自身出现判定）
{
  const deadline = Date.now() + 90000;
  let ready = false;
  while (Date.now() < deadline && !ready) {
    const r = await cdp.send("Runtime.evaluate", { expression: "window.__DSH_PANEL_STATE__ !== undefined", returnByValue: true }, sessionId);
    ready = r?.result?.value === true;
    if (!ready) await sleep(600);
  }
  if (!ready) throw new Error("引擎就绪超时（面板信标未出现）");
  await sleep(SETTLE_MS);
}

const evalJs = async (expr) => {
  const r = await cdp.send("Runtime.evaluate", { expression: expr, returnByValue: true }, sessionId);
  return r?.result?.value;
};
const panelState = () => evalJs("window.__DSH_PANEL_STATE__.depth");
const waitForDepth = async (expected, timeoutMs = 5000) => {
  const deadline = Date.now() + timeoutMs;
  let last = await panelState();
  while (Date.now() < deadline) {
    last = await panelState();
    if (last === expected) return true;
    await sleep(150);
  }
  return false;
};
const click = (x, y) => cdp.send("Input.dispatchMouseEvent", { type: "mousePressed", x, y, button: "left", clickCount: 1 }, sessionId)
  .then(() => cdp.send("Input.dispatchMouseEvent", { type: "mouseReleased", x, y, button: "left", clickCount: 1 }, sessionId));
const shot = async (name) => {
  const s = await cdp.send("Page.captureScreenshot", { format: "png" }, sessionId);
  await mkdir(OUT_DIR, { recursive: true });
  const file = path.join(OUT_DIR, `${name}.png`);
  await writeFile(file, Buffer.from(s.data, "base64"));
  console.log(`    📷 ${path.relative(REPO_ROOT, file)}`);
};

console.log("交互体验自测（390x844 竖屏，真实鼠标事件）:");

// S0 开场引导（v0.1.3）：正常游玩启动即推入 z1 INTRO，点击"开始经营"关闭
check("S0 开场引导自动弹出，面板深度 1", await waitForDepth(1), `depth=${await panelState()}`);
await shot("S0-intro");

// S1 关闭开场引导 → 主工作台（开始经营按钮中心实测 CSS 坐标，见 S0 截图）
await click(195, 507);
check("S1 点击开始经营 → 面板栈清空", await waitForDepth(0), `depth=${await panelState()}`);
await shot("S1-home");

// S2 打开科技树
await click(78, 804);
check("S2 点击科技键 → 面板深度 1", await waitForDepth(1), `depth=${await panelState()}`);
await shot("S2-tech-open");

// S3 关闭科技树
await click(352, 244);
check("S3 点击关闭 → 面板栈清空", await waitForDepth(0), `depth=${await panelState()}`);

// S4 打开周报
await click(195, 804);
check("S4 点击周报键 → 面板深度 1", await waitForDepth(1), `depth=${await panelState()}`);
await shot("S4-report-open");

// S5 确认周报（按钮中心实测 CSS 坐标，见 S4 截图）
await click(195, 537);
check("S5 点击确认 → 面板栈清空", await waitForDepth(0), `depth=${await panelState()}`);

// S6 暂停菜单（已知缺陷 #67 现场取证）
await click(312, 804);
await waitForDepth(1);
const depthAfterPause = await panelState();
check("S6 点击暂停键（#67 取证）", true, `depth=${depthAfterPause}（预期 1；若 0 即 #67 无面板缺陷现场）`);
await shot("S6-pause-issue67");

// S7 遮罩点击恢复
await click(195, 500);
check("S7 点击遮罩 → 面板栈清空", await waitForDepth(0), `depth=${await panelState()}`);

// 清理
cdp.ws.close();
child.kill();
await rm(profile, { recursive: true, force: true }).catch(() => {});
server.close();

console.log(`\n结果: ${results.filter((r) => r.ok).length}/${results.length} 项通过`);
if (process.exitCode === 1) console.log("存在失败项，详见上方 ✘ 条目");
