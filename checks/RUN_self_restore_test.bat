@echo off
rem RUN_self_restore_test.bat - проверка самодостаточности стенда (вариант C).
rem Идея: рабочая модель (LR_SELF_MODEL) загружена в VRAM, прогон тестов вытесняет её
rem (OLLAMA_MAX_LOADED_MODELS=1), а после прогона стенд обязан её вернуть.
rem Здесь: возвращаем gemma4:26b, а прогоняем на glm-4.7-flash (другой модели).
rem Проверка приёмки: GET /api/ps после финиша — в памяти должна быть gemma4:26b.
set CHECKS_OUT=D:\AI\log\ollama_checks
set LR_NUM_CTX=8192
set LR_NUM_PREDICT=260
set LR_SEED=42
set LR_THINK=0
set LR_SELF_MODEL=gemma4:26b
set LR_SELF_KEEPALIVE=5m
python -X utf8 D:\AI\AGENT_SETTINGS\checks\loop_revive_test.py glm-4.7-flash:q4_K_M