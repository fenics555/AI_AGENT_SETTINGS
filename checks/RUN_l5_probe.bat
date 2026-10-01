@echo off
rem CONTENT-EDITS probe 01.10.2026 22:05: three content edits in .clinerules:
rem  (1) слово-состояние само по себе = триггер, запрет требовать подтверждения (glm r1);
rem  (2) АНТИ-ГАЛЛЮЦИНАЦИИ 10а: запрет выдумывать результат обращения к системе на триггере (laguna r1 = класс F);
rem  (3) ПРИМЕР-ПРАВИЛО НЕВЕРНО/ВЕРНО по п.1.
rem ОТКАТ: удалить блок «СЛОВО-СОСТОЯНИЕ САМО ПО СЕБЕ», подпункт «10а.», строку «ПРИМЕР-ПРАВИЛО».
set CHECKS_OUT=D:\AI\log\ollama_checks
set LR_NUM_CTX=8192
set LR_NUM_PREDICT=260
set LR_SEED=42
set LR_THINK=0
del /q "%CHECKS_OUT%\content_probe_done.txt" 2>nul
cmd /c "python -X utf8 D:\AI\AGENT_SETTINGS\checks\loop_revive_test.py gemma4:26b glm-4.7-flash:q4_K_M laguna-xs-2.1:latest" > "%CHECKS_OUT%\content_probe.log" 2>&1
echo FINISHED 2026-10-01 22:xx models=gemma4:26b,glm,laguna content_edits=3 checkers=ck4 seed=42 > "%CHECKS_OUT%\content_probe_done.txt"