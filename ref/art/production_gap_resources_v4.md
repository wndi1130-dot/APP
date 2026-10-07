# 3D 제작 자원 보충 4판 — 작업·구조·철도음과 자료 색인

작성: 2026-10-07 · 작업 기준 커밋: `38b959e4a8ba99c8d55acaad32c463bf1aa0091e`

[전체 색인](README.md) · [구조화 목록](production_gap_resources_v4.json) · [3판](game_reference_resources_v3.md) · [2판](production_resources.md)

## 이번에 달라진 것

사용자 요청에 따라 README에서 자료를 찾을 수 있게 통합 목록을 추가했다. 8개 새 조사 항목, 기존 후보 재확인 1건, 도면 자료 경로 2건을 나눴다. 외부 팩을 구매하거나 내려받은 것이 아니라 필요한 동작·파일 형식·근거의 구체성을 높인 작업이다.

| 빈칸 | 이번에 확인한 수준 | 아직 확인하지 못한 것 |
|---|---|---|
| 작업 모션 | Fix & Build의 삽질·렌치·설계도 확인 클립 이름과 FBX 제공 | 화실 투입에 맞는 궤적·그립·모션 품질 |
| 부축·들것 | Injury & Rescue 공식 설명에 해당 동작이 명시됨 | 정확한 짝 파일 ID·FBX 전달·두 체형의 정렬 |
| 철도 음향 | 실제 열차 출발/기적 CC0 후보와 전문 작업음 유료 라이브러리 | 청취·루프·현장 소음 분리·폴란드 차종의 음색 |
| 겨울 복장 | MPFB 의복 자체 제작 경로 | 완성된 긴 방한 외투·목도리와 겹침 호환 |
| 원도면 | Ol49-69 수리 공고의 설계자료 위치, Pt31 박물관 색인 | 원도면 이미지·치수·스케일·재배포 권리 |

## 적용 판단

우선 비교할 것은 삽질과 구조 모션이다. 이미 기반 몸체·일반 이동 모션·소품 후보는 있으므로, 더 많은 일반 팩보다 손과 소품·두 인물·객차 문이 만나는 동작의 빈칸을 줄이는 편이 유용하다. 다만 아래는 모두 프로젝트 적용 제안이며 S1을 3D로 재작성하거나 의료·철도 규칙을 새로 확정한 것이 아니다.

유료 후보의 조달과 무료 기법 문서를 같은 것으로 취급하지 않는다. 두 CC0 음원도 제목·라이선스만 확인했고 재생하지 않았다. 긴 외투는 아직 찾았다고 보고하지 않으며, 자체 제작 경로를 대안으로 남겼다.

<a id="mcc_fix_build"></a>
## 1. MoCap Central — Fix & Build

**[WATCH] / 유료 작업 모션 팩**

새 공급처. 3판 MoCap Online과 다른 업체다.

**우리 용도:** 삽질·렌치·탁상 정비·설계도 확인 동작의 조달 후보.

**출처 확인:** 공식 목록에서 am_Stand_Trans_Shovel, am_Shovel_03_Dig, am_Shovel_Trans_Stand, am_StandWrenchMid_01_TurnVertical, am_TablePlans_01_LookAtPoint를 확인했다. 상품은 raw skeletal FBX 제공을 명시한다.

**적용 제안:** 삽질 진입·반복·종료를 연결하고, 손·삽·화실 위치를 자체 조정하는 출발점으로 비교한다. 원본의 Dig를 석탄 퍼서 화실에 던지는 완성 동작으로 바꾸려면 수정이 필요할 수 있다.

**형식·버전:** FBX 원본과 Unity/Unreal 배포 안내. 제작자가 Unity 2022.3 LTS~6+를 제시하지만 우리 환경에서는 미검증. 가격은 고정하지 않음.

**권리·배포:** 유료 자체 EULA. 웹에서 읽은 2026-07-12판은 게임 사용을 허용하고 독립 원본 재배포·AI 학습/데이터셋 사용을 금지하며 추출 방지를 요구한다. Exa는 같은 주소의 2024판을 반환했으므로 취득일 원문을 다시 고정한다.

**AI 처리 구분:** 2026판의 AI 조항은 학습·데이터셋 사용에 관한 문구다. 이를 모든 로컬 코딩 보조 금지로 확대하지 않으며, 원본의 외부 모델 입력 허가도 자동으로 추정하지 않는다.

**한계:** 클립명과 배포 형식만 확인. 석탄 급탄에 맞는 궤적·삽 크기·손 그립·루트 이동·연속성은 파일 미확인.

**후속 검증:** 취득 조건 확인 후 삽질 1개와 전환 동작의 정확한 파일을 검수하고, 서로 다른 체형·화실 높이에서 접촉과 중단을 시험한다.

근거: [S01](https://mocapcentral.com/products/mocap-studio-series-fix-build-pack) · [S02](https://mocapcentral.com/pages/fix-build-animation-list) · [S03](https://mocapcentral.com/pages/licensing)

<a id="reallusion_injury_rescue"></a>
## 2. Reallusion — Injury & Rescue

**[WATCH] / 유료 구조·짝동작 모션 팩**

3판에서 미확보였던 부축·들것 동작의 새 공급 후보.

**우리 용도:** 부상자 부축·업거나 들기·들것 운반·구호물자 전달 비교.

**출처 확인:** 공식 제품 설명에 shouldering/carrying, 들것으로 부상자 운반, 물자 배분·수령이 명시돼 있다. 개별 클립 파일명은 확보하지 못했다.

**적용 제안:** 두 인물의 동작과 소품을 함께 다루는 장면 후보로 삼는다. 응급처치 동작이 있다는 이유로 새 의료 규칙을 추가하지 않는다.

**형식·버전:** iClone 콘텐츠 상품. 구매 파일이 직접 FBX인지, 내보내기용 프로그램과 별도 비용이 필요한지는 취득 전에 확인해야 한다.

**권리·배포:** 공식 정책 상단은 Standard의 외부 도구/엔진 export를 안내하고 iContent는 외부 export를 제외한다. 하단 FAQ에 구 Standard/Extended 설명이 남아 있어 구매 옵션·해당 EULA를 대조해야 한다. 원본 공개 재배포 허가로 해석하지 않는다.

**AI 처리 구분:** 정책은 AI 학습 등 특별 용도를 Enterprise 문의 대상으로 둔다. 게임용 로컬 변환과 외부 AI 입력은 분리해서 확인한다.

**한계:** 부축·들것이라는 동작 범주는 공식 확인했지만 짝 클립 ID, 상대 좌표, 몸 크기 변화, 전환/취소 동작, Blender·Unity 가져오기는 미확인.

**후속 검증:** 클립 목록·짝 정렬 데이터·export 요구 소프트웨어를 먼저 확보한다. 이후 키가 다른 두 사람과 좁은 객차 문 통과를 시험한다.

근거: [S04](https://www.reallusion.com/ContentStore/iClone/pack/3D-Animation-Injury-and-Rescue/default.html) · [S05](https://www.reallusion.com/license/content.html)

<a id="audio_train_departure_125211"></a>
## 3. Freesound 125211 — keithpeter의 증기열차 출발 녹음

**[WATCH] / CC0 개별 현장 음원**

3판 일반 압력음에서 실제 증기열차 현장음으로 보충.

**우리 용도:** 출발 순간의 증기·급탄·기적·차륜 소리 층을 비교할 재료.

**출처 확인:** 제작자는 영국 Birmingham Moor Street에서 출발하는 Hall형 증기열차를 녹음했으며, 석탄 투입·증기·기적·가속·객차 주행음이 포함된다고 설명한다. WAV/CC0 표시를 확인했다.

**적용 제안:** 출발 장면의 기준 청취 자료로 비교하고 필요한 구간만 선별한다.

**형식·버전:** 제작자 페이지에 WAV 다운로드 제공. 이번에는 파일을 받거나 재생하지 않았다.

**권리·배포:** 해당 음원의 CC0 표시 확인. 사이트 전체 자료의 권리로 확대하지 않는다.

**AI 처리 구분:** 자산 CC0 표시와 서비스의 외부 입력·보관 조건은 구분한다. 이번 원본 전송 없음.

**한계:** 여러 소리가 섞인 현장 녹음이다. 깨끗한 석탄 원샷이나 무한 루프를 확보했다고 할 수 없다. 폴란드 기관차의 정확한 음색도 아니다.

**후속 검증:** 청취 후 말소리·클리핑·겹친 효과를 확인하고 편집 가능한 구간, 모노 합성, 반복 피로도를 점검한다.

근거: [S06](https://freesound.org/people/keithpeter/sounds/125211/)

<a id="audio_loco_whistle_686058"></a>
## 4. Freesound 686058 — relwin의 기관차 기적

**[WATCH] / CC0 개별 현장 음원**

출발/철수 신호용 음향 보충.

**우리 용도:** 열차 출발 신호의 실제 기관차 기적 후보.

**출처 확인:** 제작자는 여객 열차를 견인하는 기관차 478의 기적이라고 설명한다. d_s478_onboardwhistle.wav와 CC0 표시를 확인했다.

**적용 제안:** 급박한 출발 신호의 비교 음원으로 삼되 경고 자막·화면 표시를 함께 검토한다.

**형식·버전:** WAV 현장 녹음. 미다운로드·미청취.

**권리·배포:** 해당 음원 CC0 표시. 기록된 제작자·원문 주소는 유지한다.

**AI 처리 구분:** CC0 표기를 확인했지만 이번 원본 파일의 외부 입력은 하지 않았다.

**한계:** 미국 협궤 철도 녹음이며 Ol49/Pt47 고증 음원으로 사용하지 않는다. 다른 현장 소리가 얼마나 섞였는지 미확인.

**후속 검증:** 휴대폰 모노 재생의 고음 피로, 대사 마스킹, 페이드와 반복 경고 간격을 확인한다.

근거: [S07](https://freesound.org/people/relwin/sounds/686058/)

<a id="evocative_american_steam"></a>
## 5. Evocative Sound and Visuals — American Steam Trains

**[WATCH] / 유료 철도 음향 라이브러리**

일반 효과음 번들보다 구체적인 기관차 작업음 후보.

**우리 용도:** 화실 급탄·증기 방출·근접/원경 주행·정비 소리의 수급 후보.

**출처 확인:** 제작자는 운행 중인 미국 석탄 증기기관차 두 대와 정적 전시차의 소리를 구분하고, 운전실에서 화부가 급탄하는 녹음 및 근접/원경/통과 시점을 설명한다.

**적용 제안:** 기관차 음향을 주행음 한 파일 대신 작업·배기·기적·차륜·공간 거리별로 나누는 비교 자료로 쓴다.

**형식·버전:** 제작자 연결 판매 페이지가 디지털 다운로드와 Royalty-free/사용자 수 선택을 안내한다. 파일 목록과 샘플을 직접 검사하지 않았다.

**권리·배포:** 유료 자체 라이선스. 판매 페이지의 Royalty-free 표시는 확인했지만 이 상품에 적용되는 EULA 전문은 확보하지 못했다. 원본 공개 업로드·재배포는 허용으로 간주하지 않는다.

**AI 처리 구분:** AI 입력/학습 조건은 미확인. 확인 전 원본의 외부 전송이나 학습 입력을 하지 않는다.

**한계:** 미국 기관차 녹음이므로 지역 음색 차이가 남는다. 급탄음이 다른 소리와 분리 가능한지, 필요한 루프·원샷이 있는지 미확인.

**후속 검증:** 정확한 트랙 목록·EULA·샘플을 먼저 대조하고 필요한 소리만 라이선스 취득 후 검수한다.

근거: [S08](https://www.evocativesound.com/2025/12/04/american-steam-trains/) · [S09](https://www.asoundeffect.com/sound-library/american-steam-trains/)

<a id="mpfb_makeclothes_workflow"></a>
## 6. MPFB — MakeClothes 의복 제작 절차

**[WATCH] / 기존 도구의 공식 제작 기법**

v2 MPFB/v3 의복 후보의 제작 경로 구체화. 새로운 인체 프로그램이 아님.

**우리 용도:** 긴 방한 외투를 찾지 못했을 때 자체 의복을 같은 몸체에 맞추는 대안.

**출처 확인:** 공식 문서는 helper 기반 의복 추출, 재질·UUID 메타데이터, 검사·저장을 다룬다. 제작 입력 메시의 면 형식 통일과 정점 그룹 조건도 명시한다.

**적용 제안:** 방한 외투의 자체 제작과 기존 니트/바지의 겹침 검수를 비교한다. 자산 생성 규칙과 엔진용 스키닝 규칙을 별도 문서로 관리한다.

**형식·버전:** MPFB의 Blender 내 제작 절차. 완성된 겨울 외투 팩은 아니며, 배포 확장 버전과 실행 호환은 별도 확인한다.

**권리·배포:** 도구 코드와 핵심 자산/제3자 의복 권리를 분리한다. 외부 의복을 수정했다고 원본 라이선스가 사라지지 않는다.

**AI 처리 구분:** 자체 제작물과 외부 입력물의 권리를 나눠 기록한다. 이번 생성/외부 입력 없음.

**한계:** 기본 셔츠 예제를 긴 코트·아동·노년 체형의 자동 완성으로 확대하지 않는다. 문서의 정점당 그룹 조건을 최종 게임에서 정점당 뼈 하나만 쓰라는 지시로 바꾸지 않는다.

**후속 검증:** 허벅지/무릎을 덮는 외투의 앉기·걷기·부축 동작을 시험하고, 숨겨진 몸 메시·의복 분리·가중치·LOD를 확인한다.

근거: [S10](https://static.makehumancommunity.org/mpfb/docs/assets/creating_clothes.html) · [S11](https://static.makehumancommunity.org/about/license.html)

<a id="blender_child_of_handoffs"></a>
## 7. Blender 4.5 — Child Of 제약과 소품 인계

**[WATCH] / 공식 기본 기능 문서**

리그 제작 자체와 다른 소품 접촉/부모 전환 기법 보충.

**우리 용도:** 삽을 집고 내려놓기, 물자 건네기, 들것 손잡이와 인물의 관계를 제작할 때 참고.

**출처 확인:** 공식 문서는 복수 대상의 Influence와 그 애니메이션, Set Inverse를 통한 부모 적용 시 변형 보정을 설명한다. armature의 본 체인을 정의하는 용도와 구분한다.

**적용 제안:** 테이블→손→다른 손으로 소품 소유 관계가 바뀌는 순간을 명시하고, 실제 게임 소유 상태와 시각 제약을 따로 기록한다.

**형식·버전:** Blender 기본 constraint. 별도 애드온이나 모션 파일이 아니다.

**권리·배포:** Blender 기능 문서를 참고한다. 입력 소품·모션의 이용 권리는 별도다.

**AI 처리 구분:** 후속 자작 자동화는 입력 자료의 권리를 따르며 외부 전송을 기본 요구하지 않는다.

**한계:** 제약 설명만으로 두 사람의 자연스러운 움직임이 생성되지 않는다. Blender 제약을 엔진의 실시간 부모 전환으로 그대로 export할 수 있다고 가정하지 않는다.

**후속 검증:** 베이크/엔진 소켓 이벤트 방식을 비교하고 손바뀜 프레임, Set Inverse 순서, 취소/세이브 복귀 때 소품 순간이동을 검사한다.

근거: [S12](https://docs.blender.org/manual/en/4.5/animation/constraints/relationship/child_of.html)

<a id="unity_spline_train_path"></a>
## 8. Unity Splines — 경로와 Spline Animate

**[WATCH] / 공식 엔진 패키지/예제**

Blender의 선로 형상 제작과 구분되는 엔진 경로 표현 후보.

**우리 용도:** 곡선 위 열차 전경·카메라 이동·선로 주변 반복 배치의 후순위 비교.

**출처 확인:** Splines 2.8 공식 개요는 경로 위 객체 배치·위치/회전 애니메이션 예제를 설명하며 Unity 2022.3 이상을 지원 범위로 적는다. Spline Animate는 GameObject 이동 경로를 지정한다.

**적용 제안:** 기관차와 객차의 배치·카메라를 경로 데이터에서 재구성하는 후보로 삼는다. 열차는 앞뒤 대차 위치와 연결 간격을 별도로 검토한다.

**형식·버전:** Unity 패키지. 문서 조회 경로의 2.8 세부 패치 표시가 달라 정확한 채택 버전은 고정하지 않았다.

**권리·배포:** Unity 패키지의 취득 버전 이용 조건을 따른다. CC0 자산이나 별도 철도 물리 엔진으로 분류하지 않는다.

**AI 처리 구분:** 자작 경로 데이터와 외부 지도 데이터의 권리를 구분한다. OSM 파생 DB의 기존 라이선스 체계를 유지한다.

**한계:** 객체 하나의 경로 이동을 객차 연결·분기기·충돌·철도 운행 시뮬레이션 완성으로 확대하지 않는다. 실제 지도/캠페인을 지금 구현하는 지시가 아니다.

**후속 검증:** 후속 작은 곡선 구간에서 객차 앞뒤 기준점·길이·연결 간격을 먼저 비교한다. 저장 후 위치·방향을 같은 데이터로 복원하는지 검수한다.

근거: [S13](https://docs.unity3d.com/Packages/com.unity.splines@2.8/manual/index.html) · [S14](https://docs.unity3d.com/Packages/com.unity.splines@2.8/manual/animate-spline.html)

## 기존 조사에서 보완한 것

### CMU subject 62 작업 동작 재확인
3판에서 열람하지 못한 subject 62 본문을 Exa로 읽었다. 렌치·톱질·못질·청소·상자 개폐·로프 감기 같은 작업을 확인했다. 파싱에서 번호가 선명한 62_18(상자 닫기), 62_19(상자 열기), 62_21(로프 감기)을 기록한다.

일부 표 번호가 불완전하게 반환돼 전체 번호를 복원하지 않았다. 읽은 목록에서 삽질 명칭은 확인하지 못했다. 따라서 construction이라는 분류를 화부 모션 확보로 해석하지 않는다. 실제 모션 파일·라이선스 재판정·런타임 시험은 하지 않았다.

근거: [S15](https://mocap.cs.cmu.edu/search.php?subjectnumber=62) · [S16](https://mocap.cs.cmu.edu/)

## 기관차 도면 — 탐색 경로와 확보물을 구분

### 볼슈틴 Ol49-69 차대 수리 부속 설계자료
공식 PPZ.265.4.2025 공고 본문에서 Ol49-69 차대 수리와 부속 6 OPZ(설계자료)의 존재를 확인했다. 이후 원도면을 찾아야 할 구체적인 기관·차량·공고 경로를 확보한 것이다.

실제 도면 파일·치수·스케일·사용권은 미확인. 완성 기관차 모델링용 측면/평면도를 확보한 것으로 세지 않는다. Ol49를 최종 차종으로 확정하지 않는다.

근거: [S17](https://bip.parowozowniawolsztyn.pl/przetarg_publiczny_PPZ.265.4.2025.htm)

### Stacja Muzeum Pt31 기술 문서 색인 경로
박물관 도메인의 Pt31 기술 문서 TOM II PDF가 검색 색인에 나타났다. 차종과 원문 위치를 기록한 후속 탐색 경로다.

PDF 열람 실패로 도면·표·이미지를 검토하지 못했다. 색인의 종이 크기를 기관차 부품 치수로 쓰지 않는다. Pt31은 Pt47·Ol49와 다른 차종이고 이 자료의 재배포 권리도 미확인이다.

근거: [S18](https://cyfrowa.stacjamuzeum.pl/storage/app/media/Zbiory/Dokumentacja%20techniczna%20parowozu%20Pt31/TOM%20II/tom-ii.pdf)

## 약관과 조회 한계

MoCap Central EULA는 같은 주소에서 조회 경로에 따라 2024판과 2026-07-12판이 반환됐다. 이번 요약은 날짜가 명시된 2026판의 게임 이용/원본 재배포/AI 학습 구분을 따른다. 구판의 모호한 임베딩 문구를 현행 확정 제한으로 옮기지 않았다. 실제 구매 시 원문 버전을 다시 보관해야 한다. [S03](https://mocapcentral.com/pages/licensing)

Reallusion은 공식 페이지 상단의 확장 Standard 설명과 하단 구 FAQ가 서로 다르다. 특히 캐릭터 수 제한 설명은 이번 모션 팩의 구매 조건으로 곧바로 적용하지 않았다. iContent와 외부 내보내기 권한, 필요한 프로그램을 실제 옵션에서 확인한다. [S05](https://www.reallusion.com/license/content.html)

CMU 표의 일부 번호가 파싱에서 빠졌고 박물관 PDF는 열람에 실패했다. 불완전한 번호를 추측해 채우거나 PDF 도면·표를 보았다고 기록하지 않았다. 저장소에는 제3자 도면 원문·음원·모션·사진을 추가하지 않았다.

## 남은 확인 항목

- 화실 높이와 투입 방향에 맞는 급탄 모션의 실제 궤적/클립 품질
- 부축/들것의 짝 클립 ID·상대 좌표·소품 제공 범위·직접 FBX 전달 여부
- 완성된 긴 방한 외투·목도리와 체형별 겹쳐 입기 호환
- 최종 선정 차종의 치수 있는 측면·평면·실내 도면 및 재사용 권리
- 폴란드 기관차의 개별 작업음 또는 대체 음원의 실제 청취·믹싱 적합성
- 중앙유럽 소도시 역·일반 병원의 구체적인 게임용 내외부 모듈
- Blender/Unity import와 실제 휴대폰에서의 시각 품질·성능

## 출처 장부

| ID | 원문 | 열람 수준 |
|---|---|---|
| S01 | [MoCap Central Fix & Build 상품 설명](https://mocapcentral.com/products/mocap-studio-series-fix-build-pack) | 공식 본문 열람 |
| S02 | [MoCap Central Fix & Build 클립 목록](https://mocapcentral.com/pages/fix-build-animation-list) | 공식 목록 열람 |
| S03 | [MoCap Central EULA](https://mocapcentral.com/pages/licensing) | 공식 본문 열람; 조회 경로별 2024/2026 판본 차이 발견 |
| S04 | [Reallusion Injury & Rescue](https://www.reallusion.com/ContentStore/iClone/pack/3D-Animation-Injury-and-Rescue/default.html) | 공식 본문 열람 |
| S05 | [Reallusion Content License Policy](https://www.reallusion.com/license/content.html) | 공식 본문 열람; 상단 정책과 하단 FAQ의 차이 기록 |
| S06 | [keithpeter / Freesound 125211](https://freesound.org/people/keithpeter/sounds/125211/) | 제작자 설명·파일 메타데이터·CC0 표시 열람; 청취 안 함 |
| S07 | [relwin / Freesound 686058](https://freesound.org/people/relwin/sounds/686058/) | 제작자 설명·파일 메타데이터·CC0 표시 열람; 청취 안 함 |
| S08 | [Evocative Sound and Visuals American Steam Trains](https://www.evocativesound.com/2025/12/04/american-steam-trains/) | 녹음 제작자 본문 열람; 청취 안 함 |
| S09 | [American Steam Trains 판매·배포 정보](https://www.asoundeffect.com/sound-library/american-steam-trains/) | 제작자 연결 판매 페이지 열람; 개별 EULA 전문 미확보 |
| S10 | [MPFB Creating clothes](https://static.makehumancommunity.org/mpfb/docs/assets/creating_clothes.html) | 공식 제작 절차 본문 열람 |
| S11 | [MakeHuman Community 라이선스](https://static.makehumancommunity.org/about/license.html) | 2판에서 확인한 프로그램/핵심 자산 구분; 이번에 개별 의복 권리까지 재검증한 것은 아님 |
| S12 | [Blender 4.5 Child Of Constraint](https://docs.blender.org/manual/en/4.5/animation/constraints/relationship/child_of.html) | 기본 열람 오류 후 Exa로 공식 본문 열람 |
| S13 | [Unity Splines 2.8 개요](https://docs.unity3d.com/Packages/com.unity.splines@2.8/manual/index.html) | 공식 본문 열람 |
| S14 | [Unity Spline Animate](https://docs.unity3d.com/Packages/com.unity.splines@2.8/manual/animate-spline.html) | 공식 본문 열람; 조회 경로별 세부 패치 번호 차이 있음 |
| S15 | [CMU subject 62](https://mocap.cs.cmu.edu/search.php?subjectnumber=62) | 기본 열람 시간 초과 후 Exa로 본문 열람; 일부 표 번호 파싱 불완전 |
| S16 | [CMU 모션 데이터 이용 안내](https://mocap.cs.cmu.edu/) | 3판의 기존 이용 조건 참조; 신규 라이선스로 교체하지 않음 |
| S17 | [볼슈틴 Ol49-69 차대 수리 공고 PPZ.265.4.2025](https://bip.parowozowniawolsztyn.pl/przetarg_publiczny_PPZ.265.4.2025.htm) | Exa로 공식 공고 본문과 부속 문서 제목 열람; 실제 도면 미열람 |
| S18 | [Stacja Muzeum Pt31 기술 문서 TOM II](https://cyfrowa.stacjamuzeum.pl/storage/app/media/Zbiory/Dokumentacja%20techniczna%20parowozu%20Pt31/TOM%20II/tom-ii.pdf) | 검색 색인에서 발견; PDF 열람 실패; 도면·표 미검토 |

## 문서 검증의 범위

`python ref/art/build_research_index.py --check`로 세 판의 ID 충돌, 출처 참조, README/보고서 생성 결과, 상대 링크, 미실행 표기를 확인한다. `python ref/art/validate_catalog.py`와 `python -m unittest discover -s ref/art -p 'test_*.py' -v`를 함께 실행한다. 실제 실행 결과는 별도 `research_index_validation_v4.json` 및 PR 기록에 남긴다. 이 검사들은 링크의 실시간 가용성·법률 판단·음원 청취·모션 품질·게임 성능을 확인하지 않는다.
