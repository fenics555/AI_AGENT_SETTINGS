@echo off
chcp 65001 >nul
cd /d D:\AI\AGENT_SETTINGS\think_probe

echo ============================================
echo  RUN ALL CHECKS: v4 - v5 - v6
echo ============================================
echo.

echo [1/3] v4 - поведение моделей
echo.
powershell -NoProfile -ExecutionPolicy Bypass -File "D:\AI\AGENT_SETTINGS\think_probe\think_probe_v4.ps1"
echo.
echo v4 exit=%errorlevel%
echo.

echo [2/3] v5 - генерация скрипта
echo.
powershell -NoProfile -ExecutionPolicy Bypass -File "D:\AI\AGENT_SETTINGS\think_probe\think_probe_v5.ps1"
echo.
echo v5 exit=%errorlevel%
echo.

echo [3/3] v6 - выбор инструмента
echo.
powershell -NoProfile -ExecutionPolicy Bypass -File "D:\AI\AGENT_SETTINGS\think_probe\think_probe_v6.ps1"
echo.
echo v6 exit=%errorlevel%
echo.

echo ============================================
echo  ALL DONE
echo ============================================
pause