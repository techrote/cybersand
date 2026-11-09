"""Bounded scanline/pixel grammar; native owner independently validates everything."""
from .backend import NativeError


def raster_points(op,cell_limit):
    shape=op.get('shape')
    if shape=='pixels':
        if set(op)-{'shape','material','points','replace_only_material'}:raise NativeError('unknown_operation_field')
        points=op.get('points')
        if not isinstance(points,list) or not 1<=len(points)<=32:raise NativeError('pixels_count_1_to_32_required')
        if any(not isinstance(p,list) or len(p)!=2 or any(type(v) is not int for v in p) for p in points):raise NativeError('invalid_pixel_coordinate')
        result=[tuple(p) for p in points]
        if len(set(result))!=len(result):raise NativeError('duplicate_pixel_coordinate')
        return result,None
    if shape!='scanlines':raise NativeError('unsupported_shape')
    required={'shape','x','y','width','height','scale','material','rows'}
    if set(op)!=required:raise NativeError('invalid_stamp_fields')
    if any(type(op[k]) is not int for k in ('x','y','width','height','scale','material')):raise NativeError('invalid_stamp_integer')
    x,y,w,h,scale=(op[k] for k in ('x','y','width','height','scale'))
    if not 1<=w<=256 or not 1<=h<=256 or not 1<=scale<=16:raise NativeError('invalid_stamp_dimensions')
    if w*h*scale*scale>cell_limit:raise NativeError('stamp_exceeds_cell_budget')
    rows=op['rows']
    if not isinstance(rows,list) or not 1<=len(rows)<=256:raise NativeError('invalid_scanline_rows')
    result=[];row=0;span_count=0
    for group in rows:
        if not isinstance(group,dict) or set(group)!={'repeat','spans'} or type(group['repeat']) is not int or not 1<=group['repeat']<=h-row:raise NativeError('invalid_scanline_repeat')
        spans=group['spans']
        if not isinstance(spans,list) or len(spans)>256:raise NativeError('invalid_scanline_spans')
        span_count+=len(spans)
        if span_count>2048:raise NativeError('scanline_span_capacity')
        end=0
        for span in spans:
            if not isinstance(span,list) or len(span)!=2 or any(type(v) is not int for v in span):raise NativeError('invalid_scanline_span')
            start,length=span
            if start<end or length<1 or start<0 or start+length>w:raise NativeError('overlapping_or_outside_scanline_span')
            end=start+length
            for yy in range(row*scale,(row+group['repeat'])*scale):
                result.extend((x+xx,y+yy) for xx in range(start*scale,end*scale))
        row+=group['repeat']
    if row!=h:raise NativeError('scanline_height_mismatch')
    return result,(x,y,w*scale,h*scale)


def pixel_schema(allowed):
    return {'type':'object','additionalProperties':False,'properties':{
        'observation_id':{'type':'string'},'material':{'type':'integer','enum':list(allowed)},
        'points':{'type':'array','minItems':1,'maxItems':32,'items':{'type':'array','minItems':2,'maxItems':2,'items':{'type':'integer'}}}},'required':['observation_id','material','points']}


def native_packet(name,args,mode):
    if mode=='scanline':
        if name not in ('observe','prepare_stamp','apply_edit','step'):raise NativeError('tool_not_in_scanline_mode')
    elif name not in ('observe','prepare_edit','prepare_pixels','apply_edit','step'):raise NativeError('tool_not_in_tools_mode')
    if name=='prepare_pixels':
        if not isinstance(args,dict) or set(args)!={'observation_id','material','points'}:raise NativeError('invalid_pixels_packet')
        return 'prepare_edit',{'observation_id':args['observation_id'],'operations':[{'shape':'pixels','material':args['material'],'points':args['points']}]}
    if name=='prepare_stamp':
        if not isinstance(args,dict) or set(args)!={'observation_id','stamp'} or not isinstance(args['stamp'],dict) or 'shape' in args['stamp']:raise NativeError('invalid_stamp_packet')
        return 'prepare_edit',{'observation_id':args['observation_id'],'operations':[{**args['stamp'],'shape':'scanlines'}]}
    if name=='prepare_edit' and isinstance(args,dict) and any(op.get('shape') not in ('disc','line','rectangle') for op in args.get('operations',[]) if isinstance(op,dict)):
        raise NativeError('use_dedicated_pixels_tool')
    return name,args
