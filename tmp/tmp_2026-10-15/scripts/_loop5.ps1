# _loop5.ps1 — приёмка рычага: v21 против базы G на 2 узлах x 3 модели
$root = 'D:\AI\AGENT_SETTINGS\checks\agentic'
foreach ($rs in 'G', '21') {
    foreach ($m in 'gpt-oss', 'qwen', 'gemma4') {
        $h = @{ Rulesets = $rs; Models = $m; OnlyTasks = 'T12c' }
        Write-Host ("### probe3 rs=$rs T12c $m")
        & (Join-Path $root 'probe_3_rules_skills.ps1') @h
    }
}
foreach ($m in 'gpt-oss', 'laguna') {
    $h = @{ Rulesets = '21'; Models = $m; OnlyTasks = 'P2g_tool' }
    Write-Host ("### probe2 rs=21 P2g_tool $m")
    & (Join-Path $root 'probe_2_tools.ps1') @h
}
Write-Host 'LOOP5 DONE'
