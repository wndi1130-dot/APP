extends SceneTree
## Marks the hands (BodyBake.hand_marks) in folders already baked from a body,
## for the shader's gloves (dead_vat.gdshader `gloves`): only mesh.res changes,
## the same vertices in the same order, so the motion picture is read as before.
## godot --headless --path <project> --script tools/hand_marks_cli.gd -- <body glb> <baked dir> [<baked dir>...]
## The hands' light is read off the folder's albedo.png, or, without one, the
## first folder's that has one (the dead's folder has none), else the body's own picture.

const BodyBake = preload("res://scripts/body_bake.gd")
const USAGE: String = "usage: godot --headless --path <project> --script tools/hand_marks_cli.gd -- <body glb> <baked dir> [<baked dir>...]"
const SAME_PLACE: float = 0.0001          # metres a baked vertex may be from the body's own


func _init() -> void:
	var paths: Array[String] = []
	for arg in OS.get_cmdline_user_args():
		paths.append(arg)
	if paths.size() < 2:
		print(USAGE)
		quit(1)
		return
	var body_root := BodyBake.load_glb(paths[0]) as Node3D
	if body_root == null:
		print("could not read the body")
		quit(1)
		return
	var marks := BodyBake.hand_marks(body_root)
	var mesh_node := BodyBake.first_of(body_root, "MeshInstance3D") as MeshInstance3D
	if marks.is_empty() or mesh_node == null:
		print("the body has no skinned mesh")
		body_root.free()
		quit(1)
		return
	var rest: PackedVector3Array = mesh_node.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var picture: Image = null
	for dir: String in paths.slice(1):
		if FileAccess.file_exists(dir.path_join("albedo.png")):
			picture = Image.load_from_file(dir.path_join("albedo.png"))
			break
	if picture == null:
		picture = BodyBake.picture_of(body_root)
	body_root.free()
	var hands := 0
	for c in marks:
		hands += 1 if c.a > 0.5 else 0
	var failed := false
	for dir: String in paths.slice(1):
		var mesh := ResourceLoader.load(dir.path_join("mesh.res"), "", ResourceLoader.CACHE_MODE_IGNORE) as Mesh
		if mesh == null:
			print(dir, ": no mesh.res")
			failed = true
			continue
		var baked: PackedVector3Array = mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		var far := 0.0
		if baked.size() == rest.size():
			for i in baked.size():
				far = maxf(far, baked[i].distance_to(rest[i]))
		if baked.size() != rest.size() or far > SAME_PLACE:
			print(dir, ": not this body (vertices ", baked.size(), " / ", rest.size(), ", furthest ", far, " m)")
			failed = true
			continue
		var light := BodyBake.hand_light(mesh, marks, picture)
		var marked := BodyBake.with_hand_marks(mesh, marks, light)
		var err := ResourceSaver.save(marked, dir.path_join("mesh.res"))
		print(dir, ": vertices ", baked.size(), " on the hands ", hands, " light ", snappedf(light, 0.001), " err ", err)
		failed = failed or err != OK
	quit(1 if failed else 0)
