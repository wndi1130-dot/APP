import type { Game, StopState } from './state';

// 정차 조짐(2026-10-07 사용자): 위험을 꼬리표로 적지 않고, 정찰조가 본 조짐과 그 해석으로 알린다.
// "입가에 피를 묻힌 까마귀들이 날아간다. 매우 불길하다." 조짐 문장은 장소와 날씨마다 다르고 한 판 안에서 되도록 다시 안 나온다.
// 금지선: 사람이나 무리가 화차·닫힌 칸 안에 갇힌 장면은 쓰지 않는다(강제 이송 열차로 읽힌다). 화차는 빈 풍경으로만.
// 해석 말(매우 불길하다 / 불길하다 / …)은 일부러 고정한다. 플레이어가 약속을 읽는 말이라 매번 바뀌면 못 읽는다.

export type Weather = 'snow' | 'fog' | 'sleet' | 'overcast' | 'clear';
/** 바깥 기척. 정차마다 정해지고 준비를 바꿔도 안 바뀐다. many 무리가 많다, some 보통, few 거의 없다. */
export type SignTier = 'many' | 'some' | 'few';

export const WEATHER_NAME: Record<Weather, string> = { snow: '눈', fog: '안개', sleet: '진눈깨비', overcast: '흐림', clear: '맑은 추위' };
/** 어둡고 칙칙한 날이 8할(아트 방향). 갠 날은 드물다. */
const WEATHER_WEIGHT: [Weather, number][] = [['snow', 30], ['fog', 20], ['sleet', 15], ['overcast', 20], ['clear', 15]];

/** 열차 창으로 보이는 날씨. 위험은 알려 주지 않는다. */
export const WEATHER_LOOK: Record<Weather, string[]> = {
  snow: ['눈이 쉬지 않고 내린다.', '함박눈이 플랫폼을 덮어 간다.', '눈보라가 창에 들러붙는다.', '가는 눈이 비스듬히 날린다.', '눈이 그쳤다가 다시 내린다.'],
  fog: ['안개가 짙다. 역사 지붕이 겨우 보인다.', '안개가 선로를 따라 낮게 깔렸다.', '안개 때문에 스무 걸음 앞이 흐리다.', '젖은 안개가 창에 맺힌다.', '안개 사이로 전신주만 줄지어 보인다.'],
  sleet: ['진눈깨비가 창을 때린다.', '진눈깨비가 내린다. 옷이 금세 젖겠다.', '젖은 눈이 선로 위에서 녹았다 언다.', '처마마다 진눈깨비 물이 떨어진다.', '진눈깨비에 플랫폼이 번들거린다.'],
  overcast: ['하늘이 낮고 잿빛이다.', '구름이 두껍다. 한낮인데 어둑하다.', '바람이 구름을 낮게 몰고 간다.', '흐린 빛에 모든 것이 납빛이다.', '해가 구름 뒤에서 희미하게 비친다.'],
  clear: ['오랜만에 하늘이 갰다. 추위가 살을 벤다.', '볕은 드는데 숨이 얼 만큼 춥다.', '하늘이 맑다. 눈밭이 눈부시다.', '맑은 하늘 아래 성에가 반짝인다.', '바람 한 점 없이 쨍하게 춥다.'],
};

/** 열차 창으로 보이는 장소 겉모습. 위험은 알려 주지 않는다. */
export const PLACE_LOOK: Record<string, string[]> = {
  freight: ['녹슨 화차들이 줄지어 서 있다.', '기중기가 팔을 늘어뜨린 채 멈춰 있다.', '창고 지붕 절반이 내려앉았다.'],
  houses: ['선로 옆으로 낮은 집들이 이어진다.', '집집마다 덧창이 닫혀 있다.', '골목마다 버려진 손수레가 서 있다.'],
  hospital: ['붉은 벽돌 병원이 선로 너머에 서 있다.', '병원 창 절반이 판자로 막혀 있다.', '구급차 한 대가 정문 앞에 비스듬히 서 있다.'],
  factory: ['공장 굴뚝이 식은 채 서 있다.', '저탄장의 검은 더미가 눈을 이고 있다.', '공장 담이 선로를 따라 길게 이어진다.'],
  church: ['역 너머로 교회 종탑이 보인다.', '작은 교회 지붕에 눈이 두껍게 앉았다.', '교회 묘지 울타리가 반쯤 쓰러져 있다.'],
  office: ['광장 건너 관청 건물이 서 있다.', '관청 정문에 모래주머니가 쌓여 있다.', '관청 시계탑 바늘이 멈춰 있다.'],
};

/** 정찰조가 본 조짐(장소별). 무리가 많은지 없는지를 간접으로 드러낸다. */
export const PLACE_OMENS: Record<string, Record<SignTier, string[]>> = {
  freight: {
    many: ['입가에 피를 묻힌 까마귀 떼가 창고 지붕에서 날아오른다.', '창고 철문이 안에서 두드려진다. 한둘이 아니다.', '플랫폼 눈이 붉게 얼룩졌다. 끌린 자국이 창고로 이어진다.'],
    some: ['창고 문 하나가 바람도 없는데 삐걱인다.', '선로 사이에 언 발자국이 몇 줄 있다. 며칠 됐다.', '기중기 밑 눈 더미에서 무언가 긁는 소리가 났다.'],
    few: ['쥐 죽은 듯 고요하다. 화차 위 눈이 고르게 쌓였다.', '까마귀들이 선로에 앉아 졸고 있다.', '창고 문마다 눈이 무릎까지 쌓였다. 드나든 자국이 없다.'],
  },
  houses: {
    many: ['골목 끝에서 개들이 짖다가 한꺼번에 뚝 그친다.', '깨진 유리가 전부 바깥에 흩어져 있다. 안에서 나왔다.', '눈 덮인 마당에 신발 한 짝과 긴 핏자국이 있다.'],
    some: ['굴뚝 하나에서 연기가 가늘게 오르다 끊긴다.', '담장 너머에서 무언가 쓰러지는 소리가 한 번 난다.', '대문마다 분필 숫자가 있다. 누가 먼저 뒤졌다.'],
    few: ['빨랫줄에 언 옷이 그대로 걸려 있다. 바람 소리뿐이다.', '고양이가 지붕에서 볕을 쬔다. 쫓기는 기색이 없다.', '골목 눈 위에 새 발자국만 찍혀 있다.'],
  },
  hospital: {
    many: ['응급실 유리문 안쪽에 손바닥 자국이 겹겹이 찍혀 있다.', '위층 복도에서 무언가 끌리는 소리가 멈추지 않는다.', '주차장 까마귀들이 무언가를 두고 다투다 일제히 날아오른다.'],
    some: ['병동 창 하나에 커튼이 흔들린다. 창은 닫혀 있다.', '약품 상자가 계단에 쏟아져 있다. 누가 급히 나갔다.', '지하로 가는 문틈에서 들척지근한 냄새가 샌다.'],
    few: ['접수대에 눈이 들이쳐 쌓였다. 발자국 하나 없다.', '복도가 고요하다. 물 떨어지는 소리뿐이다.', '비둘기들이 병원 처마에 줄지어 앉아 있다.'],
  },
  factory: {
    many: ['굴뚝 꼭대기 까마귀 떼가 공장 안을 내려다보며 운다.', '철문이 안쪽에서 밀려 바깥으로 휘어 있다.', '작업장 안에서 쇠 긁는 소리가 여럿 겹쳐 들린다.'],
    some: ['기계 사이로 그림자 하나가 지나갔다. 다시 안 보인다.', '담 밑 눈이 사람 모양으로 꺼져 있다.', '저탄장 더미에 누가 파헤친 자국이 있다.'],
    few: ['쥐들이 저탄장을 태연히 가로지른다.', '기계마다 성에가 하얗게 앉았다. 손댄 흔적이 없다.', '공장 마당이 텅 비었다. 양철판만 바람에 덜컹인다.'],
  },
  church: {
    many: ['종탑 까마귀들이 부리에 붉은 것을 물고 날아간다.', '예배당 앞마당에 핏자국이 길게 끌려 있다.', '앞마당 눈이 진창이 됐다. 발자국이 전부 안으로 향한다.'],
    some: ['종이 한 번 울린다. 바람은 그만큼 세지 않다.', '의자들이 문 앞에 쌓여 있다. 누가 막으려 했다.', '촛농이 아직 무르다. 누가 다녀간 지 얼마 안 됐다.'],
    few: ['종탑 아래 비둘기들이 꼼짝 않고 앉아 있다.', '예배당 안이 고요하다. 깨진 창으로 눈만 날린다.', '묘지 울타리 너머까지 눈이 고르게 덮였다.'],
  },
  office: {
    many: ['관청 계단에 흩어진 서류가 핏물에 얼어붙어 있다.', '위층 창마다 그림자가 서 있다. 움직이지 않는다.', '정문 바리케이드가 안쪽에서 무너져 있다.'],
    some: ['복도 끝 문이 바람에 열렸다 닫혔다 한다.', '서류함이 모두 열려 있다. 누가 무엇을 찾았다.', '지하 기록실 쪽에서 물건 떨어지는 소리가 한 번 난다.'],
    few: ['멈춘 시계탑에 눈이 쌓였다. 아무 기척이 없다.', '관청 계단에 참새들이 내려앉아 부스러기를 쫀다.', '정문 눈 위에 발자국이 없다. 쥐 죽은 듯 고요하다.'],
  },
};

/** 정찰조가 본 조짐(날씨별). 장소 조짐과 섞어 같은 장소라도 날마다 달리 보이게 한다. */
export const WEATHER_OMENS: Record<Weather, Record<SignTier, string[]>> = {
  snow: {
    many: ['새로 내린 눈 위에 맨발 자국이 어지럽다.', '눈발 속에서 비틀거리는 그림자가 여럿 지나간다.'],
    some: ['눈이 발자국을 반쯤 덮었다. 어제 것이다.', '먼 눈발 속에 그림자 하나가 서 있다.'],
    few: ['밤새 내린 눈이 고르다. 아무것도 지나가지 않았다.', '눈 밟는 소리 하나 없다.'],
  },
  fog: {
    many: ['안개 속 사방에서 이 가는 소리가 난다.', '안개 너머에서 썩은 내가 바람을 거슬러 온다.'],
    some: ['안개 속에 사람 같은 것이 섰다가 사라진다.', '안개 너머에서 발 끄는 소리가 한 번 난다.'],
    few: ['안개 속에서 까마귀 우는 소리만 한가롭다.', '안개가 깔렸지만 소리 하나 없이 고요하다.'],
  },
  sleet: {
    many: ['진눈깨비에 젖은 핏자국이 선로 옆으로 길게 번졌다.', '빗소리 사이로 낮은 신음이 여기저기서 난다.'],
    some: ['진눈깨비가 소리를 덮는다. 가까이 와야 들린다.', '젖은 눈 위에 발자국 하나가 끌린 듯 이어진다.'],
    few: ['진눈깨비만 추적추적 내린다. 다른 소리는 없다.', '처마 밑 고양이가 젖은 털을 핥고 있다.'],
  },
  overcast: {
    many: ['낮은 구름 아래로 까마귀 떼가 한곳을 맴돈다.', '바람이 바뀌자 썩은 내가 확 끼친다.'],
    some: ['바람이 멎자 어디선가 낮은 신음이 한 번 들린다.', '까마귀 몇 마리가 지붕 하나를 떠나지 않는다.'],
    few: ['바람도 없이 쥐 죽은 듯 고요하다.', '들개 한 마리가 느긋하게 선로를 건너간다.'],
  },
  clear: {
    many: ['맑은 하늘에 까마귀 떼가 새까맣게 한곳을 맴돈다.', '눈 위 핏자국이 볕에 선명하다. 아직 얼지 않았다.'],
    some: ['쨍한 추위에 먼 데 문 닫히는 소리가 또렷하다.', '눈부신 눈밭 너머로 무언가 움직였다.'],
    few: ['볕이 쨍하고 바람이 없다. 새소리만 들린다.', '맑은 하늘 아래 눈밭이 고요하다.'],
  },
};

/** 해석 말. 준비(얼마나·몇 명·호위)에 따라 바뀌고, 이 말이 약속이다. */
export type RiskLevel = 'dead' | 'hurt' | 'light' | 'calm';
export const VERDICT: Record<RiskLevel, string> = {
  dead: '매우 불길하다.',
  hurt: '불길하다.',
  light: '긁히는 정도로 끝날 것 같다.',
  calm: '괜찮을 것 같다.',
};
const RANK: Record<RiskLevel, number> = { calm: 0, light: 1, hurt: 2, dead: 3 };
/** 조짐이 보통 가리키는 해석 범위. 준비가 이 범위를 벗어나게 하면 '이 준비로는/이 준비라면'을 붙여 조짐과 해석이 어긋나 보이지 않게 한다. */
const SIGN_RANGE: Record<SignTier, [number, number]> = { few: [0, 1], some: [1, 2], many: [2, 3] };

export function verdictText(level: RiskLevel, sign: SignTier): string {
  const [lo, hi] = SIGN_RANGE[sign];
  const r = RANK[level];
  if (r > hi) return `이 준비로는 ${VERDICT[level]}`;
  if (r < lo) return `이 준비라면 ${VERDICT[level]}`;
  return VERDICT[level];
}

export function signTier(threat: number, horde: boolean): SignTier {
  if (threat > 1 || horde) return 'many';
  if (threat < 1) return 'few';
  return 'some';
}

function hash(s: string): number {
  let x = 2166136261;
  for (let i = 0; i < s.length; i += 1) x = Math.imul(x ^ s.charCodeAt(i), 16777619);
  return x >>> 0;
}

/** 아직 안 본 문장 중 하나. 다 봤으면 가장 오래전에 본 것. 난수 흐름을 건드리지 않게 판 씨앗과 구간으로 고른다. */
export function pickFresh(pool: string[], seen: string[], salt: string): string {
  const start = hash(salt) % pool.length;
  const order = pool.map((_, i) => pool[(start + i) % pool.length]);
  const fresh = order.find(t => !seen.includes(t));
  if (fresh) return fresh;
  return order.reduce((a, b) => (seen.lastIndexOf(a) <= seen.lastIndexOf(b) ? a : b));
}

const SEEN_CAP = 150;
export function markSeen(g: Game, text: string): void {
  g.linesSeen = [...(g.linesSeen ?? []).filter(t => t !== text), text].slice(-SEEN_CAP);
}

export function pickWeather(g: Game): Weather {
  const total = WEATHER_WEIGHT.reduce((s, [, w]) => s + w, 0);
  let x = hash(`${g.seed}:w:${g.seg}`) % total;
  for (const [w, n] of WEATHER_WEIGHT) { if (x < n) return w; x -= n; }
  return 'snow';
}

export interface StopView { weather: Weather; sign: SignTier; sky: string; ground: string; omen: string }

/** 정차의 날씨, 창밖 겉모습, 정찰조 조짐. 바꾸지 않고 계산만 한다(예전 저장 판도 이걸로 채운다). */
export function stopView(g: Game, stop: StopState, horde: boolean): StopView {
  const weather = stop.weather ?? pickWeather(g);
  const sign = stop.sign ?? signTier(stop.threat ?? 1, horde);
  const seen = g.linesSeen ?? [];
  const salt = `${g.seed}:${g.seg}:${stop.place}`;
  const sky = pickFresh(WEATHER_LOOK[weather], seen, `${salt}:wl`);
  const ground = pickFresh(PLACE_LOOK[stop.place] ?? PLACE_LOOK.freight, seen, `${salt}:pl`);
  const omens = [...(PLACE_OMENS[stop.place] ?? PLACE_OMENS.freight)[sign], ...WEATHER_OMENS[weather][sign]];
  return { weather, sign, sky, ground, omen: stop.omen ?? pickFresh(omens, seen, `${salt}:om`) };
}

/** 도착할 때 정차 글을 정해 두고 창밖 글은 본 것으로 적는다. 기척(threat)이 정해진 뒤 부른다. */
export function rollStopView(g: Game, stop: StopState, horde: boolean): void {
  const v = stopView(g, stop, horde);
  stop.weather = v.weather;
  stop.sign = v.sign;
  stop.look = `${v.sky} ${v.ground}`;
  stop.omen = v.omen;
  markSeen(g, v.sky);
  markSeen(g, v.ground);
}
