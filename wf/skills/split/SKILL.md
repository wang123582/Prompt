---
description: 阶段③ 任务划分。把 design.md 拆成 tasks/<模块>.md 和 tasks/progress.md。
model: sonnet
effort: medium
---

# ③ 任务划分

**输入**：`design.md` → **产出**：每模块一份 `tasks/<模块>.md` + `tasks/progress.md`
**验收**：`progress.md` 列全模块，每个模块都有对应文件。

## 做法

0. 骨架已由 ②design 落在代码根，**不重新生成**；拆任务时对着骨架的签名走，签名缺失的模块回 ②补。
1. 从 `templates/tasks/_模块模板.md` 拷模板，一模块一份。
2. 子任务拆到**最小可验证**粒度，每条都能独立打勾。
   把 `design.md` 该模块下的 `📖学习点` 原样抄进任务文件——④exec 派 agent 前要用。
3. 每个模块的子任务必须包含：实现 → 写 pytest → 实跑 pytest/mypy/ruff → 提醒可提交。
4. 在 `progress.md` 标出**哪些模块互相独立**——阶段④ 的并行完全依赖这个标注。
5. 多个模块要改同一个共享文件（如公共 config）→ 在 `progress.md` 注明「需先串行」。

## 收尾

→ 走 `/wf:wrap`，下一阶段 `/wf:exec`，`建议档位：高`。
