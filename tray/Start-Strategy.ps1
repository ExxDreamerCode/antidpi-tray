#requires -Version 5.1
param(
    [int]$ProfileNumber = 0,
    [int]$InterfaceIndex = 0,
    [string]$Scope = 'all',
    [string]$ZapretDirectory = (Join-Path (Split-Path $PSScriptRoot -Parent) 'zapret-winws'),
    [string]$StateDirectory = (Join-Path $PSScriptRoot '_state')
)
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

if($ProfileNumber -le 0){
    $cmdPath = Join-Path $StateDirectory 'tray_cmd.json'
    if(Test-Path -LiteralPath $cmdPath -PathType Leaf){
        try{
            $cmd = Get-Content -LiteralPath $cmdPath -Raw | ConvertFrom-Json
            $ProfileNumber = [int]$cmd.Profile
        }catch{
            throw 'Broken tray_cmd.json: cannot read the strategy profile number.'
        }
    }
}
if($ProfileNumber -le 0){
    throw 'Unknown strategy profile. Pass -ProfileNumber or let the tray write tray_cmd.json.'
}

$stale = Get-Process -Name 'winws2' -ErrorAction SilentlyContinue
if($stale){
    $stale | Stop-Process -Force
    Start-Sleep -Milliseconds 1500
}

if($InterfaceIndex -le 0){
    $adapterPath = Join-Path $StateDirectory 'adapter.json'
    if(Test-Path -LiteralPath $adapterPath -PathType Leaf){
        $adapter = Get-Content -LiteralPath $adapterPath -Raw | ConvertFrom-Json
        $InterfaceIndex = [int]$adapter.Index
    }
}
if($InterfaceIndex -le 0){
    throw 'Unknown network adapter index. Specify -InterfaceIndex.'
}

$engine = Get-ChildItem -LiteralPath $PSScriptRoot -Filter 'Zapret2_Golden*.ps1' | Select-Object -First 1
if(-not $engine){ throw 'Engine script Zapret2_Golden*.ps1 not found next to this script.' }

& $engine.FullName `
  -ProfileNumber $ProfileNumber `
  -InterfaceIndex $InterfaceIndex `
  -Scope $Scope `
  -ZapretDirectory $ZapretDirectory `
  -StateDirectory $StateDirectory

exit $LASTEXITCODE

