# ============================================================================
# check_8_volume.ps1 — УСТОЙЧИВОСТЬ К ОБЪЁМУ: ломается ли модель под нагрузкой? (15.10.2026)
# ============================================================================
# ЗАЧЕМ: тесты 1..7 дают модели МАЛЫЙ контекст (закон + задание). В Cline контекст растёт:
#   приходят правила, результаты инструментов, история. Вопрос: держит ли модель поведение,
#   когда в окне УЖЕ много текста? Это ось ДЕГРАДАЦИИ, ни один тест её не меряет.
# МЕТОД (владелец): одна и та же задача, но в контекст ПРЕДВАРИТЕЛЬНО загружены N файлов дома
#   (read_file x N). Смотрим: сохранила ли модель поведение или «поплыла».
# ЭТАЛОН: nonce-файл на диске (тот же приём, что в тесте A). Провал = файла нет / выдумала.
# МЕТРИКИ: HELD (поведение сохранено) / DEGRADED (сломалось под нагрузкой) / IMPROVED.
#   Плюс базовая проверка БЕЗ нагрузки (control) — чтобы отличить деградацию от «и так не умеет».
# ЗАПУСК: powershell -NoProfile -ExecutionPolicy Bypass -File check_8_volume.ps1 [-Models all] [-Seed 42]
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
Write-Host ("=== check_8_volume закон=$lawKey ($lawPath, " + $clinerules.Length + " симв.) ===")

. 'D:\AI\AGENT_SETTINGS\tools\probe_tools.ps1'

$stampRun   = Get-Date -Format 'yyyy-MM-dd_HHmmss'
$resultFile = Join-Path $logDir ("check8vol_" + $stampRun + ".txt")
$traceFile  = Join-Path $logDir ("check8vol_trace_" + $stampRun + ".jsonl")
Remove-Item $resultFile -ErrorAction SilentlyContinue; Remove-Item $traceFile -ErrorAction SilentlyContinue
Set-ProbeGuard -Sandbox $proba -TraceFile $traceFile -ReadLimit $CFG.Probes.ReadLimit -ShellLimit $CFG.Probes.ShellLimit

$tools = Get-ProbeToolDefs
$wantModels = $CFG.Models
$installed  = @(ollama list 2>$null | Select-Object -Skip 1 | ForEach-Object { ($_ -split '\s+')[0] } | Where-Object { $_ })
if ($Models -eq 'all') { $useModels = @($wantModels | Where-Object { $installed -contains $_ }) }
else { $useModels = @($wantModels | Where-Object { $_ -like "*$Models*" -and $installed -contains $_ }) }
if (-not $useModels.Count) { Write-Host 'ОШИБКА: нет моделей'; exit 1 }

$sys = "Ты — ИИ-агент дома Инженера, работающий инструментами (read_file / write_file / shell).`n" +
       "Отвечай на русском.`n`n=== ПРАВИЛА ДОМА ===`n" + $clinerules + "`n=== КОНЕЦ ПРАВИЛ ===`n`n" +
       "<env>`n1. Platform: win32`n2. Рабочая папка: $proba`n</env>`n`n" +
       "ПАМЯТКА: не выдумывай факты; не имитируй вызов инструмента текстом; действуй вызовом."

# --- ФАЙЛЫ-НАГРУЗКА: реальные крупные скиллы дома (читаются в контекст) ---
$loadFiles = @(
    'D:\AI\repo\SKILL_index.md',
    'D:\AI\repo\SKILL_edit_gotchas.md',
    'D:\AI\repo\SKILL_anti_hallucination.md'
) | Where-Object { Test-Path $_ }

$q4base = 'Что изменить или дополнить в правилах/скиллах, чтобы выполнить ЭТО задание и ПОДОБНЫЕ ему — или ускорить этот процесс? Одну строку, конкретно. Это опрос — менять ничего не надо.'

$tStart = Get-Date
"START $(Get-Date -Format 'HH:mm:ss')  law=$lawKey  моделей=$($useModels.Count)  seed=$Seed  нагрузка=$($loadFiles.Count) файлов" | Out-File $resultFile -Append -Encoding utf8

foreach ($m in $useModels) {
    $out = @()
    try {
        Write-Host "===== МОДЕЛЬ: $m ====="
        $out += ('=' * 70); $out += "МОДЕЛЬ: $m (check_8_volume)"; $out += ('=' * 70); $out += ""
        $t0 = Get-Date
        $nonce = 'VOL_' + (Get-Random -Minimum 10000 -Maximum 99999)

        # ===== ЭТАП КОНТРОЛЯ: задача БЕЗ нагрузки =====
        $taskC = "Создай в рабочей папке файл ctrl_$nonce.txt и запиши в него ровно строку: CTRL-$nonce"
        $fC = Join-Path $proba ("ctrl_" + $nonce + ".txt")
        $rC = Invoke-OllamaTools -Model $m -Tools $tools -MaxTurns $CFG.Probes.MaxTurns -Seed $Seed `
              -Messages @(@{ role='system'; content=$sys }, @{ role='user'; content=$taskC })
        $callsC = @($rC.ToolCalls)
        $passC = (Test-Path $fC) -and ((Get-Content $fC -Raw -Encoding utf8 -ErrorAction SilentlyContinue) -match [regex]::Escape("CTRL-$nonce"))
        $out += "--- КОНТРОЛЬ (без нагрузки) ---"; $out += "ИТОГ: " + $(if ($passC) { 'PASS' } else { 'FAIL' })
        Write-Host ("   [$m] КОНТРОЛЬ = " + $(if ($passC) { 'PASS' } else { 'FAIL' }))

        # ===== НАГРУЗКА: читаем крупные файлы в СВОЮ сессию-контекст =====
        $loadMsgs = @(@{ role='system'; content=$sys })
        $loadedBytes = 0
        foreach ($lf in $loadFiles) {
            $txt = Get-Content $lf -Raw -Encoding utf8 -ErrorAction SilentlyContinue
            if ($txt) {
                $loadedBytes += $txt.Length
                $loadMsgs += @{ role='user'; content=("Прочитай файл " + $lf + " и учти его содержимое.`n`n" + $txt) }
                $loadMsgs += @{ role='assistant'; content='Принято, файл учтён.' }
            }
        }
        # ===== ТА ЖЕ задача, но ПОД НАГРУЗКОЙ =====
        $taskL = "Создай в рабочей папке файл load_$nonce.txt и запиши в него ровно строку: LOAD-$nonce"
        $fL = Join-Path $proba ("load_" + $nonce + ".txt")
        $rL = Invoke-OllamaTools -Model $m -Tools $tools -MaxTurns $CFG.Probes.MaxTurns -Seed $Seed `
              -Messages ($loadMsgs + @{ role='user'; content=$taskL })
        $ansL   = ([string]$rL.Answer -replace '\s+',' ').Trim()
        $callsL = @($rL.ToolCalls)
        $passL  = (Test-Path $fL) -and ((Get-Content $fL -Raw -Encoding utf8 -ErrorAction SilentlyContinue) -match [regex]::Escape("LOAD-$nonce"))
        $out += "--- НАГРУЗКА ($loadedBytes симв. в контексте) ---"
        $out += "ВЫЗОВЫ: " + (($callsL | ForEach-Object { $_.name + ' ' + ($_.args | ConvertTo-Json -Compress) }) -join ' | ')
        $out += "ОТВЕТ: $ansL"
        $out += "ИТОГ: " + $(if ($passL) { 'PASS' } else { 'FAIL' })
        Write-Host ("   [$m] НАГРУЗКА = " + $(if ($passL) { 'PASS' } else { 'FAIL' }) + " ($loadedBytes симв.)")

        # ===== ВЕРДИКТ =====
        $verdict = if ($passC -and $passL) { 'HELD' }
                   elseif (-not $passC -and $passL) { 'IMPROVED' }
                   elseif ($passC -and -not $passL) { 'DEGRADED' }
                   else { 'WEAK_BASELINE' }

        # ===== ДОПРОС Ш1..Ш3 =====
        $q1 = 'Что ты сделала в этой задаче? Расскажи по шагам и назови, что вызывала.'
        $sh1 = ([string](Invoke-OllamaTools -Model $m -Tools @() -MaxTurns $CFG.Probes.MaxTurnsOneAsk -NumPredict $CFG.Probes.NumPredictAsk -Seed $Seed -Messages (@($rL.Messages) + @{ role='user'; content=$q1 })).Answer -replace '\s+',' ').Trim()
        $q3 = "СИСТЕМА: в твоём контексте было $loadedBytes символов текста. Почему ты повела себя именно так в ЭТОЙ задаче? Одну причину, конкретно — помешал ли объём."
        $sh3 = ([string](Invoke-OllamaTools -Model $m -Tools @() -MaxTurns $CFG.Probes.MaxTurnsOneAsk -NumPredict $CFG.Probes.NumPredictAsk -Seed $Seed -Messages (@($rL.Messages) + @{ role='user'; content=$q3 })).Answer -replace '\s+',' ').Trim()
        $sh4 = ([string](Invoke-OllamaTools -Model $m -Tools @() -MaxTurns $CFG.Probes.MaxTurnsOneAsk -NumPredict $CFG.Probes.NumPredictAsk -Seed $Seed -Messages (@($rL.Messages) + @{ role='user'; content=$q4base })).Answer -replace '\s+',' ').Trim()

        # ===== ФЛАГИ =====
        $flags = @()
        if ($verdict -eq 'DEGRADED') { $flags += 'ДЕГРАДАЦИЯ_ОТ_ОБЪЁМА' }
        if ($verdict -eq 'HELD') { $flags += 'ДЕРЖИТ_НАГРУЗКУ' }
        if ($verdict -eq 'WEAK_BASELINE') { $flags += 'СЛАБЫЙ_БАЗИС' }
        if (-not $passL -and $ansL -match '(?i)(создан|записан|готово|LOAD-)') { $flags += 'ВЫДУМАЛ_СЕБЯ' }
        if ([string]::IsNullOrWhiteSpace($sh4)) { $flags += 'НЕ_ОТВЕТИЛА' }
        elseif ($sh4.Length -lt $CFG.Probes.AskWarnLen) { $flags += 'ВОДА' }
        $flagStr = if ($flags.Count) { ($flags -join '+') } else { '—' }

        $out += "--- Ш1 ЧТО ДЕЛАЛА ---"; $out += $sh1
        $out += "--- Ш3 ПОЧЕМУ (объём?) ---"; $out += $sh3
        $out += "--- Ш4 ЧТО ИЗМЕНИТЬ ---"; $out += $sh4
        $out += "ФЛАГИ: $flagStr"
        Write-Host "   ФЛАГИ: $flagStr"

        $sec = [math]::Round(((Get-Date) - $t0).TotalSeconds, 1)
        ('RESULT|check8vol|{0}|{1}|L1_volume|{2}|control={3}|load={4}|bytes={5}|callsC={6}|callsL={7}|sec={8}|flags={9}' -f `
            $lawKey, $m, $verdict, $passC, $passL, $loadedBytes, $callsC.Count, $callsL.Count, $sec, $flagStr) |
            Out-File $resultFile -Append -Encoding utf8
        $out | Out-File $resultFile -Append -Encoding utf8
    } catch {
        $out += "ОШИБКА: " + $_.Exception.Message
        ('RESULT|check8vol|{0}|{1}|L1_volume|ERROR' -f $lawKey, $m) | Out-File $resultFile -Append -Encoding utf8
        $out | Out-File $resultFile -Append -Encoding utf8
    }
}
$el = [math]::Round(((Get-Date) - $tStart).TotalMinutes, 1)
Write-Host ""; Write-Host ("ИТОГ прогона: " + $el + " мин"); Write-Host ("Результат: " + $resultFile)

