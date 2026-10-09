extends RefCounted
## Smoke and steam emitters. Every puff in the game comes from here, so the
## ban lines (project rules, presentation_motion.md 586) live in this table:
## - only a running locomotive makes thick smoke, long and grey, flowing back;
## - a stopped locomotive makes low steam under the wheels, never a rising column;
## - car stoves make faint steam only;
## - omen and field smoke hugs the ground (doorframes, sacks), never a column;
## - buildings, factory chimneys and cooling towers make none, so there is no
##   kind for them, and a closed wagon has no flue.
## Smoke may pass behind the HUD band but must not cover cross-section windows
## or faces; that is placement, checked where the emitter is put.

const SmokeShader = preload("res://fx/shaders/smoke_soft.gdshader")

## dir: emission direction in the emitter's frame (-x = behind a train heading +x).
## up_g: buoyancy (upward gravity). flat: spread stays in the ground plane.
## max_alpha caps how thick a puff can look.
## max_rise: the most a puff may climb above the emitter (metres), checked in tests.
const KINDS: Dictionary = {
	"loco_run": {"amount": 72, "lifetime": 4.5, "dir": Vector3(-1.0, 0.35, 0.0), "spread": 10.0,
		"v_min": 3.0, "v_max": 4.5, "up_g": 0.25, "scale": Vector2(1.8, 2.6), "grow": 2.6,
		"color": Color(0.40, 0.40, 0.41), "old": Color(0.60, 0.61, 0.62), "max_alpha": 0.75, "max_rise": 13.0},
	"loco_idle": {"amount": 24, "lifetime": 1.6, "dir": Vector3(0.0, 0.0, 1.0), "spread": 90.0, "flat": true,
		"v_min": 0.5, "v_max": 0.9, "up_g": 0.05, "scale": Vector2(0.5, 0.8), "grow": 2.0,
		"color": Color(0.70, 0.71, 0.72), "old": Color(0.80, 0.81, 0.82), "max_alpha": 0.35, "max_rise": 0.8},
	"stove": {"amount": 8, "lifetime": 2.0, "dir": Vector3(0.0, 1.0, 0.0), "spread": 25.0,
		"v_min": 0.25, "v_max": 0.4, "up_g": 0.02, "scale": Vector2(0.2, 0.35), "grow": 2.0,
		"color": Color(0.78, 0.79, 0.80), "old": Color(0.84, 0.85, 0.86), "max_alpha": 0.22, "max_rise": 1.0},
	"low_drift": {"amount": 18, "lifetime": 3.0, "dir": Vector3(1.0, 0.1, 0.0), "spread": 30.0, "flat": true,
		"v_min": 0.3, "v_max": 0.6, "up_g": 0.03, "scale": Vector2(0.5, 0.9), "grow": 2.2,
		"color": Color(0.36, 0.36, 0.37), "old": Color(0.55, 0.56, 0.57), "max_alpha": 0.45, "max_rise": 1.5},
}

## Below this speed (m/s) a locomotive counts as stopped.
const RUN_SPEED: float = 1.0


static func kind_for_locomotive(speed: float) -> String:
	return "loco_run" if speed >= RUN_SPEED else "loco_idle"


## Highest a puff of this kind can climb: rise of the fastest upward start
## plus buoyancy over its life (spread can only tilt it further from vertical).
static func max_rise(kind: String) -> float:
	var k: Dictionary = KINDS[kind]
	var dir: Vector3 = Vector3(k["dir"]).normalized()
	var spread := deg_to_rad(float(k["spread"]))
	var tilt := 0.0 if bool(k.get("flat", false)) else spread
	var up := clampf(sin(minf(asin(clampf(dir.y, -1.0, 1.0)) + tilt, PI / 2.0)), -1.0, 1.0)
	var t := float(k["lifetime"])
	return maxf(up, 0.0) * float(k["v_max"]) * t + 0.5 * float(k["up_g"]) * t * t


## Build an emitter, or null for a kind that does not exist (chimneys etc.).
static func build(kind: String) -> GPUParticles3D:
	if not KINDS.has(kind):
		return null
	var k: Dictionary = KINDS[kind]
	var p := GPUParticles3D.new()
	p.name = "Smoke_%s" % kind
	p.amount = int(k["amount"])
	p.lifetime = float(k["lifetime"])
	p.local_coords = false
	p.visibility_aabb = AABB(Vector3(-25, -2, -8), Vector3(30, 16, 16))
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3(k["dir"]).normalized()
	pm.spread = float(k["spread"])
	pm.flatness = 1.0 if bool(k.get("flat", false)) else 0.0
	pm.initial_velocity_min = float(k["v_min"])
	pm.initial_velocity_max = float(k["v_max"])
	pm.gravity = Vector3(0.0, float(k["up_g"]), 0.0)
	pm.damping_min = 0.2
	pm.damping_max = 0.5
	pm.scale_min = Vector2(k["scale"]).x
	pm.scale_max = Vector2(k["scale"]).y
	var grow := Curve.new()
	grow.add_point(Vector2(0.0, 1.0 / float(k["grow"])))
	grow.add_point(Vector2(1.0, 1.0))
	var grow_tex := CurveTexture.new()
	grow_tex.curve = grow
	pm.scale_curve = grow_tex
	pm.angle_min = -180.0
	pm.angle_max = 180.0
	p.process_material = pm
	var quad := QuadMesh.new()
	quad.size = Vector2(1.0, 1.0)
	var mat := ShaderMaterial.new()
	mat.shader = SmokeShader
	mat.set_shader_parameter("smoke_color", k["color"])
	mat.set_shader_parameter("old_color", k["old"])
	mat.set_shader_parameter("density", float(k["max_alpha"]))
	quad.material = mat
	p.draw_pass_1 = quad
	p.set_meta("fx_kind", kind)
	return p


## Locomotive: `running` sits on the chimney, `idle` low by the wheels
## (steam under a standing engine, not from the chimney). Keep both and let
## this switch them by speed.
static func update_locomotive(running: GPUParticles3D, idle: GPUParticles3D, speed: float) -> void:
	var run := kind_for_locomotive(speed) == "loco_run"
	running.emitting = run
	idle.emitting = not run
	if run:
		# Faster train, longer trail; the smoke never stands up straight.
		running.speed_scale = clampf(0.6 + speed / 20.0, 0.6, 1.6)
