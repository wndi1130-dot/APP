"""지도 소품 B: 독립 제작기. 외부 자료/재질/그림 없이 Col 정점색으로 만든다.

blender -b --factory-startup -P tools/blender/props_field_b.py -- --repo .
--preview: 이미 만든 GLB를 다시 열어 캐시에 검토용 접촉 인화만 만든다.
Blender X=가로, -Y=앞, Z=위. 내보낸 GLB는 X=가로, +Z=앞, +Y=위.
"""
import sys
sys.dont_write_bytecode = True
import argparse
import collections
import hashlib
import json
import math
from pathlib import Path
import re
import struct
import bmesh
import bpy
from mathutils import Vector

TRIANGLE_LIMIT = 600
# 선형 RGBA: 앞의 여섯 색은 props_common.py와 동일하다.
PALETTE = {
    "wood": (0.24, 0.17, 0.11, 1.0),
    "worn_wood": (0.38, 0.29, 0.19, 1.0),
    "iron": (0.12, 0.15, 0.17, 1.0),
    "worn_metal": (0.28, 0.32, 0.33, 1.0),
    "cloth": (0.43, 0.41, 0.31, 1.0),
    "enamel": (0.68, 0.70, 0.66, 1.0),
    "snow": (0.82, 0.88, 0.91, 1.0),
    "bark": (0.20, 0.16, 0.13, 1.0),
    "rust": (0.32, 0.16, 0.09, 1.0),
    "glass": (0.19, 0.33, 0.38, 1.0),
    "rubber": (0.035, 0.045, 0.05, 1.0),
    "stone": (0.35, 0.37, 0.39, 1.0),
}
SKIPPED = {"unload": "지도 spots의 하역 상호작용 지점이며 소품 rect가 없음. 물체나 하역 경사로를 새로 만들지 않음."}
PLACEMENT = "rect 가운데 바닥. +Y 위, +Z 앞. facing은 +Y 둘레 시계 방향 0/90/180/270도. 현 map_view는 크기를 보정하지 않음."


class Piece:
    def __init__(self, name):
        self.name = name
        self.bm = bmesh.new()
        self.col = self.bm.loops.layers.float_color.new("Col")
        self.colours = set()

    def face(self, pts, colour, outward):
        pts = [Vector(p) for p in pts]
        normal = Vector()
        for a, b in zip(pts, pts[1:] + pts[:1]):
            normal += a.cross(b)
        if normal.length < 1e-9:
            raise ValueError("면 넓이 0: " + self.name)
        if normal.dot(Vector(outward)) < 0:
            pts.reverse()
        face = self.bm.faces.new([self.bm.verts.new(p) for p in pts])
        for loop in face.loops:
            loop[self.col] = PALETTE[colour]
        self.colours.add(colour)

    def box(self, x, y, z, colour="wood"):
        x0, x1 = x
        y0, y1 = y
        z0, z1 = z
        assert min(x1-x0, y1-y0, z1-z0) > 0
        for a, s in ((x0, -1), (x1, 1)):
            self.face([(a,y0,z0),(a,y1,z0),(a,y1,z1),(a,y0,z1)],colour,(s,0,0))
        for a, s in ((y0, -1), (y1, 1)):
            self.face([(x0,a,z0),(x1,a,z0),(x1,a,z1),(x0,a,z1)],colour,(0,s,0))
        for a, s in ((z0, -1), (z1, 1)):
            self.face([(x0,y0,a),(x1,y0,a),(x1,y1,a),(x0,y1,a)],colour,(0,0,s))

    def beam(self, start, end, radius, colour="wood", sides=6, tip=None, caps=None):
        a, b = Vector(start), Vector(end)
        axis = (b-a).normalized()
        guide = Vector((1,0,0)) if abs(axis.z) > .9 else Vector((0,0,1))
        u = axis.cross(guide).normalized()
        v = axis.cross(u).normalized()
        dirs = [u*math.cos(i*math.tau/sides)+v*math.sin(i*math.tau/sides) for i in range(sides)]
        tip = radius if tip is None else tip
        lo = [a+d*radius for d in dirs]
        hi = [b+d*tip for d in dirs]
        self.face(lo,caps or colour,-axis)
        self.face(hi,caps or colour,axis)
        for i in range(sides):
            j = (i+1) % sides
            self.face([lo[i],lo[j],hi[j],hi[i]],colour,dirs[i]+dirs[j])

    def lump(self, x, y, z, rx, ry, h, colour="stone", sides=5):
        rings = [[(x+rx*r*math.cos(i*math.tau/sides),y+ry*r*math.sin(i*math.tau/sides),z+dz)
                  for i in range(sides)] for dz,r in ((0,.72),(h*.55,1),(h,.25))]
        self.face(rings[0],colour,(0,0,-1))
        self.face(rings[-1],colour,(0,0,1))
        for lo,hi in zip(rings,rings[1:]):
            for i in range(sides):
                j=(i+1)%sides
                a=(i+.5)*math.tau/sides
                self.face([lo[i],lo[j],hi[j],hi[i]],colour,(math.cos(a),math.sin(a),.25))

    def fit(self, footprint, height):
        lo=[min(v.co[i] for v in self.bm.verts) for i in range(3)]
        hi=[max(v.co[i] for v in self.bm.verts) for i in range(3)]
        for vert in self.bm.verts:
            for i,extent in enumerate((*footprint,height)):
                vert.co[i]=((vert.co[i]-lo[i])/(hi[i]-lo[i])-(.5 if i<2 else 0))*extent
        bmesh.ops.triangulate(self.bm,faces=list(self.bm.faces))
        self.bm.normal_update()
        if any(f.calc_area()<1e-10 for f in self.bm.faces):
            raise ValueError("퇴화 삼각형: "+self.name)


def snow(p,x=(-.45,.45),y=(-.4,.4),z=.9,t=.035):
    p.box(x,y,(z,z+t),"snow")


def frame(p, height=1, depth=.42, shelves=(.08,)):
    for x in (-.48,.44):
        for y in (-depth,depth-.04):
            p.box((x,x+.04),(y,y+.04),(0,height),"worn_wood")
    for z in shelves:
        p.box((-.48,.48),(-depth,depth),(z,z+.045),"wood")


def chest(p, medical=False):
    p.box((-.48,.48),(-.44,.44),(.04,.84),"enamel" if medical else "wood")
    p.box((-.5,.5),(-.46,.46),(.84,.94),"worn_wood")
    for x in (-.32,.28):
        p.box((x,x+.045),(-.47,.47),(.82,.96),"iron")
    p.box((-.09,.09),(-.46,-.445),(.5,.65),"worn_metal")
    if medical:
        p.box((-.24,.24),(-.463,-.448),(.25,.42),"cloth")
    else:
        p.box((-.30,.14),(-.30,.12),(.95,.975),"cloth")
        p.box((-.25,.12),(-.28,.10),(.976,.99),"enamel")


def power_pole(p):
    p.beam((0,0,0),(0,0,1),.12,"bark",8,tip=.075)
    p.box((-.5,.5),(-.1,.1),(.82,.86),"worn_wood")
    for x in (-.4,0,.4):
        p.beam((x,0,.85),(x,0,.94),.07,"enamel",6)
    p.box((-.17,.17),(-.16,.16),(.02,.18),"iron")
    snow(p,(-.48,.48),(-.09,.09),.86,.015)


def sleeper_stack(p):
    for layer in range(3):
        for y in (-.33,0,.33):
            p.box((-.5+layer*.02,.48-layer*.01),(y-.13,y+.13),(layer*.25,layer*.25+.21),"wood" if layer%2 else "bark")
    for y in (-.33,0,.33):
        snow(p,(-.42,.4),(y-.10,y+.10),.71)


def reel(p, hose=False):
    # 축은 X: 양 플랜지와 감긴 케이블/호스가 옆에서 읽힌다.
    p.beam((-.3,0,.5),(.3,0,.5),.32,"rubber",12)
    for x in (-.43,.35):
        p.beam((x,0,.5),(x+.08,0,.5),.48,"worn_metal" if hose else "worn_wood",12)
        p.beam((x-.008,0,.5),(x+.09,0,.5),.10,"iron",6)
    if hose:
        for x in (-.35,.35):
            p.beam((x,0,.5),(x,-.36,0),.035,"iron",4)
            p.beam((x,0,.5),(x,.36,0),.035,"iron",4)
        p.beam((-.3,-.31,.48),(.18,-.48,.04),.04,"rubber",6)
        p.beam((.18,-.48,.04),(.48,-.48,.04),.05,"worn_metal",6)
    else:
        p.box((-.5,.5),(-.4,.4),(0,.06),"wood")
        snow(p,(-.25,.25),(-.13,.13),.82)


def spruce(p):
    p.beam((0,0,0),(0,0,.95),.075,"bark",6,tip=.025)
    for z,r,h in ((.15,.49,.42),(.40,.37,.38),(.64,.25,.36)):
        p.beam((0,0,z),(0,0,z+h),r,"iron",8,tip=.015)
        p.beam((0,0,z+.11),(0,0,z+h+.015),r*.78,"snow",8,tip=.01)


def cloth_bolt_rack(p):
    frame(p, .95, .43, (.05,.49))
    for z in (.25,.7):
        for x in (-.3,0,.3):
            p.beam((x,-.39,z),(x,.36,z),.12,"cloth" if x else "enamel",8,caps="worn_wood")


def wagon(p, coal=False, engine=False):
    p.box((-.48,.48),(-.42,.42),(.23,.32),"iron")
    for x in (-.34,.34):
        for dx in (-.06,.06):
            p.beam((x+dx,-.5,.16),(x+dx,-.42,.16),.14,"rubber",8)
            p.beam((x+dx,.42,.16),(x+dx,.5,.16),.14,"rubber",8)
    p.box((-.5,.5),(-.38,.38),(.32,.38),"worn_wood")
    if coal:
        for y in (-.42,.38):
            p.box((-.49,.49),(y,y+.04),(.37,.8),"rust")
        for x in (-.49,.45):
            p.box((x,x+.04),(-.38,.38),(.37,.8),"iron")
        for x in (-.32,0,.32):
            p.lump(x,0,.40,.21,.34,.43,"rubber",5)
        snow(p,(-.42,.4),(.38,.42),.8,.025)
    elif engine:
        p.box((-.42,.18),(-.32,.32),(.38,.69),"iron")
        p.box((.12,.42),(-.36,.36),(.38,.9),"worn_metal")
        p.box((.17,.35),(-.368,-.36),(.69,.83),"glass")
        p.box((.17,.35),(.36,.368),(.69,.83),"glass")
        p.box((.421,.43),(-.24,.24),(.69,.83),"glass")
        for x in (-.34,-.25,-.16):
            p.box((x,x+.03),(-.325,-.32),(.43,.61),"rubber")
        snow(p,(.1,.44),(-.38,.38),.9,.03)
        snow(p,(-.4,.08),(-.28,.28),.69,.02)
    else:
        for x in (-.4,-.2,0,.2,.4):
            p.box((x-.003,x+.003),(-.37,.37),(.38,.385),"bark")
        snow(p,(-.42,.18),(-.31,.27),.385,.015)


def loom(p):
    frame(p,.92,.44,(.11,))
    for y,z in ((-.32,.68),(.32,.8)):
        p.beam((-.43,y,z),(.43,y,z),.075,"worn_wood",8)
    p.box((-.32,.32),(-.32,.32),(.69,.71),"cloth")
    for x in (-.28,-.14,0,.14,.28):
        p.beam((x,-.31,.72),(x,.32,.82),.009,"enamel",4)
    p.box((-.37,.37),(.04,.08),(.74,.97),"wood")
    p.box((-.3,.3),(-.18,-.08),(.03,.065),"worn_wood")


def logs(p, mode="stack"):
    if mode=="scatter":
        for a,b,r in (((-.4,-.32,.11),(.26,-.2,.11),.11),((-.16,.12,.1),(.48,.27,.1),.1),((-.44,.42,.1),(.12,.32,.1),.09)):
            p.beam(a,b,r,"bark",7,caps="worn_wood")
    elif mode=="fallen":
        p.beam((-.49,0,.26),(.49,0,.26),.24,"bark",9,caps="worn_wood")
        p.beam((-.04,0,.32),(.12,.44,.52),.07,"bark",5,tip=.025,caps="worn_wood")
        snow(p,(-.41,.3),(-.09,.09),.47,.04)
    else:
        for level,n in enumerate((3,3,2)):
            for i in range(n):
                x=(i-(n-1)/2)*.29
                p.beam((x,-.47,.14+level*.25),(x,.47,.14+level*.25),.14,"bark",7,caps="worn_wood")
        snow(p,(-.28,.28),(-.4,.4),.77,.035)


def axe_rack(p):
    frame(p,.95,.24,(.04,.45))
    for x in (-.3,0,.3):
        p.beam((x,-.25,.08),(x+.03,-.25,.85),.025,"worn_wood",5)
        p.box((x-.13,x+.04),(-.28,-.22),(.75,.88),"worn_metal")


def coat_rack(p):
    # 비어 있는 설비만: 가방/옷/신발 더미 없음.
    for x in (-.44,.44):
        p.box((x-.025,x+.025),(-.035,.035),(0,.94),"wood")
        p.box((x-.05,x+.05),(-.44,.44),(0,.07),"wood")
    p.box((-.48,.48),(-.05,.05),(.88,.94),"worn_wood")
    for x in (-.35,-.12,.12,.35):
        p.beam((x,0,.89),(x,-.18,.79),.018,"iron",4)
        p.beam((x,-.18,.79),(x,-.22,.84),.018,"iron",4)


def hull(p, upright=False):
    # 길이 방향 X. 뾰족한 양 끝과 각진 현측으로 배임을 구분한다.
    bottom=[(-.5,0,.15),(-.27,-.32,0),(.3,-.32,0),(.5,0,.15),(.3,.32,0),(-.27,.32,0)]
    rim=[(-.5,0,.75),(-.29,-.5,.56),(.3,-.5,.56),(.5,0,.75),(.3,.5,.56),(-.29,.5,.56)]
    if not upright:
        bottom=[(x,y,.8-z) for x,y,z in bottom]
        rim=[(x,y,.8-z) for x,y,z in rim]
    p.face(bottom,"bark",(0,0,-1 if upright else 1))
    for i in range(6):
        j=(i+1)%6
        p.face([bottom[i],bottom[j],rim[j],rim[i]],"worn_wood" if i%2 else "wood",(rim[i][0]+rim[j][0],rim[i][1]+rim[j][1],0))
    if upright:
        p.box((-.2,.22),(-.31,.31),(.15,.21),"wood")
        p.beam((-.44,0,.3),(-.44,0,1),.045,"worn_wood",5)
    else:
        snow(p,(-.22,.28),(-.19,.19),.8,.04)
        for x in (-.25,0,.25):
            p.box((x-.014,x+.014),(-.3,.3),(.79,.82),"bark")


def wheelhouse(p):
    p.box((-.48,.48),(-.43,.43),(0,.48),"wood")
    for x in (-.45,.4):
        for y in (-.42,.37):
            p.box((x,x+.05),(y,y+.05),(.48,.9),"worn_wood")
    # 기둥 사이 개구부를 남기고 유리 한 장만 넣는다.
    p.box((-.37,-.06),(-.42,-.405),(.52,.83),"glass")
    p.box((-.5,.5),(-.46,.46),(.9,.96),"rust")
    snow(p,(-.46,.42),(-.41,.41),.96,.04)
    p.beam((.15,0,.48),(.15,0,.67),.025,"iron",5)
    p.beam((.15,-.1,.68),(.15,.1,.68),.018,"iron",5)


def battery_rack(p):
    frame(p,.94,.38,(.04,.47))
    for z in (.09,.52):
        for x in (-.28,.22):
            p.box((x-.16,x+.16),(-.29,.29),(z,z+.31),"iron")
            p.box((x-.17,x+.17),(-.31,.31),(z+.31,z+.35),"rubber")
            for dx in (-.09,.09):
                p.box((x+dx-.025,x+dx+.025),(-.03,.03),(z+.35,z+.39),"worn_metal")


def fuel_drums(p):
    for x,y in ((-.25,-.25),(.25,-.25),(0,.25)):
        p.beam((x,y,.02),(x,y,.85),.23,"rust" if x<0 else "iron",10)
        for z in (.17,.65):
            p.beam((x,y,z),(x,y,z+.035),.24,"worn_metal",10)
        p.beam((x,y,.85),(x,y,.88),.21,"snow",10)


def lumber(p):
    for z in (.03,.23,.43,.63):
        for y in (-.32,0,.32):
            p.box((-.5,.5),(y-.13,y+.13),(z,z+.14),"worn_wood" if z>.4 else "wood")
    for x in (-.33,.28):
        p.box((x,x+.07),(-.48,.48),(.18,.22),"bark")
    snow(p,(-.45,.4),(-.42,.42),.77)


def deck(p, pier=False):
    for y in (-.4,.4):
        p.box((-.5,.5),(y-.04,y+.04),(0,.18),"bark")
    for i in range(12):
        x=-.5+i/12
        p.box((x,x+.077),(-.5,.5),(.18,.28+(0 if pier else (i%3)*.035)),"wood" if i%3 else "worn_wood")
    for x in (-.3,.17):
        snow(p,(x,x+.12),(-.38,.37),.35 if not pier else .28,.025)


def buoy_line(p):
    p.beam((-.49,0,.05),(.49,0,.05),.018,"cloth",5)
    for x in (-.36,0,.36):
        p.lump(x,0,.03,.105,.2,.24,"enamel" if x else "rust",8)
        p.beam((x,0,.26),(x,0,.3),.025,"iron",5)


def scrap(p):
    for i in range(4):
        p.box((-.46+i*.04,.43-i*.03),(-.35,.38),(i*.12,i*.12+.055),"rust" if i%2 else "worn_metal")
    p.beam((-.4,-.4,.15),(.4,.3,.68),.06,"iron",6)
    p.beam((-.38,.38,.35),(.36,-.3,.58),.075,"rust",6)
    p.box((-.2,.2),(-.19,.19),(.51,.69),"iron")
    snow(p,(-.17,.15),(-.15,.14),.69)


def ice_heap(p):
    for x,y,z,rx,ry,h in ((-.23,-.23,0,.25,.24,.55),(.22,-.22,.03,.26,.27,.75),(0,.2,.02,.33,.3,1)):
        p.lump(x,y,z,rx,ry,h,"glass",5)
        p.lump(x,y,z+h*.55,rx*.81,ry*.81,h*.45,"snow",5)


def herb_rack(p):
    frame(p,1,.32,(.06,))
    p.box((-.48,.48),(-.035,.035),(.9,.95),"worn_wood")
    for x in (-.32,-.1,.12,.34):
        p.beam((x,0,.91),(x,0,.68),.012,"cloth",4)
        p.beam((x,0,.35),(x,0,.69),.09,"cloth",5,tip=.025)
        p.beam((x,0,.39),(x+.06,0,.66),.025,"bark",4)


def door_pile(p):
    for i in range(3):
        z=i*.18
        p.box((-.49+i*.02,.49-i*.015),(-.4,.4),(z,z+.1),"wood")
        for x in (-.27,.22):
            p.box((x-.14,x+.14),(-.28,.28),(z+.1,z+.12),"worn_wood")
    p.box((.32,.37),(-.13,-.05),(.48,.52),"worn_metal")
    snow(p,(-.4,.15),(-.32,.3),.48,.025)


def dry_bush(p):
    for i in range(7):
        a=i*math.tau/7
        tip=(.44*math.cos(a),.44*math.sin(a),.55+(i%3)*.13)
        p.beam((0,0,0),tip,.025,"bark",5,tip=.008)
        p.beam((tip[0]*.5,tip[1]*.5,tip[2]*.5),(tip[0]*1.08,tip[1]*.85,tip[2]*.65),.014,"bark",4,tip=.005)


def net_rack(p):
    for x in (-.48,.48):
        p.beam((x,0,0),(x,0,1),.028,"wood",6)
        p.box((x-.025,x+.025),(-.45,.45),(0,.035),"bark")
    p.beam((-.48,0,.95),(.48,0,.95),.02,"worn_wood",5)
    for i in range(9):
        x=-.4+i*.1
        p.beam((x,0,.28),(x,0,.88),.005,"cloth",4)
    for z in (.28,.43,.58,.73,.88):
        p.beam((-.4,0,z),(.4,0,z),.005,"cloth",4)


def fuel_tank(p):
    p.beam((-.43,0,.55),(.43,0,.55),.36,"worn_metal",12)
    for x in (-.3,.24):
        p.box((x,x+.06),(-.28,.28),(0,.34),"iron")
        p.beam((x,0,.55),(x+.035,0,.55),.37,"rust",12)
    p.beam((0,0,.87),(0,0,.97),.065,"iron",8)
    p.beam((0,0,.97),(0,0,1),.1,"worn_metal",8)
    snow(p,(-.36,.34),(-.12,.12),.9,.025)


def rail_marker(p):
    p.box((-.15,.15),(-.15,.15),(0,.15),"stone")
    p.box((-.06,.06),(-.05,.05),(.1,.7),"iron")
    p.box((-.4,.4),(-.035,.035),(.65,.95),"enamel")
    p.box((-.25,.25),(-.042,-.036),(.76,.8),"iron")


def rock_ridge(p):
    for x,y,h,rx,ry in ((-.28,-.17,.7,.24,.3),(.05,.03,1,.32,.4),(.35,.14,.66,.16,.28)):
        p.lump(x,y,0,rx,ry,h,"stone",6)
        p.lump(x,y,h*.72,rx*.6,ry*.6,h*.29,"snow",6)


def sled(p):
    for y in (-.37,.37):
        p.beam((-.45,y,.04),(.36,y,.04),.035,"iron",5)
        p.beam((.36,y,.04),(.49,y,.18),.035,"iron",5)
    p.box((-.4,.34),(-.42,.42),(.14,.22),"worn_wood")
    for x in (-.22,.12):
        p.box((x-.13,x+.13),(-.32,.32),(.23,.65),"glass")
        snow(p,(x-.13,x+.13),(-.32,.32),.65)


def buffer_stop(p):
    for y in (-.38,.38):
        p.beam((-.42,y,.04),(.12,y,.75),.06,"iron",4)
        p.beam((.42,y,.04),(.12,y,.75),.06,"rust",4)
    p.box((.05,.21),(-.49,.49),(.65,.88),"worn_wood")
    for y in (-.3,.3):
        p.beam((.21,y,.76),(.36,y,.76),.11,"iron",8)
    snow(p,(.05,.21),(-.43,.43),.88)


def cabinet(p):
    p.box((-.5,.5),(-.4,.4),(0,.94),"iron")
    for x in (-.46,.02):
        p.box((x,x+.44),(-.43,-.405),(.06,.88),"worn_metal")
        p.box((x+.32,x+.35),(-.47,-.43),(.45,.62),"iron")
    p.box((-.44,.44),(-.35,.35),(.94,1),"worn_wood")


def plate_stack(p):
    for i in range(6):
        p.box((-.5+i*.014,.5-i*.009),(-.48+i*.012,.48-i*.01),(.08+i*.11,.13+i*.11),"rust" if i%2 else "worn_metal")
    for x in (-.32,.25):
        p.box((x,x+.08),(-.43,.43),(0,.08),"wood")
    snow(p,(-.4,.37),(-.36,.32),.68,.03)


def floor_shell(p):
    # 얇은 바닥판과 균열만. 집 외곽 벽·잠금·창 막음은 만들지 않는다.
    p.box((-.5,.5),(-.5,.5),(0,.08),"stone")
    for x in (-.25,0,.25):
        p.box((x-.002,x+.002),(-.49,.49),(.08,.081),"iron")
    p.box((-.49,.49),(-.002,.002),(.08,.081),"iron")
    snow(p,(-.49,-.3),(.3,.49),.081,.015)


def stair_stub(p):
    for i in range(3):
        p.box((-.5,.5),(-.5+i/3,-.5+(i+1)/3),(0,(i+1)*.15),"stone")
        snow(p,(-.43,.4),(-.48+i/3,-.23+i/3),(i+1)*.15,.01)


def fish_traps(p):
    # 통발은 어구: 바구니 테와 세로 살, 사람이 들어가는 칸이 아니다.
    for cx,cy,z in ((-.24,-.22,0),(.24,.22,0),(0,0,.43)):
        for dz in (.02,.4):
            ring=[(cx+.22*math.cos(i*math.tau/6),cy+.22*math.sin(i*math.tau/6),z+dz) for i in range(6)]
            for i in range(6):
                p.beam(ring[i],ring[(i+1)%6],.014,"wood",4)
        for i in (0, 2, 3, 5):
            a=i*math.tau/6
            p.beam((cx+.22*math.cos(a),cy+.22*math.sin(a),z+.02),(cx+.22*math.cos(a),cy+.22*math.sin(a),z+.4),.012,"worn_wood",4)


def fallen_mast(p):
    p.beam((-.49,0,.16),(.49,0,.16),.12,"bark",8,tip=.055,caps="worn_wood")
    p.beam((.05,-.48,.16),(.05,.48,.16),.045,"worn_wood",6)
    p.beam((-.38,0,.2),(.06,.45,.2),.01,"cloth",4)
    snow(p,(-.4,.35),(-.045,.045),.26,.02)


def vent_pipe(p):
    p.box((-.3,.3),(-.3,.3),(0,.07),"stone")
    p.beam((0,0,.03),(0,0,.86),.13,"rust",10)
    p.beam((0,0,.7),(0,0,.74),.145,"iron",10)
    p.beam((0,0,.83),(0,0,1),.31,"worn_metal",10,tip=.055)
    p.beam((0,0,.89),(0,0,1.015),.23,"snow",10,tip=.04)


def crate(p,x,y,z,s=.43):
    p.box((x-s/2,x+s/2),(y-s/2,y+s/2),(z,z+s),"wood")
    for dz in (.08,.27):
        p.box((x-s/2-.008,x+s/2+.008),(y-s/2-.012,y-s/2-.003),(z+dz,z+dz+.025),"bark")
    for dx in (-s*.38,s*.38):
        p.box((x+dx-.025,x+dx+.025),(y-s/2-.025,y-s/2-.012),(z+.02,z+s-.02),"worn_wood")


def fish_crates(p):
    for x,y,z in ((-.24,-.24,0),(.24,-.24,0),(-.24,.24,0),(0,0,.44)):
        crate(p,x,y,z)
    snow(p,(-.2,.19),(-.2,.19),.87,.03)


def hay_cart(p):
    p.box((-.45,.3),(-.4,.4),(.25,.34),"wood")
    for y in (-.44,.44):
        p.beam((-.05,y-.04,.23),(-.05,y+.04,.23),.22,"bark",10)
        p.beam((-.05,y-.045,.23),(-.05,y+.045,.23),.07,"worn_metal",6)
    p.beam((.1,0,.29),(.5,0,.19),.04,"worn_wood",5)
    for x in (-.28,.1):
        p.lump(x,0,.34,.19,.34,.46,"cloth",6)
        p.box((x-.015,x+.015),(-.33,.33),(.34,.8),"wood")
    snow(p,(-.3,.1),(-.18,.17),.8,.025)


def coal_bin(p):
    p.box((-.5,.5),(-.45,.45),(0,.07),"wood")
    for y in (-.45,.4):
        p.box((-.5,.5),(y,y+.05),(.07,.65),"wood")
    for x in (-.5,.45):
        p.box((x,x+.05),(-.4,.4),(.07,.65),"worn_wood")
    for x,y,h in ((-.27,-.15,.53),(.22,-.15,.45),(0,.15,.65)):
        p.lump(x,y,.08,.25,.23,h,"rubber",5)


def firewood_rick(p):
    for y in (-.32,0,.32):
        for z in (.12,.35,.58):
            p.beam((-.43,y,z),(.43,y,z),.115,"bark",6,caps="worn_wood")
    for x in (-.48,.48):
        p.box((x-.02,x+.02),(-.44,.44),(0,.78),"wood")
    snow(p,(-.4,.4),(-.39,.39),.72,.04)


# 높이와 조형 판단은 각 자산 장부/결과 글에 그대로 기록한다.
SPECS = {
    "power_pole": (power_pole,5.2,"wall 전봇대: 전선 없이 좁은 가로대·애자로 식별, 높이 예외."),
    "sleeper_stack": (sleeper_stack,1.05,"low: 낡은 침목을 세 단으로 쌓고 윗단에 눈."),
    "cable_drum": (lambda p:reel(p),1.15,"none/low 혼합: 케이블 권취통의 둥근 플랜지를 살리기 위해 높이 예외."),
    "ration_ledger_chest": (chest,.48,"none 우세: 낮은 배급 장부함, 뚜껑 위 장부 두 권."),
    "hose_reel": (lambda p:reel(p,True),1.0,"low/none 동수: 받침 있는 호스 릴과 짧은 노즐, low 높이 채택."),
    "spruce": (spruce,4.2,"tree: 좁은 침엽 수관 세 층과 눈, 나무 높이 예외."),
    "cloth_bolt_rack": (cloth_bolt_rack,1.15,"none 우세지만 원단 롤 보관대 의미 우선, 옷이나 소지품 더미 아님."),
    "coal_wagon": (lambda p:wagon(p,coal=True),2.0,"wagon: 열린 석탄 적재함·대차, 사람 승차 설비 없음."),
    "loom": (loom,1.2,"none/low 혼합: 직기 틀·날실·직물 면을 구분하도록 높이 예외."),
    "log_stack_low": (logs,1.2,"low: 긴 통나무 여덟 개와 밝은 절단면, 1.3m 미만."),
    "axe_rack": (axe_rack,1.05,"none/low 혼합: 도끼 세 자루를 수직 보관하는 낮은 설비로 예외."),
    "heavy_coat_rack": (coat_rack,1.25,"none/low 혼합: 빈 외투 걸이 설비만 제작, 옷·가방·신발 더미 없음."),
    "sunken_bow": (lambda p:hull(p,True),1.9,"wall: 수면 위 솟은 뾰족한 선수와 열린 선체, 1.8m 이상."),
    "sunken_wheelhouse": (wheelhouse,1.9,"wall: 창 개구부를 남긴 조타실 윗부분, 지붕에 눈."),
    "battery_rack": (battery_rack,1.1,"low 우세: 두 단 배터리와 단자, 글자·경고표지 없음."),
    "engine": (lambda p:wagon(p,engine=True),3.2,"별도 train_cars의 기관차: 16×3m 원문 치수, 연기·굴뚝·승객 설비 없음. props 자동 배치 대상 아님."),
    "fuel_drum_stack": (fuel_drums,.95,"none 우세지만 연료통 세 개의 원통 형태 우선, 낮은 한 단 예외."),
    "lumber_stack": (lumber,1.05,"low 우세: 각재를 간격 둔 네 단으로 적재."),
    "sunken_deck_section": (deck,.65,"low: 고르지 않은 갑판 조각과 받침보, 난간·승차 자리 없음."),
    "buoy_line": (buoy_line,.3,"none: 바닥에 놓인 부표 세 개와 낮은 연결 밧줄."),
    "scrap_stack": (scrap,1.1,"low: 금속 판재·관 폐자재만, 소지품을 섞지 않음."),
    "shore_ice_heap": (ice_heap,.95,"low: 별도 제외 7종에 없는 물가 얼음 덩어리 세 개, 불투명 정점색."),
    "firewood_stack": (logs,1.05,"low: 절단면이 보이는 장작 단, 1.3m 미만."),
    "herb_drying_rack": (herb_rack,1.1,"none 우세: 약초 묶음을 걸어 말리는 틀 의미를 위해 높이 예외."),
    "door_pile": (door_pile,.65,"low 우세: 떼어 낸 문짝 세 장, 사람 칸의 문·빗장·잠금 아님."),
    "dry_bush": (dry_bush,.45,"none: 잎 없는 낮은 갈색 잔가지, 바닥 가까운 높이."),
    "net_drying_rack": (net_rack,1.2,"low: 성긴 어망과 두 기둥, 철조망 없이 섬유 밧줄색."),
    "fuel_tank": (fuel_tank,1.25,"low14/wall9 혼합: 다수 low 기준 수평 연료탱크, wall 배치와 높이 불일치 남음."),
    "log_scatter": (lambda p:logs(p,"scatter"),.4,"none: 바닥에 흩어진 짧은 통나무 세 개."),
    "rail_marker": (rail_marker,.48,"none: 낮은 직사각 철도 표지, 번호·대기 구획·십자 없음."),
    "rock_ridge": (rock_ridge,2.4,"wall: 눈 덮인 각진 바위 능선 세 봉우리, 시야 차단 높이."),
    "ice_sled_load": (sled,.95,"low 우세: 얼음 덩어리만 실은 썰매, 소지품 더미 없음."),
    "buffer_stop": (buffer_stop,1.1,"low: 삼각 지지대와 목재 완충 보, 철길 종단 설비."),
    "office_cabinet": (cabinet,1.15,"low 우세: 두 문 달린 낮은 사무용 철제 보관장."),
    "overturned_boat": (hull,1.1,"low: 뒤집힌 뾰족 선체와 바닥 리브, 눈 얹힌 용골."),
    "plate_stack": (plate_stack,.7,"low 우세: 철판 여섯 장과 받침 각재, 낡은 금속색."),
    "fallen_log": (lambda p:logs(p,"fallen"),.65,"low: 부러진 가지와 절단면이 있는 쓰러진 통나무."),
    "floor_shell": (floor_shell,.12,"none: 가장 흔한 32×16m의 얇은 바닥판만, 벽·창 막음 없음."),
    "stair_stub": (stair_stub,.48,"none: 3단 돌계단 잔재, 높이 0.5m 이하."),
    "fish_trap_stack": (fish_traps,1.1,"low: 속이 보이는 작은 통발 세 개, 어구 바구니 형태."),
    "flat_wagon": (wagon,1.2,"wagon: 눈 얹힌 빈 평판 화차와 대차, 승객·하역 경사로 없음."),
    "fallen_mast": (fallen_mast,.5,"low: 가로대와 짧은 밧줄이 붙은 쓰러진 돛대."),
    "pier_deck": (lambda p:deck(p,True),.18,"none: 입력 최빈 3×22m의 낮은 잔교 판재, 난간·경사로 없음."),
    "vent_pipe": (vent_pipe,2.0,"wall: 광산 환기관과 빗물 막이, 굴뚝 연기 자리 없음."),
    "fish_crate_stack": (fish_crates,1.1,"low 우세: 생선 운반 나무상자 네 개, 내용물·소지품 없음."),
    "hay_cart": (hay_cart,1.2,"low 우세: 마른 건초 두 묶음과 수레 바퀴·손잡이."),
    "medicine_crate": (lambda p:chest(p,True),.48,"none 우세: 낮은 약품 상자와 빈 직사각 라벨, 빨간 십자·초승달 없음."),
    "coal_bin": (coal_bin,.95,"none/low 동수: 열린 석탄함의 벽과 석탄 덩어리, low 기준 예외."),
    "firewood_rick": (firewood_rick,1.15,"low: 양 끝 지지판 안에 가지런히 쌓은 장작, 눈 덮인 윗단."),
}


def census(repo, names):
    """리터럴 rect 딕셔너리를 집계. 실행 배치 수와 혼동하지 않는다."""
    sizes={k:collections.Counter() for k in names}
    per_map={}
    samples={k:[] for k in names}
    for path in sorted((repo/"s2/game/world/maps").glob("*.gd")):
        counts=collections.Counter()
        source=path.read_text(encoding="utf-8-sig")
        for match in re.finditer(r'\{[^{}]*\}',source):
            body=match.group()
            kind=re.search(r'"kind"\s*:\s*"([a-z_]+)"\s*[,}]',body)
            rect=re.search(r'"rect"\s*:\s*(?:Rect2i\(\s*|\[\s*)(-?\d+)\s*,\s*(-?\d+)\s*,\s*(\d+)\s*,\s*(\d+)\s*[\])]',body)
            if not kind or kind[1] not in names or not rect:
                continue
            k=kind[1]
            sizes[k][(int(rect[3]),int(rect[4]))]+=1
            counts[k]+=1
            if len(samples[k])<3:
                samples[k].append({"source":path.relative_to(repo).as_posix(),"line":source.count("\n",0,match.start())+1,"rect_wh":[int(rect[3]),int(rect[4])]})
        per_map[path.name]=dict(counts)
    return sizes,per_map,samples


def export(piece,path):
    mesh=bpy.data.meshes.new(piece.name)
    obj=None
    try:
        piece.bm.to_mesh(mesh)
        mesh.color_attributes.active_color=mesh.color_attributes["Col"]
        mesh.color_attributes.render_color_index=0
        obj=bpy.data.objects.new(piece.name,mesh)
        bpy.context.collection.objects.link(obj)
        bpy.ops.object.select_all(action="DESELECT")
        obj.select_set(True)
        bpy.context.view_layer.objects.active=obj
        bpy.ops.export_scene.gltf(filepath=str(path),export_format="GLB",use_selection=True,
            export_yup=True,export_apply=False,export_materials="NONE",export_texcoords=False,
            export_normals=True,export_tangents=False,export_vertex_color="ACTIVE",
            export_extras=False,export_animations=False)
    finally:
        if obj: bpy.data.objects.remove(obj,do_unlink=True)
        bpy.data.meshes.remove(mesh)


def check_glb(path,tris,footprint,height):
    data=path.read_bytes()
    magic,version,length=struct.unpack_from("<4sII",data)
    chunk_len,chunk_type=struct.unpack_from("<II",data,12)
    assert magic==b"glTF" and version==2 and length==len(data) and chunk_type==0x4e4f534a
    doc=json.loads(data[20:20+chunk_len])
    assert len(doc.get("meshes",[]))==1 and len(doc.get("nodes",[]))==1
    prims=doc["meshes"][0]["primitives"]
    assert len(prims)==1 and prims[0].get("mode",4)==4
    p=prims[0]
    assert "COLOR_0" in p["attributes"] and "TEXCOORD_0" not in p["attributes"]
    assert doc["accessors"][p["indices"]]["count"]==tris*3 and 0<tris<=600
    assert not any(doc.get(k) for k in ("materials","images","textures","animations","skins","cameras","extensions"))
    assert all("uri" not in b for b in doc["buffers"])
    pos=doc["accessors"][p["attributes"]["POSITION"]]
    lo,hi=pos["min"],pos["max"]
    target=(footprint[0],height,footprint[1])
    assert all(abs(hi[i]-lo[i]-target[i])<.001 for i in range(3))
    assert abs(lo[1])<.001 and abs(lo[0]+hi[0])<.001 and abs(lo[2]+hi[2])<.001
    return {"bytes":len(data),"sha256":hashlib.sha256(data).hexdigest(),"bounds_m":[lo,hi],"dimensions_m":list(target)}


def write_books(out,book):
    (out/"catalog_b.json").write_text(json.dumps(book,ensure_ascii=False,indent=2)+"\n",encoding="utf-8")
    lines=["# 지도 소품 B", "", "`tools/blender/props_field_b.py`가 생성한 장부. 메시·면 묶음 각 하나, Col 정점색, 삼각형 ≤600.","",PLACEMENT,"",
           "| 이름 | 수 | 발자국 m | 높이 m | solid | 삼각형 | 바이트 | 판단 |","|---|---:|---|---:|---|---:|---:|---|"]
    for k,r in book["assets"].items():
        solid=", ".join(f"{s}:{n}" for s,n in r["solid"].items())
        lines.append(f'| {k} | {r["count"]} | {r["footprint_m"][0]}×{r["footprint_m"][1]} | {r["height_m"]} | {solid} | {r["lod0_tris"]} | {r["bytes"]} | {r["judgment"]} |')
    lines += ["", "## 파일 확인값", "", "| 이름 | SHA-256 |", "|---|---|"]
    lines += [f'| {k} | `{r["sha256"]}` |' for k,r in book["assets"].items()]
    lines += ["", "## 팔레트 (선형 RGBA)", ""]+[f"- {k}: {v}" for k,v in PALETTE.items()]
    lines += ["", "## 제외", ""]+[f"- {k}: {v}" for k,v in book["skipped"].items()]
    lines += ["- skip_ground_like 7종은 입력 그대로 제외: "+", ".join(book["skip_ground_like"]),"",
              "최빈 rect가 입력에 있으면 그대로 사용한다. 누락된 10종은 지도 리터럴 Rect2i에서 보완한다. engine은 train_cars의 16×3m를 사용한다.",
              "지도 추정은 리터럴 소품 수 × 이번 GLB 삼각형 수의 합이다. 기존 모델·다른 발주·train_cars·실행 중 동적 추가는 제외한다.",
              "현 PropModels의 Weathered는 use_vertex_color 기본 false라 게임 배치 색 반영은 별도 연결 작업이 필요하다. 이 제작기는 로더를 수정하지 않는다."]
    (out/"README_b.md").write_text("\n".join(lines)+"\n",encoding="utf-8")


def preview(repo,out,book):
    """검토 전용: 다시 가져온 실제 GLB만 렌더, 출력은 허용된 캐시."""
    target=repo/"s2/.godot/props_b_evidence"
    target.mkdir(parents=True,exist_ok=True)
    keys=list(book["assets"])
    for page in range(math.ceil(len(keys)/10)):
        bpy.ops.wm.read_factory_settings(use_empty=True)
        scene=bpy.context.scene
        scene.render.engine="BLENDER_WORKBENCH"
        scene.display.shading.light="STUDIO"
        scene.display.shading.color_type="VERTEX"
        scene.display.shading.show_shadows=True
        scene.display.shading.show_cavity=True
        scene.display.shading.cavity_type="BOTH"
        scene.display.shading.background_type="WORLD"
        scene.world=bpy.data.worlds.new("PreviewWorld")
        scene.world.color=(.055,.065,.075)
        scene.view_settings.view_transform="Standard"
        scene.render.resolution_x=2000
        scene.render.resolution_y=900
        scene.render.resolution_percentage=100
        for i,key in enumerate(keys[page*10:(page+1)*10]):
            before=set(bpy.data.objects)
            bpy.ops.import_scene.gltf(filepath=str(out/(key+".glb")))
            imported=set(bpy.data.objects)-before
            for obj in imported:
                if obj.type!="MESH": continue
                obj.rotation_mode="XYZ"
                obj.rotation_euler=(math.radians(24),0,math.radians(-24))
                bpy.context.view_layer.update()
                dims=obj.dimensions
                scale=2.5/max(dims.x,dims.y,dims.z)
                obj.scale=(scale,)*3
                bpy.context.view_layer.update()
                corners=[obj.matrix_world@Vector(v) for v in obj.bound_box]
                low=min(v.z for v in corners)
                center=(min(v.x for v in corners)+max(v.x for v in corners))/2
                obj.location.x+=(i%5-2)*3.5-center
                obj.location.z+=(1-i//5)*3.7-low
            curve=bpy.data.curves.new("PreviewLabel","FONT")
            curve.body=key
            curve.align_x="CENTER"
            curve.size=.16
            label=bpy.data.objects.new("PreviewLabel",curve)
            scene.collection.objects.link(label)
            label.location=((i%5-2)*3.5,-2,(1-i//5)*3.7-.35)
            label.rotation_euler=(math.pi/2,0,0)
            label.color=(.8,.85,.9,1)
        cam_data=bpy.data.cameras.new("PreviewCamera")
        cam=bpy.data.objects.new("PreviewCamera",cam_data)
        scene.collection.objects.link(cam)
        cam.location=(0,-30,3)
        cam.rotation_euler=(math.pi/2,0,0)
        cam_data.type="ORTHO"
        cam_data.ortho_scale=18.2
        scene.camera=cam
        scene.render.image_settings.file_format="PNG"
        scene.render.filepath=str(target/f"contact_b_{page+1}.png")
        bpy.ops.render.render(write_still=True)
        print(f"PREVIEW_READY contact_b_{page+1}.png",flush=True)


def main():
    parser=argparse.ArgumentParser()
    parser.add_argument("--repo",required=True)
    parser.add_argument("--preview",action="store_true")
    args=parser.parse_args(sys.argv[sys.argv.index("--")+1:])
    repo=Path(args.repo).resolve()
    out=repo/"s2/models/props_field"
    if args.preview:
        preview(repo,out,json.loads((out/"catalog_b.json").read_text(encoding="utf-8")))
        return
    source=json.loads((repo/"_in/kinds_b.json").read_text(encoding="utf-8-sig"))
    kinds=source["kinds"]
    assert len(kinds)==50 and {r["kind"] for r in kinds}==set(SPECS)|set(SKIPPED)
    out.mkdir(parents=True,exist_ok=True)
    # 다시 실행할 때는 장부 해시가 일치하는 이전 출력만 교체한다.
    old={}
    if (out/"catalog_b.json").exists():
        old=json.loads((out/"catalog_b.json").read_text(encoding="utf-8"))["assets"]
    for key in SPECS:
        path=out/(key+".glb")
        if path.exists() and (key not in old or hashlib.sha256(path.read_bytes()).hexdigest()!=old[key]["sha256"]):
            raise RuntimeError("기존 변경 보호: "+key)
    sizes,per_map,samples=census(repo,SPECS)
    book={"version":1,"axis":"X right, +Y up, +Z front","origin":"footprint centre floor",
          "palette":PALETTE,"placement":PLACEMENT,"source":"_in/kinds_b.json",
          "expected_kinds":[r["kind"] for r in kinds],"skipped":SKIPPED,
          "skip_ground_like":[r["kind"] for r in source["skip_ground_like"]],
          "assets":{},"failures":[],"per_map_literal_counts":per_map}
    bpy.ops.wm.read_factory_settings(use_empty=True)
    for row in kinds:
        k=row["kind"]
        if k in SKIPPED: continue
        build,height,judgment=SPECS[k]
        if row["rects_wh_top"]:
            footprint,modal_count=row["rects_wh_top"][0]
            origin="input rects_wh_top[0]"
        elif sizes[k]:
            footprint,modal_count=sizes[k].most_common(1)[0]
            origin="map literal Rect2i modal"
        elif k=="engine":
            footprint,modal_count=(16,3),0
            origin="train_cars Rect2i(16 + k * 16, 1, 16, 3), props 아님"
        else:
            raise ValueError("발자국 근거 없음: "+k)
        p=Piece(k)
        try:
            build(p)
            p.fit(footprint,height)
            tris=len(p.bm.faces)
            assert 0<tris<=TRIANGLE_LIMIT,(k,tris)
            path=out/(k+".glb")
            # 생성한 이전 버전의 복구 사본은 캐시에만 저장.
            if path.exists():
                backup=repo/"s2/.godot/props_b_evidence/backups"/hashlib.sha256(path.read_bytes()).hexdigest()
                backup.parent.mkdir(parents=True,exist_ok=True)
                if not backup.exists(): backup.write_bytes(path.read_bytes())
            export(p,path)
            checked=check_glb(path,tris,footprint,height)
            book["assets"][k]={"status":"ready","path":f"res://models/props_field/{k}.glb",
                "count":row["count"],"maps":row["maps"],"footprint_m":list(footprint),
                "footprint_source":origin,"modal_rect_count":modal_count,"source_samples":samples[k],
                "height_m":height,"solid":row["solid"],"facing":row["facing"],
                "map_families":row["map_families"],"lod0_tris":tris,"triangle_limit":600,
                "colours":sorted(p.colours),"placement":PLACEMENT,"judgment":judgment,**checked}
            print(f"PROP_READY {k} tris={tris} bytes={checked['bytes']}",flush=True)
        except Exception as error:
            book["failures"].append({"kind":k,"error":str(error)})
            print(f"PROP_FAILED {k}: {type(error).__name__}: {error}",flush=True)
        finally:
            p.bm.free()
    totals={m:sum(n*book["assets"][k]["lod0_tris"] for k,n in counts.items() if k in book["assets"]) for m,counts in per_map.items()}
    peak=max(totals,key=totals.get)
    book["map_triangle_estimate"]={"method":"literal rect dictionaries × generated triangles; B only; no runtime claim",
        "map_files":len(per_map),"max_map":peak,"max_triangles":totals[peak],"per_map_triangles":totals}
    write_books(out,book)
    print("PROPS_FIELD_B "+json.dumps({"ready":len(book["assets"]),"skipped":list(SKIPPED),"failures":book["failures"],"peak_map":peak,"peak_triangles":totals[peak]},ensure_ascii=False),flush=True)
    if book["failures"]: raise SystemExit(1)


if __name__=="__main__": main()
