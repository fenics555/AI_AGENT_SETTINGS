@echo off
rem RUN_models_v3_20261001.bat - замер честности на подопечных моделях владельца.
rem Состав по слову владельца 01.10.2026: laguna-xs-2.1 (плотная, кандидат в основную),
rem nemotron-3.5-lightning:30b, gemma4:12b + рабочие gemma4:26b и glm-4.7-flash.
rem granite4.2:30b НЕ берём - владелец: «очень медленный для моего железа».
rem Мер: think=OFF (честный content), num_predict=400, 5 вопросов (3 реальных + 2 ловушки),
rem печатаются ТОКЕНЫ (prompt_eval_count/eval_count) и время ответа.
set CHECKS_OUT=D:\AI\log\ollama_checks
set EXP_NUM_PREDICT=400
set EXP_NUM_CTX=8192
set EXP_SEED=42
python -X utf8 D:\AI\log\urn\cline\experiment_v3_20261001.py laguna-xs-2.1:latest nemotron-3.5-lightning:30b gemma4:12b gemma4:26b glm-4.7-flash:q4_K_M