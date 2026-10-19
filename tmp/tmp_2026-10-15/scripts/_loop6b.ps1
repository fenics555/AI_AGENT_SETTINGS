# _loop6b.ps1 — ПОВТОР «ключика» ЧИСТО, без параллельного канона + выяснить: процесс 8036 жив?
$root = 'D:\AI\AGENT_SETTINGS\checks\agentic'
Write-Host ('LOOP6B start ' + (Get-Date -Format 'HH:mm:ss'))
Write-Host ('loop6 PID 8036 alive = ' + ((Get-Process -Id 8036 -ErrorAction SilentlyContinue) -ne $null))
$env:PROBE_TOOLS_SHIM = Join-Path $root '_shim\probe_tools_B.shim.ps1'
foreach ($m in 'laguna', 'gpt-oss') {
    $h = @{ Rulesets = '21'; Models = $m; OnlyTasks = 'P2f,P2g' }
    Write-Host ("### KEY-v2 rs=21 $m  (P2f/P2g)")
    & (Join-Path $root 'probe_2_tools.ps1') @h
}
Write-Host 'LOOP6B DONE'
