extends "res://addons/gut/test.gd"
## PR2c: 눈 무늬·면적 보존·미분의 실행 경로와 검사기 자체를 소스에서 확인한다.
## 화면과 셰이더 컴파일은 부른 세션에서 별도로 확인한다.

const SHADER_PATH := "res://game/world/world_vis.gdshader"
const GRAIN_PATH := "res://fx/textures/ground_detail.png"
const SENSITIVE_CALLS := ["fwidth", "dFdx", "dFdy", "texture"]
const DECLARATION_TYPES := [
	"bool", "int", "uint", "float", "vec2", "vec3", "vec4", "ivec2", "ivec3", "ivec4",
	"bvec2", "bvec3", "bvec4", "mat2", "mat3", "mat4", "sampler2D", "sampler2DArray",
]
const CONDITION_BUILTINS := [
	"bool", "int", "uint", "float", "vec2", "vec3", "vec4", "ivec2", "ivec3", "ivec4",
	"bvec2", "bvec3", "bvec4", "mat2", "mat3", "mat4", "abs", "min", "max", "clamp",
	"mix", "step", "smoothstep", "floor", "ceil", "round", "trunc", "fract", "mod",
	"sign", "sqrt", "pow", "exp", "log", "sin", "cos", "tan", "length", "dot",
	"normalize", "any", "all", "isnan", "isinf", "true", "false", "const",
]
enum CommentMode { CODE, LINE, BLOCK, QUOTED }


func _code() -> String:
	return _strip_comments(FileAccess.get_file_as_string(SHADER_PATH))


func _strip_comments(source: String) -> String:
	# 문자열의 res:// 는 남긴다. 지운 자리는 공백으로 채워 식별자와 줄이 붙지 않게 한다.
	var parts: PackedStringArray = []
	var mode := CommentMode.CODE
	var quote := ""
	var escaped := false
	var i := 0
	while i < source.length():
		var ch := source.substr(i, 1)
		var pair := source.substr(i, 2)
		if mode == CommentMode.QUOTED:
			parts.append(ch)
			if escaped:
				escaped = false
			elif ch == "\\":
				escaped = true
			elif ch == quote:
				mode = CommentMode.CODE
		elif mode == CommentMode.LINE:
			parts.append("\n" if ch == "\n" else " ")
			if ch == "\n":
				mode = CommentMode.CODE
		elif mode == CommentMode.BLOCK:
			if pair == "*/":
				parts.append("  ")
				i += 2
				mode = CommentMode.CODE
				continue
			parts.append("\n" if ch == "\n" else " ")
		elif pair == "//" or pair == "/*":
			mode = CommentMode.LINE if pair == "//" else CommentMode.BLOCK
			parts.append("  ")
			i += 2
			continue
		else:
			parts.append(ch)
			if ch == "\"" or ch == "'":
				quote = ch
				mode = CommentMode.QUOTED
		i += 1
	var lines: PackedStringArray = []
	for line: String in "".join(parts).split("\n"):
		lines.append(line.strip_edges())
	return "\n".join(lines)


func _tokens(source: String) -> Array[String]:
	var regex := RegEx.new()
	var error := regex.compile("\"(?:\\\\.|[^\"\\\\])*\"|[A-Za-z_][A-Za-z_0-9]*|(?:[0-9]+(?:\\.[0-9]*)?|\\.[0-9]+)(?:[eE][+-]?[0-9]+)?|==|!=|<=|>=|&&|\\|\\||\\+\\+|--|\\+=|-=|\\*=|/=|<<|>>|[^\\s]")
	var result: Array[String] = []
	if error != OK:
		return result
	for found: RegExMatch in regex.search_all(source):
		result.append(found.get_string())
	return result


func _paired_tokens(tokens: Array[String]) -> Dictionary:
	var pairs := {}
	var stack: Array[int] = []
	var closing := {"(": ")", "[": "]", "{": "}"}
	for i in tokens.size():
		var token := tokens[i]
		if closing.has(token):
			stack.append(i)
		elif token in [")", "]", "}"]:
			if stack.is_empty() or closing[tokens[stack.back()]] != token:
				return {"error": "괄호 짝 불일치: %d" % i}
			var opening: int = stack.pop_back()
			pairs[opening] = i
			pairs[i] = opening
	if not stack.is_empty():
		return {"error": "닫히지 않은 괄호"}
	return {"pairs": pairs}


func _included_source(source: String) -> Dictionary:
	# 포함 파일도 같은 검사 대상이다. 중복 읽기와 순환을 막고 읽기 실패를 통과시키지 않는다.
	var texts: PackedStringArray = []
	var queue: Array[Dictionary] = [{"path": SHADER_PATH, "source": source}]
	var seen := {SHADER_PATH: true}
	var include_regex := RegEx.new()
	include_regex.compile("#include\\s+\"([^\"]+)\"")
	var at := 0
	while at < queue.size():
		if queue.size() > 64:
			return {"error": "include가 64개를 넘음"}
		var unit: Dictionary = queue[at]
		var code := _strip_comments(String(unit["source"]))
		texts.append(code)
		for found: RegExMatch in include_regex.search_all(code):
			var path := found.get_string(1)
			if not path.begins_with("res://"):
				path = String(unit["path"]).get_base_dir().path_join(path).simplify_path()
			if seen.has(path):
				continue
			seen[path] = true
			if not FileAccess.file_exists(path):
				return {"error": "include 읽기 실패: " + path}
			queue.append({"path": path, "source": FileAccess.get_file_as_string(path)})
		at += 1
	return {"source": "\n".join(texts)}


func _uniform_condition(tokens: Array[String], start: int, end: int, known: Dictionary, local: Dictionary) -> bool:
	for i in range(start, end):
		var token := tokens[i]
		if not token.is_valid_identifier() or (i > start and tokens[i - 1] == "."):
			continue
		if known.has(token) or local.has(token) or token in DECLARATION_TYPES or token in ["true", "false", "const"]:
			continue
		if token in CONDITION_BUILTINS and i + 1 < end and tokens[i + 1] == "(":
			continue
		return false
	return true


func _guarded(state: Dictionary, start: int, end: int, guards: Array[String], local: Dictionary, label: String) -> Array[String]:
	var next: Array[String] = guards.duplicate()
	var tokens: Array[String] = state["tokens"]
	if not _uniform_condition(tokens, start, end, state["known"], local):
		next.append(label + "(" + " ".join(PackedStringArray(tokens.slice(start, end))) + ")")
	return next


func _statement_end(tokens: Array[String], pairs: Dictionary, start: int, end: int, depth := 0) -> int:
	if start >= end or depth > 128:
		return end
	if tokens[start] == "{":
		return int(pairs[start]) + 1
	if tokens[start] in ["if", "for", "while"] and start + 1 < end and tokens[start + 1] == "(":
		var next := _statement_end(tokens, pairs, int(pairs[start + 1]) + 1, end, depth + 1)
		if tokens[start] == "if" and next < end and tokens[next] == "else":
			next = _statement_end(tokens, pairs, next + 1, end, depth + 1)
		return next
	var i := start
	while i < end:
		if tokens[i] == ";":
			return i + 1
		if tokens[i] in ["(", "[", "{"]:
			i = int(pairs[i]) + 1
		else:
			i += 1
	return end


func _expression_start(tokens: Array[String], start: int, end: int) -> int:
	# 선언·대입의 왼쪽은 조건의 일부가 아니다.
	for i in range(end - 1, start - 1, -1):
		if tokens[i] in ["=", "+=", "-=", "*=", "/="]:
			return i + 1
	return start + 1 if start < end and tokens[start] == "return" else start


func _scan_expression(state: Dictionary, start: int, end: int, guards: Array[String], local: Dictionary, depth := 0) -> void:
	if depth > 128:
		state["errors"].append("식의 중첩이 너무 깊음")
		return
	var tokens: Array[String] = state["tokens"]
	var pairs: Dictionary = state["pairs"]
	var split := -1
	var question := -1
	var colon := -1
	var ternary_depth := 0
	var i := start
	while i < end:
		if tokens[i] in ["(", "["]:
			i = int(pairs[i]) + 1
			continue
		if tokens[i] == "?":
			if question < 0:
				question = i
			ternary_depth += 1
		elif tokens[i] == ":" and ternary_depth > 0:
			ternary_depth -= 1
			if ternary_depth == 0 and colon < 0:
				colon = i
		elif tokens[i] in [",", ";"] and ternary_depth == 0:
			_scan_expression(state, start, i, guards, local, depth + 1)
			_scan_expression(state, i + 1, end, guards, local, depth + 1)
			return
		elif tokens[i] in ["&&", "||"] and split < 0 and question < 0:
			split = i
		i += 1
	if question >= 0 and colon > question:
		_scan_expression(state, start, question, guards, local, depth + 1)
		var next := _guarded(state, _expression_start(tokens, start, question), question, guards, local, "?:")
		_scan_expression(state, question + 1, colon, next, local, depth + 1)
		_scan_expression(state, colon + 1, end, next, local, depth + 1)
		return
	if split >= 0:
		_scan_expression(state, start, split, guards, local, depth + 1)
		var next := _guarded(state, _expression_start(tokens, start, split), split, guards, local, tokens[split])
		_scan_expression(state, split + 1, end, next, local, depth + 1)
		return
	i = start
	while i < end:
		if i + 1 < end and tokens[i].is_valid_identifier() and tokens[i + 1] == "(":
			var call := {"name": tokens[i], "at": i, "guards": guards.duplicate()}
			if tokens[i] in SENSITIVE_CALLS:
				state["ops"].append(call)
			elif state["functions"].has(tokens[i]):
				state["calls"].append(call)
			var close: int = pairs[i + 1]
			_scan_expression(state, i + 2, close, guards, local, depth + 1)
			i = close + 1
		elif tokens[i] in ["(", "["]:
			var close: int = pairs[i]
			_scan_expression(state, i + 1, close, guards, local, depth + 1)
			i = close + 1
		else:
			i += 1


func _scan_statement(state: Dictionary, start: int, end: int, guards: Array[String], local: Dictionary, depth := 0) -> int:
	var tokens: Array[String] = state["tokens"]
	var pairs: Dictionary = state["pairs"]
	if start >= end:
		return end
	if depth > 128:
		state["errors"].append("제어문의 중첩이 너무 깊음")
		return end
	var token := tokens[start]
	if token == "{":
		var block_end: int = pairs[start]
		var i := start + 1
		while i < block_end:
			var following := _scan_statement(state, i, block_end, guards, local, depth + 1)
			if following <= i:
				state["errors"].append("문장 경계를 찾지 못함")
				return block_end + 1
			i = following
		return block_end + 1
	if token in ["if", "for", "while"]:
		if start + 1 >= end or tokens[start + 1] != "(":
			state["errors"].append("제어문 조건 괄호가 없음")
			return end
		var condition_end: int = pairs[start + 1]
		var loop_local: Dictionary = local.duplicate()
		var counter := ""
		if token == "for" and start + 5 < condition_end and tokens[start + 2] in ["int", "uint"] and tokens[start + 4] == "=":
			var semicolon := tokens.find(";", start + 5)
			if semicolon >= 0 and semicolon < condition_end and _uniform_condition(tokens, start + 5, semicolon, state["known"], local):
				counter = tokens[start + 3]
				loop_local[counter] = true
		_scan_expression(state, start + 2, condition_end, guards, loop_local)
		var next_guards := _guarded(state, start + 2, condition_end, guards, loop_local, token)
		if not counter.is_empty():
			var body_end := _statement_end(tokens, pairs, condition_end + 1, end)
			for i in range(condition_end + 1, body_end - 1):
				if tokens[i] == counter and (tokens[i + 1] in ["=", "+=", "-=", "*=", "/=", "++", "--"] or tokens[i - 1] in ["++", "--"]):
					next_guards.append("for 본문이 반복 변수를 바꿈: " + counter)
					break
		var after_body := _scan_statement(state, condition_end + 1, end, next_guards, loop_local, depth + 1)
		if token == "if" and after_body < end and tokens[after_body] == "else":
			after_body = _scan_statement(state, after_body + 1, end, next_guards, local, depth + 1)
		return after_body
	if token in ["do", "switch"]:
		state["errors"].append("지원하지 않는 제어문을 통과시키지 않음: " + token)
		return _statement_end(tokens, pairs, start, end)
	var statement_end := _statement_end(tokens, pairs, start, end)
	_scan_expression(state, start, statement_end, guards, local)
	if token in ["return", "discard", "break", "continue"] and not guards.is_empty():
		state["escapes"].append({"at": start, "guards": guards.duplicate(), "kind": token})
	return statement_end


func _derivative_errors(source: String) -> PackedStringArray:
	# 호출 그래프의 고정점으로, 분기 안에서 부른 함수의 그 아래 호출까지 따라간다.
	var errors: PackedStringArray = []
	var included := _included_source(source)
	if included.has("error"):
		errors.append(String(included["error"]))
		return errors
	var tokens := _tokens(String(included["source"]))
	var paired := _paired_tokens(tokens)
	if tokens.is_empty() or paired.has("error"):
		errors.append(String(paired.get("error", "토큰이 없음")))
		return errors
	var pairs: Dictionary = paired["pairs"]
	var known := {}
	for i in range(tokens.size() - 2):
		if tokens[i] in ["uniform", "const"]:
			known[tokens[i + 2]] = true
	var functions := {}
	var at := 0
	while at + 1 < tokens.size():
		if tokens[at].is_valid_identifier() and tokens[at + 1] == "(":
			var close: int = pairs[at + 1]
			if close + 1 < tokens.size() and tokens[close + 1] == "{":
				var finish: int = pairs[close + 1]
				functions[tokens[at]] = {"parameters": at + 2, "start": close + 1, "end": finish + 1}
				at = finish + 1
				continue
		at += 1
	for name: String in functions:
		var info: Dictionary = functions[name]
		var visible: Dictionary = known.duplicate()
		# 인자·지역 변수가 같은 이름의 uniform을 가리면 uniform으로 판정하지 않는다.
		for i in range(int(info["parameters"]), int(info["end"]) - 2):
			if tokens[i] in DECLARATION_TYPES and tokens[i + 1].is_valid_identifier() and tokens[i + 2] != "(" and tokens[i - 1] != "const":
				visible.erase(tokens[i + 1])
		info.merge({"tokens": tokens, "pairs": pairs, "known": visible, "functions": functions, "ops": [], "calls": [], "escapes": [], "errors": []})
		var initial_guards: Array[String] = []
		_scan_statement(info, int(info["start"]), int(info["end"]), initial_guards, {})
		errors.append_array(PackedStringArray(info["errors"]))
		info["sensitive"] = not (info["ops"] as Array).is_empty()
	for _iteration in functions.size():
		var changed := false
		for name: String in functions:
			var info: Dictionary = functions[name]
			if bool(info["sensitive"]):
				continue
			for call: Dictionary in info["calls"]:
				if bool(functions[call["name"]]["sensitive"]):
					info["sensitive"] = true
					changed = true
					break
		if not changed:
			break
	for name: String in functions:
		var info: Dictionary = functions[name]
		var sites: Array = (info["ops"] as Array).duplicate()
		for call: Dictionary in info["calls"]:
			if bool(functions[call["name"]]["sensitive"]):
				sites.append(call)
		for site: Dictionary in sites:
			var guards: Array = (site["guards"] as Array).duplicate()
			for escape: Dictionary in info["escapes"]:
				if int(escape["at"]) < int(site["at"]) or escape["kind"] in ["break", "continue"]:
					guards.append_array(escape["guards"])
			if not guards.is_empty():
				var message := "%s → %s: %s" % [name, site["name"], "; ".join(PackedStringArray(guards))]
				if not errors.has(message):
					errors.append(message)
		# 상태에 함수 사전을 보관한 채 반환하면 참조 순환이 생긴다.
		info.erase("functions")
	return errors


func _snow_contract_errors(source: String) -> PackedStringArray:
	var code := _compact(_strip_comments(source))
	var required := [
		"boolis_ground=ground_kind>0.5;",
		"vec2patch_p=snow_p*(is_ground?0.09:0.15);",
		"vec2fine_p=is_ground?snow_p*1.1:patch_p*3.1;",
		"vec2warp_p=is_ground?snow_p*0.125:patch_p*0.5;",
		"floatsnow_patch=(is_ground?0.8:0.72)*fx_vnoise(patch_p+0.7*warp)+(is_ground?0.2:0.28)*fx_vnoise(fine_p+1.4*warp+vec2(5.3,11.9));",
		"floatsnow_blend=smoothstep(0.05,0.95,local_snow);",
		"floatsnow_edge=snow_patch-(1.0-snow_blend);",
		"floatground_w=max(1.25*fwidth(snow_edge),0.002);",
		"floatprop_w=max(fwidth(snow_patch),0.02);",
		"floatpatch_w=is_ground?ground_w:prop_w;",
		"floatsnow_t=mix(1.0+patch_w,-patch_w,snow_blend);",
		"floatground_cover=smoothstep(-patch_w,patch_w,snow_patch-snow_t);",
		"floatprop_cover=0.9*smoothstep(snow_t-patch_w,snow_t+patch_w,snow_patch);",
		"cover=is_ground?0.97*ground_cover:prop_cover;",
	]
	var errors: PackedStringArray = []
	for expression: String in required:
		if not code.contains(expression):
			errors.append("눈 식 누락: " + expression)
	if code.contains("if(local_snow"):
		errors.append("눈 양끝 강제 분기가 남음")
	return errors


func _grass_order_errors(source: String) -> PackedStringArray:
	var code := _compact(_strip_comments(source))
	var expressions := [
		"bare_ground(kind,ground_detail,base,world_pos.xz,grain,ground_dx,ground_dy,grass_share)",
		"grass_share*=bare_k;",
		"floatgrass_holes=grass_share*thin_snow*grass_cut;",
		"grass_holes*=1.0-smoothstep(0.0,0.25,max(pile,bank));",
		"cover*=1.0-grass_holes;",
	]
	var errors: PackedStringArray = []
	var previous := -1
	for expression: String in expressions:
		var at := code.find(expression)
		if at < 0 or at <= previous or code.count(expression) != 1:
			errors.append("풀 구멍 순서·횟수 오류: " + expression)
		previous = at
	return errors


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


func test_patch_fine_and_warp_scales_are_independent() -> void:
	# 6378c2d8에서는 실패 예상: 소품에도 새 배율을 쓰며 땅·소품 좌표 선택이 없다.
	var code := _compact(_snow_code())
	assert_true(code.contains("vec2snow_p=world_pos.xz+snow_phase;"))
	assert_true(code.contains("vec2patch_p=snow_p*(is_ground?0.09:0.15);"))
	assert_true(code.contains("vec2fine_p=is_ground?snow_p*1.1:patch_p*3.1;"))
	assert_true(code.contains("vec2warp_p=is_ground?snow_p*0.125:patch_p*0.5;"))
	assert_true(code.contains("fx_vnoise(warp_p+vec2(17.1,9.2))"))
	assert_true(code.contains("fx_vnoise(warp_p+vec2(3.7,23.6))"))


func test_fine_noise_has_one_fifth_of_the_patch_weight() -> void:
	# 6378c2d8에서는 실패 예상: 소품의 원래 무게 0.72/0.28을 복원하지 않는다.
	var snow := _compact(_snow_code())
	assert_true(snow.contains("floatsnow_patch=(is_ground?0.8:0.72)*fx_vnoise(patch_p+"))
	assert_true(snow.contains("+(is_ground?0.2:0.28)*fx_vnoise(fine_p+"))


func test_edge_width_tracks_the_continuous_noise_minus_threshold() -> void:
	# 6378c2d8에서는 실패 예상: 소품 폭과 땅 폭을 따로 계산해 선택하지 않는다.
	var snow := _compact(_snow_code())
	assert_true(snow.contains("floatsnow_blend=smoothstep(0.05,0.95,local_snow);"))
	assert_true(snow.contains("floatsnow_edge=snow_patch-(1.0-snow_blend);"))
	assert_true(snow.contains("floatground_w=max(1.25*fwidth(snow_edge),0.002);"))
	assert_true(snow.contains("floatprop_w=max(fwidth(snow_patch),0.02);"))
	assert_true(snow.contains("floatpatch_w=is_ground?ground_w:prop_w;"))


func test_all_derivatives_and_implicit_reads_have_uniform_control_flow() -> void:
	# 6378c2d8에서는 실패 예상: 도로·실내 균열, 웅덩이 하늘, 더미 법선의 분기가 검출된다.
	var errors := _derivative_errors(_code())
	assert_eq(errors.size(), 0, "\n".join(errors))


func test_ground_snow_endpoints_follow_a_continuously_widened_threshold() -> void:
	# 6378c2d8에서는 실패 예상: 양끝을 if로 덮어쓰며 폭만큼 넓힌 문턱이 없다.
	var snow := _compact(_snow_code())
	assert_false(snow.contains("if(local_snow"))
	assert_true(snow.contains("floatsnow_t=mix(1.0+patch_w,-patch_w,snow_blend);"))
	assert_true(snow.contains("floatground_cover=smoothstep(-patch_w,patch_w,snow_patch-snow_t);"))
	for width: float in [0.002, 0.02, 0.5, 2.0]:
		for patch: float in [0.0, 0.1, 0.5, 0.9, 1.0]:
			assert_eq(smoothstep(-width, width, patch - (1.0 + width)), 0.0)
			assert_eq(smoothstep(-width, width, patch + width), 1.0)
			var just_empty := lerpf(1.0 + width, -width, smoothstep(0.05, 0.95, 0.050001))
			var just_full := lerpf(1.0 + width, -width, smoothstep(0.05, 0.95, 0.949999))
			assert_almost_eq(smoothstep(-width, width, patch - just_empty), 0.0, 0.00001)
			assert_almost_eq(smoothstep(-width, width, patch - just_full), 1.0, 0.00001)


func test_only_ground_uses_the_higher_snow_cap() -> void:
	# 6378c2d8에서는 실패 예상: 옛 소품 식 전체를 지키는 계약이 없다.
	var errors := _snow_contract_errors(_code())
	assert_eq(errors.size(), 0, "\n".join(errors))
	var snow := _compact(_snow_code())
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
	# 6378c2d8에서는 실패 예상: 구멍 문턱 0.65가 고정되어 2.6 m 반복이 남는다.
	var fragment := _block(_code(), "void fragment() {")
	var code := _compact(fragment)
	assert_true(code.contains("floatgrass_threshold=0.65+clamp((wander-1.0)*(0.06/0.45),-0.06,0.06);"))
	assert_true(code.contains("floatgrass_edge=grain.a-grass_threshold;"), "기존 사진의 잔 채널만 재사용")
	assert_true(code.contains("floatgrass_w=max(1.25*fwidth(grass_edge),0.002);"))
	var width_at := fragment.find("fwidth(grass_edge)")
	assert_gte(width_at, 0)
	if width_at < 0:
		return
	var before_width := fragment.substr(0, width_at)
	assert_eq(before_width.count("{") - before_width.count("}"), 0, "fragment의 어떤 분기 안에도 없는 미분")
	assert_gt(width_at, fragment.find("vec4 grain = texture(fx_ground"))
	assert_lt(width_at, fragment.find("bare_ground("), "재질 계산 분기 전에 미분")
	assert_lt(fragment.find("float wander ="), fragment.find("float grass_edge ="))
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
	assert_true(code.contains("floatgrass_holes=grass_share*thin_snow*grass_cut;"), "풀 몫이 0이면 구멍도 0")
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
	var errors := _grass_order_errors(_code())
	assert_eq(errors.size(), 0, "\n".join(errors))


func test_heaped_snow_reaches_full_cover_after_the_ground_cap() -> void:
	# ee39b399(3번 전)에서는 실패 예상: 더미 띠의 상한 0.85 때문에 띠에서도 바닥이 비친다.
	var fragment := _block(_code(), "void fragment() {")
	var code := _compact(fragment)
	assert_true(code.contains("cover=max(cover,1.0*pile*heaped);"), "더미 띠는 1.0까지")
	assert_false(code.contains("0.85*pile*heaped"))
	assert_true(code.contains("floatheaped=smoothstep(0.1,0.5,local_snow)*smoothstep(0.6,0.9,up)*sky*(1.0-smoothstep(0.08,0.3,chroma));"), "기존 지도 눈 양·윗면·지붕·채도 조건 유지")
	var heap_at := fragment.find("cover = max(cover, 1.0 * pile * heaped);")
	assert_gt(heap_at, fragment.find("cover = is_ground ? 0.97 * ground_cover : prop_cover;"), "평지 상한보다 더미가 우선")
	if heap_at >= 0:
		var after_heap := fragment.substr(heap_at)
		assert_false(after_heap.contains("0.97"), "더미를 다시 평지 상한으로 제한하지 않음")


func test_grass_holes_add_no_noise_or_texture_reads() -> void:
	# ee39b399(3번 전)에서는 실패 예상: 재사용만으로 그리는 구멍 식이 아직 없다.
	var code := _code()
	assert_eq(code.count("fx_vnoise("), 33, "셰이더 전체 값 노이즈 호출 지점 유지")
	assert_eq(code.count("fx_fbm2("), 8, "추가 옥타브 없음")
	assert_eq(code.count("texture(fx_ground"), 1, "사진 결은 한 번만 읽음")
	assert_eq(code.count("texture("), 3, "웅덩이 하늘만 명시적 기울기로 바꿈")
	assert_eq(code.count("textureGrad("), 3)
	assert_eq(code.count("textureLod("), 3, "전체 텍스처 읽기 지점은 9회 유지")
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


func test_far_hole_areas_match_the_original_png_alpha() -> void:
	# 6378c2d8에서는 실패 예상: 원본 알파 면적 표와 원거리 면적 보존이 없다.
	var code := _compact(_code())
	var table := _match(code, "constfloatGRASS_HOLE_AREAS\\[13\\]=float\\[13\\]\\(([^)]+)\\);")
	if table == null:
		return
	var values := table.get_string(1).split(",", false)
	assert_eq(values.size(), 13)
	if values.size() != 13:
		return
	var image := Image.new()
	assert_eq(image.load_png_from_buffer(FileAccess.get_file_as_bytes(GRAIN_PATH)), OK)
	assert_eq(image.get_size(), Vector2i(512, 512))
	assert_eq(image.get_format(), Image.FORMAT_RGBA8)
	if image.get_format() != Image.FORMAT_RGBA8 or image.is_empty():
		return
	var histogram := PackedInt32Array()
	histogram.resize(256)
	var bytes := image.get_data()
	for i in range(3, bytes.size(), 4):
		histogram[bytes[i]] += 1
	var total := float(image.get_width() * image.get_height())
	var previous := 1.0
	for i in 13:
		var above := 0
		# alpha / 255 > (59 + i) / 100: 문턱과 같은 화소는 세지 않는다.
		var first := floori(float((59 + i) * 255) / 100.0) + 1
		for alpha in range(first, 256):
			above += histogram[alpha]
		var area := String(values[i]).to_float()
		assert_almost_eq(area, float(above) / total, 0.0000001, "알파 문턱 %.2f" % (0.59 + 0.01 * i))
		assert_lte(area, previous, "문턱이 높을수록 구멍 면적 감소")
		previous = area


func test_far_holes_blend_to_measured_area_at_the_measured_pixel_size() -> void:
	# 6378c2d8에서는 실패 예상: 밉에서 평균 알파가 문턱 밑으로 가면 구멍 면적이 0이 된다.
	var code := _compact(_code())
	assert_true(code.contains("constfloatGRASS_HOLE_FADE_START=0.0025390625;"), "반 텍셀: 가장 작은 구멍을 두 화소로 표현")
	assert_true(code.contains("constfloatGRASS_HOLE_FADE_END=0.01015625;"), "두 텍셀: 면적 가중 중앙 구멍 크기")
	assert_true(code.contains("floatgrass_px=max(length(ground_dx),length(ground_dy));"))
	assert_true(code.contains("floatgrass_far=smoothstep(GRASS_HOLE_FADE_START,GRASS_HOLE_FADE_END,grass_px);"))
	assert_true(code.contains("floatgrass_mean=grass_hole_area(grass_threshold);"))
	assert_true(code.contains("floatgrass_cut=mix(smoothstep(-grass_w,grass_w,grass_edge),grass_mean,grass_far);"))
	var area := _compact(_block(_code(), "float grass_hole_area("))
	assert_true(area.contains("clamp((threshold-0.59)*100.0,0.0,12.0)"))
	assert_true(area.contains("mix(GRASS_HOLE_AREAS[lower],GRASS_HOLE_AREAS[min(lower+1,12)],fract(index))"))
	for word: String in ["texture", "fx_vnoise(", "fx_fbm2("]:
		assert_false(area.contains(word), "면적 표는 추가 읽기 없이 보간: " + word)


func test_indoor_finish_clears_the_replaced_ground_grass() -> void:
	# 6378c2d8에서는 실패 예상: 실내 마감으로 바닥을 바꾼 뒤에도 이전 풀 몫을 남긴다.
	var fragment := _block(_code(), "void fragment() {")
	var room := _compact(_block(fragment, "if (rc > 0) {"))
	assert_true(room.contains("base=mix(finish,tone,0.5*away);grass_share=0.0;"), "두 마감 모두 실내 표면이므로 풀 몫 0")


func test_comment_filter_keeps_strings_and_removes_both_comment_forms() -> void:
	var source := "#include \"res://fx/shaders/fx_common.gdshaderinc\"\nfloat x = 1.0; // fwidth(sky)\n/* texture(vis, uv);\n dFdx(VERTEX); */ float y = 2.0;"
	var code := _strip_comments(source)
	assert_true(code.contains("\"res://fx/shaders/fx_common.gdshaderinc\""))
	assert_false(code.contains("fwidth"))
	assert_false(code.contains("texture("))
	assert_false(code.contains("dFdx"))
	assert_true(_compact(code).contains("floatx=1.0;floaty=2.0;"))


func test_snow_contract_rejects_a_core_line_hidden_in_comments() -> void:
	# 검사기 시험: 원래 식이 주석에만 남아 있으면 통과하지 않는다.
	var source := _code()
	assert_eq(_snow_contract_errors(source).size(), 0)
	var line := "vec2 fine_p = is_ground ? snow_p * 1.1 : patch_p * 3.1;"
	assert_true(source.contains(line))
	var block_comment := source.replace(line, "/* " + line + " */")
	var line_comment := source.replace(line, "// " + line)
	assert_gt(_snow_contract_errors(block_comment).size(), 0)
	assert_gt(_snow_contract_errors(line_comment).size(), 0)


func test_snow_contract_rejects_new_scales_on_props() -> void:
	# 검사기 시험: 소품까지 새 배율을 쓰도록 바꾸면 실패한다.
	var source := _code()
	var changed := source.replace("snow_p * (is_ground ? 0.09 : 0.15)", "snow_p * 0.09")
	assert_ne(changed, source)
	assert_gt(_snow_contract_errors(changed).size(), 0)


func test_control_checker_rejects_snow_inside_a_sky_branch() -> void:
	# 검사기 시험: uniform 눈 조건도 바깥 sky 조건이 화소별이면 미분에 안전하지 않다.
	var source := _code()
	assert_eq(_derivative_errors(source).size(), 0)
	var gate := "if (fx_snow > 0.01) {"
	var block := gate + _block(source, gate) + "}"
	assert_true(source.contains(block))
	var changed := source.replace(block, "if (sky > 0.5) {\n" + block + "\n}")
	assert_gt(_derivative_errors(changed).size(), 0)


func test_control_checker_rejects_bank_derivatives_and_implicit_reads() -> void:
	# 검사기 시험: 각 미분과 암시적 밉 읽기를 bank 분기에 넣은 문자열은 실패한다.
	for expression: String in ["fwidth(bank)", "dFdx(bank)", "dFdy(bank)", "texture(vis, vec2(0.0)).r"]:
		var body := "float x = " + expression + ";"
		var source := "uniform sampler2D vis; varying float bank; void fragment() { " + body + " }"
		assert_eq(_derivative_errors(source).size(), 0, expression)
		var changed := source.replace(body, "if (bank > 0.002) { " + body + " }")
		assert_gt(_derivative_errors(changed).size(), 0, expression)


func test_control_checker_accepts_branchless_ground_kind_and_uniform_include() -> void:
	# 검사기 시험: 이름이 등장한다는 이유만으로 미분을 금지하지 않는다.
	var source := "#include \"res://fx/shaders/fx_common.gdshaderinc\"\nvarying flat float ground_kind;\nvoid fragment() { bool is_ground = ground_kind > 0.5; if (fx_snow > 0.01) { float w = fwidth(ground_kind); } }"
	assert_eq(_derivative_errors(source).size(), 0)


func test_control_checker_follows_nested_helper_calls_and_else_paths() -> void:
	# 검사기 시험: 두 번 거친 함수 호출과 else/else if도 원래 화소별 조건을 따른다.
	var helpers := "varying float sky; global uniform float fx_snow; float leaf() { return fwidth(sky); } float middle() { return leaf(); } "
	var safe := helpers + "void fragment() { if (fx_snow > 0.01) { float x = middle(); } }"
	assert_eq(_derivative_errors(safe).size(), 0)
	var direct := helpers + "void fragment() { if (sky > 0.5) { float x = middle(); } }"
	var in_else := helpers + "void fragment() { if (sky > 0.5) { } else if (fx_snow > 0.01) { float x = middle(); } }"
	assert_gt(_derivative_errors(direct).size(), 0)
	assert_gt(_derivative_errors(in_else).size(), 0)


func test_control_checker_handles_loops_and_unbraced_statements() -> void:
	# 검사기 시험: 상수 for는 허용하고 화소별 for/while·중괄호 없는 if는 거부한다.
	var prefix := "varying float sky; void fragment() { "
	assert_eq(_derivative_errors(prefix + "for (int i = 0; i < 3; i++) { float x = fwidth(sky); } }").size(), 0)
	for statement: String in [
		"for (int i = 0; i < int(sky); i++) { float x = fwidth(sky); }",
		"while (sky > 0.5) { float x = fwidth(sky); }",
		"if (sky > 0.5) fwidth(sky);",
	]:
		assert_gt(_derivative_errors(prefix + statement + " }").size(), 0, statement)


func test_control_checker_handles_conditional_expressions_and_early_exit() -> void:
	# 검사기 시험: 삼항식·단락 평가·먼저 빠져나간 화소도 검사 우회로가 되지 않는다.
	var prefix := "varying float sky; void fragment() { "
	for statement: String in [
		"float x = sky > 0.5 ? fwidth(sky) : 0.0;",
		"bool x = sky > 0.5 && fwidth(sky) > 0.0;",
		"if (sky > 0.5) return; float x = fwidth(sky);",
	]:
		assert_gt(_derivative_errors(prefix + statement + " }").size(), 0, statement)
	assert_eq(_derivative_errors("uniform sampler2D tex; varying float sky; void fragment() { if (sky > 0.5) { vec4 a = textureGrad(tex, vec2(0.0), vec2(0.1), vec2(0.1)); vec4 b = textureLod(tex, vec2(0.0), 0.0); vec4 c = texelFetch(tex, ivec2(0), 0); } }").size(), 0, "명시적 밉·기울기는 허용")


func test_grass_order_checker_rejects_both_reordered_steps() -> void:
	# 검사기 시험: 보호를 덮임 반영 뒤로, bare_k 곱을 바닥 호출 앞으로 옮기면 실패한다.
	var source := _code()
	assert_eq(_grass_order_errors(source).size(), 0)
	var protect := "grass_holes *= 1.0 - smoothstep(0.0, 0.25, max(pile, bank));"
	var apply := "cover *= 1.0 - grass_holes;"
	var changed := source.replace(protect, "").replace(apply, apply + "\n" + protect)
	assert_ne(changed, source)
	assert_gt(_grass_order_errors(changed).size(), 0)
	var scale := "grass_share *= bare_k;"
	var call := "base = mix(base, bare_ground("
	changed = source.replace(scale, "").replace(call, scale + "\n" + call)
	assert_ne(changed, source)
	assert_gt(_grass_order_errors(changed).size(), 0)


func test_control_checker_rejects_shadowed_uniforms_and_changed_loop_counters() -> void:
	# 검사기 시험: 같은 이름의 인자는 uniform이 아니며, 본문이 바꾼 반복 변수도 상수가 아니다.
	var shadow := "uniform float amount; varying float sky; float helper(float amount) { if (amount > 0.5) { return fwidth(sky); } return 0.0; } void fragment() { float x = helper(sky); }"
	assert_gt(_derivative_errors(shadow).size(), 0)
	var loop := "varying float sky; void fragment() { for (int i = 0; i < 3; i++) { float x = fwidth(sky); i = int(sky); } }"
	assert_gt(_derivative_errors(loop).size(), 0)
