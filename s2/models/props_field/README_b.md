# 지도 소품 B

`tools/blender/props_field_b.py`가 생성한 장부. 메시·면 묶음 각 하나, Col 정점색, 삼각형 ≤600.

rect 가운데 바닥. +Y 위, +Z 앞. facing은 +Y 둘레 시계 방향 0/90/180/270도. 현 map_view는 크기를 보정하지 않음.

| 이름 | 수 | 발자국 m | 높이 m | solid | 삼각형 | 바이트 | 판단 |
|---|---:|---|---:|---|---:|---:|---|
| power_pole | 38 | 1×1 | 5.2 | wall:38 | 124 | 8992 | wall 전봇대: 전선 없이 좁은 가로대·애자로 식별, 높이 예외. |
| sleeper_stack | 38 | 3×1 | 1.05 | low:38 | 144 | 11040 | low: 낡은 침목을 세 단으로 쌓고 윗단에 눈. |
| cable_drum | 37 | 2×2 | 1.15 | none:19, low:18 | 196 | 12876 | none/low 혼합: 케이블 권취통의 둥근 플랜지를 살리기 위해 높이 예외. |
| ration_ledger_chest | 37 | 2×1 | 0.48 | none:27, low:10 | 84 | 6848 | none 우세: 낮은 배급 장부함, 뚜껑 위 장부 두 권. |
| hose_reel | 36 | 2×2 | 1.0 | low:18, none:18 | 260 | 17080 | low/none 동수: 받침 있는 호스 릴과 짧은 노즐, low 높이 채택. |
| spruce | 36 | 1×1 | 4.2 | tree:36 | 188 | 12444 | tree: 좁은 침엽 수관 세 층과 눈, 나무 높이 예외. |
| cloth_bolt_rack | 34 | 3×1 | 1.15 | none:24, low:10 | 240 | 16228 | none 우세지만 원단 롤 보관대 의미 우선, 옷이나 소지품 더미 아님. |
| coal_wagon | 34 | 10×3 | 2.0 | wagon:34 | 386 | 25908 | wagon: 열린 석탄 적재함·대차, 사람 승차 설비 없음. |
| loom | 34 | 3×2 | 1.2 | none:21, low:13 | 212 | 15396 | none/low 혼합: 직기 틀·날실·직물 면을 구분하도록 높이 예외. |
| log_stack_low | 32 | 3×6 | 1.2 | low:32 | 204 | 13700 | low: 긴 통나무 여덟 개와 밝은 절단면, 1.3m 미만. |
| axe_rack | 31 | 2×1 | 1.05 | none:16, low:15 | 156 | 11672 | none/low 혼합: 도끼 세 자루를 수직 보관하는 낮은 설비로 예외. |
| heavy_coat_rack | 31 | 3×1 | 1.25 | none:16, low:15 | 156 | 11868 | none/low 혼합: 빈 외투 걸이 설비만 제작, 옷·가방·신발 더미 없음. |
| sunken_bow | 31 | 2×4 | 1.9 | wall:31 | 44 | 4212 | wall: 수면 위 솟은 뾰족한 선수와 열린 선체, 1.8m 이상. |
| sunken_wheelhouse | 31 | 4×3 | 1.9 | wall:31 | 128 | 9792 | wall: 창 개구부를 남긴 조타실 윗부분, 지붕에 눈. |
| battery_rack | 30 | 2×1 | 1.1 | low:18, none:12 | 264 | 19436 | low 우세: 두 단 배터리와 단자, 글자·경고표지 없음. |
| engine | 30 | 16×3 | 3.2 | (none):30 | 368 | 24656 | 별도 train_cars의 기관차: 16×3m 원문 치수, 연기·굴뚝·승객 설비 없음. props 자동 배치 대상 아님. |
| fuel_drum_stack | 30 | 2×2 | 0.95 | none:18, low:12 | 432 | 26592 | none 우세지만 연료통 세 개의 원통 형태 우선, 낮은 한 단 예외. |
| lumber_stack | 29 | 4×2 | 1.05 | low:19, none:10 | 180 | 13552 | low 우세: 각재를 간격 둔 네 단으로 적재. |
| sunken_deck_section | 29 | 8×3 | 0.65 | low:29 | 192 | 14408 | low: 고르지 않은 갑판 조각과 받침보, 난간·승차 자리 없음. |
| buoy_line | 28 | 2×1 | 0.3 | none:28 | 196 | 13648 | none: 바닥에 놓인 부표 세 개와 낮은 연결 밧줄. |
| scrap_stack | 28 | 2×3 | 1.1 | low:28 | 112 | 8532 | low: 금속 판재·관 폐자재만, 소지품을 섞지 않음. |
| shore_ice_heap | 28 | 3×2 | 0.95 | low:28 | 156 | 11556 | low: 별도 제외 7종에 없는 물가 얼음 덩어리 세 개, 불투명 정점색. |
| firewood_stack | 27 | 3×2 | 1.05 | low:27 | 204 | 13704 | low: 절단면이 보이는 장작 단, 1.3m 미만. |
| herb_drying_rack | 26 | 3×1 | 1.1 | none:18, low:8 | 232 | 16952 | none 우세: 약초 묶음을 걸어 말리는 틀 의미를 위해 높이 예외. |
| door_pile | 25 | 2×1 | 0.65 | low:17, none:8 | 132 | 10188 | low 우세: 떼어 낸 문짝 세 장, 사람 칸의 문·빗장·잠금 아님. |
| dry_bush | 25 | 2×2 | 0.45 | none:25 | 196 | 14600 | none: 잎 없는 낮은 갈색 잔가지, 바닥 가까운 높이. |
| net_drying_rack | 24 | 4×1 | 1.2 | low:24 | 248 | 18004 | low: 성긴 어망과 두 기둥, 철조망 없이 섬유 밧줄색. |
| fuel_tank | 23 | 3×2 | 1.25 | low:14, wall:9 | 224 | 14568 | low14/wall9 혼합: 다수 low 기준 수평 연료탱크, wall 배치와 높이 불일치 남음. |
| log_scatter | 23 | 3×3 | 0.4 | none:23 | 72 | 5420 | none: 바닥에 흩어진 짧은 통나무 세 개. |
| rail_marker | 23 | 1×1 | 0.48 | none:23 | 48 | 4312 | none: 낮은 직사각 철도 표지, 번호·대기 구획·십자 없음. |
| rock_ridge | 23 | 8×6 | 2.4 | wall:23 | 192 | 13620 | wall: 눈 덮인 각진 바위 능선 세 봉우리, 시야 차단 높이. |
| ice_sled_load | 22 | 3×1 | 0.95 | low:21, none:1 | 124 | 9380 | low 우세: 얼음 덩어리만 실은 썰매, 소지품 더미 없음. |
| buffer_stop | 21 | 1×2 | 1.1 | low:21 | 128 | 9396 | low: 삼각 지지대와 목재 완충 보, 철길 종단 설비. |
| office_cabinet | 21 | 2×1 | 1.15 | low:11, none:10 | 72 | 5996 | low 우세: 두 문 달린 낮은 사무용 철제 보관장. |
| overturned_boat | 21 | 4×2 | 1.1 | low:21 | 64 | 5752 | low: 뒤집힌 뾰족 선체와 바닥 리브, 눈 얹힌 용골. |
| plate_stack | 21 | 3×2 | 0.7 | low:11, none:10 | 108 | 8508 | low 우세: 철판 여섯 장과 받침 각재, 낡은 금속색. |
| fallen_log | 20 | 5×1 | 0.65 | low:20 | 60 | 4896 | low: 부러진 가지와 절단면이 있는 쓰러진 통나무. |
| floor_shell | 20 | 32×16 | 0.12 | none:20 | 72 | 5988 | none: 가장 흔한 32×16m의 얇은 바닥판만, 벽·창 막음 없음. |
| stair_stub | 20 | 1×2 | 0.48 | none:20 | 72 | 5988 | none: 3단 돌계단 잔재, 높이 0.5m 이하. |
| fish_trap_stack | 19 | 2×2 | 1.1 | low:19 | 576 | 41284 | low: 속이 보이는 작은 통발 세 개, 어구 바구니 형태. |
| flat_wagon | 19 | 12×3 | 1.2 | wagon:19 | 320 | 21304 | wagon: 눈 얹힌 빈 평판 화차와 대차, 승객·하역 경사로 없음. |
| fallen_mast | 18 | 7×1 | 0.5 | low:18 | 72 | 5596 | low: 가로대와 짧은 밧줄이 붙은 쓰러진 돛대. |
| pier_deck | 18 | 3×22 | 0.18 | none:18 | 192 | 14392 | none: 입력 최빈 3×22m의 낮은 잔교 판재, 난간·경사로 없음. |
| vent_pipe | 18 | 1×1 | 2.0 | wall:18 | 156 | 10316 | wall: 광산 환기관과 빗물 막이, 굴뚝 연기 자리 없음. |
| fish_crate_stack | 17 | 2×2 | 1.1 | low:11, none:6 | 252 | 18600 | low 우세: 생선 운반 나무상자 네 개, 내용물·소지품 없음. |
| hay_cart | 17 | 3×2 | 1.2 | low:15, none:2 | 240 | 16532 | low 우세: 마른 건초 두 묶음과 수레 바퀴·손잡이. |
| medicine_crate | 17 | 1×1 | 0.48 | none:13, low:4 | 72 | 6000 | none 우세: 낮은 약품 상자와 빈 직사각 라벨, 빨간 십자·초승달 없음. |
| coal_bin | 16 | 3×2 | 0.95 | none:8, low:8 | 138 | 10412 | none/low 동수: 열린 석탄함의 벽과 석탄 덩어리, low 기준 예외. |
| firewood_rick | 16 | 3×1 | 1.15 | low:16 | 216 | 14928 | low: 양 끝 지지판 안에 가지런히 쌓은 장작, 눈 덮인 윗단. |

## 파일 확인값

| 이름 | SHA-256 |
|---|---|
| power_pole | `13915876b7b22851e54f13134d0ab9c4cf77e0a1b214b5937696f86c8af35223` |
| sleeper_stack | `580e2e06c79e43432baa0c5d04951577a5d113aa7b29bd9541db62c41e099e9b` |
| cable_drum | `731d91acce909fdec01d2d148cc6d987a7b2fb1806564ba300565a7d7578dae6` |
| ration_ledger_chest | `086b05d5efa24435a1d2350168152e87cbe7805921eb798d89855816402920e1` |
| hose_reel | `a049fd688a169dbc300bab20ec5557008fdd4fe338d8e127ae3468a7d8fdd22d` |
| spruce | `49421b743304a006275cff9b4bcf3391077ed47deaac7c6d463fbc8305457c2b` |
| cloth_bolt_rack | `cdfedda8350c5acf8f80e849a97f7da5f1bf3e2c66e804ecc903d47ae78ad9ab` |
| coal_wagon | `dea0df03b727e6c33d18d03b096b4e99999f97a7f5128d9d7175c07497832744` |
| loom | `f9a0d3d4203464975bec561e24a3994aaa2151d19b2e0fbfccf43ad1a5a3e59b` |
| log_stack_low | `98e8c6ef0cd891cca837f15966967a2ab7f7c5b335a921fa714fa11268fe6694` |
| axe_rack | `874d9199f7717a42e612fa60364df6d3d9f2250e351afd4f2c6562404ebc9c94` |
| heavy_coat_rack | `488a8bb9adfa8850f1e61705969f4b588cf09e1e6693715d7761ed921785d40c` |
| sunken_bow | `e159eabedfe8d1b6437479973f86f16f505e9278ea4efa686d10c1e8ca976cb8` |
| sunken_wheelhouse | `a8aab857cbce54f2d4c3fe2b13bc567e2ee5057804d4ccd101b6a17bdf439218` |
| battery_rack | `ed367f9fcb31481aa1bdfd89eb2e96f07567aa3dc9e9d51c2cb0d1a7dcc75298` |
| engine | `6cfb6ccbb099ef170b153f26d88945e8a593832d8871210bcb50fa24611cdc7e` |
| fuel_drum_stack | `c369c47b71512e9fcbdab1feaf3793501853f7a1af82c0990474fbc6ee7ec3a6` |
| lumber_stack | `d4c20dee3930f47173de17ce57b89f15917018d6cb37d77861362038101954f2` |
| sunken_deck_section | `e208fae83de7e256cdd2a6a1899b6bcb64b248f16157eba669a77862e6928505` |
| buoy_line | `64a64b30a59521c130f15a2eb58ce3fe3c2984e1bcd10b95c5da3a685560430b` |
| scrap_stack | `73742ac2738058d0b995d6989552020b396fe975b9f97dcbb596762099e7bf82` |
| shore_ice_heap | `1f12264aefa4d7e2169b1edbb63484a12f58693d04188d60ec7b3afceb36f815` |
| firewood_stack | `43e71f84dde4643bbe4499edc7b0508a983cba56a07d53d92f4ae0c6df873ba1` |
| herb_drying_rack | `ee69f2005ff6744a181353626ccb8555270b66697497ef120cef4566054cd282` |
| door_pile | `5e301e4e1c589365d1d0735d9fd9b8f860efbb1052b98438627965091fd0fcd2` |
| dry_bush | `5ed55caeb75d0f9893607d1bedd5c04ec476350655e6313f7a5b3a3b4a040625` |
| net_drying_rack | `88c2b6102e7953d3755daf588868f0cc0ff43f77858b039ad8bf430ef8cb2e99` |
| fuel_tank | `7b1722d36f9a244b4880f82f713d3913290c37b929c71d38e1c94f821ba621cc` |
| log_scatter | `e5c21747283c6d07f9556ca91a58a8cf37836fb859d5b28b335e4fd5739a211a` |
| rail_marker | `3fecae6f0573873a88cee0d01d2655a8ffb9e6459baf0f72b11ae8b3c1d9aac8` |
| rock_ridge | `c42989c13e1823e3eb8683f5dfc12e2ee872a9fd4ef9369d85844503418f694e` |
| ice_sled_load | `117e2488e6f31c1c6e5c06ac704a237a7d2c788e05719658c25ffb7bbc162492` |
| buffer_stop | `619a700eb677d2b9524d465eee50290c9c4c42a96d9f0708eb3369dfb89054ed` |
| office_cabinet | `a8097fb57fa4b288e4a52a7039b20175c17ad678e3183ef4f543e8d38af2e3b7` |
| overturned_boat | `72e47eb9d6c69fccc9f2456eac4f5ece893a7f8bb297e1900ada6309feb4c4ed` |
| plate_stack | `82b73f5f3b0a01611be9adf62e1c56313a78707c95ed5cc90ad07cfafa8b4288` |
| fallen_log | `95dbffc865a75e11ea12d88bafd760421acfd9264c1101cbc7c020924943405d` |
| floor_shell | `db201ef9b609d80cf9374347ac9848b568a437e00c41372e2b28a20c9c711b8a` |
| stair_stub | `12b3d57e1cc3c981e35ddbf331b0e15172c07d33c10c85f1ba6b9ebe2004aaf1` |
| fish_trap_stack | `b6c262d4d3e9dc05c81cd7ed342cd9113224d3fc07c1efe15182007df96fc813` |
| flat_wagon | `67328c7280d7c28069e6a5d8852d532909baf63e81dd0d0c402cd586b8740994` |
| fallen_mast | `3edddf8a8ad002c06fd6b7771a612fa6a8ed148d981511b31fd3c886f93d43e5` |
| pier_deck | `270e4e19f72382e3a6d0d6623b8b3efe0f098a95ac5456036bf0e46a9804a912` |
| vent_pipe | `8d2fa2f477f222891d6a741745bc866a5dd2e9958198c1dff85e00cf50e88360` |
| fish_crate_stack | `bbb2b36ac72565d64e291ff542ced2d5a00ae3a5d342af434ecbd62f1ca54c63` |
| hay_cart | `597251e7c03dcbbbb955dc3a646411c0b065c66b19e583fa6b59174c913c5dbc` |
| medicine_crate | `2a133f7a962f5dbe0e4af5319d5f56b735d9be409bb410777335388a83ef6a51` |
| coal_bin | `12106aa333353abc578576a410815757ef5ebd9190ba7d834d6ed099cbc2ae67` |
| firewood_rick | `9e1167e6a7f7d1310795908b1c1015cde0a3feb3d8ea1ee6487a5e9a1a61919f` |

## 팔레트 (선형 RGBA)

- wood: (0.24, 0.17, 0.11, 1.0)
- worn_wood: (0.38, 0.29, 0.19, 1.0)
- iron: (0.12, 0.15, 0.17, 1.0)
- worn_metal: (0.28, 0.32, 0.33, 1.0)
- cloth: (0.43, 0.41, 0.31, 1.0)
- enamel: (0.68, 0.7, 0.66, 1.0)
- snow: (0.82, 0.88, 0.91, 1.0)
- bark: (0.2, 0.16, 0.13, 1.0)
- rust: (0.32, 0.16, 0.09, 1.0)
- glass: (0.19, 0.33, 0.38, 1.0)
- rubber: (0.035, 0.045, 0.05, 1.0)
- stone: (0.35, 0.37, 0.39, 1.0)

## 제외

- unload: 지도 spots의 하역 상호작용 지점이며 소품 rect가 없음. 물체나 하역 경사로를 새로 만들지 않음.
- skip_ground_like 7종은 입력 그대로 제외: fishing_hole, water, snow_drift, rock_face, snow_bank, snow_fence, snow_gauge_pole

최빈 rect가 입력에 있으면 그대로 사용한다. 누락된 10종은 지도 리터럴 Rect2i에서 보완한다. engine은 train_cars의 16×3m를 사용한다.
지도 추정은 리터럴 소품 수 × 이번 GLB 삼각형 수의 합이다. 기존 모델·다른 발주·train_cars·실행 중 동적 추가는 제외한다.
현 PropModels의 Weathered는 use_vertex_color 기본 false라 게임 배치 색 반영은 별도 연결 작업이 필요하다. 이 제작기는 로더를 수정하지 않는다.
