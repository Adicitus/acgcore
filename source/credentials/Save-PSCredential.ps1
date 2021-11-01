function Save-PSCredential(
    [PSCredential] $Credential,
    [string] $Path,
    [switch] $UseKey,
    [string] $Key
) {

    $convertArgs = @{
        SecureString = $Credential.Password
    }

    if ($UseKey) {
        if ($Key) {
            $bytes = [System.Convert]::FromBase64String($Key)
            if ($bytes.count -ne 32) {
                throw "Invalid key provided for Save-Credential (expected a Base64 string convertable to a 32 byte array)."
            }
        } else {
            $r = [System.Random]::new()
            $bytes = [byte[]]( 0..31 | % { $r.next(0, 255) } )
        }
        $convertArgs.Key = $bytes
    }

    $credStr = "{0}:{1}" -f $Credential.Username, (ConvertFrom-SecureString @convertArgs)
    $credStr | Out-File -FilePath $Path -Encoding utf8

    if ($UseKey) {
        return [System.Convert]::ToBase64String($convertArgs.Key)
    }

}