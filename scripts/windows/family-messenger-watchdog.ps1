#Requires -Version 5.1
<#
.SYNOPSIS
    Family Messenger — Autostart & Self-Healing Watchdog (WSL2 + PostgreSQL + Synapse + Nginx + Tailscale Funnel)
.DESCRIPTION
    Ensures that after Windows 11 startup, login, or an unexpected WSL2/service crash:
    1. WSL2 Ubuntu-24.04 is started and held alive in the background.
    2. PostgreSQL 16, Matrix Synapse, Nginx, and systemd healthcheck timer are active inside Ubuntu-24.04.
    3. Local Nginx backend (http://127.0.0.1:8440/health) responds with HTTP 200 OK.
    4. Tailscale runs in Unattended mode (--unattended --ssh=false) and Tailscale Funnel proxies
       https://asrock.tail56bf63.ts.net -> http://127.0.0.1:8440.
    5. Public HTTPS health check (https://asrock.tail56bf63.ts.net/health) passes with strict system TLS validation.
    Logs are written to logs/watchdog.log without exposing any secrets, tokens, or passwords.
#>

param(
    [string]$Distro = "Ubuntu-24.04",
    [string]$PublicUrl = "https://asrock.tail56bf63.ts.net",
    [string]$LocalBackend = "http://127.0.0.1:8440"
)

$ErrorActionPreference = "Continue"
$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
$LogDir = Join-Path $RepoRoot "logs"
if (-not (Test-Path $LogDir)) {
    New-Item -ItemType Directory -Path $LogDir -Force | Out-Null
}
$LogFile = Join-Path $LogDir "watchdog.log"

# Rotate log if > 5 MB
if ((Test-Path $LogFile) -and ((Get-Item $LogFile).Length -gt 5242880)) {
    Move-Item -Path $LogFile -Destination "$LogFile.1" -Force
}

function Write-WatchdogLog {
    param([string]$Level, [string]$Message)
    $ts = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
    $line = "[$ts] [$Level] $Message"
    Add-Content -Path $LogFile -Value $line -Encoding UTF8
    Write-Output $line
}

Write-WatchdogLog "INFO" "Starting Family Messenger Watchdog check..."

# 1. Ensure WSL2 Ubuntu-24.04 keepalive process is running so WSL2 VM never auto-terminates
$keepaliveRunning = wsl.exe -d $Distro -u root -- bash -c "pgrep -f '[f]amily-messenger-wsl-keepalive' >/dev/null 2>&1 && echo YES || echo NO" 2>$null
if (($keepaliveRunning | Out-String).Trim() -ne "YES") {
    Write-WatchdogLog "WARN" "WSL2 keepalive not detected (WSL2 was stopped or rebooted). Launching hidden keepalive daemon..."
    Start-Process -FilePath "wsl.exe" `
        -ArgumentList "-d $Distro -u root -- bash -c `"exec -a family-messenger-wsl-keepalive sleep infinity`"" `
        -WindowStyle Hidden
    Start-Sleep -Seconds 3
}

# 2. Check and recover Linux systemd services inside WSL2 (postgresql, matrix-synapse, nginx)
$linuxCheckScript = @'
set -e
for svc in postgresql matrix-synapse nginx; do
    if ! systemctl is-active --quiet "$svc"; then
        logger -t family-messenger-watchdog "Service $svc inactive; restarting..."
        systemctl restart "$svc"
        echo "RECOVERED:$svc"
    fi
done
systemctl start family-messenger-healthcheck.timer 2>/dev/null || true
echo "LINUX_SERVICES_OK"
'@

$linuxResult = ($linuxCheckScript -replace "`r", "") | wsl.exe -d $Distro -u root -- bash 2>&1 | Out-String
if ($linuxResult -match "RECOVERED:") {
    Write-WatchdogLog "WARN" "Recovered Linux services inside WSL2: $($linuxResult.Trim() -replace '\s+', ' ')"
} elseif ($linuxResult -match "LINUX_SERVICES_OK") {
    Write-WatchdogLog "INFO" "Linux systemd services (postgresql, matrix-synapse, nginx) are active."
} else {
    Write-WatchdogLog "ERROR" "Unexpected WSL2 service check output: $($linuxResult.Trim())"
}

# 3. Verify local Nginx backend (http://127.0.0.1:8440/health)
$localHealthy = $false
try {
    $resp = Invoke-WebRequest -Uri "$LocalBackend/health" -UseBasicParsing -TimeoutSec 5 -ErrorAction Stop
    if ($resp.StatusCode -eq 200 -and $resp.Content.Trim() -eq "OK") {
        $localHealthy = $true
        Write-WatchdogLog "INFO" "Local Nginx -> Synapse healthcheck ($LocalBackend/health): HTTP 200 OK"
    }
} catch {
    Write-WatchdogLog "WARN" "Local healthcheck ($LocalBackend/health) failed ($($_.Exception.Message)). Restarting nginx and matrix-synapse in WSL2..."
    wsl.exe -d $Distro -u root -- bash -c "systemctl restart matrix-synapse nginx" 2>$null
    Start-Sleep -Seconds 3
    try {
        $resp2 = Invoke-WebRequest -Uri "$LocalBackend/health" -UseBasicParsing -TimeoutSec 5 -ErrorAction Stop
        if ($resp2.StatusCode -eq 200) {
            $localHealthy = $true
            Write-WatchdogLog "INFO" "Local healthcheck recovered after service restart: HTTP 200 OK"
        }
    } catch {
        Write-WatchdogLog "ERROR" "Local healthcheck still failing after restart: $($_.Exception.Message)"
    }
}

# 4. Ensure Tailscale Unattended & Funnel (https://asrock.tail56bf63.ts.net -> http://127.0.0.1:8440)
$TailscaleExe = "C:\Program Files\Tailscale\tailscale.exe"
if (Test-Path $TailscaleExe) {
    $tsStatusRaw = & $TailscaleExe status --json 2>$null | Out-String
    $tsState = "Unknown"
    if ($tsStatusRaw) {
        try {
            $tsJson = $tsStatusRaw | ConvertFrom-Json
            $tsState = $tsJson.BackendState
        } catch {}
    }

    if ($tsState -ne "Running") {
        Write-WatchdogLog "WARN" "Tailscale BackendState is '$tsState'. Starting Tailscale in Unattended mode (--unattended --ssh=false)..."
        & $TailscaleExe up --unattended --ssh=false 2>&1 | Out-Null
        Start-Sleep -Seconds 3
    }

    $funnelStatus = (& $TailscaleExe funnel status 2>&1 | Out-String)
    if ($funnelStatus -notmatch "Funnel on" -or $funnelStatus -notmatch "127\.0\.0\.1:8440") {
        Write-WatchdogLog "WARN" "Tailscale Funnel not active on 127.0.0.1:8440. Enabling background Funnel..."
        & $TailscaleExe funnel --bg --https=443 $LocalBackend 2>&1 | Out-Null
        Start-Sleep -Seconds 2
    } else {
        Write-WatchdogLog "INFO" "Tailscale Unattended & Funnel configuration verified active."
    }
} else {
    Write-WatchdogLog "ERROR" "Tailscale executable not found at $TailscaleExe"
}

# 5. Verify Public Internet HTTPS Endpoint (Strict System TLS Validation)
try {
    $pubResp = Invoke-WebRequest -Uri "$PublicUrl/health" -UseBasicParsing -TimeoutSec 10 -ErrorAction Stop
    if ($pubResp.StatusCode -eq 200 -and $pubResp.Content.Trim() -eq "OK") {
        Write-WatchdogLog "INFO" "Public HTTPS Funnel healthcheck ($PublicUrl/health): HTTP 200 OK (TLS verified)"
    } else {
        Write-WatchdogLog "WARN" "Public HTTPS Funnel returned unexpected status: $($pubResp.StatusCode)"
    }
} catch {
    Write-WatchdogLog "WARN" "Public HTTPS Funnel check ($PublicUrl/health) failed ($($_.Exception.Message)). Re-applying tailscale funnel..."
    if (Test-Path $TailscaleExe) {
        & $TailscaleExe up --unattended --ssh=false 2>&1 | Out-Null
        & $TailscaleExe funnel --bg --https=443 $LocalBackend 2>&1 | Out-Null
    }
}

Write-WatchdogLog "INFO" "Watchdog cycle completed."
