$s = 'D:\AI\AGENT_SETTINGS\tmp\run_matrix_20261018_095458_summary.txt'
$rows = @()
foreach ($ln in (Get-Content $s -Encoding UTF8)) {
  if ($ln -notmatch 'RESULT\|') { continue }
  $p = ($ln -replace '^\s+','').Split('|')
  # RESULT|probe3|R_w6|gemma4:26b|S1_total|COUNT_OK||...
  if ($p.Count -lt 6) { continue }
  $law = $p[2] -replace '^R_',''
  $model = $p[3]
  if ($model -match 'gemma') { $model = 'gemma4' }
  elseif ($model -match 'qwen') { $model = 'qwen3.6' }
  elseif ($model -match 'laguna') { $model = 'laguna' }
  else { $model = 'OTHER:' + $model }
  $task = $p[4]
  $verdict = $p[5]
  if ($task -notin @('S1_total','S2_creo','S3_prog')) { continue }
  $rows += [pscustomobject]@{ Law=$law; Model=$model; Task=$task; V=$verdict }
}
'ВСЕГО ЗОНДОВ: ' + $rows.Count
''
'--- ПО ЗАКОНАМ (COUNT_OK / всего) ---'
$rows | Group-Object Law | ForEach-Object {
  $ok = @($_.Group | Where-Object { $_.V -eq 'COUNT_OK' }).Count
  $tot = $_.Group.Count
  '{0,-6} {1}/{2}   {3}' -f $_.Name, $ok, $tot, (($_.Group | Group-Object V | ForEach-Object { $_.Name + '=' + $_.Count }) -join ' ')
}
''
'--- ПО МОДЕЛЯМ ---'
$rows | Group-Object Model | ForEach-Object {
  $ok = @($_.Group | Where-Object { $_.V -eq 'COUNT_OK' }).Count
  '{0,-12} {1}/{2}' -f $_.Name, $ok, $_.Group.Count
}
''
'--- МАТРИЦА закон x модель (S1/S2) ---'
$laws = @('w2','w6','w7','w8','w9','w10')
$models = @('gemma4','qwen3.6','laguna')
foreach ($l in $laws) {
  $line = '{0,-5}' -f $l
  foreach ($m in $models) {
    $s1 = ($rows | Where-Object { $_.Law -eq $l -and $_.Model -eq $m -and $_.Task -eq 'S1_total' } | Select-Object -First 1).V
    $s2 = ($rows | Where-Object { $_.Law -eq $l -and $_.Model -eq $m -and $_.Task -eq 'S2_creo' } | Select-Object -First 1).V
    $f = { param($v) if ($v -eq 'COUNT_OK') { 'OK ' } elseif ($v -eq 'COUNT_WRONG') { 'WRG' } elseif ($v -eq 'FAKE_CALL') { 'FAK' } elseif ($v -eq 'NO_WALK') { 'NW ' } else { '?  ' } }
    $line += ' | ' + $m + ' ' + (& $f $s1) + '/' + (& $f $s2)
  }
  $line
}
