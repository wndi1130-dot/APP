extends Node
## J08: a few movable wooden furnishings, their contents, and contained stove fuel.
## No random loot roll, free carrying, fire spread or changes to the stop clock.

const Grid = preload("res://game/world/field_grid.gd")
const Rooms = preload("res://game/world/room_furnish.gd")
const Building = preload("res://game/sim/building_rules.gd")
const SimNoise = preload("res://game/sim/noise.gd")
const Weapons = preload("res://game/sim/weapons.gd")
const Clock = preload("res://game/sim/field_clock.gd")
const PropModels = preload("res://game/world/prop_models.gd")

const PUSH_KINDS: Dictionary = {"wardrobe": 9, "bookcase": 6, "shelf": 3}
const WOOD_KINDS: Array[String] = ["wardrobe", "bookcase", "shelf", "bed", "bench", "dining_set", "blanket_chest", "crate_stack"]
const LEGACY_KINDS: Dictionary = {"wardrobe": "wardrobe", "bookcase": "bookcase", "shop_shelf": "shelf", "dining_set": "dining_set"}
const LEGACY_BOXES: Dictionary = {"waiting_bench": "bench", "shed_crates": "crate_stack"}
const PUSH_REACH: float = 6.0
const USE_REACH: float = 1.7
const PUSH_BASE_SECONDS: float = 4.0
const PUSH_CELL_SECONDS: float = 2.0
const PUSH_NOISE: int = SimNoise.Level.NORMAL
const BREAK_BASE_SECONDS: float = 7.5
const BREAK_CELL_SECONDS: float = 2.5
const BREAK_NOISE: int = SimNoise.Level.LOUD
const PLANKS_PER_CELL: int = 1
const HEAP_SEARCH_SECONDS: float = 1.0
const FUEL_SECONDS: Dictionary = {"plank": 60.0, "wood": 120.0}
const FUEL_CAP: float = 600.0
const LIGHT_SECONDS: float = 2.0
const LIGHT_NOISE: int = SimNoise.Level.QUIET
const LIGHT_REACH: float = 4.0
const LIGHT_STRENGTH: float = 0.7
const DIRS: Array[Vector2i] = [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN, Vector2i.UP]

var game
var work: Dictionary = {}


## A stove uses the existing clock's exact advance, before the bodies read
## warmth. Only installed on first fueling; all clock values/rates are kept.
class FuelClock extends Clock:
	var stoves: Array = []
	var expired: Callable

	func advance(real_delta: float) -> void:
		super.advance(real_delta)
		for stove: Dictionary in stoves:
			if stove.has("fuel_until") and bool(stove["lit"]) and elapsed >= float(stove["fuel_until"]):
				stove["lit"] = false
				if expired.is_valid():
					expired.call(stove)


## Hand-laid maps represent furniture by their container and its model, not
## props. Describe those same one-cell objects lazily; do not repaint their
## original map or change their contents before a player actually moves one.
static func objects(field) -> Array:
	if field.data.has("props"):
		return field.data["props"]
	var props: Array = []
	for box: Dictionary in field.data["containers"].values():
		var model := PropModels.kind_for(String(box["id"]), String(box.get("name", "")))
		var kind := String(LEGACY_KINDS.get(model, LEGACY_BOXES.get(box["id"], "")))
		if kind == "":
			continue
		box["furniture"] = kind
		box["object_legacy"] = true
		props.append({"kind": kind, "rect": Rect2i(box["cell"], Vector2i.ONE),
			"level": box.get("level", 0), "building": box.get("building", -1),
			"legacy_model": PropModels.DIR + model + ".glb" if model != "" else ""})
	field.data["props"] = props
	return props


static func for_game(field):
	if field.has_meta("object_rules"):
		return field.get_meta("object_rules")
	var node = load("res://game/sim/object_rules.gd").new()
	node.game = field
	node.name = "ObjectRules"
	field.add_child(node)
	field.set_meta("object_rules", node)
	return node


static func area(prop: Dictionary) -> int:
	var r: Rect2i = prop["rect"]
	return maxi(1, r.size.x * r.size.y)


static func push_seconds(prop: Dictionary) -> float:
	return PUSH_BASE_SECONDS + PUSH_CELL_SECONDS * area(prop)


static func break_seconds(prop: Dictionary) -> float:
	return BREAK_BASE_SECONDS + BREAK_CELL_SECONDS * area(prop)


static func plank_yield(prop: Dictionary) -> int:
	return area(prop) * PLANKS_PER_CELL


static func break_tool(p) -> bool:
	for hand: Dictionary in p.hands:
		if String(hand["id"]) == "axe" or bool(Weapons.get_data(hand["id"]).get("pry", false)):
			return true
	return false


static func cells(r: Rect2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			out.append(Vector2i(x, y))
	return out


static func boxes_of(data: Dictionary, prop: Dictionary) -> Array:
	var out: Array = []
	for box: Dictionary in data["containers"].values():
		if box.has("furniture") and int(box.get("level", 0)) == int(prop.get("level", 0)) \
				and String(box["furniture"]) == String(prop["kind"]) and (prop["rect"] as Rect2i).has_point(box["cell"]):
			out.append(box)
	return out


static func room_map(field, lv: int) -> Dictionary:
	if not field.data.has("_object_rooms"):
		field.data["_object_rooms"] = {}
	var cache: Dictionary = field.data["_object_rooms"]
	if not cache.has(lv):
		cache[lv] = Rooms.rooms_of(field.levels[lv])
	return cache[lv]


static func room_at(field, lv: int, c: Vector2i) -> int:
	var g = field.levels[lv]
	return int(room_map(field, lv)["of"][g.index(c)]) if g.inside(c) else -1


## The moving object and its own boxes may occupy their previous cells.
## People (including the pusher), the dead, stairs and all other props may not.
static func free_rect(field, prop: Dictionary, r: Rect2i, room: int) -> bool:
	var lv := int(prop.get("level", 0))
	var g = field.levels[lv]
	var old: Rect2i = prop["rect"]
	for c in cells(r):
		if not g.inside(c) or room_at(field, lv, c) != room or room < 0:
			return false
		var solid: int = g.solid_at(c)
		if solid != Grid.Solid.NONE and not (old.has_point(c) and solid == Grid.Solid.LOW):
			return false
	for other: Dictionary in field.data.get("props", []):
		if not is_same(other, prop) and not bool(other.get("fallen", false)) and int(other.get("level", 0)) == lv \
				and Rooms.blocks(String(other.get("kind", "")), lv) \
				and other.get("rect") is Rect2i and r.intersects(other["rect"]):
			return false
	var own := boxes_of(field.data, prop)
	for box: Dictionary in field.data["containers"].values():
		if int(box.get("level", 0)) == lv and r.has_point(box["cell"]) and not own.any(func(b): return is_same(b, box)):
			return false
	for stair: Dictionary in field.stairs:
		if (stair["low"] == lv or stair["high"] == lv) and r.has_point(stair["cell"]):
			return false
	for person in field.people:
		if person.is_alive() and field.level_of(person.position) == lv and r.has_point(Grid.cell_of(person.position)):
			return false
	for z: Dictionary in field.zombies.list:
		if field.zombies.active(z) and field.level_of(z["pos"]) == lv and r.has_point(Grid.cell_of(z["pos"])):
			return false
	return true


static func push_plan(field, p, c: Vector2i) -> Dictionary:
	var props := objects(field)
	var lv: int = field.level_of(p.position)
	var g = field.levels[lv]
	var door: Dictionary = g.doors.get(c, {})
	if door.is_empty() or String(door.get("state", "")) not in ["closed", "locked"] \
			or Building.has_brace(door) or bool(door.get("busy", false)) or field.lift(c, lv).distance_to(p.position) > USE_REACH:
		return {}
	var face: int = g.face_toward(c, p.position)
	var front: Vector2i = g.faces(c)[face]
	var room := room_at(field, lv, front)
	if room < 0 or room_at(field, lv, Grid.cell_of(p.position)) != room:
		return {}
	var normal: Vector2i = front - c
	var along := Vector2i(1, 0) if normal.y != 0 else Vector2i(0, 1)
	var best: Dictionary = {}
	var nearest := INF
	for prop: Dictionary in props:
		if not PUSH_KINDS.has(prop.get("kind", "")) or int(prop.get("level", 0)) != lv \
				or bool(prop.get("fallen", false)) or bool(prop.get("busy", false)) or prop.has("brace_door"):
			continue
		var old: Rect2i = prop["rect"]
		var dist := Vector2(old.get_center() - front).length()
		if old.has_point(Grid.cell_of(p.position)) or dist > PUSH_REACH or dist >= nearest \
				or not cells(old).all(func(k): return room_at(field, lv, k) == room):
			continue
		if boxes_of(field.data, prop).any(func(b): return bool(b.get("busy", false))):
			continue
		var length := maxi(old.size.x, old.size.y)
		var depth := mini(old.size.x, old.size.y)
		var size := Vector2i(length, depth) if normal.y != 0 else Vector2i(depth, length)
		for shift in range(length):
			var corner := front - along * shift + Vector2i(mini(normal.x, 0), mini(normal.y, 0)) * (depth - 1)
			var target := Rect2i(corner, size)
			if free_rect(field, prop, target, room):
				best = {"prop": prop, "rect": target, "face": face, "door": c, "level": lv, "room": room}
				nearest = dist
				break
	return best


static func can_remove(field, p, c: Vector2i) -> bool:
	var lv: int = field.level_of(p.position)
	var g = field.levels[lv]
	var door: Dictionary = g.doors.get(c, {})
	return Building.has_brace(door) and int(door["brace"]["face"]) == g.face_toward(c, p.position) \
		and field.lift(c, lv).distance_to(p.position) <= USE_REACH


static func near_prop(field, p, prop: Dictionary) -> bool:
	if field.level_of(p.position) != int(prop.get("level", 0)):
		return false
	if not (prop["rect"] as Rect2i).grow(2).has_point(Grid.cell_of(p.position)):
		return false
	var g = field.grid_at(p.position)
	for c in cells(prop["rect"]):
		if field.lift(c, int(prop.get("level", 0))).distance_to(p.position) <= USE_REACH \
				and g.body_line_clear(Grid.cell_of(p.position), c):
			return true
	return false


static func can_break(field, p, prop: Dictionary) -> bool:
	return WOOD_KINDS.has(String(prop.get("kind", ""))) and not bool(prop.get("busy", false)) \
		and not boxes_of(field.data, prop).any(func(b): return bool(b.get("busy", false))) \
		and break_tool(p) and near_prop(field, p, prop)


static func fuel_item(p) -> String:
	for id: String in FUEL_SECONDS:
		if int(p.items.get(id, 0)) > 0:
			return id
	return ""


static func can_light(field, p, stove: Dictionary) -> bool:
	var at: Vector3 = field.lift(stove["cell"], int(stove.get("level", 0)))
	return fuel_item(p) != "" and not bool(stove.get("busy", false)) \
		and float(stove.get("fuel_until", 0.0)) - field.clock.elapsed < FUEL_CAP \
		and field.actions._in_reach(p, at)


func _process(_delta: float) -> void:
	# Observe field time, never wall time: pausing and slow motion stay in step.
	sync_stoves()
	_sync_light_floor()
	for id in work.keys():
		var p = instance_from_id(id)
		var w: Dictionary = work[id]
		if p == null or not is_instance_valid(p):
			w["target"]["busy"] = false
			_release_boxes(w)
			work.erase(id)
		elif p.action != "craft" or not is_same(p.action_busy, w["target"]):
			_release_boxes(w)
			work.erase(id)
		elif not _valid(p, w):
			p.cancel_action()
			_release_boxes(w)
			work.erase(id)


func _release_boxes(w: Dictionary) -> void:
	for box: Dictionary in w.get("boxes", []):
		box["busy"] = false


func _valid(p, w: Dictionary) -> bool:
	if not p.can_act() or p.body.injured_at != w["injured"] or p.body.wounds.size() != w["wounds"]:
		return false
	if w["kind"] == "light":
		return game.actions._in_reach(p, game.lift(w["target"]["cell"], w["level"]))
	if w["kind"] == "break":
		return break_tool(p) and near_prop(game, p, w["target"]) and w["target"]["rect"] == w["rect"]
	var g = game.levels[w["level"]]
	if w["kind"] == "remove" and (not Building.has_brace(g.doors[w["door"]]) \
			or not is_same(g.doors[w["door"]]["brace"]["prop"], w["target"])):
		return false
	return game.level_of(p.position) == w["level"] and g.face_toward(w["door"], p.position) == w["face"] \
		and game.lift(w["door"], w["level"]).distance_to(p.position) <= USE_REACH


func _start(p, target: Dictionary, kind: String, label: String, seconds: float, extra: Dictionary = {}) -> bool:
	if not p.can_act() or p.action != "" or game.actions.striking(p) or bool(target.get("busy", false)):
		return false
	var w := {"target": target, "kind": kind, "level": game.level_of(p.position),
		"injured": p.body.injured_at, "wounds": p.body.wounds.size(), "rect": target.get("rect", Rect2i())}
	w.merge(extra, true)
	var boxes: Array = [] if kind == "light" else boxes_of(game.data, target)
	if boxes.any(func(b): return bool(b.get("busy", false))):
		return false
	w["boxes"] = boxes
	for box: Dictionary in boxes:
		box["busy"] = true
	work[p.get_instance_id()] = w
	p.start_action("craft", label, seconds, _done.bind(p, w))
	target["busy"] = true
	p.action_busy = target
	return true


func push(p, c: Vector2i) -> void:
	var plan := push_plan(game, p, c)
	if plan.is_empty():
		return
	if _start(p, plan["prop"], "push", "가구로 문 막기", push_seconds(plan["prop"]), plan):
		game.make_sound(p.position, PUSH_NOISE, "pry", p)


func remove(p, c: Vector2i) -> void:
	if not can_remove(game, p, c):
		return
	var g = game.grid_at(p.position)
	var brace: Dictionary = g.doors[c]["brace"]
	var prop: Dictionary = brace["prop"]
	if _start(p, prop, "remove", "가구 치우기", push_seconds(prop), {"door": c, "face": brace["face"]}):
		game.make_sound(p.position, PUSH_NOISE, "pry", p)


func smash(p, prop: Dictionary) -> void:
	if not objects(game).any(func(q): return is_same(q, prop)):
		return
	if can_break(game, p, prop) and _start(p, prop, "break", "부수기", break_seconds(prop)):
		game.make_sound(p.position, BREAK_NOISE, "axe", p)
		# The generic sound router has no axe tag. Reuse the existing wooden
		# board impact for the player's ear; the rule sound is counted once.
		if game.audio != null:
			game.audio.door("wall", p.position, BREAK_NOISE)


func light(p, stove: Dictionary) -> void:
	sync_stoves()
	if can_light(game, p, stove) and _start(p, stove, "light", "난로 피우기", LIGHT_SECONDS):
		game.make_sound(p.position, LIGHT_NOISE, "pry", p)


func _done(p, w: Dictionary) -> void:
	var id: int = p.get_instance_id()
	if not work.has(id) or not is_same(work[id], w) or p.action != "":
		return
	work.erase(id)
	_release_boxes(w)
	if not _valid(p, w):
		return
	var target: Dictionary = w["target"]
	match w["kind"]:
		"push":
			var g = game.levels[w["level"]]
			var door: Dictionary = g.doors[w["door"]]
			if String(door["state"]) not in ["closed", "locked"] or bool(door.get("busy", false)) \
					or not free_rect(game, target, w["rect"], w["room"]):
				game.hud.toast("문 앞에 가구를 놓을 자리가 없다")
				return
			target["home_rect"] = target["rect"]
			target["home_facing"] = target.get("facing", 0)
			move_prop(target, w["rect"])
			target["brace_door"] = w["door"]
			Building.add_brace(door, w["face"], target, PUSH_KINDS[target["kind"]])
		"remove":
			var door: Dictionary = game.levels[w["level"]].doors[w["door"]]
			if not Building.has_brace(door) or not is_same(door["brace"]["prop"], target):
				return
			var dest := return_rect(target, w["door"])
			if dest.size == Vector2i.ZERO:
				game.hud.toast("가구를 치울 자리가 없다")
				return
			Building.remove_brace(door)
			target.erase("brace_door")
			move_prop(target, dest)
		"break":
			if not game.data["props"].any(func(q): return is_same(q, target)):
				return
			break_prop(p, target)
		"light":
			var fuel := fuel_item(p)
			if fuel == "" or float(target.get("fuel_until", 0.0)) - game.clock.elapsed >= FUEL_CAP:
				return
			if p.take_item(fuel):
				_bind_fuel_clock()
				target["fuel_until"] = game.clock.elapsed + minf(FUEL_CAP, maxf(0.0, float(target.get("fuel_until", 0.0)) - game.clock.elapsed) + float(FUEL_SECONDS[fuel]))
				target["lit"] = true
				stove_changed(target)


func return_rect(prop: Dictionary, c: Vector2i) -> Rect2i:
	var lv := int(prop.get("level", 0))
	var old: Rect2i = prop["rect"]
	var room := room_at(game, lv, old.position)
	var home: Rect2i = prop.get("home_rect", Rect2i())
	if home.size != Vector2i.ZERO and free_rect(game, prop, home, room):
		return home
	return side_rect(prop, c)


func side_rect(prop: Dictionary, c: Vector2i) -> Rect2i:
	var lv := int(prop.get("level", 0))
	var old: Rect2i = prop["rect"]
	var room := room_at(game, lv, old.position)
	var normal: Vector2i = game.levels[lv].faces(c)[0] - c
	var along := Vector2i(1, 0) if normal.y != 0 else Vector2i(0, 1)
	for distance in range(1, maxi(old.size.x, old.size.y) + 1):
		for sign0 in [1, -1]:
			var dest := Rect2i(old.position + along * sign0 * distance, old.size)
			if dest.has_point(game.levels[lv].faces(c)[0]) or dest.has_point(game.levels[lv].faces(c)[1]):
				continue
			if free_rect(game, prop, dest, room):
				return dest
	return Rect2i()


func _clear_prop(prop: Dictionary) -> void:
	var lv := int(prop.get("level", 0))
	var g = game.levels[lv]
	for c in cells(prop["rect"]):
		if g.solid_at(c) == Grid.Solid.LOW:
			g.set_solid(c, Grid.Solid.NONE)
			g.refresh_cell(c)
	if lv == 0:
		game.data["low_blocks"].erase(prop["rect"])


func move_prop(prop: Dictionary, dest: Rect2i, fallen: bool = false) -> void:
	var boxes := boxes_of(game.data, prop)
	var old: Rect2i = prop["rect"]
	var lv := int(prop.get("level", 0))
	_clear_prop(prop)
	prop["rect"] = dest
	prop["fallen"] = fallen
	prop["facing"] = 0 if dest.size.x >= dest.size.y else 1
	if not fallen and dest == prop.get("home_rect", Rect2i()):
		prop["facing"] = int(prop.get("home_facing", prop["facing"]))
	var g = game.levels[lv]
	if not fallen:
		for c in cells(dest):
			g.set_solid(c, Grid.Solid.LOW)
			g.refresh_cell(c)
		if lv == 0:
			game.data["low_blocks"].append(dest)
	for box: Dictionary in boxes:
		var offset: Vector2i = box["cell"] - old.position
		if old.size != dest.size:
			offset = Vector2i(offset.y, offset.x)
		box["cell"] = dest.position + offset
		game.view.move_object_container(String(box["id"]))
	game.view.update_prop(prop)


func topple(prop: Dictionary, c: Vector2i) -> void:
	prop.erase("brace_door")
	var dest := side_rect(prop, c)
	if dest.size == Vector2i.ZERO:
		# A packed room still releases the doorway: the fallen piece lies flat.
		dest = prop["rect"]
	move_prop(prop, dest, true)


func break_prop(p, prop: Dictionary) -> void:
	var lv := int(prop.get("level", 0))
	if prop.has("brace_door"):
		Building.remove_brace(game.levels[lv].doors[prop["brace_door"]])
	var contents: Array = []
	for box: Dictionary in boxes_of(game.data, prop):
		contents.append_array(box["items"])
		game.data["containers"].erase(box["id"])
		game.view.remove_object_container(String(box["id"]))
	var id := "furniture_heap_%d" % game.data["containers"].size()
	while game.data["containers"].has(id):
		id += "_"
	var r: Rect2i = prop["rect"]
	game.data["containers"][id] = {"id": id, "name": "부순 가구 더미", "cell": r.position,
		"level": lv, "building": game.levels[lv].building_at(r.position), "items": contents,
		"locked": false, "searched": false, "search": HEAP_SEARCH_SECONDS}
	_clear_prop(prop)
	game.data["props"].erase(prop)
	game.view.update_prop(prop, true)
	game.view.add_container(id)
	p.add_item("plank", plank_yield(prop))


func _bind_fuel_clock() -> void:
	if game.clock is FuelClock:
		return
	var fuel_clock := FuelClock.new()
	fuel_clock.elapsed = game.clock.elapsed
	fuel_clock.speed = game.clock.speed
	fuel_clock.stoves = game.data["stoves"]
	fuel_clock.expired = stove_changed
	game.clock = fuel_clock


func sync_stoves() -> void:
	for stove: Dictionary in game.data["stoves"]:
		if stove.has("fuel_until") and bool(stove["lit"]) and game.clock.elapsed >= float(stove["fuel_until"]):
			stove["lit"] = false
			stove_changed(stove)


func stove_changed(stove: Dictionary) -> void:
	var idx: int = game.data["stoves"].find(stove)
	var id := "stove_fuel_%d" % idx
	var lights: Array = game.data["lights"]
	for i in range(lights.size() - 1, -1, -1):
		if String(lights[i]["id"]) == id:
			lights.remove_at(i)
	if stove["lit"]:
		lights.append({"id": id, "kind": "stove", "cell": stove["cell"], "level": stove.get("level", 0),
			"when": "dusk" if int(stove.get("level", 0)) == game.level_of(game.player.position) else "off",
			"from_min": Clock.SUNSET_MIN, "reach": LIGHT_REACH, "strength": LIGHT_STRENGTH})
	game.lamp_key = "-"
	game.view.update_stove(idx)


func _sync_light_floor() -> void:
	var lv: int = game.level_of(game.player.position)
	for light_row: Dictionary in game.data["lights"]:
		if String(light_row.get("kind", "")) != "stove":
			continue
		var when := "dusk" if int(light_row.get("level", 0)) == lv else "off"
		if light_row["when"] != when:
			light_row["when"] = when
			game.lamp_key = "-"
