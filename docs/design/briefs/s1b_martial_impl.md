# S1b 둘째 묶음: 계엄·경비대 재판·내전의 코드 모양 (제안)

작성: 2026-10-09 · 스레드 'S1b 어두운 길과 계엄' · 기준: [s1b_dark_path.md](s1b_dark_path.md) 5.3·5.4·5.5, [decisions.md](../decisions.md) 처형·내전과 계엄 결정, S1 코드 main 353abfc.

이 문서는 규칙을 새로 정하지 않는다. 5.3과 5.5의 규칙을 지금 S1 코드(`s1/src/game/`)의 자리에 맞춰 '어디에 무엇을 붙이는지'로 옮긴 것이다. 규칙과 다른 데가 있으면 5.3·5.5가 기준이고, 여기 적은 코드 쪽 단순화는 전부 제안이다. 숫자는 모두 `dark/data.ts`의 `B`에 두어 `tools/s1b_sim.ts --set`으로 잴 수 있게 한다.

## 0. 나누는 법 (제안)

둘째 묶음을 PR 둘로 나눈다. 하나로 하면 politics.ts·turn.ts·state.ts를 한꺼번에 크게 만져 'S1 코드 마무리' 스레드의 PR과 겹친다.

| PR | 들어가는 것 | 안 들어가는 것 |
|---|---|---|
| **A. 계엄 핵심** | 대권이 끝나는 카드(문 1), 계엄 상태, 포고 회기, 충성 계기와 쿠데타 끝, 유지비, 거두기와 포고 추인 묶음, 경비대 재판, 일대기·수단 점수 | 통행 금지(탄압 묶음과 함께), 직속 부대(S1c 지식 코드 뒤) |
| **B. 내전 직전과 내전** | 내전 직전 시계와 카드, 내전과 카드, 계엄 문 2·3·4, 휴전 서약 안건, 계엄 요청 안건 | 탄압 넷(강제 해산·지도부 근신·통로 통제·대표 근신)은 PR C로 따로 |

A가 먼저다. B의 문 셋은 A의 `enterMartial(g, door)` 하나를 부른다.

## 1. 상태 (dark/state.ts)

```ts
export type MartialDoor = 'extend' | 'council' | 'brink' | 'sided' | 'captain';
export interface Martial {
  door: MartialDoor;
  since: number;            // 선포한 구간
  trustBefore: number;      // 거둘 때 돌아갈 값의 기준(5.3: 직전 값 −15)
  decreed: LawId[];         // 계엄 중 포고로 통과한 법
  repealed: LawId[];        // 계엄 중 포고로 폐지한 법
  coupWarnAt: number | null;// 쿠데타 경고가 뜬 뒤 되돌릴 기한(구간). null이면 경고 없음
  warned: boolean;          // 경고가 한 번이라도 떴다(거둔 뒤 보너스 없음)
  rationLocked: number;     // 계엄이 올린 경비대 배급 레버 값(내릴 수 없다)
  against?: Comm;           // 편든 계엄(sided)에서 누른 쪽
}
// DarkState에 더한다
martial: Martial | null;
martialLifted?: { seg: number; bonus: boolean };   // 거둔 뒤 첫 추인 표결의 +2를 쓸지
powersPlan?: 'return' | 'ask' | 'extend';          // 대권이 끝나는 카드에서 고른 것
```

`Game`엔 더하지 않는다. S1a 판(`g.dark` 없음)은 아무 것도 바뀌지 않는다.

`EndKind`(state.ts)에 `'coup'`을 더한다. turn.ts `finish`의 끝 문장: "경비대장이 열차를 잡았다. 열차장은 창고칸에 앉아 있다." (닫힌 칸·가둠 그림 없음, 1.4). `darkFinish`는 다른 끝과 같은 길이다.

## 2. 문 1: 대권이 끝나는 카드 (PR A)

- **언제**: `darkPrep`(출발 전 운영)에서 `lawActive(g,'emergency_powers') && g.decreeLeft === 1`(포고할 수 있는 마지막 구간)이면 카드 `dark:powers_end`(화자 부관) 한 장. 판에 한 번이 아니라 대권마다 한 번.
- **선택지** (5.3 표 그대로): `dark:powers:return`(돌려준다, 신임 +5), `dark:powers:ask`(의회에 묻는다), `dark:powers:extend`(연장한다, **선을 넘는 선택지**. 검은 띠, `cross: 'martial'`).
  - 연장은 `stageOf(g.comms.guard.rel).index <= 2`(호의 이상)이고 `g.comms.guard.grudge === 0`일 때만 열린다. 아니면 회색이고 이유 "경비대장이 고개를 젓는다."
- **적용**: 고른 값을 `d.powersPlan`에 둔다. turn.ts `nextSegment`에서 `decreeLeft`가 0이 되는 자리(지금 `endEmergencyPowers(g)` 한 줄)를 `darkPowersEnd(g) || endEmergencyPowers(g)`로 바꾼다. S1a 판이면 `darkPowersEnd`가 false를 돌려주고 지금과 같다. 카드를 안 고른 채 구간이 넘어가면 '돌려준다'다.
  - return: `endEmergencyPowers` 그대로 + 신임 +5.
  - ask: `endEmergencyPowers` 그대로(포고는 추인 안건이 된다) + 다음 회기 안건에 `extend_powers`(법이 아닌 안건, 통치 67, rank `ratify`, 추인 안건들보다 앞). 통과하면 `enactLaw(g,'emergency_powers',[])`로 대권 3구간이 다시 서고, 그 회기의 `g.ratify`·`g.ratifyRepeal`을 비운다(그 사이 포고는 추인된 것으로 본다). 부결이면 아무 것도 더 하지 않는다(추인 안건이 이어서 오른다).
  - extend: `enterMartial(g, 'extend')`. 포고 목록은 `martial.decreed`로 옮기고 `g.ratify`엔 넣지 않는다(계엄이 끝날 때 한 묶음으로).

## 3. 계엄 상태 (PR A)

**들어설 때 `enterMartial(g, door)`**: `d.martial` 생성, 문에 따른 값(5.5 표):

| 문 | 적의·관계 | 긴장 | 신임 | 수단 |
|---|---|---|---|---|
| extend | 경비대 외 모든 칸 적의 +1(`offend`) | +10 | | `martial` 5 |
| council | 없음 | +3 | | `martial_council` 2 |
| brink | 맞선 두 집단 적의 +1, 끼지 않은 칸 관계 +5 | +5 | | `martial_brink` 4 |
| sided | 상대 집단 적의 +2, 끼지 않은 칸 관계 −3 | +5 | | `martial_sided` 5 |
| captain | brink와 같음 | +5 | −10 | 0(열차장이 고르지 않음) |

공통: 경비대 배급 레버 +1(상한 안에서)이고 `rationLocked`에 적는다. `trustBefore = g.trust`. 일지 'dark' 줄에 구간과 정차 장소. `scene(g,'martial',4, …)`. 비상대권 법이 걸려 있으면 내린다(`delete g.passed.emergency_powers`, `decreeLeft = 0`): 계엄은 법이 아니라 상태다. 열린 `trust_crisis` 카드와 `g.trustCrisis`는 지운다(신임 위기로 축출되지 않는다).

**`MEANS`에 더한다**: `martial: 5, martial_sided: 5, martial_brink: 4, martial_council: 2, martial_lifted: -2`(거둔 계엄은 5가 아니라 3, 5.3. 음수 항목은 `meansTotal`에서 0 아래로 내려가지 않게 한다), `guard_exec: 1`(경비대 재판 처형의 +1). `CROSSINGS`에 `martial, martial_sided, martial_brink`를 더한다. `GRAVE`엔 `martial_sided`만.

**회기 (의회 대신 포고)**: turn.ts가 회기 구간에 `openCouncil(g)`를 부르는 자리를 그대로 두고, `openCouncil` 안에서 `g.dark?.martial`이면 `council.martial = true`로 연다. 계엄 회기는:
- 안건은 법 제정·폐지만(`agendaOptions`에서 추인·법이 아닌 안건·AI 안건·법 요구 순서를 뺀다). `council.locked = false`, 거래 없음(`deals` 단추 숨김), `pre`(정기 신임) 없음, 재판 안건 없음(`darkCouncilOpen`이 `council.martial`이면 모두 건너뛴다. 정기 신임 간격 `confSince`도 세지 않는다).
- 표결 단추 대신 **포고** 단추만(`castVote(g, true)`가 지금 대권 포고와 같은 길이다: 긴장 +5, 싫어하는 칸 −3). 한 회기에 하나. 포고한 법은 `martial.decreed`/`repealed`에 적고, `g.ratify`엔 넣지 않는다.
- 포고 하나마다 경비대 관계 −5(`B.mlDecreeLoyal`), `afterVote`에서 `r.decree && d.martial`일 때.
- 회기를 그냥 닫을 수도 있다(포고 없음).
- 화면에 **'계엄을 거둔다'** 단추(의회 화면, 계엄 회기에만). 누르면 `liftMartial(g)` 뒤 그 회기는 바로 닫힌다(의회는 다음 정기 회기부터).
- 비상 소집(`emergencyCalls`)은 계엄 중 잠긴다("의회가 닫혀 있다"). 적의 3 지도자의 불신임 동의(`confBy`)는 쌓이기만 하고 계엄 중엔 오르지 않는다.

**신임 대신 충성**: 계엄 중 `g.trust`는 건드리지 않고 그대로 둔다(거둘 때 기준이 된다). 화면(ui)의 신임 계기 자리에 '경비대의 충성'을 `g.comms.guard.rel`로 그린다. turn.ts의 신임 위기(`g.trust <= 0`) 분기는 `g.dark?.martial`이면 건너뛴다. 정기 신임 표결 없음.

**쿠데타** (`darkSettle`, 정산마다):
- 문턱 `band`: 보통 `stageOf(guard.rel).band <= -1`(회의 이하), captain 문이면 `<= 0`(중립 이하).
- 문턱 아래인데 `coupWarnAt === null`이면 `coupWarnAt = g.seg + 2`, `warned = true`, 카드 `dark:coup_warn`(정보, 화자 부관: "경비대장이 당직표를 제 손으로 다시 짰다. 열차장 이름은 없다."). 문턱 위(호의 이상, captain이면 중립 이상)로 돌아오면 `coupWarnAt = null`. `g.seg >= coupWarnAt`이면 `END_LINK.finish(g, 'coup')`.
- 계엄 중 `supportComm(g,'guard')`는 막힌다("계엄 중엔 지지로 충성을 사지 못한다", 5.3). 경비대 배급 레버 올리기는 된다. 레버를 `rationLocked` 아래로 내리는 행동은 turn.ts 레버 처리에서 막는다.

**유지비** (`darkSettle`): 경비대 노출(`base[3]`) +2, 긴장 +2, 공포 +3 (`B.mlExpo, mlTension, mlFear`).

**비상 변형 본문**(5.3): PR A에선 밤샘(`dark:vigil`)의 화자를 경비대장으로, '허락한다'를 '통행 쪽지를 써 준다'로만 바꾼다. 나머지 카드의 비상 본문은 데이터가 생길 때.

**거두기 `liftMartial(g)`**:
- `g.trust = clamp(martial.trustBefore - 15, 0, 100)`. `d.martial = null`, `d.martialLifted = { seg, bonus: !martial.warned }`. 경비대 배급 레버 잠금 해제(값은 그대로).
- 포고로 바꾼 법 전부를 **안건 하나** `ratify_decrees`(법이 아닌 안건, 일반 51, rank `ratify`)로 다음 정기 회기에 올린다. `changes`에 법 이름을 전부 적는다. 통과하면 그대로, 부결이면 `decreed`는 `repealLaw`, `repealed`는 `enactLaw`. 재상정 쿨다운은 걸지 않는다. 이 안건의 `lean`은 법마다의 입장 평균 + (`martialLifted.bonus`면 +2, `B.mlLiftBonus`). 표결이 끝나면 `martialLifted`를 지운다.
- `cross(g,'martial_lifted')`(수단 −2). 일지: "투표함 뚜껑이 다시 열렸다."
- 정기 신임 표결은 정기 일정만 잇는다(거둔 직후 따로 열지 않음, `confSince`는 계엄 전 값 그대로).

**끝까지 가면**: 완주·좌초·반란·쿠데타. 완주하면 일대기에 '계엄 아래 닿았다' 장면. 포고는 추인 없이 남는다.

## 4. 경비대 재판 (PR A)

의회 재판(`dark/council.ts` TRIAL 안건)은 계엄 중 열리지 않는다. 대신:

- 수사 카드 `dark:case`의 '재판에 넘긴다'(`dark:trial`)가 계엄 중엔 '경비대 재판에 넘긴다'로 보인다. 효과는 같다: `sendTrial` → `status = 'trial'`, 군중 시계 +1(한 번).
- `darkPrep`(다음 출발 전 운영)에서 계엄 중이고 `status === 'trial'`인 사건마다 카드 `dark:gtrial`(화자 경비대장) 한 장: 피고(`topByClues`), 죄목, 증거 단계, 피고의 말 한 줄(`defenseLine`), 선례. 선택지 둘: `dark:gtrial:hear`(판결을 듣는다), `dark:gtrial:free`(풀어 준다).
  - hear: 유죄 확률 증거 1.0 / 정황 0.6 / 소문 0.3 (`B.gtrialP = [0.3, 0.6, 1]`). 유죄면 `cs.convicted = id`, `d.stats.trials += 1, guilty += 1`, `precedent`는 의회 재판과 같이 적고, 벌 카드 `dark:punish`(`text: 'guard'`)로 간다. 벌 넷 모두 열리고 처형도 된다(`punish(g, c, s, how, 'guard')`: `via`에 `'guard'`를 더하고 `EXECUTION.rule === 'trial'`에서 `via === 'trial' || via === 'guard'`를 허락한다. 처형이면 `cross(g,'executions')`에 더해 `cross(g,'guard_exec')`. 장면 글: '경비대장의 판결로').
  - 무죄면 의회 무죄와 같이 `acq = true`, `status = 'open'`, 시계 2. 피고 칸 관계 +3은 없다(표결이 없었다). 일지: "경비대장이 서류를 돌려보냈다. 증거가 모자란다고 했다."
  - free: 의회 무죄와 같다(`acq`, open, 시계 2). 공개로 풀어 준 것이라 피고 칸 관계 +3.
- 군중: 재판 카드가 뜨는 구간엔 군중 시계가 그대로 돈다(의회 재판처럼 회기 하나를 밀어내지 않으니 더 빠르다, 5.3 '의회 재판보다 빠르다').
- 계엄을 거둘 때 `status === 'trial'`인 사건은 다음 정기 회기 의회 재판으로 돌아간다(아무 것도 안 해도 된다. `MOTION_SOURCES`가 다시 집는다).

## 5. 내전 직전과 내전 (PR B)

```ts
export interface Brink {
  a: Comm; b: Comm;         // 원수 두 집단(둘 다 열기 2 이상, 둘 사이 불씨 2단계 이상)
  clock: number;            // 남은 구간(3, 전에 그 집단을 탄압했으면 2)
  stage: 1 | 2 | 3;         // 징후 강도
  opened: number;
  separated: boolean;       // '떼어 놓는다'를 썼다(한 번)
  truce?: { session: number; conds: [Cond, Cond]; kept: [boolean, boolean] };
}
export interface War { a: Comm; b: Comm; since: number; segs: number }
brink: Brink | null; war: War | null; brinkCount: number; warCount: number;
```

- **열림** (`darkSettle`): `brink === null && war === null && brinkCount < 2`이고 `rivals(a,b)`인 두 칸이 `fervor >= 2`이고 `d.embers`에 who∈{a,b}, target∈{b,a}, `stage >= 2`인 불씨가 있을 때. 끝 가까이엔 열지 않는다: `24 - g.seg < 3`이면 안 연다(5.5 `brink_late`).
- **시계** (`darkSettle`): `clock -= 1`, 긴장 +1, 두 집단 사이 불씨 `escProb` +0.2(`escalate`에서 `d.brink`를 본다). `clock === 0`이면 내전.
- **구간마다 카드** `dark:brink`(`darkPrep`, 화자 부관, 본문은 stage 1·2·3 조짐 셋 + 고정 해석 "두 칸이 서로를 노린다."): 선택지는 5.5 표 다섯. `dark:brink:table`(신임 40 이상만: 다음 회기 `truce` 안건, 일반 51, rank `crisis`. 통과하면 두 집단 조건 하나씩이 `g.leashes`와 같은 틀의 약속으로 걸리고, 시계 안에 둘 다 지키면 시계 멈춤과 열기 −1. 회기가 시계 안에 없으면 비상 소집이 필요하다고 본문에 적는다), `dark:brink:separate`(시계 +1 한 번, 두 집단 관계 −5, S1c 재배치 코드가 있으면 그 둘 떨어뜨리기에 −10%), `dark:brink:side`(한쪽을 고르는 둘째 카드 `dark:brink:side:a|b` → 고른 쪽 `supportComm` 값, 진 쪽 적의 +2, 50%로 진 쪽 불씨 `imm = 3`. 시계 끝. 지도부 근신은 PR C 뒤에), `dark:brink:martial`(**선을 넘음**. 경비대가 a·b가 아니면 `enterMartial(g,'brink')`, 경비대가 한쪽이면 `enterMartial(g,'sided')`에 `against`는 상대. 조건: 경비대 중립 이상. 두 집단 열기는 1로), `dark:brink:watch`(시계가 돈다).
- **계엄 요청 안건** `martial_request`(통치 67, rank `ai`, `by`는 경비대장이나 규율 쪽 지도자): 시계 2구간째에 40%. 통과하면 `enterMartial(g,'council')`.
- **내전** (`clock === 0`): `war = { a, b, since, segs: 0 }`, `brink = null`, `warCount += 1`. `darkSettle`마다 두 집단에서 1명 죽음(`onDeath`, 'violence')·2명 부상, 긴장 +8, `d.haul = 0.5`. 회기 구간이어도 의회가 열리지 않는다(turn.ts의 `openCouncil` 앞에서 `g.dark?.war`면 건너뛰고 일지 한 줄). 긴장 100이면 S1a 반란이 겹친다(그대로).
- **내전 카드** `dark:war`(`darkPrep`마다, 화자 경비대장, 건너뛸 수 없다): `dark:war:martial`(경비대 회의 이상. `enterMartial(g,'brink'|'sided')`, 다음 구간에 끝나며 그 정산에 1~2명 더 죽음, 끼지 않은 칸 관계 +3), `dark:war:side:a|b`(1구간에 끝, 진 쪽 지도자 50% 죽음·적의 3, 신임 −10), `dark:war:truce`(신임 60 이상. 50%로 끝, 두 집단 열기 2, 다음 회기 `truce` 안건), `dark:war:idle`(계속. 경비대장 `trait === 'ambition'`이고 경비대 호의 이상이면 40%로 `enterMartial(g,'captain')`).
- `segs >= 2`면 한쪽이 이긴다(의석 비율로 주사위): 진 쪽 지도자 50% 죽음, 진 쪽 적의 3, 신임 −15, 이긴 쪽이 다음 회기 법 하나를 요구(S1a 법 요구 틀). `war = null`.
- 경비대가 반대 이하면 `martial`·`side`가 잠긴다("경비대장이 대답하지 않는다").

## 6. 시뮬레이터 (tools/s1b_sim.ts, tools/s1c_bot.ts)

- `DarkPolicy`에 `tyrant`(계엄을 노린다: 대권이 열리면 통과시키고 끝나면 연장, 내전 직전·내전에선 계엄, 경비대 재판에선 늘 처형)를 더하고 RUNS에 넣는다. `GameMetrics.dark`에 `martialDoor`(문별 횟수), `martialSegs`, `coups`, `lifted`, `gtrials`, `gexec`, `brinks`, `wars`를 더한다.
- 재는 줄(15.3, 5.5): 돌보는 정책에서 내전 직전 15~30%·내전 5~10%, 계엄을 쓴 판의 완주가 비슷하거나 높고 사망·끝 신임에서 값을 치르는지, 반란+쿠데타+축출 합이 kind의 1.5배 이상.
- 지금 TS 봇은 비상대권을 거의 통과시키지 못한다(16.1 3차 7번과 같은 병목). tyrant 봇은 긴장 50 이상이면 비상대권을 먼저 올리게 한다. 그래도 0%면 문 1은 플레이에서만 보고(H7), 시뮬은 문 3으로 잰다.

## 7. H7에서 계엄을 볼 수 있게 (개발 도구, 제안)

시뮬에서 계엄은 거의 열리지 않았다(16.1 5차: 정책으로는 0%). 사용자가 H7 판정에서 계엄을 한 번은 봐야 하니, 주소 `?s1b=1&scene=powers`로 시작하는 **시험 시작 상태**를 둔다: 비상대권이 통과된 채 포고 마지막 구간(`decreeLeft = 1`)에서 시작해 첫 서류가 '대권이 끝나는 카드'다. `scene=brink`는 내전 직전 시계 2구간째다. 메뉴에는 넣지 않고 주소로만 연다(플레이 빌드 점검표에 적는다). 비상대권이 열리는 조건(법 16, 긴장 50 이상이나 신임 10 이하)을 낮추는 건 핵심 규칙 변경이라 H7 결과를 보고 사용자에게 묻는다.

## 8. 다른 스레드와 겹치는 파일

- `politics.ts`: `openCouncil`(계엄 회기), `agendaOptions`(계엄이면 법만), `castVote`/`afterVote` 훅은 이미 있다. `endEmergencyPowers`는 건드리지 않고 turn.ts에서 앞에 `darkPowersEnd`를 끼운다.
- `state.ts`: `EndKind`에 `coup`, `CouncilState`에 `martial?: boolean`.
- `turn.ts`: `nextSegment`의 대권 끝 한 줄, 신임 위기 분기의 `!g.dark?.martial`, 레버 내리기 잠금, 회기 열기 앞의 `war` 분기, `finish` 문장.
- `ui/app.ts`·`council.ts`·`meters`: 포고 단추, 거둔다 단추, 충성 계기. S1a 화면엔 한 줄 훅만 두고 그림은 `ui/dark.ts`에서(14장 원칙).
- 'S1 코드 마무리' 스레드가 K02 6~11, J10을 고치는 동안 같은 파일을 만지므로, PR A는 그 PR들이 합쳐진 뒤 main에서 다시 맞춘다.
