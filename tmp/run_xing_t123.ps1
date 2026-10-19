# run_xing_t123.ps1 - tests 1,2,3 for Xing4.0-29B-A4B
$ErrorActionPreference = 'Continue'
$root = 'D:\AI\AGENT_SETTINGS\checks\agentic'
$logDir = Join-Path $root 'log'
$tmp = 'D:\AI\AGENT_SETTINGS\tmp'
cd $root
. 'D:\AI\AGENT_SETTINGS\config\paths.ps1'
$stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$sum = Join-Path $tmp ('run_xing_' + $stamp + '_summary.txt')
"START $(Get-Date -Format 'HH:mm:ss')  run=xing tests=1,2,3  stamp=$stamp" | Out-File $sum -Encoding utf8
$t00 = Get-Date
$m = @($CFG.Models | Where-Object { $_ -like '*Xing*' })[0]
('MODEL: ' + $m) | Tee-Object -FilePath $sum -Append
('LAW: ' + (Get-Item 'D:\AI\.clinerules').Length + ' bytes SHA=' + (Get-FileHash 'D:\AI\.clinerules' -Algorithm SHA256).Hash.Substring(0,8)) | Tee-Object -FilePath $sum -Append
('ETALON ' + (Get-Date -Format 'HH:mm:ss') + ': total=' + @(Get-ChildItem 'D:\AI\repo' -Recurse -File -Filter 'SKILL_*.md').Count + ' creo=' + @(Get-ChildItem 'D:\AI\repo\Creo' -Recurse -File -Filter 'SKILL_*.md').Count + ' prog=' + @(Get-ChildItem 'D:\AI\repo\Prog' -Recurse -File -Filter 'SKILL_*.md').Count) | Tee-Object -FilePath $sum -Append

$jobs = @(
  @{ test='1'; script='check_1_law.ps1';          key='check1law_'; args=@('-Models',$m,'-Law','live','-Seed','42') },
  @{ test='2'; script='check_2_read.ps1';         key='check2read_'; args=@('-Models',$m,'-Law','live','-Seed','42') },
  @{ test='3'; script='check_3_skills_avail.ps1'; key='probe3_';    args=@('-Models',$m,'-Rulesets','A','-Seed','42') }
)

$i = 0
foreach ($j in $jobs) {
  $i++
  $t0 = Get-Date
  Write-Host (('{0}/{1} TEST {2} | Xing4.0 | START {3}' -f $i,$jobs.Count,$j.test,$t0.ToString('HH:mm:ss'))) -ForegroundColor Yellow
  ('[{0}/{1}] test={2} START {3}' -f $i,$jobs.Count,$j.test,$t0.ToString('HH:mm:ss')) | Out-File $sum -Append -Encoding utf8
  Get-Process llama-server -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
  Start-Sleep -Seconds 3
  $targs = @('-NoProfile','-ExecutionPolicy','Bypass','-File',(Join-Path $root $j.script)) + $j.args
  Start-Process powershell -ArgumentList $targs -Wait -NoNewWindow
  Start-Sleep -Seconds 2
  $lg = Get-ChildItem $logDir -Filter ($j.key + '*.txt') | Where-Object { $_.Name -notmatch 'trace' } | Sort-Object LastWriteTime -Descending | Select-Object -First 1
  $sec = [math]::Round(((Get-Date) - $t0).TotalSeconds, 1)
  Write-Host (('    log={0} sec={1}' -f $(if($lg){$lg.Name}else{'NONE'}),$sec)) -ForegroundColor Cyan
  ('  log=' + $(if($lg){$lg.Name}else{'NONE'}) + '  sec=' + $sec) | Out-File $sum -Append -Encoding utf8
  if ($lg) {
    (Select-String -Path $lg.FullName -Pattern 'RESULT\|' | ForEach-Object { $_.Line }) | Tee-Object -FilePath $sum -Append
  }
}

Write-Host ('ALL DONE ' + (Get-Date -Format 'HH:mm:ss') + ' | ' + $sum) -ForegroundColor Green
('ALL DONE ' + (Get-Date -Format 'HH:mm:ss')) | Out-File $sum -Append -Encoding utf8
