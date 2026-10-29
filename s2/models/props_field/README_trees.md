# 숲 모형

`tools/blender/props_field_trees.py`가 만든다. 단일 메시·Col 정점색·알파 1, 질감·재질 없음.
모형 이름/경로와 키를 유지한다. Quaternius 침엽수·자작나무와 Kenney 밑 덮개 셋은 모두 CC0.
굽기 전 장부는 `pending_bake`(면 수·바이트·해시·경계·폭 null)이고, 굽기가 끝나면 아래 「파일 확인값」에 실측이 들어간다.

## 원본과 꼴

| 이름 (침엽수는 같은 꼴의 `_snow` 포함) | 원본 | 키 m | 가지 층 | 가로 배율 | 삼각형 예산 / 목표 |
|---|---|---:|---|---:|---|
| spruce_tall | quaternius_nature / `PineTree_2.fbx` | 11 | 4 | 0.82 | 400~600 / 520 |
| spruce_mid | quaternius_nature / `PineTree_3.fbx` | 7.5 | 6 | 0.90 | 400~600 / 520 |
| spruce_round | quaternius_nature / `PineTree_1.fbx` | 6 | 5 | 1.10 | 400~600 / 520 |
| spruce_young | quaternius_nature / `PineTree_1.fbx` | 2.6 | 5층 중 위 3층, 드러난 밑줄기 ×0.35 | 0.90 | 200~400 / 300 |
| spruce_far | quaternius_nature / `PineTree_2.fbx` | 9 | 4층; 예산/층 보존 실패 시 위 1층, 밑줄기 ×0.20 | 0.82 | 80~100 / 96 |
| bush_juniper | kenney_nature_kit / `tree_pineGroundA.glb` | 1.1 | — | 1.00 | 1~200 / 기존 유지 |
| bush_dry | kenney_nature_kit / `plant_bushDetailed.glb` | 0.9 | — | 1.00 | 1~200 / 기존 유지 |
| fern_dry | kenney_nature_kit / `plant_bushLargeTriangle.glb` | 0.6 | — | 1.00 | 1~200 / 기존 유지 |
| birch_bare | quaternius_nature / `BirchTree_Dead_Snow_1.fbx` | 7 | — | 1.00 | 1~599 / 520 |

높이는 면 줄이기 뒤 밑동~우듬지 전체를 맞춘다. 가로 배율은 이 균일 배율에 추가 적용한다.
FBX 정적 확인: PineTree_1은 1,920삼각형·5층, 2는 1,692·4층, 3은 2,392·6층. 목표 수는 굽기 실측이 아니다.
1° 평면 줄이기(재질 경계 보존) 후 필요하면 collapse 비율을 탐색한다. 하한/상한 또는 가지 층·껍질 역할 보존 실패 시 굽기를 실패시킨다.
`birch_bare`는 `BirchTree_Dead_Snow_1.fbx`의 Snow 면을 빼고 White/Black을 다시 칠한다. 검은 무늬는 원본 재질에서 온다. 600 미만.

## 색 (선형 RGB)

| 역할 | R | G | B | 기본 Y | jitter 뒤 Y |
|---|---:|---:|---:|---:|---|
| needle | 0.035 | 0.064 | 0.058 | 0.05740 | 0.05051~0.06429 |
| needle_dark | 0.028 | 0.055 | 0.050 | 0.04890 | 0.04303~0.05477 |
| bark | 0.075 | 0.060 | 0.050 | 0.06247 | 0.05497~0.06996 |
| birch | 0.600 | 0.600 | 0.560 | 0.59711 | 0.52546~0.66877 |
| birch_mark | 0.070 | 0.070 | 0.065 | 0.06964 | 0.06128~0.07800 |
| juniper | 0.070 | 0.100 | 0.080 | 0.09218 | 0.08112~0.10324 |
| dry_leaf | 0.260 | 0.150 | 0.080 | 0.16833 | 0.14813~0.18853 |
| fern | 0.330 | 0.200 | 0.090 | 0.21970 | 0.19333~0.24606 |
| snow | 0.840 | 0.880 | 0.900 | 0.87294 | 고정, 윗면 바늘잎 22%에 최대 80% 혼합 |

Y = 0.2126R + 0.7152G + 0.0722B. 바늘잎 Y 0.04~0.08, 면 jitter ±12%, 알파 1.
`needle_dark`는 tall/far, `needle`은 mid/round/young에 쓴다. Kenney 셋의 원본·키·색·jitter는 그대로 둔다.
눈 짝은 완성된 기본형 BMesh 복사본이다. 같은 정점/삼각형/기본 명암에서, 바늘잎 법선의 위 성분 >0.55인 면만 기존 눈 (0.84, 0.88, 0.90)과 섞는다.
위 성분 0.55부터 0.85에서 최대 혼합 0.80, 그 가운데 22% 면에만(면 번호 해시) 덩어리로, 옆·아랫면·줄기는 기본형과 동일. PineTree_Snow_*의 눈 덩어리는 사용하지 않는다.
합격은 화면 흑백: 눈 짝 무리의 평균이 맨땅보다 어둡다(줌 24 낮).

## 굽기와 인계

```powershell
blender -b --factory-startup --python-exit-code 1 -P tools/blender/props_field_trees.py -- --repo . --src "<Kenney GLTF 폴더>" --src-quaternius "C:\dev\zombie\assets_raw\quaternius_nature\fbx"
```

`--src-quaternius`는 위 경로가 기본값이고 `--src`는 기존 Kenney GLTF 폴더 인수다.
부른 세션이 굽기 → Godot 가져오기 → `test_props_field_trees.gd` 실행 → 줌 24·36 낮·밤 전/후와 흑백 명도 → 화면 삼각형 합 전/후를 확인한다.
이 문서의 목표 RGB 검사로 게임 조명·셰이더를 거친 화면 명도 합격을 대신하지 않는다. 장부가 ready여도 화면 합격은 별도다.

## 파일 확인값

| 이름 | 상태 | 실제 삼각형 | 실제 층 | 바이트 | sha256 |
|---|---|---:|---:|---:|---|
| spruce_tall | ready | 520 | 4 | 54068 | 9767daca527bc10bc0864c0916cfe91dbc0725a9f37e415beb1eab9d53b23ee6 |
| spruce_tall_snow | ready | 520 | 4 | 54076 | aaaa1075d8d52722114f833f2219a06239028fa02fdeca369f0dc34e1cd43ae0 |
| spruce_mid | ready | 520 | 6 | 54048 | 5e59e11f3dd62a55d49aa00c361c284643fea7038a42991f8d508921c79c2990 |
| spruce_mid_snow | ready | 520 | 6 | 54060 | e43464eed6042c1698fa5c3ed260ac4476ce0087e1c60e9a3fd89d20b7343acb |
| spruce_round | ready | 520 | 5 | 54048 | 05fb396e7b4e784b816cb38bde10b682bd86e5dbce66fc3f06686f5c0607264d |
| spruce_round_snow | ready | 520 | 5 | 54060 | ecc911e6a59df3a7c85849414402457ea90d95acff97424130d46ea809fe9c6c |
| spruce_young | ready | 300 | 3 | 31624 | 75c1f71f92eb57061b4e90c2a179f8e18c8271cde3675a41fbb14cd81a571301 |
| spruce_young_snow | ready | 300 | 3 | 31632 | ca095d68b39922cb82146f35346d9a2ea3cbfd18a4e3ff72e0ff896348630d92 |
| spruce_far | ready | 96 | 4 | 10788 | b68b99447501f86ef76fc150a469a05859cbcab6f6573c7efb47bb3d70b55498 |
| spruce_far_snow | ready | 96 | 4 | 10796 | 2ec89dda4c54f4e73d530f75c59882075fa72cfebbe01c51566cca227cc5f7e4 |
| bush_juniper | ready | 82 | 0 | 9380 | 715f1d3c45e74a393be8a70fcca46124d6db3281b4729ce9bee081f4e2e9503c |
| bush_dry | ready | 52 | 0 | 6312 | da1790e5e15642703889f82d606b36f4d1e53d1e203997686231d8fa75379068 |
| fern_dry | ready | 21 | 0 | 3144 | c928954176094aff7ab8cf2b93509ca4c2da81fbf68640ef0848452460f40944 |
| birch_bare | ready | 520 | 0 | 54044 | 44086fc2288d9af4688b022e0e6e77a7e239e75ba8d94ffddb3348cfcbdfcd77 |
