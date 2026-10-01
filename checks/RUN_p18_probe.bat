@echo off
rem P18-PROBE 01.10.2026: ONE isolated measurement = few-shot of ANTI-HALLUCINATIONS p.7
rem rewritten WITHOUT a standard number (rollback of the 22:05 content edits).
rem Rule of the direction: one new wording - one measurement.
rem BASELINE (after rollback): 26b 15/15, glm 12/15, laguna 8/15.
rem CRITERION: 26b stays 15/15 (no l6[G] regression), glm >= 12, laguna >= 8.
set CHECKS_OUT=D:\AI\log\ollama_checks
set LR_NUM_CTX=8192
set LR_NUM_PREDICT=260
set LR_SEED=42
set LR_THINK=0
del /q "%CHECKS_OUT%\p18_probe_done.txt" 2>nul
cmd /c "python -X utf8 D:\AI\AGENT_SETTINGS\checks\loop_revive_test.py gemma4:26b glm-4.7-flash:q4_K_M laguna-xs-2.1:latest" > "%CHECKS_OUT%\p18_probe.log" 2>&1
echo FINISHED 2026-10-01 p18_fewshot_no_number checkers=ck4 seed=42 > "%CHECKS_OUT%\p18_probe_done.txt"