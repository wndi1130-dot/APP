extends Node
## The stop seen from the train (결정 421-3, presentation_motion.md 정차 장면).
## 「정차 고르기」 no longer lays the card straight over the carriages: the
## camera climbs onto the roof of the running train, the place comes out of
## the weather ahead and the train slows, and the stop card comes up with the
## station behind it (card_time). Sent: the brakes (the stop's own brake sound
## at field_audio.gd's loudness), the train stands, and the camera goes up and
## over to look down on the platform the way the field's camera does, while the
## field is built underneath (stop_loader.gd): the slower that is the longer
## the look down, never shorter than DOWN_S. Passed by: the train picks up
## speed and the camera comes back down beside it to the train's own screen.
##
## All of it is looks. The stop's map is read for where its platform,
## buildings, wagons and trees stand; nothing is written, and skipping a beat
## (once it has been seen whole) changes nothing in the stop. It has a world of
## its own (a SubViewport) so the field can be built in the main one under it.
## It wears the weather the field will open with (stop_look: the atmosphere
## frame's look for the stop's act, cold and hour): late autumn's rain on wet
## ground, snow lying only as deep as it lies, the same sky light.

signal card_time
signal done(how: String)           # "sent" or "passed"

const TrainModels = preload("res://game/world/train_model_kit.gd")
const TrackView = preload("res://game/world/track_view.gd")
const FieldGrid = preload("res://game/world/field_grid.gd")
const MapView = preload("res://game/world/map_view.gd")
const BuildingView = preload("res://game/world/building_view.gd")
const Smoke = preload("res://fx/smoke.gd")
const FxState = preload("res://fx/fx_state.gd")
const FieldAudio = preload("res://game/audio/field_audio.gd")
const UiFonts = preload("res://game/ui/ui_fonts.gd")
const Atmosphere = preload("res://fx/atmosphere.gd")
const SnowCover = preload("res://game/sim/snow_cover.gd")
const Weather = preload("res://game/sim/weather.gd")
const PrecipShader = preload("res://fx/shaders/precip.gdshader")
const BRAKE_SOUND := "res://audio/train_brake/brake.wav"
## Seconds into the brake sound at which the train stands; the sound starts
## so that moment falls on the train's own.
const BRAKE_STAND_AT: float = FieldAudio.BRAKE_STAND_AT
const ROLL_SOUND := "res://audio/train_idle/train_idle.wav"

## The beats (seconds; the result notes and test_stop_cinema.gd hold them).
## The run lasts at least RUN_S and goes on till the stop's map is known; when
## the map comes late the run goes on RUN_LEAD_S more, so the place is laid out
## far off in the weather, never in sight.
const RISE_S: float = 1.8
const RUN_S: float = 2.6
const RUN_LEAD_S: float = 3.0
const NEAR_S: float = 4.0
const BRAKE_MIN_S: float = 1.2
const BRAKE_MAX_S: float = 2.4
const DOWN_S: float = 2.4
const AWAY_S: float = 2.4
const FADE_S: float = 0.35
## The run and the slowing (m/s, s, m): the card comes up D_CARD short of the
## stand at CARD_SPEED, and while it is up the train creeps on, closing on
## HOLD_LEFT short of the stand (the last of it is the brakes').
const RUN_SPEED: float = 12.0
const CARD_SPEED: float = 4.0
const HOLD_K: float = 1.6
const HOLD_LEFT: float = 1.5
const D_CARD: float = HOLD_LEFT + HOLD_K * CARD_SPEED
const D_NEAR: float = D_CARD + (RUN_SPEED + CARD_SPEED) * 0.5 * NEAR_S
## The look down ends where the field's own camera begins (field_game.gd
## CAM_PITCH, CAM_YAW and cam_size 24 m of height): the same pitch and turn, the
## same height of ground on the screen, a narrow lens standing in for its flat one.
const FIELD_PITCH_DEG: float = 35.0
const FIELD_YAW_DEG: float = 45.0
const FIELD_VIEW_H: float = 24.0
const DOWN_FOV: float = 24.0
## Every map's train (field_maps.gd cars_of; all 81 maps, 2026-10-24): 80 m,
## four cars and the engine at the east end. Laid at the origin here; the
## stop's map is moved to meet it.
const TRAIN := Rect2i(0, 0, 80, 3)
## The weather and the hour a stop opens with till it says otherwise
## (field_game.gd weather ["fog", "snow"], field_clock.gd ARRIVE_MIN 10:30).
const WEATHER: Array = ["fog", "snow"]
const HOUR: float = 10.5
const SEEN_FILE := "user://presentation.cfg"
## Snow over the roofs and the ground, the muted colours of the field (map_view.gd).
const SNOW := Color(0.66, 0.68, 0.71)
const STEEL := Color(0.25, 0.25, 0.27)
const ROOF := Color(0.24, 0.23, 0.23)
const WINDOW_DARK := Color(0.13, 0.13, 0.14)
const ROOF_SNOW := Color(0.78, 0.8, 0.83)
const TRUNK := Color(0.3, 0.26, 0.22)
const CROWN := Color(0.62, 0.66, 0.66)
## A fir's own dark green-grey, where no snow lies on it.
const FIR := Color(0.25, 0.28, 0.26)
## The field's air (game/sim/outside_temp.gd, the season table's stretch
## temperature, and the Weather the field makes from it) and its lying snow's
## white (world_vis.gdshader FX_SNOW).
const OutsideTemp = preload("res://game/sim/outside_temp.gd")
const FX_SNOW := Color(0.70, 0.71, 0.72)
## Camera places on the train (its own frame: TRAIN at the origin, the line
## along x through z 1.5, the roofs about 3.4 up): beside it as the train's
## screen shows it, on the tail car's roof looking ahead, and turned out to the
## platform side, the station on the right of the screen (the card is on the left).
const SIDE_AT := Vector3(36, 2.4, 27.5)
const SIDE_LOOK := Vector3(36, 1.8, 1.5)
const SIDE_FOV: float = 36.0
const ROOF_AT := Vector3(6, 6.6, 1.1)
const ROOF_LOOK := Vector3(52, 3.6, 2.7)
const ROOF_FOV: float = 60.0
## Over the stop while the card is up: high behind the tail on the far side,
## looking over the train at the stop's buildings by the platform, turned so
## they sit at STATION_SCREEN_X of the screen's width (the card covers the left).
const STATION_AT := Vector3(-4, 13, -10)
const STATION_FOV: float = 52.0
const STATION_SCREEN_X: float = 0.72
## Where the buildings counted for that are: beside the train and this far out on the platform side.
const STATION_REACH := Vector2(10, 40)
## The weather's depth: thick along the line, the place coming out of it; as
## the camera rises over the stop it thins to the field's clear look (the
## field draws no depth fog), so the hand-over is not a jump in the air.
const FOG_LINE_K: float = 0.85
const FOG_NEAR_K: float = 0.6
const FOG_OVER: float = 0.0015
## Laid ahead of the train, a stretch at a time, as far as the weather lets one see and more.
const CORRIDOR_AHEAD: float = 240.0
const CORRIDOR_STEP: float = 60.0

## The stop's map (stop_loader.gd), {} till it is known; set_map hands it over.
var data: Dictionary = {}
## Seen whole before (SEEN_FILE): a tap then goes to the next beat.
var seen: bool = false
## Write SEEN_FILE once it has been seen whole (off in tests).
var remember: bool = true
## The field is built: the look down may end.
var ready_to_land: bool = false
## The stop's field opts (slice_flow.gd _field_opts): read for the weather the
## field opens with, so the scene and the field under it wear the same.
var stop_opts: Dictionary = {}
var look: Dictionary = {}          # the stop's atmosphere look (stop_look)
var fx: Dictionary = {}            # its fx_* shader globals
var falls: String = "snow"         # what falls: snow, sleet, rain or none
var white: float = 1.0             # how white the ground lies, 0..1 (fx_snow)
var wet: float = 0.0               # how wet it is (fx_wet)
## rise, run, near, hold, brake, away, down, rest, out, end.
var beat: String = ""
var t: float = 0.0                 # seconds into the beat
var clock: float = 0.0             # seconds since it began, pauses not counted
var paused: bool = false
var how: String = ""               # "sent" or "passed" once one is chosen
var speed: float = 0.0             # the train's, m/s
var beats_seen: Array = []         # the beats in the order they began (tests)
var layer: CanvasLayer
var port: SubViewport
var view: TextureRect
var marks: Control                 # the loading ring and the skip arrow
var world: Node3D
var camera: Camera3D
var train_pivot: Node3D
var station: Node3D
var smoke_run: GPUParticles3D
var smoke_idle: GPUParticles3D
var snow: GPUParticles3D
var brake_player: AudioStreamPlayer
var roll_player: AudioStreamPlayer
var p: float = 0.0                 # the train's way along the line (its frame's x)
var p_stand: float = INF           # where it comes to stand, once the map is known
var run_end: float = -1.0          # the clock at which the run gives way to the slowing
var _d: float = 0.0                # metres short of the stand
var _brake: Dictionary = {}
var _from: Transform3D
var _from_fov: float = ROOF_FOV
var _corridor_to: float = -200.0
var _corridor_stop: float = INF
var _shake: float = 0.0
var _spin: float = 0.0
var _env: Environment
var _fog_line: float = 0.025
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.seed = 421
	layer = CanvasLayer.new()
	layer.name = "StopCinema"
	# Over the field and its HUD (5, 10) while it is built underneath, under
	# the slice's own layer (40) with the gauges and the stop card.
	layer.layer = 20
	add_child(layer)
	port = SubViewport.new()
	port.own_world_3d = true
	port.msaa_3d = Viewport.MSAA_DISABLED
	port.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	port.gui_disable_input = true
	add_child(port)
	_fit_port()
	get_viewport().size_changed.connect(_fit_port)
	view = TextureRect.new()
	view.name = "View"
	view.texture = port.get_texture()
	view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	view.stretch_mode = TextureRect.STRETCH_SCALE
	view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	view.modulate.a = 0.0
	view.gui_input.connect(_view_input)
	layer.add_child(view)
	marks = Control.new()
	marks.name = "Marks"
	marks.mouse_filter = Control.MOUSE_FILTER_IGNORE
	marks.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	marks.draw.connect(_draw_marks)
	layer.add_child(marks)
	var sl := stop_look(stop_opts)
	look = sl["look"]
	fx = sl["params"]
	falls = String(look.get("falls", "snow"))
	white = clampf(float(fx.get("fx_snow", 0.0)), 0.0, 1.0)
	wet = clampf(float(fx.get("fx_wet", 0.0)), 0.0, 1.0)
	# The globals the field sets as it is built under the scene, set now: the
	# train's models and the smoke read them, so nothing turns mid-scene.
	FxState.apply(fx)
	_build_world()
	_build_train()
	_build_sound()
	if not data.is_empty():
		_place_station()
	_begin("rise")
	_step(0.0)


## The stop's map, known now: its place is laid out ahead in the weather.
func set_map(d: Dictionary) -> void:
	if d.is_empty() or not data.is_empty():
		return
	data = d
	if is_inside_tree():
		_place_station()


## The crew is sent: the brakes, then the look down.
func send() -> void:
	if beat != "hold":
		return
	how = "sent"
	_begin("brake")


## The stop is passed by: the train picks up speed again.
func pass_by() -> void:
	if beat != "hold":
		return
	how = "passed"
	_begin("away")


## The field is ready: once the look down has had its time it gives way.
func land() -> void:
	ready_to_land = true


## A tap once the scene has been seen whole: on to the next beat. The card and
## the wait for the field are not skipped.
func skip() -> void:
	if not seen or paused:
		return
	match beat:
		"rise", "run", "near":
			if p_stand < INF:
				_begin("hold")
		"brake":
			_d = 0.0
			p = p_stand
			train_pivot.position.x = p
			_begin("down")
		"down":
			_begin("rest")
		"away":
			_begin("out")


## Whether the camera has come to rest over the stop (the field may then be
## built in longer slices: a still picture bears a slower frame).
func at_rest() -> bool:
	return beat == "rest" or beat == "out" or beat == "end"


## The beat's way, 0 to 1, for the tests and the marks.
func progress() -> float:
	match beat:
		"rise":
			return clampf(t / RISE_S, 0.0, 1.0)
		"near":
			return clampf(t / NEAR_S, 0.0, 1.0)
		"down":
			return clampf(t / DOWN_S, 0.0, 1.0)
		"away":
			return clampf(t / AWAY_S, 0.0, 1.0)
	return 0.0


static func was_seen() -> bool:
	var cfg := ConfigFile.new()
	if cfg.load(SEEN_FILE) != OK:
		return false
	return bool(cfg.get_value("stop_cinema", "seen", false))


static func mark_seen() -> void:
	var cfg := ConfigFile.new()
	cfg.load(SEEN_FILE)
	cfg.set_value("stop_cinema", "seen", true)
	cfg.save(SEEN_FILE)


func _notification(what: int) -> void:
	# A call or the home button: the scene stops where it is and comes back
	# there, on the same beat (J03). Nothing in it counts time while away.
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED:
		_pause(true)
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN or what == NOTIFICATION_APPLICATION_RESUMED:
		_pause(false)


func _pause(on: bool) -> void:
	paused = on
	for pl in [brake_player, roll_player]:
		if is_instance_valid(pl):
			pl.stream_paused = on
	for parts in [smoke_run, smoke_idle, snow]:
		if is_instance_valid(parts):
			parts.speed_scale = 0.0 if on else 1.0


func _process(delta: float) -> void:
	if paused:
		return
	_step(minf(delta, 0.1))


## One tick of the scene (the tests call it straight).
func _step(delta: float) -> void:
	clock += delta
	t += delta
	_spin += delta
	var was: float = p
	match beat:
		"rise", "run":
			p += RUN_SPEED * delta
			_d = p_stand - p if p_stand < INF else INF
			if beat == "rise" and t >= RISE_S:
				_begin("run")
			elif beat == "run" and run_end >= 0.0 and clock >= run_end:
				_begin("near")
		"near":
			var k: float = minf(t, NEAR_S)
			_d = D_NEAR - (RUN_SPEED * k + (CARD_SPEED - RUN_SPEED) * k * k / (2.0 * NEAR_S))
			p = p_stand - _d
			if t >= NEAR_S:
				# The card comes up; the creep goes on from where the slowing left off.
				var over: float = t - NEAR_S
				_begin("hold")
				t = over
				_d = _hold_d(t)
				p = p_stand - _d
		"hold":
			_d = _hold_d(t)
			p = p_stand - _d
		"brake":
			var s: float = clampf(t / float(_brake["len"]), 0.0, 1.0)
			var d0: float = _brake["d0"]
			var v0: float = _brake["v0"]
			var span: float = _brake["len"]
			_d = d0 * (2.0 * s * s * s - 3.0 * s * s + 1.0) - v0 * span * (s * s * s - 2.0 * s * s + s)
			p = p_stand - _d
			_shake = maxf(0.0, 1.0 - s) * 0.12
			if s >= 1.0:
				_d = 0.0
				p = p_stand
				_begin("down")
		"down":
			if t >= DOWN_S:
				_begin("rest")
		"rest":
			if ready_to_land:
				_begin("out")
		"away":
			var v: float = lerpf(float(_brake.get("v0", 0.0)), RUN_SPEED, clampf(t / 1.6, 0.0, 1.0))
			p += v * delta
			if t >= AWAY_S:
				_begin("out")
		"out":
			view.modulate.a = clampf(1.0 - t / FADE_S, 0.0, 1.0)
			if t >= FADE_S:
				_begin("end")
	if beat != "out" and beat != "end":
		view.modulate.a = minf(1.0, view.modulate.a + delta / FADE_S)
	speed = (p - was) / delta if delta > 0.0 else speed
	train_pivot.position.x = p
	_lay_corridor(p + CORRIDOR_AHEAD)
	_place_camera()
	_update_fx()
	marks.queue_redraw()


## Metres short of the stand `s` seconds into the card: the creep closing on HOLD_LEFT.
static func _hold_d(s: float) -> float:
	return HOLD_LEFT + (D_CARD - HOLD_LEFT) * exp(-s / HOLD_K)


func _begin(b: String) -> void:
	# What a beat starts from: the train's speed when braking or going away,
	# the camera where it was for the moves that start from it.
	if b == "brake":
		var v: float = maxf((_d - HOLD_LEFT) / HOLD_K, 0.0) if beat == "hold" else maxf(speed, 0.0)
		_brake = {"d0": _d, "v0": v, "len": clampf(2.0 * _d / maxf(v, 0.01), BRAKE_MIN_S, BRAKE_MAX_S)}
		if is_instance_valid(brake_player) and brake_player.stream != null:
			brake_player.play(maxf(0.0, BRAKE_STAND_AT - float(_brake["len"])))
	elif b == "away":
		_brake = {"v0": maxf((_d - HOLD_LEFT) / HOLD_K, 0.0)}
	elif b == "hold":
		_d = D_CARD
		p = p_stand - _d
	if b == "down" or b == "away":
		_from = camera.global_transform
		_from_fov = camera.fov
	beat = b
	t = 0.0
	beats_seen.append(b)
	if b == "hold":
		card_time.emit()
	elif b == "out":
		if not seen and remember:
			mark_seen()
		done.emit(how)
	elif b == "end":
		queue_free()


func _view_input(e: InputEvent) -> void:
	var up_click: bool = e is InputEventMouseButton and (e as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT and not e.is_pressed()
	var up_touch: bool = e is InputEventScreenTouch and not e.is_pressed()
	if up_click or up_touch:
		skip()


func _fit_port() -> void:
	var s: Vector2i = get_window().size if get_window() != null else Vector2i(1280, 720)
	port.size = Vector2i(maxi(s.x, 64), maxi(s.y, 64))


# ---------------------------------------------------------------- the world

func _build_world() -> void:
	world = Node3D.new()
	world.name = "World"
	port.add_child(world)
	var light: Dictionary = Atmosphere.light(look)
	var env := Environment.new()
	# Dark and cold, as the field's air is (its background is the weather's tint, darkened).
	var air: Color = Color(light["fog_color"]).darkened(0.3)
	env.background_mode = Environment.BG_COLOR
	env.background_color = air
	# The field's exposure (field_game.gd _build_world), so the stop and the field it opens on are one brightness.
	env.tonemap_exposure = Atmosphere.EXPOSURE
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = light["ambient_color"]
	env.ambient_light_energy = float(light["ambient_energy"]) * 1.15
	# The running train's horizon: the depth fog the field leaves off (fx_state.gd).
	_fog_line = float(light["fog_density"]) * FOG_LINE_K
	env.fog_enabled = true
	env.fog_density = _fog_line
	env.fog_light_color = air
	_env = env
	var we := WorldEnvironment.new()
	we.environment = env
	world.add_child(we)
	var sun := DirectionalLight3D.new()
	# Where the field's sun stands at the hour it opens (field_game.gd).
	sun.rotation_degrees = Vector3(float(light["sun_pitch"]), float(light["sun_yaw"]), 0.0)
	sun.light_color = light["sun_color"]
	sun.light_energy = light["sun_energy"]
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 90.0
	world.add_child(sun)
	camera = Camera3D.new()
	camera.near = 0.2
	camera.far = 600.0
	world.add_child(camera)
	camera.current = true
	# The ground: one sheet (snow as deep as it lies, else wet open ground),
	# the line's ballast and rails along it.
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	MapView.box(st, Vector3(6000, 0.2, 1600), Vector3(0, -0.1, 1.5), _ground(SNOW))
	MapView.box(st, Vector3(6000, 0.03, 3.2), Vector3(0, 0.016, 1.5), MapView.FLOOR_COLORS[FieldGrid.Floor.RAIL])
	for z: float in [1.5 - 0.72, 1.5 + 0.72]:
		MapView.box(st, Vector3(6000, 0.12, 0.08), Vector3(0, 0.16, z), STEEL)
	_mesh(world, st, false)
	snow = GPUParticles3D.new()
	snow.amount = 2700  # three times the old 900, as the field draws (field_game.gd)
	snow.lifetime = 3.0
	snow.local_coords = false
	snow.visibility_aabb = AABB(Vector3(-40, -10, -40), Vector3(80, 30, 80))
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(34, 8, 26)
	pm.direction = Vector3(0.3, -1, 0.1)
	pm.spread = 12.0
	pm.initial_velocity_min = 1.4
	pm.initial_velocity_max = 2.2
	pm.gravity = Vector3(0.0, -0.5, 0.0)
	snow.process_material = pm
	# What falls is the field's (field_game.gd, the same precip shader): rain
	# streaks when it is warm, small quick wet flakes for sleet, else snow.
	var flake := QuadMesh.new()
	flake.size = Vector2(0.09, 0.09)
	var fm := ShaderMaterial.new()
	fm.shader = PrecipShader
	fm.set_shader_parameter("shape", 1)
	fm.set_shader_parameter("opacity", 0.85)
	if falls == "rain":
		flake.size = Vector2(0.025, 0.5)
		fm.set_shader_parameter("shape", 0)
		fm.set_shader_parameter("opacity", 0.6)
		pm.direction = Vector3(0.05, -1, 0.02)
		pm.initial_velocity_min = 7.0
		pm.initial_velocity_max = 9.0
		pm.gravity = Vector3(0.0, -4.0, 0.0)
		snow.lifetime = 1.6
	elif falls == "sleet":
		flake.size = Vector2(0.07, 0.07)
		fm.set_shader_parameter("opacity", 0.7)
		pm.initial_velocity_min = 3.5
		pm.initial_velocity_max = 4.5
		snow.lifetime = 2.6
	flake.material = fm
	snow.draw_pass_1 = flake
	snow.emitting = falls != "none"
	world.add_child(snow)


## The look the field opens this stop with (field_game.gd _ready, _apply_fx
## and picture_hour: the same region, act cold, side, weather, hour and lying
## snow) and the shader globals it sets: {"look", "params"}.
static func stop_look(o: Dictionary) -> Dictionary:
	var region := Atmosphere.region_key(String(o.get("region", Atmosphere.DEFAULT_REGION)))
	var act := String(o.get("act", "prologue"))
	var scheme := String(o.get("cold_scheme", ""))
	var cold := clampf(float(o.get("cold", Atmosphere.cold_for(act, float(o.get("act_progress", 0.0)), scheme))), 0.0, 1.0)
	var side := clampf(float(o.get("side", Atmosphere.side_for(act, scheme))), 0.0, 1.0)
	var weather = Weather.new(o.get("weather", WEATHER), OutsideTemp.of(o, cold, side), Vector2(1, 0.2), 0.4)
	var kinds: Array = o.get("look", weather.kinds)
	var hour := float(o.get("look_hour", -1.0))
	if hour <= -1.5:
		var sun := Atmosphere.sun_times(cold, side)
		hour = [sun.x + 0.25, sun.y - 0.4, sun.y + 1.7][clampi(int(round(-hour)) - 2, 0, 2)]
	elif hour < 0.0:
		hour = float(o.get("arrive_min", HOUR * 60.0)) / 60.0
	# The season by the season table, as the field names it (a cold given
	# outright names it by that cold).
	var season := Atmosphere.season_for(cold, side) if o.has("cold") else Atmosphere.season_at(act, float(o.get("act_progress", 0.0)), scheme)
	var l: Dictionary = Atmosphere.look(hour, kinds, region, cold, {"wind": weather.wind, "side": side, "season": season})
	var open_ground := bool(Atmosphere.region(region)["open"])
	var lying = SnowCover.new(season, open_ground, 0.0, Atmosphere.cold_key(cold, "snow_cm", 1 if open_ground else 0, side))
	return {"look": l, "params": Atmosphere.params(l, weather.wind_dir, lying.cover())}


## A colour open to the sky as the field's world_vis.gdshader shows it: darker
## when wet, under the snow as far as it lies.
func _ground(base: Color) -> Color:
	# As world_vis does: the floor colour read as sRGB, dampened and snowed in
	# linear (its FX_SNOW is a linear number), handed back as an sRGB vertex colour.
	var damp: float = 1.0 - 0.35 * wet
	var lin := base.srgb_to_linear()
	var bare := Color(lin.r * damp, lin.g * damp, lin.b * damp)
	var snowy: Color = FX_SNOW * lerpf(1.0, 0.75, wet)
	return bare.lerp(Color(snowy.r, snowy.g, snowy.b), 0.75 * white).linear_to_srgb()


func _build_train() -> void:
	train_pivot = Node3D.new()
	train_pivot.name = "Train"
	world.add_child(train_pivot)
	var cars: Array = []
	var x: int = TRAIN.position.x
	while x < TRAIN.end.x:
		cars.append({"rect": Rect2i(x, TRAIN.position.y, 16, TRAIN.size.y), "kind": "car"})
		x += 16
	cars[cars.size() - 1]["kind"] = "engine"
	var kit := TrainModels.attach_field(train_pivot, {"train": TRAIN, "train_cars": cars})
	# Cars the models could not stand for are dark boxes, as on the field.
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var any: bool = false
	for index: int in kit.get_meta("fallback_cars", []):
		var r: Rect2i = cars[index]["rect"]
		MapView.box(st, Vector3(r.size.x - 0.6, 3.0, 2.8), Vector3(r.position.x + r.size.x * 0.5, 1.5, 1.5), Color(0.3, 0.29, 0.28) if cars[index]["kind"] == "car" else Color(0.22, 0.22, 0.24))
		any = true
	if any:
		_mesh(train_pivot, st, true)
	# The engine's smoke (fx/smoke.gd: long and grey behind it while it runs,
	# low steam by the wheels once it stands, never a column).
	smoke_run = Smoke.build("loco_run")
	smoke_run.position = Vector3(TRAIN.end.x - 3.0, 4.4, 1.5)
	train_pivot.add_child(smoke_run)
	smoke_idle = Smoke.build("loco_idle")
	smoke_idle.position = Vector3(TRAIN.end.x - 6.0, 0.3, 3.1)
	train_pivot.add_child(smoke_idle)
	Smoke.update_locomotive(smoke_run, smoke_idle, RUN_SPEED)


func _build_sound() -> void:
	FieldAudio._ensure_bus()
	brake_player = AudioStreamPlayer.new()
	brake_player.bus = "SFX"
	if ResourceLoader.exists(BRAKE_SOUND):
		brake_player.stream = load(BRAKE_SOUND)
	# As loud as the field's own brakes (field_audio.gd BRAKE_LOUD).
	brake_player.volume_db = FieldAudio._db(FieldAudio.BRAKE_LOUD)
	add_child(brake_player)
	roll_player = AudioStreamPlayer.new()
	roll_player.bus = "SFX"
	if ResourceLoader.exists(ROLL_SOUND):
		roll_player.stream = load(ROLL_SOUND)
	roll_player.volume_db = FieldAudio._db(0.35)
	roll_player.finished.connect(func() -> void:
		if beat != "end" and is_instance_valid(roll_player):
			roll_player.play())
	add_child(roll_player)
	if roll_player.stream != null:
		roll_player.play()


## The stop's place, from its map: laid where the train will stand, the line
## through it meeting the train's own. Its corridor stops short of it.
func _place_station() -> void:
	if p_stand < INF or data.is_empty() or not data.get("train") is Rect2i:
		return
	run_end = maxf(RISE_S + RUN_S, clock + (RUN_LEAD_S if clock > 0.05 else 0.0))
	var run_left: float = maxf(run_end - clock, 0.0)
	p_stand = p + RUN_SPEED * run_left + D_NEAR
	var tr: Rect2i = data["train"]
	station = Node3D.new()
	station.name = "Station"
	station.position = Vector3(p_stand - tr.position.x, 0.0, float(TRAIN.position.y - tr.position.y))
	world.add_child(station)
	_corridor_stop = station.position.x - 6.0
	_build_station()


func _build_station() -> void:
	var g: FieldGrid = data["grid"]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Floors that are not snow, as the field lays them; the platform a little raised.
	for y in range(g.height):
		var start: int = -1
		var kind: int = -1
		for x in range(g.width + 1):
			var f: int = g.floor_at(Vector2i(x, y)) if x < g.width else -1
			var shown: int = f if f != FieldGrid.Floor.SNOW and f != FieldGrid.Floor.DEEP_SNOW else -1
			if start >= 0 and shown != kind:
				var high: float = 0.28 if kind == FieldGrid.Floor.PLATFORM else 0.03
				MapView.box(st, Vector3(x - start, high, 1), Vector3((start + x) * 0.5, high * 0.5 + 0.005, y + 0.5), _ground(MapView.FLOOR_COLORS[kind]))
				start = -1
			if shown >= 0 and start < 0:
				start = x
				kind = shown
	var uppers: Array = data.get("upper_rects", [])
	var lamps := SurfaceTool.new()
	lamps.begin(Mesh.PRIMITIVE_TRIANGLES)
	var lit: bool = false
	for b: Dictionary in data.get("buildings", []):
		if not b.get("rect") is Rect2i:
			continue
		var r: Rect2i = b["rect"]
		var floors: int = 1
		for u in uppers:
			if u is Rect2i and (u as Rect2i).intersects(r):
				floors = 2
				break
		_building(st, lamps, b, floors)
		lit = lit or bool(b.get("warm", false))
	# Wagons on the sidings: the field's own models (map_view.gd), open, flat or tender as the field
	# shows them; an open box only where the kit has none. No closed wagon (map brief, ban list).
	var wagons: Array = data.get("wagons", [])
	var wagon_models := TrainModels.attach_wagons(station, wagons, TrackView.wagon_heights(g, wagons))
	for index: int in wagon_models.get_meta("fallback_wagons", []):
		for part: Array in open_wagon_parts(wagons[index]):
			MapView.box(st, part[0], part[1], part[2])
	for c in data.get("trees", []):
		_tree(st, FieldGrid.center(c))
	for r in data.get("low_blocks", []):
		var mid := Vector3(r.position.x + r.size.x * 0.5, 0, r.position.y + r.size.y * 0.5)
		MapView.box(st, Vector3(r.size.x - 0.1, 1.0, r.size.y - 0.1), mid + Vector3(0, 0.5, 0), Color(0.42, 0.4, 0.38))
	if (data.get("spots", {}) as Dictionary).has("water_tower"):
		for y in range(mini(14, g.height)):
			for x in range(mini(14, g.width)):
				var c := Vector2i(x, y)
				if g.solid_at(c) == FieldGrid.Solid.BLOCK and g.building_at(c) < 0:
					MapView.box(st, Vector3(1, 6.0, 1), Vector3(x + 0.5, 3.0, y + 0.5), Color(0.4, 0.37, 0.35))
	else:
		for r in MapView.outdoor_block_runs(g, data):
			MapView.box(st, Vector3(r.size.x, 2.4, 1), Vector3(r.position.x + r.size.x * 0.5, 1.2, r.position.y + 0.5), Color(0.44, 0.43, 0.42))
	_mesh(station, st, true)
	if lit:
		var m := _mesh(station, lamps, false)
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_color = FxState.LAMP
		m.material_override = mat
	# The line's sleepers through the place, as along the way to it.
	_sleepers(station.position.x - 4.0, station.position.x + g.width + 60.0)


## The way to the stop, laid a stretch at a time ahead of the train: telegraph
## poles on the far side, trees and drifts out from the line, sleepers under it.
## Nothing is laid where the stop's own place begins.
func _lay_corridor(to: float) -> void:
	while _corridor_to < minf(to, _corridor_stop):
		var x0: float = _corridor_to
		var x1: float = minf(x0 + CORRIDOR_STEP, _corridor_stop)
		var rng := RandomNumberGenerator.new()
		rng.seed = 7919 + int(floor(x0))
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var px: float = ceilf(x0 / 45.0) * 45.0
		while px < x1:
			MapView.box(st, Vector3(0.24, 7.0, 0.24), Vector3(px, 3.5, -3.5), Color(0.27, 0.24, 0.21))
			MapView.box(st, Vector3(0.12, 0.12, 1.6), Vector3(px, 6.6, -3.5), Color(0.27, 0.24, 0.21))
			px += 45.0
		for i in 16:
			var side: float = -1.0 if rng.randf() < 0.55 else 1.0
			var z: float = 1.5 + side * rng.randf_range(11.0, 140.0)
			_tree(st, Vector3(rng.randf_range(x0, x1), 0, z))
		# Drifts out from the line, only where snow lies to drift.
		for i in (5 if white > 0.3 else 0):
			var side: float = -1.0 if rng.randf() < 0.5 else 1.0
			var z: float = 1.5 + side * rng.randf_range(7.0, 60.0)
			var w: float = rng.randf_range(3.0, 9.0)
			MapView.box(st, Vector3(w, rng.randf_range(0.3, 0.8), w * 0.6), Vector3(rng.randf_range(x0, x1), 0.2, z), ROOF_SNOW)
		var node := _mesh(world, st, true)
		node.visibility_range_end = CORRIDOR_AHEAD + 120.0
		_sleepers(x0, x1)
		_corridor_to = x1
		if x1 >= _corridor_stop:
			break


func _sleepers(x0: float, x1: float) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var x: float = ceilf(x0 / 0.7) * 0.7
	while x < x1:
		MapView.box(st, Vector3(0.24, 0.1, 2.5), Vector3(x, 0.07, 1.5), Color(0.24, 0.21, 0.19))
		x += 0.7
	var node := _mesh(world, st, false)
	node.visibility_range_end = 140.0


## A fir in three tiers on a dark trunk (seen from the side, the field's
## trunk-and-crown box reads as a sign), as snowy as the stop's snow lies.
func _tree(st: SurfaceTool, at: Vector3) -> void:
	var crown: Color = FIR.lerp(CROWN, white)
	MapView.box(st, Vector3(0.35, 1.6, 0.35), at + Vector3(0, 0.8, 0), TRUNK)
	MapView.box(st, Vector3(2.6, 1.3, 2.6), at + Vector3(0, 1.9, 0), FIR.darkened(0.08).lerp(Color(0.33, 0.37, 0.36), white))
	MapView.box(st, Vector3(1.9, 1.2, 1.9), at + Vector3(0, 3.0, 0), crown.darkened(0.25))
	MapView.box(st, Vector3(1.1, 1.1, 1.1), at + Vector3(0, 4.0, 0), crown)


## A wagon the model kit has none for, as [size, centre, colour] boxes: a floor on its wheels and four
## low sides, open on top, its coal heaped inside a little over the sides.
static func open_wagon_parts(w: Dictionary) -> Array:
	var r: Rect2i = w["rect"]
	var mid := Vector3(r.position.x + r.size.x * 0.5, 0, r.position.y + r.size.y * 0.5)
	var lx: float = r.size.x - 0.2
	var lz: float = r.size.y - 0.2
	var body := Color(0.33, 0.3, 0.28)
	var out: Array = [[Vector3(lx, 0.3, lz), mid + Vector3(0, 0.75, 0), body]]
	for s: float in [-1.0, 1.0]:
		out.append([Vector3(lx, 1.0, 0.12), mid + Vector3(0, 1.4, s * (lz - 0.12) * 0.5), body])
		out.append([Vector3(0.12, 1.0, lz), mid + Vector3(s * (lx - 0.12) * 0.5, 1.4, 0), body])
	if float(w.get("coal", 0.0)) > 0.0:
		out.append([Vector3(lx - 0.6, 1.1, lz - 0.6), mid + Vector3(0, 1.45, 0), Color(0.12, 0.12, 0.13)])
	return out


## A building as one block of its own paint (building_view.gd paint_for, a little
## darker), dark windows along it, lamp-lit ones where a stove is kept going,
## and a gable roof along its long side, snow-laden as far as snow lies.
func _building(st: SurfaceTool, lamps: SurfaceTool, b: Dictionary, floors: int) -> void:
	var roof: Color = ROOF.lightened(0.12).darkened(0.3 * wet).lerp(ROOF_SNOW, white)
	var r: Rect2i = b["rect"]
	var paint: Color = BuildingView.paint_for(int(b.get("id", 0)))
	var wall := Color(paint.r, paint.g, paint.b).darkened(0.28)
	var h: float = 3.0 * floors - 0.3
	var mid := Vector3(r.position.x + r.size.x * 0.5, 0.0, r.position.y + r.size.y * 0.5)
	MapView.box(st, Vector3(r.size.x, h, r.size.y), mid + Vector3(0, h * 0.5, 0), wall)
	var warm: bool = bool(b.get("warm", false))
	# Windows on the north and south faces, a floor at a time.
	for fl in floors:
		var y: float = 1.5 + 3.0 * fl
		for z: float in [r.position.y - 0.04, r.end.y + 0.04]:
			var x: float = r.position.x + 1.6
			while x < r.end.x - 1.0:
				MapView.box(lamps if warm else st, Vector3(1.0, 1.1, 0.06), Vector3(x, y, z), FxState.LAMP if warm else WINDOW_DARK)
				x += 3.2
	# The roof: two slopes over the long side and the gable ends.
	var long_x: bool = r.size.x >= r.size.y
	var span: float = float(r.size.y if long_x else r.size.x)
	var rise: float = clampf(span * 0.32, 1.0, 3.2)
	var eave: float = 0.3
	var x0: float = r.position.x - eave
	var x1: float = r.end.x + eave
	var z0: float = r.position.y - eave
	var z1: float = r.end.y + eave
	var top: float = h + rise
	if long_x:
		var zm: float = (z0 + z1) * 0.5
		_quad(st, Vector3(x0, h, z0), Vector3(x1, h, z0), Vector3(x1, top, zm), Vector3(x0, top, zm), roof)
		_quad(st, Vector3(x1, h, z1), Vector3(x0, h, z1), Vector3(x0, top, zm), Vector3(x1, top, zm), roof.darkened(0.12))
		_tri(st, Vector3(x0, h, z1), Vector3(x0, h, z0), Vector3(x0, top, zm), wall.darkened(0.1))
		_tri(st, Vector3(x1, h, z0), Vector3(x1, h, z1), Vector3(x1, top, zm), wall.darkened(0.1))
	else:
		var xm: float = (x0 + x1) * 0.5
		_quad(st, Vector3(x0, h, z1), Vector3(x0, h, z0), Vector3(xm, top, z0), Vector3(xm, top, z1), roof)
		_quad(st, Vector3(x1, h, z0), Vector3(x1, h, z1), Vector3(xm, top, z1), Vector3(xm, top, z0), roof.darkened(0.12))
		_tri(st, Vector3(x0, h, z0), Vector3(x1, h, z0), Vector3(xm, top, z0), wall.darkened(0.1))
		_tri(st, Vector3(x1, h, z1), Vector3(x0, h, z1), Vector3(xm, top, z1), wall.darkened(0.1))
	MapView.box(st, Vector3(x1 - x0, 0.18, z1 - z0), mid + Vector3(0, h + 0.02, 0), ROOF)


## A flat face, both sides (the roof is seen from below at the eaves too).
static func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, color: Color) -> void:
	_tri(st, a, b, c, color)
	_tri(st, a, c, d, color)


static func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, color: Color) -> void:
	var n: Vector3 = (c - a).cross(b - a).normalized()
	for v in [a, b, c]:
		st.set_color(color)
		st.set_normal(n)
		st.add_vertex(v)
	for v in [a, c, b]:
		st.set_color(color)
		st.set_normal(-n)
		st.add_vertex(v)


func _mesh(parent: Node3D, st: SurfaceTool, shadow: bool) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = st.commit()
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	# The colours are sRGB numbers, as the field's floors and every other material's are (mood C9).
	mat.vertex_color_is_srgb = true
	mat.roughness = 1.0
	node.material_override = mat
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadow else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(node)
	return node


# ---------------------------------------------------------------- the camera

## Where the camera is for the beat now: train-borne places ride with the
## train; the look down ends fixed over the platform where the field begins.
func _place_camera() -> void:
	var on_train: Transform3D = train_pivot.global_transform
	var side := _pose(SIDE_AT, SIDE_LOOK)
	var roof := _pose(ROOF_AT, ROOF_LOOK)
	var stat := _station_pose()
	var xf: Transform3D
	var fov: float = ROOF_FOV
	match beat:
		"rise":
			var k: float = _ease(t / RISE_S)
			xf = on_train * _blend(side, roof, k, 2.0)
			fov = lerpf(SIDE_FOV, ROOF_FOV, k)
		"run":
			xf = on_train * roof
		"near":
			var k: float = _ease(t / NEAR_S)
			xf = on_train * _blend(roof, stat, k)
			fov = lerpf(ROOF_FOV, STATION_FOV, k)
		"hold", "brake":
			xf = on_train * stat
			fov = STATION_FOV
		"down":
			var k: float = _ease(t / DOWN_S)
			xf = _blend(_from, _down_pose(), k, 9.0)
			fov = lerpf(_from_fov, DOWN_FOV, k)
		"rest", "out", "end" when how != "passed":
			# Waiting on the field: the view settles a little closer, slowly.
			var drift: float = 1.0 - exp(-t / 6.0)
			xf = _down_pose()
			xf.origin += (_down_focus() - xf.origin).normalized() * drift * 1.2
			fov = DOWN_FOV
		"away", "out", "end" when how == "passed":
			# Back onto the roof as the train picks up speed; the train's own
			# screen fades in from there (beside it the stop's buildings stand in the way).
			var k: float = _ease(t / 1.4) if beat == "away" else 1.0
			xf = on_train * _blend(stat, roof, k)
			fov = lerpf(STATION_FOV, ROOF_FOV, k)
		_:
			xf = on_train * roof
	if _shake > 0.0:
		xf.origin += Vector3(_rng.randf_range(-1, 1), _rng.randf_range(-1, 1), _rng.randf_range(-1, 1)) * _shake
	camera.global_transform = xf
	camera.fov = fov
	snow.global_position = xf.origin + (-xf.basis.z) * 14.0 + Vector3(0, 4, 0)


## Where the field's camera will look from: over the first of the crew's
## places (by the train's door), at its pitch, as much ground on the screen.
func _down_pose() -> Transform3D:
	var focus := _down_focus()
	var pitch: float = deg_to_rad(FIELD_PITCH_DEG)
	var yaw: float = deg_to_rad(FIELD_YAW_DEG)
	var dist: float = FIELD_VIEW_H * 0.5 / tan(deg_to_rad(DOWN_FOV * 0.5))
	var at := focus + Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch)) * dist
	return Transform3D(Basis(), at).looking_at(focus, Vector3.UP)


func _down_focus() -> Vector3:
	var spots: Array = (data.get("spawns", {}) as Dictionary).get("squad", [])
	if spots.is_empty() or station == null:
		return train_pivot.global_position + Vector3(40, 0, 6)
	return station.to_global(FieldGrid.center(spots[0]))


## The camera over the stop while the card is up (STATION_AT), in the train's frame.
func _station_pose() -> Transform3D:
	var anchor := _station_anchor()
	var dir: Vector3 = anchor - STATION_AT
	var aspect: float = float(port.size.x) / maxf(float(port.size.y), 1.0)
	var half_w: float = tan(deg_to_rad(STATION_FOV * 0.5)) * aspect
	dir = dir.rotated(Vector3.UP, atan((STATION_SCREEN_X * 2.0 - 1.0) * half_w))
	return Transform3D(Basis(), STATION_AT).looking_at(STATION_AT + dir, Vector3.UP)


## The middle of the stop's buildings by the platform, by their ground, in the
## train's frame at its stand; open ground off the train's middle when there are none.
func _station_anchor() -> Vector3:
	if station == null or not data.get("train") is Rect2i:
		return Vector3(TRAIN.size.x * 0.5, 0.0, 14.0)
	var tr: Rect2i = data["train"]
	var sum := Vector3.ZERO
	var weight: float = 0.0
	for b: Dictionary in data.get("buildings", []):
		if not b.get("rect") is Rect2i:
			continue
		var r: Rect2i = b["rect"]
		var c := Vector2(r.position.x + r.size.x * 0.5, r.position.y + r.size.y * 0.5)
		if c.x < tr.position.x - STATION_REACH.x or c.x > tr.end.x + STATION_REACH.x:
			continue
		if c.y < tr.end.y or c.y > tr.end.y + STATION_REACH.y:
			continue
		var w: float = float(r.size.x * r.size.y)
		sum += Vector3(c.x - tr.position.x, 1.5, c.y - tr.position.y) * w
		weight += w
	return sum / weight if weight > 0.0 else Vector3(TRAIN.size.x * 0.5, 0.0, 14.0)


static func _pose(at: Vector3, look: Vector3) -> Transform3D:
	return Transform3D(Basis(), at).looking_at(look, Vector3.UP)


## From a to b, the way bowed up by `lift` metres in the middle.
static func _blend(a: Transform3D, b: Transform3D, k: float, lift: float = 0.0) -> Transform3D:
	var kk: float = clampf(k, 0.0, 1.0)
	var at: Vector3 = a.origin.lerp(b.origin, kk) + Vector3.UP * lift * 4.0 * kk * (1.0 - kk)
	var q: Quaternion = a.basis.get_rotation_quaternion().slerp(b.basis.get_rotation_quaternion(), kk)
	return Transform3D(Basis(q), at)


static func _ease(k: float) -> float:
	var x: float = clampf(k, 0.0, 1.0)
	return x * x * (3.0 - 2.0 * x)


func _update_fx() -> void:
	Smoke.update_locomotive(smoke_run, smoke_idle, absf(speed))
	# Thick along the line, thinner as the place comes up, gone over it.
	var fog: float = _fog_line
	var near_fog: float = _fog_line * FOG_NEAR_K
	if beat == "near":
		fog = lerpf(_fog_line, near_fog, _ease(t / NEAR_S))
	elif beat == "hold" or beat == "brake":
		fog = near_fog
	elif beat == "down":
		fog = lerpf(near_fog, FOG_OVER, _ease(t / DOWN_S))
	elif how == "passed":
		fog = lerpf(near_fog, _fog_line, _ease(t / AWAY_S)) if beat == "away" else _fog_line
	elif beat == "rest" or beat == "out" or beat == "end":
		fog = FOG_OVER
	if _env != null:
		_env.fog_density = fog
	if is_instance_valid(roll_player):
		roll_player.pitch_scale = lerpf(0.8, 1.25, clampf(absf(speed) / RUN_SPEED, 0.0, 1.0))


# ---------------------------------------------------------------- marks

## Bottom right: the arrow that skips (once seen whole), and left of it the
## ring that turns while the field is being made ready. No words (결정 417).
func _draw_marks() -> void:
	var size: Vector2 = marks.size
	var r: float = UiFonts.px(10.0)
	var at := size - Vector2(UiFonts.px(34.0), UiFonts.px(30.0))
	var lamp := Color(FxState.LAMP, 0.9)
	var skippable: bool = seen and (beat in ["rise", "run", "near", "brake", "down", "away"])
	if skippable:
		var w: float = UiFonts.px(2.2)
		for i in 2:
			var o := at + Vector2(UiFonts.px(-5.0 + 9.0 * i), 0)
			marks.draw_polyline(PackedVector2Array([o + Vector2(-r * 0.45, -r * 0.7), o + Vector2(r * 0.35, 0), o + Vector2(-r * 0.45, r * 0.7)]), lamp, w, true)
	var loading: bool = how == "sent" and not ready_to_land and (beat == "down" or beat == "rest" or beat == "brake")
	if loading:
		var c := at - Vector2(UiFonts.px(36.0) if skippable else 0.0, 0)
		var a0: float = fposmod(_spin * 4.0, TAU)
		marks.draw_arc(c, r, a0, a0 + TAU * 0.72, 28, lamp, UiFonts.px(2.4), true)
