"""사는 칸 세 겹 꾸밈 소품(결정 486 칸 안 채움): 바닥·벽·천장 각 셋 이상이 되게 칸마다 나눠 놓는다. Blender 4.5 헤드리스.

blender -b --factory-startup -P tools/blender/train_car_layers.py -- --repo . [--out <폴더>]

천장(대각 보기가 2.2 m 위를 자르므로 모두 그 아래로 매단다):
- hang_lamp: 칸 가운데 높이 2.0 m의 첫 등(train_light.gd 단계 1 석유등) 자리에 매단 석유등. 막대 고리로 걸고 사슬은 쓰지 않는다.
- drying_line: 의자 위에 살짝 처진 짧은 줄과 말리는 벙어리장갑 한 켤레·목도리·걸레.
- hang_pot: 난로 옆 막대 고리에 건 작은 냄비.
벽(뒷벽 창 사이, 뒤가 벽에 붙는다):
- coat_hook: 나무 판에 나무못 셋, 평상 겨울 외투 하나·줄무늬 목도리·뜨개 모자.
- wall_notes: 판에 꽂은 쪽지 다섯(번호·이름 줄 없음).
- wall_rack: 작은 선반에 병 둘·깡통 하나.
바닥:
- rug: 해진 줄무늬 깔개(1 cm 두께, 걷는 줄에 깔려도 걸리지 않는다).
- bucket: 손잡이 달린 쇠 양동이.
- firewood: 난로 옆 쪼갠 장작 다섯.
- basket: 천을 덮은 손바구니.
금지선(project_instructions 민감한 역사, 지도_발주_공통 6장): 사슬·소지품 더미(가방·신발·옷 더미)·군복 색·먹을 것 더미를 만들지 않는다.
외투는 하나만 걸고, 장갑·목도리는 줄에 널린 빨래다.
train_interior.py의 Piece·내보내기·검사를 쓰고(정점색만, 재질·질감 없음) train_car_dress.py의 색을 함께 쓴다.
크기는 지은 모양을 잰 값이다. 새 경로(<이름>.glb)를 만들고 catalog.json·README.md에 줄을 더한다.
"""
import sys
sys.dont_write_bytecode = True

import argparse
from pathlib import Path

import bpy

sys.path.insert(0, str(Path(__file__).resolve().parent))
import train_interior as ti  # noqa: E402
import train_interior_swap as swap  # noqa: E402
import train_car_dress as dress  # noqa: E402  (색 판 EXTRA를 함께 쓴다)

# 선형 RGB. 흰 눈 바탕 칸에서 튀지 않게 어둡고 채도를 누른다.
EXTRA = {
    "glass_warm": (0.78, 0.55, 0.28, 1.0),
    "rope": (0.34, 0.29, 0.22, 1.0),
    "wool_moss": (0.20, 0.22, 0.19, 1.0),
}
ti.PALETTE.update(EXTRA)
USES = {
    "hang_lamp": "사는 칸 가운데 천장(첫 등 자리, 높이 1.86~2.18 m): 막대 고리에 건 석유등",
    "drying_line": "사는 칸 의자 위 천장: 살짝 처진 줄과 말리는 벙어리장갑·목도리·걸레",
    "hang_pot": "사는 칸 난로 옆 천장: 막대 고리에 건 작은 냄비",
    "coat_hook": "사는 칸 뒷벽 창 사이: 나무못 판과 외투 하나·목도리·뜨개 모자",
    "wall_notes": "사는 칸 뒷벽 창 사이: 쪽지 다섯을 꽂은 판",
    "wall_rack": "사는 칸 뒷벽 창 사이: 병 둘·깡통 하나를 얹은 작은 선반",
    "rug": "사는 칸 바닥: 해진 줄무늬 깔개(1 cm)",
    "bucket": "사는 칸 바닥: 손잡이 달린 쇠 양동이",
    "firewood": "사는 칸 난로 옆 바닥: 쪼갠 장작 다섯",
    "basket": "사는 칸 바닥: 천을 덮은 손바구니",
}


def both(p, quad, colour):
    """앞뒤로 보이는 얇은 천 한 장."""
    p.face(quad, colour, (0, 0, 1))
    p.face(quad, colour, (0, 0, -1))


def hang_lamp(p):
    """막대 고리에 건 석유등: 놋 받침, 따뜻한 유리 굴뚝, 놋 뚜껑과 꼭지. 바닥 0, 막대 끝 0.32."""
    p.box((-0.065, 0.065), (0.0, 0.025), (-0.065, 0.065), "brass_dark")
    p.lathe((0.0, 0.0), [(0.025, 0.045, 0.045), (0.08, 0.06, 0.06), (0.15, 0.055, 0.055), (0.18, 0.032, 0.032)], "glass_warm", 6)
    p.box((-0.05, 0.05), (0.18, 0.21), (-0.05, 0.05), "brass")
    p.lathe((0.0, 0.0), [(0.21, 0.026, 0.026), (0.235, 0.01, 0.01)], "brass_dark", 6)
    p.beam((0.0, 0.235, 0.0), (0.0, 0.32, 0.0), 0.005, "iron", 4)


def drying_line(p):
    """양 끝을 막대 고리로 매단 1.2 m 줄(두 마디로 처짐)과 말리는 벙어리장갑 한 켤레·목도리·걸레. 바닥 0, 고리 끝 0.42."""
    knots = [(-0.6, 0.30, 0.0), (0.0, 0.27, 0.0), (0.6, 0.30, 0.0)]
    for a, b in zip(knots, knots[1:]):
        p.beam(a, b, 0.005, "rope", 4)
    for x in (-0.6, 0.6):
        p.beam((x, 0.30, 0.0), (x, 0.42, 0.0), 0.005, "iron", 4)
    both(p, [(-0.48, 0.15, 0.0), (-0.40, 0.15, 0.0), (-0.40, 0.29, 0.0), (-0.48, 0.29, 0.0)], "wool_dark")
    both(p, [(-0.36, 0.15, 0.0), (-0.28, 0.15, 0.0), (-0.28, 0.285, 0.0), (-0.36, 0.285, 0.0)], "wool_dark")
    both(p, [(-0.12, 0.0, 0.0), (-0.02, 0.0, 0.0), (-0.02, 0.27, 0.0), (-0.12, 0.27, 0.0)], "blanket_stripe")
    both(p, [(0.02, 0.04, 0.0), (0.12, 0.04, 0.0), (0.12, 0.27, 0.0), (0.02, 0.27, 0.0)], "blanket_stripe")
    both(p, [(0.25, 0.08, 0.0), (0.50, 0.08, 0.0), (0.50, 0.285, 0.0), (0.25, 0.285, 0.0)], "cloth_faded")


def hang_pot(p):
    """막대 고리에 건 작은 냄비와 들손. 바닥 0, 고리 끝 0.48."""
    p.lathe((0.0, 0.0), [(0.0, 0.10, 0.10), (0.03, 0.125, 0.125), (0.14, 0.13, 0.13), (0.16, 0.14, 0.14)], "iron", 6, "iron_worn")
    p.beam((-0.13, 0.15, 0.0), (0.0, 0.30, 0.0), 0.005, "iron", 4)
    p.beam((0.0, 0.30, 0.0), (0.13, 0.15, 0.0), 0.005, "iron", 4)
    p.beam((0.0, 0.30, 0.0), (0.0, 0.48, 0.0), 0.006, "iron", 4)


def coat_hook(p):
    """벽에 붙인 나무 판(뒤 z −0.03~0)과 나무못 셋, 외투 하나·줄무늬 목도리·뜨개 모자. 바닥 0, 판 위 0.98."""
    p.box((-0.36, 0.36), (0.88, 0.98), (-0.03, 0.0), "wood_dark")
    for x in (-0.24, 0.0, 0.24):
        p.beam((x, 0.92, 0.0), (x, 0.94, 0.07), 0.012, "wood_worn", 4)
    p.box((-0.40, -0.08), (0.12, 0.80), (0.0, 0.07), "wool")
    p.box((-0.37, -0.11), (0.80, 0.88), (0.0, 0.06), "wool_dark")
    p.box((-0.44, -0.38), (0.30, 0.78), (0.005, 0.06), "wool_dark")
    p.box((-0.10, -0.04), (0.40, 0.90), (0.0, 0.03), "blanket_stripe")
    p.lathe((0.24, 0.05), [(0.70, 0.075, 0.05), (0.80, 0.08, 0.055), (0.88, 0.045, 0.03)], "wool_moss", 6)


def wall_notes(p):
    """벽에 붙인 판(뒤 z −0.02~0)에 꽂은 쪽지 다섯. 번호나 이름 줄은 그리지 않는다."""
    p.box((-0.34, 0.34), (0.0, 0.46), (-0.02, 0.0), "wood_worn")
    notes = [((-0.29, -0.10), (0.24, 0.42), "paper"), ((-0.06, 0.12), (0.26, 0.40), "paper_aged"),
             ((0.15, 0.30), (0.20, 0.41), "paper"), ((-0.26, -0.04), (0.04, 0.20), "paper_aged"),
             ((0.02, 0.28), (0.04, 0.17), "cloth_faded")]
    for (x0, x1), (y0, y1), colour in notes:
        p.face([(x0, y0, 0.004), (x1, y0, 0.004), (x1, y1, 0.004), (x0, y1, 0.004)], colour, (0, 0, 1))


def wall_rack(p):
    """벽에 붙인 작은 선반(뒤 z −0.18~0 쪽이 벽)과 받침 둘, 병 둘·깡통 하나."""
    p.box((-0.36, 0.36), (0.0, 0.03), (-0.18, 0.0), "wood")
    for x in (-0.28, 0.28):
        p.box((x - 0.015, x + 0.015), (-0.12, 0.0), (-0.18, -0.15), "wood_dark")
    for x, h in ((-0.18, 0.17), (0.0, 0.13)):
        p.lathe((x, -0.09), [(0.03, 0.045, 0.045), (0.03 + h * 0.8, 0.045, 0.045), (0.03 + h, 0.025, 0.025)], "glass_dark", 6)
    p.box((0.13, 0.25), (0.03, 0.14), (-0.15, -0.03), "iron_worn")


def rug(p):
    """해진 줄무늬 깔개 1.6 × 0.9 m, 1 cm. 위 판에 줄무늬 둘."""
    p.box((-0.8, 0.8), (0.0, 0.010), (-0.45, 0.45), "wool_dark", "wool")
    for x0, x1 in ((-0.62, -0.50), (0.50, 0.62)):
        p.face([(x0, 0.0105, -0.40), (x1, 0.0105, -0.40), (x1, 0.0105, 0.40), (x0, 0.0105, 0.40)], "blanket_stripe", (0, 1, 0))


def bucket(p):
    """손잡이 달린 쇠 양동이(높이 0.28 + 손잡이)."""
    p.lathe((0.0, 0.0), [(0.0, 0.11, 0.11), (0.26, 0.14, 0.14), (0.28, 0.145, 0.145)], "iron_worn", 8, "iron")
    p.beam((-0.14, 0.26, 0.0), (0.0, 0.38, 0.0), 0.006, "iron", 4)
    p.beam((0.0, 0.38, 0.0), (0.14, 0.26, 0.0), 0.006, "iron", 4)


def firewood(p):
    """쪼갠 장작 다섯을 두 단으로(길이 0.5 m)."""
    for x, y in ((-0.16, 0.05), (0.0, 0.05), (0.16, 0.05), (-0.08, 0.15), (0.08, 0.15)):
        p.beam((x, y, -0.25), (x, y, 0.25), 0.055, "wood_worn" if x < 0 else "wood", 5)


def basket(p):
    """천을 덮은 손바구니와 손잡이."""
    p.lathe((0.0, 0.0), [(0.0, 0.14, 0.10), (0.14, 0.18, 0.13), (0.16, 0.17, 0.12)], "wood_worn", 8, "wood")
    p.box((-0.15, 0.15), (0.16, 0.18), (-0.10, 0.10), "cloth_faded")
    p.beam((-0.16, 0.16, 0.0), (0.0, 0.32, 0.0), 0.008, "wood_dark", 4)
    p.beam((0.0, 0.32, 0.0), (0.16, 0.16, 0.0), 0.008, "wood_dark", 4)


BUILDERS = {
    "hang_lamp": hang_lamp, "drying_line": drying_line, "hang_pot": hang_pot,
    "coat_hook": coat_hook, "wall_notes": wall_notes, "wall_rack": wall_rack,
    "rug": rug, "bucket": bucket, "firewood": firewood, "basket": basket,
}


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
        size = dress.measured(piece)
        piece.fit(size)
        tris = len(piece.bm.faces)
        if not 0 < tris <= ti.TRIANGLE_LIMIT:
            raise SystemExit("삼각형 상한 초과: %s %d" % (pid, tris))
        path = out_dir / (pid + ".glb")
        ti.export(piece, path)
        byte_count, digest, bounds = ti.check_glb(path, tris, size)
        palette_extra = {k: list(v[:3]) for k, v in {**dress.EXTRA, **EXTRA}.items() if k in piece.colours}
        rows.append({"id": pid, "status": "ready", "path": "res://models/train_interior/%s.glb" % pid,
                     "reference_size_m": size, "origin": ti.ORIGIN, "triangle_limit": ti.TRIANGLE_LIMIT,
                     "uses": 1, "size_variants": [{"size_m": size, "uses": 1}], "source_materials": {},
                     "dimensions_m": [round(bounds[1][i] - bounds[0][i], 6) for i in range(3)], "bounds_m": bounds,
                     "use": USES[pid], "lod0_tris": tris, "colours": sorted(piece.colours), "bytes": byte_count, "sha256": digest,
                     "source_asset": "손으로 만듦(tools/blender/train_car_layers.py)", "palette_extra": palette_extra})
        print("CAR_LAYERS %s size=%s tris=%d bytes=%d colours=%s" % (pid, size, tris, byte_count, sorted(piece.colours)), flush=True)
    if not args.out:
        swap.patch_books(out_dir, rows)


if __name__ == "__main__":
    main()
