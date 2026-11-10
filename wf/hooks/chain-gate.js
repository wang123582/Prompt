#!/usr/bin/env node
/**
 * 链路图闸门（PreToolUse）：项目里还没有「用户确认过的链路图」，就不许写代码文件。
 * 见 RULES.md「工作顺序」第 3 层：我先画链路图 → 问他对不对 → 他说可以，
 * 我在 design.md 链路图小节写一行 `链路图确认：<日期> 「他的原话」`，这里见到才放行。
 *
 * 只管 Edit / Write / NotebookEdit 的代码文件；文档、配置一律放行（不然连画图都画不了）。
 * Bash 写文件不拦——写法太多，猜不准，误伤代价大。
 * 不拦：没有 CONTEXT.md 的目录（没进流水线）、规则中心本身。
 * 逃生开关：环境变量 CHAIN_GATE_OFF=1。任何异常一律放行（fail open）。
 * ⚠️ 本文件不用字符串拼正则，只用正则字面量。
 */
'use strict';
const fs = require('fs');
const path = require('path');

const MAX_UP = 8;   // 从目标文件向上找 CONTEXT.md 的最大层数
const CODE_RE = /\.(py|pyi|ipynb|js|mjs|cjs|ts|tsx|jsx|c|cc|cpp|cxx|h|hpp|rs|go|java|kt|sh)$/i;

const pass = () => process.exit(0);

// 写完 stdout 再退出，否则管道里的输出会被丢掉（同 guard-rules.js）
const deny = (reason) => {
  process.exitCode = 0;
  process.stdout.write(JSON.stringify({
    hookSpecificOutput: {
      hookEventName: 'PreToolUse',
      permissionDecision: 'deny',
      permissionDecisionReason: reason
    }
  }));
};

function findRoot(start) {
  let d = start;
  for (let i = 0; i < MAX_UP; i++) {
    if (fs.existsSync(path.join(d, 'CONTEXT.md'))) return d;
    const up = path.dirname(d);
    if (up === d) break;
    d = up;
  }
  return null;
}

// 取 design.md 里「链路图」小节的正文（到下一个同级或更高级标题为止），去掉 HTML 注释
function chainSection(text) {
  const lines = text.replace(/<!--[\s\S]*?-->/g, '').split(/\r?\n/);
  let level = 0;
  const out = [];
  for (const line of lines) {
    const h = line.match(/^(#{1,6})\s/);
    if (level) {
      if (h && h[1].length <= level) break;
      out.push(line);
    } else if (h && /链路图/.test(line)) {
      level = h[1].length;
    }
  }
  return level ? out.join('\n') : null;
}

// 小节里第一个代码块有没有非空内容
function hasDiagram(sec) {
  const m = sec.match(/```[^\n]*\n([\s\S]*?)```/);
  return !!(m && m[1].trim());
}

const hasConfirm = (sec) => /链路图确认[*\s]*[：:][*\s]*\S/.test(sec);

let raw = '';
process.stdin.setEncoding('utf8');
process.stdin.on('data', (c) => { raw += c; });
process.stdin.on('end', () => {
  try {
    if (process.env.CHAIN_GATE_OFF === '1') return pass();

    const input = JSON.parse(raw);
    const ti = (input && input.tool_input) || {};
    const target = ti.file_path || ti.notebook_path;
    if (!target || !CODE_RE.test(target)) return pass();

    const abs = path.resolve(input.cwd || process.cwd(), target);
    const root = findRoot(path.dirname(abs));
    if (!root) return pass();
    // 规则中心不是项目
    if (fs.existsSync(path.join(root, 'RULES.md')) &&
        fs.existsSync(path.join(root, 'PROMPT.md'))) return pass();

    const designPath = path.join(root, 'design.md');
    const text = fs.existsSync(designPath) ? fs.readFileSync(designPath, 'utf8') : '';
    const sec = chainSection(text);

    if (sec !== null && hasDiagram(sec) && hasConfirm(sec)) return pass();

    const missing = !sec || !hasDiagram(sec)
      ? '还没有链路图'
      : '链路图还没经用户确认';
    deny(
      '链路图闸门：' + missing + '，不许写代码（' + path.relative(root, abs) + '）。\n' +
      '按 RULES.md「工作顺序」：先在 ' + designPath + ' 的「链路图」小节画出' +
      '从输入到输出的每一步、箭头上写数据，拿真样本走一遍，然后直接画给用户看、问他对不对。\n' +
      '他明确说可以 → 在小节里写一行 `链路图确认：<日期> 「他的原话」`，再写代码。\n' +
      '他没点头之前不许自己写这一行。'
    );
  } catch (_) { pass(); }
});
