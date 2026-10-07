import { COMM_NAME } from '../data';
import { josa } from '../josa';
import type { Comm } from '../data';
import { CARD_EXTENSIONS } from '../cards';
import type { CardView, Choice, Eff } from '../cards';
import { clamp, journal, rnd } from '../state';
import type { Card, Game } from '../state';
import { attachCar, giveCandidates, giveCar } from './cars';
import { BRANCH_NAME, D, FIELD_NAME, TECHS } from './data';
import type { Field, TechId, Variant } from './data';
import { resolvePressure } from './hooks';
import { techUseLine } from './lawtech';
import { hygieneWhy, resolveLice, resolveTyphus } from './hygiene';
import { attachApprentice, distributeBlocked, fieldOwner, freeTeacher, manualWriter, startManual } from './knowledge';
import { setBedOrder } from './medbay';
import { domCard, personById } from './state';
import type { DomPerson } from './state';
import { breakPenalty, BREAK_LINES, CAR_NAME, jobCheck, restoreCheck, setFullRule, setTarget, standDown, startRestore, techRelSides, techTitle } from './workshop';

const pct = (v: number): string => `${Math.round(v * 100)}%`;

// 내정 카드 12장(10장)과 위생 카드 둘(16.5), 파업·느린 열차 카드 둘(8.7). 서류 뭉치에 S1a 카드와 같이 쌓인다.
// 선택지 말은 열차장의 외침(15자 이름, 40자·두 문장 이내 말). 문장은 자리표시다(나중에 Gemini 문장으로 바꾼다).
// 고를 게 없는 것(반쪽 설계도, 고장 수리, 견습 완료, 마지막 한 사람, 장부 내려놓기, 두 번째 창고 넘침)은 일지 한 줄로 간다.

function sp(p: DomPerson | undefined): CardView['speaker'] {
  return p ? { name: p.name, role: p.role, comm: p.comm } : undefined;
}

function chief(g: Game, f: Field): DomPerson | undefined {
  return (g.dom?.people ?? []).filter(p => p.alive && !p.gone && p.field === f).sort((a, b) => b.skill - a.skill)[0];
}

/** 열병 카드에 앓는 사람 이름을 적는다(16.5, J10 11번). 이름이 없으면 수만. */
function typhusNames(g: Game, c: Comm, n: number): string {
  const names = (g.dom?.typhus ?? []).filter(t => t.comm === c).flatMap(t => t.patients);
  if (names.length === 0) return `${n}명이`;
  const last = names[names.length - 1];
  return `${names.join(', ')}${josa(last, '이/가')}`;
}

const rel = (c: Comm, v: number): Eff => ({ t: 'rel', c, v });

/** 위생 카드의 공동체. 비어 있으면 꼬리칸으로 떨어뜨리지 않고 멈춘다(J10 W9: 병이 늘 꼬리칸 몫으로 읽히지 않게, 시험에서 잡히게). */
function needComm(card: Card): Comm {
  if (!card.comm) throw new Error(`${card.kind} 카드에 공동체가 없다`);
  return card.comm;
}

function sidesEffs(id: TechId, v?: Variant): Eff[] {
  const s = techRelSides(id, v);
  return [...s.like.map(c => rel(c, D.techRel)), ...s.dislike.map(c => rel(c, -D.techRel))];
}

const GIVE_LABEL: Record<string, string> = { front: '앞칸을 내준다', store: '창고칸을 내준다', cold: '냉동칸을 내준다', tail3: '꼬리칸 하나를' };
const GIVE_EXTRA: Record<string, string[]> = {
  front: ['앞칸 온기 −15, 과밀 +20', '온실 식량 +3/구간'], store: ['자재 상한 0', '온실 식량 +1.5/구간'],
  cold: ['안치한 시신을 내놓는다', '온실 식량 +1.5/구간'], tail3: ['꼬리칸 과밀 +15', '온실 식량 +1.5/구간'],
};

/** 복원 확인 본문 끝의 쓸모 줄(7.3). 변형이 있으면 갈래 카드가 변형마다 붙인다. */
function useText(g: Game, id: TechId): string {
  if (TECHS[id].variants) return '';
  const line = techUseLine(g, id);
  return line ? ` ${line}.` : '';
}

export function domView(g: Game, card: Card): CardView | null {
  if (!card.kind.startsWith('dom:') || !g.dom) return null;
  const d = g.dom;
  switch (card.kind) {
    case 'dom:fit': {
      const id = card.text as TechId;
      const def = TECHS[id];
      const ch = restoreCheck(g, id);
      const half = d.frags[def.branch] < ch.fragsNeed;
      const later = { label: '나중에', say: '아직은 아니다. 부품을 아껴라.', effs: [], special: 'dom:none' };
      const parts = (n: number) => [`부품 −${n}`, ...(ch.core ? [`코어 −${ch.core}`] : []), ...(ch.wood ? [`목재 −${ch.wood}`] : [])];
      return {
        title: '설계도가 맞았다', speaker: sp(chief(g, 'craft')), required: false,
        body: `${BRANCH_NAME[def.branch]}의 ${def.name}. ${half ? '조각이 반만 맞는다. 금 간 채로라도 돌릴 수는 있다.' : '조각이 다 맞았다.'} ${def.effect}.${useText(g, id)}`,
        choices: [
          { label: '완성판 복원', say: '옛 세상의 손이 아직 살아 있다. 당장 맞춰라!', effs: def.variants ? [] : sidesEffs(id), special: 'dom:restore:full', disabled: ch.full, extra: parts(ch.parts) },
          ...(ch.defectNeed < ch.fragsNeed ? [{ label: '결함판으로', say: '반쪽이라도 오늘 돌린다!', effs: def.variants ? [] : sidesEffs(id), special: 'dom:restore:defect', disabled: ch.defect === '완성판으로 된다' ? '조각이 다 있다' : ch.defect, extra: [...parts(ch.parts), '효과 절반, 고장 +3%p'] }] : []),
          later,
        ],
      };
    }
    case 'dom:fork': {
      const id = card.text as TechId;
      const def = TECHS[id];
      const vs = def.variants!;
      return {
        title: '두 갈래', speaker: sp(chief(g, def.branch)), required: true,
        body: `${def.name}은(는) 두 갈래로만 맞출 수 있다. 한 번 고르면 이 길에선 못 바꾼다.`,
        choices: (['a', 'b'] as Variant[]).map(v => ({
          label: vs[v].label, say: vs[v].say, effs: sidesEffs(id, v), special: `dom:variant:${v}`, extra: [vs[v].effect, ...(techUseLine(g, id, v) ? [techUseLine(g, id, v)!] : [])],
        })),
      };
    }
    case 'dom:short': {
      const isBreak = card.text === 'break';
      const n = card.n ?? 0;
      const penalty = ['다음 3구간 석탄 +1', '정차 산출 −20%(3구간)', '꼬리칸 난방 −1'][n];
      return {
        title: '부품이 모자란다', speaker: sp(chief(g, 'craft')), required: true, key: 'dom:short',
        body: isBreak ? `${BREAK_LINES[n]}. 고칠 부품이 없다. 부품 ${Math.floor(d.parts)}개.` : `유지비를 못 낸 기계가 반쯤만 돈다(${(card.text ?? '').split(',').map(x => TECHS[x as TechId]?.name ?? x).join(', ')}).`,
        choices: [
          { label: '하나를 세운다', say: '그건 세워라. 그 부품으로 보일러부터 막는다!', effs: [], special: 'dom:short:stand', extra: ['기술 하나가 멈춘다'] },
          { label: '그냥 달린다', say: '삐걱대도 달린다!', effs: [], special: 'dom:short:go', extra: isBreak ? [penalty] : ['반쯤만 돈다'] },
          { label: '목표치 +3', say: '기계를 굶길 순 없다. 목표치를 올려라!', effs: [], special: 'dom:short:target', extra: ['부품 목표치 +3', ...(isBreak ? [penalty] : [])] },
        ],
      };
    }
    case 'dom:pupil': {
      const f = card.text as Field;
      const t = freeTeacher(g, f);
      const owner = fieldOwner(g, f);
      const other: Comm = owner === 'tail' ? 'medtech' : 'tail';
      const blocked = distributeBlocked(g, f);
      return {
        title: '견습생 후보', speaker: sp(t && t !== 'manual' ? t : chief(g, f)), required: false,
        body: `${FIELD_NAME[f]}을(를) 배울 사람 셋이 왔다. ${COMM_NAME[owner]} 아이, ${COMM_NAME[other]} 아이, 그리고 간부가 미는 아이.${f === 'engine' ? ` 기관실 화부 노출 ${Math.round(g.comms.engine.base[3])}.` : ''}`,
        choices: [
          { label: '길드에 맡긴다', say: '기술은 그 일을 해 온 손에 남긴다.', effs: [rel(owner, D.guildRel)], special: 'dom:pupil:guild', disabled: t ? undefined : '가르칠 사람이 없다' },
          { label: '다른 칸에 나눈다', say: '기술은 한 칸의 것이 아니다. 다른 칸 아이에게도 가르쳐라!', effs: [rel(owner, D.distributeRel)], special: 'dom:pupil:other', disabled: !t ? '가르칠 사람이 없다' : blocked },
          { label: '아직 아니다', say: '지금은 손이 모자라다. 다음에 보자.', effs: [], special: 'dom:none' },
        ],
      };
    }
    case 'dom:manual': {
      const f = card.text as Field;
      const { who, why } = manualWriter(g, f);
      return {
        title: '매뉴얼을 써 달라', speaker: sp(who), required: false,
        body: why ? `${who?.name ?? '그 사람'}이(가) 고개를 젓는다. ${why}.` : `${who?.name ?? '그 사람'}이(가) 종이 묶음을 본다. 3구간이 걸리고, 그동안 ${FIELD_NAME[f]} 기계가 덜 돈다.`,
        choices: [
          { label: '써 달라', say: '당신이 죽어도 열차는 달려야 하오.', effs: [], special: 'dom:manual:write', disabled: why, extra: f === 'engine' ? [`다 쓰면 기관실 관계 ${D.engineManualRel}`] : [] },
          { label: '그만둔다', say: '알겠다. 다음에 다시 묻겠다.', effs: [], special: 'dom:none' },
        ],
      };
    }
    case 'dom:demand': {
      const p = personById(g, card.who);
      const n = card.n ?? 0;
      const ask = ['더 좋은 침상', '가족 몫 식량', '위험한 일 면제'][n];
      const cost = n === 0 ? [{ t: 'lux', v: -1 } as Eff] : [];
      return {
        title: '대체 불가', speaker: sp(p), required: true,
        body: `${p?.name ?? '그 사람'} 말고는 ${FIELD_NAME[p?.field ?? 'engine']}을(를) 아는 사람이 없다. 그가 ${ask}을(를) 원한다.`,
        choices: [
          { label: '들어준다', say: '당신 없인 우리도 없소. 원하는 걸 주겠소.', effs: [...cost, rel(p?.comm ?? 'tail', D.demandRel), rel('tail', D.demandFair)], special: 'dom:demand:grant', extra: n === 1 ? ['식량 −0.5/구간(6구간)'] : n === 2 ? ['파견 못 감'] : [] },
          { label: '거절한다', say: '특별한 사람은 없다. 똑같이 먹고 똑같이 잔다!', effs: [], special: 'dom:demand:refuse', extra: ['그 분야 기술 ×0.8(3구간)'] },
          { label: '견습생을 붙인다', say: '그러니 더더욱 제자를 둬야겠소.', effs: [rel(p?.comm ?? 'tail', -3)], special: 'dom:demand:pupil', disabled: p && freeTeacher(g, p.field) ? undefined : '가르칠 틈이 없다' },
        ],
      };
    }
    case 'dom:car': {
      const coach = card.n === 1;
      return {
        title: '쓸 만한 칸', required: false,
        body: coach ? '측선에 낡은 객차 한 칸이 서 있다. 바퀴는 돈다.' : '측선에 닫힌 화차 한 칸이 서 있다. 바닥이 멀쩡하다.',
        choices: [
          coach
            ? { label: '거주칸으로 단다', say: '사람이 먼저다. 꼬리칸을 넓혀라!', effs: [], special: 'dom:car:coach', extra: [`꼬리칸 과밀 −${D.coachCrowd}`, '달리기 석탄 +0.4/구간'] }
            : { label: '창고로 단다', say: '쌓을 곳이 생겼다, 달아라!', effs: [], special: 'dom:car:store', extra: ['자재 상한 +40', '달리기 석탄 +0.4/구간'] },
          { label: '두고 간다', say: '끌 석탄이 없다. 두고 간다.', effs: [], special: 'dom:none' },
        ],
      };
    }
    case 'dom:give': {
      const cands = giveCandidates(g);
      const say: Record<string, string> = {
        front: '앞칸은 충분히 따뜻하게 지냈다. 이제 내놓아라!', store: '창고를 비운다. 쇳조각보다 먹을 것이다!',
        cold: '냉동칸을 비운다. 산 사람이 먼저다.', tail3: '꼬리칸 하나를 비운다. 자라면 그들이 먼저 먹는다.',
      };
      const effs: Record<string, Eff[]> = {
        front: [rel('front', -25), { t: 'grudge', c: 'front' }], store: [], cold: [], tail3: [rel('tail', -10)],
      };
      return {
        title: '칸을 내줄 곳', required: false,
        body: '온실 유리 지붕을 얹을 칸 하나가 필요하다. 그 칸에 살던 사람이나 물건은 밀려난다.',
        choices: [
          ...cands.map(car => ({
            label: GIVE_LABEL[car] ?? `${CAR_NAME[car]} 내준다`, say: say[car], effs: effs[car] ?? [], special: `dom:give:${car}`,
            disabled: jobCheck(g, 'convert', car).why, extra: [...(GIVE_EXTRA[car] ?? []), '자재 −20, 공방 작업 6'],
          })),
          { label: '아직 아니다', say: '아직은 어느 칸도 못 내준다.', effs: [], special: 'dom:none' },
        ],
      };
    }
    case 'dom:box':
      return {
        title: '빈 매뉴얼 상자', speaker: sp(chief(g, 'engine')), required: true,
        body: '기관 매뉴얼 상자가 비어 있다. 기관실 사람들은 아무것도 모른다고 한다.',
        choices: [
          { label: '기관실을 추궁한다', say: '누가 가져갔는지 오늘 안에 밝혀라!', effs: [rel('engine', -10)], special: 'dom:box:press' },
          { label: '묻어 둔다', say: '못 본 걸로 하겠다.', effs: [], special: 'dom:none' },
        ],
      };
    case 'dom:full':
      return {
        title: '창고가 넘친다', speaker: sp(chief(g, 'craft')), required: true,
        body: `창고칸에 쇳조각과 판자가 천장까지 찼다. ${Math.max(1, Math.round(card.n ?? 0))}만큼이 통로에 나와 있다. 정한 답이 뒤로도 규칙이 된다.`,
        choices: [
          { label: '부품으로 만든다', say: '쌓아 두지 말고 부품으로 만들어라!', effs: [], special: 'dom:full:parts', extra: ['부품 목표치 +3', '넘친 몫은 버림'] },
          { label: '내다 버린다', say: '무게만 늘린다. 내다 버려라.', effs: [], special: 'dom:full:dump', extra: ['넘친 몫은 버림'] },
          { label: '통로에 쌓는다', say: '통로에라도 쌓아라. 언젠가 쓴다.', effs: [], special: 'dom:full:aisle', extra: ['자재 상한 +20', `꼬리칸 과밀 +${D.fullCrowd}`] },
        ],
      };
    case 'dom:bed':
      return {
        title: '누가 침상에 눕나', speaker: sp(chief(g, 'med')), required: true,
        body: `의무칸 침상은 ${D.beds}개인데 눕힐 사람이 ${card.n ?? D.beds + 1}명이다. 정한 순서가 뒤로도 의무칸 규칙이 된다.`,
        choices: [
          { label: '일할 손 먼저', say: '내일 삽을 들 손부터 눕혀라!', effs: [rel('engine', D.bedWorkersRel), rel('guard', D.bedWorkersRel), rel('tail', -D.bedWorkersRel)], special: 'dom:bed:workers', extra: ['병자는 제 칸에서 앓는다'] },
          { label: '아픈 사람 먼저', say: '가장 아픈 사람이 먼저다.', effs: [rel('medtech', D.bedWorkersRel)], special: 'dom:bed:sick', extra: ['넘치면 부상 회복 40%'] },
          { label: '순번으로', say: '침상은 순번이다. 넘치는 사람은 제 칸이 돌봐라.', effs: [], special: 'dom:bed:rota', extra: ['넘치면 그 칸 과밀 +5'] },
        ],
      };
    case 'dom:officer': {
      const p = personById(g, card.who);
      return {
        title: '간부가 대신 정했다', speaker: sp(p), required: true,
        body: `열차장이 누워 있는 동안 ${p?.name ?? '공방장'}이(가) 맡긴 것보다 한 칸 더 정했다.`,
        choices: [
          { label: '그대로 맡긴다', say: '잘했다. 앞으로도 그렇게 해라.', effs: [], special: 'dom:officer:keep', extra: ['간부 야심 +1'] },
          { label: '되돌린다', say: '내가 누워 있어도 이 열차는 내 것이다!', effs: [{ t: 'trust', v: 2 }], special: 'dom:officer:revert', extra: ['그 간부 적의 +1'] },
        ],
      };
    }
    case 'dom:lice': {
      const c = needComm(card);
      return {
        title: '이가 돈다', focus: c, required: true,
        body: `${COMM_NAME[c]}에서 밤새 긁는 소리가 난다. 같이 덮는 담요, 돌려 입는 옷, 말릴 데 없는 빨래 탓이다. (${hygieneWhy(g, c)})`,
        choices: [
          { label: '옷을 삶는다', say: '옷이고 담요고 다 솥에 넣어라. 석탄이 아까워도 지금이다!', effs: [{ t: 'coal', v: -D.boilCoal }], special: 'dom:lice:boil' },
          { label: '침구를 태운다', say: '침구를 태워라. 오늘 밤은 추워도 참게.', effs: [], special: 'dom:lice:burn', extra: [`${COMM_NAME[c]} 온기 −${D.beddingWarm}(${D.beddingSegs}구간)`] },
          { label: '버틴다', say: '석탄을 아껴야 한다. 며칠만 버텨 다오.', effs: [], special: 'dom:lice:endure', extra: [`${D.endureSegs}구간 뒤 열병이 될 수 있다`] },
        ],
      };
    }
    case 'dom:typhus': {
      const c = needComm(card);
      return {
        title: '열병', focus: c, required: true,
        body: `${COMM_NAME[c]}에서 ${typhusNames(g, c, card.n ?? 4)} 열에 들떠 누웠다. 붐비고 담요를 같이 덮는 칸이다. 앓는 사람은 의약품을 먹는다. 붐비고 담요를 같이 덮는 칸은 어디든 열병이 날 수 있다.`,
        choices: [
          { label: '의무칸을 비운다', say: '의무칸을 비워라. 앓는 사람이 먼저다!', effs: [], special: 'dom:typhus:bay', extra: ['번지지 않는다', `약 받으면 ${pct(D.typhusRecover)} 회복`, '부상자 회복이 멈춘다'] },
          { label: '따로 눕힌다', say: '앓는 사람은 그 칸 끝에 따로 눕혀라. 담요도 그릇도 따로다.', effs: [], special: 'dom:typhus:apart', extra: [`번질 확률 ${pct(D.typhusSpread)} → ${pct(D.typhusSpreadApart)}`, `약 받으면 ${pct(D.typhusRecoverApart)} 회복`, '부상자 회복은 그대로'] },
        ],
      };
    }
    case 'dom:stoker':
      return {
        title: '삽을 쥘 사람', speaker: sp(chief(g, 'engine')), required: true,
        body: '기관실이 불을 껐다. 몰 사람은 있다. 화부 일을 맡을 칸이 있으면 열차가 간다.',
        choices: [
          { label: '꼬리칸에 맡긴다', say: '꼬리칸이 삽을 든다. 이 열차는 모두의 것이다!', effs: [rel('engine', D.stokerEngineRel)], special: 'dom:stoker:tail', extra: ['꼬리칸 노출 +5/구간', '석탄 +2/구간'] },
          { label: '경비대에 맡긴다', say: '경비대가 불을 지켜라!', effs: [rel('engine', D.stokerEngineRel)], special: 'dom:stoker:guard', extra: ['경비대 노출 +5/구간', '석탄 +2/구간'] },
          { label: '세워 둔다', say: '기관실과 이야기하겠다. 기다려라.', effs: [], special: 'dom:none' },
        ],
      };
    case 'dom:pressure': {
      const last = (g.dom?.pressureStage ?? 0) >= 1;
      return {
        title: last ? '마지막 압력 경고' : '압력 경고', speaker: sp(chief(g, 'engine')), required: true,
        body: last
          ? '이음매에서 김이 샌다. 바늘이 붉은 칸을 넘었다. 이번엔 기관실 누구도 웃지 않는다.'
          : '견습이 모는 보일러 바늘이 붉은 칸에서 떨린다. 김을 빼면 석탄이 더 든다.',
        choices: [
          { label: '김을 뺀다', say: '김을 빼라. 보일러보다 귀한 건 없다!', effs: [{ t: 'coal', v: -D.ventCoal }], special: 'dom:pressure:vent' },
          last
            ? { label: '그대로 간다', say: '멈추면 다 얼어 죽는다. 그대로 간다!', effs: [], special: 'dom:pressure:go', extra: ['보일러가 터진다(판 끝)'] }
            : { label: '그대로 간다', say: '바늘은 늘 떤다. 그대로 간다!', effs: [], special: 'dom:pressure:go', extra: ['다음 경고가 마지막이다'] },
        ],
      };
    }
    default:
      return null;
  }
}

/** 카드 고른 뒤의 일. effs(관계·자원)는 chooseCard가 이미 적용했다. */
export function domChoose(g: Game, card: Card, choice: Choice): void {
  const d = g.dom;
  if (!d || !choice.special?.startsWith('dom:')) return;
  d.h6.picks.push({ seg: g.seg, title: card.kind, label: choice.label });
  const [, what, arg] = choice.special.split(':');
  switch (what) {
    case 'restore': {
      const id = card.text as TechId;
      if (TECHS[id].variants) domCard(g, { kind: 'dom:fork', text: id, n: arg === 'defect' ? 1 : 0 });
      else startRestore(g, id, arg as 'full' | 'defect', undefined, true);
      break;
    }
    case 'variant':
      startRestore(g, card.text as TechId, card.n === 1 ? 'defect' : 'full', arg as Variant, true);
      break;
    case 'short':
      if (arg === 'stand') {
        standDown(g);
        if (card.text === 'break' && d.parts >= D.repairParts) { d.parts -= D.repairParts; d.stats.repairs += 1; }
        else if (card.text === 'break') breakPenalty(g, card.n ?? 0);
      } else if (arg === 'go') {
        if (card.text === 'break') breakPenalty(g, card.n ?? 0);
      } else {
        setTarget(g, d.target + 3);
        if (card.text === 'break') breakPenalty(g, card.n ?? 0);
      }
      break;
    case 'pupil':
      attachApprentice(g, card.text as Field, arg as 'guild' | 'other', true);
      break;
    case 'manual':
      startManual(g, card.text as Field);
      break;
    case 'demand': {
      const p = personById(g, card.who);
      if (!p) break;
      if (arg === 'grant') {
        if (card.n === 1) d.grants.push(g.seg + D.grantSegs);
        if (card.n === 2) p.exempt = true;
      } else if (arg === 'refuse') {
        d.sabotage[p.field] = g.seg + D.sabotageSegs - 1;
        if (g.comms[p.comm].rel <= -15) p.leaveRisk = true;
      } else {
        attachApprentice(g, p.field, 'guild', true);
      }
      break;
    }
    case 'car':
      attachCar(g, arg as 'store' | 'coach');
      break;
    case 'give':
      giveCar(g, arg);
      break;
    case 'box':
      if (rnd(g) < 0.5) {
        d.manuals.engine = true;
        journal(g, '견습 화부의 침낭 밑에서 매뉴얼이 나왔다. 기관실이 이를 갈았다.', 'dark');
      } else {
        journal(g, '아무것도 나오지 않았다. 기관실 사람들이 열차장을 노려본다.', 'bad');
      }
      break;
    case 'full':
      setFullRule(g, arg as 'parts' | 'dump' | 'aisle');
      break;
    case 'bed':
      setBedOrder(g, arg as 'workers' | 'sick' | 'rota');
      break;
    case 'officer':
      if (arg === 'revert') {
        const p = personById(g, card.who);
        if (p) g.comms[p.comm].grudge = clamp(g.comms[p.comm].grudge + 1, 0, 3);
      }
      break;
    case 'lice':
      resolveLice(g, needComm(card), arg as 'boil' | 'burn' | 'endure');
      break;
    case 'typhus':
      resolveTyphus(g, needComm(card), arg as 'bay' | 'apart');
      break;
    case 'stoker':
      d.stoker = arg as Comm;
      break;
    case 'pressure':
      if (resolvePressure(g, arg === 'vent')) { g.end = 'stranded'; g.phase = 'end'; }
      break;
    default:
      break;
  }
}

let registered = false;
/** 서류 뭉치에 내정 카드를 잇는다. game/index.ts가 한 번 부른다. */
export function registerDomesticCards(): void {
  if (registered) return;
  registered = true;
  CARD_EXTENSIONS.push({ view: domView, choose: domChoose });
}
registerDomesticCards();

export const DOM_CARD_KINDS = [
  'dom:fit', 'dom:fork', 'dom:short', 'dom:pupil', 'dom:manual', 'dom:demand', 'dom:car', 'dom:give', 'dom:box', 'dom:full', 'dom:bed', 'dom:officer',
  'dom:lice', 'dom:typhus', 'dom:stoker', 'dom:pressure',
] as const;
