"""Regenerate the combat HUD previews from its authored layout dimensions."""
import json
from pathlib import Path

PANEL = [3, 24, 39]
MUTED = [165, 180, 192]

def frame(name, w, h, x, y, children=(), bg=PANEL, anchor=(0, 0)):
    textured = name not in ('Fill', 'Track', 'PlayerHealth', 'AbilityHUD')
    button = name in ('Skip', 'Activate', 'Price', 'Shop')
    layers=list(children)
    if textured:
        layers.insert(0,dict(type='ImageLabel',name='StudTexture',size=[1,0,1,0],bgTransparency=1,
                            icon='rbxassetid://6927295847',scaleType='Tile',tileSize=[0,108 if button else 48 if name=='Slot' else 64,0,108 if button else 48 if name=='Slot' else 64],
                            imageTransparency=.72 if name!='Slot' else .86))
    edge=[int(channel*.56) for channel in bg] if button else [239,91,43] if name=='RageBar' else [42,79,102]
    outlines=[] if name in ('Fill','Track','AbilityHUD') else [dict(thickness=3 if button else 2,color=edge,applyMode='Border')]
    if name=='PlayerHealth':
        outlines=[dict(thickness=1,color=[15,20,18],applyMode='Border')]
    return dict(type='Frame', name=name, size=[0,w,0,h], position=[0,x,0,y],
                anchor=list(anchor), bg=bg, children=layers,
                corner=4 if textured else 0,
                strokes=outlines)

def text(name, value, x, y, w, h, color=(237,243,247)):
    return dict(type='TextLabel', name=name, text=value, size=[0,w,0,h],
                position=[0,x,0,y], bgTransparency=1, textColor=list(color),
                textScaled=True, textXAlignment='Left', font='Ubuntu',fontWeight='Bold')

def icon(name,asset,x,y,w,h):
    return dict(type='ImageLabel',name=name,icon=asset,position=[0,x,0,y],size=[0,w,0,h],
                bgTransparency=1,scaleType='Fit')

def design(width,height):
    compact = width < 1400
    narrow = width < 700
    reference_factor=min(1,1280/width,720/height)
    rw,rh=width*reference_factor,height*reference_factor
    def fit(sx,ox,sy,oy,ratio):
        w=sx*.65*width+ox+sx*.35*rw
        h=sy*.65*height+oy+sy*.35*rh
        return min(w,h*ratio),min(h,w/ratio)
    # Authored surfaces use the same responsive envelope as production Vide.
    round_ratio=396/68 if narrow else 520/68
    w,h=fit(.9,0,.08,0,round_ratio)
    if narrow:
        w,h=152,36
    k=w/(396 if narrow else 520)
    top=frame('RoundStatus',w,h,width/2+(8 if narrow and height<width else 0),44,anchor=(.5,0),children=[
        text('Round','ROUND\n5' if narrow else 'ROUND 5',w*.025,h*.18,w*.26,h*.64),
        text('Remaining','7 LEFT' if narrow else '7 REMAINING',w*.32,h*.18,w*.34,h*.28,MUTED),
        text('Timer','01:00',w*.32,h*.55,w*.34,h*.26),
        frame('Skip',w*.27,h*.66,w*.705,h*.17,
              [text('Label','SKIP\n0/1' if narrow else 'SKIP 0/1',w*.02,h*.15,w*.23,h*.36)],bg=[219,112,45])])
    if narrow:
        bw=width-24
    else:
        bw=.22*.65*width+160+.22*.35*rw
    xp=frame('XPBar',bw,52,width/2,height-16,anchor=(.5,1),children=[
        text('Level','LEVEL 6',10,4,bw*.34,18),text('XP','55 / 65 XP',bw*.62-10,4,bw*.38,18,MUTED),
        frame('Track',bw-20,16,10,28,[frame('Fill',(bw-20)*55/65,16,0,0,bg=[67,222,143])],bg=[30,43,52])])
    rage=frame('RageBar',bw,52,width/2,height-76,anchor=(.5,1),children=[
        text('Status','RAGE 100%',bw*.025,5,bw*.66,20,[255,226,184]),
        frame('Track',bw*.66,13,bw*.025,30,[frame('Fill',bw*.66,13,0,0,bg=[221,116,57])],bg=[53,35,34]),
        frame('Activate',bw*.28,39,bw*.705,6.5,[text('Label','ACTIVATE [R]',bw*.018,10,bw*.244,19)],bg=[230,79,42])])
    aw=min(370,width*.55 if narrow and height<width else width-24) if compact else 432
    ah=aw/ (370/106 if compact else 432/118)
    ak=aw/(370 if compact else 432)
    rows=[]
    row_step=54 if compact else 60
    for row,label in enumerate(['WEAPONS','PASSIVES']):
        heading=text(label,label,4*ak,(row*row_step+8)*ak,66*ak,14*ak,MUTED)
        count=text(label+'Count','1 / 5',14*ak,(row*row_step+27)*ak,48*ak,19*ak)
        heading['textXAlignment']=count['textXAlignment']='Center'
        rows.extend([heading,count])
        cell=(42 if compact else 54)*ak
        gap=(5 if compact else 6)*ak
        for slot in range(6):
            occupied=slot==0
            locked=slot==5
            content=[]
            if occupied:
                content=[icon('Icon','rbxassetid://102194989748667' if row==0 else 'rbxassetid://109206613200684',cell*.16,cell*.07,cell*.68,cell*.68),
                         text('Level','LV.5' if row==0 else 'LV.1',cell*.075,cell*.73,cell*.85,cell*.23)]
            elif locked:
                content=[icon('Lock','rbxassetid://18209587260',cell*.29,cell*.15,cell*.42,cell*.42),
                         text('Unlock','+ SLOT',cell*.08,cell*.73,cell*.84,cell*.23,[185,162,114])]
            node=frame('Slot',cell,cell,78*ak+slot*(cell+gap),row*row_step*ak,content,bg=[28,39,49] if occupied else PANEL)
            node['strokes'][0]['color']=[145,102,211] if occupied else [136,108,52] if locked else [54,85,103]
            rows.append(node)
    portrait=height>width
    tray=frame('AbilityHUD',aw,ah,width/2 if portrait else width-20,
               height-122 if portrait else 94 if compact else height-16,
               rows,anchor=(.5,1) if portrait else (1,0) if compact else (1,1))
    def offer(name,value,y):
        oh=44 if height<360 else 54 if narrow else 58
        return frame(name,200 if narrow else 220,oh,12 if compact else 20,y,[
            icon('Artwork','rbxassetid://115042318829702' if name=='RunBoost' else 'rbxassetid://99546721866961',6,6,34,oh-12),
            text('Title',value,46,oh*.14,88 if narrow else 108,oh*.32),text('Detail','THIS RUN' if name=='RunBoost' else 'TEAMMATES',46,oh*.61,88 if narrow else 108,oh*.22,MUTED),
            frame('Price',54,oh-12,140 if narrow else 160,6,[text('Value','20 R$',5,(oh-30)/2,44,18)],bg=[241,180,67])])
    nodes=[top,xp,rage,tray,offer('RunBoost','RUN BOOST',172 if compact else height/2-57),
           offer('ReviveTeam','REVIVE 1',(238 if portrait else 138 if height<360 else 154) if compact else height/2-123),
           frame('Coins',200 if narrow else 220,42 if narrow else 44,12 if compact else 20,(124 if portrait else 44) if compact else height/2+15,
                 [icon('Coin','rbxassetid://117589844207603',8,7,30,30),text('Balance','1,284',46,8,144,26,[255,231,158])]),
           frame('Shop',142,42 if compact else 50,width-154 if compact else 20,
                 (124 if portrait else 44) if compact else height/2+73,
                 [icon('Coin','rbxassetid://117589844207603',10,10,24,24),text('Label','SHOP',42,8,88,26)],bg=[225,157,40])]
    if compact and not portrait:
        nodes[4]['position'][3]=88
    # The world billboard is approximated at the screenshot's projected 12 pixels per stud.
    health=frame('PlayerHealth',4.6*12+24,.65*12+8,width/2,height/2,
                 [frame('Fill',4.6*12+24,.65*12+8,0,0,bg=[69,205,105]),
                  text('Value','100',2,1,4.6*12+20,.65*12+6)],anchor=(.5,.5))
    health['bgTransparency']=1
    health['children'][1]['textXAlignment']='Center'
    nodes.append(health)
    # Match the supplied screenshot's busy green arena without changing the game's world assets.
    nodes.insert(0,dict(type='ImageLabel',name='ArenaStuds',size=[1,0,1,0],bgTransparency=1,
                        icon='rbxassetid://6927295847',scaleType='Tile',tileSize=[0,64,0,64],imageTransparency=.75))
    return dict(pinevex_object=dict(type='Frame',name='CombatHUD',size=[1,0,1,0],bg=[66,196,43],children=nodes),
                viewport_size=[width,height],transparent_background=False)

for name,w,h in [('RunHUD',1920,1080),('RunHUDMobile',390,844),('RunHUDLandscape',844,390),('RunHUDShort',568,320),('RunHUDStandard',1280,720),('RunHUDUltrawide',2560,1080)]:
    Path(__file__).with_name(name+'.json').write_text(json.dumps(design(w,h),indent=2)+'\n')

health_path=Path(__file__).with_name('PlayerHealthBars.json')
health_design=json.loads(health_path.read_text())
for bar in health_design['pinevex_object']['children']:
    if not bar.get('name','').startswith('Bar'):
        continue
    # Existing preview columns represent 60, 40 and 30 projected pixels per stud.
    # Permit deterministic regeneration without compounding the enlarged size.
    column=int(bar['name'].split('_')[-1])
    pixels_per_stud=[60,40,30][column]
    bar['size']=[0,4.6*pixels_per_stud+24,0,.65*pixels_per_stud+8]
    if column==0:
        bar['position'][1]=154
    bar['strokes'][0]['thickness']=bar['size'][3]*.07
    for child in bar['children']:
        if child.get('name')=='Value':
            child['strokes'][0]['thickness']=bar['size'][3]*.9*.055
health_path.write_text(json.dumps(health_design,indent=2)+'\n')
