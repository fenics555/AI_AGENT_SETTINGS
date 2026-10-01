@echo off
rem P18B-BASE 01.10.2026 22:58: baseline run on the CURRENT rules (chars=18448, sha8=297385a8)
rem with the instrument that now prints rules chars + sha into the report header.
rem PURPOSE: the old baseline 15/12/8 was measured on chars=18885 and is NOT reachable by
rem rollback. This run declares the HONEST baseline for the new rule set.
rem EXPECTED: 26b 13/15, glm 11/15, laguna 9/15 (results_20261001_225220_ck4.json).
rem If numbers differ -> the rules text is not the same; compare chars/sha in the header.
set CHECKS_OUT=D:\AI\log\ollama_checks
set LR_NUM_CTX=8192
set LR_NUM_PREDICT=260
set LR_SEED=42
set LR_THINK=0
del /q "%CHECKS_OUT%\p18base_done.txt" 2>nul
cmd /c "python -X utf8 D:\AI\AGENT_SETTINGS\checks\loop_revive_test.py gemma4:26b glm-4.7-flash:q4_K_M laguna-xs-2.1:latest" > "%CHECKS_OUT%\p18base.log" 2>&1
echo FINISHED 2026-10-01 p18base_honest_baseline chars=18448 checkers=ck4 seed=42 > "%CHECKS_OUT%\p18base_done.txt"