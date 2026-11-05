using Microsoft.Diagnostics.Symbols;
using Microsoft.Diagnostics.Tracing;
using Microsoft.Diagnostics.Tracing.Etlx;
using Microsoft.Diagnostics.Tracing.Parsers.Kernel;
internal static class WorkerReader {
 sealed record Frame(string Address,string Module,string ModulePath,string Function,bool Resolved);
 sealed record Change(long Qpc,string Kind,int Tid,int Cpu,string State,string Reason,int Flags,int EmitterTid,int EmitterPid,int TargetPid,int CpuCurrentTid);
 sealed record Segment(long Start,long End,string State,string Reason,int Cpu);
 static bool Worker(Frame f)=>f.Resolved&&f.Module.StartsWith("libgodot_rapier")&&(f.Function.Contains("rayon_core::registry::main_loop")||f.Function.Contains("rayon_core::registry::WorkerThread::")||f.Function.Contains("rayon_core::registry::ThreadBuilder::run"));
 static object? Property(object o,string n)=>o.GetType().GetProperty(n)?.GetValue(o);
 public static void Run(string etl,string raw,string output,List<Program.Window> windows,string? existing){
  using var writer=File.CreateText(Path.Combine(output,"worker-processing.log"));
  string etlx=existing??Path.Combine(output,"derived.etlx");
  if(existing==null)TraceLog.CreateFromEventTraceLogFile(etl,etlx,new TraceLogOptions{ConversionLog=writer});
  using var log=new TraceLog(etlx);var callers=windows.Select(w=>w.Tid).ToHashSet();
  var pids=log.Threads.Where(t=>callers.Contains(t.ThreadID)).Select(t=>t.Process.ProcessID).Distinct().ToArray();
  if(pids.Length!=1)throw new Exception("ambiguous caller process/TID reuse");int pid=pids[0];
  var threads=log.Threads.Where(t=>t.Process.ProcessID==pid).ToArray();
  if(threads.Length>2048)throw new Exception("thread census capacity exceeded");
  var metadata=threads.Select(t=>new{tid=t.ThreadID,index=Property(t,"ThreadIndex"),name=Property(t,"ThreadName"),start_relative_ms=t.StartTimeRelativeMSec,end_relative_ms=t.EndTimeRelativeMSec,start=t.StartTime,end=t.EndTime}).ToArray();
  string? path=Environment.GetEnvironmentVariable("CYBERSAND_ETW_SYMBOL_PATH");
  using var symbols=path==null?null:new SymbolReader(writer,path);
  var attempted=new HashSet<string>();var errors=new List<object>();var cache=new Dictionary<ulong,Frame>();
  List<Frame> Frames(TraceCallStack? stack){
   var frames=new List<Frame>();int depth=0;
   for(var s=stack;s!=null&&depth++<192;s=s.Caller){var a=s.CodeAddress;
    if(!cache.TryGetValue(a.Address,out var f)){var module=a.ModuleFile;
     if(symbols!=null&&module!=null&&(a.ModuleName.StartsWith("libgodot_rapier")||a.ModuleName is "ntoskrnl" or "ntdll" or "kernel32" or "kernelbase")&&attempted.Add(module.FilePath))try{log.CodeAddresses.LookupSymbolsForModule(symbols,module);}catch(Exception ex){errors.Add(new{module=module.FilePath,error=ex.Message});}
     f=new($"0x{a.Address:x}",a.ModuleName,a.ModuleFilePath,a.FullMethodName,a.Method!=null);cache[a.Address]=f;
    }frames.Add(f);
   }return frames;
  }
  var workers=new HashSet<int>();var evidence=new Dictionary<int,List<object>>();var candidates=new Dictionary<int,HashSet<string>>();var lifetimes=new List<object>();var intervals=new List<object>();var starts=new Dictionary<int,long>();var ends=new Dictionary<int,long>();long first=long.MaxValue,last=0;
  foreach(var e in log.Events){
   first=Math.Min(first,e.TimeStampQPC);last=Math.Max(last,e.TimeStampQPC);
   if(e.EventName.Contains("Sample")&&e.EventName.Contains("Interval"))intervals.Add(new{qpc=e.TimeStampQPC,name=e.EventName,payload=e.PayloadNames.ToDictionary(n=>n,n=>e.PayloadByName(n))});
   if(e is ThreadTraceData&&e.ProcessID==pid){lifetimes.Add(new{qpc=e.TimeStampQPC,name=e.EventName,tid=e.ThreadID,payload=e.PayloadNames.ToDictionary(n=>n,n=>e.PayloadByName(n))});if(e.EventName=="Thread/Start")starts[e.ThreadID]=e.TimeStampQPC;if(e.EventName=="Thread/Stop")ends[e.ThreadID]=e.TimeStampQPC;}
   TraceCallStack? stack=null;int tid=e.ThreadID;string kind;
   if(e is SampledProfileTraceData&&e.ProcessID==pid){stack=e.CallStack();kind="cpu_sample";}
   else if(e is CSwitchTraceData c&&c.OldProcessID==pid){var ix=c.BlockingStack();stack=ix==CallStackIndex.Invalid?null:log.CallStacks[ix];tid=c.OldThreadID;kind="switch_out";}
   else continue;
   var frames=Frames(stack);var names=frames.Where(f=>f.Module.StartsWith("libgodot_rapier")&&f.Function.Contains("rayon_core::")).ToArray();
   if(names.Length==0)continue;
   if(!candidates.TryGetValue(tid,out var set)){set=new();candidates[tid]=set;}foreach(var f in names)set.Add(f.Function);
   if(!frames.Any(Worker))continue;workers.Add(tid);
   if(!evidence.TryGetValue(tid,out var saved)){saved=new();evidence[tid]=saved;}
   if(saved.Count<6)saved.Add(new{qpc=e.TimeStampQPC,tid,kind,frames});
  }
  if(workers.Overlaps(callers))throw new Exception("worker-loop identity overlaps caller");
  var active=workers.Where(t=>starts.GetValueOrDefault(t,first)<windows.Max(w=>w.End)&&ends.GetValueOrDefault(t,last)>windows.Min(w=>w.Start)).ToHashSet();
  Program.Write(Path.Combine(output,"worker-census.json"),new{schema="inv154-rayon-worker-census-v1",etl,etl_sha256=Program.Hash(etl),raw,raw_sha256=Program.Hash(raw),etlx,etlx_sha256=Program.Hash(etlx),process_id=pid,caller_tids=callers,worker_tids=workers.Order(),workers_overlapping_measurement=active.Order(),worker_start_qpc=starts.Where(p=>workers.Contains(p.Key)).ToDictionary(),worker_end_qpc=ends.Where(p=>workers.Contains(p.Key)).ToDictionary(),sample_profile_interval=log.SampleProfileInterval,trace_start_qpc=first,trace_end_qpc=last,first_long_qpc=windows.Min(w=>w.Start),last_long_qpc=windows.Max(w=>w.End),events_lost=log.EventsLost,trace_truncated=log.Truncated,has_call_stacks=log.HasCallStacks,profile_intervals=intervals,process_threads=metadata,thread_lifetime_events=lifetimes,worker_identity_evidence=evidence,rayon_candidate_symbols=candidates,symbol_errors=errors});
  Console.WriteLine($"Worker census pid={pid} workers={string.Join(',',workers.Order())}");
  Reconstruct(log,windows,active,callers,pid,first,last,output,Frames);
 }
 static void Reconstruct(TraceLog log,List<Program.Window> windows,HashSet<int> workers,HashSet<int> callers,int pid,long first,long last,string output,Func<TraceCallStack?,List<Frame>> frames){
  var target=workers.Union(callers).ToHashSet();var changes=new List<Change>();var stacks=new List<object>();var cpuCurrent=new Dictionary<int,int>();var anomalies=new List<object>();var completion=new List<(long Qpc,int Tid,int Target)>();bool truncated=false;long samples=0;
  bool InWindow(long q)=>windows.Any(w=>w.Start<=q&&q<=w.End);
  foreach(var e in log.Events){
   if(e is CSwitchTraceData c){
    if(target.Contains(c.OldThreadID)&&c.OldProcessID==pid)changes.Add(new(e.TimeStampQPC,"out",c.OldThreadID,e.ProcessorNumber,c.OldThreadState.ToString(),c.OldThreadWaitReason.ToString(),0,-1,-1,pid,cpuCurrent.GetValueOrDefault(e.ProcessorNumber,-1)));
    if(target.Contains(c.NewThreadID)&&c.NewProcessID==pid)changes.Add(new(e.TimeStampQPC,"in",c.NewThreadID,e.ProcessorNumber,"","",0,-1,-1,pid,c.NewThreadID));
    cpuCurrent[e.ProcessorNumber]=c.NewThreadID;
    if(target.Contains(c.OldThreadID)&&c.OldProcessID==pid&&InWindow(e.TimeStampQPC)){
     var ix=c.BlockingStack();var st=ix==CallStackIndex.Invalid?null:log.CallStacks[ix];
     if(stacks.Count<40000)stacks.Add(new{qpc=e.TimeStampQPC,tid=c.OldThreadID,kind="switch_out",available=st!=null,frames=frames(st),cpu=e.ProcessorNumber,state=c.OldThreadState.ToString(),reason=c.OldThreadWaitReason.ToString()});else truncated=true;
    }
   }
   else if(e is DispatcherReadyThreadTraceData r&&target.Contains(r.AwakenedThreadID)){
    changes.Add(new(e.TimeStampQPC,"ready",r.AwakenedThreadID,e.ProcessorNumber,"","",(int)r.Flags,e.ThreadID,e.ProcessID,r.AwakenedProcessID,cpuCurrent.GetValueOrDefault(e.ProcessorNumber,-1)));
    if(InWindow(e.TimeStampQPC)){var st=e.CallStack();var fs=frames(st);if(callers.Contains(r.AwakenedThreadID)&&workers.Contains(cpuCurrent.GetValueOrDefault(e.ProcessorNumber,-1))&&(int)r.Flags==0&&e.ThreadID==cpuCurrent.GetValueOrDefault(e.ProcessorNumber,-1)&&fs.Any(f=>f.Module=="ntdll"&&f.Function.Contains("WakeByAddress"))&&fs.Any(f=>f.Function.Contains("rayon_core::job::")&&f.Function.Contains("physics_world::")))completion.Add((e.TimeStampQPC,e.ThreadID,r.AwakenedThreadID));if(stacks.Count<40000)stacks.Add(new{qpc=e.TimeStampQPC,tid=r.AwakenedThreadID,kind="ready_target",header_tid=e.ThreadID,header_pid=e.ProcessID,cpu_current_tid=cpuCurrent.GetValueOrDefault(e.ProcessorNumber,-1),flags=(int)r.Flags,available=st!=null,frames=fs,cpu=e.ProcessorNumber});else truncated=true;}
   }
   else if(e is SampledProfileTraceData p&&workers.Contains(e.ThreadID)&&e.ProcessID==pid&&InWindow(e.TimeStampQPC)){
    samples++;var st=e.CallStack();if(stacks.Count<40000)stacks.Add(new{qpc=e.TimeStampQPC,tid=e.ThreadID,kind="cpu_sample",available=st!=null,frames=frames(st),cpu=e.ProcessorNumber,count=Property(p,"Count"),dpc=p.ExecutingDPC,isr=p.ExecutingISR});else truncated=true;
   }
   if(changes.Count>400000)throw new Exception("worker transition capacity exceeded");
  }
  var segments=new Dictionary<int,List<Segment>>();
  foreach(int tid in target){var list=new List<Segment>();segments[tid]=list;Change? run=null,off=null,ready=null;
   void Add(long a,long b,string state,string reason,int cpu){if(b>a)list.Add(new(a,b,state,reason,cpu));}
   void Close(long end){if(off==null)return;if(off.State is "Ready" or "Standby")Add(off.Qpc,end,"ready",off.State,off.Cpu);else if(off.State is "Wait" or "Waiting"){if(ready!=null){Add(off.Qpc,ready.Qpc,"waiting",off.Reason,off.Cpu);Add(ready.Qpc,end,"ready","ReadyThread",ready.Cpu);}else Add(off.Qpc,end,"unknown_off_cpu",off.State+":"+off.Reason+"; no usable ReadyThread",off.Cpu);}else Add(off.Qpc,end,"unknown_off_cpu",off.State+":"+off.Reason,off.Cpu);}
   foreach(var c in changes.Where(c=>c.Tid==tid).OrderBy(c=>c.Qpc)){
    if(c.Kind=="out"){if(run!=null)Add(run.Qpc,c.Qpc,"scheduled","CSwitch",run.Cpu);else if(off!=null)anomalies.Add(new{tid,qpc=c.Qpc,kind="out_without_in"});off=c;run=null;ready=null;}
    else if(c.Kind=="ready"){if(off!=null&&(c.Flags&6)==0)ready??=c;else if(run!=null)anomalies.Add(new{tid,qpc=c.Qpc,kind="ready_while_scheduled",flags=c.Flags});}
    else{Close(c.Qpc);off=null;ready=null;if(run!=null)anomalies.Add(new{tid,qpc=c.Qpc,kind="in_without_out"});run=c;}
   }
   if(run!=null)Add(run.Qpc,last,"scheduled","trace_end",run.Cpu);Close(last);
  }
  var reports=new List<object>();var totals=new Dictionary<int,Dictionary<string,double>>();
  foreach(var w in windows){var workersForWindow=new List<object>();double unit=1e6/w.Frequency;
   foreach(int tid in workers.Order()){long covered=0;var states=new Dictionary<string,double>();var spans=new List<object>();
    foreach(var seg in segments[tid]){long a=Math.Max(w.Start,seg.Start),b=Math.Min(w.End,seg.End);if(b<=a)continue;double us=(b-a)*unit;covered+=b-a;states[seg.State]=states.GetValueOrDefault(seg.State)+us;spans.Add(new{start_qpc=a,end_qpc=b,state=seg.State,reason=seg.Reason,processor=seg.Cpu,usec=us});}
    double missing=Math.Max(0,w.End-w.Start-covered)*unit;if(missing>0)states["unknown_coverage"]=missing;
    if(!totals.TryGetValue(tid,out var sum)){sum=new();totals[tid]=sum;}foreach(var pair in states)sum[pair.Key]=sum.GetValueOrDefault(pair.Key)+pair.Value;
    workersForWindow.Add(new{tid,states_usec=states,segments=spans});
   }
   var wakes=changes.Where(c=>c.Kind=="ready"&&w.Start<=c.Qpc&&c.Qpc<=w.End).ToArray();
   var signals=new List<object>();long finalSignal=completion.Where(x=>w.Start<=x.Qpc&&x.Qpc<=w.End).Select(x=>x.Qpc).DefaultIfEmpty(-1).Max();long longestCallerWait=completion.Where(x=>w.Start<=x.Qpc&&x.Qpc<=w.End).Select(x=>segments[x.Target].Where(z=>z.State=="waiting"&&z.End==x.Qpc).Select(z=>z.End-Math.Max(z.Start,w.Start)).DefaultIfEmpty(0).Max()).DefaultIfEmpty(0).Max();
   foreach(var signal in completion.Where(x=>w.Start<=x.Qpc&&x.Qpc<=w.End)){
    var before=new Dictionary<string,double>();
    foreach(var seg in segments[signal.Tid]){long a=Math.Max(w.Start,seg.Start),b=Math.Min(signal.Qpc,seg.End);if(b>a)before[seg.State]=before.GetValueOrDefault(seg.State)+(b-a)*unit;}
    var run=segments[signal.Tid].LastOrDefault(x=>x.State=="scheduled"&&x.Start<=signal.Qpc&&signal.Qpc<=x.End);
    var firstRun=segments[signal.Tid].FirstOrDefault(x=>x.State=="scheduled"&&x.End>w.Start&&x.Start<signal.Qpc);
    var callerWait=segments[signal.Target].LastOrDefault(x=>x.State=="waiting"&&x.End==signal.Qpc);var duringWait=new Dictionary<string,double>();
    if(callerWait!=null)foreach(var seg in segments[signal.Tid]){long a=Math.Max(Math.Max(w.Start,callerWait.Start),seg.Start),b=Math.Min(signal.Qpc,seg.End);if(b>a)duringWait[seg.State]=duringWait.GetValueOrDefault(seg.State)+(b-a)*unit;}
    signals.Add(new{signal_qpc=signal.Qpc,worker_tid=signal.Tid,caller_tid=signal.Target,is_final_verified_caller_wake=signal.Qpc==finalSignal,preceding_caller_wait_start_qpc=callerWait==null?(long?)null:Math.Max(w.Start,callerWait.Start),preceding_caller_wait_usec=callerWait==null?(double?)null:(signal.Qpc-Math.Max(w.Start,callerWait.Start))*unit,is_longest_caller_wait=callerWait!=null&&signal.Qpc-Math.Max(w.Start,callerWait.Start)==longestCallerWait,worker_states_during_caller_wait_usec=duringWait,states_before_signal_usec=before,first_schedule_after_window_start_usec=firstRun==null?(double?)null:Math.Max(0,firstRun.Start-w.Start)*unit,last_schedule_to_signal_usec=run==null?(double?)null:(signal.Qpc-Math.Max(w.Start,run.Start))*unit,proof="resolved OS WakeByAddress inside Rayon PhysicsWorld step job (latch set may be inlined); ReadyThread target caller, flags0, emitter and reconstructed CPU context agree",job_entry_observed=false});
   }
   reports.Add(new{window=w,bracket_usec=(w.End-w.Start)*unit,workers=workersForWindow,ready_events=wakes,verified_caller_completion_signals=signals});
  }
  Program.Write(Path.Combine(output,"worker-state.json"),new{schema="inv154-rayon-worker-state-v1",long_event_count=windows.Count,worker_tids=workers.Order(),total_states_usec_by_tid=totals,events_lost=log.EventsLost,trace_truncated=log.Truncated,stack_rows_truncated=truncated,worker_cpu_samples_in_windows=samples,verified_caller_completion_signal_count=completion.Count,transitions=changes,anomalies,long_events=reports,limitations=new[]{"All symbol-identified Rayon workers in the process, possibly multiple pools; idle workers are not assumed critical","Scheduled means scheduler residency, not useful computation; DPC/ISR and VM host interruptions remain distinct","Waiting without usable ReadyThread is unknown_off_cpu; missing trace coverage is explicit","Ready event header TID may be unknown; current CPU context retained separately and is not alone proof of a job completion","No exact job-entry or pool instance identity is inferred from sparse CPU sampling; multiple wakes may be condvar notification followed by latch mutex reacquisition, not multiple jobs"}});
  Program.Write(Path.Combine(output,"worker-stacks.json"),new{schema="inv154-rayon-worker-stacks-v1",events_lost=log.EventsLost,rows_truncated=truncated,rows=stacks});
  Console.WriteLine(System.Text.Json.JsonSerializer.Serialize(new{long_events=windows.Count,workers=workers.Count,total_states_usec_by_tid=totals,samples}));
 }
}
