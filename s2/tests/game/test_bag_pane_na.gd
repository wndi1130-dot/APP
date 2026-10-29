extends "res://addons/gut/test.gd"
## 가방 창 「나」(결정 488·489): 오른쪽 창, 세로 장소 줄과 얇은 물건 줄을 살핀다.
## 탭을 바꿔도 이동 대상·챙기는 시간·상자 소리는 이어지고, 도트 그림은 정수배로 보인다.
## 창 폭·가림은 캔버스 단위로 프로젝트 기본 창 1280×720에 대어 재고, 도트 그림의 기기 픽셀 정수배는 셈으로 본다.

const FieldGame = preload("res://game/field_game.gd")
const InventoryPane = preload("res://game/ui/inventory_pane.gd")
const GlassPane = preload("res://game/ui/glass_pane.gd")
const UiFonts = preload("res://game/ui/ui_fonts.gd")
const HudIcons = preload("res://game/ui/hud_icons.gd")
const SearchRules = preload("res://game/sim/search_rules.gd")


func _game() -> Node:
	var game = FieldGame.new()
	game.opts = {"seed": 5, "raiders": false, "auto_pause": false, "arrive": false}
	add_child_autofree(game)
	game.set_process(false)
	game.zombies.list.clear()
	return game


## A searched drawer away from the train; keep the map's reach and store rules.
func _box(game, items: Array = ["food_pack", "bandage"]) -> String:
	for id: String in game.data["containers"]:
		var c: Dictionary = game.data["containers"][id]
		if int(c.get("level", 0)) == 0 and not bool(c.get("locked", false)) and not c.has("pick") and not game.FieldMaps.by_train(game.data, c["cell"], "unloading"):
			c["searched"] = true
			c["furniture"] = "dresser"
			c["items"] = items.duplicate()
			game.player.position = game.actions._container_at(c)
			game.player.stop()
			return id
	return ""


func _tab(hud, kind: String, id: String = "") -> Button:
	var places: Node = hud.modal.find_child("Places", true, false)
	for key: Button in places.get_children():
		if key.has_meta("place_kind") and key.has_meta("place_id"):
			if String(key.get_meta("place_kind")) == kind and String(key.get_meta("place_id")) == id:
				return key
	return null


func _row(hud, list_name: String, id: String) -> Button:
	var list: Node = hud.modal.find_child(list_name, true, false)
	if list == null:
		return null
	for key: Button in list.find_children("*", "Button", true, false):
		if key.has_meta("item_id") and String(key.get_meta("item_id")) == id:
			return key
	return null


func _key(hud, word: String) -> Button:
	for key: Button in hud.modal.find_children("*", "Button", true, false):
		if key.text == word:
			return key
	return null


func _layout() -> void:
	for _i in range(3):
		await get_tree().process_frame


func _screen_rect(control: Control) -> Rect2:
	return control.get_screen_transform() * Rect2(Vector2.ZERO, control.size)


## The mockup card's share of the screen the pane covers: 43% at 1280×720 (35% on a
## 1688×780 phone, where the canvas is wider); the left half stays free for the stick.
## In canvas units against the project's 1280×720 window: a headless run's own
## window is a small square whose screen transform says nothing about a phone.
func test_the_pane_keeps_the_left_half_free_and_covers_at_most_the_mockup_share() -> void:
	var game = _game()
	game.hud.loot(_box(game))
	await _layout()
	var pane: Control = game.hud.modal.find_child("Pane", true, false)
	var base := Vector2(float(ProjectSettings.get_setting("display/window/size/viewport_width")), float(ProjectSettings.get_setting("display/window/size/viewport_height")))
	var canvas: Rect2 = pane.get_viewport_rect()
	var rect: Rect2 = pane.get_global_rect()
	var share: float = (rect.size.x * rect.size.y) / (base.x * base.y)
	var message: String = "canvas %.0f×%.0f; pane %.1f×%.1f at (%.1f, %.1f); covers %.4f of %.0f×%.0f" % [canvas.size.x, canvas.size.y, rect.size.x, rect.size.y, rect.position.x, rect.position.y, share, base.x, base.y]
	gut.p(message)
	assert_almost_eq(rect.end.x, canvas.end.x, 1.0, message)
	assert_gt(rect.position.x, canvas.position.x + canvas.size.x * 0.5, message)
	assert_almost_eq(pane.size.x, UiFonts.px(330.0), 1.0, "the requested fixed css width")
	assert_lte(share, 0.43, message)
	assert_lte(rect.end.y, base.y, "the lists leave the foot inside a phone's 720-high canvas")
	game.hud._close_modal()


func test_places_keep_their_order_short_names_empty_mark_and_selection() -> void:
	var game = _game()
	var id: String = _box(game, [])
	var c: Dictionary = game.data["containers"][id]
	# Enough nearby places to force the rail's own scroll, even on a tall canvas.
	for i in range(19):
		game.data["containers"]["na_extra_%d" % i] = c.duplicate(true)
	var expected: Array = InventoryPane.places(game, game.player)
	game.hud.loot(id)
	await _layout()
	var places: Node = game.hud.modal.find_child("Places", true, false)
	assert_eq(places.get_child_count(), expected.size() + 1)
	assert_eq((places.get_child(0) as Button).text, "가방")
	for i in expected.size():
		var key := places.get_child(i + 1) as Button
		assert_true(key.has_meta("place_kind") and key.has_meta("place_id"))
		if key.has_meta("place_kind") and key.has_meta("place_id"):
			assert_eq(String(key.get_meta("place_kind")), String(expected[i]["kind"]))
			assert_eq(String(key.get_meta("place_id")), String(expected[i]["id"]))
	var chosen: Button = _tab(game.hud, "box", id)
	assert_not_null(chosen)
	if chosen == null:
		return
	assert_true(SearchRules.shows_empty(c))
	assert_eq(chosen.text, "서랍장·빈")
	assert_true(chosen.has_meta("selected"))
	if chosen.has_meta("selected"):
		assert_true(bool(chosen.get_meta("selected")))
	var skin := chosen.get_theme_stylebox("normal") as StyleBoxFlat
	assert_eq(skin.border_color, GlassPane.AMBER)
	assert_gt(skin.bg_color.a, GlassPane.CELL.a)
	var label := chosen.find_children("*", "Label", true, false)[0] as Label
	assert_eq(label.get_theme_color("font_color"), GlassPane.INK3)
	var mark := chosen.find_children("*", "TextureRect", true, false)[0] as TextureRect
	assert_eq(mark.texture, HudIcons.texture("fetch", UiFonts.size(20.0), GlassPane.INK3))
	var rail := game.hud.modal.find_child("PlaceScroll", true, false) as ScrollContainer
	assert_gt(rail.get_v_scroll_bar().max_value, rail.get_v_scroll_bar().page, "only the places rail scrolls when it is full")
	game.hud._close_modal()


func test_a_row_starts_taking_with_stop_bar_and_total_time() -> void:
	var game = _game()
	var p = game.player
	p.items.clear()
	var id: String = _box(game, ["bandage", "food_pack"])
	game.hud.loot(id)
	assert_not_null(_key(game.hud, "모두 담기"))
	var row: Button = _row(game.hud, "Near", "food_pack")
	assert_not_null(row)
	if row == null:
		return
	row.pressed.emit()
	assert_eq(p.action, "take")
	assert_eq(game.actions.taking_item(p), "food_pack", "sorting keeps the source index")
	assert_false(game.paused)
	assert_not_null(_key(game.hud, "멈추기"))
	var taking: Button = _row(game.hud, "Near", "food_pack")
	var bar: Node = game.hud.modal.find_child("TakeBar", true, false)
	assert_not_null(bar)
	assert_eq(bar.get_parent(), taking, "the bar belongs to the thing coming out")
	assert_eq(game.hud.take_bar, bar)
	for key: Button in game.hud.modal.find_child("Near", true, false).find_children("*", "Button", true, false):
		assert_true(key.disabled, "no second row can start while taking")
	var total := game.hud.modal.find_child("TakeAll", true, false) as Label
	assert_not_null(total)
	if total != null:
		assert_true(total.text.contains("다 챙기면"))
	_key(game.hud, "멈추기").pressed.emit()
	assert_eq(p.action, "")
	assert_eq(game.data["containers"][id]["items"], ["bandage", "food_pack"], "stopping keeps what was not taken")
	game.hud._close_modal()


func test_the_bag_tab_sends_its_row_to_the_last_box() -> void:
	var game = _game()
	var p = game.player
	p.items.clear()
	p.add_item("scrap", 1)
	var id: String = _box(game, [])
	game.hud.loot(id)
	_tab(game.hud, "bag").pressed.emit()
	assert_eq(game.hud.inv_view, "bag")
	assert_eq(String(game.hud.inv_near["id"]), id)
	var bag: Node = game.hud.modal.find_child("Bag", true, false)
	assert_not_null(bag)
	assert_null(game.hud.modal.find_child("Near", true, false), "only one inventory list is shown")
	var row: Button = _row(game.hud, "Bag", "scrap")
	assert_not_null(row)
	if row == null:
		return
	assert_false(row.disabled)
	row.pressed.emit()
	assert_has(game.data["containers"][id]["items"], "scrap")
	assert_false(p.items.has("scrap"))
	assert_eq(game.hud.inv_view, "bag", "a refresh keeps the bag tab")
	game.hud._close_modal()


## Whole multiples of 32 device pixels (decision 489): the window's stretch is in
## the count — the multiple nearest the line icon's size that fits the row.
func test_pixel_art_is_nearest_at_whole_device_multiples_with_a_line_fallback() -> void:
	var game = _game()
	var id: String = _box(game)
	var picture := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	picture.fill(Color("ffc66c"))
	var texture := ImageTexture.create_from_image(picture)
	game.hud.item_px_override["food_pack"] = texture
	game.hud.loot(id)
	await _layout()
	var row: Button = _row(game.hud, "Near", "food_pack")
	var icon := row.find_child("ItemIcon", true, false) as TextureRect
	assert_eq(icon.texture, texture)
	assert_eq(icon.texture_filter, CanvasItem.TEXTURE_FILTER_NEAREST)
	# A 720-high phone draws the canvas 1:1, a 1080-high one at 1.5, a 1440-high one at 2.
	for s: float in [1.0, 1.5, 2.0, 3.0]:
		var whole: float = InventoryPane.whole_pixels(UiFonts.px(15.0) * s, UiFonts.px(32.0) * s)
		gut.p("stretch %.1f: art %.0f device px" % [s, whole])
		assert_gt(whole, 0.0)
		assert_eq(fmod(whole, 32.0), 0.0)
		assert_lte(whole, UiFonts.px(32.0) * s)
	assert_eq(InventoryPane.whole_pixels(1.0, 8.0), 0.0, "a window too small for 32 pixels")
	var scale: Vector2 = (icon.get_viewport().get_final_transform() * icon.get_global_transform_with_canvas()).get_scale().abs()
	var s_here: float = minf(scale.x, scale.y)
	var expected: float = InventoryPane.whole_pixels(UiFonts.px(15.0) * s_here, UiFonts.px(32.0) * s_here)
	gut.p("this window: stretch %.3f, art %.2f device px" % [s_here, icon.size.x * s_here])
	if expected > 0.0:
		assert_almost_eq(icon.size.x * s_here, expected, 0.01, "the art lands on whole device pixels")
	else:
		assert_almost_eq(icon.size.x, UiFonts.px(15.0), 0.01, "too small a window keeps the line icon's size")
	assert_almost_eq(icon.size.x, icon.size.y, 0.01)
	var fallback := _row(game.hud, "Near", "bandage").find_child("ItemIcon", true, false) as TextureRect
	assert_eq(fallback.texture, HudIcons.texture(game.item_icon("bandage"), UiFonts.size(15.0), GlassPane.INK2), "a missing png uses the existing line icon")
	game.hud._close_modal()


## Measure each visible key, including folded clothing and row jobs, in screen pixels.
func _touch_sizes(hud, where: String) -> void:
	var pane: Control = hud.modal.find_child("Pane", true, false)
	var least: float = INF
	var least_word: String = ""
	for key: Button in pane.find_children("*", "Button", true, false):
		if not key.is_visible_in_tree():
			continue
		var pixels: Vector2 = _screen_rect(key).size
		var short_side: float = minf(pixels.x, pixels.y)
		var scale: Vector2 = key.get_screen_transform().get_scale().abs()
		var minimum: float = UiFonts.px(32.0) * minf(scale.x, scale.y)
		if short_side < least:
			least = short_side
			least_word = key.text if key.text != "" else key.tooltip_text
		assert_gte(short_side + 0.1, minimum, "%s: %s %.2f px, minimum %.2f px" % [where, key.name, short_side, minimum])
	gut.p("%s: smallest key %.2f screen px (%s)" % [where, least, least_word])


func test_every_touch_target_is_at_least_32_css_and_clothing_folds() -> void:
	var game = _game()
	var id: String = _box(game)
	game.player.add_item("food_pack", 1)
	game.hud.loot(id)
	await _layout()
	_touch_sizes(game.hud, "near")
	_tab(game.hud, "bag").pressed.emit()
	await _layout()
	_touch_sizes(game.hud, "bag")
	var worn := game.hud.modal.find_child("Worn", true, false) as Control
	assert_false(worn.visible)
	var fold := game.hud.modal.find_child("WornFold", true, false) as Button
	assert_true(fold.text.begins_with("입은 옷 "))
	fold.pressed.emit()
	await _layout()
	assert_true(game.hud.inv_worn_open)
	worn = game.hud.modal.find_child("Worn", true, false) as Control
	assert_eq(worn.visible, worn.get_child_count() > 0)
	_touch_sizes(game.hud, "worn")
	var pane: Control = game.hud.modal.find_child("Pane", true, false)
	assert_lte(pane.position.y + pane.size.y, pane.get_viewport_rect().size.y, "expanded clothes still fit")
	(game.hud.modal.find_child("WornFold", true, false) as Button).pressed.emit()
	assert_false((game.hud.modal.find_child("Worn", true, false) as Control).visible)
	game.hud._close_modal()


func test_the_bag_tab_keeps_taking_and_stays_selected_when_it_finishes() -> void:
	var game = _game()
	var p = game.player
	p.items.clear()
	var id: String = _box(game, ["food_pack"])
	game.hud.loot(id)
	_row(game.hud, "Near", "food_pack").pressed.emit()
	_tab(game.hud, "bag").pressed.emit()
	assert_eq(game.hud.inv_view, "bag")
	assert_eq(p.action, "take")
	assert_false(game.paused)
	assert_eq(game.hud.taking_box, id)
	p.action_t = 0.001
	game._update_person(p, 0.1)
	assert_eq(p.action, "")
	assert_eq(game.hud.inv_view, "bag")
	assert_eq(int(p.items.get("food_pack", 0)), 1)
	assert_true(game.paused)
	assert_eq(game.hud.taking_box, "")
	game.hud._close_modal()


func test_the_bag_tab_shuts_the_box_and_returning_opens_it_once() -> void:
	var game = _game()
	var id: String = _box(game)
	var audio = game.audio
	audio.box_quiet_until = 0
	var before: int = audio.played.size()
	game.hud.loot(id)
	audio.box_quiet_until = 0
	_tab(game.hud, "bag").pressed.emit()
	assert_eq(game.hud.box_shown, "")
	audio.box_quiet_until = 0
	_tab(game.hud, "box", id).pressed.emit()
	assert_eq(game.hud.box_shown, id)
	game.hud._inv_sort()
	assert_eq(audio.played.slice(before), ["box_open_drawer", "box_close_drawer", "box_open_drawer"])
	game.hud._close_modal()
	audio.box_quiet_until = 0
	game.hud.tick(0.016)
	assert_eq(audio.played.slice(before), ["box_open_drawer", "box_close_drawer", "box_open_drawer", "box_close_drawer"])


## A short list still shows every place: the rail scrolls only when the screen runs out.
func test_a_short_list_still_shows_every_place() -> void:
	var game = _game()
	var id: String = _box(game, [])
	var c: Dictionary = game.data["containers"][id]
	for i in range(2):
		game.data["containers"]["na_near_%d" % i] = c.duplicate(true)
	game.hud.loot(id)
	await _layout()
	var places: Control = game.hud.modal.find_child("Places", true, false)
	var rail := game.hud.modal.find_child("PlaceScroll", true, false) as ScrollContainer
	assert_eq(places.get_child_count(), 5, "the bag, three boxes and the ground")
	var need: float = places.get_combined_minimum_size().y
	assert_gte(rail.size.y + 0.5, need, "rail %.1f px for places %.1f px" % [rail.size.y, need])
	game.hud._close_modal()


## The bag key over another pane opens on the bag, not on the last place's tab.
func test_the_bag_over_another_pane_opens_on_the_bag() -> void:
	var game = _game()
	var id: String = _box(game)
	game.hud.loot(id)
	game.hud._close_modal()
	assert_eq(game.hud.inv_view, "near")
	game.hud.body_panel()
	game.hud.bag_panel()
	assert_eq(game.hud.inv_view, "bag")
	assert_not_null(game.hud.modal.find_child("Bag", true, false))
	game.hud._close_modal()


## While a thing comes out of a box the bag stays at hand as before (its rows and
## jobs); only the rows of that box wait.
func test_taking_leaves_the_bag_at_hand() -> void:
	var game = _game()
	var p = game.player
	p.items.clear()
	p.add_item("scrap", 1)
	p.add_item("can_beans", 1)
	var id: String = _box(game, ["food_pack", "bandage"])
	game.hud.loot(id)
	_row(game.hud, "Near", "food_pack").pressed.emit()
	assert_eq(p.action, "take")
	_tab(game.hud, "bag").pressed.emit()
	assert_eq(p.action, "take")
	var row: Button = _row(game.hud, "Bag", "scrap")
	assert_not_null(row)
	if row != null:
		assert_false(row.disabled, "a bag row still goes across while taking")
	var eat: Button = null
	for key: Button in game.hud.modal.find_child("Bag", true, false).find_children("*", "Button", true, false):
		if key.tooltip_text == "먹기":
			eat = key
	assert_not_null(eat)
	if eat != null:
		assert_false(eat.disabled, "eating stays open while taking")
	_tab(game.hud, "box", id).pressed.emit()
	for key: Button in game.hud.modal.find_child("Near", true, false).find_children("*", "Button", true, false):
		assert_true(key.disabled, "the box being taken from waits")
	game.hud._close_modal()


## With the bag shown, the place a pressed row goes to keeps an amber edge.
func test_the_bag_tab_marks_where_a_row_goes() -> void:
	var game = _game()
	var id: String = _box(game)
	game.hud.loot(id)
	_tab(game.hud, "bag").pressed.emit()
	var aim: Button = _tab(game.hud, "box", id)
	assert_not_null(aim)
	if aim != null:
		assert_true(bool(aim.get_meta("aim")))
		assert_false(bool(aim.get_meta("selected")))
		assert_eq((aim.get_theme_stylebox("normal") as StyleBoxFlat).border_color, GlassPane.AMBER)
	assert_false(bool(_tab(game.hud, "ground").get_meta("aim")))
	game.hud._close_modal()


## The foot's particle follows the place's last letter (UiFonts.josa).
func test_the_bag_foot_says_where_with_the_right_particle() -> void:
	var game = _game()
	var id: String = _box(game)
	game.data["containers"][id]["furniture"] = "fridge_open"
	game.hud.loot(id)
	_tab(game.hud, "bag").pressed.emit()
	var foot := game.hud.modal.find_child("MoveHint", true, false) as Label
	assert_not_null(foot)
	if foot != null:
		assert_true(foot.text.begins_with("누르면 냉장고로 · 가방"), foot.text)
	game.hud._close_modal()


## By the train with two weapons the bag tab has three keys; the pane keeps its width.
func test_the_bag_tab_by_the_train_keeps_the_width() -> void:
	var game = _game()
	var p = game.player
	assert_gt(p.hands.size(), 1)
	p.add_item("scrap", 1)
	var unload: Rect2i = game.data["unload"]
	p.position = game.lift(unload.position + Vector2i(3, 1), 0)
	p.stop()
	game.hud.bag_panel()
	await _layout()
	assert_not_null(_key(game.hud, "바꾸기"))
	assert_not_null(_key(game.hud, "열차에 싣기"))
	var pane: Control = game.hud.modal.find_child("Pane", true, false)
	assert_almost_eq(pane.size.x, UiFonts.px(330.0), 1.0, "three keys fit in the fixed width")
	game.hud._close_modal()


func _touch(hud, at: Vector2, pressed: bool, index: int = 0, canceled: bool = false) -> void:
	var e := InputEventScreenTouch.new()
	e.index = index
	e.position = at
	e.pressed = pressed
	e.canceled = canceled
	hud._input(e)


func _drag(hud, at: Vector2, index: int = 0) -> void:
	var e := InputEventScreenDrag.new()
	e.index = index
	e.position = at
	hud._input(e)


const LONG_BOX: Array = ["food_pack", "scrap", "wood", "cloth", "bandage", "document", "plank", "medkit", "flare", "scrap", "wood", "food_pack"]


## Two searched boxes in reach of the player: a map's boxes stand more than a reach
## apart, so another one of the same floor is set on the drawer's cell.
func _two_boxes(game) -> Array:
	var a: String = _box(game, ["food_pack"])
	var ca: Dictionary = game.data["containers"][a]
	for b: String in game.data["containers"]:
		var cb: Dictionary = game.data["containers"][b]
		if b != a and int(cb.get("level", 0)) == int(ca.get("level", 0)) and not bool(cb.get("locked", false)) and not cb.has("pick"):
			cb["cell"] = ca["cell"]
			cb["searched"] = true
			cb["furniture"] = "side_table"
			cb["items"] = ["bandage"]
			return [a, b]
	return []


## The bag pane leaves the stick free (decision 488): a thumb on it walks and the
## field runs; let go, and the field waits again under the pane.
func test_the_stick_walks_with_the_bag_up() -> void:
	var game = _game()
	var hud = game.hud
	hud.loot(_box(game))
	await _layout()
	assert_true(game.paused)
	var home: Vector2 = hud.stick_home()
	_touch(hud, home, true)
	_drag(hud, home + Vector2(hud.STICK_R, 0))
	assert_ne(game.player.stick, Vector2.ZERO, "the stick pushes under the bag pane")
	hud.tick(0.016)
	assert_false(game.paused, "the field runs while the stick walks")
	assert_true(hud.modal_open, "the pane stays up")
	_touch(hud, home + Vector2(hud.STICK_R, 0), false)
	hud.tick(0.016)
	assert_eq(game.player.stick, Vector2.ZERO)
	assert_true(game.paused, "let go, and the field waits again")
	hud._close_modal()


## Pushing the stick while a thing comes out lets the take go (STICK_BREAKS) and the
## thing stays in the box; the pane is laid again without its stop key.
func test_pushing_the_stick_lets_a_take_go_under_the_pane() -> void:
	var game = _game()
	var p = game.player
	p.items.clear()
	var hud = game.hud
	var id: String = _box(game, ["food_pack"])
	hud.loot(id)
	_row(hud, "Near", "food_pack").pressed.emit()
	assert_eq(p.action, "take")
	var home: Vector2 = hud.stick_home()
	_touch(hud, home, true)
	_drag(hud, home + Vector2(hud.STICK_R, 0))
	hud.tick(0.016)
	game._update_person(p, 0.05)
	assert_eq(p.action, "", "the stick lets the take go")
	assert_has(game.data["containers"][id]["items"], "food_pack", "the thing stays in the box")
	hud.tick(0.016)
	assert_true(hud.modal_open, "the pane stays up")
	assert_eq(hud.modal, hud.box_pane, "the bag pane, laid again")
	assert_eq(hud.taking_box, "")
	assert_null(_key(hud, "멈추기"))
	assert_not_null(_row(hud, "Near", "food_pack"), "the row is back in the box")
	assert_false(game.paused, "the stick still walks the field")
	_touch(hud, home + Vector2(hud.STICK_R, 0), false)
	hud._close_modal()


## The app away (field_game.gd interrupt) holds the field still under the bag
## pane, a thing coming out or not.
func test_the_app_away_holds_the_field_while_taking() -> void:
	var game = _game()
	var p = game.player
	p.items.clear()
	var hud = game.hud
	hud.loot(_box(game, ["food_pack"]))
	_row(hud, "Near", "food_pack").pressed.emit()
	assert_eq(p.action, "take")
	hud.tick(0.016)
	assert_false(game.paused, "the field runs while the thing comes out")
	game.interrupt()
	hud.tick(0.016)
	assert_true(game.paused, "the app away keeps the field still")
	hud._close_modal()


## With the thumb on the stick (index 0, the one finger Godot makes a mouse of),
## another finger presses the pane's keys by hand.
func test_a_second_finger_presses_the_pane_with_the_stick_held() -> void:
	var game = _game()
	var hud = game.hud
	hud.loot(_box(game))
	await _layout()
	var home: Vector2 = hud.stick_home()
	_touch(hud, home, true)
	_drag(hud, home + Vector2(hud.STICK_R, 0))
	var at: Vector2 = _tab(hud, "ground").get_global_rect().get_center()
	_touch(hud, at, true, 1)
	_touch(hud, at, false, 1)
	assert_eq(String(hud.inv_near.get("kind", "")), "ground", "the second finger took the floor's key")
	assert_eq(hud.stick_index, 0, "the thumb still holds the stick")
	assert_ne(game.player.stick, Vector2.ZERO, "and still walks")
	_touch(hud, home + Vector2(hud.STICK_R, 0), false)
	hud._close_modal()


## The same finger drags the pane's list, and lifting presses nothing.
func test_a_second_finger_drags_the_list_with_the_stick_held() -> void:
	var game = _game()
	var p = game.player
	var hud = game.hud
	hud.loot(_box(game, LONG_BOX))
	await _layout()
	var home: Vector2 = hud.stick_home()
	_touch(hud, home, true)
	var list := hud.modal.find_child("List", true, false) as ScrollContainer
	var row: Button = list.find_children("*", "Button", true, false)[0]
	var at: Vector2 = row.get_global_rect().get_center()
	_touch(hud, at, true, 1)
	_drag(hud, at + Vector2(0, -80), 1)
	_touch(hud, at + Vector2(0, -80), false, 1)
	assert_gt(list.scroll_vertical, 0, "the second finger dragged the list")
	assert_ne(p.action, "take", "a drag takes no row")
	_touch(hud, home, false)
	hud._close_modal()


## The same places nearest first the other way round are no walk off; laid
## again all the same, they keep the order they were shown in.
func test_the_same_places_in_another_order_lay_nothing_again() -> void:
	var game = _game()
	var hud = game.hud
	var two: Array = _two_boxes(game)
	if two.is_empty():
		pending("no two boxes in reach of one spot on this map")
		return
	hud.loot(two[0])
	var shown: Array = hud.bag_places.duplicate()
	var boxes: Array = shown.filter(func(k: String) -> bool: return k.begins_with("box:"))
	assert_gte(boxes.size(), 2)
	var turned: Array = shown.duplicate()
	turned[turned.find(boxes[0])] = boxes[1]
	turned[shown.find(boxes[1])] = boxes[0]
	hud.bag_places = turned
	var pane = hud.modal
	hud._bag_places_moved()
	assert_eq(hud.modal, pane, "the same places lay nothing again")
	hud._lay_bag_again()
	assert_ne(hud.modal, pane, "laid again")
	assert_eq(hud.bag_places, turned, "the places keep their order")
	hud._close_modal()


## Laid again (a walk), the item list stays where it was scrolled to.
func test_laying_again_keeps_the_list_where_it_was() -> void:
	var game = _game()
	var hud = game.hud
	hud.loot(_box(game, LONG_BOX))
	await _layout()
	var list := hud.modal.find_child("List", true, false) as ScrollContainer
	list.scroll_vertical = 60
	var was: int = list.scroll_vertical
	assert_gt(was, 0, "the list scrolls")
	hud._lay_bag_again()
	await _layout()
	var again := hud.modal.find_child("List", true, false) as ScrollContainer
	assert_ne(again, list, "the pane was laid again")
	assert_eq(again.scroll_vertical, was, "the list is where it was")
	hud._close_modal()


## Under the bag pane as in the field, the ring round the run key over the stick
## plants no stick (finger_down's ring of nothing).
func test_the_ring_round_the_run_key_plants_no_stick_under_the_pane() -> void:
	var game = _game()
	var hud = game.hud
	hud.loot(_box(game))
	await _layout()
	var home: Vector2 = hud.stick_home()
	var at: Vector2 = home + Vector2(0.0, -110.0)
	assert_true(hud.run_button.is_visible_in_tree(), "the run key shows")
	assert_true(hud.run_button.get_global_rect().grow(4.0 * hud.PX_PER_MM).has_point(at), "the touch is in its ring")
	assert_lte(at.distance_to(home), hud.STICK_R * hud.STICK_CATCH, "and in the stick's reach")
	_touch(hud, at, true)
	assert_eq(hud.stick_index, -1, "no stick planted")
	_touch(hud, at, false)
	hud._close_modal()


## A floating stick (a setting) under the bag pane is not the world: a short
## touch taps nothing there, and a cancelled touch is no lift at all.
func test_the_stick_under_the_pane_taps_nothing() -> void:
	var game = _game()
	game.opts["stick_float"] = true
	var hud = game.hud
	hud.loot(_box(game))
	await _layout()
	var at := Vector2(hud._view_size().x * 0.25, hud._view_size().y * 0.4)
	_touch(hud, at, true)
	assert_eq(hud.stick_index, 0)
	assert_true(bool(hud.fingers[0].get("fixed", false)), "a touch on it taps nothing")
	hud.stick_tap_ms = 0
	_touch(hud, at, false, 0, true)
	assert_eq(hud.stick_index, -1, "a cancelled touch lets the stick go")
	assert_eq(hud.stick_tap_ms, 0, "and is no lift")
	hud._close_modal()


## Walking off a box drops its place from the rail, and a box shown goes back to the bag.
func test_walking_off_a_box_drops_its_place_and_shows_the_bag() -> void:
	var game = _game()
	var hud = game.hud
	var id: String = _box(game)
	hud.loot(id)
	assert_eq(hud.inv_view, "near")
	assert_not_null(_tab(hud, "box", id))
	var unload: Rect2i = game.data["unload"]
	game.player.position = game.lift(unload.position + Vector2i(3, 1), 0)
	hud.tick(0.5)
	assert_null(_tab(hud, "box", id), "the box left behind is off the rail")
	assert_eq(hud.inv_view, "bag")
	assert_not_null(hud.modal.find_child("Bag", true, false))
	hud._close_modal()


## The bag pane's shade lies under the pane alone; other panes keep the full shade.
func test_the_bag_shade_leaves_the_left_clear() -> void:
	var game = _game()
	game.hud.loot(_box(game))
	await _layout()
	var dim := game.hud.modal.get_node("Shade") as ColorRect
	var canvas: Rect2 = dim.get_viewport_rect()
	var rect: Rect2 = dim.get_global_rect()
	assert_gt(rect.position.x, canvas.size.x * 0.5, "the shade starts at %.1f of %.1f" % [rect.position.x, canvas.size.x])
	assert_almost_eq(rect.end.x, canvas.end.x, 1.0)
	game.hud._close_modal()
	game.hud.body_panel()
	var body_dim := game.hud.modal.get_node("Shade") as ColorRect
	assert_almost_eq(body_dim.get_global_rect().position.x, 0.0, 1.0, "other panes keep the full shade")
	game.hud._close_modal()
