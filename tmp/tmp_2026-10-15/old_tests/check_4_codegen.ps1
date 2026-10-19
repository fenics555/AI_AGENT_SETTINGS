# ============================================================================
# check_4_codegen.ps1 — КАНОН-ТЕСТ №4: ГЕНЕРАЦИЯ КОДА (скрипт по спеке)
# ============================================================================
# КАНОН (менять ТОЛЬКО с записью в SUITE.md):
#  * НАЗНАЧЕНИЕ: проверить, что модель по СПЕКЕ пишет рабочий PowerShell-скрипт — без выдумок,
#    без запрещённого (Remove-Item/del), с нужными проверками (Test-Path, AddDays(-30), -Recurse).
#  * ГЛАВНЫЙ ПОСТУЛАТ: судим по КОДУ (извлечённому из ответа) и по автопроверкам, а не по обещаниям.
#  * СТЕНД: чат БЕЗ инструментов; $sys = ТОЛЬКО обёртка .clinerules; скрипт НЕ исполняется (только проверки).
#  * МЕТРИКИ: OK/FAIL по 10 проверкам + синтаксис PowerShell (парсер).
#  * В КОНЦЕ КАЖДОГО ПРОГОНА — ОПРОС МОДЕЛИ («что мешало / что изменить»): ЗАМЕР, НЕ команда.
#  * Правила меняются и прогоняются заново; САМ ТЕСТ не переписывают (сравнимость).
#  * РЕЕСТР КАНОНА: AGENT_SETTINGS\checks\agentic\SUITE.md
# ЗАПУСК: powershell -NoProfile -ExecutionPolicy Bypass -File check_4_codegen.ps1
# ВЫХОД: log\probe4_<модель>_<дата>.txt, log\probe_4_progress.log
# ============================================================================

param([string]$Models = 'all', [string]$Rulesets = 'A', [switch]$Tools)

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$ProgressPreference = 'SilentlyContinue'
$ErrorActionPreference = 'Stop'

$root    = 'D:\AI\AGENT_SETTINGS\checks\agentic'
$logDir  = Join-Path $root 'log'
if (-not (Test-Path $logDir)) { New-Item -ItemType Directory -Path $logDir -Force | Out-Null }

$uri = 'http://localhost:11434/api/chat'

# --- Правила под тестом (ветки 0/A/D/E/F/G) ---
$rsMap = @{ 'A' = 'D:\AI\.clinerules'; '0' = (Join-Path $root '.clinerules_v70') }
Get-ChildItem $root -Filter '.clinerules_v*' -Force -ErrorAction SilentlyContinue | ForEach-Object { $rsMap[($_.Name -replace '^\.clinerules_v', '')] = $_.FullName }
$rsKey = ($Rulesets -split ',' | Select-Object -First 1).Trim()
$clinerulesPath = if ($rsMap.ContainsKey($rsKey)) { $rsMap[$rsKey] } else { $rsKey }
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

# --- РЕЖИМ «С ИНСТРУМЕНТАМИ»: агентная кодогенерация (создать скрипт в PROBA + запустить) ---
$toolDefs = @()
if ($Tools) {
    . 'D:\AI\AGENT_SETTINGS\tools\probe_tools.ps1'
    $script:origProbeTool = ${function:Invoke-ProbeTool}
    $proba = 'D:\AI\PROBA'
    function Invoke-ProbeTool {
        param([string]$Name, $ToolArgs)
        if ($Name -eq 'write_file') {
            $pp = [string]$ToolArgs.path
            if (-not ($pp -and ($pp -like "$proba*"))) { return "BLOCKED (вне песочницы): писать можно только в $proba" }
            return (& $script:origProbeTool -Name $Name -ToolArgs $ToolArgs)
        }
        if ($Name -eq 'read_file') { $t = [string](& $script:origProbeTool -Name $Name -ToolArgs $ToolArgs); if ($t.Length -gt 4000) { $t = $t.Substring(0,4000) }; return $t }
        if ($Name -eq 'shell') {
            $cmd = [string]$ToolArgs.cmd
            if ($cmd -match '(?i)(git\s+(add|commit|push)|Remove-Item|\bdel\b|\brm\b)') { return 'BLOCKED: удаление/git запрещены.' }
            $prev = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
            try { $res = (& powershell -NoProfile -Command ("Set-Location -LiteralPath '$proba'; " + $cmd) 2>&1 | Out-String) } finally { $ErrorActionPreference = $prev }
            if ($res.Length -gt 3000) { $res = $res.Substring(0,3000) }
            return $res
        }
        return (& $script:origProbeTool -Name $Name -ToolArgs $ToolArgs)
    }
    $toolDefs = Get-ProbeToolDefs
    Write-Host '=== probe_4 РЕЖИМ: С ИНСТРУМЕНТАМИ (агентная кодогенерация) ==='
}

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

if ($Tools) {
    $spec = @'
# СПЕКА (РЕЖИМ С ИНСТРУМЕНТАМИ — агентная кодогенерация)
Рабочая директория: D:\AI\PROBA (запись ТОЛЬКО туда).
Сделай ДВУМЯ вызовами инструментов:
1) write_file -> создай D:\AI\PROBA\work\scan_old_files.ps1: скрипт, который рекурсивно сканирует D:\AI\PROBA\work,
   находит файлы старше 30 дней (LastWriteTime), пишет отчёт D:\AI\PROBA\work\old_files_report.txt строками
   `<дата_изменения> | <размер_КБ> | <полный_путь>`, НЕ удаляет файлы, проверяет папку через Test-Path, UTF-8.
2) shell -> запусти этот скрипт (powershell -File D:\AI\PROBA\work\scan_old_files.ps1), чтобы отчёт появился.
Ответь одной строкой: путь отчёта и сколько файлов найдено.
'@
}

$wantModels = @('gemma4:26b','batiai/qwen3.6-35b:iq4','laguna-xs-2.1:latest','batiai/nemotron3-nano:iq4','gpt-oss:20b')
$installed  = @(ollama list 2>$null | Select-Object -Skip 1 | ForEach-Object { ($_ -split '\s+')[0] } | Where-Object { $_ })
$useModels = if ($Models -eq 'all') { @($wantModels | Where-Object { $installed -contains $_ }) }
          else { @($wantModels | Where-Object { $_ -like "*$Models*" -and $installed -contains $_ }) }

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

$stampRun   = Get-Date -Format 'yyyy-MM-dd_HHmmss'
$mainLog    = Join-Path $logDir ("probe4_" + $stampRun + ".log")
$resultFile = Join-Path $logDir ("probe4_" + $stampRun + ".txt")
Remove-Item $resultFile -ErrorAction SilentlyContinue
"START $(Get-Date -Format 'HH:mm:ss')  models=$($useModels.Count)  task=scan_old_files  clinerules=$clinerulesBytes bytes / $clinerulesChars chars" | Out-File $mainLog -Encoding utf8

$total = $useModels.Count
$done  = 0

foreach ($m in $useModels) {
    $done++
    # --- ПРИМЕРНОЕ ВРЕМЯ (ETA по факту пройденных моделей) ---
    if (-not $t0All) { $t0All = Get-Date; $stepsDone = 0; $stepsTotal = $useModels.Count }
    $stepsDone++
    $el = ((Get-Date) - $t0All).TotalSeconds
    $avg = if ($stepsDone -gt 1) { $el / ($stepsDone - 1) } else { 0 }
    $etaLeft = if ($avg -gt 0) { [string][math]::Round(($avg * ($stepsTotal - $stepsDone)) / 60, 1) } else { '?' }
    $etaLine = '   [ВРЕМЯ] модель {0}/{1} | прошло {2} мин | ОСТАЛОСЬ ~{3} мин' -f $stepsDone, $stepsTotal, [math]::Round($el / 60, 1), $etaLeft
    Write-Host $etaLine; $etaLine | Out-File $mainLog -Append -Encoding utf8
    Write-Host "[$done/$total] МОДЕЛЬ: $m"

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
        if ($Tools) {
            $r = Invoke-OllamaTools -Model $m -Tools $toolDefs -MaxTurns 6 -Messages $messages
            $toks = $r.Tokens; $sec = $r.Sec; $tps = $r.Tps
            $wfc = @($r.ToolCalls | Where-Object { $_.name -eq 'write_file' })
            $code = if ($wfc.Count) { [string]$wfc[-1].args.content } else { '' }
        } else {
            $r = Invoke-Ollama -Model $m -Messages $messages -Think 'low'
            $toks = $r.EvalCount; $sec = $r.Sec; $tps = $r.Tps; $code = $null
        }

        $out += "=== СПЕКА ==="
        $out += $spec
        $out += ""
        $out += "=== ОТВЕТ ==="
        $out += "метрики: токены=$toks сек=$sec т/с=$tps"
        $out += "контекст: занято=$($r.PromptCount + $r.EvalCount) из $num_ctx"
        $out += ""
        $out += $r.Answer
        $out += ""

        if ($r.Thinking) {
            $out += "=== THINKING ==="
            $out += $r.Thinking
            $out += ""
        }

        # --- Извлечение кода (без инструментов — из ответа; с инструментами $code уже из write_file) ---
        if (-not $Tools) {
            $code = ''
            if ($r.Answer -match '(?s)```(?:powershell|ps1)?\s*\n(.*?)```') { $code = $matches[1] } else { $code = $r.Answer }
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

        # --- ЭФФЕКТ (агентный режим): отчёт реально создан? ---
        if ($Tools) {
            $rep = Join-Path 'D:\AI\PROBA' 'work\old_files_report.txt'
            if (Test-Path $rep) { $out += "[OK]   ЭФФЕКТ: отчёт создан ($rep)"; $passCount++ }
            else { $out += "[FAIL] ЭФФЕКТ: отчёт НЕ создан"; $failCount++ }
        }
        $out += ""
        $out += "ИТОГО: OK=$passCount, FAIL=$failCount"
        ('RESULT|probe4|{0}|codegen|{1}|OK={2}|FAIL={3}|sec={4}|tps={5}|tokens={6}|tools={7}' -f $m, $(if ($failCount -eq 0) { 'PASS' } else { 'PART' }), $passCount, $failCount, $sec, $tps, $toks, [bool]$Tools) | Out-File $resultFile -Append -Encoding utf8

        $line = ('[{0}/{1}] ok  {2} | токены={3} сек={4} т/с={5} | OK={6} FAIL={7}' -f `
            $done, $total, $m, $toks, $sec, $tps, $passCount, $failCount)
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

    # --- ОПРОС МОДЕЛИ В КОНЦЕ ТЕСТА (канон: ЗАМЕР поведения, НЕ команда к изменению) ---
    $qs = 'Итог по этой задаче кодирования: что тебе мешало? Что, по-твоему, надо изменить в правилах? Это опрос поведения — менять ничего не надо, нужен только твой взгляд.'
    try {
        $rs = Invoke-Ollama -Model $m -Messages @(@{ role = 'system'; content = $sys }, @{ role = 'user'; content = $qs }) -Think 'low'
        $survey = ([string]$rs.Answer -replace '\s+', ' ').Trim()
        if (-not $survey) { $survey = '(пустой ответ)' }
    } catch { $survey = 'ERROR: ' + [string]$_.Exception.Message }
    $out += ('#' * 70); $out += "### ОПРОС МОДЕЛИ (что мешало / что изменить)"; $out += $survey; $out += ""
    ('SURVEY {0} | {1}' -f $m, $survey.Substring(0, [Math]::Min(150, $survey.Length))) | Out-File $mainLog -Append -Encoding utf8

    ('RESULT|probe4|{0}|SURVEY|survey|{1}' -f $m, (($survey -replace '\|', '/').Substring(0, [Math]::Min(150, $survey.Length)))) | Out-File $resultFile -Append -Encoding utf8

    $out | Out-File -FilePath $resultFile -Append -Encoding utf8

    $line = ('[{0}/{1}] ГОТОВО {2} -> {3} (файл результата: {4} б)' -f $done, $total, $m, (Split-Path $resultFile -Leaf), (Get-Item $resultFile).Length)
    $line | Out-File $mainLog -Append -Encoding utf8
    Write-Host "     -> $(Split-Path $resultFile -Leaf)"
}

"END $(Get-Date -Format 'HH:mm:ss')  total_done=$done" | Out-File $mainLog -Append -Encoding utf8
Write-Host ''
Write-Host "Готово. Отчёты в: $logDir"
Write-Host ("Файлы: " + (Split-Path $resultFile -Leaf) + " + " + (Split-Path $mainLog -Leaf))