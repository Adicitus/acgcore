/* Originally taken from P/Invoke.NET with minor adjustments.
 * Found as a part the script at:
 * https://social.technet.microsoft.com/Forums/windowsserver/en-US/e718a560-2908-4b91-ad42-d392e7f8f1ad/take-ownership-of-a-registry-key-and-change-permissions?forum=winserverpowershell
 * Renamed and reformatted for readability.
 */
using System;
using System.Runtime.InteropServices;

public class ProcessPrivilegeAdjustor
{
	[DllImport("advapi32.dll", ExactSpelling = true, SetLastError = true)]
	internal static extern bool AdjustTokenPrivileges(
		IntPtr htok, 
		bool disall,
		ref TokPriv1Luid newst,
		int len,
		IntPtr prev,
		IntPtr relen
	);

	[DllImport("advapi32.dll", ExactSpelling = true, SetLastError = true)]
	internal static extern bool OpenProcessToken(
		IntPtr h, 
		int acc,
		ref IntPtr phtok
	);
	
	[DllImport("advapi32.dll", SetLastError = true)]
	internal static extern bool LookupPrivilegeValue(
		string host,
		string name,
		ref long pluid
	);
	
	[StructLayout(LayoutKind.Sequential, Pack = 1)]
	internal struct TokPriv1Luid
	{
		public int Count;
		public long Luid;
		public int Attr;
	}

	internal const int SE_PRIVILEGE_ENABLED = 0x00000002;
	internal const int SE_PRIVILEGE_DISABLED = 0x00000000;
	internal const int TOKEN_QUERY = 0x00000008;
	internal const int TOKEN_ADJUST_PRIVILEGES = 0x00000020;
	
	public static bool SetPrivilege(long processHandle, string privilege, bool disable) {
		bool retVal;
		TokPriv1Luid tp;
		IntPtr hproc = new IntPtr(processHandle);
		IntPtr htok = IntPtr.Zero;
		retVal = OpenProcessToken(hproc, TOKEN_ADJUST_PRIVILEGES | TOKEN_QUERY, ref htok);
		tp.Count = 1;
		tp.Luid = 0;
		
		if(disable)
		{
			tp.Attr = SE_PRIVILEGE_DISABLED;
		}
		else
		{
			tp.Attr = SE_PRIVILEGE_ENABLED;
		}
		
		retVal = LookupPrivilegeValue(null, privilege, ref tp.Luid);
		retVal = AdjustTokenPrivileges(htok, false, ref tp, 0, IntPtr.Zero, IntPtr.Zero);
		return retVal;
	}
}