@echo off
setlocal DisableDelayedExpansion
set "WH_SCRIPT=%~f0"
set "WH_TEST_ONLY="
if /i "%~1"=="--self-test" set "WH_TEST_ONLY=1"
powershell.exe -NoProfile -Command "$ErrorActionPreference='Stop'; $identity=[Security.Principal.WindowsIdentity]::GetCurrent(); $sid=$identity.User.Value; if (-not $sid) {throw 'Cannot identify current user.'}; $admin=([Security.Principal.WindowsPrincipal]$identity).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator); if (-not $admin -and $env:WH_TEST_ONLY -eq '1') {throw 'Run --self-test from an administrator terminal.'}; $p64=[Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($env:WH_SCRIPT)); $s64=[Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($sid)); $test=if ($env:WH_TEST_ONLY -eq '1') {'1'} else {''}; $runner={ $ErrorActionPreference='Stop'; try { $p=[Text.Encoding]::Unicode.GetString([Convert]::FromBase64String($path64)); $sid=[Text.Encoding]::Unicode.GetString([Convert]::FromBase64String($sid64)); $identity=[Security.Principal.WindowsIdentity]::GetCurrent(); if (-not ([Security.Principal.WindowsPrincipal]$identity).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {throw 'Administrator privileges are required.'}; if ($identity.User.Value -ne $sid) {throw 'Elevation changed the Windows user. Run from the intended administrator account.'}; $env:WH_SCRIPT=$p; $env:WH_ORIGINAL_SID=$sid; $env:WH_TEST_ONLY=$test; $raw=[IO.File]::ReadAllText($p); $marker='### POWERSHELL'+' PAYLOAD ###'; $offset=$raw.LastIndexOf($marker,[StringComparison]::Ordinal); if ($offset -lt 0) {throw 'PowerShell payload not found.'}; & ([scriptblock]::Create($raw.Substring($offset+$marker.Length))) } catch { Write-Host ('ERROR: '+$_.Exception.Message) -ForegroundColor Red; if ($pauseOnError) {[void](Read-Host 'Press Enter to exit')}; exit 1 } }; $prefix='$path64='''+$p64+''';$sid64='''+$s64+''';$test='''+$test+''';$pauseOnError='+$(if ($admin) {'$false'} else {'$true'})+';'; $code=$prefix+$runner.ToString(); if ($admin) {& ([scriptblock]::Create($code))} else { $encoded=[Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($code)); $q=[char]34; $ps=Join-Path $PSHOME 'powershell.exe'; $cmd=Join-Path $env:SystemRoot 'System32\cmd.exe'; $argsLine='/d /s /c '+$q+'color 0F '+[char]38+' '+$q+$ps+$q+' -NoProfile -EncodedCommand '+$encoded+$q; Start-Process -FilePath $cmd -ArgumentList $argsLine -WorkingDirectory (Join-Path $env:SystemRoot 'System32') -Verb RunAs; exit 0 }"
set "WH_EXIT=%errorlevel%"
if not "%WH_EXIT%"=="0" pause
exit /b %WH_EXIT%
### POWERSHELL PAYLOAD ###
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem
$base = [IO.Path]::GetDirectoryName($env:WH_SCRIPT)
if ([string]::IsNullOrWhiteSpace($base) -or -not (Test-Path -LiteralPath $base -PathType Container)) { throw 'Cannot determine the script directory.' }
$data = Join-Path $env:ProgramData 'Windhawk'
$serviceName = 'Windhawk'
$roots = @('HKLM\SOFTWARE\Windhawk','HKCU\Software\Windhawk')
$regFiles = @('HKLM_Windhawk.reg','HKCU_Windhawk.reg')
$reg = Join-Path $env:SystemRoot 'System32\reg.exe'
if ([Environment]::Is64BitOperatingSystem -and -not [Environment]::Is64BitProcess) { throw 'Use 64-bit Windows PowerShell.' }
function Invoke-Reg([string[]]$Arguments) {
    # Avoid Windows PowerShell 5.1 treating native stderr as a terminating error.
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = $reg
    # All arguments are fixed switches, registry roots or generated file paths.
    # Double quotes cannot occur in Windows file names.
    $psi.Arguments = (($Arguments | ForEach-Object { '"' + $_ + '"' }) -join ' ')
    $psi.UseShellExecute = $false
    $psi.CreateNoWindow = $true
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $proc = [System.Diagnostics.Process]::Start($psi)
    try {
        $stdout = $proc.StandardOutput.ReadToEndAsync()
        $stderr = $proc.StandardError.ReadToEndAsync()
        $proc.WaitForExit()
        $code = $proc.ExitCode
        $message = ($stdout.GetAwaiter().GetResult() + ' ' + $stderr.GetAwaiter().GetResult()).Trim()
        if ($code -ne 0) {throw "Registry operation failed (exit $code): $message"}
    } finally {$proc.Dispose()}
}
function Registry-Exists([int]$i) {
    $hive = if ($i -eq 0) {'Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Windhawk'} else {'Registry::HKEY_CURRENT_USER\Software\Windhawk'}
    return Test-Path -LiteralPath $hive -ErrorAction Stop
}
function New-Temp {
    $p = Join-Path $env:TEMP ('WindhawkBackup-' + [guid]::NewGuid().ToString('N'))
    [void][IO.Directory]::CreateDirectory($p)
    return $p
}
function Remove-Temp([string]$p) {
    if ($p -and (Test-Path -LiteralPath $p)) { try { Remove-Item -LiteralPath $p -Recurse -Force } catch { Write-Warning "Temporary files retained: $p" } }
}
# Only persistent mod binaries and source files are in the file backup scope.
# Engine is a traversal ancestor, not a removable configuration directory.
function Is-OutsideModScope([string]$relative) {
    if ($relative -ieq 'Engine') {return $false}
    foreach ($allowed in @('Engine\Mods','ModsSource')) {
        if ($relative -ieq $allowed -or $relative.StartsWith($allowed+'\',[StringComparison]::OrdinalIgnoreCase)) {return $false}
    }
    return $true
}
function Get-TreeItems([string]$root,[bool]$modScopeOnly=$false,[string]$relative='') {
    foreach ($item in Get-ChildItem -LiteralPath $root -Force) {
        $key = if ($relative) { $relative + '\' + $item.Name } else { $item.Name }
        if ($modScopeOnly -and (Is-OutsideModScope $key)) {continue}
        if ($modScopeOnly -and $key -in @('Engine','Engine\Mods','ModsSource') -and -not $item.PSIsContainer) {throw "Expected a directory: $key"}
        if ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) {throw "Unsupported reparse point: $($item.FullName)"}
        $item
        if ($item.PSIsContainer) {Get-TreeItems $item.FullName $modScopeOnly $key}
    }
}
function Assert-NoLinks([string]$p,[bool]$modScopeOnly=$false) {
    $item = Get-Item -LiteralPath $p -Force
    if ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) {throw "Unsupported reparse point: $p"}
    Get-TreeItems $p $modScopeOnly | Out-Null
}
function Assert-Install {
    $svcInfo = Get-CimInstance Win32_Service -Filter "Name='Windhawk'"
    if (-not $svcInfo) { throw 'Windhawk service not found. Install Windhawk in standard (non-portable) mode first.' }
    if ($svcInfo.PathName -notmatch '(?i)(?:^|[\\/])windhawk\.exe"?\s+-service(?:\s|$)') { throw 'The Windhawk service executable could not be verified.' }
    $null = Get-Service -Name $serviceName
    if (-not (Test-Path -LiteralPath $data -PathType Container)) {throw 'Standard Windhawk data directory not found. Portable/custom installations are not supported.'}
    if (-not (Registry-Exists 0)) {throw 'Windhawk machine registry configuration not found.'}
    Assert-NoLinks $data $true
}
function With-ServiceStopped([scriptblock]$Action) {
    $svc = Get-Service -Name $serviceName
    if ($svc.Status -notin @('Running','Stopped')) {throw "Unexpected service state: $($svc.Status)"}
    $wasRunning = $svc.Status -eq 'Running'
    try {
        if ($wasRunning) { Stop-Service -Name $serviceName; $svc.WaitForStatus('Stopped',[TimeSpan]::FromSeconds(30)) }
        & $Action
    } finally {
        $svc.Refresh()
        if ($wasRunning -and $svc.Status -ne 'Running') { Start-Service -Name $serviceName; $svc.WaitForStatus('Running',[TimeSpan]::FromSeconds(30)) }
    }
}
function Copy-Tree([string]$source,[string]$target) {
    $root = Get-Item -LiteralPath $source -Force
    if ($root.Attributes -band [IO.FileAttributes]::ReparsePoint) {throw "Unsupported reparse point: $source"}
    $prefix = [IO.Path]::GetFullPath($source).TrimEnd('\') + '\'
    [void][IO.Directory]::CreateDirectory($target)
    foreach ($item in Get-TreeItems $source $true) {
        $dest = Join-Path $target $item.FullName.Substring($prefix.Length)
        if ($item.PSIsContainer) { [void][IO.Directory]::CreateDirectory($dest) }
        else { [IO.File]::Copy($item.FullName,$dest,$true) }
    }
}
function Snapshot([string]$target) {
    Copy-Tree $data (Join-Path $target 'ProgramData_Windhawk')
    $rd = Join-Path $target 'Reg'; [void][IO.Directory]::CreateDirectory($rd)
    for ($i=0;$i -lt 2;$i++) { if (Registry-Exists $i) { Invoke-Reg @('export',$roots[$i],(Join-Path $rd $regFiles[$i]),'/y') } }
}
function Assert-Reg([string]$path,[int]$i) {
    $lines = [IO.File]::ReadAllLines($path)
    if ($lines.Count -eq 0 -or $lines[0].Trim() -ne 'Windows Registry Editor Version 5.00') {throw "Invalid registry header: $path"}
    $root = if ($i -eq 0) {'HKEY_LOCAL_MACHINE\SOFTWARE\Windhawk'} else {'HKEY_CURRENT_USER\Software\Windhawk'}
    $found = $false
    foreach ($line in $lines) {
        $s=$line.Trim()
        if ($s.StartsWith('[')) {
            if ($s -notmatch '^\[([^\]]+)\]$') {throw 'Invalid registry section.'}
            $key=$Matches[1]
            if ($key -ine $root -and -not $key.StartsWith($root+'\',[StringComparison]::OrdinalIgnoreCase)) {throw "Registry key outside Windhawk: $key"}
            $found=$true
        } elseif ($s -match '^\s*(?:@|"(?:[^"\\]|\\.)*")\s*=\s*-\s*$') {throw 'Registry deletion entries are not accepted.'}
    }
    if (-not $found) {throw 'Registry file has no Windhawk sections.'}
}
function Assert-Snapshot([string]$p) {
    $d=Join-Path $p 'ProgramData_Windhawk'; $r=Join-Path $p 'Reg'
    if (-not (Test-Path -LiteralPath $d -PathType Container) -or -not (Test-Path -LiteralPath $r -PathType Container)) {throw 'Unsupported or incomplete backup layout.'}
    Assert-NoLinks $p
    $manifest=Join-Path $p 'manifest.json'
    if (Test-Path -LiteralPath $manifest) {
        $m=Get-Content -LiteralPath $manifest -Raw | ConvertFrom-Json
        if ($m.format -ne 1) {throw 'Unsupported backup manifest version.'}
        $actual = Get-Inventory $p $true
        $expected = @{}
        foreach ($entry in @($m.files)) {
            $key = [string]$entry.path
            if ([string]::IsNullOrWhiteSpace($key) -or $expected.ContainsKey($key) -or [string]$entry.sha256 -notmatch '^[0-9A-Fa-f]{64}$') { throw 'Invalid manifest entry.' }
            $expected[$key] = [string]$entry.sha256
        }
        foreach ($key in $expected.Keys) {
            if (-not $actual.ContainsKey($key)) { throw "Backup file missing: $key (expected $($expected.Count), actual $($actual.Count))" }
            if ($actual[$key] -ne $expected[$key]) { throw "Backup hash mismatch: $key" }
        }
        foreach ($key in $actual.Keys) {
            if (-not $expected.ContainsKey($key)) { throw "Unexpected backup file: $key (expected $($expected.Count), actual $($actual.Count))" }
        }
    }
    foreach ($item in Get-ChildItem -LiteralPath $p -Force) {if ($item.Name -notin @('ProgramData_Windhawk','Reg','manifest.json')) {throw "Unexpected backup item: $($item.Name)"}}
    if (-not (Test-Path -LiteralPath (Join-Path $r $regFiles[0]) -PathType Leaf)) {throw 'Machine registry backup missing.'}
    for ($i=0;$i -lt 2;$i++) { $f=Join-Path $r $regFiles[$i]; if (Test-Path -LiteralPath $f) {Assert-Reg $f $i} }
    foreach ($item in Get-ChildItem -LiteralPath $r -Force) {if ($item.PSIsContainer -or $item.Name -notin $regFiles) {throw 'Unexpected registry backup item.'}}
}
function Extract-Safe([string]$zip,[string]$target) {
    try { $z=[IO.Compression.ZipFile]::OpenRead($zip) } catch [System.IO.InvalidDataException] {
        throw "The selected backup is corrupted or is not a valid ZIP archive."
    }
    try {
        $prefix=[IO.Path]::GetFullPath($target).TrimEnd('\')+'\'
        $seen=New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::OrdinalIgnoreCase)
        foreach ($e in $z.Entries) {
            $name=$e.FullName.Replace('/','\')
            if ([IO.Path]::IsPathRooted($name) -or $name.Contains(':') -or $name -match '(^|\\)\.\.?($|\\)') {throw 'Unsafe ZIP entry path.'}
            $parts=$name.TrimEnd('\').Split('\')
            foreach ($part in $parts) {if (-not $part -or $part -match '[. ]$' -or $part -match '^(CON|PRN|AUX|NUL|COM[1-9]|LPT[1-9])(?:\.|$)') {throw 'Unsafe ZIP entry name.'}}
            $dest=[IO.Path]::GetFullPath((Join-Path $target $name))
            if (-not $dest.StartsWith($prefix,[StringComparison]::OrdinalIgnoreCase) -or -not $seen.Add($dest.TrimEnd('\'))) {throw 'Unsafe or duplicate ZIP entry.'}
            if ($name.EndsWith('\')) {[void][IO.Directory]::CreateDirectory($dest)} else {
                [void][IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($dest))
                [IO.Compression.ZipFileExtensions]::ExtractToFile($e,$dest,$false)
            }
        }
    } catch [System.IO.InvalidDataException] {
        throw "The selected backup is corrupted or is not a valid ZIP archive."
    } finally {$z.Dispose()}
    Assert-Snapshot $target
}
function Get-Inventory([string]$p,[bool]$excludeManifest=$false,[bool]$modScopeOnly=$false) {
    $result = @{}
    $prefix = [IO.Path]::GetFullPath($p).TrimEnd('\') + '\'
    foreach ($item in Get-TreeItems $p $modScopeOnly) {
        if ($item.PSIsContainer) {continue}
        $path = $item.FullName
        $rel = $path.Substring($prefix.Length)
        if ($excludeManifest -and $rel -ieq 'manifest.json') { continue }
        $result[$rel] = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash
    }
    return ,$result
}
function Save-Zip([string]$source,[string]$name) {
    $inventory=Get-Inventory $source $true
    $entries=@(foreach ($k in $inventory.Keys) { [pscustomobject]@{path=$k;sha256=$inventory[$k]} })
    ConvertTo-Json -InputObject @{format=1;files=$entries} -Depth 4 | Set-Content -LiteralPath (Join-Path $source 'manifest.json') -Encoding UTF8
    Write-Host "Checking backup manifest..."
    Assert-Snapshot $source
    $final=Join-Path $base $name
    $partial=$final+'.'+[guid]::NewGuid().ToString('N')+'.tmp'
    $verify=New-Temp
    try {
        [IO.Compression.ZipFile]::CreateFromDirectory($source,$partial,[IO.Compression.CompressionLevel]::Optimal,$false)
        Write-Host "Checking ZIP contents..."
        Extract-Safe $partial $verify
        $a=Get-Inventory $source; $b=Get-Inventory $verify
        if ($a.Count -ne $b.Count) {throw 'ZIP verification failed.'}
        foreach ($k in $a.Keys) {if (-not $b.ContainsKey($k) -or $a[$k] -ne $b[$k]) {throw "ZIP verification failed: $k"}}
        [IO.File]::Move($partial,$final)
        Write-Host "Verified backup: $final" -ForegroundColor Green
    } finally {if (Test-Path -LiteralPath $partial) {Remove-Item -LiteralPath $partial -Force}; Remove-Temp $verify}
}
function New-BackupName([string]$prefix='windhawk-backup') {return "$prefix-$(Get-Date -Format 'yyyy-MM-dd_HH-mm-ss-fff').zip"}
function Get-Directories([string]$root,[bool]$modScopeOnly=$false) {
    $prefix = [IO.Path]::GetFullPath($root).TrimEnd('\') + '\'
    $result = @{}
    foreach ($item in Get-TreeItems $root $modScopeOnly) {
        if (-not $item.PSIsContainer) {continue}
        $result[$item.FullName.Substring($prefix.Length)] = $true
    }
    return ,$result
}
function Assert-FileWritable([string]$path) {
    if ([IO.File]::GetAttributes($path) -band [IO.FileAttributes]::ReadOnly) {throw "Read-only file: $path"}
    try {
        $handle = [IO.File]::Open($path,[IO.FileMode]::Open,[IO.FileAccess]::ReadWrite,[IO.FileShare]::None)
        $handle.Dispose()
    } catch {throw "File is locked or access is denied: $path. No restore changes have been made. Close Windhawk and affected applications, then try again. $($_.Exception.Message)"}
}
# Restart Manager is used only for identification. Never ask it to shut down apps.
function Initialize-LockSupport {
    if ('WhBackup.NativeLocks' -as [type]) {return}
    Add-Type -Language CSharp -TypeDefinition @'
using System;
using System.IO;
using System.Text;
using System.Threading;
using System.Diagnostics;
using System.ComponentModel;
using System.Security.Principal;
using System.Runtime.InteropServices;

namespace WhBackup {
    public static class NativeLocks {
        [StructLayout(LayoutKind.Sequential)]
        internal struct UniqueProcess {
            public int Pid;
            public System.Runtime.InteropServices.ComTypes.FILETIME Start;
        }
        [StructLayout(LayoutKind.Sequential, CharSet=CharSet.Unicode)]
        internal struct ProcessInfo {
            public UniqueProcess Process;
            [MarshalAs(UnmanagedType.ByValTStr, SizeConst=256)] public string AppName;
            [MarshalAs(UnmanagedType.ByValTStr, SizeConst=64)] public string ServiceName;
            public uint AppType, AppStatus, Session;
            [MarshalAs(UnmanagedType.Bool)] public bool Restartable;
        }
        public sealed class Owner {
            public int Pid;
            public long StartFileTime;
            public uint AppType, Session;
            public string AppName, ServiceName;
        }
        [DllImport("rstrtmgr.dll", CharSet=CharSet.Unicode, ExactSpelling=true)]
        private static extern int RmStartSession(out uint session, int flags, StringBuilder key);
        [DllImport("rstrtmgr.dll", CharSet=CharSet.Unicode, ExactSpelling=true)]
        private static extern int RmRegisterResources(uint session, uint count,
            [MarshalAs(UnmanagedType.LPArray, ArraySubType=UnmanagedType.LPWStr, SizeParamIndex=1)] string[] files,
            uint appCount, IntPtr apps, uint serviceCount, IntPtr services);
        [DllImport("rstrtmgr.dll", ExactSpelling=true)]
        private static extern int RmGetList(uint session, out uint needed, ref uint count,
            [In, Out] ProcessInfo[] apps, ref uint rebootReasons);
        [DllImport("rstrtmgr.dll", ExactSpelling=true)]
        private static extern int RmEndSession(uint session);
        [DllImport("user32.dll")] private static extern IntPtr GetShellWindow();
        [DllImport("user32.dll")] private static extern uint GetWindowThreadProcessId(IntPtr window, out uint pid);
        public static int ShellPid() {
            uint pid;
            IntPtr window=GetShellWindow();
            if (window==IntPtr.Zero || GetWindowThreadProcessId(window,out pid)==0) return 0;
            return checked((int)pid);
        }
        private static void Check(int rc) {if (rc!=0) throw new Win32Exception(rc);}
        public static Owner[] Owners(string path) {
            uint session;
            Check(RmStartSession(out session,0,new StringBuilder(33)));
            try {
                Check(RmRegisterResources(session,1,new string[]{path},0,IntPtr.Zero,0,IntPtr.Zero));
                uint needed, count=0, reasons=0;
                int rc=RmGetList(session,out needed,ref count,null,ref reasons);
                if (rc==0) {
                    if (reasons!=0 || count!=0) throw new InvalidOperationException("Unresolved Restart Manager result.");
                    return new Owner[0];
                }
                if (rc!=234) Check(rc);
                for(int retry=0;retry<5;retry++) {
                    if (needed==0 || needed>4096) throw new InvalidOperationException("Invalid lock owner count.");
                    count=needed; reasons=0;
                    ProcessInfo[] list=new ProcessInfo[checked((int)count)];
                    rc=RmGetList(session,out needed,ref count,list,ref reasons);
                    if(rc==234) continue;
                    Check(rc);
                    if(reasons!=0) throw new InvalidOperationException("Restart Manager requires a reboot (reason mask " + reasons + ").");
                    if(count>list.Length) throw new InvalidOperationException("Invalid Restart Manager response.");
                    Owner[] result=new Owner[checked((int)count)];
                    for(int i=0;i<result.Length;i++) {
                        ProcessInfo p=list[i];
                        long ft=((long)(uint)p.Process.Start.dwHighDateTime<<32) | (uint)p.Process.Start.dwLowDateTime;
                        result[i]=new Owner {Pid=p.Process.Pid,StartFileTime=ft,AppType=p.AppType,Session=p.Session,AppName=p.AppName,ServiceName=p.ServiceName};
                    }
                    return result;
                }
                throw new InvalidOperationException("Lock owners changed repeatedly.");
            } finally {RmEndSession(session);}
        }
    }

    // Hold the original shell process and its non-elevated primary token before terminating it.
    // Never start Explorer using the elevated backup process's token.
    public sealed class ShellLease : IDisposable {
        [StructLayout(LayoutKind.Sequential, CharSet=CharSet.Unicode)]
        private struct StartupInfo {
            public int cb;
            public string reserved, desktop, title;
            public uint x,y,xSize,ySize,xChars,yChars,fill,flags;
            public ushort show,reserved2;
            public IntPtr reservedPtr,stdInput,stdOutput,stdError;
        }
        [StructLayout(LayoutKind.Sequential)]
        private struct ProcessInformation {public IntPtr process,thread; public uint pid,tid;}
        [DllImport("advapi32.dll", SetLastError=true)]
        private static extern bool OpenProcessToken(IntPtr process,uint access,out IntPtr token);
        [DllImport("advapi32.dll", SetLastError=true)]
        private static extern bool DuplicateTokenEx(IntPtr token,uint access,IntPtr attributes,int level,int type,out IntPtr duplicate);
        [DllImport("advapi32.dll", SetLastError=true)]
        private static extern bool GetTokenInformation(IntPtr token,int infoClass,out int info,int size,out int returned);
        [DllImport("advapi32.dll", SetLastError=true)]
        private static extern bool GetTokenInformation(IntPtr token,int infoClass,IntPtr info,int size,out int returned);
        [StructLayout(LayoutKind.Sequential)]
        private struct Luid {public uint low; public int high;}
        [DllImport("advapi32.dll", CharSet=CharSet.Unicode, SetLastError=true)]
        private static extern bool LookupPrivilegeValue(string system,string name,out Luid luid);
        [DllImport("advapi32.dll", CharSet=CharSet.Unicode, SetLastError=true, ExactSpelling=true)]
        private static extern bool CreateProcessWithTokenW(IntPtr token,uint logonFlags,string app,StringBuilder commandLine,
            uint creationFlags,IntPtr environment,string directory,ref StartupInfo startup,out ProcessInformation info);
        [DllImport("kernel32.dll", SetLastError=true)] private static extern bool CloseHandle(IntPtr handle);
        [DllImport("kernel32.dll", SetLastError=true)] private static extern bool TerminateProcess(IntPtr handle,uint exitCode);
        private Process original;
        private IntPtr token=IntPtr.Zero;
        private IntPtr processHandle=IntPtr.Zero;
        private readonly string explorerPath;
        private readonly int session;
        private readonly long started;
        private bool stopIssued;
        private static bool CanLaunchWithToken() {
            Luid required;
            if(!LookupPrivilegeValue(null,"SeImpersonatePrivilege",out required)) throw new Win32Exception(Marshal.GetLastWin32Error());
            using(WindowsIdentity caller=WindowsIdentity.GetCurrent()) {
                int size;
                GetTokenInformation(caller.Token,3,IntPtr.Zero,0,out size);
                if(size<4) throw new InvalidOperationException("Cannot query restart privileges.");
                IntPtr buffer=Marshal.AllocHGlobal(size);
                try {
                    int returned;
                    if(!GetTokenInformation(caller.Token,3,buffer,size,out returned)) throw new Win32Exception(Marshal.GetLastWin32Error());
                    int count=Marshal.ReadInt32(buffer);
                    if(count<0 || count>(returned-4)/12) throw new InvalidOperationException("Invalid token privilege data.");
                    for(int i=0;i<count;i++) {
                        int offset=4+i*12;
                        if(unchecked((uint)Marshal.ReadInt32(buffer,offset))==required.low && Marshal.ReadInt32(buffer,offset+4)==required.high)
                            return (Marshal.ReadInt32(buffer,offset+8)&2)!=0;
                    }
                    return false;
                } finally {Marshal.FreeHGlobal(buffer);}
            }
        }
        public ShellLease(int pid,long startFileTime,string sid) {
            explorerPath=Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.Windows),"explorer.exe");
            session=Process.GetCurrentProcess().SessionId;
            started=startFileTime;
            try {
                if(!CanLaunchWithToken()) throw new InvalidOperationException("The required non-elevated Explorer restart privilege is unavailable.");
                original=Process.GetProcessById(pid);
                // Access Process.Handle before checking identity so the same process object is retained.
                processHandle=original.Handle;
                if(session==0 || original.SessionId!=session || NativeLocks.ShellPid()!=pid ||
                   original.StartTime.ToUniversalTime().ToFileTimeUtc()!=started ||
                   !String.Equals(original.MainModule.FileName,explorerPath,StringComparison.OrdinalIgnoreCase))
                    throw new InvalidOperationException("The lock owner is not the verified desktop Explorer in this session.");
                IntPtr raw;
                if(!OpenProcessToken(processHandle,0x000A,out raw)) throw new Win32Exception(Marshal.GetLastWin32Error());
                try {
                    using(WindowsIdentity identity=new WindowsIdentity(raw)) {
                        if(identity.User==null || !String.Equals(identity.User.Value,sid,StringComparison.OrdinalIgnoreCase))
                            throw new InvalidOperationException("Explorer belongs to a different user.");
                    }
                    int elevated,returned;
                    if(!GetTokenInformation(raw,20,out elevated,4,out returned)) throw new Win32Exception(Marshal.GetLastWin32Error());
                    if(elevated!=0) throw new InvalidOperationException("Explorer is elevated; automatic restart is not safe.");
                    // TOKEN_ASSIGN_PRIMARY | TOKEN_DUPLICATE | TOKEN_QUERY; SecurityImpersonation, TokenPrimary.
                    if(!DuplicateTokenEx(raw,0x000B,IntPtr.Zero,2,1,out token)) throw new Win32Exception(Marshal.GetLastWin32Error());
                } finally {CloseHandle(raw);}
            } catch {Dispose(); throw;}
        }
        public void Stop() {
            if(original.HasExited || NativeLocks.ShellPid()!=original.Id || original.StartTime.ToUniversalTime().ToFileTimeUtc()!=started)
                throw new InvalidOperationException("Explorer changed before restart. Retry the restore.");
            if(!TerminateProcess(processHandle,0)) throw new Win32Exception(Marshal.GetLastWin32Error());
            stopIssued=true;
            if(!original.WaitForExit(10000)) throw new InvalidOperationException("Explorer did not exit within 10 seconds.");
        }
        private bool ShellRunning() {
            int pid=NativeLocks.ShellPid();
            if(pid==0) return false;
            try {
                using(Process p=Process.GetProcessById(pid)) {
                    return !p.HasExited && p.SessionId==session && String.Equals(p.MainModule.FileName,explorerPath,StringComparison.OrdinalIgnoreCase);
                }
            } catch {return false;}
        }
        private bool WaitForShell(int milliseconds) {
            Stopwatch timer=Stopwatch.StartNew();
            do {if(ShellRunning()) return true; Thread.Sleep(200);} while(timer.ElapsedMilliseconds<milliseconds);
            return ShellRunning();
        }
        public void EnsureRunning() {
            if(!stopIssued) return;
            // Windows may already have restarted Explorer automatically.
            if(WaitForShell(3000)) return;
            StartupInfo startup=new StartupInfo();
            startup.cb=Marshal.SizeOf(typeof(StartupInfo));
            startup.desktop="winsta0\\default";
            ProcessInformation info;
            if(!CreateProcessWithTokenW(token,0,explorerPath,new StringBuilder("\""+explorerPath+"\""),0,IntPtr.Zero,Path.GetDirectoryName(explorerPath),ref startup,out info)) {
                int error=Marshal.GetLastWin32Error();
                if(WaitForShell(1000)) return;
                throw new Win32Exception(error);
            }
            CloseHandle(info.thread); CloseHandle(info.process);
            if(!WaitForShell(15000)) throw new InvalidOperationException("The desktop shell could not be confirmed after launch.");
        }
        public void Dispose() {
            if(token!=IntPtr.Zero) {CloseHandle(token); token=IntPtr.Zero;}
            if(original!=null) {original.Dispose(); original=null;}
            processHandle=IntPtr.Zero;
        }
    }
}
'@
}
function Get-LockedRestoreFiles([hashtable]$plan) {
    foreach ($k in ($plan.change + $plan.remove)) {
        $path = Join-Path $data $k
        try {Assert-FileWritable $path} catch {
            [pscustomobject]@{Path=$path; Reason=$_.Exception.Message}
        }
    }
}
function Test-SharingViolation($record) {
    $exception=$record.Exception
    while ($exception) {
        if (($exception.HResult -band 65535) -in @(32,33)) {return $true}
        $exception=$exception.InnerException
    }
    return $false
}
function Show-RebootAdvice {
    Write-Host 'No restore file or registry changes have been made.' -ForegroundColor Yellow
    Write-Host 'Save your work and close the listed applications normally, then retry.'
    Write-Host 'If the lock persists, enable Windhawk safe mode (Ctrl+Win+W, if available), restart Windows, and retry this restore before re-enabling mods.'
    Write-Host 'After a successful restore, exit safe mode or start Windhawk normally if needed.'
    Write-Host 'The script does not restart Windows automatically or schedule an unattended restore.'
}
function Test-SafeLockOwner($owner,[int]$shellPid,[int]$session) {
    return ($null -ne $owner -and $shellPid -gt 0 -and $session -gt 0 -and $owner.Pid -eq $shellPid -and $owner.Session -eq $session -and $owner.AppType -ne 1000 -and -not $owner.ServiceName)
}
function Get-SafeShellOwner([object[]]$locked) {
    Initialize-LockSupport
    $shellPid = [WhBackup.NativeLocks]::ShellPid()
    $session = [Diagnostics.Process]::GetCurrentProcess().SessionId
    $shellOwner = $null
    $unsafe = $false
    foreach ($lock in $locked) {
        Write-Host "Blocked file: $($lock.Path)" -ForegroundColor Yellow
        if ([IO.File]::GetAttributes($lock.Path) -band [IO.FileAttributes]::ReadOnly) {
            Write-Warning 'This file is read-only. No process will be closed to bypass file attributes.'
            $unsafe=$true; continue
        }
        try {$owners = @([WhBackup.NativeLocks]::Owners($lock.Path))} catch {
            Write-Warning "Lock owner detection failed: $($_.Exception.Message)"
            $unsafe=$true; continue
        }
        if (-not $owners.Count) {Write-Warning 'No lock owner could be identified.'; $unsafe=$true; continue}
        foreach ($owner in $owners) {
            Write-Host "  Owner: $($owner.AppName) (PID $($owner.Pid), session $($owner.Session))"
            # Do not stop services, other sessions, other Explorer instances, critical processes or arbitrary user apps.
            if (-not (Test-SafeLockOwner $owner $shellPid $session)) {
                $unsafe=$true; continue
            }
            if ($shellOwner -and $shellOwner.StartFileTime -ne $owner.StartFileTime) {$unsafe=$true; continue}
            $shellOwner=$owner
        }
    }
    if ($unsafe -or -not $shellOwner) {throw 'One or more blockers cannot be restarted safely.'}
    return $shellOwner
}
function Put-File([string]$source,[string]$target,[bool]$existing) {
    $tmp = Join-Path ([IO.Path]::GetDirectoryName($target)) ('.wh-restore-' + [guid]::NewGuid().ToString('N') + '.tmp')
    try {
        [IO.File]::Copy($source,$tmp,$false)
        if ($existing) { [IO.File]::Replace($tmp,$target,[System.Management.Automation.Language.NullString]::Value) }
        else { [IO.File]::Move($tmp,$target) }
    } finally {
        if ([IO.File]::Exists($tmp)) {try {Remove-Item -LiteralPath $tmp -Force} catch {Write-Warning "Temporary file retained: $tmp"}}
    }
}
function Get-RestorePlan([string]$incoming,[string]$old) {
    Assert-NoLinks $data $true
    $src = Join-Path $incoming 'ProgramData_Windhawk'
    $prev = Join-Path $old 'ProgramData_Windhawk'
    $current = Get-Inventory $data $false $true
    $saved = Get-Inventory $prev $false $true
    $wanted = Get-Inventory $src $false $true
    $currentDirs = Get-Directories $data $true
    $savedDirs = Get-Directories $prev $true
    $wantedDirs = Get-Directories $src $true
    if ($current.Count -ne $saved.Count -or $currentDirs.Count -ne $savedDirs.Count) {throw 'Windhawk data changed during safety backup. Try again.'}
    foreach ($k in $current.Keys) {if (-not $saved.ContainsKey($k) -or $current[$k] -ne $saved[$k]) {throw "Windhawk data changed during safety backup: $k"}}
    foreach ($k in $currentDirs.Keys) {if (-not $savedDirs.ContainsKey($k)) {throw "Windhawk directories changed during safety backup: $k"}}
    foreach ($k in $wanted.Keys) {if ($currentDirs.ContainsKey($k)) {throw "File/directory conflict: $k"}}
    foreach ($k in $wantedDirs.Keys) {if ($current.ContainsKey($k)) {throw "Directory/file conflict: $k"}}
    $add = @( $wanted.Keys | Where-Object {-not $current.ContainsKey($_)} | Sort-Object )
    $change = @( $wanted.Keys | Where-Object {$current.ContainsKey($_) -and $current[$_] -ne $wanted[$_]} | Sort-Object )
    $remove = @($current.Keys | Where-Object {-not $wanted.ContainsKey($_)} | Sort-Object)
    # Preserve the Engine ancestor because it contains unmanaged runtime data.
    $removeDirs = @($currentDirs.Keys | Where-Object {-not $wantedDirs.ContainsKey($_) -and $_ -notin @('Engine')} | Sort-Object -Property Length -Descending)
    $addDirs = @($wantedDirs.Keys | Where-Object {-not $currentDirs.ContainsKey($_)} | Sort-Object -Property Length)
    $regChanges = @()
    for ($i=0;$i -lt 2;$i++) {
        $before = Join-Path (Join-Path $old 'Reg') $regFiles[$i]
        $after = Join-Path (Join-Path $incoming 'Reg') $regFiles[$i]
        $hasBefore = Test-Path -LiteralPath $before -PathType Leaf
        $hasAfter = Test-Path -LiteralPath $after -PathType Leaf
        if ((Registry-Exists $i) -ne $hasBefore) {throw 'Registry changed during safety backup. Try again.'}
        if ($hasBefore -and $hasAfter -and (Get-FileHash -LiteralPath $before).Hash -eq (Get-FileHash -LiteralPath $after).Hash) {continue}
        if ($hasAfter -or $hasBefore) {$regChanges += $i}
    }
    Write-Host "Restore plan: $($add.Count) new, $($change.Count) changed, $($remove.Count) removed, $($wanted.Count-$add.Count-$change.Count) unchanged files."
    Write-Host "Directories: $($addDirs.Count) new, $($removeDirs.Count) removed. Registry roots to update: $($regChanges.Count)."
    return @{add=$add;change=$change;remove=$remove;addDirs=$addDirs;removeDirs=$removeDirs;regChanges=$regChanges;current=$current;wanted=$wanted}
}
function Apply-RestorePlan([string]$incoming,[hashtable]$plan,[System.Collections.Generic.List[object]]$journal) {
    $src = Join-Path $incoming 'ProgramData_Windhawk'
    foreach ($k in $plan.addDirs) {
        $path = Join-Path $data $k
        if (Test-Path -LiteralPath $path) {throw "Directory appeared during restore: $k"}
        [void][IO.Directory]::CreateDirectory($path)
        $journal.Add(@{kind='addDir';key=$k})
    }
    foreach ($k in ($plan.change + $plan.add)) {
        $path = Join-Path $data $k
        $existing = $plan.current.ContainsKey($k)
        if ($existing) {
            if ((Get-FileHash -LiteralPath $path).Hash -ne $plan.current[$k]) {throw "File changed during restore: $k"}
        } elseif (Test-Path -LiteralPath $path) {throw "File appeared during restore: $k"}
        Put-File (Join-Path $src $k) $path $existing
        $kind = if ($existing) {'change'} else {'add'}
        $journal.Add(@{kind=$kind;key=$k})
        if ((Get-FileHash -LiteralPath $path).Hash -ne $plan.wanted[$k]) {throw "Restored file verification failed: $k"}
    }
    foreach ($k in $plan.remove) {
        $path = Join-Path $data $k
        if ((Get-FileHash -LiteralPath $path).Hash -ne $plan.current[$k]) {throw "File changed during restore: $k"}
        [IO.File]::Delete($path)
        $journal.Add(@{kind='remove';key=$k})
    }
    foreach ($k in $plan.removeDirs) {
        [IO.Directory]::Delete((Join-Path $data $k),$false)
        $journal.Add(@{kind='removeDir';key=$k})
    }
    foreach ($i in $plan.regChanges) {
        $f = Join-Path (Join-Path $incoming 'Reg') $regFiles[$i]
        # Registry operations can partially succeed, so record before invoking them.
        $journal.Add(@{kind='reg';key=$i})
        if ((Registry-Exists $i)) {Invoke-Reg @('delete',$roots[$i],'/f')}
        if (Test-Path -LiteralPath $f) {Invoke-Reg @('import',$f)}
    }
}
function Undo-Restore([string]$old,[System.Collections.Generic.List[object]]$journal) {
    $prev = Join-Path $old 'ProgramData_Windhawk'
    $errors = New-Object 'System.Collections.Generic.List[string]'
    for ($j=$journal.Count-1;$j -ge 0;$j--) {
        $entry = $journal[$j]; $k = $entry.key
        try {
            if ($entry.kind -eq 'reg') {
                $i=[int]$k
                if (Registry-Exists $i) {Invoke-Reg @('delete',$roots[$i],'/f')}
                $f=Join-Path (Join-Path $old 'Reg') $regFiles[$i]
                if (Test-Path -LiteralPath $f) {Invoke-Reg @('import',$f)}
            } else {
                $path=Join-Path $data $k
                switch ($entry.kind) {
                    'change' {Put-File (Join-Path $prev $k) $path ([IO.File]::Exists($path))}
                    'remove' {Put-File (Join-Path $prev $k) $path $false}
                    'add' {[IO.File]::Delete($path)}
                    'addDir' {[IO.Directory]::Delete($path,$false)}
                    'removeDir' {[void][IO.Directory]::CreateDirectory($path)}
                }
            }
        } catch {$errors.Add("$($entry.kind) $($entry.key): $($_.Exception.Message)")}
    }
    if ($errors.Count) {throw ($errors -join '; ')}
}
function Run-Backup {
    Assert-Install
    $temp=New-Temp
    try {With-ServiceStopped {Snapshot $temp}; Save-Zip $temp (New-BackupName)} finally {Remove-Temp $temp}
}
function Run-Restore([string]$zip,[bool]$keepSafetyZip) {
    Assert-Install
    $incoming=New-Temp; $old=New-Temp
    $retainOld=$false
    try {
        Extract-Safe $zip $incoming
        With-ServiceStopped {
            try {Snapshot $old} catch {if (Test-SharingViolation $_) {Show-RebootAdvice}; throw}
            if ($keepSafetyZip) {Save-Zip $old (New-BackupName 'windhawk-backup-safety')}
            else {
                Write-Host 'Checking temporary rollback snapshot...'
                Assert-Snapshot $old
            }
            try {$plan = Get-RestorePlan $incoming $old} catch {if (Test-SharingViolation $_) {Show-RebootAdvice}; throw}
            Write-Host 'Checking changed and removed files for locks...'
            $locked = @(Get-LockedRestoreFiles $plan)
            $shell = $null
            try {
                if ($locked.Count) {
                    try {
                        $owner = Get-SafeShellOwner $locked
                        # Validate identity and obtain a restart token before asking to terminate anything.
                        $shell = New-Object WhBackup.ShellLease -ArgumentList @([int]$owner.Pid,[long]$owner.StartFileTime,[string]$env:WH_ORIGINAL_SID)
                        Write-Host 'Windows Explorer is locking the selected mod files.' -ForegroundColor Yellow
                        Write-Host 'The taskbar and File Explorer windows may close temporarily. Finish any active file transfers and save your work first.'
                        if (-not (Confirm 'Restart Windows Explorer automatically and continue?')) {throw 'Explorer restart declined. Restore canceled.'}
                        # Recheck all blockers after the user prompt. Fail closed if the lock owner changed.
                        $locked = @(Get-LockedRestoreFiles $plan)
                        if ($locked.Count) {
                            $again = Get-SafeShellOwner $locked
                            if ($again.Pid -ne $owner.Pid -or $again.StartFileTime -ne $owner.StartFileTime) {throw 'Lock owners changed. Retry the restore.'}
                            if ((Get-Service -Name $serviceName).Status -ne 'Stopped') {throw 'Windhawk service is no longer stopped.'}
                            Write-Host 'Releasing Windows Explorer file locks...'
                            $shell.Stop()
                            # Rebuild and verify the complete plan against the original snapshot.
                            $plan = Get-RestorePlan $incoming $old
                            $remaining = @(Get-LockedRestoreFiles $plan)
                            if ($remaining.Count) {
                                foreach ($item in $remaining) {Write-Warning "Still blocked: $($item.Path)"}
                                throw 'Files remain locked after the Explorer restart attempt.'
                            }
                        }
                    } catch {Show-RebootAdvice; throw}
                }
                if ((Get-Service -Name $serviceName).Status -ne 'Stopped') {throw 'Windhawk service is no longer stopped. No restore changes have been made.'}
                $journal = New-Object 'System.Collections.Generic.List[object]'
                try {Apply-RestorePlan $incoming $plan $journal} catch {
                    $original=$_
                    if ($journal.Count -eq 0) {throw "Restore failed before any recorded changes: $original"}
                    Write-Warning 'Restore failed. Rolling back changed items only.'
                    try {Undo-Restore $old $journal} catch {$retainOld=$true; throw "Restore and rollback failed. Recovery snapshot retained at: $old. Rollback error: $_; original error: $original"}
                    throw "Restore failed; recorded changes rolled back. $original"
                }
            } finally {
                if ($shell) {
                    try {$shell.EnsureRunning()} catch {
                        Write-Warning "Automatic Explorer restart could not be confirmed: $($_.Exception.Message)"
                        Write-Warning 'Press Ctrl+Shift+Esc, choose Run new task, enter explorer.exe without administrator privileges, or restart Windows after saving your work.'
                    } finally {$shell.Dispose()}
                }
            }
        }
        Write-Host 'Restore completed. Restart Windhawk or sign out if necessary.' -ForegroundColor Green
    } finally {Remove-Temp $incoming; if (-not $retainOld) {Remove-Temp $old} else {Write-Warning "Recovery snapshot retained: $old"}}
}
function Confirm([string]$message) {return (Read-Host "$message (Y/N)") -ieq 'Y'}
# Optional diagnostics: no Windhawk files, registry roots or shell processes are modified.
function Run-SelfTest {
    Write-Host 'Running Windhawk Backup & Restore lock diagnostics...' -ForegroundColor Cyan
    Initialize-LockSupport
    Write-Host '[PASS] Native Restart Manager and Explorer restart helpers compiled.' -ForegroundColor Green
    $selfSession=[Diagnostics.Process]::GetCurrentProcess().SessionId
    $desktopPid=[WhBackup.NativeLocks]::ShellPid()
    if ($desktopPid -le 0 -or $selfSession -eq 0) {throw 'An interactive Windows desktop is required for this self-test.'}
    $fake=[pscustomobject]@{Pid=$desktopPid;Session=$selfSession;AppType=4;ServiceName=''}
    if (-not (Test-SafeLockOwner $fake $desktopPid $selfSession)) {throw 'Valid Explorer policy test failed.'}
    $fake.Pid=$desktopPid+1
    if (Test-SafeLockOwner $fake $desktopPid $selfSession) {throw 'Other process rejection test failed.'}
    $fake.Pid=$desktopPid; $fake.Session=$selfSession+1
    if (Test-SafeLockOwner $fake $desktopPid $selfSession) {throw 'Other session rejection test failed.'}
    $fake.Session=$selfSession; $fake.AppType=1000
    if (Test-SafeLockOwner $fake $desktopPid $selfSession) {throw 'Critical process rejection test failed.'}
    $fake.AppType=4; $fake.ServiceName='ExampleService'
    if (Test-SafeLockOwner $fake $desktopPid $selfSession) {throw 'Service rejection test failed.'}
    Write-Host '[PASS] Explorer allowlist and other-process/session/service/critical-process rejection.' -ForegroundColor Green
    # Verify that the actual desktop shell identity and restart token can be obtained. Never call Stop().
    $desktop=Get-Process -Id $desktopPid
    try {
        $lease=New-Object WhBackup.ShellLease -ArgumentList @([int]$desktopPid,[long]($desktop.StartTime.ToUniversalTime().ToFileTimeUtc()),[string]$env:WH_ORIGINAL_SID)
        try {Write-Host '[PASS] Current Explorer identity and non-elevated restart token verified (Explorer was not closed).' -ForegroundColor Green}
        finally {$lease.Dispose()}
    } finally {$desktop.Dispose()}
    $temp=New-Temp
    $child=$null
    try {
        $data=$temp
        $file=Join-Path $temp 'diagnostic.dll'
        $ready=Join-Path $temp 'ready'
        $release=Join-Path $temp 'release'
        [IO.File]::WriteAllText($file,'Temporary diagnostic data')
        $originalHash=(Get-FileHash -LiteralPath $file).Hash
        $plan=@{change=@('diagnostic.dll');remove=@()}
        if (@(Get-LockedRestoreFiles $plan).Count -ne 0) {throw 'Unlocked file was incorrectly rejected.'}
        Write-Host '[PASS] Unlocked file check.' -ForegroundColor Green
        $childCode=@"
`$ErrorActionPreference='Stop'
`$handle=[IO.File]::Open('$($file.Replace("'","''"))',[IO.FileMode]::Open,[IO.FileAccess]::ReadWrite,[IO.FileShare]::None)
try {
    [IO.File]::WriteAllText('$($ready.Replace("'","''"))','ready')
    `$timer=[Diagnostics.Stopwatch]::StartNew()
    while (-not [IO.File]::Exists('$($release.Replace("'","''"))') -and `$timer.ElapsedMilliseconds -lt 45000) {Start-Sleep -Milliseconds 100}
} finally {`$handle.Dispose()}
"@
        $encoded=[Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($childCode))
        $child=Start-Process -FilePath (Join-Path $PSHOME 'powershell.exe') -ArgumentList @('-NoProfile','-NonInteractive','-EncodedCommand',$encoded) -WindowStyle Hidden -PassThru
        $timer=[Diagnostics.Stopwatch]::StartNew()
        while (-not [IO.File]::Exists($ready) -and -not $child.HasExited -and $timer.ElapsedMilliseconds -lt 10000) {Start-Sleep -Milliseconds 100}
        if (-not [IO.File]::Exists($ready) -or $child.HasExited) {throw 'The diagnostic lock process did not start.'}
        $locked=@(Get-LockedRestoreFiles $plan)
        if ($locked.Count -ne 1 -or $locked[0].Path -ne $file) {throw 'Locked file was not detected.'}
        Write-Host '[PASS] Exclusive file lock detected.' -ForegroundColor Green
        $owners=@([WhBackup.NativeLocks]::Owners($file))
        if ($child.Id -notin @($owners | ForEach-Object {$_.Pid})) {throw 'Restart Manager did not identify the diagnostic process.'}
        Write-Host '[PASS] Restart Manager identified the actual lock owner.' -ForegroundColor Green
        $rejected=$false
        try {$null=Get-SafeShellOwner $locked} catch {
            if ($_.Exception.Message -ne 'One or more blockers cannot be restarted safely.') {throw}
            $rejected=$true
        }
        if (-not $rejected -or $child.HasExited) {throw 'Non-Explorer process was not safely rejected.'}
        Write-Host '[PASS] Non-Explorer lock owner rejected without stopping it.' -ForegroundColor Green
        [IO.File]::WriteAllText($release,'release')
        if (-not $child.WaitForExit(10000) -or $child.ExitCode -ne 0) {throw 'The diagnostic process did not release its lock normally.'}
        if (@(Get-LockedRestoreFiles $plan).Count -ne 0 -or (Get-FileHash -LiteralPath $file).Hash -ne $originalHash) {throw 'Released file check or content preservation test failed.'}
        Write-Host '[PASS] Released file is writable and its contents are unchanged.' -ForegroundColor Green
    } finally {
        try {
            if ($child) {
                try {
                    if (-not $child.HasExited) {
                        [IO.File]::WriteAllText($release,'release')
                        if (-not $child.WaitForExit(5000)) {$child.Kill(); [void]$child.WaitForExit(5000)}
                    }
                } finally {$child.Dispose()}
            }
        } finally {Remove-Temp $temp}
    }
    Write-Host 'Self-test passed. No Windhawk data, registry configuration or desktop shell was changed.' -ForegroundColor Green
    Write-Host 'A real Explorer-locked restore is still required to validate termination, restart and rollback.'
}
# Presentation only: section headings do not alter the operation flow.
function Show-Section([string]$heading) {
    $line = '=' * 56
    $left = [int][Math]::Floor([Math]::Max(0, (56 - $heading.Length) / 2))
    Write-Host $line
    Write-Host ((' ' * $left) + $heading)
    Write-Host $line
    Write-Host ''
}
if ($env:WH_TEST_ONLY -eq '1') {Run-SelfTest; exit 0}
while ($true) {
    Clear-Host
    Write-Host 'WINDHAWK BACKUP AND RESTORE v1.4.1' -ForegroundColor Cyan
    Write-Host 'https://github.com/SefaMeert/windhawk-backup-restore'
    Write-Host ''
    Show-Section 'WINDHAWK BACKUP AND RESTORE'
    Write-Host "   [1] Backup Windhawk Configuration`n`n   [2] Restore Windhawk Configuration`n`n   [3] Exit`n"
    Write-Host ('=' * 56)
    Write-Host ''
    $choice=Read-Host 'Please enter your choice (1-3)'
    try {
        switch ($choice) {
            '1' {
                Clear-Host
                Show-Section 'WINDHAWK BACKUP'
                if (Confirm "Create a backup in ${base}?") {
                    Clear-Host
                    Show-Section 'BACKUP IN PROGRESS'
                    Run-Backup
                    Write-Host ''
                    Show-Section 'BACKUP COMPLETED'
                } else {continue}
            }
            '2' {
                Clear-Host
                Show-Section 'SELECT A BACKUP TO RESTORE'
                $files=@(Get-ChildItem -LiteralPath $base -File | Where-Object {$_.Name -like 'windhawk-backup-*.zip' -or $_.Name -ieq 'windhawk-config-archive.zip'} | Sort-Object LastWriteTime -Descending)
                if (-not $files.Count) {throw 'No backups found.'}
                for ($i=0;$i -lt $files.Count;$i++) {
                    $suffix = if ($i -eq 0) {' (Latest)'} else {''}
                    Write-Host "[$($i+1)] $($files[$i].Name)$suffix"
                }
                $n=0; $answer=Read-Host 'Select backup (0 to cancel)'
                if (-not [int]::TryParse($answer,[ref]$n) -or $n -lt 0 -or $n -gt $files.Count) {throw 'Invalid selection.'}
                if ($n -eq 0) {continue}
                Clear-Host
                Show-Section 'WINDHAWK RESTORE'
                Write-Host 'WARNING: Current managed mod files and registry settings absent from the selected backup will be removed.' -ForegroundColor Yellow
                Write-Host "Restore $($files[$n-1].Name)?"
                Write-Host '[Y] Create a safety ZIP and restore (recommended)'
                Write-Host '[N] Restore without a permanent safety ZIP (temporary rollback snapshot retained on rollback failure)'
                Write-Host '[0] Cancel'
                $safety=Read-Host 'Choose Y, N or 0'
                if ($safety -eq '0') {continue}
                if ($safety -notin @('Y','N')) {throw 'Invalid safety backup choice.'}
                Clear-Host
                Show-Section 'RESTORE IN PROGRESS'
                Run-Restore $files[$n-1].FullName ($safety -ieq 'Y')
                Write-Host ''
                Show-Section 'RESTORE COMPLETED'
            }
            '3' {exit 0}
            default {continue}
        }
    } catch {
        Write-Host ''
        Show-Section 'ERROR'
        Write-Host "ERROR: $($_.Exception.Message)" -ForegroundColor Red
    }
    Write-Host ''
    Write-Host ('=' * 56)
    [void](Read-Host 'Press Enter to return to menu')
}
