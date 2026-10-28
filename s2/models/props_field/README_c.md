# 필드 소품 C

독립 생성 장부. tools/blender/props_field_c.py로 재생성한다.

rect 가운데 바닥. +Y 위, +Z 전면. facing 0~3은 기존 map_view의 -Y 회전 0/90/180/270도를 따른다. 손잡이를 포함한 원형 AABB가 최빈 발자국 안이다. 현 map_view는 회전만 하며 rect별 축척 보정은 하지 않는다.

메시·면 묶음 각 하나, 삼각형 ≤600, 정점색 Col. 재질·그림·빛·애니메이션 없음.

| 이름 | 수 | 발자국 m | 높이 m | solid | 삼각형 | 바이트 | 판단 한 줄 |
|---|---:|---|---:|---|---:|---:|---|
| circular_saw_bench | 15 | 3×2 | 1.2 | low:15 | 252 | 17904 | 제재용 원형톱·톱니·가이드·작업대를 1.20m low로 구성 |
| fish_drying_frame | 15 | 4×2 | 1.25 | low:15 | 354 | 30216 | 생선 여섯 마리를 낮은 A형 건조 틀에 걸어 low 높이 유지 |
| sled_load | 15 | 2×1 | 1.1 | low:15 | 228 | 16976 | 눈 덮인 자재 상자만 실은 썰매; 소지품 더미 없음 |
| track_switch | 15 | 2×1 | 0.35 | none:15 | 136 | 10476 | 침목·분기 레일·낮은 전환 레버로 none 바닥 높이 유지 |
| cask_stack | 14 | 2×2 | 0.48 | none:8, low:6 | 348 | 23076 | none 우세에 맞춰 작은 저장 통 셋을 한 층으로 낮게 배치 |
| generator | 14 | 2×1 | 1.1 | low:14 | 176 | 12824 | 개방 프레임의 발전기·연료통·계기, 배기 연기 없음 |
| relief_crate | 14 | 2×1 | 0.48 | none:8, low:6 | 120 | 9420 | none 우세의 낮은 보급 상자; 빈 명판만 두고 표지 없음 |
| slag_heap | 14 | 3×3 | 0.95 | low:14 | 146 | 13660 | 광산 찌꺼기 돌덩이 다섯 무리와 부분 적설, low |
| checkout | 13 | 2×1 | 1.1 | low:11, none:2 | 72 | 6048 | 계산대 위 기계식 금전등록기와 계산 받침, low |
| community_banner | 13 | 1×2 | 0.18 | none:13 | 112 | 8612 | none에 맞춰 내려놓은 무문자 천 현수막과 양 끝 봉 |
| conveyor | 13 | 6×1 | 1.0 | low:13 | 248 | 17844 | 낮은 광산 벨트 운반기·롤러·가로 돌기, low |
| ice_block_stack | 13 | 3×2 | 1.1 | low:13 | 120 | 9420 | 얼음 다섯 블록에 눈 모서리; 불투명 정점색만 사용 |
| mail_sorting_rack | 13 | 3×1 | 1.2 | low:8, none:5 | 312 | 22872 | 우편 분류 15칸과 종이; low 우세 기준의 낮은 선반 |
| plank_bridge | 13 | 2×3 | 0.24 | none:13 | 144 | 11096 | 보 두 줄 위 널판 아홉 장의 평평한 작은 다리, none |
| rail_pile | 13 | 3×1 | 0.6 | low:13 | 240 | 17816 | 폐레일 여섯 개를 두 층으로 쌓아 low 유지 |
| stump_cluster | 13 | 4×4 | 0.48 | none:13 | 334 | 35116 | 뿌리째 낮게 잘린 그루터기 넷(Poly Haven tree_stump_01·02, CC0) |
| wrecked_car_cluster | 13 | 4×4 | 1.2 | low:13 | 256 | 17932 | 찌그러진 폐차 두 대의 껍데기·바퀴·눈; 소지품 없음 |
| band_saw | 12 | 4×2 | 1.3 | low:12 | 188 | 13148 | 두 바퀴·수직 띠톱·작업판을 갖춘 소형 제재기, low 상한 |
| box_truck | 12 | 6×2 | 2.4 | low:9, wall:3 | 372 | 25520 | 상자형 적재함의 의미와 wall 혼용을 우선해 low 높이 예외; +Z 전면과 짧은 깊이를 지키는 압축 비례 |
| drain_ditch | 12 | 4×1 | 0.2 | none:12 | 96 | 7736 | 낮은 돌 가장자리와 바닥의 배수로 단면, none |
| flour_sack_pile | 12 | 2×2 | 1.0 | low:11, none:1 | 272 | 22608 | 밀가루 저장 자루 네 개와 빈 품목표; 개인 소지품 아님 |
| lumber_rack | 12 | 6×2 | 1.25 | low:8, none:4 | 264 | 19484 | 세 단 자재 받침에 긴 판재 아홉 장, low 우세 |
| market_stall | 12 | 3×2 | 1.25 | low:12 | 188 | 14036 | 낮은 판매대·빈 상품함·접힌 차양으로 low 유지 |
| nave_pillar | 12 | 2×2 | 3.2 | wall:12 | 76 | 6076 | 교회 신랑의 각진 주초·기둥·주두로 wall 의미 유지 |
| post_box_row | 12 | 2×1 | 1.25 | low:9, none:3 | 180 | 13608 | 투입구와 작은 문이 있는 우편함 세 개, low 우세 |
| printing_press | 12 | 3×2 | 1.15 | none:8, low:4 | 228 | 15828 | 인쇄 롤러·손바퀴·급지판의 의미 우선, none 높이 예외 |
| water_barrel | 12 | 2×2 | 1.15 | low:12 | 244 | 15924 | 쇠 테와 수도꼭지·수면이 있는 낮은 물통, low |
| weigh_platform | 12 | 3×2 | 1.2 | low:10, none:2 | 144 | 11100 | 낮은 계량판과 옆 계기 지주를 함께 포함, low 우세 |
| boat_on_blocks | 11 | 5×2 | 1.2 | low:11 | 100 | 8980 | 받침목 위 열린 작은 목선; 선실·문·사람 없음; +Z 전면과 짧은 깊이를 지키는 압축 비례 |
| forklift | 11 | 3×2 | 2.0 | low:9, wall:2 | 360 | 24660 | 포크·마스트·운전석 보호틀의 의미와 wall 혼용 우선, low 예외 |
| jib_crane | 11 | 2×2 | 2.8 | wall:11 | 124 | 9240 | 수직 기둥·돌출 붐·가는 인양선과 갈고리의 wall 크레인 |
| log_truck | 11 | 9×3 | 2.4 | low:11 | 554 | 36344 | 통나무 적재대·운전석의 의미 우선, low 높이 예외; +Z 전면과 짧은 깊이를 지키는 압축 비례 |
| ore_cart | 11 | 2×1 | 1.2 | low:11 | 300 | 21056 | 광석을 실은 경사 측벽 광차와 철제 바퀴, low |
| pit_props | 11 | 3×1 | 0.85 | low:11 | 156 | 10972 | 갱도용 받침 통나무를 눕혀 보관한 자재 묶음, low |
| coal_sorter | 10 | 4×3 | 2.1 | wall:10 | 208 | 15320 | 체살·드럼·받침 다리로 된 석탄 선별기, wall |
| farm_tractor | 10 | 4×2 | 1.3 | low:10 | 372 | 24372 | 큰 뒷바퀴와 작은 앞바퀴의 무선실 소형 트랙터, low; +Z 전면과 짧은 깊이를 지키는 압축 비례 |
| generator_unit | 10 | 2×2 | 1.15 | low:10 | 172 | 12808 | 통풍구 달린 덮개식 발전기; 개방 프레임 generator와 구분 |
| hopper | 10 | 3×3 | 2.3 | wall:10 | 116 | 9120 | 좁은 배출구와 넓은 상부 투입함의 광석 호퍼, wall |
| mine_portal | 10 | 3×2 | 2.6 | none:10 | 96 | 7732 | 열린 갱구의 기둥·상인방 의미를 우선, none 높이 예외 |
| rail_stack | 10 | 4×1 | 0.75 | low:10 | 348 | 25364 | 레일 아홉 개를 세 층으로 정돈한 야적, low |
| 합계 | 491 | 40종 | — | — | 8756 | 652344 | 고유 자산 합계 |

## SHA-256

| 이름 | sha256 |
|---|---|
| circular_saw_bench | 245fa801abffff97c49ce6678d9e527a57a25b360f112ad61679aaae52b9287a |
| fish_drying_frame | a13ebc5161e704fa0446f316fc48483aa310db26bb0ce07825e7c73d4e00d7df |
| sled_load | d8233fd846842f43a2fe65321095ca8518cc0fe7e0aecc19d650b05183a91515 |
| track_switch | 32258da040c7085de4f55ad6626ed28503ff31c2480f0eddafb161f81a3d1e4b |
| cask_stack | f633d1c0cc17faf26899bb0f8fb3c0456b3456c078796a1e45937348a07490b6 |
| generator | c3191b3d67cecffabf279b84482c0101d8c353318ca3ccc037488787ff158c30 |
| relief_crate | 0f8adbe939765257eafdf3406d56a0d6ddbf3be3c63fbed44d81373ed049c493 |
| slag_heap | 8596e2599410717e6019524a609cc651da405ea160d5054e90a4eca9727b17e2 |
| checkout | c9cba5fa076e88ab36496030548fb9c422de51d735ff3fabff9d67305efe4ad9 |
| community_banner | b89bb0a4a95b69fe7a3c30e72623892d9d964d89f85678bd803d235b69a3a269 |
| conveyor | 0ef2cb3fe75e3cb788bd1357ba78f29520417d9c56e2705738fc82930fe9c839 |
| ice_block_stack | a876ec3feb59653ec2440f8fbf110341e613861d85f251b3efc6b2e73a1f4fd8 |
| mail_sorting_rack | d19bfc28f04ea2c6702d3e7edc7f355b54ea4de5a22942db53e3c7f808f69774 |
| plank_bridge | 2eb97ea57e403d6bcedf5a63007d29753db7378a1dff89146abe75e7a27bcd41 |
| rail_pile | 4ff25912d0f924a6ae3a43002a22dbc95657fc56a7665b8f4f1dc3bb6826e282 |
| stump_cluster | 3fff2152f114296f581ff9173c091862fe9613a52bcd589b88ce9e16d4b4b700 |
| wrecked_car_cluster | a7cdd3410aaf171cd6e9650b511af4b14815d7780ec4b1a3312d1ecf01af194d |
| band_saw | 31c9d2650a75a7bd137ef1b7e3840c670c68215e4000816b5cb3c021ae4c9e35 |
| box_truck | 1874c58b532d9057e13475a285f86df233cf115a9c0065c0b625d3d276623489 |
| drain_ditch | 8b9a3cfeb95db04d9cd14f60cc208dd5ab6d43213ea2e5b5f8e249ca12c561e8 |
| flour_sack_pile | ad40a4f89361fb744dbc45f6af0ff7780f6a90457874280f383be1fa3769df88 |
| lumber_rack | 842f062735b2f59708e0e83d120450df054fcbfbaec32c903ce695c1012d136d |
| market_stall | 8010e17452947fca0bd63460288e296c05ff1b8f50d0557cb2e9b140959e9fe6 |
| nave_pillar | bab29737c13226b2137b352a7a88486914d62c0e79953f93b61a86ce6808bfda |
| post_box_row | e2817f3fc398b6e0ad369d4ab706b558d0bdd434fa776a9c91636199dad23305 |
| printing_press | 2305fab0400c97273f832317f4d92ac0793cbd17a75c791332148fce5ecf1836 |
| water_barrel | 28155ab80e9a4750d228e8be974cac5be9f2d8c36851504abccc33c5afd27c73 |
| weigh_platform | cc0c55c867ddc7cc66217ed9db4d5f3f8b704c1c4324b83e9892e9907a3f16ca |
| boat_on_blocks | fc1ca848e7932e1c8a3f4d42fc61d4f7d30ee4dd1070557f4d433470a85c0646 |
| forklift | e4d326776a8311c411001671ccb55ad58ec7295f0b286712c6a2f8fbff0f3dad |
| jib_crane | 0bb3836d50c3ed1fec3688284009d6f1456e75407cc07a9515de5ac9fecea30c |
| log_truck | 8342e4ac2bd4f77ad184b789aefe43d40a74f4193ea8a2a9a008c7b8e1b642ac |
| ore_cart | c3fa3dfb26daa7e6beee4f8a0b5776601ed0e81060a8848dff1ee83498be2fac |
| pit_props | 365453c63085b217869451f4d58a145b5ecccc51878324aad02d5c5a4da09d6f |
| coal_sorter | 441fe10e5915235dc4f90636e4ff20769a7007fb83225dbdf488b065e46a1d04 |
| farm_tractor | aa2b5f79f60866ecb073b7ea36bc43e2df11822f381ea0bf863d06ea752c419e |
| generator_unit | 19ca1c8d83cd057ad1cd431f251224e34daf684c543412613ec26d538a8fc27a |
| hopper | 183b4a4ee7daa79fbdec3ac076fdda386d62ad8ace81fdae1de695ca3f6e4af4 |
| mine_portal | bb19aade115b172d135a4f7e34bd89fb459c88eefa06fbebeb1cf1066a20b138 |
| rail_stack | c9e8babed46fc9df5367162b1d9058c892a55b47db5953d9f12c191de84f2c48 |

## 팔레트

선형 RGBA. 앞 6색은 공용 팔레트 그대로이며 뒤 6색만 추가했다.

- wood: (0.24, 0.17, 0.11, 1.0)
- worn_wood: (0.38, 0.29, 0.19, 1.0)
- iron: (0.12, 0.15, 0.17, 1.0)
- worn_metal: (0.28, 0.32, 0.33, 1.0)
- cloth: (0.43, 0.41, 0.31, 1.0)
- enamel: (0.68, 0.7, 0.66, 1.0)
- snow: (0.84, 0.88, 0.9, 1.0)
- bark: (0.19, 0.15, 0.12, 1.0)
- rust: (0.31, 0.16, 0.09, 1.0)
- glass: (0.24, 0.37, 0.4, 1.0)
- rubber: (0.045, 0.055, 0.06, 1.0)
- stone: (0.29, 0.3, 0.28, 1.0)

## 지도 비용

C 40종의 지도 한 장 최대 소품 삼각형 합: **office_04 / 4,776개**.
지도 원문마다 종류별 수 × 실제 삼각형을 합했다. 다른 발주의 자산·건물·인물·런타임 추가 배치는 포함하지 않는다.

## 제외

- fishing_hole: 지형성 skip_ground_like: 발주 제외
- water: 지형성 skip_ground_like: 발주 제외
- snow_drift: 지형성 skip_ground_like: 발주 제외
- rock_face: 지형성 skip_ground_like: 발주 제외
- snow_bank: 지형성 skip_ground_like: 발주 제외
- snow_fence: 지형성 skip_ground_like: 발주 제외
- snow_gauge_pole: 지형성 skip_ground_like: 발주 제외
