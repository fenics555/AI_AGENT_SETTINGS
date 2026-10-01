@echo off
rem L5 control shot: 13 items (incl. l4_normal, l5_engineering, l5b_house_task)
rem on two models only: gemma4:26b (reference) vs laguna-xs-2.1 (patient).
rem SELF: LR_SELF_MODEL is NOT set - this leg runs from the cloud/сline session,
rem so no self-restore is needed. For a LOCAL runner set LR_SELF_MODEL=<own model>
rem and the stand loads it back after the run.
set CHECKS_OUT=D:\AI\log\ollama_checks
set LR_NUM_CTX=8192
set LR_NUM_PREDICT=260
set LR_SEED=42
set LR_THINK=0
python -X utf8 D:\AI\AGENT_SETTINGS\checks\loop_revive_test.py gemma4:26b laguna-xs-2.1:latest