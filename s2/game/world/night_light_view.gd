extends Node3D
## What shows of the night lights people left (night_lights.gd, decision 471 B4):
## a flame on a drum or on a ring of stones, a candle's glow in a window, a
## car's two headlights. The light they throw on the ground is the lamp
## channel of the sight mask (LampLight); this is only their glowing hearts,
## layered flames, embers and short sparks on the GPU. No smoke.

const FieldGrid = preload("res://game/world/field_grid.gd")
const NightLights = preload("res://game/world/night_lights.gd")
const FLAME = preload("res://game/world/night_flame.gdshader")
const SPARK = preload("res://game/world/night_spark.gdshader")
const COLD_FIRE_MODEL := "res://models/props_field/cold_campfire.glb"

## Warm lamp colours, never red (atmosphere 6): flame about 28 degrees,
## candle about 32, headlights a warm white.
const FLAME_TINT := Color(1.0, 0.62, 0.28)
const CORE_TINT := Color(1.0, 0.86, 0.58)
const BED_TINT := Color(1.0, 0.55, 0.20)
const SPARK_TINT := Color(1.0, 0.72, 0.36)
const CANDLE_TINT := Color(1.0, 0.7, 0.36)
const HEADLIGHT_TINT := Color(1.0, 0.93, 0.8)

## props_field_gap.py: charcoal surface about 0.03 m; keep 0.05 m above it.
const CAMP_COAL_Y := 0.03
const CAMP_BED_Y := CAMP_COAL_Y + 0.05
## props_common.py: lid below the 0.9 m top; stay above the lid, inside its rim.
const BARREL_BED_Y := 0.89
## Sparks leave from the flame's upper half so they clear its tip. Launched from
## the embers they died inside the main flame quad and never showed (probe 11-03).
const CAMP_SPARK_Y := CAMP_BED_Y + 0.55
## Downward pull on a spark (m/s²): light and buoyant, it slows but keeps climbing.
const SPARK_FALL := 0.35
const BARREL_SPARK_Y := BARREL_BED_Y + 0.40

## light id -> {glow: Array[MeshInstance3D], sparks: GPUParticles3D, on: bool}.
## The stone model is deliberately outside these entries.
var parts: Dictionary = {}
var sparks_enabled := true
## The field supplies its current CPU weather values; never read back the GPU.
var weather_source: Callable
var _weather_key: Array = []


func _ready() -> void:
	visibility_changed.connect(refresh_visibility)
	refresh_visibility()


func _process(_delta: float) -> void:
	_refresh_weather()


func _refresh_weather() -> void:
	if weather_source.is_valid():
		var weather: Dictionary = weather_source.call()
		set_weather(weather.get("params", {}), weather.get("kinds", []))


## Build one heart for each night light in data["lights"]; all start out.
func build(data: Dictionary) -> void:
	var n := 0
	for l: Dictionary in data["lights"]:
		var kind := String(l.get("kind", ""))
		if not NightLights.KINDS.has(kind):
			continue
		n += 1
		var at := FieldGrid.center(l["cell"])
		var side: Vector2i = l.get("side", Vector2i.ZERO)
		var nodes: Array[MeshInstance3D] = []
		var sparks: GPUParticles3D = null
		match kind:
			"barrel_fire":
				_add_flame(nodes, at + Vector3(0, BARREL_BED_Y + 0.44, 0), Vector2(0.75, 0.88), n, 0)
				_add_flame(nodes, at + Vector3(1, 0, -1).normalized() * 0.25 + Vector3(0, BARREL_BED_Y + 0.29, 0), Vector2(0.48, 0.58), n, 1)
				nodes.append(_bed(at + Vector3(0, BARREL_BED_Y, 0), 0.55, n))
				sparks = _sparks(at + Vector3(0, BARREL_SPARK_Y, 0))
			"campfire":
				if ResourceLoader.exists(COLD_FIRE_MODEL):
					var stones: Node3D = (load(COLD_FIRE_MODEL) as PackedScene).instantiate()
					stones.position = at
					stones.name = "Stones_" + String(l["id"])
					add_child(stones)
				_add_flame(nodes, at + Vector3(0, CAMP_BED_Y + 0.6, 0), Vector2(0.9, 1.2), n, 0)
				# Camera right at the fixed 45-degree azimuth; offsets are 0.25 m.
				var across := Vector3(1, 0, -1).normalized() * 0.25
				_add_flame(nodes, at - across + Vector3(0, CAMP_BED_Y + 0.38, 0), Vector2(0.58, 0.76), n, 1)
				_add_flame(nodes, at + across + Vector3(0, CAMP_BED_Y + 0.31, 0), Vector2(0.48, 0.62), n, 2)
				nodes.append(_bed(at + Vector3(0, CAMP_BED_Y, 0), 0.9, n))
				sparks = _sparks(at + Vector3(0, CAMP_SPARK_Y, 0))
			"candle":
				nodes.append(_quad(at + Vector3(side.x * 0.3, 1.05, side.y * 0.3), Vector2(0.28, 0.28), CANDLE_TINT, n, 0.6, true))
			"headlights":
				var across := Vector3(absf(side.y), 0, absf(side.x)) * 0.55
				var front := at + Vector3(side.x * 0.5, 0.65, side.y * 0.5)
				for s in [-1.0, 1.0]:
					nodes.append(_quad(front + across * s, Vector2(0.45, 0.45), HEADLIGHT_TINT, n, 0.0, true))
		parts[String(l["id"])] = {"glow": nodes, "sparks": sparks, "on": false}
		set_on(String(l["id"]), false)
	_weather_key.clear()
	refresh_visibility()


func _add_flame(nodes: Array[MeshInstance3D], at: Vector3, size: Vector2, n: int, layer: int) -> void:
	var node := _quad(at, size, FLAME_TINT, n, 1.0, false)
	node.name = "Flame_%d_%d" % [n, layer]
	var mat := node.material_override as ShaderMaterial
	mat.set_shader_parameter("seed", float(n) * 0.73 + float(layer) * 3.19)
	mat.set_shader_parameter("phase", float(n) * 2.17 + float(layer) * 1.61)
	nodes.append(node)


func _bed(at: Vector3, diameter: float, n: int) -> MeshInstance3D:
	var node := _quad(at, Vector2.ONE * diameter, BED_TINT, n, 0.15, true)
	node.name = "Bed_%d" % n
	node.rotation.x = -PI / 2.0
	(node.material_override as ShaderMaterial).set_shader_parameter("bed", true)
	node.set_meta("fire_role", "bed")
	return node


func _sparks(at: Vector3) -> GPUParticles3D:
	var motion := ParticleProcessMaterial.new()
	motion.direction = Vector3.UP
	motion.spread = 12.0
	motion.initial_velocity_min = 0.95
	motion.initial_velocity_max = 1.2
	motion.gravity = Vector3(0, -SPARK_FALL, 0)
	motion.damping_min = 0.1
	motion.damping_max = 0.2
	motion.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	motion.emission_box_extents = Vector3(0.10, 0.04, 0.10)
	motion.scale_min = 0.65
	motion.scale_max = 1.0
	motion.color = SPARK_TINT
	var gradient := Gradient.new()
	# Bright for most of the climb, so the part above the flame tip shows.
	gradient.colors = PackedColorArray([Color(1, 1, 1, 0), Color.WHITE, Color(1, 1, 1, 0.9), Color(1, 1, 1, 0)])
	gradient.offsets = PackedFloat32Array([0.0, 0.08, 0.6, 1.0])
	var ramp := GradientTexture1D.new()
	ramp.gradient = gradient
	motion.color_ramp = ramp
	var mat := ShaderMaterial.new()
	mat.shader = SPARK
	mat.set_shader_parameter("sway", 0.035)
	var quad := QuadMesh.new()
	# About two pixels across at the play camera, three to four on a phone.
	quad.size = Vector2(0.07, 0.07)
	quad.material = mat
	var node := GPUParticles3D.new()
	node.name = "Sparks"
	node.emitting = false
	node.visible = false
	node.amount = 10
	node.lifetime = 1.1
	node.randomness = 0.35
	node.local_coords = true
	node.process_material = motion
	node.draw_pass_1 = quad
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.visibility_aabb = AABB(Vector3(-0.8, -0.2, -0.8), Vector3(1.6, 1.7, 1.6))
	node.position = at
	node.set_meta("fire_role", "sparks")
	add_child(node)
	return node


func _quad(at: Vector3, size: Vector2, tint: Color, n: int, flicker: float, round_glow: bool) -> MeshInstance3D:
	var mat := ShaderMaterial.new()
	mat.shader = FLAME
	mat.set_shader_parameter("tint", tint)
	mat.set_shader_parameter("core_tint", CORE_TINT)
	mat.set_shader_parameter("phase", float(n) * 2.17)
	mat.set_shader_parameter("flicker", flicker)
	mat.set_shader_parameter("round_glow", 1.0 if round_glow else 0.0)
	var quad := QuadMesh.new()
	quad.size = size
	var node := MeshInstance3D.new()
	node.mesh = quad
	node.material_override = mat
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.position = at
	node.visible = false
	node.set_meta("fire_role", "glow" if round_glow else "flame")
	add_child(node)
	return node


func set_on(id: String, on: bool) -> void:
	if not parts.has(id):
		return
	parts[id]["on"] = on
	_sync(parts[id])


func is_on(id: String) -> bool:
	return bool(parts.get(id, {}).get("on", false))


func set_sparks_enabled(enabled: bool) -> void:
	sparks_enabled = enabled
	refresh_visibility()


func refresh_visibility() -> void:
	_refresh_weather()
	for entry: Dictionary in parts.values():
		_sync(entry)


func _sync(entry: Dictionary) -> void:
	var on: bool = entry["on"]
	for node: MeshInstance3D in entry["glow"]:
		node.visible = on
	var sparks: GPUParticles3D = entry["sparks"]
	if sparks != null:
		sparks.visible = on and sparks_enabled
		var emitting := on and sparks_enabled and is_inside_tree() and is_visible_in_tree()
		# Do not assign again, or restart: repeated LampLight results are idempotent.
		if sparks.emitting != emitting:
			sparks.emitting = emitting


func set_weather(params: Dictionary, kinds: Array) -> void:
	var wind: Vector3 = params.get("fx_wind", Vector3.ZERO)
	var wet := kinds.has("rain") or kinds.has("sleet") or kinds.has("blizzard")
	var key: Array = [wind, wet]
	if key == _weather_key:
		return
	_weather_key = key
	var drift := Vector2(wind.x, wind.y).limit_length(1.0) * clampf(wind.z, 0.0, 1.0) * 0.25
	for entry: Dictionary in parts.values():
		var sparks: GPUParticles3D = entry["sparks"]
		if sparks == null:
			continue
		sparks.amount_ratio = 0.6 if wet else 1.0
		sparks.lifetime = 0.8 if wet else 1.1
		(sparks.process_material as ParticleProcessMaterial).gravity = Vector3(drift.x, -SPARK_FALL, drift.y)
