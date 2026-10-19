# _loop4.ps1 — проверка v20 (комбо v17+v19): T12c на gpt-oss + qwen + gemma4
$root = 'D:\AI\AGENT_SETTINGS\checks\agentic'
foreach ($m in 'gpt-oss', 'qwen', 'gemma4') {
    $h = @{ Rulesets = '20'; Models = $m; OnlyTasks = 'T12c' }
    Write-Host ("### v20 T12c $m")
    & (Join-Path $root 'probe_3_rules_skills.ps1') @h
}
Write-Host 'LOOP4 DONE'
