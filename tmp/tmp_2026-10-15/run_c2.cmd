@echo off
powershell -NoProfile -ExecutionPolicy Bypass -File "D:\AI\AGENT_SETTINGS\checks\agentic\check_2_read.ps1" -Models all -Law 32 -Seed 42 > "D:\AI\AGENT_SETTINGS\tmp\out\_c2read.txt" 2>&1
