# 规则与模板中心（只读）

> 本文件夹是**给 agent 的规则、技能和模板**，不是工作区，不存任何单个项目的状态。
> **规则本体在 `RULES.md`**（全局自动加载）。**流程细节在 `wf/skills/`**（用到才加载）。
> **本文件不重复规则**——重复就是冲突源。

## 目录结构

```
RULES.md             # 唯一常驻规则：Tier0 回复格式 + 档位 + Tier1 防灾 + Tier2 连续性 + 停点
PROMPT.md            # 流程地图（只有全景，没有可执行细节）
CLAUDE.md            # 本文件：规则中心的指路牌
templates/           # 新项目空骨架 → 拷到项目代码根
  project-CLAUDE.md  CONTEXT.md  design.md  USAGE.md  tasks/
wf/                  # ★ 工作流插件，junction 到 ~/.claude/skills/wf
  .claude-plugin/plugin.json
  hooks/hooks.json
  hooks/session-start.js                 # 开场注入：目标锚定 + 当前任务 + 该跑哪个技能
  hooks/guard-rules.js                   # 规则中心只读保护（PreToolUse 硬拒）
  skills/{intake,req,design,split,exec,check,wrap,night}/SKILL.md
install.ps1|sh|bat   # 全局注入规则 + 建 junction + 给项目建状态骨架
uninstall.ps1|sh|bat # 撤除
```

⚠️ **状态文件不在本文件夹。** 每个项目的 `CONTEXT.md` / `design.md` / `USAGE.md` / `tasks/` 都在**该项目自己的代码根目录**下，随项目一起移动。

## 红线（`wf` 插件的 PreToolUse hook 会硬拒，不是靠自觉）

- `RULES.md`、`PROMPT.md`、`CLAUDE.md`、`templates/`：**写入被 hook 拦截**。
  确需修改 → 设环境变量 `RULES_UNLOCK=1` 再重开会话，改完取消。
- `wf/skills/*` **不在保护范围**，随时可改，改完即刻生效（改 `wf/hooks/` 需 `/reload-plugins`）。
- **可写的是各项目代码根下的状态文件**，且只动当前项目那一份，绝不跨项目读写。
- **代码不写进本文件夹。**

## 安装

```
install.bat                            # 全局模式：注入 ~/.claude/CLAUDE.md + 建 wf 插件 junction
install.bat <代码根目录> [项目名]        # 项目模式：给该项目建状态骨架
```

全局模式做两件事：
1. 往 `~/.claude/CLAUDE.md` 写一段指向本目录 `RULES.md` 的引用（改规则中心即刻全局生效）。
2. 在 `~/.claude/skills/wf` 建 junction（Windows）/ symlink（mac、Linux）指向本目录的 `wf/`——**只有一个链接，插件自带 hooks，不碰 `~/.claude/settings.json`**。

装完在任意项目里输 `/wf` + Tab 可见 8 个技能。

## 在本文件夹直接开会话时

这里没有项目状态。先按 `RULES.md` Tier 1 第 2 条问清是哪个项目、代码根在哪，拿到确认再走。
