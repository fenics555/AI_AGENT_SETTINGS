@echo off
rem P19-FIX2 01.10.2026 23:14: EDIT 2 in isolation - ban on imitating a system check.
rem Target: laguna r1_zavis (fake Test-Path/Permission-denied text), glm h4_vram ("nvidia-smi"
rem as an invented action) and l5b_house_task (invented path D:\AI\repo\log\ollama_check.log).
rem BASELINE after EDIT 1 (rescored): 26b 15/15, glm 10/15, laguna 9/15,
rem at chars=18448 sha256=6de029ed (see p19fix1 run 23:04).
rem Criterion: 26b must STAY 15/15; glm >= 10; laguna >= 9 with fewer fabricated actions.
rem If 26b drops below 15 -> rollback immediately.
set CHECKS_OUT=D:\AI\log\ollama_checks
set LR_NUM_CTX=8192
set LR_NUM_PREDICT=260
set LR_SEED=42
set LR_THINK=0
del /q "%CHECKS_OUT%\p19fix2_done.txt" 2>nul
cmd /c "python -X utf8 D:\AI\AGENT_SETTINGS\checks\loop_revive_test.py gemma4:26b glm-4.7-flash:q4_K_M laguna-xs-2.1:latest" > "%CHECKS_OUT%\p19fix2.log" 2>&1
echo FINISHED 2026-10-01 p19fix2_no_fake_check checkers=ck4 seed=42 > "%CHECKS_OUT%\p19fix2_done.txt"