extends SceneTree
## Bakes the train people's motions (game/train/train_clips.gd) on a rigged body
## into a folder of their own. body_bake.gd is only read: its helpers retarget,
## skin and save; the layers here are train_clips.gd's, not body_bake.gd's.
## godot --headless --path s2 --script tools/bake_train_cli.gd -- <body glb> <motion glb,motion glb> <out dir> [--check] [--small]
## --small writes the compacted bake (BodyBake.compact) the phone build carries.

const BodyBake = preload("res://scripts/body_bake.gd")
const VatBaker = preload("res://scripts/vat_baker.gd")
const TrainClips = preload("res://game/train/train_clips.gd")
const USAGE: String = "usage: godot --headless --path s2 --script tools/bake_train_cli.gd -- <body glb> <motion glb[,motion glb...]> <out dir> [--check] [--small]"


func _init() -> void:
	var paths: Array[String] = []
	var check := false
	var small := false
	for arg in OS.get_cmdline_user_args():
		if arg == "--check":
			check = true
		elif arg == "--small":
			small = true
		else:
			paths.append(arg)
	if paths.size() < 3:
		print(USAGE)
		quit(1)
		return
	var body_root := BodyBake.load_glb(paths[0]) as Node3D
	var motion_roots: Array = []
	for motion_path in paths[1].split(",", false):
		var loaded := BodyBake.load_glb(motion_path) as Node3D
		if loaded == null:
			print("could not read the motion file ", motion_path)
			quit(1)
			return
		motion_roots.append(loaded)
	if body_root == null or motion_roots.is_empty():
		print("could not read the body or motion file")
		quit(1)
		return
	root.add_child(body_root)
	for motion_root: Node3D in motion_roots:
		root.add_child(motion_root)
	await process_frame
	var assets := bake(body_root, BodyBake.merge_motions(motion_roots))
	if assets.is_empty():
		quit(1)
		return
	if small:
		assets = BodyBake.compact(assets, TrainClips.KEEP)
	BodyBake.save(assets, paths[2])
	var image: Image = assets["image"]
	print("vertices ", assets["vertices"], " image ", image.get_width(), " x ", image.get_height(), " bytes ", image.get_data().size())
	if check:
		var back: Dictionary = BodyBake.load_baked(paths[2])
		var ok: bool = not back.is_empty() and back["clips"].size() == assets["clips"].size() and back["vertices"] == assets["vertices"]
		print("check ", "ok" if ok else "FAIL", " clips ", back.get("clips", []).size())
		if not ok:
			quit(1)
			return
	quit()


## TrainClips.CLIPS in order, posed as body_bake.gd poses its own list but with
## TrainClips.LAYERS. {} if a motion or a bone is missing.
static func bake(body_root: Node3D, motion_root: Node3D) -> Dictionary:
	var list: Array = TrainClips.CLIPS
	# body_bake.gd checks layer names against its own table: hand it the rows without them.
	var bare: Array = list.map(func(row: Array) -> Array: return [row[0], row[1], row[2], row[3], "", row[5]])
	var ctx := BodyBake.prepare(body_root, motion_root, bare, [])
	if ctx.is_empty():
		return {}
	for row: Array in list:
		if String(row[4]) != "" and not TrainClips.LAYERS.has(row[4]):
			push_error("bake_train: layer not found: " + str(row[4]))
			return {}
	ctx["sink_scale"] = BodyBake._sink_scale(body_root, ctx["body"])
	var player: AnimationPlayer = ctx["player"]
	var mesh_node: MeshInstance3D = ctx["mesh_node"]
	var clips := []
	for row: Array in list:
		var count: int = row[2]
		var looped: bool = row[3]
		var frames := []
		var reach := [[], []]
		var spec: Dictionary = TrainClips.LAYERS.get(row[4], {})
		for f in count:
			var u: float = float(f) / float(count) if looped else float(f) / float(count - 1)
			_pose(ctx, String(row[1]), spec, u)
			frames.append(BodyBake._skin_frame(ctx))
			BodyBake._note_reach(ctx, String(row[0]), reach)
		var share: float = 1.0
		if spec.has("span"):
			share = float(spec["span"][1]) - float(spec["span"][0])
		var length: float = float(row[5]) if String(row[1]) == "" else player.get_animation(row[1]).length * share
		# A held pose (a short span) still needs a breath of length so the shader's rate stays sane.
		length = maxf(length, 2.0) if share < 0.1 else length
		clips.append({"name": row[0], "loop": looped, "length": length, "frames": frames, "round": BodyBake._round(reach) if looped else 0.0})
	return BodyBake._with_rounds(VatBaker.build_skinned(mesh_node.mesh.surface_get_arrays(0), clips), clips)


static func _pose(ctx: Dictionary, clip: String, spec: Dictionary, u: float) -> void:
	var at := u
	if spec.has("span"):
		var span: Array = spec["span"]
		at = lerpf(float(span[0]), float(span[1]), at)
	BodyBake._pose_at(ctx, clip, at, spec.get("damp", {}))
	BodyBake.apply_layer(ctx["body"], spec, u, float(ctx.get("sink_scale", 1.0)))
