@echo off
rem L5 control shot: 15 items (h1-h4, l1-l7, r1-r3) x {plain, house}
rem 3 models: gemma4:26b (reference), glm-4.7-flash (working, added by owner word 01.10.2026),
rem laguna-xs-2.1 (patient).
rem SELF: LR_SELF_MODEL is NOT set - this leg runs from the cloud/Cline session,
rem so no self-restore is needed. For a LOCAL runner set LR_SELF_MODEL=<own model>
rem and the stand loads it back after the run.
set CHECKS_OUT=D:\AI\log\ollama_checks
set LR_NUM_CTX=8192
set LR_NUM_PREDICT=260
set LR_SEED=42
set LR_THINK=0
python -X utf8 D:\AI\AGENT_SETTINGS\checks\loop_revive_test.py gemma4:26b glm-4.7-flash:q4_K_M laguna-xs-2.1:latest