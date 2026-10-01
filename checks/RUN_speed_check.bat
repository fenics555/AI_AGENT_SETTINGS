@echo off
rem Замер скорости модели: load, prompt t/s, gen t/s.
rem Пример: RUN_speed_check.bat gemma4:26b
set CHECKS_OUT=D:\AI\log\ollama_checks
set SPEED_NUM_CTX=202752
set SPEED_NUM_PREDICT=250
python -X utf8 D:\AI\AGENT_SETTINGS\checks\speed_check.py %*
