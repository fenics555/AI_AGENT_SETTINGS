<#
  Apply-AgentParams.ps1
  Applies sampling parameters from config\behavior.json to LOCAL Ollama models
  by re-creating the SAME tag (in-place update, no duplicate "-strict" twins).

  Nothing except PARAMETER lines is changed: the script starts from
  "ollama show <model> --modelfile", keeps FROM/DRAFT/TEMPLATE/RENDERER/PARSER/
  LICENSE as-is and rewrites only the managed parameters. Therefore weights,
  quantization, GPU offload and MTP speculative decoding (speed) stay intact.

  On the first run the pristine Modelfile of each model is saved to backup\,
  so -Restore can always bring the author defaults back.

  Usage:
    powershell -ExecutionPolicy Bypass -File Apply-AgentParams.ps1                 # activePreset, all models
    powershell ... -Preset creative
    powershell ... -Model gemma4:12b -Preset strict
    powershell ... -DryRun                                                         # show what would change
    powershell ... -Restore -Model gemma4:12b                                      # back to saved defaults
    powershell ... -SystemPrompt                                                   # also inject SYSTEM from behavior.md
#>
[CmdletBinding()]
param(
  [string]$Config,
  [string]$Preset,
  [string[]]$Model,
  [switch]$DryRun,
  [switch]$Restore,
  [switch]$SystemPrompt
)

$ErrorActionPreference = 'Stop'

# allow both "-Model a,b" (when started via powershell -File) and repeated "-Model a -Model b"
$Model = @($Model | ForEach-Object { ([string]$_ -split ',') } | ForEach-Object { $_.Trim() } | Where-Object { $_ })

$root = Split-Path -Parent $PSScriptRoot
if (-not $Config) { $Config = Join-Path $root 'config\behavior.json' }
$backupDir = Join-Path $root 'backup'
$logDir = Join-Path $root 'log'
$workDir = Join-Path $env:TEMP ('ollama_params_' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Force -Path $backupDir, $logDir, $workDir | Out-Null

$logFile = Join-Path $logDir ('apply_' + (Get-Date -Format 'yyyyMMdd_HHmmss') + '.log')
function Say([string]$msg) {
  $t = '{0} {1}' -f (Get-Date -Format 'HH:mm:ss'), $msg
  Write-Host $t
  Add-Content -Path $logFile -Value $t -Encoding UTF8
}
function FileName([string]$model) { ($model -replace '[:/\\]', '_') }

$cfg = Get-Content $Config -Raw -Encoding UTF8 | ConvertFrom-Json
$env:OLLAMA_HOST = $cfg.host

function Get-NamedValue($collection, [string]$name) {
  foreach ($item in $collection.PSObject.Properties) {
    if ($item.Name -eq $name) { return $item.Value }
  }
  return $null
}

$presetName = if ($Preset) { [string]$Preset } else { [string]$cfg.activePreset }
$presetObj = Get-NamedValue $cfg.presets $presetName
if ($null -eq $presetObj) { throw "Preset '$presetName' not found in $Config" }

# NOTE: the variable name must not collide with the -Preset parameter: a parameter
# variable keeps its [string] type constraint, so "$preset = @{}" would be silently
# coerced to the string "@{...}" instead of a hashtable.
$presetTable = @{}
foreach ($kv in $presetObj.PSObject.Properties) { $presetTable[$kv.Name] = $kv.Value }

$managed = @($cfg.manageParams | ForEach-Object { [string]$_ })

Say ("config=$Config preset=$presetName params=" + (($presetTable.Keys | Sort-Object | ForEach-Object { "$_=$($presetTable[$_])" }) -join ', '))

# --- model list -----------------------------------------------------------
if ($Model) {
  $targets = $Model
} else {
  $targets = foreach ($line in (& ollama list | Select-Object -Skip 1)) {
    $t = ($line -replace '\s+', ' ').Trim()
    if ($t) { ($t -split ' ')[0] }
  }
}

$targets = $targets | Where-Object {
  $m = $_
  if (-not $m) { return $false }
  $skip = $false
  foreach ($pat in @($cfg.skipModels)) { if ($m -eq $pat -or $m -like "$pat*") { $skip = $true } }
  foreach ($pat in @($cfg.skipContains)) { if ($m -like "*$pat*") { $skip = $true } }
  return (-not $skip)
}

if (-not $targets) { Say 'no models to process'; exit 0 }
Say "models: $($targets -join ', ')"

# --- system prompt (optional) --------------------------------------------
$sysText = $null
$useSys = $SystemPrompt -or ($cfg.systemPrompt.enabled -eq $true)
if ($useSys -and $cfg.systemPrompt.file) {
  $sysPath = Join-Path (Join-Path $root 'config') $cfg.systemPrompt.file
  if (Test-Path $sysPath) {
    $raw = Get-Content $sysPath -Raw -Encoding UTF8
    $m = [regex]::Match($raw, '(?s)<!--\s*SYS:BEGIN\s*-->(.*?)<!--\s*SYS:END\s*-->')
    if ($m.Success) { $sysText = $m.Groups[1].Value.Trim() }
  }
  if (-not $sysText) { Say 'WARN: systemPrompt file/markers not found - SYSTEM layer skipped' }
}

$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
function Save-Text([string]$path, [string[]]$lines) {
  [IO.File]::WriteAllText($path, ($lines -join "`r`n"), $utf8NoBom)
}

# --- process -------------------------------------------------------------
foreach ($m in $targets) {
  $safe = FileName $m
  $backup = Join-Path $backupDir ($safe + '.Modelfile.orig')

  if ($Restore) {
    if (-not (Test-Path $backup)) { Say "SKIP $m : no backup yet"; continue }
    if ($DryRun) { Say "DRYRUN restore $m from $(Split-Path $backup -Leaf)"; continue }
    Say "restore $m from backup"
    & ollama create $m -f $backup
    if ($LASTEXITCODE -ne 0) { Say "FAIL restore $m" } else { Say "OK restored $m" }
    continue
  }

  $mfLines = @(& ollama show $m --modelfile)
  if ($mfLines.Count -lt 3) { Say "SKIP $m : empty modelfile"; continue }

  if (-not (Test-Path $backup)) {
    Save-Text $backup $mfLines
    Say "backup saved: $(Split-Path $backup -Leaf)"
  }

  # effective params = preset, then per-model overrides
  $eff = @{}
  foreach ($k in $presetTable.Keys) { $eff[$k] = $presetTable[$k] }
  if ($cfg.overrides) {
    $ovObj = Get-NamedValue $cfg.overrides $m
    if ($null -ne $ovObj) {
      foreach ($kv in $ovObj.PSObject.Properties) { $eff[$kv.Name] = $kv.Value }
    }
  }

  $newLines = @()
  foreach ($k in $managed) {
    if ($eff.ContainsKey($k)) { $newLines += "PARAMETER $k $($eff[$k])" }
  }
  if ($sysText) {
    $newLines += 'SYSTEM """'
    $newLines += ($sysText -split "`r?`n")
    $newLines += '"""'
  }

  $out = New-Object System.Collections.Generic.List[string]
  $inserted = $false
  foreach ($line in $mfLines) {
    if ($line -match '^PARAMETER\s+(\S+)') {
      if ($managed -contains $Matches[1]) { continue }   # drop old managed value
    }
    if (-not $inserted -and $line -match '^\s*(LICENSE|MESSAGE)\b') {
      foreach ($l in $newLines) { $out.Add($l) }
      $inserted = $true
    }
    $out.Add($line)
  }
  if (-not $inserted) { foreach ($l in $newLines) { $out.Add($l) } }

  $tmpFile = Join-Path $workDir ($safe + '.Modelfile')
  Save-Text $tmpFile $out.ToArray()

  Say ("$m -> " + ((@($newLines | Where-Object { $_ -like 'PARAMETER*' })) -join ' | '))
  if ($DryRun) { Say "DRYRUN modelfile: $tmpFile"; continue }

  & ollama create $m -f $tmpFile
  if ($LASTEXITCODE -ne 0) { Say "FAIL $m" } else { Say "OK $m" }
}

Say "done. log: $logFile"
Say "hint: verify with  ollama show <model>  (Parameters block)"

