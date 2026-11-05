extends "res://addons/gut/test.gd"
## 가방 창 「나」(결정 558): 가방과 고른 곳을 나란히 둔 두 칸과 오른쪽 장소 줄을 살핀다.
## 장소를 바꿔도 이동 대상·챙기는 시간·상자 소리는 이어지고, 도트 그림은 정수배로 보인다.
## 창 폭·가림은 캔버스 단위로 프로젝트 기본 창 1280×720에 대어 재고, 도트 그림의 기기 픽셀 정수배는 셈으로 본다.

const FieldGame = preload("res://game/field_game.gd")
const InventoryPane = preload("res://game/ui/inventory_pane.gd")
const GlassPane = preload("res://game/ui/glass_pane.gd")
const UiFonts = preload("res://game/ui/ui_fonts.gd")
const HudIcons = preload("res://game/ui/hud_icons.gd")
const SearchRules = preload("res://game/sim/search_rules.gd")
const HoldConfirm = preload("res://game/ui/hold_confirm.gd")


func _game(viewport: SubViewport = null) -> Node:
	var game = FieldGame.new()
	game.opts = {"seed": 5, "raiders": false, "auto_pause": false, "arrive": false}
	if viewport == null:
		add_child_autofree(game)
	else:
		viewport.add_child(game)
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
	await get_tree().create_timer(0.25).timeout
	# A slide still under way on a slow machine ends by fixed steps.
	for node: Node in get_tree().root.find_children("Pane", "", true, false):
		for _i in range(120):
			if not node.has_method("is_sliding") or not bool(node.call("is_sliding")):
				break
			node.call("motion_step", 1.0 / 60.0)


func _screen_rect(control: Control) -> Rect2:
	return control.get_screen_transform() * Rect2(Vector2.ZERO, control.size)


## The mockup card's width (결정 558 「나」): the bag and the place side by side and
## the rail, 488 css — 70% of a 1280×720 screen's width while looking (the field
## stands still), 58% on a 2316×1080 phone; the dimmed HUD at the left stays visible.
## In canvas units against the project's 1280×720 window: a headless run's own
## window is a small square whose screen transform says nothing about a phone.
func test_the_pane_keeps_the_left_free_and_covers_at_most_the_mockup_width() -> void:
	var game = _game()
	game.hud.loot(_box(game))
	await _layout()
	var pane: Control = game.hud.modal.find_child("Pane", true, false)
	var base := Vector2(float(ProjectSettings.get_setting("display/window/size/viewport_width")), float(ProjectSettings.get_setting("display/window/size/viewport_height")))
	var canvas: Rect2 = pane.get_viewport_rect()
	var rect: Rect2 = pane.get_global_rect()
	var width_share: float = rect.size.x / base.x
	var message: String = "canvas %.0f×%.0f; pane %.1f×%.1f at (%.1f, %.1f); %.4f of %.0f wide" % [canvas.size.x, canvas.size.y, rect.size.x, rect.size.y, rect.position.x, rect.position.y, width_share, base.x]
	gut.p(message)
	assert_almost_eq(rect.end.x, canvas.end.x, 1.0, message)
	assert_gt(rect.position.x, canvas.position.x + canvas.size.x * 0.25, message)
	assert_almost_eq(pane.size.x, InventoryPane.pane_px(), 0.5, "the fixed width, whole pixels: no content widens it")
	assert_almost_eq(InventoryPane.pane_px(), UiFonts.px(InventoryPane.PANE_W), 5.0, "within a pixel a part of the css width")
	assert_almost_eq(InventoryPane.PANE_W, 488.0, 0.01, "two columns of 200 and the rail of 52")
	assert_lte(width_share, 0.71, message)
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
	# The bag is always shown beside the place (결정 558): the rail holds places only.
	assert_eq(places.get_child_count(), expected.size())
	for i in expected.size():
		var key := places.get_child(i) as Button
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
	assert_eq(skin.border_color, InventoryPane.BONE, "the chosen place's edge in bone: amber is the main key's (결정 560)")
	assert_gt(skin.border_color.a, GlassPane.HAIR.a)
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
	# The main key turned 멈추기 shows the seconds left of this thing.
	var left := game.hud.modal.find_child("TakeLeft", true, false) as Label
	assert_not_null(left)
	if left != null:
		assert_eq(left.text, "%.1f초" % p.action_t)
		var before: float = p.action_t
		game._update_person(p, 0.2)
		game.hud._tick_take()
		assert_lt(p.action_t, before)
		assert_eq(left.text, "%.1f초" % InventoryPane.take_left(game, p))
		assert_ne(left.text, "%.1f초" % before)
	_key(game.hud, "멈추기").pressed.emit()
	assert_eq(p.action, "")
	assert_null(game.hud.modal.find_child("BagStrip", true, false), "stop unfolds at once")
	assert_not_null(game.hud.modal.find_child("Bag", true, false))
	assert_eq(game.data["containers"][id]["items"], ["bandage", "food_pack"], "stopping keeps what was not taken")
	game.hud._close_modal()


## The bag and the place side by side (결정 558): a bag row goes to the place shown.
func test_the_bag_beside_a_box_sends_its_row_to_the_box() -> void:
	var game = _game()
	var p = game.player
	p.items.clear()
	p.add_item("scrap", 1)
	var id: String = _box(game, [])
	game.hud.loot(id)
	assert_eq(String(game.hud.inv_near["id"]), id)
	assert_not_null(game.hud.modal.find_child("Bag", true, false), "the bag's rows")
	assert_not_null(game.hud.modal.find_child("Near", true, false), "and the box's, side by side")
	var row: Button = _row(game.hud, "Bag", "scrap")
	assert_not_null(row)
	if row == null:
		return
	assert_false(row.disabled)
	row.pressed.emit()
	assert_has(game.data["containers"][id]["items"], "scrap")
	assert_false(p.items.has("scrap"))
	assert_eq(String(game.hud.inv_near["id"]), id, "a refresh keeps the box")
	game.hud._close_modal()


## Whole multiples of 32 device pixels (decision 489): the window's stretch is in
## the count — the multiple nearest the line icon's size that fits the row.
func test_pixel_art_is_nearest_at_whole_device_multiples_with_a_line_fallback() -> void:
	var game = _game()
	# The can opener has no baked picture: it keeps its line icon.
	var id: String = _box(game, ["food_pack", "can_opener"])
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
	var room: float = UiFonts.px(InventoryPane.ROW_H - 4.0)
	for s: float in [1.0, 1.5, 2.0, 3.0]:
		var whole: float = InventoryPane.whole_pixels(UiFonts.px(InventoryPane.ART) * s, room * s)
		gut.p("stretch %.1f: art %.0f device px" % [s, whole])
		assert_gt(whole, 0.0)
		assert_eq(fmod(whole, 32.0), 0.0)
		assert_lte(whole, room * s)
	assert_eq(InventoryPane.whole_pixels(1.0, 8.0), 0.0, "a window too small for 32 pixels")
	var scale: Vector2 = (icon.get_viewport().get_final_transform() * icon.get_global_transform_with_canvas()).get_scale().abs()
	var s_here: float = minf(scale.x, scale.y)
	var expected: float = InventoryPane.whole_pixels(UiFonts.px(InventoryPane.ART) * s_here, room * s_here)
	gut.p("this window: stretch %.3f, art %.2f device px" % [s_here, icon.size.x * s_here])
	if expected > 0.0:
		assert_almost_eq(icon.size.x * s_here, expected, 0.01, "the art lands on whole device pixels")
	else:
		assert_almost_eq(icon.size.x, UiFonts.px(InventoryPane.ITEM_ICON), 0.01, "too small a window keeps the line icon's size")
	assert_almost_eq(icon.size.x, icon.size.y, 0.01)
	var fallback := _row(game.hud, "Near", "can_opener").find_child("ItemIcon", true, false) as TextureRect
	assert_eq(fallback.stretch_mode, TextureRect.STRETCH_KEEP_ASPECT_CENTERED)
	assert_almost_eq(fallback.size.x, UiFonts.px(InventoryPane.ITEM_ICON), 1.0)
	assert_almost_eq(fallback.size.y, UiFonts.px(InventoryPane.ITEM_ICON), 1.0)
	assert_eq(fallback.texture, HudIcons.texture(game.item_icon("can_opener"), UiFonts.size(InventoryPane.ITEM_ICON), GlassPane.INK2, 1.0 / HudIcons.LINE), "a missing png uses the existing line icon")
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
		var minimum: float = UiFonts.px(InventoryPane.KEY) * minf(scale.x, scale.y)
		if short_side < least:
			least = short_side
			least_word = key.text if key.text != "" else key.tooltip_text
		assert_gte(short_side + 0.1, minimum, "%s: %s %.2f px, minimum %.2f px" % [where, key.name, short_side, minimum])
	gut.p("%s: smallest key %.2f screen px (%s)" % [where, least, least_word])


## Every press is 48 dp = 52 css (결정 558); the clothes fold into one key beside
## the floor (and away beside a box), and a row held open keeps its keys as big.
func test_every_touch_target_is_at_least_48_dp_and_clothing_folds() -> void:
	var game = _game()
	var id: String = _box(game)
	game.player.add_item("food_pack", 1)
	game.hud.loot(id)
	await _layout()
	_touch_sizes(game.hud, "box")
	assert_null(game.hud.modal.find_child("WornFold", true, false), "beside a box the clothes fold away")
	game.hud._inv_expand("bag", "food_pack")
	await _layout()
	assert_not_null(game.hud.modal.find_child("More", true, false), "the row held open")
	_touch_sizes(game.hud, "held open")
	_tab(game.hud, "ground").pressed.emit()
	await _layout()
	_touch_sizes(game.hud, "floor")
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
	assert_almost_eq(pane.size.x, InventoryPane.pane_px(), 0.5, "the clothes key keeps its long word inside the fixed width")
	(game.hud.modal.find_child("WornFold", true, false) as Button).pressed.emit()
	assert_false((game.hud.modal.find_child("Worn", true, false) as Control).visible)
	game.hud._close_modal()


## Another place chosen while a thing comes out: the taking goes on, and when it is
## out the place chosen stays, the field still again.
func test_another_place_keeps_taking_and_stays_chosen_when_it_finishes() -> void:
	var game = _game()
	var p = game.player
	p.items.clear()
	var id: String = _box(game, ["food_pack"])
	game.hud.loot(id)
	_row(game.hud, "Near", "food_pack").pressed.emit()
	_tab(game.hud, "ground").pressed.emit()
	assert_eq(String(game.hud.inv_near.get("kind", "")), "ground")
	assert_eq(p.action, "take")
	assert_false(game.paused)
	assert_eq(game.hud.taking_box, id)
	p.action_t = 0.001
	game._update_person(p, 0.1)
	assert_eq(p.action, "")
	assert_eq(String(game.hud.inv_near.get("kind", "")), "ground")
	assert_eq(int(p.items.get("food_pack", 0)), 1)
	assert_true(game.paused)
	assert_eq(game.hud.taking_box, "")
	game.hud._close_modal()


func test_another_place_shuts_the_box_and_returning_opens_it_once() -> void:
	var game = _game()
	var id: String = _box(game)
	var audio = game.audio
	audio.box_quiet_until = 0
	var before: int = audio.played.size()
	game.hud.loot(id)
	audio.box_quiet_until = 0
	_tab(game.hud, "ground").pressed.emit()
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


## A short list still shows every place: the rail scrolls only when the screen runs
## out (between the fold at its top and the main key at its foot, three show).
func test_a_short_list_still_shows_every_place() -> void:
	var game = _game()
	var id: String = _box(game, [])
	var c: Dictionary = game.data["containers"][id]
	for i in range(1):
		game.data["containers"]["na_near_%d" % i] = c.duplicate(true)
	game.hud.loot(id)
	await _layout()
	var places: Control = game.hud.modal.find_child("Places", true, false)
	var rail := game.hud.modal.find_child("PlaceScroll", true, false) as ScrollContainer
	assert_eq(places.get_child_count(), 3, "two boxes and the ground")
	var need: float = places.get_combined_minimum_size().y
	assert_gte(rail.size.y + 0.5, need, "rail %.1f px for places %.1f px" % [rail.size.y, need])
	assert_false(game.hud.modal.find_child("PlaceMore", true, false).visible, "all three show: no fade")
	game.hud._close_modal()


## The places rail stands five keys high at most and scrolls past them, its foot
## faded while more lie below; scrolled to the end, no fade (coordinator 10-30).
func test_the_places_rail_stops_at_five_keys_and_fades_while_more_lie_below() -> void:
	var game = _game()
	var hud = game.hud
	var id: String = _box(game, ["food_pack"])
	var c: Dictionary = game.data["containers"][id]
	for i in range(6):
		game.data["containers"]["na_more_%d" % i] = c.duplicate(true)
	hud.loot(id)
	await _layout()
	var places: Control = hud.modal.find_child("Places", true, false)
	var rail := hud.modal.find_child("PlaceScroll", true, false) as ScrollContainer
	var more := hud.modal.find_child("PlaceMore", true, false) as Control
	assert_eq(places.get_child_count(), 8, "seven boxes and the ground")
	assert_lte(rail.custom_minimum_size.y, UiFonts.px(InventoryPane.RAIL_MAX) + 0.5, "five keys high at most")
	assert_lt(rail.size.y + 0.5, places.get_combined_minimum_size().y, "the rail scrolls the rest")
	assert_true(more.visible, "the foot fades while more lie below")
	rail.scroll_vertical = 100000
	assert_false(more.visible, "scrolled to the end, no fade")
	hud._close_modal()


## Decision 532: RUN, the lamp and the stick sleep with the rest of the HUD.
func test_run_and_the_rest_sleep_dimmed_until_the_pane_closes() -> void:
	var game = _game()
	var hud = game.hud
	hud.loot(_box(game))
	await _layout()
	assert_lt(hud.run_button.modulate.a, 0.5, "RUN sleeps, dimmed")
	assert_lt(hud.lamp_button.modulate.a, 0.5, "the lamp sleeps, dimmed")
	assert_lt(hud.touch.modulate.a, 0.5, "the stick sleeps, dimmed")
	assert_lt(hud.portrait.modulate.a, 0.5, "the portrait sleeps, dimmed")
	var was: bool = hud.run_button.button_pressed
	var at: Vector2 = hud.run_button.get_global_rect().get_center()
	_touch(hud, at, true)
	_touch(hud, at, false)
	assert_eq(hud.run_button.button_pressed, was, "RUN does not toggle under the pane")
	assert_eq(hud.stick_index, -1, "and plants no stick")
	assert_false(hud.modal_open, "a tap outside folds the pane")
	assert_almost_eq(hud.run_button.modulate.a, 1.0, 0.001, "RUN wakes")
	assert_almost_eq(hud.portrait.modulate.a, 1.0, 0.001, "the pane put away wakes it")


## The bag key over another pane opens the bag afresh, beside the first place near.
func test_the_bag_over_another_pane_opens_on_the_bag() -> void:
	var game = _game()
	var id: String = _box(game)
	game.hud.loot(id)
	game.hud._close_modal()
	game.hud.body_panel()
	game.hud.bag_panel()
	assert_not_null(game.hud.modal.find_child("Bag", true, false))
	assert_eq(String(game.hud.inv_near.get("kind", "")), "box", "beside the first place near, afresh")
	game.hud._close_modal()


## While a thing comes out of a box the bag stays at hand as before (its rows and,
## held open, what a row can do); only the rows of that box wait.
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
	assert_null(_row(game.hud, "Bag", "scrap"), "while taking the bag folds to a strip")
	var strip := game.hud.modal.find_child("BagStrip", true, false) as Button
	assert_not_null(strip)
	strip.pressed.emit()
	assert_true(game.hud.inv_fold_open)
	var row: Button = _row(game.hud, "Bag", "scrap")
	assert_not_null(row)
	if row != null:
		assert_false(row.disabled, "a bag row is still at hand while taking")
		row.pressed.emit()
		assert_true(p.items.has("scrap"), "the box things come out of takes nothing in while busy")
		assert_eq(p.action, "take", "and the taking goes on")
	game.hud._inv_expand("bag", "can_beans")
	assert_eq(p.action, "take", "holding a row open does not stop the taking")
	var eat := game.hud.modal.find_child("Eat", true, false) as Button
	assert_not_null(eat, "the held row offers eating")
	if eat != null:
		assert_false(eat.disabled, "eating stays open while taking")
	for key: Button in game.hud.modal.find_child("Near", true, false).find_children("*", "Button", true, false):
		assert_true(key.disabled, "the box being taken from waits")
	game.hud._close_modal()


## The place a bag row goes to is the one shown beside the bag: its key on the rail
## is the chosen one, its name heads the right column.
func test_the_place_beside_the_bag_is_where_a_row_goes() -> void:
	var game = _game()
	var id: String = _box(game)
	game.data["containers"][id]["furniture"] = "fridge_open"
	game.hud.loot(id)
	var chosen: Button = _tab(game.hud, "box", id)
	assert_not_null(chosen)
	if chosen != null:
		assert_true(bool(chosen.get_meta("selected")))
		assert_eq((chosen.get_theme_stylebox("normal") as StyleBoxFlat).border_color, InventoryPane.BONE)
	assert_false(bool(_tab(game.hud, "ground").get_meta("selected")))
	var title := game.hud.modal.find_child("Title", true, false) as Label
	assert_eq(title.text, "냉장고", "the right column is the fridge")
	game.hud._close_modal()


## By the train with two weapons: the swap key, and 싣기 at the rail's foot; the pane
## keeps its width.
func test_the_bag_by_the_train_keeps_the_width() -> void:
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
	assert_almost_eq(pane.size.x, InventoryPane.pane_px(), 0.5, "the keys fit in the fixed width")
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


## Decision 532: dragging over the sleeping stick cannot advance the field.
func test_the_stick_stays_locked_with_the_bag_up() -> void:
	var game = _game()
	var hud = game.hud
	hud.loot(_box(game))
	await _layout()
	assert_true(game.paused)
	var home: Vector2 = hud.stick_home()
	_touch(hud, home, true)
	_drag(hud, home + Vector2(hud.STICK_R, 0))
	assert_eq(game.player.stick, Vector2.ZERO, "the stick sleeps under the bag pane")
	hud.tick(0.016)
	assert_true(game.paused, "the field stays paused")
	assert_true(hud.modal_open, "the pane stays up")
	_touch(hud, home + Vector2(hud.STICK_R, 0), false)
	hud.tick(0.016)
	assert_eq(game.player.stick, Vector2.ZERO)
	assert_true(game.paused, "a drag is not a closing tap")
	assert_true(hud.modal_open)
	hud._close_modal()


## The sleeping stick cannot cancel the take that keeps the field running.
func test_dragging_over_the_stick_keeps_taking_under_the_pane() -> void:
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
	assert_eq(p.action, "take", "the stick cannot cancel the take")
	assert_eq(p.stick, Vector2.ZERO)
	assert_has(game.data["containers"][id]["items"], "food_pack", "the thing is still coming out")
	hud.tick(0.016)
	assert_true(hud.modal_open, "the pane stays up")
	assert_eq(hud.modal, hud.box_pane)
	assert_eq(hud.taking_box, id)
	assert_not_null(_key(hud, "멈추기"))
	assert_false(game.paused, "taking still advances the field")
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


## A first finger outside must not steal another finger's pane buttons.
func test_a_second_finger_presses_the_pane_with_the_first_outside() -> void:
	var game = _game()
	var hud = game.hud
	hud.loot(_box(game))
	await _layout()
	var home: Vector2 = hud.stick_home()
	_touch(hud, home, true)
	var at: Vector2 = _tab(hud, "ground").get_global_rect().get_center()
	_touch(hud, at, true, 1)
	_touch(hud, at, false, 1)
	assert_eq(String(hud.inv_near.get("kind", "")), "ground", "the second finger took the floor's key")
	assert_eq(hud.stick_index, -1, "no stick was planted")
	assert_eq(game.player.stick, Vector2.ZERO)
	_touch(hud, home, false)
	assert_true(hud.modal_open, "the old outside finger cannot close the rebuilt pane")
	assert_true(game.paused)
	hud._close_modal()


## The same finger drags the pane's list, and lifting presses nothing.
func test_a_second_finger_drags_the_list_with_the_first_outside() -> void:
	var game = _game()
	var p = game.player
	var hud = game.hud
	hud.loot(_box(game, LONG_BOX))
	await _layout()
	var home: Vector2 = hud.stick_home()
	_touch(hud, home, true)
	var list := hud.modal.find_child("NearScroll", true, false) as ScrollContainer
	var row: Button = list.find_children("*", "Button", true, false)[0]
	var at: Vector2 = row.get_global_rect().get_center()
	_touch(hud, at, true, 1)
	_drag(hud, at + Vector2(0, -80), 1)
	_touch(hud, at + Vector2(0, -80), false, 1)
	assert_gt(list.scroll_vertical, 0, "the second finger dragged the list")
	assert_ne(p.action, "take", "a drag takes no row")
	_touch(hud, home, false)
	hud._close_modal()


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


## 결정 558 by the touch path itself: a second finger, the first resting outside
## (a thumb left on the stick), held on a bag row opens it under itself and moves
## nothing; a tap of the same finger still moves it across.
func test_by_touch_a_second_finger_held_on_a_row_opens_it_and_moves_nothing() -> void:
	var game = _game()
	var p = game.player
	var hud = game.hud
	p.items.clear()
	p.add_item("scrap", 1)
	var id: String = _box(game, ["food_pack"])
	hud.loot(id)
	await _layout()
	var home: Vector2 = hud.stick_home()
	_touch(hud, home, true)
	var row: Button = _row(hud, "Bag", "scrap")
	var rest: StyleBox = row.get_theme_stylebox("normal")
	var line_y: float = (row.get_node("Line") as Control).position.y
	var at: Vector2 = row.get_global_rect().get_center()
	_touch(hud, at, true, 1)
	# 결정 561 ④ on this path too: the face shown is the pressed one, as far down
	# as the line (the button's own pressed state is not set here).
	assert_eq(row.get_theme_stylebox("normal"), row.get_theme_stylebox("pressed"), "a second finger's press shows the pressed face")
	assert_almost_eq((row.get_node("Line") as Control).position.y - line_y, UiFonts.px(InventoryPane.PRESS_SINK), 0.01, "with the line sunk as far")
	# Taken away (not a tap, so nothing moves): its own face again, the line up.
	_touch(hud, at, false, 1, true)
	assert_eq(row.get_theme_stylebox("normal"), rest, "taken away, its own face again")
	assert_almost_eq((row.get_node("Line") as Control).position.y, line_y, 0.01, "and its line back up")
	assert_eq(int(p.items.get("scrap", 0)), 1, "a finger taken away moves nothing")
	_touch(hud, at, true, 1)
	await _wait(InventoryPane.LONG_S + 0.2)
	_touch(hud, at, false, 1)
	assert_eq(int(p.items.get("scrap", 0)), 1, "a held row stays in the bag")
	assert_does_not_have(game.data["containers"][id]["items"], "scrap")
	assert_eq(String(hud.inv_expand.get("id", "")), "scrap", "the held row opened under itself")
	assert_not_null(hud.modal.find_child("More", true, false), "its keys show under it")
	await _layout()
	at = _row(hud, "Bag", "scrap").get_global_rect().get_center()
	_touch(hud, at, true, 1)
	_touch(hud, at, false, 1)
	assert_false(p.items.has("scrap"), "a tap moves the row across")
	assert_has(game.data["containers"][id]["items"], "scrap")
	_touch(hud, home, false)
	hud._close_modal()


## 결정 559 by the touch path: an empty can calls the dead, so its key under the
## held row throws only when held full — a short press lets the line wind back
## unthrown. The first finger's GUI path is covered in its own SubViewport below.
func test_by_touch_the_can_is_thrown_only_when_its_key_is_held_full() -> void:
	var game = _game()
	var p = game.player
	var hud = game.hud
	p.items.clear()
	p.add_item("can_empty", 2)
	hud.bag_panel()
	await _layout()
	hud._inv_expand("bag", "can_empty")
	await _layout()
	var throw := hud.modal.find_child("Throw", true, false) as Button
	assert_not_null(throw, "the held can offers throwing")
	if throw == null:
		hud._close_modal()
		return
	var hold = throw.get_node("Hold")
	var home: Vector2 = hud.stick_home()
	_touch(hud, home, true)
	var at: Vector2 = throw.get_global_rect().get_center()
	_touch(hud, at, true, 1)
	# The half hold by fixed steps, not the clock: a slow frame past HOLD_S would
	# fire it and free the hold under the check.
	hold.set_process(false)
	hold.advance(HoldConfirm.HOLD_S * 0.5)
	assert_almost_eq(float(hold.state["fill"]), 0.5, 0.01, "the line fills while the finger stays")
	_touch(hud, at, false, 1)
	hold.set_process(false)
	hold.advance(HoldConfirm.BACK_S + 0.01)
	assert_eq(int(p.items.get("can_empty", 0)), 2, "a short press throws nothing")
	assert_true(hud.modal_open, "the pane stays up")
	assert_eq(float(hold.get("state")["fill"]), 0.0, "the line wound back")
	_touch(hud, at, true, 1)
	await _wait(HoldConfirm.HOLD_S + HoldConfirm.FLASH_S + 0.25)
	_touch(hud, at, false, 1)
	assert_eq(int(p.items.get("can_empty", 0)), 1, "a full hold throws one can")
	_touch(hud, home, false)
	if hud.modal_open:
		hud._close_modal()


## 결정 559 with a second finger: what goes aboard is the train's, so 싣기 loads
## only when held full, while the first finger rests outside the pane.
func test_by_touch_a_second_finger_loads_the_train_only_when_held_full() -> void:
	var game = _game()
	var p = game.player
	var hud = game.hud
	p.items.clear()
	p.add_item("scrap", 1)
	var unload: Rect2i = game.data["unload"]
	p.position = game.lift(unload.position + Vector2i(3, 1), 0)
	p.stop()
	hud.bag_panel()
	await _layout()
	var key := hud.modal.find_child("MainKey", true, false) as Button
	assert_not_null(key)
	if key == null:
		hud._close_modal()
		return
	assert_eq(key.text, "열차에 싣기")
	var home: Vector2 = hud.stick_home()
	_touch(hud, home, true)
	var at: Vector2 = key.get_global_rect().get_center()
	var hold = key.get_node("Hold")
	# Half holds by fixed steps, not the clock (a slow frame would fire them).
	_touch(hud, at, true, 1)
	hold.set_process(false)
	hold.advance(HoldConfirm.HOLD_S * 0.5)
	_touch(hud, at, false, 1)
	assert_eq(int(p.items.get("scrap", 0)), 1, "a short press loads nothing")
	# Let the line wind back first: pressed again while winding back it fills on
	# from where it stood (hold_step), which would fire before the check below.
	hold.set_process(false)
	hold.advance(HoldConfirm.BACK_S + 0.01)
	assert_eq(float(hold.state["fill"]), 0.0, "the short press wound back")
	_touch(hud, at, true, 1)
	_drag(hud, at + Vector2(30, 0), 1)
	hold.set_process(false)
	hold.advance(HoldConfirm.HOLD_S * 0.5)
	assert_almost_eq(float(hold.state["fill"]), 0.5, 0.01, "30 canvas px inside the key keeps filling")
	assert_eq(int(p.items.get("scrap", 0)), 1, "half a hold loads nothing yet")
	# The rest by the clock: the frames themselves fill it.
	hold.set_process(true)
	await _wait(HoldConfirm.HOLD_S * 0.5 + HoldConfirm.FLASH_S + 0.25)
	_touch(hud, at, false, 1)
	assert_false(p.items.has("scrap"), "a full hold loads it")
	assert_eq(int(game.unloaded.get("scrap", 0)), 1, "aboard once")
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


## Laid again after a content change, the item list keeps its scroll.
func test_laying_again_keeps_the_list_where_it_was() -> void:
	var game = _game()
	var hud = game.hud
	hud.loot(_box(game, LONG_BOX))
	await _layout()
	var list := hud.modal.find_child("NearScroll", true, false) as ScrollContainer
	list.scroll_vertical = 60
	var was: int = list.scroll_vertical
	assert_gt(was, 0, "the list scrolls")
	hud._lay_bag_again()
	await _layout()
	var again := hud.modal.find_child("NearScroll", true, false) as ScrollContainer
	assert_ne(again, list, "the pane was laid again")
	assert_eq(again.scroll_vertical, was, "the list is where it was")
	hud._close_modal()


## The sleeping RUN key's ring is outside the pane too.
func test_the_ring_round_run_folds_the_pane_without_planting_a_stick() -> void:
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
	assert_false(hud.modal_open)


## A canceled outside touch neither closes the pane nor becomes a field tap.
func test_a_canceled_outside_touch_does_nothing_under_the_pane() -> void:
	var game = _game()
	game.opts["stick_float"] = true
	var hud = game.hud
	hud.loot(_box(game))
	await _layout()
	var at := Vector2(hud._view_size().x * 0.25, hud._view_size().y * 0.4)
	_touch(hud, at, true)
	assert_eq(hud.stick_index, -1)
	hud.stick_tap_ms = 0
	_touch(hud, at, false, 0, true)
	assert_eq(hud.stick_index, -1)
	assert_eq(hud.stick_tap_ms, 0, "and is no lift")
	assert_true(hud.modal_open)
	hud._close_modal()


## External relocation still refreshes nearby places; the bag itself cannot walk.
func test_external_relocation_drops_a_box_place_and_shows_the_bag() -> void:
	var game = _game()
	var hud = game.hud
	var id: String = _box(game)
	hud.loot(id)
	assert_not_null(_tab(hud, "box", id))
	var unload: Rect2i = game.data["unload"]
	game.player.position = game.lift(unload.position + Vector2i(3, 1), 0)
	hud.tick(0.5)
	assert_null(_tab(hud, "box", id), "the box left behind is off the rail")
	assert_not_null(hud.modal.find_child("Bag", true, false))
	# Its destination falls to the floor, not on its own to the train's hold
	# though it is near now: a thing loaded there cannot come back from here.
	assert_not_null(_tab(hud, "train"), "the train's hold is near")
	assert_eq(String(hud.inv_near.get("kind", "")), "ground", "the destination falls to the floor")
	hud._close_modal()


## An empty box's mark sits inside its key with the name, at the screen's edge:
## a short name whole, a long fallback giving up its last letters.
func test_the_empty_mark_stays_inside_its_key() -> void:
	for name_and_kind: Array in [["서랍장", "dresser"], ["오래된 나무 궤짝", "no_such_furniture"]]:
		var game = _game()
		var hud = game.hud
		var id: String = _box(game, [])
		var c: Dictionary = game.data["containers"][id]
		c["name"] = name_and_kind[0]
		c["furniture"] = name_and_kind[1]
		hud.loot(id)
		await _layout()
		var key: Button = _tab(hud, "box", id)
		var edge: Rect2 = key.get_global_rect()
		var mark: Label = null
		for word: Label in key.find_children("*", "Label", true, false):
			if word.text == "·빈":
				mark = word
			assert_gte(word.get_global_rect().position.x, edge.position.x - 0.5, "%s: %s starts inside the key" % [name_and_kind[0], word.text])
			assert_lte(word.get_global_rect().end.x, edge.end.x + 0.5, "%s: %s ends inside the key" % [name_and_kind[0], word.text])
		assert_not_null(mark, "the empty box is marked")
		hud._close_modal()


## The bag pane's shade lies under the pane alone; other panes keep the full shade.
func test_the_bag_shade_leaves_the_left_clear() -> void:
	var game = _game()
	game.hud.loot(_box(game))
	await _layout()
	var dim := game.hud.modal.get_node("Shade") as ColorRect
	var canvas: Rect2 = dim.get_viewport_rect()
	var rect: Rect2 = dim.get_global_rect()
	assert_gt(rect.position.x, canvas.size.x * 0.25, "the shade starts at %.1f of %.1f" % [rect.position.x, canvas.size.x])
	assert_almost_eq(rect.end.x, canvas.end.x, 1.0)
	game.hud._close_modal()
	game.hud.body_panel()
	var body_dim := game.hud.modal.get_node("Shade") as ColorRect
	assert_almost_eq(body_dim.get_global_rect().position.x, 0.0, 1.0, "other panes keep the full shade")
	game.hud._close_modal()


## 결정 558: taking covers no more than the old pane, without shifting the place.
func test_taking_folds_to_the_old_width_then_lingers_and_unfolds() -> void:
	var game = _game()
	var hud = game.hud
	var p = game.player
	p.items.clear()
	var id: String = _box(game, ["scrap"])
	hud.loot(id)
	await _layout()
	var near_x: float = hud.modal.find_child("NearScroll", true, false).global_position.x
	_row(hud, "Near", "scrap").pressed.emit()
	await _layout()
	var pane: Control = hud.modal.find_child("Pane", true, false)
	var base: Vector2 = Vector2(float(ProjectSettings.get_setting("display/window/size/viewport_width")), float(ProjectSettings.get_setting("display/window/size/viewport_height")))
	assert_almost_eq(pane.size.x, InventoryPane.pane_px(true), 0.5)
	assert_lte(pane.get_global_rect().size.x / base.x, 0.476)
	assert_almost_eq(pane.get_global_rect().end.x, pane.get_viewport_rect().end.x, 1.0)
	assert_almost_eq(float(hud.modal.find_child("NearScroll", true, false).global_position.x), near_x, 1.0)
	assert_not_null(hud.modal.find_child("BagStrip", true, false))
	# Taking for longer than the linger (the field stands still here, so the thing
	# is still coming out): the fold's second runs from the last thing out, not
	# from the laying that began it.
	await _wait(InventoryPane.FOLD_LINGER_S + 0.1)
	assert_eq(p.action, "take")
	p.action_t = 0.001
	# The pane is laid somewhere between these two ticks (laying it takes time).
	var before_ms: int = Time.get_ticks_msec()
	game._update_person(p, 0.1)
	var after_ms: int = Time.get_ticks_msec()
	assert_eq(p.action, "")
	assert_not_null(hud.modal.find_child("BagStrip", true, false), "the last thing out keeps the fold briefly")
	var linger_ms: int = int(InventoryPane.FOLD_LINGER_S * 1000.0)
	assert_between(hud.inv_fold_until_ms, before_ms + linger_ms, after_ms + linger_ms, "a second from the last thing out")
	# Laid again while it lingers (a row opened, a place shown): still folded, and
	# the second is not stretched.
	var deadline: int = hud.inv_fold_until_ms
	InventoryPane.open(hud, hud.inv_near)
	assert_not_null(hud.modal.find_child("BagStrip", true, false), "laid again within the second, still folded")
	assert_eq(hud.inv_fold_until_ms, deadline, "the second is not stretched")
	# Short of the deadline it is still folded (checked only while the clock is
	# short of it: a stalled frame says nothing either way).
	await _wait(maxf(0.0, float(deadline - Time.get_ticks_msec()) / 1000.0 - 0.4))
	if Time.get_ticks_msec() < deadline - 50:
		assert_not_null(hud.modal.find_child("BagStrip", true, false), "folded until the second is up")
	await _wait(maxf(0.0, float(hud.inv_fold_until_ms - Time.get_ticks_msec()) / 1000.0) + 0.15)
	await _layout()
	assert_null(hud.modal.find_child("BagStrip", true, false))
	assert_not_null(hud.modal.find_child("Bag", true, false))
	assert_false(hud.inv_fold_open)
	hud._close_modal()


## 「모두 담기」 keeps the bag folded from one thing to the next and lingers its
## second from the last thing out, however long the box took.
func test_taking_everything_folds_until_the_last_is_out() -> void:
	var game = _game()
	var hud = game.hud
	var p = game.player
	p.items.clear()
	var id: String = _box(game, ["scrap", "wood"])
	hud.loot(id)
	await _layout()
	hud._loot_all(id)
	await _layout()
	assert_eq(p.action, "take")
	assert_not_null(hud.modal.find_child("BagStrip", true, false), "taking everything folds the bag")
	p.action_t = 0.001
	game._update_person(p, 0.1)
	assert_eq(p.action, "take", "the next thing is coming out")
	assert_not_null(hud.modal.find_child("BagStrip", true, false), "between two things the bag stays folded")
	await _wait(InventoryPane.FOLD_LINGER_S + 0.1)
	p.action_t = 0.001
	var before_ms: int = Time.get_ticks_msec()
	game._update_person(p, 0.1)
	var after_ms: int = Time.get_ticks_msec()
	assert_eq(p.action, "")
	assert_true((game.data["containers"][id]["items"] as Array).is_empty(), "the box is empty")
	assert_not_null(hud.modal.find_child("BagStrip", true, false), "the last thing out keeps the fold its second")
	var linger_ms: int = int(InventoryPane.FOLD_LINGER_S * 1000.0)
	assert_between(hud.inv_fold_until_ms, before_ms + linger_ms, after_ms + linger_ms, "a second from the box's last thing out")
	await _wait(maxf(0.0, float(hud.inv_fold_until_ms - Time.get_ticks_msec()) / 1000.0) + 0.15)
	await _layout()
	assert_null(hud.modal.find_child("BagStrip", true, false))
	assert_not_null(hud.modal.find_child("Bag", true, false))
	hud._close_modal()


func test_plain_button_fingers_need_no_pane_only_keys() -> void:
	var game = _game()
	var hud = game.hud
	var key := Button.new()
	add_child_autofree(key)
	key.size = Vector2(100, 60)
	hud.fingers[7] = {"kind": "button", "button": key, "start": Vector2.ZERO}
	assert_true(hud.finger_move(7, Vector2(40, 0)))
	assert_true(hud.finger_up(7, Vector2(40, 0)))
	assert_false(hud.fingers.has(7))
	hud._finger_key_up({"kind": "button"})


func test_a_dim_bag_row_still_opens_its_jobs_without_moving() -> void:
	var game = _game()
	var p = game.player
	p.items = {"can_beans": 1}
	var id: String = _box(game, ["wood", "wood", "wood", "wood", "wood", "wood"])
	game.data["containers"][id]["furniture"] = "nightstand"
	game.hud.loot(id)
	var row: Button = _row(game.hud, "Bag", "can_beans")
	assert_false(row.disabled)
	assert_lt((row.get_node("Line") as Control).modulate.a, 1.0)
	row.pressed.emit()
	assert_eq(int(p.items.get("can_beans", 0)), 1)
	row.button_down.emit()
	await _wait(InventoryPane.LONG_S + 0.15)
	assert_not_null(game.hud.modal.find_child("Eat", true, false))
	assert_true((game.hud.modal.find_child("Move", true, false) as Button).disabled)
	game.hud._close_modal()


func test_the_second_duplicate_box_row_opens_and_keeps_its_source_index() -> void:
	var game = _game()
	var hud = game.hud
	var id: String = _box(game, ["scrap", "scrap"])
	hud.loot(id)
	var near: Node = hud.modal.find_child("Near", true, false)
	(near.get_child(1) as Button).button_down.emit()
	await _wait(InventoryPane.LONG_S + 0.15)
	near = hud.modal.find_child("Near", true, false)
	assert_eq(int(hud.inv_expand.get("i", -1)), 1)
	assert_eq(near.get_child_count(), 3)
	assert_eq(String(near.get_child(2).name), "More")
	# Distinguish the two source slots after wiring; the callback must still use 1.
	game.data["containers"][id]["items"][1] = "wood"
	(hud.modal.find_child("Take", true, false) as Button).pressed.emit()
	assert_eq(game.actions.taking_item(game.player), "wood")
	hud._loot_stop(id)
	hud.inv_expand = {"side": "near", "id": "scrap", "i": 99, "at": InventoryPane.place_key(hud.inv_near)}
	hud.bag_panel()
	assert_null(hud.modal.find_child("More", true, false), "a stale source index opens nothing")
	hud.inv_expand = {"side": "near", "id": "scrap", "i": 0, "at": "box:gone"}
	hud.bag_panel()
	assert_null(hud.modal.find_child("More", true, false), "a stale place opens nothing")
	hud._close_modal()


func test_a_second_finger_moved_twenty_pixels_cannot_open_a_row() -> void:
	var game = _game()
	var hud = game.hud
	game.player.items = {"scrap": 1}
	hud.loot(_box(game, []))
	await _layout()
	var home: Vector2 = hud.stick_home()
	_touch(hud, home, true)
	var row: Button = _row(hud, "Bag", "scrap")
	var at: Vector2 = row.get_global_rect().get_center()
	_touch(hud, at, true, 1)
	_drag(hud, at + Vector2(20, 0), 1)
	assert_true(bool(row.get_meta("dragged")))
	await _wait(InventoryPane.LONG_S + 0.15)
	assert_true(hud.inv_expand.is_empty())
	_touch(hud, at + Vector2(20, 0), false, 1)
	assert_eq(int(game.player.items.get("scrap", 0)), 1)
	_touch(hud, home, false)
	hud._close_modal()


func test_drop_touch_releases_a_manual_hold_and_row() -> void:
	var game = _game()
	var hud = game.hud
	game.player.items = {"can_empty": 2}
	hud.bag_panel()
	hud._inv_expand("bag", "can_empty")
	await _layout()
	var key := hud.modal.find_child("Throw", true, false) as Button
	var hold = key.get_node("Hold")
	_touch(hud, hud.stick_home(), true)
	_touch(hud, key.get_global_rect().get_center(), true, 1)
	hold.set_process(false)
	hold.advance(HoldConfirm.HOLD_S * 0.5)
	hud.drop_touch()
	hold.set_process(false)
	hold.advance(HoldConfirm.BACK_S + 0.01)
	assert_eq(float(hold.state["fill"]), 0.0)
	assert_eq(int(game.player.items["can_empty"]), 2)
	var row: Button = _row(hud, "Bag", "can_empty")
	_touch(hud, row.get_global_rect().get_center(), true, 2)
	hud.drop_touch()
	await _wait(InventoryPane.LONG_S + 0.15)
	assert_eq(String(hud.inv_expand.get("id", "")), "can_empty", "the dropped row press cannot toggle it closed")
	hud._close_modal()


func test_a_hold_dragged_past_its_edge_lets_go_without_scrolling() -> void:
	var game = _game()
	var hud = game.hud
	game.player.items = {"can_empty": 2, "scrap": 1, "wood": 1, "cloth": 1, "bandage": 1, "plank": 1, "flare": 1, "food_pack": 1}
	hud.bag_panel()
	hud._inv_expand("bag", "can_empty")
	await _layout()
	var key := hud.modal.find_child("Throw", true, false) as Button
	var hold = key.get_node("Hold")
	var list := hud.modal.find_child("BagScroll", true, false) as ScrollContainer
	list.ensure_control_visible(key)
	await get_tree().process_frame
	var was: int = list.scroll_vertical
	var at: Vector2 = key.get_global_rect().get_center()
	_touch(hud, hud.stick_home(), true)
	_touch(hud, at, true, 1)
	hold.set_process(false)
	hold.advance(HoldConfirm.HOLD_S * 0.5)
	_drag(hud, at + Vector2(0, -200), 1)
	hold.set_process(false)
	hold.advance(HoldConfirm.BACK_S + 0.01)
	assert_eq(float(hold.state["fill"]), 0.0)
	assert_eq(list.scroll_vertical, was, "a finger born on a hold never scrolls")
	assert_eq(int(game.player.items["can_empty"]), 2)
	# Back on the key without lifting: the slip let go for good (as by the GUI).
	_drag(hud, at, 1)
	hold.set_process(false)
	hold.advance(HoldConfirm.HOLD_S + 0.01)
	assert_eq(float(hold.state["fill"]), 0.0, "back on the key it fills nothing")
	_touch(hud, at, false, 1)
	assert_eq(int(game.player.items["can_empty"]), 2, "and nothing is thrown")
	hud._close_modal()


func test_a_train_bag_row_moves_one_kind_without_a_hold() -> void:
	var game = _game()
	var p = game.player
	p.items = {"scrap": 2, "wood": 1}
	var unload: Rect2i = game.data["unload"]
	p.position = game.lift(unload.position + Vector2i(3, 1), 0)
	p.stop()
	game.hud.bag_panel()
	assert_not_null(game.hud.modal.find_child("MainKey", true, false).get_node_or_null("Hold"))
	var row: Button = _row(game.hud, "Bag", "scrap")
	assert_null(row.get_node_or_null("Hold"))
	row.pressed.emit()
	assert_eq(int(game.unloaded.get("scrap", 0)), 2)
	assert_eq(int(p.items.get("wood", 0)), 1)
	game.hud._inv_expand("bag", "wood")
	var move := game.hud.modal.find_child("Move", true, false) as Button
	assert_null(move.get_node_or_null("Hold"))
	move.pressed.emit()
	assert_eq(int(game.unloaded.get("wood", 0)), 1)
	game.hud._close_modal()


func _input_viewport() -> SubViewport:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280, 720)
	viewport.gui_disable_input = false
	add_child_autofree(viewport)
	return viewport


func _mouse(viewport: SubViewport, at: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	event.position = at
	event.global_position = at
	event.pressed = pressed
	viewport.push_input(event, true)


func _motion(viewport: SubViewport, at: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.button_mask = MOUSE_BUTTON_MASK_LEFT
	event.position = at
	event.global_position = at
	viewport.push_input(event, true)


## 결정 558: real GUI dispatch in the game's own viewport, not the runner window.
func test_by_gui_a_held_bag_row_opens_without_moving() -> void:
	var viewport := _input_viewport()
	var game = _game(viewport)
	game.player.items = {"scrap": 1}
	var id: String = _box(game, [])
	game.hud.loot(id)
	await _layout()
	var at: Vector2 = _row(game.hud, "Bag", "scrap").get_global_rect().get_center()
	_mouse(viewport, at, true)
	await _wait(InventoryPane.LONG_S + 0.2)
	_mouse(viewport, at, false)
	assert_eq(int(game.player.items.get("scrap", 0)), 1)
	assert_does_not_have(game.data["containers"][id]["items"], "scrap")
	assert_eq(String(game.hud.inv_expand.get("id", "")), "scrap")
	assert_not_null(game.hud.modal.find_child("More", true, false))
	game.hud._close_modal()


## 결정 559: releasing the GUI hold winds it back; a full hold throws just once.
func test_by_gui_the_can_needs_a_full_hold() -> void:
	var viewport := _input_viewport()
	var game = _game(viewport)
	game.player.items = {"can_empty": 2}
	game.hud.bag_panel()
	game.hud._inv_expand("bag", "can_empty")
	await _layout()
	var key := game.hud.modal.find_child("Throw", true, false) as Button
	var hold = key.get_node("Hold")
	var at: Vector2 = key.get_global_rect().get_center()
	_mouse(viewport, at, true)
	assert_true(bool(hold.get("_down")), "the GUI press reached the hold")
	# The half hold by fixed steps, not the clock (a slow frame would fire it).
	hold.set_process(false)
	hold.advance(HoldConfirm.HOLD_S * 0.5)
	assert_almost_eq(float(hold.state["fill"]), 0.5, 0.01)
	_mouse(viewport, at, false)
	hold.set_process(false)
	hold.advance(HoldConfirm.BACK_S + 0.01)
	assert_eq(int(game.player.items.get("can_empty", 0)), 2)
	assert_eq(float(hold.state["fill"]), 0.0)
	_mouse(viewport, at, true)
	await _wait(HoldConfirm.HOLD_S + HoldConfirm.FLASH_S + 0.25)
	_mouse(viewport, at, false)
	assert_eq(int(game.player.items.get("can_empty", 0)), 1)
	if game.hud.modal_open:
		game.hud._close_modal()


## 결정 559 by the GUI: dragged past the key's edge the hold lets go for good —
## back on the key without lifting fills nothing (as a second finger's does).
func test_by_gui_a_hold_slipped_off_and_back_stays_let_go() -> void:
	var viewport := _input_viewport()
	var game = _game(viewport)
	game.player.items = {"can_empty": 2}
	game.hud.bag_panel()
	game.hud._inv_expand("bag", "can_empty")
	await _layout()
	var key := game.hud.modal.find_child("Throw", true, false) as Button
	var hold = key.get_node("Hold")
	var at: Vector2 = key.get_global_rect().get_center()
	_mouse(viewport, at, true)
	assert_true(bool(hold.get("_down")))
	hold.set_process(false)
	hold.advance(HoldConfirm.HOLD_S * 0.5)
	# Off the key's top or bottom, whichever stays on the screen.
	_motion(viewport, at + (Vector2(0, -200) if at.y > 300.0 else Vector2(0, 200)))
	assert_false(bool(hold.get("_down")), "past the slip the press is let go")
	_motion(viewport, at)
	hold.set_process(false)
	hold.advance(HoldConfirm.HOLD_S + 0.01)
	assert_eq(float(hold.state["fill"]), 0.0, "back on the key it fills nothing")
	_mouse(viewport, at, false)
	assert_eq(int(game.player.items.get("can_empty", 0)), 2, "nothing is thrown")
	# A new press is a new hold: it fills again and a full one throws just one.
	_mouse(viewport, at, true)
	assert_true(bool(hold.get("_down")))
	hold.set_process(false)
	hold.advance(HoldConfirm.HOLD_S * 0.5)
	assert_almost_eq(float(hold.state["fill"]), 0.5, 0.01, "a new press fills again")
	hold.advance(HoldConfirm.HOLD_S * 0.5 + 0.01)
	# Full: the buzz and the flash at once, the throw as the flash ends (결정 561 ④).
	assert_gt(float(hold.get("flash")), 0.0, "full, the face flashes")
	assert_eq(int(game.player.items.get("can_empty", 0)), 2, "the throw waits for the flash")
	hold.advance(HoldConfirm.FLASH_S + 0.01)
	assert_eq(int(game.player.items.get("can_empty", 0)), 1, "held full, one can is thrown")
	_mouse(viewport, at, false)
	if game.hud.modal_open:
		game.hud._close_modal()


## 결정 561 ④: the work waits for the flash, and a pane laid again in that 0.16 s
## (a thing coming out of the box lays it) frees the hold; the throw it buzzed for
## still happens, once.
func test_a_hold_gone_mid_flash_still_does_its_work_once() -> void:
	var game = _game()
	await _layout()
	game.player.items = {"can_empty": 2}
	game.hud.bag_panel()
	game.hud._inv_expand("bag", "can_empty")
	await _layout()
	var key := game.hud.modal.find_child("Throw", true, false) as Button
	var hold = key.get_node("Hold")
	key.button_down.emit()
	hold.set_process(false)
	hold.advance(HoldConfirm.HOLD_S + 0.01)
	assert_gt(float(hold.get("flash")), 0.0, "full, it flashes")
	assert_eq(int(game.player.items.get("can_empty", 0)), 2, "not thrown yet")
	game.hud.bag_panel()
	for _i in range(4):
		await get_tree().process_frame
	assert_false(is_instance_valid(hold), "the pane laid again freed the hold")
	assert_eq(int(game.player.items.get("can_empty", 0)), 1, "the throw it buzzed for is not lost")
	for _i in range(3):
		await get_tree().process_frame
	assert_eq(int(game.player.items.get("can_empty", 0)), 1, "and it is done once")
	if game.hud.modal_open:
		game.hud._close_modal()


func test_real_place_and_row_paths_keep_bag_and_rail_scrolls() -> void:
	var game = _game(_input_viewport())
	var hud = game.hud
	var id: String = _box(game, LONG_BOX)
	var box: Dictionary = game.data["containers"][id]
	box["furniture"] = "crate_stack"
	for i: int in range(12):
		game.data["containers"]["scroll_box_%d" % i] = box.duplicate(true)
	game.player.items.clear()
	for item: String in ["scrap", "wood", "cloth", "bandage", "plank", "flare", "document", "medkit", "bottle_spirit", "tweezers", "can_empty", "food_pack"]:
		game.player.add_item(item, 2)
	hud.loot(id)
	await _layout()
	var bag := hud.modal.find_child("BagScroll", true, false) as ScrollContainer
	var rail := hud.modal.find_child("PlaceScroll", true, false) as ScrollContainer
	var near := hud.modal.find_child("NearScroll", true, false) as ScrollContainer
	bag.scroll_vertical = 40
	rail.scroll_vertical = 80
	near.scroll_vertical = 60
	var bag_y: int = bag.scroll_vertical
	var rail_y: int = rail.scroll_vertical
	assert_gt(bag_y, 0)
	assert_gt(rail_y, 0)
	assert_gt(near.scroll_vertical, 0)
	# Away and straight back before a frame has put the scrolls back: the place
	# comes back at its top as it would a frame later, not where it was left.
	_tab(hud, "box", "scroll_box_0").pressed.emit()
	_tab(hud, "box", id).pressed.emit()
	await _layout()
	assert_eq(int(hud.modal.find_child("NearScroll", true, false).scroll_vertical), 0, "back within a frame, the place starts at the top")
	assert_eq(int(hud.modal.find_child("BagScroll", true, false).scroll_vertical), bag_y)
	assert_eq(int(hud.modal.find_child("PlaceScroll", true, false).scroll_vertical), rail_y)
	near = hud.modal.find_child("NearScroll", true, false) as ScrollContainer
	near.scroll_vertical = 60
	assert_gt(near.scroll_vertical, 0)
	_tab(hud, "box", "scroll_box_0").pressed.emit()
	await _layout()
	assert_eq(int(hud.modal.find_child("BagScroll", true, false).scroll_vertical), bag_y)
	assert_eq(int(hud.modal.find_child("PlaceScroll", true, false).scroll_vertical), rail_y)
	assert_eq(int(hud.modal.find_child("NearScroll", true, false).scroll_vertical), 0, "a new place starts at the top")
	_row(hud, "Bag", "scrap").pressed.emit()
	await _layout()
	assert_eq(int(game.player.items.get("scrap", 0)), 1, "the real row callback moved one")
	assert_eq(int(hud.modal.find_child("BagScroll", true, false).scroll_vertical), bag_y)
	assert_eq(int(hud.modal.find_child("PlaceScroll", true, false).scroll_vertical), rail_y)
	# Taking and unfolding pass through open() too, retaining the hidden bag scroll.
	_row(hud, "Near", "wood").pressed.emit()
	await _layout()
	assert_not_null(hud.modal.find_child("BagStrip", true, false))
	(hud.modal.find_child("BagStrip", true, false) as Button).pressed.emit()
	await _layout()
	assert_eq(int(hud.modal.find_child("BagScroll", true, false).scroll_vertical), bag_y)
	game.player.action_t = 0.001
	game._update_person(game.player, 0.1)
	await _layout()
	assert_eq(game.player.action, "", "took() also lays through open()")
	assert_eq(int(hud.modal.find_child("BagScroll", true, false).scroll_vertical), bag_y)
	assert_eq(int(hud.modal.find_child("PlaceScroll", true, false).scroll_vertical), rail_y)
	hud._close_modal()


func test_a_long_journal_fits_above_the_foot_at_720_high() -> void:
	var viewport := _input_viewport()
	var game = _game(viewport)
	# Goals use the same mission source as goal_text() and the ordinary journal.
	game.mission_play.mission.kind = "survey"
	game.mission_play.mission.goals.clear()
	for i: int in range(36):
		game.mission_play.mission.goals.append({"id": "long_%d" % i, "name": "먼 역의 설비와 남겨진 선로 기록을 하나씩 살피기 %d" % i, "parts": ["seen"], "got": [], "amount": 0.0, "have": 0.0, "t": -1.0, "extra": false})
	game.hud.loot(_box(game, LONG_BOX))
	await _layout()
	var pane: Control = game.hud.modal.find_child("Pane", true, false)
	var journal := pane.find_child("JournalScroll", true, false) as ScrollContainer
	assert_not_null(journal)
	if journal != null:
		assert_gt((journal.get_child(0) as Control).size.y, journal.size.y)
		assert_lte(pane.get_global_rect().end.y, float(viewport.size.y) - UiFonts.px(InventoryPane.FOOT_GAP) + 1.0)
		journal.scroll_vertical = 100000
		assert_gt(journal.scroll_vertical, 0, "the rest of the journal remains reachable")
		# Laid again over itself (a row taken, a row opened): the journal stays
		# where it was read to.
		var read_to: int = journal.scroll_vertical
		InventoryPane.open(game.hud, game.hud.inv_near)
		await _layout()
		var again := game.hud.modal.find_child("JournalScroll", true, false) as ScrollContainer
		assert_not_null(again)
		if again != null:
			assert_eq(again.scroll_vertical, read_to, "laid again, the journal keeps its place")
	game.hud._close_modal()


## 결정 550·561 ①: the baked 3D pictures are painted art — drawn smooth from
## their mipmaps, filling the row's picture square; a thing that shares a model
## shows the same picture.
func test_baked_pictures_are_smooth_and_fill_the_art_square() -> void:
	var game = _game()
	var id: String = _box(game, ["can_beans", "rusk", "can_opener"])
	game.hud.loot(id)
	await _layout()
	var beans := _row(game.hud, "Near", "can_beans").find_child("ItemIcon", true, false) as TextureRect
	assert_not_null(beans.texture)
	assert_eq(beans.texture, InventoryPane.art_texture("can_beans"))
	assert_true(InventoryPane.is_painted(beans.texture), "a 256 px bake")
	assert_true(beans.texture.get_image().has_mipmaps(), "imported with mipmaps")
	assert_eq(beans.texture_filter, CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS)
	assert_almost_eq(beans.size.x, UiFonts.px(InventoryPane.ART), 1.0)
	assert_almost_eq(beans.size.y, UiFonts.px(InventoryPane.ART), 1.0)
	var rusk := _row(game.hud, "Near", "rusk").find_child("ItemIcon", true, false) as TextureRect
	assert_eq(rusk.texture, InventoryPane.art_texture("hardtack"), "rusk shares the hardtack's picture")
	assert_null(InventoryPane.art_texture("can_opener"))
	game.hud._close_modal()


## Every baked picture is a square painted one with mipmaps (결정 561 ①).
func test_every_baked_picture_is_square_painted_and_mipmapped() -> void:
	var dir := DirAccess.open("res://assets/icons/items")
	assert_not_null(dir)
	if dir == null:
		return
	var seen: int = 0
	for file: String in dir.get_files():
		if not file.ends_with(".png"):
			continue
		var texture := load("res://assets/icons/items/" + file) as Texture2D
		assert_not_null(texture, file)
		if texture == null:
			continue
		assert_eq(texture.get_width(), texture.get_height(), file)
		assert_true(InventoryPane.is_painted(texture), file)
		assert_true(texture.get_image().has_mipmaps(), file + " has mipmaps")
		seen += 1
	assert_gte(seen, 22)
	for alias: String in InventoryPane.ART_ALIAS:
		assert_not_null(InventoryPane.art_texture(alias), alias)


## A thing with no picture of its own takes the one baked for its line icon's
## name; its own picture, then its alias, come first.
func test_a_thing_without_its_own_picture_takes_its_line_icons_bake() -> void:
	var beans: Texture2D = InventoryPane.art_texture("can_beans")
	assert_not_null(beans)
	assert_eq(InventoryPane.art_texture("no_such_thing", "can_beans"), beans, "the line icon's bake")
	assert_eq(InventoryPane.art_texture("can_beans", "medkit"), beans, "its own picture first")
	assert_eq(InventoryPane.art_texture("rusk", "medkit"), InventoryPane.art_texture("hardtack"), "then its alias")
	assert_null(InventoryPane.art_texture("no_such_thing", "no_such_icon"))
	assert_null(InventoryPane.art_texture("no_such_thing"))


## 결정 561 ③: the bag's mark 1.3 times — in its column head, on the folded
## strip, and on the field's bag key.
func test_the_bag_mark_is_one_point_three_times() -> void:
	var game = _game()
	var hud = game.hud
	game.player.items = {"scrap": 1}
	var id: String = _box(game, ["wood"])
	hud.loot(id)
	await _layout()
	var head_mark := hud.modal.find_child("BagHead", true, false).find_children("*", "TextureRect", true, false)[0] as TextureRect
	assert_almost_eq(head_mark.custom_minimum_size.x, float(GlassPane.px(InventoryPane.BAG_ICON)), 0.5)
	assert_almost_eq(InventoryPane.BAG_ICON, InventoryPane.HEAD_ICON * 1.3, 0.01)
	_row(hud, "Near", "wood").pressed.emit()
	await _layout()
	var strip: Node = hud.modal.find_child("BagStrip", true, false)
	assert_not_null(strip)
	if strip != null:
		var strip_mark := strip.find_children("*", "TextureRect", true, false)[0] as TextureRect
		assert_almost_eq(strip_mark.custom_minimum_size.x, float(GlassPane.px(InventoryPane.BAG_ICON)), 0.5)
	assert_eq(hud.bag_button.get_theme_constant("icon_max_width"), hud.BAG_KEY_ICON_PX)
	assert_eq(hud.BAG_KEY_ICON_PX, 39)
	hud._close_modal()


## 결정 561 ④: a pressed key's marks sink with its face and a one-press key
## buzzes very short on the way down; a hold key keeps its buzz for the full hold.
func test_a_pressed_key_sinks_and_a_one_press_key_buzzes() -> void:
	assert_eq(InventoryPane.PRESS_SINK, 1.5, "결정 561 ④: pressed, 1.5 css")
	var game = _game()
	var hud = game.hud
	game.player.items = {"can_empty": 1, "scrap": 1}
	# Something on the ground, so the rail has a place key.
	game.ground_items.append({"pos": game.player.position, "id": "cloth", "n": 1})
	hud.bag_panel()
	hud._inv_expand("bag", "can_empty")
	await _layout()
	var row: Button = _row(hud, "Bag", "scrap")
	_sinks_with_face(row, [row.get_node("Line")], "a row")
	assert_eq(int(row.get_meta("tap_buzz", 0)), 1, "a one-press row buzzes once")
	assert_eq((row.get_theme_stylebox("pressed") as StyleBoxFlat).border_color, GlassPane.INK, "the pressed rim lights")
	var throw := hud.modal.find_child("Throw", true, false) as Button
	# Its mark, its word and its hold's line (and flash) all keep to the face.
	var parts: Array = throw.get_children().filter(func(c: Node) -> bool: return c is Control)
	assert_true(parts.has(throw.get_node("Hold")))
	_sinks_with_face(throw, parts, "the throw key")
	assert_eq(int(throw.get_meta("tap_buzz", 0)), 0, "a hold key does not buzz on the way down")
	var place: Button = null
	for node: Node in hud.modal.find_children("*", "Button", true, false):
		if node.has_meta("place_kind"):
			place = node as Button
			break
	assert_not_null(place, "a place key on the rail")
	if place != null:
		_sinks_with_face(place, place.get_children().filter(func(c: Node) -> bool: return c is Control), "a place key")
		assert_eq(int(place.get_meta("tap_buzz", 0)), 1, "a place key buzzes once")
		assert_eq((place.get_theme_stylebox("pressed") as StyleBoxFlat).border_color, GlassPane.INK, "its pressed rim lights")
	hud._close_modal()


## 결정 561 ④: the pressed face goes down PRESS_SINK (its box's margins) and each
## part laid on it as far, and all come back up on the way up.
func _sinks_with_face(b: Button, parts: Array, what: String) -> void:
	var sink: float = UiFonts.px(InventoryPane.PRESS_SINK)
	for state: String in ["pressed", "hover_pressed"]:
		var box := b.get_theme_stylebox(state) as StyleBoxFlat
		assert_almost_eq(box.expand_margin_bottom, sink, 0.01, "%s: the %s face goes down" % [what, state])
		assert_almost_eq(box.expand_margin_top, -sink, 0.01, "%s: its top with it" % what)
	var y0: Array = []
	for c: Control in parts:
		y0.append(c.position.y)
	b.button_down.emit()
	for k: int in parts.size():
		assert_almost_eq((parts[k] as Control).position.y - float(y0[k]), sink, 0.01, "%s: %s sinks with the face" % [what, (parts[k] as Node).name])
	b.button_up.emit()
	for k: int in parts.size():
		assert_almost_eq((parts[k] as Control).position.y, float(y0[k]), 0.01, "%s: %s comes back up" % [what, (parts[k] as Node).name])


## 결정 561 ④: a bag row dimmed (here it cannot go aboard) still opens on a long
## press, so its face sinks with its line.
func test_a_dim_bag_row_sinks_whole() -> void:
	var game = _game()
	var p = game.player
	p.items = {"can_opener": 1, "food_pack": 1}
	var rect: Rect2i = game.data["unload"]
	p.position = game.lift(rect.position + Vector2i(3, 1), 0)
	game.hud.bag_panel()
	game.hud._inv_place({"kind": "train", "id": "", "name": "열차 짐칸"})
	await _layout()
	var row: Button = _row(game.hud, "Bag", "can_opener")
	assert_false(row.disabled, "a dim bag row still takes a long press")
	assert_eq(row.get_theme_stylebox("normal"), row.get_theme_stylebox("disabled"), "dim at rest")
	_sinks_with_face(row, [row.get_node("Line")], "a dim row")
	game.hud._close_modal()


## 결정 561 ④ with the load: shut in the confirm's flash, the pane stays shut and
## what was held for still goes aboard, once.
func test_a_load_held_full_then_shut_in_its_flash_loads_and_stays_shut() -> void:
	var game = _game()
	var p = game.player
	p.items = {"food_pack": 1}
	var rect: Rect2i = game.data["unload"]
	p.position = game.lift(rect.position + Vector2i(3, 1), 0)
	game.hud.bag_panel()
	game.hud._inv_place({"kind": "train", "id": "", "name": "열차 짐칸"})
	await _layout()
	var key := game.hud.modal.find_child("MainKey", true, false) as Button
	assert_not_null(key, "the load key by the train")
	# Its mark, its word and its hold keep to the pressed face too.
	_sinks_with_face(key, key.get_children().filter(func(c: Node) -> bool: return c is Control), "the load key")
	var hold = key.get_node("Hold")
	var held_work: Callable = hold.work
	var calls: Array = [0]
	hold.work = func() -> void:
		calls[0] += 1
		held_work.call()
	key.button_down.emit()
	hold.set_process(false)
	hold.advance(HoldConfirm.HOLD_S + 0.01)
	assert_gt(float(hold.get("flash")), 0.0, "full, it flashes")
	assert_eq(int(game.unloaded.get("food_pack", 0)), 0, "not aboard yet")
	key.button_up.emit()
	game.hud._close_modal()
	await _layout()
	assert_eq(int(game.unloaded.get("food_pack", 0)), 1, "what was held for goes aboard")
	assert_false(game.hud.modal_open, "the shut pane stays shut")
	await _layout()
	assert_eq(int(calls[0]), 1, "the load's work ran once")


## 결정 561 ④: a throw held full, its pane shut and another opened within the
## flash: the can is thrown, and the pane opened since is left alone.
func test_a_throw_held_full_then_another_pane_opened_leaves_that_pane() -> void:
	var game = _game()
	var hud = game.hud
	await _layout()
	game.player.items = {"can_empty": 2}
	hud.bag_panel()
	hud._inv_expand("bag", "can_empty")
	await _layout()
	var key := hud.modal.find_child("Throw", true, false) as Button
	var hold = key.get_node("Hold")
	key.button_down.emit()
	hold.set_process(false)
	hold.advance(HoldConfirm.HOLD_S + 0.01)
	key.button_up.emit()
	hold.set_process(false)
	assert_gt(float(hold.get("flash")), 0.0, "full, it flashes")
	var held_era: int = hud.pane_era
	hud._close_modal()
	hud.bag_panel()
	var era: int = hud.pane_era
	assert_eq(era, held_era + 1, "shut and opened again: another pane")
	if is_instance_valid(hold):
		hold.advance(HoldConfirm.FLASH_S + 0.01)
	for _i in range(4):
		await get_tree().process_frame
	assert_eq(int(game.player.items.get("can_empty", 0)), 1, "the can held for is thrown")
	assert_true(hud.modal_open, "the pane opened since stays up")
	assert_eq(hud.pane_era, era, "and is not shut and opened again")
	hud._close_modal()


## 결정 561 ④ by the GUI: a real press keeps the pressed face (its draw mode) and
## the row's line sunk with it across frames; let go off the row, both come back.
func test_by_gui_a_held_row_stays_sunk_with_its_face() -> void:
	var viewport := _input_viewport()
	var game = _game(viewport)
	game.player.items = {"scrap": 1}
	game.hud.bag_panel()
	await _layout()
	var row: Button = _row(game.hud, "Bag", "scrap")
	var line := row.get_node("Line") as Control
	var y0: float = line.position.y
	var at: Vector2 = row.get_global_rect().get_center()
	_mouse(viewport, at, true)
	for _i in range(3):
		await get_tree().process_frame
	assert_eq(row.get_draw_mode(), BaseButton.DRAW_PRESSED, "the face is the pressed one")
	assert_almost_eq(line.position.y - y0, UiFonts.px(InventoryPane.PRESS_SINK), 0.01, "its line stays sunk with it")
	# Let go off the row, so it moves nothing and the pane is not laid again.
	var away: Vector2 = at + (Vector2(0, -260) if at.y > 360.0 else Vector2(0, 260))
	_motion(viewport, away)
	_mouse(viewport, away, false)
	for _i in range(2):
		await get_tree().process_frame
	assert_true(is_instance_valid(line), "the row is still the one pressed")
	if is_instance_valid(line):
		assert_almost_eq(line.position.y, y0, 0.01, "let go, its line comes back up")
	if game.hud.modal_open:
		game.hud._close_modal()


## 결정 561 ②: the weight mark is a weight with a ring, not a box with a handle —
## in the bag pane only; the train's home bar keeps its 정치 mark.
func test_the_weight_mark_is_a_ringed_weight() -> void:
	assert_true(String(HudIcons.PATHS["weight"]).contains("<circle"), "a ring on top")
	assert_false(String(HudIcons.PATHS["weight"]).contains("M8.500 11V3.500"), "no handle")
	assert_true(String(HudIcons.PATHS["scale"]).contains("M8.500 11V3.500"), "정치 keeps its own mark")
	# The ring is drawn: at twice the size, the column through the middle has ink
	# above the weight's top (y 10) and none in the ring's hole.
	var image: Image = HudIcons.texture("weight", 24, Color.WHITE).get_image()
	var ring: float = 0.0
	for y: int in range(4, 10):
		ring = maxf(ring, image.get_pixel(24, y).a)
	assert_gt(ring, 0.5, "the ring's top is drawn")
	assert_lt(image.get_pixel(24, 12).a, 0.5, "the ring is open in the middle")
	var pane_src: String = (load("res://game/ui/inventory_pane.gd") as GDScript).source_code
	assert_false(pane_src.contains("\"scale\""), "the bag pane asks for the weight mark only")
