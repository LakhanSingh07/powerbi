@echo off
setlocal
set "DIR=C:\Users\Admin\Downloads\Power-BI-Design-Files-main\Power-BI-Design-Files-main\Full Dashboards\Agents Performance - Dashboard"
cd /d "%DIR%"
start "PBIP Watcher" powershell -NoProfile -ExecutionPolicy Bypass -File "%DIR%\pbip-watch.ps1" -CommitOnChange
start "PBIP Server" powershell -NoProfile -ExecutionPolicy Bypass -File "%DIR%\pbip-server.ps1"
exit /b 0
