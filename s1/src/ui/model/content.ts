import type { Condition, Effect, LawKind } from '../../core';

// A1 스키마(schema/event.schema.json, law.schema.json)와 같은 모양의 타입.
// 더미 카드와 법안이 그대로 JSON 데이터로 옮겨 갈 수 있게 맞춘다. tests/ui/content.test.ts가 A1 검사기로 확인한다.

export type Stage = 's1a' | 's1b' | 's1c';
export type EventPhase = 'travel' | 'stop' | 'council' | 'settle';
export type Speaker =
  | 'captain' | 'deputy' | 'ration_officer' | 'rep' | 'aide' | 'faction_leader'
  | 'tail' | 'engine' | 'guard' | 'medtech' | 'front';

export interface EventChoice {
  label: string;
  effects: Effect[];
  followups: string[];
  witnesses: string[];
}

export interface EventContent {
  id: string;
  stage: Stage;
  phase: EventPhase;
  trigger: Condition[];
  speaker: Speaker;
  body: string;
  choices: EventChoice[];
  repeat: number;
  chronicle?: string;
}

export interface LawContent {
  id: string;
  kind: LawKind;
  opens_when: Condition[];
  effects: Effect[];
  stances: {
    ration: 'equal' | 'contribution' | 'neutral';
    authority: 'discipline' | 'practical' | 'neutral';
    technology: 'restoration' | 'adaptation' | 'neutral';
  };
  preview: string;
  chronicle: { passed: string; rejected: string };
}
