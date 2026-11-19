@echo off
chcp 65001 >nul
echo Stopping AntiDPI...
schtasks /run /tn "AntiDPI Stop"
echo.
pause

