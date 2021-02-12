function Save-Credential(
    [PSCredential] $Credential,
    [string] $Path,
    [switch] $UseKey
) {

    $convertArgs = @{
        SecureString = $Credential.Password
    }

    if ($UseKey) {
        $r = [System.Random]::new()
        $bytes = [byte[]]( 0..31 | % { $r.next(0, 255) } )
        $convertArgs.Key = $bytes
    }

    $credStr = "{0}:{1}" -f $Credential.Username, (ConvertFrom-SecureString @convertArgs)
    [System.IO.File]::WriteAllText($path, $credStr, [System.Text.Encoding]::UTF8)

    if ($UseKey) {
        return [System.Convert]::ToBase64String($convertArgs.Key)
    }

}