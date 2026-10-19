# watch_3m2t.ps1 — НАБЛЮДАТЕЛЬ ПРОГОНА: показывает ход в видимом окне
# Запуск (окно гарантированно видно):  двойной клик ИЛИ
#   cmd /c start "STEND LIVE" powershell -NoProfile -NoExit -ExecutionPolicy Bypass -File D:\AI\AGENT_SETTINGS\tmp\watch_3m2t.ps1
$Host.UI.RawUI.WindowTitle = 'STEND LIVE - hod progona'
$out = 'D:\AI\AGENT_SETTINGS\tmp\run_3m2t_out.txt'
$sum = 'D:\AI\AGENT_SETTINGS\tmp\run_3m2t_svodka.txt'
$logDir = 'D:\AI\AGENT_SETTINGS\checks\agentic\log'

Write-Host '=== НАБЛЮДАТЕЛЬ ПРОГОНА P12-P25 x 3 модели x 2 теста ===' -ForegroundColor Green
Write-Host 'Конец = ALL DONE. Окно НЕ закрывать (только читает файлы).' -ForegroundColor Yellow
Write-Host ''

$lastLen = -1
$lastSum = -1
while ($true) {
  $now = Get-Date -Format 'HH:mm:ss'
  # 1) сводка (структурированные результаты)
  $sf = Get-ChildItem 'D:\AI\AGENT_SETTINGS\tmp' -Filter 'run_3m2t_run1_*' | Sort-Object LastWriteTime -Descending | Select-Object -First 1
  if ($sf) {
    if ($sf.Length -ne $lastSum) {
      $done = (Select-String -Path $sf.FullName -Pattern 'ALL DONE' | Measure-Object).Count
      $phases = (Select-String -Path $sf.FullName -Pattern '\[\d+/36\]' | Measure-Object).Count
      $res = (Select-String -Path $sf.FullName -Pattern 'RESULT\|' | Measure-Object).Count
      Write-Host ("[$now] СВОДКА: фаз начато=$phases/36, RESULT-строк=$res, ALL DONE=$done") -ForegroundColor Cyan
      if ($done -gt 0) { Write-Host 'ПРОГОН ЗАВЕРШЁН!' -ForegroundColor Green; break }
      $lastSum = $sf.Length
    }
  }
  # 2) ход теста (последние строки out-файла)
  if (Test-Path $out) {
    $len = (Get-Item $out).Length
    if ($len -ne $lastLen) {
      $tail = Get-Content $out -Tail 3 -ErrorAction SilentlyContinue
      foreach ($t in $tail) { if ($t -match 'START|ЗАДАЧА|MODEL|RULESET|COUNT_|SKILL_|sec=|ЗАД|шаг') { Write-Host ("  $t") } }
      $lastLen = $len
    }
  }
  # 3) свежий лог теста
  $lg = Get-ChildItem $logDir -File -Filter 'probe*.log' -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 1
  if ($lg) {
    $age = [math]::Round(((Get-Date) - $lg.LastWriteTime).TotalSeconds)
    if ($age -gt 180) { Write-Host ("[$now] ВНИМАНИЕ: лог не растёт $age с — возможен стоп") -ForegroundColor Red }
  } else { Write-Host ("[$now] логов пока нет") -ForegroundColor DarkGray }
  Start-Sleep -Seconds 15
}
Write-Host ''
Write-Host 'Сводка:' $sf.FullName -ForegroundColor Green
Read-Host 'Enter — закрыть'
