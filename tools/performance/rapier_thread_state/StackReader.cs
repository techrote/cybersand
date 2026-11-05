using Microsoft.Diagnostics.Tracing.Etlx;
using Microsoft.Diagnostics.Tracing.Parsers.Kernel;
using Microsoft.Diagnostics.Symbols;
internal static class StackReader {
 public static void Run(string etl,string output,List<Program.Window> windows){
  using var writer=File.CreateText(Path.Combine(output,"stack-processing.log"));
  try{
   string derived=Path.Combine(output,"derived.etlx");
   TraceLog.CreateFromEventTraceLogFile(etl,derived,new TraceLogOptions{ConversionLog=writer});
   using var log=new TraceLog(derived);var rows=new List<object>();bool truncated=false;
   string? path=Environment.GetEnvironmentVariable("CYBERSAND_ETW_SYMBOL_PATH");
   using var symbols=path==null?null:new SymbolReader(writer,path);var attempted=new HashSet<string>();var errors=new List<object>();
   foreach(var e in log.Events){
    if(!windows.Any(w=>w.Start<=e.TimeStampQPC&&e.TimeStampQPC<=w.End))continue;
    TraceCallStack? stack=null;string kind="";int tid=e.ThreadID;
    if(e is SampledProfileTraceData&&windows.Any(w=>w.Tid==tid&&w.Start<=e.TimeStampQPC&&e.TimeStampQPC<=w.End)){stack=e.CallStack();kind="cpu_sample";}
    else if(e is CSwitchTraceData c&&windows.Any(w=>w.Tid==c.OldThreadID&&w.Start<=e.TimeStampQPC&&e.TimeStampQPC<=w.End)){var si=c.BlockingStack();stack=si==CallStackIndex.Invalid?null:log.CallStacks[si];kind="switch_out";tid=c.OldThreadID;}
    else continue;
    if(rows.Count>=25000){truncated=true;break;}var frames=new List<object>();int depth=0;
    for(var s=stack;s!=null&&depth++<192;s=s.Caller){
     var a=s.CodeAddress;var module=a.ModuleFile;
     if(symbols!=null&&module!=null&&attempted.Add(module.FilePath))try{log.CodeAddresses.LookupSymbolsForModule(symbols,module);}catch(Exception ex){errors.Add(new{module=module.FilePath,error=ex.Message});}
     frames.Add(new{address=$"0x{a.Address:x}",module=a.ModuleName,module_path=a.ModuleFilePath,function=a.FullMethodName,has_method=a.Method!=null});
    }
    rows.Add(new{qpc=e.TimeStampQPC,tid,kind,stack_available=stack!=null,frames});
   }
   Program.Write(Path.Combine(output,"stacks.json"),new{schema="inv154-etw-stack-v1",etl_sha256=Program.Hash(etl),has_call_stacks=log.HasCallStacks,has_pdb_info=log.HasPdbInfo,trace_truncated=log.Truncated,events_lost=log.EventsLost,symbol_path=path,symbol_lookup_attempts=attempted,symbol_errors=errors,row_limit=25000,rows_truncated=truncated,rows});
  }catch(Exception ex){Program.Write(Path.Combine(output,"stack-failure.json"),new{error=ex.ToString()});}
 }
}
