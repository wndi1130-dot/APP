# 공용 소품

`tools/blender/props_common.py`가 생성한 장부다. 이 파일과 `catalog.json`은 손으로 고치지 않는다.

```
blender -b --factory-startup -P tools/blender/props_common.py -- --repo .
```

칸 1m, 소품마다 메시·면 묶음 각 하나, LOD 없음, 삼각형 상한 600. 재질·그림·셰이더 없이 6색 팔레트의 정점색을 쓴다.

rect 가운데 바닥에 놓는다. 기본 앞은 +Z, 위는 +Y. facing 0~3은 +Y 둘레 0/90/180/270도. 직사각형은 회전 후 X·Z 경계를 rect 크기에 맞추며 높이는 유지한다. 열린 문과 가지도 발자국에 포함한다.

크기 순서는 Godot X×Y×Z(가로×높이×깊이)다. 최빈 수는 지도 원문 rect 수이며 실제 런타임 배치 수와 구분한다.

| 이름 | 쓰임 | 발자국 m | 높이 m | 최빈 수/원문 수 | 삼각형/상한 | 크기 X×Y×Z m | 바이트 | 놓는 법 |
|---|---|---|---|---|---|---|---|---|
| `shelf` | 네 단 나무 선반 | 3×1 | 1.8 | 1556/1609 | 84/600 | 3×1.8×1 | 6824 | rect 가운데 바닥, facing |
| `cold_stove` | 불 꺼진 무쇠 난로와 짧은 관 | 1×1 | 1.1 | 1329/1329 | 140/600 | 1×1.1×1 | 10240 | rect 가운데 바닥, facing |
| `desk` | 서랍 둘 달린 나무 책상 | 2×1 | 0.75 | 1293/1297 | 120/600 | 2×0.75×1 | 9324 | rect 가운데 바닥, facing |
| `barrel` | 쇠 테 둘을 두른 나무 통 | 1×1 | 0.9 | 1310/1321 | 240/600 | 1×0.9×1 | 16212 | rect 가운데 바닥, facing |
| `bed` | 낮은 침대와 얇은 침구 | 2×1 | 0.5 | 1142/1144 | 120/600 | 2×0.5×1 | 9320 | rect 가운데 바닥, facing |
| `bare_tree` | 잎 없이 위로 뻗는 좁은 나무 | 1×1 | 5.2 | 1235/1235 | 220/600 | 1×5.2×1 | 15072 | rect 가운데 바닥, facing |
| `crate_stack` | 상자 셋을 두 단으로 쌓음 | 2×2 | 1.25 | 706/726 | 360/600 | 2×1.25×2 | 26136 | rect 가운데 바닥, facing |
| `sack_pile` | 무표식 저장 자루 넷 | 2×2 | 0.85 | 527/536 | 384/600 | 2×0.85×2 | 27316 | rect 가운데 바닥, facing |
| `file_cabinet` | 서랍 넷 철제 서류함 | 2×1 | 1.3 | 527/527 | 108/600 | 2×1.3×1 | 8512 | rect 가운데 바닥, facing |
| `part_crate` | 뚜껑 열린 부품 상자와 덩어리 셋 | 1×1 | 0.7 | 454/454 | 132/600 | 1×0.7×1 | 9808 | rect 가운데 바닥, facing |
| `handcart` | 바퀴 둘과 받침 달린 손수레 | 2×1 | 1 | 390/411 | 256/600 | 2×1×1 | 17188 | rect 가운데 바닥, facing |
| `blanket_chest` | 뚜껑 닫힌 나무 궤 | 2×1 | 0.65 | 389/391 | 96/600 | 2×0.65×1 | 7676 | rect 가운데 바닥, facing |
| `fridge_open` | 문이 90도 열린 빈 법랑 냉장고 | 1×1 | 1.5 | 355/355 | 108/600 | 1×1.5×1 | 8500 | rect 가운데 바닥, facing |
| `iv_stand` | 세 발 받침과 고리 둘인 링거대 | 1×1 | 1.6 | 346/346 | 292/600 | 1×1.6×1 | 19216 | rect 가운데 바닥, facing |
| `tool_chest` | 서랍 셋 낮은 공구함 | 2×1 | 0.8 | 331/331 | 96/600 | 2×0.8×1 | 7668 | rect 가운데 바닥, facing |
| `paper_cart` | 무문자 종이 묶음이 놓인 서류 수레 | 2×1 | 1.05 | 329/329 | 304/600 | 2×1.05×1 | 21208 | rect 가운데 바닥, facing |
| `oxygen_cylinder` | 받침 포함 산소통 하나 | 1×1 | 1.4 | 297/297 | 188/600 | 1×1.4×1 | 13228 | rect 가운데 바닥, facing |
| `pallet_stack` | 짐받이 세 단 | 2×2 | 0.6 | 286/288 | 396/600 | 2×0.6×2 | 28672 | rect 가운데 바닥, facing |

## 파일 확인값

| 이름 | sha256 |
|---|---|
| `shelf` | `2927d8abcae84cfc797ebe43aeef8245e512f5bbe636514ec92be1c57eb57304` |
| `cold_stove` | `f17baf0ec158f03902981c7b22cb26443b3c6e7d0e753de30a87f53b9e97433e` |
| `desk` | `ba4582f98a6eed65d21f3d7b80dc65283a80461867781a1bdc54dc00834acfd2` |
| `barrel` | `196c8052e2003041cda384d15b9c24277f15fdd55058ff406553fa4b60a9b8c5` |
| `bed` | `9d115cccc92708c2a636ffce413e56167ed3cb75b29a2f6eae8c9d7284305e30` |
| `bare_tree` | `1b188af967953061d2feff7b281c9c7e5323a3c05ec88d5abd971b13fe771fa1` |
| `crate_stack` | `324c46649e9c67c9bec7a1cb3143b2bfa2339ef4bab2a2dcd0244eda3ca0bd74` |
| `sack_pile` | `dcc716714d8740f5d03e338a788b92e19423466d91c8d86f7dbe4c361c3aedca` |
| `file_cabinet` | `488676c0996c55ccb1e925501e4ceaeff1f5ed8008df291f8092b59cdef873ef` |
| `part_crate` | `81381d60e5d10ad789fcf80e3f1ab09967613264ad5cb8a1fa0093e8cdb0fc92` |
| `handcart` | `e2784b18afedddebd877037707cebcc7cbfd937352ff8567c48a4b44ea7c36f3` |
| `blanket_chest` | `842c1894caa4e76b64a4e73f223e4ffed74bebad3bc9e365c23d29bf966085d4` |
| `fridge_open` | `c951a45caab2bb68e1bc8fc1839fb4c32b470da9459aedbfb7b3d7a732f4ff29` |
| `iv_stand` | `a9722c4417ebbf794e3388b387a52b174ed97ed5047dffde738f8c1b802deb60` |
| `tool_chest` | `eb07e803e6172107926368a2d2911d7df5b3f8a0741d435ff02d3f86d82eebb2` |
| `paper_cart` | `2f05b522418e88c0f1321b30df9c581072f60dbccfade3b6181a012c5df1b8b8` |
| `oxygen_cylinder` | `e2d6c95907262caf9cd9965df629a8d45de731bee7d5246b4421230bbff47f8b` |
| `pallet_stack` | `5e9d79e6d37c9f9b0c4021c744e9d43ebb45e386d301b1eb5503e2d05567878e` |

## 제외

- `wardrobe`: props_stop01/wardrobe.glb 기존 소품 사용.
- `workbench`: props_stop01/workbench.glb 기존 소품 사용.
