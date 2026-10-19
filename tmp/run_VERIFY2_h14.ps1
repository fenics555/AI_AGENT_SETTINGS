# PROVERKA H14b (obryad: SHAG-1 = SKILL_index, bez MANIFEST) na nemotron, test 3. Vidimoe okno.
$root="D:\AI\AGENT_SETTINGS\checks\agentic"
$log=Join-Path $root "log"
$sum="D:\AI\AGENT_SETTINGS\tmp\VERIFY2_summary.txt"
"=== H14b (SHAG-1=SKILL_index) x nemotron, test 3 ===" | Out-File $sum -Encoding utf8
$t0=Get-Date
Write-Host ("### H14 TEST3 START " + $t0.ToString("HH:mm:ss"))
Start-Process powershell -ArgumentList @("-NoProfile","-ExecutionPolicy","Bypass","-File",(Join-Path $root "check_3_skills_avail.ps1"),"-Models","nemotron","-Rulesets","H14","-Seed","42") -WorkingDirectory $root -NoNewWindow -Wait
Write-Host ("### H14 TEST3 DONE " + [math]::Round(((Get-Date)-$t0).TotalMinutes,1) + " min")
$l=Get-ChildItem $log -Filter "probe3_*.txt" | Sort-Object LastWriteTime -Descending | Select-Object -First 1
if($l){ Get-Content $l.FullName -Encoding utf8 | Where-Object { $_ -match "RESULT|ОТВЕТ МОДЕЛИ|ЭТАЛОН НА СТАРТЕ|depth=" } | Out-File $sum -Append -Encoding utf8 }
"=== DONE ===" | Out-File $sum -Append -Encoding utf8
Write-Host "=== DONE ==="

