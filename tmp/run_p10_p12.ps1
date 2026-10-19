# run_p10_p12.ps1 - p10/p11/p12 x laguna/qwen3 x тесты 3+4 (фикс SURVEY, ctx 65536)
$ErrorActionPreference = 'Continue'
$root = 'D:\AI\AGENT_SETTINGS\checks\agentic'
$logDir = Join-Path $root 'log'
$tmp = 'D:\AI\AGENT_SETTINGS\tmp'
cd $root
$stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$sum = Join-Path $tmp ('run_p10p12_' + $stamp + '_summary.txt')
function W($t) { $t | Out-File $sum -Append -Encoding utf8; Write-Host $t }
W ("START $(Get-Date -Format 'HH:mm:ss') p10/p11/p12 x2 модели x 3+4 stamp=$stamp")
$names = @{ 'p10' = 'P10-ritual-masshtab'; 'p11' = 'P11-meta-razgovor'; 'p12' = 'P12-svod-ne-spisok' }
foreach ($rk in 'p10','p11','p12') {
  foreach ($mk in 'laguna','qwen3.6') {
    $t0 = Get-Date
    & ollama stop laguna-xs-2.1:latest *>$null
    & ollama stop batiai/qwen3.6-35b:iq4 *>$null
    Get-Process llama-server -EA SilentlyContinue | Stop-Process -Force -EA SilentlyContinue
    Start-Sleep -Seconds 6
    Write-Host ('--- ' + $names[$rk] + ' | ' + $mk + ' ---') -ForegroundColor Yellow
    $a = @('-NoProfile','-ExecutionPolicy','Bypass','-File',(Join-Path $root 'check_3_skills_avail.ps1'),'-Models',$mk,'-Rulesets',$rk,'-Seed','42')
    Start-Process powershell -ArgumentList $a -Wait -NoNewWindow
    Start-Sleep -Seconds 2
    foreach ($probe in 'probe3','probe4') {
      if ($probe -eq 'probe4') {
        Start-Sleep -Seconds 1
        $b = @('-NoProfile','-ExecutionPolicy','Bypass','-File',(Join-Path $root 'check_4_skills_read.ps1'),'-Models',$mk,'-Rulesets',$rk,'-Seed','42')
        Start-Process powershell -ArgumentList $b -Wait -NoNewWindow
        Start-Sleep -Seconds 2
      }
      $lg = Get-ChildItem $logDir -Filter ($probe + '_*.txt') | Where-Object { $_.Name -notmatch 'trace' } | Sort-Object LastWriteTime -Descending | Select-Object -First 1
      if ($lg) {
        $c = Get-Content $lg.FullName -Encoding utf8 -Raw
        W ('[' + $probe + '|' + $names[$rk] + '|' + $mk + '] log=' + $lg.Name)
        ($c -split "`n" | Where-Object { $_ -match '^START |^RULESET |^ЭТАЛОН' } | Select-Object -First 4 | ForEach-Object { '   ' + $_.Trim() }) | ForEach-Object { W $_ }
        (Select-String -Path $lg.FullName -Pattern 'RESULT\|' | ForEach-Object { '   ' + $_.Line }) | ForEach-Object { W $_ }
        $i = $c.IndexOf('ОПРОС МОДЕЛИ')
        if ($i -ge 0) { $blk = $c.Substring($i); W ('   SURVEY=' + $blk.Length + ' симв.'); $blk | Out-File $sum -Append -Encoding utf8 }
      } else { W ('   ' + $probe + ': ЛОГА НЕТ') }
    }
    $sec = [math]::Round(((Get-Date) - $t0).TotalSeconds, 1)
    W ('  ' + $names[$rk] + '|' + $mk + ' sec=' + $sec)
    Write-Host ('  done sec=' + $sec) -ForegroundColor Green
  }
}
W ('ALL DONE ' + (Get-Date -Format 'HH:mm:ss'))
Write-Host ('ALL DONE ' + (Get-Date -Format 'HH:mm:ss')) -ForegroundColor Green
