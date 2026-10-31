# 집 방 가구 room 16종

`tools/blender/props_field_room.py` 생성 장부.

출처: **Kenney Furniture Kit 2.0, CC0**. 입력과 라이선스는 `tools/blender/_src_kenney/`의 읽기 전용 파일이다.

상태: **ready**. `not_run`과 `—`는 최종 GLB를 만들거나 검사하지 못했다는 뜻이다.

발자국 가운데 바닥, facing 0 앞 +Z / 등 -Z, 2×1 긴 쪽 X, 발자국 96% 이내. 약장만 바닥에서 1.15~1.75 m에 뜬다.
단일 메시·단일 surface·Col 정점색, 재질·이미지·텍스처 없음, 각 700삼각형 이하가 완료 조건이다.

| 종류 | 원본 | 출처 | 삼각형 | 위끝 m | 바이트 | SHA-256 | 상태 |
|---|---|---|---:|---:|---:|---|---|
| `dresser` | `sideTableDrawers` | Kenney Furniture Kit 2.0, CC0 | 342 | 1.00 | 32424 | e16f5f90d12f7f120c1eddbcc9e8294747af2b66e1d608f6c529f8c7aae933d7 | ready |
| `chair` | `chair` | Kenney Furniture Kit 2.0, CC0 | 162 | 0.85 | 17532 | cce27d4f4aef56ea1959764400a3bca1464f63458c4c2c28532ed0f9a542f362 | ready |
| `nightstand` | `cabinetBedDrawerTable` | Kenney Furniture Kit 2.0, CC0 | 138 | 0.55 | 15060 | 3e70bc2277ac572acf593a5564272d42ce750b83e7a8bb7890e1c42ec7f5f465 | ready |
| `counter` | `kitchenCabinet` | Kenney Furniture Kit 2.0, CC0 | 114 | 0.90 | 12640 | e8b7ce695c4884ecd1461d0ac8b8168a09a06e57461308a60e7b22dae5ce84a6 | ready |
| `sink` | `kitchenSink` | Kenney Furniture Kit 2.0, CC0 | 316 | 0.90 | 33244 | 197f9d57ed4620e1bc6d87d4dc34ea02e36fd315fd6ba866a0860358d9f15b9f | ready |
| `cupboard` | `bookcaseClosedDoors` | Kenney Furniture Kit 2.0, CC0 | 277 | 1.80 | 29272 | 94a120745b1dc864b5d7ffdc894d6090bc42092ddbd1b9042e1734869759cd26 | ready |
| `settee` | `loungeSofa` | Kenney Furniture Kit 2.0, CC0 | 147 | 0.85 | 15236 | 576832043a472ee00e6e1ef1f364e7ca605afd744c01337878467c2b3a848bf7 | ready |
| `armchair` | `loungeChair` | Kenney Furniture Kit 2.0, CC0 | 148 | 0.90 | 15340 | f781561205054f85fb5c475e540e33dcd5ac40af2b8877b9d53852feaf6f935f | ready |
| `low_table` | `tableCoffeeSquare` | Kenney Furniture Kit 2.0, CC0 | 118 | 0.45 | 13052 | cd383da16d38a28e5fe959287e9351daa16c22952ad4e4f567b8131fe15e3172 | ready |
| `side_table` | `sideTable` | Kenney Furniture Kit 2.0, CC0 | 116 | 0.60 | 12848 | 0c2d9d0e854e3b173d1a0428027f8b437c2a9c319a3b3ff32e2b59011ec7c72b | ready |
| `toilet` | `toilet` | Kenney Furniture Kit 2.0, CC0 | 223 | 0.65 | 23760 | f5a8b7ddc8bf2d7f2984995d09fe096377e6b6040aa5da3d2b423a3133254fc7 | ready |
| `washstand` | `bathroomCabinetDrawer` | Kenney Furniture Kit 2.0, CC0 | 546 | 0.85 | 55180 | 0f6e92230d4d07df262b7aa93f15ba6ebe0ea3b07d94591d6d68062ae0284a7e | ready |
| `bathtub` | `bathtub` | Kenney Furniture Kit 2.0, CC0 | 647 | 0.60 | 65480 | 591b57ac09ed22d9f6547d0f1db9b01f06a12dbd9ee0506534f81a9e4cb8b3c1 | ready |
| `towel_shelf` | `bookcaseOpen` | Kenney Furniture Kit 2.0, CC0 | 436 | 1.60 | 40892 | fc45a706a81935fa402065d4c7cdfbb7ab58521c80f66c3b38fd61570ec1fbdb | ready |
| `medicine_cabinet` | `bathroomCabinet` | Kenney Furniture Kit 2.0, CC0 | 76 | 1.75 | 8400 | 80a39b204bcbb4dfc20ab9aeb84a068f6e36541e7d097d9cf1b4bc6a62f0fab9 | ready |
| `waste_bin` | `trashcan` | Kenney Furniture Kit 2.0, CC0 | 136 | 0.45 | 12200 | 46fbe14bfc63a3d5f755a8015ec2e4611ae8277e32747567930c443b1eab3d6d | ready |

## 손질

- `dresser`: 기존 두 서랍·상판·다리를 살리고 아래 몸통과 서랍 네 개를 덧댄 낮고 넓은 목제 서랍장, 짙은 호두색 몸통과 참나무색 서랍·상판.
- `chair`: 네 다리와 뚫린 등받이의 목제 의자, 짙은 호두색 틀과 참나무색 좌판.
- `nightstand`: 작은 서랍 하나, 네 다리, 바랜 파랑 칠과 나무 상판.
- `counter`: 옆면이 단순한 조리대, 꿀색 나무 문짝, 상판의 금속색도 참나무색으로 변경.
- `sink`: 밝은 회색 금속 개수통·수도꼭지, 조리대와 같은 꿀색 나무 하부장.
- `cupboard`: 연초록 칠의 높은 두 문 찬장, 짙은 목재 상판과 회색 손잡이.
- `settee`: 바랜 붉은 갈색 천의 두 자리 소파, 나무 다리와 덧댄 목제 팔걸이 상단.
- `armchair`: 바랜 초록 천의 넓은 의자, 나무 다리와 목제 팔걸이 상단.
- `low_table`: 짙은 나무 사각 상판과 바랜 파랑 다리의 낮은 탁자.
- `side_table`: 짙은 호두색 다리와 참나무색 상판의 작은 탁자.
- `toilet`: 밝은 흰 도기, 닫힌 뚜껑과 뒤쪽 물통.
- `washstand`: 후보 받침 세면대 대신 같은 제공 묶음의 수납형 세면대 선택, 법랑 대야·목제 서랍·짧은 다리.
- `bathtub`: 긴 쪽 X, 밝은 흰 법랑 욕조에 짧은 주철 다리 네 개 추가.
- `towel_shelf`: 좁고 높은 꿀색 나무 선반, 기존 수평 선반 높이를 찾아 접은 수건 여섯 장 추가.
- `medicine_cabinet`: 바닥 기준 원점, 높이 1.15~1.75 m의 작은 벽 약장, 거울색은 법랑색으로 대체, 표지 없음.
- `waste_bin`: 뚜껑과 발판이 있는 작은 회색 금속 휴지통, 윗면에 주철 손잡이 추가.

## 색과 확인

E 묶음 PALETTE에 room 색을 추가한다. 방 가구가 받는 생활 색 보정(weathered `lively`: 채도 0.75·밝기 0.82·찬 기운 0.21)을 역산한 선형 RGBA다.
흰 도기·법랑, 짙은 호두·참나무·꿀색 나무, 크림·초록·파랑 칠, 바랜 붉은 갈색·이끼 초록·겨자 천과 회색 금속을 사용한다.
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
