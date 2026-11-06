extends "res://addons/gut/test.gd"
## 바닥(시체 곁) 줄의 꼬리표(코디 2026-11-06 안2): 이름 아래 작은 둘째 줄에 옷은 「입기」와 해짐·너덜,
## 무기는 닳음·위험(또는 망가짐)을 HUD 무기 칸과 같은 주황·빨강으로. 멀쩡한 것은 상태 낱말이 없다.
## 줄이 모자라면 이름 끝만 … 로 줄고 꼬리표는 잘리지 않는다 — 가장 긴 옷·무기 이름도 다 보인다.

const FieldGame = preload("res://game/field_game.gd")
const InventoryPane = preload("res://game/ui/inventory_pane.gd")
const HudSkin = preload("res://game/ui/hud_skin.gd")
const GlassPane = preload("res://game/ui/glass_pane.gd")
const Wear = preload("res://game/sim/wear.gd")
const W = preload("res://game/sim/weapons.gd")
const UiFonts = preload("res://game/ui/ui_fonts.gd")


func _game() -> Node:
	var game = FieldGame.new()
	game.opts = {"seed": 5, "raiders": false, "auto_pause": false, "arrive": false}
	add_child_autofree(game)
	game.set_process(false)
	game.zombies.list.clear()
	game.player.items.clear()
	return game


func _garment(id: String, wear: float) -> Dictionary:
	var made: Dictionary = Wear.make(id)
	made["wear"] = wear
	return {"id": id, "n": 1, "garment": made}


func _weapon(id: String, condition: float) -> Dictionary:
	return {"id": id, "n": 1, "weapon": {"id": id, "quality": "factory", "condition": condition, "loaded": 0}}


func _words(tags: Array) -> Array:
	return tags.map(func(t: Array) -> String: return String(t[0]))


## The floor beside the player with `things` on it, the pane laid there.
func _floor(game, things: Array) -> void:
	var p = game.player
	for g: Dictionary in things:
		var lying: Dictionary = g.duplicate(true)
		lying["pos"] = p.position
		game.ground_items.append(lying)
	game.hud.bag_panel()
	game.hud._inv_place({"kind": "ground", "id": "", "name": "바닥"})


func _row(hud, id: String) -> Button:
	var rows: Array = _rows(hud, id)
	return rows[0] if not rows.is_empty() else null


## Every row of `id` on the place's side, top to bottom.
func _rows(hud, id: String) -> Array:
	var found: Array = []
	var near: Node = hud.modal.find_child("Near", true, false)
	for b: Node in near.get_children():
		if b is Button and String(b.get_meta("item_id", "")) == id:
			found.append(b)
	return found


## The row of `id` whose state word is `word`.
func _row_saying(hud, id: String, word: String) -> Button:
	for b: Button in _rows(hud, id):
		var state := b.find_child("State", true, false) as Label
		if state != null and state.text == word:
			return b
	return null


## Where on the ground the weapon `id` in `condition` lies (-1: not there).
func _lying(game, id: String, condition: float) -> int:
	for i: int in game.ground_items.size():
		var g: Dictionary = game.ground_items[i]
		if String(g["id"]) == id and g.has("weapon") and is_equal_approx(float(g["weapon"].get("condition", 1.0)), condition):
			return i
	return -1


## Is the row's open panel (More) right under `row`?
func _opens_under(row: Button) -> bool:
	if row == null:
		return false
	var list: Node = row.get_parent()
	var next: int = row.get_index() + 1
	return next < list.get_child_count() and String(list.get_child(next).name) == "More"


func _rect(row: Node, part: String) -> Rect2:
	return (row.find_child(part, true, false) as Control).get_global_rect()


## Is `inner` inside `outer`, half a pixel given?
func _inside(inner: Rect2, outer: Rect2) -> bool:
	return inner.position.x >= outer.position.x - 0.5 and inner.position.y >= outer.position.y - 0.5 \
		and inner.end.x <= outer.end.x + 0.5 and inner.end.y <= outer.end.y + 0.5


func _layout() -> void:
	for _i in range(3):
		await get_tree().process_frame
	await get_tree().create_timer(0.25).timeout
	for node: Node in get_tree().root.find_children("Pane", "", true, false):
		for _i in range(120):
			if not node.has_method("is_sliding") or not bool(node.call("is_sliding")):
				break
			node.call("motion_step", 1.0 / 60.0)


func _text_w(label: Label) -> float:
	return label.get_theme_font("font").get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, label.get_theme_font_size("font_size")).x


## The longest name among `ids` as the game shows it.
func _longest(game, ids: Array) -> String:
	var best: String = String(ids[0])
	for id: String in ids:
		if game.item_name(id).length() > game.item_name(best).length():
			best = id
	return best


# ---------------------------------------------------------------- the rule


func test_a_garment_tells_it_is_worn_and_how_worn_once_it_shows() -> void:
	assert_eq(_words(InventoryPane.ground_tags(_garment("jacket_short", 0.05))), ["입기"], "as good as new: no state")
	var torn: Array = InventoryPane.ground_tags(_garment("jacket_short", Wear.TORN_AT))
	assert_eq(_words(torn), ["입기", "해짐"])
	assert_eq(torn[1][1], HudSkin.HEED, "amber, as the HUD's worn weapon")
	var rags: Array = InventoryPane.ground_tags(_garment("jacket_short", Wear.RAGS_AT))
	assert_eq(_words(rags), ["입기", "너덜"])
	assert_eq(rags[1][1], HudSkin.BAD)
	assert_eq(_words(InventoryPane.ground_tags(_garment("jacket_short", Wear.TORN_AT - 0.01))), ["입기"], "just under the line")


func test_a_weapon_tells_its_condition_in_the_hud_s_words() -> void:
	assert_eq(InventoryPane.ground_tags(_weapon("axe", 0.95)), [], "good: nothing")
	var worn: Array = InventoryPane.ground_tags(_weapon("axe", 0.5))
	assert_eq(_words(worn), [W.CONDITION_NAMES[1]])
	assert_eq(worn[0][1], HudSkin.HEED)
	var risky: Array = InventoryPane.ground_tags(_weapon("axe", 0.15))
	assert_eq(_words(risky), [W.CONDITION_NAMES[2]])
	assert_eq(risky[0][1], HudSkin.BAD)
	var broken: Dictionary = _weapon("axe", 0.0)
	broken["weapon"]["broken"] = true
	assert_eq(_words(InventoryPane.ground_tags(broken)), ["망가짐"])
	assert_eq(InventoryPane.ground_tags(broken)[0][1], HudSkin.BAD, "red, as the HUD's broken weapon")
	# The same lines as the HUD's weapon (weapons.gd condition_level).
	assert_eq(_words(InventoryPane.ground_tags(_weapon("axe", 0.61))), [])
	assert_eq(_words(InventoryPane.ground_tags(_weapon("axe", 0.6))), [W.CONDITION_NAMES[1]])
	assert_eq(_words(InventoryPane.ground_tags(_weapon("axe", 0.3))), [W.CONDITION_NAMES[2]])


func test_a_state_left_out_or_broken_in_good_shape_still_tells_right() -> void:
	# Broken goes before the condition: a weapon broken in good shape is 「망가짐」, red.
	var broken_good: Dictionary = _weapon("axe", 1.0)
	broken_good["weapon"]["broken"] = true
	var tags: Array = InventoryPane.ground_tags(broken_good)
	assert_eq(_words(tags), ["망가짐"], "broken whatever its condition")
	assert_eq(tags[0][1], HudSkin.BAD)
	# A weapon with no condition written is as good as new (the HUD's 1.0).
	var no_condition: Dictionary = _weapon("axe", 0.0)
	(no_condition["weapon"] as Dictionary).erase("condition")
	assert_eq(InventoryPane.ground_tags(no_condition), [], "no condition: nothing to warn of")
	# A garment with no wear written can still be put on, and tells no state.
	var no_wear: Dictionary = _garment("jacket_short", 0.9)
	(no_wear["garment"] as Dictionary).erase("wear")
	assert_eq(_words(InventoryPane.ground_tags(no_wear)), ["입기"], "no wear: only 「입기」")


func test_a_plain_thing_tells_nothing_more() -> void:
	assert_eq(InventoryPane.ground_tags({"id": "scrap", "n": 2}), [])
	assert_eq(InventoryPane.ground_tags({"id": "meat_spoiled", "n": 1}), [], "its name already says it")


# ---------------------------------------------------------------- the rows


func test_the_tags_sit_under_the_name_and_the_row_still_says_it_all() -> void:
	var game = _game()
	_floor(game, [_garment("jacket_short", 0.45), _weapon("crowbar", 0.5), {"id": "scrap", "n": 1}])
	var coat: Button = _row(game.hud, "jacket_short")
	assert_eq((coat.find_child("Name", true, false) as Label).text, game.item_name("jacket_short"), "the name alone")
	var tags: Node = coat.find_child("Tags", true, false)
	assert_not_null(tags)
	assert_eq((tags.get_node("Hint") as Label).text, "입기")
	var state := tags.get_node("State") as Label
	assert_eq(state.text, "해짐")
	assert_eq(state.get_theme_color("font_color"), HudSkin.HEED)
	assert_eq(coat.text, "%s · 입기 · 해짐" % game.item_name("jacket_short"), "the hidden text says it all for tips and tests")
	assert_eq(coat.tooltip_text, coat.text, "and so does the tip")
	assert_eq(((_row(game.hud, "crowbar").find_child("Tags", true, false) as Node).get_node("State") as Label).text, W.CONDITION_NAMES[1])
	assert_null(_row(game.hud, "scrap").find_child("Tags", true, false), "nothing to tell: one line as before")
	game.hud._close_modal()


func test_the_longest_garment_and_weapon_names_show_whole_with_their_tags() -> void:
	var game = _game()
	var coat: String = _longest(game, Wear.KINDS.keys())
	var gun: String = _longest(game, W.DATA.keys())
	gut.p("longest: %s (%s), %s (%s)" % [coat, game.item_name(coat), gun, game.item_name(gun)])
	_floor(game, [_garment(coat, Wear.RAGS_AT), _weapon(gun, 0.15)])
	await _layout()
	for id: String in [coat, gun]:
		var row: Button = _row(game.hud, id)
		var name_l := row.find_child("Name", true, false) as Label
		assert_lte(_text_w(name_l), name_l.size.x + 0.5, "%s: the whole name shows (%.1f of %.1f)" % [id, _text_w(name_l), name_l.size.x])
		assert_lte(_rect(row, "Name").end.y, _rect(row, "Tags").position.y + 0.5, "%s: the name over its tags" % id)
		assert_true(_inside(_rect(row, "Name"), row.get_global_rect()), "%s: the name inside the row" % id)
		for tag: Node in row.find_child("Tags", true, false).get_children():
			var t := tag as Label
			assert_false(t.clip_text, "a tag is never clipped")
			assert_lte(_text_w(t), t.size.x + 0.5, "%s: 「%s」 whole" % [id, t.text])
		var tags_r: Rect2 = (row.find_child("Tags", true, false) as Control).get_global_rect()
		var kg_r: Rect2 = (row.find_child("Weight", true, false) as Control).get_global_rect()
		assert_lte(tags_r.end.x, kg_r.position.x + 0.5, "%s: the tags stop short of the weight" % id)
		assert_lte(tags_r.end.y, row.get_global_rect().end.y, "%s: inside the row" % id)
	game.hud._close_modal()


func test_a_long_name_gives_way_before_its_tags() -> void:
	var game = _game()
	_floor(game, [_garment("jacket_short", Wear.RAGS_AT)])
	await _layout()
	var row: Button = _row(game.hud, "jacket_short")
	var name_l := row.find_child("Name", true, false) as Label
	# Squeeze the name: a name far past the row's room is cut, the tags stay whole.
	name_l.text = "아주 아주 아주 아주 아주 긴 이름의 철도원 외투"
	await _layout()
	assert_gt(_text_w(name_l), name_l.size.x, "the name no longer fits")
	assert_eq(name_l.text_overrun_behavior, TextServer.OVERRUN_TRIM_ELLIPSIS, "so it is cut with …")
	assert_gt(name_l.size.x, UiFonts.px(12.0), "a cut name still shows its start")
	var state := row.find_child("State", true, false) as Label
	assert_lte(_text_w(state), state.size.x + 0.5, "the state word stays whole")
	assert_lte((row.find_child("Tags", true, false) as Control).get_global_rect().end.x, (row.find_child("Weight", true, false) as Control).get_global_rect().position.x + 0.5)
	assert_true(_inside(_rect(row, "Tags"), row.get_global_rect()), "the tags inside the row")
	game.hud._close_modal()


## A tagged row with a count (two figures) and a heavy weight: every part inside
## the row, none over another — the name over its tags, then the count, then the
## weight — the name still wider than nothing (6 Pro 점검 보통 1).
func test_a_tagged_row_with_a_count_keeps_every_part_inside_and_apart() -> void:
	var game = _game()
	var coat: String = _longest(game, Wear.KINDS.keys())
	var gun: String = _longest(game, W.DATA.keys())
	var coats: Dictionary = _garment(coat, Wear.RAGS_AT)
	coats["n"] = 12
	var guns: Dictionary = _weapon(gun, 0.15)
	guns["n"] = 3
	_floor(game, [coats, guns])
	await _layout()
	for want: Array in [[coat, 12, "%s · 입기 · 너덜 ×12" % game.item_name(coat)], [gun, 3, "%s · %s ×3" % [game.item_name(gun), W.CONDITION_NAMES[2]]]]:
		var id: String = want[0]
		var row: Button = _row(game.hud, id)
		assert_eq(row.text, want[2], "%s: the hidden text with its tags and count" % id)
		assert_eq(row.tooltip_text, row.text, "%s: the tip as well" % id)
		var box: Rect2 = row.get_global_rect()
		var name_r: Rect2 = _rect(row, "Name")
		var tags_r: Rect2 = _rect(row, "Tags")
		var count_r: Rect2 = _rect(row, "Count")
		var kg_r: Rect2 = _rect(row, "Weight")
		assert_eq((row.find_child("Count", true, false) as Label).text, "×%d" % int(want[1]))
		for part: Array in [["Name", name_r], ["Tags", tags_r], ["Count", count_r], ["Weight", kg_r]]:
			assert_true(_inside(part[1], box), "%s: %s inside the row (%s in %s)" % [id, part[0], part[1], box])
		assert_gt(name_r.size.x, UiFonts.px(12.0), "%s: the name keeps room" % id)
		assert_lte(name_r.end.y, tags_r.position.y + 0.5, "%s: the name over its tags" % id)
		assert_lte(maxf(name_r.end.x, tags_r.end.x), count_r.position.x + 0.5, "%s: name and tags short of the count" % id)
		assert_lte(count_r.end.x, kg_r.position.x + 0.5, "%s: the count short of the weight" % id)
		for tag: Node in row.find_child("Tags", true, false).get_children():
			assert_lte(_text_w(tag as Label), (tag as Label).size.x + 0.5, "%s: 「%s」 whole" % [id, (tag as Label).text])
	game.hud._close_modal()


## Two of one weapon in different states lie as two rows, each its own: held, the
## one held opens (and stays open through a sort); pressed, that one is picked up
## and the other stays (6 Pro 점검 보통 2).
func test_two_of_one_weapon_in_different_states_keep_their_own_rows() -> void:
	var game = _game()
	game.player.hands.clear()
	game.player.set_weapon_slots(game.player.hands)
	_floor(game, [_weapon("axe", 0.5), _weapon("axe", 0.15)])
	var worn_word: String = W.CONDITION_NAMES[1]
	var risky_word: String = W.CONDITION_NAMES[2]
	assert_eq(_rows(game.hud, "axe").size(), 2, "one row each: they do not stack")
	var risky: Button = _row_saying(game.hud, "axe", risky_word)
	assert_not_null(risky)
	assert_not_null(_row_saying(game.hud, "axe", worn_word))
	assert_eq(risky.tooltip_text, "%s · %s" % [game.item_name("axe"), risky_word])
	# Held: the row's own long press opens it, the risky one.
	risky.button_down.emit()
	await get_tree().create_timer(InventoryPane.LONG_S + 0.15).timeout
	# Opening lays the pane again: the held row is let go (freed now or soon), so
	# nothing more is asked of it — the rows are found afresh below.
	var risky_at: int = _lying(game, "axe", 0.15)
	assert_eq(game.hud.inv_expand.get("i"), risky_at, "the held row opens, not the other axe")
	for sort_turn: int in range(2):
		risky = _row_saying(game.hud, "axe", risky_word)
		assert_true(_opens_under(risky), "sort %d: the open panel under the risky axe" % sort_turn)
		assert_false(_opens_under(_row_saying(game.hud, "axe", worn_word)), "sort %d: the worn axe stays shut" % sort_turn)
		game.hud._inv_sort()
	# Pressed: that one comes to hand, the other stays where it lay.
	risky = _row_saying(game.hud, "axe", risky_word)
	risky.set_meta("held_long", false)
	risky.pressed.emit()
	assert_eq(game.player.hands.size(), 1, "one axe in hand")
	assert_almost_eq(float(game.player.hands[0].get("condition", 1.0)), 0.15, 0.001, "the risky one")
	assert_eq(_lying(game, "axe", 0.15), -1, "gone from the ground")
	assert_ne(_lying(game, "axe", 0.5), -1, "the worn axe still lies there")
	if game.hud.modal_open:
		game.hud._close_modal()
