extends "res://addons/gut/test.gd"
## PR2c 1·3번: 눈 덩어리·테두리·풀 구멍·더미 띠를 소스에서 확인한다.
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
	# ee39b399(3번 전)에서는 실패 예상: 잔 결 2.2 m가 새 0.5~1 m 범위를 벗어난다.
	var snow := _snow_code()
	var code := _compact(snow)
	assert_true(code.contains("vec2snow_p=world_pos.xz+snow_phase;"))
	assert_almost_eq(_world_scale(snow, "patch_p"), 0.09, 0.001, "바탕 약 11 m")
	var fine_scale := _world_scale(snow, "fine_p")
	assert_almost_eq(fine_scale, 1.1, 0.001, "잔 결 약 0.9 m")
	assert_between(fine_scale, 1.0, 2.0, "잔 결 크기 0.5~1 m")
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


func test_bare_ground_exports_the_actual_grass_share_on_both_paths() -> void:
	# ee39b399(3번 전)에서는 실패 예상: 사진·기존 재질의 실제 bare가 눈 쪽으로 전달되지 않는다.
	var code := _code()
	var ground := _compact(_block(code, "vec3 bare_ground("))
	assert_true(code.contains("out float grass_share"), "지역 출력 인자로 풀 몫 전달")
	assert_true(ground.begins_with("grass_share=0.0;"), "흙 전용·포장·기타 재질의 기본 풀 몫은 0")
	assert_true(ground.contains("grass_share=1.0-bare;returnmix(grass*grass_detail.rgb,SOIL*soil_detail.rgb,bare);"), "사진 재질에 실제로 쓴 bare")
	assert_true(ground.contains("grass_share=1.0-bare;returnmix(grass,SOIL*(0.92+0.16*grain.a),bare);"), "기존 재질에 실제로 쓴 bare")
	assert_eq(ground.count("grass_share=1.0-bare;"), 2, "각 풀 경로에서 한 번만 넘김")


func test_fragment_receives_grass_without_recomputing_the_ground() -> void:
	# ee39b399(3번 전)에서는 실패 예상: 바닥 계산 한 번에서 풀 몫도 받는 지역 변수가 없다.
	var fragment := _block(_code(), "void fragment() {")
	var ground := _compact(_block(fragment, "if (ground_kind > 0.5 && bare_k > 0.001) {"))
	assert_true(ground.contains("bare_ground(kind,ground_detail,base,world_pos.xz,grain,ground_dx,ground_dy,grass_share)"))
	assert_true(ground.contains("grass_share*=bare_k;"), "풀 모습을 섞은 만큼만 구멍(비탈·반쯤 지붕 밑은 정점 색)")
	assert_eq(fragment.count("bare_ground("), 1, "이미 계산하는 바닥에서 풀 몫도 얻음")
	var empty_at := fragment.find("float grass_share = 0.0;")
	assert_gte(empty_at, 0, "바닥을 계산하지 않는 소품·지붕 밑도 풀 몫 0")
	assert_lt(empty_at, fragment.find("if (ground_kind > 0.5 && bare_k > 0.001) {"))


func test_grass_grain_edge_uses_a_derivative_outside_branches() -> void:
	# ee39b399(3번 전)에서는 실패 예상: 읽어 둔 grain 잔 결의 구멍 문턱과 화소 폭이 없다.
	var fragment := _block(_code(), "void fragment() {")
	var code := _compact(fragment)
	assert_true(code.contains("floatgrass_edge=grain.a-0.65;"), "기존 사진의 잔 채널만 재사용")
	assert_true(code.contains("floatgrass_w=max(1.25*fwidth(grass_edge),0.002);"))
	var width_at := fragment.find("fwidth(grass_edge)")
	assert_gte(width_at, 0)
	if width_at < 0:
		return
	var before_width := fragment.substr(0, width_at)
	assert_eq(before_width.count("{") - before_width.count("}"), 0, "fragment의 어떤 분기 안에도 없는 미분")
	assert_gt(width_at, fragment.find("vec4 grain = texture(fx_ground"))
	assert_lt(width_at, fragment.find("bare_ground("), "재질 계산 분기 전에 미분")
	assert_eq(fragment.count("fwidth(grass_edge)"), 1)


func test_grass_holes_only_open_in_the_thin_snow_window() -> void:
	# ee39b399(3번 전)에서는 실패 예상: 실제 풀 몫과 눈 양 0.25~0.65의 연속 구멍 창이 없다.
	var code := _compact(_block(_code(), "void fragment() {"))
	var window := _match(code, "floatthin_snow=smoothstep\\(0\\.25,([0-9.]+),local_snow\\)\\*\\(1\\.0-smoothstep\\(([0-9.]+),0\\.65,local_snow\\)\\);")
	if window != null:
		var opened := float(window.get_string(1))
		var closing := float(window.get_string(2))
		assert_gt(opened, 0.25, "눈이 조금 쌓이며 연속으로 열림")
		assert_lte(opened, closing)
		assert_lt(closing, 0.65, "깊은 눈 전에 연속으로 닫힘")
	assert_true(code.contains("floatgrass_holes=grass_share*thin_snow*smoothstep(-grass_w,grass_w,grass_edge);"), "풀 몫이 0이면 구멍도 0")
	assert_true(code.contains("cover*=1.0-grass_holes;"))


func test_grass_holes_follow_and_spare_the_snow_piles() -> void:
	# ee39b399(3번 전)에서는 실패 예상: 벽·연석 더미와 바람 쌓임을 피하는 풀 구멍 처리가 없다.
	var fragment := _block(_code(), "void fragment() {")
	var piled := _block(fragment, "if (heaped > 0.001) {")
	var code := _compact(fragment)
	assert_true(code.contains("floatpile=0.0;"), "더미를 계산하지 않은 곳은 0")
	assert_false(piled.contains("float pile"), "구멍 쪽까지 쓰는 더미를 가리지 않음")
	assert_true(piled.contains("pile = smoothstep("))
	assert_true(code.contains("grass_holes*=1.0-smoothstep(0.0,0.25,max(pile,bank));"), "쌓임 0.25 이상에서 구멍 0")
	var holes_at := fragment.find("cover *= 1.0 - grass_holes;")
	assert_gt(holes_at, fragment.find("cover = max(cover, 1.0 * pile * heaped);"), "벽·연석 더미 뒤에 구멍 적용")
	assert_lt(fragment.find("float pile = 0.0;"), fragment.find("if (heaped > 0.001) {"))
	assert_lt(holes_at, fragment.find("base = mix(base, FX_SNOW"), "눈 색을 얹기 전에 적용")


func test_heaped_snow_reaches_full_cover_after_the_ground_cap() -> void:
	# ee39b399(3번 전)에서는 실패 예상: 더미 띠의 상한 0.85 때문에 띠에서도 바닥이 비친다.
	var fragment := _block(_code(), "void fragment() {")
	var code := _compact(fragment)
	assert_true(code.contains("cover=max(cover,1.0*pile*heaped);"), "더미 띠는 1.0까지")
	assert_false(code.contains("0.85*pile*heaped"))
	assert_true(code.contains("floatheaped=smoothstep(0.1,0.5,local_snow)*smoothstep(0.6,0.9,up)*sky*(1.0-smoothstep(0.08,0.3,chroma));"), "기존 지도 눈 양·윗면·지붕·채도 조건 유지")
	var heap_at := fragment.find("cover = max(cover, 1.0 * pile * heaped);")
	assert_gt(heap_at, fragment.find("cover *= 0.97;"), "평지 상한보다 더미가 우선")
	if heap_at >= 0:
		var after_heap := fragment.substr(heap_at)
		assert_false(after_heap.contains("0.97"), "더미를 다시 평지 상한으로 제한하지 않음")


func test_grass_holes_add_no_noise_or_texture_reads() -> void:
	# ee39b399(3번 전)에서는 실패 예상: 재사용만으로 그리는 구멍 식이 아직 없다.
	var code := _code()
	assert_eq(code.count("fx_vnoise("), 33, "셰이더 전체 값 노이즈 호출 지점 유지")
	assert_eq(code.count("fx_fbm2("), 8, "추가 옥타브 없음")
	assert_eq(code.count("texture(fx_ground"), 1, "사진 결은 한 번만 읽음")
	var fragment := _block(code, "void fragment() {")
	var start := fragment.find("float thin_snow =")
	var end := fragment.find("cover *= 1.0 - grass_holes;")
	assert_gte(start, 0)
	assert_gt(end, start)
	if start < 0 or end <= start:
		return
	var holes := fragment.substr(start, end - start)
	for word: String in ["texture", "fx_vnoise(", "fx_fbm2(", "bare_ground("]:
		assert_false(holes.contains(word), "구멍은 이미 읽고 계산한 값만 사용: " + word)
