extends SceneTree
## Paints a body's colour picture with gloves on its hands (BodyBake.gloved).
## godot --headless --path <project> --script tools/gloves_cli.gd -- <body glb> <albedo png> <out png> [--colour=r,g,b]
## The colour is as the picture holds it (0..1 each); left out, BodyBake.GLOVE_COLOUR.

const BodyBake = preload("res://scripts/body_bake.gd")
const USAGE: String = "usage: godot --headless --path <project> --script tools/gloves_cli.gd -- <body glb> <albedo png> <out png> [--colour=r,g,b]"


func _init() -> void:
	var paths: Array[String] = []
	var colour := BodyBake.GLOVE_COLOUR
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--colour="):
			var parts := arg.trim_prefix("--colour=").split(",")
			colour = Color(float(parts[0]), float(parts[1]), float(parts[2]))
		else:
			paths.append(arg)
	if paths.size() < 3:
		print(USAGE)
		quit(1)
		return
	var body_root := BodyBake.load_glb(paths[0]) as Node3D
	var albedo := Image.load_from_file(paths[1])
	if body_root == null or albedo == null:
		print("could not read the body or the colour picture")
		quit(1)
		return
	var out := BodyBake.gloved(body_root, albedo, colour)
	body_root.free()
	if out == null:
		print("the body has no skinned mesh with UVs")
		quit(1)
		return
	var err := out.save_png(paths[2])
	print("gloves ", paths[2], " ", out.get_width(), " x ", out.get_height(), " err ", err)
	quit(0 if err == OK else 1)
