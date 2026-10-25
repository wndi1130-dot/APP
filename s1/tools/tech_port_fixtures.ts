// 연구 이식 표본(결정 446·449, PR 6). S2가 기술 복원·결함판·유지비·공방 작업량을 GDScript로 옮길 때 맞대 볼 기준 값을 만든다.
// 규칙 코드는 읽기만 하고 고치지 않는다. 셈을 여기서 다시 적지 않고, S1이 내보내는 함수를 그대로 불러 그 답을 적는다.
// 사용: npx tsx tools/tech_port_fixtures.ts [출력 경로=../s2/tests/fixtures/train/tech_vectors.json]
//
// 판은 S1c 판(createS1cGame)에서 이 PR이 옮기는 것만 남긴다: 견습·교본·교실·늙은 장인은 끄고, 사람 명부는 계약의 experts로 비춘다.
// 씨앗마다 상태 여덟 꼴 × 기술 21개를 정해 둔 난수(tech-port-v1)로 흔들고, 바꾸는 함수는 복제본에 불러 전/후를 적는다.
// train_vectors.json(S1a 판 계약)과 섞지 않는다.

import { mkdirSync, writeFileSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import { createRng, randomInt } from '../src/core/rng';
import { PROFILES } from '../src/game/state';
import type { Game } from '../src/game/state';
import { BRANCH_NAME, D, FIELDS, prereqs, skillNeed, SPECIALISTS, TECH_IDS, TECHS, ZONE0, ZONE_WORK } from '../src/game/domestic/data';
import type { Variant } from '../src/game/domestic/data';
import { createS1cGame, techMult, techUsable, topSkill } from '../src/game/domestic/state';
import {
  cancelRestore, finishCheck, GEAR_TECHS, NOT_YET, payUpkeep, restoreBlock, restoreCheck, restoreCost, runWorkshop, startFinish, startRestore,
  techShown, upkeepOf, workPower,
} from '../src/game/domestic/workshop';

// S1 화면(ui/domestic.ts)이 쓰는 거르개 그대로
const visibleTechs = (g: Game) => TECH_IDS.filter(id => techShown(g, id));

export const FORMAT = 'tech-vectors-v1';
// 씨앗 둘이면 상태 꼴·기술·흔든 값이 다 걸린다. 넷은 파일만 25MB로 커졌다.
const seeds = ['tech-0', 'tech-1'];
let rng = createRng('tech-port-v1');
const n = (lo: number, hi: number): number => {
  const next = randomInt(rng, lo, hi);
  rng = next.rng;
  return next.value;
};
const clone = (g: Game): Game => structuredClone(g);
const experts = (g: Game) => g.dom!.people.filter(p => p.alive && !p.gone)
  .map(({ name, comm, field, skill }) => ({ name, comm, field, skill }));
// 이 PR이 옮기는 상태만. S1 사람 명부(people)는 계약의 experts로 비춘다.
function state(g: Game) {
  const d = g.dom!;
  return { seg: g.seg, gearOn: !!g.gearOn, hands: g.hands ?? null,
    dom: { parts: d.parts, wood: d.wood, scrap: d.scrap, cores: d.cores, frags: d.frags,
      target: d.target, partWork: d.partWork, techs: d.techs, restoring: d.restoring, experts: experts(g) } };
}
function mutation(g: Game, f: (copy: Game) => unknown) {
  const copy = clone(g);
  const before = structuredClone(state(copy));
  const result = f(copy) ?? null;
  return { before, result, after: state(copy) };
}
function prepare(seed: string): Game {
  const g = createS1cGame(seed);
  const d = g.dom!;
  // PR 6에 없는 것: 견습 가르치기·교본·교실·늙은 장인·정치 배수
  for (const p of d.people) { delete p.pupil; delete p.learn; delete p.writing; delete p.resting; }
  delete d.elder;
  d.order = ['parts', 'restore'];
  return g;
}
const cases: unknown[] = [];
for (const seed of seeds) for (let profile = 0; profile < 8; profile++) for (const id of TECH_IDS) {
  const g = prepare(seed);
  const d = g.dom!;
  const cost = restoreCost(id);
  g.gearOn = profile % 2 === 0;
  d.parts = n(0, 24) / (profile === 7 ? 4 : 1);
  d.wood = n(0, 32); d.scrap = n(0, 32); d.cores = n(0, 2);
  d.target = n(0, D.targetMax); d.partWork = n(0, 3) / 4;
  for (const f of FIELDS) d.frags[f] = n(0, 5);
  for (const p of d.people) p.skill = n(0, 3);
  // 손 몫은 셈을 다시 적지 않고 모자람만 흔든다
  g.hands = { have: 0, short: { repair: n(0, 4) / 4 } } as Game['hands'];
  if (profile >= 1 && profile <= 4) {
    d.parts = 20; d.wood = 30; d.scrap = 30; d.cores = 2;
    for (const p of d.people) p.skill = 3;
    for (const f of FIELDS) d.frags[f] = 5;
    for (const pre of prereqs(id)) d.techs[pre] = { stage: 'done', defect: false, progress: 0, need: restoreCost(pre).work };
  }
  if (profile === 2) d.frags[TECHS[id].branch] = cost.defectFrags;
  if (profile === 3) d.techs[id] = { stage: 'defective', defect: true, progress: cost.work, need: cost.work };
  if (profile === 4) {
    d.techs[id] = { stage: 'restoring', defect: n(0, 1) === 1, progress: n(0, cost.work * 4) / 4, need: cost.work,
      ...(id === 'e3' ? { pending: seed === 'tech-0' } : {}) };
    d.restoring = id;
    d.parts = n(0, 5); d.target = 5;
  }
  if (profile >= 5) {
    for (const t of TECH_IDS) {
      const tc = restoreCost(t);
      const stage = (['done', 'defective', 'restoring'] as const)[n(0, 2)];
      d.techs[t] = { stage, defect: stage === 'defective', progress: n(0, tc.work * 4) / 4, need: tc.work,
        off: n(0, 4) === 0, starved: n(0, 1) === 1,
        ...(TECHS[t].variants ? { variant: n(0, 1) === 0 ? 'a' as Variant : 'b' as Variant } : {}) };
    }
    if (profile === 6) { delete d.techs[id]; d.restoring = null; }
    if (profile === 7) { d.parts = 0; d.wood = 0; d.scrap = 0; }
  }
  const input = structuredClone(state(g));
  const starts = [];
  for (const mode of ['full', 'defect'] as const) for (const variant of [undefined, 'a', 'b'] as const) {
    starts.push({ mode, variant: variant ?? null, ...mutation(g, copy => startRestore(copy, id, mode, variant)) });
  }
  const finish = mutation(g, copy => startFinish(copy, id));
  // 막 시작한 복원·보완을 취소하거나 한 구간 돌리는 이어진 표본도 적는다
  const chains = [];
  for (const mode of ['full', 'defect'] as const) {
    const copy = clone(g);
    if (startRestore(copy, id, mode, 'a')) chains.push({ kind: mode, cancel: mutation(copy, cancelRestore), run: mutation(copy, runWorkshop) });
  }
  const finished = clone(g);
  if (startFinish(finished, id)) chains.push({ kind: 'finish', cancel: mutation(finished, cancelRestore), run: mutation(finished, runWorkshop) });
  cases.push({ seed, profile, id, state: input,
    read: { cost: restoreCost(id, g), block: restoreBlock(g, id) ?? null, check: restoreCheck(g, id), finish: finishCheck(g, id) ?? null,
      upkeep: upkeepOf(g, id), work: workPower(g), usable: techUsable(g, id), mult: techMult(g, id),
      prereqs: prereqs(id), visible: visibleTechs(g), skills: Object.fromEntries(FIELDS.map(f => [f, topSkill(g, f)])) },
    starts, finish, cancel: mutation(g, cancelRestore), run: mutation(g, runWorkshop), upkeep: mutation(g, payUpkeep), chains });
}
const dKeys = ['restoreWork', 'restoreParts', 'restoreWood', 'restoreScrap', 'restoreFrags', 'defectFrags', 'adaptWork', 'finishWork',
  'work', 'workSkill', 'w1Work', 'partWork', 'partScrap', 'partWood', 'target0', 'targetMax', 'defectMult', 'knowledgeLow', 'glassParts'] as const;
const start = createS1cGame('research-start');
// TrainDom.start()는 판·난수를 받지 않는다. 전문가마다 그 칸의 아직 안 쓴 첫 이름을 PROFILES 차례로 고른다(나이·몸·건강은 안 따지고 난수도 안 씀).
const usedNames = new Set<string>();
const startExperts = experts(start).map(expert => {
  const person = PROFILES.find(p => p.community === expert.comm && !usedNames.has(p.name));
  if (!person) throw new Error('Missing roster name for ' + expert.comm);
  usedNames.add(person.name);
  return { ...expert, name: person.name };
});
const output = { format: FORMAT, seeds, profiles: 8,
  scope: 'PR6 experts only; no teaching/manuals/classroom/elder; mutations project owned inventory/tech state, not political cards/journal/stats',
  tables: { TECHS, TECH_IDS, FIELDS, BRANCH_NAME, SPECIALISTS, ZONE_WORK, ZONE0, NOT_YET, GEAR_TECHS,
    D: Object.fromEntries(dKeys.map(k => [k, D[k]])),
    prereqs: Object.fromEntries(TECH_IDS.map(id => [id, prereqs(id)])), skillNeed: Object.fromEntries(TECH_IDS.map(id => [id, skillNeed(id)])) },
  start: { referenceSeed: 'research-start', nameMethod: 'first unused community name in S1 PROFILES order', experts: startExperts, frags: start.dom!.frags }, cases };
const out = resolve(process.argv.find(a => a.endsWith('.json')) ?? '../s2/tests/fixtures/train/tech_vectors.json');
mkdirSync(dirname(out), { recursive: true });
// 전/후는 통째로 둔다. 빈칸 없는 JSON이라 같은 꼴이 되풀이돼도 덜 커진다.
const text = JSON.stringify(output) + '\n';
writeFileSync(out, text);
console.log(JSON.stringify({ format: FORMAT, seeds: seeds.length, cases: cases.length, bytes: Buffer.byteLength(text), out }));
