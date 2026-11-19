@echo off
setlocal
cd /d "%~dp0"

echo === AntiDPI tray: uninstall ===
echo One UAC prompt - it stops AntiDPI and removes scheduler tasks.
echo.
powershell.exe -NoLogo -NoProfile -Command "try { Start-Process powershell.exe -Verb RunAs -ArgumentList '-NoLogo -NoProfile -ExecutionPolicy Bypass -File \"%~dp0uninstall.ps1\"' } catch { Write-Host 'UAC declined - nothing removed.'; Start-Sleep 5 }"
pause
