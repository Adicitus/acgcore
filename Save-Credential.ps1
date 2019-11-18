function Save-Credential(
    [PSCredential] $Credential,
    [string] $path
) {

    $credStr = "{0}:{1}" -f $Credential.Username, (ConvertFrom-SecureString $credential.Password)
    [System.IO.File]::WriteAllText($path, $credStr, [System.Text.Encoding]::UTF8)

}