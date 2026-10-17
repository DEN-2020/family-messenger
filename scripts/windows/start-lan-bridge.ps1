# Family Messenger — Start Wi-Fi LAN Bridge & Verify HTTPS on 192.168.2.122:8443
param(
    [string]$LanIp = "192.168.2.122",
    [int]$Port = 8443
)

$ErrorActionPreference = "Stop"
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = Split-Path -Parent (Split-Path -Parent $scriptDir)
$pythonExe = "C:\Users\Admin\AppData\Local\Programs\Python\Python310\python.exe"
$bridgeScript = Join-Path $scriptDir "lan-tls-bridge.py"
$caCert = Join-Path $repoRoot "infra\reverse-proxy\certs\family-messenger-root-ca.crt"

# Check if already listening on $LanIp:$Port
$existing = Get-NetTCPConnection -LocalAddress $LanIp -LocalPort $Port -State Listen -ErrorAction SilentlyContinue
if (-not $existing) {
    Write-Host "Starting LAN TLS Bridge on ${LanIp}:${Port} -> 127.0.0.1:${Port} ..." -ForegroundColor Cyan
    Start-Process -FilePath $pythonExe -ArgumentList "`"$bridgeScript`" $LanIp $Port 127.0.0.1 $Port" -WindowStyle Hidden
    Start-Sleep -Seconds 2
} else {
    Write-Host "LAN TLS Bridge is already listening on ${LanIp}:${Port} (PID $($existing.OwningProcess))." -ForegroundColor Green
}

Write-Host "Verifying HTTPS over Wi-Fi LAN IP https://${LanIp}:${Port} ..." -ForegroundColor Cyan
curl.exe --cacert $caCert --ssl-no-revoke -fsS "https://${LanIp}:${Port}/health"
Write-Host ""
curl.exe --cacert $caCert --ssl-no-revoke -fsS "https://${LanIp}:${Port}/_matrix/client/versions"
Write-Host ""
