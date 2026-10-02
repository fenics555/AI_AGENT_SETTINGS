@echo off
rem ==============================================================================
rem t3_tool_ignored — прогон по всем 9 моделям стека (02.10.2026, слово владельца).
rem Предмет: НЕ звать инструмент там, где он не нужен (уместность, а не инициатива).
rem Последовательность обязательна: при OLLAMA_MAX_LOADED_MODELS=1 параллельный запуск
rem заставляет модели вытеснять друг друга и портит честность замера.
rem
rem ИСПОЛЬЗОВАНИЕ:
rem   RUN_t3_models.bat                         — все 9 моделей стека
rem   RUN_t3_models.bat glm-4.7-flash:q4_K_M    — произвольный список
rem
rem Каждая модель: t3_tool_ignored.py <модель> -> t3_<безопасное_имя>.txt
rem Сводка: t3_summary.txt
rem ==============================================================================
set LOGDIR=D:\AI\log\ollama_checks
set PY=D:\AI\AGENT_SETTINGS\checks\t3_tool_ignored.py

if not "%~1"=="" goto custom

:all
call :one gemma4:26b
call :one gemma4:12b
call :one glm-4.7-flash:q4_K_M
call :one qwen3.8:latest
call :one laguna-xs-2.1:latest
call :one laguna-xs.2:q4_K_M
call :one nemotron-3.5-lightning:30b
call :one gpt-oss:20b
call :one deepseek-r1:14b
goto done

:custom
for %%M in (%*) do call :one "%%M"
goto done

:one
set M=%~1
set SAFE=%M::=%
set SAFE=%SAFE:.=%
set SAFE=%SAFE:-=%
echo === %M% >> "%LOGDIR%\t3_summary.txt"
python -X utf8 "%PY%" "%M%" > "%LOGDIR%\t3_%SAFE%.txt" 2>&1
echo [t3] %M% done >> "%LOGDIR%\t3_summary.txt"
goto :eof

:done
echo T3_BATCH_FINISHED >> "%LOGDIR%\t3_summary.txt"
exit /b 0
