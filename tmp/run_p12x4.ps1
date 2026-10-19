# run_p12x4.ps1 - СЕРИЯ ВАРИАНТОВ ОТ P12: тесты 3+4 x модели x законы
# Запуск (отвязанно, §17.1):  Start-Process cmd -ArgumentList @('/c','powershell -NoProfile -ExecutionPolicy Bypass -NoExit -File D:\AI\AGENT_SETTINGS\tmp\run_p12x4.ps1') -WindowStyle Normal
# Параметры: -Rulesets p12,p13,p14,p15   -ModelsM laguna,qwen3.6   -Tag quick
param(
  [string]$Rulesets = 'p12,p13,p14,p15',
  [string]$ModelsM  = 'laguna,qwen3.6',
  [string]$Tag      = 'quick'
)
$ErrorActionPreference = 'Continue'
$root   = 'D:\AI\AGENT_SETTINGS\checks\agentic'
$logDir = Join-Path $root 'log'
$tmp    = 'D:\AI\AGENT_SETTINGS\tmp'
cd $root
. 'D:\AI\AGENT_SETTINGS\config\paths.ps1'

$stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$sum   = Join-Path $tmp ('run_p12x4_' + $Tag + '_' + $stamp + '_summary.txt')
function W($t) { $t | Out-File $sum -Append -Encoding utf8; Write-Host $t }

# ключ закона -> короткое имя для папки скиллов модели
$mAlias = @{ 'laguna'='laguna'; 'qwen3.6'='qwen3.6'; 'gemma4'='gemma4'; 'gpt-oss'='gpt-oss'; 'xing'='xing' }

W ("START $(Get-Date -Format 'HH:mm:ss')  СЕРИЯ ОТ P12 | tag=$Tag | законы=$Rulesets | модели=$ModelsM")
W ("MODELS_IN_RUN: $ModelsM")
foreach ($rk in ($Rulesets -split ',')) {
  $lp = Join-Path $CFG.LawsDir ('law_' + $rk + '.md')
  if (Test-Path $lp) {
    $it = Get-Item $lp
    W ("LAW $rk : $($it.Length) б SHA=$((Get-FileHash $lp -Algorithm SHA256).Hash.Substring(0,8))")
  } else { W ("LAW $rk : НЕТ ФАЙЛА $lp") }
}
$t00 = Get-Date
# ЭТАЛОН (динамический, §3.3)
W ("ЭТАЛОН НА СТАРТЕ $(Get-Date -Format 'HH:mm:ss'): total=" + @(Get-ChildItem 'D:\AI\repo' -Recurse -File -Filter 'SKILL_*.md').Count + " creo=" + @(Get-ChildItem 'D:\AI\repo\Creo' -Recurse -File -Filter 'SKILL_*.md').Count + " prog=" + @(Get-ChildItem 'D:\AI\repo\Prog' -Recurse -File -Filter 'SKILL_*.md').Count)

$jobs = @()
foreach ($rk in ($Rulesets -split ',')) {
  foreach ($mk in ($ModelsM -split ',')) {
    $jobs += @{ law=$rk; model=$mk; test='3'; script='check_3_skills_avail.ps1'; key='probe3_'; args=@('-Models',$mk,'-Rulesets',$rk,'-Seed','42') }
    $jobs += @{ law=$rk; model=$mk; test='4'; script='check_4_skills_read.ps1';  key='probe4_'; args=@('-Models',$mk,'-Rulesets',$rk,'-Seed','42') }
  }
}
W ("JOBS: $($jobs.Count)  (законов=$(@($Rulesets -split ',').Count) x моделей=$(@($ModelsM -split ',').Count) x тестов=2)")

$i = 0
foreach ($j in $jobs) {
  $i++
  $t0 = Get-Date
  Write-Host (('[{0}/{1}] {2} | {3} | тест {4} | START {5}' -f $i,$jobs.Count,$j.law,$j.model,$j.test,$t0.ToString('HH:mm:ss'))) -ForegroundColor Yellow
  W ('[' + $i + '/' + $jobs.Count + '] law=' + $j.law + ' model=' + $j.model + ' test=' + $j.test + ' START ' + $t0.ToString('HH:mm:ss'))
  & ollama stop laguna-xs-2.1:latest *>$null
  & ollama stop batiai/qwen3.6-35b:iq4 *>$null
  & ollama stop gemma4:26b *>$null
  & ollama stop gpt-oss:20b *>$null
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
    # §6.1.6: ОТВЕТЫ МОДЕЛЕЙ — ПОЛНОСТЬЮ В ОКНО (и в сводку). Три блока: финал, Ш1-Ш4, опрос.
    foreach ($hdr in 'ФИНАЛЬНЫЙ ОТВЕТ','Ш1 ЧТО ДЕЛАЛА','Ш2 ЧТО ЧИТАЛА','Ш3 ПОЧЕМУ','Ш4 ЧТО УЛУЧШИТЬ','ОПРОС МОДЕЛИ') {
      $p = $c.IndexOf($hdr)
      if ($p -ge 0) {
        $blk = $c.Substring($p)
        if ($blk.Length -gt 2500) { $blk = $blk.Substring(0,2500) + ' ... [усечено 2500 симв.]' }
        W ('   --- ' + $hdr + ' ---')
        W ($blk.TrimEnd())
      }
    }
    $q = $c.IndexOf('ОПРОС МОДЕЛИ')
    if ($q -ge 0) { W ('   SURVEY=' + ($c.Length - $q) + ' симв.') }
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
