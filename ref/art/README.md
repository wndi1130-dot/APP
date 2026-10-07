# 3D 제작 자료 전체 색인

갱신: 2026-10-07

[저장소 README](../../README.md) · [현재 제작 기준](../../docs/art/production_brief.md) · [조사 지시서](../../docs/handoff/3d_research_tasks.md)

**조사 항목 71개**를 나열한다. 새 공급처·무료팩·다운로드 완료 수가 아니다. 같은 생태계의 개별 의복이나 기능 문서도 항목으로 센다. 서로 다른 ID를 세었으며 유사 기능까지 독립 공급처로 주장하지 않는다.

기존 판은 당시 조사 기록으로 보존했다. 뒤의 판은 보충이지 전 항목의 최신성 재검증이 아니다. 특히 약관·지원 버전은 실제 취득할 때 원문과 파일을 다시 고정한다. 모든 후보의 프로젝트 실행은 [WATCH]다.

## 읽는 순서와 파일

| 파일 | 역할 |
|---|---|
| [production_resources.md](production_resources.md) · [resource_index.json](resource_index.json) | 2판 기반 후보 |
| [game_reference_resources_v3.md](game_reference_resources_v3.md) · [game_reference_resources_v3.json](game_reference_resources_v3.json) | 3판 작품별 근거·생활 자원·장면 검증안 |
| [production_gap_resources_v4.md](production_gap_resources_v4.md) · [production_gap_resources_v4.json](production_gap_resources_v4.json) | 4판 정확한 작업 모션·구조·철도음·제작 보완 |
| [production_resources_v5.md](production_resources_v5.md) · [production_resources_v5.json](production_resources_v5.json) | 5판 방한복·소품·전달·메모리 검수 |
| [build_research_index.py](build_research_index.py) · [test_research_index.py](test_research_index.py) | 네 목록 통합 검사와 이 README/루트 목록/4·5판 보고서 생성 |
| [validate_catalog.py](validate_catalog.py) · [test_validate_catalog.py](test_validate_catalog.py) | 기존 2판 메타데이터·현재 지시·보관본 검사 |
| [archive_manifest.json](archive_manifest.json) | 과거 프롬프트 본문 보존 해시 |
| [game_reference_validation_v3.json](game_reference_validation_v3.json) | 이전 3판의 검사 기록. 이번 재실행 기록과 구분 |

## 2판 후보 37개

| ID / 자원 | 분야·용도 | 근거 |
|---|---|---|
| `bpy_cli` — Blender bpy / 백그라운드 CLI | 제작·자동화 / Claude Code·Codex·COS가 같은 생성·변환 설정과 로그를 남기는 기본 경로. | [조사](production_resources.md) · [출처 1](https://docs.blender.org/manual/en/4.5/advanced/command_line/arguments.html) |
| `geometry_nodes` — Geometry Nodes / Asset Browser | 제작·자동화 / 선로·침목·창문·배관·반복 객차 구조를 파라미터로 제작하고 자산으로 재사용. | [조사](production_resources.md) · [출처 1](https://docs.blender.org/manual/en/4.5/modeling/geometry_nodes/instances.html) |
| `fake_bpy` — fake-bpy-module | 제작·자동화 / 에이전트가 Blender Python을 작성할 때 API 이름·타입을 확인하는 보조 수단. | [조사](production_resources.md) · [출처 1](https://github.com/nutti/fake-bpy-module) |
| `blender_mcp` — MCP for Blender (ahujasid) | 제작·자동화 / 대화형 장면 조회와 변경이 필요할 때의 선택적 연결 경로. COS bpy CLI의 필수 대체재는 아니다. | [조사](production_resources.md) · [출처 1](https://github.com/ahujasid/mcp-for-blender) · [출처 2](https://github.com/ahujasid/mcp-for-blender/blob/main/TERMS_AND_CONDITIONS.md) |
| `rigify` — Rigify | 인물·동작 / 공통 인체 리그를 제작해 겨울 복장과 동작 라이브러리를 연결. | [조사](production_resources.md) · [출처 1](https://docs.blender.org/manual/en/4.5/addons/rigging/rigify/introduction.html) |
| `mpfb` — MPFB / MakeHuman | 인물·동작 / 체형·얼굴·복장을 조합할 인물 기반 후보. | [조사](production_resources.md) · [출처 1](https://static.makehumancommunity.org/about/license.html) |
| `quaternius_bodies` — Quaternius Universal Base Characters | 인물·동작 / 동작 라이브러리와 짝지어 볼 공통 몸체 후보. 보통 체형을 우선 비교. | [조사](production_resources.md) · [출처 1](https://quaternius.com/packs/universalbasecharacters.html) |
| `quaternius_anim1` — Quaternius Universal Animation Library 1 | 인물·동작 / 걷기·달리기·기어가기·앉기·전투·감정 표현의 기반. | [조사](production_resources.md) · [출처 1](https://quaternius.com/packs/universalanimationlibrary.html) · [출처 2](https://quaternius.itch.io/universal-animation-library) |
| `quaternius_anim2` — Quaternius Universal Animation Library 2 | 인물·동작 / 좀비 이동, 농사·낚시·근접 콤보 등 1편의 빈 동작을 보충할 후보. | [조사](production_resources.md) · [출처 1](https://quaternius.com/packs/universalanimationlibrary2.html) · [출처 2](https://quaternius.itch.io/universal-animation-library-2) |
| `rokoko_retarget` — Rokoko Studio Live Blender — 리타기팅 | 인물·동작 / 서로 다른 뼈 이름·체격을 가진 모션을 공통 리그로 옮기는 보조 경로. | [조사](production_resources.md) · [출처 1](https://github.com/Rokoko/rokoko-studio-live-blender) · [출처 2](https://github.com/Rokoko/rokoko-studio-live-blender/blob/master/LICENSE.md) · [출처 3](https://support.rokoko.com/hc/en-us/articles/4410463481489-Retargeting-an-animation-in-Blender-Plugin-1-1-and-above) |
| `mixamo` — Adobe Mixamo | 인물·동작 / CC0 팩에서 빠진 일반 인간 동작을 보충할 후보. | [조사](production_resources.md) · [출처 1](https://helpx.adobe.com/creative-cloud/faq/mixamo-faq.html) |
| `kenney_train` — Kenney Train Kit | 건물·소품 / 선로 연결·곡선·객차 간격을 빠르게 검토하는 회색 박스 후보. | [조사](production_resources.md) · [출처 1](https://kenney.nl/assets/train-kit) |
| `kenney_buildings` — Kenney Modular Buildings | 건물·소품 / 건물 모듈 스냅과 마을 블록 구성을 검토. | [조사](production_resources.md) · [출처 1](https://kenney.nl/assets/modular-buildings) |
| `kenney_factory` — Kenney Factory Kit | 건물·소품 / 공방·정비·산업시설 배치 검토용 부품 후보. | [조사](production_resources.md) · [출처 1](https://kenney.nl/assets/factory-kit) |
| `kenney_industrial` — Kenney City Kit Industrial | 건물·소품 / 역 주변 공업지대의 외형·구역 구분 후보. | [조사](production_resources.md) · [출처 1](https://kenney.nl/assets/city-kit-industrial) |
| `kenney_furniture` — Kenney Furniture Kit | 건물·소품 / 침대·책상·의자 등 실내 배치와 크기 검토 후보. | [조사](production_resources.md) · [출처 1](https://kenney.nl/assets/furniture-kit) |
| `bitsoft_factory` — BitSoft Soviet Factory | 건물·소품 / 낡은 공장 플랫폼·사다리·기계·울타리의 구체적 구성 참고 및 제한적 재사용 후보. | [조사](production_resources.md) · [출처 1](https://bitsoft.itch.io/soviet-factory) |
| `poly_haven` — Poly Haven | 재질·텍스처 / 눈·돌·낡은 목재·철·벽돌 재질 원본과 일부 소품·조명 참고. | [조사](production_resources.md) · [출처 1](https://polyhaven.com/license) |
| `ambient_cg` — ambientCG | 재질·텍스처 / 눈·지면·콘크리트·벽돌·금속 재질의 대체 공급처. | [조사](production_resources.md) · [출처 1](https://docs.ambientcg.com/license/) |
| `blendkit` — Blendkit / 구 BlenderKit | 재질·텍스처 / 일반 소품·실내·재질 후보를 검색할 보조 공급처. | [조사](production_resources.md) · [출처 1](https://www.blendkit.com/docs/licenses/) |
| `ucupaint` — Ucupaint | 재질·텍스처 / 녹·그을음·눈·먼지·복장 얼룩을 레이어와 마스크로 제작·베이크. | [조사](production_resources.md) · [출처 1](https://extensions.blender.org/add-ons/ucupaint/versions/) |
| `textools` — TexTools — franMarz 유지보수판 | 재질·텍스처 / 텍셀 밀도·UV 정렬·ID 맵·텍스처 베이크를 통일. | [조사](production_resources.md) · [출처 1](https://github.com/franMarz/TexTools-Blender) · [출처 2](https://github.com/franMarz/TexTools-Blender/blob/master/LICENSE.txt) |
| `material_maker` — Material Maker | 재질·텍스처 / 눈·성에·젖음·벽돌·천·녹을 재사용 가능한 절차 재질로 제작하는 대안. | [조사](production_resources.md) · [출처 1](https://www.materialmaker.org/) · [출처 2](https://github.com/RodZill4/material-maker) |
| `ant_landscape` — A.N.T.Landscape | 환경 생성 / 설원 주변 산·절벽·기초 지형의 오프라인 생성 후보. | [조사](production_resources.md) · [출처 1](https://extensions.blender.org/add-ons/antlandscape/) |
| `sapling` — Sapling Tree Gen | 환경 생성 / 침엽수·앙상한 나무·겨울 숲의 반복 변형 후보. | [조사](production_resources.md) · [출처 1](https://extensions.blender.org/add-ons/sapling-tree-gen/) |
| `wall_cutout` — Daniel Ilett Wall Cutout | 엔진 셰이더 / 사선 시점에서 캐릭터를 가리는 앞벽을 부분적으로 걷어내는 구현 참고. | [조사](production_resources.md) · [출처 1](https://github.com/daniel-ilett/shaders-wall-cutout) |
| `snow_tracks` — Sand Shader Unity URP for Mobile | 엔진 셰이더 / 눈 위 발자국·바퀴 자국·끌린 흔적의 누적 마스크 구조 참고. | [조사](production_resources.md) · [출처 1](https://github.com/TheodorKnab/Sand-Shader-Unity-URP-for-Mobile) |
| `urp_outlines` — Unity URP Outlines — Robinseibold | 엔진 셰이더 / 고른 인물·객차의 경계 표시 후보. 전체 월드를 만화식 윤곽선으로 고정하지 않는다. | [조사](production_resources.md) · [출처 1](https://github.com/Robinseibold/Unity-URP-Outlines) |
| `urp_decals` — Unity URP Decal Renderer Feature | 엔진 셰이더 / 포스터·낙서·그을음·손상·발자국처럼 상태가 남는 표면 표현. | [조사](production_resources.md) · [출처 1](https://docs.unity3d.com/6000.0/Documentation/Manual/urp/renderer-feature-decal.html) |
| `smoke_particles` — Kenney Smoke Particles | 효과·연출 / 증기·연기·먼지 효과의 임시 텍스처 후보. | [조사](production_resources.md) · [출처 1](https://kenney.nl/assets/smoke-particles) |
| `texture_sheet` — Unity Texture Sheet Animation | 효과·연출 / Blender에서 후속 제작할 연기·증기 flipbook을 엔진 입자로 재생할 기본 경로. | [조사](production_resources.md) · [출처 1](https://docs.unity3d.com/6000.0/Documentation/Manual/PartSysTexSheetAnimModule.html) |
| `unity_rigging` — Unity Animation Rigging | 인물·동작 / 실제 문손잡이·무기·공구와 손·발을 맞추는 엔진 측 보정 후보. | [조사](production_resources.md) · [출처 1](https://docs.unity3d.com/Packages/com.unity.animation.rigging@1.4/manual/index.html) |
| `gltf_validator` — Khronos glTF Validator | 전달·검수 / GLB/glTF 전달 파일의 구조 오류를 자동 보고. | [조사](production_resources.md) · [출처 1](https://github.com/KhronosGroup/glTF-Validator) |
| `gltf_transform` — glTF Transform | 전달·검수 / GLB 정리·텍스처 축소·중복 제거·애니메이션 최적화의 재현 가능한 변환. | [조사](production_resources.md) · [출처 1](https://github.com/donmccurdy/glTF-Transform) |
| `meshoptimizer` — meshoptimizer / gltfpack | 전달·검수 / 정점·인덱스·메시 간소화·전달 용량 최적화 후보. | [조사](production_resources.md) · [출처 1](https://github.com/zeux/meshoptimizer) |
| `gltfast` — Unity glTFast | 전달·검수 / GLB를 전달 규격으로 택할 경우 Unity import/export 경로 후보. | [조사](production_resources.md) · [출처 1](https://github.com/Unity-Technologies/com.unity.cloud.gltfast) |
| `blender_gis` — BlenderGIS | 월드·지도 / 후반 실제 철도망 주변 지형·OSM 외곽을 제작 참고로 가져오는 경로. | [조사](production_resources.md) · [출처 1](https://github.com/domlysz/BlenderGIS) · [출처 2](https://github.com/domlysz/BlenderGIS/wiki/OSM-import) |

## 3판 후보 17개

| ID / 자원 | 분야·용도 | 근거 |
|---|---|---|
| `cmu_focused_mocap` — CMU Graphics Lab – 생활·부상·상호작용 모션 | 모션 데이터 / 부상 보행·바닥 수색·방향 지시를 공통 리그로 옮기는 출발점. 62와 18/19는 작업/두 사람 동작의 탐색 후보로만 남긴다. | [조사](game_reference_resources_v3.md) · [출처 1](https://mocap.cs.cmu.edu/) · [출처 2](https://mocap.cs.cmu.edu/search.php?subjectnumber=139) · [출처 3](https://mocap.cs.cmu.edu/subjects.php) |
| `mh_shirts01_selected` — MakeHuman Shirts 01 – toigo_fisherman_sweater | 복장 자산 / 군인 아닌 민간인의 니트 기본형 후보. 낡음·기워 붙임·색 차이는 우리 쪽 재질/변형으로 만든다. | [조사](game_reference_resources_v3.md) · [출처 1](https://static.makehumancommunity.org/assets/assetpacks/shirts01.html) |
| `mh_shirts02_selected` — MakeHuman Shirts 02 – 민간인 후드·가디건 | 복장 자산 / 후드·노년 여성 의상·가디건처럼 주민 실루엣을 넓히는 후보. 역할과 국적을 의복 하나로 고정하지 않는다. | [조사](game_reference_resources_v3.md) · [출처 1](https://static.makehumancommunity.org/assets/assetpacks/shirts02.html) |
| `mh_newsboy_cap` — MakeHuman Hats 01 – jujube_newsboy_cap | 복장 자산 / 기관사·노동자용 모자 기본형 비교. 모자만으로 특정 공동체의 얼굴을 전부 같게 만들지 않는다. | [조사](game_reference_resources_v3.md) · [출처 1](https://static.makehumancommunity.org/assets/assetpacks/hats01.html) |
| `mh_plain_gloves` — MakeHuman Gloves 01 – toigo_gloves_short/medium | 복장 자산 / 난방 작업·운반·야외 수색자의 손을 구분하는 기본형 후보. | [조사](game_reference_resources_v3.md) · [출처 1](https://static.makehumancommunity.org/assets/assetpacks/gloves01.html) |
| `mh_plain_boots` — MakeHuman Shoes 01 – toigo_ankle_boots_male/female | 복장 자산 / 민간인 신발 기본형 후보. 눈 위 밑창·발목 실루엣을 자가 변형할 출발점. | [조사](game_reference_resources_v3.md) · [출처 1](https://static.makehumancommunity.org/assets/assetpacks/shoes01.html) |
| `atomic_postapoc` — Atomic Realm – Post-Apocalyptic World | 환경·생활 소품 / 의무칸·거주칸·역 관리동을 채울 사물 후보. 침상 주변 소지품과 약품 선반의 약탈 전/후 상태를 자체 구성한다. | [조사](game_reference_resources_v3.md) · [출처 1](https://atomicrealm.itch.io/post-apocalyptic-world) |
| `mco_crowd` — MoCap Online – Crowd | 의회·군중 애니메이션 / 조용히 듣기·언짢은 반응·자리에서 일어나기만 골라 의회 동작의 비교 후보로 삼는다. | [조사](game_reference_resources_v3.md) · [출처 1](https://mocaponline.com/products/crowd) · [출처 2](https://mocaponline.com/pages/standard-license) |
| `audio_snow_611277` — Freesound 611277 – Footsteps on snow (clean) | 음원 / 눈밭 보행의 기본 녹음 후보. 개별 발걸음으로 잘라 변형하고 발 접촉 시점에 재생한다. | [조사](game_reference_resources_v3.md) · [출처 1](https://freesound.org/people/xkeril/sounds/611277/) |
| `audio_radiator_265013` — Freesound 265013 – NYC steam radiator hiss.wav | 음원 / 객차 난방이 살아 있는 상태와 꺼진 상태를 대비할 지속음 재료. | [조사](game_reference_resources_v3.md) · [출처 1](https://freesound.org/people/sethlind/sounds/265013/) |
| `audio_pressure_234782` — Freesound 234782 – Steam/hiss | 음원 / 밸브 조작·짧은 증기 방출의 시작/끝 효과 후보. 기관차 작동 전체 녹음 대신 국소 효과로 쓴다. | [조사](game_reference_resources_v3.md) · [출처 1](https://freesound.org/people/wubitog/sounds/234782/) |
| `audio_radio_524205` — Freesound 524205 – Radio Sign Off / Squelch | 음원 / 열차장의 명령·망보기 보고의 시작/끝 문법을 만드는 짧은 효과 후보. | [조사](game_reference_resources_v3.md) · [출처 1](https://freesound.org/people/JovianSounds/sounds/524205/) |
| `sonniss_gdc` — Sonniss #GameAudioGDC Bundle | 음원 수급처 / 바람·금속문·옷 마찰·공구·기관 작동음의 빠진 부분을 트랙 목록에서 찾는 2차 수급처. | [조사](game_reference_resources_v3.md) · [출처 1](https://sonniss.com/gameaudiogdc/) · [출처 2](https://sonniss.com/gdc-bundle-license/) · [출처 3](https://sonniss.com/gdc-bundle-license/previous-versions/) |
| `unity_audio_snapshots` — Unity Audio Mixer / Snapshots | 엔진 기능 / 실외 눈보라/객차 안/무전 보고/의회 발언의 청취 우선순위를 바꾸는 후보. 기존 녹음 여러 개를 상태별로 섞는다. | [조사](game_reference_resources_v3.md) · [출처 1](https://docs.unity3d.com/6000.0/Documentation/Manual/AudioMixerOverview.html) |
| `cq_urp_volumetric` — Cristian Qiu – Unity URP Volumetric Light | 오픈소스 셰이더/렌더 기능 / 역사의 먼지·차가운 안개 속 광선처럼 제한된 장면의 선택 후보. | [조사](game_reference_resources_v3.md) · [출처 1](https://github.com/CristianQiu/Unity-URP-Volumetric-Light) · [출처 2](https://raw.githubusercontent.com/CristianQiu/Unity-URP-Volumetric-Light/main/LICENSE.md) · [출처 3](https://raw.githubusercontent.com/CristianQiu/Unity-URP-Volumetric-Light/main/package.json) |
| `unity_ugui_shaders` — Unity Shader Graph – UGUI Shaders sample | UI 셰이더 예제 / 긴장도에 반응하는 테두리/계기/노이즈의 독자 구현 출발점. 글자·숫자·핵심 아이콘과 움직이는 배경을 분리한다. | [조사](game_reference_resources_v3.md) · [출처 1](https://docs.unity3d.com/Packages/com.unity.shadergraph@17.0/manual/Shader-Graph-Sample-UGUI-Shaders.html) · [출처 2](https://docs.unity3d.com/Packages/com.unity.shadergraph@17.0/manual/Shader-Graph-Sample-UGUI-Shaders-Notes-on-performance.html) |
| `unity_timeline` — Unity Timeline | 장면·동작·효과 조율 / 의회 시작, 구조자 귀환, 기술 복원처럼 짧게 정해진 장면의 재사용/타이밍 관리 후보. | [조사](game_reference_resources_v3.md) · [출처 1](https://docs.unity3d.com/Packages/com.unity.timeline@1.8/manual/index.html) |

## 4판 후보 8개

| ID / 자원 | 분야·용도 | 근거 |
|---|---|---|
| `mcc_fix_build` — MoCap Central — Fix & Build | 유료 작업 모션 팩 / 삽질·렌치·탁상 정비·설계도 확인 동작의 조달 후보. | [조사](production_gap_resources_v4.md#mcc_fix_build) · [S01](https://mocapcentral.com/products/mocap-studio-series-fix-build-pack) · [S02](https://mocapcentral.com/pages/fix-build-animation-list) · [S03](https://mocapcentral.com/pages/licensing) |
| `reallusion_injury_rescue` — Reallusion — Injury & Rescue | 유료 구조·짝동작 모션 팩 / 부상자 부축·업거나 들기·들것 운반·구호물자 전달 비교. | [조사](production_gap_resources_v4.md#reallusion_injury_rescue) · [S04](https://www.reallusion.com/ContentStore/iClone/pack/3D-Animation-Injury-and-Rescue/default.html) · [S05](https://www.reallusion.com/license/content.html) |
| `audio_train_departure_125211` — Freesound 125211 — keithpeter의 증기열차 출발 녹음 | CC0 개별 현장 음원 / 출발 순간의 증기·급탄·기적·차륜 소리 층을 비교할 재료. | [조사](production_gap_resources_v4.md#audio_train_departure_125211) · [S06](https://freesound.org/people/keithpeter/sounds/125211/) |
| `audio_loco_whistle_686058` — Freesound 686058 — relwin의 기관차 기적 | CC0 개별 현장 음원 / 열차 출발 신호의 실제 기관차 기적 후보. | [조사](production_gap_resources_v4.md#audio_loco_whistle_686058) · [S07](https://freesound.org/people/relwin/sounds/686058/) |
| `evocative_american_steam` — Evocative Sound and Visuals — American Steam Trains | 유료 철도 음향 라이브러리 / 화실 급탄·증기 방출·근접/원경 주행·정비 소리의 수급 후보. | [조사](production_gap_resources_v4.md#evocative_american_steam) · [S08](https://www.evocativesound.com/2025/12/04/american-steam-trains/) · [S09](https://www.asoundeffect.com/sound-library/american-steam-trains/) |
| `mpfb_makeclothes_workflow` — MPFB — MakeClothes 의복 제작 절차 | 기존 도구의 공식 제작 기법 / 긴 방한 외투를 찾지 못했을 때 자체 의복을 같은 몸체에 맞추는 대안. | [조사](production_gap_resources_v4.md#mpfb_makeclothes_workflow) · [S10](https://static.makehumancommunity.org/mpfb/docs/assets/creating_clothes.html) · [S11](https://static.makehumancommunity.org/about/license.html) |
| `blender_child_of_handoffs` — Blender 4.5 — Child Of 제약과 소품 인계 | 공식 기본 기능 문서 / 삽을 집고 내려놓기, 물자 건네기, 들것 손잡이와 인물의 관계를 제작할 때 참고. | [조사](production_gap_resources_v4.md#blender_child_of_handoffs) · [S12](https://docs.blender.org/manual/en/4.5/animation/constraints/relationship/child_of.html) |
| `unity_spline_train_path` — Unity Splines — 경로와 Spline Animate | 공식 엔진 패키지/예제 / 곡선 위 열차 전경·카메라 이동·선로 주변 반복 배치의 후순위 비교. | [조사](production_gap_resources_v4.md#unity_spline_train_path) · [S13](https://docs.unity3d.com/Packages/com.unity.splines@2.8/manual/index.html) · [S14](https://docs.unity3d.com/Packages/com.unity.splines@2.8/manual/animate-spline.html) |

## 5판 후보 9개

| ID / 자원 | 분야·용도 | 근거 |
|---|---|---|
| `mh_punkduck_winter_coat` — punkduck — Winter coat | CC-BY 의복 자산 / 민간인 방한 외투의 실루엣·겹쳐 입기 후보. | [조사](production_resources_v5.md#mh_punkduck_winter_coat) · [S01](http://makehumancommunity.org/clothes/winter_coat.html) · [S02](http://www.makehumancommunity.org/sites/default/files/clothes/1665/1679758305/coat.mhclo) |
| `mh_elvs_winter_scarf_oc` — Elvaerwyn — Elvs Ladies winter scarf 1 OC | CC-BY 의복 자산 / 외투 위에 두르는 민간인 목도리 후보. | [조사](production_resources_v5.md#mh_elvs_winter_scarf_oc) · [S03](http://makehumancommunity.org/clothes/elvs_ladies_winter_scarf_1_oc.html) |
| `ph_modular_industrial_pipes` — Poly Haven — Modular Industrial Pipes 01 | CC0 모듈식 3D 소품 / 기관실·난방관·정비 공간의 배관과 밸브 후보. | [조사](production_resources_v5.md#ph_modular_industrial_pipes) · [S04](https://polyhaven.com/a/modular_industrial_pipes_01) · [S06](https://polyhaven.com/license) |
| `ph_vintage_day_bed` — Poly Haven — Vintage Day Bed | CC0 생활 공간 3D 소품 / 앞칸의 낡은 안락함·임시 거주 공간을 비교할 침상 소품. | [조사](production_resources_v5.md#ph_vintage_day_bed) · [S05](https://polyhaven.com/a/vintage_day_bed) · [S06](https://polyhaven.com/license) · [S21](https://polyhaven.com/a/hospital_room_2) |
| `blender_pack_dependencies` — Blender 4.5 — Pack Resources / Linked Libraries | 기본 기능·파일 전달 절차 / 다른 에이전트·컴퓨터에서 텍스처나 링크된 파일이 누락되는 상황 예방. | [조사](production_resources_v5.md#blender_pack_dependencies) · [S07](https://docs.blender.org/manual/en/4.5/files/blend/packed_data.html) |
| `flamenco_render_dispatch` — Blender Flamenco — 자체 호스팅 렌더 작업 관리 | 오픈소스 렌더 관리 도구 / 향후 별도 GPU 컴퓨터에서 프리뷰·연기 프레임·일괄 렌더를 수행할 때 검토. | [조사](production_resources_v5.md#flamenco_render_dispatch) · [S08](https://flamenco.blender.org/about/) · [S09](https://flamenco.blender.org/) · [S10](https://flamenco.blender.org/usage/shared-storage/) |
| `ktx_texture_pipeline` — KTX-Software + KtxUnity — 텍스처 전달 경로 | 텍스처 도구·Unity 로더 묶음 / 텍스처가 많은 옷·객차·소품의 전달량과 실제 로딩 비용을 비교. | [조사](production_resources_v5.md#ktx_texture_pipeline) · [S11](https://github.com/KhronosGroup/KTX-Software) · [S12](https://github.com/KhronosGroup/KTX-Software/blob/main/LICENSE.md) · [S13](https://github.com/atteneder/KtxUnity) · [S14](https://github.com/atteneder/KtxUnity/blob/main/LICENSE.md) |
| `xatlas_uv2` — xatlas — 고유 UV 생성 라이브러리 | 오픈소스 C++ 라이브러리 / 정적 역·객차 실내 모듈의 라이트맵용 UV를 만드는 보조 후보. | [조사](production_resources_v5.md#xatlas_uv2) · [S15](https://github.com/jpcy/xatlas) · [S16](https://github.com/jpcy/xatlas/blob/master/LICENSE) |
| `unity_memory_profiler` — Unity Memory Profiler — Player 스냅샷 비교 | 공식 엔진 검수 패키지 / 열차 홈→필드→복귀 전후의 잔류 자산·누적 메모리 확인. | [조사](production_resources_v5.md#unity_memory_profiler) · [S17](https://docs.unity3d.com/Packages/com.unity.memoryprofiler@1.1/manual/index.html) · [S18](https://docs.unity3d.com/Packages/com.unity.memoryprofiler@1.1/manual/snapshot-capture.html) |

## 작품 제작자 자료 6개

참고 기법을 분석하는 문서다. 원작의 모션·음원·이미지 사용권을 주는 자산 목록이 아니다.

| 작품 | 자료 | 주의 |
|---|---|---|
| This War of Mine | [Indie Game Exposes the Intimate Horror of War](https://www.siggraph.org/news/indie-game-exposes-the-intimate-horror-of-war/) | 인물끼리 눈을 맞추거나 바람에 반응하는 행동은 인터뷰에서 더 만들고 싶다는 아쉬움이다. 구현된 기능으로 적지 않는다. 사진·캐릭터·원본 모션 사용권을 주는 자료가 아니다. |
| Frostpunk 1 / The Last Autumn | [Building a snow-free Frostpunk with RizomUV](https://11bitstudios.com/frostpunk_rizomuv/) | 특정 DLC의 제작 방식이다. 본편 모든 눈의 구현이라고 확대하지 않는다. RizomUV 구매나 우리 프로젝트의 3개 상태 고정을 요구하는 근거도 아니다. |
| Frostpunk 2 | [Frostpunk 2 – the Council splotch](https://gunzes.artstation.com/projects/kNVK9d) | 원작 효과 파일을 제공하는 에셋이 아니다. Niagara는 Unity에 그대로 들어가지 않는다. 제작자는 GIC 2025 발표 슬라이드를 공개했지만 녹화본을 찾지 못했다고 적었다. 이번에는 발표 영상을 시청했다고 주장하지 않는다. |
| Frostpunk 2 | [Game UX Case Study: Frostpunk 2 (2024)](https://www.milenamlynarska.com/uxui) | 함께 소개된 저장/로딩 화면 재설계는 제작 사정으로 구현되지 않았다고 명시돼 있다. 이를 출시판 기능으로 소개하지 않는다. Heatstamps를 우리 게임에 추가하는 근거가 아니다. |
| Metro 2033 Redux | [Metro Redux 공식 Xbox 설명서](https://dlassets-ssl.xboxlive.com/public/content/0767ea45-fabe-4f9c-8169-515713bdc97b/GameManual/972a91fd-b401-4c93-9823-2d9607ac510b/en-US/index.html) | 1인칭 장비 손동작을 사선 탑뷰에 그대로 옮기지 않는다. 방사능·필터 자원·HUD 제거를 새 규칙으로 확정하지 않는다. Last Light PC 설명서 링크는 찾았으나 이번 원문 열람이 실패해 세부 근거로 쓰지 않았다. |
| Metro Exodus | [Metro Exodus – Main menu 제작 설명](https://akrasavin.github.io/portfolio/projects/metro-exodus.html) | 메뉴 구현 설명을 실시간 이동 월드 전체의 구조로 확대하지 않는다. 원작 사물·얼굴·장면을 재사용하는 권한은 아니다. 우리 게임의 세계 계절과 원작의 4계절을 혼합하지 않는다. |

## 기존 후보 재확인 — 새 후보 수에 더하지 않음

### CMU subject 62 작업 동작 재확인
기존 항목: `cmu_focused_mocap`. 3판에서 열람하지 못한 subject 62 본문을 Exa로 읽었다. 렌치·톱질·못질·청소·상자 개폐·로프 감기 같은 작업을 확인했다. 파싱에서 번호가 선명한 62_18(상자 닫기), 62_19(상자 열기), 62_21(로프 감기)을 기록한다.

일부 표 번호가 불완전하게 반환돼 전체 번호를 복원하지 않았다. 읽은 목록에서 삽질 명칭은 확인하지 못했다. 따라서 construction이라는 분류를 화부 모션 확보로 해석하지 않는다. 실제 모션 파일·라이선스 재판정·런타임 시험은 하지 않았다.

[S15](https://mocap.cs.cmu.edu/search.php?subjectnumber=62) · [S16](https://mocap.cs.cmu.edu/)

## 도면·기관 자료 경로 — 도면 확보와 구분

### 볼슈틴 Ol49-69 차대 수리 부속 설계자료
공식 PPZ.265.4.2025 공고 본문에서 Ol49-69 차대 수리와 부속 6 OPZ(설계자료)의 존재를 확인했다. 이후 원도면을 찾아야 할 구체적인 기관·차량·공고 경로를 확보한 것이다.

실제 도면 파일·치수·스케일·사용권은 미확인. 완성 기관차 모델링용 측면/평면도를 확보한 것으로 세지 않는다. Ol49를 최종 차종으로 확정하지 않는다.

[S17](https://bip.parowozowniawolsztyn.pl/przetarg_publiczny_PPZ.265.4.2025.htm)

### Stacja Muzeum Pt31 기술 문서 색인 경로
박물관 도메인의 Pt31 기술 문서 TOM II PDF가 검색 색인에 나타났다. 차종과 원문 위치를 기록한 후속 탐색 경로다.

PDF 열람 실패로 도면·표·이미지를 검토하지 못했다. 색인의 종이 크기를 기관차 부품 치수로 쓰지 않는다. Pt31은 Pt47·Ol49와 다른 차종이고 이 자료의 재배포 권리도 미확인이다.

[S18](https://cyfrowa.stacjamuzeum.pl/storage/app/media/Zbiory/Dokumentacja%20techniczna%20parowozu%20Pt31/TOM%20II/tom-ii.pdf)

## 2판에서 제외한 항목

| 항목 | 이유 |
|---|---|
| Real Snow 1.3.2 | 공식 페이지가 Blender 4.2 LTS만 호환, 4.3 이상 Unsupported 및 지원 종료를 명시한다. Blender 4.5용 기본 후보에서 제외. 실행해서 실패를 확인했다는 뜻은 아니다. |
| purna Blender to Unity Shader Converter | 열람한 제작자 README의 Blender 요구는 5.1 이상이다. 4.5 기본 경로에서 제외. 노드별 bake-only/approximation/incompatible도 있어 모든 Blender 셰이더의 무손실 변환기로 설명하지 않는다. 라이선스 상세는 미확인. |
| 전월드 등각 스프라이트·픽셀화 자동 변환 | 사용자가 픽셀 월드를 명시적으로 제외했다. 전월드 방향별 렌더·32px 격자·팔레트 강제는 제작 기본 경로에서 제외한다. 연기 flipbook·UI 아이콘·원거리 impostor 같은 국소 사용까지 금지하는 것은 아니다. |

## 5판에서 제외한 항목

| 항목 | 이유·근거 |
|---|---|
| Blender Asset Tracer v2 — Blender 4.5 기본 경로에서 제외 | 제작자 PyPI와 공식 staging README가 Blender 5.1 이상을 요구한다. 별도 4.5 프로젝트를 자동 업그레이드하거나 v1 호환을 추정하지 않는다. v2에 관한 캐시 누락 경고도 있어 모든 의존성을 완벽하게 수집한다고 보증하지 않는다. 도구 자체의 사용 금지가 아니라 현재 설치 버전과의 불일치다. · [S19](https://pypi.org/project/blender-asset-tracer/) · [S20](https://projects.staging.blender.org/blender/blender-asset-tracer/src/branch/main/README.md) |

## 다시 만드는 법

`python ref/art/build_research_index.py --write`는 이 README, 루트 README의 표시된 목록 블록, 4·5판 보고서만 갱신한다. `--check`는 파일을 쓰지 않고 누락·목록 불일치·ID 충돌·출처·미실행 표기를 검사한다. 외부 URL에 접속하거나 Blender를 실행하지 않는다.
