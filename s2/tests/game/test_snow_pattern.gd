extends "res://addons/gut/test.gd"
## PR2c: 눈 무늬·덤불 크기 구멍·미분의 실행 경로와 검사기 자체를 소스에서 확인한다.
## 화면과 셰이더 컴파일은 부른 세션에서 별도로 확인한다.

const SHADER_PATH := "res://game/world/world_vis.gdshader"
const SENSITIVE_CALLS := ["fwidth", "dFdx", "dFdy", "texture"]
const UNSUPPORTED_PREFIX := "검사기가 지원하지 않는 구문: "
const UNSUPPORTED_SHADER_WORDS := ["discard", "while", "for", "do", "break", "continue", "inout", "switch"]
const WRITE_OPERATORS := ["=", "+=", "-=", "*=", "/=", "%=", "<<=", ">>=", "&=", "|=", "^=", "++", "--"]
const DECLARATION_QUALIFIERS := ["const", "in", "out", "lowp", "mediump", "highp"]
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


func _strip_comments(source: String, keep_offsets := false) -> String:
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
	if keep_offsets:
		return "".join(parts)
	var lines: PackedStringArray = []
	for line: String in "".join(parts).split("\n"):
		lines.append(line.strip_edges())
	return "\n".join(lines)


func _tokens(source: String) -> Array[String]:
	return _lex(source)["tokens"]


func _lex(source: String) -> Dictionary:
	var regex := RegEx.new()
	var error := regex.compile("\"(?:\\\\.|[^\"\\\\])*\"|[A-Za-z_][A-Za-z_0-9]*|(?:[0-9]+(?:\\.[0-9]*)?|\\.[0-9]+)(?:[eE][+-]?[0-9]+)?|<<=|>>=|==|!=|<=|>=|&&|\\|\\||\\+\\+|--|\\+=|-=|\\*=|/=|%=|&=|\\|=|\\^=|<<|>>|[^\\s]")
	var result: Array[String] = []
	var offsets: Array[int] = []
	if error != OK:
		return {"tokens": result, "offsets": offsets}
	for found: RegExMatch in regex.search_all(source):
		result.append(found.get_string())
		offsets.append(found.get_start())
	return {"tokens": result, "offsets": offsets}


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


func _unsupported_error(errors: PackedStringArray, syntax: String) -> void:
	var message := UNSUPPORTED_PREFIX + syntax
	if not errors.has(message):
		errors.append(message)


func _function_headers(tokens: Array[String], pairs: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var at := 0
	while at + 1 < tokens.size():
		if tokens[at].is_valid_identifier() and tokens[at + 1] == "(":
			var close: int = pairs[at + 1]
			if close + 1 < tokens.size() and tokens[close + 1] == "{":
				var finish: int = pairs[close + 1]
				result.append({"name": tokens[at], "parameters": at + 2, "start": close + 1, "end": finish + 1})
				at = finish + 1
				continue
		at += 1
	return result


func _condition_start(tokens: Array[String], pairs: Dictionary, at: int, lower: int) -> int:
	var i := at - 1
	while i >= lower:
		if tokens[i] in [")", "]"]:
			i = int(pairs[i]) - 1
		elif tokens[i] in [";", "{", "}", "(", ",", ":", "?"]:
			return i + 1
		else:
			i -= 1
	return lower


func _unsupported_syntax(source: String, function_names: Dictionary, seen_includes: Dictionary) -> Dictionary:
	# 지원 경계는 여기서만 판정한다. include의 허용·식별·읽기도 같은 토큰과 원문 위치를 쓴다.
	var errors: PackedStringArray = []
	var includes: Array[Dictionary] = []
	var code := _strip_comments(source, true)
	var lexed := _lex(code)
	var tokens: Array[String] = lexed["tokens"]
	var offsets: Array[int] = lexed["offsets"]
	var paired := _paired_tokens(tokens)
	if paired.has("error"):
		return {"errors": PackedStringArray([String(paired["error"])]), "includes": includes}
	var pairs: Dictionary = paired["pairs"]
	var brace_depth := 0
	var paren_depth := 0
	var bracket_depth := 0
	for i in tokens.size():
		var token := tokens[i]
		if token == "{":
			brace_depth += 1
		elif token == "}":
			brace_depth -= 1
		elif token == "(":
			paren_depth += 1
		elif token == ")":
			paren_depth -= 1
		elif token == "[":
			bracket_depth += 1
		elif token == "]":
			bracket_depth -= 1
		if token in UNSUPPORTED_SHADER_WORDS or token == "struct":
			_unsupported_error(errors, token)
		if token in WRITE_OPERATORS and (paren_depth > 0 or bracket_depth > 0):
			_unsupported_error(errors, "괄호 안 대입")
		if token != "#":
			continue
		var directive := tokens[i + 1] if i + 1 < tokens.size() else ""
		if directive != "include":
			_unsupported_error(errors, "#" + directive)
			continue
		var line_start := source.rfind("\n", offsets[i]) + 1
		var line_end := source.find("\n", offsets[i])
		if line_end < 0:
			line_end = source.length()
		var valid := brace_depth == 0 and paren_depth == 0 and bracket_depth == 0 and i + 2 < tokens.size()
		valid = valid and source.substr(line_start, offsets[i] - line_start).strip_edges().is_empty()
		if valid:
			valid = offsets[i + 1] == offsets[i] + 1 and source.substr(offsets[i], 8) == "#include"
		var path := ""
		if valid:
			var quoted := tokens[i + 2]
			var quote_end := offsets[i + 2] + quoted.length()
			var gap := source.substr(offsets[i] + 8, offsets[i + 2] - offsets[i] - 8)
			valid = quote_end <= line_end and not gap.is_empty() and gap.strip_edges().is_empty()
			valid = valid and quoted.begins_with("\"res://") and quoted.ends_with("\"") and not quoted.contains("\\")
			if valid:
				valid = code.substr(quote_end, line_end - quote_end).strip_edges().is_empty()
				path = quoted.substr(1, quoted.length() - 2)
				valid = valid and path.simplify_path() == path
		if not valid:
			_unsupported_error(errors, "include 꼴")
		elif not seen_includes.has(path):
			var file := FileAccess.open(path, FileAccess.READ)
			if file == null:
				_unsupported_error(errors, "읽지 못한 include")
			else:
				var included_text := file.get_as_text()
				var read_error := file.get_error()
				file.close()
				if read_error != OK and read_error != ERR_FILE_EOF:
					_unsupported_error(errors, "읽지 못한 include")
				else:
					seen_includes[path] = true
					includes.append({"path": path, "source": included_text})
	var headers := _function_headers(tokens, pairs)
	var parameter_tokens := {}
	for info: Dictionary in headers:
		var name: String = info["name"]
		if function_names.has(name):
			_unsupported_error(errors, "같은 이름 함수 둘: " + name)
		function_names[name] = true
		var parameter_end := int(info["start"]) - 1
		var at := int(info["parameters"])
		for i in range(at, parameter_end):
			parameter_tokens[i] = true
		while at < parameter_end:
			while at < parameter_end and tokens[at] in DECLARATION_QUALIFIERS:
				at += 1
			if at < parameter_end and tokens[at] not in DECLARATION_TYPES:
				_unsupported_error(errors, "목록 밖 인자 타입: " + tokens[at])
			while at < parameter_end and tokens[at] != ",":
				if tokens[at] in ["(", "["]:
					at = int(pairs[at]) + 1
				else:
					at += 1
			at += 1
		var local_constants := {}
		for i in range(int(info["start"]) + 1, int(info["end"]) - 3):
			if tokens[i] != "const":
				continue
			var type_at := i + 1
			while type_at < int(info["end"]) - 2 and tokens[type_at] in DECLARATION_QUALIFIERS:
				type_at += 1
			if type_at + 1 < int(info["end"]) and tokens[type_at + 1].is_valid_identifier():
				local_constants[tokens[type_at + 1]] = true
		if local_constants.is_empty():
			continue
		for i in range(int(info["start"]) + 1, int(info["end"]) - 1):
			var first := -1
			var last := i
			if tokens[i] == "if" and tokens[i + 1] == "(":
				first = i + 2
				last = int(pairs[i + 1])
			elif tokens[i] in ["?", "&&", "||"]:
				first = _expression_start(tokens, _condition_start(tokens, pairs, i, int(info["start"]) + 1), i)
			if first < 0:
				continue
			for at_condition in range(first, last):
				if local_constants.has(tokens[at_condition]) and (at_condition == first or tokens[at_condition - 1] != "."):
					_unsupported_error(errors, "지역 const 조건")
	brace_depth = 0
	for i in range(tokens.size() - 2):
		if tokens[i] == "{":
			brace_depth += 1
		elif tokens[i] == "}":
			brace_depth -= 1
		if parameter_tokens.has(i) or not tokens[i].is_valid_identifier() or not tokens[i + 1].is_valid_identifier():
			continue
		if tokens[i] in DECLARATION_QUALIFIERS or tokens[i] in ["return", "else"]:
			continue
		if tokens[i] not in DECLARATION_TYPES:
			if brace_depth > 0:
				_unsupported_error(errors, "목록 밖 지역 타입: " + tokens[i])
			continue
		if tokens[i + 2] == "(":
			continue
		var finish := _statement_end(tokens, pairs, i, tokens.size())
		var at := i + 2
		var uniform_hint := false
		var initializer := false
		while at < finish:
			if tokens[at] in ["(", "[", "{"]:
				at = int(pairs[at]) + 1
			else:
				if tokens[at] == "=":
					initializer = true
					uniform_hint = false
				elif tokens[at] == ":" and not initializer and brace_depth == 0 and i > 0 and tokens[i - 1] == "uniform":
					uniform_hint = true
				elif tokens[at] == "," and not uniform_hint:
					_unsupported_error(errors, "여러 이름 선언")
				at += 1
	return {"errors": errors, "includes": includes}


func _included_source(source: String) -> Dictionary:
	var texts: PackedStringArray = []
	var queue: Array[Dictionary] = [{"path": SHADER_PATH, "source": source}]
	var seen := {SHADER_PATH: true}
	var function_names := {}
	var at := 0
	while at < queue.size():
		if queue.size() > 64:
			return {"error": "include가 64개를 넘음"}
		var unit: Dictionary = queue[at]
		var checked := _unsupported_syntax(String(unit["source"]), function_names, seen)
		var errors: PackedStringArray = checked["errors"]
		if not errors.is_empty():
			return {"unsupported": errors}
		texts.append(_strip_comments(String(unit["source"])))
		queue.append_array(checked["includes"])
		at += 1
	return {"source": "\n".join(texts)}


func _uniform_condition(tokens: Array[String], start: int, end: int, known: Dictionary) -> bool:
	for i in range(start, end):
		var token := tokens[i]
		if not token.is_valid_identifier() or (i > start and tokens[i - 1] == "."):
			continue
		if known.has(token) or token in DECLARATION_TYPES or token in ["true", "false", "const"]:
			continue
		if token in CONDITION_BUILTINS and i + 1 < end and tokens[i + 1] == "(":
			continue
		return false
	return true


func _guarded(state: Dictionary, start: int, end: int, guards: Array[String], label: String) -> Array[String]:
	var next: Array[String] = guards.duplicate()
	var tokens: Array[String] = state["tokens"]
	if not _uniform_condition(tokens, start, end, state["known"]):
		next.append(label + "(" + " ".join(PackedStringArray(tokens.slice(start, end))) + ")")
	return next


func _statement_end(tokens: Array[String], pairs: Dictionary, start: int, end: int, depth := 0) -> int:
	if start >= end or depth > 128:
		return end
	if tokens[start] == "{":
		return int(pairs[start]) + 1
	if tokens[start] == "if" and start + 1 < end and tokens[start + 1] == "(":
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
	# 최상위 선언·대입만 뺀다. 괄호 안 대입은 _unsupported_syntax에서 거절한다.
	var first := start + 1 if start < end and tokens[start] == "return" else start
	var depth := 0
	for i in range(start, end):
		if tokens[i] in ["(", "["]:
			depth += 1
		elif tokens[i] in [")", "]"]:
			depth -= 1
		elif depth == 0 and tokens[i] in WRITE_OPERATORS:
			first = i + 1
	return first


func _scan_expression(state: Dictionary, start: int, end: int, guards: Array[String], depth := 0) -> void:
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
			_scan_expression(state, start, i, guards, depth + 1)
			_scan_expression(state, i + 1, end, guards, depth + 1)
			return
		elif tokens[i] in ["&&", "||"] and split < 0 and question < 0:
			split = i
		i += 1
	if question >= 0 and colon > question:
		_scan_expression(state, start, question, guards, depth + 1)
		var next := _guarded(state, _expression_start(tokens, start, question), question, guards, "?:")
		_scan_expression(state, question + 1, colon, next, depth + 1)
		_scan_expression(state, colon + 1, end, next, depth + 1)
		return
	if split >= 0:
		_scan_expression(state, start, split, guards, depth + 1)
		var next := _guarded(state, _expression_start(tokens, start, split), split, guards, tokens[split])
		_scan_expression(state, split + 1, end, next, depth + 1)
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
			_scan_expression(state, i + 2, close, guards, depth + 1)
			i = close + 1
		elif tokens[i] in ["(", "["]:
			var close: int = pairs[i]
			_scan_expression(state, i + 1, close, guards, depth + 1)
			i = close + 1
		else:
			i += 1


func _scan_statement(state: Dictionary, start: int, end: int, guards: Array[String], depth := 0) -> int:
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
			var following := _scan_statement(state, i, block_end, guards, depth + 1)
			if following <= i:
				state["errors"].append("문장 경계를 찾지 못함")
				return block_end + 1
			i = following
		return block_end + 1
	if token == "if":
		if start + 1 >= end or tokens[start + 1] != "(":
			state["errors"].append("제어문 조건 괄호가 없음")
			return end
		var condition_end: int = pairs[start + 1]
		_scan_expression(state, start + 2, condition_end, guards)
		var next_guards := _guarded(state, start + 2, condition_end, guards, token)
		var after_body := _scan_statement(state, condition_end + 1, end, next_guards, depth + 1)
		if after_body < end and tokens[after_body] == "else":
			after_body = _scan_statement(state, after_body + 1, end, next_guards, depth + 1)
		return after_body
	var statement_end := _statement_end(tokens, pairs, start, end)
	_scan_expression(state, start, statement_end, guards)
	if token == "return" and not guards.is_empty():
		state["returns"].append({"at": start, "guards": guards.duplicate()})
	return statement_end


func _derivative_errors(source: String) -> PackedStringArray:
	# 호출 그래프의 고정점으로, 분기 안에서 부른 함수의 그 아래 호출까지 따라간다.
	var errors: PackedStringArray = []
	var included := _included_source(source)
	if included.has("unsupported"):
		return PackedStringArray(included["unsupported"])
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
	var brace_depth := 0
	for i in tokens.size():
		if tokens[i] == "{":
			brace_depth += 1
		elif tokens[i] == "}":
			brace_depth -= 1
		elif brace_depth == 0 and i + 2 < tokens.size() and tokens[i] in ["uniform", "const"]:
			known[tokens[i + 2]] = true
	var functions := {}
	for info: Dictionary in _function_headers(tokens, pairs):
		functions[info["name"]] = info
	for name: String in functions:
		var info: Dictionary = functions[name]
		var visible: Dictionary = known.duplicate()
		# 인자·지역 변수가 같은 이름의 uniform을 가리면 uniform으로 판정하지 않는다.
		for i in range(int(info["parameters"]), int(info["end"]) - 2):
			if tokens[i] in DECLARATION_TYPES and tokens[i + 1].is_valid_identifier() and tokens[i + 2] != "(" and tokens[i - 1] != "const":
				visible.erase(tokens[i + 1])
		info.merge({"tokens": tokens, "pairs": pairs, "known": visible, "functions": functions, "ops": [], "calls": [], "returns": [], "errors": []})
		var initial_guards: Array[String] = []
		_scan_statement(info, int(info["start"]), int(info["end"]), initial_guards)
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
			for prior_return: Dictionary in info["returns"]:
				if int(prior_return["at"]) < int(site["at"]):
					guards.append_array(prior_return["guards"])
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
		"floatsnow_fine=0.5;",
		"vec2snow_fine_p=vec2(0.0);",
		"vec2patch_p=snow_p*(is_ground?0.09:0.15);",
		"vec2fine_p=is_ground?snow_p*1.1:patch_p*3.1;",
		"vec2warp_p=is_ground?snow_p*0.125:patch_p*0.5;",
		"snow_fine_p=fine_p+1.4*warp+vec2(5.3,11.9);",
		"snow_fine=fx_vnoise(snow_fine_p);",
		"floatsnow_patch=(is_ground?0.8:0.72)*fx_vnoise(patch_p+0.7*warp)+(is_ground?0.2:0.28)*snow_fine;",
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


func _grass_base_contract_errors(source: String) -> PackedStringArray:
	var code := _compact(_strip_comments(source))
	var errors: PackedStringArray = []
	for expression: String in [
		"constfloatTHIN_SNOW_GRASS_BASE=0.11;",
		"floatgrass_holes=grass_share*thin_snow*mix(THIN_SNOW_GRASS_BASE,1.0,grass_cut);",
	]:
		if code.count(expression) != 1:
			errors.append("얇은 눈 바탕 풀빛 식 누락·중복: " + expression)
	return errors


func _grass_order_errors(source: String) -> PackedStringArray:
	var code := _compact(_strip_comments(source))
	var expressions := [
		"bare_ground(kind,ground_detail,base,world_pos.xz,grain,ground_dx,ground_dy,grass_share)",
		"grass_share*=bare_k;",
		"floatgrass_holes=grass_share*thin_snow*mix(THIN_SNOW_GRASS_BASE,1.0,grass_cut);",
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


func _write_statements(tokens: Array[String], pairs: Dictionary, start: int, end: int, name: String) -> Array[String]:
	var result: Array[String] = []
	for i in range(start, end):
		if tokens[i] != name:
			continue
		if tokens[i + 1] not in WRITE_OPERATORS and tokens[i - 1] not in ["++", "--"]:
			continue
		var first := i
		while first > start and tokens[first - 1] not in [";", "{", "}"]:
			first -= 1
		var last := _statement_end(tokens, pairs, first, end)
		result.append("".join(PackedStringArray(tokens.slice(first, last))))
	return result


func _single_assignment_errors(source: String) -> PackedStringArray:
	# 이 세 값은 선언과 최종 소비 두 자리만 허용한다. 별도 호출에 넘기는 것도 거절한다.
	var errors: PackedStringArray = []
	var tokens := _tokens(_strip_comments(source))
	var paired := _paired_tokens(tokens)
	if paired.has("error"):
		errors.append(String(paired["error"]))
		return errors
	var pairs: Dictionary = paired["pairs"]
	var opening := -1
	for i in range(tokens.size() - 2):
		if tokens[i] == "void" and tokens[i + 1] == "fragment" and tokens[i + 2] == "(":
			var after_parameters := int(pairs[i + 2]) + 1
			if after_parameters < tokens.size() and tokens[after_parameters] == "{":
				opening = after_parameters
			break
	if opening < 0:
		errors.append("단일 대입 검사: fragment 본문이 없음")
		return errors
	var closing: int = pairs[opening]
	for name: String in ["prop_cover", "ground_cover", "grass_cut"]:
		var uses: Array[int] = []
		for i in range(opening + 1, closing):
			if tokens[i] == name:
				uses.append(i)
		if uses.size() != 2:
			errors.append("단일 선언·최종 사용 횟수 오류: " + name)
			continue
		var writes := 0
		for at: int in uses:
			if tokens[at + 1] in WRITE_OPERATORS or tokens[at - 1] in ["++", "--"]:
				writes += 1
		if tokens[uses[0] - 1] != "float" or tokens[uses[0] + 1] != "=" or writes != 1:
			errors.append("선언 뒤 덮어쓰기 또는 선언 전 사용: " + name)
	# 71be4d57의 모든 최종 쓰기를 순서대로 잠근다. 정상 식 뒤의 추가 쓰기도 거절한다.
	var expected_writes := {
		"thin_snow": [
			"floatthin_snow=smoothstep(0.25,0.4,local_snow)*(1.0-smoothstep(0.5,0.65,local_snow));",
		],
		"grass_holes": [
			"floatgrass_holes=grass_share*thin_snow*mix(THIN_SNOW_GRASS_BASE,1.0,grass_cut);",
			"grass_holes*=1.0-smoothstep(0.0,0.25,max(pile,bank));",
		],
		"cover": [
			"floatcover=0.0;",
			"cover=is_ground?0.97*ground_cover:prop_cover;",
			"cover*=smoothstep(0.6,0.9,up)*sky*(1.0-smoothstep(0.08,0.3,chroma));",
			"cover*=0.25;",
			"cover=max(cover,0.8*clamp(bank,0.0,1.0));",
			"cover=max(cover,1.0*pile*heaped);",
			"cover*=1.0-0.9*trodden;",
			"cover*=1.0-grass_holes;",
		],
	}
	for name: String in expected_writes:
		if _write_statements(tokens, pairs, opening + 1, closing, name) != expected_writes[name]:
			errors.append("쓰기 목록·순서 오류: " + name)
	var body := "".join(PackedStringArray(tokens.slice(opening + 1, closing)))
	if not body.contains("cover=is_ground?0.97*ground_cover:prop_cover;"):
		errors.append("두 눈 덮임 값을 최종 cover에서 사용하지 않음")
	if not body.contains("floatgrass_holes=grass_share*thin_snow*mix(THIN_SNOW_GRASS_BASE,1.0,grass_cut);"):
		errors.append("덤불 마스크를 grass_holes에서 사용하지 않음")
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
	# 35c73dc8에서는 실패 예상: 잔 결 호출을 구멍과 공유하는 지역 값이 없다.
	var snow := _compact(_snow_code())
	assert_true(snow.contains("floatsnow_patch=(is_ground?0.8:0.72)*fx_vnoise(patch_p+"))
	assert_true(snow.contains("+(is_ground?0.2:0.28)*snow_fine;"))
	assert_eq(snow.count("snow_fine=fx_vnoise(snow_fine_p);"), 1)


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
	# include 철자 판정에는 주석을 지우기 전 원문을 넘긴다.
	var errors := _derivative_errors(FileAccess.get_file_as_string(SHADER_PATH))
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
	# 35c73dc8에서는 실패 예상: 사진의 높은 알파가 구멍 본체이고 잔 결의 낮은 꼬리를 쓰지 않는다.
	var fragment := _block(_code(), "void fragment() {")
	var code := _compact(fragment)
	assert_true(code.contains("floatgrass_threshold=0.30+clamp((wander-1.0)*(0.02/0.45),-0.02,0.02);"))
	assert_true(code.contains("floatgrass_cell_edge=0.13-length(fract(snow_fine_p+vec2(0.5))-vec2(0.5));"))
	assert_true(code.contains("floatgrass_edge=min(grass_threshold-snow_fine,grass_cell_edge)+(grain.a-0.5)*0.01;"), "낮은 꼬리·크기 제한·테두리 결을 함께 미분")
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
	assert_true(code.contains("floatgrass_holes=grass_share*thin_snow*mix(THIN_SNOW_GRASS_BASE,1.0,grass_cut);"), "풀 몫이 0이면 구멍도 0")
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


func test_tufts_reuse_the_fine_noise_sample_and_its_position() -> void:
	# 35c73dc8에서는 실패 예상: 눈 잔 결 값·좌표를 눈 블록 밖으로 넘기지 않는다.
	var fragment := _block(_code(), "void fragment() {")
	var snow := _compact(_snow_code())
	var gate_at := fragment.find("if (fx_snow > 0.01) {")
	var value_at := fragment.find("float snow_fine = 0.5;")
	var position_at := fragment.find("vec2 snow_fine_p = vec2(0.0);")
	assert_gte(value_at, 0)
	assert_gte(position_at, 0)
	assert_lt(value_at, gate_at, "눈 없을 때 중립값")
	assert_lt(position_at, gate_at)
	assert_true(snow.contains("snow_fine_p=fine_p+1.4*warp+vec2(5.3,11.9);"))
	assert_eq(snow.count("snow_fine=fx_vnoise(snow_fine_p);"), 1)
	assert_eq(snow.count("fx_vnoise("), 5, "덤불을 위해 노이즈를 다시 부르지 않음")


func test_tufts_replace_the_area_table_and_only_fade_below_two_pixels() -> void:
	# 35c73dc8에서는 실패 예상: 놀이 줌에서 구멍을 전부 평균 면적으로 바꾸는 표가 남아 있다.
	var code := _compact(_code())
	for obsolete: String in ["GRASS_HOLE_AREAS", "grass_hole_area(", "GRASS_HOLE_FADE_", "grass_mean", "grass_far"]:
		assert_false(code.contains(obsolete), "밀리미터 사진 구멍용 경로 제거: " + obsolete)
	assert_true(code.contains("floatgrass_px=max(length(ground_dx),length(ground_dy));"))
	assert_true(code.contains("floatgrass_resolve=1.0-smoothstep(0.05,0.1,grass_px);"), "10 cm 덤불이 2→1 화소가 될 때만 옅게")
	assert_true(code.contains("floatgrass_cut=smoothstep(-grass_w,grass_w,grass_edge)*grass_resolve;"))
	var pitch := sin(deg_to_rad(35.0))
	for height: float in [780.0, 1080.0]:
		var play_pixel := 20.0 / height / pitch
		var far_pixel := 36.0 / height / pitch
		assert_gt(0.10 / play_pixel, 2.0, "기본 줌의 작은 덤불도 두 화소 이상")
		assert_eq(1.0 - smoothstep(0.05, 0.1, play_pixel), 1.0, "기본 줌에서 면적 평균·소실 없음")
		assert_lt(0.10 / far_pixel, 2.0, "가장 먼 줌에서는 작은 덤불이 두 화소 미만")
		assert_between(1.0 - smoothstep(0.05, 0.1, far_pixel), 0.0, 1.0)


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


func test_control_checker_handles_unbraced_if_statements() -> void:
	var source := "varying float sky; void fragment() { if (sky > 0.5) fwidth(sky); }"
	assert_gt(_derivative_errors(source).size(), 0)


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


func test_control_checker_rejects_shadowed_uniform_parameters() -> void:
	# 검사기 시험: 같은 이름의 함수 인자는 전역 uniform이 아니다.
	var shadow := "uniform float amount; varying float sky; float helper(float amount) { if (amount > 0.5) { return fwidth(sky); } return 0.0; } void fragment() { float x = helper(sky); }"
	assert_gt(_derivative_errors(shadow).size(), 0)


func test_control_checker_rejects_each_unsupported_syntax() -> void:
	# 35c73dc8 검사기에서는 실패 예상: 지원하지 않을 구문도 일부 분석해 통과시킨다.
	var cases := {
		"#define": "#define VALUE 1.0\nvoid fragment() {}",
		"#if": "#if 1\nvoid fragment() {}\n#endif",
		"#ifdef": "#ifdef VALUE\nvoid fragment() {}\n#endif",
		"#ifndef": "#ifndef VALUE\nvoid fragment() {}\n#endif",
		"#pragma": "#pragma unknown\nvoid fragment() {}",
		"discard": "void fragment() { discard; }",
		"while": "void fragment() { while (false) {} }",
		"for": "void fragment() { for (int i = 0; i < 1; i++) {} }",
		"do": "void fragment() { do {} while (false); }",
		"break": "void fragment() { for (int i = 0; i < 1; i++) { break; } }",
		"continue": "void fragment() { for (int i = 0; i < 1; i++) { continue; } }",
		"inout": "void helper(inout float x) {} void fragment() { float x = 0.0; helper(x); }",
	}
	for syntax: String in cases:
		var errors := _derivative_errors(String(cases[syntax]))
		assert_true(errors.has(UNSUPPORTED_PREFIX + syntax), syntax)
		assert_eq(errors.count(UNSUPPORTED_PREFIX + syntax), 1, "구문마다 진단 한 줄: " + syntax)


func test_control_checker_rejects_duplicate_function_names() -> void:
	# 35c73dc8 검사기에서는 실패 예상: 같은 이름 함수의 뒤 정의로 앞 정의를 덮어쓴다.
	var source := "float helper(float x) { return x; } float helper(vec2 x) { return x.x; } void fragment() {}"
	assert_true(_derivative_errors(source).has(UNSUPPORTED_PREFIX + "같은 이름 함수 둘: helper"))


func test_local_const_does_not_make_a_varying_uniform_in_another_function() -> void:
	# 35c73dc8 검사기에서는 실패 예상: 다른 함수의 지역 const가 전역 허용 이름에 섞인다.
	var source := "varying float sky; float helper() { const float sky = 1.0; return sky; } void fragment() { if (sky > 0.5) { float x = fwidth(sky); } }"
	assert_gt(_derivative_errors(source).size(), 0)


func test_unsupported_words_in_comments_are_ignored() -> void:
	var source := "// #define for while discard\n/* #if #ifdef do break continue inout */\nvoid fragment() {}"
	assert_eq(_derivative_errors(source).size(), 0)


func test_cover_values_and_tuft_mask_are_declared_once_and_consumed() -> void:
	var errors := _single_assignment_errors(_code())
	assert_eq(errors.size(), 0, "\n".join(errors))


func test_single_assignment_checker_rejects_cover_and_mask_overwrites() -> void:
	# 검사기 시험: 정상 식이 남아 있어도 실제 소비 직전 덮어쓰면 실패해야 한다.
	var source := _code()
	assert_eq(_single_assignment_errors(source).size(), 0)
	for name: String in ["prop_cover", "ground_cover"]:
		var before_use := "cover = is_ground ? 0.97 * ground_cover : prop_cover;"
		var changed := source.replace(before_use, name + " = 0.0;\n" + before_use)
		assert_ne(changed, source)
		assert_gt(_single_assignment_errors(changed).size(), 0, name)
	var before_holes := "float grass_holes ="
	var changed := source.replace(before_holes, "grass_cut = 0.0;\n" + before_holes)
	assert_ne(changed, source)
	assert_gt(_single_assignment_errors(changed).size(), 0)


func test_final_snow_writes_reject_three_late_overwrites() -> void:
	# 71be4d57에서는 실패 예상: thin_snow·grass_holes·마지막 cover 덮어쓰기를 놓친다.
	var source := _code()
	var thin := "float thin_snow = smoothstep(0.25, 0.4, local_snow) * (1.0 - smoothstep(0.5, 0.65, local_snow));"
	var apply := "cover *= 1.0 - grass_holes;"
	var paint := "base = mix(base, FX_SNOW"
	for changed: String in [
		source.replace(thin, thin + "\nthin_snow = 1.0;"),
		source.replace(apply, "grass_holes = 0.0;\n" + apply),
		source.replace(paint, "cover = 0.0;\n" + paint),
	]:
		assert_ne(changed, source)
		assert_gt(_single_assignment_errors(changed).size(), 0)


func test_cover_write_sequence_rejects_missing_or_reordered_steps() -> void:
	# 71be4d57에서는 실패 예상: 최종 선택 외의 cover 쓰기 목록·순서를 검사하지 않는다.
	var source := _code()
	var cleared := "cover *= 0.25;"
	var bank := "cover = max(cover, 0.8 * clamp(bank, 0.0, 1.0));"
	var reordered := source.replace(cleared, "__swap_cover_write__").replace(bank, cleared).replace("__swap_cover_write__", bank)
	var qualified := source.replace("float cover = 0.0;", "highp float cover = 0.0;")
	for changed: String in [source.replace(cleared, ""), reordered, qualified]:
		assert_ne(changed, source)
		assert_gt(_single_assignment_errors(changed).size(), 0)


func test_include_syntax_rejects_spacing_comments_and_nested_directives() -> void:
	# 71be4d57에서는 실패 예상: 허용 토큰과 실제 읽기 정규식이 다른 꼴을 받아들인다.
	var path := "\"res://fx/shaders/fx_common.gdshaderinc\""
	for source: String in [
		"# include " + path + "\nvoid fragment() {}",
		"#/**/include " + path + "\nvoid fragment() {}",
		"void fragment() {\n#include " + path + "\n}",
		"void fragment() { if (true) {\n#include " + path + "\n} }",
		"float x; #include " + path + "\nvoid fragment() {}",
	]:
		assert_true(_derivative_errors(source).has(UNSUPPORTED_PREFIX + "include 꼴"), source)
	assert_true(_derivative_errors("#include \"res://__pr2c_missing_include__.gdshaderinc\"\nvoid fragment() {}").has(UNSUPPORTED_PREFIX + "읽지 못한 include"))


func test_parenthesized_assignment_is_unsupported_in_a_condition() -> void:
	# 71be4d57에서는 실패 예상: 안쪽 = 뒤만 조건으로 보고 sky 조건을 잃는다.
	var source := "varying float sky; void fragment() { bool flag = false; float x = (sky > 0.5 && (flag = true)) ? fwidth(sky) : 0.0; }"
	assert_true(_derivative_errors(source).has(UNSUPPORTED_PREFIX + "괄호 안 대입"))
	for comparison: String in ["==", "!=", "<=", ">="]:
		var compared := "uniform float amount; varying float sky; void fragment() { float x = (amount " + comparison + " 1.0) ? fwidth(sky) : 0.0; }"
		assert_eq(_derivative_errors(compared).size(), 0, comparison)


func test_multiple_declarations_cannot_hide_a_uniform_name() -> void:
	# 71be4d57에서는 실패 예상: 둘째 선언 amount를 지역 변수로 수집하지 않는다.
	var source := "uniform float amount; varying float sky; void fragment() { float a = 1.0, amount = sky; if (amount > 0.5) { float x = fwidth(sky); } }"
	assert_true(_derivative_errors(source).has(UNSUPPORTED_PREFIX + "여러 이름 선언"))
	var hinted := "uniform sampler2D tex : filter_nearest, repeat_disable; varying float sky; void fragment() { float x = texture(tex, vec2(sky)).r; }"
	assert_eq(_derivative_errors(hinted).size(), 0, "uniform 힌트의 쉼표는 변수 선언이 아님")


func test_unlisted_local_and_parameter_types_are_unsupported() -> void:
	# 71be4d57에서는 실패 예상: 목록 밖 타입이 전역 uniform과 같은 이름을 가려도 놓친다.
	var local := "uniform float amount; varying float sky; void fragment() { uvec2 amount = uvec2(1); if (amount.x > uint(0)) { float x = fwidth(sky); } }"
	var parameter := "uniform float amount; varying float sky; float helper(uvec2 amount) { if (amount.x > uint(0)) { return fwidth(sky); } return 0.0; } void fragment() {}"
	var custom := "struct Pair { float x; }; uniform float amount; varying float sky; float helper(Pair amount) { if (amount.x > 0.5) { return fwidth(sky); } return 0.0; } void fragment() {}"
	assert_true(_derivative_errors(local).has(UNSUPPORTED_PREFIX + "목록 밖 지역 타입: uvec2"))
	assert_true(_derivative_errors(parameter).has(UNSUPPORTED_PREFIX + "목록 밖 인자 타입: uvec2"))
	assert_true(_derivative_errors(custom).has(UNSUPPORTED_PREFIX + "목록 밖 인자 타입: Pair"))


func test_local_const_condition_has_an_explicit_unsupported_reason() -> void:
	# 71be4d57에서는 실패 예상: 거절은 하지만 지역 const 조건이라는 이유를 구분하지 않는다.
	for body: String in [
		"const bool ready = true; if (ready) { float x = fwidth(sky); }",
		"const highp float ready = 1.0; float x = ready > 0.5 ? fwidth(sky) : 0.0;",
		"const bool ready = true; bool x = ready && fwidth(sky) > 0.0;",
	]:
		var source := "varying float sky; void fragment() { " + body + " }"
		assert_true(_derivative_errors(source).has(UNSUPPORTED_PREFIX + "지역 const 조건"), body)


func test_thin_snow_grass_base_is_one_fraction_constant() -> void:
	# 0af097d3 셰이더에서는 실패 예상: 바탕 풀빛 상수가 없다.
	var code := _compact(_code())
	var found := _match(code, "constfloatTHIN_SNOW_GRASS_BASE=([0-9.]+);")
	if found == null:
		return
	var value := float(found.get_string(1))
	assert_gt(value, 0.0)
	assert_lt(value, 1.0)
	assert_almost_eq(value, 0.11, 0.000001, "코디 11-07의 바탕 풀빛 몫")
	assert_eq(code.count("constfloatTHIN_SNOW_GRASS_BASE="), 1)
	assert_eq(code.count("THIN_SNOW_GRASS_BASE"), 2, "선언과 구멍 식에서만 사용")
	var before := code.substr(0, found.get_start())
	assert_eq(before.count("{") - before.count("}"), 0, "맨 바깥 상수")


func test_grass_base_uses_the_thin_window_and_keeps_full_tufts() -> void:
	# 0af097d3 셰이더에서는 실패 예상: 덤불 밖의 얇은 눈에 바탕 몫을 더하지 않는다.
	var source := _code()
	var errors := _grass_base_contract_errors(source)
	assert_eq(errors.size(), 0, "\n".join(errors))
	var found := _match(_compact(source), "constfloatTHIN_SNOW_GRASS_BASE=([0-9.]+);")
	if found == null:
		return
	var value := float(found.get_string(1))
	assert_eq(lerpf(value, 1.0, 1.0), 1.0, "덤불 자리의 최대 구멍은 그대로")
	assert_eq(lerpf(value, 1.0, 0.0), value, "덤불 밖에만 바탕 몫")
	for depth: float in [0.0, 0.25, 0.65, 1.0]:
		var thin := smoothstep(0.25, 0.4, depth) * (1.0 - smoothstep(0.5, 0.65, depth))
		assert_eq(thin * lerpf(value, 1.0, 0.0), 0.0, "얇은 눈 창 밖에서 바탕도 0")
		assert_eq(thin * lerpf(value, 1.0, 1.0), 0.0, "얇은 눈 창 밖에서 덤불도 0")


func test_grass_base_contract_rejects_distance_coupling() -> void:
	# 0af097d3 셰이더에서는 정상 식 선행 조건부터 실패한다.
	var source := _code()
	assert_eq(_grass_base_contract_errors(source).size(), 0)
	var line := "float grass_holes = grass_share * thin_snow * mix(THIN_SNOW_GRASS_BASE, 1.0, grass_cut);"
	for distance: String in ["grass_far", "grass_px"]:
		var replacement := line.replace("mix(THIN_SNOW_GRASS_BASE,", "mix(THIN_SNOW_GRASS_BASE * " + distance + ",")
		var prefix := "float grass_far = smoothstep(0.05, 0.1, grass_px);\n" if distance == "grass_far" else ""
		var changed := source.replace(line, prefix + replacement)
		assert_ne(changed, source)
		assert_gt(_grass_base_contract_errors(changed).size(), 0, distance)


func test_grass_base_contract_rejects_a_base_outside_thin_snow() -> void:
	# 0af097d3 셰이더에서는 정상 식 선행 조건부터 실패한다.
	var source := _code()
	assert_eq(_grass_base_contract_errors(source).size(), 0)
	var line := "float grass_holes = grass_share * thin_snow * mix(THIN_SNOW_GRASS_BASE, 1.0, grass_cut);"
	var changed := source.replace(line, "float grass_holes = grass_share * (THIN_SNOW_GRASS_BASE + thin_snow * (1.0 - THIN_SNOW_GRASS_BASE) * grass_cut);")
	assert_ne(changed, source)
	assert_gt(_grass_base_contract_errors(changed).size(), 0)

