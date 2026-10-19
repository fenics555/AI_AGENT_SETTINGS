# watch_live.ps1 — УНИВЕРСАЛЬНОЕ ОКНО-НАБЛЮДАТЕЛЬ ПРОГОНА (один на все прогоны)
# ######################################################################
# ##  НА ЛБУ №1: ЗАКОН УЧИТ РЕШАТЬ, А НЕ ПОДСКАЗЫВАЕТ (владелец)     ##
# ##    ЦЕЛЬ — ОБУЧИТЬ модель решать ПОДОБНЫЕ задачи, а не помочь     ##
# ##    пройти тест. Подсказка (маска/число/имя/готовая команда) —    ##
# ##    НЕ в закон (в скилл/инструмент). Проверка: подставь ЧУЖУЮ      ##
# ##    задачу (.prt, ГОСТ) — принцип должен работать ТАМ.             ##
# ##    Тест пройден подсказкой = умения НЕТ = ПРОВАЛ.                 ##
# ######################################################################
# ##  НА ЛБУ №2 — ЧТО ОБЯЗАНО БЫТЬ В ОКНЕ (владелец, 17.10.2026)     ##
# ##  1. ХОД            — из .LOG (пишется ВСЕГДА, сразу)             ##
# ##  2. RESULT-строки  — из .LOG                                    ##
# ##  3. ОТВЕТЫ МОДЕЛЕЙ — ФИНАЛ/Ш1..Ш5/ОПРОС (появляются в .TXT)      ##
# ##  4. ТОКЕНЫ         — «токенов N» из .LOG                         ##
# ##  5. ВРЕМЯ          — «задание N с» (.LOG) + sec= (.TXT)          ##
# ##  🔴 ГЛАВНАЯ ГРАБЛЯ: .TXT пишется ПОЗЖЕ и вначале ПУСТОЙ.         ##
# ######################################################################
# Открывает ВЛАДЕЛЕЦ (двойной клик ИЛИ командой):
#   cmd /c start "STEND LIVE" powershell -NoProfile -NoExit -ExecutionPolicy Bypass -File D:\AI\AGENT_SETTINGS\tmp\watch_live.ps1
# Только ЧИТАЕТ файлы прогона. Прогон не трогает. Выход по ALL DONE или Enter.
param([string]$Tag = '', [int]$Every = 15)
$Host.UI.RawUI.WindowTitle = 'STEND LIVE - hod progona'
$tmp    = 'D:\AI\AGENT_SETTINGS\tmp'
$logDir = 'D:\AI\AGENT_SETTINGS\checks\agentic\log'

Write-Host '=== ОКНО-НАБЛЮДАТЕЛЬ ПРОГОНА СТЕНДА ===' -ForegroundColor Green
Write-Host 'Конец = ALL DONE. Окно НЕ закрывать (только читает файлы).' -ForegroundColor Yellow
Write-Host ''

function Get-Newest($pat) {
  $f = Get-ChildItem $tmp -Filter $pat -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 1
  return $f
}
$lastSum = -1; $lastOut = -1; $same = 0
while ($true) {
  $now = Get-Date -Format 'HH:mm:ss'
  $sf = if ($Tag -ne '') { Get-Newest ('run_' + $Tag + '_*summary.txt') } else { Get-Newest 'run_*_*summary.txt' }
  if ($sf) {
    if ($sf.Length -ne $lastSum) { $lastSum = $sf.Length; $same = 0 } else { $same++ }
    $done   = (Select-String -Path $sf.FullName -Pattern 'ALL DONE' | Measure-Object).Count
    $phases = (Select-String -Path $sf.FullName -Pattern '\[\d+/\d+\]' | Measure-Object).Count
    $res    = (Select-String -Path $sf.FullName -Pattern 'RESULT\|' | Measure-Object).Count
    Write-Host ("[$now] СВОДКА: $($sf.Name)") -ForegroundColor Cyan
    Write-Host ("         фаз начато=$phases | RESULT-строк=$res | ALL DONE=$done | размер=$($sf.Length) б")
    if ($done -gt 0) { Write-Host 'ПРОГОН ЗАВЕРШЁН!' -ForegroundColor Green; break }
  } else { Write-Host "[$now] сводки по фильтру '$Tag' пока нет" -ForegroundColor DarkGray }

  $of = if ($Tag -ne '') { Get-Newest ('run_' + $Tag + '_out.txt') } else { Get-Newest 'run_*_out.txt' }
  if ($of -and $of.Length -ne $lastOut) {
    $lastOut = $of.Length
    foreach ($t in (Get-Content $of.FullName -Tail 4 -ErrorAction SilentlyContinue)) {
      if ($t -match 'START|ЗАДАЧА|RULESET|COUNT_|SKILL_|NO_|sec=|шаг|ETA') { Write-Host ("   " + $t.Trim()) }
    }
  }

  $lg = Get-ChildItem $logDir -File -ErrorAction SilentlyContinue | Where-Object { $_.Name -like 'probe*.log' } | Sort-Object LastWriteTime -Descending | Select-Object -First 1
  if ($lg) {
    $age = [math]::Round(((Get-Date) - $lg.LastWriteTime).TotalSeconds)
    if ($age -gt 180) { Write-Host ("[$now] ВНИМАНИЕ: лог не растёт $age с — возможен стоп!") -ForegroundColor Red }
    else { Write-Host ("         лог жив ($age с назад): $($lg.Name)") -ForegroundColor DarkGray }
    # 🔴 ХОД + ВРЕМЯ + ТОКЕНЫ — ИЗ .LOG (он полон СРАЗУ, в отличие от .txt)
    $lc = Get-Content $lg.FullName -Encoding UTF8 -ErrorAction SilentlyContinue
    foreach ($t in $lc) {
      if ($t -match 'шаг|COUNT_|SKILL_|NO_|задание|токенов|RULESET|ЭТАЛОН НА СТАРТЕ') {
        Write-Host ('   ' + $t.Trim()) -ForegroundColor Green
      }
    }
  }
  # §6.1.6: ОТВЕТЫ МОДЕЛЕЙ + ТОКЕНЫ + ВРЕМЯ — в окно (из .txt лога теста)
  # ФИКС (грабля PS 5.1): -Exclude с -Filter возвращает ПУСТО -> фильтруем через Where-Object!
  # Также пропускаем ПУСТЫЕ свежие логи (97 б) — берём самый свежий НЕПУСТОЙ (>= 500 б).
  # §6.1.6: ОТВЕТЫ МОДЕЛЕЙ + ТОКЕНЫ + ВРЕМЯ — ТОЛЬКО из СВЕЖЕГО .txt (не старше 200 с!)
  # 🔴 ФИКС: старый .txt от прошлой сессии показывал СТАРЫЕ ответы. Берём только свежий.
  $txt = Get-ChildItem $logDir -File -ErrorAction SilentlyContinue | Where-Object { $_.Name -like 'probe*.txt' -and $_.Name -notlike '*trace*' -and ((Get-Date) - $_.LastWriteTime).TotalSeconds -lt 200 } | Sort-Object LastWriteTime -Descending | Select-Object -First 1
  if ($txt -and $txt.Length -ne $script:lastTxt) {
    $script:lastTxt = $txt.Length
    Write-Host ("   📄 ОТВЕТЫ из СВЕЖЕГО: $($txt.Name)") -ForegroundColor Magenta
    $c = Get-Content $txt.FullName -Raw -Encoding UTF8 -ErrorAction SilentlyContinue
    if ($c) {
      foreach ($hdr in 'ФИНАЛЬНЫЙ ОТВЕТ','Ш1 ЧТО ДЕЛАЛА','Ш2 ЧТО ЧИТАЛА','Ш3 ПОЧЕМУ','Ш4 ЧТО УЛУЧШИТЬ','Ш5 ЧТО КОНКРЕТНО СЧИТАЛА','ОПРОС МОДЕЛИ') {
        $p = $c.IndexOf($hdr)
        if ($p -ge 0) {
          $blk = $c.Substring($p); if ($blk.Length -gt 1500) { $blk = $blk.Substring(0,1500) + ' …[усечено]' }
          Write-Host ('   --- ' + $hdr + ' ---') -ForegroundColor Magenta
          Write-Host ('   ' + ($blk -replace "`r?`n", ' ⏎ '))
        }
      }
      $rr = Select-String -Path $txt.FullName -Pattern 'RESULT\|'
      foreach ($x in $rr) {
        $f = $x.Line -split '\|'
        if ($f.Count -ge 6) { Write-Host ('   ⏱ ' + $f[3] + ' | ' + $f[4] + ' | ' + $f[5] + ' | ' + (($x.Line -split 'sec=')[1] -split '\|' | Select-Object -First 1) + 'с | tokens=' + (($x.Line -split 'tokens=')[1] -split '\|' | Select-Object -First 1)) -ForegroundColor Yellow }
      }
    }
  }
  Write-Host ''
  Start-Sleep -Seconds $Every
}
Write-Host 'Сводка:' $sf.FullName -ForegroundColor Green
Read-Host 'Enter — закрыть окно'
