﻿. "$PSScriptRoot\Run-Operation.ps1"

function Set-RegValue($key, $name, $value, $type=$null) {
    if (!$type) {
        if ($value -is [int16] -or $value -is [int32]) {
            $type = "REG_DWORD"
        } elseif ($value -is [int64]) {
            $type = "REG_QWORD"
        } else {
            $type = "REG_SZ"
        }
    }
    { reg add $key /v $name /t $type /d $value /f } | Run-Operation
}