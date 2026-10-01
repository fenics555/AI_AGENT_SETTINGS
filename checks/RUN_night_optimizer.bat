@echo off
rem Ночной оптимизатор — пуск без агента (закон трёх линий: CLI для ночи, окно для человека).
rem Использование:
rem   RUN_night_optimizer.bat list              - показать очередь гипотез
rem   RUN_night_optimizer.bat report             - собрать отчёт ночи из журнала
rem   RUN_night_optimizer.bat <HID>              - итерация с применением правки
set CHECKS_OUT=D:\AI\log\ollama_checks
if "%~1"=="" goto usage
if /I "%~1"=="list"    goto list
if /I "%~1"=="report"  goto report
if /I "%~1"=="gui"     goto gui
cmd /c "python -X utf8 D:\AI\AGENT_SETTINGS\checks\night_optimizer.py --run %1 --apply"
goto :eof
:list
cmd /c "python -X utf8 D:\AI\AGENT_SETTINGS\checks\night_optimizer.py --list"
goto :eof
:report
cmd /c "python -X utf8 D:\AI\AGENT_SETTINGS\checks\night_optimizer.py --report"
goto :eof
:gui
cmd /c "python -X utf8 D:\AI\AGENT_SETTINGS\checks\night_optimizer_gui.py"
goto :eof
:usage
echo RUN_night_optimizer.bat list ^| report ^| gui ^| ^<ID^>
echo   список: R0 (откат, принят), H1 (провал, закрыта), H2-H5 (нужен якорь от ноги)
