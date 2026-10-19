# _loop6.ps1 — РЫЧАГ «КЛЮЧИК»: узлы P2c/P2e/P2f на laguna + gpt-oss (с расширенной схемой инструментов)
$root = 'D:\AI\AGENT_SETTINGS\checks\agentic'
$env:PROBE_TOOLS_SHIM = Join-Path $root '_shim\probe_tools_B.shim.ps1'
foreach ($m in 'laguna', 'gpt-oss') {
    $h = @{ Rulesets = '21'; Models = $m; OnlyTasks = 'P2c,P2e,P2f' }
    Write-Host ("### KEY(expanded tools) rs=21 $m")
    & (Join-Path $root 'probe_2_tools.ps1') @h
}
Write-Host 'LOOP6 DONE'
