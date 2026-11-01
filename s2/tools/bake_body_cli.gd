extends SceneTree
## Bakes a rigged body with a motion set into a folder.
## godot --headless --path <project> --script tools/bake_body_cli.gd -- <body glb> <motion glb[,motion glb...] | -> <out dir> [--check] [--small] [--keep=<clip,clip>] [--set=person] [--shell=<kind>]
## Several motion files (same skeleton) are read as one set.
## --set=person bakes the living people's motions (BodyBake.PERSON_CLIPS, no still poses) instead of the dead's;
## those from a motion set need the motion files, so "-" is refused for it.
## --small writes the compacted bake (BodyBake.compact) the phone build carries;
## --keep names the clips that keep every frame in it.
## --shell=<kind> bakes a garment (BodyBake.SHELLS) cut from the body, or a bag on its back
## (BodyBake.BAG_SHELLS), instead of the body:
## the same skin and motions, so it is drawn over a body baked with the same --set and --keep.

const BodyBake = preload("res://scripts/body_bake.gd")
const USAGE: String = "usage: godot --headless --path <project> --script tools/bake_body_cli.gd -- <body glb> <motion glb[,motion glb...] | -> <out dir> [--check] [--small] [--keep=<clip,clip>] [--set=person] [--shell=<kind>]"


func _init() -> void:
	var paths: Array[String] = []
	var check := false
	var small := false
	var keep: Array = []
	var person := false
	var garment := ""
	for arg in OS.get_cmdline_user_args():
		if arg == "--check":
			check = true
		elif arg == "--small":
			small = true
		elif arg == "--set=person":
			person = true
		elif arg.begins_with("--shell="):
			garment = arg.trim_prefix("--shell=")
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
	if own and person:
		print("the living's motions take some from a motion set: give the motion files")
		quit(1)
		return
	var body_root := BodyBake.load_glb(paths[0]) as Node3D
	var motion_roots: Array = []
	if not own:
		for motion_path in paths[1].split(",", false):
			var loaded := BodyBake.load_glb(motion_path) as Node3D
			if loaded == null:
				motion_roots.clear()
				break
			motion_roots.append(loaded)
	if body_root == null or (motion_roots.is_empty() and not own):
		print("could not read the body or motion file")
		quit(1)
		return
	if garment != "" and not BodyBake.shell(body_root, garment):
		print("no such garment, or no skinned mesh: ", garment)
		quit(1)
		return
	# A body (not a garment over it) carries its hands marked, for the shader's gloves.
	var marks := BodyBake.mark_hands(body_root) if garment == "" else PackedColorArray()
	root.add_child(body_root)
	for motion_root: Node3D in motion_roots:
		root.add_child(motion_root)
	await process_frame
	var motion_root: Node3D = null if own else BodyBake.merge_motions(motion_roots)
	var assets: Dictionary = BodyBake.bake_own(body_root) if own else (BodyBake.bake_person(body_root, motion_root) if person else BodyBake.bake(body_root, motion_root))
	if assets.is_empty():
		quit(1)
		return
	if not (assets.get("fit_failures", []) as Array).is_empty():
		print("fit failed, nothing saved: ", ", ".join(assets["fit_failures"]))
		quit(1)
		return
	if small:
		assets = BodyBake.compact(assets, keep)
	if not marks.is_empty():
		(assets["mesh"] as Mesh).set_meta(BodyBake.HAND_LIGHT, BodyBake.hand_light(assets["mesh"], marks, BodyBake.picture_of(body_root)))
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
