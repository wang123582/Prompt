# 运行手册 (PROMPT.md) —— 流程地图

> **只读。这里只有地图，没有可执行细节**——细节全在 `wf` 插件的技能里，用到才加载。
> 规则本体在 `RULES.md`（全局自动加载）。本文件不重复规则，也不重复技能内容。

---

## 全景

```
用户来活
   ↓
/wf:intake ── 分诊 ──┬─ ③ 一次性任务 → 干完即走，不初始化、不进流水线
                     └─ ①② → 初始化 → 进流水线
   ↓
① /wf:req     需求确认   中档   → design.md 第一章
② /wf:design  详细设计   高档   → design.md 第二章 + 第四章 ADR
③ /wf:split   任务划分   中档   → tasks/<模块>.md + tasks/progress.md
④ /wf:exec    执行       高档   → 代码 + 测试（主 agent 派生并行子 agent）
⑤ /wf:check   Review     高档   → 审查 + 修复
   ↓
/wf:wrap ── 每个阶段 / 模块做完都走一遍：
            多余物检测 → 更新文档 → 写下轮「当前任务」→ 提醒 git
```

`/wf:night` 夜间模式：无人值守连续推进，**只能用户手动开启**。

---

## 规则和状态分家

| 东西 | 在哪 | 可写？ |
|---|---|---|
| 规则 `RULES.md` | 规则中心 | ❌ hook 硬拒 |
| 流程 `PROMPT.md`（本文件）、`CLAUDE.md`、`templates/` | 规则中心 | ❌ hook 硬拒 |
| 技能 `wf/skills/*` | 规则中心，junction 到 `~/.claude/skills/wf` | ✅ 改完即刻生效 |
| 状态 `CONTEXT.md` `design.md` `USAGE.md` `tasks/` | **各项目自己的代码根** | ✅ 只动当前项目那一份 |
| 代码 | 各项目自己的代码根 | ✅ |

⚠️ 状态和代码**都不写进规则中心**。**绝不跨项目**读写状态——这是本系统出过的真实事故。

---

## 一个阶段一个会话

每阶段做完 `/clear` 再进下一阶段——上一阶段的探索过程对下一阶段是噪音。
档位由技能 frontmatter 自动切，**用户不用手动 `/model`**。该 `/clear` 时我会在调度行提醒。

## 章节互不删

① 阶段只写 `design.md` 第一章，② 阶段只写第二章和第四章，**禁止删除对方章节内容**。

---

## 想改规则本体时

`RULES.md` / `PROMPT.md` / `CLAUDE.md` / `templates/` 被 `wf` 插件的 `PreToolUse` hook 硬拒。
确需修改：**设环境变量 `RULES_UNLOCK=1` 再重开会话**，改完取消。

`wf/skills/*` 不在保护范围，随时可改，改完即刻生效（改 `wf/hooks/` 需 `/reload-plugins`）。
