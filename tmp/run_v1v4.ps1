# run_v1v4.ps1 — ТЕСТ 4 НОРМАЛЬНЫХ ВАРИАНТОВ (v1..v4) x 3 модели x тест 3
param([string]$Rulesets='v1,v2,v3,v4', [string]$ModelsM='gemma4,qwen3.6,laguna', [string]$Tag='v1v4')
$ErrorActionPreference='Continue'
$root='D:\AI\AGENT_SETTINGS\checks\agentic'
$logDir=Join-Path $root 'log'
$tmp='D:\AI\AGENT_SETTINGS\tmp'
cd $root
. 'D:\AI\AGENT_SETTINGS\config\paths.ps1'
$stamp=Get-Date -Format 'yyyyMMdd_HHmmss'
$sum=Join-Path $tmp ('run_v1v4_'+$Tag+'_'+$stamp+'_summary.txt')
function W($t){ $t | Out-File $sum -Append -Encoding utf8; Write-Host $t }
$laws=@($Rulesets.Split(','))
$models=@($ModelsM.Split(','))
W ("START $(Get-Date -Format 'HH:mm:ss')  ВАРИАНТЫ v1-v4 | законы=$Rulesets | модели=$ModelsM | temp=0.1 seed=42")
foreach($rk in $laws){ $lp=Join-Path $CFG.LawsDir ('law_'+$rk+'.md'); if(Test-Path $lp){ W ("LAW $rk : $((Get-Item $lp).Length) б") } }
W ("ЭТАЛОН: total=" + @(Get-ChildItem 'D:\AI\repo' -Recurse -File -Filter 'SKILL_*.md').Count + " creo=" + @(Get-ChildItem 'D:\AI\repo\Creo' -Recurse -File -Filter 'SKILL_*.md').Count + " prog=" + @(Get-ChildItem 'D:\AI\repo\Prog' -Recurse -File -Filter 'SKILL_*.md').Count)
$t00=Get-Date; $i=0; $total=$laws.Count*$models.Count
W ("JOBS: $total")
foreach($rk in $laws){ foreach($mk in $models){
  $i++; $t0=Get-Date
  $line='['+$i+'/'+$total+'] law='+$rk+' model='+$mk+' START '+$t0.ToString('HH:mm:ss')
  W $line; Write-Host $line -ForegroundColor Yellow
  foreach($mm in $CFG.Models){ & ollama stop $mm *>$null }
  Get-Process llama-server -EA SilentlyContinue | Stop-Process -Force -EA SilentlyContinue
  Start-Sleep -Seconds 6
  & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $root 'check_3_skills_avail.ps1') -Models $mk -Rulesets $rk -Seed 42 -Temp 0.1 -OnlyTasks 'S1_total,S2_creo,S3_prog'
  Start-Sleep -Seconds 2
  $lg=Get-ChildItem $logDir -File -EA SilentlyContinue | Where-Object { $_.Name -like 'probe3_*.txt' -and $_.Name -notlike '*trace*' -and $_.LastWriteTime -ge $t0.AddSeconds(-3) } | Sort-Object LastWriteTime -Descending | Select-Object -First 1
  if($lg){ (Select-String -Path $lg.FullName -Pattern 'RESULT\|' | ForEach-Object { W ('   '+$_.Line) }) } else { W '   ЛОГА НЕТ' }
  $sec=[math]::Round(((Get-Date)-$t0).TotalSeconds,1)
  $avg=((Get-Date)-$t00).TotalSeconds/$i
  $eta=(Get-Date).AddSeconds($avg*($total-$i)).ToString('HH:mm')
  W ('   sec='+$sec+'  ETA~'+$eta+'  осталось='+($total-$i))
  Write-Host ('   sec='+$sec+' ETA~'+$eta) -ForegroundColor Cyan
}}
W ('ALL DONE '+(Get-Date -Format 'HH:mm:ss')+'  всего='+[math]::Round(((Get-Date)-$t00).TotalSeconds,1)+' с')
Write-Host ('ALL DONE '+(Get-Date -Format 'HH:mm:ss')) -ForegroundColor Green
