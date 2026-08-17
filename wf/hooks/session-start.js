#!/usr/bin/env node
/**
 * 会话开场注入：找到本项目的 CONTEXT.md，把「目标锚定 + 当前任务 + 建议档位 + 该跑哪个技能」
 * 送进上下文。用户不必手动交代自己在哪一步。
 * 任何异常一律静默退出（fail open），绝不影响会话启动。
 * ⚠️ 本文件不用字符串拼正则，只用正则字面量——字符串里的反斜杠会在写入时被吃掉。
 */
'use strict';
const fs = require('fs');
const path = require('path');

const MAX_UP = 6;   // 在子目录开会话时，向上找 CONTEXT.md 的最大层数

const SKILL_BY_TYPE = [
  [/需求确认|需求/, '/wf:req'],
  [/设计/, '/wf:design'],
  [/任务划分|拆分/, '/wf:split'],
  [/执行|实现|新功能|修复|bug/i, '/wf:exec'],
  [/review|审查|检查/i, '/wf:check'],
];

const clean = (s) =>
  (s || '').replace(/<!--[\s\S]*?-->/g, '').replace(/\*\*/g, '').trim();

// 逐行找标签，取冒号后面的内容。不拼正则，避免转义坑。
function field(text, label) {
  const lines = text.split(/\r?\n/);
  for (let i = 0; i < lines.length; i++) {
    const at = lines[i].indexOf(label);
    if (at < 0) continue;
    const m = lines[i].slice(at + label.length).match(/^[*\s]*[：:]\s*(.*)$/);
    if (m) {
      const v = clean(m[1]);
      if (v) return v;
    }
  }
  return '';
}

// 向上找项目根（含 CONTEXT.md 的那一层）
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

function emit(body) {
  process.stdout.write(JSON.stringify({
    hookSpecificOutput: { hookEventName: 'SessionStart', additionalContext: body }
  }));
  process.exit(0);
}

let raw = '';
process.stdin.setEncoding('utf8');
process.stdin.on('data', (c) => { raw += c; });
process.stdin.on('end', () => {
  try {
    let cwd = process.cwd();
    try { cwd = (JSON.parse(raw) || {}).cwd || cwd; } catch (e) { /* 用 process.cwd() */ }

    const isRulesCenter =
      fs.existsSync(path.join(cwd, 'RULES.md')) &&
      fs.existsSync(path.join(cwd, 'PROMPT.md')) &&
      !fs.existsSync(path.join(cwd, 'CONTEXT.md'));

    if (isRulesCenter) {
      return emit(
        '【wf】当前在规则中心，这里不存任何项目状态。\n' +
        '先按 RULES.md Tier 1 第 2 条问清是哪个项目、代码根在哪，拿到确认再动手。'
      );
    }

    const projRoot = findRoot(cwd);
    if (!projRoot) {
      return emit(
        '【wf】当前目录及其上层都没有 CONTEXT.md，说明本项目还没接入。\n' +
        '▶ 建议先跑 /wf:intake 分诊（全新项目 / 已有代码首次接入 / 一次性任务）。\n' +
        '若只是一次性小问题（看个报错、跑个脚本），不要初始化，直接答完即走。'
      );
    }

    const text = fs.readFileSync(path.join(projRoot, 'CONTEXT.md'), 'utf8');
    const where = (projRoot === cwd) ? '' : '（项目根在 ' + projRoot + '）';

    const big  = field(text, '大目标')       || '（未填）';
    const now  = field(text, '当前阶段目标') || '（未填）';
    const type = field(text, '任务类型');
    const tier = field(text, '建议档位');
    const acc  = field(text, '验收标准');
    const desc = field(text, '任务描述');

    let skill = '';
    for (let i = 0; i < SKILL_BY_TYPE.length; i++) {
      if (SKILL_BY_TYPE[i][0].test(type)) { skill = SKILL_BY_TYPE[i][1]; break; }
    }

    const L = ['【wf】本项目锚定' + where + '（回复开头三句从这里抄）'];
    L.push('· 大目标：' + big);
    L.push('· 当前阶段目标：' + now);

    const bits = [];
    if (type) bits.push('类型=' + type);
    if (tier) bits.push('建议档位=' + tier);
    if (acc)  bits.push('验收=' + acc);
    if (bits.length) L.push('· 当前任务：' + bits.join(' · '));
    if (desc) L.push('  ' + desc);

    if (skill) {
      L.push('▶ 建议先跑：' + skill + '（自动切到对应档位，不必手动 /model）');
      L.push('  同阶段继续可直接调用；跨阶段先让用户 /clear 再进。');
    } else if (!type) {
      L.push('▶ 「当前任务」为空：依据「当前进度」+ tasks/progress.md 判断下一步，判断不了就问用户。');
    }

    if (big === '（未填）' || now === '（未填）') {
      L.push('⚠️ 目标锚定有未填项，开头三句会失真。先问用户补上（一句话即可），' +
             '由我写进 CONTEXT.md —— 不要让用户自己去开文件。');
    }
    emit(L.join('\n'));
  } catch (e) { process.exit(0); }
});
