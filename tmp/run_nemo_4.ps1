# Драйвер: 4 канон-теста на ОДНОЙ модели (nemotron), последовательно (GPU одна).
# ОДНО ОКНО ХРОНОЛОГИИ (владелец, 15.10.2026): дочерние тесты запускаются ВИДИМО (-NoNewWindow),
#   чтобы был виден прогресс. ЭТО ОКНО ЗАКРЫВАТЬ НЕЛЬЗЯ — вместе с ним умрёт прогон.
#   Хронология дополнительно дублируется в run_nemo_4_summary.txt.
$root   = 'D:\AI\AGENT_SETTINGS\checks\agentic'
$tmp    = 'D:\AI\AGENT_SETTINGS\tmp'
$models = 'nemotron'
$law    = 'live'
$seed   = 42
$summary = Join-Path $tmp 'run_nemo_4_summary.txt'
"=== 4 ТЕСТА НА $models  START $(Get-Date -Format 'HH:mm:ss') ===" | Out-File $summary -Encoding utf8

$tests = @(
    @{ f = 'check_1_law.ps1';          tag = 'TEST1_LAW';   args = @('-Models',$models,'-Law',$law,'-Seed',$seed) },
    @{ f = 'check_2_read.ps1';         tag = 'TEST2_READ';  args = @('-Models',$models,'-Law',$law,'-Seed',$seed) },
    @{ f = 'check_3_skills_avail.ps1'; tag = 'TEST3_AVAIL'; args = @('-Models',$models,'-Rulesets','A','-Seed',$seed) },
    @{ f = 'check_4_skills_read.ps1';  tag = 'TEST4_APPLY'; args = @('-Models',$models,'-Rulesets','A','-Seed',$seed) }
)

foreach ($t in $tests) {
    $t0  = Get-Date
    $out = Join-Path $tmp ("run_nemo_" + $t.tag + ".out.txt")
    $err = Join-Path $tmp ("run_nemo_" + $t.tag + ".err.txt")
    Remove-Item $out,$err -ErrorAction SilentlyContinue
    Write-Host ("=== " + $t.tag + " START " + $t0.ToString('HH:mm:ss') + " ===")
    $exe = Join-Path $root $t.f
    # ВИДИМЫЙ запуск (одно окно хронологии): тест печатает прогресс на экран И в лог.
    $p = Start-Process -FilePath 'powershell' `
        -ArgumentList (@('-NoProfile','-ExecutionPolicy','Bypass','-File',$exe) + $t.args) `
        -WorkingDirectory $root -NoNewWindow -PassThru -Wait
    $el = [math]::Round(((Get-Date) - $t0).TotalMinutes, 1)
    $lines = Get-Content $out -Encoding utf8 -ErrorAction SilentlyContinue
    $verdicts = @($lines | Where-Object { $_ -match 'LAW_CITED|HONEST|GUESSED|HALLUC|SKILL_READ|MAP_ONLY|COUNT_|FLAGS|ФЛАГИ|SKILL_READ' })
    "--- $($t.tag) done in $el min ---" | Out-File $summary -Append -Encoding utf8
    $verdicts | Out-File $summary -Append -Encoding utf8
    Write-Host ("=== " + $t.tag + " DONE in " + $el + " min ===")
}
"=== ALL DONE $(Get-Date -Format 'HH:mm:ss') ===" | Out-File $summary -Append -Encoding utf8
Write-Host '=== QUEUE DONE ==='
