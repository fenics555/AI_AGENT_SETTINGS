---
name: models-stack
system: AGENT_SETTINGS
description: Use when: нужны характеристики моделей стека (архитектура, MoE/плотная, контекст, размер, capabilities), выбор модели для прогона, «какая модель быстрее», «почему модель тормозит», окно контекста
when: модели, стек, MoE, архив MoE, контекст, num_ctx, окно, laguna, gemma4, nemotron, qwen3, gpt-oss, xing4, скорость модели, VRAM, прогон моделей
priority: critical
date: 16.10.2026
executor: Cline
---

# ПАСПОРТ МОДЕЛЕЙ СТЕКА (живые факты 16.10.2026)

> Источник: `ollama show <model>` (локальные файлы) + официальные страницы Ollama
> (`ollama.com/library/<model>`) для MoE-структуры, которую `ollama show` НЕ раскрывает.
> **Все модели дома — MoE.** Крупный контекст (256K–1M) держится на 16 ГБ VRAM ТОЛЬКО за счёт MoE.

## 1. СВОДНАЯ ТАБЛИЦА (полный стек)

| модель | размер | архитектура | всего / активных | контекст | квант | capabilities |
|---|---|---|---|---|---|---|
| **gemma4:26b** | 18 ГБ | `gemma4` = **25.2B A4B MoE** | 25.2B / **3.8B** | **262 144** | Q4_K_M | tools · thinking · **vision** |
| **laguna-xs-2.1** | 20 ГБ | `laguna` = **33B MoE** (256 экспертов + 1 shared) | 33B / **3B** | **262 144** | Q4_K_M | tools · thinking |
| **nemotron3-nano** | 17 ГБ | `nemotron_h_moe` | 31.6B | **1 048 576** (1M) | IQ4_XS | tools · thinking |
| **qwen3.6-35b** | 18 ГБ | `qwen35moe` | 34.7B | **262 144** | IQ4_XS | tools · thinking |
| **gpt-oss:20b** | 13 ГБ | `gpt-oss` = MoE (32 эксперта) | 20.9B | **131 072** | MXFP4 | tools · thinking |
| **Xing4.0-29B-A4B** | 18 ГБ | `xing4_0` = **A4B MoE** | 31.2B / ~4B | **262 144** | Q4_K_M | tools · thinking |

Дополнительно: `nomic-embed-text-v2-moe:latest` (957 МБ) — эмбеддер для индекса скиллов.

## 2. 🔴 ГЛАВНЫЙ ФАКТ: `ollama show` НЕ ПОКАЗЫВАЕТ MoE

**Грабля:** `ollama show gemma4:26b` выводит `architecture gemma4`, и выглядит как **плотная** модель.
**Факт:** по официальной спеке это **26B A4B MoE** — *«8 active / 128 total experts, 3.8B active»*.
Так же и `laguna`: `architecture laguna` — а по спеке *«33B total, 3B activated, 256 experts»*.

**ПРАВИЛО:** нужен MoE-статус → смотреть **официальную страницу** `ollama.com/library/<model>`
(раздел Readme: «Mixture-of-Experts», «Active Parameters», «Expert Count»), а не `ollama show`.

**Как читать имя:** суффикс **`A4B`** = ~4B активных параметров = MoE
(`gemma4:26b-a4b-it-*`, `Xing4.0-29B-A4B`).

## 3. ЗАЧЕМ ЭТО ДОМУ

| вывод | следствие |
|---|---|
| все модели MoE | окно 256K реально работает на 16 ГБ VRAM (активны ~3–4B) |
| у каждой `thinking` | всем нужен запас `num_predict` (§6.8): допросы ≥ 2048 |
| **gpt-oss** — reasoning | думает ~1700 токенов ДО ответа; малый `num_predict` = пустой `content` |
| `tools` у всех | tool-use канал стенда поддержан нативно |
| `vision` только у gemma4 | задача с картинками → gemma4 |

## 4. ЖИВОЙ ЗАМЕР СКОРОСТИ (16.10.2026, NumCtx=32768)

| модель | t/s (генерация) | заметка |
|---|---|---|
| gemma4:26b | ~85–115 | эталон |
| laguna | ~86–89 | стабильная |
| qwen3.6-35b | ~87 | но **буксовала на старте** (тест1 = 116 с вместо 25 с) |
| nemotron3 | ~102–103 | быстрая |
| gpt-oss | ~? | reasoning, медленнее всех |

**Грабля qwen3:** на тестах 1–2 тратила в 3–4,6× больше времени (петля/долгое thinking).
Результаты при этом верные — это **потеря времени, не качества**.

## 4а. 🔴 VRAM: МОДЕЛИ БОЛЬШЕ 16 ГБ ЧАСТИЧНО НА CPU (17.10.2026)

**Машина дома: VRAM 16 311 MiB = 15,9 ГБ.** Проверять `ollama ps` (колонка `PROCESSOR`):

| модель | размер | влезает? | PROCESSOR | следствие |
|---|---|---|---|---|
| **gpt-oss:20b** | **13 ГБ** | ✅ **да** | **100% GPU** | полная скорость |
| nemotron3-nano | 17–18 ГБ | ❌ нет | **22% CPU / 78% GPU** | 434 с на 3 задачи, **14 562 токена** |
| gemma4:26b | 18 ГБ | ❌ нет | 25% CPU / 75% GPU | медленнее, чем могла бы |
| qwen3.6-35b | 18 ГБ | ❌ нет | ~22% CPU / 78% GPU | — |
| laguna-xs-2.1 | **20 ГБ** | ❌ нет | 36% CPU / 64% GPU | самая тяжёлая |

**ПОСЛЕДСТВИЯ (живые факты):**
1. **Скорость в 3–10 раз ниже** — часть слоёв в системной памяти.
2. **РИСК ЗАВИСАНИЯ:** модель уже в памяти + переполнение → Ollama **встаёт**
   (GPU 0–15%, лог мёртв, `RESULT` не пишется вообще).
3. **HTTP 500 (`ERROR`)** — переполнение контекста/VRAM.

**НЕ ЛЕЧИТСЯ законом** — это железо vs размер модели. Лечится только:
- брать модели **≤13 ГБ** для полной скорости;
- либо **кванты поменьше** (iq4 → iq3);
- **гарантированная выгрузка** перед сменой модели:
  `ollama stop <модель>` + `Stop-Process llama-server` + пауза 5 с + проверка `nvidia-smi`.

**В отчётах ВСЕГДА указывать** `PROCESSOR` из `ollama ps` — он объясняет медленность и зависания.


## 5. ИЗВЕСТНЫЕ ВЕРСИИ (обновления, 16.10.2026)

**gemma4** (`ollama.com/library/gemma4`, обновлён 3 дня назад, 51 тег):
| тег | размер | контекст |
|---|---|---|
| 12b | 7,7–8,0 ГБ | 256K |
| **26b** | 16–19 ГБ | 256K |
| 31b | 19–20 ГБ | 256K |
| 26b-a4b-it-q8_0 | 28 ГБ | 256K |
| 26b-a4b-it-bf16 | 52 ГБ | 256K |
| 26b-nvfp4 | 16 ГБ | 256K |

Наша копия `001e5dafc3c7` (18 ГБ) = **`26b-a4b-it-mtp-q4_K_M`** (MTP-драфт есть: см. Modelfile `DRAFT`).
**Обновляться на q8_0/bf16 не нужно** — в 1,5–3× тяжелее, для стенда важнее скорость.

**laguna-xs-2.1** (обновлён 1 месяц, 133.3K скачиваний): latest 20 ГБ · q8_0 36 ГБ · bf16 67 ГБ.
Особенности: KV-кэш в **FP8**, 40 слоёв (10 global + 30 sliding window), sliding window 512.
Лицензия OpenMDW-1.1. Автор — Poolside.

**Xing4.0-29B-A4B-GGUF** (`Venastine-Research`, HF API): lastModified 2026-10-11, 61 337 скачиваний,
710 likes, apache-2.0, base `XingChen-AGI/Xing4.0-29B-A4B`, arxiv 2512.24157 / 2507.18013.
У автора **только одна** модель → обновлений нет.

## 6. ПРОБА

Назвать: (а) какие модели стека MoE → **все**; (б) где смотреть MoE-статус → **офиц. страница Ollama**,
не `ollama show`; (в) что значит суффикс `A4B` → **~4B активных = MoE**; (г) у кого самый большой
контекст → **nemotron3 (1M)**; (д) кому нужен большой `num_predict` → **gpt-oss (reasoning)**.

## 7. 🔴 МОДЕЛЬ В `ollama list` ≠ МОДЕЛЬ РАБОЧАЯ (дорогая грабля, 16.10.2026)

**Живой факт:** `hf.co/Venastine-Research/Xing4.0-29B-A4B-GGUF:Q4_K_M` (18 ГБ):
- ✅ есть в `ollama list`
- ✅ `ollama show` **читает манифест** (архитектура, контекст, capabilities, параметры) — выглядит рабочей
- ❌ **НЕ ЗАПУСКАЕТСЯ ВООБЩЕ**: любой запрос → **HTTP 500**
- ❌ `ollama ps` пусто, `llama-server` не стартует (0 процессов)

**Точная причина из `%LOCALAPPDATA%\Ollama\server.log`:**
```
llama_model_load: error loading model: unknown model architecture: 'xing4_0'
srv  llama_server: exiting due to model loading error
[GIN] POST "/api/chat" | 500
```
**Движок llama.cpp внутри Ollama НЕ ЗНАЕТ архитектуру `xing4_0`** (форк China Telecom:
`hyper_connection`, `sinkhorn_iterations`, `MLA attention`, YaRN-rope).
Обновление Ollama 0.40.3 → 0.40.4 **не помогло**. В манифесте **нет** строки `requires`
(у gemma4 она была: `requires 0.30.9`) — то есть версия даже не проверяется, а рантайм падает.

**ПРАВИЛО (обязательная проверка ПЕРЕД добавлением модели в `$CFG.Models`):**
1. **Прямая проба API** — не доверять `ollama list` и `ollama show`:
   ```powershell
   $b=[Text.Encoding]::UTF8.GetBytes('{"model":"<модель>","messages":[{"role":"user","content":"2+2"}],"stream":false}')
   try { (Invoke-RestMethod -Uri 'http://localhost:11434/api/chat' -Method Post -Body $b `
          -ContentType 'application/json' -TimeoutSec 120).message.content }
   catch { 'МОДЕЛЬ НЕ РАБОТАЕТ: ' + $_.Exception.Message }
   ```
2. Если ошибка — смотреть **точную причину** в логе:
   `Get-Content "$env:LOCALAPPDATA\Ollama\server.log" -Tail 40` → искать
   `unknown model architecture` / `failed to load model`.
3. **Только после успешной пробы** добавлять модель в `$CFG.Models`.
4. Если добавил нерабочую — **убрать немедленно**: иначе `-Models all` падает на её загрузке,
   и весь прогон бесполезен.

**Признак для проверки:** нестандартное имя архитектуры (`xing4_0`, `*_moe` экспериментального
форка) + отсутствие `requires` в `ollama show` = **высокий риск неподдержки**.

**Xing4.0 status (16.10.2026):** убрана из `$CFG.Models` по слову владельца. Модель на диске,
но нерабочая — вернуть только после появления поддержки `xing4_0` в llama.cpp/Ollama.


## 8. 🔴 УДАЛЕНО: nemotron3-nano — «СЫРОЙ» Modelfile (17.10.2026)

**Модель УДАЛЕНА по слову владельца** (`ollama rm batiai/nemotron3-nano:iq4`).

**ЧТО БЫЛО НЕ ТАК (диагностика до удаления):**

Модель = **NVIDIA Nemotron 3 Nano 30B-A3B** (MoE), квант `BatiAI`, IQ4_XS, 16,73 ГБ.
В **GGUF-метаданных ЕСТЬ** полноценный `tokenizer.chat_template` (**10 708 символов**):
- роли `system`/`user`/`assistant` через `<|im_start|>` / `<|im_end|>`
- **поддержка tools** (`{%- if not tools is defined %}`)
- **thinking-режим** (`enable_thinking`, ` thinking`)

**А в Modelfile Ollama стояло:**
```
TEMPLATE {{ .Prompt }}                              <- БЕЗ ролей!
SYSTEM   You are a helpful AI assistant.            <- дефолт
PARAMETER temperature 0.7                           <- «фантазии»
```
**Ollama берёт `TEMPLATE` из Modelfile, а не `chat_template` из GGUF** -> шаблон **не применялся**.

**СЛЕДСТВИЯ (подтверждены прогонами):**
1. нет ролей -> не понимает формат вызова инструментов;
2. `temperature 0.7` -> флаги `ВЫДУМАЛ_СЕБЯ` + `ВОДА`;
3. **14 562 токена** на задачу (в 20x больше gemma4) — не знает, когда остановиться;
4. **13+ минут** на задачу теста 4 (12 ходов) — «болтливость»;
5. **НО** числа давала **верные** (`COUNT_OK` 198/65) — модель сильная, испорчен формат сборки.

**КАК ПРОВЕРИТЬ ЛЮБУЮ МОДЕЛЬ (метод):**
```powershell
ollama show <модель> --modelfile | Select-String 'TEMPLATE|RENDERER|PARSER|SYSTEM'
```
- у **рабочих** моделей: либо **RENDERER/PARSER** (gemma4, laguna), либо **полный TEMPLATE** (gpt-oss, qwen3);
- **`TEMPLATE {{ .Prompt }}` БЕЗ RENDERER** = риск «сырого» формата -> модель путает роли.

**ЛЕЧЕНИЕ (если модель нужна):** пересобрать с шаблоном из GGUF:
```powershell
ollama show <модель> --modelfile         # взять FROM (путь к блобу)
# создать Modelfile: FROM <блоб> + TEMPLATE """<chat_template из GGUF>"""
ollama create <модель>-fixed -f Modelfile
```
Извлечение шаблона из GGUF — питоном (метаданные `tokenizer.chat_template`).

**ВЫВОД:** «плохое поведение модели» может быть **дефектом сборки её Modelfile**, а не модели.
Сначала проверять `TEMPLATE`/`RENDERER` — потом винить модель.

---

## 9. 🔴 РЕЕСТР VRAM: КТО ВЛЕЗАЕТ В 16 ГБ ПРИ `num_ctx` (живой замер 17.10.2026)

**Владелец (17.10.2026):** `NumCtx` поднят 32768 -> **65536** для ВСЕХ моделей.
**ЦЕНА ИЗМЕРЕНА:** большой KV-кэш не влезает в VRAM -> часть слоёв уходит на CPU (§6.12.17).

**ЖИВОЙ ЗАМЕР (лагуна, `ollama ps`):**
```
NAME                    SIZE     PROCESSOR          CONTEXT
laguna-xs-2.1:latest    20 GB    42%/58% CPU/GPU    65536
```
При `num_ctx=32768` та же модель шла **100% GPU**. Вывод: **65k = частичный CPU-спил у тяжёлых.**

**ЭТАЛОН VRAM (16 ГБ, RTX 5060 Ti):**

| модель | вес | при 32768 | при 65536 (прогноз) |
|---|---|---|---|
| **gpt-oss:20b** | 13 ГБ | ✅ 100% GPU | ⚠️ близко к пределу |
| **gemma4:26b** | 18 ГБ | ⚠️ часть CPU | ⚠️ больше CPU |
| **qwen3.6-35b** | 18 ГБ | ⚠️ часть CPU | ⚠️ больше CPU |
| **laguna-xs-2.1** | 20 ГБ | ✅ 100% GPU | ❌ **42% CPU / 58% GPU** (ЗАМЕР) |

**Цена CPU-спила (факт 17.10):** лагуна при 65k на тесте 3 дала `COUNT_WRONG depth=0`
(при 32768 была `COUNT_OK`). Т.е. **спил бьёт по качеству**, а не только по скорости.

**ПРАВИЛО ЗАМЕРА (обязательное после смены `num_ctx`):**
```powershell
ollama ps     # колонка PROCESSOR: «100% GPU» = ок; «NN% CPU» = спил
```
**Мерить КАЖДУЮ модель** — вес разный, предел у всех свой.

**ВЫВОД:** `num_ctx` — **не бесплатный** параметр. Поднимать -> мерить `ollama ps` ->
сравнивать качество (COUNT_OK vs COUNT_WRONG). Окно больше ≠ тест лучше.



