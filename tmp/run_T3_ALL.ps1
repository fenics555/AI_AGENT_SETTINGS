# T3: 4 zakona x 5 modeley. Vidimoe okno. Zopiy zakon ne trogaem.
$root="D:\AI\AGENT_SETTINGS\checks\agentic"
$log=Join-Path $root "log"
$sum="D:\AI\AGENT_SETTINGS\tmp\T3_ALL_summary.txt"
$laws=@("H9","H11","H12","H13")
$models=@("gemma4","qwen","laguna","nemotron","gpt-oss")
"=== T3 ALL START ===" | Out-File $sum -Encoding utf8
foreach($lk in $laws){
 foreach($m in $models){
  $t0=Get-Date
  Write-Host ("### H=$lk M=$m START " + $t0.ToString("HH:mm:ss"))
  $l0=Get-ChildItem $log -Filter "probe3_*.txt" | Sort-Object LastWriteTime -Descending | Select-Object -First 1
  Start-Process powershell -ArgumentList @("-NoProfile","-ExecutionPolicy","Bypass","-File",(Join-Path $root "check_3_skills_avail.ps1"),"-Models",$m,"-Rulesets",$lk,"-Seed","42") -WorkingDirectory $root -NoNewWindow -Wait
  $el=[math]::Round(((Get-Date)-$t0).TotalMinutes,1)
  $l=Get-ChildItem $log -Filter "probe3_*.txt" | Sort-Object LastWriteTime -Descending | Select-Object -First 1
  Write-Host ("### H=$lk M=$m DONE $el min")
  "--- H=$lk M=$m | $el min ---" | Out-File $sum -Append -Encoding utf8
  if($l){ Get-Content $l.FullName -Encoding utf8 | Where-Object { $_ -match "RESULT|ЭТАЛОН НА СТАРТЕ" } | Out-File $sum -Append -Encoding utf8 }
 }
}
"=== T3 ALL DONE ===" | Out-File $sum -Append -Encoding utf8
Write-Host "=== T3 ALL DONE ==="
