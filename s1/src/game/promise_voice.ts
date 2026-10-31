// 약속을 지켰을 때 그 칸 사람이 하는 말 한 줄(결정 184, 약속_지킴_값후보 5·7절). 값은 바꾸지 않고 일지 줄만 하나 늘린다.
// 고르는 법에는 주사위가 없다: 이 판에서 그 칸의 약속을 몇 번째 지켰는지로 정한다
// (첫째는 그 칸의 첫 줄, 둘째는 둘째 줄, 셋째부터는 어느 칸에나 쓰는 셋을 차례로 돈다). 그래서 같은 칸의 말이 두 번 이어 나오지 않고 같은 씨앗의 판이 달라지지 않는다.
import { COMM_NAME } from './data';
import type { Comm } from './data';
import { journal } from './state';
import type { Game } from './state';

/** 칸마다 두 줄 */
export const VOICE: Record<Comm, readonly [string, string]> = {
  engine: ['말한 대로 왔구나. 화부들한테 전하겠다.', '약속은 석탄 같은 거다. 넣은 만큼 간다.'],
  tail: ['한다고 한 걸 했네. 여기서는 그게 드문 일이야.', '뒤쪽에서도 다 봤어. 잊지 않을게.'],
  guard: ['명령이 아니라 약속이었지. 지킨 것으로 적어 둔다.', '말과 한 일이 같았다. 그거면 됐다.'],
  medtech: ['말한 날에 말한 대로였다. 그렇게 적어 두겠다.', '지켜질 줄 몰랐다. 다음에도 묻겠다.'],
  front: ['계산이 맞았구나. 다음 이야기도 들어 보자.', '약속을 값으로 치는 사람이라면 우리도 그렇게 대하겠다.'],
};

/** 어느 칸에나 쓰는 셋 */
export const VOICE_ANY: readonly string[] = ['한 말을 지켰다.', '이번에는 믿을 만했다.', '칸 사람들이 다 들었다. 열차장이 약속을 지켰다고.'];

/** 그 칸의 n번째(1부터) 지킨 약속에 붙일 말 */
export function voiceFor(c: Comm, n: number): string {
  if (n <= 2) return VOICE[c][n - 1];
  return VOICE_ANY[(n - 3) % VOICE_ANY.length];
}

/** 약속을 지킨 자리에서 부른다. 지킨 수를 세고, 말 한 줄을 일지에 잇는다. 'deal' 꼬리표라서 접힌 일지에서도 보인다. */
export function voiceKept(g: Game, c: Comm): void {
  const kept = g.keptVoice ??= {};
  kept[c] = (kept[c] ?? 0) + 1;
  journal(g, `${COMM_NAME[c]}: 「${voiceFor(c, kept[c]!)}」`, 'deal');
}
