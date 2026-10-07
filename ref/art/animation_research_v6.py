"""Validate and render the animation research supplement; no network or asset execution."""
from __future__ import annotations


def require(condition: bool, message: str) -> None:
    if not condition:
        raise ValueError(message)


def validate_v6(data: dict, resource_ids: set[str], prior_ids: set[str], reserved_ids: set[str]) -> dict[str, int]:
    sources = set(data["sources"])
    named_clips = 0
    for resource in data["resources"]:
        require(isinstance(resource.get("clips"), list), "Missing clip evidence list")
        names: set[str] = set()
        for clip in resource["clips"]:
            require(bool(clip.get("name")) and clip["name"] not in names, "Duplicate or missing clip name")
            names.add(clip["name"])
            require(bool(clip.get("purpose")), "Missing clip purpose")
            require(clip.get("evidence") in {"catalog_text", "legacy_catalog", "catalog_pdf"},
                    "Unsubstantiated clip evidence")
            require(bool(clip.get("source_ids")) and set(clip["source_ids"]) <= sources,
                    "Unknown clip source reference")
            require(set(clip["source_ids"]) <= set(resource["source_ids"]), "Clip source outside resource evidence")
        named_clips += len(names)
    used = resource_ids | reserved_ids
    for row in data["rechecks"] + data["excluded"]:
        require(row["id"] not in used, "Duplicate supplementary ID")
        used.add(row["id"])
        require(bool(row.get("source_ids")) and set(row["source_ids"]) <= sources, "Unknown source reference")
    for row in data["rechecks"]:
        require(row["updates_resource"] in prior_ids, "Unknown recheck target")
        require(row["status"] == "[WATCH]" and bool(row["limits"]) and bool(row["finding"]),
                "Invalid recheck evidence")
    for row in data["excluded"]:
        require(row["status"] == "[BLOCKED]" and bool(row["reason"]), "Invalid exclusion")
    covered: set[str] = set()
    for row in data["coverage"]:
        require(bool(row.get("id")) and row["id"] not in covered, "Duplicate coverage ID")
        covered.add(row["id"])
        require(bool(row.get("resource_ids")) and set(row["resource_ids"]) <= resource_ids,
                "Unknown coverage resource")
        for key in ("action", "proposal", "gap"):
            require(bool(row.get(key)), "Missing coverage " + key)
    return {
        "v6_resources": len(data["resources"]), "v6_sources": len(sources),
        "v6_named_clips": named_clips, "v6_rechecks": len(data["rechecks"]),
        "v6_exclusions": len(data["excluded"]), "v6_action_groups": len(covered),
    }


def cell(text: str) -> str:
    return str(text).replace("|", "\\|").replace("\n", " ").strip()


def source_links(row: dict, data: dict) -> str:
    return " · ".join(f'[{key}]({data["sources"][key]["url"]})' for key in row["source_ids"])


def report_v6(data: dict) -> str:
    lines = [f'# {data["title"]}', "", f'작성: {data["date"]} · 기준 커밋: `{data["base_research_commit"]}`', "",
             "[전체 색인](README.md) · [구조화 목록](animation_resources_v6.json) · [5판](production_resources_v5.md)", "",
             "## 범위", "", data["scope"], "", data["world_direction"], "", "## 이번에 좁힌 것", ""]
    for paragraph in data["summary"]:
        lines += [paragraph, ""]
    lines += ["## 동작별로 필요한 묶음 — 구현 제안", "",
              "목록의 동작 범주와 우리 게임의 채택 결정을 구분한다. 아래는 장면을 완성하기 위한 검수 단위 제안이며 현재 구현물이 아니다.", "",
              "| 동작 | 연결·검수 단위 | 남은 확인 |", "|---|---|---|"]
    for row in data["coverage"]:
        lines.append(f'| {cell(row["action"])} | {cell(row["proposal"])} | {cell(row["gap"])} |')
    labels = (("project_use", "우리 용도"), ("confirmed", "출처 확인"), ("proposal", "적용 제안"),
              ("delivery", "형식·호환"), ("license", "권리"), ("ai_handling", "파일·AI 처리"),
              ("limitations", "한계"), ("next_test", "후속 검증"))
    for number, row in enumerate(data["resources"], 1):
        lines += ["", f'<a id="{row["id"]}"></a>', f'## {number}. {row["name"]}', "",
                  f'**{row["status"]} / {row["kind"]}**', "", row["prior_relation"], ""]
        for key, title in labels:
            lines += [f'**{title}:** {row[key]}', ""]
        if row["clips"]:
            lines += ["대표 이름만 기록했다. 원본 모션 파일을 취득·재생한 것이 아니며, 구형 카탈로그는 현행 상품과 별도 대조가 필요하다.", "",
                      "| 카탈로그의 정확한 이름 | 용도 | 증거 수준 |", "|---|---|---|"]
            evidence = {"catalog_text": "공식 목록", "legacy_catalog": "기존 버전 목록", "catalog_pdf": "기존 PDF 목록·쪽 이미지 확인"}
            for clip in row["clips"]:
                lines.append(f'| `{cell(clip["name"])}` | {cell(clip["purpose"])} | {evidence[clip["evidence"]]} · {source_links(clip, data)} |')
            lines.append("")
        else:
            lines += ["**클립 식별자:** 개별 이름을 확인하지 않은 후보 또는 모션 파일이 아닌 기법이다. 이름을 추측해 채우지 않았다.", ""]
        lines += ["근거: " + source_links(row, data)]
    lines += ["", "## 기존 후보 재확인 — 신규 수에 포함하지 않음", ""]
    for row in data["rechecks"]:
        lines += [f'### {row["name"]}', f'기존 ID: `{row["updates_resource"]}`', "", row["finding"], "",
                  row["limits"], "", source_links(row, data), ""]
    lines += ["## 특정 용도에서 제외", ""]
    for row in data["excluded"]:
        lines += [f'### {row["status"]} {row["name"]}', "", row["reason"], "", source_links(row, data), ""]
    lines += ["## 절단·부상·상호작용의 연결 원칙 — 제안", ""]
    for paragraph in data["implementation_notes"]:
        lines += [paragraph, ""]
    lines += ["프로젝트 요구 근거: " + source_links({"source_ids": ["S23", "S24"]}, data), "",
              "## 열람 한계와 오해 방지", ""]
    for note in data["check_notes"]:
        lines += [note, ""]
    lines += ["## 후속 확인", ""]
    lines += [f'- {gap}' for gap in data["remaining_gaps"]]
    lines += ["", "## 출처 장부", "", "| ID | 원문 | 열람 범위 |", "|---|---|---|"]
    for key, source in data["sources"].items():
        lines.append(f'| {key} | [{cell(source["title"])}]({source["url"]}) | {cell(source["access"])} |')
    lines += ["", "## 저장·검사", "",
              "`python ref/art/build_research_index.py --check`, `python ref/art/validate_catalog.py`, "
              "`python -m unittest discover -s ref/art -p 'test_*.py' -v`로 문서와 목록을 확인한다. "
              "실제 결과는 `research_index_validation_v6.json`과 PR에 별도 기록한다. "
              "모션 품질·저작권 법률 판단·엔진 임포트·모바일 성능 검사가 아니며, 후보의 설치를 수행하지 않는다.", ""]
    return "\n".join(lines)
