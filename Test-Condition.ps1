function Test-Condition{
    param(
        [Parameter(Mandatory=$true,  Position=1)][scriptblock]$Test,
        [Parameter(Mandatory=$false, Position=2)][scriptblock]$OnPass=$null,
        [Parameter(Mandatory=$false, Position=3)][scriptblock]$OnFail=$null,
        [Parameter(Mandatory=$false, Position=4)][scriptblock]$Evaluate = { param($v) $true -eq $v }
    )

    $r = & $Test
    $pass = & $Evaluate $r

    if ($pass) {
        if ($OnPass) { & $OnPass }
    } else {
        if ($OnFail) { & $OnFail }
    }

    return $pass

}