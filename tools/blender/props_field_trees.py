"""숲 모형: Quaternius 소나무/자작나무 + 기존 Kenney 밑 덮개. Blender 4.5.

blender -b --factory-startup --python-exit-code 1 -P tools/blender/props_field_trees.py -- --repo . --src <Kenney GLTF 폴더> [--src-quaternius <Quaternius FBX 폴더>]

원본은 저장소 밖에 둔다. 눈 없는 PineTree_1~3을 줄여 짙은 바늘잎으로 칠하고,
눈 짝은 완성 BMesh를 복사해 윗면 색만 바꾼다. 자작나무는 Snow 면을 제거한다.
모든 예산을 통과한 뒤 기존 이름/경로에 GLB와 장부/README를 쓴다.
"""
import sys
sys.dont_write_bytecode = True

import argparse
import hashlib
import json
import math
from pathlib import Path

import bmesh
import bpy
from mathutils import Matrix, Vector

sys.path.insert(0, str(Path(__file__).resolve().parent))
import props_common as pc  # noqa: E402

DEFAULT_QUATERNIUS = r"C:\dev\zombie\assets_raw\quaternius_nature\fbx"
# 선형 RGB. Y = 0.2126 R + 0.7152 G + 0.0722 B, jitter 뒤에도 바늘잎 Y 0.04~0.08.
COLOURS = {
    "needle": (0.035, 0.064, 0.058),
    "needle_dark": (0.028, 0.055, 0.050),
    "bark": (0.075, 0.060, 0.050),
    "birch": (0.60, 0.60, 0.56),
    "birch_mark": (0.07, 0.07, 0.065),
    "juniper": (0.07, 0.10, 0.08),
    "dry_leaf": (0.26, 0.15, 0.08),
    "fern": (0.33, 0.20, 0.09),
    "snow": pc.PALETTE["snow"][:3],
}
MATERIAL_COLOUR = {"leafsDark": "needle", "leafsGreen": "needle", "grass": "juniper",
                   "woodBarkDark": "bark", "woodBark": "bark", "_defaultMat": "bark"}
QUATERNIUS_COLOUR = {"wood": "bark", "green": "needle", "darkgreen": "needle_dark",
                     "white": "birch", "black": "birch_mark", "snow": "snow"}
SEMANTICS = ("bark", "needle", "needle_dark", "birch", "birch_mark", "snow")
NEEDLE_SLOTS = {SEMANTICS.index("needle"), SEMANTICS.index("needle_dark")}
# 눈은 윗면을 보는 바늘잎 가운데 일부(SNOW_SHARE)에만 덩어리로: 다 덮으면 나무가 눈 덮인 땅보다 밝아진다.
# 0.4·0.85에서는 눈 짝 무리의 흑백 평균이 맨땅보다 밝았다(lodge_01 낮 0.43 > 0.39, 10-29).
SNOW_FROM, SNOW_FULL, SNOW, SNOW_SHARE = 0.55, 0.85, 0.8, 0.22
JITTER = 0.12
TREES = {
    "spruce_tall": {"source": "PineTree_2", "height": 11.0, "snow": True, "min": 400, "limit": 600,
                    "target": 520, "layers": 4, "keep_layers": 4, "width_scale": 0.82, "needle": "needle_dark"},
    "spruce_mid": {"source": "PineTree_3", "height": 7.5, "snow": True, "min": 400, "limit": 600,
                   "target": 520, "layers": 6, "keep_layers": 6, "width_scale": 0.90, "needle": "needle"},
    "spruce_round": {"source": "PineTree_1", "height": 6.0, "snow": True, "min": 400, "limit": 600,
                     "target": 520, "layers": 5, "keep_layers": 5, "width_scale": 1.10, "needle": "needle"},
    "spruce_young": {"source": "PineTree_1", "height": 2.6, "snow": True, "min": 200, "limit": 400,
                     "target": 300, "layers": 5, "keep_layers": 3, "width_scale": 0.90,
                     "stem_compress": 0.35, "needle": "needle"},
    "spruce_far": {"source": "PineTree_2", "height": 9.0, "snow": True, "min": 80, "limit": 100,
                   "target": 96, "layers": 4, "keep_layers": 4, "width_scale": 0.82,
                   "fallback_layers": 1, "needle": "needle_dark"},
    # 이 셋의 원본/키/색/삼각형 처리와 jitter seed는 이전 Kenney 경로를 유지한다.
    "bush_juniper": {"source": "tree_pineGroundA", "height": 1.1, "snow": False, "limit": 200, "recolour": {"needle": "juniper"}},
    "bush_dry": {"source": "plant_bushDetailed", "height": 0.9, "snow": False, "limit": 200, "recolour": {"juniper": "dry_leaf"}},
    "fern_dry": {"source": "plant_bushLargeTriangle", "height": 0.6, "snow": False, "limit": 200, "recolour": {"juniper": "fern"}},
}
BIRCH = {"source": "BirchTree_Dead_Snow_1", "height": 7.0, "snow": False, "min": 1, "limit": 599, "target": 520}


def luminance(rgb):
    return sum(c * w for c, w in zip(rgb, (0.2126, 0.7152, 0.0722)))


def jitter(seed_text, i):
    h = hashlib.md5(("%s:%d" % (seed_text, i)).encode()).digest()
    return 1.0 + JITTER * (h[0] / 127.5 - 1.0)


def load_source(src_dir, name):
    """기존 Kenney GLB 경로: 밑 덮개 셋은 같은 순서와 색으로 만든다."""
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=str(src_dir / (name + ".glb")))
    meshes = [o for o in bpy.context.scene.objects if o.type == "MESH"]
    bpy.ops.object.select_all(action="DESELECT")
    for o in meshes:
        o.select_set(True)
    bpy.context.view_layer.objects.active = meshes[0]
    if len(meshes) > 1:
        bpy.ops.object.join()
    obj = bpy.context.view_layer.objects.active
    obj.parent = None
    obj.data.transform(obj.matrix_world)
    obj.matrix_world = Matrix.Identity(4)
    return obj


def colour_of(obj, poly, recolour):
    mat = obj.material_slots[poly.material_index].material if obj.material_slots else None
    name = MATERIAL_COLOUR.get(mat.name.split(".")[0] if mat else "", "bark")
    return recolour.get(name, name)


def build_kenney(pid, spec, src_dir):
    obj = load_source(src_dir, spec["source"])
    mesh = obj.data
    lo = Vector([min(v.co[i] for v in mesh.vertices) for i in range(3)])
    hi = Vector([max(v.co[i] for v in mesh.vertices) for i in range(3)])
    s = spec["height"] / (hi.z - lo.z)
    centre = Vector(((lo.x + hi.x) / 2, (lo.y + hi.y) / 2, lo.z))
    piece = pc.Piece(pid)
    made = [piece.bm.verts.new((v.co - centre) * s) for v in mesh.vertices]
    for i, poly in enumerate(mesh.polygons):
        if poly.area < 1e-12:
            continue
        name = colour_of(obj, poly, spec.get("recolour", {}))
        # 기존 Kenney 껍질은 공용 팔레트 그대로. 새 소나무 bark와 분리한다.
        base = pc.PALETTE["bark"][:3] if name == "bark" else COLOURS[name]
        rgb = [c * jitter(pid, i) for c in base]
        try:
            face = piece.bm.faces.new([made[k] for k in poly.vertices])
        except ValueError:
            continue
        face.smooth = False
        for loop in face.loops:
            loop[piece.col] = rgb + [1.0]
        piece.colours.add(name)
    bmesh.ops.remove_doubles(piece.bm, verts=list(piece.bm.verts), dist=1e-6)
    bmesh.ops.triangulate(piece.bm, faces=list(piece.bm.faces))
    return piece


def load_quaternius(src_dir, source):
    """가로수 도구처럼 세계 좌표로 합치되 색 역할을 면 재질 번호로 보존한다."""
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.fbx(filepath=str(src_dir / (source + ".fbx")))
    bm = bmesh.new()
    for obj in [o for o in bpy.context.scene.objects if o.type == "MESH"]:
        mapping = {}
        for i, slot in enumerate(obj.material_slots):
            name = slot.material.name.split(".")[0].lower() if slot.material else ""
            if name not in QUATERNIUS_COLOUR:
                raise ValueError("%s: 미확인 Quaternius 재질 %r" % (source, name))
            mapping[i] = SEMANTICS.index(QUATERNIUS_COLOUR[name])
        part = bmesh.new()
        part.from_mesh(obj.data)
        part.transform(obj.matrix_world)
        for face in part.faces:
            face.material_index = mapping[face.material_index]
        tmp = bpy.data.meshes.new("tree_part")
        part.to_mesh(tmp)
        part.free()
        bm.from_mesh(tmp)
        bpy.data.meshes.remove(tmp)
    snow_faces = [f for f in bm.faces if f.material_index == SEMANTICS.index("snow")]
    bmesh.ops.delete(bm, geom=snow_faces, context="FACES")
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context="VERTS")
    if not bm.faces:
        raise ValueError("%s: 눈 제거 뒤 빈 메시" % source)
    for obj in list(bpy.context.scene.objects):
        bpy.data.objects.remove(obj, do_unlink=True)
    mesh = bpy.data.meshes.new("tree_source")
    bm.to_mesh(mesh)
    bm.free()
    obj = bpy.data.objects.new("tree_source", mesh)
    bpy.context.scene.collection.objects.link(obj)
    for name in SEMANTICS:
        mesh.materials.append(bpy.data.materials.new(name))
    return obj


def needle_layers(bm):
    """연결된 바늘잎 면 묶음을 가지 층으로 보고 낮은 층부터 정렬한다."""
    unseen = {f for f in bm.faces if f.material_index in NEEDLE_SLOTS}
    layers = []
    while unseen:
        seed = unseen.pop()
        group, stack = {seed}, [seed]
        while stack:
            face = stack.pop()
            for edge in face.edges:
                for other in edge.link_faces:
                    if other in unseen:
                        unseen.remove(other)
                        group.add(other)
                        stack.append(other)
        layers.append(group)
    return sorted(layers, key=lambda group: min(v.co.z for f in group for v in f.verts))


def keep_top_layers(obj, count, expected, stem_compress=1.0):
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    layers = needle_layers(bm)
    if len(layers) != expected:
        raise ValueError("바늘잎 층 %d != 원본 계약 %d" % (len(layers), expected))
    discarded = [f for layer in layers[:-count] for f in layer]
    bmesh.ops.delete(bm, geom=discarded, context="FACES")
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context="VERTS")
    if stem_compress != 1.0:
        bottom = min(v.co.z for v in bm.verts)
        crown = min(v.co.z for layer in layers[-count:] for f in layer for v in f.verts)
        shortening = (crown - bottom) * (1.0 - stem_compress)
        for v in bm.verts:
            v.co.z = bottom + (v.co.z - bottom) * stem_compress if v.co.z < crown else v.co.z - shortening
    bm.to_mesh(obj.data)
    bm.free()


def triangle_count(obj):
    return sum(len(p.vertices) - 2 for p in obj.data.polygons)


def semantic_shape_ok(obj, layers):
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    slots = {f.material_index for f in bm.faces}
    if layers:
        ok = len(needle_layers(bm)) == layers and SEMANTICS.index("bark") in slots
    else:
        ok = {SEMANTICS.index("birch"), SEMANTICS.index("birch_mark")}.issubset(slots)
    bm.free()
    return ok


def replace_mesh(obj, mesh):
    old = obj.data
    obj.data = mesh
    bpy.data.meshes.remove(old)


def decimate(obj, spec, layers):
    """먼저 평면 줄이기. 하한 미달이면 되돌리고 동일 원본에서 비율을 탐색한다."""
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    original = obj.data.copy()
    mod = obj.modifiers.new("tree_planar", "DECIMATE")
    mod.decimate_type = "DISSOLVE"
    mod.angle_limit = math.radians(1.0)
    mod.delimit = {"MATERIAL"}
    bpy.ops.object.modifier_apply(modifier=mod.name)
    if triangle_count(obj) < spec["min"] or not semantic_shape_ok(obj, layers):
        replace_mesh(obj, original)
    else:
        bpy.data.meshes.remove(original)
    tris = triangle_count(obj)
    if spec["min"] <= tris <= spec["limit"] and semantic_shape_ok(obj, layers):
        return True
    base = obj.data.copy()
    low, high = 0.0, 1.0
    ratio = min(1.0, spec["target"] / max(1, tris))
    for _ in range(12):
        replace_mesh(obj, base.copy())
        mod = obj.modifiers.new("tree_collapse", "DECIMATE")
        mod.decimate_type = "COLLAPSE"
        mod.ratio = ratio
        mod.use_collapse_triangulate = True
        bpy.ops.object.modifier_apply(modifier=mod.name)
        count = triangle_count(obj)
        shape_ok = semantic_shape_ok(obj, layers)
        if spec["min"] <= count <= spec["limit"] and shape_ok:
            bpy.data.meshes.remove(base)
            return True
        if count < spec["min"] or not shape_ok:
            low = ratio
        else:
            high = ratio
        ratio = (low + high) / 2
    replace_mesh(obj, base)
    return False


def build_quaternius(pid, spec, src_dir):
    obj = load_quaternius(src_dir, spec["source"])
    retained = spec.get("keep_layers", 0)
    if retained:
        keep_top_layers(obj, retained, spec["layers"], spec.get("stem_compress", 1.0))
    # 실패할 때만 먼 나무의 맨 위 층을 재시도한다. 실제 채택 층 수를 장부에 기록한다.
    if not decimate(obj, spec, retained):
        if "fallback_layers" not in spec:
            raise ValueError("%s: 면 예산과 가지/재질 보존을 함께 만족하지 못함" % pid)
        obj = load_quaternius(src_dir, spec["source"])
        retained = spec["fallback_layers"]
        keep_top_layers(obj, retained, spec["layers"], stem_compress=0.20)
        if not decimate(obj, spec, retained):
            raise ValueError("%s: 맨 위 층으로 줄인 뒤에도 면 예산 실패" % pid)
    mesh = obj.data
    mesh.update()
    lo = Vector([min(v.co[i] for v in mesh.vertices) for i in range(3)])
    hi = Vector([max(v.co[i] for v in mesh.vertices) for i in range(3)])
    foot = [v.co for v in mesh.vertices if v.co.z < lo.z + 0.12 * (hi.z - lo.z)]
    centre = Vector((sum(v.x for v in foot) / len(foot), sum(v.y for v in foot) / len(foot), lo.z))
    scale = spec["height"] / (hi.z - lo.z)
    piece = pc.Piece(pid)
    made = []
    for v in mesh.vertices:
        co = (v.co - centre) * scale
        co.x *= spec.get("width_scale", 1.0)
        co.y *= spec.get("width_scale", 1.0)
        made.append(piece.bm.verts.new(co))
    for i, poly in enumerate(mesh.polygons):
        if poly.area < 1e-12:
            continue
        name = SEMANTICS[poly.material_index]
        if name.startswith("needle"):
            name = spec["needle"] if name == "needle" else "needle_dark"
        rgb = [c * jitter(pid, i) for c in COLOURS[name]]
        face = piece.bm.faces.new([made[k] for k in poly.vertices])
        face.material_index = poly.material_index
        face.smooth = False
        for loop in face.loops:
            loop[piece.col] = rgb + [1.0]
        piece.colours.add(name)
    bmesh.ops.delete(piece.bm, geom=[v for v in piece.bm.verts if not v.link_faces], context="VERTS")
    bmesh.ops.triangulate(piece.bm, faces=list(piece.bm.faces))
    piece.bm.normal_update()
    if retained and len(needle_layers(piece.bm)) != retained:
        raise ValueError("%s: 최종 삼각화 후 가지 층 손실" % pid)
    return piece, retained


def geometry_signature(bm):
    bm.verts.index_update()
    return (tuple(tuple(v.co) for v in bm.verts), tuple(tuple(v.index for v in f.verts) for f in bm.faces))


def snow_twin(base):
    piece = pc.Piece(base.pid + "_snow")
    piece.bm.free()
    piece.bm = base.bm.copy()
    piece.col = piece.bm.loops.layers.float_color["Col"]
    piece.colours = set(base.colours)
    piece.bm.normal_update()
    snowy_faces = 0
    for face in piece.bm.faces:
        if face.material_index not in NEEDLE_SLOTS or face.normal.z <= SNOW_FROM:
            continue
        if hashlib.md5(("snow:%s:%d" % (base.pid, face.index)).encode()).digest()[1] / 255.0 >= SNOW_SHARE:
            continue
        weight = SNOW * min(1.0, (face.normal.z - SNOW_FROM) / (SNOW_FULL - SNOW_FROM))
        for loop in face.loops:
            rgb = loop[piece.col][:3]
            loop[piece.col] = [c * (1 - weight) + n * weight for c, n in zip(rgb, COLOURS["snow"])] + [1.0]
        snowy_faces += 1
    if not snowy_faces or geometry_signature(base.bm) != geometry_signature(piece.bm):
        raise ValueError("%s: 눈 윗면 또는 동일 메시 검사 실패" % piece.pid)
    piece.colours.add("snow")
    return piece


def check_budget(pid, spec, tris):
    if not spec.get("min", 1) <= tris <= spec["limit"]:
        raise ValueError("%s 삼각형 %d: 허용 %d~%d" % (pid, tris, spec.get("min", 1), spec["limit"]))


def bounds(bm):
    xs, ys, zs = ([v.co[i] for v in bm.verts] for i in range(3))
    return [[round(min(xs), 4), round(min(zs), 4), round(-max(ys), 4)],
            [round(max(xs), 4), round(max(zs), 4), round(-min(ys), 4)]]


def catalogue_header():
    return {"version": 2, "generator": "tools/blender/props_field_trees.py",
            "source": "quaternius_nature + kenney_nature_kit",
            "sources": {"quaternius_nature": {"name": "Quaternius Ultimate Nature Pack", "license": "CC0-1.0"},
                        "kenney_nature_kit": {"name": "Kenney Nature Kit 2.1", "license": "CC0-1.0"}},
            "axis": "+Y 위, 원점은 밑동 가운데", "colour_encoding": "linear RGBA, alpha 1",
            "palette": {name: list(rgb) for name, rgb in COLOURS.items()},
            "needle_luminance_range": [0.04, 0.08], "jitter": JITTER,
            "snow": {"normal_from": SNOW_FROM, "normal_full": SNOW_FULL, "max_mix": SNOW, "face_share": SNOW_SHARE}, "assets": {}}


def recipe_entry(pid, spec):
    quaternius = pid.startswith("spruce") or pid == "birch_bare"
    colours = ([spec["needle"], "bark"] if pid.startswith("spruce") else
               ["birch", "birch_mark"] if pid == "birch_bare" else list(spec["recolour"].values()))
    if pid.endswith("_snow"):
        colours.append("snow")
    return {"path": "res://models/props_field/%s.glb" % pid, "status": "pending_bake", "lod0_tris": None,
            "triangle_min": spec.get("min", 1), "triangle_limit": spec["limit"],
            "triangle_target": spec.get("target"), "bytes": None, "sha256": None,
            "bounds_godot": None, "height_m": spec["height"], "width_m": None,
            "source": "quaternius_nature" if quaternius else "kenney_nature_kit",
            "source_asset": spec["source"] + (".fbx" if quaternius else ".glb"),
            "planned_foliage_layers": spec.get("keep_layers", 0), "foliage_layers": None,
            "width_scale": spec.get("width_scale", 1.0),
            "stem_compress": spec.get("stem_compress", 1.0),
            "snow_twin_of": pid[:-5] if pid.endswith("_snow") else None, "colours": sorted(colours)}


def readme_text(book):
    lines = ["# 숲 모형", "", "`tools/blender/props_field_trees.py`가 만든다. 단일 메시·Col 정점색·알파 1, 질감·재질 없음.",
             "모형 이름/경로와 키를 유지한다. Quaternius 침엽수·자작나무와 Kenney 밑 덮개 셋은 모두 CC0.",
             "굽기 전 장부는 `pending_bake`(면 수·바이트·해시·경계·폭 null)이고, 굽기가 끝나면 아래 「파일 확인값」에 실측이 들어간다.", "",
             "## 원본과 꼴", "", "| 이름 (침엽수는 같은 꼴의 `_snow` 포함) | 원본 | 키 m | 가지 층 | 가로 배율 | 삼각형 예산 / 목표 |",
             "|---|---|---:|---|---:|---|"]
    for pid, spec in {**TREES, "birch_bare": BIRCH}.items():
        row = book["assets"][pid]
        layers = str(spec["keep_layers"]) if "keep_layers" in spec else "—"
        if pid == "spruce_young":
            layers = "5층 중 위 3층, 드러난 밑줄기 ×0.35"
        elif pid == "spruce_far":
            layers = "4층; 예산/층 보존 실패 시 위 1층, 밑줄기 ×0.20"
        target = str(spec["target"]) if "target" in spec else "기존 유지"
        lines.append("| %s | %s / `%s` | %g | %s | %.2f | %d~%d / %s |" %
                     (pid, row["source"], row["source_asset"], spec["height"], layers,
                      spec.get("width_scale", 1.0), spec.get("min", 1), spec["limit"], target))
    lines += ["", "높이는 면 줄이기 뒤 밑동~우듬지 전체를 맞춘다. 가로 배율은 이 균일 배율에 추가 적용한다.",
              "FBX 정적 확인: PineTree_1은 1,920삼각형·5층, 2는 1,692·4층, 3은 2,392·6층. 목표 수는 굽기 실측이 아니다.",
              "1° 평면 줄이기(재질 경계 보존) 후 필요하면 collapse 비율을 탐색한다. 하한/상한 또는 가지 층·껍질 역할 보존 실패 시 굽기를 실패시킨다.",
              "`birch_bare`는 `BirchTree_Dead_Snow_1.fbx`의 Snow 면을 빼고 White/Black을 다시 칠한다. 검은 무늬는 원본 재질에서 온다. 600 미만.", "",
              "## 색 (선형 RGB)", "", "| 역할 | R | G | B | 기본 Y | jitter 뒤 Y |", "|---|---:|---:|---:|---:|---|"]
    for name, rgb in COLOURS.items():
        y = luminance(rgb)
        span = "고정, 윗면 바늘잎 %d%%에 최대 %d%% 혼합" % (round(SNOW_SHARE * 100), round(SNOW * 100)) if name == "snow" else "%.5f~%.5f" % (y * (1 - JITTER), y * (1 + JITTER))
        lines.append("| %s | %.3f | %.3f | %.3f | %.5f | %s |" % (name, *rgb, y, span))
    lines += ["", "Y = 0.2126R + 0.7152G + 0.0722B. 바늘잎 Y 0.04~0.08, 면 jitter ±12%, 알파 1.",
              "`needle_dark`는 tall/far, `needle`은 mid/round/young에 쓴다. Kenney 셋의 원본·키·색·jitter는 그대로 둔다.",
              "눈 짝은 완성된 기본형 BMesh 복사본이다. 같은 정점/삼각형/기본 명암에서, 바늘잎 법선의 위 성분 >%.2f인 면만 기존 눈 (0.84, 0.88, 0.90)과 섞는다." % SNOW_FROM,
              "위 성분 %.2f부터 %.2f에서 최대 혼합 %.2f, 그 가운데 %d%% 면에만(면 번호 해시) 덩어리로, 옆·아랫면·줄기는 기본형과 동일. PineTree_Snow_*의 눈 덩어리는 사용하지 않는다." % (SNOW_FROM, SNOW_FULL, SNOW, round(SNOW_SHARE * 100)),
              "합격은 화면 흑백: 눈 짝 무리의 평균이 맨땅보다 어둡다(줌 24 낮).", "",
              "## 굽기와 인계", "", "```powershell",
              'blender -b --factory-startup --python-exit-code 1 -P tools/blender/props_field_trees.py -- --repo . --src "<Kenney GLTF 폴더>" --src-quaternius "' + DEFAULT_QUATERNIUS + '"',
              "```", "", "`--src-quaternius`는 위 경로가 기본값이고 `--src`는 기존 Kenney GLTF 폴더 인수다.",
              "부른 세션이 굽기 → Godot 가져오기 → `test_props_field_trees.gd` 실행 → 줌 24·36 낮·밤 전/후와 흑백 명도 → 화면 삼각형 합 전/후를 확인한다.",
              "이 문서의 목표 RGB 검사로 게임 조명·셰이더를 거친 화면 명도 합격을 대신하지 않는다. 장부가 ready여도 화면 합격은 별도다.", "",
              "## 파일 확인값", "", "| 이름 | 상태 | 실제 삼각형 | 실제 층 | 바이트 | sha256 |", "|---|---|---:|---:|---:|---|"]
    for pid, row in book["assets"].items():
        values = [str(row[key]) if row.get(key) is not None else "—" for key in ("lod0_tris", "foliage_layers", "bytes", "sha256")]
        lines.append("| %s | %s | %s |" % (pid, row["status"], " | ".join(values)))
    return "\n".join(lines) + "\n"


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--repo", required=True)
    parser.add_argument("--src", required=True)
    parser.add_argument("--src-quaternius", default=DEFAULT_QUATERNIUS)
    args = parser.parse_args(sys.argv[sys.argv.index("--") + 1:])
    repo, src_dir, quat_dir = Path(args.repo).resolve(), Path(args.src).resolve(), Path(args.src_quaternius).resolve()
    out_dir = repo / "s2/models/props_field"
    for name in ("needle", "needle_dark"):
        y = luminance(COLOURS[name])
        if not 0.04 <= y * (1 - JITTER) <= y * (1 + JITTER) <= 0.08 < luminance(COLOURS["snow"]):
            raise ValueError("바늘잎 명도 범위 실패: %s" % name)
    rows = {}
    for pid, spec in {**TREES, "birch_bare": BIRCH}.items():
        if pid.startswith("spruce") or pid == "birch_bare":
            piece, layers = build_quaternius(pid, spec, quat_dir)
        else:
            piece, layers = build_kenney(pid, spec, src_dir), 0
        rows[pid] = (piece, spec, layers)
        if spec["snow"]:
            rows[pid + "_snow"] = (snow_twin(piece), spec, layers)
    # 어느 종이든 예산 실패면 GLB/장부를 쓰기 전에 중단한다.
    for pid, (piece, spec, _) in rows.items():
        check_budget(pid, spec, len(piece.bm.faces))
    book = catalogue_header()
    for pid, (piece, spec, layers) in rows.items():
        tris, b = len(piece.bm.faces), bounds(piece.bm)
        path = out_dir / (pid + ".glb")
        # 역할 번호는 눈 짝을 만드는 데까지만 사용한다. 내보내기는 단일 면 묶음.
        for face in piece.bm.faces:
            face.material_index = 0
        pc.export(piece, str(path))
        size, sha = pc.check_glb(str(path), tris)
        row = recipe_entry(pid, spec)
        row.update({"status": "ready", "lod0_tris": tris, "bytes": size, "sha256": sha, "bounds_godot": b,
                    "foliage_layers": layers,
                    "height_m": round(b[1][1] - b[0][1], 2),
                    "width_m": round(max(b[1][0] - b[0][0], b[1][2] - b[0][2]), 2), "colours": sorted(piece.colours)})
        if pid == "spruce_far" or pid == "spruce_far_snow":
            row["stem_compress"] = 0.20 if layers == 1 else 1.0
        book["assets"][pid] = row
        print("TREE %s tris %d bytes %d h %.2f layers %d" % (pid, tris, size, row["height_m"], layers))
    (out_dir / "catalog_trees.json").write_text(json.dumps(book, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    (out_dir / "README_trees.md").write_text(readme_text(book), encoding="utf-8")


if __name__ == "__main__":
    main()
