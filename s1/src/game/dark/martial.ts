import { COMMS } from '../data';
import type { Comm } from '../data';
import { endEmergencyPowers, offend } from '../politics';
import { clamp, END_LINK, journal, lawActive, stageOf } from '../state';
import type { Game } from '../state';
import { B } from './data';
import type { MeansKey } from './data';
import { cross, scene } from './chronicle';
import { darkCard } from './state';
import type { MartialDoor } from './state';

// 5.3 계엄(둘째 묶음 PR A, s1b_martial_impl.md 2~3장). 계엄은 법이 아니라 상태다(d.martial). 들어서는 문은 다섯(5.5 표)이고
// 이 파일의 enterMartial 하나로 모인다. 문 2·3·4(의회가 맡김, 내전 직전·내전, 경비대장)를 부르는 쪽은 PR B다.
// g.dark가 없으면 모든 함수가 아무 일도 안 한다.

export const isMartial = (g: Game): boolean => !!g.dark?.martial;

/** 대권 연장(문 1)이 잠기는 이유. 열리면 null. 경비대 호의 이상이고 경비대 적의 0이어야 한다(5.3). */
export function canExtend(g: Game): string | null {
  const guard = g.comms.guard;
  if (stageOf(guard.rel).index <= 2 && guard.grudge === 0) return null;
  return '경비대장이 고개를 젓는다.';
}

/** 계엄을 거둘 수 있나. 계엄 회기의 의회 화면에서만 단추가 있다. 열리면 null. */
export function canLift(g: Game): string | null {
  if (!g.dark?.martial) return '계엄 중이 아니다';
  if (g.phase !== 'council' || !g.council?.martial) return '계엄 회기에만 거둘 수 있다';
  return null;
}

/** 문마다 수단 점수 키(5.5 표). 경비대장의 계엄은 열차장이 고른 일이 아니라 점수가 없다. */
const DOOR_MEANS: Partial<Record<MartialDoor, MeansKey>> = { extend: 'martial', council: 'martial_council', brink: 'martial_brink', sided: 'martial_sided' };
/** 일대기 문장(5.5 표 '일대기' 열). 자리표시이고 Gemini가 같은 결로 쓴다. */
const DOOR_SCENE: Record<MartialDoor, string> = {
  extend: '권력을 놓지 않았다. 대권을 계엄으로 이었다',
  council: '의회가 열차를 그에게 맡겼다',
  brink: '내전을 막으려 계엄을 선포했다',
  sided: '경비대 편에 서서 계엄을 선포했다',
  captain: '열차장이 손 놓은 사이 경비대장이 열차를 잡았다',
};

/** 계엄이 들어선다. opts는 내전 직전·내전 문에서 쓴다: a·b는 맞선 두 집단, against는 편든 계엄에서 누른 쪽. */
export function enterMartial(g: Game, door: MartialDoor, opts: { against?: Comm; a?: Comm; b?: Comm } = {}): void {
  const d = g.dark;
  if (!d || d.martial) return;
  const guard = g.comms.guard;
  // 비상대권이 걸려 있으면 내린다: 계엄은 법이 아니라 상태다. 포고 목록은 계엄 기록으로 옮기고 g.ratify에는 넣지 않는다
  // (endEmergencyPowers와 달리 계엄이 끝날 때 한 묶음으로 추인한다).
  const decreed = (g.decreed ?? []).filter(l => lawActive(g, l));
  const repealed = (g.decreedRepeals ?? []).filter(l => !lawActive(g, l));
  g.decreed = [];
  g.decreedRepeals = [];
  if (lawActive(g, 'emergency_powers')) {
    delete g.passed.emergency_powers;
    g.repealedAt.emergency_powers = g.session;
  }
  g.decreeLeft = 0;
  delete d.powersPlan;
  d.extendAsk = false;
  // 신임 위기로 축출되지 않는다(5.3): 걸린 위기와 카드를 지운다. 대권 끝 카드도 더는 필요 없다.
  g.trustCrisis = null;
  g.cards = g.cards.filter(c => c.kind !== 'trust_crisis' && c.kind !== 'dark:powers_end');

  // 경비대 배급 레버 +1(상한 안에서). 계엄 동안 이 값 아래로 못 내린다.
  guard.ration = Math.min(4, guard.ration + 1);
  d.martial = {
    door, since: g.seg, trustBefore: g.trust, decreed, repealed, coupWarnAt: null, warned: false, rationLocked: guard.ration,
    ...(opts.against ? { against: opts.against } : {}),
  };
  d.martialDoors.push(door);

  switch (door) {
    case 'extend':
      for (const c of COMMS) if (c !== 'guard') offend(g, c);
      g.tension = clamp(g.tension + B.mlEnterTension, 0, 100);
      break;
    case 'council':
      g.tension = clamp(g.tension + B.mlCouncilTension, 0, 100);
      break;
    default: {
      // brink·captain: 맞선 두 집단 적의 +1, 끼지 않은 칸 관계 +5(질서를 바랐다). sided: 누른 쪽 적의 +2, 끼지 않은 칸 관계 −3(제 원수를 누르는 걸 봤다).
      const involved = new Set<Comm>([opts.a, opts.b, opts.against].filter((c): c is Comm => !!c));
      if (door === 'sided') {
        if (opts.against) { offend(g, opts.against); offend(g, opts.against); }
      } else {
        for (const c of [opts.a, opts.b]) if (c) offend(g, c);
      }
      for (const c of COMMS) {
        if (involved.has(c)) continue;
        const dRel = door === 'sided' ? -B.mlSidedRel : B.mlBrinkRel;
        g.comms[c].rel = clamp(g.comms[c].rel + dRel, -100, 100);
      }
      g.tension = clamp(g.tension + B.mlBrinkTension, 0, 100);
      if (door === 'captain') g.trust = clamp(g.trust - B.mlCaptainTrust, 0, 100);
    }
  }

  const key = DOOR_MEANS[door];
  if (key) cross(g, key);
  const place = g.stop?.place;
  scene(g, 'martial', 4, `${g.seg}구간${place ? `, ${place}에서` : ','} ${DOOR_SCENE[door]}.`, [guard.leader.personId]);
  journal(g, `${g.seg}구간${place ? `, ${place}` : ''}: 계엄을 선포했다. 의회 탁자의 투표함 뚜껑이 닫힌다.`, 'dark');
}

/** 스스로 계엄을 거둔다(5.3). 신임은 계엄 직전 값 −15로 돌아오고, 포고 추인 안건이 다음 정기 회기에 오른다(council.ts). */
export function liftMartial(g: Game, _why: 'self' = 'self'): void {
  const d = g.dark;
  const m = d?.martial;
  if (!d || !m) return;
  g.trust = clamp(m.trustBefore - B.mlLiftTrust, 0, 100);
  // 앞선 계엄의 포고 추인이 아직 안 열렸으면 한 묶음으로 잇는다.
  const prev = d.martialLifted;
  d.martialLifted = { seg: g.seg, bonus: !m.warned, decreed: [...(prev?.decreed ?? []), ...m.decreed], repealed: [...(prev?.repealed ?? []), ...m.repealed] };
  d.martial = null;
  d.stats.lifted += 1;
  cross(g, 'martial_lifted');
  journal(g, '투표함 뚜껑이 다시 열렸다.', 'dark');
  // 계엄 회기에서 눌렀으면 그 회기는 바로 닫힌다(의회는 다음 정기 회기부터). 정기 신임 간격(confSince)은 건드리지 않는다.
  if (g.phase === 'council' && g.council?.martial) g.council.options = [];
}

/** 정산마다(hooks.darkSettle, meters 앞). 유지비와 쿠데타 판정(5.3). 판이 이미 끝났으면 아무 일도 안 한다. */
export function martialSettle(g: Game): void {
  const d = g.dark;
  const m = d?.martial;
  if (!d || !m || g.phase === 'end') return;
  d.stats.martialSegs += 1;
  g.comms.guard.base[3] += B.mlExpo;
  g.tension = clamp(g.tension + B.mlTension, 0, 100);
  g.fear = clamp(g.fear + B.mlFear, 0, 100);
  // 문턱: 경비대 관계 단계가 회의 이하(band -1). 경비대장의 계엄이면 한 단계 높아 중립 이하(band 0).
  const line = m.door === 'captain' ? 0 : -1;
  if (stageOf(g.comms.guard.rel).band > line) {
    m.coupWarnAt = null;
    return;
  }
  if (m.coupWarnAt === null) {
    m.coupWarnAt = g.seg + B.mlCoupSegs;
    m.warned = true;
    darkCard(g, { kind: 'dark:coup_warn' });
    journal(g, `경비대의 충성이 무너지고 있다. ${B.mlCoupSegs}구간 안에 되돌리지 못하면 열차를 잃는다.`, 'bad');
    return;
  }
  if (g.seg >= m.coupWarnAt) {
    scene(g, 'coup', 4, `${g.seg}구간, 경비대장이 열차를 잡았다.`, [g.comms.guard.leader.personId]);
    END_LINK.finish(g, 'coup');
  }
}

/** 대권이 끝나는 구간(turn.ts nextSegment): 대권이 끝나는 카드에서 고른 길을 따른다. 길을 처리했으면 true(turn.ts가 endEmergencyPowers를 또 부르지 않는다).
 * S1a 판(g.dark 없음)이면 false라서 지금 그대로다. 카드를 안 고른 채 넘어가면 '돌려준다'다. */
export function darkPowersEnd(g: Game): boolean {
  const d = g.dark;
  if (!d) return false;
  let plan = d.powersPlan ?? 'return';
  delete d.powersPlan;
  if (plan === 'extend') {
    // 카드를 보인 뒤 경비대가 돌아섰을 수 있다. 그러면 연장은 안 되고 돌려준다.
    const why = canExtend(g);
    if (why) {
      journal(g, why, 'bad');
      plan = 'return';
    } else {
      enterMartial(g, 'extend');
      return true;
    }
  }
  endEmergencyPowers(g);
  if (plan === 'ask') {
    d.extendAsk = true;
  } else {
    g.trust = clamp(g.trust + B.powersReturnTrust, 0, 100);
  }
  return true;
}
