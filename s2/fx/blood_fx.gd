extends Node3D
## Blood for one stop. A hit throws drops that fly a short arc in the hit's
## direction (most land close, a few far) and leave a small mark where each one
## lands, so the ground shows which way the blow went. Marks on the floor and on
## walls are flat instanced quads in one MultiMesh (one draw for the whole stop);
## the shape and the drying are made in the shader. The oldest mark goes first.
## World contacts come from the caller: no flat-ground guess, no raycast per drop.

const FxState = preload("res://fx/fx_state.gd")
const DROP_SHADER = preload("res://fx/shaders/blood_drop.gdshader")
const SPLAT_SHADER = preload("res://fx/shaders/blood_splat.gdshader")
const MARK_SHADER = preload("res://fx/shaders/blood_decal.gdshader")
const MAX_SPLATS := 512
const MAX_DROPS_PER_HIT := 24
const MAX_DROPS := 48
const MAX_BODY_MARKS := 16
const STAIN_SECONDS := 900.0
const DRY_SECONDS := 90.0
const POOL_GROW_SECONDS := 8.0
const GRAVITY := 9.8
## Drops that fall this far below the hit without a floor are let go.
const LOST_BELOW := 2.5
const VARIANTS := 8
## 경고 빨강과 헷갈리지 않게 채도를 누른 검붉은 갈색. 마르면 갈색에 가까운 검정.
const FRESH := Color(0.23, 0.07, 0.055)
const DRIED := Color(0.17, 0.075, 0.055)
## The spray right where the blow lands: short and soft.
const PUFF_SECONDS := 0.18
enum Kind { DROP, SPLAT, POOL, WALL }
## Per weapon kind: drops at strength 1, horizontal speed (m/s) and how wide the spray fans.
const KINDS: Dictionary = {
	"blunt": {"count": 10, "speed": 2.2, "fan": 2.0},
	"slash": {"count": 16, "speed": 3.0, "fan": 1.6},
	"pierce": {"count": 7, "speed": 2.6, "fan": 0.8},
	"firearm": {"count": 20, "speed": 4.5, "fan": 1.0},
}

var splats: MultiMeshInstance3D
var splat_material: ShaderMaterial
var drops_node: MultiMeshInstance3D
var drops: Array[Dictionary] = []
## What each MultiMesh slot holds, kept here too: the renderer's copy cannot be read back headless.
var records: Array[Dictionary] = []
var body_marks: Array[Dictionary] = []
var clock := 0.0
var _written := 0
var _rng := RandomNumberGenerator.new()
var _serial := 0


func _ready() -> void:
	_rng.seed = 1
	splat_material = ShaderMaterial.new()
	splat_material.shader = SPLAT_SHADER
	splat_material.set_shader_parameter("fresh", FRESH)
	splat_material.set_shader_parameter("dried", DRIED)
	splat_material.set_shader_parameter("dry_seconds", DRY_SECONDS)
	splat_material.set_shader_parameter("pool_seconds", POOL_GROW_SECONDS)
	splat_material.set_shader_parameter("life_seconds", STAIN_SECONDS)
	var plane := PlaneMesh.new()
	plane.size = Vector2.ONE
	plane.material = splat_material
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.mesh = plane
	mm.instance_count = MAX_SPLATS
	mm.visible_instance_count = 0
	splats = MultiMeshInstance3D.new()
	splats.name = "Splats"
	splats.multimesh = mm
	splats.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(splats)
	var drop_material := ShaderMaterial.new()
	drop_material.shader = DROP_SHADER
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	quad.material = drop_material
	var dm := MultiMesh.new()
	dm.transform_format = MultiMesh.TRANSFORM_3D
	dm.use_colors = true
	dm.use_custom_data = true
	dm.mesh = quad
	dm.instance_count = MAX_DROPS
	dm.visible_instance_count = 0
	drops_node = MultiMeshInstance3D.new()
	drops_node.name = "Drops"
	drops_node.multimesh = dm
	drops_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	drops_node.add_to_group("transient_fx")
	add_child(drops_node)
	for _i in range(MAX_BODY_MARKS):
		var mark := MeshInstance3D.new()
		mark.mesh = QuadMesh.new()
		mark.visible = false
		mark.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var material := ShaderMaterial.new()
		material.shader = MARK_SHADER
		mark.material_override = material
		add_child(mark)
		body_marks.append({"node": mark, "material": material, "active": false, "id": -1, "age": 0.0})
	FxState.register_blood_client(self)


func begin_stop(seed_value: int = 1) -> void:
	clear()
	_serial = 0
	_rng.seed = seed_value


## The ground's sight mask, so marks in unseen places stay as dark as the ground.
func set_sight(vis: Texture2D, map_size: Vector2) -> void:
	splat_material.set_shader_parameter("vis", vis)
	splat_material.set_shader_parameter("map_size", map_size)
	splat_material.set_shader_parameter("mask_on", 1.0 if vis != null else 0.0)


## A hit. `contact` may hold "position" (the floor under the body; its y is where
## drops land), "snow", and "wall_position"/"wall_normal" for a wall beside it.
## An optional "can_land" callable checks each drop's landing position once.
func hit(world_pos: Vector3, direction: Vector3, strength: float = 1.0, kind: String = "blunt", contact: Dictionary = {}) -> Dictionary:
	if FxState.blood_level == FxState.BloodLevel.OFF or strength <= 0.0:
		return {}
	var spec: Dictionary = KINDS.get(kind, KINDS["blunt"])
	var force := clampf(strength, 0.1, 2.0)
	var wanted := mini(MAX_DROPS_PER_HIT, maxi(1, roundi(float(spec["count"]) * force * FxState.blood_scale())))
	var seed_value := _rng.randi()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var flat := Vector3(direction.x, 0.0, direction.z)
	flat = flat.normalized() if flat.length_squared() > 0.0001 else Vector3.FORWARD
	var has_floor := contact.has("position")
	var floor_y: float = contact["position"].y if has_floor else world_pos.y - LOST_BELOW
	var snow := bool(contact.get("snow", false))
	var room := mini(wanted, MAX_DROPS - drops.size())
	var granted := FxState.lease_particles(drops_node, drops.size() + room) - drops.size()
	var made := 0
	for i in range(maxi(0, granted)):
		# Most drops keep close to the line of the blow; now and then one flies wide.
		var turn := (rng.randf() - 0.5) * 0.07
		for tier in [[3, 0.1], [5, 0.2], [8, 0.3], [10, 0.4]]:
			if rng.randi_range(0, tier[0] - 1) == 0:
				turn += (rng.randf() - 0.5) * tier[1]
		turn *= float(spec["fan"]) * 2.2
		var speed := float(spec["speed"]) * sqrt(force) * rng.randf_range(0.15, 1.0)
		var dir := flat.rotated(Vector3.UP, turn)
		drops.append({
			"pos": world_pos + Vector3(rng.randf_range(-0.06, 0.06), rng.randf_range(-0.05, 0.08), rng.randf_range(-0.06, 0.06)),
			"vel": dir * speed + Vector3.UP * rng.randf_range(0.2, 1.6),
			"floor": floor_y, "land": has_floor, "snow": snow,
			"can_land": contact.get("can_land", Callable()),
			"size": rng.randf_range(0.022, 0.045), "mark": rng.randf_range(0.07, 0.14), "seed": rng.randf(),
		})
		made += 1
	if made > 0 and drops.size() < MAX_DROPS:
		drops.append({"puff": true, "pos": world_pos, "vel": flat * 0.8, "age": 0.0, "size": 0.16 * sqrt(force)})
	_sync_drops()
	var mark := {}
	# A splat under the body: every hard blow, half of the light ones.
	if has_floor and (force >= 1.2 or rng.randf() < 0.5):
		mark = stain(contact["position"], Vector3.UP, force * 0.8, snow)
	if contact.has("wall_position"):
		wall(contact["wall_position"], contact.get("wall_normal", -flat), force)
	return {"count": made, "seed": seed_value, "direction": flat, "kind": kind, "stain": mark}


## A body that falls: a heavy hit, a big splat under it and a pool that spreads.
func death(world_pos: Vector3, direction: Vector3, kind: String = "blunt", contact: Dictionary = {}) -> Dictionary:
	var result := hit(world_pos, direction, 1.6, kind, contact)
	if contact.has("position"):
		pool(contact["position"], bool(contact.get("snow", false)))
	return result


func stain(world_pos: Vector3, normal: Vector3 = Vector3.UP, strength: float = 1.0, on_snow: bool = false) -> Dictionary:
	if FxState.blood_level == FxState.BloodLevel.OFF or strength <= 0.0:
		return {}
	var size := clampf(strength, 0.15, 2.0) * _rng.randf_range(0.36, 0.55) * sqrt(FxState.blood_scale())
	return _write(world_pos, normal, Vector2(size, size), Vector3.ZERO, Kind.SPLAT, on_snow, clampf(strength, 0.0, 1.0))


func pool(world_pos: Vector3, on_snow: bool = false, normal: Vector3 = Vector3.UP) -> Dictionary:
	if FxState.blood_level == FxState.BloodLevel.OFF:
		return {}
	var size := _rng.randf_range(1.2, 1.6) * sqrt(FxState.blood_scale())
	return _write(world_pos, normal, Vector2(size, size), Vector3.ZERO, Kind.POOL, on_snow, 1.0)


func wall(world_pos: Vector3, normal: Vector3, strength: float = 1.0) -> Dictionary:
	if FxState.blood_level == FxState.BloodLevel.OFF or strength <= 0.0:
		return {}
	var size := clampf(strength, 0.3, 2.0) * _rng.randf_range(0.32, 0.5)
	return _write(world_pos, normal, Vector2(size, size), Vector3.ZERO, Kind.WALL, false, clampf(strength, 0.0, 1.0))


## Attach to an existing bone/attachment Node3D. local_pose's +Z faces out.
## Blood is cosmetic; wounds, clothing damage and bleeding stay in simulation.
func body_mark(anchor: Node3D, local_pose: Transform3D, kind: String = "stain", size: float = 0.16) -> int:
	if FxState.blood_level == FxState.BloodLevel.OFF or not is_instance_valid(anchor):
		return -1
	var slot := _oldest_or_free(body_marks)
	_serial += 1
	var material: ShaderMaterial = slot["material"]
	material.set_shader_parameter("pattern_seed", float(_rng.randi_range(1, VARIANTS)))
	material.set_shader_parameter("mark_kind", {"bite": 1, "scratch": 2}.get(kind, 0))
	material.set_shader_parameter("dry", 0.0)
	material.set_shader_parameter("opacity", 1.0)
	var pose := local_pose.scaled_local(Vector3.ONE * clampf(size, 0.04, 0.4))
	slot.merge({"active": true, "id": _serial, "age": 0.0, "anchor": weakref(anchor), "pose": pose}, true)
	var node: MeshInstance3D = slot["node"]
	node.global_transform = anchor.global_transform * pose
	node.visible = anchor.is_visible_in_tree()
	return _serial


func _process(delta: float) -> void:
	advance(delta)


func advance(delta: float) -> void:
	if FxState.blood_level == FxState.BloodLevel.OFF:
		clear()
		return
	var dt := maxf(delta, 0.0)
	clock += dt
	splat_material.set_shader_parameter("now", clock)
	_step_drops(dt)
	for slot in body_marks:
		if not bool(slot["active"]):
			continue
		var anchor: Node3D = slot["anchor"].get_ref()
		slot["age"] = float(slot["age"]) + dt
		if not is_instance_valid(anchor) or float(slot["age"]) >= STAIN_SECONDS:
			slot["active"] = false
			slot["node"].visible = false
			continue
		slot["node"].visible = anchor.is_visible_in_tree()
		slot["node"].global_transform = anchor.global_transform * slot["pose"]
		slot["material"].set_shader_parameter("dry", minf(1.0, float(slot["age"]) / DRY_SECONDS))


## Small steps so a fast drop cannot pass through the floor between frames.
func _step_drops(dt: float) -> void:
	if drops.is_empty():
		return
	var left := dt
	while left > 0.0 and not drops.is_empty():
		var h := minf(left, 1.0 / 60.0)
		left -= h
		for i in range(drops.size() - 1, -1, -1):
			var d: Dictionary = drops[i]
			if d.has("puff"):
				d["age"] = float(d["age"]) + h
				d["pos"] = d["pos"] + d["vel"] * h
				d["vel"] = d["vel"] * 0.85
				if float(d["age"]) >= PUFF_SECONDS:
					drops.remove_at(i)
				continue
			d["vel"] = d["vel"] + Vector3.DOWN * GRAVITY * h
			d["pos"] = d["pos"] + d["vel"] * h
			if d["pos"].y <= d["floor"]:
				if d["land"]:
					_land(d)
				drops.remove_at(i)
	_sync_drops()


## Where a drop lands it leaves a mark stretched the way it was flying.
func _land(d: Dictionary) -> void:
	var vel: Vector3 = d["vel"]
	var flat := Vector3(vel.x, 0.0, vel.z)
	var speed := flat.length()
	var at := Vector3(d["pos"].x, d["floor"], d["pos"].z)
	var can_land: Callable = d.get("can_land", Callable())
	if can_land.is_valid() and not bool(can_land.call(at)):
		# Spend _write's floor angle so later sprays keep the same dice.
		_rng.randf_range(0.0, TAU)
		return
	var width := float(d["mark"]) * 1.6 * sqrt(FxState.blood_scale())
	var stretch := 1.0 + minf(speed * 0.35, 1.4)
	_write(at, Vector3.UP, Vector2(width * stretch, width), flat, Kind.DROP, bool(d["snow"]), 0.85, float(d["seed"]))


func _write(at: Vector3, normal: Vector3, size: Vector2, along: Vector3, kind: int, on_snow: bool, strength: float, seed_value: float = -1.0) -> Dictionary:
	var n := normal.normalized() if normal.length_squared() > 0.0001 else Vector3.UP
	var basis := wall_basis(n) if kind == Kind.WALL else floor_basis(n, along, _rng.randf_range(0.0, TAU))
	basis = Basis(basis.x * size.x, basis.y, basis.z * size.y)
	var index := _written % MAX_SPLATS
	_written += 1
	_serial += 1
	var s := seed_value if seed_value >= 0.0 else _rng.randf()
	var lift := 0.012 + 0.0004 * float(index % 8)
	var xf := Transform3D(basis, at + n * lift)
	var custom := Color(s, clock, float(kind) + (0.5 if on_snow else 0.0), strength)
	var mm := splats.multimesh
	mm.set_instance_transform(index, xf)
	mm.set_instance_custom_data(index, custom)
	mm.visible_instance_count = mini(_written, MAX_SPLATS)
	if records.size() <= index:
		records.resize(index + 1)
	records[index] = {"xf": xf, "custom": custom}
	return {"id": _serial, "index": index, "kind": kind, "size": size, "snow": on_snow, "seed": s}


func _sync_drops() -> void:
	var dm := drops_node.multimesh
	for i in range(drops.size()):
		var d: Dictionary = drops[i]
		var vel: Vector3 = d["vel"]
		var colour := FRESH
		var radius := float(d["size"])
		if d.has("puff"):
			var t := clampf(float(d["age"]) / PUFF_SECONDS, 0.0, 1.0)
			radius = -radius * lerpf(0.4, 1.0, t)
			colour.a = 0.6 * (1.0 - t)
		dm.set_instance_transform(i, Transform3D(Basis.IDENTITY, d["pos"]))
		dm.set_instance_custom_data(i, Color(vel.x, vel.y, vel.z, radius))
		dm.set_instance_color(i, colour)
	dm.visible_instance_count = drops.size()
	if drops.is_empty():
		FxState.release_particles(drops_node)
	else:
		FxState.lease_particles(drops_node, drops.size())


func splat_count() -> int:
	return mini(_written, MAX_SPLATS)


## Drops still in the air (the puff at the wound is not one).
func drop_count() -> int:
	var n := 0
	for d in drops:
		if not d.has("puff"):
			n += 1
	return n


## Marks still on the ground, oldest first (index in the MultiMesh).
func splat_order() -> Array[int]:
	var order: Array[int] = []
	var n := splat_count()
	for k in range(n):
		order.append((_written - n + k) % MAX_SPLATS)
	return order


func clear() -> void:
	drops.clear()
	if is_instance_valid(drops_node):
		drops_node.multimesh.visible_instance_count = 0
		FxState.release_particles(drops_node)
	if is_instance_valid(splats):
		splats.multimesh.visible_instance_count = 0
	records.clear()
	_written = 0
	clock = 0.0
	if splat_material:
		splat_material.set_shader_parameter("now", 0.0)
	for slot in body_marks:
		slot["active"] = false
		slot["node"].visible = false


static func _oldest_or_free(slots: Array[Dictionary]) -> Dictionary:
	var oldest := {}
	for slot in slots:
		if not bool(slot["active"]):
			return slot
		if oldest.is_empty() or int(slot["id"]) < int(oldest["id"]):
			oldest = slot
	return oldest


## A floor mark: +Y is the surface normal, +X runs along `along` (or a random turn).
static func floor_basis(normal: Vector3, along: Vector3, turn: float) -> Basis:
	var x := along - normal * along.dot(normal)
	if x.length_squared() < 0.0001:
		var side := Vector3.RIGHT if absf(normal.dot(Vector3.RIGHT)) < 0.95 else Vector3.FORWARD
		x = (side - normal * side.dot(normal)).rotated(normal, turn)
	x = x.normalized()
	return Basis(x, normal, x.cross(normal).normalized())


## A wall mark: +Y is the wall's normal and +X points up the wall, so drips run toward -X.
static func wall_basis(normal: Vector3) -> Basis:
	var x := Vector3.UP - normal * Vector3.UP.dot(normal)
	if x.length_squared() < 0.0001:
		x = Vector3.FORWARD
	x = x.normalized()
	return Basis(x, normal, x.cross(normal).normalized())
