import { requiredVotes } from '../../core';
import type { CouncilVoteRecord, GroupVoteRecord } from '../../core';
import { hasSessionVote } from '../model/app-state';
import {
  councilInputs, projectCouncil, projectionMarks, recordMarks, runCouncilVote,
} from '../model/council-view';
import type { CouncilProjection, SeatMark } from '../model/council-view';
import { DUMMY_BILLS, billById, characterFor } from '../model/dummy';
import { segmentsUntilCouncil } from '../model/flow';
import { GROUP_META, groupMeta } from '../model/groups';
import { DEFAULT_HEMICYCLE, assignBlocks, hemicycleBounds, layoutHemicycle } from '../model/seats';
import { cx, h, pct, s } from '../dom';
import { chip, screenTitle, segmented, stub } from './common';
import type { View } from './common';

// 식당칸 = 의회. 프로스트펑크 2식 반원 100석. 의석 배분과 표결은 A2 core로 푼다.

interface CouncilModel {
  inSession: boolean;
  voted: boolean;
  mock: boolean;
  billId: string;
  projection: CouncilProjection;
  record: CouncilVoteRecord | null;
}

function councilModel(view: View): CouncilModel {
  const { app, ui } = view;
  const inSession = app.flow.phase === 'council' && !app.flow.ended;
  const voted = hasSessionVote(app);
  const session = voted ? app.sessionVote : null;
  const billId = session?.billId ?? app.billId;
  const bill = billById(billId);
  const inputs = session ? session.inputs : councilInputs(app.game, bill);
  const projection = projectCouncil(inputs, bill.law.kind);
  let record: CouncilVoteRecord | null = null;
  const mock = !voted && ui.mockVote !== null;
  if (session) record = runCouncilVote(inputs, bill.law.kind, app.voteMode, session.rng).record;
  else if (ui.mockVote) record = runCouncilVote(inputs, bill.law.kind, app.voteMode, ui.mockVote.rng).record;
  return { inSession, voted, mock, billId, projection, record };
}

const SEAT_R = DEFAULT_HEMICYCLE.seatRadius;

function seatShape(mark: SeatMark, x: number, y: number, color: string): SVGElement {
  const style = `--seat:${color}`;
  switch (mark) {
    case 'yes':
      return s('circle', { class: 'seat seat--yes', cx: x, cy: y, r: SEAT_R, style });
    case 'no':
      return s('circle', { class: 'seat seat--no', cx: x, cy: y, r: SEAT_R - 1.25, style });
    case 'undecided':
    case 'abstain':
      return s('circle', { class: 'seat seat--small', cx: x, cy: y, r: 2.75, style });
    case 'unknown':
      return s('circle', { class: 'seat seat--unknown', cx: x, cy: y, r: SEAT_R, style });
    case 'absent':
      return s('circle', { class: 'seat seat--absent', cx: x, cy: y, r: SEAT_R - 1.5 });
  }
}

function legendIcon(mark: SeatMark): SVGSVGElement {
  const color = 'var(--ink-2)';
  return s('svg', { class: 'legend__icon', viewBox: '-8 -8 16 16', width: 14, height: 14, 'aria-hidden': 'true' },
    seatShape(mark, 0, 0, color));
}

function hemicycle(model: CouncilModel): HTMLElement {
  const { projection, record } = model;
  const layout = layoutHemicycle(DEFAULT_HEMICYCLE);
  const owners = assignBlocks(layout.length, projection.groups.map(group => ({ id: group.id, seats: group.seats })));
  const marks = record ? recordMarks(record, projection) : projectionMarks(projection);
  const bounds = hemicycleBounds(DEFAULT_HEMICYCLE);
  const width = bounds.maxX - bounds.minX;
  const height = bounds.maxY - bounds.minY;
  const seats = layout.map(seat => seatShape(marks[seat.order], seat.x, -seat.y, groupMeta(owners[seat.order]).color));
  const yes = record ? record.yes : projection.totals.yes;
  const passed = yes >= projection.required;
  const verdict = record ? (record.passed ? '가결' : '부결') : (passed ? '통과 예상' : '모자람');
  return h('div', { class: 'hemi', 'data-test': 'hemicycle' },
    s('svg', {
      class: 'hemi__svg', viewBox: `${bounds.minX} ${-bounds.maxY} ${width} ${height}`,
      role: 'img', 'aria-label': `의석 100석. 찬성 ${yes}표, 통과에 ${projection.required}표 필요.`,
    }, seats),
    h('div', { class: 'hemi__center' },
      h('span', { class: 'hemi__count' }, h('span', { class: 'hemi__count-label' }, '찬성'), String(yes)),
      h('span', { class: cx('hemi__verdict', passed ? 'is-pass' : 'is-fail') },
        `${projection.required}표 필요 · ${verdict}`)));
}

function tally(model: CouncilModel): HTMLElement {
  const { projection, record } = model;
  const totals = record
    ? { yes: record.yes, middle: record.abstain, no: record.no, absent: record.absent }
    : { yes: projection.totals.yes, middle: projection.totals.undecided, no: projection.totals.no, absent: projection.totals.absent };
  const middleLabel = record ? '기권' : '미정';
  const secret = record?.mode === 'secret';
  const legend: [SeatMark, string, number][] = secret
    ? [['unknown', '투표함', 100 - totals.absent], ['absent', '부재', totals.absent]]
    : [['yes', '찬성', totals.yes], ['no', '반대', totals.no], [record ? 'abstain' : 'undecided', middleLabel, totals.middle], ['absent', '부재', totals.absent]];
  return h('div', { class: 'tally' },
    h('div', { class: 'tally__bar', role: 'img', 'aria-label': `찬성 ${totals.yes}, 반대 ${totals.no}, ${middleLabel} ${totals.middle}, 부재 ${totals.absent}. 통과선 ${projection.required}.` },
      h('span', { class: 'tally__seg is-yes', style: `width:${pct(totals.yes)}` }),
      h('span', { class: 'tally__seg is-middle', style: `width:${pct(totals.middle)}` }),
      h('span', { class: 'tally__seg is-no', style: `width:${pct(totals.no)}` }),
      h('span', { class: 'tally__mark', style: `left:${pct(projection.required)}`, title: `통과선 ${projection.required}` })),
    h('ul', { class: 'legend' },
      legend.map(([mark, label, count]) => h('li', { class: 'legend__item' },
        legendIcon(mark), h('span', null, label), h('b', null, String(count))))),
  );
}

function cell(value: string | number, extra?: string): HTMLTableCellElement {
  return h('td', { class: cx('num', extra) }, String(value));
}

/** 0은 가운뎃점으로 흐리게, 0이 아니면 그대로. */
function zeroDot(value: number): HTMLTableCellElement {
  return value === 0 ? cell('·', 'is-dim') : cell(value);
}

function groupTable(model: CouncilModel): HTMLElement {
  const { projection, record } = model;
  const secret = record?.mode === 'secret';
  const publicGroups = record && record.mode === 'public' ? new Map(record.groups.map(group => [group.groupId, group])) : null;
  const headers = record
    ? ['집단', '의석', '찬성', '반대', '기권', '부재', '이탈']
    : ['집단', '의석', '약속', '찬성', '반대', '미정', '부재'];
  const rows = projection.groups.map(group => {
    const meta = GROUP_META[group.id as keyof typeof GROUP_META];
    const leader = group.leaderId ? characterFor(group.leaderId) : undefined;
    const nameCell = h('th', { scope: 'row', class: 'name' },
      chip(group.id), h('span', { class: 'name__text' }, meta.name),
      leader ? h('span', { class: 'name__sub' }, leader.name) : null);
    if (!record) {
      return h('tr', null, nameCell, cell(group.seats), zeroDot(group.promised),
        cell(group.yes), cell(group.no), cell(group.undecided), zeroDot(group.absent));
    }
    if (secret || !publicGroups) {
      return h('tr', null, nameCell, cell(group.seats), cell('—', 'is-dim'), cell('—', 'is-dim'), cell('—', 'is-dim'),
        zeroDot(group.absent), cell('—', 'is-dim'));
    }
    const vote = publicGroups.get(group.id) as GroupVoteRecord;
    return h('tr', null, nameCell, cell(group.seats), cell(vote.yes), cell(vote.no), cell(vote.abstain),
      zeroDot(vote.absent), cell(vote.defectorVotes ? `${vote.defectorVotes}/${vote.promisedVotes}` : '·', vote.defectorVotes ? 'is-alert' : 'is-dim'));
  });
  let totalCells: HTMLTableCellElement[];
  if (!record) {
    const promised = projection.groups.reduce((sum, group) => sum + group.promised, 0);
    const t = projection.totals;
    totalCells = [cell(100), cell(promised), cell(t.yes), cell(t.no), cell(t.undecided), cell(t.absent)];
  } else {
    const defectors = record.mode === 'public' ? record.groups.reduce((sum, group) => sum + group.defectorVotes, 0) : null;
    totalCells = [cell(100), cell(record.yes), cell(record.no), cell(record.abstain), cell(record.absent),
      cell(defectors === null ? '?' : defectors || '·', defectors ? 'is-alert' : 'is-dim')];
  }
  return h('table', { class: 'council-table', 'data-test': 'council-table' },
    h('thead', null, h('tr', null, headers.map((label, index) => h('th', { scope: 'col', class: index === 0 ? 'name' : 'num' }, label)))),
    h('tbody', null, rows),
    h('tfoot', null, h('tr', null, h('th', { scope: 'row', class: 'name' }, '합계'), totalCells)));
}

function statusText(view: View, model: CouncilModel): string {
  if (model.inSession) return model.voted ? '회기 · 표결 끝' : '회기 · 표결 전';
  if (model.voted) return '회기 끝 · 이번 구간 표결 결과';
  if (model.mock) return '모의 표결 · 기록 안 됨';
  const until = segmentsUntilCouncil(view.app.flow);
  return until === null ? '회기 아님 · 남은 회기 없음' : `회기 아님 · ${until === 0 ? '이번 구간' : `${until}구간 뒤`}`;
}

function modeNote(view: View, model: CouncilModel): HTMLElement {
  const { app } = view;
  const publicMode = app.voteMode === 'public';
  const explanation = publicMode
    ? '공개 투표: 누가 어떻게 찍었는지 남는다. 배신이 보이고 공포가 오른다.'
    : '비밀 투표: 합계만 남는다. 약속한 표가 왔는지 알 수 없다.';
  const short = publicMode ? '공개: 누가 찍었는지 남는다.' : '비밀: 합계만 남는다.';
  const actual = model.voted && app.sessionVote && app.sessionVote.mode !== app.voteMode
    ? ` 실제로는 ${app.sessionVote.mode === 'public' ? '공개' : '비밀'} 투표였다.`
    : '';
  return h('p', { class: 'council__note' },
    h('span', { class: 'label-full' }, explanation + actual),
    h('span', { class: 'label-short', 'aria-hidden': 'true' }, short + actual));
}

export function councilScreen(view: View): HTMLElement {
  const model = councilModel(view);
  const bill = billById(model.billId);
  const billLabel = (id: string) => {
    const candidate = billById(id);
    return `${candidate.title} ${requiredVotes(candidate.law.kind)}`;
  };
  const kindLabel = bill.law.kind === 'normal' ? '일반 법' : '통치 법';
  const agenda = model.voted
    ? h('div', { class: 'agenda__fixed' }, billLabel(model.billId))
    : segmented('안건', 'bill', 'bill', DUMMY_BILLS.map((candidate, index) => ({
      value: candidate.law.id, label: billLabel(candidate.law.id), test: `bill-${index}`,
    })), model.billId, 'agenda__seg');
  return h('section', { class: 'council', 'aria-label': '식당칸 의회', 'data-test': 'council' },
    screenTitle('식당칸 · 의회', statusText(view, model),
      stub(view, 'S1a', '거래 수단 다섯', 'stub--inline'),
      stub(view, 'S1b', '투표함 연출', 'stub--inline')),
    h('div', { class: 'council__body' },
      h('div', { class: 'council__left' }, hemicycle(model), tally(model), modeNote(view, model)),
      h('div', { class: 'council__right' },
        h('div', { class: 'agenda' }, agenda,
          h('p', { class: 'agenda__preview' }, h('b', null, `${kindLabel} ${model.projection.required}표`), ` · ${bill.law.preview}`)),
        groupTable(model))));
}

/** 아래 왼쪽 엄지 자리에 붙는 투표 방식 전환. */
export function councilControls(view: View): HTMLElement[] {
  return [segmented('투표 방식', 'vote-mode', 'mode', [
    { value: 'public', label: '공개', test: 'mode-public' },
    { value: 'secret', label: '비밀', test: 'mode-secret' },
  ], view.app.voteMode, 'mode-toggle')];
}
