"""Dependency-free Hangul transcription with explicit evidence levels.

The declarative rules derive from Hangulize (BSD-3-Clause; LICENSE.hangulize).
Only Python's standard library is imported. The rule table is local JSON.
An NIKL example is an attested spelling, not a proof that arbitrary names
have an officially approved spelling. Unknown pronunciation is not inferred
from a person's nationality.
"""

from __future__ import annotations

import argparse
from dataclasses import dataclass
from functools import lru_cache
import json
from pathlib import Path
import re
import sys
import unicodedata

ROOT = Path(__file__).resolve().parent
ALIASES = {"cs": "cz", "ces": "cz", "cze": "cz", "pol": "pl",
           "deu": "de", "ger": "de", "hun": "hu", "ukr": "uk",
           "slk": "sk", "slo": "sk", "lit": "lt"}
NIKL = "https://www.korean.go.kr/front/page/pageView.do?mn_id=97&page_id="
RULE_SOURCES = {"pl": NIKL + "P000131", "de": NIKL + "P000125",
                "cz": NIKL + "P000132", "hu": NIKL + "P000135"}
# NIKL German section 1.3 applies final-r rules at a morpheme boundary.
# These are attested decompositions, not inferred boundaries in arbitrary names.
GERMAN_SEGMENTS = {
    "verarbeiten": ("ver", "arbeiten"),
    "zerknirschen": ("zer", "knirschen"),
    "fürsorge": ("für", "sorge"),
    "vorbild": ("vor", "bild"),
    "urkunde": ("ur", "kunde"),
    "vaterland": ("vater", "land"),
}
ONSETS = "ㄱㄲㄴㄷㄸㄹㅁㅂㅃㅅㅆㅇㅈㅉㅊㅋㅌㅍㅎ"
VOWELS = "ㅏㅐㅑㅒㅓㅔㅕㅖㅗㅘㅙㅚㅛㅜㅝㅞㅟㅠㅡㅢㅣ"
CODAS = "\0ㄱㄲㄳㄴㄵㄶㄷㄹㄺㄻㄼㄽㄾㄿㅀㅁㅂㅄㅅㅆㅇㅈㅊㅋㅌㅍㅎ"
SYMBOLS = dict(zip(
    "G GG N D DD L M B BB S SS NG J JJ C K T P H".split(), ONSETS))
SYMBOLS.update(dict(zip(
    "A AE YA YAE EO E YEO YE O WA WAE OE YO U WEO WE WI YU EU YI I".split(), VOWELS)))
BOUNDARY = "\x02"
MAX_INPUT_LENGTH = 200


@lru_cache(maxsize=1)
def _table() -> dict:
    return json.loads((ROOT / "transliteration_rules.json").read_text(encoding="utf-8"))


@lru_cache(maxsize=1)
def _pronunciations() -> dict:
    return json.loads((ROOT / "pronunciation_notes.json").read_text(encoding="utf-8"))


def _pronunciation(text: str, language: str) -> dict | None:
    return next((item for item in _pronunciations()["entries"]
                 if item["language"] == language and _key(item["original"]) == _key(text)), None)


def _language(language: str) -> str:
    if not isinstance(language, str):
        raise ValueError("언어 코드는 문자열이어야 합니다.")
    language = ALIASES.get(language.lower(), language.lower())
    if language not in _table()["languages"]:
        raise ValueError("지원 언어는 pl, de, cz(cs), hu, uk, sk, lt입니다.")
    return language


def _input(text: str) -> str:
    if not isinstance(text, str) or not text.strip():
        raise ValueError("원어 이름은 빈 문자열일 수 없습니다.")
    text = unicodedata.normalize("NFC", text.strip())
    if len(text) > MAX_INPUT_LENGTH:
        raise ValueError("입력은 200자 이하여야 합니다.")
    if any(unicodedata.category(c).startswith("C") for c in text):
        raise ValueError("제어 문자나 사설 영역 문자를 넣을 수 없습니다.")
    if not any(c.isalpha() for c in text):
        raise ValueError("원어 이름에 문자가 필요합니다.")
    if re.search(r"[^\w\s'’ʼ\-À-ž\u0400-\u052f]", text, re.UNICODE) or any(c.isdigit() or c == "_" for c in text):
        raise ValueError("이름에 지원하지 않는 기호가 있습니다.")
    return re.sub(r"\s+", " ", text).replace("’", "'").replace("ʼ", "'")


def _key(text: str) -> str:
    return unicodedata.normalize("NFC", text).strip().casefold()


def _normalize(text: str, data: dict, language: str) -> str:
    preserved = data["normalize"]
    safe = set(preserved.values())
    output = []
    for char in text:
        if char in preserved:
            output.append(preserved[char])
        elif char.lower() in safe:
            output.append(char.lower())
        else:
            output.append("".join(c for c in unicodedata.normalize("NFD", char.lower())
                                  if unicodedata.category(c) != "Mn"))
    normalized = "".join(output)
    if language == "cz":
        # NIKL's published ASCII caron notation is an input alias only.
        normalized = normalized.replace("d'", "ď").replace("t'", "ť")
    return normalized


def _regex(pattern: str, variables: dict[str, str]) -> re.Pattern:
    pattern = pattern.replace("@", "<vowels>")
    pattern = re.sub(r"<([a-zA-Z_][a-zA-Z0-9_]*)>",
                     lambda m: "(?:" + "|".join(re.escape(c) for c in variables[m[1]]) + ")", pattern)
    left = re.match(r"^(\^?\^?)\{(~?)([^}]+)\}", pattern)
    if left:
        edge = BOUNDARY if left[1] else ""
        operator = "<!" if left[2] else "<="
        pattern = "(?" + operator + edge + "(?:" + left[3] + "))" + pattern[left.end():]
    right = re.search(r"\{(~?)([^}]+)\}(\$?\$?)$", pattern)
    if right:
        edge = BOUNDARY if right[3] else ""
        operator = "!" if right[1] else "="
        pattern = pattern[:right.start()] + "(?" + operator + "(?:" + right[2] + ")" + edge + ")"
    if pattern.startswith("^"):
        pattern = "(?<=" + BOUNDARY + ")" + pattern.lstrip("^")
    if pattern.endswith("$"):
        pattern = pattern.rstrip("$") + "(?=" + BOUNDARY + ")"
    return re.compile(pattern)


@dataclass(frozen=True)
class Compiled:
    replacements: tuple
    tokens: dict


@lru_cache(maxsize=7)
def _compiled(language: str) -> Compiled:
    data = _table()["languages"][language]
    tokens: dict[str, tuple[str, str]] = {}
    inverse: dict[tuple[str, str], str] = {}
    replacements = []
    for pattern, replacement in data["rules"]:
        if isinstance(replacement, list):
            encoded = []
            for kind, symbol in replacement:
                phoneme = (kind, SYMBOLS[symbol])
                if phoneme not in inverse:
                    marker = chr(0xE000 + len(tokens))
                    inverse[phoneme] = marker
                    tokens[marker] = phoneme
                encoded.append(inverse[phoneme])
            replacement = "".join(encoded)
        replacements.append((_regex(pattern, data["variables"]), replacement or ""))
    return Compiled(tuple(replacements), tokens)


def _compose(text: str, tokens: dict, temporary: str) -> str:
    result: list[str] = []
    syllable: dict[str, str] = {}
    order = {"C": 0, "V": 1, "F": 2}
    last = -1

    def flush() -> None:
        nonlocal last
        if syllable:
            onset = ONSETS.index(syllable.get("C", "ㅇ"))
            vowel = VOWELS.index(syllable.get("V", "ㅡ"))
            coda = CODAS.index(syllable.get("F", "\0"))
            result.append(chr(0xAC00 + (onset * 21 + vowel) * 28 + coda))
            syllable.clear()
        last = -1

    for char in text:
        if char in tokens:
            kind, jamo = tokens[char]
            if order[kind] <= last:
                flush()
            syllable[kind] = jamo
            last = order[kind]
        elif char == BOUNDARY or char in temporary:
            if char == "%":
                flush()
        else:
            raise ValueError(f"자동 표기가 미확인인 문자입니다: {char!r}")
    flush()
    return "".join(result)


def _word(word: str, language: str) -> str:
    if language == "de" and _key(word) in GERMAN_SEGMENTS:
        return "".join(_word(segment, language) for segment in GERMAN_SEGMENTS[_key(word)])
    pronunciation = _pronunciation(word, language)
    if pronunciation:
        word = pronunciation["rewrite"]
    data = _table()["languages"][language]
    compiled = _compiled(language)
    normalized = _normalize(word, data, language)
    normalized = BOUNDARY + normalized + BOUNDARY
    for pattern, replacement in compiled.replacements:
        normalized = pattern.sub(lambda _m, value=replacement: value, normalized)
    return _compose(normalized, compiled.tokens, data["temporary"])


def transliterate_rules(text: str, language: str) -> str:
    """Apply rules without consulting the official-example lookup table."""
    language = _language(language)
    text = _input(text)
    parts = re.split(r"([ -])", text)
    return "".join(part if part in ("", " ", "-") else _word(part, language) for part in parts)


@lru_cache(maxsize=1)
def _examples() -> dict:
    file = ROOT / "nikl_examples.json"
    if not file.exists():
        return {}
    data = json.loads(file.read_text(encoding="utf-8"))
    index = {}
    for item in data["examples"]:
        key = (item["language"], _key(item["original"]))
        if key in index and index[key]["korean"] != item["korean"]:
            raise ValueError("같은 원어의 용례 표기가 충돌합니다.")
        index[key] = item
    return index


def transcribe(text: str, language: str, *, use_examples: bool = True) -> dict:
    """Return text plus its evidence classification; never claim approval."""
    language = _language(language)
    text = _input(text)
    example = _examples().get((language, _key(text))) if use_examples else None
    if example:
        return {"original": text, "korean": example["korean"], "korean_basis": "용례",
                "korean_source": example["source"]}
    korean = transliterate_rules(text, language)
    pronunciation = _pronunciation(text, language)
    reviews = _pronunciations()
    words = [part for part in re.split(r"[ -]", text) if part]
    word_notes = [_pronunciation(part, language) for part in words]
    unverified_note = next((item for item in word_notes if item and item["status"] == "미확인"), None)
    review_keys = {_key(x) for x in reviews["review_names"].get(language, [])}
    needs_review = any(_key(part) in review_keys for part in words)
    if unverified_note:
        return {"original": text, "korean": korean, "korean_basis": "미확인",
                "korean_source": RULE_SOURCES.get(language, _table()["languages"][language]["source"]),
                "pronunciation_source": unverified_note["source"], "korean_note": unverified_note["note_ko"]}
    if needs_review:
        return {"original": text, "korean": korean, "korean_basis": "미확인",
                "korean_source": RULE_SOURCES[language], "korean_note": reviews["review_note_ko"]}
    if language in RULE_SOURCES:
        result = {"original": text, "korean": korean, "korean_basis": "규칙",
                  "korean_source": RULE_SOURCES[language]}
        if pronunciation:
            result["pronunciation_source"] = pronunciation["source"]
            result["korean_note"] = pronunciation["note_ko"]
        return result
    return {"original": text, "korean": korean, "korean_basis": "미확인",
            "korean_source": _table()["languages"][language]["source"],
            "korean_note": "자동 전사 초안입니다. 해당 언어의 국립국어원 개별 용례를 확인하지 못했습니다."}


def transliterate(text: str, language: str) -> str:
    return transcribe(text, language)["korean"]


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="원어 이름을 한글로 옮기고 표기 근거를 표시합니다.")
    parser.add_argument("language", help="pl, de, cz(cs), hu, uk, sk, lt")
    parser.add_argument("text", help="원어 이름. 띄어쓰기가 있으면 따옴표로 묶으세요.")
    parser.add_argument("--rules-only", action="store_true", help="용례 우선 적용을 끕니다.")
    args = parser.parse_args(argv)
    try:
        print(json.dumps(transcribe(args.text, args.language, use_examples=not args.rules_only),
                         ensure_ascii=False, indent=2))
        return 0
    except (ValueError, OSError, KeyError) as error:
        print(f"[FAIL] {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
