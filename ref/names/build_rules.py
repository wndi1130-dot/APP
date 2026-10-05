"""Extract declarative BSD-licensed rules without executing upstream Python."""

from __future__ import annotations

import argparse
import ast
import hashlib
import json
from pathlib import Path
from urllib.request import Request, urlopen

ROOT = Path(__file__).resolve().parent
REVISION = "488cb85525e2eca795b042b735ba54359c928fd9"
LANGUAGES = {"pl": "pol", "de": "deu", "cz": "ces", "hu": "hun",
             "uk": "ukr", "sk": "slk", "lt": "lit"}
KINDS = {"Choseong": "C", "Jungseong": "V", "Jongseong": "F"}


def phoneme(node: ast.AST) -> list[str]:
    if (not isinstance(node, ast.Call) or not isinstance(node.func, ast.Name)
            or node.func.id not in KINDS or len(node.args) != 1
            or not isinstance(node.args[0], ast.Name) or node.keywords):
        raise ValueError("허용하지 않은 원자료 표현입니다.")
    return [KINDS[node.func.id], node.args[0].id]


def extract(raw: bytes) -> dict:
    tree = ast.parse(raw.decode("utf-8"))
    cls = next(n for n in tree.body if isinstance(n, ast.ClassDef))
    values: dict = {}
    normalizer: dict = {}
    rules: list = []
    for node in cls.body:
        if isinstance(node, ast.Assign) and len(node.targets) == 1:
            key = node.targets[0].id
            if key == "notation":
                if not isinstance(node.value, ast.Call) or not isinstance(node.value.args[0], ast.List):
                    raise ValueError("표기 규칙 목록 형식이 다릅니다.")
                for entry in node.value.args[0].elts:
                    if not isinstance(entry, ast.Tuple) or len(entry.elts) < 2:
                        raise ValueError("표기 규칙 항목 형식이 다릅니다.")
                    pattern = ast.literal_eval(entry.elts[0])
                    outputs = entry.elts[1:]
                    if len(outputs) == 1 and isinstance(outputs[0], ast.Constant):
                        result = ast.literal_eval(outputs[0])
                        if result is not None and not isinstance(result, str):
                            raise ValueError("치환값은 문자열이어야 합니다.")
                    else:
                        if len(outputs) == 1 and isinstance(outputs[0], ast.Tuple):
                            outputs = outputs[0].elts
                        result = [phoneme(x) for x in outputs]
                    rules.append([pattern, result])
            elif isinstance(node.value, ast.Constant) and isinstance(node.value.value, str):
                values[key] = node.value.value
        elif isinstance(node, ast.FunctionDef) and node.name == "normalize":
            for expression in ast.walk(node):
                if isinstance(expression, ast.Dict):
                    candidate = ast.literal_eval(expression)
                    if all(isinstance(k, str) and isinstance(v, str) for k, v in candidate.items()):
                        normalizer.update(candidate)
    return {"variables": {k: v for k, v in values.items() if not k.startswith("_")},
            "temporary": values.get("__tmp__", ""), "normalize": normalizer, "rules": rules}


def main() -> None:
    parser = argparse.ArgumentParser(description="고정된 원자료에서 전사 규칙표를 다시 만듭니다.")
    parser.add_argument("--fetch", action="store_true", help="고정 커밋의 원자료를 내려받습니다.")
    args = parser.parse_args()
    cache = ROOT / ".cache"
    cache.mkdir(exist_ok=True)
    result = {"upstream": "https://github.com/sublee/hangulize", "revision": REVISION,
              "license": "BSD-3-Clause", "license_file": "LICENSE.hangulize",
              "note_ko": "정규식 규칙표만 추출했습니다. 외부 파이썬 코드를 실행하거나 가져오지 않습니다.",
              "languages": {}}
    for language, code in LANGUAGES.items():
        path = f"hangulize/langs/{code}/__init__.py"
        url = f"https://raw.githubusercontent.com/sublee/hangulize/{REVISION}/{path}"
        local = cache / ("hangulize-" + path.replace("/", "_"))
        if args.fetch:
            request = Request(url, headers={"User-Agent": "B1-name-reference/1.0"})
            with urlopen(request, timeout=30) as response:
                local.write_bytes(response.read())
        if not local.exists():
            raise SystemExit("원자료 캐시가 없습니다. --fetch를 지정해 내려받으세요.")
        raw = local.read_bytes()
        data = extract(raw)
        data.update(source=url, sha256=hashlib.sha256(raw).hexdigest())
        result["languages"][language] = data
    (ROOT / "transliteration_rules.json").write_text(
        json.dumps(result, ensure_ascii=False, indent=2) + "\n", encoding="utf-8", newline="\n")
    license_path = cache / "hangulize-LICENSE"
    if args.fetch:
        with urlopen(f"https://raw.githubusercontent.com/sublee/hangulize/{REVISION}/LICENSE", timeout=30) as response:
            license_path.write_bytes(response.read())
    (ROOT / "LICENSE.hangulize").write_bytes(license_path.read_bytes())
    print("[PASS] 7개 언어 규칙표와 원문 라이선스를 저장했습니다.")


if __name__ == "__main__":
    main()
