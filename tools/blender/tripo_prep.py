"""Clean an AI-generated mesh (Tripo .glb) into a phone-budget game prop.

Run with Blender (or the `bpy` pip module):
    blender -b -P tools/blender/tripo_prep.py -- --in raw.glb --out out/ --size medium
    python tools/blender/tripo_prep.py --in raw.glb --out out/ --size medium

What it does, in order:
  1. Imports the .glb into an empty scene and joins all meshes into one object.
  2. Merges by distance, deletes loose geometry, recalculates normals.
  3. Scales so the longest side matches --height or keeps the source size,
     and puts the origin at the bottom centre (props stand on the floor).
  4. Decimates to the triangle budget of the size class (LOD0) and makes
     a lighter copy for LOD1 when the class has one.
  5. Shrinks every texture to the class texture size and drops normal,
     roughness and metallic maps (flat hand-painted look, no PBR).
  6. Optionally pulls saturation down (--desat 0..1).
  7. Exports one .glb holding NAME_LOD0 (and NAME_LOD1), and a JSON report
     with triangle counts and texture sizes.

Budgets follow docs/art/tripo_pipeline.md section 3 (proposal values).
"""

import argparse
import json
import os
import sys

import bpy

BUDGETS = {
    # class: (LOD0 max triangles, LOD1 ratio of LOD0 or None, texture px)
    "small": (400, None, 256),
    "medium": (1500, 0.5, 512),
    "large": (5000, 1 / 3, 1024),
}


def parse_args():
    argv = sys.argv
    argv = argv[argv.index("--") + 1:] if "--" in argv else argv[1:]
    p = argparse.ArgumentParser()
    p.add_argument("--in", dest="src", required=True)
    p.add_argument("--out", required=True)
    p.add_argument("--name", help="asset name, default from file name")
    p.add_argument("--size", choices=BUDGETS, default="medium")
    p.add_argument("--tris", type=int, help="override LOD0 triangle budget")
    p.add_argument("--height", type=float, help="target height in metres")
    p.add_argument("--desat", type=float, default=0.0, help="0 keeps colour, 1 grey")
    return p.parse_args(argv)


def tri_count(obj):
    return sum(len(poly.vertices) - 2 for poly in obj.data.polygons)


def reset_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def import_and_join(path):
    bpy.ops.import_scene.gltf(filepath=path)
    meshes = [o for o in bpy.context.scene.objects if o.type == "MESH"]
    if not meshes:
        raise SystemExit(f"no mesh in {path}")
    bpy.ops.object.select_all(action="DESELECT")
    for o in meshes:
        o.select_set(True)
    bpy.context.view_layer.objects.active = meshes[0]
    if len(meshes) > 1:
        bpy.ops.object.join()
    obj = bpy.context.view_layer.objects.active
    # Drop the importer's empties so the object sits at the scene root.
    bpy.ops.object.parent_clear(type="CLEAR_KEEP_TRANSFORM")
    for o in list(bpy.context.scene.objects):
        if o is not obj:
            bpy.data.objects.remove(o, do_unlink=True)
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    return obj


def clean(obj):
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.mesh.remove_doubles(threshold=0.0005)
    bpy.ops.mesh.delete_loose()
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.mesh.normals_make_consistent(inside=False)
    bpy.ops.object.mode_set(mode="OBJECT")


def place(obj, height):
    if height:
        dims = obj.dimensions
        if dims.z > 0:
            s = height / dims.z
            obj.scale = (s, s, s)
            bpy.ops.object.transform_apply(scale=True)
    # Origin at bottom centre of the bounding box.
    xs = [v.co.x for v in obj.data.vertices]
    ys = [v.co.y for v in obj.data.vertices]
    zs = [v.co.z for v in obj.data.vertices]
    cx, cy, bz = (min(xs) + max(xs)) / 2, (min(ys) + max(ys)) / 2, min(zs)
    for v in obj.data.vertices:
        v.co.x -= cx
        v.co.y -= cy
        v.co.z -= bz
    obj.location = (0, 0, 0)


def decimate(obj, target):
    now = tri_count(obj)
    if now <= target:
        return
    mod = obj.modifiers.new("decimate", "DECIMATE")
    mod.decimate_type = "COLLAPSE"
    mod.ratio = max(target / now, 0.0005)
    mod.use_collapse_triangulate = True
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.modifier_apply(modifier=mod.name)


def flatten_materials(obj, tex_px, desat):
    """Keep only base colour, shrink its image, drop PBR detail maps."""
    sizes = []
    for slot in obj.material_slots:
        mat = slot.material
        if not mat or not mat.use_nodes:
            continue
        nodes, links = mat.node_tree.nodes, mat.node_tree.links
        bsdf = next((n for n in nodes if n.type == "BSDF_PRINCIPLED"), None)
        if not bsdf:
            continue
        for name in ("Normal", "Roughness", "Metallic", "Emission Color"):
            sock = bsdf.inputs.get(name)
            if sock:
                for link in list(sock.links):
                    links.remove(link)
        bsdf.inputs["Roughness"].default_value = 0.9
        bsdf.inputs["Metallic"].default_value = 0.0
        for n in list(nodes):
            if n.type == "TEX_IMAGE" and not any(
                l.to_node == bsdf and l.to_socket.name == "Base Color"
                for out in n.outputs for l in out.links
            ):
                nodes.remove(n)
        for n in nodes:
            if n.type == "TEX_IMAGE" and n.image:
                img = n.image
                w, h = img.size
                if max(w, h) > tex_px:
                    k = tex_px / max(w, h)
                    img.scale(max(1, int(w * k)), max(1, int(h * k)))
                if desat > 0:
                    px = list(img.pixels)
                    for i in range(0, len(px), 4):
                        r, g, b = px[i], px[i + 1], px[i + 2]
                        y = 0.299 * r + 0.587 * g + 0.114 * b
                        px[i] = r + (y - r) * desat
                        px[i + 1] = g + (y - g) * desat
                        px[i + 2] = b + (y - b) * desat
                    img.pixels = px
                img.pack()
                sizes.append(list(img.size))
    return sizes


def main():
    a = parse_args()
    name = a.name or os.path.splitext(os.path.basename(a.src))[0]
    lod0_max, lod1_ratio, tex_px = BUDGETS[a.size]
    lod0_max = a.tris or lod0_max
    os.makedirs(a.out, exist_ok=True)

    reset_scene()
    obj = import_and_join(a.src)
    raw_tris = tri_count(obj)
    clean(obj)
    place(obj, a.height)
    decimate(obj, lod0_max)
    tex = flatten_materials(obj, tex_px, a.desat)
    obj.name = f"{name}_LOD0"

    report = {
        "name": name,
        "size_class": a.size,
        "raw_tris": raw_tris,
        "lod0_tris": tri_count(obj),
        "lod0_budget": lod0_max,
        "textures": tex,
        "dimensions_m": [round(d, 3) for d in obj.dimensions],
    }
    if lod1_ratio:
        lod1 = obj.copy()
        lod1.data = obj.data.copy()
        bpy.context.collection.objects.link(lod1)
        lod1.name = f"{name}_LOD1"
        decimate(lod1, int(tri_count(obj) * lod1_ratio))
        report["lod1_tris"] = tri_count(lod1)

    out_glb = os.path.join(a.out, f"{name}.glb")
    bpy.ops.export_scene.gltf(filepath=out_glb, export_format="GLB",
                              export_yup=True, export_apply=True)
    report["glb_bytes"] = os.path.getsize(out_glb)
    over = report["lod0_tris"] > lod0_max
    report["ok"] = not over
    with open(os.path.join(a.out, f"{name}.json"), "w", encoding="utf-8") as f:
        json.dump(report, f, ensure_ascii=False, indent=2)
    print(json.dumps(report, ensure_ascii=False))


if __name__ == "__main__":
    main()
