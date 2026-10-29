"""첫 정차 가구 열 종을 공개 3D(CC0)와 기본 도형으로 바꾼다(결정 424·477).
Blender 4.5 헤드리스. 원본 .gltf·.bin·질감은 저장소 밖에 둔다.

blender -b --factory-startup --python-exit-code 1 -P tools/blender/props_stop01_cc0.py -- --repo . --src C:\\dev\\zombie\\assets_raw\\polyhaven\\models [--out <폴더>] [--only wardrobe,dining_set]

고른 오브젝트 → 평면 먼저 줄이기 → 질감에서 선형 Col 읽기 → copies 놓기 →
발자국 가운데·바닥 원점에 맞춤 → 단일 메시 GLB → 실제 바이트를 읽어 장부.
위 +Y, 앞 +Z, 등 -Z(Godot). Blender에서는 Z가 위, -Y가 앞이다.
Col.a: 몸체 1, 테두리·손잡이·쇠붙이 .5, 책·종이·상품·공구·천 0.
weathered는 판 넷(tint_sets_body/trim)을 재질 값으로, 판 번호를 MultiMesh 사용자 자료로 받는다(furniture_tints.gd dress).
--out은 검수용 폴더다. 장부 path는 최종 res:// 경로이며 게임으로 복사는 하지 않는다.
이번 발주의 Blender·Godot·시각 검사는 not_run. 이 파일을 import하여 시험하지 않는다.
"""
import sys

sys.dont_write_bytecode = True

import argparse
from collections import Counter
import colorsys
import hashlib
import json
import math
from pathlib import Path
import random
import re
import struct
import tempfile

import bmesh
import bpy
from mathutils import Matrix, Vector

sys.path.insert(0, str(Path(__file__).resolve().parent))
import props_common as pc  # noqa: E402  공용 도형·내보내기·검사는 고치지 않는다.

TRIANGLE_LIMIT = 700
MARGIN = .96
DATE = "2026-10-29"
SCRIPT = "tools/blender/props_stop01_cc0.py"
MASKS = {"body": 1.0, "trim": .5, "keep": 0.0}
TRIANGLE_BUDGETS = {"workbench": 500, "bookcase": 700, "drawer_chest_spilled": 700,
                    "shop_shelf": 500, "toolbox": 200, "office_desk": 600}
BOOK_SEED = 1017
# 새 기본 도형의 sRGB. 이전 iron_bed 팔레트와 조형은 그대로 둔다.
PRIMITIVE_SRGB = {
    "wood_dark": (.32, .26, .21), "wood_worn": (.39, .31, .24),
    "steel_dark": (.22, .25, .27), "black_steel": (.10, .12, .13),
    "shelf_blue": (.37, .43, .47), "shelf_trim": (.20, .24, .27),
    "tool_red": (.35, .24, .22), "paper": (.62, .61, .56),
    "book_navy": (.20, .25, .32), "book_brick": (.36, .24, .22),
    "book_green": (.24, .31, .26), "book_earth": (.38, .32, .23),
    "book_taupe": (.35, .32, .29), "stock_box": (.37, .34, .29), "can": (.32, .36, .37),
}
BOOK_COLOURS = ("book_navy", "book_brick", "book_green", "book_earth", "book_taupe")
PRIMITIVE_PARTS = {
    "workbench": ["four_plank_top", "four_legs", "lower_shelf", "vise", "hammer", "hand_plane"],
    "bookcase": ["seeded_books"],
    "drawer_chest_spilled": ["scattered_paper"],
    "shop_shelf": ["straight_sides", "four_shelves", "back", "price_strips", "empty_cans", "boxes"],
    "toolbox": ["open_body", "hinged_lid", "tray", "black_handle", "two_tools"],
    "office_desk": ["three_drawer_pedestal", "handles"],
    "iron_bed": ["frame", "mattress", "blanket"],
}
# 상자당 12삼각형, 빈 8각 깡통당 60. 실측은 굽기 후 별도 필드에 기록한다.
PRIMITIVE_TRIANGLES = {"workbench": 288, "bookcase": 216, "drawer_chest_spilled": 48,
                       "shop_shelf": 300, "toolbox": 192, "office_desk": 84, "iron_bed": 264}
# 비율은 sRGB의 HSV에 적용한다. 기존 tint() 결과의 현재 색을 누르며 원본색으로 재칠하지 않는다.
BODY_PRESS_BASIS = "srgb_hsv_after_existing_palette_tint_body_only"
BODY_PRESS = {
    "wardrobe": dict(saturation=.60, value=.85),
    "dining_set": dict(saturation=.60, value=.85),
    "table_overturned": dict(saturation=.60, value=.85),
    "office_desk": dict(saturation=.60, value=.85),
    "bookcase": dict(saturation=.60, value=.85),
    "drawer_chest_spilled": dict(saturation=.60, value=.85),
}
GRADE = dict(saturation=.45, value=.82, cool=[.78, .85, .95], cool_mix=.35)
# fx_model_grade 뒤, 조명·날씨 앞의 선형 RGB. 나무 몸체는 마루(.14~.24)보다 어둡게.
GRADED_TARGETS = {
    "cream": (.56, .54, .46), "sage": (.38, .46, .37),
    "blue": (.34, .44, .52), "brick": (.28, .20, .17),
    "walnut": (.11, .09, .072), "oak": (.12, .10, .078),
    "moss": (.23, .32, .23), "iron": (.14, .16, .175),
    "steel": (.26, .285, .30), "linen": (.65, .65, .59),
}


def grade(rgb):
    value = max(rgb)
    return tuple((value * (1 - GRADE["saturation"]) + c * GRADE["saturation"])
                 * GRADE["value"] * (1 - GRADE["cool_mix"] + cool * GRADE["cool_mix"])
                 for c, cool in zip(rgb, GRADE["cool"]))


def inverse_grade(target):
    before = [c / (GRADE["value"] * (1 - GRADE["cool_mix"] + cool * GRADE["cool_mix"]))
              for c, cool in zip(target, GRADE["cool"])]
    value = max(before)
    rgb = tuple((c - value * (1 - GRADE["saturation"])) / GRADE["saturation"] for c in before)
    if not all(0 <= c <= 1 for c in rgb):
        raise ValueError("F-COLOUR: 역보정 범위 밖 " + str(target))
    if max(abs(a - b) for a, b in zip(grade(rgb), target)) > 1e-8:
        raise ValueError("F-COLOUR: 역보정 불일치")
    return rgb


PALETTE = {name: inverse_grade(rgb) for name, rgb in GRADED_TARGETS.items()}


def copy_spec(source, parts, size, x=0.0, z=0.0, yaw=0.0, bottom=0.0, tilt=0.0, mirror=False):
    # parts: (실제 node 이름, 삼각형 상한, 원본 좌표에서 앞으로 뺄 거리 m).
    return dict(source=source, parts=parts, size=size, x=x, z=z, yaw=yaw,
                bottom=bottom, tilt=tilt, mirror=mirror)


TABLE = [("painted_wooden_table", 240, 0.0)]
CHAIR = [("painted_wooden_chair_01", 120, 0.0)]
# 원본은 3열×2단. 가운데 위 02·아래 05를 몸체 묶음에서 빼고 최종 m 좌표로 따로 놓는다.
DRAWERS = [("vintage_wooden_drawer_01_body", 220, 0.0)] + [
    ("vintage_wooden_drawer_01_drawer%02d" % i, 45, 0.0) for i in (1, 3, 4, 6)]
# size는 최종 (가로 x, 높이 y, 깊이 z) m. rect_fallback은 관측값이 없는 세 종에만 쓴다.
SWAPS = {
    "wardrobe": dict(size=[1.22, 1.90, .60], paint="cream", copies=[
        copy_spec("painted_wooden_cabinet_02", [("painted_wooden_cabinet_02", 300, 0.0)], [1.22, 1.90, .55]),
        copy_spec("painted_wooden_cabinet_02", [("painted_wooden_cabinet_02_door", 70, 0.0)], [.58, 1.68, .04], x=-.30, z=.30, bottom=.11),
        copy_spec("painted_wooden_cabinet_02", [("painted_wooden_cabinet_02_door", 70, 0.0)], [.58, 1.68, .04], x=.30, z=.30, bottom=.11, mirror=True)],
        note="몸체 앞에 원본 문짝을 길게 맞춘 두 벌(한 벌 좌우 반전). 원본 서랍은 생략. 깊이 .60 m의 두 문 옷장"),
    "shop_shelf": dict(size=[2.08, 1.60, .50], paint="shelf_blue", copies=[],
        note="기본 도형: 곧은 옆판·네 판·뒤판·가격표 띠. 빈 깡통 둘과 상자 넷은 keep 마스크"),
    "bookcase": dict(size=[1.40, 1.90, .56], paint="walnut", copies=[
        copy_spec("wooden_bookshelf_worn", [("wooden_bookshelf_worn", 480, 0.0)], [1.40, 1.90, .56])],
        note="원본 선반을 보존하고 지지면마다 서 있는 책 무리·누운 책·빈 틈. 책 18권, 씨앗 1017, 탁한 다섯 색, keep 마스크"),
    "dining_set": dict(size=[1.60, .88, 1.80], paint="blue", copies=[
        copy_spec("painted_wooden_table", TABLE, [1.60, .76, .82]),
        copy_spec("painted_wooden_chair_01", CHAIR, [.44, .88, .50], z=-.65),
        copy_spec("painted_wooden_chair_01", CHAIR, [.44, .88, .50], z=.65, yaw=math.pi)],
        note="식탁 하나·서로 마주 보는 의자 둘. 상판 .76 m, 등받이 .88 m"),
    "table_overturned": dict(size=[.76, .82, 1.60], rect_fallback=[1, 2], paint="blue", copies=[
        copy_spec("painted_wooden_table", TABLE, [1.60, .76, .82], tilt=math.pi / 2, yaw=math.pi / 2)],
        note="식탁과 같은 원본·색·치수의 상을 90도 옆으로 눕힘"),
    "workbench": dict(size=[1.75, .90, .86], paint="wood_dark", copies=[],
        note="기본 도형: 틈 있는 두꺼운 상판 네 장·네 다리·아래 선반·끝 바이스·망치·대패. 어두운 나무 두 톤과 회색 쇠"),
    "office_desk": dict(size=[1.40, .77, .75], paint="brick", copies=[
        copy_spec("WoodenTable_01", [("WoodenTable_01", 420, 0.0)], [1.40, .77, .75])],
        note="원본 상판·다리 보존. 한쪽 아래 기본 도형 서랍 받침(서랍 셋·손잡이) 추가"),
    # old_bed_frame(Poly Haven)은 가는 관이 많아 면 줄이기가 3,434면에서 멈춰(목표 550) Blender 기본 도형으로 짓는다.
    "iron_bed": dict(size=[1.92, 1.04, .94], paint="iron", copies=[],
        note="Blender 기본 도형 철 침대: 머리·발 판(기둥·가로대·살), 옆 가로대, 매트리스와 덮은 담요. 긴 축 X, 긴 옆면 앞 +Z"),
    "drawer_chest_spilled": dict(size=[.90, 1.00, .86], rect_fallback=[1, 1], paint="moss", copies=[
        copy_spec("vintage_wooden_drawer_01", DRAWERS, [.90, 1.00, .46], z=-.20),
        copy_spec("vintage_wooden_drawer_01", [("vintage_wooden_drawer_01_drawer02", 45, 0.0)],
                  [.27, .39, .42], z=.03, bottom=.515),
        copy_spec("vintage_wooden_drawer_01", [("vintage_wooden_drawer_01_drawer05", 45, 0.0)],
                  # 바닥 원점 주위의 기울임이 깊이 중심을 약 .06 m 앞으로 옮긴다.
                  [.27, .39, .42], z=.10, bottom=.004, tilt=math.radians(18))],
        note="원본 몸체·서랍 재사용. 가운데 위 02는 깊이의 절반만큼 열고, 아래 05는 바닥에서 18도 기울임. 종이 네 장 추가, .90×.86 m 안"),
    "toolbox": dict(size=[.38, .40, .35], rect_fallback=[1, 1], paint="tool_red", copies=[],
        note="기본 도형: 빈 몸통·뒤로 110도 열린 뚜껑·안쪽 쟁반·튀어나온 공구 둘. 바랜 빨강 몸체·검은 쇠 손잡이, 열린 전체 치수"),
}


def srgb_to_linear(c):
    return c / 12.92 if c <= .04045 else ((c + .055) / 1.055) ** 2.4


def press_body(rgba, pid):
    """선형 Col → sRGB HSV 비율 조정 → 선형 Col. trim·keep와 원래 알파는 보존한다."""
    if pid not in BODY_PRESS or rgba[3] < .75:
        return rgba
    srgb = [12.92 * c if c <= .0031308 else 1.055 * c ** (1 / 2.4) - .055 for c in rgba[:3]]
    hue, saturation, value = colorsys.rgb_to_hsv(*srgb)
    knobs = BODY_PRESS[pid]
    pressed = colorsys.hsv_to_rgb(hue, saturation * knobs["saturation"], value * knobs["value"])
    return (*(srgb_to_linear(c) for c in pressed), rgba[3])


class Sampler:
    """props_field_cc0와 같은 UV 표본기. 바탕색 필수, AO는 해당 재질에 연결된 것만."""
    def __init__(self, material):
        bsdf = None
        if material is not None and material.use_nodes:
            bsdf = next((n for n in material.node_tree.nodes if n.type == "BSDF_PRINCIPLED"), None)
        self.diff = self._load(self._image(bsdf.inputs["Base Color"])) if bsdf else None
        if self.diff is None:
            raise ValueError("F-INPUT-MISSING: 원본 바탕색 질감을 읽지 못함")
        ao = next((n.image for n in material.node_tree.nodes if n.type == "TEX_IMAGE" and n.image
                   and ("_arm_" in n.image.name.lower() or "_ao_" in n.image.name.lower())), None)
        self.ao = self._load(ao)

    @staticmethod
    def _image(socket):
        stack, seen = [link.from_node for link in socket.links], set()
        while stack:
            node = stack.pop()
            if node in seen:
                continue
            seen.add(node)
            if node.type == "TEX_IMAGE" and node.image is not None:
                return node.image
            for inp in node.inputs:
                stack.extend(link.from_node for link in inp.links)
        return None

    @staticmethod
    def _load(image):
        if image is None or image.size[0] == 0 or image.size[1] == 0:
            return None
        return (image.size[0], image.size[1], list(image.pixels[:]), image.colorspace_settings.name == "sRGB")

    @staticmethod
    def _px(tex, uv):
        w, h, px, srgb = tex
        x = min(w - 1, max(0, int((uv[0] % 1.0) * w)))
        y = min(h - 1, max(0, int((uv[1] % 1.0) * h)))
        rgb = px[(y * w + x) * 4:(y * w + x) * 4 + 3]
        return [srgb_to_linear(c) for c in rgb] if srgb else list(rgb)

    def colour(self, uv):
        rgb = self._px(self.diff, uv)
        if self.ao is not None:
            ao = self._px(self.ao, uv)[0]
            rgb = [c * (.65 + .35 * ao) for c in rgb]
        return rgb


def tint(rgb, paint, mask):
    # 원본 결의 명암은 남기되 역보정한 색 판 쪽으로 강하게 당긴다.
    value = max(rgb)
    shade = .87 + .21 * min(1.0, math.sqrt(max(0.0, value)))
    if paint in PRIMITIVE_SRGB:
        return (*(srgb_to_linear(c) * shade for c in PRIMITIVE_SRGB[paint]), mask)
    hue = [c / value if value > 1e-8 else 1.0 for c in rgb]
    neutral = value > 1e-8 and max(rgb) - min(rgb) < value * .12
    key = "steel" if mask == .5 and (paint == "iron" or neutral) else paint
    colour = [min(1.0, c * shade * (.95 + .05 * h)) for c, h in zip(PALETTE[key], hue)]
    return (*colour, mask)


def decimate(obj, target):
    """작게 용접 → 같은 평면 → 마지막에 collapse. 다른 판·문은 함께 뭉개지 않는다."""
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    weld = obj.modifiers.new("weld", "WELD")
    weld.merge_threshold = .00005
    bpy.ops.object.modifier_apply(modifier=weld.name)
    planar = obj.modifiers.new("planar", "DECIMATE")
    planar.decimate_type = "DISSOLVE"
    planar.angle_limit = math.radians(3)
    planar.use_dissolve_boundaries = False
    planar.delimit = {"MATERIAL", "SEAM", "UV"}
    bpy.ops.object.modifier_apply(modifier=planar.name)
    if sum(len(p.vertices) - 2 for p in obj.data.polygons) > target:
        drop_specks(obj)
    for _ in range(8):
        tris = sum(len(p.vertices) - 2 for p in obj.data.polygons)
        if 0 < tris <= target:
            return tris
        mod = obj.modifiers.new("collapse", "DECIMATE")
        mod.decimate_type = "COLLAPSE"
        mod.ratio = max(.002, target / max(1, tris) * .97)
        mod.use_collapse_triangulate = True
        bpy.ops.object.modifier_apply(modifier=mod.name)
    tris = sum(len(p.vertices) - 2 for p in obj.data.polygons)
    if 0 < tris <= target:
        return tris
    raise ValueError("F-BUDGET: 부품 예산을 지키지 못함 %s (%d > %d)" % (obj.name, tris, target))


def drop_specks(obj, size=.04):
    """떨어진 작은 조각(나사·못 머리, 가장 긴 변 4 cm 밑)은 대각뷰 거리에서 안 보이고 면 줄이기를 막으니 지운다."""
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    seen, kill = set(), []
    for face in bm.faces:
        if face.index in seen:
            continue
        seen.add(face.index)
        stack, island = [face], []
        while stack:
            f = stack.pop()
            island.append(f)
            for edge in f.edges:
                for g in edge.link_faces:
                    if g.index not in seen:
                        seen.add(g.index)
                        stack.append(g)
        pts = [v.co for f in island for v in f.verts]
        if max(max(p[i] for p in pts) - min(p[i] for p in pts) for i in range(3)) < size:
            kill.extend(island)
    if kill:
        bmesh.ops.delete(bm, geom=kill, context="FACES")
        bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context="VERTS")
        bm.to_mesh(obj.data)
    bm.free()


def component_masks(mesh):
    """연결된 판의 넓은 면은 몸체, 얇은 옆면·막대·작은 손잡이는 테두리. 의미 분할은 시각 검수 대상."""
    links = [[] for _ in mesh.vertices]
    for edge in mesh.edges:
        a, b = edge.vertices
        links[a].append(b)
        links[b].append(a)
    groups, seen = {}, set()
    extent = [max(v.co[i] for v in mesh.vertices) - min(v.co[i] for v in mesh.vertices) for i in range(3)]
    reference = max(extent)
    for vertex in mesh.vertices:
        if vertex.index in seen:
            continue
        todo, members = [vertex.index], []
        seen.add(vertex.index)
        while todo:
            at = todo.pop()
            members.append(at)
            for other in links[at]:
                if other not in seen:
                    seen.add(other)
                    todo.append(other)
        dims = [max(mesh.vertices[v].co[i] for v in members) - min(mesh.vertices[v].co[i] for v in members)
                for i in range(3)]
        ordered = sorted(dims)
        trim = ordered[2] < reference * .16 or ordered[1] < reference * .065
        thin_axis = dims.index(min(dims)) if ordered[0] < ordered[1] * .22 else None
        for v in members:
            groups[v] = (trim, thin_axis)
    result = {}
    for poly in mesh.polygons:
        trim, thin_axis = groups[poly.vertices[0]]
        edge = thin_axis is not None and abs(poly.normal[thin_axis]) < .5
        result[poly.index] = .5 if trim or edge else 1.0
    return result


def load_part(src_dir, source, parts):
    """한 원본의 고른 부품만 읽음. 월드 변환과 부품 사이 거리를 보존한 순수 좌표·색 목록을 돌려준다."""
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=str(src_dir / source / (source + "_1k.gltf")))
    objects = []
    for name, target, forward in parts:
        obj = bpy.data.objects.get(name)
        if obj is None or obj.type != "MESH":
            raise ValueError("F-INPUT-MISSING: 원본 오브젝트 " + name)
        objects.append((obj, obj.matrix_world.copy(), target, forward))
    keep = {row[0] for row in objects}
    # 부모를 지우기 전에 월드 행렬을 모두 저장한다.
    for obj, world, _, _ in objects:
        obj.parent = None
        obj.data = obj.data.copy()
        obj.data.transform(world)
        obj.matrix_world = Matrix.Identity(4)
    for obj in list(bpy.context.scene.objects):
        if obj not in keep:
            bpy.data.objects.remove(obj, do_unlink=True)
    verts, faces = [], []
    for obj, _, target, forward in objects:
        decimate(obj, target)
        mesh = obj.data
        mesh.update()
        uv = mesh.uv_layers.active
        if uv is None:
            raise ValueError("F-INPUT-MISSING: 원본 UV " + obj.name)
        samplers = {i: Sampler(slot.material) for i, slot in enumerate(obj.material_slots)}
        masks = component_masks(mesh)
        offset = len(verts)
        verts.extend(v.co.copy() + Vector((0, -forward, 0)) for v in mesh.vertices)
        for poly in mesh.polygons:
            if poly.area < 1e-10:
                continue
            if poly.material_index not in samplers:
                raise ValueError("F-INPUT-MISSING: 원본 재질 " + obj.name)
            sampler = samplers[poly.material_index]
            cols = [sampler.colour(uv.data[i].uv) for i in poly.loop_indices]
            mask = .5 if source == "old_bed_frame" else masks[poly.index]
            faces.append(([offset + i for i in poly.vertices], cols, mask))
    return verts, faces


def fit(verts, size):
    """세 축을 정한 가구 치수로 맞추고, 발자국 가운데 바닥을 원점으로. 가구는 땅에 묻지 않는다."""
    lo = Vector([min(v[i] for v in verts) for i in range(3)])
    hi = Vector([max(v[i] for v in verts) for i in range(3)])
    dims = hi - lo
    if min(dims) <= 1e-8:
        raise ValueError("F-GEOMETRY: 두께 없는 가구")
    centre = Vector(((lo.x + hi.x) / 2, (lo.y + hi.y) / 2, lo.z))
    scale = Vector((size[0] / dims.x, size[2] / dims.y, size[1] / dims.z))
    for v in verts:
        for i in range(3):
            v[i] = (v[i] - centre[i]) * scale[i]


def paint_added(piece, before, paint, mask, transform=None):
    verts = set()
    for face in piece.bm.faces:
        if face in before:
            continue
        for loop in face.loops:
            loop[piece.col] = tint(loop[piece.col][:3], paint, mask)
            verts.add(loop.vert)
    if transform is not None:
        for vertex in verts:
            vertex.co = transform @ vertex.co
    piece.colours.add(paint)


def add_box(piece, x, y, z, paint, mask, transform=None):
    before = set(piece.bm.faces)
    piece.box(x, y, z, "cloth" if mask == 0 else "iron")
    paint_added(piece, before, paint, mask, transform)


def add_empty_can(piece, x, y, bottom, radius=.065, height=.17):
    """8각 빈 깡통. 바깥·안쪽·입구 테두리·두 바닥 = 60삼각형, keep 마스크."""
    before = set(piece.bm.faces)
    outer = [(x + radius * math.cos(i * math.tau / 8), y + radius * math.sin(i * math.tau / 8))
             for i in range(8)]
    inner = [(x + (radius - .007) * math.cos(i * math.tau / 8),
              y + (radius - .007) * math.sin(i * math.tau / 8)) for i in range(8)]
    top, floor = bottom + height, bottom + .006
    for i in range(8):
        j = (i + 1) % 8
        outward = (math.cos((i + .5) * math.tau / 8), math.sin((i + .5) * math.tau / 8), 0)
        piece.face([(*outer[i], bottom), (*outer[j], bottom), (*outer[j], top), (*outer[i], top)], "iron", outward)
        piece.face([(*inner[i], floor), (*inner[j], floor), (*inner[j], top), (*inner[i], top)], "iron",
                   (-outward[0], -outward[1], 0))
        piece.face([(*outer[i], top), (*outer[j], top), (*inner[j], top), (*inner[i], top)], "iron", (0, 0, 1))
    piece.face([(*p, bottom) for p in outer], "iron", (0, 0, -1))
    piece.face([(*p, floor) for p in inner], "iron", (0, 0, 1))
    paint_added(piece, before, "can", 0.0)


def workbench(piece):
    """24상자 = 288삼각형. 상판의 세 틈은 15 mm, 최고점은 바이스 .90 m."""
    plank = (.86 - 3 * .015) / 4
    for i in range(4):
        y = -.43 + i * (plank + .015)
        add_box(piece, (-.875, .875), (y, y + plank), (.72, .81),
                "wood_dark" if i % 2 == 0 else "wood_worn", 1.0)
    for x in (-.79, .69):
        for y in (-.35, .25):
            add_box(piece, (x, x + .10), (y, y + .10), (0, .72), "wood_dark", 1.0)
    for i in range(3):
        y = -.34 + i * .23
        add_box(piece, (-.77, .77), (y, y + .22), (.17, .21), "wood_worn", 1.0)
    for x in (-.78, .70):
        add_box(piece, (x, x + .08), (-.34, .34), (.12, .18), "wood_dark", 1.0)
    add_box(piece, (-.79, .79), (.30, .35), (.60, .72), "wood_dark", 1.0)
    # 한쪽 끝 바이스: 받침·고정 턱·움직이는 턱·나사·돌림 막대.
    add_box(piece, (-.86, -.64), (-.16, .16), (.70, .74), "steel_dark", .5)
    add_box(piece, (-.85, -.82), (-.14, .14), (.77, .90), "steel_dark", .5)
    add_box(piece, (-.71, -.67), (-.14, .14), (.77, .90), "steel_dark", .5)
    add_box(piece, (-.85, -.62), (-.025, -.005), (.82, .84), "black_steel", .5)
    add_box(piece, (-.63, -.61), (-.14, .14), (.80, .825), "black_steel", .5)
    # 상판 위 공구는 칠 표의 영향을 받지 않는다.
    add_box(piece, (.10, .36), (-.28, -.25), (.81, .835), "wood_worn", 0.0)
    add_box(piece, (.33, .39), (-.32, -.21), (.825, .88), "steel_dark", 0.0)
    add_box(piece, (.30, .57), (.12, .24), (.81, .845), "wood_worn", 0.0)
    add_box(piece, (.42, .44), (.14, .22), (.84, .89), "steel_dark", 0.0)
    add_box(piece, (.32, .36), (.145, .215), (.84, .875), "wood_dark", 0.0)


def add_book(piece, x, y, z, paint, lying=False):
    """상자 한 개의 책등·표지는 탁한 색, 쪽 면은 무지 종이색. 추가 면 없이 12삼각형."""
    before = set(piece.bm.faces)
    add_box(piece, x, y, z, paint, 0.0)
    for face in piece.bm.faces:
        if face in before:
            continue
        pts = [v.co for v in face.verts]
        spans = [max(p[i] for p in pts) - min(p[i] for p in pts) for i in range(3)]
        fore_edge = all(abs(p.y - y[1]) < 1e-6 for p in pts)
        page_side = spans[0 if lying else 2] < 1e-6
        if fore_edge or page_side:
            for loop in face.loops:
                loop[piece.col] = tint(loop[piece.col][:3], "paper", 0.0)
    piece.colours.add("paper")


def bookcase(piece):
    """원본의 넓은 수평 윗면에서 책을 받친다. 원본 ≤480 + 18상자×12 = ≤696삼각형."""
    piece.bm.normal_update()
    surfaces = []
    for face in piece.bm.faces:
        pts = [v.co for v in face.verts]
        lo = [min(p[i] for p in pts) for i in range(3)]
        hi = [max(p[i] for p in pts) for i in range(3)]
        if face.normal.z > .85 and hi[2] - lo[2] < .004 and hi[0] - lo[0] > .42 and hi[1] - lo[1] > .20:
            surfaces.append((hi[2], lo[0], hi[0], lo[1], hi[1]))
    # 몰딩·판 두께 때문에 6 cm 안에 겹친 수평면은 가장 높은 하나로 묶는다.
    shelves = []
    for surface in sorted(surfaces):
        if shelves and surface[0] - shelves[-1][0] < .06:
            old = shelves[-1]
            shelves[-1] = (surface[0], min(old[1], surface[1]), max(old[2], surface[2]),
                           min(old[3], surface[3]), max(old[4], surface[4]))
        else:
            shelves.append(surface)
    height = max(v.co.z for v in piece.bm.verts)
    shelves = [s for s in shelves if .035 < s[0] < height - .15]
    if len(shelves) != 6:
        raise ValueError("F-GEOMETRY: 책을 놓을 선반 지지면 확인 필요 " + str(shelves))
    rng = random.Random(BOOK_SEED)
    per_shelf, extra = divmod(18, len(shelves))
    for i, (top, left, right, front, back) in enumerate(shelves):
        ceiling = shelves[i + 1][0] - .045 if i + 1 < len(shelves) else height - .05
        room = ceiling - top
        if room < .14:
            raise ValueError("F-GEOMETRY: 책장 칸 높이 부족")
        left, right = max(left + .055, -.57), min(right - .055, .57)
        count = per_shelf + int(i < extra)
        lying = 1 if count == 3 else 2
        x = left + rng.uniform(.015, .10)
        for _ in range(count - lying):
            width = rng.uniform(.075, .115)
            x_range = (x, x + width) if i % 2 == 0 else (-x - width, -x)
            y = front + rng.uniform(.035, .07)
            add_book(piece, x_range, (y, min(back - .04, y + rng.uniform(.24, .31))),
                     (top + .001, top + room * rng.uniform(.62, .85)), rng.choice(BOOK_COLOURS))
            x += width + rng.uniform(.008, .025)
        z = top + .001
        for _ in range(lying):
            width, thickness = rng.uniform(.23, .31), rng.uniform(.026, .038)
            end = right - rng.uniform(.025, .09)
            x_range = (end - width, end) if i % 2 == 0 else (-end, -end + width)
            y = front + rng.uniform(.04, .08)
            add_book(piece, x_range, (y, min(back - .04, y + .23)), (z, z + thickness),
                     rng.choice(BOOK_COLOURS), lying=True)
            z += thickness


def drawer_chest_spilled(piece):
    """원본 서랍은 SWAPS에서 따로 배치한다. 여기서는 바닥의 무지 종이 네 장만 더한다."""
    for x, y, yaw in ((-.30, -.27, -18), (.30, -.29, 12), (-.28, -.33, 24), (.29, -.34, -10)):
        transform = Matrix.Translation(Vector((x, y, 0))) @ Matrix.Rotation(math.radians(yaw), 4, "Z")
        add_box(piece, (-.05, .05), (-.06, .06), (.002, .004), "paper", 0.0, transform)


def shop_shelf(piece):
    """15상자와 8각 빈 깡통 둘 = 300삼각형. 곧은 네 단 철 진열대."""
    for x in (-1.04, .995):
        add_box(piece, (x, x + .045), (-.25, .25), (0, 1.60), "shelf_blue", 1.0)
    add_box(piece, (-.995, .995), (.23, .25), (.04, 1.60), "shelf_blue", 1.0)
    for z in (.06, .53, 1.00, 1.47):
        add_box(piece, (-.995, .995), (-.235, .23), (z, z + .04), "shelf_blue", 1.0)
        add_box(piece, (-.985, .985), (-.247, -.236), (z + .005, z + .034), "shelf_trim", .5)
    for x, z, height in ((-.73, .10, .23), (.34, .57, .27), (-.22, 1.04, .20), (.50, 1.51, .07)):
        add_box(piece, (x, x + .25), (-.16, .12), (z, z + height), "stock_box", 0.0)
    add_empty_can(piece, .37, -.04, .10)
    add_empty_can(piece, -.65, -.03, 1.04, height=.20)


def office_desk(piece):
    """원본 상판·다리 ≤420 + 서랍 받침 7상자×12 = ≤504삼각형."""
    add_box(piece, (-.60, -.25), (-.285, .29), (.045, .72), "brick", 1.0)
    for i in range(3):
        z = .095 + i * .19
        add_box(piece, (-.59, -.26), (-.31, -.285), (z, z + .165), "brick", 1.0)
        add_box(piece, (-.48, -.37), (-.335, -.31), (z + .065, z + .085), "black_steel", .5)


def toolbox(piece):
    """16상자 = 192삼각형. 속이 빈 몸체와 뒤로 열린 뚜껑, 열린 전체 높이가 .40 m."""
    add_box(piece, (-.19, .19), (-.175, .06), (0, .025), "tool_red", 1.0)
    for x in (-.19, .174):
        add_box(piece, (x, x + .016), (-.175, .06), (.025, .205), "tool_red", 1.0)
    for y in (-.175, .044):
        add_box(piece, (-.174, .174), (y, y + .016), (.025, .205), "tool_red", 1.0)
    lid = Matrix.Translation(Vector((0, .06, .195))) @ Matrix.Rotation(math.radians(-110), 4, "X")
    add_box(piece, (-.19, .19), (-.215, 0), (0, .014), "tool_red", 1.0, lid)
    # 뚜껑 바깥의 검은 쇠 손잡이도 같은 경첩 변환을 쓴다.
    for x in (-.08, .065):
        add_box(piece, (x, x + .015), (-.13, -.11), (.014, .06), "black_steel", .5, lid)
    add_box(piece, (-.08, .08), (-.13, -.11), (.05, .065), "black_steel", .5, lid)
    add_box(piece, (-.162, .162), (-.15, .035), (.125, .14), "steel_dark", .5)
    for x in (-.162, .151):
        add_box(piece, (x, x + .011), (-.15, .035), (.14, .168), "steel_dark", .5)
    add_box(piece, (-.105, -.083), (-.12, -.095), (.14, .31), "wood_worn", 0.0)
    add_box(piece, (-.14, -.05), (-.135, -.08), (.29, .325), "steel_dark", 0.0)
    add_box(piece, (.08, .10), (-.06, -.035), (.14, .29), "wood_dark", 0.0)
    add_box(piece, (.077, .103), (-.065, -.03), (.28, .36), "steel_dark", 0.0)


def iron_bed(piece):
    """칠한 철 침대(머리 판이 발 판보다 높음), 매트리스와 발치 쪽 2/3를 덮은 담요."""
    for x0, top in ((-.95, .98), (.91, .74)):   # 머리 판(-X), 발 판(+X)
        for y in (-.47, .43):
            add_box(piece, (x0, x0 + .04), (y, y + .04), (0, top), "iron", 1.0)
        for z in (top - .05, .40):
            add_box(piece, (x0 + .005, x0 + .035), (-.43, .43), (z, z + .035), "iron", 1.0)
        for i in range(5):
            y = -.32 + i * .16 - .01
            add_box(piece, (x0 + .01, x0 + .03), (y, y + .02), (.435, top - .05), "steel", .5)
    for y in (-.47, .43):
        add_box(piece, (-.91, .91), (y, y + .04), (.30, .36), "iron", 1.0)
    add_box(piece, (-.90, .90), (-.42, .42), (.36, .50), "linen", 0.0)
    add_box(piece, (-.25, .90), (-.45, .45), (.50, .54), "brick", 0.0)   # 바랜 붉은 갈색 담요


def build_piece(pid, spec, src_dir, rect):
    piece, cache = pc.Piece(pid), {}
    for copy in spec["copies"]:
        key = (copy["source"], tuple(copy["parts"]))
        if key not in cache:
            cache[key] = load_part(src_dir, copy["source"], copy["parts"])
        raw, faces = cache[key]
        verts = [v.copy() for v in raw]
        fit(verts, copy["size"])
        turn = Matrix.Rotation(copy["yaw"], 3, "Z") @ Matrix.Rotation(copy["tilt"], 3, "X")
        for v in verts:
            if copy["mirror"]:
                v.x = -v.x
        verts = [turn @ v for v in verts]
        bottom = min(v.z for v in verts)
        made = [piece.bm.verts.new(v + Vector((copy["x"], -copy["z"], copy["bottom"] - bottom))) for v in verts]
        for idx, cols, mask in faces:
            if copy["mirror"]:
                idx, cols = list(reversed(idx)), list(reversed(cols))
            try:
                face = piece.bm.faces.new([made[i] for i in idx])
            except ValueError:   # 면 줄이기가 남긴 겹친 면(같은 꼭짓점 묶음)은 한 번만
                continue
            for loop, rgb in zip(face.loops, cols):
                loop[piece.col] = tint(rgb, spec["paint"], mask)
    builders = {"workbench": workbench, "bookcase": bookcase, "drawer_chest_spilled": drawer_chest_spilled,
                "shop_shelf": shop_shelf, "toolbox": toolbox, "office_desk": office_desk, "iron_bed": iron_bed}
    if pid in builders:
        builders[pid](piece)
    if pid in BODY_PRESS:
        for face in piece.bm.faces:
            for loop in face.loops:
                loop[piece.col] = press_body(loop[piece.col], pid)
    if pid == "drawer_chest_spilled":
        # 최종 fit으로 돌출을 숨기지 않는다. 원본 부품·종이 모두 예정 발자국 안이어야 한다.
        if any(abs(v.co.x) > spec["size"][0] / 2 + 1e-5 or abs(v.co.y) > spec["size"][2] / 2 + 1e-5
               for v in piece.bm.verts):
            raise ValueError("F-BOUNDS: 쏟아진 서랍·종이가 .90×.86 m 밖")
    piece.colours.add(spec["paint"])
    bmesh.ops.delete(piece.bm, geom=[v for v in piece.bm.verts if not v.link_faces], context="VERTS")
    size = [min(spec["size"][0], rect[0] * MARGIN), spec["size"][1], min(spec["size"][2], rect[1] * MARGIN)]
    fit([v.co for v in piece.bm.verts], size)
    bmesh.ops.triangulate(piece.bm, faces=list(piece.bm.faces))
    piece.bm.normal_update()
    for face in piece.bm.faces:
        face.smooth = False
        face.material_index = 0
    return piece


def bounds_godot(bm):
    lo = [min(v.co[i] for v in bm.verts) for i in range(3)]
    hi = [max(v.co[i] for v in bm.verts) for i in range(3)]
    return [[lo[0], lo[2], -hi[1]], [hi[0], hi[2], -lo[1]]]


def census(repo):
    """지도 정적 kind+rect 리터럴만 센다. facing·동적 방 꾸미기·cell 수납은 추정해 더하지 않는다."""
    kinds = (repo / "s2/game/world/prop_kinds.gd").read_text(encoding="utf-8")
    aliases = {kind: pid for kind, pid in re.findall(r'"([^"\n]+)"\s*:\s*STOP_DIR\s*\+\s*"([^"/]+)\.glb"', kinds)
               if pid in SWAPS}
    files = sorted((repo / "s2/game/world/maps").glob("*.gd")) + [repo / "s2/game/world/sulehuf_map.gd"]
    counts = {pid: Counter() for pid in SWAPS}
    maps, by_kind = {pid: set() for pid in SWAPS}, {pid: Counter() for pid in SWAPS}
    for path in files:
        # 행 끝 주석은 집계에서 제외(문자열 안의 #은 보존).
        text = re.sub(r'("(?:\\.|[^"\\])*"|#[^\n]*)', lambda m: "" if m[0].startswith("#") else m[0],
                      path.read_text(encoding="utf-8"))
        for row in re.findall(r"\{[^{}]*\}", text):
            kind = re.search(r'"kind"\s*:\s*"([^"\n]+)"', row)
            rect = re.search(r'"rect"\s*:\s*(?:\[|Rect2i\()\s*-?\d+\s*,\s*-?\d+\s*,\s*(\d+)\s*,\s*(\d+)', row)
            if kind is None or rect is None or kind[1] not in aliases:
                continue
            pid = aliases[kind[1]]
            counts[pid][(int(rect[1]), int(rect[2]))] += 1
            maps[pid].add(path.name)
            by_kind[pid][kind[1]] += 1
    result = {}
    for pid, count in counts.items():
        # 동률이면 작은 면적, 그다음 x,z 순. 관측 0을 최빈값처럼 쓰지 않는다.
        modal = min(count, key=lambda r: (-count[r], r[0] * r[1], r)) if count else None
        rect = list(modal) if modal else SWAPS[pid].get("rect_fallback")
        if rect is None:
            raise ValueError("F-INPUT-MISSING: rect 표본도 가정값도 없음 " + pid)
        result[pid] = dict(rect_modal=list(modal) if modal else None, rect_fit_m=rect,
                           rect_modal_count=count[modal] if modal else 0, rect_samples=sum(count.values()),
                           rect_histogram={"%dx%d" % r: n for r, n in sorted(count.items())},
                           kind_counts=dict(sorted(by_kind[pid].items())), map_count=len(maps[pid]),
                           rect_basis="observed_static_literals" if modal else "assumed_no_rect_samples")
    return result, len(files)


def read_glb(path):
    data = path.read_bytes()
    if len(data) < 20 or struct.unpack_from("<4sII", data) != (b"glTF", 2, len(data)):
        raise ValueError("F-GLB: 머리 " + str(path))
    offset, book, binary = 12, None, b""
    while offset < len(data):
        length, kind = struct.unpack_from("<II", data, offset)
        start, offset = offset + 8, offset + 8 + length
        if offset > len(data):
            raise ValueError("F-GLB: 청크 경계 " + str(path))
        if kind == 0x4E4F534A:
            book = json.loads(data[start:offset])
        elif kind == 0x004E4942:
            binary = data[start:offset]
    if book is None:
        raise ValueError("F-GLB: JSON 없음 " + str(path))
    return book, binary, data


def before_receipt(path):
    book, _, raw = read_glb(path)
    lod0 = {n["mesh"] for n in book.get("nodes", []) if "mesh" in n and n.get("name", "").upper().endswith("_LOD0")}
    if not lod0 and len(book.get("meshes", [])) == 1:
        lod0 = {0}
    if not lod0 or not book.get("textures"):
        raise ValueError("F-BASELINE-MISSING: 트리포 이전 값 또는 기존 장부 before 필요 " + str(path))
    tris = 0
    for index in lod0:
        for primitive in book["meshes"][index]["primitives"]:
            if primitive.get("mode", 4) != 4:
                raise ValueError("F-GLB: 이전 모형이 삼각형이 아님")
            accessor = primitive.get("indices", primitive["attributes"]["POSITION"])
            count = book["accessors"][accessor]["count"]
            if count % 3:
                raise ValueError("F-GLB: 이전 삼각형 수")
            tris += count // 3
    return dict(lod0_tris=tris, bytes=len(raw), sha256=hashlib.sha256(raw).hexdigest(),
                materials=len(book.get("materials", [])), textures=len(book.get("textures", [])))


def read_accessor(book, binary, index):
    accessor = book["accessors"][index]
    view = book["bufferViews"][accessor["bufferView"]]
    if "sparse" in accessor or view.get("buffer", 0) != 0:
        raise ValueError("F-GLB: 지원하지 않는 accessor")
    components = {"SCALAR": 1, "VEC3": 3, "VEC4": 4}[accessor["type"]]
    code, unit = {5121: ("B", 255), 5123: ("H", 65535), 5125: ("I", 4294967295), 5126: ("f", 1)}[accessor["componentType"]]
    layout = "<" + code * components
    stride = view.get("byteStride", struct.calcsize(layout))
    start = view.get("byteOffset", 0) + accessor.get("byteOffset", 0)
    values = [struct.unpack_from(layout, binary, start + i * stride) for i in range(accessor["count"])]
    if accessor.get("normalized", False):
        values = [tuple(v / unit for v in row) for row in values]
    return values


def mask_counts(alphas):
    counts = Counter({name: 0 for name in MASKS})
    for alpha in alphas:
        name = min(MASKS, key=lambda key: abs(alpha - MASKS[key]))
        # Blender의 VEC4 정점색은 정규화 정수일 수 있어 .5가 128/255가 된다.
        if abs(alpha - MASKS[name]) > 1 / 255 + 1e-6:
            raise ValueError("F-MASK: 0/.5/1 이외 알파 " + str(alpha))
        counts[name] += 1
    return dict(counts)


def check_output(path, piece, rect):
    tris = len(piece.bm.faces)
    budget = TRIANGLE_BUDGETS.get(piece.pid, TRIANGLE_LIMIT)
    if not 0 < tris <= budget:
        raise ValueError("F-BUDGET: %s 삼각형 %d > %d" % (piece.pid, tris, budget))
    size, sha = pc.check_glb(str(path), tris)
    book, binary, _ = read_glb(path)
    primitive = book["meshes"][0]["primitives"][0]
    attrs = primitive["attributes"]
    if "material" in primitive or any(k.startswith("TEXCOORD_") for k in attrs):
        raise ValueError("F-GLB: 재질 또는 UV")
    for node in book.get("nodes", []):
        if "mesh" in node and any(k in node for k in ("matrix", "translation", "rotation", "scale")):
            raise ValueError("F-GLB: 원점 바깥 노드 변환")
    colour = book["accessors"][attrs["COLOR_0"]]
    if colour["type"] != "VEC4":
        raise ValueError("F-MASK: COLOR_0 알파가 빠짐")
    colours = read_accessor(book, binary, attrs["COLOR_0"])
    positions = read_accessor(book, binary, attrs["POSITION"])
    if len(colours) != len(positions):
        raise ValueError("F-GLB: 위치·색 꼭짓점 수 불일치")
    indices = [row[0] for row in read_accessor(book, binary, primitive["indices"])]
    actual_mask = mask_counts(colours[i][3] for i in indices)
    expected_mask = mask_counts(loop[piece.col][3] for face in piece.bm.faces for loop in face.loops)
    if actual_mask != expected_mask:
        raise ValueError("F-MASK: 내보낸 알파 비율 불일치")
    bounds = [[min(v[i] for v in positions) for i in range(3)], [max(v[i] for v in positions) for i in range(3)]]
    intended = bounds_godot(piece.bm)
    if max(abs(a - b) for row, other in zip(bounds, intended) for a, b in zip(row, other)) > 1e-4:
        raise ValueError("F-BOUNDS: Blender와 GLB 경계 불일치")
    lo, hi = bounds
    if hi[0] - lo[0] > rect[0] * MARGIN + 1e-5 or hi[2] - lo[2] > rect[1] * MARGIN + 1e-5:
        raise ValueError("F-BOUNDS: rect 96% 바깥")
    height = hi[1] - lo[1]
    if not .3 <= height <= 2.1 or abs(lo[1]) > 1e-5 or max(abs(lo[i] + hi[i]) for i in (0, 2)) > 1e-5:
        raise ValueError("F-BOUNDS: 높이 또는 바닥 가운데 원점")
    return dict(lod0_tris=tris, bytes=size, sha256=sha, bounds_m=bounds, height_m=height,
                mask_counts=actual_mask, mask_ratio={name: count / len(indices) for name, count in actual_mask.items()},
                mask_basis="indexed_triangle_corners", mask_alpha_verified=True)


def check_sources(src_dir, selected):
    """입력 전용 구조 사본으로 굽지 않는다. 선택한 원본의 bin·질감까지 먼저 확인한다. 다운로드 없음."""
    expected = {}
    for pid in selected:
        for copy in SWAPS[pid]["copies"]:
            expected.setdefault(copy["source"], set()).update(p[0] for p in copy["parts"])
    for source, names in expected.items():
        root = (src_dir / source).resolve()
        path = root / (source + "_1k.gltf")
        if not path.is_file():
            raise ValueError("F-INPUT-MISSING: " + str(path))
        doc = json.loads(path.read_text(encoding="utf-8"))
        present = {node.get("name") for node in doc.get("nodes", []) if "mesh" in node}
        if names - present:
            raise ValueError("F-INPUT-MISSING: " + source + " " + str(sorted(names - present)))
        # 정점색에는 바탕색 질감만 읽는다: .bin과 바탕색 그림만 꼭 있어야 한다(법선·거칠기 질감은 없어도 됨).
        textures = doc.get("textures", [])
        base = {int(textures[int(m["pbrMetallicRoughness"]["baseColorTexture"]["index"])]["source"])
                for m in doc.get("materials", []) if "baseColorTexture" in m.get("pbrMetallicRoughness", {})}
        images = [img for i, img in enumerate(doc.get("images", [])) if i in base]
        for resource in doc.get("buffers", []) + images:
            uri = resource.get("uri", "")
            if uri.startswith("data:") or not uri:
                continue
            target = (root / uri).resolve()
            if ":" in uri or not target.is_relative_to(root) or not target.is_file():
                raise ValueError("F-INPUT-MISSING: 원본 옆 .bin·질감 " + uri)


def source_metadata(pid):
    """단일 출처는 문자열, 혼합 출처는 두 문자열의 배열. 원본 id와 자체 조형을 섞지 않는다."""
    spec, source_objects = SWAPS[pid], {}
    for copy in spec["copies"]:
        source_objects.setdefault(copy["source"], set()).update(part[0] for part in copy["parts"])
    sources = (["poly_haven"] if source_objects else []) + (["blender_primitives"] if pid in PRIMITIVE_PARTS else [])
    return dict(source=sources[0] if len(sources) == 1 else sources,
                source_ids=sorted(source_objects),
                source_objects={source: sorted(names) for source, names in source_objects.items()},
                primitive_parts=PRIMITIVE_PARTS.get(pid, []),
                size_m=spec["size"], chosen_size_m=spec["size"],
                body_press=BODY_PRESS.get(pid),
                triangle_limit=TRIANGLE_BUDGETS.get(pid, TRIANGLE_LIMIT),
                triangle_estimate_max=sum(part[1] for copy in spec["copies"] for part in copy["parts"])
                                      + PRIMITIVE_TRIANGLES.get(pid, 0),
                note=spec["note"])


def write_books(out_dir, book):
    book["missing"] = sorted(set(SWAPS) - set(book["assets"]))
    book["pending"] = sorted(pid for pid, row in book["assets"].items() if row.get("bake_status") == "pending")
    book["complete"] = not book["missing"] and not book["pending"]
    book["bake_status"] = "pending" if book["pending"] else ("partial" if book["missing"] else "baked")
    (out_dir / "catalog_cc0.json").write_text(json.dumps(book, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    lines = ["# 첫 정차 가구 CC0 교체 — 2차", "", "이 표는 `%s`의 조형 계획과 굽기 장부를 함께 기록한다. 날짜 %s." % (SCRIPT, DATE), "",
             "`bake_status: baked`인 행만 실제 GLB 측정값이다. `pending`은 2차 재굽기 전이며 면 수·바이트·해시는 null이다.",
             "기존 GLB는 그대로 두고 1차 출처·측정값을 `previous_bake`에 보존한다. 최초 트리포 `before`도 유지한다.",
             "`source`는 `poly_haven` 또는 `blender_primitives`, 혼합은 두 값의 배열이다. pending 행의 출처는 2차 계획이다.", "",
             "전: 최초 교체 직전 트리포 GLB의 LOD0 accessor count·파일 전체 바이트. 재실행해도 before를 보존한다.",
             "후: 단일 메시·surface·LOD0, UV·재질·질감 없음, 각진 음영, 선형 Col. 치수는 x×y(높이)×z m.", "",
             "rect는 maps/*.gd와 sulehuf_map.gd %d개 파일의 정적 kind+rect 리터럴 집계(별칭 합산)." % book["census_file_count"],
             "facing으로 rect를 돌리지 않으며 동적 방 배치·cell 수납은 포함하지 않는다. 최빈값 없는 항목은 가정을 따로 표시한다.",
             "sulehuf의 가구 수납은 cell만 있어 rect 표본이 없다. 침대는 긴 축을 X에 둔다.", "",
             "| 이름 | 출처 / 자체 조형 | 삼각형 트리포→2차 | 예산 추정 상한 / 제한 | 바이트 트리포→2차 | rect 최빈(빈도/표본) | 크기 x×y×z m |",
             "|---|---|---:|---:|---:|---|---|"]
    for pid in SWAPS:
        if pid not in book["assets"]:
            continue
        row = book["assets"][pid]
        before = row["before"]
        source = "; ".join(row["source_ids"])
        if row.get("primitive_parts"):
            source += (" + " if source else "") + "Blender 기본 도형: " + ", ".join(row["primitive_parts"])
        rect = "%d×%d (%d/%d)" % (*row["rect_modal"], row["rect_modal_count"], row["rect_samples"]) if row["rect_modal"] else "없음(0); 가정 %d×%d" % tuple(row["rect_fit_m"])
        pending = row.get("bake_status") == "pending"
        after_tris, after_bytes = ("not_run", "not_run") if pending else (str(row["lod0_tris"]), str(row["bytes"]))
        size = row["size_m"] if pending else [row["bounds_m"][1][i] - row["bounds_m"][0][i] for i in range(3)]
        lines.append("| `%s` | %s | %d→%s | %d / %d | %d→%s | %s | %.2f×%.2f×%.2f%s |" %
                     (pid, source + (" (계획)" if pending else ""), before["lod0_tris"], after_tris,
                      row["triangle_estimate_max"], row["triangle_limit"], before["bytes"], after_bytes, rect,
                      *size, " (예정)" if pending else ""))
    lines += ["", "미생성: " + (", ".join(book["missing"]) or "없음"),
              "재굽기 대기: " + (", ".join(book["pending"]) or "없음"), "", "## 가정·확인 범위", "",
              "- Poly Haven CC0 1.0은 발주에서 제공한 출처 조건이다. 이번 작성에서 네트워크 재확인은 하지 않았다.",
              "- 원본 앞은 glTF +Z로 가정. 원본 노드 변환은 보존한다. 두 문 옷장·매트리스·테두리 마스크는 실제 화면 검수 필요.",
              "- mask_ratio는 삼각형 코너 수 비율. Col.a 몸체 1 / 테두리·손잡이·쇠붙이 .5 / 책·종이·상품·공구·천 0. 원본 의미 구분은 연결 부품·판 두께에 따른 추정이다.",
              "- props_common.export의 ACTIVE 정점색과 재질 NONE 조합은 Blender 4.5에서 COLOR_0 VEC4 알파를 보존한다. .5는 정규화 정수로 반올림될 수 있다.",
              "- baked 행의 알파·경계·예산·SHA만 출력 바이트와 대조한다. pending 행의 GLB는 아직 1차 결과다. Godot 가져오기·GUT·시각 검사는 not_run.",
              "- shelf·desk·bed·file_cabinet·tool_chest는 prop_kinds.gd에서 기존 공용 GLB가 우선한다. 첫 정차 BY_ID/BY_SUFFIX·직접 stop01 참조와 구분해야 한다.",
              "- --out 결과는 검수용이며 res:// 경로로 자동 설치하지 않는다. --only는 기존 장부의 다른 항목을 보존한다.", ""]
    lines += ["## 칠 판과 셰이더 칠 칸", "",
              "`res://game/world/furniture_tints.gd`는 body·trim 두 sRGB 색을 가진 4판이다. 모든 색은 HSV 채도 <0.45, 밝기 <0.75다.",
              "`pick(row, cell)`은 tint 번호의 양의 나머지 → building 번호 해시 → 둘 다 없을 때 cell 해시 순서다. 해시는 PCG로 섞은 뒤 판을 고른다(`roll`). 같은 건물은 같은 판을 고른다.",
              "`dress()`가 색을 `srgb_to_linear()`로 바꿔 재질 값 tint_sets_body·tint_sets_trim에 넣고, 판 번호 + 1은 MultiMesh 사용자 자료로 간다. a는 각각의 세기다.",
              "정점 알파 ≥0.75는 몸체, 0.25≤알파<0.75는 테두리, 나머지는 보존한다. use_vertex_color일 때만 적용한다.",
              "칠 밝기는 판 밝기 × (모형 몸체·테두리 평균 밝기 tint_ref / 0.18)^0.25이고 테두리는 몸체의 0.5~1배다(paint_ref, TINT_KEEP). 결은 바탕 밝기 / 평균 비(0~1.6)로 남고, 칠이 남긴 바탕도 같은 밝기로 맞춘다. 판 번호가 없으면 기존 경로가 그대로다.",
              "지도·room_*.gd·map_view.gd·prop_fit.gd·prop_models.gd 연결은 이 작업 범위 밖이다. 이 체크아웃의 room_furnish에는 TINT_SETS가 없다.", "",
              "## 몸체 색 누르기", "",
              "기존 코드가 원본색을 그대로 복사하지 않고 tint()로 지정 색에 맞추므로, 현재 칠 결과의 sRGB HSV를 기준으로 누른다.",
              "선형 Col을 sRGB로 바꿔 채도·명도에 아래 비율을 곱한 뒤 선형으로 돌린다. alpha ≥0.75인 몸체만 적용하며 trim·keep는 보존한다.",
              "장부 body_press_basis: `" + BODY_PRESS_BASIS + "`. 게임의 기존 색 보정·날씨는 이 굽기 조정 뒤에 적용된다.", "",
              "| 종 | 채도 배수 | 명도 배수 |", "|---|---:|---:|"]
    lines.extend("| %s | %.2f | %.2f |" % (pid, knobs["saturation"], knobs["value"]) for pid, knobs in BODY_PRESS.items())
    lines += ["", "## 2차 조형", ""]
    lines.extend("- `%s`: %s" % (pid, row["note"]) for pid, row in book["assets"].items())
    (out_dir / "README_cc0.md").write_text("\n".join(lines) + "\n", encoding="utf-8")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--repo", required=True)
    parser.add_argument("--src", required=True)
    parser.add_argument("--out", default="")
    parser.add_argument("--only", default="")
    args = parser.parse_args(sys.argv[sys.argv.index("--") + 1:])
    repo, src_dir = Path(args.repo).resolve(), Path(args.src).resolve()
    canonical = repo / "s2/models/props_stop01"
    out_dir = Path(args.out).resolve() if args.out else canonical
    selected = list(dict.fromkeys(part.strip() for part in args.only.split(",") if part.strip())) if args.only else list(SWAPS)
    if not selected or set(selected) - set(SWAPS):
        raise ValueError("F-INPUT-MISSING: --only 이름 " + args.only)
    check_sources(src_dir, selected)
    sizes, file_count = census(repo)
    book_path = out_dir / "catalog_cc0.json"
    book = json.loads(book_path.read_text(encoding="utf-8")) if book_path.exists() else {"assets": {}}
    if set(book["assets"]) - set(SWAPS):
        raise ValueError("F-CATALOG: 다른 묶음의 장부")
    before = {}
    for pid, row in book["assets"].items():
        path = out_dir / (pid + ".glb")
        current = row["previous_bake"] if row.get("bake_status") == "pending" else row
        if not path.is_file() or hashlib.sha256(path.read_bytes()).hexdigest() != current["sha256"]:
            raise ValueError("F-CATALOG: 기존 파일과 장부 불일치 " + pid)
    canonical_book_path = canonical / "catalog_cc0.json"
    canonical_assets = json.loads(canonical_book_path.read_text(encoding="utf-8"))["assets"] if canonical_book_path.exists() else {}
    for pid in selected:
        # --out에서도 기존 게임 파일을 '전'으로 읽는다. 부분 실행·재실행은 최초 영수증 유지.
        previous = book["assets"].get(pid, canonical_assets.get(pid))
        before[pid] = previous["before"] if previous else before_receipt(canonical / (pid + ".glb"))
    book.update(schema_version=1, date=DATE, source_script=SCRIPT, triangle_limit=TRIANGLE_LIMIT,
                recipe_revision=2, triangle_budgets=TRIANGLE_BUDGETS, book_seed=BOOK_SEED,
                body_press=BODY_PRESS, body_press_basis=BODY_PRESS_BASIS, import_check="not_run",
                census_file_count=file_count, grade=GRADE, graded_targets=GRADED_TARGETS,
                mask_values=MASKS, staged=out_dir != canonical, godot_test="not_run", visual_check="not_run")
    out_dir.mkdir(parents=True, exist_ok=True)
    # 현재 GLB는 새 GLB 검사에 성공한 뒤에만 바꾼다. 임시 파일은 자동 정리한다.
    with tempfile.TemporaryDirectory(prefix="props_stop01_cc0_") as temp:
        for pid in selected:
            spec, rect = SWAPS[pid], sizes[pid]["rect_fit_m"]
            final = out_dir / (pid + ".glb")
            old_bytes = final.read_bytes() if final.exists() else None
            piece = build_piece(pid, spec, src_dir, rect)
            try:
                candidate = Path(temp) / (pid + ".glb")
                pc.export(piece, str(candidate))
                receipt = check_output(candidate, piece, rect)
                row = dict(path="res://models/props_stop01/%s.glb" % pid, **source_metadata(pid),
                           before=before[pid], bake_status="baked", recipe_revision=2,
                           source_script=SCRIPT, **sizes[pid], **receipt)
                if (final.read_bytes() if final.exists() else None) != old_bytes:
                    raise ValueError("F-CONCURRENT-EDIT: 굽는 동안 파일 변경 " + pid)
                final.write_bytes(candidate.read_bytes())
                book["assets"][pid] = row
                write_books(out_dir, book)
                print("CC0 %s tris %d bytes %d sha256 %s" % (pid, row["lod0_tris"], row["bytes"], row["sha256"]))
            finally:
                piece.bm.free()


if __name__ == "__main__":
    main()
