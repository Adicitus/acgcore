#Set-WinAutoLogon.ps1

function Set-WinAutoLogon {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true, Position=1, ParameterSetName="Credential")]
        [pscredential]$LogonCredential,
        [Parameter(Mandatory=$true, Position=1, ParameterSetName="Params")]
        [String]$Username,
        [Parameter(Mandatory=$true, Position=2, ParameterSetName="Params")]
        [SecureString]$Password,
        [Parameter(Mandatory=$false, Position=3, ParameterSetName="Params")]
        [String]$Domain=".",
        [Parameter(Mandatory=$false)]
        [int]$AutoLogonLimit=100000
    )

    $templatePath = "$PSScripRoot\.assets\templates\winlogon.tmplt.reg"
    $Values = $null

    switch ($PSCmdlet.ParameterSetName) {

        "Params" {
            $values = @{
                Username    = $Username
                Password    = Unlock-SecureString $Password
                Domain      = $Domain
            }
        }

        "Credential" {
            $values = @{
                Domain      = "."
                Password    = Unlock-SecureString $LogonCredential.Password
            }
            $LogonCredential.UserName -match "((?<domain>.+)\\)?(?<username>.+)"
            if ($matches.domain) {
                $v.domain = $matches.domain
            }
            $v.Username = $matches.Username
        }

    }
    
    $values.AutoLogonLimit = $AutoLogonLimit

    $tmpFile = [System.IO.Path]::GetTempFileName()

    Rendter-Template $templatePath $values > $tmpFile

    reg import $tmpFile
    Remove-Item $tmpFile
}