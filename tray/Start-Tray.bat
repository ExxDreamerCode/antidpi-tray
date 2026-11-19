@echo off
set "PYW="
for /f "delims=" %%p in ('where pythonw.exe 2^>nul') do (
  if not defined PYW set "PYW=%%p"
)
if not defined PYW set "PYW=pythonw.exe"
start "" "%PYW%" "%~dp0AntiDPI_Tray.py"
