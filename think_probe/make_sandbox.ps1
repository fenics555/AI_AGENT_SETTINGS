# ============================================================================
# make_sandbox.ps1 — построение и сброс песочницы для think_probe_v7
# ============================================================================
# Создаёт D:\AI\AGENT_SETTINGS\think_probe\sandbox\
#   small.md    50 строк
#   big.md      2000 строк, МАРКЕР_БОЛЬШОЙ на 1000
#   huge.md     20000 строк, МАРКЕР_ГИГАНТ на 19500
#   main.py     функция calculate_total
#   config.json max_retry=5
#   README.md   строка "Версия 1.0"
#   file1.txt, file2.txt  содержат MARKER_FOR_GREP
#   file3.txt   без маркера
#   out\        пустая папка для write-тестов
#
# ЗАПУСК:  powershell -NoProfile -ExecutionPolicy Bypass -File make_sandbox.ps1
# ============================================================================

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$ErrorActionPreference = 'Stop'

$root    = 'D:\AI\AGENT_SETTINGS\think_probe'
$sandbox = Join-Path $root 'sandbox'

if (Test-Path $sandbox) { Remove-Item $sandbox -Recurse -Force }
New-Item -ItemType Directory -Path $sandbox -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $sandbox 'out') -Force | Out-Null

# small.md
$lines = @('# TEST SMALL FILE','')
for ($i=1; $i -le 48; $i++) { $lines += "строка small $i - обычный текст" }
$lines | Out-File (Join-Path $sandbox 'small.md') -Encoding utf8

# big.md
$lines = @('# TEST BIG FILE','')
for ($i=1; $i -le 2000; $i++) {
  if ($i -eq 1000) { $lines += "СТРОКА 1000: МАРКЕР_БОЛЬШОЙ здесь" }
  else { $lines += "строка big $i - наполнение для проверки" }
}
$lines | Out-File (Join-Path $sandbox 'big.md') -Encoding utf8

# huge.md
$lines = @('# TEST HUGE FILE','')
for ($i=1; $i -le 20000; $i++) {
  if ($i -eq 19500) { $lines += "СТРОКА 19500: МАРКЕР_ГИГАНТ здесь" }
  else { $lines += "строка huge $i - наполнение для проверки" }
}
$lines | Out-File (Join-Path $sandbox 'huge.md') -Encoding utf8

# main.py
@'
def calculate_total(items):
    return sum(items)

def main():
    print(calculate_total([1, 2, 3]))

if __name__ == "__main__":
    main()
'@ | Out-File (Join-Path $sandbox 'main.py') -Encoding utf8

# config.json
'{"max_retry": 5, "timeout": 30}' | Out-File (Join-Path $sandbox 'config.json') -Encoding utf8

# README.md
"# README`n`nВерсия 1.0`n" | Out-File (Join-Path $sandbox 'README.md') -Encoding utf8

# файлы для grep-теста
"prefix`nMARKER_FOR_GREP_1`nsuffix" | Out-File (Join-Path $sandbox 'file1.txt') -Encoding utf8
"prefix`nMARKER_FOR_GREP_2`nsuffix" | Out-File (Join-Path $sandbox 'file2.txt') -Encoding utf8
"no marker here"                    | Out-File (Join-Path $sandbox 'file3.txt') -Encoding utf8

Write-Host "Песочница построена: $sandbox"
Get-ChildItem $sandbox | Select-Object Name, Length | Format-Table -AutoSize