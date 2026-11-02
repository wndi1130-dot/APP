extends SceneTree
## PC 창 모드: 같은 첫 정차/시험 벽의 낮·어스름·밤·눈·폭풍 켬/끔 그림.
## godot --path s2 --rendering-method mobile --resolution 1280x720 -s res://tools/horde_shots.gd -- --out=<폴더> [--horde=off] [--fill=off]

const FieldGame = preload("res://game/field_game.gd")
const FieldMaps = preload("res://game/world/field_maps.gd")
const FxState = preload("res://fx/fx_state.gd")
const Horde = preload("res://game/world/horde_view.gd")
const BodyBake = preload("res://scripts/body_bake.gd")
const VatBaker = preload("res://scripts/vat_baker.gd")
const DeadBody = preload("res://game/actors/dead_body.gd")
const DeadCast = preload("res://game/actors/dead_cast.gd")
const Zombies = preload("res://game/actors/zombies.gd")
const SCENES: Array[Dictionary] = [
	{"name": "day", "hour": 12.0, "cold": 0.0, "weather": ["clear"]},
	{"name": "dusk", "hour": 16.1667, "cold": 0.0, "weather": ["clear"]},
	{"name": "night", "hour": 19.0, "cold": 0.0, "weather": ["clear"]},
	{"name": "snow", "hour": 12.0, "cold": 0.8, "weather": ["snow"]},
	{"name": "blizzard", "hour": 12.0, "cold": 1.0, "weather": ["blizzard"]},
]

var _out: String = ""
var _enabled: bool = true
var _fill_enabled: bool = true
var _index: Array[Dictionary] = []
var _comparison: Dictionary = {}


func _initialize() -> void:
	_run.call_deferred()


static func test_walls() -> Array:
	return [
		{"id": "h1_north_sheet", "a": Vector2(4, 0), "b": Vector2(28, 0), "out": Vector2(0, -1), "kind": "wall_sheet", "height": 3.0},
		{"id": "h1_west_stack", "a": Vector2(0, 4), "b": Vector2(0, 28), "out": Vector2(-1, 0), "kind": "wall_stack", "height": 5.2},
	]


func _run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--out="):
			_out = argument.substr(6)
		elif argument == "--horde=off":
			_enabled = false
		elif argument == "--fill=off":
			_fill_enabled = false
	if _out.is_empty() or DisplayServer.get_name() == "headless" or RenderingServer.get_current_rendering_method() != "mobile":
		push_error("horde_shots: mobile 렌더러의 창 모드와 --out=<폴더>가 필요합니다.")
		quit(1)
		return
	if _enabled and (Horde.read_table().is_empty() or not ResourceLoader.exists(Horde.ATLAS_PATH)):
		push_error("horde_shots: 먼저 horde_bake를 실행하고 PNG를 가져오세요.")
		quit(1)
		return
	if DirAccess.make_dir_recursive_absolute(_out) != OK:
		push_error("horde_shots: 출력 폴더를 만들 수 없습니다.")
		quit(1)
		return
	await process_frame
	for scene: Dictionary in SCENES:
		if not await _shot(scene):
			quit(1)
			return
	var file: FileAccess = FileAccess.open(_out.path_join("index.json"), FileAccess.WRITE)
	if file == null:
		push_error("horde_shots: index.json 저장 실패")
		quit(1)
		return
	file.store_string(JSON.stringify(_index, "\t"))
	file.close()
	quit()


func _shot(scene: Dictionary) -> bool:
	var game: FieldGame = FieldGame.new()
	var map_data: Dictionary = FieldMaps.build("", "K1")
	game.opts = {"seed": 5, "raiders": false, "auto_pause": false, "arrive": false,
		"weather": scene["weather"], "look": scene["weather"], "cold": scene["cold"],
		"side": 0.0, "look_hour": scene["hour"], "region": "K1", "map_data": map_data,
		"test_edge_walls": test_walls(), "perf": {"horde": _enabled}}
	root.add_child(game)
	while not game.is_built:
		await process_frame
	var horde: Node = game.get_node_or_null("HordeView")
	if _enabled and (horde == null or not bool((horde.get("stats") as Dictionary).get("ready", false))):
		push_error("horde_shots: 무리 생성 실패. 빈 그림을 성공으로 저장하지 않습니다.")
		game.queue_free()
		await process_frame
		return false
	game.paused = true
	game.hud.visible = false
	game.clock.elapsed = maxf(float(scene["hour"]) - 10.5, 0.0) * 240.0
	game.player.position = Vector3(5.0, 0.0, 5.0)
	game.cam_push = Vector3(4.0, 0.0, 4.0)
	game.mask_on = false
	game.view.set_mask_enabled(false)
	_fixture_walls(game)
	for _frame: int in range(4):
		await process_frame
	game.paused = false
	game.set_process(false)
	game.fx_params["fx_fade"] = 0.0
	FxState.apply({"fx_fade": 0.0})
	game._update_light()
	var fill: Vector4 = game.fx_params.get("fx_fill", Vector4.ZERO)
	fill.w = 1.0 if _fill_enabled else 0.0
	game.fx_params["fx_fill"] = fill
	FxState.apply({"fx_fill": fill})
	# 그림은 모서리 벽 바로 앞. 필드의 카메라 경계 제한과 무관한 고정 구도.
	var aim := Vector3(9.0, 0.0, 9.0)
	game.camera.size = 24.0
	game.camera.position = aim + FieldGame.cam_back() * 60.0
	game.camera.look_at(aim, Vector3.UP)
	if _enabled:
		_gray_pair(game.camera)
		if not _comparison_pair(game):
			game.queue_free()
			await process_frame
			return false
	var cloud: Vector4 = game.fx_params.get("fx_cloud", Vector4.ZERO)
	FxState.apply({"fx_cloud": Vector4(cloud.x, 0.0, 0.0, cloud.w)})
	await create_timer(1.5).timeout
	await RenderingServer.frame_post_draw
	var name_tag: String = "horde_%s_%s" % [scene["name"], "on" if _enabled else "off"]
	if not _fill_enabled:
		name_tag += "_fill_off"
	var picture: Image = root.get_texture().get_image()
	var error: Error = picture.save_png(_out.path_join(name_tag + ".png"))
	_index.append({"shot": name_tag, "scene": scene, "horde": _enabled,
		"stats": horde.get("stats") if horde != null else {}, "camera_size": 24.0,
		"camera_pitch": FieldGame.CAM_PITCH, "camera_yaw": FieldGame.CAM_YAW,
		"test_walls": "north wall_sheet 3.0m / west wall_stack 5.2m; each 24m", "mask": false,
		"comparison": _comparison if _enabled else {}, "fill": game.fx_params.get("fx_fill", Vector4.ZERO)})
	game.queue_free()
	await process_frame
	if error != OK:
		push_error("horde_shots: PNG 저장 실패: " + error_string(error))
	return error == OK


static func _card_hash(seed: float, lane: int) -> float:
	# horde_far.person_hash의 uint32 흐름. 같은 몸과 크기를 VAT에 적용한다.
	var bits: int = int(seed * 16777216.0) ^ ((lane * 374761393) & 0xffffffff)
	bits = ((bits ^ (bits >> 13)) * 1274126177) & 0xffffffff
	bits = bits ^ (bits >> 16)
	return float(bits & 16777215) / 16777216.0


func _comparison_pair(game: Node3D) -> bool:
	var seed: float = 0.5
	var body_index: int = mini(int(floor(_card_hash(seed, 1) * 3.0)), 2)
	var size: float = lerpf(0.92, 1.08, _card_hash(seed, 3))
	var folder: String = DeadCast.ROOT + Horde.BODIES[body_index]
	var assets: Dictionary = DeadBody.with_albedo(BodyBake.load_baked(folder), folder)
	var table: Dictionary = Horde.read_table()
	if assets.is_empty() or not assets.get("albedo") is Texture2D or not assets.get("skin") is Texture2D or table.is_empty():
		push_error("horde_shots: 비교 몸/알베도/피부/칸 표 누락: " + folder)
		return false
	var selected: Array[int] = Horde.clip_indices(assets["clips"])
	if selected.size() != Horde.MOTIONS.size():
		push_error("horde_shots: 비교 동작 이름 누락")
		return false
	var theta: float = Horde.camera_theta()
	var right: Vector3 = Vector3.UP.cross(Horde.camera_back()).normalized()
	# 지도 밖 모서리의 빈 통로. 원래 북/서 벽의 유한 끝에 가리지 않는다.
	var center := Vector3(-1.8, 0.0, -1.8)
	var vat_at: Vector3 = center - right
	var card_at: Vector3 = center + right
	var mesh: Mesh = assets["mesh"]
	var marked: bool = mesh.get_surface_count() > 0 and (mesh.surface_get_format(0) & Mesh.ARRAY_FORMAT_COLOR) != 0
	var vat := MultiMesh.new()
	vat.transform_format = MultiMesh.TRANSFORM_3D
	vat.use_colors = true
	vat.use_custom_data = true
	vat.mesh = mesh
	vat.instance_count = 1
	vat.custom_aabb = AABB(center - Vector3(4, 3, 4), Vector3(8, 8, 8))
	vat.set_instance_transform(0, Transform3D(Basis(Vector3.UP, theta).scaled(Vector3.ONE * size), vat_at))
	vat.set_instance_color(0, DeadCast.tear_of({"id": body_index + 1, "kind": "dead", "state": "wander"}, marked))
	vat.set_instance_custom_data(0, Color(0.0, VatBaker.pack_motion(selected[1]), 1.0, 1.0))
	var vat_mat := ShaderMaterial.new()
	vat_mat.shader = load("res://game/actors/dead_weathered.gdshader")
	vat_mat.set_shader_parameter("vat", assets["texture"])
	var tables: Dictionary = VatBaker.shader_tables(assets)
	for key: String in tables:
		vat_mat.set_shader_parameter(key, tables[key])
	vat_mat.set_shader_parameter("mixes", true)
	vat_mat.set_shader_parameter("cloth_state", DeadCast.CLOTH_STATE)
	vat_mat.set_shader_parameter("skin_tint", float(DeadCast.SKIN_TINT["dead"]))
	vat_mat.set_shader_parameter("skin_gone_least", float(DeadCast.SKIN_GONE_LEAST["dead"]))
	var tint: Color = Zombies.TINTS["dead"]
	vat_mat.set_shader_parameter("tint", Vector3(tint.r, tint.g, tint.b))
	var near_draw := MultiMeshInstance3D.new()
	near_draw.name = "ComparisonVAT"
	near_draw.multimesh = vat
	near_draw.material_override = vat_mat
	near_draw.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	game.add_child(near_draw)
	var card := MultiMesh.new()
	card.transform_format = MultiMesh.TRANSFORM_3D
	card.use_custom_data = true
	card.mesh = QuadMesh.new()
	card.instance_count = 1
	card.set_instance_transform(0, Transform3D(Basis.IDENTITY, card_at))
	card.set_instance_custom_data(0, Color(0.0, 1.0, theta / TAU, seed))
	var people: Array[Dictionary] = [{"position": card_at}]
	card.custom_aabb = Horde.card_aabb(people)
	var card_mat := ShaderMaterial.new()
	card_mat.shader = load("res://fx/shaders/horde_far.gdshader")
	card_mat.set_shader_parameter("atlas", load(Horde.ATLAS_PATH))
	var rects := PackedVector4Array()
	for rect: Array in table["bounds_px"]:
		rects.append(Vector4(rect[0], rect[1], rect[2], rect[3]))
	card_mat.set_shader_parameter("bounds_px", rects)
	card_mat.set_shader_parameter("clip_lengths", PackedFloat32Array(table["clip_lengths"]))
	card_mat.set_shader_parameter("camera_pitch", deg_to_rad(Horde.CAM_PITCH))
	card_mat.set_shader_parameter("comparison_hold", true)
	card_mat.set_shader_parameter("mask_on", 0.0)
	card_mat.set_shader_parameter("wall_a", Vector2(-6, -6))
	card_mat.set_shader_parameter("wall_b", Vector2(-1, -6))
	card_mat.set_shader_parameter("wall_out", Vector2(0, 1))
	var far_draw := MultiMeshInstance3D.new()
	far_draw.name = "ComparisonCard"
	far_draw.multimesh = card
	far_draw.material_override = card_mat
	far_draw.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	game.add_child(far_draw)
	var toward: Vector3 = Vector3(Horde.camera_back().x, 0.0, Horde.camera_back().z).normalized()
	var wall_mesh := BoxMesh.new()
	wall_mesh.size = Vector3(5.0, 3.0, 0.18)
	var wall := MeshInstance3D.new()
	wall.mesh = wall_mesh
	wall.position = center - toward * 1.8 + Vector3.UP * 1.5
	wall.rotation.y = theta
	var wall_mat := StandardMaterial3D.new()
	wall_mat.albedo_color = Color(0.24, 0.25, 0.27)
	wall.material_override = wall_mat
	game.add_child(wall)
	_comparison = {"body": Horde.BODIES[body_index], "motion": "stagger", "frame": 0,
		"theta": theta, "scale": size, "vat_position": vat_at, "card_position": card_at,
		"depth_difference": (card_at - vat_at).dot(-Horde.camera_back()), "left": "VAT", "right": "card"}
	return true


func _gray_pair(camera: Camera3D) -> void:
	# 화면 오른쪽 위: 왼쪽은 PNG+source_color, 오른쪽은 선형 .18 직접 출력.
	# 같아야 sRGB 저장/디코딩이 한 번씩이다. 두 칸 모두 빛/안개를 받지 않는다.
	for side: int in range(2):
		var quad := QuadMesh.new()
		quad.size = Vector2(0.8, 0.8)
		var swatch := MeshInstance3D.new()
		swatch.mesh = quad
		swatch.position = Vector3(18.0 + float(side), 10.0, -5.0)
		swatch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var shader := Shader.new()
		shader.code = "shader_type spatial; render_mode unshaded, fog_disabled; uniform sampler2D atlas : source_color, filter_nearest; void fragment() { ALBEDO = " + ("texture(atlas, vec2(620.0/2048.0, 920.0/1024.0)).rgb" if side == 0 else "vec3(0.18)") + "; }"
		var material := ShaderMaterial.new()
		material.shader = shader
		if side == 0:
			material.set_shader_parameter("atlas", load(Horde.ATLAS_PATH))
		swatch.material_override = material
		camera.add_child(swatch)


func _fixture_walls(game: Node3D) -> void:
	# 지도 줄기의 실제 자산이 오기 전, 깊이 가림을 볼 민간 철판/컨테이너 시험 모형.
	for wall: Dictionary in test_walls():
		var a: Vector2 = wall["a"]
		var b: Vector2 = wall["b"]
		var height: float = wall["height"]
		var material := StandardMaterial3D.new()
		material.albedo_color = Color(0.24, 0.25, 0.27) if wall["kind"] == "wall_sheet" else Color(0.23, 0.20, 0.21)
		material.roughness = 0.95
		var levels: int = 1 if wall["kind"] == "wall_sheet" else 2
		var parts: int = 12 if levels == 1 else 3
		var segment: Vector2 = (b - a) / float(parts)
		for part: int in range(parts):
			for level: int in range(levels):
				var mesh := BoxMesh.new()
				mesh.size = Vector3(segment.length() - 0.02, height / float(levels) - 0.01, 0.18 if levels == 1 else 1.4)
				var draw := MeshInstance3D.new()
				draw.mesh = mesh
				draw.material_override = material
				var center: Vector2 = a + segment * (float(part) + 0.5)
				draw.position = Vector3(center.x, (float(level) + 0.5) * height / float(levels), center.y)
				draw.rotation.y = -atan2(segment.y, segment.x)
				game.add_child(draw)
