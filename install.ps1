# ============================================================
#  install.ps1  --  协作工作流安装器（Windows）
#  由 install.bat 调用；也可直接 powershell -File install.ps1
#
#  两种模式:
#    install.bat                          【全局模式】把规则注入 ~/.claude/CLAUDE.md
#                                          装一次，本机任何目录开会话都自动加载规则
#    install.bat <代码根目录> [项目名]    【项目模式】给该项目建状态骨架
#                                          CONTEXT.md / design.md / USAGE.md / tasks/
#                                          + 一份只指向 @CONTEXT.md 的薄 CLAUDE.md
#    加 /y 全自动不询问；把项目文件夹拖到 install.bat 上即为项目模式
# ============================================================
$ErrorActionPreference = 'Stop'

$PromptRoot  = Split-Path -Parent $MyInvocation.MyCommand.Path
$Tpl         = Join-Path $PromptRoot 'templates'
$MarkStart   = '<!-- PROMPT-WORKFLOW-START -->'
$MarkEnd     = '<!-- PROMPT-WORKFLOW-END -->'
$Placeholder = '<项目名>'
$Utf8        = New-Object System.Text.UTF8Encoding($false)
$NL          = [Environment]::NewLine

function Show-Usage {
    Write-Host ''
    Write-Host '  用法:'
    Write-Host '    install.bat                            全局模式：把规则注入 ~/.claude/CLAUDE.md'
    Write-Host '    install.bat <代码根目录> [项目名]      项目模式：给该项目建状态骨架'
    Write-Host '    install.bat <代码根目录> [项目名] /y   全自动，不询问'
    Write-Host ''
    Write-Host '  规则全局装一次即可；每个新项目再跑一次项目模式。'
    Write-Host ''
}

function Fail([string]$msg) {
    Write-Host ('[错误] ' + $msg) -ForegroundColor Red
    exit 1
}

# 把带标记块的内容写进目标 md：不存在则新建，已有标记块则替换，否则追加。
# 返回 created / updated / appended
function Write-Block([string]$path, [string]$body) {
    $block = $MarkStart + $NL + $body.Trim() + $NL + $MarkEnd + $NL
    if (-not (Test-Path -LiteralPath $path)) {
        [System.IO.File]::WriteAllText($path, $block, $Utf8)
        return 'created'
    }
    $old = [System.IO.File]::ReadAllText($path, [System.Text.Encoding]::UTF8)
    $i = $old.IndexOf($MarkStart); $j = $old.IndexOf($MarkEnd)
    if ($i -ge 0 -and $j -gt $i) {
        $new = $old.Substring(0, $i) + $block + $old.Substring($j + $MarkEnd.Length).TrimStart()
        [System.IO.File]::WriteAllText($path, $new, $Utf8)
        return 'updated'
    }
    [System.IO.File]::WriteAllText($path, $old.TrimEnd() + $NL + $NL + $block, $Utf8)
    return 'appended'
}

# ---------- 解析参数 ----------
$auto = $false; $codeRoot = $null; $projName = $null
foreach ($a in $args) {
    if ($a -match '^(/y|-y|--yes)$')        { $auto = $true }
    elseif ($a -match '^(/\?|-h|--help)$')  { Show-Usage; exit 0 }
    elseif (-not $codeRoot)                 { $codeRoot = $a }
    elseif (-not $projName)                 { $projName = $a }
}

if (-not (Test-Path -LiteralPath (Join-Path $Tpl 'project-CLAUDE.md'))) {
    Fail ('找不到 ' + $Tpl + '\project-CLAUDE.md，请把本脚本放在规则中心根目录再运行。')
}

# ============================================================
#  全局模式：无参数
# ============================================================
if (-not $codeRoot) {
    $claudeDir = Join-Path $env:USERPROFILE '.claude'
    $target    = Join-Path $claudeDir 'CLAUDE.md'
    $pr        = $PromptRoot.Replace('\', '/')

    Write-Host '============================================================'
    Write-Host '  全局模式 —— 把规则注入 Claude 全局配置'
    Write-Host '============================================================'
    Write-Host ''
    Write-Host ('  规则中心 : ' + $PromptRoot)
    Write-Host ('  注入到   : ' + $target)
    Write-Host ''
    Write-Host '  装完后本机任何目录开会话都自动加载 RULES.md。'
    Write-Host '  该文件已有的内容会保留，只在末尾加一段带标记的块。'
    Write-Host ''
    if (-not $auto) {
        $ans = Read-Host '确认注入全局? [Y/n]'
        if ($ans -match '^(n|no)$') { Write-Host '已取消，未做任何改动。'; exit 0 }
    }

    if (-not (Test-Path -LiteralPath $claudeDir)) {
        New-Item -ItemType Directory -Path $claudeDir | Out-Null
    }
    $body = @(
        '# 全局协作工作流规则',
        '',
        '> 由规则中心的 install 脚本写入。规则本体在规则中心，改那边即刻全局生效。',
        '> 本块由脚本管理，uninstall 时按标记整块撤除；标记外的内容不会被动。',
        '',
        ('@' + $pr + '/RULES.md'),
        '',
        ('完整流程手册见 ' + $pr + '/PROMPT.md （流程不确定时按需查阅）。')
    ) -join $NL

    $r = Write-Block $target $body
    if ($r -eq 'created')  { Write-Host '  + 已创建: ~/.claude/CLAUDE.md' }
    if ($r -eq 'updated')  { Write-Host '  ~ 已更新 ~/.claude/CLAUDE.md 中的标记块' }
    if ($r -eq 'appended') { Write-Host '  ~ 已追加标记块到 ~/.claude/CLAUDE.md，原有内容保留' }

    Write-Host ''
    Write-Host '============================================================'
    Write-Host '  全局规则安装完成'
    Write-Host '============================================================'
    Write-Host '  下一步: 给某个项目建状态骨架 ——'
    Write-Host '          install.bat D:\你的项目路径'
    Write-Host '          或直接把项目文件夹拖到 install.bat 上'
    Write-Host ''
    Write-Host '  撤销: uninstall.bat （不带参数即撤全局）'
    Write-Host ''
    exit 0
}

# ============================================================
#  项目模式：带代码根目录
# ============================================================
$codeRoot = $codeRoot.Trim().Trim('"')
if (-not (Test-Path -LiteralPath $codeRoot -PathType Container)) { Fail ('目录不存在: ' + $codeRoot) }
$codeRoot = (Resolve-Path -LiteralPath $codeRoot).ProviderPath.TrimEnd('\')
if ($codeRoot -eq $PromptRoot) { Fail '不能把状态文件装进规则中心自己。请指定目标项目的代码根目录。' }

$defName = Split-Path -Leaf $codeRoot
if (-not $projName) {
    if ($auto) { $projName = $defName }
    else {
        $projName = (Read-Host ('项目名 [' + $defName + ']')).Trim()
        if (-not $projName) { $projName = $defName }
    }
}

Write-Host '============================================================'
Write-Host '  项目模式 —— 给项目建状态骨架'
Write-Host '============================================================'
Write-Host ''
Write-Host ('  代码根目录 : ' + $codeRoot)
Write-Host ('  项目名     : ' + $projName)
Write-Host ''
Write-Host '  将写入:'
Write-Host '    CONTEXT.md  design.md  USAGE.md'
Write-Host '    tasks\progress.md  tasks\_模块模板.md'
Write-Host '    CLAUDE.md   已存在则只追加标记块，不覆盖原内容'
Write-Host ''
if (-not $auto) {
    $ans = Read-Host '确认安装? [Y/n]'
    if ($ans -match '^(n|no)$') { Write-Host '已取消，未做任何改动。'; exit 0 }
}
Write-Host ''

$manifest = Join-Path $codeRoot '.prompt-workflow.manifest'

# 重装会重写 manifest；先继承上次记录的 created 项，
# 否则第二次装完再 uninstall /purge 会因为「文件已存在、本次没创建」而漏删。
$createdList = New-Object System.Collections.Generic.List[string]
if (Test-Path -LiteralPath $manifest) {
    foreach ($ln in [System.IO.File]::ReadAllLines($manifest, [System.Text.Encoding]::UTF8)) {
        if (-not $ln.StartsWith('created=')) { continue }
        $rel = $ln.Substring(8).Trim()
        if ($rel -and (-not $createdList.Contains($rel))) { $createdList.Add($rel) }
    }
}

$lines = New-Object System.Collections.Generic.List[string]
$lines.Add('# prompt-workflow install manifest -- 供 uninstall 使用，请勿手改')
$lines.Add('prompt_root=' + $PromptRoot)
$lines.Add('project=' + $projName)
$lines.Add('installed_at=' + (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'))

$tasksDir = Join-Path $codeRoot 'tasks'
if (-not (Test-Path -LiteralPath $tasksDir)) { New-Item -ItemType Directory -Path $tasksDir | Out-Null }

function Copy-One([string]$rel) {
    $dst = Join-Path $codeRoot $rel
    if (Test-Path -LiteralPath $dst) {
        Write-Host ('  - 已存在，跳过: ' + $rel)
        return
    }
    Copy-Item -LiteralPath (Join-Path $Tpl $rel) -Destination $dst
    if (-not $script:createdList.Contains($rel)) { $script:createdList.Add($rel) }
    Write-Host ('  + 已创建: ' + $rel)
}

Copy-One 'CONTEXT.md'
Copy-One 'design.md'
Copy-One 'USAGE.md'
Copy-One 'tasks\progress.md'
Copy-One 'tasks\_模块模板.md'

# 薄 CLAUDE.md：模板里已无绝对路径，只需替换项目名
$body = [System.IO.File]::ReadAllText((Join-Path $Tpl 'project-CLAUDE.md'), [System.Text.Encoding]::UTF8)
$body = $body.Replace($Placeholder, $projName)
$r = Write-Block (Join-Path $codeRoot 'CLAUDE.md') $body
if ($r -eq 'created')  { Write-Host '  + 已创建: CLAUDE.md';             $lines.Add('claude_md=created') }
if ($r -eq 'updated')  { Write-Host '  ~ 已更新 CLAUDE.md 中的标记块';  $lines.Add('claude_md=appended') }
if ($r -eq 'appended') { Write-Host '  ~ 已追加标记块到原有 CLAUDE.md'; $lines.Add('claude_md=appended') }

foreach ($rel in $createdList) { $lines.Add('created=' + $rel) }
[System.IO.File]::WriteAllLines($manifest, $lines, $Utf8)

Write-Host ''
Write-Host '============================================================'
Write-Host '  项目状态骨架安装完成'
Write-Host '============================================================'
Write-Host ('  已接入: ' + $codeRoot)
Write-Host '  规则由全局 ~/.claude/CLAUDE.md 加载；本项目状态由该目录下 CLAUDE.md 指向 CONTEXT.md'
Write-Host ''
Write-Host ('  下一步: 打开 ' + $codeRoot + '\CONTEXT.md 填「代码根目录」一项即可开工')
Write-Host ('  卸载:   uninstall.bat "' + $codeRoot + '"')
Write-Host ''
exit 0
