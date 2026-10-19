# SHAG 1: peregrat PROVALY H9 na NOVOM kode (NumCtx=32768, NumPredictAsk=2048)
$root="D:\AI\AGENT_SETTINGS\checks\agentic"
$log=Join-Path $root "log"
$sum="D:\AI\AGENT_SETTINGS\tmp\STEP1_summary.txt"
$jobs=@(
  @{ m="gemma4";  t="S2_creo,S3_prog" },
  @{ m="qwen";    t="S2_creo" },
  @{ m="laguna";  t="S2_creo" },
  @{ m="nemotron";t="S1_total,S2_creo,S3_prog" },
  @{ m="gpt-oss"; t="S1_total,S2_creo,S3_prog" }
)
"=== SHAG 1: PROVALY H9 (novy kod) ===" | Out-File $sum -Encoding utf8
foreach($j in $jobs){
 $t0=Get-Date
 Write-Host ("### M=" + $j.m + " T=" + $j.t + " START " + $t0.ToString("HH:mm:ss"))
 Start-Process powershell -ArgumentList @("-NoProfile","-ExecutionPolicy","Bypass","-File",(Join-Path $root "check_3_skills_avail.ps1"),"-Models",$j.m,"-Rulesets","H9","-OnlyTasks",$j.t,"-Seed","42") -WorkingDirectory $root -NoNewWindow -Wait
 $el=[math]::Round(((Get-Date)-$t0).TotalMinutes,1)
 $l=Get-ChildItem $log -Filter "probe3_*.txt" | Sort-Object LastWriteTime -Descending | Select-Object -First 1
 Write-Host ("### M=" + $j.m + " DONE $el min")
 "--- M=$($j.m) T=$($j.t) | $el min ---" | Out-File $sum -Append -Encoding utf8
 if($l){ Get-Content $l.FullName -Encoding utf8 | Where-Object { $_ -match "RESULT|ЭТАЛОН НА СТАРТЕ" } | Out-File $sum -Append -Encoding utf8 }
}
"=== SHAG 1 DONE ===" | Out-File $sum -Append -Encoding utf8
Write-Host "=== SHAG 1 DONE ==="
