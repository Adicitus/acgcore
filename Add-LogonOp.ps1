function Add-LogonOp{
    param(
        [string]$Name,
        [string]$Operation,
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
        $value = "Powershell -WindowStyle Hidden -Command $Operation"
        $r =  New-ItemProperty -Path $path -Name $Name -Value $value -Force -ErrorAction Stop
        if ($Details) {
            return $r
        } else {
            $true
        }
    } catch {
        if ($Details) {
            return $_
        } else {
            $false
        }
    }
}