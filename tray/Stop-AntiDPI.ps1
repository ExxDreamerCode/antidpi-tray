#requires -Version 5.1
$ErrorActionPreference = 'Stop'
$processes = Get-Process -Name 'winws2' -ErrorAction SilentlyContinue
if($processes){
    $processes | Stop-Process -Force
    $processes | Wait-Process -Timeout 10 -ErrorAction SilentlyContinue
    Write-Host 'AntiDPI stopped.'
}else{
    Write-Host 'AntiDPI not running.'
}
exit 0
