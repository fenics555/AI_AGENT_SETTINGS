$dir = 'D:\AI\AGENT_SETTINGS\checks\agentic\log'
$files = Get-ChildItem $dir -Filter 'probe3_2026-10-17_13*.txt' | Where-Object { $_.Name -notmatch 'trace' } | Sort-Object LastWriteTime
foreach ($f in $files) {
  $c = Get-Content $f.FullName -Encoding utf8 -Raw
  $i = $c.IndexOf('ОПРОС МОДЕЛИ В КОНЦЕ')
  Write-Host ('##########################################################')
  Write-Host ('ФАЙЛ: ' + $f.Name)
  if ($i -ge 0) {
    # берём от ОПРОСА до конца блока (перед следующей '####' или концом)
    $rest = $c.Substring($i)
    $end = $rest.IndexOf('############')
    if ($end -gt 60) { $rest = $rest.Substring(0, $end) }
    Write-Host $rest
  } else { Write-Host '(ОПРОС не найден)' }
  Write-Host ''
}
