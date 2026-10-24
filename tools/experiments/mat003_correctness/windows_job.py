"""Windows job lifetime guard. No API calls at import time."""
import ctypes
from ctypes import wintypes

class WindowsJob:
    def __init__(self,process_handle,commit_limit):
        k=ctypes.WinDLL('kernel32',use_last_error=True)
        class Basic(ctypes.Structure):
            _fields_=[('process_time',ctypes.c_longlong),('job_time',ctypes.c_longlong),('flags',wintypes.DWORD),('minimum_ws',ctypes.c_size_t),('maximum_ws',ctypes.c_size_t),('active_limit',wintypes.DWORD),('affinity',ctypes.c_size_t),('priority',wintypes.DWORD),('scheduling',wintypes.DWORD)]
        class IO(ctypes.Structure):
            _fields_=[(name,ctypes.c_ulonglong) for name in ('read_ops','write_ops','other_ops','read_bytes','write_bytes','other_bytes')]
        class Limits(ctypes.Structure):
            _fields_=[('basic',Basic),('io',IO),('process_memory',ctypes.c_size_t),('job_memory',ctypes.c_size_t),('peak_process',ctypes.c_size_t),('peak_job',ctypes.c_size_t)]
        k.CreateJobObjectW.argtypes=[ctypes.c_void_p,wintypes.LPCWSTR];k.CreateJobObjectW.restype=wintypes.HANDLE
        k.SetInformationJobObject.argtypes=[wintypes.HANDLE,ctypes.c_int,ctypes.c_void_p,wintypes.DWORD];k.SetInformationJobObject.restype=wintypes.BOOL
        k.AssignProcessToJobObject.argtypes=[wintypes.HANDLE,wintypes.HANDLE];k.AssignProcessToJobObject.restype=wintypes.BOOL
        k.CloseHandle.argtypes=[wintypes.HANDLE];k.CloseHandle.restype=wintypes.BOOL
        self.kernel=k;self.handle=k.CreateJobObjectW(None,None)
        if not self.handle:raise OSError(ctypes.get_last_error(),'CreateJobObjectW')
        limits=Limits();limits.basic.flags=0x2000|0x200;limits.job_memory=commit_limit
        if not k.SetInformationJobObject(self.handle,9,ctypes.byref(limits),ctypes.sizeof(limits)) or not k.AssignProcessToJobObject(self.handle,wintypes.HANDLE(process_handle)):
            error=ctypes.get_last_error();self.close();raise OSError(error,'job memory/lifetime binding')
        n=ctypes.WinDLL('ntdll');n.NtResumeProcess.argtypes=[wintypes.HANDLE];n.NtResumeProcess.restype=ctypes.c_long
        if n.NtResumeProcess(wintypes.HANDLE(process_handle))<0:self.close();raise OSError('NtResumeProcess')
    def close(self):
        if self.handle:self.kernel.CloseHandle(self.handle);self.handle=None
