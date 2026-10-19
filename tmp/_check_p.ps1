$L = 'D:\AI\AGENT_SETTINGS\laws'
Write-Host '=== 3 ПРИНЦИПА (law_p1/p2/p3) ==='
foreach ($k in @('p1','p2','p3')) {
  $f = Join-Path $L ('law_' + $k + '.md')
  if (Test-Path $f) {
    $c = Get-Content $f -Encoding utf8 -Raw
    $m0 = if ($c -match 'ЗАКОН УЧИТ РАБОТАТЬ') { 'М0' } else { '--' }
    $m1 = if ($c -match 'ВОПРОС ОПРЕДЕЛЯЕТ ПРЕДМЕТ') { 'П1' } else { '--' }
    $m2 = if ($c -match 'ГРАНИЦЫ ПОИСКА') { 'П2' } else { '--' }
    $sub = if ($c -match 'МАСКА ОБЯЗАТЕЛЬНА') { 'ЕСТЬ-ПОДСКАЗКА' } else { 'без подсказок' }
    $sz = (Get-Item $f).Length
    $ln = (Get-Content $f -Encoding utf8).Count
    Write-Host ('  law_' + $k.PadRight(4) + ' ' + $m0 + ' ' + $m1 + ' ' + $m2 + ' | ' + $sub.PadRight(15) + ' | ' + $sz + ' б / ' + $ln + ' стр')
  }
}
