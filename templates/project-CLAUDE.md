# <项目名> —— 协作工作流接入

> 把本文件拷到**该项目代码根目录**、改名 `CLAUDE.md`（`./CLAUDE.md` 或 `./.claude/CLAUDE.md` 都行）。
> 它会被任何在本项目工作的 agent **自动加载**，从而：自动读到中央规则 + 本项目自己的状态，并守住「不破坏规则」的红线。
> 使用前把所有 `<项目名>` 替换成本项目目录名（与 `/home/toe/prompt/projects/<项目名>/` 一致）。

## 必做：自动加载规则 + 本项目状态
@/home/toe/prompt/PROMPT.md
@/home/toe/prompt/projects/<项目名>/CONTEXT.md

严格按 `PROMPT.md` 的「启动步骤 / 工作模式 / 执行规则」执行。
本项目的 `design.md` / `tasks/` 在 `/home/toe/prompt/projects/<项目名>/`，按需读取。

## 红线：规则只读，状态才可写
- `/home/toe/prompt/PROMPT.md`、`CLAUDE.md`、`templates/` 是**只读规则/模板**，禁止修改（已做系统级保护）。
- **只允许写本项目自己的状态**：`/home/toe/prompt/projects/<项目名>/` 下的 `CONTEXT.md`、`design.md`、`tasks/`、`USAGE.md`。
- **绝不读/写别的项目** `projects/<其它名>/` 的状态，避免串味。
- **代码写在本项目代码根目录**，不写进 `/home/toe/prompt`。
