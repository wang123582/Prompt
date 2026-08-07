@echo off
rem ============================================================
rem  uninstall.bat -- launcher. Pure ASCII on purpose: cmd.exe cannot
rem  read UTF-8 batch files reliably on a non-UTF-8 codepage,
rem  so all logic and Chinese output live in uninstall.ps1.
rem
rem  Usage:
rem    uninstall.bat                       global mode  (~/.claude/CLAUDE.md)
rem    uninstall.bat <code-root> [...]     project mode
rem    add /y to skip all prompts
rem ============================================================
setlocal
set "PS1=%~dp0uninstall.ps1"
if not exist "%PS1%" (
    echo [ERROR] uninstall.ps1 not found next to uninstall.bat.
    pause
    exit /b 1
)
powershell -NoProfile -ExecutionPolicy Bypass -File "%PS1%" %*
set "RC=%ERRORLEVEL%"
if "%~1"=="" pause
endlocal & exit /b %RC%
