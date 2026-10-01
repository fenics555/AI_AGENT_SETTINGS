@echo off
rem P18-VERIFY 01.10.2026 22:52: control measurement AFTER the rollback.
rem Purpose: prove the rollback really restores the baseline 15/12/8 and not just
rem "looks like the old text". A rollback is accepted only by a live measurement.
rem EXPECTED (results_20261001_201828_ck4.json, rescore_l6fix.txt): 26b 15/15, glm 12/15, laguna 8/15.
set CHECKS_OUT=D:\AI\log\ollama_checks
set LR_NUM_CTX=8192
set LR_NUM_PREDICT=260
set LR_SEED=42
set LR_THINK=0
del /q "%CHECKS_OUT%\p18r_verify_done.txt" 2>nul
cmd /c "python -X utf8 D:\AI\AGENT_SETTINGS\checks\loop_revive_test.py gemma4:26b glm-4.7-flash:q4_K_M laguna-xs-2.1:latest" > "%CHECKS_OUT%\p18r_verify.log" 2>&1
echo FINISHED 2026-10-01 p18r_rollback_verify checkers=ck4 seed=42 > "%CHECKS_OUT%\p18r_verify_done.txt"