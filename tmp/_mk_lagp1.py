import os

lines = [
    "# run_laguna_p1.ps1 - ПРОВЕРКА: лагуна на law_p1 с ИСПРАВЛЕННЫМ SURVEY",
    "$ErrorActionPreference = 'Continue'",
    "$root = 'D:\\AI\\AGENT_SETTINGS\\checks\\agentic'",
    "$logDir = Join-Path $root 'log'",
    "$tmp = 'D:\\AI\\AGENT_SETTINGS\\tmp'",
    "cd $root",
    "$stamp = Get-Date -Format 'yyyyMMdd_HHmmss'",
    "$sum = Join-Path $tmp ('run_lagp1_' + $stamp + '_summary.txt')",
    "\"START $(Get-Date -Format 'HH:mm:ss')  ЛАГУНА + law_p1 + ФИКС SURVEY  stamp=$stamp\" | Out-File $sum -Encoding utf8",
    "$t0 = Get-Date",
    "& ollama stop laguna-xs-2.1:latest 2>&1 | Out-Null",
    "Get-Process llama-server -EA SilentlyContinue | Stop-Process -Force -EA SilentlyContinue",
    "Start-Sleep -Seconds 5",
    "Write-Host 'тест 3 | laguna | закон A (живой law_p1)' -ForegroundColor Yellow",
    "$targs = @('-NoProfile','-ExecutionPolicy','Bypass','-File',(Join-Path $root 'check_3_skills_avail.ps1'),'-Models','laguna','-Rulesets','A','-Seed','42')",
    "Start-Process powershell -ArgumentList $targs -Wait -NoNewWindow",
    "Start-Sleep -Seconds 2",
    "$sec = [math]::Round(((Get-Date) - $t0).TotalSeconds, 1)",
    "$lg = Get-ChildItem $logDir -Filter 'probe3_*.txt' | Where-Object { $_.Name -notmatch 'trace' } | Sort-Object LastWriteTime -Descending | Select-Object -First 1",
    "('  sec=' + $sec + ' log=' + $(if($lg){$lg.Name}else{'NONE'})) | Out-File $sum -Append -Encoding utf8",
    "if ($lg) {",
    "  $c = Get-Content $lg.FullName -Encoding utf8 -Raw",
    "  $i = $c.IndexOf('ОПРОС МОДЕЛИ')",
    "  if ($i -ge 0) {",
    "    $blk = $c.Substring($i)",
    "    ('SURVEY БЛОК = ' + $blk.Length + ' симв.') | Out-File $sum -Append -Encoding utf8",
    "    $blk | Out-File $sum -Append -Encoding utf8",
    "    Write-Host '==== SURVEY (полный) ====' -ForegroundColor Green",
    "    Write-Host $blk",
    "  }",
    "  (Select-String -Path $lg.FullName -Pattern 'RESULT\\|' | ForEach-Object { $_.Line }) | Out-File $sum -Append -Encoding utf8",
    "}",
    "Write-Host ('ALL DONE ' + (Get-Date -Format 'HH:mm:ss')) -ForegroundColor Green",
    "('ALL DONE ' + (Get-Date -Format 'HH:mm:ss')) | Out-File $sum -Append -Encoding utf8",
]

path = r"D:\AI\AGENT_SETTINGS\tmp\run_laguna_p1.ps1"
with open(path, "w", encoding="utf-8-sig", newline="\r\n") as fh:
    fh.write("\n".join(lines) + "\n")
print("written", path, "lines=", len(lines))
