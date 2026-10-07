import { COMM_NAME, COMMS, CORPSE_LAWS, LAWS } from '../data';
import type { LawId } from '../data';
import { CARD_EXTENSIONS, VIEW_FILTERS } from '../cards';
import type { Choice } from '../cards';
import { needLaws, NEEDS } from '../needs';
import type { NeedId } from '../needs';
import { canDecree, DECREE_REL, enactLaw, lawOpen, stance } from '../politics';
import { clamp, journal, lawActive } from '../state';
import type { Game } from '../state';

// 제안 (7) '포고로 정한다'(s1b_dark_path 5.3 끝, S1a R3 대조 7번). 사용자 답 전이라 S1b 판에서만 켜고, 이 파일 하나를 빼면 사라진다.
// 비상대권 3구간 동안 요구·파업·법 요구 카드에 선택지 하나가 붙는다. 그 구간 포고 자리를 쓰고(castVote 포고와 같은 자리),
// 대권을 쥐는 값(포고마다 긴장 +5, 942df98)을 똑같이 치른다. 숫자는 제안이다.

const KINDS = ['demand', 'strike', 'need_warn'];
/** need_warn에 붙는 법 포고는 많아야 이만큼(카드가 길어지지 않게) */
const LAW_CHOICES = 2;

function decreeLaws(g: Game, id: NeedId): LawId[] {
  const corpseSet = CORPSE_LAWS.some(l => lawActive(g, l));
  return needLaws(id).filter(l => !lawActive(g, l) && lawOpen(g, l) && !(corpseSet && CORPSE_LAWS.includes(l))).slice(0, LAW_CHOICES);
}

function choices(g: Game, kind: string, c: string, text?: string): Choice[] {
  if (kind === 'need_warn') {
    if (!NEEDS[text as NeedId]) return [];
    return decreeLaws(g, text as NeedId).map(law => ({
      label: `포고: ${LAWS[law].title}`, say: `${LAWS[law].title}, 오늘부터다. 의회는 나중에 추인한다.`, effs: [{ t: 'tension', v: 5 }],
      special: `dark:decree:law:${law}`, extra: ['이번 구간 포고 자리를 쓴다', '대권이 끝나면 추인 안건'],
    }));
  }
  if (kind === 'strike') {
    return [{
      label: '포고로 불을 올린다', say: '비상대권으로 명한다. 불을 올려라. 지금.', effs: [{ t: 'tension', v: 5 }, { t: 'fear', v: 5 }, { t: 'rel', c: 'engine', v: -5 }],
      special: 'dark:decree:strike', extra: ['이번 구간 포고 자리를 쓴다', '파업이 끝난다'],
    }];
  }
  if (kind === 'demand' && COMMS.includes(c as never)) {
    return [{
      label: '포고로 정한다', say: '비상대권으로 정한다. 지금은 올릴 수 없다. 더 묻지 마라.', effs: [{ t: 'tension', v: 5 }, { t: 'fear', v: 3 }, { t: 'rel', c: c as never, v: -3 }],
      special: 'dark:decree:refuse', extra: ['이번 구간 포고 자리를 쓴다', '거절해도 열기가 오르지 않는다'],
    }];
  }
  return [];
}

VIEW_FILTERS.push((g, card, v) => {
  if (!g.dark || !canDecree(g) || !KINDS.includes(card.kind)) return v;
  const add = choices(g, card.kind, card.comm ?? 'tail', card.text);
  return add.length ? { ...v, choices: [...v.choices, ...add] } : v;
});

CARD_EXTENSIONS.push({
  view: () => null,
  choose: (g, card, ch) => {
    const sp = ch.special ?? '';
    if (!g.dark || !sp.startsWith('dark:decree:')) return;
    g.decreeSeg = g.seg;
    if (sp.startsWith('dark:decree:law:')) {
      const law = sp.slice('dark:decree:law:'.length) as LawId;
      // castVote의 포고와 같은 장부: 대권이 끝나면 추인 안건이 되고, 싫어하는 칸과 관계 −3.
      (g.decreed ??= []).push(law);
      for (const c of COMMS) if (stance(g, c, { law, repeal: false }, false).score <= -3) g.comms[c].rel = clamp(g.comms[c].rel - DECREE_REL, -100, 100);
      enactLaw(g, law, []);
      journal(g, `비상대권으로 ${LAWS[law].title}을(를) 포고했다.`, 'dark');
      return;
    }
    if (sp === 'dark:decree:strike') {
      g.comms.engine.fervor = 0;
      journal(g, '비상대권으로 기관실에 불을 올리라고 명했다. 화부들이 말없이 삽을 들었다.', 'dark');
      return;
    }
    journal(g, `비상대권으로 ${COMM_NAME[card.comm ?? 'tail']}의 요구를 물렸다.`, 'dark');
  },
});
