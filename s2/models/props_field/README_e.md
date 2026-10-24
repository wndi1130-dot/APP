# 지도 조립 소품 E

`tools/blender/props_field_e.py` 자동 장부. 입력 201~278위, 78종·199개.

rect 가운데 바닥, +Y 위·+Z 앞, facing은 +Y축 -90도씩. 발자국 96% 안쪽. 현재 map_view는 XZ 자동 맞춤을 하지 않는다.

재질·그림·빛·애니메이션 없는 단일 메시/단일 surface, 정점색 Col, 각 600삼각형 이하.
차량·선박은 +Z 앞과 평면 비율을 보존하므로 긴 가로 rect를 다 채우지 않을 수 있다.

| 이름 | 수 | 발자국 m | 높이 m | solid | 삼각형 | 바이트 | SHA-256 | 놓는 법 | 판단 |
|---|---:|---|---:|---|---:|---:|---|---|---|
| `garage_door_leaf` | 5 | 2×1 | 2.2 | {'wall': 5} | 120 | 9424 | `62e48d304ff42ff2001cfc198deef6131161131a18ff540c5019d1f19d7d78f9` | rect 중앙 바닥/facing | wall: 낡은 차고 문짝 하나, 잠금장치 없는 세로 판재 |
| `hive_box` | 5 | 1×1 | 0.9 | {'low': 5} | 60 | 5212 | `aaf45d0d7596650a63db87a6423cd279d2414d37117504ba49dc85af2048de78` | rect 중앙 바닥/facing | low: 층진 벌통과 작은 출입 틈, 눈 덮인 뚜껑 |
| `inspection_pit` | 5 | 14×2 | 0.12 | {'none': 5} | 60 | 5216 | `a56dedaad741b3a17bc65eae0c1fa2ac90d8787402aa534118d6cca967575510` | rect 중앙 바닥/facing | none: 파내지 않는 어두운 점검구와 낮은 평테두리 |
| `log_flatcar` | 5 | 12×3 | 1.9 | {'wagon': 5} | 460 | 29892 | `322c3f26d9312413c10cac08b6ddd4e6f8e1c972b10d1070c1c5fa521af6ae8c` | rect 중앙 바닥/facing | wagon 예외: 사람 칸 없는 원목 화물 평판차, 적재 통나무 |
| `millstone` | 5 | 2×2 | 0.65 | {'low': 5} | 168 | 12772 | `4b96ee225b68494dc05be0d4ee01fb58131d4af40004386dab185fb45a0d67da` | rect 중앙 바닥/facing | low: 가운데 구멍과 방사 홈이 있는 맷돌 |
| `mooring_post` | 5 | 1×1 | 0.9 | {'low': 5} | 84 | 6132 | `71996b9dfd5557277b96752d1c5fcc2af6380ad8718dbb4ea53fec21a5144d0c` | rect 중앙 바닥/facing | low: 둥근 계선 기둥과 가로 머리, 사슬 없음 |
| `rail_plow` | 5 | 12×3 | 1.8 | {'wall': 5} | 344 | 23624 | `bdaa3995a9d807eeb5d469b9f197686c67a26ac5b8b2a11a404cae0721a22c27` | rect 중앙 바닥/facing | wall: 앞 +Z 쐐기 제설날과 유리 계기창이 있는 기관실 |
| `siding_buffer` | 5 | 2×3 | 1.0 | {'low': 5} | 96 | 7720 | `29c501065245357b5cbcb42701a0b589f352b27ccaf28290309d810c615453ae` | rect 중앙 바닥/facing | low: 선로 끝 완충대와 양쪽 고무 받침 |
| `wheelset` | 5 | 2×1 | 0.9 | {'low': 5} | 148 | 9964 | `536012485c1bad8357bb60ce703edb3af5918b052d7e623cab926bddab90bbfc` | rect 중앙 바닥/facing | low: 축 하나로 연결된 철도 바퀴 두 개 |
| `wind_pole` | 5 | 1×1 | 3.2 | {'none': 5} | 84 | 6124 | `331f1a7a3e65926355d7a34ed808d6541d3f7f51fe4b89bc17bcbca51f28f499` | rect 중앙 바닥/facing | none 높이 예외: 기상 바람기둥과 축 늘어진 빈 풍향포 |
| `ballast_pile` | 4 | 3×2 | 0.8 | {'low': 4} | 324 | 29072 | `003927c09e5b7aaeea107a7bb649abb329f20038c973c14097983a88694dee6a` | rect 중앙 바닥/facing | low: 눈 사이로 드러난 각진 선로 자갈 |
| `dock_plate` | 4 | 4×3 | 0.12 | {'none': 4} | 144 | 11092 | `f2f618802a7e737d98d6d69a41d8d89ed00bf82ad6c49485e16a4a9f13e127ff` | rect 중앙 바닥/facing | none: 경사 없는 평철판, 하역 경사로 아님 |
| `dry_grass` | 4 | 2×2 | 0.4 | {'none': 4} | 216 | 16328 | `a9dc14f7465d7378b07abf2b38f9b74c501b3913a5c6136fad27b66ce11c6edf` | rect 중앙 바닥/facing | none: 낮은 마른 풀 포기와 눈 사이 빈 공간 |
| `evidence_shelf` | 4 | 3×1 | 1.2 | {'low': 2, 'none': 2} | 120 | 9420 | `98aee2611dad73ddaf0117a4dc617a9b60f73ebeaa4231009bad811c989375a8` | rect 중앙 바닥/facing | low/none 혼합: 종이 기록만 놓인 낮은 증거 선반, 소지품 더미 없음 |
| `fuel_pump` | 4 | 1×2 | 1.3 | {'low': 4} | 144 | 10580 | `0c16a4482828f40242c93b17eb088563670a70caf6868e53d581762dfc781e45` | rect 중앙 바닥/facing | low: 계기 창·주유 손잡이·느슨한 호스가 있는 주유기 |
| `hose_rack` | 4 | 4×1 | 1.15 | {'low': 2, 'none': 2} | 232 | 17256 | `f7eb5f61fe470b36247cfd2e94bcca9ff864d620882931c2bca0ebee43b2423f` | rect 중앙 바닥/facing | low/none 혼합: 선반에 감긴 고무 호스 두 타래 |
| `long_table` | 4 | 4×2 | 0.8 | {'low': 4} | 120 | 9412 | `779b2bab5203a03bb28de8af68146ddc239c1042ac0352ebe7d89736309217fe` | rect 중앙 바닥/facing | low: 긴 널판 식탁과 네 다리 |
| `plank_patch` | 4 | 3×1 | 1.9 | {'wall': 3, 'none': 1} | 120 | 9412 | `89d0528c3aeccda449506f49ebfad5c44782c268c1de1f35de2acf738a72ee41` | rect 중앙 바닥/facing | wall/none 혼합: 안쪽 수선용 널판 묶음, 창 봉쇄·빗장 아님 |
| `skybridge_rail` | 4 | 6×1 | 1.1 | {'none': 4} | 96 | 7740 | `124ba9081794ed36fdf42f8b67c0e4404842e6cacb573ff267a3f16ee197fa4d` | rect 중앙 바닥/facing | none 높이 예외: 연결다리 가장자리의 열린 난간 |
| `slate_board` | 4 | 2×1 | 1.25 | {'low': 4} | 72 | 6044 | `a8e76453d58016d2d9b7a147225499968a9a04bf9732ada61679470e16f92844` | rect 중앙 바닥/facing | low: 무문자 석판과 작은 나무 받침틀 |
| `turntable_rim` | 4 | 6×1 | 0.3 | {'low': 4} | 192 | 14592 | `8ab87a87fde5f002abd38428223421a5f4f6fd13888a8e9af6566ab1f63451d4` | rect 중앙 바닥/facing | low: 회차대 가장자리의 짧은 곡선 레일 |
| `windbreak_fence` | 4 | 8×1 | 1.2 | {'low': 4} | 240 | 17828 | `059334b28554955f160452b9d998ece767269bfdfd5cbbddead7b9bc464af444` | rect 중앙 바닥/facing | low: 틈 있는 낮은 나무 바람막이, 철조망 없음 |
| `bin_bay` | 3 | 4×2 | 1.1 | {'low': 3} | 108 | 8564 | `2dfc8e330048c36518a3a9b002b7cc03b3e481593126634def70ce6fdef92a40` | rect 중앙 바닥/facing | low: 분리된 폐자재 통 세 개, 소지품 적재 없음 |
| `bunk_bed` | 3 | 2×1 | 1.75 | {'none': 3} | 156 | 11916 | `8595a037566cf00b10504ddf5b3c37f65cd85d2a6842c556d1b3a299a0ec72e7` | rect 중앙 바닥/facing | none 높이 예외: 두 층 침상과 얇은 침구, 옷 더미 없음 |
| `chiller_case` | 3 | 4×1 | 1.15 | {'low': 3} | 48 | 4372 | `04bfcb68e698d062e40dd8d234c190e53748e8a12b6c5aa33133a8a308b28c3c` | rect 중앙 바닥/facing | low: 유리 앞판과 비어 있는 냉장 진열함 |
| `coal_hopper` | 3 | 3×3 | 2.7 | {'wall': 3} | 88 | 7296 | `a7806c5304350c403f25c98fcf98d8bb301fff4138b30a80fe791bc359513ac7` | rect 중앙 바닥/facing | wall: 아래가 좁은 석탄 호퍼와 네 받침 |
| `dock_door` | 3 | 4×1 | 0.15 | {'none': 3} | 144 | 11096 | `fcbbd43a6ada476d13d7d5d3246e81daf16b33edb8855810d49afe0c984e2a7a` | rect 중앙 바닥/facing | none: 원문 평평한 하역 문에 맞춘 누운 문판, 경사로 없음 |
| `fallen_pole` | 3 | 5×1 | 0.5 | {'low': 3} | 100 | 7360 | `6c7cf0adbdb2785217913c6465b673e9cba9abcc706c72b59d6bf1416b4afcbe` | rect 중앙 바닥/facing | low: 쓰러진 전신주와 절연체, 발자국 안 가로대 |
| `garden_bed` | 3 | 4×2 | 0.35 | {'low': 3} | 72 | 6052 | `47e347aae1ecaeac448ffb2fc7a6176a59641f9d5eabdf2548235bd3c87c72cc` | rect 중앙 바닥/facing | low: 낮은 테두리와 눈 덮인 빈 텃밭 |
| `hand_pump_cart` | 3 | 2×1 | 1.2 | {'low': 3} | 312 | 20692 | `0dc490ed085f026743893104f631b071485498db63ca2c572dd0ef62924db331` | rect 중앙 바닥/facing | low: 바퀴 달린 수동 펌프와 손잡이 |
| `hedge` | 3 | 6×1 | 1.1 | {'low': 3} | 476 | 37468 | `28db55e5aed3267b776e38912c925e4c5b5d53b06b69656705375af17bef844a` | rect 중앙 바닥/facing | low: 잎 적은 겨울 생울타리와 작은 눈 덩어리 |
| `laundry_line` | 3 | 6×1 | 1.8 | {'none': 3} | 76 | 6080 | `9a19c5a9f7bb7228e4ab6a2dce801f7638d5261982162b946a6873e56d006373` | rect 중앙 바닥/facing | none 높이 예외: 빈 빨랫줄과 두 기둥, 옷·가방 더미 없음 |
| `rail_handcar` | 3 | 3×2 | 1.2 | {'low': 3} | 284 | 18852 | `b359a193fcddebd4362e22a4a75efdd4d394cbca3c94190dbb3416927e421c33` | rect 중앙 바닥/facing | low: 철도 수동 대차의 펌프 지레와 네 바퀴 |
| `rubble_heap` | 3 | 2×5 | 0.8 | {'low': 3} | 324 | 29072 | `3257e10721ee15d38b15aa56994f9646fdcd67720bbd5694c60e0661ca707d4a` | rect 중앙 바닥/facing | low: 깨진 돌·벽돌만 쌓인 낮은 잔해 |
| `well_cover` | 3 | 2×2 | 0.5 | {'low': 3} | 168 | 12760 | `d329b435a30fbd46ff5fccc9f9ea1fa5dee96b16af271ec517b4a8719de60cfd` | rect 중앙 바닥/facing | low: 낮은 우물 돌테와 닫힌 나무 덮개 |
| `armory_rack` | 2 | 3×1 | 1.2 | {'none': 2} | 108 | 8576 | `f3aeddff58eb54980573025b347757a5857d7667698249c6b5bd1a989ebca195` | rect 중앙 바닥/facing | none 높이 예외: 빈 무기 거치 홈과 열린 받침틀 |
| `brake_shoe_pile` | 2 | 2×1 | 0.5 | {'low': 2} | 144 | 11092 | `89b3c0340433f0f19a39cd19f1566e5c7ee33dcaf5f5552190957c3041612260` | rect 중앙 바닥/facing | low: 곡면 제동 블록 여섯 개, 소지품 없음 |
| `curing_barrel` | 2 | 1×1 | 0.85 | {'low': 1, 'none': 1} | 272 | 19300 | `1ec54077e583a0a8b53fd31bbe097a4977fd86e081cac2019d34047c3c7b959c` | rect 중앙 바닥/facing | low/none 혼합: 뚜껑과 쇠테를 두른 저장 통 하나 |
| `frozen_barge` | 2 | 8×3 | 1.1 | {'low': 2} | 80 | 7380 | `a5fa593672b75e45112b6c428990bb71b26e2095f562539152ecbb4e7536066a` | rect 중앙 바닥/facing | low: 얼어붙은 빈 평저 바지선, 승선 자리 없음 |
| `grain_silo` | 2 | 5×5 | 6.2 | {'wall': 2} | 304 | 21400 | `e6ddc932a325c61caf723bc6ec184d8c7084f3985df0e12f020eaf314a40a3d0` | rect 중앙 바닥/facing | wall: 원통 곡물 사일로와 원뿔 지붕 |
| `herb_bed` | 2 | 4×2 | 0.35 | {'none': 2} | 288 | 21684 | `26d93673d3f34c389e5be11b644d5acc2e98024e7d9e6aa7054a5a3b45b5fd1f` | rect 중앙 바닥/facing | none: 낮은 약초밭의 마른 줄기와 목재 테 |
| `herb_rack` | 2 | 3×1 | 1.2 | {'low': 2} | 120 | 9412 | `52057cf83c747de5ab674ad922a4747024a0cdaf71fcea0348307b88b6c120ef` | rect 중앙 바닥/facing | low: 약초를 말리는 나무 채반 세 단 |
| `lock_wheel` | 2 | 1×1 | 1.2 | {'low': 2} | 176 | 13212 | `809218bea95db8a63683adf307411b7c3395c2f28b45bd278edf6407cf60fcf3` | rect 중앙 바닥/facing | low: 수문 조작 바퀴와 수직 축, 문 잠금 아님 |
| `log_pile` | 2 | 4×2 | 1.1 | {'low': 2} | 292 | 18892 | `3fe7dc132962e4fefd7d16cfa035bd707ebf88dc8e8b4cf9b46be47db18a008e` | rect 중앙 바닥/facing | low: 마른 원목 다섯 개와 눈 덮인 위쪽 |
| `patrol_car` | 2 | 5×2 | 0.8 | {'low': 2} | 348 | 23840 | `43a8880f6c62ac679e7afbc3edffb046ef503b545268c54912cb8cfe033950ee` | rect 중앙 바닥/facing | low: 눈 쌓인 순찰 승용차, 무표식·등화 효과 없음, 앞 +Z |
| `plank_fence` | 2 | 6×1 | 1.2 | {'low': 2} | 240 | 17820 | `e95cd2675ca77d3533a04023a96186889c5872c3c6f68977b1596eb13c2a9fb1` | rect 중앙 바닥/facing | low: 낮은 널판 울타리, 철조망·출입 잠금 없음 |
| `platform_cart` | 2 | 2×1 | 0.5 | {'low': 2} | 264 | 17696 | `490ccb2a3060bcebabcb94c19a6afd43dbbdd2d318731b5ebfe3bc66590b55e1` | rect 중앙 바닥/facing | low: 낮은 평판 운반 수레와 네 바퀴 |
| `repair_scaffold` | 2 | 4×2 | 1.25 | {'low': 2} | 144 | 11088 | `bfe579f343f81456f9ac19e06d718f0f8625c2b1da81787b1d306bf0201737be` | rect 중앙 바닥/facing | low: 수선용 낮은 발판과 사선 지지대 |
| `roof_beam_pile` | 2 | 2×3 | 0.8 | {'low': 2} | 72 | 6056 | `6a2aac3a47fa60e898535b54552f7fd5b96baf82dff752ba3d425f26449b820a` | rect 중앙 바닥/facing | low: 지붕 보 세 층, 양 끝이 보이는 목재 |
| `roof_tile_heap` | 2 | 2×5 | 0.7 | {'low': 2} | 156 | 11940 | `c3b0c2454a794b7171af77e3ec5df02fd1cf63d0a96deb11d07e2087f58a7c55` | rect 중앙 바닥/facing | low: 겹친 회색 지붕 기와 조각, 눈 얹힘 |
| `sluice_frame` | 2 | 6×2 | 2.8 | {'wall': 2} | 212 | 15728 | `6f576f96932a708703834634b310ea327e9a14509a61eb5e2712932fa1923fe0` | rect 중앙 바닥/facing | wall: 수문 물길의 문틀·판·조작축, 사람 칸 없음 |
| `strongbox` | 2 | 1×1 | 0.5 | {'none': 2} | 88 | 7160 | `8dad28934f6bd5e6c5f59f7b777a73c122b81036dbe19b07d7e324b2f31e2fa2` | rect 중앙 바닥/facing | none: 바닥 가까운 소형 금고와 작은 원형 손잡이 |
| `transformer_unit` | 2 | 2×2 | 2.3 | {'wall': 2} | 372 | 25532 | `1b40eef07c399906a00d64782d4c6c730927b822cac48f0699ca1f4f628be16e` | rect 중앙 바닥/facing | wall: 방열핀·절연체가 있는 낡은 변압기 |
| `water_gauge` | 2 | 1×1 | 1.2 | {'low': 2} | 108 | 8580 | `955afe99bdff4778565aac36093614481338b37a75ceb726931985bfbbd9f8a4` | rect 중앙 바닥/facing | low: 수위 눈금판, 대기 번호·구획 없음 |
| `anchor` | 1 | 2×1 | 0.35 | {'low': 1} | 184 | 13312 | `ecfc301ea1120a7f401dd8dd4371b0fa0468243befe4e3796b9d98667edec4c4` | rect 중앙 바닥/facing | low: 바닥에 누운 닻과 굽은 양 갈래, 사슬 없음 |
| `bridge_rail` | 1 | 6×1 | 1.15 | {'low': 1} | 96 | 7732 | `bc311a4f9c30a86637fa9a6052fc189eafcb6e4c9e70050fcef7524dc9abcc71` | rect 중앙 바닥/facing | low: 다리의 열린 나무 난간 |
| `bridge_truss` | 1 | 8×2 | 2.8 | {'wall': 1} | 240 | 17820 | `496f908da5e3ff8f8fd8d162fad8b248375bc662842757f101849c7515ccdfb0` | rect 중앙 바닥/facing | wall: 삼각 버팀이 이어진 교량 철골 |
| `dock_platform` | 1 | 12×4 | 0.35 | {'none': 1} | 180 | 13620 | `481c2f615db2adea1b13f40fa1be5056c4dc63050e53523f47f4670114e8e714` | rect 중앙 바닥/facing | none: 평평한 부두 널판과 낮은 받침, 경사로 없음 |
| `fallen_bell` | 1 | 3×3 | 1.1 | {'low': 1} | 348 | 24864 | `56def57b6c67ed0b69491224eebea7f30ca0f24a7d7f62c814d608fba704409d` | rect 중앙 바닥/facing | low: 옆으로 기운 빈 종과 두꺼운 입 테두리 |
| `fire_engine` | 1 | 7×3 | 1.8 | {'wall': 1} | 480 | 33084 | `948084cc6082df872fee57afd97b40664c6b73079011c3a0c0caec45bbe6857b` | rect 중앙 바닥/facing | wall: 사다리·장비함이 있는 소방차, 빨간 십자·등화 효과 없음 |
| `fishing_boat` | 1 | 9×3 | 2.1 | {'wall': 1} | 148 | 12016 | `12bc773cbb1e197cf36918e9b433d37ffab514a89bf5e7ca646e747e242186f1` | rect 중앙 바닥/facing | wall: 작은 조타실과 열린 갑판 어선, 승선 자리 없음 |
| `flagpole` | 1 | 1×1 | 4.0 | {'none': 1} | 68 | 5244 | `8eceb8592adec9cae380bd6e575542f7b1393dc305928c287b5ffa1be8144fc7` | rect 중앙 바닥/facing | none 높이 예외: 표식 없는 깃대와 작은 빈 깃발 |
| `frozen_fountain` | 1 | 4×4 | 1.1 | {'low': 1} | 284 | 19752 | `d43359d9e6e0d87b2769d272f9b531f9ab9d3a98c829fce2235dc50a9f2143ac` | rect 중앙 바닥/facing | low: 얼음 찬 분수 받침과 작은 중앙 수반 |
| `pallet_truck` | 1 | 2×1 | 1.1 | {'low': 1} | 312 | 21196 | `9f31ee934e4800128538fbd46883e09549fa025148457f1615bbea910b6df528` | rect 중앙 바닥/facing | low: 포크 두 갈래·작은 바퀴·수동 운반 손잡이 |
| `pit_rail_pair` | 1 | 8×2 | 0.16 | {'none': 1} | 108 | 8580 | `26f1c03be1c56c2c5d5f3f5e7325a9538d74df4c15c992f747d425b6c971f564` | rect 중앙 바닥/facing | none: 점검구 위의 두 평행 레일과 침목 |
| `playground_frame` | 1 | 4×3 | 1.25 | {'low': 1} | 132 | 10248 | `04b3f61d4c3406137fb1cc61f5866b6a836a8fd4e762fa09e40c9a0ed8c1a165` | rect 중앙 바닥/facing | low: 낮은 놀이 오르기 틀, 매달린 사슬 없음 |
| `quay_crane` | 1 | 5×5 | 5.0 | {'wall': 1} | 136 | 10580 | `6d254eff54cf1aef11a2d17bd7ed8bf06f6beccaaad2db61db63a19da568fd2d` | rect 중앙 바닥/facing | wall: 부두 기중기와 기울어진 붐, 갈고리만 표현 |
| `reed_clump` | 1 | 3×3 | 0.5 | {'none': 1} | 360 | 25624 | `fd53b154ce8df60385c54d512ec3e866d0581dace5627f6a0df12378a4886a89` | rect 중앙 바닥/facing | none: 낮은 겨울 갈대와 마른 이삭 |
| `shop_awning` | 1 | 3×1 | 2.2 | {'none': 1} | 76 | 6332 | `68b8d34f62200c2b2f2bcb4d9ff143b3372379efb9a6a32d29bb97fb87038eac` | rect 중앙 바닥/facing | none 높이 예외: 가게 차양 천과 열린 두 기둥 |
| `signal_bridge` | 1 | 10×1 | 4.2 | {'none': 1} | 252 | 17892 | `11e6a802c33e835b7598c368dccb20ac72cd22bceebfaa2106c8827038da5af0` | rect 중앙 바닥/facing | none 높이 예외: 선로 신호교와 꺼진 신호판, 빛 없음 |
| `stalled_tram` | 1 | 12×3 | 2.8 | {'wall': 1} | 428 | 29316 | `90a6586d6476b225253790075fdb4b0615133ffefe8e22e8b02eb8457165455e` | rect 중앙 바닥/facing | wall: 창과 옆 출입구가 열린 멈춘 전차, 앞 +Z |
| `switch_cluster` | 1 | 3×2 | 1.1 | {'low': 1} | 152 | 11660 | `4c67d05fa848fa221d79f9bc6874e4a5ca056586ae848584aab5d4fd056e5b08` | rect 중앙 바닥/facing | low: 분기 레일·연결봉·낮은 전환기 |
| `switch_lever` | 1 | 1×1 | 1.0 | {'low': 1} | 72 | 5660 | `d17cf9ce18012d8d3fb2d6dfc8df188eb41c6b55c2944d87110bd7082dd4ce07` | rect 중앙 바닥/facing | low: 받침과 기울어진 선로 전환 지레 |
| `tow_truck` | 1 | 7×3 | 1.8 | {'wall': 1} | 388 | 26572 | `79e6db9c79c6f4d442ea85d91579f9961f71c4d43ff514eaac4deea6de8ab13c` | rect 중앙 바닥/facing | wall: 견인 붐과 빈 갈고리 있는 트럭, 사슬 없음 |
| `training_frame` | 1 | 3×3 | 1.2 | {'low': 1} | 132 | 10256 | `2fa001129abaacc24e4af6fab6cd015e8854158afceebde6acbc6c4322809bd8` | rect 중앙 바닥/facing | low: 원문의 낮은 나무 훈련 틀, 줄 세우는 자리 없음 |
| `turntable_deck` | 1 | 20×3 | 0.35 | {'none': 1} | 120 | 9416 | `40d785a07dbb42915d6395ffa7174cc831330646bcae8b26dec89c9307c4a55b` | rect 중앙 바닥/facing | none: 회차대 평판과 평행 레일, 낮은 중앙 회전 받침 |
| `water_crane` | 1 | 2×2 | 3.2 | {'wall': 1} | 148 | 10604 | `ebe7e6f966733355cf61297c66a843f307f9a09d73f257f3fcfad91deaa87643` | rect 중앙 바닥/facing | wall: 증기기관차 급수관과 굽은 주둥이, 연기 없음 |
| `water_tower` | 1 | 5×5 | 6.0 | {'wall': 1} | 376 | 26300 | `74ec6d35f9f37f94056e6fee8a9bc3be8f9733e7b01bd7cbd42a5f997c611279` | rect 중앙 바닥/facing | wall: 네 다리 위의 원통 물탱크, 연기·망루 없음 |

## 팔레트 (선형 RGBA)

- `wood`: (0.24, 0.17, 0.11, 1.0)
- `worn_wood`: (0.38, 0.29, 0.19, 1.0)
- `iron`: (0.12, 0.15, 0.17, 1.0)
- `worn_metal`: (0.28, 0.32, 0.33, 1.0)
- `cloth`: (0.43, 0.41, 0.31, 1.0)
- `enamel`: (0.68, 0.7, 0.66, 1.0)
- `snow`: (0.82, 0.87, 0.89, 1.0)
- `bark`: (0.18, 0.14, 0.11, 1.0)
- `rust`: (0.32, 0.18, 0.11, 1.0)
- `glass`: (0.22, 0.35, 0.39, 1.0)
- `rubber`: (0.055, 0.065, 0.07, 1.0)
- `stone`: (0.37, 0.39, 0.38, 1.0)

제외 없음. 자세한 명령·검사 출력·배치 위험은 루트 `_result_props_e.md`.
