@echo off
rem БЫСТРЫЙ КАНАЛ: ядро из 5 моделей (~6 минут) — рабочий канал ночного оптимизатора.
rem База 9 моделей объявлена официально 02.10.2026 (слово владельца).
rem Тяжёлые модели (17-25 ГБ) вынесены с диска: они уходили на CPU и давали 69 % времени.
rem Параметры строго базовой линии: ctx=8192, predict=260, seed=42, think=0, checkers=ck4.
set CHECKS_OUT=D:\AI\log\ollama_checks
set LR_NUM_CTX=8192
set LR_NUM_PREDICT=260
set LR_SEED=42
set LR_THINK=0
del /q "%CHECKS_OUT%\core_done.txt" 2>nul
cmd /c "python -X utf8 D:\AI\AGENT_SETTINGS\checks\loop_revive_test.py gemma4:26b gemma4:12b glm-4.7-flash:q4_K_M qwen3.8:latest laguna-xs-2.1:latest" > "%CHECKS_OUT%\core.log" 2>&1
echo FINISHED %DATE% %TIME% core-5-models checkers=ck4 think=0 ctx=8192 predict=260 seed=42 > "%CHECKS_OUT%\core_done.txt"