. "D:\AI\AGENT_SETTINGS\config\paths.ps1"
. "D:\AI\AGENT_SETTINGS\tools\probe_tools.ps1"
Set-ProbeGuard -Sandbox $CFG.Sandbox -TraceFile "D:\AI\AGENT_SETTINGS\tmp\_t.jsonl" -ReadLimit 48000 -ShellLimit 48000
$tools = Get-ProbeToolDefs
$sys = "Ты агент. ЗАКОН: читай файлы инструментами. Ответь числом."
$r = Invoke-OllamaTools -Model "gemma4:26b" -Tools $tools -MaxTurns 4 -Messages @(@{role="system";content=$sys},@{role="user";content="Посчитай: (Get-ChildItem D:\AI\repo -Recurse -File -Filter SKILL_*.md).Count — назови число"})
Write-Output ("Answer len: " + $r.Answer.Length + " | source: " + $r.AnswerSource + " | calls: " + @($r.ToolCalls).Count)
Write-Output ("Answer: [" + $r.Answer.Substring(0,[Math]::Min(120,$r.Answer.Length)) + "]")
