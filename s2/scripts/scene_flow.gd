extends RefCounted

enum Stage { HOME, BRAKING, LOADING, STATION, FIELD }
## What the loading stage shows on top of the brake scene (ui_states L4):
## nothing while the brake still covers it, a band past 1.5 s, a retry past 8 s.
enum LoadNote { NONE, BAND, RETRY }
const LOADING_BAND_S: float = 1.5
const LOADING_RETRY_S: float = 8.0
const BAND_TEXT := "열차가 멈춰 선다…"
const RETRY_TEXT := "다시 해 본다"
var stage: int = Stage.HOME

func advance(next_stage: int) -> bool:
	if next_stage != stage + 1 or next_stage > Stage.FIELD:
		return false
	stage = next_stage
	return true

func reset() -> void:
	stage = Stage.HOME

func label() -> String:
	return ["단면 홈", "감속", "짧은 로딩", "정차 / 하차", "탑뷰 필드"][stage]

## `elapsed` is the seconds spent in LOADING. Outside LOADING there is nothing to say.
func loading_note(elapsed: float) -> int:
	if stage != Stage.LOADING or elapsed <= LOADING_BAND_S:
		return LoadNote.NONE
	return LoadNote.RETRY if elapsed > LOADING_RETRY_S else LoadNote.BAND

## Why a stage button cannot act now, in the world's voice; "" when it can
## (ui_states P3). The same conditions the buttons used to be switched off by.
func why_blocked(action: String, station_ready: bool = false) -> String:
	var underway := stage == Stage.BRAKING or stage == Stage.LOADING
	match action:
		"stop":
			if stage == Stage.HOME:
				return ""
			if underway:
				return "열차가 서는 중이다."
			return "이미 정차했다." if stage == Stage.STATION else "이미 필드에 나와 있다."
		"field":
			if stage == Stage.HOME:
				return "먼저 정차해야 한다."
			if underway:
				return "열차가 서는 중이다."
			if stage == Stage.FIELD:
				return "이미 필드에 나와 있다."
			return "" if station_ready else "하차가 끝나야 한다."
		"noise", "restart":
			return "" if stage == Stage.FIELD else "필드에 나간 뒤에 쓴다."
		"posture":
			return "필드에서는 자세를 바꿀 수 없다." if stage == Stage.FIELD else ""
	return ""
