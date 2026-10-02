# -*- coding: utf-8 -*-
"""t3_tool_ignored — модель НЕ должна звать инструмент там, где он не нужен.

Направление, обратное t1: там мы проверяем инициативу (позвать инструмент, когда факт
проверяем), здесь — сдержанность (не звать, когда ответ известен из вопроса).

Зачем: в п.3 `glm` сделала 4 вызова подряд на вопрос о машине, где хватало одного.
Модель, которая «просто всегда зовёт инструмент», не отличается от модели, которая
умеет выбирать. Дом платит за каждый лишний вызов.

Порядок (спека v2 §2):
  1. Вопрос с ОЧЕВИДНЫМ ответом, который инструментом не лучше уточнять.
  2. Передаём tools.
  3. Считаем вызовы: 0 = PASS (сдержанность), > 0 = FAIL класса В (перерасход).
  Лимит 3 — обрезка по грабли п.3.

Запуск: cmd /c python -X utf8 t3_tool_ignored.py [модель]
"""
import json
import sys

sys.path.insert(0, r"D:\AI\AGENT_SETTINGS\checks")
import loop_revive_test as L  # noqa: E402

MODEL = sys.argv[1] if len(sys.argv) > 1 else "gemma4:26b"
CALL_LIMIT = 3

TOOLS = [
    {
        "type": "function",
        "function": {
            "name": "web_search",
            "description": "Поиск в интернете. Возвращает выдержки из найденных страниц.",
            "parameters": {"type": "object",
                           "properties": {"query": {"type": "string", "description": "запрос"}},
                           "required": ["query"]},
        },
    },
]

# Вопросы с ответом, который даётся без инструмента. Инструмент тут не нужен.
PROBES = [
    ("арифметика", "Сколько будет 17 умножить на 23? Ответь только числом."),
    ("свои слова", "Объясни в одном предложении, зачем нужны логи. Без инструментов."),
    ("своё определение", "Дай своё определение термину «дедлайн» одним предложением."),
]


def main():
    print("МОДЕЛЬ: %s   ЛИМИТ ВЫЗОВОВ: %d" % (MODEL, CALL_LIMIT))
    print("=" * 92)
    total_calls = 0
    for label, q in PROBES:
        opts = {"num_ctx": L.NUM_CTX, "num_predict": L.NUM_PREDICT, "seed": L.SEED}
        opts.update(L.MODEL_OPTIONS.get(MODEL, {}))
        body = {"model": MODEL, "messages": [{"role": "user", "content": q}],
                "stream": False, "think": False, "tools": TOOLS, "options": opts}
        rec = {"label": label, "calls": 0, "err": ""}
        try:
            data = L.post("/api/chat", body)
            msg = data.get("message") or {}
            calls = msg.get("tool_calls") or []
            rec["calls"] = len(calls)
            rec["shown"] = calls[:CALL_LIMIT]
            rec["text"] = (msg.get("content") or "")[:120]
        except Exception as exc:  # noqa: BLE001
            rec["err"] = str(exc)[:120]
        total_calls += rec["calls"]
        print("-" * 92)
        print("ПРОБА: %s | %s" % (label, q))
        print("    вызовов: %d%s" % (rec["calls"],
                                     " (ПРЕВЫШЕН ЛИМИТ)" if rec["calls"] > CALL_LIMIT else ""))
        for c in rec.get("shown") or []:
            fn = (c.get("function") or {})
            print("    -> %s(%s)" % (fn.get("name"), str(fn.get("arguments"))[:90]))
        print("    ответ: %s" % (rec.get("text") or rec["err"] or "<ПУСТО>"))
        L.unload(MODEL)

    print("=" * 92)
    verdict = "PASS" if total_calls == 0 else "FAIL"
    print("ВЕРДИКТ t3_tool_ignored: %s   (всего вызовов: %d)" % (verdict, total_calls))
    print("ТИП ПРОВАЛА: %s"
          % ("—" if total_calls == 0
             else "перерасход вызовов — инструмент зван там, где не нужен"))


if __name__ == "__main__":
    main()
