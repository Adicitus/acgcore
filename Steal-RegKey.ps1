. "$PSScriptRoot\Run-Operation.ps1"
. "$PSScriptRoot\Set-ProcessPrivilege.ps1"

<#
.SYNOPSIS
    Grants ownership of the given registry key to the designated user (default is the current user).
.PARAMETER RegKey
    The registry key to steal, can be specified with or without a root key (HKLM, HKCU, HKU, etc.).
    if no root key is specified then the key is presumed to be under HKLM.

    Root keys can be designated in their short form (e.g. HKLM, HKCU) or their full-length
    form (e.g. HKEY_LOCAL_MACHINE, HKEY_CURRENT_USER).
    
    Separating the root key by a colon (:) is optional. Both "HKLM\" and "HKLM:\" are valid
    ways of designating the HKEY_LOCAL_MACHINE root key.
.PARAMETER User
    The name of the user that should become the owner of the given registry key.
#>
function Steal-RegKey {
    param(
        [parameter(Mandatory=$true,  Position=1)][String]$RegKey,
        [parameter(Mandatory=$false, position=2)][String]$User=[System.Security.Principal.WindowsIdentity]::GetCurrent().Name
    )

    Set-ProcessPrivilege SeTakeOwnershipPrivilege

    $OriginalRegKey = $RegKey 
    $registry = $null

    switch -regex ($RegKey) {
        "^(HKEY_LOCAL_MACHINE|HKLM)(:)?[\\/]" {
            $registry = [Microsoft.Win32.Registry]::LocalMachine
            $RegKey = $RegKey -replace "^[^\\/]+[\\/]",""
        }
        "^(HKEY_CURRENT_USER|HKCU)(:)?[\\/]" {
            $registry = [Microsoft.Win32.Registry]::CurrentUser
            $RegKey = $RegKey -replace "^[^\\/]+[\\/]",""
        }
        "^(HKEY_USERS|HKU)(:)?[\\/]" {
            $registry = [Microsoft.Win32.Registry]::Users
            $RegKey = $RegKey -replace "^[^\\/]+[\\/]",""
        }
        "^(HKEY_CURRENT_CONFIG|HKCC)(:)?[\\/]" {
            $registry = [Microsoft.Win32.Registry]::Users
            $RegKey = $RegKey -replace "^[^\\/]+[\\/]",""
        }
        "^(HKEY_CLASSES_ROOT|HKCR)(:)?[\\/]" {
            $registry = [Microsoft.Win32.Registry]::Users
            $RegKey = $RegKey -replace "^[^\\/]+[\\/]",""
        }
        default {
            $registry = [Microsoft.Win32.Registry]::LocalMachine
        }
    }

    $key = { $registry.OpenSubKey(
        $RegKey,
        [Microsoft.Win32.RegistryKeyPermissionCheck]::ReadWriteSubTree,
        [System.Security.AccessControl.RegistryRights]::takeownership
    ) } |Run-Operation

    if (!$key) {
        shoutOut "Unable to find '$OriginalRegKey'" Red
        return 
    }

    # You must get a blank acl for the key b/c you do not currently have access
    $acl = { $key.GetAccessControl([System.Security.AccessControl.AccessControlSections]::None) } | Run-Operation
    $me = [System.Security.Principal.NTAccount]$user
    $acl.SetOwner($me)
    { $key.SetAccessControl($acl) } | Run-Operation | Out-Null

    # After you have set owner you need to get the acl with the perms so you can modify it.
    $acl = { $key.GetAccessControl() } | Run-Operation
    $rule = New-Object System.Security.AccessControl.RegistryAccessRule ("BuiltIn\Administrators","FullControl","Allow")
    { $acl.SetAccessRule($rule) } | Run-Operation | Out-Null
    { $key.SetAccessControl($acl) } | Run-Operation | Out-Null

    $key.Close()
    shoutOut "Done!" Green
}