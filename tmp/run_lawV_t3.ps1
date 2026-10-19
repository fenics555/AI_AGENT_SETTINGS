# Драйвер: ТЕСТ 3 на nemotron по вариантам закона (H7 база / H8 без режимов / H9 +2 вызова).
# ПРАВКА ТОЛЬКО В КОПИЯХ laws\*; живой закон НЕ трогаем.
# Запуск скрыто (владелец, 15.10.2026). Хронология -> run_lawV_t3.driver.out.txt
$root   = 'D:\AI\AGENT_SETTINGS\checks\agentic'
$tmp    = 'D:\AI\AGENT_SETTINGS\tmp'
$models = 'nemotron'
$seed   = 42
$summary = Join-Path $tmp 'run_lawV_t3_summary.txt'
"=== ТЕСТ 3 на $models ПО ВАРИАНТАМ ЗАКОНА  START $(Get-Date -Format 'HH:mm:ss') ===" | Out-File $summary -Encoding utf8

# key -> файл закона (все в laws\, кроме D/E которые рядом с тестом)
$variants = @(
    @{ k = 'H7'; note = 'BASA: явные режимы ЛЕГКИЙ/ПОЛНЫЙ + нет требования 2 вызовов' },
    @{ k = 'H8'; note = 'PRAVKA: режимы УБРАНЫ, один полный старт' },
    @{ k = 'H9'; note = 'PRAVKA2: режимы убраны + МИНИМУМ 2 вызова, план без вызова = не шаг' }
)

foreach ($v in $variants) {
    $lp = Join-Path 'D:\AI\AGENT_SETTINGS\laws' ('law_' + $v.k + '.md')
    if (-not (Test-Path $lp)) { Write-Host ("НЕТ ЗАКОНА: " + $lp); continue }
    $t0  = Get-Date
    $out = Join-Path $tmp ("run_lawV_t3_" + $v.k + ".out.txt")
    $err = Join-Path $tmp ("run_lawV_t3_" + $v.k + ".err.txt")
    Remove-Item $out,$err -ErrorAction SilentlyContinue
    Write-Host ""
    Write-Host ("################ " + $v.k + " : " + $v.note)
    Write-Host ("### START " + $t0.ToString('HH:mm:ss') + "  (закон " + $lp + ")")
    # ВИДИМО, БЕЗ редиректа: ход теста печатается ПРЯМО в это окно;
    # свои логи тест пишет сам в agentic\log\ (probe3_<stamp>.txt).
    Start-Process -FilePath 'powershell' `
        -ArgumentList @('-NoProfile','-ExecutionPolicy','Bypass','-File',(Join-Path $root 'check_3_skills_avail.ps1'),
                        '-Models',$models,'-Rulesets',$v.k,'-Seed',$seed) `
        -WorkingDirectory $root -NoNewWindow -Wait
    $el = [math]::Round(((Get-Date) - $t0).TotalMinutes, 1)
    Write-Host ("### " + $v.k + " DONE in " + $el + " min")
    # результат берём из СВЕЖЕГО лога теста (probe3_*.txt), самого нового
    $latest = Get-ChildItem (Join-Path $root 'log') -Filter 'probe3_*.txt' -ErrorAction SilentlyContinue |
              Sort-Object LastWriteTime -Descending | Select-Object -First 1
    "--- $($v.k) [$($v.note)] done in $el min | лог: $($latest.Name) ---" | Out-File $summary -Append -Encoding utf8
    if ($latest) {
        @(Get-Content $latest.FullName -Encoding utf8 | Where-Object { $_ -match 'RESULT\|probe3|VERDICT|ОТВЕТ МОДЕЛИ|ЭТАЛОН НА СТАРТЕ' }) |
            Out-File $summary -Append -Encoding utf8
    }
}
"=== ALL DONE $(Get-Date -Format 'HH:mm:ss') ===" | Out-File $summary -Append -Encoding utf8
Write-Host ''
Write-Host '=== QUEUE DONE — окно можно закрыть ==='

