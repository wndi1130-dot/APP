// 화면에 소수점을 보이지 않는다(2026-10-07 사용자: "소수점은 보고 안 하게"). 계산은 소수로 하고, 글로 나갈 때만 바꾼다.
// - 배수 ×0.85 → −15%, ×1.25 → +25%
// - 구간당 1보다 작은 값 +0.4/구간 → 3구간에 +1
// - 그 밖의 소수 5.5 → 6, 0.3 → 1 미만이 아니라 반올림(0이 되면 1로 둔다: 있는 것을 없다고 쓰지 않는다)

const round = (v: number) => Math.round(v);

function mult(x: number): string {
  const p = round((x - 1) * 100);
  return p >= 0 ? `+${p}%` : `−${Math.abs(p)}%`;
}

export function plainNumbers(text: string): string {
  if (!/\d\.\d/.test(text)) return text;
  return text
    .replace(/×(\d+\.\d+)/g, (_, x: string) => mult(Number(x)))
    .replace(/([+−-])(\d+\.\d+)\/구간/g, (m, sign: string, x: string) => {
      const v = Number(x);
      if (v >= 1) return `${sign}${round(v)}/구간`;
      if (v <= 0) return m;
      return `${round(1 / v)}구간에 ${sign}1`;
    })
    .replace(/\d+\.\d+/g, x => {
      const v = Number(x);
      const r = round(v);
      return String(r === 0 && v > 0 ? 1 : r);
    });
}
