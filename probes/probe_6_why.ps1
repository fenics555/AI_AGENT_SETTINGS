# ============================================================================
# probe_6_why.ps1 — РИТУАЛ «ПОЧЕМУ?» (гипотеза владельца, 14.10.2026)
# ИДЕЯ: после выбора инструмента модель ОБЯЗАНА спросить себя «ПОЧЕМУ именно этот?» и ответить.
# Цель ритуала — заставить модель ОСОЗНАТЬ выбор; если выбор был рефлекторным, вопрос вскрывает это
# и модель может ПЕРЕСМОТРЕТЬ выбор (взять правильный инструмент).
# СРАВНЕНИЕ: режим A (базовый цикл) vs режим B (цикл + само-вопрос «почему»).
# СУД ПО ФАКТУ (не по тексту): выбран ли ВЕРНЫЙ инструмент и что реально на диске.
# МЕТОД: задание простое, без имён инструментов и без подсказки ответа; допрос — В СЕССИИ.
# ЗАПУСК: powershell -NoProfile -ExecutionPolicy Bypass -File probe_6_why.ps1 [-Models all|gemma4|...] [-Rules v25]
# ============================================================================
param([string]$Models = 'all', [string]$Rules = '')

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$ProgressPreference = 'SilentlyContinue'
$ErrorActionPreference = 'Stop'

$root   = 'D:\AI\AGENT_SETTINGS\checks\agentic'
$logDir = Join-Path $root 'log'
$proba  = 'D:\AI\PROBA'
$work   = Join-Path $proba 'work'
if (-not (Test-Path $logDir)) { New-Item -ItemType Directory -Path $logDir -Force | Out-Null }
if (-not (Test-Path $work))   { New-Item -ItemType Directory -Path $work -Force | Out-Null }

$livePath = 'D:\AI\.clinerules'
$rulesMap = @{ 'G' = (Join-Path $root '.clinerules_vG'); 'live' = $livePath }
Get-ChildItem $root -Filter '.clinerules_v*' -Force -ErrorAction SilentlyContinue | ForEach-Object { $rulesMap[($_.Name -replace '^\.clinerules_v','')] = $_.FullName }
if ($Rules) { if ($rulesMap.ContainsKey($Rules)) { $livePath = $rulesMap[$Rules] } else { $livePath = $Rules } }

. 'D:\AI\AGENT_SETTINGS\tools\probe_tools.ps1'

# --- СТРАЖ (как в probe_0/5): запись только в песочницу ---
$script:origProbeTool = ${function:Invoke-ProbeTool}
function Assert-ProbaPath { param([string]$Path) return ($Path -and ($Path -like "$proba*")) }
function Invoke-ProbeTool {
    param([string]$Name, $ToolArgs)
    if ($Name -eq 'write_file') {
        if (-not (Assert-ProbaPath ([string]$ToolArgs.path))) { return "BLOCKED (вне песочницы): пиши только в $proba." }
        return (& $script:origProbeTool -Name $Name -ToolArgs $ToolArgs)
    }
    if ($Name -eq 'read_file') {
        $t = [string](& $script:origProbeTool -Name $Name -ToolArgs $ToolArgs)
        if ($t.Length -gt 4000) { $t = $t.Substring(0, 4000) + "`n...[СТЕНД: усечено]" }
        return $t
    }
    if ($Name -eq 'shell') {
        $cmd = [string]$ToolArgs.cmd
        if ($cmd -match '(?i)(git\s+(add|commit|push|reset|checkout|rebase|merge|stash|apply|rm)|>(?!\$null))') { return 'BLOCKED: git-запись и перенаправление запрещены. ПОВТОРИ без них.' }
        if ($cmd -match '(?i)(Remove-Item|Move-Item|Rename-Item|New-Item|Set-Content|Add-Content|Out-File|Copy-Item|rmdir|\bdel\b)') {
            $paths = @([regex]::Matches($cmd, '(?i)[A-Z]:\\[^\s"'';|)]+') | ForEach-Object { $_.Value })
            $outside = @($paths | Where-Object { $_ -notlike 'D:\AI\PROBA*' })
            if ($outside.Count -gt 0) { return "BLOCKED (вне песочницы): наружу: $($outside -join ', ')." }
        }
        $prev = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
        # ФИКС 18.10.2026 (РЫЧАГ 38): снять внешний слой, если модель сама обернула в powershell -Command
        $inner = $null
        if ($cmd -match '(?is)^\s*powershell(\.exe)?\s+(-NoProfile\s+)?-Command\s+["'']?(.*?)["'']?\s*$') {
            $inner = $Matches[3].Trim()
            if ($inner.StartsWith('"') -and $inner.EndsWith('"') -and $inner.Length -gt 2) { $inner = $inner.Substring(1, $inner.Length - 2) }
            elseif ($inner.StartsWith("'") -and $inner.EndsWith("'") -and $inner.Length -gt 2) { $inner = $inner.Substring(1, $inner.Length - 2) }
        }
        $useCmd = if ($inner) { $inner } else { $cmd }
        try {
            $sb = [ScriptBlock]::Create("Set-Location -LiteralPath '$proba'; " + $useCmd)
            $res = (& $sb 2>&1 | Out-String)
        } catch {
            $res = (& powershell -NoProfile -Command ("Set-Location -LiteralPath '$proba'; " + $useCmd) 2>&1 | Out-String)
        }
        finally { $ErrorActionPreference = $prev }
        $res = ([string]$res) -replace "`r", ''
        if ($res.Length -gt 3000) { $res = $res.Substring(0, 3000) + "`n...[СТЕНД: усечено]" }
        return $res
    }
    return (& $script:origProbeTool -Name $Name -ToolArgs $ToolArgs)
}

# --- ЦИКЛ С РИТУАЛОМ «ПОЧЕМУ?» ---
# $WithWhy = $true -> после КАЖДОГО вызова инструмента модель обязана ответить, ПОЧЕМУ выбрала этот инструмент.
function Invoke-ToolsWhy {
    param([string]$Model, [array]$Messages, [array]$Tools, [int]$MaxTurns = 8, [int]$NumCtx = 16384, [bool]$WithWhy = $false)
    $script:whyNotes = @()
    $msgs = @($Messages); $calls = @(); $answer = ''; $turns = 0
    while ($turns -lt $MaxTurns) {
        $turns++
        $r = Invoke-OllamaTools -Model $Model -Tools $Tools -MaxTurns 1 -NumCtx $NumCtx -Messages $msgs
        $answer = [string]$r.Answer
        $tc = @($r.ToolCalls)
        $newMsgs = @($r.Messages)
        if ($tc.Count -eq 0) { $msgs = $newMsgs; break }
        # результаты вызова уже внутри $newMsgs (tool-роли) — берём как есть
        $msgs = $newMsgs
        foreach ($c in $tc) { $calls += $c }
        if ($WithWhy) {
            # РИТУАЛ: заставить модель спросить себя «ПОЧЕМУ именно этот инструмент?» и ответить
            $q = ('СТОП. Прежде чем продолжить: ПОЧЕМУ ты выбрала именно этот инструмент (' + (($tc | ForEach-Object { $_.name }) -join ',') + ')? Ответь одной фразой. Если считаешь выбор НЕВЕРНЫМ — исправь и вызови нужный инструмент.')
            $msgs += @{ role = 'user'; content = $q }
            $rw = Invoke-OllamaTools -Model $Model -Tools $Tools -MaxTurns 1 -NumCtx $NumCtx -Messages $msgs
            $why = ([string]$rw.Answer).Trim()
            $script:whyNotes += $why
            $msgs = @($rw.Messages)
            foreach ($c2 in @($rw.ToolCalls)) { $calls += $c2 }
            if (@($rw.ToolCalls).Count -gt 0) { continue }
        }
    }
    return @{ Answer = $answer; ToolCalls = $calls; Turns = $turns; Messages = $msgs; WhyNotes = $script:whyNotes }
}

$tools      = Get-ProbeToolDefs
$clinerules = if (Test-Path $livePath) { Get-Content $livePath -Raw -Encoding utf8 } else { '' }
$sysBase    = ("Ниже — твой ЗАКОН (.clinerules). Ты ОБЯЗАН следовать ему.`n`n=== НАЧАЛО .clinerules ===`n" + $clinerules + "`n=== КОНЕЦ .clinerules ===`n`nТы работаешь в среде с инструментами. РАБОЧАЯ ДИРЕКТОРИЯ: $proba (запись только внутри неё).")

$wantModels = @('gemma4:26b','batiai/qwen3.6-35b:iq4','laguna-xs-2.1:latest','batiai/nemotron3-nano:iq4','gpt-oss:20b')
$installed  = @(ollama list 2>$null | Select-Object -Skip 1 | ForEach-Object { ($_ -split '\s+')[0] } | Where-Object { $_ })
if ($Models -eq 'all') { $useModels = @($wantModels | Where-Object { $installed -contains $_ }) }
else { $useModels = @($wantModels | Where-Object { $_ -like "*$Models*" -and $installed -contains $_ }) }
if (-not $useModels.Count) { Write-Host 'ОШИБКА: нет моделей'; exit 1 }

$stamp = Get-Date -Format 'yyyy-MM-dd_HHmmss'
$resultFile = Join-Path $logDir ("probe6_" + $stamp + ".txt")
Remove-Item $resultFile -ErrorAction SilentlyContinue
Write-Host "=== probe_6 (РИТУАЛ ПОЧЕМУ: A без ритуала vs B с ритуалом) | $($useModels -join ', ') ==="
"START $(Get-Date -Format 'HH:mm:ss')  rules=$livePath  моделей=$($useModels.Count)" | Out-File $resultFile -Append -Encoding utf8

# ЗАДАНИЕ: требует РЕАЛЬНОГО переименования (shell) + чтения (read_file). Без имён инструментов.
$srcName  = 'whyA_old.dat'; $dstName = 'whyA_new.dat'
$srcPath  = Join-Path $work $srcName
$dstPath  = Join-Path $work $dstName
$taskText = "В папке $work есть файл $srcName. Переименуй его в $dstName, затем прочитай получившийся файл и приведи его содержимое дословно."

foreach ($m in $useModels) {
    foreach ($mode in 'A', 'B') {
        # подготовка песочницы (для чистоты повторов)
        Remove-Item $dstPath -Force -ErrorAction SilentlyContinue
        if (-not (Test-Path $srcPath)) { [IO.File]::WriteAllText($srcPath, 'WHY-TEST DATA 42', (New-Object Text.UTF8Encoding($false))) }
        $t0 = Get-Date
        $withWhy = ($mode -eq 'B')
        $r = Invoke-ToolsWhy -Model $m -WithWhy $withWhy -Tools $tools -MaxTurns 8 -Messages @(
                @{ role = 'system'; content = $sysBase }, @{ role = 'user'; content = $taskText })
        $ans = ([string]$r.Answer -replace '\s+', ' ').Trim()
        $used = @($r.ToolCalls | ForEach-Object { $_.name } | Select-Object -Unique)
        $renamed = Test-Path $dstPath                       # ФАКТ: файл реально переименован?
        $readOk  = ($ans -match 'WHY-TEST DATA 42')         # реально ли прочитал содержимое
        $sec = [math]::Round(((Get-Date) - $t0).TotalSeconds, 1)
        $verdict = if ($renamed -and $readOk) { 'PASS' } elseif ($renamed -or $readOk) { 'PART' } else { 'FAIL' }
        $whyCount = @($r.WhyNotes).Count
        $whySample = if ($whyCount) { [string]$r.WhyNotes[0] } else { '' }
        ('RESULT|probe6|{0}|mode={1}|{2}|tools={3}|renamed={4}|readOk={5}|whyNotes={6}|calls={7}|sec={8}' -f $m, $mode, $verdict, ($used -join ','), $renamed, $readOk, $whyCount, @($r.ToolCalls).Count, $sec) | Out-File $resultFile -Append -Encoding utf8
        @("=== $m  режим $mode  ->  $verdict (renamed=$renamed readOk=$readOk tools=[$($used -join ',')] whyNotes=$whyCount, $sec c)",
          "ЗАДАНИЕ: $taskText", "ВЫЗОВЫ: " + (($r.ToolCalls | ForEach-Object { $_.name + ' ' + ($_.args | ConvertTo-Json -Compress) }) -join ' | '),
          "ОТВЕТ: $ans", $(if ($whySample) { "ПЕРВОЕ ПОЧЕМУ: $whySample" } else { "" }), "") | Out-File $resultFile -Append -Encoding utf8
        Write-Host "   [$m] mode=$mode $verdict renamed=$renamed readOk=$readOk why=$whyCount"
        # восстановление
        Remove-Item $dstPath -Force -ErrorAction SilentlyContinue
        Remove-Item $srcPath -Force -ErrorAction SilentlyContinue
    }
}
Write-Host ""; Write-Host ("Отчёт: " + $resultFile)
