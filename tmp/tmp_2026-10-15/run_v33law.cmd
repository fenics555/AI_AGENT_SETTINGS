@echo off
powershell -NoProfile -ExecutionPolicy Bypass -File "D:\AI\AGENT_SETTINGS\checks\agentic\check_1_law.ps1" -Models all -Law 33 -OnlyTasks L1_read -Seed 42 > "D:\AI\AGENT_SETTINGS\tmp\out\_v33law.txt" 2>&1
