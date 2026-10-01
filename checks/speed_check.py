# -*- coding: utf-8 -*-
"""
Speed check: same prompt + big context + long generation, original vs -strict copy.
Proves that changing sampling parameters does not change speed (offload / MTP intact).

Usage:
    cmd /c python -X utf8 speed_check.py gemma4:26b gemma4:26b-strict > speed_out.txt 2>&1

Env: SPEED_NUM_CTX (default 202752), SPEED_NUM_PREDICT (default 400), SPEED_PROMPT
"""

import datetime
import json
import os
import sys
import time
import urllib.request

OLLAMA = os.environ.get("OLLAMA_HOST", "127.0.0.1:11434")
if not OLLAMA.startswith("http"):
    OLLAMA = "http://" + OLLAMA

NUM_CTX = int(os.environ.get("SPEED_NUM_CTX", "202752"))
NUM_PREDICT = int(os.environ.get("SPEED_NUM_PREDICT", "400"))
PROMPT = os.environ.get(
    "SPEED_PROMPT",
    "Напиши связный текст примерно на 400 слов о литейной оснастке: стержневые ящики, "
    "холодно-стержневая смесь, газопроницаемость, дефекты стержней. Без списков, без заголовков.",
)

BASE = os.environ.get("CHECKS_OUT", os.path.dirname(os.path.abspath(__file__)))
os.makedirs(BASE, exist_ok=True)
STAMP = datetime.datetime.now().strftime("%Y%m%d_%H%M%S")


def post(path, payload, timeout=3600):
    req = urllib.request.Request(
        OLLAMA + path,
        data=json.dumps(payload).encode("utf-8"),
        headers={"Content-Type": "application/json"},
    )
    with urllib.request.urlopen(req, timeout=timeout) as resp:
        return json.loads(resp.read().decode("utf-8"))


def tps(count, duration):
    return (count / (duration / 1e9)) if duration else 0.0


def main():
    models = sys.argv[1:]
    if not models:
        print("usage: python speed_check.py MODEL [MODEL ...]")
        return 2

    rows = []
    for model in models:
        print("=== %s (num_ctx=%d, num_predict=%d)" % (model, NUM_CTX, NUM_PREDICT), flush=True)
        body = {
            "model": model,
            "messages": [{"role": "user", "content": PROMPT}],
            "stream": False,
            "think": False,
            "options": {"num_ctx": NUM_CTX, "num_predict": NUM_PREDICT, "temperature": 0.3},
        }
        t0 = time.time()
        try:
            data = post("/api/chat", body)
            wall = time.time() - t0
            row = {
                "model": model,
                "num_ctx": NUM_CTX,
                "wall_s": round(wall, 1),
                "load_s": round((data.get("load_duration") or 0) / 1e9, 1),
                "prompt_tokens": data.get("prompt_eval_count"),
                "prompt_tps": round(tps(data.get("prompt_eval_count") or 0,
                                        data.get("prompt_eval_duration") or 0), 1),
                "gen_tokens": data.get("eval_count"),
                "gen_tps": round(tps(data.get("eval_count") or 0,
                                     data.get("eval_duration") or 0), 2),
                "answer_chars": len((data.get("message") or {}).get("content") or ""),
            }
        except Exception as exc:  # noqa: BLE001
            row = {"model": model, "num_ctx": NUM_CTX, "wall_s": 0, "load_s": 0,
                   "prompt_tokens": 0, "prompt_tps": 0, "gen_tokens": 0,
                   "gen_tps": 0, "answer_chars": 0, "error": str(exc)}
        rows.append(row)
        print(json.dumps(row, ensure_ascii=False), flush=True)
        try:
            post("/api/generate", {"model": model, "keep_alive": 0}, timeout=120)
        except Exception:  # noqa: BLE001
            pass

    path = os.path.join(BASE, "speed_%s.json" % STAMP)
    with open(path, "w", encoding="utf-8") as fh:
        json.dump(rows, fh, ensure_ascii=False, indent=2)
    print("wrote %s" % path, flush=True)
    return 0


if __name__ == "__main__":
    sys.exit(main())
