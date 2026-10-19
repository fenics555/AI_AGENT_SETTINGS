import os

# ДОГОН: только тест 3 (СКИЛЛЫ: ВИДИМОСТЬ) x 2 модели. Канон §6.1.2.
lines = [
    "# run_stage1c_t3.ps1 - CATCH-UP: test 3 only x laguna+gemma4 on NEW live law",
    "$ErrorActionPreference = 'Continue'",
    "$root = 'D:\\AI\\AGENT_SETTINGS\\checks\\agentic'",
    "$logDir = Join-Path $root 'log'",
    "$tmp = 'D:\\AI\\AGENT_SETTINGS\\tmp'",
    "cd $root",
    "$stamp = Get-Date -Format 'yyyyMMdd_HHmmss'",
    "$sum = Join-Path $tmp ('run_stage1c_' + $stamp + '_summary.txt')",
    "\"START $(Get-Date -Format 'HH:mm:ss')  run=stage1c CATCHUP test=3  stamp=$stamp\" | Out-File $sum -Encoding utf8",
    "$t00 = Get-Date",
    "('LAW: ' + (Get-Item 'D:\\AI\\.clinerules').Length + ' bytes SHA=' + (Get-FileHash 'D:\\AI\\.clinerules' -Algorithm SHA256).Hash.Substring(0,8)) | Tee-Object -FilePath $sum -Append",
    "('ETALON ' + (Get-Date -Format 'HH:mm:ss') + ': total=' + @(Get-ChildItem 'D:\\AI\\repo' -Recurse -File -Filter 'SKILL_*.md').Count + ' creo=' + @(Get-ChildItem 'D:\\AI\\repo\\Creo' -Recurse -File -Filter 'SKILL_*.md').Count + ' prog=' + @(Get-ChildItem 'D:\\AI\\repo\\Prog' -Recurse -File -Filter 'SKILL_*.md').Count) | Tee-Object -FilePath $sum -Append",
    "",
    "$jobs = @(",
    "  @{ model='laguna'; args=@('-Models','laguna','-Rulesets','A','-Seed','42') },",
    "  @{ model='gemma4'; args=@('-Models','gemma4','-Rulesets','A','-Seed','42') }",
    ")",
    "",
    "$i = 0",
    "foreach ($j in $jobs) {",
    "  $i++",
    "  $t0 = Get-Date",
    "  Write-Host (('{0}/{1} TEST 3 | {2} | START {3}' -f $i,$jobs.Count,$j.model,$t0.ToString('HH:mm:ss'))) -ForegroundColor Yellow",
    "  ('[{0}/{1}] test=3 model={2} START {3}' -f $i,$jobs.Count,$j.model,$t0.ToString('HH:mm:ss')) | Out-File $sum -Append -Encoding utf8",
    "  Get-Process llama-server -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue",
    "  Start-Sleep -Seconds 3",
    "  $targs = @('-NoProfile','-ExecutionPolicy','Bypass','-File',(Join-Path $root 'check_3_skills_avail.ps1')) + $j.args",
    "  Start-Process powershell -ArgumentList $targs -Wait -NoNewWindow",
    "  Start-Sleep -Seconds 2",
    "  $lg = Get-ChildItem $logDir -Filter 'probe3_*.txt' | Where-Object { $_.Name -notmatch 'trace' } | Sort-Object LastWriteTime -Descending | Select-Object -First 1",
    "  $sec = [math]::Round(((Get-Date) - $t0).TotalSeconds, 1)",
    "  Write-Host (('    log={0} sec={1}' -f $(if($lg){$lg.Name}else{'NONE'}),$sec)) -ForegroundColor Cyan",
    "  ('  log=' + $(if($lg){$lg.Name}else{'NONE'}) + '  sec=' + $sec) | Out-File $sum -Append -Encoding utf8",
    "  if ($lg) {",
    "    (Select-String -Path $lg.FullName -Pattern 'RESULT\\|' | ForEach-Object { $_.Line }) | Tee-Object -FilePath $sum -Append",
    "  }",
    "}",
    "",
    "Write-Host ('ALL DONE ' + (Get-Date -Format 'HH:mm:ss') + ' | ' + $sum) -ForegroundColor Green",
    "('ALL DONE ' + (Get-Date -Format 'HH:mm:ss')) | Out-File $sum -Append -Encoding utf8",
]

path = r"D:\AI\AGENT_SETTINGS\tmp\run_stage1c_t3.ps1"
with open(path, "w", encoding="utf-8-sig", newline="\r\n") as fh:
    fh.write("\n".join(lines) + "\n")
print("written", path, "lines=", len(lines))
