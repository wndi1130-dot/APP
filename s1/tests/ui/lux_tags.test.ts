import { describe, expect, it } from 'vitest';
import { LUX_REST, luxBreakdown, luxFront, luxGain, luxItems, syncLuxTags } from '../../src/ui/lux_tags';
import { createS1cGame } from '../../src/game';
import type { Game } from '../../src/game';

// 사치품 이름표(결정 071): 숫자는 하나 그대로, 화면만 얻은 곳에 따라 갈라 보인다. 규칙 값과 난수는 건드리지 않는다.

const bag = (lux: number, luxTags?: string[]) => ({ lux, luxTags });

describe('사치품 이름표', () => {
  it('장소의 묶음을 차례대로 돌려 붙인다(난수 없음)', () => {
    expect(luxGain(0, 'houses', 4)).toEqual(['술', '담배', '커피', '축음기판']);
    expect(luxGain(4, 'houses', 2)).toEqual(['그림', '술']);
    expect(luxGain(0, 'office', 3)).toEqual(['시계', '은수저', '시계']);
    expect(luxGain(0, undefined, 2)).toEqual(['술', '담배']);
    expect(luxGain(0, 'houses', 0)).toEqual([]);
  });

  it('이름표가 없는 판(옛 저장, 새 판)은 「그 밖」으로 읽고 갈라 보이지 않는다', () => {
    expect(luxItems(bag(3))).toEqual([LUX_REST, LUX_REST, LUX_REST]);
    expect(luxBreakdown(bag(8))).toBe('');
    expect(luxFront(bag(8), 3)).toBe('');
  });

  it('이름표 수가 숫자와 안 맞으면 모자란 만큼 채우고 남는 뒤를 자른다', () => {
    expect(luxBreakdown(bag(4, ['술', '담배']))).toBe('술 1 · 담배 1 · 그 밖 2');
    expect(luxItems(bag(1, ['술', '담배']))).toEqual(['술']);
    expect(luxItems(bag(-2, ['술']))).toEqual([]);
  });

  it('치를 때는 앞에서부터 나간다', () => {
    const g = bag(5, ['술', '술', '담배', '커피', '그림']);
    expect(luxFront(g, 3)).toBe('술 2 · 담배 1');
    expect(luxBreakdown(g)).toBe('술 2 · 담배 1 · 커피 1 · 그림 1');
  });

  it('정차 수확으로 늘면 그 장소 이름이 붙고, 줄면 앞에서 떼며, 그 밖에 는 몫은 이름표가 없다', () => {
    const g = { lux: 8 } as Game;
    syncLuxTags(g, 8, 11, { place: 'houses', n: 3 });
    g.lux = 11;
    expect(luxItems(g).slice(8)).toEqual(['축음기판', '그림', '술']);
    syncLuxTags(g, 11, 2, null);
    g.lux = 2;
    expect(luxItems(g)).toEqual(['그림', '술']);
    syncLuxTags(g, 2, 5, null);
    g.lux = 5;
    expect(luxBreakdown(g)).toBe('그림 1 · 술 1 · 그 밖 3');
    syncLuxTags(g, 5, 0, null);
    expect(g.luxTags).toBeUndefined();
  });

  it('새 판은 이름표 칸이 없다(규칙이 만들지 않는다)', () => {
    expect(createS1cGame('lux').luxTags).toBeUndefined();
  });
});
