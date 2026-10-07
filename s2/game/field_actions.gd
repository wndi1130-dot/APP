extends RefCounted
## What people do with the place: doors, windows, searching, salvage, the
## water tower, the signal box ladder, the coal work site, sewer lids,
## unloading and departure (s2_station 2.2-2.4, body_injury 3·6·9).

const FieldGrid = preload("res://game/world/field_grid.gd")
const W = preload("res://game/sim/weapons.gd")
const SimNoise = preload("res://game/sim/noise.gd")
const Carry = preload("res://game/sim/carry.gd")
const HordeDirector = preload("res://game/sim/horde_director.gd")

const REACH: float = 1.4
const DOOR_TIME: float = 0.5
const PRY_TIME: float = 4.0
const KICK_TIME: float = 1.0
const GLASS_TIME: float = 3.0
const SALVAGE_TIME: float = 6.0
const FIRE_LIGHT_TIME: float = 10.0
const FIRE_BURN: float = 120.0
const SNOW_TIME: float = 240.0
const CLIMB_FAST: float = 3.0
const CLIMB_CAREFUL: float = 6.0
const BLOCK_LID_TIME: float = 8.0
const RUB_SNOW_TIME: float = 10.0
const UPSTAIRS_Y: float = 3.0
const UNLOAD_KEEP: Array = ["bandage", "cloth", "plank", "medkit", "bottle_spirit", "arrow", "flare"]
const AMMO_ITEMS: Dictionary = {"ammo_pistol": ["pistol", 6], "ammo_shell": ["shell", 4], "arrow": ["craft", 1]}

var game
var coal_delivered: float = 0.0
var coal_spent: float = 0.0
var work_started: bool = false
var fire_left: float = 0.0
var fire_noise_t: float = 0.0
var dig_noise_t: float = 0.0
var unload_t: float = 0.0


func _init(field_game) -> void:
	game = field_game


func update(delta: float) -> void:
	_tower(delta)
	_dig_noise(delta)
	_ladder_falls()
	_player_goal()
	unload_t -= delta
	if unload_t <= 0.0:
		unload_t = 0.5
		_auto_unload()
		_auto_pickup()


# ---------------------------------------------------------------- go and do

## Walk to an interactable, then act. kind: door | window | container | spot | item | manhole.
func go_and_do(p, kind: String, key, at: Vector3, verb: String = "") -> void:
	p.brain["goal"] = {"kind": kind, "key": key, "at": at, "verb": verb}
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
		if not p.brain.has("goal") or not p.can_act() or p.action != "":
			continue
		var g: Dictionary = p.brain["goal"]
		if p.path.is_empty() or p.position.distance_to(g["at"]) <= REACH:
			if p.position.distance_to(g["at"]) <= REACH + 0.6:
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
			pick_up(p, g["key"])
		"manhole":
			block_lid(p, g["key"])


# ---------------------------------------------------------------- doors

func open_door_on_way(p, c: Vector2i) -> void:
	var door: Dictionary = game.grid.doors[c]
	if p.action != "":
		return
	if door["state"] == "locked":
		p.stop()
		if p == game.player:
			game.hud.toast("잠겼다. 쇠지렛대로 따거나 차서 연다.")
		return
	# Opening a door on the way keeps the walk going afterwards.
	var keep: PackedVector3Array = p.path.duplicate()
	var run: bool = p.running
	p.start_action("door", "문", DOOR_TIME, _door_on_way_done.bind(p, c, keep, run))


func _door_on_way_done(p, c: Vector2i, keep: PackedVector3Array, run: bool) -> void:
	_set_door(c, "open")
	p.go_to(keep, run)


func door_default(p, c: Vector2i, verb: String) -> void:
	var door: Dictionary = game.grid.doors[c]
	match verb:
		"close":
			if door["state"] == "open":
				p.start_action("door", "문 닫기", DOOR_TIME, _set_door.bind(c, "closed"))
		"pry":
			pry_door(p, c)
		"kick":
			kick_door(p, c)
		_:
			if door["state"] == "closed":
				p.start_action("door", "문 열기", DOOR_TIME, _set_door.bind(c, "open"))
			elif door["state"] == "open":
				p.start_action("door", "문 닫기", DOOR_TIME, _set_door.bind(c, "closed"))
			elif door["state"] == "locked":
				if has_pry(p):
					pry_door(p, c)
				elif p == game.player:
					game.hud.toast("잠겼다. 쇠지렛대가 있으면 딴다. 차면 시끄럽다.")


func _set_door(c: Vector2i, state: String) -> void:
	# Something standing in the doorway keeps it from closing.
	if state == "closed" and not game.zombies.in_radius(FieldGrid.center(c), 0.6).is_empty():
		return
	game.grid.set_door_state(c, state)
	game.view.update_door(c)
	_check_raider_door(c)


func has_pry(p) -> bool:
	for h in p.hands:
		if bool(W.get_data(h["id"]).get("pry", false)):
			return true
	return false


## Pry a locked door with a crowbar: a few seconds and a normal sound.
func pry_door(p, c: Vector2i) -> void:
	if not has_pry(p):
		if p == game.player:
			game.hud.toast("쇠지렛대가 손에 있어야 한다.")
		return
	game.make_sound(FieldGrid.center(c), SimNoise.Level.NORMAL, "pry", p)
	p.start_action("pry", "문 따기", PRY_TIME, _set_door.bind(c, "open"))


## Kick: one loud try, half the time it gives (s2_station 2.4).
func kick_door(p, c: Vector2i) -> void:
	p.start_action("kick", "문 차기", KICK_TIME, _kicked.bind(p, c))


func _kicked(p, c: Vector2i) -> void:
	game.make_sound(FieldGrid.center(c), SimNoise.Level.LOUD, "kick", p)
	if game.rng.randf() < 0.5:
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
	var w: Dictionary = game.grid.windows[c]
	if not w["broken"]:
		if verb == "break" or p != game.player:
			p.start_action("window", "창 깨기", 1.0, _break_window.bind(p, c))
		else:
			game.hud.toast("창은 깨야 넘는다. 깨면 시끄럽고 안의 온기가 빠진다.")
			game.hud.offer([{"label": "창을 깬다", "call": window_default.bind(p, c, "break")}])
		return
	if w["glass"]:
		p.start_action("glass", "유리 치우기", GLASS_TIME, _clear_glass.bind(c))


func _break_window(p, c: Vector2i) -> void:
	game.grid.break_window(c)
	game.view.update_window(c)
	var b: int = int(game.grid.windows[c]["building"])
	if b >= 0:
		game.data["buildings"][b]["window_broken"] = true
	game.make_sound(FieldGrid.center(c), SimNoise.Level.LOUD, "glass", p)


func _clear_glass(c: Vector2i) -> void:
	game.grid.windows[c]["glass"] = false
	game.view.update_window(c)


## Climbing through a broken window: glass left in the frame cuts (gloves help).
func vault_window(p, c: Vector2i) -> void:
	p.brain["vaulted_" + str(c)] = true
	var w: Dictionary = game.grid.windows[c]
	if w["glass"] and game.rng.randf() < (0.2 if p.gloves else 0.5):
		p.body.apply_cut(false, game.clock.elapsed)
		game.telemetry.injury(game.clock.elapsed, p.pid, "glass")
		if p.team != "raider":
			game.say(p, "%s 유리에 베였다." % p.display_name)


# ---------------------------------------------------------------- searching

func search_time(p, c: Dictionary) -> float:
	return float(c["search"]) / (1.0 + 0.15 * int(p.skills["search"]))


func search(p, id: String) -> void:
	var c: Dictionary = game.data["containers"][id]
	if c["locked"]:
		if has_pry(p):
			game.make_sound(FieldGrid.center(c["cell"]), SimNoise.Level.NORMAL, "pry", p)
			p.start_action("pry", "금고 따기", PRY_TIME + 1.0, _unlock.bind(id))
		elif p == game.player:
			game.hud.toast("잠긴 금고다. 쇠지렛대가 있어야 한다.")
		return
	if c["searched"]:
		if p == game.player:
			game.hud.loot(id)
		return
	c["busy"] = true
	p.start_action("search", "뒤지기", search_time(p, c), _searched.bind(p, id))


func _unlock(id: String) -> void:
	game.data["containers"][id]["locked"] = false
	game.view.update_container(id)


func _searched(p, id: String) -> void:
	var c: Dictionary = game.data["containers"][id]
	c["searched"] = true
	c["busy"] = false
	game.view.update_container(id)
	if p == game.player:
		game.hud.loot(id)
		return
	# A companion takes what fits in the bag without going over the limit.
	var keep: Array = []
	var took: Array = []
	for item in c["items"]:
		if p.weight() + Carry.item_weight(item) <= p.carry_limit():
			p.add_item(item)
			took.append(game.item_name(item))
		else:
			keep.append(item)
	c["items"] = keep
	if not took.is_empty():
		game.say(p, "%s: %s 챙겼다." % [p.display_name, ", ".join(took)])
	elif not keep.is_empty():
		game.say(p, "%s: 가방이 차서 못 챙겼다." % p.display_name)


## Take one item from a searched container into the player's bag.
func take(p, id: String, index: int) -> void:
	var c: Dictionary = game.data["containers"][id]
	if index < 0 or index >= c["items"].size():
		return
	var item: String = c["items"][index]
	c["items"].remove_at(index)
	_receive(p, item, 1)
	if item == "symbol_bell":
		game.make_sound(FieldGrid.center(c["cell"]), SimNoise.Level.NORMAL, "bell", p)
		game.hud.toast("종이 흔들려 울렸다.")
	game.view.update_container(id)


func take_all(p, id: String) -> void:
	var c: Dictionary = game.data["containers"][id]
	while not c["items"].is_empty():
		take(p, id, 0)


func _receive(p, item: String, n: int) -> void:
	if AMMO_ITEMS.has(item) and p.team != "raider":
		var row: Array = AMMO_ITEMS[item]
		game.ammo[row[0]] = int(game.ammo.get(row[0], 0)) + int(row[1]) * n
		return
	p.add_item(item, n)


func pick_up(p, idx: int) -> void:
	if idx < 0 or idx >= game.ground_items.size():
		return
	var g: Dictionary = game.ground_items[idx]
	game.ground_items.remove_at(idx)
	if g.has("weapon"):
		var h: Dictionary = g["weapon"]
		if p.hands.size() < 2:
			p.hands.append(h)
			p.set_weapon_slots(p.hands)
		else:
			p.add_item(h["id"])
		game.say(p, "%s 주웠다." % W.get_data(h["id"]).get("name", h["id"]))
		return
	_receive(p, g["id"], int(g["n"]))


## Arrows and small things right under the player's feet go in by themselves.
func _auto_pickup() -> void:
	var p = game.player
	for i in range(game.ground_items.size() - 1, -1, -1):
		var g: Dictionary = game.ground_items[i]
		if g["id"] == "arrow" and p.position.distance_to(g["pos"]) < 1.0:
			pick_up(p, i)


# ---------------------------------------------------------------- salvage, spots

func spot_default(p, id: String, verb: String) -> void:
	var spot: Dictionary = game.data["spots"][id]
	match spot["kind"]:
		"salvage":
			if spot["state"] == "intact":
				game.make_sound(FieldGrid.center(spot["cell"]), SimNoise.Level.NORMAL, "salvage", p)
				p.start_action("salvage", "뜯어내기", SALVAGE_TIME / float(p.mults()["hands"]), _salvaged.bind(p, id))
		"water_tower":
			water_tower_card(p)
		"ladder":
			ladder(p, verb)
		"work_site":
			if work_started:
				game.hud.work_panel()
			else:
				start_work(p)


func _salvaged(p, id: String) -> void:
	var spot: Dictionary = game.data["spots"][id]
	spot["state"] = "taken"
	game.make_sound(FieldGrid.center(spot["cell"]), SimNoise.Level.NORMAL, "salvage", p)
	p.add_item(spot["material"], int(spot["amount"]))
	game.view.update_spot(id)
	game.say(p, "%s %d 얻었다." % [game.item_name(spot["material"]), int(spot["amount"])])


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
	game.set_radio("기관사: 급수탑 물이 나온다. 넣는다.")


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
			game.set_radio("신호소 위: " + game.director.forecast(game.clock.elapsed, 1, game.clock))
		else:
			game.hud.toast("내려왔다.")


## Grabbed on the ladder: 30% to fall and break a leg (body_injury 3.2).
func _ladder_falls() -> void:
	for p in game.people_alive():
		if p.brain.get("on_ladder", false) and not p.grabbers.is_empty():
			p.brain["on_ladder"] = false
			if game.rng.randf() < 0.3:
				game.combat.fall(p, "사다리에서 떨어졌다", 1.0, true)


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
	if not site_clear():
		game.hud.toast("측선에 아직 저것들이 서 있다. 치우고 불러야 한다.")
		return
	if game.allies_alive().size() + 6 > game.ALLY_CAP:
		game.hud.toast("필드에 사람이 너무 많다.")
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
	game.set_radio("기관사: 작업조 내려간다. 석탄을 퍼 오게 지켜라.")
	game.hud.work_panel()


## Pickaxes ring once a minute while anyone is digging (wakes the frozen ones).
func _dig_noise(delta: float) -> void:
	if not work_started:
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
	if key != "manhole":
		if p == game.player:
			game.hud.toast("암거는 막을 수 없다.")
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
			game.hud.toast("뚜껑을 누를 무거운 것(판자나 고철)이 있어야 한다.")
		return
	game.make_sound(p.position, SimNoise.Level.NORMAL, "lid", p)
	p.start_action("lid", "뚜껑 막기", BLOCK_LID_TIME, _lid_blocked.bind(p, key, mat))


func _lid_blocked(p, key: String, mat: String) -> void:
	if not p.take_item(mat):
		return
	game.director.block(key)
	game.view.update_manhole(key, true)
	game.receipt.place_note("manholeBlocked", true)
	game.hud.toast("맨홀을 막았다. 그 몫은 암거로 나온다.")


# ---------------------------------------------------------------- treatment, crafting

## A medic (or anyone) treats another person: kit for heavy bleeding, bandages
## otherwise; a medic within 2 min of the wound eases it one more step.
func treat(medic, o) -> void:
	if medic.action != "" or o.body.bleed <= 0:
		return
	var src = medic if (medic.items.has("medkit") or medic.items.has("bandage")) else o
	var heavy: bool = o.body.bleed >= 2
	var t := 6.0 if medic.medical == "none" else 4.0
	medic.face_point(o.position)
	medic.start_action("treat", "치료", t, _treated.bind(medic, o, src, heavy))


func _treated(medic, o, src, heavy: bool) -> void:
	if heavy and src.take_item("medkit"):
		o.body.use_kit()
	elif heavy and int(src.items.get("bandage", 0)) >= 2:
		src.take_item("bandage", 2)
		o.body.bandage(2)
		if medic.medical != "none" and o.body.quick_treat_ok(game.clock.elapsed):
			o.body.bandage(1)
	elif src.take_item("bandage"):
		o.body.bandage(1)
	else:
		game.say(medic, "붕대가 없다.")
		return
	game.say(medic, "%s → %s 치료했다." % [medic.display_name, o.display_name])


func self_bandage(p) -> void:
	if p.body.bleed <= 0:
		game.hud.toast("피가 나지 않는다.")
		return
	treat(p, p)


func splint(p) -> void:
	if not (p.body.arm_fracture or p.body.leg_fracture) or p.body.splinted:
		game.hud.toast("부목을 댈 데가 없다.")
		return
	if int(p.items.get("plank", 0)) <= 0 and int(p.items.get("wood", 0)) <= 0:
		game.hud.toast("판자가 있어야 부목을 댄다.")
		return
	p.start_action("splint", "부목", 10.0, _splinted.bind(p))


func _splinted(p) -> void:
	if p.take_item("plank") or p.take_item("wood"):
		p.body.splint()


func tear_bandage(p) -> void:
	if int(p.items.get("cloth", 0)) <= 0:
		game.hud.toast("천이 없다.")
		return
	p.start_action("craft", "붕대 만들기", 5.0, _torn.bind(p))


func _torn(p) -> void:
	if p.take_item("cloth"):
		p.add_item("bandage", 2)


func rub_snow(p) -> void:
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
	for key in game.data["manholes"]:
		if key == "manhole" and game.director.is_open(key) and p.position.distance_to(FieldGrid.center(game.data["manholes"][key])) < 2.5:
			out.append({"label": "맨홀 막기", "call": block_lid.bind(p, key)})
	if on_signal_top(p):
		out.append({"label": "내려가기", "call": ladder.bind(p, "fast")})
	for o in game.allies_alive():
		if o != p and o.body.bleed > 0 and o.position.distance_to(p.position) < 1.8:
			out.append({"label": "%s 치료" % o.display_name, "call": treat.bind(p, o)})
			break
	if on_platform(p):
		out.append({"label": "출발", "call": game.hud.depart_card})
	return out


const NEAR_USE: float = 1.7


## The situation pad (field_unified 10): what is within a step of the player
## on their floor, closest first, at most two (stairs, a box, a door, a
## window, something on the ground).
func _near_things(p) -> Array:
	var rows: Array = []
	var lv: int = game.level_of(p.position)
	for s in game.stairs:
		if s["ladder"] or not (s["low"] == lv or s["high"] == lv):
			continue
		var at: Vector3 = game.lift(s["cell"], lv)
		var d: float = at.distance_to(p.position)
		if d < NEAR_USE:
			var up: bool = s["low"] == lv
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
			rows.append([d, "줍기", go_and_do.bind(p, "item", i, g["pos"])])
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
			if d < NEAR_USE + 0.5 and spot["kind"] in ["ladder", "water_tower", "salvage"]:
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
	return game.data["platform"].grow(1).has_point(FieldGrid.cell_of(p.position))


## Anything put down on the platform counts as loaded (s2_station 2.4).
func _auto_unload() -> void:
	var rect: Rect2i = game.data["unload"]
	for p in game.squad:
		if not p.is_alive() or not rect.grow(1).has_point(FieldGrid.cell_of(p.position)):
			continue
		var put: Array = []
		for id in p.items.keys():
			if UNLOAD_KEEP.has(id) or W.is_known(id):
				continue
			var n: int = int(p.items[id])
			game.unloaded[id] = int(game.unloaded.get(id, 0)) + n
			put.append("%s %d" % [game.item_name(id), n])
			p.items.erase(id)
		if not put.is_empty():
			game.say(p, "%s 실었다: %s" % [p.display_name, ", ".join(put)])
