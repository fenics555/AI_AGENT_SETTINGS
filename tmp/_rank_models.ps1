$f = Get-ChildItem 'D:\AI\AGENT_SETTINGS\tmp' -Filter 'run_5laws_*_summary.txt' | Sort-Object LastWriteTime -Descending | Select-Object -First 1
$lines = Get-Content $f.FullName -Encoding utf8

Write-Host '=== ИТОГИ ПО МОДЕЛЯМ (тест 3: COUNT_OK) ==='
$t3 = @{}
foreach ($l in $lines) {
  if ($l -match '^RESULT\|probe3\|R_(\d)\|([^|]+)\|S\d') {
    $law = $Matches[1]; $m = $Matches[2]
    $ok = if ($l -match '\|COUNT_OK\|') { 1 } else { 0 }
    if (-not $t3.ContainsKey($m)) { $t3[$m] = @{ ok = 0; all = 0 } }
    $t3[$m].ok += $ok; $t3[$m].all += 1
  }
}
foreach ($k in $t3.Keys | Sort-Object) {
  $v = $t3[$k]
  Write-Host ('  ' + $k.PadRight(30) + ' ' + $v.ok + '/' + $v.all)
}

Write-Host ''
Write-Host '=== ИТОГИ ПО МОДЕЛЯМ (тест 4: SKILL_READ) ==='
$t4 = @{}
foreach ($l in $lines) {
  if ($l -match '^RESULT\|probe4\|R_(\d)\|([^|]+)\|T\d') {
    $m = $Matches[2]
    $ok = if ($l -match '\|SKILL_READ\|') { 1 } else { 0 }
    if (-not $t4.ContainsKey($m)) { $t4[$m] = @{ ok = 0; all = 0 } }
    $t4[$m].ok += $ok; $t4[$m].all += 1
  }
}
foreach ($k in $t4.Keys | Sort-Object) {
  $v = $t4[$k]
  Write-Host ('  ' + $k.PadRight(30) + ' ' + $v.ok + '/' + $v.all)
}
