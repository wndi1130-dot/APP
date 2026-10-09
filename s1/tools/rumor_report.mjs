import { readFileSync, writeFileSync } from 'node:fs';
import { resolve } from 'node:path';

const input = process.argv[2] ?? 'tools/rumor_sim_4000.json';
const data = JSON.parse(readFileSync(input, 'utf8'));
if (Object.keys(data.runs).length !== 4 || data.baselineMatches !== 2000) throw new Error('F-RESULT-INCOMPLETE: 네 묶음 및 끔 해시 2,000판 확인이 필요하다');
const f = (v, d = 2) => v.toFixed(d);
const pct = v => `${f(v * 100)}%`;
const signed = v => `${v >= 0 ? '+' : ''}${f(v)}`;
const rows = Object.entries(data.runs).map(([key, r]) => {
  if (r.games !== data.n || r.terminal !== data.n) throw new Error(`F-NOT-TERMINAL: ${key}`);
  const [policy, mode] = key.split('/');
  return `| ${policy} | ${mode === 'on' ? '켬' : '끔'} | ${r.games.toLocaleString('en-US')} | ${pct(r.completionRate)} | ${r.passed}/${r.votes} (${pct(r.votePassRate)}) | ${f(r.tensionPeakMean)} | ${f(r.rumorCardsMean)} | ${f(r.overlapMean)} | ${f(r.cardsMean)} | ${f(r.repeatedCardsMean)} |`;
}).join('\n');
const changes = ['caretaker', 'first'].map(policy => {
  const on = data.runs[`${policy}/on`], off = data.runs[`${policy}/off`];
  return `| ${policy} | ${signed(100 * (on.completionRate - off.completionRate))}%p | ${signed(100 * (on.votePassRate - off.votePassRate))}%p | ${signed(on.tensionPeakMean - off.tensionPeakMean)} | ${signed(on.cardsMean - off.cardsMean)} | ${signed(on.cardsMean - off.cardsMean - on.rumorCardsMean)} | ${signed(on.repeatedCardsMean - off.repeatedCardsMean)} | ${signed(on.travelRepeatsMean - off.travelRepeatsMean)} |`;
}).join('\n');
const paired = ['caretaker', 'first'].map(policy => {
  const c = data.comparisons[policy];
  return `| ${policy} | ${signed(c.completionDelta * 100)} ± ${f(c.paired95HalfWidth * 100)}%p | ${c.bothComplete} | ${signed(c.bothCompleteCardsDelta)} | ${signed(c.bothCompleteRepeatedCardsDelta)} |`;
}).join('\n');
const choices = ['caretaker', 'first'].map(policy => `| ${policy} | ${data.runs[`${policy}/on`].rumorChoices.join(' | ')} |`).join('\n');
const report = `# C1 소문 시제품 측정 결과

상태: **partial**. 시제품·최종 비교 측정은 실행했다. 원래 \`npm test\` 전체 통과와 실행 전체의 쓰기 allowlist 준수를 충족했다고 판정할 수 없어 전체 완료를 선언하지 않는다. 필수 입력 누락이나 사용자 대기 상태는 없다.

기준 HEAD: \`9714567\`. 기준 규칙: 읽기 전용 \`_brief_politics_detail.md\` 7.0~7.3와 8.0의 눈보라 소문 지연 0. 이 사본을 우선했다. 인터넷·외부 모델·설치·권한 상승·sandbox 규칙 변경·git 쓰기·interactive GUI는 실행하지 않았다.

## 최종 측정

S1a만 사용해 caretaker·first 두 정책을 소문 켬/끔으로 각각 ${data.n.toLocaleString('en-US')}판 실행했다. 동일 시드 \`rumor-0\`~\`rumor-${data.n - 1}\`, 총 ${(data.n * 4).toLocaleString('en-US')}판이다. 네 묶음 모두 \`phase=end\` 및 종료 사유를 검사했다. 완주는 그중 \`end=complete\`인 판이다. 시뮬레이션 경과 ${f(data.elapsedSeconds, 3)}초.

| 정책 | 소문 | 판 수 | 완주율 | 회기 통과/실제 표결 | 긴장 최고 평균 | 소문 카드/판 | 같은 칸 겹침/판 | 전체 카드/판 | 반복 제목 카드/판 |
|---|---|---:|---:|---:|---:|---:|---:|---:|---:|
${rows}

회기 통과율은 실제 처리한 표결의 가결 수/표결 수이다. 통과한 법 종류 수를 분모로 쓰지 않는다. 긴장 최고는 봇의 행동 경계마다 관찰한 긴장의 판별 최고값이다. 같은 칸 겹침은 관계 대기열에서 새 소문이 기존 대기 소문과 경쟁한 횟수(남기거나 교체할 때 각각 1회)이며, 이미 도착한 과거 사건 및 관계 변화 0인 일지 전용 후속은 제외한다.

## 켬 − 끔 차이와 반복 카드 밀어내기

| 정책 | 완주율 차이 | 회기 통과율 차이 | 긴장 최고 차이 | 전체 카드/판 차이 | 소문 제외 카드/판 차이 | 반복 제목/판 차이 | 이동 반복/판 차이 |
|---|---:|---:|---:|---:|---:|---:|---:|
${changes}

소문 카드를 기존 이동 사건 대신 뽑는 할당량 규칙은 넣지 않았다. 기존 카드 대기열에 더한다. 표의 음수인 이동 반복 차이만으로 직접 밀어내기 효과를 확정할 수 없다. 생존 구간·정책·관계·난수 소비 변화도 결과를 바꾼다. 전체 카드와 전체 반복 제목 변화까지 같이 본다.

같은 시드 두 판의 완주 차이로 정규근사 95% 범위를 계산했다. 양쪽 모두 완주한 판만 따로 본 카드 차이는 생존 길이의 영향을 줄이는 보조 관찰이며, 선택된 부분집합이라 전체 판의 인과 효과로 일반화하지 않는다.

| 정책 | 짝지은 완주 차이 ± 95% 반폭 | 양쪽 완주 시드 수 | 그 시드의 전체 카드 차이/판 | 그 시드의 반복 제목 차이/판 |
|---|---:|---:|---:|---:|
${paired}

## 봇의 소문 선택

first는 늘 첫 선택지인 사실 붙이기다. caretaker는 신임 50 이상이면 사실 붙이기, 그보다 낮으면 사건 칸 원한이 0이고 공포가 30 미만일 때 입단속, 나머지는 방치한다. S1a의 기존 일반 카드 정책은 유지했다. 따라서 세 선택지를 무작위로 같은 비율로 시험한 결과는 아니다.

| 정책 | 사실 붙이기 | 입단속 | 방치 |
|---|---:|---:|---:|
${choices}

## 7장 숫자를 바꿀 안

현재 기본값은 그대로 0/1/2구간·1.5배·4구간 한 번이다. 아래는 **미실행 후보(\`not_run\`)**이며 기본값 변경이나 효과 검증을 주장하지 않는다. 겹침·긴장 상승·전체 카드 증가를 각각 분리해 비교하도록 한 숫자씩 바꾸는 편이 해석하기 쉽다.

| 숫자 | 현재 | 비교 후보 | 의도와 아직 모르는 것 |
|---|---|---|---|
| 지연 | 사건 칸 0 / 옆 1 / 먼 2 | 0 / 1 / 1 | 먼 칸 대기 시간을 줄여 겹침 감소를 확인한다. 더 많은 효과가 도착하면 긴장이 오히려 오를 수 있다. |
| 부풀림 | 건너온 칸 ×1.5, 한 번 | ×1.25 | 회기 통과율 하락과 긴장 상승이 완화되는지 본다. 지연·겹침의 영향은 남는다. |
| 카드 간격 | 전역 4구간에 최대 1회 | 전역 6구간에 최대 1회 | 카드 증가를 줄인다. 사실 붙이기·입단속 기회도 줄어 관계 효과는 악화될 수 있다. |

이 시제품에서 반복 카드 밀어내기가 확인됐다고 판단하지 않는다. 간격만 늘리는 안은 카드 수 억제이고 기존 반복 사건을 직접 교체하는 안이 아니다.

## 구현과 가정

- 플래그는 \`enableRumor(g)\`로 켜는 판별 선택 상태 \`g.rumor\`이다. 기본 판에는 필드를 추가하지 않는다. 끔 판 ${data.baselineMatches.toLocaleString('en-US')}개의 전체 JSON SHA-256을 변경 전 판과 비교해 일치를 확인했다.
- 관계 효과가 원래 있던 칸만 운반한다. 아무 효과가 없던 칸에 새 벌점을 만들지 않는다. 사건 칸은 카드·작업조·정치 행동의 칸을 우선한다. 법·칸 없는 사건은 가장 큰 관계 반응의 칸이며 동률은 탄 순서로 정한다.
- 칸 순서는 \`data.ts COMMS\`의 역순인 기관실→앞칸→경비대→기술·의무진→꼬리칸이다. 재배열 API는 새 사건에 적용한다. 이미 출발한 소문의 도착 예정 구간은 유지한다.
- 대기열은 칸·남은 구간·크기·문장 번호와 사건 ID·발생 칸·원래 변화량·절대 도착 구간을 저장한다. 발생한 구간의 정산에서 다음 구간 몫을 미리 깎지 않으며, 소수 변화량은 반올림하지 않는다. 건너온 칸에 한 번만 ×1.5를 붙인다.
- 사건 칸은 즉시 적용한다. 전달받는 칸의 대기 소문은 큰 절댓값 하나만 남기고 동률은 앞선 소문을 남긴다. 작은 소문의 관계 효과는 버린다. 이 손실 자체가 게임 균형에 영향을 주는 가정이다.
- 카드 문턱은 부풀린 도착 변화량의 절댓값 5이다. 관계 상한에 잘려 실제 변화가 작아도 문턱은 요청 변화량을 쓴다. 전역 카드 간격은 생성 구간 기준이며 해당 소문의 일지 한 줄은 항상 남긴다.
- 신임 50 이상의 사실 정정은 같은 사건의 남은 소문을 멈추고 이미 도착한 부풀림을 거둔다. 입단속은 남은 전파만 멈추고 사건 칸 원한 +1·공포 +3을 준다. 방치는 유지한다. 낮은 신임 해명은 신임 −2와 열차장 역할의 새 문장 전파다. 별도 관계 벌점은 기준에 없으므로 만들지 않았고, 더 큰 관계 소문이 있는 칸은 문장 전용 후속이 대기열을 차지하지 않는다.
- 사건·정치·정차·약속 함수를 감싸 그 함수의 순수 관계 차이를 한 묶음으로 포착한다. 중첩 함수는 한 번만 처리한다. 내부 함수가 관계를 잠시 즉시 바꿔 계산한 다음 반환 경계에서 운반하므로 함수 내부 판단까지 지연시키는 완성 구조는 아니다. 지속적인 배급·온기·피로 관계 변화는 생활 상태로 간주해 직접 적용을 유지했다. S1b/S1c 고유 경로 전체의 소문화는 이번 S1a 실험 범위 밖이다.
- 원본에는 C3 눈보라 지속 상태나 화물역 칸 재배열 상태가 없다. 소문 모듈에 최소 연결 API를 제공했다. 눈보라 동안 새 사건의 타 칸 효과와 기존 대기 소문은 같은 정산에 도착하고 부풀림은 한 번이다. 실제 날씨 발생·예고·난방·정차 C3 전체는 넣지 않았다. 최종 시뮬레이션에는 눈보라를 강제로 넣지 않았고 해당 예외는 전용 시험으로 검증했다.
- 안전한 사건 종류별 자리 문장 세 벌을 쓴다. 사건별 상세 사실/오보 콘텐츠 전체는 만들지 않았다. 소문 주어는 대표·열차장 등 열차 안 역할이다. 감염 전파 책임·민족·종교 집단·통로 폐쇄 표현은 추가하지 않았다.
- 저장 복원 \`readSave\` 및 \`cloneGame\`에서 대기열·간격·통계 보존을 실제 시험했다. 잘못된 소문 저장 필드의 별도 스키마 검사는 아직 없다. 장기 저장 형식 안정성과 모든 사건의 출처 지정은 열린 위험이다.

## 실제 검증·실패·미실행

| 항목 | 관찰값 | 상태 / failure code / blocked reason |
|---|---|---|
| 원래 \`npm test\` | exit 1, Vite Windows 파스 확인에서 \`spawn EPERM\` | failed, \`F-PROCESS-SPAWN\`; 기존 시험 전체 통과 아님 |
| 별도 설정의 전체 Vitest | 1,060 통과 / 16 실패 / 1 skipped | 14개 CLI spawn 제한, 2개 5초 한도 초과. 전체 통과 \`not_verified\` |
| 시간 초과 2개와 C1 재검사 | 단일 워커, 3파일 43시험 통과, exit 0 | 기존 5초 한도를 바꾸지 않고 재검사해 시간 초과 해소 |
| 최종 C1·거래·법 검사 | 3파일 22시험 통과, exit 0 | 실제 실행, 최종 게임 코드 수정 뒤 확인 |
| TypeScript | 최초 오류 2개 수정 후 \`tsc --noEmit\` exit 0, 오류 로그 없음 | 실제 실행; 생성 build는 아님 |
| TypeScript 네이티브 실행 | 설치된 절대 경로 \`node_modules/@typescript/typescript-win32-x64/lib/tsc.exe --noEmit\` exit 0, 오류 로그 없음 | 래퍼 종료 처리에 의존하지 않고 직접 확인 |
| 끔 회귀 | 연결 전 2,000판 JSON SHA-256 vs 최종 판 일치 | 실제 검증, 최종 측정에서도 같은 2,000판을 다시 대조 |
| 비교 시뮬레이션 | 예비 4,000판 + 최종 16,000판 | 총 20,000판 비교 실행. 별도 기준 작성/검증 4,000판은 비교 판 수에 합치지 않음 |
| exact process terminal | 기록된 실행 세션 각각의 최종 종료 코드 확인, 최종 16,000판 세션 exit 0 | 실제 tool terminal. 프로세스 조회와 구분한다 |
| 전체 프로세스 잔여 조회 | CIM Win32_Process 액세스 거부 | \`not_verified\`, \`F-PROCESS-QUERY\`; 조회 실패를 잔여 0개로 기록하지 않는다. 실행 세션 종료는 별도 확인 |
| 최초 tsx 실행 | esbuild 하위 프로세스 \`spawn EPERM\` | \`F-PROCESS-SPAWN\`, Node 자체 TypeScript 경로로 시뮬레이션 해소 |
| 파일 쓰기 경계 | 직접 만든 코드·도구·로그·결과는 allowlist. 별도 전체 Vitest의 기존 시험은 \`s1/.local\` 및 OS 임시 경로 사용 | \`F-WRITE-SCOPE\`; 실행 전 시험 부작용 확인을 빠뜨려 실행 전체 준수는 주장 불가. 시험 자체 정리가 있어도 준수 증거로 쓰지 않음. 해당 전체 실행은 반복하지 않음 |
| 공용 작업 원장 | 갱신 안 함 | \`not_run\`, \`F-WRITE-SCOPE\`; 원장은 현재 허용 경로 밖 |
| build·브라우저·실앱·시각 render | 실행 안 함 | \`not_run\`; 범위 밖 산출/캐시와 interactive GUI 금지. Markdown 구조 및 원자료 숫자만 읽기 확인 |
| 입력·사용자 승인 대기 | 없음 | \`F-INPUT-MISSING\`·\`F-NEEDS-USER\`는 적용하지 않음 |
| 보고서 생성 | 최초 template literal 문법 오류와 inline 수정 명령 인용 오류를 관찰, 파일 본문 범위를 직접 수정 후 생성 exit 0 | \`F-REPORT-SYNTAX\` 해소. 최종 보고서는 실제 원자료에서 생성 |

기존 전체 시험이 허용 목록 밖 임시 경로를 사용하는 것을 실행 후 발견했다. 이 경계 위반 가능성과 시험 시작 제한을 숨기지 않는다. 해당 경로의 추가 삭제·수정은 하지 않았다. 전체 완료 조건을 충족하지 못한 이유다.

## 바뀐 파일과 실제 산출물

- 게임 코드: \`s1/src/game/rumor.ts\`, \`cards.ts\`, \`politics.ts\`, \`turn.ts\`, \`state.ts\`, \`index.ts\`.
- 자동 플레이어: \`s1/tools/s1c_bot.ts\`.
- 도구: \`s1/tools/rumor_node.mjs\`, \`rumor_sim.ts\`, \`rumor_report.mjs\`, \`rumor_off_baseline.ts\`, \`rumor_checks.ts\`, \`rumor_vitest.config.mjs\`.
- 신규 시험: \`s1/tests/game/rumor.test.ts\`.
- 보고서: \`rumor_sim_result.md\`.
- 증거: \`s1/tools/rumor_off_baseline.json\`, \`rumor_sim_1000.json\`, \`rumor_sim_4000.json\`, 해당 실행 로그와 시험 로그, \`rumor_artifact_hashes.json\`, \`rumor_process_terminal.json\`. npm/Vitest 캐시·시험용 TEMP는 \`s1/tools/rumor_*\` 아래다.
- 기준 사본·docs·package.json·lockfile·node_modules의 코드는 수정하지 않았다. git add/commit/checkout/stash는 실행하지 않았다. git diff/status는 읽기만 사용했다.

## 돌린 명령과 판 수

작업 위치는 저장소의 \`s1\`이다. 모든 Node 명령은 \`C:\\Program Files\\nodejs\\node.exe\`, npm 명령은 같은 폴더의 \`npm.cmd\`를 사용했다. 아래 상대 경로는 그 위치 기준이다. 실행 로그는 각각 \`tools/rumor_*.log\`에 보존했다.

| 명령 | 실제 실행량 / 결과 |
|---|---|
| \`node node_modules/tsx/dist/cli.mjs tools/rumor_off_baseline.ts\` | spawn 실패, 완성 판 0 |
| \`node --experimental-transform-types tools/rumor_node.mjs tools/rumor_off_baseline.ts\` | 로컬 JSON import 처리 전 0판, 처리 후 caretaker/first 각 1,000판 기준 해시 작성 |
| \`node --experimental-transform-types tools/rumor_node.mjs tools/rumor_off_baseline.ts --verify\` | 끔 2,000판 재실행, 모두 일치 |
| \`node --experimental-transform-types tools/rumor_node.mjs tools/rumor_sim.ts 1000 tools/rumor_sim_1000\` | 네 조건 각 1,000판, 4,000판, exit 0 |
| \`node --experimental-transform-types tools/rumor_node.mjs tools/rumor_sim.ts 4000 tools/rumor_sim_4000\` | 네 조건 각 4,000판, 16,000판, 해시 2,000판 확인. exact terminal은 별도 프로세스 증거 파일에 기록 |
| \`npm test\` | exit 1, 시험 시작 차단 |
| \`node node_modules/vitest/vitest.mjs run --config tools/rumor_vitest.config.mjs --configLoader native\` | 별도 전체 실행 1,060통과/16실패/1skipped, exit 1 |
| \`node node_modules/vitest/vitest.mjs run tests/game/people.test.ts tests/ui/seats.test.ts tests/game/rumor.test.ts --maxWorkers 1 --config tools/rumor_vitest.config.mjs --configLoader native\` | 43시험 통과, exit 0 |
| \`node node_modules/vitest/vitest.mjs run tests/game/rumor.test.ts tests/game/deal_rules.test.ts tests/game/lawtech.test.ts --maxWorkers 1 --config tools/rumor_vitest.config.mjs --configLoader native\` | 최종 22시험 통과, exit 0 |
| \`node --experimental-transform-types tools/rumor_node.mjs tools/rumor_checks.ts --run\` | C1 검사 10개 통과, exit 0 |
| \`node node_modules/typescript/lib/tsc.js --noEmit\` | 최초 타입 오류 2개 관찰·수정, 최종 exit 0 |
| \`node tools/rumor_report.mjs tools/rumor_sim_4000.json\` | 이 결과 파일을 실제 원자료에서 생성 |

최종 게임 코드 검사 이후 추가 게임 코드 변경은 없다. 시뮬레이션의 비종료 판과 끔 해시 차이는 발견 즉시 예외로 중단하도록 했으며 이번 최종 측정에서는 발견하지 않았다.

## 정확히 하나의 다음 행동

현재 파일 쓰기 경계를 지키고 하위 프로세스 실행이 허용되는 시험 환경에서 원래 \`npm test\`를 재실행해 전체 통과 여부를 확인한다.
`;
const out = resolve('../rumor_sim_result.md');
writeFileSync(out, report);
console.log(`결과 기록: ${out}, ${data.n * 4}판, 끔 해시 ${data.baselineMatches}판`);
