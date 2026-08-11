# ============================================================
#  uninstall.ps1  --  协作工作流卸载器（Windows）
#  由 uninstall.bat 调用
#
#  两种模式:
#    uninstall.bat                        【全局模式】撤掉 ~/.claude/CLAUDE.md 里的标记块
#    uninstall.bat <代码根目录>           【项目模式】撤该项目的标记块，状态文件保留
#    uninstall.bat <代码根目录> /purge    连同本脚本装过的状态文件一起删
#    加 /y 全自动不询问
# ============================================================
$ErrorActionPreference = 'Stop'

$PromptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$MarkStart  = '<!-- PROMPT-WORKFLOW-START -->'
$MarkEnd    = '<!-- PROMPT-WORKFLOW-END -->'
$Utf8       = New-Object System.Text.UTF8Encoding($false)
$NL         = [Environment]::NewLine

function Show-Usage {
    Write-Host ''
    Write-Host '  用法:'
    Write-Host '    uninstall.bat                          全局模式：撤 ~/.claude/CLAUDE.md 里的标记块'
    Write-Host '    uninstall.bat <代码根目录>             项目模式：撤该项目标记块，状态文件保留'
    Write-Host '    uninstall.bat <代码根目录> /purge      连状态文件一起删'
    Write-Host '    加 /y 全自动，不询问'
    Write-Host ''
}

function Fail([string]$msg) {
    Write-Host ('[错误] ' + $msg) -ForegroundColor Red
    exit 1
}

# 撤掉标记块。返回 deleted / stripped / nomark / nofile
function Strip-Block([string]$path) {
    if (-not (Test-Path -LiteralPath $path)) { return 'nofile' }
    $s = [System.IO.File]::ReadAllText($path, [System.Text.Encoding]::UTF8)
    $i = $s.IndexOf($MarkStart); $j = $s.IndexOf($MarkEnd)
    if ($i -lt 0 -or $j -le $i) { return 'nomark' }
    $new = ($s.Substring(0, $i) + $s.Substring($j + $MarkEnd.Length)).Trim()
    if ($new.Length -eq 0) {
        Remove-Item -LiteralPath $path -Force
        return 'deleted'
    }
    [System.IO.File]::WriteAllText($path, $new + $NL, $Utf8)
    return 'stripped'
}

# ---------- 解析参数 ----------
$auto = $false; $purge = $false; $codeRoot = $null
foreach ($a in $args) {
    if ($a -match '^(/y|-y|--yes)$')        { $auto = $true }
    elseif ($a -match '^(/purge|--purge)$') { $purge = $true }
    elseif ($a -match '^(/\?|-h|--help)$')  { Show-Usage; exit 0 }
    elseif (-not $codeRoot)                 { $codeRoot = $a }
}

# ============================================================
#  全局模式：无参数
# ============================================================
if (-not $codeRoot) {
    $target = Join-Path (Join-Path $env:USERPROFILE '.claude') 'CLAUDE.md'

    Write-Host '============================================================'
    Write-Host '  全局模式 —— 撤掉 Claude 全局配置里的规则块'
    Write-Host '============================================================'
    Write-Host ''
    Write-Host ('  目标: ' + $target)
    Write-Host '  只删标记块，你自己写在该文件里的其它内容原样保留。'
    Write-Host '  各项目的状态文件不受影响。'
    Write-Host ''
    if (-not $auto) {
        $ans = Read-Host '确认撤销全局规则? [Y/n]'
        if ($ans -match '^(n|no)$') { Write-Host '已取消，未做任何改动。'; exit 0 }
    }
    Write-Host ''

    $r = Strip-Block $target
    if ($r -eq 'nofile')   { Write-Host '  ! 没有 ~/.claude/CLAUDE.md，跳过' }
    if ($r -eq 'nomark')   { Write-Host '  ! 该文件里没有标记块，未改动' }
    if ($r -eq 'deleted')  { Write-Host '  - 已删除: ~/.claude/CLAUDE.md   整份都是本脚本生成的' }
    if ($r -eq 'stripped') { Write-Host '  - 已移除标记块，原有内容保留' }

    Write-Host ''
    Write-Host '============================================================'
    Write-Host '  全局规则已撤销'
    Write-Host '============================================================'
    Write-Host '  各项目目录里的 CLAUDE.md / CONTEXT.md 仍在。'
    Write-Host '  要撤某个项目: uninstall.bat D:\你的项目路径'
    Write-Host ''
    exit 0
}

# ============================================================
#  项目模式：带代码根目录
# ============================================================
$codeRoot = $codeRoot.Trim().Trim('"')
if (-not (Test-Path -LiteralPath $codeRoot -PathType Container)) { Fail ('目录不存在: ' + $codeRoot) }
$codeRoot = (Resolve-Path -LiteralPath $codeRoot).ProviderPath.TrimEnd('\')
if ($codeRoot -eq $PromptRoot) { Fail '目标是规则中心自己，拒绝执行。' }

$manifest    = Join-Path $codeRoot '.prompt-workflow.manifest'
$hasManifest = Test-Path -LiteralPath $manifest

Write-Host '============================================================'
Write-Host '  项目模式 —— 撤掉项目的工作流接入'
Write-Host '============================================================'
Write-Host ''
if (-not $hasManifest) {
    Write-Host '  提示: 未找到安装记录 .prompt-workflow.manifest'
    Write-Host '        只能按标记块撤 CLAUDE.md，状态文件请自行处理。'
}
Write-Host ('  目标: ' + $codeRoot)
Write-Host ''
if (-not $auto) {
    $ans = Read-Host '确认卸载? [Y/n]'
    if ($ans -match '^(n|no)$') { Write-Host '已取消，未做任何改动。'; exit 0 }
    if ((-not $purge) -and $hasManifest) {
        Write-Host ''
        Write-Host '  状态文件 CONTEXT.md / design.md / USAGE.md / tasks 里可能有你的项目进度。'
        Write-Host '  删了不可恢复，也不做备份。'
        $ans2 = Read-Host '一并删除本脚本装过的状态文件? [y/N]'
        if ($ans2 -match '^(y|yes)$') { $purge = $true }
    }
}
Write-Host ''

$r = Strip-Block (Join-Path $codeRoot 'CLAUDE.md')
if ($r -eq 'nofile')   { Write-Host '  ! 没有 CLAUDE.md，跳过' }
if ($r -eq 'nomark')   { Write-Host '  ! CLAUDE.md 里没有标记块，未改动' }
if ($r -eq 'deleted')  { Write-Host '  - 已删除: CLAUDE.md   整份都是本脚本生成的' }
if ($r -eq 'stripped') { Write-Host '  - 已移除 CLAUDE.md 中的标记块，原有内容保留' }

if ($purge -and $hasManifest) {
    foreach ($line in [System.IO.File]::ReadAllLines($manifest, [System.Text.Encoding]::UTF8)) {
        if (-not $line.StartsWith('created=')) { continue }
        $rel = $line.Substring(8).Trim()
        if (-not $rel) { continue }
        # manifest 可能是另一平台写的，两种分隔符都认
        $p = Join-Path $codeRoot ($rel.Replace('/', '\'))
        if (Test-Path -LiteralPath $p) {
            Remove-Item -LiteralPath $p -Force
            Write-Host ('  - 已删除: ' + $rel)
        }
    }
    $tasksDir = Join-Path $codeRoot 'tasks'
    if ((Test-Path -LiteralPath $tasksDir) -and -not (Get-ChildItem -LiteralPath $tasksDir -Force)) {
        Remove-Item -LiteralPath $tasksDir -Force
        Write-Host '  - 已删除: tasks'
    }
}

if ($hasManifest) { Remove-Item -LiteralPath $manifest -Force }

Write-Host ''
Write-Host '============================================================'
Write-Host '  项目卸载完成'
Write-Host '============================================================'
if (-not $purge) {
    Write-Host '  状态文件已保留: CONTEXT.md  design.md  USAGE.md  tasks\'
    Write-Host '  要一并删除，重跑并加 /purge'
}
Write-Host '  全局规则仍在，撤它: uninstall.bat （不带参数）'
Write-Host ''
exit 0
