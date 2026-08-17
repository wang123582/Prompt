#!/usr/bin/env bash
# ============================================================
#  install.sh  --  协作工作流安装器（Ubuntu / Linux）
#
#  两种模式:
#    ./install.sh                          【全局模式】把规则注入 ~/.claude/CLAUDE.md
#                                           装一次，本机任何目录开会话都自动加载规则
#    ./install.sh <代码根目录> [项目名]    【项目模式】给该项目建状态骨架
#                                           CONTEXT.md / design.md / USAGE.md / tasks/
#                                           + 一份只指向 @CONTEXT.md 的薄 CLAUDE.md
#    加 -y 全自动不询问
# ============================================================
set -euo pipefail

PROMPT_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
TPL="$PROMPT_ROOT/templates"
B='<!-- PROMPT-WORKFLOW-START -->'
E='<!-- PROMPT-WORKFLOW-END -->'
PH='<项目名>'

usage() {
  cat <<'USAGE'

  用法:
    ./install.sh                          全局模式：把规则注入 ~/.claude/CLAUDE.md
    ./install.sh <代码根目录> [项目名]    项目模式：给该项目建状态骨架
    ./install.sh <代码根目录> [项目名] -y 全自动，不询问

  规则全局装一次即可；每个新项目再跑一次项目模式。

USAGE
}

die() { echo "[错误] $*" >&2; exit 1; }

# write_block <目标文件> <正文>
# 不存在则新建，已有标记块则替换，否则追加。结果放进全局 WB_RESULT
write_block() {
  local path="$1" body="$2" block tmp
  block="$B
$body
$E"
  if [ ! -e "$path" ]; then
    printf '%s\n' "$block" > "$path"
    WB_RESULT=created
  elif grep -qF -- "$B" "$path"; then
    tmp="$(mktemp)"
    awk -v b="$B" -v e="$E" 'index($0,b){s=1} !s{print} index($0,e){s=0}' "$path" > "$tmp"
    printf '%s\n' "$block" >> "$tmp"
    cat -- "$tmp" > "$path"
    rm -f -- "$tmp"
    WB_RESULT=updated
  else
    printf '\n%s\n' "$block" >> "$path"
    WB_RESULT=appended
  fi
}

AUTO_YES=0
CODE_ROOT=""
PROJ_NAME=""
while [ $# -gt 0 ]; do
  case "$1" in
    -h|--help) usage; exit 0 ;;
    -y|--yes)  AUTO_YES=1 ;;
    *)
      if [ -z "$CODE_ROOT" ]; then CODE_ROOT="$1"
      elif [ -z "$PROJ_NAME" ]; then PROJ_NAME="$1"
      fi ;;
  esac
  shift
done

[ -f "$TPL/project-CLAUDE.md" ] || die "找不到 $TPL/project-CLAUDE.md，请把本脚本放在规则中心根目录再运行。"

# ============================================================
#  全局模式：无参数
# ============================================================
if [ -z "$CODE_ROOT" ]; then
  CLAUDE_DIR="$HOME/.claude"
  TARGET="$CLAUDE_DIR/CLAUDE.md"

  echo "============================================================"
  echo "  全局模式 —— 把规则注入 Claude 全局配置"
  echo "============================================================"
  echo
  echo "  规则中心 : $PROMPT_ROOT"
  echo "  注入到   : $TARGET"
  echo
  echo "  装完后本机任何目录开会话都自动加载 RULES.md。"
  echo "  该文件已有的内容会保留，只在末尾加一段带标记的块。"
  echo
  if [ "$AUTO_YES" != "1" ]; then
    read -r -p "确认注入全局? [Y/n]: " ANS
    case "${ANS:-}" in n|N|no|NO) echo "已取消，未做任何改动。"; exit 0 ;; esac
  fi

  mkdir -p -- "$CLAUDE_DIR"
  write_block "$TARGET" "# 全局协作工作流规则

> 由规则中心的 install 脚本写入。规则本体在规则中心，改那边即刻全局生效。
> 本块由脚本管理，uninstall 时按标记整块撤除；标记外的内容不会被动。

@$PROMPT_ROOT/RULES.md

完整流程手册见 $PROMPT_ROOT/PROMPT.md （流程不确定时按需查阅）。"

  case "$WB_RESULT" in
    created)  echo "  + 已创建: ~/.claude/CLAUDE.md" ;;
    updated)  echo "  ~ 已更新 ~/.claude/CLAUDE.md 中的标记块" ;;
    appended) echo "  ~ 已追加标记块到 ~/.claude/CLAUDE.md，原有内容保留" ;;
  esac

  # ---------- wf 插件：软链到 ~/.claude/skills/wf ----------
  WF_SRC="$PROMPT_ROOT/wf"
  WF_LINK="$CLAUDE_DIR/skills/wf"
  if [ -d "$WF_SRC" ]; then
    mkdir -p "$CLAUDE_DIR/skills"
    if [ -L "$WF_LINK" ]; then
      rm -f "$WF_LINK"                 # 只删软链本身，不碰目标
    elif [ -e "$WF_LINK" ]; then
      echo "  ! ~/.claude/skills/wf 已存在且不是软链，跳过（请手动处理）"
      WF_LINK=""
    fi
    if [ -n "$WF_LINK" ]; then
      if ln -s "$WF_SRC" "$WF_LINK" 2>/dev/null; then
        echo "  + 已链接: ~/.claude/skills/wf  ->  <规则中心>/wf"
        echo "    8 个技能 + 规则中心只读保护 hook 已就位；输 /wf 加 Tab 可见"
      else
        echo "  ! 软链建立失败，回退为复制（以后改 wf/ 需重跑本脚本才生效）"
        cp -R "$WF_SRC" "$WF_LINK"
      fi
    fi
  else
    echo "  ! 规则中心下没有 wf/ 目录，跳过技能安装"
  fi

  echo
  echo "============================================================"
  echo "  全局规则安装完成"
  echo "============================================================"
  echo "  下一步: 给某个项目建状态骨架 ——"
  echo "          ./install.sh /home/you/yourproject"
  echo
  echo "  撤销: ./uninstall.sh （不带参数即撤全局）"
  echo
  exit 0
fi

# ============================================================
#  项目模式：带代码根目录
# ============================================================
[ -d "$CODE_ROOT" ] || die "目录不存在: $CODE_ROOT"
CODE_ROOT="$(cd -- "$CODE_ROOT" && pwd)"
[ "$CODE_ROOT" != "$PROMPT_ROOT" ] || die "不能把状态文件装进规则中心自己。请指定目标项目的代码根目录。"

DEF_NAME="$(basename -- "$CODE_ROOT")"
if [ -z "$PROJ_NAME" ]; then
  if [ "$AUTO_YES" = "1" ]; then
    PROJ_NAME="$DEF_NAME"
  else
    read -r -p "项目名 [$DEF_NAME]: " PROJ_NAME
    [ -n "$PROJ_NAME" ] || PROJ_NAME="$DEF_NAME"
  fi
fi

echo "============================================================"
echo "  项目模式 —— 给项目建状态骨架"
echo "============================================================"
echo
echo "  代码根目录 : $CODE_ROOT"
echo "  项目名     : $PROJ_NAME"
echo
echo "  将写入:"
echo "    CONTEXT.md  design.md  USAGE.md"
echo "    tasks/progress.md  tasks/_模块模板.md"
echo "    CLAUDE.md   已存在则只追加标记块，不覆盖原内容"
echo
if [ "$AUTO_YES" != "1" ]; then
  read -r -p "确认安装? [Y/n]: " ANS
  case "${ANS:-}" in n|N|no|NO) echo "已取消，未做任何改动。"; exit 0 ;; esac
fi
echo

MANIFEST="$CODE_ROOT/.prompt-workflow.manifest"

# 重装会重写 manifest；先继承上次记录的 created 项，
# 否则第二次装完再 uninstall --purge 会因为「文件已存在、本次没创建」而漏删。
OLD_CREATED=""
if [ -f "$MANIFEST" ]; then
  OLD_CREATED="$(grep '^created=' "$MANIFEST" || true)"
fi

{
  echo "# prompt-workflow install manifest -- 供 uninstall 使用，请勿手改"
  echo "prompt_root=$PROMPT_ROOT"
  echo "project=$PROJ_NAME"
  echo "installed_at=$(date '+%Y-%m-%d %H:%M:%S')"
} > "$MANIFEST"
[ -z "$OLD_CREATED" ] || printf '%s\n' "$OLD_CREATED" >> "$MANIFEST"

mkdir -p -- "$CODE_ROOT/tasks"

copy_one() {
  local rel="$1" dst="$CODE_ROOT/$1"
  if [ -e "$dst" ]; then
    echo "  - 已存在，跳过: $rel"
    return 0
  fi
  cp -- "$TPL/$rel" "$dst"
  grep -qxF "created=$rel" "$MANIFEST" || printf 'created=%s\n' "$rel" >> "$MANIFEST"
  echo "  + 已创建: $rel"
}

copy_one "CONTEXT.md"
copy_one "design.md"
copy_one "USAGE.md"
copy_one "tasks/progress.md"
copy_one "tasks/_模块模板.md"

# 薄 CLAUDE.md：模板里已无绝对路径，只需替换项目名
T="$(cat -- "$TPL/project-CLAUDE.md")"
T="${T//$PH/$PROJ_NAME}"
write_block "$CODE_ROOT/CLAUDE.md" "$T"
case "$WB_RESULT" in
  created)  echo "  + 已创建: CLAUDE.md";             echo "claude_md=created"   >> "$MANIFEST" ;;
  updated)  echo "  ~ 已更新 CLAUDE.md 中的标记块";   echo "claude_md=appended" >> "$MANIFEST" ;;
  appended) echo "  ~ 已追加标记块到原有 CLAUDE.md";  echo "claude_md=appended" >> "$MANIFEST" ;;
esac

echo
echo "============================================================"
echo "  项目状态骨架安装完成"
echo "============================================================"
echo "  已接入: $CODE_ROOT"
echo "  规则由全局 ~/.claude/CLAUDE.md 加载；本项目状态由该目录下 CLAUDE.md 指向 CONTEXT.md"
echo
echo "  下一步: 打开 $CODE_ROOT/CONTEXT.md 填「代码根目录」一项即可开工"
echo "  卸载:   ./uninstall.sh \"$CODE_ROOT\""
echo
