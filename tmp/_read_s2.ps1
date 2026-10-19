$dir = 'D:\AI\AGENT_SETTINGS\checks\agentic\log'
$files = Get-ChildItem $dir -Filter 'probe3_2026-10-17_0*.txt' | Sort-Object LastWriteTime | Select-Object -First 5
foreach ($f in $files) {
  Write-Host ('=== ' + $f.Name + ' ===')
  $h = Select-String -Path $f.FullName -Pattern 'ЭТАЛОН: 65' -ErrorAction SilentlyContinue
  foreach ($x in $h) {
    $line = $x.Line.Trim()
    if ($line.Length -gt 165) { $line = $line.Substring(0,165) }
    Write-Host ('   ' + $line)
  }
  $c = Select-String -Path $f.FullName -Pattern 'shell \{' -ErrorAction SilentlyContinue
  $n = 0
  foreach ($x in $c) {
    if ($n -lt 3) { $l2 = $x.Line.Trim(); if ($l2.Length -gt 130) { $l2 = $l2.Substring(0,130) }; Write-Host ('   CALL: ' + $l2); $n++ }
  }
}
