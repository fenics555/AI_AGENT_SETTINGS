# run_matrix.ps1 — МАТРИЦА: законы w6..w10 (+w2 контроль) x 3 модели x 2 теста (S1_total, S2_creo)
# Образец: run_w1w5.ps1 (тот же чекер check_3_skills_avail.ps1, те же seed/temp).
# ФИКСАЦИЯ (§М.2е): temp=0.1 seed=42 -> результат воспроизводим и сравним с ночным прогоном.
param(
  [string]$Rulesets = 'w6,w7,w8,w9,w10,w2',
  [string]$ModelsM  = 'gemma4,qwen3.6,laguna',
  [string]$Tasks    = 'S1_total,S2_creo',
  [string]$Tag      = 'matrix'
)
$ErrorActionPreference='Continue'
$root='D:\AI\AGENT_SETTINGS\checks\agentic'
$logDir=Join-Path $root 'log'
$tmp='D:\AI\AGENT_SETTINGS\tmp'
cd $root
. 'D:\AI\AGENT_SETTINGS\config\paths.ps1'
$stamp=Get-Date -Format 'yyyyMMdd_HHmmss'
$sum=Join-Path $tmp ('run_'+$Tag+'_'+$stamp+'_summary.txt')
function W($t){ $t | Out-File $sum -Append -Encoding utf8; Write-Host $t }
$laws=@($Rulesets.Split(','))
$models=@($ModelsM.Split(','))
W ("START $(Get-Date -Format 'HH:mm:ss')  МАТРИЦА | законы=$Rulesets | модели=$ModelsM | задачи=$Tasks | temp=0.1 seed=42")
# §0б: SHA каждого закона — фиксируем ДО прогона и сверяем в каждой фазе (ловит подмену)
$shaOf = @{}
foreach($rk in $laws){
  $lp=Join-Path $CFG.LawsDir ('law_'+$rk+'.md')
  if(Test-Path $lp){ $h=(Get-FileHash $lp -Algorithm SHA256).Hash; $shaOf[$rk]=$h
    W ("LAW $rk : $((Get-Item $lp).Length) б  SHA=$($h.Substring(0,16))...") }
  else { W ("LAW $rk : НЕТ ФАЙЛА!") }
}
W ("ЭТАЛОН: total=" + @(Get-ChildItem 'D:\AI\repo' -Recurse -File -Filter 'SKILL_*.md').Count + " creo=" + @(Get-ChildItem 'D:\AI\repo\Creo' -Recurse -File -Filter 'SKILL_*.md').Count + " prog=" + @(Get-ChildItem 'D:\AI\repo\Prog' -Recurse -File -Filter 'SKILL_*.md').Count)
$t00=Get-Date; $i=0; $total=$laws.Count*$models.Count
W ("JOBS: $total")
foreach($rk in $laws){ foreach($mk in $models){
  $i++; $t0=Get-Date
  $line='['+$i+'/'+$total+'] law='+$rk+' model='+$mk+' START '+$t0.ToString('HH:mm:ss')
  W $line
  # §0б: СВЕРКА SHA закона ПЕРЕД фазой — подмена/расхождение = громкий флаг
  $lpNow=Join-Path $CFG.LawsDir ('law_'+$rk+'.md')
  if(Test-Path $lpNow){
    $hNow=(Get-FileHash $lpNow -Algorithm SHA256).Hash
    if($shaOf[$rk] -and $hNow -ne $shaOf[$rk]){ W ('   !!! SHA LAW MISMATCH: '+$rk+' был '+$shaOf[$rk].Substring(0,16)+'..., стал '+$hNow.Substring(0,16)+'...') }
    else { W ('   SHA OK: '+$rk+' '+$hNow.Substring(0,16)+'...') }
  } else { W ('   !!! LAW MISSING: '+$rk) }
  # мягкая остановка ТОЛЬКО моделей стенда (не mass-kill всех окон)
  foreach($mm in $CFG.Models){ & ollama stop $mm *>$null }
  Get-Process llama-server -EA SilentlyContinue | Stop-Process -Force -EA SilentlyContinue
  Start-Sleep -Seconds 6
  & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $root 'check_3_skills_avail.ps1') -Models $mk -Rulesets $rk -Seed 42 -Temp 0.1 -OnlyTasks $Tasks
  Start-Sleep -Seconds 2
  $lg=Get-ChildItem $logDir -File -EA SilentlyContinue | Where-Object { $_.Name -like 'probe3_*.txt' -and $_.Name -notlike '*trace*' -and $_.LastWriteTime -ge $t0.AddSeconds(-3) } | Sort-Object LastWriteTime -Descending | Select-Object -First 1
  if($lg){
    # §6.1.6: НЕ только RESULT — обязательны ОТВЕТЫ МОДЕЛЕЙ (ГРАБЛЯ 12)
    (Select-String -Path $lg.FullName -Pattern 'RESULT\|' | ForEach-Object { W ('   '+$_.Line) })
    $raw=Get-Content $lg.FullName -Encoding UTF8
    $inAns=$false
    foreach($ln in $raw){
      if($ln -match '^--- ФИНАЛЬНЫЙ ОТВЕТ ---'){ $inAns=$true; W ('   >>> ФИНАЛЬНЫЙ ОТВЕТ'); continue }
      if($ln -match '^--- Ш[1-5] '){ $inAns=$true; W ('   >>> '+$ln.Trim()); continue }
      if($ln -match '^VERDICT:|^ЭТАЛОН:|^### ЗАДАЧА:'){ $inAns=$false }
      if($inAns -and $ln.Trim()){ W ('       '+$ln.Trim()) }
      if($ln -match '^\s*ЭТАЛОН:\s*(.+)$'){ W ('       ЭТАЛОН-> '+$matches[1]) }
    }
  } else { W '   ЛОГА НЕТ' }
  $sec=[math]::Round(((Get-Date)-$t0).TotalSeconds,1)
  $avg=((Get-Date)-$t00).TotalSeconds/$i
  $eta=(Get-Date).AddSeconds($avg*($total-$i)).ToString('HH:mm')
  W ('   sec='+$sec+'  ETA~'+$eta+'  осталось='+($total-$i))
}}
W ('ALL DONE '+(Get-Date -Format 'HH:mm:ss')+'  всего='+[math]::Round(((Get-Date)-$t00).TotalSeconds,1)+' с')
