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

/** 여론(결정 058): 집단의 관계 값을 의석 크기로 무게를 두어 평균한 값. −는 불만 쪽, +는 지지 쪽. 화면만 쓰고 규칙은 읽지 않는다. */
export function moodMean(rows: { seats: number; rel: number }[]): number {
  const total = rows.reduce((sum, r) => sum + r.seats, 0);
  if (total <= 0) return 0;
  return Math.round(rows.reduce((sum, r) => sum + r.seats * r.rel, 0) / total);
}

/** 눈금 위 자리(0~100%). 관계 값은 ±span에서 끝에 붙는다. 가운데(50%)가 0이다. */
export function scalePos(rel: number, span = 50): number {
  return 50 + (Math.max(-span, Math.min(span, rel)) / span) * 50;
}
