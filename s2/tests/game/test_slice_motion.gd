extends "res://addons/gut/test.gd"
## Pinned panes, retiring cards and papers keep their logical slots separate.

const PaneMotion = preload("res://game/ui/pane_motion.gd")
const PaperMotion = preload("res://game/ui/paper_motion.gd")
const CarPane = preload("res://game/ui/car_pane.gd")
const SliceFlow = preload("res://game/slice_flow.gd")
const TrainGauges = preload("res://game/ui/train_gauges.gd")


func _pane() -> CarPane:
	var host := Control.new()
	host.size = Vector2(960.0, 640.0)
	add_child_autofree(host)
	var c: CarPane = CarPane.new()
	c.name = "CarPane"
	host.add_child(c)
	c.pin(TrainGauges.BAND_H)
	return c


func _flow(seen: bool = false) -> SliceFlow:
	var f: SliceFlow = SliceFlow.new()
	f.opts = {"skip_field": true, "seed": 3, "cinema": false, "cinema_seen": seen}
	add_child_autofree(f)
	return f


func _offsets(c: Control) -> Vector4:
	return Vector4(c.offset_left, c.offset_top, c.offset_right, c.offset_bottom)


func _finish_pane(c: Control) -> void:
	var tw: Tween = c.get_meta(PaneMotion.META_TWEEN) as Tween
	if tw.is_valid():
		tw.custom_step(PaneMotion.OPEN_S + PaneMotion.CLOSE_S + 0.001)


func _assert_quiet(node: Node) -> void:
	if node is Control:
		var c: Control = node as Control
		assert_eq(c.mouse_filter, Control.MOUSE_FILTER_IGNORE, String(c.name))
		assert_eq(c.focus_mode, Control.FOCUS_NONE, String(c.name))
	for child: Node in node.get_children():
		_assert_quiet(child)


func test_motion_spans_match_the_contract() -> void:
	assert_eq(PaneMotion.OPEN_S, 0.18)
	assert_eq(PaneMotion.CLOSE_S, 0.14)
	assert_eq(PaneMotion.SHIFT_PX, 18.0)
	assert_eq(SliceFlow.COUNCIL_OPEN_S, 0.24)
	assert_eq(SliceFlow.COUNCIL_FROM_PX, 8.0)
	assert_eq(SliceFlow.CARD_FADE_S, 0.18)
	assert_eq(SliceFlow.PAPER_FOLDED_CLOSE_S, 0.12)
	assert_eq(SliceFlow.PAPER_OPEN_CLOSE_S, 0.20)
	assert_eq(SliceFlow.PAPER_DROP_PX, 24.0)


func test_open_starts_right_and_finishes_at_the_pinned_offsets() -> void:
	var c: CarPane = _pane()
	var rest: Vector4 = _offsets(c)
	var tw: Tween = PaneMotion.open(c)
	assert_eq(c.offset_left, rest.x + PaneMotion.SHIFT_PX)
	assert_eq(c.modulate.a, 0.0)
	assert_true(PaneMotion.shown(c))
	tw.custom_step(PaneMotion.OPEN_S * 0.5)
	assert_gt(c.offset_left, rest.x)
	assert_lt(c.offset_left, rest.x + PaneMotion.SHIFT_PX)
	assert_gt(c.modulate.a, 0.0)
	assert_lt(c.modulate.a, 1.0)
	tw.custom_step(PaneMotion.OPEN_S)
	assert_eq(_offsets(c), rest)
	assert_eq(c.modulate.a, 1.0)


func test_open_repin_and_parent_resize_finish_at_the_latest_offsets() -> void:
	var c: CarPane = _pane()
	var tw: Tween = PaneMotion.open(c)
	tw.custom_step(PaneMotion.OPEN_S * 0.4)
	c.pin(TrainGauges.BAND_H + 23.0)
	var rest: Vector4 = _offsets(c)
	var host: Control = c.get_parent() as Control
	host.size += Vector2(137.0, 79.0)
	tw.custom_step(PaneMotion.OPEN_S)
	assert_eq(_offsets(c), rest, "the new pin wins over the first rest")
	assert_eq(c.get_global_rect().end.x, host.get_global_rect().end.x)


func test_close_repin_finishes_hidden_at_the_latest_offsets() -> void:
	var c: CarPane = _pane()
	PaneMotion.open(c).custom_step(PaneMotion.OPEN_S + 0.001)
	var tw: Tween = PaneMotion.close(c)
	assert_false(PaneMotion.shown(c), "hidden logically at once")
	assert_true(c.visible, "still drawn while leaving")
	tw.custom_step(PaneMotion.CLOSE_S * 0.4)
	c.pin(TrainGauges.BAND_H + 31.0)
	var rest: Vector4 = _offsets(c)
	tw.custom_step(PaneMotion.CLOSE_S)
	assert_eq(_offsets(c), rest)
	assert_false(c.visible)
	assert_eq(c.modulate.a, 0.0)


func test_close_then_open_continues_from_the_current_pose_without_drift() -> void:
	var c: CarPane = _pane()
	var key := Button.new()
	c.add_child(key)
	key.mouse_filter = Control.MOUSE_FILTER_STOP
	key.focus_mode = Control.FOCUS_ALL
	var rest: Vector4 = _offsets(c)
	PaneMotion.open(c).custom_step(PaneMotion.OPEN_S + 0.001)
	for _round in 3:
		var leaving: Tween = PaneMotion.close(c)
		leaving.custom_step(PaneMotion.CLOSE_S * 0.4)
		var at: Vector4 = _offsets(c)
		var alpha: float = c.modulate.a
		var entering: Tween = PaneMotion.open(c)
		assert_false(leaving.is_valid() and leaving.is_running())
		assert_eq(_offsets(c), at, "no jump when the direction changes")
		assert_eq(c.modulate.a, alpha)
		assert_eq(key.mouse_filter, Control.MOUSE_FILTER_STOP)
		assert_eq(key.focus_mode, Control.FOCUS_ALL)
		entering.custom_step(PaneMotion.OPEN_S + 0.001)
		assert_eq(_offsets(c), rest, "repeated reversals keep the pin")


func test_retired_pane_blocks_children_renames_and_frees_after_close() -> void:
	var c: CarPane = _pane()
	var holder := Control.new()
	c.add_child(holder)
	var key := Button.new()
	holder.add_child(key)
	PaneMotion.open(c).custom_step(PaneMotion.OPEN_S + 0.001)
	var host: Node = c.get_parent()
	var tw: Tween = PaneMotion.close(c, true)
	_assert_quiet(c)
	assert_ne(String(c.name), "CarPane")
	assert_null(host.get_node_or_null("CarPane"))
	var replacement: CarPane = CarPane.new()
	replacement.name = "CarPane"
	host.add_child(replacement)
	replacement.pin(TrainGauges.BAND_H)
	PaneMotion.open(replacement)
	assert_eq(String(replacement.name), "CarPane", "the name is free immediately")
	tw.custom_step(PaneMotion.CLOSE_S * 0.99)
	assert_false(c.is_queued_for_deletion())
	tw.custom_step(PaneMotion.CLOSE_S * 0.02)
	assert_true(c.is_queued_for_deletion())
	await get_tree().process_frame
	assert_false(is_instance_valid(c))
	assert_true(is_instance_valid(replacement))


func test_select_hides_logically_before_the_reusable_pane_disappears() -> void:
	var f: SliceFlow = _flow()
	_finish_pane(f.pane)
	f._select("")
	assert_eq(f.sel, "")
	assert_false(PaneMotion.shown(f.pane))
	assert_true(f.pane.visible)
	_assert_quiet(f.pane)
	f._update_decor_lock()
	_assert_quiet(f.pane)
	_finish_pane(f.pane)
	assert_false(f.pane.visible)
	assert_true(is_instance_valid(f.pane))
	f._select(SliceFlow.FIRST_CAR)
	assert_true(PaneMotion.shown(f.pane))
	assert_eq(f.pane.modulate.a, 0.0)


func test_room_slots_clear_while_the_old_panes_leave() -> void:
	var f: SliceFlow = _flow()
	f._open_workshop()
	var workshop: Control = f.shop
	assert_eq(workshop.modulate.a, 0.0)
	_finish_pane(workshop)
	f._open_mods()
	assert_null(f.shop)
	assert_ne(String(workshop.name), "WorkshopPane")
	_assert_quiet(workshop)
	var refit: Control = f.mods
	assert_eq(refit.modulate.a, 0.0)
	f._open_research()
	assert_null(f.mods)
	var study: Control = f.research
	assert_eq(study.modulate.a, 0.0)
	f._open_cost("coal")
	assert_null(f.research)
	var expense: Control = f.cost
	assert_eq(expense.modulate.a, 0.0)
	f._put_rooms_away()
	assert_null(f.cost)
	assert_eq(f.gauges.get("focus"), [], "the stock focus clears at once")
	assert_false(PaneMotion.shown(f.pane))
	for room: Control in [workshop, refit, study, expense]:
		_assert_quiet(room)
		assert_true(room.visible)
		assert_true(room.has_meta(PaneMotion.META_RETIRING))
		_finish_pane(room)
		assert_true(room.is_queued_for_deletion())


func test_set_cover_uses_the_resting_rect_and_matches_the_pane_spans() -> void:
	var f: SliceFlow = _flow()
	_finish_pane(f.pane)
	f.train.set_view_mode("diag")
	f._select("")
	_finish_pane(f.pane)
	f._cover_tween.custom_step(PaneMotion.CLOSE_S + 0.001)
	var rest_rect: Rect2 = f.pane.get_global_rect()
	var covered: float = f.get_viewport().get_visible_rect().size.x - rest_rect.position.x
	f._select(SliceFlow.FIRST_CAR)
	assert_eq(float(f.train.get("pane_px")), 0.0, "opening starts from the old width")
	assert_gt(f.pane.get_global_rect().position.x, rest_rect.position.x)
	f._set_cover()
	assert_almost_eq(f._pane_cover(), covered, 0.001, "the moving right edge does not shrink the cover")
	f._cover_tween.custom_step(PaneMotion.OPEN_S * 0.5)
	assert_gt(float(f.train.get("pane_px")), 0.0)
	assert_lt(float(f.train.get("pane_px")), covered)
	var entering: Tween = f.pane.get_meta(PaneMotion.META_TWEEN) as Tween
	entering.custom_step(PaneMotion.OPEN_S * 0.5)
	f._set_cover()
	f._cover_tween.custom_step(PaneMotion.OPEN_S)
	assert_almost_eq(float(f.train.get("pane_px")), covered, 0.001)
	_finish_pane(f.pane)
	f._select("")
	assert_almost_eq(float(f.train.get("pane_px")), covered, 0.001, "closing starts from the current width")
	f._set_cover()
	assert_eq(f._pane_cover(), 0.0, "a retiring pane covers no logical room")
	f._cover_tween.custom_step(PaneMotion.CLOSE_S * 0.5)
	assert_gt(float(f.train.get("pane_px")), 0.0)
	assert_lt(float(f.train.get("pane_px")), covered)
	f._cover_tween.custom_step(PaneMotion.CLOSE_S)
	assert_eq(float(f.train.get("pane_px")), 0.0)


func test_cover_reversal_keeps_the_current_width_and_the_latest_pin() -> void:
	var f: SliceFlow = _flow()
	_finish_pane(f.pane)
	f.train.set_view_mode("diag")
	f._set_cover()
	if f._cover_tween != null and f._cover_tween.is_valid():
		f._cover_tween.custom_step(PaneMotion.OPEN_S + 0.001)
	f._select("")
	f._cover_tween.custom_step(PaneMotion.CLOSE_S * 0.5)
	var width: float = float(f.train.get("pane_px"))
	var leaving: Tween = f._cover_tween
	f._select(SliceFlow.FIRST_CAR)
	assert_false(leaving.is_valid() and leaving.is_running())
	assert_eq(float(f.train.get("pane_px")), width, "a reversal starts at the current width")
	f.pane.call("pin", TrainGauges.BAND_H + 13.0)
	var pinned: Vector4 = _offsets(f.pane)
	f._cover_tween.custom_step(PaneMotion.OPEN_S + 0.001)
	_finish_pane(f.pane)
	assert_eq(_offsets(f.pane), pinned)
	var rect: Rect2 = f.pane.get_global_rect()
	var covered: float = f.get_viewport().get_visible_rect().size.x - rect.position.x
	assert_almost_eq(float(f.train.get("pane_px")), covered, 0.001)


func test_sheet_card_retirement_follows_the_fold_and_keeps_a_new_card() -> void:
	var f: SliceFlow = _flow()
	f.go(f._index_of("stop_pick"))
	var old: Control = f.card
	var old_name: String = String(old.name)
	var sheet: Control = old.get("sheet") as Control
	var tw: Tween = f._retire_card(old)
	assert_null(f.card)
	_assert_quiet(old)
	assert_ne(String(old.name), old_name)
	f._show_stop_pick()
	var replacement: Control = f.card
	# The new card is made without a name of its own (auto @Control@…): it only must not be the
	# leaving one or carry its retiring mark.
	assert_ne(replacement, old)
	assert_false(replacement.has_meta(PaneMotion.META_RETIRING))
	assert_false(String(replacement.name).contains("_retiring"))
	tw.custom_step(PaperMotion.CLOSE_S * 0.5)
	assert_lt(sheet.scale.x, 1.0, "the sheet folds instead of a plain fade")
	assert_false(old.is_queued_for_deletion())
	tw.custom_step(PaperMotion.CLOSE_S * 0.49)
	assert_false(old.is_queued_for_deletion())
	tw.custom_step(PaperMotion.CLOSE_S * 0.02)
	assert_true(old.is_queued_for_deletion())
	await get_tree().process_frame
	assert_false(is_instance_valid(old))
	assert_eq(f.card, replacement)


func test_seen_sheet_card_retirement_uses_the_short_fold_span() -> void:
	var f: SliceFlow = _flow(true)
	f.go(f._index_of("stop_pick"))
	var old: Control = f.card
	var tw: Tween = f._retire_card(old)
	var seconds: float = PaperMotion.CLOSE_S * PaperMotion.SHORT
	tw.custom_step(seconds * 0.99)
	assert_false(old.is_queued_for_deletion())
	tw.custom_step(seconds * 0.02)
	assert_true(old.is_queued_for_deletion())


func test_receipt_and_arrival_open_their_sheets_with_paper_motion() -> void:
	var f: SliceFlow = _flow()
	for id: String in ["receipt", "arrive"]:
		f.go(f._index_of(id))
		var sheet: Control = f.card.get("sheet") as Control
		assert_not_null(sheet)
		assert_true(sheet.has_meta(PaperMotion.META_TWEEN), id)
		assert_eq(sheet.modulate.a, 0.0)
		assert_eq(sheet.scale.x, PaperMotion.FOLDED)
		var tw: Tween = sheet.get_meta(PaperMotion.META_TWEEN) as Tween
		tw.custom_step(PaperMotion.OPEN_S + 0.001)
		assert_eq(sheet.scale, Vector2.ONE)
		assert_eq(sheet.modulate.a, 1.0)


func test_council_rises_into_place_and_retires_with_a_plain_fade() -> void:
	var f: SliceFlow = _flow()
	f.go(f._index_of("council"))
	var c: Control = f.card
	var rest: Vector2 = c.position - Vector2(0.0, SliceFlow.COUNCIL_FROM_PX)
	assert_eq(c.modulate.a, 0.0)
	var entering: Tween = c.get_meta(SliceFlow.META_CARD_TWEEN) as Tween
	entering.custom_step(SliceFlow.COUNCIL_OPEN_S * 0.5)
	assert_gt(c.position.y, rest.y)
	assert_lt(c.position.y, rest.y + SliceFlow.COUNCIL_FROM_PX)
	assert_gt(c.modulate.a, 0.0)
	assert_lt(c.modulate.a, 1.0)
	entering.custom_step(SliceFlow.COUNCIL_OPEN_S)
	assert_eq(c.position, rest)
	assert_eq(c.modulate.a, 1.0)
	var leaving: Tween = f._retire_card(c)
	assert_null(f.card)
	_assert_quiet(c)
	assert_ne(String(c.name), "CouncilCard")
	leaving.custom_step(SliceFlow.CARD_FADE_S * 0.99)
	assert_false(c.is_queued_for_deletion())
	leaving.custom_step(SliceFlow.CARD_FADE_S * 0.02)
	assert_true(c.is_queued_for_deletion())


func test_council_retirement_cancels_an_unfinished_entry() -> void:
	var f: SliceFlow = _flow()
	f.go(f._index_of("council"))
	var c: Control = f.card
	var entering: Tween = c.get_meta(SliceFlow.META_CARD_TWEEN) as Tween
	entering.custom_step(SliceFlow.COUNCIL_OPEN_S * 0.4)
	var alpha: float = c.modulate.a
	var leaving: Tween = f._retire_card(c)
	assert_false(entering.is_valid() and entering.is_running())
	assert_eq(c.modulate.a, alpha, "the fade continues from the current alpha")
	leaving.custom_step(SliceFlow.CARD_FADE_S + 0.001)
	assert_true(c.is_queued_for_deletion())


func _check_paper_retirement(folded: bool) -> void:
	var f: SliceFlow = _flow()
	var old: Control = f.paper
	if folded:
		old.call("set_folded", true)
	var at: Vector2 = old.position
	var seconds: float = SliceFlow.PAPER_FOLDED_CLOSE_S if folded else SliceFlow.PAPER_OPEN_CLOSE_S
	var tw: Tween = f._drop_paper()
	assert_null(f.paper)
	assert_false(bool(f.pane.get("choosing_paper")), "the decor lock releases at once")
	_assert_quiet(old)
	assert_ne(String(old.name), "Paper")
	f._show_paper()
	var replacement: Control = f.paper
	assert_eq(String(replacement.name), "Paper")
	tw.custom_step(seconds * 0.5)
	assert_gt(old.position.y, at.y)
	assert_lt(old.position.y, at.y + SliceFlow.PAPER_DROP_PX)
	assert_gt(old.modulate.a, 0.0)
	assert_lt(old.modulate.a, 1.0)
	assert_false(old.is_queued_for_deletion())
	tw.custom_step(seconds * 0.49)
	assert_false(old.is_queued_for_deletion())
	tw.custom_step(seconds * 0.02)
	assert_true(old.is_queued_for_deletion())
	assert_eq(old.position, at + Vector2(0.0, SliceFlow.PAPER_DROP_PX))
	await get_tree().process_frame
	assert_false(is_instance_valid(old))
	assert_eq(f.paper, replacement)


func test_open_turn_paper_retires_in_the_open_span() -> void:
	await _check_paper_retirement(false)


func test_folded_turn_paper_retires_in_the_folded_span() -> void:
	await _check_paper_retirement(true)


func test_freeing_the_train_stops_its_pending_cover_motion() -> void:
	var f: SliceFlow = _flow()
	f.train.set_view_mode("diag")
	f._select("")
	var cover: Tween = f._cover_tween
	assert_true(cover.is_valid())
	var old_train: Node3D = f.train
	f.train = null
	old_train.queue_free()
	await get_tree().process_frame
	assert_false(is_instance_valid(old_train))
	# GUT also rejects any freed-capture errors on the tween's next frame.
	await get_tree().process_frame
	assert_true(is_instance_valid(f))
	assert_eq(f._cover_tween, cover)
	assert_false(f._cover_tween.is_valid())


func test_retiring_turn_paper_stops_layout_and_ignores_old_choices() -> void:
	var f: SliceFlow = _flow()
	var old: Control = f.paper
	var sheet: Control = old.get("sheet") as Control
	var children: Array[Node] = old.get_children()
	old.set_process(true)
	var leaving: Tween = f._drop_paper()
	assert_false(old.is_processing(), "layout retries cannot create new active buttons")
	assert_false(old.is_connected("chose", f._paper_chosen))
	assert_false(old.is_connected("fold_changed", f._paper_folded))
	f._show_paper()
	var replacement: Control = f.paper
	var state: Dictionary = f.train_g.duplicate(true)
	old.emit_signal("chose", state.duplicate(true))
	assert_eq(f.paper, replacement, "a late choice cannot replace the current paper")
	assert_eq(f.train_g, state)
	leaving.custom_step(SliceFlow.PAPER_OPEN_CLOSE_S * 0.5)
	assert_eq(old.get("sheet"), sheet)
	assert_eq(old.get_children(), children)
	_assert_quiet(old)
	leaving.custom_step(SliceFlow.PAPER_OPEN_CLOSE_S)
	assert_true(old.is_queued_for_deletion())


func test_arrival_slip_follows_the_sheet_alpha_on_entry_and_retirement() -> void:
	var f: SliceFlow = _flow()
	f.go(f._index_of("arrive"))
	var c: Control = f.card
	var sheet: Control = c.get("sheet") as Control
	var slip: Control = c.get("slip") as Control
	assert_not_null(slip)
	var at: Vector2 = slip.position
	var turn: float = slip.rotation
	var size: Vector2 = slip.size
	assert_eq(slip.modulate.a, 0.0, "the slip cannot appear ahead of its sheet")
	var entering: Tween = sheet.get_meta(PaperMotion.META_TWEEN) as Tween
	entering.custom_step(PaperMotion.OPEN_S * 0.06)
	assert_gt(sheet.modulate.a, 0.0)
	assert_lt(sheet.modulate.a, 1.0)
	assert_eq(slip.modulate.a, sheet.modulate.a)
	entering.custom_step(PaperMotion.OPEN_S)
	assert_eq(slip.modulate.a, 1.0)
	var leaving: Tween = f._retire_card(c)
	leaving.custom_step(PaperMotion.CLOSE_S * 0.9)
	assert_gt(sheet.modulate.a, 0.0)
	assert_lt(sheet.modulate.a, 1.0)
	assert_eq(slip.modulate.a, sheet.modulate.a)
	assert_eq(slip.position, at)
	assert_eq(slip.rotation, turn)
	assert_eq(slip.size, size)
	leaving.custom_step(PaperMotion.CLOSE_S)
	assert_almost_eq(slip.modulate.a, 0.0, 0.0001, "no slip remains visible after its sheet leaves")
	assert_true(c.is_queued_for_deletion())
	await get_tree().process_frame
	assert_false(is_instance_valid(c))
	assert_false(is_instance_valid(slip))


func test_freeing_the_flow_stops_its_pending_motions() -> void:
	var f: SliceFlow = _flow()
	f.train.set_view_mode("diag")
	f._select("")
	var cover: Tween = f._cover_tween
	var pane_out: Tween = f.pane.get_meta(PaneMotion.META_TWEEN) as Tween
	f._open_workshop()
	var room_in: Tween = f.shop.get_meta(PaneMotion.META_TWEEN) as Tween
	var paper_out: Tween = f._drop_paper()
	var card_out: Tween = f._retire_card(f.card)
	f.queue_free()
	await get_tree().process_frame
	assert_false(is_instance_valid(f))
	# A tween sees its bound node gone on its next step, one frame after the free.
	await get_tree().process_frame
	for tw: Tween in [cover, pane_out, room_in, paper_out, card_out]:
		assert_false(tw.is_valid(), "a bound tween ends with its flow or control")
