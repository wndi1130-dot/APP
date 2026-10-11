import { describe, expect, it } from 'vitest';
import { createS1cGame } from '../../src/game';
import { workshopNow } from '../../src/ui/domestic';

// 공방 창 「지금」 줄: 복원 중이면 이름, 퍼센트, 남은 구간 어림을 한 줄에 적는다.

function restoring(progress: number, need = 6) {
  const g = createS1cGame('ws-now');
  const d = g.dom!;
  d.restoring = 'w1';
  d.techs.w1 = { stage: 'restoring', progress, need } as never;
  d.parts = d.target; // 부품이 차 있어 복원이 바로 돈다
  return g;
}

describe('공방 「지금」 줄', () => {
  it('복원이 없으면 공방 상태 글 그대로다', () => {
    const g = createS1cGame('ws-now-0');
    expect(workshopNow(g)).not.toContain('%');
  });

  it('복원 중이면 퍼센트와 남은 구간을 적는다', () => {
    expect(workshopNow(restoring(3))).toMatch(/^복원: .+ 50% · \d+구간$/);
  });

  it('부품이 앞 차례이고 목표보다 적으면 「부품 뒤」라고 적는다', () => {
    const g = restoring(3);
    const d = g.dom!;
    d.order = ['parts', 'restore', 'modify'];
    d.parts = 0; d.target = 5;
    expect(workshopNow(g)).toMatch(/50% · 부품 뒤$/);
  });

  it('추인을 기다리는 배관은 퍼센트 대신 「추인 기다림」이다', () => {
    const g = restoring(6);
    (g.dom!.techs.w1 as { pending?: boolean }).pending = true;
    expect(workshopNow(g)).toMatch(/· 추인 기다림$/);
  });
});
