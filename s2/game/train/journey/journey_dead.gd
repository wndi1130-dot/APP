extends Node3D
## 「열차를 보고 뛰어오는 망자」 (결정 495 2절, 7b 망자 밀도·죽음은 멀리 결과로): the dead
## of a village's edge or a farm track hear the train and come at it over the snow,
## each in its own time and its own line (never in step, never in a row), and are left
## behind as the cars go by; the last of them stand looking after it. In the land's
## frame (they flow back with it), drawn with the field's baked dead body
## (dead_body.gd assets, the dead_weathered shader) in one MultiMesh, as zombies.gd
## draws them: worn everyday winter clothes, nothing of a uniform (7b). Variants:
## chasers (a scatter that runs), runner (one or two fresh ones, fast), walkers
## (a few plodding to the line), straggler (one by the track that turns and follows).

const DeadBody = preload("res://game/actors/dead_body.gd")
const DeadCast = preload("res://game/actors/dead_cast.gd")
const VatBaker = preload("res://scripts/vat_baker.gd")
const Kit = preload("res://game/train/journey/journey_kit.gd")
const SHADER := preload("res://game/actors/dead_weathered.gdshader")

## How many of the dead by variant (7b 흩어짐 1~10; a farm track's one or two).
const COUNT: Dictionary = {"chasers": Vector2i(4, 8), "runner": Vector2i(1, 2), "walkers": Vector2i(2, 4), "straggler": Vector2i(1, 1)}
## Their paces, m/s (zombies.gd: shamble 1.05, hurry 1.35, fresh 2.7; here they run at a train).
const RUN := Vector2(2.4, 3.2)
const FRESH := Vector2(3.6, 4.4)
const WALK := Vector2(0.8, 1.25)
## Gone by then whatever happens (seconds).
const LIFE_S: float = 30.0
const TINT := Color(0.5, 0.52, 0.47)   # zombies.gd TINTS["dead"]

var journey: Node3D
var bodies: Array = []
var age: float = 0.0
var baked: bool = false
var mm: MultiMesh
var rng := RandomNumberGenerator.new()
var _done: bool = false
var _hands_marked: bool = false
var _lift: float = 0.0


func begin(j: Node3D, ev: Dictionary, seed_value: int) -> void:
	journey = j
	rng.seed = seed_value
	name = "DeadRush"
	var variant: String = String(ev.get("variant", "chasers"))
	var span: Vector2i = COUNT.get(variant, Vector2i(2, 4))
	var n: int = rng.randi_range(span.x, span.y)
	var side: float = -1.0 if rng.randf() < 0.55 else 1.0
	for i in n:
		var start := Vector3(rng.randf_range(-14.0, 34.0), 0.0, side * rng.randf_range(11.0, 27.0))
		var pace: float = rng.randf_range(RUN.x, RUN.y)
		var gait: int = DeadBody.RUN
		if variant == "runner":
			pace = rng.randf_range(FRESH.x, FRESH.y)
		elif variant == "walkers":
			pace = rng.randf_range(WALK.x, WALK.y)
			gait = rng.randi_range(0, DeadBody.WALKS - 1)
			start.z = side * rng.randf_range(7.5, 18.0)
		elif variant == "straggler":
			start = Vector3(rng.randf_range(0.0, 20.0), 0.0, side * rng.randf_range(5.5, 9.0))
			pace = rng.randf_range(1.6, 2.4)
			gait = DeadBody.RUN if rng.randf() < 0.5 else 1
		# Toward the bank and on with the train (it is going +x past them).
		var to := Vector3(start.x + rng.randf_range(6.0, 22.0), 0.0, side * rng.randf_range(4.6, 6.4))
		# Half turned to the line at first, as if looking for the noise.
		var b := {"id": absi(seed_value) % 997 + i, "kind": "dead", "pos": start, "angle": atan2(0.6, -side), "to": to,
			"pace": pace, "gait": gait, "state": "wait", "t": 0.0, "wait": rng.randf_range(0.2, 2.2),
			"follow": rng.randf_range(1.5, 4.0), "r": rng.randf(), "phase": rng.randf(), "age": 0.0, "fall": variant == "runner" and rng.randf() < 0.3}
		bodies.append(b)
	_build_draw()
	advance(0.0, 0.0)


func is_done() -> bool:
	return _done


func advance(delta: float, _travelled: float) -> void:
	age += delta
	var behind: bool = true
	var shown: int = 0
	for i in bodies.size():
		var b: Dictionary = bodies[i]
		b["age"] = float(b["age"]) + delta
		b["t"] = float(b["t"]) + delta
		var motion: int = DeadBody.STAND
		var moved: float = 0.0
		match String(b["state"]):
			"wait":
				if float(b["t"]) >= float(b["wait"]):
					_go_to(b, "go")
			"go":
				var to: Vector3 = b["to"]
				var at: Vector3 = b["pos"]
				var d: Vector3 = to - at
				var step: float = float(b["pace"]) * delta
				if d.length() <= step:
					b["pos"] = to
					_go_to(b, "fall" if bool(b["fall"]) else "follow")
				else:
					var dir: Vector3 = d.normalized()
					b["pos"] = at + dir * step
					b["angle"] = lerp_angle(float(b["angle"]), atan2(dir.x, dir.z), minf(1.0, delta * 5.0))
					moved = step
				motion = int(b["gait"])
			"follow":
				# Along the bank after the cars, slowing.
				var k: float = clampf(float(b["t"]) / float(b["follow"]), 0.0, 1.0)
				var pace: float = lerpf(float(b["pace"]) * 0.8, 0.9, k)
				b["pos"] = (b["pos"] as Vector3) + Vector3(pace * delta, 0.0, 0.0)
				b["angle"] = lerp_angle(float(b["angle"]), PI * 0.5, minf(1.0, delta * 4.0))
				moved = pace * delta
				motion = int(b["gait"]) if k < 0.6 else 1
				if k >= 1.0:
					_go_to(b, "stand")
			"fall":
				motion = DeadBody.FALL_FRONT
			"stand":
				motion = DeadBody.STAND
				b["angle"] = lerp_angle(float(b["angle"]), PI * 0.5, minf(1.0, delta * 2.0))
		# Its feet go by the ground it covers (dead_body.gd step), not by the clock.
		var stride: float = float(DeadBody.rounds.get(motion, DeadBody.STRIDE.get(motion, 1.2)))
		if moved > 0.0:
			b["r"] = fposmod(float(b["r"]) + moved / maxf(stride, 0.1), 1.0)
		var r: float = float(b["r"])
		if motion == DeadBody.STAND:
			r = fposmod(float(b["phase"]) + float(b["age"]) / 3.0, 1.0)
		elif motion == DeadBody.FALL_FRONT:
			r = clampf(float(b["t"]) / 1.1, 0.0, 1.0)
		var plain := Color(r, float(motion), 1.0, 1.0)
		var custom: Color = DeadBody.mix_from(b, plain, float(b["age"]), DeadBody.table) if baked else Color(r, 1.0 if motion == DeadBody.RUN else 0.0, 0.0, 1.0)
		var pos: Vector3 = b["pos"]
		mm.set_instance_transform(i, Transform3D(Basis(Vector3.UP, float(b["angle"])), Vector3(pos.x, Kit.FIELD_Y + _lift, pos.z)))
		mm.set_instance_custom_data(i, custom)
		mm.set_instance_color(i, DeadCast.tear_of(b, _hands_marked))
		shown += 1
		if journey != null and _train_x(pos) > -70.0:
			behind = false
	if mm != null:
		mm.visible_instance_count = shown
	if age >= LIFE_S or (age > 3.0 and behind):
		_done = true


func _go_to(b: Dictionary, state: String) -> void:
	b["state"] = state
	b["t"] = 0.0


## Where a point of this event is along the train (its own frame: 0 the tail).
func _train_x(local: Vector3) -> float:
	return journey.get("land").position.x + position.x + local.x


func _build_draw() -> void:
	var body: Dictionary = DeadBody.assets()
	baked = not body.is_empty()
	var node := MultiMeshInstance3D.new()
	node.name = "Dead"
	mm = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.use_colors = true
	mm.instance_count = maxi(bodies.size(), 1)
	mm.visible_instance_count = 0
	if baked:
		var mesh: Mesh = body["mesh"]
		mm.mesh = mesh
		_hands_marked = mesh != null and mesh.get_surface_count() > 0 and (mesh.surface_get_format(0) & Mesh.ARRAY_FORMAT_COLOR) != 0
		var mat := ShaderMaterial.new()
		mat.shader = SHADER
		mat.set_shader_parameter("vat", body["texture"])
		mat.set_shader_parameter("rows_per_frame", float(body["rows_per_frame"]))
		var tables: Dictionary = VatBaker.shader_tables(body)
		for key: String in tables:
			mat.set_shader_parameter(key, tables[key])
		mat.set_shader_parameter("mixes", true)
		mat.set_shader_parameter("tint", Vector3(TINT.r, TINT.g, TINT.b))
		node.material_override = mat
	else:
		# No baked body in this build: a dark stand-in a body's size.
		var cap := CapsuleMesh.new()
		cap.radius = 0.22
		cap.height = 1.7
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.3, 0.3, 0.29)
		cap.material = m
		mm.mesh = cap
		_lift = 0.85
	mm.custom_aabb = AABB(Vector3(-40, -3, -40), Vector3(120, 8, 80))
	node.multimesh = mm
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(node)
