# Utility to acquire registry values using reg.exe (uses Invoke-ShoutOut)
function Get-RegValue($key, $name){
    $regValueQVregex = "\s+{0}\s+(?<type>REG_[A-Z]+)\s+(?<value>.*)"
    { reg query $key /v $name } | Invoke-ShoutOut | Where-Object { 
        $_ -match ($regValueQVregex -f $name)
    } | ForEach-Object {
        $v = $Matches.value
        switch($Matches.type) {
            REG_QWORD {
                $i64c = New-Object System.ComponentModel.Int64Converter
                $v = $i64c.ConvertFrom($v)
            }
            REG_DWORD {
                $i32c = New-Object System.ComponentModel.Int32Converter
                $v = $i32c.ConvertFrom($v)
            }
        }

        $v
    }
}