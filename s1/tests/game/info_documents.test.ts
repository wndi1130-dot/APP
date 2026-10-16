import { describe, expect, it } from 'vitest';
import {
  DOCUMENT_STORE_LIMIT, INFO_KINDS, chooseDocument, documentsSettled,
  receiveDocument, recurringTargets, useStoredDocument,
} from '../../src/game/info_documents';
import type { InfoDocument, RecurringRoles } from '../../src/game/info_documents';
import { goalStatus } from '../../src/game/stop_goals';

const document = (id = 'doc_a'): InfoDocument => ({
  id, kind: 'technology', sourcePlaceId: 'place_a', segment: 1, bodyKey: '', choices: [],
  targetId: null, state: 'pending', technology: { branchCandidates: [], consumeAt: null },
});
const roles: RecurringRoles = { representatives: ['target_a'], officers: ['target_a', 'target_b'], companions: ['target_c'] };
const history = (targetId: string | null): InfoDocument => ({
  id: 'doc_history', kind: 'history', sourcePlaceId: 'place_a', segment: 1, bodyKey: '', choices: [],
  targetId, state: 'pending', history: { conditionKey: '', workKey: '', objectKey: '', allowedActionIds: [] },
});

describe('정보 문서 준비', () => {
  it('덤은 목표 달성과 무관하다', () => {
    const received = receiveDocument([], document());
    expect(received.documents).toHaveLength(1);
    expect(received.effectApplied).toBe(false);
    expect(goalStatus('coal', 12, { coal: 12 })).toBe('done');
    expect(goalStatus('coal', 12, {})).toBe('retreat');
    expect(receiveDocument([], document(), { searchable: false }).documents).toEqual([]);
    expect(receiveDocument(received.documents, document('doc_b'), { searchable: false }).documents).toEqual(received.documents);
  });

  it('읽기와 보관은 둘 중 하나다', () => {
    const pending = receiveDocument([], document()).documents;
    expect(documentsSettled(pending)).toBe(false);
    const read = chooseDocument(pending, 'doc_a', 'read');
    expect(read.documents[0].state).toBe('read');
    expect(read.effectApplied).toBe(false);
    expect(documentsSettled(read.documents)).toBe(true);
    expect(chooseDocument(read.documents, 'doc_a', 'stored').changed).toBe(false);
    expect(chooseDocument(read.documents, 'doc_a', 'read').changed).toBe(false);
    expect(useStoredDocument(read.documents, 'doc_a').changed).toBe(false);
    const stored = chooseDocument(pending, 'doc_a', 'stored');
    expect(stored.documents[0].state).toBe('stored');
    expect(documentsSettled(stored.documents)).toBe(true);
    expect(chooseDocument(stored.documents, 'doc_a', 'read').changed).toBe(false);
    expect(pending[0].state).toBe('pending');
  });

  it('보관 포화에도 문서를 버리지 않는다', () => {
    expect(DOCUMENT_STORE_LIMIT).toBe(3);
    const stored: InfoDocument[] = Array.from({ length: 3 }, (_, index) => ({ ...document(`doc_${index}`), state: 'stored' }));
    const pending = receiveDocument(stored, document()).documents;
    const rejected = chooseDocument(pending, 'doc_a', 'stored');
    expect(rejected.changed).toBe(false);
    expect(rejected.documents).toEqual(pending);
    expect(rejected.documents).toHaveLength(4);
    expect(rejected.documents[3].state).toBe('pending');
    expect(chooseDocument(pending, 'doc_a', 'read').documents[3].state).toBe('read');
    const over = [...stored, { ...document('doc_extra'), state: 'stored' as const }, document()];
    const restored = JSON.parse(JSON.stringify(over)) as InfoDocument[];
    expect(chooseDocument(restored, 'doc_a', 'stored', 1).documents).toEqual(over);
    expect(chooseDocument(restored, 'doc_a', 'read', 1).documents.slice(0, 4)).toEqual(over.slice(0, 4));
    expect(chooseDocument(restored, 'doc_a', 'stored', 0).documents).toHaveLength(5);
  });

  it('저장한 문서는 한 번만 사용한다', () => {
    const pending = receiveDocument([], document()).documents;
    expect(receiveDocument(pending, document()).changed).toBe(false);
    const stored = chooseDocument(pending, 'doc_a', 'stored').documents;
    const used = useStoredDocument(stored, 'doc_a');
    expect(used.changed).toBe(true);
    expect(used.documents[0].state).toBe('used');
    const reopened = JSON.parse(JSON.stringify(used.documents)) as InfoDocument[];
    expect(useStoredDocument(reopened, 'doc_a').changed).toBe(false);
    expect(receiveDocument(reopened, document()).documents).toEqual(reopened);
    const reordered = Object.fromEntries(Object.entries(document()).reverse()) as InfoDocument;
    expect(receiveDocument(reopened, reordered).documents).toEqual(reopened);
    expect(() => receiveDocument(reopened, { ...document(), bodyKey: 'body_other' })).toThrow();
    expect(stored[0].state).toBe('stored');
    const next: InfoDocument = {
      id: 'doc_next', kind: 'next_stop', sourcePlaceId: 'place_a', segment: 1, bodyKey: '', choices: [],
      targetId: null, state: 'stored', nextStop: { stopId: 'stop_next', observedSegment: 1, blankKey: 'risk', confirmed: false },
    };
    const stale = useStoredDocument([next], 'doc_next', { currentStopId: 'stop_other' });
    expect(stale.changed).toBe(false);
    expect(stale.reason).toContain('낡은 자료');
    expect(stale.documents[0]).toEqual(next);
  });

  it('과거사는 반복 역할에만 붙는다', () => {
    expect(recurringTargets(roles)).toEqual(['target_a', 'target_b', 'target_c']);
    for (const targetId of recurringTargets(roles)) {
      const received = receiveDocument([], history(targetId), { roles });
      expect(received.documents[0].bodyKey).toBe('');
      expect(received.documents[0].targetId).toBe(targetId);
      expect(received.documents[0]).not.toHaveProperty('body');
    }
    for (const target of ['one_time', 'missing', null]) expect(() => receiveDocument([], history(target), { roles })).toThrow();
    expect(() => receiveDocument([], history('target_a'))).toThrow();
    const stored = chooseDocument(receiveDocument([], history('target_a'), { roles }).documents, 'doc_history', 'stored').documents;
    const inactive = useStoredDocument(stored, 'doc_history', { roles, inactiveTargetIds: ['target_a'] });
    expect(inactive.changed).toBe(false);
    expect(inactive.documents).toEqual(stored);
    expect(useStoredDocument(stored, 'doc_history', { roles: { ...roles, representatives: [], officers: [] } }).changed).toBe(false);
    expect(useStoredDocument(stored, 'doc_history', { roles }).documents[0].state).toBe('used');
  });

  it('미정 기술 문서의 효과는 꺼져 있다', () => {
    expect(INFO_KINDS).toEqual(['next_stop', 'history', 'technology']);
    expect(() => receiveDocument([], { ...document(), kind: 'story' } as unknown as InfoDocument)).toThrow();
    const pending = receiveDocument([], document());
    const read = chooseDocument(pending.documents, 'doc_a', 'read');
    const stored = chooseDocument(pending.documents, 'doc_a', 'stored');
    const used = useStoredDocument(stored.documents, 'doc_a');
    for (const result of [pending, read, stored, used]) {
      expect(result.effectApplied).toBe(false);
      expect(result.documents[0]).not.toHaveProperty('effect');
      expect(result.documents[0]).not.toHaveProperty('cost');
      expect(result.documents[0]).not.toHaveProperty('fragmentMultiplier');
      expect(result.documents[0]).toMatchObject({ technology: { branchCandidates: [], consumeAt: null } });
    }
    expect(read.reason).toContain('답 뒤에 채움');
    expect(used.reason).toContain('답 뒤에 채움');
  });
});
