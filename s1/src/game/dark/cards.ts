import { COMM_NAME, REP_ROLE } from '../data';
import type { Comm } from '../data';
import { CARD_EXTENSIONS, VIEW_FILTERS } from '../cards';
import type { CardView, Choice } from '../cards';
import { journal, situation } from '../state';
import { revertLater } from '../people';
import type { Card, Game } from '../state';
import { B, EXECUTION, TRAIN_ORDER } from './data';
import {
  boardingText, caseById, coverUp, crimeTitle, crowdLine, eligible, level, LEVEL_WORD, mobTarget, openCase, protect, punish, punishPreview,
  guardFree, guardTrial, scapegoat, sendTrial, settleTruth, summary, topByClues, updateFlags,
} from './cases';
import type { Punish } from './cases';
import { closeChronicle, nightmareSay, reaction } from './chronicle';
import { defenseLine } from './council';
import { canExtend } from './martial';
import { ruleChosen, vigil } from './corpses';
import { fill, freeGuards, guarded, guardsOut, postGuard, signRead } from './embers';
import {
  afterOrder, answerThreat, dropOrder, exeOptions, exeVoice, METHOD, orderOpen, roleLine, setExe, setMethod, startOrder, successP,
} from './order';
import { adults, alive, commOf, darkCard, dpick, dr, eul, iga, nameOf, segFull } from './state';
import type { Ember, OrderExe, OrderMethod } from './state';

// S1b 카드(13장). 본문과 대사는 자리표시이고 Gemini가 같은 결로 쓴다. 선을 넘는 선택지는 cross에 반응 한 줄(10.1)을 단다.
// 화면은 cross가 있으면 검은 띠를 두른다(ui/card.ts). 무뎌짐이면 반응 줄이 빈칸이다(10.5).

/** S1b가 올리는 카드 종류(구간 예산 등급표 budget.ts가 빠진 것을 가린다). 새 dark: 카드를 만들면 여기도 넣는다. */
export const DARK_CARD_KINDS = [
  'dark:sign', 'dark:armory', 'dark:act', 'dark:theft', 'dark:case', 'dark:punish', 'dark:mob', 'dark:truth', 'dark:hostile', 'dark:exec_threat',
  'dark:order_exe', 'dark:order_method', 'dark:order_done', 'dark:order_fail', 'dark:corpse_rule', 'dark:vigil',
] as const;

const rep = (g: Game, c: Comm) => ({ name: g.comms[c].leader.name, role: REP_ROLE[c], comm: c });
/** 수사·징후의 화자: 경비대장. 경비대장이 용의자이거나 경비대 적의 2 이상이면 부관(4.4). */
function officer(g: Game, suspects: string[] = []): { name: string; role: string; comm: Comm } {
  const gl = g.comms.guard.leader;
  if (suspects.includes(gl.personId) || g.comms.guard.grudge >= 2) return { name: nameOf(g, g.dark!.staff.deputy), role: '부관', comm: 'front' };
  return rep(g, 'guard');
}
const ok = (label: string, say?: string): Choice => ({ label, ...(say ? { say } : {}), effs: [], special: 'dark:none' });
const crossing = (g: Game, card: Card, ch: Choice, about?: string): Choice => ({ ...ch, cross: reaction(g, about, `${card.uid}|${ch.special}`) });

function view(g: Game, card: Card): CardView | null {
  if (!card.kind.startsWith('dark:') || !g.dark) return null;
  const d = g.dark;
  const c = card.comm ?? 'tail';
  switch (card.kind) {
    case 'dark:sign': {
      const pair = signPair(g, card);
      if (pair) return pairView(g, pair);
      const e = d.embers.find(x => x.id === card.n) ?? (card.vals?.n2 ? d.embers.find(x => x.id === Number(card.vals!.n2)) : undefined);
      const solo = e && e.id !== card.n;
      const tier = (solo ? card.vals?.tier2 : card.text) ?? 'kiche';
      if (!e) return { title: '지나간 기척', speaker: officer(g), body: [card.who, card.vals?.who2].filter(Boolean).join('\n'), required: true, choices: [ok('알았다')] };
      const read = signRead(e, tier);
      const full = guardsOut(g) >= B.guardMax && !guarded(g, e);
      const boiler = tier === 'imm' && e.imm === 2 && e.sab === 'boiler';
      const coupling = tier === 'imm' && e.imm === 2 && e.sab === 'coupling';
      return {
        title: tier === 'kiche' ? '기척' : '임박', speaker: officer(g), focus: e.who, required: true,
        body: `${(solo ? card.vals?.who2 : card.who) ?? ''} ${read}`,
        choices: [
          { label: '경비를 붙인다', say: '두 사람 붙여라. 밤에도 눈 떼지 마라.', effs: [], special: 'dark:guard', disabled: guarded(g, e) ? '이미 서 있다' : full ? '경비가 두 곳에 나가 있다' : freeGuards(g).length < B.guardPair ? '경비대에 남은 사람이 모자라다' : undefined, extra: ['경비대 노출 +3', '공포 +2', ...(coupling ? ['꼬리칸 관계 −3'] : [])] },
          ...(boiler ? [{ label: '수석 기관사에게 맡긴다', say: `${g.comms.engine.leader.name}, 밤 교대는 네가 직접 봐라.`, effs: [], special: 'dark:engine', disabled: g.comms.engine.rel < 15 ? '기관실이 열차장을 따르지 않는다' : undefined }] : []),
          { label: '대표를 부른다', say: `${g.comms[e.who].leader.name}, 네 칸에서 무슨 말이 도는지 들어 보자.`, effs: [], special: 'dark:call' },
          { label: '모른 척한다', say: '쪽지 한 장에 경비를 뺄 수는 없다.', effs: [], special: 'dark:none' },
        ],
      };
    }
    case 'dark:armory':
      return {
        title: '무기고 열쇠', speaker: rep(g, 'guard'), focus: 'guard', required: true,
        body: '무기고 선반에서 칼 하나가 비었다. 장부엔 그대로다. 열쇠를 누가 쥘지 정해 두자고 한다.',
        choices: [
          { label: '열쇠는 경비대장만', say: '열쇠는 경비대장 하나만 쥔다. 오늘부터.', effs: [{ t: 'rel', c: 'guard', v: 3 }, { t: 'rel', c: 'tail', v: -3 }, { t: 'rel', c: 'engine', v: -3 }], special: 'dark:armory:on' },
          { label: '그대로 둔다', say: '지금처럼 둬라. 칼 하나에 칸을 뒤질 순 없다.', effs: [], special: 'dark:armory:off' },
        ],
      };
    case 'dark:act': {
      const sab = card.vals?.sab;
      return {
        title: sab ? '사보타주' : '일이 났다', speaker: officer(g), focus: c, required: true, body: card.text ?? '',
        choices: sab
          ? [{ label: '수사를 연다', say: '누가 손댔는지 찾아라.', effs: [], special: 'dark:sab:case' }, ok('덮어 둔다', '고쳐 놓고 넘어가라. 지금은 사람을 뒤질 때가 아니다.')]
          : [ok('알았다')],
      };
    }
    case 'dark:theft':
      return {
        title: '빈 창고', speaker: { name: nameOf(g, d.staff.ration), role: '배급장', comm: 'front' }, focus: c, required: true, body: card.text ?? '',
        choices: [{ label: '수사를 연다', say: '장부를 다시 맞춰라. 누가 가져갔는지.', effs: [], special: 'dark:theft:case' }, ok('눈감는다', '굶은 사람을 뒤지지 마라.')],
      };
    case 'dark:case': {
      const cs = caseById(g, card.n);
      if (!cs || cs.status === 'closed') return { title: '닫힌 수사', body: '이 일은 이미 끝났다.', required: true, choices: [ok('알았다')] };
      const live = eligible(g, cs);
      const lines = live.map(s => `${nameOf(g, s.id)}(${boardingText(g, s.id)}) · ${LEVEL_WORD[level(s)]}${s.clues.length ? `: ${s.clues[s.clues.length - 1].line}` : ''}`);
      const top = topByClues(g, cs);
      const canTrial = !!top && level(top) >= 1;
      const martial = !!d.martial;
      return {
        title: `수사: ${crimeTitle(g, cs)}`, speaker: officer(g, cs.sus.map(s => s.id)), focus: cs.victimComm, required: true,
        body: [`${cs.where}. 용의자 셋.`, ...lines].join('\n'), faces: live.map(s => nameOf(g, s.id)),
        choices: [
          { label: '더 캔다', say: '아직 이르다. 그날 밤 교대 명단부터 다시 가져와.', effs: [], special: 'dark:dig' },
          martial
            ? { label: '경비대 재판에 넘긴다', say: '경비대장, 서류를 읽고 판결해라. 식당칸은 닫혀 있다.', effs: [], special: 'dark:trial', disabled: cs.status === 'trial' ? '이미 넘겼다' : canTrial ? undefined : '정황 이상인 용의자가 없다', extra: ['다음 출발 전 경비대장이 판결한다'] }
            : { label: '재판에 넘긴다', say: '식당칸에서 모두가 보는 앞에서 가린다.', effs: [], special: 'dark:trial', disabled: cs.status === 'trial' ? '이미 넘겼다' : canTrial ? undefined : '정황 이상인 용의자가 없다', extra: ['다음 회기 안건 자리를 쓴다'] },
          { label: '경비대가 처리한다', say: '경비대장, 오늘 안에 끝내라. 이름은 네가 골라.', effs: [], special: 'dark:summary', extra: ['공포 +5', '경비대 외 관계 −2'] },
          { label: '덮는다', say: '보일러 일지에 미끄러졌다고 적어라. 오늘 날짜로.', effs: [], special: 'dark:cover', extra: [`${COMM_NAME[cs.victimComm]} 적의 +1`] },
        ],
      };
    }
    case 'dark:punish': {
      const via = card.text === 'summary' ? 'summary' : card.text === 'guard' ? 'guard' : 'trial';
      const who = card.who ?? '';
      const name = nameOf(g, who);
      const execOff = EXECUTION.rule === 'none' ? '처형은 없다' : EXECUTION.rule === 'trial' && via === 'summary' ? '처형은 재판 판결로만' : undefined;
      // 벌의 반응은 증거 단계를 따른다(4.4). 고르기 전에 근거 한 줄과 단계에 맞춘 관계 값을 보인다(벌을 내릴 때와 같은 값).
      const pcs = caseById(g, card.n);
      const s = pcs?.sus.find(x => x.id === who);
      const pv = s ? punishPreview(s) : null;
      const proof = pv?.lv === 2 && pcs ? [`${COMM_NAME[pcs.victimComm]} 관계 +2`] : [];
      const head = via === 'trial' ? `의회가 ${name}에게 유죄를 냈다. 벌은 열차장이 정한다.` : `경비대장이 ${name}${eul(name)} 데려왔다.`;
      return {
        title: `${name}의 벌`, speaker: via === 'trial' ? undefined : via === 'guard' ? rep(g, 'guard') : officer(g, [who]), focus: c, required: true,
        body: pv ? `${head}\n${pv.basis}` : head,
        faces: [name],
        choices: [
          { label: '배급을 끊는다', say: '그 몫은 피해 칸에 돌려라. 사흘이다.', effs: [], special: 'dark:punish:ration', extra: [`${COMM_NAME[c]} 관계 −${pv?.ration ?? 3}`, ...proof] },
          { label: '근신', say: '경비대 칸 구석에 앉혀라. 손은 묶지 마라.', effs: [], special: 'dark:punish:confine', extra: ['경비대 노출 +2/구간', ...proof] },
          crossing(g, card, { label: '하차 명령', say: '짐 하나와 사흘 치 빵을 줘라. 다음 역에서 내린다.', effs: [], special: 'dark:punish:exile', extra: [`${COMM_NAME[c]} 관계 −${pv?.exile ?? 8}`, '공포 +5', ...proof] }, who),
          ...(EXECUTION.rule === 'none' ? [] : [crossing(g, card, { label: '처형', say: '판결은 났다. 해가 지기 전에 끝내라.', effs: [], special: 'dark:punish:execute', disabled: execOff, extra: [`${COMM_NAME[c]} 적의 +1`, '공포 +10', ...proof] }, who)]),
        ],
      };
    }
    case 'dark:mob': {
      const cs = caseById(g, card.n);
      if (!cs || cs.status === 'closed') return { title: '흩어진 사람들', body: '사람들이 흩어졌다.', required: true, choices: [ok('알았다')] };
      const t = mobTarget(g, cs);
      if (!t) {
        return {
          title: '모인 사람들', speaker: rep(g, cs.victimComm), focus: cs.victimComm, required: true,
          body: `${crowdLine(g, cs)} 사람들이 모였지만 누구 이름에도 모이지 못했다.`,
          choices: [{ label: '돌려보낸다', say: '범인은 경비대가 찾는다. 돌아가라.', effs: [{ t: 'tension', v: 3 }, { t: 'rel', c: cs.victimComm, v: -3 }], special: 'dark:mob:none' }],
        };
      }
      const name = nameOf(g, t.id);
      const canTrial = !cs.promiseUsed;
      return {
        title: '사람들이 범인을 찾는다', speaker: rep(g, cs.victimComm), focus: cs.victimComm, required: true,
        body: `${crowdLine(g, cs)} 사람들이 ${name}${eul(name)} 끌어내려 한다. ${name}${iga(name)} ${boardingText(g, t.id)}.`, faces: [name],
        choices: [
          crossing(g, card, { label: '내준다', say: '그날 밤 거기 있던 건 그자뿐이다. 데려가라.', effs: [], special: 'dark:mob:give' }, t.id),
          { label: '지킨다', say: '아무도 손대지 마라. 경비대, 그 앞에 서라.', effs: [], special: 'dark:mob:protect', extra: ['경비대 노출 +5', `${COMM_NAME[cs.victimComm]} 관계 −5`, '공포 +3'] },
          { label: '재판을 약속한다', say: '다음 회기에 가린다. 내 이름을 걸겠다.', effs: [], special: 'dark:mob:promise', disabled: canTrial ? undefined : '이 일엔 이미 약속했다' },
          crossing(g, card, { label: '물러선다', say: '…경비대는 물러서라.', effs: [], special: 'dark:mob:lynch' }, t.id),
        ],
      };
    }
    case 'dark:truth': {
      const innocent = card.who ?? '';
      const w = card.text;
      const iname = nameOf(g, innocent);
      return {
        title: '드러나려는 일', speaker: officer(g), focus: c, required: true,
        body: w && alive(g, w) ? `${nameOf(g, w)}${iga(nameOf(g, w))} ${iname}의 일을 두고 할 말이 있다고 한다. 내일 식당칸에서.` : `${iname}의 일을 두고 다른 말이 돈다.`,
        choices: [
          { label: '말하게 둔다', say: '들어 보자. 틀렸으면 틀린 거다.', effs: [], special: 'dark:truth:let' },
          ...(w && orderOpen(g, w) ? [crossing(g, card, { label: '조용히 처리한다', say: '그 입을 닫게 해라.', effs: [], special: 'dark:truth:order', extra: [roleLine(g, w, 'truth')] }, w)] : []),
        ],
      };
    }
    case 'dark:hostile': {
      const who = card.who ?? g.comms[c].leader.personId;
      const name = nameOf(g, who);
      return {
        title: '불신임 동의', speaker: rep(g, c), focus: c, required: true,
        body: `${name}${iga(name)} 다음 회기에 열차장 불신임을 올리겠다고 한다. ${roleLine(g, who, 'hostile')}`,
        choices: [
          { label: '받는다', say: '올려라. 의회가 정하면 따른다.', effs: [], special: 'dark:hostile:let' },
          ...(orderOpen(g, who) ? [crossing(g, card, { label: '조용히 처리한다', say: '회기 전에 끝내라. 조용히.', effs: [], special: 'dark:hostile:order' }, who)] : []),
        ],
      };
    }
    case 'dark:exec_threat': {
      const who = card.who ?? '';
      const name = nameOf(g, who);
      return {
        title: '쥐고 있는 말', speaker: { name, role: COMM_NAME[c], comm: c }, focus: c, required: true,
        body: `${name}${iga(name)} 찾아왔다. 그날 일을 아직 기억한다고 한다. 사치품 셋을 원한다.`,
        choices: [
          { label: '들어준다', say: '원하는 걸 말해라. 이번 한 번이다.', effs: [], special: 'dark:threat:give', disabled: g.lux < 3 ? '사치품이 모자라다' : undefined, extra: ['사치품 −3'] },
          { label: '버틴다', say: '해 볼 테면 해 봐라.', effs: [], special: 'dark:threat:stand' },
          { label: '먼저 털어놓는다', say: '모두 들어라. 내가 한 일이다.', effs: [], special: 'dark:threat:confess', extra: ['신임 −10'] },
          ...(orderOpen(g, who) ? [crossing(g, card, { label: '조용히 처리한다', say: '이 사람의 입을 닫게 해라.', effs: [], special: 'dark:threat:order', extra: [roleLine(g, who, 'silence')] }, who)] : []),
        ],
      };
    }
    case 'dark:order_exe': {
      const target = card.who ?? '';
      const opts = exeOptions(g, target);
      const o = d.order;
      const voice = (exe: OrderExe) => exeVoice(successP(g, { target, why: o?.why ?? 'hostile', exe }));
      return {
        title: '누구를 보내나', focus: c, required: true, body: `${nameOf(g, target)}. ${roleLine(g, target, o?.why ?? 'hostile')}`,
        choices: [
          { label: '경비대 사람', say: '경비대에서 하나 보내라. 입이 무거운 자로.', effs: [], special: 'dark:exe:guard', disabled: opts.guard.why, extra: opts.guard.id ? [voice('guard')] : [] },
          { label: '원수', say: '그자를 미워하는 사람이 있지. 그를 불러라.', effs: [], special: 'dark:exe:rival', disabled: opts.rival.why, extra: opts.rival.id ? [voice('rival')] : [] },
          { label: '매인 사람', say: '네가 진 빚을 갚을 때다.', effs: [], special: 'dark:exe:bound', disabled: opts.bound.why, extra: opts.bound.id ? [voice('bound')] : [] },
          { label: '거둔다', say: '…아니다. 잊어라.', effs: [], special: 'dark:order:drop' },
        ],
      };
    }
    case 'dark:order_method': {
      const o = d.order;
      const target = card.who ?? '';
      const voice = (m: OrderMethod) => exeVoice(successP(g, { ...(o ?? { target, why: 'hostile' }), method: m }));
      const p = (m: OrderMethod) => `들킬 수 있다${METHOD[m].caught >= 0.4 ? '(크게)' : ''}`;
      return {
        title: '어떻게', speaker: o?.exeId ? { name: nameOf(g, o.exeId), role: '실행자', comm: commOf(g, o.exeId) } : undefined, focus: c, required: true,
        body: `${nameOf(g, target)}. 방법을 정한다.`,
        choices: [
          { label: '사고처럼', say: '보일러 쪽이든 승강대든, 사고로 보이게 해라.', effs: [], special: 'dark:method:accident', extra: [voice('accident'), p('accident')] },
          { label: '정차에서', say: '다음 정차에 둘을 같이 내보내라.', effs: [], special: 'dark:method:stop', extra: [voice('stop'), p('stop'), '다음 정차 영수증에 따로 적힌다'] },
          { label: '칸 안에서, 밤에', say: '밤에 해라. 다른 칸이 잘 때.', effs: [], special: 'dark:method:night', extra: [voice('night'), p('night')] },
          { label: '거둔다', say: '…아니다. 잊어라.', effs: [], special: 'dark:order:drop' },
        ],
      };
    }
    case 'dark:order_done': {
      const name = nameOf(g, card.who ?? '');
      const kin = card.vals?.kin;
      // 수사는 늘 열린다(4.6). 사고로 꾸며 들키지 않았으면 그 줄이 먼저다. 들켰으면 붙잡힌 줄이 text에 온다.
      const hidden = card.text === 'hidden';
      const caughtLine = !hidden && card.text ? ` ${card.text}` : '';
      const seen = !hidden && !!card.text;
      return {
        title: '끝났다', focus: c, required: true,
        body: `${name}${iga(name)} 죽었다.${hidden ? ' 사고라고 적혔다. 그래도 수사가 열린다.' : ` 수사가 열린다.${caughtLine}`}${kin ? ` ${kin}${iga(kin)} 식당칸 문가에 서 있다.` : ''}`,
        ...(kin ? { faces: [kin] } : {}),
        choices: [
          // 들켜서 실행자가 붙잡혔으면 일지로는 못 덮는다. 경비대 입을 막는 값 오른 줄이 대신 나온다(제안, PR 41 리뷰).
          seen
            ? { label: '입단속한다', say: '경비대에 입을 다물라고 해라. 본 사람은 못 본 거다.', effs: [], special: 'dark:after:hush', extra: [`공포 +${B.hushFear}`, `경비대 노출 +${B.hushExpo}`] }
            : { label: '덮는다', say: '보일러 일지에 사고라고 적어라.', effs: [], special: 'dark:after:cover' },
          crossing(g, card, { label: '남에게 씌운다', say: '용의자 하나의 침상 밑을 뒤져라. 뭐가 나올 거다.', effs: [], special: 'dark:after:frame' }),
          { label: '수사하게 둔다', say: '수사는 수사대로 둬라.', effs: [], special: 'dark:after:let' },
        ],
      };
    }
    case 'dark:order_fail':
      return { title: '실패', focus: c, required: true, body: card.text ?? '', choices: [ok('알았다')] };
    case 'dark:corpse_rule': {
      const again = d.practice !== null;
      return {
        title: '확인은 누가', speaker: rep(g, 'medtech'), focus: c, required: true,
        body: again ? `${card.who ?? ''}의 확인을 두고 다시 묻는다. 지난번처럼 해도 되겠느냐고.` : `${COMM_NAME[c]}에서 ${card.who ?? '사람'}${iga(card.who ?? '사람')} 죽었다. 일어나기 전에 누가 확인할지 정해야 한다.`,
        choices: [
          { label: '경비대가 한다', say: '경비대 일이다. 총은 경비대에 있다.', effs: [], special: 'dark:rule:guard', extra: ['죽음마다 경비대 노출 +1, 관계 −2'] },
          { label: '의무진이 한다', say: '의무진이 마지막을 본다. 그게 맞다.', effs: [], special: 'dark:rule:medtech', extra: ['죽음마다 의무진 관계 −3'] },
          { label: '그 칸이 한다', say: '그 칸 사람이 그 칸 사람을 보낸다.', effs: [], special: 'dark:rule:car', extra: ['죽음마다 그 칸 관계 −1, 공포 +2'] },
        ],
      };
    }
    case 'dark:vigil': {
      const name = card.who ?? '';
      const martial = !!d.martial; // 계엄 중엔 통행을 허락하는 사람이 경비대장이다(5.3 비상 변형)
      return {
        title: '밤샘', speaker: martial ? rep(g, 'guard') : rep(g, c), focus: c, required: true,
        body: `${name}의 곁을 하룻밤 지키겠다고 한다.`,
        choices: [
          { label: martial ? '통행 쪽지를 써 준다' : '허락한다', say: martial ? '하룻밤이다. 쪽지에 칸 이름과 시간을 적어라.' : '하룻밤이다. 등잔 하나는 켜 둬라.', effs: [], special: 'dark:vigil:allow', extra: [`${COMM_NAME[c]} 관계 +4`] },
          { label: '경비와 함께', say: '지켜라. 다만 경비 하나가 문가에 선다.', effs: [], special: 'dark:vigil:guard', extra: [`${COMM_NAME[c]} 관계 +2`, '경비대 노출 +1'] },
          { label: '거절한다', say: '오늘 보내야 한다. 미안하다.', effs: [], special: 'dark:vigil:refuse', extra: [`${COMM_NAME[c]} 관계 −3`] },
        ],
      };
    }
    case 'dark:powers_end': {
      const deputy = { name: nameOf(g, d.staff.deputy), role: '부관', comm: 'front' as Comm };
      const why = canExtend(g);
      const decrees = (g.decreed ?? []).length + (g.decreedRepeals ?? []).length;
      return {
        title: '약속한 날', speaker: deputy, required: true,
        body: `대권이 오늘로 끝난다. 포고한 법이 ${decrees}건 책상에 쌓여 있다.`,
        choices: [
          { label: '돌려준다', say: '약속한 날이다. 권한을 의회에 돌려준다.', effs: [], special: 'dark:powers:return', extra: [`신임 +${B.powersReturnTrust}`, '포고는 다음 정기 회기에 추인받아야 남는다'] },
          { label: '의회에 묻는다', say: '아직 끝나지 않았다. 의회가 정하게 하라.', effs: [], special: 'dark:powers:ask', extra: ['대권은 약속한 날에 끝난다', '다음 회기 안건: 비상대권 연장(67표)'] },
          crossing(g, card, { label: '연장한다', say: '의회는 기다릴 수 없다. 대권은 계속된다.', effs: [], special: 'dark:powers:extend', disabled: why ?? undefined, extra: ['계엄이 선다. 의회 대신 포고, 신임 대신 경비대의 충성', '경비대 외 모든 칸 적의 +1', '긴장 +10'] }),
        ],
      };
    }
    case 'dark:coup_warn':
      return {
        title: '당직표', speaker: { name: nameOf(g, d.staff.deputy), role: '부관', comm: 'front' }, required: true,
        body: '경비대장이 당직표를 제 손으로 다시 짰다. 열차장 이름은 없다.',
        choices: [ok('알았다')],
      };
    case 'dark:gtrial': {
      const cs = caseById(g, card.n);
      const top = cs ? topByClues(g, cs) : undefined;
      if (!cs || !top || cs.status !== 'trial') return { title: '닫힌 서류', body: '이 재판은 이미 끝났다.', required: true, choices: [ok('알았다')] };
      const name = nameOf(g, top.id);
      const lv = level(top);
      const pre = d.precedent[cs.kind];
      const lines = [
        `${name}(${boardingText(g, top.id)}) · ${crimeTitle(g, cs)}`,
        `증거 단계: ${LEVEL_WORD[lv]}${top.clues.length ? `. ${top.clues[top.clues.length - 1].line}` : ''}`,
        `피고의 말: "${defenseLine(g, { kind: 'motion', motion: 'trial', person: top.id, ref: cs.id })}"`,
        ...(pre ? [`지난번엔 ${LEVEL_WORD[pre.level]}만으로 ${pre.guilty ? '유죄' : '무죄'}를 냈다.`] : []),
      ];
      return {
        title: `경비대 재판: ${name}`, speaker: rep(g, 'guard'), focus: cs.victimComm, required: true, body: lines.join('\n'), faces: [name],
        choices: [
          { label: '판결을 듣는다', say: '경비대장, 읽어라. 나는 듣겠다.', effs: [], special: 'dark:gtrial:hear', extra: [['소문이면 유죄가 나기 어렵다', '정황이면 유죄가 날 때가 많다', '증거면 유죄가 난다'][lv], '유죄면 벌 넷이 모두 열린다'] },
          { label: '풀어 준다', say: '증거가 모자라다. 풀어 줘라.', effs: [], special: 'dark:gtrial:free', extra: [`${COMM_NAME[commOf(g, top.id)]} 관계 +3`, '군중이 다음 구간에 온다'] },
        ],
      };
    }
    default:
      return null;
  }
}

function choose(g: Game, card: Card, ch: Choice): void {
  const d = g.dark;
  if (!d) return;
  if (d.nightmareCards > 0) d.nightmareCards -= 1;
  // 카드로 판이 끝났다(반란 등): 일지 끝에 H7 한 줄.
  if (g.phase === 'end') closeChronicle(g);
  const sp = ch.special ?? '';
  if (!sp.startsWith('dark:')) return;
  const cs = caseById(g, card.n);
  const say = (text: string, tone: 'dark' | 'bad' | undefined = 'dark') => { if (text) journal(g, text, tone); };
  switch (sp) {
    case 'dark:guard': case 'dark:guard2': case 'dark:guard:both': {
      // 묶인 쪽지(4.2)에선 첫째 줄, 둘째 줄, 둘 다. 홀로 남은 둘째 줄이면 그 불씨.
      const pair = signPair(g, card);
      const one = signEmbers(g, card)[0];
      const picked = !pair ? (one ? [one] : []) : sp === 'dark:guard' ? [pair.a.e] : sp === 'dark:guard2' ? [pair.b.e] : [pair.a.e, pair.b.e];
      for (const e of picked) postGuard(g, e);
      break;
    }
    case 'dark:engine': {
      const e = signEmbers(g, card).find(x => x.imm === 2 && x.sab === 'boiler');
      if (e) e.blocked = true;
      break;
    }
    case 'dark:call': {
      const e = signEmbers(g, card)[0];
      if (e && !g.cards.some(k => k.kind === 'demand')) darkCard(g, { kind: 'demand', comm: e.who }, false);
      break;
    }
    case 'dark:armory:on': d.armory = true; break;
    case 'dark:armory:off': d.armory = false; break;
    case 'dark:sab:case': {
      const e = d.embers.find(x => x.id === card.n);
      const v = (card.vals?.v ?? card.comm ?? 'tail') as Comm;
      const kind = (card.vals?.sab ?? 'boiler') as 'boiler' | 'coupling' | 'poison' | 'heating';
      if (e) openCase(g, { kind, culprit: e.actor, victimComm: v, dead: false, clock: null, ember: e.id, where: fill(g, '{place}', e, 2) });
      break;
    }
    case 'dark:theft:case':
      if (card.who) openCase(g, { kind: 'theft', culprit: card.who, victimComm: 'front', dead: false, clock: null, where: '창고칸' });
      break;
    case 'dark:dig': break;
    case 'dark:trial': if (cs) sendTrial(g, cs); break;
    case 'dark:summary': {
      if (!cs) break;
      const s = summary(g, cs);
      if (s) darkCard(g, { kind: 'dark:punish', n: cs.id, who: s.id, comm: commOf(g, s.id), text: 'summary' }, false);
      break;
    }
    case 'dark:cover': if (cs) coverUp(g, cs); break;
    case 'dark:powers:return': d.powersPlan = 'return'; break;
    case 'dark:powers:ask': d.powersPlan = 'ask'; break;
    case 'dark:powers:extend': d.powersPlan = 'extend'; break;
    case 'dark:gtrial:hear': if (cs && cs.status === 'trial') guardTrial(g, cs); break;
    case 'dark:gtrial:free': if (cs && cs.status === 'trial') guardFree(g, cs); break;
    case 'dark:punish:ration': case 'dark:punish:confine': case 'dark:punish:exile': case 'dark:punish:execute': {
      const s = cs?.sus.find(x => x.id === card.who);
      if (cs && s) for (const line of punish(g, cs, s, sp.slice('dark:punish:'.length) as Punish, card.text === 'summary' ? 'summary' : card.text === 'guard' ? 'guard' : 'trial')) say(line);
      break;
    }
    case 'dark:mob:give': case 'dark:mob:lynch': {
      const t = cs ? mobTarget(g, cs) : undefined;
      if (cs && t) say(scapegoat(g, cs, t, sp === 'dark:mob:lynch'), 'bad');
      break;
    }
    case 'dark:mob:protect': if (cs) say(protect(g, cs)); break;
    case 'dark:mob:promise':
      if (cs) {
        cs.promiseUsed = true;
        cs.status = 'trial';
        cs.promised = g.session + 1;
        if (cs.clock !== null) cs.clock = 1;
      }
      break;
    case 'dark:mob:none':
      if (cs) { cs.clock = null; updateFlags(g); }
      break;
    case 'dark:truth:let': {
      if (card.who) say(settleTruth(g, card.who, true), 'bad');
      break;
    }
    case 'dark:truth:order':
      if (card.text && card.who) {
        // 진실이 드러나기 전에 입을 막으려 한다. 명령이 끝날 때까지 묶어 두고(창을 다시 열지 않는다),
        // 성공하면 묻히고 실패하거나 거두면 바로 드러난다(order.ts runOrder, dropOrder).
        const x = d.innocents.find(y => y.id === card.who);
        if (x) { x.asked = false; x.held = true; }
        else d.innocents.push({ id: card.who, comm: commOf(g, card.who), seg: g.seg, caseId: card.n ?? -1, how: 'punish', held: true });
        startOrder(g, card.text, 'truth');
        d.order!.ref = card.who;
      }
      break;
    case 'dark:hostile:let':
    case 'dark:hostile:order':
      d.confBy = card.comm ?? null;
      d.confLeader = card.who ?? null;
      if (sp === 'dark:hostile:order' && card.who) startOrder(g, card.who, 'hostile');
      break;
    case 'dark:threat:give': case 'dark:threat:stand': case 'dark:threat:confess':
      if (card.who) say(answerThreat(g, card.who, sp.slice('dark:threat:'.length) as 'give' | 'stand' | 'confess'));
      break;
    case 'dark:threat:order': if (card.who) startOrder(g, card.who, 'silence'); break;
    case 'dark:exe:guard': case 'dark:exe:rival': case 'dark:exe:bound':
      setExe(g, sp.slice('dark:exe:'.length) as OrderExe);
      break;
    case 'dark:method:accident': case 'dark:method:stop': case 'dark:method:night':
      setMethod(g, sp.slice('dark:method:'.length) as OrderMethod);
      break;
    case 'dark:order:drop': dropOrder(g); break;
    case 'dark:after:cover': case 'dark:after:hush': case 'dark:after:frame': case 'dark:after:let':
      say(afterOrder(g, card.n, sp.slice('dark:after:'.length) as 'cover' | 'hush' | 'frame' | 'let'));
      break;
    case 'dark:rule:guard': case 'dark:rule:medtech': case 'dark:rule:car':
      d.practiceAsked += 1;
      ruleChosen(g, sp.slice('dark:rule:'.length) as 'guard' | 'medtech' | 'car');
      break;
    case 'dark:vigil:allow': case 'dark:vigil:guard': case 'dark:vigil:refuse':
      if (card.who) vigil(g, { comm: card.comm ?? 'tail', name: card.who }, sp.slice('dark:vigil:'.length) as 'allow' | 'guard' | 'refuse');
      break;
    default: break;
  }
}

/** 징후 쪽지에 걸린 산 불씨들(첫째 줄, 둘째 줄 순) */
function signEmbers(g: Game, card: Card): Ember[] {
  const d = g.dark!;
  const ids = [card.n, card.vals?.n2 !== undefined ? Number(card.vals.n2) : undefined];
  return ids.map(id => d.embers.find(x => x.id === id)).filter((x): x is Ember => !!x);
}

interface SignLine { e: Ember; tier: string; line: string }
/** 두 줄이 다 살아 있는 묶인 쪽지면 두 줄을 돌려준다. 하나만 남았으면 null(한 줄 쪽지로 본다). */
function signPair(g: Game, card: Card): { a: SignLine; b: SignLine } | null {
  if (!card.vals?.n2) return null;
  const d = g.dark!;
  const a = d.embers.find(x => x.id === card.n);
  const b = d.embers.find(x => x.id === Number(card.vals!.n2));
  if (!a || !b) return null;
  return { a: { e: a, tier: card.text ?? 'kiche', line: card.who ?? '' }, b: { e: b, tier: card.vals.tier2 ?? 'kiche', line: card.vals.who2 ?? '' } };
}

/** 묶인 징후 쪽지(4.2): 두 줄과 각 해석. 경비는 한쪽이나 둘 다, 수석 기관사는 보일러 임박이 있을 때만. 대표 부르기는 한 줄 쪽지에만 있다. */
function pairView(g: Game, p: { a: SignLine; b: SignLine }): CardView {
  const { a, b } = p;
  const free = B.guardMax - guardsOut(g);
  const need = [a, b].filter(x => !guarded(g, x.e)).length;
  const hands = Math.floor(freeGuards(g).length / B.guardPair);
  const same = a.e.who === b.e.who;
  const label = (x: SignLine, i: number) => (same ? `${i === 0 ? '첫째' : '둘째'} 일에 경비` : `${COMM_NAME[x.e.who]} 쪽에 경비`);
  const coupling = (x: SignLine) => x.tier === 'imm' && x.e.imm === 2 && x.e.sab === 'coupling';
  const boiler = [a, b].find(x => x.tier === 'imm' && x.e.imm === 2 && x.e.sab === 'boiler');
  const one = (x: SignLine, i: number, special: string): Choice => ({
    label: label(x, i), say: '두 사람 붙여라. 밤에도 눈 떼지 마라.', effs: [], special,
    disabled: guarded(g, x.e) ? '이미 서 있다' : free < 1 ? '경비가 두 곳에 나가 있다' : hands < 1 ? '경비대에 남은 사람이 모자라다' : undefined,
    extra: [`경비대 노출 +${B.guardExpo}`, `공포 +${B.guardFear}`, ...(coupling(x) ? ['꼬리칸 관계 −3'] : [])],
  });
  return {
    title: a.tier === 'imm' || b.tier === 'imm' ? '임박' : '기척', speaker: officer(g), focus: a.e.who, required: true,
    body: `${a.line} ${signRead(a.e, a.tier)}\n${b.line} ${signRead(b.e, b.tier)}`,
    choices: [
      {
        label: '둘 다 경비를 붙인다', say: '두 곳 다 두 사람씩 붙여라.', effs: [], special: 'dark:guard:both',
        disabled: need === 0 ? '이미 서 있다' : free < need || hands < need ? '경비가 모자란다' : undefined,
        extra: [`경비대 노출 +${B.guardExpo * need}`, `공포 +${B.guardFear * need}`, ...([a, b].some(coupling) ? ['꼬리칸 관계 −3'] : [])],
      },
      one(a, 0, 'dark:guard'),
      one(b, 1, 'dark:guard2'),
      ...(boiler ? [{ label: '수석 기관사에게 맡긴다', say: `${g.comms.engine.leader.name}, 밤 교대는 네가 직접 봐라.`, effs: [], special: 'dark:engine', disabled: g.comms.engine.rel < 15 ? '기관실이 열차장을 따르지 않는다' : undefined }] : []),
      { label: '모른 척한다', say: '쪽지 한 장에 경비를 뺄 수는 없다.', effs: [], special: 'dark:none' },
    ],
  };
}

CARD_EXTENSIONS.push({ view, choose });

/** 악몽(10.5): 선을 넘은 다음 몇 장의 카드에서 열차장 말이 첫 문장에서 끊긴다. 수치는 없다. */
VIEW_FILTERS.push((g, _card, v) => {
  const d = g.dark;
  if (!d || d.nightmareCards <= 0 || d.nightmareUntil < g.seg) return v;
  return { ...v, choices: v.choices.map(ch => (ch.say && !ch.cross ? { ...ch, say: nightmareSay(ch.say) } : ch)) };
});

/** 정산: 배급이 20 이하로 2구간인 칸은 구간마다 30%로 창고를 턴다(4.3, 사다리 밖). 2구간째에 기척 한 줄이 먼저 온다(약속은 아니다).
 * 원한이 아니라 배고픔이라 불씨를 만들지 않는다. 수사는 선택이고, 굶은 사람을 벌하는지가 이 사건의 무게다. */
export function theftTick(g: Game): void {
  const d = g.dark!;
  for (const c of TRAIN_ORDER) {
    if (situation(g, c)[1] <= B.starveLine) d.rationStreak[c] += 1;
    else d.rationStreak[c] = 0;
    if (d.rationStreak[c] === 2) journal(g, `${COMM_NAME[c]} 배급 줄에서 감자 껍질 냄새가 나는 사람이 셋이다. 오늘 감자는 나오지 않았다.`, 'dark');
    if (d.rationStreak[c] < 2 || dr(g) >= B.theftP) continue;
    const pool = adults(g, c, { noRep: true, except: d.confined.map(x => x.id) });
    if (!pool.length) continue;
    const thief = dpick(g, pool);
    const lost = 4 + Math.round(dr(g) * 2);
    g.food = Math.max(0, g.food - lost);
    g.comms[c].base[1] += 5;
    revertLater(g, c, 1, 5, 2);
    d.stats.theft += 1;
    const text = `창고 장부와 자루가 맞지 않는다. 식량 ${lost}이 비었다. ${COMM_NAME[c]} 그릇이 며칠 조금 찼다.`;
    if (segFull(g) || g.cards.some(k => k.kind === 'dark:theft')) {
      d.stats.cardsDeferred += 1;
      journal(g, text, 'dark');
      continue;
    }
    darkCard(g, { kind: 'dark:theft', comm: c, who: thief.id, text });
  }
}
