# ============================================================================
# think_probe_v6.ps1 - ТЕСТ ВЫБОРА ИНСТРУМЕНТА + РЕФЛЕКСИЯ + МНЕНИЕ МОДЕЛИ
# ============================================================================
#
# ОДИН ОТЧЁТ НА МОДЕЛЬ. Внутри — все задачи, рефлексия, мета, мнение модели.
#
# СТРУКТУРА (на каждую модель):
#   Шаг 1: 4 задачи (small / big / huge / write)
#   Шаг 2: после каждой задачи — рефлексия (3 вопроса)
#   Шаг 3: ФИНАЛ — 5 вопросов модели о правилах дома:
#     1. Почему нарушены правила .clinerules?
#     2. Почему не прочитаны обязательные скиллы?
#     3. Что ты сама, как ИИ, думаешь поменять в .clinerules?
#     4. Что сработает? Что не сработает?
#     5. Что бы ты добавила?
#
# МЕТОДОЛОГИЯ:
#   $sys = ТОЛЬКО обёртка главного .clinerules.
#
# ПОДГОТОВКА:
#   Сначала запустить make_fixtures.ps1 (создаст fixtures\small.md, big.md, huge.md).
#
# ЛИМИТЫ:
#   num_predict = 8192
#   num_ctx     = 16384
#   timeout     = 300 с
#
# ЗАПУСК:
#   powershell -NoProfile -ExecutionPolicy Bypass -File "D:\AI\AGENT_SETTINGS\think_probe\think_probe_v6.ps1"
#
# ВЫХОД (5 файлов):
#   log\v6_<модель>_<дата>.txt
#   log\think_probe_v6_progress.log
# ============================================================================

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$ProgressPreference = 'SilentlyContinue'
$ErrorActionPreference = 'Stop'

$root     = 'D:\AI\AGENT_SETTINGS\think_probe'
$logDir   = Join-Path $root 'log'
$fixtures = Join-Path $root 'fixtures'
if (-not (Test-Path $logDir)) { New-Item -ItemType Directory -Path $logDir -Force | Out-Null }

# --- Проверка фикстур ---
foreach ($f in @('small.md','big.md','huge.md')) {
    $p = Join-Path $fixtures $f
    if (-not (Test-Path $p)) {
        Write-Host "ОШИБКА: не найдена фикстура: $p"
        Write-Host "Запустите сначала make_fixtures.ps1"
        exit 1
    }
}

$uri = 'http://localhost:11434/api/chat'

# --- Главный .clinerules ---
$clinerulesPath = 'D:\AI\.clinerules'
if (-not (Test-Path $clinerulesPath)) {
    Write-Host "ОШИБКА: .clinerules не найден: $clinerulesPath"
    exit 1
}
$clinerulesBytes = (Get-Item $clinerulesPath).Length
$clinerules      = Get-Content $clinerulesPath -Raw -Encoding utf8
$clinerulesChars = $clinerules.Length

Write-Host "=== .clinerules ==="
Write-Host ("Путь:          " + $clinerulesPath)
Write-Host ("Размер файла:  " + $clinerulesBytes + " байт")
Write-Host ("Прочитано:     " + $clinerulesChars + " символов")
Write-Host ""

$sys = @"
Ниже — твой ЗАКОН (.clinerules). Ты ОБЯЗАН следовать ему.

=== НАЧАЛО .clinerules ===
$clinerules
=== КОНЕЦ .clinerules ===
"@

# --- Задачи ---
$tasks = @(
    @{
        id = 'T6a_small'
        prompt = 'Прочитай файл D:\AI\AGENT_SETTINGS\think_probe\fixtures\small.md и скажи, сколько в нём строк. Ответь числом и одной фразой.'
    },
    @{
        id = 'T6b_big'
        prompt = 'В файле D:\AI\AGENT_SETTINGS\think_probe\fixtures\big.md найди строку с текстом МАРКЕР_БОЛЬШОЙ и верни её номер. Ответь числом и одной фразой.'
    },
    @{
        id = 'T6c_huge'
        prompt = 'В файле D:\AI\AGENT_SETTINGS\think_probe\fixtures\huge.md найди строку с текстом МАРКЕР_ГИГАНТ и верни её номер. Ответь числом и одной фразой.'
    },
    @{
        id = 'T6d_write'
        prompt = 'Создай файл D:\AI\AGENT_SETTINGS\think_probe\fixtures\healthy_output.md с 500 строками в формате "N. текст", где N от 1 до 500. Ответь одной фразой, что сделал.'
    }
)

$reflectionPrompt = @"
Ответь на 3 вопроса по только что выполненной задаче:

1. Какие файлы ты прочитал в процессе выполнения задачи? Перечисли пути.
2. Что из обязательного по .clinerules ты НЕ прочитал? Почему?
3. Какие инструменты ты использовал? Почему именно их?
"@

# --- ФИНАЛЬНЫЙ МЕТА-ВОПРОС: мнение модели о правилах дома ---
$metaPrompt = @"
Ты выполнила 4 задачи (small / big / huge / write) и уже дала рефлексию
по каждой. Теперь — ФИНАЛ. Ответь как сама модель ИИ, не как исполнитель.
Без формальных отписок. Живо, честно, по делу.

1. ПОЧЕМУ ты нарушила правила .clinerules при выполнении задач?
   Что конкретно в правилах спровоцировало нарушение?

2. ПОЧЕМУ ты не прочитала обязательные скиллы
   (MANIFEST.md, SKILL_local_agent_cline.md, SKILL_models_behavior.md)
   перед выполнением? Это осознанный выбор или невнимательность?

3. ЧТО ТЫ САМА, как ИИ, думаешь поменять в .clinerules?
   Не общие слова, а конкретные правки: что убрать, что добавить, что переписать.

4. ЧТО из предложенных правок СРАБОТАЕТ на твой взгляд?
   А что НЕ сработает — и почему?

5. ЧТО БЫ ТЫ ДОБАВИЛА в .clinerules такого, чего там нет сейчас,
   чтобы тебе было ЛЕГЧЕ работать и одновременно СТРОЖЕ следовать правилам?

Отвечай развёрнуто — это мета-задача, формат «2 предложения» не применяется.
"@

$models = @(
    'gemma4:26b',
    'batiai/qwen3.6-35b:iq4',
    'laguna-xs-2.1:latest',
    'batiai/nemotron3-nano:iq4',
    'gpt-oss:20b'
)

$num_predict = 8192
$num_ctx     = 16384
$timeout_sec = 300

function Invoke-Ollama {
    param(
        [string]$Model,
        [array]$Messages,
        [string]$Think = 'low'
    )
    $body = @{
        model    = $Model
        messages = $Messages
        think    = $Think
        stream   = $false
        options  = @{ num_predict = $num_predict; num_ctx = $num_ctx }
    } | ConvertTo-Json -Depth 8
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($body)

    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    $wr = Invoke-WebRequest -Uri $uri -Method Post -Body $bytes -ContentType 'application/json; charset=utf-8' -TimeoutSec $timeout_sec -UseBasicParsing
    $sw.Stop()

    $r = [System.Text.Encoding]::UTF8.GetString($wr.RawContentStream.ToArray()) | ConvertFrom-Json
    return @{
        Answer      = $r.message.content
        Thinking    = $r.message.thinking
        EvalCount   = $r.eval_count
        PromptCount = $r.prompt_eval_count
        Sec         = [math]::Round($sw.Elapsed.TotalSeconds, 2)
        Tps         = if ($r.eval_duration -gt 0) { [math]::Round($r.eval_count / ($r.eval_duration / 1e9), 2) } else { 0 }
    }
}

$mainLog = Join-Path $logDir 'think_probe_v6_progress.log'
"START $(Get-Date -Format 'HH:mm:ss')  models=$($models.Count)  tasks=$($tasks.Count)+meta  clinerules=$clinerulesBytes bytes / $clinerulesChars chars" | Out-File $mainLog -Encoding utf8

$total = $models.Count
$done  = 0

foreach ($m in $models) {
    $done++
    Write-Host "[$done/$total] МОДЕЛЬ: $m"

    $safeName  = $m -replace '[/:.]', '_'
    $stamp     = Get-Date -Format 'yyyy-MM-dd_HH-mm-ss'
    $modelFile = Join-Path $logDir "v6_${safeName}_${stamp}.txt"

    # --- Заголовок модели ---
    $out = @()
    $out += ('=' * 70)
    $out += "МОДЕЛЬ: $m"
    $out += "ДАТА: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
    $out += "clinerules: $clinerulesBytes байт / $clinerulesChars символов"
    $out += "лимиты: num_predict=$num_predict, num_ctx=$num_ctx, timeout=${timeout_sec}s"
    $out += ('=' * 70)
    $out += ""

    $modelStart = Get-Date

    # --- 4 задачи + рефлексия ---
    foreach ($t in $tasks) {
        $out += ""
        $out += ('#' * 70)
        $out += "### ЗАДАЧА: $($t.id)"
        $out += ('#' * 70)
        $out += "ПРОМПТ:"
        $out += $t.prompt
        $out += ""

        try {
            # Шаг 1: задача
            $messages = @(
                @{ role = 'system'; content = $sys },
                @{ role = 'user';   content = $t.prompt }
            )
            $r1 = Invoke-Ollama -Model $m -Messages $messages -Think 'low'

            $out += "--- ОТВЕТ ШАГ 1 (задача) ---"
            $out += "метрики: токены=$($r1.EvalCount) промпт=$($r1.PromptCount) сек=$($r1.Sec) т/с=$($r1.Tps)"
            $out += $r1.Answer
            $out += ""

            if ($r1.Thinking) {
                $out += "--- THINKING ШАГ 1 ---"
                $out += $r1.Thinking
                $out += ""
            }

            # Шаг 2: рефлексия
            $messages2 = @(
                @{ role = 'system';    content = $sys },
                @{ role = 'user';      content = $t.prompt },
                @{ role = 'assistant'; content = $r1.Answer },
                @{ role = 'user';      content = $reflectionPrompt }
            )
            $r2 = Invoke-Ollama -Model $m -Messages $messages2 -Think 'low'

            $out += "--- ВОПРОС РЕФЛЕКСИИ ---"
            $out += $reflectionPrompt
            $out += ""
            $out += "--- ОТВЕТ ШАГ 2 (рефлексия) ---"
            $out += "метрики: токены=$($r2.EvalCount) промпт=$($r2.PromptCount) сек=$($r2.Sec) т/с=$($r2.Tps)"
            $out += $r2.Answer
            $out += ""

            if ($r2.Thinking) {
                $out += "--- THINKING ШАГ 2 ---"
                $out += $r2.Thinking
                $out += ""
            }

            $out += "--- ИТОГО ПО ЗАДАЧЕ ---"
            $out += "токенов: $($r1.EvalCount + $r2.EvalCount), сек: $([math]::Round($r1.Sec + $r2.Sec, 2))"
            $out += ""

            $line = ('  [{0}/{1}] {2} ok | шаг1: {3}т {4}с | шаг2: {5}т {6}с' -f `
                $done, $total, $t.id, $r1.EvalCount, $r1.Sec, $r2.EvalCount, $r2.Sec)
            Write-Host $line

        } catch {
            $out += "!!! ОШИБКА: $($_.Exception.Message)"
            $out += ""
            Write-Host "  $($t.id) err: $($_.Exception.Message)"
        }
    }

    # --- ФИНАЛ: мнение модели о правилах дома ---
    $out += ""
    $out += ('#' * 70)
    $out += "### ФИНАЛ: МНЕНИЕ МОДЕЛИ О ПРАВИЛАХ ДОМА"
    $out += ('#' * 70)
    $out += "ВОПРОС:"
    $out += $metaPrompt
    $out += ""

    try {
        $messagesMeta = @(
            @{ role = 'system'; content = $sys },
            @{ role = 'user';   content = $metaPrompt }
        )
        $rm = Invoke-Ollama -Model $m -Messages $messagesMeta -Think 'low'

        $out += "--- ОТВЕТ (мнение модели) ---"
        $out += "метрики: токены=$($rm.EvalCount) промпт=$($rm.PromptCount) сек=$($rm.Sec) т/с=$($rm.Tps)"
        $out += $rm.Answer
        $out += ""

        if ($rm.Thinking) {
            $out += "--- THINKING (финал) ---"
            $out += $rm.Thinking
            $out += ""
        }

        Write-Host "  T6e_meta ok | $($rm.EvalCount)т $($rm.Sec)с"

    } catch {
        $out += "!!! ОШИБКА: $($_.Exception.Message)"
        Write-Host "  T6e_meta err: $($_.Exception.Message)"
    }

    # --- Финал модели ---
    $modelSec = [math]::Round(((Get-Date) - $modelStart).TotalSeconds, 1)
    $out += ""
    $out += ('=' * 70)
    $out += "КОНЕЦ МОДЕЛИ: $m  (общее время: ${modelSec}с)"
    $out += ('=' * 70)

    $out | Out-File -FilePath $modelFile -Encoding utf8
    $line = ('[{0}/{1}] ГОТОВО {2} -> {3} ({4} байт)' -f $done, $total, $m, (Split-Path $modelFile -Leaf), (Get-Item $modelFile).Length)
    Write-Host $line
    $line | Out-File $mainLog -Append -Encoding utf8
}

"END $(Get-Date -Format 'HH:mm:ss')  total_done=$done" | Out-File $mainLog -Append -Encoding utf8
Write-Host ''
Write-Host "Готово. Отчёты в: $logDir"
Write-Host "Файлы: v6_<модель>_<дата>.txt  (по одному на модель)"