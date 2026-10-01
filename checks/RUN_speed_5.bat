@echo off
rem RUN_speed_5.bat - честная скорость генерации на 5 моделях (ответ владельца «26b быстрее 12b?»).
rem Инструмент правильный: один и тот же промпт, num_ctx=202752, think выключен принудительно,
rem меряется чистая генерация (eval_duration), а не среднее по коротким ответам батареи.
set CHECKS_OUT=D:\AI\log\ollama_checks
set SPEED_NUM_CTX=202752
set SPEED_NUM_PREDICT=400
python -X utf8 D:\AI\AGENT_SETTINGS\checks\speed_check.py gemma4:26b gemma4:12b glm-4.7-flash:q4_K_M nemotron-3.5-lightning:30b laguna-xs-2.1:latest