"""C 몫 필드 소품. Blender -b --factory-startup -P tools/blender/props_field_c.py -- --repo .
독립 생성기: X 가로, Blender -Y 전면 / Z 위 -> glTF +Z 전면 / +Y 위.
GLB에는 메시 하나, primitive 하나, Col 정점색만 둔다.
"""
import sys
sys.dont_write_bytecode = True
import argparse
import collections
import hashlib
import json
import math
import re
import struct
from pathlib import Path
import bmesh
import bpy
from mathutils import Vector

TRIANGLE_LIMIT = 600
PALETTE = {
    "wood": (0.24, 0.17, 0.11, 1.0),
    "worn_wood": (0.38, 0.29, 0.19, 1.0),
    "iron": (0.12, 0.15, 0.17, 1.0),
    "worn_metal": (0.28, 0.32, 0.33, 1.0),
    "cloth": (0.43, 0.41, 0.31, 1.0),
    "enamel": (0.68, 0.70, 0.66, 1.0),
    "snow": (0.84, 0.88, 0.90, 1.0),
    "bark": (0.19, 0.15, 0.12, 1.0),
    "rust": (0.31, 0.16, 0.09, 1.0),
    "glass": (0.24, 0.37, 0.40, 1.0),
    "rubber": (0.045, 0.055, 0.06, 1.0),
    "stone": (0.29, 0.30, 0.28, 1.0),
}
PLACEMENT = ("rect 가운데 바닥. +Y 위, +Z 전면. facing 0~3은 기존 map_view의 "
             "-Y 회전 0/90/180/270도를 따른다. 손잡이를 포함한 원형 AABB가 최빈 발자국 안이다. "
             "현 map_view는 회전만 하며 rect별 축척 보정은 하지 않는다.")

class Piece:
    def __init__(self, pid):
        self.pid = pid
        self.bm = bmesh.new()
        self.col = self.bm.loops.layers.float_color.new("Col")
        self.colours = set()

    def face(self, pts, colour, outward):
        pts = [Vector(p) for p in pts]
        normal = Vector((0, 0, 0))
        for a, b in zip(pts, pts[1:] + pts[:1]):
            normal.x += (a.y - b.y) * (a.z + b.z)
            normal.y += (a.z - b.z) * (a.x + b.x)
            normal.z += (a.x - b.x) * (a.y + b.y)
        if normal.length < 1e-9:
            raise ValueError(self.pid + ": degenerate face")
        if normal.dot(Vector(outward)) < 0:
            pts.reverse()
        face = self.bm.faces.new([self.bm.verts.new(v) for v in pts])
        for loop in face.loops:
            loop[self.col] = PALETTE[colour]
        self.colours.add(colour)

    def box(self, x, y, z, colour):
        x0, x1 = x
        y0, y1 = y
        z0, z1 = z
        assert min(x1-x0, y1-y0, z1-z0) > 0
        for a, n in ((x0, -1), (x1, 1)):
            self.face([(a,y0,z0),(a,y1,z0),(a,y1,z1),(a,y0,z1)], colour, (n,0,0))
        for a, n in ((y0, -1), (y1, 1)):
            self.face([(x0,a,z0),(x1,a,z0),(x1,a,z1),(x0,a,z1)], colour, (0,n,0))
        for a, n in ((z0, -1), (z1, 1)):
            self.face([(x0,y0,a),(x1,y0,a),(x1,y1,a),(x0,y1,a)], colour, (0,0,n))

    def b(self, x, y, z, sx, sy, sz, colour):
        self.box((x-sx/2,x+sx/2),(y-sy/2,y+sy/2),(z,z+sz),colour)

    def beam(self, a, b, r, colour, sides=6, tip=None):
        a, b = Vector(a), Vector(b)
        axis = (b-a).normalized()
        guide = Vector((1,0,0)) if abs(axis.z) > .9 else Vector((0,0,1))
        u = axis.cross(guide).normalized()
        v = axis.cross(u).normalized()
        radial = [u*math.cos(i*math.tau/sides)+v*math.sin(i*math.tau/sides) for i in range(sides)]
        tip = r if tip is None else tip
        lo = [a+d*r for d in radial]
        hi = [b+d*tip for d in radial]
        self.face(lo,colour,-axis)
        self.face(hi,colour,axis)
        for i in range(sides):
            j=(i+1)%sides
            self.face([lo[i],lo[j],hi[j],hi[i]],colour,radial[i]+radial[j])

    def lathe(self, centre, profile, colour, sides=8, alternate=None):
        cx,cy=centre
        rings=[[(cx+rx*math.cos(i*math.tau/sides),cy+ry*math.sin(i*math.tau/sides),z)
                for i in range(sides)] for z,rx,ry in profile]
        self.face(rings[0],colour,(0,0,-1))
        self.face(rings[-1],colour,(0,0,1))
        for low, high in zip(rings,rings[1:]):
            for i in range(sides):
                j=(i+1)%sides
                a=(i+.5)*math.tau/sides
                self.face([low[i],low[j],high[j],high[i]],
                          alternate if alternate and i%3==0 else colour,(math.cos(a),math.sin(a),0))

    def hull(self, rings, colour, cx=0):
        pts=[[(cx+x*rx,cy+y*ry,z) for x,y in ((-1,-1),(1,-1),(1,1),(-1,1))]
             for z,rx,ry,cy in rings]
        self.face(pts[0],colour,(0,0,-1))
        self.face(pts[-1],colour,(0,0,1))
        for lo,hi in zip(pts,pts[1:]):
            for i,n in enumerate(((0,-1,0),(1,0,0),(0,1,0),(-1,0,0))):
                j=(i+1)%4
                self.face([lo[i],lo[j],hi[j],hi[i]],colour,n)

    def fit(self, footprint, height, occupancy=None):
        lo=[min(v.co[i] for v in self.bm.verts) for i in range(3)]
        hi=[max(v.co[i] for v in self.bm.verts) for i in range(3)]
        wh=occupancy or footprint
        target=(wh[0]*.96,wh[1]*.96,height)
        for v in self.bm.verts:
            for i in range(3):
                v.co[i]=((v.co[i]-lo[i])/(hi[i]-lo[i])-(.5 if i<2 else 0))*target[i]
        bmesh.ops.triangulate(self.bm,faces=list(self.bm.faces))
        self.bm.normal_update()
        if any(f.calc_area()<1e-10 for f in self.bm.faces):
            raise ValueError(self.pid+": zero triangle")
        if len(self.bm.faces)>TRIANGLE_LIMIT:
            raise ValueError(self.pid+": triangle budget "+str(len(self.bm.faces)))

    def bounds(self):
        coords=[(v.co.x,v.co.z,-v.co.y) for v in self.bm.verts]
        return [[round(fn(v[i] for v in coords),6)+0.0 for i in range(3)] for fn in (min,max)]


def legs(p, top=.75, colour="wood", spread=.4):
    for x in (-spread,spread):
        for y in (-.35,.35):
            p.b(x,y,0,.065,.07,top,colour)

def snow(p,x,y,z,sx,sy):
    p.b(x,y,z,sx,sy,.025,"snow")

def crate(p,x=0,y=0,z=0,sx=.92,sy=.85,h=.7):
    p.b(x,y,z,sx,sy,h,"wood")
    for i in range(4):
        p.b(x,y-sy/2-.01,z+i*h/4+.015,sx-.04,.025,h/4-.03,"worn_wood")
    for px in (x-sx*.32,x+sx*.32):
        p.b(px,y-sy/2-.03,z,.035,.025,h,"iron")
    p.beam((x-sx*.4,y-sy/2-.05,z+.08),(x+sx*.4,y-sy/2-.05,z+h-.08),.025,"worn_wood",4)

def drum(p,x,y,z,r=.22,h=.72):
    p.lathe((x,y),[(z,r*.85,r*.85),(z+h*.18,r,r),(z+h*.8,r,r),(z+h,r*.86,r*.86)],
            "wood",8,"worn_wood")
    for f in (.18,.76):
        p.lathe((x,y),[(z+h*f,r*1.015,r*1.015),(z+h*(f+.07),r*1.015,r*1.015)],"iron",8)

def wheels(p, ys=(-.33,.34), r=.16, z=.16, colour="rubber"):
    for x in (-.43,.43):
        for y in ys:
            p.beam((x-.07,y,z),(x+.07,y,z),r,colour,8)
            p.beam((x-.075,y,z),(x+.075,y,z),r*.4,"worn_metal",6)

def rails(p, layers=2):
    for y in (-.3,.3):
        p.b(0,y,0,.95,.13,.1,"wood")
    for layer in range(layers):
        for y in (-.26,0,.26):
            z=.11+layer*.18
            p.b(0,y,z,1,.1,.035,"rust")
            p.b(0,y,z+.035,1,.035,.09,"iron")
            p.b(0,y,z+.125,1,.07,.035,"worn_metal")

def circular_saw_bench(p):
    legs(p,.62,"iron")
    p.b(0,0,.62,1,.85,.07,"worn_wood")
    p.b(-.22,.16,.25,.24,.35,.26,"iron")
    p.beam((-.025,0,.68),(.025,0,.68),.24,"worn_metal",16)
    for i in range(8):
        a=i*math.tau/8
        p.b(0,.245*math.cos(a),.68+.245*math.sin(a),.06,.045,.05,"enamel")
    p.b(.26,0,.70,.04,.85,.06,"iron")
    p.b(-.22,-.16,.72,.20,.60,.045,"worn_wood")

def fish_drying_frame(p):
    for x in (-.45,.45):
        for y in (-.35,.35):
            p.beam((x,y,0),(x*.92,0,1),.035,"bark",5)
    for z in (.54,.97):
        p.beam((-.47,0,z),(.47,0,z),.025,"wood",5)
    for i in range(6):
        x=-.36+i*.145
        p.beam((x,0,.96),(x,0,.83),.008,"cloth",4)
        p.lathe((x,0),[(.48,.01,.012),(.62,.05,.03),(.77,.035,.025),(.82,.008,.01)],"worn_metal",4)
        p.face([(x-.045,0,.47),(x+.045,0,.47),(x,0,.54)],"cloth",(0,-1,0))
    snow(p,0,0,1,.9,.06)

def sled_load(p):
    for x in (-.38,.38):
        p.beam((x,.44,.06),(x,-.32,.06),.035,"iron",4)
        p.beam((x,-.32,.06),(x,-.48,.25),.035,"iron",4)
        p.b(x,0,.07,.06,.65,.13,"wood")
    for y in (-.3,-.1,.1,.3):
        p.b(0,y,.2,.84,.14,.05,"worn_wood")
    crate(p,0,.06,.25,.65,.6,.5)
    snow(p,0,.06,.75,.62,.57)

def track_switch(p):
    for x in (-.43,-.2,.04,.28,.46):
        p.b(x,0,0,.07,.9,.08,"wood")
    for y in (-.3,.3):
        p.b(0,y,.08,1,.05,.07,"iron")
    p.beam((-.45,-.25,.16),(.42,.18,.16),.02,"worn_metal",4)
    p.b(.30,.4,.1,.16,.18,.1,"iron")
    p.beam((.3,.4,.2),(.08,.4,.35),.025,"rust",5)
    p.b(.08,.4,.34,.13,.07,.05,"worn_wood")

def cask_stack(p):
    drum(p,-.26,-.2,0,.22,.65)
    drum(p,.26,-.2,0,.22,.65)
    drum(p,0,.25,0,.22,.65)

def generator(p):
    p.b(0,0,0,.94,.87,.11,"iron")
    for x in (-.43,.43):
        for y in (-.36,.36):
            p.b(x,y,.11,.055,.055,.72,"iron")
    for y in (-.36,.36):
        p.b(0,y,.79,.9,.055,.05,"worn_metal")
    p.beam((-.29,0,.38),(.17,0,.38),.24,"worn_metal",8)
    p.b(.27,0,.2,.26,.57,.48,"iron")
    p.b(0,.04,.67,.58,.5,.16,"rust")
    p.b(.27,-.31,.42,.20,.04,.2,"enamel")
    p.beam((.25,-.34,.52),(.25,-.37,.52),.045,"glass",8)

def relief_crate(p):
    crate(p)
    p.b(0,-.46,.38,.32,.015,.18,"enamel")
    snow(p,0,.15,.7,.88,.45)

def slag_heap(p):
    for x,y,r,h in ((0,0,.38,.65),(-.3,-.2,.25,.36),(.32,-.14,.24,.3),(-.13,.30,.27,.42),(.32,.3,.18,.25)):
        p.lathe((x,y),[(0,r,r),(.12,r*.95,r*.9),(h,r*.18,r*.12)],"stone",5,"rust")
    p.lathe((-.04,.03),[(.58,.21,.15),(.65,.07,.06)],"snow",5)

def checkout(p):
    p.b(0,0,0,.95,.8,.7,"wood")
    p.b(0,0,.7,1,.85,.065,"worn_wood")
    p.b(.25,0,.765,.36,.42,.08,"iron")
    p.hull([(.845,.18,.19,.0),(1.0,.18,.10,.07)],"worn_metal",.25)
    p.b(.25,-.22,.86,.22,.03,.08,"enamel")
    p.b(-.23,0,.77,.32,.56,.02,"rubber")

def community_banner(p):
    for x in (-.44,.44):
        p.beam((x,-.48,.03),(x,.48,.03),.024,"wood",6)
    for i in range(5):
        x=-.4+i*.16
        z=.05+(.035 if i%2 else 0)
        p.b(x,0,z,.16,.83,.016,"cloth")
    snow(p,.20,.12,.10,.25,.5)

def conveyor(p):
    for x in (-.4,0,.4):
        p.b(x,0,0,.045,.7,.55,"iron")
    p.b(0,0,.54,1,.66,.09,"rubber")
    for y in (-.38,.38):
        p.b(0,y,.51,1,.05,.15,"worn_metal")
    for i in range(9):
        p.b(-.44+i*.11,0,.64,.025,.62,.02,"rust")
    for x in (-.44,.44):
        p.beam((x,-.37,.57),(x,.37,.57),.06,"iron",8)
    p.b(-.27,.43,.2,.2,.14,.25,"iron")

def ice_block_stack(p):
    for x,y,z in ((-.27,-.24,0),(.24,-.24,0),(-.27,.24,0),(.24,.24,0),(-.03,0,.40)):
        p.hull([(z,.22,.21,y),(z+.36,.20,.20,y)],"glass",x)
        snow(p,x,y,z+.36,.37,.35)

def rack(p, columns, rows, documents=False):
    for x in (-.5,.5):
        p.b(x,0,0,.035,.8,1,"wood")
    p.b(0,.38,0,1,.035,1,"wood")
    for i in range(rows+1):
        p.b(0,0,i/rows,1,.8,.025,"worn_wood")
    for j in range(1,columns):
        p.b(-.5+j/columns,0,0,.025,.76,1,"wood")
    if documents:
        for i in range(rows):
            for j in range(columns):
                p.b(-.5+(j+.5)/columns,.05,i/rows+.03,.72/columns,.47,.08,"enamel")

def mail_sorting_rack(p):
    rack(p,5,3,True)

def plank_bridge(p):
    for x in (-.34,.34):
        p.b(x,0,0,.10,1,.12,"wood")
    for i in range(9):
        y=-.46+i*.115
        p.b(0,y,.12,.94,.09,.06,"worn_wood" if i%3 else "wood")
    snow(p,-.35,.16,.18,.13,.44)

def rail_pile(p):
    rails(p,2)

def stump_cluster(p):
    for x,y,r,h in ((-.3,-.3,.17,.8),(.3,-.2,.15,.6),(0,.25,.22,1)):
        p.lathe((x,y),[(0,r*1.3,r*1.3),(.17,r,r),(h,r*.8,r*.9)],"bark",6,"wood")
        p.lathe((x,y),[(h,r*.78,r*.88),(h+.015,r*.78,r*.88)],"worn_wood",6)
        p.lathe((x,y),[(h+.016,r*.38,r*.4),(h+.025,r*.38,r*.4)],"wood",6)

def wrecked_car_cluster(p):
    for cx,cy in ((-.27,-.1),(.25,.12)):
        p.b(cx,cy,.12,.42,.70,.16,"rust")
        p.hull([(.28,.18,.2,cy),(.48,.14,.14,cy+.03)],"worn_metal",cx)
        p.b(cx,cy-.15,.34,.25,.02,.10,"glass")
        for x in (cx-.21,cx+.21):
            for y in (cy-.24,cy+.24):
                p.beam((x-.025,y,.1),(x+.025,y,.1),.1,"rubber",6)
        snow(p,cx,cy+.05,.49,.25,.23)

def band_saw(p):
    p.b(0,0,0,.82,.7,.1,"iron")
    p.b(.28,.18,.1,.22,.25,.92,"worn_metal")
    for z in (.26,.89):
        p.beam((.04,-.03,z),(.04,.1,z),.20,"iron",10)
        p.beam((.04,-.04,z),(.04,-.06,z),.13,"worn_metal",8)
    p.b(-.17,-.03,.25,.016,.035,.68,"enamel")
    p.b(0,0,.51,.96,.85,.06,"worn_metal")
    p.b(.27,-.31,.44,.16,.10,.05,"rust")

def vehicle_base(p, cab=True):
    wheels(p)
    p.b(0,0,.18,.82,.92,.11,"iron")
    if cab:
        p.b(0,-.29,.29,.78,.36,.35,"worn_metal")
        p.hull([(.64,.39,.18,-.28),(.95,.34,.13,-.25)],"worn_metal")
        p.b(0,-.42,.69,.57,.015,.17,"glass")
        for x in (-.38,.38):
            p.b(x,-.26,.68,.025,.2,.19,"glass")
        p.b(0,-.49,.27,.84,.06,.07,"iron")
        for x in (-.27,.27):
            p.b(x,-.49,.47,.12,.02,.09,"enamel")
        snow(p,0,-.25,.95,.66,.25)

def box_truck(p):
    vehicle_base(p)
    p.b(0,.19,.3,.84,.58,.76,"cloth")
    for x in (-.4,.4):
        p.b(x,.19,.3,.035,.59,.76,"worn_metal")
    p.b(0,.49,.3,.02,.025,.72,"iron")
    snow(p,0,.19,1.06,.80,.54)

def drain_ditch(p):
    p.b(0,0,0,1,.9,.04,"stone")
    for y in (-.4,.4):
        p.b(0,y,.04,1,.1,.15,"stone")
        snow(p,0,y,.19,.94,.09)
    p.b(0,0,.045,.94,.57,.015,"glass")
    for x in (-.44,.44):
        p.b(x,0,.06,.08,.60,.03,"rust")

def flour_sack_pile(p):
    for x,y,z in ((-.23,-.23,0),(.23,-.2,0),(0,.24,0),(0,0,.43)):
        p.lathe((x,y),[(z,.16,.20),(z+.08,.21,.23),(z+.35,.18,.2),(z+.44,.05,.07)],"cloth",6,"enamel")
        p.b(x,y,z+.44,.11,.035,.035,"wood")
        p.b(x,y-.205,z+.13,.15,.012,.13,"enamel")

def lumber_rack(p):
    for x in (-.43,0,.43):
        p.b(x,.30,0,.04,.05,1,"iron")
        for z in (.16,.52,.87):
            p.b(x,0,z,.04,.75,.045,"worn_metal")
    for z in (.2,.56,.91):
        for y in (-.25,0,.25):
            p.b(0,y,z,.97,.19,.055,"wood" if y==0 else "worn_wood")
    snow(p,0,.25,.965,.89,.17)

def market_stall(p):
    legs(p,.55)
    p.b(0,0,.55,1,.83,.06,"worn_wood")
    p.b(0,-.4,.1,.94,.03,.45,"wood")
    for x in (-.44,.44):
        p.b(x,.35,.61,.045,.045,.37,"wood")
    p.beam((-.48,.35,.98),(.48,.35,.98),.06,"cloth",6)
    for x in (-.27,.23):
        p.b(x,0,.61,.35,.4,.06,"wood")
        for y in (-.2,.2):
            p.b(x,y,.67,.35,.025,.15,"worn_wood")

def nave_pillar(p):
    p.b(0,0,0,1,1,.08,"stone")
    p.b(0,0,.08,.79,.79,.09,"worn_metal")
    p.lathe((0,0),[(.17,.30,.30),(.85,.27,.27)],"stone",8,"enamel")
    p.b(0,0,.85,.8,.8,.08,"stone")
    p.b(0,0,.93,1,1,.07,"enamel")

def post_box_row(p):
    for x in (-.36,0,.36):
        p.b(x,0,0,.06,.08,.40,"iron")
        p.b(x,0,.4,.30,.72,.55,"worn_metal")
        p.b(x,-.37,.74,.23,.02,.035,"iron")
        p.b(x,-.37,.47,.24,.025,.19,"cloth")
        snow(p,x,0,.95,.28,.67)

def printing_press(p):
    legs(p,.4,"iron")
    p.b(0,0,.4,.95,.83,.1,"iron")
    for y in (-.15,.15):
        p.beam((-.42,y,.65),(.42,y,.65),.14,"worn_metal",10)
    for x in (-.43,.43):
        p.b(x,0,.5,.06,.55,.43,"iron")
    p.b(0,.20,.85,.83,.25,.05,"worn_metal")
    p.b(0,-.27,.51,.68,.23,.025,"enamel")
    p.beam((.45,0,.67),(.50,0,.67),.25,"iron",10)
    p.beam((.52,0,.67),(.52,.18,.82),.018,"worn_metal",4)

def water_barrel(p):
    p.lathe((0,0),[(0,.38,.38),(.12,.45,.45),(.86,.45,.45),(.94,.40,.40)],"worn_metal",12,"rust")
    p.lathe((0,0),[(.94,.36,.36),(.955,.36,.36)],"glass",12)
    for z in (.18,.75):
        p.lathe((0,0),[(z,.46,.46),(z+.045,.46,.46)],"iron",12)
    p.beam((0,-.41,.2),(0,-.5,.2),.035,"iron",6)

def weigh_platform(p):
    p.b(0,0,0,.98,.88,.13,"iron")
    for i in range(7):
        p.b(-.42+i*.14,0,.13,.12,.84,.035,"worn_metal")
    p.b(.38,.33,.16,.045,.07,.66,"iron")
    p.b(.22,.33,.80,.36,.17,.19,"worn_metal")
    p.b(.22,.235,.84,.27,.02,.11,"enamel")
    p.beam((.08,.21,.88),(.24,.21,.88),.009,"iron",4)

def boat_on_blocks(p):
    for y in (-.3,.3):
        p.b(0,y,0,.8,.12,.15,"wood")
    outer=[(-.35,.42,.55),(.35,.42,.55),(.45,0,.55),(.26,-.34,.55),(0,-.5,.55),(-.26,-.34,.55),(-.45,0,.55)]
    lower=[(x*.62,y*.82,.18) for x,y,z in outer]
    inner=[(x*.84,y*.89,.51) for x,y,z in outer]
    floor=[(x*.55,y*.7,.23) for x,y,z in outer]
    p.face(lower,"wood",(0,0,-1))
    p.face(floor,"worn_wood",(0,0,1))
    for i in range(len(outer)):
        j=(i+1)%len(outer)
        n=(outer[i][0]+outer[j][0],outer[i][1]+outer[j][1],0)
        p.face([lower[i],lower[j],outer[j],outer[i]],"wood",n)
        p.face([outer[i],outer[j],inner[j],inner[i]],"snow",(0,0,1))
        p.face([inner[i],inner[j],floor[j],floor[i]],"worn_wood",(-n[0],-n[1],0))
    for y in (-.20,.18):
        p.b(0,y,.40,.60,.13,.04,"worn_wood")

def forklift(p):
    wheels(p,ys=(-.23,.30),r=.14,z=.14)
    p.b(0,.12,.22,.80,.65,.3,"rust")
    p.b(0,.32,.52,.70,.28,.18,"worn_metal")
    p.b(0,.1,.52,.33,.25,.08,"rubber")
    p.b(0,.23,.60,.34,.06,.21,"rubber")
    for x in (-.33,.33):
        for y in (-.13,.33):
            p.b(x,y,.52,.035,.035,.48,"iron")
    p.b(0,.1,1,.72,.55,.035,"iron")
    for x in (-.23,.23):
        p.b(x,-.31,.08,.045,.06,.95,"worn_metal")
        p.b(x,-.49,.08,.07,.41,.04,"worn_metal")
    p.b(0,-.31,.23,.52,.08,.07,"iron")

def jib_crane(p):
    p.b(0,.22,0,.65,.55,.10,"stone")
    p.beam((0,.22,.1),(0,.22,1),.07,"iron",8)
    p.beam((0,.22,.95),(0,-.45,.95),.045,"worn_metal",4)
    p.beam((0,.22,.61),(0,-.40,.94),.025,"rust",4)
    p.beam((0,-.42,.94),(0,-.42,.44),.009,"iron",5)
    p.beam((0,-.42,.44),(.08,-.42,.39),.02,"iron",5)
    p.beam((.08,-.42,.39),(.12,-.42,.44),.02,"iron",5)
    p.b(0,.24,.26,.30,.22,.16,"worn_metal")

def log_truck(p):
    vehicle_base(p)
    p.b(0,.19,.31,.84,.58,.06,"wood")
    for x in (-.39,.39):
        for y in (.02,.43):
            p.b(x,y,.36,.03,.035,.55,"iron")
    for x,z in ((-.25,.49),(0,.49),(.25,.49),(-.13,.72),(.13,.72)):
        p.beam((x,-.02,z),(x,.46,z),.115,"bark",8)
        p.face([(x+.085*math.cos(i*math.tau/8),-.03,z+.085*math.sin(i*math.tau/8))
                for i in range(8)],"worn_wood",(0,-1,0))
    snow(p,0,.20,.84,.32,.43)

def ore_cart(p):
    wheels(p,ys=(-.28,.28),r=.12,z=.12,colour="iron")
    p.b(0,0,.18,.86,.76,.08,"iron")
    p.hull([(.26,.29,.29,0),(.78,.46,.43,0)],"rust")
    p.b(0,0,.785,.78,.7,.025,"stone")
    for x,y in ((-.19,-.18),(.2,.13),(-.15,.17)):
        p.lathe((x,y),[(.81,.16,.14),(.98,.04,.03)],"stone",5)
    for y in (-.47,.47):
        p.b(0,y,.34,.13,.1,.08,"iron")

def pit_props(p):
    for x in (-.26,0,.26):
        p.beam((x,-.45,.14),(x,.45,.14),.11,"bark",7)
    for x in (-.13,.13):
        p.beam((x,-.43,.34),(x,.43,.34),.11,"wood",7)
    p.b(0,0,.45,.72,.13,.07,"worn_wood")
    for y in (-.3,.3):
        p.b(0,y,0,.9,.12,.05,"iron")

def coal_sorter(p):
    legs(p,.6,"iron")
    p.hull([(.25,.23,.28,0),(.65,.46,.43,0)],"worn_metal")
    p.b(0,0,.66,.84,.76,.03,"iron")
    for i in range(7):
        p.b(-.36+i*.12,0,.70,.035,.71,.035,"rust")
    p.b(0,.30,.74,.8,.13,.25,"iron")
    p.beam((-.36,.28,.75),(.35,.28,.75),.09,"worn_metal",8)
    p.b(0,-.33,.12,.28,.4,.06,"worn_metal")

def farm_tractor(p):
    for x in (-.39,.39):
        for y,r in ((.25,.24),(-.34,.15)):
            p.beam((x-.08,y,r),(x+.08,y,r),r,"rubber",10)
            p.beam((x-.085,y,r),(x+.085,y,r),r*.5,"rust",8)
    p.b(0,0,.22,.65,.87,.12,"iron")
    p.b(0,-.23,.34,.5,.48,.38,"worn_metal")
    p.b(0,-.48,.40,.40,.02,.22,"iron")
    for x in (-.38,.38):
        p.b(x,.25,.51,.24,.49,.045,"rust")
    p.b(0,.25,.47,.31,.25,.07,"rubber")
    p.b(0,.37,.54,.3,.04,.2,"rubber")
    p.beam((.13,-.15,.68),(.13,-.15,.97),.022,"iron",6)
    snow(p,0,-.25,.72,.43,.35)

def generator_unit(p):
    p.b(0,0,0,.97,.87,.12,"iron")
    p.b(0,0,.12,.83,.76,.62,"cloth")
    for i in range(6):
        p.b(-.27+i*.10,-.39,.30,.045,.025,.28,"iron")
    p.b(.21,-.41,.61,.27,.03,.09,"enamel")
    for x in (-.35,.35):
        p.beam((x,-.22,.75),(x,.24,.75),.025,"iron",5)
    p.beam((-.21,.21,.75),(-.21,.21,.92),.04,"iron",6)
    snow(p,.09,0,.75,.45,.55)

def hopper(p):
    for x in (-.35,.35):
        for y in (-.35,.35):
            p.b(x,y,0,.045,.045,.64,"iron")
    p.hull([(.26,.12,.12,0),(.66,.46,.46,0),(.96,.46,.46,0)],"rust")
    p.b(0,0,.97,.82,.82,.025,"stone")
    p.b(0,0,.17,.27,.3,.09,"iron")
    for y in (-.47,.47):
        p.b(0,y,.64,.95,.04,.05,"worn_metal")

def mine_portal(p):
    for x in (-.40,.40):
        p.b(x,0,0,.17,.84,.88,"bark")
        p.b(x,-.44,.1,.19,.04,.12,"iron")
    p.b(0,0,.86,1,.88,.14,"worn_wood")
    for x in (-.34,.34):
        p.beam((x,-.41,.65),(x*.55,-.41,.87),.045,"wood",4)
    snow(p,0,0,1,.95,.8)

def rail_stack(p):
    rails(p,3)

SPECS = {
    "circular_saw_bench": (1.20,"제재용 원형톱·톱니·가이드·작업대를 1.20m low로 구성"),
    "fish_drying_frame": (1.25,"생선 여섯 마리를 낮은 A형 건조 틀에 걸어 low 높이 유지"),
    "sled_load": (1.10,"눈 덮인 자재 상자만 실은 썰매; 소지품 더미 없음"),
    "track_switch": (.35,"침목·분기 레일·낮은 전환 레버로 none 바닥 높이 유지"),
    "cask_stack": (.48,"none 우세에 맞춰 작은 저장 통 셋을 한 층으로 낮게 배치"),
    "generator": (1.10,"개방 프레임의 발전기·연료통·계기, 배기 연기 없음"),
    "relief_crate": (.48,"none 우세의 낮은 보급 상자; 빈 명판만 두고 표지 없음"),
    "slag_heap": (.95,"광산 찌꺼기 돌덩이 다섯 무리와 부분 적설, low"),
    "checkout": (1.10,"계산대 위 기계식 금전등록기와 계산 받침, low"),
    "community_banner": (.18,"none에 맞춰 내려놓은 무문자 천 현수막과 양 끝 봉"),
    "conveyor": (1.00,"낮은 광산 벨트 운반기·롤러·가로 돌기, low"),
    "ice_block_stack": (1.10,"얼음 다섯 블록에 눈 모서리; 불투명 정점색만 사용"),
    "mail_sorting_rack": (1.20,"우편 분류 15칸과 종이; low 우세 기준의 낮은 선반"),
    "plank_bridge": (.24,"보 두 줄 위 널판 아홉 장의 평평한 작은 다리, none"),
    "rail_pile": (.60,"폐레일 여섯 개를 두 층으로 쌓아 low 유지"),
    "stump_cluster": (.48,"none 기준의 낮게 잘린 그루터기 세 개와 나이테"),
    "wrecked_car_cluster": (1.20,"찌그러진 폐차 두 대의 껍데기·바퀴·눈; 소지품 없음"),
    "band_saw": (1.30,"두 바퀴·수직 띠톱·작업판을 갖춘 소형 제재기, low 상한"),
    "box_truck": (2.40,"상자형 적재함의 의미와 wall 혼용을 우선해 low 높이 예외"),
    "drain_ditch": (.20,"낮은 돌 가장자리와 바닥의 배수로 단면, none"),
    "flour_sack_pile": (1.00,"밀가루 저장 자루 네 개와 빈 품목표; 개인 소지품 아님"),
    "lumber_rack": (1.25,"세 단 자재 받침에 긴 판재 아홉 장, low 우세"),
    "market_stall": (1.25,"낮은 판매대·빈 상품함·접힌 차양으로 low 유지"),
    "nave_pillar": (3.20,"교회 신랑의 각진 주초·기둥·주두로 wall 의미 유지"),
    "post_box_row": (1.25,"투입구와 작은 문이 있는 우편함 세 개, low 우세"),
    "printing_press": (1.15,"인쇄 롤러·손바퀴·급지판의 의미 우선, none 높이 예외"),
    "water_barrel": (1.15,"쇠 테와 수도꼭지·수면이 있는 낮은 물통, low"),
    "weigh_platform": (1.20,"낮은 계량판과 옆 계기 지주를 함께 포함, low 우세"),
    "boat_on_blocks": (1.20,"받침목 위 열린 작은 목선; 선실·문·사람 없음"),
    "forklift": (2.00,"포크·마스트·운전석 보호틀의 의미와 wall 혼용 우선, low 예외"),
    "jib_crane": (2.80,"수직 기둥·돌출 붐·가는 인양선과 갈고리의 wall 크레인"),
    "log_truck": (2.40,"통나무 적재대·운전석의 의미 우선, low 높이 예외"),
    "ore_cart": (1.20,"광석을 실은 경사 측벽 광차와 철제 바퀴, low"),
    "pit_props": (.85,"갱도용 받침 통나무를 눕혀 보관한 자재 묶음, low"),
    "coal_sorter": (2.10,"체살·드럼·받침 다리로 된 석탄 선별기, wall"),
    "farm_tractor": (1.30,"큰 뒷바퀴와 작은 앞바퀴의 무선실 소형 트랙터, low"),
    "generator_unit": (1.15,"통풍구 달린 덮개식 발전기; 개방 프레임 generator와 구분"),
    "hopper": (2.30,"좁은 배출구와 넓은 상부 투입함의 광석 호퍼, wall"),
    "mine_portal": (2.60,"열린 갱구의 기둥·상인방 의미를 우선, none 높이 예외"),
    "rail_stack": (.75,"레일 아홉 개를 세 층으로 정돈한 야적, low"),
}

def census(repo, names):
    found={name:[] for name in names}
    map_counts={}
    paths=sorted((repo/"s2/game/world/maps").glob("*.gd"))
    for path in paths:
        source=path.read_text(encoding="utf-8-sig")
        counts=collections.Counter()
        for match in re.finditer(r"\{[^{}]*\}",source,re.S):
            block=match.group()
            kind=re.search(r'"kind"\s*:\s*"([^"]+)"',block)
            rect=re.search(r'"rect"\s*:\s*(?:\[\s*|Rect2i\(\s*)(-?\d+)\s*,\s*(-?\d+)\s*,\s*(\d+)\s*,\s*(\d+)\s*[\]\)]',block)
            if not kind or not rect or kind[1] not in found:
                continue
            k=kind[1]
            note=re.search(r'"(?:note|name)"\s*:\s*"([^"]*)"',block)
            found[k].append({"map":path.stem,"wh":[int(rect[3]),int(rect[4])],
                             "note":note[1] if note else ""})
            counts[k]+=1
        for m in re.finditer(r'\[\s*-?\d+\s*,\s*-?\d+\s*,\s*(\d+)\s*,\s*(\d+)\s*,\s*"([^"]+)"\s*,\s*"(?:low|none|wall)"[^\]]*\]',source):
            if m[3] in found:
                found[m[3]].append({"map":path.stem,"wh":[int(m[1]),int(m[2])],"note":""})
                counts[m[3]]+=1
        map_counts[path.stem]=dict(counts)
    return found,map_counts,len(paths)

def export_glb(p,path):
    mesh=bpy.data.meshes.new(p.pid)
    obj=None
    try:
        p.bm.to_mesh(mesh)
        mesh.color_attributes.active_color=mesh.color_attributes["Col"]
        mesh.color_attributes.render_color_index=0
        obj=bpy.data.objects.new(p.pid,mesh)
        bpy.context.scene.collection.objects.link(obj)
        bpy.ops.object.select_all(action="DESELECT")
        obj.select_set(True)
        bpy.context.view_layer.objects.active=obj
        bpy.ops.export_scene.gltf(filepath=str(path),export_format="GLB",use_selection=True,
            export_yup=True,export_apply=False,export_materials="NONE",export_texcoords=False,
            export_normals=True,export_tangents=False,export_vertex_color="ACTIVE",
            export_extras=False,export_animations=False,export_cameras=False,export_lights=False)
    finally:
        if obj:
            bpy.data.objects.remove(obj,do_unlink=True)
        bpy.data.meshes.remove(mesh)

def check_glb(path,expected_tris):
    data=path.read_bytes()
    magic,version,length=struct.unpack_from("<4sII",data)
    size,tag=struct.unpack_from("<II",data,12)
    assert (magic,version,length,tag)==(b"glTF",2,len(data),0x4E4F534A)
    book=json.loads(data[20:20+size])
    assert len(book["meshes"])==1
    assert sum("mesh" in node for node in book["nodes"])==1
    primitives=book["meshes"][0]["primitives"]
    assert len(primitives)==1
    prim=primitives[0]
    assert prim.get("mode",4)==4 and "COLOR_0" in prim["attributes"]
    count=book["accessors"][prim["indices"]]["count"]
    assert count%3==0 and count//3==expected_tris<=TRIANGLE_LIMIT
    assert not any(book.get(k) for k in ("materials","images","textures","animations","skins","cameras"))
    assert not book.get("extensions",{}).get("KHR_lights_punctual")
    assert all("uri" not in b for b in book["buffers"])
    return len(data),hashlib.sha256(data).hexdigest()

def write_books(repo,source,assets,counts,map_files):
    totals={m:sum(n*assets[k]["lod0_tris"] for k,n in row.items()) for m,row in counts.items()}
    largest=max(totals,key=totals.get)
    book={"version":1,"generator":"tools/blender/props_field_c.py","triangle_limit":600,
          "palette":PALETTE,"axis":"+Y up, +Z front","origin":"footprint centre floor",
          "placement":PLACEMENT,"input":"_in/kinds_c.json","input_sha256":hashlib.sha256((repo/"_in/kinds_c.json").read_bytes()).hexdigest(),
          "assets":assets,"skipped":{x["kind"]:"지형성 skip_ground_like: 발주 제외" for x in source["skip_ground_like"]},
          "census":{"files":map_files,"measure":"지도 원문의 literal rect; 런타임 생성/가시성 제외",
                    "counts":counts,"triangles_per_map":totals,"maximum":{"map":largest,"triangles":totals[largest],"counts":counts[largest]}},
          "failures":[]}
    out=repo/"s2/models/props_field"
    (out/"catalog_c.json").write_text(json.dumps(book,ensure_ascii=False,indent=2)+"\n",encoding="utf-8")
    table=["| 이름 | 수 | 발자국 m | 높이 m | solid | 삼각형 | 바이트 | 판단 한 줄 |",
           "|---|---:|---|---:|---|---:|---:|---|"]
    for k,a in assets.items():
        wh="×".join(str(v) for v in a["footprint_m"])
        solid=", ".join(f"{s}:{n}" for s,n in a["solid"].items())
        table.append(f'| {k} | {a["count"]} | {wh} | {a["height_m"]} | {solid} | {a["lod0_tris"]} | {a["bytes"]} | {a["judgment"]} |')
    table.append(f'| 합계 | {sum(a["count"] for a in assets.values())} | 40종 | — | — | {sum(a["lod0_tris"] for a in assets.values())} | {sum(a["bytes"] for a in assets.values())} | 고유 자산 합계 |')
    lines=["# 필드 소품 C","", "독립 생성 장부. tools/blender/props_field_c.py로 재생성한다.","",PLACEMENT,"",
           "메시·면 묶음 각 하나, 삼각형 ≤600, 정점색 Col. 재질·그림·빛·애니메이션 없음.",""]+table
    lines+=["","## SHA-256","", "| 이름 | sha256 |","|---|---|"]
    lines += [f'| {k} | {a["sha256"]} |' for k,a in assets.items()]
    lines+=["","## 팔레트","", "선형 RGBA. 앞 6색은 공용 팔레트 그대로이며 뒤 6색만 추가했다.",""]
    lines += [f"- {k}: {v}" for k,v in PALETTE.items()]
    lines+=["","## 지도 비용","",f"C 40종의 지도 한 장 최대 소품 삼각형 합: **{largest} / {totals[largest]:,}개**.",
            "지도 원문마다 종류별 수 × 실제 삼각형을 합했다. 다른 발주의 자산·건물·인물·런타임 추가 배치는 포함하지 않는다.",
            "", "## 제외",""]+[f"- {k}: {reason}" for k,reason in book["skipped"].items()]
    (out/"README_c.md").write_text("\n".join(lines)+"\n",encoding="utf-8")
    print("C_COMPLETE kinds=40 placements=491 max_map="+json.dumps(book["census"]["maximum"],ensure_ascii=False),flush=True)

def preview(repo):
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    for idx,k in enumerate(SPECS):
        bpy.ops.import_scene.gltf(filepath=str(repo/"s2/models/props_field"/(k+".glb")))
        objects=list(bpy.context.selected_objects)
        meshes=[o for o in objects if o.type=="MESH"]
        if not meshes:
            continue
        obj=meshes[0]
        bpy.context.view_layer.update()
        scale=2.4/max(obj.dimensions)
        for o in objects:
            o.scale*=scale
            o.location=Vector(((idx%5)*4.2,-(idx//5)*4.2,0))
        font=bpy.data.curves.new("caption","FONT")
        font.body=k
        font.align_x="CENTER"
        font.size=.20
        label=bpy.data.objects.new("caption",font)
        bpy.context.scene.collection.objects.link(label)
        label.location=((idx%5)*4.2,-(idx//5)*4.2-1.6,.01)
    scene=bpy.context.scene
    camera_data=bpy.data.cameras.new("inspection")
    camera=bpy.data.objects.new("inspection",camera_data)
    scene.collection.objects.link(camera)
    target=Vector((8.4,-14.7,0))
    camera.location=target+Vector((0,-24,40))
    camera.rotation_euler=(target-camera.location).to_track_quat("-Z","Y").to_euler()
    camera_data.type="ORTHO"
    camera_data.ortho_scale=38
    scene.camera=camera
    scene.render.engine="BLENDER_WORKBENCH"
    scene.display.shading.light="STUDIO"
    scene.display.shading.color_type="VERTEX"
    scene.display.shading.show_shadows=True
    scene.display.shading.show_cavity=True
    scene.display.shading.cavity_type="BOTH"
    scene.display.shading.background_type="WORLD"
    scene.world.color=(.11,.12,.14)
    scene.render.resolution_x=1600
    scene.render.resolution_y=2200
    scene.render.resolution_percentage=100
    scene.render.image_settings.file_format="PNG"
    scene.render.filepath=str(repo/"s2/.godot/props_c_preview.png")
    bpy.ops.render.render(write_still=True)

def main():
    args=argparse.ArgumentParser()
    args.add_argument("--repo",default=".")
    args.add_argument("--preview",action="store_true")
    opt=args.parse_args(sys.argv[sys.argv.index("--")+1:] if "--" in sys.argv else [])
    repo=Path(opt.repo).resolve()
    if opt.preview:
        preview(repo)
        return
    source=json.loads((repo/"_in/kinds_c.json").read_text(encoding="utf-8-sig"))
    assert {r["kind"] for r in source["kinds"]}==set(SPECS) and len(SPECS)==40
    assert sum(r["count"] for r in source["kinds"])==491
    found,counts,map_files=census(repo,set(SPECS))
    out=repo/"s2/models/props_field"
    out.mkdir(parents=True,exist_ok=True)
    assets={}
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    for row in source["kinds"]:
        k=row["kind"]
        observations=found[k]
        if len(observations)!=row["count"]:
            raise ValueError(f'{k}: census {len(observations)} != input {row["count"]}')
        common=collections.Counter(tuple(o["wh"]) for o in observations).most_common()
        footprint=tuple(row["rects_wh_top"][0][0]) if row["rects_wh_top"] else common[0][0]
        height,judgment=SPECS[k]
        p=Piece(k)
        try:
            globals()[k](p)
            occupancy=None
            if k in ("box_truck","log_truck","farm_tractor","boat_on_blocks"):
                occupancy=(min(footprint[0],footprint[1]*.65),footprint[1])
                judgment+="; +Z 전면과 짧은 깊이를 지키는 압축 비례"
            p.fit(footprint,height,occupancy)
            path=out/(k+".glb")
            export_glb(p,path)
            size,sha=check_glb(path,len(p.bm.faces))
            assets[k]={"path":"res://models/props_field/"+k+".glb","status":"ready","count":row["count"],
                "footprint_m":footprint,"footprint_source":"_in/kinds_c.json rects_wh_top" if row["rects_wh_top"] else "지도 Rect2i 원문 최빈값",
                "modal_count":dict(common)[footprint],"height_m":height,"solid":row["solid"],"facing":row["facing"],
                "lod0_tris":len(p.bm.faces),"triangle_limit":600,"bytes":size,"sha256":sha,
                "bounds_godot":p.bounds(),"colours":sorted(p.colours),"judgment":judgment,"placement":PLACEMENT,
                "map_families":row["map_families"],"example_notes":list(dict.fromkeys(o["note"] for o in observations if o["note"]))[:3]}
            print(f'C_EXPORT {k} tris={len(p.bm.faces)} bytes={size} footprint={footprint} height={height}',flush=True)
        finally:
            p.bm.free()
    write_books(repo,source,assets,counts,map_files)

if __name__=="__main__":
    main()
