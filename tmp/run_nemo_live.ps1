# run_nemo_live.ps1 - 1 тест: nemotron, тест 4, ЖИВОЙ закон (-Rulesets A)
$ErrorActionPreference = 'Continue'
$root = 'D:\AI\AGENT_SETTINGS\checks\agentic'
$logDir = Join-Path $root 'log'
$tmp = 'D:\AI\AGENT_SETTINGS\tmp'
cd $root
$stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$sum = Join-Path $tmp ('run_nemolive_' + $stamp + '_summary.txt')
"START $(Get-Date -Format 'HH:mm:ss')  nemotron + ЖИВОЙ закон + тест 4  stamp=$stamp" | Out-File $sum -Encoding utf8
('LAW live: ' + (Get-Item 'D:\AI\.clinerules').Length + ' б SHA=' + (Get-FileHash 'D:\AI\.clinerules' -Algorithm SHA256).Hash.Substring(0,8)) | Out-File $sum -Append -Encoding utf8
$t0 = Get-Date
Get-Process llama-server -EA SilentlyContinue | Stop-Process -Force -EA SilentlyContinue
Start-Sleep -Seconds 5
Write-Host 'nemotron | ЖИВОЙ закон | тест 4' -ForegroundColor Yellow
$targs = @('-NoProfile','-ExecutionPolicy','Bypass','-File',(Join-Path $root 'check_4_skills_read.ps1'),'-Models','nemotron','-Rulesets','A','-Seed','42')
Start-Process powershell -ArgumentList $targs -Wait -NoNewWindow
Start-Sleep -Seconds 2
$sec = [math]::Round(((Get-Date) - $t0).TotalSeconds, 1)
$lg = Get-ChildItem $logDir -Filter 'probe4_*.txt' | Where-Object { $_.Name -notmatch 'trace' } | Sort-Object LastWriteTime -Descending | Select-Object -First 1
Write-Host (('ИТОГО: ' + $sec + ' с')) -ForegroundColor Green
('  sec=' + $sec + '  log=' + $(if($lg){$lg.Name}else{'NONE'})) | Out-File $sum -Append -Encoding utf8
if ($lg) { (Select-String -Path $lg.FullName -Pattern 'RESULT\||ОШИБКА' | ForEach-Object { $_.Line }) | Out-File $sum -Append -Encoding utf8 }
('ALL DONE ' + (Get-Date -Format 'HH:mm:ss')) | Out-File $sum -Append -Encoding utf8
