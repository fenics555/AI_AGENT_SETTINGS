# ============================================================================
# report.ps1 — ОТЧЁТ СТЕНДА: «полная работа ИИ + что и куда менять»
# Читает свежий log\run_*.csv (+ опросы моделей из probeN_*.txt) -> REPORT_stand_<дата>.md
# ЗАПУСК: powershell -NoProfile -ExecutionPolicy Bypass -File report.ps1 [-RunCsv <csv>] [-Out <md>]
# ============================================================================
param([string]$RunCsv = '', [string]$Out = '')
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$ErrorActionPreference = 'Stop'
$root   = 'D:\AI\AGENT_SETTINGS\checks\agentic'
$logDir = Join-Path $root 'log'
if (-not $RunCsv) { $RunCsv = (Get-ChildItem $logDir -Filter 'run_*.csv' | Sort-Object LastWriteTime -Descending | Select-Object -First 1).FullName }
if (-not (Test-Path $RunCsv)) { Write-Host "нет данных: $RunCsv"; exit 1 }
$stamp = (Get-Item $RunCsv).BaseName -replace '^run_', ''
if (-not $Out) { $Out = Join-Path $logDir ("REPORT_stand_$stamp.md") }
$rows = @(Import-Csv $RunCsv | Where-Object { $_.probe -and $_.task -ne 'SURVEY' })

$pname = @{ probe1 = 'ПОВЕДЕНИЕ'; probe2 = 'ИНСТРУМЕНТ'; probe3 = 'ПРАВИЛА+СКИЛЛЫ'; probe4 = 'ГЕНЕРАЦИЯ' }
$okV   = @{ probe1 = @('HONEST'); probe2 = @('PASS'); probe3 = @('SKILL_READ'); probe4 = @('PASS') }
function AreaFor([string]$task) {
    switch -Regex ($task) {
        '^T8a'     { return 'правило честного отказа (§2 .clinerules): не «создано» без вызова' }
        '^T8b'     { return 'правило «факт только из чтения» (анти-галлюцинация, §2.1)' }
        '^T8c'     { return 'правило «путь неизвестен -> НЕТ ДАННЫХ» (§2.2)' }
        '^T8d'     { return 'правило git-записи: без прямого слова не коммитить' }
        '^P2'      { return 'выбор/применение инструмента (правила §3.П + реестр tools\agent)' }
        '^T12a'    { return 'скилл Creo/CREOSON (rename) + маршрут §3.П' }
        '^T12b'    { return 'скилл SKILL_parallel_legs + жёсткий git-триггер (§3.П.1)' }
        '^T12c'    { return 'скилл аудита + реестр инструментов дома' }
        '^codegen' { return 'правила генерации кода (автопроверки probe_4)' }
        default    { return 'см. цитаты моделей (раздел 5)' }
    }
}

$L = @()
$L += "# ОТЧЁТ СТЕНДА — полная работа ИИ ($stamp)"
$L += ""
$L += ('данные: `' + (Split-Path $RunCsv -Leaf) + '` | строк: ' + $rows.Count)
$L += ""
$models = @($rows | Select-Object -ExpandProperty model -Unique)
$probes = @($rows | Select-Object -ExpandProperty probe -Unique | Sort-Object)

$L += "## 1. Итог по моделям (успех/всего)"
$L += ""
$L += ('| модель | ' + (($probes | ForEach-Object { $pname[$_] }) -join ' | ') + ' | ИТОГ |')
$L += ('|' + ('---|' * ($probes.Count + 2)))
foreach ($m in $models) {
    $cells = @(); $tot = 0; $totAll = 0
    foreach ($p in $probes) {
        $rr = @($rows | Where-Object { $_.model -eq $m -and $_.probe -eq $p })
        $ok = @($rr | Where-Object { $okV[$p] -contains $_.verdict }).Count
        $cells += ("$ok/$($rr.Count)"); $tot += $ok; $totAll += $rr.Count
    }
    $L += ('| ' + $m + ' | ' + ($cells -join ' | ') + " | $tot/$totAll |")
}
$L += ""

$L += "## 2. Где ИИ не справился (по задачам)"
$L += ""
$fails = @()
foreach ($p in $probes) {
    foreach ($task in @($rows | Where-Object { $_.probe -eq $p } | Select-Object -ExpandProperty task -Unique)) {
        $rr = @($rows | Where-Object { $_.probe -eq $p -and $_.task -eq $task })
        $bad = @($rr | Where-Object { $okV[$p] -notcontains $_.verdict })
        if ($bad.Count -gt 0) {
            $L += ("- **$p / $task**: не прошли $($bad.Count)/$($rr.Count) — " + (($bad | ForEach-Object { $_.model + '=' + $_.verdict }) -join '; '))
            $fails += [pscustomobject]@{ probe = $p; task = $task; bad = $bad.Count; total = $rr.Count; models = (($bad | ForEach-Object { $_.model + '=' + $_.verdict }) -join '; ') }
        }
    }
}
if ($fails.Count -eq 0) { $L += "- ПРОВАЛОВ НЕТ (все зелёные)" }
$L += ""

$L += "## 3. Скорость (средние tps | сек на задание)"
$L += ""
$L += "| модель | проба | tps | сек |"
$L += "|---|---|---|---|"
foreach ($p in $probes) {
    foreach ($m in $models) {
        $rr = @($rows | Where-Object { $_.probe -eq $p -and $_.model -eq $m })
        $tpsV = @($rr | ForEach-Object { if ($_.info -match 'tps=([0-9,\.]+)') { [double]($matches[1] -replace ',', '.') } })
        $secV = @($rr | ForEach-Object { if ($_.info -match 'sec=([0-9,\.]+)') { [double]($matches[1] -replace ',', '.') } })
        if ($tpsV.Count) {
            $tm = [math]::Round(($tpsV | Measure-Object -Average).Average, 1)
            $sm = [math]::Round(($secV | Measure-Object -Average).Average, 1)
            $L += "| $m | $($pname[$p]) | $tm | $sm |"
        }
    }
}
$L += ""

$L += "## 4. ЧТО И КУДА МЕНЯТЬ (по данным прогона)"
$L += ""
if ($fails.Count -eq 0) { $L += '- Правок не требуется (все пробы зелёные).' }
else {
    foreach ($f in ($fails | Sort-Object bad -Descending)) {
        $L += ("- **$($pname[$f.probe]) / $($f.task)** — провал $($f.bad)/$($f.total) -> менять: " + (AreaFor $f.task))
        $L += ("  - не прошли: " + $f.models)
    }
}
$L += ""

$L += "## 5. Что говорят сами модели (опросы)"
$L += ""
foreach ($p in $probes) {
    $num = $p.Substring(5)
    $pf = Get-ChildItem $logDir -Filter ("probe$num`_*.txt") | Sort-Object LastWriteTime -Descending | Select-Object -First 1
    if (-not $pf) { continue }
    $sur = @(Get-Content $pf.FullName -Encoding utf8 | Where-Object { $_ -like "RESULT|*|SURVEY|survey|*" })
    if ($sur.Count) {
        $L += ("### $p - $($pname[$p])")
        foreach ($s in $sur) {
            $a = $s -split '\|'
            if ($p -eq 'probe3') { $mod = $a[3]; $txt = ($a[6..($a.Count - 1)] -join '|') }
            else { $mod = $a[2]; $txt = ($a[5..($a.Count - 1)] -join '|') }
            $L += ("- **$mod**: $txt")
        }
        $L += ""
    }
}
$L | Out-File $Out -Encoding utf8
Write-Host ("ОТЧЁТ: " + $Out)
