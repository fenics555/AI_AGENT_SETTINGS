# _fix_probes.ps1 — фикс РЫЧАГ 38 в probes\ (одинаковая строка в 4 файлах)
$files = @(
  'D:\AI\AGENT_SETTINGS\probes\probe_0_recon.ps1',
  'D:\AI\AGENT_SETTINGS\probes\probe_5_honest.ps1',
  'D:\AI\AGENT_SETTINGS\probes\probe_6_why.ps1',
  'D:\AI\AGENT_SETTINGS\probes\probe_7_write.ps1'
)
$old = '        try { $res = (& powershell -NoProfile -Command ("Set-Location -LiteralPath ''$proba''; " + $cmd) 2>&1 | Out-String) }'
foreach ($f in $files) {
  if (-not (Test-Path $f)) { Write-Host ("НЕТ: " + $f); continue }
  $raw = Get-Content $f -Raw -Encoding UTF8
  if ($raw -notmatch [regex]::Escape('Set-Location -LiteralPath')) { Write-Host ("ПРОПУСК (нет строки): " + $f); continue }
  $bom = 0
  $bytes = [IO.File]::ReadAllBytes($f)
  if ($bytes.Length -ge 3 -and $bytes[0] -eq 239 -and $bytes[1] -eq 187 -and $bytes[2] -eq 191) { $bom = 1 }

  $newBlock = @'
        # ФИКС 18.10.2026 (РЫЧАГ 38): снять внешний слой, если модель сама обернула в powershell -Command
        $inner = $null
        if ($cmd -match '(?is)^\s*powershell(\.exe)?\s+(-NoProfile\s+)?-Command\s+["'']?(.*?)["'']?\s*$') {
            $inner = $Matches[3].Trim()
            if ($inner.StartsWith('"') -and $inner.EndsWith('"') -and $inner.Length -gt 2) { $inner = $inner.Substring(1, $inner.Length - 2) }
            elseif ($inner.StartsWith("'") -and $inner.EndsWith("'") -and $inner.Length -gt 2) { $inner = $inner.Substring(1, $inner.Length - 2) }
        }
        $useCmd = if ($inner) { $inner } else { $cmd }
        try {
            $sb = [ScriptBlock]::Create("Set-Location -LiteralPath '$proba'; " + $useCmd)
            $res = (& $sb 2>&1 | Out-String)
        } catch {
            $res = (& powershell -NoProfile -Command ("Set-Location -LiteralPath '$proba'; " + $useCmd) 2>&1 | Out-String)
        }
'@
  $lines = Get-Content $f -Encoding UTF8
  $out = @()
  $done = $false
  foreach ($ln in $lines) {
    if (-not $done -and $ln -match 'Set-Location -LiteralPath' -and $ln -match 'try\s*\{') {
      $out += ($newBlock -split "`r?`n")
      $done = $true
    } else {
      $out += $ln
    }
  }
  if ($done) {
    [IO.File]::WriteAllLines($f, $out, (New-Object System.Text.UTF8Encoding($bom -eq 1)))
    Write-Host ("ИСПРАВЛЕН: " + ($f -replace '.*\\','') + "  (строк было " + $lines.Count + ", стало " + $out.Count + ")")
  } else {
    Write-Host ("НЕ НАЙДЕН якорь: " + $f)
  }
}
