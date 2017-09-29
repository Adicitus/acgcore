function Remove-LogonOp {
    param(
        [string]$name,
        [Switch]$RunOnce,
        [Switch]$Details
    )

    $path = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\"

    if ($PSBoundParameters.ContainsKey("RunOnce")) {
        $path += "RunOnce"
    } else {
        $path += "Run"
    }

    try {
        Remove-ItemProperty -Path $path -Name $name -Force -ErrorAction Stop | Out-Null
        return $true
    } catch {
        if ($Details) {
            return $_
        } else {
            return $false
        }
    }
}