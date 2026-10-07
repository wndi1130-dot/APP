extends RefCounted

enum Stage { HOME, BRAKING, LOADING, STATION, FIELD }
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
