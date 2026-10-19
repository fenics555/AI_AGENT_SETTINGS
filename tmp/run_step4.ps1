# run_step4.ps1 - ШАГ 4: ТОЛЬКО НЕПРОЙДЕННЫЕ МОДЕЛИ, по одной на фазу
# ДЕФЕКТЫ ПРОШЛОГО ДРАЙВЕРА, КОТОРЫЕ ЗДЕСЬ ИСПРАВЛЕНЫ:
#   1) тест берёт -Models как ОДИН шаблон -> список через запятую = 0 моделей => запускаем ПО ОДНОЙ;
#   2) "самый свежий лог" подхватывал ЧУЖОЙ лог прошлой серии => берём лог ТОЛЬКО новее старта фазы.
# Запуск (отвязанно, §17.1):
#   cmd /c start "" powershell -NoProfile -ExecutionPolicy Bypass -NoExit -File D:\AI\AGENT_SETTINGS\tmp\run_step4.ps1
param(
  [string]$Rulesets = 'p12,p15',
  [string]$ModelsM  = 'gemma4,gpt-oss',
  [string]$Tag      = 'step4'
)
$ErrorActionPreference = 'Continue'
$root   = 'D:\AI\AGENT_SETTINGS\checks\agentic'
$logDir = Join-Path $root 'log'
$tmp    = 'D:\AI\AGENT_SETTINGS\tmp'
cd $root
. 'D:\AI\AGENT_SETTINGS\config\paths.ps1'

$stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$sum   = Join-Path $tmp ('run_step4_' + $Tag + '_' + $stamp + '_summary.txt')
function W($t) { $t | Out-File $sum -Append -Encoding utf8; Write-Host $t }

$laws   = @($Rulesets -split ',' | ForEach-Object { $_.Trim() })
$models = @($ModelsM  -split ',' | ForEach-Object { $_.Trim() })
W ("START $(Get-Date -Format 'HH:mm:ss')  ШАГ4 (только непройденные) | законы=$($laws -join ',') | модели=$($models -join ',')")
foreach ($rk in $laws) {
  $lp = Join-Path $CFG.LawsDir ('law_' + $rk + '.md')
  if (Test-Path $lp) { $it=Get-Item $lp; W ("LAW $rk : $($it.Length) б SHA=$((Get-FileHash $lp -Algorithm SHA256).Hash.Substring(0,8))") }
}
$t00 = Get-Date
W ("ЭТАЛОН НА СТАРТЕ $(Get-Date -Format 'HH:mm:ss'): total=" + @(Get-ChildItem 'D:\AI\repo' -Recurse -File -Filter 'SKILL_*.md').Count + " creo=" + @(Get-ChildItem 'D:\AI\repo\Creo' -Recurse -File -Filter 'SKILL_*.md').Count + " prog=" + @(Get-ChildItem 'D:\AI\repo\Prog' -Recurse -File -Filter 'SKILL_*.md').Count)

$jobs = @()
foreach ($rk in $laws) { foreach ($mk in $models) {
  $jobs += @{ law=$rk; model=$mk; test='3'; script='check_3_skills_avail.ps1'; key='probe3_'; args=@('-Models',$mk,'-Rulesets',$rk,'-Seed','42') }
  $jobs += @{ law=$rk; model=$mk; test='4'; script='check_4_skills_read.ps1';  key='probe4_'; args=@('-Models',$mk,'-Rulesets',$rk,'-Seed','42') }
} }
W ("JOBS: $($jobs.Count)  (законов=$($laws.Count) x моделей=$($models.Count) x 2 теста)")

$i = 0
foreach ($j in $jobs) {
  $i++
  $t0 = Get-Date
  Write-Host (('[{0}/{1}] {2} | {3} | тест {4} | START {5}' -f $i,$jobs.Count,$j.law,$j.model,$j.test,$t0.ToString('HH:mm:ss'))) -ForegroundColor Yellow
  W ('[' + $i + '/' + $jobs.Count + '] law=' + $j.law + ' model=' + $j.model + ' test=' + $j.test + ' START ' + $t0.ToString('HH:mm:ss'))
  foreach ($mm in $CFG.Models) { & ollama stop $mm *>$null }
  Get-Process llama-server -EA SilentlyContinue | Stop-Process -Force -EA SilentlyContinue
  Start-Sleep -Seconds 6
  $targs = @('-NoProfile','-ExecutionPolicy','Bypass','-File',(Join-Path $root $j.script)) + $j.args
  Start-Process powershell -ArgumentList $targs -Wait -NoNewWindow
  Start-Sleep -Seconds 2
  # ФИКС: лог ТОЛЬКО созданный/изменённый ПОСЛЕ старта этой фазы (иначе подхватит чужой)
  $lg = Get-ChildItem $logDir -Filter ($j.key + '*.txt') | Where-Object { $_.Name -notmatch 'trace' -and $_.LastWriteTime -ge $t0.AddSeconds(-3) } | Sort-Object LastWriteTime -Descending | Select-Object -First 1
  if ($lg) {
    W ('   log=' + $lg.Name)
    (Select-String -Path $lg.FullName -Pattern 'RESULT\|' | ForEach-Object { '   ' + $_.Line }) | ForEach-Object { W $_ }
    $c = Get-Content $lg.FullName -Encoding utf8 -Raw
    foreach ($hdr in 'ФИНАЛЬНЫЙ ОТВЕТ','Ш1 ЧТО ДЕЛАЛА','Ш2 ЧТО ЧИТАЛА','Ш3 ПОЧЕМУ','Ш4 ЧТО УЛУЧШИТЬ','ОПРОС МОДЕЛИ') {
      $p = $c.IndexOf($hdr); if ($p -ge 0) { $blk=$c.Substring($p); if ($blk.Length -gt 2200) { $blk=$blk.Substring(0,2200)+' ... [усечено]' }; W ('   --- '+$hdr+' ---'); W ($blk.TrimEnd()) }
    }
  } else { W '   ЛОГА НЕТ (тест не стартовал или упал)' }
  $sec = [math]::Round(((Get-Date) - $t0).TotalSeconds, 1)
  $avg = ((Get-Date) - $t00).TotalSeconds / $i
  $eta = (Get-Date).AddSeconds($avg * ($jobs.Count - $i)).ToString('HH:mm')
  W ('   sec=' + $sec + '  ETA~' + $eta + '  осталось=' + ($jobs.Count - $i))
  Write-Host (('   sec={0} ETA~{1}' -f $sec,$eta)) -ForegroundColor Cyan
}
W ('ALL DONE ' + (Get-Date -Format 'HH:mm:ss') + '  всего=' + [math]::Round(((Get-Date)-$t00).TotalSeconds,1) + ' с')
Write-Host ('ALL DONE ' + (Get-Date -Format 'HH:mm:ss')) -ForegroundColor Green
