@echo off
rem ==============================================================================
rem АРХИВ. НЕ ЗАПУСКАТЬ ДЛЯ ПРИЁМКИ (правка 02.10.2026, слово владельца: «если нужно
rem править RUN_p18_probe.bat — правь»).
rem
rem ЧТО ЭТО: прогон гипотезы H1 (подъём SECTION_MAX 7000→10000). Гипотеза ПРОВАЛЕНА
rem   01.10.2026: laguna 9→4 при зелёном health check. Откат выполнен, тема закрыта.
rem   Запуск этого файла сегодня воспроизводит ПРОВАЛЕННЫЙ эксперимент.
rem ПОЧЕМУ НЕ УДАЛЁН: файл принадлежит прошлой фазе, его след — в отчёте
rem   REPORT_p18_fewshot_no_number_2026-10-01.md и в ROADMAP §0 спеки.
rem
rem УСТАРЕВШЕЕ В ШАПКЕ (не соответствует официальной базе):
rem   BASE 15/10/9 при chars=18448 sha256=6de029ed — ОТМЕНЕНА владельцем 02.10.2026.
rem   Официальная база: 9 моделей, house 67/75 (ядро) + 33/60 (информаторы),
rem   chars=14556 sha256=22b7ef34. Критерий — по 5 моделям ядра, не по трём.
rem
rem ЧТО ЗАПУСКАТЬ ВМЕСТО ЭТОГО ФАЙЛА:
rem   все 9 моделей : RUN_all_models.bat   (~19,5 мин, закон замера владельца 10:20)
rem   только ядро   : RUN_night_core.bat   (~6-9 мин, отладка правки, НЕ приёмка)
rem ==============================================================================
rem Оригинальная шапка H1 (01.10.2026 23:40) сохранена ниже без изменений.
rem P20-SECTIONMAX 01.10.2026 23:40: owner's decision - raise SECTION_MAX as a separate stage.
rem WHAT:  SECTION_MAX 7000 -> 10000 AND the second silent cut, max_chars 20000 -> 40000
rem        (sum of sections = 20 873 > 20 000, so raising one limit alone would have re-cut
rem         the tail of ВОСКРЕШЕНИЕ - measured, not assumed).
rem BASE (official, decided by owner): 26b 15/15, glm 10/15, laguna 9/15
rem        at chars=18448 sha256=6de029ed, num_ctx=8192, num_predict=260, think=OFF.
rem CTX FIT PROVEN (PROBE_ctx3): prompt_eval 26b=7201 glm=7186 laguna=4099, all < 8192,
rem        done=stop, answer 391 correct. No sliding window, so the run is valid.
rem CRITERION (owner): 26b >= 15, glm >= 10, laguna >= 9 -> accept; otherwise roll back.
rem HYPOTHESIS: this is the last one that may heal laguna r1-r3 without redistribution.
set CHECKS_OUT=D:\AI\log\ollama_checks
set LR_NUM_CTX=8192
set LR_NUM_PREDICT=260
set LR_SEED=42
set LR_THINK=0
del /q "%CHECKS_OUT%\p20sm_done.txt" 2>nul
cmd /c "python -X utf8 D:\AI\AGENT_SETTINGS\checks\loop_revive_test.py gemma4:26b glm-4.7-flash:q4_K_M laguna-xs-2.1:latest" > "%CHECKS_OUT%\p20sm.log" 2>&1
echo FINISHED 2026-10-01 p20sm_section_max_10000 checkers=ck4 seed=42 > "%CHECKS_OUT%\p20sm_done.txt"