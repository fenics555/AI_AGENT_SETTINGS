# _ctx.ps1 — ОКНО ЧЕРЕЗ ШИМУ (num_ctx): тест гипотезы «окно мало». Без правки боевых проб.
$root = 'D:\AI\AGENT_SETTINGS\checks\agentic'
$shim = Join-Path $root '_shim\probe_tools_B.shim.ps1'
if ($env:PROBE_CTX)     { $ctx = [int]$env:PROBE_CTX } else { $ctx = 32768 }
if ($env:PROBE_TOOLS_SHIM) { $shim = $env:PROBE_TOOLS_SHIM }
# 1) ОБЯЗАТЕЛЬНО боевой модуль (иначе shim не увидит Invoke-OllamaTools)
. 'D:\AI\AGENT_SETTINGS\tools\probe_tools.ps1'
. $shim
Write-Host ("CTX SHIM: num_ctx=$ctx  shim=$shim")
$c = Get-Content $root\probe_2_tools.ps1 -Raw -Encoding utf8
$c = $c.Replace("-MaxTurns 6 -Messages", ("-MaxTurns 6 -NumCtx $ctx -Messages"))
$old = $root\probe_2_tools.ps1 + '.ctxtmp.ps1'
[IO.File]::WriteAllText($old, $c, (New-Object Text.UTF8Encoding($true)))
& $old -Models laguna -Rulesets 21 -OnlyTasks P2e
Remove-Item $old -Force -ErrorAction SilentlyContinue
Write-Host 'CTX DONE'
