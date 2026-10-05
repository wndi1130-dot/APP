# B1 이름 풀과 한글 표기

`codex/a3-profile-generator`의 `s1/tools/gen_profiles.ts`가 읽는 이름 자료다. 이 작업은 `ref/names/`만 추가하며 `docs/`, `s1/`, main을 직접 변경하지 않는다. 자료 확인일은 2026-10-05다.

## 구성과 수량

| 파일·언어 | 이름 | 성의 뿌리 | 이름의 남녀 구성 |
|---|---:|---:|---|
| `pl.json` 폴란드어 | 150 | 200 | 남 75, 여 75 |
| `de.json` 독일어 | 150 | 200 | 남 75, 여 75 |
| `cz.json` 체코어 | 150 | 200 | 남 75, 여 75 |
| `other.json` 우크라이나어 `uk` | 30 | 40 | 남 15, 여 15 |
| `other.json` 슬로바키아어 `sk` | 30 | 40 | 남 15, 여 15 |
| `other.json` 헝가리어 `hu` | 30 | 40 | 남 15, 여 15 |
| `other.json` 리투아니아어 `lt` | 30 | 39 | 남 15, 여 15 |

이름은 합계 570개, 생성기용 성은 759뿌리다. 성의 남성형·여성형을 각각 한 뿌리로 부풀려 세지 않는다. 리투아니아 성은 원자료 40뿌리 중 전통 미혼형을 확인한 39뿌리를 입력에 사용한다. 미혼형이 미확인인 `Stankus`를 임의로 만들어 넣지 않는다. 39개는 작업 명세의 ‘40개 안팎’에 해당한다.

`famous_blocklist.json`은 유명인 차단 전용이며 서로 다른 인물 392명, 표기 변형을 포함한 975행을 담는다. 일반 이름 풀로 사용하지 않는다. 동일 인물의 국제형·별칭은 `variant_of`로 구분하며, 행 수와 서로 다른 인물 수는 다르다. 문화권별 구성·한글 표기의 근거는 [BLOCKLIST_SOURCES.md](BLOCKLIST_SOURCES.md)에 적었다.

## 출처와 선정

이름의 실재·빈도와 한글 표기의 근거는 서로 다르다. 각 항목의 `source`는 원어·통계 출처, `korean_source`는 한글 전사 근거다. 통계의 기준 연도, 모집단, 선정 필터, 원문 보존본 여부, 성별형의 확인 방법은 [SOURCES.md](SOURCES.md)를 따른다.

폴란드는 PESEL의 등록 원자료를 사용한다. 독일 이름은 쾰른의 지역 출생등록 자료이므로 독일 전국 전 연령의 빈도라고 해석하지 않는다. 독일 성의 연구 자료도 집계 연도와 전화가입 표본의 범위를 분리한다. 체코의 과거 내무부 자료는 현재 원 배포본을 직접 받을 수 있는지와 보존본을 사용했는지를 구별한다. 리투아니아 성의 사전 자료는 국가별 빈도 순위가 아니다. 확인하지 않은 대표성은 `미확인`이다.

원어는 악센트와 키릴 문자를 보존하며 NFC로 저장한다. 같은 언어 안에서 이름 목록, 성의 성별형 목록, 이름과 성의 교집합까지 중복을 검사한다. 다른 언어의 동일 철자는 별개 언어의 항목이므로 삭제하지 않는다. 순위에서 일부 항목을 제외했더라도 원자료의 `source_rank`·`source_count`를 새 순위로 바꾸지 않는다.

`source_pools.json`에는 전사 이전의 선택된 원어 기록과 출처를 보존한다. `build_pools.py`는 인터넷 없이 이 파일을 읽어 네 입력 파일을 다시 만든다. 대용량 통계 원본, 임시 내려받기, 외부 A3 확인용 파일은 `.cache/`에만 두며 Git에 넣지 않는다.

## 입력 계약

```json
{
  "language": "pl",
  "given_names": [
    {"original": "Anna", "korean": "안나", "gender": "female", "korean_basis": "규칙"}
  ],
  "surnames": [
    {
      "male": {"original": "Kowalski", "korean": "코발스키"},
      "female": {"original": "Kowalska", "korean": "코발스카"}
    },
    {"original": "Nowak", "korean": "노바크"}
  ]
}
```

위 예시는 키 구조만 보여 주는 축약본이다. 실제 항목에는 출처·표기 근거가 추가된다. `given_names`, `surnames`, `original`, `korean`, `gender`, `male`, `female` 키는 A3 계약 그대로다. `gender`는 `male` 또는 `female`만 사용한다.

`other.json`도 두 배열을 최상위에 둔다. 네 언어를 최상위 객체로 다시 감싸지 않는다. 각 항목에는 `language`를 추가해 원어의 소속을 남긴다.

## 한글 표기의 근거

| `korean_basis` | 뜻 |
|---|---|
| `용례` | 원어와 한글의 대응을 국립국어원 자료에서 직접 확인한 항목 |
| `규칙` | 해당 언어의 표기 규칙과 필요한 발음 자료로 변환한 값. 개별 인명의 공식 심의 완료를 뜻하지 않음 |
| `미확인` | 한글 초안은 있으나 적용 언어·개별 발음·국립국어원 표기의 추가 검수가 필요한 값 |

먼저 `nikl_examples.json`의 정확히 일치하는 용례를 적용한다. 없으면 규칙으로 계산한다. 국립국어원 자료에 없는 이름을 그럴듯하다는 이유로 `용례`라고 하지 않는다. 폴란드어 `Anna`의 위 예시도 현재 확인 목록에서는 `규칙`이다.

사용한 국립국어원 규정은 다음과 같다.

- [독일어 표기 세칙](https://www.korean.go.kr/front/page/pageView.do?mn_id=97&page_id=P000125)
- [폴란드어 표기 세칙](https://www.korean.go.kr/front/page/pageView.do?mn_id=97&page_id=P000131), [표기 일람표](https://www.korean.go.kr/front/page/pageView.do?mn_id=97&page_id=P000110)
- [체코어 표기 세칙](https://www.korean.go.kr/front/page/pageView.do?mn_id=97&page_id=P000132), [표기 일람표](https://www.korean.go.kr/front/page/pageView.do?mn_id=97&page_id=P000111)
- [헝가리어 표기 세칙](https://www.korean.go.kr/front/page/pageView.do?mn_id=97&page_id=P000135), [표기 일람표](https://www.korean.go.kr/front/page/pageView.do?mn_id=97&page_id=P000114)

헝가리어는 공식 세칙이 확인되어 규칙 변환을 지원한다. 우크라이나어·리투아니아어·슬로바키아어의 이번 목록에는 국립국어원 개별 용례를 확인하지 못했으므로 `미확인`을 사용한다. 해당 언어의 표기 규정이나 용례가 세상에 전혀 없다는 주장이 아니다.

`nikl_examples.json`은 폴란드어 37개, 독일어 30개, 체코어 36개, 헝가리어 30개, 합계 133개의 확인 사례를 담는다. **규정 본문과 표기 일람표의 일반어·인명·지명 용례**가 섞여 있으며, 133개 모두 인명 심의 데이터베이스의 항목이라고 주장하지 않는다. 기대값은 실제 페이지에서 읽어 기록했으며 변환기의 출력으로 만들지 않았다.

검사에서는 용례 조회를 일부러 차단한 상태로 규칙 엔진이 133개를 변환하는지 확인한다. 별도로 용례가 규칙보다 우선하는지도 확인한다. `Leipzig → 라이프치히`, `Krejčí → 크레이치`, `Mazurek → 마주레크`는 용례 사전에 넣지 않은 규칙 확인 사례다.

독일어는 철자만으로 복합어의 경계나 차용 이름의 발음을 항상 알 수 없다. 공식 문서의 여섯 복합·파생어는 확인된 형태소 경계를 사용한다. `David`, `Charlotte`, `Louis`는 Duden의 인명 발음 항목을 보조 근거로 사용하며, 여전히 `규칙`이지 국립국어원 `용례`가 아니다. 발음을 확정하지 못한 일부 이름은 `pronunciation_notes.json`에 남기고 `미확인`으로 표시한다.

공식 페이지에서도 원어 오타가 의심되는 행은 기대값에 억지로 맞추지 않았다. `przjyaciół`, `sěst`, 그리스어 β가 들어간 `auβerhalb`는 제외 이유와 출처를 `nikl_examples.json`에 남겼다. 체코어 항목은 [국립국어원 온라인가나다의 관련 문의](https://www.korean.go.kr/front/onlineQna/onlineQnaView.do?mn_id=90&pageIndex=1&qna_seq=327473)도 확인했다.

## 실행과 검사

Python 3.10 이상 표준 라이브러리만 사용한다. `pip install`은 필요 없다. 저장소 루트에서 실행한다.

```sh
python3 -m unittest discover -s ref/names
python3 ref/names/build_pools.py --check
python3 ref/names/transliterate.py de Leipzig
python3 ref/names/transliterate.py cz Krejčí
python3 ref/names/transliterate.py pl Mazurek
git diff --check
```

Windows에서 실행 파일 이름이 `python`이면 `python -X utf8`로 바꾼다. `.py` 파일을 직접 실행하면 PowerShell의 파이프 문자 인코딩에 기대지 않는다.

원어 목록을 수정한 뒤 재생성하려면 다음과 같이 한다. 먼저 네 파일 전체의 입력을 검사하고, 문제가 있으면 임시 이름을 지어 넣는 대신 실패한다.

```sh
python3 ref/names/build_pools.py
python3 -m unittest discover -s ref/names
python3 ref/names/build_pools.py --check
```

검사 범위는 수량·남녀 비율·필수 키·한글·원어 중복·유니코드·출처 URL 형식·성별형·표기 근거·결과 재현성·유명인 개수와 별칭 중복 집계다. 출처 URL이 있다는 것만으로 자료의 대표성, 저작권 상태, 모든 발음의 정확성을 자동으로 증명하는 검사는 아니다.

### 실제 실행 결과

2026-10-05 Windows / Python 3.13 / Node.js 24.15.0에서 실행했다. Python 실행 파일 이름은 `python`이었다.

```powershell
python -X utf8 -m unittest discover -s ref/names -v
python -X utf8 ref/names/build_pools.py --check
node ref/names/verify_a3.mjs
```

| 검사 | 실제 결과 |
|---|---|
| 전체 단위 검사 | [PASS] 36개, 실패·오류 0개 |
| 국립국어원 용례의 조회 없는 규칙 변환 | [PASS] 133개 일치 |
| 네 JSON 재생성 | [PASS] 파일 내용 바이트 단위 일치 |
| 고정 A3 코드의 세 시드 생성 및 재실행 | [PASS] 600명, 같은 시드 결과 일치 |
| A3의 이름 임시 목록 사용 | [PASS] 0건 |
| A3의 유명인 원어·한글 차단 목록 읽기 | [PASS] 975행의 두 필드 모두 읽음, 생성된 차단 대상 0건 |
| 기존 A3의 other 언어 일치 | [WATCH] 600명 검사 중 서로 다른 언어의 이름·성 조합 72건 관측 |
| B6 | [WATCH] 검사 기준 main에 없어 A3가 임시 선호 목록을 사용함. B1의 이름 대체와 다름 |

수량·근거별 집계·검사 명령·해시는 [validation_report.json](validation_report.json)에 보존했다. 통합 검사의 프로필은 메모리에서만 생성했고 저장소에 출력하지 않았다.

### 기존 A3와의 통합 검사

선택 사항이며 Node.js 24 이상을 사용한다. 먼저 A3의 고정 Git blob을 `.cache/`로 **내려받기만** 한 다음, 확인용 프로그램이 메모리에서 프로필을 생성한다. 내려받은 blob의 해시가 다르면 실행하지 않는다.

```sh
python3 ref/names/fetch_a3_reference.py
node ref/names/verify_a3.mjs
```

대상은 `codex/a3-profile-generator`의 `s1/tools/gen_profiles.ts`, blob `9b935fc2859632b0d24295bce34c31207efc364b`다. 본 작업에서 `s1/` 파일이나 프로필 출력 파일을 만들지 않는다. 세 시드의 600명에 대해 이름 풀 읽기, 이름 임시 대체 여부, 같은 시드 재현, 유명인 양쪽 표기 차단을 확인한다. 그 외 A3의 B6 경고가 있다면 숨기지 않는다.

## 남은 문제와 적용 범위

**기존 A3의 `other` 처리:** A3의 이름 읽기 함수가 각 항목의 `language`를 보존하지 않는다. 따라서 네 언어의 이름·성·고향을 같은 언어로 묶는 것을 현재 소비자에서는 보장할 수 없다. B1은 메타데이터를 남기고 검사에서 실제 혼합을 별도로 집계하지만, `s1/` 수정 권한 범위 밖이므로 A3 코드를 고치지 않는다.

**리투아니아 성의 적용:** `female`에는 확인된 전통 미혼형 39개를 넣고, `female_married`에는 확인된 전통 기혼형을 함께 보존했다. 이는 이름 자료의 범위 선택이지 혼인 상태 추론이 아니다. A3는 이 차이도 사용하지 않으므로 혼인형·가족별 표기를 정교하게 선택하는 소비자 보완이 필요하다. 여성에게 남성형을 공통형인 것처럼 붙이지 않는다.

**유명인 차단의 범위:** 수백 명을 확인했어도 모든 실존 인물·새 유명인·개명·별명·이니셜·모든 중간 이름을 망라하는 목록은 아니다. A3가 읽지 않는 `aliases`에만 의존하지 않도록 지원되는 변형은 별도 `names` 행으로도 제공한다. 최종 인물의 사람이 읽는 이름은 사람 검수를 거친다.

**통계와 발음:** 지역별·연령별 자료를 전국 전 연령의 분포로 확장해서 해석하지 않는다. 사전형 목록을 빈도 순위로 부르지 않는다. `미확인` 표기는 인명·문화권 검수 전의 초안이며, 특히 독일어권의 차용 이름과 우크라이나어·슬로바키아어·리투아니아어의 공식 한글 표기는 남은 검수 대상이다.

## 변환기 원자료와 라이선스

규칙표는 [Hangulize의 공개 Python 구현](https://github.com/sublee/hangulize)의 고정 커밋 `488cb85525e2eca795b042b735ba54359c928fd9`에서 가져왔다. [원문 BSD-3-Clause 라이선스](LICENSE.hangulize)를 보존한다. `build_rules.py`는 외부 Python을 실행하지 않고 AST로 선언형 규칙만 추출한다. 실행 시에는 로컬 JSON과 표준 라이브러리의 정규식·유니코드 조합만 사용한다.

```sh
# 원자료를 다시 내려받는 경우에만 네트워크가 필요하다.
python3 ref/names/build_rules.py --fetch
python3 -m unittest discover -s ref/names
```

언어별 원자료 URL과 SHA-256은 `transliteration_rules.json`에 있다. 제3자 규칙표를 국립국어원의 공식 프로그램이라고 부르지 않는다. 국립국어원 규정과 대조한 회귀 검사, 독일어 형태소 경계·발음 보조, 입력 검증과 근거 분류는 이 폴더의 구현에 포함한다.

통계·사전·Wikidata 자료의 이용 조건은 각각 [SOURCES.md](SOURCES.md), [BLOCKLIST_SOURCES.md](BLOCKLIST_SOURCES.md)에 구분한다. 리투아니아 사전에서 가져온 파생 부분은 원출처의 저작자 표시와 동일조건변경허락 조건을 유지한다. 서로 다른 자료를 한데 모았다는 이유로 전부 CC0이거나 전부 새 코드의 라이선스라고 주장하지 않는다.
