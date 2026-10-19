# run_canon3.ps1 — ПОЛНЫЙ ПРОГОН КАНОНА (простая версия, без вложенных однострочных foreach)
param([string]$Rulesets='p12', [string]$ModelsM='laguna', [string]$Tag='c3')
$ErrorActionPreference='Continue'
$root='D:\AI\AGENT_SETTINGS\checks\agentic'
$logDir=Join-Path $root 'log'
$tmp='D:\AI\AGENT_SETTINGS\tmp'
cd $root
. 'D:\AI\AGENT_SETTINGS\config\paths.ps1'
$stamp=Get-Date -Format 'yyyyMMdd_HHmmss'
$sum=Join-Path $tmp ('run_canon3_'+$Tag+'_'+$stamp+'_summary.txt')
function W($t){ $t | Out-File $sum -Append -Encoding utf8; Write-Host $t }

$laws=@($Rulesets.Split(','))
$models=@($ModelsM.Split(','))
W ("START $(Get-Date -Format 'HH:mm:ss')  КАНОН3 | законы=$Rulesets | модели=$ModelsM")
W ("ETALON: total=" + @(Get-ChildItem 'D:\AI\repo' -Recurse -File -Filter 'SKILL_*.md').Count + " creo=" + @(Get-ChildItem 'D:\AI\repo\Creo' -Recurse -File -Filter 'SKILL_*.md').Count)

$testScripts=@('check_3_skills_avail.ps1','check_4_skills_read.ps1')
$testKeys=@('probe3_','probe4_')

$i=0
$total=$laws.Count * $models.Count * $testScripts.Count
W ("JOBS: $total")

foreach ($rk in $laws) {
  foreach ($mk in $models) {
    for ($ti=0; $ti -lt $testScripts.Count; $ti++) {
      $i++
      $scr=$testScripts[$ti]
      $key=$testKeys[$ti]
      $t0=Get-Date
      $line='['+$i+'/'+$total+'] law='+$rk+' model='+$mk+' script='+$scr+' START '+$t0.ToString('HH:mm:ss')
      W $line
      Write-Host $line -ForegroundColor Yellow
      foreach ($mm in $CFG.Models) { & ollama stop $mm *>$null }
      Get-Process llama-server -EA SilentlyContinue | Stop-Process -Force -EA SilentlyContinue
      Start-Sleep -Seconds 5
      $full=Join-Path $root $scr
      if (-not (Test-Path $full)) { W ('   НЕТ СКРИПТА: '+$full); continue }
      & powershell -NoProfile -ExecutionPolicy Bypass -File $full -Models $mk -Rulesets $rk -Seed 42
      Start-Sleep -Seconds 2
      $lg=Get-ChildItem $logDir -Filter ($key+'*.txt') | Where-Object { $_.Name -notmatch 'trace' -and $_.LastWriteTime -ge $t0.AddSeconds(-3) } | Sort-Object LastWriteTime -Descending | Select-Object -First 1
      if ($lg) {
        W ('   log='+$lg.Name)
        $rr=Select-String -Path $lg.FullName -Pattern 'RESULT\|'
        foreach ($x in $rr) { W ('   '+$x.Line) }
      } else { W '   ЛОГА НЕТ' }
      $sec=[math]::Round(((Get-Date)-$t0).TotalSeconds,1)
      W ('   sec='+$sec)
      Write-Host ('   sec='+$sec) -ForegroundColor Cyan
    }
  }
}
W ('ALL DONE '+(Get-Date -Format 'HH:mm:ss'))
Write-Host ('ALL DONE '+(Get-Date -Format 'HH:mm:ss')) -ForegroundColor Green
