# AGENT_SETTINGS — единая настройка локальных моделей Ollama

Одна папка = одно место правды: параметры моделей + правила поведения.
Скрипт **обновляет модели на месте** (пересоздаёт тот же тег), поэтому двойников нет.

```
D:\AI\AGENT_SETTINGS\
├── config\
│   ├── behavior.json   <- ВСЕ параметры (пресеты strict/balanced/creative, skip-листы, overrides)
│   └── behavior.md     <- правила поведения + (опционально) системный промпт между SYS-маркерами
├── tools\
│   └── Apply-AgentParams.ps1
├── backup\             <- pristine Modelfile каждой модели (первый прогон) - для -Restore
└── log\                <- журнал применений
```

## Запуск

```powershell
cd D:\AI\AGENT_SETTINGS\tools

# посмотреть, что будет сделано (ничего не меняет)
powershell -ExecutionPolicy Bypass -File .\Apply-AgentParams.ps1 -DryRun

# применить пресет strict из конфига ко ВСЕМ моделям
powershell -ExecutionPolicy Bypass -File .\Apply-AgentParams.ps1

# другое поведение
powershell -ExecutionPolicy Bypass -File .\Apply-AgentParams.ps1 -Preset creative
powershell -ExecutionPolicy Bypass -File .\Apply-AgentParams.ps1 -Preset balanced

# одна модель
powershell -ExecutionPolicy Bypass -File .\Apply-AgentParams.ps1 -Model gemma4:12b -Preset strict

# вернуть авторские дефолты
powershell -ExecutionPolicy Bypass -File .\Apply-AgentParams.ps1 -Restore -Model gemma4:12b
powershell -ExecutionPolicy Bypass -File .\Apply-AgentParams.ps1 -Restore

# добавить в модель системный промпт из behavior.md (по умолчанию выключено)
powershell -ExecutionPolicy Bypass -File .\Apply-AgentParams.ps1 -SystemPrompt
```

## Программы проверки моделей

Лежат рядом с настройками, в `checks\`:

| Файл | Что делает |
|---|---|
| `checks\strict_test.py` | 10 вопросов (6 фактов + 4 ловушки) по каждой модели: поведение + t/s |
| `checks\verify_prompt_test.py` | A/B: обычный промпт против правила «нет источника — нет утверждения», 3 ловушки + контроль (реальный ГОСТ 2.106-96) |
| `checks\speed_check.py` | скорость на заданном окне контекста (по умолчанию 202752): load, prompt t/s, gen t/s |
| `checks\RUN_*.bat` | готовые лаунчеры (`RUN_strict_test.bat`, `RUN_verify_test.bat`, `RUN_speed_check.bat`, `RUN_all_checks.bat`) |

Вывод прогонов: `D:\AI\log\ollama_checks\` (срок хранения 56 дней, ключ добавлен в `retention.json`),
сводные отчёты — в `D:\AI\log\reports\`. Подробности и как читать результаты — `checks\README.md`.

Внимание: `OLLAMA_MAX_LOADED_MODELS=1`, поэтому любая проверка загружает модель и **вытесняет**
ту, с которой вы работаете. Запускать, когда работа не идёт.

## Почему скорость не падает

Скрипт берёт `ollama show <model> --modelfile` и переписывает **только строки `PARAMETER`**
из `manageParams`. Остальное (`FROM` на блоб весов, `DRAFT` = MTP-драфт, `TEMPLATE`,
`RENDERER`, `PARSER`, `LICENSE`, проектор) остаётся байт-в-байт. Веса, квант, оффлоад
на GPU и спекулятивное декодирование не затрагиваются.

Проверка после применения:

```powershell
ollama show gemma4:26b            # в блоке Parameters: temperature 0.3, top_p 0.9, ...
ollama ps
Select-String -Path "$env:LOCALAPPDATA\Ollama\server.log" -Pattern 'offloaded|spec-type|tg =' | Select-Object -Last 10
```

## Что НЕ решается этим скриптом

- `num_ctx` (окно контекста) приходит из Cline: поле **Context Window** модели Ollama
  (`contextWindow ?? maxInputTokens`), в логе это `llama-server ... -c 202752`.
  Хочешь окно 200k и скорость — бери MoE+MTP модель, а не плотную.
- `.clinerules` / `MANIFEST.md` — текст в промпт, параметры API не задают;
  правила честности оттуда лежат в `config\behavior.md` (раздел 1).
