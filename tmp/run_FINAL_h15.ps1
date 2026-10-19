# FINAL-тест: H15 x gemma4:26b, test 3. Polnaya proverka.
$root="D:\AI\AGENT_SETTINGS\checks\agentic"
$log=Join-Path $root "log"
$sum="D:\AI\AGENT_SETTINGS\tmp\FINAL_summary.txt"
"=== FINAL: H15 x gemma4:26b, test 3 ===" | Out-File $sum -Encoding utf8
$t0=Get-Date
Write-Host ("### FINAL START " + $t0.ToString("HH:mm:ss"))
Start-Process powershell -ArgumentList @("-NoProfile","-ExecutionPolicy","Bypass","-File",(Join-Path $root "check_3_skills_avail.ps1"),"-Models","gemma","-Rulesets","H15","-Seed","42") -WorkingDirectory $root -NoNewWindow -Wait
Write-Host ("### FINAL DONE " + [math]::Round(((Get-Date)-$t0).TotalMinutes,1) + " min")
$l=Get-ChildItem $log -Filter "probe3_*.txt" | Sort-Object LastWriteTime -Descending | Select-Object -First 1
if($l){ "LOG: " + $l.Name | Out-File $sum -Append -Encoding utf8; Get-Content $l.FullName -Encoding utf8 | Where-Object { $_ -match "RESULT|ЭТАЛОН|ОТВЕТ МОДЕЛИ|СТАРТ|RUN" } | Out-File $sum -Append -Encoding utf8 }
"=== DONE ===" | Out-File $sum -Append -Encoding utf8
