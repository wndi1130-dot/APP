"""건물 조각 키트를 블렌더에서 헤드리스로 만든다.

    blender -b --factory-startup -P tools/blender/building_kit.py -- --repo .

한 번 돌리면 세 가지를 새로 쓴다.
  s2/models/building_kit/<조각>.glb   조각 하나에 메시 하나, 재질 없음
  s2/models/building_kit/catalog.json 대응표(삼각형, 크기, 바이트, sha256, 놓는 법)
  s2/models/building_kit/README.md    장부(같은 값을 사람이 읽는 표로)
대응표와 장부를 손으로 고치지 않는다. 조각을 바꾸면 이 스크립트를 다시 돌린다.

축: 블렌더 X = 벽을 따라, Z = 위, -Y = 바깥. glTF(+Y 위)로 내보내면 Godot에서
X는 그대로, 위는 +Y, 바깥은 +Z다. 기준점은 칸 가운데 바닥(층 바닥 높이)이고,
문짝만 경첩 줄이 기준점이다.

칠: 그림을 굽지 않는다. 정점 색에 칠 구역(0~5)과 날씨 받음을 적고, 무늬와 색은
건물 셰이더가 세계 좌표로 그린다. 구역 번호 k는 R = k의 1자리, G = 2자리,
B = 4자리 비트(0 또는 1)이고, A는 날씨에 드러난 면 1, 지붕·벽 안쪽 면 0이다.
0과 1만 쓰므로 sRGB와 선형 사이를 오가거나 8비트로 줄어도 값이 그대로다.
"""

import argparse
import hashlib
import json
import math
import os
import sys

import bmesh
import bpy
from mathutils import Vector

SCRIPT_VERSION = 1

# 격자 (s2/game/world/map_view.gd LEVEL_H·CUT_H와 같다)
H = 3.0          # 층 바닥에서 윗층 바닥까지
CUT = 0.35       # 열린 층의 가로 벽 턱
TE = 0.45        # 바깥벽 두께, 칸 가운데
TI = 0.2         # 안벽 두께, 칸 가운데
YO, YI = -TE / 2.0, TE / 2.0
PL_H = 0.3       # 기단 높이(턱보다 낮게)
BAND = 2.8       # 층 띠 아래 끝(띠는 2.8~3.0)
SILL, HEAD, WIN_W = 0.9, 2.2, 0.7
GLASS_Y = -0.06  # 유리판(벽 가운데보다 조금 바깥)
FRAME = 0.05     # 창틀·창살 폭
DOOR_W, DOOR_H = 0.9, 2.1
STEP = 0.08      # 문턱·디딤돌 높이
QUOIN = 0.3      # 모서리돌 띠 폭
# 지붕: 경간 SPAN에서 만든 박공. 3번 이식은 용마루 방향(X)으로 길이만큼 늘이고,
# 경간 방향(Y)과 높이(Z)는 같은 배율(경간 / SPAN)로 줄여 경사가 그대로 남는다.
PITCH = 35.0
SPAN = 10.0
EAVE = 0.3
ROOF_T = 0.12

ZONES = {"wall": 0, "stone": 1, "wood": 2, "glass": 3, "roof": 4, "metal": 5}
ZONE_NAMES = {"wall": "벽면", "stone": "석재(기단·띠·창턱·모서리돌)", "wood": "나무",
              "glass": "유리", "roof": "지붕", "metal": "쇠붙이"}

# 첫 정차 지도 열한 채의 바깥 껍데기 수(지하 빼고). 3번 이식 전 어림에만 쓴다.
SULEHUF_COUNTS = {"wall_runs": 197, "windows": 81, "outer_doors": 18,
                  "corners": 80, "gable_roofs": 13, "chimneys": 8}
SULEHUF_BUDGET = 15000


class Piece:
    """면을 하나씩 쌓아 조각 하나를 만든다. 면마다 바깥 법선을 받아 감김을 맞춘다."""

    def __init__(self, pid):
        self.pid = pid
        self.bm = bmesh.new()
        self.col = self.bm.loops.layers.float_color.new("Col")
        self.zones = set()

    def face(self, pts, zone, exposed, normal):
        pts = [Vector(p) for p in pts]
        n = Vector((0.0, 0.0, 0.0))
        for i, a in enumerate(pts):
            b = pts[(i + 1) % len(pts)]
            n.x += (a.y - b.y) * (a.z + b.z)
            n.y += (a.z - b.z) * (a.x + b.x)
            n.z += (a.x - b.x) * (a.y + b.y)
        if n.length < 1e-9:
            raise ValueError("%s: 넓이 없는 면" % self.pid)
        want = Vector(normal).normalized()
        if n.normalized().dot(want) < 0.0:
            pts.reverse()
            n = -n
        if n.normalized().dot(want) < 0.99:
            raise ValueError("%s: 면 법선이 뜻한 쪽과 다름 %s" % (self.pid, tuple(want)))
        k = ZONES[zone]
        colour = (float(k & 1), float((k >> 1) & 1), float((k >> 2) & 1), 1.0 if exposed else 0.0)
        f = self.bm.faces.new([self.bm.verts.new(p) for p in pts])
        f.smooth = False
        for loop in f.loops:
            loop[self.col] = colour
        self.zones.add(k)

    def rect(self, axis, at, r1, r2, zone, exposed, sign):
        """축에 수직인 사각형. axis가 x면 (y, z), y면 (x, z), z면 (x, y) 범위다."""
        if r1[1] - r1[0] <= 1e-9 or r2[1] - r2[0] <= 1e-9:
            raise ValueError("%s: 빈 사각형" % self.pid)
        a0, a1 = r1
        b0, b1 = r2
        if axis == "x":
            pts = [(at, a0, b0), (at, a1, b0), (at, a1, b1), (at, a0, b1)]
            normal = (sign, 0.0, 0.0)
        elif axis == "y":
            pts = [(a0, at, b0), (a1, at, b0), (a1, at, b1), (a0, at, b1)]
            normal = (0.0, sign, 0.0)
        else:
            pts = [(a0, b0, at), (a1, b0, at), (a1, b1, at), (a0, b1, at)]
            normal = (0.0, 0.0, sign)
        self.face(pts, zone, exposed, normal)

    def box(self, x, y, z, zone, exposed, sides="xXyYzZ"):
        """상자 면 가운데 sides에 적은 쪽만 만든다(x = -X, X = +X ...)."""
        table = {"x": ("x", x[0], y, z, -1), "X": ("x", x[1], y, z, 1),
                 "y": ("y", y[0], x, z, -1), "Y": ("y", y[1], x, z, 1),
                 "z": ("z", z[0], x, y, -1), "Z": ("z", z[1], x, y, 1)}
        for s in sides:
            axis, at, r1, r2, sign = table[s]
            ex = exposed[s] if isinstance(exposed, dict) else exposed
            self.rect(axis, at, r1, r2, zone, ex, sign)

    def tris(self):
        return sum(len(f.verts) - 2 for f in self.bm.faces)

    def bounds_godot(self):
        xs = [v.co.x for v in self.bm.verts]
        ys = [v.co.y for v in self.bm.verts]
        zs = [v.co.z for v in self.bm.verts]
        lo = [min(xs), min(zs), -max(ys)]
        hi = [max(xs), max(zs), -min(ys)]
        return [[round(v, 4) + 0.0 for v in lo], [round(v, 4) + 0.0 for v in hi]]


# ---------------------------------------------------------------- 바깥벽

def ext_wall(p):
    p.rect("y", YI, (-0.5, 0.5), (0.0, H), "wall", 0, 1)
    p.rect("y", YO, (-0.5, 0.5), (0.0, BAND), "wall", 1, -1)
    p.rect("y", YO, (-0.5, 0.5), (BAND, H), "stone", 1, -1)
    p.rect("z", H, (-0.5, 0.5), (YO, YI), "wall", 0, 1)


def ext_wall_cut(p):
    p.rect("y", YI, (-0.5, 0.5), (0.0, CUT), "wall", 0, 1)
    p.rect("y", YO, (-0.5, 0.5), (0.0, CUT), "wall", 1, -1)
    p.rect("z", CUT, (-0.5, 0.5), (YO, YI), "wall", 0, 1)


def ext_plinth(p):
    # 기단 줄은 문 칸에서 끊기므로 늘림 조각이지만 끝면을 둔다
    p.box((-0.5, 0.5), (-0.5, YO), (0.0, PL_H), "stone", 1, sides="xXyZ")


def ext_plinth_corner(p):
    # 바깥 모서리: 건물은 +X+Y 쪽, 바깥은 -X와 -Y 쪽
    p.rect("y", -0.5, (-0.5, 0.5), (0.0, PL_H), "stone", 1, -1)
    p.rect("x", -0.5, (-0.5, 0.5), (0.0, PL_H), "stone", 1, -1)
    p.rect("z", PL_H, (-0.5, 0.5), (-0.5, YO), "stone", 1, 1)
    p.rect("z", PL_H, (-0.5, YO), (YO, 0.5), "stone", 1, 1)


def ext_plinth_corner_in(p):
    # 안으로 꺾인 모서리: 바깥은 -X-Y 사분면 하나
    p.rect("z", PL_H, (-0.5, YO), (-0.5, YO), "stone", 1, 1)


def ext_corner(p):
    # 바깥 모서리: 벽 팔이 +X와 +Y로 뻗고 바깥은 -X와 -Y 쪽
    xo, xi = YO, YI
    p.rect("y", YO, (xo, xo + QUOIN), (0.0, BAND), "stone", 1, -1)
    p.rect("y", YO, (xo + QUOIN, 0.5), (0.0, BAND), "wall", 1, -1)
    p.rect("y", YO, (xo, 0.5), (BAND, H), "stone", 1, -1)
    p.rect("x", xo, (YO, YO + QUOIN), (0.0, BAND), "stone", 1, -1)
    p.rect("x", xo, (YO + QUOIN, 0.5), (0.0, BAND), "wall", 1, -1)
    p.rect("x", xo, (YO, 0.5), (BAND, H), "stone", 1, -1)
    p.rect("y", YI, (xi, 0.5), (0.0, H), "wall", 0, 1)
    p.rect("x", xi, (YI, 0.5), (0.0, H), "wall", 0, 1)
    p.rect("z", H, (xo, 0.5), (YO, YI), "wall", 0, 1)
    p.rect("z", H, (xo, xi), (YI, 0.5), "wall", 0, 1)


def ext_corner_in(p):
    # 안으로 꺾인 모서리: 벽 팔이 -X와 -Y로 뻗고 바깥은 -X-Y 사분면
    xo, xi = YO, YI
    p.rect("y", YO, (-0.5, xo), (0.0, BAND), "wall", 1, -1)
    p.rect("y", YO, (-0.5, xo), (BAND, H), "stone", 1, -1)
    p.rect("x", xo, (-0.5, YO), (0.0, BAND), "wall", 1, -1)
    p.rect("x", xo, (-0.5, YO), (BAND, H), "stone", 1, -1)
    p.rect("y", YI, (-0.5, xi), (0.0, H), "wall", 0, 1)
    p.rect("x", xi, (-0.5, YI), (0.0, H), "wall", 0, 1)
    p.rect("z", H, (-0.5, xi), (YO, YI), "wall", 0, 1)
    p.rect("z", H, (xo, xi), (-0.5, YO), "wall", 0, 1)


def ext_corner_cut(p):
    # 열린 층의 턱 줄 끝 모서리(ext_corner와 같은 자리, 높이만 턱)
    xo, xi = YO, YI
    p.rect("y", YO, (xo, xo + QUOIN), (0.0, CUT), "stone", 1, -1)
    p.rect("y", YO, (xo + QUOIN, 0.5), (0.0, CUT), "wall", 1, -1)
    p.rect("x", xo, (YO, YO + QUOIN), (0.0, CUT), "stone", 1, -1)
    p.rect("x", xo, (YO + QUOIN, 0.5), (0.0, CUT), "wall", 1, -1)
    p.rect("y", YI, (xi, 0.5), (0.0, CUT), "wall", 0, 1)
    p.rect("x", xi, (YI, 0.5), (0.0, CUT), "wall", 0, 1)
    p.rect("z", CUT, (xo, 0.5), (YO, YI), "wall", 0, 1)
    p.rect("z", CUT, (xo, xi), (YI, 0.5), "wall", 0, 1)


def ext_corner_in_cut(p):
    xo, xi = YO, YI
    p.rect("y", YO, (-0.5, xo), (0.0, CUT), "wall", 1, -1)
    p.rect("x", xo, (-0.5, YO), (0.0, CUT), "wall", 1, -1)
    p.rect("y", YI, (-0.5, xi), (0.0, CUT), "wall", 0, 1)
    p.rect("x", xi, (-0.5, YI), (0.0, CUT), "wall", 0, 1)
    p.rect("z", CUT, (-0.5, xi), (YO, YI), "wall", 0, 1)
    p.rect("z", CUT, (xo, xi), (-0.5, YO), "wall", 0, 1)


def wall_end_cap(p):
    # 늘림 바깥벽은 끝면이 없다. 열린 층에서 선 줄이 턱 모서리와 만나면 그 끝을 이것으로 막는다.
    # 기준점은 줄이 끝나는 칸 경계이고 면은 -X를 본다.
    p.rect("x", 0.0, (YO, YI), (0.0, H), "wall", 0, -1)


# ---------------------------------------------------------------- 창

def ext_window(p):
    hw = WIN_W / 2.0
    # 바깥면: 창 아래, 창 위, 양옆, 층 띠
    p.rect("y", YO, (-0.5, 0.5), (0.0, SILL), "wall", 1, -1)
    p.rect("y", YO, (-0.5, 0.5), (HEAD, BAND), "wall", 1, -1)
    p.rect("y", YO, (-0.5, -hw), (SILL, HEAD), "wall", 1, -1)
    p.rect("y", YO, (hw, 0.5), (SILL, HEAD), "wall", 1, -1)
    p.rect("y", YO, (-0.5, 0.5), (BAND, H), "stone", 1, -1)
    # 안면
    p.rect("y", YI, (-0.5, 0.5), (0.0, SILL), "wall", 0, 1)
    p.rect("y", YI, (-0.5, 0.5), (HEAD, H), "wall", 0, 1)
    p.rect("y", YI, (-0.5, -hw), (SILL, HEAD), "wall", 0, 1)
    p.rect("y", YI, (hw, 0.5), (SILL, HEAD), "wall", 0, 1)
    p.rect("z", H, (-0.5, 0.5), (YO, YI), "wall", 0, 1)
    # 구멍 옆과 위, 구멍 바닥(바깥 반은 돌, 안 반은 나무 창대)
    p.rect("x", -hw, (YO, YI), (SILL, HEAD), "wall", 0, 1)
    p.rect("x", hw, (YO, YI), (SILL, HEAD), "wall", 0, -1)
    p.rect("z", HEAD, (-hw, hw), (YO, YI), "wall", 0, -1)
    p.rect("z", SILL, (-hw, hw), (YO, GLASS_Y), "stone", 1, 1)
    p.rect("z", SILL, (-hw, hw), (GLASS_Y, YI), "wood", 0, 1)
    # 바깥 창턱(벽보다 0.06 나옴): 윗면과 앞면
    p.rect("z", SILL, (-0.42, 0.42), (YO - 0.06, YO), "stone", 1, 1)
    p.rect("y", YO - 0.06, (-0.42, 0.42), (SILL - 0.06, SILL), "stone", 1, -1)
    # 창틀과 창살: 유리 바로 바깥과 바로 안. 창살은 틀보다 조금 앞에 두어 겹친 면이 싸우지 않는다.
    f = FRAME
    zt = SILL + (HEAD - SILL) * 0.65
    for side, sign, ex in (("out", -1, 1), ("in", 1, 0)):
        y_border = GLASS_Y + sign * 0.010
        y_mull = GLASS_Y + sign * 0.013
        y_tran = GLASS_Y + sign * 0.016
        p.rect("y", y_border, (-hw, -hw + f), (SILL, HEAD), "wood", ex, sign)
        p.rect("y", y_border, (hw - f, hw), (SILL, HEAD), "wood", ex, sign)
        p.rect("y", y_border, (-hw + f, hw - f), (SILL, SILL + f), "wood", ex, sign)
        p.rect("y", y_border, (-hw + f, hw - f), (HEAD - f, HEAD), "wood", ex, sign)
        p.rect("y", y_mull, (-f / 2.0, f / 2.0), (SILL + f, HEAD - f), "wood", ex, sign)
        p.rect("y", y_tran, (-hw + f, hw - f), (zt - f / 2.0, zt + f / 2.0), "wood", ex, sign)


def window_glass(p):
    hw = WIN_W / 2.0
    p.rect("y", GLASS_Y, (-hw, hw), (SILL, HEAD), "glass", 1, -1)
    p.rect("y", GLASS_Y, (-hw, hw), (SILL, HEAD), "glass", 0, 1)


def ext_window_cut(p):
    hw = WIN_W / 2.0
    p.rect("y", YI, (-0.5, 0.5), (0.0, CUT), "wall", 0, 1)
    p.rect("y", YO, (-0.5, 0.5), (0.0, CUT), "wall", 1, -1)
    # 턱 윗면의 창 자리는 나무 창대 칠로 남긴다
    p.rect("z", CUT, (-0.5, -hw), (YO, YI), "wall", 0, 1)
    p.rect("z", CUT, (-hw, hw), (YO, YI), "wood", 0, 1)
    p.rect("z", CUT, (hw, 0.5), (YO, YI), "wall", 0, 1)


def window_glass_broken(p):
    shards = [
        [(-0.30, 2.15), (-0.05, 2.15), (-0.30, 1.70)],
        [(0.30, 2.15), (0.30, 1.85), (0.12, 2.15)],
        [(-0.30, 0.95), (-0.08, 0.95), (-0.30, 1.25)],
        [(0.30, 0.95), (0.30, 1.40), (0.05, 0.95)],
    ]
    for shard in shards:
        pts = [(x, GLASS_Y, z) for x, z in shard]
        p.face(pts, "glass", 1, (0.0, -1.0, 0.0))
        p.face(pts, "glass", 0, (0.0, 1.0, 0.0))


def window_glass_floor(p):
    floor = [
        [(-0.32, 0.30), (-0.18, 0.27), (-0.24, 0.40)],
        [(-0.10, 0.36), (0.04, 0.31), (0.00, 0.46)],
        [(0.12, 0.28), (0.26, 0.33), (0.15, 0.41)],
        [(0.24, 0.42), (0.36, 0.38), (0.33, 0.48)],
        [(-0.28, 0.44), (-0.16, 0.47), (-0.22, 0.49)],
        [(0.02, 0.27), (0.10, 0.25), (0.08, 0.32)],
    ]
    for shard in floor:
        p.face([(x, y, 0.004) for x, y in shard], "glass", 0, (0.0, 0.0, 1.0))
    sill = [
        [(-0.30, YO - 0.05), (-0.18, YO - 0.04), (-0.25, YO - 0.01)],
        [(0.14, YO - 0.02), (0.27, YO - 0.05), (0.25, YO - 0.01)],
    ]
    for shard in sill:
        p.face([(x, y, SILL + 0.004) for x, y in shard], "glass", 1, (0.0, 0.0, 1.0))


def window_boards(p):
    # 판자 한 장. 놓을 높이와 기울기는 대응표 board_slots.window
    p.box((-0.48, 0.48), (YO - 0.04, YO - 0.01), (-0.09, 0.09), "wood",
          {"y": 1, "Y": 0, "z": 1, "Z": 1}, sides="yYzZ")


# ---------------------------------------------------------------- 문

def ext_door(p):
    hd = DOOR_W / 2.0
    lintel = DOOR_H + 0.15
    p.rect("y", YO, (-0.5, -hd), (0.0, DOOR_H), "wall", 1, -1)
    p.rect("y", YO, (hd, 0.5), (0.0, DOOR_H), "wall", 1, -1)
    p.rect("y", YO, (-0.5, 0.5), (DOOR_H, lintel), "wood", 1, -1)
    p.rect("y", YO, (-0.5, 0.5), (lintel, BAND), "wall", 1, -1)
    p.rect("y", YO, (-0.5, 0.5), (BAND, H), "stone", 1, -1)
    p.rect("y", YI, (-0.5, -hd), (0.0, DOOR_H), "wall", 0, 1)
    p.rect("y", YI, (hd, 0.5), (0.0, DOOR_H), "wall", 0, 1)
    p.rect("y", YI, (-0.5, 0.5), (DOOR_H, H), "wall", 0, 1)
    p.rect("z", H, (-0.5, 0.5), (YO, YI), "wall", 0, 1)
    p.rect("x", -hd, (YO, YI), (STEP, DOOR_H), "wall", 0, 1)
    p.rect("x", hd, (YO, YI), (STEP, DOOR_H), "wall", 0, -1)
    p.rect("z", DOOR_H, (-hd, hd), (YO, YI), "wall", 0, -1)
    # 바깥 디딤돌(1층 바깥 문만)과 문턱
    p.rect("z", STEP, (-0.5, 0.5), (-0.5, YO), "stone", 1, 1)
    p.rect("y", -0.5, (-0.5, 0.5), (0.0, STEP), "stone", 1, -1)
    p.rect("z", STEP, (-hd, hd), (YO, YI), "stone", 0, 1)
    p.rect("y", YI, (-hd, hd), (0.0, STEP), "stone", 0, 1)


def door_leaf(p):
    # 경첩 줄이 기준점이고 문짝은 +X로 0.9. 닫힌 자리는 대응표 hinge_m
    p.box((0.0, DOOR_W), (-0.025, 0.025), (STEP, DOOR_H - 0.02), "wood", 0, sides="xXyYZ")
    p.box((0.76, 0.82), (-0.07, 0.07), (1.0, 1.06), "metal", 0)


def door_leaf_broken(p):
    # 경첩에 남은 아래 조각과 안쪽 바닥에 떨어진 판
    outline = [(0.0, STEP), (0.55, STEP), (0.35, 1.15), (0.0, 1.6)]
    front = [(x, -0.025, z) for x, z in outline]
    back = [(x, 0.025, z) for x, z in outline]
    p.face(front, "wood", 0, (0.0, -1.0, 0.0))
    p.face(back, "wood", 0, (0.0, 1.0, 0.0))
    centre = Vector((sum(x for x, _ in outline) / 4.0, 0.0, sum(z for _, z in outline) / 4.0))
    # 바닥에 닿은 아랫변은 두지 않는다
    for a, b in ((outline[1], outline[2]), (outline[2], outline[3]), (outline[3], outline[0])):
        quad = [(a[0], -0.025, a[1]), (b[0], -0.025, b[1]), (b[0], 0.025, b[1]), (a[0], 0.025, a[1])]
        edge = Vector((b[0] - a[0], 0.0, b[1] - a[1]))
        normal = Vector((edge.z, 0.0, -edge.x))
        if normal.dot(Vector(((a[0] + b[0]) / 2.0, 0.0, (a[1] + b[1]) / 2.0)) - centre) < 0.0:
            normal = -normal
        p.face(quad, "wood", 0, normal)
    # 바닥의 판: 문턱 쪽 끝이 들린 채 눕는다
    x0, x1 = 0.08, 0.86
    y0, y1 = 0.24, 0.5
    z0, z1 = 0.10, 0.02
    t = 0.04
    p.face([(x0, y0, z0 + t), (x1, y0, z0 + t), (x1, y1, z1 + t), (x0, y1, z1 + t)], "wood", 0,
           (0.0, (z0 - z1) / (y1 - y0), 1.0))
    p.face([(x0, y0, z0), (x0, y1, z1), (x0, y1, z1 + t), (x0, y0, z0 + t)], "wood", 0, (-1.0, 0.0, 0.0))
    p.face([(x1, y0, z0), (x1, y1, z1), (x1, y1, z1 + t), (x1, y0, z0 + t)], "wood", 0, (1.0, 0.0, 0.0))
    p.face([(x0, y0, z0), (x1, y0, z0), (x1, y0, z0 + t), (x0, y0, z0 + t)], "wood", 0, (0.0, -1.0, 0.0))
    p.face([(x0, y1, z1), (x1, y1, z1), (x1, y1, z1 + t), (x0, y1, z1 + t)], "wood", 0, (0.0, 1.0, 0.0))


def door_boards(p):
    # 판자 한 장. 놓을 높이와 기울기는 대응표 board_slots.door
    p.box((-0.5, 0.5), (YO - 0.035, YO - 0.005), (-0.08, 0.08), "wood",
          {"y": 1, "Y": 0, "z": 1, "Z": 1}, sides="yYzZ")


# ---------------------------------------------------------------- 안벽과 잘린 문

def int_wall(p):
    t = TI / 2.0
    p.box((-0.5, 0.5), (-t, t), (0.0, H), "wall", 0, sides="xXyYZ")


def int_wall_cut(p):
    t = TI / 2.0
    p.box((-0.5, 0.5), (-t, t), (0.0, CUT), "wall", 0, sides="xXyYZ")


def int_door(p):
    hd = DOOR_W / 2.0
    t = TI / 2.0
    lintel = DOOR_H + 0.12
    for y, sign in ((-t, -1), (t, 1)):
        p.rect("y", y, (-0.5, -hd), (0.0, DOOR_H), "wood", 0, sign)
        p.rect("y", y, (hd, 0.5), (0.0, DOOR_H), "wood", 0, sign)
        p.rect("y", y, (-0.5, 0.5), (DOOR_H, lintel), "wood", 0, sign)
        p.rect("y", y, (-0.5, 0.5), (lintel, H), "wall", 0, sign)
    p.rect("x", -hd, (-t, t), (0.0, DOOR_H), "wood", 0, 1)
    p.rect("x", hd, (-t, t), (0.0, DOOR_H), "wood", 0, -1)
    p.rect("z", DOOR_H, (-hd, hd), (-t, t), "wall", 0, -1)
    p.rect("z", H, (-0.5, 0.5), (-t, t), "wall", 0, 1)


def door_frame_cut(p):
    # 열린 층의 턱 줄에 든 문 칸(바깥·안 공용, 바깥벽 두께)
    hd = DOOR_W / 2.0
    p.rect("z", 0.04, (-hd, hd), (YO, YI), "stone", 0, 1)
    p.box((-0.5, -hd), (YO, YI), (0.0, CUT), "wood", 0, sides="XyYZ")
    p.box((hd, 0.5), (YO, YI), (0.0, CUT), "wood", 0, sides="xyYZ")


def door_leaf_cut(p):
    p.box((0.0, DOOR_W), (-0.025, 0.025), (STEP, CUT), "wood", 0, sides="xXyYZ")


# ---------------------------------------------------------------- 지붕과 굴뚝

def roof_rise():
    return SPAN / 2.0 * math.tan(math.radians(PITCH))


def roof_gable(p):
    s = SPAN / 2.0
    tan_p = math.tan(math.radians(PITCH))
    sin_p, cos_p = math.sin(math.radians(PITCH)), math.cos(math.radians(PITCH))
    r = roof_rise()
    tv = ROOF_T / cos_p
    ye = s + EAVE
    ze = r - ye * tan_p
    for sy in (-1.0, 1.0):
        # sy = -1이 남쪽(바깥, Godot +Z) 경사
        p.face([(-0.5, 0.0, r), (0.5, 0.0, r), (0.5, sy * ye, ze), (-0.5, sy * ye, ze)],
               "roof", 1, (0.0, sy * sin_p, cos_p))
        p.face([(-0.5, 0.0, r - tv), (0.5, 0.0, r - tv), (0.5, sy * ye, ze - tv), (-0.5, sy * ye, ze - tv)],
               "wood", 0, (0.0, -sy * sin_p, -cos_p))
        p.rect("y", sy * ye, (-0.5, 0.5), (ze - tv, ze), "wood", 1, sy)
        for sx in (-0.5, 0.5):
            p.face([(sx, 0.0, r), (sx, sy * ye, ze), (sx, sy * ye, ze - tv), (sx, 0.0, r - tv)],
                   "wood", 1, (1.0 if sx > 0 else -1.0, 0.0, 0.0))
    # 용마루 덮개(함석)
    w, lift, top = 0.15, 0.015, 0.05
    zw = r - w * tan_p + lift
    for sy in (-1.0, 1.0):
        rise = Vector((0.0, -sy * w, (r + top) - zw))
        normal = Vector((0.0, sy * rise.z, w))
        p.face([(-0.5, sy * w, zw), (0.5, sy * w, zw), (0.5, 0.0, r + top), (-0.5, 0.0, r + top)],
               "metal", 1, normal)
    for sx in (-0.5, 0.5):
        p.face([(sx, -w, zw), (sx, w, zw), (sx, 0.0, r + top)], "metal", 1, (1.0 if sx > 0 else -1.0, 0.0, 0.0))


def roof_gable_end(p):
    # 박공 끝 삼각 벽. 지붕과 같은 배율로 X와 Z를 함께 줄인다.
    tan_p = math.tan(math.radians(PITCH))
    tv = ROOF_T / math.cos(math.radians(PITCH))
    half = SPAN / 2.0 - tv / tan_p
    apex = roof_rise() - tv
    tri = [(-half, 0.0), (half, 0.0), (0.0, apex)]
    p.face([(x, YO, z) for x, z in tri], "wall", 1, (0.0, -1.0, 0.0))
    p.face([(x, YI, z) for x, z in tri], "wall", 0, (0.0, 1.0, 0.0))
    # 다락 환기창(결정 476: 대각뷰에서 박공 면이 빈 삼각형으로 읽혔다). 나무 틀과 널 넷,
    # 그 뒤는 어둠(유리 구역). 박공과 같은 배율로 줄어 작은 집은 작은 창이 된다.
    w, h, f = 0.9, 0.6, 0.06
    c = apex * 0.55
    lo, hi = c - h / 2.0, c + h / 2.0
    p.rect("y", YO - 0.002, (-w / 2.0, w / 2.0), (lo, hi), "glass", 1, -1)
    for x0, x1 in ((-w / 2.0 - f, -w / 2.0), (w / 2.0, w / 2.0 + f)):
        p.box((x0, x1), (YO - 0.05, YO), (lo, hi + f), "wood", 1, sides="yxXZ")
    p.box((-w / 2.0, w / 2.0), (YO - 0.05, YO), (hi, hi + f), "wood", 1, sides="yzZ")
    p.box((-w / 2.0 - f - 0.03, w / 2.0 + f + 0.03), (YO - 0.07, YO), (lo - f, lo), "wood", 1, sides="yxXzZ")
    for i in range(4):
        z = lo + (i + 0.5) * h / 4.0
        p.box((-w / 2.0, w / 2.0), (YO - 0.035, YO - 0.004), (z - 0.03, z + 0.03), "wood", 1, sides="yzZ")


def roof_flat(p):
    p.rect("z", 0.0, (-0.5, 0.5), (-0.5, 0.5), "roof", 1, 1)


def roof_parapet(p):
    p.rect("y", YO, (-0.5, 0.5), (0.0, 0.5), "wall", 1, -1)
    p.rect("y", YI, (-0.5, 0.5), (0.0, 0.5), "wall", 1, 1)
    p.rect("z", 0.5, (-0.5, 0.5), (YO, YI), "stone", 1, 1)


def chimney(p):
    # 몸통(밑은 지붕 속에 묻힘)과 덮개돌. 위는 막혀 있다.
    p.box((-0.3, 0.3), (-0.3, 0.3), (0.0, 1.9), "wall", 1, sides="xXyY")
    p.box((-0.36, 0.36), (-0.36, 0.36), (1.9, 2.05), "stone", 1, sides="xXyYzZ")


# ---------------------------------------------------------------- 계단과 사다리

def stair_steep(p):
    # 한 칸 안에서 3 m를 오르는 가파른 나무 계단. 발판은 +Y 쪽, 위층으로 나가는 쪽은 -Y.
    run = 0.72
    depth = 0.18
    y_front0, y_back0 = 0.45 - depth, 0.45

    def front(z):
        return y_front0 - z * run / H

    def back(z):
        return y_back0 - z * run / H

    for x_out, x_in, sign in ((-0.42, -0.38, -1.0), (0.42, 0.38, 1.0)):
        outline = [(back(0.0), 0.0), (front(0.0), 0.0), (front(H), H), (back(H), H)]
        p.face([(x_out, y, z) for y, z in outline], "wood", 0, (sign, 0.0, 0.0))
        p.face([(x_in, y, z) for y, z in outline], "wood", 0, (-sign, 0.0, 0.0))
        # 앞 줄(작은 Y)은 계단 밑을, 뒤 줄은 디딤 쪽(위)을 본다
        for line, up in ((front, False), (back, True)):
            ya, za, yb, zb = line(0.0), 0.0, line(H), H
            quad = [(x_out, ya, za), (x_out, yb, zb), (x_in, yb, zb), (x_in, ya, za)]
            edge = Vector((0.0, yb - ya, zb - za))
            normal = Vector((0.0, edge.z, -edge.y)) if up else Vector((0.0, -edge.z, edge.y))
            p.face(quad, "wood", 0, normal)
    steps = 11
    for i in range(1, steps + 1):
        z = H * i / (steps + 1)
        p.box((-0.38, 0.38), (front(z), back(z)), (z - 0.035, z), "wood", 0, sides="yYzZ")


def stair_well(p):
    # 위층 계단 구멍 둘레 난간: 양옆(±X)과 계단 발치 위(+Y). 위층으로 나가는 -Y는 비워 둔다.
    rail_lo, rail_hi = 0.86, 0.92
    for sx in (-1.0, 1.0):
        x0, x1 = sorted((sx * 0.43, sx * 0.48))
        p.box((x0, x1), (-0.48, 0.48), (rail_lo, rail_hi), "wood", 0, sides="xXzZ")
    p.box((-0.43, 0.43), (0.43, 0.48), (rail_lo, rail_hi), "wood", 0, sides="yYzZ")
    for px in (-0.455, 0.455):
        for py in (-0.455, 0.455):
            p.box((px - 0.03, px + 0.03), (py - 0.03, py + 0.03), (0.0, rail_lo), "wood", 0, sides="xXyY")


def ladder(p):
    # 칸 +Y 쪽에 선 사다리. 위층 바닥 위로 0.9 m 솟아 잡을 곳이 있다.
    top = H + 0.9
    y0, y1 = 0.27, 0.32
    for x in (-0.2, 0.2):
        p.box((x - 0.025, x + 0.025), (y0, y1), (0.0, top), "wood", 0, sides="xXyY")
    for i in range(1, 10):
        z = 0.33 * i
        yc = (y0 + y1) / 2.0
        a = (yc - 0.02, z - 0.012)
        b = (yc + 0.02, z - 0.012)
        c = (yc, z + 0.018)
        for (ya, za), (yb, zb) in ((a, b), (b, c), (c, a)):
            quad = [(-0.175, ya, za), (0.175, ya, za), (0.175, yb, zb), (-0.175, yb, zb)]
            edge = Vector((0.0, yb - ya, zb - za))
            normal = Vector((0.0, edge.z, -edge.y))
            mid = Vector((0.0, (ya + yb) / 2.0 - yc, (za + zb) / 2.0 - z))
            if normal.dot(mid) < 0.0:
                normal = -normal
            p.face(quad, "wood", 0, normal)


# ---------------------------------------------------------------- 조각 목록

# id: (만드는 함수, 갈래, 늘림, 기준점, 높이 규칙, 칸 안, 삼각형 상한, 쓰임)
#   늘림: none = 그대로, x = 줄 길이만큼 X로, xy = X와 Y로, span = X는 길이, Y·Z는 경간 배율,
#         span_xz = X·Z를 경간 배율로(박공 끝)
#   높이 규칙: full = 바닥에서 LEVEL_H, cut = 바닥에서 CUT_H, free = 따로 없음
PIECES = [
    ("ext_wall", ext_wall, "wall", "x", "cell_floor", "full", True, 14, "곧은 바깥벽 1 m, 맨 위 0.2 m 층 띠"),
    ("ext_wall_cut", ext_wall_cut, "wall", "x", "cell_floor", "cut", True, 8, "열린 층의 바깥 턱"),
    ("ext_plinth", ext_plinth, "plinth", "x", "cell_floor", "free", True, 8, "1층 바깥벽 밖 기단(문 칸에서 끊김)"),
    ("ext_plinth_corner", ext_plinth_corner, "plinth", "none", "cell_floor", "free", True, 8, "1층 바깥 모서리 기단"),
    ("ext_plinth_corner_in", ext_plinth_corner_in, "plinth", "none", "cell_floor", "free", True, 4, "1층 안으로 꺾인 모서리 기단"),
    ("ext_corner", ext_corner, "wall", "none", "cell_floor", "full", True, 20, "바깥 모서리와 모서리돌"),
    ("ext_corner_in", ext_corner_in, "wall", "none", "cell_floor", "full", True, 16, "안으로 꺾인 모서리(ㄱ자 건물)"),
    ("ext_corner_cut", ext_corner_cut, "wall", "none", "cell_floor", "cut", True, 20, "열린 층 턱 줄 끝의 바깥 모서리"),
    ("ext_corner_in_cut", ext_corner_in_cut, "wall", "none", "cell_floor", "cut", True, 16, "열린 층 턱 줄의 안으로 꺾인 모서리"),
    ("wall_end_cap", wall_end_cap, "wall", "none", "run_end", "full", True, 4, "선 바깥벽 줄이 턱과 만나는 끝 마구리"),
    ("ext_window", ext_window, "opening", "none", "cell_floor", "full", True, 64, "창 벽: 구멍, 창턱, 창틀, 창살(유리 빼고)"),
    ("ext_window_cut", ext_window_cut, "opening", "none", "cell_floor", "cut", True, 16, "열린 층 턱에 든 창 칸"),
    ("window_glass", window_glass, "state", "none", "cell_floor", "free", True, 4, "성한 유리"),
    ("window_glass_broken", window_glass_broken, "state", "none", "cell_floor", "free", True, 24, "틀에 남은 깨진 유리"),
    ("window_glass_floor", window_glass_floor, "state", "none", "cell_floor", "free", True, 12, "바닥과 창턱의 유리 조각"),
    ("window_boards", window_boards, "state", "none", "slot", "free", True, 12, "창 판자 한 장"),
    ("ext_door", ext_door, "opening", "none", "cell_floor", "full", True, 40, "바깥 문 벽: 구멍, 인방, 문턱, 디딤돌"),
    ("door_leaf", door_leaf, "state", "none", "hinge", "free", False, 24, "문짝과 손잡이"),
    ("door_leaf_broken", door_leaf_broken, "state", "none", "hinge", "free", False, 20, "부서진 문짝"),
    ("door_boards", door_boards, "state", "none", "slot", "free", True, 12, "문 판자 한 장"),
    ("int_wall", int_wall, "wall", "x", "cell_floor", "full", True, 10, "안벽 0.2 m"),
    ("int_wall_cut", int_wall_cut, "wall", "x", "cell_floor", "cut", True, 10, "안벽 턱"),
    ("int_door", int_door, "opening", "none", "cell_floor", "full", True, 30, "안문 틀"),
    ("door_frame_cut", door_frame_cut, "opening", "none", "cell_floor", "cut", True, 18, "턱 줄에 든 문 칸"),
    ("door_leaf_cut", door_leaf_cut, "state", "none", "hinge", "free", False, 12, "턱 높이 문짝"),
    ("roof_gable", roof_gable, "roof", "span", "wall_top", "free", False, 28, "박공지붕(경사 둘, 처마, 용마루 덮개)"),
    ("roof_gable_end", roof_gable_end, "roof", "span_xz", "wall_top", "free", False, 80, "박공 끝 삼각 벽과 다락 환기창"),
    ("roof_flat", roof_flat, "roof", "xy", "wall_top", "free", True, 4, "평지붕 면"),
    ("roof_parapet", roof_parapet, "roof", "x", "wall_top", "free", True, 8, "평지붕 둘레 낮은 벽"),
    ("chimney", chimney, "roof", "none", "roof_base", "free", True, 40, "굴뚝 몸통과 덮개돌"),
    ("stair_steep", stair_steep, "stair", "none", "cell_floor", "full", True, 160, "가파른 나무 계단(한 칸, 3 m)"),
    ("stair_well", stair_well, "stair", "none", "cell_floor", "free", True, 60, "위층 계단 구멍 난간"),
    ("ladder", ladder, "stair", "none", "cell_floor", "free", True, 72, "사다리(위층 위로 0.9 m)"),
]

STRETCH_NAMES = {"none": "그대로", "x": "X로 줄 길이", "xy": "X·Y로", "span": "X 길이, Y·Z 경간 배율",
                 "span_xz": "X·Z 경간 배율"}
ORIGIN_NAMES = {"cell_floor": "칸 가운데 바닥", "hinge": "경첩 줄 바닥", "slot": "판자 가운데",
                "run_end": "줄 끝 칸 경계 바닥",
                "wall_top": "벽 꼭대기 가운데", "roof_base": "굴뚝 밑 가운데"}


def export(piece, path):
    me = bpy.data.meshes.new(piece.pid)
    piece.bm.to_mesh(me)
    attr = me.color_attributes["Col"]
    me.color_attributes.active_color = attr
    me.color_attributes.render_color_index = list(me.color_attributes).index(attr)
    obj = bpy.data.objects.new(piece.pid, me)
    bpy.context.scene.collection.objects.link(obj)
    for o in bpy.context.scene.objects:
        o.select_set(o == obj)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.export_scene.gltf(
        filepath=path, export_format="GLB", use_selection=True, export_yup=True,
        export_apply=False, export_materials="NONE", export_texcoords=False,
        export_normals=True, export_tangents=False, export_vertex_color="ACTIVE",
        export_extras=False, export_animations=False)
    bpy.data.objects.remove(obj)
    bpy.data.meshes.remove(me)


def sha256(path):
    with open(path, "rb") as f:
        return hashlib.sha256(f.read()).hexdigest()


def write_readme(path, book, rows):
    lines = []
    w = lines.append
    w("# 건물 조각 키트")
    w("")
    w("`tools/blender/building_kit.py`(판 %d)가 블렌더 %s 헤드리스로 만든다. 이 파일과 "
      "`catalog.json`은 스크립트가 새로 쓰니 손으로 고치지 않는다." % (SCRIPT_VERSION, book["blender"]))
    w("")
    w("```")
    w("blender -b --factory-startup -P tools/blender/building_kit.py -- --repo .")
    w("```")
    w("")
    w("## 약속")
    w("")
    w("- 칸 1 m, 층 %.1f m, 턱 %.2f m(`map_view.gd`의 `LEVEL_H`·`CUT_H`). 바깥벽 %.2f m, 안벽 %.1f m, "
      "모두 칸 가운데." % (H, CUT, TE, TI))
    w("- Godot 축으로 X는 벽을 따라, +Y는 위, +Z는 바깥이다. 90° 단위로 돌려 놓는다.")
    w("- 늘림 조각은 X 끝면이 없다(이웃 조각이 덮는다). 안벽과 기단만 끝면이 있다(홀로 끝나거나 문 칸에서 끊긴다).")
    w("- 기단은 1층에만 놓는 따로 조각이다. 위층 바깥벽은 바닥까지 벽면이다.")
    w("- 열린 층에서는 가로 줄(북쪽 바깥 줄 빼고)을 턱 조각으로 바꾼다. 턱 줄 끝 모서리는 `ext_corner_cut`이고, "
      "그 모서리와 만나는 선 줄의 끝은 `wall_end_cap`으로 막는다.")
    w("- 유리, 문짝, 판자는 상태가 바뀌니 낱 노드로 놓는다. 나머지는 건물 × 층 × 무리마다 한 메시로 굽는다.")
    w("- 박공지붕은 경간 %.0f m로 만들었다. X는 지붕 길이만큼 늘이고, Y와 Z는 같은 배율"
      "(경간 ÷ %.0f)로 바꾸면 경사 %.0f°가 그대로다. 처마 내밈(%.1f m)과 지붕 두께도 같은 배율로 바뀐다. "
      "박공 끝 벽은 X와 Z를 같은 배율로 바꾼다." % (SPAN, SPAN, PITCH, EAVE))
    w("- 그림자는 바깥 무리와 지붕만 드리운다(3번 이식).")
    w("")
    w("## 칠 구역")
    w("")
    w("정점 색 R·G·B가 구역 번호의 비트(0 또는 1)이고 A가 날씨 받음(바깥에 드러난 면 1, 안쪽 0)이다. "
      "무늬와 색은 건물 셰이더가 세계 좌표로 그린다.")
    w("")
    w("| 번호 | 구역 | R G B |")
    w("|---|---|---|")
    for name, k in ZONES.items():
        w("| %d | %s | %d %d %d |" % (k, ZONE_NAMES[name], k & 1, (k >> 1) & 1, (k >> 2) & 1))
    w("")
    w("## 조각 %d개" % len(rows))
    w("")
    w("| 조각 | 쓰임 | 삼각형 / 상한 | 늘림 | 기준점 | 크기 X × Y × Z (m) |")
    w("|---|---|---|---|---|---|")
    for r in rows:
        d = r["dimensions_m"]
        w("| `%s` | %s | %d / %d | %s | %s | %.2f × %.2f × %.2f |" % (
            r["id"], r["use"], r["lod0_tris"], r["triangle_limit"], STRETCH_NAMES[r["stretch"]],
            ORIGIN_NAMES[r["origin"]], d[0], d[1], d[2]))
    w("")
    w("## 판자 자리")
    w("")
    w("판자 조각 하나를 장수만큼 놓는다. 높이(m)와 바깥 축(+Z) 둘레 기울기(°):")
    w("")
    for kind in ("window", "door"):
        slots = book["board_slots"][kind]
        w("- %s: %s" % ("창" if kind == "window" else "문",
                        ", ".join("%.2f m · %+d°" % (s["height_m"], s["roll_deg"]) for s in slots)))
    w("")
    est = book["sulehuf_estimate"]
    w("## 첫 정차 열한 채 어림")
    w("")
    w("바깥 껍데기만 센 어림이다(지하 빼고, 기단은 3번 이식 때 잰다). 셈: 벽 줄 %d, 창 %d, 바깥 문 %d, "
      "모서리 %d, 박공지붕 %d(끝 벽 둘씩), 굴뚝 %d." % (
          SULEHUF_COUNTS["wall_runs"], SULEHUF_COUNTS["windows"], SULEHUF_COUNTS["outer_doors"],
          SULEHUF_COUNTS["corners"], SULEHUF_COUNTS["gable_roofs"], SULEHUF_COUNTS["chimneys"]))
    w("")
    w("| 몫 | 삼각형 |")
    w("|---|---|")
    for name, value in est["parts"].items():
        w("| %s | %s |" % (name, format(value, ",")))
    w("| **합** | **%s** (예산 %s) |" % (format(est["total"], ","), format(SULEHUF_BUDGET, ",")))
    w("")
    with open(path, "w", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(lines))


def estimate(by_id):
    c = SULEHUF_COUNTS
    t = {k: v["lod0_tris"] for k, v in by_id.items()}
    parts = {
        "곧은 바깥벽": c["wall_runs"] * t["ext_wall"],
        "창(벽과 유리)": c["windows"] * (t["ext_window"] + t["window_glass"]),
        "바깥 문(벽과 문짝)": c["outer_doors"] * (t["ext_door"] + t["door_leaf"]),
        "모서리": c["corners"] * t["ext_corner"],
        "박공지붕": c["gable_roofs"] * (t["roof_gable"] + 2 * t["roof_gable_end"]),
        "굴뚝": c["chimneys"] * t["chimney"],
    }
    return {"parts": parts, "total": sum(parts.values())}


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    ap = argparse.ArgumentParser()
    ap.add_argument("--repo", required=True)
    args = ap.parse_args(argv)
    out_dir = os.path.join(os.path.abspath(args.repo), "s2", "models", "building_kit")
    os.makedirs(out_dir, exist_ok=True)
    bpy.ops.wm.read_factory_settings(use_empty=True)
    rows = []
    by_id = {}
    for pid, build, category, stretch, origin, height, fits, limit, use in PIECES:
        piece = Piece(pid)
        build(piece)
        tris = piece.tris()
        if tris > limit or limit > 300:
            raise SystemExit("%s: 삼각형 %d가 상한 %d를 넘음" % (pid, tris, limit))
        bounds = piece.bounds_godot()
        zones = sorted(piece.zones)
        path = os.path.join(out_dir, pid + ".glb")
        export(piece, path)
        row = {
            "id": pid, "status": "ready", "path": "res://models/building_kit/%s.glb" % pid,
            "category": category, "use": use, "stretch": stretch, "origin": origin, "height": height,
            "fits_cell": fits, "lod0_tris": tris, "triangle_limit": limit,
            "dimensions_m": [round(bounds[1][i] - bounds[0][i], 4) for i in range(3)],
            "bounds_m": bounds, "zones": zones,
            "bytes": os.path.getsize(path), "sha256": sha256(path),
        }
        rows.append(row)
        by_id[pid] = row
    book = {
        "version": 1,
        "script_version": SCRIPT_VERSION,
        "blender": bpy.app.version_string,
        "mode_setting": "visuals/building_models_enabled",
        "grid": {"cell_m": 1.0, "level_m": H, "cut_m": CUT, "ext_wall_m": TE, "int_wall_m": TI,
                 "plinth_m": PL_H, "band_m": [BAND, H], "sill_m": SILL, "head_m": HEAD,
                 "window_w_m": WIN_W, "door_m": [DOOR_W, DOOR_H]},
        "roof": {"pitch_deg": PITCH, "nominal_span_m": SPAN, "eave_m": EAVE, "thickness_m": ROOF_T,
                 "rise_m": round(roof_rise(), 4)},
        "zones": ZONES,
        "colour_encoding": "r = 1자리, g = 2자리, b = 4자리 비트, a = 날씨 받음",
        "hinge_m": [-DOOR_W / 2.0, 0.0, 0.0],
        "board_slots": {
            "window": [{"height_m": 1.95, "roll_deg": 4}, {"height_m": 1.55, "roll_deg": -3},
                       {"height_m": 1.15, "roll_deg": 2}],
            "door": [{"height_m": 1.70, "roll_deg": 28}, {"height_m": 1.05, "roll_deg": -24},
                     {"height_m": 0.45, "roll_deg": 26}],
        },
        "assets": {r["id"]: {k: v for k, v in r.items() if k != "id"} for r in rows},
    }
    book["sulehuf_estimate"] = estimate(by_id)
    if book["sulehuf_estimate"]["total"] > SULEHUF_BUDGET:
        raise SystemExit("첫 정차 어림 %d가 예산 %d를 넘음" % (book["sulehuf_estimate"]["total"], SULEHUF_BUDGET))
    with open(os.path.join(out_dir, "catalog.json"), "w", encoding="utf-8", newline="\n") as f:
        json.dump(book, f, ensure_ascii=False, indent=2)
        f.write("\n")
    write_readme(os.path.join(out_dir, "README.md"), book, rows)
    print("BUILDING_KIT " + json.dumps({"pieces": len(rows), "estimate": book["sulehuf_estimate"]["total"],
                                        "tris": {r["id"]: r["lod0_tris"] for r in rows}}, ensure_ascii=False))


main()
