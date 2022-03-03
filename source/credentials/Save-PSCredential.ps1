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
            $bytes = for($i = 0; $i -lt 32; $i++) { $r.next(0, 256) }
        }
        $convertArgs.Key = $bytes
    }

    $credStr = "{0}:{1}" -f $Credential.Username, (ConvertFrom-SecureString @convertArgs)
    $credStr | Set-Content -Path $Path -Encoding UTF8

    if ($UseKey) {
        return [System.Convert]::ToBase64String($convertArgs.Key)
    }

}