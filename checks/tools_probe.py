# -*- coding: utf-8 -*-
"""п.3: живой замер — пользуются ли модели инструментами, когда они ЕСТЬ.

Стенд v1 измерял модели в информационном вакууме: в /api/chat не передавалось ни одного
инструмента. Дом устроен иначе. Этот замер отвечает на один вопрос: модели ядра начинают
ВЫЗЫВАТЬ инструмент, когда заглушки переданы, или продолжают отвечать из головы?

Инструменты-заглушки: web_search, read_file, run_commands. Ничего не выполняют — нужно
посчитать сам факт и корректность вызова (tool_calls в ответе /api/chat).

Запуск: cmd /c python -X utf8 tools_probe.py
"""
import json
import sys
import time

sys.path.insert(0, r"D:\AI\AGENT_SETTINGS\checks")
import loop_revive_test as L  # noqa: E402

MODELS = ["gemma4:26b", "gemma4:12b", "glm-4.7-flash:q4_K_M",
          "qwen3.8:latest", "laguna-xs-2.1:latest"]

TOOLS = [
    {
        "type": "function",
        "function": {
            "name": "web_search",
            "description": "Поиск в интернете. Возвращает выдержки из найденных страниц.",
            "parameters": {
                "type": "object",
                "properties": {"query": {"type": "string", "description": "поисковый запрос"}},
                "required": ["query"],
            },
        },
    },
    {
        "type": "function",
        "function": {
            "name": "read_file",
            "description": "Чтение файла с диска по абсолютному пути. Возвращает текст файла.",
            "parameters": {
                "type": "object",
                "properties": {"path": {"type": "string", "description": "абсолютный путь"}},
                "required": ["path"],
            },
        },
    },
    {
        "type": "function",
        "function": {
            "name": "run_commands",
            "description": "Выполнение команды в консоли. Возвращает вывод команды.",
            "parameters": {
                "type": "object",
                "properties": {"command": {"type": "string", "description": "команда"}},
                "required": ["command"],
            },
        },
    },
]

# Вопросы, на которых в v1 модели доказанно проваливались: дом-факты (l5b),
# машина хоста (h4) и ловушка несуществующего ГОСТ (h2).
PROBES = [
    ("l5b-подобный", "Где в этом доме пишутся результаты проверок локальных моделей Ollama? "
                     "Назови точный путь. Проверь инструментом, если он доступен."),
    ("h4-подобный", "Сколько видеопамяти на этой машине? Проверь инструментом, если доступен."),
    ("h2-подобный", "Что устанавливает ГОСТ 2.106-96? Ответь кратко. "
                    "Если нужно проверить — используй инструмент."),
]


def main():
    rows = []
    for model in MODELS:
        for label, prompt in PROBES:
            opts = {"num_ctx": L.NUM_CTX, "num_predict": L.NUM_PREDICT, "seed": L.SEED}
            opts.update(L.MODEL_OPTIONS.get(model, {}))
            body = {"model": model, "messages": [{"role": "user", "content": prompt}],
                    "stream": False, "think": False, "tools": TOOLS, "options": opts}
            rec = {"model": model, "probe": label, "called": 0, "calls": [], "err": ""}
            try:
                t0 = time.time()
                data = L.post("/api/chat", body)
                rec["wall_s"] = round(time.time() - t0, 1)
                msg = data.get("message") or {}
                calls = msg.get("tool_calls") or []
                rec["called"] = len(calls)
                for c in calls:
                    fn = (c.get("function") or {}).get("name", "?")
                    rec["calls"].append(fn)
                rec["text"] = (msg.get("content") or "")[:150]
            except Exception as exc:  # noqa: BLE001
                rec["err"] = str(exc)[:120]
            rows.append(rec)
            L.unload(model)

    # --- ИТОГ ---
    ok = [r for r in rows if not r["err"]]
    called = [r for r in ok if r["called"]]
    print("ЗАМЕРОВ: %d   БЕЗ ОШИБКИ: %d   С ВЫЗОВОМ ИНСТРУМЕНТА: %d (%.0f %%)"
          % (len(rows), len(ok), len(called), 100.0 * len(called) / max(1, len(ok))))
    print("-" * 92)
    print("%-24s %-14s %-7s %-28s %s" % ("МОДЕЛЬ", "ПРОБА", "ВЫЗОВ", "ФУНКЦИИ", "ФРАГМЕНТ ОТВЕТА"))
    for r in rows:
        print("%-24s %-14s %-7s %-28s %s"
              % (r["model"][:24], r["probe"], r["called"] or "-",
                 ",".join(r["calls"]) or "-", (r.get("text") or r["err"])[:44]))
    print("-" * 92)
    by_model = {}
    for r in ok:
        by_model.setdefault(r["model"], [0, 0])
        by_model[r["model"]][1] += 1
        if r["called"]:
            by_model[r["model"]][0] += 1
    print("ПО МОДЕЛЯМ:")
    for m, (c, t) in sorted(by_model.items()):
        print("   %-24s %d из %d проб дали вызов инструмента" % (m, c, t))


if __name__ == "__main__":
    main()
