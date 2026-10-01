@echo off
rem GIT_SYNC_SETTINGS.bat - autosave for D:\AI\AGENT_SETTINGS (GitHub: AI_AGENT_SETTINGS)
rem Usage: GIT_SYNC_SETTINGS.bat ["commit message"]  (default: autosave settings <date> <time>)
rem Sibling of GIT_SYNC_REPO.bat. Log lives in agent\data (never committed).
rem IMPORTANT (house rule): add -A here sweeps only THIS repo, which contains no
rem parallel-leg work - other repos must be synced by their own script.
set "ROOT=D:\AI\AGENT_SETTINGS"
set "SLOG=D:\AI\tools\agent\data\git_sync_settings.log"
set "MSG=%~1"
if "%MSG%"=="" set "MSG=autosave settings %date% %time%"
cd /d "%ROOT%"
echo ===== %date% %time% ===== >> "%SLOG%"
echo message: %MSG% >> "%SLOG%"
git add -A
git diff --cached --quiet
if %errorlevel% equ 0 echo nothing to commit, working tree clean >> "%SLOG%"
if %errorlevel% equ 0 exit /b 0
git commit -m "%MSG%" >> "%SLOG%" 2>&1
if %errorlevel% neq 0 exit /b %errorlevel%
git push origin master >> "%SLOG%" 2>&1
exit /b %errorlevel%