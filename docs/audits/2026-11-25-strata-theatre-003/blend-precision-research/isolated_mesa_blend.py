"""Isolated Mesa blend arithmetic experiment; not Godot graphical qualification."""
import ctypes as c, ctypes.util, json
P,I,U,F=c.c_void_p,c.c_int,c.c_uint,c.c_float
E=c.CDLL(ctypes.util.find_library('EGL'))
G=c.CDLL(ctypes.util.find_library('GL'))
def api(lib,name,result,args):
 f=getattr(lib,name);f.restype=result;f.argtypes=args;return f
display=api(E,'eglGetPlatformDisplay',P,[U,P,P])(0x31DD,None,None)
a,b=I(),I();assert api(E,'eglInitialize',U,[P,c.POINTER(I),c.POINTER(I)])(display,c.byref(a),c.byref(b))
assert api(E,'eglBindAPI',U,[U])(0x30A2)
attrs=(I*15)(0x3033,1,0x3040,8,0x3024,8,0x3023,8,0x3022,8,0x3021,8,0x3025,0,0x3038)
config=P();count=I()
assert api(E,'eglChooseConfig',U,[P,c.POINTER(I),c.POINTER(P),I,c.POINTER(I)])(display,attrs,c.byref(config),1,c.byref(count)) and count.value
surface=api(E,'eglCreatePbufferSurface',P,[P,P,c.POINTER(I)])(display,config,(I*5)(0x3057,1,0x3056,1,0x3038))
context=api(E,'eglCreateContext',P,[P,P,P,c.POINTER(I)])(display,config,None,(I*5)(0x3098,3,0x30FB,3,0x3038))
assert context and surface and api(E,'eglMakeCurrent',U,[P,P,P,P])(display,surface,surface,context)
get_string=api(G,'glGetString',c.c_char_p,[U])
metadata={'scope':__doc__,'renderer':get_string(0x1F01).decode(),'version':get_string(0x1F02).decode()}
shader_create=api(G,'glCreateShader',U,[U]);shader_source=api(G,'glShaderSource',None,[U,I,c.POINTER(c.c_char_p),c.POINTER(I)])
shader_compile=api(G,'glCompileShader',None,[U]);shader_param=api(G,'glGetShaderiv',None,[U,U,c.POINTER(I)])
def compile_shader(kind,source):
 s=shader_create(kind);data=c.c_char_p(source.encode());shader_source(s,1,c.byref(data),None);shader_compile(s);ok=I();shader_param(s,0x8B81,c.byref(ok));assert ok.value,source;return s
vertex=compile_shader(0x8B31,'#version 330\nvoid main(){vec2 v[3]=vec2[3](vec2(-1,-1),vec2(3,-1),vec2(-1,3));gl_Position=vec4(v[gl_VertexID],0,1);}')
create_program=api(G,'glCreateProgram',U,[]);attach=api(G,'glAttachShader',None,[U,U]);link=api(G,'glLinkProgram',None,[U]);use=api(G,'glUseProgram',None,[U])
programs={}
for name,body in {
 'legacy':'colour=vec4(mix(source.rgb,vec3(.055,.105,.15),.3),source.a)*vec4(1,1,1,opacity);',
 'premultiplied':'vec4 q=vec4(mix(source.rgb,vec3(.055,.105,.15),.3)*source.a,source.a);colour=vec4(q.rgb*opacity,q.a*opacity);',
 'straight_branch':'colour=vec4(mix(source.rgb,vec3(.055,.105,.15),.3),source.a)*vec4(1,1,1,opacity);',
 }.items():
 fragment=compile_shader(0x8B30,'#version 330\nuniform vec4 source; uniform float opacity;out vec4 colour;void main(){'+body+'}')
 p=create_program();attach(p,vertex);attach(p,fragment);link(p);programs[name]=p
vao=U();api(G,'glGenVertexArrays',None,[I,c.POINTER(U)])(1,c.byref(vao));api(G,'glBindVertexArray',None,[U])(vao)
api(G,'glViewport',None,[I,I,I,I])(0,0,1,1)
enable=api(G,'glEnable',None,[U]);disable=api(G,'glDisable',None,[U]);enable(0x0BE2);disable(0x0BD0)
blend=api(G,'glBlendFuncSeparate',None,[U,U,U,U]);clear_colour=api(G,'glClearColor',None,[F,F,F,F]);clear=api(G,'glClear',None,[U]);draw=api(G,'glDrawArrays',None,[U,I,I]);finish=api(G,'glFinish',None,[])
location=api(G,'glGetUniformLocation',I,[U,c.c_char_p]);four=api(G,'glUniform4f',None,[I,F,F,F,F]);one=api(G,'glUniform1f',None,[I,F]);read=api(G,'glReadPixels',None,[I,I,I,I,U,U,P])
rows=[]
for opacity in [.5,.3,.7,1.0]:
 for source in [(229,229,229,255),(25,25,25,255),(0,0,127,127),(255,255,255,255)]:
  row={'source_u8':source,'opacity':opacity,'outputs':{}}
  for name,p in programs.items():
   use(p);four(location(p,b'source'),*(x/255 for x in source));one(location(p,b'opacity'),opacity)
   blend(1 if name=='premultiplied' else 0x0302,0x0303,1,0x0303)
   clear_colour(0,0,0,0);clear(0x4000);draw(4,0,3);finish();pixel=(c.c_ubyte*4)();read(0,0,1,1,0x1908,0x1401,pixel)
   assert api(G,'glGetError',U,[])()==0,'OpenGL arithmetic probe error'
   row['outputs'][name]=list(pixel)
  rows.append(row)
record={'schema':'strata3-isolated-blend-precision-v1','metadata':metadata,'cases':rows,
        'legacy_premultiplied_different_cases':sum(r['outputs']['legacy']!=r['outputs']['premultiplied'] for r in rows),
        'direct_straight_branch_exact_cases':sum(r['outputs']['legacy']==r['outputs']['straight_branch'] for r in rows),
        'limitations':['Source RGBA values are uniforms reproducing captured texture samples. This is an isolated Mesa blend experiment, not Godot renderer execution or physical GPU qualification.','The final Godot shader and ordinary Workbench must pass their own hosted graphical tests.']}
print(json.dumps(record,indent=2))
assert api(E,'eglMakeCurrent',U,[P,P,P,P])(display,None,None,None)
assert api(E,'eglDestroyContext',U,[P,P])(display,context)
assert api(E,'eglDestroySurface',U,[P,P])(display,surface)
assert api(E,'eglTerminate',U,[P])(display)
