@echo off
rem ALL-MODELS 02.10.2026 08:50: состав пересобран после удаления трёх моделей с диска
rem (слово владельца): deepseek-r1:32b (19 ГБ), gemma4:31b (19 ГБ), granite4.2:30b (17 ГБ).
rem Это были три самые медленные модели (38,4 мин из 55,3). Осталось 9 чат-моделей.
rem Ожидание: ~17 минут вместо 55 (быстрый канал ядра — около 6 минут).
rem Параметры РОВНО как в базовой линии: ctx=8192, predict=260, seed=42, think=0, checkers=ck4.
rem nomic-embed-text исключён — эмбеддинг, не чат.
set CHECKS_OUT=D:\AI\log\ollama_checks
set LR_NUM_CTX=8192
set LR_NUM_PREDICT=260
set LR_SEED=42
set LR_THINK=0
del /q "%CHECKS_OUT%\allm_done.txt" 2>nul
cmd /c "python -X utf8 D:\AI\AGENT_SETTINGS\checks\loop_revive_test.py gemma4:26b glm-4.7-flash:q4_K_M laguna-xs-2.1:latest gemma4:12b qwen3.8:latest laguna-xs.2:q4_K_M nemotron-3.5-lightning:30b gpt-oss:20b deepseek-r1:14b" > "%CHECKS_OUT%\allm.log" 2>&1
echo FINISHED %DATE% %TIME% all-9-models checkers=ck4 think=0 ctx=8192 predict=260 seed=42 > "%CHECKS_OUT%\allm_done.txt"
