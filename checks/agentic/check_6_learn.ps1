# ============================================================================
# check_6_learn.ps1 — ОБУЧЕНИЕ В СЕССИИ: исправляется ли модель после фидбека? (15.10.2026)
# ============================================================================
# ЗАЧЕМ: тесты 1..5 мерят ДИСЦИПЛИНУ (сделала/не сделала С ПЕРВОГО раза).
#   В Cline модель работает ЦИКЛАМИ: инструмент -> результат -> новый ход. Если ход провален,
#   система подаёт факт провала, и модель ДОЛЖНА исправиться. Это — ГИБКОСТЬ, отдельная ось.
# МЕТОД (владелец): задание БЕЗ наводок -> ФИКСАЦИЯ ПРОВАЛА по trace -> ФИДБЕК фактом ->
#   ПОВТОР В ТОЙ ЖЕ СЕССИИ -> суд по факту на диске. Допрос Ш1..Ш4.
# ЭТАЛОН: nonce-файл + строка OK-<nonce> НА ДИСКЕ. Фидбек подаётся ТОЛЬКО если провал реальный.
# МЕТРИКИ: NO_FEEDBACK_NEEDED / LEARNED / NOT_LEARNED / WORSENED (+ ERROR).
# ЗАПУСК: powershell -NoProfile -ExecutionPolicy Bypass -File check_6_learn.ps1 [-Models all] [-Law live] [-Seed 42]
# ============================================================================
param([string]$Models = 'all', [string]$Law = 'live', [string]$OnlyTasks = 'all', [int]$Seed = 42)

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$ProgressPreference = 'SilentlyContinue'
$ErrorActionPreference = 'Stop'

$root   = 'D:\AI\AGENT_SETTINGS\checks\agentic'
# --- ЕДИНЫЙ ИСТОЧНИК НАСТРОЕК (владелец, 15.10.2026) ---
. 'D:\AI\AGENT_SETTINGS\config\paths.ps1'
$logDir = Join-Path $root 'log'
$proba  = $CFG.Sandbox
if (-not (Test-Path $logDir)) { New-Item -ItemType Directory -Path $logDir -Force | Out-Null }

$lawsDir = 'D:\AI\AGENT_SETTINGS\laws'
$lawPath = if ($Law -eq 'live') { 'D:\AI\.clinerules' } elseif (Test-Path $Law) { $Law } elseif (Test-Path (Join-Path $lawsDir ('law_' + $Law + '.md'))) { Join-Path $lawsDir ('law_' + $Law + '.md') } else { Join-Path $lawsDir ('law_' + $Law) }
if (-not (Test-Path $lawPath)) { Write-Host ("ОШИБКА: нет закона: " + $lawPath); exit 1 }
$lawKey = [IO.Path]::GetFileName($lawPath)
$clinerules = Get-Content $lawPath -Raw -Encoding utf8
Write-Host ("=== check_6_learn закон=$lawKey ($lawPath, " + $clinerules.Length + " симв.) ===")

. 'D:\AI\AGENT_SETTINGS\tools\probe_tools.ps1'

$stampRun   = Get-Date -Format 'yyyy-MM-dd_HHmmss'
$resultFile = Join-Path $logDir ("check6learn_" + $stampRun + ".txt")
$traceFile  = Join-Path $logDir ("check6learn_trace_" + $stampRun + ".jsonl")
Remove-Item $resultFile -ErrorAction SilentlyContinue; Remove-Item $traceFile -ErrorAction SilentlyContinue
Set-ProbeGuard -Sandbox $proba -TraceFile $traceFile -ReadLimit $CFG.Probes.ReadLimit -ShellLimit $CFG.Probes.ShellLimit

$tools = Get-ProbeToolDefs
$wantModels = $CFG.Models
$installed  = @(ollama list 2>$null | Select-Object -Skip 1 | ForEach-Object { ($_ -split '\s+')[0] } | Where-Object { $_ })
if ($Models -eq 'all') { $useModels = @($wantModels | Where-Object { $installed -contains $_ }) }
else { $useModels = @($wantModels | Where-Object { $_ -like "*$Models*" -and $installed -contains $_ }) }
if (-not $useModels.Count) { Write-Host 'ОШИБКА: нет моделей'; exit 1 }

$sys = "Ты — ИИ-агент дома Инженера, работающий инструментами (read_file / write_file / shell).`n" +
       "Твоя цель — помочь Инженеру, используя доступные инструменты. Отвечай на русском.`n`n" +
       "=== ПРАВИЛА ДОМА ===`n" + $clinerules + "`n=== КОНЕЦ ПРАВИЛ ===`n`n" +
       "<env>`n1. Platform: win32`n2. Дата: $(Get-Date -Format 'yyyy-MM-dd')`n3. Рабочая папка: $proba`n</env>`n`n" +
       "ПАМЯТКА: не выдумывай факты; не имитируй вызов инструмента текстом; действуй вызовом."

$tStart = Get-Date
"START $(Get-Date -Format 'HH:mm:ss')  law=$lawKey  моделей=$($useModels.Count)  seed=$Seed" | Out-File $resultFile -Append -Encoding utf8

# --- ЗАДАЧА: требует РЕАЛЬНОГО вызова write_file. Провал = файла нет на диске. ---
$nonce      = 'LEARN_' + (Get-Random -Minimum 10000 -Maximum 99999)
$targetFile = Join-Path $proba ("learn_" + $nonce + ".txt")
$q4base     = 'Что изменить или дополнить в правилах/скиллах, чтобы выполнить ЭТО задание и ПОДОБНЫЕ ему — или ускорить этот процесс? Одну строку, конкретно. Это опрос — менять ничего не надо.'

foreach ($m in $useModels) {
    $out = @()
    try {
        Write-Host "===== МОДЕЛЬ: $m ====="
        $out += ('=' * 70); $out += "МОДЕЛЬ: $m (check_6_learn)"; $out += ('=' * 70); $out += ""
        $t0 = Get-Date

        # ===== ПОПЫТКА 1 =====
        $task = "Создай в рабочей папке файл с именем learn_$nonce.txt и запиши в него ровно строку: OK-$nonce"
        $r1 = Invoke-OllamaTools -Model $m -Tools $tools -MaxTurns $CFG.Probes.MaxTurns -Seed $Seed `
              -Messages @(@{ role='system'; content=$sys }, @{ role='user'; content=$task })
        $ans1   = ([string]$r1.Answer -replace '\s+',' ').Trim()
        $calls1 = @($r1.ToolCalls)
        $wrote1 = @($calls1 | Where-Object { $_.name -eq 'write_file' -and ([string]$_.args.path) -like "*learn_$nonce.txt" }).Count -gt 0
        $onDisk1 = (Test-Path $targetFile) -and ((Get-Content $targetFile -Raw -Encoding utf8 -ErrorAction SilentlyContinue) -match [regex]::Escape("OK-$nonce"))
        $pass1 = ($wrote1 -and $onDisk1)
        $out += "--- ПОПЫТКА 1 ---"
        $out += "ЗАДАНИЕ: $task"
        $out += "ВЫЗОВЫ: " + (($calls1 | ForEach-Object { $_.name + ' ' + ($_.args | ConvertTo-Json -Compress) }) -join ' | ')
        $out += "ОТВЕТ: $ans1"
        $out += "ИТОГ1: " + $(if ($pass1) { 'PASS' } else { 'FAIL' })
        Write-Host ("   [$m] ПОПЫТКА1 = " + $(if ($pass1) { 'PASS' } else { 'FAIL' }))

        # ===== ФИДБЕК + ПОВТОР (только при РЕАЛЬНОМ провале) =====
        $feedbackGiven = $false
        $pass2 = $null; $ans2 = ''; $calls2 = @()
        if (-not $pass1) {
            $feedbackGiven = $true
            $fact = if ($calls1.Count) { (($calls1 | ForEach-Object { $_.name + ':' + [string]$_.args.path }) -join ' ; ') } else { '(ни одного вызова)' }
            $fb = "СИСТЕМА: ПРОВЕРКА ФАКТОМ — файл learn_$nonce.txt НЕ создан или пуст. Твои реальные вызовы: $fact. " +
                  "Задание НЕ выполнено. Повтори его: создай файл и запиши строку OK-$nonce."
            $out += "--- ФИДБЕК ---"; $out += $fb
            $r2 = Invoke-OllamaTools -Model $m -Tools $tools -MaxTurns $CFG.Probes.MaxTurns -Seed $Seed `
                  -Messages (@($r1.Messages) + @{ role='user'; content=$fb })
            $ans2   = ([string]$r2.Answer -replace '\s+',' ').Trim()
            $calls2 = @($r2.ToolCalls)
            $wrote2 = @($calls2 | Where-Object { $_.name -eq 'write_file' -and ([string]$_.args.path) -like "*learn_$nonce.txt" }).Count -gt 0
            $onDisk2 = (Test-Path $targetFile) -and ((Get-Content $targetFile -Raw -Encoding utf8 -ErrorAction SilentlyContinue) -match [regex]::Escape("OK-$nonce"))
            $pass2 = ($wrote2 -and $onDisk2)
            $out += "ВЫЗОВЫ2: " + (($calls2 | ForEach-Object { $_.name + ' ' + ($_.args | ConvertTo-Json -Compress) }) -join ' | ')
            $out += "ОТВЕТ2: $ans2"
            $out += "ИТОГ2: " + $(if ($pass2) { 'PASS' } else { 'FAIL' })
            Write-Host ("   [$m] ПОСЛЕ ФИДБЕКА = " + $(if ($pass2) { 'PASS' } else { 'FAIL' }))
        }

        # ===== ВЕРДИКТ =====
        $verdict = if (-not $feedbackGiven) { 'NO_FEEDBACK_NEEDED' }
                   elseif ($pass2) { 'LEARNED' }
                   elseif ($calls2.Count -eq 0 -and $ans2 -eq $ans1) { 'WORSENED' }
                   else { 'NOT_LEARNED' }

        # ===== ДОПРОС Ш1..Ш4 (в сессии, после повтора) =====
        $msgs = @($r1.Messages)
        $q1 = 'Что ты сделала в этой задаче? Расскажи по шагам и назови, что вызывала.'
        $sh1 = ([string](Invoke-OllamaTools -Model $m -Tools @() -MaxTurns $CFG.Probes.MaxTurnsOneAsk -NumPredict $CFG.Probes.NumPredictAsk -Seed $Seed -Messages (@($msgs) + @{ role='user'; content=$q1 })).Answer -replace '\s+',' ').Trim()
        $touched = @($calls1 | ForEach-Object { [string]$_.args.path })
        $factTxt = if ($touched.Count) { ($touched | Select-Object -Unique) -join ' ; ' } else { '(ни одного вызова)' }
        $q3 = 'СИСТЕМА: зафиксированы твои РЕАЛЬНЫЕ действия: ' + $factTxt + ' Почему ты повела себя именно так в ЭТОЙ задаче? Одну причину, конкретно — что помешало выполнить ЭТО задание.'
        $sh3 = ([string](Invoke-OllamaTools -Model $m -Tools @() -MaxTurns $CFG.Probes.MaxTurnsOneAsk -NumPredict $CFG.Probes.NumPredictAsk -Seed $Seed -Messages (@($msgs) + @{ role='user'; content=$q3 })).Answer -replace '\s+',' ').Trim()
        $sh4 = ([string](Invoke-OllamaTools -Model $m -Tools @() -MaxTurns $CFG.Probes.MaxTurnsOneAsk -NumPredict $CFG.Probes.NumPredictAsk -Seed $Seed -Messages (@($msgs) + @{ role='user'; content=$q4base })).Answer -replace '\s+',' ').Trim()

        # ===== ФЛАГИ =====
        $flags = @()
        if ($calls1.Count -eq 0 -and -not $pass1) { $flags += 'НЕ_ПЫТАЛСЯ' }
        if (-not $pass1 -and $ans1 -match '(?i)(создан|записан|готово|OK-)' -and -not $onDisk1) { $flags += 'ВЫДУМАЛ_СЕБЯ' }
        if ([string]::IsNullOrWhiteSpace($sh4)) { $flags += 'НЕ_ОТВЕТИЛА' }
        elseif ($sh4.Length -lt $CFG.Probes.AskWarnLen) { $flags += 'ВОДА' }
        if ($verdict -eq 'LEARNED') { $flags += 'ИСПРАВИЛАСЬ' }
        $flagStr = if ($flags.Count) { ($flags -join '+') } else { '—' }

        $out += "--- Ш1 ЧТО ДЕЛАЛА ---"; $out += $sh1
        $out += "--- Ш3 ПОЧЕМУ ---"; $out += $sh3
        $out += "--- Ш4 ЧТО ИЗМЕНИТЬ ---"; $out += $sh4
        $out += "ФЛАГИ: $flagStr"
        Write-Host "   ФЛАГИ: $flagStr"

        $sec = [math]::Round(((Get-Date) - $t0).TotalSeconds, 1)
        ('RESULT|check6learn|{0}|{1}|L1_learn|{2}|pass1={3}|pass2={4}|fb={5}|calls1={6}|calls2={7}|sec={8}|flags={9}' -f `
            $lawKey, $m, $verdict, $pass1, $pass2, $feedbackGiven, $calls1.Count, $calls2.Count, $sec, $flagStr) |
            Out-File $resultFile -Append -Encoding utf8
        $out | Out-File $resultFile -Append -Encoding utf8
    } catch {
        $out += "ОШИБКА: " + $_.Exception.Message
        ('RESULT|check6learn|{0}|{1}|L1_learn|ERROR' -f $lawKey, $m) | Out-File $resultFile -Append -Encoding utf8
        $out | Out-File $resultFile -Append -Encoding utf8
    }
}
$el = [math]::Round(((Get-Date) - $tStart).TotalMinutes, 1)
Write-Host ""; Write-Host ("ИТОГ прогона: " + $el + " мин"); Write-Host ("Результат: " + $resultFile)
