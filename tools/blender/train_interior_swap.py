"""열차 실내 소품 일부를 공개 3D(CC0)로 바꾼다(사용자 말 2026-10-25). Blender 4.5 헤드리스.

blender -b --factory-startup -P tools/blender/train_interior_swap.py -- --repo . --src <원본 폴더> [--only stove,sacks] [--out <폴더>]

원본은 저장소 밖(`C:\\dev\\zombie\\assets_raw\\polyhaven\\models\\<id>\\`)에 둔다: <id>_1k.gltf와 그 .bin·질감.
하는 일: 가져오기 → 한 메시로 합침(copies대로 여러 개 놓기) → 면 줄이기(TARGET 아래) →
면마다 원래 질감 색을 읽어 색 판(train_interior.py PALETTE)에서 그 자리에 허락된 가장 가까운 색으로 칠함 →
자리 크기에 맞춤(상자 한가운데 원점, train_interior.py fit) → 같은 경로로 GLB(재질·질감 없음, Col 정점색) →
catalog.json·README.md의 그 줄을 고침. 원래 질감은 버리므로 상자 글씨·번호·십자 같은 무늬는 남지 않는다.
train_interior.py를 다시 돌리면 이 소품들이 손으로 만든 것으로 돌아가므로, 그 뒤엔 이 스크립트를 다시 돌린다.
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
import train_interior as ti  # noqa: E402  같은 색 판·내보내기·검사를 쓴다

TARGET = 560          # 맞춘 뒤 삼각형(train_interior.py 개별 상한 600 안)
SHARP_DEG = 38.0      # 이보다 꺾인 모서리는 날카롭게 둔다
WOOD = ["wood", "wood_worn", "wood_dark"]
IRON = ["iron", "iron_worn", "soot"]
CLOTH = ["cloth", "cloth_faded"]
PAINTED = WOOD + ["paper_aged"]
# 자리 이름 → 원본, 허락된 색, 여러 개 놓기([x, y, z]는 원본 경계 상자 크기 단위로 옮김(y 위),
# 돌림 rad, 크기 배율, [그 하나만 쓸 색]). size가 있으면 장부에 없는 새 자리다(그 크기로 맞춤).
# 난로는 바꾸지 않는다: 후보 barrel_stove는 칸 난로가 아니라 구멍 뚫린 녹슨 드럼통(모닥불 통)이고,
# 찌그러진 삼각형 9,216개라 600 아래로 줄이면 구겨진 깡통이 된다(2026-10-25 미리보기).
# 연통·문·다리가 있는 지금 난로(train_interior.py)가 칸 안 난로로 더 잘 읽힌다.
SWAPS = {
    # 납작한 자루(0.46×0.18×0.70)를 셋 쌓는다. 가운데 것은 엇갈려 놓아 바닥이 네모에 가깝다.
    "sacks": {"source": "cement_bag", "colours": CLOTH,
              "copies": [[0, 0, 0, 0.0, 1.0], [0.04, 0.85, 0.03, math.pi / 2 + 0.2, 0.97, ["cloth_faded"]], [-0.05, 1.7, -0.04, 0.3, 0.93]],
              "use": "쌓은 자루 셋(Poly Haven cement_bag, CC0, 천 색으로 다시 칠함)"},
    # 긴 나무 상자(0.53×0.46×1.17)를 옆으로 눕히고, 작은 상자 하나를 한쪽 위에 얹는다.
    "crates": {"source": "wooden_crate_02", "colours": WOOD,
               "copies": [[0, 0, 0, math.pi / 2, 1.0], [0.47, 0.75, 0.05, math.pi / 2 + 0.15, 0.5]],
               "use": "나무 상자 둘, 작은 것을 위에(Poly Haven wooden_crate_02, CC0)"},
    "cupboard": {"source": "painted_wooden_shelves", "colours": PAINTED, "copies": [[0, 0, 0, 0.0, 1.0]],
                 "size": [0.52, 1.12, 0.38], "uses": 2, "material": "wood",
                 "use": "칠 벗겨진 작은 선반장, 칸 끝 구석(Poly Haven painted_wooden_shelves, CC0)"},
    "wood_chair": {"source": "painted_wooden_chair_01", "colours": WOOD, "copies": [[0, 0, 0, 0.0, 1.0]],
              "size": [0.44, 0.96, 0.54], "uses": 1, "material": "wood",
              "use": "칠 벗겨진 나무 의자(Poly Haven painted_wooden_chair_01, CC0)"},
}


def srgb_to_linear(c):
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def nearest(rgb, allowed):
    best, best_d = allowed[0], 1e9
    for name in allowed:
        p = ti.PALETTE[name]
        # 밝기 차이를 더 무겁게: 색 판 안에서는 밝고 어두움이 모양을 읽게 한다.
        d = sum((a - b) ** 2 for a, b in zip(rgb, p[:3]))
        lum = (0.2126 * (rgb[0] - p[0]) + 0.7152 * (rgb[1] - p[1]) + 0.0722 * (rgb[2] - p[2])) ** 2
        d += 3.0 * lum
        if d < best_d:
            best, best_d = name, d
    return best


class Sampler:
    """한 재질의 바탕색: 질감이 있으면 그 픽셀, 없으면 바탕색 값."""
    def __init__(self, material):
        self.pixels = None
        self.size = (0, 0)
        self.factor = (0.6, 0.6, 0.6)
        if material is None or not material.use_nodes:
            return
        bsdf = next((n for n in material.node_tree.nodes if n.type == "BSDF_PRINCIPLED"), None)
        if bsdf is None:
            return
        socket = bsdf.inputs["Base Color"]
        self.factor = tuple(socket.default_value[:3])
        image = self._image(socket)
        if image is not None and image.size[0] > 0:
            self.size = (image.size[0], image.size[1])
            self.pixels = list(image.pixels[:])
            self.linear = image.colorspace_settings.name not in ("sRGB",)
            self.factor = (1.0, 1.0, 1.0)

    def _image(self, socket):
        seen = set()
        stack = [l.from_node for l in socket.links]
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

    def colour(self, uv):
        if self.pixels is None or uv is None:
            return self.factor
        w, h = self.size
        x = min(w - 1, max(0, int((uv[0] % 1.0) * w)))
        y = min(h - 1, max(0, int((uv[1] % 1.0) * h)))
        i = (y * w + x) * 4
        rgb = self.pixels[i:i + 3]
        if not self.linear:
            rgb = [srgb_to_linear(c) for c in rgb]
        return tuple(rgb[k] * self.factor[k] for k in range(3))


def load_source(src_dir, source):
    folder = src_dir / source
    files = sorted(folder.glob("*.gltf")) + sorted(folder.glob("*.glb"))
    if not files:
        raise FileNotFoundError("원본 없음: %s" % folder)
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=str(files[0]))
    meshes = [o for o in bpy.context.scene.objects if o.type == "MESH"]
    if not meshes:
        raise ValueError("메시 없음: " + source)
    return meshes


def decimate(obj, target):
    """한 오브젝트를 target 삼각형 아래로. 먼저 붙은 점을 잇고 평평한 면을 합친 뒤
    (상자 면처럼 모양이 그대로인 줄이기), 남는 만큼만 접어 줄인다."""
    bpy.context.view_layer.objects.active = obj
    weld = obj.modifiers.new("weld", "WELD")
    weld.merge_threshold = 0.0005
    bpy.ops.object.modifier_apply(modifier=weld.name)
    if sum(len(p.vertices) - 2 for p in obj.data.polygons) > target:
        flat = obj.modifiers.new("flat", "DECIMATE")
        flat.decimate_type = "DISSOLVE"
        flat.angle_limit = math.radians(2.0)
        bpy.ops.object.modifier_apply(modifier=flat.name)
    for _ in range(6):
        tris = sum(len(p.vertices) - 2 for p in obj.data.polygons)
        if tris <= target:
            return tris
        mod = obj.modifiers.new("decimate", "DECIMATE")
        mod.decimate_type = "COLLAPSE"
        mod.ratio = max(0.01, target / tris * 0.97)
        mod.use_collapse_triangulate = True
        bpy.ops.object.modifier_apply(modifier=mod.name)
    return sum(len(p.vertices) - 2 for p in obj.data.polygons)


def build_piece(pid, spec, src_dir, target):
    meshes = load_source(src_dir, spec["source"])
    # 원본 전체를 한 메시로: 재질별 표본기를 면 재질 번호로 고른다.
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
    per_copy = max(40, target // len(spec["copies"]))
    decimate(obj, per_copy)
    samplers = [Sampler(slot.material) for slot in obj.material_slots] or [Sampler(None)]
    mesh = obj.data
    uv_layer = mesh.uv_layers.active
    lo = Vector([min(v.co[i] for v in mesh.vertices) for i in range(3)])
    hi = Vector([max(v.co[i] for v in mesh.vertices) for i in range(3)])
    span = hi - lo
    centre = (lo + hi) / 2
    piece = ti.Piece(pid)
    for copy in spec["copies"]:
        ox, oy, oz, yaw, scale = copy[:5]
        # 여섯째 칸이 있으면 그 하나만 다른 색으로(자루 하나는 바랜 천).
        allowed = copy[5] if len(copy) > 5 else spec["colours"]
        # [x, y, z]는 glTF 축(Y 위). Blender로: X, -Z, Y.
        offset = Vector((ox * span.x, -oz * span.y, oy * span.z))
        turn = Matrix.Rotation(yaw, 3, "Z")
        verts = {}
        for v in mesh.vertices:
            co = turn @ ((v.co - centre) * scale) + offset
            verts[v.index] = piece.bm.verts.new(co)
        for poly in mesh.polygons:
            if poly.area < 1e-10:
                continue
            uv = None
            if uv_layer is not None:
                us = [uv_layer.data[li].uv for li in poly.loop_indices]
                uv = (sum(u[0] for u in us) / len(us), sum(u[1] for u in us) / len(us))
            sampler = samplers[min(poly.material_index, len(samplers) - 1)]
            name = nearest(sampler.colour(uv), allowed)
            try:
                face = piece.bm.faces.new([verts[i] for i in poly.vertices])
            except ValueError:
                continue
            face.smooth = False
            for loop in face.loops:
                loop[piece.col] = ti.PALETTE[name]
            piece.colours.add(name)
    bmesh.ops.remove_doubles(piece.bm, verts=list(piece.bm.verts), dist=1e-6)
    loose = [v for v in piece.bm.verts if not v.link_faces]
    bmesh.ops.delete(piece.bm, geom=loose, context="VERTS")
    # 둥근 면은 매끈하게, 모서리는 날카롭게(SHARP_DEG보다 꺾인 모서리를 가른다).
    # 줄인 원통이 구겨진 깡통처럼 보이지 않게 한다.
    sharp = [e for e in piece.bm.edges if not e.is_manifold or e.calc_face_angle(math.pi) > math.radians(SHARP_DEG)]
    bmesh.ops.split_edges(piece.bm, edges=sharp)
    for f in piece.bm.faces:
        f.smooth = True
    return piece


def patch_books(out_dir, rows):
    book_path = out_dir / "catalog.json"
    book = json.loads(book_path.read_text(encoding="utf-8"))
    readme_path = out_dir / "README.md"
    readme = readme_path.read_text(encoding="utf-8") if readme_path.exists() else ""
    for r in rows:
        entry = book["assets"].setdefault(r["id"], {})
        old_sha = entry.get("sha256", "")
        entry.update({k: v for k, v in r.items() if k != "id"})
        if old_sha:
            readme = readme.replace("| %s | %s |" % (r["id"], old_sha), "| %s | %s |" % (r["id"], r["sha256"]))
        ti.prepare_import(out_dir, r["id"])
    book["total_triangles"] = sum(int(a["lod0_tris"]) for a in book["assets"].values())
    if book["total_triangles"] > ti.TOTAL_LIMIT:
        raise SystemExit("전체 삼각형 예산 초과: %d" % book["total_triangles"])
    book["swapped"] = {"script": "tools/blender/train_interior_swap.py",
                       "note": "공개 3D(CC0)에서 가져와 면을 줄이고 색 판으로 다시 칠한 소품. 권리 장부에 한 줄씩."}
    book_path.write_text(json.dumps(book, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    marker = "## 공개 3D로 바꾼 것"
    lines = [marker, "", "`tools/blender/train_interior_swap.py`가 위 표의 같은 경로를 덮어쓴다. 전체 삼각형: %d." % book["total_triangles"], ""]
    lines += ["| 이름 | 원본 | 크기 | 삼각형 | 색 | sha256 |", "|---|---|---|---:|---|---|"]
    for pid, a in book["assets"].items():
        if "source_asset" in a:
            lines.append("| %s | %s | %s | %d | %s | %s |" % (pid, a["source_asset"], ti.dimensions(a["dimensions_m"]),
                                                          a["lod0_tris"], ", ".join(a["colours"]), a["sha256"]))
    if marker in readme:
        readme = readme[:readme.index(marker)].rstrip() + "\n"
    readme_path.write_text(readme.rstrip() + "\n\n" + "\n".join(lines) + "\n", encoding="utf-8")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--repo", required=True)
    parser.add_argument("--src", required=True)
    parser.add_argument("--only", default="")
    parser.add_argument("--out", default="")
    args = parser.parse_args(sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else [])
    repo = Path(args.repo).resolve()
    src_dir = Path(args.src).resolve()
    out_dir = Path(args.out).resolve() if args.out else repo / "s2/models/train_interior"
    book = json.loads((repo / "s2/models/train_interior/catalog.json").read_text(encoding="utf-8"))
    ids = [i for i in args.only.split(",") if i] or list(SWAPS)
    rows, failures = [], []
    for pid in ids:
        spec = SWAPS[pid]
        size = spec["size"] if "size" in spec else book["assets"][pid]["reference_size_m"]
        try:
            piece = build_piece(pid, spec, src_dir, TARGET)
            piece.fit(size)
            tris = len(piece.bm.faces)
            if not 0 < tris <= ti.TRIANGLE_LIMIT:
                raise ValueError("삼각형 상한 초과: %d" % tris)
            bpy.ops.wm.read_factory_settings(use_empty=True)
            path = out_dir / (pid + ".glb")
            ti.export(piece, path)
            byte_count, digest, bounds = ti.check_glb(path, tris, size)
            rows.append({"id": pid, "status": "ready", "path": "res://models/train_interior/%s.glb" % pid,
                         "reference_size_m": list(size), "origin": ti.ORIGIN, "triangle_limit": ti.TRIANGLE_LIMIT,
                         "uses": spec.get("uses", book["assets"].get(pid, {}).get("uses", 1)),
                         "size_variants": book["assets"].get(pid, {}).get("size_variants", [{"size_m": list(size), "uses": spec.get("uses", 1)}]),
                         "source_materials": book["assets"].get(pid, {}).get("source_materials", {spec.get("material", "wood"): spec.get("uses", 1)}),
                         "dimensions_m": [round(bounds[1][i] - bounds[0][i], 6) for i in range(3)],
                         "bounds_m": bounds, "use": spec["use"], "lod0_tris": tris, "colours": sorted(piece.colours),
                         "bytes": byte_count, "sha256": digest,
                         "source_asset": "Poly Haven %s (CC0)" % spec["source"]})
            print("SWAP_READY %s tris=%d bytes=%d colours=%s" % (pid, tris, byte_count, sorted(piece.colours)), flush=True)
        except Exception as error:
            failures.append({"id": pid, "reason": "%s: %s" % (type(error).__name__, error)})
            print("SWAP_FAILED %s %s" % (pid, error), flush=True)
    if rows and not args.out:
        patch_books(out_dir, rows)
    print("SWAP done=%d failed=%d" % (len(rows), len(failures)), flush=True)
    if failures:
        raise SystemExit(1)


if __name__ == "__main__":
    main()
