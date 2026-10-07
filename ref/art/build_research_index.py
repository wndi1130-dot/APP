"""Build/check the research README inventory. Standard library only; no network."""
from __future__ import annotations

import argparse
import json
import re
from pathlib import Path
from urllib.parse import unquote, urlsplit

from animation_research_v6 import report_v6, validate_v6

ROOT = Path(__file__).resolve().parents[2]
START = "<!-- APP_3D_RESEARCH_INDEX_BEGIN -->"
END = "<!-- APP_3D_RESEARCH_INDEX_END -->"
CATALOGS = (
    "ref/art/resource_index.json",
    "ref/art/game_reference_resources_v3.json",
    "ref/art/production_gap_resources_v4.json",
    "ref/art/production_resources_v5.json",
    "ref/art/animation_resources_v6.json",
)
REPORTS = ("production_resources.md", "game_reference_resources_v3.md", "production_gap_resources_v4.md", "production_resources_v5.md", "animation_resources_v6.md")
ALLOWED = {"[PASS]", "[WATCH]", "[PATCH REQUIRED]", "[FAIL]", "[BLOCKED]"}


def require(condition: bool, message: str) -> None:
    if not condition:
        raise ValueError(message)


def load(root: Path = ROOT) -> list[dict]:
    return [json.loads((root / name).read_text(encoding="utf-8")) for name in CATALOGS]


def valid_url(url: str) -> bool:
    parts = urlsplit(url)
    return parts.scheme == "https" and bool(parts.netloc) and not parts.username and not parts.password


def valid_reference(source: dict) -> bool:
    """Permit explicitly documented legacy HTTP citations, never download targets."""
    url = source["url"]
    if valid_url(url):
        return True
    parts = urlsplit(url)
    return (parts.scheme == "http" and parts.hostname in {"makehumancommunity.org", "www.makehumancommunity.org"}
            and not parts.username and not parts.password and parts.port in (None, 80)
            and source.get("allow_insecure_reference") is True and bool(source.get("transport_note")))


def validate(catalogs: list[dict]) -> dict[str, int]:
    v2, v3, v4, v5, v6 = catalogs
    ids: set[str] = set()
    for data in catalogs:
        for row in data["resources"]:
            require(bool(re.fullmatch(r"[a-z][a-z0-9_]*", row["id"])), "Invalid resource ID")
            require(row["id"] not in ids, "Duplicate resource ID: " + row["id"])
            ids.add(row["id"])
            require(row.get("status") in ALLOWED, "Invalid status")
            require(row.get("project_runtime_tested") is False, "Unsubstantiated runtime claim")
            for flag in ("package_downloaded", "audio_auditioned"):
                if flag in row:
                    require(row[flag] is False, "Unsubstantiated execution claim")
            require(bool(row.get("name")), "Missing name")
            for url in row.get("sources", []):
                require(valid_url(url), "Invalid source URL")
    for data in catalogs[2:]:
        for source in data["sources"].values():
            require(valid_reference(source), "Invalid source URL")
            require(bool(source.get("access")), "Missing source access level")
        for row in data["resources"]:
            for key in ("kind", "prior_relation", "project_use", "confirmed", "proposal", "delivery",
                        "license", "ai_handling", "limitations", "next_test", "source_ids"):
                require(bool(row.get(key)), "Missing " + key)
            require(set(row["source_ids"]) <= set(data["sources"]), "Unknown source reference")
    source_ids = set(v4["sources"])
    old_ids = {r["id"] for d in (v2, v3) for r in d["resources"]}
    supplementary: set[str] = set()
    for row in v4["rechecks"] + v4["leads"]:
        require(row["id"] not in ids | supplementary, "Duplicate supplementary ID")
        supplementary.add(row["id"])
        require(set(row["source_ids"]) <= source_ids, "Unknown source reference")
        require(bool(row.get("limits")) and bool(row.get("finding")), "Missing evidence limit")
        require(row["status"] == "[WATCH]", "Unverified lead marked passed")
    for row in v4["rechecks"]:
        require(row["updates_resource"] in old_ids, "Unknown recheck target")
    for row in v2["excluded"]:
        require(row["id"] not in ids | supplementary, "Excluded ID collision")
        supplementary.add(row["id"])
    for row in v5["excluded"]:
        require(row["id"] not in ids | supplementary, "Excluded ID collision")
        supplementary.add(row["id"])
        require(row["status"] == "[BLOCKED]" and bool(row["reason"]), "Invalid exclusion")
        require(bool(row["source_ids"]) and set(row["source_ids"]) <= set(v5["sources"]), "Unknown source reference")
    references = {r["id"] for r in v3["references"]}
    require(len(references) == len(v3["references"]), "Duplicate game reference")
    for row in v3["resources"] + v3["scene_tests"]:
        require(set(row["reference_ids"]) <= references, "Unknown game reference")
    v3_ids = {r["id"] for r in v3["resources"]}
    for row in v3["scene_tests"]:
        require(set(row["resources"]) <= v3_ids, "Unknown scene resource")
    v6_counts = validate_v6(v6, ids, {r["id"] for d in catalogs[:-1] for r in d["resources"]}, supplementary)
    return {
        "v2_resources": len(v2["resources"]), "v3_resources": len(v3["resources"]),
        "v4_resources": len(v4["resources"]), "total_resource_entries": len(ids),
        "game_references": len(references), "scene_plans": len(v3["scene_tests"]),
        "v4_sources": len(source_ids), "v4_rechecks": len(v4["rechecks"]),
        "v4_leads": len(v4["leads"]), "v2_exclusions": len(v2["excluded"]),
        "v5_resources": len(v5["resources"]), "v5_sources": len(v5["sources"]),
        "v5_exclusions": len(v5["excluded"]),
        **v6_counts,
    }


def cell(value: str) -> str:
    return str(value).replace("|", "\\|").replace("\n", " ").strip()


def source_links(row: dict, v4: dict) -> str:
    return " · ".join(f'[{key}]({v4["sources"][key]["url"]})' for key in row["source_ids"])


def root_block(catalogs: list[dict], counts: dict) -> str:
    _, _, v4, v5, v6 = catalogs
    lines = [START, "## 3D 제작 자료 목록", "",
        "**[전체 자원 색인: ref/art/README.md](ref/art/README.md)** — 버전별 후보를 한곳에서 찾는다.", "",
        f'조사 항목 **{counts["total_resource_entries"]}개**: 2판 {counts["v2_resources"]}개 + 3판 {counts["v3_resources"]}개 + 4판 {counts["v4_resources"]}개 + 5판 {counts["v5_resources"]}개 + 6판 {counts["v6_resources"]}개. '
        "공급자 수나 확보한 파일 수가 아니며, 도구·서비스·기법·개별 자산을 포함한다. 프로젝트 적용은 미검증이다.", "",
        "| 순서 | 자료 | 내용 |", "|---|---|---|",
        "| 1 | [현재 아트 기준](docs/art/production_brief.md) · [조사 지시서](docs/handoff/3d_research_tasks.md) | 비픽셀 월드·UI 분리와 작업 범위 |",
        "| 2 | [전체 자원 목록](ref/art/README.md) | 분야·용도·출처·미확인 상태로 검색 |",
        f'| 3 | [제작 자원 2판](ref/art/{REPORTS[0]}) · [JSON](ref/art/resource_index.json) | 기반 도구·리그·소품·재질·셰이더 {counts["v2_resources"]}개, 별도 제외 {counts["v2_exclusions"]}개 |',
        f'| 4 | [작품별 보충 3판](ref/art/{REPORTS[1]}) · [JSON](ref/art/game_reference_resources_v3.json) | This War of Mine·Frostpunk 1·2·Metro 제작자 자료 {counts["game_references"]}개, 후보 {counts["v3_resources"]}개, 장면 검증안 {counts["scene_plans"]}개 |',
        f'| 5 | [빠진 자원 보충 4판](ref/art/{REPORTS[2]}) · [JSON](ref/art/production_gap_resources_v4.json) | 작업·구조 모션, 철도 음향, 의복/소품/경로 제작 {counts["v4_resources"]}개, 재확인 {counts["v4_rechecks"]}건, 자료 경로 {counts["v4_leads"]}건 |',
        f'| 6 | [방한복·소품·전달 보충 5판](ref/art/{REPORTS[3]}) · [JSON](ref/art/production_resources_v5.json) | 구체 의복·생활 소품·의존 파일·렌더 관리·UV/텍스처·메모리 {counts["v5_resources"]}개, 버전 제외 {counts["v5_exclusions"]}개 |',
        f'| 7 | [애니메이션 보충 6판](ref/art/{REPORTS[4]}) · [JSON](ref/art/animation_resources_v6.json) | 사다리·계단·사격·부상·절단 이후 {counts["v6_resources"]}개, 대표 클립명 {counts["v6_named_clips"]}개, 동작 묶음 {counts["v6_action_groups"]}개 |',
        "", "### 이번에 추가한 6판 항목", "",
        "| 자원 | 필요한 부분 |", "|---|---|"]
    for row in v6["resources"]:
        lines.append(f'| [{cell(row["name"])}](ref/art/{REPORTS[4]}#{row["id"]}) | {cell(row["project_use"])} |')
    lines += ["", "[WATCH] 저장된 것은 작성한 조사 문서·출처 주소·메타데이터·검사 도구다. "
              "원작 게임 자산, 외부 유료 팩, 모션·음원 원본, 도면 PDF를 이 저장소에 추가하지 않았다. "
              "구매·다운로드·설치·Blender/Unity 실행·음원 청취·모바일 성능 검증은 이번 범위 밖이다.", "",
              "검사: `python ref/art/build_research_index.py --check` · `python ref/art/validate_catalog.py` · "
              "`python -m unittest discover -s ref/art -p 'test_*.py' -v`", END]
    return "\n".join(lines)


def inventory(catalogs: list[dict], counts: dict) -> str:
    v2, v3, v4, v5, v6 = catalogs
    lines = ["# 3D 제작 자료 전체 색인", "", "갱신: 2026-10-07", "",
        "[저장소 README](../../README.md) · [현재 제작 기준](../../docs/art/production_brief.md) · "
        "[조사 지시서](../../docs/handoff/3d_research_tasks.md)", "",
        f'**조사 항목 {counts["total_resource_entries"]}개**를 나열한다. 새 공급처·무료팩·다운로드 완료 수가 아니다. '
        "같은 생태계의 개별 의복이나 기능 문서도 항목으로 센다. 서로 다른 ID를 세었으며 유사 기능까지 독립 공급처로 주장하지 않는다.", "",
        "기존 판은 당시 조사 기록으로 보존했다. 뒤의 판은 보충이지 전 항목의 최신성 재검증이 아니다. "
        "특히 약관·지원 버전은 실제 취득할 때 원문과 파일을 다시 고정한다. 모든 후보의 프로젝트 실행은 [WATCH]다.", "",
        "## 읽는 순서와 파일", "",
        "| 파일 | 역할 |", "|---|---|",
        f'| [{REPORTS[0]}]({REPORTS[0]}) · [resource_index.json](resource_index.json) | 2판 기반 후보 |',
        f'| [{REPORTS[1]}]({REPORTS[1]}) · [game_reference_resources_v3.json](game_reference_resources_v3.json) | 3판 작품별 근거·생활 자원·장면 검증안 |',
        f'| [{REPORTS[2]}]({REPORTS[2]}) · [production_gap_resources_v4.json](production_gap_resources_v4.json) | 4판 정확한 작업 모션·구조·철도음·제작 보완 |',
        f'| [{REPORTS[3]}]({REPORTS[3]}) · [production_resources_v5.json](production_resources_v5.json) | 5판 방한복·소품·전달·메모리 검수 |',
        f'| [{REPORTS[4]}]({REPORTS[4]}) · [animation_resources_v6.json](animation_resources_v6.json) | 6판 사다리·계단·사격·부상·절단 상태 |',
        "| [build_research_index.py](build_research_index.py) · [test_research_index.py](test_research_index.py) | 다섯 목록 통합 검사와 이 README/루트 목록/4~6판 보고서 생성 |",
        "| [animation_research_v6.py](animation_research_v6.py) | 대표 클립명의 증거·동작 묶음 참조와 6판 보고서 생성 |",
        "| [validate_catalog.py](validate_catalog.py) · [test_validate_catalog.py](test_validate_catalog.py) | 기존 2판 메타데이터·현재 지시·보관본 검사 |",
        "| [archive_manifest.json](archive_manifest.json) | 과거 프롬프트 본문 보존 해시 |",
        "| [game_reference_validation_v3.json](game_reference_validation_v3.json) | 이전 3판의 검사 기록. 이번 재실행 기록과 구분 |", ""]
    for index, data in enumerate(catalogs):
        version = index + 2
        lines += [f'## {version}판 후보 {len(data["resources"])}개', "",
                  "| ID / 자원 | 분야·용도 | 근거 |", "|---|---|---|"]
        for row in data["resources"]:
            title = f'`{row["id"]}` — {cell(row["name"])}'
            use = row.get("project_use", row.get("project_proposal", ""))
            kind = row.get("category", row.get("kind", ""))
            if version >= 4:
                links = source_links(row, data)
                report = f'{REPORTS[index]}#{row["id"]}'
            else:
                links = " · ".join(f'[출처 {i + 1}]({u})' for i, u in enumerate(row["sources"]))
                report = REPORTS[index]
            lines.append(f'| {title} | {cell(kind)} / {cell(use)} | [조사]({report}) · {links} |')
        lines.append("")
    lines += [f'## 작품 제작자 자료 {len(v3["references"])}개', "",
              "참고 기법을 분석하는 문서다. 원작의 모션·음원·이미지 사용권을 주는 자산 목록이 아니다.", "",
              "| 작품 | 자료 | 주의 |", "|---|---|---|"]
    for row in v3["references"]:
        lines.append(f'| {cell(row["game"])} | [{cell(row["title"])}]({row["url"]}) | {cell(row["caution"])} |')
    lines += ["", "## 기존 후보 재확인 — 새 후보 수에 더하지 않음", ""]
    for row in v4["rechecks"]:
        lines += [f'### {row["name"]}', f'기존 항목: `{row["updates_resource"]}`. {row["finding"]}',
                  "", row["limits"], "", source_links(row, v4), ""]
    lines += ["## 도면·기관 자료 경로 — 도면 확보와 구분", ""]
    for row in v4["leads"]:
        lines += [f'### {row["name"]}', row["finding"], "", row["limits"], "", source_links(row, v4), ""]
    lines += ["## 2판에서 제외한 항목", "", "| 항목 | 이유 |", "|---|---|"]
    for row in v2["excluded"]:
        lines.append(f'| {cell(row["name"])} | {cell(row["reason"])} |')
    lines += ["", "## 5판에서 제외한 항목", "", "| 항목 | 이유·근거 |", "|---|---|"]
    for row in v5["excluded"]:
        lines.append(f'| {cell(row["name"])} | {cell(row["reason"])} · {source_links(row, v5)} |')
    lines += ["", "## 6판의 기존 후보 재확인", ""]
    for row in v6["rechecks"]:
        lines += [f'### {row["name"]}', f'기존 ID: `{row["updates_resource"]}`. {row["finding"]}', "",
                  row["limits"], "", source_links(row, v6), ""]
    lines += ["## 6판에서 특정 용도로 제외한 항목", "", "| 항목 | 이유·근거 |", "|---|---|"]
    for row in v6["excluded"]:
        lines.append(f'| {cell(row["name"])} | {cell(row["reason"])} · {source_links(row, v6)} |')
    lines += ["", "## 다시 만드는 법", "",
              "`python ref/art/build_research_index.py --write`는 이 README, 루트 README의 표시된 목록 블록, 4~6판 보고서를 갱신한다. "
              "`--check`는 파일을 쓰지 않고 누락·목록 불일치·ID 충돌·출처·미실행 표기를 검사한다. "
              "외부 URL에 접속하거나 Blender를 실행하지 않는다.", ""]
    return "\n".join(lines)


def report(v4: dict) -> str:
    lines = ["# 3D 제작 자원 보충 4판 — 작업·구조·철도음과 자료 색인", "",
        f'작성: {v4["date"]} · 작업 기준 커밋: `{v4["base_research_commit"]}`', "",
        "[전체 색인](README.md) · [구조화 목록](production_gap_resources_v4.json) · "
        "[3판](game_reference_resources_v3.md) · [2판](production_resources.md)", "",
        "## 이번에 달라진 것", "",
        "사용자 요청에 따라 README에서 자료를 찾을 수 있게 통합 목록을 추가했다. "
        "8개 새 조사 항목, 기존 후보 재확인 1건, 도면 자료 경로 2건을 나눴다. "
        "외부 팩을 구매하거나 내려받은 것이 아니라 필요한 동작·파일 형식·근거의 구체성을 높인 작업이다.", "",
        "| 빈칸 | 이번에 확인한 수준 | 아직 확인하지 못한 것 |", "|---|---|---|",
        "| 작업 모션 | Fix & Build의 삽질·렌치·설계도 확인 클립 이름과 FBX 제공 | 화실 투입에 맞는 궤적·그립·모션 품질 |",
        "| 부축·들것 | Injury & Rescue 공식 설명에 해당 동작이 명시됨 | 정확한 짝 파일 ID·FBX 전달·두 체형의 정렬 |",
        "| 철도 음향 | 실제 열차 출발/기적 CC0 후보와 전문 작업음 유료 라이브러리 | 청취·루프·현장 소음 분리·폴란드 차종의 음색 |",
        "| 겨울 복장 | MPFB 의복 자체 제작 경로 | 완성된 긴 방한 외투·목도리와 겹침 호환 |",
        "| 원도면 | Ol49-69 수리 공고의 설계자료 위치, Pt31 박물관 색인 | 원도면 이미지·치수·스케일·재배포 권리 |", "",
        "## 적용 판단", "",
        "우선 비교할 것은 삽질과 구조 모션이다. 이미 기반 몸체·일반 이동 모션·소품 후보는 있으므로, "
        "더 많은 일반 팩보다 손과 소품·두 인물·객차 문이 만나는 동작의 빈칸을 줄이는 편이 유용하다. "
        "다만 아래는 모두 프로젝트 적용 제안이며 S1을 3D로 재작성하거나 의료·철도 규칙을 새로 확정한 것이 아니다.", "",
        "유료 후보의 조달과 무료 기법 문서를 같은 것으로 취급하지 않는다. 두 CC0 음원도 제목·라이선스만 확인했고 재생하지 않았다. "
        "긴 외투는 아직 찾았다고 보고하지 않으며, 자체 제작 경로를 대안으로 남겼다.", ""]
    labels = (("project_use", "우리 용도"), ("confirmed", "출처 확인"), ("proposal", "적용 제안"),
              ("delivery", "형식·버전"), ("license", "권리·배포"), ("ai_handling", "AI 처리 구분"),
              ("limitations", "한계"), ("next_test", "후속 검증"))
    for i, row in enumerate(v4["resources"], 1):
        lines += [f'<a id="{row["id"]}"></a>', f'## {i}. {row["name"]}', "",
                  f'**{row["status"]} / {row["kind"]}**', "", row["prior_relation"], ""]
        for key, title in labels:
            lines += [f'**{title}:** {row[key]}', ""]
        lines += ["근거: " + source_links(row, v4), ""]
    lines += ["## 기존 조사에서 보완한 것", ""]
    for row in v4["rechecks"]:
        lines += [f'### {row["name"]}', row["finding"], "", row["limits"], "",
                  "근거: " + source_links(row, v4), ""]
    lines += ["## 기관차 도면 — 탐색 경로와 확보물을 구분", ""]
    for row in v4["leads"]:
        lines += [f'### {row["name"]}', row["finding"], "", row["limits"], "",
                  "근거: " + source_links(row, v4), ""]
    lines += ["## 약관과 조회 한계", "",
        "MoCap Central EULA는 같은 주소에서 조회 경로에 따라 2024판과 2026-07-12판이 반환됐다. "
        "이번 요약은 날짜가 명시된 2026판의 게임 이용/원본 재배포/AI 학습 구분을 따른다. "
        "구판의 모호한 임베딩 문구를 현행 확정 제한으로 옮기지 않았다. 실제 구매 시 원문 버전을 다시 보관해야 한다. [S03](https://mocapcentral.com/pages/licensing)", "",
        "Reallusion은 공식 페이지 상단의 확장 Standard 설명과 하단 구 FAQ가 서로 다르다. "
        "특히 캐릭터 수 제한 설명은 이번 모션 팩의 구매 조건으로 곧바로 적용하지 않았다. "
        "iContent와 외부 내보내기 권한, 필요한 프로그램을 실제 옵션에서 확인한다. [S05](https://www.reallusion.com/license/content.html)", "",
        "CMU 표의 일부 번호가 파싱에서 빠졌고 박물관 PDF는 열람에 실패했다. "
        "불완전한 번호를 추측해 채우거나 PDF 도면·표를 보았다고 기록하지 않았다. "
        "저장소에는 제3자 도면 원문·음원·모션·사진을 추가하지 않았다.", "",
        "## 남은 확인 항목", ""]
    for gap in v4["remaining_gaps"]:
        lines += [f'- {gap}']
    lines += ["", "## 출처 장부", "", "| ID | 원문 | 열람 수준 |", "|---|---|---|"]
    for key, source in v4["sources"].items():
        lines.append(f'| {key} | [{cell(source["title"])}]({source["url"]}) | {cell(source["access"])} |')
    lines += ["", "## 문서 검증의 범위", "",
        "`python ref/art/build_research_index.py --check`로 세 판의 ID 충돌, 출처 참조, "
        "README/보고서 생성 결과, 상대 링크, 미실행 표기를 확인한다. "
        "`python ref/art/validate_catalog.py`와 `python -m unittest discover -s ref/art -p 'test_*.py' -v`를 함께 실행한다. "
        "실제 실행 결과는 별도 `research_index_validation_v4.json` 및 PR 기록에 남긴다. "
        "이 검사들은 링크의 실시간 가용성·법률 판단·음원 청취·모션 품질·게임 성능을 확인하지 않는다.", ""]
    return "\n".join(lines)


def report_v5(data: dict) -> str:
    lines = [f'# {data["title"]}', "", f'작성: {data["date"]} · 기준 커밋: `{data["base_research_commit"]}`', "",
             "[전체 색인](README.md) · [구조화 목록](production_resources_v5.json) · [4판](production_gap_resources_v4.md)", "",
             "## 범위", "", data["scope"], "", data["world_direction"], "", "## 이번 조사에서 좁힌 것", ""]
    for paragraph in data["summary"]:
        lines += [paragraph, ""]
    lines += ["## 사용 순서 제안", "",
              "의복 두 항목은 기존 공통 몸체와의 호환 확인부터, 소품 두 항목은 크기·부품 분리부터 비교한다. "
              "텍스처 최적화 전에 원본·전달본·측정 기준을 나눈다. 렌더 관리 서버는 지금 설치할 필수 도구가 아니다.", ""]
    labels = (("project_use", "용도"), ("confirmed", "출처 확인"), ("proposal", "적용 제안"),
              ("delivery", "형식·호환"), ("license", "권리"), ("ai_handling", "파일·AI 처리"),
              ("limitations", "미확인·한계"), ("next_test", "후속 검증"))
    for i, row in enumerate(data["resources"], 1):
        lines += [f'<a id="{row["id"]}"></a>', f'## {i}. {row["name"]}', "",
                  f'**{row["status"]} / {row["kind"]}**', "", row["prior_relation"], ""]
        for key, title in labels:
            lines += [f'**{title}:** {row[key]}', ""]
        lines += ["근거: " + source_links(row, data), ""]
    lines += ["## Blender 4.5 기준 제외", ""]
    for row in data["excluded"]:
        lines += [f'### {row["status"]} {row["name"]}', "", row["reason"], "", source_links(row, data), ""]
    lines += ["## 조회 한계와 잘못 읽기 쉬운 부분", ""]
    for note in data["check_notes"]:
        lines += [note, ""]
    lines += ["## 남은 검증", ""]
    lines += [f'- {gap}' for gap in data["remaining_gaps"]]
    lines += ["", "## 출처 장부", "", "| ID | 자료 | 열람 범위 |", "|---|---|---|"]
    for key, source in data["sources"].items():
        lines.append(f'| {key} | [{cell(source["title"])}]({source["url"]}) | {cell(source["access"])} |')
    lines += ["", "## 저장·검사", "",
              "GitHub 연구 브랜치의 원문과 COS 로컬 파일을 같은 커밋으로 맞춘다. "
              "검사 기록은 `research_index_validation_v5.json`에, 실제 동작 결과는 후속 제작 단계에 별도로 남긴다. "
              "목록 검사가 통과해도 에셋 품질·엔진 임포트·모바일 성능을 검증한 것은 아니다.", ""]
    return "\n".join(lines)


def render(catalogs: list[dict], root_text: str) -> tuple[dict[str, str], dict[str, int]]:
    counts = validate(catalogs)
    if START in root_text or END in root_text:
        require(root_text.count(START) == root_text.count(END) == 1, "Invalid README markers")
        before, rest = root_text.split(START, 1)
        _, after = rest.split(END, 1)
        new_root = before + root_block(catalogs, counts) + after
    else:
        new_root = root_text.rstrip() + "\n\n" + root_block(catalogs, counts) + "\n"
    return {
        "README.md": new_root,
        "ref/art/README.md": inventory(catalogs, counts),
        "ref/art/production_gap_resources_v4.md": report(catalogs[2]),
        "ref/art/production_resources_v5.md": report_v5(catalogs[3]),
        "ref/art/animation_resources_v6.md": report_v6(catalogs[4]),
    }, counts


def check_outputs(outputs: dict[str, str], root: Path = ROOT) -> int:
    links = 0
    for name, expected in outputs.items():
        path = root / name
        require(path.is_file() and path.read_text(encoding="utf-8") == expected, "Stale generated file: " + name)
        for target in re.findall(r"\]\(([^)]+)\)", expected):
            if "://" in target or target.startswith("#"):
                continue
            target = unquote(target.split("#", 1)[0])
            if target:
                destination = (path.parent / target).resolve()
                require(destination.is_relative_to(root.resolve()) and destination.exists(), "Broken local link: " + target)
                links += 1
    return links


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    modes = parser.add_mutually_exclusive_group(required=True)
    modes.add_argument("--check", action="store_true")
    modes.add_argument("--write", action="store_true")
    args = parser.parse_args()
    outputs, counts = render(load(), (ROOT / "README.md").read_text(encoding="utf-8"))
    if args.write:
        for name, text in outputs.items():
            require(all(line == line.rstrip() for line in text.splitlines()), "Trailing whitespace: " + name)
            (ROOT / name).write_text(text, encoding="utf-8", newline="\n")
    links = check_outputs(outputs)
    print("[PASS] " + json.dumps(counts, ensure_ascii=False, sort_keys=True))
    print(f"[PASS] {len(outputs)} generated documents match; {links} local links; no cross-catalog ID collisions")
    print("[WATCH] Metadata/document checks only; no external URL, legal, audio, Blender, Unity, or mobile tests")


if __name__ == "__main__":
    main()
