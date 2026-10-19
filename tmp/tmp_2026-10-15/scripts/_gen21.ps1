# _gen21.ps1 — чистая ветка v21 = G + рычаг v17 (строка-ЗАПРЕТ после ШАГА-1)
$root = 'D:\AI\AGENT_SETTINGS\checks\agentic'
$g = Get-Content (Join-Path $root '.clinerules_vG') -Raw -Encoding utf8
$A1 = "ШАГ-1. ВЫЗОВ read_file('D:\AI\repo\MANIFEST.md') — первое действие задачи, НЕ текст."
$N1 = $A1 + "`n     ЗАПРЕЩЕНО завершать/отвечать сразу после ШАГА-1: ОБЯЗАТЕЛЬНО выполни ШАГ-2 (Select-String карты) и ШАГ-3 (read доменного скилла), и ТОЛЬКО ПОТОМ действуй/отвечай."
[IO.File]::WriteAllText((Join-Path $root '.clinerules_v21'), $g.Replace($A1, $N1), (New-Object Text.UTF8Encoding($true)))
Write-Host 'v21 created'
