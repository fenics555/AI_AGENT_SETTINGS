@echo off
rem P18-PROBE-2 01.10.2026 22:40: SECOND iteration of the same edit, one measurement.
rem Law found in phase 19: replacing a few-shot wording does not delete the template,
rem it MOVES it to a neighbouring situation. Fix: the example distinguishes TWO situations.
rem BASELINE before this edit: 26b 14/15, glm 9/15, laguna 10/15 (results_20261001_223131_ck4.json).
rem TARGET: 26b returns to 15/15 (l5b[B] healed) and laguna stays >= 8.
rem If not -> full rollback of .clinerules, cycle closed.
set CHECKS_OUT=D:\AI\log\ollama_checks
set LR_NUM_CTX=8192
set LR_NUM_PREDICT=260
set LR_SEED=42
set LR_THINK=0
del /q "%CHECKS_OUT%\p18b_probe_done.txt" 2>nul
cmd /c "python -X utf8 D:\AI\AGENT_SETTINGS\checks\loop_revive_test.py gemma4:26b glm-4.7-flash:q4_K_M laguna-xs-2.1:latest" > "%CHECKS_OUT%\p18b_probe.log" 2>&1
echo FINISHED 2026-10-01 p18b_two_situations checkers=ck4 seed=42 > "%CHECKS_OUT%\p18b_probe_done.txt"