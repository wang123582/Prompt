#!/usr/bin/env node
/**
 * 规则中心只读保护。
 * 拦截对 <规则中心>/RULES.md | PROMPT.md | CLAUDE.md | templates/** 的写入。
 *
 * 两条通道：
 *   1. Edit / Write / NotebookEdit —— 看 tool_input.file_path，精确判定。
 *   2. Bash —— 看 tool_input.command，**粗匹配启发式**：命令里同时出现
 *      「写意图」和「受保护文件名」，且落点在规则中心，才拦。
 *      故意做不到严密：`python3 某脚本.py` 在脚本内部改 RULES.md 是拦不住的。
 *      它挡的是「agent 顺手 sed -i 一下」，不是有意绕过。
 *
 * 逃生开关：设环境变量 RULES_UNLOCK=1（改规则本体时用，改完取消）。
 * 失败一律放行（fail open）——宁可漏拦，绝不误伤把会话卡死。
 */
'use strict';
const fs = require('fs');
const path = require('path');

const FILES = ['RULES.md', 'PROMPT.md', 'CLAUDE.md'];
const DIRS = ['templates'];

// 写意图：重定向到文件 / 原地改 / 复制搬移删除 / 能任意写文件的解释器
const WRITE_RE = /(>>?\s*[^&\s|>])|\bsed\b[^|;]*\s-i|\b(tee|cp|mv|rm|truncate|dd|patch|install)\b|\b(python3?|node|perl|ruby)\b/;
// 受保护的名字（Bash 命令里按字面找）
const NAME_RE = /\b(RULES\.md|PROMPT\.md|CLAUDE\.md)\b|\btemplates\//;

const pass = () => process.exit(0);

// 写完 stdout 再退出。stdout 是管道时 write 是异步的，
// 紧跟 process.exit() 会把还没冲刷的输出丢掉 —— 那等于这个 hook 静默失效。
const deny = (what, how) => {
  process.exitCode = 0;
  process.stdout.write(JSON.stringify({
    hookSpecificOutput: {
      hookEventName: 'PreToolUse',
      permissionDecision: 'deny',
      permissionDecisionReason:
        '规则中心只读保护：' + what + ' 是规则本体，禁止直接改写（' + how + '）。' +
        '确需修改，请用户先设环境变量 RULES_UNLOCK=1 再重开会话。'
    }
  }));
};

let raw = '';
process.stdin.setEncoding('utf8');
process.stdin.on('data', (c) => { raw += c; });
process.stdin.on('end', () => {
  try {
    if (process.env.RULES_UNLOCK === '1') return pass();

    const input = JSON.parse(raw);
    const ti = (input && input.tool_input) || {};

    // 插件真实位置 = <规则中心>/wf/hooks，穿透 junction/symlink 求真实路径
    let root;
    try {
      root = path.resolve(fs.realpathSync(__dirname), '..', '..');
    } catch (_) { return pass(); }

    // 确认这真是规则中心（同时有 RULES.md 和 PROMPT.md），否则放行
    if (!fs.existsSync(path.join(root, 'RULES.md')) ||
        !fs.existsSync(path.join(root, 'PROMPT.md'))) return pass();

    // 返回 p 相对规则中心的路径；p 不在规则中心里则返回 null（p 就是根时返回 ''）
    const inRoot = (p) => {
      const rel = path.relative(root, p);
      return !rel.startsWith('..') && !path.isAbsolute(rel) ? rel : null;
    };

    // ---------- 通道 1：文件路径类工具 ----------
    const target = ti.file_path || ti.notebook_path;
    if (target) {
      let abs;
      try { abs = fs.realpathSync(path.resolve(target)); }
      catch (_) { abs = path.resolve(target); }

      const rel = inRoot(abs);
      if (!rel) return pass();

      const parts = rel.split(path.sep);
      const hit = (parts.length === 1 && FILES.includes(parts[0])) || DIRS.includes(parts[0]);
      if (!hit) return pass();

      deny(parts.join('/'), input.tool_name || '文件写入');
      return;
    }

    // ---------- 通道 2：Bash ----------
    const cmd = ti.command;
    if (typeof cmd !== 'string' || !cmd) return pass();
    if (!WRITE_RE.test(cmd)) return pass();

    const name = cmd.match(NAME_RE);
    if (!name) return pass();

    // 落点必须在规则中心：命令里写了规则中心绝对路径，或会话 cwd 就在里面
    const cwd = input.cwd || process.cwd();
    if (!cmd.includes(root) && inRoot(path.resolve(cwd)) === null) return pass();

    deny(name[0], 'Bash 命令');
  } catch (_) { pass(); }
});
