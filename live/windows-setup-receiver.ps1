# Atlas OS Live log receiver on Hong Khai's Windows PC (DESIGN §26.6). Run once AS ADMINISTRATOR (UAC):
#   powershell -ExecutionPolicy Bypass -File windows-setup-receiver.ps1
# 1) Windows Firewall: inbound TCP + UDP 4960, only from the local subnet (the pondok network is a "Public" profile).
# 2) Start at login, hidden: a shortcut in the user's Startup folder runs node log-receiver.mjs.
param([string]$LogDir = 'C:\HISADA\atlas-live-logs', [string]$User = $env:USERNAME)
$ErrorActionPreference = 'Stop'
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$receiver = Join-Path $here 'log-receiver.mjs'
$node = (Get-Command node).Source

foreach ($proto in 'TCP', 'UDP') {
  $name = "Atlas OS Live log ($proto 4960)"
  Get-NetFirewallRule -DisplayName $name -ErrorAction SilentlyContinue | Remove-NetFirewallRule
  New-NetFirewallRule -DisplayName $name -Direction Inbound -Action Allow -Protocol $proto -LocalPort 4960 `
    -RemoteAddress LocalSubnet -Profile Private, Public -Program $node | Out-Null
  Write-Output "firewall: $name (hanya subnet lokal)"
}

$startup = Join-Path ([Environment]::GetFolderPath('Startup')) 'Atlas OS Live log.lnk'
$sh = New-Object -ComObject WScript.Shell
$lnk = $sh.CreateShortcut($startup)
$lnk.TargetPath = $node
$lnk.Arguments = "`"$receiver`" `"$LogDir`""
$lnk.WorkingDirectory = $here
$lnk.WindowStyle = 7   # minimized
$lnk.Description = 'Atlas OS Live: penerima log (DESIGN §26.6)'
$lnk.Save()
Write-Output "mulai otomatis: $startup"
