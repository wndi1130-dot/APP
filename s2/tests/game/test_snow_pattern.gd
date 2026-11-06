extends "res://addons/gut/test.gd"
## PR2c 1번: 눈 덩어리의 크기·테두리·재질별 상한을 소스에서 확인한다.
## 화면과 셰이더 컴파일은 부른 세션에서 별도로 확인한다.

const SHADER_PATH := "res://game/world/world_vis.gdshader"


func _code() -> String:
	var lines: PackedStringArray = []
	for raw: String in FileAccess.get_file_as_string(SHADER_PATH).split("\n"):
		var line := raw.strip_edges()
		if not line.begins_with("//"):
			lines.append(line)
	return "\n".join(lines)


func _compact(code: String) -> String:
	return code.replace(" ", "").replace("\t", "").replace("\n", "").replace("\r", "")


func _block(code: String, marker: String) -> String:
	var start := code.find(marker)
	assert_gte(start, 0, "코드에 필요한 경계: " + marker)
	if start < 0:
		return ""
	var opening := code.find("{", start)
	assert_gte(opening, 0, "여는 중괄호: " + marker)
	if opening < 0:
		return ""
	var depth := 1
	for i in range(opening + 1, code.length()):
		var ch := code.substr(i, 1)
		if ch == "{":
			depth += 1
		elif ch == "}":
			depth -= 1
			if depth == 0:
				return code.substr(opening + 1, i - opening - 1)
	assert_eq(depth, 0, "닫히지 않은 덩어리: " + marker)
	return ""


func _snow_code() -> String:
	return _block(_code(), "if (fx_snow > 0.01) {")


func _match(code: String, pattern: String) -> RegExMatch:
	var regex := RegEx.new()
	var error := regex.compile(pattern)
	assert_eq(error, OK, "소스 검색식 문법")
	if error != OK:
		return null
	var found := regex.search(code)
	assert_not_null(found, "필요한 소스 식: " + pattern)
	return found


func _world_scale(code: String, name: String) -> float:
	var found := _match(_compact(code), "vec2" + name + "=snow_p\\*([0-9.]+);")
	return float(found.get_string(1)) if found != null else -1.0


func test_patch_fine_and_warp_scales_are_independent() -> void:
	# origin/main 실패 예상: 잔 결·비틀기가 바탕 좌표의 배수여서 함께 커진다.
	var snow := _snow_code()
	var code := _compact(snow)
	assert_true(code.contains("vec2snow_p=world_pos.xz+snow_phase;"))
	assert_almost_eq(_world_scale(snow, "patch_p"), 0.09, 0.001, "바탕 약 11 m")
	assert_almost_eq(_world_scale(snow, "fine_p"), 0.45, 0.001, "잔 결 약 2.2 m")
	assert_gte(_world_scale(snow, "warp_p"), 1.0 / 9.0, "비틀기는 9 m 이하")
	assert_true(code.contains("fx_vnoise(warp_p+vec2(17.1,9.2))"))
	assert_true(code.contains("fx_vnoise(warp_p+vec2(3.7,23.6))"))


func test_fine_noise_has_one_fifth_of_the_patch_weight() -> void:
	# origin/main 실패 예상: 잔 결 무게 0.28이 비슷한 크기의 둥근 조각을 강조한다.
	var snow := _compact(_snow_code())
	assert_true(snow.contains("floatsnow_patch=0.8*fx_vnoise(patch_p+"))
	assert_true(snow.contains("+0.2*fx_vnoise(fine_p+"))


func test_edge_width_tracks_the_continuous_noise_minus_threshold() -> void:
	# origin/main 실패 예상: 경계 대신 노이즈만 미분하며 폭의 바닥 0.02가 번짐을 만든다.
	var snow := _compact(_snow_code())
	assert_true(snow.contains("floatsnow_t=1.0-smoothstep(0.05,0.95,local_snow);"))
	assert_true(snow.contains("floatsnow_edge=snow_patch-snow_t;"))
	var width := _match(snow, "floatpatch_w=max\\(1\\.25\\*fwidth\\(snow_edge\\),([0-9.]+)\\);")
	if width != null:
		var floor_width := float(width.get_string(1))
		assert_gt(floor_width, 0.0, "영폭 smoothstep 방지")
		assert_lte(floor_width, 0.005, "노이즈 값으로 테두리를 넓히지 않음")
	assert_true(snow.contains("cover=smoothstep(-patch_w,patch_w,snow_edge);"))
	assert_false(snow.contains("fwidth(snow_patch)"))


func test_edge_derivative_precedes_local_snow_and_ground_branches() -> void:
	# origin/main 실패 예상: 연속 경계 미분이 없으며, 이후 수정에서도 재질 분기 안의 미분을 막는다.
	var fragment := _block(_code(), "void fragment() {")
	var width_at := fragment.find("fwidth(snow_edge)")
	assert_gte(width_at, 0, "경계 미분이 존재")
	if width_at < 0:
		return
	var before_width := fragment.substr(0, width_at)
	for word: String in ["ground_kind", "bare_ground(", "if (kind", "if (bare_k", "if (local_snow"]:
		assert_false(before_width.contains(word), "미분보다 앞선 화소별 분기 없음: " + word)


func test_empty_and_full_snow_override_antialiasing_before_the_cap() -> void:
	# origin/main 실패 예상: 화면 미분 폭과 무관한 0.05·0.95 양끝 보장이 명시되어 있지 않다.
	var snow := _snow_code()
	assert_eq(_compact(_block(snow, "if (local_snow <= 0.05) {")), "cover=0.0;")
	assert_eq(_compact(_block(snow, "else if (local_snow >= 0.95) {")), "cover=1.0;")
	var antialias_at := snow.find("cover = smoothstep(")
	var empty_at := snow.find("if (local_snow <= 0.05)")
	var full_at := snow.find("else if (local_snow >= 0.95)")
	var cap_at := snow.find("if (ground_kind > 0.5)")
	assert_gte(antialias_at, 0)
	assert_gt(empty_at, antialias_at, "미분·안티에일리어싱 뒤에 눈 없음 보장")
	assert_gt(full_at, empty_at)
	assert_gt(cap_at, full_at, "0과 1을 정한 뒤 재질별 상한 적용")


func test_only_ground_uses_the_higher_snow_cap() -> void:
	# origin/main 실패 예상: 모든 재질에 0.9를 곱해 땅에서도 흙이 10% 비친다.
	var snow := _snow_code()
	var cap_at := snow.find("if (ground_kind > 0.5) {")
	assert_gte(cap_at, 0, "땅과 소품을 가르는 분기")
	if cap_at < 0:
		return
	var caps := snow.substr(cap_at)
	assert_eq(_compact(_block(caps, "if (ground_kind > 0.5) {")), "cover*=0.97;")
	assert_eq(_compact(_block(caps, "} else {")), "cover*=0.9;")
	assert_eq(snow.count("0.97"), 1, "높은 상한은 땅 분기 안에 한 번만")
	assert_true(_compact(_code()).contains("cover*=smoothstep(0.6,0.9,up)*sky*(1.0-smoothstep(0.08,0.3,chroma));"), "지붕·기울기·채도 제한 유지")


func test_snow_keeps_its_noise_and_texture_read_budget() -> void:
	# origin/main 통과 예상: 기존 비용 잠금으로 바탕 1·잔 결 1·비틀기 2·녹음 1을 늘리지 않는다.
	var snow := _snow_code()
	assert_eq(snow.count("fx_vnoise("), 5)
	assert_eq(snow.count("fx_fbm2("), 0, "눈 덩어리에 숨은 추가 옥타브 없음")
	assert_false(snow.contains("texture"), "눈 덩어리에 새 텍스처 읽기 없음")
	assert_eq(_code().count("texture(fx_ground"), 1, "사진 결은 한 번만 읽음")


func test_snow_gate_and_depth_sum_remain_exact() -> void:
	# origin/main 통과 예상: 다른 PR과 공유하는 시작 조건·눈 깊이 식의 원문을 잠근다.
	var code := _code()
	var lines := code.split("\n")
	var gate := "if (fx_snow > 0.01) {"
	var depth_sum := "local_snow = clamp(fx_snow * (1.0 + snow_shift + 1.4 * snow_melt * melt), 0.0, 1.0);"
	assert_eq(lines.count(gate), 1, "보호 줄: 눈 시작 조건")
	assert_eq(lines.count(depth_sum), 1, "보호 줄: 지도별 눈 깊이")
	assert_eq(_snow_code().count("local_snow ="), 1, "깊이를 다시 덮어쓰지 않음")
