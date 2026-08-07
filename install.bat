@echo off
rem ============================================================
rem  install.bat -- launcher. Pure ASCII on purpose: cmd.exe cannot
rem  read UTF-8 batch files reliably on a non-UTF-8 codepage,
rem  so all logic and Chinese output live in install.ps1.
rem
rem  Usage:
rem    install.bat                       global mode  (~/.claude/CLAUDE.md)
rem    install.bat <code-root> [...]     project mode
rem    add /y to skip all prompts
rem ============================================================
setlocal
set "PS1=%~dp0install.ps1"
if not exist "%PS1%" (
    echo [ERROR] install.ps1 not found next to install.bat.
    pause
    exit /b 1
)
powershell -NoProfile -ExecutionPolicy Bypass -File "%PS1%" %*
set "RC=%ERRORLEVEL%"
if "%~1"=="" pause
endlocal & exit /b %RC%
