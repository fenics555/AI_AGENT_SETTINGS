$root='D:\AI\AGENT_SETTINGS\checks\agentic'
foreach ($k in '01','02','03','04') {
    & "$root\run_tests.ps1" -Rulesets $k
}
