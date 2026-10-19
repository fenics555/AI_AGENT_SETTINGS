# _test_real_tool.ps1 — проверка РЕАЛЬНОГО Invoke-ProbeTool после фикса (не эмуляция)
$ErrorActionPreference = 'Continue'
. 'D:\AI\AGENT_SETTINGS\config\paths.ps1'
. 'D:\AI\AGENT_SETTINGS\tools\probe_tools.ps1'

$logDir = 'D:\AI\AGENT_SETTINGS\checks\agentic\log'
Set-ProbeGuard -Sandbox 'D:\AI\PROBA' -TraceFile (Join-Path $logDir '_test_trace.jsonl')

'=== РЕАЛЬНЫЙ Invoke-ProbeTool: shell с вложенным powershell (была 446) ==='
$a = Invoke-ProbeTool -Name 'shell' -ToolArgs @{ cmd = 'powershell -Command "Get-ChildItem -Recurse -Filter ''SKILL_*.md'' -Path ''D:\AI\repo'' | Measure-Object | Select-Object -ExpandProperty Count"' }
'результат: [' + ([string]$a).Trim() + ']   ожидание 199   ' + $(if (([string]$a).Trim() -eq '199') { 'PASS' } else { 'FAIL' })

'=== РЕАЛЬНЫЙ Invoke-ProbeTool: shell без обёртки ==='
$b = Invoke-ProbeTool -Name 'shell' -ToolArgs @{ cmd = 'Get-ChildItem -Recurse -Filter ''SKILL_*.md'' -Path ''D:\AI\repo\Creo'' | Measure-Object | Select-Object -ExpandProperty Count' }
'результат: [' + ([string]$b).Trim() + ']   ожидание 65   ' + $(if (([string]$b).Trim() -eq '65') { 'PASS' } else { 'FAIL' })

'=== TRACE (что записано) ==='
$tf = Join-Path $logDir '_test_trace.jsonl'
if (Test-Path $tf) { Get-Content $tf -Encoding UTF8 | ForEach-Object { $_.Substring(0, [Math]::Min(220, $_.Length)) } }
