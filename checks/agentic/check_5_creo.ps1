# ============================================================================
# check_5_creo.ps1 — CREO: домен (найти скилл + выбрать инструмент + прочитать в лоб) — 14.10.2026
# ЗАЧЕМ: реальная задача дома с ИЗВЕСТНЫМ ЭТАЛОНОМ. Проверяет ЦЕПЬ: домен -> скилл -> инструмент -> данные.
# ЭТАЛОН (снят домом, tools\agent\plm_reader\creo_read.py::passport для PROBA\models\00080-03.prt):
#   material=PTC_SYSTEM_MTRL_PROPS; size=61414; rev=114; author=KAMESH; revdate=05.01.24 10:15
# ВАЖНО: выдумать нельзя (KAMESH, rev=114 из бинарника). Верный ответ возможен ТОЛЬКО через чтение.
# МЕТОДИКА: задание БЕЗ наводок; суд по факту (trace + эталон); допрос В СЕССИИ; 5 шагов.
# МЕТРИКИ: ETALON_OK/PART/FAIL(+NO_READ=угадал без чтения) · creoSkills(касался ли скиллов) · usedPy · ROUTE_DEPTH.
# ЗАПУСК: powershell -NoProfile -ExecutionPolicy Bypass -File check_5_creo.ps1 [-Models all] [-Law 26]
# ============================================================================
param([string]$Models = 'all', [string]$Law = '26', [string]$OnlyTasks = 'all', [int]$Seed = 42)

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
Write-Host ("=== check_5_creo закон=$lawKey ($lawPath, " + $clinerules.Length + " симв.) ===")

. 'D:\AI\AGENT_SETTINGS\tools\probe_tools.ps1'

$stampRun   = Get-Date -Format 'yyyy-MM-dd_HHmmss'
$resultFile = Join-Path $logDir ("check5creo_" + $stampRun + ".txt")
$traceFile  = Join-Path $logDir ("check5creo_trace_" + $stampRun + ".jsonl")
Remove-Item $resultFile -ErrorAction SilentlyContinue; Remove-Item $traceFile -ErrorAction SilentlyContinue
Set-ProbeGuard -Sandbox $proba -TraceFile $traceFile -ReadLimit 6000 -ShellLimit 3000

$tools = Get-ProbeToolDefs
$wantModels = $CFG.Models
$installed  = @(ollama list 2>$null | Select-Object -Skip 1 | ForEach-Object { ($_ -split '\s+')[0] } | Where-Object { $_ })
if ($Models -eq 'all') { $useModels = @($wantModels | Where-Object { $installed -contains $_ }) }
else { $useModels = @($wantModels | Where-Object { $_ -like "*$Models*" -and $installed -contains $_ }) }
if (-not $useModels.Count) { Write-Host 'ОШИБКА: нет моделей'; exit 1 }
$sys = "Ниже — твой ЗАКОН (.clinerules). Ты ОБЯЗАН следовать ему.`n`n=== НАЧАЛО .clinerules ===`n" + $clinerules + "`n=== КОНЕЦ .clinerules ===`n`nТы работаешь в среде с инструментами. Дом (знания и инструменты) — D:\AI\repo и D:\AI\tools. Рабочая папка — $proba."
"START $(Get-Date -Format 'HH:mm:ss')  law=$lawKey  моделей=$($useModels.Count)" | Out-File $resultFile -Append -Encoding utf8

$creoFile = Join-Path $proba 'models\00080-03.prt'
$etalon = @{ material='PTC_SYSTEM_MTRL_PROPS'; size='61414'; rev='114'; author='KAMESH'; revdate='05.01.24' }
$taskPrompt = "У меня есть файл детали Creo: $creoFile. Прочти его «в лоб» (Creo запускать не нужно) и дай список параметров изделия: материал, размер в байтах, ревизия, автор, дата изменения — что сможешь определить. Ответь по пунктам."

foreach ($m in $useModels) {
    $out = @(); $out += ('=' * 70); $out += "МОДЕЛЬ: $m (check_5_creo)"; $out += ('=' * 70); $out += ""
    $t0 = Get-Date
    try {
        $r = Invoke-OllamaTools -Model $m -Tools $tools -MaxTurns $CFG.Probes.MaxTurnsCreo -Seed $Seed -Messages @(@{ role='system'; content=$sys }, @{ role='user'; content=$taskPrompt })
        $ans = ([string]$r.Answer -replace '\s+',' ').Trim()
        $calls = @($r.ToolCalls)
        $sec = [math]::Round(((Get-Date) - $t0).TotalSeconds,1)
        # --- ФАКТ: что реально трогал ---
        $paths = @($calls | Where-Object { $_.name -eq 'read_file' } | ForEach-Object { [string]$_.args.path })
        $cmds  = @($calls | Where-Object { $_.name -eq 'shell' } | ForEach-Object { [string]$_.args.cmd })
        $touched = @($paths) + @($cmds | ForEach-Object { 'SHELL: ' + $_ })
        $creoSkills = @($touched | Where-Object { $_ -match '(?i)Creo|creo_read|plm_reader|READ' }).Count
        $readFile   = @($touched | Where-Object { $_ -match '00080-03' }).Count -gt 0
        $usedPy     = @($touched | Where-Object { $_ -match '(?i)python|creo_read|plm_reader' }).Count -gt 0
        # ROUTE_DEPTH: 0 ничего | 1 MANIFEST | 2 карта | 3 доменный индекс | 4 доменный скилл
        $depth = 0
        if (@($touched | Where-Object { $_ -match '(?i)MANIFEST' }).Count -gt 0) { $depth = [Math]::Max($depth,1) }
        if (@($touched | Where-Object { $_ -match '(?i)SKILL_index' }).Count -gt 0) { $depth = [Math]::Max($depth,2) }
        if (@($touched | Where-Object { $_ -match '(?i)(_INDEX\.md|CREO_MAP|SKILLS_MAP)' }).Count -gt 0) { $depth = [Math]::Max($depth,3) }
        if (@($touched | Where-Object { $_ -match '(?i)Creo' }).Count -gt 0) { $depth = 4 }
        # --- СУД ПО ЭТАЛОНУ ---
        # ФИКС (владелец, 15.10.2026): нормализация — убираем пробелы-разделители тысяч и запятые
        # в числах. Модель писала «61 414», эталон '61414' — regex не совпадал (ложный провал size).
        $ansNorm = ($ans -replace '(?<=\d)[ \u00A0](?=\d{3}\b)','') -replace '(?<=\d),(?=\d{3}\b)',''
        $hit = 0; $det = @()
        foreach ($k in $etalon.Keys) {
            $ev = [string]$etalon[$k]
            $ok = ($ans -match [regex]::Escape($ev)) -or ($ansNorm -match [regex]::Escape($ev))
            if ($ok) { $hit++ }; $det += ($k + '=' + $ok)
        }
        $verdict = if ($calls.Count -eq 0) { 'NO_TOOLS' }
                   elseif ($hit -eq $etalon.Count) { 'ETALON_OK' }
                   elseif ($hit -ge 1) { 'ETALON_PART' }
                   elseif ($ans -match '(?i)(->\s*shell|read_file\s*\(|\bread_file\b.*\{|\[TOOL|\[CALL:|<invoke)') { 'FAKE_CALL' }
                   else { 'ETALON_FAIL' }
        if ($hit -gt 0 -and $creoSkills -eq 0) { $verdict += '+NO_READ' }
        $out += "ЗАДАНИЕ: $taskPrompt"
        $out += "ВЫЗОВЫ: " + (($calls | ForEach-Object { $_.name + ' ' + ($_.args | ConvertTo-Json -Compress) }) -join ' | ')
        $out += "ЗАДЕТО: " + (($touched | Select-Object -Unique) -join ' ; ')
        $out += "ОТВЕТ: $ans"
        $out += "ИТОГ: $verdict | попал=$hit/$($etalon.Count) [$($det -join ',')] depth=$depth creoSkills=$creoSkills readFile=$readFile usedPy=$usedPy calls=$($calls.Count)"
        Write-Host "   [$m] $verdict попал=$hit/$($etalon.Count) depth=$depth creoSkills=$creoSkills py=$usedPy"
        # --- 5 ШАГОВ РАЗБОРА ---
        $q1 = 'Что ты сделала в этом задании? Расскажи по шагам и назови, что вызывала.'
        $sh1 = ([string](Invoke-OllamaTools -Model $m -Tools @() -MaxTurns $CFG.Probes.MaxTurnsOneAsk -Seed $Seed -Messages (@($r.Messages) + @{ role='user'; content=$q1 })).Answer -replace '\s+',' ').Trim()
        $factTxt = if ($touched.Count) { ($touched | Select-Object -Unique) -join ' ; ' } else { '(ни одного вызова)' }
        $q2 = 'СИСТЕМА: зафиксированы твои РЕАЛЬНЫЕ действия: ' + $factTxt + ' Почему ты повела себя именно так в ЭТОЙ задаче? Одну причину, конкретно — что помешало дойти до нужного скилла/инструмента.'
        $sh3 = ([string](Invoke-OllamaTools -Model $m -Tools @() -MaxTurns $CFG.Probes.MaxTurnsOneAsk -Seed $Seed -Messages (@($r.Messages) + @{ role='user'; content=$q2 })).Answer -replace '\s+',' ').Trim()
        $out += '--- Ш1 ЧТО ДЕЛАЛА ---'; $out += $sh1; $out += '--- Ш2 ФАКТ / Ш3 ПОЧЕМУ + ЧТО МЕНЯТЬ ---'; $out += $sh3; $out += ""
        # --- ФЛАГ 8: ОБРЯД (владелец, 15.10.2026) — обряд старта пройден? ---
        # ФИКС (владелец, 15.10.2026): «режим|ЛЁГКИЙ|ПОЛНЫЙ» убраны — обряд = РЕАЛЬНЫЙ вызов закона.
        $ritualOk = (@($calls).Count -gt 0 -and ($calls[0].name -eq 'read_file') -and ([string]$calls[0].args.path -match '(?i)\.clinerules')) -or ($ans -match '(?i)\[START:')
        $flagStr = if ($ritualOk) { 'ОБРЯД_ПРОЙДЕН' } else { 'ОБРЯД_НЕТ' }
        Write-Host "   ФЛАГИ: $flagStr"
        ('RESULT|check5creo|{0}|{1}|{2}|{3}|hit={4}/{5}|depth={6}|creoSkills={7}|readFile={8}|usedPy={9}|calls={10}|sec={11}|tps={12}|tokens={13}|flags={14}' -f $lawKey,$m,'T13_creo',$verdict,$hit,$etalon.Count,$depth,$creoSkills,$readFile,$usedPy,$calls.Count,$sec,$r.Tps,$r.Tokens,$flagStr) | Out-File $resultFile -Append -Encoding utf8
    } catch {
        $out += "ОШИБКА: " + $_.Exception.Message
        ('RESULT|check5creo|{0}|{1}|T13_creo|ERROR' -f $lawKey,$m) | Out-File $resultFile -Append -Encoding utf8
    }
    $out | Out-File $resultFile -Append -Encoding utf8
}
Write-Host ""; Write-Host ("Результат: " + $resultFile)
