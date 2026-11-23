import math, os, json, subprocess, shutil
from PIL import Image, ImageDraw, ImageFilter, ImageFont
OUT=os.path.expanduser('design/logo/out'); os.makedirs(OUT,exist_ok=True)
INK='#0E1522'; PAPER='#F2F4F8'; ACC_L='#1F4FD1'; ACC_D='#7DA8FF'
# mark geometry in 100-unit box: two keycaps, overlap = the conflict, filled
A=(12,12,62,62); B=(38,38,88,88); SW=8; R=10; O=(38,38,62,62)
def svg_mark(fg,acc,full=True):
    o=f'<rect x="38" y="38" width="24" height="24" rx="2" fill="{acc if full else fg}"/>'
    return (f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100" fill="none" stroke="{fg}" stroke-width="{SW}" stroke-linejoin="round">'
      f'<rect x="16" y="16" width="42" height="42" rx="{R-4}"/><rect x="42" y="42" width="42" height="42" rx="{R-4}"/>'
      f'<g stroke="none">{o}</g></svg>\n')
for n,s in {'mark.svg':svg_mark(INK,ACC_L),'mark-dark.svg':svg_mark(PAPER,ACC_D),'mark-mono.svg':svg_mark('currentColor','currentColor',False)}.items():
    open(f'{OUT}/{n}','w').write(s)
open(f'{OUT}/lockup.svg','w').write('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 420 100"><g transform="translate(0,0)">'+svg_mark(INK,ACC_L).split('>',1)[1].replace('</svg>','')+'</g><text x="116" y="68" font-family="Satoshi, -apple-system, Helvetica, sans-serif" font-size="56" font-weight="600" letter-spacing="-1.5" fill="'+INK+'">bindcalm</text></svg>\n')
def draw_mark(d,ox,oy,sc,fg,acc,mono=False):
    w=round(SW*sc)
    for x in (16,42):
        d.rounded_rectangle([ox+(x-SW/2)*sc,oy+(x-SW/2)*sc,ox+(x+42+SW/2)*sc,oy+(x+42+SW/2)*sc],radius=(R-4+SW/2)*sc,outline=fg,width=w)
    d.rounded_rectangle([ox+38*sc,oy+38*sc,ox+62*sc,oy+62*sc],radius=2*sc,fill=fg if mono else acc)
def squircle(cx,cy,r,n=5,k=720):
    return [(cx+r*math.copysign(abs(math.cos(t))**(2/n),math.cos(t)),cy+r*math.copysign(abs(math.sin(t))**(2/n),math.sin(t))) for t in [2*math.pi*i/k for i in range(k)]]
def icon(S=1024):
    ss=4; N=S*ss; img=Image.new('RGBA',(N,N),(0,0,0,0))
    body=824/1024*N; c=N/2; cy=c-6/1024*N
    sh=Image.new('RGBA',(N,N),(0,0,0,0)); ImageDraw.Draw(sh).polygon(squircle(c,cy+12/1024*N,body/2),fill=(0,0,0,90))
    sh=sh.filter(ImageFilter.GaussianBlur(14/1024*N)); img.alpha_composite(sh)
    d=ImageDraw.Draw(img); d.polygon(squircle(c,cy,body/2),fill='#141C2B')
    # subtle depth: faint 1px-ish top rim
    rim=Image.new('RGBA',(N,N),(0,0,0,0)); rd=ImageDraw.Draw(rim); rd.polygon(squircle(c,cy,body/2),fill=(255,255,255,14)); rd.polygon(squircle(c,cy+3/1024*N,body/2-1/1024*N),fill=(0,0,0,0))
    img.alpha_composite(rim); d=ImageDraw.Draw(img)
    m=500/1024*N; draw_mark(d,c-m/2,cy-m/2,m/100,PAPER,ACC_D)
    return img.resize((S,S),Image.LANCZOS)
big=icon(1024); big.save(f'{OUT}/icon-1024.png')
iset=f'{OUT}/AppIcon.iconset'; shutil.rmtree(iset,ignore_errors=True); os.makedirs(iset)
for s in (16,32,128,256,512):
    for k in (1,2):
        px=s*k; im=icon(px) if px<=64 else big.resize((px,px),Image.LANCZOS)
        im.save(f'{iset}/icon_{s}x{s}{"@2x" if k==2 else ""}.png')
subprocess.run(['iconutil','-c','icns',iset,'-o',f'{OUT}/AppIcon.icns'],check=True)
for s in (16,32,64,128,256,512): (icon(s) if s<=64 else big.resize((s,s),Image.LANCZOS)).save(f'{OUT}/icon-{s}.png')
# template (black + alpha) for menu bar, 18pt
for k in (1,2):
    S=18*k; ss=8; t=Image.new('RGBA',(S*ss,S*ss),(0,0,0,0)); draw_mark(ImageDraw.Draw(t),0,0,S*ss/100,'black','black',True); t.resize((S,S),Image.LANCZOS).save(f'{OUT}/MenuBarTemplate{"@2x" if k==2 else ""}.png')
# preview
W,H=1600,980; p=Image.new('RGB',(W,H),'#E8EDF4'); d=ImageDraw.Draw(p)
d.rectangle([800,0,W,560],fill='#0F1319')
try: f=ImageFont.truetype('/System/Library/Fonts/SFNS.ttf',96); fs=ImageFont.truetype('/System/Library/Fonts/SFNS.ttf',22)
except: f=fs=ImageFont.load_default()
for x0,bg,fg,acc in ((0,'#E8EDF4',INK,ACC_L),(800,'#0F1319',PAPER,ACC_D)):
    draw_mark(d,x0+60,80,2.6,fg,acc); d.text((x0+340,150),'bindcalm',font=f,fill=fg)
    for i,s in enumerate((16,24,32,48)): draw_mark(d,x0+60+i*90,400,s/100,fg,acc)
    draw_mark(d,x0+460,400,0.48,fg,acc,True); d.text((x0+60,470),'mark 16/24/32/48 · mono',font=fs,fill=fg)
x=60
for s in (512,256,128,64,32,16):
    im=Image.open(f'{OUT}/icon-{s}.png') if s<512 else big.resize((360,360),Image.LANCZOS)
    p.paste(im,(x,590 if s<512 else 590),im); d.text((x,590+(360 if s==512 else s)+10),f'{s}',font=fs,fill=INK); x+=(380 if s==512 else s+40)
p.save(os.path.expanduser('design/logo/out/preview.png'))
tok={'light':{'bg':'#E8EDF4','fg':INK,'muted':'#4B5870','accent':ACC_L,'accent-fg':'#FFFFFF','icon-bg':'#141C2B'},
     'dark':{'bg':'#0F1319','fg':PAPER,'muted':'#A3ACBB','accent':ACC_D,'accent-fg':'#06122B','icon-bg':'#141C2B'}}
def lum(h):
    c=[int(h[i:i+2],16)/255 for i in (1,3,5)]; c=[x/12.92 if x<=.03928 else ((x+.055)/1.055)**2.4 for x in c]; return .2126*c[0]+.7152*c[1]+.0722*c[2]
def cr(a,b): a,b=sorted((lum(a),lum(b)),reverse=True); return round((a+.05)/(b+.05),2)
checks={m:{'fg/bg':cr(t['fg'],t['bg']),'muted/bg':cr(t['muted'],t['bg']),'accent/bg':cr(t['accent'],t['bg']),'accent-fg/accent':cr(t['accent-fg'],t['accent']),'icon fg/icon-bg':cr(PAPER,t['icon-bg']),'icon accent/icon-bg':cr(ACC_D,t['icon-bg'])} for m,t in tok.items()}
json.dump({'tokens':tok,'contrast':checks},open(f'{OUT}/logo-tokens.json','w'),indent=2)
css=':root {\n'+''.join(f'  --bc-logo-{k}: {v};\n' for k,v in tok['light'].items())+'}\n@media (prefers-color-scheme: dark) {\n  :root {\n'+''.join(f'    --bc-logo-{k}: {v};\n' for k,v in tok['dark'].items())+'  }\n}\n'
open(f'{OUT}/logo-tokens.css','w').write(css); print(json.dumps(checks))
