@echo off
rem Полный прогон всех локальных генеративных моделей (кроме nomic-embed-text).
rem Внимание: ~10 минут и вытесняет модель, с которой вы работаете.
set CHECKS_OUT=D:\AI\log\ollama_checks
set TEST_NUM_CTX=8192
set TEST_NUM_PREDICT=300
python -X utf8 D:\AI\AGENT_SETTINGS\checks\strict_test.py gemma4:12b gemma4:26b gemma4:31b gpt-oss:20b nemotron-3.5-lightning:30b granite4.2:30b glm-4.7-flash:q4_K_M laguna-xs-2.1:latest
