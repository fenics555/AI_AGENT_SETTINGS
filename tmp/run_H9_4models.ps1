# Драйвер: ТОЛЬКО H9 на 4 моделях (gemma4, qwen, laguna, gpt-oss), тест 3.
# ВИДИМОЕ ОКНО ХРОНОЛОГИИ (§6.1): ход теста печатается прямо в окно.
# ЗАКОН ПРАВИТЬ НЕЛЬЗЯ (§6.0) — гоняем ТОЛЬКО КОПИЮ laws\law_H9.md.
$root   = 'D:\AI\AGENT_SETTINGS\checks\agentic'
$tmp    = 'D:\AI\AGENT_SETTINGS\tmp'
$seed   = 42
$lawKey = 'H9'
$modelsList = @('gemma4', 'qwen', 'laguna', 'gpt-oss')
$summary = Join-Path $tmp 'run_H9_4models_summary.txt'
"=== H9 (копия закона) — ТЕСТ 3 на 4 моделях  START $(Get-Date -Format 'HH:mm:ss') ===" | Out-File $summary -Encoding utf8
$lp = Join-Path 'D:\AI\AGENT_SETTINGS\laws' ('law_' + $lawKey + '.md')
"ЗАКОН: $lp ($((Get-Item $lp).Length) б)" | Out-File $summary -Append -Encoding utf8

foreach ($m in $modelsList) {
    $t0 = Get-Date
    Write-Host ''
    Write-Host ("################ МОДЕЛЬ: $m  (закон H9)  START " + $t0.ToString('HH:mm:ss'))
    Start-Process -FilePath 'powershell' `
        -ArgumentList @('-NoProfile','-ExecutionPolicy','Bypass','-File',(Join-Path $root 'check_3_skills_avail.ps1'),
                        '-Models',$m,'-Rulesets',$lawKey,'-Seed',$seed) `
        -WorkingDirectory $root -NoNewWindow -Wait
    $el = [math]::Round(((Get-Date) - $t0).TotalMinutes, 1)
    $latest = Get-ChildItem (Join-Path $root 'log') -Filter 'probe3_*.txt' -ErrorAction SilentlyContinue |
              Sort-Object LastWriteTime -Descending | Select-Object -First 1
    Write-Host ("### МОДЕЛЬ $m DONE in $el min | лог: $($latest.Name)")
    $lines = if ($latest) { @(Get-Content $latest.FullName -Encoding utf8 | Where-Object { $_ -match 'RESULT\|probe3|ОТВЕТ МОДЕЛИ|VERDICT' }) } else { @() }
    $lines | ForEach-Object { Write-Host $_ }
    "--- МОДЕЛЬ $m done in $el min | лог: $($latest.Name) ---" | Out-File $summary -Append -Encoding utf8
    $lines | Out-File $summary -Append -Encoding utf8
}
"=== ALL DONE $(Get-Date -Format 'HH:mm:ss') ===" | Out-File $summary -Append -Encoding utf8
Write-Host ''
Write-Host '=== QUEUE DONE — окно можно закрыть ==='
