import { COMMS } from '../data';
import type { Game } from '../state';
import { bedCrowd } from './beds';
import { D } from './data';
import { lawTechSit } from './lawtech';
import { techUsable, zeroSit } from './state';

// 처지 보정(situation()이 더하는 S1c 몫). state.ts에서 따로 뺐다: state가 lawtech·medbay를 부르고
// 그 둘이 다시 state를 부르던 실행 시 import 순환을 끊는다(A2 코드 구조 점검 4번).

/** situation()이 읽는 처지 보정을 다시 계산한다. 기술·침구·장갑이 바뀔 때마다 부른다. */
export function refreshSit(g: Game): void {
  const d = g.dom;
  if (!d) return;
  const sit = zeroSit();
  // 기술이 바꾼 법의 벌(7.3, lawtech.ts). 법을 통과·폐지할 때도 다시 부른다(politics.ts).
  lawTechSit(g, sit);
  for (const c of COMMS) if ((d.bedding[c] ?? -1) >= g.seg) sit[c][0] -= D.beddingWarm;
  if (d.armored.includes('guard') && techUsable(g, 'w3')) sit.guard[3] -= D.armorExposure;
  const beds = bedCrowd(g);
  sit.medtech[2] += beds.medtech;
  sit.tail[2] += beds.tail;
  d.sit = sit;
}
