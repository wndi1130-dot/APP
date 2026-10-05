import { describe, expect, it } from 'vitest';
import { validateContent } from '../../tools/validate';
import { DUMMY_BILLS, DUMMY_CARDS, DUMMY_CHARACTERS } from '../../src/ui/model/dummy';
import { effectSummary } from '../../src/ui/model/format';

// 화면 뼈대의 더미 카드와 법안이 A1 검사기(스키마, 길이 제한, 문장 규칙)를 그대로 통과하는지 본다.
// 그래야 나중에 데이터(JSON)로 옮겨도 모양이 맞는다.

describe('더미 콘텐츠와 A1 검사기', () => {
  it('결정 카드는 사건 카드 스키마와 문장 규칙을 통과한다', () => {
    for (const card of DUMMY_CARDS) {
      const diagnostics = validateContent(card.event, `${card.event.id}.json`);
      expect(diagnostics, JSON.stringify(diagnostics)).toEqual([]);
      expect(card.event.choices.length).toBeGreaterThanOrEqual(2);
      expect(card.event.choices.length).toBeLessThanOrEqual(3);
      for (const choice of card.event.choices) expect([...choice.label].length).toBeLessThanOrEqual(15);
    }
  });

  it('안건은 법안 스키마를 통과하고 일반 법 하나, 통치 법 하나다', () => {
    for (const bill of DUMMY_BILLS) {
      const diagnostics = validateContent(bill.law, `${bill.law.id}.json`);
      expect(diagnostics, JSON.stringify(diagnostics)).toEqual([]);
    }
    expect(DUMMY_BILLS.map(bill => bill.law.kind).sort()).toEqual(['normal', 'rule']);
  });

  it('인물의 한 줄 소개는 40자 이내이고 성향 딱지를 쓰지 않는다', () => {
    for (const character of DUMMY_CHARACTERS) {
      expect([...character.line].length).toBeLessThanOrEqual(40);
      expect(character.line).not.toMatch(/탐욕스러|겁쟁이|야심가|이상주의자/);
    }
  });

  it('효과 미리보기는 숨은 수치를 드러내지 않는다', () => {
    expect(effectSummary([
      { type: 'coal', amount: -8 },
      { type: 'community.warmth', target: 'tail', amount: 10 },
      { type: 'relation', target: 'engine', amount: -5 },
      { type: 'fear', amount: 3 },
      { type: 'cohesion', target: 'tail', amount: -0.1 },
      { type: 'votes', target: 'tail', amount: 4 },
    ])).toEqual(['석탄 −8', '꼬리칸 온기 +10', '기관실 관계 −5']);
  });
});
