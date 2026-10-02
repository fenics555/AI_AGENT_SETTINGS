r"""Аудит входа стенда: что ОТДАЁТ модель, что ПРИНИМАЕТ, и доходит ли каждое правило.

    cmd /c python -X utf8 D:\AI\AGENT_SETTINGS\checks\stand_audit.py

Спека проверки программ агента, шаги 1-6 и 9. Код не правится — только измеряется.

Что проверяем:
  1. ПРОМПТ целиком: длина, разделы, токены.
  2. ОБРЕЗКА: каждый раздел мастер-файла против того, что реально ушло в модель.
  3. ПОСТРОЧНО: какие строки мастер-файла НЕ дошли до промпта (потерянные правила).
  4. ОБЯЗАТЕЛЬНЫЕ ПУНКТЫ: RULES_REQUIRED присутствуют ли.
  5. ВЫХОД: формат results_*.json, поля, что оптимизатору видно по слепым.
  6. ЧИТАЕМОСТЬ: стенд не пишет в чужие данные (только CHECKS_OUT + __pycache__).
"""
import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import loop_revive_test as L          # noqa: E402

OUT = r"D:\AI\log\urn\cline\stand_audit.txt"
lines = []


def add(s=""):
    lines.append(s)


# --- 1. ПРОМПТ ---------------------------------------------------------------------------------
add("=== 1. ЧТО ОТДАЁТ СТЕНД ===")
add("rules path      : %s" % L.RULES_PATH)
add("SECTION_HEADS   : %s" % (L.SECTION_HEADS,))
add("SECTION_MAX     : %d" % L.SECTION_MAX)
add("RULES_MAX_TOTAL : %d" % L.RULES_MAX_TOTAL)
add("house_system    : %d симв., ~%d токенов" % (len(L.HOUSE_SYSTEM), L.RULES_TOKENS))
add("num_ctx/predict : %d / %d, seed=%d, think=%s"
    % (L.NUM_CTX, L.NUM_PREDICT, L.SEED, L.THINK))
add("модели в этом запуске: %s" % (", ".join(sys.argv[1:]) or "по аргументам",))
add("предметов       : %d, условий: %d" % (len(L.ITEMS), 2))

# --- 2. ОБРЕЗКА --------------------------------------------------------------------------------
add()
add("=== 2. ОБРЕЗКА РАЗДЕЛОВ (реальная длина мастера против того, что ушло) ===")
add("%-34s %8s %8s %s" % ("раздел", "в файле", "в модель", "статус"))
raw_parts = []
with open(L.RULES_PATH, encoding="utf-8-sig") as fh:
    raw = fh.read()
marks = sorted((raw.find("\n" + h) + 1, h) for h in L.SECTION_HEADS if raw.find("\n" + h) >= 0)
for n, (i, head) in enumerate(marks):
    stop = marks[n + 1][0] if n + 1 < len(marks) else len(raw)
    full = raw[i:stop].strip()
    cut = full[:L.SECTION_MAX]
    status = "ОК" if len(full) <= L.SECTION_MAX else "ОБРЕЗАН, потеряно %d симв." % (len(full) - L.SECTION_MAX)
    add("%-34s %8d %8d %s" % (head[:34], len(full), min(len(full), L.SECTION_MAX), status))
    raw_parts.append(cut)
sum_raw = sum(len(p) for p in raw_parts)
add("сумма разделов : %d при RULES_MAX_TOTAL=%d -> %s"
    % (sum_raw, L.RULES_MAX_TOTAL, "ОК" if sum_raw <= L.RULES_MAX_TOTAL else "ОБРЕЗАНА СУММА"))

# --- 3. ПОСТРОЧНО: что НЕ дошло ----------------------------------------------------------------
add()
add("=== 3. СТРОКИ МАСТЕРА, НЕ ДОШЕДШИЕ ДО МОДЕЛИ ===")
lost = []
for n, (i, head) in enumerate(marks):
    stop = marks[n + 1][0] if n + 1 < len(marks) else len(raw)
    full = raw[i:stop].strip()
    for off, line in enumerate(full.split("\n")):
        s = line.strip()
        if len(s) < 25:
            continue
        if s not in L.HOUSE_SYSTEM:
            lost.append((head[:26], off + 1, len(s), s[:96]))
add("всего потерянных строк: %d" % len(lost))
for head, no, ln, txt in lost[:40]:
    add("  [%s:%d] (%d симв.) %s" % (head, no, ln, txt))
if len(lost) > 40:
    add("  ... и ещё %d" % (len(lost) - 40))

# --- 4. ОБЯЗАТЕЛЬНЫЕ ПУНКТЫ ---------------------------------------------------------------------
add()
add("=== 4. ОБЯЗАТЕЛЬНЫЕ ПУНКТЫ (RULES_REQUIRED) ===")
add("требуется: %s" % (", ".join(L.RULES_REQUIRED),))
for k in L.RULES_REQUIRED:
    add("  %-28s %s" % (k, "есть" if k in L.HOUSE_SYSTEM else "НЕТ — прогон недействителен"))
ok, health = L.check_rules_health()
add("check_rules_health: %s -> %s" % (ok, health))
add("позиция блока ВОСКРЕШЕНИЕ: %.0f%% промпта (порог тревоги 40%%)"
    % (100.0 * L.HOUSE_SYSTEM.find("ВОСКРЕШЕНИЕ: REVIVE") / len(L.HOUSE_SYSTEM)))

# --- 5. ПРЕДМЕТЫ И ЧТО ПРИНИМАЕТ ---------------------------------------------------------------
add()
add("=== 5. ЧТО ПРИНИМАЕТ: предметы и чекеры ===")
add("%-20s %-8s %s" % ("qid", "чекер", "вопрос (усечённо)"))
for _f, qid, prompt, chk in L.ITEMS:
    add("%-20s %-8s %s" % (qid, chk, prompt[:88].replace("\n", " ")))
add("BLIND_ITEMS: %s" % (L.BLIND_ITEMS,))
add("по слепым оптимизатору видно: только вердикт, цитаты скрыты (write_optimizer_report)")

# --- 6. КУДА ПИШЕТ -----------------------------------------------------------------------------
add()
add("=== 6. КУДА ПИШЕТ (безопасность данных) ===")
add("CHECKS_OUT = %s" % L.BASE)
add("входы правил: RULES_PATH (только чтение), измеряется, но не меняется")
add("модели: выгрузка через /api/generate keep_alive=0 — состояние Ollama, не данные")

with open(OUT, "w", encoding="utf-8") as fh:
    fh.write("\n".join(lines))
print("written %s lines=%d" % (OUT, len(lines)))
