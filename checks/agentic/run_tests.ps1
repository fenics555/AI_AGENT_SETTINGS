# ============================================================================
# run_tests.ps1 — ЗАПУСКАЛКА ВСЕХ ТЕСТОВ (канон 6: 5 + 1 старый) + ЕДИНЫЙ ФАЙЛ ИТОГОВ
# ============================================================================
# ПО-ПРОСТОМУ: это НЕ «раннер» и не новая сущность — просто скрипт, который по очереди
# запускает канон-тесты и складывает их результаты в один файл, чтобы сравнивать прогоны.
#   правила поменял -> запустил run_tests.ps1 -> увидел сводку и разницу с прошлым прогоном.
# ВЫВОДИТ ПРИМЕРНОЕ ВРЕМЯ: перед каждым тестом — оценка по прошлым прогонам, после теста —
# фактическое время и обновлённая оценка «осталось ~N мин».
# КАНОН (6 тестов): 1 check_1_law · 2 check_2_read · 3 check_3_skills_avail · 4 check_4_skills_read ·
#   5 check_5_creo · 6 check_4_write (старый). Логика последовательная — см. README.md §1.
# ЗАПУСК: powershell -NoProfile -ExecutionPolicy Bypass -File run_tests.ps1 [-Probes 1,2,3,4,5,6] [-Law 32] [-Models all]
# ВЫХОД: log\run_<дата>.csv (таблица итогов), log\run_<дата>.txt (сводка), log\run_<дата>.log (прогресс)
# ============================================================================

param([string]$Probes = '1,2,3,4,5', [string]$Law = '32', [string]$Models = 'all')

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$ProgressPreference = 'SilentlyContinue'
$ErrorActionPreference = 'Continue'

$root   = 'D:\AI\AGENT_SETTINGS\checks\agentic'
$logDir = Join-Path $root 'log'
$stamp  = Get-Date -Format 'yyyy-MM-dd_HHmmss'
$suiteCsv = Join-Path $logDir ("run_" + $stamp + ".csv")
$suiteTxt = Join-Path $logDir ("run_" + $stamp + ".txt")
$suiteLog = Join-Path $logDir ("run_" + $stamp + ".log")

$map = @{
    '1' = @{ script = 'check_1_law.ps1';    args = @('-Models', $Models, '-Law', $Law);                 name = 'ЗАКОН' }
    '2' = @{ script = 'check_2_read.ps1';   args = @('-Models', $Models, '-Law', $Law);                 name = 'ЧТЕНИЕ' }
    '3' = @{ script = 'check_3_skills_avail.ps1'; args = @('-Models', $Models, '-Rulesets', $Law, '-AskRead'); name = 'СКИЛЛЫ:ВИДИМОСТЬ' }
    '4' = @{ script = 'check_4_skills_read.ps1';  args = @('-Models', $Models, '-Rulesets', $Law, '-AskRead'); name = 'СКИЛЛЫ:ПРИМЕНЕНИЕ' }
    '5' = @{ script = 'check_5_creo.ps1';   args = @('-Models', $Models, '-Law', $Law);                 name = 'CREO' }
    '6' = @{ script = 'check_4_write.ps1';  args = @('-Models', $Models, '-Law', $Law);                 name = 'ЗАПИСЬ (старый)' }
}

# --- ПРИМЕРНОЕ ВРЕМЯ: оценка по прошлым прогонам (для каждого теста) ---
function Get-HistSec {
    param([string]$ProbeN, [int]$DefaultSec)
    $logs = @(Get-ChildItem $logDir -File -ErrorAction SilentlyContinue | Where-Object { $_.Name -match '^(run|suite)_' -and $_.Extension -eq '.log' } | Sort-Object LastWriteTime -Descending | Select-Object -First 6)
    $vals = @()
    foreach ($l in $logs) {
        $st = $null
        foreach ($ln in (Get-Content $l.FullName -Encoding utf8 -ErrorAction SilentlyContinue)) {
            if ($ln -match ("^PROBE {0} .* START (\d{{2}}:\d{{2}}:\d{{2}})" -f $ProbeN)) { $st = [datetime]::ParseExact($matches[1], 'HH:mm:ss', $null) }
            elseif ($ln -match ("^PROBE {0} END (\d{{2}}:\d{{2}}:\d{{2}})" -f $ProbeN)) {
                if ($st) { $en = [datetime]::ParseExact($matches[1], 'HH:mm:ss', $null); $d = ($en - $st).TotalSeconds; if ($d -gt 0) { $vals += $d }; $st = $null }
            }
        }
    }
    if ($vals.Count) { return [int](($vals | Measure-Object -Average).Average) } else { return $DefaultSec }
}
$DEF = @{ '1' = 600; '2' = 720; '3' = 2100; '4' = 900 }   # секунды по умолчанию (5 моделей)
$histSec = @{}
$estTotal = 0
foreach ($n in @($Probes -split ',' | ForEach-Object { $_.Trim() })) {
    if ($map.ContainsKey($n)) { $histSec[$n] = Get-HistSec -ProbeN $n -DefaultSec $DEF[$n]; $estTotal += $histSec[$n] }
}
Write-Host ("ОЦЕНКА ВРЕМЕНИ: " + (($histSec.Keys | Sort-Object | ForEach-Object { "тест $_ ~" + [math]::Round($histSec[$_]/60,1) + " мин" }) -join ' | ') + "  =>  ВСЕГО ~" + [math]::Round($estTotal/60,1) + " мин")
# (строка ОЦЕНКА в лог пишется ПОСЛЕ START — см. ниже; раньше её затирала запись START)

"START $(Get-Date -Format 'HH:mm:ss')  probes=$Probes  rulesets=$Rulesets  models=$Models" | Out-File $suiteLog -Encoding utf8
("ОЦЕНКА " + ($histSec.Keys | Sort-Object | ForEach-Object { "p$_=" + [math]::Round($histSec[$_]/60,1) + "м" }) + " всего=" + [math]::Round($estTotal/60,1) + "м") | Out-File $suiteLog -Append -Encoding utf8
Write-Host "=== ЗАПУСКАЛКА КАНОН-НАБОРА  ($stamp)  probes=$Probes models=$Models ==="

$rows = @()
$leftSec = $estTotal
foreach ($n in @($Probes -split ',' | ForEach-Object { $_.Trim() })) {
    if (-not $map.ContainsKey($n)) { Write-Host ("пропуск: неизвестный тест '$n'"); continue }
    $it = $map[$n]
    $p  = Join-Path $root $it.script
    if (-not (Test-Path $p)) { Write-Host ("пропуск: нет файла $p"); continue }
    $estMin = [math]::Round($histSec[$n] / 60, 1)
    Write-Host ("--- probe_$n ($($it.name)) : $($it.script) ---  ОЦЕНКА ~$estMin мин | осталось всего ~" + [math]::Round($leftSec / 60, 1) + " мин")
    ('PROBE {0} {1} START {2}' -f $n, $it.script, (Get-Date -Format 'HH:mm:ss')) | Out-File $suiteLog -Append -Encoding utf8
    $t0 = Get-Date

    $o = Join-Path $logDir ("suite_probe$n.out")
    $e = Join-Path $logDir ("suite_probe$n.err")
    Remove-Item $o, $e -ErrorAction SilentlyContinue
    $args = @('-NoProfile','-ExecutionPolicy','Bypass','-File',$p) + $it.args
    $proc = Start-Process -FilePath 'powershell.exe' -ArgumentList $args -RedirectStandardOutput $o -RedirectStandardError $e -WindowStyle Hidden -PassThru
    Write-Host ("    pid=$($proc.Id) — ждём...")
    Wait-Process -Id $proc.Id -Timeout 7200 -ErrorAction SilentlyContinue
    $actSec = ((Get-Date) - $t0).TotalSeconds
    $leftSec = [math]::Max(0, $leftSec - $histSec[$n])
    Write-Host ("    ФАКТ: " + [math]::Round($actSec / 60, 1) + " мин (оценка была ~$estMin) | осталось ~" + [math]::Round($leftSec / 60, 1) + " мин")
    ('PROBE {0} FACT {1}s est={2}s' -f $n, [int]$actSec, $histSec[$n]) | Out-File $suiteLog -Append -Encoding utf8
    ('PROBE {0} END {1}' -f $n, (Get-Date -Format 'HH:mm:ss')) | Out-File $suiteLog -Append -Encoding utf8

    # свежий result-файл этого теста (пишет сам тест: probeN_<дата>.txt)
    $rf = Get-ChildItem $logDir -Filter ("probe{0}_*.txt" -f $n) | Sort-Object LastWriteTime -Descending | Select-Object -First 1
    if (-not $rf) { Write-Host ("    нет результата probe_$n"); ('PROBE {0} NO_RESULT' -f $n) | Out-File $suiteLog -Append -Encoding utf8; continue }
    Write-Host ("    результат: " + $rf.Name)
    $lines = @(Get-Content $rf.FullName -Encoding utf8 | Where-Object { $_ -like 'RESULT|*' })
    foreach ($ln in $lines) {
        $a = $ln -split '\|'
        # probe3 пишет лишнее поле ruleset -> сдвиг
        if ($n -eq '3') { $mdl = $a[3]; $tsk = $a[4]; $vrd = $a[5]; $info = ($a[6..($a.Count - 1)] -join '|') }
        else            { $mdl = $a[2]; $tsk = $a[3]; $vrd = $a[4]; $info = ($a[5..($a.Count - 1)] -join '|') }
        $rows += [pscustomobject]@{ probe = ("probe" + $n); model = $mdl; task = $tsk; verdict = $vrd; info = $info }
    }
}

$rows | Export-Csv -Path $suiteCsv -NoTypeInformation -Encoding utf8
Write-Host ""
Write-Host ("Единый CSV: " + $suiteCsv)
Write-Host ("Строк: " + $rows.Count)
# --- СВОДКА ---
$sum = @()
$sum += ("РАННЕР КАНОН-НАБОРА " + $stamp + "  (probes=$Probes rulesets=$Rulesets models=$Models)")
if (-not $rows.Count) { $sum += "НЕТ СТРОК RESULT — проверь, что тесты завершились и пишут probeN_<дата>.txt" }
foreach ($pn in @($rows | Select-Object -ExpandProperty probe -Unique)) {
    $pr    = @($rows | Where-Object { $_.probe -eq $pn })
    $tasks = @($pr | Where-Object { $_.task -ne 'SURVEY' })
    $sum += ""
    $sum += ("[{0}] строк {1}, задач {2}" -f $pn, $pr.Count, $tasks.Count)
    foreach ($g in ($tasks | Group-Object verdict | Sort-Object Name)) {
        $sum += ("    {0,-14} {1}" -f $g.Name, $g.Count)
    }
    foreach ($m in @($tasks | Select-Object -ExpandProperty model -Unique)) {
        $mm = @($tasks | Where-Object { $_.model -eq $m })
        $ok = @($mm | Where-Object { $_.verdict -in @('PASS','SKILL_READ','HONEST','ANSWERED') }).Count
        $sum += ("    {0,-30} успех {1}/{2}" -f $m, $ok, $mm.Count)
    }
    foreach ($s in @($pr | Where-Object { $_.task -eq 'SURVEY' })) {
        $sum += ("    ОПРОС {0}: {1}" -f $s.model, $s.info)
    }
}

# --- СРАВНЕНИЕ С BASELINE (предыдущий suite_*.csv) ---
# --- СКОРОСТЬ: токены/с модели (генерация) + секунды выполнения задания ---
$sum += ""
$sum += "СКОРОСТЬ (средние; время задания включает загрузку модели при первом обращении):"
$spd = @($rows | Where-Object { $_.task -ne 'SURVEY' })
foreach ($pn in @($spd | Select-Object -ExpandProperty probe -Unique)) {
    foreach ($m in @($spd | Where-Object { $_.probe -eq $pn } | Select-Object -ExpandProperty model -Unique)) {
        $rr = @($spd | Where-Object { $_.probe -eq $pn -and $_.model -eq $m })
        $tpsV = @(); $secV = @()
        foreach ($row in $rr) {
            if ($row.info -match 'tps=([\d\.]+)') { $tpsV += [double]$matches[1] }
            if ($row.info -match 'sec=([\d\.]+)') { $secV += [double]$matches[1] }
        }
        $tpsAvg = if ($tpsV.Count) { [math]::Round(($tpsV | Measure-Object -Average).Average, 1) } else { 0 }
        $secAvg = if ($secV.Count) { [math]::Round(($secV | Measure-Object -Average).Average, 1) } else { 0 }
        $sum += ("    {0,-8} {1,-30} {2,6} ток/с | задание ~{3} с" -f $pn, $m, $tpsAvg, $secAvg)
    }
}
$prev = Get-ChildItem $logDir -File -ErrorAction SilentlyContinue | Where-Object { $_.Name -match '^run_.*\.csv$' -and $_.FullName -ne $suiteCsv } | Sort-Object LastWriteTime -Descending | Select-Object -First 1
$sum += ""
if ($prev) {
    $sum += ("СРАВНЕНИЕ С BASELINE: " + $prev.Name)
    $old = @(Import-Csv $prev.FullName)
    foreach ($pn in @($rows | Select-Object -ExpandProperty probe -Unique)) {
        foreach ($vd in @('PASS','SKILL_READ','MAP_ONLY','NO_SKILL_READ','NO_TOOLS','HONEST','PRETEND','HALLUC','PART','FAIL','ERROR')) {
            $nowC = @($rows | Where-Object { $_.probe -eq $pn -and $_.verdict -eq $vd -and $_.task -ne 'SURVEY' }).Count
            $oldC = @($old  | Where-Object { $_.probe -eq $pn -and $_.verdict -eq $vd -and $_.task -ne 'SURVEY' }).Count
            if ($nowC -ne 0 -or $oldC -ne 0) {
                $d = $nowC - $oldC
                $mark = if ($d -gt 0) { '+' } else { '' }
                $sum += ("    {0,-8} {1,-14} было {2,2} -> стало {3,2}  ({4}{5})" -f $pn, $vd, $oldC, $nowC, $mark, $d)
            }
        }
    }
} else {
    $sum += "BASELINE: предыдущих прогонов suite_*.csv нет — этот прогон СТАНЕТ baseline."
}

$sum | Out-File $suiteTxt -Encoding utf8
$sum | ForEach-Object { Write-Host $_ }
Write-Host ""
Write-Host ("Сводка: " + $suiteTxt)
Write-Host ("Лог: " + $suiteLog)
('DONE ' + (Get-Date -Format 'HH:mm:ss')) | Out-File $suiteLog -Append -Encoding utf8
