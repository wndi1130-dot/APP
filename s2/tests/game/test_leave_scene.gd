extends "res://addons/gut/test.gd"
## The stop's closing scene (user decision 183): a head line and four columns
## read off the stop's own record. People are numbers, never names.

const LeaveScene = preload("res://game/ui/leave_scene.gd")
const FieldGame = preload("res://game/field_game.gd")
const FieldHud = preload("res://game/ui/field_hud.gd")
const FieldGrid = preload("res://game/world/field_grid.gd")


func _result(stock: Dictionary = {}, people: Dictionary = {}, place: Dictionary = {}, gained: Array = []) -> Dictionary:
	var state := {"looted": 1.0, "remainingRisk": 0}
	state.merge(place, true)
	return {"receipt": {"stock": stock, "people": people, "items": {"gained": gained}, "placeState": state}, "boarded": 4, "stay": 12, "hordes": 0, "places": 6, "dead_about": 0}


func test_the_head_line_goes_by_the_heaviest_thing_in_the_record() -> void:
	assert_eq(LeaveScene.head(_result()), ["빈손으로 떠났다", "게임 12분을 머물렀다 · 무리는 오지 않았다"])
	assert_eq(LeaveScene.head(_result({"coal": 6, "info": 9, "ammo_pistol": -4}))[0], "정보를 싣고 떠났다")
	assert_eq(LeaveScene.head(_result({"coal": 6}))[0], "석탄을 싣고 떠났다")
	assert_eq(LeaveScene.head(_result({"coal": 6}, {"injured": ["a"]}))[0], "다친 사람을 태우고 떠났다")
	assert_eq(LeaveScene.head(_result({"coal": 6}, {"injured": ["a"], "bitten": ["a"]}))[0], "물린 사람을 태우고 떠났다")
	assert_eq(LeaveScene.head(_result({"coal": 6}, {"bitten": ["a"], "leftBehind": ["b"]}))[0], "다 태우지 못하고 떠났다")
	assert_eq(LeaveScene.head(_result({"coal": 6}, {"leftBehind": ["b"], "dead": ["c"]}))[0], "돌아오지 못한 사람이 있다")
	var busy := _result()
	busy["hordes"] = 2
	assert_eq(String(LeaveScene.head(busy)[1]), "게임 12분을 머물렀다 · 무리 2번")


func test_the_four_columns_stand_side_by_side_and_say_nothing_when_empty() -> void:
	var bare: Array = LeaveScene.columns(_result())
	assert_eq(bare, [["실은 것", ["없다"]], ["탄 사람", ["4명", "모두 탔다"]], ["다친 사람", ["없다"]], ["남긴 것", ["없다"]]])
	var record := _result(
		{"coal": 2, "food": 7, "scrap": 3, "wood": 1, "medicine": 5, "ammo_shell": -2},
		{"bitten": ["a"], "injured": ["a", "b"], "dead": ["c"], "leftBehind": ["d", "e"]},
		{"looted": 0.3, "waterTower": "frozen"}, ["symbol_bell"])
	record["dead_about"] = 1
	var full: Array = LeaveScene.columns(record)
	assert_eq(full[0], ["실은 것", ["식량 7", "의약품 5", "고철 3", "석탄 2"]], "most first, four at the most, nothing that went down")
	assert_eq(full[1], ["탄 사람", ["4명"]])
	assert_eq(full[2], ["다친 사람", ["물린 사람 1", "다친 사람 2", "죽은 사람 1"]])
	assert_eq(full[3], ["남긴 것", ["못 탄 사람 2", "뒤지지 않은 곳이 많다", "얼어 있는 급수탑", "망자"]], "one of the dead still about is said")
	var nothing_to_search := _result({}, {}, {"looted": 0.0})
	nothing_to_search["places"] = 0
	assert_eq(LeaveScene.columns(nothing_to_search)[3], ["남긴 것", ["없다"]], "a map with nothing to search left nothing unsearched")
	assert_eq(LeaveScene.columns(_result({}, {}, {"looted": 0.7}, ["symbol_bell"]))[0], ["실은 것", ["출발 종"]])
	assert_eq(LeaveScene.columns(_result({}, {}, {"looted": 0.7}))[3], ["남긴 것", ["뒤지지 못한 곳이 있다"]])


func test_a_plain_stop_closes_on_the_scene_with_no_name_in_it() -> void:
	var game = FieldGame.new()
	game.opts = {"seed": 5, "raiders": false, "auto_pause": false}
	add_child_autofree(game)
	game.set_process(false)
	game.depart()
	assert_true(game.ended)
	var words: Control = game.hud.leaving["words"]
	var said: Array = []
	for l in words.find_children("*", "Label", true, false):
		said.append(l.text)
	for title in ["실은 것", "탄 사람", "다친 사람", "남긴 것"]:
		assert_true(said.has(title), title)
	for p in game.people:
		for line in said:
			assert_false(String(line).contains(p.display_name), "a number, never a name")


# The train rolls away with whoever boarded; who stayed is still drawn where
# they stand, and the end card gives them as a number.
func test_the_train_rolls_away_and_who_stayed_stands_there() -> void:
	var game = FieldGame.new()
	game.opts = {"seed": 5, "raiders": false, "auto_pause": false}
	add_child_autofree(game)
	game.set_process(false)
	var late = game.squad[2]
	late.position = FieldGrid.center(Vector2i(2, 2))
	assert_eq(game.view.train_node.position.x, 0.0, "it stands")
	game.depart()
	assert_true(game.ended)
	assert_true(game.rode_off.has(game.player))
	assert_false(game.rode_off.has(late))
	game._process(0.1)
	game._process(0.1)
	assert_almost_eq(absf(game.view.train_node.position.x), FieldGame.train_roll(0.2), 0.001)
	assert_gt(FieldGame.train_roll(FieldHud.LEAVE_BEAT_S), 3.0, "seen to move within the beat")
	assert_false(game.player.visible, "aboard: gone with it")
	assert_true(late.visible, "still on the platform")
	game.hud.tick(FieldHud.LEAVE_BEAT_S + 0.1)
	var card: Array = []
	for l in game.hud.modal.find_children("*", "Label", true, false):
		card.append(l.text)
	var text: String = "\n".join(card)
	assert_string_contains(text, "못 탄 사람 1", "the receipt counts who stayed")
	assert_false(text.contains(late.display_name), "a number, never a name")
