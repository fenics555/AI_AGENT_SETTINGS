$s = 'D:\AI\AGENT_SETTINGS\tmp\run_matrix4_20261018_150126_summary.txt'
$rows = @()
foreach ($ln in (Get-Content $s -Encoding UTF8)) {
  if ($ln -notmatch 'RESULT\|') { continue }
  $p = ($ln -replace '^\s+','').Split('|')
  if ($p.Count -lt 6) { continue }
  $law = $p[2] -replace '^R_',''
  $model = $p[3]
  if ($model -match 'gemma') { $model = 'gemma4' }
  elseif ($model -match 'qwen') { $model = 'qwen3.6' }
  elseif ($model -match 'laguna') { $model = 'laguna' }
  elseif ($model -match 'gpt-oss') { $model = 'gpt-oss' }
  else { $model = 'OTHER:' + $model }
  $task = $p[4]; $verdict = $p[5]
  if ($task -notin @('S1_total','S2_creo','S3_prog')) { continue }
  $rows += [pscustomobject]@{ Law=$law; Model=$model; Task=$task; V=$verdict }
}
'ЗОНДОВ: ' + $rows.Count
''
'ВЕРДИКТЫ ПО ВСЕМ:'
$rows | Group-Object V | Sort-Object Count -Descending | ForEach-Object { '  {0,-14} {1}' -f $_.Name, $_.Count }
''
'--- ПО ЗАКОНАМ (OK / всего) ---'
$rows | Group-Object Law | ForEach-Object {
  $ok = @($_.Group | Where-Object { $_.V -eq 'COUNT_OK' }).Count
  '{0,-5} {1}/{2}   {3}' -f $_.Name, $ok, $_.Group.Count, (($_.Group | Group-Object V | ForEach-Object { $_.Name + '=' + $_.Count }) -join ' ')
}
''
'--- ПО МОДЕЛЯМ (OK / всего) ---'
$rows | Group-Object Model | ForEach-Object {
  $ok = @($_.Group | Where-Object { $_.V -eq 'COUNT_OK' }).Count
  '{0,-10} {1}/{2}' -f $_.Name, $ok, $_.Group.Count
}
''
'--- МАТРИЦА (S1/S2) ---'
$laws = @('w2','w6','w9')
$models = @('gemma4','qwen3.6','laguna','gpt-oss')
$f = { param($v) if ($v -eq 'COUNT_OK') { 'OK ' } elseif ($v -eq 'COUNT_WRONG') { 'WRG' } elseif ($v -eq 'FAKE_CALL') { 'FAK' } elseif ($v -eq 'NO_WALK') { 'NW ' } elseif ($v -eq 'NO_ANSWER') { 'NAN' } elseif ($v -eq 'NO_TOOLS') { 'NTL' } elseif ($v -eq 'COUNT_LUCKY') { 'LCK' } else { '?  ' } }
foreach ($l in $laws) {
  $line = '{0,-5}' -f $l
  foreach ($m in $models) {
    $s1 = ($rows | Where-Object { $_.Law -eq $l -and $_.Model -eq $m -and $_.Task -eq 'S1_total' } | Select-Object -First 1).V
    $s2 = ($rows | Where-Object { $_.Law -eq $l -and $_.Model -eq $m -and $_.Task -eq 'S2_creo' } | Select-Object -First 1).V
    $line += ' | ' + $m.PadRight(8) + (& $f $s1) + '/' + (& $f $s2)
  }
  $line
}
