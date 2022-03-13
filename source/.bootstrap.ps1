$script:__RNG = New-Object System.Random

# Render-Template variables:
$script:__InterpolationTags = @{
    Start = '<<'
    End = '>>'
}
$script:__InterpolationTagsHistory = [System.Collections.Stack]::new()



New-Alias -Name 'Save-Credential' -Value 'Save-PSCredential'
New-Alias -Name 'Load-Credential' -Value 'Load-PSCredential'
New-Alias -Name '~'  -Value Unlock-SecureString