"""들판 소품 둘(바위·그루터기 무리)을 공개 3D(CC0)로 바꾼다(결정 424·477, 코디네이터 10-27 O1 고리 덮개).
Blender 4.5 헤드리스.

blender -b --factory-startup --python-exit-code 1 -P tools/blender/props_field_cc0.py -- --repo . --src <원본 폴더> [--out <폴더>]

원본은 저장소 밖(`C:\\dev\\zombie\\assets_raw\\polyhaven\\models\\<id>\\`)에 둔다: <id>_1k.gltf와 그 .bin·질감.
하는 일: 고른 오브젝트를 가져와 → 놓기(copies) → 면 줄이기(target 아래) → 꼭짓점마다 원래 바탕색 × AO를
읽어 들판 색 판(props_common.PALETTE)의 바탕 색 쪽으로 당겨 칠함 → 지금 소품의 자리 크기(발자국·높이)에
맞춤 → 같은 경로로 GLB(단일 메시, Col 정점색, 재질·질감 없음) → catalog·README의 그 줄을 고침.
윗면에만 옅은 눈을 조금 얹는다(옛 바위처럼 새하얗게 뜨지 않게, 그래도 고리 덮개가 땅에 묻히지 않게).
"""
import sys
sys.dont_write_bytecode = True

import argparse
import json
import math
from pathlib import Path

import bmesh
import bpy
from mathutils import Matrix, Vector

sys.path.insert(0, str(Path(__file__).resolve().parent))
import props_common as pc  # noqa: E402  같은 색 판·내보내기·검사를 쓴다

PULL = 0.35   # 원래 색을 색 판 바탕 쪽으로 당기는 몫(다른 들판 소품과 한 덩어리로 보이게)
SNOW_FROM, SNOW_FULL = 0.55, 0.9   # 윗면 법선 z가 이 사이에서 눈이 0에서 "snow" 몫까지 는다
# 이름 → 원본 오브젝트, 색 판 바탕, 놓기([x, y] 발자국 m, 돌림 rad, 크기 배율, 삼각형), 자리 크기.
# 삼각형은 고리 덮개 몫으로 낮게 잡는다: 지도 하나에 바위·그루터기 무리가 각각 100개 넘게 깔린다.
SWAPS = {
    "boulder": {"catalog": "catalog_d.json", "readme": "README_d.md", "base": "stone",
                "copies": [["rock_moss_set_02", "rock_moss_set_02_rock11", 0.0, -0.15, 0.0, 1.0, 200],
                           ["rock_moss_set_02", "rock_moss_set_02_rock08", 0.55, 0.75, 0.7, 0.5, 60],
                           ["rock_moss_set_02", "rock_moss_set_02_rock09", -0.6, 0.7, 2.4, 0.4, 60]],
                "size": [1.92, 1.20, 1.92], "sink": 0.04, "snow": 0.3,
                "use": "이끼 낀 둥근 바위와 작은 돌 둘(Poly Haven rock_moss_set_02, CC0)"},
    "stump_cluster": {"catalog": "catalog_c.json", "readme": "README_c.md", "base": "bark",
                      "copies": [["tree_stump_01", "tree_stump_01", -1.05, -0.95, 0.0, 1.0, 100],
                                 ["tree_stump_02", "tree_stump_02", 1.0, -0.65, 1.4, 0.85, 90],
                                 ["tree_stump_01", "tree_stump_01", 0.65, 1.1, 2.6, 0.9, 90],
                                 ["tree_stump_02", "tree_stump_02", -1.05, 1.05, 4.0, 0.6, 70]],
                      "size": [3.84, 0.48, 3.84], "sink": 0.0, "snow": 0.12,
                      "use": "뿌리째 낮게 잘린 그루터기 넷(Poly Haven tree_stump_01·02, CC0)"},
}


def srgb_to_linear(c):
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


class Sampler:
    """바탕색 질감과 (있으면) AO 질감을 UV로 읽는다. 값은 선형."""
    def __init__(self, material):
        self.diff = self.ao = None
        bsdf = None
        if material is not None and material.use_nodes:
            bsdf = next((n for n in material.node_tree.nodes if n.type == "BSDF_PRINCIPLED"), None)
        if bsdf is not None:
            self.diff = self._load(self._image(bsdf.inputs["Base Color"]))
        arm = next((i for i in bpy.data.images if "_arm_" in i.name or "_ao_" in i.name), None)
        self.ao = self._load(arm) if arm is not None else None

    @staticmethod
    def _image(socket):
        stack, seen = [l.from_node for l in socket.links], set()
        while stack:
            node = stack.pop()
            if node in seen:
                continue
            seen.add(node)
            if node.type == "TEX_IMAGE" and node.image is not None:
                return node.image
            for inp in node.inputs:
                stack.extend(l.from_node for l in inp.links)
        return None

    @staticmethod
    def _load(image):
        if image is None or image.size[0] == 0:
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
        rgb = self._px(self.diff, uv) if self.diff and uv is not None else [0.2, 0.2, 0.2]
        if self.ao and uv is not None:
            ao = self._px(self.ao, uv)[0]
            rgb = [c * (0.55 + 0.45 * ao) for c in rgb]
        return rgb


def decimate(obj, target):
    bpy.context.view_layer.objects.active = obj
    weld = obj.modifiers.new("weld", "WELD")
    weld.merge_threshold = 0.001
    bpy.ops.object.modifier_apply(modifier=weld.name)
    for _ in range(8):
        tris = sum(len(p.vertices) - 2 for p in obj.data.polygons)
        if tris <= target:
            return tris
        mod = obj.modifiers.new("decimate", "DECIMATE")
        mod.decimate_type = "COLLAPSE"
        mod.ratio = max(0.002, target / tris * 0.97)
        mod.use_collapse_triangulate = True
        bpy.ops.object.modifier_apply(modifier=mod.name)
    return sum(len(p.vertices) - 2 for p in obj.data.polygons)


def load_part(src_dir, source, name, target):
    """원본 하나를 가져와 그 오브젝트만 남기고, 제자리(가운데·바닥 z=0 그대로)로 옮겨 줄인 메시와 표본기."""
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=str(src_dir / source / (source + "_1k.gltf")))
    obj = bpy.data.objects[name]
    for o in list(bpy.context.scene.objects):
        if o != obj:
            bpy.data.objects.remove(o, do_unlink=True)
    obj.parent = None
    world = obj.matrix_world.copy()
    obj.data.transform(world)
    obj.matrix_world = Matrix.Identity(4)
    lo = Vector([min(v.co[i] for v in obj.data.vertices) for i in range(3)])
    hi = Vector([max(v.co[i] for v in obj.data.vertices) for i in range(3)])
    # 바위 묶음은 따로 놓인 돌 하나라 제 가운데로, 바닥은 원본 땅(z 0)이 없으면 제 밑면으로.
    shift = Vector(((lo.x + hi.x) / 2, (lo.y + hi.y) / 2, lo.z if lo.z > 0.0 else 0.0))
    obj.data.transform(Matrix.Translation(-shift))
    tris = decimate(obj, target)
    sampler = Sampler(obj.material_slots[0].material if obj.material_slots else None)
    mesh = obj.data
    uv_layer = mesh.uv_layers.active
    verts = [v.co.copy() for v in mesh.vertices]
    faces = []
    for poly in mesh.polygons:
        if poly.area < 1e-10:
            continue
        cols = [sampler.colour(uv_layer.data[li].uv if uv_layer else None) for li in poly.loop_indices]
        faces.append((list(poly.vertices), cols, poly.normal.z))
    return verts, faces, tris


def build_piece(pid, spec, src_dir):
    piece = pc.Piece(pid)
    base = pc.PALETTE[spec["base"]]
    tris = 0
    for source, name, x, y, yaw, scale, target in spec["copies"]:
        verts, faces, t = load_part(src_dir, source, name, target)
        tris += t
        turn = Matrix.Rotation(yaw, 3, "Z")
        # 발자국 [x, y]는 glTF 축(+X 오른쪽, +Z 앞). Blender로: X, -Y.
        made = [piece.bm.verts.new(turn @ (co * scale) + Vector((x, -y, 0.0))) for co in verts]
        for idx, cols, up in faces:
            try:
                face = piece.bm.faces.new([made[i] for i in idx])
            except ValueError:
                continue
            for loop, rgb in zip(face.loops, cols):
                rgb = [c * (1 - PULL) + b * PULL for c, b in zip(rgb, base[:3])]
                w = spec["snow"] * min(1.0, max(0.0, (up - SNOW_FROM) / (SNOW_FULL - SNOW_FROM)))
                loop[piece.col] = [c * (1 - w) + n * w for c, n in zip(rgb, pc.PALETTE["snow"][:3])] + [1.0]
    piece.colours.add(spec["base"])
    bmesh.ops.remove_doubles(piece.bm, verts=list(piece.bm.verts), dist=1e-6)
    bmesh.ops.delete(piece.bm, geom=[v for v in piece.bm.verts if not v.link_faces], context="VERTS")
    fit(piece.bm, spec["size"], spec["sink"])
    # 다른 들판 소품처럼 각진 음영: 면마다 밝기가 갈려 먼 고리에서도 돌·나무 결이 읽힌다.
    for f in piece.bm.faces:
        f.smooth = False
    return piece


def fit(bm, size, sink):
    """발자국 가운데를 원점에, 땅(z 0) 위 높이와 발자국이 자리 크기의 96% 안에 들게 한 배율로. 땅 밑 뿌리는 그대로."""
    lo = Vector([min(v.co[i] for v in bm.verts) for i in range(3)])
    hi = Vector([max(v.co[i] for v in bm.verts) for i in range(3)])
    centre = Vector(((lo.x + hi.x) / 2, (lo.y + hi.y) / 2, 0.0))
    w, d, h = hi.x - lo.x, hi.y - lo.y, max(hi.z, 1e-3)
    s = 0.96 * min(size[0] / w, size[2] / d, size[1] / h)
    for v in bm.verts:
        v.co = (v.co - centre) * s - Vector((0, 0, sink))


def bounds_godot(bm):
    lo = [min(v.co[i] for v in bm.verts) for i in range(3)]
    hi = [max(v.co[i] for v in bm.verts) for i in range(3)]
    # Blender (x, y, z) → glTF/Godot (x, z, -y)
    return [[round(lo[0], 4), round(lo[2], 4), round(-hi[1], 4)], [round(hi[0], 4), round(hi[2], 4), round(-lo[1], 4)]]


def patch_books(out_dir, pid, spec, tris, size, sha, bounds):
    path = out_dir / spec["catalog"]
    text = path.read_text(encoding="utf-8")
    book = json.loads(text)
    entry = next(e for e in _walk(book) if e.get("path") == "res://models/props_field/%s.glb" % pid)
    old = (entry["lod0_tris"], entry["bytes"], entry["sha256"])
    entry.update({"lod0_tris": tris, "bytes": size, "sha256": sha, "source_asset": spec["use"],
                  "source_script": "tools/blender/props_field_cc0.py"})
    if "judgment" in entry:
        entry["judgment"] = spec["use"]
    for key in ("bounds_godot", "bounds_m"):
        if key in entry:
            entry[key] = bounds
    # 지도마다 이 장부 소품의 삼각형 합(놓인 수 × 삼각형)과 가장 무거운 지도를 다시 센다.
    census = book.get("census", {})
    if "counts" in census and "triangles_per_map" in census:
        assets = book["assets"]
        for m, counts in census["counts"].items():
            census["triangles_per_map"][m] = sum(n * assets[k]["lod0_tris"] for k, n in counts.items() if k in assets)
        heaviest = max(census["triangles_per_map"], key=census["triangles_per_map"].get)
        if "maximum" in census:
            top = census["maximum"]
            if top.get("map") != heaviest:
                top["map"] = heaviest
                top["counts"] = dict(sorted(census["counts"][heaviest].items(), key=lambda kv: -kv[1])[:3])
            top["triangles"] = census["triangles_per_map"][heaviest]
    path.write_text(json.dumps(book, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    total_tris = sum(a["lod0_tris"] for a in book["assets"].values())
    total_bytes = sum(a["bytes"] for a in book["assets"].values())
    readme = out_dir / spec["readme"]
    lines = readme.read_text(encoding="utf-8").split("\n")
    for i, line in enumerate(lines):
        cells = [c.strip() for c in line.split("|")]
        if len(cells) > 7 and cells[1] == "합계":
            cells[6], cells[7] = str(total_tris), str(total_bytes)
            lines[i] = "| " + " | ".join(cells[1:-1]) + " |"
        if len(cells) > 2 and cells[1].strip("`") == pid:
            if cells[2] == old[2] or cells[2].strip("`") == old[2]:
                lines[i] = line.replace(old[2], sha)
            elif len(cells) > 7:
                lines[i] = line.replace("| %d | %d |" % (old[0], old[1]), "| %d | %d |" % (tris, size))
                lines[i] = lines[i].replace(cells[-2], spec["use"])
    readme.write_text("\n".join(lines), encoding="utf-8")


def _walk(node):
    if isinstance(node, dict):
        yield node
        for v in node.values():
            yield from _walk(v)
    elif isinstance(node, list):
        for v in node:
            yield from _walk(v)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--repo", required=True)
    parser.add_argument("--src", required=True)
    parser.add_argument("--out", default="")
    args = parser.parse_args(sys.argv[sys.argv.index("--") + 1:])
    repo = Path(args.repo).resolve()
    src_dir = Path(args.src).resolve()
    out_dir = Path(args.out).resolve() if args.out else repo / "s2/models/props_field"
    for pid, spec in SWAPS.items():
        piece = build_piece(pid, spec, src_dir)
        tris = sum(len(f.verts) - 2 for f in piece.bm.faces)
        if tris > pc.TRIANGLE_LIMIT:
            raise SystemExit("%s 삼각형 %d > %d" % (pid, tris, pc.TRIANGLE_LIMIT))
        bounds = bounds_godot(piece.bm)
        bmesh.ops.triangulate(piece.bm, faces=list(piece.bm.faces))
        tris = len(piece.bm.faces)
        path = out_dir / (pid + ".glb")
        pc.export(piece, str(path))
        size, sha = pc.check_glb(str(path), tris)
        patch_books(out_dir, pid, spec, tris, size, sha, bounds)
        print("CC0 %s tris %d bytes %d bounds %s" % (pid, tris, size, bounds))


main()
