function Write-ConfigFile {
    param(
        [hashtable]$Config,
        [string]$Path
    )

	[string[]]$output = @()
	$keys = $Config.keys

	$keys = $Keys | Sort-Object

	foreach ($key in $keys)
	{
		$output += "[$key]"
		foreach($item in $config[$key].keys)
		{
            foreach ($value in $config[$key][$item])
            {
				if (!$value) {
					# Entry, just append it to the output
					$output += $item
					continue
				}

				# Setting, Append <item>=<value> to output for each value.
				$value = $value.Replace("#", "\#").trimend() 
			    $output += (
					($item, $value | Where-Object {$_}) -join '='
				)
            }
		}
		$output += "" # Empty line between each section to make output more readable.
	}


	if ($PSBoundParameters.ContainsKey('Path'))
	{
		if (!(test-path $Path))
		{
			new-item -itemtype file -force -Path $Path | out-null
		}
		[System.IO.File]::WriteAllLines($Path, $output, [System.Text.Encoding]::UTF8)
		#$output | out-file -force -filepath $Path 
	}
	else
	{
		$output
	}

}