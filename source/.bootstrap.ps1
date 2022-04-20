$osInfo = Get-WmiObject Win32_OperatingSystem
$seed = ($osInfo.FreePhysicalMemory + $osInfo.NumberOfProcesses + [datetime]::Now.Ticks) % [int]::MaxValue
$script:__RNG = New-Object System.Random $seed
Remove-Variable 'seed'

# Render-Template variables:
$script:__InterpolationTags = @{
    Start = '<<'
    End = '>>'
}
$script:__InterpolationTagsHistory = New-Object System.Collections.Stack



New-Alias -Name 'Save-Credential' -Value 'Save-PSCredential'
New-Alias -Name 'Load-Credential' -Value 'Restore-PSCredential'
New-Alias -Name 'Load-PSCredential' -Value 'Restore-PSCredential'
New-Alias -Name '~' -Value Unlock-SecureString