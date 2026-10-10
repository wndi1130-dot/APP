extends RefCounted
## How a storm looks at its three stops (weather_fx.md 14장): coming, at its
## height, gone. Picture only: light, falling snow in layers, the snow-fog that
## closes the view, frost on the screen edge. Rules still come from weather.gd.
## Numbers are proposals until a phone check (Galaxy S22) fixes them.

const PRECIP := "res://fx/shaders/precip.gdshader"

## Most snow particles on screen at once, all layers together (phone budget).
const MAX_PARTICLES: int = 900

## sun: times the day band's sun energy. sun_pitch: degrees below level (a low
## sun throws long shadows). front: dark bank on the edge the wind comes from.
## whiteout: snow-fog over the whole view. edge_frost: frost creeping in.
## fall_cm_h: how fast lying snow and snow caps grow.
## windows_lit: window lights that wait for dusk are on all day. lamp_gain:
## how much of the night's lamp glow shows on the ground by day (0..1).
## rules: the weather kinds the stop plays by (weather.gd); kinds: what it is
## drawn as. Colours stay grey, grey-blue and grey-yellow: no red, no sky blue.
const STAGES: Dictionary = {
	"before": {
		"rules": ["clear"], "kinds": ["overcast"], "sun": 0.7, "sun_pitch": -50.0, "shadows": true,
		"sun_color": Color(0.80, 0.76, 0.67), "ambient_color": Color(0.57, 0.56, 0.53),
		"front": 0.75, "whiteout": 0.0, "edge_frost": 0.05, "fall_cm_h": 0.0,
		"layers": [
			# A few fat flakes ahead of the storm, and snow dust creeping along the ground.
			{"name": "big", "amount": 40, "shape": 1, "size": Vector2(0.16, 0.16), "speed": 2.0, "lean": 0.35, "height": 10.0, "opacity": 0.8},
			{"name": "drift", "amount": 140, "shape": 2, "size": Vector2(0.07, 0.6), "speed": 5.0, "lean": 1.0, "height": 0.25, "opacity": 0.35},
		],
	},
	"during": {
		"rules": ["blizzard"], "kinds": ["blizzard"], "sun": 0.5, "sun_pitch": -50.0, "shadows": false,
		"sun_color": Color(0.72, 0.74, 0.78), "ambient_color": Color(0.55, 0.57, 0.61),
		"front": 0.0, "whiteout": 0.75, "edge_frost": 0.3, "fall_cm_h": 3.0,
		"windows_lit": true, "lamp_gain": 0.7,
		"layers": [
			# Far: fine and many. Middle: short streaks. Near: fat streaks lying on the wind.
			{"name": "far", "amount": 400, "shape": 1, "size": Vector2(0.07, 0.07), "speed": 9.0, "lean": 0.8, "height": 9.0, "opacity": 0.8},
			{"name": "mid", "amount": 300, "shape": 2, "size": Vector2(0.09, 0.45), "speed": 13.0, "lean": 0.86, "height": 8.0, "opacity": 0.7},
			{"name": "near", "amount": 120, "shape": 2, "size": Vector2(0.16, 1.1), "speed": 18.0, "lean": 0.92, "height": 7.0, "opacity": 0.5},
			{"name": "drift", "amount": 80, "shape": 2, "size": Vector2(0.08, 0.8), "speed": 9.0, "lean": 1.0, "height": 0.25, "opacity": 0.4},
		],
	},
	"after": {
		"rules": ["clear"], "kinds": ["clear"], "sun": 1.2, "sun_pitch": -27.0, "shadows": true,
		"sun_color": Color(0.93, 0.94, 0.96), "ambient_color": Color(0.66, 0.68, 0.71),
		"front": 0.0, "whiteout": 0.0, "edge_frost": 0.2, "fall_cm_h": 0.0, "storm_cm": 25.0,
		"layers": [
			# Ice dust hanging in the still air, catching the sun.
			{"name": "glitter", "amount": 60, "shape": 1, "size": Vector2(0.06, 0.06), "speed": 0.15, "lean": 0.3, "height": 4.0, "opacity": 0.95, "twinkle": 1.0},
		],
	},
}


static func has(stage: String) -> bool:
	return STAGES.has(stage)


static func look(stage: String) -> Dictionary:
	return STAGES.get(stage, {})


static func particle_count(stage: String) -> int:
	var n := 0
	for layer in look(stage).get("layers", []):
		n += int(layer["amount"])
	return n


## Which way a layer's snow moves: straight down at lean 0, flat on the wind at 1.
static func fall_dir(wind_dir: Vector2, lean: float) -> Vector3:
	var w := wind_dir.normalized() if wind_dir.length() > 0.001 else Vector2(1, 0)
	var flat := clampf(lean, 0.0, 1.0)
	return Vector3(w.x * flat, -(1.0 - flat) - 0.02, w.y * flat).normalized()


## An empty snow layer; aim_layer() fills it in.
static func new_layer() -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.process_material = ParticleProcessMaterial.new()
	var q := QuadMesh.new()
	var m := ShaderMaterial.new()
	m.shader = load(PRECIP)
	q.material = m
	p.draw_pass_1 = q
	p.visibility_aabb = AABB(Vector3(-60, -14, -40), Vector3(120, 30, 80))
	return p


## Set a layer up from its row in STAGES. Returns where it sits relative to
## the middle of the view: upwind, so it fills the view as it flies.
static func aim_layer(p: GPUParticles3D, spec: Dictionary, wind_dir: Vector2) -> Vector3:
	var dir := fall_dir(wind_dir, float(spec["lean"]))
	var fast := float(spec["speed"])
	var high := float(spec["height"])
	# Long enough to cross the view, whichever way it flies.
	var life := clampf(high / maxf(-dir.y * fast, 0.01) if dir.y < -0.3 else 44.0 / fast, 1.2, 12.0)
	p.amount = int(spec["amount"])
	p.lifetime = life
	p.preprocess = life
	var pm := p.process_material as ParticleProcessMaterial
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(30, minf(high * 0.4, 3.0), 20)
	pm.direction = dir
	pm.spread = 4.0
	pm.initial_velocity_min = fast * 0.75
	pm.initial_velocity_max = fast
	pm.gravity = Vector3.ZERO
	var q := p.draw_pass_1 as QuadMesh
	q.size = spec["size"]
	var m := q.material as ShaderMaterial
	m.set_shader_parameter("shape", int(spec["shape"]))
	m.set_shader_parameter("opacity", float(spec["opacity"]))
	m.set_shader_parameter("axis", dir)
	m.set_shader_parameter("twinkle", float(spec.get("twinkle", 0.0)))
	return Vector3(0, high, 0) - Vector3(dir.x, 0, dir.z) * fast * life * 0.5
