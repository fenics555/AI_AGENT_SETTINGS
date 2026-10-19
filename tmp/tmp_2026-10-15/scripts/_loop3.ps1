# _loop3.ps1 — проверка победителя v17: эталон gemma4 + генерализация (T12b, laguna, P2g_tool)
$root = 'D:\AI\AGENT_SETTINGS\checks\agentic'
function R3($rs, $m, $t) { $h = @{ Rulesets = $rs; Models = $m; OnlyTasks = $t }; & (Join-Path $root 'probe_3_rules_skills.ps1') @h }
function R2($rs, $m, $t) { $h = @{ Rulesets = $rs; Models = $m; OnlyTasks = $t }; & (Join-Path $root 'probe_2_tools.ps1') @h }
Write-Host '### v17 gemma4 T12c (эталон)'; R3 '17' 'gemma4' 'T12c'
Write-Host '### v17 gpt-oss T12b';          R3 '17' 'gpt-oss' 'T12b'
Write-Host '### v17 laguna T12c';           R3 '17' 'laguna' 'T12c'
Write-Host '### v17 gpt-oss P2g_tool';      R2 '17' 'gpt-oss' 'P2g_tool'
Write-Host 'LOOP3 DONE'
