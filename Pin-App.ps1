#https://docs.microsoft.com/sv-se/windows/configuration/configure-windows-10-taskbar


function Pin-App 
{
    param(
        [ValidateScript({$list = (New-Object -Com Shell.Application).NameSpace('shell:::{4234d49b-0245-4df3-b780-3893943456e1}').Items() | % Name;if(($_ | ? {$_ -notin $list})) {Write-Warning "Available applications are:`n$($list -join "`n")";return $false} else {return $true}})][string[]]$Application,
        [switch]$Unpin
    )
    if (!$Application)
    {
        return
    }
    
    $exepath = "$env:TEMP\explorer.exe"
    #Ugly Hack
    if ( !$StartMenu.IsPresent -and !(Test-Path $exepath))
    {
        #Register-ScheduledTask -TaskName hack -Action (New-ScheduledTaskAction -Execute cmd -Argument "/c mklink $exepath $pshome\powershell.exe") -Principal (New-ScheduledTaskPrincipal -UserId system) -Trigger (New-ScheduledTaskTrigger -Once -At (get-date).addDays(-1)) | Start-ScheduledTask
        #Unregister-ScheduledTask -TaskName hack -Confirm:$false
		Copy-Item "$pshome\powershell.exe" $exepath
    }
    
    if ($Unpin.IsPresent)
    {
        $verb = 'taskbarunpin'
    }
    else
    {
        $verb = 'taskbarpin'
    }

    foreach ($appname in $Application)
    {
        #Ugly ureadable one-liner
        $command = "& {((New-Object -Com Shell.Application).NameSpace('shell:::{4234d49b-0245-4df3-b780-3893943456e1}').Items() | ?{`$_.Name -eq '$appname'}).InvokeVerb('$verb')}"
        & $exepath -command $command
    }

    #Clean up after ugly hack
    #Remove-Item $exepath
}