$live = (Get-FileHash 'D:\AI\.clinerules' -Algorithm SHA256).Hash
Write-Host ('ЖИВОЙ: ' + (Get-Item 'D:\AI\.clinerules').Length + ' б, SHA ' + $live.Substring(0,16))
Get-ChildItem 'D:\AI\AGENT_SETTINGS\laws' -Filter 'law_*.md' | Sort-Object Name | ForEach-Object {
  $sha = (Get-FileHash $_.FullName -Algorithm SHA256).Hash
  $same = if ($sha -eq $live) { '=ЖИВОЙ' } else { 'ИЗМЕНЁН' }
  $lines = (Get-Content $_.FullName -Encoding utf8).Count
  Write-Host ('  ' + $_.Name.PadRight(11) + ' ' + $_.Length.ToString().PadLeft(6) + ' б ' + $lines.ToString().PadLeft(4) + ' стр  ' + $same)
}

'ЖИВОЙ: ' + (Get-Item 'D:\AI\.clinerules').Length + ' б, SHA ' + $live.Substring(0,16)
Get-ChildItem 'D:\AI\AGENT_SETTINGS\laws' -Filter 'law_*.md' | Sort-Object Name | ForEach-Object {
  $sha = (Get-FileHash $_.FullName -Algorithm SHA256).Hash
  $same = if ($sha -eq $live) { '=ЖИВОЙ' } else { 'ИЗМЕНЁН' }
  $lines = (Get-Content $_.FullName -Encoding utf8).Count
  Write-Host ('  ' + $_.Name.PadRight(11) + ' ' + $_.Length.ToString().PadLeft(6) + ' б ' + $lines.ToString().PadLeft(4) + ' стр  ' + $same)
}
