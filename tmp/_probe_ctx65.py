import subprocess, time, json

models = ["gpt-oss:20b", "gemma4:26b", "batiai/qwen3.6-35b:iq4", "laguna-xs-2.1:latest"]
out = []
for m in models:
    out.append("=" * 60)
    out.append("MODEL: " + m)
    # unload all first
    subprocess.run(["ollama", "stop", m], capture_output=True, text=True, timeout=60)
    time.sleep(3)
    body = json.dumps({
        "model": m,
        "messages": [{"role": "user", "content": "Скажи одно слово: OK"}],
        "stream": False,
        "options": {"num_ctx": 65536, "num_predict": 16},
    })
    t0 = time.time()
    try:
        p = subprocess.run(
            ["curl", "-s", "-X", "POST", "http://localhost:11434/api/chat",
             "-H", "Content-Type: application/json", "-d", body],
            capture_output=True, text=True, timeout=420)
        dt = round(time.time() - t0, 1)
        out.append("  answer_sec=" + str(dt))
        try:
            j = json.loads(p.stdout)
            msg = j.get("message", {}).get("content", "")
            out.append("  content_len=" + str(len(msg)))
            out.append("  done_reason=" + str(j.get("done_reason", "")))
            out.append("  eval_count=" + str(j.get("eval_count", "")))
        except Exception as e:
            out.append("  JSON ERR: " + str(e)[:100])
            out.append("  raw: " + p.stdout[:200])
    except subprocess.TimeoutExpired:
        out.append("  TIMEOUT > 420s")
    time.sleep(2)
    ps = subprocess.run(["ollama", "ps"], capture_output=True, text=True, timeout=60)
    out.append("  --- ollama ps ---")
    for line in ps.stdout.strip().splitlines():
        out.append("  " + line)
    subprocess.run(["ollama", "stop", m], capture_output=True, text=True, timeout=60)
    time.sleep(3)

txt = "\n".join(out)
print(txt)
with open(r"D:\AI\AGENT_SETTINGS\tmp\ctx65_probe.txt", "w", encoding="utf-8") as fh:
    fh.write(txt)
print("\nSAVED")
