<#
    .SYNOPSIS
    Creates a PSCredential.

    .DESCRIPTION
    Takes a Username and Password to create a PSCredential.
#>
function New-PSCredential{
    param(
        [parameter(Mandatory=$true, position=1)][string] $Username,
        [parameter(Mandatory=$true, position=2)][string] $Password
    )
    $secPassw  = ConvertTo-SecureString $password -AsPlainText -Force
    $cred = New-Object System.Management.Automation.PSCredential($username, $secPassw)

    return $cred
}