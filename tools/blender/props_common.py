"""공용 소품을 블렌더 헤드리스로 만든다.

    blender -b --factory-startup -P tools/blender/props_common.py -- --repo .

종류마다 GLB 하나, 메시 하나, 면 묶음 하나다. 그림·재질·셰이더·LOD는 없다.
블렌더 X는 가로, Z는 위, -Y는 앞이다. glTF에서는 +Y가 위, +Z가 앞이다.
기준점은 발자국 가운데 바닥이다. catalog.json과 README.md는 자동 장부다.
"""

import sys

sys.dont_write_bytecode = True

import argparse
import hashlib
import json
import math
import os
import struct

import bmesh
import bpy
from mathutils import Vector

SCRIPT_VERSION = 1
TRIANGLE_LIMIT = 600
# 선형 RGBA. 색 자체를 내보내므로 건물 키트의 구역 비트 셰이더가 필요 없다.
PALETTE = {
    "wood": (0.24, 0.17, 0.11, 1.0),
    "worn_wood": (0.38, 0.29, 0.19, 1.0),
    "iron": (0.12, 0.15, 0.17, 1.0),
    "worn_metal": (0.28, 0.32, 0.33, 1.0),
    "cloth": (0.43, 0.41, 0.31, 1.0),
    "enamel": (0.68, 0.70, 0.66, 1.0),
}
SKIPPED = {
    "wardrobe": "props_stop01/wardrobe.glb 기존 소품 사용",
    "workbench": "props_stop01/workbench.glb 기존 소품 사용",
}


class Piece:
    """건물 키트처럼 한 BMesh에 면과 Col 정점색을 모은다."""

    def __init__(self, pid):
        self.pid = pid
        self.bm = bmesh.new()
        self.col = self.bm.loops.layers.float_color.new("Col")
        self.colours = set()

    def face(self, pts, colour, outward):
        pts = [Vector(p) for p in pts]
        normal = Vector((0.0, 0.0, 0.0))
        for i, a in enumerate(pts):
            b = pts[(i + 1) % len(pts)]
            normal.x += (a.y - b.y) * (a.z + b.z)
            normal.y += (a.z - b.z) * (a.x + b.x)
            normal.z += (a.x - b.x) * (a.y + b.y)
        if normal.length < 1e-9:
            raise ValueError("넓이 없는 면: " + self.pid)
        if normal.dot(Vector(outward)) < 0.0:
            pts.reverse()
        face = self.bm.faces.new([self.bm.verts.new(p) for p in pts])
        face.smooth = False
        for loop in face.loops:
            loop[self.col] = PALETTE[colour]
        self.colours.add(colour)

    def box(self, x, y, z, colour):
        x0, x1 = x
        y0, y1 = y
        z0, z1 = z
        if min(x1 - x0, y1 - y0, z1 - z0) <= 0:
            raise ValueError("빈 상자: " + self.pid)
        for at, sign in ((x0, -1), (x1, 1)):
            self.face([(at, y0, z0), (at, y1, z0), (at, y1, z1), (at, y0, z1)], colour, (sign, 0, 0))
        for at, sign in ((y0, -1), (y1, 1)):
            self.face([(x0, at, z0), (x1, at, z0), (x1, at, z1), (x0, at, z1)], colour, (0, sign, 0))
        for at, sign in ((z0, -1), (z1, 1)):
            self.face([(x0, y0, at), (x1, y0, at), (x1, y1, at), (x0, y1, at)], colour, (0, 0, sign))

    def beam(self, start, end, radius, colour, sides=8, tip=None):
        """임의 방향의 각기둥/원뿔대. 양 끝도 막는다."""
        a, b = Vector(start), Vector(end)
        axis = (b - a).normalized()
        guide = Vector((1, 0, 0)) if abs(axis.z) > 0.9 else Vector((0, 0, 1))
        u = axis.cross(guide).normalized()
        v = axis.cross(u).normalized()
        radial = [u * math.cos(i * math.tau / sides) + v * math.sin(i * math.tau / sides)
                  for i in range(sides)]
        tip = radius if tip is None else tip
        lower = [a + d * radius for d in radial]
        upper = [b + d * tip for d in radial]
        self.face(lower, colour, -axis)
        self.face(upper, colour, axis)
        for i in range(sides):
            j = (i + 1) % sides
            self.face([lower[i], lower[j], upper[j], upper[i]], colour, radial[i] + radial[j])

    def lathe(self, centre, profile, colour, sides=8, alternate=None):
        """높이·가로 반지름·깊이 반지름의 고리를 잇는다."""
        cx, cy = centre
        rings = [[(cx + rx * math.cos(i * math.tau / sides),
                   cy + ry * math.sin(i * math.tau / sides), z)
                  for i in range(sides)] for z, rx, ry in profile]
        self.face(rings[0], colour, (0, 0, -1))
        self.face(rings[-1], colour, (0, 0, 1))
        for lower, upper in zip(rings, rings[1:]):
            for i in range(sides):
                j = (i + 1) % sides
                angle = (i + 0.5) * math.tau / sides
                tint = alternate if alternate and i % 3 == 0 else colour
                self.face([lower[i], lower[j], upper[j], upper[i]], tint,
                          (math.cos(angle), math.sin(angle), 0))

    def fit(self, footprint, height):
        """장식·열린 문까지 포함한 경계를 발자국 안에 맞추고 바닥을 0에 둔다."""
        lo = [min(v.co[i] for v in self.bm.verts) for i in range(3)]
        hi = [max(v.co[i] for v in self.bm.verts) for i in range(3)]
        size = (footprint[0], footprint[1], height)
        for vertex in self.bm.verts:
            for axis in range(3):
                vertex.co[axis] = ((vertex.co[axis] - lo[axis]) / (hi[axis] - lo[axis])
                                   - (0.5 if axis < 2 else 0.0)) * size[axis]
        bmesh.ops.triangulate(self.bm, faces=list(self.bm.faces))
        self.bm.normal_update()
        if any(f.calc_area() < 1e-10 for f in self.bm.faces):
            raise ValueError("삼각형 넓이 검사 실패: " + self.pid)

    def bounds_godot(self):
        xs = [v.co.x for v in self.bm.verts]
        ys = [v.co.y for v in self.bm.verts]
        zs = [v.co.z for v in self.bm.verts]
        return [[round(v, 4) + 0.0 for v in row]
                for row in ([min(xs), min(zs), -max(ys)], [max(xs), max(zs), -min(ys)])]


def shelf(p):
    for x in (-0.5, 0.46):
        p.box((x, x + 0.04), (-0.5, 0.5), (0, 1), "wood")
    p.box((-0.46, 0.46), (0.46, 0.5), (0.02, 0.98), "wood")
    for z in (0.04, 0.34, 0.65, 0.96):
        p.box((-0.46, 0.46), (-0.5, 0.46), (z, z + 0.04), "worn_wood")


def cold_stove(p):
    for x in (-0.3, 0.3):
        for y in (-0.3, 0.3):
            p.box((x - 0.05, x + 0.05), (y - 0.05, y + 0.05), (0, 0.18), "iron")
    p.lathe((0, 0), [(0.14, 0.43, 0.43), (0.65, 0.48, 0.48)], "iron")
    p.box((-0.5, 0.5), (-0.5, 0.5), (0.65, 0.70), "worn_metal")
    p.box((-0.23, 0.23), (-0.47, -0.43), (0.24, 0.56), "worn_metal")
    p.box((0.13, 0.2), (-0.5, -0.47), (0.36, 0.40), "iron")
    p.beam((0, 0.22, 0.70), (0, 0.22, 1), 0.12, "iron")


def desk(p):
    p.box((-0.5, 0.5), (-0.5, 0.5), (0.91, 1), "worn_wood")
    for x in (-0.44, 0.38):
        for y in (-0.43, 0.36):
            p.box((x, x + 0.06), (y, y + 0.07), (0, 0.91), "wood")
    p.box((-0.43, -0.1), (-0.43, 0.43), (0.45, 0.91), "wood")
    for z in (0.49, 0.70):
        p.box((-0.40, -0.13), (-0.46, -0.43), (z, z + 0.17), "worn_wood")
        p.box((-0.31, -0.22), (-0.49, -0.46), (z + 0.07, z + 0.10), "iron")


def barrel(p):
    p.lathe((0, 0), [(0, 0.40, 0.40), (0.12, 0.44, 0.44), (0.5, 0.49, 0.49),
                      (0.88, 0.44, 0.44), (1, 0.40, 0.40)], "wood", 12, "worn_wood")
    for z in (0.18, 0.74):
        p.lathe((0, 0), [(z, 0.47, 0.47), (z + 0.08, 0.48, 0.48)], "iron", 12)
    for x in (-0.22, 0, 0.22):
        p.box((x - 0.012, x + 0.012), (-0.30, 0.30), (1, 1.005), "wood")


def bed(p):
    p.box((-0.5, 0.5), (-0.5, 0.5), (0.28, 0.46), "wood")
    p.box((-0.46, 0.46), (-0.46, 0.46), (0.46, 0.74), "cloth")
    for x in (-0.46, 0.38):
        for y in (-0.46, 0.38):
            p.box((x, x + 0.08), (y, y + 0.08), (0, 0.28), "wood")
    for x, height in ((-0.5, 1), (0.46, 0.85)):
        p.box((x, x + 0.04), (-0.5, 0.5), (0.46, height), "worn_wood")
    p.box((-0.40, -0.20), (-0.34, 0.34), (0.74, 0.86), "enamel")
    p.box((0.16, 0.42), (-0.45, 0.45), (0.74, 0.79), "cloth")


def bare_tree(p):
    nodes = [(0, 0, 0), (0.04, 0.03, 0.38), (-0.03, -0.02, 0.72), (0.04, 0, 1)]
    for i in range(3):
        p.beam(nodes[i], nodes[i + 1], 0.13 - i * 0.035, "wood", 6, 0.09 - i * 0.032)
    for start, middle, end in [
        (nodes[1], (-0.29, -0.11, 0.58), (-0.49, -0.19, 0.81)),
        (nodes[1], (0.30, 0.14, 0.57), (0.48, 0.22, 0.75)),
        (nodes[2], (-0.12, 0.32, 0.83), (-0.22, 0.49, 0.96)),
        (nodes[2], (0.20, -0.30, 0.84), (0.31, -0.48, 0.98)),
    ]:
        p.beam(start, middle, 0.045, "wood", 6, 0.026)
        p.beam(middle, end, 0.026, "worn_wood", 6, 0.008)


def crate(p, x, y, z):
    x0, x1 = x
    y0, y1 = y
    z0, z1 = z
    t = 0.035
    p.box(x, y, z, "wood")
    for a in (x0, x1 - t):
        for b in (y0 - 0.01, y1 - t + 0.01):
            p.box((a, a + t), (b, b + t), z, "worn_wood")
    for b in (y0 - 0.015, y1):
        p.box(x, (b, b + 0.015), (z0 + 0.08, z0 + 0.12), "worn_wood")
    for i in range(3):
        a = x0 + (x1 - x0) * i / 3
        p.box((a + 0.01, a + (x1 - x0) / 3 - 0.01), y, (z1, z1 + 0.015), "worn_wood")


def crate_stack(p):
    crate(p, (-0.5, -0.02), (-0.5, 0.5), (0, 0.48))
    crate(p, (0.02, 0.5), (-0.5, 0.5), (0, 0.48))
    crate(p, (-0.34, 0.34), (-0.34, 0.34), (0.495, 0.98))


def sack_pile(p):
    for x, y, z, scale in ((-0.25, -0.24, 0, 1), (0.25, -0.21, 0, 1),
                            (0, 0.25, 0, 1), (0, 0.02, 0.45, 0.85)):
        height = 0.55 * scale
        profile = [(z + h * height, r * scale, r * scale * 0.85)
                   for h, r in ((0, 0.16), (0.16, 0.25), (0.57, 0.26), (0.88, 0.19), (1, 0.055))]
        p.lathe((x, y), profile, "cloth", 8)
        p.lathe((x, y), [(z + height, 0.055, 0.047), (z + height + 0.035, 0.08, 0.068)], "cloth", 6)


def drawer_unit(p, drawers):
    p.box((-0.5, 0.5), (-0.46, 0.5), (0, 1), "iron")
    for i in range(drawers):
        z = 0.05 + 0.90 * i / drawers
        top = z + 0.90 / drawers - 0.025
        p.box((-0.46, 0.46), (-0.49, -0.46), (z, top), "worn_metal")
        p.box((-0.11, 0.11), (-0.53, -0.49), (top - 0.085, top - 0.055), "iron")


def file_cabinet(p):
    drawer_unit(p, 4)


def part_crate(p):
    p.box((-0.5, 0.5), (-0.5, 0.5), (0, 0.08), "wood")
    for x in (-0.5, 0.44):
        p.box((x, x + 0.06), (-0.5, 0.5), (0.08, 0.60), "worn_wood")
    for y in (-0.5, 0.44):
        p.box((-0.44, 0.44), (y, y + 0.06), (0.08, 0.60), "wood")
    # 경첩 쪽에 세워 열린 뚜껑. 자물쇠나 걸쇠는 없다.
    p.box((-0.49, 0.49), (0.45, 0.5), (0.60, 1), "worn_wood")
    for x, y, z in ((-0.22, -0.15, 0.35), (0.19, 0.12, 0.40), (0.14, -0.23, 0.30)):
        p.beam((x - 0.1, y, 0.10), (x + 0.08, y + 0.07, z), 0.12, "worn_metal", 6)


def handcart(p):
    p.box((-0.5, 0.22), (-0.36, 0.36), (0.28, 0.36), "wood")
    for y in (-0.38, 0.34):
        p.box((-0.5, 0.22), (y, y + 0.04), (0.36, 0.62), "worn_wood")
    for x in (-0.5, 0.18):
        p.box((x, x + 0.04), (-0.34, 0.34), (0.36, 0.62), "wood")
    p.beam((-0.18, -0.5, 0.20), (-0.18, 0.5, 0.20), 0.04, "iron")
    for y in (-0.5, 0.40):
        p.beam((-0.18, y, 0.20), (-0.18, y + 0.10, 0.20), 0.20, "iron", 12)
    for y in (-0.26, 0.26):
        p.beam((0.12, y, 0.32), (0.5, y, 1), 0.035, "wood")
        p.box((0.12, 0.17), (y - 0.03, y + 0.03), (0, 0.30), "iron")


def blanket_chest(p):
    p.box((-0.5, 0.5), (-0.48, 0.48), (0.10, 0.86), "wood")
    p.box((-0.5, 0.5), (-0.5, 0.5), (0.86, 1), "worn_wood")
    for x in (-0.46, 0.36):
        for y in (-0.43, 0.33):
            p.box((x, x + 0.10), (y, y + 0.10), (0, 0.10), "wood")
    for x in (-0.28, 0.26):
        p.box((x, x + 0.02), (-0.48, 0.48), (1, 1.002), "wood")


def fridge_open(p):
    for x in (-0.45, 0.39):
        p.box((x, x + 0.06), (-0.05, 0.5), (0, 1), "enamel")
    for z in (0, 0.94):
        p.box((-0.39, 0.39), (-0.05, 0.5), (z, z + 0.06), "enamel")
    p.box((-0.39, 0.39), (0.44, 0.5), (0.06, 0.94), "worn_metal")
    for z in (0.36, 0.65):
        p.box((-0.39, 0.39), (0.0, 0.44), (z, z + 0.025), "enamel")
    # 왼쪽 경첩에서 90도 열린 문. 전체 외곽(문 포함)을 1×1m에 맞춘다.
    p.box((-0.50, -0.44), (-0.95, -0.05), (0.06, 0.96), "enamel")
    p.box((-0.54, -0.50), (-0.82, -0.76), (0.43, 0.63), "iron")


def iv_stand(p):
    p.beam((0, 0, 0.10), (0, 0, 0.91), 0.024, "worn_metal")
    for i in range(3):
        angle = math.tau * i / 3
        x, y = 0.5 * math.cos(angle), 0.5 * math.sin(angle)
        p.beam((0, 0, 0.12), (x, y, 0.055), 0.025, "worn_metal", 6)
        p.beam((x - 0.025, y, 0.045), (x + 0.025, y, 0.045), 0.045, "iron")
    for sign in (-1, 1):
        points = [(0, 0, 0.91), (sign * 0.13, 0, 0.98),
                  (sign * 0.24, 0, 0.94), (sign * 0.24, 0, 0.88)]
        for a, b in zip(points, points[1:]):
            p.beam(a, b, 0.012, "worn_metal", 6)


def tool_chest(p):
    drawer_unit(p, 3)
    p.box((-0.5, 0.5), (-0.49, 0.5), (1, 1.035), "wood")


def paper_cart(p):
    for x in (-0.46, 0.40):
        for y in (-0.42, 0.36):
            p.box((x, x + 0.06), (y, y + 0.06), (0.12, 1), "worn_metal")
            p.beam((x, y, 0.07), (x + 0.06, y, 0.07), 0.07, "iron")
    for z in (0.16, 0.52, 0.88):
        p.box((-0.5, 0.5), (-0.5, 0.5), (z, z + 0.04), "wood")
    for x, y, z in ((-0.23, 0, 0.20), (0.22, 0.04, 0.56), (-0.15, -0.03, 0.92)):
        for i in range(3):
            p.box((x - 0.18 + 0.008 * i, x + 0.18), (y - 0.30, y + 0.30),
                  (z + i * 0.018, z + i * 0.018 + 0.014), "enamel")


def oxygen_cylinder(p):
    p.box((-0.5, 0.5), (-0.5, 0.5), (0, 0.06), "iron")
    p.lathe((0, 0), [(0.06, 0.28, 0.28), (0.12, 0.33, 0.33), (0.77, 0.33, 0.33),
                      (0.87, 0.22, 0.22), (0.91, 0.09, 0.09)], "worn_metal", 12)
    p.beam((0, 0, 0.91), (0, 0, 1), 0.045, "iron", 6)
    p.box((-0.13, 0.13), (-0.04, 0.04), (0.97, 1), "iron")
    p.beam((0.08, -0.03, 0.94), (0.08, -0.11, 0.94), 0.055, "enamel")


def pallet_stack(p):
    for layer in range(3):
        z = layer / 3
        for y in (-0.5, -0.06, 0.38):
            p.box((-0.5, 0.5), (y, y + 0.12), (z, z + 0.055), "wood")
        for x in (-0.44, -0.04, 0.36):
            p.box((x, x + 0.08), (-0.5, 0.5), (z + 0.055, z + 0.265), "wood")
        for i in range(5):
            x = -0.5 + 0.21 * i
            p.box((x, x + 0.16), (-0.5, 0.5), (z + 0.265, z + 1 / 3), "worn_wood")


# kind: (조형 함수, 최빈 발자국 m, 높이 m, 최빈 크기 원문 수, 종류 원문 수, 쓰임)
# 80개 지도 원문의 사전·행 형식을 표준 입력 계산으로 함께 셌다.
# 빈도는 런타임 배치 수가 아니라 원문에 적힌 rect 수다.
PROPS = {
    "shelf": (shelf, (3, 1), 1.8, 1556, 1609, "네 단 나무 선반"),
    "cold_stove": (cold_stove, (1, 1), 1.1, 1329, 1329, "불 꺼진 무쇠 난로와 짧은 관"),
    "desk": (desk, (2, 1), 0.75, 1293, 1297, "서랍 둘 달린 나무 책상"),
    "barrel": (barrel, (1, 1), 0.9, 1310, 1321, "쇠 테 둘을 두른 나무 통"),
    "bed": (bed, (2, 1), 0.5, 1142, 1144, "낮은 침대와 얇은 침구"),
    "bare_tree": (bare_tree, (1, 1), 5.2, 1235, 1235, "잎 없이 위로 뻗는 좁은 나무"),
    "crate_stack": (crate_stack, (2, 2), 1.25, 706, 726, "상자 셋을 두 단으로 쌓음"),
    "sack_pile": (sack_pile, (2, 2), 0.85, 527, 536, "무표식 저장 자루 넷"),
    "file_cabinet": (file_cabinet, (2, 1), 1.3, 527, 527, "서랍 넷 철제 서류함"),
    "part_crate": (part_crate, (1, 1), 0.7, 454, 454, "뚜껑 열린 부품 상자와 덩어리 셋"),
    "handcart": (handcart, (2, 1), 1.0, 390, 411, "바퀴 둘과 받침 달린 손수레"),
    "blanket_chest": (blanket_chest, (2, 1), 0.65, 389, 391, "뚜껑 닫힌 나무 궤"),
    "fridge_open": (fridge_open, (1, 1), 1.5, 355, 355, "문이 90도 열린 빈 법랑 냉장고"),
    "iv_stand": (iv_stand, (1, 1), 1.6, 346, 346, "세 발 받침과 고리 둘인 링거대"),
    "tool_chest": (tool_chest, (2, 1), 0.8, 331, 331, "서랍 셋 낮은 공구함"),
    "paper_cart": (paper_cart, (2, 1), 1.05, 329, 329, "무문자 종이 묶음이 놓인 서류 수레"),
    "oxygen_cylinder": (oxygen_cylinder, (1, 1), 1.4, 297, 297, "받침 포함 산소통 하나"),
    "pallet_stack": (pallet_stack, (2, 2), 0.6, 286, 288, "짐받이 세 단"),
}


def export(piece, path):
    mesh = bpy.data.meshes.new(piece.pid)
    obj = None
    try:
        piece.bm.to_mesh(mesh)
        attr = mesh.color_attributes["Col"]
        mesh.color_attributes.active_color = attr
        mesh.color_attributes.render_color_index = list(mesh.color_attributes).index(attr)
        obj = bpy.data.objects.new(piece.pid, mesh)
        bpy.context.scene.collection.objects.link(obj)
        for other in bpy.context.scene.objects:
            other.select_set(other == obj)
        bpy.context.view_layer.objects.active = obj
        bpy.ops.export_scene.gltf(
            filepath=path, export_format="GLB", use_selection=True, export_yup=True,
            export_apply=False, export_materials="NONE", export_texcoords=False,
            export_normals=True, export_tangents=False, export_vertex_color="ACTIVE",
            export_extras=False, export_animations=False)
    finally:
        if obj is not None:
            bpy.data.objects.remove(obj, do_unlink=True)
        bpy.data.meshes.remove(mesh)


def check_glb(path, expected_tris):
    """실제 내보낸 GLB의 메시·색·삼각형·외부 자원 여부를 확인한다."""
    with open(path, "rb") as handle:
        data = handle.read()
    magic, version, length = struct.unpack_from("<4sII", data)
    chunk_length, chunk_type = struct.unpack_from("<II", data, 12)
    if magic != b"glTF" or version != 2 or length != len(data) or chunk_type != 0x4E4F534A:
        raise ValueError("GLB 머리 검사 실패")
    book = json.loads(data[20:20 + chunk_length])
    if len(book.get("meshes", [])) != 1 or sum("mesh" in n for n in book.get("nodes", [])) != 1:
        raise ValueError("단일 메시 검사 실패")
    primitives = book["meshes"][0]["primitives"]
    if len(primitives) != 1:
        raise ValueError("단일 면 묶음 검사 실패")
    primitive = primitives[0]
    if primitive.get("mode", 4) != 4 or "COLOR_0" not in primitive["attributes"]:
        raise ValueError("삼각형·정점색 검사 실패")
    count = book["accessors"][primitive["indices"]]["count"]
    if count % 3 or count // 3 != expected_tris:
        raise ValueError("실제 GLB 삼각형 수 불일치")
    if any(book.get(key) for key in ("materials", "images", "textures", "animations", "skins")):
        raise ValueError("불필요한 재질·그림·애니메이션")
    if any("uri" in buffer for buffer in book.get("buffers", [])):
        raise ValueError("외부 자원 참조")
    return len(data), hashlib.sha256(data).hexdigest()


def write_books(out_dir, rows, failures):
    placement = ("rect 가운데 바닥에 놓는다. 기본 앞은 +Z, 위는 +Y. facing 0~3은 "
                 "+Y 둘레 0/90/180/270도. 직사각형은 회전 후 X·Z 경계를 rect 크기에 "
                 "맞추며 높이는 유지한다. 열린 문과 가지도 발자국에 포함한다.")
    book = {
        "version": 1, "script_version": SCRIPT_VERSION, "blender": bpy.app.version_string,
        "grid": {"cell_m": 1.0}, "axis": "X right, +Y up, +Z front",
        "origin": "cell_floor", "colour_encoding": "linear RGBA vertex colours, alpha 1",
        "palette": PALETTE, "placement": placement, "skipped": SKIPPED,
        "census": {"source": "s2/game/world/maps/*.gd", "files": 80,
                   "measure": "literal rect frequencies; dictionaries and compact rows"},
        "assets": {r["id"]: {k: v for k, v in r.items() if k != "id"} for r in rows},
        "failures": failures,
    }
    with open(os.path.join(out_dir, "catalog.json"), "w", encoding="utf-8", newline="\n") as handle:
        json.dump(book, handle, ensure_ascii=False, indent=2)
        handle.write("\n")
    lines = ["# 공용 소품", "", "`tools/blender/props_common.py`가 생성한 장부다. "
             "이 파일과 `catalog.json`은 손으로 고치지 않는다.", "", "```",
             "blender -b --factory-startup -P tools/blender/props_common.py -- --repo .", "```", "",
             "칸 1m, 소품마다 메시·면 묶음 각 하나, LOD 없음, 삼각형 상한 600. "
             "재질·그림·셰이더 없이 6색 팔레트의 정점색을 쓴다.", "", placement, "",
             "크기 순서는 Godot X×Y×Z(가로×높이×깊이)다. "
             "최빈 수는 지도 원문 rect 수이며 실제 런타임 배치 수와 구분한다.", "",
             "| 이름 | 쓰임 | 발자국 m | 높이 m | 최빈 수/원문 수 | 삼각형/상한 | 크기 X×Y×Z m | 바이트 | 놓는 법 |",
             "|---|---|---|---|---|---|---|---|---|"]
    for row in rows:
        width, depth = row["footprint_m"]
        dimensions = "×".join("%g" % n for n in row["dimensions_m"])
        lines.append("| `%s` | %s | %g×%g | %g | %d/%d | %d/600 | %s | %d | rect 가운데 바닥, facing |" % (
            row["id"], row["use"], width, depth, row["height_m"], row["modal_rect_count"],
            row["source_rect_count"], row["lod0_tris"], dimensions, row["bytes"]))
    lines += ["", "## 파일 확인값", "", "| 이름 | sha256 |", "|---|---|"]
    lines += ["| `%s` | `%s` |" % (row["id"], row["sha256"]) for row in rows]
    lines += ["", "## 제외", ""] + ["- `%s`: %s." % item for item in SKIPPED.items()]
    if failures:
        lines += ["", "## 생성 실패", ""]
        lines += ["- `%s`: %s (%s)." % (row["id"], row["failure_code"], row["error_type"]) for row in failures]
    with open(os.path.join(out_dir, "README.md"), "w", encoding="utf-8", newline="\n") as handle:
        handle.write("\n".join(lines) + "\n")


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    parser = argparse.ArgumentParser()
    parser.add_argument("--repo", required=True)
    args = parser.parse_args(argv)
    out_dir = os.path.join(os.path.abspath(args.repo), "s2", "models", "props_common")
    os.makedirs(out_dir, exist_ok=True)
    bpy.ops.wm.read_factory_settings(use_empty=True)
    rows, failures = [], []
    for pid, (build, footprint, height, modal_count, source_count, use) in PROPS.items():
        piece = Piece(pid)
        try:
            build(piece)
            piece.fit(footprint, height)
            tris = len(piece.bm.faces)
            if not 0 < tris <= TRIANGLE_LIMIT:
                raise ValueError("삼각형 상한 검사 실패: " + pid)
            bounds = piece.bounds_godot()
            path = os.path.join(out_dir, pid + ".glb")
            export(piece, path)
            size, digest = check_glb(path, tris)
            rows.append({
                "id": pid, "status": "ready", "path": "res://models/props_common/%s.glb" % pid,
                "category": "prop", "use": use, "stretch": "xz_after_facing",
                "origin": "cell_floor", "height": "free", "fits_cell": footprint == (1, 1),
                "footprint_m": list(footprint), "height_m": height,
                "modal_rect_count": modal_count, "source_rect_count": source_count,
                "lod0_tris": tris, "triangle_limit": TRIANGLE_LIMIT,
                "dimensions_m": [round(bounds[1][i] - bounds[0][i], 4) for i in range(3)],
                "bounds_m": bounds, "colours": sorted(piece.colours), "bytes": size, "sha256": digest,
            })
            print("PROP_READY %s tris=%d bytes=%d" % (pid, tris, size), flush=True)
        except Exception as error:
            failures.append({"id": pid, "failure_code": "F-GENERATE", "error_type": type(error).__name__,
                             "blocked_reason": "이 종류의 조형 또는 GLB 검사가 실패함"})
            print("PROP_FAILED %s %s: %s" % (pid, type(error).__name__, error), flush=True)
        finally:
            piece.bm.free()
        # 완성된 파일은 즉시 남기고, 일부가 실패해도 독립적인 다음 종류를 만든다.
        write_books(out_dir, rows, failures)
    print("PROPS_COMMON " + json.dumps({"pieces": len(rows), "failures": failures,
                                        "tris": {r["id"]: r["lod0_tris"] for r in rows}}, ensure_ascii=False), flush=True)
    if failures:
        raise SystemExit(1)


if __name__ == "__main__":
    main()
