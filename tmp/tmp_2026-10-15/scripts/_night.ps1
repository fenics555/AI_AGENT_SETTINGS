$root='D:\AI\AGENT_SETTINGS\checks\agentic'
$keys = 1..16 | ForEach-Object { '{0:d2}' -f $_ }
$log = Join-Path $root ('log\night_' + (Get-Date -Format 'yyyy-MM-dd_HHmmss') + '.log')
"START $(Get-Date -Format 'HH:mm:ss')  16 rulesets v01..v16 x full canon" | Out-File $log -Encoding utf8
foreach ($k in $keys) {
    "=== v$k START $(Get-Date -Format 'HH:mm:ss') ===" | Out-File $log -Append -Encoding utf8
    & "$root\run_tests.ps1" -Rulesets $k
    "=== v$k END $(Get-Date -Format 'HH:mm:ss') ===" | Out-File $log -Append -Encoding utf8
}
"DONE $(Get-Date -Format 'HH:mm:ss')" | Out-File $log -Append -Encoding utf8
