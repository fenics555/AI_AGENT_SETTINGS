$dir = 'D:\AI\AGENT_SETTINGS\checks\agentic\log'
$files = Get-ChildItem $dir -Filter 'probe3_2026-10-17_13*.txt' | Where-Object { $_.Name -notmatch 'trace' } | Sort-Object LastWriteTime
foreach ($f in $files) {
  $sur = Select-String -Path $f.FullName -Pattern '^RESULT\|\w+\|R_A\|[^|]+\|SURVEY\|survey\|' -ErrorAction SilentlyContinue
  foreach ($s in $sur) {
    $line = $s.Line
    $idx = $line.IndexOf('|survey|')
    Write-Host ('==================================================')
    Write-Host ('ФАЙЛ: ' + $f.Name)
    Write-Host ('--- SURVEY (полный ответ) ---')
    if ($idx -ge 0) {
      $txt = $line.Substring($idx + 8)
      Write-Host $txt
    } else {
      Write-Host $line
    }
    Write-Host ''
  }
}
