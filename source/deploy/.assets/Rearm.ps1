
Write-Output "Starting rearm snippet..."

"Looking for Office rearm files (ospp.vbs) under '${env:ProgramFiles(x86)}'..." | Write-Output

$rearmFiles = ls -Recurse "${env:ProgramFiles(x86)}" -Filter "*ospp.vbs" | % { $_.FullName }
if ($rearmFiles) { write-Output ( "Rearm files found: {0}" -f ($rearmFiles -join ", ") ) }
$rearmFiles | % { 
    Write-Output "Checking '$_'..."
    $r = cscript $_ /dstatus
    $r | % { "  | $_" } | Write-Output
    $rf = $r -join "`n"
    if ($rf -match "REMAINING GRACE: [0-6] days") {
        Write-Output "Rearming using '$_'..."
        try {
            cscript $_ /rearm | Out-String | Write-Output
            Write-Output "Done!"
        } catch {
            $_ | Out-String | Write-Output
        }
    } else {
        Write-Output "No Need to rearm!"
    }

}

"Finished checking for office rearm files." | Write-Output

"Checking licensing store (SoftwareLicensingProduct)..." | Write-Output

$licenses = Get-WmiObject SoftwareLicensingProduct | ? {
    $_.LicenseStatus -ne 1
} | ? {
    $_.PartialProductKey -and ($_.Licensefamily -match "Office|Eval") -and ( ($_.LicenseStatus -eq 5) -or ( ($_.GracePeriodRemaining -lt (1 * 24 * 60))) )
} # wait until the last 24h to rearm, since we only get ~5 days with some versions of office.,


if ($licenses) {
    
    $licenses | % {
        Write-Output "Rearming: $($_.Description) ($($_.LicenseFamily)): $($_.LicenseStatus) ($($_.GracePeriodRemaining) minutes left, $($_.RemainingSkuReArmCount) SKU rearms left)"
                
        try {
            if ($_.Licensefamily -match "Office|Eval") {
                $_.ReArmSku() | Out-String | Write-Output
            }
            sleep 10
        } catch {
            $_ | Out-String | Write-Output 
        }     
    }
} else {
    Write-Host "No SoftwareLicenses needed to be rearmed" -ForegroundColor Green
}

Write-Output "Rearm snippet finished running."