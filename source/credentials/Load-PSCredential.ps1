function Load-PSCredential {
    [CmdletBinding()]
    param(
        $Path,
        $Key
    )

    $Path = Resolve-Path $path

    $credStr = Get-Content -Path $path -Encoding UTF8
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