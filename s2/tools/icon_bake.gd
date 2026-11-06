extends SceneTree
## Fixed-light item icons. Run with a rendering window, not headless.
## godot --path s2 --resolution 512x512 -s res://tools/icon_bake.gd -- <out_dir> <list_file>

const ICON_SIZE := 256
const CELL_SIZE := 128
const MARGIN := 0.12 # Per edge.
const CANVAS := Color("8a8270")
const OUTLINE := Color("171c22")
## A pale line just outside the dark one, so a dark thing still parts from the
## pane's dark glass at 26 css (코디 2026-11-07 「어두운 바탕에서 읽히는지」); on a
## light ground it is all but unseen and the dark line does that work.
const RIM := Color("d6dde3")
const RIM_ALPHA := 0.3
## The camera is moved onto the drawing at most this many times, until it is
## within this many pixels of filling the square (refit).
const FIT_TRIES := 3
const FIT_TOLERANCE := 2.0
const BACKGROUNDS := [Color("3a3f45"), Color("d9dde0")]

var _entries: Array[Dictionary] = []
var _out_dir := ""
var _cursor := 0
var _saved := 0
var _directory_error := ""


func _initialize() -> void:
	call_deferred("_begin")


func _begin() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 2:
		print("usage: godot --path s2 --resolution 512x512 -s res://tools/icon_bake.gd -- <out_dir> <list_file>")
		_done()
		return
	_out_dir = ProjectSettings.globalize_path(args[0])
	var file := FileAccess.open(args[1], FileAccess.READ)
	if file == null:
		print("ICON_BAKE_SKIP list=", args[1], " reason=", error_string(FileAccess.get_open_error()))
		_done()
		return
	var pattern := RegEx.new()
	pattern.compile("^(\\S+)\\s+(res://.+?\\.(?:glb|gltf|obj|tscn|scn|res|tres|gd))(?:\\s+(\\S+))?(?:\\s+(\\S+))?(?:\\s+(\\S+))?(?:\\s+(\\S+))?$")
	var names := {}
	var line_number := 0
	while file.get_position() < file.get_length():
		line_number += 1
		var line := file.get_line().trim_prefix("\ufeff").strip_edges()
		if line.is_empty() or line.begins_with("#"):
			continue
		var entry := {"name": "line_%d" % line_number, "line": line_number}
		var matched := pattern.search(line)
		if matched == null:
			entry["error"] = "expected: <name> <res://scene_or_mesh> [yaw] [pitch] [roll] [margin]"
		else:
			var item_name := matched.get_string(1)
			entry["name"] = item_name
			entry["path"] = matched.get_string(2)
			entry["yaw"] = 35.0
			entry["pitch"] = 28.0
			# Roll turns the picture in its own plane (a long thing laid along the
			# diagonal fills more of the square); margin is per edge.
			entry["roll"] = 0.0
			entry["margin"] = MARGIN
			if not item_name.is_valid_filename() or item_name in [".", ".."]:
				entry["error"] = "name must be a single valid filename"
			elif names.has(item_name.to_lower()):
				entry["error"] = "duplicate name"
			else:
				names[item_name.to_lower()] = true
			for group in [3, 4, 5, 6]:
				var angle := matched.get_string(group)
				if not angle.is_empty():
					if not angle.is_valid_float() or not is_finite(angle.to_float()):
						entry["error"] = "yaw and pitch must be finite degrees"
					else:
						entry[["yaw", "pitch", "roll", "margin"][group - 3]] = angle.to_float()
		_entries.append(entry)
	var read_error := file.get_error()
	file.close()
	if read_error != OK and read_error != ERR_FILE_EOF:
		print("ICON_BAKE_SKIP list=", args[1], " reason=", error_string(read_error))
	var directory_error := DirAccess.make_dir_recursive_absolute(_out_dir)
	if directory_error != OK:
		_directory_error = "output directory: " + error_string(directory_error)
	call_deferred("_bake_next")


func _bake_next() -> void:
	if _cursor >= _entries.size():
		call_deferred("_finish")
		return
	var entry: Dictionary = _entries[_cursor]
	_cursor += 1
	if entry.has("error") or not _directory_error.is_empty():
		_skip(entry, str(entry.get("error", _directory_error)))
		return
	var path: String = entry["path"]
	if not ResourceLoader.exists(path):
		_skip(entry, "resource missing: " + path)
		return
	var resource := ResourceLoader.load(path)
	var source: Node
	if resource is Script:
		# A builder script: build(name) makes the thing's model (tools/item_models.gd).
		source = (resource as Script).call("build", str(entry["name"])) as Node
	elif resource is Mesh:
		var instance := MeshInstance3D.new()
		instance.mesh = resource as Mesh
		source = instance
	elif resource is PackedScene:
		source = (resource as PackedScene).instantiate()
	if source == null:
		_skip(entry, "could not load a Mesh or PackedScene: " + path)
		return
	var stage := Node3D.new()
	_copy_meshes(source, Transform3D.IDENTITY, true, stage, str(entry["name"]), _paints_with_vertex_colours(path))
	source.free()
	if stage.get_child_count() == 0:
		stage.free()
		_skip(entry, "no visible mesh surfaces")
		return
	var view := SubViewport.new()
	view.size = Vector2i(ICON_SIZE, ICON_SIZE)
	view.own_world_3d = true
	view.transparent_bg = true
	view.msaa_3d = Viewport.MSAA_4X
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(view)
	view.add_child(stage)
	var margin: float = clampf(float(entry["margin"]), 0.0, 0.4)
	if not _set_camera_and_lights(stage, view, float(entry["yaw"]), float(entry["pitch"]), float(entry["roll"]), margin):
		_skip(entry, "empty or non-finite mesh bounds", view)
		return
	var image: Image = await _draw(view)
	# Every thing fills its square alike (코디 2026-11-07 「칸 채움 크기 맞추기」): the
	# camera was framed on the box round the model's corners, which is wider than
	# what is drawn, the more so turned. So the drawing itself is measured and the
	# camera moved and zoomed onto it, a few times at most.
	var camera: Camera3D = view.get_camera_3d()
	for _try in range(FIT_TRIES):
		if image == null or image.is_empty():
			break
		image.convert(Image.FORMAT_RGBA8)
		var used: Rect2i = image.get_used_rect()
		if not used.has_area():
			break
		var fit: Dictionary = refit(used, ICON_SIZE, margin)
		if not bool(fit["off"]):
			break
		var per_pixel: float = camera.size / float(ICON_SIZE)
		var shift: Vector2 = fit["shift"]
		var axes: Basis = camera.transform.basis
		camera.position += axes.x * (shift.x * per_pixel) - axes.y * (shift.y * per_pixel)
		camera.size *= float(fit["scale"])
		image = await _draw(view)
	view.queue_free()
	if image == null or image.is_empty():
		_skip(entry, "viewport readback failed")
		return
	image.convert(Image.FORMAT_RGBA8)
	if not image.get_used_rect().has_area():
		_skip(entry, "render is fully transparent")
		return
	var muted := _make_muted(image)
	entry["preview"] = muted
	var small := _resize_alpha(image, 64)
	var images := [image, small, muted]
	var suffixes := ["_256.png", "_64.png", "_256_muted.png"]
	var saved_all := true
	for i in images.size():
		var destination := _out_dir.path_join(str(entry["name"]) + suffixes[i])
		var save_error: Error = (images[i] as Image).save_png(destination)
		if save_error != OK:
			saved_all = false
			print("ICON_BAKE_SAVE_FAILED path=", destination, " reason=", error_string(save_error))
	if saved_all:
		_saved += 1
		print("ICON_BAKE_SAVED name=", entry["name"])
	else:
		entry["error"] = "one or more PNG writes failed"
	call_deferred("_bake_next")


## The view's picture once uploads, shader compilation and the draws are done.
func _draw(view: SubViewport) -> Image:
	for _frame in range(4):
		await process_frame
		await RenderingServer.frame_post_draw
	return view.get_texture().get_image()


## How far the camera is off a square filled as every other is: the drawn part
## (`used`, pixels of a `size` square) should have its longer side at
## size·(1 − 2·margin) and its middle at the square's middle. {"scale": the factor
## for the camera's size, "shift": Vector2 pixels the camera moves (x right, y
## down), "off": whether either is more than FIT_TOLERANCE pixels out}.
static func refit(used: Rect2i, size: int, margin: float) -> Dictionary:
	var side: float = float(maxi(used.size.x, used.size.y))
	var target: float = float(size) * (1.0 - margin * 2.0)
	var middle: Vector2 = Vector2(used.position) + Vector2(used.size) * 0.5
	var shift: Vector2 = middle - Vector2(size, size) * 0.5
	var off: bool = absf(side - target) > FIT_TOLERANCE or shift.length() > FIT_TOLERANCE
	return {"scale": side / maxf(target, 1.0), "shift": shift, "off": off}


func _skip(entry: Dictionary, reason: String, view: SubViewport = null) -> void:
	entry["error"] = reason
	print("ICON_BAKE_SKIP line=", entry["line"], " name=", entry["name"], " reason=", reason)
	if view != null:
		view.queue_free()
	call_deferred("_bake_next")


func _copy_meshes(node: Node, parent_pose: Transform3D, shown: bool,
		stage: Node3D, item_name: String, vertex_coloured: bool = false) -> void:
	var pose := parent_pose
	if node is Node3D:
		var spatial := node as Node3D
		pose = spatial.transform if spatial.top_level else parent_pose * spatial.transform
		shown = shown and spatial.visible
	if node is MeshInstance3D and shown:
		var original := node as MeshInstance3D
		if original.mesh != null and original.mesh.get_surface_count() > 0:
			# Copy static geometry only; scene lights and callbacks stay outside the tree.
			var instance := MeshInstance3D.new()
			instance.mesh = original.mesh
			instance.transform = pose
			instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			for surface in original.mesh.get_surface_count():
				var material := original.get_active_material(surface)
				instance.set_surface_override_material(surface,
					_bake_material(material, original.mesh, surface, item_name, vertex_coloured))
			stage.add_child(instance)
	for child in node.get_children():
		_copy_meshes(child, pose, shown, stage, item_name, vertex_coloured)


## A glTF file that defines no materials at all is painted only in its vertex
## colours (COLOR_0): the importer gives it a plain white material that would
## hide them. A file with materials, even plain white ones, keeps them as made.
static func _paints_with_vertex_colours(path: String) -> bool:
	var json_text := ""
	if not FileAccess.file_exists(path):
		return false
	if path.ends_with(".gltf"):
		json_text = FileAccess.get_file_as_string(path)
	elif path.ends_with(".glb"):
		var file := FileAccess.open(path, FileAccess.READ)
		if file == null or file.get_length() < 20 or file.get_32() != 0x46546C67:
			return false
		file.seek(12)
		var chunk_length := file.get_32()
		if file.get_32() != 0x4E4F534A or chunk_length > file.get_length() - 20:
			return false
		json_text = file.get_buffer(chunk_length).get_string_from_utf8()
	if json_text.is_empty():
		return false
	var gltf: Variant = JSON.parse_string(json_text)
	if not gltf is Dictionary:
		return false
	var materials: Variant = (gltf as Dictionary).get("materials", [])
	return materials is Array and (materials as Array).is_empty()


func _bake_material(original: Material, mesh: Mesh, surface: int, item_name: String,
		vertex_coloured: bool = false) -> Material:
	if original is BaseMaterial3D:
		var copy := original.duplicate() as BaseMaterial3D
		copy.next_pass = null
		# A model painted only in vertex colours: read them as the game's shaders
		# do (sRGB), in place of the importer's plain white.
		if vertex_coloured and copy.albedo_texture == null and _has_colors(mesh, surface):
			copy.vertex_color_use_as_albedo = true
			copy.vertex_color_is_srgb = true
			print("ICON_BAKE_MATERIAL name=", item_name, " surface=", surface,
				" source=", original.get_class(), " replacement=copy color=vertex_color_srgb")
		return copy
	var material := StandardMaterial3D.new()
	material.roughness = 0.9
	material.metallic = 0.0
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	var texture: Texture2D
	var tint := Color.WHITE
	var has_tint := false
	var missing: Array[String] = []
	if original is ShaderMaterial:
		var shader_material := original as ShaderMaterial
		var shader := shader_material.shader
		if shader != null:
			for uniform in shader.get_shader_uniform_list():
				var key := str(uniform["name"])
				var value: Variant = shader_material.get_shader_parameter(key)
				var is_texture := str(uniform.get("hint_string", "")).contains("Texture")
				if value == null and is_texture:
					value = shader.get_default_texture_parameter(key)
				elif value == null:
					value = RenderingServer.shader_get_parameter_default(shader.get_rid(), key)
				if is_texture and (value == null or (value is Texture2D and value.get_size() == Vector2.ZERO)):
					missing.append(key)
				if not _is_albedo_name(key):
					continue
				if value is Texture2D and texture == null:
					if value.get_width() > 0 and value.get_height() > 0:
						texture = value as Texture2D
				elif not has_tint:
					if value is Color:
						tint = value
						has_tint = true
					elif value is Vector3:
						tint = Color(value.x, value.y, value.z)
						has_tint = true
					elif value is Vector4:
						tint = Color(value.x, value.y, value.z, value.w)
						has_tint = true
	var mode := "albedo"
	if texture != null or has_tint:
		material.albedo_texture = texture
		material.albedo_color = tint
		if texture != null or tint.a < 1.0:
			material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	else:
		var arrays := mesh.surface_get_arrays(surface)
		var colors: Variant = arrays[Mesh.ARRAY_COLOR] if arrays.size() > Mesh.ARRAY_COLOR else null
		if colors is PackedColorArray and not colors.is_empty():
			material.vertex_color_use_as_albedo = true
			mode = "vertex_color"
		else:
			material.albedo_color = CANVAS
			mode = "canvas_8a8270"
	print("ICON_BAKE_MATERIAL name=", item_name, " surface=", surface,
		" source=", original.get_class() if original != null else "none",
		" replacement=StandardMaterial3D color=", mode, " missing_textures=", missing)
	return material


func _has_colors(mesh: Mesh, surface: int) -> bool:
	var arrays := mesh.surface_get_arrays(surface)
	var colors: Variant = arrays[Mesh.ARRAY_COLOR] if arrays.size() > Mesh.ARRAY_COLOR else null
	return colors is PackedColorArray and not (colors as PackedColorArray).is_empty()


func _is_albedo_name(key: String) -> bool:
	var lower := key.to_lower()
	return lower.contains("albedo") or lower.contains("base_color") \
		or lower.contains("basecolor") or lower.contains("diffuse") \
		or lower in ["color", "tint", "color_texture", "color_map", "texture_color", "picture"]


func _set_camera_and_lights(stage: Node3D, view: SubViewport, yaw: float, pitch: float,
		roll: float = 0.0, margin: float = MARGIN) -> bool:
	var axes := Basis(Vector3.UP, deg_to_rad(yaw)) * Basis(Vector3.RIGHT, -deg_to_rad(pitch)) * Basis(Vector3.BACK, deg_to_rad(roll))
	var low := Vector3(INF, INF, INF)
	var high := Vector3(-INF, -INF, -INF)
	for child in stage.get_children():
		var instance := child as MeshInstance3D
		var box := instance.mesh.get_aabb()
		for corner in range(8):
			var point: Vector3 = axes.inverse() * (instance.transform * box.get_endpoint(corner))
			if not point.is_finite():
				return false
			low = low.min(point)
			high = high.max(point)
	var extent := high - low
	if not extent.is_finite() or maxf(extent.x, extent.y) <= 0.000001:
		return false
	var center := axes * ((low + high) * 0.5)
	var distance := extent.length() * 2.0 + 1.0
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = maxf(extent.x, extent.y) / (1.0 - margin * 2.0)
	camera.near = 0.001
	camera.far = distance + extent.z + 1.0
	camera.transform = Transform3D(axes, center + axes.z * distance)
	view.add_child(camera)
	camera.make_current()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0, 0, 0, 0)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("8996a6")
	environment.ambient_light_energy = 0.25
	environment.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var world := WorldEnvironment.new()
	world.environment = environment
	view.add_child(world)
	_add_light(view, axes, center, Vector3(-3, 4, 5), Color("fff0dc"), 1.1)
	_add_light(view, axes, center, Vector3(3, -2, 4), Color("93a7bc"), 0.35)
	_add_light(view, axes, center, Vector3(1, 3, -4), Color("d0dce5"), 0.6)
	return true


func _add_light(view: SubViewport, axes: Basis, center: Vector3,
		direction: Vector3, color: Color, energy: float) -> void:
	var light := DirectionalLight3D.new()
	light.light_color = color
	light.light_energy = energy
	light.shadow_enabled = false
	view.add_child(light)
	light.position = center + axes * direction
	light.look_at(center, axes.y)


func _resize_alpha(source: Image, size: int) -> Image:
	var image := source.duplicate() as Image
	# Filter premultiplied pixels to avoid dark fringes.
	image.premultiply_alpha()
	image.resize(size, size, Image.INTERPOLATE_LANCZOS)
	for y in size:
		for x in size:
			var pixel := image.get_pixel(x, y)
			if pixel.a > 0.0:
				pixel = Color(pixel.r / pixel.a, pixel.g / pixel.a, pixel.b / pixel.a, pixel.a)
			else:
				pixel = Color(0, 0, 0, 0)
			image.set_pixel(x, y, pixel)
	return image


## The picture as the pane shows it: colour pressed to 0.75, a dark line one pixel
## round the thing (half strength) and, one pixel further out, the pale RIM.
## Each lies behind what is drawn there, so the thing's own edge stays as drawn.
static func _make_muted(source: Image) -> Image:
	var muted := source.duplicate() as Image
	muted.adjust_bcs(1.0, 1.0, 0.75)
	var width: int = muted.get_width()
	var height: int = muted.get_height()
	var own := PackedFloat32Array()
	own.resize(width * height)
	for y in height:
		for x in width:
			own[y * width + x] = muted.get_pixel(x, y).a
	var near := _dilate(own, width, height)
	var further := _dilate(near, width, height)
	var result := muted.duplicate() as Image
	for y in height:
		for x in width:
			var at: int = y * width + x
			var pixel := muted.get_pixel(x, y)
			var line := (near[at] - own[at]) * 0.5 * (1.0 - pixel.a)
			var halo := maxf(further[at] - near[at], 0.0) * RIM_ALPHA * (1.0 - pixel.a - line)
			var alpha := pixel.a + line + halo
			if alpha > 0.0:
				result.set_pixel(x, y, Color(
					(pixel.r * pixel.a + OUTLINE.r * line + RIM.r * halo) / alpha,
					(pixel.g * pixel.a + OUTLINE.g * line + RIM.g * halo) / alpha,
					(pixel.b * pixel.a + OUTLINE.b * line + RIM.b * halo) / alpha, alpha))
	return result


## Each value as the largest within one step round it (a 3×3 grey dilation).
static func _dilate(values: PackedFloat32Array, width: int, height: int) -> PackedFloat32Array:
	var across := PackedFloat32Array()
	across.resize(values.size())
	for y in height:
		for x in width:
			var best: float = values[y * width + x]
			if x > 0:
				best = maxf(best, values[y * width + x - 1])
			if x < width - 1:
				best = maxf(best, values[y * width + x + 1])
			across[y * width + x] = best
	var out := PackedFloat32Array()
	out.resize(values.size())
	for y in height:
		for x in width:
			var best: float = across[y * width + x]
			if y > 0:
				best = maxf(best, across[(y - 1) * width + x])
			if y < height - 1:
				best = maxf(best, across[(y + 1) * width + x])
			out[y * width + x] = best
	return out


func _finish() -> void:
	if not _directory_error.is_empty():
		print("ICON_BAKE_SHEET_FAILED reason=", _directory_error)
		_done()
		return
	var columns := maxi(1, _entries.size())
	if columns * CELL_SIZE > 16384:
		print("ICON_BAKE_SHEET_FAILED reason=sheet exceeds 16384 pixels wide")
		_done()
		return
	var sheet := SubViewport.new()
	sheet.size = Vector2i(columns * CELL_SIZE, CELL_SIZE * 2)
	sheet.disable_3d = true
	sheet.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(sheet)
	for row in range(2):
		var background := ColorRect.new()
		background.color = BACKGROUNDS[row]
		background.position = Vector2(0, row * CELL_SIZE)
		background.size = Vector2(sheet.size.x, CELL_SIZE)
		sheet.add_child(background)
		for column in _entries.size():
			var entry: Dictionary = _entries[column]
			var origin := Vector2(column * CELL_SIZE, row * CELL_SIZE)
			if entry.has("preview"):
				var picture := TextureRect.new()
				picture.texture = ImageTexture.create_from_image(_resize_alpha(entry["preview"], 108))
				picture.position = origin + Vector2(10, 0)
				picture.size = Vector2(108, 108)
				sheet.add_child(picture)
			var label := Label.new()
			label.text = str(entry["name"]) + (" [failed]" if entry.has("error") else "")
			label.position = origin + Vector2(2, 108)
			label.size = Vector2(CELL_SIZE - 4, 20)
			label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			label.clip_text = true
			label.add_theme_font_size_override("font_size", 12)
			label.add_theme_color_override("font_color", Color("eeeeee") if row == 0 else Color("20262d"))
			sheet.add_child(label)
	for _frame in range(3):
		await process_frame
		await RenderingServer.frame_post_draw
	var image := sheet.get_texture().get_image()
	if image == null or image.is_empty():
		print("ICON_BAKE_SHEET_FAILED reason=viewport readback failed")
	else:
		var save_error := image.save_png(_out_dir.path_join("sheet.png"))
		if save_error != OK:
			print("ICON_BAKE_SHEET_FAILED reason=", error_string(save_error))
		else:
			print("ICON_BAKE_SHEET_SAVED path=", _out_dir.path_join("sheet.png"))
	sheet.queue_free()
	_done()


func _done() -> void:
	print("ICON_BAKE_DONE saved=%d/%d" % [_saved, _entries.size()])
	quit(0)
