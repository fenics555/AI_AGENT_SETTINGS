# _gen2.ps1 — рычаги v17..v19 (форсировать продолжение маршрута после MANIFEST)
$root = 'D:\AI\AGENT_SETTINGS\checks\agentic'
$g = Get-Content (Join-Path $root '.clinerules_vG') -Raw -Encoding utf8
$A1 = "ШАГ-1. ВЫЗОВ read_file('D:\AI\repo\MANIFEST.md') — первое действие задачи, НЕ текст."
$v = @(
  @{ id='v17'; a=$A1; n=($A1 + "`n     ЗАПРЕЩЕНО завершать/отвечать сразу после ШАГА-1: ОБЯЗАТЕЛЬНО выполни ШАГ-2 (Select-String карты) и ШАГ-3 (read доменного скилла), и ТОЛЬКО ПОТОМ действуй/отвечай.") }
  @{ id='v18'; a=$A1; n="ШАГ-1. read_file('D:\AI\repo\MANIFEST.md'); ШАГ-2. shell Select-String SKILL_index <ключ>; ШАГ-3. read_file найденного скилла; ЗАТЕМ ДЕЙСТВУЙ. Без ВСЕХ ТРЁХ вызовов задача НЕ начата (ответ/завершение после ШАГА-1 = ПРОВАЛ)." }
  @{ id='v19'; a=$A1; n=($A1 + "`n     Определи НАПРАВЛЕНИЕ по ключевым словам задачи (Creo/git/аудит/модель) и ПЕРВЫМ чтением после MANIFEST возьми SKILL_<направление> (напр. Creo->repo\Creo\SKILL_creo_index.md; аудит->repo\AUDIT\SKILL_audit_protocol.md).") }
)
$ok=0
foreach ($x in $v) { if ($g -notlike ('*'+$x.a+'*')) { Write-Host ('нет якоря '+$x.id); continue }; [IO.File]::WriteAllText((Join-Path $root ('.clinerules_'+$x.id)), $g.Replace($x.a,$x.n), (New-Object Text.UTF8Encoding($true))); $ok++ }
Write-Host ("создано: $ok")
