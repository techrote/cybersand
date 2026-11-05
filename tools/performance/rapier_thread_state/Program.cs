using System.Security.Cryptography;
using System.Text.Json;
using Microsoft.Diagnostics.Tracing;
internal static class Program {
 public static readonly JsonSerializerOptions Json=new(){WriteIndented=true,PropertyNamingPolicy=JsonNamingPolicy.SnakeCaseLower};
 public static string Hash(string p){using var f=File.OpenRead(p);return Convert.ToHexString(SHA256.HashData(f)).ToLowerInvariant();}
 public static void Write(string p,object v)=>File.WriteAllText(p,JsonSerializer.Serialize(v,Json)+"\n");
 public sealed record Window(int Index,string Phase,long Frame,int Tid,long Start,long End,long Frequency,long StepUsec);
 public static string ReaderSourceDirectory(){
  var explicitPath=Environment.GetEnvironmentVariable("CYBERSAND_ETW_READER_SOURCE");
  var candidates=new[]{explicitPath,Path.Combine(Directory.GetCurrentDirectory(),"tools/performance/rapier_thread_state"),Path.GetFullPath(Path.Combine(AppContext.BaseDirectory,"../../.."))};
  foreach(var path in candidates)if(path!=null&&File.Exists(Path.Combine(path,"Program.cs"))&&File.Exists(Path.Combine(path,"StateReader.cs")))return Path.GetFullPath(path);
  throw new DirectoryNotFoundException("Set CYBERSAND_ETW_READER_SOURCE to the exact reader source directory");
 }
 public static int Main(string[] a){
  if(a.Length<3){Console.Error.WriteLine("Usage: analyzer ETL raw.json output-dir [--stacks] [--workers] [--etlx existing.etlx]");return 2;}
  string etl=Path.GetFullPath(a[0]),rawPath=Path.GetFullPath(a[1]),output=Path.GetFullPath(a[2]);Directory.CreateDirectory(output);
  try{
   using var raw=JsonDocument.Parse(File.ReadAllBytes(rawPath));var windows=new List<Window>();var tids=new HashSet<int>();long frequency=0;int i=0;
   foreach(var row in raw.RootElement.GetProperty("physics_rows").EnumerateArray()){
    var p=row.GetProperty("cpu_probe");var b=p.GetProperty("cpu_before").EnumerateArray().Select(x=>x.GetInt64()).ToArray();var e=p.GetProperty("cpu_after").EnumerateArray().Select(x=>x.GetInt64()).ToArray();
    if(b.Length!=10||e.Length!=10||b[1]!=e[1]||b[4]!=e[4]||b[4]<=0||b[8]!=0||e[8]!=0)throw new Exception("counter schema/capability failed");
    frequency=b[4];tids.Add((int)b[1]);long step=row.GetProperty("bridge_step_usec").GetInt64();if(step<=40000)continue;
    windows.Add(new(++i,row.GetProperty("phase").GetString()!,row.GetProperty("physics_frames").GetInt64(),(int)b[1],b[3],e[2],b[4],step));
   }
   if(a.Contains("--workers")){int pos=Array.IndexOf(a,"--etlx");string? existing=pos>=0&&pos+1<a.Length?Path.GetFullPath(a[pos+1]):null;WorkerReader.Run(etl,rawPath,output,windows,existing);}
   else{StateReader.Run(etl,rawPath,output,windows,tids,frequency);if(a.Contains("--stacks"))StackReader.Run(etl,output,windows);}
   Write(Path.Combine(output,"analyzer-identity.json"),new{command=Environment.GetCommandLineArgs(),runtime=System.Runtime.InteropServices.RuntimeInformation.FrameworkDescription,traceevent=typeof(TraceEvent).Assembly.FullName,source=Directory.GetFiles(ReaderSourceDirectory(),"*.cs").ToDictionary(p=>Path.GetFileName(p),Hash),assembly_sha256=Hash(typeof(Program).Assembly.Location)});return 0;
  }catch(Exception ex){Write(Path.Combine(output,"failure.json"),new{error=ex.ToString()});Console.Error.WriteLine(ex);return 1;}
 }
}
