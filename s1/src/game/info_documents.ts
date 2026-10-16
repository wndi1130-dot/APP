export const INFO_KINDS = ['next_stop', 'history', 'technology'] as const;
export type InfoKind = typeof INFO_KINDS[number] | 'story';
export type DocumentState = 'pending' | 'read' | 'stored' | 'used';
// 추정: 한도는 새 보관만 막으며, 기존 문서는 줄이거나 버리지 않는다.
export const DOCUMENT_STORE_LIMIT = 3;

interface DocumentBase {
  id: string;
  sourcePlaceId: string;
  segment: number;
  bodyKey: string;
  choices: string[];
  targetId: string | null;
  state: DocumentState;
}
export type InfoDocument = DocumentBase & (
  | { kind: 'next_stop'; nextStop: { stopId: string; observedSegment: number; blankKey: string; confirmed: boolean } }
  | { kind: 'history'; history: { conditionKey: string; workKey: string; objectKey: string; allowedActionIds: string[] } }
  | { kind: 'technology'; technology: { branchCandidates: string[]; consumeAt: string | null } }
);
// 이야기 종류만 예약한다. 본문·문서 생성·효과는 구현하지 않는다.
export interface RecurringRoles {
  representatives: readonly string[];
  officers: readonly string[];
  companions: readonly string[];
}
export interface DocumentContext {
  roles?: RecurringRoles;
  searchable?: boolean;
  inactiveTargetIds?: readonly string[];
  currentStopId?: string;
}
export interface DocumentChange {
  documents: InfoDocument[];
  changed: boolean;
  effectApplied: false;
  reason?: string;
}

export function recurringTargets(roles?: RecurringRoles): string[] {
  return roles ? [...new Set([...roles.representatives, ...roles.officers, ...roles.companions])].filter(Boolean) : [];
}

function content(document: InfoDocument): string {
  const { state: _state, ...value } = document;
  const ordered = (input: unknown): unknown => {
    if (Array.isArray(input)) return input.map(ordered);
    if (input !== null && typeof input === 'object') {
      const record = input as Record<string, unknown>;
      return Object.fromEntries(Object.keys(record).sort().map(key => [key, ordered(record[key])]));
    }
    return input;
  };
  return JSON.stringify(ordered(value));
}

function change(documents: readonly InfoDocument[], changed: boolean, reason?: string): DocumentChange {
  return { documents: structuredClone([...documents]), changed, effectApplied: false, reason };
}

function blocked(document: InfoDocument, context: DocumentContext): string | undefined {
  if (document.kind === 'history') {
    if (!document.targetId || !recurringTargets(context.roles).includes(document.targetId)) return '반복 역할의 대상이 없다';
    if (context.inactiveTargetIds?.includes(document.targetId)) return '대상이 행동할 수 없다';
  }
  if (document.kind === 'next_stop' && context.currentStopId !== undefined
    && document.nextStop.stopId !== context.currentStopId) return '노선이 바뀐 낡은 자료다';
  return undefined;
}

/** 수신은 pending 한 장을 보존한다. 재수신으로 읽음·사용 상태를 되돌리지 않는다. */
export function receiveDocument(
  documents: readonly InfoDocument[], document: InfoDocument, context: DocumentContext = {},
): DocumentChange {
  if (!document.id || !INFO_KINDS.some(kind => kind === document.kind) || document.state !== 'pending') {
    throw new Error('받을 수 없는 정보 문서다');
  }
  const existing = documents.find(item => item.id === document.id);
  if (existing) {
    if (content(existing) !== content(document)) throw new Error('같은 문서 키의 내용이 다르다');
    return change(documents, false, '이미 받은 문서다');
  }
  if (context.searchable === false) return change(documents, false, '지나치기에는 새 문서가 없다');
  if (document.kind === 'history' && (!document.targetId || !recurringTargets(context.roles).includes(document.targetId))) {
    throw new Error('과거사는 반복 역할에만 붙일 수 있다');
  }
  return change([...documents, document], true);
}

/** 정산의 읽기·보관 선택에는 비용이 없고, 한 문서의 선택은 한 번뿐이다. */
export function chooseDocument(
  documents: readonly InfoDocument[], id: string, choice: 'read' | 'stored', limit = DOCUMENT_STORE_LIMIT,
): DocumentChange {
  if (choice !== 'read' && choice !== 'stored') throw new Error('읽기 또는 보관을 골라야 한다');
  if (!Number.isSafeInteger(limit) || limit < 0) throw new Error('보관 한도가 올바르지 않다');
  const document = documents.find(item => item.id === id);
  if (!document || document.state !== 'pending') return change(documents, false, '선택할 미정 문서가 없다');
  if (choice === 'stored' && documents.filter(item => item.state === 'stored').length >= limit) {
    return change(documents, false, '보관이 가득 찼다. 읽기는 가능하다');
  }
  const result = change(documents, true, choice === 'read' ? '효과와 본문은 답 뒤에 채움' : undefined);
  result.documents.find(item => item.id === id)!.state = choice;
  return result;
}

/** 문서 자체를 한 번 소비한다. 미정 효과·조각 배수·비용은 어떤 갈래에도 붙이지 않는다. */
export function useStoredDocument(
  documents: readonly InfoDocument[], id: string, context: DocumentContext = {},
): DocumentChange {
  const document = documents.find(item => item.id === id);
  if (!document || document.state !== 'stored') return change(documents, false, '사용할 보관 문서가 없다');
  const reason = blocked(document, context);
  if (reason) return change(documents, false, reason);
  const result = change(documents, true, '효과와 본문은 답 뒤에 채움');
  result.documents.find(item => item.id === id)!.state = 'used';
  return result;
}

export function documentsSettled(documents: readonly InfoDocument[]): boolean {
  return documents.every(document => document.state !== 'pending');
}
