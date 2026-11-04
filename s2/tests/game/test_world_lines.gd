extends "res://addons/gut/test.gd"
## 세계 한 줄(world_lines.gd): 정지 가림막 아래에 멈출 때마다 하나씩 보이는 글. 줄마다 한 문장, 「다.」로 끝,
## 40자 안, 같은 줄 두 번 없음.

const WorldLines = preload("res://game/sim/world_lines.gd")


func test_each_line_is_one_short_sentence() -> void:
	assert_gt(WorldLines.LINES.size(), 10, "enough lines that a pause rarely meets the same one")
	var seen: Dictionary = {}
	for line: String in WorldLines.LINES:
		assert_lte(line.length(), WorldLines.LINE_MAX, line)
		assert_true(line.ends_with("다."), "ends in a full stop: " + line)
		assert_eq(line.count("."), 1, "one sentence: " + line)
		assert_false(line.contains("좀비") or line.contains("당신"), "game words only: " + line)
		assert_false(seen.has(line), "no line twice: " + line)
		seen[line] = true
