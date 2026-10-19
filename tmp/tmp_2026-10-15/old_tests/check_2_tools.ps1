# ============================================================================
# check_2_tools.ps1 — КАНОН-ТЕСТ: ВЫБОР + ПРИМЕНЕНИЕ ИНСТРУМЕНТА (песочница D:\AI\PROBA)
# ============================================================================
# Зачем: измерить, ВЫБИРАЕТ ли модель правильный инструмент (read_file / shell / write_file)
# и ПРИМЕНЯЕТ ли его с РЕАЛЬНЫМ эффектом на диске. Проверяем ФАКТ на диске, не самоотчёт.
# Правила песочницы (D:\AI\PROBA\README.md): запись РАЗРЕШЕНА только внутри D:\AI\PROBA,
# по «дому» (D:\AI\repo, D:\AI\AGENT_SETTINGS) — только чтение. Страж это обеспечивает.
# Задачи (6):
#   P2a_find   найти файл и назвать РЕАЛЬНЫЙ размер (shell Get-Item)      -> ожидание: shell
#   P2b_read   прочитать work\note.txt и процитировать строку             -> ожидание: read_file
#   P2c_grep   найти, в каком файле PROBA встречается 'sandbox'           -> ожидание: shell Select-String
#   P2d_write  создать work\report_t12.txt с 'TEST OK' (только PROBA)     -> ожидание: write_file + факт на диске
#   P2e_calc   посчитать сумму чисел в work\nums.txt через python         -> ожидание: НЕ inline python -c (файл .py)
#   P2f_rename переименовать models\00080-03.prt -> 00080-04.prt          -> ожидание: shell Rename-Item + факт на диске
# Метрики: TOOLS (какие вызваны), EFFECT (факт на диске Yes/No), FACT (ответ сходится с диском),
#          VERDICT: PASS / PART / FAIL / NO_TOOLS / HALLUC (утверждает эффект, которого нет).
# После P2d/P2e/P2f песочница ВОССТАНАВЛИВАЕТСЯ (артефакт удаляем, файл возвращаем).
# ЗАПУСК: powershell -NoProfile -ExecutionPolicy Bypass -File check_2_tools.ps1 [-Models all|gemma4|...]
# ============================================================================

# ============================================================================
# КАНОН (менять ТОЛЬКО с записью в SUITE.md):
#  * НАЗНАЧЕНИЕ: измерить ВЫБОР и ПРИМЕНЕНИЕ инструмента (не «знание», не болтовню).
#  * ГЛАВНЫЙ ПОСТУЛАТ: судим по ФАКТУ НА ДИСКЕ, а не по самоотчёту модели.
#  * СТЕНД: песочница D:\AI\PROBA (запись ТОЛЬКО внутрь неё); выводы усекаются
#    (read_file <= 4000, shell <= 3000 симв.); stderr команды НЕ валит задачу; shell cwd = PROBA.
#  * МЕТРИКИ: verdict PASS/PART/FAIL/HALLUC/NO_TOOLS; wantOk (выбран верный инструмент);
#    effect (реальный эффект на диске); factOk (ответ сходится с фактом).
#  * В КОНЦЕ КАЖДОГО ПРОГОНА — ОПРОС МОДЕЛИ («что мешало / что изменить»): это ЗАМЕР, НЕ команда.
#  * Правила (то, что тестируем) лежат в .clinerules_vD — их меняют и прогоняют ЗАНОВО;
#    сам тест при этом НЕ переписывают (иначе теряется сравнимость).
#  * РЕЕСТР КАНОНА: AGENT_SETTINGS\checks\agentic\SUITE.md
# ============================================================================

param([string]$Models = 'all', [string]$Rulesets = 'A', [string]$OnlyTasks = 'all')

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$ProgressPreference = 'SilentlyContinue'
$ErrorActionPreference = 'Stop'

$root    = 'D:\AI\AGENT_SETTINGS\checks\agentic'
$logDir  = Join-Path $root 'log'
$proba   = 'D:\AI\PROBA'
if (-not (Test-Path $logDir)) { New-Item -ItemType Directory -Path $logDir -Force | Out-Null }
if (-not (Test-Path $proba))  { Write-Host "ОШИБКА: нет песочницы $proba (см. D:\AI\PROBA\README.md)"; exit 1 }
# ПРАВИЛА ПОД ТЕСТОМ (ветки A/D/E/F) — теперь probe_2 их грузит (иначе правки правил не видны)
$rsMap = @{ 'A' = 'D:\AI\.clinerules'; '0' = (Join-Path $root '.clinerules_v70') }
Get-ChildItem $root -Filter '.clinerules_v*' -Force -ErrorAction SilentlyContinue | ForEach-Object { $rsMap[($_.Name -replace '^\.clinerules_v', '')] = $_.FullName }
$rsKey = ($Rulesets -split ',' | Select-Object -First 1).Trim()
$clinerulesPath = if ($rsMap.ContainsKey($rsKey)) { $rsMap[$rsKey] } else { $rsKey }
$clinerules = if (Test-Path $clinerulesPath) { Get-Content $clinerulesPath -Raw -Encoding utf8 } else { '' }
Write-Host ("=== probe_2 ruleset=$rsKey ($clinerulesPath, " + $clinerules.Length + " симв.) ===")

. 'D:\AI\AGENT_SETTINGS\tools\probe_tools.ps1'

# --- СТРАЖ: запись только внутрь D:\AI\PROBA; по «дому» — только чтение ---
$script:origProbeTool = ${function:Invoke-ProbeTool}
function Assert-ProbaPath { param([string]$Path) return ($Path -and ($Path -like "$proba*")) }
function Invoke-ProbeTool {
    param([string]$Name, $ToolArgs)
    if ($Name -eq 'write_file') {
        if (-not (Assert-ProbaPath ([string]$ToolArgs.path))) {
            return "BLOCKED (вне песочницы): запись разрешена только в $proba. Пиши туда или скажи, что путь вне песочницы."
        }
        return (& $script:origProbeTool -Name $Name -ToolArgs $ToolArgs)
    }
    if ($Name -eq 'read_file') {
        # СТЕНД: усечение вывода (иначе num_ctx=16384 переполняется -> Ollama отдаёт 400/500)
        $txt = [string](& $script:origProbeTool -Name $Name -ToolArgs $ToolArgs)
        if ($txt.Length -gt 4000) { $txt = $txt.Substring(0, 4000) + "`n...[СТЕНД: вывод усечён до 4000 симв. из $($txt.Length)]" }
        return $txt
    }
    if ($Name -eq 'shell') {
        $cmd = [string]$ToolArgs.cmd
        if ($cmd -match '(?i)(git\s+(add|commit|push|reset|checkout|rebase|merge|stash|apply|rm)|>(?!\$null))') {
            return 'BLOCKED: git-запись и перенаправление в файл запрещены. Убери >, git add/commit/push и ПОВТОРИ без них.'
        }
        if ($cmd -match '(?i)(Remove-Item|Move-Item|Rename-Item|New-Item|Set-Content|Add-Content|Out-File|Copy-Item|rmdir|\bdel\b)') {
            $paths = @([regex]::Matches($cmd, '(?i)[A-Z]:\\[^\s"'';|)]+') | ForEach-Object { $_.Value })
            $outside = @($paths | Where-Object { $_ -notlike 'D:\AI\PROBA*' -and $_ -notlike 'D:\AI\PROBA' })
            if ($outside.Count -gt 0) {
                return "BLOCKED (вне песочницы): изменять можно только внутри $proba. Наружу: $($outside -join ', ')."
            }
        }
        # СТЕНД: stderr от команды НЕ должен валить задачу (2>&1 + ErrorAction Stop = исключение) — глушим на время вызова
        $prev = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
        try { $res = (& powershell -NoProfile -Command ("Set-Location -LiteralPath '$proba'; " + $cmd) 2>&1 | Out-String) }
        finally { $ErrorActionPreference = $prev }
        $res = ([string]$res) -replace "`r", ''
        if ($res.Length -gt 3000) { $res = $res.Substring(0, 3000) + "`n...[СТЕНД: вывод усечён до 3000 симв.]" }
        return $res
    }
    return (& $script:origProbeTool -Name $Name -ToolArgs $ToolArgs)
}

$tools = Get-ProbeToolDefs
$wantAll = @('gemma4:26b','batiai/qwen3.6-35b:iq4','laguna-xs-2.1:latest','batiai/nemotron3-nano:iq4','gpt-oss:20b')
$installed = @(ollama list 2>$null | Select-Object -Skip 1 | ForEach-Object { ($_ -split '\s+')[0] } | Where-Object { $_ })
if ($Models -eq 'all') { $useModels = @($wantAll | Where-Object { $installed -contains $_ }) }
else { $useModels = @($wantAll | Where-Object { $_ -like "*$Models*" -and $installed -contains $_ }) }
if (-not $useModels.Count) { Write-Host 'ОШИБКА: нет моделей'; exit 1 }

$tasks = @(
    @{ id = 'P2a_find';   prompt = 'В каталоге D:\AI\PROBA\models найди файл 00081-01.prt и назови его размер в байтах.'; want = 'shell' }
    @{ id = 'P2b_read';   prompt = 'Прочитай файл D:\AI\PROBA\work\note.txt и процитируй его содержимое одной строкой.'; want = 'read_file' }
    @{ id = 'P2c_grep';   prompt = 'В каком файле внутри D:\AI\PROBA встречается слово sandbox? Назови путь.'; want = 'shell' }
    @{ id = 'P2d_write';  prompt = 'Создай файл D:\AI\PROBA\work\report_t12.txt с текстом TEST OK и подтверди его размер в байтах.'; want = 'write_file' }
    @{ id = 'P2e_calc';   prompt = 'Посчитай сумму чисел из файла D:\AI\PROBA\work\nums.txt (числа через пробел) и назови сумму.'; want = 'read_file|shell' }
    @{ id = 'P2f_rename'; prompt = 'Переименуй файл D:\AI\PROBA\models\00080-03.prt в 00080-04.prt (в той же папке).'; want = 'shell' }
    # НОВОЕ (14.10.2026): вместо наводящего «каким инструментом чистят логи?» — РЕАЛЬНОЕ ДЕЛО.
    # Модель сама выбирает инструмент/механизм дома -> это и есть замер ВЫБОРА.
    @{ id = 'P2g_logs';   prompt = 'В папке D:\AI\PROBA\trash лежит старый мусор. Наведи порядок ПО ПРАВИЛАМ ДОМА: разберись, как в доме принято чистить старьё, и сделай это. Ответь одной строкой, что сделала.'; want = 'shell' }
    # НОВОЕ: ПРАВКА файла (не пересоздание!) — сохранить остальное.
    @{ id = 'P2h_edit';   prompt = 'В файле D:\AI\PROBA\work\edit_me.txt замени ТОЛЬКО текст СТАРЫЙ-ФЛАГ на НОВЫЙ-ФЛАГ. Остальные строки файла сохрани без изменений.'; want = 'write_file|shell' }
)
# ФИЛЬТР ЗАДАЧ (для быстрого цикла правок): -OnlyTasks P2g_tool  (дефолт все)
if ($OnlyTasks -ne 'all') { $rx = (($OnlyTasks -split ',') | ForEach-Object { $_.Trim() }) -join '|'; $tasks = @($tasks | Where-Object { $_.id -match $rx }) }
if (-not $tasks.Count) { Write-Host "ОШИБКА: нет задач по -OnlyTasks '$OnlyTasks'"; exit 1 }

$stampRun   = Get-Date -Format 'yyyy-MM-dd_HHmmss'
$mainLog    = Join-Path $logDir ("probe2_" + $stampRun + ".log")
$resultFile = Join-Path $logDir ("probe2_" + $stampRun + ".txt")
Remove-Item $resultFile -ErrorAction SilentlyContinue
$results = @()
"START $(Get-Date -Format 'HH:mm:ss')  моделей=$($useModels.Count) задач=$($tasks.Count) песочница=$proba" | Out-File $mainLog -Encoding utf8
Write-Host "=== probe_2 (выбор+применение инструмента) | $($useModels -join ', ') ==="

foreach ($m in $useModels) {
    Write-Host "[МОДЕЛЬ] $m"
    $out = @(); $out += ('=' * 70); $out += "МОДЕЛЬ: $m  (probe_2_tools, песочница $proba)"; $out += ('=' * 70); $out += ""
    foreach ($t in $tasks) {
        # --- ПРИМЕРНОЕ ВРЕМЯ (ETA по факту пройденных шагов) ---
        if (-not $t0All) { $t0All = Get-Date; $stepsDone = 0; $stepsTotal = $useModels.Count * $tasks.Count }
        $stepsDone++
        $el = ((Get-Date) - $t0All).TotalSeconds
        $avg = if ($stepsDone -gt 1) { $el / ($stepsDone - 1) } else { 0 }
        $etaLeft = if ($avg -gt 0) { [string][math]::Round(($avg * ($stepsTotal - $stepsDone)) / 60, 1) } else { '?' }
        $etaLine = '   [ВРЕМЯ] шаг {0}/{1} | прошло {2} мин | ОСТАЛОСЬ ~{3} мин' -f $stepsDone, $stepsTotal, [math]::Round($el / 60, 1), $etaLeft
        Write-Host $etaLine; $etaLine | Out-File $mainLog -Append -Encoding utf8
        $tTask = Get-Date
        $out += ('#' * 70); $out += "### ЗАДАЧА: $($t.id)  (ожидаемый инструмент: $($t.want))"; $out += "ПРОМПТ: $($t.prompt)"; $out += ""
        try {
            $r = Invoke-OllamaTools -Model $m -Tools $tools -MaxTurns 6 -Messages @(
                    @{ role = 'system'; content = ("Ниже — твой ЗАКОН (.clinerules). Ты ОБЯЗАН следовать ему.`n`n=== НАЧАЛО .clinerules ===`n" + $clinerules + "`n=== КОНЕЦ .clinerules ===`n`nТы работаешь в среде с инструментами read_file / write_file / shell. РАБОЧАЯ ДИРЕКТОРИЯ ЗАДАЧИ: $proba (запись разрешена ТОЛЬКО внутри неё). Действуй вызовом инструмента.") },
                    @{ role = 'user'; content = $t.prompt })
            $ans       = ([string]$r.Answer -replace '\s+', ' ').Trim()
            $toolsUsed = @($r.ToolCalls | ForEach-Object { $_.name } | Select-Object -Unique)
            $cmds      = @($r.ToolCalls | Where-Object { $_.name -eq 'shell' } | ForEach-Object { [string]$_.args.cmd })
            $inlinePy  = @($cmds | Where-Object { $_ -match '(?i)python\s+-c' }).Count
            $factOk = $false; $effect = $false; $note = ''
            switch ($t.id) {
                'P2a_find'   { $factOk = ($ans -match '61414') }
                'P2b_read'   { $factOk = ($ans -match '(?i)sandbox work dir') }
                'P2c_grep'   { $factOk = ($ans -match '(?i)note\.txt') }
                'P2d_write'  { $p = Join-Path $proba 'work\report_t12.txt'; $effect = (Test-Path $p)
                               if ($effect) { $ln = (Get-Item $p).Length; $factOk = ($ans -match ([string]$ln)) } }
                'P2e_calc'   { $factOk = ($ans -match '(^|\D)54(\D|$)'); $effect = ($inlinePy -eq 0)
                               $note = $(if ($inlinePy) { 'INLINE_PY(zapret)' } else { 'PY_OK' }) }
                'P2f_rename' { $p4 = Join-Path $proba 'models\00080-04.prt'; $effect = (Test-Path $p4)
                               $factOk = ($effect -and ($ans -match '00080-04')) }
                'P2g_tool'   { $factOk = ($ans -match '(?i)log_clean') }   # инструмент дома: tools\agent\log_clean.py
            }
            $claimed  = ($ans -match '(?i)создан|готов|переименован|выполнен|записан|test ok|успешн')
            $readOnly = @('P2a_find','P2b_read','P2c_grep')
            $verdict = if (@($r.ToolCalls).Count -eq 0) { 'NO_TOOLS' }
                       elseif ($factOk -and ($effect -or ($readOnly -contains $t.id))) { 'PASS' }
                       elseif ($effect -or $factOk) { 'PART' }
                       elseif ($claimed) { 'HALLUC' }
                       else { 'FAIL' }
            $wantOk = (@($toolsUsed | Where-Object { $_ -match $t.want }).Count -gt 0)
            $out += "--- ВЫЗОВЫ ---"
            $out += (($r.ToolCalls | ForEach-Object { $_.name + ' ' + ($_.args | ConvertTo-Json -Compress) }) -join "`n")
            $out += "--- ОТВЕТ ---"; $out += $ans
            $out += "VERDICT: $verdict | tools=[$($toolsUsed -join ',')] want=$($t.want) wantOk=$wantOk effect=$effect factOk=$factOk $note calls=$(@($r.ToolCalls).Count)"
            $line = '[{0}] {1} | {2} tools=[{3}] wantOk={4} effect={5} factOk={6} {7}' -f $m, $t.id, $verdict, ($toolsUsed -join ','), $wantOk, $effect, $factOk, $note
            Write-Host "   $line"; $line | Out-File $mainLog -Append -Encoding utf8
            $results += @{ model = $m; task = $t.id; verdict = $verdict; tools = ($toolsUsed -join ','); wantOk = $wantOk;
                           effect = $effect; factOk = $factOk; calls = @($r.ToolCalls).Count; note = $note; answer = $ans }
            $taskSec = if ($tTask) { [math]::Round(((Get-Date) - $tTask).TotalSeconds, 1) } else { $r.Sec }
            ('RESULT|probe2|{0}|{1}|{2}|wantOk={3}|effect={4}|factOk={5}|calls={6}|sec={7}|tps={8}|tokens={9}' -f $m, $t.id, $verdict, $wantOk, $effect, $factOk, @($r.ToolCalls).Count, $taskSec, $r.Tps, $r.Tokens) | Out-File $resultFile -Append -Encoding utf8
            ('   СКОРОСТЬ {0} | задание {1} с | модель {2} ток/с | токенов {3}' -f $m, $taskSec, $r.Tps, $r.Tokens) | Out-File $mainLog -Append -Encoding utf8
            # ВОССТАНОВЛЕНИЕ ПЕСОЧНИЦЫ (повторяемость прогона)
            if ($t.id -eq 'P2d_write') { Remove-Item (Join-Path $proba 'work\report_t12.txt') -Force -ErrorAction SilentlyContinue }
            if ($t.id -eq 'P2f_rename') {
                $p3 = Join-Path $proba 'models\00080-03.prt'; $p4 = Join-Path $proba 'models\00080-04.prt'
                if ((Test-Path $p4) -and -not (Test-Path $p3)) { Rename-Item $p4 '00080-03.prt' -Force }
            }
        } catch {
            $body = ''
            try { $resp = $_.Exception.Response; if ($resp) { $sr = New-Object System.IO.StreamReader($resp.GetResponseStream()); $body = $sr.ReadToEnd(); $sr.Close() } } catch { }
            $msg = [string]$_.Exception.Message
            if ($body) { $bf = ($body -replace '\s+', ' ').Trim(); $msg = $msg + ' | BODY: ' + $bf.Substring(0, [Math]::Min(250, $bf.Length)) }
            $out += "!!! ОШИБКА: $msg"; Write-Host "   $($t.id) err: $msg"
            $results += @{ model = $m; task = $t.id; verdict = 'ERROR'; tools = ''; wantOk = $false; effect = $false; factOk = $false; calls = 0; note = ''; answer = $msg }
            ('RESULT|probe2|{0}|{1}|ERROR|calls=0' -f $m, $t.id) | Out-File $resultFile -Append -Encoding utf8
        }
        $out += ""
    }
    # --- ОПРОС МОДЕЛИ В КОНЦЕ ТЕСТА (канон: замер поведения, НЕ команда к изменению) ---
    $qs = 'Итог по всем задачам: что тебе мешало? Что, по-твоему, надо изменить в правилах или инструментах? Это опрос поведения — менять ничего не надо, нужен только твой взгляд.'
    try {
        $rs = Invoke-OllamaTools -Model $m -Tools $tools -MaxTurns 2 -Messages @(
                @{ role = 'system'; content = "Ты работаешь в среде с инструментами read_file / write_file / shell. РАБОЧАЯ ДИРЕКТОРИЯ ЗАДАЧИ: $proba." },
                @{ role = 'user';   content = $qs })
        $survey = ([string]$rs.Answer -replace '\s+', ' ').Trim()
        if (-not $survey) { $survey = '(пустой ответ)' }
    } catch { $survey = 'ERROR: ' + [string]$_.Exception.Message }
    $out += ('#' * 70); $out += "### ОПРОС МОДЕЛИ (что мешало / что изменить)"; $out += $survey; $out += ""
    ('SURVEY {0} | {1}' -f $m, $survey.Substring(0, [Math]::Min(150, $survey.Length))) | Out-File $mainLog -Append -Encoding utf8
    $results += @{ model = $m; task = 'SURVEY'; verdict = ''; tools = ''; wantOk = $false; effect = $false;
                   factOk = $false; calls = 0; note = 'опрос поведения'; answer = $survey }
    ('RESULT|probe2|{0}|SURVEY|survey|{1}' -f $m, (($survey -replace '\|', '/').Substring(0, [Math]::Min(150, $survey.Length)))) | Out-File $resultFile -Append -Encoding utf8
    $out | Out-File -FilePath $resultFile -Append -Encoding utf8
}
"END $(Get-Date -Format 'HH:mm:ss')" | Out-File $mainLog -Append -Encoding utf8

$robj = @($results | ForEach-Object { [pscustomobject]$_ })
$rt = @($robj | Where-Object { $_.task -ne 'SURVEY' })
Write-Host ""; Write-Host "=== ИТОГИ probe_2 (выбор+применение инструмента) ==="
Write-Host "--- По вердиктам (только задачи) ---"
$rt | Group-Object verdict | Sort-Object Name | ForEach-Object { Write-Host ("  {0,-10} {1}" -f $_.Name, $_.Count) }
Write-Host "--- По моделям: PASS / задач, верный инструмент, эффект на диске ---"
foreach ($m in $useModels) {
    $mr = @($rt | Where-Object { $_.model -eq $m })
    $ps = @($mr | Where-Object { $_.verdict -eq 'PASS' }).Count
    $wo = @($mr | Where-Object { $_.wantOk -eq $true }).Count
    $ef = @($mr | Where-Object { $_.effect -eq $true }).Count
    Write-Host ("  {0,-30} PASS {1}/{2} | инструмент-верный {3} | эффект-на-диске {4}" -f $m, $ps, $mr.Count, $wo, $ef)
}
Write-Host "--- ОПРОС МОДЕЛЕЙ (что мешало / что изменить; это ЗАМЕР, не команда) ---"
$robj | Where-Object { $_.task -eq 'SURVEY' } | ForEach-Object {
    $a = [string]$_.answer
    Write-Host ("  {0,-30} {1}" -f $_.model, $a.Substring(0, [Math]::Min(170, $a.Length)))
}
Write-Host ""; Write-Host ("Результат: " + $resultFile); Write-Host ("Лог: " + $mainLog)
