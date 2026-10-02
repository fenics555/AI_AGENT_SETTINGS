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
    store = house if c == "house" else plain if c == "plain" else None
    if store is None:
        continue
    if m not in store:
        store[m] = {}
        order.append(m)
    store[m][q] = (r.get("verdict"), r.get("error_class", "?"), r.get("blind", False))

out = []
add = out.append
add("=== ПОЛНАЯ ТАБЛИЦА: все модели одной итерацией ===")
add("источник: %s" % os.path.basename(path))
add("база сравнения: 26b 15, glm 10, laguna 9 при chars=%d" % N.BASE_CHARS)
add("моделей в прогоне: %d, предметов: %d" % (len(order), len(qids)))

add("")
add("--- 1. СВОДКА ---")
add("%-30s %9s %9s %8s %s" % ("модель", "house", "plain", "verdict", "провалы house"))
for m in order:
    h = house.get(m, {})
    p = plain.get(m, {})
    hp = sum(1 for v in h.values() if v[0] == "PASS")
    pp = sum(1 for v in p.values() if v[0] == "PASS")
    fails = ", ".join("%s[%s]" % (q, h[q][1]) for q in qids if q in h and h[q][0] != "PASS")
    ok = hp >= N.BASE.get(m, 0)
    add("%-30s %4d/%-4d %4d/%-4d %8s %s"
        % (m, hp, len(h), pp, len(p), "PASS" if ok else "ниже базы", fails or "-"))

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
add("--- 5. ВХОД ПРОГОНА (обязателен в таблице) ---")
for r in rows[:1]:
    add("rules: %s" % r.get("rules_file", r.get("rules", "не записано в json")))
    add("chars=%s tokens=%s" % (r.get("rules_chars", "?"), r.get("rules_tokens", "?")))

dest = os.path.splitext(path)[0] + "_TABLE.md"
with open(dest, "w", encoding="utf-8") as fh:
    fh.write("\n".join(out))
print("OK -> %s (%d lines)" % (dest, len(out)))
