// S1a 규칙의 수치와 데이터. 출처는 docs/design/briefs/s1a_politics_numbers.md와 그 시뮬레이터(docs/design/sim/s1a_balance.py)다.
// 브리프가 고쳐지면 여기를 같이 고친다. 문장은 모두 자리표시이고, 나중에 Gemini 문장으로 바꾼다.

export const COMMS = ['tail', 'medtech', 'guard', 'front', 'engine'] as const;
export type Comm = typeof COMMS[number];

export const COMM_NAME: Record<Comm, string> = {
  tail: '꼬리칸', medtech: '기술·의무진', guard: '경비대', front: '앞칸', engine: '기관실',
};
export const COMM_SHORT: Record<Comm, string> = {
  tail: '꼬리', medtech: '의무', guard: '경비', front: '앞칸', engine: '기관',
};

// 브리프 1장과 시뮬레이터 P. 시뮬레이션 뒤 고친 값을 그대로 쓴다.
export const P = Object.freeze({
  segments: 24, sessionEvery: 3,
  coal0: 100, food0: 100, med0: 20, lux0: 8, trust0: 50, tension0: 20,
  coalRun: 6, coalStrike: 4, coalHeatPerLever: 0.25, foodPerPersonLever: 0.025,
  haulTotal: 36, targetBoost: 3, leverStep: 12, winterEvery: 6, winterDrop: 5,
  injuryRate: 0.25, deathRate: 0.03, medPerInjured: 0.5,
  recoverBase: 1, recoverCap: 3, naturalCeiling: 15,
  engineFatigue: 2, shiftRelief: 10, shiftCoal: 3,
  strikeRel: -15, refuseRel: 5, rescueRate: 0.2, crisisLine: 30,
  thrownHorde: 0.05, storeRisk: 0.03, coldCap: 6, pyreCoal: 1, pyreKinCrowd: 2, pyreLight: 1.05,
  // 정찰 대가(제안, 파밍 자동 파견과 같은 값): 정찰조 2명이 체류 일부를 써서 산출 ×0.8, 정찰조도 표결에서 빠진다.
  scoutSize: 2, scoutHaul: 0.8,
  /** 먼저 보낸 정찰조 한 사람의 위험(제안): 장소 위험 1~3 × 바깥 기척 × 무리 × 경비대 경계 거부. 크게 다침 5%, 못 돌아옴 1.2% 단위. 기척이 고요(0.8)면 0 */
  scoutHurt: 0.05, scoutDeath: 0.012,
  repealCool: 2, repealRel: 10, hostileGrudge: 2, blackmailReputation: 3, grudgeDecay: 2,
  maxDealsPerSession: 3, promiseSegments: 3,
  // 꼬리칸 수단(first_leg_story 6.4, 사용자 16:00 '수단 더하기'. 숫자는 제안).
  // 작업조를 낸 칸 노출 +5, 안 낸 칸 −10(쉼 바닥까지), 지나친 정차는 모두 쉰다. 의무진·앞칸은 궂은일 반감 관계 −3. 다친 사람 1명마다 그 칸 −2.
  crewGain: 5, crewRest: 10, choreRel: -3, hurtRel: -2, snowExposure: 10,
  // 작업조 노동으로는 노출이 60 위로 안 오른다: 꼬리칸의 시작 노출 60이 '늘 먼저 불려 나간' 값이다(6.4 첫 줄).
  // 한계가 없으면 꼬리칸만 보내는 판이 노출 100에 닿아 완주가 42→24%로 무너졌다(4000판, 제안). 법·눈 녹이기는 이 위로도 올린다.
  crewCap: 60,
  // 공간 레버 0~2단: 한 단에 꼬리칸 과밀 −10, 내주는 칸 +10. 당길 때 내주는 칸 관계 −3, 당겨 둔 동안 구간마다 단당 −1.
  spaceStep: 10, spaceMax: 2, spacePullRel: -3, spaceHoldRel: -1,
  // 같은 칸을 3구간 안에 또 지지하면 +10 대신 +5(first_leg_story 7.7 'S1a 몫 제안').
  supportRel: 10, supportRepeatRel: 5, supportGap: 3,
});
/** 쉼 바닥: 안 나간 칸의 노출이 이 아래로는 안 내려간다(6.4). 표에 없는 칸(경비대·기관실)은 쉼으로 안 바뀐다. */
export const REST_FLOOR: Partial<Record<Comm, number>> = { tail: 35, medtech: 25, front: 10 };
/** 운반 솜씨(손에 익었나). 기관실은 화부가 빠지면 열차가 못 가서 못 낸다. */
export const CREW_HAUL: Partial<Record<Comm, number>> = { tail: 1, guard: 0.9, medtech: 0.9, front: 0.8 };
/** 늘 하던 일이 아닌 칸: 낼 때마다 궂은일 반감 */
export const CHORE_COMMS: readonly Comm[] = ['medtech', 'front'];

// 처지 = [온기, 배급, 과밀, 위험 노출]. 레버 2(보통) 기준(브리프 2.1, 기관실 노출은 고친 값 45).
export const START: Record<Comm, [number, number, number, number]> = {
  tail: [35, 40, 75, 60], engine: [80, 55, 40, 45], guard: [55, 55, 45, 55],
  medtech: [55, 50, 45, 25], front: [75, 65, 20, 10],
};
export const POP0: Record<Comm, number> = { tail: 90, engine: 25, guard: 25, medtech: 30, front: 30 };
export const REL0: Record<Comm, number> = { tail: -20, engine: 10, guard: 15, medtech: 5, front: 20 };
export const COH0: Record<Comm, number> = { tail: 0.55, engine: 0.85, guard: 0.8, medtech: 0.7, front: 0.65 };
// 이념: 배급(+1 균등/−1 기여), 권위(+1 규율/−1 실용), 기술(+1 복원/−1 적응)
export const IDEO: Record<Comm, [number, number, number]> = {
  tail: [1, -1, -1], engine: [-1, 1, 1], guard: [-1, 1, 0], medtech: [0, -1, 1], front: [-1, -1, 1],
};
// 들어주면 반대편이 화난다(원작). 칼질했을 때 기뻐하는 쪽이기도 하다.
export const OPPOSITE: Record<Comm, Comm> = { tail: 'front', front: 'tail', engine: 'medtech', medtech: 'engine', guard: 'tail' };

export const LEVER_NAMES = ['끊음', '낮음', '보통', '높음', '최대'] as const;

// ---- 관계 7단계(브리프 1.1) ----
export const STAGES = [
  { min: 70, name: '헌신', band: 2 }, { min: 40, name: '지지', band: 1 }, { min: 15, name: '호의', band: 1 },
  { min: -14, name: '중립', band: 0 }, { min: -39, name: '회의', band: -1 }, { min: -69, name: '반대', band: -1 },
  { min: -100, name: '적대', band: -2 },
] as const;

// ---- 법 18개(브리프 8.3) ----
export type Axes = [number, number, number];
export type Mats = Partial<Record<Comm, [number, number, number, number]>>;
export type LawId =
  | 'common_kitchen' | 'contribution_ration' | 'seed_grain' | 'common_heating' | 'heat_quota' | 'snow_duty'
  | 'child_labor' | 'corpse_throw' | 'corpse_store' | 'corpse_burn' | 'treat_all' | 'triage' | 'no_outsiders'
  | 'patrol' | 'secret_ballot' | 'emergency_powers' | 'strike_ban' | 'guided_voting'
  // S1c 법 다섯(s1a_politics_numbers 8.5). S1c를 켠 판에서만 열린다(domestic/laws.ts).
  | 'tech_control' | 'apprentice_duty' | 'triage_std' | 'bath_rota' | 'hands_first'
  // 기술이 여는 덜 잔혹한 변형(s1c_domestic 7.3): 원래 법과 하나만 설 수 있다(domestic/laws.ts).
  | 'seed_half' | 'child_pack';
export type Crisis = 'coal' | 'food' | 'corpse' | 'med';

export interface LawRes {
  rationFloor?: number; heatFloor?: number; tensionAdd?: number; foodAdd?: number; coalAdd?: number;
  foodOnce?: number; fearOnce?: number; fearAdd?: number; trustOnce?: number;
  heatMult?: number; haulMult?: number; medMult?: number; heal?: number; deathMult?: number;
  noRescue?: boolean; corpse?: 'throw' | 'store' | 'burn';
}

export interface LawDef {
  id: LawId;
  title: string;
  group: string;
  tag: '이상' | '가혹' | '싼 답' | '질서' | '표결' | '통치';
  kind: 'normal' | 'rule';
  axes: Axes;
  mats: Mats;
  rels: Partial<Record<Comm, number>>;
  like: Partial<Record<Comm, number>>;
  res: LawRes;
  crisis: Crisis[];
  /** 바뀌는 수치. 표결 전에 보여 준다(decisions.md 화면과 연출). */
  changes: string[];
  opensWhen: string;
}

const L = (def: Omit<LawDef, 'mats' | 'rels' | 'like' | 'res' | 'crisis'> & Partial<LawDef>): LawDef => ({
  mats: {}, rels: {}, like: {}, res: {}, crisis: [], ...def,
});

export const LAWS: Record<LawId, LawDef> = {
  common_kitchen: L({
    id: 'common_kitchen', title: '공동 식당', group: '식량', tag: '이상', kind: 'normal', axes: [1, 0, 0],
    like: { tail: 2, medtech: 1, guard: 1, engine: 1 }, rels: { tail: 10 }, res: { rationFloor: 3, tensionAdd: -1 },
    changes: ['모든 칸 배급 높음 아래로 못 내림', '긴장 −1/구간', '꼬리칸 관계 +10'], opensWhen: '처음부터',
  }),
  contribution_ration: L({
    id: 'contribution_ration', title: '기여 배급', group: '식량', tag: '가혹', kind: 'normal', axes: [-1, 0, 0],
    mats: { engine: [0, 10, 0, 0], guard: [0, 10, 0, 0], tail: [0, -5, 0, 0], front: [0, -10, 0, 0], medtech: [0, -5, 0, 0] },
    res: { foodAdd: -1.5 }, crisis: ['food'],
    changes: ['식량 +1.5/구간 절약', '기관실·경비대 배급 +10', '앞칸 배급 −10', '꼬리칸·의무진 배급 −5'], opensWhen: '처음부터',
  }),
  seed_grain: L({
    id: 'seed_grain', title: '종자곡 풀기', group: '식량', tag: '가혹', kind: 'normal', axes: [0, -1, -1],
    rels: { front: -20, engine: -5, medtech: -5 }, like: { tail: 1 }, res: { foodOnce: 30 }, crisis: ['food'],
    changes: ['식량 +30(한 번)', '앞칸 관계 −20', '기관실·의무진 관계 −5', '해빙기에 심을 씨앗이 없다'], opensWhen: '식량 50 이하',
  }),
  common_heating: L({
    id: 'common_heating', title: '공동 난방', group: '추위', tag: '이상', kind: 'normal', axes: [1, 0, -1],
    like: { tail: 2, medtech: 1 }, rels: { tail: 10 }, res: { heatFloor: 3, tensionAdd: -1 },
    changes: ['모든 칸 난방 높음 아래로 못 내림', '긴장 −1/구간', '꼬리칸 관계 +10'], opensWhen: '꼬리칸 온기 40 이하',
  }),
  heat_quota: L({
    id: 'heat_quota', title: '난방 배당', group: '추위', tag: '가혹', kind: 'normal', axes: [-1, 1, 0],
    mats: { tail: [-10, 0, 0, 0], medtech: [-10, 0, 0, 0], guard: [-5, 0, 0, 0] }, res: { heatMult: 0.5 }, crisis: ['coal'],
    changes: ['난방 석탄 절반', '꼬리칸·의무진 온기 −10', '경비대 온기 −5'], opensWhen: '석탄 50 이하',
  }),
  snow_duty: L({
    id: 'snow_duty', title: '눈 녹이기 당번', group: '추위', tag: '가혹', kind: 'normal', axes: [1, 1, -1],
    mats: { tail: [-5, 0, 0, 5], front: [-5, 0, 0, 15], medtech: [-5, 0, 0, 5] }, res: { coalAdd: -1 }, crisis: ['coal'],
    changes: ['석탄 +1/구간 절약', '앞칸 노출 +15', '꼬리칸·의무진 노출 +5', '세 칸 온기 −5'], opensWhen: '처음부터',
  }),
  child_labor: L({
    id: 'child_labor', title: '아동 노동', group: '노동', tag: '가혹', kind: 'normal', axes: [-1, -1, 0],
    mats: { tail: [0, 0, 0, 10] }, rels: { tail: -5, medtech: -10 }, res: { haulMult: 1.2, fearOnce: 5 }, crisis: ['coal', 'food'],
    changes: ['정차 산출 +20%', '아이들은 열차 옆 승강장에서 짐만 받는다(필드 안엔 안 감)', '꼬리칸 노출 +10', '꼬리칸 관계 −5', '의무진 관계 −10', '공포 +5'], opensWhen: '석탄이나 식량 40 이하',
  }),
  corpse_throw: L({
    id: 'corpse_throw', title: '선로에 버리기', group: '시신', tag: '싼 답', kind: 'normal', axes: [0, -1, -1],
    res: { corpse: 'throw' }, crisis: ['corpse'],
    changes: ['지금 드는 것 없음', '던진 시신마다 정차 위험 +5%', '죽은 이가 무리에 섞여 돌아온다'], opensWhen: '첫 죽음 뒤',
  }),
  corpse_store: L({
    id: 'corpse_store', title: '냉동칸 안치', group: '시신', tag: '이상', kind: 'normal', axes: [1, 0, 1],
    like: { tail: 1, medtech: 1, front: 1 }, res: { corpse: 'store' }, crisis: ['corpse'],
    changes: ['시신마다 꼬리칸 과밀 +1', '쌓일수록 녹아 일어나는 사고'], opensWhen: '첫 죽음 뒤',
  }),
  corpse_burn: L({
    // 화장은 화실이 아니라 정차 때 선로 옆 장작불에서 한다(2026-10-07 사용자 카드 답). 석탄을 얻지 않고 쓰며,
    // 다음 정차까지 시신을 지켜야 한다. 숫자는 제안.
    id: 'corpse_burn', title: '정차 때 장작불', group: '시신', tag: '가혹', kind: 'normal', axes: [0, 1, 1],
    rels: { medtech: -5, front: -5 }, like: { guard: 1 }, res: { corpse: 'burn' }, crisis: ['corpse'],
    changes: ['다음에 내리는 정차에서 선로 옆에서 태운다', '시신마다 석탄 −1(불쏘시개)', '그때까지 냉동칸에 둔다. 6구가 넘으면 살던 칸에 둬서 과밀 +2', '태우는 정차는 불빛에 위험이 조금 커진다', '의무진·앞칸 관계 −5'], opensWhen: '첫 죽음 뒤',
  }),
  treat_all: L({
    id: 'treat_all', title: '모두를 치료', group: '의료', tag: '이상', kind: 'normal', axes: [1, 0, 1],
    like: { tail: 1, medtech: 1, guard: 1, front: 1, engine: 1 }, res: { medMult: 1.6, heal: 0.7 },
    changes: ['부상 회복 40% → 70%', '의약품 소모 ×1.6'], opensWhen: '처음부터',
  }),
  triage: L({
    id: 'triage', title: '중환자 분류', group: '의료', tag: '가혹', kind: 'normal', axes: [0, -1, -1],
    rels: { medtech: -15, tail: -5 }, res: { medMult: 0.6, trustOnce: -5 }, crisis: ['med'],
    changes: ['의약품 소모 ×0.6', '신임 −5', '의무진 관계 −15', '꼬리칸 관계 −5'], opensWhen: '의약품 5 이하나 부상자 6명 이상',
  }),
  no_outsiders: L({
    id: 'no_outsiders', title: '외부인 받지 않기', group: '의료', tag: '가혹', kind: 'normal', axes: [0, 1, -1],
    rels: { medtech: -10, tail: -10 }, res: { noRescue: true, trustOnce: -5 },
    changes: ['생존자를 데려오지 않는다', '신임 −5', '의무진·꼬리칸 관계 −10'], opensWhen: '꼬리칸 과밀 75 이상',
  }),
  patrol: L({
    id: 'patrol', title: '순찰과 귀환 검사', group: '질서', tag: '질서', kind: 'normal', axes: [0, 1, 0],
    rels: { tail: -5 }, res: { tensionAdd: -1, fearAdd: 2, foodAdd: 0.5, deathMult: 0.8 },
    changes: ['긴장 −1/구간', '공포 +2/구간', '식량 −0.5/구간', '정차 사망 ×0.8', '꼬리칸 관계 −5'], opensWhen: '긴장 40 이상',
  }),
  secret_ballot: L({
    id: 'secret_ballot', title: '비밀 투표', group: '표결', tag: '표결', kind: 'normal', axes: [0, -1, 0],
    changes: ['찬성·반대·미정이 안 보인다', '산 표를 확인할 수 없다', '공개 투표의 공포가 멈춘다'], opensWhen: '처음부터',
  }),
  emergency_powers: L({
    id: 'emergency_powers', title: '비상대권', group: '통치', tag: '통치', kind: 'rule', axes: [0, 1, 0],
    changes: ['3구간 동안 구간마다 포고 하나(표결 없음)', '포고마다 긴장 +5, 싫어하는 칸 관계 −3', '끝나면 포고는 추인받아야 남는다'], opensWhen: '긴장 50 이상이나 신임 10 이하',
  }),
  strike_ban: L({
    id: 'strike_ban', title: '파업 금지', group: '통치', tag: '통치', kind: 'rule', axes: [0, 1, 0],
    rels: { engine: -30 }, changes: ['기관실이 파업하지 못한다', '기관실 관계 −30'], opensWhen: '파업을 한 번 겪은 뒤',
  }),
  guided_voting: L({
    id: 'guided_voting', title: '유도 투표', group: '통치', tag: '통치', kind: 'rule', axes: [0, 1, 0],
    changes: ['회기마다 미정 30%가 찬성으로', '회기마다 모든 관계 −3', '공포 +3', '3회기 뒤 끝난다'], opensWhen: '세 번째 회기부터',
  }),
  // ---- S1c 법(s1a_politics_numbers 8.5, s1c_domestic 9.1·16.4). 숫자는 제안. 효과는 domestic/*.ts가 lawActive로 읽는다. ----
  tech_control: L({
    id: 'tech_control', title: '기술 통제법', group: '지식', tag: '통치', kind: 'rule', axes: [0, 1, 1],
    like: { engine: 2, guard: 1, tail: -1, medtech: -1 }, rels: { engine: 15, guard: 5 },
    changes: ['견습생은 그 분야 전문가의 칸에서만', '기관실 관계 +15', '경비대 관계 +5', '견습 의무법이 닫힌다'], opensWhen: '다른 칸 견습생이 처음 붙은 뒤',
  }),
  apprentice_duty: L({
    id: 'apprentice_duty', title: '견습 의무', group: '지식', tag: '이상', kind: 'normal', axes: [1, -1, 0],
    like: { tail: 2, medtech: 1, engine: -2 },
    changes: ['분야마다 견습생 하나는 다른 칸에서', '전문가가 늘 가르쳐 모든 기술 ×0.9', '기술 통제법이 닫힌다'], opensWhen: '대체 불가 요구가 처음 온 뒤',
  }),
  triage_std: L({
    id: 'triage_std', title: '중환자 분류(기준)', group: '의료', tag: '가혹', kind: 'normal', axes: [0, -1, 0],
    like: { front: 1, medtech: 1, tail: -1 }, rels: { medtech: -5 }, res: { medMult: 0.75, trustOnce: -2 }, crisis: ['med'],
    changes: ['의약품 소모 ×0.75', '신임 −2', '의무진 관계 −5', '중환자 분류 대신 오른다'], opensWhen: '환자 분류 기준을 복원한 뒤',
  }),
  bath_rota: L({
    id: 'bath_rota', title: '더운물 고루 나누기', group: '위생', tag: '이상', kind: 'normal', axes: [1, 0, 0],
    like: { tail: 2, medtech: 1, front: -1 },
    changes: ['모든 칸이 같은 더운물 몫', '순번 돌리는 데 석탄 +0.25/구간', '더운물 석탄 ×1.2', '일하는 손 먼저가 닫힌다'], opensWhen: '판 시작부터',
  }),
  hands_first: L({
    id: 'hands_first', title: '일하는 손 먼저', group: '위생', tag: '가혹', kind: 'normal', axes: [-1, 0, 0],
    like: { engine: 1, guard: 1, tail: -1, front: -1 },
    changes: ['기관실·경비대·파견 칸 더운물 +1', '꼬리칸·앞칸 더운물 −1', '더운물 석탄 ×0.8', '더운물 고루 나누기가 닫힌다'], opensWhen: '판 시작부터',
  }),
  // 7.3 M3 가(훈제·염장): 종자곡 풀기의 변형. 남긴 씨앗은 훈제해 둔다. 숫자는 내정 스레드 제안.
  seed_half: L({
    id: 'seed_half', title: '종자곡 반만 풀기', group: '식량', tag: '가혹', kind: 'normal', axes: [0, -1, -1],
    rels: { front: -10, engine: -2, medtech: -2 }, like: { tail: 1 }, res: { foodOnce: 15 }, crisis: ['food'],
    changes: ['식량 +15(한 번)', '앞칸 관계 −10', '기관실·의무진 관계 −2', '남긴 씨앗은 훈제해 둔다', '종자곡 풀기가 닫힌다'],
    opensWhen: '훈제·염장을 복원한 뒤, 식량 50 이하',
  }),
  // 7.3 X1(짐 꾸리기·방한 장비): 아동 노동의 변형. 아이들은 내리지 않고 열차 안에서 짐을 꾸린다.
  child_pack: L({
    id: 'child_pack', title: '아동 노동(짐 꾸리기만)', group: '노동', tag: '가혹', kind: 'normal', axes: [-1, -1, 0],
    rels: { tail: -5, medtech: -5 }, res: { haulMult: 1.1, fearOnce: 2 }, crisis: ['coal', 'food'],
    changes: ['정차 산출 +10%', '아이들은 내리지 않고 열차 안에서 짐을 꾸린다', '꼬리칸 관계 −5', '의무진 관계 −5', '공포 +2', '아동 노동이 닫힌다'],
    opensWhen: '짐 꾸리기·방한 장비를 복원한 뒤, 석탄이나 식량 40 이하',
  }),
};
/** S1c 법. S1a 판에선 열리지 않는다. */
export const S1C_LAWS: LawId[] = ['tech_control', 'apprentice_duty', 'triage_std', 'bath_rota', 'hands_first', 'seed_half', 'child_pack'];
/** 변형 법 → 원래 법. 1회 효과는 둘을 합쳐 판에 한 번이다(R3 카드 1). */
export const LAW_VARIANT_OF: Partial<Record<LawId, LawId>> = { seed_half: 'seed_grain', child_pack: 'child_labor', triage_std: 'triage' };
export const LAW_IDS = Object.keys(LAWS) as LawId[];
export const CORPSE_LAWS: LawId[] = ['corpse_throw', 'corpse_store', 'corpse_burn'];

// ---- 장소(ref/places_loot_draft.json의 가중치) ----
export const LOOT_KEYS = ['coal', 'food', 'medicine', 'luxury', 'symbol', 'secret'] as const;
export type LootKey = typeof LOOT_KEYS[number];
export const LOOT_NAME: Record<LootKey, string> = {
  coal: '석탄', food: '식량', medicine: '의약품', luxury: '사치품', symbol: '상징물', secret: '정보',
};
export interface PlaceDef { id: string; name: string; risk: number; loot: Record<LootKey, number> }
export const PLACES: PlaceDef[] = [
  { id: 'freight', name: '화물역', risk: 3, loot: { coal: 40, food: 25, medicine: 5, luxury: 5, symbol: 10, secret: 15 } },
  { id: 'houses', name: '주택가', risk: 2, loot: { coal: 5, food: 35, medicine: 10, luxury: 20, symbol: 20, secret: 10 } },
  { id: 'hospital', name: '병원', risk: 3, loot: { coal: 0, food: 10, medicine: 55, luxury: 0, symbol: 10, secret: 25 } },
  { id: 'factory', name: '공장', risk: 3, loot: { coal: 50, food: 10, medicine: 5, luxury: 5, symbol: 15, secret: 15 } },
  { id: 'church', name: '교회', risk: 2, loot: { coal: 0, food: 10, medicine: 0, luxury: 10, symbol: 60, secret: 20 } },
  { id: 'office', name: '관청', risk: 2, loot: { coal: 0, food: 5, medicine: 0, luxury: 10, symbol: 25, secret: 60 } },
];

/** 정찰조가 당한 자리(파밍 스레드 17:16 제안). 위험이 장소 안쪽 한 자리에 묶여 있다고 읽히게 해서,
 * 짧게·적게 보내면 그 자리를 비켜 간다는 '이 준비라면' 해석과 맞물린다. 숫자는 안 바꾼다. */
export const SCOUT_DEEP: Record<string, string> = {
  freight: '화물 창고 맨 안쪽',
  houses: '골목 끝 집 지하실',
  hospital: '병동 안쪽 복도 끝',
  factory: '공장 안쪽 보일러실',
  church: '교회 뒤 사제관 안쪽',
  office: '관청 문서고 안쪽',
};

export const STAY = {
  short: { name: '짧게', mult: 0.6, risk: 0.6, coal: 1 },
  normal: { name: '보통', mult: 1, risk: 1, coal: 2 },
  long: { name: '길게', mult: 1.4, risk: 1.5, coal: 3 },
} as const;
export type StayId = keyof typeof STAY;

// ---- 성향(브리프 3.3) ----
export const TRAITS = ['greed', 'ideal', 'family', 'fear', 'ambition'] as const;
export type Trait = typeof TRAITS[number];
export const TRAIT_NAME: Record<Trait, string> = { greed: '탐욕', ideal: '이상주의', family: '가족', fear: '겁', ambition: '야심' };
export const BRIBE_EXPOSE: Record<Trait, number> = { greed: 0.1, ideal: 1, family: 0.2, fear: 0.3, ambition: 0.15 };
export const TRAIT_BAN: Partial<Record<Comm, Trait>> = { engine: 'greed', front: 'ideal' };
export const REP_ROLE: Record<Comm, string> = {
  tail: '꼬리칸 대표', medtech: '의무장', guard: '경비대장', front: '앞칸 대표', engine: '수석 기관사',
};
export const REP_AGE: Record<Comm, [number, number]> = {
  tail: [30, 55], medtech: [40, 65], guard: [35, 55], front: [45, 70], engine: [60, 75],
};

// ---- 비밀 풀(브리프 7장) ----
export const SECRET_POOL: { text: string; weight: 1 | 2 | 3 }[] = [
  { text: '배급을 몰래 더 받는다', weight: 1 }, { text: '붕괴 전 직업을 속였다', weight: 1 },
  { text: '앞칸 사람에게 빚이 있다', weight: 1 }, { text: '몰래 술을 숨겨 둔다', weight: 1 },
  { text: '파견에서 주운 것을 다 내놓지 않았다', weight: 1 }, { text: '엔진 신앙을 믿는 척만 한다', weight: 1 },
  { text: '사치품을 빼돌린다', weight: 2 }, { text: '다른 지도자와 몰래 거래했다', weight: 2 },
  { text: '가족을 앞칸으로 몰래 옮겼다', weight: 2 }, { text: '의약품을 사적으로 썼다', weight: 2 },
  { text: '지난 회기 표를 팔았다', weight: 2 }, { text: '보일러 점검을 건너뛰었다', weight: 2 },
  // 숨긴 물림은 2구간이면 끝나서 오래가는 비밀이 못 된다. 그 자리에 오래가는 비밀 둘(body_injury 4.4).
  { text: '물린 가족을 숨겨 줬다가 몰래 처리했다', weight: 3 }, { text: '예전 정차에서 사람을 버리고 왔다', weight: 3 },
  { text: '필드에서 긁혔는데 검사를 피했다', weight: 2 },
  { text: '외부와 몰래 무전을 한다', weight: 3 }, { text: '첫 겨울에 사람을 죽였다', weight: 3 },
];

// ---- 공개 협상 조건(브리프 3.2) ----
export type ConditionKind =
  | 'heat' | 'ration' | 'relocate' | 'skip_dispatch' | 'front_levy' | 'shift' | 'target' | 'give_med' | 'give_lux'
  | 'keep_ration' | 'agenda' | 'cut'
  // S1c 조건 둘(s1a_politics_numbers 3.2, s1c_domestic 9.2)
  | 'apprentice_pick' | 'research_pick';
export interface ConditionDef {
  kind: ConditionKind; label: string; /** 지금 바로 치르는 조건인가 */ now: boolean; target?: LootKey; amount?: number;
  /** S1c를 켠 판에서만 내건다 */ s1c?: boolean;
}
export const CONDITIONS: Record<Comm, ConditionDef[]> = {
  tail: [
    { kind: 'heat', label: '꼬리칸 난방 +1', now: false },
    { kind: 'ration', label: '꼬리칸 배급 +1', now: false },
    { kind: 'relocate', label: '칸 재배치(과밀 −15)', now: true },
    { kind: 'skip_dispatch', label: '다음 파견에서 제외', now: false },
    { kind: 'front_levy', label: '앞칸 사치품 3 공출', now: true },
  ],
  engine: [
    { kind: 'ration', label: '기관실 배급 +1', now: false },
    { kind: 'shift', label: '화부 교대 늘리기', now: true },
    { kind: 'target', label: '다음 정차는 석탄', now: false, target: 'coal' },
    { kind: 'apprentice_pick', label: '견습생 선발권', now: false, s1c: true },
  ],
  guard: [
    { kind: 'give_med', label: '장비: 의약품 3', now: false, amount: 3 },
    { kind: 'ration', label: '경비대 배급 +1', now: false },
    { kind: 'target', label: '다음 정차는 식량', now: false, target: 'food' },
  ],
  medtech: [
    { kind: 'give_med', label: '의약품 5', now: false, amount: 5 },
    { kind: 'heat', label: '의무칸 난방 +1', now: false },
    { kind: 'target', label: '다음 정차는 의약품', now: false, target: 'medicine' },
    { kind: 'research_pick', label: '연구 우선권', now: false, s1c: true },
  ],
  front: [
    { kind: 'give_lux', label: '사치품 3', now: false, amount: 3 },
    { kind: 'keep_ration', label: '앞칸 배급 유지', now: false },
    { kind: 'target', label: '다음 정차는 사치품', now: false, target: 'luxury' },
  ],
};
export const COMMON_CONDITIONS: ConditionDef[] = [
  { kind: 'agenda', label: '다음 안건 선택권', now: true },
  { kind: 'cut', label: '다른 칸 하나 칼질', now: true },
];

// 현장 조달: 다음 정차에서 이걸 가져오면(브리프 3.1)
export const FETCH_WANT: Record<Comm, { target: LootKey; amount: number; label: string }> = {
  tail: { target: 'food', amount: 10, label: '식량 10' },
  medtech: { target: 'medicine', amount: 6, label: '의약품 6' },
  guard: { target: 'symbol', amount: 1, label: '상징물 하나' },
  front: { target: 'luxury', amount: 2, label: '사치품 2' },
  engine: { target: 'coal', amount: 12, label: '석탄 12' },
};

// 공동체 고유 행동(브리프 3.6, 호의 이상)
export const UNIQUE_ACTION: Record<Comm, string> = {
  tail: '눈 녹이기 자원(석탄 +3)', engine: '무리한 운행(이번 구간 석탄 −2)', guard: '정차 호위(부상 절반)',
  medtech: '응급 치료(부상자 2명)', front: '사치품 헌납(+2)',
};

// 항의(브리프 1.6)
export const PROTEST: Record<Comm, string> = {
  engine: '파업', tail: '작업 거부', guard: '경계 거부', medtech: '진료 거부', front: '거래 거부',
};
