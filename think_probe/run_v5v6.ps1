# Runner: последовательно v5 (генерация кода) и v6 (чат-поведение).
# Запускается детачем из Cline; пишет свой лог в log\.
$ErrorActionPreference = 'Continue'
$tp = 'D:\AI\AGENT_SETTINGS\think_probe'
& (Join-Path $tp 'think_probe_v5.ps1')
& (Join-Path $tp 'think_probe_v6.ps1')
Write-Host 'RUN_V5V6 DONE'
