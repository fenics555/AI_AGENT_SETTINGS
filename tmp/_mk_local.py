import os

# ЛОКАЛЬНАЯ ПРОВЕРКА: law_9 vs живой на gpt-oss (1 модель, 2 теста)
lines = [
    "# run_local_check.ps1 - локальная проверка law_9 на gpt-oss",
    "$ErrorActionPreference = 'Continue'",
    "$root = 'D:\\AI\\AGENT_SETTINGS\\checks\\agentic'",
    "$logDir = Join-Path $root 'log'",
    "$tmp = 'D:\\AI\\AGENT_SETTINGS\\tmp'",
    "cd $root",
    "$stamp = Get-Date -Format 'yyyyMMdd_HHmmss'",
    "$sum = Join-Path $tmp ('run_local_' + $stamp + '_summary.txt')",
    "\"START $(Get-Date -Format 'HH:mm:ss')  ЛОКАЛЬНАЯ: law_2 vs law_9 на gpt-oss  stamp=$stamp\" | Out-File $sum -Encoding utf8",
    "",
    "$jobs = @(",
    "  @{ L='2'; test='3'; script='check_3_skills_avail.ps1'; key='probe3_'; args=@('-Models','gpt-oss','-Rulesets','2','-Seed','42') },",
    "  @{ L='9'; test='3'; script='check_3_skills_avail.ps1'; key='probe3_'; args=@('-Models','gpt-oss','-Rulesets','9','-Seed','42') },",
    "  @{ L='2'; test='4'; script='check_4_skills_read.ps1';  key='probe4_'; args=@('-Models','gpt-oss','-Rulesets','2','-Seed','42') },",
    "  @{ L='9'; test='4'; script='check_4_skills_read.ps1';  key='probe4_'; args=@('-Models','gpt-oss','-Rulesets','9','-Seed','42') }",
    ")",
    "",
    "$i = 0",
    "foreach ($j in $jobs) {",
    "  $i++",
    "  $t0 = Get-Date",
    "  Write-Host (('{0}/4 law_{1} test={2} | START {3}' -f $i,$j.L,$j.test,$t0.ToString('HH:mm:ss'))) -ForegroundColor Yellow",
    "  ('[{0}/4] law_{1} test={2} START {3}' -f $i,$j.L,$j.test,$t0.ToString('HH:mm:ss')) | Out-File $sum -Append -Encoding utf8",
    "  Get-Process llama-server -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue",
    "  Start-Sleep -Seconds 3",
    "  $targs = @('-NoProfile','-ExecutionPolicy','Bypass','-File',(Join-Path $root $j.script)) + $j.args",
    "  Start-Process powershell -ArgumentList $targs -Wait -NoNewWindow",
    "  Start-Sleep -Seconds 2",
    "  $lg = Get-ChildItem $logDir -Filter ($j.key + '*.txt') | Where-Object { $_.Name -notmatch 'trace' } | Sort-Object LastWriteTime -Descending | Select-Object -First 1",
    "  $sec = [math]::Round(((Get-Date) - $t0).TotalSeconds, 1)",
    "  Write-Host (('    sec={0}' -f $sec)) -ForegroundColor Cyan",
    "  ('  sec=' + $sec) | Out-File $sum -Append -Encoding utf8",
    "  if ($lg) {",
    "    (Select-String -Path $lg.FullName -Pattern 'RESULT\\||ОШИБКА' | ForEach-Object { $_.Line }) | Out-File $sum -Append -Encoding utf8",
    "  }",
    "}",
    "Write-Host ('ALL DONE ' + (Get-Date -Format 'HH:mm:ss')) -ForegroundColor Green",
    "('ALL DONE ' + (Get-Date -Format 'HH:mm:ss')) | Out-File $sum -Append -Encoding utf8",
]

path = r"D:\AI\AGENT_SETTINGS\tmp\run_local_check.ps1"
with open(path, "w", encoding="utf-8-sig", newline="\r\n") as fh:
    fh.write("\n".join(lines) + "\n")
print("written", path, "lines=", len(lines))
