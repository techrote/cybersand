"""Mode separation, exact raster grammar, protection and real provider projection."""
import copy,json,unittest
from unittest.mock import patch
from .raster import raster_points,native_packet
from .desktop_backend import validate_desktop_tool,desktop_tool_schemas
from .backend import NativeError
from .boilerplate import sections
from .providers import request_body,scanline_decision,Decision,HTTPAdapter,ProviderError
from .config import load_profile
from .test_runner import HERE

class RasterTests(unittest.TestCase):
    def stamp(self):return {'shape':'scanlines','x':30,'y':30,'width':4,'height':3,'scale':2,'material':58,'rows':[{'repeat':1,'spans':[[0,4]]},{'repeat':1,'spans':[[0,1],[3,1]]},{'repeat':1,'spans':[[0,4]]}]}
    def test_exact_scanlines_repeat_scale_and_holes(self):
        points,bounds=raster_points(self.stamp(),64)
        expected={(x,y) for y in range(30,36) for x in range(30,38) if y not in (32,33) or x in (30,31,36,37)}
        self.assertEqual(set(points),expected);self.assertEqual(len(points),40);self.assertEqual(bounds,(30,30,8,6))
        blank=self.stamp();blank['rows']=[{'repeat':3,'spans':[]}]
        self.assertEqual(raster_points(blank,48)[0],[])
    def test_scanline_malformed_and_expanded_capacity(self):
        for field,value in [('scale',0),('width',257),('rows',[{'repeat':4,'spans':[]}]),('rows',[{'repeat':2,'spans':[]}]),('rows',[{'repeat':3,'spans':[[2,3]]}]),('rows',[{'repeat':3,'spans':[[1,2],[2,1]]}]),('rows',[{'repeat':3,'spans':[[0,1.5]]}])]:
            op=self.stamp();op[field]=value
            with self.assertRaises(NativeError,msg=str(op)):raster_points(op,65536)
        with self.assertRaisesRegex(NativeError,'stamp_exceeds_cell_budget'):raster_points(self.stamp(),47)
    def test_pixels_exact32_distinct_and_integer(self):
        op={'shape':'pixels','material':58,'points':[[i,0] for i in range(32)]}
        self.assertEqual(len(raster_points(op,32)[0]),32)
        for points in (op['points']+[[32,0]],[[0,0],[0,0]],[[1.5,0]],[[True,0]],[]):
            with self.assertRaises(NativeError):raster_points({**op,'points':points},65536)
    def test_bounds_protection_and_material_remain_enforced(self):
        scope={'x':0,'y':0,'width':64,'height':64}
        args={'observation_id':'o','operations':[self.stamp()]}
        validate_desktop_tool('prepare_edit',args,scope,{0,58},[],'o',None,0,480,64)
        for changed,protected in ((args,[{'x':30,'y':30,'width':1,'height':1}]),({'observation_id':'o','operations':[{**self.stamp(),'material':2}]},[]),({'observation_id':'o','operations':[{**self.stamp(),'x':60}]},[])):
            with self.assertRaises(NativeError):validate_desktop_tool('prepare_edit',changed,scope,{0,58},protected,'o',None,0,480,64)
    def test_modes_have_distinct_authoring_interfaces(self):
        self.assertIn('prepare_pixels',desktop_tool_schemas())
        self.assertNotIn('prepare_stamp',desktop_tool_schemas())
        pixel={'observation_id':'o','material':58,'points':[[1,1]]}
        self.assertEqual(native_packet('prepare_pixels',pixel,'tools')[1]['operations'][0]['shape'],'pixels')
        for name,args,mode in [('prepare_pixels',pixel,'scanline'),('prepare_edit',{},'scanline'),('prepare_stamp',{},'tools')]:
            with self.assertRaises(NativeError):native_packet(name,args,mode)
        self.assertNotEqual(sections()['system'],sections(mode='scanline')['system'])
        self.assertNotIn('tool_prepare_edit',sections(mode='scanline'))
    def test_actual_scanline_requests_have_no_function_tools_and_all_own_wording(self):
        cfg=load_profile(HERE/'profiles/fixture.json',fixture_mode=True,desktop=True)
        cfg['_authoring_mode']='scanline';cfg['_boilerplate']={k:'SCAN_'+k for k in sections(mode='scanline')}
        history=[{'kind':'user','text':'job'},{'kind':'call','tool':'prepare_stamp','id':'call','args':{'observation_id':'o','stamp':{}}},{'kind':'result','id':'call','text':'{"status":"proposed"}\n[Earlier image omitted.]'}]
        for provider in ('openai_responses','nvidia_chat','ollama_chat'):
            cfg['provider']=provider;body=request_body(cfg,history,desktop_tool_schemas(),include_image_bytes=False)
            self.assertNotIn('tools',body);self.assertNotIn('parallel_tool_calls',body)
            raw=json.dumps(body)
            self.assertNotIn('function_call',raw);self.assertNotIn('tool_calls',raw)
            for key in ('system','packet_inspect','packet_stamp','packet_apply','packet_step','packet_finish'):self.assertIn('SCAN_'+key,raw)
            self.assertIn('assistant',raw);self.assertIn('Earlier image omitted',raw)
    def test_scanline_plaintext_response_decodes_to_native_lifecycle(self):
        d=Decision('final',text=json.dumps({'action':'stamp','observation_id':'o','stamp':{k:v for k,v in self.stamp().items() if k!='shape'}}))
        decoded=scanline_decision(d,'c');self.assertEqual(decoded.tool,'prepare_stamp')
        name,args=native_packet(decoded.tool,decoded.args,'scanline');self.assertEqual(name,'prepare_edit')
        self.assertEqual(raster_points(args['operations'][0],64)[0],raster_points(self.stamp(),64)[0])
        self.assertEqual(scanline_decision(Decision('final',text='{"action":"finish","message":"done"}'),'c').text,'done')
        for text in ('```json {} ```','{"action":"shell"}','[]','{"action":"finish","message":"ok"}'+(' '*32000)):
            with self.assertRaises(ProviderError):scanline_decision(Decision('final',text=text),'c')
    def test_real_http_adapter_projection_and_decode(self):
        cfg=load_profile(HERE/'profiles/fixture.json',fixture_mode=True,desktop=True);cfg['_authoring_mode']='scanline'
        cfg['_boilerplate']=sections(mode='scanline')
        answer={'model':cfg['model'],'choices':[{'finish_reason':'stop','message':{'content':'{"action":"inspect","region":null,"detail":"cells"}'}}],'usage':{'prompt_tokens':100,'completion_tokens':20}}
        with patch('workbench_api_agent.providers.http_post',return_value=answer) as post:
            d=HTTPAdapter(cfg,fixture_mode=True).request([{'kind':'user','text':'job'}],6000000,30)
        self.assertEqual(d.tool,'observe');self.assertNotIn('tools',post.call_args.args[2])

    def test_openai_scanline_packet_above_old_prose_cap_is_not_truncated(self):
        cfg=load_profile(HERE/'profiles/fixture.json',fixture_mode=True,desktop=True)
        cfg.update(provider='openai_responses',endpoint='https://api.openai.com/v1/responses',_authoring_mode='scanline',_boilerplate=sections(mode='scanline'))
        stamp={'x':0,'y':0,'width':1,'height':256,'scale':1,'material':58,'rows':[{'repeat':1,'spans':[[0,1]]} for _ in range(256)]}
        text=json.dumps({'action':'stamp','observation_id':'o','stamp':stamp})
        self.assertGreater(len(text),8000)
        answer={'status':'completed','model':cfg['model'],'output':[{'type':'message','content':[{'type':'output_text','text':text}]}],'usage':{'input_tokens':100,'output_tokens':3000}}
        with patch('workbench_api_agent.providers.http_post',return_value=answer):
            decision=HTTPAdapter(cfg,fixture_mode=True).request([{'kind':'user','text':'job'}],6000000,30)
        self.assertEqual(decision.tool,'prepare_stamp')
        self.assertEqual(len(decision.args['stamp']['rows']),256)
        _,args=native_packet(decision.tool,decision.args,'scanline')
        self.assertEqual(len(raster_points(args['operations'][0],256)[0]),256)

    def test_openai_commentary_is_not_concatenated_into_final_packet(self):
        from .providers import parse_response,render_history_response
        final='{"action":"inspect","region":null,"detail":"cells"}'
        answer={'status':'completed','model':'test','output':[
            {'type':'message','phase':'commentary','content':[{'type':'output_text','text':'{"action":"inspect"} trailing commentary'}]},
            {'type':'message','phase':'commentary','content':[{'type':'output_text','text':'{"action":"stamp","observation_id":"not-issued"}'}]},
            {'type':'message','phase':'final_answer','content':[{'type':'output_text','text':final}]}]}
        decision=parse_response(answer,'openai_responses','test')
        self.assertEqual(decision.text,final)
        self.assertEqual(scanline_decision(decision,'c').tool,'observe')
        answer['output'].pop()
        with self.assertRaisesRegex(ProviderError,'response_final_message_missing'):parse_response(answer,'openai_responses','test')
        messages=render_history_response([{'kind':'agent','text':final}],1000,'low')
        self.assertEqual(messages[0]['phase'],'final_answer')

    def test_nvidia_explicit_alias_keeps_actual_identity_and_rejects_other_models(self):
        from .providers import parse_response
        canonical='nvidia/nemotron-3.5-super-vl-120b-a12b'
        actual='private/nvidia/nemotron-3.5-super-120b-a12b'
        answer={'model':actual,'choices':[{'finish_reason':'stop','message':{'content':'done'}}]}
        with self.assertRaisesRegex(ProviderError,'provider_model_changed'):parse_response(answer,'nvidia_chat',canonical)
        d=parse_response(answer,'nvidia_chat',canonical,allowed_models=[actual])
        self.assertEqual(d.model,actual)
        answer['model']='another-model'
        with self.assertRaises(ProviderError):parse_response(answer,'nvidia_chat',canonical,allowed_models=[actual])
