# run_stage1d_rest.ps1 - tests 1,2,3 x remaining models (from CFG)
$ErrorActionPreference = 'Continue'
$root = 'D:\AI\AGENT_SETTINGS\checks\agentic'
$logDir = Join-Path $root 'log'
$tmp = 'D:\AI\AGENT_SETTINGS\tmp'
cd $root
. 'D:\AI\AGENT_SETTINGS\config\paths.ps1'
$stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$sum = Join-Path $tmp ('run_stage1d_' + $stamp + '_summary.txt')
"START $(Get-Date -Format 'HH:mm:ss')  run=stage1d tests=1,2,3 remaining-models  stamp=$stamp" | Out-File $sum -Encoding utf8
$t00 = Get-Date
('MODELS_IN_CFG: ' + ($CFG.Models -join ', ')) | Tee-Object -FilePath $sum -Append
('LAW: ' + (Get-Item 'D:\AI\.clinerules').Length + ' bytes SHA=' + (Get-FileHash 'D:\AI\.clinerules' -Algorithm SHA256).Hash.Substring(0,8)) | Tee-Object -FilePath $sum -Append
('ETALON ' + (Get-Date -Format 'HH:mm:ss') + ': total=' + @(Get-ChildItem 'D:\AI\repo' -Recurse -File -Filter 'SKILL_*.md').Count + ' creo=' + @(Get-ChildItem 'D:\AI\repo\Creo' -Recurse -File -Filter 'SKILL_*.md').Count + ' prog=' + @(Get-ChildItem 'D:\AI\repo\Prog' -Recurse -File -Filter 'SKILL_*.md').Count) | Tee-Object -FilePath $sum -Append

# МОДЕЛИ ДЛЯ ДОГОНА — из $CFG (исключаем уже прогнанные laguna/gemma4)
$already = @('laguna','gemma4')
$todo = @($CFG.Models | Where-Object { $m=$_; -not ($already | Where-Object { $m -like ('*' + $_ + '*') }) })
('MODELS_IN_RUN: ' + ($todo -join ' | ')) | Tee-Object -FilePath $sum -Append

$jobs = @()
foreach ($m in $todo) {
  $jobs += @{ model=$m; test='1'; script='check_1_law.ps1';          key='check1law_'; args=@('-Models',$m,'-Law','live','-Seed','42') }
  $jobs += @{ model=$m; test='2'; script='check_2_read.ps1';         key='check2read_'; args=@('-Models',$m,'-Law','live','-Seed','42') }
  $jobs += @{ model=$m; test='3'; script='check_3_skills_avail.ps1'; key='probe3_';    args=@('-Models',$m,'-Rulesets','A','-Seed','42') }
}
('JOBS: ' + $jobs.Count) | Tee-Object -FilePath $sum -Append

$i = 0
foreach ($j in $jobs) {
  $i++
  $t0 = Get-Date
  Write-Host (('{0}/{1} TEST {2} | {3} | START {4}' -f $i,$jobs.Count,$j.test,$j.model,$t0.ToString('HH:mm:ss'))) -ForegroundColor Yellow
  ('[{0}/{1}] test={2} model={3} START {4}' -f $i,$jobs.Count,$j.test,$j.model,$t0.ToString('HH:mm:ss')) | Out-File $sum -Append -Encoding utf8
  Get-Process llama-server -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
  Start-Sleep -Seconds 3
  $targs = @('-NoProfile','-ExecutionPolicy','Bypass','-File',(Join-Path $root $j.script)) + $j.args
  Start-Process powershell -ArgumentList $targs -Wait -NoNewWindow
  Start-Sleep -Seconds 2
  $lg = Get-ChildItem $logDir -Filter ($j.key + '*.txt') | Where-Object { $_.Name -notmatch 'trace' } | Sort-Object LastWriteTime -Descending | Select-Object -First 1
  $sec = [math]::Round(((Get-Date) - $t0).TotalSeconds, 1)
  $avg = ((Get-Date) - $t00).TotalSeconds / $i
  $eta = (Get-Date).AddSeconds($avg * ($jobs.Count - $i)).ToString('HH:mm')
  Write-Host (('    log={0} sec={1} ETA~{2}' -f $(if($lg){$lg.Name}else{'NONE'}),$sec,$eta)) -ForegroundColor Cyan
  ('  log=' + $(if($lg){$lg.Name}else{'NONE'}) + '  sec=' + $sec + '  ETA~' + $eta) | Out-File $sum -Append -Encoding utf8
  if ($lg) {
    (Select-String -Path $lg.FullName -Pattern 'RESULT\|' | ForEach-Object { $_.Line }) | Tee-Object -FilePath $sum -Append
  }
}

Write-Host ('ALL DONE ' + (Get-Date -Format 'HH:mm:ss') + ' | ' + $sum) -ForegroundColor Green
('ALL DONE ' + (Get-Date -Format 'HH:mm:ss')) | Out-File $sum -Append -Encoding utf8
