$cmd = 'git commit -m test'
$rx  = '(?i)(git\s+(add|commit|push|reset|checkout|rebase|merge|stash|apply|rm)|>(?!\$null))'
Write-Host ('regex = ' + $rx)
Write-Host ('match = ' + ($cmd -match $rx))
$rx2 = '(?i)(git\s+(add|commit|push))'
Write-Host ('simple match = ' + ($cmd -match $rx2))
# проверим и как в модуле (тот же литерал)
$m = [regex]::Match($cmd, $rx)
Write-Host ('regex object success = ' + $m.Success + ' value=' + $m.Value)
