extends SceneTree
## Bakes a rigged body with a motion set into a folder.
## godot --headless --path <project> --script tools/bake_body_cli.gd -- <body glb> <motion glb | -> <out dir> [--check] [--small] [--keep=<clip,clip>] [--set=person]
## --set=person bakes the living people's motions (BodyBake.PERSON_CLIPS, no still poses) instead of the dead's.
## --small writes the compacted bake (BodyBake.compact) the phone build carries;
## --keep names the clips that keep every frame in it.

const BodyBake = preload("res://scripts/body_bake.gd")
const USAGE: String = "usage: godot --headless --path <project> --script tools/bake_body_cli.gd -- <body glb> <motion glb | -> <out dir> [--check] [--small] [--keep=<clip,clip>] [--set=person]"


func _init() -> void:
	var paths: Array[String] = []
	var check := false
	var small := false
	var keep: Array = []
	var person := false
	for arg in OS.get_cmdline_user_args():
		if arg == "--check":
			check = true
		elif arg == "--small":
			small = true
		elif arg == "--set=person":
			person = true
		elif arg.begins_with("--keep="):
			keep = Array(arg.trim_prefix("--keep=").split(",", false))
		else:
			paths.append(arg)
	if paths.size() < 3:
		print(USAGE)
		quit(1)
		return
	# "-" for the motion file: the motions written in body_bake.gd alone.
	var own: bool = paths[1] == "-"
	var body_root := BodyBake.load_glb(paths[0]) as Node3D
	var motion_root: Node3D = null if own else BodyBake.load_glb(paths[1]) as Node3D
	if body_root == null or (motion_root == null and not own):
		print("could not read the body or motion file")
		quit(1)
		return
	root.add_child(body_root)
	if not own:
		root.add_child(motion_root)
	await process_frame
	var assets: Dictionary = (BodyBake.bake_own(body_root, BodyBake.PERSON_CLIPS, []) if person else BodyBake.bake_own(body_root)) if own else BodyBake.bake(body_root, motion_root)
	if assets.is_empty():
		quit(1)
		return
	if small:
		assets = BodyBake.compact(assets, keep)
	BodyBake.save(assets, paths[2])
	var image: Image = assets["image"]
	print("vertices ", assets["vertices"], " image ", image.get_width(), " x ", image.get_height(), " bytes ", image.get_data().size())
	if check:
		var loaded: Dictionary = BodyBake.load_baked(paths[2])
		var loaded_image: Image = loaded.get("image")
		var same: bool = not loaded.is_empty() and loaded["clips"].size() == assets["clips"].size() \
			and loaded_image.get_width() == image.get_width() and loaded_image.get_height() == image.get_height() \
			and loaded_image.get_data() == image.get_data() and loaded["vertices"] == assets["vertices"]
		print("check ", "ok" if same else "FAIL", " clips ", loaded.get("clips", []).size(), " image ", loaded_image.get_width() if loaded_image else 0, " x ", loaded_image.get_height() if loaded_image else 0)
		if not same:
			quit(1)
			return
	quit()
