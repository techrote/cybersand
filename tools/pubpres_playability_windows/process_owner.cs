// PowerShell5.1/.NET Framework compatible; no installed compiler or Python.
// The launcher replaces the namespace token with this file's SHA-256 before
// Add-Type, so an older in-process helper cannot silently satisfy a new run.
// Documented Windows10+ APIs: CreateProcessW/STARTUPINFOEX,
// UpdateProcThreadAttribute(JOB_LIST, HANDLE_LIST), ResumeThread,
// QueryInformationJobObject, TerminateJobObject and KILL_ON_JOB_CLOSE.
// https://learn.microsoft.com/windows/win32/api/processthreadsapi/nf-processthreadsapi-updateprocthreadattribute
// https://learn.microsoft.com/windows/win32/procthread/job-objects
using System;
using System.Collections;
using System.Collections.Generic;
using System.ComponentModel;
using System.Diagnostics;
using System.Globalization;
using System.IO;
using System.Runtime.InteropServices;
using System.Text;
using System.Threading;
using Microsoft.Win32.SafeHandles;

namespace PUBPRES_PROCESS_OWNER
{
    public sealed class KernelHandle : SafeHandleZeroOrMinusOneIsInvalid
    {
        public KernelHandle() : base(true) { }
        public KernelHandle(IntPtr value) : base(true) { SetHandle(value); }
        protected override bool ReleaseHandle() { return Native.CloseHandle(handle); }
    }

    internal static class Native
    {
        [StructLayout(LayoutKind.Sequential)] internal struct Security
        { public int Length; public IntPtr Descriptor; [MarshalAs(UnmanagedType.Bool)] public bool Inherit; }
        [StructLayout(LayoutKind.Sequential)] internal struct Startup
        {
            public int Size; public IntPtr Reserved, Desktop, Title;
            public uint X, Y, XSize, YSize, XCount, YCount, Fill, Flags;
            public ushort ShowWindow, ReservedSize; public IntPtr ReservedBytes, Input, Output, Error;
        }
        [StructLayout(LayoutKind.Sequential)] internal struct StartupEx
        { public Startup Startup; public IntPtr Attributes; }
        [StructLayout(LayoutKind.Sequential)] internal struct ProcessInfo
        { public IntPtr Process, Thread; public uint ProcessId, ThreadId; }
        [StructLayout(LayoutKind.Sequential)] internal struct BasicLimit
        {
            public long ProcessTime, JobTime; public uint Flags; public UIntPtr MinWorkingSet, MaxWorkingSet;
            public uint ActiveLimit; public UIntPtr Affinity; public uint Priority, Scheduling;
        }
        [StructLayout(LayoutKind.Sequential)] internal struct IoCounters
        { public ulong ReadOps, WriteOps, OtherOps, ReadBytes, WriteBytes, OtherBytes; }
        [StructLayout(LayoutKind.Sequential)] internal struct ExtendedLimit
        { public BasicLimit Basic; public IoCounters Io; public UIntPtr ProcessMemory, JobMemory, PeakProcess, PeakJob; }
        [StructLayout(LayoutKind.Sequential)] internal struct Accounting
        { public long User, Kernel, PeriodUser, PeriodKernel; public uint Faults, Total, Active, Terminated; }
        internal delegate bool ConsoleHandler(uint signal);
        [DllImport("kernel32.dll", SetLastError=true)] [return:MarshalAs(UnmanagedType.Bool)]
        internal static extern bool CloseHandle(IntPtr handle);
        [DllImport("kernel32.dll", CharSet=CharSet.Unicode, SetLastError=true)]
        internal static extern IntPtr CreateJobObjectW(IntPtr security, string name);
        [DllImport("kernel32.dll", SetLastError=true)] [return:MarshalAs(UnmanagedType.Bool)]
        internal static extern bool SetInformationJobObject(KernelHandle job, int kind, ref ExtendedLimit value, uint size);
        [DllImport("kernel32.dll", SetLastError=true)] [return:MarshalAs(UnmanagedType.Bool)]
        internal static extern bool QueryInformationJobObject(KernelHandle job, int kind, out Accounting value, uint size, IntPtr returned);
        [DllImport("kernel32.dll", SetLastError=true)] [return:MarshalAs(UnmanagedType.Bool)]
        internal static extern bool TerminateJobObject(KernelHandle job, uint code);
        [DllImport("kernel32.dll", SetLastError=true)] [return:MarshalAs(UnmanagedType.Bool)]
        internal static extern bool IsProcessInJob(KernelHandle process, KernelHandle job, [MarshalAs(UnmanagedType.Bool)] out bool member);
        [DllImport("kernel32.dll", CharSet=CharSet.Unicode, SetLastError=true)]
        internal static extern IntPtr CreateFileW(string path, uint access, uint share, ref Security security, uint disposition, uint flags, IntPtr template);
        [DllImport("kernel32.dll", SetLastError=true)] [return:MarshalAs(UnmanagedType.Bool)]
        internal static extern bool InitializeProcThreadAttributeList(IntPtr list, int count, uint flags, ref IntPtr size);
        [DllImport("kernel32.dll", SetLastError=true)] [return:MarshalAs(UnmanagedType.Bool)]
        internal static extern bool UpdateProcThreadAttribute(IntPtr list, uint flags, UIntPtr key, IntPtr value, IntPtr size, IntPtr old, IntPtr returned);
        [DllImport("kernel32.dll")] internal static extern void DeleteProcThreadAttributeList(IntPtr list);
        [DllImport("kernel32.dll", CharSet=CharSet.Unicode, SetLastError=true)] [return:MarshalAs(UnmanagedType.Bool)]
        internal static extern bool CreateProcessW(string application, StringBuilder command, IntPtr processSecurity,
            IntPtr threadSecurity, [MarshalAs(UnmanagedType.Bool)] bool inherit, uint flags, IntPtr environment,
            string directory, ref StartupEx startup, out ProcessInfo process);
        [DllImport("kernel32.dll", SetLastError=true)] internal static extern uint ResumeThread(KernelHandle thread);
        [DllImport("kernel32.dll", SetLastError=true)] internal static extern uint WaitForSingleObject(KernelHandle process, uint milliseconds);
        [DllImport("kernel32.dll", SetLastError=true)] [return:MarshalAs(UnmanagedType.Bool)]
        internal static extern bool GetExitCodeProcess(KernelHandle process, out uint code);
        [DllImport("kernel32.dll", SetLastError=true)] [return:MarshalAs(UnmanagedType.Bool)]
        internal static extern bool SetConsoleCtrlHandler(ConsoleHandler handler, [MarshalAs(UnmanagedType.Bool)] bool add);
    }

    public sealed class OwnedProcess : IDisposable
    {
        private readonly object sync = new object();
        private KernelHandle job, process;
        private Native.ConsoleHandler consoleHandler;
        private bool consoleHookActive;
        private int cancellation;
        private bool closed;
        private string receipt;
        public Process MetricsProcess { get; private set; }
        public int Id { get; private set; }
        public int? ExitCode { get; private set; }
        public bool AssignedBeforeResume { get; private set; }
        public bool InitialThreadResumed { get; private set; }
        public bool ConsoleHookInstalled { get; private set; }
        public bool CancellationRequested { get { return Interlocked.CompareExchange(ref cancellation,0,0) != 0; } }
        public bool ParentExitedBeforeCleanup { get; private set; }
        public bool HadSurvivors { get; private set; }
        public bool ZeroExitWithDescendants { get; private set; }
        public uint? ActiveBeforeCleanup { get; private set; }
        public uint? ActiveAfterCleanup { get; private set; }
        public bool CleanupEstablished { get; private set; }
        public string Failure { get; private set; }

        private static void Require(bool success, string operation)
        {
            if (!success)
            {
                int error=Marshal.GetLastWin32Error();
                throw new Win32Exception(error,operation+" [Win32 "+error.ToString(CultureInfo.InvariantCulture)+"]: "+new Win32Exception(error).Message);
            }
        }

        private static KernelHandle OpenInherited(string path, bool input)
        {
            Native.Security security = new Native.Security();
            security.Length=Marshal.SizeOf(typeof(Native.Security)); security.Inherit=true;
            KernelHandle handle=new KernelHandle(Native.CreateFileW(path,input ? 0x80000000u : 0x40000000u,3,
                ref security,input ? 3u : 1u,0x80,IntPtr.Zero));
            if (handle.IsInvalid) { int error=Marshal.GetLastWin32Error(); handle.Dispose(); throw new Win32Exception(error,"Open child standard stream"); }
            return handle;
        }

        public static OwnedProcess Start(ProcessStartInfo info, string stdout, string stderr, string receiptPath)
        {
            OwnedProcess owner=new OwnedProcess(); owner.receipt=receiptPath; owner.Failure="";
            try { owner.Launch(info,stdout,stderr); return owner; }
            catch (Exception error)
            {
                owner.Failure=error.GetType().Name+": "+error.Message;
                try { owner.Close(); } catch (Exception cleanup) { owner.Failure += "; cleanup: "+cleanup.Message; owner.WriteReceipt(); }
                throw;
            }
        }

        private void Launch(ProcessStartInfo info, string stdout, string stderr)
        {
            if (!Path.IsPathRooted(info.FileName) || info.FileName.IndexOf('"') >= 0)
                throw new ArgumentException("The owned executable must be an absolute unquoted path");
            job=new KernelHandle(Native.CreateJobObjectW(IntPtr.Zero,null));
            Require(!job.IsInvalid,"CreateJobObjectW");
            Native.ExtendedLimit limit=new Native.ExtendedLimit();
            limit.Basic.Flags=0x2000; // KILL_ON_JOB_CLOSE; neither breakaway flag.
            Require(Native.SetInformationJobObject(job,9,ref limit,(uint)Marshal.SizeOf(limit)),"SetInformationJobObject");
            consoleHandler=delegate(uint signal) {
                if (signal != 0 && signal != 1 && signal != 2) return false;
                try { RequestCancellation(); } catch { } // Main finally retains/refuses uncertain cleanup.
                return true;
            };
            ConsoleHookInstalled=Native.SetConsoleCtrlHandler(consoleHandler,true);
            consoleHookActive=ConsoleHookInstalled;
            IntPtr attributes=IntPtr.Zero, allowed=IntPtr.Zero, jobs=IntPtr.Zero, environment=IntPtr.Zero;
            bool initialized=false;
            KernelHandle initialThread=null;
            using (KernelHandle input=OpenInherited("NUL",true))
            using (KernelHandle output=OpenInherited(stdout,false))
            using (KernelHandle error=OpenInherited(stderr,false))
            try
            {
                IntPtr bytes=IntPtr.Zero;
                Native.InitializeProcThreadAttributeList(IntPtr.Zero,2,0,ref bytes);
                if (bytes == IntPtr.Zero) throw new Win32Exception(Marshal.GetLastWin32Error(),"Size process attribute list");
                attributes=Marshal.AllocHGlobal(bytes);
                Require(Native.InitializeProcThreadAttributeList(attributes,2,0,ref bytes),"Initialize process attributes"); initialized=true;
                allowed=Marshal.AllocHGlobal(IntPtr.Size*3);
                Marshal.WriteIntPtr(allowed,0,input.DangerousGetHandle());
                Marshal.WriteIntPtr(allowed,IntPtr.Size,output.DangerousGetHandle());
                Marshal.WriteIntPtr(allowed,IntPtr.Size*2,error.DangerousGetHandle());
                Require(Native.UpdateProcThreadAttribute(attributes,0,new UIntPtr(0x20002),allowed,new IntPtr(IntPtr.Size*3),IntPtr.Zero,IntPtr.Zero),"Restrict inherited standard handles");
                jobs=Marshal.AllocHGlobal(IntPtr.Size); Marshal.WriteIntPtr(jobs,job.DangerousGetHandle());
                Require(Native.UpdateProcThreadAttribute(attributes,0,new UIntPtr(0x2000d),jobs,new IntPtr(IntPtr.Size),IntPtr.Zero,IntPtr.Zero),"Assign creation-time Job list");
                SortedDictionary<string,string> values=new SortedDictionary<string,string>(StringComparer.OrdinalIgnoreCase);
                foreach (DictionaryEntry entry in info.EnvironmentVariables)
                {
                    string key=(string)entry.Key, value=(string)entry.Value;
                    if (key.IndexOf('\0') >= 0 || (value != null && value.IndexOf('\0') >= 0)) throw new ArgumentException("NUL in process environment");
                    values[key]=value ?? "";
                }
                StringBuilder block=new StringBuilder();
                foreach (KeyValuePair<string,string> entry in values) block.Append(entry.Key).Append('=').Append(entry.Value).Append('\0');
                block.Append('\0'); environment=Marshal.StringToHGlobalUni(block.ToString());
                Native.StartupEx startup=new Native.StartupEx();
                startup.Startup.Size=Marshal.SizeOf(typeof(Native.StartupEx)); startup.Startup.Flags=0x100;
                startup.Startup.Input=input.DangerousGetHandle(); startup.Startup.Output=output.DangerousGetHandle(); startup.Startup.Error=error.DangerousGetHandle();
                startup.Attributes=attributes;
                Native.ProcessInfo created;
                StringBuilder command=new StringBuilder("\""+info.FileName+"\" "+info.Arguments);
                // Creation-time JOB_LIST closes the suspended-but-unassigned
                // interval too. Failure is terminal; never retry without it.
                Require(Native.CreateProcessW(info.FileName,command,IntPtr.Zero,IntPtr.Zero,true,
                    0x4u|0x400u|0x80000u|0x08000000u,environment,info.WorkingDirectory,ref startup,out created),"CreateProcessW in owned suspended Job");
                process=new KernelHandle(created.Process); initialThread=new KernelHandle(created.Thread); Id=checked((int)created.ProcessId);
                bool member;
                Require(Native.IsProcessInJob(process,job,out member),"Verify pre-execution Job membership");
                if (!member) throw new InvalidOperationException("Suspended child is not in the required Job");
                AssignedBeforeResume=true;
                MetricsProcess=Process.GetProcessById(Id);
                if (CancellationRequested) throw new OperationCanceledException("Cancelled before resuming the owned child");
                WriteReceipt(); // Evidence destination must work before child execution.
                uint previousSuspendCount=Native.ResumeThread(initialThread);
                Require(previousSuspendCount != 0xffffffff,"Resume owned initial thread");
                if (previousSuspendCount != 1) throw new InvalidOperationException("Owned initial thread did not have exactly one suspension");
                InitialThreadResumed=true;
            }
            finally
            {
                if (initialThread != null) initialThread.Dispose();
                if (initialized) Native.DeleteProcThreadAttributeList(attributes);
                if (attributes != IntPtr.Zero) Marshal.FreeHGlobal(attributes);
                if (allowed != IntPtr.Zero) Marshal.FreeHGlobal(allowed);
                if (jobs != IntPtr.Zero) Marshal.FreeHGlobal(jobs);
                if (environment != IntPtr.Zero) Marshal.FreeHGlobal(environment);
            }
        }

        public bool WaitForExit(int milliseconds)
        {
            if (ExitCode.HasValue) return true;
            if (process == null || process.IsClosed) return false;
            uint result=Native.WaitForSingleObject(process,checked((uint)milliseconds));
            if (result == 0x102) return false;
            Require(result == 0,"WaitForSingleObject child");
            uint code; Require(Native.GetExitCodeProcess(process,out code),"GetExitCodeProcess");
            ExitCode=unchecked((int)code); return true;
        }

        private uint Active()
        {
            Native.Accounting value;
            Require(Native.QueryInformationJobObject(job,1,out value,(uint)Marshal.SizeOf(typeof(Native.Accounting)),IntPtr.Zero),"Query active owned processes");
            return value.Active;
        }

        public void RequestCancellation()
        {
            lock (sync)
            {
                if (closed) return;
                Interlocked.Exchange(ref cancellation,1);
                if (!closed && job != null && !job.IsInvalid && !job.IsClosed)
                    Require(Native.TerminateJobObject(job,125),"Cancel complete owned Job");
                WriteReceipt();
            }
        }

        private void ReleaseParentHandles()
        {
            if (MetricsProcess != null) { MetricsProcess.Dispose(); MetricsProcess=null; }
            if (process != null) { process.Dispose(); process=null; }
        }

        public void Close()
        {
            lock (sync)
            {
                if (closed) { if (!CleanupEstablished) throw new InvalidOperationException("Owned Job cleanup was not established: "+Failure); return; }
                try
                {
                    ParentExitedBeforeCleanup=WaitForExit(0);
                    if (ParentExitedBeforeCleanup) ReleaseParentHandles();
                    if (job != null && !job.IsInvalid && !job.IsClosed)
                    {
                        ActiveBeforeCleanup=Active(); HadSurvivors=ActiveBeforeCleanup.Value != 0;
                        ZeroExitWithDescendants=ParentExitedBeforeCleanup && ExitCode == 0 && HadSurvivors;
                        // Unconditional even when the immediate parent exited.
                        Require(Native.TerminateJobObject(job,125),"Terminate complete owned Job");
                        if (process != null && !WaitForExit(10000)) throw new TimeoutException("Owned parent did not exit after Job termination");
                        ReleaseParentHandles();
                        Stopwatch deadline=Stopwatch.StartNew();
                        do
                        {
                            ActiveAfterCleanup=Active();
                            if (ActiveAfterCleanup == 0) break;
                            if (deadline.ElapsedMilliseconds >= 30000) throw new TimeoutException("Owned descendants remained after Job termination");
                            Thread.Sleep(20);
                        } while (true);
                    }
                    else ActiveAfterCleanup=0;
                    CleanupEstablished=true;
                }
                catch (Exception error) { Failure += (Failure.Length == 0 ? "" : "; ")+error.GetType().Name+": "+error.Message; throw; }
                finally
                {
                    closed=true;
                    if (consoleHookActive) { Native.SetConsoleCtrlHandler(consoleHandler,false); consoleHookActive=false; }
                    // SafeHandle plus non-inherited KILL_ON_CLOSE is the final
                    // backstop if querying/waiting failed or the owner is killed.
                    if (job != null) { job.Dispose(); job=null; }
                    ReleaseParentHandles();
                    WriteReceipt();
                }
            }
        }

        private static string Json(string text)
        {
            StringBuilder result=new StringBuilder("\"");
            foreach (char value in text ?? "")
            {
                if (value == '\\' || value == '"') result.Append('\\').Append(value);
                else if (value < 32) result.Append("\\u").Append(((int)value).ToString("x4",CultureInfo.InvariantCulture));
                else result.Append(value);
            }
            return result.Append('"').ToString();
        }
        private static string Number(object value) { return value == null ? "null" : Convert.ToString(value,CultureInfo.InvariantCulture); }
        private static string Bool(bool value) { return value ? "true" : "false"; }
        private void WriteReceipt()
        {
            lock (sync)
            {
            if (String.IsNullOrEmpty(receipt)) return;
            string json="{\n\"schema\":\"pubpres-windows-process-owner-v1\",\n"+
                "\"process_id\":"+(Id == 0 ? "null" : Number(Id))+",\n\"root_exit_code\":"+Number(ExitCode)+",\n"+
                "\"creation_time_job_list\":true,\n\"standard_handle_allowlist\":true,\n\"kill_on_close\":true,\n\"breakaway_allowed\":false,\n"+
                "\"assigned_before_resume\":"+Bool(AssignedBeforeResume)+",\n\"initial_thread_resumed\":"+Bool(InitialThreadResumed)+",\n\"console_hook_installed\":"+Bool(ConsoleHookInstalled)+",\n"+
                "\"cancellation_requested\":"+Bool(CancellationRequested)+",\n\"parent_exited_before_cleanup\":"+Bool(ParentExitedBeforeCleanup)+",\n"+
                "\"active_before_cleanup\":"+Number(ActiveBeforeCleanup)+",\n\"active_after_cleanup\":"+Number(ActiveAfterCleanup)+",\n"+
                "\"had_survivors\":"+Bool(HadSurvivors)+",\n\"zero_exit_with_descendants\":"+Bool(ZeroExitWithDescendants)+",\n"+
                "\"cleanup_established\":"+Bool(CleanupEstablished)+",\n\"failure\":"+Json(Failure)+"\n}\n";
            File.WriteAllText(receipt,json,new UTF8Encoding(false));
            }
        }
        public void Dispose() { Close(); }
    }
}
