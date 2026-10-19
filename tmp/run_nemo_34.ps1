# Драйвер: тесты 3+4 на nemotron (после исправления ключа Rulesets: A = живой закон).
$root   = 'D:\AI\AGENT_SETTINGS\checks\agentic'
$tmp    = 'D:\AI\AGENT_SETTINGS\tmp'
$models = 'nemotron'
$seed   = 42
$summary = Join-Path $tmp 'run_nemo_34_summary.txt'
"=== ТЕСТЫ 3+4 НА $models  START $(Get-Date -Format 'HH:mm:ss') ===" | Out-File $summary -Encoding utf8

$tests = @(
    @{ f = 'check_3_skills_avail.ps1'; tag = 'TEST3_AVAIL'; args = @('-Models',$models,'-Rulesets','A','-Seed',$seed) },
    @{ f = 'check_4_skills_read.ps1';  tag = 'TEST4_APPLY'; args = @('-Models',$models,'-Rulesets','A','-Seed',$seed) }
)

foreach ($t in $tests) {
    $t0  = Get-Date
    $out = Join-Path $tmp ("run_nemo_" + $t.tag + ".out.txt")
    $err = Join-Path $tmp ("run_nemo_" + $t.tag + ".err.txt")
    Remove-Item $out,$err -ErrorAction SilentlyContinue
    Write-Host ("=== " + $t.tag + " START " + $t0.ToString('HH:mm:ss') + " ===")
    Start-Process -FilePath 'powershell' `
        -ArgumentList (@('-NoProfile','-ExecutionPolicy','Bypass','-File',(Join-Path $root $t.f)) + $t.args) `
        -WorkingDirectory $root -WindowStyle Hidden -RedirectStandardOutput $out -RedirectStandardError $err -Wait
    $el = [math]::Round(((Get-Date) - $t0).TotalMinutes, 1)
    $lines = Get-Content $out -Encoding utf8 -ErrorAction SilentlyContinue
    "--- $($t.tag) done in $el min ---" | Out-File $summary -Append -Encoding utf8
    @($lines | Where-Object { $_ -match 'RESULT|ERROR|FLAGS|SKILL|COUNT' }) | Out-File $summary -Append -Encoding utf8
    Write-Host ("=== " + $t.tag + " DONE in " + $el + " min ===")
}
"=== ALL DONE $(Get-Date -Format 'HH:mm:ss') ===" | Out-File $summary -Append -Encoding utf8
