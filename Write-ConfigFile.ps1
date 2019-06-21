function Write-ConfigFile {
    param(
        [hashtable]$Config,
        [string]$Path
    )

	[string[]]$output = @()
	foreach ($key in $Config.keys)
	{
		$output += "[$key]" #`r`n"
		foreach($item in $config[$key].keys)
		{
            foreach ($value in $config[$key][$item])
            {
			    $output += (($item,"$value".trimend() | Where-Object {$_}) -join '=') # + "`r`n"
            }
		}
	}
	if ($PSBoundParameters.ContainsKey('Path'))
	{
		if (!(test-path $Path))
		{
			new-item -itemtype file -force -Path $Path | out-null
		}
		$output | out-file -force -filepath $Path 
	}
	else
	{
		$output
	}
}