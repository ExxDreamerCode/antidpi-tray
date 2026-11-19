@echo off
chcp 65001 >nul
echo AntiDPI status:
tasklist | findstr /i "winws2"
if errorlevel 1 (
    echo.
    echo AntiDPI is NOT running (winws2 not found).
) else (
    echo.
    echo AntiDPI is RUNNING.
)
echo.
pause
