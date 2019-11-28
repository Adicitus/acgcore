function Wait-Condition{
    param(
        [Parameter(Mandatory=$true,  Position=1)][scriptblock]$Test,
        [Parameter(Mandatory=$false, Position=2)][scriptblock]$Evaluate = { param($v) $true -eq $v },
        [Parameter(Mandatory=$false, Position=3)][int]$IntervalMS=200,
        [Parameter(Mandatory=$false, Position=4)][int]$TimeoutMS=0
    )

    $__waitStart__ = [datetime]::Now
    do {
        if ($TimeoutMS -gt 0) {
            $t = ([datetime]::Now - $__waitStart__).TotalMilliSeconds
            if ($t -gt $TimeOutMS) {
                return $false
            }
        }

        Start-Sleep -MilliSeconds $IntervalMS
        $r = & $Test
    } while(!(& $Evaluate $r))

    return $true

}