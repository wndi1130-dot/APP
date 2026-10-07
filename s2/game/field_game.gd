extends Node3D
## One direct stop at Sulechów (S2 graybox, s2_station.md). Owns the map,
## people, the dead, clocks and the receipt. Combat, AI, input and HUD live in
## helper scripts that read and write this node.

signal finished(result: Dictionary)
signal restart_requested

const FieldGrid = preload("res://game/world/field_grid.gd")
const SulehufMap = preload("res://game/world/sulehuf_map.gd")
const MapView = preload("res://game/world/map_view.gd")
const Person = preload("res://game/actors/person.gd")
const Zombies = preload("res://game/actors/zombies.gd")
const FieldClock = preload("res://game/sim/field_clock.gd")
const SimNoise = preload("res://game/sim/noise.gd")
const NoiseLedger = preload("res://game/sim/noise_ledger.gd")
const HordeDirector = preload("res://game/sim/horde_director.gd")
const Receipt = preload("res://game/sim/receipt.gd")
const Telemetry = preload("res://game/sim/telemetry.gd")
const Carry = preload("res://game/sim/carry.gd")
const Weather = preload("res://game/sim/weather.gd")
const W = preload("res://game/sim/weapons.gd")
const Combat = preload("res://game/field_combat.gd")
const AI = preload("res://game/field_ai.gd")
const Actions = preload("res://game/field_actions.gd")
const Hud = preload("res://game/ui/field_hud.gd")
const VatBaker = preload("res://scripts/vat_baker.gd")

const AMBIENT_C: float = -14.0
const SIGHT_RADIUS: int = 18
const SIGHT_UPSTAIRS: int = 30
const NEAR_SIGHT: float = 2.6
const VIEW_CONE_COS: float = 0.17       # about 160 degrees ahead (zomboid-like)
const ALLY_CAP: int = 12
const CAM_PITCH: float = 52.0
const EXTRA_ITEMS: Dictionary = {
	"info_telegraph": {"name": "전신 기록", "weight": 0.5, "stock": "info"},
	"info_timetable": {"name": "시간표", "weight": 0.5, "stock": "info"},
	"flare": {"name": "철도 섬광", "weight": 0.5, "stock": ""},
	"ammo_pistol": {"name": "권총탄 한 줌", "weight": 0.0, "stock": ""},
	"ammo_shell": {"name": "산탄 한 줌", "weight": 0.0, "stock": ""},
}
const STOCK_OF: Dictionary = {"food_pack": ["food", 0.5], "med_box": ["medicine", 0.5], "luxury_pack": ["luxury", 0.5], "symbol_bell": ["symbol", 1.0], "info_telegraph": ["info", 1.0], "info_timetable": ["info", 1.0], "medkit": ["medicine", 1.0], "document": ["info", 0.0]}

var opts: Dictionary = {}
var rng := RandomNumberGenerator.new()
var data: Dictionary
var grid: FieldGrid
var view: MapView
var zombies: Zombies
var camera: Camera3D
var environment: Environment
var sun: DirectionalLight3D
var snow: GPUParticles3D
var clock := FieldClock.new()
var ledger := NoiseLedger.new()
var director: HordeDirector
var receipt: Receipt
var telemetry: Telemetry
var combat: Combat
var ai: AI
var actions: Actions
var hud: Hud

var people: Array = []
var squad: Array = []
var crew: Array = []
var raiders: Array = []
var player: Person
var paused: bool = false
var ended: bool = false
var seen_now: Dictionary = {}
var seen_memory := PackedByteArray()
var vis_t: float = 0.0
var hud_t: float = 0.0
var mask_on: bool = true
var forecast_precision: int = 0
var weather: Weather
var cap: int = HordeDirector.CONCURRENT_CAP
var waiting: int = 0                   # bodies held at entries by the concurrent cap
var deaf_t: float = 0.0                # player can't hear sound cues (indoor gunfire, 8.2)
var casings: int = 0
var last_gun_t: float = -INF
var radio: String = ""
var radio_t: float = 0.0
var ammo: Dictionary = {"pistol": 8, "shell": 4, "craft": 8}
var ammo_start: Dictionary = {}
var unloaded: Dictionary = {}
var blood: Array = []
var sounds: Array = []                 # recent sounds for the HUD: {pos, level, t}
var shot_times: Array = []
var hordes: Dictionary = {}            # index -> {"t": arrival, "ids": [], "cleared": bool, "entry": key}
var pending_spawn: Array = []          # {"t", "pos", "horde", "target"}
var rattle: Dictionary = {}            # manhole key -> seconds of rattling left
var ground_items: Array = []           # {pos, id, n}
var decisions: Array = []
var cam_focus := Vector3.ZERO
var cam_push := Vector3.ZERO
var cam_size: float = 24.0
var zone_now: String = ""
var auto_paused_once: bool = false
var flash_t: float = 0.0
var dark_noise_t: float = 0.0
var safe_warned: bool = false
var ice_warned: bool = false
var glass_warned: bool = false
var player_downed_t: float = 0.0
var spotted_events: int = 0
var unseen_rattle: bool = false
var light_t: float = 0.0


func _ready() -> void:
	rng.seed = int(opts.get("seed", Time.get_ticks_usec()))
	clock.speed = float(opts.get("clock_speed", 1.0))
	weather = Weather.new(opts.get("weather", ["fog", "snow"]), AMBIENT_C, Vector2(1, 0.2), 0.4)
	cap = int(opts.get("cap", HordeDirector.CONCURRENT_CAP))
	Engine.max_fps = int(opts.get("fps_cap", 60))
	data = SulehufMap.build()
	grid = data["grid"]
	seen_memory.resize(grid.width * grid.height)
	director = HordeDirector.new(rng)
	if opts.has("budget"):
		director.budget_left = int(opts["budget"])
	receipt = Receipt.new(SulehufMap.PLACE_ID, "freight", "small_station_siding")
	receipt.set_source("direct")
	telemetry = Telemetry.new("s2-%d" % rng.seed)
	_build_world()
	view = MapView.new()
	add_child(view)
	view.setup(data)
	zombies = Zombies.new()
	add_child(zombies)
	zombies.setup(self, VatBaker.build(int(opts.get("vertices", 1500))))
	combat = Combat.new(self)
	ai = AI.new(self)
	actions = Actions.new(self)
	_spawn_people()
	_spawn_dead()
	ammo_start = ammo.duplicate()
	hud = Hud.new()
	add_child(hud)
	hud.setup(self)
	set_radio("기관사: " + director.forecast(0.0, 0, clock))
	cam_focus = player.position
	_update_camera(1.0)
	_refresh_vision()
	telemetry.zone_enter(grid.zone_at(FieldGrid.cell_of(player.position)), 0.0)


func _build_world() -> void:
	var world := WorldEnvironment.new()
	environment = Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.13, 0.135, 0.15)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.62, 0.66, 0.72)
	environment.ambient_light_energy = 0.6
	# Weather fog lives in the sight mask (weather.gd); depth fog would wash
	# the whole oblique view out, so it stays off unless asked for.
	environment.fog_enabled = bool(opts.get("fog", false))
	environment.fog_density = 0.012
	environment.fog_light_color = Color(0.7, 0.72, 0.75)
	world.environment = environment
	add_child(world)
	sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, -30, 0)
	sun.light_energy = 0.7
	sun.light_color = Color(0.86, 0.9, 0.98)
	sun.shadow_enabled = bool(opts.get("shadows", true))
	sun.directional_shadow_max_distance = 60.0
	add_child(sun)
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = cam_size
	camera.near = 0.1
	camera.far = 200.0
	add_child(camera)
	camera.current = true
	snow = GPUParticles3D.new()
	snow.amount = maxi(weather.particles(), 1)
	snow.lifetime = 4.0
	snow.visibility_aabb = AABB(Vector3(-30, -2, -20), Vector3(60, 14, 40))
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(28, 0.5, 20)
	pm.direction = Vector3(weather.wind_dir.x * weather.wind, -1, weather.wind_dir.y * weather.wind)
	pm.spread = 10.0
	pm.initial_velocity_min = 1.5
	pm.initial_velocity_max = 2.2
	pm.gravity = Vector3(0.2, -0.6, 0)
	snow.process_material = pm
	var flake := BoxMesh.new()
	flake.size = Vector3(0.05, 0.05, 0.05)
	var fm := StandardMaterial3D.new()
	fm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fm.albedo_color = Color(0.95, 0.96, 0.98)
	flake.material = fm
	snow.draw_pass_1 = flake
	snow.emitting = bool(opts.get("snow", true)) and weather.particles() > 0
	add_child(snow)


func _spawn_people() -> void:
	var loadout: Array = opts.get("squad", default_squad("crude"))
	var spots: Array = data["spawns"]["squad"]
	for i in range(loadout.size()):
		var row: Dictionary = loadout[i]
		var p := make_person(row, FieldGrid.center(spots[i % spots.size()]))
		squad.append(p)
		receipt.person("sent", p.pid)
	player = squad[0]
	if bool(opts.get("raiders", true)):
		var rows := [
			{"id": "npc_raider_1", "name": "약탈자", "role": "raider", "skills": {"strength": 5, "melee": 2, "shooting": 3, "stealth": 1, "search": 1}, "hands": [["pipe_shotgun", "crude", 1.0]], "brain": "shooter"},
			{"id": "npc_raider_2", "name": "약탈자", "role": "raider", "skills": {"strength": 5, "melee": 2, "shooting": 2, "stealth": 2, "search": 1}, "hands": [["pistol", "crude", 0.7]], "brain": "advancer"},
			{"id": "npc_raider_3", "name": "약탈자", "role": "raider", "skills": {"strength": 6, "melee": 4, "shooting": 1, "stealth": 2, "search": 1}, "hands": [["axe", "factory", 0.8]], "brain": "flanker"},
		]
		var rs: Array = data["spawns"]["raiders"]
		for i in range(rows.size()):
			var r := make_person(rows[i], FieldGrid.center(rs[i]))
			r.brain = {"role": rows[i]["brain"], "state": "idle", "aware": 0.0, "morale": 1.0, "seen_t": 0.0, "last_seen": Vector3.ZERO, "home": r.position, "aim_t": 0.0, "target": null, "fight_t": 0.0}
			r.add_item("med_box", 1)
			raiders.append(r)


func default_squad(pipe_quality: String) -> Array:
	return [
		{"id": "p_chief", "name": "열차장", "role": "chief", "skills": {"strength": 5, "melee": 3, "shooting": 2, "stealth": 2, "search": 2}, "hands": [["axe", "factory", 0.9], ["pistol", "factory", 0.8]], "items": {"bandage": 2, "cloth": 1}},
		{"id": "p_guard_marek", "name": "마레크", "role": "companion", "skills": {"strength": 6, "melee": 2, "shooting": 4, "stealth": 1, "search": 1}, "hands": [["pipe_shotgun", pipe_quality, 0.9], ["knife", "factory", 0.8]], "items": {"bandage": 1}},
		{"id": "p_med_joanna", "name": "요안나", "role": "companion", "medical": "skilled", "skills": {"strength": 4, "melee": 1, "shooting": 4, "stealth": 3, "search": 3}, "hands": [["bow", "factory", 0.9], ["crowbar", "factory", 0.9]], "items": {"bandage": 3, "medkit": 1}},
		{"id": "p_tail_tomasz", "name": "토마시", "role": "companion", "skills": {"strength": 7, "melee": 3, "shooting": 1, "stealth": 1, "search": 2}, "hands": [["crowbar", "factory", 0.8], ["knife", "factory", 0.7]], "items": {"bandage": 1}, "bag": "big_pack"},
	]


func make_person(row: Dictionary, at: Vector3) -> Person:
	var p := Person.new()
	add_child(p)
	p.setup(String(row["id"]), String(row["name"]), String(row["role"]), at)
	p.skills = row.get("skills", p.skills).duplicate()
	p.medical = String(row.get("medical", "none"))
	p.bag = String(row.get("bag", "pack"))
	var slots: Array = []
	for h in row.get("hands", []):
		var id: String = h[0]
		var mag: int = int(W.get_data(id).get("mag", 0))
		slots.append({"id": id, "quality": h[1] if h.size() > 1 else "factory", "condition": float(h[2]) if h.size() > 2 else 1.0, "loaded": mag})
	p.set_weapon_slots(slots)
	for id in row.get("items", {}):
		p.add_item(id, int(row["items"][id]))
	p.facing = PI
	people.append(p)
	return p


func _spawn_dead() -> void:
	var s: Dictionary = data["spawns"]
	for key in ["dead_street", "dead_platform", "dead_siding_end"]:
		for c in s[key]:
			zombies.spawn("dead", FieldGrid.center(c))
	for c in s["clothed_station"]:
		zombies.spawn("clothed", FieldGrid.center(c))
	for c in s["frozen_siding"]:
		zombies.spawn("frozen", FieldGrid.center(c), {"depth": rng.randf_range(0.6, 1.0)})


func people_alive() -> Array:
	var out: Array = []
	for p in people:
		if p.is_alive():
			out.append(p)
	return out


func allies_alive() -> Array:
	var out: Array = []
	for p in people:
		if p.is_alive() and p.team != "raider":
			out.append(p)
	return out


# ---------------------------------------------------------------- loop

func _process(delta: float) -> void:
	delta = minf(delta, 0.1)
	if not ended and not paused:
		_step(delta)
	_update_camera(delta)
	vis_t -= delta
	if vis_t <= 0.0:
		vis_t = 0.1
		_refresh_vision()
	zombies.render(camera, seen_now, mask_on)
	for p in people:
		p.visible = _person_visible(p)
		p.refresh_view(p.visible)
	hud.tick(delta)


func _step(delta: float) -> void:
	clock.advance(delta)
	var now := clock.elapsed
	radio_t -= delta
	for p in people:
		_update_person(p, delta)
	zombies.update(delta)
	ai.update(delta)
	combat.update(delta)
	_update_hordes(delta)
	_update_spawns(delta)
	_update_blood(delta)
	_update_night(delta)
	_update_zone(delta)
	actions.update(delta)
	_check_end()
	var keep: Array = []
	for s in sounds:
		if now - float(s["t"]) < 1.6:
			keep.append(s)
	sounds = keep


func _update_zone(delta: float) -> void:
	var z := grid.zone_at(FieldGrid.cell_of(player.position))
	if z != zone_now:
		zone_now = z
		telemetry.zone_enter(z, clock.elapsed)
	telemetry.zone_tick(z, delta)
	var looted := false
	for id in player.items:
		if STOCK_OF.has(id):
			looted = true
	if looted and player.moving:
		telemetry.carry_time(delta)
	view.cut_away(grid.building_at(FieldGrid.cell_of(player.position)) if not player.upstairs else -1)


# ---------------------------------------------------------------- people

func _update_person(p: Person, delta: float) -> void:
	if not p.is_alive():
		return
	var cell := FieldGrid.cell_of(p.position)
	var indoor := grid.indoor(cell)
	var stove := near_stove(p.position)
	var ctx := {"running": p.is_running_now(), "swinging": p.swing_t > 0.0, "carry_state": p.carry_state(), "cold_level": p.cold_level(), "indoor_rest": indoor and not p.moving}
	for ev in p.body.tick(delta, ctx):
		_on_body_event(p, ev)
	p.heat.tick(delta, {"ambient_c": AMBIENT_C, "indoor": indoor and not building_open(grid.building_at(cell)), "stove": stove, "warmth": float(p.coat["warmth"]) + (0.1 if p.gloves else 0.0), "windproof": float(p.coat["windproof"]), "moving": p.moving, "wind": 0.0 if indoor else weather.wind})
	if weather.always_cold() and not indoor and not stove:
		p.heat.heat = minf(p.heat.heat, 60.0)
	p.panic = maxf(0.0, p.panic - delta * 0.08)
	if not p.grabbers.is_empty():
		p.grab_left -= delta
		if p.grab_left <= 0.0:
			combat.bite(p)
		return
	if p.fallen_t > 0.0:
		p.fallen_t -= delta
		return
	if p.body.downed:
		return
	if p.action != "":
		p.action_t -= delta * float(p.mults()["hands"]) if p.action != "climb" else delta
		if p.action_t <= 0.0:
			var done := p.action_done
			p.cancel_action()
			if done.is_valid():
				done.call()
		return
	_move_person(p, delta)


func _move_person(p: Person, delta: float) -> void:
	if p.path.is_empty():
		p.moving = false
		return
	var next := p.path[0]
	var d := next - p.position
	d.y = 0
	if d.length() < 0.12:
		p.path.remove_at(0)
		if p.path.is_empty():
			p.moving = false
		return
	var cell := FieldGrid.cell_of(p.position)
	var spd := p.speed(grid.floor_at(cell))
	if spd <= 0.0:
		p.moving = false
		if p == player:
			hud.toast("너무 무겁다. 짐을 덜어야 움직인다.")
			p.stop()
		return
	var step := d.normalized() * minf(spd * delta, d.length())
	var dest := p.position + step
	var dc := FieldGrid.cell_of(dest)
	if grid.doors.has(dc) and grid.doors[dc]["state"] == "closed":
		actions.open_door_on_way(p, dc)
		return
	if grid.blocks_body(dc):
		dest = _slide(p.position, step)
	if grid.windows.has(dc) and grid.windows[dc]["broken"] and not p.brain.get("vaulted_" + str(dc), false):
		actions.vault_window(p, dc)
	p.facing = atan2(step.x, step.z)
	p.position = dest
	p.moving = true
	_footsteps(p, delta, dc)


func _slide(at: Vector3, step: Vector3) -> Vector3:
	var r := at
	var cand := r + Vector3(step.x, 0, 0)
	if not grid.blocks_body(FieldGrid.cell_of(cand)):
		r.x = cand.x
	cand = r + Vector3(0, 0, step.z)
	if not grid.blocks_body(FieldGrid.cell_of(cand)):
		r.z = cand.z
	return r


func _footsteps(p: Person, delta: float, cell: Vector2i) -> void:
	var running := p.is_running_now()
	var floor_kind := grid.floor_at(cell)
	p.brain["step_t"] = float(p.brain.get("step_t", 0.0)) - delta
	if p.brain["step_t"] <= 0.0:
		p.brain["step_t"] = 0.5
		var glass: bool = grid.windows.has(cell) and grid.windows[cell]["glass"]
		var trait_mult := 1.0
		var r := SimNoise.footstep_radius(running, FieldGrid.FLOOR_SOUND[floor_kind], trait_mult, p.crouched, int(p.skills["stealth"]), glass) * weather.sound_mult(true)
		zombies.hear(p.position, SimNoise.footstep_level(running, glass), r)
		_wake_frozen_near(p)
	if running:
		p.brain["run_score_t"] = float(p.brain.get("run_score_t", 0.0)) + delta
		if p.brain["run_score_t"] >= 5.0:
			p.brain["run_score_t"] = 0.0
			_score(SimNoise.Level.NORMAL, "run")
		# Ice: running on ice can throw you down (body_injury 3.2).
		if floor_kind == FieldGrid.Floor.ICE:
			p.ice_t += delta
			if p.ice_t >= 3.0:
				p.ice_t = 0.0
				if rng.randf() < 0.1:
					combat.fall(p, "얼음에 미끄러졌다")
			if p == player and not ice_warned:
				ice_warned = true
				hud.toast("얼음 위에선 걷는 게 좋다.")
		elif p.carry_state() >= 2 and rng.randf() < delta * 0.03:
			combat.fall(p, "짐에 눌려 넘어졌다")


## Frozen ones wake when someone walks right up to them (crouching gets closer).
func _wake_frozen_near(p: Person) -> void:
	var reach := 0.8 if p.crouched else 1.7
	for z in zombies.list:
		if z["state"] == "frozen" and z["pos"].distance_to(p.position) < reach:
			zombies.wake(z)


func near_stove(at: Vector3) -> bool:
	for s in data["stoves"]:
		if s["lit"] and FieldGrid.center(s["cell"]).distance_to(at) < 4.0:
			var b: int = s["building"]
			if b < 0 or not building_open(b):
				return true
	var tower: Dictionary = data["spots"]["water_tower"]
	if tower["state"] == "fire" and FieldGrid.center(tower["cell"]).distance_to(at) < 3.5:
		return true
	return false


## A building with a broken window no longer keeps the warmth (body_injury 3.1).
func building_open(b: int) -> bool:
	if b < 0:
		return true
	return bool(data["buildings"][b]["window_broken"])


func _on_body_event(p: Person, ev: String) -> void:
	match ev:
		"downed":
			p.cancel_action()
			p.stop()
			say(p, "%s 쓰러졌다." % p.display_name)
			telemetry.injury(clock.elapsed, p.pid, "downed")
			if p.team == "raider":
				ai.raider_downed(p)
		"died":
			on_person_died(p)
		"bleed_stopped":
			if p.team != "raider":
				say(p, "%s 피가 멎었다." % p.display_name)
		"window_closed":
			if p.body.infected and p.team != "raider":
				say(p, "%s 열이 오른다." % p.display_name)
		"exhausted_heavy":
			if p == player:
				hud.toast("숨이 차서 더는 뛰지 못한다.")


func on_person_died(p: Person) -> void:
	p.body.dead = true
	p.cancel_action()
	p.stop()
	for z in p.grabbers.duplicate():
		zombies.release(z, p.position, false)
	p.grabbers.clear()
	telemetry.injury(clock.elapsed, p.pid, "dead")
	if p.team != "raider":
		receipt.person("dead", p.pid)
		say(p, "%s 죽었다." % p.display_name)
	# Everyone is already infected: the body stands up again (zombies.md).
	var z := zombies.add_rising(p.position, p.display_name)
	p.brain["rising_id"] = z["id"]
	for item in p.items:
		ground_items.append({"pos": p.position, "id": item, "n": p.items[item]})
	p.items.clear()
	if p == player:
		_check_end()


# ---------------------------------------------------------------- sound, blood, night

## Every noise goes through here: the dead hear it, the next horde comes
## earlier, the frozen wake, raiders turn, the HUD shows it. The dead walk to
## where the sound was, not to whoever made it (body_injury 8.2).
func make_sound(at: Vector3, level: int, tag: String, from: Person = null) -> void:
	var now := clock.elapsed
	var indoor := grid.indoor(FieldGrid.cell_of(at))
	# Next to a sewer mouth the sound rings in the tunnel: one step louder,
	# and a loud one wakes that hole for the next horde (field_unified 6).
	var hole := sewer_near(at, 12.0)
	if hole != "" and sewer_near(at, 4.0) != "" and level >= SimNoise.Level.NORMAL:
		level = SimNoise.clamp_level(level + 1)
	if hole != "" and level >= SimNoise.Level.LOUD and director.call_from(hole):
		if forecast_precision > 0 or player.position.distance_to(at) < 14.0:
			set_radio("기관사: 굴 쪽이 울린다. 다음 것들은 %s에서 나온다." % HordeDirector.ENTRY_NAMES[hole])
	var radius := SimNoise.radius(level, indoor, director.call_range_mult(now)) * weather.sound_mult(false)
	zombies.hear(at, level, radius)
	_score(level, tag)
	sounds.append({"pos": at, "level": level, "t": now, "tag": tag})
	if level >= SimNoise.Level.LOUD:
		ai.raiders_hear(at, radius, from)
	if tag == "gun":
		shot_times.append(now)
		casings += 1
		last_gun_t = now
		# Indoor gunfire deafens the shooter and anyone within 2 m for 5 s.
		if indoor and from != null and (from == player or from.position.distance_to(player.position) < 2.0):
			deaf_t = 5.0


## Key of an open sewer mouth within r metres of at, or "".
func sewer_near(at: Vector3, r: float) -> String:
	for key in data["manholes"]:
		if not director.is_open(key):
			continue
		if FieldGrid.center(data["manholes"][key]).distance_to(at) <= r:
			return key
	return ""


func _score(level: int, tag: String) -> void:
	var now := clock.elapsed
	var pts := ledger.add(level, now, tag)
	if pts > 0:
		director.add_noise(pts, now)
		telemetry.noise(now, ledger.total)


## Excessive blood calls the dead (user 2026-10-07, body_injury 8.1): heavy
## bleeding not yet stopped, or clothes soaked from several close kills. It
## leaves a dark trail the dead follow, and every minute it counts as a normal
## sound at that spot, stretched downwind. Light bleeding calls nobody.
func _update_blood(delta: float) -> void:
	var now := clock.elapsed
	for p in people_alive():
		var excessive: bool = p.body.bleed >= 2 or p.blood_soaked
		if not excessive:
			p.brain["blood_noise_t"] = 60.0
			continue
		p.brain["blood_t"] = float(p.brain.get("blood_t", 0.0)) - delta
		if p.brain["blood_t"] <= 0.0:
			p.brain["blood_t"] = 1.5
			blood.append({"pos": p.position, "t": now, "s": 2})
		p.brain["blood_noise_t"] = float(p.brain.get("blood_noise_t", 60.0)) - delta
		if p.brain["blood_noise_t"] <= 0.0:
			p.brain["blood_noise_t"] = 60.0
			var radius := SimNoise.radius(SimNoise.Level.NORMAL, false, 1.0)
			zombies.hear(p.position, SimNoise.Level.NORMAL, radius, weather)
			_score(SimNoise.Level.NORMAL, "blood")
	while blood.size() > 0 and now - float(blood[0]["t"]) > 120.0:
		blood.pop_front()
	while blood.size() > 200:
		blood.pop_front()


## Freshest, closest trail point a zombie at `at` can smell (20 m, more downwind).
func strongest_scent(at: Vector3) -> Dictionary:
	var best: Dictionary = {}
	var best_score := 0.0
	var now := clock.elapsed
	for b in blood:
		var reach: float = 20.0 * weather.downwind(b["pos"], at)
		var d: float = at.distance_to(b["pos"])
		if d > reach:
			continue
		var fresh := 1.0 - (now - float(b["t"])) / 120.0
		var score := fresh * (1.0 - d / reach) + float(b["t"]) * 0.0001
		if score > best_score:
			best_score = score
			best = b
	return best


## After dusk every light-carrier counts as a normal sound each minute.
func _update_night(delta: float) -> void:
	if not clock.is_dark():
		return
	light_t -= delta
	if light_t <= 0.0:
		light_t = 60.0
		for p in squad:
			if p.is_alive():
				make_sound(p.position, SimNoise.Level.NORMAL, "light")


# ---------------------------------------------------------------- hordes

func _update_hordes(delta: float) -> void:
	var now := clock.elapsed
	# Telegraph: a sewer lid rattles 3 s before anything climbs out, and keeps
	# rattling while bodies come through (field_unified 6 '예고 있는 입장').
	var next_key := director.next_entry
	if director.seconds_to_next(now) < 3.0 and HordeDirector.is_sewer(next_key):
		rattle[next_key] = maxf(float(rattle.get(next_key, 0.0)), 0.5)
	for s in pending_spawn:
		if HordeDirector.is_sewer(s["entry"]) and float(s["t"]) - now < 3.0:
			rattle[s["entry"]] = maxf(float(rattle.get(s["entry"], 0.0)), 0.5)
	for key in rattle.keys():
		rattle[key] -= delta
		var node: MeshInstance3D = view.manhole_nodes[key]
		node.position.y = absf(sin(now * 31.0)) * 0.08 if rattle[key] > 0.0 and key == "manhole" else 0.0
		if rattle[key] <= 0.0:
			rattle.erase(key)
	var h := director.update(now)
	if not h.is_empty():
		_start_horde(h)
	for idx in hordes:
		var info: Dictionary = hordes[idx]
		if info["cleared"]:
			continue
		var left := 0
		for z in zombies.list:
			if int(z["horde"]) == int(idx) and zombies.threat(z):
				left += 1
		var spawned_all := true
		for s in pending_spawn:
			if int(s["horde"]) == int(idx):
				spawned_all = false
		if spawned_all and (left <= 1 or now - float(info["t"]) > 150.0):
			info["cleared"] = true
			var recent := 0
			for t in shot_times:
				if now - float(t) < 60.0:
					recent += 1
			director.horde_cleared(now, recent)
			set_radio("기관사: 한 무리 지나갔다. " + director.forecast(now, forecast_precision, clock))


func _start_horde(h: Dictionary) -> void:
	var now := clock.elapsed
	var key: String = h["entry"]
	# Fair spawn: roads and the track end never let anything in on screen; pick
	# another road out of sight. Sewer mouths may be on screen: they rattle first.
	if not HordeDirector.is_sewer(key) and _entry_on_screen(key):
		for other in ["east_track", "north_road", "south_road"]:
			if not _entry_on_screen(other):
				key = other
				break
	hordes[h["index"]] = {"t": now, "cleared": false, "entry": key, "size": h["size"]}
	telemetry.horde(now, int(h["index"]), int(h["size"]), key)
	var target := player.position
	var gap: float = float(data["entry_gap"].get(key, 0.6))
	var lead := 3.0 if HordeDirector.is_sewer(key) else 0.0
	var cells: Array = data["entries"][key]
	for i in range(int(h["size"])):
		pending_spawn.append({"t": now + lead + i * gap, "pos": FieldGrid.center(cells[i % cells.size()]), "horde": h["index"], "target": target, "entry": key})
	if HordeDirector.is_sewer(key):
		set_radio("기관사: %s이 덜컹거린다. 올라온다." % HordeDirector.ENTRY_NAMES[key] if key == "manhole" else "기관사: %s에서 소리가 울린다. 올라온다." % HordeDirector.ENTRY_NAMES[key])
	else:
		set_radio("기관사: %s, 저것들이 들어온다." % HordeDirector.ENTRY_NAMES[key])
	# The first wave also pulls the dead of the street toward the train (front wave).
	if int(h["index"]) == 0:
		for z in zombies.list:
			if z["state"] == "wander" and grid.zone_at(FieldGrid.cell_of(z["pos"])) == "D":
				z["state"] = "investigate"
				z["target"] = FieldGrid.center(Vector2i(50, 10))
				z["linger"] = 30.0
				z["speed"] = Zombies.SPEED_SHAMBLE
	forecast_t = 6.0


func _entry_on_screen(key: String) -> bool:
	return camera.is_position_in_frustum(FieldGrid.center(data["entries"][key][0]) + Vector3(0, 0.5, 0))


var forecast_t: float = 0.0


## Bodies come out one by one; the concurrent cap (60 on screen and round the
## train, 2026-10-07 review) holds the rest at the entry until room frees up.
func _update_spawns(delta: float) -> void:
	var now := clock.elapsed
	var keep: Array = []
	var alive := 0
	for z in zombies.list:
		if zombies.threat(z) and z["state"] != "frozen":
			alive += 1
	waiting = 0
	var gate: Dictionary = {}
	for s in pending_spawn:
		var key: String = s["entry"]
		# A manhole closed mid-horde sends the rest out of the culvert.
		if HordeDirector.is_sewer(key) and not director.is_open(key):
			key = "culvert"
			s["entry"] = key
			s["pos"] = FieldGrid.center(data["entries"][key][0])
		if now < float(s["t"]):
			keep.append(s)
			continue
		if alive >= cap or gate.has(key):
			waiting += 1
			s["t"] = now + 0.5
			keep.append(s)
			continue
		var z := zombies.spawn("dead", s["pos"] + Vector3(rng.randf_range(-0.4, 0.4), 0, rng.randf_range(-0.4, 0.4)), {"horde": s["horde"], "target": s["target"]})
		z["stander"] = false
		alive += 1
		gate[key] = true
	pending_spawn = keep
	if forecast_t > 0.0:
		forecast_t -= delta
		if forecast_t <= 0.0:
			set_radio("기관사: " + director.forecast(now, forecast_precision, clock))
	deaf_t = maxf(0.0, deaf_t - delta)


func set_radio(text: String) -> void:
	radio = text
	radio_t = 8.0
	hud.radio(text)


func say(p, text: String) -> void:
	if hud != null:
		hud.toast(text)


# ---------------------------------------------------------------- vision & camera

## Zomboid-like sight: a wide cone ahead, a small circle all round, walls hide.
func _refresh_vision() -> void:
	var origin := FieldGrid.cell_of(player.position)
	var radius := SIGHT_UPSTAIRS if player.upstairs else SIGHT_RADIUS
	if clock.is_dark():
		radius = int(radius * 0.6)
	if not mask_on:
		seen_now = {}
		view.set_mask_enabled(false)
		return
	view.set_mask_enabled(true)
	var forward := Vector2.ZERO if player.upstairs else Vector2(sin(player.facing), cos(player.facing))
	var result := grid.visible_cells(origin, radius, forward, VIEW_CONE_COS, NEAR_SIGHT)
	for i in result:
		seen_memory[i] = 1
	seen_now = result
	view.update_vis(seen_now, seen_memory)
	view.update_labels(seen_memory, mask_on)


func _person_visible(p: Person) -> bool:
	if p.team != "raider" and p.team != "survivor":
		return true
	if not mask_on:
		return true
	return seen_now.has(grid.index(FieldGrid.cell_of(p.position)))


func cell_seen(at: Vector3) -> bool:
	return not mask_on or seen_now.has(grid.index(FieldGrid.cell_of(at)))


func _update_camera(delta: float) -> void:
	var focus := player.position + cam_push
	cam_focus = cam_focus.lerp(focus, clampf(delta * 4.0, 0.0, 1.0))
	camera.size = lerpf(camera.size, cam_size, clampf(delta * 6.0, 0.0, 1.0))
	var pitch := deg_to_rad(CAM_PITCH)
	var back := Vector3(0, sin(pitch), cos(pitch)) * 60.0
	camera.position = cam_focus + back
	camera.look_at(cam_focus, Vector3.UP)
	snow.position = cam_focus + Vector3(0, 9, 0)
	sun.light_energy = lerpf(0.7, 0.1, clampf((clock.game_minutes() - 900.0) / 90.0, 0.0, 1.0))
	environment.ambient_light_energy = lerpf(0.6, 0.2, clampf((clock.game_minutes() - 900.0) / 90.0, 0.0, 1.0))


func screen_to_ground(screen: Vector2) -> Vector3:
	var origin := camera.project_ray_origin(screen)
	var dir := camera.project_ray_normal(screen)
	if absf(dir.y) < 0.0001:
		return Vector3.ZERO
	var t := -origin.y / dir.y
	return origin + dir * t


func pixels_per_metre() -> float:
	return get_viewport().get_visible_rect().size.y / camera.size


# ---------------------------------------------------------------- frozen, risen, doors

func on_frozen_wake(z: Dictionary) -> void:
	sounds.append({"pos": z["pos"], "level": SimNoise.Level.NORMAL, "t": clock.elapsed, "tag": "ice"})
	if player.position.distance_to(z["pos"]) < 14.0:
		hud.toast("눈 속에서 얼음이 갈라진다.")


func on_risen(z: Dictionary) -> void:
	if z["name"] != "":
		hud.toast("%s 일어났다." % z["name"])


func on_zombie_killed(z: Dictionary) -> void:
	pass


func on_door_banged(c: Vector2i) -> void:
	var door: Dictionary = grid.doors[c]
	if door["state"] == "open" or door["state"] == "broken":
		return
	door["hp"] = int(door["hp"]) - 1
	make_sound(FieldGrid.center(c), SimNoise.Level.NORMAL, "bang")
	if door["hp"] <= 0:
		grid.set_door_state(c, "broken")
		view.update_door(c)


func telemetry_note_spotted() -> void:
	spotted_events += 1


## A zombie's hand reaches a person: grab, scratch or blocked (body_injury 2장).
func zombie_reaches(z: Dictionary, p: Person) -> String:
	return combat.zombie_reaches(z, p)


# ---------------------------------------------------------------- end

func _check_end() -> void:
	if ended:
		return
	var squad_up := 0
	for p in squad:
		if p.is_alive() and not p.body.downed:
			squad_up += 1
	if squad_up == 0:
		finish("wiped")
		return
	if clock.past_limit():
		finish("limit")
		return
	if clock.past_safe() and not safe_warned:
		safe_warned = true
		set_radio("기관사: 이제 떠나야 한다. 오래는 못 기다린다.")


## Departure: whistle (very loud), people on the platform board, the rest stay.
func finish(reason: String) -> void:
	if ended:
		return
	ended = true
	var now := clock.elapsed
	var platform: Rect2i = data["platform"]
	if reason == "departed":
		make_sound(FieldGrid.center(Vector2i(90, 4)), SimNoise.Level.VERY_LOUD, "whistle")
	var boarded: Array = []
	for p in squad + crew:
		if not p.is_alive():
			continue
		var on_board: bool = platform.grow(1).has_point(FieldGrid.cell_of(p.position)) and not p.body.downed
		if p.brain.get("boarded", false):
			on_board = true
		if on_board or reason == "wiped" and false:
			boarded.append(p)
			for id in p.items:
				unloaded[id] = int(unloaded.get(id, 0)) + int(p.items[id])
		else:
			receipt.person("leftBehind", p.pid)
		if p.body.infection == "bite":
			receipt.person("bitten", p.pid)
		elif p.body.bleed >= 2 or p.body.leg_fracture or p.body.arm_fracture or p.body.downed:
			receipt.person("injured", p.pid)
	var stock: Dictionary = {}
	for id in unloaded:
		if STOCK_OF.has(id):
			var row: Array = STOCK_OF[id]
			stock[row[0]] = float(stock.get(row[0], 0.0)) + float(row[1]) * int(unloaded[id])
		if id in ["symbol_bell", "info_telegraph", "info_timetable"]:
			receipt.gain_item(id)
	stock["coal"] = float(stock.get("coal", 0.0)) + actions.coal_delivered - actions.coal_spent
	stock["scrap"] = float(stock.get("scrap", 0.0)) + float(unloaded.get("scrap", 0))
	stock["wood"] = float(stock.get("wood", 0.0)) + float(unloaded.get("wood", 0))
	for k in ["pistol", "shell", "craft"]:
		var used: int = int(ammo_start[k]) - int(ammo[k])
		var key: String = "ammo_" + k
		stock[key] = float(stock.get(key, 0.0)) - used
		telemetry.ammo(k, used)
	for key in stock:
		var v := roundi(float(stock[key]))
		if v != 0:
			receipt.add_stock(key, v)
	var depart_label := clock.label()
	receipt.set_time(clock.minutes_label(0.0), depart_label, clock.stay_game_minutes())
	var searched := 0
	for id in data["containers"]:
		if data["containers"][id]["searched"]:
			searched += 1
	receipt.set_place_state(snappedf(float(searched) / data["containers"].size(), 0.01), clampi(zombies.alive_count() / 10, 0, 5))
	receipt.place_note("waterTower", data["spots"]["water_tower"]["state"])
	receipt.set_end(reason)
	for d in decisions:
		receipt.decision(d["id"], d["choice"])
	telemetry.end(reason, now)
	var result := {"reason": reason, "receipt": receipt.to_dict(), "receipt_json": receipt.to_json(), "telemetry": telemetry.to_json_line(), "boarded": boarded.size(), "stay": clock.stay_game_minutes(), "real_seconds": now, "unloaded": unloaded.duplicate(), "noise": ledger.total, "hordes": hordes.size()}
	_save(result)
	hud.show_end(result)
	finished.emit(result)


func _save(result: Dictionary) -> void:
	DirAccess.make_dir_recursive_absolute("user://runs")
	var stamp := Time.get_datetime_string_from_system().replace(":", "-")
	var f := FileAccess.open("user://runs/receipt_%s.json" % stamp, FileAccess.WRITE)
	if f:
		f.store_string(result["receipt_json"])
	var t := FileAccess.open("user://runs/telemetry.jsonl", FileAccess.READ_WRITE if FileAccess.file_exists("user://runs/telemetry.jsonl") else FileAccess.WRITE)
	if t:
		t.seek_end()
		t.store_line(result["telemetry"])


func item_name(id: String) -> String:
	if EXTRA_ITEMS.has(id):
		return EXTRA_ITEMS[id]["name"]
	if id == "scrap":
		return "고철"
	if id == "wood":
		return "목재"
	return String(Carry.ITEM_NAMES.get(id, W.get_data(id).get("name", id)))
