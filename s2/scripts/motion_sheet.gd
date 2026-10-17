extends Node3D
## Test branch only: every baked motion of the two bodies frozen at its start,
## middle and end, side by side under the field camera's 52 degree pitch, so the
## phone can be photographed. Pages turn every PAGE_SECONDS and print a logcat
## line (MOTIONSHEET) as each one is shown.

const BodyBake = preload("res://scripts/body_bake.gd")
const VatBaker = preload("res://scripts/vat_baker.gd")
const DeadBody = preload("res://game/actors/dead_body.gd")

const BODIES := [["tracksuit", "res://models/people/n3-body_tracksuit"], ["seamstress", "res://models/people/n5-crew_seamstress"]]
const PER_PAGE: int = 5
const GAP_X: float = 1.9
const GAP_Z: float = 2.4
const PAGE_SECONDS: float = 5.0
const YAW: float = 35.0

var pages: Array = []       # [body index, first clip]
var page: int = -1
var holder: Node3D
var cam: Camera3D
var title: Label


func _ready() -> void:
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.32, 0.34, 0.37)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.55, 0.58, 0.62)
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, 30, 0)
	add_child(sun)
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(60, 60)
	ground.mesh = plane
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color(0.72, 0.74, 0.78)
	ground.material_override = gm
	add_child(ground)
	cam = Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 6.6
	cam.rotation_degrees = Vector3(-52, 0, 0)
	add_child(cam)
	var ui := CanvasLayer.new()
	add_child(ui)
	title = Label.new()
	title.position = Vector2(24, 16)
	title.add_theme_font_size_override("font_size", 34)
	ui.add_child(title)
	for b in BODIES.size():
		var vat := _vat(b)
		if vat.is_empty():
			continue
		var n: int = vat["clips"].size()
		for first in range(0, n, PER_PAGE):
			pages.append([b, first])
	_next()


func _vat(b: int) -> Dictionary:
	return DeadBody.with_albedo(BodyBake.load_baked(BODIES[b][1]), BODIES[b][1])


func _next() -> void:
	page += 1
	if page >= pages.size():
		page = 0
	_show(pages[page][0], pages[page][1])
	get_tree().create_timer(PAGE_SECONDS).timeout.connect(_next)


func _show(b: int, first: int) -> void:
	if holder != null:
		holder.queue_free()
	holder = Node3D.new()
	add_child(holder)
	var vat := _vat(b)
	var clips: Array = vat["clips"]
	var last := mini(first + PER_PAGE, clips.size())
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.mesh = vat["mesh"]
	mm.instance_count = (last - first) * 3
	mm.custom_aabb = AABB(Vector3(-20, -5, -20), Vector3(40, 10, 40))
	var names := []
	var i := 0
	for c in range(first, last):
		var clip: Dictionary = clips[c]
		var frames: int = clip["frames"]
		names.append("%d %s" % [c, clip["name"]])
		var col := c - first
		for row in 3:
			var r: float
			if clip["loop"]:
				r = [0.0, 0.5, float(frames - 1) / frames][row]
			else:
				r = [0.0, 0.5, 1.0][row]
			var pos := Vector3((col - (last - first - 1) / 2.0) * GAP_X, 0, (row - 1) * GAP_Z)
			mm.set_instance_transform(i, Transform3D(Basis(Vector3.UP, deg_to_rad(YAW)), pos))
			mm.set_instance_custom_data(i, Color(r, c, 1.0, 1.0))
			i += 1
	var draw := MultiMeshInstance3D.new()
	draw.multimesh = mm
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://game/actors/dead_vat.gdshader")
	mat.set_shader_parameter("vat", vat["texture"])
	var tables := VatBaker.shader_tables(vat)
	for key in tables:
		mat.set_shader_parameter(key, tables[key])
	mat.set_shader_parameter("tint", Vector3(0.5, 0.5, 0.5))
	draw.material_override = mat
	holder.add_child(draw)
	# Look down at the middle of the three rows from the field's pitch.
	var pitch := deg_to_rad(52.0)
	cam.position = Vector3(0, 0.8, 0) + Vector3(0, sin(pitch), cos(pitch)) * 30.0
	title.text = "%s   왼쪽부터: %s   (줄: 시작 / 중간 / 끝)" % [BODIES[b][0], " · ".join(names)]
	print("MOTIONSHEET page=%d body=%s first=%d last=%d clips=%s" % [page, BODIES[b][0], first, last - 1, ",".join(names).replace(" ", "_")])
