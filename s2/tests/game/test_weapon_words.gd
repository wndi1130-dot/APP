extends GutTest
## Every weapon has its two lines and every make its one (결정 531), each short
## enough for one line of the bag's window and ending as a plain sentence.

const W = preload("res://game/sim/weapons.gd")
const Words = preload("res://game/sim/weapon_words.gd")


func _sorted(keys: Array) -> Array:
	var out: Array = keys.duplicate()
	out.sort()
	return out


func test_every_weapon_has_a_line_of_what_it_does_and_one_of_the_world() -> void:
	var ids: Array = _sorted(W.DATA.keys() + W.IMPROVISED.keys())
	assert_eq(ids.size(), 10, "seven weapons and three improvised ones")
	assert_eq(_sorted(Words.DESC.keys()), ids)
	assert_eq(_sorted(Words.FLAVOR.keys()), ids)


func test_every_make_of_gun_has_its_line() -> void:
	assert_eq(_sorted(Words.QUALITY_LINE.keys()), _sorted(W.QUALITY.keys()))


func test_each_line_fits_and_ends_as_a_plain_sentence() -> void:
	var tables: Array = [[Words.DESC, Words.DESC_MAX], [Words.FLAVOR, Words.FLAVOR_MAX], [Words.QUALITY_LINE, Words.QUALITY_MAX]]
	for row: Array in tables:
		var lines: Dictionary = row[0]
		var most: int = row[1]
		for key: String in lines:
			var line: String = String(lines[key])
			assert_lte(line.length(), most, "%s is %d long: %s" % [key, line.length(), line])
			assert_true(line.ends_with("다."), "%s ends as a plain sentence: %s" % [key, line])
			assert_eq(line.strip_edges(), line, "%s has no spaces at its ends" % key)
			assert_false(line.contains(":"), "%s has no colon" % key)
