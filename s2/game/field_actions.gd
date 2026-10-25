extends RefCounted
## What people do with the place: doors, windows, searching, salvage, the
## water tower, the signal box ladder, the coal work site, sewer lids,
## unloading and departure (s2_station 2.2-2.4, body_injury 3·6·9).

const FieldGrid = preload("res://game/world/field_grid.gd")
const W = preload("res://game/sim/weapons.gd")
const SimNoise = preload("res://game/sim/noise.gd")
const Carry = preload("res://game/sim/carry.gd")
const HordeDirector = preload("res://game/sim/horde_director.gd")
const Treatment = preload("res://game/sim/treatment.gd")
const SearchRules = preload("res://game/sim/search_rules.gd")
const DoorRules = preload("res://game/sim/door_rules.gd")
const WindowRules = preload("res://game/sim/window_rules.gd")
const CoreScenes = preload("res://game/world/core_scenes.gd")
const Pose = preload("res://game/actors/person_pose.gd")

const REACH: float = 1.4
const INTERACT_REACH: float = REACH + 0.6
const DOOR_TIME: float = DoorRules.TOGGLE_SECONDS
const PRY_TIME: float = DoorRules.PRY_SECONDS
const KICK_TIME: float = DoorRules.KICK_SECONDS
const GLASS_TIME: float = WindowRules.CLEAR_SECONDS
# The pass's snow plough (user decisions 176, 188): its drives are the salvage
# spots named so, and with the last of them off comes the core and this much scrap.
const DRIVE_PREFIX: String = "plow_drive_"
const CORE_ITEM: String = "plow_core"
const CORE_SCRAP: int = 10
const CORE_HEAP: String = "plow_core_heap"
const SALVAGE_TIME: float = 6.0
const FIRE_LIGHT_TIME: float = 10.0
const FIRE_BURN: float = 120.0
const SNOW_TIME: float = 240.0
const CLIMB_FAST: float = 3.0
const CLIMB_CAREFUL: float = 6.0
# Over the train at a coupling (a map's "crossings"), one at a time, like a
# ladder: first values, to be tuned by play (user 2026-10-12).
const CROSS_TIME: float = 3.0
const CROSS_LOADED: float = 5.0
const CROSS_NEAR: float = 1.6
const CROSS_FOLLOW: float = 8.0     # companions this near the way come over after the chief
const BLOCK_LID_TIME: float = 8.0
const RUB_SNOW_TIME: float = 10.0
const UPSTAIRS_Y: float = 3.0
const CARE_REACH: float = 2.0     # how near you must be to treat someone else
# Planks and spirits go on the train as wood and luxury (user decision 407 B1); cloth and bandages stay field stores.
const UNLOAD_KEEP: Array = ["bandage", "cloth", "medkit", "ammo_craft", "flare", "tweezers", "needle_thread"]
const FieldItems = preload("res://game/sim/field_items.gd")
const Wear = preload("res://game/sim/wear.gd")
## 나단계 손일 (decision 423, P12·P22): a key turns in a second and a half
## without a sound; boarding a door takes a plank and a handful of nails, eight
## seconds of hammering, and gives the door three more blows to break; a
## stake is whittled from a plank in six.
const KEY_TIME: float = 1.5
const BOARD_TIME: float = 8.0
const BOARD_HP: int = 3
const STAKE_TIME: float = 6.0
## Who sees one of the dead gone through (card 12): a companion this near, in sight.
const BODY_SEEN_M: float = 8.0
## Going through the pockets of a plain body: three seconds with the hands
## busy (a grab stops it, as any work). The frozen and the padded take their
## own (loot_tables.gd BODY, zombies.search_time).
const BODY_SEARCH_TIME: float = 3.0
## Going through a container is quiet (3 m, indoors 1.5 m), once every four
## seconds of it (loot spec v1 4, user decision 407 B4).
const SEARCH_NOISE_EVERY: float = SearchRules.NOISE_EVERY
const ROUND_NAMES: Dictionary = {"pistol": "권총탄", "shell": "산탄"}
const AMMO_ITEMS: Dictionary = {"ammo_pistol": ["pistol", 6], "ammo_shell": ["shell", 4], "ammo_craft": ["craft", 1]}

var game
var coal_delivered: float = 0.0
var coal_spent: float = 0.0
var work_started: bool = false
var fire_left: float = 0.0
var fire_noise_t: float = 0.0
var dig_noise_t: float = 0.0
var unload_t: float = 0.0
## Short-lived reservations, separate from saved AI state. No actor or callback is retained.
var ongoing: Dictionary = {}
## A work of the hands the player asked for while in a blow or a shove waits
## here and is done once as soon as the blow is over (decision 420: one body
## does one thing at a time). Short-lived, never saved.
var after_blow: Dictionary = {}


func _init(field_game) -> void:
	game = field_game


## In a blow or a shove: drawn back, landing, or coming back from it.
func striking(p) -> bool:
	return p.swing_t > 0.0 or p.strike_t > 0.0 or p.shove_t > 0.0


## Asked for mid-blow, a work does not start (true: not now). The player's own
## press waits for the blow to end and lets the fight go, as walking off to a
## thing lets it go (go_and_do). A companion's AI only asks again later: its
## fight is its own to keep.
func _wait_blow(p, call: Callable) -> bool:
	if not striking(p):
		return false
	if p == game.player:
		after_blow[p.get_instance_id()] = call
		p.target_zombie = {}
		p.target_person = null
	return true


## Does what waited for a blow to end; dropped if the body was taken meanwhile.
func _after_blows() -> void:
	for id in after_blow.keys():
		var p = instance_from_id(id)
		var call: Callable = after_blow[id]
		if p == null or not is_instance_valid(p) or not call.is_valid() or not p.can_act():
			after_blow.erase(id)
		elif not striking(p):
			after_blow.erase(id)
			call.call()


func _in_reach(p, at: Vector3, boundary: bool = false) -> bool:
	if game.level_of(p.position) != game.level_of(at) or p.position.distance_to(at) > INTERACT_REACH:
		return false
	var lg = game.grid_at(at)
	var from_cell := FieldGrid.cell_of(p.position)
	var to_cell := FieldGrid.cell_of(at)
	# A door/frame may itself block the body; ordinary items may not be taken through one.
	return lg.line_clear(from_cell, to_cell) if boundary else lg.body_line_clear(from_cell, to_cell)


func _can_start(p, at: Vector3, boundary: bool = false) -> bool:
	return p.can_act() and p.action == "" and not striking(p) and _in_reach(p, at, boundary)


func _target(work: Dictionary) -> Dictionary:
	match work["kind"]:
		"container": return game.data["containers"].get(work["key"], {})
		"door": return game.grid.doors.get(work["key"], {})
		"window": return game.grid.windows.get(work["key"], {})
	return {}


func _work_valid(p, work: Dictionary) -> bool:
	if not p.can_act() or not _in_reach(p, work["at"], work["kind"] != "container"):
		return false
	if p.body.injured_at != work["injured_at"] or p.body.wounds.size() > int(work["wounds"]):
		return false
	if work["pry"] and not has_pry(p):
		return false
	var target := _target(work)
	if not is_same(target, work["object"]):
		return false
	for key in work["state"]:
		if target.get(key) != work["state"][key]:
			return false
	return true


func _begin_work(p, action: String, label: String, seconds: float, done: Callable,
		kind: String, key, at: Vector3, needs_pry: bool = false) -> bool:
	var work := {"kind": kind, "key": key, "at": at, "pry": needs_pry}
	var target := _target(work)
	if target.is_empty() or bool(target.get("busy", false)) or not _can_start(p, at, kind != "container"):
		return false
	if needs_pry and not has_pry(p):
		return false
	var state: Dictionary = {}
	for field in ["state", "locked", "searched", "broken", "glass"]:
		if target.has(field):
			state[field] = target[field]
	work.merge({"action": action, "object": target, "state": state, "ready": false,
		"injured_at": p.body.injured_at, "wounds": p.body.wounds.size()})
	p.start_action(action, label, seconds, done)
	target["busy"] = true
	p.action_busy = target
	ongoing[p.get_instance_id()] = work
	return true


## Called before the body/action tick, including for fallen or grabbed people.
func validate_work(p) -> void:
	_check_chain(p)
	var id: int = p.get_instance_id()
	if not ongoing.has(id):
		return
	var work: Dictionary = ongoing[id]
	if p.action != work["action"] or not is_same(p.action_busy, work["object"]):
		ongoing.erase(id)
		return
	if not _work_valid(p, work):
		p.cancel_action()
		ongoing.erase(id)


## Only the timed-action completion branch can issue a completion ticket.
func complete_work(p) -> void:
	var id: int = p.get_instance_id()
	if ongoing.has(id) and _work_valid(p, ongoing[id]):
		ongoing[id]["ready"] = true


func _finished_work(p, action: String) -> bool:
	var id: int = p.get_instance_id()
	if not ongoing.has(id):
		return false
	var work: Dictionary = ongoing[id]
	ongoing.erase(id)
	return work["action"] == action and work["ready"] and _work_valid(p, work)


func update(delta: float) -> void:
	_tower(delta)
	_dig_noise(delta)
	_ladder_falls()
	_crossing_falls()
	_after_blows()
	_player_goal()
	unload_t -= delta
	if unload_t <= 0.0:
		unload_t = 0.5
		_auto_unload()
		_load_garments()
		_auto_pickup()


# ---------------------------------------------------------------- go and do

## Walk to an interactable, then act. kind: door | window | container | spot | item | manhole.
func go_and_do(p, kind: String, key, at: Vector3, verb: String = "") -> void:
	if not p.can_act():
		return
	# Ground-array indices change as other people pick things up while this person walks.
	var ground_item: Dictionary = {}
	if kind == "item":
		if not key is int or key < 0 or key >= game.ground_items.size():
			return
		ground_item = game.ground_items[key]
	p.brain["goal"] = {"kind": kind, "key": key, "at": at, "verb": verb}
	if kind == "item":
		p.brain["goal"]["ground_item"] = ground_item
	p.target_zombie = {}
	var stand: Vector3 = at
	if kind in ["door", "window", "container", "spot", "manhole"]:
		var lg = game.grid_at(at)
		var lv: int = game.level_of(at)
		var c: Vector2i = lg.nearest_walkable(FieldGrid.cell_of(at), false, 2)
		if lg.blocks_body(FieldGrid.cell_of(at)):
			stand = game.lift(_side_cell(lg, FieldGrid.cell_of(at), p.position), lv)
		elif FieldGrid.cell_of(at) != c:
			stand = game.lift(c, lv)
	if p.position.distance_to(stand) <= REACH:
		_do_goal(p)
	else:
		p.go_to(game.find_path(p.position, stand, false), p.running)


## The walkable neighbour of a door/window cell on the walker's side.
func _side_cell(lg, c: Vector2i, from: Vector3) -> Vector2i:
	var best := c
	var best_d := 999.0
	for o in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var n: Vector2i = c + o
		if not lg.people_can_walk(n) or lg.blocks_body(n):
			continue
		var d: float = FieldGrid.center(n).distance_to(from)
		if d < best_d:
			best_d = d
			best = n
	return best


func _player_goal() -> void:
	for p in game.squad:
		# Mid-blow the goal waits: it is done once the blow is over.
		if not p.brain.has("goal") or not p.can_act() or p.action != "" or striking(p):
			continue
		var g: Dictionary = p.brain["goal"]
		if p.path.is_empty() or p.position.distance_to(g["at"]) <= REACH:
			if p.position.distance_to(g["at"]) <= INTERACT_REACH:
				_do_goal(p)
			else:
				p.brain.erase("goal")


func _do_goal(p) -> void:
	var g: Dictionary = p.brain["goal"]
	p.brain.erase("goal")
	p.stop()
	p.face_point(g["at"])
	match g["kind"]:
		"door":
			door_default(p, g["key"], g["verb"])
		"window":
			window_default(p, g["key"], g["verb"])
		"container":
			search(p, g["key"])
		"spot":
			spot_default(p, g["key"], g["verb"])
		"item":
			var idx: int = int(g["key"])
			if g.has("ground_item") and (idx < 0 or idx >= game.ground_items.size() or not is_same(game.ground_items[idx], g["ground_item"])):
				return
			pick_up(p, idx)
		"body":
			search_body(p, g["key"])
		"strip":
			# The player picks which garment from the body's list (field_hud.gd).
			if p == game.player:
				game.hud.strip_pane(int(g["key"]))
		"manhole":
			block_lid(p, g["key"])
		"ladder":
			climb_ladder(p, g["key"], g["verb"])


# ---------------------------------------------------------------- doors

func open_door_on_way(p, c: Vector2i) -> void:
	var door: Dictionary = game.grid.doors.get(c, {})
	if door.is_empty() or not _can_start(p, FieldGrid.center(c), true):
		return
	if door["state"] == "locked":
		p.stop()
		if has_key(p, c):
			unlock_with_key(p, c)
		elif p == game.player:
			game.hud.toast("잠김")
		return
	if not DoorRules.can_toggle(door, "open"):
		return
	# Opening a door on the way keeps the walk going afterwards.
	var keep: PackedVector3Array = p.path.duplicate()
	var run: bool = p.running
	_begin_work(p, "door", "문", DOOR_TIME, _door_on_way_done.bind(p, c, keep, run), "door", c, FieldGrid.center(c))


func _door_on_way_done(p, c: Vector2i, keep: PackedVector3Array, run: bool) -> void:
	if not _finished_work(p, "door"):
		return
	_set_door(c, "open")
	if game.grid.doors.has(c) and game.grid.doors[c]["state"] == "open" and p.can_act():
		p.go_to(keep, run)


func door_default(p, c: Vector2i, verb: String) -> void:
	if _wait_blow(p, door_default.bind(p, c, verb)):
		return
	var door: Dictionary = game.grid.doors.get(c, {})
	if door.is_empty() or not _can_start(p, FieldGrid.center(c), true):
		return
	match verb:
		"close":
			if door["state"] == "open":
				_begin_work(p, "door", "문 닫기", DOOR_TIME, _set_door.bind(c, "closed", p), "door", c, FieldGrid.center(c))
		"pry":
			pry_door(p, c)
		"kick":
			kick_door(p, c)
		_:
			if door["state"] == "closed":
				_begin_work(p, "door", "문 열기", DOOR_TIME, _set_door.bind(c, "open", p), "door", c, FieldGrid.center(c))
			elif door["state"] == "open":
				_begin_work(p, "door", "문 닫기", DOOR_TIME, _set_door.bind(c, "closed", p), "door", c, FieldGrid.center(c))
			elif door["state"] == "locked":
				if has_key(p, c):
					unlock_with_key(p, c)
				elif has_pry(p):
					pry_door(p, c)
				elif p == game.player:
					game.hud.toast("잠김")


func _set_door(c: Vector2i, state: String, p = null, pried: bool = false) -> void:
	if p != null and not _finished_work(p, "pry" if pried else "door"):
		return
	if not DoorRules.can_toggle(game.grid.doors.get(c, {}), state, pried):
		return
	# Something standing in the doorway keeps it from closing.
	if state == "closed":
		if not game.zombies.in_radius(FieldGrid.center(c), DoorRules.OCCUPANT_RADIUS).is_empty():
			return
		for person in game.people:
			if person.is_alive() and person.position.distance_to(FieldGrid.center(c)) < DoorRules.OCCUPANT_RADIUS:
				return
	game.grid.set_door_state(c, state)
	game.view.update_door(c)
	_check_raider_door(c)


func has_pry(p) -> bool:
	for h in p.hands:
		if bool(W.get_data(h["id"]).get("pry", false)):
			return true
	return false


## The key of this door's building is in the pack (P12), and the door is not
## boarded up.
func has_key(p, c: Vector2i) -> bool:
	var door: Dictionary = game.grid.doors.get(c, {})
	if door.is_empty() or bool(door.get("boarded", false)):
		return false
	return int(p.items.get(FieldItems.key_for(int(door.get("building", -1))), 0)) > 0


## A key opens a locked door quickly and makes no sound (P12: the reward for
## going through the dead of the house).
func unlock_with_key(p, c: Vector2i) -> void:
	if not _can_start(p, FieldGrid.center(c), true):
		return
	_begin_work(p, "door", "열쇠로 열기", KEY_TIME, _key_opened.bind(p, c), "door", c, FieldGrid.center(c))


func _key_opened(p, c: Vector2i) -> void:
	if not _finished_work(p, "door") or not has_key(p, c):
		return
	if String(game.grid.doors[c]["state"]) != "locked":
		return
	game.grid.set_door_state(c, "open")
	game.view.update_door(c)
	_check_raider_door(c)


## A closed door near by can be boarded up with a plank and a handful of nails
## (P22): locked from this side, harder to break, and heard while it is done.
func can_board(p, c: Vector2i) -> bool:
	var door: Dictionary = game.grid.doors.get(c, {})
	return not door.is_empty() and String(door["state"]) in ["closed", "locked"] and not bool(door.get("boarded", false)) \
		and (int(p.items.get("plank", 0)) > 0 or int(p.items.get("wood", 0)) > 0) and int(p.items.get("nails", 0)) > 0


func board_door(p, c: Vector2i) -> void:
	if _wait_blow(p, board_door.bind(p, c)):
		return
	if not can_board(p, c) or not _can_start(p, FieldGrid.center(c), true):
		return
	if _begin_work(p, "craft", "문 막기", BOARD_TIME, _boarded.bind(p, c), "door", c, FieldGrid.center(c)):
		game.make_sound(FieldGrid.center(c), SimNoise.Level.NORMAL, "hammer", p)


func _boarded(p, c: Vector2i) -> void:
	if not _finished_work(p, "craft") or not can_board(p, c):
		return
	if not (p.take_item("plank") or p.take_item("wood")) or not p.take_item("nails"):
		return
	var door: Dictionary = game.grid.doors[c]
	game.grid.set_door_state(c, "locked")
	door["boarded"] = true
	door["hp"] = int(door.get("hp", 0)) + BOARD_HP
	game.view.update_door(c)


## A plank whittled to a stake (P22, P23): into a free hand.
func whittle_stake(p) -> void:
	if _wait_blow(p, whittle_stake.bind(p)):
		return
	if int(p.items.get("plank", 0)) <= 0 or p.hands.size() >= 2:
		return
	p.start_action("craft", "말뚝 깎기", STAKE_TIME, _whittled.bind(p))


func _whittled(p) -> void:
	if p.hands.size() >= 2 or not p.take_item("plank"):
		return
	_into_hand(p, "wood_stake")


## An improvised weapon goes straight into a free hand (P23: one tap). Returns
## false when both hands are full.
func _into_hand(p, id: String) -> bool:
	if p.hands.size() >= 2 or not W.is_known(id) or String(W.get_data(id).get("kind", "")) != "melee":
		return false
	var h := {"id": id, "quality": "factory", "condition": 1.0, "loaded": 0}
	if p.hands.is_empty():
		p.hands.append(h)
	else:
		p.hands.insert(0, h)
	p.set_weapon_slots(p.hands)
	if p == game.player:
		game.hud.toast("%s을(를) 쥐었다." % String(W.get_data(id)["name"]))
	return true


## Pry a locked door with a crowbar: a few seconds and a normal sound.
func pry_door(p, c: Vector2i) -> void:
	if _wait_blow(p, pry_door.bind(p, c)):
		return
	if not DoorRules.can_force(game.grid.doors.get(c, {})) or not _can_start(p, FieldGrid.center(c), true):
		return
	if not has_pry(p):
		if p == game.player:
			game.hud.toast("쇠지렛대 없음")
		return
	if _begin_work(p, "pry", "문 따기", PRY_TIME, _set_door.bind(c, "open", p, true), "door", c, FieldGrid.center(c), true):
		game.make_sound(FieldGrid.center(c), SimNoise.Level.NORMAL, "pry", p)


## Kick: one loud try, half the time it gives (s2_station 2.4).
func kick_door(p, c: Vector2i) -> void:
	if _wait_blow(p, kick_door.bind(p, c)):
		return
	if DoorRules.can_force(game.grid.doors.get(c, {})):
		_begin_work(p, "kick", "문 차기", KICK_TIME, _kicked.bind(p, c), "door", c, FieldGrid.center(c))


func _kicked(p, c: Vector2i) -> void:
	if not _finished_work(p, "kick") or not DoorRules.can_force(game.grid.doors.get(c, {})):
		return
	game.make_sound(FieldGrid.center(c), SimNoise.Level.LOUD, "kick", p)
	if game.rng.randf() < DoorRules.KICK_CHANCE:
		game.grid.set_door_state(c, "broken")
		game.view.update_door(c)
		_check_raider_door(c)
	elif p == game.player:
		game.hud.toast("문이 버텼다.")


## Opening the pharmacy door lets the raiders see us (s2_station 2.5).
func _check_raider_door(c: Vector2i) -> void:
	if int(game.grid.doors[c]["building"]) != 3:
		return
	for r in game.raiders:
		if r.is_alive() and r.brain.get("state", "") == "idle":
			r.brain["aware"] = 0.6


# ---------------------------------------------------------------- windows

func window_default(p, c: Vector2i, verb: String) -> void:
	if _wait_blow(p, window_default.bind(p, c, verb)):
		return
	var w: Dictionary = game.grid.windows.get(c, {})
	if w.is_empty() or not _can_start(p, FieldGrid.center(c), true):
		return
	if not w["broken"]:
		if verb == "break" or p != game.player:
			_begin_work(p, "window", "창 깨기", WindowRules.BREAK_SECONDS, _window_work_done.bind(p, c), "window", c, FieldGrid.center(c))
		else:
			game.hud.toast("깨야 넘음")
			game.hud.offer([{"label": "창을 깬다", "call": window_default.bind(p, c, "break")}])
		return
	if WindowRules.can_clear(w):
		_begin_work(p, "glass", "유리 치우기", GLASS_TIME, _clear_glass.bind(c, p), "window", c, FieldGrid.center(c))


func _window_work_done(p, c: Vector2i) -> void:
	if _finished_work(p, "window"):
		_break_window(p, c)


## Also called by a weapon impact: the combat caller already resolved the hit.
func _break_window(p, c: Vector2i) -> void:
	if not WindowRules.can_break(game.grid.windows.get(c, {})):
		return
	game.grid.break_window(c)
	game.view.update_window(c)
	var b: int = int(game.grid.windows[c]["building"])
	if b >= 0:
		game.data["buildings"][b]["window_broken"] = true
	game.make_sound(FieldGrid.center(c), SimNoise.Level.LOUD, "glass", p)


func _clear_glass(c: Vector2i, p = null) -> void:
	if p != null and not _finished_work(p, "glass"):
		return
	if not WindowRules.can_clear(game.grid.windows.get(c, {})):
		return
	game.grid.windows[c]["glass"] = false
	game.view.update_window(c)


func can_vault_window(p, c: Vector2i) -> bool:
	return p.can_act() and p.action == "" and _in_reach(p, FieldGrid.center(c), true) and WindowRules.can_cross(game.grid.windows.get(c, {}), p.carry_state())


## Called once on actual entry, not once per frame or once per window lifetime.
func vault_window(p, c: Vector2i) -> void:
	if _wait_blow(p, vault_window.bind(p, c)):
		return
	if not can_vault_window(p, c):
		return
	var w: Dictionary = game.grid.windows[c]
	if w["glass"] and game.rng.randf() < (0.2 if p.gloves else 0.5):
		p.body.apply_cut(false, game.clock.elapsed, game.combat.wound_side("leg"))
		game.telemetry.injury(game.clock.elapsed, p.pid, "glass")
		if p.team != "raider":
			game.say(p, "%s 유리에 베였다." % p.display_name, true, "cut")


# ---------------------------------------------------------------- searching

func search_time(p, c: Dictionary) -> float:
	return SearchRules.seconds(float(c["search"]), int(p.skills["search"]))


func _container_at(c: Dictionary) -> Vector3:
	return game.lift(c["cell"], int(c.get("level", 0)))


func search(p, id: String) -> void:
	if _wait_blow(p, search.bind(p, id)):
		return
	var c: Dictionary = game.data["containers"].get(id, {})
	if c.is_empty() or not _can_start(p, _container_at(c)) or bool(c.get("busy", false)):
		return
	if c["locked"]:
		if c.has("pick"):
			# A record box of this stop's goal: quiet and slow, or quick and loud.
			if p == game.player:
				game.mission_play.lock_card(p, id)
			return
		if has_pry(p):
			if _begin_work(p, "pry", "금고 따기", PRY_TIME + DoorRules.SAFE_EXTRA_SECONDS, _unlock.bind(id, p), "container", id, _container_at(c), true):
				game.make_sound(_container_at(c), SimNoise.Level.NORMAL, "pry", p)
		elif p == game.player:
			game.hud.toast("잠긴 금고 · 쇠지렛대 없음")
		return
	if c["searched"]:
		if p == game.player:
			game.hud.loot(id)
		else:
			_companion_take(p, c)
		return
	if not SearchRules.can_search(c):
		return
	if p != game.player and p.team == "squad":
		var helpers := 0
		for other in game.squad:
			if other != p and other != game.player and other.is_alive() and other.action == "search":
				helpers += 1
		if helpers >= SearchRules.COMPANION_LIMIT:
			return
	if not _begin_work(p, "search", "뒤지기", search_time(p, c), _search_work_done.bind(p, id), "container", id, _container_at(c)):
		return
	game.shout(p, "search_start")
	# The first rummage is heard at once, then one every SEARCH_NOISE_EVERY (user decision 407 B4).
	p.action_noise_t = 0.0
	game.make_sound(_container_at(c), SimNoise.Level.QUIET, "search", p)


func _unlock(id: String, p = null) -> void:
	if p != null and not _finished_work(p, "pry"):
		return
	if not game.data["containers"].has(id):
		return
	game.data["containers"][id]["locked"] = false
	game.view.update_container(id)


## Called each frame of a container search: the quiet rummage when it is due.
func search_noise(p, delta: float) -> void:
	if p.action != "search" or p.action_busy.is_empty():
		return
	p.action_noise_t += delta
	if p.action_noise_t < SEARCH_NOISE_EVERY:
		return
	p.action_noise_t = fmod(p.action_noise_t, SEARCH_NOISE_EVERY)
	game.make_sound(_container_at(p.action_busy), SimNoise.Level.QUIET, "search", p)


func _search_work_done(p, id: String) -> void:
	if _finished_work(p, "search"):
		_searched(p, id)


## A completed search notification; timed work reaches it only through its ticket.
func _searched(p, id: String) -> void:
	var c: Dictionary = game.data["containers"].get(id, {})
	if c.is_empty() or c["searched"]:
		return
	c["searched"] = true
	c["busy"] = false
	game.view.update_container(id)
	game.mission_play.searched(id)
	if p == game.player:
		game.hud.loot(id)
		return
	_companion_take(p, c)


func _companion_take(p, c: Dictionary) -> void:
	# A companion takes what fits in the bag without going over the limit.
	var keep: Array = []
	var took: Array = []
	for item in c["items"]:
		# Clothes are put on, not bagged (wear.gd): a companion leaves them.
		if Wear.is_garment(String(item)):
			keep.append(item)
		elif AMMO_ITEMS.has(item) or p.weight() + Carry.item_weight(item) <= p.carry_limit():
			_receive(p, item, 1)
			took.append(game.item_name(item))
		else:
			keep.append(item)
	c["items"] = keep
	if not took.is_empty():
		game.say(p, "%s: %s 챙겼다." % [p.display_name, ", ".join(took)], false, "found")
	elif not keep.is_empty():
		game.say(p, "%s: 가방이 차서 못 챙겼다." % p.display_name, false, "bag_full")
	else:
		game.shout(p, "empty")


## Take one item from a searched container into the player's bag. `asked`:
## the player has seen what putting a garment on takes (field_hud.gd wear_pane).
func take(p, id: String, index: int, asked: bool = false) -> void:
	var c: Dictionary = game.data["containers"].get(id, {})
	if not SearchRules.can_take(c) or not _can_start(p, _container_at(c)):
		return
	if index < 0 or index >= c["items"].size():
		return
	var item: String = c["items"][index]
	if Wear.is_garment(item) and _asks(p, item, asked):
		game.hud.wear_pane({"box": id, "i": index, "id": item})
		return
	c["items"].remove_at(index)
	# A garment is put on, not bagged (wear.gd): laid at the feet as found, then worn.
	if Wear.is_garment(item):
		_put_down_garment(p, Wear.make(item))
		dress(p, game.ground_items.size() - 1)
		game.view.update_container(id)
		return
	# Something to hit with goes straight into a free hand (P23).
	if not W.breaks(item) or not _into_hand(p, item):
		_receive(p, item, 1)
	if item == "symbol_bell":
		game.make_sound(_container_at(c), SimNoise.Level.NORMAL, "bell", p)
		game.hud.toast("종이 흔들려 울렸다.")
	game.view.update_container(id)


func take_all(p, id: String) -> void:
	var c: Dictionary = game.data["containers"].get(id, {})
	if not SearchRules.can_take(c):
		return
	# Clothes stay in the box: each is put on by itself (wear.gd).
	var i := 0
	while i < c["items"].size():
		if Wear.is_garment(String(c["items"][i])):
			i += 1
			continue
		var before: int = c["items"].size()
		take(p, id, i)
		if c["items"].size() == before:
			break


func _receive(p, item: String, n: int) -> void:
	if AMMO_ITEMS.has(item) and p.team != "raider":
		var row: Array = AMMO_ITEMS[item]
		game.ammo[row[0]] = int(game.ammo.get(row[0], 0)) + int(row[1]) * n
		return
	p.add_item(item, n)


## Through the pockets of a fallen one (the dead now and then have a small
## thing; a raider has what it carried). Most have nothing: the three seconds
## are the price. If it gets up meanwhile the hands come away empty.
func search_body(p, zid: int) -> void:
	if _wait_blow(p, search_body.bind(p, zid)):
		return
	var z: Dictionary = game.zombies.find(zid)
	if p.action != "" or not game.zombies.lootable(z):
		return
	p.start_action("loot", "품 뒤지기", game.zombies.search_time(z), _body_searched.bind(p, zid))


func _body_searched(p, zid: int) -> void:
	var z: Dictionary = game.zombies.find(zid)
	if not game.zombies.lootable(z):
		if p == game.player:
			game.hud.toast("일어났다. 손을 뗐다.")
		return
	z["searched"] = true
	var loot: Array = z["loot"]
	z["loot"] = []
	game.telemetry.body(not loot.is_empty())
	var names: Array = []
	for row in loot:
		var n: int = int(row["n"])
		if row.has("ammo"):
			game.ammo[row["ammo"]] = int(game.ammo.get(row["ammo"], 0)) + n
			names.append("%s %d발" % [ROUND_NAMES.get(row["ammo"], row["ammo"]), n])
		elif row.has("weapon"):
			names.append(String(W.get_data(row["id"]).get("name", row["id"])))
			game.ground_items.append({"pos": p.position, "id": row["id"], "n": 1, "weapon": row["weapon"]})
			pick_up(p, game.ground_items.size() - 1)
		else:
			names.append(game.item_name(row["id"]) + (" %d" % n if n > 1 else ""))
			_receive(p, row["id"], n)
	if p == game.player:
		game.hud.toast("찾았다: %s." % ", ".join(names) if not names.is_empty() else "아무것도 없다.")
	_body_seen(p)


## One of the dead gone through (decision 423 card 12): the nearest companion
## who sees it says a line (`event`: its pockets, or its clothes taken), and
## the train hears of it from those who saw (the receipt's witnessed row
## "body_search"; their car minds it or not).
func _body_seen(p, event: String = "body_search") -> void:
	var seen: Array = []
	var nearest = null
	var best := BODY_SEEN_M
	for q in game.squad:
		if q == p or not q.is_alive() or game.level_of(q.position) != game.level_of(p.position):
			continue
		var d: float = q.position.distance_to(p.position)
		if d > BODY_SEEN_M or not game.sight_clear(q.position, p.position):
			continue
		seen.append(String(q.pid))
		if q != game.player and d < best:
			best = d
			nearest = q
	if nearest != null:
		game.shout(nearest, event)
	if not seen.is_empty():
		game.body_searches.append({"who": String(p.pid), "seen": seen})


func pick_up(p, idx: int, asked: bool = false) -> void:
	if idx < 0 or idx >= game.ground_items.size():
		return
	var g: Dictionary = game.ground_items[idx]
	if not _can_start(p, g["pos"]) or int(g.get("n", 0)) <= 0:
		return
	if g.has("garment"):
		if _asks(p, String(g["id"]), asked) and Wear.wearable(g["garment"]):
			game.hud.wear_pane({"ground": g, "id": String(g["id"])})
			return
		dress(p, idx)
		return
	if g.has("weapon"):
		# The bag stores counts, not weapon condition/ammunition. Keep a full-handed pickup intact.
		if p.hands.size() >= 2:
			return
		var h: Dictionary = g["weapon"]
		game.ground_items.remove_at(idx)
		p.hands.append(h)
		p.set_weapon_slots(p.hands)
		game.say(p, "%s 주웠다." % W.get_data(h["id"]).get("name", h["id"]))
		return
	game.ground_items.remove_at(idx)
	_receive(p, g["id"], int(g["n"]))


# ---------------------------------------------------------------- clothes

## Changing clothes is a chain of steps (decision 434, clothing.md 7장,
## wear.gd dress_plan): the layers over a place off, the garment on, them back
## on, each step a job of the hands as long as its motion, one after the
## other. A layer taken off for the while lies at the feet until it goes back
## on; cut short (the stick, a blow, a grab), the steps done stay done and what
## was taken off stays at the feet. The head, the neck, the face and the hands
## go on and off at a walk (Wear.WALKABLE, field_game.gd). Never saved: what
## a chain holds is on the body or on the ground. Keyed by the body's instance.
var wear_chains: Dictionary = {}


## Put on the garment lying at `idx` (decision 434); what was in its place, or
## a whole suit it puts aside, is put down at the feet as it is. One worn
## through to rags is not put on (3.3).
func dress(p, idx: int) -> void:
	if idx < 0 or idx >= game.ground_items.size():
		return
	var g: Dictionary = game.ground_items[idx]
	if not g.has("garment") or not _can_start(p, g["pos"]):
		return
	if not Wear.wearable(g["garment"]):
		if p == game.player:
			game.hud.toast("너덜해서 못 입는다.")
		return
	_begin_chain(p, Wear.dress_plan(p, String(g["id"])), g)


## Take off what is in `slot` (the layers over it off and back on); it is put
## down at the feet as it is.
func undress(p, slot: String) -> void:
	if Wear.occupant(p, slot).is_empty() or not p.can_act() or p.action != "" or striking(p):
		return
	_begin_chain(p, Wear.undress_plan(p, slot), {})


func _begin_chain(p, plan: Array, lay: Dictionary) -> void:
	if plan.is_empty():
		return
	var chain := {"plan": plan, "at": 0, "lay": lay, "held": {}, "walk": Wear.plan_walks(plan), "injured_at": p.body.injured_at, "wounds": p.body.wounds.size()}
	_next_step(p, chain)


func _next_step(p, chain: Dictionary) -> void:
	var id: int = p.get_instance_id()
	var plan: Array = chain["plan"]
	var at: int = int(chain["at"])
	if at >= plan.size():
		wear_chains.erase(id)
		return
	var step: Dictionary = plan[at]
	var off: bool = Wear.step_off(step)
	var label: String = "갈아입기" if plan.size() > 1 else ("벗기" if off else "입기")
	p.start_action("wear", label, float(step["t"]), _step_done.bind(p, chain))
	if p.action != "wear":
		wear_chains.erase(id)
		return
	p.action_busy = {"slot": String(step["slot"]), "off": off, "walk": bool(chain["walk"])}
	wear_chains[id] = chain


## One step done: its garment off (laid down for the while, or for good) or on.
func _step_done(p, chain: Dictionary) -> void:
	var step: Dictionary = chain["plan"][int(chain["at"])]
	var slot: String = String(step["slot"])
	match String(step["op"]):
		"off":
			chain["held"][slot] = _put_down_garment(p, Wear.take_off(p, slot))
		"aside", "drop":
			_put_down_garment(p, Wear.take_off(p, slot))
		"on":
			var lay: Dictionary = chain["lay"]
			if _lift_garment(lay):
				var state: Dictionary = (lay["garment"] as Dictionary).duplicate(true)
				for old: Dictionary in Wear.put_on(p, state):
					_put_down_garment(p, old)
				if p == game.player:
					game.hud.toast("%s 입었다." % String(state.get("name", game.item_name(String(lay["id"])))))
		"back":
			var held: Dictionary = chain["held"].get(slot, {})
			chain["held"].erase(slot)
			# Rags are not put back on (3.3): it stays where it lies.
			if not held.is_empty() and Wear.wearable(held["garment"]) and _lift_garment(held):
				for old: Dictionary in Wear.put_on(p, (held["garment"] as Dictionary).duplicate(true)):
					_put_down_garment(p, old)
	chain["at"] = int(chain["at"]) + 1
	_next_step(p, chain)


## A chain whose step was cut short ends there (called each frame before the
## body's tick, validate_work): what it took off stays where it lies. A wound
## cuts it as it cuts other work (_work_valid).
func _check_chain(p) -> void:
	var id: int = p.get_instance_id()
	if not wear_chains.has(id):
		return
	var chain: Dictionary = wear_chains[id]
	if p.action == "wear" and (p.body.injured_at != float(chain["injured_at"]) or p.body.wounds.size() > int(chain["wounds"])):
		p.cancel_action()
	if p.action != "wear":
		wear_chains.erase(id)


## A round a vest stopped is no wound, but it knocks the hands off a change
## of clothes all the same (clothing.md 7장).
func struck(p) -> void:
	if p.action == "wear":
		p.cancel_action()


## The player is shown the change first when it takes layers off and back on
## (7장: what comes off and how long), once: `asked` is the answer.
func _asks(p, id: String, asked: bool) -> bool:
	return not asked and p == game.player and game.hud != null and Wear.dress_plan(p, id).size() > 1


## Is this one going on and off at a walk (field_game.gd lets the stick walk
## it, and a run cuts it).
func walk_work(p) -> bool:
	return p.action == "wear" and bool(p.action_busy.get("walk", false))


## Take a garment lying on the ground up again (true if it was still there).
func _lift_garment(g: Dictionary) -> bool:
	if g.is_empty():
		return false
	for i in game.ground_items.size():
		if is_same(game.ground_items[i], g):
			game.ground_items.remove_at(i)
			return true
	return false


## Lay a garment down at the feet as it is; returns what lies there ({} for
## nothing). By the train it goes aboard soon after (_load_garments), unless a
## change of clothes under way will take it up again.
func _put_down_garment(p, state: Dictionary) -> Dictionary:
	if state.is_empty():
		return {}
	var g := {"pos": p.position, "id": String(state["id"]), "n": 1, "garment": state}
	game.ground_items.append(g)
	return g


## Clothes put down by the train are not left lying there (clothing.md 7장):
## they go aboard as they are, all but those a change of clothes under way
## will take up again (and the one it is putting on).
func _load_garments() -> void:
	var held: Array = []
	for chain: Dictionary in wear_chains.values():
		held.append(chain["lay"])
		held.append_array((chain["held"] as Dictionary).values())
	var put: Array = []
	for i in range(game.ground_items.size() - 1, -1, -1):
		var g: Dictionary = game.ground_items[i]
		if not g.has("garment") or held.any(func(h: Dictionary) -> bool: return is_same(h, g)):
			continue
		if not game.FieldMaps.by_train(game.data, FieldGrid.cell_of(g["pos"]), "unloading"):
			continue
		game.loaded_wear.append(g["garment"])
		put.append(String((g["garment"] as Dictionary).get("name", game.item_name(String(g["id"])))))
		game.ground_items.remove_at(i)
	if not put.is_empty():
		game.say(game.player, "실었다: %s" % ", ".join(put))


# ---------------------------------------------------------------- the dead's clothes

## Take `slot`'s garment off one of the fallen (decision 434, clothing.md 8장):
## as long as its weight says (Wear.strip_time), kneeling at the body as for
## its pockets (the same job, "loot"); it is put down by the body as it is,
## worn and holed. If it gets up meanwhile the hands come away empty. Seen,
## it is as going through the pockets is (card 12).
func strip_body(p, zid: int, slot: String) -> void:
	if _wait_blow(p, strip_body.bind(p, zid, slot)):
		return
	var z: Dictionary = game.zombies.find(zid)
	if not game.zombies.strippable(z) or not _can_start(p, z["pos"]):
		return
	var g: Dictionary = game.zombies.worn_of(z).get(slot, {})
	if g.is_empty():
		return
	p.start_action("loot", "옷 가져오기", Wear.strip_time(String(g["id"])), _body_stripped.bind(p, zid, slot))


func _body_stripped(p, zid: int, slot: String) -> void:
	var z: Dictionary = game.zombies.find(zid)
	if not game.zombies.strippable(z):
		if p == game.player:
			game.hud.toast("일어났다. 손을 뗐다.")
		return
	if not _in_reach(p, z["pos"]):
		return
	var worn: Dictionary = game.zombies.worn_of(z)
	if not worn.has(slot):
		return
	var g: Dictionary = worn[slot]
	worn.erase(slot)
	var lay := _put_down_garment(p, g)
	lay["pos"] = z["pos"]
	if p == game.player:
		game.hud.toast("%s 가져왔다." % String(g.get("name", "")))
	# Seen once a body, however many it takes off it (the pockets are their own).
	if not bool(z.get("stripped", false)):
		z["stripped"] = true
		_body_seen(p, "body_strip")


## Arrows and small things right under the player's feet go in by themselves.
func _auto_pickup() -> void:
	var p = game.player
	for i in range(game.ground_items.size() - 1, -1, -1):
		var g: Dictionary = game.ground_items[i]
		if g["id"] == "ammo_craft" and p.position.distance_to(g["pos"]) < 1.0:
			pick_up(p, i)


# ---------------------------------------------------------------- salvage, spots

func spot_default(p, id: String, verb: String) -> void:
	if _wait_blow(p, spot_default.bind(p, id, verb)):
		return
	var spot: Dictionary = game.data["spots"][id]
	match spot["kind"]:
		"salvage":
			if spot["state"] == "intact":
				game.make_sound(FieldGrid.center(spot["cell"]), salvage_level(id), "salvage", p)
				p.start_action("salvage", "뜯어내기", SALVAGE_TIME, _salvaged.bind(p, id))
		"water_tower":
			water_tower_card(p)
		"ladder":
			ladder(p, verb)
		"inspect", "deep":
			game.mission_play.spot(p, id)
		"conveyor":
			game.mission_play.conveyor_card(p)
		"work_site":
			if work_started:
				game.hud.work_panel()
			else:
				start_work(p)
		"core":
			core_scene(p, id)


## A freight yard's or works' stopped machine (decision 426, core_scenes.gd). A core left in it
## comes away in half a minute of normal noise, start and end; a stripped one is a short look.
## A hidden core looks stripped: without the engine hand it stays where it is.
func core_scene(p, id: String) -> void:
	var spot: Dictionary = game.data["spots"][id]
	match String(spot["state"]):
		"core":
			game.make_sound(FieldGrid.center(spot["cell"]), SimNoise.Level.NORMAL, "salvage", p)
			p.start_action("salvage", "떼어 내기", CoreScenes.DETACH_SECONDS, _core_taken.bind(p, id))
		"bare", "hidden", "seen", "seen_hidden":
			if spot["state"] == "bare":
				spot["state"] = "seen"
			elif spot["state"] == "hidden":
				spot["state"] = "seen_hidden"
			game.view.update_spot(id)
			game.say(p, "쓸 만한 건 이미 뜯겨 나갔다.")


func _core_taken(p, id: String) -> void:
	var spot: Dictionary = game.data["spots"][id]
	if spot["state"] != "core":
		return
	spot["state"] = "taken"
	game.make_sound(FieldGrid.center(spot["cell"]), SimNoise.Level.NORMAL, "salvage", p)
	p.add_item(spot["item"])
	game.view.update_spot(id)
	game.say(p, "%s를 떼어 냈다." % game.item_name(spot["item"]))


func _salvaged(p, id: String) -> void:
	var spot: Dictionary = game.data["spots"][id]
	spot["state"] = "taken"
	game.make_sound(FieldGrid.center(spot["cell"]), salvage_level(id), "salvage", p)
	p.add_item(spot["material"], int(spot["amount"]))
	game.view.update_spot(id)
	game.say(p, "%s %d 얻었다." % [game.item_name(spot["material"]), int(spot["amount"])])
	if id.begins_with(DRIVE_PREFIX) and drives_left() == 0:
		# The last drive off: the core comes away, and the scrap that held it
		# lies there in a heap, to be taken as any box's things are.
		p.add_item(CORE_ITEM)
		var heap: Array = []
		heap.resize(CORE_SCRAP)
		heap.fill("scrap")
		game.data["containers"][CORE_HEAP] = {"id": CORE_HEAP, "name": "뜯어낸 고철 더미", "cell": spot["cell"], "level": 0, "building": game.grid.building_at(spot["cell"]), "search": 5, "items": heap, "locked": false, "searched": false}
		game.view.add_container(CORE_HEAP)
		game.say(p, "%s를 떼어 냈다. 고철 더미가 나왔다." % game.item_name(CORE_ITEM))


## Taking a plough's drive apart is loud work, start and end (user decision
## 176: six points a drive, so two are still quiet and the third is not).
static func salvage_level(id: String) -> int:
	return SimNoise.Level.LOUD if id.begins_with(DRIVE_PREFIX) else SimNoise.Level.NORMAL


## How many of the plough's drives are still on it.
func drives_left() -> int:
	var n := 0
	for id: String in game.data["spots"]:
		if id.begins_with(DRIVE_PREFIX) and game.data["spots"][id]["state"] == "intact":
			n += 1
	return n


# ---------------------------------------------------------------- water tower

## Frozen water tower: burn coal (2 min, smoke calls each minute) or shovel
## snow in (4 min, quiet, one person's hands are tied). s2_station 2.4.
func water_tower_card(p) -> void:
	var tower: Dictionary = game.data["spots"]["water_tower"]
	if tower["state"] != "frozen":
		game.hud.toast("급수탑: %s" % {"fire": "불이 타는 중", "snow": "눈을 퍼 넣는 중", "thawed": "녹았다"}.get(tower["state"], tower["state"]))
		return
	game.hud.card("water_tower", "급수탑이 얼어 있다. 물이 없으면 기관이 오래 못 간다.", [
		{"id": "fire", "label": "불을 피운다", "say": "\"석탄 셋을 태워. 연기는 감수한다!\"", "cost": "석탄 −3 · 2분 · 1분마다 보통 소리"},
		{"id": "snow", "label": "눈을 퍼 넣는다", "say": "\"조용히 하자. 손으로 퍼 넣는다.\"", "cost": "4분 · 조용함 · 한 사람이 묶인다"},
		{"id": "leave", "label": "그냥 둔다", "say": "\"물은 다음 정차에서 구한다.\"", "cost": "없음"},
	], Callable(self, "_tower_choice").bind(p))


func _tower_choice(choice: String, p) -> void:
	if _wait_blow(p, _tower_choice.bind(choice, p)):
		return
	var tower: Dictionary = game.data["spots"]["water_tower"]
	game.decisions.append({"id": "water_tower", "choice": choice})
	match choice:
		"fire":
			p.start_action("fire", "불 피우기", FIRE_LIGHT_TIME, _light_tower)
		"snow":
			var who = _nearest_companion(FieldGrid.center(tower["cell"]), 12.0)
			if who == null:
				who = p
			tower["state"] = "snow"
			game.view.update_spot("water_tower")
			who.stop()
			var at := FieldGrid.center(tower["cell"]) + Vector3(1.0, 0, 0.6)
			who.position = Vector3(at.x, who.position.y, at.z) if who.position.distance_to(at) < 3.0 else who.position
			who.start_action("snow", "눈 퍼 넣기", SNOW_TIME, _thawed)
			game.say(who, "%s 눈을 퍼 넣는다." % who.display_name)
		"leave":
			pass


func _light_tower() -> void:
	var tower: Dictionary = game.data["spots"]["water_tower"]
	tower["state"] = "fire"
	coal_spent += 3.0
	fire_left = FIRE_BURN
	fire_noise_t = 0.0
	game.view.update_spot("water_tower")


func _thawed() -> void:
	var tower: Dictionary = game.data["spots"]["water_tower"]
	tower["state"] = "thawed"
	game.view.update_spot("water_tower")
	game.set_radio("기관사: 급수탑 물이 나온다. 넣는다.", "reply")


func _tower(delta: float) -> void:
	if fire_left <= 0.0:
		return
	fire_left -= delta
	fire_noise_t -= delta
	if fire_noise_t <= 0.0:
		fire_noise_t = 60.0
		game.make_sound(FieldGrid.center(game.data["spots"]["water_tower"]["cell"]), SimNoise.Level.NORMAL, "smoke")
	if fire_left <= 0.0:
		_thawed()


func _nearest_companion(at: Vector3, r: float):
	var best = null
	var best_d := r
	for p in game.squad:
		if p == game.player or not p.is_alive() or not p.can_act():
			continue
		var d: float = p.position.distance_to(at)
		if d < best_d:
			best_d = d
			best = p
	return best


# ---------------------------------------------------------------- signal box ladder

## Up the signal box ladder (the only way down from there is the ladder).
func on_signal_top(p) -> bool:
	return p.upstairs and game.grid_at(p.position).building_at(FieldGrid.cell_of(p.position)) == 1


## Up the ladder: fast is a normal sound, careful is quiet but slow. Upstairs
## the forecast gets sharper and the view wider (s2_station 2.2).
func ladder(p, verb: String) -> void:
	if _wait_blow(p, ladder.bind(p, verb)):
		return
	if on_signal_top(p):
		p.start_action("climb", "내려가기", CLIMB_CAREFUL if verb == "careful" else CLIMB_FAST, _climbed.bind(p, false))
		return
	if verb == "":
		game.hud.offer([
			{"label": "빨리 오른다", "call": ladder.bind(p, "fast")},
			{"label": "조심히 오른다", "call": ladder.bind(p, "careful")},
		])
		return
	if verb == "fast":
		game.make_sound(p.position, SimNoise.Level.NORMAL, "ladder", p)
	p.brain["on_ladder"] = true
	p.start_action("climb", "오르기", CLIMB_CAREFUL if verb == "careful" else CLIMB_FAST, _climbed.bind(p, true))


func _climbed(p, up: bool) -> void:
	p.brain["on_ladder"] = false
	p.position.y = UPSTAIRS_Y if up else 0.0
	if p == game.player:
		if up:
			game.forecast_precision = 1
			game.set_radio("신호소 위: " + game.director.forecast(game.clock.elapsed, 1, game.clock), "say")
		else:
			game.hud.toast("내려왔다.")


# ---------------------------------------------------------------- rooftop ladders

## A rooftop's skylight ladder (stairs with "roof", house_layout.md 6.1): the signal box
## ladder's rule as it is. Fast is a normal sound, careful is quiet but slow; grabbed on
## it, 30% to fall (_ladder_falls). Up or down the same. The dead cannot climb it (paths
## skip ladders), and the companions wait at its foot.
func climb_ladder(p, s: Dictionary, verb: String = "") -> void:
	if not p.can_act():
		return
	var up: bool = game.level_of(p.position) == int(s["low"])
	if verb == "":
		game.hud.offer([
			{"label": "빨리 오른다" if up else "빨리 내려간다", "call": climb_ladder.bind(p, s, "fast")},
			{"label": "조심히 오른다" if up else "조심히 내려간다", "call": climb_ladder.bind(p, s, "careful")},
		])
		return
	if verb == "fast":
		game.make_sound(p.position, SimNoise.Level.NORMAL, "ladder", p)
	p.brain["on_ladder"] = true
	p.start_action("climb", "오르기" if up else "내려가기", CLIMB_CAREFUL if verb == "careful" else CLIMB_FAST, _ladder_done.bind(p, s, up))


func _ladder_done(p, s: Dictionary, up: bool) -> void:
	p.brain["on_ladder"] = false
	p.position = game.lift(s["cell"], int(s["high"]) if up else int(s["low"]))
	if p == game.player and up and not game.roof_seen:
		# Up on a roof the forecast gets sharper, once a stop (6.2, the signal box's rule).
		game.roof_seen = true
		game.forecast_precision = 1
		game.set_radio("옥상: " + game.director.forecast(game.clock.elapsed, 1, game.clock), "say")


## Grabbed on the ladder: 30% to fall and break a leg (body_injury 3.2).
func _ladder_falls() -> void:
	for p in game.people_alive():
		if p.brain.get("on_ladder", false) and not p.grabbers.is_empty():
			p.brain["on_ladder"] = false
			if game.rng.randf() < 0.3:
				game.combat.fall(p, "사다리에서 떨어졌다", 1.0, true)


# ---------------------------------------------------------------- over the train

## The two ends of a way over the train: the ground cell above its first cell
## and the one below its last.
static func crossing_ends(crossing: Dictionary) -> Array:
	var cells: Array = crossing["cells"].duplicate()
	cells.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.y < b.y)
	return [cells[0] + Vector2i(0, -1), cells[cells.size() - 1] + Vector2i(0, 1)]


## A way written over ground one walks (the wayside maps mark the way round
## the train's ends so) is no climb: there is nothing to go over.
func walked_round(crossing: Dictionary) -> bool:
	for c: Vector2i in crossing["cells"]:
		if game.grid.people_can_walk(c):
			return true
	return false


## The way over the train p stands at: {"i", "from", "to"}, or {} if none.
func crossing_at(p) -> Dictionary:
	if game.level_of(p.position) != 0:
		return {}
	var ways: Array = game.data.get("crossings", [])
	for i in ways.size():
		if walked_round(ways[i]):
			continue
		var ends: Array = crossing_ends(ways[i])
		for k in 2:
			if FieldGrid.center(ends[k]).distance_to(p.position) < CROSS_NEAR:
				return {"i": i, "from": ends[k], "to": ends[1 - k]}
	return {}


## Hurt enough that the climb is beyond them (as the end of a stop counts the hurt).
func too_hurt_to_cross(p) -> bool:
	return p.body.bleed >= 2 or p.body.leg_fracture or p.body.arm_fracture or p.body.downed


## Why p cannot go over there now ("" if they can): the way is for people on
## foot, one at a time; the hurt and whoever carries someone go round.
func cross_refused(p, way: Dictionary) -> String:
	var who: Dictionary = game.data["crossings"][int(way["i"])].get("who", {})
	if not bool(who.get("person", true)):
		return "여기로는 못 넘는다."
	if too_hurt_to_cross(p) and not bool(who.get("wounded", false)):
		return "다친 몸으로는 못 넘는다. 열차 끝으로 돌아야 한다."
	if p.carrying_wounded != null:
		return "사람을 업고는 못 넘는다."
	if p.carry_state() >= 1 and not bool(who.get("carrying", true)):
		return "짐을 들고는 못 넘는다."
	for o in game.people_alive():
		if o != p and o.action == "climb" and int(o.brain.get("crossing", -1)) == int(way["i"]):
			return "앞사람이 넘는 중이다."
	return ""


func cross_seconds(p) -> float:
	return CROSS_LOADED if p.carry_state() >= 1 else CROSS_TIME


## Over the train: hands full of the climb for its seconds, then down on the
## other side. The companions who follow come over after, one by one.
func cross_train(p, way: Dictionary) -> bool:
	if striking(p):
		return false
	var no: String = cross_refused(p, way)
	if no != "":
		if p == game.player:
			game.hud.toast(no)
		return false
	p.aim.stop()
	p.brain["crossing"] = int(way["i"])
	p.start_action("climb", "넘는 중", cross_seconds(p), _crossed.bind(p, way))
	game.make_sound(p.position, SimNoise.Level.QUIET, "ladder", p)
	return true


func _crossed(p, way: Dictionary) -> void:
	p.brain.erase("crossing")
	p.brain.erase("cross")
	p.position = FieldGrid.center(way["to"])
	p.stop()
	if p != game.player:
		return
	for o in game.squad:
		if o != p and o.is_alive() and o.command == "follow" and o.position.distance_to(FieldGrid.center(way["from"])) < CROSS_FOLLOW:
			o.brain["cross"] = way


## Grabbed half way over: down they come, on the side they started from.
func _crossing_falls() -> void:
	for p in game.people_alive():
		if p.brain.has("crossing") and (p.action != "climb" or not p.grabbers.is_empty()):
			var held: bool = not p.grabbers.is_empty()
			p.brain.erase("crossing")
			if held:
				game.combat.fall(p, "넘다가 떨어졌다", 0.05, true)


# ---------------------------------------------------------------- work site

## The crew comes down only when nothing awake stands near the wagons
## (the frozen ones under the snow don't count: that is the trap).
func site_clear() -> bool:
	var site: Vector3 = FieldGrid.center(game.data["spots"]["work_site"]["cell"])
	for z in game.zombies.in_radius(site, 16.0):
		if game.zombies.active(z) and z["state"] != "downed" and z["state"] != "waking":
			return false
	return true


## Coal work site: four carriers and two escorts come down from the train.
func start_work(p) -> void:
	if not game.mission_play.crew_allowed():
		game.hud.toast("살피기만 · 작업조 안 부름")
		return
	if not site_clear():
		game.hud.toast("측선에 망자")
		return
	if game.allies_alive().size() + 6 > game.ALLY_CAP:
		game.hud.toast("사람이 너무 많음")
		return
	work_started = true
	var spot: Dictionary = game.data["spots"]["work_site"]
	spot["state"] = "open"
	game.view.update_spot("work_site")
	var doors: Array = game.data["spawns"]["train_door"]
	var rows := [
		{"id": "s2_crew_01", "name": "운송조 1", "role": "worker", "skills": {"strength": 6, "melee": 1, "shooting": 0, "stealth": 1, "search": 1}, "hands": []},
		{"id": "s2_crew_02", "name": "운송조 2", "role": "worker", "skills": {"strength": 6, "melee": 1, "shooting": 0, "stealth": 1, "search": 1}, "hands": []},
		{"id": "s2_crew_03", "name": "운송조 3", "role": "worker", "skills": {"strength": 5, "melee": 1, "shooting": 0, "stealth": 1, "search": 1}, "hands": []},
		{"id": "s2_crew_04", "name": "운송조 4", "role": "worker", "skills": {"strength": 7, "melee": 2, "shooting": 0, "stealth": 1, "search": 1}, "hands": []},
		{"id": "s2_escort_01", "name": "호위조 1", "role": "escort", "skills": {"strength": 6, "melee": 3, "shooting": 3, "stealth": 1, "search": 1}, "hands": [["shotgun", "factory", 0.8], ["crowbar", "factory", 0.9]]},
		{"id": "s2_escort_02", "name": "호위조 2", "role": "escort", "skills": {"strength": 6, "melee": 4, "shooting": 1, "stealth": 1, "search": 1}, "hands": [["axe", "factory", 0.9]]},
	]
	for i in range(rows.size()):
		var c: Vector2i = doors[i % doors.size()]
		var q = game.make_person(rows[i], FieldGrid.center(c) + Vector3(game.rng.randf_range(-0.5, 0.5), 0, 0.3))
		q.brain = {"job": "dig", "side": i % 2}
		game.crew.append(q)
		game.receipt.person("sent", q.pid)
	game.set_radio("기관사: 작업조 내려간다. 석탄을 퍼 오게 지켜라.", "reply")
	if game.mission_play.crew_down(p):
		return
	game.hud.work_panel()


## Pickaxes ring once a minute while anyone is digging (wakes the frozen ones).
func _dig_noise(delta: float) -> void:
	if not work_started:
		return
	if game.mission_play.belt_noise(delta):
		return
	var digging := false
	for p in game.crew:
		if p.is_alive() and p.action == "dig":
			digging = true
	if not digging:
		return
	dig_noise_t -= delta
	if dig_noise_t <= 0.0:
		dig_noise_t = 60.0
		game.make_sound(FieldGrid.center(game.data["spots"]["work_site"]["cell"]), SimNoise.Level.NORMAL, "pickaxe")


func coal_left() -> float:
	var n := 0.0
	for w in game.data["wagons"]:
		n += float(w.get("coal", 0.0))
	return n


# ---------------------------------------------------------------- sewer lid

## Put something heavy on the street manhole: one plank or scrap, 8 s, a
## normal sound. The culvert can't be closed (field_unified 6 하수도).
func block_lid(p, key: String) -> void:
	if _wait_blow(p, block_lid.bind(p, key)):
		return
	if not game.FieldMaps.lid(key):
		if p == game.player:
			game.hud.toast("%s는 막을 수 없다." % ("암거" if key == "culvert" else "이 구멍"))
		return
	if not game.director.is_open(key):
		return
	var mat := ""
	for m in ["plank", "scrap", "wood"]:
		if int(p.items.get(m, 0)) > 0:
			mat = m
			break
	if mat == "":
		if p == game.player:
			game.hud.toast("판자나 고철 없음")
		return
	game.make_sound(p.position, SimNoise.Level.NORMAL, "lid", p)
	p.start_action("lid", "뚜껑 막기", BLOCK_LID_TIME, _lid_blocked.bind(p, key, mat))


func _lid_blocked(p, key: String, mat: String) -> void:
	if not p.take_item(mat):
		return
	game.director.block(key)
	game.view.update_manhole(key, true)
	game.receipt.place_note("manholeBlocked", true)
	game.hud.toast("맨홀을 막았다. 그 몫은 %s 나온다." % ("암거로" if game.data["manholes"].has("culvert") else "다른 길로"))


# ---------------------------------------------------------------- treatment, crafting

## A medic (or anyone) treats another person: kit for heavy bleeding, bandages
## otherwise; a medic within 2 min of the wound eases it one more step.
func treat(medic, o) -> void:
	if _wait_blow(medic, treat.bind(medic, o)):
		return
	if medic.action != "" or o.body.bleed <= 0:
		return
	var src = medic if (medic.items.has("medkit") or medic.items.has("bandage")) else o
	var heavy: bool = o.body.bleed >= 2
	var t := 6.0 if medic.medical == "none" else 4.0
	medic.face_point(o.position)
	medic.start_action("treat", "치료", t, _treated.bind(medic, o, src, heavy))
	_note_care(medic, o, "", t, "치료")


func _treated(medic, o, src, heavy: bool) -> void:
	if heavy and src.take_item("medkit"):
		o.body.use_kit()
	elif heavy and int(src.items.get("bandage", 0)) >= 2:
		# Only what was really wound on is taken.
		o.body.bandage(2)
		var used: int = o.body.last_bandages_used
		if medic.medical != "none" and o.body.quick_treat_ok(game.clock.elapsed) and int(src.items.get("bandage", 0)) > used:
			o.body.bandage(1)
			used += o.body.last_bandages_used
		if used > 0:
			src.take_item("bandage", used)
	elif int(src.items.get("bandage", 0)) >= 1:
		o.body.bandage(1)
		if o.body.last_bandages_used > 0:
			src.take_item("bandage", o.body.last_bandages_used)
	else:
		game.say(medic, "붕대가 없다.")
		return
	game.say(medic, "%s → %s 치료했다." % [medic.display_name, o.display_name])
	if o != medic:
		game.shout(o, "treated")


func self_bandage(p) -> void:
	if p.body.bleed <= 0:
		game.hud.toast("피가 나지 않는다.")
		return
	treat(p, p)


## What the two of them carry between them: the tools of the treatment plan.
func care_tools(medic, o) -> Dictionary:
	var have := {}
	for who in ([medic] if medic == o else [medic, o]):
		for id in who.items:
			have[id] = int(have.get(id, 0)) + int(who.items[id])
	return have


## Your own body, or someone within arm's reach.
func in_care_reach(medic, o) -> bool:
	return medic == o or medic.position.distance_to(o.position) <= CARE_REACH


## The plan for one wound with what the two carry (body picture, body_injury 4.6).
func care_plan(medic, o, wound: Dictionary, mode: String) -> Array:
	return Treatment.plan(wound, care_tools(medic, o), mode)


## Care for one chosen wound: first aid (blood only) or every step the tools
## allow, one timed step after another. Moving away cuts it short like any
## other slow work; what was done stays done. False when nothing can be done.
func treat_wound(medic, o, wound: Dictionary, mode: String) -> bool:
	if medic.action != "" or not medic.can_act() or not in_care_reach(medic, o):
		return false
	return _care_next(medic, o, wound, mode)


func _care_next(medic, o, wound: Dictionary, mode: String) -> bool:
	if o.body.index_of(wound) < 0 or not medic.can_act() or striking(medic) or not in_care_reach(medic, o):
		return false
	var steps: Array = Treatment.runnable(care_plan(medic, o, wound, mode))
	if steps.is_empty():
		return false
	var step: Dictionary = steps[0]
	if medic != o:
		medic.face_point(o.position)
	var seconds: float = Treatment.seconds(step, medic.medical)
	medic.start_action("treat", String(step["label"]), seconds, _care_done.bind(medic, o, wound, mode, step))
	_note_care(medic, o, String(wound.get("part", "")), seconds, String(step["label"]))
	return true


## For the drawing only: whom the treatment just begun is for and where.
func _note_care(medic, o, part: String, seconds: float, label: String) -> void:
	if medic.action == "treat":
		medic.set_meta(Pose.CARE, {"of": o, "part": part, "total": seconds, "label": label})


func _care_done(medic, o, wound: Dictionary, mode: String, step: Dictionary) -> void:
	var index: int = o.body.index_of(wound)
	if index < 0:
		return
	if Treatment.apply(o.body, index, String(step["id"])) <= 0:
		return
	# What it takes comes from the one who treats first, then from the one treated.
	for item: String in step["uses"]:
		var used: int = int(step["uses"][item])
		var from_first: int = mini(used, int(medic.items.get(item, 0)))
		if from_first > 0:
			medic.take_item(item, from_first)
		if used > from_first:
			o.take_item(item, used - from_first)
	if not _care_next(medic, o, wound, mode):
		game.say(medic, "%s: 처치했다." % Treatment.wound_text(wound))


func splint(p) -> void:
	if _wait_blow(p, splint.bind(p)):
		return
	if not (p.body.arm_fracture or p.body.leg_fracture) or p.body.splinted:
		game.hud.toast("부목 댈 데 없음")
		return
	if int(p.items.get("plank", 0)) <= 0 and int(p.items.get("wood", 0)) <= 0:
		game.hud.toast("판자 없음")
		return
	p.start_action("splint", "부목", 10.0, _splinted.bind(p))


func _splinted(p) -> void:
	if p.take_item("plank") or p.take_item("wood"):
		p.body.splint()


func tear_bandage(p) -> void:
	if _wait_blow(p, tear_bandage.bind(p)):
		return
	if int(p.items.get("cloth", 0)) <= 0:
		game.hud.toast("천이 없다.")
		return
	p.start_action("craft", "붕대 만들기", 5.0, _torn.bind(p))


func _torn(p) -> void:
	if p.take_item("cloth"):
		p.add_item("bandage", 2)


func rub_snow(p) -> void:
	if _wait_blow(p, rub_snow.bind(p)):
		return
	p.start_action("rub", "눈으로 문지르기", RUB_SNOW_TIME, p.rub_snow)


## Things the player can do right here, for the context buttons.
func context(p) -> Array:
	var out: Array = _near_things(p)
	if p.body.bleed > 0 and (p.items.has("bandage") or p.items.has("medkit")):
		out.append({"label": "붕대", "call": self_bandage.bind(p)})
	if (p.body.arm_fracture or p.body.leg_fracture) and not p.body.splinted:
		out.append({"label": "부목", "call": splint.bind(p)})
	if p.blood_soaked:
		out.append({"label": "눈으로 문지름", "call": rub_snow.bind(p)})
	if p.items.has("cloth") and int(p.items.get("bandage", 0)) < 2:
		out.append({"label": "붕대 만들기", "call": tear_bandage.bind(p)})
	# Made there and then (P22): a door boarded up, a stake from a plank.
	if game.level_of(p.position) == 0:
		for dc: Vector2i in game.grid.doors:
			if FieldGrid.center(dc).distance_to(p.position) < NEAR_USE and can_board(p, dc):
				out.append({"label": "문 막기", "call": board_door.bind(p, dc)})
				break
	if p.items.has("plank") and p.hands.size() < 2:
		out.append({"label": "말뚝 깎기", "call": whittle_stake.bind(p)})
	for key in game.data["manholes"]:
		if game.FieldMaps.lid(key) and game.director.is_open(key) and p.position.distance_to(FieldGrid.center(game.data["manholes"][key])) < 2.5:
			out.append({"label": "맨홀 막기", "call": block_lid.bind(p, key)})
	var wall: Dictionary = game.holdout.wall_row(p)
	if not wall.is_empty():
		out.append(wall)
	if on_signal_top(p):
		out.append({"label": "내려가기", "call": ladder.bind(p, "fast")})
	var way: Dictionary = crossing_at(p)
	if not way.is_empty():
		out.append({"label": "열차 넘기 %d초" % int(cross_seconds(p)), "call": cross_train.bind(p, way)})
	for o in game.allies_alive():
		if o != p and o.body.bleed > 0 and o.position.distance_to(p.position) < 1.8:
			out.append({"label": "%s 치료" % o.display_name, "call": treat.bind(p, o)})
			break
	# Leaving is not in this list: it has a pad of its own (hud.depart_button),
	# so that whatever lies next to the leader it is one press away.
	return out


const NEAR_USE: float = 1.7


## The situation pad (field_unified 10): what is within a step of the player
## on their floor, closest first, at most two (stairs, a box, a door, a
## window, something on the ground).
func _near_things(p) -> Array:
	var rows: Array = []
	var lv: int = game.level_of(p.position)
	for s in game.stairs:
		if not (s["low"] == lv or s["high"] == lv):
			continue
		if s["ladder"] and not s.has("roof"):
			continue
		var at: Vector3 = game.lift(s["cell"], lv)
		var d: float = at.distance_to(p.position)
		if d < NEAR_USE:
			var up: bool = s["low"] == lv
			if s["ladder"]:
				rows.append([d, "옥상으로" if up else "사다리 내려가기", climb_ladder.bind(p, s, "")])
			else:
				rows.append([d, "올라가기" if up else "내려가기", take_stairs.bind(p, s)])
	for id in game.data["containers"]:
		var c: Dictionary = game.data["containers"][id]
		var at: Vector3 = game.lift(c["cell"], int(c.get("level", 0)))
		var d: float = at.distance_to(p.position)
		if d < NEAR_USE and not c["searched"]:
			rows.append([d, "뒤지기", go_and_do.bind(p, "container", id, at)])
	for i in range(game.ground_items.size()):
		var g: Dictionary = game.ground_items[i]
		var d: float = g["pos"].distance_to(p.position)
		if d < NEAR_USE:
			rows.append([d, "입기" if g.has("garment") else "줍기", go_and_do.bind(p, "item", i, g["pos"])])
	# The nearest one lying there whose pockets nobody has been through.
	var body: Dictionary = {}
	var body_d: float = NEAR_USE
	for z in game.zombies.list:
		if game.zombies.lootable(z) and game.level_of(z["pos"]) == lv:
			var d: float = z["pos"].distance_to(p.position)
			if d < body_d:
				body_d = d
				body = z
	if not body.is_empty():
		rows.append([body_d, "품 뒤지기", go_and_do.bind(p, "body", int(body["id"]), body["pos"])])
	# The nearest one lying there with clothes still on it (decision 434): just
	# behind its pockets, so with both to do the pockets come first.
	var clad: Dictionary = {}
	var clad_d: float = NEAR_USE
	for z in game.zombies.list:
		if z["state"] in ["dead", "downed", "rising"] and game.level_of(z["pos"]) == lv:
			var d: float = z["pos"].distance_to(p.position)
			if d < clad_d and game.zombies.strippable(z):
				clad_d = d
				clad = z
	if not clad.is_empty():
		rows.append([clad_d + 0.01, "옷 가져오기", go_and_do.bind(p, "strip", int(clad["id"]), clad["pos"])])
	if lv == 0:
		var cell := FieldGrid.cell_of(p.position)
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				var c: Vector2i = cell + Vector2i(dx, dy)
				var at := FieldGrid.center(c)
				var d: float = at.distance_to(p.position)
				if game.grid.doors.has(c):
					var st: String = game.grid.doors[c]["state"]
					if st != "broken":
						rows.append([d, "문 닫기" if st == "open" else ("문 따기" if st == "locked" else "문 열기"), go_and_do.bind(p, "door", c, at)])
				elif game.grid.windows.has(c):
					rows.append([d, "창", go_and_do.bind(p, "window", c, at)])
		for id in game.data["spots"]:
			var spot: Dictionary = game.data["spots"][id]
			var at := FieldGrid.center(spot["cell"])
			var d: float = at.distance_to(p.position)
			var usable: bool = spot["kind"] in ["ladder", "water_tower", "salvage", "inspect", "deep", "conveyor"] or spot["kind"] == "core" and spot["state"] != "taken"
			if d < NEAR_USE + 0.5 and usable:
				rows.append([d, spot["name"], go_and_do.bind(p, "spot", id, at)])
	rows.sort_custom(func(a, b): return a[0] < b[0])
	var out: Array = []
	for row in rows.slice(0, 2):
		out.append({"label": row[1], "call": row[2]})
	return out


## Up or down the stair under (or next to) the player.
func take_stairs(p, s: Dictionary) -> void:
	var lv: int = game.level_of(p.position)
	var other: int = s["high"] if s["low"] == lv else s["low"]
	var path: PackedVector3Array = game.find_path(p.position, game.lift(s["cell"], other), false)
	if not path.is_empty():
		p.brain.erase("goal")
		p.drive_speed = 0.0
		p.go_to(path, p.running)


# ---------------------------------------------------------------- platform

func on_platform(p) -> bool:
	return game.FieldMaps.by_train(game.data, FieldGrid.cell_of(p.position))


## Anything put down on the platform counts as loaded (s2_station 2.4).
func _auto_unload() -> void:
	for p in game.squad:
		if not p.is_alive() or not game.FieldMaps.by_train(game.data, FieldGrid.cell_of(p.position), "unloading"):
			continue
		var put: Array = []
		for id in p.items.keys():
			# A key, an empty tin and the can opener stay with the one who has them.
			if UNLOAD_KEEP.has(id) or W.is_known(id) or FieldItems.stays_on_body(id):
				continue
			var n: int = int(p.items[id])
			game.unloaded[id] = int(game.unloaded.get(id, 0)) + n
			put.append("%s %d" % [game.item_name(id), n])
			p.items.erase(id)
		if not put.is_empty():
			game.telemetry.trip()
			game.say(p, "%s 실었다: %s" % [p.display_name, ", ".join(put)])
