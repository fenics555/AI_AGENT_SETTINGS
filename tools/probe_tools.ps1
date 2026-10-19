# ============================================================================
# probe_tools.ps1 — ОБЩАЯ БИБЛИОТЕКА ИНСТРУМЕНТОВ для агентных тестов think_probe.
# Модель вызывает инструменты через НАТИВНЫЙ function calling Ollama (/api/chat, tools).
# Все тесты (v12 и далее) используют эту библиотеку — не дублируют инструменты.
#
# ЗАКОН СТЕНДА (13.10.2026): seed ФИКСИРОВАН по умолчанию (42). Без него вердикты «плывут»
#   (разброс ±2/3). Подтверждено: два прогона probe_3 с seed=42 дали ПОБАЙТНО одинаковый результат.
#   Отключить (для отладки) — явно передать -Seed -1.
# Экспорт:  Get-ProbeToolDefs   — JSON-описания инструментов (read_file/write_file/shell)
#           Invoke-ProbeTool    — выполнить один вызов инструмента (песочно)
#           Invoke-OllamaTools  — цикл function calling: модель -> вызов -> результат -> ответ
#           Set-ProbeGuard      — ЕДИНЫЙ СТРАЖ + TRACE для всех проб (песочница/обрезка/блокировки/JSONL)
#           Write-ProbeTrace    — записать один вызов в trace-JSONL текущей пробы
# ============================================================================

# Корень, доступный инструментам (песочница тестов — внутри него).
$script:ProbeRoot = 'D:\AI'

function Get-ProbeToolDefs {
    return @(
        @{ type = 'function'; function = @{
            name = 'read_file'
            description = 'Прочитать текстовый файл по ПОЛНОМУ пути (UTF-8). Возвращает содержимое.'
            parameters = @{ type = 'object'; properties = @{ path = @{ type = 'string'; description = 'полный путь к файлу' } }; required = @('path') }
        } }
        @{ type = 'function'; function = @{
            name = 'write_file'
            description = 'Записать текст в файл (создать или перезаписать) по ПОЛНОМУ пути.'
            parameters = @{ type = 'object'; properties = @{ path = @{ type = 'string' }; content = @{ type = 'string' } }; required = @('path','content') }
        } }
        @{ type = 'function'; function = @{
            name = 'shell'
            description = 'Выполнить команду PowerShell (например, Get-ChildItem, Select-String). Возвращает вывод.'
            parameters = @{ type = 'object'; properties = @{ cmd = @{ type = 'string' } }; required = @('cmd') }
        } }
    )
}

function Invoke-ProbeTool {
    param([string]$Name, $ToolArgs)
    try {
        switch ($Name) {
            'read_file' {
                $path = [string]$ToolArgs.path
                if (-not (Test-Path $path)) { return "ОШИБКА: файл не найден: $path" }
                return (Get-Content $path -Raw -Encoding utf8)
            }
            'write_file' {
                $path = [string]$ToolArgs.path
                $dir = Split-Path $path -Parent
                if ($dir -and -not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
                [System.IO.File]::WriteAllText($path, [string]$ToolArgs.content, (New-Object System.Text.UTF8Encoding($false)))
                return ("OK: записано " + $path + " (" + (Get-Item $path).Length + " байт)")
            }
            'shell' {
                $out = & powershell -NoProfile -Command ([string]$ToolArgs.cmd) 2>&1 | Out-String
                return $out
            }
            default { return "ОШИБКА: неизвестный инструмент: $Name" }
        }
    } catch { return ("ОШИБКА инструмента: " + $_.Exception.Message) }
}

function Invoke-OllamaTools {
    param(
        [string]$Model,
        [array]$Messages,
        [array]$Tools,
        # ДЕФОЛТЫ — ИЗ $CFG (владелец, 16.10.2026). НЕ хардкодить здесь.
        # Если $CFG не загружен — берутся аварийные значения.
        [int]$MaxTurns = $(if ($CFG -and $CFG.Probes) { $CFG.Probes.MaxTurns } else { 8 }),
        [int]$NumCtx = $(if ($CFG -and $CFG.Probes) { $CFG.Probes.NumCtx } else { 16384 }),
        [int]$NumPredict = $(if ($CFG -and $CFG.Probes) { $CFG.Probes.NumPredictMain } else { 8192 }),
        [int]$TimeoutSec = $(if ($CFG -and $CFG.Probes) { $CFG.Probes.TimeoutSec } else { 600 }),
        [double]$Temperature = -1,
        [int]$Seed = $(if ($CFG) { $CFG.Seed } else { 42 }),
        [string]$Uri = $(if ($CFG -and $CFG.Probes) { $CFG.Probes.OllamaUri } else { 'http://localhost:11434/api/chat' })
    )
    $calls = @(); $turns = 0; $answer = ''; $answerSource = ''
    $sumEval = 0; $sumEvalDur = 0; $sumPromptEval = 0; $turnSecs = @()
    $msgs = @($Messages)
    while ($turns -lt $MaxTurns) {
        $turns++
        $opts = @{ num_ctx = $NumCtx; num_predict = $NumPredict }
        if ($Temperature -ge 0) { $opts['temperature'] = $Temperature }
        if ($Seed -ge 0) { $opts['seed'] = $Seed }
        $body = @{
            model    = $Model
            messages = $msgs
            tools    = $Tools
            stream   = $false
            think    = 'low'
            options  = $opts
        } | ConvertTo-Json -Depth 12
        $sw = [System.Diagnostics.Stopwatch]::StartNew()
        $wr = Invoke-WebRequest -Uri $Uri -Method Post -Body ([System.Text.Encoding]::UTF8.GetBytes($body)) `
              -ContentType 'application/json; charset=utf-8' -TimeoutSec $TimeoutSec -UseBasicParsing
        $r = [System.Text.Encoding]::UTF8.GetString($wr.RawContentStream.ToArray()) | ConvertFrom-Json
        $sw.Stop()
        # СКОРОСТЬ: секунды шага + токены генерации (eval_count/eval_duration) — для метрик тестов
        $turnSecs += [math]::Round($sw.Elapsed.TotalSeconds, 2)
        $sumEval += [int]$r.eval_count
        $sumEvalDur += [long]$r.eval_duration
        $sumPromptEval += [int]$r.prompt_eval_count
        $msg = $r.message
        if ($msg.tool_calls -and @($msg.tool_calls).Count -gt 0) {
            $msgs += @{ role = 'assistant'; content = [string]$msg.content; tool_calls = $msg.tool_calls }
            foreach ($tc in $msg.tool_calls) {
                $nm = $tc.function.name
                $ar = $tc.function.arguments
                $calls += @{ name = $nm; args = $ar }
                $res = Invoke-ProbeTool -Name $nm -ToolArgs $ar
                $msgs += @{ role = 'tool'; content = [string]$res }
            }
            continue
        } else {
            $answer = [string]$msg.content
            # ФИКС (владелец, 15.10.2026): у reasoning-моделей ответ может лежать в thinking,
            # а content пуст. Если так — брать thinking (грабли SKILL_stack_characterization §2).
            if ([string]::IsNullOrWhiteSpace($answer) -and $msg.thinking) { $answer = [string]$msg.thinking }
            $answerSource = 'content'
            if ([string]::IsNullOrWhiteSpace([string]$msg.content) -and $msg.thinking) { $answerSource = 'thinking' }
            break
        }
    }
    # ФИКС (владелец, 15.10.2026): если цикл закончился по MaxTurns БЕЗ финального текста,
    # ответ НЕ пустой — он в ПОСЛЕДНЕМ assistant-сообщении. Иначе тест печатал «(пусто)»,
    # хотя модель отвечала (подтверждено: H11 gemma4 — «найдено 196», а тест давал «(пусто)»).
    if ([string]::IsNullOrWhiteSpace($answer)) {
        $lastAsst = @($msgs | Where-Object { $_.role -eq 'assistant' -and -not [string]::IsNullOrWhiteSpace([string]$_.content) })
        if ($lastAsst.Count -gt 0) { $answer = [string]$lastAsst[-1].content; $answerSource = 'last-assistant' }
    }
    $secTotal = [math]::Round((($turnSecs | Measure-Object -Sum).Sum), 2)
    $tps = if ($sumEvalDur -gt 0) { [math]::Round($sumEval / ($sumEvalDur / 1e9), 2) } else { 0 }
    return @{ Answer = $answer; AnswerSource = $answerSource; ToolCalls = $calls; Turns = $turns; Messages = $msgs;
              Sec = $secTotal; TurnSec = $turnSecs; Tokens = $sumEval; Tps = $tps; PromptTokens = $sumPromptEval }
}


# ============================================================================
# ЕДИНЫЙ СТРАЖ + TRACE (методика 14.10.2026) — используется ВСЕМИ пробами.
# ЗАЧЕМ: раньше страж/обрезка/trace КОПИРОВАЛИСЬ в каждую пробу (probe_0/5/7/8/9) — дубль и рассинхрон.
# Set-ProbeGuard заменяет исходный Invoke-ProbeTool своей обёрткой: песочница (запись только внутрь),
# блокировка git-записи/перенаправления, усечение выводов под num_ctx, запись trace-JSONL.
# ВЫЗОВ (в начале пробы, ПОСЛЕ . probe_tools.ps1):
#     Set-ProbeGuard -Sandbox 'D:\AI\PROBA' -TraceFile (Join-Path $logDir ("probeN_trace_"+$stamp+".jsonl")) `
#                    [-ReadLimit 6000] [-ShellLimit 3000]
# ============================================================================
function Write-ProbeTrace {
    param([Parameter(Mandatory)][string]$Tool, $Args, [string]$Result = '', [string]$Origin = 'real', $Extra)
    if (-not $script:ProbeTraceFile) { return }
    $script:ProbeSeq++
    $rec = [ordered]@{ seq = $script:ProbeSeq; ts = (Get-Date -Format 'HH:mm:ss.fff')
                       tool = $Tool; origin = $Origin; args = $Args; result = $Result }
    if ($Extra) { foreach ($k in $Extra.Keys) { $rec[$k] = $Extra[$k] } }
    ($rec | ConvertTo-Json -Compress -Depth 6) | Out-File $script:ProbeTraceFile -Append -Encoding utf8
}

function Set-ProbeGuard {
    param(
        [Parameter(Mandatory)][string]$Sandbox,
        [string]$TraceFile = '',
        [int]$ReadLimit = $(if ($CFG -and $CFG.Probes) { $CFG.Probes.ReadLimit } else { 48000 }),
        [int]$ShellLimit = $(if ($CFG -and $CFG.Probes) { $CFG.Probes.ShellLimit } else { 48000 }),
        [switch]$DenyGitWrite
    )
    # ВАЖНО: PowerShell НЕ имеет замыканий — все настройки держим ТОЛЬКО в $script:,
    # иначе обёртка их не увидит (грабля 14.10.2026: git-блокировка молча НЕ работала).
    $script:ProbeGuardSandbox = $Sandbox
    $script:ProbeReadLimit    = $ReadLimit
    $script:ProbeShellLimit   = $ShellLimit
    $script:ProbeSeq          = 0
    $script:ProbeTraceFile    = $TraceFile
    $script:ProbeDenyGitWrite = if ($DenyGitWrite) { $true } else { $true }   # всегда запрещено
    if ($TraceFile) { Remove-Item $TraceFile -Force -ErrorAction SilentlyContinue }

    # запомнить исходный инструмент (один раз) — обёртка будет звать его напрямую
    if (-not $script:ProbeBareTool) { $script:ProbeBareTool = ${function:Invoke-ProbeTool} }

    function global:Invoke-ProbeTool {
        param([string]$Name, $ToolArgs)
        $sandbox = $script:ProbeGuardSandbox
        $bare    = $script:ProbeBareTool
        if ($Name -eq 'read_file') {
            $raw = [string](& $bare -Name $Name -ToolArgs $ToolArgs)
            # УСЕЧЕНИЕ КАК В CLINE (15.10.2026): начало+конец 50/50, хвост СОХРАНЯЕТСЯ.
            #   Cline (extension.js, Ike): maxChars=48000, при превышении берёт slice(0,half)
            #   + '[... truncated ...]' + slice(-half). Наш прежний вариант резал ТОЛЬКО начало
            #   -> терялся конец файла (напр. §5.4 КРАШ/REVIVE в конце закона).
            $short = $raw
            if ($raw.Length -gt $script:ProbeReadLimit) {
                $half = [int][Math]::Ceiling($script:ProbeReadLimit / 2)
                $tailLen = [Math]::Max(1, $script:ProbeReadLimit - $half)
                $short = $raw.Substring(0, $half) + "`n...[СТЕНД: усечено; всего " + $raw.Length + " симв., показаны начало+конец]`n" + $raw.Substring($raw.Length - $tailLen)
            }
            Write-ProbeTrace -Tool $Name -Args $ToolArgs -Result $short -Origin 'real'
            return $short
        }
        if ($Name -eq 'write_file') {
            $p = [string]$ToolArgs.path
            if (-not ($p -and $p.StartsWith($sandbox, [StringComparison]::OrdinalIgnoreCase))) {
                $m = "BLOCKED (вне песочницы): писать можно только внутрь $sandbox."
                Write-ProbeTrace -Tool $Name -Args $ToolArgs -Result $m -Origin 'blocked'
                return $m
            }
            $res = [string](& $bare -Name $Name -ToolArgs $ToolArgs)
            Write-ProbeTrace -Tool $Name -Args $ToolArgs -Result $res -Origin 'real'
            return $res
        }
        if ($Name -eq 'shell') {
            $cmd = [string]$ToolArgs.cmd
            if ($script:ProbeDenyGitWrite -and $cmd -match '(?i)(git\s+(add|commit|push|reset|checkout|rebase|merge|stash|apply|rm)|>(?!\$null))') {
                $m = 'BLOCKED: git-запись и перенаправление в файл запрещены. ПОВТОРИ без них.'
                Write-ProbeTrace -Tool $Name -Args $ToolArgs -Result $m -Origin 'blocked'
                return $m
            }
            if ($cmd -match '(?i)(Remove-Item|Move-Item|Rename-Item|New-Item|Set-Content|Add-Content|Out-File|Copy-Item|rmdir|\bdel\b)') {
                $paths = @([regex]::Matches($cmd, '(?i)[A-Z]:\\[^\s"'';|)]+') | ForEach-Object { $_.Value })
                $outside = @($paths | Where-Object { $_ -notlike "$sandbox*" })
                if ($outside.Count -gt 0) {
                    $m = "BLOCKED (вне песочницы): изменять можно только внутри $sandbox. Наружу: $($outside -join ', ')."
                    Write-ProbeTrace -Tool $Name -Args $ToolArgs -Result $m -Origin 'blocked'
                    return $m
                }
            }
            $prev = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
            # 🔴 ФИКС 18.10.2026 (РЫЧАГ 38): модель часто присылает команду УЖЕ обёрнутой
            # в свой `powershell -Command "..."`. Обёртка стенда добавляла ВТОРОЙ слой →
            # вывод искажался (живой факт: `-Filter 'SKILL_*.md' -Path 'D:\AI\repo'` давал 446 вместо 199).
            # Пробы: A) без вложенного = 199 ✅ · B) с вложенным = 446 ❌ · C) вложенный без -Path = 0.
            # ЛЕЧЕНИЕ: если $cmd уже содержит вызов powershell — снять внешний слой и запустить
            # команду В ТЕКУЩЕЙ сессии через ScriptBlock (Set-Location + $cmd в одном процессе).
            $cmdRaw = $cmd
            $inner  = $null
            if ($cmd -match '(?is)^\s*powershell(\.exe)?\s+(-NoProfile\s+)?-Command\s+["'']?(.*?)["'']?\s*$') {
                $inner = $Matches[3]
                $inner = $inner.Trim()
                if ($inner.StartsWith('"') -and $inner.EndsWith('"') -and $inner.Length -gt 2) { $inner = $inner.Substring(1, $inner.Length - 2) }
                elseif ($inner.StartsWith("'") -and $inner.EndsWith("'") -and $inner.Length -gt 2) { $inner = $inner.Substring(1, $inner.Length - 2) }
            }
            $useCmd = if ($inner) { $inner } else { $cmdRaw }
            try {
                # ScriptBlock в ТЕКУЩЕЙ сессии — без второго процесса и без двойного вывода.
                $sb = [ScriptBlock]::Create("Set-Location -LiteralPath '$sandbox'; " + $useCmd)
                $res = (& $sb 2>&1 | Out-String)
            } catch {
                # запасной путь: если ScriptBlock не собрался — прежний способ, но БЕЗ второго powershell
                $res = (& powershell -NoProfile -Command ("Set-Location -LiteralPath '$sandbox'; " + $useCmd) 2>&1 | Out-String)
            }
            finally { $ErrorActionPreference = $prev }
            $res = ([string]$res) -replace "`r", ''
            if ($res.Length -gt $script:ProbeShellLimit) {
                # УСЕЧЕНИЕ КАК В CLINE: начало+конец 50/50 (резать СЕРЕДИНУ).
                $half = [int][Math]::Ceiling($script:ProbeShellLimit / 2)
                $tailLen = [Math]::Max(1, $script:ProbeShellLimit - $half)
                $res = $res.Substring(0, $half) + "`n...[СТЕНД: усечено; всего " + $res.Length + " симв., вырезана середина]`n" + $res.Substring($res.Length - $tailLen)
            }
            Write-ProbeTrace -Tool $Name -Args $ToolArgs -Result $res -Origin 'real'
            return $res
        }
        return (& $bare -Name $Name -ToolArgs $ToolArgs)
    }
}

# Прочитать trace-JSONL как объекты (для суда «читал/выдумал» и ROUTE_DEPTH).
function Get-ProbeTrace {
    param([string]$TraceFile)
    if (-not $TraceFile) { $TraceFile = $script:ProbeTraceFile }
    if (-not (Test-Path $TraceFile)) { return @() }
    return @(Get-Content $TraceFile -Encoding utf8 | Where-Object { $_.Trim() } | ForEach-Object { try { $_ | ConvertFrom-Json } catch {} })
}

