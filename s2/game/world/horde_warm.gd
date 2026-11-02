extends Node3D
## 부팅 무리 데우기: 첫 정차의 무리가 치르던 아틀라스 첫 읽기와 셰이더·그리기 파이프라인 첫 컴파일을
## 부팅 메뉴가 떠 있는 동안으로 옮긴다. 읽은 셰이더·아틀라스는 HordeView가 정차 사이에 붙잡아 두는
## 자리(_shader_kept·_atlas_kept)에 넣고, 메뉴 뒤(필드 카메라가 닿지 않는 자리)에서 무리 한 장을
## 숨은 카메라로 DRAW_FRAMES 동안 그려 첫 그림 컴파일까지 끝낸다. 필드와 같은 화면(루트 뷰포트)이라
## 같은 화면 형식으로 컴파일된다. 그사이 다른 카메라(필드)가 켜져 있으면 그리지 않고 읽기만 한다.
## 무리 꺼짐(horde false)·데우기 꺼짐(horde_warm false, 폰 재기의 끔 판)이면 아무것도 읽지 않는다.

const Horde = preload("res://game/world/horde_view.gd")
const DRAW_FRAMES: int = 2 # 첫 프레임에 컴파일, 하나 더는 그 그림이 실제로 나간 뒤에 거두려고
const WAIT_FRAMES: int = 900 # 읽기를 기다리는 상한(30 fps 30초). 넘기면 받지 않고 수거 목록에 넘긴다.
const RIG_AT := Vector3(0.0, -500.0, 0.0) # 필드 카메라에 들지 않는 자리

static var last_stats: Dictionary = {} # 끝난 데우기의 결과(시험·로그용)
static var warmed: bool = false # 한 번 그려 데웠으면 다시 부팅해도 되풀이하지 않는다

var stats: Dictionary = {}
var _open: Dictionary = {} # 요청하고 아직 get하지 않은 경로(요청 하나에 get 하나)
var _started_usec: int = 0
var _frames: int = 0
var _draw_frames: int = 0
var _rig: Node3D
var _camera: Camera3D
var _report_switch: bool = false
var _done: bool = false


## boot._ready에서 한 줄. settings는 폰 성능 스위치(안드로이드만 읽음, 그 밖은 {}).
static func start(parent: Node, settings: Dictionary) -> Node:
	if settings.get("horde") is bool and not bool(settings["horde"]):
		return null # 무리 꺼짐: 자원도 노드도 없다(필드가 {"horde": false} 줄을 찍는다).
	var asked: Variant = settings.get("horde_warm")
	if asked is bool and not bool(asked):
		print("PERF_SWITCH ", {"horde_warm": false})
		return null
	if warmed and Horde._shader_kept != null and Horde._atlas_kept != null:
		return null
	var node: Node3D = (load("res://game/world/horde_warm.gd") as GDScript).new()
	node.name = "HordeWarm"
	node.set("_report_switch", asked is bool)
	parent.add_child(node)
	return node


func _ready() -> void:
	_started_usec = Time.get_ticks_usec()
	stats = {"atlas": false, "shader": false, "drawn": false, "frames": 0, "ms": 0.0, "reason": ""}
	for path: String in [Horde.ATLAS_PATH, Horde.SHADER_PATH]:
		Horde.resource_reads += 1
		if ResourceLoader.load_threaded_request(path) == OK:
			_open[path] = true


func _process(_delta: float) -> void:
	if _done:
		return
	_frames += 1
	if not _open.is_empty():
		_collect()
		if not _open.is_empty():
			if _frames >= WAIT_FRAMES:
				_finish("load timeout")
			return
	if _rig == null:
		if not bool(stats["atlas"]) or not bool(stats["shader"]):
			_finish("asset error")
		elif get_viewport().get_camera_3d() != null:
			_finish("another camera is up; read only")
		else:
			_build_rig()
		return
	if get_viewport().get_camera_3d() != _camera:
		_finish("camera taken before drawn")
		return
	_draw_frames += 1
	if _draw_frames >= DRAW_FRAMES:
		stats["drawn"] = true
		_finish("")


func _collect() -> void:
	for path: String in _open.keys():
		if ResourceLoader.load_threaded_get_status(path) == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			continue
		var asset: Resource = ResourceLoader.load_threaded_get(path)
		_open.erase(path)
		if path == Horde.ATLAS_PATH:
			var atlas: Texture2D = asset as Texture2D
			if atlas != null and atlas.get_size() == Vector2(Horde.ATLAS_SIZE):
				Horde._atlas_kept = atlas
				stats["atlas"] = true
		elif asset is Shader:
			Horde._shader_kept = asset
			stats["shader"] = true


## 숨은 카메라와 무리 카드 하나: 짓기와 같은 메시·재질(칸 표까지)이라 같은 셰이더 변형이 컴파일된다.
func _build_rig() -> void:
	_rig = Node3D.new()
	_rig.name = "WarmRig"
	_rig.position = RIG_AT
	add_child(_rig)
	var mat := ShaderMaterial.new()
	mat.shader = Horde._shader_kept
	mat.set_shader_parameter("atlas", Horde._atlas_kept)
	var table: Dictionary = Horde.read_table_result()["table"]
	if not table.is_empty():
		Horde.configure_card(mat, table)
	mat.set_shader_parameter("wall_a", Vector2.ZERO)
	mat.set_shader_parameter("wall_b", Vector2(1.0, 0.0))
	mat.set_shader_parameter("wall_out", Vector2(0.0, -1.0))
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.mesh = Horde.card_mesh()
	mm.instance_count = 1
	mm.set_instance_transform(0, Transform3D.IDENTITY)
	mm.set_instance_custom_data(0, Color(0.5, 1.0, 0.0, 0.5))
	mm.custom_aabb = AABB(Vector3(-2.0, -2.0, -2.0), Vector3(4.0, 4.0, 4.0))
	var draw := MultiMeshInstance3D.new()
	draw.name = "WarmCard"
	draw.multimesh = mm
	draw.material_override = mat
	draw.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_rig.add_child(draw)
	_camera = Camera3D.new()
	_camera.name = "WarmCamera"
	_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	_camera.size = Horde.CAM_SIZE
	_rig.add_child(_camera)
	_camera.look_at_from_position(RIG_AT + Horde.camera_back() * 30.0, RIG_AT, Vector3.UP)
	_camera.current = true


func _finish(reason: String, freeing: bool = false) -> void:
	_done = true
	set_process(false)
	stats["reason"] = reason
	stats["frames"] = _frames
	stats["ms"] = snappedf(float(Time.get_ticks_usec() - _started_usec) / 1000.0, 0.1)
	# 다 받지 못한 요청은 무리 짓기와 같은 수거 목록으로(요청 하나에 get 하나).
	for path: String in _open:
		Horde._orphan_paths.append(path)
	_open.clear()
	if not Horde._orphan_paths.is_empty():
		Horde._reap_orphans()
	if bool(stats["drawn"]):
		warmed = true
	last_stats = stats.duplicate()
	print("HORDE_WARM ", stats)
	if _report_switch:
		print("PERF_SWITCH ", {"horde_warm": true, "ok": bool(stats["drawn"]), "atlas": stats["atlas"], "shader": stats["shader"],
			"ms": stats["ms"], "reason": reason})
	if freeing:
		return
	if is_instance_valid(_camera):
		_camera.current = false
	queue_free()


func _notification(what: int) -> void:
	# 부팅이 먼저 지워져도(이어 하기로 바로 필드) 등록한 읽기는 수거 목록으로, 결과 줄은 한 번.
	if what == NOTIFICATION_PREDELETE and not _done:
		_finish("freed before warm end", true)
