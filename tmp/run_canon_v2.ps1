# run_canon_p16p20.ps1 - ПОЛНЫЙ ПРОГОН КАНОНА: тесты 1,2,3,4 x 5 законов x 2 модели
# §6.1.6: ответы моделей -> в окно и сводку. §6.1.2: живое окно. §17.1: отвязанный запуск.
# Фикс: лог ТОЛЬКО новее старта фазы; по одной модели на фазу.
param(
  [string]$Rulesets = 'p12,p18,p19,p20,p16',
  [string]$ModelsM  = 'laguna,gemma4',
  [string]$Tests    = '3,4',
  [string]$Tag      = 'canon'
)
$ErrorActionPreference = 'Continue'
$root   = 'D:\AI\AGENT_SETTINGS\checks\agentic'
$logDir = Join-Path $root 'log'
$tmp    = 'D:\AI\AGENT_SETTINGS\tmp'
cd $root
. 'D:\AI\AGENT_SETTINGS\config\paths.ps1'

$stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$sum   = Join-Path $tmp ('run_canon_' + $Tag + '_' + $stamp + '_summary.txt')
function W($t) { $t | Out-File $sum -Append -Encoding utf8; Write-Host $t }

$laws   = @([string]$Rulesets).Split([char[]]" ,;`t", [StringSplitOptions]::RemoveEmptyEntries)
$models = @([string]$ModelsM).Split([char[]]" ,;`t", [StringSplitOptions]::RemoveEmptyEntries)
# ФИКС (§5.1): тесты НЕ через параметр — всегда оба (полный канон 3+4). Убран лишний источник ошибок.
$tests  = @('3','4')
$smap = @{ '1'=@{s='check_1_law.ps1'; k='probe1_'}; '2'=@{s='check_2_read.ps1'; k='probe2_'};
           '3'=@{s='check_3_skills_avail.ps1'; k='probe3_'}; '4'=@{s='check_4_skills_read.ps1'; k='probe4_'} }

W ("START $(Get-Date -Format 'HH:mm:ss')  КАНОН: тесты=$($tests -join ',') | законы=$($laws -join ',') | модели=$($models -join ',')")
foreach ($rk in $laws) {
  $lp = Join-Path $CFG.LawsDir ('law_' + $rk + '.md')
  if (Test-Path $lp) { $it=Get-Item $lp; W ("LAW $rk : $($it.Length) б SHA=$((Get-FileHash $lp -Algorithm SHA256).Hash.Substring(0,8))") }
}
$t00 = Get-Date
W ("ЭТАЛОН НА СТАРТЕ $(Get-Date -Format 'HH:mm:ss'): total=" + @(Get-ChildItem 'D:\AI\repo' -Recurse -File -Filter 'SKILL_*.md').Count + " creo=" + @(Get-ChildItem 'D:\AI\repo\Creo' -Recurse -File -Filter 'SKILL_*.md').Count + " prog=" + @(Get-ChildItem 'D:\AI\repo\Prog' -Recurse -File -Filter 'SKILL_*.md').Count)

$jobs = @()
foreach ($rk in $laws) { foreach ($mk in $models) { foreach ($tk in $tests) {
  $sw = $smap[$tk]
  $jobs += @{ law=$rk; model=$mk; test=$tk; script=$sw.s; key=$sw.k; args=@('-Models',$mk,'-Rulesets',$rk,'-Seed','42') }
} } }
W ("JOBS: $($jobs.Count)  (законов=$($laws.Count) x моделей=$($models.Count) x тестов=$($tests.Count))")

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
  & powershell @targs
  Start-Sleep -Seconds 2
  $lg = Get-ChildItem $logDir -Filter ($j.key + '*.txt') | Where-Object { $_.Name -notmatch 'trace' -and $_.LastWriteTime -ge $t0.AddSeconds(-3) } | Sort-Object LastWriteTime -Descending | Select-Object -First 1
  if ($lg) {
    W ('   log=' + $lg.Name)
    (Select-String -Path $lg.FullName -Pattern 'RESULT\|' | ForEach-Object { '   ' + $_.Line }) | ForEach-Object { W $_ }
    $c = Get-Content $lg.FullName -Encoding utf8 -Raw
    foreach ($hdr in 'ФИНАЛЬНЫЙ ОТВЕТ','Ш3 ПОЧЕМУ','Ш4 ЧТО УЛУЧШИТЬ','ОПРОС МОДЕЛИ') {
      $p = $c.IndexOf($hdr); if ($p -ge 0) { $blk=$c.Substring($p); if ($blk.Length -gt 1800) { $blk=$blk.Substring(0,1800)+' ... [усечено]' }; W ('   --- '+$hdr+' ---'); W ($blk.TrimEnd()) }
    }
  } else { W '   ЛОГА НЕТ (тест не стартовал/упал)' }
  $sec = [math]::Round(((Get-Date) - $t0).TotalSeconds, 1)
  $avg = ((Get-Date) - $t00).TotalSeconds / $i
  $eta = (Get-Date).AddSeconds($avg * ($jobs.Count - $i)).ToString('HH:mm')
  W ('   sec=' + $sec + '  ETA~' + $eta + '  осталось=' + ($jobs.Count - $i))
  Write-Host (('   sec={0} ETA~{1}' -f $sec,$eta)) -ForegroundColor Cyan
}
W ('ALL DONE ' + (Get-Date -Format 'HH:mm:ss') + '  всего=' + [math]::Round(((Get-Date)-$t00).TotalSeconds,1) + ' с')
Write-Host ('ALL DONE ' + (Get-Date -Format 'HH:mm:ss')) -ForegroundColor Green

