import os

# ТЕСТ 4 x 2 модели (laguna + gpt-oss) на law_3: проверка рычага "поиск по смыслу".
lines = [
    "# run_law3_t4.ps1 - law_3: test 4 x 2 models (проверка поиска по смыслу)",
    "$ErrorActionPreference = 'Continue'",
    "$root = 'D:\\AI\\AGENT_SETTINGS\\checks\\agentic'",
    "$logDir = Join-Path $root 'log'",
    "$tmp = 'D:\\AI\\AGENT_SETTINGS\\tmp'",
    "cd $root",
    "$stamp = Get-Date -Format 'yyyyMMdd_HHmmss'",
    "$sum = Join-Path $tmp ('run_law3_' + $stamp + '_summary.txt')",
    "\"START $(Get-Date -Format 'HH:mm:ss')  run=law_3 test=4 2models  stamp=$stamp\" | Out-File $sum -Encoding utf8",
    "$t00 = Get-Date",
    "('LAW3: ' + (Get-Item 'D:\\AI\\AGENT_SETTINGS\\laws\\law_3.md').Length + ' bytes') | Out-File $sum -Append -Encoding utf8",
    "",
    "# тест 4 на модели: laguna (слабая), gpt-oss (быстрая), nemotron (проблемная)",
    "$jobs = @(",
    "  @{ model='laguna'; args=@('-Models','laguna','-Rulesets','3','-Seed','42') },",
    "  @{ model='gpt-oss'; args=@('-Models','gpt-oss','-Rulesets','3','-Seed','42') },",
    "  @{ model='nemotron'; args=@('-Models','nemotron','-Rulesets','3','-Seed','42') }",
    ")",
    "",
    "$i = 0",
    "foreach ($j in $jobs) {",
    "  $i++",
    "  $t0 = Get-Date",
    "  Write-Host (('{0}/{1} TEST 4 | {2} | START {3}' -f $i,$jobs.Count,$j.model,$t0.ToString('HH:mm:ss'))) -ForegroundColor Yellow",
    "  ('[{0}/{1}] test=4 model={2} START {3}' -f $i,$jobs.Count,$j.model,$t0.ToString('HH:mm:ss')) | Out-File $sum -Append -Encoding utf8",
    "  Get-Process llama-server -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue",
    "  Start-Sleep -Seconds 3",
    "  $targs = @('-NoProfile','-ExecutionPolicy','Bypass','-File',(Join-Path $root 'check_4_skills_read.ps1')) + $j.args",
    "  Start-Process powershell -ArgumentList $targs -Wait -NoNewWindow",
    "  Start-Sleep -Seconds 2",
    "  $lg = Get-ChildItem $logDir -Filter 'probe4_*.txt' | Where-Object { $_.Name -notmatch 'trace' } | Sort-Object LastWriteTime -Descending | Select-Object -First 1",
    "  $sec = [math]::Round(((Get-Date) - $t0).TotalSeconds, 1)",
    "  Write-Host (('    log={0} sec={1}' -f $(if($lg){$lg.Name}else{'NONE'}),$sec)) -ForegroundColor Cyan",
    "  ('  log=' + $(if($lg){$lg.Name}else{'NONE'}) + '  sec=' + $sec) | Out-File $sum -Append -Encoding utf8",
    "  if ($lg) {",
    "    (Select-String -Path $lg.FullName -Pattern 'RESULT\\|' | ForEach-Object { $_.Line }) | Out-File $sum -Append -Encoding utf8",
    "  }",
    "}",
    "",
    "Write-Host ('ALL DONE ' + (Get-Date -Format 'HH:mm:ss') + ' | ' + $sum) -ForegroundColor Green",
    "('ALL DONE ' + (Get-Date -Format 'HH:mm:ss')) | Out-File $sum -Append -Encoding utf8",
]

path = r"D:\AI\AGENT_SETTINGS\tmp\run_law3_t4.ps1"
with open(path, "w", encoding="utf-8-sig", newline="\r\n") as fh:
    fh.write("\n".join(lines) + "\n")
print("written", path, "lines=", len(lines))
