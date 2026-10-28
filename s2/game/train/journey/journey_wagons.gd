extends Node3D
## 「곁 선로의 버려진 빈 화차 줄」 (결정 495 2절): a short siding by a village with a
## string of wagons left standing on it, snowed on as the stretch's snow lies — open
## wagons with coal or empty, flat wagons, now and then a cold tender; never a closed
## wagon, never anyone in or by them, nothing knocking (presentation_motion.md 7b 「옆
## 선로의 화차는 비었거나 석탄·짐만」, 정차 장면 금지선). The far side of the line only,
## so it never stands between the camera and the cars. The train's model kit draws
## them (train_model_kit.gd attach_wagons, as the field's side lines). In the land's frame.

const TrainModels = preload("res://game/world/train_model_kit.gd")
const MapView = preload("res://game/world/map_view.gd")
const PropModels = preload("res://game/world/prop_models.gd")
const Kit = preload("res://game/train/journey/journey_kit.gd")

## The siding's middle across the line (the far side) and its wagons by variant.
const SIDING_Z: float = -4.5
const STRINGS: Dictionary = {
	"coal": ["wagon_coal", "wagon_coal", "wagon_open", "wagon_coal", "wagon_coal", "wagon_coal"],
	"flats": ["wagon_flat", "wagon_flat", "wagon_flat", "wagon_open", "wagon_flat"],
	"mixed": ["wagon_open", "wagon_coal", "wagon_flat", "wagon_tender", "wagon_open", "wagon_coal", "wagon_flat"],
}
const LENGTH: Dictionary = {"wagon_coal": 10, "wagon_open": 10, "wagon_flat": 12, "wagon_tender": 6}
const LIFE_S: float = 60.0

var journey: Node3D
var age: float = 0.0
var length: float = 0.0
var rng := RandomNumberGenerator.new()
var _done: bool = false


func begin(j: Node3D, ev: Dictionary, seed_value: int) -> void:
	journey = j
	rng.seed = seed_value
	name = "Wagons"
	var kinds: Array = (STRINGS.get(String(ev.get("variant", "coal")), STRINGS["coal"]) as Array).duplicate()
	var n: int = rng.randi_range(3, kinds.size())
	var wagons: Array = []
	var x: int = rng.randi_range(4, 14)
	for i in n:
		var kind: String = String(kinds[i])
		var l: int = int(LENGTH.get(kind, 10))
		# The model kit picks the model by name and coal (train_model_kit.gd wagon_kind).
		var w := {"rect": Rect2i(x, int(round(SIDING_Z - 1.5)), l, 3), "coal": 1.0 if kind == "wagon_coal" else 0.0,
			"name": "탄수차" if kind == "wagon_tender" else ("평판 화차" if kind == "wagon_flat" else "빈 화차")}
		wagons.append(w)
		x += l + rng.randi_range(1, 3)
		if rng.randf() < 0.18 and i < n - 1:
			x += rng.randi_range(8, 20)   # a gap where one was taken away
	length = float(x) + 10.0
	_lay_siding(length)
	var heights: Array = []
	heights.resize(wagons.size())
	heights.fill(0.0)
	TrainModels.attach_wagons(self, wagons, heights)
	advance(0.0, 0.0)


func is_done() -> bool:
	return _done


func advance(delta: float, _travelled: float) -> void:
	age += delta
	if journey == null:
		return
	var land: Node3D = journey.get("land")
	var tail_x: float = land.position.x + position.x + length
	if age >= LIFE_S or (age > 2.0 and tail_x < -70.0):
		_done = true


## The siding under them: its bed, sleepers and rails, the buffer stop at the end.
func _lay_siding(run: float) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var bed := Color(0.31, 0.3, 0.28)
	MapView.box(st, Vector3(run + 4.0, absf(Kit.FIELD_Y) - 0.2, 3.4), Vector3(run * 0.5, (Kit.FIELD_Y - 0.2) * 0.5, SIDING_Z), bed)
	var x: float = 0.0
	while x < run + 2.0:
		MapView.box(st, Vector3(0.24, 0.1, 2.4), Vector3(x, -0.15, SIDING_Z), Color(0.22, 0.19, 0.17))
		x += 0.7
	for z: float in [SIDING_Z - 0.72, SIDING_Z + 0.72]:
		MapView.box(st, Vector3(run + 2.0, 0.13, 0.08), Vector3(run * 0.5 + 1.0, -0.065, z), Color(0.3, 0.26, 0.22))
	var node := MeshInstance3D.new()
	node.name = "Siding"
	node.mesh = st.commit()
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.vertex_color_is_srgb = true
	mat.roughness = 1.0
	node.material_override = mat
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(node)
	var stop: Mesh = Kit.mesh_of("buffer_stop")
	if stop != null:
		var b := MeshInstance3D.new()
		b.name = "BufferStop"
		b.mesh = stop
		b.transform = Transform3D(Basis(Vector3.UP, PI * 0.5).scaled(Vector3.ONE * 1.4), Vector3(run + 1.5, -0.2, SIDING_Z))
		add_child(b)
