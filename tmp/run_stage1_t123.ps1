# run_stage1_t123.ps1 - STAGE 1: tests 1,2,3 x laguna+gemma4 on NEW live law
$ErrorActionPreference = 'Continue'
$root = 'D:\AI\AGENT_SETTINGS\checks\agentic'
$logDir = Join-Path $root 'log'
$tmp = 'D:\AI\AGENT_SETTINGS\tmp'
cd $root
$stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$sum = Join-Path $tmp ('run_stage1_' + $stamp + '_summary.txt')
"START $(Get-Date -Format 'HH:mm:ss')  run=stage1 tests=1,2,3 law=LIVE(new D)  stamp=$stamp" | Out-File $sum -Encoding utf8
$t00 = Get-Date

if (-not (Test-Path 'D:\AI\.clinerules')) { 'STOP: нет живого закона' | Out-File $sum -Append; exit 1 }
('LAW: ' + (Get-Item 'D:\AI\.clinerules').Length + ' bytes, SHA=' + (Get-FileHash 'D:\AI\.clinerules' -Algorithm SHA256).Hash.Substring(0,8)) | Out-File $sum -Append -Encoding utf8
('ETALON_ON_START ' + (Get-Date -Format 'HH:mm:ss') + ': total=' + @(Get-ChildItem 'D:\AI\repo' -Recurse -File -Filter 'SKILL_*.md').Count + ' creo=' + @(Get-ChildItem 'D:\AI\repo\Creo' -Recurse -File -Filter 'SKILL_*.md').Count + ' prog=' + @(Get-ChildItem 'D:\AI\repo\Prog' -Recurse -File -Filter 'SKILL_*.md').Count) | Out-File $sum -Append -Encoding utf8

$jobs = @(
  @{ law='live'; model='laguna'; test='1'; script='check_1_law.ps1';         key='check1law_'; args=@('-Models','laguna','-Law','live','-Seed','42') },
  @{ law='live'; model='gemma4'; test='1'; script='check_1_law.ps1';         key='check1law_'; args=@('-Models','gemma4','-Law','live','-Seed','42') },
  @{ law='live'; model='laguna'; test='2'; script='check_2_read.ps1';        key='check2read_'; args=@('-Models','laguna','-Law','live','-Seed','42') },
  @{ law='live'; model='gemma4'; test='2'; script='check_2_read.ps1';        key='check2read_'; args=@('-Models','gemma4','-Law','live','-Seed','42') },
  @{ law='live'; model='laguna'; test='3'; script='check_3_skills_avail.ps1';key='probe3_';    args=@('-Models','laguna','-Rulesets','A','-Seed','42') },
  @{ law='live'; model='gemma4'; test='3'; script='check_3_skills_avail.ps1';key='probe3_';    args=@('-Models','gemma4','-Rulesets','A','-Seed','42') }
)

$i = 0
foreach ($j in $jobs) {
  $i++
  $t0 = Get-Date
  ('[{0}/{1}] test={2} model={3} START {4}' -f $i,$jobs.Count,$j.test,$j.model,$t0.ToString('HH:mm:ss')) | Out-File $sum -Append -Encoding utf8
  Get-Process llama-server -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
  Start-Sleep -Seconds 3
  $null = & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $root $j.script) @($j.args) 2>&1
  Start-Sleep -Seconds 2
  $lg = Get-ChildItem $logDir -Filter ($j.key + '*.txt') | Where-Object { $_.Name -notmatch 'trace' } | Sort-Object LastWriteTime -Descending | Select-Object -First 1
  $sec = [math]::Round(((Get-Date) - $t0).TotalSeconds, 1)
  $done = $i
  $avg = ((Get-Date) - $t00).TotalSeconds / $done
  $left = [math]::Round(($avg * ($jobs.Count - $done)) / 60, 1)
  $eta = (Get-Date).AddSeconds($avg * ($jobs.Count - $done)).ToString('HH:mm')
  ('  log=' + $(if($lg){$lg.Name}else{'NONE'}) + '  sec=' + $sec + '  ETA~' + $eta + '  left~' + $left + 'min') | Out-File $sum -Append -Encoding utf8
  if ($lg) {
    (Select-String -Path $lg.FullName -Pattern 'RESULT\|' | ForEach-Object { $_.Line }) | Out-File $sum -Append -Encoding utf8
  }
}

('ALL DONE ' + (Get-Date -Format 'HH:mm:ss')) | Out-File $sum -Append -Encoding utf8
Write-Host ('ALL DONE. Summary: ' + $sum)
