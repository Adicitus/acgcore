<#
    .SYNOPSIS
    Creates a PSCredential.

    .DESCRIPTION
    Takes a Username and Password to create a PSCredential.
#>
function New-PSCredential{
    [CmdletBinding(DefaultParameterSetName="ClearText")]
    param(
        [parameter(Mandatory=$true, position=1)][string] $Username,
        [parameter(Mandatory=$true, position=2, ParameterSetName="ClearText")][string] $Password,
        [parameter(Mandatory=$true, position=2, ParameterSetName="SecureString")][securestring]$SecurePassword
    )

    if ($PSCmdlet.ParameterSetName -eq "ClearText") {
        $SecurePassword = ConvertTo-SecureString -String $Password -AsPlainText -Force
    }

    $cred = New-Object System.Management.Automation.PSCredential($username, $SecurePassword)

    return $cred
}