$m = 'qwen3.6:35b-a3b-coding-mtp-q4_K_M'
$host.ui.RawUI.WindowTitle = "PULL: $m"
Write-Host '============================================================' -ForegroundColor Yellow
Write-Host "  КАЧАЮ МОДЕЛЬ:  $m" -ForegroundColor Yellow
Write-Host '  ~23 ГБ  ·  Q4_K_M  ·  кодер + thinking + MTP' -ForegroundColor Yellow
Write-Host '  НЕ ЗАКРЫВАТЬ окно до 100%.' -ForegroundColor Yellow
Write-Host '============================================================' -ForegroundColor Yellow
ollama pull $m
Write-Host ''
Write-Host 'ГОТОВО: модель скачана.' -ForegroundColor Green
Read-Host 'Нажми Enter, чтобы закрыть окно'
