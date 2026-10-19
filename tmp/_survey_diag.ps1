$dir = 'D:\AI\AGENT_SETTINGS\checks\agentic\log'
Write-Host '=== РАЗМЕР БЛОКА ОПРОСА В КАЖДОМ ЛОГЕ ==='
$files = Get-ChildItem $dir -Filter 'probe3_2026-10-17_13*.txt' | Where-Object { $_.Name -notmatch 'trace' } | Sort-Object LastWriteTime
foreach ($f in $files) {
  $c = Get-Content $f.FullName -Encoding utf8 -Raw
  $i = $c.IndexOf('ОПРОС МОДЕЛИ')
  $len = -1
  if ($i -ge 0) { $len = $c.Length - $i }
  Write-Host ('  ' + $f.Name + ' : блок = ' + $len + ' симв.')
}
Write-Host ''
Write-Host '=== ВЫЗОВЫ В TRACE ПОСЛЕ ПОСЛЕДНЕЙ ЗАДАЧИ (S3->SURVEY) ==='
$tr = Get-ChildItem $dir -Filter 'probe3_trace_2026-10-17_13*.jsonl' | Sort-Object LastWriteTime
foreach ($t in $tr) {
  $lines = Get-Content $t.FullName -Encoding utf8
  $lastTask = ''
  if ($lines.Count -gt 0) {
    $ll = $lines[-1]
    if ($ll -match '\{"task":"([^"]+)"') { $lastTask = $Matches[1] }
  }
  Write-Host ('  ' + $t.Name + ' | последняя задача в trace: ' + $lastTask + ' | вызовов: ' + $lines.Count)
}
