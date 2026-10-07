import { describe, expect, it } from 'vitest';
import { beginNames, endNames, shortText, shownName } from '../../src/ui/names';

// 한 화면 그리기를 흉내 낸다: 이름을 모으고, 겹침이 바뀌면 한 번 더 그린다(app.ts render와 같은 순서).
function draw(names: string[], text = ''): { names: string[]; text: string } {
  const once = () => ({ names: names.map(shownName), text: shortText(text) });
  beginNames();
  let out = once();
  if (endNames()) {
    beginNames();
    out = once();
    expect(endNames()).toBe(false);
  }
  return out;
}

describe('이름 표시', () => {
  it('겹치지 않으면 이름만 쓴다', () => {
    expect(draw(['요나 호프만', '안나 두다']).names).toEqual(['요나', '안나']);
  });

  it('같은 이름이 둘 이상 보이면 성 첫 글자를 붙인다', () => {
    const out = draw(['요나 호프만', '안나 두다'], '요나 크라우스가 돌아오지 않았다.');
    expect(out.names).toEqual(['요나 호.', '안나']);
    expect(out.text).toBe('요나 크.가 돌아오지 않았다.');
  });

  it('같은 사람이 두 번 보이는 건 겹침이 아니다', () => {
    expect(draw(['요나 호프만'], '요나 호프만이(가) 표를 쥐었다.').text).toBe('요나이(가) 표를 쥐었다.');
  });

  it('다음 화면에서 겹침이 풀리면 첫 글자를 뗀다', () => {
    draw(['요나 호프만', '요나 마이어']);
    expect(draw(['요나 마이어']).names).toEqual(['요나']);
  });

  it('프로필에 같은 이름이 있어도 성 첫 글자는 서로 다르다', async () => {
    const profiles = (await import('../../data/profiles.json')).default as unknown as { name: string }[];
    const byGiven = new Map<string, Set<string>>();
    for (const p of profiles) {
      const [g, s] = p.name.split(/\s+/);
      const set = byGiven.get(g) ?? new Set<string>();
      expect(set.has(s[0])).toBe(false);
      set.add(s[0]);
      byGiven.set(g, set);
    }
  });
});
