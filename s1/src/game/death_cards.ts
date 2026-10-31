import { COMM_NAME, COMMS, CONDITIONS, P, REP_ROLE } from './data';
import type { Comm, LawId } from './data';
import { CARD_EXTENSIONS, withAfford } from './cards';
import type { CardView, Choice, Eff } from './cards';
import { revertLater } from './people';
import { journal } from './state';
import type { Card, DeathSlot, Game } from './state';
import { chainOf, DEATH_CARD_KINDS, dropChain, hands, skilledHand } from './death_weight';

// 죽음의 무게 카드(death_weight.ts가 올린다). 선택지는 지금 확실한 비용과 고르는 즉시 생기는 정치 변화만 보인다(결정 364).

// ---- 카드 ----
function leaderOf(g: Game, c: Comm): { name: string; role: string; comm: Comm } {
  return { name: g.comms[c].leader.name, role: REP_ROLE[c], comm: c };
}

/** 「손을 보내 배웅한다」가 서 있으면 죽은 이의 칸 관계 벌이 없다(결정 367 3). */
function spare(g: Game, c: Comm, effs: Eff[]): Eff[] {
  return hands(g) ? effs.filter(e => !((e.t === 'rel' && e.c === c && e.v < 0) || (e.t === 'grudge' && e.c === c))) : effs;
}

/** 사람을 옮겨 올 칸: 그 칸 말고 가장 사람이 많은 칸. */
function donorOf(g: Game, c: Comm): Comm {
  return [...COMMS].filter(x => x !== c).sort((a, b) => g.comms[b].pop - g.comms[a].pop)[0];
}

/** 대표가 약속으로 걸 조건(그 칸이 거래창에서 내거는 조건 가운데 지금 바로 치르지 않는 첫 것). */
function repCondition(c: Comm) {
  return CONDITIONS[c].find(x => !x.now && !x.s1c && x.kind !== 'target' && x.kind !== 'skip_dispatch') ?? CONDITIONS[c].find(x => !x.now && !x.s1c);
}

const PUSH_COST: Record<DeathSlot, Eff[]> = {
  rep: [{ t: 'lux', v: -1 }], parent: [{ t: 'food', v: -3 }], child: [{ t: 'coal', v: -2 }], hand: [{ t: 'food', v: -2 }], heat: [{ t: 'coal', v: -3 }],
};

const PUSH_BODY: Record<DeathSlot, string> = {
  rep: '새 대표가 아직 자리를 잡지 못했다. 칸 사람들이 지난번 대답을 다시 묻는다.',
  parent: '남은 아이를 맡은 집이 지쳤다. 칸이 손을 더 보태 달라고 다시 말한다.',
  child: '빈 잠자리 곁의 아이들이 밤마다 깬다. 칸이 그 일을 다시 꺼냈다.',
  hand: '빈 손을 나눠 진 사람들이 지쳤다. 칸이 그 일을 다시 꺼냈다.',
  heat: '난로가 식었던 밤 이야기가 칸마다 돈다. 칸이 그 일을 다시 꺼냈다.',
};

function lossView(g: Game, card: Card): CardView | null {
  const c = card.comm ?? 'tail';
  const who = card.who ?? '';
  switch (card.kind) {
    case 'loss_rep': {
      const s = g.comms[c];
      const cond = repCondition(c);
      const busy = !!s.promise;
      return {
        title: '빈 의석', speaker: leaderOf(g, c), focus: c, required: true,
        body: `${who}의 자리를 ${s.leader.name}이(가) 이었다. 첫 회기 전에 열차장에게 약속 하나를 받아 두겠다고 한다.`,
        choices: withAfford(g, [
          { label: '약속한다', log: '새 대표에게 칸 몫을 챙기겠다고 약속했다.', say: '좋다. 약속하마. 그 칸 몫은 내가 챙긴다.', effs: [{ t: 'rel', c, v: 3 }], special: 'dw_promise',
            extra: cond ? [`약속: ${cond.label}`] : [], ...(busy || !cond ? { disabled: '이미 걸린 약속이 있다' } : {}) },
          { label: '거절한다', log: '새 대표의 약속 요구를 거절했다.', say: '자리를 이었으면 먼저 일로 보여라.', effs: spare(g, c, [{ t: 'rel', c, v: -5 }, { t: 'grudge', c }]), special: 'dw_refuse' },
        ]),
      };
    }
    case 'loss_child': {
      return {
        title: '빈 잠자리', speaker: leaderOf(g, c), focus: c, required: true,
        body: `${who}의 잠자리가 비었다. ${COMM_NAME[c]}이(가) 남은 아이들 잠자리를 난로 곁으로 옮겨 달라고 한다.`,
        choices: withAfford(g, [
          { label: '들어준다', log: '남은 아이들 잠자리를 난로 곁에 두게 했다.', say: '아이들 자리를 난로 곁으로 옮겨라. 석탄은 내가 낸다.', effs: [{ t: 'coal', v: -3 }, { t: 'base', c, i: 0, v: 3 }] },
          { label: '지금은 안 된다', log: '남은 아이들 잠자리는 그대로 두기로 했다.', say: '지금은 석탄을 뺄 수 없다. 다음 역까지 버텨라.', effs: spare(g, c, [{ t: 'rel', c, v: -4 }, { t: 'tension', v: 2 }]), special: 'dw_refuse' },
        ]),
      };
    }
    case 'loss_hand': {
      const skilled = skilledHand(g, who);
      const from = donorOf(g, c);
      const short = skilled ? 2 : 1;
      return {
        title: '빈 손', speaker: leaderOf(g, c), focus: c, required: true,
        body: `${who}이(가) 하던 일이 비었다.${skilled ? ' 손이 익은 사람이었다.' : ''} ${COMM_NAME[c]}이(가) 사람을 하나 보내 달라고 한다.`,
        choices: withAfford(g, [
          { label: `${COMM_NAME[from]}에서 한 사람 옮긴다`, log: `${COMM_NAME[from]}에서 ${COMM_NAME[c]}에 일손 하나를 보냈다.`, say: `${COMM_NAME[from]}에서 한 사람 보내라. 일은 멈추면 안 된다.`,
            effs: [{ t: 'pop', c: from, v: -1 }, { t: 'pop', c, v: 1 }, { t: 'rel', c: from, v: -3 }, { t: 'rel', c, v: 2 }] },
          { label: '그 칸이 나눠 진다', log: `${who}이(가) 하던 일을 그 칸이 나눠 지게 했다.`, say: '남은 사람끼리 나눠 져라. 지금은 보낼 손이 없다.', effs: [], special: 'dw_share',
            extra: [`다음 정차 작업조 −${short}`] },
        ]),
      };
    }
    case 'heat_after': {
      const n = card.n ?? 1;
      return {
        title: '식은 난로', speaker: leaderOf(g, c), focus: c, required: true,
        body: `지난밤 난로가 식었다. ${n}명이 아침을 맞지 못했다. 남은 사람들이 「난방 배당」을 거둘 안건을 다음 회기 첫 자리에 올려 달라고 한다.`,
        choices: withAfford(g, [
          { label: '올린다', log: '난방 배당 폐지를 다음 회기에 올리기로 했다.', say: '다음 회기 첫 안건으로 올리겠다.', effs: [{ t: 'rel', c, v: 3 }], special: 'dw_heat_agenda', extra: ['다음 회기: 난방 배당 폐지 안건'] },
          { label: '그 칸에 석탄을 따로 준다', log: '법은 두고 식은 칸 난로에 석탄을 더 넣게 했다.', say: '법은 두고, 그 칸 난로에 석탄을 더 넣어라.', effs: [{ t: 'coal', v: -4 }, { t: 'base', c, i: 0, v: 5 }], special: 'dw_heat_coal', extra: ['두 구간 동안'] },
          { label: '이번엔 안 된다', log: '난로가 식은 칸에도 난방 배당을 그대로 뒀다.', say: '법은 그대로 간다. 모두가 춥다.', effs: spare(g, c, [{ t: 'rel', c, v: -4 }, { t: 'tension', v: 3 }]), special: 'dw_refuse' },
        ]),
      };
    }
    case 'chain_push': {
      const slot = (card.text ?? 'hand') as DeathSlot;
      return {
        title: '다시 오른 요구', speaker: leaderOf(g, c), focus: c, required: true,
        body: PUSH_BODY[slot],
        choices: withAfford(g, [
          { label: '들어준다', log: '죽음 뒤 다시 오른 요구를 들어줬다.', say: '알았다. 이번엔 들어주겠다.', effs: [...PUSH_COST[slot], { t: 'rel', c, v: 3 }] },
          { label: '물리친다', log: '죽음 뒤 다시 오른 요구를 물리쳤다.', say: '이미 대답했다. 같은 말을 두 번 하지 않는다.', effs: spare(g, c, [{ t: 'rel', c, v: -5 }]), special: 'dw_push_refuse', extra: ['다음 회기 그 칸 한 석이 반대로'] },
        ]),
      };
    }
    case 'chain_fix': {
      const slot = (card.text ?? 'hand') as DeathSlot;
      return { title: '고칠 길', speaker: leaderOf(g, c), focus: c, required: true, body: FIX_BODY[slot], choices: withAfford(g, fixChoices(g, c, slot)) };
    }
    default:
      return null;
  }
}

const FIX_BODY: Record<DeathSlot, string> = {
  rep: '새 대표가 칸 사람들 앞에서 묻는다. 다음 회기 안건을 이 칸이 고르게 해 줄 수 있느냐고.',
  parent: '남은 아이를 맡은 칸이 배급을 조금 더 달라고 한다. 그러면 이 일을 덮겠다고 한다.',
  child: '아이들 잠자리 곁 난로를 두 구간만 더 키워 달라고 한다. 그러면 칸이 잠잠해진다.',
  hand: '빈 손을 메울 길이 하나 있다. 사람을 하나 더 먹여 일을 가르치는 것이다.',
  heat: '칸이 마지막으로 묻는다. 「난방 배당」 폐지를 회기에 올려 주겠느냐고.',
};

function fixChoices(g: Game, c: Comm, slot: DeathSlot): Choice[] {
  const close = (effs: Eff[], extra: string[], log: string): Choice => ({ label: '값을 치르고 닫는다', log, say: '이 일은 여기서 매듭짓자.', effs: [...effs, { t: 'rel', c, v: 4 }], special: `dw_fix_${slot}`, extra });
  const open: Choice = { label: '닫지 않는다', log: '죽음 뒤 남은 요구를 받아들이지 않았다.', say: '지금은 그럴 수 없다.', effs: [{ t: 'grudge', c }], special: 'dw_fix_none' };
  switch (slot) {
    case 'child': return [close([{ t: 'coal', v: -4 }, { t: 'base', c, i: 0, v: 5 }], ['두 구간 동안'], '아이들 잠자리 곁 난로에 석탄을 더 줬다.'), open];
    case 'parent': {
      const to = raisedComm(g, c);
      return [close([{ t: 'food', v: -5 }, { t: 'base', c: to, i: 1, v: 3 }], [], '남은 아이를 맡은 칸에 배급을 더 줬다.'), open];
    }
    case 'hand': return [close([{ t: 'food', v: -3 }], ['다음 정차 작업조 +1'], '빈 손을 메울 사람을 하나 더 먹여 가르치기로 했다.'), open];
    case 'rep': return [close([{ t: 'lux', v: -2 }], ['다음 회기 안건을 이 칸이 고른다'], '다음 회기 안건을 이 칸이 고르게 했다.'), open];
    case 'heat': return [close([], ['다음 회기: 난방 배당 폐지 안건'], '난방 배당 폐지를 회기에 올리기로 했다.'), open];
  }
}

/** 남은 아이를 맡은 칸(남은 아이 카드에서 정한 곳). 없으면 그 칸. */
function raisedComm(g: Game, c: Comm): Comm {
  const r = Object.values(g.raised ?? {}).at(-1) as Comm | undefined;
  return r ?? c;
}

function pushRepeal(g: Game, law: LawId): void {
  g.proposals = [{ law, repeal: true, promise: true }, ...g.proposals.filter(p => !('law' in p && p.law === law))];
}

function lossChoose(g: Game, card: Card, choice: Choice): void {
  if (!g.deathWeight || (!(DEATH_CARD_KINDS as readonly string[]).includes(card.kind) && card.kind !== 'orphan')) return;
  const c = card.comm ?? 'tail';
  const ch = chainOf(g, c);
  if (choice.special === 'dw_refuse' || choice.special === 'dw_share') { if (ch && ch.step === 0) ch.refused = true; }
  switch (choice.special) {
    case 'dw_promise': {
      const s = g.comms[c];
      const cond = repCondition(c);
      if (!cond || s.promise) break;
      const baseline = cond.kind === 'heat' ? s.heat : cond.kind === 'ration' || cond.kind === 'keep_ration' ? s.ration : undefined;
      s.promise = { kind: 'open', cond, label: cond.label, due: g.seg + P.promiseSegments, madeSession: g.session, ...(baseline === undefined ? {} : { baseline }) };
      journal(g, `${COMM_NAME[c]} 새 대표와 약속했다: ${cond.label}.`, 'deal');
      break;
    }
    case 'dw_share': g.crewShort = (g.crewShort ?? 0) + (skilledHand(g, card.who ?? '') ? 2 : 1); break;
    case 'dw_heat_agenda': pushRepeal(g, 'heat_quota'); break;
    case 'dw_heat_coal': revertLater(g, c, 0, 5, 2); break;
    case 'dw_push_refuse': {
      const v = (g.voteShift ??= []).find(x => x.comm === c && x.side === 'captain');
      if (v) v.n -= 1; else g.voteShift.push({ comm: c, n: -1, side: 'captain' });
      break;
    }
    case 'dw_fix_child': revertLater(g, c, 0, 5, 2); break;
    case 'dw_fix_hand': g.crewShort = (g.crewShort ?? 0) - 1; break;
    case 'dw_fix_rep': g.agendaHolder = c; break;
    case 'dw_fix_heat': pushRepeal(g, 'heat_quota'); break;
    default: break;
  }
  if (card.kind === 'chain_fix' && ch) dropChain(g, ch, choice.special === 'dw_fix_none' ? 'unfixed' : 'fixed');
}

CARD_EXTENSIONS.push({ view: lossView, choose: lossChoose });
