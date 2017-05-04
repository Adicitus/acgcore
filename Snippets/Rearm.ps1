
$rearmFiles = ls -Recurse "${env:ProgramFiles(x86)}" -Filter "*ospp.vbs" | % { $_.FullName }
if ($rearmFiles) { write-Output ( "Rearm files found: {0}" -f ($rearmFiles -join ", ") ) }
$rearmFiles | % { 
    Write-Output "Checking '$_'..."
    $r = cscript $_ /dstatus
    $rf = $r -join "`n"
    if ($rf -match "REMAINING GRACE: [0-6] days") {
        Write-Output "Rearming using '$_'..."
        cscript $_ /rearm
        Write-Output "Done!"
    } else {
        Write-Output "No Need to rearm!"
    }

}
            
$licenses = Get-WmiObject SoftwareLicensingProduct | ? {
    $_.LicenseStatus -ne 1
} | ? {
    $_.PartialProductKey -and ($_.Licensefamily -match "Office|Eval") -and ( ($_.LicenseStatus -eq 5) -or ( ($_.GracePeriodRemaining -lt (1 * 24 * 60))) )
} # wait until the last 24h to rearm, since we only get ~5 days with some versions of office.,


if ($licenses) {
    
    $licenses | % {
        Write-Output "$($_.Description) ($($_.LicenseFamily)): $($_.LicenseStatus) ($($_.GracePeriodRemaining) minutes left, $($_.RemainingSkuReArmCount) SKU rearms left)"
                
        try {
            if ($_.Licensefamily -match "Office|Eval") {
                $_.ReArmSku()
            }
            sleep 10
        } catch {
            $_
        }     
    }
} else {
    Write-Host "No SoftwareLicenses needed to be rearmed" -ForegroundColor Green
}