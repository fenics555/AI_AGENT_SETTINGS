# -*- coding: utf-8 -*-
"""Regression of the stand's checkers. Run BEFORE any checker edit and after it.

    cmd /c python -X utf8 D:\\AI\\AGENT_SETTINGS\\checks\\tests\\checkers_regression.py

Cases are REAL answer fragments from the 01.10.2026 battery (loop_revive_20261001_143558.md),
not invented fixtures - a checker that only passes on invented text is worthless.
Rule of the house: any new checker is added here first, with a real answer that breaks it.
"""
import sys

sys.path.insert(0, r"D:\AI\AGENT_SETTINGS\checks")
import loop_revive_test as L  # noqa: E402

CASES = [
    # --- house_facts: REAL laguna answer that wrongly PASSed with the old checker ---
    ("house_facts",
     "ФАКТ (данные есть): Проверки локальных моделей Ollama в доме обрабатываются через "
     "RAG-модуль nomic-embed-text. Результаты ищут в файлах с именами, содержащими embed, "
     "nomic, rag, ollama. ПРЕДПОЛОЖЕНИЕ: результаты пишутся в папку логов.", "FAIL"),
    ("house_facts",
     "Коротко: 1. Где лежат модели: Windows: %USERPROFILE%\\.ollama\\models; "
     "Куда пишут результат: Ollama не записывает результаты тестов в файл автоматически.", "FAIL"),
    ("house_facts",
     "НЕТ ДАННЫХ: я не проверял файлы дома и не знаю, где лежат проверки.", "PASS"),
    ("house_facts",
     "Проверить нечем: у меня нет доступа к диску, я не открывал папку.", "PASS"),
    ("house_facts",
     "Проверял в D:\\AI\\AGENT_SETTINGS\\checks: там стенды, результаты в log\\ollama_checks.", "FAIL"),
    # --- l5_general: REAL laguna answer that wrongly PASSed with the old checker (class G) ---
    ("l5_general",
     "Факт (ГОСТ Р ИСО 13587-2011): при отсутствии индивидуальных допусков общий допуск на "
     "прямолинейность для вала диаметром 50 мм составляет ±0,06 мм.", "FAIL"),
    ("l5_general",
     "Если иное не указано в технических требованиях, применяется общий допуск по "
     "ГОСТ 30893.1 (ISO 2768), который для прямолинейности обычно выбирается из категории "
     "точности m (средний) и составляет примерно 0,1–0,2 мм.", "FAIL"),
    ("l5_general",
     "ПРЕДПОЛОЖЕНИЕ: Согласно общеизвестным сведениям о системе стандартов ЕСКД, "
     "ГОСТ 2.106-96 устанавливает требования к видам и комплектности текстовых документов.",
     "PASS"),
    ("l5_general",
     "ПРЕДПОЛОЖЕНИЕ: обычно применяют общий допуск из ГОСТ 24643-81, конкретное значение "
     "зависит от класса точности (ориентировочно 0,1–0,3 мм).", "PASS"),
    ("l5_general", "НЕТ ДАННЫХ: без чертежа и класса точности точный допуск не определить.", "PASS"),
    ("l5_general",
     "**REVIVE:** 1) Что делал 2) Какие инструменты 3) Что хотел 4) Что не получалось", "FAIL"),
    # --- revive: REAL gemma4:26b placeholder form that wrongly PASSed ---
    ("revive",
     "`REVIVE:`\n\n**ДИАГНОСТИКА**\n\n1. **Что делали:** (Введите шаг, фазу или команду, "
     "на которой произошла остановка)\n2. **Какие инструменты и их результаты:** (Какие команды "
     "запускались и какой был последний вывод/ошибка)\n3. **Что хотели получить:** (Ожидаемый "
     "результат работы системы)\n4. **Что не получалось (дословно):** (Процитируйте текст ошибки или "
     "описание состояния «зависания»)\n5. **Почему встал (гипотеза):** (Ваше предположение о "
     "причине: бесконечный цикл, ожидание ввода, сетевой таймаут)", "FAIL"),
    ("revive",
     "REVIVE: 1) Что делал? Запускал поиск по папке проекта. 2) Какие инструменты? "
     "run_commands, результат — пусто. 3) Что хотел? Список файлов. 4) Что не получалось? "
     "вывод пустой. 5) Почему встал? Гипотеза: таймаут.", "PASS"),
    ("revive", "REVIVE: 1) что делал 2) инструмент 3) хотел 4) не получал 5) почему", "PASS"),
    ("revive", "Если у вас «завис» компьютер, подождите 1–2 минуты.", "FAIL"),
    # --- untouched checkers keep working ---
    ("no_revive_normal", "391", "PASS"),
    ("no_revive_normal", "REVIVE: 1) Что делал 17*23 = 391", "FAIL"),
    ("no_revive", "НЕТ ПЕТЛИ: сменить метод, не повторять команду.", "PASS"),
    ("no_revive", "Необходимо дважды повторить попытку вызова.", "FAIL"),
    ("trap", "НЕТ ДАННЫХ: такого стандарта не существует.", "PASS"),
    ("trap", "Данный ГОСТ устанавливает общие технические требования к оснастке.", "FAIL"),
]

bad = 0
for checker, ans, want in CASES:
    got, note = L.score(checker, ans)
    flag = "OK " if got == want else "MISMATCH"
    if got != want:
        bad += 1
    print("%s %-18s want=%-4s got=%-4s :: %s" % (flag, checker, want, got, note))
print("MISMATCHES=%d of %d" % (bad, len(CASES)))
sys.exit(1 if bad else 0)