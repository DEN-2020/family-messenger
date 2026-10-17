# Family Messenger — Phase 0: Windows & WSL2 Environment Check Script
$ErrorActionPreference = "Stop"

Write-Host "=== 1. Windows 11 & Hardware ===" -ForegroundColor Cyan
Get-CimInstance Win32_OperatingSystem | Select-Object Caption, Version, BuildNumber, @{N="FreeRAM_GB";E={[math]::Round($_.FreePhysicalMemory/1MB,2)}}, @{N="TotalRAM_GB";E={[math]::Round($_.TotalVisibleMemorySize/1MB,2)}} | Format-Table -AutoSize

Write-Host "=== 2. WSL2 & Ubuntu-24.04 Status ===" -ForegroundColor Cyan
wsl -d Ubuntu-24.04 -- bash -c "uname -r; ps -p 1 -o comm=; systemctl is-active postgresql matrix-synapse nginx"

Write-Host "`n=== 3. Port Conflict & SEO Studio Isolation Check ===" -ForegroundColor Cyan
$ports = @(80, 3000, 3001, 5432, 8008, 8080, 8443)
Get-NetTCPConnection -State Listen -ErrorAction SilentlyContinue |
    Where-Object { $_.LocalPort -in $ports } |
    Select-Object LocalAddress, LocalPort, OwningProcess, @{Name="Process";Expression={(Get-Process -Id $_.OwningProcess -ErrorAction SilentlyContinue).ProcessName}} |
    Sort-Object LocalPort -Unique | Format-Table -AutoSize

Write-Host "=== 4. Matrix HTTPS Endpoint Health Check ===" -ForegroundColor Cyan
wsl -d Ubuntu-24.04 -- bash -c "curl --cacert /usr/local/share/ca-certificates/family-messenger-root-ca.crt -fsS https://localhost:8443/health && echo ' (HTTPS /health)' && curl --cacert /usr/local/share/ca-certificates/family-messenger-root-ca.crt -fsS https://localhost:8443/_matrix/client/versions"
