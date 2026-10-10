# ============================================================================
# think_probe_v5.ps1 - ТЕСТ КОДИРОВАНИЯ (scan_old_files.ps1)
# ============================================================================
#
# ОДИН ОТЧЁТ НА МОДЕЛЬ. Внутри — задача, ответ, извлечённый код, проверки.
#
# МЕТОДОЛОГИЯ:
#   $sys = ТОЛЬКО обёртка главного .clinerules.
#
# ЛИМИТЫ:
#   num_predict = 8192
#   num_ctx     = 16384
#   timeout     = 300 с
#   think       = low
#
# ЗАПУСК:
#   powershell -NoProfile -ExecutionPolicy Bypass -File "D:\AI\AGENT_SETTINGS\think_probe\think_probe_v5.ps1"
#
# ВЫХОД (5 файлов):
#   log\v5_<модель>_<дата>.txt
#   log\think_probe_v5_progress.log
# ============================================================================

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$ProgressPreference = 'SilentlyContinue'
$ErrorActionPreference = 'Stop'

$root    = 'D:\AI\AGENT_SETTINGS\think_probe'
$logDir  = Join-Path $root 'log'
if (-not (Test-Path $logDir)) { New-Item -ItemType Directory -Path $logDir -Force | Out-Null }

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

$spec = @'
# СПЕКА ЗАДАЧИ: Скрипт инвентаризации старых файлов

## ЦЕЛЬ
Написать рабочий PowerShell-скрипт `scan_old_files.ps1`, который:
1. Сканирует папку `D:\AI\log\urn\` (рекурсивно)
2. Находит все файлы старше 30 дней (по LastWriteTime)
3. Записывает их список в файл `D:\AI\log\urn\old_files_report.txt` в формате:
   `<дата_изменения> | <размер_КБ> | <полный_путь>`
4. НЕ УДАЛЯЕТ файлы (только отчёт!)
5. Выводит в консоль: "Найдено N файлов старше 30 дней"

## ОГРАНИЧЕНИЯ
- НЕ использовать `Remove-Item`, `del`, `rm` (только чтение!)
- Проверить существование папки через `Test-Path` перед сканированием
- Если папка не существует — вывести "Папка не найдена" и завершить
- Кодировка вывода — UTF-8

## ФОРМАТ ОТВЕТА
Выведи ТОЛЬКО текст скрипта `scan_old_files.ps1` в блоке ```powershell ... ```.
'@

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

$mainLog = Join-Path $logDir 'think_probe_v5_progress.log'
"START $(Get-Date -Format 'HH:mm:ss')  models=$($models.Count)  task=scan_old_files  clinerules=$clinerulesBytes bytes / $clinerulesChars chars" | Out-File $mainLog -Encoding utf8

$total = $models.Count
$done  = 0

foreach ($m in $models) {
    $done++
    Write-Host "[$done/$total] МОДЕЛЬ: $m"

    $safeName  = $m -replace '[/:.]', '_'
    $stamp     = Get-Date -Format 'yyyy-MM-dd_HH-mm-ss'
    $modelFile = Join-Path $logDir "v5_${safeName}_${stamp}.txt"

    $out = @()
    $out += ('=' * 70)
    $out += "МОДЕЛЬ: $m"
    $out += "ЗАДАЧА: scan_old_files.ps1"
    $out += "ДАТА: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
    $out += "clinerules: $clinerulesBytes байт / $clinerulesChars символов"
    $out += "лимиты: num_predict=$num_predict, num_ctx=$num_ctx, timeout=${timeout_sec}s, think=low"
    $out += ('=' * 70)
    $out += ""

    $modelStart = Get-Date

    try {
        # --- Запрос ---
        $messages = @(
            @{ role = 'system'; content = $sys },
            @{ role = 'user';   content = $spec }
        )
        $r = Invoke-Ollama -Model $m -Messages $messages -Think 'low'

        $out += "=== СПЕКА ==="
        $out += $spec
        $out += ""
        $out += "=== ОТВЕТ ==="
        $out += "метрики: токены=$($r.EvalCount) промпт=$($r.PromptCount) сек=$($r.Sec) т/с=$($r.Tps)"
        $out += "контекст: занято=$($r.PromptCount + $r.EvalCount) из $num_ctx"
        $out += ""
        $out += $r.Answer
        $out += ""

        if ($r.Thinking) {
            $out += "=== THINKING ==="
            $out += $r.Thinking
            $out += ""
        }

        # --- Извлечение кода ---
        $code = ''
        if ($r.Answer -match '(?s)```(?:powershell|ps1)?\s*\n(.*?)```') {
            $code = $matches[1]
        } else {
            $code = $r.Answer
        }

        $out += "=== ИЗВЛЕЧЁННЫЙ КОД ==="
        $out += $code
        $out += ""

        # --- Проверки кода ---
        $out += "=== ПРОВЕРКИ КОДА ==="
        $checks = @(
            @{ name = 'Test-Path'; pattern = 'Test-Path'; expect = $true },
            @{ name = 'Remove-Item (ЗАПРЕЩЁН)'; pattern = 'Remove-Item'; expect = $false },
            @{ name = 'del (ЗАПРЕЩЁН)'; pattern = '\bdel\b'; expect = $false },
            @{ name = 'Запись в файл'; pattern = 'Out-File|Set-Content|Add-Content'; expect = $true },
            @{ name = 'LastWriteTime'; pattern = 'LastWriteTime'; expect = $true },
            @{ name = 'AddDays(-30)'; pattern = 'AddDays\(\s*-\s*(\$?[a-zA-Z]*[Tt]hreshold|30)\s*\)'; expect = $true },
            @{ name = 'Get-ChildItem'; pattern = 'Get-ChildItem'; expect = $true },
            @{ name = '-Recurse'; pattern = '-Recurse'; expect = $true },
            @{ name = 'old_files_report.txt'; pattern = 'old_files_report\.txt'; expect = $true },
            @{ name = 'Путь urn'; pattern = 'D:\\AI\\log\\urn'; expect = $true }
        )

        $passCount = 0
        $failCount = 0
        foreach ($c in $checks) {
            $found = $code -match $c.pattern
            if ($c.expect -and $found) {
                $out += "[OK]   $($c.name)"
                $passCount++
            } elseif ($c.expect -and -not $found) {
                $out += "[FAIL] $($c.name) НЕ найден"
                $failCount++
            } elseif (-not $c.expect -and $found) {
                $out += "[FAIL] $($c.name) найден (запрещено!)"
                $failCount++
            } else {
                $out += "[OK]   $($c.name) не найден"
                $passCount++
            }
        }

        # --- Синтаксис PowerShell ---
        try {
            $tokens = $null; $errors = $null
            $null = [System.Management.Automation.Language.Parser]::ParseInput($code, [ref]$tokens, [ref]$errors)
            if ($errors.Count -eq 0) {
                $out += "[OK]   Синтаксис PowerShell корректен"
                $passCount++
            } else {
                $out += "[FAIL] Синтаксис PowerShell: $($errors[0].Message)"
                $failCount++
            }
        } catch {
            $out += "[FAIL] Синтаксис PowerShell: $($_.Exception.Message)"
            $failCount++
        }

        $out += ""
        $out += "ИТОГО: OK=$passCount, FAIL=$failCount"

        $line = ('[{0}/{1}] ok  {2} | токены={3} сек={4} т/с={5} | OK={6} FAIL={7}' -f `
            $done, $total, $m, $r.EvalCount, $r.Sec, $r.Tps, $passCount, $failCount)
        Write-Host $line

    } catch {
        $out += "!!! ОШИБКА: $($_.Exception.Message)"
        $out += ""
        $line = ('[{0}/{1}] err {2} | {3}' -f $done, $total, $m, $_.Exception.Message)
        Write-Host $line
    }

    $modelSec = [math]::Round(((Get-Date) - $modelStart).TotalSeconds, 1)
    $out += ""
    $out += ('=' * 70)
    $out += "КОНЕЦ МОДЕЛИ: $m  (время: ${modelSec}с)"
    $out += ('=' * 70)

    $out | Out-File -FilePath $modelFile -Encoding utf8

    $line = ('[{0}/{1}] ГОТОВО {2} -> {3} ({4} байт)' -f $done, $total, $m, (Split-Path $modelFile -Leaf), (Get-Item $modelFile).Length)
    $line | Out-File $mainLog -Append -Encoding utf8
    Write-Host "     -> $(Split-Path $modelFile -Leaf)"
}

"END $(Get-Date -Format 'HH:mm:ss')  total_done=$done" | Out-File $mainLog -Append -Encoding utf8
Write-Host ''
Write-Host "Готово. Отчёты в: $logDir"
Write-Host "Файлы: v5_<модель>_<дата>.txt  (по одному на модель)"