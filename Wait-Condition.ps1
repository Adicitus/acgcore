function Wait-Condition{
    param(
        [Parameter(Mandatory=$true,  Position=1)][scriptblock]$Test,
        [Parameter(Mandatory=$false, Position=2)][scriptblock]$OnPass=$null,
        [Parameter(Mandatory=$false, Position=3)][scriptblock]$OnFail=$null,
        [Parameter(Mandatory=$false, Position=4)][scriptblock]$Evaluate = { param($v) $true -eq $v },
        [Parameter(Mandatory=$false, Position=5)][int]$IntervalMS=200,
        [Parameter(Mandatory=$false, Position=6)][int]$TimeoutMS=0
    )

    $__waitStart__ = [datetime]::Now
    do {
        if ($TimeoutMS -gt 0) {
            $t = ([datetime]::Now - $__waitStart__).TotalMilliSeconds
            if ($t -gt $TimeOutMS) {
                if ($OnFail) { & $OnFail }
                return $false
            }
        }

        Start-Sleep -MilliSeconds $IntervalMS
        $r = Test-Condition -Test $Test -Evaluate $Evaluate
    } while(!$r)

    if ($OnPass) { & $OnPass }

    return $true

}