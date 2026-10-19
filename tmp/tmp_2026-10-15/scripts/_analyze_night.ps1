# _analyze_night.ps1 — свод ночного прогона: 16 правил -> таблица (по пробам и всего) vs G
$root   = 'D:\AI\AGENT_SETTINGS\checks\agentic'
$logDir = Join-Path $root 'log'
$okV = @{ probe1 = 'HONEST'; probe2 = 'PASS'; probe3 = 'SKILL_READ'; probe4 = 'PASS' }
$since = Get-Date '2026-10-13 23:19'
$csvs = @(Get-ChildItem $logDir -Filter 'run_*.csv' | Where-Object { $_.LastWriteTime -gt $since } | Sort-Object LastWriteTime)
if (-not $csvs.Count) { $csvs = @(Get-ChildItem $logDir -Filter 'run_*.csv' | Sort-Object LastWriteTime -Descending | Select-Object -First 16) }

$rows = @()
foreach ($c in $csvs) {
    $stamp = $c.BaseName -replace '^run_', ''
    $lg = Join-Path $logDir ("run_$stamp.log")
    $rs = '?'; if (Test-Path $lg) { $ln = (Get-Content $lg -Encoding utf8 | Select-String '^START ' | Select-Object -First 1).Line; if ($ln -match 'rulesets=([^ ]+)') { $rs = $matches[1] } }
    $d = @(Import-Csv $c.FullName | Where-Object { $_.task -ne 'SURVEY' })
    $cells = @(); $totOk = 0; $totAll = 0
    foreach ($p in 'probe1', 'probe2', 'probe3', 'probe4') {
        $rr = @($d | Where-Object { $_.probe -eq $p })
        $ok = @($rr | Where-Object { $okV[$p] -contains $_.verdict }).Count
        $cells += ("$ok/$($rr.Count)"); $totOk += $ok; $totAll += $rr.Count
    }
    $rows += [pscustomobject]@{ ruleset = $rs; pr1 = $cells[0]; pr2 = $cells[1]; pr3 = $cells[2]; pr4 = $cells[3]; ITog = "$totOk/$totAll"; okNum = $totOk; stamp = $c.LastWriteTime }
}
# берём САМЫЙ СВЕЖИЙ прогон на каждое правило (старые CPU-прогоны с ошибками игнорируем)
$rows = @($rows | Group-Object ruleset | ForEach-Object { $_.Group | Sort-Object stamp -Descending | Select-Object -First 1 })
Write-Host "=== НОЧНОЙ СВОД: правила x пробы (P=поведение, T=инструмент, S=скиллы, G=генерация) ==="
$rows | Sort-Object okNum -Descending | Select-Object ruleset, pr1, pr2, pr3, pr4, ITog | Format-Table -AutoSize | Out-String -Width 120
Write-Host ("всего прогонов: " + $rows.Count)