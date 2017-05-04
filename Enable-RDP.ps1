# Enable-RDP.ps1

param([parameter(Mandatory=$false)][Switch]$Run)

function Enable-RDP() {
    
    New-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server' -Name 'fDenyTSConnections' -Value 0 -PropertyType dword -Force
    New-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp' -Name 'UserAuthentication' -Value 1 -PropertyType dword -Force

    Enable-NetFirewallRule -DisplayGroup "Remote Desktop"
}

if ($Run) { Enable-RDP }