@echo off
rem ==============================================================================
rem t2_tool_use_result — ПРОГОН ПО СПИСКУ МОДЕЛЕЙ, последовательно (02.10.2026).
rem Последовательность обязательна: при OLLAMA_MAX_LOADED_MODELS=1 параллельный запуск
rem заставляет модели вытеснять друг друга и портит честность замера (проверено 12:27 —
rem пять одновременных прогонов отработали, но конкурировали за VRAM).
rem
rem ИСПОЛЬЗОВАНИЕ:
rem   RUN_t2_models.bat                       — ядро (5), приёмка v2
rem   RUN_t2_models.bat laguna-xs.2:q4_K_M ... — произвольный список (информаторы)
rem
rem Каждая модель: t2_tool_use_result.py <модель> -> t2_<безопасное_имя>.txt
rem Сводка: t2_summary.txt (вердикт + тип провала по каждой модели)
rem ==============================================================================
set LOGDIR=D:\AI\log\ollama_checks
set PY=D:\AI\AGENT_SETTINGS\checks\t2_tool_use_result.py

if "%~1"=="" goto core

:custom
for %%M in (%*) do call :one "%%M"
goto done

:core
call :one gemma4:26b
call :one gemma4:12b
call :one glm-4.7-flash:q4_K_M
call :one laguna-xs-2.1:latest
call :one qwen3.8:latest
goto done

:one
set M=%~1
set SAFE=%M::=%
set SAFE=%SAFE:.=%
set SAFE=%SAFE:-=%
echo === %M% >> "%LOGDIR%\t2_summary.txt"
python -X utf8 "%PY%" "%M%" > "%LOGDIR%\t2_%SAFE%.txt" 2>&1
echo [t2] %M% done >> "%LOGDIR%\t2_summary.txt"
goto :eof

:done
echo T2_BATCH_FINISHED >> "%LOGDIR%\t2_summary.txt"
exit /b 0
