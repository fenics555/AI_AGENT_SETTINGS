@echo off
powershell -NoProfile -ExecutionPolicy Bypass -File "D:\AI\AGENT_SETTINGS\checks\agentic\check_3_skills.ps1" -Models gemma4 -Rulesets 26 -OnlyTasks T14_marker -Seed 42 > "D:\AI\AGENT_SETTINGS\tmp\out\_c3.txt" 2>&1
