# 집 방 가구 room 16종

`tools/blender/props_field_room.py` 생성 장부.

출처: **Kenney Furniture Kit 2.0, CC0**. 입력과 라이선스는 `tools/blender/_src_kenney/`의 읽기 전용 파일이다.

상태: **ready**. `not_run`과 `—`는 최종 GLB를 만들거나 검사하지 못했다는 뜻이다.

발자국 가운데 바닥, facing 0 앞 +Z / 등 -Z, 2×1 긴 쪽 X, 발자국 96% 이내. 약장만 바닥에서 1.15~1.75 m에 뜬다.
단일 메시·단일 surface·Col 정점색, 재질·이미지·텍스처 없음, 각 700삼각형 이하가 완료 조건이다.

| 종류 | 원본 | 출처 | 삼각형 | 위끝 m | 바이트 | SHA-256 | 상태 |
|---|---|---|---:|---:|---:|---|---|
| `dresser` | `sideTableDrawers` | Kenney Furniture Kit 2.0, CC0 | 342 | 1.00 | 32424 | 10598f2f89dc0632ecba0097099730f32900394fde0866f9a5b34ad84fd1558b | ready |
| `chair` | `chair` | Kenney Furniture Kit 2.0, CC0 | 162 | 0.85 | 17532 | 3fa0e4ff9b2b2f4d0ae966c21c4f3c55948aee084394e39411a23f97d7d999dc | ready |
| `nightstand` | `cabinetBedDrawerTable` | Kenney Furniture Kit 2.0, CC0 | 138 | 0.55 | 15060 | 3ca924514e6a899f44919d77ecaf7b260aa78d2315b72857f85a4d4e0539738e | ready |
| `counter` | `kitchenCabinet` | Kenney Furniture Kit 2.0, CC0 | 114 | 0.90 | 12640 | 7438bae86451353b1baa0c099e8cb92b62ebc594df3c74e308ddb8f3af321f13 | ready |
| `sink` | `kitchenSink` | Kenney Furniture Kit 2.0, CC0 | 316 | 0.90 | 33244 | adffd6fc5908cff2f268dbabe2c9f2479af0199f60d583ba1d4da914d23ad900 | ready |
| `cupboard` | `bookcaseClosedDoors` | Kenney Furniture Kit 2.0, CC0 | 277 | 1.80 | 29272 | 53354dbdc36b68b6d60682141be407fe075eae2c8fd0ce74182c28235cb2a9dc | ready |
| `settee` | `loungeSofa` | Kenney Furniture Kit 2.0, CC0 | 147 | 0.85 | 15236 | f699480b5e9f9ad6d7b2b86cabf9e169678cba5530000107f26f39f46f8885ce | ready |
| `armchair` | `loungeChair` | Kenney Furniture Kit 2.0, CC0 | 148 | 0.90 | 15340 | d38748c192ca40c40c7f804acf754334f2623f98486756693f0857ac090f788e | ready |
| `low_table` | `tableCoffeeSquare` | Kenney Furniture Kit 2.0, CC0 | 118 | 0.45 | 13052 | 7d59fe438e0a56be25a7f37b7b030b2f722e96bb86389fccb267a207dcd9ecf6 | ready |
| `side_table` | `sideTable` | Kenney Furniture Kit 2.0, CC0 | 116 | 0.60 | 12848 | aa13e2af9437e5cbee1e6ca74260390f045295fcacea45b979eaf92efcb5c33c | ready |
| `toilet` | `toilet` | Kenney Furniture Kit 2.0, CC0 | 223 | 0.65 | 23760 | 8d477b3d861ca96d4398dd4c761a554bf7c1cdfcb92db3afc5ad2f8c3161c1c9 | ready |
| `washstand` | `bathroomCabinetDrawer` | Kenney Furniture Kit 2.0, CC0 | 546 | 0.85 | 55180 | 9bc5b4bb3e90ab9eff4c69ed20763cfed912a7feb5748b347705a6765a7f83b6 | ready |
| `bathtub` | `bathtub` | Kenney Furniture Kit 2.0, CC0 | 647 | 0.60 | 65480 | ae8d1e51aa538173907114c2242f77682db223a9bb7a13f8df67208cda2183b7 | ready |
| `towel_shelf` | `bookcaseOpen` | Kenney Furniture Kit 2.0, CC0 | 436 | 1.60 | 40892 | cbc8d7fca9f1739a71ede12d91a1da91c5411deb6629417e37d7175cff9a3970 | ready |
| `medicine_cabinet` | `bathroomCabinet` | Kenney Furniture Kit 2.0, CC0 | 76 | 1.75 | 8400 | 70d39fbfff29adea07546ce06b40daa86c70a7e8bb371f62d5c697f595f9107c | ready |
| `waste_bin` | `trashcan` | Kenney Furniture Kit 2.0, CC0 | 136 | 0.45 | 12200 | e8c6b96b69cc00339d6ed7c748d16f7547cc45f6f44c3448f384649872b3f8b4 | ready |

## 손질

- `dresser`: 기존 두 서랍·상판·다리를 살리고 아래 몸통과 서랍 네 개를 덧댄 낮고 넓은 목제 서랍장.
- `chair`: 네 다리와 뚫린 등받이의 목제 의자, 밝은 크림 칠과 짙은 좌판.
- `nightstand`: 작은 서랍 하나, 네 다리, 바랜 파랑 칠과 나무 상판.
- `counter`: 옆면이 단순한 조리대, 상판의 금속색도 목재색으로 변경.
- `sink`: 밝은 회색 금속 개수통·수도꼭지, 크림 칠 목제 하부장.
- `cupboard`: 연초록 칠의 높은 두 문 찬장, 짙은 목재 상판과 회색 손잡이.
- `settee`: 바랜 붉은 갈색 천의 두 자리 소파, 나무 다리와 덧댄 목제 팔걸이 상단.
- `armchair`: 바랜 초록 천의 넓은 의자, 나무 다리와 목제 팔걸이 상단.
- `low_table`: 짙은 나무 사각 상판과 바랜 파랑 다리의 낮은 탁자.
- `side_table`: 밝은 크림 다리와 짙은 목제 상판의 작은 탁자.
- `toilet`: 밝은 흰 도기, 닫힌 뚜껑과 뒤쪽 물통.
- `washstand`: 후보 받침 세면대 대신 같은 제공 묶음의 수납형 세면대 선택, 법랑 대야·목제 서랍·짧은 다리.
- `bathtub`: 긴 쪽 X, 밝은 흰 법랑 욕조에 짧은 주철 다리 네 개 추가.
- `towel_shelf`: 좁고 높은 목제 선반, 기존 수평 선반 높이를 찾아 접은 수건 여섯 장 추가.
- `medicine_cabinet`: 바닥 기준 원점, 높이 1.15~1.75 m의 작은 벽 약장, 거울색은 법랑색으로 대체, 표지 없음.
- `waste_bin`: 뚜껑과 발판이 있는 작은 회색 금속 휴지통, 윗면에 주철 손잡이 추가.

## 색과 확인

E 묶음 PALETTE에 room 색을 추가한다. 셰이더의 채도 0.45·밝기 0.82·찬 기운 0.35를 역산한 선형 RGBA다.
흰 도기·법랑, 크림·연초록·흐린 파랑 칠, 짙은 나무, 바랜 붉은 갈색·초록·겨자 천과 회색 금속을 사용한다.
가방·신발·옷 더미, 빨간 십자·초승달, 사슬·쇠창살·빗장, 현대 가전·플라스틱·유리 탁자를 추가하지 않는다.

```json
{
  "blender": "4.5.10 LTS",
  "glb": "pass",
  "workbench_render": "pass: rendered, visual review still required",
  "visual_review": "not_verified",
  "godot_tests": "not_run: caller owns Godot/import",
  "imports": "not_run"
}
```

## 실행

먼저 원래 PC 문지기를 실행해 `GODOT_GATE=PASS`를 확인한다. 실패하면 Blender를 시작하지 않는다.
```powershell
& "C:/Users/wndi1/AppData/Local/Programs/Python/Python313/python.exe" -X utf8 -I "C:/Users/wndi1/OneDrive/바탕 화면/작업폴더/coord/tools/godot_gate.py"
# PASS를 실제로 확인한 뒤에만 다음 명령 실행
& "C:/Program Files/Blender Foundation/Blender 4.5/blender.exe" -b --factory-startup --python-exit-code 1 -P tools/blender/props_field_room.py -- --repo .
```

같은 Blender 실행에서 최종 GLB를 다시 들여와 Workbench 정점색, 수평 45°·내려다봄 35°의 `tools/blender/_room_sheet.png`를 만든다.
그림과 `_room_work/`는 git 제외 대상이다. Godot과 .import 생성은 이 스크립트가 수행하지 않는다.
이전 생성 파일은 덮어쓰기 전에 `_room_work/backups/`에 이름·SHA-256별로 보관한다.
