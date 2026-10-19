# run_full_canon.ps1 - FULL CANON: tests 1-6 x all models, live law (law_2)
$ErrorActionPreference = 'Continue'
$root = 'D:\AI\AGENT_SETTINGS\checks\agentic'
$logDir = Join-Path $root 'log'
$tmp = 'D:\AI\AGENT_SETTINGS\tmp'
cd $root
. 'D:\AI\AGENT_SETTINGS\config\paths.ps1'
$stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$sum = Join-Path $tmp ('run_canon_' + $stamp + '_summary.txt')
"START $(Get-Date -Format 'HH:mm:ss')  run=FULL-CANON tests=1..6 all-models  stamp=$stamp" | Out-File $sum -Encoding utf8
$t00 = Get-Date
('MODELS: ' + ($CFG.Models -join ', ')) | Out-File $sum -Append -Encoding utf8
('LAW: ' + (Get-Item 'D:\AI\.clinerules').Length + ' bytes SHA=' + (Get-FileHash 'D:\AI\.clinerules' -Algorithm SHA256).Hash.Substring(0,8)) | Out-File $sum -Append -Encoding utf8
('ETALON ' + (Get-Date -Format 'HH:mm:ss') + ': total=' + @(Get-ChildItem 'D:\AI\repo' -Recurse -File -Filter 'SKILL_*.md').Count + ' creo=' + @(Get-ChildItem 'D:\AI\repo\Creo' -Recurse -File -Filter 'SKILL_*.md').Count + ' prog=' + @(Get-ChildItem 'D:\AI\repo\Prog' -Recurse -File -Filter 'SKILL_*.md').Count) | Out-File $sum -Append -Encoding utf8

# карта тестов: script | как брать закон | префикс лога
$tests = @(
  @{ n='1'; script='check_1_law.ps1';          lawParam='-Law';      lawVal='live'; key='check1law_' },
  @{ n='2'; script='check_2_read.ps1';         lawParam='-Law';      lawVal='live'; key='check2read_' },
  @{ n='3'; script='check_3_skills_avail.ps1'; lawParam='-Rulesets'; lawVal='A';    key='probe3_' },
  @{ n='4'; script='check_4_skills_read.ps1';  lawParam='-Rulesets'; lawVal='A';    key='probe4_' },
  @{ n='5'; script='check_5_creo.ps1';         lawParam='-Law';      lawVal='live'; key='check5creo_' },
  @{ n='6'; script='check_4_write.ps1';        lawParam='-Law';      lawVal='live'; key='check4write_' }
)

$jobs = @()
foreach ($t in $tests) {
  foreach ($m in $CFG.Models) {
    $jobs += @{ n=$t.n; script=$t.script; key=$t.key; model=$m;
                args=@('-Models',$m,$t.lawParam,$t.lawVal,'-Seed','42') }
  }
}
('JOBS: ' + $jobs.Count) | Out-File $sum -Append -Encoding utf8

$i = 0
foreach ($j in $jobs) {
  $i++
  $t0 = Get-Date
  Write-Host (('{0}/{1} TEST {2} | {3} | START {4}' -f $i,$jobs.Count,$j.n,$j.model,$t0.ToString('HH:mm:ss'))) -ForegroundColor Yellow
  ('[{0}/{1}] test={2} model={3} START {4}' -f $i,$jobs.Count,$j.n,$j.model,$t0.ToString('HH:mm:ss')) | Out-File $sum -Append -Encoding utf8
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
    (Select-String -Path $lg.FullName -Pattern 'RESULT\|' | ForEach-Object { $_.Line }) | Out-File $sum -Append -Encoding utf8
  }
}

Write-Host ('ALL DONE ' + (Get-Date -Format 'HH:mm:ss') + ' | ' + $sum) -ForegroundColor Green
('ALL DONE ' + (Get-Date -Format 'HH:mm:ss')) | Out-File $sum -Append -Encoding utf8
