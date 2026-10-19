# run_lawV_2x2.ps1 - прогон: laguna (слабая) + gemma4 (сильная) x тест1 + тест3 x закон live/V
$ErrorActionPreference = 'Continue'
$root = 'D:\AI\AGENT_SETTINGS\checks\agentic'
cd $root
$stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$sum = Join-Path 'D:\AI\AGENT_SETTINGS\tmp' ('run_lawV_' + $stamp + '_summary.txt')
"START $(Get-Date -Format 'HH:mm:ss')  run=lawV 2x2  stamp=$stamp" | Out-File $sum -Encoding utf8

# --- ЭТАЛОН ---
$et = 'ЭТАЛОН НА СТАРТЕ ' + (Get-Date -Format 'HH:mm:ss') + ': total=' + @(Get-ChildItem 'D:\AI\repo' -Recurse -File -Filter 'SKILL_*.md').Count
$et += ' creo=' + @(Get-ChildItem 'D:\AI\repo\Creo' -Recurse -File -Filter '*.md').Count
$et += ' prog=' + @(Get-ChildItem 'D:\AI\repo\Prog' -Recurse -File -Filter '*.md').Count
$et | Tee-Object -FilePath $sum -Append

# --- СПИСОК ЗАДАЧ ---
$jobs = @(
  @{ law='live'; model='laguna'; test='1'; script='check_1_law.ps1'; args=@('-Models','laguna','-Law','live','-Seed','42') },
  @{ law='live'; model='laguna'; test='3'; script='check_3_skills_avail.ps1'; args=@('-Models','laguna','-Rulesets','A','-Seed','42') },
  @{ law='V';    model='laguna'; test='1'; script='check_1_law.ps1'; args=@('-Models','laguna','-Law','V','-Seed','42') },
  @{ law='V';    model='laguna'; test='3'; script='check_3_skills_avail.ps1'; args=@('-Models','laguna','-Rulesets','V','-Seed','42') },
  @{ law='live'; model='gemma4'; test='1'; script='check_1_law.ps1'; args=@('-Models','gemma4','-Law','live','-Seed','42') },
  @{ law='live'; model='gemma4'; test='3'; script='check_3_skills_avail.ps1'; args=@('-Models','gemma4','-Rulesets','A','-Seed','42') },
  @{ law='V';    model='gemma4'; test='1'; script='check_1_law.ps1'; args=@('-Models','gemma4','-Law','V','-Seed','42') },
  @{ law='V';    model='gemma4'; test='3'; script='check_3_skills_avail.ps1'; args=@('-Models','gemma4','-Rulesets','V','-Seed','42') }
)

$i = 0
foreach ($j in $jobs) {
  $i++
  $t0 = Get-Date
  $hdr = '[{0}/{1}] {2} law={3} model={4} test={5}  СТАРТ {6}' -f $i, $jobs.Count, $j.script, $j.law, $j.model, $j.test, $t0.ToString('HH:mm:ss')
  Write-Host $hdr -ForegroundColor Cyan
  $hdr | Out-File $sum -Append -Encoding utf8
  # стоп llama-server перед сменой модели
  Get-Process llama-server -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
  Start-Sleep -Seconds 3
  $out = & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $root $j.script) @($j.args) 2>&1
  $sec = [math]::Round(((Get-Date) - $t0).TotalSeconds, 1)
  $res = @($out | Where-Object { $_ -match 'RESULT\|' })
  if ($res.Count) { $res | Out-File $sum -Append -Encoding utf8 } else { ('НЕТ RESULT (' + $j.script + ' ' + $j.law + ' ' + $j.model + ')') | Out-File $sum -Append -Encoding utf8 }
  ('  -> sec=' + $sec) | Out-File $sum -Append -Encoding utf8
}

('ALL DONE ' + (Get-Date -Format 'HH:mm:ss')) | Out-File $sum -Append -Encoding utf8
Write-Host 'ALL DONE' -ForegroundColor Green
Write-Host ('Сводка: ' + $sum)
Read-Host 'Нажми Enter для закрытия'
