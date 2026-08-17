#!/usr/bin/env node
/**
 * 规则中心只读保护。
 * 拦截对 <规则中心>/RULES.md | PROMPT.md | CLAUDE.md | templates/** 的写入。
 * 逃生开关：设环境变量 RULES_UNLOCK=1（改规则本体时用，改完取消）。
 * 失败一律放行（fail open）——宁可漏拦，绝不误伤把会话卡死。
 */
'use strict';
const fs = require('fs');
const path = require('path');

const FILES = ['RULES.md', 'PROMPT.md', 'CLAUDE.md'];
const DIRS = ['templates'];

const pass = () => process.exit(0);

let raw = '';
process.stdin.setEncoding('utf8');
process.stdin.on('data', (c) => { raw += c; });
process.stdin.on('end', () => {
  try {
    if (process.env.RULES_UNLOCK === '1') return pass();

    const input = JSON.parse(raw);
    const target = input && input.tool_input &&
      (input.tool_input.file_path || input.tool_input.notebook_path);
    if (!target) return pass();

    // 插件真实位置 = <规则中心>/wf/hooks，穿透 junction/symlink 求真实路径
    let root;
    try {
      root = path.resolve(fs.realpathSync(__dirname), '..', '..');
    } catch (_) { return pass(); }

    // 确认这真是规则中心（同时有 RULES.md 和 PROMPT.md），否则放行
    if (!fs.existsSync(path.join(root, 'RULES.md')) ||
        !fs.existsSync(path.join(root, 'PROMPT.md'))) return pass();

    let abs;
    try { abs = fs.realpathSync(path.resolve(target)); }
    catch (_) { abs = path.resolve(target); }

    const rel = path.relative(root, abs);
    if (!rel || rel.startsWith('..') || path.isAbsolute(rel)) return pass();

    const parts = rel.split(path.sep);
    const hit = (parts.length === 1 && FILES.includes(parts[0])) || DIRS.includes(parts[0]);
    if (!hit) return pass();

    process.stdout.write(JSON.stringify({
      hookSpecificOutput: {
        hookEventName: 'PreToolUse',
        permissionDecision: 'deny',
        permissionDecisionReason:
          '规则中心只读保护：' + parts.join('/') + ' 是规则本体，禁止直接改写。' +
          '确需修改，请用户先设环境变量 RULES_UNLOCK=1 再重开会话。'
      }
    }));
    pass();
  } catch (_) { pass(); }
});
