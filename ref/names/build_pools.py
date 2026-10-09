"""Build A3-compatible name pools deterministically from cited source records."""

from __future__ import annotations

import argparse
from copy import deepcopy
import hashlib
import json
from pathlib import Path
import re
import sys
import unicodedata
from urllib.parse import urlsplit

from transliterate import transcribe

ROOT = Path(__file__).resolve().parent
CORE = ("pl", "de", "cz")
MIN_SURNAMES = {"de": 193}
OTHER = ("uk", "sk", "hu", "lt")
LANGUAGES = CORE + OTHER
ALLOWED_BASES = {"용례", "규칙", "미확인"}


def normalized(text: str) -> str:
    return unicodedata.normalize("NFC", text).casefold().strip()


def check_source(value: str) -> None:
    if not isinstance(value, str):
        raise ValueError("출처는 URL 문자열이어야 합니다.")
    parts = urlsplit(value)
    if parts.scheme not in ("https", "http") or not parts.netloc:
        raise ValueError("출처에 실제 HTTP(S) URL이 필요합니다.")


def decorate(part: dict, language: str, inherited_source: str | None = None) -> dict:
    if not isinstance(part, dict):
        raise ValueError("이름 항목은 객체여야 합니다.")
    original = part.get("original")
    if not isinstance(original, str) or not original.strip():
        raise ValueError("원어 이름이 비어 있습니다.")
    if original != original.strip() or original != unicodedata.normalize("NFC", original):
        raise ValueError(f"원어의 공백 또는 유니코드 정규화를 확인하세요: {original!r}")
    source = part.get("source", inherited_source)
    check_source(source)
    result = deepcopy(part)
    result["source"] = source
    result["language"] = language
    result.update(transcribe(original, language))
    if result["korean_basis"] not in ALLOWED_BASES or not re.search(r"[가-힣]", result["korean"]):
        raise ValueError(f"한글 표기 또는 근거가 누락되었습니다: {original}")
    return result


def make_language(language: str, source: dict) -> dict:
    given = source.get("given_names")
    surnames = source.get("surnames")
    if not isinstance(given, list) or not isinstance(surnames, list):
        raise ValueError(f"{language}: 이름과 성 목록이 필요합니다.")
    excluded_surnames = []
    if language == "lt":
        selected = []
        for row in surnames:
            unmarried = row.get("female_unmarried_verified")
            male = row.get("male", row)
            if not unmarried:
                excluded_surnames.append({**transcribe(male["original"], language),
                                          "reason": "검증된 전통 미혼형이 없어 생성기 입력에서 제외했다."})
                continue
            entry = {key: deepcopy(value) for key, value in row.items()
                     if key not in ("original", "gender", "male", "female", "female_verified",
                                    "female_unmarried_verified", "generation_note_ko")}
            entry["male"] = {key: deepcopy(value) for key, value in male.items()
                             if key not in ("female_verified", "female_unmarried_verified", "generation_note_ko")}
            entry["female"] = deepcopy(unmarried)
            entry["female_married"] = deepcopy(row.get("female", row.get("female_verified")))
            entry["female_form_usage"] = "traditional_unmarried"
            entry["generation_note_ko"] = "현재 소비자용 female에는 사전에서 확인한 전통 미혼형을 선택했다. 전통 기혼형은 female_married에 따로 보존한다. 모든 여성의 법적 성이나 혼인 상태를 추정하는 규칙이 아니다."
            selected.append(entry)
        surnames = selected
    min_given, min_surnames = (150, 200) if language in CORE else (30, 39 if language == "lt" else 40)
    # 독일 성은 출처 표(상위 200)에서 편집 기준으로 뺀 자리를 채울 다음 순위가 없어 193개다.
    min_surnames = MIN_SURNAMES.get(language, min_surnames)
    if len(given) < min_given or len(surnames) < min_surnames:
        raise ValueError(f"{language}: 최소 이름 {min_given}개와 성 {min_surnames}개가 필요합니다.")
    result = {"language": language, "given_names": [], "surnames": [],
              "sources": deepcopy(source.get("sources", []))}
    for key, value in source.items():
        if key not in result:
            result[key] = deepcopy(value)
    if excluded_surnames:
        result["excluded_surnames"] = excluded_surnames
    given_seen = set()
    genders = {"male": 0, "female": 0}
    for part in given:
        name = decorate(part, language)
        if name.get("gender") not in genders:
            raise ValueError(f"{language}: 성별은 male 또는 female이어야 합니다.")
        key = normalized(name["original"])
        if key in given_seen:
            raise ValueError(f"{language}: 원어 이름이 중복됩니다: {name['original']}")
        given_seen.add(key)
        genders[name["gender"]] += 1
        result["given_names"].append(name)
    if any(n < len(given) * 0.4 for n in genders.values()):
        raise ValueError(f"{language}: 남녀 이름의 비율을 확인하세요.")
    surname_seen = {"male": set(), "female": set()}
    for surname in surnames:
        if "male" in surname or "female" in surname:
            if "male" not in surname or "female" not in surname:
                raise ValueError(f"{language}: 남녀 성의 한쪽 형태가 없습니다.")
            entry = deepcopy(surname)
            entry["language"] = language
            for gender in ("male", "female"):
                entry[gender] = decorate(surname[gender], language, surname.get("source"))
                entry[gender]["gender"] = gender
            if entry.get("female_married"):
                entry["female_married"] = decorate(entry["female_married"], language, surname.get("source"))
        else:
            if surname.get("gender") in ("male", "female"):
                raise ValueError(f"{language}: 성별 전용 성을 남녀 공통 형식으로 내보낼 수 없습니다.")
            entry = decorate(surname, language)
        for gender in ("male", "female"):
            part = entry[gender] if "male" in entry else entry
            key = normalized(part["original"])
            if key in given_seen:
                raise ValueError(f"{language}: 이름과 성 사이에 원어가 중복됩니다: {part['original']}")
            if key in surname_seen[gender]:
                raise ValueError(f"{language}: {gender} 원어 성이 중복됩니다: {part['original']}")
            surname_seen[gender].add(key)
        result["surnames"].append(entry)
    return result


def build_outputs(source_path: Path = ROOT / "source_pools.json") -> dict[str, dict]:
    raw = source_path.read_bytes()
    sources = json.loads(raw.decode("utf-8"))
    pools = {language: make_language(language, sources[language]) for language in LANGUAGES}
    digest = hashlib.sha256(raw).hexdigest()
    for pool in pools.values():
        pool["source_pools_sha256"] = digest
        pool["transcription_note"] = "용례는 국립국어원의 확인된 표기, 규칙은 변환 결과, 미확인은 추가 검수가 필요한 초안이다. 규칙 표시는 해당 인명의 개별 심의 완료를 뜻하지 않는다."
    result = {language + ".json": pools[language] for language in CORE}
    result["other.json"] = {
        "language": "other",
        "languages": list(OTHER),
        "given_names": [item for language in OTHER for item in pools[language]["given_names"]],
        "surnames": [item for language in OTHER for item in pools[language]["surnames"]],
        "sources": {language: pools[language].get("sources", []) for language in OTHER},
        "language_notes": {language: {key: value for key, value in pools[language].items()
                                      if key not in ("given_names", "surnames", "sources", "source_pools_sha256")}
                           for language in OTHER},
        "source_pools_sha256": digest,
        "integration_note": "A3 입력 계약 때문에 평평한 두 목록을 유지한다. 각 항목의 language는 보존하지만 현재 A3는 이를 버리므로 이름·성·고향의 같은 언어 묶음은 보장하지 못한다. 소비자 코드의 후속 보완이 필요하며 이 작업은 s1/을 바꾸지 않는다.",
    }
    return result


def serialize(data: dict) -> bytes:
    return (json.dumps(data, ensure_ascii=False, indent=2) + "\n").encode("utf-8")


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="출처가 있는 원어 풀에서 네 입력 파일을 재생성합니다.")
    parser.add_argument("--check", action="store_true", help="파일을 쓰지 않고 기존 파일과 바이트 단위로 비교합니다.")
    args = parser.parse_args(argv)
    try:
        outputs = build_outputs()
        mismatches = []
        for name, data in outputs.items():
            path = ROOT / name
            expected = serialize(data)
            if args.check:
                if not path.exists() or path.read_bytes() != expected:
                    mismatches.append(name)
            else:
                path.write_bytes(expected)
        if mismatches:
            print("[FAIL] 재생성 결과와 다른 파일: " + ", ".join(mismatches), file=sys.stderr)
            return 1
        print("[PASS] 네 이름 파일의 재현성을 확인했습니다." if args.check else "[PASS] 네 이름 파일을 생성했습니다.")
        return 0
    except (KeyError, ValueError, OSError) as error:
        print(f"[FAIL] {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
