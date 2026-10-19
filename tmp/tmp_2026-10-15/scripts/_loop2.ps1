# _loop2.ps1 — проверка рычагов v17..v19 (форсировать маршрут): T12c на nemotron + gpt-oss
$root = 'D:\AI\AGENT_SETTINGS\checks\agentic'
foreach ($rs in '17', '18', '19') {
    foreach ($m in 'gpt-oss', 'qwen') {
        $h = @{ Rulesets = $rs; Models = $m; OnlyTasks = 'T12c' }
        Write-Host ("### probe3 rs=$rs T12c model=$m") -ForegroundColor Cyan
        & (Join-Path $root 'probe_3_rules_skills.ps1') @h
    }
}
Write-Host 'LOOP2 DONE'
