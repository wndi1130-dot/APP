"""열차 겉몸 여섯(객차 다섯 + 화차). Blender 헤드리스, 외부 자원 없이 작은 색 그림 한 장만 넣는다.

blender -b --factory-startup -P tools/blender/train_exterior.py -- --repo .
blender -b --factory-startup -P tools/blender/train_exterior.py -- --repo . --preview

생성 모델이 녹아내린 곳(덩어리 바퀴, 사다리꼴 창, 너덜한 끝단, 뭉친 지붕 환기구)을
단순한 새 모양으로 갈아 끼운다. 논리 좌표는 glTF X(길이) / Y 위 / Z 앞(카메라 쪽).
원점은 길이·폭의 가운데, 레일 위(Y=0). 길이는 완충기 끝까지 16m(train_model_kit가 길이로 배율을 정한다).
노드 둘: <id>_LOD0, <id>_LOD1(LOD1은 삼각형 절반 이하). 재질 하나, 색 그림 256x256 한 장(칸 가운데만 찍는다).
"""
import sys
sys.dont_write_bytecode = True

import argparse
import hashlib
import json
import math
import struct
from pathlib import Path

import bmesh
import bpy
from mathutils import Vector

SCRIPT_VERSION = 1
ATLAS = 256
CELL = 32
# sRGB 0..255. 흰 눈 바탕에서 튀지 않게 어둡고 차갑게(셰이더가 채도를 다시 누른다).
PALETTE = {
    "green": (74, 92, 78), "green_dark": (50, 62, 54), "green_faded": (96, 108, 96),
    "maroon": (100, 52, 46), "maroon_dark": (70, 38, 34),
    "blue": (50, 60, 76), "blue_dark": (34, 40, 52),
    "cream": (172, 166, 146), "grey": (104, 108, 104),
    "plank": (112, 88, 64), "plank_dark": (74, 58, 44), "plank_grey": (118, 110, 98),
    "roof": (98, 98, 96), "roof_dark": (58, 60, 62), "roof_seam": (48, 48, 50), "tarp": (102, 98, 78),
    "iron": (38, 38, 40), "iron_worn": (62, 60, 58), "rust": (104, 64, 44),
    "steel": (88, 88, 90),
    "glass": (30, 38, 46), "glass_warm": (96, 78, 54), "glass_green": (70, 92, 78),
    "curtain": (166, 160, 144), "curtain_red": (108, 56, 48),
    "brass": (140, 112, 58), "black": (20, 20, 22), "bellows": (36, 34, 32),
    "leaf": (58, 84, 52), "inside": (22, 20, 19), "crate": (124, 100, 72), "sack": (132, 120, 98),
}
NAMES = list(PALETTE)
assert len(NAMES) <= (ATLAS // CELL) ** 2

# 공통 치수(m)
HALF_L = 8.0          # 완충기 끝
BODY_X = 7.6          # 차체 끝벽
BODY_Z = 1.40         # 옆벽
FLOOR_Y = 1.15        # 차체 밑
EAVE_Y = 2.62         # 처마
PEAK_Y = 2.92         # 지붕 꼭대기
BOGIE_X = 5.25
AXLE_GAP = 1.05
WHEEL_R = 0.46
WHEEL_Z = 0.72


def uv_of(colour):
    i = NAMES.index(colour)
    cx = (i % (ATLAS // CELL)) * CELL + CELL / 2
    cy = (i // (ATLAS // CELL)) * CELL + CELL / 2
    # glTF는 V가 위에서 아래로 가지만 Blender UV는 아래에서 위다.
    return (cx / ATLAS, 1.0 - cy / ATLAS)


class Piece:
    """한 BMesh. 면마다 한 색(그 색 칸의 가운데 UV)."""
    def __init__(self, pid):
        self.pid = pid
        self.bm = bmesh.new()
        self.uv = self.bm.loops.layers.uv.new("UVMap")

    def face(self, pts, colour, outward):
        pts = [Vector((p[0], -p[2], p[1])) for p in pts]
        outward = Vector((outward[0], -outward[2], outward[1]))
        normal = Vector((0, 0, 0))
        for i, a in enumerate(pts):
            normal += a.cross(pts[(i + 1) % len(pts)])
        if normal.length < 1e-10:
            raise ValueError("넓이 없는 면: %s %s" % (self.pid, colour))
        if normal.dot(outward) < 0:
            pts.reverse()
        f = self.bm.faces.new([self.bm.verts.new(p) for p in pts])
        f.smooth = False
        u = uv_of(colour)
        for loop in f.loops:
            loop[self.uv].uv = u

    def box(self, x, y, z, colour, top=None, skip=()):
        x0, x1 = x
        y0, y1 = y
        z0, z1 = z
        if min(x1 - x0, y1 - y0, z1 - z0) <= 0:
            raise ValueError("빈 상자: %s" % self.pid)
        if "-x" not in skip:
            self.face([(x0, y0, z0), (x0, y1, z0), (x0, y1, z1), (x0, y0, z1)], colour, (-1, 0, 0))
        if "+x" not in skip:
            self.face([(x1, y0, z0), (x1, y1, z0), (x1, y1, z1), (x1, y0, z1)], colour, (1, 0, 0))
        if "-y" not in skip:
            self.face([(x0, y0, z0), (x1, y0, z0), (x1, y0, z1), (x0, y0, z1)], colour, (0, -1, 0))
        if "+y" not in skip:
            self.face([(x0, y1, z0), (x1, y1, z0), (x1, y1, z1), (x0, y1, z1)], top or colour, (0, 1, 0))
        if "-z" not in skip:
            self.face([(x0, y0, z0), (x1, y0, z0), (x1, y1, z0), (x0, y1, z0)], colour, (0, 0, -1))
        if "+z" not in skip:
            self.face([(x0, y0, z1), (x1, y0, z1), (x1, y1, z1), (x0, y1, z1)], colour, (0, 0, 1))

    def cyl(self, a, b, r, colour, sides=8, caps=True, cap_colour=None):
        a, b = Vector(a), Vector(b)
        axis = (b - a).normalized()
        guide = Vector((1, 0, 0)) if abs(axis.y) > .9 else Vector((0, 1, 0))
        u = axis.cross(guide).normalized()
        v = axis.cross(u).normalized()
        ring = [u * math.cos(i * math.tau / sides) + v * math.sin(i * math.tau / sides) for i in range(sides)]
        lo = [a + d * r for d in ring]
        hi = [b + d * r for d in ring]
        if caps:
            self.face(lo, cap_colour or colour, -axis)
            self.face(hi, cap_colour or colour, axis)
        for i in range(sides):
            j = (i + 1) % sides
            self.face([lo[i], lo[j], hi[j], hi[i]], colour, ring[i] + ring[j])

    def fin(self):
        bmesh.ops.triangulate(self.bm, faces=list(self.bm.faces))
        self.bm.normal_update()
        if any(f.calc_area() < 1e-11 for f in self.bm.faces):
            raise ValueError("퇴화 삼각형: " + self.pid)
        return len(self.bm.faces)


# ---------------------------------------------------------------- 부품
def roof_profile(z_half, eave, peak, steps):
    """처마에서 꼭대기까지 납작한 타원 호. (z, y) 목록, 앞(+z)에서 뒤(-z)로."""
    pts = []
    for i in range(steps + 1):
        t = i / steps * math.pi
        pts.append((z_half * math.cos(t), eave + (peak - eave) * math.sin(t)))
    return pts


def roof(p, x0, x1, colour, steps, z_half=1.44, eave=EAVE_Y, peak=PEAK_Y, under=True, caps=True, cap_colour=None):
    prof = roof_profile(z_half, eave, peak, steps)
    for (za, ya), (zb, yb) in zip(prof, prof[1:]):
        # 호의 가운데(처마 높이의 z=0)에서 바깥으로
        p.face([(x0, ya, za), (x1, ya, za), (x1, yb, zb), (x0, yb, zb)], colour, (0, (ya + yb) / 2 - eave + 0.01, (za + zb) / 2))
    if under:
        p.face([(x0, eave - 0.03, z_half), (x1, eave - 0.03, z_half), (x1, eave - 0.03, -z_half), (x0, eave - 0.03, -z_half)], "roof_dark", (0, -1, 0))
        for zs in (1, -1):
            p.face([(x0, eave - 0.03, zs * z_half), (x1, eave - 0.03, zs * z_half), (x1, eave, zs * z_half), (x0, eave, zs * z_half)], colour, (0, 0, zs))
    if caps:
        for xe, xs in ((x0, -1), (x1, 1)):
            ring = [(xe, eave - 0.03, z_half)] + [(xe, y, z) for z, y in prof] + [(xe, eave - 0.03, -z_half)]
            p.face(ring, cap_colour or colour, (xs, 0, 0))


def side_wall(p, zs, openings, colour, y0=FLOOR_Y, y1=EAVE_Y, depth=0.06, detail=True):
    """옆벽 한 면(z = zs*BODY_Z). openings: [(x0, x1, ya, yb, inner_colour)] 사람 키 높이의 창·문 구멍.
    구멍마다 벽은 띠로 나뉘고, 안쪽 면은 depth만큼 들어가 있다(LOD0은 구멍 둘레 면까지)."""
    z = zs * BODY_Z
    xs = sorted(openings)
    if not detail:
        # 먼 판: 벽 한 장에 구멍 자리를 3mm 앞에 붙인다(틈으로 속이 비쳐 보이지 않게).
        p.face([(-BODY_X, y0, z), (BODY_X, y0, z), (BODY_X, y1, z), (-BODY_X, y1, z)], colour, (0, 0, zs))
        zf = zs * (BODY_Z + 0.003)
        for (a, b, ya, yb, inner) in xs:
            p.face([(a, ya, zf), (b, ya, zf), (b, yb, zf), (a, yb, zf)], inner, (0, 0, zs))
        return
    # 구멍이 없는 띠: 구멍 사이 기둥, 구멍 위·아래 띠
    cuts = [-BODY_X]
    for o in xs:
        cuts += [o[0], o[1]]
    cuts.append(BODY_X)
    # 기둥(구멍 사이 전체 높이)
    for i in range(0, len(cuts), 2):
        a, b = cuts[i], cuts[i + 1]
        if b - a > 1e-6:
            p.face([(a, y0, z), (b, y0, z), (b, y1, z), (a, y1, z)], colour, (0, 0, zs))
    for (a, b, ya, yb, inner) in xs:
        if ya > y0 + 1e-6:
            p.face([(a, y0, z), (b, y0, z), (b, ya, z), (a, ya, z)], colour, (0, 0, zs))
        if yb < y1 - 1e-6:
            p.face([(a, yb, z), (b, yb, z), (b, y1, z), (a, y1, z)], colour, (0, 0, zs))
        zi = zs * (BODY_Z - depth)
        p.face([(a, ya, zi), (b, ya, zi), (b, yb, zi), (a, yb, zi)], inner, (0, 0, zs))
        # 구멍 둘레(위·아래·양옆), 아래는 창턱 색
        p.face([(a, ya, zi), (b, ya, zi), (b, ya, z), (a, ya, z)], "iron_worn", (0, 1, 0))
        p.face([(a, yb, zi), (b, yb, zi), (b, yb, z), (a, yb, z)], colour, (0, -1, 0))
        p.face([(a, ya, zi), (a, yb, zi), (a, yb, z), (a, ya, z)], colour, (1, 0, 0))
        p.face([(b, ya, zi), (b, yb, zi), (b, yb, z), (b, ya, z)], colour, (-1, 0, 0))


def end_wall(p, xs, colour, door_colour="inside", detail=True, bellows=True, top=EAVE_Y):
    """끝벽 한 면(x = xs*BODY_X): 가운데 연결 문, 그 둘레 연결막(LOD0은 주름 셋)."""
    x = xs * BODY_X
    dz, dy0, dy1 = 0.42, FLOOR_Y + 0.05, 2.38
    p.face([(x, FLOOR_Y, -BODY_Z), (x, FLOOR_Y, -dz), (x, top, -dz), (x, top, -BODY_Z)], colour, (xs, 0, 0))
    p.face([(x, FLOOR_Y, dz), (x, FLOOR_Y, BODY_Z), (x, top, BODY_Z), (x, top, dz)], colour, (xs, 0, 0))
    p.face([(x, FLOOR_Y, -dz), (x, FLOOR_Y, dz), (x, dy0, dz), (x, dy0, -dz)], colour, (xs, 0, 0))
    p.face([(x, dy1, -dz), (x, dy1, dz), (x, top, dz), (x, top, -dz)], colour, (xs, 0, 0))
    if not bellows:
        p.face([(x, dy0, -dz), (x, dy0, dz), (x, dy1, dz), (x, dy1, -dz)], door_colour, (xs, 0, 0))
        return
    # 연결막: 문 둘레를 감싸는 고무 주름 상자(문 쪽은 비어 어두운 통로)
    x1 = xs * (BODY_X + 0.30)
    lo, hi = sorted((x, x1))
    w, yb, yt = 0.56, FLOOR_Y + 0.02, 2.48
    p.box((lo, hi), (yb, yt), (-w, w), "bellows", skip=("+x" if xs > 0 else "-x", "-x" if xs > 0 else "+x"))
    p.face([(x1, yb, -w), (x1, yb, w), (x1, yb + 0.06, w), (x1, yb + 0.06, -w)], "iron", (xs, 0, 0))
    p.face([(x1, yt - 0.06, -w), (x1, yt - 0.06, w), (x1, yt, w), (x1, yt, -w)], "iron", (xs, 0, 0))
    p.face([(x1, yb + 0.06, -w), (x1, yb + 0.06, -dz), (x1, yt - 0.06, -dz), (x1, yt - 0.06, -w)], "iron", (xs, 0, 0))
    p.face([(x1, yb + 0.06, dz), (x1, yb + 0.06, w), (x1, yt - 0.06, w), (x1, yt - 0.06, dz)], "iron", (xs, 0, 0))
    p.face([(x1, yb + 0.06, -dz), (x1, yb + 0.06, dz), (x1, yt - 0.06, dz), (x1, yt - 0.06, -dz)], door_colour, (xs, 0, 0))
    if detail:
        for k in range(1, 3):
            xr = x + (x1 - x) * k / 3.0
            a, b = sorted((xr - 0.015, xr + 0.015))
            p.box((a, b), (yb - 0.01, yt + 0.01), (-w - 0.02, w + 0.02), "black", skip=("-x", "+x"))


def underframe(p, detail=True, length=BODY_X):
    """차체 밑: 옆 들보, 완충 들보, 완충기 넷, 연결기 둘, (LOD0) 버팀 막대·밑 상자."""
    for zs in (1, -1):
        p.box((-length, length), (FLOOR_Y - 0.17, FLOOR_Y), sorted((zs * 1.22, zs * 1.34)), "iron")
    for xs in (1, -1):
        a, b = sorted((xs * length, xs * (length + 0.14)))
        p.box((a, b), (0.86, FLOOR_Y + 0.02), (-1.36, 1.36), "iron_worn" if detail else "iron")
        for zs in (1, -1):
            if detail:
                a, b = xs * (length + 0.14), xs * (HALF_L - 0.05)
                p.cyl((a, 1.02, zs * 0.86), (b, 1.02, zs * 0.86), 0.08, "iron", 6)
                p.cyl((xs * (HALF_L - 0.05), 1.02, zs * 0.86), (xs * HALF_L, 1.02, zs * 0.86), 0.19, "steel", 10, cap_colour="iron_worn")
            else:
                a, b = sorted((xs * (length + 0.14), xs * HALF_L))
                p.box((a, b), (0.86, 1.18), sorted((zs * 0.66, zs * 1.06)), "iron")
        a, b = sorted((xs * (length + 0.14), xs * (HALF_L - 0.12)))
        p.box((a, b), (0.95, 1.08), (-0.09, 0.09), "iron")
    if detail:
        # 버팀 막대(옆에서 보이는 V자) 둘과 가운데 기둥
        for zs in (1, -1):
            z = zs * 1.16
            pts = [(-3.9, FLOOR_Y - 0.15, z), (-1.4, 0.70, z), (1.4, 0.70, z), (3.9, FLOOR_Y - 0.15, z)]
            for a, b in zip(pts, pts[1:]):
                p.cyl(a, b, 0.025, "iron", 4, caps=False)
            for x in (-1.4, 1.4):
                p.cyl((x, 0.70, z), (x, FLOOR_Y - 0.17, z), 0.03, "iron", 4, caps=False)
        p.box((-1.0, 1.0), (0.66, FLOOR_Y - 0.17), (-0.62, 0.62), "iron_worn")


def bogie(p, cx, detail=True):
    """대차 하나: 바퀴 넷(축 둘), 옆틀 둘, 축상자, 판스프링, 받침보."""
    sides = 16 if detail else 8   # 16·8각은 꼭짓점 하나가 레일 위(Y=0)에 닿는다
    for ax in (cx - AXLE_GAP, cx + AXLE_GAP):
        for zs in (1, -1):
            z0, z1 = sorted((zs * (WHEEL_Z - 0.06), zs * (WHEEL_Z + 0.06)))
            p.cyl((ax, WHEEL_R, z0), (ax, WHEEL_R, z1), WHEEL_R, "iron", sides, cap_colour="iron_worn")
            if detail:
                # 바퀴 가운데 굴대 머리(옆에서 둥근 점)
                za, zb = sorted((zs * (WHEEL_Z + 0.06), zs * (WHEEL_Z + 0.10)))
                p.cyl((ax, WHEEL_R, za), (ax, WHEEL_R, zb), 0.12, "steel", 6)
        if detail:
            p.cyl((ax, WHEEL_R, -WHEEL_Z), (ax, WHEEL_R, WHEEL_Z), 0.06, "iron", 6, caps=False)
    for zs in (1, -1):
        z0, z1 = sorted((zs * 0.84, zs * 0.96))
        p.box((cx - 1.55, cx + 1.55), (0.56, 0.78), (z0, z1), "iron_worn" if detail else "iron")
        if detail:
            for ax in (cx - AXLE_GAP, cx + AXLE_GAP):
                p.box((ax - 0.16, ax + 0.16), (0.30, 0.62), (z0 - 0.02, z1 + 0.02), "iron")
            p.box((cx - 0.55, cx + 0.55), (0.78, 0.90), (z0, z1), "steel")
            p.box((cx - 0.08, cx + 0.08), (0.86, 0.98), (z0, z1), "iron")
    p.box((cx - 0.16, cx + 0.16), (0.78, FLOOR_Y - 0.17), (-1.0, 1.0), "iron")


def door(p, zs, x0, x1, colour, detail=True):
    """옆 문 아래 디딤판 둘과 손잡이 둘. 문 구멍 자체는 side_wall이 낸다."""
    z = zs * BODY_Z
    za, zb = sorted((zs * (BODY_Z - 0.26), zs * (BODY_Z - 0.02)))
    p.box((x0 + 0.04, x1 - 0.04), (FLOOR_Y - 0.30, FLOOR_Y - 0.25), (za, zb), "iron")
    if detail:
        za2, zb2 = sorted((zs * (BODY_Z - 0.14), zs * (BODY_Z - 0.02)))
        p.box((x0 + 0.04, x1 - 0.04), (FLOOR_Y - 0.62, FLOOR_Y - 0.57), (za2, zb2), "iron")
        for x in (x0 - 0.06, x1 + 0.06):
            p.cyl((x, 1.45, z + zs * 0.04), (x, 2.25, z + zs * 0.04), 0.018, "brass" if colour != "plank" else "iron", 4, caps=False)


def door_panel(p, zs, x0, x1, panel, window="glass", detail=True):
    """문짝의 작은 창(문판은 구멍 안쪽 면). 먼 판은 벽 앞 4mm."""
    zi = zs * (BODY_Z - 0.055) if detail else zs * (BODY_Z + 0.004)
    p.face([(x0 + 0.05, 1.82, zi), (x1 - 0.05, 1.82, zi), (x1 - 0.05, 2.22, zi), (x0 + 0.05, 2.22, zi)], window, (0, 0, zs))


def vent(p, x, detail=True, y=PEAK_Y):
    """지붕 환기구: 60m 뒤 필드 카메라에서도 점으로 읽히는 크기."""
    if detail:
        p.cyl((x, y - 0.03, 0), (x, y + 0.04, 0), 0.19, "roof_seam", 8, caps=False)
        p.cyl((x, y + 0.04, 0), (x, y + 0.10, 0), 0.15, "iron", 8, cap_colour="roof_seam")
    else:
        p.box((x - 0.16, x + 0.16), (y - 0.02, y + 0.09), (-0.16, 0.16), "roof_seam")


def roof_seams(p, detail, x0=-BODY_X, x1=BODY_X, every=1.9, z_half=1.44, eave=EAVE_Y, peak=PEAK_Y, colour="roof_seam"):
    """지붕 판 이음 띠(가로). 지붕 위 6mm, 폭 5cm."""
    n = int((x1 - x0) / every)
    for i in range(1, n + 1):
        x = x0 + (x1 - x0) * i / (n + 1)
        roof(p, x - 0.025, x + 0.025, colour, 8 if detail else 4, z_half=z_half, eave=eave + 0.006, peak=peak + 0.006, under=False, caps=False)


def windows_row(count, width, x_from=-6.1, x_to=6.1, ya=1.62, yb=2.32, inner="glass"):
    gap = (x_to - x_from - count * width) / max(count - 1, 1)
    out = []
    for i in range(count):
        a = x_from + i * (width + gap)
        out.append([a, a + width, ya, yb, inner])
    return out


# ---------------------------------------------------------------- 객차
def coach(p, detail, body, body_low=None, roof_col="roof", wins=None, door_xs=(6.55, 7.25),
          extras=None, vents=(-4.5, -1.5, 1.5, 4.5), belt=None, door_col=None):
    """공통 객차. wins: windows_row 결과(같은 줄을 양옆에), 문은 양 끝 가까이 양옆."""
    door_col = door_col or body
    for zs in (1, -1):
        holes = [list(w) for w in wins]
        for xs in (1, -1):
            a, b = sorted((xs * door_xs[0], xs * door_xs[1]))
            holes.append([a, b, FLOOR_Y + 0.08, 2.36, door_col])
        side_wall(p, zs, holes, body, detail=detail)
        for xs in (1, -1):
            a, b = sorted((xs * door_xs[0], xs * door_xs[1]))
            door(p, zs, a, b, body, detail)
            door_panel(p, zs, a, b, door_col, detail=detail)
        doors_only = [h for h in holes if h[2] < 1.4]
        if body_low and detail:
            # 아래쪽 판(색이 다른 허리 아래 띠), 벽에서 1cm 나옴. 문 자리만 비운다.
            z0, z1 = sorted((zs * BODY_Z, zs * (BODY_Z + 0.01)))
            for (a, b) in _between(doors_only, -BODY_X, BODY_X):
                p.box((a, b), (FLOOR_Y, 1.52), (z0, z1), body_low, skip=("-y",))
        if belt and detail:
            z0, z1 = sorted((zs * BODY_Z, zs * (BODY_Z + 0.015)))
            for (a, b) in _between(doors_only, -BODY_X, BODY_X):
                p.box((a, b), (1.53, 1.58), (z0, z1), belt, skip=("-y",))
    for xs in (1, -1):
        end_wall(p, xs, body, detail=detail)
    liner(p)
    # 차체 바닥 밑면
    p.face([(-BODY_X, FLOOR_Y, -BODY_Z), (BODY_X, FLOOR_Y, -BODY_Z), (BODY_X, FLOOR_Y, BODY_Z), (-BODY_X, FLOOR_Y, BODY_Z)], "iron", (0, -1, 0))
    roof(p, -BODY_X - 0.08, BODY_X + 0.08, roof_col, 8 if detail else 4)
    roof_seams(p, detail)
    if detail:
        for zs in (1, -1):
            z0, z1 = sorted((zs * 1.40, zs * 1.47))
            p.box((-BODY_X - 0.08, BODY_X + 0.08), (EAVE_Y - 0.07, EAVE_Y - 0.02), (z0, z1), "iron")
    for x in vents:
        vent(p, x, detail)
    underframe(p, detail)
    for cx in (-BOGIE_X, BOGIE_X):
        bogie(p, cx, detail)
    if extras:
        extras(p, detail)


def liner(p):
    """안쪽 면: 홈 단면(앞벽 위를 잘라 냄)에서 칸 속이 비어 보이지 않게 뒷벽·끝벽 안쪽과 바닥 윗면을 둔다."""
    zi = -(BODY_Z - 0.07)
    p.face([(-BODY_X + 0.07, FLOOR_Y, zi), (BODY_X - 0.07, FLOOR_Y, zi), (BODY_X - 0.07, EAVE_Y, zi), (-BODY_X + 0.07, EAVE_Y, zi)], "plank", (0, 0, 1))
    p.face([(-BODY_X + 0.07, FLOOR_Y + 0.01, -BODY_Z + 0.07), (BODY_X - 0.07, FLOOR_Y + 0.01, -BODY_Z + 0.07),
            (BODY_X - 0.07, FLOOR_Y + 0.01, BODY_Z - 0.07), (-BODY_X + 0.07, FLOOR_Y + 0.01, BODY_Z - 0.07)], "plank_dark", (0, 1, 0))
    for xs in (1, -1):
        x = xs * (BODY_X - 0.07)
        p.face([(x, FLOOR_Y, -BODY_Z + 0.07), (x, FLOOR_Y, BODY_Z - 0.07), (x, EAVE_Y, BODY_Z - 0.07), (x, EAVE_Y, -BODY_Z + 0.07)], "plank", (-xs, 0, 0))


def _between(holes, lo, hi):
    """구멍들 사이의 빈 구간(아래 띠를 구멍 밖에만 붙인다)."""
    out = []
    cur = lo
    for h in sorted(holes):
        if h[0] > cur + 1e-6:
            out.append((cur, h[0]))
        cur = max(cur, h[1])
    if hi > cur + 1e-6:
        out.append((cur, hi))
    return out


def worn_extras(p, detail):
    # 덧댄 판자(아래 판), 창 아래 1/3만 가린 판자 둘(불빛이 보이게, 금지선), 지붕 방수포, 손으로 단 연통
    for zs in (1, -1):
        z0, z1 = sorted((zs * BODY_Z, zs * (BODY_Z + 0.025)))
        for (a, b) in ((-5.2, -3.9), (-0.9, 0.5), (2.6, 3.4)) if zs > 0 else ((-3.2, -2.0), (1.4, 2.9)):
            p.box((a, b), (FLOOR_Y + 0.08, 1.46), (z0, z1), "plank_grey", skip=("-y",))
            if detail:
                p.box((a, b), (FLOOR_Y + 0.33, FLOOR_Y + 0.37), sorted((zs * (BODY_Z + 0.025), zs * (BODY_Z + 0.035))), "plank_dark")
    wins = windows_row(8, 0.9, x_from=-5.9, x_to=5.9)
    for zs, ks in ((1, (2, 5)), (-1, (1,))):
        for k in ks:
            a, b = wins[k][0], wins[k][1]
            z0, z1 = sorted((zs * (BODY_Z - 0.06), zs * (BODY_Z + 0.02)))
            p.box((a - 0.04, b + 0.04), (1.60, 1.86), (z0, z1), "plank_grey")
    roof(p, -2.6, 0.4, "tarp", 8 if detail else 4, eave=EAVE_Y + 0.015, peak=PEAK_Y + 0.015, under=False, caps=detail)
    # 덧댄 함석 한 장(지붕 앞쪽 경사만)
    prof = roof_profile(1.44, EAVE_Y + 0.012, PEAK_Y + 0.012, 8)
    for (za, ya), (zb, yb) in zip(prof[0:3], prof[1:4]):
        p.face([(4.4, ya, za), (5.9, ya, za), (5.9, yb, zb), (4.4, yb, zb)], "rust", (0, (ya + yb) / 2 - EAVE_Y + 0.01, (za + zb) / 2))
    if detail:
        # 창 아래로 흘러내린 녹 자국(몇 창만)
        for zs in (1, -1):
            z0, z1 = sorted((zs * (BODY_Z + 0.002), zs * (BODY_Z + 0.008)))
            for k in ((0, 3, 6) if zs > 0 else (2, 4)):
                a = wins[k][0] + 0.15
                p.box((a, a + 0.07), (1.30, 1.60), (z0, z1), "rust", skip=("-y", "+y"))
    x = 3.1
    p.cyl((x, PEAK_Y - 0.04, -0.55), (x, PEAK_Y + 0.38, -0.55), 0.07, "iron", 6 if detail else 4)
    if detail:
        p.cyl((x, PEAK_Y + 0.38, -0.55), (x, PEAK_Y + 0.42, -0.55), 0.13, "iron", 6)


def chief_extras(p, detail):
    if not detail:
        return
    # 창 양옆에 접힌 커튼(창 안쪽 면 앞)
    for zs in (1, -1):
        zi = zs * (BODY_Z - 0.05)
        for w in windows_row(5, 1.45, x_from=-5.6, x_to=5.6):
            for a, b in ((w[0] + 0.02, w[0] + 0.24), (w[1] - 0.24, w[1] - 0.02)):
                p.face([(a, w[2] + 0.02, zi), (b, w[2] + 0.02, zi), (b, w[3] - 0.02, zi), (a, w[3] - 0.02, zi)], "curtain_red", (0, 0, zs))


def medic_extras(p, detail):
    # 반쯤 친 흰 커튼(창 아래 절반)
    for zs in (1, -1):
        zi = zs * (BODY_Z - 0.05)
        for w in windows_row(7, 1.0):
            p.face([(w[0] + 0.02, w[2] + 0.02, zi), (w[1] - 0.02, w[2] + 0.02, zi), (w[1] - 0.02, (w[2] + w[3]) / 2, zi), (w[0] + 0.02, (w[2] + w[3]) / 2, zi)], "curtain", (0, 0, zs))


def glass_coach(p, detail):
    """온실칸: 나무 아래 판, 위는 유리 벽(세로 살), 지붕 가운데 유리 등."""
    y_glass = 1.62
    for zs in (1, -1):
        holes = [[-BODY_X + 0.35, BODY_X - 0.35, y_glass, 2.48, "glass_green"]]
        side_wall(p, zs, holes, "plank", detail=detail)
        if detail:
            z0, z1 = sorted((zs * (BODY_Z - 0.065), zs * (BODY_Z - 0.01)))
            n = 14
            for i in range(1, n):
                x = -BODY_X + 0.35 + (2 * (BODY_X - 0.35)) * i / n
                p.box((x - 0.03, x + 0.03), (y_glass, 2.48), (z0, z1), "plank_dark", skip=("-y", "+y"))
            # 안쪽 화분 줄(유리 아래쪽 어두운 잎)
            zi = zs * (BODY_Z - 0.055)
            for i in range(0, n, 2):
                a = -BODY_X + 0.4 + (2 * (BODY_X - 0.35)) * i / n
                b = a + (2 * (BODY_X - 0.35)) / n - 0.1
                p.face([(a, y_glass + 0.02, zi), (b, y_glass + 0.02, zi), (b, y_glass + 0.32, zi), (a, y_glass + 0.32, zi)], "leaf", (0, 0, zs))
        z0, z1 = sorted((zs * BODY_Z, zs * (BODY_Z + 0.012)))
        if detail:
            p.box((-BODY_X, BODY_X), (FLOOR_Y + 0.2, FLOOR_Y + 0.25), (z0, z1), "plank_dark", skip=("-y",))
    for xs in (1, -1):
        end_wall(p, xs, "plank", detail=detail)
    liner(p)
    p.face([(-BODY_X, FLOOR_Y, -BODY_Z), (BODY_X, FLOOR_Y, -BODY_Z), (BODY_X, FLOOR_Y, BODY_Z), (-BODY_X, FLOOR_Y, BODY_Z)], "iron", (0, -1, 0))
    roof(p, -BODY_X - 0.08, BODY_X + 0.08, "roof", 8 if detail else 4)
    roof_seams(p, detail, x0=-BODY_X, x1=-5.7, every=0.95)
    roof_seams(p, detail, x0=5.7, x1=BODY_X, every=0.95)
    # 가운데 유리 등(높인 채광창): 양 경사면이 유리
    lx0, lx1, w, yb, yt = -5.6, 5.6, 0.62, PEAK_Y - 0.06, PEAK_Y + 0.12
    for zs in (1, -1):
        p.face([(lx0, yb, zs * w), (lx1, yb, zs * w), (lx1, yt, zs * 0.18), (lx0, yt, zs * 0.18)], "glass_green", (0, 1, zs))
    p.face([(lx0, yt, -0.18), (lx1, yt, -0.18), (lx1, yt, 0.18), (lx0, yt, 0.18)], "roof_dark", (0, 1, 0))
    for xe, xs in ((lx0, -1), (lx1, 1)):
        p.face([(xe, yb, -w), (xe, yb, w), (xe, yt, 0.18), (xe, yt, -0.18)], "roof_dark", (xs, 0, 0))
    if detail:
        for i in range(1, 8):
            x = lx0 + (lx1 - lx0) * i / 8
            p.box((x - 0.025, x + 0.025), (yb, yt + 0.01), (-w, w), "roof_dark", skip=("-y",))
    underframe(p, detail)
    for cx in (-BOGIE_X, BOGIE_X):
        bogie(p, cx, detail)


def freight(p, detail):
    """덮개 화차: 세로 판자 벽, 문은 처음부터 열려 옆으로 밀려 있다(금지선). 안에 상자·자루."""
    top = 3.35
    door_a, door_b = -0.95, 0.95
    for zs in (1, -1):
        holes = [[door_a, door_b, FLOOR_Y + 0.02, 3.0, "inside"]]
        side_wall(p, zs, holes, "plank", y1=top, depth=1.2 if detail else 0.9, detail=detail)
        z0, z1 = sorted((zs * BODY_Z, zs * (BODY_Z + 0.05)))
        # 열어 둔 미닫이 문짝(문 구멍 옆 벽 앞)
        p.box((door_b + 0.05, door_b + 1.95), (FLOOR_Y + 0.02, 3.02), (z0, z1), "plank_grey")
        if detail:
            p.box((door_a - 0.2, door_b + 2.1), (3.04, 3.10), sorted((zs * BODY_Z, zs * (BODY_Z + 0.08))), "iron")
            # 세로 살과 X 버팀 쇠띠
            for x in (-6.4, -4.6, -2.8, 3.6, 5.2, 6.8):
                p.box((x - 0.04, x + 0.04), (FLOOR_Y, top), (z0, z1), "plank_dark", skip=("-y", "+y"))
            for (a, b) in ((-6.4, -4.6), (-4.6, -2.8), (3.6, 5.2), (5.2, 6.8)):
                p.cyl((a, FLOOR_Y + 0.1, zs * (BODY_Z + 0.03)), (b, top - 0.1, zs * (BODY_Z + 0.03)), 0.025, "iron", 4, caps=False)
            # 문간으로 보이는 짐: 나무 상자와 자루(가방·신발 무더기 없음, 금지선)
            zi0, zi1 = sorted((zs * 0.2, zs * (BODY_Z - 0.3)))
            p.box((-0.8, -0.1), (FLOOR_Y, FLOOR_Y + 0.6), (zi0, zi1), "crate")
            p.box((0.05, 0.75), (FLOOR_Y, FLOOR_Y + 0.42), (zi0, zi1), "sack")
            p.box((-0.6, 0.0), (FLOOR_Y + 0.6, FLOOR_Y + 1.0), (zi0, zi1), "crate")
    for xs in (1, -1):
        x = xs * BODY_X
        p.face([(x, FLOOR_Y, -BODY_Z), (x, FLOOR_Y, BODY_Z), (x, top, BODY_Z), (x, top, -BODY_Z)], "plank", (xs, 0, 0))
        if detail:
            a, b = sorted((x, x + xs * 0.04))
            for z in (-0.9, 0.0, 0.9):
                p.box((a, b), (FLOOR_Y, top), (z - 0.05, z + 0.05), "plank_dark", skip=("-y", "+y"))
    p.face([(-BODY_X, FLOOR_Y, -BODY_Z), (BODY_X, FLOOR_Y, -BODY_Z), (BODY_X, FLOOR_Y, BODY_Z), (-BODY_X, FLOOR_Y, BODY_Z)], "iron", (0, -1, 0))
    roof(p, -BODY_X - 0.06, BODY_X + 0.06, "roof", 6 if detail else 3, eave=top, peak=top + 0.22)
    roof_seams(p, detail, every=1.2, eave=top, peak=top + 0.22)
    # 지붕 위 걷는 판(가운데 줄)
    p.box((-BODY_X, BODY_X), (top + 0.22, top + 0.26), (-0.22, 0.22), "plank_dark")
    underframe(p, detail)
    for cx in (-BOGIE_X, BOGIE_X):
        bogie(p, cx, detail)


def build_worn(p, d):
    coach(p, d, "green", body_low="green_dark", roof_col="roof",
          wins=windows_row(8, 0.9, x_from=-5.9, x_to=5.9), extras=worn_extras, vents=(-4.6, -0.9, 1.6, 4.6), door_col="green_faded")


def build_clean(p, d):
    coach(p, d, "maroon", body_low="maroon_dark", roof_col="roof",
          wins=windows_row(9, 0.95, x_from=-6.0, x_to=6.0, ya=1.6, yb=2.36), belt="cream", door_col="maroon_dark")


def build_chief(p, d):
    coach(p, d, "blue", body_low="blue_dark", roof_col="roof_dark",
          wins=windows_row(5, 1.45, x_from=-5.6, x_to=5.6, ya=1.6, yb=2.36, inner="glass_warm"), belt="brass",
          extras=chief_extras, vents=(-3.0, 0.0, 3.0), door_col="blue_dark")


def build_medic(p, d):
    coach(p, d, "cream", body_low="grey", roof_col="roof",
          wins=windows_row(7, 1.0), extras=medic_extras, vents=(-4.5, -2.0, 2.0, 4.5), door_col="grey")


BUILDERS = {
    "coach_worn": (build_worn, "판자를 덧댄 낡은 3등 객차(꼬리·식당·경비·공방·찬 칸 등)"),
    "coach_clean": (build_clean, "칠이 남은 앞칸 객차, 크림 띠"),
    "coach_chief": (build_chief, "열차장실, 큰 창 다섯과 접힌 커튼"),
    "coach_medic": (build_medic, "의무칸, 반쯤 친 흰 커튼. 붉은 십자 없음"),
    "coach_glass": (glass_coach, "온실칸, 유리 벽과 지붕 채광창"),
    "freight_open": (freight, "문을 열어 둔 덮개 화차, 문간에 나무 상자·자루"),
}


# ---------------------------------------------------------------- 내보내기
def atlas_image():
    img = bpy.data.images.new("train_exterior_palette", ATLAS, ATLAS, alpha=False)
    px = [0.0] * (ATLAS * ATLAS * 4)
    per = ATLAS // CELL
    for i, name in enumerate(NAMES):
        r, g, b = (c / 255.0 for c in PALETTE[name])
        cx, cy = i % per, i // per
        for y in range(cy * CELL, (cy + 1) * CELL):
            row = ATLAS - 1 - y      # Blender 픽셀은 아래 줄부터
            for x in range(cx * CELL, (cx + 1) * CELL):
                k = (row * ATLAS + x) * 4
                px[k:k + 4] = [r, g, b, 1.0]
    img.pixels = px
    img.file_format = "PNG"
    img.pack()
    return img


def material(img):
    mat = bpy.data.materials.new("train_exterior")
    mat.use_nodes = True
    nodes = mat.node_tree.nodes
    bsdf = next(n for n in nodes if n.type == "BSDF_PRINCIPLED")
    tex = nodes.new("ShaderNodeTexImage")
    tex.image = img
    tex.interpolation = "Closest"
    mat.node_tree.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
    bsdf.inputs["Roughness"].default_value = 0.9
    bsdf.inputs["Metallic"].default_value = 0.0
    return mat


def export(pid, pieces, mat, path):
    objs = []
    try:
        for lod, piece in enumerate(pieces):
            mesh = bpy.data.meshes.new("%s_LOD%d" % (pid, lod))
            piece.bm.to_mesh(mesh)
            mesh.materials.append(mat)
            obj = bpy.data.objects.new("%s_LOD%d" % (pid, lod), mesh)
            bpy.context.scene.collection.objects.link(obj)
            objs.append(obj)
        for other in bpy.context.scene.objects:
            other.select_set(other in objs)
        bpy.context.view_layer.objects.active = objs[0]
        bpy.ops.export_scene.gltf(filepath=str(path), export_format="GLB", use_selection=True,
            export_yup=True, export_apply=False, export_materials="EXPORT", export_texcoords=True,
            export_normals=True, export_tangents=False, export_vertex_color="NONE",
            export_extras=False, export_animations=False, export_image_format="AUTO")
    finally:
        for obj in objs:
            mesh = obj.data
            bpy.data.objects.remove(obj, do_unlink=True)
            bpy.data.meshes.remove(mesh)


def check_glb(path, tris):
    data = path.read_bytes()
    magic, version, length = struct.unpack_from("<4sII", data)
    chunk_length, chunk_type = struct.unpack_from("<II", data, 12)
    if (magic, version, length, chunk_type) != (b"glTF", 2, len(data), 0x4E4F534A):
        raise ValueError("GLB 머리 검사 실패")
    book = json.loads(data[20:20 + chunk_length])
    if len(book.get("meshes", [])) != 2 or len(book.get("materials", [])) != 1 or len(book.get("images", [])) != 1:
        raise ValueError("메시 둘·재질 하나·그림 하나 검사 실패")
    if any(book.get(k) for k in ("animations", "skins", "cameras")) or "KHR_lights_punctual" in book.get("extensions", {}):
        raise ValueError("불필요한 자원")
    names = sorted(n.get("name", "") for n in book["nodes"] if "mesh" in n)
    counts, lo, hi = [], [1e9] * 3, [-1e9] * 3
    for m in book["meshes"]:
        if len(m["primitives"]) != 1:
            raise ValueError("면 묶음 하나 검사 실패")
        prim = m["primitives"][0]
        counts.append(book["accessors"][prim["indices"]]["count"] // 3)
        pos = book["accessors"][prim["attributes"]["POSITION"]]
        lo = [min(lo[i], pos["min"][i]) for i in range(3)]
        hi = [max(hi[i], pos["max"][i]) for i in range(3)]
    if sorted(counts) != sorted(tris):
        raise ValueError("삼각형 수 검사 실패 %s %s" % (counts, tris))
    if abs(hi[0] - HALF_L) > 1e-4 or abs(lo[0] + HALF_L) > 1e-4 or abs(lo[1]) > 1e-4:
        raise ValueError("길이 16m·바닥 0 검사 실패 %s %s" % (lo, hi))
    return len(data), hashlib.sha256(data).hexdigest(), [round(hi[i] - lo[i], 6) for i in range(3)], names


def update_catalog(repo, rows):
    path = repo / "s2/game/world/train_model_catalog.json"
    book = json.loads(path.read_text(encoding="utf-8"))
    for r in rows:
        a = book["assets"][r["id"]]
        a.update({"status": "ready", "path": "res://models/train_exterior/%s.glb" % r["id"], "category": "exterior",
                  "lod0_tris": r["lod0"], "lod1_tris": r["lod1"], "texture_size": [ATLAS, ATLAS], "materials": 1,
                  "bytes": r["bytes"], "dimensions_m": r["dims"], "sha256": r["sha256"],
                  "source": "tools/blender/train_exterior.py"})
        if r["id"] == "coach_medic":
            # 지붕 부품(연통) 자리: 새 지붕 꼭대기
            a["attachment_sites"]["roof_clear"]["position"] = [0, PEAK_Y, 0]
    path.write_text(json.dumps(book, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--repo", required=True)
    parser.add_argument("--preview", action="store_true")
    parser.add_argument("--out", default="")
    args = parser.parse_args(sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else [])
    repo = Path(args.repo).resolve()
    out_dir = repo / "s2/models/train_exterior"
    if args.preview:
        preview(out_dir, Path(args.out) if args.out else repo / "s2/.godot/train_exterior_work")
        return
    bpy.ops.wm.read_factory_settings(use_empty=True)
    img = atlas_image()
    mat = material(img)
    rows, failures = [], []
    for pid, (build, note) in BUILDERS.items():
        pieces = [Piece(pid + "_LOD0"), Piece(pid + "_LOD1")]
        try:
            build(pieces[0], True)
            build(pieces[1], False)
            tris = [pc.fin() for pc in pieces]
            if tris[1] * 2 > tris[0]:
                raise ValueError("LOD1이 절반을 넘음 %s" % tris)
            path = out_dir / (pid + ".glb")
            export(pid, pieces, mat, path)
            size, digest, dims, names = check_glb(path, tris)
            rows.append({"id": pid, "lod0": tris[0], "lod1": tris[1], "bytes": size, "sha256": digest, "dims": dims, "note": note})
            print("TRAIN_EXT_READY %s lod0=%d lod1=%d bytes=%d dims=%s nodes=%s" % (pid, tris[0], tris[1], size, dims, names), flush=True)
        except Exception as error:
            failures.append({"id": pid, "reason": "%s: %s" % (type(error).__name__, error)})
            print("TRAIN_EXT_FAILED %s %s" % (pid, error), flush=True)
        finally:
            for pc in pieces:
                pc.bm.free()
    if failures:
        raise SystemExit(1)
    update_catalog(repo, rows)
    print("TRAIN_EXTERIOR %d ready" % len(rows), flush=True)


def preview(out_dir, dest):
    """GLB를 다시 열어 옆·지붕 위에서 본 접촉 시트를 저장소 밖에 렌더한다."""
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_WORKBENCH"
    scene.display.shading.light = "STUDIO"
    scene.display.shading.color_type = "TEXTURE"
    scene.display.shading.show_shadows = True
    scene.display.shading.show_cavity = True
    scene.display.shading.cavity_type = "BOTH"
    scene.display.shading.background_type = "WORLD"
    scene.world = bpy.data.worlds.new("bg")
    scene.world.color = (.55, .57, .6)
    scene.view_settings.view_transform = "Standard"
    for i, pid in enumerate(BUILDERS):
        before = set(bpy.data.objects)
        bpy.ops.import_scene.gltf(filepath=str(out_dir / (pid + ".glb")))
        for obj in set(bpy.data.objects) - before:
            if obj.type != "MESH":
                continue
            lod1 = obj.name.endswith("LOD1")
            obj.parent = None
            obj.location = (20.0 if lod1 else 0.0, 0, -i * 4.2)
    dest.mkdir(parents=True, exist_ok=True)
    cam_data = bpy.data.cameras.new("cam")
    cam = bpy.data.objects.new("cam", cam_data)
    scene.collection.objects.link(cam)
    cam_data.type = "ORTHO"
    scene.camera = cam
    scene.render.resolution_x = 2400
    scene.render.resolution_y = 2000
    for name, loc, ortho in (("side", (10, -40, -10.5), 38), ("roof", (-6, -30, 14), 40)):
        cam.location = loc
        cam.rotation_euler = (Vector((10, 0, -10.5)) - cam.location).to_track_quat("-Z", "Y").to_euler()
        cam_data.ortho_scale = ortho
        scene.render.filepath = str(dest / ("preview_%s.png" % name))
        bpy.ops.render.render(write_still=True)
    print("PREVIEW_READY", dest, flush=True)


if __name__ == "__main__":
    main()
