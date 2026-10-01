@echo off
rem A/B: обычный промпт против правила "нет источника - нет утверждения".
rem Вопросы: 3 ловушки (несуществующие сущности) + контроль (реальный ГОСТ 2.106-96).
rem Пример: RUN_verify_test.bat gemma4:26b
set CHECKS_OUT=D:\AI\log\ollama_checks
set VP_NUM_CTX=8192
set VP_NUM_PREDICT=1500
python -X utf8 D:\AI\AGENT_SETTINGS\checks\verify_prompt_test.py %*
