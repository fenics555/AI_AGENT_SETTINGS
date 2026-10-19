@echo off
powershell -NoProfile -ExecutionPolicy Bypass -File "D:\AI\AGENT_SETTINGS\checks\agentic\check_3_skills.ps1" -Models all -Rulesets 26 -OnlyTasks T13_creo -Seed 42 > "D:\AI\AGENT_SETTINGS\tmp\out\_c3creo.txt" 2>&1
