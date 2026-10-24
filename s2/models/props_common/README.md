# 공용 소품

`tools/blender/props_common.py`가 생성한 장부다. 이 파일과 `catalog.json`은 손으로 고치지 않는다.

```
blender -b --factory-startup -P tools/blender/props_common.py -- --repo .
```

칸 1m, 소품마다 메시·면 묶음 각 하나, LOD 없음, 삼각형 상한 600. 재질·그림·셰이더 없이 12색 팔레트와 그 명암을 정점색 Col로 쓴다.

rect 가운데 바닥에 놓는다. 기본 앞은 +Z, 위는 +Y. facing 0~3은 +Y 둘레 0/90/180/270도. 직사각형은 회전 후 X·Z 경계를 rect 크기에 맞추며 높이는 유지한다. 열린 문과 가지도 발자국에 포함한다.

크기 순서는 Godot X×Y×Z(가로×높이×깊이)다. 최빈 수는 지도 원문 rect 수이며 실제 런타임 배치 수와 구분한다.

| 이름 | 쓰임 | 발자국 m | 높이 m | 최빈 수/원문 수 | 삼각형/상한 | 크기 X×Y×Z m | 바이트 | 놓는 법 |
|---|---|---|---|---|---|---|---|---|
| `shelf` | 네 단 나무 선반 | 3×1 | 1.8 | 1556/1609 | 336/600 | 3×1.8×1 | 24468 | rect 가운데 바닥, facing |
| `cold_stove` | 불 꺼진 무쇠 난로와 짧은 관 | 1×1 | 1.1 | 1329/1329 | 404/600 | 1×1.1×1 | 28084 | rect 가운데 바닥, facing |
| `desk` | 서랍 둘 달린 나무 책상 | 2×1 | 0.75 | 1293/1297 | 288/600 | 2×0.75×1 | 21088 | rect 가운데 바닥, facing |
| `barrel` | 쇠 테 둘을 두른 나무 통 | 1×1 | 0.9 | 1310/1321 | 488/600 | 1×0.9×1 | 33448 | rect 가운데 바닥, facing |
| `bed` | 낮은 침대와 얇은 침구 | 2×1 | 0.5 | 1142/1144 | 276/600 | 2×0.5×1 | 20244 | rect 가운데 바닥, facing |
| `bare_tree` | 잎 없이 위로 뻗는 좁은 나무 | 1×1 | 5.2 | 1235/1235 | 376/600 | 1×5.2×1 | 26604 | rect 가운데 바닥, facing |
| `crate_stack` | 상자 셋을 두 단으로 쌓음 | 2×2 | 1.25 | 706/726 | 468/600 | 2×1.25×2 | 33700 | rect 가운데 바닥, facing |
| `sack_pile` | 무표식 저장 자루 넷 | 2×2 | 0.85 | 527/536 | 512/600 | 2×0.85×2 | 45500 | rect 가운데 바닥, facing |
| `file_cabinet` | 서랍 넷 철제 서류함 | 2×1 | 1.3 | 527/527 | 384/600 | 2×1.3×1 | 27836 | rect 가운데 바닥, facing |
| `part_crate` | 뚜껑 열린 부품 상자와 덩어리 셋 | 1×1 | 0.7 | 454/454 | 332/600 | 1×0.7×1 | 23556 | rect 가운데 바닥, facing |
| `handcart` | 바퀴 둘과 받침 달린 손수레 | 2×1 | 1 | 390/411 | 528/600 | 2×1×1 | 37004 | rect 가운데 바닥, facing |
| `blanket_chest` | 뚜껑 닫힌 나무 궤 | 2×1 | 0.65 | 389/391 | 204/600 | 2×0.65×1 | 15236 | rect 가운데 바닥, facing |
| `fridge_open` | 문이 90도 열린 빈 법랑 냉장고 | 1×1 | 1.5 | 355/355 | 364/600 | 1×1.5×1 | 26168 | rect 가운데 바닥, facing |
| `iv_stand` | 세 발 받침과 고리 둘인 링거대 | 1×1 | 1.6 | 346/346 | 476/600 | 1×1.6×1 | 31076 | rect 가운데 바닥, facing |
| `tool_chest` | 서랍 셋 낮은 공구함 | 2×1 | 0.8 | 331/331 | 360/600 | 2×0.8×1 | 26152 | rect 가운데 바닥, facing |
| `paper_cart` | 무문자 종이 묶음이 놓인 서류 수레 | 2×1 | 1.05 | 329/329 | 516/600 | 2×1.05×1 | 35156 | rect 가운데 바닥, facing |
| `oxygen_cylinder` | 받침 포함 산소통 하나 | 1×1 | 1.4 | 297/297 | 436/600 | 1×1.4×1 | 30336 | rect 가운데 바닥, facing |
| `pallet_stack` | 짐받이 세 단 | 2×2 | 0.6 | 286/288 | 540/600 | 2×0.6×2 | 40040 | rect 가운데 바닥, facing |

## 파일 확인값

| 이름 | sha256 |
|---|---|
| `shelf` | `c82e2e49bb54dff9360c81adbc93e8ac592694b195082c7b3da36aa10497801c` |
| `cold_stove` | `25917b868cae200e4fad33719f6c3f0a3a36f36d69eb1ad17fec93a6bbd4436f` |
| `desk` | `6bce09810d3c33b6146fd8f40a7027ce9980c981d8203a15622715ef46516a6f` |
| `barrel` | `440ded97a8f9aca4aa4b6705f1e630c4ab9980388259c9709fbf62fcd420f207` |
| `bed` | `99df235b655efe35411efb61ed9f60d66296e05642ddebea038c6e526aff263a` |
| `bare_tree` | `c354c893f97cf9dcd0981ee00a4c688a07443a983685200afa5f440fda18c2f5` |
| `crate_stack` | `4aa6d7a131dd705c5b7a2d794e39f56313ff5e79aeddaab319dd9acabc6d73f8` |
| `sack_pile` | `504c2a96c7ae3532ecc927811152cb72765bbf8a95125cb2fc619b5a790e6e7a` |
| `file_cabinet` | `be90670796b7c67812a42df4d01006bb64853e36db6802bcdf7eb0989878fca7` |
| `part_crate` | `9907df9565905754ccabf241597b221d616a459ac7e8ed3308f4cb319e01e065` |
| `handcart` | `1a660d3b4f9e850bfdb592b2c2f95e3c6b9c5dce51e3fba3ddf3c30ff437a138` |
| `blanket_chest` | `f01fa292adcd5e4972724dd182b06ac6d977d569fd03b95bf0e437815b0649b2` |
| `fridge_open` | `d466b667eee3fb9dd41264c9609e38717f8aa39e252386297180dae28ebdee9b` |
| `iv_stand` | `47a4b92c9a587e89028500cf4d7340efdac9ad087f8d06f76f6b41abaaf92258` |
| `tool_chest` | `69f5ee1ec2855371edec0c5a950366721ad42d83d6fc236a30e937e9a2b58ada` |
| `paper_cart` | `9a49ef84fe72c09755c10f6166e16d5318b1e91015e60e1705143f0769d3c935` |
| `oxygen_cylinder` | `74294192de68ed240140f80a8787ac5baa2312e62f3b39e2190033cc071a5b3c` |
| `pallet_stack` | `b716068626390fdd3810b3770871018955e65937720e49d877ece3ad4d21d59f` |

## 제외

- `wardrobe`: props_stop01/wardrobe.glb 기존 소품 사용.
- `workbench`: props_stop01/workbench.glb 기존 소품 사용.
