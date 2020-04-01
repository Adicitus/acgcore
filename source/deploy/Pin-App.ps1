#https://docs.microsoft.com/sv-se/windows/configuration/configure-windows-10-taskbar


function Pin-App {
    param(
        [string[]]$Application,
        [switch]$Unpin
    )
    if (!$Application) {
        return
    }
    
    $exepath = "$env:TEMP\explorer.exe"

    #Ugly Hack to circumvent Windows Security...
    if ( !$StartMenu.IsPresent -and !(Test-Path $exepath)) {
        Copy-Item "$pshome\powershell.exe" $exepath
    }

    if (Get-Process -Id $pid | ? {$_.Path -ne $exepath}) {
        $as = @($Application | % {"'$_'"}) -join ", "
        if ($PSBoundParameters.ContainsKey("Unpin")) {
            $as += " -Unpin"
        }
	
        $command = "Pin-App $as"

        & $exepath -Command $command
        return
    }

    $shell = New-Object -Com Shell.Application
    $list = $shell.NameSpace('shell:::{4234d49b-0245-4df3-b780-3893943456e1}').Items()
    if (!($apps = $list | ? {$a = $_; $Application | ? {$a.Name -like $_}})) {
        Write-Warning "None of the desired Applications exist!"
        Write-Warning "Available applications are:`n$(($list | % Name | Sort-Object) -join "`n")"
        return $false
    }
    
    if ($Unpin.IsPresent) {
        $verb = 'taskbarunpin'
    }
    else {
        $verb = 'taskbarpin'
    }

    $apps | % { $_.InvokeVerb($verb) }
}