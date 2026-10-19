# _gen_variants.ps1 — генерит 16 вариантов правил (.clinerules_v01..v16) из живого G (одна правка на вариант)
$root = 'D:\AI\AGENT_SETTINGS\checks\agentic'
$g = Get-Content (Join-Path $root '.clinerules_vG') -Raw -Encoding utf8
$A2 = "ШАГ-2. КАРТА: ВЫЗОВ shell Select-String -Path 'D:\AI\repo\SKILL_index.md' -Pattern '<ключ задачи>'"
$A3 = "ШАГ-3. ВЫЗОВ read_file ТОГО скилла, что нашла карта. Только ПОСЛЕ этого — сама задача/поиск файлов."
$AL = "3.Л. ЛЁГКИЙ (вопрос; чтение 1 файла; 1 команда; мета; генерация в чате):"
$AG = "  - git (commit/push/rebase/merge/staged/HEAD) -> SKILL_parallel_legs.md."
$A1 = "ШАГ-1. ВЫЗОВ read_file('D:\AI\repo\MANIFEST.md') — первое действие задачи, НЕ текст."
$AP3 = "3.П.3. БЮДЖЕТ: обязательные чтения > 50% num_ctx -> SKILL_index.md по ключам (Select-String), critical —"
$AP2 = "3.П.2. ПОИСК ИНСТРУМЕНТА: (1) направление по SKILL_index.md (Select-String); (2) реестр инструментов —"

$variants = @(
  @{ id='v01'; a=$AP2; n=($AP2 + "`n   ПЕРВЫМ делом для задач про инструменты/механизмы дома — read_file реестра tools\agent\README.md.") }
  @{ id='v02'; a=$A3;  n='ШАГ-3. ОБЯЗАТЕЛЬНО read_file ДОМЕННОГО скилла. Если прочитал ТОЛЬКО карту (SKILL_index) — задача ПРОВАЛЕНА.' }
  @{ id='v03'; a=$AL;  n='3.Л. ЛЁГКИЙ — ПРИМЕНЯТЬ ШИРЕ (вопрос; чтение 1 файла; 1 команда; мета; генерация в чате) — 3 шага §3.П НЕ гонять:' }
  @{ id='v04'; a=$A2;  n="ШАГ-2. ВЫЗОВ shell: powershell -NoProfile -File D:\AI\repo\INDEX\find_skill.ps1 -Query '<ключ задачи>' -Top 5 (ПОИСК ПО СМЫСЛУ вместо Select-String)." }
  @{ id='v05'; a=$A1;  n="ШАГ-1. Если направление УЖЕ названо в задаче (Creo/git/аудит/модель) — MANIFEST не читать, сразу ШАГ-2. Иначе read_file('D:\AI\repo\MANIFEST.md')." }
  @{ id='v06'; a=$AG;  n=($AG + "`n    ЛЮБОЕ упоминание git -> СТОП и read_file SKILL_parallel_legs.md ЦЕЛИКОМ ДО любых команд.") }
  @{ id='v07'; a=$AP2; n=($AP2 + "`n   В ответе — ТОЛЬКО точное ИМЯ ФАЙЛА инструмента из реестра, без пояснений.") }
  @{ id='v08'; a=$AP3; n=($AP3 + "`n   НА ЗАДАЧУ <= 8 вызовов инструментов; после 2 поисков — принимай решение.") }
  @{ id='v09'; a=$A3;  n="ШАГ-3. Прочти скилл ПО НАПРАВЛЕНИЮ: Creo->repo\Creo\SKILL_creo_index.md; git->SKILL_parallel_legs.md; аудит/чистка->repo\AUDIT\SKILL_audit_protocol.md; модель->SKILL_models_behavior.md." }
  @{ id='v10'; a=$A2;  n=($A2 + "`n     ПРИМЕР-2 (аудит): read_file MANIFEST; shell Select-String SKILL_index 'аудит'; read_file repo\AUDIT\SKILL_audit_protocol.md; выполнять.") }
  @{ id='v11'; a=$AP3; n='3.П.3. SKILL_index ЦЕЛИКОМ читать ЗАПРЕЩЕНО (26 КБ) — ТОЛЬКО Select-String по ключам; budget в [START:].' }
  @{ id='v12'; a=$A3;  n=($A3 + ' Если задача требует инструмент — СНАЧАЛА вызов, потом объяснение.') }
  @{ id='v13'; a=$AP2; n='3.П.2. ПОИСК: Select-String по SKILL_index -> read_file доменного скилла; инструменты дома — реестр tools\agent\README.md. Не нашёл — по корням, НЕ сдаваться.' }
  @{ id='v14'; a=$AL;  n=($AL + "`n     ОТВЕТ: с действием — только ФАКТ (путь/имя), без пояснений.") }
  @{ id='v15'; a=$A3;  n='ШАГ-3. Прочитав скилл, ПЕРЕЧИТАЙ его перед выполнением (памяти о чтении нет).' }
  @{ id='v16'; a=$A2;  n=($A2 + "`n     Если 2 поиска не дали скилл — смени способ (реестр/корни), НЕ повторяй тот же запрос.") }
)
$ok = 0
foreach ($v in $variants) {
    if ($g -notlike ('*' + $v.a + '*')) { Write-Host ("НЕТ ЯКОРЯ: " + $v.id); continue }
    $txt = $g.Replace($v.a, $v.n)
    [IO.File]::WriteAllText((Join-Path $root ('.clinerules_' + $v.id)), $txt, (New-Object Text.UTF8Encoding($true)))
    $ok++
}
Write-Host ("Создано вариантов: $ok из " + $variants.Count)
Get-ChildItem $root -Filter '.clinerules_v0*' -Force | Select-Object -ExpandProperty Name
