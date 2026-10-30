"""공개 소품 10종을 손질하고 기본 도형 소품 4종을 만든다.

Blender 4.5 헤드리스. 먼저 PC 문지기의 GODOT_GATE=PASS를 실제 확인한다.
문지기가 막으면 Blender를 시작하지 않는다. Godot 실행·import는 별도다.
blender -b --factory-startup --python-exit-code 1 -P tools/blender/props_field_open.py -- --repo .
선택: 위 명령 끝에 --only kettle,mug
원본은 읽기 전용. 압축 해제·백업·중간 파일은 tools/blender/_open_work/만 쓴다.
Blender X=가로, Z=위, -Y=앞. GLB +Y=위, +Z=앞, 발자국 중심이 원점.
"""
import sys
sys.dont_write_bytecode = True

import argparse
from array import array
import hashlib
import json
import math
import os
from pathlib import Path, PurePosixPath
import shutil
import struct
import zipfile

import bmesh
import bpy
from mathutils import Matrix, Vector
from mathutils.bvhtree import BVHTree

sys.path.insert(0, str(Path(__file__).resolve().parent))
import props_common as pc

RAW = Path("C:/dev/zombie/assets_raw/빈곳채우기_20261030")
EPS = 0.0001
GRADE = dict(saturation=.45, value=.82, cool=[.78, .85, .95], cool_mix=.35)
GRADED_TARGETS = {
    "aluminium": (.54, .57, .60), "dark": (.17, .18, .19),
    "sage": (.46, .55, .45), "wood": (.26, .225, .18),
    "glass": (.12, .15, .14), "cream": (.62, .60, .50),
    "porcelain": (.735, .75, .77), "stone": (.42, .42, .40),
    "worn_wood": (.30, .27, .22), "green": (.22, .30, .25),
    # The grade cannot reach a warm red: the three accents are the reds it can, the poster's
    # being exactly our props' rust (props_common "rust" graded).
    "flag_rust": (.303, .213, .199), "paper": (.55, .52, .44),
    "bluegrey": (.30, .36, .42), "ink": (.15, .15, .16),
    "poster_rust": (.235, .188, .170), "bike_red": (.348, .232, .215),
    "tyre": (.10, .10, .11), "snow": (.74, .77, .79),
}
DESIGNS = json.loads(r'''
{
  "kettle": {
    "source": "usd",
    "weld": 0.00002,
    "source_name": "kitchenware_kettle_r01",
    "limit": 250,
    "mount": "top",
    "footprint": [
      1,
      1
    ],
    "range": [
      [
        0.12,
        0.12,
        0.08
      ],
      [
        0.5,
        0.4,
        0.4
      ]
    ],
    "paints": [
      "aluminium",
      "dark"
    ],
    "note": "금속 몸과 짙은 손잡이·꼭지, 꽃무늬 제거"
  },
  "kettle_enamel": {
    "source": "usd",
    "weld": 0.00002,
    "source_name": "kitchenware_kettle_u01",
    "limit": 250,
    "mount": "top",
    "footprint": [
      1,
      1
    ],
    "range": [
      [
        0.12,
        0.12,
        0.08
      ],
      [
        0.5,
        0.4,
        0.4
      ]
    ],
    "paints": [
      "sage",
      "wood"
    ],
    "note": "연녹 법랑 몸과 짙은 나무 손잡이"
  },
  "cutting_board": {
    "source": "usd",
    "source_name": "kitchenware_cuttingBoard_a01",
    "limit": 80,
    "mount": "top",
    "footprint": [
      1,
      1
    ],
    "range": [
      [
        0.3,
        0.005,
        0.15
      ],
      [
        0.5,
        0.04,
        0.3
      ]
    ],
    "paints": [
      "wood"
    ],
    "lay_flat": true,
    "note": "모로 선 원본을 눕힌 짙은 나무 도마(실측 유지)"
  },
  "vase": {
    "source": "usd",
    "source_name": "misc_glass_vase_a01",
    "limit": 120,
    "mount": "top",
    "footprint": [
      1,
      1
    ],
    "range": [
      [
        0.04,
        0.08,
        0.04
      ],
      [
        0.3,
        0.6,
        0.3
      ]
    ],
    "paints": [
      "glass",
      "tyre"
    ],
    "lathe": 8,
    "note": "원본 윤곽을 높이 일곱 곳에서 재어 8면으로 돌린 불투명 짙은 병유리, 입구는 더 어둡게"
  },
  "alarm_clock": {
    "source": "obj",
    "source_name": "Crosley_Alarm_Clock_Vintage_Metal",
    "limit": 220,
    "mount": "top",
    "footprint": [
      1,
      1
    ],
    "range": [
      [
        0.09,
        0.14,
        0.04
      ],
      [
        0.13,
        0.19,
        0.07
      ]
    ],
    "paints": [
      "dark",
      "cream"
    ],
    "note": "짙은 몸과 민무늬 크림 문자판, 글씨·상표 제거"
  },
  "mug": {
    "source": "obj",
    "source_name": "Threshold_Porcelain_Coffee_Mug_All_Over_Bead_White",
    "limit": 120,
    "mount": "top",
    "footprint": [
      1,
      1
    ],
    "range": [
      [
        0.11,
        0.095,
        0.08
      ],
      [
        0.15,
        0.13,
        0.12
      ]
    ],
    "paints": [
      "porcelain"
    ],
    "hollow": true,
    "note": "손잡이와 안쪽 면을 살린 흰 자기 잔"
  },
  "teapot": {
    "source": "obj",
    "source_name": "Threshold_Porcelain_Teapot_White",
    "limit": 250,
    "mount": "top",
    "footprint": [
      1,
      1
    ],
    "range": [
      [
        0.16,
        0.11,
        0.16
      ],
      [
        0.22,
        0.16,
        0.22
      ]
    ],
    "paints": [
      "porcelain"
    ],
    "note": "뚜껑·주둥이·손잡이를 살린 흰 자기 주전자"
  },
  "serving_bowl": {
    "source": "obj",
    "source_name": "Threshold_Porcelain_Serving_Bowl_Coupe_White",
    "limit": 150,
    "mount": "top",
    "footprint": [
      1,
      1
    ],
    "range": [
      [
        0.18,
        0.05,
        0.18
      ],
      [
        0.24,
        0.09,
        0.24
      ]
    ],
    "paints": [
      "porcelain"
    ],
    "hollow": true,
    "note": "안쪽 바닥과 입구를 살린 흰 자기 큰 사발"
  },
  "dinner_plate": {
    "source": "obj",
    "source_name": "Threshold_Dinner_Plate_Square_Rim_White_Porcelain",
    "limit": 80,
    "mount": "top",
    "footprint": [
      1,
      1
    ],
    "range": [
      [
        0.24,
        0.02,
        0.24
      ],
      [
        0.31,
        0.055,
        0.31
      ]
    ],
    "paints": [
      "porcelain"
    ],
    "hollow": true,
    "note": "낮은 안쪽과 사각 테를 살린 흰 자기 접시"
  },
  "yard_well": {
    "source": "glb",
    "source_name": "scenario_asset_9p84PJEb3SqR6SqvuMKWX1m1",
    "source_sha256": "d135957aef74d60a1d86b948f3d75ff83d36475c516be6c85d18ee404329eadc",
    "limit": 700,
    "mount": "floor",
    "footprint": [
      2,
      2
    ],
    "range": [
      [
        1.3,
        1.8999,
        1.3
      ],
      [
        1.92,
        1.9001,
        1.92
      ]
    ],
    "paints": [
      "stone",
      "wood",
      "worn_wood"
    ],
    "snow": 0.2,
    "height": 1.9,
    "note": "돌·목재·바랜 지붕 널, 윗면에 옅은 눈"
  },
  "mailbox": {
    "source": "made",
    "source_name": "mailbox",
    "limit": 200,
    "mount": "floor",
    "footprint": [
      1,
      1
    ],
    "range": [
      [
        0.19,
        1.2499,
        0.47
      ],
      [
        0.3,
        1.2501,
        0.49
      ]
    ],
    "paints": [
      "green",
      "worn_wood",
      "flag_rust"
    ],
    "snow": 0.2,
    "height": 1.25,
    "note": "나무 기둥과 반원 지붕 통, 작은 녹슨 깃발"
  },
  "wall_poster": {
    "source": "made",
    "source_name": "wall_poster",
    "limit": 150,
    "mount": "wall",
    "footprint": [
      1,
      1
    ],
    "range": [
      [
        0.5999,
        0.8499,
        0.0099
      ],
      [
        0.6001,
        0.8501,
        0.0101
      ]
    ],
    "paints": [
      "paper",
      "bluegrey",
      "ink",
      "poster_rust"
    ],
    "bottom": 1.2,
    "height": 2.05,
    "note": "찢긴 종이에 눈 덮인 산과 기차 색 조각, 글자 없음"
  },
  "wall_clock": {
    "source": "made",
    "source_name": "wall_clock",
    "limit": 250,
    "mount": "wall",
    "footprint": [
      1,
      1
    ],
    "range": [
      [
        0.3199,
        0.3199,
        0.0499
      ],
      [
        0.3201,
        0.3201,
        0.0501
      ]
    ],
    "paints": [
      "wood",
      "cream",
      "ink"
    ],
    "bottom": 1.79,
    "height": 2.11,
    "note": "나무 테·크림 문자판·눈금 12개·바늘 둘, 숫자 없음"
  },
  "bicycle": {
    "source": "made",
    "source_name": "bicycle",
    "limit": 600,
    "mount": "floor",
    "footprint": [
      2,
      1
    ],
    "range": [
      [
        1.6999,
        0.1,
        0.65
      ],
      [
        1.7001,
        0.35,
        0.96
      ]
    ],
    "paints": [
      "bike_red",
      "tyre",
      "aluminium"
    ],
    "snow": 0.15,
    "note": "길이 1.70 m, 지름 0.66 m 바퀴의 쓰러진 옛 자전거"
  }
}
''')


class Blocked(RuntimeError):
    def __init__(self, code, reason):
        self.code = code
        super().__init__(reason)


def require(condition, code, reason):
    if not condition:
        raise Blocked(code, reason)


def grade(rgb):
    value = max(rgb)
    return tuple((value * (1 - GRADE["saturation"]) + c * GRADE["saturation"])
                 * GRADE["value"] * (1 - GRADE["cool_mix"] + cool * GRADE["cool_mix"])
                 for c, cool in zip(rgb, GRADE["cool"]))


def inverse_grade(target):
    # room의 수식. 음수를 자르면 목표가 바뀌므로 해당 종류만 막는다.
    before = [c / (GRADE["value"] * (1 - GRADE["cool_mix"] + cool * GRADE["cool_mix"]))
              for c, cool in zip(target, GRADE["cool"])]
    value = max(before)
    rgb = tuple((c - value * (1 - GRADE["saturation"])) / GRADE["saturation"] for c in before)
    require(all(0 <= c <= 1 for c in rgb), "F-GRADE-GAMUT",
            f"F-NEEDS-USER: 화면 목표 {target}의 역산 {rgb}가 [0,1] 밖")
    require(max(abs(a - b) for a, b in zip(grade(rgb), target)) < 1e-8,
            "F-GRADE-INVERSE", "등급 역산 불일치")
    return (*rgb, 1.0)


def configure_palette(spec):
    for key in spec["paints"] + (["snow"] if spec.get("snow") else []):
        pc.PALETTE["open_" + key] = inverse_grade(GRADED_TARGETS[key])


def source_path(spec):
    name = spec["source_name"]
    if spec["source"] == "usd":
        return RAW / "nvidia_simready" / name / "simready_usd" / ("sm_" + name + "_01.usd")
    if spec["source"] == "obj":
        return RAW / "google_scanned_objects" / (name + ".zip")
    if spec["source"] == "glb":
        return RAW / "scenario_3d" / name / "output.glb"
    return None


def credit(spec):
    name = spec["source_name"]
    if spec["source"] == "usd":
        return "NVIDIA SimReady " + name + ", CC BY 4.0"
    if spec["source"] == "obj":
        return "Google LLC. / Google Scanned Objects " + name + ", CC BY 4.0"
    if spec["source"] == "glb":
        return "Scenario " + name + ", CC BY 4.0"
    return "자체 제작, Blender 기본 도형"


def license_path(spec):
    if spec["source"] == "usd":
        return (RAW / "nvidia_simready" / spec["source_name"] / ".metadata/LICENSE.txt").as_posix()
    if spec["source"] == "obj":
        return source_path(spec).as_posix() + "!metadata.pbtxt"
    if spec["source"] == "glb":
        return "docs/design/rights_ledger.md#1 (제공 목록 근거, 로컬 라이선스 원문 없음)"
    return "tools/blender/props_field_open.py (자체 제작)"


def planned_asset(kind, spec):
    return dict(path="res://models/props_field/" + kind + ".glb", status="not_run",
                source_name=spec["source_name"], source_credit=credit(spec),
                license_path=license_path(spec), footprint_m=spec["footprint"],
                height_m=spec.get("height"), bottom_m=spec.get("bottom", 0.0),
                mount=spec["mount"], triangle_limit=spec["limit"],
                lod0_tris=None, bytes=None, sha256=None, bounds_m=None, dimensions_m=None,
                expected_dimensions_m=spec["range"], judgment=spec["note"],
                verification=dict(blender="not_run", glb="not_run", imports="not_run",
                                  godot_tests="not_run", visual_review="not_verified"))


def backup(path, work):
    if path.is_file():
        digest = hashlib.sha256(path.read_bytes()).hexdigest()
        dest = work / "backups" / (path.name + "." + digest)
        dest.parent.mkdir(parents=True, exist_ok=True)
        if not dest.exists():
            shutil.copy2(path, dest)


def write_books(repo, assets, verification):
    out = repo / "s2/models/props_field"
    work = repo / "tools/blender/_open_work"
    states = [r["status"] for r in assets.values()]
    status = "ready" if all(s == "ready" for s in states) else (
        "blocked" if "blocked" in states else "partial" if "ready" in states else "not_run")
    book = dict(version=1, batch="open", expected_kinds=list(DESIGNS), status=status,
                axis="+Y up, +Z front", origin="footprint_center_floor",
                grade=GRADE, graded_palette_targets=GRADED_TARGETS,
                assets=assets, verification=verification)
    path = out / "catalog_open.json"
    backup(path, work)
    write_whole(path, json.dumps(book, ensure_ascii=False, indent=2) + "\n")
    lines = ["# 공개 소품 open 14종", "",
             "`tools/blender/props_field_open.py` 생성 장부.", "",
             f"상태: **{status}**. ready는 GLB 구조·치수 검사 완료이며 화면 검수와 다르다.",
             "NVIDIA 4종·Google 5종·Scenario 1종은 CC BY 4.0, 나머지 4종은 자체 제작이다.",
             "원본과 라이선스 경로는 catalog_open.json, 상세 조사와 가정은 _open_work/inspect_sources.md.", "",
             "발자국 가운데 바닥, +Z 앞 / -Z 등. 작은 소품은 밑면 0, 벽걸이는 높이를 모형에 넣는다.",
             "단일 메시·단일 surface·Col 정점색, 재질·이미지·질감 없음. 발자국 96% 이내.", "",
             "| 종류 | 원본 | 출처 | 삼각형 / 상한 | 위끝 m | 바이트 | SHA-256 | 상태 |",
             "|---|---|---|---:|---:|---:|---|---|"]
    for kind, row in assets.items():
        show = lambda v: "—" if v is None else str(v)
        lines.append(f'| `{kind}` | `{row["source_name"]}` | {row["source_credit"]} | {show(row["lod0_tris"])} / {row["triangle_limit"]} | '
                     f'{show(row["height_m"])} | {show(row["bytes"])} | {show(row["sha256"])} | {row["status"]} |')
    lines += ["", "## 손질", ""]
    for kind, row in assets.items():
        reason = (" — " + row["blocked_reason"]) if row.get("blocked_reason") else ""
        lines.append(f'- `{kind}`: {row["judgment"]}{reason}')
    lines += ["", "weld 0.001 m 뒤 collapse, 안쪽 면 보호·공동 깊이 비교. 원본 실제 크기는 작은 소품에서 유지한다.",
              "USD는 실제 stage 단위 변환, OBJ는 Z 위. 주전자 재질 subset과 UV 밝기 영역으로 색을 나눈다.",
              "면별 밝기는 ±8% 안, 각진 음영. 지붕·통·자전거의 최종 윗면에만 눈을 섞는다.",
              "등급이 따뜻한 빨강에 못 닿아 우편함 깃발·포스터 녹·자전거 빨강은 닿는 가장 붉은 색으로 낮췄다(포스터 녹 = 우리 소품 rust).",
              ("Scenario 라이선스는 허깅페이스 scenario-labs/3d-collection 목록의 그 줄 license 칸(cc-by-4.0)이고, 원본 GLB SHA-256이 목록 값과 같다(굽기 때 대조)."
               if (assets.get("yard_well", {}).get("source") or {}).get("license_verification", "").startswith("list_row")
               else "Scenario 원본 해시 대조: 미확인(우물이 이 판에서 구워지지 않음)."),
              "wall_poster 밑면 1.20 m, wall_clock 중심 1.95 m. mailbox 통과 기둥은 0.04 m 겹친다.",
              "직접 만든 네 종에는 제3자 CC BY 고지를 붙이지 않는다.", "",
              "## 실행", "",
              "먼저 PC 문지기의 GODOT_GATE=PASS를 실제 확인한다. 실패하면 Blender를 시작하지 않는다.",
              "```text",
              "blender -b --factory-startup --python-exit-code 1 -P tools/blender/props_field_open.py -- --repo .",
              "# 일부만 다시 만들기: 위 명령 끝에 --only kettle,mug",
              "```", "",
              "선택하지 않은 장부 행은 보존한다. 실패한 종류는 blocked로 기록하고 다음 종류로 진행한다.",
              "기존 생성물은 _open_work/backups/에 SHA-256별로 보관한 뒤 교체한다.",
              "최종 GLB를 재가져와 Workbench 정점색으로 _open_sheet.png를 만든다.",
              "수평 45°·내려다봄 35°, 모두 같은 축척, 키 1.75 m 사람 막대. 누락 종류도 상태 이름표를 남긴다.",
              "그림과 _open_work/는 git 제외. Godot import·시험은 별도이며 현재 GLB가 없으면 시험 실패가 맞다.",
              "", "## 확인", "", "```json",
              json.dumps(verification, ensure_ascii=False, indent=2), "```", ""]
    path = out / "README_open.md"
    backup(path, work)
    write_whole(path, "\n".join(lines))


def write_whole(path, text):
    # 쓰다 끊겨도 옛 장부가 그대로 남게: 옆의 임시 파일을 다 쓴 뒤 한 번에 바꾼다.
    tmp = path.with_name(path.name + ".tmp")
    tmp.write_text(text, encoding="utf-8")
    os.replace(tmp, path)


def bounds(points):
    points = list(points)
    require(bool(points), "F-EMPTY-MESH", "꼭짓점 없음")
    return [Vector([min(p[i] for p in points) for i in range(3)]),
            Vector([max(p[i] for p in points) for i in range(3)])]


def validate_bounds(limits, spec):
    lo, hi = limits
    size = hi - lo
    for i in range(3):
        require(spec["range"][0][i] - EPS <= size[i] <= spec["range"][1][i] + EPS,
                "F-SIZE", f"Godot 치수 {list(size)}가 기대 범위 {spec['range']} 밖")
    for axis, cells in ((0, spec["footprint"][0]), (2, spec["footprint"][1])):
        require(size[axis] <= cells * .96 + EPS and abs(lo[axis] + hi[axis]) < EPS,
                "F-FOOTPRINT", "발자국 96% 또는 가로·깊이 중심 실패")
    require(abs(lo.y - spec.get("bottom", 0.0)) < EPS, "F-ORIGIN", "밑면 높이 불일치")
    if spec.get("height") is not None:
        require(abs(hi.y - spec["height"]) < EPS, "F-HEIGHT", "위끝 높이 불일치")
    if spec["mount"] == "wall":
        require(lo.y >= 1.0, "F-MOUNT", "벽걸이가 너무 낮음")
    if spec["footprint"] == [2, 1]:
        require(size.x > size.z, "F-AXIS", "긴 쪽이 X가 아님")


def reset_scene():
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    for collection in (bpy.data.meshes, bpy.data.materials, bpy.data.images):
        for item in list(collection):
            if item.users == 0:
                collection.remove(item)


class Piece(pc.Piece):
    # 도형 도우미는 그대로 쓰고 공용 도우미의 강한 색 흔들림만 대체한다.
    def __init__(self, kind):
        super().__init__(kind)
        self.paint = self.bm.faces.layers.int.new("open_paint")
        self.keys = list(GRADED_TARGETS)

    def face(self, pts, colour, outward):
        super().face(pts, colour, outward)
        self.bm.faces.ensure_lookup_table()
        face = self.bm.faces[-1]
        face[self.paint] = self.keys.index(colour.removeprefix("open_"))

    def finish_colours(self, snow=0.0):
        self.bm.normal_update()
        total, count, paints = [0.0, 0.0, 0.0], 0, set()
        for face in self.bm.faces:
            target = GRADED_TARGETS[self.keys[face[self.paint]]]
            weight = snow * max(0.0, min(1.0, (face.normal.z - .55) / .35))
            target = tuple(a * (1 - weight) + b * weight for a, b in zip(target, GRADED_TARGETS["snow"]))
            base = inverse_grade(target)
            paints.add(self.keys[face[self.paint]])
            for i in range(3):
                total[i] += base[i] * len(face.loops)
            count += len(face.loops)
            at = face.calc_center_median()
            shade = 1 + .08 * math.sin(at.x * 37 + at.y * 19 + at.z * 29)
            shade = min(shade, 1.0 / max(base[:3]))
            for loop in face.loops:
                loop[self.col] = (*(v * shade for v in base[:3]), 1.0)
            face.smooth = False
        self.intended_rgb = [round(v / max(count, 1), 4) for v in total]
        self.paint_count = len(paints)


def unpack_obj(spec, work, digest):
    dest = work / "sources" / (spec["source_name"] + "-" + digest[:16])
    dest.mkdir(parents=True, exist_ok=True)
    members = ("meshes/model.obj", "meshes/model.mtl", "materials/textures/texture.png", "metadata.pbtxt")
    with zipfile.ZipFile(source_path(spec)) as archive:
        for name in members:
            relative = PurePosixPath(name)
            target = dest.joinpath(*relative.parts)
            require(target.resolve().is_relative_to(work.resolve()), "F-SOURCE-PATH", "압축 해제 경계 밖")
            info = archive.getinfo(name)
            require(not info.is_dir() and (info.external_attr >> 16) & 0o170000 != 0o120000,
                    "F-SOURCE-PATH", "압축 안 링크 또는 폴더")
            target.parent.mkdir(parents=True, exist_ok=True)
            data = archive.read(name)
            if target.exists():
                require(target.read_bytes() == data, "F-WORK-CONFLICT", "기존 압축 해제 파일이 바뀜: " + name)
            else:
                target.write_bytes(data)
    metadata = (dest / "metadata.pbtxt").read_text(encoding="utf-8")
    require("Creative Commons Attribution 4.0 International" in metadata,
            "F-LICENSE", "Google metadata의 CC BY 4.0 고지 불일치")
    return dest


def import_usd(path):
    try:
        from pxr import Usd, UsdGeom
    except ImportError as exc:
        raise Blocked("F-USD-CAPABILITY", "최상위 USD 단위를 읽을 pxr가 없음") from exc
    stage = Usd.Stage.Open(str(path))
    require(stage is not None, "F-USD-STAGE", "USD stage를 열지 못함")
    units = float(UsdGeom.GetStageMetersPerUnit(stage))
    up = str(UsdGeom.GetStageUpAxis(stage))
    require(abs(units - 1.0) < 1e-9 and up == "Z", "F-USD-UNITS",
            f"실제 stage 단위/축이 조사값과 다름: metersPerUnit={units}, up={up}")
    mesh_count = sum(prim.IsA(UsdGeom.Mesh) for prim in stage.Traverse())
    properties = bpy.ops.wm.usd_import.get_rna_type().properties
    unit_key = next((key for key in ("apply_unit_conversion_scale", "apply_unit_conversion")
                     if key in properties), None)
    require(unit_key is not None, "F-USD-CAPABILITY", "USD 단위 변환 옵션을 확인할 수 없음")
    require("import_textures_mode" in properties, "F-USD-CAPABILITY", "USD 질감 복사 제어 옵션 없음")
    modes = {item.identifier for item in properties["import_textures_mode"].enum_items}
    require("IMPORT_NONE" in modes, "F-USD-CAPABILITY", "USD 원본 질감 참조 모드 없음")
    options = dict(import_cameras=False, import_lights=False, import_volumes=False,
                   import_shapes=False, import_skeletons=False, import_blendshapes=False,
                   import_meshes=True, import_materials=True, import_usd_preview=True,
                   import_subdiv=False, import_visible_only=True, import_defined_only=True,
                   import_guide=False, import_proxy=False, import_render=True,
                   support_scene_instancing=False, create_collection=False,
                   set_frame_range=False, import_textures_mode="IMPORT_NONE", scale=1.0)
    options = {key: value for key, value in options.items() if key in properties}
    options[unit_key] = True
    bpy.ops.wm.usd_import(filepath=str(path), **options)
    return dict(meters_per_unit=units, up_axis=up, stage_meshes=mesh_count,
                unit_conversion_option=unit_key, unit_conversion=True)


def joined_mesh(kind):
    bpy.context.view_layer.update()
    objects = [obj for obj in bpy.context.scene.objects if obj.type == "MESH"]
    require(bool(objects), "F-EMPTY-MESH", "원본에서 메시를 찾지 못함")
    # 부모를 지우기 전에 모든 world 행렬을 보관한다.
    transforms = [(obj, obj.matrix_world.copy()) for obj in objects]
    for obj, world in transforms:
        obj.data = obj.data.copy()
        obj.parent = None
        obj.data.transform(world)
        if world.determinant() < 0:
            # 거울 변환(음수 배율)을 메시에 구우면 면이 뒤집힌다: 감김을 되돌린다.
            bm = bmesh.new()
            bm.from_mesh(obj.data)
            bmesh.ops.reverse_faces(bm, faces=bm.faces[:])
            bm.to_mesh(obj.data)
            bm.free()
        obj.matrix_world = Matrix.Identity(4)
        obj.hide_set(False)
        obj.hide_viewport = False
    bpy.ops.object.select_all(action="DESELECT")
    for obj in objects:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = objects[0]
    bpy.ops.object.join()
    obj = bpy.context.object
    obj.name = kind
    for other in list(bpy.context.scene.objects):
        if other != obj:
            bpy.data.objects.remove(other, do_unlink=True)
    obj.data.update()
    return obj, len(objects)


def centre_mesh(mesh, bottom=0.0):
    lo, hi = bounds(v.co for v in mesh.vertices)
    mesh.transform(Matrix.Translation(Vector((-(lo.x + hi.x) / 2,
                                              -(lo.y + hi.y) / 2, bottom - lo.z))))
    mesh.update()


def srgb_to_linear(value):
    return value / 12.92 if value <= .04045 else ((value + .055) / 1.055) ** 2.4


class Sampler:
    def __init__(self, material=None, image=None):
        if image is None and material is not None and material.use_nodes:
            bsdf = next((n for n in material.node_tree.nodes if n.type == "BSDF_PRINCIPLED"), None)
            pending = [link.from_node for link in bsdf.inputs["Base Color"].links] if bsdf else []
            seen = set()
            while pending:
                node = pending.pop()
                if node in seen:
                    continue
                seen.add(node)
                if node.type == "TEX_IMAGE" and node.image:
                    image = node.image
                    break
                for socket in node.inputs:
                    pending.extend(link.from_node for link in socket.links)
        require(image is not None and image.size[0] > 0, "F-TEXTURE", "색 분류에 필요한 바탕색 질감 없음")
        self.width, self.height = image.size[:]
        self.channels = image.channels
        require(self.channels >= 3, "F-TEXTURE", "바탕색 채널 부족")
        self.pixels = array("f", [0.0]) * len(image.pixels)
        image.pixels.foreach_get(self.pixels)
        self.srgb = image.colorspace_settings.name == "sRGB" and not image.is_float

    def colour(self, uv):
        x = min(self.width - 1, int((uv.x % 1.0) * self.width))
        y = min(self.height - 1, int((uv.y % 1.0) * self.height))
        start = (y * self.width + x) * self.channels
        rgb = self.pixels[start:start + 3]
        return tuple(srgb_to_linear(c) for c in rgb) if self.srgb else tuple(rgb)


def sampled_face(mesh, poly, samplers):
    uv = mesh.uv_layers.active
    require(uv is not None, "F-UV", "색 분류에 필요한 UV 없음")
    sampler = samplers.get(poly.material_index)
    require(sampler is not None, "F-MATERIAL", "바탕색 표본기 누락")
    samples = [sampler.colour(uv.data[i].uv) for i in poly.loop_indices]
    return tuple(sum(rgb[c] for rgb in samples) / len(samples) for c in range(3))


def nearest(rgb, roles):
    return min(roles, key=lambda role: sum((a - b) ** 2 for a, b in zip(rgb, GRADED_TARGETS[role])))


def usd_role(kind, material):
    name = material.name.lower() if material else ""
    if kind == "kettle":
        if "opaque__plastic__kettle_r01" in name:
            return "dark"
        if "opaque__metal__kettle_r01" in name:
            return "aluminium"
    elif kind == "kettle_enamel":
        if "opaque__wood__kettle_u01" in name:
            return "wood"
        if "opaque__metal__kettle_u01" in name:
            return "sage"
    elif kind == "cutting_board" and "opaque__wood__cuttingboard_a01" in name:
        return "wood"
    elif kind == "vase" and "trans__glass__clean_a01" in name:
        return "glass"
    raise Blocked("F-MATERIAL", f"{kind}: 시각 재질 이름을 분류할 수 없음: {name!r}")


def clock_dial(obj, samplers):
    mesh = obj.data
    pale = [p.index for p in mesh.polygons
            if abs(p.normal.y) > .55 and nearest(sampled_face(mesh, p, samplers), ["dark", "cream"]) == "cream"]
    scores = [sum(mesh.polygons[i].area for i in pale if mesh.polygons[i].normal.y * sign > .55)
              for sign in (-1, 1)]
    require(max(scores) > 1e-5 and max(scores) > min(scores) * 1.1,
            "F-CLOCK-FRONT", f"문자판 앞뒤 밝기 영역을 가를 수 없음: {scores}")
    turned = scores[1] > scores[0]
    if turned:
        mesh.transform(Matrix.Rotation(math.pi, 4, "Z"))
        mesh.update()
    front = [mesh.polygons[i] for i in pale if mesh.polygons[i].normal.y < -.55]
    points = [mesh.vertices[i].co for p in front for i in p.vertices]
    lo, hi = bounds(points)
    require(hi.x - lo.x > .035 and hi.z - lo.z > .035,
            "F-CLOCK-DIAL", "크림 문자판 영역이 너무 작음")
    return dict(min=list(lo), max=list(hi), turned_180=turned, front_area_scores=scores)


def cavity_probes(mesh):
    lo, hi = bounds(v.co for v in mesh.vertices)
    tree = BVHTree.FromPolygons([v.co.copy() for v in mesh.vertices],
                               [list(p.vertices) for p in mesh.polygons], all_triangles=False)
    height = hi.z - lo.z
    probes = []
    for fx in (.35, .425, .50, .575, .65):
        for fy in (.35, .425, .50, .575, .65):
            x, y = lo.x + (hi.x - lo.x) * fx, lo.y + (hi.y - lo.y) * fy
            hit, normal, _, _ = tree.ray_cast(Vector((x, y, hi.z + .02)), Vector((0, 0, -1)), height + .04)
            under, normal_under, _, _ = tree.ray_cast(Vector((x, y, lo.z - .02)), Vector((0, 0, 1)), height + .04)
            if hit is None or under is None:
                continue
            depth = hi.z - hit.z
            if normal.z > .2 and normal_under.z < -.1 and depth > max(.0005, height * .03) and hit.z - under.z > .00002:
                probes.append(dict(fx=fx, fy=fy, depth=depth, wall=hit.z - under.z))
    return probes


def protect_interior(obj):
    mesh = obj.data
    lo, hi = bounds(v.co for v in mesh.vertices)
    centre = (lo + hi) * .5
    group = obj.vertex_groups.new(name="open_reduce")
    group.add(list(range(len(mesh.vertices))), 1.0, "REPLACE")
    protected = set()
    for poly in mesh.polygons:
        radial = Vector((poly.center.x - centre.x, poly.center.y - centre.y, 0))
        if (radial.length > 1e-6 and poly.normal.dot(radial.normalized()) < -.15) or poly.normal.z > .4:
            protected.update(poly.vertices)
    uses = {}
    for poly in mesh.polygons:
        for edge in poly.edge_keys:
            uses[edge] = uses.get(edge, 0) + 1
    for edge, count in uses.items():
        if count == 1:
            protected.update(edge)
    if protected:
        group.add(sorted(protected), .25, "REPLACE")
    return group.name


def decimate(obj, target, hollow=False, weld_m=.001):
    # cc0와 같은 weld + collapse. 입구를 채우는 연산은 하지 않는다.
    # 얇은 껍질(주전자 벽)은 1 mm 용접이 안·밖 면을 붙여 비다양체가 되고 collapse가 멈춘다 → 겹친 점만 붙임.
    bpy.context.view_layer.objects.active = obj
    group = protect_interior(obj) if hollow else None
    weld = obj.modifiers.new("open_weld", "WELD")
    weld.merge_threshold = weld_m
    bpy.ops.object.modifier_apply(modifier=weld.name)
    for _ in range(8):
        tris = sum(len(p.vertices) - 2 for p in obj.data.polygons)
        if 0 < tris <= target:
            return tris
        mod = obj.modifiers.new("open_collapse", "DECIMATE")
        mod.decimate_type = "COLLAPSE"
        mod.ratio = max(.002, target / max(1, tris) * .97)
        mod.use_collapse_triangulate = True
        if group:
            mod.vertex_group = group
            mod.vertex_group_factor = 1.0
        bpy.ops.object.modifier_apply(modifier=mod.name)
    tris = sum(len(p.vertices) - 2 for p in obj.data.polygons)
    require(0 < tris <= target, "F-TRIANGLES", f"collapse 후 {tris} > {target} 또는 빈 메시")
    return tris


def imported_piece(kind, spec, work):
    path = source_path(spec)
    require(path is not None and path.is_file(), "F-INPUT-MISSING", "원본 없음: " + str(path))
    digest = hashlib.sha256(path.read_bytes()).hexdigest()
    info = dict(path=path.as_posix(), sha256=digest, bytes=path.stat().st_size)
    reset_scene()
    scene = bpy.context.scene
    scene.unit_settings.system = "METRIC"
    scene.unit_settings.scale_length = 1.0
    image = None
    if spec["source"] == "usd":
        license_file = Path(license_path(spec))
        require(license_file.is_file() and "Attribution 4.0 International" in license_file.read_text(encoding="utf-8"),
                "F-LICENSE", "NVIDIA 라이선스 고지 없음")
        info["usd"] = import_usd(path)
    elif spec["source"] == "obj":
        unpacked = unpack_obj(spec, work, digest)
        bpy.ops.wm.obj_import(filepath=str(unpacked / "meshes/model.obj"),
                              forward_axis="NEGATIVE_Y", up_axis="Z",
                              use_split_objects=False, use_split_groups=False)
        if kind == "alarm_clock":
            image = bpy.data.images.load(str(unpacked / "materials/textures/texture.png"), check_existing=True)
        info["obj_up_axis"] = "Z"
    else:
        bpy.ops.import_scene.gltf(filepath=str(path))
        require(digest == spec["source_sha256"], "F-SOURCE-HASH",
                f"원본 SHA-256 {digest[:12]}…이 목록 줄의 값 {spec['source_sha256'][:12]}…과 다름")
        info["license_verification"] = "list_row cc-by-4.0; sha256 matches list row"
    obj, count = joined_mesh(kind)
    if spec.get("lay_flat"):
        # 모로 선 판(도마)은 위에서 보는 화면에서 금 하나로만 읽혀 눕힌다: 가장 얇은 가로축을 위로.
        lo0, hi0 = bounds(v.co for v in obj.data.vertices)
        size0 = hi0 - lo0
        obj.data.transform(Matrix.Rotation(math.pi / 2, 4, "Y" if size0.x < size0.y else "X"))
        obj.data.update()
    centre_mesh(obj.data)
    before_lo, before_hi = bounds(v.co for v in obj.data.vertices)
    original_size = before_hi - before_lo
    info.update(meshes_imported=count, triangles_before=sum(len(p.vertices) - 2 for p in obj.data.polygons),
                dimensions_blender_m=list(original_size),
                materials=[mat.name if mat else None for mat in obj.data.materials])
    if kind == "yard_well":
        require(all(1.2 < v < 2.1 for v in original_size) and 1.7 < original_size.z < 2.1,
                "F-SOURCE-SIZE", f"우물 원본 치수 {list(original_size)}")
    else:
        validate_bounds(bounds(Vector((v.co.x, v.co.z, -v.co.y)) for v in obj.data.vertices), spec)
    samplers = {}
    material_roles = {}
    used_slots = {p.material_index for p in obj.data.polygons}
    for index in used_slots:
        mat = obj.data.materials[index] if index < len(obj.data.materials) else None
        if spec["source"] == "usd":
            material_roles[index] = usd_role(kind, mat)
        elif kind == "alarm_clock":
            samplers[index] = Sampler(image=image)
        elif kind == "yard_well":
            samplers[index] = Sampler(mat)
    dial = clock_dial(obj, samplers) if kind == "alarm_clock" else None
    if dial:
        info["dial"] = dial
    if spec.get("lathe"):
        # 얇은 유리 겹벽은 collapse가 접힌 판으로 만든다: 원본 윤곽(높이별 가장 먼 반지름)을 돌려 다시 짓는다.
        lo, hi = bounds(v.co for v in obj.data.vertices)
        height = hi.z - lo.z
        profile = []
        for f in (0.0, .15, .35, .55, .75, .9, 1.0):
            z = lo.z + height * f
            near = [v.co for v in obj.data.vertices if abs(v.co.z - z) <= height * .04]
            require(bool(near), "F-LATHE", f"높이 {f}에 원본 점이 없음")
            radius = max(math.hypot(p.x, p.y) for p in near)
            profile.append((z - lo.z, radius, radius))
        info["lathe_profile_m"] = [[round(a, 4), round(b, 4)] for a, b, _ in profile]
        piece = Piece(kind)
        piece.lathe((0, 0), profile, "open_glass", sides=int(spec["lathe"]))
        top = max(piece.bm.faces, key=lambda face: face.calc_center_median().z)
        top[piece.paint] = piece.keys.index("tyre")
        info["colour_faces"] = dict(glass=len(piece.bm.faces) - 1, tyre=1)
        return piece, info
    before_cavity = cavity_probes(obj.data) if spec.get("hollow") else []
    if spec.get("hollow"):
        require(bool(before_cavity), "F-CAVITY-SOURCE", "원본 입구의 안쪽 깊이를 측정할 수 없음")
    decimate(obj, spec["limit"], bool(spec.get("hollow")), float(spec.get("weld", .001)))
    after_lo, after_hi = bounds(v.co for v in obj.data.vertices)
    size = after_hi - after_lo
    require(all(abs(size[i] - original_size[i]) <= original_size[i] * .08 + .002 for i in range(3)),
            "F-SIZE-LOSS", "면 축소 후 원본 크기가 8%+2 mm 넘게 바뀜")
    if kind == "yard_well":
        obj.data.transform(Matrix.Scale(1.9 / (after_hi.z - after_lo.z), 4))
    centre_mesh(obj.data)
    if before_cavity:
        after_cavity = cavity_probes(obj.data)
        matched = [(a, b) for a in before_cavity for b in after_cavity
                   if a["fx"] == b["fx"] and a["fy"] == b["fy"] and b["depth"] >= a["depth"] * .6]
        require(len(matched) >= max(1, math.ceil(len(before_cavity) * .8)), "F-CAVITY-LOSS",
                f"면 축소 뒤 입구·안쪽 바닥이 {len(matched)}/{len(before_cavity)} 곳만 남음")
        info["cavity"] = dict(before=before_cavity, after=after_cavity, matched=len(matched))
    piece = Piece(kind)
    roles = {key: 0 for key in spec["paints"]}
    lo, hi = bounds(v.co for v in obj.data.vertices)
    try:
        for poly in obj.data.polygons:
            require(poly.area > 1e-12, "F-DEGENERATE", "면 축소 뒤 면적 없는 면")
            if material_roles:
                role = material_roles.get(poly.material_index)
                require(role is not None, "F-MATERIAL", "collapse 뒤 재질 연결 유실")
            elif dial:
                # 문자판 내부는 표본의 검은 글씨까지 크림으로 덮는다.
                a, b = dial["min"], dial["max"]
                c = poly.center
                role = "cream" if (poly.normal.y < -.20 and a[0] - .003 <= c.x <= b[0] + .003
                                   and a[2] - .003 <= c.z <= b[2] + .003
                                   and c.y <= b[1] + .004) else "dark"
            elif samplers:
                role = nearest(sampled_face(obj.data, poly, samplers), spec["paints"])
                if role == "wood" and poly.center.z > hi.z * .60:
                    role = "worn_wood"
            else:
                role = spec["paints"][0]
            roles[role] += 1
            piece.face([obj.data.vertices[i].co.copy() for i in poly.vertices], "open_" + role, poly.normal)
        require(all(roles.values()), "F-COLOR-PARTS", f"색 부위가 사라짐: {roles}")
        info["colour_faces"] = roles
        return piece, info
    except Exception:
        piece.bm.free()
        raise


def mailbox(piece):
    piece.box((-.05, .05), (-.05, .05), (0, 1.05), "open_worn_wood")
    # 통 밑면 1.01, 기둥과 0.04 m 겹침. 앞은 -Y.
    profile = [(-.10, 1.01), (.10, 1.01)]
    profile += [(.10 * math.cos(i * math.pi / 8), 1.15 + .10 * math.sin(i * math.pi / 8))
                for i in range(9)]
    for y, normal in ((-.24, (0, -1, 0)), (.24, (0, 1, 0))):
        piece.face([(x, y, z) for x, z in profile], "open_green", normal)
    for i, a in enumerate(profile):
        b = profile[(i + 1) % len(profile)]
        outward = Vector(((a[0] + b[0]) / 2, 0, (a[1] + b[1]) / 2 - 1.13))
        piece.face([(a[0], -.24, a[1]), (b[0], -.24, b[1]),
                    (b[0], .24, b[1]), (a[0], .24, a[1])], "open_green", outward)
    piece.box((.107, .119), (-.03, -.018), (1.10, 1.20), "open_flag_rust")
    piece.box((.107, .153), (-.03, -.018), (1.20, 1.24), "open_flag_rust")


def wall_poster(piece):
    outline = [(-.30, 1.20), (.255, 1.20), (.30, 1.245), (.30, 2.05), (-.30, 2.05)]
    for y, normal in ((-.004, (0, -1, 0)), (.005, (0, 1, 0))):
        piece.face([(x, y, z) for x, z in outline], "open_paper", normal)
    for i, a in enumerate(outline):
        b = outline[(i + 1) % len(outline)]
        piece.face([(a[0], -.004, a[1]), (b[0], -.004, b[1]),
                    (b[0], .005, b[1]), (a[0], .005, a[1])],
                   "open_paper", ((a[0] + b[0]) / 2, 0, (a[1] + b[1]) / 2 - 1.625))

    def patch(points, colour, y):
        piece.face([(x, y, z) for x, z in points], "open_" + colour, (0, -1, 0))

    # Two peaks as one outline (no face over another in the same plane): the valley where their sides cross.
    patch([(-.26, 1.60), (-.08, 1.98), (.0525, 1.7512), (.15, 1.93), (.27, 1.60)], "bluegrey", -.0042)
    patch([(-.13, 1.87), (-.08, 1.98), (-.02, 1.87), (-.07, 1.90)], "paper", -.0044)
    patch([(.10, 1.84), (.15, 1.93), (.19, 1.83), (.15, 1.86)], "paper", -.0044)
    patch([(-.26, 1.42), (.24, 1.42), (.24, 1.52), (-.26, 1.52)], "ink", -.0046)
    patch([(.12, 1.52), (.12, 1.63), (.21, 1.63), (.21, 1.52)], "ink", -.0046)
    patch([(.02, 1.52), (.02, 1.62), (.065, 1.62), (.065, 1.52)], "ink", -.0046)
    patch([(-.24, 1.52), (-.24, 1.57), (-.05, 1.57), (-.05, 1.52)], "ink", -.0046)
    for x in (-.21, -.10, .04, .18):
        patch([(x + .035 * math.cos(i * math.tau / 8),
                1.41 + .035 * math.sin(i * math.tau / 8)) for i in range(8)], "ink", -.0048)
    patch([(-.26, 1.34), (.25, 1.34), (.25, 1.36), (-.26, 1.36)], "poster_rust", -.005)


def wall_clock(piece):
    centre = Vector((0, 0, 1.95))
    piece.ring(centre, .16, .139, .05, "open_wood", sides=16, axis="y")
    piece.beam((0, -.020, 1.95), (0, .020, 1.95), .139, "open_cream", sides=16)
    for i in range(12):
        angle = i * math.tau / 12
        radial = Vector((math.sin(angle), 0, math.cos(angle)))
        across = Vector((math.cos(angle), 0, -math.sin(angle))) * .004
        a, b = centre + radial * .112, centre + radial * .131
        piece.face([a - across + Vector((0, -.022, 0)), a + across + Vector((0, -.022, 0)),
                    b + across + Vector((0, -.022, 0)), b - across + Vector((0, -.022, 0))],
                   "open_ink", (0, -1, 0))
    for angle, length in ((math.radians(55), .102), (math.radians(-55), .070)):
        radial = Vector((math.sin(angle), 0, math.cos(angle)))
        across = Vector((math.cos(angle), 0, -math.sin(angle))) * .005
        a, b = centre - radial * .014, centre + radial * length
        piece.face([a - across + Vector((0, -.024, 0)), a + across + Vector((0, -.024, 0)),
                    b + across + Vector((0, -.024, 0)), b - across + Vector((0, -.024, 0))],
                   "open_ink", (0, -1, 0))
    piece.face([(.011 * math.cos(i * math.tau / 8), -.025,
                 1.95 + .011 * math.sin(i * math.tau / 8)) for i in range(8)],
               "open_ink", (0, -1, 0))


def bicycle(piece):
    for x in (-.52, .52):
        centre = Vector((x, 0, .33))
        piece.ring(centre, .33, .287, .038, "open_tyre", sides=12, axis="y")
        # 안쪽 금속 테는 얇은 평면 고리다.
        for i in range(12):
            a, b = i * math.tau / 12, (i + 1) * math.tau / 12
            piece.face([(x + r * math.cos(t), -.020, .33 + r * math.sin(t))
                        for r, t in ((.287, a), (.287, b), (.274, b), (.274, a))],
                       "open_aluminium", (0, -1, 0))
        piece.beam((x, -.027, .33), (x, .027, .33), .023, "open_aluminium", sides=6)
        for i in range(6):
            angle = i * math.tau / 6
            piece.beam(centre, (x + .275 * math.cos(angle), 0, .33 + .275 * math.sin(angle)),
                       .005, "open_aluminium", sides=3)
    rear, front = (-.52, 0, .33), (.52, 0, .33)
    crank, seat, head = (-.10, 0, .30), (-.23, 0, .72), (.33, 0, .74)
    for a, b in ((rear, crank), (crank, seat), (seat, rear), (seat, head), (head, crank),
                 (head, front), ((.36, 0, .64), front), (seat, (-.23, 0, .77))):
        piece.beam(a, b, .018, "open_bike_red", sides=4)
    piece.box((-.32, -.14), (-.07, .07), (.755, .79), "open_tyre")
    piece.beam(head, (.33, 0, .86), .014, "open_aluminium", sides=4)
    piece.beam((.33, -.13, .86), (.33, .13, .86), .014, "open_aluminium", sides=4)
    piece.beam((-.10, -.10, .30), (-.10, .10, .30), .014, "open_aluminium", sides=4)
    for y in (-.10, .10):
        piece.box((-.15, -.05), (y - .022, y + .022), (.285, .315), "open_tyre")
    turn = Matrix.Rotation(math.pi / 2, 3, "X")
    for vertex in piece.bm.verts:
        vertex.co = turn @ vertex.co


BUILDERS = dict(mailbox=mailbox, wall_poster=wall_poster, wall_clock=wall_clock, bicycle=bicycle)


def finish_piece(piece, spec):
    lo, hi = bounds(v.co for v in piece.bm.verts)
    shift = Vector((-(lo.x + hi.x) / 2, -(lo.y + hi.y) / 2, spec.get("bottom", 0.0) - lo.z))
    for vertex in piece.bm.verts:
        vertex.co += shift
    piece.finish_colours(spec.get("snow", 0.0))
    bmesh.ops.triangulate(piece.bm, faces=list(piece.bm.faces))
    piece.bm.normal_update()
    tris = len(piece.bm.faces)
    require(0 < tris <= spec["limit"], "F-TRIANGLES", f"{tris} 삼각형, 상한 {spec['limit']}")
    validate_bounds(bounds(Vector((v.co.x, v.co.z, -v.co.y)) for v in piece.bm.verts), spec)
    return tris


def read_glb(path):
    raw = path.read_bytes()
    require(len(raw) >= 28 and struct.unpack_from("<4sII", raw) == (b"glTF", 2, len(raw)),
            "F-GLB", "GLB 머리 불일치")
    length, kind = struct.unpack_from("<II", raw, 12)
    require(kind == 0x4E4F534A, "F-GLB", "GLB JSON chunk 없음")
    doc = json.loads(raw[20:20 + length])
    offset = 20 + length
    size, kind = struct.unpack_from("<II", raw, offset)
    require(kind == 0x004E4942 and offset + 8 + size == len(raw), "F-GLB", "GLB BIN chunk 불일치")
    return doc, raw[offset + 8:]


def accessor_values(doc, binary, index):
    accessor = doc["accessors"][index]
    require("sparse" not in accessor, "F-GLB", "예상 밖 sparse accessor")
    view = doc["bufferViews"][accessor["bufferView"]]
    code, width = {5126: ("f", 4), 5125: ("I", 4), 5123: ("H", 2), 5121: ("B", 1)}[accessor["componentType"]]
    count = {"SCALAR": 1, "VEC3": 3, "VEC4": 4}[accessor["type"]]
    stride = view.get("byteStride", count * width)
    start = view.get("byteOffset", 0) + accessor.get("byteOffset", 0)
    rows = [struct.unpack_from("<" + code * count, binary, start + i * stride) for i in range(accessor["count"])]
    if accessor.get("normalized"):
        divisor = {5121: 255.0, 5123: 65535.0}[accessor["componentType"]]
        rows = [tuple(v / divisor for v in row) for row in rows]
    return rows


def check_glb(path, tris, spec):
    size, digest = pc.check_glb(str(path), tris)
    doc, binary = read_glb(path)
    for node in doc["nodes"]:
        require("matrix" not in node and node.get("translation", [0, 0, 0]) == [0, 0, 0]
                and node.get("rotation", [0, 0, 0, 1]) == [0, 0, 0, 1]
                and node.get("scale", [1, 1, 1]) == [1, 1, 1], "F-GLB-TRANSFORM", "출력 노드 변환이 남음")
    primitive = doc["meshes"][0]["primitives"][0]
    require("material" not in primitive, "F-GLB-MATERIAL", "출력 재질이 남음")
    attrs = primitive["attributes"]
    positions = accessor_values(doc, binary, attrs["POSITION"])
    normals = accessor_values(doc, binary, attrs["NORMAL"])
    colours = accessor_values(doc, binary, attrs["COLOR_0"])
    indices = [row[0] for row in accessor_values(doc, binary, primitive["indices"])]
    require(len(positions) == len(normals) == len(colours) > 0, "F-GLB-ATTR", "정점 속성 개수 불일치")
    require(all(0 <= i < len(positions) for i in indices), "F-GLB-INDEX", "인덱스 범위 밖")
    require(all(math.isfinite(v) for row in positions + normals + colours for v in row),
            "F-GLB-NAN", "유한하지 않은 정점 값")
    require(all(len(c) == 4 and abs(c[3] - 1) < EPS and all(0 <= v <= 1 for v in c) for c in colours),
            "F-GLB-COLOR", "불투명 선형 정점색 범위 실패")
    for a, b, c in zip(indices[::3], indices[1::3], indices[2::3]):
        require((Vector(positions[b]) - Vector(positions[a])).cross(
            Vector(positions[c]) - Vector(positions[a])).length > 1e-12, "F-DEGENERATE", "출력 퇴화 삼각형")
        require(all((Vector(normals[a]) - Vector(normals[i])).length < EPS for i in (b, c)),
                "F-SMOOTH", "면 안 법선이 다름")
    limits = bounds(Vector(positions[i]) for i in indices)
    validate_bounds(limits, spec)
    lo, hi = limits
    require(0 < tris <= spec["limit"], "F-TRIANGLES", "출력 삼각형 상한 실패")
    used = sorted(set(indices))
    mean = [round(sum(colours[i][c] for i in used) / len(used), 4) for c in range(3)]
    groups = len({tuple(round(colours[i][c] * 20) for c in range(3)) for i in used})
    return dict(bytes=size, sha256=digest, bounds_m=[[round(v, 6) for v in row] for row in limits],
                dimensions_m=[round(v, 6) for v in hi - lo],
                height_m=round(hi.y, 6), bottom_m=round(lo.y, 6), lod0_tris=tris,
                colour_mean_rgb=mean, colour_groups=groups)


def preview(repo, assets):
    reset_scene()
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_WORKBENCH"
    scene.render.resolution_x = 2400
    scene.render.resolution_y = 2400
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = "PNG"
    scene.render.use_file_extension = True
    scene.display.shading.light = "STUDIO"
    scene.display.shading.color_type = "VERTEX"
    scene.display.shading.show_shadows = True
    scene.display.shading.show_cavity = True
    scene.display.shading.cavity_type = "BOTH"
    scene.display.shading.background_type = "WORLD"
    if scene.world is None:
        scene.world = bpy.data.worlds.new("open_preview")
    scene.world.color = (.10, .12, .14)
    scene.view_settings.view_transform = "Standard"
    elev = math.radians(35)
    direction = Vector((math.cos(elev) / math.sqrt(2), -math.cos(elev) / math.sqrt(2), math.sin(elev)))
    rotation = direction.to_track_quat("Z", "Y")
    right, up = rotation @ Vector((1, 0, 0)), rotation @ Vector((0, 1, 0))
    shown = []

    def label(text, cell):
        curve = bpy.data.curves.new("open_label", "FONT")
        curve.body, curve.size, curve.align_x = text, .115, "CENTER"
        obj = bpy.data.objects.new("open_label", curve)
        scene.collection.objects.link(obj)
        obj.rotation_euler = rotation.to_euler()
        obj.location = cell - up * 1.17 + direction * 1.5

    for index, (kind, row) in enumerate(assets.items()):
        cell = right * ((index % 4 - 1.5) * 2.65) + up * ((1.5 - index // 4) * 2.65)
        if row["status"] != "ready":
            label(kind + " / " + row["status"], cell)
            continue
        before = set(bpy.data.objects)
        bpy.ops.import_scene.gltf(filepath=str(repo / "s2/models/props_field" / (kind + ".glb")))
        bpy.context.view_layer.update()
        objects = [obj for obj in bpy.data.objects if obj not in before and obj.type == "MESH"]
        require(len(objects) == 1, "F-PREVIEW", kind + ": 재가져오기 메시 수 불일치")
        obj = objects[0]
        world = obj.matrix_world.copy()
        obj.parent = None
        obj.matrix_world = world
        require(bool(obj.data.color_attributes), "F-PREVIEW", kind + ": 정점색 없음")
        obj.data.color_attributes.active_color = obj.data.color_attributes[0]
        obj.data.color_attributes.render_color_index = 0
        lo, hi = bounds(world @ v.co for v in obj.data.vertices)
        obj.matrix_world.translation += cell - (lo + hi) * .5
        label(f'{kind} / {row["lod0_tris"]}t', cell)
        shown.append(kind)

    # 실제 키 1.75 m인 막대 사람. 소품과 같은 카메라·축척을 쓴다.
    pc.PALETTE["open_cream"] = inverse_grade(GRADED_TARGETS["cream"])
    human = Piece("human_1_75")
    try:
        for a, b in (((-.12, 0, 0), (0, 0, .85)), ((.12, 0, 0), (0, 0, .85)),
                     ((0, 0, .85), (0, 0, 1.45)), ((-.25, 0, 1.18), (0, 0, 1.38)),
                     ((.25, 0, 1.18), (0, 0, 1.38))):
            human.beam(a, b, .025, "open_cream", sides=6)
        human.lathe((0, 0), [(1.48, .05, .05), (1.53, .10, .10),
                            (1.68, .10, .10), (1.75, .04, .04)], "open_cream", sides=8)
        lo, hi = bounds(v.co for v in human.bm.verts)
        scale = 1.75 / (hi.z - lo.z)
        for v in human.bm.verts:
            v.co = (v.co - Vector((0, 0, lo.z))) * scale
        human.finish_colours()
        mesh = bpy.data.meshes.new("human_1_75")
        human.bm.to_mesh(mesh)
        mesh.color_attributes.active_color = mesh.color_attributes["Col"]
        mesh.color_attributes.render_color_index = 0
        obj = bpy.data.objects.new("human_1_75", mesh)
        scene.collection.objects.link(obj)
        cell = right * .5 * 2.65 + up * -1.5 * 2.65
        obj.location = cell - Vector((0, 0, .875))
        label("human / 1.75 m / same scale", cell)
    finally:
        human.bm.free()
    data = bpy.data.cameras.new("open_camera_45_35")
    camera = bpy.data.objects.new("open_camera_45_35", data)
    scene.collection.objects.link(camera)
    camera.location = direction * 30
    camera.rotation_euler = rotation.to_euler()
    data.type, data.ortho_scale = "ORTHO", 11.3
    scene.camera = camera
    path = repo / "tools/blender/_open_sheet.png"
    backup(path, repo / "tools/blender/_open_work")
    scene.render.filepath = str(path)
    bpy.ops.render.render(write_still=True)
    require(path.is_file() and path.stat().st_size > 1000, "F-PREVIEW", "Workbench 출력 없음")
    return dict(status="pass", complete=len(shown) == 14, shown_kinds=shown,
                path="tools/blender/_open_sheet.png", visual_review="not_verified",
                azimuth=45, elevation=35, reference_height_m=1.75)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--repo", type=Path, required=True)
    parser.add_argument("--only", default="")
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    args = parser.parse_args(argv)
    selected = list(DESIGNS) if not args.only else [part.strip() for part in args.only.split(",") if part.strip()]
    require(bool(selected) and len(selected) == len(set(selected)) and set(selected) <= set(DESIGNS),
            "F-ARGS", "--only에는 중복 없는 14종 이름만 허용")
    repo = args.repo.resolve()
    require((repo / "tools/blender/props_common.py").is_file(), "F-REPO", "저장소 경로 불일치")
    out, work = repo / "s2/models/props_field", repo / "tools/blender/_open_work"
    require(out.is_dir(), "F-REPO", "소품 출력 폴더 없음")
    work.mkdir(parents=True, exist_ok=True)
    assets = {kind: planned_asset(kind, spec) for kind, spec in DESIGNS.items()}
    existing = out / "catalog_open.json"
    if existing.is_file():
        previous = json.loads(existing.read_text(encoding="utf-8"))
        require(set(previous.get("assets", {})) == set(DESIGNS), "F-CATALOG", "기존 장부의 종류 목록 불일치")
        for kind, row in previous["assets"].items():
            require(row["source_name"] == DESIGNS[kind]["source_name"] and row["triangle_limit"] == DESIGNS[kind]["limit"],
                    "F-CATALOG", kind + ": 기존 장부의 원본·상한 불일치")
            assets[kind] = row
    verification = dict(blender=bpy.app.version_string, glb="not_run",
                        workbench_render="not_run", visual_review="not_verified",
                        imports="not_run: 별도 Godot 세션", godot_tests="not_run: 별도 Godot 세션")
    failures = []
    for kind in selected:
        spec = DESIGNS[kind]
        row = planned_asset(kind, spec)
        piece = None
        old_glb = out / (kind + ".glb")
        old_sha = hashlib.sha256(old_glb.read_bytes()).hexdigest() if old_glb.exists() else None
        try:
            configure_palette(spec)
            if spec["source"] == "made":
                reset_scene()
                piece = Piece(kind)
                BUILDERS[kind](piece)
                source_info = dict(procedural=True)
            else:
                piece, source_info = imported_piece(kind, spec, work)
            tris = finish_piece(piece, spec)
            row["intended_mean_rgb"] = piece.intended_rgb
            row["paint_count"] = piece.paint_count
            stage = work / "staged" / (kind + ".glb")
            stage.parent.mkdir(parents=True, exist_ok=True)
            backup(stage, work)
            pc.export(piece, str(stage))
            result = check_glb(stage, tris, spec)
            final = out / (kind + ".glb")
            backup(final, work)
            landing = final.with_name(final.name + ".tmp")
            shutil.copy2(stage, landing)
            confirmed = check_glb(landing, tris, spec)
            require(result == confirmed, "F-COPY", "최종 파일과 검사한 파일 불일치")
            # The exported colours must be the ones painted: within the ±8 % face shading of the intended mean,
            # and at least as many colour groups as paints.
            require(all(abs(a - b) <= .06 for a, b in zip(confirmed["colour_mean_rgb"], piece.intended_rgb))
                    and confirmed["colour_groups"] >= piece.paint_count, "F-COLOUR",
                    f'정점색 평균 {confirmed["colour_mean_rgb"]}·갈래 {confirmed["colour_groups"]}이 칠한 값 {piece.intended_rgb}·{piece.paint_count}와 다름')
            os.replace(landing, final)
            row.update(confirmed, status="ready", source=source_info)
            row["verification"].update(blender=bpy.app.version_string, glb="pass", pc_check_glb="pass")
            print(f'OPEN_READY {kind} tris={tris} bytes={row["bytes"]} sha256={row["sha256"]}', flush=True)
        except Exception as exc:
            code = exc.code if isinstance(exc, Blocked) else "F-BAKE"
            row.update(status="blocked", failure_code=code, blocked_reason=str(exc))
            row["verification"].update(blender=bpy.app.version_string, glb="not_verified",
                                       previous_glb_preserved=old_sha is not None and (out / (kind + ".glb")).exists()
                                       and hashlib.sha256((out / (kind + ".glb")).read_bytes()).hexdigest() == old_sha)
            failures.append(kind)
            print(f"OPEN_BLOCKED {kind} {code}: {exc}", flush=True)
        finally:
            if piece is not None:
                piece.bm.free()
        assets[kind] = row
        write_books(repo, assets, verification)

    # --only 이전의 ready도 오래된 파일을 그림·장부에 쓰지 않게 대조한다.
    for kind, row in assets.items():
        if row["status"] != "ready":
            continue
        try:
            measured = check_glb(out / (kind + ".glb"), int(row["lod0_tris"]), DESIGNS[kind])
            require(all(measured[key] == row[key] for key in measured), "F-STALE", "장부와 최종 GLB가 다름")
        except Exception as exc:
            row.update(status="blocked", failure_code="F-STALE", blocked_reason=str(exc))
            row["verification"]["glb"] = "not_verified"
            failures.append(kind)
    verification["glb"] = "pass" if all(row["status"] == "ready" for row in assets.values()) else "partial"
    try:
        verification["workbench_render"] = preview(repo, assets)
    except Exception as exc:
        verification["workbench_render"] = dict(status="blocked", failure_code="F-PREVIEW", reason=str(exc))
        failures.append("sheet")
        print(f"OPEN_BLOCKED sheet F-PREVIEW: {exc}", flush=True)
    write_books(repo, assets, verification)
    print(f"OPEN_RESULT selected={len(selected)} ready={sum(r['status'] == 'ready' for r in assets.values())}/14 "
          f"blocked={sum(r['status'] == 'blocked' for r in assets.values())} failures={failures}", flush=True)
    if failures:
        raise SystemExit(1)


if __name__ == "__main__":
    main()



