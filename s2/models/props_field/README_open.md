# 공개 소품 open 14종

`tools/blender/props_field_open.py` 생성 장부.

상태: **ready**. ready는 GLB 구조·치수 검사 완료이며 화면 검수와 다르다.
NVIDIA 4종·Google 5종·Scenario 1종은 CC BY 4.0, 나머지 4종은 자체 제작이다.
원본과 라이선스 경로는 catalog_open.json, 상세 조사와 가정은 _open_work/inspect_sources.md.

발자국 가운데 바닥, +Z 앞 / -Z 등. 작은 소품은 밑면 0, 벽걸이는 높이를 모형에 넣는다.
단일 메시·단일 surface·Col 정점색, 재질·이미지·질감 없음. 발자국 96% 이내.

| 종류 | 원본 | 출처 | 삼각형 / 상한 | 위끝 m | 바이트 | SHA-256 | 상태 |
|---|---|---|---:|---:|---:|---|---|
| `kettle` | `kitchenware_kettle_r01` | NVIDIA SimReady kitchenware_kettle_r01, CC BY 4.0 | 242 / 250 | 0.235961 | 25700 | 9f234500e722fa37e28f9ead32307cdaa3d84c566c3bcb662cac61194369cf01 | ready |
| `kettle_enamel` | `kitchenware_kettle_u01` | NVIDIA SimReady kitchenware_kettle_u01, CC BY 4.0 | 242 / 250 | 0.238915 | 25712 | 5d3ad0a901e50d640ac07715a9801acb85c33b7fed1556e6466fabac5f0fb28d | ready |
| `cutting_board` | `kitchenware_cuttingBoard_a01` | NVIDIA SimReady kitchenware_cuttingBoard_a01, CC BY 4.0 | 76 / 80 | 0.014182 | 8780 | 0d961e8e1d9a3d618e2f461b4c338d5dd5e7df0c4084f7eabcb306cfbb9dd30e | ready |
| `vase` | `misc_glass_vase_a01` | NVIDIA SimReady misc_glass_vase_a01, CC BY 4.0 | 108 / 120 | 0.203103 | 8312 | d3d76ec2978a4d1a759956b70c889d17c8d8c7d427ba9dc7dc4911df093ee58f | ready |
| `alarm_clock` | `Crosley_Alarm_Clock_Vintage_Metal` | Google LLC. / Google Scanned Objects Crosley_Alarm_Clock_Vintage_Metal, CC BY 4.0 | 192 / 220 | 0.163714 | 14532 | 70f46fdbb224d8ceb80a5571fc485859030d4d528d339ae9ee6e112ec44ebe14 | ready |
| `mug` | `Threshold_Porcelain_Coffee_Mug_All_Over_Bead_White` | Google LLC. / Google Scanned Objects Threshold_Porcelain_Coffee_Mug_All_Over_Bead_White, CC BY 4.0 | 120 / 120 | 0.114624 | 10364 | ab2e1b02c4631575e6dbdeee0470c28e602636f970b24d510bc956644f9e0094 | ready |
| `teapot` | `Threshold_Porcelain_Teapot_White` | Google LLC. / Google Scanned Objects Threshold_Porcelain_Teapot_White, CC BY 4.0 | 236 / 250 | 0.136345 | 18112 | 6b87036f56ea11741c9d8350c7cd41162d3d79a7f7db9cc251d52db61a171dfc | ready |
| `serving_bowl` | `Threshold_Porcelain_Serving_Bowl_Coupe_White` | Google LLC. / Google Scanned Objects Threshold_Porcelain_Serving_Bowl_Coupe_White, CC BY 4.0 | 120 / 150 | 0.068883 | 10192 | 9b8ec09293eab71618140c9febae22e3ab3bfdeb13e37766c010ef583a071843 | ready |
| `dinner_plate` | `Threshold_Dinner_Plate_Square_Rim_White_Porcelain` | Google LLC. / Google Scanned Objects Threshold_Dinner_Plate_Square_Rim_White_Porcelain, CC BY 4.0 | 72 / 80 | 0.038908 | 6832 | e69fb900234f0222291da763a8f5a029e0b63b6a2bd29d087791b2e4fa5f2214 | ready |
| `yard_well` | `scenario_asset_9p84PJEb3SqR6SqvuMKWX1m1` | Scenario scenario_asset_9p84PJEb3SqR6SqvuMKWX1m1, CC BY 4.0 | 679 / 700 | 1.9 | 60492 | 7b47478afa038c2e730ff428cd254511ed270b39e995ba8b3c22de380fb47ec4 | ready |
| `mailbox` | `mailbox` | 자체 제작, Blender 기본 도형 | 76 / 200 | 1.25 | 5868 | ba4341c961d75397b78a75ba7c5838e59f3035afcf07259b72220cdc653f45d9 | ready |
| `wall_poster` | `wall_poster` | 자체 제작, Blender 기본 도형 | 57 / 150 | 2.05 | 4416 | b0fe2692ef294f54289e4aee08a0d06bc5c6258fa1827dc740c4163e963d6229 | ready |
| `wall_clock` | `wall_clock` | 자체 제작, Blender 기본 도형 | 222 / 250 | 2.11 | 15680 | 4f0bcd4376658bd1a31a8d313998b58f8a393f432c066846d28b1a4f6f1acf62 | ready |
| `bicycle` | `bicycle` | 자체 제작, Blender 기본 도형 | 544 / 600 | 0.26 | 39868 | 0fd880c72f8d72a7d5f9518b4041241352b70df268c29f0759dcf88a2358646e | ready |

## 손질

- `kettle`: 금속 몸과 짙은 손잡이·꼭지, 꽃무늬 제거
- `kettle_enamel`: 연녹 법랑 몸과 짙은 나무 손잡이
- `cutting_board`: 모로 선 원본을 눕힌 짙은 나무 도마(실측 유지)
- `vase`: 원본 윤곽을 높이 일곱 곳에서 재어 8면으로 돌린 불투명 짙은 병유리, 입구는 더 어둡게
- `alarm_clock`: 원본 치수로 다시 지은 둥근 짙은 몸·민무늬 크림 문자판·바늘·종 둘·손잡이(스캔 면 대신)
- `mug`: 원본 윤곽을 재어 10면으로 돌린 흰 자기 잔, 안쪽 바닥과 손잡이
- `teapot`: 원본 윤곽을 높이 일곱 곳에서 재어 12면으로 돌린 흰 자기 주전자, 주둥이와 손잡이
- `serving_bowl`: 원본 윤곽을 재어 12면으로 돌린 흰 자기 큰 사발, 안쪽 바닥과 입구
- `dinner_plate`: 원본 지름·높이로 12면 둥근 테를 돌린 흰 자기 접시
- `yard_well`: 돌 둘레는 12각 기둥과 갓돌로 다시 짓고 안에 짙은 물, 원본 나무 틀·기둥·지붕은 높이별로 회갈 돌·갈색 나무
- `mailbox`: 나무 기둥과 반원 지붕 통, 작은 녹슨 깃발
- `wall_poster`: 찢긴 종이에 눈 덮인 산과 기차 색 조각, 글자 없음
- `wall_clock`: 나무 테·크림 문자판·눈금 12개·바늘 둘, 숫자 없음
- `bicycle`: 길이 1.70 m, 지름 0.66 m 바퀴의 쓰러진 옛 자전거

weld 0.001 m 뒤 collapse, 안쪽 면 보호·공동 깊이 비교. 원본 실제 크기는 작은 소품에서 유지한다.
USD는 실제 stage 단위 변환, OBJ는 Z 위. 주전자 재질 subset과 UV 밝기 영역으로 색을 나눈다.
면별 밝기는 ±8% 안, 각진 음영. 지붕·통·자전거의 최종 윗면에만 눈을 섞는다.
등급이 따뜻한 빨강에 못 닿아 우편함 깃발·포스터 녹·자전거 빨강은 닿는 가장 붉은 색으로 낮췄다(포스터 녹 = 우리 소품 rust).
Scenario 라이선스는 허깅페이스 scenario-labs/3d-collection 목록의 그 줄 license 칸(cc-by-4.0)이고, 원본 GLB SHA-256이 목록 값과 같다(굽기 때 대조).
wall_poster 밑면 1.20 m, wall_clock 중심 1.95 m. mailbox 통과 기둥은 0.04 m 겹친다.
직접 만든 네 종에는 제3자 CC BY 고지를 붙이지 않는다.

## 실행

먼저 PC 문지기의 GODOT_GATE=PASS를 실제 확인한다. 실패하면 Blender를 시작하지 않는다.
```text
blender -b --factory-startup --python-exit-code 1 -P tools/blender/props_field_open.py -- --repo .
# 일부만 다시 만들기: 위 명령 끝에 --only kettle,mug
```

선택하지 않은 장부 행은 보존한다. 실패한 종류는 blocked로 기록하고 다음 종류로 진행한다.
기존 생성물은 _open_work/backups/에 SHA-256별로 보관한 뒤 교체한다.
최종 GLB를 재가져와 Workbench 정점색으로 _open_sheet.png를 만든다.
수평 45°·내려다봄 35°, 모두 같은 축척, 키 1.75 m 사람 막대. 누락 종류도 상태 이름표를 남긴다.
그림과 _open_work/는 git 제외. Godot import·시험은 별도이며 현재 GLB가 없으면 시험 실패가 맞다.

## 확인

```json
{
  "blender": "4.5.10 LTS",
  "glb": "pass",
  "workbench_render": {
    "status": "pass",
    "complete": true,
    "shown_kinds": [
      "kettle",
      "kettle_enamel",
      "cutting_board",
      "vase",
      "alarm_clock",
      "mug",
      "teapot",
      "serving_bowl",
      "dinner_plate",
      "yard_well",
      "mailbox",
      "wall_poster",
      "wall_clock",
      "bicycle"
    ],
    "path": "tools/blender/_open_sheet.png",
    "visual_review": "not_verified",
    "azimuth": 45,
    "elevation": 35,
    "reference_height_m": 1.75
  },
  "visual_review": "not_verified",
  "imports": "not_run: 별도 Godot 세션",
  "godot_tests": "not_run: 별도 Godot 세션"
}
```
