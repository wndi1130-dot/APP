// 의석을 비율(%)로 보인다(사용자 2026-10-11: '앞칸 15석, 기술·의무진 14석' 식 표기가 어지럽다, 비율로 한눈에).
// 화면의 띠 조각 너비와 숫자가 같은 것을 말하게 하고, 석수는 누르면 뜨는 쪽지로 내린다. 계산은 안 바꾸고 보이기만 한다.

/** 몫들을 합이 100이 되는 정수 %로 바꾼다(큰 나머지부터 1씩 올림. 같은 나머지는 앞의 것부터). 합이 0이면 모두 0. */
export function sharePcts(parts: number[]): number[] {
  const total = parts.reduce((sum, n) => sum + n, 0);
  if (total <= 0) return parts.map(() => 0);
  const raw = parts.map(n => (n * 100) / total);
  const out = raw.map(Math.floor);
  const order = raw.map((v, i) => ({ i, rest: v - Math.floor(v) })).sort((a, b) => b.rest - a.rest || a.i - b.i);
  for (let k = 0, left = 100 - out.reduce((sum, n) => sum + n, 0); k < left; k += 1) out[order[k].i] += 1;
  return out;
}

/** 쪽지에 쓰는 석수 줄: '꼬리칸 45석, 앞칸 15석'. 없으면 '없음'. */
export function seatLine(rows: { name: string; seats: number }[]): string {
  return rows.length ? rows.map(r => `${r.name} ${r.seats}석`).join(', ') : '없음';
}
