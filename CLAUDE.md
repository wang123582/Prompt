# /home/toe/prompt —— 规则与模板中心（只读）

> 本文件夹是**给 agent 的规则和模板**，不是工作区，也不存任何单个项目的状态。
> 在这里开会话时，先读 `PROMPT.md` 再行动。

## 目录结构
```
PROMPT.md            # 运行手册 = 规则本体（只读）
CLAUDE.md            # 本文件（只读）
templates/           # 新项目用的空骨架（只读）
  project-CLAUDE.md  #   拷到代码根、改名 CLAUDE.md
  CONTEXT.md  design.md  USAGE.md  tasks/
projects/<项目名>/    # 各项目自己的状态（可写）：CONTEXT/design/USAGE/tasks
```

## 红线（已加系统级保护，hook 会硬拒）
- `PROMPT.md`、`CLAUDE.md`、`templates/`：**只读、照做**，不得重写/精简/挪动。
- **唯一可写的是** `projects/<项目名>/` 下的状态文件，且**每个 agent 只动自己项目那一份**，绝不跨项目。
- **代码不写进本文件夹**，写到各项目自己的代码根目录。

## 接入新代码项目（详见 `PROMPT.md`「已有项目接入」第 0 步）
1. 在 `projects/` 下建 `projects/<项目名>/`，从 `templates/` 拷入 `CONTEXT.md`/`design.md`/`USAGE.md`/`tasks/`。
2. 把 `templates/project-CLAUDE.md` 拷到该项目**代码根目录**、改名 `CLAUDE.md`，替换其中 `<项目名>`。
3. 之后任何 agent 进入该代码目录都会自动加载中央规则 + 本项目状态。
