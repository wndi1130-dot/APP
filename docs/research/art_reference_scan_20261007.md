# 3D 모델 렌더용 참고 그림 조사

조사일: 2026-10-07. 모델 컨셉 렌더(docs/art/model_renders_20261007.md)에 붙일 참고 그림을 다섯 갈래로 모으며 남긴 메모다.
그림 파일은 저작권 때문에 저장소에 넣지 않고 작업자 PC의 로컬 `ref` 폴더에만 둔다. 이 문서의 파일 이름은 그 로컬 파일을 가리킨다.

## R1. 좀보이드 게임 화면과 사람 크기

조사 상태: 일부 완료.

조사·다운로드 날짜: **2026-10-07**. 실제 게임 화면 4장과 대표 이미지 PNG 사본 1장을 받았다. 공식 개발사 블로그와 공식 Steam 상점에서만 수집했다. 파일은 이 PC의 작업 폴더에 저장했으며 외부 게시·업로드는 하지 않았다.

장면 구성은 모두 확보했으나 **Steam의 낮 설경·좀비 무리 2장에는 개별 빌드 번호가 없고, 야외 화면의 정확한 기본 줌 값도 확인할 수 없어 PARTIAL로 기록한다.** 공식 블로그에서 Build 42 맥락이 확인되는 밤 설경과 실내 화면은 별도로 구분했다.

### 받은 그림과 사람 크기

비율은 저장된 이미지 전체 높이를 기준으로, 얼굴 위쪽부터 발끝까지 보이는 인물 한 명을 눈대중으로 비교한 **추정**이다. UI가 제거된 홍보용 촬영본이므로 실제 플레이 화면의 줌 설정이나 모바일 게임의 목표 크기와 같다고 단정하지 않는다.

| 파일 이름 | 한 줄 설명 | 화면 높이 대비 사람 크기 — 추정 | 빌드 확인 상태 |
|---|---|---|---|
| `R1_zomboid_snow_1.jpg` | 낮의 눈 덮인 호숫가 건물·부두와 작업·낚시하는 작은 인물들. | **약 5~6%**. 보라색 차 왼쪽에 서 있는 인물 및 부두의 서 있는 인물 기준. | 공식 Steam 상점의 현재 스크린샷. **개별 빌드 번호 미표기·Build 42 여부 미확인**. |
| `R1_zomboid_snow_2.jpg` | 눈 내리는 Muldraugh의 밤 주택가. 가로등·창문 조명과 어두운 인물 실루엣. | **약 2.5~3%**. 주택 사이 길에 서 있는 인물 기준. | 공식 **Build 42.20 소개 글**에서 확인. 카메라가 멀리 떨어진 원경. |
| `R1_zomboid_cutaway.jpg` | 어두운 상점 건물에서 벽·지붕이 잘려 2층 생활 공간과 가구·인물이 보이는 화면. | **약 10~12%**. 탁자 앞 **앉은 사람의 머리~발끝** 기준이며, 서 있는 사람의 키 비율은 측정할 수 없음. | 공식 **Build 42 업데이트 글**의 게임 화면. |
| `R1_zomboid_horde.jpg` | 낮의 거리에서 한 사람이 다수 좀비와 맞서며, 불타는 시체·차도·건물이 함께 보이는 화면. | **약 6%**. 화면 중앙의 파란 모자 인물 기준. 주변의 서 있는 좀비도 대략 **5~7%**. | 공식 Steam 상점의 현재 스크린샷. **개별 빌드 번호 미표기·Build 42 여부 미확인**. |
| `ref_fidelity.png` | `R1_zomboid_snow_1.jpg`를 같은 구도·크기로 PNG 변환한 대표 이미지. | 원본과 동일한 **약 5~6%**. | 원본과 동일. |

모든 최종 이미지의 긴 변은 1600px 이하이다. 비율을 유지해 줄였으며 자르기·내용 합성·새 그림 생성은 하지 않았다. Build 41이라고 확인된 사진은 없으므로 `_b41` 파일은 만들지 않았다. 빌드가 미표기된 사진을 Build 42 확정 화면으로 취급하면 안 된다.

### 대표 이미지 선택

**`ref_fidelity.png`는 낮 설경을 선택했다. 밝은 눈 위에서 인물의 작은 덩어리와 흐릿한 세부, 건물·차·부두의 마감, 화면 전체에서 사람이 차지하는 크기를 함께 비교하기 쉽기 때문이다.**

다음 렌더에서는 이 이미지의 **화면에 작게 보이는 사람과 재질의 세부 표현 정도**를 참고한다. 거대한 건물·조경의 복잡함까지 게임의 제작 목표로 옮길 필요는 없다. 이 파일의 Build 42 여부 및 정확한 기본 줌 값은 미확인 상태임을 함께 전달한다.

### 출처

- 낮 설경·좀비 무리: [Project Zomboid 공식 Steam 상점](https://store.steampowered.com/app/108600/Project_Zomboid/). 상점이 제공하는 직접 스크린샷 파일을 받았으며, 이미지별 빌드·줌 수치는 표시되지 않았다.
- 밤 설경: [42.20: The Big Glow Up](https://projectzomboid.com/blog/news/2026/07/42-20-the-big-glow-up/). 본문의 “A snowy night in Muldraugh” 화면을 받았다.
- 어두운 실내: [BALANCING TIME](https://projectzomboid.com/blog/news/2026/03/balancing-time/). 해당 Build 42 업데이트 글의 실내 게임 화면을 받았다.

각 파일의 출처·설명·알려진 라이선스 상태·수집 날짜는 `ref/sources.txt` 끝에 덧붙였다. 이미지에 별도 자유 이용 라이선스가 명시되어 있는지는 확인되지 않았다. 

### 못 받은 것·확인하지 못한 것

- **Build 42이고 기본 줌이라고 모두 명시된 낮 겨울 야외 화면:** 확보하지 못했다. 받은 낮 설경은 실제 공식 상점 게임 화면이지만 개별 빌드 번호·줌 설정이 없다. 밤 설경은 Build 42 맥락이 확인되지만 원경이므로 기본 줌 장면으로 주장하지 않는다.
- **개별 이미지에서 Build 42라고 명시된 좀비 무리 화면:** 확보하지 못했다. 받은 무리 장면은 공식 상점 게임 화면이며 다수 좀비가 분명히 보이지만 개별 빌드 번호는 확인되지 않았다.
- 로그인·결제·프로그램 설치 때문에 건너뛴 출처는 없다. 초기에 실행 환경의 프록시 연결 오류가 있었으며 실행 권한을 바꿔 재시도한 뒤 최종 이미지 다운로드는 모두 성공했다.
- 공식 블로그의 같은 장소 사진과 Steam 사진은 **서로 다른 촬영본**이었다. 원본을 대조한 뒤 설경·무리 장면은 Steam 사진으로 확정했다. 개발자 실사 사진, 기능 안내표, 요청 장면과 맞지 않는 후보는 최종 `ref/` 목록에 넣지 않았다.

### 확인 결과

최종 JPG 4장과 PNG 1장을 실제로 열어 장면을 확인했다. 파일 형식·해상도·파일 크기·SHA-256을 확인했고, 대표 PNG는 선정한 JPG와 같은 크기와 구도로 저장했다. 빌드 번호·기본 줌·서 있는 실내 인물 키는 위에 적은 범위만 확인했으며, 미확인 항목을 완료로 간주하지 않았다.

## R2. 저폴리 에셋 팩 미리보기

조사 상태: 완료.

### 받은 그림

- `R2_quaternius_base.jpg` — Universal Base Characters 캐릭터 6종 대표 렌더
- `R2_quaternius_anim.jpg` — Universal Animation Library 동작 포즈 렌더
- `R2_kenney_train.jpg` — 열차·객차·화물차·선로 구성
- `R2_kenney_buildings.jpg` — 건물 모듈과 형태 변형 구성
- `R2_kenney_furniture.jpg` — 실내 가구와 문·계단 구성
- `R2_mpfb_example.jpg` — MPFB 문서의 Blender 미텍스처 인체 메시 화면

### 공식 페이지에서 확인한 팩 정보

- **Quaternius Universal Base Characters** — 팩 페이지에 CC0 표기가 있고, 인물 모델 평균 약 13k triangles로 기재되어 있다. 6개 기본 모델과 20개 헤어스타일을 설명한다. 텍스처 해상도는 페이지에 기재되지 않았다. 미리보기 이미지 자체의 별도 라이선스 표기는 확인하지 못했다. [공식 페이지](https://quaternius.com/packs/universalbasecharacters.html)
- **Quaternius Universal Animation Library** — 공식 페이지에 CC0, 120개 이상 애니메이션이 기재되어 있다. 폴리곤 수·텍스처 크기 항목은 없다. 미리보기 이미지 자체의 별도 라이선스 표기는 확인하지 못했다. [공식 페이지](https://quaternius.com/packs/universalanimationlibrary.html)
- **Kenney Train Kit** — CC0, 공식 페이지 `Files 100×` 표기. 폴리곤 수와 텍스처 크기는 기재되지 않았다. [공식 페이지](https://kenney.nl/assets/train-kit)
- **Kenney Modular Buildings** — CC0, 공식 페이지 `Files 100×` 표기. 폴리곤 수와 텍스처 크기는 기재되지 않았다. [공식 페이지](https://kenney.nl/assets/modular-buildings)
- **Kenney Furniture Kit** — CC0, 공식 페이지 `Files 140×` 표기. 폴리곤 수와 텍스처 크기는 기재되지 않았다. [공식 페이지](https://kenney.nl/assets/furniture-kit)
- **MPFB 예시** — 공식 시작 문서가 설명하는 Blender의 미텍스처 기본 인체 메시 화면이다. 해당 스크린샷의 별도 라이선스와 모델 폴리곤·텍스처 정보는 페이지에서 확인하지 못했다. [공식 문서](https://static.makehumancommunity.org/mpfb/docs/getting_started.html)

`Files` 수치는 공식 페이지에 적힌 파일 수 표기이며 폴리곤 수나 텍스처 크기를 뜻하지 않는다. `ref\sources.txt`에는 기존 내용을 덮지 않고 출처 여섯 줄을 끝에 추가했다.

### 못 받은 항목

- 없음.

## R3. 폰 탑뷰 생존·좀비 게임 화면

조사 상태: 완료.

수집일: 2026-10-07. 서로 다른 게임의 실제 화면 3장을 확보했다. 세 이미지의 긴 변은 1600px 이하로 맞췄다. `ref\ref_fidelity.png`는 이미 있어 복사하지 않았다.

### 받은 그림

1. `R3_mobile_SASZombieAssault4.jpg` — SAS: Zombie Assault 4의 전투 화면. 사선 탑뷰에 작은 플레이어와 좀비 무리, 모바일 HUD가 함께 보인다.
   - 출시: 2014년.
   - 사람 키: 화면 높이의 약 6%로 추정.
   - 좀보이드보다 마감이 낮거나 비슷하다. 더 단순한 2.5D 표현이며, 좁은 화면에서 적 무리를 읽히게 하는 구도 참고에 맞는다.
   - 출처: [Google Play 공식 화면](https://play.google.com/store/apps/details?id=com.ninjakiwi.sasza4), [Apple 공식 출시 정보](https://itunes.apple.com/lookup?id=899159669&country=us).

2. `R3_mobile_GrimSoul.jpg` — Grim Soul: Survival Magic RPG의 보스 전투 화면. 캐릭터와 여러 적, 모바일 조작 HUD가 보인다.
   - 출시: 2018년.
   - 사람 키: 화면 높이의 약 17%로 추정.
   - 좀보이드보다 그래픽 마감이 높다. 모델·재질·광원 효과가 더 선명하며, 분위기는 중세 판타지다.
   - 출처: [App Store 공식 화면](https://apps.apple.com/us/app/grim-soul-survival-magic-rpg/id1366215798), [Apple 공식 출시 정보](https://itunes.apple.com/lookup?id=1366215798&country=us).

3. `R3_mobile_DYSMANTLE.jpg` — DYSMANTLE의 주유소 폐허 장면. 사선 3D 탑뷰에서 주인공과 감염자 두 명, 주변 공간의 크기가 보인다. 공식 presskit의 게임 화면이며 HUD는 없다.
   - 출시: 원작 2021년, 모바일판 2022년.
   - 사람 키: 화면 높이의 약 6%로 추정.
   - 좀보이드보다 그래픽 마감이 높다. 그림자·재질·환경 모델이 더 정돈됐고, 형태는 단순하고 양식화됐다.
   - 출처: [10tons 공식 presskit 원본](https://presskit.10tons.com/dysmantle/images/shot-06.png), [모바일 App Store](https://apps.apple.com/us/app/dysmantle/id1403738209), [개발사 출시 정보](https://presskit.10tons.com/sheet.php?p=dysmantle). Presskit 화면이 모바일 기기에서 캡처됐는지는 확인하지 않았다.

### 못 받은 것과 이유

필수 범위인 서로 다른 게임 3장은 확보했으며 로그인·결제 때문에 못 받은 그림은 없다. 추가 후보로 확인한 일부 공식 스토어 화면은 큰 문구가 합성된 홍보 컷이라 실제 플레이 화면 우선 조건에 따라 제외했다. 4번째 그림은 선택 범위여서 더 수집하지 않았다.

## R4. 열차 실물 사진과 저폴리 열차

조사 상태: 완료.

### 받은 그림

- R4_real_loco_plough_1.jpg — 1962–63년 독일 Burladingen의 폭설 속에서 증기기관차 Lok 12가 앞 제설차로 눈을 치우는 장면. 기록에는 계열/형식명이 따로 적혀 있지 않습니다.
- R4_real_loco_plough_2.jpg — DR 99 791과 앞에 연결된 쐐기형 제설차 97-09-59의 측면. 눈 풍경은 아니며 제설차 형태를 보기 위한 보조 사진입니다.
- R4_real_wooden_car.jpg — 1920년 Breslau에서 제작한 프러시아 구획 객차 Halle 4033. 외판 일부를 제거해 목조 차체 골격이 보입니다.
- R4_real_dining_interior.jpg — 1950년대 스웨덴 철도 Dollartåget 식당차 내부. 중부 유럽이 아닌 스웨덴 자료입니다.
- R4_real_freight_wagon.jpg — 독일 유개화차(1920~50년대형). 붉은 목판 측벽과 중앙 미닫이문이 보입니다.
- R4_lowpoly_train_1.jpg — 저폴리 증기기관차와 개방형 화차 모델 미리보기.
- R4_lowpoly_train_2.jpg — 단순화한 증기기관차 모델 미리보기.

### 저폴리 모델 정보

- Low Poly Train With Open Carriage — 작가 MythicaI, Sketchfab CC Attribution(페이지에 버전 표기 없음), 9.8k triangles / 5.4k vertices.
- Steam Locomotive Low Poly — 작가 bohdan.cooperation, Sketchfab CC Attribution(페이지에 버전 표기 없음), 13.3k triangles / 7.1k vertices.

### 못 받은 것과 이유

- 없음. 요청한 실물 사진과 저폴리 미리보기 7장을 저장했습니다.

### 확인 메모

- 모든 저장 이미지의 긴 변은 1600px 이하입니다.
- 실물 사진과 모델 미리보기는 사용자 PC의 로컬 참고용입니다.

## R5. 단면·벽 자르기 화면

조사 상태: 일부 완료.

### 받은 그림
- `R5_side_section_fallout_shelter.jpg` — 여러 층의 방과 복도가 옆 단면으로 이어지는 지하 볼트 화면.
- `R5_side_section_sheltered.jpg` — 지상 기지와 지하 쉼터 방들이 층별 단면으로 보이는 화면.
- `R5_wall_cutout.jpg` — 사선 탑뷰에서 지붕과 일부 벽이 빠져 차고 내부가 드러난 화면.

### 못 받은 것과 이유
- `R5_exploded_view.jpg` — Justin T Phillips의 공개 ArtStation 포트폴리오에서 건물 부품 분해도를 확인했지만, 페이지 이미지 저장 중 브라우저 보안 권한 확인이 결정 전에 닫혀 내려받지 못함. 출처: https://justintphillips.artstation.com/projects/5X9Kk8
