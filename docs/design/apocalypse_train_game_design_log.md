# 설국열차 × Frostpunk × HOI4 × Project Zomboid
## 모바일 탑뷰 아포칼립스 생존·내정 게임 — 대화 아카이브 및 조사 메모

- 정리일: 2026-10-05
- 문서 성격: 현재 대화에서 논의된 아이디어, 설계 가설, 조사 결과, 출처를 통합한 작업용 Markdown 문서
- 주의: 아래의 게임 비평·후기 내용은 공개 리뷰와 이용자 후기를 요약한 것이다. 개별 후기는 전체 이용자를 대표하지 않는다. 얼리 액세스/과거 버전 리뷰는 당시 문제를 보여주는 참고자료로만 사용한다.

---

# 0. 한 줄 콘셉트

**달리는 열차를 이동식 사회·기지로 운영하면서, 실제 철도역과 주변 지역에 정차해 직접 파밍·전투·구조를 수행하고, 확보한 자원과 현장에서의 선택이 열차 내부의 경제·정치·생존·탄핵 위험으로 되돌아오는 3D 사선 탑뷰 아포칼립스 생존 게임.**

핵심 레퍼런스:

- **Snowpiercer**: 닫힌 이동 사회, 계급·정치·추방·열차라는 상징적 공간
- **Frostpunk / Frostpunk 2**: 혹한, 생존 경제, 법·정치, 파벌, 신뢰, 잔혹한 선택
- **Hearts of Iron IV**: 인력·생산·보급·우선순위의 연결
- **Civilization VI**: 장기 투자, 발전 방향, 지역/자원에 따른 전략적 선택
- **Project Zomboid**: 사선 탑뷰, 탐색·파밍·전투, 높은 자유도, 장소를 읽고 활용하는 생존
- **Suzerain**: 선택 누적, 인물·정책·약속의 후속 효과, 보고서와 정치적 피드백
- **Galaxy on Fire식 퀘스트 구조**: 주 경로 중간에 장애물·시련·사이드 이벤트 삽입

---

# 1. 현재까지의 대화 흐름

## 1.1 모바일에서 Project Zomboid와 매우 유사한 게임이 있는가

### 사용자 문제의식

- 모바일에 **Project Zomboid처럼 탑뷰 싱글 중심이면서 멀티도 지원하고, 자유도가 매우 높은 아포칼립스 게임**이 있는지 확인.
- 단순 좀비 액션이나 양산형 기지건설 게임이 아니라, 좀보이드에 매우 가까운 자유도를 찾고자 함.

### 조사된 비교작

#### Project Deathless: Survival
- 모바일에서 Zomboid/Mini DAYZ 계열의 직접적 비교작.
- 절차 생성 맵, 차량 수리·연료, 상처·골절·출혈·감염, 제작·탐색 등 세밀한 생존 요소를 표방.
- 다만 멀티 지원과 실제 시스템 깊이는 별도 검증 필요.

#### Dead Town Survival
- 탑뷰 좀비 생존, 거점 건설, 온라인 멀티 지원 확인.
- 거점 방어와 전투 비중이 비교적 큼.
- 좀보이드 수준의 생활 시뮬레이션과는 차이가 있음.

#### Cataclysm: Dark Days Ahead
- 절차 생성 아포칼립스, 높은 자유도, 차량·생존 시스템.
- 턴제이고 공식 멀티가 없다는 점에서 직접 경쟁작과는 차이.

#### DYSMANTLE
- 오픈월드, 파괴·수집·제작·농사·거점 요소.
- 액션 RPG 성격이 강함.

#### Last Day on Earth / Prey Day
- 모바일 탑뷰·생존·기지·멀티를 포함하지만, MMORPG/온라인 서비스형 구조가 강함.

### 당시 결론

모바일 시장에 ‘탑뷰 좀비 생존’은 존재하지만, **좀보이드의 자유도 + 깊은 내정 + 독립 싱글 + 선택적 멀티 + 이동식 열차 사회**를 한데 결합한 형태는 여전히 설계 여지가 크다.

---

## 1.2 핵심 게임 콘셉트 제시

사용자가 제시한 기본 구조:

- **설국열차 + Frostpunk + Hearts of Iron IV + Project Zomboid**
- 열차가 계속 이동한다.
- 열차 내부에서는:
  - 정치 시스템
  - 경제 시스템
  - 건설
  - 추방
  - 시련/위기
  - 배급
  - 주민/파벌 관리
- 역·스테이션·특정 지역에 정차하면:
  - 3D 사선 탑뷰
  - 파밍
  - 구조
  - 전투
  - 위험한 선택
- 외부 압력:
  - Frostpunk식 살인적인 추위
  - 좀비 웨이브/추적
- 필수 물자를 제때 확보하지 못하거나 사회를 심각하게 실패시키면:
  - 열차장 지위에 대한 **탄핵/신임 심판** 발생

### 스토리 초안

1. 열차는 지옥 같은 혹한과 좀비 사태를 피해 이동.
2. 먼 곳에서 송출되는 생존자 라디오 신호를 따라감.
3. 스토리 중반, 막대한 희생을 치르고 신호 지점에 도착.
4. 그러나 생존자는 이미 전멸.
5. 라디오는 **진화한 좀비가 내는 미끼 신호**였음.
6. 좀비가 학습·진화하고 있다는 사실이 드러남.
7. 이후 추적이 더욱 거세짐.
8. 최종 챕터는 열차를 섬으로 돌리고, 철도 연결을 끊은 뒤 최종 방어.

### 무한 모드

- 영구 정착은 불가능.
- 좀비가 서서히 늘거나, 살인적인 한파가 주기적으로 찾아옴.
- 한곳에 정착하지 않고 계속 이동해야 하는 장기 생존 도전.
- 문자 그대로 ‘절대 정차하지 않음’보다는, **잠깐 정차해 보급하지만 영구 정착할 수 없음**이 기본 설계로 제안됨.

---

# 2. 핵심 게임 루프

현재까지 가장 적합하다고 정리된 루프:

```text
열차 이동
  ↓
다음 정차지·경로 선택
  ↓
정차 / 수색대 편성
  ↓
3D 탑뷰 탐색·전투·구조·파밍
  ↓
"더 남을 것인가 / 떠날 것인가" 판단
  ↓
열차 복귀
  ↓
자원·부상·사망·구조자 정산
  ↓
배급·생산·수리·인력·정치 결정
  ↓
약속 / 불만 / 파벌 반응 / 사건
  ↓
다음 경로로 출발
```

## 핵심 갈등

> **열차를 살리려면 멈춰야 하지만, 사람들을 살려 데려가려면 결국 떠나야 한다. 그리고 언제 떠났는지에 대한 책임을 열차장이 진다.**

이 갈등에 파밍·경제·건설·정치·전투를 모두 연결하는 것이 중심 설계 원칙.

---

# 3. 정치·탄핵 시스템

## 단순 실패 게이지로 만들면 안 되는 이유

‘식량이 부족하면 탄핵’만으로는 일반적인 행복도/불만 게이지와 차이가 없다.

정치적 책임은 다음을 함께 봐야 한다.

### 3.1 생활 피해
- 실제로 누가 굶었는가
- 누가 추위에 노출되었는가
- 누가 치료받지 못했는가

### 3.2 공정성
- 피해가 특정 계층/객차/직군에 집중되었는가
- 기관실·경비대 등에 특혜를 주었는가

### 3.3 신뢰
- 플레이어가 어떤 약속을 했는가
- 그 약속을 지켰는가
- 실패가 불가피했는가, 방치였는가

## 탄핵/신임 심판의 흐름

1. 생활 피해 발생
2. 특정 인물/파벌의 요구 제기
3. 열차장이 수락·거부·협상·기한 약속
4. 실제 정책 실행
5. 결과 축적
6. 신임 심판 / 파벌 이탈 / 반란 / 쿠데타 가능성

## 중요한 원칙

- 잔혹한 선택이 **실제로 위기를 해결할 수는 있어야 한다.**
- 그러나 그 비용은 이후 관계와 정치에 남는다.
- ‘악한 선택 = 무조건 손해’로 만들면 선택이 사라진다.
- ‘악한 선택 = 언제나 최적’이어도 선택이 사라진다.

---

# 4. 자원·내정 시스템

사용자가 원하는 핵심 자원:

- 석탄
- 목재
- 고철
- 식량
- + 의약품, 탄약, 희귀 부품 등

## 설계 원칙

자원 종류를 무작정 늘리기보다 **하나의 자원이 여러 용도를 놓고 경쟁하게** 한다.

| 자원 | 경쟁 용도 |
|---|---|
| 석탄 | 열차 이동 / 난방 / 일부 생산 |
| 목재 | 임시 거점 / 차단물 / 가구 / 비상 연료 |
| 고철 | 정비 / 객차 보강 / 공방 / 무기·설비 |
| 식량 | 기본 배급 / 추가 배급 / 저장 / 교섭 |
| 의약품 | 응급치료 / 중상자 / 전염병 대비 |
| 탄약 | 탐색 안전성 / 열차 방어 / 최종방어 |
| 희귀 부품 | 엔진·통신·난방·특수 객차 업그레이드 |

## 내정 시간 제한

사용자 선호:

> **파밍 이후 필수 내정이 10분을 넘으면 안 된다.**

권장 목표:

| 상황 | 필수 내정 목표 |
|---|---:|
| 변화가 적은 정차 후 | 1~3분 |
| 신규 인원·설비·경로 변화 | 3~5분 |
| 중요한 정치·생존 위기 | 5~8분 |
| 일반 진행의 상한 | 10분 이하 |

### 내정은 깊게, 반복 클릭은 적게

플레이어가 직접 정해야 하는 것:

- 배급 원칙
- 난방 우선순위
- 생산 목표
- 예비 자원 기준
- 인력 배치 원칙
- 정비 우선순위
- 정치적 요구에 대한 대응

시스템이 자동으로 처리할 것:

- 매 식사 개별 제작
- 반복 생산
- 평시 배급
- 기본 교대근무
- 루틴 정비
- 생산 큐 유지

핵심 문장:

> **내정을 얕게 만드는 것이 아니라, 내정을 실행하는 노동을 줄인다.**

---

# 5. 사건·시련 시스템

사용자가 추가로 원하는 사건 예시:

- 터널 붕괴
- 산사태로 선로 봉쇄
- 교량 파손
- 폭설·눈사태
- 엔진 고장
- 객차 난방 파열
- 감염자 발생
- 선로 분기기 고장
- 외부 생존자 구조 요청
- 약탈자/다른 열차/소규모 공동체와 조우

## 사건이 지루해지는 조건

- 주기적으로 정확히 같은 간격에 발생
- 대응법이 항상 동일
- 선택해도 결과가 숫자 ±5로 끝남
- 플레이어의 이전 행동과 무관
- 준비를 잘해도 항상 똑같이 당함

## 사건은 네 종류로 분류

### 세계 사건
- 한파
- 산사태
- 붕괴
- 외부 집단 이동

### 운영 결과
- 정비 지연
- 과로
- 배급 차별
- 소음 증가

### 정치/인물 사건
- 약속 불이행
- 권력 변화
- 파벌 갈등
- 가족/동료 관계

### 기회/회복 사건
- 구조 성공
- 새로운 설비 발견
- 예기치 못한 식량원
- 우호적인 집단

## 이벤트 설계 핵심

같은 ‘난방 배관 파열’도 이전 상태에 따라 결과가 달라져야 함.

- 예비 부품 + 건강한 정비팀 → 짧은 복구
- 부품 있음 + 정비팀 부상 → 다른 작업 포기 필요
- 부품 부족 → 설비 희생 또는 객차 폐쇄
- 난방 개선 약속을 이미 어김 → 기술 문제 + 정치 문제
- 이전 위기에서 공정하게 대응 → 주민이 임시 조치를 더 받아들일 수 있음

### 이벤트 효과의 3개 층

1. **세계가 바뀜**: 객차 폐쇄, 사람 이동, 설비 고장 등
2. **운영이 바뀜**: 생산·이동·치료·탐색 능력 변화
3. **사람이 기억함**: 후속 요구·신뢰·관계 변화

---

# 6. 파밍·탐색 시스템

## 피해야 할 구조

> 수십 명이 탄 열차를 운영하면서 플레이어 한 명이 같은 상자를 들고 20번 왕복한다.

대량 자원의 획득은 다음과 같이 바꾸는 방향:

```text
발견
→ 접근로 확보
→ 위협 제거/우회
→ 적재 수단 확보
→ 운반 인력 배치
→ 방어
→ 철수 시점 결정
```

소량의 의약품·탄약·개인 장비는 직접 파밍할 수 있지만, 대량의 석탄·목재·고철은 **작업 조건을 만들어 확보하는 형태**가 적합.

## 장소마다 달라야 하는 것은 ‘상자 위치’가 아니라 ‘주요 행동’

| 장소 | 핵심 행동 |
|---|---|
| 화물역 | 대량 적재 + 방어 |
| 터널 | 조명·시야·안전한 통과 |
| 산사태 | 중장비 / 수작업 / 우회 선택 |
| 병원 | 약품 / 구조 / 치료 우선순위 |
| 주택가 | 소음 관리·은밀 탐색 |
| 혹한 지역 | 임시 거점·체온·숙박 |

---

# 7. 현지 야영 / 임시 거점

사용자 제안:

- 장거리 파밍 중 근처 베이스를 조직해 하룻밤 묵을 수 있어야 함.

권장 방향:

- 열차와 별도의 ‘두 번째 도시’를 만드는 것이 아님.
- 건물 조건을 보고 **임시 거점**으로 활용.

| 후보 | 장점 | 부담 |
|---|---|---|
| 역 관리동 | 열차와 가까움 | 접근로가 많음 |
| 창고 | 물자 적재에 유리 | 난방·방어 불리 |
| 주택 | 보온·휴식 | 수용력 작음 |
| 의료시설 | 치료와 약품 | 위험 지역일 수 있음 |

필수 관리 요소는 최소화:

- 난방
- 경계
- 퇴로

야영한다고 반드시 밤마다 웨이브가 발생해서는 안 됨.

---

# 8. 그래픽·카메라·3D 제작 방향

## 그래픽 목표

- 화려한 그래픽보다 **Project Zomboid처럼 직관적인 사선 탑뷰**
- 낮은 그래픽 부담
- 작은 모바일 화면에서도 실루엣과 역할이 잘 보이는 디자인

## Blender로 충분한가

결론: **충분함.**

Blender 담당:

- 열차/객차
- 건물
- 가구/소품
- 캐릭터 모델
- 좀비 모델
- 리깅
- 애니메이션
- 재질
- 반복 구조 생성 스크립트

게임 엔진(Unity 등) 담당:

- 문 상호작용
- 충돌
- AI
- 체온
- 인벤토리
- 소음
- 좀비 반응
- 정치·경제 시스템
- 저장

## 모델링 전략

기성 에셋:

- 일반 건물
- 나무
- 상자
- 차량 잔해
- 일반 생존자/기본 좀비

고유 제작:

- 기관차
- 공통 객차 차체
- 객차 연결부
- 열차 핵심 설비
- 주요 변이 좀비
- 대표 캐릭터

## 캐릭터

초기에는 기본 몸체 1~2종을 공유하고:

- 복장
- 색상
- 장비
- 초상화
- 대사
- 관계

로 차별화.

---

# 9. AI 도구 역할 분담

현재 사용 가능:

- Claude Code
- Codex
- Gemini

권장 초기 역할:

## Claude Code — 게임 구현·통합

- Unity 프로젝트
- 카메라
- 이동
- 전투
- 정차 장면
- UI
- 기능 통합
- 메인 브랜치 통합 담당

## Codex — 시스템/자동화

- 자원 시스템
- 배급
- 정치 상태
- 저장/불러오기
- 데이터 구조
- Blender Python 자동화
- 객차 모듈 생성
- 테스트/검증 도구

## Gemini — 세계관·이벤트·캐릭터·각본

- 세계관 규칙
- 캐릭터 바이블
- 캠페인 큰 흐름
- 이벤트 대사
- 라디오
- 정치 사건
- 후속 분기

### Gemini 콘텐츠 출력 권장 필드

- event_id
- 발생 조건
- 발언자
- 본문
- 선택지
- 자원 변화
- 신뢰/관계 변화
- 후속 사건
- 반복 가능 여부

## 운영 원칙

- 동시에 메인 코드 수정자는 2명 정도로 제한
- 브랜치/워크트리 분리
- 통합 담당 고정
- 게임 상태/저장 형식 변경은 통합 담당이 조정
- “정치 시스템 전체” 대신 작동 가능한 작은 플레이 상황 단위로 업무 분해

---

# 10. 캠페인 분량과 맵 수

## 목표 플레이타임

사용자 목표:

- **약 15시간 캠페인**
- 생존 비중을 높임
- Galaxy on Fire처럼 다양한 퀘스트·장애물·시련으로 밀도 확보

## 단순 계산

15시간 × 60분 = 900분

만약 한 맵/정차가 20분이면:

- 900 ÷ 20 = **45회**

하지만 실제로는 열차 내정·정치·보고서 시간이 존재.

### 권장 초기 계산

- 외부 탐색/전투/시련: 약 12시간
- 열차 운영/정치/대화: 약 3시간

외부 12시간 = 720분

- 평균 20분/정차 → **약 36개 정차 구간**

추가로 대체 경로용 장소를 약 6개 만들면:

- **전체 제작 장소 약 42개**
- 1회 캠페인에서 실제 방문 약 36개

### 장소 제작 등급

| 분류 | 수량 예시 | 목표 |
|---|---:|---|
| 핵심 스토리/대형 시련 | 8 | 약 30분, 전용 연출·동선 |
| 일반 생존/보급 | 20 | 약 18분, 모듈형 |
| 짧은 위기/특수 장소 | 8 | 약 15분 |
| 대체 경로 | 6 | 재플레이/분기 |

**주의:** 야영·깊은 내정이 늘어나면 이 숫자는 다시 줄여야 함. 42개는 확정 제작량이 아니라 15시간 분량 계산용 가설.

---

# 11. 실제 철도역·도시 지도 기반 맵 제작

사용자 방향:

- 미국 또는 유럽 실제 철도역/철도 지도 기반
- Project Zomboid의 유명 모드맵처럼 실제 도시의 공간감을 살림

## 권장 3단 구조

### 1) 전체 여정 지도
현실에서 가져올 것:
- 철도 연결
- 역 순서
- 강/산/해안

게임에 맞게 바꿀 것:
- 일부 역 생략
- 이동시간 압축
- 봉쇄/폐선/우회 설정

### 2) 정차 지역 배치
현실에서 가져올 것:
- 역
- 창고
- 주택가
- 도로
- 하천
- 산업시설

게임에 맞게 바꿀 것:
- 빈 거리 압축
- 수색 가능한 범위 조정

### 3) 실제 플레이 공간
게임에서 별도 제작:
- 문/창문
- 실내
- 파밍 포인트
- 적
- 장애물
- 탈출 동선
- 야영 가능 위치

## 자료 후보

### OpenRailwayMap
- OpenStreetMap 기반 철도 인프라 지도
- 실제 철도망/역/선로 조사에 유용

URL: https://www.openrailwaymap.org/

### OpenStreetMap
- 지역 배치/도로/건물 외곽 등

URL: https://www.openstreetmap.org/

### BlenderGIS
- OSM XML, Shapefile, 표고 등 Blender 가져오기

URL: https://github.com/domlysz/BlenderGIS

## 주의

- 실제 지도에서 건물 외곽을 가져와도 게임용 실내와 상호작용은 별도 제작 필요.
- 실제 축척을 그대로 쓰면 빈 이동 시간이 너무 길어질 수 있음.
- 지리적 관계는 유지하되 플레이 공간은 압축.
- OSM/관련 데이터의 라이선스와 표시 의무 확인 필요.

---

# 12. 저장·체크포인트

모바일 기준으로 20분 맵이어도 중간저장이 반드시 필요.

## 권장 저장 계층

### 큰 체크포인트
- 지역 진입
- 수색대 출발
- 수색대 귀환
- 열차 출발
- 주요 정치적 결정
- 챕터 전환

### 플레이 중 자동저장
- 약 30~60초 간격을 시험
- 앱 백그라운드 전환 시 보조 저장
- 저장 후 나가기 지원

## 반드시 복원되어야 할 상태

- 캐릭터 위치
- 문/잠금 상태
- 가져간 물자
- 남은 물자
- 좀비 위치 또는 위협 상태
- 웨이브/추적 진행도
- 부상
- 임시 거점
- 열차 재고
- 생산 진행
- 정치적 약속/기한

---

# 13. 조사 게임별 핵심 교훈

## 13.1 Pandemic Train

### 장점
- 열차 + 생존 + 외부 탐색이라는 콘셉트 자체는 강함.
- 자원 부족과 도덕적 선택의 잠재력.

### 반복적으로 지적된 문제
- 열차 내 제작이 반복 클릭으로 변함.
- 작업 큐가 없고 동일 작업을 수동 반복.
- 외부 탐색이 같은 적·같은 맵·같은 보상 패턴으로 반복.
- 장기 성장감이 약함.
- 열차가 핵심 판타지인데 실제 관리 깊이는 제한적이라는 불만.
- 탐색·전투가 자동 탐색으로 건너뛰고 싶어질 정도로 반복적이라는 평가.

### 가져올 것
- 열차와 탐색의 결합
- 제한된 자원과 승무원 운영

### 버릴 것
- 음식 5개를 만들기 위해 같은 조작 5번
- 반복 전투/반복 맵
- ‘열차’가 사실상 메뉴 사이의 연결점에 불과한 구조

주요 출처:
- Steam negative reviews: https://steamcommunity.com/app/1379600/negativereviews/?browsefilter=toprated
- GOG analytical feedback: https://www.gog.com/forum/pandemic_train/pandemic_train_analytical_feedback_suggestions
- Steam positive reviews: https://steamcommunity.com/app/1379600/positivereviews/?browsefilter=toprated

---

## 13.2 Frostpunk 2

### 장점
- 파벌과 법률
- 약속과 협상
- 단기 위기를 해결하기 위해 미래의 정치적 빚을 지는 구조
- 작은 선택이 뒤늦게 큰 결과로 번지는 구조

### 비판
- 규모가 커지면서 도시와 주민에 대한 물리적 친밀감 감소.
- 추상화된 지구 단위 관리가 기존 Frostpunk의 손맛을 일부 잃음.
- 파벌 요구가 반복 업무처럼 느껴질 가능성.

### 가져올 것
- 약속의 기한
- 파벌 간 거래
- 현재 문제를 해결하기 위해 미래 자원을 담보하는 정치

### 주의할 것
- 주민을 숫자/막대기로만 만들지 않기
- 열차의 작은 사회라는 장점을 이용해 결정의 피해가 눈에 보이게 하기

출처:
- PC Gamer review: https://www.pcgamer.com/games/city-builder/frostpunk-2-review/
- Shacknews review: https://www.shacknews.com/article/141448/frostpunk-2-review-score
- IGN review: https://www.ign.com/articles/frostpunk-2-review
- Metacritic: https://www.metacritic.com/game/frostpunk-2/

---

## 13.3 Project Zomboid

### 장점
- 높은 시스템 자유도
- 장소와 사물을 상황에 맞게 활용
- 작은 실수와 욕심이 서사를 생성
- 플레이어 지식과 캐릭터 숙련이 함께 성장
- 생존 자체가 이야기 생성기로 작동
- 환경 스토리텔링

### 약점/논쟁점
- 초반 학습 장벽
- 장기 생존 후 ‘안정화 고원’에 도달하면 목표가 약해질 수 있음
- 무엇을 해야 하는지 스스로 정하지 못하는 플레이어에게는 공백이 큼

### 가져올 것
- 시스템 기반의 사건 생성
- 자유로운 야영/거점화
- ‘소음 → 좀비 접근 → 퇴로 봉쇄’처럼 행동이 연쇄 결과를 만듦

### 보완할 것
- 본 게임에는 캠페인 목적과 시련이 있으므로, 장기 안정 이후에도 새로운 목표를 제시
- 같은 적 체력만 늘리는 방식 대신 새로운 행동을 요구

출처:
- Steam reviews: https://steamcommunity.com/app/108600/reviews/?browsefilter=toprated
- Project Zomboid and the Peril of Endless Games: https://dissectinggamedesign.substack.com/p/project-zomboid-and-the-peril-of

---

## 13.4 Suzerain

### 장점
- 선택 누적
- 인물 관계와 정책이 함께 움직임
- 약속/정책/예산/여론이 후속 대사와 사건에 반영
- 보고서와 뉴스로 세계가 플레이어 선택에 반응

### 약점
- 텍스트가 너무 길어지면 템포가 느려짐
- 반복 플레이에서 큰 사건의 순서를 알고 나면 신선도가 줄 수 있음
- 숨겨진 점수 시스템과 서사 결과가 충돌하면 선택이 무효화된 느낌을 줄 수 있음

### 가져올 것
- 단일 선택 하나보다 여러 선택의 누적 결과
- 인물의 가치관과 정치적 이해관계 분리
- 국정/열차 보고서로 결정의 후속 효과 표시

### 버릴 것
- 모바일에서 긴 회의문을 연속해서 읽는 구조
- 플레이어가 이해할 수 없는 숨은 점수 하나로 엔딩을 덮어버리는 구조

출처:
- Articy 개발자 인터뷰: https://www.articy.com/en/showcase/suzerain/
- Matchsticks for My Eyes: https://www.matchstickeyes.com/2024/07/27/suzerain-a-narrative-game-that-brings-policy-politics-to-life/
- Vice review: https://www.vice.com/en/article/suzerain-game-review/
- The Game Crater review: https://www.thegamecrater.com/suzerain-review/

---

## 13.5 IXION

### 장점
- 이동식 거대 거주지 관리
- 생산망 안정화의 만족감
- 스토리·생존·자원 관리의 결합

### 문제
- 여러 재난을 한꺼번에 던질 때 인위적 난이도로 느껴질 수 있음
- 잘못된 설계의 결과가 너무 늦게 드러나면 사실상 재시작 강요
- 챕터 끝에 대량 자원 채우기식 과제가 늘어질 수 있음
- 마이크로매니지먼트와 QoL 부족 불만

### 교훈
- 위험은 예고되고 복구 가능해야 함
- ‘다음 이야기를 보려면 자원 1,000개 채우기’식 목표를 피함
- 플레이어가 잘 준비하면 실제로 쉬워져야 함

출처:
- PC Gamer: https://www.pcgamer.com/ixion-review/
- Rock Paper Shotgun: https://www.rockpapershotgun.com/ixion-review

---

## 13.6 Against the Storm

### 장점
- 같은 생산 시스템이라도 자원·주민·건물 조합이 달라져 매번 전략이 바뀜
- 투입 대비 효과가 명확한 UI
- 반복 플레이를 ‘다시 처음부터 노동’이 아니라 ‘새 퍼즐’로 만듦
- 끝나는 시점을 잘 잡아 장기 도시 건설의 지루함을 회피

### 교훈
- 모든 맵에서 같은 정답 빌드를 강제하지 않기
- 지역 조건이 열차의 기존 강점과 약점을 다르게 드러내게 하기
- 무한모드에서는 단순 난이도 상승보다 **조건 조합 변화**가 중요

출처:
- Eurogamer: https://www.eurogamer.net/against-the-storm-review-a-perfectly-chaotic-city-builder
- GameWatcher: https://www.gamewatcher.com/against-the-storm/review
- PCGamesN: https://www.pcgamesn.com/against-the-storm/review

---

## 13.7 The Alters

### 장점
- 생산 최소량 자동 유지 같은 QoL
- 통합 관리 화면
- 자원·기지·인물 관계의 연결
- 인물의 감정이 자원 시스템과 따로 놀지 않도록 설계

### 비판
- 반복 채굴과 이동이 업무처럼 느껴질 수 있음
- 자원 압박이 스토리를 방해할 수 있음
- 생산이 자동화되지 않으면 중후반에 반복 노동이 됨

### 교훈
- 자동화는 적극적으로 제공
- 그러나 자동화로 비운 시간에 **더 좋은 선택과 사건**이 들어가야 함

출처:
- IGN: https://www.ign.com/articles/the-alters-review
- GamesRadar: https://www.gamesradar.com/games/survival/the-alters-review/
- The Verge: https://www.theverge.com/games-review/685213/the-alters-review-ps5-xbox-steam
- PCGamesN: https://www.pcgamesn.com/the-alters/review

---

## 13.8 Last Train Home

### 장점
- 열차가 이동식 기지
- 전투 인력 = 열차 운영 인력이라는 연결
- 혹한·보급·병력 손실의 긴장

### 교훈
- 수색대에 누굴 보내느냐가 내부 생산·정비에 직접 영향을 주게 만들기
- 외부 전투의 피해가 내정에 실제로 반영되게 하기

출처:
- Steam: https://store.steampowered.com/app/1469610/Last_Train_Home/
- Steam discussion example: https://steamcommunity.com/app/1469610/discussions/0/4297069185834673957/

---

## 13.9 Zompiercer

### 장점
- 열차가 진짜 ‘집’으로 느껴지는 요소
- 직접 객차를 꾸미고 이동
- 손수 제작된 장소가 기억에 남는다는 후기

### 문제
- 장거리 걷기
- 정적 맵 반복
- 콘텐츠 부족

### 교훈
- 열차를 단순 메뉴가 아니라 플레이어가 애착을 갖는 공간으로 만들기
- 실제 지도를 쓸 때 빈 거리까지 사실적으로 재현하지 않기

출처:
- Steam reviews: https://steamcommunity.com/app/1262460/reviews/?browsefilter=toprated

---

# 14. UI·보고서·레이아웃

## 기본 철학

> **보고서는 계산을 대신하고, 장면은 성과를 보여준다.**

### 귀환 후 우선 보여줄 것

1. 이번 정차에서 확보한 것
2. 열차에서 실제로 달라진 것
3. 다음 구간을 버틸 여유
4. 아직 해결되지 않은 문제
5. 지금 결정해야 할 것

예시:

```text
[이번 정차 결과]
연료 +82
고철 +47
의약품 +13
정비공 1명 구조

[열차 변화]
후미 난방 복구
공방 재가동

[다음 구간]
이동 연료 충분
의약품 부족 지속

[결정 필요]
다음 경로에서 병원 우회 여부
```

## UI 3단계

### 지휘 화면
- 다음 구간에 필요한 물자
- 가장 중요한 문제 2~3개
- 최근 성과

### 운영 화면
- 객차 기능
- 인력
- 생산 목표
- 배급
- 난방
- 정비

### 상세 보고서
- 증감 원인
- 객차/집단별 배급
- 약속 이력
- 생산 병목
- 사고 원인

---

# 15. 현재까지의 명확한 설계 판정

## [PASS]

- 열차 = 이동식 사회 + 집 + 기지
- 외부 탐색과 내부 정치의 직접 연결
- 석탄/목재/고철/식량 중심 자원
- 지속되는 배급·난방·생산 방침
- 자동화된 반복 생산
- 실제 지리 기반 정차 지역
- 3D 사선 탑뷰
- 현지 임시 야영
- 약속/신뢰/공정성 기반 정치
- 준비를 잘하면 위기를 실제로 쉽게 넘길 수 있는 구조
- 중간 라디오 반전
- 캠페인 + 무한 생존

## [WATCH]

- 15시간 캠페인 규모는 1인 + AI 개발 기준 상당히 큼
- 36~42개 장소는 확정치가 아니라 분량 계산 가설
- 실제 지도 기반 맵은 실내/게임 동선의 추가 제작비가 큼
- 멀티는 저장/동기화/권한 설계가 별도 대형 작업
- 너무 많은 자원·파벌·인물 변수를 동시에 넣으면 모바일 UI가 무거워질 수 있음

## [PATCH REQUIRED]

- 필수 내정이 10분 이상 반복
- 매 정차마다 같은 생산 조작 반복
- 일정 주기의 랜덤 손실 이벤트
- 자원이 많아지면 그만큼 억지로 더 빼앗는 난이도 스케일링
- 같은 상자를 여러 번 나르는 반복 파밍
- ‘다음 스토리를 보기 위해 자원 X개 채우기’식 장시간 노가다
- 모든 장소의 플레이가 ‘적 죽이고 상자 털기’로 동일
- 정치가 호감도 막대 하나로 축약
- 준비 여부와 무관하게 고정 피해를 주는 스토리 반전
- 자동 탐색 버튼이 사실상 최적 선택이 되는 설계

---

# 16. 추천 첫 검증판

전체 게임을 만들기 전에 다음 하나의 플레이 구간을 완성하는 것이 권장됨.

## 상황

- 작은 화물역 도착
- 석탄과 고철 확보 필요
- 병원 수색대가 아직 돌아오지 않음
- 좀비가 서서히 접근
- 기온 하락

## 플레이어 선택

- 더 기다린다
- 추가 구조대를 보낸다
- 수색대를 버리고 출발한다
- 화물 작업을 중단하고 구조에 집중한다

## 열차 내부 후속

- 확보한 석탄으로 난방 정상화 가능
- 그러나 정비 부품이 부족할 수 있음
- 구조 실패 시 의료진 손실
- 가족/파벌 반응
- 열차장에 대한 신뢰 변화

## 검증 기준

- 같은 상황을 다른 선택으로 다시 해보고 싶은가
- 파밍 결과가 내정에 직접 연결되는가
- 내정 결과가 다음 탐색에 직접 연결되는가
- 실패 이유가 이해 가능한가
- 준비를 잘하면 위기를 더 쉽게 넘길 수 있는가
- 반복 클릭보다 판단 시간이 더 많은가

---

# 17. 향후 설계에서 가장 중요한 질문

1. 플레이어는 직접 한 캐릭터를 조종하는가, 수색대를 지휘하는가, 둘 다 가능한가?
2. 열차의 승객 수는 개별 NPC 기반인가, 집단 + 주요 인물 혼합형인가?
3. 객차 건설은 자유 배치인가, 슬롯/모듈 방식인가?
4. 정치 집단은 직업·계층·가치관 중 무엇을 기준으로 형성되는가?
5. 추위와 좀비는 각각 어떤 종류의 의사결정을 강요하는가?
6. 멀티에서는 최종 출발 결정권을 누가 가지는가?
7. 실제 철도 노선은 미국/유럽 중 어느 지역을 중심으로 하는가?
8. 최종 섬 방어가 실제 철도 지리와 어떻게 연결되는가?
9. 캠페인에서 죽음/열차 붕괴 시 체크포인트를 어디까지 되돌릴 것인가?
10. 무한모드에서 장기 안정 후의 ‘안정화 고원’을 어떻게 깨뜨릴 것인가?

---

# 18. 참고 링크 모음

## 모바일/좀비 생존 비교작

- Project Deathless — Google Play: https://play.google.com/store/apps/details?id=com.Deathless_Team.ProjectDeathless
- Dead Town Survival — Google Play: https://play.google.com/store/apps/details?id=com.Ccentury.DeadTownSurvival
- Cataclysm: DDA — Google Play: https://play.google.com/store/apps/details?id=com.cleverraven.cataclysmdda
- DYSMANTLE — 10tons: https://www.10tons.com/game/dysmantle/
- Last Day on Earth — Google Play: https://play.google.com/store/apps/details?id=zombie.survival.craft.z
- Prey Day — Google Play: https://play.google.com/store/apps/details?id=zombie.survival.online.craft

## 열차/이동식 기지 비교작

- Pandemic Train: https://store.steampowered.com/app/1379600/Pandemic_Train/
- Last Train Home: https://store.steampowered.com/app/1469610/Last_Train_Home/
- Zompiercer: https://store.steampowered.com/app/1262460/Zompiercer/
- Frostrain: https://store.steampowered.com/app/2735630/Frostrain/
- Frostrain 2: https://store.steampowered.com/app/3690490/Frostrain_2/

## 정치/사회/내정 비교작

- Frostpunk 2: https://store.steampowered.com/app/1601580/Frostpunk_2/
- Suzerain: https://store.steampowered.com/app/1207650/Suzerain/
- IXION: https://store.steampowered.com/app/1113120/IXION/
- Against the Storm: https://store.steampowered.com/app/1336490/Against_the_Storm/
- The Alters: https://store.steampowered.com/app/1601570/The_Alters/

## 조사·리뷰

- Frostpunk 2 — PC Gamer: https://www.pcgamer.com/games/city-builder/frostpunk-2-review/
- Frostpunk 2 — Shacknews: https://www.shacknews.com/article/141448/frostpunk-2-review-score
- Frostpunk 2 — IGN: https://www.ign.com/articles/frostpunk-2-review
- Frostpunk 2 — Metacritic: https://www.metacritic.com/game/frostpunk-2/
- Project Zomboid Steam reviews: https://steamcommunity.com/app/108600/reviews/?browsefilter=toprated
- Project Zomboid and the Peril of Endless Games: https://dissectinggamedesign.substack.com/p/project-zomboid-and-the-peril-of
- Suzerain — Articy developer interview: https://www.articy.com/en/showcase/suzerain/
- Suzerain — Matchsticks for My Eyes: https://www.matchstickeyes.com/2024/07/27/suzerain-a-narrative-game-that-brings-policy-politics-to-life/
- Suzerain — Vice: https://www.vice.com/en/article/suzerain-game-review/
- Pandemic Train Steam negative reviews: https://steamcommunity.com/app/1379600/negativereviews/?browsefilter=toprated
- Pandemic Train GOG feedback: https://www.gog.com/forum/pandemic_train/pandemic_train_analytical_feedback_suggestions
- IXION — PC Gamer: https://www.pcgamer.com/ixion-review/
- Against the Storm — Eurogamer: https://www.eurogamer.net/against-the-storm-review-a-perfectly-chaotic-city-builder
- Against the Storm — GameWatcher: https://www.gamewatcher.com/against-the-storm/review
- The Alters — IGN: https://www.ign.com/articles/the-alters-review
- The Alters — GamesRadar: https://www.gamesradar.com/games/survival/the-alters-review/
- The Alters — The Verge: https://www.theverge.com/games-review/685213/the-alters-review-ps5-xbox-steam
- Zompiercer Steam reviews: https://steamcommunity.com/app/1262460/reviews/?browsefilter=toprated

## 지도/3D 제작

- OpenRailwayMap: https://www.openrailwaymap.org/
- OpenStreetMap: https://www.openstreetmap.org/
- OSM copyright / ODbL: https://www.openstreetmap.org/copyright
- BlenderGIS: https://github.com/domlysz/BlenderGIS
- Blender Manual: https://docs.blender.org/manual/en/latest/
- Kenney assets: https://kenney.nl/assets
- Synty POLYGON Apocalypse: https://syntystore.com/products/polygon-apocalypse-pack
- Adobe Mixamo FAQ: https://helpx.adobe.com/creative-cloud/faq/mixamo-faq.html

---

# 19. 현재 프로젝트의 핵심 설계 명제

> **외부 파밍은 자원을 얻는 시간이 아니라, 누구를 어디까지 위험에 노출시킬지 결정하는 시간이어야 한다.**

> **내정은 반복 생산을 클릭하는 시간이 아니라, 이미 확보한 자원을 누구에게 어떤 원칙으로 배분할지 결정하는 시간이어야 한다.**

> **정치는 호감도를 올리는 별도 미니게임이 아니라, 파밍과 배급 과정에서 생긴 손실·특혜·약속의 누적 결과여야 한다.**

> **잘 준비한 플레이어는 실제로 위기를 더 쉽게 넘겨야 한다. 게임은 준비를 무효화하는 대신, 그 여유로 더 큰 선택을 열어야 한다.**

> **맵의 차이는 건물 스킨이 아니라 그 장소가 요구하는 행동과 판단에서 나와야 한다.**

> **열차는 메뉴가 아니라 플레이어가 점점 더 살아 있는 사회로 느끼는 ‘집’이어야 한다.**

---

# 20. 작업용 요약

현재 가장 유망한 방향은 다음과 같다.

```text
[이동 중]
열차 내부 운영 자동화 + 보고서 + 정치적 결정

[정차]
실제 철도역/도시 기반 3D 탑뷰 맵 탐색

[외부]
파밍 + 구조 + 전투 + 야영 + 선택적 임무

[압력]
추위 = 장기 계획 / 연료 / 난방
좀비 = 현장 압박 / 소음 / 체류 시간 / 퇴로

[귀환]
성과 확인 → 열차 실제 변화 → 정치 반응 → 다음 경로 결정

[장기]
캠페인 약 15시간 + 무한 생존
```

게임의 핵심 차별성은 단순히 ‘좀보이드 + 프로스트펑크’가 아니라:

**“밖에서 한 생존 선택이 열차 내부의 정치로 돌아오고, 열차 안에서 만든 사회가 다음 외부 생존의 조건을 바꾸는 것.”**

