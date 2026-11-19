@echo off
net session >nul 2>&1
if %errorlevel%==0 goto :elevated

powershell.exe -NoLogo -NoProfile -Command "try { Start-Process powershell.exe -Verb RunAs -ArgumentList '-NoLogo -NoProfile -ExecutionPolicy Bypass -File \"%~dp0Create-Tasks.ps1\"' } catch { Write-Host 'UAC declined - tasks not created.'; Start-Sleep 5 }"
goto :eof

:elevated
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0Create-Tasks.ps1"
