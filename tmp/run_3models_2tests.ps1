# run_3models_2tests.ps1 — P12-P25 x 3 модели x 2 теста (по просьбе владельца)
# Модели: qwen3.6 (средняя), gpt-oss (самая низкая по VRAM), laguna (выбор ноги)
param([string]$Rulesets='p12,p21,p22,p23,p24,p25', [string]$ModelsM='qwen3.6,gpt-oss,laguna', [string]$Tag='3m2t')
$ErrorActionPreference='Continue'
$root='D:\AI\AGENT_SETTINGS\checks\agentic'
$logDir=Join-Path $root 'log'
$tmp='D:\AI\AGENT_SETTINGS\tmp'
cd $root
. 'D:\AI\AGENT_SETTINGS\config\paths.ps1'
$stamp=Get-Date -Format 'yyyyMMdd_HHmmss'
$sum=Join-Path $tmp ('run_3m2t_'+$Tag+'_'+$stamp+'_summary.txt')
function W($t){ $t | Out-File $sum -Append -Encoding utf8; Write-Host $t }

$laws=@($Rulesets.Split(','))
$models=@($ModelsM.Split(','))
W ("START $(Get-Date -Format 'HH:mm:ss')  3 МОДЕЛИ x 2 ТЕСТА | законы=$Rulesets | модели=$ModelsM")
foreach ($rk in $laws) {
  $lp=Join-Path $CFG.LawsDir ('law_'+$rk+'.md')
  if (Test-Path $lp) { $it=Get-Item $lp; W ("LAW $rk : $($it.Length) б SHA=$((Get-FileHash $lp -Algorithm SHA256).Hash.Substring(0,8))") }
}
W ("ETALON: total=" + @(Get-ChildItem 'D:\AI\repo' -Recurse -File -Filter 'SKILL_*.md').Count + " creo=" + @(Get-ChildItem 'D:\AI\repo\Creo' -Recurse -File -Filter 'SKILL_*.md').Count + " prog=" + @(Get-ChildItem 'D:\AI\repo\Prog' -Recurse -File -Filter 'SKILL_*.md').Count)

$t00=Get-Date
$i=0
$total=$laws.Count*$models.Count*2
W ("JOBS: $total")
foreach ($rk in $laws) {
  foreach ($mk in $models) {
    for ($ti=0; $ti -lt 2; $ti++) {
      $i++
      if ($ti -eq 0) { $scr='check_3_skills_avail.ps1'; $key='probe3_' } else { $scr='check_4_skills_read.ps1'; $key='probe4_' }
      $t0=Get-Date
      $line='['+$i+'/'+$total+'] law='+$rk+' model='+$mk+' script='+$scr+' START '+$t0.ToString('HH:mm:ss')
      W $line
      Write-Host $line -ForegroundColor Yellow
      foreach ($mm in $CFG.Models) { & ollama stop $mm *>$null }
      Get-Process llama-server -EA SilentlyContinue | Stop-Process -Force -EA SilentlyContinue
      Start-Sleep -Seconds 5
      $full=Join-Path $root $scr
      & powershell -NoProfile -ExecutionPolicy Bypass -File $full -Models $mk -Rulesets $rk -Seed 42
      Start-Sleep -Seconds 2
      $lg=Get-ChildItem $logDir -Filter ($key+'*.txt') | Where-Object { $_.Name -notmatch 'trace' -and $_.LastWriteTime -ge $t0.AddSeconds(-3) } | Sort-Object LastWriteTime -Descending | Select-Object -First 1
      if ($lg) {
        W ('   log='+$lg.Name)
        $rr=Select-String -Path $lg.FullName -Pattern 'RESULT\|'
        foreach ($x in $rr) { W ('   '+$x.Line) }
        # §6.1.6: ОТВЕТЫ МОДЕЛЕЙ -> ПОЛНОСТЬЮ (финал, допрос Ш1-Ш5, опрос)
        $c=Get-Content $lg.FullName -Encoding utf8 -Raw
        foreach ($hdr in 'ФИНАЛЬНЫЙ ОТВЕТ','Ш1 ЧТО ДЕЛАЛА','Ш2 ЧТО ЧИТАЛА','Ш3 ПОЧЕМУ','Ш4 ЧТО УЛУЧШИТЬ','Ш5 ЧТО КОНКРЕТНО СЧИТАЛА','ОПРОС МОДЕЛИ') {
          $p=$c.IndexOf($hdr)
          if ($p -ge 0) {
            $blk=$c.Substring($p)
            if ($blk.Length -gt 2200) { $blk=$blk.Substring(0,2200)+' ... [усечено 2200]' }
            W ('   --- '+$hdr+' ---')
            W ($blk.TrimEnd())
          }
        }
      } else { W '   ЛОГА НЕТ' }
      $sec=[math]::Round(((Get-Date)-$t0).TotalSeconds,1)
      $avg=((Get-Date)-$t00).TotalSeconds/$i
      $eta=(Get-Date).AddSeconds($avg*($total-$i)).ToString('HH:mm')
      W ('   sec='+$sec+'  ETA~'+$eta+'  осталось='+($total-$i))
      Write-Host ('   sec='+$sec+' ETA~'+$eta) -ForegroundColor Cyan
    }
  }
}
W ('ALL DONE '+(Get-Date -Format 'HH:mm:ss')+'  всего='+[math]::Round(((Get-Date)-$t00).TotalSeconds,1)+' с')
Write-Host ('ALL DONE '+(Get-Date -Format 'HH:mm:ss')) -ForegroundColor Green
