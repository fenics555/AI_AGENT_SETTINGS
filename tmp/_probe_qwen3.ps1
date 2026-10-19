# _probe_qwen3.ps1 - какие законы/окна были в прогонах qwen3 (тест 3)
$dir = 'D:\AI\AGENT_SETTINGS\checks\agentic\log'
$names = @(
 'probe3_2026-10-16_002422','probe3_2026-10-16_003806','probe3_2026-10-16_005348',
 'probe3_2026-10-16_010903','probe3_2026-10-16_082817','probe3_2026-10-16_153154',
 'probe3_2026-10-16_165633','probe3_2026-10-16_192231'
)
foreach ($n in $names) {
  $f = Join-Path $dir ($n + '.log')
  if (Test-Path $f) {
    $line = (Get-Content $f -Encoding utf8 | Select-Object -First 2) -join ' || '
    Write-Host ($n.Substring(19) + ' | ' + $line.Trim())
  } else {
    Write-Host ($n.Substring(19) + ' | НЕТ ЛОГА')
  }
}
