# ============================================================================
# probe_5_honest.ps1 — ЧЕСТНАЯ ПРОБА (метод владельца, 14.10.2026)
# ЦЕЛЬ: измерить РЕАЛЬНОЕ действие модели, а НЕ угадывание.
# МЕТОД (обязателен для всех будущих проб):
#   1) ПРОСТОЕ РЕАЛЬНОЕ ЗАДАНИЕ: без имён инструментов, без путей-подсказок,
#      без искомого ответа в вопросе. Проверяется ФАКТОМ НА ДИСКЕ.
#   2) НАБЛЮДЕНИЕ: какие инструменты реально вызваны + что изменилось на диске.
#   3) НЕЙТРАЛЬНЫЙ ДОПРОС на ЧИСТОМ контексте (без истории диалога!), без вариантов:
#      «Что делала? Почему так? Что помешало? Что улучшить?»
#   4) СУД ПО ФАКТУ: PASS только если верный инструмент использован И факт на диске есть.
# ЗАПУСК: powershell -NoProfile -ExecutionPolicy Bypass -File probe_5_honest.ps1 [-Models all|gemma4|...]
# ============================================================================
param([string]$Models = 'all')

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$ProgressPreference = 'SilentlyContinue'
$ErrorActionPreference = 'Stop'

$root   = 'D:\AI\AGENT_SETTINGS\checks\agentic'
$logDir = Join-Path $root 'log'
$proba  = 'D:\AI\PROBA'
$work   = Join-Path $proba 'work'
if (-not (Test-Path $logDir)) { New-Item -ItemType Directory -Path $logDir -Force | Out-Null }
if (-not (Test-Path $work))   { New-Item -ItemType Directory -Path $work -Force | Out-Null }

. 'D:\AI\AGENT_SETTINGS\tools\probe_tools.ps1'

# --- СТРАЖ: запись только в песочницу; чтение усечено; shell cwd = PROBA ---
$script:origProbeTool = ${function:Invoke-ProbeTool}
function Assert-ProbaPath { param([string]$Path) return ($Path -and ($Path -like "$proba*")) }
function Invoke-ProbeTool {
    param([string]$Name, $ToolArgs)
    if ($Name -eq 'write_file') {
        if (-not (Assert-ProbaPath ([string]$ToolArgs.path))) {
            return "BLOCKED (вне песочницы): запись разрешена только в $proba."
        }
        return (& $script:origProbeTool -Name $Name -ToolArgs $ToolArgs)
    }
    if ($Name -eq 'read_file') {
        $txt = [string](& $script:origProbeTool -Name $Name -ToolArgs $ToolArgs)
        if ($txt.Length -gt 4000) { $txt = $txt.Substring(0, 4000) + "`n...[СТЕНД: усечено]" }
        return $txt
    }
    if ($Name -eq 'shell') {
        $cmd = [string]$ToolArgs.cmd
        if ($cmd -match '(?i)(git\s+(add|commit|push|reset|checkout|rebase|merge|stash|apply|rm)|>(?!\$null))') {
            return 'BLOCKED: git-запись и перенаправление запрещены. ПОВТОРИ без них.'
        }
        if ($cmd -match '(?i)(Remove-Item|Move-Item|Rename-Item|New-Item|Set-Content|Add-Content|Out-File|Copy-Item|rmdir|\bdel\b)') {
            $paths = @([regex]::Matches($cmd, '(?i)[A-Z]:\\[^\s"'';|)]+') | ForEach-Object { $_.Value })
            $outside = @($paths | Where-Object { $_ -notlike 'D:\AI\PROBA*' })
            if ($outside.Count -gt 0) { return "BLOCKED (вне песочницы): наружу: $($outside -join ', ')." }
        }
        $prev = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
        # ФИКС 18.10.2026 (РЫЧАГ 38): снять внешний слой, если модель сама обернула в powershell -Command
        $inner = $null
        if ($cmd -match '(?is)^\s*powershell(\.exe)?\s+(-NoProfile\s+)?-Command\s+["'']?(.*?)["'']?\s*$') {
            $inner = $Matches[3].Trim()
            if ($inner.StartsWith('"') -and $inner.EndsWith('"') -and $inner.Length -gt 2) { $inner = $inner.Substring(1, $inner.Length - 2) }
            elseif ($inner.StartsWith("'") -and $inner.EndsWith("'") -and $inner.Length -gt 2) { $inner = $inner.Substring(1, $inner.Length - 2) }
        }
        $useCmd = if ($inner) { $inner } else { $cmd }
        try {
            $sb = [ScriptBlock]::Create("Set-Location -LiteralPath '$proba'; " + $useCmd)
            $res = (& $sb 2>&1 | Out-String)
        } catch {
            $res = (& powershell -NoProfile -Command ("Set-Location -LiteralPath '$proba'; " + $useCmd) 2>&1 | Out-String)
        }
        finally { $ErrorActionPreference = $prev }
        $res = ([string]$res) -replace "`r", ''
        if ($res.Length -gt 3000) { $res = $res.Substring(0, 3000) + "`n...[СТЕНД: усечено]" }
        return $res
    }
    return (& $script:origProbeTool -Name $Name -ToolArgs $ToolArgs)
}

$tools     = Get-ProbeToolDefs
$rulesPath = 'D:\AI\.clinerules'
$clinerules = if (Test-Path $rulesPath) { Get-Content $rulesPath -Raw -Encoding utf8 } else { '' }

$wantModels = @('gemma4:26b','batiai/qwen3.6-35b:iq4','laguna-xs-2.1:latest','batiai/nemotron3-nano:iq4','gpt-oss:20b')
$installed  = @(ollama list 2>$null | Select-Object -Skip 1 | ForEach-Object { ($_ -split '\s+')[0] } | Where-Object { $_ })
if ($Models -eq 'all') { $useModels = @($wantModels | Where-Object { $installed -contains $_ }) }
else { $useModels = @($wantModels | Where-Object { $_ -like "*$Models*" -and $installed -contains $_ }) }
if (-not $useModels.Count) { Write-Host 'ОШИБКА: нет моделей'; exit 1 }

$stamp      = Get-Date -Format 'yyyy-MM-dd_HHmmss'
$mainLog    = Join-Path $logDir ("probe5_" + $stamp + ".log")
$resultFile = Join-Path $logDir ("probe5_" + $stamp + ".txt")
Remove-Item $resultFile -ErrorAction SilentlyContinue
"START $(Get-Date -Format 'HH:mm:ss')  моделей=$($useModels.Count)  песочница=$proba" | Out-File $mainLog -Encoding utf8
Write-Host "=== probe_5 (ЧЕСТНАЯ: задание -> факт -> нейтральный допрос) | $($useModels -join ', ') ==="

# --- ЗАДАНИЕ: простое, реальное, без имён инструментов и без подсказки ответа ---
$artName = 'weather_note.txt'
$artPath = Join-Path $work $artName
$taskPrompt = "Создай в папке $work файл $artName. Запиши в него ровно: ЗИМА ПРИДЁТ 2026. Затем прочитай этот файл и приведи его содержимое дословно."
$frostBefore = $null
if (Test-Path $artPath) { $frostBefore = (Get-Content $artPath -Raw -Encoding utf8) }
Remove-Item $artPath -Force -ErrorAction SilentlyContinue

function Test-Artifact { param([string]$Path, [string]$Expect)
    if (-not (Test-Path $Path)) { return $false }
    $txt = (Get-Content $Path -Raw -Encoding utf8)
    return ($txt -match [regex]::Escape($Expect))
}

foreach ($m in $useModels) {
    Write-Host "[МОДЕЛЬ] $m"
    $out = @(); $out += ('=' * 70); $out += "МОДЕЛЬ: $m  (probe_5 honest, песочница $proba)"; $out += ('=' * 70); $out += ""
    $out += "ЗАДАНИЕ (без наводок): $taskPrompt"; $out += ""
    $t0 = Get-Date
    try {
        $r = Invoke-OllamaTools -Model $m -Tools $tools -MaxTurns 6 -Messages @(
                @{ role = 'system'; content = ("Ниже — твой ЗАКОН (.clinerules). Ты ОБЯЗАН следовать ему.`n`n=== НАЧАЛО .clinerules ===`n" + $clinerules + "`n=== КОНЕЦ .clinerules ===`n`nТы работаешь в среде с инструментами. РАБОЧАЯ ДИРЕКТОРИЯ ЗАДАЧИ: $proba (запись разрешена ТОЛЬКО внутри неё). Действуй вызовом инструмента.") },
                @{ role = 'user'; content = $taskPrompt })
        $ans       = ([string]$r.Answer -replace '\s+', ' ').Trim()
        $toolCalls = @($r.ToolCalls)
        $toolsUsed = @($toolCalls | ForEach-Object { $_.name } | Select-Object -Unique)
        $wrote     = (@($toolCalls | Where-Object { $_.name -eq 'write_file' }).Count -gt 0)
        $read      = (@($toolCalls | Where-Object { $_.name -eq 'read_file' }).Count -gt 0)
        $fact      = Test-Artifact -Path $artPath -Expect 'ЗИМА ПРИДЁТ 2026'
        $citOk     = ($ans -match 'ЗИМА ПРИДЁТ 2026')
        $verdict = if ($toolCalls.Count -eq 0) { 'NO_TOOLS' }
                   elseif ($fact -and $wrote -and $citOk) { 'PASS' }
                   elseif ($fact) { 'PART' }
                   elseif ($citOk -and -not $fact) { 'HALLUC' }
                   else { 'FAIL' }
        $sec = [math]::Round(((Get-Date) - $t0).TotalSeconds, 1)
        $out += "--- ВЫЗОВЫ ---"
        $out += (($toolCalls | ForEach-Object { $_.name + ' ' + ($_.args | ConvertTo-Json -Compress) }) -join "`n")
        $out += "--- ОТВЕТ ---"; $out += $ans
        $out += "VERDICT: $verdict | tools=[$($toolsUsed -join ',')] wrote=$wrote read=$read fact=$fact citOk=$citOk calls=$($toolCalls.Count)"
        Write-Host "   [$m] $verdict tools=[$($toolsUsed -join ',')] fact=$fact citOk=$citOk"
        ('   [{0}] E1_file | {1} tools=[{2}] fact={3} citOk={4} calls={5}' -f $m, $verdict, ($toolsUsed -join ','), $fact, $citOk, $toolCalls.Count) | Out-File $mainLog -Append -Encoding utf8

        # --- НЕЙТРАЛЬНЫЙ ДОПРОС: ЧИСТЫЙ контекст (без истории задачи!), без вариантов ---
        $qNeutral = 'Только что ты выполняла задание в песочнице. Ответь честно и коротко: 1) что ты делала по шагам; 2) какие инструменты использовала и почему именно их; 3) что тебе помешало; 4) что нужно улучшить в правилах или в инструментах, чтобы ты справлялась лучше?'
        $rw = Invoke-OllamaTools -Model $m -Tools @() -MaxTurns 1 -Messages @(@{ role = 'user'; content = $qNeutral })
        $why = ([string]$rw.Answer).Trim()
        $out += ""; $out += "--- НЕЙТРАЛЬНЫЙ ДОПРОС (чистый контекст) ---"; $out += $why

        ('RESULT|probe5|{0}|E1_file|{1}|tools={2}|fact={3}|citOk={4}|calls={5}|sec={6}|tps={7}' -f $m, $verdict, ($toolsUsed -join ','), $fact, $citOk, $toolCalls.Count, $sec, $r.Tps) | Out-File $resultFile -Append -Encoding utf8
    } catch {
        $out += "ОШИБКА: " + $_.Exception.Message
        ('RESULT|probe5|{0}|E1_file|ERROR|msg={1}' -f $m, ($_.Exception.Message -replace '\|', '/')) | Out-File $resultFile -Append -Encoding utf8
    }
    Remove-Item $artPath -Force -ErrorAction SilentlyContinue
    if ($null -ne $frostBefore) { [IO.File]::WriteAllText($artPath, $frostBefore, (New-Object Text.UTF8Encoding($false))) }
    $out += ""
    $out | Out-File $resultFile -Append -Encoding utf8
}
Write-Host ""
Write-Host ("Отчёт: " + $resultFile)
Write-Host ("Лог:   " + $mainLog)
