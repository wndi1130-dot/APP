extends GutTest
## The new-run introduction is the top sheet over the train, never a step or
## a saved flag. Its key removes only the sheet, and its draft fits one screen.

const WorldIntro = preload("res://game/ui/world_intro.gd")
const PaperSheet = preload("res://game/ui/paper_sheet.gd")
const SliceFlow = preload("res://game/slice_flow.gd")
const Boot = preload("res://game/boot.gd")
const UiFonts = preload("res://game/ui/ui_fonts.gd")


func _flow(extra: Dictionary = {}) -> SliceFlow:
	var flow: SliceFlow = SliceFlow.new()
	var options: Dictionary = {"skip_field": true, "seed": 3, "cinema": false, "save": false, "still": true}
	options.merge(extra, true)
	flow.opts = options
	add_child_autofree(flow)
	return flow


func test_a_new_run_opens_the_intro_last_over_the_first_train_screen() -> void:
	var flow: SliceFlow = _flow({"intro": true})
	var top: Node = flow.layer.get_child(flow.layer.get_child_count() - 1)
	assert_eq(String(top.name), "WorldIntro")
	assert_true(top is WorldIntro, "the last child is the introduction")
	assert_eq(flow.current(), "train", "the train has already opened underneath")
	var intro: WorldIntro = top as WorldIntro
	if intro != null:
		assert_true(intro.still, "the flow passes its still option to the sheet")
		assert_eq(intro.mouse_filter, Control.MOUSE_FILTER_STOP, "the sheet blocks the train underneath")


func test_no_intro_option_or_false_leaves_the_train_without_a_sheet() -> void:
	for extra: Dictionary in [{}, {"intro": false}]:
		var flow: SliceFlow = _flow(extra)
		assert_null(flow.layer.get_node_or_null("WorldIntro"))
		assert_eq(flow.current(), "train")


func test_the_departure_key_removes_only_the_intro_and_emits_its_signal() -> void:
	var flow: SliceFlow = _flow({"intro": true})
	var intro: WorldIntro = flow.layer.get_node_or_null("WorldIntro") as WorldIntro
	assert_not_null(intro)
	if intro == null:
		return
	watch_signals(intro)
	assert_eq(intro.go_key.text, WorldIntro.GO_WORD)
	intro.go_key.pressed.emit()
	assert_signal_emitted(intro, "went_on")
	assert_true(intro.is_queued_for_deletion())
	assert_eq(flow.current(), "train", "departure here puts only the sheet away")
	await wait_frames(2)
	assert_null(flow.layer.get_node_or_null("WorldIntro"))
	assert_eq(flow.current(), "train")


func test_boot_requests_the_intro_only_for_an_empty_resume() -> void:
	var boot: Boot = Boot.new()
	# Slots of its own, as in test_slice_flow; the factory nodes stay out of
	# the tree so even a minimal resume cannot start play or write a save.
	boot.slice_save_path = "user://test_world_intro_slice.json"
	boot.train_save_path = "user://test_world_intro_train.json"
	boot.field_save_path = "user://test_world_intro_field.json"
	autofree(boot)
	var fresh: SliceFlow = boot._make_slice({}) as SliceFlow
	autofree(fresh)
	assert_eq(fresh.opts.get("intro", false), true)
	var resumed: SliceFlow = boot._make_slice({"step": "train"}) as SliceFlow
	autofree(resumed)
	assert_eq(resumed.opts.get("intro", true), false)
	for flow: SliceFlow in [fresh, resumed]:
		assert_eq(flow.opts["slice_save_path"], boot.slice_save_path)
		assert_eq(flow.opts["train_save_path"], boot.train_save_path)
		assert_eq(flow.opts["field_save_path"], boot.field_save_path)


func test_the_still_sheet_and_all_its_words_fit_in_1280_by_720() -> void:
	var viewport: SubViewport = SubViewport.new()
	viewport.size = Vector2i(1280, 720)
	add_child_autofree(viewport)
	var intro: WorldIntro = WorldIntro.new()
	intro.still = true
	viewport.add_child(intro)
	await wait_frames(3)
	var screen: Rect2 = Rect2(Vector2.ZERO, Vector2(viewport.size))
	assert_eq(intro.size, screen.size, "the overlay fills the viewport")
	assert_eq(intro.sheet.size, WorldIntro.SHEET_SIZE * UiFonts.K, "copy never grows the paper")
	assert_true(intro.sheet.get_script() == PaperSheet)
	assert_eq(intro.sheet.modulate.a, 1.0, "still shows the whole sheet at once")
	var dim: ColorRect = intro.get_node("Dim") as ColorRect
	assert_eq(dim.modulate.a, 1.0)
	assert_eq(dim.color, WorldIntro.DIM)
	# The sheet leans: test its four transformed corners, not an unrotated box.
	var transform: Transform2D = intro.sheet.get_global_transform()
	var sheet_size: Vector2 = intro.sheet.size
	for corner: Vector2 in [Vector2.ZERO, Vector2(sheet_size.x, 0), sheet_size, Vector2(0, sheet_size.y)]:
		assert_true(screen.has_point(transform * corner), "paper corner inside the screen: %s" % (transform * corner))
	var inner: Control = intro.sheet.inner
	var paper_room: Rect2 = Rect2(Vector2.ZERO, inner.size).grow(1.0)
	for node: Node in intro.sheet.find_children("*", "Label", true, false):
		var label: Label = node as Label
		var local: Transform2D = inner.get_global_transform().affine_inverse() * label.get_global_transform()
		assert_true(paper_room.encloses(Rect2(local.origin, label.size)), label.text + " stays on the paper")
	var text_room: Control = intro.body.get_parent() as Control
	assert_true(Rect2(Vector2.ZERO, text_room.size).grow(1.0).encloses(intro.body.get_rect()), "the body stays in its reserved room")
	var lines: int = intro.body.get_line_count()
	assert_gt(lines, 1, "the paragraph wraps")
	var text_height: float = 0.0
	for i: int in lines:
		text_height += float(intro.body.get_line_height(i))
	text_height += float(maxi(lines - 1, 0) * intro.body.get_theme_constant("line_spacing"))
	assert_lte(text_height, text_room.size.y + 1.0, "every line fits without clipping or growing the sheet")
	var font: Font = intro.body.get_theme_font("font")
	assert_true(font is FontVariation and String((font as FontVariation).base_font.resource_path).begins_with(UiFonts.DIR), "the paragraph uses the game's face")
	assert_eq(intro.body.get_theme_font_size("font_size"), UiFonts.size(12.0))
	assert_eq(intro.body.text.replace(UiFonts.WORD_JOINER, ""), WorldIntro.TEXT)
	assert_eq(intro.go_key.text, WorldIntro.GO_WORD)


func test_the_draft_is_three_or_four_sentences_with_a_kick_and_a_key() -> void:
	for words: String in [WorldIntro.KICK, WorldIntro.TEXT, WorldIntro.GO_WORD]:
		assert_false(words.strip_edges().is_empty())
	var sentences: int = WorldIntro.TEXT.count(".")
	assert_gte(sentences, 3)
	assert_lte(sentences, 4)
