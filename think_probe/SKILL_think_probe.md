---
name: think_probe
system: AGENT_SETTINGS
description: Use when: тест модели, поведение модели, think_probe, проба поведения, тупик, проверка модели
when: тест модели, поведение модели, think_probe, проба поведения, тупик, проверка модели
priority: critical
version: 3.0
date: 11.10.2026
executor: Cline
---

# SKILL: THINK_PROBE (тесты поведения моделей) — v3.0

## TL;DR (30 секунд)
Проект: тесты локальных моделей Ollama для агентной работы в Cline.
Железо: Intel 285K + RTX 5060 Ti **16 ГБ VRAM**.
Главный конфликт: `.clinerules` 29 КБ не влезает в контекст — нужно ≤ 8 КБ.
Лимиты: `num_ctx ≥ 16384`, `num_predict=16384` для `low`.
Методология: тесты проверяют **ТОЛЬКО `.clinerules`**, без подсказок.
Не трогать: `repo\.clinerules` (копия для GitHub).

## 1. Назначение
Отдельное направление для прогона тестов поведения локальных моделей Ollama.

## 2. Когда читать
- При выборе модели для задачи (совместно с `SKILL_models_behavior.md`).
- При подготовке нового прогона тестов.
- При разборе провалов агентной работы.

## 3. Что внутри (карта файлов)

| Файл | Назначение |
|---|---|
| `think_probe_v4.ps1` | Основной скрипт: 14 проб × 5 моделей × 2 режима = 140 запросов |
| `think_probe_v5.ps1` | Тест кодирования: генерация `scan_old_files.ps1` |
| `think_probe_v6.ps1` | Тест выбора инструмента: 4 задачи + рефлексия + мета |
| `make_fixtures.ps1` | Генератор `fixtures\{small,big,huge}.md` |
| `run_all_checks.ps1` | Последовательный запуск v4 → v5 → v6 |
| `run_all.bat` | Обёртка для Windows |
| `log\think_probe_v4_*.txt` | Ответы, головы, прогресс v4 |
| `log\v5_<модель>_<дата>*.txt` | Отчёты v5 (`_report`, `_code`, `_check`, `_diag`) |
| `log\v6_<модель>_<дата>.txt` | Отчёты v6 (4 задачи + рефлексия + мета) |
| `think_probe_спека.md` | Спека (что сделано, что осталось) |

## 4. КРИТИЧНЫЕ ЛИМИТЫ (обновлено 11.10.2026)

| Параметр | Значение | Почему |
|---|---|---|
| `.clinerules` текущий | 29234 байт / 18453 символа | Вырос с 23281 за счёт v6.x |
| **`.clinerules` целевой** | **≤ 8 КБ (≈8000 символов)** | Иначе не влезает вместе с задачей |
| `.clinerules` жёсткий минимум | 4 КБ | Для тяжёлых моделей при `num_ctx=16384` |
| `num_ctx` (минимум) | **16384** | 8192 НЕ ВМЕЩАЕТ `.clinerules` |
| `num_ctx` (оптимум для gemma4/gpt-oss) | **32768** | Влезают в VRAM полностью |
| `num_ctx` (для qwen/laguna/nemotron) | **16384** | Не влезают в 16 ГБ, больше — хуже |
| `num_predict` (`think=false`) | 1024–2048 | Достаточно |
| `num_predict` (`think=low`) | **16384** | 8192 обрезает qwen3.6-35b |
| `timeout` | **600 с** | `low` может идти долго |

## 5. ТОКЕНЫ vs СИМВОЛЫ (для расчёта)
- **Английский:** 1 токен ≈ 4 символа.
- **Русский:** 1 токен ≈ **2–2.5 символа**.
- Текущий `.clinerules` ≈ 7000 токенов (подтверждено логами: `промпт=7572` для gemma4).
- Целевой `.clinerules` 8 КБ ≈ 3200 токенов.

## 6. МЕТОДОЛОГИЯ ТЕСТА
**Тест проверяет ТОЛЬКО `.clinerules`.** Системный промпт = обёртка:

Ниже — твой ЗАКОН (.clinerules). Ты ОБЯЗАН следовать ему.

=== НАЧАЛО .clinerules ===
<полный текст .clinerules>
=== КОНЕЦ .clinerules ===

`user` = текст пробы. Никаких подсказок сверху.
Если модель не следует правилам — это результат теста, не повод править скрипт.

## 7. Запуск (все скрипты)
```powershell
cd D:\AI\AGENT_SETTINGS\think_probe

# 1. Фикстуры (только для v6)
powershell -NoProfile -ExecutionPolicy Bypass -File .\make_fixtures.ps1

# 2. Тесты по одному
powershell -NoProfile -ExecutionPolicy Bypass -File .\think_probe_v4.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File .\think_probe_v5.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File .\think_probe_v6.ps1

# 3. Или всё сразу
powershell -NoProfile -ExecutionPolicy Bypass -File .\run_all_checks.ps1