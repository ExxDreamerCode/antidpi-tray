#requires -Version 5.1
param([switch]$KeepTasks)
$ErrorActionPreference = 'Continue'

Write-Host '=== AntiDPI tray: uninstall ==='

if (-not $KeepTasks) {
    foreach ($name in @('AntiDPI Stop', 'AntiDPI Start')) {
        $t = Get-ScheduledTask -TaskName $name -ErrorAction SilentlyContinue
        if ($t) {
            Unregister-ScheduledTask -TaskName $name -Confirm:$false
            Write-Host "[OK] task removed: $name"
        }
    }
    $stale = Get-Process -Name 'winws2' -ErrorAction SilentlyContinue
    if ($stale) {
        $stale | Stop-Process -Force
        Write-Host '[OK] winws2 stopped.'
    }
    foreach ($name in @('Igareck AntiDPI Stop', 'Igareck AntiDPI Start')) {
        $t = Get-ScheduledTask -TaskName $name -ErrorAction SilentlyContinue
        if ($t) {
            Unregister-ScheduledTask -TaskName $name -Confirm:$false
            Write-Host "[OK] legacy task removed: $name"
        }
    }
}

$run = Get-ItemProperty -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run' -ErrorAction SilentlyContinue
if ($run.PSObject.Properties['AntiDPI Tray']) {
    Remove-ItemProperty -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run' -Name 'AntiDPI Tray'
    Write-Host '[OK] autostart removed (HKCU Run).'
}

Write-Host ''
Write-Host 'Engine files were NOT deleted.'
Write-Host 'To remove everything, delete the install folder manually:'
Write-Host '  C:\Igareck_AntiDPI'
