r"""Полная таблица по ВСЕМ моделям из results_*.json.

    cmd /c python -X utf8 D:\AI\AGENT_SETTINGS\checks\all_models_table.py <results.json>

Одна итерация стенда = один файл результатов со всеми моделями. Таблица строится по нему:
  1) сводка house/plain по каждой модели + вердикт по критерию базы;
  2) матрица предметов x моделей (house) с классом ошибки;
  3) что видно оптимизатору по слепым (без цитат);
  4) блокировки: какие барьеры нарушены у каких моделей.
"""
import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import night_optimizer as N      # noqa: E402  (критерии оттуда, одна правда)

path = sys.argv[1]
with open(path, encoding="utf-8") as fh:
    rows = json.load(fh)
house, plain, order = {}, {}, []
qids = [q for _f, q, _p, _c in __import__("loop_revive_test").ITEMS]
for r in rows:
    m, q, c = r["model"], r["qid"], r.get("cond")
    if m not in order:
        order.append(m)
    store = house if c == "house" else plain if c == "plain" else None
    if store is None:
        continue
    store.setdefault(m, {})[q] = (r.get("verdict"), r.get("error_class", "?"), r.get("blind", False))

out = []
add = out.append
add("=== ПОЛНАЯ ТАБЛИЦА: все модели одной итерацией ===")
add("источник: %s" % os.path.basename(path))
add("база сравнения: 26b 15, glm 10, laguna 9 при chars=%d" % N.BASE_CHARS)
add("моделей в прогоне: %d, предметов: %d" % (len(order), len(qids)))

add("")
add("--- 1. СВОДКА ---")
add("база сравнения есть только у трёх моделей; для остальных вердикт = «нет базы»")
add("%-30s %9s %9s %14s %s" % ("модель", "house", "plain", "к базе", "провалы house"))
for m in order:
    h = house.get(m, {})
    p = plain.get(m, {})
    hp = sum(1 for v in h.values() if v[0] == "PASS")
    pp = sum(1 for v in p.values() if v[0] == "PASS")
    fails = ", ".join("%s[%s]" % (q, h[q][1]) for q in qids if q in h and h[q][0] != "PASS")
    base = N.BASE.get(m)
    if base is None:
        cmp_txt = "нет базы"
    elif hp >= base:
        cmp_txt = "выше/равно %d" % base
    else:
        cmp_txt = "НИЖЕ базы %d" % base
    add("%-30s %4d/%-4d %4d/%-4d %14s %s" % (m, hp, len(h), pp, len(p), cmp_txt, fails or "-"))

add("")
add("--- 2. МАТРИЦА ПРЕДМЕТОВ (house): P=pass, иначе класс в скобках ---")
add("%-20s %s" % ("предмет", " ".join("%-6s" % m.split(":")[0][:6] for m in order)))
for q in qids:
    cells = []
    for m in order:
        v = house.get(m, {}).get(q)
        cells.append("%-6s" % ("-" if not v else "P" if v[0] == "PASS" else v[1]))
    add("%-20s %s" % (q, " ".join(cells)))

add("")
add("--- 3. СЛЕПЫЕ ПРЕДМЕТЫ (оптимизатор видит только это) ---")
add("%-30s %s" % ("модель", " ".join("%-18s" % q for q in N.BLIND_ITEMS)))
for m in order:
    cells = []
    for q in N.BLIND_ITEMS:
        v = house.get(m, {}).get(q)
        base = N.BASE_BLIND.get((m, q), "PASS")
        if not v:
            cells.append("%-18s" % "-")
        elif v[0] == "PASS":
            cells.append("%-18s" % "PASS")
        else:
            cells.append("%-18s" % ("FAIL (в базе %s)" % base))
    add("%-30s %s" % (m, " ".join(cells)))

add("")
add("--- 4. БАРЬЕРЫ КРИТЕРИЯ ПО МОДЕЛЯМ ---")
for m in order:
    h = house.get(m, {})
    hp = sum(1 for v in h.values() if v[0] == "PASS")
    base = N.BASE.get(m)
    bad = []
    if base is None:
        bad.append("нет базовой цифры — критерий неприменим (сравнивать не с чем)")
    elif hp < base:
        bad.append("%d/%d < базы %d" % (hp, len(h), base))
    for q, v in h.items():
        if v[0] != "PASS" and v[2] and N.BASE_BLIND.get((m, q), "PASS") == "PASS":
            bad.append("слепой %s не прошёл (в базе PASS)" % q)
    add("%-30s %s" % (m, "; ".join(bad) if bad else "барьеров нет"))

add("")
add("--- 6. ТОКЕНЫ И ВРЕМЯ (house) ---")
add("prompt_tokens — сколько токенов Ollama посчитал в ПРОМПТЕ (проверка окна);")
add("tokens — токены ответа; tps — скорость генерации; wall_s — время на предмет.")
add("%-30s %12s %10s %8s %9s %10s %9s"
    % ("модель", "prompt_tok", "ans_tok", "t/s", "время, с", "на предм.", "в окне"))
budget = 8192 - 260 - 400
for m in order:
    rows_m = [r for r in rows if r["model"] == m and r.get("cond") == "house"]
    if not rows_m:
        continue
    pt = [r.get("prompt_tokens") for r in rows_m if r.get("prompt_tokens")]
    at = sum(r.get("tokens") or 0 for r in rows_m)
    tps = [r.get("tps") or 0 for r in rows_m]
    wall = sum(r.get("wall_s") or 0 for r in rows_m)
    n = len(rows_m)
    ptxt = str(pt[0]) if pt else "нет в json"
    if pt:
        fits = "да" if max(pt) <= budget else "НЕТ (+%d)" % (max(pt) - budget)
    else:
        fits = "проверить серией"
    add("%-30s %12s %10d %8.1f %9.1f %10.1f %9s"
        % (m, ptxt, at, (sum(tps) / len(tps)) if tps else 0, wall, wall / float(n), fits))
add("")
add("бюджет под промпт: num_ctx %d − ответ 260 − запас 400 = %d токенов" % (8192, budget))

dest = os.path.splitext(path)[0] + "_TABLE.md"
with open(dest, "w", encoding="utf-8") as fh:
    fh.write("\n".join(out))
print("OK -> %s (%d lines)" % (dest, len(out)))
