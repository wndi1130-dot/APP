"""Room furniture: edit the read-only Kenney Furniture Kit 2.0 inputs.

Run godot_gate.py and observe GODOT_GATE=PASS before starting Blender:
blender -b --factory-startup -P tools/blender/props_field_room.py -- --repo .

The optional --manifest-only mode uses only Python's standard library. It records
blocked/not_run results, never fabricates GLBs or reports Blender verification.
Blender coordinates: X right, Z up, -Y front. Export: +Y up, +Z front.
"""
import sys
sys.dont_write_bytecode = True

import argparse
import hashlib
import json
import math
from pathlib import Path
import re
import shutil
import struct

TRIANGLE_LIMIT = 700
SOURCE_CREDIT = "Kenney Furniture Kit 2.0, CC0"
SOURCE_LICENSE = "tools/blender/_src_kenney/License.txt"
TOLERANCE = 0.0001

# Exact requested top elevation, footprint, sensible width/depth, source, finish.
# Every selected source faces glTF +Z after its own node transforms. In particular,
# trashcan has a source-node rotation which must not be dropped on import.
# Front/back read-only CPU projections were inspected; Workbench review is pending.
DESIGNS = {
    "dresser": dict(source="sideTableDrawers", height=1.0, footprint=[2, 1], size=[1.76, .62], paint="room_cream",
                    note="기존 두 서랍·상판·다리를 살리고 아래 몸통과 서랍 네 개를 덧댄 낮고 넓은 목제 서랍장"),
    "chair": dict(source="chair", height=.85, footprint=[1, 1], size=[.52, .55], paint="room_cream",
                  note="네 다리와 뚫린 등받이의 목제 의자, 밝은 크림 칠과 짙은 좌판"),
    "nightstand": dict(source="cabinetBedDrawerTable", height=.55, footprint=[1, 1], size=[.50, .43], paint="room_blue",
                       note="작은 서랍 하나, 네 다리, 바랜 파랑 칠과 나무 상판"),
    "counter": dict(source="kitchenCabinet", height=.9, footprint=[1, 1], size=[.96, .66], paint="room_sage",
                    note="옆면이 단순한 조리대, 상판의 금속색도 목재색으로 변경"),
    "sink": dict(source="kitchenSink", height=.9, footprint=[1, 1], size=[.90, .66], paint="room_cream",
                 note="밝은 회색 금속 개수통·수도꼭지, 크림 칠 목제 하부장"),
    "cupboard": dict(source="bookcaseClosedDoors", height=1.8, footprint=[1, 1], size=[.78, .44], paint="room_sage",
                     note="연초록 칠의 높은 두 문 찬장, 짙은 목재 상판과 회색 손잡이"),
    "settee": dict(source="loungeSofa", height=.85, footprint=[2, 1], size=[1.76, .78], paint="room_walnut",
                   note="바랜 붉은 갈색 천의 두 자리 소파, 나무 다리와 덧댄 목제 팔걸이 상단"),
    "armchair": dict(source="loungeChair", height=.9, footprint=[1, 1], size=[.82, .78], paint="room_walnut",
                     note="바랜 초록 천의 넓은 의자, 나무 다리와 목제 팔걸이 상단"),
    "low_table": dict(source="tableCoffeeSquare", height=.45, footprint=[1, 1], size=[.72, .66], paint="room_blue",
                     note="짙은 나무 사각 상판과 바랜 파랑 다리의 낮은 탁자"),
    "side_table": dict(source="sideTable", height=.6, footprint=[1, 1], size=[.56, .43], paint="room_cream",
                      note="밝은 크림 다리와 짙은 목제 상판의 작은 탁자"),
    "toilet": dict(source="toilet", height=.65, footprint=[1, 1], size=[.46, .68], paint="room_enamel",
                  note="밝은 흰 도기, 닫힌 뚜껑과 뒤쪽 물통"),
    "washstand": dict(source="bathroomCabinetDrawer", height=.85, footprint=[1, 1], size=[.72, .55], paint="room_cream",
                     note="후보 받침 세면대 대신 같은 제공 묶음의 수납형 세면대 선택, 법랑 대야·목제 서랍·짧은 다리"),
    "bathtub": dict(source="bathtub", height=.6, footprint=[2, 1], size=[1.82, .83], paint="room_enamel",
                   note="긴 쪽 X, 밝은 흰 법랑 욕조에 짧은 주철 다리 네 개 추가"),
    "towel_shelf": dict(source="bookcaseOpen", height=1.6, footprint=[1, 1], size=[.62, .40], paint="room_cream",
                       note="좁고 높은 목제 선반, 기존 수평 선반 높이를 찾아 접은 수건 여섯 장 추가"),
    "medicine_cabinet": dict(source="bathroomCabinet", height=1.75, bottom=1.15, footprint=[1, 1], size=[.46, .20], paint="room_blue",
                            note="바닥 기준 원점, 높이 1.15~1.75 m의 작은 벽 약장, 거울색은 법랑색으로 대체, 표지 없음"),
    "waste_bin": dict(source="trashcan", height=.45, footprint=[1, 1], size=[.34, .34], paint="room_metal",
                     note="뚜껑과 발판이 있는 작은 회색 금속 휴지통, 윗면에 주철 손잡이 추가"),
}

# Linear RGB AFTER fx_model_grade, before lighting/weather/photo fade. Reversing
# max-channel desaturation keeps warm wood/cloth distinct and whites bright.
GRADED_TARGETS = {
    "room_cream": (.62, .60, .50), "room_sage": (.46, .55, .45),
    "room_blue": (.40, .50, .58), "room_walnut": (.26, .225, .18),
    "room_oak": (.42, .35, .27), "room_brick": (.45, .32, .28),
    "room_moss": (.27, .37, .26), "room_mustard": (.50, .43, .30),
    "room_linen": (.65, .65, .59), "room_enamel": (.735, .75, .77),
    "room_steel": (.54, .57, .60), "room_metal": (.26, .285, .30),
    "room_cast": (.17, .18, .19), "room_seam": (.12, .13, .14),
}
GRADE = dict(saturation=.45, value=.82, cool=[.78, .85, .95], cool_mix=.35)


def grade(rgb):
    value = max(rgb)
    return tuple((value * (1 - GRADE["saturation"]) + c * GRADE["saturation"])
                 * GRADE["value"] * (1 - GRADE["cool_mix"] + cool * GRADE["cool_mix"])
                 for c, cool in zip(rgb, GRADE["cool"]))


def inverse_grade(target):
    before_cool = [c / (GRADE["value"] * (1 - GRADE["cool_mix"] + cool * GRADE["cool_mix"]))
                   for c, cool in zip(target, GRADE["cool"])]
    value = max(before_cool)
    rgb = tuple((c - value * (1 - GRADE["saturation"])) / GRADE["saturation"] for c in before_cool)
    assert all(0 <= c <= 1 for c in rgb), (target, rgb)
    assert max(abs(a - b) for a, b in zip(grade(rgb), target)) < 1e-8
    return (*rgb, 1.0)


ROOM_PALETTE = {name: inverse_grade(rgb) for name, rgb in GRADED_TARGETS.items()}


def read_glb(path):
    raw = path.read_bytes()
    magic, version, total = struct.unpack_from("<4sII", raw)
    assert (magic, version, total) == (b"glTF", 2, len(raw)), path
    length, kind = struct.unpack_from("<II", raw, 12)
    assert kind == 0x4E4F534A
    doc = json.loads(raw[20:20 + length])
    offset = 20 + length
    bin_length, bin_kind = struct.unpack_from("<II", raw, offset)
    assert bin_kind == 0x004E4942 and offset + 8 + bin_length == len(raw)
    return raw, doc, raw[offset + 8:]


def source_record(repo, name):
    path = repo / "tools/blender/_src_kenney" / (name + ".glb")
    raw, doc, _ = read_glb(path)
    assert not doc.get("images") and not doc.get("textures"), "Unexpected textured source: " + name
    tris = 0
    for node in doc["nodes"]:
        if "mesh" in node:
            tris += sum(doc["accessors"][p["indices"]]["count"] // 3
                        for p in doc["meshes"][node["mesh"]]["primitives"])
    return dict(name=name, credit=SOURCE_CREDIT, path=path.relative_to(repo).as_posix(),
                sha256=hashlib.sha256(raw).hexdigest(), bytes=len(raw), triangles=tris,
                materials=[dict(name=m.get("name", ""), base_color=m.get("pbrMetallicRoughness", {}).get("baseColorFactor", [1, 1, 1, 1]))
                           for m in doc.get("materials", [])])


def planned_asset(repo, kind, spec):
    return dict(path="res://models/props_field/" + kind + ".glb", status="not_run",
                source_name=spec["source"], source_credit=SOURCE_CREDIT,
                source=source_record(repo, spec["source"]), footprint_m=spec["footprint"],
                height_m=spec["height"], bottom_m=spec.get("bottom", 0.0),
                planned_width_depth_m=spec["size"], triangle_limit=TRIANGLE_LIMIT,
                lod0_tris=None, bytes=None, sha256=None, bounds_m=None, dimensions_m=None,
                source_yaw_degrees=0, source_node_transforms="baked into vertices",
                judgment=spec["note"], verification="not_run", failure_code=None)


def backup(path, repo):
    """Keep the previous exact bytes before touching an existing output."""
    if path.is_file():
        digest = hashlib.sha256(path.read_bytes()).hexdigest()
        target = repo / "tools/blender/_room_work/backups" / (path.name + "." + digest)
        target.parent.mkdir(parents=True, exist_ok=True)
        if not target.exists():
            shutil.copy2(path, target)


def write_books(repo, assets, failures, verification, palette=None):
    out = repo / "s2/models/props_field"
    out.mkdir(parents=True, exist_ok=True)
    license_path = repo / SOURCE_LICENSE
    book = dict(version=1, batch="room", expected_kinds=list(DESIGNS),
                status="ready" if all(a["status"] == "ready" for a in assets.values()) and not failures else "partial",
                source_credit=SOURCE_CREDIT, license_path=SOURCE_LICENSE,
                license_sha256=hashlib.sha256(license_path.read_bytes()).hexdigest() if license_path.is_file() else None,
                axis="+Y up, +Z front", origin="footprint_center_floor",
                placement="발자국 가운데 바닥, facing 0 앞 +Z / 등 -Z, 2×1 긴 쪽 X, 발자국 96% 이내",
                palette=palette or ROOM_PALETTE, colour_encoding="linear RGBA vertex Col, alpha 1",
                grade=GRADE, graded_palette_targets=GRADED_TARGETS,
                source_orientation_review="앞/뒤 CPU 투영 그림을 확인함; Blender Workbench 최종 그림은 별도 verification 참조",
                assumptions=["1칸=1 m; 깊이는 표의 칸보다 얕은 실가구 비율",
                             "medicine_cabinet의 1.75 m는 위끝 높이, 메시 자체 높이는 0.60 m",
                             "washstand는 제공 원본 중 수납장이 있는 bathroomCabinetDrawer로 선택",
                             "실제 게임의 조명·날씨·fx_photo 결과는 이 생성 스크립트만으로 보증하지 않음"],
                verification=verification, assets=assets, skipped={}, failures=failures)
    path = out / "catalog_room.json"
    backup(path, repo)
    path.write_text(json.dumps(book, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    lines = ["# 집 방 가구 room 16종", "", "`tools/blender/props_field_room.py` 생성 장부.", "",
             "출처: **Kenney Furniture Kit 2.0, CC0**. 입력과 라이선스는 `tools/blender/_src_kenney/`의 읽기 전용 파일이다.",
             "", "상태: **" + book["status"] + "**. `not_run`과 `—`는 최종 GLB를 만들거나 검사하지 못했다는 뜻이다.",
             "", book["placement"] + ". 약장만 바닥에서 1.15~1.75 m에 뜬다.",
             "단일 메시·단일 surface·Col 정점색, 재질·이미지·텍스처 없음, 각 700삼각형 이하가 완료 조건이다.",
             "", "| 종류 | 원본 | 출처 | 삼각형 | 위끝 m | 바이트 | SHA-256 | 상태 |",
             "|---|---|---|---:|---:|---:|---|---|"]
    for kind, asset in assets.items():
        lines.append(f'| `{kind}` | `{asset["source_name"]}` | {SOURCE_CREDIT} | {asset["lod0_tris"] if asset["lod0_tris"] is not None else "—"} | '
                     f'{asset["height_m"]:.2f} | {asset["bytes"] if asset["bytes"] is not None else "—"} | '
                     f'{asset["sha256"] or "—"} | {asset["status"]} |')
    lines += ["", "## 손질", ""] + [f'- `{kind}`: {a["judgment"]}.' for kind, a in assets.items()]
    lines += ["", "## 색과 확인", "", "E 묶음 PALETTE에 room 색을 추가한다. 셰이더의 채도 0.45·밝기 0.82·찬 기운 0.35를 역산한 선형 RGBA다.",
              "흰 도기·법랑, 크림·연초록·흐린 파랑 칠, 짙은 나무, 바랜 붉은 갈색·초록·겨자 천과 회색 금속을 사용한다.",
              "가방·신발·옷 더미, 빨간 십자·초승달, 사슬·쇠창살·빗장, 현대 가전·플라스틱·유리 탁자를 추가하지 않는다.",
              "", "```json", json.dumps(verification, ensure_ascii=False, indent=2), "```", "", "## 실행", "",
              "먼저 원래 PC 문지기를 실행해 `GODOT_GATE=PASS`를 확인한다. 실패하면 Blender를 시작하지 않는다.",
              "```powershell", '& "C:/Users/wndi1/AppData/Local/Programs/Python/Python313/python.exe" -X utf8 -I "C:/Users/wndi1/OneDrive/바탕 화면/작업폴더/coord/tools/godot_gate.py"',
              '# PASS를 실제로 확인한 뒤에만 다음 명령 실행',
              '& "C:/Program Files/Blender Foundation/Blender 4.5/blender.exe" -b --factory-startup --python-exit-code 1 -P tools/blender/props_field_room.py -- --repo .',
              "```", "", "같은 Blender 실행에서 최종 GLB를 다시 들여와 Workbench 정점색, 수평 45°·내려다봄 35°의 `tools/blender/_room_sheet.png`를 만든다.",
              "그림과 `_room_work/`는 git 제외 대상이다. Godot과 .import 생성은 이 스크립트가 수행하지 않는다.",
              "이전 생성 파일은 덮어쓰기 전에 `_room_work/backups/`에 이름·SHA-256별로 보관한다."]
    if failures:
        lines += ["", "## 막힘", "", "```json", json.dumps(failures, ensure_ascii=False, indent=2), "```"]
    path = out / "README_room.md"
    backup(path, repo)
    path.write_text("\n".join(lines) + "\n", encoding="utf-8")


def material_name(material):
    return re.sub(r"\.\d+$", "", material.name) if material else "_defaultMat"


def remap(kind, spec, material, z, normal):
    name = material.lower()
    paint = spec["paint"]
    if kind == "medicine_cabinet" and name == "metal":
        return "room_enamel"  # replace the mirror-like door inset, not a logo
    if name == "carpet":
        return "room_brick" if kind == "settee" else "room_moss"
    if name == "carpetwhite":
        return "room_enamel"
    if "metal" in name:
        if kind == "counter" and z > .85:
            return "room_oak"
        if kind == "bathtub" and name == "metallight" and z < .83:
            return "room_enamel"
        return {"metaldark": "room_cast", "metallight": "room_steel"}.get(name, "room_metal" if kind == "waste_bin" else "room_steel")
    if kind == "sink" and z > .68:
        return "room_steel"
    if name == "wooddark":
        return "room_walnut"
    if kind in ("toilet", "washstand", "bathtub") and name == "_defaultmat":
        return "room_enamel"
    if kind in ("settee", "armchair"):
        return "room_walnut"
    if z < .10:
        return "room_walnut"
    if z > .91 or (kind == "chair" and .34 < z < .65 and normal.z > .8):
        return "room_oak"
    if kind == "towel_shelf" and normal.z > .8:
        return "room_oak"
    return paint


def import_piece(repo, kind, spec):
    """Bake each material's actual base factor to Col, then remap those faces."""
    before = set(bpy.data.objects)
    piece = base.Piece(kind)
    try:
        bpy.ops.import_scene.gltf(filepath=str(repo / "tools/blender/_src_kenney" / (spec["source"] + ".glb")))
        bpy.context.view_layer.update()
        objects = [o for o in bpy.data.objects if o not in before and o.type == "MESH"]
        assert objects, "No imported meshes"
        points = [o.matrix_world @ v.co for o in objects for v in o.data.vertices]
        lo, hi = min(v.z for v in points), max(v.z for v in points)
        for obj in objects:
            mesh = obj.data
            old = mesh.color_attributes.get("Col")
            if old:
                mesh.color_attributes.remove(old)
            colours = mesh.color_attributes.new(name="Col", type="FLOAT_COLOR", domain="CORNER")
            for polygon in mesh.polygons:
                material = mesh.materials[polygon.material_index] if mesh.materials else None
                factor = (1., 1., 1., 1.) if material is None else tuple(material.diffuse_color)
                if material and material.use_nodes:
                    shader = next((n for n in material.node_tree.nodes if n.type == "BSDF_PRINCIPLED"), None)
                    if shader:
                        assert not shader.inputs["Base Color"].is_linked, "Textured source needs explicit handling"
                        factor = tuple(shader.inputs["Base Color"].default_value)
                for loop_index in polygon.loop_indices:
                    colours.data[loop_index].color = factor
                pts = [obj.matrix_world @ mesh.vertices[i].co for i in polygon.vertices]
                normal = (pts[1] - pts[0]).cross(pts[2] - pts[0])
                if normal.length_squared < 1e-20:
                    continue
                normal.normalize()
                z = (sum(v.z for v in pts) / len(pts) - lo) / (hi - lo)
                colour = remap(kind, spec, material_name(material), z, normal)
                for loop_index in polygon.loop_indices:
                    colours.data[loop_index].color = ROOM_PALETTE[colour]
                piece.face(pts, colour, normal)
        # Some Kenney nodes instance the same mesh (e.g. the two drawers).
        # Keep its slots until every instance has baked its original factors.
        for mesh in {obj.data for obj in objects}:
            mesh.materials.clear()
        bottom = spec.get("bottom", 0.)
        lift = .06 if kind == "bathtub" else (.05 if kind == "washstand" else 0.)
        reserve = .03 if kind == "waste_bin" else 0.
        piece.fit([v / .96 for v in spec["size"]], spec["height"] - bottom - lift - reserve)
        for vertex in piece.bm.verts:
            vertex.co.z += bottom + lift
        return piece
    except Exception:
        piece.bm.free()
        raise
    finally:
        for obj in list(bpy.data.objects):
            if obj not in before:
                bpy.data.objects.remove(obj, do_unlink=True)
        for collection in (bpy.data.meshes, bpy.data.materials, bpy.data.images):
            for block in list(collection):
                if block.users == 0:
                    collection.remove(block)


def horizontal_shelves(piece):
    levels = {}
    piece.bm.normal_update()
    for face in piece.bm.faces:
        if face.normal.z > .99:
            z = round(face.calc_center_median().z, 4)
            levels[z] = levels.get(z, 0.) + face.calc_area()
    return sorted(z for z, area in levels.items() if area > .04 and z < 1.40)


def embellish(piece, kind, spec):
    p = piece
    if kind == "dresser":
        p.box((-.80, .80), (-.275, .275), (.11, .68), "room_walnut")
        for x0, x1 in ((-.78, -.02), (.02, .78)):
            for z0, z1 in ((.14, .37), (.40, .63)):
                p.box((x0, x1), (-.30, -.275), (z0, z1), "room_cream")
                mid = (x0 + x1) / 2
                p.box((mid - .045, mid + .045), (-.33, -.30), (z0 + .10, z0 + .13), "room_metal")
    elif kind in ("settee", "armchair"):
        width, depth = spec["size"]
        for sign in (-1, 1):
            candidates = [v.co.z for v in p.bm.verts if sign * v.co.x > width * .40 and -.32 < v.co.y < .12]
            assert candidates, "Could not locate the armrest"
            z = max(candidates)
            x = sign * width * .455
            p.box((x - .035, x + .035), (-depth * .37, depth * .14), (z, z + .025), "room_oak")
    elif kind in ("bathtub", "washstand"):
        width, depth = spec["size"]
        for x in (-width * .33, width * .33):
            for y in (-depth * .30, depth * .30):
                p.box((x - .04, x + .04), (y - .04, y + .04), (0, .085), "room_cast" if kind == "bathtub" else "room_walnut")
    elif kind == "towel_shelf":
        levels = horizontal_shelves(p)
        assert len(levels) >= 3, ("Could not identify three towel shelves", levels)
        for i, z in enumerate(levels[:3]):
            x = -.045 if i % 2 == 0 else .035
            for j in range(2):
                colour = ("room_mustard", "room_linen", "room_moss")[(i + j) % 3]
                bottom = z + .004 + j * .058
                p.box((x - .19, x + .19), (-.16, .12), (bottom, bottom + .052), colour)
                p.box((x - .18, x + .18), (-.164, -.159), (bottom + .012, bottom + .018), "room_linen")
    elif kind == "medicine_cabinet":
        p.box((.14, .17), (-.118, -.100), (1.40, 1.44), "room_metal")
    elif kind == "waste_bin":
        p.beam((-.045, 0, .415), (-.045, 0, .442), .008, "room_cast", sides=6)
        p.beam((.045, 0, .415), (.045, 0, .442), .008, "room_cast", sides=6)
        p.beam((-.045, 0, .442), (.045, 0, .442), .008, "room_cast", sides=8)


def finish_piece(piece, spec):
    # Center the final footprint after additions; never lower the wall cabinet.
    for axis in (0, 1):
        center = (min(v.co[axis] for v in piece.bm.verts) + max(v.co[axis] for v in piece.bm.verts)) / 2
        for vertex in piece.bm.verts:
            vertex.co[axis] -= center
    bmesh.ops.triangulate(piece.bm, faces=list(piece.bm.faces))
    if len(piece.bm.faces) > TRIANGLE_LIMIT:
        # Only used if a changed source exceeds the known source + detail budget.
        bmesh.ops.remove_doubles(piece.bm, verts=list(piece.bm.verts), dist=1e-7)
        mesh = bpy.data.meshes.new("room_reduce")
        piece.bm.to_mesh(mesh)
        obj = bpy.data.objects.new("room_reduce", mesh)
        bpy.context.scene.collection.objects.link(obj)
        modifier = obj.modifiers.new("room_budget", "DECIMATE")
        modifier.ratio = (TRIANGLE_LIMIT - 20) / len(piece.bm.faces)
        modifier.use_collapse_triangulate = True
        evaluated = obj.evaluated_get(bpy.context.evaluated_depsgraph_get())
        reduced = bpy.data.meshes.new_from_object(evaluated)
        piece.bm.clear()
        piece.bm.from_mesh(reduced)
        piece.col = piece.bm.loops.layers.float_color["Col"]
        bpy.data.objects.remove(obj, do_unlink=True)
        bpy.data.meshes.remove(mesh)
        bpy.data.meshes.remove(reduced)
        bmesh.ops.triangulate(piece.bm, faces=list(piece.bm.faces))
    piece.bm.normal_update()
    assert 0 < len(piece.bm.faces) <= TRIANGLE_LIMIT
    assert all(f.calc_area() > 1e-10 for f in piece.bm.faces)
    lo, hi = piece.bounds()
    assert abs(lo[1] - spec.get("bottom", 0.)) < TOLERANCE, (lo, spec)
    assert abs(hi[1] - spec["height"]) < TOLERANCE, (hi, spec)
    for axis, cell in ((0, spec["footprint"][0]), (2, spec["footprint"][1])):
        assert hi[axis] - lo[axis] <= cell * .96 + TOLERANCE


def accessor_values(doc, binary, index):
    a = doc["accessors"][index]
    assert "sparse" not in a
    view = doc["bufferViews"][a["bufferView"]]
    code, width = {5126: ("f", 4), 5125: ("I", 4), 5123: ("H", 2), 5121: ("B", 1)}[a["componentType"]]
    count = {"SCALAR": 1, "VEC3": 3, "VEC4": 4}[a["type"]]
    stride = view.get("byteStride", count * width)
    start = view.get("byteOffset", 0) + a.get("byteOffset", 0)
    rows = [struct.unpack_from("<" + code * count, binary, start + i * stride) for i in range(a["count"])]
    if a.get("normalized"):
        divisor = {5121: 255., 5123: 65535.}[a["componentType"]]
        rows = [tuple(v / divisor for v in row) for row in rows]
    return rows


def check_glb(path, expected_tris, spec):
    size, digest = base.check_glb(path, expected_tris)
    _, doc, binary = read_glb(path)
    # No residual object transforms: the origin and axis contract is in the mesh.
    for node in doc["nodes"]:
        assert "matrix" not in node
        assert node.get("translation", [0, 0, 0]) == [0, 0, 0]
        assert node.get("rotation", [0, 0, 0, 1]) == [0, 0, 0, 1]
        assert node.get("scale", [1, 1, 1]) == [1, 1, 1]
    primitive = doc["meshes"][0]["primitives"][0]
    assert "material" not in primitive
    positions = accessor_values(doc, binary, primitive["attributes"]["POSITION"])
    colours = accessor_values(doc, binary, primitive["attributes"]["COLOR_0"])
    normals = accessor_values(doc, binary, primitive["attributes"]["NORMAL"])
    indices = [v[0] for v in accessor_values(doc, binary, primitive["indices"])]
    assert len(positions) == len(colours) == len(normals)
    assert all(0 <= index < len(positions) for index in indices)
    assert all(math.isfinite(v) for row in positions + normals + colours for v in row)
    assert all(len(c) == 4 and abs(c[3] - 1) < .0001 and all(0 <= v <= 1 for v in c) for c in colours)
    assert len({tuple(round(v, 4) for v in c[:3]) for c in colours}) >= 2, "Flat fallback colour"
    for a, b, c in zip(indices[0::3], indices[1::3], indices[2::3]):
        assert (Vector(positions[b]) - Vector(positions[a])).cross(Vector(positions[c]) - Vector(positions[a])).length > 2e-10
    used = [positions[i] for i in indices]
    bounds = [[min(v[i] for v in used) for i in range(3)], [max(v[i] for v in used) for i in range(3)]]
    lo, hi = bounds
    assert abs(lo[1] - spec.get("bottom", 0.)) < TOLERANCE
    assert abs(hi[1] - spec["height"]) < TOLERANCE
    for axis, cells in ((0, spec["footprint"][0]), (2, spec["footprint"][1])):
        assert hi[axis] - lo[axis] <= cells * .96 + TOLERANCE
        assert abs(hi[axis] + lo[axis]) < TOLERANCE
    if spec["footprint"] == [2, 1]:
        assert hi[0] - lo[0] > hi[2] - lo[2]
    return dict(bytes=size, sha256=digest, bounds_m=[[round(v, 6) for v in row] for row in bounds],
                dimensions_m=[round(hi[i] - lo[i], 6) for i in range(3)],
                lod0_tris=len(indices) // 3, surfaces=1, meshes=1, vertex_colours="Col / COLOR_0", verification="pass")


def preview(repo, assets):
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_WORKBENCH"
    scene.render.resolution_x = 2000
    scene.render.resolution_y = 1900
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = "PNG"
    scene.display.shading.light = "STUDIO"
    scene.display.shading.color_type = "VERTEX"
    scene.display.shading.show_shadows = True
    scene.display.shading.show_cavity = True
    scene.display.shading.cavity_type = "BOTH"
    scene.display.shading.background_type = "WORLD"
    if scene.world is None:
        scene.world = bpy.data.worlds.new("room_preview")
    scene.world.color = (.10, .12, .14)
    scene.view_settings.view_transform = "Standard"
    elev = math.radians(35)
    direction = Vector((math.cos(elev) / math.sqrt(2), -math.cos(elev) / math.sqrt(2), math.sin(elev)))
    rotation = direction.to_track_quat("Z", "Y")
    right, up = rotation @ Vector((1, 0, 0)), rotation @ Vector((0, 1, 0))
    for index, kind in enumerate(DESIGNS):
        if assets[kind]["status"] != "ready":
            continue
        before = set(bpy.data.objects)
        bpy.ops.import_scene.gltf(filepath=str(repo / "s2/models/props_field" / (kind + ".glb")))
        bpy.context.view_layer.update()
        objects = [o for o in bpy.data.objects if o not in before and o.type == "MESH"]
        for obj in objects:
            world = obj.matrix_world.copy()
            obj.parent = None
            obj.matrix_world = world
            assert obj.data.color_attributes, kind
            obj.data.color_attributes.active_color = obj.data.color_attributes[0]
            obj.data.color_attributes.render_color_index = 0
        points = [o.matrix_world @ v.co for o in objects for v in o.data.vertices]
        center = Vector([(min(p[i] for p in points) + max(p[i] for p in points)) / 2 for i in range(3)])
        cell = right * ((index % 4 - 1.5) * 2.8) + up * ((1.5 - index // 4) * 2.8)
        for obj in objects:
            obj.matrix_world.translation += cell - center
        curve = bpy.data.curves.new("room_label", "FONT")
        curve.body = f'{kind}  {assets[kind]["lod0_tris"]}t / {DESIGNS[kind]["height"]:.2f}m'
        curve.size = .12
        curve.align_x = "CENTER"
        label = bpy.data.objects.new("room_label", curve)
        scene.collection.objects.link(label)
        label.rotation_euler = rotation.to_euler()
        label.location = cell - up * 1.13 + direction * 1.5
    data = bpy.data.cameras.new("room_camera_45_35")
    camera = bpy.data.objects.new("room_camera_45_35", data)
    scene.collection.objects.link(camera)
    camera.location = direction * 30
    camera.rotation_euler = rotation.to_euler()
    data.type = "ORTHO"
    data.ortho_scale = 11.8
    scene.camera = camera
    path = repo / "tools/blender/_room_sheet.png"
    backup(path, repo)
    scene.render.filepath = str(path)
    bpy.ops.render.render(write_still=True)
    assert path.is_file() and path.stat().st_size > 1000
    print("ROOM_RENDER=PASS _room_sheet.png workbench_vertex azimuth=45 elevation=35", flush=True)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--repo", required=True)
    parser.add_argument("--manifest-only", action="store_true")
    parser.add_argument("--blocked-code", default="F-NONINTERACTIVE")
    parser.add_argument("--blocked-reason", default="Blender not executed")
    args = parser.parse_args(sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else sys.argv[1:])
    repo = Path(args.repo).resolve()
    failures, assets = [], {}
    verification = dict(blender="not_run", glb="not_run", workbench_render="not_run",
                        visual_review="not_verified", godot_tests="not_run: caller owns Godot/import", imports="not_run")
    for kind, spec in DESIGNS.items():
        try:
            assets[kind] = planned_asset(repo, kind, spec)
        except Exception as error:
            failures.append(dict(kind=kind, failure_code="F-INPUT-MISSING", observed=str(error)))
    if len(assets) != len(DESIGNS) or not (repo / SOURCE_LICENSE).is_file():
        failures.append(dict(failure_code="F-INPUT-MISSING", observed="Expected 16 usable sources and License.txt"))
        write_books(repo, assets, failures, verification)
        return 2
    if args.manifest_only:
        for asset in assets.values():
            asset["failure_code"] = args.blocked_code
        failures.append(dict(failure_code=args.blocked_code, observed=args.blocked_reason,
                             blocked_reason="No GODOT_GATE=PASS; no Blender process was started"))
        write_books(repo, assets, failures, verification)
        print(f"ROOM_MANIFEST=PARTIAL expected=16 generated=0 failure={args.blocked_code}", flush=True)
        return 2
    global bpy, bmesh, Vector, base
    import bpy
    import bmesh
    from mathutils import Vector
    sys.path.insert(0, str(Path(__file__).resolve().parent))
    import props_field_e as base
    base.PALETTE.update(ROOM_PALETTE)
    bpy.ops.wm.read_factory_settings(use_empty=True)
    verification["blender"] = bpy.app.version_string
    out = repo / "s2/models/props_field"
    out.mkdir(parents=True, exist_ok=True)
    for kind, spec in DESIGNS.items():
        piece = None
        try:
            piece = import_piece(repo, kind, spec)
            embellish(piece, kind, spec)
            finish_piece(piece, spec)
            path = out / (kind + ".glb")
            backup(path, repo)
            base.export(piece, path)
            result = check_glb(path, len(piece.bm.faces), spec)
            assets[kind].update(result, status="ready", colours=sorted(piece.colours))
            print(f'PROP_READY {kind} tris={result["lod0_tris"]} height={spec["height"]} bytes={result["bytes"]} surface=1 Col=PASS footprint=PASS', flush=True)
        except Exception as error:
            assets[kind].update(status="failed", failure_code="F-ASSET-VERIFY", verification="failed")
            failures.append(dict(kind=kind, failure_code="F-ASSET-VERIFY", observed=repr(error)))
            print(f"PROP_FAILED {kind} {error!r}", flush=True)
        finally:
            if piece is not None:
                piece.bm.free()
        # Persist every completed asset and its evidence immediately.
        write_books(repo, assets, failures, verification, base.PALETTE)
    verification["glb"] = "pass" if all(a["status"] == "ready" for a in assets.values()) else "failed"
    try:
        preview(repo, assets)
        verification["workbench_render"] = "pass: rendered, visual review still required"
    except Exception as error:
        verification["workbench_render"] = "failed"
        failures.append(dict(failure_code="F-RENDER", observed=repr(error)))
    for kind, asset in assets.items():
        if source_record(repo, DESIGNS[kind]["source"])["sha256"] != asset["source"]["sha256"]:
            failures.append(dict(kind=kind, failure_code="F-SOURCE-CHANGED", observed="Input hash changed during bake"))
    write_books(repo, assets, failures, verification, base.PALETTE)
    count = sum(a["status"] == "ready" for a in assets.values())
    print(f"PROPS_FIELD_ROOM generated={count} expected=16 failures={len(failures)}", flush=True)
    return 1 if failures else 0


if __name__ == "__main__":
    raise SystemExit(main())
