# Found @ http://stackoverflow.com/questions/16926127/powershell-to-resolve-junction-target-path
# Originally from: http://chrisbensen.blogspot.se/2010/06/getfinalpathnamebyhandle.html

function Global:Get_UNCPath($l_dir)
{
    if( ( ([System.Management.Automation.PSTypeName]'System.Win32').Type -eq $null)  -or ([system.win32].getmethod('GetSymbolicLinkTarget') -eq $null) )
    {
        Add-Type -MemberDefinition @"
private const int CREATION_DISPOSITION_OPEN_EXISTING = 3;
private const int FILE_FLAG_BACKUP_SEMANTICS = 0x02000000;

[DllImport("kernel32.dll", EntryPoint = "GetFinalPathNameByHandleW", CharSet = CharSet.Unicode, SetLastError = true)]
 public static extern int GetFinalPathNameByHandle(IntPtr handle, [In, Out] StringBuilder path, int bufLen, int flags);

[DllImport("kernel32.dll", EntryPoint = "CreateFileW", CharSet = CharSet.Unicode, SetLastError = true)]
 public static extern SafeFileHandle CreateFile(string lpFileName, int dwDesiredAccess, int dwShareMode,
 IntPtr SecurityAttributes, int dwCreationDisposition, int dwFlagsAndAttributes, IntPtr hTemplateFile);

 public static string GetSymbolicLinkTarget(System.IO.DirectoryInfo symlink)
 {
     SafeFileHandle directoryHandle = CreateFile(symlink.FullName, 0, 2, System.IntPtr.Zero, CREATION_DISPOSITION_OPEN_EXISTING, FILE_FLAG_BACKUP_SEMANTICS, System.IntPtr.Zero);
     if(directoryHandle.IsInvalid)
     {
         throw new Win32Exception(Marshal.GetLastWin32Error());
     }
     StringBuilder path = new StringBuilder(512);
     int size = GetFinalPathNameByHandle(directoryHandle.DangerousGetHandle(), path, path.Capacity, 0);
     if (size<0)
     {
         throw new Win32Exception(Marshal.GetLastWin32Error());
     }
     // The remarks section of GetFinalPathNameByHandle mentions the return being prefixed with "\\?\"
     // More information about "\\?\" here -> http://msdn.microsoft.com/en-us/library/aa365247(v=VS.85).aspx
     string sPath = path.ToString();
     if( sPath.Length>8 && sPath.Substring(0,8) == @"\\?\UNC\" )
     {
         return @"\" + sPath.Substring(7);
     }
     else if( sPath.Length>4 && sPath.Substring(0,4) == @"\\?\" )
     {
         return sPath.Substring(4);
     }
     else
     {
         return sPath;
     }
 }
"@ -Name Win32 -NameSpace System -UsingNamespace System.Text,Microsoft.Win32.SafeHandles,System.ComponentModel
    }
    [System.Win32]::GetSymbolicLinkTarget($l_dir)
}