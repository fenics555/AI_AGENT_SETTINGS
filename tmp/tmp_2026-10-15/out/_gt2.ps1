. 'D:\AI\AGENT_SETTINGS\tools\probe_tools.ps1'
Set-ProbeGuard -Sandbox 'D:\AI\PROBA' -TraceFile 'D:\AI\AGENT_SETTINGS\tmp\out\_gt2.jsonl'
Write-Host ('DenyGitWrite внутри guard = ' + $script:DenyGitWrite)
Write-Host ('--- прямой вызов (как в R4) ---')
$r = Invoke-ProbeTool -Name 'shell' -ToolArgs @{ cmd = 'git commit -m test' }
Write-Host ('прямой: ' + (([string]$r) -replace "`r?`n", ' ').Substring(0, [Math]::Min(60, ([string]$r).Length)))
Write-Host '--- вызов ИЗ ДРУГОЙ функции (как в реальной пробе) ---'
function Call-Tool { param($c) return (Invoke-ProbeTool -Name 'shell' -ToolArgs @{ cmd = $c }) }
$r2 = Call-Tool 'git commit -m test'
Write-Host ('из функции: ' + (([string]$r2) -replace "`r?`n", ' ').Substring(0, [Math]::Min(60, ([string]$r2).Length)))
