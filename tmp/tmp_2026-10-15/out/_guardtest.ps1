. 'D:\AI\AGENT_SETTINGS\tools\probe_tools.ps1'
$tf = 'D:\AI\AGENT_SETTINGS\tmp\out\_guardtest.jsonl'
Set-ProbeGuard -Sandbox 'D:\AI\PROBA' -TraceFile $tf
$r1 = Invoke-ProbeTool -Name 'read_file' -ToolArgs @{ path = 'D:\AI\PROBA\work\note.txt' }
$r2 = Invoke-ProbeTool -Name 'write_file' -ToolArgs @{ path = 'D:\AI\PROBA\work\_guard_ok.txt'; content = 'ok' }
$r3 = Invoke-ProbeTool -Name 'write_file' -ToolArgs @{ path = 'D:\AI\repo\HACK.txt'; content = 'bad' }
$r4 = Invoke-ProbeTool -Name 'shell' -ToolArgs @{ cmd = 'git commit -m test' }
$r5 = Invoke-ProbeTool -Name 'shell' -ToolArgs @{ cmd = 'Get-ChildItem D:\AI\PROBA\work | Select-Object -First 2 -ExpandProperty Name' }
Write-Host ('R1 read len = ' + ([string]$r1).Length)
Write-Host ('R2 write-ok  = ' + ((([string]$r2) -replace "`r?`n", ' ').Substring(0, [Math]::Min(50, ([string]$r2).Length))))
Write-Host ('R3 write-out = ' + ([string]$r3))
Write-Host ('R4 git       = ' + ([string]$r4))
Write-Host ('R5 shell     = ' + ((([string]$r5) -replace "`r?`n", ' | ')))
Write-Host '=== TRACE ==='
Get-ProbeTrace | ForEach-Object { '{0} {1} origin={2} len={3}' -f $_.seq, $_.tool, $_.origin, ([string]$_.result).Length }
Remove-Item 'D:\AI\PROBA\work\_guard_ok.txt' -Force -ErrorAction SilentlyContinue
Write-Host ('sandbox file removed = ' + (-not (Test-Path 'D:\AI\PROBA\work\_guard_ok.txt')))
Write-Host ('repo HACK.txt exists = ' + (Test-Path 'D:\AI\repo\HACK.txt'))
