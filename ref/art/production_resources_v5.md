# 3D 제작 자원 보충 5판 — 방한복·생활 소품·파일 전달·용량 검수

작성: 2026-10-07 · 기준 커밋: `da6797dcdbe782d4effea9c29e722ae77d9e3ce1`

[전체 색인](README.md) · [구조화 목록](production_resources_v5.json) · [4판](production_gap_resources_v4.md)

## 범위

추가 조사, GitHub 연구 브랜치와 COS 로컬 문서 저장, README 갱신, 문서 검사. 자산 팩 취득·설치·구매·모델 제작·렌더·엔진 실행·main 병합은 하지 않음.

비픽셀·좀보이드식 그래픽·사선 탑뷰. S1 웹 정치 프로토타입과 UI/초상/폰트 미확정 상태 유지.

## 이번 조사에서 좁힌 것

4판에서 남았던 방한 코트와 목도리의 실제 제작자 페이지를 찾았다. 여성 체형용 구형 MakeHuman 자산이며, 모든 주민 체형에 맞는 완성 팩을 확보한 것은 아니다.

기관실 배관과 생활 공간의 낡은 침상은 구체적인 CC0 메시 자산으로 좁혔다. HDRI나 상품 미리보기를 이동 가능한 3D 실내로 오인하지 않는다.

Blender 의존 파일 전달, 별도 컴퓨터의 렌더 작업 관리, 라이트맵 UV와 텍스처 전달·메모리 측정을 보충했다. 모델을 잘 만드는 일과 다른 컴퓨터/엔진에서 같은 결과로 여는 일을 분리한다.

신규 조사 항목 9개와 Blender 4.5 기준 제외 1개다. 항목 수를 공급처 수·설치 수·확보한 원본 파일 수로 부르지 않는다. 기존 62개와 합치면 후보 항목은 71개이며 제외는 별도다.

## 사용 순서 제안

의복 두 항목은 기존 공통 몸체와의 호환 확인부터, 소품 두 항목은 크기·부품 분리부터 비교한다. 텍스처 최적화 전에 원본·전달본·측정 기준을 나눈다. 렌더 관리 서버는 지금 설치할 필수 도구가 아니다.

<a id="mh_punkduck_winter_coat"></a>
## 1. punkduck — Winter coat

**[WATCH] / CC-BY 의복 자산**

기존 MPFB 조사에서 미선정이던 겨울 코트의 구체 자산.

**용도:** 민간인 방한 외투의 실루엣·겹쳐 입기 후보.

**출처 확인:** 제작자는 여성용 겨울 코트와 diffuse 텍스처를 제공하며 털 표현은 별도 제작해야 한다고 설명한다. coat.mhclo 머리말은 author punkduck, license CC BY 3.0, basemesh hm08, obj_file coat.obj를 명시한다.

**적용 제안:** 몸체별 코트 변형과 털 표현의 저비용 대안을 비교한다. 원작자의 구형 particle hair 설명을 모바일 런타임 요구로 바꾸지 않는다.

**형식·호환:** coat.mhclo / coat.obj / coat.mhmat 제공 목록 확인. 페이지의 1.1.x는 MakeHuman 호환 표기이며 Blender 4.5 검증이 아니다.

**권리:** CC-BY-3.0은 읽은 MHCLO 머리말의 표기다. 원본 패키지 전체의 저자·텍스처 고지는 취득 시 확인하고 출처/수정 내역을 보존한다. CC0로 표시하지 않는다.

**파일·AI 처리:** 메타데이터와 설명만 열람. 실제 모델·텍스처를 클라우드에 넣거나 원본을 GitHub에 올리지 않았다.

**미확인·한계:** 체형에 따라 벨트·버클 위치 조정이 필요하다는 제작자 경고가 있다. 남성·아동·노년 체형의 호환, 앉기·보행·부축의 관통, 메시 비용은 미검증.

**후속 검증:** 후속 취득 후 코트 길이·버클·숨길 몸 표면을 확인하고, 걸음/앉기/부축에 맞춰 가중치와 표현을 검수한다.

근거: [S01](http://makehumancommunity.org/clothes/winter_coat.html) · [S02](http://www.makehumancommunity.org/sites/default/files/clothes/1665/1679758305/coat.mhclo)

<a id="mh_elvs_winter_scarf_oc"></a>
## 2. Elvaerwyn — Elvs Ladies winter scarf 1 OC

**[WATCH] / CC-BY 의복 자산**

4판의 목도리 공백을 구체적인 자산 페이지까지 좁힘.

**용도:** 외투 위에 두르는 민간인 목도리 후보.

**출처 확인:** 제작자는 여성 MakeHuman 모델의 재킷 위에 맞춘 삼각형 메시, 한 텍스처 구성을 설명한다. Elv_Scarf1_ladies_oc.mhclo / .obj / .mhmat 파일명이 나열돼 있다.

**적용 제안:** 코트·목·머리카락과 겹치는 부분을 조절하고 색/마모 변화로 주민 차이를 만든다.

**형식·호환:** MakeHuman 의복 형식. 완성 Unity 프리팹이나 모든 체형용 팩은 아니다.

**권리:** 제작자 페이지 CC-BY. 세부 버전은 이번에 확보하지 못했으므로 실제 파일의 고지를 확인하기 전 원본 재배포 승인을 판정하지 않는다.

**파일·AI 처리:** 제작자 설명·파일 목록만 열람. 원본의 외부 입력은 하지 않았다.

**미확인·한계:** coat와 같은 제작자의 짝 세트가 아니며 서로 겹침 없이 맞는지는 미검증. 삼각형 메시라는 사실로 가볍다고 판정하지 않는다.

**후속 검증:** 출처/라이선스 버전 확인 후 고개 돌리기·웅크리기·후드와의 간섭을 시험한다.

근거: [S03](http://makehumancommunity.org/clothes/elvs_ladies_winter_scarf_1_oc.html)

<a id="ph_modular_industrial_pipes"></a>
## 3. Poly Haven — Modular Industrial Pipes 01

**[WATCH] / CC0 모듈식 3D 소품**

v2 Poly Haven 공급처를 실제 배관 모델로 구체화.

**용도:** 기관실·난방관·정비 공간의 배관과 밸브 후보.

**출처 확인:** Jorge Camacho 제작 모델이며 Blend/glTF/FBX 등과 여러 재질 맵, CC0 표시를 확인했다. Industrial Pipe & Valve라는 다른 항목은 HDRI일 수 있으므로 이름만 보고 메시로 수집하지 않는다.

**적용 제안:** 배관·조작 밸브·장식 게이지를 구분하고, 움직여야 할 부품만 독립 자산으로 가공하는 비용을 평가한다.

**형식·호환:** 3D 모델과 재질 맵. 선택 해상도와 포맷에 따라 용량이 다르므로 기본 고해상도 다운로드를 납품 규격으로 고정하지 않는다.

**권리:** 해당 자산 CC0. 자산 사용권과 웹사이트 수집 조건은 별개이며 자동 대량 수집은 하지 않는다.

**파일·AI 처리:** CC0 자산 자체에 근거 없는 AI 금지 조건을 덧붙이지 않는다. 서비스의 전송/보관 정책은 별도이며 이번 원본 전송은 없음.

**미확인·한계:** 실제 폴란드 기관차의 부품 치수·배관 연결 고증 자료가 아니다. 조작부 분리·충돌·소켓·리그는 미검사.

**후속 검증:** 소품 1개부터 단위·피벗·분리 가능 부품·법선 방향·축소 맵과 실제 상호작용을 확인한다.

근거: [S04](https://polyhaven.com/a/modular_industrial_pipes_01) · [S06](https://polyhaven.com/license)

<a id="ph_vintage_day_bed"></a>
## 4. Poly Haven — Vintage Day Bed

**[WATCH] / CC0 생활 공간 3D 소품**

추상적인 가구 수급처 대신 낡은 침상의 구체 후보.

**용도:** 앞칸의 낡은 안락함·임시 거주 공간을 비교할 침상 소품.

**출처 확인:** Aron Łyczek 제작. 낡은 목재 프레임·쿠션·이불이 있는 모델로 소개되며 Blend/glTF/FBX와 CC0 표시를 확인했다.

**적용 제안:** 상대적으로 좋은 침상과 꼬리칸의 좁은 수면 공간을 대비하는 자료로 비교한다. 앞칸 배치 자체를 확정하지 않는다.

**형식·호환:** 메시 자산이며 Hospital Room 2 같은 HDRI와 구분한다. 페이지의 반올림된 삼각형 수 대신 실제 취득 메시를 검사한다.

**권리:** 해당 자산 CC0. 웹사이트 전체 사진·설명문에 같은 권리를 자동 적용하지 않는다.

**파일·AI 처리:** 이번에는 상품 본문/메타데이터만 확인했다. 원본 메시·텍스처를 저장하거나 외부 처리하지 않았다.

**미확인·한계:** 의료용 침대도, 유럽 객차 표준 침상 도면도 아니다. 이불·베개 분리 및 사람이 눕는 충돌/애니메이션은 미확인.

**후속 검증:** 객차 폭과 통로, 누운 몸의 접촉, 소품 분리, 저해상도 질감의 가독성을 확인한다.

근거: [S05](https://polyhaven.com/a/vintage_day_bed) · [S06](https://polyhaven.com/license) · [S21](https://polyhaven.com/a/hospital_room_2)

<a id="blender_pack_dependencies"></a>
## 5. Blender 4.5 — Pack Resources / Linked Libraries

**[WATCH] / 기본 기능·파일 전달 절차**

Asset Browser나 glTF 변환과 다른 .blend 원본의 의존 파일 전달 문제를 보충.

**용도:** 다른 에이전트·컴퓨터에서 텍스처나 링크된 파일이 누락되는 상황 예방.

**출처 확인:** 공식 문서는 외부 리소스와 링크된 라이브러리의 패킹을 설명한다. 실제 반영에는 저장이 필요하며 모든 파일을 담을 수 있는 것은 아니라고 명시한다.

**적용 제안:** 전달 전에 패킹 가능한 파일과 외부에 남는 의존 파일 목록을 나누고, 원본을 덮어쓰지 않은 별도 전달본에서 검사한다.

**형식·호환:** Blender 4.5 기능 문서. 별도 애드온 설치가 필요하지 않은 후보 경로.

**권리:** 패킹은 외부 자산 라이선스를 변경하지 않는다. 제한된 텍스처를 .blend에 넣었다고 공개 GitHub에 올릴 수 있게 되는 것은 아니다.

**파일·AI 처리:** 자산 의존 목록을 먼저 검토하고 허용된 전달 대상만 사용한다. 이번 패킹/Blender 실행은 없음.

**미확인·한계:** 공식 문서는 비디오 등 패킹 불가 파일을 예로 든다. 캐시 전체의 완전 포함을 보증하지 않는다.

**후속 검증:** 작은 허용 장면의 전달본을 다른 경로에서 열어 누락 파일·절대경로·외부 캐시를 확인한다.

근거: [S07](https://docs.blender.org/manual/en/4.5/files/blend/packed_data.html)

<a id="flamenco_render_dispatch"></a>
## 6. Blender Flamenco — 자체 호스팅 렌더 작업 관리

**[WATCH] / 오픈소스 렌더 관리 도구**

COS의 모델 생성/파일 제어와 별개인 렌더 작업 배분 후보.

**용도:** 향후 별도 GPU 컴퓨터에서 프리뷰·연기 프레임·일괄 렌더를 수행할 때 검토.

**출처 확인:** 공식 소개는 자체 호스팅 렌더 관리와 GPL 3.0을 명시한다. 공유 저장소 문서는 즉시 접근 가능한 저장소를 요구하며 비동기 클라우드 동기화를 기본 지원하지 않는다.

**적용 제안:** 작업별 입력 사본과 완료된 출력물을 분리하는 구조를 먼저 설계한다. 인터넷 공개 서버보다 신뢰된 사설 연결을 우선 비교한다.

**형식·호환:** Manager/Worker와 Blender 애드온을 설치하는 별도 도구. 선택 릴리스의 Blender 4.5 호환은 미검증이며 설치하지 않았다.

**권리:** 공식 소개 GPL 3.0. 입력 자산·작업 파일의 권리와 별개다.

**파일·AI 처리:** 새 서버·터널·네트워크 공유를 만들지 않았다. 사용자 파일을 렌더 노드로 보내려면 대상·범위·권한을 명시한다.

**미확인·한계:** Windows 공유 경로는 드라이브 문자 방식이며 UNC를 지원하지 않는다고 설명한다. Google Drive/Dropbox/OneDrive/Syncthing 동기화 폴더를 즉시 일관된 공유 저장소로 가정하면 안 된다. 기본 인증 기능도 최소화된 설계다.

**후속 검증:** 후속 승인 시 입력 전달 완료·버전 동일성·워커별 경로·중단/재시도·결과 복사와 덮어쓰기 방지를 작은 작업으로 검증한다.

근거: [S08](https://flamenco.blender.org/about/) · [S09](https://flamenco.blender.org/) · [S10](https://flamenco.blender.org/usage/shared-storage/)

<a id="ktx_texture_pipeline"></a>
## 7. KTX-Software + KtxUnity — 텍스처 전달 경로

**[WATCH] / 텍스처 도구·Unity 로더 묶음**

v2 glTF/meshoptimizer의 메시 전달과 구분되는 텍스처 인코딩·로딩 조합. 두 프로젝트를 경로 하나로 센다.

**용도:** 텍스처가 많은 옷·객차·소품의 전달량과 실제 로딩 비용을 비교.

**출처 확인:** Khronos 도구는 KTX2 생성·인코딩·변환·검사 CLI를 제공한다. KtxUnity는 KTX2/Basis와 ETC1S/UASTC, 여러 플랫폼 및 메모리/StreamingAssets/URL 로딩을 설명한다.

**적용 제안:** 원본 텍스처는 보존하고 엔진 전달본만 변환한다. 다운로드 크기·로딩 중 최대 메모리·GPU 점유를 서로 다른 측정값으로 기록한다.

**형식·호환:** KTX 인코딩 도구와 Unity 네이티브 로더. Unity 기본 임포터가 모든 .ktx2를 그대로 처리한다고 가정하지 않는다.

**권리:** KTX-Software 고유 파일은 대체로 Apache-2.0이나 LICENSE는 별도 라이선스와 lib/etcdec.cxx의 비오픈소스 예외를 명시한다. KtxUnity LICENSE는 Apache-2.0. 채택 배포물의 고지를 확인한다.

**파일·AI 처리:** 원본 자산의 권리를 유지하며 변환 도구의 라이선스로 입력 자산 권리를 덮지 않는다. 이번 설치·변환·외부 입력 없음.

**미확인·한계:** 파일이 작아졌다고 GPU 메모리나 화질이 같은 비율로 좋아지는 것은 아니다. 법선/마스크 채널·색 공간·알파·실기기 지원 포맷은 실제 시험이 필요하다.

**후속 검증:** 색·법선·마스크 대표 맵을 선정해 선명도, 로딩 지연, 최대 메모리와 최종 GPU 포맷을 비교한다. 기존 PNG 경로를 보존한다.

근거: [S11](https://github.com/KhronosGroup/KTX-Software) · [S12](https://github.com/KhronosGroup/KTX-Software/blob/main/LICENSE.md) · [S13](https://github.com/atteneder/KtxUnity) · [S14](https://github.com/atteneder/KtxUnity/blob/main/LICENSE.md)

<a id="xatlas_uv2"></a>
## 8. xatlas — 고유 UV 생성 라이브러리

**[WATCH] / 오픈소스 C++ 라이브러리**

TexTools의 편집 보조와 다른 자동 UV 생성 경로 후보.

**용도:** 정적 역·객차 실내 모듈의 라이트맵용 UV를 만드는 보조 후보.

**출처 확인:** 제작자는 외부 의존성 없는 C++11 라이브러리로, 라이트맵 베이크나 텍스처 페인팅에 적합한 고유 UV를 만든다고 설명한다. MIT 라이선스 확인.

**적용 제안:** 기존 색 텍스처용 UV를 보존한 채 베이크용 UV를 별도 비교한다. 반복 타일 UV를 자동으로 전부 교체하지 않는다.

**형식·호환:** 라이브러리/예제이며 Blender 4.5용 플러그인 완제품이 아니다. 연동 방식·빌드·입출력 검수 필요.

**권리:** 라이브러리 MIT. 포함 예제 모델까지 같은 조건이라고 가정하지 않는다.

**파일·AI 처리:** 자작 변환 단계의 후보로만 기록. 외부 메시나 예제 모델을 복제/전송하지 않았다.

**미확인·한계:** 겹치지 않는 UV 생성은 조명 베이크 성공·빛샘 제거·최적 텍셀 밀도를 보증하지 않는다. 재색인된 정점과 재질/스키닝 데이터의 연결도 확인해야 한다.

**후속 검증:** 작은 정적 모듈에서 기존 UV 보존, 패딩·섬 수·재색인·베이크 이음새를 검사한다.

근거: [S15](https://github.com/jpcy/xatlas) · [S16](https://github.com/jpcy/xatlas/blob/master/LICENSE)

<a id="unity_memory_profiler"></a>
## 9. Unity Memory Profiler — Player 스냅샷 비교

**[WATCH] / 공식 엔진 검수 패키지**

자산 최적화 도구와 별개인 실사용 메모리 검증 수단.

**용도:** 열차 홈→필드→복귀 전후의 잔류 자산·누적 메모리 확인.

**출처 확인:** 공식 문서는 Editor, 로컬 Player, 연결 기기의 스냅샷 수집과 두 스냅샷 비교를 설명한다. 기본 대상은 Editor다.

**적용 제안:** 모바일 판정은 실제 대상 기기의 Player를 명시하고 동일 경로 왕복 전후를 비교한다. 에디터 수치를 휴대폰 점유량으로 보고하지 않는다.

**형식·호환:** Unity 패키지 1.1 문서 기준. 실제 선택 버전과 S2 프로젝트 요구 조건은 후속 고정.

**권리:** Unity 패키지 고지·이용 조건을 따른다. CC0 에셋으로 분류하지 않는다.

**파일·AI 처리:** 메모리 덤프를 공개 저장소에 자동 올리지 않고 요약 지표만 남기는 방안을 권한다. 이번 스냅샷 수집/전송 없음.

**미확인·한계:** 메모리 비교는 FPS·발열·GPU 시간 검사를 대신하지 않는다. 스냅샷 수집 자체의 비용도 실제 실행에서 구분한다.

**후속 검증:** 기기·빌드·장면·품질 설정을 고정하고 왕복 후 텍스처·메시·오디오 잔류와 증가량을 비교한다.

근거: [S17](https://docs.unity3d.com/Packages/com.unity.memoryprofiler@1.1/manual/index.html) · [S18](https://docs.unity3d.com/Packages/com.unity.memoryprofiler@1.1/manual/snapshot-capture.html)

## Blender 4.5 기준 제외

### [BLOCKED] Blender Asset Tracer v2 — Blender 4.5 기본 경로에서 제외

제작자 PyPI와 공식 staging README가 Blender 5.1 이상을 요구한다. 별도 4.5 프로젝트를 자동 업그레이드하거나 v1 호환을 추정하지 않는다. v2에 관한 캐시 누락 경고도 있어 모든 의존성을 완벽하게 수집한다고 보증하지 않는다. 도구 자체의 사용 금지가 아니라 현재 설치 버전과의 불일치다.

[S19](https://pypi.org/project/blender-asset-tracer/) · [S20](https://projects.staging.blender.org/blender/blender-asset-tracer/src/branch/main/README.md)

## 조회 한계와 잘못 읽기 쉬운 부분

MakeHuman 원본은 HTTPS 열람이 실패했고 Exa의 HTTP 원문으로 확인했다. URL을 검증된 HTTPS로 임의 변환하지 않았으며, 검사기는 해당 출처의 명시적 HTTP 사유만 예외로 인정한다. 일반 다운로드 허용목록이 아니다.

dress03 검색 요약과 본문 파싱이 달라 코트의 근거를 제작자 페이지와 MHCLO 머리말로 좁혔다. HTTP 메타데이터 일부 열람을 전체 패키지 취득으로 기록하지 않는다.

Flamenco/BAT 일부 기본 웹 경로는 열람 실패했다. Exa 원문과 BAT 제작자 PyPI, 공식 staging 미러를 구분했다. 새 도구가 최신이라는 이유로 Blender 4.5와 호환된다고 쓰지 않는다.

Poly Haven의 Hospital Room 2는 HDRI다. 병원 실내 메시·실제 중앙유럽 의료시설 도면을 이번에 확보했다는 근거로 쓰지 않는다.

새 자료는 연구 후보다. 방한복·배관·메모리 도구를 찾았다는 사실로 게임 기능·차종·URP 버전·최종 화풍을 확정하지 않는다.

## 남은 검증

- 겨울 코트와 목도리의 실제 메시·체형별 겹침·동작 관통·목도리 라이선스 버전
- 배관 밸브/침상 구성품 분리와 상호작용 소켓
- 화실 급탄·두 사람 부축/들것의 실제 궤적과 짝 클립 검수
- 중앙유럽 역/병원 실내 모듈과 최종 기관차 치수 도면
- Flamenco 선택 릴리스의 Blender 4.5 지원과 컴퓨터 사이 저장소 설계
- 엔진 임포트·기기 메모리·GPU 비용·발열의 실제 측정

## 출처 장부

| ID | 자료 | 열람 범위 |
|---|---|---|
| S01 | [punkduck Winter coat 제작자 페이지](http://makehumancommunity.org/clothes/winter_coat.html) | Exa로 HTTP 원문 열람. HTTPS 직접 열람 실패. |
| S02 | [coat.mhclo 원본 메타데이터](http://www.makehumancommunity.org/sites/default/files/clothes/1665/1679758305/coat.mhclo) | Exa로 파일 머리말의 author/license/basemesh/obj_file 확인. 완성 패키지·메시를 취득하거나 실행한 것은 아님. |
| S03 | [Elvs Ladies winter scarf 1 OC 제작자 페이지](http://makehumancommunity.org/clothes/elvs_ladies_winter_scarf_1_oc.html) | Exa로 제작자 설명·파일명·CC-BY 열람. HTTPS 직접 열람 실패. |
| S04 | [Poly Haven Modular Industrial Pipes 01](https://polyhaven.com/a/modular_industrial_pipes_01) | 자산 종류·제공 형식·맵 목록·제작자·CC0 표시 열람. 패키지 미취득. |
| S05 | [Poly Haven Vintage Day Bed](https://polyhaven.com/a/vintage_day_bed) | 모델 설명·제공 형식·제작자·CC0 표시 열람. 메시 파트 구성은 미검사. |
| S06 | [Poly Haven Asset License 및 사이트 이용 조건](https://polyhaven.com/license) | CC0 자산과 웹사이트 이용 조건을 구분하는 본문 열람. |
| S07 | [Blender 4.5 Packed Data](https://docs.blender.org/manual/en/4.5/files/blend/packed_data.html) | 기본 웹 열람 실패 후 Exa로 공식 본문 확인. |
| S08 | [Flamenco About](https://flamenco.blender.org/about/) | Exa로 공식 설계 원칙·구성·인증 범위 열람. |
| S09 | [Flamenco 공식 소개](https://flamenco.blender.org/) | Exa로 GPL 3.0·자체 호스팅 렌더 관리 설명 열람. |
| S10 | [Flamenco Shared Storage](https://flamenco.blender.org/usage/shared-storage/) | 공유 저장소·Windows 경로·비동기 동기화 서비스 제약 본문 열람. |
| S11 | [Khronos KTX-Software README](https://github.com/KhronosGroup/KTX-Software) | 공식 저장소 README의 KTX2·Basis·CLI 설명 열람. |
| S12 | [KTX-Software LICENSE.md](https://github.com/KhronosGroup/KTX-Software/blob/main/LICENSE.md) | 일반 Apache-2.0 및 별도 라이선스/비오픈소스 예외 본문 열람. |
| S13 | [KtxUnity README](https://github.com/atteneder/KtxUnity) | 제작자 README의 KTX2/Basis·플랫폼·비동기 로딩 API 확인. 패키지 실행 안 함. |
| S14 | [KtxUnity LICENSE.md](https://github.com/atteneder/KtxUnity/blob/main/LICENSE.md) | Apache-2.0 표기 확인. |
| S15 | [xatlas README](https://github.com/jpcy/xatlas) | 원작자 저장소에서 C++11 UV 생성 라이브러리 설명 확인. |
| S16 | [xatlas LICENSE](https://github.com/jpcy/xatlas/blob/master/LICENSE) | 원작자 MIT 라이선스 확인. 예제 모델의 별도 권리는 전수검토 안 함. |
| S17 | [Unity Memory Profiler 1.1 개요](https://docs.unity3d.com/Packages/com.unity.memoryprofiler@1.1/manual/index.html) | 공식 기능 설명 열람. 조회 페이지 사이 세부 패치 표시는 달라 채택 패치를 고정하지 않음. |
| S18 | [Memory Profiler 스냅샷 수집·비교](https://docs.unity3d.com/Packages/com.unity.memoryprofiler@1.1/manual/snapshot-capture.html) | Editor/Player/연결 기기 선택과 두 스냅샷 비교 본문 열람. |
| S19 | [Blender Asset Tracer 제작자 PyPI 배포 정보](https://pypi.org/project/blender-asset-tracer/) | 제작자 배포 설명을 웹/Exa로 확인. v2가 Blender 5.1 이상을 요구함. |
| S20 | [Blender Asset Tracer 공식 staging 미러 README](https://projects.staging.blender.org/blender/blender-asset-tracer/src/branch/main/README.md) | 본 저장소 열람 실패 후 공식 staging 미러를 Exa로 대조. 본 저장소와 동일 시점임을 보증하지 않음. |
| S21 | [Poly Haven Hospital Room 2](https://polyhaven.com/a/hospital_room_2) | HDRI·EXR/HDR 제공임을 확인. 이동 가능한 병원 실내 메시로 분류하지 않음. |

## 저장·검사

GitHub 연구 브랜치의 원문과 COS 로컬 파일을 같은 커밋으로 맞춘다. 검사 기록은 `research_index_validation_v5.json`에, 실제 동작 결과는 후속 제작 단계에 별도로 남긴다. 목록 검사가 통과해도 에셋 품질·엔진 임포트·모바일 성능을 검증한 것은 아니다.
