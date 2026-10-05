# 유명 인물 이름 조합 제외 목록: 출처와 검증

확인일: 2026-10-05. 원본 조회 시각: 12:49:08–12:53:32 UTC(한국 시각 21:49:08–21:53:32).

## 목적과 적용 범위

`famous_blocklist.json`은 **서로 다른 실인물 392명**, **이름 비교용 975행**을 담는다. 기본 인물 행 392개에 같은 사람의 확인된 표기 변형 583행을 더했다. 사람 수는 `qid`의 고유값으로 센다.

[공통 규칙 8 및 B1](../../docs/handoff/codex_tasks.md), [콘텐츠 가이드 2장의 이름 규칙](../../docs/prototype/s1_content_guide.md)에 따른 생성 제외 자료다. 유명 실존 인물을 게임 인물로 사용하는 것을 막기 위해 그 이름을 이 파일에 기록하는 것은 B1이 요구한 예외다. 일반 이름 풀이나 사건·대사 생성용 예문으로 사용하지 않는다.

`country`는 이 작업에서 배정한 **관련 이름 문화권**이다. 현행 국적, 단일 민족, 생애 전체의 국적을 판정한 값이 아니다. 역사적 국가, 이민·귀화, 복수 언어권 활동이 겹치는 인물도 포함한다. 한 사람은 한 문화권에만 배정해 수를 중복으로 늘리지 않았다. 예를 들어 프란츠 카프카는 이 목록에서 `cz`, 존 폰 노이만은 `hu`, 마리 퀴리는 `pl`에 배정했다. 개별 인물의 배경을 확인하려면 해당 QID의 출처를 확인한다.

## 수록 분포

다음 표는 기본 인물 행만 집계했다. 분야는 목록의 편중을 확인하기 위해 정한 대표 분야 하나이며, 한 사람의 모든 직업을 뜻하지 않는다. 원본의 직업 식별자는 `occupation_qids`에 따로 남겼다.

| 관련 문화권 | 코드 | 정치·공공 | 스포츠 | 연예·공연·영화 | 역사·문학·문화·과학 | 서로 다른 인물 | 전체 행 |
|---|---|---:|---:|---:|---:|---:|---:|
| 폴란드 | pl | 17 | 15 | 10 | 23 | 65 | 129 |
| 독일 | de | 14 | 14 | 11 | 21 | 60 | 130 |
| 체코 | cz | 16 | 19 | 10 | 15 | 60 | 80 |
| 우크라이나 | uk | 13 | 18 | 9 | 11 | 51 | 294 |
| 슬로바키아 | sk | 14 | 21 | 9 | 4 | 48 | 69 |
| 헝가리 | hu | 14 | 18 | 11 | 16 | 59 | 209 |
| 리투아니아 | lt | 16 | 19 | 9 | 5 | 49 | 64 |
| 합계 | | 104 | 124 | 69 | 95 | **392** | **975** |

문화권마다 최소 25명 조건을 충족한다. 다만 슬로바키아·리투아니아에서는 한국어 라벨을 확인할 수 있는 문학·과학 후보가 적어 정치·스포츠 비중이 높다. 분야별 동일 인원을 맞춘 표본이나 유명세 순위가 아니다.

## 수집과 채택 기준

1. 분야별 후보와 Wikidata 검색 결과에서 인물을 찾고, `wbgetentities`의 영어 위키백과 제목 조회로 QID를 대조했다. 광범위 SPARQL의 시간 초과 결과는 채택 근거로 사용하지 않았다.
2. 최종 후보는 각각 `https://www.wikidata.org/wiki/Special:EntityData/Q번호.json`을 실제로 GET했다. 모든 행의 `source`는 이때 읽은 인물별 JSON URL이다. 원본 JSON의 긴 설명·본문·이미지는 복제하지 않았다.
3. `P31 = Q5`(사람)와 전체 이름 형태를 확인했다. 한국어 기본값은 실제 `labels.ko.value`가 있고 한글이 포함된 경우만 채택했다. 한국어 이름을 추측하거나 영어 fallback으로 보충하지 않았다.
4. `original`은 관련 언어의 관측된 전체 이름 라벨을 우선한다. 해당 라벨이 없으면 `mul` 값이 같은 언어의 `P1559` 또는 해당 언어 위키백과의 연결 제목과 정확히 일치하는 경우만 사용했다. 그러한 대조도 안 되면 제외했다. 체코 그룹 코드는 `cz`이지만 Wikidata의 체코어 키는 `cs`다.
5. 원본의 영문·기본 라벨, 모어 이름 속성, 전체 이름 별칭, 연결 제목에서 확인된 표기 변형을 수집했다. 이니셜, 직함, 수식 별명, 회사명, 다른 언어로 재전사된 잡음, 성만 남은 조각, 문자 체계가 섞인 오타 의심값을 걸렀다. 단어 두 개가 겹친다는 이유만으로 채택하지 않고, 예를 들어 `폰 노이만`처럼 이름이 빠진 값은 제외했다.
6. 정규화와 QID 검사를 거친 뒤, 남긴 별칭을 `variant_of`가 있는 보조행으로 펼쳤다. 실제로 관측되지 않은 이름 순서나 전사 결과를 만들어 넣지 않았다.

Wikidata의 언어별 라벨과 `mul` 기본값은 서로 다르다. `languagefallback`을 사용하면 요청 언어와 실제 반환 언어가 달라질 수도 있다. 이번 수집은 raw EntityData를 사용하고, 출처 필드를 명시해 이 둘을 구분했다.

- [Wikidata 기본 라벨과 별칭 안내](https://www.wikidata.org/wiki/Help:Default_values_for_labels_and_aliases)
- [MediaWiki: Wikidata 정보 표시 API와 언어 fallback](https://www.mediawiki.org/wiki/API:Presenting_Wikidata_knowledge)
- [Wikidata P1559: name in native language](https://www.wikidata.org/wiki/Property:P1559)

`original`이 있다는 사실은 그 사람이 생애 내내 사용한 법적 성명·모어를 전수 확인했다는 뜻이 아니다. 이 목록은 출처에서 관측한 이름 조합을 막는 자료다. 한국어 값 또한 국립국어원 심의 표기와 전수 대조한 결과가 아니다.

## 필드와 생성기 연결

최상위 구조와 필수 필드는 그대로다.

```json
{"names":[{"original":"전체 원문 이름","korean":"전체 한글 이름","country":"pl","source":"실제로 읽은 인물별 JSON URL"}]}
```

| 추가 필드 | 의미 |
|---|---|
| `qid` | 같은 사람을 묶는 Wikidata 식별자. 사람 수를 셀 때 사용한다. |
| `original_basis` | 원어 문자열을 읽은 원본 필드 경로. 예: `labels.hu`. `+`는 원어 대조에 두 필드를 함께 사용했다는 뜻이다. |
| `korean_basis` | 한국어 표기 근거 등급: `용례` / `규칙` / `미확인`. 국립국어원 심의 및 전사 세칙을 전수 대조하지 않았으므로 이 목록의 모든 행은 `미확인`이다. |
| `korean_evidence` | 한글 문자열을 읽은 원본 필드 경로. 예: `labels.ko`, `aliases.ko`, `sitelinks.kowiki`. 원문 재대조에 사용하며 표준 표기 판정을 뜻하지 않는다. |
| `source_revision` | 최초 개별 JSON 조회 때의 `lastrevid`. 이후 라이브 문서가 바뀌어도 이 번호는 당시 관측 시점을 가리킨다. |
| `retrieved_at_utc` | 기본 인물 행의 최초 조회 시각. |
| `category` | 기본 인물 행의 편집상 대표 분야. |
| `occupation_qids` | 원본 P106에 있던 비폐기 직업 식별자들. |
| `native_name_evidence` | 관련 언어의 P1559에서 실제로 읽은 이름. 빈 배열이면 그 속성에서 근거를 얻지 않았다는 뜻이다. |
| `aliases.original`, `aliases.korean` | 기본 행에 연결한 관측 표기 변형. |
| `alias_evidence` | 각 별칭 문자열을 읽은 원본 필드 경로. |
| `variant_of` | 보조행이 가리키는 기본 인물의 QID. 기본 행에는 없다. |
| `variant_kind` | `international_name`: 영문·기본 라벨/영문 연결 제목 137행, `source_name`: 그 밖의 원문 이름 변형 219행, `korean_name`: 한글 표기 변형 227행. |

**A3가 `names[]`의 `original`과 `korean`만 읽어도 보조행을 함께 비교할 수 있다.** 별칭 필드만 별도로 읽는 기능에 의존하지 않는다. 원어와 한국어는 각각 전체 문자열로 비교한다. 한 행의 두 값은 같은 사람에게 연결된 관측 이름이며, 서로 음절별로 대응하는 전사 쌍이라는 뜻은 아니다.

`variant_of`가 있는 행을 새 사람으로 세거나, QID만 보고 보조행을 제거한 뒤 이름 비교를 하면 안 된다. QID 중복 제거는 인원 집계에만 쓴다. 기본 행과 보조행의 모든 문자열을 비교용 집합으로 만드는 것이 이 파일의 사용 방법이다.

정규화 검사는 NFKD 분해 → 소문자화 → 결합 부호와 공백 제거 순서다. 이것만으로 `ł/l`, `ß/ss`, 언어별 전사, 이름 순서, 부칭의 유무를 모두 같게 만들지는 않는다. 그런 차이는 실제 출처에서 확인한 별도 행으로 보완했다.

### 이름 순서·다중 이름·가명

| 사례 | 실제 수록된 형태 | 처리 |
|---|---|---|
| 헝가리 성 우선 순서 | `Orbán Viktor` / `Viktor Orbán` | 현지 라벨과 영문 라벨을 같은 QID의 별도 행으로 유지했다. |
| 현지 이름과 국제 사용명 | `Neumann János` / `John von Neumann` | 단어 역순 처리로 만들지 않고 각각 관측된 값을 썼다. |
| 우크라이나 부칭 포함형 | `Володимир Олександрович Зеленський` / `Володимир Зеленський` / `Volodymyr Zelenskyy` | 부칭 포함 원문, 생략 원문, 영문 라벨을 구분했다. |
| 폴란드어와 영문권 이름 | `Fryderyk Chopin` / `Frédéric Chopin`, `Mikołaj Kopernik` / `Nicolaus Copernicus` | 서로 다른 사람으로 세지 않는다. |
| 다중 이름·복합 성 | `Ignacy Jan Paderewski`, `Laura Asadauskaitė-Zadneprovskienė` | 원본의 중간 이름·복합 성을 임의로 자르지 않는다. |
| 필명·예명 | `Bolesław Prus`, `Pola Negri`, `Леся Українка` | 널리 알려진 표시 이름을 기본값으로 사용할 수 있다. 법적 본명과 같다는 뜻은 아니다. |
| 현지형과 영어 사용형 | `Marija Gimbutienė` / `Marija Gimbutas` | 토큰 유사성만으로 판정하지 않고 같은 QID의 직접 관측값을 남겼다. |

위 사례의 인물별 근거: [오르반](https://www.wikidata.org/wiki/Special:EntityData/Q57641.json), [노이만](https://www.wikidata.org/wiki/Special:EntityData/Q17455.json), [젤렌스키](https://www.wikidata.org/wiki/Special:EntityData/Q3874799.json), [쇼팽](https://www.wikidata.org/wiki/Special:EntityData/Q1268.json), [코페르니쿠스](https://www.wikidata.org/wiki/Special:EntityData/Q619.json), [파데레프스키](https://www.wikidata.org/wiki/Special:EntityData/Q191957.json), [아사다우스카이테](https://www.wikidata.org/wiki/Special:EntityData/Q260438.json), [프루스](https://www.wikidata.org/wiki/Special:EntityData/Q144439.json), [네그리](https://www.wikidata.org/wiki/Special:EntityData/Q230633.json), [우크라인카](https://www.wikidata.org/wiki/Special:EntityData/Q298033.json), [김부타스](https://www.wikidata.org/wiki/Special:EntityData/Q221084.json).

헝가리 영사관은 헝가리식 성명 순서를 성–이름–추가 이름으로 안내한다. 영국 여권청의 우크라이나 안내는 부칭이 있는 관행과 국제 여권에서의 부칭 생략을 구분한다. 따라서 임의의 전체 토큰 역순 처리나 마지막 토큰 삭제를 일반 규칙으로 삼지 않았다.

- [헝가리 뉴욕총영사관: 출생 등록과 이름 순서](https://newyork.mfa.gov.hu/en/birth-registration)
- [영국 여권청: Ukraine — names](https://www.gov.uk/government/publications/ukraine-knowledge-base-profile/ukraine-knowledge-base-profile#ukraine-names)

## 라이선스와 출처

Wikidata의 구조화 데이터는 **CC0**로 제공된다. 이 파일은 그 구조화 데이터의 인명·식별자·필드 위치를 사용했다. 위키백과 전기 본문, 이미지, 설명 문단을 복제하지 않았다. 출처 표시는 의무 여부와 별개로 재검토를 위해 모든 행에 남겼다.

- [Wikidata: Copyright](https://www.wikidata.org/wiki/Wikidata:Copyright)
- [Wikidata: Data access — Data best practices](https://www.wikidata.org/wiki/Wikidata:Data_access#Data_best_practices)
- [CC0 1.0](https://creativecommons.org/publicdomain/zero/1.0/)
- [Wikidata: 일반 면책 안내](https://www.wikidata.org/wiki/Wikidata:General_disclaimer)

관측 라벨이라는 출처 범위와 표준 표기 판정을 구분한다. 국립국어원 심의 여부는 각 이름에 대해 별도로 확인해야 한다. 국립국어원 용례는 성·이름의 정렬 순서에도 주의가 필요하다.

- [국립국어원: 정부·언론외래어심의공동위원회](https://www.korean.go.kr/front/page/pageView.do?page_id=P000450)

## 실제 검사 결과

Windows PowerShell 5.1 / Python 3.13에서 아래 검사를 실제 실행했다. 검사는 지정 파일을 읽으며 저장소의 다른 파일을 수정하지 않는다.

| 검사 | 결과 |
|---|---|
| UTF-8 JSON, BOM 없음, LF 줄바꿈, 필수 필드 | [PASS] 975행 |
| 서로 다른 인물 | [PASS] QID 392개, 기본 행 392개 |
| 문화권별 최소 25명 | [PASS] 최솟값 48명 |
| 기본 행 원어·한글 정규화 중복 | [PASS] 각각 0건 |
| 전체 행의 정규화한 원어–한글 쌍 중복 | [PASS] 0건 |
| 서로 다른 QID 간 원어·한글 충돌 | [PASS] 각각 0건 |
| 전체 행 원어 문자열 | [PASS] 정규화 고유값 748개; 같은 인물에서 반복되는 행 227개 |
| 전체 행 한글 문자열 | [PASS] 정규화 고유값 619개; 같은 인물에서 반복되는 행 356개 |
| 보조행의 기본 인물 연결 및 별칭 펼치기 | [PASS] 보조행 583개 전부 연결 |
| Wikidata 재조회: 실인물과 원본 필드 | [PASS] 사람 엔터티 392개; 이름 필드 1,950개; 불일치 0건 |
| 전체 문자열 비교 계약 점검 | [PASS] 차단 대상 18개, 부분 이름 4개 모두 예상 결과 |
| 실제 A3 프로젝트 실행 | [WATCH] 목록 작성 단계에서는 실행하지 않았다. 위 비교 검사는 독립 계약 점검이다. |

같은 사람의 기본값을 보조행에서 다시 사용하므로 전체 행의 원어 또는 한글이 반복되는 것은 의도한 구조다. `qid`가 다른 사람 사이의 충돌과 원어–한글 쌍 중복은 별도로 0건임을 확인했다.

재조회 시 Q58077의 라이브 리비전이 최초 조회 이후 변경되어 있었다. 이름 필드 대조는 모두 일치했다. `source_revision`은 최초 조회 리비전이며 현재 웹 페이지의 최신 리비전과 항상 같다는 뜻은 아니다.

### 1. 오프라인 구조·중복 검사

저장소 루트에서 PowerShell로 실행한다. UTF-8 입력 설정을 생략하면 PowerShell 5.1 파이프에서 원어 문자가 손실될 수 있다.

```powershell
$OutputEncoding = [System.Text.UTF8Encoding]::new($false)
@'
import json, re, unicodedata, collections
from pathlib import Path
path = Path("ref/names/famous_blocklist.json")
raw = path.read_bytes()
assert not raw.startswith(b"\xef\xbb\xbf") and b"\r" not in raw
rows = json.loads(raw.decode("utf-8"))["names"]
base = [r for r in rows if "variant_of" not in r]
base_by_qid = {r["qid"]: r for r in base}
def norm(text):
    return "".join(c for c in unicodedata.normalize("NFKD", text).lower()
                   if not unicodedata.category(c).startswith("M") and not c.isspace())
required = ("original", "korean", "country", "source", "qid")
assert len(base) == len(base_by_qid) >= 300
expected = {"pl", "de", "cz", "uk", "sk", "hu", "lt"}
counts = collections.Counter(r["country"] for r in base)
assert set(counts) == expected and min(counts.values()) >= 25
for r in rows:
    assert all(isinstance(r[k], str) and r[k] for k in required)
    assert len(r["original"].split()) >= 2 and len(r["korean"].split()) >= 2
    assert re.fullmatch(r"Q[1-9][0-9]*", r["qid"])
    assert r["source"] == "https://www.wikidata.org/wiki/Special:EntityData/" + r["qid"] + ".json"
    assert re.search(r"[가-힣]", r["korean"]) and not re.search(r"[A-Za-z]", r["korean"])
    assert "?" not in r["original"] + r["korean"] and "\ufffd" not in r["original"] + r["korean"]
    assert isinstance(r["source_revision"], int) and r["source_revision"] > 0
    assert all(ord(c) >= 32 for c in r["original"] + r["korean"])
    if "variant_of" in r:
        assert r["variant_of"] == r["qid"] and r["qid"] in base_by_qid
        assert r["country"] == base_by_qid[r["qid"]]["country"]
pairs = [(norm(r["original"]), norm(r["korean"])) for r in rows]
assert len(set(pairs)) == len(pairs)
collisions = {}
for field in ("original", "korean"):
    index = collections.defaultdict(set)
    for r in rows:
        index[norm(r[field])].add(r["qid"])
    conflicts = {s: sorted(qids) for s, qids in index.items() if len(qids) > 1}
    assert not conflicts, (field, conflicts)
    collisions[field] = {"distinct_normalized": len(index), "same_person_repeat_rows": len(rows) - len(index), "cross_person_conflicts": len(conflicts)}
    assert len({norm(r[field]) for r in base}) == len(base)
    indexed = {norm(r[field]) for r in rows}
    for r in base:
        assert all(norm(a) in indexed for a in r["aliases"][field])
print(json.dumps({"status": "[PASS]", "people": len(base), "rows": len(rows),
                  "variants": len(rows) - len(base), "countries": dict(counts),
                  "pairs_duplicate": len(rows) - len(set(pairs)), "strings": collisions},
                 ensure_ascii=False))
'@ | python -X utf8 -
```

실제 출력 요약: `people=392, rows=975, variants=583, pairs_duplicate=0`. 정규화 고유 문자열은 `original=748, korean=619`, 서로 다른 사람 사이의 충돌은 양쪽 모두 0건이다.

### 2. 출처의 원문 필드 재대조

다음 코드는 네트워크로 QID별 원문을 묶어 다시 읽고, 기본 행과 보조행의 두 이름이 기록된 필드에 실제로 있는지 확인한다. 대체 언어 값을 켜지 않는다. 원본 라벨이 나중에 변경되면 오류를 그대로 보여주므로 `source_revision`과 함께 검토해야 한다.

```powershell
$OutputEncoding = [System.Text.UTF8Encoding]::new($false)
@'
import json, urllib.request, urllib.parse, sys, re, unicodedata, collections
sys.stdout.reconfigure(encoding='utf-8')
headers={'User-Agent':'APP-B1-NameReference/1.0 (read-only Wikidata name collection; https://github.com/wndi1130-dot/APP)'}

from pathlib import Path
from concurrent.futures import ThreadPoolExecutor,as_completed
rows=json.loads(Path("ref/names/famous_blocklist.json").read_text(encoding="utf-8"))["names"]
byqid=collections.defaultdict(list)
for row in rows: byqid[row["qid"]].append(row)
def fetch(ids):
    url="https://www.wikidata.org/w/api.php?"+urllib.parse.urlencode({"action":"wbgetentities","ids":"|".join(ids),"props":"labels|aliases|claims|sitelinks|info","languages":"pl|de|cs|uk|sk|hu|lt|ko|en|mul","sitefilter":"plwiki|dewiki|cswiki|ukwiki|skwiki|huwiki|ltwiki|kowiki|enwiki","format":"json"})
    with urllib.request.urlopen(urllib.request.Request(url,headers=headers),timeout=40) as res:
        payload=json.load(res)
    if "error" in payload: raise RuntimeError(str(payload["error"]))
    return payload["entities"]
def observed(entity,basis):
    section,rest=basis.split(".",1)
    if section=="labels": return {entity.get("labels",{}).get(rest,{}).get("value")}
    if section=="sitelinks": return {entity.get("sitelinks",{}).get(rest,{}).get("title")}
    if section=="aliases": return {x["value"] for x in entity.get("aliases",{}).get(rest,[])}
    if section=="claims":
        prop,language=rest.split(".",1)
        return {s["mainsnak"]["datavalue"]["value"]["text"] for s in entity.get("claims",{}).get(prop,[]) if s.get("rank")!="deprecated" and "datavalue" in s.get("mainsnak",{}) and s["mainsnak"]["datavalue"]["value"].get("language")==language}
    raise ValueError(basis)
errors=[];checked=0;humans=0;fields=0;revisions_changed=[];occupations={}
ids=list(byqid)
with ThreadPoolExecutor(max_workers=2) as pool:
    for future in as_completed([pool.submit(fetch,ids[i:i+40]) for i in range(0,len(ids),40)]):
        entities=future.result()
        for qid,entity in entities.items():
            values=[s.get("mainsnak",{}).get("datavalue",{}).get("value",{}).get("id") for s in entity.get("claims",{}).get("P31",[]) if s.get("rank")!="deprecated"]
            if "Q5" not in values: errors.append([qid,"not_human"])
            else: humans+=1
            for row in byqid[qid]:
                for key in ["original","korean"]:
                    basis=row["korean_evidence"] if key=="korean" else row["original_basis"]
                    first=basis.split("+")[0]
                    if row[key] not in observed(entity,first): errors.append([qid,key,row[key],basis])
                    if "+" in basis:
                        extra=basis.split("+",1)[1]
                        if extra.startswith("P1559."): extra="claims."+extra
                        if row[key] not in observed(entity,extra): errors.append([qid,key,"fallback_unconfirmed",extra])
                    fields+=1
            if entity.get("lastrevid")!=byqid[qid][0]["source_revision"]: revisions_changed.append(qid)
            checked+=1
        print(json.dumps({"source_people_checked":checked,"total_people":len(ids),"errors":len(errors)}),flush=True)
print(json.dumps({"status":"[PASS]" if not errors else "[FAIL]","people_verified":checked,"human_entities":humans,"name_fields_verified":fields,"source_field_errors":errors,"revisions_changed":revisions_changed},ensure_ascii=False))
assert not errors
'@ | python -X utf8 -
```

실제 출력: `people_verified=392, human_entities=392, name_fields_verified=1950, source_field_errors=[]`. 최초 추출 이후 리비전 변경 항목은 `Q58077` 1개였다.

### 3. 이름 전체 비교 계약 점검

다음 검사는 `names[]`만 읽으며 별칭 필드를 직접 읽지 않는다. 목록 작성 단계에서는 독립 계약 점검으로 실행했으며, 실제 A3 통합 실행 결과와 구분한다.

```powershell
$OutputEncoding = [System.Text.UTF8Encoding]::new($false)
@'
import json, urllib.request, urllib.parse, sys, re, unicodedata, collections
sys.stdout.reconfigure(encoding='utf-8')
headers={'User-Agent':'APP-B1-NameReference/1.0 (read-only Wikidata name collection; https://github.com/wndi1130-dot/APP)'}

from pathlib import Path
data=json.loads(Path("ref/names/famous_blocklist.json").read_text(encoding="utf-8"))["names"]
base=[r for r in data if "variant_of" not in r]
norm=lambda t:"".join(c for c in unicodedata.normalize("NFKD",t).lower() if not unicodedata.category(c).startswith("M") and not c.isspace())
original={norm(r["original"]) for r in data}
korean={norm(r["korean"]) for r in data}
positive_original=["Orbán Viktor","Viktor Orbán","Neumann János","John von Neumann","Fryderyk Chopin","Frédéric Chopin","Mikołaj Kopernik","Nicolaus Copernicus","Володимир Зеленський","Volodymyr Zelenskyy","Andriy Shevchenko","Marija Gimbutienė","Marija Gimbutas","  vIKTOR   oRBaN  "]
positive_korean=["오르반 빅토르","빅토르 오르반","볼로디미르 젤렌스키","안드리 셰브첸코"]
assert all(norm(s) in original for s in positive_original)
assert all(norm(s) in korean for s in positive_korean)
assert all(norm(s) not in original for s in ["Orbán","Viktor","von Neumann"])
assert norm("폰 노이만") not in korean
print(json.dumps({"status":"[PASS]","standalone_exact_full_name_contract":{"positive":len(positive_original)+len(positive_korean),"negative":4},"primary_original_basis":dict(collections.Counter(p["original_basis"] for p in base)),"first_retrieved_at_utc":min(p["retrieved_at_utc"] for p in base),"last_retrieved_at_utc":max(p["retrieved_at_utc"] for p in base),"by_country_category":{c:dict(collections.Counter(p["category"] for p in base if p["country"]==c)) for c in ["pl","de","cz","uk","sk","hu","lt"]}},ensure_ascii=False))
'@ | python -X utf8 -
```

## 남은 한계와 미확인

- [WATCH] **국립국어원 심의 및 전사 세칙 적합성은 전수 미확인**이다. 기본 한글 이름 392개가 Wikidata 한국어 라벨에 실제로 있다는 것과 표준 표기가 맞다는 것은 별개의 판단이다. 이 파일의 한글을 일반 이름 풀의 전사 정답으로 재사용하지 않는다.
- [WATCH] **모든 유명인·별칭을 망라하지 않는다.** 출처의 전체 이름 라벨도 본명, 필명, 국제 사용명 중 하나일 수 있다. 성 변경, 옛 철자, 지역 전사 차이와 미수록 인물은 남아 있다.
- [WATCH] **관련 문화권 분류는 현행 국적 확인 결과가 아니다.** 역사국가·오스트리아/독일어권·체코슬로바키아·옛 소련권·이민 배경을 단일 국적으로 재해석하지 않는다.
- [WATCH] **원어 근거 부족으로 제외:** [Q313379](https://www.wikidata.org/wiki/Special:EntityData/Q313379.json). 최종 개별 조회에서 리투아니아어 라벨 또는 허용한 원어 대조 근거를 확보하지 못했다.
- [WATCH] **한국어 확인 실패 후보는 임의로 보완하지 않았다.** 슬로바키아·리투아니아의 한국어 라벨 없는 후보 45명을 추가 확인했지만, 그 묶음에서는 한국어 위키백과 연결 제목도 확보하지 못했다.
- [WATCH] **표기 대응 이상이 의심되는 후보는 제외:** [Maryna Viazovska, Q23721911](https://www.wikidata.org/wiki/Special:EntityData/Q23721911.json), [Bolek Polívka, Q676173](https://www.wikidata.org/wiki/Special:EntityData/Q676173.json). 이번 파일에서 한국어 정답을 새로 확정하지 않았다.
- [WATCH] **목록 작성 단계에서는 실제 A3 통합 검사를 실행하지 않았다.** 위 결과는 독립 데이터 검증 결과다. 실제 고정 A3 통합 테스트 결과는 README에 별도로 기록한다. QID로 인물을 세는 처리와 모든 행의 이름을 비교하는 처리를 구분해야 한다.
