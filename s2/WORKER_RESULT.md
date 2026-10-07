# S2 작업 결과

상태: **산출물 작성 완료 / 정적 확인 완료 / 실행 검증 `not_run`**. 작성일: 2026-10-07. APK, 스크린샷, S22 성능 통과 근거는 아직 없다.

구현 failure code: `NONE`. 실행하지 못한 검사와 보조 기록의 failure code는 아래에 남겼다. 비대화형으로 질문·확인 요청 없이 진행했다.

## 범위와 구현

`docs/handoff/s2_perf_spike.md`와 `docs/design/briefs/engine.md` 전체를 UTF-8로 읽었다. 시작 시 git status는 비어 있었고 브랜치는 `s2/perf-spike-20261007`이었다. `s2/**`와 `.github/workflows/s2-android.yml`에만 새 파일을 작성했다. `docs/`, `s1/`, 기존 파일, `.git`을 수정하지 않았다. commit·push·PR·다운로드·설치·네트워크·외부 모델·서브에이전트·GUI·권한 상승은 실행하지 않았다.

Godot 4.7.2 지정, Mobile 렌더러, 가로 화면, 객차 여섯 칸 홈 → 감속 → 짧은 로딩 → 정차 카메라 회전·절차 하차 → 탑뷰 필드 흐름을 작성했다. 기본 하차 보행에 고개·어깨·가슴 자세를 더해 당당함과 처짐을 조합한다. 제동·한숨 소리는 자리만 있고 실제 소리 파일은 없다.

좀비 기본 100 / 최대 150개, 절차 VAT 두 클립과 하나의 MultiMesh, 탭 이동, 벽·문, 격자 시야, 소음 반경, 일반 안개, GPU 비 입자와 단계 토글을 넣었다. HUD는 FPS·실제 시계로 잰 프레임 간격 평균/최대·MultiMesh 제출 수·설정 수·필드 시간을 표시한다.

CI는 공식 4.7.2 Linux 실행 파일을 `--headless`로 실행하고 같은 릴리스의 템플릿을 쓴다. SHA-512 확인 → CI 전용 GUT 9.3.0 및 라이선스 → 임포트 → 아홉 테스트/JUnit 확인 → 임시 디버그 키 생성 → APK 내보내기/서명 검사 → APK·로그 artifact 순서다. push 브랜치와 PR 경로 필터를 발주문대로 작성했다. CI를 실제로 실행한 것은 아니다.

## 바뀐 파일

모두 새 파일이다. 전체 경로 목록은 `verification/delivery-checks.json`에도 남긴다. 같은 줄의 짧은 파일명은 앞에 적은 폴더 안의 파일을 뜻한다.

- `.github/workflows/s2-android.yml`
- `s2/.gitignore`, `s2/project.godot`, `s2/export_presets.cfg`
- `s2/scenes/main.tscn`, `home.tscn`, `station.tscn`, `field.tscn`
- `s2/scripts/main.gd`, `home.gd`, `station.gd`, `field.gd`, `graybox.gd`
- `s2/scripts/grid_visibility.gd`, `noise_radius.gd`, `scene_flow.gd`, `vat_baker.gd`
- `s2/shaders/zombie_vat.gdshader`
- `s2/tests/.gdignore`, `test_grid_visibility.gd`, `test_noise_radius.gd`, `test_scene_flow.gd`
- `s2/README.md`, `s2/PERF_CHECKLIST.md`, `s2/WORKER_RESULT.md`
- `s2/tools/verify_static.py`, `s2/verification-output.txt`
- `s2/verification/static-checks.json`, `bash-syntax.txt`, `verify_delivery.py`, `delivery-checks.json`, `delivery-output.txt`, `delivery-first-attempt.txt`
- `s2/verification/ci-step-03.bash` ~ `ci-step-09.bash`: YAML에서 추출한 검증용 셸 블록 일곱 개

## 실제 검증과 출력

GDScript 12개, VAT 셰이더, `.tscn` 4개, `project.godot`, `export_presets.cfg`를 디스크에서 다시 읽었다. 들여쓰기·타입·preload·노드/시그널·장면 순서·MultiMesh 속성 설정 순서·VAT 정점/행·입력·측정값을 확인했다. 눈으로 확인한 범위에서는 문법 문제를 발견하지 못했다. 이는 Godot 파싱 성공을 뜻하지 않는다. 검토 중 CI 템플릿 저장 폴더를 `4.7.2.stable`로 바로잡았다.

기존 Python 절대 실행 파일 `<로컬 Python 3.13>\python.exe`와 설치되어 있던 `yaml` 모듈을 사용했다. `-B s2/tools/verify_static.py` 최종 종료 코드는 **0**, 출력은 다음과 같다.

```text
PASS structural: 12 GDScript, 4 scenes, 22 resource references
PASS YAML parse: PyYAML SafeLoader + BaseLoader; version, triggers and paths checked
SHA256 manifest: 25 files; s2/verification/static-checks.json
NOT_RUN Godot parse / GUT / APK export / render / S22
```

구분자, INI 절, 리소스 참조, 필수 설정, YAML 구조, 버전·브랜치·경로 필터를 확인했다. SafeLoader로 파싱하고 BaseLoader로 구조를 확인해 YAML 1.1의 `on` 키 해석 차이를 피했다. 완전한 GDScript 문법 검사기는 아니다. 소스·설정·설명 파일 25개의 SHA-256은 `verification/static-checks.json`에 있다. 결과와 로그·검증용 복사본은 자기 참조를 피하려고 해시 대상에서 제외했다.

마지막 납품 검사는 `verification/verify_delivery.py`로 브랜치, 모든 새 파일의 허용 경로, tracked/staged 변경 0, 필수 파일 실재, 소스·문서 끝 공백, 25개 해시, 다음 단계가 하나인지를 대조했다. **최종 exit 0**이었다. 관찰 출력은 `verification/delivery-output.txt`, 구조화 결과는 `verification/delivery-checks.json`에 남겼다. `git diff --check`는 **exit 0 / 출력 없음**이었고 untracked 소스·문서의 공백도 Python으로 확인했다.

```text
PASS allowlist: 40 new files, no tracked/staged changes
PASS branch: s2/perf-spike-20261007
PASS git diff --check: exit 0, no output
PASS SHA256: 25 source/config/document files match static manifest
PASS delivery: required files exist, text whitespace checked, one next step
```

첫 납품 검사에서는 PowerShell 리다이렉션이 UTF-16 로그를 만들어 UTF-8 읽기가 `UnicodeDecodeError`로 종료됐다(exit 1 / `F-ENCODING`). 로그를 UTF-8로 변환하고 이후 출력도 UTF-8로 명시 저장하도록 바꿨다. 원 관찰은 `verification/delivery-first-attempt.txt`에 보존했고 수정한 검사로 다시 확인해 통과했다. 이 인코딩 문제는 해결됐다.

추가 Bash 검사에서 절대 Git Bash 실행 파일은 존재했지만 `--noprofile --norc -n`이 첫 블록을 파싱하기 전에 실패했다. 관찰값은 `fatal error - CreateFileMapping …, Win32 error 5. Terminating.`이며 PowerShell wrapper는 **exit 1**이었다. 공개 기록에서 로컬 SID·PID는 가렸다. 셸 파싱은 `not_run`, failure code는 `F-SANDBOX-RUNTIME`이다. 나머지 여섯 블록은 실행하지 않았고 권한 상승·우회·재시도도 하지 않았다. `verification/bash-syntax.txt`에 남겼다.

## not_run / not_verified

| 항목 | 상태 | 이유 / failure code |
|---|---|---|
| Godot 4.7.2 파싱·임포트·실행 | `not_run` | Godot가 없고 다운로드·설치 미승인. `F-RUNTIME-UNAVAILABLE` |
| GUT 아홉 테스트 | `not_run` | Godot/GUT가 없으며 프레임워크는 CI에서 받을 예정. `F-RUNTIME-UNAVAILABLE` |
| APK 내보내기·디버그 서명 확인 | `not_run` | 엔진·템플릿·이번 작업의 Android 도구 준비 없음. `F-RUNTIME-UNAVAILABLE` |
| GitHub Actions / artifact / APK 링크 | `not_run` | commit/push/PR은 맡긴 쪽의 범위. CI 실행·업로드 없음 |
| 화면·VAT·카메라·Android 글꼴·스크린샷 | `not_run` | 실행 환경 없음 / GUI 불허. `F-RUNTIME-UNAVAILABLE` |
| S22 FPS·10분 뒤 성능·열·카메라 끊김 | `not_run` | 사용자 기기 측정 전. 성능 통과를 주장하지 않음 |
| 릴리스 가용성과 Godot/GUT/SDK 호환성 | `not_verified` | 네트워크 금지. 지정 버전과 고정 URL만 작성 |
| 문서의 실앱 외형 | `not_verified` | Markdown 텍스트 구조 확인만 수행. GUI 사용 안 함 |
| CI 셸 문법 파싱 | `not_run` | Bash 초기화 접근 거부. `F-SANDBOX-RUNTIME` |
| slack-work-board 공용 원장 쓰기 | `not_run` | 스킬 정본의 쓰기 경로가 허용 범위 밖. `F-PATH-NOT-ALLOWED`. 독립 작업은 계속함 |

## 열린 위험

- 4.7.2 릴리스 파일과 GUT 9.3.0, Java 17, SDK 35의 실제 가용성·호환성은 첫 CI에서 확인해야 한다. 다른 버전으로 자동 대체하지 않는다.
- Mobile의 VAT 정점 텍스처 참조·GPU 입자·셰이더/API·키스토어 환경변수는 실행 미확인이다.
- 기기 시스템 한글 글꼴, 가로 화면 단추 위치, 카메라 연출, 어둠 격자의 외형은 화면 미확인이다.
- 좀비 제출 수는 MultiMesh에 보낸 수이며 GPU 픽셀 가림 결과가 아니다. 시야로 줄어들므로 설정 100만으로 최대 그리기 부하를 보장하지 않는다. 점검표에 제출 수도 기록한다.
- 정식 내비게이션·스켈레톤·동적 그림자·최종 에셋이 없어 회색 상자의 성능을 최종 게임의 성능 보증으로 해석할 수 없다.

## 가정

- 발주문의 4.7.2를 우선하고 최신성 조사나 4.8로의 교체는 하지 않았다.
- GUT 9.3.0을 고정했다. `tests/.gdignore`는 GUT을 받은 CI의 임시 checkout에서만 제거한다.
- 동작·VAT·도형은 직접 절차 생성한다. 소리는 무음 자리뿐이며 외부 에셋은 없다.
- 되돌릴 수 있는 기본값으로 seed 20261007, 격자 48×32, 시야 16칸, 소음 12m/6초, CPU 30Hz, 시야 10Hz, 비 256개를 선택했다.
- 하차 완료 후 **필드 진입**을 눌러 넘어가며 자세를 비교할 시간을 둔다. 로딩은 0.45초의 모의 대기다.
- 탭 이동은 바닥 투영과 벽 슬라이드이고 경로 탐색은 없다. 문까지 중간 탭이 필요할 수 있다. 소음의 벽 감쇠는 없고 VAT 법선은 원래 상자 법선으로 근사한다.
- 기본 필드는 100마리·시야/안개/비 ON이다. 필수 기준 행은 비 OFF로 고정하고 비 ON 조건을 따로 비교한다.

## 프로세스 종료

Godot나 상주 앱을 시작하지 않았다. PowerShell/Python/Git 도구 호출과 실패한 Bash가 종료를 반환했다. 실행 중인 cell·session은 남기지 않는다. Bash는 오류 뒤 스스로 종료했다. 마지막 납품 검사의 종료 코드와 출력은 `delivery-output.txt`에 보관한다.

## 다음 단계 (정확히 하나)

맡긴 쪽에서 이 변경을 현재 브랜치에 올려 **S2 Android performance spike CI를 한 번 실행한다**.
