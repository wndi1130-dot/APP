// Builds the Gemini request for one empty text field. Pure: no I/O, no network, no secrets.
// The fixed instruction condenses docs/prototype/s1_content_guide.md chapter 2; examples come only from 3.2.
import type { Profile } from './gen_profiles.ts';

export const PROMPT_VERSION = 'profile-line-v1';
export const PROFILE_LINE_MAX = 40;

const COMMUNITY_LABELS: Record<Profile['community'], string> = {
  tail: '꼬리칸', front: '앞칸', medtech: '기술·의무진', guard: '경비대', engine: '기관실',
};
const BOARDING_LABELS: Record<Profile['boarding'], string> = {
  depot: '볼슈틴 차고에서 탔다(기관사·차고 사람)',
  bought: '물건이나 권력을 내고 탔다',
  force: '경찰·군 잔존 병력으로 탔다',
  rescue: '구조되어 탔다',
  refugee: '나중에 태운 피난민이다',
  born: '열차에서 태어났다',
};

const STYLE_RULES = [
  '너는 붕괴 후 여섯 번째 겨울, 중부 유럽을 달리는 증기 열차 사회를 그리는 게임의 글을 쓴다.',
  '',
  '[문체]',
  '- 한국어로 짧고 구체적으로 쓴다. 감정을 설명하지 말고 사물과 행동으로 보여준다. "춥다" 대신 "숨이 하얗게 얼었다".',
  '- 이 세계는 차갑고 건조하다. 영웅적인 말투나 희망찬 구호를 쓰지 않는다.',
  '- 단위는 미터법과 섭씨를 쓴다.',
  '- 성향을 가리키는 단어(탐욕스러운, 겁쟁이, 야심가, 이상주의자 같은 말)를 쓰지 않는다. 성향은 행동으로만 드러난다.',
  '',
  '[세계관의 금기]',
  '- 추위와 감염의 원인을 단정하지 않는다.',
  "- '좀비'라는 말을 쓰지 않는다. 이 세계에서는 '망자', '그것들'이라고 부른다.",
  '- 도덕 점수나 선악 수치를 문장에 드러내지 않는다.',
  '',
  '[쓰지 않는 것]',
  '- 실제 총기 제조사와 모델명. 일반 명칭과 별명만 쓴다.',
  '- 강제 이송 열차를 흉내 내는 표현과 장면: 사람을 화물칸에 싣기, 줄 세워 가르는 선별 장면, 수용소 어휘.',
  '- 국적이나 민족을 집단의 성격으로 쓰는 것.',
  '- 유명 실존 인물, 실제 정당과 단체의 이름.',
  '- 신체 훼손의 직접 묘사.',
  '- 상투어: "희망의 불씨", "운명의 수레바퀴", "모든 것이 변했다" 같은 말.',
].join('\n');

const PROFILE_LINE_TASK = [
  '[이번에 쓸 것: 프로필 한 줄]',
  `- 한 문장, ${PROFILE_LINE_MAX}자 이내(공백 포함), 줄바꿈 없이 쓴다.`,
  '- 3인칭 현재형 서술로, 그 사람이 다루는 물건이나 몸에 밴 습관 하나를 보여준다.',
  '- 주어진 이름, 나이, 공동체, 고향, 탄 경위, 좋아하는 것, 싫어하는 것만 근거로 삼는다. 성향, 비밀, 관계, 과거 사건을 지어내지 않는다.',
  '- 이름과 나이를 문장에 되풀이하지 않는다.',
  '',
  '[출력]',
  '- JSON 하나만 낸다: {"line": "..."}. 설명 문장이나 코드 블록 표시 없이.',
].join('\n');

// Content guide 3.2, verbatim in substance. These are our own characters, not quotes from other works.
const GUIDE_EXAMPLES = [
  '[예시: 콘텐츠 가이드 3.2]',
  '수석 기관사: 헨리크 마주레크(Henryk Mazurek), 67세, 볼슈틴 출신, 기관실 대표. 붕괴 전 볼슈틴 차고의 자원봉사 기관사로, 첫 겨울에 박물관 기관차에 불을 넣은 사람 중 하나다. 좋아하는 것: 석탄 타는 냄새. 싫어하는 것: 기관차를 \'물건\'이라 부르는 사람. 말투 예: "압력 12. 더 올리면 할멈이 운다."',
  '꼬리칸 대표: 파블라 크레이치(Pavla Krejčí), 41세, 브르노 출신, 꼬리칸 대표. 세 번째 겨울에 태운 피난민. 좋아하는 것: 라디오 잡음 사이로 새어 나오는 음악. 싫어하는 것: 앞칸 창에 걸린 커튼. 말투 예: "우리 칸 난로는 이틀째 꺼져 있어요. 회의는 따뜻한 데서 하시죠?"',
].join('\n');

export interface TextRequest {
  id: string;
  field: 'line';
  promptVersion: string;
  system: string;
  user: string;
}

/** Only the fields the guide (3.5) allows the writer to see. */
export function profileFacts(profile: Profile): Record<string, string | number> {
  return {
    이름: profile.name,
    나이: profile.age,
    공동체: COMMUNITY_LABELS[profile.community],
    고향: profile.hometown,
    탄_경위: BOARDING_LABELS[profile.boarding],
    좋아하는_것: profile.like,
    싫어하는_것: profile.dislike,
  };
}

export function buildProfileLineRequest(profile: Profile, rejections: readonly string[] = []): TextRequest {
  const parts = [
    GUIDE_EXAMPLES,
    '',
    '[이번 항목]',
    JSON.stringify(profileFacts(profile), null, 2),
  ];
  if (rejections.length) {
    parts.push('', '[이전 답이 거절된 이유]', ...rejections.map((reason) => `- ${reason}`), '규칙을 지켜 다시 써라.');
  }
  parts.push('', '[출력 형식]', `{"line": "${PROFILE_LINE_MAX}자 이내 한 문장"}`);
  return {
    id: profile.id,
    field: 'line',
    promptVersion: PROMPT_VERSION,
    system: `${STYLE_RULES}\n\n${PROFILE_LINE_TASK}`,
    user: parts.join('\n'),
  };
}
