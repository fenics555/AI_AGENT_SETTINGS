$dir = 'D:\AI\AGENT_SETTINGS\laws'
Write-Host '=== СОСТАВ НОВЫХ ВАРИАНТОВ (какие правки внутри) ==='
foreach ($k in @('4','5','9','10','11','12','13')) {
  $f = Join-Path $dir ('law_' + $k + '.md')
  if (Test-Path $f) {
    $c = Get-Content $f -Encoding utf8 -Raw
    $mask = if ($c -match 'МАСКА ОБЯЗАТЕЛЬНА') { 'МАСКА' } else { '-' }
    $noai = if ($c -match "ЗАПРЕЩЕНО: -Recurse от 'D:\\\\AI'") { 'НЕТ-ОБХОДА' } else { '-' }
    $read = if ($c -match 'ОБЯЗАТЕЛЬНО read_file') { 'ЧИТАЙ-СКИЛЛ' } else { '-' }
    $loop = if ($c -match 'НЕ повторяй его') { 'АНТИ-ПЕТЛЯ' } else { '-' }
    $lines = (Get-Content $f -Encoding utf8).Count
    Write-Host ('  law_' + $k.PadRight(3) + ' ' + $mask.PadRight(18) + $noai.PadRight(14) + $read.PadRight(13) + $loop.PadRight(12) + '(' + $lines + ' стр)')
  } else { Write-Host ('  law_' + $k + ' НЕТ') }
}
