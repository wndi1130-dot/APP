extends Node3D
## What shows of the night lights people left (night_lights.gd, decision 471 B4):
## a flame on a drum or on a ring of stones, a candle's glow in a window, a
## car's two headlights. The light they throw on the ground is the lamp
## channel of the sight mask (LampLight); this is only their glowing hearts,
## one small quad each, flickering on the GPU. No smoke.

const FieldGrid = preload("res://game/world/field_grid.gd")
const NightLights = preload("res://game/world/night_lights.gd")
const FLAME = preload("res://game/world/night_flame.gdshader")
const COLD_FIRE_MODEL := "res://models/props_field/cold_campfire.glb"

## Warm lamp colours, never red (atmosphere 6): flame about 28 degrees,
## candle about 32, headlights a warm white.
const FLAME_TINT := Color(1.0, 0.62, 0.28)
const CANDLE_TINT := Color(1.0, 0.7, 0.36)
const HEADLIGHT_TINT := Color(1.0, 0.93, 0.8)

## light id -> Array of MeshInstance3D (its glowing parts).
var parts: Dictionary = {}


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
		var nodes: Array = []
		match kind:
			"barrel_fire":
				nodes.append(_quad(at + Vector3(0, 1.3, 0), Vector2(0.9, 0.9), FLAME_TINT, n, 1.0, false))
			"campfire":
				if ResourceLoader.exists(COLD_FIRE_MODEL):
					var stones: Node3D = (load(COLD_FIRE_MODEL) as PackedScene).instantiate()
					stones.position = at
					add_child(stones)
				nodes.append(_quad(at + Vector3(0, 0.6, 0), Vector2(1.1, 1.2), FLAME_TINT, n, 1.0, false))
			"candle":
				nodes.append(_quad(at + Vector3(side.x * 0.3, 1.05, side.y * 0.3), Vector2(0.28, 0.28), CANDLE_TINT, n, 0.6, true))
			"headlights":
				var across := Vector3(absf(side.y), 0, absf(side.x)) * 0.55
				var front := at + Vector3(side.x * 0.5, 0.65, side.y * 0.5)
				for s in [-1.0, 1.0]:
					nodes.append(_quad(front + across * s, Vector2(0.45, 0.45), HEADLIGHT_TINT, n, 0.0, true))
		parts[String(l["id"])] = nodes
		set_on(String(l["id"]), false)


func _quad(at: Vector3, size: Vector2, tint: Color, n: int, flicker: float, round_glow: bool) -> MeshInstance3D:
	var mat := ShaderMaterial.new()
	mat.shader = FLAME
	mat.set_shader_parameter("tint", tint)
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
	add_child(node)
	return node


func set_on(id: String, on: bool) -> void:
	for node: MeshInstance3D in parts.get(id, []):
		node.visible = on


func is_on(id: String) -> bool:
	for node: MeshInstance3D in parts.get(id, []):
		return node.visible
	return false
