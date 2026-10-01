<#
  Creates "strict" copies of every locally installed Ollama model.

  What it changes:  sampling only (temperature / top_p / min_p / repeat_penalty).
  What it does NOT change: weights, quantization, GPU offload, MTP draft layer
  (all inherited from "FROM <model>"), so generation speed stays the same.

  Usage:
    powershell -ExecutionPolicy Bypass -File .\New-StrictModels.ps1
    powershell -ExecutionPolicy Bypass -File .\New-StrictModels.ps1 -Skip nomic-embed-text,gpt-oss:20b
    powershell -ExecutionPolicy Bypass -File .\New-StrictModels.ps1 -Temperature 0.2 -TopP 0.85
#>
[CmdletBinding()]
param(
  [string[]]$Skip = @('nomic-embed-text'),
  [string]$OllamaHost = '127.0.0.1:11434',
  [double]$Temperature = 0.3,
  [double]$TopP = 0.9,
  [double]$MinP = 0.05,
  [double]$RepeatPenalty = 1.05
)

$ErrorActionPreference = 'Stop'
$env:OLLAMA_HOST = $OllamaHost

$tmpDir = Join-Path $PSScriptRoot 'modelfiles'
New-Item -ItemType Directory -Path $tmpDir -Force | Out-Null

$names = foreach ($line in (& ollama list | Select-Object -Skip 1)) {
  $t = ($line -replace '\s+', ' ').Trim()
  if ($t) { ($t -split ' ')[0] }
}

$created = New-Object System.Collections.Generic.List[string]
foreach ($m in $names) {
  if (-not $m) { continue }
  if ($m -match 'strict') { continue }
  if ($Skip | Where-Object { $m -eq $_ -or $m -like "$_*" }) { continue }

  $target = "$m-strict"
  $file = Join-Path $tmpDir (($m -replace '[:/\\]', '_') + '.Modelfile')
  @(
    "FROM $m",
    "PARAMETER temperature $Temperature",
    "PARAMETER top_p $TopP",
    "PARAMETER min_p $MinP",
    "PARAMETER repeat_penalty $RepeatPenalty"
  ) | Set-Content -Path $file -Encoding ascii

  Write-Host "=== $m -> $target"
  & ollama create $target -f $file
  $created.Add($target)
}

Write-Host ""
Write-Host ("Created: " + ($created -join ', '))
& ollama list
