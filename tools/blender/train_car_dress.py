"""열세 칸 꾸밈 소품: 찬 칸(배치 cold), 꼬리칸(배치 coach의 cars 갈래), 기관차 운전실(배치 loco). Blender 4.5 헤드리스.

blender -b --factory-startup -P tools/blender/train_car_dress.py -- --repo . [--out <폴더>]

찬 칸(금지선: decisions.md 냉동칸 줄, handoff_local 민감한 역사 금지선): 시신·덮인 몸 모양·자루·들것·먹을 것은
그리지 않는다. 담요는 펼치지 않고 작게 접어 쌓아 접힌 둥근 모서리가 보이게 한다(누운 사람으로 읽히지 않게).
- blanket_stack: 작게 접어 넷을 쌓은 담요(발자국 0.8×0.55 m).
- lantern_off: 불 꺼진 손등불(어두운 유리).
- blanket_curtain: 천장에 매단 막대에 담요 두 폭을 양 끝으로 걷어 둔 커튼(가운데가 열려 뒤 받침이 보인다).
꼬리칸(셋이 복사한 칸으로 보이지 않게 칸마다 하나씩):
- laundry_line: 머리 위 빨랫줄과 널린 빨래(셔츠·수건·양말 한 켤레·홑이불).
- patch_boards: 창 하나를 막아 못 박은 판자 셋.
기관차 운전실:
- coal_heap: 화실 앞 바닥에 부린 석탄 더미 2.4 m.
train_interior.py의 Piece·내보내기·검사를 쓰고(정점색만, 재질·질감 없음), 색 판에 셋을 더한다.
크기는 지은 모양을 잰 값이다. 새 경로(<이름>.glb)를 만들고 catalog.json·README.md에 줄을 더한다
(train_ice_chest.py와 같은 방식).
"""
import sys
sys.dont_write_bytecode = True

import argparse
import math
from pathlib import Path

import bpy

sys.path.insert(0, str(Path(__file__).resolve().parent))
import train_interior as ti  # noqa: E402
import train_interior_swap as swap  # noqa: E402

# 선형 RGB. 흰 눈 바탕 칸에서 튀지 않게 어둡고 채도를 누른다.
EXTRA = {
    "glass_dark": (0.10, 0.12, 0.13, 1.0),
    "blanket_stripe": (0.22, 0.15, 0.13, 1.0),
    "cloth_blue": (0.20, 0.25, 0.30, 1.0),
    "wool": (0.26, 0.24, 0.22, 1.0),
    "wool_dark": (0.21, 0.20, 0.19, 1.0),
}
ti.PALETTE.update(EXTRA)
USES = {
    "blanket_stack": "찬 칸 뒤 받침 위: 작게 접어 넷을 쌓은 담요(접힌 둥근 모서리가 앞을 본다)",
    "lantern_off": "찬 칸 바닥: 불 꺼진 손등불(어두운 유리, 쇠 받침·뚜껑·고리)",
    "blanket_curtain": "찬 칸 뒤 받침 앞: 천장에 매단 막대에 담요 두 폭을 양 끝으로 걷어 둔 커튼",
    "laundry_line": "꼬리칸 1 머리 위: 살짝 처진 빨랫줄과 셔츠·수건·양말·홑이불",
    "patch_boards": "꼬리칸 2 뒷벽 창 하나: 기울게 못 박은 판자 셋",
    "coal_heap": "기관차 운전실 화실 앞: 바닥에 부린 석탄 더미 2.4 m",
}


def blanket_stack(p):
    """넷을 쌓은 접은 담요: 판마다 조금씩 어긋나고, 앞(+z) 모서리는 접혀 둥글며, 둘째 판은 끝 줄무늬가 보인다."""
    y = 0.0
    for k, (dx, w, c) in enumerate(((0.0, 0.40, "cloth"), (0.03, 0.38, "cloth_faded"), (-0.02, 0.39, "cloth"), (0.02, 0.36, "cloth_faded"))):
        t = 0.07
        p.box((dx - w, dx + w), (y, y + t), (-0.26, 0.23), c)
        p.beam((dx - w, y + t / 2, 0.23), (dx + w, y + t / 2, 0.23), t / 2, "blanket_stripe" if k == 1 else c, 6)
        y += t


def lantern_off(p):
    """불 꺼진 손등불: 쇠 받침, 모서리 기둥 넷, 어두운 유리, 뚜껑과 고리."""
    p.box((-0.08, 0.08), (0.0, 0.03), (-0.08, 0.08), "iron")
    p.box((-0.065, 0.065), (0.03, 0.22), (-0.065, 0.065), "glass_dark")
    for x in (-0.072, 0.072):
        for z in (-0.072, 0.072):
            p.box((x - 0.008, x + 0.008), (0.03, 0.22), (z - 0.008, z + 0.008), "iron")
    p.box((-0.08, 0.08), (0.22, 0.25), (-0.08, 0.08), "iron")
    p.box((-0.04, 0.04), (0.25, 0.29), (-0.04, 0.04), "iron_worn")
    p.beam((-0.05, 0.29, 0.0), (0.0, 0.34, 0.0), 0.008, "iron", 6)
    p.beam((0.0, 0.34, 0.0), (0.05, 0.29, 0.0), 0.008, "iron", 6)


def pleats(p, x0, x1, n, y0, y1, colours, depth=0.03):
    """막대에 걸린 담요 한 폭: n개 주름이 앞뒤로 얕게 오가고(깊으면 밝고 어두운 줄이 세져 줄무늬 천으로 읽힘),
    아래 끝 가까이 어두운 줄무늬 띠. 앞(+z)에서만 보인다."""
    xs = [x0 + (x1 - x0) * i / n for i in range(n + 1)]
    zs = [depth if i % 2 == 0 else -depth for i in range(n + 1)]
    bands = ((y0, y0 + 0.08, None), (y0 + 0.08, y0 + 0.19, "blanket_stripe"), (y0 + 0.19, y1, None))
    for i in range(n):
        out = (-(zs[i + 1] - zs[i]), 0.0, xs[i + 1] - xs[i])
        for b0, b1, band in bands:
            p.face([(xs[i], b0, zs[i]), (xs[i + 1], b0, zs[i + 1]), (xs[i + 1], b1, zs[i + 1]), (xs[i], b1, zs[i])],
                   band or colours[i % len(colours)], out)


def blanket_curtain(p):
    """천장에서 내린 고리 둘에 건 막대, 담요 두 폭을 양 끝으로 걷어 가운데 1.7 m가 열린 커튼. 왼 폭은 허리께를 끈으로 묶었다."""
    p.beam((-1.8, 1.92, 0.0), (1.8, 1.92, 0.0), 0.016, "iron", 6)
    for x in (-1.6, 1.6):
        p.beam((x, 1.92, 0.0), (x, 2.85, 0.0), 0.008, "iron", 4)
    pleats(p, -1.8, -0.72, 9, 0.08, 1.9, ("wool", "wool_dark"))
    pleats(p, 0.98, 1.8, 7, 0.08, 1.9, ("wool_dark", "wool"))
    p.box((-1.8, -0.72), (0.92, 0.98), (-0.06, 0.06), "blanket_stripe")


def laundry_line(p):
    """살짝 처진 빨랫줄(세 마디)과 널린 빨래: 셔츠(몸판과 어깨판), 끝 줄무늬 수건, 양말 한 켤레, 홑이불. 빨래는 앞뒤 두 면."""
    knots = [(-1.5, 0.60, 0.0), (-0.5, 0.56, 0.0), (0.5, 0.56, 0.0), (1.5, 0.60, 0.0)]
    for a, b in zip(knots, knots[1:]):
        p.beam(a, b, 0.006, "wood_worn", 4)

    def hang(x0, x1, y0, y1, colour):
        quad = [(x0, y0, 0.0), (x1, y0, 0.0), (x1, y1, 0.0), (x0, y1, 0.0)]
        p.face(quad, colour, (0, 0, 1))
        p.face(quad, colour, (0, 0, -1))

    hang(-1.20, -0.85, 0.20, 0.47, "paper_aged")
    hang(-1.32, -0.73, 0.47, 0.585, "paper_aged")
    hang(-0.55, -0.20, 0.15, 0.19, "cloth_blue")
    hang(-0.55, -0.20, 0.19, 0.23, "blanket_stripe")
    hang(-0.55, -0.20, 0.23, 0.565, "cloth_blue")
    hang(0.00, 0.08, 0.36, 0.56, "cloth")
    hang(0.12, 0.20, 0.38, 0.56, "cloth")
    hang(0.45, 1.35, 0.0, 0.565, "cloth_faded")


def plank(p, cx, cy, length, height, z0, z1, angle, colour):
    """xy 면에서 angle만큼 기운 판자(뒤 z0, 앞 z1)."""
    c, s = math.cos(angle), math.sin(angle)
    corners = [(-length / 2, -height / 2), (length / 2, -height / 2), (length / 2, height / 2), (-length / 2, height / 2)]

    def at(u, v, z):
        return (cx + u * c - v * s, cy + u * s + v * c, z)

    front = [at(u, v, z1) for u, v in corners]
    back = [at(u, v, z0) for u, v in corners]
    p.face(front, colour, (0, 0, 1))
    p.face(back, colour, (0, 0, -1))
    for i in range(4):
        j = (i + 1) % 4
        mu, mv = (corners[i][0] + corners[j][0]) / 2, (corners[i][1] + corners[j][1]) / 2
        p.face([back[i], back[j], front[j], front[i]], colour, (mu * c - mv * s, mu * s + mv * c, 0.0))


def patch_boards(p):
    """창 하나를 막아 못 박은 판자 셋: 조금씩 기울고 길이가 다르며, 끝마다 못 대가리."""
    for dx, cy, length, angle, colour in ((0.0, 0.16, 1.40, 0.03, "wood_worn"), (0.05, 0.48, 1.30, -0.05, "wood"),
                                          (-0.03, 0.80, 1.44, 0.02, "wood_dark")):
        plank(p, dx, cy, length, 0.2, 0.0, 0.035, angle, colour)
        for end in (-1, 1):
            u = end * (length / 2 - 0.06)
            nx, ny = dx + u * math.cos(angle), cy + u * math.sin(angle)
            p.box((nx - 0.012, nx + 0.012), (ny - 0.012, ny + 0.012), (0.035, 0.045), "iron")


def coal_heap(p):
    """운전실 화실 앞 석탄 더미: 울퉁불퉁한 높이 격자를 면마다 따로 그늘지게 그려 덩어리로 읽히고,
    가장자리는 바닥에 닿는다(12 m 탄수차 더미 coal_pile은 높이만 맞춰 줄면 운전실 밖으로 나간다)."""
    nx, nz, peak = 10, 5, 0.6

    def height(i, k):
        if i in (0, nx) or k in (0, nz):
            return 0.0
        ridge = math.sin(math.pi * k / nz) * min(1.0, math.sin(math.pi * i / nx) * 1.4)
        return max(0.02, peak * ridge + (((i * 7 + k * 13) % 5) - 2) * 0.03)

    grid = [[(-1.2 + 2.4 * i / nx, height(i, k), -0.55 + 1.1 * k / nz) for k in range(nz + 1)] for i in range(nx + 1)]
    for i in range(nx):
        for k in range(nz):
            a, b, c, d = grid[i][k], grid[i + 1][k], grid[i + 1][k + 1], grid[i][k + 1]
            colour = "iron" if (i * 3 + k) % 4 == 0 else "soot"
            p.face([a, b, c], colour, (0, 1, 0))
            p.face([a, c, d], colour, (0, 1, 0))


BUILDERS = {"blanket_stack": blanket_stack, "lantern_off": lantern_off, "blanket_curtain": blanket_curtain,
            "laundry_line": laundry_line, "patch_boards": patch_boards, "coal_heap": coal_heap}


def measured(piece):
    """지은 모양의 경계 크기(게임 축 x·y·z, cm로 반올림). Blender XYZ = 게임 X,-Z,Y."""
    lo = [min(v.co[i] for v in piece.bm.verts) for i in range(3)]
    hi = [max(v.co[i] for v in piece.bm.verts) for i in range(3)]
    return [round(hi[0] - lo[0], 2), round(hi[2] - lo[2], 2), round(hi[1] - lo[1], 2)]


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--repo", required=True)
    parser.add_argument("--out", default="")
    args = parser.parse_args(sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else [])
    repo = Path(args.repo).resolve()
    out_dir = Path(args.out).resolve() if args.out else repo / "s2/models/train_interior"
    out_dir.mkdir(parents=True, exist_ok=True)
    rows = []
    for pid, build in BUILDERS.items():
        bpy.ops.wm.read_factory_settings(use_empty=True)
        piece = ti.Piece(pid)
        build(piece)
        size = measured(piece)
        piece.fit(size)
        tris = len(piece.bm.faces)
        if not 0 < tris <= ti.TRIANGLE_LIMIT:
            raise SystemExit("삼각형 상한 초과: %s %d" % (pid, tris))
        path = out_dir / (pid + ".glb")
        ti.export(piece, path)
        byte_count, digest, bounds = ti.check_glb(path, tris, size)
        rows.append({"id": pid, "status": "ready", "path": "res://models/train_interior/%s.glb" % pid,
                     "reference_size_m": size, "origin": ti.ORIGIN, "triangle_limit": ti.TRIANGLE_LIMIT,
                     "uses": 1, "size_variants": [{"size_m": size, "uses": 1}], "source_materials": {},
                     "dimensions_m": [round(bounds[1][i] - bounds[0][i], 6) for i in range(3)], "bounds_m": bounds,
                     "use": USES[pid], "lod0_tris": tris, "colours": sorted(piece.colours), "bytes": byte_count, "sha256": digest,
                     "source_asset": "손으로 만듦(tools/blender/train_car_dress.py)",
                     "palette_extra": {k: list(v[:3]) for k, v in EXTRA.items() if k in piece.colours}})
        print("CAR_DRESS %s size=%s tris=%d bytes=%d colours=%s" % (pid, size, tris, byte_count, sorted(piece.colours)), flush=True)
    if not args.out:
        swap.patch_books(out_dir, rows)


if __name__ == "__main__":
    main()
