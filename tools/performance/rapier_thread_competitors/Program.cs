using Microsoft.Diagnostics.Tracing;
using Microsoft.Diagnostics.Tracing.Etlx;
using Microsoft.Diagnostics.Tracing.Parsers.Kernel;
using Microsoft.Diagnostics.Symbols;
using System.Text.Json;
using System.Security.Cryptography;
record Window(int Index,long Start,long End,long Freq);
record Run(long Start,int Tid,int Pid,string Name,int Priority);
record Slice(int Window,long Start,long End,int Cpu,int Tid,int Pid,string Name,int Priority,double Usec);
internal static class Program {
 static readonly JsonSerializerOptions Json=new(){WriteIndented=true,PropertyNamingPolicy=JsonNamingPolicy.SnakeCaseLower};
 static void Write(string p,object v)=>File.WriteAllText(p,JsonSerializer.Serialize(v,Json)+"\n");
 static string Hash(string p){using var f=File.OpenRead(p);return Convert.ToHexString(SHA256.HashData(f)).ToLowerInvariant();}
 public static int Main(string[] args){
  if(args.Length!=3){Console.Error.WriteLine("Usage: RapierThreadCompetitors ETLX raw.json output-dir");return 2;}
  string etlx=Path.GetFullPath(args[0]),raw=Path.GetFullPath(args[1]),output=Path.GetFullPath(args[2]);Directory.CreateDirectory(output);
  try {
   using var document=JsonDocument.Parse(File.ReadAllBytes(raw));var windows=new List<Window>();int i=0;
   foreach(var row in document.RootElement.GetProperty("physics_rows").EnumerateArray()){
    if(row.GetProperty("bridge_step_usec").GetInt64()<=40000)continue;
    var p=row.GetProperty("cpu_probe");var b=p.GetProperty("cpu_before").EnumerateArray().Select(x=>x.GetInt64()).ToArray();var e=p.GetProperty("cpu_after").EnumerateArray().Select(x=>x.GetInt64()).ToArray();
    windows.Add(new(++i,b[3],e[2],b[4]));
   }
   using var log=new TraceLog(etlx);var active=new Dictionary<int,Run>();var slices=new List<Slice>();long switches=0,samples=0,eligibleSamples=0,interruptSamples=0,eligibleInterruptSamples=0;const int sampleRowLimit=20000;bool rowsTruncated=false;var priorities=new List<object>();
   void Close(int cpu,long end){if(!active.TryGetValue(cpu,out var run))return;foreach(var w in windows){long a=Math.Max(w.Start,run.Start),b=Math.Min(w.End,end);if(b<=a)continue;slices.Add(new(w.Index,a,b,cpu,run.Tid,run.Pid,run.Name,run.Priority,(b-a)*1e6/w.Freq));}}
   foreach(var e in log.Events){
    if(e is CSwitchTraceData c){switches++;Close(c.ProcessorNumber,c.TimeStampQPC);active[c.ProcessorNumber]=new(c.TimeStampQPC,c.NewThreadID,c.NewProcessID,c.NewProcessName,c.NewThreadPriority);if(windows.Any(w=>w.Start<=c.TimeStampQPC&&c.TimeStampQPC<=w.End)&&priorities.Count<30000)priorities.Add(new{qpc=c.TimeStampQPC,cpu=c.ProcessorNumber,old_tid=c.OldThreadID,new_tid=c.NewThreadID,old_pid=c.OldProcessID,new_pid=c.NewProcessID,old_name=c.OldProcessName,new_name=c.NewProcessName,old_priority=c.OldThreadPriority,new_priority=c.NewThreadPriority,old_state=c.OldThreadState.ToString(),reason=c.OldThreadWaitReason.ToString()});}
   }
   var totals=slices.GroupBy(x=>new{x.Pid,x.Tid,x.Name,x.Priority}).Select(g=>new{g.Key.Pid,g.Key.Tid,g.Key.Name,g.Key.Priority,usec=g.Sum(x=>x.Usec),segments=g.Count()}).OrderByDescending(x=>x.usec).ToList();
   Write(Path.Combine(output,"cpu-occupancy.json"),new{schema="inv154-worker-competitor-occupancy-v1",etlx,etlx_sha256=Hash(etlx),raw,raw_sha256=Hash(raw),events_lost=log.EventsLost,trace_truncated=log.Truncated,windows,switches,processor_count=active.Count,total_cpu_residency_usec=slices.Sum(x=>x.Usec),totals,per_cpu=slices.GroupBy(x=>x.Cpu).Select(g=>new{cpu=g.Key,usec=g.Sum(x=>x.Usec)}),slices,priority_switches=priorities,limitations=new[]{"Scheduler residency includes any intervening interrupts/DPC/virtual-host descheduling; not a direct CPU-instruction-time measure.","Overlapping CPU slices across logical processors are summed as CPU-us, not wall-us."}});
   var targetTids=totals.Take(16).Select(x=>x.Tid).ToHashSet();var sampleRows=new List<object>();
   using var writer=File.CreateText(Path.Combine(output,"symbols.log"));string? symbolPath=Environment.GetEnvironmentVariable("CYBERSAND_ETW_SYMBOL_PATH");using var symbols=symbolPath==null?null:new SymbolReader(writer,symbolPath);var attempted=new HashSet<string>();var errors=new List<object>();
   foreach(var e in log.Events){if(e is not SampledProfileTraceData p||!windows.Any(w=>w.Start<=e.TimeStampQPC&&e.TimeStampQPC<=w.End))continue;samples++;bool interrupt=p.ExecutingDPC||p.ExecutingISR;if(interrupt)interruptSamples++;if(!targetTids.Contains(e.ThreadID))continue;eligibleSamples++;if(interrupt)eligibleInterruptSamples++;if(sampleRows.Count>=sampleRowLimit){rowsTruncated=true;continue;}var frames=new List<object>();int depth=0;for(var s=e.CallStack();s!=null&&depth++<128;s=s.Caller){var a=s.CodeAddress;var m=a.ModuleFile;if(symbols!=null&&m!=null&&!m.FilePath.Contains("godot_v4.7",StringComparison.OrdinalIgnoreCase)&&attempted.Add(m.FilePath))try{log.CodeAddresses.LookupSymbolsForModule(symbols,m);}catch(Exception ex){errors.Add(new{module=m.FilePath,error=ex.Message});}frames.Add(new{address=$"0x{a.Address:x}",module=a.ModuleName,module_path=a.ModuleFilePath,function=a.FullMethodName,resolved=a.Method!=null});}sampleRows.Add(new{qpc=e.TimeStampQPC,tid=e.ThreadID,pid=e.ProcessID,process=e.ProcessName,cpu=e.ProcessorNumber,ip=$"0x{p.InstructionPointer:x}",dpc=p.ExecutingDPC,isr=p.ExecutingISR,frames});}
   Write(Path.Combine(output,"competitor-samples.json"),new{schema="inv154-worker-competitor-samples-v2",etlx_sha256=Hash(etlx),events_lost=log.EventsLost,samples_in_windows=samples,interrupt_samples_in_windows=interruptSamples,noninterrupt_samples_in_windows=samples-interruptSamples,eligible_samples_in_windows=eligibleSamples,eligible_interrupt_samples_in_windows=eligibleInterruptSamples,row_limit=sampleRowLimit,retained_rows=sampleRows.Count,rows_truncated=rowsTruncated,target_tids=targetTids,rows=sampleRows,symbol_path=symbolPath,symbol_lookup_attempts=attempted,symbol_errors=errors});
   Write(Path.Combine(output,"identity.json"),new{command=Environment.GetCommandLineArgs(),assembly_sha256=Hash(typeof(Program).Assembly.Location),source_sha256=Hash(Path.Combine(AppContext.BaseDirectory,"analyzer-source.cs.txt")),traceevent=typeof(TraceEvent).Assembly.FullName});
   Console.WriteLine(JsonSerializer.Serialize(new{windows=windows.Count,logical_processors=active.Count,top=totals.Take(12),samples_in_windows=samples}));return 0;
  }catch(Exception ex){Write(Path.Combine(output,"failure.json"),new{error=ex.ToString()});Console.Error.WriteLine(ex);return 1;}
 }
}
