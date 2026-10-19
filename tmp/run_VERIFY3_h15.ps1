# PROVERKA H15: SHAG-1=anti_hallucination, karta POISKOM, bez MANIFEST. nemotron, test 3.
$root="D:\AI\AGENT_SETTINGS\checks\agentic"
$log=Join-Path $root "log"
$sum="D:\AI\AGENT_SETTINGS\tmp\VERIFY3_summary.txt"
"=== H15 (anti-halluc + karta poiskom) x nemotron, test 3 ===" | Out-File $sum -Encoding utf8
$t0=Get-Date
Write-Host ("### H15 TEST3 START " + $t0.ToString("HH:mm:ss"))
Start-Process powershell -ArgumentList @("-NoProfile","-ExecutionPolicy","Bypass","-File",(Join-Path $root "check_3_skills_avail.ps1"),"-Models","nemotron","-Rulesets","H15","-Seed","42") -WorkingDirectory $root -NoNewWindow -Wait
Write-Host ("### H15 TEST3 DONE " + [math]::Round(((Get-Date)-$t0).TotalMinutes,1) + " min")
$l=Get-ChildItem $log -Filter "probe3_*.txt" | Sort-Object LastWriteTime -Descending | Select-Object -First 1
if($l){ Get-Content $l.FullName -Encoding utf8 | Where-Object { $_ -match "RESULT|ОТВЕТ МОДЕЛИ|ЭТАЛОН НА СТАРТЕ" } | Out-File $sum -Append -Encoding utf8 }
"=== DONE ===" | Out-File $sum -Append -Encoding utf8
Write-Host "=== DONE ==="
