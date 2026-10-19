$f = 'D:\AI\AGENT_SETTINGS\tmp\watch_live.ps1'
$err = $null
$tokens = $null
[void][System.Management.Automation.Language.Parser]::ParseFile($f, [ref]$tokens, [ref]$err)
if ($err -and $err.Count -gt 0) {
  'ERRORS: ' + $err.Count
  $err | Select-Object -First 5 | ForEach-Object { $_.Message + ' @ line ' + $_.Extent.StartLineNumber }
} else {
  'PARSE OK'
}
