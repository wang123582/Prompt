#!/usr/bin/env node
/**
 * statusline 命令：把订阅额度（rate_limits）落盘给 usage-guard.js 读，顺手显示一行用量。
 * hook 拿不到额度数据，只有 statusline 的输入里有，所以由这里当搬运工。
 * 由 install.sh 写进 ~/.claude/settings.json 的 statusLine。
 * 任何异常一律静默（fail open），绝不影响状态栏和会话。
 */
'use strict';
const fs = require('fs');
const os = require('os');
const path = require('path');

const CACHE = path.join(os.homedir(), '.claude', 'wf-usage.json');

const hhmm = (sec) => {
  const d = new Date(sec * 1000);
  return String(d.getHours()).padStart(2, '0') + ':' + String(d.getMinutes()).padStart(2, '0');
};

let raw = '';
process.stdin.on('data', (c) => (raw += c));
process.stdin.on('end', () => {
  try {
    const rl = JSON.parse(raw).rate_limits;
    if (!rl) return;                                   // 非订阅 / 首次响应前没有该字段

    const tmp = CACHE + '.' + process.pid;
    fs.writeFileSync(tmp, JSON.stringify({ ...rl, updated_at: Math.floor(Date.now() / 1000) }));
    fs.renameSync(tmp, CACHE);                         // 原子替换，guard 读不到半截文件

    const seg = [];
    if (rl.five_hour) seg.push(`5h ${Math.round(rl.five_hour.used_percentage)}% ↻${hhmm(rl.five_hour.resets_at)}`);
    if (rl.seven_day) seg.push(`7d ${Math.round(rl.seven_day.used_percentage)}%`);
    process.stdout.write(seg.join(' · '));
  } catch (_) { /* fail open */ }
});
