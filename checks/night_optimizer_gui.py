# -*- coding: utf-8 -*-
r"""night_optimizer_gui - окно ночного оптимизатора (рука 2 по закону трёх линий).

    cmd /c python -X utf8 D:\AI\AGENT_SETTINGS\checks\night_optimizer_gui.py

Работает БЕЗ агента. Зовёт ту же библиотеку, тот же лог и тот же отчёт, что и CLI:
никакой своей логики замера здесь нет (одна библиотека — один лок — один лог).
"""
import os
import subprocess
import sys
import tkinter as tk
from tkinter import messagebox, scrolledtext

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import night_optimizer as N          # noqa: E402  (библиотека одна на все руки)

HERE = os.path.dirname(os.path.abspath(__file__))
README = os.path.join(HERE, "README.md")


class NightWindow(tk.Tk):
    def __init__(self):
        super().__init__()
        self.title("Ночной оптимизатор %s — регрессионная ночь правил" % N.APP_VERSION)
        self.geometry("900x640")
        self.settings = N.load_settings()

        bar = tk.Frame(self)
        bar.pack(fill="x", padx=8, pady=6)
        tk.Label(bar, text="[слой 1: настройки]", fg="#666").pack(side="left")
        self.max_iter = tk.IntVar(value=self.settings["max_iterations"])
        self.timeout = tk.IntVar(value=self.settings["timeout_sec"])
        self.gitbox = tk.BooleanVar(value=self.settings["git_enabled"])
        for label, var in (("итераций", self.max_iter), ("таймаут с", self.timeout)):
            tk.Label(bar, text=label).pack(side="left", padx=(10, 2))
            tk.Entry(bar, textvariable=var, width=6).pack(side="left")
        tk.Checkbutton(bar, text="пушить из инструмента", variable=self.gitbox).pack(side="left", padx=10)
        tk.Button(bar, text="Сохранить настройки", command=self.save).pack(side="left", padx=4)
        tk.Button(bar, text="README", command=self.show_readme).pack(side="left", padx=4)

        bar2 = tk.Frame(self)
        bar2.pack(fill="x", padx=8)
        tk.Label(bar2, text="[слой 2: рабочие кнопки]", fg="#666").pack(side="left")
        tk.Button(bar2, text="Очередь", command=self.show_queue).pack(side="left", padx=4)
        tk.Button(bar2, text="Запустить ночь", command=self.run_night).pack(side="left", padx=4)
        tk.Button(bar2, text="Отчёт", command=self.make_report).pack(side="left", padx=4)
        tk.Button(bar2, text="Открыть лог", command=self.open_log).pack(side="left", padx=4)

        self.status = tk.Label(self, text="готов", anchor="w", fg="#0a0")
        self.status.pack(fill="x", padx=10, pady=4)
        self.out = scrolledtext.ScrolledText(self, wrap="none", font=("Consolas", 9))
        self.out.pack(fill="both", expand=True, padx=8, pady=6)

    def say(self, text):
        self.out.insert("end", text + "\n")
        self.out.see("end")
        self.update_idletasks()

    def save(self):
        self.settings.update(max_iterations=self.max_iter.get(),
                             timeout_sec=self.timeout.get(),
                             git_enabled=self.gitbox.get())
        N.save_settings(self.settings)
        self.say("настройки сохранены: %s" % N.SETTINGS_PATH)

    def show_queue(self):
        self.say("--- очередь ---")
        for h in N.QUEUE:
            self.say("  %-3s %-13s %s" % (h["id"], h["status"], h["title"]))

    def make_report(self):
        self.say("отчёт: %s" % N.write_report())

    def open_log(self):
        path = os.path.join(N.LOG_DIR, "night_optimizer.log")
        if os.path.exists(path):
            os.startfile(path)
        else:
            messagebox.showinfo("Лог", "лог ещё пуст: %s" % path)

    def show_readme(self):
        if os.path.exists(README):
            with open(README, encoding="utf-8") as fh:
                messagebox.showinfo("README", fh.read()[:3000])
        else:
            messagebox.showinfo("README", "README.md в папке checks не найден")

    def run_night(self):
        """Ночь идёт отдельным процессом: окно остаётся живым и показывает ход."""
        todo = [h["id"] for h in N.QUEUE if h["status"] == "new" and h.get("apply")]
        if not todo:
            self.say("нет гипотез с заданной правкой — смотри отчёт и ROADMAP")
            return
        hid = todo[0]
        self.save()
        self.status.configure(text="идёт итерация %s (детач, ждём маяк стенда)…" % hid, fg="#a50")
        self.say("запуск итерации %s отдельным процессом" % hid)
        args = [sys.executable, "-X", "utf8", os.path.join(HERE, "night_optimizer.py"),
                "--run", hid, "--apply"]
        proc = subprocess.Popen(args, cwd=HERE)
        self.status.configure(text="итерация %s, PID %d" % (hid, proc.pid), fg="#a50")
        self.after(2000, lambda: self.watch(proc, hid))

    def watch(self, proc, hid):
        """Один опрос состояния процесса; цикла опросов файла результата тут нет."""
        if proc.poll() is None:
            self.after(3000, lambda: self.watch(proc, hid))
            return
        self.status.configure(text="итерация %s завершена, код %d" % (hid, proc.returncode), fg="#0a0")
        self.say("итог итерации %s: код возврата %d — подробности в логе и отчёте" % (hid, proc.returncode))


if __name__ == "__main__":
    NightWindow().mainloop()
