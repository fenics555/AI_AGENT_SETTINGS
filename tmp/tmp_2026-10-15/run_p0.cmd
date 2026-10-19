@echo off
powershell -NoProfile -ExecutionPolicy Bypass -File "D:\AI\AGENT_SETTINGS\probes\probe_0_recon.ps1" -Models %1 -Rules %2 > "D:\AI\AGENT_SETTINGS\tmp\out\_ro.txt" 2>&1
