# -*- coding: utf-8 -*-
"""Re-score a finished run with the CURRENT checkers (honest re-measurement).

    cmd /c python -X utf8 D:\\AI\\AGENT_SETTINGS\\checks\\tests\\rescore_run.py <results_*.json>

Needed after every checker change: a verdict computed by an old checker is not a result,
it is a historical artefact. Example: the run 14:37 was 12/13 for gemma4:26b with the old
revive checker and 9/13 with the honest one.
"""
import json
import sys

sys.path.insert(0, r"D:\AI\AGENT_SETTINGS\checks")
import loop_revive_test as L  # noqa: E402

path = sys.argv[1]
rows = json.load(open(path, encoding="utf-8"))
checker_of = {qid: chk for _f, qid, _p, chk in L.ITEMS}

seen = []
for r in rows:
    key = (r["model"], r["cond"])
    if key not in seen:
        seen.append(key)

for model, cond in seen:
    sub = [r for r in rows if r["model"] == model and r["cond"] == cond]
    bad = []
    for r in sub:
        chk = checker_of.get(r["qid"], "?")
        verdict, _note = L.score(chk, r.get("answer", ""))
        if verdict != "PASS":
            bad.append(r["qid"])
    print("%-34s %-6s %2d/%d  fail=%s" % (model, cond, len(sub) - len(bad), len(sub),
                                          ",".join(bad) or "-"))