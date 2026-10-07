import { S1C_LAWS } from '../data';
import type { LawId } from '../data';
import { lawActive } from '../state';
import type { Game } from '../state';
import { techMult, techUsable, variantMult } from './state';

// S1c 법 다섯이 열리는 때(s1a_politics_numbers 8.5, 숫자는 제안). 19와 20, 21가와 21나는 같은 문제의 두 답이라
// 하나를 통과시키면 다른 하나는 닫힌다. 12b는 환자 분류 기준(M2)을 복원한 판에서 12 대신 오른다.
// 종자곡 반만 풀기(M3 가)와 아동 노동 짐 꾸리기만(X1)은 원래 법과 나란히 열리고 하나만 설 수 있다(7.3 '골라 올린다').
// 원래 법이 이미 서 있으면 변형은 개정 표결로 오른다(통과하면 원래 법을 내리고 변형을 세운다).
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
    // 원래 법이 서 있으면 변형은 개정 안건으로 오른다(politics.ts agendaOptions의 amend).
    case 'triage_std': return techUsable(g, 'm2') && (lawActive(g, 'triage') || triageCrisis(g));
    case 'triage': return techUsable(g, 'm2') || lawActive(g, 'triage_std') ? false : null;
    // 7.3 변형: 기술이 서면 원래 법과 변형 중 하나를 골라 올린다. 하나가 서면 다른 하나는 닫힌다.
    case 'seed_half': return variantMult(g, 'm3', 'a') > 0 && (lawActive(g, 'seed_grain') || g.food <= 50);
    case 'seed_grain': return lawActive(g, 'seed_half') ? false : null;
    case 'child_pack': return techMult(g, 'x1') > 0 && (lawActive(g, 'child_labor') || g.coal <= 40 || g.food <= 40);
    case 'child_labor': return lawActive(g, 'child_pack') ? false : null;
    case 'bath_rota': return d.flags.lice && !lawActive(g, 'hands_first');
    case 'hands_first': return d.flags.lice && !lawActive(g, 'bath_rota');
    default: return null;
  }
}
