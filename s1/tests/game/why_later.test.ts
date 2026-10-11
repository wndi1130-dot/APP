import { readdirSync, readFileSync } from 'node:fs';
import { join } from 'node:path';
import { describe, expect, it } from 'vitest';
import { validateContent } from '../../tools/validate';

// 구현명세 라: 선택지마다 「그 칸의 사정 한 줄(why)」이 있고, 후속 카드를 부르는 선택지엔 「나중에(later)」가 있다.
// 같은 표식을 세우는 선택지는 같은 later 글을 쓴다(플레이어가 한 번 읽은 말이 바뀌지 않게).

interface Choice { id: string; why?: string; later?: string; effects: { type: string; id?: string; value?: unknown }[] }
const dir = join(__dirname, '../../data/events');
const choices = readdirSync(dir).filter(f => f.endsWith('.json')).flatMap(f => {
  const ev = JSON.parse(readFileSync(join(dir, f), 'utf8')) as { id: string; choices: Choice[] };
  return ev.choices.map(c => ({ ev: ev.id, ...c }));
});

describe('선택지의 why·later', () => {
  it('모든 선택지에 why가 있고 70자 이하다', () => {
    const bad = choices.filter(c => !c.why || c.why.length > 70).map(c => `${c.ev}/${c.id}`);
    expect(bad).toEqual([]);
  });

  it('후속 카드를 부르는 선택지엔 later가 있다', () => {
    const bad = choices.filter(c => c.effects.some(e => e.type === 'followup') && !c.later).map(c => `${c.ev}/${c.id}`);
    expect(bad).toEqual([]);
  });

  it('front_pot_touched를 세우는 선택지는 같은 later를 쓴다', () => {
    const texts = new Set(choices
      .filter(c => c.effects.some(e => e.type === 'flag' && e.id === 'front_pot_touched' && e.value === true))
      .map(c => c.later));
    expect([...texts]).toEqual(['앞칸 솥을 건드린 것으로 남아, 앞칸과 한 약속이 있으면 「어긴 말」이 온다.']);
  });

  it('검사기는 why가 없거나 70자를 넘으면 경고만 낸다(오류 아님)', () => {
    const event = JSON.parse(readFileSync(join(__dirname, '../../fixtures/valid/event.json'), 'utf8'));
    delete event.choices[0].why;
    event.choices[1].why = '긴 글'.repeat(30);
    const found = validateContent(event, 'event.json').map(d => `${d.severity}:${d.code}:${d.path}`);
    expect(found).toEqual(['warning:text.why_missing:/choices/0/why', 'warning:text.why_long:/choices/1/why']);
  });
});
