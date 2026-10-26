# 지도 조립 소품 gap: 샛길 틈 세 갈래(map-layout data["side_path"] gap_kind), 벽장 선반,
# 샛길 숲 띠의 겨울 잡목 덤불, 마루 밑 숨긴 칸의 들뜬 마루, 숲 띠 빈터의 꺼진 모닥불.
#
# blender -b --factory-startup -P tools/blender/props_field_gap.py -- --repo .
#
# props_field_e.py의 조각·내보내기·검사를 그대로 쓴다(단일 메시, 정점색 Col, 600삼각형 이하,
# rect 가운데 바닥, +Y 위·+Z 앞, facing은 +Y축 -90도씩). 앞(+Z)은 지도 안쪽이다.
# 금지선: 철조망·가시·망루 없음. 철망은 가시 없는 마름모 철망, 쪽문은 자물쇠 없이 열린 문.

import sys
import argparse
import json
import math
import os
from pathlib import Path

import bpy
from mathutils import Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import props_field_e as base  # noqa: E402

TRIANGLE_LIMIT = 600
# 높이 m, 발자국 칸, 맞춤 깊이 상한(m, 없으면 발자국 그대로), solid, 판단.
DESIGNS = {
    "gap_wire": (1.6, [2, 2], None, "none", "none: 마름모 철망 울타리의 한쪽이 기둥째 벌어져 젖혀진 틈, 가시 없음, 밟힌 흙길"),
    "gap_gate": (1.3, [2, 2], None, "none", "none: 판자 울타리 사이 나무 쪽문이 바깥으로 열려 있음, 자물쇠·빗장 없음, 밟힌 흙길"),
    "gap_planks": (1.2, [2, 2], None, "none", "none: 가운데 기둥이 부러져 판자 울타리가 무너지고 판자가 바닥에 흩어진 틈"),
    "small_shelf": (1.4, [1, 1], .42, "low", "low: 벽장·찬방 끝 선 선반, 단지·자루·작은 상자, 현대 가전 없음"),
    "thicket": (1.8, [2, 2], None, "low", "low: 2×2칸을 거의 다 덮는 겨울 잡목 덤불, 네 귀 가까운 낮은 어두운 속심 넷과 바깥·위로 퍼진 밝은 마른 가지 서른"),
    "loose_board": (.045, [1, 1], None, "none", "none: 사는 집 나무 바닥의 마루 판 넷 가운데 한 장이 한쪽 끝 3.5 cm 들리고 조금 돌아감, 밑 틈은 어둡게(마루 밑 숨긴 칸, 카드 K)"),
    "cold_campfire": (.16, [2, 2], None, "none", "none: 숲 띠 빈터의 꺼진 모닥불, 돌 여덟 둥근 테 안 검은 숯 바닥과 회색 재, 탄 막대 셋과 반 탄 장작 하나, 돌 셋 위 옅은 눈"),
}
# 마루 판 색: 소품 셰이더의 색 누르기(weathered.gdshader fx_model_grade 채도 .45·밝기 .82·찬 기운 .35)를
# 지나면 바닥 칸 WOOD(map_view.gd FLOOR_COLORS[3] 0.40, 0.34, 0.29)와 같은 밝기·색이 되게 거꾸로 맞춘 값.
FLOOR_PALETTE = {
    "floor_board": (0.57, 0.33, 0.12, 1.0),
    "floor_board_b": (0.53, 0.31, 0.115, 1.0),
    "floor_board_lift": (0.6, 0.36, 0.14, 1.0),
    "floor_seam": (0.3, 0.17, 0.07, 1.0),
    "floor_hole": (0.09, 0.055, 0.035, 1.0),
}
base.PALETTE.update(FLOOR_PALETTE)
# 꺼진 모닥불: 안개 너머 지도 끝이라 어둡고 차게. 눈은 굽는다(지도 소품 재질은 sheltered라 셰이더가 얹지 않음).
CAMP_PALETTE = {
    "cold_stone": (0.15, 0.16, 0.17, 1.0),
    "ash": (0.22, 0.215, 0.21, 1.0),
    "char": (0.045, 0.04, 0.035, 1.0),
    "snow_dust": (0.48, 0.5, 0.53, 1.0),
}
base.PALETTE.update(CAMP_PALETTE)
# 발자국보다 작게 맞출 것(m): 2×2칸 자리 가운데에 실제 크기로(지름 약 1.25 m).
FIT_CAPS = {"cold_campfire": (1.3, 1.3)}


def slab(p, centre, u, v, w, hu, hv, hw, colour):
    # 축이 기운 상자(판자·쓰러진 문짝). u, v, w는 서로 직교하는 단위 벡터.
    c, u, v, w = Vector(centre), Vector(u).normalized(), Vector(v).normalized(), Vector(w).normalized()
    def corner(su, sv, sw):
        return c + u*(su*hu) + v*(sv*hv) + w*(sw*hw)
    faces = [
        ([corner(1,-1,-1), corner(1,1,-1), corner(1,1,1), corner(1,-1,1)], u),
        ([corner(-1,-1,-1), corner(-1,1,-1), corner(-1,1,1), corner(-1,-1,1)], -u),
        ([corner(-1,1,-1), corner(1,1,-1), corner(1,1,1), corner(-1,1,1)], v),
        ([corner(-1,-1,-1), corner(1,-1,-1), corner(1,-1,1), corner(-1,-1,1)], -v),
        ([corner(-1,-1,1), corner(1,-1,1), corner(1,1,1), corner(-1,1,1)], w),
        ([corner(-1,-1,-1), corner(1,-1,-1), corner(1,1,-1), corner(-1,1,-1)], -w),
    ]
    for pts, normal in faces:
        p.face(pts, colour, normal)


def lattice(p, origin, along, width, z0, z1, step=.3, radius=.012):
    # 가시 없는 마름모 철망: 두 방향 빗금 철사. along은 수평 단위 벡터, 판은 along×위 평면.
    o, a = Vector(origin), Vector(along).normalized()
    h = z1 - z0
    def at(s, z):
        return o + a*s + Vector((0, 0, z))
    n = int((width + h) / step) + 1
    for i in range(n):
        for sign in (1, -1):
            # s - sign*(z - z0) = c, 판 안으로 자른 선분.
            c = -h + i*step if sign == 1 else i*step
            pts = []
            for z in (z0, z1):
                s = c + sign*(z - z0)
                pts.append((s, z))
            (s0, za), (s1, zb) = pts
            # 너비 [0, width]로 자름
            if max(s0, s1) < 0 or min(s0, s1) > width:
                continue
            def clip(sa, za, sb, zb):
                if sa < 0:
                    t = (0 - sa)/(sb - sa); za, sa = za + t*(zb - za), 0.0
                if sa > width:
                    t = (width - sa)/(sb - sa); za, sa = za + t*(zb - za), width
                return sa, za
            s0, za = clip(s0, za, s1, zb)
            s1, zb = clip(s1, zb, s0, za)
            if abs(s1 - s0) + abs(zb - za) < .05:
                continue
            p.beam(at(s0, za), at(s1, zb), radius, "worn_metal", 3)


def path_strip(p, x0, x1, colour="bark"):
    # 틈을 지나며 밟힌 흙길: 안쪽(앞 -Y)에서 바깥(+Y)까지 얇게. 맞춤 깊이도 이것으로 잡힌다.
    p.box((x0, x1), (-.96, .96), (0, .015), colour)


def gap_wire(p):
    for x in (-.94, .94):
        p.beam((x, 0, 0), (x, 0, 1.6), .035, "worn_metal", 6)
    p.beam((-.2, 0, 0), (-.2, 0, 1.6), .03, "worn_metal", 6)
    p.beam((-.94, 0, 1.55), (-.2, 0, 1.55), .02, "worn_metal", 4)
    lattice(p, (-.94, 0, 0), (1, 0, 0), .74, .06, 1.52)
    # 오른쪽 판: 기둥(.94)에 붙은 채 바깥으로 60도 젖혀지고 위가 처짐.
    swing = math.radians(60)
    d = Vector((-math.cos(swing), math.sin(swing), 0))
    lattice(p, (.94, 0, 0), d, .66, .06, 1.25)
    p.beam((.94, 0, 1.25), Vector((.94, 0, 1.25)) + d*.66 + Vector((0, 0, -.12)), .018, "worn_metal", 4)
    # 떨어진 위 가로대 한 토막이 바깥 땅에 비스듬히.
    p.beam((.25, .55, .02), (.85, .9, .02), .02, "rust", 4)
    path_strip(p, -.15, .7)


def picket_run(p, x0, x1, z_top, rails=(.35, 1.0), every=.11, colour_a="worn_wood", colour_b="wood"):
    for z in rails:
        p.box((x0, x1), (.02, .07), (z, z + .07), "worn_wood")
    n = max(1, int((x1 - x0) / every))
    for i in range(n):
        x = x0 + i*every
        p.box((x, x + every*.8), (-.03, .02), (.04, z_top - (i % 3)*.04), colour_a if i % 2 else colour_b)


def gap_gate(p):
    for x in (-.96, -.5, .5, .96):
        p.box((x - .045, x + .045), (-.045, .045), (0, 1.3), "wood")
    picket_run(p, -.92, -.55, 1.18)
    picket_run(p, .55, .92, 1.18)
    # 쪽문: 왼쪽 문기둥(-.5)에 경첩, 바깥(+Y)으로 80도 열림. 세로 판자 다섯과 Z 버팀.
    swing = math.radians(80)
    d = Vector((math.cos(swing), math.sin(swing), 0))
    n = Vector((-math.sin(swing), math.cos(swing), 0))
    hinge = Vector((-.45, .05, 0))
    up = Vector((0, 0, 1))
    for i in range(5):
        s = .1 + i*.18
        slab(p, hinge + d*s + n*.02 + up*.62, d, n, up, .08, .015, .54, "worn_wood" if i % 2 else "wood")
    for z in (.3, .95):
        slab(p, hinge + d*.46 + n*.05 + up*z, d, n, up, .44, .015, .045, "wood")
    a, b = hinge + d*.1 + n*.05 + up*.33, hinge + d*.82 + n*.05 + up*.92
    p.beam(a, b, .03, "wood", 4)
    for z in (.3, .95):
        p.box((-.5, -.42), (.0, .08), (z - .03, z + .03), "iron")
    path_strip(p, -.4, .4)


def gap_planks(p):
    for x in (-.96, .96):
        p.box((x - .045, x + .045), (-.045, .045), (0, 1.2), "wood")
    picket_run(p, -.92, -.55, 1.1, rails=(.3, .9))
    picket_run(p, .62, .92, 1.1, rails=(.3, .9))
    # 부러진 가운데 기둥: 밑동과 바닥에 누운 윗동.
    p.box((-.05, .05), (-.05, .05), (0, .38), "wood")
    slab(p, (.08, -.45, .05), (.25, -1, 0), (1, .25, 0), (0, 0, 1), .38, .045, .045, "wood")
    # 오른쪽 가로대가 안쪽 땅으로 처져 내려옴.
    p.beam((.92, .04, .9), (.3, -.35, .04), .03, "worn_wood", 4)
    p.beam((.92, .04, .32), (.4, -.1, .03), .03, "worn_wood", 4)
    # 바닥에 흩어진 판자(누운 판, 두께는 위로).
    up = Vector((0, 0, 1))
    # 판자 끝이 |y| .95 안에 들게(울타리 줄이 rect 가운데에 남도록).
    for (x, y, ang, colour) in ((-.35, .55, 20, "wood"), (-.1, .2, 75, "worn_wood"), (.2, .65, -30, "worn_wood"),
                                (-.4, -.25, -60, "wood"), (.35, -.7, 10, "worn_wood"), (-.05, -.5, 50, "wood")):
        r = math.radians(ang)
        u = Vector((math.cos(r), math.sin(r), 0))
        v = Vector((-math.sin(r), math.cos(r), 0))
        slab(p, (x, y, .02), u, v, up, .45, .045, .015, colour)
    # 아직 비스듬히 서 있는 판자 하나.
    slab(p, (-.48, .1, .5), (.35, 0, .94), (0, 1, 0), (.94, 0, -.35), .5, .045, .015, "worn_wood")
    path_strip(p, -.35, .45)


def small_shelf(p):
    base.legs(p, 1.0, "wood", .44, .16)
    for z in (.08, .4, .7, .96):
        p.box((-.5, .5), (-.2, .2), (z, z + .04), "worn_wood")
    p.box((-.5, .5), (.17, .2), (.08, 1.0), "wood")
    # 단지·병(둥근 것), 자루 하나, 작은 나무 상자 하나.
    for x, z, colour in ((-.3, .44, "enamel"), (-.08, .44, "stone"), (.25, .74, "enamel"), (.36, .44, "glass")):
        p.lathe((x, 0), [(z, .07, .07), (z + .12, .08, .08), (z + .16, .05, .05)], colour, 8)
    p.lathe((-.25, 0), [(.74, .1, .08), (.84, .11, .09), (.9, .06, .05)], "cloth", 8)
    p.box((.02, .22), (-.12, .1), (.12, .26), "worn_wood")


def thicket(p):
    # 위에서 「가는 막대 줄」도 「어두운 바위」도 아니게(map-layout 지도 그림 10-26 06:5x): 낮은 어두운
    # 속심 셋에서 밝은 마른 가지 서른넷이 퍼진다. 위에서 덮는 넓이는 가지가 얼마나 낮고 멀리
    # 뻗느냐로 정해져(07:2x 「띠가 듬성」), 가지 대부분은 낮게 멀리, 넷에 하나만 높이 선다.
    # 가지 끝은 마른 색(worn_wood·cloth)이라 윗면이 밝다. 맨나무(376삼각형)보다 적게.
    cores = ((-.5, -.36, .44, .4, .4), (.5, -.36, .42, .44, .36), (0, .5, .48, .42, .46))
    for x, y, rx, ry, h in cores:
        p.lathe((x, y), [(0, rx*.9, ry*.9), (h*.6, rx, ry), (h, rx*.45, ry*.4)], "bark", 5)
    tips = ("worn_wood", "cloth", "worn_wood", "wood")
    for i, (x, y, rx, ry, h) in enumerate(cores):
        n = 12 if i == 2 else 11
        for k in range(n):
            a = i*.9 + k*math.tau/n + .25*math.sin(k*2.3 + i)
            tall = (k + i) % 4 == 0
            reach = (.4 if tall else .6) + .28*((k*5 + i*2) % 7)/6
            base = (x + rx*.3*math.cos(a), y + ry*.3*math.sin(a), h*.45)
            tip = (x + reach*math.cos(a), y + reach*math.sin(a), (1.5 + .3*((k + i) % 3)/2) if tall else .55 + .5*((k*3 + i) % 5)/4)
            p.beam(base, tip, .032, tips[(k + i) % 4], 3, .006)


def loose_board(p):
    # 1 m 칸을 덮는 마루 판 넷(앞뒤로 길게, 판 사이 홈). 셋째 판(+X 쪽)이 앞(-Y) 끝에서
    # 3.5 cm 들리고 조금 돌아가, 그 밑과 양옆 홈이 어두운 틈으로 보인다. 바닥과 같은 색이라 칸 둘레는
    # 거의 안 보이고 들린 판만 읽힌다. 바닥 위 두께 9 mm, 몸을 막지 않는다.
    t = .009
    p.box((-.5, -.256), (-.5, .15), (0, t), "floor_board")
    p.box((-.5, -.256), (.158, .5), (0, t), "floor_board_b")
    p.box((-.5, -.256), (.15, .158), (0, t*.45), "floor_seam")
    p.box((-.256, -.248), (-.5, .5), (0, t*.45), "floor_seam")
    p.box((-.248, -.004), (-.5, .5), (0, t), "floor_board_b")
    p.box((.256, .5), (-.5, -.3), (0, t), "floor_board_b")
    p.box((.256, .5), (-.292, .5), (0, t), "floor_board")
    p.box((.256, .5), (-.3, -.292), (0, t*.45), "floor_seam")
    # 들린 판 밑 틈: 판보다 조금 넓어 양옆 홈까지 어둡다.
    p.box((-.004, .256), (-.5, .5), (0, .002), "floor_hole")
    lift = .035
    u = Vector((.03, -1, lift)).normalized()
    v = Vector((0, 0, 1)).cross(u).normalized()
    w = u.cross(v).normalized()
    if w.z < 0:
        w = -w
    slab(p, (.126, -.004, t*.5 + lift*.5), u, v, w, .496, .118, t*.5, "floor_board_lift")


def cold_campfire(p):
    # 돌 여덟을 반지름 .48 테로(크기·높이 조금씩 다르게). 테 안은 검은 숯 바닥 위에 가운데만 회색 재가
    # 조금 비껴 쌓여 각진 판으로 안 읽히게. 가운데서 테로 걸친 탄 막대 넷과, 반만 타고 끝은 껍질이
    # 남은 장작 하나가 돌에 걸침. 돌 셋 꼭대기에 옅은 눈. 몸을 막지 않는다.
    p.lathe((0, 0), [(0, .42, .4), (.018, .36, .34), (.03, .2, .19)], "char", 9)
    p.lathe((.04, -.03), [(.012, .24, .2), (.04, .16, .13), (.055, .05, .04)], "ash", 8)
    stones = []
    for k in range(8):
        a = k*math.tau/8 + .2*math.sin(k*1.7)
        rx, ry = .08 + .03*((k*3) % 4)/3, .07 + .03*((k*5 + 1) % 4)/3
        h = .09 + .05*((k*7 + 2) % 5)/4
        x, y = .48*math.cos(a), .48*math.sin(a)
        p.lathe((x, y), [(0, rx, ry), (h*.55, rx*1.1, ry*1.05), (h, rx*.55, ry*.5)], "cold_stone", 5)
        stones.append((x, y, rx, ry, h))
    for k in (1, 4, 6):
        x, y, rx, ry, h = stones[k]
        p.lathe((x, y), [(h*.85, rx*.6, ry*.55), (h + .012, rx*.3, ry*.28)], "snow_dust", 4)
    for ang, lift in ((30, .12), (120, .1), (205, .03)):
        a = math.radians(ang)
        p.beam((.08*math.cos(a), .08*math.sin(a), .05), (.45*math.cos(a), .45*math.sin(a), lift), .025, "char", 4, .015)
    a = math.radians(295)
    d = Vector((math.cos(a), math.sin(a), 0))
    mid = d*.34 + Vector((0, 0, .08))
    p.beam(d*.06 + Vector((0, 0, .04)), mid, .04, "char", 4, .03)
    p.beam(mid, d*.6 + Vector((0, 0, .13)), .04, "bark", 4)


BUILD = {"gap_wire": gap_wire, "gap_gate": gap_gate, "gap_planks": gap_planks, "small_shelf": small_shelf,
         "thicket": thicket, "loose_board": loose_board, "cold_campfire": cold_campfire}


def write_books(repo, assets, failures):
    out = repo/"s2/models/props_field"
    placement = "rect 가운데 바닥, +Y 위·+Z 앞(지도 안쪽), facing은 +Y축 -90도씩. 발자국 96% 안쪽."
    book = {"version": 1, "batch": "gap", "input": "map-layout data[\"side_path\"] gap_kind 셋 + small_shelf + thicket + loose_board + cold_campfire",
            "expected_kinds": list(DESIGNS), "blender": bpy.app.version_string,
            "palette": base.PALETTE, "colour_encoding": "linear RGBA vertex Col, alpha 1",
            "axis": "+Y up, +Z front", "origin": "footprint_center_floor", "placement": placement,
            "assets": assets, "skipped": {}, "failures": failures}
    (out/"catalog_gap.json").write_text(json.dumps(book, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    lines = ["# 지도 조립 소품 gap", "", "`tools/blender/props_field_gap.py` 자동 장부. 샛길 틈 세 갈래, 벽장 선반, 겨울 잡목 덤불, 들뜬 마루, 꺼진 모닥불, 7종.", "",
             placement, "", "재질·그림·빛·애니메이션 없는 단일 메시/단일 surface, 정점색 Col, 각 600삼각형 이하.",
             "틈 셋은 지나갈 수 있다(solid none). 철조망·가시·망루는 금지선이라 없다.",
             "덤불에는 눈을 굽지 않았다. 지도 소품 재질(prop_models.gd)은 지금 모두 sheltered라 소품 셰이더도 눈을 얹지 않는다. 꺼진 모닥불만 돌 셋 위에 옅은 눈을 굽는다.",
             "들뜬 마루는 바닥 칸 WOOD 색에 맞춘 마루 판 색 다섯을 쓴다(소품 셰이더의 색 누르기를 거꾸로 맞춤). 칸 둘레는 거의 안 보이고 들린 판과 밑 틈만 읽힌다.", "",
             "| 이름 | 발자국 칸 | 높이 m | solid | 삼각형 | 바이트 | SHA-256 | 판단 |",
             "|---|---|---:|---|---:|---:|---|---|"]
    for k, a in assets.items():
        lines.append(f'| `{k}` | {a["footprint_m"][0]}×{a["footprint_m"][1]} | {a["height_m"]} | {a["solid"]} | {a["lod0_tris"]} | {a["bytes"]} | `{a["sha256"]}` | {a["judgment"]} |')
    lines += ["", "팔레트는 E 묶음에 마루 판 색 다섯과 모닥불 색 넷을 더한 것이다(`catalog_gap.json` palette)."]
    (out/"README_gap.md").write_text("\n".join(lines) + "\n", encoding="utf-8")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--repo", required=True)
    args = parser.parse_args(sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else [])
    repo = Path(args.repo).resolve()
    bpy.ops.wm.read_factory_settings(use_empty=True)
    out = repo/"s2/models/props_field"
    assets, failures = {}, []
    for k, (height, footprint, depth_cap, solid, judgment) in DESIGNS.items():
        p = base.Piece(k)
        try:
            BUILD[k](p)
            fit_footprint = list(footprint)
            if depth_cap:
                fit_footprint[1] = min(footprint[1], depth_cap)
            if k in FIT_CAPS:
                fit_footprint = list(FIT_CAPS[k])
            p.fit(fit_footprint, height)
            tris = len(p.bm.faces)
            assert 0 < tris <= TRIANGLE_LIMIT, (k, tris)
            bounds = p.bounds()
            path = out/(k + ".glb")
            base.export(p, path)
            size, digest = base.check_glb(path, tris)
            assets[k] = {"path": "res://models/props_field/" + k + ".glb", "status": "ready",
                         "footprint_m": footprint, "height_m": height, "solid": solid, "lod0_tris": tris,
                         "triangle_limit": TRIANGLE_LIMIT, "bounds_m": bounds,
                         "dimensions_m": [round(bounds[1][i] - bounds[0][i], 5) for i in range(3)],
                         "bytes": size, "sha256": digest, "colours": sorted(p.colours), "judgment": judgment,
                         "placement": "rect 중앙 바닥, +Y 위/+Z 앞, facing -90도씩"}
            print(f"PROP_READY {k} tris={tris} bytes={size}", flush=True)
        except Exception as error:
            failures.append({"kind": k, "error": str(error)})
            print(f"PROP_FAILED {k} {error}", flush=True)
        finally:
            p.bm.free()
    write_books(repo, assets, failures)
    print(f"PROPS_FIELD_GAP generated={len(assets)} expected={len(DESIGNS)} failures={len(failures)}", flush=True)
    if failures:
        raise SystemExit(1)


if __name__ == "__main__":
    main()
