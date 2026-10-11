# ============================================================================
# run_all_checks.ps1 - ПОСЛЕДОВАТЕЛЬНЫЙ ЗАПУСК ВСЕХ ТЕСТОВ
# ============================================================================
#
# Прогоняет один за другим: v4 → v5 → v6
# Ошибка одного НЕ убивает остальные.
# Если нет фикстур для v6 — пропускает v6 (не падает).
#
# ЗАПУСК:
#   cd D:\AI\AGENT_SETTINGS\think_probe
#   powershell -NoProfile -ExecutionPolicy Bypass -File .\run_all_checks.ps1
#
# ВЫХОД:
#   log\run_all_checks_<дата>.log    - общий лог обёртки
#   log\think_probe_v4_*.log/txt     - результаты v4
#   log\think_probe_v5_*.log/txt     - результаты v5
#   log\v6_*.txt                     - результаты v6
# ============================================================================

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$ErrorActionPreference = 'Continue'

$root   = 'D:\AI\AGENT_SETTINGS\think_probe'
$logDir = Join-Path $root 'log'
$fixDir = Join-Path $root 'fixtures'

if (-not (Test-Path $logDir)) { New-Item -ItemType Directory -Path $logDir -Force | Out-Null }

$stamp      = Get-Date -Format 'yyyy-MM-dd_HH-mm-ss'
$wrapperLog = Join-Path $logDir "run_all_checks_${stamp}.log"

# --- Логгер ---
function Write-Log {
    param(
        [string]$Message,
        [string]$Color = 'White'
    )
    $line = "[$(Get-Date -Format 'HH:mm:ss')] $Message"
    Write-Host $line -ForegroundColor $Color
    $line | Out-File $wrapperLog -Append -Encoding utf8
}

# --- Запуск одного скрипта ---
function Run-Check {
    param(
        [string]$Name,
        [string]$ScriptPath
    )

    Write-Log "" "DarkGray"
    Write-Log ("=" * 60) "DarkGray"
    Write-Log "  ЗАПУСК: $Name" "Cyan"
    Write-Log "  Файл:   $ScriptPath" "DarkGray"
    Write-Log ("=" * 60) "DarkGray"

    if (-not (Test-Path $ScriptPath)) {
        Write-Log "  НЕ НАЙДЕН: $ScriptPath" "Red"
        return @{ Name = $Name; Status = 'missing'; Sec = 0 }
    }

    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    $status = 'ok'
    $errMsg = ''

    try {
        $psExe = "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe"
        & $psExe -NoProfile -ExecutionPolicy Bypass -File $ScriptPath
        $exitCode = $LASTEXITCODE
        if ($exitCode -ne 0 -and $null -ne $exitCode) {
            $status = "exit=$exitCode"
        }
    } catch {
        $status  = 'crash'
        $errMsg  = $_.Exception.Message
    }

    $sw.Stop()
    $sec = [math]::Round($sw.Elapsed.TotalSeconds, 1)

    if ($status -eq 'ok') {
        Write-Log "  $Name ЗАВЕРШЁН за ${sec}с" "Green"
    } else {
        Write-Log "  $Name ОШИБКА ($status) за ${sec}с" "Red"
        if ($errMsg) { Write-Log "  Причина: $errMsg" "Red" }
    }

    return @{ Name = $Name; Status = $status; Sec = $sec }
}

# ============================================================================
# СТАРТ
# ============================================================================

$totalSw = [System.Diagnostics.Stopwatch]::StartNew()

Write-Log "=== СТАРТ ОБЁРТКИ ===" "Yellow"
Write-Log "Папка:  $root" "DarkGray"
Write-Log "Лог:    $wrapperLog" "DarkGray"
Write-Log ""

# --- Проверка .clinerules ---
$crPath = 'D:\AI\.clinerules'
if (Test-Path $crPath) {
    $crSize = (Get-Item $crPath).Length
    Write-Log "clinerules: $crSize байт ($crPath)" "DarkGray"
} else {
    Write-Log "clinerules НЕ НАЙДЕН: $crPath" "Red"
}

# --- Проверка фикстур для v6 ---
$fixOk = $true
foreach ($f in @('small.md','big.md','huge.md')) {
    if (-not (Test-Path (Join-Path $fixDir $f))) { $fixOk = $false }
}
if ($fixOk) {
    Write-Log "фикстуры v6: ОК (small.md / big.md / huge.md)" "DarkGray"
} else {
    Write-Log "фикстуры v6: НЕТ — v6 будет пропущен" "Yellow"
}

Write-Log ""

# --- Список тестов ---
$checks = @(
    @{ Name = 'v4 - поведение моделей';   Path = (Join-Path $root 'think_probe_v4.ps1'); Skip = $false },
    @{ Name = 'v5 - генерация скрипта';   Path = (Join-Path $root 'think_probe_v5.ps1'); Skip = $false },
    @{ Name = 'v6 - выбор инструмента';   Path = (Join-Path $root 'think_probe_v6.ps1'); Skip = (-not $fixOk) }
)

$results = @()

foreach ($c in $checks) {
    if ($c.Skip) {
        Write-Log "  ПРОПУСК: $($c.Name) (нет фикстур)" "Yellow"
        $results += @{ Name = $c.Name; Status = 'skipped'; Sec = 0 }
        continue
    }
    $r = Run-Check -Name $c.Name -ScriptPath $c.Path
    $results += $r
}

# ============================================================================
# ИТОГИ
# ============================================================================

$totalSw.Stop()
$totalSec = [math]::Round($totalSw.Elapsed.TotalSeconds, 1)

Write-Log "" "DarkGray"
Write-Log ("=" * 60) "Yellow"
Write-Log "  ИТОГИ ПРОГОНА" "Yellow"
Write-Log ("=" * 60) "Yellow"

foreach ($r in $results) {
    $icon = switch ($r.Status) {
        'ok'      { '[OK]  ' }
        'skipped' { '[SKIP]' }
        'missing' { '[---] ' }
        default   { '[ERR] ' }
    }
    $color = switch ($r.Status) {
        'ok'      { 'Green' }
        'skipped' { 'Yellow' }
        default   { 'Red' }
    }
    Write-Log ("  {0} {1,-40} {2,6}с" -f $icon, $r.Name, $r.Sec) $color
}

Write-Log ""
Write-Log "  ОБЩЕЕ ВРЕМЯ: ${totalSec}с ($([math]::Round($totalSec/60,1)) мин)" "Yellow"
Write-Log ""

# --- Список файлов результатов ---
Write-Log "=== ФАЙЛЫ РЕЗУЛЬТАТОВ ===" "Cyan"

Write-Host ""
Write-Host "--- Последние отчёты v4 ---" -ForegroundColor DarkGray
Get-ChildItem $logDir -Filter 'v4_*.txt' -ErrorAction SilentlyContinue |
    Sort-Object LastWriteTime | Select-Object -Last 5 |
    Format-Table Name, Length, LastWriteTime -AutoSize

Write-Host "--- Последние отчёты v5 ---" -ForegroundColor DarkGray
Get-ChildItem $logDir -Filter 'v5_*.txt' -ErrorAction SilentlyContinue |
    Sort-Object LastWriteTime | Select-Object -Last 5 |
    Format-Table Name, Length, LastWriteTime -AutoSize

Write-Host "--- Последние отчёты v6 ---" -ForegroundColor DarkGray
Get-ChildItem $logDir -Filter 'v6_*.txt' -ErrorAction SilentlyContinue |
    Sort-Object LastWriteTime | Select-Object -Last 5 |
    Format-Table Name, Length, LastWriteTime -AutoSize

Write-Host ""
Write-Host "Обёртка завершена." -ForegroundColor Yellow
Write-Host "Лог: $wrapperLog" -ForegroundColor DarkGray