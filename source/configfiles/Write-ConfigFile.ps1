function Write-ConfigFile {
    param(
        [hashtable]$Config,
        [string]$Path
    )

    [string[]]$output = @()
    $keys = $Config.keys

    $keys = $Keys | Sort-Object

    foreach ($key in $keys) {
        $output += "[$key]"
        foreach ($item in $config[$key].keys) {
            foreach ($value in $config[$key][$item]) {
                if ($null, "" -contains $value) {
                    # Entry, just append it to the output
                    $output += $item
                    continue
                }

                # Setting, Append <item>=<value> to output for each value.
                if ($value -is [string]) {
                    $value = $value.Replace("#", "\#").trimend()
                }
                $output += "{0}={1}" -f $item, $value
            }
        }
        $output += "" # Empty line between each section to make output more readable.
    }


    if ($PSBoundParameters.ContainsKey('Path')) {
        if (!(test-path $Path)) {
            new-item -itemtype file -force -Path $Path | out-null
        }
        Set-Content -Path $Path -Value  $output -Encoding  [System.Text.Encoding]::UTF8
    }
    else {
        $output
    }

}