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

  // 결정 423 카드 6: 「어긴 말」은 겨울 솥(먹을 것)을 건드린 선택에서만. 가구·살림 상자는 따로 기억한다.
  const setting = (id: string) => choices.filter(c => c.effects.some(e => e.type === 'flag' && e.id === id && e.value === true));

  it('front_pot_touched는 앞칸 먹을 것을 건드린 선택지만 세우고, 같은 later를 쓴다', () => {
    const pot = setting('front_pot_touched');
    expect(pot.map(c => `${c.ev}/${c.id}`).sort()).toEqual(['ev_b01_warm_potatoes/c_front_share', 'ev_h02_burst_crates/c_swap_front']);
    expect([...new Set(pot.map(c => c.later))]).toEqual(['앞칸 솥을 건드린 것으로 남아, 앞칸과 한 약속이 있으면 「어긴 말」이 온다.']);
  });

  it('앞칸 가구·살림 상자를 내준 선택지는 front_goods_given만 세우고, 같은 later를 쓴다', () => {
    const goods = setting('front_goods_given');
    expect(goods.map(c => `${c.ev}/${c.id}`).sort()).toEqual(['ev_h01_low_fire/c_burn_furniture', 'ev_h09_too_heavy/c_drop_boxes']);
    expect(goods.filter(c => c.effects.some(e => e.type === 'flag' && e.id === 'front_pot_touched'))).toEqual([]);
    expect([...new Set(goods.map(c => c.later))]).toEqual(['앞칸이 살림을 내준 것으로 기억한다. 겨울 솥 약속을 어긴 것은 아니다.']);
  });

  it('검사기는 why가 없거나 70자를 넘으면 경고만 낸다(오류 아님)', () => {
    const event = JSON.parse(readFileSync(join(__dirname, '../../fixtures/valid/event.json'), 'utf8'));
    delete event.choices[0].why;
    event.choices[1].why = '긴 글'.repeat(30);
    const found = validateContent(event, 'event.json').map(d => `${d.severity}:${d.code}:${d.path}`);
    expect(found).toEqual(['warning:text.why_missing:/choices/0/why', 'warning:text.why_long:/choices/1/why']);
  });
});
