@echo off
rem Прогон "6 фактов + 4 ловушки" по указанным моделям.
rem Пример: RUN_strict_test.bat gemma4:26b gemma4:12b
set CHECKS_OUT=D:\AI\log\ollama_checks
set TEST_NUM_CTX=8192
set TEST_NUM_PREDICT=300
set TEST_THINK=0
python -X utf8 D:\AI\AGENT_SETTINGS\checks\strict_test.py %*
