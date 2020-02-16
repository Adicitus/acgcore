function Create-HiveVHD {
    param(
        $PackageName,
        $Label=$PackageName,
        $DestinationDir="C:\",
        $MaxSize=450GB,
        [Switch]$NonDeduplicated,
        [Switch]$Fixed
    )
	
    $params = @{
        FileName="$PackageName.hive.vhdx"
        Label=$Label
        DestinationDir="$DestinationDir\"
        MaxSize=$MaxSize
    }

    if ($PSBoundParameters.ContainsKey("NonDeduplicated")) {
        $params.NonDeduplicated = $true
    }
    if ($PSBoundParameters.ContainsKey("Fixed")) {
        $params.Fixed = $true
    }

    $vhd = Create-PodVHD @params
    
    $path = $vhd | Get-Disk | Get-Partition | Get-Volume | Find-VolumePath

    
    Write-Host "Adding hive.ini... " -NoNewline
    $hiveConfig = [System.IO.File]::create("${path}hive.ini")
    $path = $hiveConfig.Name
    $acl = $hiveConfig.GetAccessControl()
    $ar = New-Object System.Security.AccessControl.FileSystemAccessRule("Everyone", "FullControl", "Allow")
    $acl.SetAccessRule($ar)
    [System.IO.File]::SetAccessControl($path, $acl)
    $hiveConfig.Close()
    Write-Host "Done!" -ForegroundColor Green

    Write-Host "Hiding hive.ini..." -NoNewline
    [System.IO.File]::SetAttributes($path, [System.IO.FileAttributes]::Hidden)
    Write-Host "Done!" -ForegroundColor Green


    return $vhd
}