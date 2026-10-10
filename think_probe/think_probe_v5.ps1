# think_probe_v5.ps1 - ТЕСТ НА РЕАЛЬНОЕ КОДИРОВАНИЕ (с .clinerules и диагностикой)
# Отчёты по каждой модели отдельно — не перезаписываются!
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$ProgressPreference = 'SilentlyContinue'
$ErrorActionPreference = 'Stop'

# --- Пути ---
$root    = 'D:\AI\AGENT_SETTINGS\think_probe'
$logDir  = Join-Path $root 'log'
if (-not (Test-Path $logDir)) { New-Item -ItemType Directory -Path $logDir -Force | Out-Null }

$uri     = 'http://localhost:11434/api/chat'
$clinerulesPath = 'D:\AI\.clinerules'

# --- Прочитать .clinerules ---
if (-not (Test-Path $clinerulesPath)) {
    Write-Host "ОШИБКА: .clinerules не найден: $clinerulesPath"
    exit 1
}
$clinerules = Get-Content $clinerulesPath -Raw -Encoding utf8
$clinerulesSize = (Get-Item $clinerulesPath).Length
Write-Host "=== .clinerules ==="
Write-Host ("Путь: " + $clinerulesPath)
Write-Host ("Размер файла: " + $clinerulesSize + " байт")
Write-Host ("Прочитано: " + $clinerules.Length + " символов")
Write-Host ""

# --- Системный промпт ---
$sys = @"
Ты — исполнитель дома. Ниже — твой ЗАКОН (.clinerules). Ты ОБЯЗАН следовать ему.

=== НАЧАЛО .clinerules ===
$clinerules
=== КОНЕЦ .clinerules ===

Соблюдай ВСЕ правила из .clinerules. Отвечай коротко, по делу. Без <thought> блоков.
"@

# --- Спека задачи ---
$spec = @'
# СПЕКА ЗАДАЧИ: Скрипт инвентаризации старых файлов

## ЦЕЛЬ
Написать рабочий PowerShell-скрипт `scan_old_files.ps1`, который:
1. Сканирует папку `D:\AI\log\urn\` (рекурсивно)
2. Находит все файлы старше 30 дней (по LastWriteTime)
3. Записывает их список в файл `D:\AI\log\urn\old_files_report.txt` в формате:
   `<дата_изменения> | <размер_КБ> | <полный_путь>`
4. НЕ УДАЛЯЕТ файлы (только отчёт!)
5. Выводит в консоль: "Найдено N файлов старше 30 дней"

## ОГРАНИЧЕНИЯ
- НЕ использовать `Remove-Item`, `del`, `rm` (только чтение!)
- Проверить существование папки через `Test-Path` перед сканированием
- Если папка не существует — вывести "Папка не найдена" и завершить
- Кодировка вывода — UTF-8

## ФОРМАТ ОТВЕТА
Выведи ТОЛЬКО текст скрипта `scan_old_files.ps1` в блоке ```powershell ... ```.
'@

# --- Модели ---
$models = @(
  'gemma4:26b',
  'batiai/qwen3.6-35b:iq4',
  'laguna-xs-2.1:latest',
  'batiai/nemotron3-nano:iq4',
  'gpt-oss:20b'
)

# --- Лимиты ---
$num_predict = 8192
$num_ctx     = 16384
$timeout_sec = 300

# --- Общий лог ---
$mainLog = Join-Path $logDir 'think_probe_v5_progress.log'
"START $(Get-Date -Format 'HH:mm:ss')  models=$($models.Count)  task=scan_old_files  clinerules=$($clinerules.Length)chars" | Out-File $mainLog -Encoding utf8

$total = $models.Count
$done  = 0

foreach ($m in $models) {
  $done++
  Write-Host "[$done/$total] Тестирую: $m"

  # --- Имя файла с моделью (без перезаписи) ---
  $safeName = $m -replace '[/:.]', '_'
  $stamp    = Get-Date -Format 'yyyy-MM-dd_HH-mm-ss'
  $reportFile = Join-Path $logDir "v5_${safeName}_${stamp}_report.txt"
  $headsFile  = Join-Path $logDir "v5_${safeName}_${stamp}_heads.txt"
  $codeFile   = Join-Path $logDir "v5_${safeName}_${stamp}_code.ps1"
  $checkFile  = Join-Path $logDir "v5_${safeName}_${stamp}_check.txt"
  $diagFile   = Join-Path $logDir "v5_${safeName}_${stamp}_diag.txt"

  # --- Метрики до запроса ---
  $ramBefore = 0
  $llamaProcBefore = Get-Process -Name 'llama-server' -ErrorAction SilentlyContinue
  if ($llamaProcBefore) {
      $ramBefore = [math]::Round(($llamaProcBefore | Measure-Object WorkingSet64 -Sum).Sum / 1GB, 2)
  }

  # --- Запрос ---
  $body = @{
    model    = $m
    messages = @(
      @{ role = 'system'; content = $sys },
      @{ role = 'user';   content = $spec }
    )
    think    = 'low'
    stream   = $false
    options  = @{ num_predict = $num_predict; num_ctx = $num_ctx }
  } | ConvertTo-Json -Depth 6
  $bytes = [System.Text.Encoding]::UTF8.GetBytes($body)

  try {
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    $wr = Invoke-WebRequest -Uri $uri -Method Post -Body $bytes -ContentType 'application/json; charset=utf-8' -TimeoutSec $timeout_sec -UseBasicParsing
    $sw.Stop()

    $r    = [System.Text.Encoding]::UTF8.GetString($wr.RawContentStream.ToArray()) | ConvertFrom-Json
    $ans  = $r.message.content
    $thk  = $r.message.thinking
    $sec  = [math]::Round($sw.Elapsed.TotalSeconds, 2)
    $tps  = if ($r.eval_duration -gt 0) { [math]::Round($r.eval_count / ($r.eval_duration / 1e9), 2) } else { 0 }

    # --- Метрики после запроса ---
    $ramAfter = 0
    $llamaProcAfter = Get-Process -Name 'llama-server' -ErrorAction SilentlyContinue
    if ($llamaProcAfter) {
        $ramAfter = [math]::Round(($llamaProcAfter | Measure-Object WorkingSet64 -Sum).Sum / 1GB, 2)
    }
    $psOutput = ollama ps 2>$null | Select-String -Pattern $m -SimpleMatch
    $psLine = if ($psOutput) { ($psOutput.ToString() -replace '\s+', ' ').Trim() } else { 'n/a' }

    # --- Размер промпта и что вошло ---
    $promptTokens = $r.prompt_eval_count
    $evalTokens   = $r.eval_count
    $ctxLimit     = $num_ctx
    $ctxUsed      = $promptTokens + $evalTokens
    $ctxFree      = $ctxLimit - $ctxUsed

    # --- Диагностика: что прочла / что не вошло ---
    $diag = @()
    $diag += "=== ДИАГНОСТИКА МОДЕЛИ: $m ==="
    $diag += ""
    $diag += "--- .clinerules ---"
    $diag += "Размер файла: $clinerulesSize байт"
    $diag += "Прочитано: $($clinerules.Length) символов"
    $diag += "Оценка токенов: ~$( [math]::Round($clinerules.Length / 3.5) )"
    $diag += ""
    $diag += "--- Промпт ---"
    $diag += "prompt_tokens: $promptTokens"
    $diag += "eval_tokens: $evalTokens"
    $diag += "num_ctx: $ctxLimit"
    $diag += "Занято: $ctxUsed"
    $diag += "Свободно: $ctxFree"
    if ($ctxFree -lt 0) {
      $diag += "!!! ПРОМПТ ОБРЕЗАН !!!"
    } else {
      $diag += "OK: промпт влез"
    }
    $diag += ""
    $diag += "--- Скорость ---"
    $diag += "Время: $sec сек"
    $diag += "Скорость: $tps т/с"
    $diag += ""
    $diag += "--- Память ---"
    $diag += "RAM до: $ramBefore GB"
    $diag += "RAM после: $ramAfter GB"
    $diag += "ollama ps: $psLine"
    $diag | Out-File -FilePath $diagFile -Encoding utf8

    # --- Отчёт ---
    $report = @()
    $report += "МОДЕЛЬ: $m"
    $report += "ДАТА: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
    $report += "МЕТРИКИ: токены=$evalTokens промпт=$promptTokens сек=$sec т/с=$tps"
    $report += "ПАМЯТЬ: RAM=$ramAfter GB | PS: $psLine"
    $report += "КОНТЕКСТ: занято=$ctxUsed из $ctxLimit (свободно=$ctxFree)"
    $report += ""
    $report += "=== ОТВЕТ ==="
    $report += $ans
    $report | Out-File -FilePath $reportFile -Encoding utf8

    # --- Thinking ---
    if ($thk) { $thk | Out-File -FilePath $headsFile -Encoding utf8 }

    # --- Код ---
    $code = ''
    if ($ans -match '(?s)```(?:powershell|ps1)?\s*\n(.*?)```') { $code = $matches[1] } else { $code = $ans }
    $code | Out-File -FilePath $codeFile -Encoding utf8

    # --- Проверки кода ---
    $checkResult = @()
    $checkResult += "=== ПРОВЕРКА КОДА: $m ==="
    $checkResult += ""
    $checks = @(
      @{ name = 'Test-Path'; pattern = 'Test-Path'; expect = $true },
      @{ name = 'Remove-Item (ЗАПРЕЩЁН)'; pattern = 'Remove-Item'; expect = $false },
      @{ name = 'del (ЗАПРЕЩЁН)'; pattern = '\bdel\b'; expect = $false },
      @{ name = 'Запись в файл'; pattern = 'Out-File|Set-Content|Add-Content'; expect = $true },
      @{ name = 'LastWriteTime'; pattern = 'LastWriteTime'; expect = $true },
      @{ name = 'AddDays(-30)'; pattern = 'AddDays\(-30\)'; expect = $true },
      @{ name = 'Get-ChildItem'; pattern = 'Get-ChildItem'; expect = $true }
    )
    foreach ($c in $checks) {
      $found = $code -match $c.pattern
      if ($c.expect -and $found) { $checkResult += "[OK] $($c.name) найден" }
      elseif ($c.expect -and -not $found) { $checkResult += "[FAIL] $($c.name) НЕ найден" }
      elseif (-not $c.expect -and $found) { $checkResult += "[FAIL] $($c.name) найден (запрещено!)" }
      else { $checkResult += "[OK] $($c.name) не найден" }
    }
    try {
      $tokens = $null; $errors = $null
      $null = [System.Management.Automation.Language.Parser]::ParseInput($code, [ref]$tokens, [ref]$errors)
      if ($errors.Count -eq 0) { $checkResult += "[OK] Синтаксис PowerShell корректен" }
      else { $checkResult += "[FAIL] Синтаксис PowerShell: $($errors[0].Message)" }
    } catch {
      $checkResult += "[FAIL] Синтаксис PowerShell: $($_.Exception.Message)"
    }
    $checkResult | Out-File -FilePath $checkFile -Encoding utf8

    # --- Общий лог ---
    $line = ('[{0}/{1}] ok  {2} | токены={3} промпт={4} сек={5} т/с={6} | RAM={7}GB | ctx={8}/{9} | PS: {10}' -f $done, $total, $m, $evalTokens, $promptTokens, $sec, $tps, $ramAfter, $ctxUsed, $ctxLimit, $psLine)
    Write-Host $line
    $line | Out-File $mainLog -Append -Encoding utf8

  } catch {
    $line = ('[{0}/{1}] err {2} | {3}' -f $done, $total, $m, $_.Exception.Message)
    Write-Host $line
    $line | Out-File $mainLog -Append -Encoding utf8
  }
}

"END $(Get-Date -Format 'HH:mm:ss')  total_done=$done" | Out-File $mainLog -Append -Encoding utf8
Write-Host ''
Write-Host "Готово. Логи в: $logDir"
Write-Host "Файлы на модель: v5_<модель>_<дата>_report.txt, _heads.txt, _code.ps1, _check.txt, _diag.txt"