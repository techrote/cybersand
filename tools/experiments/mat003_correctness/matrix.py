"""Pure matrix description. No subprocess, compilation or execution entry point."""
ARMS=('K64-E8','K64-E16','K72-E8','K72-E16','K80-E8','K80-E16','D128-E8','D128-E16')

def cases():
    rows=[]
    def add(suite,arm,sanitized,**kw):
        rows.append(dict(id=f'{suite}-{len(rows):03d}',suite=suite,arm=arm,sanitized=sanitized,**kw))
    for arm in ARMS:
        for sanitized in (False,True):
            add('storage',arm,sanitized,operations=65536,records=1024,timeout=300)
            for backend,workers in (('serial',1),('phased',1),('phased',4)):
                add('small',arm,sanitized,backend=backend,workers=workers,side=256,ticks=2048,timeout=300)
            if arm.endswith('E16'):
                add('natural',arm,sanitized,backend='serial',workers=1,side=128,ticks=65540,timeout=600)
                for side in (512,2048):
                    for scene in ('sleeping-excluded','active-window-excluded'):
                        for workers in (1,4):
                            add('resident',arm,sanitized,backend='phased',workers=workers,side=side,scene=scene,setup=255,reentry=4,roles=('event','reference'),timeout=600)
            add('refusal',arm,sanitized,chunks=4,operations=256,timeout=300)
    return rows

LIMITS=dict(platform_processes=152,platform_builds=32,platform_wall_seconds=21600,
            compile_seconds=180,concurrency=1,total_output_bytes=64*1024**3,
            normal_rss_bytes=2*1024**3,sanitized_rss_bytes=3*1024**3,
            qualification_admitted=False,timing_admitted=False)
