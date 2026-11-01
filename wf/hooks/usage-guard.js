#!/usr/bin/env node
/**
 * 额度守卫（PostToolUse，全局生效）：额度 ≥ THRESHOLD 时提醒我收尾、后台 sleep 到重置后自动续上。
 * 额度数据来自 usage-cache.js（statusline）落盘的 ~/.claude/wf-usage.json。
 * 同一会话、同一个唤醒点只提醒一次，避免每次工具调用都刷屏。
 * 任何异常一律静默退出（fail open）。
 */
'use strict';
const fs = require('fs');
const os = require('os');
const path = require('path');

const THRESHOLD = 95;      // 用量百分比，到这条线就暂停
const MARGIN = 120;        // 重置后再多等的秒数，防止刚重置时额度还没刷新

const DIR = path.join(os.homedir(), '.claude');
const CACHE = path.join(DIR, 'wf-usage.json');
const NOTIFIED = path.join(DIR, 'wf-usage-notified.json');   // { session_id: wake }

const readJson = (p) => { try { return JSON.parse(fs.readFileSync(p, 'utf8')); } catch (_) { return null; } };
const hhmm = (sec) => {
  const d = new Date(sec * 1000);
  return String(d.getHours()).padStart(2, '0') + ':' + String(d.getMinutes()).padStart(2, '0');
};

let raw = '';
process.stdin.on('data', (c) => (raw += c));
process.stdin.on('end', () => {
  try {
    const sid = (JSON.parse(raw || '{}').session_id) || 'unknown';
    const usage = readJson(CACHE);
    if (!usage) return;

    const now = Math.floor(Date.now() / 1000);
    const over = [['five_hour', '5小时'], ['seven_day', '7天']]
      .map(([k, name]) => ({ name, w: usage[k] }))
      .filter(({ w }) => w && w.resets_at > now && w.used_percentage >= THRESHOLD);
    if (!over.length) return;

    const wake = Math.max(...over.map(({ w }) => w.resets_at)) + MARGIN;

    const notified = readJson(NOTIFIED) || {};
    if (notified[sid] === wake) return;               // 这一轮已经提醒过
    for (const k of Object.keys(notified)) if (notified[k] < now) delete notified[k];   // 清掉过期记录
    notified[sid] = wake;
    fs.writeFileSync(NOTIFIED, JSON.stringify(notified));

    const what = over.map(({ name, w }) => `${name}额度 ${Math.round(w.used_percentage)}%`).join('，');
    process.stdout.write(JSON.stringify({
      systemMessage: `⏸ ${what}，暂停到 ${hhmm(wake)} 后自动续上`,
      hookSpecificOutput: {
        hookEventName: 'PostToolUse',
        additionalContext:
          `【wf 额度守卫】${what}（≥${THRESHOLD}%），${hhmm(wake)} 可恢复。\n` +
          `- 手头有未完成的任务：先收尾到可断开的状态（正在写的文件写完整、更新 tasks/progress.md），` +
          `然后用 Bash 的 run_in_background 执行 \`sleep $(( ${wake} - $(date +%s) ))\`，接着结束本轮。` +
          `后台 sleep 结束会唤醒你，醒来后从断开处继续。\n` +
          `- 手头没有未完成的任务、只是在等用户：不要 sleep，告诉用户额度情况后直接结束。`,
      },
    }));
  } catch (_) { /* fail open */ }
});
