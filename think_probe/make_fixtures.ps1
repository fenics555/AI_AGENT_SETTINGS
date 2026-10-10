# ============================================================================
# make_fixtures.ps1 - ГЕНЕРАТОР ТЕСТОВЫХ ФАЙЛОВ ДЛЯ think_probe_v6
# ============================================================================
#
# Создаёт три файла в D:\AI\AGENT_SETTINGS\think_probe\fixtures\
#   small.md  - 50 строк
#   big.md    - 2000 строк, МАРКЕР_БОЛЬШОЙ на строке 1000
#   huge.md   - 20000 строк, МАРКЕР_ГИГАНТ на строке 19500
#
# ЗАПУСК:
#   powershell -NoProfile -ExecutionPolicy Bypass -File "D:\AI\AGENT_SETTINGS\think_probe\make_fixtures.ps1"
# ============================================================================

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$ErrorActionPreference = 'Stop'

$root     = 'D:\AI\AGENT_SETTINGS\think_probe'
$fixtures = Join-Path $root 'fixtures'
if (-not (Test-Path $fixtures)) { New-Item -ItemType Directory -Path $fixtures -Force | Out-Null }

# --- small.md: 50 строк ---
$smallPath = Join-Path $fixtures 'small.md'
$lines = @()
$lines += '# TEST SMALL FILE'
$lines += ''
for ($i = 1; $i -le 48; $i++) {
    $lines += "строка small $i - обычный текст для проверки чтения"
}
$lines | Out-File -FilePath $smallPath -Encoding utf8
Write-Host "small.md : $($lines.Count) строк -> $smallPath"

# --- big.md: 2000 строк, маркер на 1000 ---
$bigPath = Join-Path $fixtures 'big.md'
$lines = @()
$lines += '# TEST BIG FILE'
$lines += ''
for ($i = 1; $i -le 2000; $i++) {
    if ($i -eq 1000) {
        $lines += "СТРОКА 1000: МАРКЕР_БОЛЬШОЙ здесь"
    } else {
        $lines += "строка big $i - наполнение для проверки чтения большого файла"
    }
}
$lines | Out-File -FilePath $bigPath -Encoding utf8
Write-Host "big.md   : $($lines.Count) строк (маркер на 1000) -> $bigPath"

# --- huge.md: 20000 строк, маркер на 19500 ---
$hugePath = Join-Path $fixtures 'huge.md'
$lines = @()
$lines += '# TEST HUGE FILE'
$lines += ''
for ($i = 1; $i -le 20000; $i++) {
    if ($i -eq 19500) {
        $lines += "СТРОКА 19500: МАРКЕР_ГИГАНТ здесь"
    } else {
        $lines += "строка huge $i - наполнение для проверки чтения гигантского файла"
    }
}
$lines | Out-File -FilePath $hugePath -Encoding utf8
Write-Host "huge.md  : $($lines.Count) строк (маркер на 19500) -> $hugePath"

Write-Host ''
Write-Host "Готово. Фикстуры в: $fixtures"
Get-ChildItem $fixtures | Select-Object Name, Length | Format-Table -AutoSize