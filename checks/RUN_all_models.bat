@echo off
rem ALL-MODELS 02.10.2026: полный прогон стенда по ВСЕМ чат-моделям стека одной итерацией.
rem Параметры РОВНО как в базовой линии, иначе цифры несравнимы с 15/10/9:
rem   LR_NUM_CTX=8192, LR_NUM_PREDICT=260, LR_SEED=42, LR_THINK=0, checkers=ck4.
rem Промпт не менялся с приёмки R0: chars=18448. Вход зафиксирован в шапке отчёта стенда.
rem Модели: 12 чат-моделей из `ollama list`. nomic-embed-text исключён — эмбеддинг, не чат.
rem granite4.2:30b ВКЛЮЧЁН по слову владельца «проверим все одной итерацией».
rem Ожидание: 12 моделей x 15 предметов x 2 условия = 360 запросов; база 3 модели = 240 с,
rem   но 19-25 ГБ модели при 16 ГБ VRAM идут на CPU — считать 25-45 минут.
set CHECKS_OUT=D:\AI\log\ollama_checks
set LR_NUM_CTX=8192
set LR_NUM_PREDICT=260
set LR_SEED=42
set LR_THINK=0
del /q "%CHECKS_OUT%\allm_done.txt" 2>nul
cmd /c "python -X utf8 D:\AI\AGENT_SETTINGS\checks\loop_revive_test.py gemma4:26b glm-4.7-flash:q4_K_M laguna-xs-2.1:latest gpt-oss:20b gemma4:12b nemotron-3.5-lightning:30b gemma4:31b deepseek-r1:14b deepseek-r1:32b qwen3.8:latest granite4.2:30b laguna-xs.2:q4_K_M" > "%CHECKS_OUT%\allm.log" 2>&1
echo FINISHED %DATE% %TIME% all-12-models checkers=ck4 think=0 ctx=8192 predict=260 seed=42 > "%CHECKS_OUT%\allm_done.txt"
