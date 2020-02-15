# Utility to acquire registry values using reg.exe (uses Run-Operation)
function Query-RegValue($key, $name){
    $regValueQVregex = "\s+{0}\s+(?<type>REG_[A-Z]+)\s+(?<value>.*)"
    { reg query $key /v $name } | Run-Operation | ? {  $_ -match ($regValueQVregex -f $name) } | % {
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