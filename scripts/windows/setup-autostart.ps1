#Requires -Version 5.1
<#
.SYNOPSIS
    Configures automatic startup and 2-minute self-healing watchdog for Family Messenger on Windows 11.
.DESCRIPTION
    1. Configures Tailscale in Unattended mode (--unattended --ssh=false) and persistent background Funnel (:443 -> 127.0.0.1:8440).
    2. Registers the 'FamilyMessenger-Watchdog' Scheduled Task (triggers at user logon and every 2 minutes indefinitely).
    3. Adds a redundant HKCU Run registry key so WSL2 + Matrix services start immediately on sign-in.
    4. If run as Administrator with -EnablePreLogonBoot (requires Windows account password due to LSA LimitBlankPasswordUse=1),
       registers a pre-logon AtStartup (BootTrigger) task using S4U (without AutoLogon and without storing password).
#>

param(
    [switch]$EnablePreLogonBoot
)

$ErrorActionPreference = "Stop"
$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
$WatchdogScript = Join-Path $RepoRoot "scripts\windows\family-messenger-watchdog.ps1"

Write-Host "1. Verifying Tailscale Unattended & Funnel configuration..." -ForegroundColor Cyan
& "C:\Program Files\Tailscale\tailscale.exe" up --unattended --ssh=false
& "C:\Program Files\Tailscale\tailscale.exe" funnel --bg --https=443 http://127.0.0.1:8440

Write-Host "2. Registering Windows Scheduled Task 'FamilyMessenger-Watchdog' (AtLogOn + 2-min Self-Healing)..." -ForegroundColor Cyan
$action = New-ScheduledTaskAction -Execute "powershell.exe" `
    -WorkingDirectory $RepoRoot `
    -Argument "-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File .\scripts\windows\family-messenger-watchdog.ps1"

$triggerLogon = New-ScheduledTaskTrigger -AtLogOn -User "$env:USERDOMAIN\$env:USERNAME"
$triggerRepeat = New-ScheduledTaskTrigger -Once -At (Get-Date).AddMinutes(1) `
    -RepetitionInterval (New-TimeSpan -Minutes 2) `
    -RepetitionDuration (New-TimeSpan -Days 3650)

$principal = New-ScheduledTaskPrincipal -UserId "$env:USERDOMAIN\$env:USERNAME" -LogonType Interactive -RunLevel Limited

$settings = New-ScheduledTaskSettingsSet `
    -AllowStartIfOnBatteries `
    -DontStopIfGoingOnBatteries `
    -StartWhenAvailable `
    -ExecutionTimeLimit (New-TimeSpan -Minutes 5) `
    -MultipleInstances IgnoreNew

Register-ScheduledTask -TaskName "FamilyMessenger-Watchdog" `
    -Action $action `
    -Trigger @($triggerLogon, $triggerRepeat) `
    -Principal $principal `
    -Settings $settings `
    -Description "Starts and monitors WSL2 Ubuntu-24.04, PostgreSQL, Matrix Synapse, Nginx, and Tailscale Funnel every 2 minutes." `
    -Force | Out-Null

Write-Host "3. Configuring HKCU Startup Run key for immediate logon recovery..." -ForegroundColor Cyan
$runCmd = "powershell.exe -NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$WatchdogScript`""
Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run" -Name "FamilyMessengerAutostart" -Value $runCmd

if ($EnablePreLogonBoot) {
    Write-Host "4. Attempting to register Pre-Logon BootTrigger (S4U without storing password)..." -ForegroundColor Cyan
    $triggerBoot = New-ScheduledTaskTrigger -AtStartup
    $principalS4U = New-ScheduledTaskPrincipal -UserId "$env:USERDOMAIN\$env:USERNAME" -LogonType S4U -RunLevel Highest
    Register-ScheduledTask -TaskName "FamilyMessenger-PreLogon-Boot" `
        -Action $action `
        -Trigger $triggerBoot `
        -Principal $principalS4U `
        -Settings $settings `
        -Description "Pre-logon startup of WSL2 and Matrix Synapse at Windows boot via S4U." `
        -Force | Out-Null
    Write-Host "Pre-Logon BootTrigger task registered successfully." -ForegroundColor Green
}

Write-Host "4. Starting 'FamilyMessenger-Watchdog' task now to verify execution..." -ForegroundColor Cyan
Start-ScheduledTask -TaskName "FamilyMessenger-Watchdog"
Start-Sleep -Seconds 4
Get-ScheduledTask -TaskName "FamilyMessenger-Watchdog" | Get-ScheduledTaskInfo | Select-Object TaskName, LastRunTime, LastTaskResult, NextRunTime
