extends RefCounted
## PR1a: 자료 검사와 한 번만 찍는 계약. 지도 활성화와 밖 칸 쓰기는 PR1b.

const FieldGrid = preload("res://game/world/field_grid.gd")


static func check(bounds: Dictionary, grid: FieldGrid) -> Array[String]:
	var errors: Array[String] = []
	if bounds.is_empty():
		return errors
	if not bounds.get("rule", 0) is int or int(bounds.get("rule", 0)) < 0:
		errors.append("rule: 0 이상의 정수가 필요합니다")
		return errors
	if int(bounds.get("rule", 0)) == 0:
		return errors
	if bounds.get("made_by", "") not in ["rule", "hand"]:
		errors.append("made_by: rule 또는 hand가 필요합니다")
	var sides: Variant = bounds.get("sides")
	if not sides is Array or sides.size() != 4:
		errors.append("sides: 왼쪽, 위, 오른쪽, 아래의 네 폭이 필요합니다")
	else:
		for width: Variant in sides:
			if not width is int or width < 0:
				errors.append("sides: 폭은 0 이상의 정수여야 합니다")
	var gaps: Variant = bounds.get("gaps")
	if not gaps is Array:
		errors.append("gaps: 진입로 이름 배열이 필요합니다")
	else:
		for gap: Variant in gaps:
			if not gap is String:
				errors.append("gaps: 진입로 이름은 문자열이어야 합니다")
	var outline: Variant = bounds.get("outline")
	if not outline is Array or outline.size() < 4:
		errors.append("outline: 닫는 변을 포함한 꼭짓점 네 개 이상이 필요합니다")
		return errors
	for point: Variant in outline:
		if not point is Vector2i:
			errors.append("outline: 꼭짓점은 Vector2i여야 합니다")
			return errors
		if point.x < 0 or point.y < 0 or point.x > grid.width or point.y > grid.height:
			errors.append("outline: 격자 밖 꼭짓점입니다")
	var count: int = outline.size()
	var area: int = 0
	for i in range(count):
		var a: Vector2i = outline[i]
		var b: Vector2i = outline[(i + 1) % count]
		var c: Vector2i = outline[(i + 2) % count]
		if a == b or (a.x != b.x and a.y != b.y):
			errors.append("outline/%d: 길이가 있는 가로 또는 세로 변이어야 합니다" % i)
		if (a.x == b.x) == (b.x == c.x):
			errors.append("outline/%d: 이웃 변의 방향이 같거나 겹칩니다" % i)
		area += a.x * b.y - b.x * a.y
		for j in range(i + 2, count):
			if i == 0 and j == count - 1:
				continue
			var u: Vector2i = outline[j]
			var v: Vector2i = outline[(j + 1) % count]
			if maxi(mini(a.x, b.x), mini(u.x, v.x)) <= mini(maxi(a.x, b.x), maxi(u.x, v.x)) \
					and maxi(mini(a.y, b.y), mini(u.y, v.y)) <= mini(maxi(a.y, b.y), maxi(u.y, v.y)):
				errors.append("outline/%d/%d: 자기 교차 또는 겹침입니다" % [i, j])
	if area <= 0:
		errors.append("outline: 시계 방향이어야 합니다")
	var runs: Variant = bounds.get("runs")
	if not runs is Array:
		errors.append("runs: 구간 배열이 필요합니다")
		return errors
	var next_edge: int = 0
	for run: Variant in runs:
		if not run is Dictionary or not run.get("from") is int or not run.get("to") is int:
			errors.append("runs: from/to 정수가 필요합니다")
			return errors
		if run["from"] != next_edge or run["to"] <= run["from"] or run["to"] > count:
			errors.append("runs: 변 번호가 빠지거나 겹칩니다")
		if run.get("kind", "") not in ["wall", "cliff", "rock", "mine", "forest", "water", "quarry"]:
			errors.append("runs: 알 수 없는 갈래입니다")
		next_edge = run["to"]
	if next_edge != count:
		errors.append("runs: 마지막 변까지 덮어야 합니다")
	return errors


static func apply(data: Dictionary, bounds_rule: int = -1) -> Dictionary:
	var bounds: Dictionary = data.get("bounds", {})
	if bounds.is_empty() or bounds_rule == 0 or bounds.get("rule", 0) == 0:
		return data
	var errors: Array[String] = check(bounds, data["grid"])
	if not errors.is_empty():
		push_error("경계 검사 실패: " + "; ".join(errors))
		return data
	# 요청한 저장 판의 자료가 없으면 다른 판으로 표시하지 않는다(설계 7a).
	var rule: int = int(bounds["rule"])
	if bounds_rule > 0 and bounds_rule != rule:
		return data
	if data.has("bounds_stamp"):
		assert(int(data["bounds_stamp"]) == rule, "다른 판의 경계를 다시 찍을 수 없습니다")
		return data
	data["bounds_stamp"] = rule
	return data
