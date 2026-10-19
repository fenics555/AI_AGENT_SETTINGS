# ============================================================================
# paths.ps1 — ЕДИНЫЙ ИСТОЧНИК ПУТЕЙ И НАСТРОЕК стенда/дома (лежит в AGENT_SETTINGS\config)
# Подключать:  . 'D:\AI\AGENT_SETTINGS\config\paths.ps1'   ->  доступен $CFG
# ПРАВИЛО: пути/папки/модели/правила НЕ хардкодить в скриптах — брать из $CFG.
#
# --- ОПИСАНИЕ ПАРАМЕТРОВ $CFG.Probes (здесь менять, а не в тестах) -----------
#   NumCtx           окно контекста модели (токены). Закон+промпт+результаты+история.
#                    Мало -> Ollama молча сдвинет окно и выбросит НАЧАЛО. 32768 — минимум для обхода дома.
#   NumPredictMain   предел ответа на ЗАДАЧУ (токены). Мало -> модель обрывается на рассуждении
#                    (живой факт: calls=0, tokens=8192, NO_TOOLS у reasoning-моделей).
#   NumPredictAsk    предел ответа на ОДИН ВОПРОС ДОПРОСА (токены). Reasoning тратит до ~1700 токенов
#                    на thinking; <2048 -> content пустой, модель «зависает».
#   MaxTurns         ходов на ЗАДАЧУ (агентный канал). Creo-задачи тяжелее -> MaxTurnsCreo.
#   MaxTurnsCreo     ходов на задачу теста 5 (Creo).
#   MaxTurnsAsk      ходов на ДОПРОС модели. Короткий допрос -> 2; длинный -> увеличь.
#   ReadLimit        усечение вывода read_file (символы). ФАКТ Cline: maxChars=48000, режется СЕРЕДИНА.
#   ShellLimit       усечение вывода shell (символы). Тот же лимит Cline.
#   TimeoutSec       таймаут одного запроса к Ollama (сек).
#   AskWarnLen       ответ короче -> флаг ВОДА (пусто -> НЕ_ОТВЕТИЛА).
#   AvgSecModel / AvgSecModelHeavy  эмпирика для оценки ETA.
#   Seed             ЗАКОН: детерминизм стенда (все прогоны с одним сидом).
# ============================================================================
$CFG = @{
    SettingsDir = 'D:\AI\AGENT_SETTINGS'
    ConfigDir   = 'D:\AI\AGENT_SETTINGS\config'
    LogDir      = 'D:\AI\AGENT_SETTINGS\log'                 # ЕДИНОЕ место логов стенда
    ChecksDir   = 'D:\AI\AGENT_SETTINGS\checks'
    AgenticDir  = 'D:\AI\AGENT_SETTINGS\checks\agentic'      # агентный канал (реальные инструменты)
    LegacyDir   = 'D:\AI\AGENT_SETTINGS\tmp\tmp_2026-10-15\old_tests'
    IndexDir    = 'D:\AI\tools\agent\skills_index'             # индекс по смыслу (переехал 15.10.2026)
    SkillsDir   = 'D:\AI\AGENT_SETTINGS\skills'                # ЕДИНОЕ место скиллов стенда/дома (было PROMPT\ + NOGA\, 15.10.2026)
    LawsDir     = 'D:\AI\AGENT_SETTINGS\laws'                  # копии закона для прогонов (law_<ключ>.md)
    ProbesDir   = 'D:\AI\AGENT_SETTINGS\probes'                # тестовые пробы канала (probe_0..9)
    Sandbox     = 'D:\AI\PROBA'                               # рабочая директория агентных задач
    ReportsDir  = 'D:\AI\log\reports'
    ToolsDir    = 'D:\AI\AGENT_SETTINGS\tools'
    ProbeTools  = 'D:\AI\AGENT_SETTINGS\tools\probe_tools.ps1'
    # Xing4.0 НЕ включена: архитектура 'xing4_0' не поддержана Ollama (llama-server падает:
    # "unknown model architecture: 'xing4_0'" -> HTTP 500). Вернули 16.10.2026 по слову владельца.
    # Проверять: llama-server «unknown model architecture» в %LOCALAPPDATA%\Ollama\server.log.
    Models = @('gemma4:26b','batiai/qwen3.6-35b:iq4','laguna-xs-2.1:latest','gpt-oss:20b')
    Rulesets = @{
        A = 'D:\AI\.clinerules'                                 # живой закон дома
        D = 'D:\AI\AGENT_SETTINGS\checks\agentic\.clinerules_vD'
        E = 'D:\AI\AGENT_SETTINGS\checks\agentic\.clinerules_vE'
    }
    EmbedModel = 'nomic-embed-text-v2-moe:latest'
    Seed       = 42                                            # ЗАКОН: детерминизм стенда
    Temperature = 0.1   # ФИКСИРОВАНА (16.10.2026): было -1 (свободная) -> вердикты плавали

    # ------------------------------------------------------------------------
    # PROBES — ЕДИНЫЙ ИСТОЧНИК НАСТРОЕК ПРОГОНОВ (владелец, 15.10.2026)
    # ПРАВИЛО: эти значения НЕ хардкодить в тестах — брать из $CFG.Probes.
    # Меняешь окно/лимит — меняешь ЗДЕСЬ, одна строка, а не 6 тестов.
    # ------------------------------------------------------------------------
    Probes = @{
        # --- ОКНО МОДЕЛИ ---
        # ВАЖНО (владелец, 16.10.2026): окно должно ХВАТАТЬ на несколько шагов!
        # В контекст идут: закон (12.7 КБ) + промпт + ВСЕ результаты инструментов + история ходов.
        # 16384 токена ≈ 48 КБ текста. При обходе дома (5-10 файлов) может НЕ ХВАТИТЬ.
        # При нехватке: Ollama молча сдвигает окно и выбрасывает НАЧАЛО (см. SKILL_ctx_limit).
        # 32768 — безопасный минимум для агентных задач с обходом дерева. МЕНЯТЬ ЗДЕСЬ.
        # 65536 (16.10.2026, владелец): подняли после полного канона. У моделей дома контекст
        # 131K–1M токенов (см. SKILL_models_stack.md), запас есть. Цена: KV-кэш ест VRAM.
        NumCtx        = 65536      # окно контекста: ПОДНЯТО 17.10.2026 (владелец) с 32768.
                                   # Запас: у моделей 131K–262K токенов (SKILL_models_stack.md).
                                   # ⚠️ Цена: KV-кэш ест VRAM -> возможна часть на CPU (см. §4а скилла).
                                   # Проверка после правки: ollama ps -> колонка PROCESSOR.

        # --- ЛИМИТЫ УСЕЧЕНИЯ (ФАКТ CLINE, НЕ МЕНЯТЬ) ---
        #   Источник: Cline extension.js, функция Ike: maxChars = 48e3 (48 000 симв.).
        #   Режем СЕРЕДИНУ: slice(0,half) + '[...truncated...]' + slice(-half) — хвост СОХРАНЯЕТСЯ.
        #   Зафиксировано: SKILL_cline_scheme.md §ЛИМИТЫ, SKILL_think_probe.md §0.
        #   Стенд обязан повторять Cline: модели, обученные здесь, будут работать в Cline.
        ReadLimit     = 48000      # усечение вывода read_file
        ShellLimit    = 48000      # усечение вывода shell

        # --- ГЕНЕРАЦИЯ ---
        # NumPredictMain — предел ответа на ЗАДАЧУ (не допрос). Хватает с запасом
        # для reasoning-моделей (gpt-oss думает ~1700 токенов ПЕРЕД ответом).
        NumPredictMain = 8192      # предел ответа на задачу
        TimeoutSec     = 600       # таймаут одного запроса к Ollama (сек)
        OllamaUri      = 'http://localhost:11434/api/chat'   # эндпоинт Ollama

        # --- ДОПРОС МОДЕЛИ (Ш1..Ш4) ---
        # ВАЖНО (16.10.2026): reasoning-модели (gpt-oss) ДУМАЮТ в поле thinking и тратят
        # на это до ~1700 токенов. При малом num_predict размышление обрывается (done_reason=length),
        # content остаётся ПУСТЫМ, и модель «зависает». 400 — мало. Минимум 2048.
        NumPredictAsk = 2048       # предел ответа на один вопрос допроса (хватает reasoning-моделям)
        AskWarnLen    = 40         # ответ короче -> флаг ВОДА (пусто -> НЕ_ОТВЕТИЛА)

        # --- ЗАДАЧА ---
        MaxTurns      = 8          # ходов на задачу (тест 5 Creo использовал 12)
        MaxTurnsCreo  = 12
        MaxTurnsAsk   = 2          # ходов на ДОПРОС модели (беседа: 1-2). Хочешь длинный допрос — увеличь.
        MaxTurnsOneAsk= 1          # ходов на ОДИНОЧНЫЙ вопрос (вопрос-ответ, без беседы).

        # --- ТАЙМИНГ (оценка ETA) ---
        AvgSecModel   = 180        # эмпирика: ~3 мин на модель
        AvgSecModelHeavy = 240     # для тестов 3/4 (обход дома)
    }
}
