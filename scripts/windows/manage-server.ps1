# Family Messenger — Phase 0: Server Management & Controlled User Provisioning (PowerShell)
param(
    [Parameter(Mandatory=$true)]
    [ValidateSet("status", "start", "stop", "restart", "backup", "create-user")]
    [string]$Action,

    [string]$Username,
    [string]$Password,
    [switch]$Admin
)

$ErrorActionPreference = "Stop"

switch ($Action) {
    "status" {
        wsl -d Ubuntu-24.04 -u root -- bash -c "systemctl status postgresql matrix-synapse nginx --no-pager"
    }
    "start" {
        wsl -d Ubuntu-24.04 -u root -- bash -c "systemctl start postgresql matrix-synapse nginx && /usr/local/bin/family-messenger-healthcheck"
    }
    "stop" {
        wsl -d Ubuntu-24.04 -u root -- bash -c "systemctl stop nginx matrix-synapse"
    }
    "restart" {
        wsl -d Ubuntu-24.04 -u root -- bash -c "systemctl restart postgresql matrix-synapse nginx && /usr/local/bin/family-messenger-healthcheck"
    }
    "backup" {
        wsl -d Ubuntu-24.04 -u root -- bash -c "'/mnt/c/Users/Admin/Documents/Family Messenger/infra/backups/backup.sh'"
    }
    "create-user" {
        if (-not $Username -or -not $Password) {
            throw "Specify -Username and -Password when using -Action create-user"
        }
        $adminFlag = if ($Admin) { "--admin" } else { "--no-admin" }
        wsl -d Ubuntu-24.04 -u root -- bash -c "/opt/venvs/matrix-synapse/bin/register_new_matrix_user -u '$Username' -p '$Password' $adminFlag -c /etc/matrix-synapse/homeserver.yaml -c /etc/matrix-synapse/conf.d/server_name.yaml -c /etc/matrix-synapse/conf.d/secrets.yaml http://127.0.0.1:8008"
    }
}
