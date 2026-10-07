# 애니메이션 자료 6판 — 사다리·계단·사격·부상·절단 이후

작성: 2026-10-07 · 기준 커밋: `23be388bc55be0062a6d637930ba7020bad8482c`

[전체 색인](README.md) · [구조화 목록](animation_resources_v6.json) · [5판](production_resources_v5.md)

## 범위

추가 자료 조사, README 색인 갱신, GitHub 연구 브랜치와 COS 로컬 저장. 자산 구매·패키지 다운로드·설치·Blender/Unity 실행·렌더·게임 구현·main 병합 없음.

픽셀 월드가 아닌 좀보이드식 사선 탑뷰. S1 웹 정치 검증은 유지하며 여기의 동작/상태 묶음은 후속 제작을 위한 제안이다.

## 이번에 좁힌 것

14개 신규 조사 항목은 모션 팩 10개와 접촉/레이어/메시 처리 자료 4개다. 기존 CMU의 계단 검색 결과 재확인 1건과 특정 용도에서 제외한 도구 1개는 후보 수에 더하지 않는다. 2~5판 71개와 합쳐 85개 항목이며, 확보한 모션 파일 수나 독립 공급자 수가 아니다.

사다리는 진입·상승·정지·하강·이탈을, 계단은 올라감·내려감·시작·좌우 발 정지를 구분한 실제 카탈로그를 찾았다. 사격은 전신 권총·소총·엄폐 동작과 펌프식 산탄총 후보를 분리했다.

이번에 부상자와 조력자의 짝 클립명이 있는 Combat Injured 자료를 찾았다. 단순히 두 사람 동작이라는 설명만 있던 기존 후보보다 공급 명세가 구체적이지만 실제 파일·상대 좌표·품질은 미검증이다.

절단은 처치 장면의 연기, 팔다리 상태를 바꾸는 메시/리그, 이후 이동과 보조기·의수의 세 층으로 조사했다. 기존 카메라 회피 연출을 유지하며 수술 방법이나 새 의료 규칙을 작성하지 않는다. 절뚝임을 의족 보행으로, 메시 절단기를 완성된 절단 애니메이션으로 간주하지 않는다.

## 동작별로 필요한 묶음 — 구현 제안

목록의 동작 범주와 우리 게임의 채택 결정을 구분한다. 아래는 장면을 완성하기 위한 검수 단위 제안이며 현재 구현물이 아니다.

| 동작 | 연결·검수 단위 | 남은 확인 |
|---|---|---|
| 사다리 | 접근·붙잡기·상승/하강 루프·중간 정지·방향 전환·상하단 이탈을 하나의 연결 묶음으로 명세한다. | 가로대 간격/캐릭터 키 조합, 다른 인물 점유, 사다리 도중 피격·저장·취소 |
| 계단·경사 | 평지 진입→올라감/내려감→좌우발 정지→평지 복귀를 분리하고 발 접촉을 보정한다. | 부상·짐·두 사람 부축 상태의 계단 클립은 별도 미확보 |
| 사격·장전 | 조준·발사·장전·취소·이동을 무기군별로 비교하고 캐릭터/무기/탄약 확정 이벤트를 분리한다. | 리볼버·2연발·볼트액션·한손 장전·의수 그립의 정확한 전신 클립/파일은 미확인 |
| 엄폐 | 높은/낮은 엄폐, 좌우 노출, 조준, 복귀, 장전, 피격 이탈을 비교한다. | 캐릭터 전신 동작 외에 지형·시야·AI·총구 충돌 처리가 필요 |
| 피격과 지속 부상 | 즉시 피격 반응과 이후 절뚝임/팔 감싸기/기어가기를 다른 상태로 둔다. | 공격받을 때 매번 긴 피격 클립에 갇히지 않는 중단/겹침 규칙 |
| 부축·구조 | 환자와 조력자의 paired clip을 같은 시간축·상대 좌표·소켓 계약으로 묶는다. | 들것 실제 파일명/소품 포함, 계단과 좁은 문, 취소/조력자 교체 |
| 넘어짐·기상·사망 | 넘어짐→바닥/무릎 대기→기상 또는 사망을 구분하며 래그돌과 애니메이션의 제어권을 한 번만 전환한다. | 엎드림/반듯이 누움/벽 가까이 등의 기상 클립과 전환 품질은 파일 확인 필요 |
| 절단 처치 장면 | 기존 결정대로 카메라는 자르는 부위가 아니라 얼굴·잡은 손·관찰자로 향한다. 환자/조력자 자세·붕대 상태·장면 종료를 준비하는 연출 자료로 쓴다. | 카메라 회피용 짝 연기·정확한 클립은 미확보. 구조/응급처치 팩을 수술 애니메이션 팩으로 부르지 않음 |
| 팔다리 상실 표현 | 초기 비교안은 공통 골격을 유지한 사전 분할 외형·단면 덮개·붕대/의수 상태다. 리깅·의복·장비 소켓·저장된 부위 상태를 함께 관리한다. | 실시간 절단 알고리즘은 의복/스킨드 메시 실패 위험이 크며 기본 채택하지 않음 |
| 절단 이후·의수/의족 | 초기 부상, 보조기구 사용, 적응한 의수/의족 동작을 같은 영구 통증 모션으로 묶지 않는다. 기능과 작업 역할에 맞는 동작을 검수한다. | 의족 전용 보행·한손 사다리·의수 장전/삽질·부위별 생활 동작의 검증된 완성 팩은 찾지 못함 |

<a id="mco_ladder"></a>
## 1. MoCap Online — LADDER

**[WATCH] / 유료 사다리 모션 팩**

기존 MoCap Online Crowd와 다른 사다리 동작 팩. MoCap Central과는 다른 업체.

**우리 용도:** 역 설비·객차 접근 사다리의 진입, 오르내리기, 정지, 방향 전환, 이탈.

**출처 확인:** 공식 카탈로그가 상단/하단 진입·이탈, 상승/하강 루프와 정지, 방향 전환을 나눈다. 12inch·230mm·400mm 간격용 프리셋을 제시한다.

**적용 제안:** 접근→붙잡기→상승/하강→정지→상단/하단 이탈을 연결할 조달 후보. 가로대 간격은 실제 사다리 모델에 맞춰 비교한다.

**형식·호환:** 엔진/FBX/Blender 등 상품 형식을 선택하는 구조다. 정확한 구매 옵션·파일과 우리 리그 호환은 미확인.

**권리:** 자체 유료 약관. 원본 공개 배포 불가. 업체 약관은 AI Applications와 관련한 사용에 사전 서면 허가를 요구한다.

**파일·AI 처리:** 일반 모션 비교는 가능하나 원본의 에이전트 입력/처리는 허가 범위 확인 전 [BLOCKED]. 학습만 금지하는 조항으로 축소하지 않는다.

**한계:** 카탈로그의 간격 명칭을 법정 규격으로 인용하지 않는다. 애니메이션 팩을 완성 사다리 컨트롤러로 보지 않는다. 중간 저장·막힌 출구·동료 점유 처리는 별도다.

**후속 검증:** 가로대 간격과 키가 다른 인물에서 손발 접촉, 최상단 이탈, 중간 방향 전환·취소를 시험한다.

대표 이름만 기록했다. 원본 모션 파일을 취득·재생한 것이 아니며, 구형 카탈로그는 현행 상품과 별도 대조가 필요하다.

| 카탈로그의 정확한 이름 | 용도 | 증거 수준 |
|---|---|---|
| `LDR_O12_Std_Rlx_To_Ascd_LU` | 서 있는 자세에서 상승 진입 | 공식 목록 · [S01](https://mocaponline.com/products/ladder) |
| `LDR_O12_Ascd_LU_Loop` | 상승 반복 | 공식 목록 · [S01](https://mocaponline.com/products/ladder) |
| `LDR_O12_Ascd_LU_Stop` | 상승 정지 | 공식 목록 · [S01](https://mocaponline.com/products/ladder) |
| `LDR_O12_Ascd_To_Dscd_LU_Start` | 상승에서 하강으로 전환 | 공식 목록 · [S01](https://mocaponline.com/products/ladder) |
| `LDR_O12_Dscd_LU_Loop` | 하강 반복 | 공식 목록 · [S01](https://mocaponline.com/products/ladder) |
| `LDR_O12_Ascd_LU_To_Std_Rlx` | 상승에서 서 있는 자세로 이탈 | 공식 목록 · [S01](https://mocaponline.com/products/ladder) |

근거: [S01](https://mocaponline.com/products/ladder) · [S02](https://mocaponline.com/pages/standard-license)

<a id="motionbeats_stairs_slopes"></a>
## 2. Motionbeats — Action Adventure Stairs and Slope

**[WATCH] / 유료 계단·경사 전신 모션**

기존 평지 보행·부상 보행과 구분되는 새 공급 후보.

**우리 용도:** 역 계단·승강장 단차·경사로에서 올라감/내려감과 시작/정지/회전.

**출처 확인:** UE4/UE5 스켈레톤, FBX, root motion과 in-place를 명시한다. 공식 목록에 좌우 발 정지·피벗·완만/급경사 변형이 있다.

**적용 제안:** 평지 보행 속도만 바꾸는 대신 계단용 동작과 접촉 보정을 비교한다. 정상·부상 상태를 무조건 같은 보폭으로 재생하지 않는다.

**형식·호환:** FBX 제공 명시. 애니메이션만이며 Blueprint 컨트롤러는 제공하지 않는다고 적혀 있다.

**권리:** Fab 상품의 선택 라이선스 확인 필요. 무료/CC0로 분류하지 않고 원본 공개 저장은 하지 않는다.

**파일·AI 처리:** 상품의 Allows usage with AI는 No. 플랫폼 태그와 구매 조항을 대조하며 원본 외부 입력을 허용으로 단정하지 않는다.

**한계:** 패키지 수량에는 스켈레톤/루트모션 변형이 섞일 수 있다. 서로 다른 파일 수를 고유 동작 수로 합산하지 않는다. 실제 계단 높이·발판 깊이와의 일치는 미검증.

**후속 검증:** 서로 다른 단차에서 발 접지·골반 높이·좌우 정지발·진입/마지막 계단을 대조하고 엔진 이동과 root motion 중복을 검사한다.

대표 이름만 기록했다. 원본 모션 파일을 취득·재생한 것이 아니며, 구형 카탈로그는 현행 상품과 별도 대조가 필요하다.

| 카탈로그의 정확한 이름 | 용도 | 증거 수준 |
|---|---|---|
| `walk_up_stairs_start` | 계단 상승 시작 | 공식 목록 · [S03](https://www.fab.com/listings/56775370-29a2-483e-ba90-cabac9ab92e4?lang=en) |
| `walk_up_stairs_root` | 상승 root 변형 | 공식 목록 · [S03](https://www.fab.com/listings/56775370-29a2-483e-ba90-cabac9ab92e4?lang=en) |
| `walk_up_stairs_stop_LF` | 왼발 정지 변형 | 공식 목록 · [S03](https://www.fab.com/listings/56775370-29a2-483e-ba90-cabac9ab92e4?lang=en) |
| `walk_up_stairs_stop_RF` | 오른발 정지 변형 | 공식 목록 · [S03](https://www.fab.com/listings/56775370-29a2-483e-ba90-cabac9ab92e4?lang=en) |
| `walk_down_stairs_start` | 계단 하강 시작 | 공식 목록 · [S03](https://www.fab.com/listings/56775370-29a2-483e-ba90-cabac9ab92e4?lang=en) |
| `walk_down_stairs_root` | 하강 root 변형 | 공식 목록 · [S03](https://www.fab.com/listings/56775370-29a2-483e-ba90-cabac9ab92e4?lang=en) |

근거: [S03](https://www.fab.com/listings/56775370-29a2-483e-ba90-cabac9ab92e4?lang=en) · [S12](https://www.fab.com/eula)

<a id="kaykit_character_animations"></a>
## 3. KayKit — Character Animations

**[WATCH] / 무료 CC0 전신 애니메이션**

Quaternius/Mixamo 외에 비교할 새 라이브러리.

**우리 용도:** 이동·기어가기·웅크리기·피격·사망과 한손/양손 원거리·활·도구 동작의 저비용 기반.

**출처 확인:** 제작자는 무료 FBX/glTF와 CC0를 명시하고 유료 .blend Source를 구분한다. 범주에 조준·발사·재장전·피격·사망·이동·도구 동작이 있다.

**적용 제안:** 초기 공통 동작의 기준 후보로 비교하되 몸체나 화풍까지 KayKit의 비례로 바꾸지 않는다.

**형식·호환:** FBX/glTF 무료 제공, 편집용 .blend는 별도 Source 등급. Rig_Medium/Large의 제공 범위는 같지 않다.

**권리:** CC0 Universal 표기. 전체 원본을 취득한 것은 아니고 출처는 연구 장부에 유지한다.

**파일·AI 처리:** CC0에 근거 없는 포괄 AI 금지를 덧붙이지 않는다. 외부 서비스의 전송/보관 조건은 별도로 확인한다.

**한계:** 스타일화된 움직임이 지친 민간인에게 맞는지는 미검증. 페이지의 Swimming/Climbing은 추가 예정이므로 현재 사다리 모션 확보로 세지 않는다. 개별 클립명은 미확인.

**후속 검증:** 작은 공통 리그에 조준·피격·기어가기·작업 대표 클립을 옮겨 보폭·손 접촉·과장 정도를 확인한다.

**클립 식별자:** 개별 이름을 확인하지 않은 후보 또는 모션 파일이 아닌 기법이다. 이름을 추측해 채우지 않았다.

근거: [S04](https://kaylousberg.itch.io/kaykit-character-animations)

<a id="kubold_rifle_animset"></a>
## 4. Kubold — Rifle Animset Pro

**[WATCH] / 유료 전신 소총 모션**

범용 라이브러리에서 소총 전신 동작으로 구체화한 새 후보.

**우리 용도:** 조준·발사·재장전·이동과 방향별 피격·사망의 연결.

**출처 확인:** 현재 상품 설명과 공식 구형 클립 카탈로그를 각각 읽었다. 구형 목록은 단발·연속 사격·additive 발사·재장전·방향별 피격/사망을 구분한다.

**적용 제안:** 실제 총 모델이 아닌 일반 소총 소켓을 기준으로 전신 자세·손 접촉·상하체 합성을 비교한다.

**형식·호환:** 공식 downloads의 기존 Unity 카탈로그 URL은 v1.2지만 문서 표제는 v1.1이다. 아래 이름을 현행 Fab 파일의 검증된 이름으로 승격하지 않는다.

**권리:** 제작자 FAQ는 구워진 게임 배포와 원본 재배포를 구분한다. 선택 판매처/라이선스를 확인하며 공개 저장소에 모션 원본을 넣지 않는다.

**파일·AI 처리:** 조회한 상품의 AI 사용 표시는 No. 해당 구매 조건과 외부 입력 권한을 별도 확인한다.

**한계:** Shotgun/Crossbow 태그만으로 펌프·2연발·석궁 전용 장전이 있다고 보지 않는다. 애니메이션과 컨트롤러는 별개며 오래된 데모 스크립트를 기본 채택하지 않는다.

**후속 검증:** 고른 현행 포맷의 실제 클립명을 대조하고 조준 방향·이동·발사 이벤트·피격 중단·리그 변환을 시험한다.

대표 이름만 기록했다. 원본 모션 파일을 취득·재생한 것이 아니며, 구형 카탈로그는 현행 상품과 별도 대조가 필요하다.

| 카탈로그의 정확한 이름 | 용도 | 증거 수준 |
|---|---|---|
| `Rifle_ShootOnce` | 단발 | 기존 버전 목록 · [S06](https://www.kubold.com/s/RifleAnimsetPro_v12_ListOfAnimations.html) |
| `Rifle_ShootLoop_Additive` | 사격 additive 레이어 | 기존 버전 목록 · [S06](https://www.kubold.com/s/RifleAnimsetPro_v12_ListOfAnimations.html) |
| `Rifle_Reload_2` | 재장전 변형 | 기존 버전 목록 · [S06](https://www.kubold.com/s/RifleAnimsetPro_v12_ListOfAnimations.html) |
| `Rifle_Hit_L_1` | 방향별 피격 | 기존 버전 목록 · [S06](https://www.kubold.com/s/RifleAnimsetPro_v12_ListOfAnimations.html) |
| `Rifle_Death_L` | 방향별 사망 | 기존 버전 목록 · [S06](https://www.kubold.com/s/RifleAnimsetPro_v12_ListOfAnimations.html) |

근거: [S05](https://www.fab.com/listings/e0eed5c5-54a6-41cc-bfa9-62b26c309bca?lang=en) · [S06](https://www.kubold.com/s/RifleAnimsetPro_v12_ListOfAnimations.html) · [S11](https://www.kubold.com/faq-unity) · [S12](https://www.fab.com/eula)

<a id="kubold_pistol_animset"></a>
## 5. Kubold — Pistol Animset Pro

**[WATCH] / 유료 전신 권총 모션**

소총과 손·팔 자세가 다른 권총의 별도 후보.

**우리 용도:** 권총 조준·이동·발사·재장전·피격을 비교.

**출처 확인:** 현재 상품은 전신 권총 동작과 FBX 원본 제공을 설명한다. 공식 기존 카탈로그에서 발사·재장전·이동·방향별 피격 이름을 확인했다.

**적용 제안:** S2 권총 후보에 먼저 비교한다. 탭 사격을 FPS 조작으로 바꾸지 않고 조준 표시와 전신 동작을 맞춘다.

**형식·호환:** 상품의 FBX 제공 설명 확인. 아래 구형 카탈로그의 이름과 현행 구매 파일 일치는 미검증.

**권리:** Kubold FAQ와 실제 선택한 판매처 EULA를 함께 확인. 무료/CC0 아님, 모션 원본 공개 재배포 불가.

**파일·AI 처리:** 상품의 AI 사용 표시 No를 기록하고 실제 조항/입력 권한을 확인한다.

**한계:** 게임의 한손 권총+손전등, 한쪽 팔 상실, 리볼버 전용 장전까지 이 팩이 보장하는 것은 아니다. 다른 손의 존재가 필요 없는 모션인지 따로 봐야 한다.

**후속 검증:** 한손/양손 그립, 손전등, 장전 취소, 탄약 확정 시점과 실제 폰의 조준 가독성을 검사한다.

대표 이름만 기록했다. 원본 모션 파일을 취득·재생한 것이 아니며, 구형 카탈로그는 현행 상품과 별도 대조가 필요하다.

| 카탈로그의 정확한 이름 | 용도 | 증거 수준 |
|---|---|---|
| `Pistol_ShootOnce` | 권총 발사 | 기존 버전 목록 · [S08](https://www.kubold.com/s/PistolAnimsetPro_AnimationsDescriptions.html) |
| `Pistol_Reload_2` | 권총 재장전 변형 | 기존 버전 목록 · [S08](https://www.kubold.com/s/PistolAnimsetPro_AnimationsDescriptions.html) |
| `Pistol_Hit_L_1` | 권총 자세 피격 | 기존 버전 목록 · [S08](https://www.kubold.com/s/PistolAnimsetPro_AnimationsDescriptions.html) |
| `Pistol_RunFwdLoop` | 무장 전진 이동 | 기존 버전 목록 · [S08](https://www.kubold.com/s/PistolAnimsetPro_AnimationsDescriptions.html) |

근거: [S07](https://www.fab.com/listings/c5caff8c-6815-4e81-b825-aeb95967411e?lang=en) · [S08](https://www.kubold.com/s/PistolAnimsetPro_AnimationsDescriptions.html) · [S11](https://www.kubold.com/faq-unity) · [S12](https://www.fab.com/eula) · [S24](https://github.com/wndi1130-dot/APP/blob/23be388bc55be0062a6d637930ba7020bad8482c/docs/design/briefs/weapons.md)

<a id="kubold_cover_rifle"></a>
## 6. Kubold — Cover Rifle Animset Pro

**[WATCH] / 유료 높은/낮은 엄폐 모션**

기본 사격과 다른 엄폐 진입/이탈·내밀어 조준하기의 연결 후보.

**우리 용도:** 역 기둥·상자·객차 옆에서 엄폐 진입, 노출 사격, 복귀, 재장전.

**출처 확인:** 공식 UE4 카탈로그 PDF 세 쪽에서 높은/낮은 엄폐와 좌우 조준/전환/장전 동작을 확인했다. 상품은 움직이는 클립과 조준 포즈를 구분한다.

**적용 제안:** 좁은 전투 장소의 시야/충돌 규칙과 동작을 분리해 비교한다. 벽을 관통하지 않는 총구 위치가 핵심이다.

**형식·호환:** 열람한 것은 기존 UE4 목록. 현재 Fab는 Unreal 형식이 보여 실제 FBX 전달/추출 경로와 비용을 구매 전에 확인한다.

**권리:** Kubold FAQ/판매처 라이선스 적용. 원본 공개 배포 허가로 해석하지 않는다.

**파일·AI 처리:** 상품의 AI 사용 표시 No. 구매 조건·외부 입력 범위 확인 전 원본 전송 안 함.

**한계:** 엄폐를 선택하고 움직이는 AI·지형 분석 시스템이 아니다. 조준 포즈 개수와 연속 모션 개수를 합쳐 고유 모션 수로 홍보하지 않는다.

**후속 검증:** 낮은/높은 엄폐 높이·좌우 모서리·총구·카메라 가림·피격 중단을 대조한다.

대표 이름만 기록했다. 원본 모션 파일을 취득·재생한 것이 아니며, 구형 카탈로그는 현행 상품과 별도 대조가 필요하다.

| 카탈로그의 정확한 이름 | 용도 | 증거 수준 |
|---|---|---|
| `CoverHi_Idle2CoverR` | 오른쪽 높은 엄폐 진입 | 기존 PDF 목록·쪽 이미지 확인 · [S10](https://www.kubold.com/s/CoverRifleAnimsetPro_UE4_list.pdf) |
| `CoverHi_CoverR2AimR` | 높은 엄폐에서 오른쪽 조준 | 기존 PDF 목록·쪽 이미지 확인 · [S10](https://www.kubold.com/s/CoverRifleAnimsetPro_UE4_list.pdf) |
| `CoverHi_ReloadR` | 높은 엄폐 재장전 | 기존 PDF 목록·쪽 이미지 확인 · [S10](https://www.kubold.com/s/CoverRifleAnimsetPro_UE4_list.pdf) |
| `CoverLo_ReloadR` | 낮은 엄폐 재장전 | 기존 PDF 목록·쪽 이미지 확인 · [S10](https://www.kubold.com/s/CoverRifleAnimsetPro_UE4_list.pdf) |

근거: [S09](https://www.fab.com/listings/f9e9fbcb-0f07-49a0-8c06-80b18eba0e90) · [S10](https://www.kubold.com/s/CoverRifleAnimsetPro_UE4_list.pdf) · [S11](https://www.kubold.com/faq-unity) · [S12](https://www.fab.com/eula)

<a id="kaidoom_pump_shotgun"></a>
## 7. KaidoomDev — Pump-Action shotgun Character Animation Pack

**[WATCH] / 산탄총 캐릭터/무기 모션 후보**

소총 상품의 shotgun 태그가 아닌 실제 펌프식 산탄총 설명을 가진 새 후보.

**우리 용도:** 산탄총 캐릭터 동작과 무기 작동·부분 재장전의 시각적 연결.

**출처 확인:** 제작자는 1/3인칭 사용, 남은 탄과 재고에 따른 장전 조합 데모, 애니메이션 가능한 산탄총 리그를 설명한다.

**적용 제안:** 무기 쪽 작동과 사람 손의 접촉 시점을 따로 가진 납품물을 비교한다. 기본 소총 동작 하나로 전 무기 장전을 때우지 않는다.

**형식·호환:** Unreal Engine 형식만 확인. 직접 FBX·전체 몸 리그·Unity 가져오기는 미확인.

**권리:** Fab 선택 라이선스 확인 필요. 상용 게임 사용과 원본 팩 재배포는 다르며 원본은 이번 저장물에서 제외한다.

**파일·AI 처리:** 상품의 Allows usage with AI는 Yes지만 특정 서비스 전송/재배포 전부 허용을 뜻한다고 확대하지 않는다.

**한계:** 클립명과 정확한 루프/취소 범위는 미확인. 두 연발·볼트액션·리볼버를 해결하는 팩이 아니다. 예제 총기 이름/형태를 세계관에 자동 채택하지 않는다.

**후속 검증:** 실제 파일명·손/무기 리그·장전 중단·탄약 시각 표시·좁은 엄폐에서의 간섭을 검수한다.

**클립 식별자:** 개별 이름을 확인하지 않은 후보 또는 모션 파일이 아닌 기법이다. 이름을 추측해 채우지 않았다.

근거: [S25](https://www.fab.com/listings/4f89da93-387c-4251-9646-6f2a973e682a) · [S12](https://www.fab.com/eula) · [S24](https://github.com/wndi1130-dot/APP/blob/23be388bc55be0062a6d637930ba7020bad8482c/docs/design/briefs/weapons.md)

<a id="ailive_injury"></a>
## 8. Ailive — Injury Animation Pack

**[WATCH] / 부상 보행·목발 전신 모션**

CMU 부상 보행에 더해 실제 FBX와 목발/팔 부상을 명시한 새 후보.

**우리 용도:** 다친 다리, 다친 팔, 목발 보행 상태를 분리해 비교.

**출처 확인:** 제작자는 UE5 Manny 기반 전신 모캡과 손가락, FBX를 설명한다. 목록에 오른발 부상·왼팔 부상·목발 두 변형·느린 보행이 있다.

**적용 제안:** 피격 순간의 움찔함과 이후 계속되는 부상 이동을 다른 클립으로 다룬다.

**형식·호환:** FBX 표시. 목발 소품의 포함 여부·접촉 리그·체형 호환은 미확인.

**권리:** 상품 설명의 Use freely를 가격 무료나 CC0로 해석하지 않는다. Fab 실제 취득 조건을 확인한다.

**파일·AI 처리:** 상품은 Allows usage with AI No, Generated with AI No다. 제작자의 별도 AI 서비스와 해당 파일 제작방식을 혼동하지 않는다.

**한계:** 부상자가 다리를 절뚝이는 동작이지 의족 사용자나 다리 절단 후의 보행 고증 데이터가 아니다. 통증 행동을 모든 장애인의 기본 자세로 고정하지 않는다.

**후속 검증:** 목발 접지·발 위치·옷 관통과 정상/부상 전환을 시험하고 좌우를 뒤집을 때 장비 배치가 맞는지 확인한다.

대표 이름만 기록했다. 원본 모션 파일을 취득·재생한 것이 아니며, 구형 카탈로그는 현행 상품과 별도 대조가 필요하다.

| 카탈로그의 정확한 이름 | 용도 | 증거 수준 |
|---|---|---|
| `Injured_Right_Foot_Walk` | 오른발 부상 보행 | 공식 목록 · [S13](https://www.fab.com/listings/fb337e07-d758-4423-a0e3-a17a9610b1f6) |
| `Limping_with_Crutches` | 목발 보행 | 공식 목록 · [S13](https://www.fab.com/listings/fb337e07-d758-4423-a0e3-a17a9610b1f6) |
| `Walking_with_Injured_Left_Arm` | 왼팔 부상 보행 | 공식 목록 · [S13](https://www.fab.com/listings/fb337e07-d758-4423-a0e3-a17a9610b1f6) |

근거: [S13](https://www.fab.com/listings/fb337e07-d758-4423-a0e3-a17a9610b1f6) · [S12](https://www.fab.com/eula)

<a id="raise_combat_injured"></a>
## 9. Raise Creation — Combat Injured Animation Pack

**[WATCH] / 지속 부상 상태·구조 짝동작**

Reallusion 구조 후보와 별개로 조력자 짝 클립명까지 공개된 새 후보.

**우리 용도:** 다리 끌기, 무릎/바닥 자세 전환, 부축 진입·걷기·이탈을 연결.

**출처 확인:** 공식 목록에 피해자/조력자의 Rescue_Walk와 Rescue_Walk_Help, 진입/이탈 대응 이름이 있다. FBX 제공과 두 사람 Rescue 묶음을 명시한다.

**적용 제안:** 부축을 부상자 한 사람의 동작으로 끝내지 않고 조력자와 소품/충돌을 같은 장면 상태로 묶는 후보.

**형식·호환:** Unreal 및 FBX 표기. 실제 파일의 root 좌표·스케일·리그·프레임 수는 미검증.

**권리:** Fab 선택 라이선스 확인 필요. 원본 패키지 공유가 아니라 문서/대표 클립 식별자만 저장한다.

**파일·AI 처리:** 상품의 Allows usage with AI는 Yes, Generated with AI No. 해당 표시를 저작권 포기/무제한 재배포로 확대하지 않는다.

**한계:** 제작자는 순간 피격보다 부상 행동/이동용이라고 구분한다. Rescue 설명의 Value X = 45는 단위/축 기준을 확인하기 전 cm 또는 우리 게임 좌표로 전용하지 않는다. 팩의 전투 범주는 주먹/발 동작이며 부상 사격 완성품이 아니다.

**후속 검증:** 피해자/조력자 짝의 정확한 프레임 대응·키 차이·문 통과·부축 취소/조력자 교체·저장 복귀를 시험한다.

대표 이름만 기록했다. 원본 모션 파일을 취득·재생한 것이 아니며, 구형 카탈로그는 현행 상품과 별도 대조가 필요하다.

| 카탈로그의 정확한 이름 | 용도 | 증거 수준 |
|---|---|---|
| `AS_CI_Walk_Drag_Leg` | 다리를 끄는 부상 이동 | 공식 목록 · [S26](https://www.fab.com/listings/1e54821b-c2e3-48ed-b26e-52bd24d5c20c) |
| `AS_CI_Stand_to_Knee` | 서기→무릎 자세 | 공식 목록 · [S26](https://www.fab.com/listings/1e54821b-c2e3-48ed-b26e-52bd24d5c20c) |
| `AS_CI_Rescue_Walk` | 부상자의 부축 보행 | 공식 목록 · [S26](https://www.fab.com/listings/1e54821b-c2e3-48ed-b26e-52bd24d5c20c) |
| `AS_CI_Rescue_Walk_Help` | 조력자 짝 보행 | 공식 목록 · [S26](https://www.fab.com/listings/1e54821b-c2e3-48ed-b26e-52bd24d5c20c) |
| `AS_CI_Rescue_To_Help` | 조력자 부축 진입 | 공식 목록 · [S26](https://www.fab.com/listings/1e54821b-c2e3-48ed-b26e-52bd24d5c20c) |
| `AS_CI_Rescue_Out_Help` | 조력자 부축 이탈 | 공식 목록 · [S26](https://www.fab.com/listings/1e54821b-c2e3-48ed-b26e-52bd24d5c20c) |

근거: [S26](https://www.fab.com/listings/1e54821b-c2e3-48ed-b26e-52bd24d5c20c) · [S12](https://www.fab.com/eula)

<a id="ochi_mobility_animations"></a>
## 10. Studio Ochi — Low Poly Disabled People Animated & Rigged

**[WATCH] / 보조기구·휠체어 인물 애니메이션**

절뚝임뿐 아니라 보조기구를 사용하는 인물의 별도 자료.

**우리 용도:** 지팡이·목발·보행기·휠체어와 몸의 접촉을 살펴볼 후보.

**출처 확인:** 제작자 설명에 도구별 애니메이션과 휴식 자세, FBX/GLB 및 애니메이션별 Blend가 언급된다. 제목의 Animated판을 정적 Posed판과 구분했다.

**적용 제안:** 장애 이후의 생활 동작과 장비 소켓을 분석하는 보조 자료. 전 인물을 같은 통증/무력한 자세로 만들지 않는다.

**형식·호환:** 설명은 FBX/GLB/Blend를 말하지만 Fab의 포함 형식 표시는 GLB 중심이다. 실제 판매 포맷은 취득 전에 문의/확인해야 한다.

**권리:** 판매처의 선택 라이선스 확인 필요. 원본/수정 자산의 독립 배포를 허용으로 보지 않는다.

**파일·AI 처리:** 실제 라이선스와 입력 서비스 조건 확인 전 원본 클라우드 전송은 하지 않는다.

**한계:** 토이 비례·현대 장비가 최종 화풍과 맞는지는 별도다. 전문 의족 보행·절단 부위별 동작·의수 조작을 제공한다는 근거는 아니다.

**후속 검증:** 애니메이션판의 실제 파일과 도구 포함 여부를 확인하고 바닥/좌석/손잡이 접촉과 캐릭터 교체 가능성을 점검한다.

**클립 식별자:** 개별 이름을 확인하지 않은 후보 또는 모션 파일이 아닌 기법이다. 이름을 추측해 채우지 않았다.

근거: [S14](https://www.fab.com/listings/d07f9075-f2dd-477e-a6de-bfb3cdd5d14a) · [S12](https://www.fab.com/eula)

<a id="ik_footplacement"></a>
## 11. IKFootPlacement — plonkabartosz

**[WATCH] / MIT 발 접촉 보정 예제**

기존 Unity Animation Rigging 후보의 계단 접촉 보정 사례 구체화.

**우리 용도:** 계단/경사에서 발의 위치와 방향을 맞추는 구현 참고.

**출처 확인:** 제작자 README는 Two Bone IK Constraint, raycast와 IAnimationJob을 설명하며 Humanoid 전용이 아니라고 명시한다. Unity/Animation Rigging의 구형 기준 버전과 IK control baking을 안내한다.

**적용 제안:** 보행 클립을 먼저 정한 뒤 가까운 캐릭터의 접촉 오차를 줄이는 후보로 비교한다.

**형식·호환:** Unity C# 소스. Blender 애드온이나 계단 오르기 모션 팩이 아니다. 현행 프로젝트 버전에서 미검증.

**권리:** MIT 표시. 취득 버전 고지와 포함 자산별 조건을 보존한다.

**파일·AI 처리:** MIT 코드의 권리와 외부 모션 입력물의 권리는 별개. 이번 실행/원본 입력은 없다.

**한계:** 발 IK 하나가 골반·보폭·경로 충돌·노년/부상 동작을 자동 완성하지 않는다. 계단 모션·부모 이동·IK가 같은 위치를 중복 제어하지 않게 해야 한다.

**후속 검증:** 발판 가장자리·다양한 단차·시작/멈춤·멀리 있는 NPC의 보정 생략을 비교한다.

**클립 식별자:** 개별 이름을 확인하지 않은 후보 또는 모션 파일이 아닌 기법이다. 이름을 추측해 채우지 않았다.

근거: [S15](https://github.com/plonkabartosz/IKFootPlacement)

<a id="limbhacker"></a>
## 12. LimbHacker — JoeCooper

**[WATCH] / MIT 스킨드 메시 분리 연구 예제**

애니메이션이 아닌 팔다리 상태 표현의 기술적 참고.

**우리 용도:** 스킨드 메시·여러 렌더러·분리 뒤 래그돌 연결의 문제를 조사.

**출처 확인:** 제작자는 스킨드 캐릭터 분리 기능을 설명하지만 알고리즘 문제 때문에 상용 판매를 중단했다고 경고한다. 닫힌 솔리드 메시 가정과 여러 겹/겹치는 기하의 문제를 설명한다.

**적용 제안:** 완제품 추천보다 실패 모드 참고로 둔다. 이 게임의 초기 후보는 미리 분리 가능한 외형·단면 덮개·붕대/의수 상태와 공통 골격 유지 방식이다.

**형식·호환:** Unity C# 소스. 수술/절단 연기 모션이나 Blender용 자동 제작기가 아니다.

**권리:** MIT 표시. 소스 고지 보존; 예제 캐릭터/외부 입력 자산은 따로 확인.

**파일·AI 처리:** 오픈소스라는 이유로 입력 캐릭터·유료 의복 라이선스가 사라지지 않는다.

**한계:** 겹쳐 입은 겨울옷·열린 메시·본 영향·물리 관절·손에 든 소품·저장을 통합 해결하지 않는다. 사용자의 카메라 회피 연출을 실시간 고어 절단 의무로 바꾸지 않는다.

**후속 검증:** 별도 제작 승인 뒤 허용된 단순 캐릭터에서 기하 실패·본/소켓 유지·의복 중첩을 비교하고, 사전 분할 방식보다 실익이 있는지 판단한다.

**클립 식별자:** 개별 이름을 확인하지 않은 후보 또는 모션 파일이 아닌 기법이다. 이름을 추측해 채우지 않았다.

근거: [S16](https://github.com/JoeCooper/LimbHacker) · [S23](https://github.com/wndi1130-dot/APP/blob/23be388bc55be0062a6d637930ba7020bad8482c/docs/design/briefs/field_system.md)

<a id="unity_animation_layers_masks"></a>
## 13. Unity — Animation Layers / Avatar Mask

**[WATCH] / 공식 동작 합성 기능**

기존 리타기팅·IK와 다른 상하체 동작 합성/적용 범위.

**우리 용도:** 다친 하체 이동과 상체 조준·재장전의 적용 범위를 나누는 후보.

**출처 확인:** Avatar Mask는 신체 또는 Transform별 애니메이션 적용과 손발 IK 곡선을 고를 수 있다. 기본 리타기팅의 Humanoid 조건도 별도 공식 문서로 확인했다.

**적용 제안:** 정상 이동, 부상 이동, 상체 동작, 짧은 반응의 책임을 나누고 상황별 중단 우선순위를 명세한다.

**형식·호환:** Unity 공식 기능 문서. 구현과 캐릭터별 mask/레이어 자산은 아직 없다.

**권리:** Unity 이용 조건 적용. 문서 기법과 외부 모션의 권리는 분리한다.

**파일·AI 처리:** 자작 컨트롤러와 라이선스 제한 모션을 구분한다. 이번 엔진 코드를 만들거나 유료 클립을 넣지 않았다.

**한계:** Mask는 모션 영향 범위이지 메시를 자르는 기능이 아니다. 없는 팔의 뼈를 삭제하거나 scale=0으로 만들기만 하면 Humanoid 매핑/소켓/물리가 깨질 수 있으므로 초기 기본안으로 고정하지 않는다. 부상 사격의 품질은 합성 시험 대상이다.

**후속 검증:** 걷기+조준+피격+장전 중단의 조합, 필요한 본 유지, 손전등/무기 소켓, 부상 상태 전환과 저장 복귀를 검사한다.

**클립 식별자:** 개별 이름을 확인하지 않은 후보 또는 모션 파일이 아닌 기법이다. 이름을 추측해 채우지 않았다.

근거: [S18](https://docs.unity3d.com/6000.0/Documentation/Manual/class-AvatarMask.html) · [S20](https://docs.unity3d.com/6000.0/Documentation/Manual/Retargeting.html)

<a id="unity_target_matching"></a>
## 14. Unity — Animator.MatchTarget

**[WATCH] / 공식 진입·접촉 위치 보정 API**

발 IK·소품 부모 전환과 구분되는 클립 구간의 목표 정렬 기법.

**우리 용도:** 사다리 첫 발판·문턱·소품에 몸의 기준점이 닿도록 진입 동작을 정렬.

**출처 확인:** API는 지정된 클립 진행 구간에 AvatarTarget이 목표에 도달하도록 객체 위치/회전을 조정한다. base layer만, 한 번에 한 target, applyRootMotion 필요라는 제약을 명시한다.

**적용 제안:** 동작별 align/commit/release 시점을 명세하고 IK·엔진 이동·target matching이 같은 root를 경쟁하지 않게 비교한다.

**형식·호환:** Unity 6.0 공식 API. 모든 엔진의 범용 Motion Warping이나 완성 컨트롤러라고 부르지 않는다.

**권리:** Unity 문서/엔진 이용 조건 적용. 입력 애니메이션 권리는 별도다.

**파일·AI 처리:** 이번에는 공식 문서만 읽었으며 실행/원본 모션 입력은 하지 않았다.

**한계:** 양손·양발 여러 접촉을 한 API 호출로 동시에 해결하지 않는다. 루프 중 과거 시작 시점을 주면 다음 루프로 넘어가는 특성에 유의한다.

**후속 검증:** 낮은 사다리 진입·상단 이탈에서 root 소유권, 클립 구간, 중단 시 순간이동, 점유된 출구를 검수한다.

**클립 식별자:** 개별 이름을 확인하지 않은 후보 또는 모션 파일이 아닌 기법이다. 이름을 추측해 채우지 않았다.

근거: [S19](https://docs.unity3d.com/6000.0/Documentation/ScriptReference/Animator.MatchTarget.html)

## 기존 후보 재확인 — 신규 수에 포함하지 않음

### CMU 계단 모션 경로
기존 ID: `cmu_focused_mocap`

공식 도메인 검색 색인에서 subject 143의 143_17 Walk Up Stairs And Over를 확인했다. 기존 CMU 공급처의 새 탐색 경로이며 독립 라이브러리로 세지 않는다.

143·113 상세 본문은 web와 Exa에서 열리지 않았다. 색인만으로 양방향 계단·장비 상태·파일 형식을 검증하지 않는다. 본문이 불완전한 다른 subject 번호를 추측하지 않았다. 홈페이지는 상업 제품 포함을 허용하되 데이터 재판매를 금지하며 손가락을 실제 캡처하지 않았다고 설명한다.

[S21](https://mocap.cs.cmu.edu/search.php?subjectnumber=143) · [S22](https://mocap.cs.cmu.edu/)

## 특정 용도에서 제외

### [BLOCKED] EzySlice를 완성 캐릭터 절단/의수 시스템으로 사용하는 안

제작자 README의 범위는 평면에 의한 convex mesh slicing이다. 스킨드 메시 가중치·옷·본·소켓·래그돌·절단 이후 동작을 해결한다고 명시하지 않는다. 정적 소품 절단에 쓸 가능성까지 부정하는 것이 아니라 이번 캐릭터 절단 기본안에서 제외한다.

[S17](https://github.com/DavidArayan/ezy-slice)

## 절단·부상·상호작용의 연결 원칙 — 제안

모션 한 파일 대신 진입·반복·정지·이탈·취소, 손발 접촉점, 소품 소유 전환, 행동 결과 확정 시점, 허용 부상/장비 상태를 납품 계약으로 제안한다. 사다리·계단·양손무기·부축을 가능한 모든 조합으로 무조건 만들라는 뜻은 아니다. 실제 허용 조합은 게임 설계에서 선택한다.

현재 무기 브리프는 탭 사격과 일반 무기군을 사용한다. 원작 FPS 컨트롤러, 제조사 모델명, 소총 모션을 전 무기군에 강제하는 변경을 하지 않는다. 애니메이션 이름과 실제 화면의 무기 이름도 분리한다.

부위 상태가 바뀌어도 공통 골격/Avatar를 유지하고 외형·장비·IK 목표를 선택적으로 바꾸는 안을 먼저 비교한다. 이는 제안이며 원본 리그에 따라 달라진다. Avatar Mask는 메시 분리나 의족 모션을 자동 생성하지 않는다.

절단 처치·외형 교체·이후 이동을 독립적으로 검수한다. 카메라 회피가 소프트웨어/스토어의 등급 승인을 보장한다고 쓰지 않는다. 이 보고서는 의료 절차나 스토어 정책 판단이 아니다.

프로젝트 요구 근거: [S23](https://github.com/wndi1130-dot/APP/blob/23be388bc55be0062a6d637930ba7020bad8482c/docs/design/briefs/field_system.md) · [S24](https://github.com/wndi1130-dot/APP/blob/23be388bc55be0062a6d637930ba7020bad8482c/docs/design/briefs/weapons.md)

## 열람 한계와 오해 방지

공식 클립명, 구형 카탈로그, PDF 표, 상품의 기능 범주, 검색 색인만 보인 항목을 구분한다. clip evidence가 catalog_text/legacy_catalog/catalog_pdf여도 실제 파일 재생을 뜻하지 않는다.

Kubold 소총 URL과 내부 문서 버전의 차이 및 구형 Unity/UE4 카탈로그를 그대로 표시했다. 구형 이름을 현행 판매 패키지에서 직접 확인했다고 쓰지 않는다.

MoCap Online의 AI Applications 조항은 넓은 서면 허가 조건이다. Fab의 AI No 표시는 특정 구매 약관의 의미와 대조해야 하며 모든 로컬 코드 보조에 같은 금지를 기계적으로 복사하지 않는다. AI Yes도 공개 원본 재배포 허가를 뜻하지 않는다.

Fab 요약은 특정 라이선스의 구속력 있는 전문이 아니다. 실제 구매 옵션/원본 형식/NoAI 조건을 취득일에 고정해야 한다. 아직 구매하거나 자산 원본을 외부 서비스에 넣지 않았다.

PDF 카탈로그 3쪽은 스크린샷으로 읽었다. 상품의 애니메이션 시연 영상은 시청했다고 기록하지 않는다. CMU 상세 본문은 열람 실패했고 검색 결과 수준만 남겼다.

의족/절단 검색에서 나온 2D 아이콘·의료 설명 영상·원작 모드 추출 파일을 3D 상용 애니메이션 자산으로 세지 않았다. 특정 모션을 찾지 못했다는 것은 시장에 없다는 증명이 아니다.

## 후속 확인

- 사다리·계단에 맞춘 실제 체형/발판/가로대 접촉과 전환 품질
- S2에서 우선 쓸 권총·산탄총·활의 원본 포맷과 구체 무기군별 장전
- 부상 상태의 사격·장전, 한손+손전등, 의수 그립과 작업 동작
- 의족 전용 움직임과 보조기구 없이 적응한 생활 동작
- 절단 장면 카메라 회피에 맞는 환자·조력자의 짝 연기
- 정적 포즈·목발·부축과 실제 절단 후의 다양한 능력을 구분한 연출 검수
- 다운로드 라이선스·우리 공통 리그·Blender/Unity 임포트·실기기 비용

## 출처 장부

| ID | 원문 | 열람 범위 |
|---|---|---|
| S01 | [MoCap Online LADDER 상품·클립 목록](https://mocaponline.com/products/ladder) | 제작자 본문과 클립명 목록 열람; 영상/원본 클립 미재생 |
| S02 | [MoCap Online Standard License](https://mocaponline.com/pages/standard-license) | 현행 공개 약관의 AI Applications 사전 서면 허가 및 원본 배포 제한 열람 |
| S03 | [Motionbeats Stairs and Slope](https://www.fab.com/listings/56775370-29a2-483e-ba90-cabac9ab92e4?lang=en) | 제작자 본문·클립명·FBX/루트모션/인플레이스·AI 표시 열람 |
| S04 | [KayKit Character Animations](https://kaylousberg.itch.io/kaykit-character-animations) | 제작자 본문·CC0·무료/Source 구분·climbing의 예정 항목 표시 열람 |
| S05 | [Kubold Rifle Animset Pro 상품](https://www.fab.com/listings/e0eed5c5-54a6-41cc-bfa9-62b26c309bca?lang=en) | 제작자 상품 본문 열람; 태그를 실제 클립명으로 사용하지 않음 |
| S06 | [Kubold Rifle Animset Pro 기존 Unity 클립 설명](https://www.kubold.com/s/RifleAnimsetPro_v12_ListOfAnimations.html) | 공식 downloads 링크의 HTML 목록 열람. URL은 v1.2, 문서 표제는 v1.1; 구판 명세로 구분 |
| S07 | [Kubold Pistol Animset Pro 상품](https://www.fab.com/listings/c5caff8c-6815-4e81-b825-aeb95967411e?lang=en) | 제작자 상품 본문과 FBX 원본 제공 설명 열람 |
| S08 | [Kubold Pistol Animset Pro 기존 클립 설명](https://www.kubold.com/s/PistolAnimsetPro_AnimationsDescriptions.html) | 공식 downloads 링크의 기존 HTML 카탈로그 열람; 현재 구매 파일과 대조 안 함 |
| S09 | [Kubold Cover Rifle Animset Pro 상품](https://www.fab.com/listings/f9e9fbcb-0f07-49a0-8c06-80b18eba0e90) | 제작자 본문·엄폐 모션/조준 포즈 구분 열람 |
| S10 | [Kubold Cover Rifle UE4 클립 목록 PDF](https://www.kubold.com/s/CoverRifleAnimsetPro_UE4_list.pdf) | 공식 링크 PDF 3쪽의 텍스트 및 세 쪽 스크린샷 확인. 기존 UE4 명세이며 애니메이션 영상이 아님 |
| S11 | [Kubold FAQ Unity / 라이선스·FBX](https://www.kubold.com/faq-unity) | 제작자 FAQ의 구워진 게임 배포·원본 재배포 제한·컨트롤러 구분 열람 |
| S12 | [Fab Standard License 공개 요약](https://www.fab.com/eula) | 공식 요약 열람. 요약은 비구속적이며 각 상품의 구매 라이선스 원문 확인을 대신하지 않음 |
| S13 | [Ailive Injury Animation Pack](https://www.fab.com/listings/fb337e07-d758-4423-a0e3-a17a9610b1f6) | 제작자 본문·5개 전신 클립명·FBX·AI 표시 열람 |
| S14 | [Studio Ochi Low Poly Disabled People Animated & Rigged](https://www.fab.com/listings/d07f9075-f2dd-477e-a6de-bfb3cdd5d14a) | 제작자 본문 열람. 설명의 FBX/Blend와 포함 형식 표시의 GLB 사이 차이 기록 |
| S15 | [IKFootPlacement 제작자 README](https://github.com/plonkabartosz/IKFootPlacement) | README 기능·MIT 표시·요구 패키지·베이크 안내 열람; 실행 안 함 |
| S16 | [LimbHacker 제작자 README](https://github.com/JoeCooper/LimbHacker) | README와 MIT 표시, 알고리즘 문제/닫힌 메시 가정 경고 열람; 소스 실행 안 함 |
| S17 | [EzySlice 제작자 README](https://github.com/DavidArayan/ezy-slice) | convex mesh 절단 범위·MIT 표시 열람; 스킨드 캐릭터 완제품으로 인정하지 않음 |
| S18 | [Unity 6 Avatar Mask](https://docs.unity3d.com/6000.0/Documentation/Manual/class-AvatarMask.html) | 공식 본문에서 신체/Transform 및 손발 IK 곡선 마스킹 설명 확인 |
| S19 | [Unity 6 Animator.MatchTarget](https://docs.unity3d.com/6000.0/Documentation/ScriptReference/Animator.MatchTarget.html) | 공식 API 본문 열람. base layer·단일 대상·applyRootMotion 제약 확인 |
| S20 | [Unity 6 Retargeting](https://docs.unity3d.com/6000.0/Documentation/Manual/Retargeting.html) | 공식 Humanoid 리타기팅 설명 열람; Generic 리그에 같은 보장을 적용하지 않음 |
| S21 | [CMU subject 143 계단 검색 결과](https://mocap.cs.cmu.edu/search.php?subjectnumber=143) | 검색 색인에 143_17 Walk Up Stairs And Over가 보임. web/Exa 본문 열람 실패; 검색 결과 수준 |
| S22 | [CMU 이용 안내](https://mocap.cs.cmu.edu/) | Exa로 공식 안내 열람. 상업 포함/데이터 재판매 제한과 손가락 미캡처 구분 |
| S23 | [APP 필드 브리프의 절단 연출·의수 결정](https://github.com/wndi1130-dot/APP/blob/23be388bc55be0062a6d637930ba7020bad8482c/docs/design/briefs/field_system.md) | 고정 커밋의 COS 로컬 원문 열람. 외부 사실/법률 검증이 아닌 프로젝트 요구사항 |
| S24 | [APP 무기 브리프의 조작·무기 원형](https://github.com/wndi1130-dot/APP/blob/23be388bc55be0062a6d637930ba7020bad8482c/docs/design/briefs/weapons.md) | 고정 커밋의 COS 로컬 원문 열람. 탭 사격과 원형 구분의 프로젝트 근거 |
| S25 | [KaidoomDev Pump-Action shotgun Character Animation Pack](https://www.fab.com/listings/4f89da93-387c-4251-9646-6f2a973e682a) | 제작자 본문·1/3인칭 활용·무기 리그·AI 표시 열람; 파일 미취득 |
| S26 | [Raise Creation Combat Injured Animation Pack](https://www.fab.com/listings/1e54821b-c2e3-48ed-b26e-52bd24d5c20c) | 제작자 상태별·구조자 짝 클립 목록·FBX·AI 표시 열람; 원본 미재생 |

## 저장·검사

`python ref/art/build_research_index.py --check`, `python ref/art/validate_catalog.py`, `python -m unittest discover -s ref/art -p 'test_*.py' -v`로 문서와 목록을 확인한다. 실제 결과는 `research_index_validation_v6.json`과 PR에 별도 기록한다. 모션 품질·저작권 법률 판단·엔진 임포트·모바일 성능 검사가 아니며, 후보의 설치를 수행하지 않는다.
