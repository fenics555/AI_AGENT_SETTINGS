# Drajver: testy 4+5 na gemma4, zakon H11. Vidimoe okno.
$t4 = 'D:\AI\AGENT_SETTINGS\checks\agentic\check_4_skills_read.ps1'
$t5 = 'D:\AI\AGENT_SETTINGS\checks\agentic\check_5_creo.ps1'
$log = 'D:\AI\AGENT_SETTINGS\checks\agentic\log'
$sum = 'D:\AI\AGENT_SETTINGS\tmp\run_H11_t45_gemma4_summary.txt'
"START 4+5 gemma4 H11" | Out-File $sum -Encoding utf8
Write-Host "##### TEST 4 (SKILLS APPLY) "; Start-Process powershell -ArgumentList @("-NoProfile","-ExecutionPolicy","Bypass","-File",$t4,"-Models","gemma4","-Rulesets","H11","-Seed","42") -WorkingDirectory (Split-Path $t4 -Parent) -NoNewWindow -Wait
$l4 = Get-ChildItem $log -Filter "probe4_*.txt" | Sort-Object LastWriteTime -Descending | Select-Object -First 1
if ($l4) { Write-Host ("log4: "+$l4.Name); Get-Content $l4.FullName -Encoding utf8 | Where-Object { $_ -match "RESULT|VERDICT|ETALON|SKILL_READ|FLAG" } | Tee-Object -Append $sum }
Write-Host "##### TEST 5 (CREO)"; Start-Process powershell -ArgumentList @("-NoProfile","-ExecutionPolicy","Bypass","-File",$t5,"-Models","gemma4","-Law","H11","-Seed","42") -WorkingDirectory (Split-Path $t5 -Parent) -NoNewWindow -Wait
$l5 = Get-ChildItem $log -Filter "check5creo_*.txt" | Sort-Object LastWriteTime -Descending | Select-Object -First 1
if ($l5) { Write-Host ("log5: "+$l5.Name); Get-Content $l5.FullName -Encoding utf8 | Where-Object { $_ -match "RESULT|VERDICT|ETALON|FLAG" } | Tee-Object -Append $sum }
Write-Host "=== QUEUE DONE ==="
