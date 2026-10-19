# run_NIGHT_FULL6.ps1 — ПОЛНЫЙ СТЕНД НА НОЧЬ: 6 тестов x 10 законов x 4 модели
# Канон (§5 правил стенда): check_1_law, check_2_read, check_3_skills_avail, check_4_skills_read,
#                            check_5_creo, check_4_write
# §М.2е: temp=0.1, seed=42 — ЯВНО. §6.1.4: модели из $CFG.
param(
  [string]$ModelsM = 'gemma4,qwen3.6,laguna,gpt-oss',
  [string]$Tag     = 'full6'
)
$ErrorActionPreference='Continue'
$root='D:\AI\AGENT_SETTINGS\checks\agentic'
$logDir=Join-Path $root 'log'
$tmp='D:\AI\AGENT_SETTINGS\tmp'
cd $root
. 'D:\AI\AGENT_SETTINGS\config\paths.ps1'
$stamp=Get-Date -Format 'yyyyMMdd_HHmmss'
$sum=Join-Path $tmp ('run_FULL6_'+$Tag+'_'+$stamp+'_summary.txt')
function W($t){ $t | Out-File $sum -Append -Encoding utf8; Write-Host $t }

# ЗАКОНЫ (10): живой + варианты
$laws = @('lite','p32','p33','p34','p24','p31','p16','p21','p23','p12')
$models=@($ModelsM.Split(','))
# ТЕСТЫ (6 канона) с их параметром ключа
$tests = @(
  @{n='1'; sc='check_1_law.ps1';          key='-Law';      lg='probe1_'},
  @{n='2'; sc='check_2_read.ps1';         key='-Law';      lg='probe2_'},
  @{n='3'; sc='check_3_skills_avail.ps1'; key='-Rulesets'; lg='probe3_'},
  @{n='4'; sc='check_4_skills_read.ps1';  key='-Rulesets'; lg='probe4_'},
  @{n='5'; sc='check_5_creo.ps1';         key='-Law';      lg='check5creo_'}
)
W ("START $(Get-Date -Format 'HH:mm:ss')  ПОЛНЫЙ СТЕНД | законы=$($laws.Count) | модели=$($models.Count) | тесты=$($tests.Count) | temp=0.1 seed=42")
W ("LAWS: " + ($laws -join ', '))
W ("MODELS: " + ($models -join ', '))
W ("ЭТАЛОН: total=" + @(Get-ChildItem 'D:\AI\repo' -Recurse -File -Filter 'SKILL_*.md').Count + " creo=" + @(Get-ChildItem 'D:\AI\repo\Creo' -Recurse -File -Filter 'SKILL_*.md').Count + " prog=" + @(Get-ChildItem 'D:\AI\repo\Prog' -Recurse -File -Filter 'SKILL_*.md').Count)

$jobs=@()
foreach($rk in $laws){ foreach($mk in $models){ foreach($t in $tests){
  $jobs += @{ law=$rk; model=$mk; test=$t.n; sc=$t.sc; key=$t.key; lg=$t.lg }
}}}
W ("JOBS: $($jobs.Count)")
$t00=Get-Date; $i=0
foreach($j in $jobs){
  $i++; $t0=Get-Date
  $line='['+$i+'/'+$jobs.Count+'] law='+$j.law+' model='+$j.model+' TEST='+$j.test+' START '+$t0.ToString('HH:mm:ss')
  W $line; Write-Host $line -ForegroundColor Yellow
  foreach($mm in $CFG.Models){ & ollama stop $mm *>$null }
  Get-Process llama-server -EA SilentlyContinue | Stop-Process -Force -EA SilentlyContinue
  Start-Sleep -Seconds 5
  $full=Join-Path $root $j.sc
  # ключи тестов РАЗНЫЕ (§6.12.7 каталога): 3/4 — -Rulesets (+Temp); 1/2/5 — -Law (Temp НЕ принимают!)
  if($j.key -eq '-Rulesets'){ & powershell -NoProfile -ExecutionPolicy Bypass -File $full -Models $j.model -Rulesets $j.law -Seed 42 -Temp 0.1 }
  else { & powershell -NoProfile -ExecutionPolicy Bypass -File $full -Models $j.model -Law $j.law -Seed 42 }
  Start-Sleep -Seconds 2
  $lg=Get-ChildItem $logDir -File -EA SilentlyContinue | Where-Object { $_.Name -like ($j.lg+'*.txt') -and $_.Name -notlike '*trace*' -and $_.LastWriteTime -ge $t0.AddSeconds(-3) } | Sort-Object LastWriteTime -Descending | Select-Object -First 1
  if($lg){ W ('   log='+$lg.Name); (Select-String -Path $lg.FullName -Pattern 'RESULT\|' | ForEach-Object { '   '+$_.Line }) | ForEach-Object { W $_ } } else { W '   ЛОГА НЕТ' }
  $sec=[math]::Round(((Get-Date)-$t0).TotalSeconds,1)
  $avg=((Get-Date)-$t00).TotalSeconds/$i
  $eta=(Get-Date).AddSeconds($avg*($jobs.Count-$i)).ToString('HH:mm')
  W ('   sec='+$sec+'  ETA~'+$eta+'  осталось='+($jobs.Count-$i))
  Write-Host ('   sec='+$sec+' ETA~'+$eta) -ForegroundColor Cyan
}
W ('ALL DONE '+(Get-Date -Format 'HH:mm:ss')+'  всего='+[math]::Round(((Get-Date)-$t00).TotalSeconds,1)+' с')
Write-Host ('ALL DONE '+(Get-Date -Format 'HH:mm:ss')) -ForegroundColor Green
