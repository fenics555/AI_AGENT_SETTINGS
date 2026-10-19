import os

# ПРОВЕРКА P4/P5: law_p1 (база) vs law_p4 vs law_p5 x nemotron + qwen3 x тесты 3,4
lines = [
    "# run_p45.ps1 - law_p1 vs p4 vs p5 x nemotron + qwen3 x тесты 3,4",
    "$ErrorActionPreference = 'Continue'",
    "$root = 'D:\\AI\\AGENT_SETTINGS\\checks\\agentic'",
    "$logDir = Join-Path $root 'log'",
    "$tmp = 'D:\\AI\\AGENT_SETTINGS\\tmp'",
    "cd $root",
    "$stamp = Get-Date -Format 'yyyyMMdd_HHmmss'",
    "$sum = Join-Path $tmp ('run_p45_' + $stamp + '_summary.txt')",
    "\"START $(Get-Date -Format 'HH:mm:ss')  P4/P5: law_p1 vs p4 vs p5 | nemotron + qwen3  stamp=$stamp\" | Out-File $sum -Encoding utf8",
    "$t00 = Get-Date",
    "$models = @('nemotron','qwen3')",
    "$laws = @('p1','p4','p5')",
    "$jobs = @()",
    "foreach ($L in $laws) {",
    "  foreach ($m in $models) {",
    "    $jobs += @{ L=$L; model=$m; test='3'; script='check_3_skills_avail.ps1'; key='probe3_'; args=@('-Models',$m,'-Rulesets',$L,'-Seed','42') }",
    "    $jobs += @{ L=$L; model=$m; test='4'; script='check_4_skills_read.ps1';  key='probe4_'; args=@('-Models',$m,'-Rulesets',$L,'-Seed','42') }",
    "  }",
    "}",
    "('JOBS: ' + $jobs.Count) | Out-File $sum -Append -Encoding utf8",
    "$i = 0",
    "foreach ($j in $jobs) {",
    "  $i++",
    "  $t0 = Get-Date",
    "  Write-Host (('{0}/{1} law_{2} test={3} | {4} | START {5}' -f $i,$jobs.Count,$j.L,$j.test,$j.model,$t0.ToString('HH:mm:ss'))) -ForegroundColor Yellow",
    "  ('[{0}/{1}] law_{2} test={3} model={4} START {5}' -f $i,$jobs.Count,$j.L,$j.test,$j.model,$t0.ToString('HH:mm:ss')) | Out-File $sum -Append -Encoding utf8",
    "  ollama stop $j.model 2>$null | Out-Null",
    "  Get-Process llama-server -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue",
    "  Start-Sleep -Seconds 5",
    "  $targs = @('-NoProfile','-ExecutionPolicy','Bypass','-File',(Join-Path $root $j.script)) + $j.args",
    "  Start-Process powershell -ArgumentList $targs -Wait -NoNewWindow",
    "  Start-Sleep -Seconds 2",
    "  $lg = Get-ChildItem $logDir -Filter ($j.key + '*.txt') | Where-Object { $_.Name -notmatch 'trace' } | Sort-Object LastWriteTime -Descending | Select-Object -First 1",
    "  $sec = [math]::Round(((Get-Date) - $t0).TotalSeconds, 1)",
    "  $avg = ((Get-Date) - $t00).TotalSeconds / $i",
    "  $eta = (Get-Date).AddSeconds($avg * ($jobs.Count - $i)).ToString('HH:mm')",
    "  Write-Host (('    sec={0} ETA~{1}' -f $sec,$eta)) -ForegroundColor Cyan",
    "  ('  sec=' + $sec + '  ETA~' + $eta) | Out-File $sum -Append -Encoding utf8",
    "  if ($lg) {",
    "    (Select-String -Path $lg.FullName -Pattern 'RESULT\\|' | ForEach-Object { $_.Line }) | Out-File $sum -Append -Encoding utf8",
    "  }",
    "}",
    "Write-Host ('ALL DONE ' + (Get-Date -Format 'HH:mm:ss')) -ForegroundColor Green",
    "('ALL DONE ' + (Get-Date -Format 'HH:mm:ss')) | Out-File $sum -Append -Encoding utf8",
]

path = r"D:\AI\AGENT_SETTINGS\tmp\run_p45.ps1"
with open(path, "w", encoding="utf-8-sig", newline="\r\n") as fh:
    fh.write("\n".join(lines) + "\n")
print("written", path, "lines=", len(lines))
