function Load-Credential {
    [CmdletBinding()]
    param(
        $path,
        $Key
    )

    $credStr = [System.IO.File]::ReadAllText($path, [System.Text.Encoding]::UTF8)
    $u, $p = $credStr.split(":")
    
    $ConvertArgs = @{
        String=$p
    }

    if ($key) {
        $keyBytes = [System.Convert]::FromBase64String($key)
        $ConvertArgs.Key = $keyBytes
    }

    New-Object PScredential $u, (ConvertTo-SecureString @ConvertArgs)
}