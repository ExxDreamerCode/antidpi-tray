@echo off
setlocal
cd /d "%~dp0"

echo === AntiDPI tray: install ===
echo Engine sources are pinned by commit and verified by SHA256.
echo.

powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0install.ps1" -TraySource "%~dp0tray" %*
if errorlevel 1 (
    echo.
    echo Install FAILED. See messages above.
    pause
    exit /b 1
)

echo.
echo Creating scheduler tasks - one UAC prompt, the last one you will see...
powershell.exe -NoLogo -NoProfile -Command "try { Start-Process powershell.exe -Verb RunAs -ArgumentList '-NoLogo -NoProfile -ExecutionPolicy Bypass -File \"%~dp0tray\Create-Tasks.ps1\"' } catch { Write-Host 'UAC declined - tasks NOT created. Run tray\Create-Tasks.bat later.'; Start-Sleep 5 }"

echo.
echo Done. The tray will appear now.
set "PYW="
for /f "delims=" %%p in ('where pythonw.exe 2^>nul') do (
  if not defined PYW set "PYW=%%p"
)
if not defined PYW set "PYW=pythonw.exe"
start "" "%PYW%" "C:\Igareck_AntiDPI\Igareck\AntiDPI_Tray.py"
pause
