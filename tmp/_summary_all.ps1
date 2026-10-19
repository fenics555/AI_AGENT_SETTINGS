$tmp = 'D:\AI\AGENT_SETTINGS\tmp'
Write-Host '=== ТЕСТ 3 ==='
Get-ChildItem $tmp -Filter 'run_princ*_summary.txt' | Sort-Object LastWriteTime | ForEach-Object {
  Get-Content $_.FullName -Encoding utf8 | Where-Object { $_ -match '^RESULT\|probe3\|' } | ForEach-Object {
    $p = $_.Split('|')
    Write-Host ('  ' + $p[2].PadRight(6) + ' | ' + $p[3].Substring(0,[Math]::Min(13,$p[3].Length)).PadRight(14) + ' | ' + $p[4].PadRight(9) + ' | ' + $p[5])
  }
}
Write-Host ''
Write-Host '=== ТЕСТ 4 ==='
Get-ChildItem $tmp -Filter 'run_princ*_summary.txt' | Sort-Object LastWriteTime | ForEach-Object {
  Get-Content $_.FullName -Encoding utf8 | Where-Object { $_ -match '^RESULT\|probe4\|' } | ForEach-Object {
    $p = $_.Split('|')
    Write-Host ('  ' + $p[2].PadRight(6) + ' | ' + $p[3].Substring(0,[Math]::Min(13,$p[3].Length)).PadRight(14) + ' | ' + $p[4].PadRight(11) + ' | ' + $p[5])
  }
}
