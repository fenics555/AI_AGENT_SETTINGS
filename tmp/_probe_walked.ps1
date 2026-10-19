# _probe_walked.ps1 - почему $walked=False для команды qwen3
$cmd = "(Get-ChildItem 'D:\AI\repo\Prog' -Recurse -File -Filter 'SKILL_*.md').Count"
Write-Host ("CMD: " + $cmd)
$h1 = $cmd -match '(?i)Get-ChildItem|gci\b|\bdir\b|ChildItem\s+-Path'
$h2 = $cmd -match '(?i)SKILL_index|\.md''\s*\)\s*-Pattern'
Write-Host ("  match Get-ChildItem     : $h1")
Write-Host ("  match EXCLUDE-regex     : $h2")
Write-Host ("  walked = h1 -and -not h2: " + ($h1 -and (-not $h2)))

# и вторая команда gemma4 (252) для сравнения
$cmd2 = "(Get-ChildItem 'D:\AI\repo\Creo' -Recurse -File).Count"
Write-Host ("`nCMD2: " + $cmd2)
$g1 = $cmd2 -match '(?i)Get-ChildItem|gci\b|\bdir\b|ChildItem\s+-Path'
$g2 = $cmd2 -match '(?i)SKILL_index|\.md''\s*\)\s*-Pattern'
Write-Host ("  walked = " + ($g1 -and (-not $g2)))
