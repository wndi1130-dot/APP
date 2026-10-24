# 지도 소품 A

`tools/blender/props_field_a.py`가 생성한 자동 장부.

```
blender -b --factory-startup -P tools/blender/props_field_a.py -- --repo .
```

rect 가운데 바닥; +Y 위, +Z 앞; facing 0~3은 Y축 -90도씩; 회전 후 크기 보정 없음

종류당 메시 1개·면 묶음 1개, Col 정점색, 재질·그림·광원·애니메이션 없음.

rect가 비어 있던 버드나무·낚시깃대·얼음자리는 지도 Rect2i 최빈값으로 보완했다. rect가 없는 지점·조명 4종은 1×1m 가정이다.

| 이름 | 수 | 발자국 m | 높이 m | 삼각형 | 바이트 | 판단 |
|---|---:|---|---:|---:|---:|---|
| `bare_willow` | 225 | 1×1 | 4.6 | 196 | 15188 | 잎 없는 버드나무; 가늘게 아래로 늘어진 가지, tree 높이 예외 |
| `map_cabinet` | 206 | 3×1 | 0.48 | 120 | 9416 | none 우세; 지도용 얇고 넓은 서랍 네 단, 손잡이는 앞면 |
| `record_shelf_row` | 206 | 4×1 | 1.25 | 192 | 14456 | 기록 선반의 쓰임을 우선해 none 0.5m 예외; 긴 세 칸과 문서철 |
| `street_tree` | 198 | 1×1 | 4.4 | 208 | 15996 | 가로수 의미를 우선한 tree; 눈 얹힌 좁은 맨가지 수관 |
| `firewood_pile` | 197 | 2×1 | 0.85 | 132 | 9492 | low 우세; 잘린 장작 여섯 토막과 위쪽 눈 |
| `car` | 153 | 4×2 | 1.18 | 348 | 23828 | low 1.3m 이하; 눈 쌓인 소형 승용차, +Z 앞을 지키며 4×2m 안에서 폭을 줄임 |
| `conductor_log_chest` | 153 | 2×1 | 0.48 | 60 | 5232 | none 우세; 운행일지용 닫힌 나무 궤와 금속 손잡이 |
| `shop_counter` | 153 | 3×1 | 1.05 | 96 | 7736 | low 우세; 앞 판과 안쪽 수납칸이 구분된 낡은 판매대 |
| `tin_crate` | 142 | 2×1 | 0.48 | 120 | 9412 | none 우세; 골진 양철 상자와 모서리 보강 |
| `fuel_can_group` | 131 | 2×1 | 0.62 | 240 | 17444 | low 우세; 뚜껑과 열린 손잡이가 있는 연료통 세 개 |
| `freezer_chest` | 123 | 2×1 | 0.95 | 108 | 8580 | low 우세; 닫힌 위 여닫이 법랑 냉동고와 전면 통풍구 |
| `tire_stack` | 117 | 2×2 | 0.9 | 252 | 18656 | low 우세; 중앙 구멍이 관통하는 고무 타이어 세 단 |
| `coal_heap` | 111 | 3×2 | 0.8 | 92 | 7128 | low 우세; 각진 석탄 덩어리, 주변부에만 잔설 |
| `candle_stand` | 106 | 1×1 | 1.2 | 208 | 14560 | low 우세; 세 갈래 촛대와 꺼진 초, 불빛 없음 |
| `bench` | 101 | 3×1 | 0.95 | 120 | 9400 | low 우세; 판자 좌판과 등받이를 가진 벤치 |
| `hand_bell` | 92 | 1×1 | 0.4 | 112 | 7832 | low 상한 내; 벌어진 종 입구와 나무 손잡이 |
| `salvage` | 92 | 1×1 | 0.42 | 156 | 13852 | rect 없는 자재 지점은 1×1m 가정; 목재와 금속 부품만 배치 |
| `plank_stack` | 91 | 3×2 | 0.85 | 108 | 8572 | low; 엇갈린 받침 위에 두께가 보이는 제재 판자 여섯 장 |
| `stone_wall_segment` | 84 | 6×1 | 1.2 | 216 | 16152 | low; 거친 돌 여섯 구획을 쌓은 낮은 담장과 눈 덮개 |
| `shopping_cart` | 78 | 1×1 | 1.05 | 428 | 30480 | low 우세; 빈 장바구니, 열린 격자와 손잡이 및 네 바퀴 |
| `bare_orchard_tree` | 75 | 1×1 | 2.8 | 208 | 15784 | tree; 낮게 갈라지고 잘린 끝이 보이는 과수원 맨나무 |
| `tip_up_flag` | 75 | 1×1 | 0.48 | 64 | 5244 | none; 낚시 받침과 감개, 낮은 천 깃발, 표식 없음 |
| `hymn_shelf` | 69 | 2×1 | 1.2 | 180 | 13616 | low 우세; 찬송가 책 네 묶음을 둔 세 단 나무 선반 |
| `tool_cart` | 67 | 2×1 | 0.48 | 248 | 17992 | none 우세; 바퀴와 손잡이가 있는 낮은 두 단 공구 수레 |
| `vestry_chest` | 66 | 2×1 | 0.9 | 84 | 6900 | low 우세; 장식표지 없는 닫힌 제의실 수납 궤 |
| `fuel_drum` | 63 | 1×1 | 1.05 | 140 | 9536 | low; 금속 띠 둘과 주입구가 있는 녹슨 연료 드럼통 |
| `parts_rack` | 63 | 3×1 | 1.25 | 140 | 10672 | low 우세; 금속 기둥과 부품 수납함을 가진 선반 |
| `car_window` | 62 | 1×1 | 0.48 | 72 | 6056 | rect 없는 조명 지점은 1×1m 가정; 빛 없는 유리창 부품으로만 제작 |
| `bread_rack` | 61 | 1×1 | 1.2 | 204 | 14532 | low 우세; 나무 쟁반 세 단과 각진 빵 여섯 개 |
| `gear_rack` | 61 | 3×1 | 1.2 | 192 | 16376 | 장비 선반 의미를 우선해 none 0.5m 예외; 공구와 기계 부품만 수납 |
| `pew_row` | 59 | 6×1 | 1.1 | 132 | 10244 | low; 긴 좌판·등받이와 세 개 받침의 교회 의자 줄 |
| `radio_set` | 57 | 2×1 | 0.45 | 152 | 11144 | none 우세; 스피커 격자·주파수 창·다이얼과 접힌 안테나 |
| `net_pile` | 55 | 2×2 | 0.42 | 352 | 25656 | low 상한 내; 어구인 접힌 그물의 열린 격자, 소지품 없음 |
| `lamp_post` | 54 | 1×1 | 3.6 | 88 | 6920 | 가로등 의미를 우선한 none 높이 예외; 꺼진 등기구, 광원 없음 |
| `firebox` | 53 | 1×1 | 0.48 | 72 | 6052 | rect 없는 조명 지점은 1×1m 가정; 꺼진 화실과 열린 빈 입구만 제작 |
| `ammo_crate` | 52 | 2×1 | 0.48 | 84 | 6896 | none 우세; 무표식 닫힌 탄약 상자, 외부 내용물 없음 |
| `quilted_vest` | 52 | 1×1 | 0.12 | 132 | 10260 | none; 평평하게 펼친 조끼 한 벌과 누빔 봉제선, 옷 더미 없음 |
| `frozen_reeds` | 50 | 3×3 | 0.48 | 300 | 22464 | none; 얼어 붙은 낮은 갈대 열두 줄기와 얇은 눈 받침 |
| `log_stack_high` | 50 | 2×9 | 2.2 | 156 | 11172 | wall 1.8m 이상; 2×9m 방향으로 길게 쌓인 통나무 여섯 본 |
| `hardware_rack` | 47 | 3×1 | 1.2 | 184 | 15952 | 철물 선반 의미를 우선해 none 0.5m 예외; 고리·보강쇠·부품함 |
| `coupler_set` | 45 | 1×1 | 0.42 | 72 | 6060 | none 우세; 철도 연결기 머리와 축 부품 두 개, 사슬 없음 |
| `tool_rack` | 45 | 2×1 | 1.25 | 156 | 11920 | low; 긴 공구 세 자루를 기대 둔 열린 공구대 |
| `work_site` | 45 | 1×1 | 0.45 | 92 | 7328 | rect 없는 작업 지점은 1×1m 가정; 받침 둘과 작업판·공구, 구획 없음 |
| `ice_cut_pool` | 44 | 4×3 | 0.08 | 72 | 6056 | none; 잘라낸 얼음 가장자리와 낮은 얼음면, 물 효과 없음 |
| `lamp_shelf` | 44 | 2×1 | 0.48 | 188 | 13668 | none 우세; 낮은 선반 위 꺼진 손등 두 개, 빛과 불꽃 없음 |
| `rope_coil` | 44 | 1×1 | 0.24 | 212 | 22036 | low 상한 내; 두 겹 밧줄 고리와 풀린 끝, 사람용 구속물 없음 |
| `notice_board` | 42 | 2×1 | 1.85 | 96 | 7736 | 게시판 쓰임을 우선한 none 높이 예외; 기둥 둘과 무문자 공지판 |
| `blanket_crate` | 41 | 2×1 | 0.48 | 60 | 5220 | none 우세; 덮개가 닫힌 담요 보관 상자, 밖으로 쌓인 옷 없음 |
| `glass_cabinet` | 40 | 2×1 | 1.25 | 132 | 10248 | 유리 수납장 의미를 우선해 none 0.5m 예외; 불투명 청회색 유리 |
| `fieldstone_wall` | 38 | 8×1 | 1.2 | 288 | 21188 | low; 길게 이어진 들돌 담장 세 단과 군데군데 잔설 |

## 팔레트 (선형 RGBA)

- `wood`: (0.24, 0.17, 0.11, 1.0)
- `worn_wood`: (0.38, 0.29, 0.19, 1.0)
- `iron`: (0.12, 0.15, 0.17, 1.0)
- `worn_metal`: (0.28, 0.32, 0.33, 1.0)
- `cloth`: (0.43, 0.41, 0.31, 1.0)
- `enamel`: (0.68, 0.7, 0.66, 1.0)
- `snow`: (0.82, 0.87, 0.88, 1.0)
- `bark`: (0.19, 0.16, 0.13, 1.0)
- `rust`: (0.3, 0.15, 0.075, 1.0)
- `glass`: (0.2, 0.34, 0.38, 1.0)
- `rubber`: (0.035, 0.043, 0.048, 1.0)
- `stone`: (0.34, 0.36, 0.34, 1.0)

## SHA-256

| 이름 | SHA-256 |
|---|---|
| `bare_willow` | `0f5526325832b017cc2cc5c977eafe692f213032db29c279ac016bec247bcff0` |
| `map_cabinet` | `92edf039eaa138081c24f74c8cd568028a85f0c2254cdb685029c6e4436fe8ed` |
| `record_shelf_row` | `3be843d80743c82ef425958f8181827722dd1e05d8eef33b0d52bbc679e0adcf` |
| `street_tree` | `fcc90a999fc6f0f6aaf896076056540f4180be8d8ec0bb7686256c6a877eb452` |
| `firewood_pile` | `604e221d7080382b4bd92d0d04e61b78b5e4b92c87a545369243943633207e11` |
| `car` | `6d9f5a5144ab403b464b7b08d229e55812381cfd3cc8ac801e68ba985bfb095f` |
| `conductor_log_chest` | `302e343644da4f23e2672685b7d7f1779d247f965de74b02236e372ed87afc8c` |
| `shop_counter` | `05fb823902a4165b757e09a489cfe1acc0beb67ec0e6dd901269931e49d75491` |
| `tin_crate` | `e94a7daba600a7a17eac17262c76b2a7e4dba720650490cb2400249bbd19c80a` |
| `fuel_can_group` | `52c2f1e8c66bb67150a9af8da6747625381d7d2550cb4d22ce901971e5d97790` |
| `freezer_chest` | `6cafb548dfef4e96db8d569ebec1106463a59ea3fe926b3434dcc8e9f8c6b81b` |
| `tire_stack` | `2b9d823e4eb89d847f84ff102a252509dfe8ba69c75f7aa8f8adf3ac113e05d4` |
| `coal_heap` | `50189a544e27cbceced164d59fbc4913d6515849875d61f2d1a109cdf82ef03d` |
| `candle_stand` | `41461340873bab0d93e946b435317ea0ce6f0c7b0dbcb800a4e57077353c9859` |
| `bench` | `e9b6795559845d13402d18d4c7e12f51fa0059f0e55eed73df373d81cf625170` |
| `hand_bell` | `ac81c18f30ffc0fe8f61afcfd9f974ff71a7e9b09308b6058d0751945399367b` |
| `salvage` | `48de08e80fd1e22e4257e3c7cf7501fc95a41d352b0d3593558bf46af8a025f3` |
| `plank_stack` | `f76f34ca5642f760764b03f6969514ae772782e96ee8a88214ebeec0a28a7ebf` |
| `stone_wall_segment` | `c6020661d65c75949ee5e2f442532b8a7067e7c9fb71173b7a5380ee89d68069` |
| `shopping_cart` | `1b8b8e3512470dfb8288b11b559aeed16a7e2af4c97ce97c61a7473e4929f03c` |
| `bare_orchard_tree` | `fb3dee5950eeecf1b714ff4093edb18948ce3b5afe7d9b7ff0c53287ca6b265d` |
| `tip_up_flag` | `6cbb64f35685f2a53e4376db9e20dd1e4cba3dd6234362f9de26ac9a2a4adef3` |
| `hymn_shelf` | `c036ba9ef53358988404c35aa5095db09d9690f8580b26ed8be839647d15ab0c` |
| `tool_cart` | `429100f410e3570d0d1958323b8366b08c74dd8b8402ac45481e2bf1361076be` |
| `vestry_chest` | `93636274f67f0fc9c0a384e0aead92a0d368067347a9d552ef884f4730e1a778` |
| `fuel_drum` | `2b3046d64876096759de9b9a5208ae596e25a1b15bccba2e1784b5f4cb428f78` |
| `parts_rack` | `7cd8e7a2d947f818dbdf0d5f1f8db2a56d786824080a2abffc1795c9b30fc18e` |
| `car_window` | `51b22888912aec8e51913bb2d08b03705ced350bcab320e472a7cda2749db44c` |
| `bread_rack` | `fbf631543f0b9e99c84cc24142b95a1c4a3f903bb4cb0fdae9e9b289836b48d1` |
| `gear_rack` | `66abe6834364d9e1723aa174aa2fcd155ae13352e4decc306086330718eded1d` |
| `pew_row` | `0327b3a2ff60a184ec6bf8f60fde2e78f63fd3ae610817f2e4c433c6c4eeea01` |
| `radio_set` | `9cda5a223c9c1798650ef26433b346ccee23cd7b3f442c922a1635dcc4ff0f0f` |
| `net_pile` | `5d6b8285cc14e8fd0ac56f7400aafe3d13abd1066daea5d4d8e996b04f0a0984` |
| `lamp_post` | `088a02b52ecd1ad69a661ed9ff5b3f486cd70523c6328d1ef41dae03582b1cf5` |
| `firebox` | `9964916eb4654cfa78113c45d99fc3e94f20f41c838be26bf621bc6f390d640d` |
| `ammo_crate` | `187d74725de8714b28c1b61ce26ef79eff7cac20688096665a5d94430cf95014` |
| `quilted_vest` | `8099e2c7138991a40753cee6a35d37d8a12ebb02973cf03f76cb42fe127e0435` |
| `frozen_reeds` | `3c2ad4d8f29b27fa8947072d9110f7956b932e72945a71adae82918dd71c8251` |
| `log_stack_high` | `05d7a2f8035ba7ecb052a5c1296e285ac96491706f39f765a185f062e45b4a79` |
| `hardware_rack` | `dafa752599b754adcc75864d20d0e6a3c1fc647a0ffdc5adc67e6926420f0dfb` |
| `coupler_set` | `f174d8b783c6b6a0866b6c7a04f3aefdcc5b401012e8013a0a435510e94d520e` |
| `tool_rack` | `b614f590bbc56b8052dadf535cda9bb2205dc3badb60622291fb26ac88ec17ed` |
| `work_site` | `5fb110371f35ff2ab51b7e00771e32fff75d82ac187521c73b248f9237f9fe6c` |
| `ice_cut_pool` | `24a8b3061e65a6bd008804a6d182efaeb909892e9dc843912376c933ad0a1629` |
| `lamp_shelf` | `565dac52314e1f92f238d92232935a6936abe1c8f899e166cb4c7903aa83fbb1` |
| `rope_coil` | `3f862dc18f0f467460ef4ec4dcc061234326a20c25b740fdd50c098b6ef56f9b` |
| `notice_board` | `6a90e8de3d0a332bf24fd671c866208a17178cd324db864be8aa5cdc0c95715e` |
| `blanket_crate` | `b2e67a8573869f685583376b55dff14394b9ad85270413b20f7713607e5f49ca` |
| `glass_cabinet` | `13ee4cd4526a1137f80bc8ea51fc8079079da86333e4e55ecd827b59d6d7cdee` |
| `fieldstone_wall` | `2b3f3eda619cd13028927447cf5b6a181eaf584f3d0e2a10c764a1fed5df4f7c` |

지도 한 장 최대 소품 삼각형 합(원문 출현 기준 A종 추정): `office_06` 59,292.
지도 원문 kind 출현 수 × A종 삼각형. 반복문 실행 수·다른 소품·건물 제외; 런타임 총량 아님

`salvage`, `work_site`는 spots, `car_window`, `firebox`는 lights의 종류다. 모델은 빛 없는 물건으로 만들었지만 현재 _build_props가 이 지점에 자동 배치하지 않는다.
지형성 제외 7종: fishing_hole, water, snow_drift, rock_face, snow_bank, snow_fence, snow_gauge_pole.
