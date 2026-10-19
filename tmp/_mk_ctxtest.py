import os

# ЗАМЕР: nemotron, тест 4, NumCtx=32768 (проверка гипотезы «65536 ломает»)
lines = [
    "# run_ctx_test.ps1 - Замер: nemotron test 4 при NumCtx=32768",
    "$ErrorActionPreference = 'Continue'",
    "$root = 'D:\\AI\\AGENT_SETTINGS\\checks\\agentic'",
    "$logDir = Join-Path $root 'log'",
    "$tmp = 'D:\\AI\\AGENT_SETTINGS\\tmp'",
    "cd $root",
    ". 'D:\\AI\\AGENT_SETTINGS\\config\\paths.ps1'",
    "$stamp = Get-Date -Format 'yyyyMMdd_HHmmss'",
    "$sum = Join-Path $tmp ('run_ctxtest_' + $stamp + '_summary.txt')",
    "\"START $(Get-Date -Format 'HH:mm:ss')  ЗАМЕР nemotron test=4  stamp=$stamp\" | Out-File $sum -Encoding utf8",
    "('NumCtx=' + $CFG.Probes.NumCtx + ' | ReadLimit=' + $CFG.Probes.ReadLimit) | Out-File $sum -Append -Encoding utf8",
    "$t0 = Get-Date",
    "Get-Process llama-server -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue",
    "Start-Sleep -Seconds 3",
    "Write-Host 'ЗАМЕР: nemotron test 4 @ NumCtx=32768' -ForegroundColor Yellow",
    "$targs = @('-NoProfile','-ExecutionPolicy','Bypass','-File',(Join-Path $root 'check_4_skills_read.ps1'),'-Models','nemotron','-Rulesets','3','-Seed','42')",
    "Start-Process powershell -ArgumentList $targs -Wait -NoNewWindow",
    "Start-Sleep -Seconds 2",
    "$lg = Get-ChildItem $logDir -Filter 'probe4_*.txt' | Where-Object { $_.Name -notmatch 'trace' } | Sort-Object LastWriteTime -Descending | Select-Object -First 1",
    "$sec = [math]::Round(((Get-Date) - $t0).TotalSeconds, 1)",
    "Write-Host (('ИТОГО: ' + $sec + ' с при NumCtx=' + $CFG.Probes.NumCtx)) -ForegroundColor Green",
    "('  sec=' + $sec + '  log=' + $(if($lg){$lg.Name}else{'NONE'})) | Out-File $sum -Append -Encoding utf8",
    "if ($lg) { (Select-String -Path $lg.FullName -Pattern 'RESULT\\|' | ForEach-Object { $_.Line }) | Out-File $sum -Append -Encoding utf8 }",
    "('ALL DONE ' + (Get-Date -Format 'HH:mm:ss')) | Out-File $sum -Append -Encoding utf8",
]

path = r"D:\AI\AGENT_SETTINGS\tmp\run_ctx_test.ps1"
with open(path, "w", encoding="utf-8-sig", newline="\r\n") as fh:
    fh.write("\n".join(lines) + "\n")
print("written", path, "lines=", len(lines))
