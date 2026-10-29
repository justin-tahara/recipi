"""Builds recipi's app icon from one set of shapes.

Writes the SVG sources and 1024 px PNGs for the iOS 18 light, dark and
tinted icons into this folder. Edit the numbers below, then run:

    python3 -m pip install cairosvg
    python3 design/icon/make_icons.py design/icon
"""
import cairosvg, sys

# The mark is a lowercase "r" drawn as one rounded stroke, with a paprika
# dot after it. All values are in a 1024 x 1024 canvas.
# Stem x, shoulder top y, stem bottom y, stroke width, dot radius, gap.
S,T,B,W,R,gap=350,306,718,120,74,28
E=S+180
cx=E+W/2+gap+R; cy=T+12
def r_svg(bg, ink, dot, rect=True):
    bgel=f'<rect width="1024" height="1024" fill="{bg}"/>' if rect else ''
    return f'''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1024 1024" width="1024" height="1024">
  {bgel}
  <path d="M {S} {B} L {S} {T+170} C {S} {T+60} {S+70} {T} {E} {T}" fill="none" stroke="{ink}" stroke-width="{W}" stroke-linecap="round" stroke-linejoin="round"/>
  <circle cx="{cx:g}" cy="{cy}" r="{R}" fill="{dot}"/>
</svg>
'''
out=sys.argv[1]
variants={
 'recipi-icon': r_svg('#F7F7F5','#37352F','#D96B3B'),
 'recipi-icon-dark': r_svg('none','#E6E5E3','#E8804F',rect=False),
 'recipi-icon-tinted': r_svg('none','#FFFFFF','#A0A0A0',rect=False),
}
for name,svg in variants.items():
    open(f'{out}/{name}.svg','w').write(svg)
    cairosvg.svg2png(bytestring=svg.encode(), write_to=f'{out}/{name}.png', output_width=1024, output_height=1024)
