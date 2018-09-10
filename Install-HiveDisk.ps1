. "$PSScriptRoot\ShoutOut.ps1"
. "$PSScriptRoot\Run-Operation.ps1"
. "$PSScriptRoot\RegexPatterns.ps1"
. "$PSScriptRoot\Parse-ConfigFile.ps1"
. "$PSScriptRoot\Find-VolumePath.ps1"
. "$PSScriptRoot\Change-DriveLetter.ps1"

<#
.WISHLIST
    - [Done 20170418 - Functionality moved to Caffeinate] Should take the hive.ini configuration
      files and merge them with the main configuration, letting each hive add directives
      (like VMPath) to make the configuration more modular.

      The idea being that simply including a properly configured hive should make the resources
      of that hive available to installer.

      This needs to be made permanent somehow, so that subsequent restarts can find the hive-config
      and use the directives from that one to inform further steps (like CAFSetup).
        - This could be done by simply copying the hive.ini to a subfolder under the configuration
          file's home directory, and either 1) adding an #include statement to the configuration file
          for each hive file or 2) making the parent script look for that subfolder and add any
          confifuration files found within to the confiuration at load-time.
          
          Both solutions have merit, the difficulty comes from managing the includes.

          Solution 1 makes the inclusion process a part of the natural configuration file life-cycle
          and is very easy to implement (simply append an #include to the configuration file
          [Note: This function doesn't currently know where the setup file is located]), it would
          neccessitate reloading the configuration file for the parent script.

          Solution 2 requires specialized logic in the parent script to deal with an exception or
          extension of the configuration file life-cycle, alternatively it would require making
          changes to the parser.

.SYNPOSIS
    Attaches and configures a hive-style VHD pod.

.NOTES
    - Mounts VHDs as VHDs rather than as DiskImages, because for whatever reason Hyper-V cannot start VMs located on
      volumes mounted as DiskImages. However, this means that hive disks need the Hyper-V feature to function, since
      it relies on cmdlets in the Hyper-V module.
    - 'hive.ini' files have 3 unique directives that go into the [Install] section:
       * DriveLetter: specifies the drive-letter that should be assigned to this hive. Any volume already using that
            driveletter will be moved to Z
       * MountPoint: specifies a location within a pre-existing FS that the hive should be mounted.
            [!Warning!][20170419] This option is NOT compatible with DriveLetter, and only one mount point can currently
            be used per hive. This is to avoid ambiguous paths, as Hyper-V VHDs recalculate their ParentPaths
            when volumes are moved (and they seem to favor using drive letters when possible).

            If you specify both a DriveLetter and a MountPoint directive, then the MountPoint should take precedence
            and the drive letter be removed.
            
#>
function Install-HiveDisk{
    param(
        [parameter(ValueFromPipeline=$true, Position=1)][System.IO.FileInfo]$File,
        [Parameter(Postion=2, Mandatory=$false)][hashtable]$Credential = @{
            Username='MDTUser'
            Password='Pa$$w0rd'
            Domain=$env:COMPUTERNAME
        }
    )

    if ( !(Get-Module Hyper-V -ListAvailable )) {
        ShoutOut "Unable to install, no 'Hyper-V' module available (install relies on VHD cmdlets)!" Yellow
        return
    } 

    $podPath = $File.FullName

    $image = { $podPath | Get-VHD } | Run-Operation
    if (!$image -or $image -is [System.Management.Automation.ErrorRecord]) {
        shoutOut "Could not open '$podPath' as a VHD!" Red
        return
    }

    if (!$image.Attached) {
        shoutOut "Mounting '$podPath'" Cyan
        $image | Mount-VHD
        $image = $image | Get-VHD
    }

    $disk = $image | Get-Disk

    shoutOut ("Mounted as disk #{0}..." -f $disk.Number ) Cyan

    $partitions = $disk | Get-Partition

    shoutOut ("Found {0} partitions..." -f @($partitions).Count ) Cyan

    $partitions | % {
        shoutOut ("Inspecting partition {0}" -f $_.PartitionNumber) Cyan
        $partition = $_
        $volume = $Partition | Get-Volume
        $volumePath = Find-VolumePath $volume
        if ( !$volumePath ) {
            shoutOut "No mount point assigned, ignoring...."
            return
        }

        if ($volumePath -notmatch "[\\/]$") { $volumePath += "\" }

        $driveRoot = $volumePath # "$($partition.DriveLetter):\"
        shoutOut "`$driveRoot='$driveRoot'" Cyan

        $conf = @{}

        if (Test-Path "${driveRoot}hive.ini") {
            shoutOut "Partition contains a hive configuration file, parsing..."
            $conf = Parse-ConfigFile "$driveRoot\hive.ini"
            shoutOut "Done!" Green
        }

        if ($iconf = $conf.Install) {
            if ($iconf.DriveLetter) {
                $iconf.DriveLetter | ? {
                    $valid = $_ -match "^[D-Z]$"
                    if (!$valid) {
                        shoutOut "Invalid Drive Letter: '$_' (Note: A, B, and C are reserved and cannot be used)" Red
                        return $false
                    }
                    if ($_ -eq $partition.DriveLetter) {
                        shoutOut "Partition already has drive letter $($_.DriveLetter)" Green
                        return $false
                    }
                    return $true
                } | % {
                    $dl = $_
                    
                    { Change-DriveLetter $partition.DriveLetter $dl -ByDriveLetter } | Run-Operation -OutNull

                    $partition = $partition  | Get-Partition
                    $driveRoot = "$($partition.DriveLetter):\"
                }
            }
            if ($iconf.MountPoint) {
                $iconf.MountPoint | % {
                    if ( $_ -notmatch $RegexPatterns.Directory ) {
                        shoutOut "Mount point specification does not match the expected format for a directory: '$_'" Red
                        return
                    }

                    $dir = $_

                    if ( !(Test-Path $dir) ) {
                        mkdir $dir
                    }

                    $volume = $partition | Get-Volume

                    # "gwmi -query" uses regular escape sequences, so '\\' becomes '\' and (e.g.) '\a' becomes 'a', '\n' is newline, etc.
                    # So we need to escape the '\'. -replace is a regex operator so it also uses regular escape sequences, thus
                    #     -replace "\\","\\"
                    # will actually replace every instance of '\' rather than every instance of '\\'.
                    #
                    # Furthermore, the specification for MSFT_Volume changes between 2012R2 and 2016. 
                    if ($volume.uniqueID) { # UniqueId takes the original meaning of ObjectID in WS2016,
                                            # where the meaning of objectID changes to the fully qualified path(?).
                        $id = $volume.uniqueID -replace "\\","\\"
                    } else { # In 2012R2, ObjectID is the unique id for the MSFT_Volume.
                        $id = $volume.objectID -replace "\\","\\"
                    }

                    # The following piece of code could maybe be replaced with a call to mountvol.exe?

                    $w32_volume = gwmi -query "select * From Win32_Volume Where DeviceID='$id'"
                
                    if (!$w32_volume) {
                        shoutOut "Unable to get Win32_Volume instance for the hive! Unable to assign mountpoint" Red
                        return
                    }

                    { $w32_volume.AddMountPoint($dir) } | Run-Operation | Out-Null

                    $w32_volume.DriveLetter = $null
                    $w32_volume.put()

                    $driveRoot = $dir
                }
            }
            if ($iconf.Symlink) { # Set up symlinks
                $iconf.Symlink | % {
                    $line = $_
                    $defaultTarget = $driveRoot
                    switch -Regex ($line) {
                        $RegexPatterns.File {
                            $link = $Matches.file
                        }
                        $RegexPatterns.Directory {
                            $link = $Matches.directory
                        }
                        default {
                            shoutOut "Invalid Symlink path: '$_'" Red
                            return
                        }
                    }

                    $remainder = $line.Remove(0, $link.Length)

                    if ($remainder.Length -gt 1) {
                        $remainder = $remainder.Remove(0, 1)
                        $targetIsDirectory = $true
                        switch -Regex ($remainder) {
                            $RegexPatterns.File {
                                $targetIsDirectory = $false
                                $target = $Matches.file
                            }
                            $RegexPatterns.Directory {
                                $target = $Matches.directory
                            }
                            default {
                                shoutOut "No target specified/recognized, using default target '$driveRoot'..." Yellow
                                $target = $defaultTarget
                            }
                        }
                    } else {
                         $target = $defaultTarget
                    }

                    $cmd = if ($targetIsDirectory) {
                        "cmd /C mklink /J '$link' '$target'"
                    } else {
                        "cmd /C mklink '$link' '$target'"
                    }

                    $cmd | Run-Operation
                }
            }

        }


        $tn = "MountHive($($File.Name))"
        if ($t = Get-ScheduledTask | ? {$_.TaskName -eq $tn}) {
            shoutOut "Found a startup task for this hive, removing it.... " Cyan -NoNewline
            $t | Unregister-ScheduledTask -Confirm:$false
            shoutOut "Done!" Green
        }

        shoutOut "Adding startup task to mount the hive... " Cyan -NoNewline

        $ta = New-ScheduledTaskAction -Execute "Powershell" -Argument "-NonInteractive -Command Mount-VHD '$($File.FullName)'"
        $tt = New-ScheduledTaskTrigger -AtStartup
        $ts = New-ScheduledTaskSettingsSet -StartWhenAvailable -DontStopIfGoingOnBatteries
        $t = New-ScheduledTask -Action $ta -Trigger $tt -Settings $ts
        $r = $t | Register-ScheduledTask -User "$env:COMPUTERNAME\MDTUser" -Password 'Pa$$w0rd' -TaskName $tn
        shoutOut "Done!" Green
    }
}