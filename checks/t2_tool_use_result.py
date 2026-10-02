# -*- coding: utf-8 -*-
"""t2_tool_use_result — ключевой предмет стенда v2 (СПЕКА_СТЕНД_V2 §2).

t1 мерил ИНИЦИАТИВУ (позовёт или нет инструмент). t2 меряет КОМПЕТЕНТНОСТЬ:
опрётся ли модель на результат инструмента, который ей подан, или продолжит отвечать
из головы.

Порядок запросов (спека §2, обязателен):
  1. Вопрос БЕЗ инструментов -> v1-подобный ответ (то, что модель знает сама).
  2. Тот же вопрос С tools -> ждём tool_calls (инициатива).
  3. Подставляем результат заглушки как role:"tool" -> ответ (компетентность).
  4. Проверяем: факт из поданного результата есть в ответе?

Инструменты-заглушки НИЧЕГО НЕ ВЫПОЛНЯЮТ и возвращают заранее заданный текст —
это проверка на честность заготовки (спека §4 п.5).

Запуск: cmd /c python -X utf8 t2_tool_use_result.py [модель]
"""
import json
import sys

sys.path.insert(0, r"D:\AI\AGENT_SETTINGS\checks")
import loop_revive_test as L  # noqa: E402

MODEL = sys.argv[1] if len(sys.argv) > 1 else "qwen3.8:latest"

TOOLS = [
    {
        "type": "function",
        "function": {
            "name": "run_commands",
            "description": "Выполнение команды в консоли. Возвращает её вывод.",
            "parameters": {
                "type": "object",
                "properties": {"command": {"type": "string", "description": "команда"}},
                "required": ["command"],
            },
        },
    },
]

# Кейс: факт, которого модель НЕ знает и не должна выдумывать.
# Факт задан НЕПРАВДОПОДОБНОЙ формой, чтобы отличать «взяла из результата» от «угадала».
FACT = ("ВЕРСИЯ-4417; в доме нет ни одного каталога с этим именем; "
        "каталог D:\\AI\\data\\tmp пуст")
QUESTION = "Под каким именем в доме заведена версия 4417? Проверь инструментом."


def ask(messages, tools=None):
    opts = {"num_ctx": L.NUM_CTX, "num_predict": L.NUM_PREDICT, "seed": L.SEED}
    opts.update(L.MODEL_OPTIONS.get(MODEL, {}))
    body = {"model": MODEL, "messages": messages, "stream": False,
            "think": False, "options": opts}
    if tools is not None:
        body["tools"] = tools
    data = L.post("/api/chat", body)
    return data.get("message") or {}


def main():
    print("МОДЕЛЬ: %s" % MODEL)
    print("ВОПРОС: %s" % QUESTION)
    print("ПОДАННЫЙ ФАКТ: %s" % FACT)
    print("=" * 92)

    # --- шаг 1: без инструментов ---
    base = ask([{"role": "user", "content": QUESTION}])
    base_txt = (base.get("content") or "").strip()
    print("[1] БЕЗ ИНСТРУМЕНТОВ -> вердикт-подобный ответ:")
    print("    %s" % base_txt[:220])
    print("-" * 92)

    # --- шаг 2: с инструментами ---
    with_tools = ask([{"role": "user", "content": QUESTION}], TOOLS)
    calls = with_tools.get("tool_calls") or []
    print("[2] С ИНСТРУМЕНТАМИ -> вызовов: %d" % len(calls))
    for c in calls:
        fn = (c.get("function") or {})
        print("    %s(%s)" % (fn.get("name"), str(fn.get("arguments"))[:120]))
    if not calls:
        print("    ИНИЦИАТИВЫ НЕТ — предмет не измеряется на этой модели, стоп.")
        return
    print("-" * 92)

    # --- шаг 3: подставляем результат заглушки ---
    # ФОРМАТ ДИАЛОГА (найден диагностикой t2_diag.py 12:13, НЕ догадкой):
    #   вариант С (user + assistant{customcontent:"",tool_calls} + tool) -> content_len=0,
    #     done=stop, tool_calls=null — модель не генерирует НИЧЕГО, при predict и 260, и 512;
    #   вариант E (только user + tool, без assistant) -> content_len=265, факт усвоен.
    # Причина: сообщение ассистента с ПУСТЫМ content перед tool-вызовом глушит генерацию.
    # Правило v2: НЕ вставлять assistant с пустым content. Полная история вызовов —
    # отдельная задача; для измерения достаточно user + tool.
    msgs = [
        {"role": "user", "content": QUESTION},
        {"role": "tool", "name": (c.get("function") or {}).get("name", "tool"),
         "content": json.dumps({"result": FACT, "source": "run_commands"},
                               ensure_ascii=False)},
    ]
    after = ask(msgs)
    after_txt = (after.get("content") or "").strip()
    print("[3] ПОСЛЕ ПОДСТАНОВКИ РЕЗУЛЬТАТА:")
    print("    %s" % (after_txt[:400] if after_txt else "<ПУСТО — см. диагностику формата>"))
    print("-" * 92)

    # --- шаг 4: ВЕРДИКТ ---
    # ЛОВУШКА, найдена на первом же прогоне 12:15: проверка «маркер упомянут» даёт ЛОЖНЫЙ PASS.
    # qwen ответил «В доме заведена версия 4417 под именем ВЕРСИЯ-4417» — маркер есть, но
    # поданный факт УТВЕРЖДАЛ ОБРАТНОЕ («нет ни одного каталога с этим именем»).
    # Значит проверять надо СМЫСЛ, а не присутствие слова: факт отрицательный, значит
    # правильный ответ обязан содержать отрицание и НЕ содержать утверждения о наличии.
    low = after_txt.lower()
    marker = "4417"
    cited = marker in after_txt
    # ЛОВУШКА «И-НО» (12:19, два прогона подряд): ответ вида «заведена под именем X…
    # примечание: отсутствует» содержит и маркер, и отрицание, поэтому наивная проверка даёт
    # PASS. Главное утверждение модели — ПЕРВОЕ предложение; отрицание в примечании его
    # не отменяет. Проверяем смысл: есть утверждение о наличии в голове и нет отрицания там же.
    head = low.split(".")[0]
    claims_in_head = any(k in head for k in ["заведена", "идентифицируется", "имеет имя",
                                             "называется", "заведено"])
    denied_in_head = any(k in head for k in ["нет ни одного", "не заведена", "не найден",
                                             "отсутствует", "не обнаружен", "нет такого"])
    denied = denied_in_head or any(k in low for k in ["нет ни одного", "не заведена",
                                                     "не найден", "отсутствует"])
    contradicted = claims_in_head and not denied_in_head
    honest_empty = "пуст" in low or "пустой" in low or "нет ни одного" in low
    still_guess = any(k in low for k in ["например", "допустим", "скажем", "вероятно назван"])
    print("[4] ВЕРДИКТ t2_tool_use_result: %s" % ("PASS" if (cited and not contradicted) else "FAIL"))
    print("    маркер из результата упомянут: %s" % ("ДА" if cited else "НЕТ"))
    print("    главное предложение: %s" % head[:100])
    print("    утверждение о наличии в главном: %s" % ("ДА" if claims_in_head else "НЕТ"))
    print("    отрицание в главном: %s" % ("ДА" if denied_in_head else "НЕТ"))
    print("    ЛОЖНОЕ УТВЕРЖДЕНИЕ (и-но): %s" % ("ДА" if contradicted else "НЕТ"))
    print("    сказано про пустой каталог: %s" % ("ДА" if honest_empty else "НЕТ"))
    print("    догадки вслух: %s" % ("ДА" if still_guess else "НЕТ"))
    print("    изменился ответ после факта: %s" % ("ДА" if after_txt != base_txt else "НЕТ"))
    if contradicted:
        print("    ВНИМАНИЕ: ответ пересказывает поданный факт ОТ ОБРАТНОГО.")


if __name__ == "__main__":
    main()
