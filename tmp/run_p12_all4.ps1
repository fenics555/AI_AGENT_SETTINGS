# run_p12_all4.ps1 - ШАГ 4: ВСЕ 4 МОДЕЛИ x выбранные законы x тесты 3+4
# §6.1.4: модели берём через -Models all (тест сам резолвит из $CFG.Models)
# §6.1.6: ответы моделей выводим в окно И в сводку
# Запуск (отвязанно, §17.1):
#   cmd /c start "" powershell -NoProfile -ExecutionPolicy Bypass -NoExit -File D:\AI\AGENT_SETTINGS\tmp\run_p12_all4.ps1
param(
  [string]$Rulesets = 'p12,p15',
  [string]$ModelsM  = 'all',
  [string]$Tag      = 'all4'
)
$ErrorActionPreference = 'Continue'
$root   = 'D:\AI\AGENT_SETTINGS\checks\agentic'
$logDir = Join-Path $root 'log'
$tmp    = 'D:\AI\AGENT_SETTINGS\tmp'
cd $root
. 'D:\AI\AGENT_SETTINGS\config\paths.ps1'

$stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$sum   = Join-Path $tmp ('run_p12all4_' + $Tag + '_' + $stamp + '_summary.txt')
function W($t) { $t | Out-File $sum -Append -Encoding utf8; Write-Host $t }

W ("START $(Get-Date -Format 'HH:mm:ss')  ШАГ4: ВСЕ МОДЕЛИ | tag=$Tag | законы=$Rulesets | модели=$ModelsM")
$useModels = if ($ModelsM -eq 'all') { $CFG.Models } else { ($ModelsM -split ',') }
W ('MODELS_IN_RUN: ' + ($useModels -join ', '))
foreach ($rk in ($Rulesets -split ',')) {
  $lp = Join-Path $CFG.LawsDir ('law_' + $rk + '.md')
  if (Test-Path $lp) {
    $it = Get-Item $lp
    W ("LAW $rk : $($it.Length) б SHA=$((Get-FileHash $lp -Algorithm SHA256).Hash.Substring(0,8))")
  } else { W ("LAW $rk : НЕТ ФАЙЛА $lp") }
}
$t00 = Get-Date
W ("ЭТАЛОН НА СТАРТЕ $(Get-Date -Format 'HH:mm:ss'): total=" + @(Get-ChildItem 'D:\AI\repo' -Recurse -File -Filter 'SKILL_*.md').Count + " creo=" + @(Get-ChildItem 'D:\AI\repo\Creo' -Recurse -File -Filter 'SKILL_*.md').Count + " prog=" + @(Get-ChildItem 'D:\AI\repo\Prog' -Recurse -File -Filter 'SKILL_*.md').Count)

$jobs = @()
foreach ($rk in ($Rulesets -split ',')) {
  $jobs += @{ law=$rk; test='3'; script='check_3_skills_avail.ps1'; key='probe3_'; args=@('-Models',$ModelsM,'-Rulesets',$rk,'-Seed','42') }
  $jobs += @{ law=$rk; test='4'; script='check_4_skills_read.ps1';  key='probe4_'; args=@('-Models',$ModelsM,'-Rulesets',$rk,'-Seed','42') }
}
W ("JOBS: $($jobs.Count)  (законов=$(@($Rulesets -split ',').Count) x моделей=$($useModels.Count) x 2 теста)")

$i = 0
foreach ($j in $jobs) {
  $i++
  $t0 = Get-Date
  Write-Host (('[{0}/{1}] {2} | тест {3} | START {4}' -f $i,$jobs.Count,$j.law,$j.test,$t0.ToString('HH:mm:ss'))) -ForegroundColor Yellow
  W ('[' + $i + '/' + $jobs.Count + '] law=' + $j.law + ' test=' + $j.test + ' START ' + $t0.ToString('HH:mm:ss'))
  # гарантированная выгрузка всех моделей (§6.2 п.4)
  foreach ($mm in $CFG.Models) { & ollama stop $mm *>$null }
  Get-Process llama-server -EA SilentlyContinue | Stop-Process -Force -EA SilentlyContinue
  Start-Sleep -Seconds 6
  $targs = @('-NoProfile','-ExecutionPolicy','Bypass','-File',(Join-Path $root $j.script)) + $j.args
  Start-Process powershell -ArgumentList $targs -Wait -NoNewWindow
  Start-Sleep -Seconds 2
  $lg = Get-ChildItem $logDir -Filter ($j.key + '*.txt') | Where-Object { $_.Name -notmatch 'trace' } | Sort-Object LastWriteTime -Descending | Select-Object -First 1
  if ($lg) {
    W ('   log=' + $lg.Name)
    (Select-String -Path $lg.FullName -Pattern 'RESULT\|' | ForEach-Object { '   ' + $_.Line }) | ForEach-Object { W $_ }
    $c = Get-Content $lg.FullName -Encoding utf8 -Raw
    # §6.1.6: ОТВЕТЫ МОДЕЛЕЙ — ЦЕЛИКОМ В ОКНО
    foreach ($hdr in 'ФИНАЛЬНЫЙ ОТВЕТ','Ш1 ЧТО ДЕЛАЛА','Ш2 ЧТО ЧИТАЛА','Ш3 ПОЧЕМУ','Ш4 ЧТО УЛУЧШИТЬ','ОПРОС МОДЕЛИ') {
      $p = $c.IndexOf($hdr)
      if ($p -ge 0) {
        $blk = $c.Substring($p)
        if ($blk.Length -gt 2500) { $blk = $blk.Substring(0,2500) + ' ... [усечено 2500 симв.]' }
        W ('   --- ' + $hdr + ' ---'); W ($blk.TrimEnd())
      }
    }
    $q = $c.IndexOf('ОПРОС МОДЕЛИ')
    if ($q -ge 0) { W ('   SURVEY=' + ($c.Length - $q) + ' симв.') }
    $mr = (Select-String -Path $lg.FullName -Pattern 'RESULT\|' | ForEach-Object { ($_.Line -split '\|')[3] } | Sort-Object -Unique)
    W ('   MODELS_WITH_RESULT: ' + $mr.Count + ' -> ' + ($mr -join ' | '))
  } else { W '   ЛОГА НЕТ' }
  $sec = [math]::Round(((Get-Date) - $t0).TotalSeconds, 1)
  $avg = ((Get-Date) - $t00).TotalSeconds / $i
  $eta = (Get-Date).AddSeconds($avg * ($jobs.Count - $i)).ToString('HH:mm')
  W ('   sec=' + $sec + '  ETA~' + $eta + '  осталось=' + ($jobs.Count - $i))
  Write-Host (('   sec={0} ETA~{1}' -f $sec,$eta)) -ForegroundColor Cyan
}
$tot = [math]::Round(((Get-Date) - $t00).TotalSeconds, 1)
W ('ALL DONE ' + (Get-Date -Format 'HH:mm:ss') + '  всего=' + $tot + ' с')
Write-Host ('ALL DONE ' + (Get-Date -Format 'HH:mm:ss')) -ForegroundColor Green
