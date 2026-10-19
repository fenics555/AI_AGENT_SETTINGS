# run_p21p25.ps1 — ПРОГОН 5 КОМПАКТНЫХ ВАРИАНТОВ (только тест 3 = где провалы S1/S2/S3)
param([string]$Rulesets='p12,p21,p22,p23,p24,p25', [string]$ModelsM='laguna,gemma4', [string]$Tag='p21_25')
$ErrorActionPreference='Continue'
$root='D:\AI\AGENT_SETTINGS\checks\agentic'
$logDir=Join-Path $root 'log'
$tmp='D:\AI\AGENT_SETTINGS\tmp'
cd $root
. 'D:\AI\AGENT_SETTINGS\config\paths.ps1'
$stamp=Get-Date -Format 'yyyyMMdd_HHmmss'
$sum=Join-Path $tmp ('run_p21p25_'+$Tag+'_'+$stamp+'_summary.txt')
function W($t){ $t | Out-File $sum -Append -Encoding utf8; Write-Host $t }

$laws=@($Rulesets.Split(','))
$models=@($ModelsM.Split(','))
W ("START $(Get-Date -Format 'HH:mm:ss')  ВАРИАНТЫ P21-P25 (тест 3) | законы=$Rulesets | модели=$ModelsM")
foreach ($rk in $laws) {
  $lp=Join-Path $CFG.LawsDir ('law_'+$rk+'.md')
  if (Test-Path $lp) { $it=Get-Item $lp; W ("LAW $rk : $($it.Length) б SHA=$((Get-FileHash $lp -Algorithm SHA256).Hash.Substring(0,8))") }
}
W ("ETALON: total=" + @(Get-ChildItem 'D:\AI\repo' -Recurse -File -Filter 'SKILL_*.md').Count + " creo=" + @(Get-ChildItem 'D:\AI\repo\Creo' -Recurse -File -Filter 'SKILL_*.md').Count + " prog=" + @(Get-ChildItem 'D:\AI\repo\Prog' -Recurse -File -Filter 'SKILL_*.md').Count)

$t00=Get-Date
$i=0
$total=$laws.Count*$models.Count
W ("JOBS: $total")
foreach ($rk in $laws) {
  foreach ($mk in $models) {
    $i++
    $t0=Get-Date
    $line='['+$i+'/'+$total+'] law='+$rk+' model='+$mk+' START '+$t0.ToString('HH:mm:ss')
    W $line
    Write-Host $line -ForegroundColor Yellow
    foreach ($mm in $CFG.Models) { & ollama stop $mm *>$null }
    Get-Process llama-server -EA SilentlyContinue | Stop-Process -Force -EA SilentlyContinue
    Start-Sleep -Seconds 5
    $full=Join-Path $root 'check_3_skills_avail.ps1'
    & powershell -NoProfile -ExecutionPolicy Bypass -File $full -Models $mk -Rulesets $rk -Seed 42
    Start-Sleep -Seconds 2
    $lg=Get-ChildItem $logDir -Filter 'probe3_*.txt' | Where-Object { $_.Name -notmatch 'trace' -and $_.LastWriteTime -ge $t0.AddSeconds(-3) } | Sort-Object LastWriteTime -Descending | Select-Object -First 1
    if ($lg) {
      W ('   log='+$lg.Name)
      $rr=Select-String -Path $lg.FullName -Pattern 'RESULT\|'
      foreach ($x in $rr) { W ('   '+$x.Line) }
      $c=Get-Content $lg.FullName -Encoding utf8 -Raw
      $p=$c.IndexOf('ОПРОС МОДЕЛИ')
      if ($p -ge 0) { W ('   SURVEY='+($c.Length-$p)+' симв.') }
    } else { W '   ЛОГА НЕТ' }
    $sec=[math]::Round(((Get-Date)-$t0).TotalSeconds,1)
    $avg=((Get-Date)-$t00).TotalSeconds/$i
    $eta=(Get-Date).AddSeconds($avg*($total-$i)).ToString('HH:mm')
    W ('   sec='+$sec+'  ETA~'+$eta+'  осталось='+($total-$i))
    Write-Host ('   sec='+$sec+' ETA~'+$eta) -ForegroundColor Cyan
  }
}
W ('ALL DONE '+(Get-Date -Format 'HH:mm:ss')+'  всего='+[math]::Round(((Get-Date)-$t00).TotalSeconds,1)+' с')
Write-Host ('ALL DONE '+(Get-Date -Format 'HH:mm:ss')) -ForegroundColor Green
