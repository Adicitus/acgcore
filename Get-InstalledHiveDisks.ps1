# Get-InstalledHiveDisks.ps1
#requires -Modules PSScheduledJob, ShoutOUt

function Get-InstalledHiveDiskPaths {
    param()

    $userDirs = ls C:\Users

    $userDirs | % {
        $path = "{0}\AppData\Local\Microsoft\Windows\PowerShell\ScheduledJobs" -f $_.FullName
        if ((Test-Path $path)) {
            "Found a ScheduledJobs directory under '{0}'." -f $_.Name | ShoutOut
            "Collecting ScheduledJobs..." | ShoutOut
            ls $path | %  {
                "Found '{0}'." -f $_.Name | ShoutOut
                @{ Name=$_.Name; Path= $path }
            }
        }
    } | ? {
        $_.Name -match "^MountHive\((?<hivename>.+)\)$"
    } | % {
        "Loading '{0}'..." -f $_.Name | ShoutOut
        $def = [Microsoft.PowerShell.ScheduledJob.ScheduledJobDefinition]::LoadFromStore($_.Name, $_.Path)
        $vhdPath = $def.InvocationInfo.Parameters[0] | ? { $_.Name -eq "ArgumentList" } | % Value | Select -First 1
        "VHD located @ '{0}'." -f $vhdPath | shoutOut
        $vhdPath
    }
}