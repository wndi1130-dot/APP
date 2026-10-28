"""가로수(street_tree)와 맨가지 나무(공용 bare_tree)를 공개 3D(CC0) 맨가지 활엽으로 바꾼다
(사용자 10-28 「나무도 빠르게 바꿔야」, 코디 나무 후보 견줌 — 가로수·침엽수는 Quaternius).
Blender 4.5 헤드리스.

blender -b --factory-startup --python-exit-code 1 -P tools/blender/props_field_street.py -- --repo . --src <FBX 폴더> [--out <폴더>] [--preview <폴더>]

원본은 저장소 밖(`C:\\dev\\zombie\\assets_raw\\quaternius_nature\\fbx\\`): Quaternius Ultimate Nature Pack(CC0 1.0)의
눈 얹힌 맨가지 활엽 FBX. 하는 일: 원본 메시를 한 덩이로 모아 → 재질 이름으로 껍질·눈을 가르고 → 면 줄이기(target 아래,
재질 칸은 지킴) → 짙은 껍질과 껍질에 조금 섞은 눈으로 정점색 → 줄기 밑동 가운데를 원점에, 높이를 지금 가로수 높이로 →
같은 경로로 GLB(단일 메시, Col 정점색, 재질·질감 없음) → 그 장부(catalog_a·README_a, 공용 catalog·README)의 줄을 고친다.
공용 bare_tree는 props_common.py가 KEPT로 두어 다시 굽지 않는다.
껍질은 들판 색 판 bark보다 짙게 둔다: 소품 셰이더가 채도·밝기를 눌러 회백색으로 뜨던 것을 겨울 맨가지의 짙은 윤곽으로.
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
import props_common as pc  # noqa: E402  같은 내보내기·검사를 쓴다

BARK = (0.075, 0.060, 0.050)   # 선형. 들판 bark(0.19)보다 짙게
SNOW_MIX = 0.55                 # 원본 눈 면에 섞는 눈 몫(새하얀 눈뭉치로 뜨지 않게)
JITTER = 0.10                   # 면마다 밝기 흔들림
SWAPS = {
    "street_tree": {"dir": "props_field", "catalog": "catalog_a.json", "readme": "README_a.md",
                    "source": "CommonTree_Dead_Snow_5", "height": 4.4, "target": 520,
                    "use": "눈 조금 얹은 맨가지 활엽 가로수(Quaternius CommonTree_Dead_Snow_5, CC0)"},
    # 숲 띠·샛길·고리에 1,235칸 — 가늘게(같은 계열의 좁은 나무), 삼각형도 가로수보다 낮게.
    "bare_tree": {"dir": "props_common", "catalog": "catalog.json", "readme": "README.md",
                  "source": "CommonTree_Dead_Snow_3", "height": 5.2, "target": 440,
                  "use": "눈 조금 얹은 좁은 맨가지 활엽(Quaternius CommonTree_Dead_Snow_3, CC0)"},
}


def jitter(seed, i):
    h = hashlib.md5(("%s:%d" % (seed, i)).encode()).digest()
    return 1.0 + JITTER * (h[0] / 127.5 - 1.0)


def load_source(src_dir, source):
    """FBX를 가져와 메시를 세계 좌표 한 오브젝트로 합친다. 재질 칸 0 = 껍질, 1 = 눈."""
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.fbx(filepath=str(src_dir / (source + ".fbx")))
    meshes = [o for o in bpy.context.scene.objects if o.type == "MESH"]
    bm = bmesh.new()
    for o in meshes:
        part = bmesh.new()
        part.from_mesh(o.data)
        part.transform(o.matrix_world)
        snow = [i for i, s in enumerate(o.material_slots) if s.material is not None and "snow" in s.material.name.lower()]
        for f in part.faces:
            f.material_index = 1 if f.material_index in snow else 0
        tmp = bpy.data.meshes.new("tmp")
        part.to_mesh(tmp)
        part.free()
        bm.from_mesh(tmp)
        bpy.data.meshes.remove(tmp)
    for o in list(bpy.context.scene.objects):
        bpy.data.objects.remove(o, do_unlink=True)
    mesh = bpy.data.meshes.new("src")
    bm.to_mesh(mesh)
    bm.free()
    obj = bpy.data.objects.new("src", mesh)
    bpy.context.scene.collection.objects.link(obj)
    for name in ("bark", "snow"):
        obj.data.materials.append(bpy.data.materials.new(name))
    return obj


def decimate(obj, target):
    bpy.context.view_layer.objects.active = obj
    weld = obj.modifiers.new("weld", "WELD")
    weld.merge_threshold = 0.0005
    bpy.ops.object.modifier_apply(modifier=weld.name)
    for _ in range(8):
        tris = sum(len(p.vertices) - 2 for p in obj.data.polygons)
        if tris <= target:
            return tris
        mod = obj.modifiers.new("decimate", "DECIMATE")
        mod.decimate_type = "COLLAPSE"
        mod.ratio = max(0.05, target / tris * 0.97)
        mod.use_collapse_triangulate = True
        bpy.ops.object.modifier_apply(modifier=mod.name)
    return sum(len(p.vertices) - 2 for p in obj.data.polygons)


def build_piece(pid, spec, src_dir):
    obj = load_source(src_dir, spec["source"])
    decimate(obj, spec["target"])
    mesh = obj.data
    verts = [v.co.copy() for v in mesh.vertices]
    lo_z = min(v.z for v in verts)
    hi_z = max(v.z for v in verts)
    # 줄기 밑동(아래 12%)의 가운데를 원점에: 우듬지가 한쪽으로 기운 나무도 줄기가 칸 가운데 선다.
    foot = [v for v in verts if v.z < lo_z + 0.12 * (hi_z - lo_z)]
    centre = Vector((sum(v.x for v in foot) / len(foot), sum(v.y for v in foot) / len(foot), lo_z))
    s = spec["height"] / (hi_z - lo_z)
    piece = pc.Piece(pid)
    made = [piece.bm.verts.new((co - centre) * s) for co in verts]
    snow = pc.PALETTE["snow"][:3]
    for i, poly in enumerate(mesh.polygons):
        if poly.area < 1e-12:
            continue
        rgb = [c * jitter(pid, i) for c in BARK]
        if poly.material_index == 1:
            rgb = [b * (1 - SNOW_MIX) + n * SNOW_MIX for b, n in zip(rgb, snow)]
        try:
            face = piece.bm.faces.new([made[k] for k in poly.vertices])
        except ValueError:
            continue
        face.smooth = False
        for loop in face.loops:
            loop[piece.col] = rgb + [1.0]
    piece.colours = {"bark", "snow"}
    bmesh.ops.remove_doubles(piece.bm, verts=list(piece.bm.verts), dist=1e-6)
    bmesh.ops.delete(piece.bm, geom=[v for v in piece.bm.verts if not v.link_faces], context="VERTS")
    bpy.data.objects.remove(obj, do_unlink=True)
    return piece


def bounds_godot(bm):
    lo = [min(v.co[i] for v in bm.verts) for i in range(3)]
    hi = [max(v.co[i] for v in bm.verts) for i in range(3)]
    # Blender (x, y, z) → glTF/Godot (x, z, -y)
    return [[round(lo[0], 4), round(lo[2], 4), round(-hi[1], 4)], [round(hi[0], 4), round(hi[2], 4), round(-lo[1], 4)]]


def patch_books(out_dir, pid, spec, tris, size, sha, bounds):
    path = out_dir / spec["catalog"]
    book = json.loads(path.read_text(encoding="utf-8"))
    entry = book["assets"][pid]
    old = (entry["lod0_tris"], entry["bytes"], entry["sha256"])
    entry.update({"lod0_tris": tris, "bytes": size, "sha256": sha, "bounds_m": bounds, "colours": ["bark", "snow"],
                  "source_asset": spec["use"], "source_script": "tools/blender/props_field_street.py"})
    common = "dimensions_m" in entry
    if common:
        entry["dimensions_m"] = [round(bounds[1][i] - bounds[0][i], 4) for i in range(3)]
        entry["use"] = spec["use"]
    else:
        entry["judgment"] = spec["use"]
    path.write_text(json.dumps(book, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    readme = out_dir / spec["readme"]
    lines = readme.read_text(encoding="utf-8").split("\n")
    for i, line in enumerate(lines):
        cells = [c.strip() for c in line.split("|")]
        if len(cells) < 4 or cells[1].strip("`") != pid:
            continue
        if cells[2].strip("`") == old[2]:
            lines[i] = line.replace(old[2], sha)
        elif common and len(cells) > 10:
            # 공용 README 표: 이름 | 쓰임 | 발자국 | 높이 | 최빈/원문 | 삼각형/상한 | 크기 | 바이트 | 놓는 법
            cells[2], cells[6] = spec["use"], "%d/600" % tris
            cells[7] = "×".join("%g" % n for n in entry["dimensions_m"])
            cells[8] = str(size)
            lines[i] = "| " + " | ".join(cells[1:-1]) + " |"
        elif not common and len(cells) > 8:
            cells[5], cells[6], cells[7] = str(tris), str(size), spec["use"]
            lines[i] = "| " + " | ".join(cells[1:-1]) + " |"
    readme.write_text("\n".join(lines), encoding="utf-8")
    return old


def preview(piece, path):
    """작업대 렌더로 대각뷰 한 장(면 줄이기로 가지가 무너졌는지 보는 용도)."""
    mesh = bpy.data.meshes.new("pv")
    piece.bm.to_mesh(mesh)
    obj = bpy.data.objects.new("pv", mesh)
    sc = bpy.context.scene
    sc.collection.objects.link(obj)
    mesh.color_attributes.active_color = mesh.color_attributes["Col"]
    sc.render.engine = "BLENDER_WORKBENCH"
    sc.display.shading.color_type = "VERTEX"
    sc.render.resolution_x, sc.render.resolution_y = 420, 520
    cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
    sc.collection.objects.link(cam)
    sc.camera = cam
    cam.data.type = "ORTHO"
    cam.data.ortho_scale = 6.0
    pitch, yaw = math.radians(35), math.radians(45)
    cam.location = (12 * math.cos(pitch) * math.sin(yaw), -12 * math.cos(pitch) * math.cos(yaw), 2.2 + 12 * math.sin(pitch))
    cam.rotation_euler = (math.radians(90) - pitch, 0, yaw)
    sc.render.filepath = str(path)
    bpy.ops.render.render(write_still=True)
    bpy.data.objects.remove(obj, do_unlink=True)
    bpy.data.objects.remove(cam, do_unlink=True)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--repo", required=True)
    parser.add_argument("--src", required=True)
    parser.add_argument("--out", default="")
    parser.add_argument("--preview", default="")
    args = parser.parse_args(sys.argv[sys.argv.index("--") + 1:])
    repo = Path(args.repo).resolve()
    src_dir = Path(args.src).resolve()
    for pid, spec in SWAPS.items():
        out_dir = Path(args.out).resolve() if args.out else repo / "s2/models" / spec["dir"]
        piece = build_piece(pid, spec, src_dir)
        bmesh.ops.triangulate(piece.bm, faces=list(piece.bm.faces))
        tris = len(piece.bm.faces)
        if tris > pc.TRIANGLE_LIMIT:
            raise SystemExit("%s 삼각형 %d > %d" % (pid, tris, pc.TRIANGLE_LIMIT))
        bounds = bounds_godot(piece.bm)
        if args.preview:
            preview(piece, Path(args.preview) / (pid + ".png"))
        path = out_dir / (pid + ".glb")
        pc.export(piece, str(path))
        size, sha = pc.check_glb(str(path), tris)
        old = patch_books(out_dir, pid, spec, tris, size, sha, bounds)
        print("STREET %s tris %d->%d bytes %d->%d bounds %s" % (pid, old[0], tris, old[1], size, bounds))


main()
