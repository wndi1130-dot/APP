import { P } from './data';
import { rainAt, rowAt } from './season';
import { routeWeather } from './route_weather';
import { hash } from './fnv_hash';
import type { Game, StopState } from './state';

// 정차 조짐(2026-10-07 사용자): 위험을 꼬리표로 적지 않고, 정찰조가 본 조짐과 그 해석으로 알린다.
// "입가에 피를 묻힌 까마귀들이 날아간다. 매우 불길하다." 조짐 문장은 장소와 날씨마다 다르고 한 판 안에서 되도록 다시 안 나온다.
// 고요함: 안전한 쪽은 사람·망자 소리는 없고 새나 짐승 소리는 남는다. 새소리마저 끊긴 고요는 위험 쪽이다
// (사운드 브리프 7.1과 맞춤, 2026-10-07). 사용자 예문 '쥐 죽은 듯 고요하다'는 인기척에 대한 말로 쓴다.
// 금지선: 사람이나 무리가 화차·닫힌 칸 안에 갇힌 장면은 쓰지 않는다(강제 이송 열차로 읽힌다). 화차는 빈 풍경으로만.
// 해석 말(매우 불길하다 / 불길하다 / …)은 일부러 고정한다. 플레이어가 약속을 읽는 말이라 매번 바뀌면 못 읽는다.

/** 정차 날씨. 평상 다섯은 씨앗 해시로 뽑고(기온 켠 판은 계절표 비율, season.ts), 눈보라·한파는 재난을 켠 판에서 재난이 닥친 구간에만 온다(pickWeather).
 *  기온 켠 판에서 한낮 기온이 rain_above보다 높은 구간의 sleet는 비다(규칙은 진눈깨비와 같고 글만 비, RAIN_SWAP). */
export type Weather = 'snow' | 'fog' | 'sleet' | 'overcast' | 'clear' | 'blizzard' | 'cold' | 'cold_front';
/** 바깥 기척. 정차마다 정해지고 준비를 바꿔도 안 바뀐다. many 무리가 많다, some 보통, few 거의 없다. */
export type SignTier = 'many' | 'some' | 'few';

export const WEATHER_NAME: Record<Weather, string> = { snow: '눈', fog: '안개', sleet: '진눈깨비', overcast: '흐림', clear: '맑은 추위', blizzard: '눈보라', cold: '한파', cold_front: '맑은 추위' };
/** 어둡고 칙칙한 날이 8할(아트 방향). 갠 날은 드물다. 재난 날씨(눈보라·한파)는 여기서 뽑지 않는다. */
const WEATHER_WEIGHT: [Weather, number][] = [['snow', 30], ['fog', 20], ['sleet', 15], ['overcast', 20], ['clear', 15]];

/** 열차 창으로 보이는 날씨. 위험은 알려 주지 않는다. */
export const WEATHER_LOOK: Record<Weather, string[]> = {
  snow: ['눈이 쉬지 않고 내린다.', '함박눈이 플랫폼을 덮어 간다.', '눈보라가 창에 들러붙는다.', '가는 눈이 비스듬히 날린다.', '눈이 그쳤다가 다시 내린다.'],
  fog: ['안개가 짙다. 역사 지붕이 겨우 보인다.', '안개가 선로를 따라 낮게 깔렸다.', '안개 때문에 스무 걸음 앞이 흐리다.', '젖은 안개가 창에 맺힌다.', '안개 사이로 전신주만 줄지어 보인다.'],
  sleet: ['진눈깨비가 창을 때린다.', '진눈깨비가 내린다. 옷이 금세 젖겠다.', '젖은 눈이 선로 위에서 녹았다 언다.', '처마마다 진눈깨비 물이 떨어진다.', '진눈깨비에 플랫폼이 번들거린다.'],
  overcast: ['하늘이 낮고 잿빛이다.', '구름이 두껍다. 한낮인데 어둑하다.', '바람이 구름을 낮게 몰고 간다.', '흐린 빛에 모든 것이 납빛이다.', '해가 구름 뒤에서 희미하게 비친다.'],
  clear: ['오랜만에 하늘이 갰다. 추위가 살을 벤다.', '볕은 드는데 숨이 얼 만큼 춥다.', '하늘이 맑다. 눈밭이 눈부시다.', '맑은 하늘 아래 성에가 반짝인다.', '바람 한 점 없이 쨍하게 춥다.'],
  blizzard: ['눈보라가 몰아친다. 승강장 끝이 안 보인다.', '바람이 눈을 옆으로 몰아 창을 때린다.', '흰 벽 같은 눈발 속에 전신주 하나가 흔들린다.', '눈이 바람에 실려 땅에 닿지를 않는다.', '바람 소리에 기관차 소리마저 묻힌다.'],
  cold: ['숨을 들이쉬면 콧속이 언다.', '창 안쪽까지 성에가 두껍게 꼈다.', '빛이 희고 날카롭다. 그림자가 길다.', '레일이 추위에 쩡 하고 운다.', '눈이 발밑에서 마른 소리를 내며 부서진다.'],
  cold_front: ['하늘이 유리처럼 맑다. 바람이 뚝 멎었다.', '빛이 유난히 희다. 눈밭이 쨍하다.', '먼 숲 끝까지 또렷하다. 공기가 고여 있다.', '창가 성에가 보는 사이에 자란다.', '구름이 걷혔다. 입김이 짙게 흩어진다.'],
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
    few: ['사람 기척은 쥐 죽은 듯 없다. 참새들만 시끄럽다.', '까마귀들이 선로에 앉아 졸고 있다.', '창고 문마다 눈이 무릎까지 쌓였다. 드나든 자국이 없다.'],
  },
  houses: {
    many: ['골목 끝에서 개들이 짖다가 한꺼번에 뚝 그친다.', '깨진 유리가 전부 바깥에 흩어져 있다. 안에서 나왔다.', '눈 덮인 마당에 신발 한 짝과 끌린 자국이 있다.'],
    some: ['지하실 창틈으로 연기가 낮게 새다 끊긴다.', '담장 너머에서 무언가 쓰러지는 소리가 한 번 난다.', '대문마다 분필 숫자가 있다. 누가 먼저 뒤졌다.'],
    few: ['빨랫줄에 언 옷이 걸려 있다. 참새들이 그 위에서 떠든다.', '고양이가 지붕에서 볕을 쬔다. 쫓기는 기색이 없다.', '골목 눈 위에 새 발자국만 찍혀 있다.'],
  },
  hospital: {
    many: ['응급실 유리문 안쪽에 손바닥 자국이 겹겹이 찍혀 있다.', '위층 복도에서 무언가 끌리는 소리가 멈추지 않는다.', '주차장 까마귀들이 무언가를 두고 다투다 일제히 날아오른다.'],
    some: ['병동 창 하나에 커튼이 흔들린다. 창은 닫혀 있다.', '약품 상자가 계단에 쏟아져 있다. 누가 급히 나갔다.', '지하로 가는 문틈에서 들척지근한 냄새가 샌다.'],
    few: ['접수대에 눈이 들이쳐 쌓였다. 발자국 하나 없다.', '복도엔 인기척이 없다. 창밖에서 참새 소리가 들린다.', '비둘기들이 병원 처마에 줄지어 앉아 있다.'],
  },
  factory: {
    many: ['굴뚝 꼭대기 까마귀 떼가 공장 안을 내려다보며 운다.', '철문이 안쪽에서 밀려 바깥으로 휘어 있다.', '작업장 안에서 쇠 긁는 소리가 여럿 겹쳐 들린다.'],
    some: ['기계 사이로 그림자 하나가 지나갔다. 다시 안 보인다.', '담 밑 눈이 사람 모양으로 꺼져 있다.', '저탄장 더미에 누가 파헤친 자국이 있다.'],
    few: ['쥐들이 저탄장을 태연히 가로지른다.', '기계마다 성에가 하얗게 앉았다. 손댄 흔적이 없다.', '공장 마당이 텅 비었다. 양철판만 바람에 덜컹인다.'],
  },
  church: {
    many: ['종탑 까마귀들이 부리에 붉은 것을 물고 날아간다.', '예배당 앞마당에 핏자국이 길게 끌려 있다.', '앞마당 눈이 진창이 됐다. 발자국이 전부 안으로 향한다.'],
    some: ['종이 한 번 울린다. 바람은 그만큼 세지 않다.', '의자들이 문 앞에 쌓여 있다. 누가 막으려 했다.', '촛농이 아직 무르다. 누가 다녀간 지 얼마 안 됐다.'],
    few: ['종탑 아래 비둘기들이 모이를 쪼며 구구댄다.', '예배당엔 인기척이 없다. 깨진 창으로 참새가 드나든다.', '묘지 울타리 너머까지 눈이 고르게 덮였다.'],
  },
  office: {
    many: ['관청 계단에 흩어진 서류가 핏물에 얼어붙어 있다.', '위층 창마다 그림자가 서 있다. 움직이지 않는다.', '정문 바리케이드가 안쪽에서 무너져 있다.'],
    some: ['복도 끝 문이 바람에 열렸다 닫혔다 한다.', '서류함이 모두 열려 있다. 누가 무엇을 찾았다.', '지하 기록실 쪽에서 물건 떨어지는 소리가 한 번 난다.'],
    few: ['멈춘 시계탑 위에서 까치가 시끄럽게 운다.', '관청 계단에 참새들이 내려앉아 부스러기를 쫀다.', '정문 눈 위엔 새 발자국뿐이다. 사람 기척은 없다.'],
  },
};

/** 정찰조가 본 조짐(날씨별). 장소 조짐과 섞어 같은 장소라도 날마다 달리 보이게 한다. */
export const WEATHER_OMENS: Record<Weather, Record<SignTier, string[]>> = {
  snow: {
    many: ['새로 내린 눈 위에 맨발 자국이 어지럽다.', '눈발 속에서 비틀거리는 그림자가 여럿 지나간다.'],
    some: ['눈이 발자국을 반쯤 덮었다. 어제 것이다.', '먼 눈발 속에 그림자 하나가 서 있다.'],
    few: ['밤새 내린 눈이 고르다. 아무것도 지나가지 않았다.', '눈밭에서 까마귀가 느긋하게 운다.'],
  },
  fog: {
    many: ['안개 속 사방에서 이 가는 소리가 난다.', '안개 너머에서 썩은 내가 바람을 거슬러 온다.'],
    some: ['안개 속에 사람 같은 것이 섰다가 사라진다.', '안개 너머에서 발 끄는 소리가 한 번 난다.', '안개 속에 새소리 하나 없다. 너무 조용하다.'],
    few: ['안개 속에서 까마귀 우는 소리만 한가롭다.', '안개 너머로 먼 개 짖는 소리가 한가롭다.'],
  },
  sleet: {
    many: ['진눈깨비에 젖은 핏자국이 선로 옆으로 길게 번졌다.', '빗소리 사이로 낮은 신음이 여기저기서 난다.'],
    some: ['진눈깨비가 소리를 덮는다. 가까이 와야 들린다.', '젖은 눈 위에 발자국 하나가 끌린 듯 이어진다.'],
    few: ['처마 밑에서 참새들이 진눈깨비를 피하며 운다.', '처마 밑 고양이가 젖은 털을 핥고 있다.'],
  },
  overcast: {
    many: ['낮은 구름 아래로 까마귀 떼가 한곳을 맴돈다.', '바람이 바뀌자 썩은 내가 확 끼친다.'],
    some: ['바람이 멎자 어디선가 낮은 신음이 한 번 들린다.', '새소리마저 뚝 끊겼다. 너무 조용하다.', '까마귀 몇 마리가 지붕 하나를 떠나지 않는다.'],
    few: ['인기척은 쥐 죽은 듯 없고 까마귀만 한가롭다.', '들개 한 마리가 느긋하게 선로를 건너간다.'],
  },
  clear: {
    many: ['맑은 하늘에 까마귀 떼가 새까맣게 한곳을 맴돈다.', '눈 위 핏자국이 볕에 선명하다. 아직 얼지 않았다.'],
    some: ['쨍한 추위에 먼 데 문 닫히는 소리가 또렷하다.', '눈부신 눈밭 너머로 무언가 움직였다.'],
    few: ['볕이 쨍하고 바람이 없다. 새소리만 들린다.', '맑은 하늘에 참새 떼가 시끄럽다.'],
  },
  blizzard: {
    many: ['바람에 섞여 여럿이 우는 소리가 실려 온다.', '눈 위에 끌린 자국이 덮이자마자 또 생긴다.'],
    some: ['바람 사이로 무언가 넘어지는 소리가 한 번 난다.', '눈발 속에 그림자 하나가 섰다가 지워진다.'],
    few: ['까마귀들이 처마 밑에 웅크려 눈을 피한다.', '들개 한 마리가 처마 밑에서 바람을 피한다.'],
  },
  cold: {
    many: ['얼어붙은 그림자들이 길가에 흩어져 서 있다.', '언 눈 위에 맨발 자국이 새로 났다. 다 얼지는 않았다.'],
    some: ['언 그림자 하나가 서 있다. 손가락이 조금 움직였다.', '먼 데서 얼음 깨지는 소리가 쩡 하고 난다.'],
    few: ['추위에 까마귀들도 지붕 위에서 꼼짝 않는다.', '볕 드는 담 밑에 참새들이 몸을 부풀리고 모였다.'],
  },
  cold_front: {
    many: ['눈 위에 발자국이 어지럽다. 볕에 핏자국이 검다.', '바람 없는 공기에 썩은 내가 그대로 고여 있다.'],
    some: ['고인 공기 너머에서 발 끄는 소리가 또렷하다.', '맑은 눈밭 끝에 그림자 하나가 서성인다.'],
    few: ['들개 한 마리가 볕을 쬐며 졸고 있다.', '까치 두 마리가 맑은 하늘을 가로질러 간다.'],
  },
};

// 계절표를 따르는 판(기온 켠 판)의 글 바꿔 끼우기(결정 423, 서막 (나)). 위 글은 겨울 글이라 눈·얼음이 박혀 있다.
// 그 구간에 쌓인 눈이 없으면 SNOW_SWAP, 밤 결빙도 없으면(한파·한파 전조 날씨는 빼고) FROST_SWAP, 진눈깨비가 비면 RAIN_SWAP 글로 바꾼다.
// 한 줄을 한 줄로 바꿔 글 수가 그대로라 한 판 안 되풀이 규칙이 같이 산다. 바꾼 글도 위 글과 같은 규칙(길이·금지선·고요)을 지킨다.
/** 쌓인 눈이 없는 구간: 눈밭·눈 더미가 박힌 글 → 낙엽·진흙 글. 이 글들도 얼음은 말하지 않는다(한파 날씨 글은 빼고). */
export const SNOW_SWAP: Record<string, string> = {
  '저탄장의 검은 더미가 눈을 이고 있다.': '저탄장의 검은 더미에 낙엽이 들러붙었다.',
  '작은 교회 지붕에 눈이 두껍게 앉았다.': '작은 교회 지붕에 젖은 낙엽이 수북하다.',
  '플랫폼 눈이 붉게 얼룩졌다. 끌린 자국이 창고로 이어진다.': '플랫폼 바닥이 붉게 얼룩졌다. 끌린 자국이 창고로 이어진다.',
  '기중기 밑 눈 더미에서 무언가 긁는 소리가 났다.': '기중기 밑 낙엽 더미에서 무언가 긁는 소리가 났다.',
  '창고 문마다 눈이 무릎까지 쌓였다. 드나든 자국이 없다.': '창고 문마다 낙엽이 수북이 쌓였다. 드나든 자국이 없다.',
  '눈 덮인 마당에 신발 한 짝과 끌린 자국이 있다.': '젖은 마당에 신발 한 짝과 끌린 자국이 있다.',
  '골목 눈 위에 새 발자국만 찍혀 있다.': '골목 진흙 위에 새 발자국만 찍혀 있다.',
  '접수대에 눈이 들이쳐 쌓였다. 발자국 하나 없다.': '접수대에 낙엽이 들이쳐 쌓였다. 발자국 하나 없다.',
  '담 밑 눈이 사람 모양으로 꺼져 있다.': '담 밑 덤불이 사람 모양으로 꺾여 있다.',
  '앞마당 눈이 진창이 됐다. 발자국이 전부 안으로 향한다.': '앞마당이 진창이 됐다. 발자국이 전부 안으로 향한다.',
  '묘지 울타리 너머까지 눈이 고르게 덮였다.': '묘지 울타리 너머까지 낙엽이 고르게 덮였다.',
  '정문 눈 위엔 새 발자국뿐이다. 사람 기척은 없다.': '정문 진흙 위엔 새 발자국뿐이다. 사람 기척은 없다.',
  '하늘이 맑다. 눈밭이 눈부시다.': '하늘이 맑다. 먼 들판까지 훤하다.',
  '눈이 발밑에서 마른 소리를 내며 부서진다.': '언 땅이 발밑에서 마른 소리를 낸다.',
  '빛이 유난히 희다. 눈밭이 쨍하다.': '빛이 유난히 희다. 들판이 쨍하다.',
  '눈 위 핏자국이 볕에 선명하다. 아직 얼지 않았다.': '자갈 위 핏자국이 볕에 선명하다. 아직 마르지 않았다.',
  '눈부신 눈밭 너머로 무언가 움직였다.': '볕 드는 들판 너머로 무언가 움직였다.',
  '언 눈 위에 맨발 자국이 새로 났다. 다 얼지는 않았다.': '언 진흙에 맨발 자국이 새로 났다. 다 얼지는 않았다.',
  '눈 위에 발자국이 어지럽다. 볕에 핏자국이 검다.': '서리 위에 발자국이 어지럽다. 볕에 핏자국이 검다.',
  '맑은 눈밭 끝에 그림자 하나가 서성인다.': '맑은 들판 끝에 그림자 하나가 서성인다.',
};
/** 밤 결빙도 없는 구간(늦가을): 성에·언 것·살을 베는 추위가 박힌 글 → 젖고 쌀쌀한 글 */
export const FROST_SWAP: Record<string, string> = {
  '선로 사이에 언 발자국이 몇 줄 있다. 며칠 됐다.': '선로 사이 진흙에 발자국이 몇 줄 있다. 며칠 됐다.',
  '빨랫줄에 언 옷이 걸려 있다. 참새들이 그 위에서 떠든다.': '빨랫줄에 젖은 옷이 걸려 있다. 참새들이 그 위에서 떠든다.',
  '기계마다 성에가 하얗게 앉았다. 손댄 흔적이 없다.': '기계마다 녹이 붉게 앉았다. 손댄 흔적이 없다.',
  '관청 계단에 흩어진 서류가 핏물에 얼어붙어 있다.': '관청 계단에 흩어진 서류가 핏물에 젖어 있다.',
  '오랜만에 하늘이 갰다. 추위가 살을 벤다.': '오랜만에 하늘이 갰다. 바람이 차다.',
  '볕은 드는데 숨이 얼 만큼 춥다.': '볕은 드는데 바람 끝이 맵다.',
  '맑은 하늘 아래 성에가 반짝인다.': '맑은 하늘 아래 젖은 선로가 반짝인다.',
  '바람 한 점 없이 쨍하게 춥다.': '바람 한 점 없이 볕이 엷다.',
  '쨍한 추위에 먼 데 문 닫히는 소리가 또렷하다.': '맑은 공기에 먼 데 문 닫히는 소리가 또렷하다.',
};
/** 한낮 기온이 rain_above보다 높은 구간의 진눈깨비 = 비 */
export const RAIN_SWAP: Record<string, string> = {
  '진눈깨비가 창을 때린다.': '찬비가 창을 때린다.',
  '진눈깨비가 내린다. 옷이 금세 젖겠다.': '비가 그치지 않는다. 옷이 금세 젖겠다.',
  '젖은 눈이 선로 위에서 녹았다 언다.': '침목 사이마다 빗물이 고였다.',
  '처마마다 진눈깨비 물이 떨어진다.': '처마마다 빗물이 줄줄 떨어진다.',
  '진눈깨비에 플랫폼이 번들거린다.': '비에 젖은 플랫폼이 번들거린다.',
  '진눈깨비에 젖은 핏자국이 선로 옆으로 길게 번졌다.': '빗물에 번진 핏자국이 선로 옆으로 길게 이어진다.',
  '진눈깨비가 소리를 덮는다. 가까이 와야 들린다.': '빗소리가 발소리를 덮는다. 가까이 와야 들린다.',
  '젖은 눈 위에 발자국 하나가 끌린 듯 이어진다.': '진흙 위에 발자국 하나가 끌린 듯 이어진다.',
  '처마 밑에서 참새들이 진눈깨비를 피하며 운다.': '처마 밑에서 참새들이 비를 피하며 운다.',
};

/** 이 정차의 글 고르기 조건: 계절표를 안 따르는 판(기온 꺼진 판)은 null(겨울 글 그대로, 골든 그대로) */
function seasonCond(g: Game, weather: Weather): { snow: boolean; frost: boolean; rain: boolean } | null {
  if (!g.climate) return null;
  const row = rowAt(g.seg);
  const cold = weather === 'cold' || weather === 'cold_front';
  return { snow: row.snow, frost: row.night_freeze || cold, rain: weather === 'sleet' && rainAt(g.seg) };
}

function seasonLine(t: string, c: { snow: boolean; frost: boolean; rain: boolean } | null): string {
  if (!c) return t;
  let out = t;
  if (c.rain) out = RAIN_SWAP[out] ?? out;
  if (!c.frost) out = FROST_SWAP[out] ?? out;
  if (!c.snow) out = SNOW_SWAP[out] ?? out;
  return out;
}

/** 해석 말. 준비(얼마나·몇 명·호위)에 따라 바뀌고, 이 말이 약속이다. */
export type RiskLevel = 'dead' | 'hurt' | 'light' | 'calm';
export const VERDICT: Record<RiskLevel, string> = {
  dead: '매우 불길하다.',
  hurt: '불길하다.',
  light: '긁히는 정도로 끝날 것 같다.',
  calm: '괜찮을 것 같다.',
};
/** 인원 줄(결정 341, 문구는 가안). 정찰 뒤에만 뜬다. N은 충분해지는 인원 ceil(1.5 × 알맞은 인원)이다. */
export type CrewBandName = 'short' | 'tight' | 'enough';
export const CREW_LINE = {
  enough: '이 인원이면 충분하다. 큰일 없이 돌아올 가능성이 높다.',
  enoughUnlucky: '이 인원이면 충분하다. 그래도 이번엔 운이 나쁘게 읽힌다.',
  tight: (n: number) => `인원이 빠듯하다. 누군가 크게 다칠 수 있다. 충분하려면 ${n}명쯤.`,
  short: (n: number) => `인원이 모자란다. 사람을 잃을 수 있다. 충분하려면 ${n}명쯤.`,
  over: '8명으로도 빠듯하다. 체류를 줄이거나 호위를 붙이면 낮아진다.',
  overShort: '8명으로도 모자란다. 체류를 줄이거나 호위를 붙이면 낮아진다.',
} as const;
const CREW_BAND_SAY: Record<CrewBandName, string> = { short: '모자란다', tight: '빠듯하다', enough: '충분하다' };

/** 충분해지는 인원 N. 넘으면 8명으로도 모자란 정차다 */
export function crewEnoughCount(need: number): number {
  return Math.ceil(1.5 * need);
}

/** 인원 줄 글. 충분인데 해석이 불길(hurt·dead)이면 약속(해석 말)을 그대로 두고 운이 나쁘다고만 덧붙인다.
 * N이 8을 넘으면 8명을 다 보냈을 때의 밴드로 말한다: 8/need가 모자람 경계 아래(need > 10)면 「모자란다」, 아니면 「빠듯하다」. */
export function crewLineText(band: CrewBandName, need: number, level: RiskLevel): string {
  if (band === 'enough') return level === 'hurt' || level === 'dead' ? CREW_LINE.enoughUnlucky : CREW_LINE.enough;
  const n = crewEnoughCount(need);
  if (n > 8) return 8 / need < P.crewBandShort ? CREW_LINE.overShort : CREW_LINE.over;
  return band === 'tight' ? CREW_LINE.tight(n) : CREW_LINE.short(n);
}

/** 선택지 밑 까닭 한 줄(결정 339 「왜」). 알맞은 인원 숫자는 정찰 뒤에만 쓴다. */
/** snow: 눈보라가 한창이라 정찰을 보내도 안쪽을 못 읽는 때. 정찰하면 인원을 알 수 있다고 말하지 않는다(검수 PR 395 낮음 11). */
export function crewWhyText(known: { place: string; risk: number; stay: string; need: number; crew: number; band: CrewBandName } | null, snow = false): string {
  if (!known && snow) return '눈보라 속에서는 정찰을 보내도 안쪽 기척을 읽을 수 없어 몇 명이 알맞은지 말할 수 없다. 산출은 알맞은 인원까지만 늘고, 더 보내면 위험은 낮아지지만 돌아온 이들이 이번 회기 표결에서 빠진다.';
  if (!known) return '몇 명이 알맞은지는 정찰로 위험을 알아야 말할 수 있다. 산출은 알맞은 인원까지만 늘고, 더 보내면 위험은 낮아지지만 돌아온 이들이 이번 회기 표결에서 빠진다.';
  const need = Math.round(known.need * 10) / 10;
  return `${known.place} 위험 ${known.risk}에 ${known.stay} 체류라 ${need}명쯤이 알맞다. 지금 ${known.crew}명이면 ${CREW_BAND_SAY[known.band]}. 알맞은 인원보다 더 보내면 산출은 그대로고 위험만 낮아지며, 돌아온 이들은 이번 회기 표결에서 빠진다.`;
}
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

export { hash };

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
  // 재난을 켠 판에서 눈보라·한파가 닥친 구간이면 정차 날씨는 그 재난이다(창밖 글·조짐이 재난과 어긋나지 않게).
  // 재난은 기온 켠 판의 흐름 날씨보다 먼저 적용한다.
  // 두 구간 앞 예고(DZ.lead 2) 구간의 정차는 앞머리다: 눈보라는 흐림, 한파는 한파 전조(드문 갬과 닮았지만 바람이 멎는다).
  const d = g.disasters ? g.disaster : undefined;
  if (d?.stage === 'active') return d.kind;
  if (d?.stage === 'brewing') return d.kind === 'blizzard' ? 'overcast' : 'cold_front';
  // 결정 474 N2: 기온 켠 판만 노선 흐름을 읽는다. 꺼진 판은 옛 고정 비율 그대로(골든).
  if (g.climate) return routeWeather(g.seed, g.seg);
  const table = WEATHER_WEIGHT;
  const total = table.reduce((s, [, w]) => s + w, 0);
  let x = hash(`${g.seed}:w:${g.seg}`) % total;
  for (const [w, n] of table) { if (x < n) return w; x -= n; }
  return 'snow';
}

export interface StopView { weather: Weather; sign: SignTier; sky: string; ground: string; omen: string }

/** 정차의 날씨, 창밖 겉모습, 정찰조 조짐. 바꾸지 않고 계산만 한다(예전 저장 판도 이걸로 채운다). */
export function stopView(g: Game, stop: StopState, horde: boolean): StopView {
  const weather = stop.weather ?? pickWeather(g);
  const sign = stop.sign ?? signTier(stop.threat ?? 1, horde);
  const seen = g.linesSeen ?? [];
  const salt = `${g.seed}:${g.seg}:${stop.place}`;
  const c = seasonCond(g, weather);
  const fit = (pool: string[]) => pool.map(t => seasonLine(t, c));
  const sky = pickFresh(fit(WEATHER_LOOK[weather]), seen, `${salt}:wl`);
  const ground = pickFresh(fit(PLACE_LOOK[stop.place] ?? PLACE_LOOK.freight), seen, `${salt}:pl`);
  const omens = fit([...(PLACE_OMENS[stop.place] ?? PLACE_OMENS.freight)[sign], ...WEATHER_OMENS[weather][sign]]);
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
