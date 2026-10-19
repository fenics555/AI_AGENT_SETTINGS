# _probe_rx.ps1 - проверка нового регекса $anySkillRx на реальных файлах
$anySkillRx = '(?i)(SKILL_[a-z0-9_\-]+\.md|SKILL_[a-z0-9_\-]*index)'
$files = @(
  'D:\AI\repo\Creo\COPY\SKILL_copy_rename.md',
  'D:\AI\repo\SKILL_index.md',
  'D:\AI\repo\Creo\CREOSON\SKILL_creoson_rename_mechanism.md',
  'D:\AI\repo\AUDIT\SKILL_probe_marker.md',
  'D:\AI\repo\MANIFEST.md'
)
foreach ($f in $files) {
  $isMap  = $f -match '(?i)SKILL_index'
  $isSkill = ($f -match $anySkillRx) -and (-not $isMap)
  $leaf = Split-Path $f -Leaf
  Write-Host ("  {0,-45} map={1,-6} skillHit={2}" -f $leaf, $isMap, $isSkill)
}
