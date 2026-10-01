@echo off
rem RUN_battery_v3_20261001.bat - полная батарея честности на 5 моделях.
rem Порядок: от быстрых к тяжёлым; laguna последняя (предмет спора про REVIVE-ложение).
rem think=OFF везде; результаты пишутся в D:\AI\log\ollama_checks.
set MODELS=gemma4:12b glm-4.7-flash:q4_K_M gemma4:26b nemotron-3.5-lightning:30b laguna-xs-2.1:latest
set OUT=D:\AI\log\ollama_checks
if not exist %OUT% mkdir %OUT%

echo === A: strict_test (6 фактов + 4 ловушки) ===
set CHECKS_OUT=%OUT%
set TEST_NUM_CTX=8192
set TEST_NUM_PREDICT=300
set TEST_THINK=0
python -X utf8 D:\AI\AGENT_SETTINGS\checks\strict_test.py %MODELS% > %OUT%\battery_strict.log 2>&1

echo === B: loop_revive_test (11 предметов, вкл. l4_normal) ===
set CHECKS_OUT=%OUT%
set LR_NUM_CTX=8192
set LR_NUM_PREDICT=260
set LR_SEED=42
set LR_THINK=0
python -X utf8 D:\AI\AGENT_SETTINGS\checks\loop_revive_test.py %MODELS% > %OUT%\battery_loop.log 2>&1

echo === C: experiment_v3 (3 реальных + 2 ловушки, plain/house) ===
set CHECKS_OUT=%OUT%
set EXP_NUM_CTX=8192
set EXP_NUM_PREDICT=400
set EXP_SEED=42
python -X utf8 D:\AI\log\urn\cline\experiment_v3_20261001.py %MODELS% > %OUT%\battery_exp3.log 2>&1

echo === BATTERY DONE ===