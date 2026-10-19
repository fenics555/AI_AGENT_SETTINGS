# Test 5 (CREO) na gemma4, zakon H11. Vidimoe okno.
$t5 = 'D:\AI\AGENT_SETTINGS\checks\agentic\check_5_creo.ps1'
$log = 'D:\AI\AGENT_SETTINGS\checks\agentic\log'
Write-Host "##### TEST 5 (CREO) START"
Start-Process powershell -ArgumentList @("-NoProfile","-ExecutionPolicy","Bypass","-File",$t5,"-Models","gemma4","-Law","H11","-Seed","42") -WorkingDirectory (Split-Path $t5 -Parent) -NoNewWindow -Wait
$l5 = Get-ChildItem $log -Filter "check5creo_*.txt" | Sort-Object LastWriteTime -Descending | Select-Object -First 1
if ($l5) { Write-Host ("log: "+$l5.Name); Get-Content $l5.FullName -Encoding utf8 | Where-Object { $_ -match "RESULT|VERDICT|ITOG|ETALON|FLAG|OTVET|ОТВЕТ|ИТОГ" } }
Write-Host "=== QUEUE DONE ==="
