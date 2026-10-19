# PROVERKA FIXOV: nemotron x testy 3,4 (zakon H9). Vidimoe okno.
$root="D:\AI\AGENT_SETTINGS\checks\agentic"
$log=Join-Path $root "log"
$sum="D:\AI\AGENT_SETTINGS\tmp\VERIFY_summary.txt"
"=== PROVERKA NA nemotron (slabaya): testy 3 i 4, zakon H9 ===" | Out-File $sum -Encoding utf8
$t0=Get-Date
Write-Host ("### TEST 3 START " + $t0.ToString("HH:mm:ss"))
Start-Process powershell -ArgumentList @("-NoProfile","-ExecutionPolicy","Bypass","-File",(Join-Path $root "check_3_skills_avail.ps1"),"-Models","nemotron","-Rulesets","H9","-Seed","42") -WorkingDirectory $root -NoNewWindow -Wait
Write-Host ("### TEST 3 DONE " + [math]::Round(((Get-Date)-$t0).TotalMinutes,1) + " min")
$l=Get-ChildItem $log -Filter "probe3_*.txt" | Sort-Object LastWriteTime -Descending | Select-Object -First 1
if($l){ Get-Content $l.FullName -Encoding utf8 | Where-Object { $_ -match "RESULT|ОТВЕТ МОДЕЛИ|ЭТАЛОН НА СТАРТЕ" } | Out-File $sum -Append -Encoding utf8 }
$t1=Get-Date
Write-Host ("### TEST 4 START " + $t1.ToString("HH:mm:ss"))
Start-Process powershell -ArgumentList @("-NoProfile","-ExecutionPolicy","Bypass","-File",(Join-Path $root "check_4_skills_read.ps1"),"-Models","nemotron","-Rulesets","H9","-Seed","42") -WorkingDirectory $root -NoNewWindow -Wait
Write-Host ("### TEST 4 DONE " + [math]::Round(((Get-Date)-$t1).TotalMinutes,1) + " min")
$l4=Get-ChildItem $log -Filter "probe4_*.txt" | Sort-Object LastWriteTime -Descending | Select-Object -First 1
if($l4){ Get-Content $l4.FullName -Encoding utf8 | Where-Object { $_ -match "RESULT|ОТВЕТ МОДЕЛИ|ЭТАЛОН" } | Out-File $sum -Append -Encoding utf8 }
"=== VERIFY DONE ===" | Out-File $sum -Append -Encoding utf8
Write-Host "=== VERIFY DONE ==="
