# ============================================================================
# chart.ps1 — ГРАФИКИ стенда: успех моделей по правилам (A/D/G) и пробам -> HTML+SVG
# ЗАПУСК: powershell -NoProfile -ExecutionPolicy Bypass -File chart.ps1
# ============================================================================
param([string]$Out = '')
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$ErrorActionPreference = 'Stop'
$logDir = 'D:\AI\AGENT_SETTINGS\checks\agentic\log'
if (-not $Out) { $Out = Join-Path $logDir ('CHART_stand_' + (Get-Date -Format 'yyyy-MM-dd_HHmmss') + '.html') }

$okV    = @{ probe1 = 'HONEST'; probe2 = 'PASS'; probe3 = 'SKILL_READ'; probe4 = 'PASS' }
$pname  = @{ probe1 = 'ПОВЕДЕНИЕ'; probe2 = 'ИНСТРУМЕНТ'; probe3 = 'СКИЛЛЫ'; probe4 = 'ГЕНЕРАЦИЯ' }
$probes = @('probe1','probe2','probe3','probe4')
$colors = @('#4472C4','#ED7D31','#70AD47')

$sets = @(
    @{ label = 'v7.0 (было)';       csv = 'run_2026-10-13_193223.csv' },
    @{ label = 'G (живой, стало)';   csv = 'run_2026-10-13_200627.csv' }
)

$data = @()
foreach ($s in $sets) {
    $p = Join-Path $logDir $s.csv
    if (-not (Test-Path $p)) { Write-Host ('нет данных (пропуск): ' + $s.csv); continue }
    $rows = @(Import-Csv $p | Where-Object { $_.task -ne 'SURVEY' })
    $vals = @{}
    foreach ($pr in $probes) {
        $rr = @($rows | Where-Object { $_.probe -eq $pr })
        $ok = @($rr | Where-Object { $okV[$pr] -contains $_.verdict }).Count
        $vals[$pr] = if ($rr.Count) { [int][math]::Round(100.0 * $ok / $rr.Count) } else { -1 }
    }
    $data += [pscustomobject]@{ label = $s.label; vals = $vals }
}

$W = 860; $H = 430; $left = 60; $baseY = 360; $maxH = 260
$groupW = [int](($W - $left - 40) / $probes.Count)
$barW = 34; $gap = 8
$svg = @()
$svg += "<svg xmlns='http://www.w3.org/2000/svg' width='$W' height='$H'><rect width='$W' height='$H' fill='white'/>"
$svg += "<line x1='$left' y1='$baseY' x2='$($W-20)' y2='$baseY' stroke='#333'/><line x1='$left' y1='$($baseY-$maxH)' x2='$left' y2='$baseY' stroke='#333'/>"
for ($g = 0; $g -lt $probes.Count; $g++) {
    $pr = $probes[$g]
    $gx = $left + $g * $groupW + 30
    for ($i = 0; $i -lt $data.Count; $i++) {
        $v = $data[$i].vals[$pr]
        if ($v -lt 0) { continue }
        $bh = [int]($maxH * $v / 100)
        $bx = $gx + $i * ($barW + $gap); $by = $baseY - $bh
        $svg += "<rect x='$bx' y='$by' width='$barW' height='$bh' fill='$($colors[$i])'/>"
        $svg += "<text x='$([int]($bx + $barW/2))' y='$($by-4)' font-size='12' text-anchor='middle' fill='#222'>$v%</text>"
    }
    $svg += "<text x='$([int]($gx+60))' y='$($baseY+20)' font-size='13' text-anchor='middle' fill='#222'>$($pname[$pr])</text>"
}
$lx = $left
for ($i = 0; $i -lt $data.Count; $i++) {
    $svg += "<rect x='$lx' y='20' width='16' height='16' fill='$($colors[$i])'/><text x='$($lx+22)' y='33' font-size='13' fill='#222'>$($data[$i].label)</text>"
    $lx += 200
}
$svg += "</svg>"

$html = @()
$html += "<!doctype html><html><head><meta charset='utf-8'><title>Стенд: успех по правилам</title></head><body>"
$html += "<h1>Стенд дома — успех моделей по правилам (seed=42)</h1>"
$html += "<p>Дата: $(Get-Date -Format 'yyyy-MM-dd HH:mm') · метрики: поведение=HONEST, инструмент=PASS, скиллы=SKILL_READ, генерация=PASS</p>"
$html += ($svg -join "`n")
$html += "<h2>Числа (успех, %)</h2><table border='1' cellpadding='6' style='border-collapse:collapse;font-family:sans-serif'>"
$html += "<tr><th>правило</th>" + (($probes | ForEach-Object { "<th>$($pname[$_])</th>" }) -join '') + "</tr>"
foreach ($d in $data) {
    $cells = ($probes | ForEach-Object { $v = $d.vals[$_]; if ($v -lt 0) { "<td>—</td>" } else { "<td>$v%</td>" } }) -join ''
    $html += "<tr><td>$($d.label)</td>$cells</tr>"
}
$html += "</table><p style='color:#888'>Стенд: D:\AI\AGENT_SETTINGS\checks\agentic · подробный отчёт: report.ps1</p></body></html>"
$html | Out-File $Out -Encoding utf8
Write-Host ('ГРАФИК: ' + $Out)
