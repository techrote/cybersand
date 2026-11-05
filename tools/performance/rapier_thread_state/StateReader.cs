using Microsoft.Diagnostics.Tracing;
using Microsoft.Diagnostics.Tracing.Parsers.Kernel;
internal static class StateReader {
 sealed record Change(long Qpc,string Kind,int Tid,int Cpu,int Pid,string Process,string State,string Reason,int Flags);
 sealed record Segment(long Start,long End,string State,string Reason,int Cpu);
 public static void Run(string etl,string raw,string output,List<Program.Window> windows,HashSet<int> tids,long freq){
  var changes=new List<Change>();var samples=new List<object>();var processes=new Dictionary<int,object>();long cs=0,readyCount=0,sampleCount=0,stackCount=0,total=0,max=0,min=long.MaxValue;int lost;
  using(var s=new ETWTraceEventSource(etl)){
   s.AllEvents+=e=>{total++;max=Math.Max(max,e.TimeStampQPC);min=Math.Min(min,e.TimeStampQPC);};
   s.Kernel.All+=e=>{if(e is ThreadTraceData t&&tids.Contains(t.ThreadID))processes.TryAdd(t.ProcessID,new{pid=t.ProcessID,name=t.ProcessName});};
   s.Kernel.ThreadCSwitch+=e=>{cs++;if(tids.Contains(e.OldThreadID))changes.Add(new(e.TimeStampQPC,"out",e.OldThreadID,e.ProcessorNumber,e.OldProcessID,e.OldProcessName,e.OldThreadState.ToString(),e.OldThreadWaitReason.ToString(),0));if(tids.Contains(e.NewThreadID))changes.Add(new(e.TimeStampQPC,"in",e.NewThreadID,e.ProcessorNumber,e.NewProcessID,e.NewProcessName,"","",0));};
   s.Kernel.DispatcherReadyThread+=e=>{readyCount++;if(tids.Contains(e.AwakenedThreadID))changes.Add(new(e.TimeStampQPC,"ready",e.AwakenedThreadID,e.ProcessorNumber,e.AwakenedProcessID,"","","",(int)e.Flags));};
   s.Kernel.PerfInfoSample+=e=>{sampleCount++;if(windows.Any(w=>w.Tid==e.ThreadID&&w.Start<=e.TimeStampQPC&&e.TimeStampQPC<=w.End))samples.Add(new{qpc=e.TimeStampQPC,tid=e.ThreadID,pid=e.ProcessID,processor=e.ProcessorNumber,ip=$"0x{e.InstructionPointer:x}",dpc=e.ExecutingDPC,isr=e.ExecutingISR});};
   s.Kernel.StackWalkStack+=_=>stackCount++;s.Process();lost=s.EventsLost;
  }
  Program.Write(Path.Combine(output,"initial-counts.json"),new{events=total,cswitch=cs,ready_thread=readyCount,cpu_samples=sampleCount,stackwalk=stackCount,events_lost=lost,trace_min_qpc=min,trace_max_qpc=max,long_events=windows.Count,first_probe=windows.FirstOrDefault()?.Start,last_probe=windows.LastOrDefault()?.End});
  changes=changes.OrderBy(c=>c.Qpc).ThenBy(c=>c.Kind=="out"?0:c.Kind=="ready"?1:2).ToList();
  var all=new Dictionary<int,List<Segment>>();var anomalies=new List<object>();
  foreach(int tid in tids){
   var seg=new List<Segment>();all[tid]=seg;Change? run=null,off=null,rdy=null;
   void Add(long a,long b,string state,string reason,int cpu){if(b>a)seg.Add(new(a,b,state,reason,cpu));}
   void Close(long end){if(off==null)return;if(off.State is "Ready" or "Standby")Add(off.Qpc,end,"ready",off.State,off.Cpu);else if(off.State is "Wait" or "Waiting"){if(rdy!=null){Add(off.Qpc,rdy.Qpc,"waiting",off.Reason,off.Cpu);Add(rdy.Qpc,end,"ready","ReadyThread",rdy.Cpu);}else Add(off.Qpc,end,"unknown_off_cpu",off.State+":"+off.Reason+"; no usable ReadyThread",off.Cpu);}else Add(off.Qpc,end,"unknown_off_cpu",off.State+":"+off.Reason,off.Cpu);}
   foreach(var c in changes.Where(c=>c.Tid==tid)){
    if(c.Kind=="out"){if(run!=null)Add(run.Qpc,c.Qpc,"scheduled","CSwitch",run.Cpu);else if(off!=null)anomalies.Add(new{tid,qpc=c.Qpc,kind="out_without_in"});off=c;run=null;rdy=null;}
    else if(c.Kind=="ready"){if(off!=null&&(c.Flags&6)==0)rdy??=c;else if(run!=null)anomalies.Add(new{tid,qpc=c.Qpc,kind="ready_while_scheduled",flags=c.Flags});}
    else{Close(c.Qpc);off=null;rdy=null;if(run!=null)anomalies.Add(new{tid,qpc=c.Qpc,kind="in_without_out"});run=c;}
   }
   if(run!=null)Add(run.Qpc,max,"scheduled","trace_end",run.Cpu);Close(max);
  }
  var reports=new List<object>();var sums=new Dictionary<string,double>();
  foreach(var w in windows){double u=1e6/w.Frequency;long charged=0;var spans=new List<object>();var d=new Dictionary<string,double>();foreach(var p in all[w.Tid]){long a=Math.Max(w.Start,p.Start),b=Math.Min(w.End,p.End);if(b<=a)continue;double us=(b-a)*u;d[p.State]=d.GetValueOrDefault(p.State)+us;charged+=b-a;spans.Add(new{start_qpc=a,end_qpc=b,state=p.State,reason=p.Reason,processor=p.Cpu,usec=us});}double missing=Math.Max(0,w.End-w.Start-charged)*u;if(missing>0)d["unknown_coverage"]=missing;foreach(var p in d)sums[p.Key]=sums.GetValueOrDefault(p.Key)+p.Value;reports.Add(new{window=w,bracket_usec=(w.End-w.Start)*u,excess_over_step_usec=(w.End-w.Start)*u-w.StepUsec,states_usec=d,segments=spans});}
  Program.Write(Path.Combine(output,"thread-state.json"),new{schema="inv154-etw-thread-state-v1",etl,etl_sha256=Program.Hash(etl),raw,raw_sha256=Program.Hash(raw),qpc_frequency=freq,event_count=total,cswitch_count=cs,ready_thread_count=readyCount,sampled_profile_count=sampleCount,stackwalk_count=stackCount,events_lost=lost,trace_min_qpc=min,trace_max_qpc=max,target_tids=tids,processes=processes.Values,target_transitions=changes,long_event_count=windows.Count,total_states_usec=sums,long_events=reports,cpu_samples_in_long_events=samples,anomalies,limitations=new[]{"QPC before.high to after.low brackets space_step; exact excess retained","scheduled is scheduler residency; ISR/DPC and VM host descheduling may interrupt residency","waiting requires Waiting switch-out and usable ReadyThread; otherwise unknown_off_cpu"}});
  Console.WriteLine(System.Text.Json.JsonSerializer.Serialize(new{long_events=windows.Count,cswitch_count=cs,ready_thread_count=readyCount,events_lost=lost,total_states_usec=sums}));
 }
}
