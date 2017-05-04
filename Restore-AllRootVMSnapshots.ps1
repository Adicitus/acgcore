Get-Vm | Get-VMSnapshot | ? { !$_.ParentSNapshot} | Restore-VMSnapshot -Confirm:$false
 