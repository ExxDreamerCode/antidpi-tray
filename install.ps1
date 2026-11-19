#requires -Version 5.1
param(
    [string]$InstallRoot = 'C:\Igareck_AntiDPI',
    [string]$TraySource = (Join-Path $PSScriptRoot 'tray')
)
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

$BundleUrl   = 'https://codeload.github.com/bol-van/zapret-win-bundle/zip/6eb463a6758fb48cd101bc55dfd057e6e9d98af1'
$BundleSha256 = '5f828239310fed0da587bc09eaa22742615b2a85cf41f55ff28128e22231c6de'
$CliUrl      = 'https://github.com/igareck/anti-dpi-for-russia/releases/download/v1.1/Igareck_AntiDPI_CLI_v1.0_Windows_x64.zip'
$CliSha256   = '08333929211ceb0da8f253fbd14549306dccf573d7f7d225df98be84259e72a0'

$TmpDir = Join-Path $env:TEMP 'antidpi-tray-install'
New-Item -ItemType Directory -Force -Path $TmpDir | Out-Null
New-Item -ItemType Directory -Force -Path $InstallRoot | Out-Null

function Get-PinnedFile([string]$Url, [string]$Sha256, [string]$OutFile) {
    $out = Join-Path $TmpDir $OutFile
    if (Test-Path $out) {
        $h = (Get-FileHash -Algorithm SHA256 $out).Hash.ToLower()
        if ($h -eq $Sha256) { Write-Host "[SKIP] $OutFile already downloaded and verified."; return $out }
        Remove-Item $out -Force
    }
    Write-Host "[GET] $Url"
    Invoke-WebRequest -Uri $Url -OutFile $out -UseBasicParsing
    $h = (Get-FileHash -Algorithm SHA256 $out).Hash.ToLower()
    if ($h -ne $Sha256) { throw "SHA256 mismatch for $OutFile : $h" }
    Write-Host "[OK] SHA256 verified: $OutFile"
    return $out
}

function Expand-Selected([string]$Zip, [string]$InnerPrefix, [string]$DestRoot, [switch]$StripPrefix) {
    Add-Type -AssemblyName System.IO.Compression.FileSystem | Out-Null
    $archive = [System.IO.Compression.ZipFile]::OpenRead($Zip)
    try {
        foreach ($entry in $archive.Entries) {
            if ([string]::IsNullOrEmpty($entry.Name)) { continue }
            $rel = $entry.FullName
            if (-not $rel.StartsWith($InnerPrefix)) { continue }
            $sub = $rel.Substring($InnerPrefix.Length)
            if ($StripPrefix) {
                $parts = $sub.Split('/')
                if ($parts.Count -lt 2) { continue }
                $sub = ($parts[1..($parts.Count - 1)] -join '/')
            }
            if ([string]::IsNullOrEmpty($sub)) { continue }
            $dest = Join-Path $DestRoot ($sub -replace '/', '\')
            $destDir = Split-Path $dest -Parent
            if (-not (Test-Path $destDir)) { New-Item -ItemType Directory -Force -Path $destDir | Out-Null }
            [System.IO.Compression.ZipFileExtensions]::ExtractToFile($entry, $dest, $true)
        }
    } finally {
        $archive.Dispose()
    }
}

Write-Host '=== AntiDPI tray: install ==='

# 1. python + deps
$pyw = Get-Command pythonw.exe -ErrorAction SilentlyContinue
if (-not $pyw) { $pyw = Get-ChildItem "$env:LOCALAPPDATA\Programs\Python\Python*\pythonw.exe" | Select-Object -First 1 }
if (-not $pyw) { throw 'pythonw.exe not found. Install Python 3.8+ first: https://www.python.org/downloads/' }
Write-Host "[OK] pythonw: $($pyw.Source)"
$py = $pyw.Source -replace 'pythonw\.exe$', 'python.exe'
if (-not (Test-Path $py)) { $py = (Get-Command python.exe).Source }
& $py -c "import pystray, PIL" 2>$null
if ($LASTEXITCODE -ne 0) {
    Write-Host '[SETUP] Installing pystray + pillow (python -m pip)...'
    & $py -m pip install --quiet pystray pillow
    if ($LASTEXITCODE -ne 0) { throw 'pip install pystray pillow failed. Run it manually.' }
    Write-Host '[OK] pystray + pillow installed.'
} else {
    Write-Host '[OK] pystray + pillow present.'
}

# 2. engine binaries (bol-van zapret-win-bundle, pinned commit + sha256)
$winws = Join-Path $InstallRoot 'zapret-winws\winws2.exe'
if (Test-Path $winws) {
    Write-Host '[SKIP] engine binaries already present.'
} else {
    $zip = Get-PinnedFile $BundleUrl $BundleSha256 'bundle.zip'
    Write-Host '[..] extracting zapret-winws...'
    Expand-Selected -Zip $zip -InnerPrefix 'zapret-winws/' -DestRoot (Join-Path $InstallRoot 'zapret-winws') -StripPrefix
    if (-not (Test-Path $winws)) {
        Write-Host ''
        Write-Host '[WARN] winws2.exe is missing after extraction. Your antivirus most likely' -ForegroundColor Yellow
        Write-Host '[WARN] quarantined it. Add exclusions for:' -ForegroundColor Yellow
        Write-Host "[WARN]   folder: $InstallRoot" -ForegroundColor Yellow
        Write-Host '[WARN]   file:   winws2.exe / WinDivert64.sys' -ForegroundColor Yellow
        Write-Host '[WARN] then re-run this installer.' -ForegroundColor Yellow
        throw 'Engine binaries missing after extraction (antivirus quarantine?).'
    }
    Write-Host '[OK] engine binaries extracted.'
}

# 3. strategy payload (igareck release, pinned version + sha256)
$golden = Get-ChildItem -Path (Join-Path $InstallRoot 'Igareck') -Filter 'Zapret2_Golden*.ps1' -ErrorAction SilentlyContinue | Select-Object -First 1
if ($golden) {
    Write-Host '[SKIP] strategy payload already present.'
} else {
    $zip2 = Get-PinnedFile $CliUrl $CliSha256 'cli.zip'
    Write-Host '[..] extracting payload...'
    New-Item -ItemType Directory -Force -Path (Join-Path $InstallRoot 'Igareck') | Out-Null
    Expand-Selected -Zip $zip2 -InnerPrefix 'payload/' -DestRoot (Join-Path $InstallRoot 'Igareck')
    Expand-Selected -Zip $zip2 -InnerPrefix '' -DestRoot $InstallRoot
    if (-not (Get-ChildItem -Path (Join-Path $InstallRoot 'Igareck') -Filter 'Zapret2_Golden*.ps1' | Select-Object -First 1)) {
        throw 'Zapret2_Golden*.ps1 missing after extraction.'
    }
    Write-Host '[OK] strategy payload extracted.'
}

# 4. tray files
Write-Host '[..] copying tray files...'
Copy-Item -Path (Join-Path $TraySource '*') -Destination (Join-Path $InstallRoot 'Igareck') -Recurse -Force
if (-not (Test-Path (Join-Path $InstallRoot 'Igareck\_state'))) {
    New-Item -ItemType Directory -Force -Path (Join-Path $InstallRoot 'Igareck\_state') | Out-Null
}
Write-Host '[OK] tray files copied.'

# 5. autostart (HKCU, no admin needed): tray starts at logon and enables last strategy
$pywPath = if ($pyw.PSObject.Properties['Source']) { $pyw.Source } else { $pyw.ToString() }
$regValue = '"{0}" "{1}" --auto-start' -f $pywPath, (Join-Path $InstallRoot 'Igareck\AntiDPI_Tray.py')
Set-ItemProperty -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run' -Name 'AntiDPI Tray' -Value $regValue
Write-Host '[OK] autostart registered (HKCU Run, --auto-start).'

Write-Host ''
Write-Host '=== Next: create scheduler tasks ==='
Write-Host 'One UAC prompt will appear - it is the only one you will ever see.'
Write-Host 'After that: tray at logon, no prompts, no admin.'
Write-Host ''
Write-Host 'NOTE: if your antivirus asks, allow winws2.exe and add the folder' -ForegroundColor Yellow
Write-Host "      $InstallRoot to its exclusions." -ForegroundColor Yellow
