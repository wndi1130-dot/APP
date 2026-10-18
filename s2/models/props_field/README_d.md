# 지도 소품 D

`tools/blender/props_field_d.py`가 자동 생성한다. 단일 메시·면 묶음, 정점색 Col, 종류당 600삼각형 이하.
재질·그림·조명·파티클·외부 참조·LOD 없음. 겨울색과 일부 눈 덮개는 실제 면 색이다.

rect 가운데 바닥, +Y 위·+Z 앞, facing에 따라 +Y 둘레 시계 방향 90도씩 회전. 손잡이·열린 문까지 발자국 안에 포함.

최빈 rect의 96% 이내로 맞춘다. 차량은 +Z 전면과 비율을 지키도록 폭을 더 줄인다. 지도 쪽 회전/다른 rect 크기의 적합성은 별도다.

| 이름 | 수 | 발자국 m | 높이 m | solid | 삼각형 | 바이트 | 판단 |
|---|---:|---|---:|---|---:|---:|---|
| `rubble_pile` | 10 | 4×3 | 0.85 | low:10 | 182 | 16892 | 광산의 각진 돌·벽돌 잔해, low 높이 |
| `service_counter` | 10 | 4×1 | 1.05 | low:6, none:4 | 116 | 9016 | 창구 상판·서랍·발받침, low 우세여서 none 배치도 같은 높이 |
| `skidder` | 10 | 5×3 | 1.3 | low:10 | 396 | 27192 | 제재소 집재차의 큰 바퀴·윈치·열린 운전석을 낮게 압축 |
| `support_frame` | 10 | 3×1 | 2.35 | none:10 | 60 | 5216 | 갱도 목재 지지틀 뜻을 우선해 none 높이 예외; 가운데 통과 공간 |
| `bark_heap` | 9 | 3×2 | 0.38 | none:9 | 120 | 9408 | 제재소 나무껍질 조각을 낮게 쌓음 |
| `cleaning_table` | 9 | 4×2 | 0.9 | low:9 | 120 | 9420 | 호수 손질대의 씻는 판·작은 배수 홈·받침 |
| `debarker` | 9 | 5×3 | 1.25 | low:9 | 276 | 19292 | 박피기의 원형 투입구·톱니 없는 롤러·받침 |
| `drying_rack` | 9 | 6×3 | 1.25 | low:9 | 144 | 11076 | 널빤지 건조 선반의 열린 세 단 구조 |
| `fish_hoist` | 9 | 3×3 | 2.7 | wall:9 | 140 | 10296 | 어망 인양용 A자 틀·권양 드럼·밧줄, wall 높이 |
| `fishing_platform` | 9 | 24×14 | 0.3 | none:9 | 204 | 15304 | 넓고 평평한 나무 작업 발판, 난간·승선 시설 없음 |
| `flat_trailer` | 9 | 8×3 | 0.95 | low:9 | 248 | 17096 | 낮은 빈 평판 화물 트레일러와 바퀴·견인봉 |
| `fuel_drum_group` | 9 | 2×2 | 1.1 | low:9 | 564 | 36284 | 뚜껑 닫힌 무표식 연료 드럼 세 개 |
| `log_carriage` | 9 | 6×2 | 1.15 | low:9 | 316 | 21344 | 통나무를 싣는 레일 대차의 받침과 목재 한 개 |
| `log_cart` | 9 | 4×2 | 1.2 | low:9 | 372 | 24748 | 바퀴 달린 작은 원목 수레, 원목 두 개 |
| `log_conveyor` | 9 | 8×1 | 1.05 | low:9 | 296 | 19696 | 연속 롤러가 드러나는 낮은 원목 이송대 |
| `oil_drum` | 9 | 1×1 | 0.9 | low:9 | 188 | 12768 | 철제 기름통의 두 테·작은 마개, 무표식 |
| `ore_cart_tipped` | 9 | 2×2 | 1.1 | low:9 | 272 | 18784 | 옆으로 기운 빈 광차와 노출된 바퀴 |
| `ore_truck` | 9 | 6×3 | 2.65 | wall:9 | 392 | 27172 | 광산 덤프트럭의 높은 적재함·유리 운전실, wall |
| `pickup_truck` | 9 | 5×2 | 1.3 | low:9 | 392 | 27180 | 눈 덮인 소형 픽업의 열린 적재함, low에 맞춘 높이 |
| `planer` | 9 | 3×2 | 1.05 | low:9 | 236 | 16248 | 대패 기계의 투입판·보호 덮개·회전 손잡이 |
| `rubbish_pile` | 9 | 2×1 | 0.3 | none:9 | 96 | 7740 | 쏟아진 쓰레기는 판재·금속 조각만; 가방·신발·옷 없음 |
| `sawdust_bin` | 9 | 3×2 | 1.1 | low:9 | 98 | 8448 | 열린 나무 통 안에 톱밥이 담긴 설비 |
| `sawdust_pile` | 9 | 3×3 | 0.8 | low:9 | 84 | 8300 | 잘게 부서진 목재색 톱밥 언덕과 옅은 눈 |
| `sawhorse` | 9 | 2×1 | 0.85 | low:9 | 60 | 5208 | 목공용 A자 다리 두 쌍과 긴 가로보 |
| `sleeper_pile` | 9 | 3×2 | 0.8 | low:9 | 132 | 10252 | 철도 침목 두 층을 교차해 쌓은 낮은 더미 |
| `weigh_scale` | 9 | 3×2 | 1.2 | low:9 | 80 | 6484 | 광산 바닥 저울의 넓은 계량판·기계식 눈금판 |
| `arcade_column` | 8 | 1×1 | 3.2 | wall:8 | 48 | 4376 | 회랑의 각진 석주·기단·주두, wall 높이 |
| `farm_cart` | 8 | 4×2 | 1.1 | low:8 | 296 | 20452 | 목재 짐수레의 열린 적재칸·두 바퀴·긴 끌채 |
| `fish_truck` | 8 | 6×3 | 2.45 | wall:8 | 392 | 27172 | 생선 운반용 무표식 냉장 화물차, 유리창·빈 적재함 |
| `garden_rack` | 8 | 3×1 | 1.15 | low:8 | 176 | 13336 | 정원용 낮은 선반에 빈 화분 두 개와 막대 도구 |
| `grave_plot` | 8 | 4×3 | 0.85 | low:8 | 92 | 7580 | 낮은 묘역 테두리·비문 없는 둥근 묘비, 번호·대기 칸 없음 |
| `ice_saw_frame` | 8 | 3×2 | 1.1 | low:8 | 118 | 9596 | 얼음톱의 사각 틀·손잡이·아래쪽 짧은 톱날 |
| `ladder_rack` | 8 | 4×1 | 1.15 | low:8 | 168 | 12780 | 사다리를 가로로 받치는 낮은 거치대 |
| `repair_lumber` | 8 | 4×2 | 0.55 | low:8 | 108 | 8576 | 수리용 널빤지 묶음과 목재 받침 |
| `signal_post` | 8 | 1×1 | 3.1 | wall:8 | 120 | 8652 | 철도 신호 기둥·무광 원판·수평 신호팔, 발광 없음 |
| `tender_wagon` | 8 | 3×11 | 2.8 | wagon:8 | 402 | 28964 | wagon은 탄수차로 해석; 석탄 칸·물 탱크, 사람 탑승 자리 없음 |
| `anvil_block` | 7 | 1×1 | 0.85 | low:7 | 84 | 7028 | 나무 받침 위 모루의 뿔·허리·평평한 타격면 |
| `box_wagon` | 7 | 3×11 | 3.1 | wagon:7 | 392 | 27168 | wagon은 빈 유개 화차; 양옆 문을 처음부터 옆으로 열어 둠 |
| `city_bus` | 7 | 10×3 | 1.8 | wall:7 | 572 | 39776 | 시내버스·유리창·열린 출입구, 짧은 rect 깊이에 맞춰 폭도 축소 |
| `cooking_pot` | 7 | 2×2 | 0.75 | low:7 | 184 | 12860 | 뚜껑과 두 손잡이를 단 큰 조리솥, 불·연기 없음 |
| `dough_table` | 7 | 2×1 | 0.85 | low:7 | 112 | 8600 | 반죽 작업대의 두꺼운 판·밀대·평평한 반죽판 |
| `grave_slab` | 7 | 2×1 | 0.2 | none:7 | 36 | 3528 | 비문 없는 낮은 석재 묘판, none 높이 |
| `parish_chest` | 7 | 2×1 | 0.8 | low:6, none:1 | 84 | 6896 | 교구 보관용 나무 궤, low 우세; 금속 띠와 뚜껑 |
| `reed_bundle` | 7 | 2×2 | 0.85 | low:7 | 352 | 24636 | 갈대 줄기를 묶은 자재 다발, 소지품 없음 |
| `altar_table` | 6 | 3×1 | 1 | low:6 | 96 | 7716 | 단순한 제단 상판과 두 받침, 천 한 장·금지 표식 없음 |
| `bell_frame` | 6 | 3×3 | 2.7 | none:6 | 176 | 12692 | 종을 매단 목재 틀 뜻을 우선해 none 높이 예외 |
| `bell_rope` | 6 | 1×1 | 0.18 | none:6 | 308 | 22452 | 바닥에 둥글게 감긴 종 밧줄 한 가닥으로 none 높이 유지 |
| `cloister_post` | 6 | 1×1 | 2.65 | wall:6 | 72 | 6064 | 회랑 목재 기둥·받침·짧은 버팀대, wall 높이 |
| `fallen_signal` | 6 | 5×1 | 0.45 | low:6 | 120 | 8652 | 옆으로 쓰러진 신호 기둥·원판·짧은 신호팔 |
| `high_rack` | 6 | 4×1 | 2.2 | wall:6 | 108 | 8572 | 높은 보관 선반의 네 단·빈 공간, wall 높이 |
| `meeting_table` | 6 | 4×2 | 0.76 | none:6 | 72 | 6060 | 회의용 탁자 뜻을 우선해 none 높이 예외; 의자·대기열 없음 |
| `old_coach` | 6 | 14×5 | 2.8 | none:6 | 572 | 39780 | 낡은 객차 뜻을 우선해 none 높이 예외; 유리창·열린 문 유지 |
| `plow_blade` | 6 | 4×2 | 1.15 | low:6 | 72 | 6052 | 제설 삽날의 꺾인 판·보강 리브·받침 |
| `pulpit` | 6 | 2×2 | 1.25 | low:6 | 60 | 5188 | 교회 설교단의 앞 판·읽기용 경사진 책받침·낮은 발판 |
| `snowplow_truck` | 6 | 6×3 | 2.5 | wall:6 | 416 | 28848 | 앞쪽 제설 삽날을 붙인 화물차, wall 높이 |
| `wire_coil` | 6 | 1×1 | 0.28 | low:6 | 308 | 23988 | 바닥에 감긴 매끈한 전선; 가시·철조망 없음 |
| `blanket_screen` | 5 | 3×1 | 1.25 | low:5 | 92 | 7448 | 담요 한 장을 낮은 목재 틀에 펼친 가림막, low 높이·소지품 더미 없음 |
| `boulder` | 5 | 2×2 | 1.2 | low:5 | 64 | 6448 | 눈이 조금 얹힌 각진 바위, low 높이 |
| `butcher_block` | 5 | 2×1 | 0.9 | low:3, none:2 | 72 | 6060 | 두꺼운 정육 작업판·튼튼한 다리, low 우세 |
| `courtyard_planter` | 5 | 3×2 | 1.2 | low:5 | 168 | 12660 | 중정 화분의 석재 통·눈·마른 가지 |

종류 60, 배치 466, 고유 메시 삼각형 12096, 바이트 881520.
지도 한 장 최대 D 소품 삼각형 합: `freight_02.gd`의 5,430. 이 몫 외 소품·컬링·인스턴싱 비용은 제외.

## 팔레트 (선형 RGBA)

| 색 | 값 |
|---|---|
| wood | (0.24, 0.17, 0.11, 1.0) |
| worn_wood | (0.38, 0.29, 0.19, 1.0) |
| iron | (0.12, 0.15, 0.17, 1.0) |
| worn_metal | (0.28, 0.32, 0.33, 1.0) |
| cloth | (0.43, 0.41, 0.31, 1.0) |
| enamel | (0.68, 0.7, 0.66, 1.0) |
| snow | (0.82, 0.88, 0.91, 1.0) |
| bark | (0.19, 0.16, 0.13, 1.0) |
| rust | (0.31, 0.16, 0.095, 1.0) |
| glass | (0.16, 0.27, 0.31, 1.0) |
| rubber | (0.035, 0.045, 0.05, 1.0) |
| stone | (0.33, 0.35, 0.36, 1.0) |

## SHA-256

| 종류 | sha256 |
|---|---|
| `rubble_pile` | `22259620231325e4d6fdc863411debb113c301221b11e8300a304a4055c4c4a8` |
| `service_counter` | `b8d526bfc1bc24336b9581f08f11cac0389957126c326631cda4707062c9f612` |
| `skidder` | `988ea1461078c0aac741b4ead587c925603414521465507d1f15636a46c3eb91` |
| `support_frame` | `5f8da315c89d3f9a1af3568b720271448383842484200306986dc8bf8a3c8f4c` |
| `bark_heap` | `1798c4cd8f5c9a793f9fb16892b07aae19b6d4512d225ccbe67abe13a842947b` |
| `cleaning_table` | `ae2d554c5511473daf401910bfb5180725ab823161714283b566393230591b52` |
| `debarker` | `bcd22c4ecabcedf06124fd09f5037a91d4510cb7e91d9ae467af55e33be6f803` |
| `drying_rack` | `731a2024759719d2a210663dbb4ce1431f3bfd207748cb76f65c18aed72a2a7b` |
| `fish_hoist` | `73e3b4c9e548b2daad6b1a29b3a22454c37752fdf39df40373a64146e4fe84a5` |
| `fishing_platform` | `00a0147edb274d0158e8891466222336a617db84557809a9e652bf4e3dc787fc` |
| `flat_trailer` | `93db8d13d447f53e98e09744e920a8ce91be78a6b15c508ec84078aa1e2bce79` |
| `fuel_drum_group` | `5b2dd2ebc11c80ad159f8b2458f1cae1c43fbccc201b3345a9dd39accbc986e8` |
| `log_carriage` | `d3bbcd61c1592c0f9321d68c5b8c8a06eccb400769627c4006ffab96246291c4` |
| `log_cart` | `b110df7e4494b45481217a2514b3cc697051c043b56de9bc5b87df7468c9dac5` |
| `log_conveyor` | `bda6f4140ba54f07a03649d0067e928f83ad36bd9514f77bb18b1073a8aa0e0b` |
| `oil_drum` | `447527d7826853a381fa152ddbd00903cb0dfd83c15cb5daff95d603806a896a` |
| `ore_cart_tipped` | `557b35e85227bc4d40c3bd63d99fc15a93550fea38a6e25eed1ee83e228fdf15` |
| `ore_truck` | `4d581da330e51b8c81920abf28c40dcccc780069b78196884ed18be30ae49b61` |
| `pickup_truck` | `18f83ca9d5c350ab170ee34484207cef5332688b89f89fd2f9946e72e1de6612` |
| `planer` | `06b925a970808ce3419d223f1e0a0f053e6e4564aad0b55eb5329fe97609d4ee` |
| `rubbish_pile` | `c4394a65e4cd427d339ce21ee5fbdfc733be909e0b7d8d85c39056eb1f5b9ee1` |
| `sawdust_bin` | `6d9884ea4c97d8a6db3db386cfd76a695ed113fbf6bce8beedaa111c8304db9a` |
| `sawdust_pile` | `ecc1dd154974045e97e34a496cc3413badd325df181b8a2c53f3db040f8498ea` |
| `sawhorse` | `e5935020fdef4d65041989fe424179498e99664b146121d94380868d4421b597` |
| `sleeper_pile` | `8662a03c55308d6406c3cabbc1008e66168313e11d52aa634647f5f629bf1c09` |
| `weigh_scale` | `76bb2fd876a46a5bbf7faacdfa0c30f67bc1f900f7129cf20825622f60bdeb22` |
| `arcade_column` | `ee0eb580a9e6fa4b2d8bb88309def30417493b27af926c898188ed5d8f3affbf` |
| `farm_cart` | `33d92484ef0298c038303593b1fbb98516d4fc8d12ea46a4151fa21d828a1502` |
| `fish_truck` | `fff63ba9e8374b657d430428c7f50dff70af62dfab6f80e3d9ad9c23235a4dce` |
| `garden_rack` | `4a41c44b89c5e78d4a2124165a4e4fc4ddcf2765d287f6f46145467c5654a027` |
| `grave_plot` | `4e6606ad40c6bca809c08c6b7e769d8ccf8d84e66efb931e39c0c970637545ef` |
| `ice_saw_frame` | `6db717addb0ffbf205f01766e42906e432d536f3c5027647bcb3a203ceada4e8` |
| `ladder_rack` | `81abb3a4cabd315b88d746f5e667fbd81348c99e64ddee20f3645c19c499a633` |
| `repair_lumber` | `65cac5c4a347ef91b1655dbf1a56998eb5942f247218f155876d3e06831c0f97` |
| `signal_post` | `0b71d3c1941cbb64739d722393d810724a3f4070b3294a2bbff4f296b1794ad3` |
| `tender_wagon` | `2dba5fc439f157c7380b17e396434329cae66bcd3f6452d11fd34abadda92ce3` |
| `anvil_block` | `be56124b74ce7553b25c3c545a5f418cfd95de0956335c00ca2c5f846eec7b6b` |
| `box_wagon` | `a9889a2bd7ade702930855fbf5a6fb5c2af5619638ba2df547f78cbf3e204115` |
| `city_bus` | `7de5f175554f0d46ef6b9019618447b7b91cdba0ea82341e887a6031733d7a5c` |
| `cooking_pot` | `b9b98e9b26ccb998135ef46b911bd36187ad495635a179f80acc6022e16bbf4a` |
| `dough_table` | `5c836ed153d4726cb94768755177e0fede7a017db8d3139f6d29af4361a4e49e` |
| `grave_slab` | `2319f10cb5f09bad5a9e7069e0dce07e483c67871417b6c0ccebc49bc8b20543` |
| `parish_chest` | `bda0a3b3397adfff9d49c213ffe3b46d765d3612b5a4f190fc8bfe0332b9add7` |
| `reed_bundle` | `791d5b06cb45f2cdb34a3e181700d166ff4e89b55d1a6f3eb36ec5b9a542084b` |
| `altar_table` | `2efd717ae2709335a8e66725e81591f5e1418cd005c1ab07ea5640305edb7c69` |
| `bell_frame` | `0e79f4d3a0e238cb7bedd32c627267fbf3c3ea9cc0060f09c0c70fbb7f135714` |
| `bell_rope` | `5e9eeb6f3bcba1444f46153b74f4834e1d62da5f1f60ae0082d38e44a1cd5b8a` |
| `cloister_post` | `9eff36f7deaf5fb6662f4ce37712a4fb06bd4798d821c43660b68fb3c6525b1b` |
| `fallen_signal` | `5e6c825692e68b93cc506e471f7291125c9e304c53299a02fc2940708e86c31a` |
| `high_rack` | `4016a20f6b70213650b267c110b393006c406ecc44201e96140d101d8f40d9b4` |
| `meeting_table` | `e18e224c3ccbf078e67684fc5f438fca876e856f359404c7fa3b997a50471c2b` |
| `old_coach` | `acc59193d5fc95b55d26124439858bf0c279ca676c76a55fef3844276a9bf69a` |
| `plow_blade` | `a742654e7c1aeb3024a206939ac2a11d9c38adff4eb7ba304ac75a5fa5a5fd25` |
| `pulpit` | `b12dd9e8e97a9c3798e4f58a6c4ce64b0cbbfe6d9b7ead9721c4af00c413c964` |
| `snowplow_truck` | `62fe8f7b5587fe50f55dce91b544d87961e60fa69331466f48d0479941bc75ee` |
| `wire_coil` | `37f589500319e2d79d30fff9caa5cf3105439c4cbe0a285bae3da87684f5b845` |
| `blanket_screen` | `a6dcf69dd1890405e81b30702c80a4ec13dff3ba7ebda349a7adc78d90ae36a7` |
| `boulder` | `8a1ac8069b780b72a3484a1236a7a270d168b8f583a8acb834a42d025a70a736` |
| `butcher_block` | `00da435c6edbb4f680955d2b402dd34b5c9da19c86f75a8a4db1eded871127e7` |
| `courtyard_planter` | `f41fdf8e1402fc4146f35e9831d031de2b593b631ddcc3b062f6bf93399df6da` |

## 입력 보완

빈 rect 표는 지도 원문 Rect2i의 최빈 크기로 보완했다. 동률이면 원문 파일 정렬에서 먼저 등장한 크기를 쓴다.
- `cleaning_table`: [4, 2], 최빈 9개, 근거 `s2/game/world/maps/lake_*.gd (Rect2i)`.
- `fish_hoist`: [3, 3], 최빈 9개, 근거 `s2/game/world/maps/lake_*.gd (Rect2i)`.
- `fishing_platform`: [24, 14], 최빈 3개, 근거 `s2/game/world/maps/lake_*.gd (Rect2i)`.
- `fuel_drum_group`: [2, 2], 최빈 9개, 근거 `s2/game/world/maps/lake_*.gd (Rect2i)`.
- `rubbish_pile`: [2, 1], 최빈 9개, 근거 `s2/game/world/maps/lake_*.gd (Rect2i)`.
- `fish_truck`: [6, 3], 최빈 8개, 근거 `s2/game/world/maps/lake_*.gd (Rect2i)`.
- `ice_saw_frame`: [3, 2], 최빈 8개, 근거 `s2/game/world/maps/lake_*.gd (Rect2i)`.

## 제외

- `fishing_hole`: 지형성 제외 목록; 이번 60종 밖.
- `water`: 지형성 제외 목록; 이번 60종 밖.
- `snow_drift`: 지형성 제외 목록; 이번 60종 밖.
- `rock_face`: 지형성 제외 목록; 이번 60종 밖.
- `snow_bank`: 지형성 제외 목록; 이번 60종 밖.
- `snow_fence`: 지형성 제외 목록; 이번 60종 밖.
- `snow_gauge_pole`: 지형성 제외 목록; 이번 60종 밖.

## 생성 실패

[]
