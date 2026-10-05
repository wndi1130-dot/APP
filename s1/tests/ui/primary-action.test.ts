import { describe, expect, it } from 'vitest';
import { advance, castSessionVote, chooseCard, createApp, setCardCollapsed } from '../../src/ui/model/app-state';
import type { AppState } from '../../src/ui/model/app-state';
import type { UiState } from '../../src/ui/views/common';
import { primaryAction } from '../../src/ui/views/hud';

function ui(patch: Partial<UiState> = {}): UiState {
  return {
    screen: 'home', panel: null, captainTab: 'journal', mockVote: null, confirmReset: false, toast: null,
    enter: null, slot: null, ...patch,
  };
}

function toCouncil(): AppState {
  let app = createApp('primary');
  while (app.flow.phase !== 'council') app = app.card ? chooseCard(app, 1) : advance(app);
  return app;
}

describe('아래 오른쪽 주 단추', () => {
  it('단계마다 다음 할 일 하나를 보여준다', () => {
    let app = createApp('primary');
    expect(primaryAction(app, ui())?.label).toBe('출발');
    app = advance(app);
    expect(primaryAction(app, ui())).toBeNull();
    expect(primaryAction(setCardCollapsed(app, true), ui())).toMatchObject({ label: '결정 카드', action: 'card-expand' });
    app = chooseCard(app, 2);
    expect(primaryAction(app, ui())?.label).toBe('정차로');
    app = chooseCard(advance(app), 1);
    expect(primaryAction(app, ui())?.label).toBe('정산으로');
    expect(primaryAction(advance(app), ui())?.label).toBe('다음 구간으로');
  });

  it('회기엔 식당칸으로 → 표결 → 정산으로', () => {
    const app = toCouncil();
    expect(primaryAction(app, ui())).toMatchObject({ label: '식당칸으로', action: 'open-car', data: { car: 'dining' } });
    expect(primaryAction(app, ui({ screen: 'council' }))).toMatchObject({ label: '표결', action: 'vote' });
    const voted = castSessionVote(app);
    expect(primaryAction(voted, ui())?.label).toBe('정산으로');
    expect(primaryAction(voted, ui({ screen: 'council' }))?.label).toBe('정산으로');
    // 표결 결과를 보는 동안 정산으로 넘어가도 모의 표결이 아니라 흐름을 이어 간다.
    expect(primaryAction(advance(voted), ui({ screen: 'council' }))?.label).toBe('다음 구간으로');
  });

  it('회기가 아닐 때 의회 화면은 모의 표결과 예상 보기를 오간다', () => {
    const app = createApp('primary');
    expect(primaryAction(app, ui({ screen: 'council' }))).toMatchObject({ label: '모의 표결', action: 'vote' });
    expect(primaryAction(app, ui({ screen: 'council', mockVote: { rng: app.game.rng, billId: app.billId } })))
      .toMatchObject({ label: '예상 보기', action: 'mock-clear' });
  });

  it('판이 끝나면 처음부터', () => {
    let app = createApp('primary-end');
    for (let step = 0; step < 400 && !app.flow.ended; step += 1) {
      if (app.card) app = chooseCard(app, 1);
      else if (app.flow.phase === 'council' && app.sessionVote?.segment !== app.flow.segment) app = castSessionVote(app);
      else app = advance(app);
    }
    expect(app.flow.ended).toBe(true);
    expect(primaryAction(app, ui())).toMatchObject({ label: '처음부터', action: 'reset' });
  });
});
