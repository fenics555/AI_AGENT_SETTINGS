---
name: think_probe
system: AGENT_SETTINGS
description: Направление тестов поведения локальных моделей Ollama. Пробы, тупики, крахи, замеры.
when: тест модели, поведение модели, think_probe, проба поведения, тупик, проверка модели
priority: critical
---

# SKILL: THINK_PROBE (тесты поведения моделей)

## Назначение
Отдельное направление для прогона тестов поведения локальных моделей Ollama.

## Когда читать
- При выборе модели для задачи (совместно с `repo\SKILL_models_behavior.md`)
- При подготовке нового прогона тестов

## Что внутри

| Файл | Назначение |
|---|---|
| `think_probe_v4.ps1` | **основной скрипт** (14 проб × 5 моделей × 2 режима) |
| `think_probe_v5.ps1` | **тест кодирования** (генерация `scan_old_files.ps1`) |
| `log\think_probe_v4_report.txt` | ответы и метрики v4 |
| `log\think_probe_v4_heads.txt` | thinking v4 |
| `log\think_probe_v4_progress.log` | прогресс v4 |
| `log\v5_<модель>_<дата>_report.txt` | отчёты v5 по каждой модели |
| `log\v5_<модель>_<дата>_code.ps1` | сгенерированный код v5 |
| `log\v5_<модель>_<дата>_check.txt` | проверки кода v5 |
| `log\v5_<модель>_<дата>_diag.txt` | диагностика контекста v5 |

## КРИТИЧНЫЕ ЛИМИТЫ (обновлено 2026-10-10)

| Параметр | Значение | Почему |
|---|---|---|
| **`.clinerules`** | **23281 байт / 14903 символа** | Полный закон (не 3857!) |
| **`num_ctx`** | **16384** | 8192 НЕ ВМЕЩАЕТ `.clinerules` |
| **`num_predict` (`think=false`)** | 1024–2048 | Достаточно |
| **`num_predict` (`think=low`)** | **8192** | 4096 обрезает `qwen3.6-35b` |
| **`timeout`** | **600 с** | `think=low` может идти долго |

## МЕТОДОЛОГИЯ ТЕСТА (КРИТИЧНО)

**Тест проверяет ТОЛЬКО `.clinerules`. Никаких дополнительных ограничений в промпте быть не должно.**

Системный промпт теста — это **только обёртка** вокруг главного `.clinerules`:


## Запуск
powershell -NoProfile -ExecutionPolicy Bypass -File "D:\AI\AGENT_SETTINGS\think_probe\think_probe_v4.ps1"
powershell -NoProfile -ExecutionPolicy Bypass -File "D:\AI\AGENT_SETTINGS\think_probe\think_probe_v5.ps1"