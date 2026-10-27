extends RefCounted
## 건물 용도와 지역(결정 478): 겉에서 읽히는 꼴(지붕·벽 재질·문창·덧붙이)을 고르는 두 열쇠.
## 지도 파일은 고치지 않고 건물 이름에서 용도를 읽는다. 지도에 손으로 쓴 role(houses)이 있으면
## 그게 이긴다(night_lights.gd와 같은 꼴). 지역은 지도 갈래 무리(map-layout 확정 10-27,
## 근거 docs/design/briefs/places.md 2.7).

## 지도 갈래 -> 지역. 손으로 만든 첫 정차(역 구내)는 철도 공업지.
const REGION_OF_GROUP: Dictionary = {
	"houses": "town", "office": "town", "hospital": "town", "church": "town",
	"freight": "rail_works", "factory": "rail_works", "first_stop": "rail_works",
	"mine": "mountain_works", "sawmill": "mountain_works",
	"lodge": "high_mountain", "summit": "high_mountain",
	"lake": "waterside", "bare_line": "bare_line",
}
const FIRST_STOP_ID := "first_leg_01_sulechow"

## 손으로 쓴 role(houses 지도) -> 용도.
const ROLE_USE: Dictionary = {
	"home": "home", "shed": "shed", "shop": "shop", "shopmain": "shop", "market": "shop", "office": "office",
}

## 「본관」「본채」의 용도: 그 지도 갈래의 주된 용도.
const GROUP_MAIN: Dictionary = {
	"hospital": "clinic", "office": "office", "church": "church", "factory": "works", "freight": "station", "lodge": "lodge",
}
## 이름 낱말 -> 용도. 앞 줄이 이긴다: 「빵집」은 가게, 「종지기 집」은 집, 「우물집」은 정자,
## 「창고형 매장」은 가게, 「관리동」은 사무, 「고리 섬 관리 집」은 집. 코어 장면 건물(core_scenes.gd
## 기관고·수선고·동력실·분해동·정비고·터빈 홀·변전실·냉동 기계실)은 일터나 차고로 읽힌다.
const NAME_USE: Array = [
	["bell_tower", ["종탑"]],
	["church", ["교회", "본당", "예배", "성당", "제의", "사제관", "경당"]],
	["clinic", ["병원", "병동", "진료", "의무", "격리", "요양", "내과", "외과", "응급", "약제", "치과", "보건"]],
	["station", ["역사", "대합실", "매표", "신호", "역무", "승강장"]],
	["headframe", ["권양기", "갱도", "갱구"]],
	["sawmill", ["제재"]],
	["lodge", ["산장", "오두막", "대피소"]],
	["shelter", ["정자", "우물", "보관소", "온실"]],
	["shop", ["빵집", "가게", "상점", "상가", "매점", "매장", "약국", "약방", "주유소", "식료품", "잡화", "철물", "정육", "문구", "안경", "서점", "시계", "이발", "인쇄", "대리점", "직판", "상회", "선구점"]],
	["hall", ["노인정", "휴게", "주막", "회관", "강당", "식당", "여관", "손님", "부엌", "주방", "급식", "대기소"]],
	["works", ["공장", "공방", "작업", "대장간", "목공", "기계", "정비", "수선", "분해", "동력", "엔진", "터빈", "변전",
		"선탄", "보일러", "설비", "발전", "세탁", "냉동", "방직", "난방", "열 공급", "지원",
		"개폐기", "검수", "공구", "수리", "압축", "염색", "펌프", "물처리", "실 감기", "선반", "가공", "충전", "제분", "계단탑",
		"다층동", " 홀"]],
	["depot", ["차고", "기관고", "화차고", "제설"]],
	["office", ["사무", "관리", "우편", "우체", "관청", "본부", "제어실", "시청", "은행", "경찰", "소방", "학교", "도서",
		"계량", "수위", "경비", "도면"]],
	["home", ["주택", "살림", "농가", "연립", "하숙", "사택", "관사", "숙소", "숙직", "기숙", "수도자", "별채", "집"]],
	["barn", ["헛간", "외양간", "마구간", "우리", "곳간", "사일로", "방앗간", "건조", "말림", " 광"]],
	["store", ["창고", "저장", "적재", "보관", "도매", "얼음", "연료", "쓰레기", "석탄", "출하"]],
	["shed", ["객차"]],
]


## 지도 갈래(「church_03」 -> 「church」, 첫 정차는 「first_stop」).
static func group_of(map_id: String) -> String:
	if map_id == FIRST_STOP_ID:
		return "first_stop"
	var cut := map_id.rfind("_")
	return map_id.substr(0, cut) if cut > 0 and map_id.substr(cut + 1).is_valid_int() else map_id


static func region_of(map_id: String) -> String:
	return String(REGION_OF_GROUP.get(group_of(map_id), "?"))


## 건물 줄(data["buildings"]의 한 줄, name·role)의 용도. 모르면 「?」.
static func use_of(row: Dictionary) -> String:
	var role := String(row.get("role", ""))
	if ROLE_USE.has(role):
		return ROLE_USE[role]
	var name := String(row.get("name", ""))
	if name.begins_with("동 ") or name.contains("공동주택"):
		return "home"  # 「동 가 긴 날개」 같은 공동주택 동
	if (name.contains("본관") or name.contains("본채")) and GROUP_MAIN.has(String(row.get("group", ""))):
		return GROUP_MAIN[row["group"]]  # 본관은 그 지도의 주된 용도
	for rule: Array in NAME_USE:
		for word: String in rule[1]:
			if name.contains(word):
				return rule[0]
	return "?"
