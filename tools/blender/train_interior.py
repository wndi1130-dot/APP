"""열차 실내 33종. Blender 헤드리스, 외부 자원 없이 정점색만 내보낸다.

blender -b --factory-startup -P tools/blender/train_interior.py -- --repo .
논리 좌표는 glTF X 오른쪽 / Y 위 / Z 앞. 내보낼 때만 Blender 축으로 바꾼다.
"""
import sys
sys.dont_write_bytecode = True

import argparse
import hashlib
import json
import math
import os
import struct
from collections import Counter
from pathlib import Path

import bmesh
import bpy
from mathutils import Vector

SCRIPT_VERSION = 1
TRIANGLE_LIMIT = 600
TOTAL_LIMIT = 8000
# 선형 RGBA. train_life.json의 기본색 5개와 그 밝음/어두움 변형, 총 12색.
# ember는 별도 FirePlaceholder 몫이므로 이 묶음에 쓰지 않는다.
PALETTE = {
    "wood": (0.30, 0.25, 0.20, 1.0),
    "wood_worn": (0.42, 0.35, 0.27, 1.0),
    "wood_dark": (0.18, 0.15, 0.12, 1.0),
    "iron": (0.12, 0.12, 0.13, 1.0),
    "iron_worn": (0.24, 0.24, 0.25, 1.0),
    "soot": (0.045, 0.045, 0.052, 1.0),
    "cloth": (0.50, 0.45, 0.40, 1.0),
    "cloth_faded": (0.64, 0.58, 0.51, 1.0),
    "paper": (0.80, 0.78, 0.70, 1.0),
    "paper_aged": (0.62, 0.59, 0.49, 1.0),
    "brass": (0.70, 0.56, 0.30, 1.0),
    "brass_dark": (0.40, 0.32, 0.17, 1.0),
}
ORIGIN = "box_center"
PLACEMENT = "X·Y·Z 경계 상자의 한가운데가 (0,0,0). +Y 위, +Z 앞. at에 그대로 놓고 yaw만 적용."
IMPORT_SCRIPT = '''@tool
extends EditorScenePostImport
## GLB는 재질 없이 Col만 저장한다. 가져온 내장 재질에서 그 색을 켠다.

func _post_import(scene: Node) -> Object:
    _paint(scene)
    return scene

func _paint(node: Node) -> void:
    if node is MeshInstance3D:
        var mesh := (node as MeshInstance3D).mesh
        for surface in mesh.get_surface_count():
            var material := StandardMaterial3D.new()
            material.vertex_color_use_as_albedo = true
            material.vertex_color_is_srgb = false
            material.albedo_color = Color.WHITE
            material.roughness = 1.0
            mesh.surface_set_material(surface, material)
    for child in node.get_children():
        _paint(child)
'''


class Piece:
    """한 BMesh, 한 Col 레이어, 한 glTF primitive. 부품은 같은 메시로 합친다."""
    def __init__(self, pid):
        self.pid = pid
        self.bm = bmesh.new()
        self.col = self.bm.loops.layers.float_color.new("Col")
        self.colours = set()

    def face(self, pts, colour, outward):
        pts = [Vector((p[0], -p[2], p[1])) for p in pts]
        outward = Vector((outward[0], -outward[2], outward[1]))
        normal = Vector((0, 0, 0))
        for i, a in enumerate(pts):
            b = pts[(i + 1) % len(pts)]
            normal += a.cross(b)
        if normal.length < 1e-9:
            raise ValueError("넓이 없는 면: " + self.pid)
        if normal.dot(outward) < 0:
            pts.reverse()
        face = self.bm.faces.new([self.bm.verts.new(p) for p in pts])
        face.smooth = False
        for loop in face.loops:
            loop[self.col] = PALETTE[colour]
        self.colours.add(colour)

    def box(self, x, y, z, colour="wood", top=None):
        x0, x1 = x
        y0, y1 = y
        z0, z1 = z
        if min(x1-x0, y1-y0, z1-z0) <= 0:
            raise ValueError("빈 상자: " + self.pid)
        for a, sign in ((x0, -1), (x1, 1)):
            self.face([(a,y0,z0),(a,y1,z0),(a,y1,z1),(a,y0,z1)], colour, (sign,0,0))
        for a, sign in ((y0, -1), (y1, 1)):
            self.face([(x0,a,z0),(x1,a,z0),(x1,a,z1),(x0,a,z1)], top if top and sign > 0 else colour, (0,sign,0))
        for a, sign in ((z0, -1), (z1, 1)):
            self.face([(x0,y0,a),(x1,y0,a),(x1,y1,a),(x0,y1,a)], colour, (0,0,sign))

    def beam(self, start, end, radius, colour="iron", sides=8):
        a, b = Vector(start), Vector(end)
        axis = (b-a).normalized()
        guide = Vector((1,0,0)) if abs(axis.y) > .9 else Vector((0,1,0))
        u = axis.cross(guide).normalized()
        v = axis.cross(u).normalized()
        radial = [u*math.cos(i*math.tau/sides)+v*math.sin(i*math.tau/sides) for i in range(sides)]
        low, high = [a+r*radius for r in radial], [b+r*radius for r in radial]
        self.face(low, colour, -axis)
        self.face(high, colour, axis)
        for i in range(sides):
            j = (i+1) % sides
            self.face([low[i],low[j],high[j],high[i]], colour, radial[i]+radial[j])

    def lathe(self, centre, profile, colour, sides=8, alternate=None):
        cx, cz = centre
        rings = [[(cx+rx*math.cos(i*math.tau/sides), y, cz+rz*math.sin(i*math.tau/sides))
                  for i in range(sides)] for y,rx,rz in profile]
        self.face(rings[0], colour, (0,-1,0))
        self.face(rings[-1], colour, (0,1,0))
        for k, (lower, upper) in enumerate(zip(rings, rings[1:])):
            dy = profile[k+1][0]-profile[k][0]
            dr = ((profile[k+1][1]-profile[k][1])+(profile[k+1][2]-profile[k][2]))/2
            for i in range(sides):
                j = (i+1) % sides
                a = (i+.5)*math.tau/sides
                tint = alternate if alternate and i % 3 == 0 else colour
                self.face([lower[i],lower[j],upper[j],upper[i]], tint, (dy*math.cos(a),-dr,dy*math.sin(a)))

    def fit(self, size):
        # Blender XYZ = glTF X,-Z,Y. 세 축 모두 경계의 중앙에 맞춘다.
        lo = [min(v.co[i] for v in self.bm.verts) for i in range(3)]
        hi = [max(v.co[i] for v in self.bm.verts) for i in range(3)]
        target = (size[0], size[2], size[1])
        for v in self.bm.verts:
            for i in range(3):
                v.co[i] = ((v.co[i]-lo[i])/(hi[i]-lo[i])-.5)*target[i]
        # 면을 공유하는 반복 부품도 별도 오브젝트로 내보내지 않는다.
        bmesh.ops.triangulate(self.bm, faces=list(self.bm.faces))
        self.bm.normal_update()
        if any(f.calc_area() < 1e-11 for f in self.bm.faces):
            raise ValueError("퇴화 삼각형: " + self.pid)


def legs(p, height=.86, positions=(-.42,.42), colour="wood_dark"):
    for x in positions:
        for z in (-.40,.40):
            p.box((x-.035,x+.035),(0,height),(z-.045,z+.045),colour)


def tabletop(p, height=.86, planks=3):
    for i in range(planks):
        z = -.5+i/planks
        p.box((-.5,.5),(height,1),(z,z+1/planks-.012),"wood", "wood_worn" if i%2 == 0 else "wood")


def bench(p):
    tabletop(p, .80, 3)
    for x in (-.45,-.15,.15,.45):
        p.box((x-.012,x+.012),(0,.80),(-.40,.40),"wood_dark")
    p.box((-.46,.46),(.25,.37),(-.045,.045),"wood")


def table(p, dining=False):
    tabletop(p)
    legs(p, positions=(-.43,-.14,.14,.43) if dining else (-.42,.42))
    p.box((-.43,.43),(.65,.84),(-.36,-.30),"wood_dark")


def desk(p):
    tabletop(p,.89)
    legs(p,.89)
    p.box((-.42,-.08),(.14,.86),(-.36,.38),"wood_dark")
    for y in (.2,.42,.64):
        p.box((-.40,-.10),(y,y+.17),(.38,.42),"wood")
        p.box((-.30,-.20),(y+.06,y+.09),(.42,.46),"brass_dark")


def workbench(p):
    table(p)
    p.box((-.43,.43),(.14,.22),(-.40,.40),"wood_dark")
    p.box((.24,.43),(.78,.95),(.43,.56),"iron")
    p.beam((.23,.82,.60),(.44,.82,.60),.018,"iron_worn",6)


def bunk(p, upper=False):
    if not upper:
        legs(p,.42)
    y = .0 if upper else .40
    p.box((-.5,.5),(y,y+.18),(-.5,.5),"wood_dark", "wood_worn")
    p.box((-.47,.47),(y+.18,y+.35),(-.46,.46),"cloth", "cloth_faded")
    p.box((-.43,-.25),(y+.35,y+.43),(-.37,.37),"cloth_faded")
    # 낮은 머리/발판이며 침상 주변을 막는 난간이 아니다.
    for x in (-.5,.47):
        p.box((x,x+.03),(y+.12,y+.37),(-.49,.49),"wood")


def blanket(p):
    # 한 장을 완만하게 접은 연속 천 표면. 소지품 더미가 아니다.
    xs = [-.5,-.36,-.12,.12,.32,.5]
    ys = [.01,.035,.012,.028,.0,.018]
    for i in range(len(xs)-1):
        a,b = xs[i:i+2]
        ya,yb = ys[i:i+2]
        c = "cloth_faded" if i%2 else "cloth"
        p.face([(a,ya,-.5),(b,yb,-.5),(b,yb,.5),(a,ya,.5)],c,(0,1,0))
        for z,sign in ((-.5,-1),(.5,1)):
            p.face([(a,-.01,z),(b,-.01,z),(b,yb,z),(a,ya,z)],"cloth",(0,0,sign))
    p.face([(-.5,-.01,-.5),(.5,-.01,-.5),(.5,-.01,.5),(-.5,-.01,.5)],"cloth",(0,-1,0))
    for i,sign in ((0,-1),(-1,1)):
        p.face([(xs[i],-.01,-.5),(xs[i],ys[i],-.5),(xs[i],ys[i],.5),(xs[i],-.01,.5)],"cloth",(sign,0,0))


def book(p):
    for y in (0,.87):
        p.box((-.5,.5),(y,y+.13),(-.5,.5),"wood_dark")
    p.box((-.46,.46),(.13,.87),(-.45,.46),"paper", "paper_aged")
    p.box((-.5,-.43),(.13,.87),(-.5,.5),"cloth")
    for y in (.30,.57):
        p.box((-.41,.44),(y,y+.025),(.46,.47),"paper_aged")


def sacks(p):
    # 식량 포대 두 개. 개인 가방/신발/옷 묶음은 포함하지 않는다.
    for x,z,h in ((-.22,-.1,.90),(.23,.12,1.0)):
        p.lathe((x,z),[(0,.20,.28),(.18,.24,.31),(h*.72,.22,.27),(h*.90,.10,.12),(h,.11,.13)],"cloth",8,"cloth_faded")


def crate(p, x, y, z, scale=1, opened=False):
    def b(ax,ay,az,c="wood"):
        p.box(tuple(x+a*scale for a in ax),tuple(y+a*scale for a in ay),tuple(z+a*scale for a in az),c)
    b((-.5,.5),(0,.08),(-.5,.5),"wood_dark")
    for h in (.08,.36,.64):
        for side in (-.5,.43):
            b((-.5,.5),(h,h+.23),(side,side+.07))
        for side in (-.5,.43):
            b((side,side+.07),(h,h+.23),(-.43,.43),"wood_worn")
    if not opened:
        b((-.5,.5),(.87,.94),(-.5,.5),"wood_worn")
    for side in (-.43,.35):
        b((side,side+.08),(.08,.87),(.5,.54),"wood_dark")


def crates(p, food=False):
    crate(p,-.52,0,0,.92,food)
    crate(p,.43,0,.03,.78,food)
    if food:
        for x in (-.70,-.42,.26,.52):
            p.lathe((x,0),[(.15,.09,.12),(.70,.11,.12),(.78,.08,.10)],"paper_aged",6,"paper")


def panel(p):
    p.box((-.5,.5),(0,1),(-.03,.01),"wood_dark")
    for i in range(8):
        x = -.5+i/8
        p.box((x+.003,x+.122),(.035,.965),(.01,.03),"wood" if i%2 else "wood_worn")


def supplies(p):
    p.box((-.5,.5),(0,.28),(-.5,.5),"cloth")
    p.box((-.46,.46),(.28,.44),(-.48,.48),"cloth_faded")
    p.lathe((-.18,0),[(.44,.19,.3),(.70,.19,.3)],"cloth_faded",8,"cloth")
    p.lathe((.23,0),[(.44,.18,.3),(.74,.18,.3)],"cloth",8,"cloth_faded")


def curtain(p):
    p.beam((-.5,1,0),(.5,1,0),.012,"brass_dark",6)
    for side in (-1,1):
        for i in range(3):
            x0 = side*(.19+i*.10)
            x1 = side*(.29+i*.10)
            p.face([(x0,.98,0),(x1,.98,.015),(x1,0,.015),(x0,.04,0)],"cloth" if i%2 else "cloth_faded",(0,0,1))
            p.face([(x0,.98,-.003),(x0,.04,-.003),(x1,0,.012),(x1,.98,.012)],"cloth",(0,0,-1))


def medicine(p):
    p.box((-.5,.5),(0,.88),(-.5,.5),"paper_aged")
    p.box((-.5,.5),(.88,1),(-.5,.5),"paper")
    p.box((-.28,.28),(.28,.64),(.5,.51),"paper")
    for y in (.36,.49):
        p.box((-.17,.17),(y,y+.035),(.51,.52),"wood_dark")


def pot(p):
    p.lathe((0,0),[(0,.30,.34),(.12,.40,.43),(.78,.42,.45),(.85,.46,.49),(.85,.38,.41),(.17,.29,.33)],"iron",12,"iron_worn")
    for x in (-.56,.56):
        p.box((x-.04,x+.04),(.57,.68),(-.18,.18),"iron_worn")
        p.box((min(x,0),max(x,0)),(.58,.64),(-.18,-.12),"iron")


def bowls(p):
    for x in (-.34,0,.34):
        p.lathe((x,0),[(0,.10,.21),(.18,.15,.29),(.24,.16,.30),(.24,.13,.26),(.06,.075,.15)],"paper",8,"paper_aged")


def board(p, slate=False, memorial=False):
    p.box((-.5,.5),(0,1),(-.04,0),"wood_dark")
    p.box((-.44,.44),(.06,.94),(0,.02),"soot" if slate else "paper_aged")
    for x in (-.5,.44):
        p.box((x,x+.06),(0,1),(0,.04),"wood_worn")
    for y in (0,.94):
        p.box((-.44,.44),(y,y+.06),(0,.04),"wood")
    if memorial:
        p.box((-.24,.24),(.70,.82),(.02,.03),"brass_dark")
    else:
        for y,width in ((.68,.60),(.49,.46),(.30,.55)):
            p.box((-.30,-.30+width),(y,y+.025),(.02,.03),"paper" if slate else "wood_dark")


def ballot(p):
    p.box((-.5,.5),(0,.87),(-.5,.5),"wood")
    # 상단 투입구는 실제 빈 틈. 잠금 장치는 없다.
    for z0,z1 in ((-.5,-.035),(.035,.5)):
        p.box((-.5,.5),(.87,1),(z0,z1),"wood_worn")
    for x0,x1 in ((-.5,-.25),(.25,.5)):
        p.box((x0,x1),(.87,1),(-.035,.035),"wood_worn")
    p.box((-.22,.22),(.32,.64),(.5,.51),"paper_aged")


def bell(p):
    p.lathe((0,0),[(0,.5,.5),(.10,.48,.48),(.23,.31,.31),(.63,.18,.18),(.72,.10,.10)],"brass",12,"brass_dark")
    p.beam((0,.72,0),(0,1,0),.065,"wood_dark",8)


def wrench(p):
    p.box((-.12,.12),(.08,.76),(-.08,.08),"iron_worn")
    p.box((-.25,.25),(0,.15),(-.09,.09),"iron")
    p.box((-.42,.42),(.70,.85),(-.10,.10),"iron")
    for x in (-.42,.20):
        p.box((x,x+.22),(.85,1),(-.10,.10),"iron_worn")


def ladle(p):
    p.lathe((0,0),[(0,.22,.22),(.10,.48,.48),(.22,.50,.50),(.22,.40,.40),(.07,.15,.15)],"iron",8,"iron_worn")
    p.beam((0,.16,-.38),(0,1,-.38),.055,"iron_worn",6)


def tools(p):
    p.box((-.5,.5),(0,.10),(-.5,.5),"wood_dark")
    p.box((-.40,-.31),(.10,.18),(-.39,.34),"wood_worn")
    p.box((-.5,-.20),(.10,.26),(.21,.39),"iron")
    p.box((-.08,.01),(.10,.18),(-.37,.33),"iron_worn")
    p.box((-.18,.11),(.10,.21),(.22,.30),"iron")
    p.box((.28,.34),(.10,.18),(-.35,.18),"iron_worn")
    p.box((.23,.39),(.10,.24),(.18,.40),"wood")


def shelf(p):
    p.box((-.5,.5),(.70,1),(-.5,.5),"wood", "wood_worn")
    for x in (-.39,.35):
        p.box((x,x+.04),(0,.70),(-.43,-.30),"iron")
        p.box((x,x+.04),(.55,.70),(-.30,.38),"iron_worn")


def radio(p):
    p.box((-.5,.5),(0,.85),(-.45,.36),"iron")
    p.box((-.43,.06),(.13,.72),(.36,.40),"soot")
    for i in range(5):
        p.box((-.39,.02),(.19+i*.10,.22+i*.10),(.40,.42),"iron_worn")
    p.box((.13,.42),(.50,.71),(.36,.42),"paper_aged")
    for x in (.20,.38):
        p.beam((x,.25,.36),(x,.25,.48),.065,"brass_dark",8)
    for x in (-.24,.20):
        p.box((x,x+.04),(.85,.98),(-.08,.03),"iron_worn")
    p.box((-.24,.24),(.96,1),(-.08,.03),"wood_dark")


def coal(p):
    # 긴 하나의 닫힌 능선 메시. 개별 석탄 오브젝트를 반복 배치하지 않는다.
    rings = []
    for i in range(9):
        x = -.5+i/8
        h = (.40,.73,.85,.69,1,.82,.92,.71,.35)[i]
        rings.append([(x,0,-.5),(x,h*.38,-.42),(x,h*.83,-.20),(x,h, .05),(x,h*.65,.32),(x,0,.5)])
    p.face(rings[0],"soot",(-1,0,0))
    p.face(rings[-1],"soot",(1,0,0))
    for k,(a,b) in enumerate(zip(rings,rings[1:])):
        for i in range(6):
            j = (i+1)%6
            colour = ("soot","iron","iron_worn")[(k+i)%3] if i < 5 else "soot"
            p.face([a[i],b[i],b[j],a[j]],colour,(0,1 if i<5 else -1,-1 if i<2 else 1))


def divider(p):
    # 얇은 독립 목재 칸막이. 창이나 출입구를 덮는 모델이 아니다.
    p.box((-.025,.025),(0,1),(-.5,.5),"wood_dark")
    for i in range(4):
        z = -.48+i*.24
        p.box((-.035,.035),(.08,.92),(z,z+.225),"wood" if i%2 else "wood_worn")


def platform(p):
    for z in (-.47,.39):
        p.box((-.5,.5),(0,.82),(z,z+.08),"iron")
    for x in (-.46,.38):
        p.box((x,x+.08),(0,.82),(-.39,.39),"iron")
    for i in range(4):
        z = -.5+i*.25
        p.box((-.5,.5),(.82,1),(z,z+.24),"iron", "iron_worn")


def boiler(p, stove=False):
    if stove:
        for x in (-.24,.24):
            for z in (-.24,.24):
                p.box((x-.04,x+.04),(0,.24),(z-.04,z+.04),"soot")
        p.lathe((0,0),[(.12,.33,.33),(.22,.44,.44),(.78,.41,.41)],"iron",10,"soot")
        p.box((-.5,.5),(.78,.86),(-.5,.5),"iron_worn")
        p.box((-.29,.29),(.29,.65),(.39,.46),"soot")
        p.box((.12,.24),(.42,.47),(.46,.50),"brass_dark")
        p.lathe((0,-.27),[(.86,.10,.10),(1,.10,.10)],"iron",8)
        return
    rings = []
    for x,r in ((-.5,.32),(-.47,.47),(.43,.47),(.50,.34)):
        rings.append([(x,.52+r*math.sin(i*math.tau/12),r*math.cos(i*math.tau/12)) for i in range(12)])
    p.face(rings[0],"soot",(-1,0,0))
    p.face(rings[-1],"iron_worn",(1,0,0))
    for a,b in zip(rings,rings[1:]):
        for i in range(12):
            j = (i+1)%12
            angle=(i+.5)*math.tau/12
            p.face([a[i],b[i],b[j],a[j]],"iron_worn" if i in (2,3) else "iron",(0,math.sin(angle),math.cos(angle)))
    for x in (-.34,.30):
        p.box((x-.025,x+.025),(0,.25),(-.33,.33),"soot")
    p.beam((-.36,.82,.44),(.30,.82,.44),.025,"brass_dark",8)
    p.beam((.20,.65,.42),(.20,.65,.54),.09,"brass",12)
    p.box((.195,.205),(.65,.71),(.54,.545),"soot")


BUILDERS = {
    "bench": (bench,"세 줄 긴 널과 네 받침을 가진 긴 의자"),
    "stove": (lambda p: boiler(p,True),"검댕 몸체·상판·짧은 연결구를 가진 난로"),
    "bunk_lower": (bunk,"낮은 다리·매트·베개를 가진 아래 침상"),
    "bunk_upper": (lambda p: bunk(p,True),"얇은 목재 받침과 매트·베개의 위 침상"),
    "book": (book,"표지·책등·누런 종이 단면이 분리된 책"),
    "blanket": (blanket,"완만한 접힘이 이어지는 한 장의 바랜 담요"),
    "sacks": (sacks,"개인 소지품 없는 식량 포대 두 개"),
    "workbench": (workbench,"하부 선반과 작은 바이스가 달린 작업대"),
    "crates": (crates,"널 틈과 보강대가 있는 화물 상자 두 개"),
    "insulation_panel": (panel,"8개 널 경계가 있는 긴 단열 패널"),
    "side_table": (table,"세 줄 상판과 네 다리의 좁은 탁자"),
    "supplies": (supplies,"가지런히 접은 의료용 천과 붕대 두 롤"),
    "curtain_half_open": (curtain,"가운데가 열린 양쪽 주름 커튼"),
    "medicine_box": (medicine,"문양 없이 가로 라벨이 있는 종이 약품 상자"),
    "dining_table": (lambda p: table(p,True),"긴 연속 상판과 여덟 다리의 식탁"),
    "cooking_pot": (pot,"속이 빈 솥과 양쪽 손잡이"),
    "bowls": (bowls,"속이 파인 누런 그릇 세 개"),
    "class_slate": (lambda p: board(p,True),"목재 테두리와 짧은 분필 선의 칠판"),
    "ballot_box": (ballot,"상단 투입 틈과 무문양 종이표의 투표함"),
    "bell": (bell,"황동 종 몸체와 짧은 목재 손잡이"),
    "wrench": (wrench,"벌어진 두 턱과 납작한 손잡이의 렌치"),
    "memorial_board": (lambda p: board(p,memorial=True),"목재 테두리 안의 빈 추모판과 황동 명판"),
    "ladle": (ladle,"오목한 국자 머리와 긴 손잡이"),
    "tools": (tools,"낮은 받침에 놓인 망치·스패너·드라이버"),
    "shelf": (shelf,"길쭉한 널과 두 개의 아래쪽 선반 받침"),
    "captain_desk": (desk,"서랍 세 칸과 황동 손잡이의 책상"),
    "radio": (radio,"스피커 슬롯·주파수 창·노브 둘의 라디오"),
    "coal_pile": (coal,"불규칙한 능선이 이어지는 긴 석탄 더미"),
    "food_crates": (lambda p: crates(p,True),"열린 식량 상자 두 개와 통 네 개"),
    "divider": (divider,"세로 널 네 줄이 보이는 얇은 목재 칸막이"),
    "empty_platform": (platform,"빈 화물용 받침의 금속 골조와 상판"),
    "storage_board": (board,"목재 테두리와 짧은 기록 선의 보관판"),
    "boiler": (boiler,"긴 단일 보일러 몸체·받침·배관·계기"),
}


def export(piece, path):
    mesh = bpy.data.meshes.new(piece.pid)
    obj = None
    try:
        piece.bm.to_mesh(mesh)
        attr = mesh.color_attributes["Col"]
        mesh.color_attributes.active_color = attr
        mesh.color_attributes.render_color_index = list(mesh.color_attributes).index(attr)
        obj = bpy.data.objects.new(piece.pid,mesh)
        bpy.context.scene.collection.objects.link(obj)
        for other in bpy.context.scene.objects:
            other.select_set(other == obj)
        bpy.context.view_layer.objects.active = obj
        bpy.ops.export_scene.gltf(filepath=str(path),export_format="GLB",use_selection=True,
            export_yup=True,export_apply=False,export_materials="NONE",export_texcoords=False,
            export_normals=True,export_tangents=False,export_vertex_color="ACTIVE",
            export_extras=False,export_animations=False)
    finally:
        if obj is not None:
            bpy.data.objects.remove(obj,do_unlink=True)
        bpy.data.meshes.remove(mesh)


def check_glb(path, expected_tris, size):
    data = path.read_bytes()
    magic,version,length = struct.unpack_from("<4sII",data)
    chunk_length,chunk_type = struct.unpack_from("<II",data,12)
    if (magic,version,length,chunk_type) != (b"glTF",2,len(data),0x4E4F534A):
        raise ValueError("GLB 머리 검사 실패")
    book = json.loads(data[20:20+chunk_length])
    if len(book.get("meshes",[])) != 1 or sum("mesh" in n for n in book.get("nodes",[])) != 1:
        raise ValueError("단일 메시 검사 실패")
    primitives = book["meshes"][0]["primitives"]
    if len(primitives) != 1:
        raise ValueError("단일 면 묶음 검사 실패")
    prim = primitives[0]
    if prim.get("mode",4) != 4 or "COLOR_0" not in prim["attributes"]:
        raise ValueError("삼각형·정점색 검사 실패")
    count = book["accessors"][prim["indices"]]["count"]
    if count % 3 or count//3 != expected_tris or not 0 < expected_tris <= TRIANGLE_LIMIT:
        raise ValueError("삼각형 수 검사 실패")
    if any(book.get(k) for k in ("materials","images","textures","animations","skins","cameras")):
        raise ValueError("불필요한 자원")
    if any("uri" in b for b in book.get("buffers",[])) or "KHR_lights_punctual" in book.get("extensions",{}):
        raise ValueError("외부 자원·빛 금지")
    pos = book["accessors"][prim["attributes"]["POSITION"]]
    bounds = [pos["min"],pos["max"]]
    for i in range(3):
        if abs(bounds[0][i]+size[i]/2) > 1e-5 or abs(bounds[1][i]-size[i]/2) > 1e-5:
            raise ValueError("중앙 기준·크기 검사 실패")
    return len(data), hashlib.sha256(data).hexdigest(), [[round(v,6)+0.0 for v in row] for row in bounds]


def dimensions(values):
    return "×".join("%g" % v for v in values)


def prepare_import(out_dir, pid):
    """엔진이 최종화할 가져오기 설정. GLB에는 재질을 넣지 않는다."""
    source = "res://models/train_interior/"+pid+".glb"
    dest = "res://.godot/imported/"+pid+".glb-"+hashlib.md5(source.encode()).hexdigest()+".scn"
    path = out_dir/(pid+".glb.import")
    if not path.exists():
        text = ('[remap]\n\nimporter="scene"\nimporter_version=1\ntype="PackedScene"\npath="'+dest+'"\n\n'
                '[deps]\n\nsource_file="'+source+'"\ndest_files=["'+dest+'"]\n\n[params]\n')
    else:
        text = path.read_text(encoding="utf-8")
    settings = {"import_script/path":'"res://models/train_interior/vertex_colors.gd"',
                "meshes/generate_lods":"false","meshes/create_shadow_meshes":"false",
                "meshes/ensure_tangents":"false","meshes/light_baking":"0"}
    lines = text.splitlines()
    for key,value in settings.items():
        found = False
        for i,line in enumerate(lines):
            if line.startswith(key+"="):
                lines[i] = key+"="+value
                found = True
                break
        if not found:
            lines.append(key+"="+value)
    path.write_text("\n".join(lines)+"\n",encoding="utf-8")


def write_books(out_dir, rows, failures, source_hash):
    total = sum(r["lod0_tris"] for r in rows)
    book = {"version":1,"script_version":SCRIPT_VERSION,"blender":bpy.app.version_string,
        "axis":"X right, +Y up, +Z front","origin":ORIGIN,"placement":PLACEMENT,
        "colour_encoding":"linear RGBA vertex colours, alpha 1","palette":PALETTE,
        "size_selection":"most frequent; ties use first occurrence in source rows",
        "source":"_in/train_interior_models.json","source_sha256":source_hash,
        "godot_import_script":"res://models/train_interior/vertex_colors.gd",
        "godot_material":"built-in StandardMaterial3D, vertex colour enabled on import; no material file",
        "triangle_limit":TRIANGLE_LIMIT,"total_triangle_limit":TOTAL_LIMIT,"total_triangles":total,
        "assets":{r["id"]:{k:v for k,v in r.items() if k != "id"} for r in rows},"failures":failures}
    (out_dir/"catalog.json").write_text(json.dumps(book,ensure_ascii=False,indent=2)+"\n",encoding="utf-8")
    (out_dir/"vertex_colors.gd").write_text(IMPORT_SCRIPT,encoding="utf-8")
    for row in rows:
        prepare_import(out_dir,row["id"])
    lines = ["# 열차 실내 가구 33종","","`tools/blender/train_interior.py`가 자동 생성한 장부.","",PLACEMENT,"",
        "크기는 glTF X×Y×Z m. 최다 사용 크기 기준이며 동률은 원본 rows의 첫 크기를 선택한다.",
        "종류마다 메시 1개·면 묶음 1개·Col 정점색. GLB 안에 재질·텍스처·빛·카메라 없음. 별도 셰이더 파일 없음.",
        "vertex_colors.gd는 가져올 때 엔진 내장 StandardMaterial3D의 정점색 표시를 켠다. 별도 재질 파일은 만들지 않는다.",
        ".import의 초기 설정은 이 스크립트가 준비하고 Godot --import가 최종화한다. 게임 코드는 수정할 필요가 없다.",
        "개별 상한 600, 전체 상한 8,000. 전체 삼각형: %d." % total,"",
        "```text","blender -b --factory-startup -P tools/blender/train_interior.py -- --repo .","```","",
        "| 이름 | 쓰임 수 | 기준 size | 실제 크기 | 삼각형 | 바이트 | 형태 |","|---|---:|---|---|---:|---:|---|"]
    for r in rows:
        lines.append("| %s | %d | %s | %s | %d | %d | %s |" % (r["id"],r["uses"],dimensions(r["reference_size_m"]),dimensions(r["dimensions_m"]),r["lod0_tris"],r["bytes"],r["use"]))
    lines += ["","## 다른 크기로 쓰인 이름","",
        "크기 차이는 자동으로 늘리거나 줄이지 않는다. 배치 코드는 원래 크기를 그대로 쓴다."]
    for r in rows:
        if len(r["size_variants"]) > 1:
            lines.append("- %s: %s. 기준 %s." % (r["id"],", ".join("%s (%d회)" % (dimensions(v["size_m"]),v["uses"]) for v in r["size_variants"]),dimensions(r["reference_size_m"])))
    lines += ["","## SHA-256","","| 이름 | sha256 |","|---|---|"]
    lines += ["| %s | %s |" % (r["id"],r["sha256"]) for r in rows]
    lines += ["","## 팔레트 (선형 RGB)",""]+["- %s: %s" % (k,dimensions(v[:3])) for k,v in PALETTE.items()]
    lines += ["","stove는 기존 코드의 stove_builder 분기로 건너뛰므로 파일만으로 교체되지 않는다.",
        "난로 기본 material 표기는 wood지만 금속 몸체이므로 iron/soot 계열을 썼다. 불 자리 모델은 만들지 않는다."]
    if failures:
        lines += ["","실패: "+json.dumps(failures,ensure_ascii=False)]
    (out_dir/"README.md").write_text("\n".join(lines)+"\n",encoding="utf-8")


def preview(repo, out_dir):
    """납품 GLB를 다시 열어 캐시에만 접촉 시트를 렌더한다. GLB에 카메라/빛 없음."""
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_WORKBENCH"
    scene.display.shading.light = "STUDIO"
    scene.display.shading.color_type = "VERTEX"
    scene.display.shading.show_shadows = True
    scene.display.shading.show_cavity = True
    scene.display.shading.cavity_type = "BOTH"
    scene.display.shading.background_type = "WORLD"
    scene.world = bpy.data.worlds.new("inspection_background")
    scene.world.color = (.065,.070,.078)
    scene.view_settings.view_transform = "Standard"
    for i,pid in enumerate(BUILDERS):
        before = set(bpy.data.objects)
        bpy.ops.import_scene.gltf(filepath=str(out_dir/(pid+".glb")))
        mesh_objects = [o for o in set(bpy.data.objects)-before if o.type == "MESH"]
        for obj in mesh_objects:
            obj.parent = None
            # 각 칸에서 비율을 유지해 축소한다. 긴 가구의 비율도 유지한다.
            obj.rotation_mode = "XYZ"
            obj.rotation_euler = (.35,0,-.45)
            bpy.context.view_layer.update()
            factor = 2.45/max(obj.dimensions)
            obj.scale = (factor,)*3
            obj.location = ((i%6)*3.6,0,-(i//6)*3.2)
        curve = bpy.data.curves.new("label","FONT")
        curve.body = pid
        curve.size = .18
        curve.align_x = "CENTER"
        label = bpy.data.objects.new("label",curve)
        scene.collection.objects.link(label)
        label.rotation_euler = (math.pi/2,0,0)
        label.location = ((i%6)*3.6,-2,-(i//6)*3.2-1.40)
        label.color = (.8,.8,.8,1)
    camera_data = bpy.data.cameras.new("inspection")
    camera = bpy.data.objects.new("inspection",camera_data)
    scene.collection.objects.link(camera)
    camera.location = (9,-30,-8)
    camera.rotation_euler = (Vector((9,0,-8))-camera.location).to_track_quat("-Z","Y").to_euler()
    camera_data.type = "ORTHO"
    camera_data.ortho_scale = 22
    scene.camera = camera
    scene.render.resolution_x = 2200
    scene.render.resolution_y = 2100
    scene.render.resolution_percentage = 100
    output = repo/"s2/.godot/train_interior_work/preview.png"
    output.parent.mkdir(parents=True,exist_ok=True)
    scene.render.filepath = str(output)
    bpy.ops.render.render(write_still=True)
    print("PREVIEW_READY",flush=True)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--repo",required=True)
    parser.add_argument("--preview",action="store_true")
    args = parser.parse_args(sys.argv[sys.argv.index("--")+1:] if "--" in sys.argv else [])
    repo = Path(args.repo).resolve()
    out_dir = repo/"s2/models/train_interior"
    if args.preview:
        preview(repo,out_dir)
        return
    source = repo/"_in/train_interior_models.json"
    census = json.loads(source.read_text(encoding="utf-8-sig"))
    life = json.loads((repo/"s2/game/train/train_life.json").read_text(encoding="utf-8-sig"))
    assert len(BUILDERS) == 33 and set(BUILDERS) == {r["model"] for r in census["rows"]}
    for name in ("wood","iron","cloth","paper","brass"):
        assert tuple(life["materials"][name]) == PALETTE[name][:3]
    out_dir.mkdir(parents=True,exist_ok=True)
    bpy.ops.wm.read_factory_settings(use_empty=True)
    rows,failures = [],[]
    for pid,(build,description) in BUILDERS.items():
        uses = [r for r in census["rows"] if r["model"] == pid]
        counts = Counter(tuple(r["size"]) for r in uses)
        size = counts.most_common(1)[0][0]
        piece = Piece(pid)
        try:
            build(piece)
            piece.fit(size)
            tris = len(piece.bm.faces)
            if not 0 < tris <= TRIANGLE_LIMIT:
                raise ValueError("삼각형 상한 초과")
            path = out_dir/(pid+".glb")
            export(piece,path)
            byte_count,digest,bounds = check_glb(path,tris,size)
            rows.append({"id":pid,"status":"ready","path":"res://models/train_interior/"+pid+".glb",
                "uses":len(uses),"reference_size_m":list(size),"dimensions_m":[round(bounds[1][i]-bounds[0][i],6) for i in range(3)],
                "size_variants":[{"size_m":list(s),"uses":n} for s,n in counts.items()],
                "source_materials":dict(Counter(r["material"] for r in uses)),"bounds_m":bounds,
                "origin":ORIGIN,"use":description,"lod0_tris":tris,"triangle_limit":TRIANGLE_LIMIT,
                "colours":sorted(piece.colours),"bytes":byte_count,"sha256":digest})
            print("TRAIN_READY %s tris=%d bytes=%d" % (pid,tris,byte_count),flush=True)
        except Exception as error:
            failures.append({"id":pid,"type":type(error).__name__,"reason":str(error)})
            print("TRAIN_FAILED %s %s" % (pid,error),flush=True)
        finally:
            piece.bm.free()
    if sum(r["lod0_tris"] for r in rows) > TOTAL_LIMIT:
        failures.append({"reason":"전체 삼각형 예산 초과"})
    write_books(out_dir,rows,failures,hashlib.sha256(source.read_bytes()).hexdigest())
    print("TRAIN_INTERIOR pieces=%d/33 triangles=%d/%d failures=%d" % (len(rows),sum(r["lod0_tris"] for r in rows),TOTAL_LIMIT,len(failures)),flush=True)
    if failures:
        raise SystemExit(1)


if __name__ == "__main__":
    main()
