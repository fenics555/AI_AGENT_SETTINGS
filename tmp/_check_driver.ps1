$d = 'D:\AI\AGENT_SETTINGS\tmp\run_5laws.ps1'
Write-Host ('есть: ' + (Test-Path $d))
if (Test-Path $d) {
  $e = $null
  [void][System.Management.Automation.Language.Parser]::ParseFile($d, [ref]$null, [ref]$e)
  Write-Host ('ParseFile err=' + $e.Count)
  $bytes = [System.IO.File]::ReadAllBytes($d)
  Write-Host ('BOM: ' + ($bytes[0..2] -join ','))
  Write-Host ('размер: ' + (Get-Item $d).Length)
  Write-Host '--- ключевые строки ---'
  Get-Content $d -Encoding utf8 | Select-String -Pattern 'laws = @|MODELS:|ETALON|JOBS' | ForEach-Object { '  ' + $_.Line.Trim() }
}

