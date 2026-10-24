extends Node3D
## Small one-shot CPU emitters. No physics bodies, lights or per-hit node creation.
## All instances lease from FxState's shared transient budget.

const FxState = preload("res://fx/fx_state.gd")
var slots: Array[Dictionary] = []
var serial := 0


func prepare(count: int, shader: Shader) -> void:
	if not slots.is_empty():
		return
	for _i in range(count):
		var p := CPUParticles3D.new()
		p.emitting = false
		p.visible = false
		p.one_shot = true
		p.explosiveness = 1.0
		p.amount = 24
		p.fixed_fps = 30
		p.local_coords = false
		p.use_fixed_seed = true
		p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		p.add_to_group("transient_fx")
		var q := QuadMesh.new()
		q.size = Vector2.ONE
		var material := ShaderMaterial.new()
		material.shader = shader
		q.material = material
		p.mesh = q
		var ramp := Gradient.new()
		ramp.set_color(0, Color.WHITE)
		ramp.set_color(1, Color(1, 1, 1, 0))
		p.color_ramp = ramp
		add_child(p)
		slots.append({"node": p, "material": material, "left": 0.0, "order": -1, "count": 0})


func burst(pos: Vector3, direction: Vector3, requested: int, seed_value: int, spec: Dictionary) -> int:
	if requested <= 0 or slots.is_empty():
		return 0
	var chosen := 0
	for i in range(slots.size()):
		if float(slots[i]["left"]) <= 0.0:
			chosen = i
			break
		if int(slots[i]["order"]) < int(slots[chosen]["order"]):
			chosen = i
	var slot: Dictionary = slots[chosen]
	var p: CPUParticles3D = slot["node"]
	_release(slot)
	var granted := FxState.lease_particles(p, mini(requested, 24))
	if granted == 0:
		return 0
	p.global_position = pos
	p.amount = granted
	p.seed = seed_value
	p.lifetime = float(spec.get("life", 0.4))
	p.direction = direction.normalized() if direction.length_squared() > 0.0001 else Vector3.FORWARD
	p.spread = float(spec.get("spread", 30.0))
	p.gravity = spec.get("gravity", Vector3(0, -5, 0))
	p.initial_velocity_min = float(spec.get("speed", 1.0)) * 0.55
	p.initial_velocity_max = float(spec.get("speed", 1.0))
	p.scale_amount_min = float(spec.get("size", 0.06)) * 0.5
	p.scale_amount_max = float(spec.get("size", 0.06))
	p.color = spec.get("color", Color.WHITE)
	var material: ShaderMaterial = slot["material"]
	material.set_shader_parameter("style", int(spec.get("style", 0)))
	p.visible = true
	p.restart()
	p.emitting = true
	serial += 1
	slot["order"] = serial
	slot["left"] = p.lifetime + 0.08
	slot["count"] = granted
	return granted


func advance(delta: float) -> void:
	for slot in slots:
		if float(slot["left"]) > 0.0:
			slot["left"] = maxf(0.0, float(slot["left"]) - maxf(delta, 0.0))
			if float(slot["left"]) <= 0.0:
				_release(slot)


func active_count() -> int:
	var count := 0
	for slot in slots:
		count += int(slot["count"])
	return count


func clear() -> void:
	for slot in slots:
		_release(slot)


func _release(slot: Dictionary) -> void:
	var p: CPUParticles3D = slot["node"]
	p.emitting = false
	p.visible = false
	slot["left"] = 0.0
	slot["count"] = 0
	FxState.release_particles(p)


func _exit_tree() -> void:
	clear()
