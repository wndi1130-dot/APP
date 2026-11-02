extends SceneTree
## PC 창 모드: 같은 첫 정차/시험 벽의 낮·어스름·밤·눈 켬/끔 그림.
## godot --path s2 --rendering-method mobile --resolution 1280x720 -s res://tools/horde_shots.gd -- --out=<폴더> [--horde=off]

const FieldGame = preload("res://game/field_game.gd")
const FieldMaps = preload("res://game/world/field_maps.gd")
const FxState = preload("res://fx/fx_state.gd")
const Horde = preload("res://game/world/horde_view.gd")
const SCENES: Array[Dictionary] = [
	{"name": "day", "hour": 12.0, "cold": 0.0, "weather": ["clear"]},
	{"name": "dusk", "hour": 16.1667, "cold": 0.0, "weather": ["clear"]},
	{"name": "night", "hour": 19.0, "cold": 0.0, "weather": ["clear"]},
	{"name": "snow", "hour": 12.0, "cold": 0.8, "weather": ["snow"]},
]

var _out: String = ""
var _enabled: bool = true
var _index: Array[Dictionary] = []


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
	# 그림은 모서리 벽 바로 앞. 필드의 카메라 경계 제한과 무관한 고정 구도.
	var aim := Vector3(9.0, 0.0, 9.0)
	game.camera.size = 24.0
	game.camera.position = aim + FieldGame.cam_back() * 60.0
	game.camera.look_at(aim, Vector3.UP)
	if _enabled:
		_gray_pair(game.camera)
	var cloud: Vector4 = game.fx_params.get("fx_cloud", Vector4.ZERO)
	FxState.apply({"fx_cloud": Vector4(cloud.x, 0.0, 0.0, cloud.w)})
	await create_timer(1.5).timeout
	await RenderingServer.frame_post_draw
	var name_tag: String = "horde_%s_%s" % [scene["name"], "on" if _enabled else "off"]
	var picture: Image = root.get_texture().get_image()
	var error: Error = picture.save_png(_out.path_join(name_tag + ".png"))
	_index.append({"shot": name_tag, "scene": scene, "horde": _enabled,
		"stats": horde.get("stats") if horde != null else {}, "camera_size": 24.0,
		"camera_pitch": FieldGame.CAM_PITCH, "camera_yaw": FieldGame.CAM_YAW,
		"test_walls": "north wall_sheet 3.0m / west wall_stack 5.2m; each 24m", "mask": false})
	game.queue_free()
	await process_frame
	if error != OK:
		push_error("horde_shots: PNG 저장 실패: " + error_string(error))
	return error == OK


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
