r"""prompt_tokens для ТЕКУЩЕГО промпта стенда — по ВСЕМ моделям, результат в json.

    cmd /c python -X utf8 D:\AI\AGENT_SETTINGS\checks\prompt_tokens_probe.py

Зачем: в прогоне, который уже отработал, поля prompt_tokens ещё не было (правка внесена
после). Чтобы таблица показывала числа для всех моделей, токены промпта меряются отдельно —
на том самом HOUSE_SYSTEM, который реально видит модель — и пишутся один раз в json рядом
с результатом прогона.

Метод: один запрос /api/chat с num_predict=1, think=False, num_ctx=8192; берётся
prompt_eval_count. Одна модель ≈ 20 с, все 12 — несколько минут детачем.
"""
import datetime
import json
import os
import sys
import time
import urllib.request

OLLAMA = "http://127.0.0.1:11434"
NUM_CTX = 8192
BUDGET = NUM_CTX - 260 - 400          # ответ + запас = 660
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import loop_revive_test as L            # noqa: E402

MODELS = ["gemma4:26b", "glm-4.7-flash:q4_K_M", "laguna-xs-2.1:latest", "gpt-oss:20b",
          "gemma4:12b", "nemotron-3.5-lightning:30b", "gemma4:31b", "deepseek-r1:14b",
          "deepseek-r1:32b", "qwen3.8:latest", "granite4.2:30b", "laguna-xs.2:q4_K_M"]

house = L.HOUSE_SYSTEM
rows = []
for m in MODELS:
    body = {"model": m, "stream": False, "think": False,
            "messages": [{"role": "system", "content": house},
                         {"role": "user", "content": "Ответь одним словом: да"}],
            "options": {"num_ctx": NUM_CTX, "num_predict": 1, "seed": 42}}
    req = urllib.request.Request(OLLAMA + "/api/chat", data=json.dumps(body).encode("utf-8"),
                                 headers={"Content-Type": "application/json"})
    t0 = time.time()
    try:
        with urllib.request.urlopen(req, timeout=1800) as fh:
            n = int(json.load(fh).get("prompt_eval_count", 0))
        rec = {"model": m, "prompt_tokens": n, "prompt_chars": len(house),
               "tok_per_char": round(n / float(len(house)), 4),
               "budget": BUDGET, "headroom": BUDGET - n,
               "fits": bool(n <= BUDGET), "sec": round(time.time() - t0, 1)}
    except Exception as exc:                                   # noqa: BLE001
        rec = {"model": m, "error": str(exc)[:120]}
    rows.append(rec)
    with open(os.path.join(L.BASE, "prompt_tokens.json"), "w", encoding="utf-8") as fh:
        json.dump({"stamp": datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
                   "num_ctx": NUM_CTX, "budget": BUDGET,
                   "prompt_chars": len(house), "models": rows}, fh, ensure_ascii=False, indent=2)
print("DONE %d моделей -> %s" % (len(rows), os.path.join(L.BASE, "prompt_tokens.json")))