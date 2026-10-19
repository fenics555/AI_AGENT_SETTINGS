# _test_shellfix.ps1 — ПРОВЕРКА ФИКСА probe_tools (РЫЧАГ 38): вложенный powershell не должен ломать вывод
$ErrorActionPreference = 'Continue'
. 'D:\AI\AGENT_SETTINGS\tools\probe_tools.ps1'

$sandbox = 'D:\AI\PROBA'
# эмулируем то, что делает обёртка: та же логика снятия внешнего слоя
function Run-ShellCmd([string]$cmd) {
  $inner = $null
  if ($cmd -match '(?is)^\s*powershell(\.exe)?\s+(-NoProfile\s+)?-Command\s+["'']?(.*?)["'']?\s*$') {
    $inner = $Matches[3].Trim()
    if ($inner.StartsWith('"') -and $inner.EndsWith('"') -and $inner.Length -gt 2) { $inner = $inner.Substring(1, $inner.Length - 2) }
    elseif ($inner.StartsWith("'") -and $inner.EndsWith("'") -and $inner.Length -gt 2) { $inner = $inner.Substring(1, $inner.Length - 2) }
  }
  $useCmd = if ($inner) { $inner } else { $cmd }
  $sb = [ScriptBlock]::Create("Set-Location -LiteralPath '$sandbox'; " + $useCmd)
  return (& $sb 2>&1 | Out-String)
}

'=== ПРОБА 1: команда gpt-oss (была 446) ==='
$cmd1 = 'powershell -Command "Get-ChildItem -Recurse -Filter ''SKILL_*.md'' -Path ''D:\AI\repo'' | Measure-Object | Select-Object -ExpandProperty Count"'
$r1 = (Run-ShellCmd $cmd1).Trim()
'результат: [' + $r1 + ']   ожидание: 199   ' + $(if ($r1 -eq '199') { 'PASS' } else { 'FAIL' })

'=== ПРОБА 2: чистая команда без обёртки (должна остаться 199) ==='
$cmd2 = 'Get-ChildItem -Recurse -Filter ''SKILL_*.md'' -Path ''D:\AI\repo'' | Measure-Object | Select-Object -ExpandProperty Count'
$r2 = (Run-ShellCmd $cmd2).Trim()
'результат: [' + $r2 + ']   ожидание: 199   ' + $(if ($r2 -eq '199') { 'PASS' } else { 'FAIL' })

'=== ПРОБА 3: Creo (эталон 65) ==='
$cmd3 = 'powershell -Command "Get-ChildItem -Recurse -Filter ''SKILL_*.md'' -Path ''D:\AI\repo\Creo'' | Measure-Object | Select-Object -ExpandProperty Count"'
$r3 = (Run-ShellCmd $cmd3).Trim()
'результат: [' + $r3 + ']   ожидание: 65   ' + $(if ($r3 -eq '65') { 'PASS' } else { 'FAIL' })
