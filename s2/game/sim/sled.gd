extends RefCounted
## A field-made sled owns its cargo; no body, path solid or train stock (sled.md 2.1-2.5).

const Carry = preload("res://game/sim/carry.gd")
const FieldGrid = preload("res://game/world/field_grid.gd")
const LIMIT: float = 12.0
const CRAFT_SECONDS: float = 30.0
const ROPE_LENGTH: float = 1.35
const ROPE_EPS: float = 0.001 # Vector3 roundoff at the taut rope, including a JSON round trip.
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
	p.sled_id = id
	p.sled_stowed_for = id
	p.sled_weapon_stowed = true
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
	p.sled_id = 0
	clear_attack(p)
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
	var at: Vector3 = row["pos"]
	var gap: Vector3 = dest - at
	if gap.length() <= ROPE_LENGTH + ROPE_EPS:
		return
	var next: Vector3 = dest - gap.normalized() * ROPE_LENGTH
	if at.distance_to(next) > ROPE_LENGTH + ROPE_EPS or not path_clear(game, at, next) or not path_clear(game, next, dest):
		game.actions.release_sled(p, true, "썰매가 걸려 줄을 놓았다")
		return
	row["pos"] = next


## Reconnect only mutually matching, living player identities. Never consume or roll here.
static func reconcile(game: Variant) -> void:
	var used: Dictionary = {}
	for row: Dictionary in game.sleds:
		row["items"] = (row.get("items", {}) as Dictionary).duplicate(true)
		var puller: Variant = null
		for p: Variant in game.people:
			if String(p.pid) == String(row.get("puller", "")):
				puller = p
		var id: int = int(row["id"])
		if (puller == null or puller != game.player or not puller.can_act() or puller.sled_id != id
			or used.has(String(puller.pid)) or int(row["level"]) != 0 or not outside(game, row["pos"])
			or not outside(game, puller.position) or puller.position.distance_to(row["pos"]) > ROPE_LENGTH + ROPE_EPS
			or not path_clear(game, row["pos"], puller.position)):
			row["puller"] = ""
		else:
			used[String(puller.pid)] = id
			puller.sled_weapon_stowed = true
			puller.sled_stowed_for = id
			clear_attack(puller)
			connect_hands(game, puller)
		game.next_sled_id = maxi(game.next_sled_id, id + 1)
	for p: Variant in game.people:
		if not used.has(String(p.pid)):
			p.sled_id = 0
		if p.sled_weapon_stowed and find(game, p.sled_stowed_for).is_empty():
			p.sled_weapon_stowed = false
			p.sled_stowed_for = 0
			if p.action == "sled_rearm":
				p.cancel_action()
		if not p.can_act() and not p.sled_job.is_empty():
			p.sled_job = {}
			if p.action == "sled_rearm" or p.action_done.get_method() == "_sled_crafted":
				p.cancel_action()
		if p.weapon_mesh != null and p.sled_weapon_stowed:
			p.weapon_mesh.visible = false
