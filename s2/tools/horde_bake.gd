extends SceneTree
## 창 모드 전용. combat의 구운 몸을 읽어 최종 알베도 576칸을 만든다.
## godot --path s2 --rendering-method mobile -s res://tools/horde_bake.gd

const Horde = preload("res://game/world/horde_view.gd")
const BodyBake = preload("res://scripts/body_bake.gd")
const VatBaker = preload("res://scripts/vat_baker.gd")
const DeadBody = preload("res://game/actors/dead_body.gd")
const DeadCast = preload("res://game/actors/dead_cast.gd")
const Zombies = preload("res://game/actors/zombies.gd")
## 720 정방형 가운데에서 42×80칸을 자르는 기본 자리(발 x 21). 실제 자리는 (방향, 동작)마다
## 자세 쪽으로 옮기고(crop_shift_px) 그만큼 칸 안 발 x(foot_px_x)를 칸 표에 적는다 —
## 몸을 줄이거나 몰래 옮기는 것이 아니라 셰이더가 같은 값으로 되돌려 놓는다.
const CROP_ORIGIN := Vector2i(339, 320)

var _port: SubViewport
var _stage: Node3D
var _camera: Camera3D
var _atlas: Image
var _bounds: Array[Rect2i] = []
var _lengths: Array[float] = []
var _encode_srgb: bool = false
var _last_full_rect := Rect2i()
# --survey: 1차 재기만 하고 (방향, 동작)별 테두리·옮김을 찍는다(저장 안 함).
var _survey: bool = "--survey" in OS.get_cmdline_user_args()
var _unions: Array[Rect2i] = []


func _initialize() -> void:
	_run.call_deferred()


func _fail(reason: String) -> void:
	push_error("horde_bake: " + reason)
	quit(1)


func _run() -> void:
	if DisplayServer.get_name() == "headless" or RenderingServer.get_current_rendering_method() != "mobile":
		_fail("창 모드와 mobile 렌더러가 필요합니다.")
		return
	_atlas = Image.create(Horde.ATLAS_SIZE.x, Horde.ATLAS_SIZE.y, false, Image.FORMAT_RGBA8)
	_atlas.fill(Color(0, 0, 0, 0))
	_bounds.resize(Horde.DIRECTIONS * Horde.MOTIONS.size())
	_prepare_view()
	var gray: Image = await _gray_cell()
	var raw_gray: float = gray.get_pixel(20, 40).r
	var expected: float = Color(0.18, 0.18, 0.18).linear_to_srgb().r
	if absf(raw_gray - expected) < 0.015:
		_encode_srgb = false # 렌더 출력에 이미 sRGB 인코딩이 한 번 적용됨.
	elif absf(raw_gray - 0.18) < 0.015:
		_encode_srgb = true # 선형 캡처를 PNG로 쓰기 직전에 정확히 한 번 변환.
	else:
		_fail("회색 기준값 불일치: %.4f (선형 .18 또는 sRGB %.4f 필요)" % [raw_gray, expected])
		return
	_encode_image(gray)
	# 회색 기준은 48열 뒤 오른쪽 띠(GRAY_RECT)에 — 칸 가운데 32 px.
	_atlas.blit_rect(gray, Rect2i(Vector2i(floori(float(Horde.CELL.x - Horde.GRAY_RECT.size.x) * 0.5), 0), Horde.GRAY_RECT.size), Horde.GRAY_RECT.position)
	_unions.resize(Horde.DIRECTIONS * Horde.MOTIONS.size())
	var none: Array[int] = []
	if not await _pose_pass(true, none):
		return
	var shifts: Array[int] = []
	var foot_x: Array[float] = []
	for i: int in range(_unions.size()):
		var u: Rect2i = _unions[i]
		var lo: int = u.end.x - (Horde.CELL.x - 2)
		var hi: int = u.position.x - 2
		if lo > hi or u.position.y < 2 or u.end.y > Horde.CELL.y - 2:
			_fail("자세가 42×80칸 2px 여백에 안 들어감: 방향%d %s %s" % [floori(float(i) / float(Horde.MOTIONS.size())), Horde.MOTIONS[i % Horde.MOTIONS.size()], u])
			return
		var shift: int = clampi(roundi((u.position.x + u.end.x) * 0.5 - Horde.CELL.x * 0.5), lo, hi)
		shifts.append(shift)
		foot_x.append(Horde.FOOT.x - float(shift))
		if _survey:
			print("SURVEY 방향%d %s x %d..%d y %d..%d 옮김 %d 발x %.0f" % [floori(float(i) / float(Horde.MOTIONS.size())), Horde.MOTIONS[i % Horde.MOTIONS.size()], u.position.x, u.end.x, u.position.y, u.end.y, shift, Horde.FOOT.x - float(shift)])
	if _survey:
		print("SURVEY_DONE %d" % _unions.size())
		quit()
		return
	if not await _pose_pass(false, shifts):
		return
	var table: Dictionary = Horde.table_contract()
	var bounds_json: Array = []
	for rect: Rect2i in _bounds:
		bounds_json.append([rect.position.x, rect.position.y, rect.size.x, rect.size.y])
	table["bounds_px"] = bounds_json
	table["bounds_order"] = "direction * 4 + motion; union over all bodies and frames"
	table["bake_viewport_px"] = [Horde.REFERENCE_HEIGHT, Horde.REFERENCE_HEIGHT]
	table["crop_origin_px"] = [CROP_ORIGIN.x, CROP_ORIGIN.y]
	table["crop_shift_px"] = shifts
	table["foot_px_x"] = foot_x
	table["clip_lengths"] = _lengths
	table["clip_lengths_order"] = "body * 4 + motion"
	table["gray_reference"] = {"rect": [Horde.GRAY_RECT.position.x, Horde.GRAY_RECT.position.y, Horde.GRAY_RECT.size.x, Horde.GRAY_RECT.size.y], "linear": 0.18, "png_srgb": expected,
		"captured": raw_gray, "encode_after_capture": _encode_srgb, "runtime_sampler": "source_color"}
	table["alpha_padding_checked"] = true
	table["dilation"] = "nearest opaque RGB throughout each cell, original alpha retained"
	var folder: String = ProjectSettings.globalize_path("res://models/horde")
	if DirAccess.make_dir_recursive_absolute(folder) != OK:
		_fail("출력 폴더 생성 실패: " + folder)
		return
	if _atlas.save_png(folder.path_join("horde_atlas.png")) != OK:
		_fail("PNG 저장 실패")
		return
	var file: FileAccess = FileAccess.open(folder.path_join("horde_atlas.json"), FileAccess.WRITE)
	if file == null:
		_fail("칸 표 저장 실패")
		return
	file.store_string(JSON.stringify(table, "\t"))
	file.close()
	print("HORDE_BAKE 576칸, 회색 기준 1칸, ", folder)
	quit()


func _prepare_view() -> void:
	_port = SubViewport.new()
	_port.size = Vector2i(Horde.REFERENCE_HEIGHT, Horde.REFERENCE_HEIGHT)
	_port.own_world_3d = true
	_port.transparent_bg = true
	_port.debug_draw = Viewport.DEBUG_DRAW_UNSHADED
	_port.msaa_3d = Viewport.MSAA_DISABLED
	_port.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
	_port.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(_port)
	_stage = Node3D.new()
	_port.add_child(_stage)
	var world := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0, 0, 0, 0)
	environment.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	environment.tonemap_exposure = 1.0
	environment.adjustment_enabled = false
	environment.glow_enabled = false
	environment.fog_enabled = false
	world.environment = environment
	_stage.add_child(world)
	_camera = Camera3D.new()
	_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	_camera.keep_aspect = Camera3D.KEEP_HEIGHT
	_camera.size = Horde.CAM_SIZE
	_camera.near = 0.1
	_camera.far = 30.0
	_stage.add_child(_camera)
	var back: Vector3 = Horde.camera_back()
	var right: Vector3 = Vector3.UP.cross(back).normalized()
	var up: Vector3 = back.cross(right).normalized()
	var target: Vector3 = up * ((Horde.FOOT.y - float(Horde.CELL.y) * 0.5) / Horde.PX_PER_M)
	_camera.position = target + back * 10.0
	_camera.look_at(target, Vector3.UP)
	_camera.current = true
	# 최종 알베도만 굽는다. combat의 채움 방출·일시정지 색은 이 별도 도구에서 끈다.
	RenderingServer.global_shader_parameter_set("fx_fill", Vector4.ZERO)
	RenderingServer.global_shader_parameter_set("fx_fade", 0.0)


func _body_node(assets: Dictionary, body_index: int) -> MultiMeshInstance3D:
	var mesh: Mesh = assets["mesh"]
	var marked: bool = mesh.get_surface_count() > 0 and (mesh.surface_get_format(0) & Mesh.ARRAY_FORMAT_COLOR) != 0
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.use_colors = true
	mm.mesh = mesh
	mm.instance_count = 1
	mm.custom_aabb = AABB(Vector3(-3, -3, -3), Vector3(6, 6, 6))
	mm.set_instance_transform(0, Transform3D.IDENTITY)
	mm.set_instance_color(0, DeadCast.tear_of({"id": body_index + 1, "kind": "dead", "state": "wander"}, marked))
	var material := ShaderMaterial.new()
	material.shader = load("res://game/actors/dead_weathered.gdshader")
	material.set_shader_parameter("vat", assets["texture"])
	var tables: Dictionary = VatBaker.shader_tables(assets)
	for key: String in tables:
		material.set_shader_parameter(key, tables[key])
	material.set_shader_parameter("mixes", true)
	material.set_shader_parameter("cloth_state", DeadCast.CLOTH_STATE)
	material.set_shader_parameter("skin_tint", float(DeadCast.SKIN_TINT["dead"]))
	material.set_shader_parameter("skin_gone_least", float(DeadCast.SKIN_GONE_LEAST["dead"]))
	var tint: Color = Zombies.TINTS["dead"]
	material.set_shader_parameter("tint", Vector3(tint.r, tint.g, tint.b))
	var body := MultiMeshInstance3D.new()
	body.multimesh = mm
	body.material_override = material
	body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return body


func _gray_cell() -> Image:
	var gray := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(0.8, 0.8)
	gray.mesh = quad
	gray.transform = _camera.transform
	gray.position -= _camera.basis.z * 9.0
	var shader := Shader.new()
	shader.code = "shader_type spatial; render_mode unshaded, fog_disabled; void fragment() { ALBEDO = vec3(0.18); }"
	var material := ShaderMaterial.new()
	material.shader = shader
	gray.material_override = material
	_stage.add_child(gray)
	var picture: Image = await _capture()
	gray.free()
	return picture


func _capture(origin: Vector2i = CROP_ORIGIN) -> Image:
	await process_frame
	await RenderingServer.frame_post_draw
	var picture: Image = _port.get_texture().get_image()
	picture.convert(Image.FORMAT_RGBA8)
	_last_full_rect = picture.get_used_rect()
	return picture.get_region(Rect2i(origin, Horde.CELL))


func _encode_image(picture: Image) -> void:
	if not _encode_srgb:
		return
	for y: int in range(picture.get_height()):
		for x: int in range(picture.get_width()):
			picture.set_pixel(x, y, picture.get_pixel(x, y).linear_to_srgb())


static func _dilate(picture: Image) -> void:
	# 칸 안에서만 최근접 불투명 색을 전파한다. 알파/여백은 그대로 유지한다.
	var width: int = picture.get_width()
	var height: int = picture.get_height()
	var sources: Array[Vector2i] = []
	sources.resize(width * height)
	sources.fill(Vector2i(-1, -1))
	for y: int in range(height):
		for x: int in range(width):
			if picture.get_pixel(x, y).a > 0.5:
				sources[y * width + x] = Vector2i(x, y)
	# 작은 40×80 그림 안에서 실제 최근접 불투명 화소를 찾는다.
	var opaque: Array[Vector2i] = []
	for source: Vector2i in sources:
		if source.x >= 0:
			opaque.append(source)
	for y: int in range(height):
		for x: int in range(width):
			var original: Color = picture.get_pixel(x, y)
			if original.a > 0.0:
				continue
			var nearest := Vector2i(-1, -1)
			var best: int = 2147483647
			for source: Vector2i in opaque:
				var squared: int = (source - Vector2i(x, y)).length_squared()
				if squared < best:
					best = squared
					nearest = source
			if nearest.x >= 0:
				var colour: Color = picture.get_pixel(nearest.x, nearest.y)
				picture.set_pixel(x, y, Color(colour.r, colour.g, colour.b, original.a))


func _store_cell(index: int, picture: Image) -> void:
	var origin := Vector2i((index % Horde.COLUMNS) * Horde.CELL.x, int(floor(float(index) / float(Horde.COLUMNS))) * Horde.CELL.y)
	_atlas.blit_rect(picture, Rect2i(Vector2i.ZERO, Horde.CELL), origin)


## measure: 기본 자리로 찍어 (방향, 동작)별 실제 테두리만 모은다(_unions). 아니면 shifts만큼 옮긴 자리로 굽는다.
func _pose_pass(measure: bool, shifts: Array[int]) -> bool:
	for body_index: int in range(Horde.BODIES.size()):
		var body_folder: String = DeadCast.ROOT + Horde.BODIES[body_index]
		var assets: Dictionary = DeadBody.with_albedo(BodyBake.load_baked(body_folder), body_folder)
		if assets.is_empty() or not assets.get("albedo") is Texture2D or not assets.get("skin") is Texture2D:
			_fail("몸·알베도·피부 마스크 누락: " + body_folder)
			return false
		var clips: Array = assets["clips"]
		var selected: Array[int] = Horde.clip_indices(clips)
		if selected.size() != Horde.MOTIONS.size():
			_fail("clips.json 이름/길이 오류: " + body_folder)
			return false
		if not measure:
			for clip_index: int in selected:
				_lengths.append(float(clips[clip_index]["length"]))
		var body: MultiMeshInstance3D = _body_node(assets, body_index)
		_stage.add_child(body)
		for direction: int in range(Horde.DIRECTIONS):
			var theta: float = Horde.camera_theta() + Horde.THETA_ZERO + TAU * float(direction) / float(Horde.DIRECTIONS)
			body.multimesh.set_instance_transform(0, Transform3D(Basis(Vector3.UP, theta), Vector3.ZERO))
			for motion: int in range(Horde.MOTIONS.size()):
				var i: int = direction * Horde.MOTIONS.size() + motion
				var origin: Vector2i = CROP_ORIGIN if measure else CROP_ORIGIN + Vector2i(shifts[i], 0)
				for frame: int in range(Horde.FRAMES):
					body.multimesh.set_instance_custom_data(0, Color(float(frame) / float(Horde.FRAMES), VatBaker.pack_motion(selected[motion]), 1.0, 1.0))
					var picture: Image = await _capture(origin)
					# 잘라낸 그림만 보면 화면 밖으로 잘린 팔을 놓친다. 전체 렌더 경계를 검사한다.
					var rect := Rect2i(_last_full_rect.position - origin, _last_full_rect.size)
					if not rect.has_area():
						_fail("빈 그림: %s %s 방향%d 틀%d" % [Horde.BODIES[body_index], Horde.MOTIONS[motion], direction, frame])
						return false
					if measure:
						_unions[i] = _unions[i].merge(rect) if _unions[i].has_area() else rect
						continue
					if not Rect2i(2, 2, Horde.CELL.x - 4, Horde.CELL.y - 4).encloses(rect):
						_fail("42×80 칸의 2px 여백 초과: %s %s 방향%d 틀%d %s" % [Horde.BODIES[body_index], Horde.MOTIONS[motion], direction, frame, rect])
						return false
					_bounds[i] = _bounds[i].merge(rect) if _bounds[i].has_area() else rect
					_encode_image(picture)
					_dilate(picture)
					_store_cell(Horde.atlas_index(body_index, direction, motion, frame), picture)
		body.free()
		assets.clear()
	return true
