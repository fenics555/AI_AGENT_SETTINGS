r"""Три варианта промпта стенда — общий текст для проб токенов.

    import ctx_variants; for name, text in ctx_variants.cases(): ...

SECTION_MAX=7000 — текущий; 10000 — вход, на котором laguna упала 9 -> 4;
третий — ВЕСЬ мастер, как если бы лимит стоял 30000 (фактически «без лимита»).
"""
import os

RULES = r"D:\AI\.clinerules"
HEADS = ("АНТИ-ПЕТЛЯ (", "ВОСКРЕШЕНИЕ: REVIVE", "АНТИ-ГАЛЛЮЦИНАЦИИ (")


def _raw():
    with open(RULES, encoding="utf-8-sig") as fh:
        return fh.read()


def _build(raw, sec_max, total):
    marks = sorted((raw.find("\n" + h) + 1, h) for h in HEADS if raw.find("\n" + h) >= 0)
    parts = {}
    for n, (i, head) in enumerate(marks):
        stop = marks[n + 1][0] if n + 1 < len(marks) else len(raw)
        parts[head] = raw[i:stop].strip()
    uniq, seen = [], set()
    for head in HEADS:
        t = parts.get(head, "")[:sec_max].strip()
        if t and t not in seen:
            seen.add(t)
            uniq.append(t)
    return ("Ты — исполнитель в инженерном доме. Ниже действующие правила дома выдержкой из "
            "мастер-файла (%s):\n\n%s" % (RULES, "\n\n".join(uniq)[:total]))


def cases():
    raw = _raw()
    return [("1) SECTION_MAX=7000 (сейчас)", _build(raw, 7000, 20000)),
            ("2) SECTION_MAX=10000 (провал laguna)", _build(raw, 10000, 40000)),
            ("3) ВЕСЬ мастер (лимит 30000)", raw)]
