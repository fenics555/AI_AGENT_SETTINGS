# Driver: run law variants one by one (H1..H4) on all models. ASCII-only (no cyrillic!).
# Run: powershell -NoProfile -ExecutionPolicy Bypass -File _run_h.ps1 -Laws "H2,H3,H4" -Models "all"
param([string]$Laws = 'H1,H2,H3,H4', [string]$Models = 'all')
$root = 'D:\AI\AGENT_SETTINGS\checks\agentic'
Set-Location $root
foreach ($lw in ($Laws -split ',' | ForEach-Object { $_.Trim() })) {
    if (-not $lw) { continue }
    Write-Host ("=== RUN law " + $lw + " ===") -ForegroundColor Cyan
    & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $root 'check_1_law.ps1') -Models $Models -Law $lw -Seed 42
}
Write-Host '=== SWOD DONE ===' -ForegroundColor Green
