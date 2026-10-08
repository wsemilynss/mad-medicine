// 自动同步脚本：监听网页文件改动 → 自动 git 提交并推送 → GitHub Pages 自动重新发布
// 网页端与手机端共用同一网址，推送后两端同时更新（约 1 分钟内生效）
const { execFileSync } = require('child_process');
const fs = require('fs');
const path = require('path');

const ROOT = __dirname;
// 只监听需要发布的文件，临时文件（_shot.html 等）不会被自动提交
const WATCH_FILES = [
  'index.html',
  'design-evolution.html',
  'system-analysis.html',
  'interaction-life-design.html',
  'reference-figures.mp4',
  'README.md',
];
const DEBOUNCE_MS = 5000; // 停止改动 5 秒后才提交，避免连续保存产生大量提交

let timer = null;
let syncing = false;
let again = false;

function git(args) {
  return execFileSync('git', args, { cwd: ROOT, encoding: 'utf8' }).trim();
}

function stamp() {
  return new Date().toLocaleTimeString('zh-CN', { hour12: false });
}

function sync() {
  if (syncing) { again = true; return; }
  syncing = true;
  try {
    git(['add', '--', ...WATCH_FILES]);
    if (!git(['status', '--porcelain', '--', ...WATCH_FILES])) return;
    const msg = 'auto: 自动同步 ' + new Date().toLocaleString('zh-CN', { hour12: false });
    git(['commit', '-m', msg]);
    try {
      git(['push', 'origin', 'main']);
    } catch (e) {
      // 远端若有他人提交，先 rebase 再推一次
      git(['pull', '--rebase', 'origin', 'main']);
      git(['push', 'origin', 'main']);
    }
    console.log(`[${stamp()}] 已发布到 GitHub Pages（网页端 / 手机端约 1 分钟后生效）`);
  } catch (e) {
    console.error(`[${stamp()}] 同步失败：`, e.message);
  } finally {
    syncing = false;
    if (again) { again = false; schedule(); }
  }
}

function schedule() {
  clearTimeout(timer);
  timer = setTimeout(sync, DEBOUNCE_MS);
  console.log(`[${stamp()}] 检测到改动，5 秒后自动提交…`);
}

console.log('正在监听以下文件，保存即自动发布：');
for (const f of WATCH_FILES) {
  const p = path.join(ROOT, f);
  if (!fs.existsSync(p)) continue;
  fs.watch(p, { persistent: true }, schedule);
  console.log('  - ' + f);
}
console.log('\n保持本窗口开启即可；按 Ctrl+C 停止。\n');
sync(); // 启动时若还有未提交的改动，先同步一次
