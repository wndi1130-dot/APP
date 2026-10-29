# 첫 정차 가구 CC0 교체 — 2차

이 표는 `tools/blender/props_stop01_cc0.py`의 조형 계획과 굽기 장부를 함께 기록한다. 날짜 2026-10-29.

`bake_status: baked`인 행만 실제 GLB 측정값이다. `pending`은 2차 재굽기 전이며 면 수·바이트·해시는 null이다.
기존 GLB는 그대로 두고 1차 출처·측정값을 `previous_bake`에 보존한다. 최초 트리포 `before`도 유지한다.
`source`는 `poly_haven` 또는 `blender_primitives`, 혼합은 두 값의 배열이다. pending 행의 출처는 2차 계획이다.

전: 최초 교체 직전 트리포 GLB의 LOD0 accessor count·파일 전체 바이트. 재실행해도 before를 보존한다.
후: 단일 메시·surface·LOD0, UV·재질·질감 없음, 각진 음영, 선형 Col. 치수는 x×y(높이)×z m.

rect는 maps/*.gd와 sulehuf_map.gd 81개 파일의 정적 kind+rect 리터럴 집계(별칭 합산).
facing으로 rect를 돌리지 않으며 동적 방 배치·cell 수납은 포함하지 않는다. 최빈값 없는 항목은 가정을 따로 표시한다.
sulehuf의 가구 수납은 cell만 있어 rect 표본이 없다. 침대는 긴 축을 X에 둔다.

| 이름 | 출처 / 자체 조형 | 삼각형 트리포→2차 | 예산 추정 상한 / 제한 | 바이트 트리포→2차 | rect 최빈(빈도/표본) | 크기 x×y×z m |
|---|---|---:|---:|---:|---|---|
| `wardrobe` | painted_wooden_cabinet_02 | 1454→422 | 440 / 700 | 333820→37920 | 2×1 (396/396) | 1.22×1.90×0.60 |
| `shop_shelf` | Blender 기본 도형: straight_sides, four_shelves, back, price_strips, empty_cans, boxes | 1454→300 | 300 / 500 | 389168→21540 | 3×1 (1214/1396) | 2.08×1.60×0.50 |
| `bookcase` | wooden_bookshelf_worn + Blender 기본 도형: seeded_books | 1455→680 | 696 / 700 | 438228→62632 | 2×1 (529/529) | 1.40×1.90×0.56 |
| `dining_set` | painted_wooden_chair_01; painted_wooden_table | 1455→450 | 480 / 700 | 369640→40968 | 2×2 (226/226) | 1.60×0.88×1.80 |
| `table_overturned` | painted_wooden_table | 1454→232 | 240 / 700 | 311100→18740 | 없음(0); 가정 1×2 | 0.76×0.82×1.60 |
| `workbench` | Blender 기본 도형: four_plank_top, four_legs, lower_shelf, vise, hammer, hand_plane | 1454→288 | 288 / 500 | 339316→21148 | 3×1 (207/226) | 1.75×0.90×0.86 |
| `office_desk` | WoodenTable_01 + Blender 기본 도형: three_drawer_pedestal, handles | 1454→490 | 504 / 600 | 320244→43840 | 2×1 (985/985) | 1.40×0.77×0.75 |
| `iron_bed` | Blender 기본 도형: frame, mattress, blanket | 1455→264 | 264 / 700 | 395728→19492 | 2×1 (744/744) | 1.92×1.04×0.94 |
| `drawer_chest_spilled` | vintage_wooden_drawer_01 + Blender 기본 도형: scattered_paper | 1455→517 | 538 / 700 | 369124→51140 | 없음(0); 가정 1×1 | 0.90×1.00×0.86 |
| `toolbox` | Blender 기본 도형: open_body, hinged_lid, tray, black_handle, two_tools | 382→192 | 192 / 200 | 88348→14580 | 없음(0); 가정 1×1 | 0.38×0.40×0.35 |

미생성: 없음
재굽기 대기: 없음

## 가정·확인 범위

- Poly Haven CC0 1.0은 발주에서 제공한 출처 조건이다. 이번 작성에서 네트워크 재확인은 하지 않았다.
- 원본 앞은 glTF +Z로 가정. 원본 노드 변환은 보존한다. 두 문 옷장·매트리스·테두리 마스크는 실제 화면 검수 필요.
- mask_ratio는 삼각형 코너 수 비율. Col.a 몸체 1 / 테두리·손잡이·쇠붙이 .5 / 책·종이·상품·공구·천 0. 원본 의미 구분은 연결 부품·판 두께에 따른 추정이다.
- props_common.export의 ACTIVE 정점색과 재질 NONE 조합은 Blender 4.5에서 COLOR_0 VEC4 알파를 보존한다. .5는 정규화 정수로 반올림될 수 있다.
- baked 행의 알파·경계·예산·SHA만 출력 바이트와 대조한다. pending 행의 GLB는 아직 1차 결과다. Godot 가져오기·GUT·시각 검사는 not_run.
- shelf·desk·bed·file_cabinet·tool_chest는 prop_kinds.gd에서 기존 공용 GLB가 우선한다. 첫 정차 BY_ID/BY_SUFFIX·직접 stop01 참조와 구분해야 한다.
- --out 결과는 검수용이며 res:// 경로로 자동 설치하지 않는다. --only는 기존 장부의 다른 항목을 보존한다.

## 칠 판과 셰이더 칠 칸

`res://game/world/furniture_tints.gd`는 body·trim 두 sRGB 색을 가진 4판이다. 모든 색은 HSV 채도 <0.45, 밝기 <0.75다.
`pick(row, cell)`은 tint 번호의 양의 나머지 → building 번호 해시 → 둘 다 없을 때 cell 해시 순서다. 해시는 PCG로 섞은 뒤 판을 고른다(`roll`). 같은 건물은 같은 판을 고른다.
`dress()`가 색을 `srgb_to_linear()`로 바꿔 재질 값 tint_sets_body·tint_sets_trim에 넣고, 판 번호 + 1은 MultiMesh 사용자 자료로 간다. a는 각각의 세기다.
정점 알파 ≥0.75는 몸체, 0.25≤알파<0.75는 테두리, 나머지는 보존한다. use_vertex_color일 때만 적용한다.
칠 RGB에 바탕색의 선형 밝기 / 모형 몸체·테두리 평균 밝기(tint_ref, paint_ref) 비(0~1.6)를 곱해 결의 명암만 남기고, 칠이 남긴 바탕도 판 밝기로 맞춘다. 판 번호가 없으면 기존 경로가 그대로다.
지도·room_*.gd·map_view.gd·prop_fit.gd·prop_models.gd 연결은 이 작업 범위 밖이다. 이 체크아웃의 room_furnish에는 TINT_SETS가 없다.

## 몸체 색 누르기

기존 코드가 원본색을 그대로 복사하지 않고 tint()로 지정 색에 맞추므로, 현재 칠 결과의 sRGB HSV를 기준으로 누른다.
선형 Col을 sRGB로 바꿔 채도·명도에 아래 비율을 곱한 뒤 선형으로 돌린다. alpha ≥0.75인 몸체만 적용하며 trim·keep는 보존한다.
장부 body_press_basis: `srgb_hsv_after_existing_palette_tint_body_only`. 게임의 기존 색 보정·날씨는 이 굽기 조정 뒤에 적용된다.

| 종 | 채도 배수 | 명도 배수 |
|---|---:|---:|
| wardrobe | 0.60 | 0.85 |
| dining_set | 0.60 | 0.85 |
| table_overturned | 0.60 | 0.85 |
| office_desk | 0.60 | 0.85 |
| bookcase | 0.60 | 0.85 |
| drawer_chest_spilled | 0.60 | 0.85 |

## 2차 조형

- `wardrobe`: 몸체 앞에 원본 문짝을 길게 맞춘 두 벌(한 벌 좌우 반전). 원본 서랍은 생략. 깊이 .60 m의 두 문 옷장
- `shop_shelf`: 기본 도형: 곧은 옆판·네 판·뒤판·가격표 띠. 빈 깡통 둘과 상자 넷은 keep 마스크
- `bookcase`: 원본 선반을 보존하고 지지면마다 서 있는 책 무리·누운 책·빈 틈. 책 18권, 씨앗 1017, 탁한 다섯 색, keep 마스크
- `dining_set`: 식탁 하나·서로 마주 보는 의자 둘. 상판 .76 m, 등받이 .88 m
- `table_overturned`: 식탁과 같은 원본·색·치수의 상을 90도 옆으로 눕힘
- `workbench`: 기본 도형: 틈 있는 두꺼운 상판 네 장·네 다리·아래 선반·끝 바이스·망치·대패. 어두운 나무 두 톤과 회색 쇠
- `office_desk`: 원본 상판·다리 보존. 한쪽 아래 기본 도형 서랍 받침(서랍 셋·손잡이) 추가
- `iron_bed`: Blender 기본 도형 철 침대: 머리·발 판(기둥·가로대·살), 옆 가로대, 매트리스와 덮은 담요. 긴 축 X, 긴 옆면 앞 +Z
- `drawer_chest_spilled`: 원본 몸체·서랍 재사용. 가운데 위 02는 깊이의 절반만큼 열고, 아래 05는 바닥에서 18도 기울임. 종이 네 장 추가, .90×.86 m 안
- `toolbox`: 기본 도형: 빈 몸통·뒤로 110도 열린 뚜껑·안쪽 쟁반·튀어나온 공구 둘. 바랜 빨강 몸체·검은 쇠 손잡이, 열린 전체 치수
