# NOCHNOY PROGON: 4 zakona x 5 modeley x test 3 (+ testy 4,5 po H11/H12)
# Vidimoe okno. ZHIVOY ZAKON NE TROGAEM - tolko kopii laws\law_H*.md
$root = "D:\AI\AGENT_SETTINGS\checks\agentic"
$log  = Join-Path $root "log"
$sum  = "D:\AI\AGENT_SETTINGS\tmp\NIGHT_summary.txt"
$laws = @("H9","H11","H12","H13")
$models = @("gemma4","qwen","laguna","nemotron","gpt-oss")
"=== NOCHNOY PROGON START ===" | Out-File $sum -Encoding utf8
"zakony: $($laws -join ","); modeli: $($models -join ",")" | Out-File $sum -Append -Encoding utf8
foreach ($lk in $laws) {
  foreach ($m in $models) {
    $t0 = Get-Date
    Write-Host ("##### H=$lk M=$m START " + $t0.ToString("HH:mm:ss"))
    Start-Process powershell -ArgumentList @("-NoProfile","-ExecutionPolicy","Bypass","-File",(Join-Path $root "check_3_skills_avail.ps1"),"-Models",$m,"-Rulesets",$lk,"-Seed","42") -WorkingDirectory $root -NoNewWindow -Wait
    $el = [math]::Round(((Get-Date)-$t0).TotalMinutes,1)
    $l = Get-ChildItem $log -Filter "probe3_*.txt" | Sort-Object LastWriteTime -Descending | Select-Object -First 1
    Write-Host ("### H=$lk M=$m DONE $el min")
    "--- H=$lk M=$m | $el min ---" | Out-File $sum -Append -Encoding utf8
    if ($l) { Get-Content $l.FullName -Encoding utf8 | Where-Object { $_ -match "RESULT|VERDICT" } | Out-File $sum -Append -Encoding utf8 }
  }
}
"=== T3 DONE, nachinaem T4 (H11,H12) ===" | Out-File $sum -Append -Encoding utf8
foreach ($lk in @("H11","H12")) {
  foreach ($m in $models) {
    $t0 = Get-Date
    Write-Host ("##### T4 H=$lk M=$m START")
    Start-Process powershell -ArgumentList @("-NoProfile","-ExecutionPolicy","Bypass","-File",(Join-Path $root "check_4_skills_read.ps1"),"-Models",$m,"-Rulesets",$lk,"-Seed","42") -WorkingDirectory $root -NoNewWindow -Wait
    $el = [math]::Round(((Get-Date)-$t0).TotalMinutes,1)
    $l = Get-ChildItem $log -Filter "probe4_*.txt" | Sort-Object LastWriteTime -Descending | Select-Object -First 1
    Write-Host ("### T4 H=$lk M=$m DONE $el min")
    "--- T4 H=$lk M=$m | $el min ---" | Out-File $sum -Append -Encoding utf8
    if ($l) { Get-Content $l.FullName -Encoding utf8 | Where-Object { $_ -match "RESULT|VERDICT" } | Out-File $sum -Append -Encoding utf8 }
  }
}
"=== T5 (H11) ===" | Out-File $sum -Append -Encoding utf8
foreach ($m in $models) {
  $t0 = Get-Date
  Write-Host ("##### T5 M=$m START")
  Start-Process powershell -ArgumentList @("-NoProfile","-ExecutionPolicy","Bypass","-File",(Join-Path $root "check_5_creo.ps1"),"-Models",$m,"-Law","H11","-Seed","42") -WorkingDirectory $root -NoNewWindow -Wait
  $el = [math]::Round(((Get-Date)-$t0).TotalMinutes,1)
  $l = Get-ChildItem $log -Filter "check5creo_*.txt" | Sort-Object LastWriteTime -Descending | Select-Object -First 1
  Write-Host ("### T5 M=$m DONE $el min")
  "--- T5 M=$m | $el min ---" | Out-File $sum -Append -Encoding utf8
  if ($l) { Get-Content $l.FullName -Encoding utf8 | Where-Object { $_ -match "RESULT|ИТОГ" } | Out-File $sum -Append -Encoding utf8 }
}
"=== NIGHT DONE ===" | Out-File $sum -Append -Encoding utf8
Write-Host "=== NIGHT DONE ==="
