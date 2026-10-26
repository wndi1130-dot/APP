extends SceneTree
## Frames of one melee blow (decision 444, 전투 손맛): the player swings a
## weapon at a body standing 0.9 m east, and every frame from the swing's
## start is taken at a fixed 60 fps through the field's own _process, with the
## rules clock, the camera's offset in pixels and the sounds of each frame.
##   godot --path s2 --resolution 1688x780 --fixed-fps 60 -s res://tools/hit_feel_frames.gd -- --out=<folder> [--weapon=crowbar] [--frames=40]
## Writes f_<nn>.png (the middle of the screen round the player) and
## frames.json. It runs on code without hit_feel.gd as well (a PR's "before").

const FieldGame = preload("res://game/field_game.gd")

var out := ""
var weapon := "crowbar"
var frames := 40
const CROP := Vector2i(640, 400)


func _initialize() -> void:
	_run()


func _run() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.substr(6)
		elif a.begins_with("--weapon="):
			weapon = a.substr(9)
		elif a.begins_with("--frames="):
			frames = int(a.substr(9))
	DirAccess.make_dir_recursive_absolute(out)
	await process_frame
	var game = FieldGame.new()
	game.opts = {"seed": 5, "raiders": false, "auto_pause": false, "arrive": false, "weather": ["clear"], "look": ["overcast"], "look_hour": 12.0}
	root.add_child(game)
	game.hud.visible = false
	game.mask_on = false
	game.view.set_mask_enabled(false)
	game.zombies.list.clear()
	game.pending_spawn.clear()
	var p = game.player
	p.hands = [{"id": weapon, "quality": "factory", "condition": 1.0, "loaded": 0}]
	p.set_weapon_slots(p.hands)
	p.facing = PI * 0.5
	game.cam_push = Vector3.ZERO
	game.cam_size = 9.0
	game.cam_focus = p.position
	game.camera.size = game.cam_size
	game.set_process(true)
	for i in 20:
		await process_frame
	# The body comes in at the swing, so it has no time to grab first.
	game.zombies.spawn("dead", p.position + Vector3(0.9, 0, 0))
	game.combat.swing_air(p)
	var rows: Array = []
	var heard := 0
	for i in frames:
		await RenderingServer.frame_post_draw
		var size: Vector2 = root.get_viewport().get_visible_rect().size
		var focus_px: Vector2 = game.camera.unproject_position(game.cam_focus)
		var played: Array = game.audio.played.slice(heard)
		heard = game.audio.played.size()
		var feel = game.get("feel")
		rows.append({"frame": i, "rules_t": snappedf(game.clock.elapsed, 0.0001),
			"hold": feel != null and feel.holding(),
			"camera_px": snappedf((focus_px - size * 0.5).length(), 0.01),
			"played": played, "last_tag_group": game.audio.last_tag_group})
		var img: Image = root.get_viewport().get_texture().get_image()
		var c := Vector2i(int(size.x * 0.5), int(size.y * 0.5))
		img.get_region(Rect2i(c - CROP / 2, CROP)).save_png(out.path_join("f_%02d.png" % i))
	var f := FileAccess.open(out.path_join("frames.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify({"weapon": weapon, "frame_s": 1.0 / 60.0, "rows": rows}, "  "))
	f.close()
	game.queue_free()
	await process_frame
	quit()
