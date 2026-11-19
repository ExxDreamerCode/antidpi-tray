#requires -Version 5.1
$ErrorActionPreference = 'Stop'
$root   = $PSScriptRoot
$user   = "$env:USERDOMAIN\$env:USERNAME"

Write-Host '=== AntiDPI: настройка задач планировщика ==='
Write-Host ''

function New-TrayTask([string]$Name, [string]$Script) {
    $existing = Get-ScheduledTask -TaskName $Name -ErrorAction SilentlyContinue
    if($existing){ Unregister-ScheduledTask -TaskName $Name -Confirm:$false }

    $action = New-ScheduledTaskAction -Execute 'powershell.exe' `
        -Argument ('-NoLogo -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "{0}"' -f $Script) `
        -WorkingDirectory $root
    $principal = New-ScheduledTaskPrincipal -UserId $user -LogonType S4U -RunLevel Highest
    $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries `
        -ExecutionTimeLimit ([TimeSpan]::Zero) -MultipleInstances IgnoreNew

    Register-ScheduledTask -TaskName $Name -Action $action -Principal $principal -Settings $settings | Out-Null
    Write-Host ("[OK] Задача создана: {0}" -f $Name) -ForegroundColor Green
}

for($n=1; $n -le 10; $n++){
    $old = "AntiDPI Start $n"
    if(Get-ScheduledTask -TaskName $old -ErrorAction SilentlyContinue){
        Unregister-ScheduledTask -TaskName $old -Confirm:$false
        Write-Host ("[ОЧИСТКА] Удалена устаревшая задача: {0}" -f $old) -ForegroundColor DarkGray
    }
}

New-TrayTask -Name 'AntiDPI Stop'  -Script "$root\Stop-AntiDPI.ps1"
New-TrayTask -Name 'AntiDPI Start' -Script "$root\Start-Strategy.ps1"

Write-Host ''
Write-Host 'Проверка (запуск стратегии 4 через планировщик)...'
$cmdPath = Join-Path $root '_state\tray_cmd.json'
@{ Profile = 4 } | ConvertTo-Json | Set-Content -LiteralPath $cmdPath -Encoding UTF8

schtasks /run /tn 'AntiDPI Stop' | Out-Null
Start-Sleep -Seconds 2
schtasks /run /tn 'AntiDPI Start' | Out-Null

$ok = $false
for($i=0; $i -lt 20; $i++){
    Start-Sleep -Seconds 1
    if(Get-Process -Name 'winws2' -ErrorAction SilentlyContinue){ $ok = $true; break }
}

if($ok){
    Write-Host '[OK] winws2 запущен через задачу планировщика. UAC не потребовался.' -ForegroundColor Green
    Write-Host 'Останавливаю обратно...'
    schtasks /run /tn 'AntiDPI Stop' | Out-Null
    Start-Sleep -Seconds 3
    if(Get-Process -Name 'winws2' -ErrorAction SilentlyContinue){
        Write-Host '[ВНИМАНИЕ] winws2 не остановился — проверьте логи в $root\..\logs' -ForegroundColor Yellow
    }else{
        Write-Host '[OK] Остановка тоже работает.' -ForegroundColor Green
    }
    Write-Host ''
    Write-Host 'Готово! Теперь включение/выключение/смена стратегий в трее работает без UAC.' -ForegroundColor Green
    Start-Sleep -Seconds 8
}else{
    Write-Host '[ОШИБКА] winws2 не запустился за 20 секунд.' -ForegroundColor Red
    Write-Host 'Посмотрите свежий лог в $root\..\logs' -ForegroundColor Red
    Read-Host 'Нажмите Enter для закрытия'
}

