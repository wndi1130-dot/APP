extends RefCounted
## People who are not the player: three companions, the work crew and the
## raiders in the pharmacy (field_unified 9·11, s2_station 2.4·2.5).
## Raiders only know what they saw or heard: last position, never the truth.

const FieldGrid = preload("res://game/world/field_grid.gd")
const W = preload("res://game/sim/weapons.gd")
const SimNoise = preload("res://game/sim/noise.gd")

const FOLLOW_OFFSETS: Array = [Vector2(-1.3, -1.2), Vector2(1.3, -1.2), Vector2(0.0, -2.4)]
const THINK: float = 0.25
const REACT_MIN: float = 0.4
const REACT_MAX: float = 0.8
const THREAT_R: float = 3.0
const COVER_R: float = 11.0
const RAIDER_SIGHT: float = 22.0
const NOTICE_TIME: float = 1.5
const SOUTH_EXIT := Vector2i(60, 99)
const DIG_TIME: float = 45.0
const TRIP_COAL: float = 0.25

var game
var think_t: float = 0.0
var fled: int = 0
var surrendered = null
var crew_attitude: String = "defensive"     # aggressive | defensive | neutral
var crew_fire: String = "threat"            # free | threat | melee
var crew_recalled: bool = false


func _init(field_game) -> void:
	game = field_game


func update(delta: float) -> void:
	for p in game.people_alive():
		if p == game.player:
			continue
		_grab_reflex(p, delta)
	think_t -= delta
	var think := think_t <= 0.0
	if think:
		think_t = THINK
	for p in game.squad:
		if p != game.player and p.is_alive() and p.can_act():
			if think:
				_companion(p)
	for p in game.crew:
		if p.is_alive() and p.can_act() and not p.brain.get("boarded", false):
			_crew(p, delta, think)
	for r in game.raiders:
		if r.is_alive() and not r.body.downed:
			_raider(r, delta, think)


# ---------------------------------------------------------------- shared

## A grabbed companion shoves back after a human reaction time; if that is
## longer than the window, the bite lands first (body_injury 2).
func _grab_reflex(p, delta: float) -> void:
	if p.grabbers.is_empty():
		p.brain.erase("react_t")
		return
	if not p.brain.has("react_t"):
		p.brain["react_t"] = game.rng.randf_range(REACT_MIN, REACT_MAX) * (0.8 if p.team == "squad" else 1.0)
	p.brain["react_t"] = float(p.brain["react_t"]) - delta
	if p.brain["react_t"] <= 0.0:
		p.brain.erase("react_t")
		game.combat.break_grab(p)


func _threat_near(p, r: float) -> Dictionary:
	var best: Dictionary = {}
	var best_d := r
	for z in game.zombies.in_radius(p.position, r):
		if not game.zombies.active(z) or z["state"] == "downed":
			continue
		var d: float = p.position.distance_to(z["pos"])
		if d < best_d and game.sight_clear(p.position, z["pos"]):
			best_d = d
			best = z
	return best


func _hostile_raider_near(p, r: float):
	for o in game.raiders:
		if not o.is_alive() or o.body.downed or o.brain.get("state", "") in ["surrender", "flee", "prisoner", "gone"]:
			continue
		if not o.brain.get("aware_of_us", false):
			continue
		if p.position.distance_to(o.position) <= r and game.sight_clear(p.position, o.position):
			return o
	return null


func _walk(p, to: Vector3, run: bool = false) -> void:
	if p.brain.get("dest", Vector3.INF).distance_to(to) < 0.6 and not p.path.is_empty():
		return
	p.brain["dest"] = to
	p.go_to(game.find_path(p.position, to, false), run)


## Use the melee slot for close work; keep the gun for when shooting is allowed.
func _prefer(p, ranged: bool) -> void:
	if p.hands.size() < 2 or p.action != "":
		return
	if W.is_ranged(p.weapon_id()) == ranged:
		return
	if W.is_ranged(p.hands[1]["id"]) == ranged:
		game.combat.swap(p)


func _shoot_or_aim(p, at: Vector3, target) -> void:
	if not game.combat.can_shoot(p):
		if W.is_ranged(p.weapon_id()) and int(p.weapon()["loaded"]) <= 0:
			game.combat.start_reload(p)
		return
	if not p.aim.active:
		game.combat.start_aim(p)
		p.brain["aim_wait"] = 0.6 + 0.04 * p.position.distance_to(at)
		return
	p.face_point(at)
	p.brain["aim_wait"] = float(p.brain.get("aim_wait", 0.0)) - THINK
	if p.brain["aim_wait"] <= 0.0 or p.aim.deg <= p.aim.floor_deg * 1.05:
		game.combat.fire(p, at, target)


func _treat_self(p) -> bool:
	if p.body.bleed <= 0 or p.action != "":
		return false
	if p.items.has("medkit") and p.body.bleed >= 2:
		p.start_action("treat", "치료", 8.0, _use_kit.bind(p, p))
		return true
	var need := 2 if p.body.bleed >= 2 else 1
	if int(p.items.get("bandage", 0)) >= need:
		p.start_action("treat", "붕대", 6.0, _use_bandage.bind(p, p, need))
		return true
	return false


func _use_kit(giver, who) -> void:
	if giver.take_item("medkit"):
		who.body.use_kit()


func _use_bandage(giver, who, n: int) -> void:
	if giver.take_item("bandage", n):
		who.body.bandage(n)


# ---------------------------------------------------------------- companions

func _companion(p) -> void:
	var player = game.player
	var threat := _threat_near(p, THREAT_R)
	var raider = _hostile_raider_near(p, 20.0)
	# Self-care first when nothing is close.
	if threat.is_empty() and raider == null and p.action == "" and _treat_self(p):
		return
	# The medic patches up a bleeding ally nearby.
	if p.medical != "none" and threat.is_empty() and raider == null and p.action == "":
		for o in game.allies_alive():
			if o != p and o.body.bleed > 0 and o.position.distance_to(p.position) < 15.0 and o.grabbers.is_empty():
				if o.position.distance_to(p.position) > 1.4:
					_walk(p, o.position, o.body.bleed >= 2)
				else:
					game.actions.treat(p, o)
				return
	if p.action != "":
		return
	match p.command:
		"retreat":
			var door := FieldGrid.center(game.data["spawns"]["train_door"][0])
			if p.position.distance_to(door) > 1.5:
				_walk(p, door, true)
			else:
				p.brain["boarded"] = true
				p.stop()
			if not threat.is_empty() and threat["pos"].distance_to(p.position) < 1.3:
				game.combat.shove(p)
			return
		"search":
			if threat.is_empty() and raider == null:
				if _search_near(p, p.command_target):
					return
				p.command = "wait"
	# Raiders aware of us: shoot back if there is a gun, else stay near the player.
	if raider != null and p.command != "retreat":
		_prefer(p, true)
		if W.is_ranged(p.weapon_id()):
			_shoot_or_aim(p, raider.position, raider)
			return
	if not threat.is_empty():
		var cover: bool = p.command == "cover"
		if cover and threat["pos"].distance_to(p.position) > 2.0:
			_prefer(p, true)
			if W.is_ranged(p.weapon_id()):
				_shoot_or_aim(p, threat["pos"], threat)
				return
		_prefer(p, false)
		game.combat.melee_target(p, threat, true)
		return
	if p.command == "cover":
		# Shoot the dead going for the player within cover range.
		for z in game.zombies.in_radius(player.position, COVER_R):
			if game.zombies.active(z) and (z["state"] == "chase" or z["state"] == "attack") and z["victim"] == player:
				_prefer(p, true)
				if W.is_ranged(p.weapon_id()):
					_shoot_or_aim(p, z["pos"], z)
				return
	if p.aim.active:
		p.aim.stop()
	p.target_zombie = {}
	match p.command:
		"follow", "cover":
			var idx: int = game.squad.find(p) - 1
			var off: Vector2 = FOLLOW_OFFSETS[clampi(idx, 0, 2)]
			var fwd := Vector3(sin(player.facing), 0, cos(player.facing))
			var right := Vector3(fwd.z, 0, -fwd.x)
			var spot: Vector3 = player.position + right * off.x + fwd * off.y
			spot = game.walkable_near(spot, false, 3)
			p.crouched = player.crouched
			var d: float = p.position.distance_to(spot)
			if d > 1.2:
				_walk(p, spot, player.running or d > 7.0)
			elif p.path.is_empty():
				p.face_point(p.position + fwd)
		"wait":
			if p.position.distance_to(p.command_target) > 1.0:
				_walk(p, p.command_target, false)


## Walk to and search the nearest unsearched container near `around`.
func _search_near(p, around: Vector3) -> bool:
	var best = null
	var best_d := 9.0
	for id in game.data["containers"]:
		var c: Dictionary = game.data["containers"][id]
		if c["searched"] or c["locked"] or c.get("busy", false):
			continue
		var d: float = FieldGrid.center(c["cell"]).distance_to(around)
		if d < best_d:
			best_d = d
			best = c
	if best == null:
		return false
	var at := FieldGrid.center(best["cell"])
	if p.position.distance_to(at) > 1.3:
		_walk(p, at, false)
	else:
		game.actions.search(p, best["id"])
	return true


# ---------------------------------------------------------------- work crew

func _crew(p, delta: float, think: bool) -> void:
	if crew_recalled or p.brain.get("job", "") == "home":
		var door := FieldGrid.center(game.data["spawns"]["train_door"][1])
		if p.position.distance_to(door) > 1.5:
			if think:
				_walk(p, door, true)
		else:
			p.brain["boarded"] = true
			p.visible = false
			p.position = door + Vector3(0, -50, 0)
		return
	if p.role == "escort":
		if think:
			_escort(p)
		return
	if not think:
		return
	var threat := _threat_near(p, 6.0)
	if not threat.is_empty():
		# Carriers run for the platform and wait there until it is clear.
		p.cancel_action()
		p.brain["fleeing"] = true
		if threat["pos"].distance_to(p.position) < 1.2:
			game.combat.shove(p)
		_walk(p, FieldGrid.center(Vector2i(int(p.position.x), 8)), true)
		return
	p.brain["fleeing"] = false
	if p.action != "":
		return
	var job: String = p.brain.get("job", "dig")
	if job == "dig":
		var wagon: Dictionary = _wagon_with_coal()
		if wagon.is_empty():
			p.brain["job"] = "home"
			return
		var at := FieldGrid.center(wagon["work"]) + Vector3(game.rng.randf_range(-1.5, 1.5), 0, 0.2)
		if p.position.distance_to(FieldGrid.center(wagon["work"])) > 2.2:
			_walk(p, at, false)
			return
		p.start_action("dig", "곡괭이질", DIG_TIME, _dug.bind(p))
		return
	if job == "carry":
		var drop := FieldGrid.center(Vector2i(clampi(int(p.position.x), 17, 96), 6))
		if p.position.distance_to(drop) > 1.0:
			_walk(p, drop, false)
			return
		game.actions.coal_delivered += float(p.brain.get("load", 0.0))
		p.brain["load"] = 0.0
		p.brain["job"] = "dig"


func _dug(p) -> void:
	var w: Dictionary = _wagon_with_coal()
	if w.is_empty():
		return
	var take := minf(TRIP_COAL, float(w["coal"]))
	w["coal"] = float(w["coal"]) - take
	p.brain["load"] = take
	p.brain["job"] = "carry"


func _wagon_with_coal() -> Dictionary:
	for w in game.data["wagons"]:
		if w.has("work") and float(w["coal"]) > 0.001:
			return w
	return {}


## Escorts guard the carriers. Attitude says how far they go out; fire
## permission says whether they may shoot (s2_station 2.4).
func _escort(p) -> void:
	var site: Vector3 = FieldGrid.center(game.data["spots"]["work_site"]["cell"])
	var reach: float = {"aggressive": 12.0, "defensive": 6.0, "neutral": 2.0}.get(crew_attitude, 6.0)
	var threat: Dictionary = {}
	var best := 999.0
	for z in game.zombies.in_radius(site, reach + 6.0):
		if not game.zombies.active(z) or z["state"] == "downed":
			continue
		var near_worker := 999.0
		for w in game.crew:
			if w.is_alive() and w.role == "worker":
				near_worker = minf(near_worker, w.position.distance_to(z["pos"]))
		var d: float = minf(p.position.distance_to(z["pos"]), near_worker)
		var attacking: bool = z["state"] == "attack" or z["state"] == "grab"
		if crew_attitude == "neutral" and not attacking and p.position.distance_to(z["pos"]) > 2.0:
			continue
		if d < reach and d < best:
			best = d
			threat = z
	if threat.is_empty():
		if p.aim.active:
			p.aim.stop()
		p.target_zombie = {}
		var post: Vector3 = site + Vector3(-4.0 if p.brain.get("side", 0) == 0 else 4.0, 0, 1.5)
		if p.position.distance_to(post) > 1.5:
			_walk(p, post, false)
		return
	var dist: float = p.position.distance_to(threat["pos"])
	var may_shoot: bool = crew_fire == "free" or (crew_fire == "threat" and best < 5.0)
	if may_shoot and dist > 2.0:
		_prefer(p, true)
		if W.is_ranged(p.weapon_id()):
			_shoot_or_aim(p, threat["pos"], threat)
			return
	_prefer(p, false)
	game.combat.melee_target(p, threat, true)


# ---------------------------------------------------------------- raiders

func _raider(r, delta: float, think: bool) -> void:
	var b: Dictionary = r.brain
	var state: String = b.get("state", "idle")
	if state in ["surrender", "prisoner", "gone"]:
		if state == "prisoner" and think:
			_follow_as_prisoner(r)
		return
	if state == "flee":
		if think:
			var exit := FieldGrid.center(SOUTH_EXIT)
			if r.position.distance_to(exit) < 2.0:
				b["state"] = "gone"
				fled += 1
				r.visible = false
				r.position.y = -50.0
				r.body.dead = true
				game.receipt.place_note("raidersFled", fled)
			else:
				_walk(r, exit, true)
		return
	if not think:
		return
	_raider_perceive(r)
	_raider_morale(r)
	if b["state"] in ["flee", "surrender"]:
		return
	var target = b.get("target")
	var sees: bool = target != null and target.is_alive() and _raider_sees(r, target)
	if sees:
		b["last_seen"] = target.position
		b["lost_t"] = 0.0
	match b["state"]:
		"idle":
			if r.position.distance_to(b["home"]) > 1.0:
				_walk(r, b["home"], false)
		"alert":
			# Heard something: the shooter holds, the others go and look.
			if b["role"] == "shooter":
				r.face_point(b["last_seen"])
			elif r.position.distance_to(b["last_seen"]) > 2.0:
				_walk(r, b["last_seen"], false)
			else:
				b["state"] = "search"
				b["search_t"] = 20.0
		"search":
			b["search_t"] = float(b.get("search_t", 20.0)) - THINK
			if b["search_t"] <= 0.0:
				b["state"] = "idle"
			elif r.path.is_empty():
				var off := Vector3(game.rng.randf_range(-5, 5), 0, game.rng.randf_range(-5, 5))
				_walk(r, b["last_seen"] + off, false)
		"fight":
			b["fight_t"] = float(b.get("fight_t", 0.0)) + THINK
			if not sees:
				b["lost_t"] = float(b.get("lost_t", 0.0)) + THINK
				if r.aim.active:
					r.aim.stop()
				b["aiming"] = false
				if b["lost_t"] > 6.0:
					b["state"] = "search"
					b["search_t"] = 20.0
					return
			_raider_fight(r, target, sees)


func _raider_sees(r, p) -> bool:
	var d: float = r.position.distance_to(p.position)
	var sight: float = RAIDER_SIGHT * float(game.weather.sight_mult(game.clock.is_dark()))
	if p.crouched:
		sight *= 0.6
	if d > sight:
		return false
	return game.sight_clear(r.position, p.position)


## A person has to stay in view 1-2 s before a raider notices (field_unified 11).
func _raider_perceive(r) -> void:
	var b: Dictionary = r.brain
	var best = null
	var best_d := 999.0
	for p in game.allies_alive():
		if p.brain.get("boarded", false):
			continue
		if _raider_sees(r, p):
			var d: float = r.position.distance_to(p.position)
			if d < best_d:
				best_d = d
				best = p
	if best == null:
		b["aware"] = maxf(0.0, float(b.get("aware", 0.0)) - THINK * 0.3)
		return
	var rate: float = THINK / NOTICE_TIME * (2.0 if best_d < 6.0 else 1.0)
	b["aware"] = minf(1.0, float(b.get("aware", 0.0)) + rate)
	if b["aware"] >= 1.0:
		if b["state"] != "fight":
			_alert_all(best, r)
		b["target"] = best


## One raider seeing us tells the others: they share the last position.
func _alert_all(target, spotter) -> void:
	for o in game.raiders:
		if not o.is_alive() or o.brain.get("state", "") in ["flee", "surrender", "prisoner", "gone"]:
			continue
		o.brain["state"] = "fight"
		o.brain["aware_of_us"] = true
		o.brain["target"] = target
		o.brain["last_seen"] = target.position
	if not game.auto_paused_once and game.opts.get("auto_pause", true):
		game.auto_paused_once = true
		game.paused = true
		game.hud.toast("약탈자가 겨눈다. 멈췄다. 명령을 고르고 계속을 누른다.")
	game.receipt.place_note("raiders", "fought")


func _raider_fight(r, target, sees: bool) -> void:
	var b: Dictionary = r.brain
	if target == null or not target.is_alive():
		b["state"] = "search"
		b["search_t"] = 10.0
		return
	var at: Vector3 = target.position if sees else b["last_seen"]
	var d: float = r.position.distance_to(at)
	match b["role"]:
		"shooter":
			# Holds inside the pharmacy, shoots through the door and windows.
			if sees and d < float(W.get_data(r.weapon_id()).get("range", 12.0)) + 4.0:
				b["aiming"] = true
				_shoot_or_aim(r, at, target)
			else:
				b["aiming"] = false
				if r.position.distance_to(b["home"]) > 1.0:
					_walk(r, b["home"], false)
		"advancer":
			# Moves up from cover to cover, shoots when it has a line.
			if sees and d < 14.0:
				r.stop()
				b["aiming"] = true
				_shoot_or_aim(r, at, target)
			else:
				b["aiming"] = false
				_walk(r, _cover_near(at, r.position), false)
		"flanker":
			# Goes round the side and closes in with the axe: it names a target only
			# within the blow's reach and with nothing in the way, else it walks on.
			if sees and d <= game.combat.melee_range(r) and not game.combat.melee_blocked(r, target.position):
				game.combat.melee_person(r, target)
			else:
				var side := Vector3(-(at - r.position).z, 0, (at - r.position).x).normalized() * 5.0
				var goal: Vector3 = at + side if d > 8.0 else at
				_walk(r, goal, d < 10.0)


## A walkable cell next to low cover between me and them, or just closer.
func _cover_near(at: Vector3, from: Vector3) -> Vector3:
	var best := from.lerp(at, 0.35)
	var best_score := 999.0
	for rect in game.data["low_blocks"]:
		var center := Vector3(rect.position.x + rect.size.x * 0.5, 0, rect.position.y + rect.size.y * 0.5)
		var dist_t: float = center.distance_to(at)
		if dist_t < 5.0 or dist_t > 16.0:
			continue
		var score: float = center.distance_to(from) + dist_t * 0.5
		if score < best_score:
			best_score = score
			var side: Vector3 = (center - at).normalized() * (maxf(rect.size.x, rect.size.y) * 0.5 + 1.0)
			best = center + side
	var c: Vector2i = game.grid.nearest_walkable(FieldGrid.cell_of(best), false, 3)
	return FieldGrid.center(c)


## Morale (field_unified 11): fear from both sides, hurt friends, ammo, pain,
## the way out. It breaks into running away, or into giving up.
func _raider_morale(r) -> void:
	var b: Dictionary = r.brain
	if b["state"] != "fight":
		return
	var m: float = float(b.get("morale", 1.0))
	var dead_near: int = game.zombies.in_radius(r.position, 6.0).size()
	if dead_near >= 3:
		m -= 0.02
	if float(b.get("fight_t", 0.0)) > 90.0 and not b.get("long_fight", false):
		b["long_fight"] = true
		m -= 0.15
	if W.is_ranged(r.weapon_id()) and int(r.weapon()["loaded"]) <= 0 and int(b.get("ammo", 6)) <= 0:
		m -= 0.01
	b["morale"] = m
	var friends := 0
	for o in game.raiders:
		if o != r and o.is_alive() and not o.body.downed and o.brain.get("state", "") == "fight":
			friends += 1
	if m < 0.45 and r.body.bleed > 0 or m < 0.3 and friends == 0:
		_surrender(r)
	elif m < 0.3:
		b["state"] = "flee"
		b["aiming"] = false
		r.aim.stop()
		game.say(r, "약탈자 하나가 남쪽 길로 달아난다.")


func _surrender(r) -> void:
	var b: Dictionary = r.brain
	b["state"] = "surrender"
	b["aiming"] = false
	r.aim.stop()
	r.stop()
	r.target_person = null
	# Whoever was hitting this raider stops: the card decides what happens next.
	for q in game.people_alive():
		if q.target_person == r:
			q.target_person = null
			q.hold_attack = false
	if not r.hands.is_empty():
		var h: Dictionary = r.hands[0]
		game.ground_items.append({"pos": r.position + Vector3(0.6, 0, 0), "id": h["id"], "n": 1, "weapon": h.duplicate()})
	r.set_weapon_slots([])
	surrendered = r
	game.hud.card("surrender", "약탈자가 무기를 내려놓고 손을 든다.", [
		{"id": "take", "label": "묶어서 데려간다", "say": "\"손 뒤로. 열차까지 걷는다.\""},
		{"id": "disarm", "label": "무기만 뺏고 보낸다", "say": "\"가라. 다시 보이면 그땐 없다.\""},
		{"id": "shoot", "label": "쏜다", "say": "\"약을 훔친 값이다.\""},
	], Callable(self, "_on_surrender_choice").bind(r))


func _on_surrender_choice(choice: String, r) -> void:
	game.decisions.append({"id": "raider_surrender", "choice": choice})
	match choice:
		"take":
			r.brain["state"] = "prisoner"
			r.team = "survivor"
			game.receipt.place_note("prisoners", 1)
		"disarm":
			r.brain["state"] = "flee"
		"shoot":
			game.make_sound(r.position, SimNoise.Level.LOUD, "gun", game.player)
			var seen: Array = []
			for o in game.allies_alive():
				if o.position.distance_to(r.position) < 15.0:
					seen.append(o.pid)
			game.receipt.witness(game.player.pid, "shot_surrendered_raider", "station_street", game.clock.label(), "raider_surrendered", seen)
			game.on_person_died(r)


func _follow_as_prisoner(r) -> void:
	var p = game.player
	if r.position.distance_to(p.position) > 2.5:
		_walk(r, p.position - Vector3(sin(p.facing), 0, cos(p.facing)) * 1.8, false)
	if game.data["platform"].grow(1).has_point(FieldGrid.cell_of(r.position)):
		r.brain["boarded"] = true


## Raiders hear loud sounds like the dead do (8.2): they turn to the spot.
func raiders_hear(at: Vector3, radius: float, from) -> void:
	for r in game.raiders:
		if r == from or not r.is_alive() or r.body.downed:
			continue
		var b: Dictionary = r.brain
		if b.get("state", "") in ["flee", "surrender", "prisoner", "gone"]:
			continue
		if r.position.distance_to(at) > radius:
			continue
		if from != null and from.team == "raider":
			continue
		# They know gunfire calls the dead too.
		b["morale"] = float(b.get("morale", 1.0)) - 0.03
		if b.get("state", "idle") != "fight":
			b["state"] = "alert"
			b["last_seen"] = at


func raider_hit(r, by) -> void:
	var b: Dictionary = r.brain
	b["morale"] = float(b.get("morale", 1.0)) - 0.25
	b["hit_by"] = by.pid if by != null else ""
	if b.get("state", "") in ["idle", "alert", "search"] and by != null:
		b["state"] = "fight"
		b["aware_of_us"] = true
		b["target"] = by
		b["last_seen"] = by.position
		_alert_all(by, r)


func raider_downed(r) -> void:
	r.brain["aiming"] = false
	for o in game.raiders:
		if o != r and o.is_alive():
			o.brain["morale"] = float(o.brain.get("morale", 1.0)) - 0.35
