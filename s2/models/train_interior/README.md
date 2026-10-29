# 열차 실내 가구 33종

`tools/blender/train_interior.py`가 자동 생성한 장부.

X·Y·Z 경계 상자의 한가운데가 (0,0,0). +Y 위, +Z 앞. at에 그대로 놓고 yaw만 적용.

크기는 glTF X×Y×Z m. 최다 사용 크기 기준이며 동률은 원본 rows의 첫 크기를 선택한다.
종류마다 메시 1개·면 묶음 1개·Col 정점색. GLB 안에 재질·텍스처·빛·카메라 없음. 별도 셰이더 파일 없음.
vertex_colors.gd는 가져올 때 엔진 내장 StandardMaterial3D의 정점색 표시를 켠다. 별도 재질 파일은 만들지 않는다.
.import의 초기 설정은 이 스크립트가 준비하고 Godot --import가 최종화한다. 게임 코드는 수정할 필요가 없다.
개별 상한 600, 전체 상한 8,000. 전체 삼각형: 4284.

```text
blender -b --factory-startup -P tools/blender/train_interior.py -- --repo .
```

| 이름 | 쓰임 수 | 기준 size | 실제 크기 | 삼각형 | 바이트 | 형태 |
|---|---:|---|---|---:|---:|---|
| bench | 8 | 14.4×0.45×0.5 | 14.4×0.45×0.5 | 96 | 7712 | 세 줄 긴 널과 네 받침을 가진 긴 의자 |
| stove | 7 | 0.4×0.7×0.4 | 0.4×0.7×0.4 | 168 | 12148 | 검댕 몸체·상판·짧은 연결구를 가진 난로 |
| bunk_lower | 6 | 1.75×0.48×0.58 | 1.75×0.48×0.58 | 108 | 8568 | 낮은 다리·매트·베개를 가진 아래 침상 |
| bunk_upper | 2 | 2.8×0.14×0.6 | 2.8×0.14×0.6 | 60 | 5232 | 얇은 목재 받침과 매트·베개의 위 침상 |
| book | 5 | 0.35×0.04×0.25 | 0.35×0.04×0.25 | 72 | 6040 | 표지·책등·누런 종이 단면이 분리된 책 |
| blanket | 3 | 2.5×0.04×0.52 | 2.5×0.04×0.52 | 36 | 3516 | 완만한 접힘이 이어지는 한 장의 바랜 담요 |
| sacks | 2 | 0.6×0.46×0.6 | 0.6×0.46×0.6 | 152 | 15252 | 개인 소지품 없는 식량 포대 두 개 |
| workbench | 2 | 2.8×0.8×0.6 | 2.8×0.8×0.6 | 140 | 10700 | 하부 선반과 작은 바이스가 달린 작업대 |
| crates | 2 | 1.4×0.7×0.7 | 1.4×0.7×0.7 | 384 | 27904 | 널 틈과 보강대가 있는 화물 상자 두 개 |
| insulation_panel | 1 | 12×0.42×0.05 | 12×0.42×0.05 | 108 | 8572 | 8개 널 경계가 있는 긴 단열 패널 |
| side_table | 1 | 1×0.7×0.35 | 1×0.7×0.35 | 96 | 7724 | 세 줄 상판과 네 다리의 좁은 탁자 |
| supplies | 1 | 0.2×0.16×0.2 | 0.2×0.16×0.2 | 80 | 6120 | 가지런히 접은 의료용 천과 붕대 두 롤 |
| curtain_half_open | 1 | 0.6×1.3×0.035 | 0.6×1.3×0.035 | 44 | 4000 | 가운데가 열린 양쪽 주름 커튼 |
| medicine_box | 1 | 0.45×0.4×0.35 | 0.45×0.4×0.35 | 60 | 5240 | 문양 없이 가로 라벨이 있는 종이 약품 상자 |
| dining_table | 1 | 12×0.75×0.6 | 12×0.75×0.6 | 144 | 11056 | 긴 연속 상판과 여덟 다리의 식탁 |
| cooking_pot | 1 | 0.65×0.5×0.55 | 0.65×0.5×0.55 | 188 | 16732 | 속이 빈 솥과 양쪽 손잡이 |
| bowls | 1 | 0.7×0.08×0.3 | 0.7×0.08×0.3 | 228 | 19292 | 속이 파인 누런 그릇 세 개 |
| class_slate | 1 | 0.8×0.55×0.05 | 0.8×0.55×0.05 | 108 | 8596 | 목재 테두리와 짧은 분필 선의 칠판 |
| ballot_box | 1 | 0.55×0.5×0.55 | 0.55×0.5×0.55 | 72 | 6044 | 상단 투입 틈과 무문양 종이표의 투표함 |
| bell | 1 | 0.14×0.2×0.14 | 0.14×0.2×0.14 | 144 | 10336 | 황동 종 몸체와 짧은 목재 손잡이 |
| wrench | 1 | 0.1×0.45×0.08 | 0.1×0.45×0.08 | 60 | 5228 | 벌어진 두 턱과 납작한 손잡이의 렌치 |
| memorial_board | 1 | 0.6×0.7×0.06 | 0.6×0.7×0.06 | 84 | 6924 | 목재 테두리 안의 빈 추모판과 황동 명판 |
| ladle | 1 | 0.08×0.35×0.08 | 0.08×0.35×0.08 | 96 | 7364 | 오목한 국자 머리와 긴 손잡이 |
| tools | 1 | 0.6×0.1×0.4 | 0.6×0.1×0.4 | 84 | 6908 | 낮은 받침에 놓인 망치·스패너·드라이버 |
| shelf | 1 | 2×0.12×0.3 | 2×0.12×0.3 | 60 | 5188 | 길쭉한 널과 두 개의 아래쪽 선반 받침 |
| captain_desk | 1 | 1.6×0.75×0.7 | 1.6×0.75×0.7 | 168 | 12768 | 서랍 세 칸과 황동 손잡이의 책상 |
| radio | 1 | 0.45×0.3×0.3 | 0.45×0.3×0.3 | 188 | 13676 | 스피커 슬롯·주파수 창·노브 둘의 라디오 |
| coal_pile | 1 | 12×0.9×1.5 | 12×0.9×1.5 | 104 | 10680 | 불규칙한 능선이 이어지는 긴 석탄 더미 |
| food_crates | 1 | 3×1×1.2 | 3×1×1.2 | 488 | 36680 | 창고칸 얼음 상자 둘(train_ice_chest.py) |
| divider | 1 | 0.1×2×1.1 | 0.1×2×1.1 | 60 | 5188 | 세로 널 네 줄이 보이는 얇은 목재 칸막이 |
| empty_platform | 1 | 3×0.5×1.2 | 3×0.5×1.2 | 96 | 7700 | 빈 화물용 받침의 금속 골조와 상판 |
| storage_board | 1 | 0.5×0.35×0.04 | 0.5×0.35×0.04 | 108 | 8576 | 목재 테두리와 짧은 기록 선의 보관판 |
| boiler | 1 | 10×2×1.4 | 10×2×1.4 | 200 | 13676 | 긴 단일 보일러 몸체·받침·배관·계기 |

## 다른 크기로 쓰인 이름

크기 차이는 자동으로 늘리거나 줄이지 않는다. 배치 코드는 원래 크기를 그대로 쓴다.
- bench: 14.4×0.45×0.5 (7회), 10.82×0.45×0.3 (1회). 기준 14.4×0.45×0.5.
- book: 0.35×0.04×0.25 (1회), 0.4×0.08×0.3 (1회), 0.4×0.05×0.25 (1회), 0.4×0.04×0.28 (1회), 0.4×0.06×0.3 (1회). 기준 0.35×0.04×0.25.
- blanket: 2.5×0.04×0.52 (2회), 1.2×0.04×0.45 (1회). 기준 2.5×0.04×0.52.
- sacks: 0.6×0.46×0.6 (1회), 3×0.8×1.4 (1회). 기준 0.6×0.46×0.6.
- workbench: 2.8×0.8×0.6 (1회), 2×0.8×0.6 (1회). 기준 2.8×0.8×0.6.
- crates: 1.4×0.7×0.7 (1회), 3×1×1.4 (1회). 기준 1.4×0.7×0.7.

## SHA-256

| 이름 | sha256 |
|---|---|
| bench | 8c97702c34b19a0cccf3e5c7ee1017606a44b9d27e4d60ccd7394000a0b718e5 |
| stove | 7e3973b6360c61e3617a502a6b95a4cf144772c9443e180ad4ddc56ecc9bdb05 |
| bunk_lower | ab8fa92b1243bc5443a9ecf0f2b7759fee602f3e9d3a68f6c42f9905a91a58db |
| bunk_upper | 7a04a761a93b57d8e256238624610933d53a712cfc45bdf1b284e5f320925902 |
| book | 5a647f723fd20ad14e2c27461b7036078668a767702e8fd403a950e16ff7c3cf |
| blanket | ffe9699d49611cba1bc0525e4e1e2175e15fecb2265674ffdd24f443a7d2fee0 |
| sacks | 13a1a79e811221fc1e5c02923dc2b4c4203fc089cfd1a9460a6cd873f4cf7e42 |
| workbench | 9a652e133df4b040b8661093798f248be146a38d01aab8df7fede33797223725 |
| crates | b34746025f2ee3d168339f000071f959b7481b0d746ba1aafd270e8de3453c4b |
| insulation_panel | 5f544851ae430c913f59050bf36c953f6cb2f13ec6e2a92e853256effd720668 |
| side_table | 5d865cd53b3092c7276c6070c43261158a70bb28ff6915b8ed915a30fd60749a |
| supplies | 968fc6193b3b862a9d3facae83a9be0859126dbcc5cc1843768a757a8ea84694 |
| curtain_half_open | abeb6ac3630daab836b57ead8406d6e0c239d3da696506dc88c47c223a1d8a81 |
| medicine_box | ae94e7c1e00ddc9a6cb6ac3466f1a8e5ee460463c0a6ba9422d10b5fad14d4fe |
| dining_table | 655ae2202751e4384d6c3e6e9eb3b0b668647094d22cad94e2e81f3ce3f0eab6 |
| cooking_pot | 1262ad212908498f0a3a29b5f2391cd882d1c14f1aa84564bfe6b93958005c49 |
| bowls | e3d34a8e5deeffe089ce88df3955dd6153d1ff59e40103b383c1b5a4131fce12 |
| class_slate | e532f60a72ecc885b993c50d95e714d7c2d7ea129c88e4eebabd2e2926fe792a |
| ballot_box | 39f202d7f0a514e934636ed6d4f30e5f790c9fe097953ade1c8a91f57cf0c98f |
| bell | 872ba2d6f5566b26abbe8d3dd52e5c8a4921b13abe547790c5903898f1e8a1df |
| wrench | 4396cd42b8417ab1509b6e47a2d5222be49a07871661a7f9eed5d762de0d33ec |
| memorial_board | a71b185dc884aa5a5a4f164b65a29d22f0fefd9e94447909d581149828197a55 |
| ladle | 300d1dd6962247789e46f0597d750be27ffe9f0b72ab9df99fd073ed30a070f3 |
| tools | 2338c323b17274bc797ebbc9d6867b72561d807a8ae2410e0d993c8ffefac494 |
| shelf | 0c738ed341c86d7ab8c4ee0ff1581493afc72d74473a553671479cb31570f69e |
| captain_desk | 68d8ac59527cdbda102cb792b14f031c065b610062b2984e47d92cc0a23e02e5 |
| radio | f46b80d612b8558cd746f2f5d0b1f3a2ded8a1642a567cffaf55d0c45811ca27 |
| coal_pile | 0674c9698b9b58d462d7f1e6e86ade3bf0c132849427b25ccd238d6305c1dcf7 |
| food_crates | 1f7287a4d048888a398878ec092f2941d09fbc593391dcfd56429782aaf581fa |
| divider | efd284c70d8c5996198a2c1306e45c2dd44bb81294b7c809a214885b8769cf91 |
| empty_platform | a483cbc8b6b12227df6876600d6e145f3cf86891474ffd1a88a8d9980d737af5 |
| storage_board | 588cdbeef2d108a2c338ea5963da041a3b5fd0d6665843795228220f5648b0b3 |
| boiler | b4addb80fbb4e989f00949507ba0289b090a31a52a80925e6cd2717f2ce99f40 |

## 팔레트 (선형 RGB)

- wood: 0.3×0.25×0.2
- wood_worn: 0.42×0.35×0.27
- wood_dark: 0.18×0.15×0.12
- iron: 0.12×0.12×0.13
- iron_worn: 0.24×0.24×0.25
- soot: 0.045×0.045×0.052
- cloth: 0.5×0.45×0.4
- cloth_faded: 0.64×0.58×0.51
- paper: 0.8×0.78×0.7
- paper_aged: 0.62×0.59×0.49
- brass: 0.7×0.56×0.3
- brass_dark: 0.4×0.32×0.17

stove는 기존 코드의 stove_builder 분기로 건너뛰므로 파일만으로 교체되지 않는다.
난로 기본 material 표기는 wood지만 금속 몸체이므로 iron/soot 계열을 썼다. 불 자리 모델은 만들지 않는다.

## 공개 3D로 바꾼 것

`tools/blender/train_interior_swap.py`(공개 3D)와 `tools/blender/train_ice_chest.py`(얼음 상자)가 위 표의 같은 경로를 덮어쓰고, `tools/blender/train_car_dress.py`(찬 칸·꼬리칸·운전실 꾸밈)가 새 경로를 더한다. 전체 삼각형: 7430. `tools/blender/train_car_layers.py`(사는 칸 세 겹 꾸밈: 천장·벽·바닥 열 가지)도 새 경로를 더한다.

| 이름 | 원본 | 크기 | 삼각형 | 색 | sha256 |
|---|---|---|---:|---|---|
| sacks | Poly Haven cement_bag (CC0) | 0.6×0.46×0.6 | 540 | cloth, cloth_faded | 13a1a79e811221fc1e5c02923dc2b4c4203fc089cfd1a9460a6cd873f4cf7e42 |
| crates | Poly Haven wooden_crate_02 (CC0) | 1.4×0.7×0.7 | 540 | wood_dark, wood_worn | b34746025f2ee3d168339f000071f959b7481b0d746ba1aafd270e8de3453c4b |
| food_crates | 손으로 만듦(tools/blender/train_ice_chest.py) | 3×1×1.2 | 588 | cloth, cloth_faded, frost, ice, ice_dark, iron, iron_worn, wood, wood_dark, wood_worn | 1f7287a4d048888a398878ec092f2941d09fbc593391dcfd56429782aaf581fa |
| cupboard | Poly Haven painted_wooden_shelves (CC0) | 0.52×1.12×0.38 | 524 | wood_dark | bba09d580fdb9a0b29ce47a08c63d0f889ce9183180b6ec4606ebb614af1d013 |
| wood_chair | Poly Haven painted_wooden_chair_01 (CC0) | 0.44×0.96×0.54 | 532 | wood, wood_dark, wood_worn | 7adc491ae241dc704dba49531007df9e829d85294801782f4accbd2009d89161 |
| blanket_stack | 손으로 만듦(tools/blender/train_car_dress.py) | 0.82×0.28×0.53 | 128 | blanket_stripe, cloth, cloth_faded | 2a9229be17cab6b11ed41d11ed092b39a07c28a3867ca26e674efc3de1763abd |
| lantern_off | 손으로 만듦(tools/blender/train_car_dress.py) | 0.16×0.34×0.16 | 136 | glass_dark, iron, iron_worn | fca900d76010c7ce41432d819b2aecad0a8de0a9ba4a023e86c0f49fa9186a64 |
| blanket_curtain | 손으로 만듦(tools/blender/train_car_dress.py) | 3.6×2.77×0.12 | 152 | blanket_stripe, iron, wool, wool_dark | 7f2a03a2ba54c3f730c7fda80e43377e9770bbd383fdf823a9ad3efa05d6710e |
| laundry_line | 손으로 만듦(tools/blender/train_car_dress.py) | 3×0.61×0.01 | 68 | blanket_stripe, cloth, cloth_blue, cloth_faded, paper_aged, wood_worn | 208cd57d14fe8ae1821a768110eabb0e08ee7eaf6a67fe70e06844c9329800d2 |
| patch_boards | 손으로 만듦(tools/blender/train_car_dress.py) | 1.46×0.88×0.05 | 108 | iron, wood, wood_dark, wood_worn | a7a11c42b690ec8aca725eab0b742f7ac312c7fd98e308d82052aac181982e6a |
| coal_heap | 손으로 만듦(tools/blender/train_car_dress.py) | 2.4×0.63×1.1 | 100 | iron, soot | 109a1fab0042fcc7e770f07caf67a4734aa9bab00fca52de9637582203339a50 |
| hang_lamp | 손으로 만듦(tools/blender/train_car_layers.py) | 0.13×0.32×0.13 | 100 | brass, brass_dark, glass_warm, iron | e9b5d79607c6298c1f8f7bbd7878dc6c7ade333513f1982136acb4ef3dd60baa |
| drying_line | 손으로 만듦(tools/blender/train_car_layers.py) | 1.21×0.42×0.01 | 68 | blanket_stripe, cloth_faded, iron, rope, wool_dark | 766d50f6b7378f30acd2f90cd80914fd1a57d73108ebffa5c051426cdd21e350 |
| hang_pot | 손으로 만듦(tools/blender/train_car_layers.py) | 0.28×0.48×0.24 | 80 | iron, iron_worn | e73b04b1fbe264827072e2c95915c81a7d541a8211cd25af960c9272cbe15234 |
| coat_hook | 손으로 만듦(tools/blender/train_car_layers.py) | 0.8×0.86×0.13 | 128 | blanket_stripe, wood_dark, wood_worn, wool, wool_dark, wool_moss | 53d8d225b64a3833d6d999c07b3822685112e9635935f426f35876cd18593c0c |
| wall_notes | 손으로 만듦(tools/blender/train_car_layers.py) | 0.68×0.46×0.02 | 22 | cloth_faded, paper, paper_aged, wood_worn | 1b504788f08cdc231d301178c5c35a2ae666a471dabaa5f12bd1beb6e5b6061c |
| wall_rack | 손으로 만듦(tools/blender/train_car_layers.py) | 0.72×0.32×0.18 | 112 | glass_dark, iron_worn, wood, wood_dark | e2791ce6e4645d86fb176245fce4bdb73e58722bcabf05d47d43e25a5480acbb |
| rug | 손으로 만듦(tools/blender/train_car_layers.py) | 1.6×0.01×0.9 | 16 | blanket_stripe, wool, wool_dark | 0dbb14593f7b75e1e7cb7d786ac25d4329539e4593b19bf4f9e05e0cbd4f269a |
| bucket | 손으로 만듦(tools/blender/train_car_layers.py) | 0.29×0.38×0.29 | 68 | iron, iron_worn | 61f97fff872a0d7abdcb4821f39761ac8034d9d28b3a771c2ee66b4e2a1bdd4b |
| firewood | 손으로 만듦(tools/blender/train_car_layers.py) | 0.42×0.2×0.5 | 80 | wood, wood_worn | 15b35dbda9eee7e311c8079adbe7c84a9323bb7f255ada7244e0da296048d91b |
| basket | 손으로 만듦(tools/blender/train_car_layers.py) | 0.36×0.33×0.26 | 80 | cloth_faded, wood, wood_dark, wood_worn | d2d4a4416904cad785d7929ae740e9bf468fefaee7b2af074cc10a0d7ad66917 |
