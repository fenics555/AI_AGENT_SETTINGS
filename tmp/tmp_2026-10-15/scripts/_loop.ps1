# _loop.ps1 — БЫСТРЫЙ ЦИКЛ ПРАВОК: целевые пробы по узлам на слабых моделях (по одному правилу)
$root = 'D:\AI\AGENT_SETTINGS\checks\agentic'
$tests = @(
    @{ probe='2'; rs='01'; tasks='P2g_tool'; models='nemotron,laguna' },   # v01 Реестр-первым
    @{ probe='2'; rs='07'; tasks='P2g_tool'; models='nemotron' },          # v07 Только имя
    @{ probe='2'; rs='13'; tasks='P2g_tool'; models='nemotron' },          # v13 Короче поиск
    @{ probe='3'; rs='04'; tasks='T12c';     models='nemotron' },          # v04 Индекс
    @{ probe='3'; rs='09'; tasks='T12c';     models='nemotron' },          # v09 Домен по направлению
    @{ probe='3'; rs='10'; tasks='T12c';     models='nemotron' },          # v10 Few-shot аудит
    @{ probe='3'; rs='15'; tasks='T12c';     models='nemotron' },          # v15 Перечитать скилл
    @{ probe='3'; rs='16'; tasks='T12c';     models='nemotron' },          # v16 Смена способа
    @{ probe='3'; rs='06'; tasks='T12b';     models='nemotron' },          # v06 git безусловный
    @{ probe='1'; rs='03'; tasks='all';      models='laguna' }             # v03 Лёгкий старт (поведение)
)
foreach ($t in $tests) {
    $script = if ($t.probe -eq '2') { 'probe_2_tools.ps1' } elseif ($t.probe -eq '3') { 'probe_3_rules_skills.ps1' } else { 'probe_1_behavior.ps1' }
    foreach ($m in ($t.models -split ',')) {
        $h = @{ Rulesets = $t.rs; Models = $m }
        if ($t.tasks -ne 'all') { $h['OnlyTasks'] = $t.tasks }
        Write-Host ("### probe$($t.probe) rs=$($t.rs) task=$($t.tasks) model=$m") -ForegroundColor Cyan
        & (Join-Path $root $script) @h
    }
}
Write-Host 'LOOP DONE'
