#!/usr/bin/env node
/**
 * Web 导出真实渲染截图管线（v0.1.2，零第三方依赖，Node >= 22 原生 WebSocket/fetch）。
 *
 * 流程：godot --headless --import → --export-release Web → 本地静态服务
 *       → headless Chrome(CDP) → 模拟 390x844 竖屏 / 1280x720 桌面
 *       → 轮询 window.__DSH_SHOT_READY__ → Page.captureScreenshot → 归档 PNG。
 *
 * 用法：node scripts/capture_screens_web.mjs [--out docs/playtest/screenshots/xxx]
 * 依赖：本机 godot（GODOT_BIN 可覆盖）与 google-chrome（CHROME_BIN 可覆盖）。
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
const PORT = 8971;
const NAV_TIMEOUT_MS = 90_000; // Godot WASM 冷启动 + 首帧就绪上限
const SETTLE_MS = 1_500; // 就绪后再等渲染稳定

const MIME = {
  ".html": "text/html; charset=utf-8",
  ".js": "text/javascript",
  ".mjs": "text/javascript",
  ".wasm": "application/wasm",
  ".pck": "application/octet-stream",
  ".png": "image/png",
  ".svg": "image/svg+xml",
  ".json": "application/json",
  ".ico": "image/x-icon",
};

const VIEWPORTS = [
  { tag: "portrait-390x844", width: 390, height: 844, dsf: 2, mobile: true },
  { tag: "desktop-1280x720", width: 1280, height: 720, dsf: 1, mobile: false },
];
const SHOTS = ["home", "intro", "tech", "report", "gameover", "task"];

// ---------- 参数 ----------
function parseArgs(argv) {
  const date = new Date().toISOString().slice(0, 10);
  let out = path.join(REPO_ROOT, "docs/playtest/screenshots", `${date}-v0.1.2`);
  const i = argv.indexOf("--out");
  if (i !== -1 && argv[i + 1]) out = path.resolve(REPO_ROOT, argv[i + 1]);
  return { out };
}

// ---------- 步骤 1：Web 导出 ----------
function run(cmd, args, opts = {}) {
  return new Promise((resolve, reject) => {
    execFile(cmd, args, { cwd: REPO_ROOT, maxBuffer: 64 * 1024 * 1024, ...opts }, (err, stdout, stderr) => {
      if (err) reject(new Error(`${cmd} ${args.join(" ")}\n${stdout}\n${stderr}`));
      else resolve({ stdout, stderr });
    });
  });
}

async function exportWeb() {
  console.log("[1/4] godot --headless --import ...");
  await run(GODOT_BIN, ["--headless", "--import", "--quit"]);
  // Godot 导出要求目标目录已存在（与 CI release-build.yml 的 mkdir 一致）
  await mkdir(path.join(REPO_ROOT, "build/web"), { recursive: true });
  console.log("[1/4] godot --headless --export-release Web ...");
  await run(GODOT_BIN, ["--headless", "--export-release", "Web", "build/web/index.html"]);
  console.log("[1/4] Web 导出完成: build/web/");
}

// ---------- 步骤 2：静态服务 ----------
function startStaticServer() {
  const server = http.createServer((req, res) => {
    const url = new URL(req.url, `http://${HOST}:${PORT}`);
    let file = path.join(REPO_ROOT, "build/web", path.normalize(decodeURIComponent(url.pathname)));
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
      .catch(() => res.writeHead(404).end("not found"));
  });
  return new Promise((resolve) => server.listen(PORT, HOST, () => resolve(server)));
}

// ---------- 步骤 3：Chrome + CDP ----------
async function startChrome() {
  const profile = await mkdtemp(path.join(os.tmpdir(), "dsh-shot-chrome-"));
  return new Promise((resolve, reject) => {
    const child = spawn(
      CHROME_BIN,
      [
        "--headless=new",
        "--remote-debugging-port=0",
        `--user-data-dir=${profile}`,
        "--no-first-run",
        "--disable-gpu-sandbox",
        "--hide-scrollbars",
        "about:blank",
      ],
      { stdio: ["ignore", "pipe", "pipe"] },
    );
    let buf = "";
    const timer = setTimeout(() => reject(new Error("Chrome 启动超时")), 30_000);
    child.stderr.on("data", (d) => {
      buf += d.toString();
      const m = buf.match(/DevTools listening on (ws:\/\/\S+)/);
      if (m) {
        clearTimeout(timer);
        resolve({ child, wsUrl: m[1], profile });
      }
    });
    child.on("exit", (code) => reject(new Error(`Chrome 提前退出: ${code}`)));
  });
}

/** 极简 CDP 客户端（flatten 模式，支持 sessionId） */
class Cdp {
  constructor(wsUrl) {
    this.ws = new WebSocket(wsUrl);
    this.id = 0;
    this.pending = new Map();
    this.listeners = new Set();
  }
  async connect() {
    if (this.ws.readyState === 0) {
      await new Promise((res, rej) => {
        this.ws.addEventListener("open", res, { once: true });
        this.ws.addEventListener("error", rej, { once: true });
      });
    }
    this.ws.addEventListener("message", (ev) => {
      const msg = JSON.parse(ev.data);
      if (msg.id && this.pending.has(msg.id)) {
        const { resolve, reject } = this.pending.get(msg.id);
        this.pending.delete(msg.id);
        msg.error ? reject(new Error(msg.error.message)) : resolve(msg.result);
      } else if (msg.method) {
        for (const fn of this.listeners) fn(msg);
      }
    });
  }
  send(method, params = {}, sessionId) {
    const id = ++this.id;
    return new Promise((resolve, reject) => {
      this.pending.set(id, { resolve, reject });
      this.ws.send(JSON.stringify({ id, method, params, ...(sessionId ? { sessionId } : {}) }));
      setTimeout(() => {
        if (this.pending.has(id)) {
          this.pending.delete(id);
          reject(new Error(`CDP 超时: ${method}`));
        }
      }, 30_000);
    });
  }
  close() {
    this.ws.close();
  }
}

async function evalWaitReady(cdp, sessionId) {
  const deadline = Date.now() + NAV_TIMEOUT_MS;
  while (Date.now() < deadline) {
    const r = await cdp.send(
      "Runtime.evaluate",
      { expression: "window.__DSH_SHOT_READY__ === true", returnByValue: true },
      sessionId,
    );
    if (r?.result?.value === true) return true;
    await sleep(500);
  }
  return false;
}

async function captureOne(cdp, viewport, shot, outDir) {
  const { targetId } = await cdp.send("Target.createTarget", { url: "about:blank" });
  const { sessionId } = await cdp.send("Target.attachToTarget", { targetId, flatten: true });
  await cdp.send("Page.enable", {}, sessionId);
  await cdp.send("Runtime.enable", {}, sessionId);
  await cdp.send(
    "Emulation.setDeviceMetricsOverride",
    { width: viewport.width, height: viewport.height, deviceScaleFactor: viewport.dsf, mobile: viewport.mobile },
    sessionId,
  );
  const url = `http://${HOST}:${PORT}/index.html?shot=${shot}`;
  await cdp.send("Page.navigate", { url }, sessionId);
  const ready = await evalWaitReady(cdp, sessionId);
  if (!ready) throw new Error(`就绪信号超时: ${viewport.tag}/${shot}（引擎未启动或场景脚本报错）`);
  await sleep(SETTLE_MS);
  const shot1 = await cdp.send("Page.captureScreenshot", { format: "png" }, sessionId);
  const file = path.join(outDir, `${viewport.tag}__${shot}.png`);
  await writeFile(file, Buffer.from(shot1.data, "base64"));
  await cdp.send("Target.closeTarget", { targetId });
  console.log(`    ✔ ${path.relative(REPO_ROOT, file)}`);
}

// ---------- 主流程 ----------
const { out } = parseArgs(process.argv);
await mkdir(out, { recursive: true });
await exportWeb();
const server = await startStaticServer();
const { child, wsUrl, profile } = await startChrome();
const cdp = new Cdp(wsUrl);
await cdp.connect();
console.log(`[2/4] Chrome CDP 就绪; [3/4] 采集 ${VIEWPORTS.length} 视口 × ${SHOTS.length} 场景 ...`);
let failed = false;
try {
  for (const viewport of VIEWPORTS) {
    for (const shot of SHOTS) {
      await captureOne(cdp, viewport, shot, out);
    }
  }
} catch (err) {
  failed = true;
  console.error(err.message);
} finally {
  cdp.close();
  child.kill();
  // Chrome 进程可能仍在写 profile，清理失败不致命（/tmp 会系统回收）
  await rm(profile, { recursive: true, force: true }).catch(() => {});
  server.close();
}
if (failed) process.exit(1);
console.log(`[4/4] 截图归档完成: ${path.relative(REPO_ROOT, out)}`);
