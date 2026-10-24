"""지도 소품 D: 독립적인 저다각형·정점색 생성기.

blender -b --factory-startup -P tools/blender/props_field_d.py -- --repo .
Blender X=가로, -Y=앞, Z=위; GLB X=가로, +Y=위, +Z=앞.
외부 자원·재질·그림·조명·애니메이션 없이 단일 메시/면 묶음으로 내보낸다.
"""
import sys
sys.dont_write_bytecode = True
import argparse
from collections import Counter
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
# 선형 RGBA: 앞 여섯 색은 공용 팔레트와 동일. 추가 색은 아래 여섯 색뿐이다.
PALETTE = {
    "wood": (0.24, 0.17, 0.11, 1.0),
    "worn_wood": (0.38, 0.29, 0.19, 1.0),
    "iron": (0.12, 0.15, 0.17, 1.0),
    "worn_metal": (0.28, 0.32, 0.33, 1.0),
    "cloth": (0.43, 0.41, 0.31, 1.0),
    "enamel": (0.68, 0.70, 0.66, 1.0),
    "snow": (0.82, 0.88, 0.91, 1.0),
    "bark": (0.19, 0.16, 0.13, 1.0),
    "rust": (0.31, 0.16, 0.095, 1.0),
    "glass": (0.16, 0.27, 0.31, 1.0),
    "rubber": (0.035, 0.045, 0.05, 1.0),
    "stone": (0.33, 0.35, 0.36, 1.0),
}
PLACEMENT = "rect 가운데 바닥, +Y 위·+Z 앞, facing에 따라 +Y 둘레 시계 방향 90도씩 회전. 손잡이·열린 문까지 발자국 안에 포함."
# 높이와 뜻에 대한 결정은 생성 장부/결과 글에도 그대로 기록한다.
SPECS = {
    "rubble_pile": (0.85, "광산의 각진 돌·벽돌 잔해, low 높이"),
    "service_counter": (1.05, "창구 상판·서랍·발받침, low 우세여서 none 배치도 같은 높이"),
    "skidder": (1.30, "제재소 집재차의 큰 바퀴·윈치·열린 운전석을 낮게 압축"),
    "support_frame": (2.35, "갱도 목재 지지틀 뜻을 우선해 none 높이 예외; 가운데 통과 공간"),
    "bark_heap": (0.38, "제재소 나무껍질 조각을 낮게 쌓음"),
    "cleaning_table": (0.90, "호수 손질대의 씻는 판·작은 배수 홈·받침"),
    "debarker": (1.25, "박피기의 원형 투입구·톱니 없는 롤러·받침"),
    "drying_rack": (1.25, "널빤지 건조 선반의 열린 세 단 구조"),
    "fish_hoist": (2.70, "어망 인양용 A자 틀·권양 드럼·밧줄, wall 높이"),
    "fishing_platform": (0.30, "넓고 평평한 나무 작업 발판, 난간·승선 시설 없음"),
    "flat_trailer": (0.95, "낮은 빈 평판 화물 트레일러와 바퀴·견인봉"),
    "fuel_drum_group": (1.10, "뚜껑 닫힌 무표식 연료 드럼 세 개"),
    "log_carriage": (1.15, "통나무를 싣는 레일 대차의 받침과 목재 한 개"),
    "log_cart": (1.20, "바퀴 달린 작은 원목 수레, 원목 두 개"),
    "log_conveyor": (1.05, "연속 롤러가 드러나는 낮은 원목 이송대"),
    "oil_drum": (0.90, "철제 기름통의 두 테·작은 마개, 무표식"),
    "ore_cart_tipped": (1.10, "옆으로 기운 빈 광차와 노출된 바퀴"),
    "ore_truck": (2.65, "광산 덤프트럭의 높은 적재함·유리 운전실, wall"),
    "pickup_truck": (1.30, "눈 덮인 소형 픽업의 열린 적재함, low에 맞춘 높이"),
    "planer": (1.05, "대패 기계의 투입판·보호 덮개·회전 손잡이"),
    "rubbish_pile": (0.30, "쏟아진 쓰레기는 판재·금속 조각만; 가방·신발·옷 없음"),
    "sawdust_bin": (1.10, "열린 나무 통 안에 톱밥이 담긴 설비"),
    "sawdust_pile": (0.80, "잘게 부서진 목재색 톱밥 언덕과 옅은 눈"),
    "sawhorse": (0.85, "목공용 A자 다리 두 쌍과 긴 가로보"),
    "sleeper_pile": (0.80, "철도 침목 두 층을 교차해 쌓은 낮은 더미"),
    "weigh_scale": (1.20, "광산 바닥 저울의 넓은 계량판·기계식 눈금판"),
    "arcade_column": (3.20, "회랑의 각진 석주·기단·주두, wall 높이"),
    "farm_cart": (1.10, "목재 짐수레의 열린 적재칸·두 바퀴·긴 끌채"),
    "fish_truck": (2.45, "생선 운반용 무표식 냉장 화물차, 유리창·빈 적재함"),
    "garden_rack": (1.15, "정원용 낮은 선반에 빈 화분 두 개와 막대 도구"),
    "grave_plot": (0.85, "낮은 묘역 테두리·비문 없는 둥근 묘비, 번호·대기 칸 없음"),
    "ice_saw_frame": (1.10, "얼음톱의 사각 틀·손잡이·아래쪽 짧은 톱날"),
    "ladder_rack": (1.15, "사다리를 가로로 받치는 낮은 거치대"),
    "repair_lumber": (0.55, "수리용 널빤지 묶음과 목재 받침"),
    "signal_post": (3.10, "철도 신호 기둥·무광 원판·수평 신호팔, 발광 없음"),
    "tender_wagon": (2.80, "wagon은 탄수차로 해석; 석탄 칸·물 탱크, 사람 탑승 자리 없음"),
    "anvil_block": (0.85, "나무 받침 위 모루의 뿔·허리·평평한 타격면"),
    "box_wagon": (3.10, "wagon은 빈 유개 화차; 양옆 문을 처음부터 옆으로 열어 둠"),
    "city_bus": (1.80, "시내버스·유리창·열린 출입구, 짧은 rect 깊이에 맞춰 폭도 축소"),
    "cooking_pot": (0.75, "뚜껑과 두 손잡이를 단 큰 조리솥, 불·연기 없음"),
    "dough_table": (0.85, "반죽 작업대의 두꺼운 판·밀대·평평한 반죽판"),
    "grave_slab": (0.20, "비문 없는 낮은 석재 묘판, none 높이"),
    "parish_chest": (0.80, "교구 보관용 나무 궤, low 우세; 금속 띠와 뚜껑"),
    "reed_bundle": (0.85, "갈대 줄기를 묶은 자재 다발, 소지품 없음"),
    "altar_table": (1.00, "단순한 제단 상판과 두 받침, 천 한 장·금지 표식 없음"),
    "bell_frame": (2.70, "종을 매단 목재 틀 뜻을 우선해 none 높이 예외"),
    "bell_rope": (0.18, "바닥에 둥글게 감긴 종 밧줄 한 가닥으로 none 높이 유지"),
    "cloister_post": (2.65, "회랑 목재 기둥·받침·짧은 버팀대, wall 높이"),
    "fallen_signal": (0.45, "옆으로 쓰러진 신호 기둥·원판·짧은 신호팔"),
    "high_rack": (2.20, "높은 보관 선반의 네 단·빈 공간, wall 높이"),
    "meeting_table": (0.76, "회의용 탁자 뜻을 우선해 none 높이 예외; 의자·대기열 없음"),
    "old_coach": (2.80, "낡은 객차 뜻을 우선해 none 높이 예외; 유리창·열린 문 유지"),
    "plow_blade": (1.15, "제설 삽날의 꺾인 판·보강 리브·받침"),
    "pulpit": (1.25, "교회 설교단의 앞 판·읽기용 경사진 책받침·낮은 발판"),
    "snowplow_truck": (2.50, "앞쪽 제설 삽날을 붙인 화물차, wall 높이"),
    "wire_coil": (0.28, "바닥에 감긴 매끈한 전선; 가시·철조망 없음"),
    "blanket_screen": (1.25, "담요 한 장을 낮은 목재 틀에 펼친 가림막, low 높이·소지품 더미 없음"),
    "boulder": (1.20, "눈이 조금 얹힌 각진 바위, low 높이"),
    "butcher_block": (0.90, "두꺼운 정육 작업판·튼튼한 다리, low 우세"),
    "courtyard_planter": (1.20, "중정 화분의 석재 통·눈·마른 가지"),
}


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
            normal += a.cross(b)
        if normal.length < 1e-9:
            raise ValueError("넓이 없는 면: " + self.pid)
        if normal.dot(Vector(outward)) < 0:
            pts.reverse()
        face = self.bm.faces.new([self.bm.verts.new(p) for p in pts])
        for loop in face.loops:
            loop[self.col] = PALETTE[colour]
        self.colours.add(colour)

    def box(self, x, y, z, c):
        x0, x1 = x; y0, y1 = y; z0, z1 = z
        if min(x1-x0, y1-y0, z1-z0) <= 0:
            raise ValueError("빈 상자: " + self.pid)
        for a, sign in ((x0, -1), (x1, 1)):
            self.face([(a,y0,z0),(a,y1,z0),(a,y1,z1),(a,y0,z1)], c, (sign,0,0))
        for a, sign in ((y0, -1), (y1, 1)):
            self.face([(x0,a,z0),(x1,a,z0),(x1,a,z1),(x0,a,z1)], c, (0,sign,0))
        for a, sign in ((z0, -1), (z1, 1)):
            self.face([(x0,y0,a),(x1,y0,a),(x1,y1,a),(x0,y1,a)], c, (0,0,sign))

    def beam(self, a, b, radius, c, sides=6, tip=None):
        a, b = Vector(a), Vector(b)
        axis = (b-a).normalized()
        guide = Vector((1,0,0)) if abs(axis.z) > .9 else Vector((0,0,1))
        u = axis.cross(guide).normalized(); v = axis.cross(u).normalized()
        radial = [u*math.cos(i*math.tau/sides)+v*math.sin(i*math.tau/sides) for i in range(sides)]
        lower = [a+d*radius for d in radial]
        upper = [b+d*(radius if tip is None else tip) for d in radial]
        self.face(lower,c,-axis); self.face(upper,c,axis)
        for i in range(sides):
            j=(i+1)%sides
            self.face([lower[i],lower[j],upper[j],upper[i]],c,radial[i]+radial[j])

    def lathe(self, centre, profile, c, sides=8, alternate=None):
        cx,cy=centre
        rings=[[(cx+rx*math.cos(i*math.tau/sides),cy+ry*math.sin(i*math.tau/sides),z)
                for i in range(sides)] for z,rx,ry in profile]
        self.face(rings[0],c,(0,0,-1)); self.face(rings[-1],c,(0,0,1))
        for lo,hi in zip(rings,rings[1:]):
            for i in range(sides):
                j=(i+1)%sides; angle=(i+.5)*math.tau/sides
                self.face([lo[i],lo[j],hi[j],hi[i]],alternate if alternate and i%3==0 else c,
                          (math.cos(angle),math.sin(angle),0))

    def ring(self, x, y, z, radius, tube, c, segments=12, sides=4):
        # 매끈한 고리: 가시나 장벽 장식을 추가하지 않는다.
        rings=[]
        for i in range(segments):
            angle=i*math.tau/segments
            rings.append([(x+(radius+tube*math.cos(j*math.tau/sides))*math.cos(angle),
                           y+(radius+tube*math.cos(j*math.tau/sides))*math.sin(angle),
                           z+tube*math.sin(j*math.tau/sides)) for j in range(sides)])
        for i in range(segments):
            for j in range(sides):
                ni=(i+1)%segments; nj=(j+1)%sides
                a=(i+.5)*math.tau/segments; b=(j+.5)*math.tau/sides
                self.face([rings[i][j],rings[ni][j],rings[ni][nj],rings[i][nj]],c,
                          (math.cos(a)*math.cos(b),math.sin(a)*math.cos(b),math.sin(b)))

    def fit(self, footprint, height):
        lo=[min(v.co[i] for v in self.bm.verts) for i in range(3)]
        hi=[max(v.co[i] for v in self.bm.verts) for i in range(3)]
        width=footprint[0]*.96
        if self.pid in ("skidder","ore_truck","pickup_truck","fish_truck","snowplow_truck",
                        "tender_wagon","box_wagon","city_bus","old_coach"):
            # 앞 방향을 유지하면서 짧은 rect에 차량을 가로로 늘리지 않는다.
            ratio=.52 if self.pid in ("city_bus","old_coach","box_wagon","tender_wagon") else .68
            width=min(width,footprint[1]*.96*ratio)
        target=(width,footprint[1]*.96,height)
        for v in self.bm.verts:
            for i in range(3):
                v.co[i]=((v.co[i]-lo[i])/(hi[i]-lo[i])-(.5 if i<2 else 0))*target[i]
        bmesh.ops.triangulate(self.bm,faces=list(self.bm.faces))
        self.bm.normal_update()
        if any(f.calc_area()<1e-10 for f in self.bm.faces):
            raise ValueError("퇴화 삼각형")

    def bounds(self):
        pts=[(v.co.x,v.co.z,-v.co.y) for v in self.bm.verts]
        return [[round(fn(p[i] for p in pts),6) for i in range(3)] for fn in (min,max)]


def legs(p, top=.82, c="wood", xs=(-.42,.42), ys=(-.36,.36)):
    for x in xs:
        for y in ys:
            p.box((x-.035,x+.035),(y-.035,y+.035),(0,top),c)


def table(p, thick=.10, c="worn_wood"):
    legs(p,1-thick)
    p.box((-.5,.5),(-.5,.5),(1-thick,1),c)
    p.box((-.44,.44),(-.38,-.34),(.15,.22),"wood")


def rack(p, levels=3):
    legs(p,1)
    for i in range(levels):
        z=.08+i*.86/max(1,levels-1)
        p.box((-.5,.5),(-.45,.45),(z,z+.055),"worn_wood")
    p.beam((-.42,.36,.12),(.42,.36,.94),.025,"iron",4)


def tub(p,z0=.25,z1=.85,c="worn_metal",x=(-.44,.44),y=(-.36,.42)):
    a,b=x; d,e=y; t=.045
    p.box(x,y,(z0,z0+t),c)
    p.box((a,a+t),y,(z0,z1),c); p.box((b-t,b),y,(z0,z1),c)
    p.box((a+t,b-t),(d,d+t),(z0,z1),c); p.box((a+t,b-t),(e-t,e),(z0,z1),c)


def drum(p,x=0,y=0,r=.36,h=.90):
    p.lathe((x,y),[(0,r*.90,r*.90),(h*.08,r,r),(h*.91,r,r),(h,r*.92,r*.92)],"worn_metal",10,"rust")
    for z in (h*.22,h*.72):
        p.lathe((x,y),[(z,r*1.04,r*1.04),(z+h*.045,r*1.04,r*1.04)],"iron",10)
    p.beam((x+r*.35,y,h),(x+r*.35,y,h+.035),r*.14,"iron",8)
    p.box((x-r*.65,x+r*.3),(y-r*.6,y+r*.45),(h,h+.022),"snow")


def rocks(p,count=7,c="stone"):
    for i in range(count):
        a=i*2.39996; radius=.32 if i else 0
        x=math.cos(a)*radius; y=math.sin(a)*radius
        size=.19+.035*(i%3); base=.08 if i>4 else 0
        p.lathe((x,y),[(base,size*.7,size*.72),(base+.19,size,size*.86),
                      (base+.35+.10*(i%2),size*.38,size*.40)],c,5,"worn_metal" if c=="stone" else "worn_wood")


def snow_patch(p,x=(-.32,.25),y=(-.3,.22),z=1):
    p.box(x,y,(z,z+.025),"snow")


def cart_wheels(p, ys=(-.26,.30), rail=False):
    for y in ys:
        p.beam((-.53,y,.18),(.53,y,.18),.035,"iron",6)
        for sign in (-1,1):
            p.beam((sign*.43,y,.18),(sign*.53,y,.18),.18,"iron" if rail else "rubber",8)
            p.beam((sign*.53,y,.18),(sign*.55,y,.18),.07,"worn_metal",4)


def vehicle(p, kind):
    # 운전석/앞 유리는 -Y 쪽. 발자국에 맞춘 축별 스타일화이며 +Z 전면을 유지한다.
    passenger=kind in ("city_bus","old_coach")
    rail=kind in ("old_coach","box_wagon","tender_wagon")
    cart_wheels(p,(-.33,.32),rail)
    p.box((-.43,.43),(-.49,.49),(.22,.34),"iron")
    if kind=="box_wagon":
        p.box((-.43,.43),(-.46,.46),(.34,.39),"worn_wood")
        for x in (-.44,.40):
            for y0,y1 in ((-.46,-.13),(.15,.46)):
                p.box((x,x+.04),(y0,y1),(.39,.94),"wood")
            # 양쪽 문을 뒤쪽 벽을 따라 미끄러뜨려 개방한다.
            p.box((x-.025,x+.045),(.15,.43),(.40,.92),"worn_wood")
            for z in (.46,.86):
                p.box((x-.03,x+.05),(.15,.43),(z,z+.025),"iron")
        for y in (-.48,.45):
            p.box((-.44,.44),(y,y+.03),(.39,.94),"wood")
        p.box((-.46,.46),(-.49,.49),(.94,1),"worn_metal")
        snow_patch(p,z=1)
        return
    if kind=="tender_wagon":
        tub(p,.34,.82,"iron",(-.42,.42),(-.46,.03))
        for x in (-.25,0,.24):
            p.lathe((x,-.22),[(.39,.16,.14),(.68,.17,.17),(.78,.07,.09)],"rubber",5)
        p.box((-.42,.42),(.04,.46),(.34,.87),"worn_metal")
        p.beam((0,.25,.87),(0,.25,.92),.13,"iron",8)
        snow_patch(p,(-.35,.32),(.06,.18),.87)
        return
    if passenger:
        for x in (-.43,.40):
            for y0,y1 in ((-.47,-.29),(-.15,.47)):
                p.box((x,x+.03),(y0,y1),(.34,.55),"enamel" if kind=="city_bus" else "wood")
        p.box((-.44,.44),(-.48,.48),(.94,1),"worn_metal")
        for x in (-.43,.40):
            for i in range(6):
                y=-.43+i*.145
                # 앞쪽 하나는 출입구로 비워 두고 옆으로 열린 문을 덧댄다.
                if i==1:
                    continue
                p.box((x,x+.03),(y,y+.11),(.57,.91),"glass")
            for y in (-.47,-.29,-.12,.18,.45):
                p.box((x-.01,x+.04),(y,y+.025),(.55,.95),"enamel")
            p.box((x-.018,x+.045),(-.12,.01),(.35,.91),"glass")
        p.box((-.39,.39),(-.481,-.465),(.58,.92),"glass")
        p.box((-.40,.40),(.465,.48),(.55,.94),"worn_metal")
        snow_patch(p,z=1)
        return
    # 트럭/집재차: 짧은 보닛, 경사진 앞 유리, 타이어 네 개, 뒤쪽 화물 설비.
    p.box((-.39,.39),(-.49,-.31),(.34,.52),"enamel")
    p.box((-.40,.40),(-.31,-.02),(.34,.57),"worn_metal")
    p.box((-.40,.40),(-.29,-.025),(.57,.92),"glass")
    for x in (-.40,.36):
        p.box((x,x+.04),(-.30,-.025),(.55,.93),"iron")
    p.box((-.42,.42),(-.32,-.005),(.92,.97),"enamel")
    p.box((-.31,.31),(-.51,-.49),(.36,.43),"iron")
    for x in (-.31,.24):
        p.box((x,x+.07),(-.515,-.50),(.46,.50),"enamel")
    if kind=="fish_truck":
        p.box((-.43,.43),(.02,.48),(.34,1),"enamel")
        for z in (.44,.65,.86):
            p.box((-.44,-.431),(.05,.44),(z,z+.018),"worn_metal")
        snow_patch(p,(-.38,.28),(.05,.42),1)
    elif kind=="skidder":
        p.beam((-.3,.22,.52),(.3,.22,.52),.19,"iron",8)
        p.beam((-.31,.28,.45),(-.31,.48,.83),.04,"worn_metal",4)
        p.beam((.31,.28,.45),(.31,.48,.83),.04,"worn_metal",4)
        p.beam((-.31,.48,.83),(.31,.48,.83),.045,"worn_metal",4)
    else:
        tub(p,.34,.88 if kind=="ore_truck" else .63,"rust" if kind=="ore_truck" else "worn_metal",y=(.03,.48))
        if kind=="snowplow_truck":
            p.box((-.57,.57),(-.67,-.61),(.05,.48),"worn_metal")
            p.box((-.57,.57),(-.69,-.66),(.05,.10),"iron")
    snow_patch(p,(-.36,.28),(-.28,-.03),.97)


def build(p):
    k=p.pid
    if k in ("skidder","ore_truck","pickup_truck","fish_truck","snowplow_truck",
             "tender_wagon","box_wagon","city_bus","old_coach"):
        vehicle(p,k)
    elif k in ("rubble_pile","boulder","sawdust_pile"):
        if k=="boulder":
            p.lathe((0,0),[(0,.35,.33),(.35,.5,.44),(.78,.38,.42),(1,.17,.22)],"stone",7,"worn_metal")
            snow_patch(p,(-.13,.14),(-.14,.13),1)
        elif k=="sawdust_pile":
            p.lathe((0,0),[(0,.5,.46),(.30,.43,.38),(.70,.24,.22),(.88,.06,.05)],"worn_wood",9,"wood")
            p.lathe((-.12,.03),[(.50,.20,.19),(.79,.09,.08)],"snow",5)
        else:
            rocks(p)
    elif k in ("cleaning_table","dough_table","altar_table","meeting_table","butcher_block"):
        table(p,.22 if k=="butcher_block" else .09,"enamel" if k=="cleaning_table" else "worn_wood")
        if k=="cleaning_table":
            for y in (-.25,-.15,-.05):
                p.box((.15,.43),(y,y+.025),(1,1.008),"worn_metal")
            p.box((-.49,-.40),(-.4,.4),(1,1.07),"worn_metal")
        if k=="dough_table":
            p.box((-.35,.12),(-.35,.28),(1,1.025),"cloth")
            p.beam((.24,-.29,1.05),(.24,.29,1.05),.045,"wood",8)
        if k=="altar_table":
            p.box((-.22,.22),(-.51,.4),(1,1.02),"cloth")
            p.box((-.22,.22),(-.515,-.50),(.70,1.02),"cloth")
    elif k=="service_counter":
        p.box((-.48,.48),(-.41,.40),(.05,.89),"wood")
        p.box((-.5,.5),(-.5,.5),(.89,1),"worn_wood")
        for x in (-.32,0,.32):
            p.box((x-.13,x+.13),(-.43,-.41),(.55,.81),"worn_wood")
            p.box((x-.045,x+.045),(-.46,-.43),(.66,.69),"iron")
        p.beam((-.43,-.47,.18),(.43,-.47,.18),.025,"iron",6)
    elif k in ("support_frame","fish_hoist","bell_frame"):
        for x in (-.40,.40):
            p.beam((x,-.4,0),(x,0,.91),.055,"wood",4)
            p.beam((x,.4,0),(x,0,.91),.055,"wood",4)
        p.box((-.50,.50),(-.07,.07),(.88,1),"worn_wood")
        if k=="fish_hoist":
            p.beam((-.22,0,.55),(.22,0,.55),.17,"iron",8)
            p.beam((0,-.06,.92),(0,-.06,.25),.018,"cloth",6)
            p.beam((.24,0,.55),(.32,0,.55),.03,"iron",6)
            p.beam((.32,0,.55),(.32,0,.70),.025,"iron",4)
        if k=="bell_frame":
            p.beam((0,0,.94),(0,0,.82),.025,"iron",6)
            p.lathe((0,0),[(.35,.27,.27),(.41,.22,.22),(.72,.12,.12),(.80,.07,.07)],"rust",10,"worn_metal")
            p.beam((0,0,.52),(0,0,.31),.04,"iron",6)
    elif k in ("bark_heap","rubbish_pile","sleeper_pile","repair_lumber"):
        n=9 if k=="bark_heap" else 8
        for i in range(n):
            layer=i//4; y=(i%4-.5*3)*.22
            z=layer*.16
            c="bark" if k=="bark_heap" else ("worn_metal" if k=="rubbish_pile" and i%3==0 else "worn_wood")
            before=set(p.bm.verts)
            p.box((-.48+(i%3)*.035,.43-(i%2)*.08),(y-.07,y+.07),(z,z+.11),c)
            if k in ("bark_heap","rubbish_pile"):
                angle=(i%5-2)*.17
                for v in set(p.bm.verts)-before:
                    vx,vy=v.co.x,v.co.y
                    v.co.x=vx*math.cos(angle)-vy*math.sin(angle)
                    v.co.y=vx*math.sin(angle)+vy*math.cos(angle)
                    if k=="bark_heap":
                        v.co.z+=.05*abs(vx)+.025*(i%3)
        if k=="sleeper_pile":
            for x in (-.28,.28):
                p.box((x-.045,x+.045),(-.45,.45),(.26,.36),"wood")
        if k!="rubbish_pile":
            snow_patch(p,(-.24,.31),(-.17,-.08),.27)
    elif k in ("drying_rack","garden_rack","high_rack"):
        rack(p,4 if k=="high_rack" else 3)
        if k=="garden_rack":
            for x in (-.22,.22):
                p.lathe((x,0),[(.14,.10,.13),(.38,.14,.16)],"rust",6)
                p.lathe((x,0),[(.38,.12,.14),(.386,.12,.14)],"bark",6)
        if k=="drying_rack":
            for z in (.17,.60):
                for y in (-.23,.08):
                    p.box((-.45,.45),(y,y+.12),(z,z+.04),"wood")
    elif k=="fishing_platform":
        for x in (-.40,0,.40):
            p.box((x-.035,x+.035),(-.5,.5),(0,.35),"wood")
        for i in range(12):
            x=-.5+i/12
            p.box((x,x+.077),(-.5,.5),(.35,.68),"wood" if i%4==0 else "worn_wood")
        snow_patch(p,(-.44,-.28),(-.42,.30),.68)
        snow_patch(p,(.21,.42),(.22,.43),.68)
    elif k in ("flat_trailer","log_carriage","log_cart","farm_cart","ore_cart_tipped"):
        cart_wheels(p,(-.25,.28),k in ("log_carriage","ore_cart_tipped"))
        p.box((-.44,.44),(-.45,.45),(.25,.35),"wood")
        if k=="flat_trailer":
            for x in (-.32,.32):
                p.beam((x,-.43,.30),(0,-.70,.28),.035,"iron",4)
            snow_patch(p,z=.35)
        elif k in ("log_carriage","log_cart"):
            for x in (-.37,.37):
                for y in (-.30,.30):
                    p.beam((x,y,.35),(x,y,.78),.035,"iron",4)
            for x in ((0,) if k=="log_carriage" else (-.17,.17)):
                p.beam((x,-.46,.55),(x,.46,.55),.18,"bark",8)
                p.beam((x,-.467,.55),(x,-.46,.55),.15,"worn_wood",8)
        else:
            before=set(p.bm.verts)
            tub(p,.35,.84,"rust" if k=="ore_cart_tipped" else "worn_wood")
            if k=="ore_cart_tipped":
                for v in set(p.bm.verts)-before:
                    x,z=v.co.x,v.co.z-.35
                    v.co.x=x*.82+z*.57
                    v.co.z=.35-x*.57+z*.82
            else:
                for x in (-.28,.28):
                    p.beam((x,-.3,.30),(x,-.82,.26),.025,"wood",4)
    elif k in ("fuel_drum_group","oil_drum"):
        if k=="oil_drum":
            drum(p)
        else:
            for x,y in ((-.26,-.22),(.27,-.17),(0,.30)):
                drum(p,x,y,.23,.75)
    elif k in ("debarker","log_conveyor","planer"):
        legs(p,.65,"iron")
        for x in (-.42,.42):
            p.box((x-.035,x+.035),(-.5,.5),(.55,.70),"worn_metal")
        n=8 if k=="log_conveyor" else 4
        for i in range(n):
            y=-.43+i*.86/max(1,n-1)
            p.beam((-.39,y,.70),(.39,y,.70),.055,"iron",8)
        if k=="debarker":
            # 투입구는 실제 빈 구멍이 있는 8각 고리.
            before=set(p.bm.verts)
            p.ring(0,0,0,.25,.07,"worn_metal",10,4)
            for v in set(p.bm.verts)-before:
                x,y,z=v.co
                v.co=(x*.30,z,y+.92)
            p.box((-.43,-.31),(-.18,.17),(.70,1),"rust")
        elif k=="planer":
            p.box((-.38,.38),(-.18,.18),(.72,.98),"enamel")
            p.beam((.40,0,.81),(.47,0,.81),.12,"iron",8)
            p.box((-.38,.38),(-.47,-.18),(.70,.73),"worn_metal")
    elif k=="sawdust_bin":
        tub(p,0,.85,"wood")
        p.lathe((0,0),[(.20,.35,.28),(.68,.38,.30),(.91,.12,.12)],"worn_wood",7)
    elif k in ("sawhorse","ladder_rack"):
        for x in (-.35,.35):
            p.beam((x,-.42,0),(x,0,.90),.045,"wood",4)
            p.beam((x,.42,0),(x,0,.90),.045,"wood",4)
        p.box((-.5,.5),(-.07,.07),(.85,.96),"worn_wood")
        if k=="ladder_rack":
            for y in (-.25,.25):
                p.box((-.5,.5),(y-.025,y+.025),(.97,1.02),"wood")
            for i in range(7):
                x=-.44+i*.145
                p.box((x,x+.025),(-.25,.25),(.98,1.01),"worn_wood")
    elif k=="weigh_scale":
        p.box((-.5,.5),(-.5,.5),(0,.16),"iron")
        p.box((-.45,.45),(-.45,.40),(.16,.20),"worn_metal")
        p.beam((0,.37,.15),(0,.37,.85),.035,"iron",6)
        p.box((-.18,.18),(.28,.40),(.72,1),"enamel")
        p.box((-.13,.13),(.265,.28),(.78,.94),"glass")
        p.beam((0,.25,.80),(.07,.25,.90),.009,"iron",4)
    elif k in ("arcade_column","cloister_post"):
        c="stone" if k=="arcade_column" else "wood"
        p.box((-.5,.5),(-.5,.5),(0,.10),"stone")
        p.box((-.33,.33),(-.33,.33),(.1,.89),c)
        p.box((-.46,.46),(-.46,.46),(.89,1),"worn_metal" if k=="arcade_column" else "worn_wood")
        if k=="cloister_post":
            p.beam((0,0,.63),(.46,0,.92),.07,"worn_wood",4)
            p.beam((0,0,.63),(-.46,0,.92),.07,"worn_wood",4)
        snow_patch(p,z=1)
    elif k in ("grave_plot","grave_slab"):
        if k=="grave_slab":
            p.box((-.5,.5),(-.5,.5),(0,.30),"stone")
            p.box((-.43,.43),(-.43,.43),(.30,.38),"worn_metal")
            snow_patch(p,z=.38)
        else:
            for x in (-.46,.40):
                p.box((x,x+.06),(-.47,.47),(0,.12),"stone")
            for y in (-.47,.41):
                p.box((-.40,.40),(y,y+.06),(0,.12),"stone")
            p.box((-.39,.39),(-.39,.39),(0,.07),"snow")
            p.box((-.22,.22),(.26,.38),(.07,.68),"stone")
            p.lathe((0,.32),[(.68,.22,.06),(.86,.10,.045)],"stone",6)
    elif k=="ice_saw_frame":
        for x in (-.44,.44):
            p.box((x-.04,x+.04),(-.10,.10),(0,1),"wood")
        for z in (.10,.87):
            p.box((-.44,.44),(-.05,.05),(z,z+.07),"worn_wood")
        p.box((-.40,.40),(-.018,.018),(.20,.31),"worn_metal")
        for i in range(9):
            x=-.4+i*.085
            p.face([(x,-.018,.20),(x+.07,-.018,.20),(x+.035,-.018,.12)],"iron",(0,-1,0))
            p.face([(x,.018,.20),(x+.035,.018,.12),(x+.07,.018,.20)],"iron",(0,1,0))
        for x in (-.44,.44):
            p.beam((x,-.20,.73),(x,.20,.73),.05,"worn_wood",6)
    elif k in ("signal_post","fallen_signal"):
        p.box((-.22,.22),(-.22,.22),(0,.12),"stone")
        p.beam((0,0,.12),(0,0,.91),.045,"iron",6)
        p.beam((0,-.06,.76),(0,-.11,.76),.15,"rubber",10)
        p.beam((0,-.115,.76),(0,-.12,.76),.08,"glass",8)
        p.box((-.04,.44),(-.035,.035),(.91,.97),"enamel")
        p.box((.29,.40),(-.04,-.036),(.91,.97),"rust")
        if k=="fallen_signal":
            for v in p.bm.verts:
                x,y,z=v.co
                v.co=(z,y,x)
    elif k=="anvil_block":
        p.lathe((0,0),[(0,.39,.37),(.45,.34,.33)],"bark",8)
        p.box((-.35,.35),(-.28,.28),(.45,.55),"iron")
        p.box((-.18,.18),(-.18,.18),(.55,.81),"iron")
        p.box((-.30,.35),(-.24,.24),(.81,.94),"worn_metal")
        p.beam((-.30,0,.86),(-.58,0,.88),.13,"iron",6,.015)
    elif k=="cooking_pot":
        p.lathe((0,0),[(0,.28,.28),(.16,.42,.42),(.70,.42,.42),(.77,.35,.35)],"iron",10)
        p.lathe((0,0),[(.77,.42,.42),(.82,.33,.33),(.88,.12,.12)],"worn_metal",10)
        p.beam((0,0,.88),(0,0,.97),.07,"bark",8)
        for x in (-.49,.49):
            p.box((x-.08,x+.08),(-.06,.06),(.59,.66),"iron")
    elif k=="parish_chest":
        p.box((-.48,.48),(-.45,.45),(.06,.82),"wood")
        p.box((-.5,.5),(-.48,.48),(.82,.96),"worn_wood")
        for x in (-.32,.32):
            p.box((x-.035,x+.035),(-.49,.49),(.96,.98),"iron")
            p.box((x-.035,x+.035),(-.47,-.45),(.08,.82),"iron")
        p.box((-.10,.10),(-.49,-.47),(.52,.57),"worn_metal")
    elif k=="reed_bundle":
        for i in range(16):
            a=i*2.39996; r=.06+.011*i if i else 0
            x,y=math.cos(a)*r,math.sin(a)*r
            p.beam((x,y,0),(x*1.25,y*1.25,.86+.035*(i%4)),.035,"cloth" if i%3 else "worn_wood",5)
        p.ring(0,0,.32,.25,.025,"wood",12,4)
    elif k in ("bell_rope","wire_coil"):
        c="cloth" if k=="bell_rope" else "rubber"
        for r,z in ((.18,.045),(.30,.045),(.41,.045)):
            p.ring(0,0,z,r,.025,c,12,4)
        p.beam((.41,0,.045),(.48,-.24,.045),.025,c,6)
    elif k=="plow_blade":
        p.box((-.5,.5),(-.11,.02),(.10,.73),"worn_metal")
        p.box((-.5,.5),(-.26,-.11),(.03,.18),"iron")
        for x in (-.37,0,.37):
            p.beam((x,.31,.12),(x,0,.62),.035,"rust",4)
        snow_patch(p,(-.42,.34),(-.10,.01),.73)
    elif k=="pulpit":
        p.box((-.5,.5),(-.45,.45),(0,.12),"wood")
        p.box((-.40,.40),(-.35,-.27),(.12,.86),"worn_wood")
        for x in (-.4,.34):
            p.box((x,x+.06),(-.27,.25),(.12,.75),"wood")
        before=set(p.bm.verts)
        p.box((-.46,.46),(-.38,.28),(.83,.91),"worn_wood")
        for v in set(p.bm.verts)-before:
            v.co.z+=v.co.y*.20
    elif k=="blanket_screen":
        for x in (-.45,.45):
            p.box((x-.025,x+.025),(-.025,.025),(0,1),"wood")
            p.box((x-.05,x+.05),(-.36,.36),(0,.05),"wood")
        p.box((-.47,.47),(-.035,.035),(.94,1),"worn_wood")
        # 펼친 천 하나의 완만한 세로 접힘. 옷·신발·가방은 없다.
        for i in range(8):
            x=-.42+i*.105; y=.035 if i%2 else -.035; ny=-y
            p.face([(x,y,.16),(x+.105,ny,.16),(x+.105,ny,.94),(x,y,.94)],"cloth",(0,-1,0))
            p.face([(x,y+.004,.16),(x+.105,ny+.004,.16),(x+.105,ny+.004,.94),(x,y+.004,.94)],"cloth",(0,1,0))
    elif k=="courtyard_planter":
        tub(p,0,.48,"stone")
        p.box((-.38,.38),(-.30,.36),(.38,.41),"snow")
        for x in (-.22,.15):
            p.beam((x,0,.40),(x+.03,0,.91),.025,"bark",5,.012)
            p.beam((x,0,.68),(x-.12,-.11,.96),.016,"bark",5,.007)
            p.beam((x+.02,0,.78),(x+.15,.10,1),.014,"bark",5,.006)
    else:
        raise ValueError("조형 함수가 없는 종류: "+k)


def export(p,path):
    mesh=bpy.data.meshes.new(p.pid)
    p.bm.to_mesh(mesh)
    mesh.color_attributes.active_color=mesh.color_attributes["Col"]
    mesh.color_attributes.render_color_index=0
    obj=bpy.data.objects.new(p.pid,mesh)
    bpy.context.scene.collection.objects.link(obj)
    for other in bpy.context.scene.objects:
        other.select_set(other==obj)
    bpy.context.view_layer.objects.active=obj
    try:
        bpy.ops.export_scene.gltf(filepath=str(path),export_format="GLB",use_selection=True,
            export_yup=True,export_materials="NONE",export_texcoords=False,export_normals=True,
            export_tangents=False,export_vertex_color="ACTIVE",export_extras=False,
            export_animations=False,export_cameras=False,export_lights=False)
    finally:
        bpy.data.objects.remove(obj,do_unlink=True)
        bpy.data.meshes.remove(mesh)


def check_glb(path,expected):
    data=path.read_bytes()
    magic,version,length=struct.unpack_from("<4sII",data)
    n,t=struct.unpack_from("<II",data,12)
    if (magic,version,length,t)!=(b"glTF",2,len(data),0x4e4f534a):
        raise ValueError("GLB 머리 오류")
    doc=json.loads(data[20:20+n])
    assert len(doc["meshes"])==1 and sum("mesh" in v for v in doc["nodes"])==1
    prims=doc["meshes"][0]["primitives"]
    assert len(prims)==1
    p=prims[0]
    assert p.get("mode",4)==4 and "COLOR_0" in p["attributes"]
    assert doc["accessors"][p["indices"]]["count"]==expected*3
    assert not any(doc.get(k) for k in ("materials","images","textures","animations","skins","cameras"))
    assert not any("uri" in b for b in doc["buffers"])
    assert not doc.get("extensions",{}).get("KHR_lights_punctual")
    assert 0<expected<=TRIANGLE_LIMIT
    return len(data),hashlib.sha256(data).hexdigest()


def census(repo):
    maps={}; rects={k:Counter() for k in SPECS}
    for path in sorted((repo/"s2/game/world/maps").glob("*.gd")):
        counts=Counter()
        for m in re.finditer(r'\{[^{}]*"kind"\s*:\s*"([^"\n]+)"[^{}]*\}',path.read_text(encoding="utf-8-sig")):
            k=m[1]
            if k not in SPECS:
                continue
            counts[k]+=1
            r=re.search(r'"rect"\s*:\s*(?:\[|Rect2i\()\s*-?\d+\s*,\s*-?\d+\s*,\s*(\d+)\s*,\s*(\d+)',m[0])
            if r:
                rects[k][(int(r[1]),int(r[2]))]+=1
        maps[path.name]=dict(counts)
    return maps,rects


def write_books(out,rows,source,maps,failures):
    tris={r["id"]:r["lod0_tris"] for r in rows}
    totals={m:sum(n*tris.get(k,0) for k,n in counts.items()) for m,counts in maps.items()}
    largest=max(totals,key=totals.get)
    book={"version":1,"generator":"tools/blender/props_field_d.py","blender":bpy.app.version_string,
          "axis":"X right, +Y up, +Z front","origin":"footprint_center_floor","placement":PLACEMENT,
          "palette":PALETTE,"colour_encoding":"linear RGBA vertex Col, alpha 1",
          "triangle_limit":600,"expected_kinds":list(SPECS),
          "input_sha256":hashlib.sha256(source).hexdigest(),
          "assets":{r["id"]:{k:v for k,v in r.items() if k!="id"} for r in rows},
          "skipped":{r["kind"]:"지형성 제외 목록; 이번 60종 밖" for r in json.loads(source)["skip_ground_like"]},
          "failures":failures,"census":{"source":"s2/game/world/maps/*.gd","map_files":len(maps),
          "method":"literal prop dictionaries, array rect and Rect2i; no runtime spawning",
          "map_counts":maps,"map_triangles_d":totals,"max_map":largest,"max_map_triangles_d":totals[largest],
          "placed_triangles_d":sum(totals.values()),"source_instances_d":sum(sum(c.values()) for c in maps.values())}}
    (out/"catalog_d.json").write_text(json.dumps(book,ensure_ascii=False,indent=2)+"\n",encoding="utf-8")
    lines=["# 지도 소품 D", "", "`tools/blender/props_field_d.py`가 자동 생성한다. 단일 메시·면 묶음, 정점색 Col, 종류당 600삼각형 이하.",
           "재질·그림·조명·파티클·외부 참조·LOD 없음. 겨울색과 일부 눈 덮개는 실제 면 색이다.","",PLACEMENT,"",
           "최빈 rect의 96% 이내로 맞춘다. 차량은 +Z 전면과 비율을 지키도록 폭을 더 줄인다. 지도 쪽 회전/다른 rect 크기의 적합성은 별도다.","",
           "| 이름 | 수 | 발자국 m | 높이 m | solid | 삼각형 | 바이트 | 판단 |","|---|---:|---|---:|---|---:|---:|---|"]
    for r in rows:
        lines.append(f'| `{r["id"]}` | {r["count"]} | {r["footprint_m"][0]}×{r["footprint_m"][1]} | {r["height_m"]:g} | '+
                     ", ".join(f"{k}:{v}" for k,v in r["solid"].items())+f' | {r["lod0_tris"]} | {r["bytes"]} | {r["judgment"]} |')
    lines += ["",f'종류 {len(rows)}, 배치 {sum(r["count"] for r in rows)}, 고유 메시 삼각형 {sum(tris.values())}, 바이트 {sum(r["bytes"] for r in rows)}.',
              f'지도 한 장 최대 D 소품 삼각형 합: `{largest}`의 {totals[largest]:,}. 이 몫 외 소품·컬링·인스턴싱 비용은 제외.',"",
              "## 팔레트 (선형 RGBA)","", "| 색 | 값 |","|---|---|"]
    lines += [f"| {k} | {v} |" for k,v in PALETTE.items()]
    lines += ["","## SHA-256","","| 종류 | sha256 |","|---|---|"]
    lines += [f'| `{r["id"]}` | `{r["sha256"]}` |' for r in rows]
    lines += ["","## 입력 보완","","빈 rect 표는 지도 원문 Rect2i의 최빈 크기로 보완했다. 동률이면 원문 파일 정렬에서 먼저 등장한 크기를 쓴다."]
    lines += [f'- `{r["id"]}`: {r["footprint_m"]}, 최빈 {r["modal_rect_count"]}개, 근거 `{r["footprint_source"]}`.' for r in rows if r["footprint_source"]!="_in/kinds_d.json"]
    lines += ["","## 제외",""]+[f"- `{k}`: {v}." for k,v in book["skipped"].items()]
    lines += ["","## 생성 실패","",json.dumps(failures,ensure_ascii=False)]
    (out/"README_d.md").write_text("\n".join(lines)+"\n",encoding="utf-8")
    return book


def preview(repo,book):
    """내보낸 GLB를 다시 열어 작업용 접촉시트 세 장. 출력은 캐시만 사용."""
    scene=bpy.context.scene
    scene.render.engine="BLENDER_WORKBENCH"
    scene.display.shading.light="STUDIO"
    scene.display.shading.color_type="VERTEX"
    scene.display.shading.show_shadows=True
    scene.display.shading.show_cavity=True
    scene.display.shading.cavity_type="BOTH"
    scene.display.shading.background_type="WORLD"
    if scene.world is None:
        scene.world=bpy.data.worlds.new("PreviewWorld")
    scene.world.color=(.075,.085,.10)
    scene.render.resolution_x=1600; scene.render.resolution_y=1280
    scene.render.resolution_percentage=100
    direction=Vector((7,-10,8)).normalized()
    right=Vector((1,0,0)); right=direction.cross(Vector((0,0,1))).normalized()*-1
    up=direction.cross(right).normalized()
    for page in range(3):
        bpy.ops.object.select_all(action="SELECT"); bpy.ops.object.delete(use_global=False)
        camera=bpy.data.cameras.new("PreviewCamera")
        cam=bpy.data.objects.new("PreviewCamera",camera); scene.collection.objects.link(cam)
        cam.location=direction*30; cam.rotation_euler=(-direction).to_track_quat("-Z","Y").to_euler()
        camera.type="ORTHO"; camera.ortho_scale=17; scene.camera=cam
        for i,(pid,row) in enumerate(list(book["assets"].items())[page*20:(page+1)*20]):
            bpy.ops.import_scene.gltf(filepath=str(repo/row["path"].replace("res://","s2/")))
            imported=[o for o in bpy.context.selected_objects if o.type=="MESH"]
            anchor=right*((i%5-2)*3.3)+up*((1.5-i//5)*3.1+.25)
            for obj in imported:
                pts=[obj.matrix_world@Vector(v) for v in obj.bound_box]
                lo=Vector([min(p[j] for p in pts) for j in range(3)])
                hi=Vector([max(p[j] for p in pts) for j in range(3)])
                factor=2.35/max(hi-lo)
                obj.location=anchor-(lo+hi)*.5*factor
                obj.scale*=factor
            font=bpy.data.curves.new("PreviewLabel","FONT"); font.body=pid
            font.align_x="CENTER"; font.size=.18
            label=bpy.data.objects.new("PreviewLabel",font); scene.collection.objects.link(label)
            label.rotation_euler=cam.rotation_euler
            label.location=anchor-up*1.25+direction*.4
        scene.render.filepath=str(repo/f"s2/.godot/props_d_preview_{page+1}.png")
        bpy.ops.render.render(write_still=True)


def main():
    argv=sys.argv[sys.argv.index("--")+1:] if "--" in sys.argv else []
    parser=argparse.ArgumentParser(); parser.add_argument("--repo",required=True)
    parser.add_argument("--preview",action="store_true")
    args=parser.parse_args(argv); repo=Path(args.repo).resolve()
    source=(repo/"_in/kinds_d.json").read_bytes(); inputs=json.loads(source)
    assert {r["kind"] for r in inputs["kinds"]}==set(SPECS) and len(SPECS)==60
    assert sum(r["count"] for r in inputs["kinds"])==466
    out=repo/"s2/models/props_field"; out.mkdir(parents=True,exist_ok=True)
    maps,rects=census(repo)
    bpy.ops.wm.read_factory_settings(use_empty=True)
    rows=[]; failures=[]
    for src in inputs["kinds"]:
        pid=src["kind"]; p=Piece(pid)
        try:
            fp=src["rects_wh_top"][0][0] if src["rects_wh_top"] else list(rects[pid].most_common(1)[0][0])
            height,judgment=SPECS[pid]
            assert sum(m.get(pid,0) for m in maps.values())==src["count"], "원문 수 불일치"
            build(p); p.fit(fp,height)
            triangles=len(p.bm.faces)
            assert 0<triangles<=600, f"삼각형 상한: {triangles}"
            export(p,out/(pid+".glb")); size,digest=check_glb(out/(pid+".glb"),triangles)
            bounds=p.bounds()
            rows.append({"id":pid,"status":"ready","path":f"res://models/props_field/{pid}.glb",
                "count":src["count"],"maps":src["maps"],"solid":src["solid"],"facing":src["facing"],
                "map_families":src["map_families"],"footprint_m":fp,"height_m":height,
                "footprint_source":"_in/kinds_d.json" if src["rects_wh_top"] else "s2/game/world/maps/lake_*.gd (Rect2i)",
                "modal_rect_count":rects[pid][tuple(fp)],"bounds_m":bounds,
                "dimensions_m":[round(bounds[1][i]-bounds[0][i],6) for i in range(3)],
                "lod0_tris":triangles,"triangle_limit":600,"bytes":size,"sha256":digest,
                "colours":sorted(p.colours),"placement":PLACEMENT,"judgment":judgment})
            print(f"PROP_READY {pid} tris={triangles} bytes={size}",flush=True)
        except Exception as error:
            failures.append({"id":pid,"error":str(error),"type":type(error).__name__})
            print(f"PROP_FAILED {pid}: {error}",flush=True)
        finally:
            p.bm.free()
    book=write_books(out,rows,source,maps,failures)
    print(f"PROPS_D generated={len(rows)} failed={len(failures)} max_map={book['census']['max_map']} triangles={book['census']['max_map_triangles_d']}",flush=True)
    if failures:
        raise SystemExit(1)
    if args.preview:
        preview(repo,book)


if __name__=="__main__":
    main()
