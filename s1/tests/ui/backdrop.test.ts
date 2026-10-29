import { afterEach, describe, expect, it, vi } from 'vitest';
import { createS1cGame } from '../../src/game';
import { SEASON_ROWS } from '../../src/game/season';
import { backdrop, backdropEl, tick } from '../../src/ui/backdrop';
import type { Clock } from '../../src/ui/backdrop';

// 달리는 배경(사용자 2026-10-11): 창밖 날씨와 재난을 따르고, 달린 시간만 센다.

describe('달리는 배경', () => {
  afterEach(() => vi.unstubAllGlobals());

  it('정차의 날씨를 따르고, 달리는 동안은 마지막에 본 날씨가 이어지고, 아무것도 없으면 눈이다', () => {
    const g = createS1cGame('bg-1');
    g.stop = null;
    expect(backdrop(g)).toEqual({ sky: 'snow', omen: false, pace: 1 });
    expect(backdrop(g, 'fog').sky).toBe('fog');
    expect(backdrop(g, 'fog').pace).toBeGreaterThan(1);
    expect(backdrop(g, 'sleet').sky).toBe('sleet');
  });

  it('눈보라가 닥친 구간은 날씨보다 먼저고 겹이 느려진다. 예고 때는 하늘만 내려앉는다', () => {
    const g = createS1cGame('bg-2');
    g.stop = null;
    g.disasters = true;
    g.disaster = { ...(g.disaster ?? {}), kind: 'blizzard', stage: 'warn', left: 1 } as NonNullable<typeof g.disaster>;
    expect(backdrop(g, 'clear')).toEqual({ sky: 'clear', omen: true, pace: 1 });
    g.disaster.stage = 'active';
    expect(backdrop(g, 'clear').sky).toBe('storm');
    expect(backdrop(g, 'clear').pace).toBeGreaterThan(2);
    g.disaster.kind = 'cold';
    expect(backdrop(g)).toEqual({ sky: 'cold', omen: false, pace: 1 });
    g.disasters = false; // 재난을 끈 판에서는 남은 상태를 읽지 않는다
    expect(backdrop(g, 'clear').sky).toBe('clear');
  });

  it('달린 시간만 모은다: 서 있는 동안은 흐르지 않아 겹이 그 자리에 멎는다', () => {
    const c: Clock = { t: 0, last: 0, moving: false };
    expect(tick(c, true, 1000)).toBe(0); // 출발
    expect(tick(c, true, 4000)).toBe(3000); // 달리는 중 다시 그림
    expect(tick(c, false, 6000)).toBe(5000); // 섬
    expect(tick(c, false, 60000)).toBe(5000); // 서 있음
    expect(tick(c, true, 61000)).toBe(5000); // 다시 출발
    expect(tick(c, true, 62500)).toBe(6500);
  });

  it('기온 꺼진 판에는 look 키가 없다', () => {
    const g = createS1cGame('bg-old');
    g.climate = false;
    expect(backdrop(g)).not.toHaveProperty('look');
  });

  it('계절표 24줄 모두 K1~K6의 지역 띠를 갖는다', () => {
    expect(SEASON_ROWS).toHaveLength(24);
    expect(SEASON_ROWS.every(row => /^K[1-6]$/.test(row.region))).toBe(true);
    expect(SEASON_ROWS.map(row => row.region)).toEqual([
      ...Array(4).fill('K1'), ...Array(5).fill('K2'), 'K3', ...Array(4).fill('K4'), ...Array(4).fill('K5'), ...Array(6).fill('K6'),
    ]);
  });

  it.each([
    [5, 'k2', 'wet', true], [17, 'k5', 'frost', true], [22, 'k6', 'snow', false],
  ] as const)('기온 켠 판 %i구간의 지역·땅·잎을 계절표에서 읽는다', (seg, kit, ground, leaves) => {
    const g = createS1cGame('bg-season');
    g.climate = true;
    g.seg = seg;
    g.stop = null;
    expect(backdrop(g, 'overcast').look).toEqual({ kit, ground, falls: 'none', leaves });
  });

  it('진눈깨비는 따뜻한 구간에서 비고, 그 밖의 하늘에서는 내리지 않는다', () => {
    const g = createS1cGame('bg-rain');
    g.climate = true;
    g.stop = null;
    g.seg = 4;
    expect(backdrop(g, 'sleet').look?.falls).toBe('rain');
    for (const sky of ['clear', 'fog', 'overcast'] as const) expect(backdrop(g, sky).look?.falls).toBe('none');
    expect(backdrop(g, 'snow').look?.falls).toBe('snow');
    g.seg = 17;
    expect(backdrop(g, 'sleet').look?.falls).toBe('sleet');
    g.disasters = true;
    g.disaster = { ...(g.disaster ?? {}), kind: 'blizzard', stage: 'active', left: 1 } as NonNullable<typeof g.disaster>;
    expect(backdrop(g, 'clear').look?.falls).toBe('snow');
    g.disaster.kind = 'cold';
    expect(backdrop(g, 'snow').look?.falls).toBe('none');
  });

  it('기온 켠 판에서 본 날씨가 없으면 흐림이다', () => {
    const g = createS1cGame('bg-unseen');
    g.climate = true;
    g.stop = null;
    expect(backdrop(g).sky).toBe('overcast');
    expect(backdrop(g).look?.falls).toBe('none');
  });

  it('기온 켠 판에만 계절 클래스와 땅 띠 하나를 붙인다', () => {
    // DOM 도우미가 쓰는 속성과 자식만 담는다. 브라우저 모양 검사는 아니다.
    class TestNode {
      attrs: Record<string, string> = {};
      children: TestNode[] = [];
      setAttribute(key: string, value: string) { this.attrs[key] = value; }
      appendChild(child: TestNode) { this.children.push(child); return child; }
    }
    vi.stubGlobal('Node', TestNode);
    vi.stubGlobal('document', { createElement: () => new TestNode() });
    const g = createS1cGame('bg-dom');
    g.stop = null;
    g.seg = 5;
    g.climate = true;
    const sky = backdropEl(g, false, 0) as unknown as TestNode;
    expect(sky.attrs.class).toBe('sky sky--overcast sky--kit-k2 sky--ground-wet sky--falls-none has-leaves');
    expect(sky.attrs['aria-hidden']).toBe('true');
    const layers = ['layer layer--far', 'layer layer--wood', 'layer layer--field', 'layer layer--mid', 'snow', 'snow snow--gust', 'veil'];
    expect(sky.children.map(child => child.attrs.class)).toEqual(layers);
    g.seg = 22;
    expect((backdropEl(g, false, 0) as unknown as TestNode).attrs.class).toBe('sky sky--overcast sky--kit-k6 sky--ground-snow sky--falls-none');
    g.climate = false;
    const old = backdropEl(g, false, 0) as unknown as TestNode;
    expect(old.attrs.class).toBe('sky sky--snow');
    expect(old.children.map(child => child.attrs.class)).toEqual(layers.filter(name => name !== 'layer layer--field'));
    expect(old.attrs.style).toBe(sky.attrs.style);
    // 앱을 다시 열어 정차 날씨를 못 본 채 달려도 마지막 정차(lastStop)의 하늘이 이어진다.
    g.climate = true;
    g.seg = 5;
    g.lastStop = { ...(g.lastStop ?? {}), weather: 'sleet' } as NonNullable<typeof g.lastStop>;
    expect((backdropEl(g, false, 0) as unknown as TestNode).attrs.class).toBe('sky sky--sleet sky--kit-k2 sky--ground-wet sky--falls-rain has-leaves');
  });
});
