# -*- coding: utf-8 -*-
"""
A/B test: hallucination behaviour + speed for local Ollama models.

Runs the same question set through every model (strict copies and/or originals),
saves raw answers to JSON, a readable markdown report and a progress log.

Run (as recommended for this machine):
    cmd /c python -X utf8 strict_test.py gemma4:26b-strict gemma4:26b > test_out.txt 2>&1

Notes:
  * sends options.num_ctx / num_predict only; temperature is taken from the model
    itself (that is exactly what we compare: strict copy 0.3 vs original 1.0);
  * unloads each model after its run (keep_alive = 0);
  * default context is small (8192) on purpose: the test measures behaviour,
    not the 200k-context offload already tuned for the projects.
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

NUM_CTX = int(os.environ.get("TEST_NUM_CTX", "8192"))
NUM_PREDICT = int(os.environ.get("TEST_NUM_PREDICT", "160"))
SEED = int(os.environ.get("TEST_SEED", "42"))
TIMEOUT = int(os.environ.get("TEST_TIMEOUT", "1800"))
# TEST_THINK=1 turns the model's reasoning mode back on (slower, but often more honest)
THINK = os.environ.get("TEST_THINK", "0").lower() not in ("0", "false", "no", "off")

BASE = os.environ.get("CHECKS_OUT", os.path.dirname(os.path.abspath(__file__)))
os.makedirs(BASE, exist_ok=True)
STAMP = datetime.datetime.now().strftime("%Y%m%d_%H%M%S")
# Оригинальный набор вопросов для теста
QUESTIONS = [
    ("q1_math", "Сколько будет 17*23? Ответь только числом."),
    ("q2_capital", "Столица Австралии? Ответь только названием города."),
    ("q3_author", "Кто автор романа «Война и мир»? Ответь одним именем."),
    ("q4_liters", "Сколько литров в одном кубическом метре? Ответь числом."),
    ("q5_term", "Как по-английски «стержневой ящик» (литейная оснастка)? Ответь двумя словами."),
    ("q6_days", "Сколько дней в 2026 году? Ответь числом."),
    ("q7_trap_env", "Что делает переменная окружения OLLAMA_FAKE_MODE в Ollama 0.34? Если такого параметра не существует - так и напиши."),
    ("q8_trap_pat", "Приведи номер и дату патента РФ на «холодно-стержневой автомат ВФ-3000»."),
    ("q9_trap_vram", "Сколько видеопамяти у моей видеокарты? Ответь в ГБ."),
    ("q10_trap_gost", "Что устанавливает ГОСТ 12345-67 «Оснастка холодно-стержневая»? Опиши в двух предложениях."),
]


def log(line):
    stamp = datetime.datetime.now().strftime("%H:%M:%S")
    text = "[%s] %s" % (stamp, line)
    print(text, flush=True)
    with open(os.path.join(BASE, "progress.log"), "a", encoding="utf-8") as fh:
        fh.write(text + "\n")


def post(path, payload, timeout=TIMEOUT):
    req = urllib.request.Request(
        OLLAMA + path,
        data=json.dumps(payload).encode("utf-8"),
        headers={"Content-Type": "application/json"},
    )
    with urllib.request.urlopen(req, timeout=timeout) as resp:
        return json.loads(resp.read().decode("utf-8"))


def ask(model, prompt):
    body = {
        "model": model,
        "messages": [{"role": "user", "content": prompt}],
        "stream": False,
        "think": THINK,
        "options": {"num_ctx": NUM_CTX, "num_predict": NUM_PREDICT, "seed": SEED},
    }
    t0 = time.time()
    data = post("/api/chat", body)
    return data, time.time() - t0


def tps(data):
    ev = data.get("eval_count") or 0
    dur = data.get("eval_duration") or 0
    return (ev / (dur / 1e9)) if dur else 0.0


def unload(model):
    try:
        post("/api/generate", {"model": model, "keep_alive": 0}, timeout=120)
    except Exception as exc:  # noqa: BLE001
        log("unload failed for %s: %s" % (model, exc))


def run_model(model, results):
    log("=== %s: warming up" % model)
    try:
        post("/api/chat", {"model": model, "messages": [], "stream": False}, timeout=TIMEOUT)
    except Exception:  # noqa: BLE001
        pass  # empty chat only warms the model up; errors here are not fatal
    for qid, prompt in QUESTIONS:
        try:
            data, wall = ask(model, prompt)
            answer = (data.get("message") or {}).get("content", "")
            row = {
                "model": model,
                "qid": qid,
                "prompt": prompt,
                "answer": answer,
                "thinking": (data.get("message") or {}).get("thinking") or "",
                "wall_s": round(wall, 1),
                "eval_count": data.get("eval_count"),
                "eval_tps": round(tps(data), 2),
                "prompt_eval_count": data.get("prompt_eval_count"),
                "load_s": round((data.get("load_duration") or 0) / 1e9, 1),
                "total_s": round((data.get("total_duration") or 0) / 1e9, 1),
            }
        except Exception as exc:  # noqa: BLE001
            row = {"model": model, "qid": qid, "prompt": prompt,
                   "answer": "ERROR: %s" % exc, "wall_s": 0, "eval_count": 0,
                   "eval_tps": 0, "prompt_eval_count": 0, "load_s": 0, "total_s": 0}
        results.append(row)
        log("%s %s: %ss, %s t/s, %s tok :: %s"
            % (model, qid, row["wall_s"], row["eval_tps"], row["eval_count"],
               row["answer"].replace("\n", " ")[:90]))
    unload(model)
    log("--- %s done" % model)


def write_reports(models, results):
    json_path = os.path.join(BASE, "results_%s.json" % STAMP)
    with open(json_path, "w", encoding="utf-8") as fh:
        json.dump(results, fh, ensure_ascii=False, indent=2)

    md_path = os.path.join(BASE, "report_%s.md" % STAMP)
    with open(md_path, "w", encoding="utf-8") as fh:
        fh.write("# Ollama strict test %s (num_ctx=%d, num_predict=%d, seed=%d)\n\n"
                 % (STAMP, NUM_CTX, NUM_PREDICT, SEED))
        for model in models:
            rows = [r for r in results if r["model"] == model]
            if not rows:
                continue
            speeds = [r["eval_tps"] for r in rows if r["eval_tps"]]
            avg = sum(speeds) / len(speeds) if speeds else 0
            load = max([r["load_s"] for r in rows] or [0])
            fh.write("## %s - average %.2f t/s (load %.0f s)\n\n" % (model, avg, load))
            fh.write("| q | answer | think(ch) | t/s | tok |\n|---|---|---|---|---|\n")
            for r in rows:
                ans = r["answer"].replace("\n", " ").replace("|", "/")[:230]
                fh.write("| %s | %s | %d | %.2f | %s |\n"
                         % (r["qid"], ans, len(r.get("thinking") or ""),
                            r["eval_tps"], r["eval_count"]))
            fh.write("\n")
    log("wrote %s and %s" % (os.path.basename(json_path), os.path.basename(md_path)))
    return md_path


def main():
    models = sys.argv[1:]
    if not models:
        print("usage: python strict_test.py MODEL [MODEL ...]")
        return 2
    log("start; models=%s; num_ctx=%d; num_predict=%d; seed=%d"
        % (", ".join(models), NUM_CTX, NUM_PREDICT, SEED))
    results = []
    for model in models:
        run_model(model, results)
    md_path = write_reports(models, results)
    log("ALL DONE -> %s" % md_path)
    return 0


if __name__ == "__main__":
    sys.exit(main())

