@echo off
powershell -NoProfile -ExecutionPolicy Bypass -File "D:\AI\AGENT_SETTINGS\probes\probe_7_write.ps1" -Models all -Rules v26 > "D:\AI\AGENT_SETTINGS\tmp\out\_p7.txt" 2>&1
