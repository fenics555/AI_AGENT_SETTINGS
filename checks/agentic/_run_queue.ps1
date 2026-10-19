# Driver: run canon tests in order: 1 -> 2 -> 3 -> 4 -> 5 (последовательная логика; ASCII-only).
# Run: powershell -NoProfile -ExecutionPolicy Bypass -File _run_queue.ps1
param([string]$Law = 'D:\AI\AGENT_SETTINGS\laws\law_H7.md', [string]$Models = 'all')
$root = 'D:\AI\AGENT_SETTINGS\checks\agentic'
Set-Location $root
$tests = @(
    @{ f = 'check_1_law.ps1';          tag = 'TEST1_LAW'  },
    @{ f = 'check_2_read.ps1';         tag = 'TEST2_READ' },
    @{ f = 'check_3_skills_avail.ps1'; tag = 'TEST3_AVAIL'; extra = @('-Rulesets', $Law) },
    @{ f = 'check_4_skills_read.ps1';  tag = 'TEST4_APPLY'; extra = @('-Rulesets', $Law) },
    @{ f = 'check_5_creo.ps1';         tag = 'TEST5_CREO' }
)
foreach ($t in $tests) {
    $t0 = Get-Date
    Write-Host ("=== " + $t.tag + " START " + $t0.ToString('HH:mm:ss') + " ===") -ForegroundColor Cyan
    $ex = @('-Models', $Models, '-Seed', '42')
    if ($t.extra) { $ex += $t.extra } else { $ex += @('-Law', $Law) }
    & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $root $t.f) @ex
    $el = [math]::Round(((Get-Date) - $t0).TotalMinutes, 1)
    Write-Host ("=== " + $t.tag + " DONE in " + $el + " min ===") -ForegroundColor Green
}
Write-Host '=== QUEUE DONE ===' -ForegroundColor Green
