import { hash } from './omens';
import type { Weather } from './omens';
import { fallsAt, weatherWeights } from './season';

/** 결정 474 N2: 앞 정차의 날씨가 다음 정차에도 이어질 몫(%). */
export const STAY = 50;

/** 기온 켠 판의 노선 날씨. 판 상태·난수를 쓰지 않고 필요한 앞 구간만 거슬러 센다(노선은 1~24). */
export function routeWeather(seed: string, seg: number): Weather {
  const table = weatherWeights(seg);
  if (seg > 1 && hash(`${seed}:ws:${seg}`) % 100 < STAY) {
    const previous = routeWeather(seed, seg - 1);
    if (table.some(([weather, weight]) => weather === previous && weight > 0)) return fallsAt(seg, previous);
  }
  const total = table.reduce((sum, [, weight]) => sum + weight, 0);
  let x = hash(`${seed}:w:${seg}`) % total;
  for (const [weather, weight] of table) {
    if (x < weight) return fallsAt(seg, weather);
    x -= weight;
  }
  return 'snow';
}
