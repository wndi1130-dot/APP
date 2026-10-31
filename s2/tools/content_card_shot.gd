extends SceneTree
## Lead-only capture; this task does not launch Godot.
## godot --path s2 --resolution 1560x720 --script res://tools/content_card_shot.gd
## Six PNGs: res://.godot/content_card_<short|longest|why_later>_<width>x720.png.
## Real generated first views only. Fit width and settling match test_turn_card.gd.
const TurnCard = preload("res://game/ui/turn_card.gd")
const UiFonts = preload("res://game/ui/ui_fonts.gd")
const FIXTURES: String = "res://tests/fixtures/train/content_vectors.json"


func _initialize() -> void:
	_run.call_deferred()


func _settled(card: Control) -> bool:
	for _frame: int in 40:
		await process_frame
		if not card.is_processing():
			await process_frame
			return true
	return false


func _run() -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(FIXTURES))
	if not parsed is Dictionary:
		push_error("F-CONTENT-SHOT: cannot read content fixtures")
		quit(1)
		return
	var fixtures: Dictionary = parsed
	var out: String = ProjectSettings.globalize_path("res://.godot")
	var made: Error = DirAccess.make_dir_recursive_absolute(out)
	if made != OK:
		push_error("F-CONTENT-SHOT: cannot create output directory (%d)" % made)
		quit(1)
		return
	for width: int in [1560, 1280]:
		var viewport: SubViewport = SubViewport.new()
		viewport.size = Vector2i(width, 720)
		viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		root.add_child(viewport)
		var background: ColorRect = ColorRect.new()
		background.color = TurnCard.Paper.INK
		background.size = Vector2(width, 720)
		viewport.add_child(background)
		var card := TurnCard.new()
		card.fit_w = float(width) / UiFonts.K - 330.0 + 44.0 - 6.0 - TurnCard.SHEET_AT.x
		card.position = Vector2((330.0 - 44.0 + 6.0) * UiFonts.K, 0)
		viewport.add_child(card)
		for shot: Dictionary in fixtures["shots"]:
			var selected: Dictionary = {}
			for row: Dictionary in fixtures["views"]:
				if row["name"] == shot["case"]:
					selected = row
					break
			if selected.is_empty():
				push_error("F-CONTENT-SHOT: missing case " + str(shot["case"]))
				quit(1)
				return
			card.show_card(selected["state"], fixtures["tables"], int(selected["card"]["uid"]))
			var settled: bool = await _settled(card)
			if not settled:
				push_error("F-CONTENT-SHOT: layout did not settle: %s/%d" % [shot["case"], width])
				quit(1)
				return
			await RenderingServer.frame_post_draw
			var picture: Image = viewport.get_texture().get_image()
			if picture == null or picture.get_size() != Vector2i(width, 720):
				push_error("F-CONTENT-SHOT: invalid capture size")
				quit(1)
				return
			var path: String = out.path_join("content_card_%s_%dx720.png" % [shot["name"], width])
			var saved: Error = picture.save_png(path)
			if saved != OK:
				push_error("F-CONTENT-SHOT: save failed (%d): %s" % [saved, path])
				quit(1)
				return
			print("CONTENT_CARD_SHOT %s case=%s" % [path, shot["case"]])
		viewport.queue_free()
		await process_frame
	quit(0)
