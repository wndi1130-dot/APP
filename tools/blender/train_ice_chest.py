"""창고칸 먹을 것 자리(food_crates)를 얼음 상자 둘로 만든다(금지선: 식량은 창고칸 얼음 상자). Blender 4.5 헤드리스.

blender -b --factory-startup -P tools/blender/train_ice_chest.py -- --repo . [--out <폴더>]

두꺼운 널벽에 쇠띠를 두른 나무 얼음 상자 둘. 왼쪽은 뚜껑을 뒤로 밀어 앞 절반이 열려 안이 보인다: 톱밥 위로 얼음덩이와
천에 싼 꾸러미. 오른쪽은 닫혀 있고 뚜껑 위에 얼음덩이 둘, 모서리마다 서리. 바닥에 얼음 부스러기.
train_interior.py의 Piece·내보내기·검사를 쓰고(정점색만, 재질·질감 없음), 색 판에 얼음·서리 셋을 더한다.
같은 경로(food_crates.glb)를 덮어쓰고 catalog.json·README.md의 그 줄을 고친다(train_interior_swap.py와 같은 방식).
train_interior.py를 다시 돌리면 열린 식량 상자로 돌아가므로, 그 뒤엔 이 스크립트를 다시 돌린다.
"""
import sys
sys.dont_write_bytecode = True

import argparse
import json
import math
from pathlib import Path

import bpy

sys.path.insert(0, str(Path(__file__).resolve().parent))
import train_interior as ti  # noqa: E402
import train_interior_swap as swap  # noqa: E402

PID = "food_crates"
# 선형 RGB. 차갑고 어둡게: 흰 눈 바탕 칸에서 튀지 않게 채도를 누른다.
ICE = {
    "ice": (0.50, 0.60, 0.68, 1.0),
    "ice_dark": (0.30, 0.38, 0.45, 1.0),
    "frost": (0.66, 0.70, 0.74, 1.0),
}
ti.PALETTE.update(ICE)


def obox(p, centre, half, tilt, colour, top=None):
    """x축으로 tilt만큼 기운 상자(가운데·반 크기). 뚜껑처럼 경첩 쪽을 기준으로 돌린 것은 centre로 맞춘다."""
    cx, cy, cz = centre
    hx, hy, hz = half
    c, s = math.cos(tilt), math.sin(tilt)

    def at(x, y, z):
        return (cx + x, cy + y * c - z * s, cz + y * s + z * c)

    def rot(v):
        return (v[0], v[1] * c - v[2] * s, v[1] * s + v[2] * c)

    for sign in (-1, 1):
        p.face([at(sign * hx, -hy, -hz), at(sign * hx, hy, -hz), at(sign * hx, hy, hz), at(sign * hx, -hy, hz)], colour, rot((sign, 0, 0)))
        p.face([at(-hx, sign * hy, -hz), at(hx, sign * hy, -hz), at(hx, sign * hy, hz), at(-hx, sign * hy, hz)],
               top if top and sign > 0 else colour, rot((0, sign, 0)))
        p.face([at(-hx, -hy, sign * hz), at(hx, -hy, sign * hz), at(hx, hy, sign * hz), at(-hx, hy, sign * hz)], colour, rot((0, 0, sign)))


def chest_walls(p, x0, x1, h, z0, z1, wall=0.07):
    """두꺼운 널벽 상자: 바닥, 네 벽(앞뒤는 널 두 줄 색을 엇갈림), 쇠띠 둘, 위 테두리 서리."""
    p.box((x0, x1), (0.0, 0.06), (z0, z1), "wood_dark")
    for k, (y0, y1) in enumerate(((0.06, h * 0.5), (h * 0.5, h))):
        c = "wood" if k == 0 else "wood_worn"
        p.box((x0, x1), (y0, y1), (z1 - wall, z1), c)            # 앞
        p.box((x0, x1), (y0, y1), (z0, z0 + wall), c)            # 뒤
        p.box((x0, x0 + wall), (y0, y1), (z0 + wall, z1 - wall), c)
        p.box((x1 - wall, x1), (y0, y1), (z0 + wall, z1 - wall), c)
    for fx in (0.18, 0.82):
        x = x0 + (x1 - x0) * fx
        p.box((x - 0.035, x + 0.035), (0.04, h + 0.005), (z1, z1 + 0.012), "iron_worn")
    # 앞면 윗단에 낀 서리 띠(아래 끝이 들쭉날쭉), 그리고 위 테두리에 앉은 서리(앞 모서리와 양 끝).
    half = (x1 - x0) / 2.0
    for k, drop in enumerate((0.16, 0.10)):
        p.box((x0 + k * half, x0 + (k + 1) * half), (h - drop, h), (z1, z1 + 0.008), "frost")
    p.box((x0 - 0.005, x1 + 0.005), (h, h + 0.018), (z1 - wall - 0.005, z1 + 0.005), "frost")
    for x in (x0, x1 - wall):
        p.box((x - 0.005, x + wall + 0.005), (h, h + 0.018), (z0, z1), "frost")


def build(p):
    h = 0.72
    z0, z1 = -0.45, 0.45
    # 왼쪽: 열린 얼음 상자.
    ax0, ax1 = -1.47, -0.07
    chest_walls(p, ax0, ax1, h, z0, z1)
    # 안: 톱밥 바닥, 그 위로 얼음덩이와 천에 싼 꾸러미.
    p.box((ax0 + 0.07, ax1 - 0.07), (0.06, 0.56), (z0 + 0.07, z1 - 0.07), "wood_worn")
    # 얼음덩이는 테두리 위로 솟게 쌓아 앞에서도 보이게 한다(높이 y_top까지).
    blocks = [(-1.26, 0.20, 0.88, 0.0), (-1.02, 0.05, 0.96, 0.25), (-0.78, 0.22, 0.86, -0.2), (-0.52, 0.06, 0.94, 0.1),
              (-0.28, 0.22, 0.84, 0.3)]
    for i, (x, z, y_top, tilt) in enumerate(blocks):
        half_y = (y_top - 0.56) * 0.5
        obox(p, (x, 0.56 + half_y, z), (0.12, half_y, 0.10), tilt, "ice_dark" if i % 3 == 1 else "ice", "frost")
    obox(p, (-0.90, 0.66, 0.30), (0.14, 0.07, 0.08), 0.08, "cloth_faded", "cloth")
    # 뚜껑: 뒤로 0.32 밀려 앞 절반이 열렸다(꺼내 가며 밀어 둔 꼴), 조금 비뚤게, 위에 서리.
    p.box((ax0 - 0.02, ax1 + 0.02), (h, h + 0.07), (z0 - 0.34, z1 - 0.30), "wood_dark", "frost")
    for fx in (0.25, 0.75):
        x = ax0 + (ax1 - ax0) * fx
        p.box((x - 0.03, x + 0.03), (h + 0.07, h + 0.08), (z0 - 0.34, z1 - 0.30), "iron_worn")
    # 오른쪽: 닫힌 얼음 상자, 뚜껑 위 서리와 얼음덩이 둘.
    bx0, bx1 = 0.07, 1.47
    chest_walls(p, bx0, bx1, h, z0, z1)
    p.box((bx0 - 0.02, bx1 + 0.02), (h, h + 0.07), (z0 - 0.02, z1 + 0.02), "wood_dark", "frost")
    p.box((bx0 + 0.5, bx0 + 0.9), (h + 0.07, h + 0.09), (z1 - 0.02, z1 + 0.03), "iron")   # 걸쇠 판
    obox(p, (0.62, h + 0.16, -0.05), (0.15, 0.09, 0.12), 0.15, "ice", "frost")
    obox(p, (0.98, h + 0.14, 0.12), (0.12, 0.07, 0.10), -0.2, "ice_dark", "frost")
    # 닫힌 뚜껑 앞 끝에 매달린 고드름.
    for x, length in ((0.30, 0.10), (0.75, 0.06), (1.20, 0.12)):
        p.box((x - 0.025, x + 0.025), (h - length, h), (z1 + 0.01, z1 + 0.035), "ice")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--repo", required=True)
    parser.add_argument("--out", default="")
    args = parser.parse_args(sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else [])
    repo = Path(args.repo).resolve()
    out_dir = Path(args.out).resolve() if args.out else repo / "s2/models/train_interior"
    book = json.loads((repo / "s2/models/train_interior/catalog.json").read_text(encoding="utf-8"))
    size = book["assets"][PID]["reference_size_m"]
    bpy.ops.wm.read_factory_settings(use_empty=True)
    piece = ti.Piece(PID)
    build(piece)
    piece.fit(size)
    tris = len(piece.bm.faces)
    if not 0 < tris <= ti.TRIANGLE_LIMIT:
        raise SystemExit("삼각형 상한 초과: %d" % tris)
    path = out_dir / (PID + ".glb")
    ti.export(piece, path)
    byte_count, digest, bounds = ti.check_glb(path, tris, size)
    old = book["assets"][PID]
    row = {"id": PID, "status": "ready", "path": "res://models/train_interior/%s.glb" % PID,
           "reference_size_m": list(size), "origin": ti.ORIGIN, "triangle_limit": ti.TRIANGLE_LIMIT,
           "uses": old.get("uses", 1), "size_variants": old.get("size_variants", []), "source_materials": old.get("source_materials", {}),
           "dimensions_m": [round(bounds[1][i] - bounds[0][i], 6) for i in range(3)], "bounds_m": bounds,
           "use": "창고칸 얼음 상자 둘: 열린 쪽은 톱밥 위 얼음덩이와 천에 싼 꾸러미, 닫힌 쪽은 서리와 얼음덩이",
           "lod0_tris": tris, "colours": sorted(piece.colours), "bytes": byte_count, "sha256": digest,
           "source_asset": "손으로 만듦(tools/blender/train_ice_chest.py)", "palette_extra": {k: list(v[:3]) for k, v in ICE.items()}}
    print("ICE_CHEST tris=%d bytes=%d colours=%s" % (tris, byte_count, sorted(piece.colours)), flush=True)
    if not args.out:
        swap.patch_books(out_dir, [row])


if __name__ == "__main__":
    main()
