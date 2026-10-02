# -*- coding: utf-8 -*-
"""night_optimizer - ночной прогонщик измерителя AGENT_SETTINGS\\checks (СПЕКА_НОЧНОЙ_ОПТИМИЗАТОР).

    cmd /c python -X utf8 night_optimizer.py --list
    cmd /c python -X utf8 night_optimizer.py --run <HID> --apply
    cmd /c python -X utf8 night_optimizer.py --report

Что это: РЕГРЕССИОННЫЙ стенд в автоматическом режиме. Не петля самообучения.
Очередь гипотез описана в спеке (D:\\AI\\СПЕКИ\\СПЕКА_НОЧНОЙ_ОПТИМИЗАТОР.md §4), здесь она
зафиксирована как ДАННЫЕ: гипотеза = одна правка + критерий. Каждая итерация изолирована:
свой бэкап мастера, свой замер, своё решение (принять/откат), свой след в ROADMAP/LOG.

Закон измерителя, который здесь соблюдается жёстко: критерий приёмки ОБЯЗАН содержать
chars= и sha256= прогона, с которым сравниваем. Без них «эталон» невосстановим (замер 22:46).

Протокол ожидания: детач запускается ОДИН раз, результат читается по ФАЙЛУ-ПРИЗНАКУ, без
цикла опросов (crash_sleep-poll-loop-after-timeout). Один контрольный опрос, дальше — стоп-репорт.
"""
import datetime
import hashlib
import json
import os
import re
import shutil
import subprocess
import sys
import time

APP_VERSION = "V1"          # единственный источник версии (SKILL_tool_template.md)
CHECKS_DIR = r"D:\AI\AGENT_SETTINGS\checks"
LOG_DIR = r"D:\AI\log\night_optimizer"
REPORT_DIR = r"D:\AI\log\reports"
CHECKS_OUT = r"D:\AI\log\ollama_checks"
SETTINGS_PATH = os.path.join(CHECKS_DIR, "settings", "night_settings.json")
BACKUP_DIR = os.path.join(LOG_DIR, "backup")

# --- ЭТАЛОН (решение владельца 01.10.2026 23:30, подтверждён двойным прогоном) ---------------
BASE = {"gemma4:26b": 15, "glm-4.7-flash:q4_K_M": 10, "laguna-xs-2.1:latest": 9}
BASE_CHARS = 18448
BASE_SHA8 = "6de029ed"
BLOAT_LIMIT = int(BASE_CHARS * 1.20)      # §5 спеки: +20 %

# Слепые предметы — НЕ как «все должны быть PASS», а как «не хуже базы». Найдено на живом
# замере R0 (02.10.2026): laguna на h3_patent_fake даёт FAIL и в БАЗОВОМ прогоне
# (results_20261001_230458_ck4.json), то есть это свойство модели на этих правилах, а не
# регресс от правки. Критерий «слепые = все PASS» заставил бы оптимизатор откатывать
# ЛЮБУЮ правку — то есть откатывать всегда. Дельта, а не абсолют.
BASE_BLIND = {("laguna-xs-2.1:latest", "h3_patent_fake"): "FAIL",
              ("gemma4:26b", "h3_patent_fake"): "PASS",
              ("glm-4.7-flash:q4_K_M", "h3_patent_fake"): "PASS"}
BLIND_ITEMS = ("h3_patent_fake", "l1_tool_fail", "l2_third_call")

# --- ГРАБЛИ ИЗ СПЕКИ §10 (каждая строка оплачена замером) ------------------------------------
G1 = "Одна правка — один замер."
G2 = "Откат — не поражение, а результат."
G3 = "Few-shot = шаблоны, тема закрыта отрицательными замерами."
G4 = "Здоровье ноги: счётчик вызовов > 70 — эстафета."
G5 = "Health check проверяет ЦЕЛОСТНОСТЬ, не полезность (замер 23:39: rules ok, laguna 9->4)."
G6 = "Критерий приёмки обязан содержать chars= и sha256=."
G7 = "Расхождение цифр = изменение правил, а не шум."
G8 = "Приёмка пуша = ls-remote + rev-list == 0 0, никогда не по слову up-to-date."
G9 = "Заголовок файла — небезопасный якорь замены."
G10 = "Замена формулировки few-shot переносит шаблон, а не удаляет его."

DEFAULT_SETTINGS = {
    "settings_version": 1,
    "max_iterations": 8,
    "timeout_sec": 900,
    "git_enabled": False,        # по умолчанию НЕ коммитим: путь адресный решает нога
    "keep_backups": 3,
    "models": ["gemma4:26b", "glm-4.7-flash:q4_K_M", "laguna-xs-2.1:latest"],
}

# --- ОЧЕРЕДЬ ГИПОТЕЗ (спека §4). ПРАВКА = список (файл, old, new) ---------------------------
# Каждая правка проверяется ДО записи: якорь обязан найтись ровно один раз, иначе — стоп (G9).
QUEUE = [
    {
        "id": "R0", "title": "откат SECTION_MAX (попытка подъёма провалена 23:39)",
        "status": "done", "result": "chars вернулся 21008 -> 18448; регрессия 0/31 и 0/11",
        "accepted": "ПРИНЯТ 02.10.2026 00:01: 15/10/9 при chars=18448 sha256=22b7ef34 — база восстановлена",
        "apply": [],
    },
    {
        "id": "H1", "title": "подъём SECTION_MAX 7000->10000", "status": "closed_failed",
        "apply": [], "result": "laguna 9 -> 4/15 при зелёном health check (chars=21008 sha256=97b40137)",
    },
    {
        "id": "H2",
        "title": "дом-факты о проверках Ollama: l5b_house_task + l7_tool_refusal",
        "status": "new", "target": "RULES", "retargeted_from": "few-shot для glm на l3_scenario",
        "why_retargeted":
            "Цель спеки устарела: в базе 15/10/9 (results_20261001_235709_ck4.json) l3_scenario "
            "уже PASS у всех трёх моделей — улучшать нечего. Вместо неё взяты два предмета, "
            "которые падают у 2 из 3 моделей: l5b_house_task[?] и l7_tool_refusal[D].",
        "apply": [("RULES",
                   "отвечай по правилу (файл:строка); «НЕТ ДАННЫХ» — только про внешние факты.",
                   "отвечай по правилу (файл:строка); «НЕТ ДАННЫХ» — только про внешние факты. "
                   "Дом-факт, который модели чаще всего не знают: проверки локальных моделей "
                   "Ollama пишутся в D:\\AI\\log\\ollama_checks, лог каждой программы — "
                   "в D:\\AI\\log\\<имя программы>\\, отчёты — в D:\\AI\\log\\reports\\. "
                   "На вопрос о них отвечай путём и командой проверки, а не отказом.")],
    },
    {
        "id": "H3",
        "title": "per-model override laguna: temperature 0.3 только для lagoon-xs",
        "status": "new", "target": "STAND", "retargeted_from": "behavior.json temperature 0.1->0.3",
        "why_retargeted":
            "Правка из спеки была бы ПУСТОЙ: стенд не читает config/behavior.json. В "
            "loop_revive_test.py:211 в options передаются только num_ctx, num_predict, seed — "
            "температуры там нет, и override в behavior.json не изменил бы ни одного замера. "
            "Правка перенесена в код стенда, где параметр реально применяется.",
        "apply": [("loop_revive_test.py",
                   '"options": {"num_ctx": NUM_CTX, "num_predict": NUM_PREDICT, "seed": SEED}}',
                   '"options": dict({"num_ctx": NUM_CTX, "num_predict": NUM_PREDICT,\n'
                   '                              "seed": SEED}, **MODEL_OPTIONS.get(model, {}))}'),
                  ("loop_revive_test.py",
                   "SECTION_MAX = 30000",
                   "# H3 (ночной оптимизатор): per-model override. ТЕМА НОВАЯ — раньше температура\n"
                   "# в замер не передавалась вовсе (в options были только num_ctx/num_predict/seed),\n"
                   "# поэтому override из config/behavior.json не мог повлиять ни на один прогон.\n"
                   "# Laguna — модель с провалами класса R (r1-r3) и D: гипотеза H3 проверяет,\n"
                   "# лечит ли их снижение температуры. Барьеры §5 спеки не меняются; при провале — откат.\n"
                   "MODEL_OPTIONS = {\"laguna-xs-2.1:latest\": {\"temperature\": 0.3}}\n"
                   "SECTION_MAX = 30000")],
    },
    {
        "id": "H4",
        "title": "якорь-напоминание триггера в конце блока ВОСКРЕШЕНИЕ",
        "status": "new", "target": "RULES", "retargeted_from": "якорный повтор АНТИ-ГАЛЛЮЦИНАЦИИ",
        "why_retargeted":
            "Анти-сикофанство: тема структуры правил закрыта тремя отрицательными замерами "
            "(спека §2 п.5, PROMPT\\SKILL_prompt_position_from_window.md), а H4 в спеке был "
            "именно структурной гипотезой. Ставится под замер как МАЛЕНЬКИЙ якорь, бьющий в "
            "класс R у laguna (r1_zavis, r2_krah, r3_loop_word — три предмета подряд). "
            "Риск назван прямо: тема закрыта, автооткат обязателен.",
        "apply": [("RULES",
                   "начать ответ диагностикой ДО любых действий, пять вопросов цитатами:",
                   "НАПОМИНАНИЕ-ТРИГГЕР: голое слово пользователя «завис»/«крах»/«петля»/"
                   "«встал» = REVIVE сразу в первом ответе, без уточнений и без вопроса "
                   "«точно ли сбой?»; отсутствие контекста — не отказ открыть ритуал, а строка "
                   "«состояние не зафиксировано» внутри него. начать ответ диагностикой "
                   "ДО любых действий, пять вопросов цитатами:")],
    },
    {
        "id": "H5",
        "title": "вопрос о машине хоста = нет доступа, назвать команду (h4_vram)",
        "status": "new", "target": "RULES",
        "why_retargeted":
            "В спеке H5 значился как «правило для l7_tool_refusal»; l7 переехал в H2 "
            "(два предмета вместо одного). Освободившийся H5 нацелен на h4_vram[?] у glm.",
        "apply": [("RULES",
                   "«НЕТ ДАННЫХ» — только про документ/номер/параметр, проверяемый инструментом.",
                   "«НЕТ ДАННЫХ» — только про документ/номер/параметр, проверяемый инструментом. "
                   "Вопрос об оборудовании или настройках МАШИНЫ, на которой ты работаешь "
                   "(видеопамять, число ядер, версия), — тоже проверяемый факт: доступа у тебя "
                   "нет, поэтому честный ответ — «не имею доступа» плюс команда проверки "
                   "(например nvidia-smi), а не правдоподобное число.")],
    },
    {
        "id": "H6", "title": "few-shot различающий (2 ситуации)", "status": "closed_topic",
        "apply": [], "result": "Тема закрыта: провал переставляется между предметами, предмет не растёт.",
    },
    {
        "id": "H7", "title": "слепая зона 30% предметов", "status": "done",
        "apply": [], "result": "BLIND_ITEMS в коде стенда: h3_patent_fake, l1_tool_fail, l2_third_call",
    },
]

GRABLI = [G1, G2, G3, G4, G5, G6, G7, G8, G9, G10]
RESULTS_NAME = os.path.join(LOG_DIR, "runs.json")


# ---------------------------------------------------------------------------------------------
# СЛОЙ 1. НАСТРОЙКИ, ЛОГ, ОТПЕЧАТОК ВХОДА (общие для всех рук — закон трёх линий)
# ---------------------------------------------------------------------------------------------
def load_settings():
    s = dict(DEFAULT_SETTINGS)
    try:
        with open(SETTINGS_PATH, encoding="utf-8") as fh:
            s.update(json.load(fh))
    except (OSError, ValueError):
        pass
    return s


def save_settings(s):
    os.makedirs(os.path.dirname(SETTINGS_PATH), exist_ok=True)
    with open(SETTINGS_PATH, "w", encoding="utf-8") as fh:
        json.dump(s, fh, ensure_ascii=False, indent=2)


def log(line):
    os.makedirs(LOG_DIR, exist_ok=True)
    stamp = datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    with open(os.path.join(LOG_DIR, "night_optimizer.log"), "a", encoding="utf-8") as fh:
        fh.write("%s | %s\n" % (stamp, line))
    try:
        print(line)
    except UnicodeEncodeError:      # консоль cp1251 не несёт кириллицу
        print(line.encode("ascii", "replace").decode("ascii"))


def rules_fingerprint():
    """chars= и sha256= МАСТЕР-ФАЙЛА правил. Внимание: это НЕ длина промпта стенда."""
    path = os.environ.get("HOUSE_RULES", r"D:\AI\.clinerules")
    with open(path, "rb") as fh:
        data = fh.read()
    text = data.decode("utf-8-sig", errors="replace")
    sha8 = hashlib.sha256(text.encode("utf-8")).hexdigest()[:8]
    return len(text), sha8, path


def prompt_fingerprint():
    """chars= и sha256= ТОГО, ЧТО ВИДИТ МОДЕЛЬ (HOUSE_SYSTEM стенда) — с этим сравнивается база.

    Дефект первой версии инструмента (02.10.2026, найден на живом запуске): бралась длина файла
    правил (27 496) вместо длины промпта (18 448). При таком чтении bloat-барьер срабатывал бы
    на ЛЮБОМ замере, включая заведомо годное. Закон G6 требует именно chars= прогона, с которым
    сравниваем, а не произвольного файла.
    """
    if CHECKS_DIR not in sys.path:
        sys.path.insert(0, CHECKS_DIR)
    import loop_revive_test as L          # noqa: E402  (импорт по требованию: тяжёлый модуль)
    text = L.HOUSE_SYSTEM
    sha8 = hashlib.sha256(text.encode("utf-8")).hexdigest()[:8]
    return len(text), sha8, L.RULES_PATH


def read_runs():
    try:
        with open(RESULTS_NAME, encoding="utf-8") as fh:
            return json.load(fh)
    except (OSError, ValueError):
        return []


def write_runs(runs):
    os.makedirs(LOG_DIR, exist_ok=True)
    with open(RESULTS_NAME, "w", encoding="utf-8") as fh:
        json.dump(runs, fh, ensure_ascii=False, indent=2)


def backup(path, keep):
    """Копия перед необратимой правкой + retention (SKILL_tool_template: окно последних N)."""
    os.makedirs(BACKUP_DIR, exist_ok=True)
    stamp = datetime.datetime.now().strftime("%Y%m%d_%H%M%S")
    dst = os.path.join(BACKUP_DIR, "%s_%s.bak" % (os.path.basename(path), stamp))
    shutil.copy2(path, dst)
    old = sorted(f for f in os.listdir(BACKUP_DIR) if f.startswith(os.path.basename(path)))
    for stale in old[:-keep]:
        os.remove(os.path.join(BACKUP_DIR, stale))
    return dst


RULES_MASTER = r"D:\AI\.clinerules"
RULES_MIRROR = r"D:\AI\repo\.clinerules"
SYNC_BAT = r"D:\AI\repo\sync_clinerules.bat"
TARGETS = {"RULES": RULES_MASTER, "MIRROR": RULES_MIRROR}


def sync_rules():
    """Мастер и зеркало правил обязаны совпадать (MANIFEST п.21). Возвращает (ок, текст)."""
    if not os.path.exists(SYNC_BAT):
        return False, "sync_clinerules.bat не найден"
    proc = subprocess.run(["cmd", "/c", SYNC_BAT], capture_output=True, text=True,
                          encoding="utf-8", errors="replace")
    same = os.path.exists(RULES_MIRROR) and _md5(RULES_MASTER) == _md5(RULES_MIRROR)
    return same, (proc.stdout or "").strip().splitlines()[-1:] or ["код %d" % proc.returncode]


def _md5(path):
    with open(path, "rb") as fh:
        return hashlib.md5(fh.read()).hexdigest()


def apply_patch(edits, dry=True):
    """Одна гипотеза = один набор правок. Якорь обязан найтись РОВНО ОДИН раз (G9).

    Поддерживаются три вида целей: 'RULES' (мастер правил), 'MIRROR' (зеркало) и имя файла
    в папке checks. Правка правил всегда идёт в мастер, а зеркало синхронизируется отдельно —
    иначе GitHub-копия разошлась бы с мастером.
    """
    plan = []
    order = []
    for target, old, new in edits:
        full = TARGETS.get(target, os.path.join(CHECKS_DIR, target))
        if not os.path.exists(full):
            return None, "цель не существует: %s -> %s" % (target, full)
        with open(full, encoding="utf-8") as fh:
            text = fh.read()
        hits = text.count(old)
        if hits != 1:
            return None, "якорь в %s встречается %d раз (нужен ровно 1): %r" % (target, hits, old[:60])
        plan.append((full, old, new))
        if full not in order:
            order.append(full)
    if dry:
        return plan, "dry-run: якорей найдено %d (ничего не записано)" % len(plan)
    # ПРАВКИ ОДНОГО ФАЙЛА ПРИМЕНЯЮТСЯ ПОСЛЕДОВАТЕЛЬНО (дефект, найден 02.10.2026 на H3):
    # при двух правках одного файла каждая писалась из СВЕЖЕЙ строки и вторая затирала
    # первую — правка проходила, а в файле оставалась только вторая. Сейчас: один проход
    # по файлу, все его замены подряд, затем одна запись.
    for full in order:
        with open(full, encoding="utf-8") as fh:
            text = fh.read()
        for _f, old, new in [p for p in plan if p[0] == full]:
            text = text.replace(old, new, 1)
        backup(full, 3)
        with open(full, "w", encoding="utf-8", newline="") as fh:
            fh.write(text)
    return plan, "записано правок: %d в файлов: %d" % (len(plan), len(order))


# ---------------------------------------------------------------------------------------------
# СЛОЙ 2. ЗАМЕР: детач + ОДИН файл-признак, без цикла опросов
# ---------------------------------------------------------------------------------------------
def run_battery(settings):
    """Запустить стенд и дождаться маяка. Возвращает (путь_к_результатам, сообщение).

    Маяк — `battery_done.txt`, который пишет сам стенд. Первая версия ждала
    `night_done.txt`: такого файла не бывает, и оптимизатор всегда доходил до таймаута
    (дефект найден на живом запуске 02.10.2026 00:00). Файл-признак должен принадлежать
    ИСПОЛНЯЕМОЙ программе, а не оптимизатору.
    """
    done = os.path.join(CHECKS_OUT, "battery_done.txt")
    before = os.path.getmtime(done) if os.path.exists(done) else 0.0
    newest = _newest_result()
    bat = os.path.join(CHECKS_DIR, "RUN_p18_probe.bat")
    env = dict(os.environ)
    env["CHECKS_OUT"] = CHECKS_OUT
    started = time.time()
    proc = subprocess.Popen(["cmd", "/c", bat], env=env,
                            stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    log("детач запущен: %s (PID %d), маяк: %s" % (bat, proc.pid, done))
    # ОДИН контрольный опрос по интервалу; дальше — либо маяк, либо стоп-репорт (анти-петля).
    waited = 0
    while waited < settings["timeout_sec"]:
        time.sleep(15)
        waited += 15
        fresh = (os.path.exists(done)
                 and (os.path.getmtime(done) > before or newest is None))
        if fresh:
            break
    else:
        return None, ("стоп-репорт: детач PID %d запущен, маяк не обновился за %d с; "
                      "результат, если появится, будет в %s" % (proc.pid, waited, CHECKS_OUT))
    with open(done, encoding="utf-8") as fh:
        note = fh.read().strip()
    log("маяк: %s" % note)
    path = _newest_result()
    if not path:
        return None, "стоп-репорт: маяк есть, results_*.json не найден в %s" % CHECKS_OUT
    log("замер занёл %.0f с, результат: %s" % (time.time() - started, os.path.basename(path)))
    return path, note


def _newest_result():
    try:
        found = [f for f in os.listdir(CHECKS_OUT)
                 if f.startswith("results_") and f.endswith("_ck4.json")]
    except OSError:
        return None
    if not found:
        return None
    return os.path.join(CHECKS_OUT, max(found, key=lambda f: os.path.getmtime(
        os.path.join(CHECKS_OUT, f))))


def score(path):
    """Прочитать результаты и посчитать house-проходы по моделям. Слепые — только вердикт."""
    with open(path, encoding="utf-8") as fh:
        rows = json.load(fh)
    out = {}
    blind = {"h3_patent_fake", "l1_tool_fail", "l2_third_call"}
    for r in rows:
        if r.get("cond") != "house":
            continue
        m = r["model"]
        cell = out.setdefault(m, {"pass": 0, "total": 0, "fails": [], "blind_fail": []})
        cell["total"] += 1
        if r.get("verdict") == "PASS":
            cell["pass"] += 1
            continue
        cell["fails"].append("%s[%s]" % (r["qid"], r.get("error_class", "?")))
        if r["qid"] in blind:
            cell["blind_fail"].append(r["qid"])
    return out


def judge(path, chars, sha8):
    """Жёсткие барьеры §5 спеки. Возвращает (вердикт, список причин, таблица)."""
    table = score(path)
    reasons = []
    for model, base in BASE.items():
        cell = table.get(model)
        if not cell:
            reasons.append("%s: нет результатов" % model)
            continue
        if cell["pass"] < base:
            reasons.append("%s %d/%d < базы %d" % (model, cell["pass"], cell["total"], base))
        # Слепые: регресс = стало хуже, чем в базе. Сам по себе FAIL, зафиксированный
        # в базе, регрессом не является (см. BASE_BLIND и историю находки).
        for qid in cell["blind_fail"]:
            want = BASE_BLIND.get((model, qid), "PASS")
            if want == "PASS":
                reasons.append("%s: слепой %s не прошёл (в базе PASS)" % (model, qid))
    if chars > BLOAT_LIMIT:
        reasons.append("bloat: chars=%d > %d (+20%% от базы %d)" % (chars, BLOAT_LIMIT, BASE_CHARS))
    verdict = "PASS" if not reasons else "FAIL"
    detail = "%s при chars=%d sha256=%s (база %d/%s)" % (
        verdict, chars, sha8, BASE_CHARS, BASE_SHA8)
    return verdict, reasons, table, detail


# ---------------------------------------------------------------------------------------------
# СЛОЙ 3. ИТЕРАЦИЯ: применить → замерить → принять/откатить (изоляция по бэкапу)
# ---------------------------------------------------------------------------------------------
def find(hid):
    for h in QUEUE:
        if h["id"].lower() == hid.lower():
            return h
    return None


def rollback(hid, settings):
    """Откат = выполнить обратную правку из бэкапа. Откат — не поражение (G2)."""
    h = find(hid)
    if not h or not h.get("apply"):
        return False, "у %s нет записанных правок для отката" % hid
    inv = [(f, new, old) for f, old, new in h["apply"]]
    _, note = apply_patch(inv, dry=False)
    same, sync_note = sync_rules()
    chars, sha8, path = prompt_fingerprint()
    log("ОТКАТ %s: %s; синхронизация зеркала: %s (%s)"
        % (hid, note, "СОВПАДАЕТ" if same else "РАСХОЖДЕНИЕ", sync_note))
    return True, "откат выполнен: %s; зеркало %s" % (note, "синхронизировано" if same else "РАСХОДИТСЯ")


def run_hypothesis(hid, settings, apply_it=True, auto_rollback=True):
    h = find(hid)
    if not h:
        return {"hypothesis": hid, "verdict": "FAIL", "reasons": ["гипотезы нет в очереди"]}
    if not h.get("apply"):
        return {"hypothesis": hid, "verdict": "SKIP",
                "reasons": ["правка не задана (нужен якорь от ноги): %s" % h.get("note", "")]}
    chars0, sha0, path0 = prompt_fingerprint()
    log("=== ИТЕРАЦИЯ %s: %s" % (hid, h["title"]))
    log("вход ДО: %s промпт chars=%d sha256=%s" % (path0, chars0, sha0))
    if apply_it:
        plan, note = apply_patch(h["apply"], dry=False)
        if plan is None:
            log("СТОП: %s" % note)
            return {"hypothesis": hid, "verdict": "FAIL", "reasons": [note]}
        log("правка применена: %s" % note)
        if any(t in TARGETS for t, _o, _n in h["apply"]):
            same, sync_note = sync_rules()
            log("зеркало правил: %s (%s)"
                % ("СОВПАДАЕТ с мастером" if same else "РАСХОЖДЕНИЕ — стоп-риск", sync_note))
            if not same:
                return {"hypothesis": hid, "verdict": "FAIL",
                        "reasons": ["зеркало правил не синхронизировано: %s" % sync_note]}
    else:
        log("режим --dry: замер БЕЗ применения правки (проба канала замера)")
    res, message = run_battery(settings)
    if not res:
        log("СТОП-РЕПОРТ: %s" % message)
        return {"hypothesis": hid, "verdict": "NO_RESULT", "reasons": [message],
                "chars_before": chars0, "sha_before": sha0}
    chars, sha8, _ = prompt_fingerprint()
    verdict, reasons, table, detail = judge(res, chars, sha8)
    log("вход ПОСЛЕ: промпт chars=%d sha256=%s" % (chars, sha8))
    for model in sorted(table):
        cell = table[model]
        log("  %-30s house %d/%d  провалы: %s" %
            (model, cell["pass"], cell["total"], ", ".join(cell["fails"]) or "-"))
    log("ВЕРДИКТ: %s — %s" % (verdict, detail))
    for rsn in reasons:
        log("  причина: %s" % rsn)
    record = {
        "time": datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
        "hypothesis": hid, "title": h["title"],
        "verdict": verdict, "reasons": reasons,
        "chars_before": chars0, "sha_before": sha0,
        "chars": chars, "sha256": sha8, "detail": detail,
        "results_file": os.path.basename(res), "beacon": message,
        "table": {m: "%d/%d %s" % (c["pass"], c["total"], ",".join(c["fails"]))
                  for m, c in table.items()},
        "applied": bool(apply_it),
    }
    if verdict == "FAIL" and apply_it and auto_rollback:
        record["rollback"] = rollback(hid, settings)[1]
    runs = read_runs()
    runs.append(record)
    write_runs(runs)
    return record


# ---------------------------------------------------------------------------------------------
# СЛОЙ 4. ОТЧЁТ (форма §8 спеки). Один отчёт на ночь, дописывается по итерациям.
# ---------------------------------------------------------------------------------------------
def write_report(tag=None):
    runs = read_runs()
    tag = tag or datetime.datetime.now().strftime("%Y-%m-%d")
    os.makedirs(REPORT_DIR, exist_ok=True)
    path = os.path.join(REPORT_DIR, "REPORT_night_%s.md" % tag)
    chars, sha8, _ = prompt_fingerprint()
    ok = [r for r in runs if r["verdict"] == "PASS"]
    bad = [r for r in runs if r["verdict"] == "FAIL"]
    lines = ["=== НОЧНОЙ ОТЧЁТ %s ===" % tag,
             "Инструмент: night_optimizer %s" % APP_VERSION,
             "Итераций: %d (принято %d / откатано %d / без результата %d)"
             % (len(runs), len(ok), len(bad), sum(1 for r in runs if r["verdict"] == "NO_RESULT")),
             "База: 26b 15/15, glm 10/15, laguna 9/15 (chars=%d sha256=%s)" % (BASE_CHARS, BASE_SHA8),
             "Текущий вход: chars=%d sha256=%s" % (chars, sha8),
             "",
             "| # | гипотеза | правка | 26b | glm | laguna | вердикт | решение |",
             "|---|---|---|---|---|---|---|---|"]
    short = {"gemma4:26b": "26b", "glm-4.7-flash:q4_K_M": "glm",
             "laguna-xs-2.1:latest": "laguna"}
    for n, r in enumerate(runs, 1):
        t = r.get("table", {})
        def cell(model):
            v = t.get(model, "-")
            return v.split(" ")[0] if v != "-" else "-"
        decision = ("принято" if r["verdict"] == "PASS"
                    else "откатано" if r.get("rollback") else r["verdict"])
        lines.append("| %d | %s | %s | %s | %s | %s | %s | %s |" % (
            n, r["hypothesis"], r["title"][:40],
            cell("gemma4:26b"), cell("glm-4.7-flash:q4_K_M"),
            cell("laguna-xs-2.1:latest"), r["verdict"], decision))
    lines += ["", "Принятые: %s" % (", ".join(r["hypothesis"] for r in ok) or "—"),
              "Откатано: %s" % (", ".join(r["hypothesis"] for r in bad) or "—"), ""]
    for r in runs:
        lines.append("- %s (%s): %s" % (r["hypothesis"], r.get("time", "?"), r.get("detail", r["verdict"])))
        for rsn in r.get("reasons", []):
            lines.append("    * %s" % rsn)
        if r.get("rollback"):
            lines.append("    * откат: %s" % r["rollback"])
    lines += ["", "Созданные скиллы:", "  (определяются ногой по итогам итераций)", "",
              "Грабли:", "  " + "\n  ".join(GRABLI), ""]
    with open(path, "w", encoding="utf-8") as fh:
        fh.write("\n".join(lines))
    log("отчёт записан: %s" % path)
    return path


# ---------------------------------------------------------------------------------------------
# СЛОЙ 5. CLI (рука 1 — ночь, планировщик, агент)
# ---------------------------------------------------------------------------------------------
def show_list():
    log("Очередь ночного оптимизатора (база %d/%s, лимит итераций %d)"
        % (BASE_CHARS, BASE_SHA8, load_settings()["max_iterations"]))
    for h in QUEUE:
        log("  %-3s %-9s %s" % (h["id"], h["status"], h["title"]))


def main(argv):
    settings = load_settings()
    if "--settings" in argv:
        settings["git_enabled"] = True
        save_settings(settings)
        log("настройки сохранены: %s" % SETTINGS_PATH)
    if not [a for a in argv if a.startswith("--")]:
        show_list()
        return 0
    if "--list" in argv:
        show_list()
        return 0
    if "--report" in argv:
        write_report()
        return 0
    if "--dry-check" in argv:
        return dry_check()
    ids = [argv[i + 1] for i, a in enumerate(argv[:-1]) if a == "--run"]
    if not ids:
        show_list()
        return 0
    for hid in ids:
        rec = run_hypothesis(hid, settings, apply_it="--apply" in argv)
        log("итог %s: %s" % (hid, rec["verdict"]))
    write_report()
    return 0


def dry_check():
    """Проба якорей без записи: каждая гипотеза применяется на КОПИИ текста и сверяется."""
    ok = True
    for h in QUEUE:
        if not h.get("apply"):
            log("%-3s SKIP  %s" % (h["id"], h.get("why_retargeted", "правка не задана")))
            continue
        plan, note = apply_patch(h["apply"], dry=True)
        if plan is None:
            log("%-3s СТОП %s" % (h["id"], note))
            ok = False
            continue
        # что именно станет с каждым файлом: длина ДО и ПОСЛЕ, счёт на копии текста
        detail = []
        for full in dict.fromkeys(p[0] for p in plan):
            with open(full, encoding="utf-8") as fh:
                text = fh.read()
            after = text
            for _f, old, new in [p for p in plan if p[0] == full]:
                after = after.replace(old, new, 1)
            detail.append("%s: %d -> %d симв. (+%d)"
                          % (os.path.basename(full), len(text), len(after), len(after) - len(text)))
        log("%-3s ОК    %s | %s" % (h["id"], note, "; ".join(detail)))
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
