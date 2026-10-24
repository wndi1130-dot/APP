"""지도 소품 A: 독립적인 정점색 조형, GLB 검사, 자동 장부.

blender -b --factory-startup -P tools/blender/props_field_a.py -- --repo .
Blender X=가로, Z=위, -Y=앞. glTF +Y=위, +Z=앞. 외부 자원 없음.
"""
import sys
sys.dont_write_bytecode = True
import argparse
from collections import Counter, defaultdict
import hashlib
import json
import math
from pathlib import Path
import re
import struct
import bpy
from mathutils import Vector

TRIANGLE_LIMIT = 600
# 선형 RGBA. 처음 여섯 색은 공용 소품과 같다.
PALETTE = {
    "wood": (0.24, 0.17, 0.11, 1.0),
    "worn_wood": (0.38, 0.29, 0.19, 1.0),
    "iron": (0.12, 0.15, 0.17, 1.0),
    "worn_metal": (0.28, 0.32, 0.33, 1.0),
    "cloth": (0.43, 0.41, 0.31, 1.0),
    "enamel": (0.68, 0.70, 0.66, 1.0),
    "snow": (0.82, 0.87, 0.88, 1.0),
    "bark": (0.19, 0.16, 0.13, 1.0),
    "rust": (0.30, 0.15, 0.075, 1.0),
    "glass": (0.20, 0.34, 0.38, 1.0),
    "rubber": (0.035, 0.043, 0.048, 1.0),
    "stone": (0.34, 0.36, 0.34, 1.0),
}

# 목표 높이와 선택 근거. 물건의 의미를 우선한 none 예외를 숨기지 않는다.
SPECS = {
    "bare_willow": (4.6, "잎 없는 버드나무; 가늘게 아래로 늘어진 가지, tree 높이 예외"),
    "map_cabinet": (0.48, "none 우세; 지도용 얇고 넓은 서랍 네 단, 손잡이는 앞면"),
    "record_shelf_row": (1.25, "기록 선반의 쓰임을 우선해 none 0.5m 예외; 긴 세 칸과 문서철"),
    "street_tree": (4.4, "가로수 의미를 우선한 tree; 눈 얹힌 좁은 맨가지 수관"),
    "firewood_pile": (0.85, "low 우세; 잘린 장작 여섯 토막과 위쪽 눈"),
    "car": (1.18, "low 1.3m 이하; 눈 쌓인 소형 승용차, +Z 앞을 지키며 4×2m 안에서 폭을 줄임"),
    "conductor_log_chest": (0.48, "none 우세; 운행일지용 닫힌 나무 궤와 금속 손잡이"),
    "shop_counter": (1.05, "low 우세; 앞 판과 안쪽 수납칸이 구분된 낡은 판매대"),
    "tin_crate": (0.48, "none 우세; 골진 양철 상자와 모서리 보강"),
    "fuel_can_group": (0.62, "low 우세; 뚜껑과 열린 손잡이가 있는 연료통 세 개"),
    "freezer_chest": (0.95, "low 우세; 닫힌 위 여닫이 법랑 냉동고와 전면 통풍구"),
    "tire_stack": (0.9, "low 우세; 중앙 구멍이 관통하는 고무 타이어 세 단"),
    "coal_heap": (0.8, "low 우세; 각진 석탄 덩어리, 주변부에만 잔설"),
    "candle_stand": (1.2, "low 우세; 세 갈래 촛대와 꺼진 초, 불빛 없음"),
    "bench": (0.95, "low 우세; 판자 좌판과 등받이를 가진 벤치"),
    "hand_bell": (0.4, "low 상한 내; 벌어진 종 입구와 나무 손잡이"),
    "salvage": (0.42, "rect 없는 자재 지점은 1×1m 가정; 목재와 금속 부품만 배치"),
    "plank_stack": (0.85, "low; 엇갈린 받침 위에 두께가 보이는 제재 판자 여섯 장"),
    "stone_wall_segment": (1.2, "low; 거친 돌 여섯 구획을 쌓은 낮은 담장과 눈 덮개"),
    "shopping_cart": (1.05, "low 우세; 빈 장바구니, 열린 격자와 손잡이 및 네 바퀴"),
    "bare_orchard_tree": (2.8, "tree; 낮게 갈라지고 잘린 끝이 보이는 과수원 맨나무"),
    "tip_up_flag": (0.48, "none; 낚시 받침과 감개, 낮은 천 깃발, 표식 없음"),
    "hymn_shelf": (1.2, "low 우세; 찬송가 책 네 묶음을 둔 세 단 나무 선반"),
    "tool_cart": (0.48, "none 우세; 바퀴와 손잡이가 있는 낮은 두 단 공구 수레"),
    "vestry_chest": (0.9, "low 우세; 장식표지 없는 닫힌 제의실 수납 궤"),
    "fuel_drum": (1.05, "low; 금속 띠 둘과 주입구가 있는 녹슨 연료 드럼통"),
    "parts_rack": (1.25, "low 우세; 금속 기둥과 부품 수납함을 가진 선반"),
    "car_window": (0.48, "rect 없는 조명 지점은 1×1m 가정; 빛 없는 유리창 부품으로만 제작"),
    "bread_rack": (1.2, "low 우세; 나무 쟁반 세 단과 각진 빵 여섯 개"),
    "gear_rack": (1.2, "장비 선반 의미를 우선해 none 0.5m 예외; 공구와 기계 부품만 수납"),
    "pew_row": (1.1, "low; 긴 좌판·등받이와 세 개 받침의 교회 의자 줄"),
    "radio_set": (0.45, "none 우세; 스피커 격자·주파수 창·다이얼과 접힌 안테나"),
    "net_pile": (0.42, "low 상한 내; 어구인 접힌 그물의 열린 격자, 소지품 없음"),
    "lamp_post": (3.6, "가로등 의미를 우선한 none 높이 예외; 꺼진 등기구, 광원 없음"),
    "firebox": (0.48, "rect 없는 조명 지점은 1×1m 가정; 꺼진 화실과 열린 빈 입구만 제작"),
    "ammo_crate": (0.48, "none 우세; 무표식 닫힌 탄약 상자, 외부 내용물 없음"),
    "quilted_vest": (0.12, "none; 평평하게 펼친 조끼 한 벌과 누빔 봉제선, 옷 더미 없음"),
    "frozen_reeds": (0.48, "none; 얼어 붙은 낮은 갈대 열두 줄기와 얇은 눈 받침"),
    "log_stack_high": (2.2, "wall 1.8m 이상; 2×9m 방향으로 길게 쌓인 통나무 여섯 본"),
    "hardware_rack": (1.2, "철물 선반 의미를 우선해 none 0.5m 예외; 고리·보강쇠·부품함"),
    "coupler_set": (0.42, "none 우세; 철도 연결기 머리와 축 부품 두 개, 사슬 없음"),
    "tool_rack": (1.25, "low; 긴 공구 세 자루를 기대 둔 열린 공구대"),
    "work_site": (0.45, "rect 없는 작업 지점은 1×1m 가정; 받침 둘과 작업판·공구, 구획 없음"),
    "ice_cut_pool": (0.08, "none; 잘라낸 얼음 가장자리와 낮은 얼음면, 물 효과 없음"),
    "lamp_shelf": (0.48, "none 우세; 낮은 선반 위 꺼진 손등 두 개, 빛과 불꽃 없음"),
    "rope_coil": (0.24, "low 상한 내; 두 겹 밧줄 고리와 풀린 끝, 사람용 구속물 없음"),
    "notice_board": (1.85, "게시판 쓰임을 우선한 none 높이 예외; 기둥 둘과 무문자 공지판"),
    "blanket_crate": (0.48, "none 우세; 덮개가 닫힌 담요 보관 상자, 밖으로 쌓인 옷 없음"),
    "glass_cabinet": (1.25, "유리 수납장 의미를 우선해 none 0.5m 예외; 불투명 청회색 유리"),
    "fieldstone_wall": (1.2, "low; 길게 이어진 들돌 담장 세 단과 군데군데 잔설"),
}


class Piece:
    def __init__(self, name):
        self.name, self.verts, self.faces, self.colors = name, [], [], []

    def face(self, pts, color, outward):
        pts = [Vector(p) for p in pts]
        normal = (pts[1] - pts[0]).cross(pts[2] - pts[0])
        if normal.dot(Vector(outward)) < 0:
            pts.reverse()
        start = len(self.verts)
        self.verts.extend(pts)
        for i in range(1, len(pts) - 1):
            self.faces.append((start, start + i, start + i + 1))
            self.colors.append(color)

    def box(self, x, y, z, c="wood"):
        a, b = x; d, e = y; f, g = z
        self.face([(a,d,f),(a,e,f),(b,e,f),(b,d,f)],c,(0,0,-1))
        self.face([(a,d,g),(b,d,g),(b,e,g),(a,e,g)],c,(0,0,1))
        self.face([(a,d,f),(b,d,f),(b,d,g),(a,d,g)],c,(0,-1,0))
        self.face([(a,e,f),(a,e,g),(b,e,g),(b,e,f)],c,(0,1,0))
        self.face([(a,d,f),(a,d,g),(a,e,g),(a,e,f)],c,(-1,0,0))
        self.face([(b,d,f),(b,e,f),(b,e,g),(b,d,g)],c,(1,0,0))

    def beam(self, a, b, r, c="iron", sides=4, r2=None, cap=None):
        a, b = Vector(a), Vector(b)
        axis = (b-a).normalized()
        u = axis.cross(Vector((0,0,1)) if abs(axis.z)<0.9 else Vector((0,1,0))).normalized()
        v = axis.cross(u)
        rings = [[point+(u*math.cos(i*math.tau/sides)+v*math.sin(i*math.tau/sides))*rad
                  for i in range(sides)] for point,rad in ((a,r),(b,r if r2 is None else r2))]
        for i in range(sides):
            j=(i+1)%sides
            self.face([rings[0][i],rings[0][j],rings[1][j],rings[1][i]],c,(rings[0][i]+rings[0][j])/2-a)
        self.face(rings[0],cap or c,-axis)
        self.face(rings[1],cap or c,axis)

    def ring(self, center, rx, ry, thick, c="rubber", n=10):
        x,y,z=center
        rings=[]
        for i in range(n):
            angle=i*math.tau/n
            rings.append([(x+(rx+thick*math.cos(j*math.tau/4))*math.cos(angle),
                           y+(ry+thick*math.cos(j*math.tau/4))*math.sin(angle),
                           z+thick*math.sin(j*math.tau/4)) for j in range(4)])
        for i in range(n):
            for j in range(4):
                a=rings[i][j]; b=rings[(i+1)%n][j]; d=rings[i][(j+1)%4]
                outward=(Vector(a)+Vector(b)+Vector(d))/3-Vector((x+rx*math.cos((i+.5)*math.tau/n),y+ry*math.sin((i+.5)*math.tau/n),z))
                self.face([a,b,rings[(i+1)%n][(j+1)%4],d],c,outward)

    def fit(self, footprint, height):
        lo=[min(v[i] for v in self.verts) for i in range(3)]
        hi=[max(v[i] for v in self.verts) for i in range(3)]
        occupied=list(footprint)
        if self.name=="car": occupied[0]=min(occupied[0],1.8)
        if self.name=="hand_bell": occupied=[.32,.32]
        if self.name=="quilted_vest": occupied=[.65,.85]
        if self.name=="car_window": occupied[1]=.12
        if self.name=="notice_board": occupied[1]=.30
        scale=[occupied[0]*.96/(hi[0]-lo[0]), occupied[1]*.96/(hi[1]-lo[1]), height/(hi[2]-lo[2])]
        for v in self.verts:
            for i in range(3):
                v[i]=(v[i]-(lo[i] if i==2 else (lo[i]+hi[i])/2))*scale[i]

    def mesh(self):
        mesh=bpy.data.meshes.new(self.name)
        mesh.from_pydata(self.verts, [], self.faces)
        mesh.update()
        attr=mesh.color_attributes.new(name="Col",type="FLOAT_COLOR",domain="CORNER")
        for poly,c in zip(mesh.polygons,self.colors):
            for loop in poly.loop_indices:
                attr.data[loop].color=PALETTE[c]
        mesh.color_attributes.active_color=attr
        mesh.color_attributes.render_color_index=0
        return mesh


def tree(p, willow=False, orchard=False):
    p.beam((0,0,0),(.015,.02,.7),.075,"bark",5,.035,"worn_wood")
    for i in range(5):
        a=i*math.tau/5+.15
        x,y=math.cos(a),math.sin(a)
        mid=(x*.25,y*.25,.82 if not orchard else .62)
        end=(x*.43,y*.43,.94 if not willow else .72)
        p.beam((.01,0,.43),mid,.032,"bark",4,.020)
        p.beam(mid,end,.020,"bark",4,.010,"worn_wood")
        if willow:
            p.beam(end,(x*.46,y*.46,.23+.04*(i%2)),.011,"bark",4,.004)
        else:
            p.beam(mid,(x*.19-y*.15,y*.19+x*.15,1),.018,"bark",4,.008,"worn_wood")
    if not willow:
        p.box((-.09,.07),(-.09,.09),(.17,.20),"snow")


def chest(p, metal=False, drawers=0, straps=False):
    p.box((-.48,.48),(-.43,.43),(0,.88),"worn_metal" if metal else "wood")
    p.box((-.5,.5),(-.46,.46),(.88,1),"worn_metal" if metal else "worn_wood")
    if drawers:
        for i in range(drawers):
            z=.08+i*.79/drawers
            p.box((-.45,.45),(-.46,-.43),(z,z+.70/drawers),"worn_wood")
            p.box((-.14,.14),(-.5,-.46),(z+.24/drawers,z+.37/drawers),"iron")
    else:
        p.box((-.16,.16),(-.49,-.43),(.56,.64),"iron")
        for x in (-.36,.32):
            p.box((x,x+.04),(-.46,.46),(.98,1.015),"iron" if straps else "wood")
            if straps:
                p.box((x,x+.04),(-.451,-.431),(.04,.88),"iron")
    if metal:
        for x in (-.34,-.17,0,.17,.34):
            p.box((x-.018,x+.018),(-.455,-.43),(.10,.78),"iron")


def rack(p, kind):
    metal=kind in ("parts_rack","gear_rack","hardware_rack","tool_rack")
    c="iron" if metal else "wood"
    for x in (-.48,.44):
        for y in (-.44,.40):
            p.box((x,x+.04),(y,y+.04),(0,1),c)
    for z in (.06,.48,.94):
        p.box((-.49,.49),(-.45,.45),(z,z+.045),"worn_metal" if metal else "worn_wood")
    if kind=="record_shelf_row":
        for x in (-.16,.16):
            p.box((x-.016,x+.016),(-.4,.4),(.1,.94),"wood")
        for i in range(7):
            x=-.42+i*.13
            p.box((x,x+.095),(-.33,.32),(.12 if i%2 else .54,.42 if i%2 else .85),"cloth" if i%3 else "enamel")
    elif kind=="hymn_shelf":
        for x in (-.38,-.17,.06,.28):
            p.box((x,x+.13),(-.3,.25),(.53,.83),"cloth")
            p.box((x+.02,x+.11),(-.31,-.30),(.63,.66),"worn_wood")
    elif kind=="bread_rack":
        for z in (.12,.54):
            for x in (-.29,0,.29):
                p.beam((x,-.26,z+.06),(x,.22,z+.06),.11,"worn_wood",6,.08)
    elif kind=="tool_rack":
        for x in (-.30,0,.30):
            p.beam((x,-.1,.15),(x,.18,.90),.024,"wood")
            p.box((x-.11,x+.11),(.10,.25),(.83,.96),"worn_metal")
    else:
        for x in (-.36,.04):
            p.box((x,x+.27),(-.35,.28),(.12,.34),"rust" if kind=="hardware_rack" else "worn_metal")
        if kind=="gear_rack":
            p.ring((-.23,0,.61),.14,.20,.04,"iron",8)
            p.beam((.1,-.2,.58),(.36,.25,.74),.06,"worn_metal",6)
        elif kind=="hardware_rack":
            p.ring((-.22,0,.59),.13,.18,.03,"iron",8)
            p.box((.1,.37),(-.25,.27),(.55,.64),"rust")
        else:
            p.beam((-.26,-.25,.63),(-.26,.25,.63),.10,"iron",6)
            p.box((.06,.35),(-.28,.27),(.54,.72),"rust")


def logs(p, high=False):
    for z,xs in ((.17,(-.32,0,.32)),(.46,(-.16,.16)),(.75,(0,))):
        for x in xs:
            p.beam((x,-.49,z),(x,.49,z),.16,"bark",6,cap="worn_wood")
    p.box((-.12,.12),(-.44,.43),(.88,.94),"snow")
    if high:
        p.box((-.48,-.42),(-.48,.48),(0,.24),"wood")
        p.box((.42,.48),(-.48,.48),(0,.24),"wood")


def car(p):
    p.box((-.44,.44),(-.48,.48),(.20,.53),"worn_metal")
    p.box((-.36,.36),(-.14,.28),(.53,.84),"glass")
    p.box((-.38,.38),(-.15,.29),(.84,.88),"worn_metal")
    for x in (-.39,.35):
        for y in (-.15,.25):
            p.box((x,x+.04),(y,y+.045),(.53,.87),"iron")
    for x in (-.46,.46):
        for y in (-.30,.30):
            p.beam((x-.035,y,.22),(x+.035,y,.22),.16,"rubber",8)
            p.beam((x-.04,y,.22),(x+.04,y,.22),.07,"worn_metal",6)
    p.box((-.42,.42),(-.50,-.47),(.23,.33),"iron")
    for x in (-.35,.23):
        p.box((x,x+.12),(-.487,-.48),(.41,.47),"enamel")
    p.box((-.37,.33),(-.13,.27),(.88,.97),"snow")
    p.box((-.40,.36),(-.44,-.17),(.53,.60),"snow")
    p.box((-.37,.39),(.31,.45),(.53,.59),"snow")


def fuel_cans(p):
    for x,y in ((-.29,-.10),(.02,.12),(.30,-.06)):
        p.box((x-.13,x+.13),(y-.28,y+.28),(0,.70),"rust" if x<0 else "worn_metal")
        p.box((x-.12,x+.12),(y-.25,y+.25),(.70,.77),"iron")
        p.box((x-.10,x-.06),(y-.08,y+.16),(.77,.98),"iron")
        p.box((x+.06,x+.10),(y-.08,y+.16),(.77,.98),"iron")
        p.box((x-.10,x+.10),(y-.08,y+.16),(.94,1),"iron")
        p.beam((x,y-.20,.77),(x,y-.20,.84),.045,"worn_metal",6)


def bench(p, pew=False):
    for x in ((-.43,0,.43) if pew else (-.37,.37)):
        p.box((x-.03,x+.03),(-.30,.29),(0,.50),"wood" if pew else "iron")
        p.box((x-.03,x+.03),(.28,.35),(.45,1),"wood")
    for y in (-.33,-.1,.13):
        p.box((-.49,.49),(y,y+.20),(.48,.55),"worn_wood")
    for z in (.72,.88):
        p.box((-.49,.49),(.29,.36),(z,z+.12),"worn_wood")
    if not pew:
        p.box((-.42,.29),(-.29,-.1),(.55,.58),"snow")


def cart(p, shopping=False):
    for x in (-.36,.36):
        for y in (-.32,.31):
            p.beam((x-.035,y,.1),(x+.035,y,.1),.10,"rubber",6)
            p.beam((x,y,.1),(x,y,.25),.025,"iron")
    p.box((-.38,.38),(-.34,.34),(.23,.28),"iron")
    for x in (-.37,.37):
        p.beam((x,-.3,.22),(x,.28,.95),.022,"iron")
        p.beam((x,.28,.95),(x,.47,.96),.025,"iron")
    p.beam((-.37,.47,.96),(.37,.47,.96),.034,"rubber")
    if shopping:
        p.box((-.38,.38),(-.4,.26),(.48,.52),"worn_metal")
        for x in (-.38,.38):
            for z in (.67,.9):
                p.beam((x,-.4,z),(x,.27,z),.014,"worn_metal")
            for y in (-.4,-.08,.27):
                p.beam((x,y,.5),(x,y,.9),.014,"worn_metal")
        for y in (-.4,.27):
            p.beam((-.38,y,.9),(.38,y,.9),.018,"iron")
            for x in (-.22,0,.22):
                p.beam((x,y,.50),(x,y,.90),.013,"worn_metal")
    else:
        p.box((-.40,.40),(-.35,.30),(.68,.75),"worn_metal")
        p.box((-.29,-.02),(-.25,.2),(.75,.91),"rust")
        p.beam((.13,-.23,.78),(.13,.22,.78),.025,"wood")
        p.box((.06,.23),(.15,.23),(.76,.83),"iron")


def wall(p, field=False):
    n=7 if field else 5
    for row in range(3):
        for i in range(n):
            x=-.5+i/n
            p.box((x+.009,x+1/n-.009),(-.46+.025*(i%2),.44),
                  (row*.30+.01,row*.30+.27+.015*(i%3)),"stone" if (i+row)%3 else "worn_metal")
    for i in (0,2,4):
        x=-.5+i/n
        p.box((x+.01,min(.49,x+1.3/n)),(-.38,.32),(.88,.94),"snow")


def lamp(p, x=0, scale=1):
    p.beam((x,0,.2),(x,0,.25),.18*scale,"iron",6)
    p.box((x-.12*scale,x+.12*scale),(-.12*scale,.12*scale),(.25,.72),"glass")
    for dx in (-.14,.14):
        p.beam((x+dx*scale,0,.25),(x+dx*scale,0,.75),.018*scale,"iron")
    p.beam((x,0,.73),(x,0,.82),.17*scale,"iron",6,.05*scale)


def build(p, k):
    if k in ("bare_willow","street_tree","bare_orchard_tree"):
        tree(p,k=="bare_willow",k=="bare_orchard_tree")
    elif k in ("map_cabinet","conductor_log_chest","tin_crate","vestry_chest","ammo_crate","blanket_crate"):
        chest(p,k=="tin_crate",4 if k=="map_cabinet" else 0,k in ("ammo_crate","vestry_chest"))
    elif k in ("record_shelf_row","hymn_shelf","parts_rack","bread_rack","gear_rack","hardware_rack","tool_rack"):
        rack(p,k)
    elif k in ("firewood_pile","log_stack_high"):
        logs(p,k=="log_stack_high")
    elif k=="car": car(p)
    elif k=="fuel_can_group": fuel_cans(p)
    elif k in ("bench","pew_row"): bench(p,k=="pew_row")
    elif k in ("tool_cart","shopping_cart"): cart(p,k=="shopping_cart")
    elif k in ("stone_wall_segment","fieldstone_wall"): wall(p,k=="fieldstone_wall")
    elif k=="shop_counter":
        p.box((-.5,.5),(-.5,.5),(.91,1),"worn_wood")
        p.box((-.47,.47),(-.44,-.38),(.05,.91),"wood")
        for x in (-.47,-.02,.43): p.box((x,x+.04),(-.38,.42),(0,.91),"wood")
        for z in (.08,.46): p.box((-.47,.47),(-.38,.42),(z,z+.05),"worn_wood")
        p.box((-.46,.46),(-.45,-.44),(.10,.17),"iron")
    elif k=="freezer_chest":
        p.box((-.47,.47),(-.44,.44),(.05,.86),"enamel")
        p.box((-.49,.49),(-.46,.46),(.86,.90),"rubber")
        p.box((-.5,.5),(-.47,.47),(.90,1),"enamel")
        p.box((-.13,.13),(-.50,-.44),(.76,.82),"iron")
        for z in (.12,.20,.28): p.box((.19,.4),(-.45,-.44),(z,z+.025),"iron")
        for x in (-.40,.34): p.box((x,x+.06),(-.38,.38),(0,.05),"iron")
    elif k=="tire_stack":
        for z in (.15,.44,.73): p.ring((0,0,z),.32,.32,.14,"rubber",10)
        p.box((-.22,.25),(.19,.33),(.85,.89),"snow")
    elif k=="coal_heap":
        for x,y,z,r in ((-.25,-.18,.18,.24),(.20,-.22,.18,.25),(-.20,.22,.18,.25),(.25,.22,.18,.22),(0,0,.44,.29)):
            p.beam((x,y,z-r*.5),(x+.025,y,z+r*.6),r,"rubber",5,r*.45)
        p.box((-.35,-.18),(.15,.34),(.34,.37),"snow")
    elif k=="candle_stand":
        p.beam((0,0,.02),(0,0,.08),.27,"iron",6)
        p.beam((0,0,.08),(0,0,.75),.04,"iron",6)
        p.beam((-.32,0,.65),(.32,0,.65),.025,"worn_metal")
        for x,z in ((-.32,.67),(0,.78),(.32,.67)):
            p.beam((x,0,z),(x,0,z+.03),.12,"iron",6)
            p.beam((x,0,z+.03),(x,0,z+.22),.04,"enamel",6)
            p.beam((x,0,z+.22),(x,0,z+.24),.008,"rubber",4)
    elif k=="hand_bell":
        p.beam((0,0,.04),(0,0,.43),.40,"worn_metal",10,.14)
        p.beam((0,0,.43),(0,0,.49),.14,"iron",8)
        p.beam((0,0,.49),(0,0,.95),.07,"wood",6,.09)
        p.beam((0,0,.01),(0,0,.06),.23,"iron",8)
    elif k in ("salvage","work_site"):
        for x in (-.34,.26): p.box((x,x+.08),(-.38,.38),(0,.28),"wood")
        for y in (-.3,-.02,.26): p.box((-.48,.48),(y,y+.20),(.28,.37),"worn_wood")
        p.beam((-.27,0,.42),(.27,.1,.42),.04,"iron",6)
        p.box((.14,.29),(.02,.24),(.39,.50),"rust")
        if k=="salvage": p.ring((-.23,.05,.41),.13,.16,.035,"iron",8)
    elif k=="plank_stack":
        for y in (-.32,.26): p.box((-.48,.48),(y,y+.10),(0,.15),"wood")
        for z in (.16,.32,.48):
            for x in (-.47,.02): p.box((x,x+.44),(-.48,.48),(z,z+.12),"worn_wood" if z<.4 else "wood")
        p.box((-.37,.38),(-.41,-.30),(.60,.63),"snow")
    elif k=="tip_up_flag":
        p.box((-.44,.44),(-.15,.15),(0,.08),"worn_wood")
        p.beam((.07,0,.08),(.07,0,.95),.019,"iron")
        p.box((.07,.42),(-.025,.025),(.70,.93),"cloth")
        p.beam((-.16,-.10,.30),(-.16,.10,.30),.14,"wood",8)
    elif k=="fuel_drum":
        p.beam((0,0,.02),(0,0,.94),.43,"rust",10)
        for z in (.18,.72): p.beam((0,0,z),(0,0,z+.07),.46,"iron",10)
        p.beam((.20,0,.94),(.20,0,1),.06,"iron",6)
        p.box((-.26,.10),(-.20,.24),(.94,.96),"snow")
    elif k=="car_window":
        p.box((-.44,.44),(-.035,.035),(.06,.94),"glass")
        for x in (-.50,.44): p.box((x,x+.06),(-.07,.07),(0,1),"iron")
        for z in (0,.94): p.box((-.5,.5),(-.07,.07),(z,z+.06),"worn_metal")
        p.box((-.46,.39),(-.08,-.07),(.08,.16),"snow")
    elif k=="radio_set":
        p.box((-.48,.48),(-.37,.37),(0,.78),"wood")
        p.box((-.43,-.02),(-.39,-.37),(.13,.65),"rubber")
        for x in (-.39,-.30,-.21,-.12): p.box((x,x+.026),(-.41,-.39),(.15,.63),"worn_metal")
        p.box((.07,.40),(-.39,-.37),(.49,.64),"glass")
        for x in (.13,.34): p.beam((x,-.38,.25),(x,-.46,.25),.065,"iron",8)
        p.beam((-.36,.15,.78),(.38,.15,.98),.018,"iron")
    elif k=="net_pile":
        for layer in range(2):
            for i in range(6):
                t=-.43+i*.17
                p.beam((t,-.43,.05+layer*.07),(t,.43,.13+layer*.07),.012,"cloth")
                p.beam((-.43,t,.06+layer*.07),(.43,t,.14+layer*.07),.012,"cloth")
        p.ring((0,0,.17),.32,.32,.025,"wood",8)
    elif k=="lamp_post":
        p.beam((0,0,0),(0,0,.07),.19,"iron",6)
        p.beam((0,0,.07),(0,0,.82),.045,"iron",6,.03)
        p.box((-.14,.14),(-.14,.14),(.82,.96),"glass")
        for x in (-.15,.15): p.beam((x,0,.81),(x,0,.96),.014,"iron")
        p.beam((0,0,.96),(0,0,1),.22,"iron",4,.03)
    elif k=="firebox":
        p.box((-.5,.5),(-.42,.42),(0,.12),"iron")
        p.box((-.5,-.35),(-.42,.42),(.12,.90),"worn_metal")
        p.box((.35,.5),(-.42,.42),(.12,.90),"worn_metal")
        p.box((-.35,.35),(.30,.42),(.12,.90),"rubber")
        p.box((-.5,.5),(-.42,.42),(.90,1),"iron")
        p.box((-.31,.31),(-.38,.28),(.12,.17),"rubber")
    elif k=="quilted_vest":
        for x in (-.37,.04):
            p.box((x,x+.33),(-.40,.28),(0,.07),"cloth")
            p.box((x+.04,x+.27),(.28,.45),(0,.07),"cloth")
            for y in (-.30,-.10,.10): p.box((x+.01,x+.32),(y,y+.012),(.07,.075),"wood")
        p.box((-.36,.36),(-.42,-.34),(0,.07),"cloth")
    elif k=="frozen_reeds":
        p.box((-.46,.46),(-.45,.45),(0,.03),"snow")
        for i in range(12):
            x=-.36+(i%4)*.23; y=-.33+(i//4)*.29; z=.5+(i%3)*.20
            p.beam((x,y,.03),(x+.07,y+.03,z),.012,"worn_wood")
            p.beam((x+.07,y+.03,z-.13),(x+.08,y+.03,z+.05),.032,"bark",4)
    elif k=="coupler_set":
        for x,y in ((-.23,-.12),(.21,.12)):
            p.box((x-.1,x+.1),(y-.35,y+.15),(.02,.20),"iron")
            p.box((x-.17,x+.17),(y+.06,y+.28),(.04,.34),"worn_metal")
            p.box((x+.07,x+.17),(y-.03,y+.12),(.08,.34),"rust")
    elif k=="ice_cut_pool":
        p.box((-.44,.44),(-.44,.44),(0,.02),"glass")
        for x in (-.50,.43): p.box((x,x+.07),(-.5,.5),(0,.08),"snow")
        for y in (-.50,.43): p.box((-.43,.43),(y,y+.07),(0,.08),"snow")
        p.box((-.37,-.12),(.10,.39),(.02,.055),"enamel")
    elif k=="lamp_shelf":
        for x in (-.44,.38): p.box((x,x+.06),(-.3,.3),(0,.22),"wood")
        p.box((-.5,.5),(-.36,.36),(.17,.24),"worn_wood")
        lamp(p,-.25,.7); lamp(p,.25,.7)
    elif k=="rope_coil":
        for z,rx,ry in ((.05,.34,.31),(.14,.29,.27)):
            p.ring((0,0,z),rx,ry,.045,"worn_wood",12)
        p.beam((.31,.10,.05),(.48,.30,.04),.035,"wood",6)
    elif k=="notice_board":
        for x in (-.40,.40): p.box((x-.025,x+.025),(-.07,.07),(0,1),"wood")
        p.box((-.49,.49),(-.04,.07),(.38,.94),"worn_wood")
        for x,z in ((-.35,.53),(-.06,.65),(.18,.48)):
            p.box((x,x+.20),(-.051,-.041),(z,z+.19),"enamel")
        p.box((-.5,.5),(-.11,.12),(.94,1),"iron")
        p.box((-.48,.40),(-.09,.10),(1,1.015),"snow")
    elif k=="glass_cabinet":
        for x in (-.48,.42): p.box((x,x+.06),(-.43,.43),(0,1),"wood")
        for z in (.08,.50,.94): p.box((-.48,.48),(-.43,.43),(z,z+.06),"worn_wood")
        p.box((-.42,.42),(.39,.43),(.14,.94),"wood")
        for x in (-.40,.02): p.box((x,x+.38),(-.435,-.42),(.16,.92),"glass")
        p.box((-.02,.02),(-.46,-.42),(.12,.94),"wood")
        for x in (-.06,.04): p.box((x,x+.02),(-.49,-.46),(.46,.59),"iron")
    else:
        raise ValueError("조형 정의 없음: "+k)


def source_stats(repo, kinds):
    counts=defaultdict(Counter); rects=defaultdict(Counter); contexts=defaultdict(Counter)
    for path in sorted((repo/"s2/game/world/maps").glob("*.gd")):
        text=re.sub(r"\}\s*,\s*\{", "}\n{", path.read_text(encoding="utf-8-sig"))
        for line in text.splitlines():
            match=re.search(r'"kind"\s*:\s*"([^"]+)"',line)
            if not match or match[1] not in kinds: continue
            k=match[1]; counts[path.stem][k]+=1
            rect=re.search(r'"rect"\s*:\s*(?:Rect2i\(|\[)\s*(-?\d+)\s*,\s*(-?\d+)\s*,\s*(\d+)\s*,\s*(\d+)',line)
            if rect:
                rects[k][(int(rect[3]),int(rect[4]))]+=1
                contexts[k]["rect"]+=1
            else: contexts[k]["cell_or_expression"]+=1
    return counts,rects,contexts


def check_glb(path, tris):
    data=path.read_bytes()
    magic,version,size=struct.unpack_from("<4sII",data)
    length,ctype=struct.unpack_from("<II",data,12)
    assert (magic,version,size,ctype)==(b"glTF",2,len(data),0x4E4F534A)
    doc=json.loads(data[20:20+length])
    assert len(doc["meshes"])==1 and sum("mesh" in n for n in doc["nodes"])==1
    prims=doc["meshes"][0]["primitives"]
    assert len(prims)==1 and prims[0].get("mode",4)==4
    prim=prims[0]
    assert "COLOR_0" in prim["attributes"]
    assert doc["accessors"][prim["indices"]]["count"]==tris*3
    assert not any(doc.get(k) for k in ("materials","images","textures","animations","skins","cameras"))
    assert "KHR_lights_punctual" not in doc.get("extensionsUsed",[])
    assert not any("uri" in b for b in doc["buffers"])
    a=doc["accessors"][prim["attributes"]["POSITION"]]
    return len(data),hashlib.sha256(data).hexdigest(),[a["min"],a["max"]]


def export(p, path):
    mesh=p.mesh(); obj=bpy.data.objects.new(p.name,mesh)
    bpy.context.scene.collection.objects.link(obj)
    for other in bpy.context.scene.objects: other.select_set(other==obj)
    bpy.context.view_layer.objects.active=obj
    bpy.ops.export_scene.gltf(filepath=str(path),export_format="GLB",use_selection=True,
        export_yup=True,export_apply=False,export_materials="NONE",export_texcoords=False,
        export_normals=True,export_tangents=False,export_vertex_color="ACTIVE",
        export_extras=False,export_animations=False)
    bpy.data.objects.remove(obj,do_unlink=True); bpy.data.meshes.remove(mesh)


def write_books(out, source, rows, counts, contexts):
    totals={m:sum(rows[k]["lod0_tris"]*n for k,n in c.items() if k in rows) for m,c in counts.items()}
    top=max(totals,key=totals.get)
    book={"schema_version":1,"generator":"tools/blender/props_field_a.py",
        "input_sha256":hashlib.sha256(source.read_bytes()).hexdigest(),"palette_linear_rgba":PALETTE,
        "placement":"rect 가운데 바닥; +Y 위, +Z 앞; facing 0~3은 Y축 -90도씩; 회전 후 크기 보정 없음",
        "assets":rows,"skipped":{},"source_context_counts":contexts,
        "ground_like_excluded":json.loads(source.read_text(encoding="utf-8-sig"))["skip_ground_like"],
        "source_line_estimate":{"per_map_triangles":totals,"max_map":top,"max_triangles":totals[top],
            "method":"지도 원문 kind 출현 수 × A종 삼각형. 반복문 실행 수·다른 소품·건물 제외; 런타임 총량 아님"}}
    (out/"catalog_a.json").write_text(json.dumps(book,ensure_ascii=False,indent=2)+"\n",encoding="utf-8")
    lines=["# 지도 소품 A", "", "`tools/blender/props_field_a.py`가 생성한 자동 장부.","",
        "```", "blender -b --factory-startup -P tools/blender/props_field_a.py -- --repo .", "```","",
        book["placement"],"", "종류당 메시 1개·면 묶음 1개, Col 정점색, 재질·그림·광원·애니메이션 없음.","",
        "rect가 비어 있던 버드나무·낚시깃대·얼음자리는 지도 Rect2i 최빈값으로 보완했다. rect가 없는 지점·조명 4종은 1×1m 가정이다.","",
        "| 이름 | 수 | 발자국 m | 높이 m | 삼각형 | 바이트 | 판단 |", "|---|---:|---|---:|---:|---:|---|"]
    for k,r in rows.items():
        lines.append(f'| `{k}` | {r["count"]} | {r["footprint_m"][0]}×{r["footprint_m"][1]} | {r["height_m"]} | {r["lod0_tris"]} | {r["bytes"]} | {r["judgment"]} |')
    lines += ["", "## 팔레트 (선형 RGBA)", ""]+[f"- `{k}`: {v}" for k,v in PALETTE.items()]
    lines += ["", "## SHA-256", "", "| 이름 | SHA-256 |", "|---|---|"]+[f'| `{k}` | `{r["sha256"]}` |' for k,r in rows.items()]
    lines += ["", f"지도 한 장 최대 소품 삼각형 합(원문 출현 기준 A종 추정): `{top}` {totals[top]:,}.",book["source_line_estimate"]["method"],"",
        "`salvage`, `work_site`는 spots, `car_window`, `firebox`는 lights의 종류다. 모델은 빛 없는 물건으로 만들었지만 현재 _build_props가 이 지점에 자동 배치하지 않는다.",
        "지형성 제외 7종: "+", ".join(r["kind"] for r in book["ground_like_excluded"])+".",""]
    (out/"README_a.md").write_text("\n".join(lines),encoding="utf-8")


def preview(repo, rows):
    """GLB를 다시 열어 정점색으로 두 장의 검토용 표를 캐시에 그린다."""
    cache=repo/"s2/.godot/props_a_work"; cache.mkdir(parents=True,exist_ok=True)
    for page in range(2):
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
        scene.world.color=(.13,.15,.17)
        scene.view_settings.view_transform="Standard"
        scene.render.resolution_x=1600; scene.render.resolution_y=1600; scene.render.resolution_percentage=100
        for i,(k,r) in enumerate(list(rows.items())[page*25:(page+1)*25]):
            bpy.ops.import_scene.gltf(filepath=str(repo/"s2/models/props_field"/(k+".glb")))
            obj=next(o for o in bpy.context.selected_objects if o.type=="MESH")
            scale=2.15/max(obj.dimensions)
            obj.scale=(scale,)*3
            obj.rotation_mode="XYZ"
            obj.rotation_euler=(math.radians(22),0,math.radians(-25))
            col=i%5; row=i//5
            obj.location=((col-2)*3.1,0,(2-row)*3.1-.70)
            bpy.ops.object.text_add(location=((col-2)*3.1-1.4,-.9,(2-row)*3.1-1.10),rotation=(math.pi/2,0,0))
            text_obj=bpy.context.object
            text_obj.data.body=k; text_obj.data.size=.14
        camera=bpy.data.cameras.new("PreviewCamera"); obj=bpy.data.objects.new("PreviewCamera",camera)
        scene.collection.objects.link(obj); obj.location=(0,-30,0)
        obj.rotation_euler=(math.pi/2,0,0); camera.type="ORTHO"; camera.ortho_scale=16
        scene.camera=obj; scene.render.filepath=str(cache/f"contact_{page+1}.png")
        bpy.ops.render.render(write_still=True)
        print(f"PREVIEW_READY contact_{page+1}.png",flush=True)


def main():
    parser=argparse.ArgumentParser(); parser.add_argument("--repo",required=True)
    parser.add_argument("--preview",action="store_true")
    parser.add_argument("--books-only",action="store_true")
    args=parser.parse_args(sys.argv[sys.argv.index("--")+1:])
    repo=Path(args.repo).resolve(); source=repo/"_in/kinds_a.json"
    data=json.loads(source.read_text(encoding="utf-8-sig")); kinds=data["kinds"]
    assert len(kinds)==50 and {r["kind"] for r in kinds}==set(SPECS)
    assert sum(r["count"] for r in kinds)==4378
    out=repo/"s2/models/props_field"; out.mkdir(parents=True,exist_ok=True)
    counts,rects,contexts=source_stats(repo,SPECS)
    if args.books_only:
        rows=json.loads((out/"catalog_a.json").read_text(encoding="utf-8"))["assets"]
        assert set(rows)==set(SPECS)
        for k,r in rows.items():
            size,digest,_=check_glb(out/(k+".glb"),r["lod0_tris"])
            assert (size,digest)==(r["bytes"],r["sha256"])
            r["source_rects_wh"]={f"{w}x{h}":n for (w,h),n in rects[k].items()}
        write_books(out,source,rows,counts,contexts)
        print("BOOKS_A PASS kinds=50 source_instances="+str(sum(sum(c.values()) for c in counts.values())),flush=True)
        return
    bpy.ops.wm.read_factory_settings(use_empty=True)
    rows={}
    for entry in kinds:
        k=entry["kind"]; height,judgment=SPECS[k]
        top=entry["rects_wh_top"]
        if top: footprint=top[0][0]; footprint_source="input_modal_rect"
        elif rects[k]: footprint=list(rects[k].most_common(1)[0][0]); footprint_source="map_rect2i_modal"
        else: footprint=[1,1]; footprint_source="assumed_one_cell_no_rect"
        p=Piece(k); build(p,k); p.fit(footprint,height)
        tris=len(p.faces)
        assert 0<tris<=600,(k,tris)
        assert entry["count"]<=200 or tris<=300,(k,tris)
        path=out/(k+".glb"); export(p,path)
        size,digest,bounds=check_glb(path,tris)
        rows[k]={"id":k,"status":"ready","path":"res://models/props_field/"+k+".glb",
            "count":entry["count"],"solid":entry["solid"],"footprint_m":footprint,
            "footprint_source":footprint_source,"height_m":height,"lod0_tris":tris,"triangle_limit":600,
            "bounds_m":bounds,"bytes":size,"sha256":digest,"colours":sorted(set(p.colors)),
            "judgment":judgment,"placement":"rect 가운데 바닥, 앞 +Z, 위 +Y, facing -90도씩",
            "source_rects_wh":{f"{w}x{h}":n for (w,h),n in rects[k].items()}}
        print(f"PROP_READY {k} tris={tris} bytes={size}",flush=True)
    write_books(out,source,rows,counts,contexts)
    print(f"PROPS_FIELD_A PASS kinds={len(rows)} instances={sum(r['count'] for r in rows.values())} tris={sum(r['lod0_tris'] for r in rows.values())}",flush=True)
    if args.preview: preview(repo,rows)


if __name__=="__main__": main()
