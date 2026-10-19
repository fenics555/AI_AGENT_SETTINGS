# _gen3.ps1 — v20 = v17 (запрет-строка) + v19 (подсказка направления) в одном
$root = 'D:\AI\AGENT_SETTINGS\checks\agentic'
$g = Get-Content (Join-Path $root '.clinerules_vG') -Raw -Encoding utf8
$A1 = "ШАГ-1. ВЫЗОВ read_file('D:\AI\repo\MANIFEST.md') — первое действие задачи, НЕ текст."
$L17 = "`n     ЗАПРЕЩЕНО завершать/отвечать сразу после ШАГА-1: ОБЯЗАТЕЛЬНО выполни ШАГ-2 (Select-String карты) и ШАГ-3 (read доменного скилла), и ТОЛЬКО ПОТОМ действуй/отвечай."
$L19 = "`n     Определи НАПРАВЛЕНИЕ по ключевым словам задачи (Creo/git/аудит/модель) и ПЕРВЫМ чтением после MANIFEST возьми SKILL_<направление> (напр. Creo->repo\Creo\SKILL_creo_index.md; аудит->repo\AUDIT\SKILL_audit_protocol.md)."
[IO.File]::WriteAllText((Join-Path $root '.clinerules_v20'), $g.Replace($A1, ($A1 + $L17 + $L19)), (New-Object Text.UTF8Encoding($true)))
Write-Host 'v20 создан'
