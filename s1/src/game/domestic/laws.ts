import { S1C_LAWS } from '../data';
import type { LawId } from '../data';
import { lawActive } from '../state';
import type { Game } from '../state';
import { techUsable } from './state';

// S1c 법 다섯이 열리는 때(s1a_politics_numbers 8.5, 숫자는 제안). 19와 20, 21가와 21나는 같은 문제의 두 답이라
// 하나를 통과시키면 다른 하나는 닫힌다. 12b는 환자 분류 기준(M2)을 복원한 판에서 12 대신 오른다.
// 돌려주는 값이 null이면 S1a 규칙(politics.ts lawOpen)을 그대로 쓴다.

function triageCrisis(g: Game): boolean {
  return g.med <= 5 || g.injured >= 6;
}

export function domesticLawOpen(g: Game, law: LawId): boolean | null {
  const d = g.dom;
  if (S1C_LAWS.includes(law) && !d) return false;
  if (!d) return null;
  switch (law) {
    case 'tech_control': return d.flags.otherApprentice && !lawActive(g, 'apprentice_duty');
    case 'apprentice_duty': return d.flags.irreplaceable && !lawActive(g, 'tech_control');
    case 'triage_std': return techUsable(g, 'm2') && !lawActive(g, 'triage') && triageCrisis(g);
    case 'triage': return techUsable(g, 'm2') || lawActive(g, 'triage_std') ? false : null;
    case 'bath_rota': return d.flags.lice && !lawActive(g, 'hands_first');
    case 'hands_first': return d.flags.lice && !lawActive(g, 'bath_rota');
    default: return null;
  }
}
