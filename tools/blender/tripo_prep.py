"""Clean an AI-generated mesh (Tripo .glb) into a phone-budget game prop.

Run with Blender (or the `bpy` pip module):
    blender -b -P tools/blender/tripo_prep.py -- --in raw.glb --out out/ --size medium
    python tools/blender/tripo_prep.py --in raw.glb --out out/ --size medium

What it does, in order:
  1. Imports the .glb into an empty scene and joins all meshes into one object.
  2. Merges by distance, deletes loose geometry, recalculates normals.
  3. Scales so the height matches --height, or the longest side matches
     --longest, or keeps the source size, and puts the origin at the bottom
     centre (props stand on the floor).
  4. Decimates to the triangle budget of the size class (LOD0), or to
     --tris when the order sheet gives a budget for this item, and makes
     a lighter copy for LOD1 when the class has one.
  5. Shrinks every texture to the class texture size and drops normal,
     roughness and metallic maps (flat hand-painted look, no PBR).
  6. Optionally pulls saturation down (--desat 0..1).
  7. With --snowcap, pulls a snow cap off the faces that look up
     (NAME_snowcap, same origin, see snowcap() below).
  8. Exports one .glb holding NAME_LOD0 (and NAME_LOD1, NAME_snowcap), and
     a JSON report with triangle counts and texture sizes.

Budgets follow docs/art/tripo_pipeline.md section 3 (proposal values).

Measured on real Tripo files (Blender 4.5.10, 2026-10-10):
  - Smart-mesh output (528 triangles) goes to 400 in seconds and keeps
    its look.
  - HD output (about 1.8 million triangles) keeps its shape down to
    about 5,000 triangles. Pushed to 400 it stops near 1,300 and the
    shape collapses, so the report says ok=false. Order small props as
    smart mesh, or give HD files a budget of 5,000 or more.
"""

import argparse
import json
import math
import os
import sys

import bmesh
import bpy
from mathutils import Vector
from mathutils.bvhtree import BVHTree

BUDGETS = {
    # class: (LOD0 max triangles, LOD1 ratio of LOD0 or None, texture px)
    "small": (400, None, 256),
    "medium": (1500, 0.5, 512),
    "large": (5000, 1 / 3, 1024),
}

# Snow cap (docs/design/briefs/weather_fx.md 13장, proposal values).
# class: most triangles a cap may have; it also may not pass SNOWCAP_SHARE
# of the model's own triangles, unless that is under SNOWCAP_FLOOR.
SNOWCAP_MAX = {"small": 300, "medium": 300, "large": 1200}
SNOWCAP_SHARE = 0.15
# A low-poly prop still needs this many for a rim that follows its outline
# (measured: a 452-triangle crate needs about 100 at a 6 cm rim).
SNOWCAP_FLOOR = 120


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
    p.add_argument("--longest", type=float,
                   help="target length of the longest side in metres")
    p.add_argument("--desat", type=float, default=0.0, help="0 keeps colour, 1 grey")
    p.add_argument("--snowcap", action="store_true",
                   help="add NAME_snowcap pulled from the faces that look up")
    p.add_argument("--snow-angle", type=float, default=40.0,
                   help="faces within this many degrees of straight up take snow")
    p.add_argument("--snow-depth", type=float, default=0.25,
                   help="cap height in metres at full depth (deep winter)")
    p.add_argument("--snow-edge", type=float, default=0.06,
                   help="width in metres of the rim that slopes down to nothing "
                        "(the sampling cell; it grows if the cap is over budget)")
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
    obj.data.validate()
    return obj


def clean(obj):
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.mesh.remove_doubles(threshold=0.0005)
    bpy.ops.mesh.delete_loose()
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.mesh.normals_make_consistent(inside=False)
    bpy.ops.object.mode_set(mode="OBJECT")


def place(obj, height, longest):
    dims = obj.dimensions
    have = dims.z if height else max(dims)
    want = height or longest
    if want and have > 0:
        s = want / have
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
    # One collapse pass can stop short on meshes made of many islands,
    # so repeat with the ratio recomputed until the budget is met.
    bpy.context.view_layer.objects.active = obj
    for _ in range(6):
        now = tri_count(obj)
        if now <= target:
            return
        mod = obj.modifiers.new("decimate", "DECIMATE")
        mod.decimate_type = "COLLAPSE"
        mod.ratio = target / now * 0.97
        mod.use_collapse_triangulate = True
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


def _islands(bm):
    """Groups of faces joined by edges."""
    seen, out = set(), []
    for f in bm.faces:
        if f in seen:
            continue
        group, stack = [], [f]
        seen.add(f)
        while stack:
            g = stack.pop()
            group.append(g)
            for e in g.edges:
                for h in e.link_faces:
                    if h not in seen:
                        seen.add(h)
                        stack.append(h)
        out.append(group)
    return out


def _snow_skin(tree, lo, hi, cell, limit, depth):
    """Sample the model from above on a grid and build the lifted skin."""
    nx = max(2, int(math.ceil((hi.x - lo.x) / cell)))
    ny = max(2, int(math.ceil((hi.y - lo.y) / cell)))
    pad = 0.004  # just inside the bounding box so edge rays still hit
    down = Vector((0.0, 0.0, -1.0))
    z, snow = {}, {}
    for i in range(nx + 1):
        x = lo.x + pad + (hi.x - lo.x - 2 * pad) * i / nx
        for j in range(ny + 1):
            y = lo.y + pad + (hi.y - lo.y - 2 * pad) * j / ny
            loc, normal, _index, _dist = tree.ray_cast(Vector((x, y, hi.z + 1.0)), down)
            if loc is None:
                continue
            z[i, j] = Vector((x, y, loc.z))
            snow[i, j] = normal.z >= limit
    # Let snow bridge what a 25 cm fall buries: bevels, gaps between planks,
    # a thin frame round a lid. A point next to lying snow and within a few
    # centimetres of its height takes snow too. Two rounds, so it never
    # climbs a wall or a windscreen.
    for _ in range(2):
        grown = []
        for (i, j), ok in snow.items():
            if ok:
                continue
            near = [(i + a, j + b) for a in (-1, 0, 1) for b in (-1, 0, 1) if a or b]
            lying = [z[n].z for n in near if snow.get(n)]
            if len(lying) >= 3 and abs(z[i, j].z - sum(lying) / len(lying)) <= 0.05:
                grown.append((i, j))
        for k in grown:
            snow[k] = True
    # Iron out the small bumps of a generated mesh so flat tops fold flat:
    # each point moves to the mean of the neighbours within 3 cm of it.
    for _ in range(2):
        level = {}
        for (i, j), ok in snow.items():
            if not ok:
                continue
            here = z[i, j].z
            near = [z[i + a, j + b].z for a in (-1, 0, 1) for b in (-1, 0, 1)
                    if snow.get((i + a, j + b)) and abs(z[i + a, j + b].z - here) <= 0.03]
            level[i, j] = sum(near) / len(near)
        for k, value in level.items():
            z[k].z = value
    bm = bmesh.new()
    verts = {}
    step = cell * 1.2  # a taller jump inside one cell is a wall, not a slope
    for i in range(nx):
        for j in range(ny):
            ring = [(i, j), (i + 1, j), (i + 1, j + 1), (i, j + 1)]
            if not all(snow.get(k) for k in ring):
                continue
            heights = [z[k].z for k in ring]
            if max(heights) - min(heights) > step:
                continue
            for k in ring:
                if k not in verts:
                    verts[k] = bm.verts.new(z[k])
            bm.faces.new([verts[k] for k in ring])
    # Patches of a few cells are noise (a wiper, a door sill).
    groups = _islands(bm)
    most = max((len(g) for g in groups), default=0)
    dropped = 0
    for g in groups:
        if len(g) < max(4, most * 0.03):
            bmesh.ops.delete(bm, geom=g, context="FACES")
            dropped += 1
    for v in bm.verts:
        if not v.is_boundary:
            v.co.z += depth
    return bm, dropped


def snowcap(obj, name, size, angle_deg, depth, edge):
    """Make NAME_snowcap from what the sky sees of obj.

    The model is sampled from straight above on a grid of edge-sized cells,
    so bumpy or plank-built tops still give one clean sheet. Points whose
    surface is within angle_deg of level take snow. The cap is one skin lying
    on the model: its rim stays on the surface and everything inside the rim
    is lifted straight up by depth. Vertex colour R holds the share of the
    full depth (rim 0, inside 1), so a shader can lower the cap as snow thins
    and drop the rim first. If the cap is over budget the grid is coarsened.
    Returns (object or None, report dict).
    """
    model_tris = tri_count(obj)
    by_share = int(model_tris * SNOWCAP_SHARE)
    budget = min(SNOWCAP_MAX[size], max(by_share, SNOWCAP_FLOOR))
    rule = "class" if budget == SNOWCAP_MAX[size] else (
        "share" if by_share >= SNOWCAP_FLOOR else "floor")
    report = {"budget": budget, "budget_rule": rule, "angle_deg": angle_deg,
              "depth_m": depth, "edge_m": edge, "cell_m": edge, "tris": 0,
              "islands": 0, "dropped_islands": 0, "area_m2": 0.0, "ok": False}
    src = bmesh.new()
    src.from_mesh(obj.data)
    src.normal_update()
    tree = BVHTree.FromBMesh(src)
    lo = Vector((min(v.co.x for v in src.verts), min(v.co.y for v in src.verts),
                 min(v.co.z for v in src.verts)))
    hi = Vector((max(v.co.x for v in src.verts), max(v.co.y for v in src.verts),
                 max(v.co.z for v in src.verts)))
    limit = math.cos(math.radians(angle_deg))
    # Flat stretches fold into a few faces and the outline keeps its detail.
    # Over budget: fold a little harder, then widen the cells. A wide fold
    # angle is not used: it eats the outline.
    tries = [(edge, 4.0), (edge, 8.0)]
    tries += [(edge * 1.35 ** n, 8.0) for n in range(1, 7)]
    bm = None
    for cell, flat_deg in tries:
        if bm:
            bm.free()
        bm, dropped = _snow_skin(tree, lo, hi, cell, limit, depth)
        # The rim (outline and the first ring inside it) is left alone:
        # folding it eats corners.
        rim = {v for v in bm.verts if v.is_boundary}
        rim |= {e.other_vert(v) for v in list(rim) for e in v.link_edges}
        bmesh.ops.dissolve_limit(
            bm, angle_limit=math.radians(flat_deg),
            verts=[v for v in bm.verts if v not in rim],
            edges=[e for e in bm.edges if e.verts[0] not in rim or e.verts[1] not in rim])
        bmesh.ops.triangulate(bm, faces=bm.faces[:])
        if len(bm.faces) <= budget:
            break
    src.free()
    report["cell_m"] = round(cell, 3)
    report["flatten_deg"] = flat_deg
    report["dropped_islands"] = dropped
    if not bm.faces:
        bm.free()
        return None, report
    col = bm.loops.layers.color.new("snow")
    for v in bm.verts:
        share = 0.0 if v.is_boundary else 1.0
        for loop in v.link_loops:
            loop[col] = (share, share, share, 1.0)
    for f in bm.faces:
        f.smooth = True
    mesh = bpy.data.meshes.new(f"{name}_snowcap")
    bm.to_mesh(mesh)
    report["islands"] = len(_islands(bm))
    report["area_m2"] = round(sum(f.calc_area() for f in bm.faces), 3)
    bm.free()
    mesh.color_attributes.active_color = mesh.color_attributes["snow"]
    mesh.color_attributes.render_color_index = mesh.color_attributes.find("snow")
    mat = bpy.data.materials.get("snow") or bpy.data.materials.new("snow")
    mat.diffuse_color = (0.92, 0.93, 0.95, 1.0)
    mesh.materials.append(mat)
    cap = bpy.data.objects.new(f"{name}_snowcap", mesh)
    bpy.context.collection.objects.link(cap)
    report["tris"] = tri_count(cap)
    report["ok"] = report["tris"] <= budget
    return cap, report


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
    place(obj, a.height, a.longest)
    decimate(obj, lod0_max)
    # Collapse can pull the bounding box in, so set the size again.
    place(obj, a.height, a.longest)
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

    extra = {}
    if a.snowcap:
        _cap, report["snowcap"] = snowcap(obj, name, a.size, a.snow_angle,
                                          a.snow_depth, a.snow_edge)
        # The cap carries its depth share in vertex colour R.
        extra = {"export_vertex_color": "ACTIVE",
                 "export_all_vertex_colors": False,
                 "export_active_vertex_color_when_no_material": True}

    out_glb = os.path.join(a.out, f"{name}.glb")
    bpy.ops.export_scene.gltf(filepath=out_glb, export_format="GLB",
                              export_yup=True, export_apply=True, **extra)
    report["glb_bytes"] = os.path.getsize(out_glb)
    over = report["lod0_tris"] > lod0_max
    report["ok"] = not over and report.get("snowcap", {"ok": True})["ok"]
    with open(os.path.join(a.out, f"{name}.json"), "w", encoding="utf-8") as f:
        json.dump(report, f, ensure_ascii=False, indent=2)
    print(json.dumps(report, ensure_ascii=False))


if __name__ == "__main__":
    main()
