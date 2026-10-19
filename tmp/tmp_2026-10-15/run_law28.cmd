@echo off
powershell -NoProfile -ExecutionPolicy Bypass -File "D:\AI\AGENT_SETTINGS\checks\agentic\check_1_law.ps1" -Models all -Law 28 -OnlyTasks L1_read -Seed 42 > "D:\AI\AGENT_SETTINGS\tmp\out\_law28.txt" 2>&1
