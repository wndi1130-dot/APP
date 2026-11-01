extends RefCounted
## A field-made sled owns its cargo; no body, path solid or train stock (sled.md 2.1-2.5).

const Carry = preload("res://game/sim/carry.gd")
const FieldGrid = preload("res://game/world/field_grid.gd")
const W = preload("res://game/sim/weapons.gd")
const LIMIT: float = 12.0
const CRAFT_SECONDS: float = 30.0
const ROPE_LENGTH: float = 1.35
const ROPE_EPS: float = 0.001 # Vector3 roundoff at the taut rope, including a JSON round trip.
const TRAIL_MAX_POINTS: int = 16
const SNOW_MULT: float = 0.9
const LOAD_MULT: Array[float] = [1.0, 0.9, 0.7, 0.0]


static func find(game: Variant, id: int) -> Dictionary:
	for row: Dictionary in game.sleds:
		if int(row["id"]) == id:
			return row
	return {}


static func weight(row: Dictionary) -> float:
	return Carry.total_weight(row.get("items", {}))


static func state(row: Dictionary) -> int:
	return Carry.state(weight(row), LIMIT)


static func speed_mult(game: Variant, p: Variant) -> float:
	if p.sled_id == 0:
		return 1.0
	var row: Dictionary = find(game, p.sled_id)
	return LOAD_MULT[state(row)] * SNOW_MULT if not row.is_empty() else 1.0


static func outside(game: Variant, at: Vector3) -> bool:
	var cell: Vector2i = FieldGrid.cell_of(at)
	return game.level_of(at) == 0 and game.grid.inside(cell) and not game.grid.indoor(cell)


static func walkable(game: Variant, cell: Vector2i) -> bool:
	return game.grid.inside(cell) and not game.grid.indoor(cell) and game.grid.people_can_walk(cell) and not game.grid.blocks_body(cell)


## Supercover traversal includes both side cells at a corner, even on a long tick.
static func path_clear(game: Variant, from: Vector3, to: Vector3) -> bool:
	if not outside(game, from) or not outside(game, to):
		return false
	var cell: Vector2i = FieldGrid.cell_of(from)
	var end: Vector2i = FieldGrid.cell_of(to)
	var delta: Vector3 = to - from
	var sx: int = signi(end.x - cell.x)
	var sy: int = signi(end.y - cell.y)
	var tx: float = INF if sx == 0 else (float(cell.x + (1 if sx > 0 else 0)) - from.x) / delta.x
	var ty: float = INF if sy == 0 else (float(cell.y + (1 if sy > 0 else 0)) - from.z) / delta.z
	var dx: float = INF if sx == 0 else absf(1.0 / delta.x)
	var dy: float = INF if sy == 0 else absf(1.0 / delta.z)
	for _crossing: int in range(absi(end.x - cell.x) + absi(end.y - cell.y) + 1):
		if not walkable(game, cell):
			return false
		if cell == end:
			return true
		if is_equal_approx(tx, ty):
			if not walkable(game, cell + Vector2i(sx, 0)) or not walkable(game, cell + Vector2i(0, sy)):
				return false
			cell += Vector2i(sx, sy)
			tx += dx
			ty += dy
		elif tx < ty:
			cell.x += sx
			tx += dx
		else:
			cell.y += sy
			ty += dy
	return false


## The sled's own cell in an unloading area on the ground floor (sled.md 2.1).
static func in_unloading(game: Variant, row: Dictionary) -> bool:
	if row.is_empty() or int(row["level"]) != 0 or game.level_of(row["pos"]) != 0:
		return false
	var cell: Vector2i = FieldGrid.cell_of(row["pos"])
	for area: Rect2i in game.data.get("unloading", []):
		if area.has_point(cell):
			return true
	return false


## The leaving card's lines: a sled out of the unloading area stays with its load,
## one in it goes aboard (sled.md 2.1). "" with no sled.
static func leaving_note(game: Variant) -> String:
	var sleds_left: int = 0
	var things_left: int = 0
	var things_aboard: int = 0
	for row: Dictionary in game.sleds:
		if in_unloading(game, row):
			things_aboard += count(row)
		else:
			sleds_left += 1
			things_left += count(row)
	var text: String = ""
	if things_aboard > 0:
		text += "\n하역 칸 안 썰매의 짐 %d개는 같이 싣는다." % things_aboard
	if sleds_left > 0:
		text += "\n하역 칸 밖 썰매 %d대·짐 %d개를 두고 간다." % [sleds_left, things_left]
	return text


## How many things the sled holds (counts, not weight).
static func count(row: Dictionary) -> int:
	var n: int = 0
	for id: String in row.get("items", {}):
		n += int(row["items"][id])
	return n


static func reachable(game: Variant, p: Variant, row: Dictionary) -> bool:
	return (p == game.player and p.can_act() and not game.ended and not row.is_empty()
		and int(row["level"]) == game.level_of(p.position) and game.actions._in_reach(p, row["pos"]))


static func materials(p: Variant) -> bool:
	return int(p.items.get("plank", 0)) >= 2 and int(p.items.get("cloth", 0)) >= 1


static func can_craft(game: Variant, p: Variant) -> bool:
	return (p == game.player and p.can_act() and not game.ended and p.action == ""
		and not game.actions.striking(p) and p.reload_t <= 0.0 and not p.aim.active
		and game.sleds.is_empty() and outside(game, p.position) and materials(p))


## A deterministic adjacent empty cell: looking for a place never rolls the dice.
static func placement(game: Variant, p: Variant) -> Variant:
	var here: Vector2i = FieldGrid.cell_of(p.position)
	for offset: Vector2i in [Vector2i(0, 1), Vector2i(1, 0), Vector2i(0, -1), Vector2i(-1, 0), Vector2i(1, 1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(-1, -1)]:
		var cell: Vector2i = here + offset
		var at: Vector3 = FieldGrid.center(cell)
		if not walkable(game, cell) or game.grid.solid_at(cell) != FieldGrid.Solid.NONE or not game.actions._in_reach(p, at):
			continue
		var occupied: bool = false
		for person: Variant in game.people:
			if game.level_of(person.position) == 0 and FieldGrid.cell_of(person.position) == cell:
				occupied = true
		for item: Dictionary in game.ground_items:
			if game.level_of(item["pos"]) == 0 and FieldGrid.cell_of(item["pos"]) == cell and int(item.get("n", 0)) > 0:
				occupied = true
		for kind: String in ["containers", "spots"]:
			for key: Variant in game.data.get(kind, {}):
				var object: Dictionary = game.data[kind][key]
				if int(object.get("level", 0)) == 0 and object.get("cell") == cell:
					occupied = true
		for dead: Dictionary in game.zombies.list:
			if game.level_of(dead["pos"]) == 0 and FieldGrid.cell_of(dead["pos"]) == cell:
				occupied = true
		for prop: Dictionary in game.data.get("props", []):
			if int(prop.get("level", 0)) == 0 and prop.get("cell") == cell:
				occupied = true
		if not occupied:
			return at
	return null


static func can_pull(game: Variant, p: Variant, row: Dictionary) -> bool:
	return (reachable(game, p, row) and outside(game, p.position) and outside(game, row["pos"])
		and p.sled_id == 0 and not p.sled_weapon_stowed and String(row["puller"]) == "" and p.action == ""
		and not game.actions.striking(p) and p.reload_t <= 0.0 and p.jam_t <= 0.0 and not p.aim.active
		and p.carrying_wounded == null and not Carry.has_big(p.items)
		and p.position.distance_to(row["pos"]) <= ROPE_LENGTH + ROPE_EPS and path_clear(game, row["pos"], p.position))


static func clear_attack(p: Variant) -> void:
	p.aim.stop()
	p.hold_attack = false
	p.target_zombie = {}
	p.target_person = null


static func connect_hands(game: Variant, p: Variant) -> void:
	var callback: Callable = game.actions._sled_hands_work
	if not p.sled_hands_work.is_connected(callback):
		p.sled_hands_work.connect(callback)


static func pull(game: Variant, p: Variant, id: int) -> bool:
	var row: Dictionary = find(game, id)
	if not can_pull(game, p, row):
		return false
	p.stop()
	p.brain.erase("goal")
	connect_hands(game, p)
	row["puller"] = String(p.pid)
	row["trail"] = PackedVector3Array([row["pos"], p.position])
	p.sled_id = id
	p.sled_stowed_for = id
	p.sled_weapon_stowed = true
	p.sled_rearm_t = 0.0
	p.drive_speed = 0.0
	clear_attack(p)
	game.hud.auto_aim = false
	game.hud.aiming = false
	game.hud.aim_target = null
	if p.weapon_mesh != null:
		p.weapon_mesh.visible = false
	return true


## Dropping the rope never moves an item or edits the weapon slot (sled.md 2.2).
static func detach(game: Variant, p: Variant) -> bool:
	if p.sled_id == 0:
		return false
	var row: Dictionary = find(game, p.sled_id)
	if not row.is_empty() and String(row["puller"]) == String(p.pid):
		row["puller"] = ""
		row.erase("trail")
	p.sled_id = 0
	p.sled_rearm_t = Carry.swap_time("belt", p.carry_state())
	clear_attack(p)
	return true


## Drawing uses the same body rate as swapping, without taking the walking action.
static func tick_rearm(p: Variant, delta: float) -> void:
	if p.sled_rearm_t <= 0.0:
		return
	p.sled_rearm_t = maxf(0.0, p.sled_rearm_t - delta * float(p.mults()["swap"]))
	if p.sled_rearm_t == 0.0:
		p.sled_weapon_stowed = false
		p.sled_stowed_for = 0
		p._refresh_weapon_mesh()


static func trail_length(trail: PackedVector3Array) -> float:
	var length: float = 0.0
	for index: int in range(1, trail.size()):
		length += trail[index - 1].distance_to(trail[index])
	return length


## Visit the whole saved route from the front, preserving both attached ends.
static func simplify_trail(game: Variant, stored: PackedVector3Array) -> PackedVector3Array:
	var trail: PackedVector3Array = PackedVector3Array()
	for at: Vector3 in stored:
		trail.append(at)
		while trail.size() >= 3 and path_clear(game, trail[-3], trail[-1]):
			trail.remove_at(trail.size() - 2)
	return trail


## A bent rope follows only verified outdoor segments, with both ends attached.
static func trail_clear(game: Variant, row: Dictionary, puller_at: Vector3) -> bool:
	var stored: Variant = row.get("trail", PackedVector3Array())
	if not stored is PackedVector3Array:
		return false
	var trail: PackedVector3Array = stored
	if trail.size() < 2 or trail[0].distance_to(row["pos"]) > ROPE_EPS or trail[-1].distance_to(puller_at) > ROPE_EPS:
		return false
	if trail_length(trail) > ROPE_LENGTH + ROPE_EPS:
		return false
	for index: int in range(1, trail.size()):
		if not path_clear(game, trail[index - 1], trail[index]):
			return false
	return true


## Called after sliding, before committing either kind of body movement.
static func before_move(game: Variant, p: Variant, dest: Vector3) -> void:
	if p.sled_id == 0:
		return
	var row: Dictionary = find(game, p.sled_id)
	if row.is_empty():
		game.actions.release_sled(p)
		return
	if not outside(game, dest):
		game.actions.release_sled(p, true, "썰매는 밖에 두었다")
		return
	if not trail_clear(game, row, p.position) or not path_clear(game, p.position, dest):
		game.actions.release_sled(p, true, "썰매가 걸려 줄을 놓았다")
		return
	if dest == p.position:
		return
	var trail: PackedVector3Array = row["trail"].duplicate()
	trail.append(dest)
	# Keep only bends needed by walls before pulling any excess from the front.
	while trail.size() >= 3 and path_clear(game, trail[-3], trail[-1]):
		trail.remove_at(trail.size() - 2)
	var excess: float = maxf(0.0, trail_length(trail) - ROPE_LENGTH)
	var first: int = 0
	while excess > 0.0 and first < trail.size() - 1:
		var segment: float = trail[first].distance_to(trail[first + 1])
		if segment <= excess:
			excess -= segment
			first += 1
		else:
			trail[first] = trail[first].lerp(trail[first + 1], excess / segment)
			excess = 0.0
	trail = trail.slice(first)
	if trail.size() > TRAIL_MAX_POINTS:
		trail = simplify_trail(game, trail)
		if trail.size() > TRAIL_MAX_POINTS:
			game.actions.release_sled(p, true, "썰매가 걸려 줄을 놓았다")
			return
	row["pos"] = trail[0]
	row["trail"] = trail


## Exact resume restores sled rows twice but keeps the same ground array.
## This transient ledger prevents duplicate drops without adding save fields.
static func _restore_body_cargo(game: Variant, row: Dictionary) -> void:
	var cargo: Dictionary = row["items"]
	for item: String in cargo.keys():
		if game.actions.goes_to_train(item):
			continue
		var restored: Dictionary = game.get_meta("sled_cargo_restore", {})
		if restored.is_empty() or not is_same(restored["ground"], game.ground_items):
			restored = {"ground": game.ground_items, "counts": {}}
			game.set_meta("sled_cargo_restore", restored)
		var counts: Dictionary = restored["counts"]
		var key: String = "%d:%s" % [int(row["id"]), item]
		var cargo_count: int = int(cargo[item])
		var remaining: int = maxi(0, cargo_count - int(counts.get(key, 0)))
		if W.is_known(item):
			for _piece: int in remaining:
				game.ground_items.append({"pos": row["pos"], "id": item, "n": 1,
					"weapon": {"id": item, "quality": "factory", "condition": 1.0, "loaded": 0}})
		elif remaining > 0:
			game.ground_items.append({"pos": row["pos"], "id": item, "n": remaining})
		counts[key] = maxi(cargo_count, int(counts.get(key, 0)))
		cargo.erase(item)


## Reconnect only mutually matching, living player identities. Never consume or roll here.
static func reconcile(game: Variant) -> void:
	var used: Dictionary = {}
	for row: Dictionary in game.sleds:
		row["items"] = (row.get("items", {}) as Dictionary).duplicate(true)
		_restore_body_cargo(game, row)
		var puller: Variant = null
		for p: Variant in game.people:
			if String(p.pid) == String(row.get("puller", "")):
				puller = p
		var id: int = int(row["id"])
		# Old saves have no trail: their straight attachment still has to be clear.
		if not row.has("trail") and puller != null:
			row["trail"] = PackedVector3Array([row["pos"], puller.position])
		# Invalid old lengths or endpoints still detach, even if a shortcut could hide them.
		var valid_trail: bool = puller != null and trail_clear(game, row, puller.position)
		if row.get("trail") is PackedVector3Array:
			var trail: PackedVector3Array = simplify_trail(game, row["trail"])
			row["trail"] = trail
			if trail.size() > TRAIL_MAX_POINTS and puller != null and puller == game.player and puller.sled_id == id:
				game.actions.release_sled(puller, true, "썰매가 걸려 줄을 놓았다")
		if (puller == null or puller != game.player or not puller.can_act() or puller.sled_id != id
			or used.has(String(puller.pid)) or int(row["level"]) != 0 or not outside(game, row["pos"])
			or not outside(game, puller.position) or not valid_trail):
			row["puller"] = ""
			row.erase("trail")
		else:
			used[String(puller.pid)] = id
			puller.sled_weapon_stowed = true
			puller.sled_stowed_for = id
			puller.sled_rearm_t = 0.0
			clear_attack(puller)
			connect_hands(game, puller)
		game.next_sled_id = maxi(game.next_sled_id, id + 1)
	for p: Variant in game.people:
		if not used.has(String(p.pid)):
			p.sled_id = 0
		if p.sled_weapon_stowed and find(game, p.sled_stowed_for).is_empty():
			p.sled_weapon_stowed = false
			p.sled_stowed_for = 0
			p.sled_rearm_t = 0.0
		elif p.sled_weapon_stowed and p.sled_id == 0 and p.sled_rearm_t <= 0.0:
			p.sled_rearm_t = Carry.swap_time("belt", p.carry_state())
		if not p.can_act() and not p.sled_job.is_empty():
			p.sled_job = {}
			if p.action_done.get_method() == "_sled_crafted":
				p.cancel_action()
		if p.weapon_mesh != null and p.sled_weapon_stowed:
			p.weapon_mesh.visible = false
