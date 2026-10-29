extends Node3D
## The land going by outside the train (결정 495, presentation_motion.md 7b 「열차는 서
## 있고 세상이 흐른다」). The train and its camera stay put; the land flows back along
## the line a piece at a time, from the band's kit (journey_kit.gd) in the order the
## sequencer gives, the sleepers and the telegraph poles beating time; now and then
## one outside event the director picks (journey_director.gd), never begun while a
## decision card is up. Laid along the whole train and MARGIN past each end, so a car
## picked anywhere has land round it; a piece behind is freed and the next laid ahead,
## one a frame. The distance run is kept apart from the nodes' places (rebased), so
## nothing drifts however long it runs. Looks only: it reads the train (its length,
## whether it runs, where its camera looks), the stretch's look and the card state the
## flow hands it, and changes no rule value.
##   var journey := Journey.attach(parent, train_scene, look, seg, {"seed": 1})

## For the sound and the windows (7b 창가의 한마디): an event's kind, where, and its
## moment — "begin" (laid ahead, coming into sight) or "gone" (gone by).
signal journey_event(kind: String, at: Vector3, phase: String)

const Kit = preload("res://game/train/journey/journey_kit.gd")
const Route = preload("res://game/train/journey/journey_route.gd")
const Sequencer = preload("res://game/train/journey/journey_sequencer.gd")
const Director = preload("res://game/train/journey/journey_director.gd")
const Events = preload("res://game/train/journey/journey_events.gd")
const MapView = preload("res://game/world/map_view.gd")

## A switch to turn it off (on by default). It shows on the diagonal train screen only
## (train_scene view_mode "diag", 결정 486): on the side-on one the land in 3D would
## cover the sky, so there it waits unseen and lays nothing.
const SETTING := "visuals/journey_enabled"
## The run (m/s), slower than a train would (7b: an information screen, a fast flow
## pulls the eye), and slow enough that at the train screen's 30 frames a second the
## sleepers move less than half their spacing a frame (they would seem to run back).
const RUN_SPEED: float = 8.0
## From standing to the full run, seconds (a train pulls away slowly).
const ACCEL_S: float = 9.0
const CHUNK_M: float = 120.0
## Land past each end of the train, and laid this much further ahead than that.
const MARGIN: float = 60.0
const AHEAD_M: float = 130.0
## The train screen's frame: the rails' top under the cars (train_scene.gd shells, y −1.44).
const RAIL_Y: float = -1.44
const SLEEPER_STEP: float = 0.65
## Where an event comes into sight: this far ahead of the middle of what the camera shows.
const EVENT_AHEAD: float = 45.0
const SEEN_FILE := "user://journey_seen.cfg"
const REBASE_M: float = 2000.0
## How far past the camera's middle the land may be in sight (the wide diagonal view
## sees about 22 m ahead, 36 m through the pane): a new window's land begins past it.
const SIGHT_M: float = 40.0
## What a frame may spend making the pieces worked out into nodes (Kit.make).
const MAKE_BUDGET_USEC: int = 6000

var host: Node3D                    # the train scene (train_scene.gd)
var look: Dictionary = {}
var seg: int = 1
var band: String = ""
var windows: Array = []
var window_i: int = 0
## A decision card is up (the flow sets it): no new event begins.
var quiet: bool = false
## Outside events off (the reduced-motion setting, tests).
var calm: bool = false
var speed: float = 0.0
var travelled: float = 0.0
var clock: float = 0.0
var seq = Sequencer.new()
var director = Director.new()
var land: Node3D
var track: Node3D
var sleepers: MultiMeshInstance3D
## Pieces laid, oldest first: {node, s0, s1, kind}.
var chunks: Array = []
var laid_to: float = -MARGIN
var events: Array = []
var _base: float = 0.0
var _section: Dictionary = {}
var _section_end: float = -INF
var _chunk_i: int = 0
var _opts: Dictionary = {}
var _seen_cfg: Dictionary = {}
var _filled: bool = false
## Pieces worked out ahead on a worker (journey_kit.gd plan), oldest first:
## {s0, s1, kind, task, box}. laid_to is where those made reach, _planned_to where
## those worked out reach.
var _planned: Array = []
var _planned_to: float = -MARGIN
## The land has reached past the train once since it was first shown: till then it
## stays hidden (train_scene's snow sheet covers, giving way to a Journey shown).
var _shown_once: bool = false
## Work the pieces out here on the main thread as they are needed (o.sync).
var _sync: bool = false
## Workers of pieces let go (a window change) still running: reaped once done, so the
## main thread never waits on them.
var _stale: Array = []


static func enabled() -> bool:
	return bool(ProjectSettings.get_setting(SETTING, true))


## Hang the land beside the train scene `train_scene` under `parent`, for stretch
## `stretch` in the stretch's `l` look. o: seed (int), band (else the season table's),
## remember (keep what was seen over runs, default true), view ("diag" stands in for
## the train's view_mode: tools, tests), running (stands in for the train's), sync
## (the pieces worked out on the main thread: the tools' before).
static func attach(parent: Node, train_scene: Node3D, l: Dictionary, stretch: int, o: Dictionary = {}) -> Node3D:
	var j = load("res://game/train/journey/journey.gd").new()
	j.host = train_scene
	j.look = l
	j.seg = stretch
	j._opts = o
	parent.add_child(j)
	return j


func _ready() -> void:
	name = "Journey"
	position = Vector3(0, float(_opts.get("rail_y", RAIL_Y)), 0)
	band = String(_opts.get("band", Route.band_of_seg(seg)))
	windows = Route.windows(seg, band)
	var seed_value: int = int(_opts.get("seed", 1))
	seq.setup(hash([seed_value, seg, "land"]))
	if bool(_opts.get("remember", true)):
		_seen_cfg = _load_seen()
	director.setup(hash([seed_value, seg, "events"]), _seen_cfg)
	_sync = bool(_opts.get("sync", false))
	land = Node3D.new()
	land.name = "Land"
	add_child(land)
	_build_track()
	speed = RUN_SPEED if _running() else 0.0
	visible = false


func _process(delta: float) -> void:
	# The kit's models are read a model a frame from when the land is hung, seen or not
	# (one can take 90 ms): the first diagonal view then does not read them all at once.
	if not Kit.warm_step(MAKE_BUDGET_USEC):
		visible = false
		return
	if not shown():
		visible = false
		return
	if not _filled:
		_fill()
	if not _shown_once:
		# First shown: the pieces are being worked out; the land shows once it reaches
		# past the train, never half laid (worked out again if a window change let them go).
		_plan_to(_front())
		_make_planned(MAKE_BUDGET_USEC)
		if laid_to < travelled + _train_length() + MARGIN:
			visible = false
			return
		_shown_once = true
	visible = true
	step(minf(delta, 0.1))


## Whether the train's screen is the diagonal one (train_scene view_mode; str(), as a
## train scene without it gives null and String(null) is no call).
func shown() -> bool:
	if _opts.has("view"):
		return str(_opts["view"]) == "diag"
	return host != null and str(host.get("view_mode")) == "diag"


## The land as far as the train and past it, worked out at once (on workers, side by
## side) and made as each is done. The kit's models are read first, here.
func _fill() -> void:
	_filled = true
	Kit.warm()
	_plan_to(_front())


## One tick (the tests call it straight).
func step(delta: float) -> void:
	if not _filled:
		_fill()
	var target: float = RUN_SPEED if _running() else 0.0
	speed = move_toward(speed, target, RUN_SPEED * delta / ACCEL_S)
	travelled += speed * delta
	if speed > 0.5:
		clock += delta
	if travelled - _base > REBASE_M:
		_rebase()
	land.position.x = _base - travelled
	sleepers.position.x = -fposmod(travelled, SLEEPER_STEP)
	_plan_to(_front())
	_make_planned(MAKE_BUDGET_USEC)
	_reap()
	# Never short of land past the train: wait for the next piece worked out (at the run
	# speed AHEAD_M is worked out well before it is needed; a test stepping straight
	# through waits here).
	while laid_to < travelled + _train_length() + MARGIN and not _planned.is_empty():
		_make_next(true)
	while not chunks.is_empty() and float(chunks[0]["s1"]) - travelled < -MARGIN - CHUNK_M:
		(chunks[0]["node"] as Node3D).queue_free()
		chunks.pop_front()
	_step_events(delta)


## The next window of the stretch's land (7b: a decision card or a session ended).
## What is in sight stays; the pieces laid ahead out of sight go and the section under
## way ends there, so the new window's land (a border field's bare one) begins past
## the view, a piece at most later (the pieces go back in one a frame).
func next_window() -> void:
	if window_i + 1 >= windows.size():
		return
	window_i += 1
	if not _filled:
		return
	_drop_planned()
	var keep_to: float = travelled + _cam_x() + SIGHT_M
	while chunks.size() > 1 and float(chunks[-1]["s0"]) >= keep_to:
		var c: Dictionary = chunks.pop_back()
		(c["node"] as Node3D).queue_free()
		laid_to = float(c["s0"])
	_planned_to = laid_to
	_section_end = laid_to


func window() -> Dictionary:
	return windows[clampi(window_i, 0, windows.size() - 1)] if not windows.is_empty() else {"band": band, "neutral": false}


## What the stop scene needs to lay the same land on the way in (stop_cinema.gd
## _lay_corridor): the band, the window, where the order stands, the section being
## laid and what is left of it (its next piece), the look. {} when none was laid (the
## side-on screen): the stop scene then goes by the stretch.
func handoff() -> Dictionary:
	# Asked before the land was first laid (a stop straight after the diagonal view came
	# up): laid now, at once; the stop's own turn covers it.
	if not _filled and shown():
		_fill()
	if not _filled:
		return {}
	return {"band": band, "window": window().duplicate(), "seed": hash([int(_opts.get("seed", 1)), seg, "corridor"]),
		"history": seq.history.duplicate(true), "at": _planned_to / RUN_SPEED, "look": look,
		"section": _section.duplicate(), "section_left_m": maxf(_section_end - _planned_to, 0.0), "chunk": _chunk_i}


## The kind of land at route metre `s` ("" none laid there).
func kind_at(s: float) -> String:
	for c: Dictionary in chunks:
		if s >= float(c["s0"]) and s < float(c["s1"]):
			return String(c["kind"])
	for p: Dictionary in _planned:
		if s >= float(p["s0"]) and s < float(p["s1"]):
			return String(p["kind"])
	return String(_section.get("kind", ""))


func _running() -> bool:
	if _opts.has("running"):
		return bool(_opts["running"])
	return host != null and host.has_method("running") and bool(host.call("running"))


func _train_length() -> float:
	return float(host.call("train_length")) if host != null and host.has_method("train_length") else 80.0


func _cam_x() -> float:
	if host != null and host.get("cam_x") != null:
		return float(host.get("cam_x"))
	return _train_length() * 0.5


func _front() -> float:
	return travelled + _train_length() + MARGIN + AHEAD_M


func _plan_to(to: float) -> void:
	while _planned_to < to:
		_plan_one()


## The next piece's place, kind and dressing, chosen here in order (so the land is the
## same however the workers keep time), worked out on a worker.
func _plan_one() -> void:
	if _planned_to >= _section_end:
		_next_section()
	var s0: float = _planned_to
	var s1: float = minf(s0 + CHUNK_M, _section_end)
	if _section_end - s1 < CHUNK_M * 0.35:
		s1 = _section_end
	var w: Dictionary = window()
	var kind: String = String(_section.get("kind", "plain"))
	# The worker reads copies of its own (the host may change its look meanwhile).
	var args: Array = [kind, s0, s1, _section.duplicate(true), look.duplicate(true), {"ground": true, "neutral": bool(w.get("neutral", false)), "chunk": _chunk_i}]
	var box: Dictionary = {}
	var task: int = -1
	if _sync:
		_plan_off_thread(box, args)
	else:
		task = WorkerThreadPool.add_task(_plan_off_thread.bind(box, args), false, "journey piece")
	_planned.append({"s0": s0, "s1": s1, "kind": kind, "task": task, "box": box})
	_planned_to = s1
	_chunk_i += 1


## On the worker: the piece as data (journey_kit.gd plan), nothing in the scene tree.
static func _plan_off_thread(box: Dictionary, args: Array) -> void:
	box["plan"] = Kit.plan(String(args[0]), float(args[1]), float(args[2]), args[3], args[4], args[5])


## The pieces worked out, made and laid in order while `budget_usec` lasts.
func _make_planned(budget_usec: int) -> void:
	var from: int = Time.get_ticks_usec()
	while not _planned.is_empty() and Time.get_ticks_usec() - from < budget_usec:
		if not _make_next(false):
			return


## The oldest piece worked out, made and laid; `wait`: till its worker is done.
func _make_next(wait: bool) -> bool:
	var p: Dictionary = _planned[0]
	var task: int = int(p["task"])
	if task >= 0:
		if not wait and not WorkerThreadPool.is_task_completed(task):
			return false
		WorkerThreadPool.wait_for_task_completion(task)
	_planned.pop_front()
	var node: Node3D = Kit.make(p["box"]["plan"])
	node.position.x = float(p["s0"]) - _base
	land.add_child(node)
	chunks.append({"node": node, "s0": p["s0"], "s1": p["s1"], "kind": p["kind"]})
	laid_to = float(p["s1"])
	return true


## The pieces worked out and not laid yet go; what is planned starts again where the
## land laid ends. Their workers still running are reaped later (_reap).
func _drop_planned() -> void:
	for p: Dictionary in _planned:
		if int(p["task"]) >= 0:
			_stale.append(int(p["task"]))
	_planned.clear()
	_planned_to = laid_to
	_reap()


func _reap() -> void:
	for task: int in _stale.duplicate():
		if WorkerThreadPool.is_task_completed(task):
			WorkerThreadPool.wait_for_task_completion(task)
			_stale.erase(task)


func _exit_tree() -> void:
	# A worker still on a piece finishes before the land goes.
	_drop_planned()
	for task: int in _stale:
		WorkerThreadPool.wait_for_task_completion(task)
	_stale.clear()


func _next_section() -> void:
	var kinds: Array = Route.kinds(window())
	if kinds.is_empty():
		_section = {"kind": "plain", "len_s": 60.0, "seed": 0, "mirror": false}
	else:
		_section = seq.next(_planned_to / RUN_SPEED, kinds)
	if not bool(_section.get("extend", false)):
		_chunk_i = 0
	_section_end = _planned_to + float(_section["len_s"]) * RUN_SPEED


func _rebase() -> void:
	var by: float = floorf((travelled - _base) / REBASE_M) * REBASE_M
	_base += by
	for c: Dictionary in chunks:
		(c["node"] as Node3D).position.x -= by
	for e in events:
		(e as Node3D).position.x -= by


## The line under the cars: sleepers that slide back a sleeper at a time and come
## round again (no new nodes), and the rails.
func _build_track() -> void:
	track = Node3D.new()
	track.name = "Track"
	add_child(track)
	var from: float = -MARGIN - 12.0
	var to: float = _train_length() + MARGIN + 12.0
	var count: int = int((to - from) / SLEEPER_STEP)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	MapView.box(st, Vector3(0.24, 0.1, 2.5), Vector3.ZERO, Color(0.23, 0.2, 0.18))
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = st.commit()
	mm.instance_count = count
	for i in count:
		mm.set_instance_transform(i, Transform3D(Basis(), Vector3(from + i * SLEEPER_STEP, -0.15, 0.0)))
	sleepers = MultiMeshInstance3D.new()
	sleepers.name = "Sleepers"
	sleepers.multimesh = mm
	sleepers.material_override = _plain_material()
	sleepers.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	track.add_child(sleepers)
	var rails := SurfaceTool.new()
	rails.begin(Mesh.PRIMITIVE_TRIANGLES)
	for z: float in [-0.72, 0.72]:
		MapView.box(rails, Vector3(to - from, 0.13, 0.08), Vector3((from + to) * 0.5, -0.065, z), Color(0.27, 0.26, 0.26))
	var rail_node := MeshInstance3D.new()
	rail_node.name = "Rails"
	rail_node.mesh = rails.commit()
	rail_node.material_override = _plain_material(0.55)
	rail_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	track.add_child(rail_node)


static func _plain_material(rough: float = 1.0) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.vertex_color_is_srgb = true
	mat.roughness = rough
	return mat


# ---------------------------------------------------------------- events

func _step_events(delta: float) -> void:
	for e in events.duplicate():
		var actor: Node3D = e
		actor.call("advance", delta, travelled)
		if bool(actor.call("is_done")):
			journey_event.emit(String(actor.get_meta("journey_id", "")), actor.global_position, "gone")
			events.erase(actor)
			actor.queue_free()
			director.finished(clock)
	director.watch(clock, quiet or calm)
	if speed < 0.5:
		return
	var ahead: float = travelled + _cam_x() + EVENT_AHEAD
	var w: Dictionary = window()
	var started: Dictionary = director.tick(clock, quiet or calm, kind_at(ahead), String(look.get("band", "day")),
		_weather_word(), bool(w.get("neutral", false)), not events.is_empty())
	if started.is_empty():
		return
	if _begin_event(started, ahead) == null:
		director.finished(clock)
		return
	_note_seen()


## For the shots tool: event `id` in `variant` now, whatever the director says.
func force_event(id: String, variant: String) -> Node3D:
	var ahead: float = travelled + _cam_x() + EVENT_AHEAD
	return _begin_event({"id": id, "variant": variant, "kind": kind_at(ahead)}, ahead)


func _begin_event(ev: Dictionary, ahead: float) -> Node3D:
	var actor: Node3D = Events.make(String(ev["id"]))
	if actor == null:
		return null
	land.add_child(actor)
	actor.set_meta("journey_id", String(ev["id"]))
	actor.position = Vector3(ahead - _base, 0.0, 0.0)
	actor.call("begin", self, ev, hash([int(_opts.get("seed", 1)), seg, director.started.size(), events.size()]))
	events.append(actor)
	journey_event.emit(String(ev["id"]), actor.global_position, "begin")
	return actor


func _weather_word() -> String:
	if bool(look.get("storm", false)):
		return "blizzard"
	var kinds: Array = look.get("kinds", [])
	return String(kinds[0]) if not kinds.is_empty() else "overcast"


func _load_seen() -> Dictionary:
	var cfg := ConfigFile.new()
	var out: Dictionary = {}
	if cfg.load(SEEN_FILE) != OK:
		return out
	if not cfg.has_section("seen"):
		return out
	for key: String in cfg.get_section_keys("seen"):
		out[key] = int(cfg.get_value("seen", key, 0))
	return out


func _note_seen() -> void:
	if not bool(_opts.get("remember", true)):
		return
	var cfg := ConfigFile.new()
	cfg.load(SEEN_FILE)
	for key: String in director.seen:
		cfg.set_value("seen", key, int(director.seen[key]))
	cfg.save(SEEN_FILE)
