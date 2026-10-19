import os

# ИСПРАВЛЕНО по граблям 6.12.13-6.12.15:
#  - заголовок окна ASCII-ONLY
#  - запуск БЕЗ отдельного окна (Start-Process -NoNewWindow), лог драйвера в файл
#  - результат берём ИЗ ЛОГА теста
lines = [
    "# run_lawGVD_2x2.ps1 - прогон законов G/V/D: laguna+gemma4 x тест1+тест3 (fixed driver)",
    "$ErrorActionPreference = 'Continue'",
    "$root = 'D:\\AI\\AGENT_SETTINGS\\checks\\agentic'",
    "$logDir = Join-Path $root 'log'",
    "$tmp = 'D:\\AI\\AGENT_SETTINGS\\tmp'",
    "cd $root",
    "$stamp = Get-Date -Format 'yyyyMMdd_HHmmss'",
    "$sum = Join-Path $tmp ('run_lawGVD_' + $stamp + '_summary.txt')",
    "\"START $(Get-Date -Format 'HH:mm:ss')  run=lawGVD  stamp=$stamp\" | Out-File $sum -Encoding utf8",
    "",
    "$jobs = @(",
    "  @{ law='G'; model='laguna'; test='1'; script='check_1_law.ps1';         key='check1law_'; args=@('-Models','laguna','-Law','G','-Seed','42') },",
    "  @{ law='G'; model='laguna'; test='3'; script='check_3_skills_avail.ps1';key='probe3_';    args=@('-Models','laguna','-Rulesets','G','-Seed','42') },",
    "  @{ law='G'; model='gemma4'; test='1'; script='check_1_law.ps1';         key='check1law_'; args=@('-Models','gemma4','-Law','G','-Seed','42') },",
    "  @{ law='G'; model='gemma4'; test='3'; script='check_3_skills_avail.ps1';key='probe3_';    args=@('-Models','gemma4','-Rulesets','G','-Seed','42') },",
    "  @{ law='V'; model='gemma4'; test='1'; script='check_1_law.ps1';         key='check1law_'; args=@('-Models','gemma4','-Law','V','-Seed','42') },",
    "  @{ law='V'; model='gemma4'; test='3'; script='check_3_skills_avail.ps1';key='probe3_';    args=@('-Models','gemma4','-Rulesets','V','-Seed','42') },",
    "  @{ law='D'; model='laguna'; test='1'; script='check_1_law.ps1';         key='check1law_'; args=@('-Models','laguna','-Law','D','-Seed','42') },",
    "  @{ law='D'; model='laguna'; test='3'; script='check_3_skills_avail.ps1';key='probe3_';    args=@('-Models','laguna','-Rulesets','D','-Seed','42') },",
    "  @{ law='D'; model='gemma4'; test='1'; script='check_1_law.ps1';         key='check1law_'; args=@('-Models','gemma4','-Law','D','-Seed','42') },",
    "  @{ law='D'; model='gemma4'; test='3'; script='check_3_skills_avail.ps1';key='probe3_';    args=@('-Models','gemma4','-Rulesets','D','-Seed','42') }",
    ")",
    "",
    "$i = 0",
    "foreach ($j in $jobs) {",
    "  $i++",
    "  $t0 = Get-Date",
    "  ('[{0}/{1}] law={2} model={3} test={4} START {5}' -f $i,$jobs.Count,$j.law,$j.model,$j.test,$t0.ToString('HH:mm:ss')) | Out-File $sum -Append -Encoding utf8",
    "  Get-Process llama-server -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue",
    "  Start-Sleep -Seconds 3",
    "  $null = & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $root $j.script) @($j.args) 2>&1",
    "  Start-Sleep -Seconds 2",
    "  $lg = Get-ChildItem $logDir -Filter ($j.key + '*.txt') | Where-Object { $_.Name -notmatch 'trace' } | Sort-Object LastWriteTime -Descending | Select-Object -First 1",
    "  $sec = [math]::Round(((Get-Date) - $t0).TotalSeconds, 1)",
    "  ('  log=' + $lg.Name + '  sec=' + $sec) | Out-File $sum -Append -Encoding utf8",
    "  if ($lg) {",
    "    (Select-String -Path $lg.FullName -Pattern 'RESULT\\|' | ForEach-Object { $_.Line }) | Out-File $sum -Append -Encoding utf8",
    "  }",
    "}",
    "",
    "('ALL DONE ' + (Get-Date -Format 'HH:mm:ss')) | Out-File $sum -Append -Encoding utf8",
    "Write-Host ('ALL DONE. Summary: ' + $sum)",
]

path = r"D:\AI\AGENT_SETTINGS\tmp\run_lawGVD_2x2.ps1"
with open(path, "w", encoding="utf-8-sig", newline="\r\n") as fh:
    fh.write("\n".join(lines) + "\n")
print("written", path, "lines=", len(lines))
