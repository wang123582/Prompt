#!/usr/bin/env bash
# ============================================================
#  uninstall.sh  --  协作工作流卸载器（Ubuntu / Linux）
#
#  两种模式:
#    ./uninstall.sh                        【全局模式】撤掉 ~/.claude/CLAUDE.md 里的标记块
#    ./uninstall.sh <代码根目录>           【项目模式】撤该项目的标记块，状态文件保留
#    ./uninstall.sh <代码根目录> --purge   连同本脚本装过的状态文件一起删
#    加 -y 全自动不询问
# ============================================================
set -euo pipefail

PROMPT_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
B='<!-- PROMPT-WORKFLOW-START -->'
E='<!-- PROMPT-WORKFLOW-END -->'

usage() {
  cat <<'USAGE'

  用法:
    ./uninstall.sh                        全局模式：撤 ~/.claude/CLAUDE.md 里的标记块
    ./uninstall.sh <代码根目录>           项目模式：撤该项目标记块，状态文件保留
    ./uninstall.sh <代码根目录> --purge   连状态文件一起删
    加 -y 全自动，不询问

USAGE
}

die() { echo "[错误] $*" >&2; exit 1; }

# strip_block <目标文件> -> SB_RESULT = nofile / nomark / deleted / stripped
strip_block() {
  local path="$1" tmp
  if [ ! -e "$path" ]; then SB_RESULT=nofile; return 0; fi
  if ! grep -qF -- "$B" "$path"; then SB_RESULT=nomark; return 0; fi
  tmp="$(mktemp)"
  awk -v b="$B" -v e="$E" 'index($0,b){s=1} !s{print} index($0,e){s=0}' "$path" > "$tmp"
  if [ -z "$(tr -d '[:space:]' < "$tmp")" ]; then
    rm -f -- "$path" "$tmp"
    SB_RESULT=deleted
  else
    cat -- "$tmp" > "$path"
    rm -f -- "$tmp"
    SB_RESULT=stripped
  fi
}

AUTO_YES=0
PURGE=0
CODE_ROOT=""
while [ $# -gt 0 ]; do
  case "$1" in
    -h|--help)  usage; exit 0 ;;
    -y|--yes)   AUTO_YES=1 ;;
    --purge)    PURGE=1 ;;
    *) [ -n "$CODE_ROOT" ] || CODE_ROOT="$1" ;;
  esac
  shift
done

# ============================================================
#  全局模式：无参数
# ============================================================
if [ -z "$CODE_ROOT" ]; then
  TARGET="$HOME/.claude/CLAUDE.md"

  echo "============================================================"
  echo "  全局模式 —— 撤掉 Claude 全局配置里的规则块"
  echo "============================================================"
  echo
  echo "  目标: $TARGET"
  echo "  只删标记块，你自己写在该文件里的其它内容原样保留。"
  echo "  各项目的状态文件不受影响。"
  echo
  if [ "$AUTO_YES" != "1" ]; then
    read -r -p "确认撤销全局规则? [Y/n]: " ANS
    case "${ANS:-}" in n|N|no|NO) echo "已取消，未做任何改动。"; exit 0 ;; esac
  fi
  echo

  strip_block "$TARGET"
  case "$SB_RESULT" in
    nofile)   echo "  ! 没有 ~/.claude/CLAUDE.md，跳过" ;;
    nomark)   echo "  ! 该文件里没有标记块，未改动" ;;
    deleted)  echo "  - 已删除: ~/.claude/CLAUDE.md   整份都是本脚本生成的" ;;
    stripped) echo "  - 已移除标记块，原有内容保留" ;;
  esac

  # ---------- 撤掉 wf 插件链接 ----------
  WF_LINK="$HOME/.claude/skills/wf"
  if [ -L "$WF_LINK" ]; then
    rm -f "$WF_LINK"                   # 只删软链，规则中心的 wf/ 原样保留
    echo "  - 已移除链接: ~/.claude/skills/wf"
  elif [ -d "$WF_LINK" ]; then
    rm -rf "$WF_LINK"
    echo "  - 已删除复制版: ~/.claude/skills/wf"
  else
    echo "  ! 没有 ~/.claude/skills/wf，跳过"
  fi

  echo
  echo "============================================================"
  echo "  全局规则已撤销"
  echo "============================================================"
  echo "  各项目目录里的 CLAUDE.md / CONTEXT.md 仍在。"
  echo "  要撤某个项目: ./uninstall.sh /home/you/yourproject"
  echo
  exit 0
fi

# ============================================================
#  项目模式：带代码根目录
# ============================================================
[ -d "$CODE_ROOT" ] || die "目录不存在: $CODE_ROOT"
CODE_ROOT="$(cd -- "$CODE_ROOT" && pwd)"
[ "$CODE_ROOT" != "$PROMPT_ROOT" ] || die "目标是规则中心自己，拒绝执行。"

MANIFEST="$CODE_ROOT/.prompt-workflow.manifest"
HAS_MANIFEST=0
[ ! -f "$MANIFEST" ] || HAS_MANIFEST=1

echo "============================================================"
echo "  项目模式 —— 撤掉项目的工作流接入"
echo "============================================================"
echo
if [ "$HAS_MANIFEST" = "0" ]; then
  echo "  提示: 未找到安装记录 .prompt-workflow.manifest"
  echo "        只能按标记块撤 CLAUDE.md，状态文件请自行处理。"
fi
echo "  目标: $CODE_ROOT"
echo
if [ "$AUTO_YES" != "1" ]; then
  read -r -p "确认卸载? [Y/n]: " ANS
  case "${ANS:-}" in n|N|no|NO) echo "已取消，未做任何改动。"; exit 0 ;; esac
  if [ "$PURGE" != "1" ] && [ "$HAS_MANIFEST" = "1" ]; then
    echo
    echo "  状态文件 CONTEXT.md / design.md / USAGE.md / tasks 里可能有你的项目进度。"
    echo "  删了不可恢复，也不做备份。"
    read -r -p "一并删除本脚本装过的状态文件? [y/N]: " ANS2
    case "${ANS2:-}" in y|Y|yes|YES) PURGE=1 ;; esac
  fi
fi
echo

strip_block "$CODE_ROOT/CLAUDE.md"
case "$SB_RESULT" in
  nofile)   echo "  ! 没有 CLAUDE.md，跳过" ;;
  nomark)   echo "  ! CLAUDE.md 里没有标记块，未改动" ;;
  deleted)  echo "  - 已删除: CLAUDE.md   整份都是本脚本生成的" ;;
  stripped) echo "  - 已移除 CLAUDE.md 中的标记块，原有内容保留" ;;
esac

if [ "$PURGE" = "1" ] && [ "$HAS_MANIFEST" = "1" ]; then
  while IFS= read -r line || [ -n "$line" ]; do
    case "$line" in
      created=*)
        rel="${line#created=}"
        [ -n "$rel" ] || continue
        # manifest 可能是另一平台写的，反斜杠也认
        rel="${rel//\\//}"
        if [ -e "$CODE_ROOT/$rel" ]; then
          rm -f -- "$CODE_ROOT/$rel"
          echo "  - 已删除: $rel"
        fi ;;
    esac
  done < "$MANIFEST"
  if [ -d "$CODE_ROOT/tasks" ] && [ -z "$(ls -A -- "$CODE_ROOT/tasks")" ]; then
    rmdir -- "$CODE_ROOT/tasks"
    echo "  - 已删除: tasks"
  fi
fi

[ "$HAS_MANIFEST" = "0" ] || rm -f -- "$MANIFEST"

echo
echo "============================================================"
echo "  项目卸载完成"
echo "============================================================"
if [ "$PURGE" != "1" ]; then
  echo "  状态文件已保留: CONTEXT.md  design.md  USAGE.md  tasks/"
  echo "  要一并删除，重跑并加 --purge"
fi
echo "  全局规则仍在，撤它: ./uninstall.sh （不带参数）"
echo
