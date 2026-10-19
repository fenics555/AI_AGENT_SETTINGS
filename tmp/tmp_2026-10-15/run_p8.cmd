@echo off
powershell -NoProfile -ExecutionPolicy Bypass -File "D:\AI\AGENT_SETTINGS\probes\probe_8_skills.ps1" -Models all -Rules v26 > "D:\AI\AGENT_SETTINGS\tmp\out\_p8.txt" 2>&1
