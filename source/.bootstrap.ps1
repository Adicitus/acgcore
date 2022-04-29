# Setting Random Number Generation:
$osInfo = Get-WmiObject Win32_OperatingSystem
$seed = ($osInfo.FreePhysicalMemory + $osInfo.NumberOfProcesses + [datetime]::Now.Ticks) % [int]::MaxValue
$script:__RNG = New-Object System.Random $seed
Remove-Variable 'seed'

# Initializeing Render-Template variables:
$script:__InterpolationTags = @{
    Start = '<<'
    End = '>>'
}
$script:__InterpolationTagsHistory = New-Object System.Collections.Stack


# Creating aliases:
New-Alias -Name 'Save-Credential' -Value 'Save-PSCredential'
New-Alias -Name 'Load-Credential' -Value 'Restore-PSCredential'
New-Alias -Name 'Load-PSCredential' -Value 'Restore-PSCredential'
New-Alias -Name '~' -Value Unlock-SecureString
New-Alias -Name 'Parse-ConfigFile' -Value 'Read-ConfigFile'
New-Alias -Name 'Create-Shortcut' -Value 'New-Shortcut'
New-Alias -Name 'Render-Template' -Value 'Format-Template'