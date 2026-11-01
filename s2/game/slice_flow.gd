extends Node
## The vertical slice end to end (밤 계획 2026-10-18 「밤에 할 것」 3, 결정 402): the
## train → choosing the stop → the field → the return receipt → the special
## session → the train → the second station → the end card, one after another
## from the boot screen. The train is the real inside (train.tscn) at the phase
## each step names; the field is the real stop. The screens that are not built
## yet are plain panels over them that read what there is (the field's own
## receipt, or the sample one when the field is skipped), and PR 3 swaps them
## for the real ones in turn. It sets no game value.
##
## The slice plays on one board of its own (J01): S1's new game (the asset
## game/train/slice_start.json, made by s1/tools/slice_vectors.ts), run by the
## train's turn as S1 runs it (train_advance.gd) to the first stop; the stop's
## departure contract goes out with the field, the field's receipt comes back onto
## that board once (field_return.gd, which also closes the stop), the special
## session opens on what came back (field_council.gd, the card council_card.gd over
## the dining car), and the train runs on to the second station (field_arrival.gd:
## its sheet arrival_sheet.gd, the end end_card.gd). Different finds, rescues and
## losses on the same people make a different session or station
## (tests/train/test_slice_vectors.gd against S1). It reads no test fixture. The
## train's paper cards come up on the train steps one at a time (turn_card.gd), and
## the train does not go on before each is chosen (the user 10-27: 「열차 단계에
## 서류가 오면 한 장씩 띄우고, 고르기 전엔 다음으로 못 가게 해」). A step gone to
## straight (the tests do) plays what lies before it on the board first, taking each
## paper on its first way that can be taken, as S1's slice does (slice_vectors.ts
## pickFirst, field_arrival.test.ts).
##
## The slice holds that one train state; the gauges, the car pane and the stop
## card all read it. On the train the carriages
## wear name plates; a car with people of its own is picked by its plate and
## its pane frosts in at the right with the camera moving it into the clear
## part; its levers set that state through train_turn.gd set_lever.

const FieldGame = preload("res://game/field_game.gd")
const FieldClock = preload("res://game/sim/field_clock.gd")
const TrainRules = preload("res://game/train/train_rules.gd")
const RouteBands = preload("res://game/train/route_bands.gd")
const RouteStops = preload("res://game/train/route_stops.gd")
const CampaignRoute = preload("res://game/train/campaign_route.gd")
const RouteState = preload("res://game/train/route_state.gd")
const StopForm = preload("res://game/sim/stop_form.gd")
const UiTheme = preload("res://game/ui/ui_theme.gd")
const UiFonts = preload("res://game/ui/ui_fonts.gd")
const LampKey = preload("res://game/ui/lamp_key.gd")
const ReceiptSheet = preload("res://game/ui/receipt_sheet.gd")
const ArrivalSheet = preload("res://game/ui/arrival_sheet.gd")
const EndCard = preload("res://game/ui/end_card.gd")
const WorldIntro = preload("res://game/ui/world_intro.gd")
const FieldArrival = preload("res://game/politics/field_arrival.gd")
const TurnCard = preload("res://game/ui/turn_card.gd")
const UiDeny = preload("res://game/ui/ui_deny.gd")
const ScreenLift = preload("res://game/ui/screen_lift.gd")
const StopPickCard = preload("res://game/ui/stop_pick_card.gd")
const CouncilCard = preload("res://game/ui/council_card.gd")
const TrainGauges = preload("res://game/ui/train_gauges.gd")
const CarPane = preload("res://game/ui/car_pane.gd")
const DecorPane = preload("res://game/ui/decor_pane.gd")
const DecorUiData = preload("res://game/ui/decor_ui_data.gd")
const CostPane = preload("res://game/ui/cost_pane.gd")
const HomeBar = preload("res://game/ui/home_bar.gd")
const GlassParts = preload("res://game/ui/glass_parts.gd")
const WorldWeather = preload("res://game/ui/world_weather.gd")
const WorldFilm = preload("res://game/ui/world_film.gd")
const Atmosphere = preload("res://fx/atmosphere.gd")
const SeasonTable = preload("res://game/season_table.gd")
const TrainStop = preload("res://game/train/train_stop.gd")
const OutsideView = preload("res://fx/outside_view.gd")
const St = preload("res://game/train/train_state.gd")
const TrainDom = preload("res://game/train/train_dom.gd")
const TrainDecor = preload("res://game/train/train_decor.gd")
const TrainTurn = preload("res://game/train/train_turn.gd")
const TrainWorkshop = preload("res://game/train/train_workshop.gd")
const WorkshopPane = preload("res://game/ui/workshop_pane.gd")
const ModsPane = preload("res://game/ui/mods_pane.gd")
const ResearchPane = preload("res://game/ui/research_pane.gd")
const StopCinema = preload("res://game/stop_cinema.gd")
const FieldDeparture = preload("res://game/politics/field_departure.gd")
const FieldSave = preload("res://game/sim/field_save.gd")
const FieldReceipt = preload("res://game/sim/receipt.gd")
const SliceSave = preload("res://game/sim/slice_save.gd")
const TrainSave = preload("res://game/politics/save_slot.gd")
const FieldMaps = preload("res://game/world/field_maps.gd")
const StopLoader = preload("res://game/stop_loader.gd")
const Journey = preload("res://game/train/journey/journey.gd")
const Corridor = preload("res://game/train/journey/journey_corridor.gd")
const PaperMotion = preload("res://game/ui/paper_motion.gd")
const FieldHud = preload("res://game/ui/field_hud.gd")
const STOP_CINEMA_SCENE := preload("res://scenes/stop_cinema.tscn")
const TRAIN_SCENE := preload("res://game/train/train.tscn")
const EDGE_BOT := preload("res://game/ui/tex/edge_bot.png")
## The frost grown in from the screen's corners over the world (시안 .w-frost,
## its left and right halves; the middle is clear).
const FROST_L := preload("res://game/ui/tex/frost_l.png")
const FROST_R := preload("res://game/ui/tex/frost_r.png")
const BOOT_SCENE := "res://scenes/boot.tscn"
## The slice's board: S1's new game and S1's tables (s1/tools/slice_vectors.ts).
const START := "res://game/train/slice_start.json"
const TrainAdvance = preload("res://game/train/train_advance.gd")
const FieldReturn = preload("res://game/politics/field_return.gd")
const FieldCouncil = preload("res://game/politics/field_council.gd")
const CouncilAgenda = preload("res://game/politics/council_agenda.gd")
const DecorGrid = preload("res://game/train/decor_grid.gd")
## The stretch the slice's train first runs (S1's slice: field_arrival.test.ts).
const FIRST_SEG: int = 2
## Steps the train may take from the session to the second station before the slice gives up.
const RUN_LIMIT: int = 12
## Where the car pane's words start in from its left (car_pane.gd), and the paper's room short of them.
const PANE_WORDS_X: float = 44.0
const PAPER_GAP: float = 6.0
## The train's people left to stand by it while the field is out (stop-cam's train defense).
const GUARDS_LEFT: int = 2

## The steps in order: [id, the train's phase behind the panel ("" for none),
## the stretch it is on, the panel's title, the next key's word]. The stretch is
## the scenery's (the weather and the act's progress outside); the board's own
## stretch is train_g["seg"].
const STEPS: Array = [
	["train", "travel", 1, "열차 · 1구간", "정차 고르기"],
	["stop_pick", "stop", 2, "정차 고르기", "내리기"],
	["field", "", 2, "", ""],
	["receipt", "settle", 2, "귀환 영수증", "특별 회기"],
	["council", "council", 2, "특별 회기", "출발"],
	["travel", "travel", 2, "열차 · 2구간", "다음 역"],
	["arrive", "stop", 3, "둘째 역 도착", "끝 카드"],
	["end", "end", 3, "끝", "처음으로"],
]

## Keep the existing card; its choices reach the board before the app can leave.
class SavedCouncil extends CouncilCard:
	signal board_changed(state: Dictionary)

	func _ready() -> void:
		idx = int(g["council"].get("idx", 0))
		if g["council"].get("result") is Dictionary:
			result = g["council"]["result"].duplicate(true)
			voted = g
		super._ready()
		if not result.is_empty():
			board.play(result)
			board.finish_reveal()
			_set_shade(SHADE_AFTER)
			bill.modulate = Color(0.8, 0.79, 0.77, 0.5)
			bar.set_main("확인", "", true)
			_fill_bill()
			_fill_pane()

	func turn(direction: int) -> void:
		var before: int = idx
		super.turn(direction)
		if idx != before:
			g = g.duplicate(true)
			g["council"]["idx"] = idx
			board_changed.emit(g)

	func _make(tool_id: String, cond_index: int, cut_target: String) -> void:
		super._make(tool_id, cond_index, cut_target)
		board_changed.emit(g)

	func cast() -> void:
		var was_cast: bool = not result.is_empty()
		super.cast()
		if not was_cast and not voted.is_empty():
			board_changed.emit(voted)


const PANEL_W: float = 560.0
## A failed write, said where the player looks; the home keys' note holds it as the
## field's warn note does (field_hud.gd TOAST_WARN_S).
const SAVE_FAILED: String = "저장하지 못했다. 다음 저장 때 다시 해 본다."
const SAVE_NOTE_S: float = 6.0
## What stays lit in the gauges while a step's sheet is up (the stop and what it
## brought back are about stock; the session about what a vote moves,
## k3c_views.js vCouncil TOP hot).
const FOCUS: Dictionary = {"stop_pick": ["coal", "food", "med", "lux"], "receipt": ["coal", "food", "med", "lux"], "council": ["trust", "mood", "food", "lux"],
		"arrive": ["trust", "tension", "coal", "food", "med", "lux"]}
## The steps whose sheet comes in from the left over the bottom edge: no soot there.
const SHEET_STEPS: Array = ["stop_pick", "receipt", "arrive"]
## The steps that are the train itself: its pane and its keys over it.
const HOME_STEPS: Array = ["train", "travel"]
## The car picked when the train comes up (시안 01: the tail's first car).
const FIRST_CAR := "tail1"
## The picked car sits in the middle of what the pane leaves clear: 159 mockup
## px left of the screen's middle (k3_views.js vHome, 844 − 318 over two).
const PANE_SHIFT_CSS: float = 159.0
const PLATE_TAP_SLOP: float = 12.0       # viewport px, even while the plate moves
## Metres of the dining car's floor and roof's surroundings kept in view behind
## the special session.
const COUNCIL_ROOM_MARGIN: float = 0.35
## The picked car's corners (c1.css .car.is-sel::before): 20 long, 2 thick, lamp amber.
const SEL_ARM: float = 20.0
const SEL_COLOR := Color("ffc66c")
## Cars not picked darken (.train.has-sel .car:not(.is-sel), brightness .5).
const UNPICKED_SHADE: float = 0.42
## 디자인 토큰 2차: the smoked glass of a pane (B1) and its words.
const PANE := Color(8 / 255.0, 11 / 255.0, 15 / 255.0, 0.84)
const INK := Color("eee9dc")
const INK2 := Color(238 / 255.0, 233 / 255.0, 220 / 255.0, 0.7)

var opts: Dictionary = {}          # skip_field: true goes past the field with the sample receipt;
                                   # still: true holds the snow and the fog (screens for checks);
                                   # cinema: false puts the stop card straight up (no roof, no look down);
                                   # cinema_seen: as if the stop scene had been seen whole (taps skip);
                                   # map_threads: false builds the stop's map at once (tests)
var step: int = -1
var stage: Node = null             # what is up behind the panel: the train or the field
var train: Node3D = null
var field: Node3D = null
var result: Dictionary = {}        # the field's result, when the field was played
var receipt: Dictionary = {}       # the receipt the receipt panel reads
var council_g: Dictionary = {}     # the state the special session was left in
var arrival_g: Dictionary = {}     # the second station's state, the board run on from the session
var passed: bool = false           # the stop passed by: no field, no return
var port_error: String = ""        # a step of the train's turn not ported yet (train_advance.gd), shown, not hidden
var last_rules: Dictionary = {}    # the rules the train was last shown with (its people react to the change)
var theme: Theme
var layer: CanvasLayer
var panel: PanelContainer
var title: Label
var lines: VBoxContainer
var next_button: Button             # the main key (lamp_key.gd), its arrow drawn by itself
var panel_style: StyleBoxFlat
var card: Control = null           # a real screen standing in for the panel (stop_pick)
var paper: Control = null          # the train's paper card up now (turn_card.gd), one at a time
var going: bool = false            # the main key was pulled: on with the train once the papers are chosen
var gauges: Control                # the train's gauges along the top, over the train
var soot_bot: TextureRect          # the soot rising from the bottom edge under the keys
var weather: Control               # the snow, the fog and the drift over the train (world_weather.gd)
var frost: Control                 # the corners' frost over the train (.w-frost)
var film: Control                  # the dark edges and the grain over the frost (world_film.gd)
var plates: Control                # the carriages' name plates, where the train's cars are
var marks: Control                 # the picked car's corners and the other cars' shade
var train_g: Dictionary = {}       # the slice's train state (its own board)
var train_t: Dictionary = {}       # its tables
var home: Control = null           # the train's own screen on the train steps: pane and keys
var pane: Control = null           # the picked car's pane (car_pane.gd)
var bar: Control = null            # the keys along the bottom (home_bar.gd)
var sel: String = ""               # the picked car's id, "" with the pane folded
var decor_id: String = ""          # the car being decorated (open_decor), "" when none
var decor_pane: Control = null
var _decor_hidden: Array = []      # what open_decor put away, to bring back
var _plate_press_id: String = ""
var _plate_press_pos: Vector2 = Vector2.ZERO
var _plate_pointer: int = -1         # mouse, or the touch index
var _plate_dragged: bool = false
var shop: Control = null           # the workshop's pane where the car's stands (workshop_pane.gd)
var shop_was: String = ""          # the car picked before the workshop or the refit pane came up
var mods: Control = null           # the refit pane, where the workshop's stands (mods_pane.gd)
var research: Control = null       # the research pane, where the workshop's stands (research_pane.gd)
var cost: Control = null           # what a stretch costs and why, where the rooms stand (cost_pane.gd)
var shop_seg: int = -1             # the stretch the workshop last worked (once each leaving)
var outside: MeshInstance3D = null  # the world outside the train (fx/outside_view.gd)
## The land going by outside the train (결정 495, journey/journey.gd): shown on the
## diagonal view only (train_scene view_mode); visuals/journey_enabled turns it off.
var journey: Node3D = null
## The stop seen from the train (결정 421-3): the scene from the roof to the
## look down (stop_cinema.gd), the field made ready under it (stop_loader.gd),
## and that field, built and standing still, till the field step shows it.
var cinema: Node = null
var loader: Node
var pending_field: Node = null
var field_resume: Dictionary = {}
var pending_shop_events: Array = []
var save_error: String = ""
## A failed write is told once a step where the player looks (the field's warn note, the
## home keys' note, the panel's lines); the next save point tries again and clears it.
## With no place to tell it, the error waits for one of those screens to stand.
var save_told_at: int = -1
var save_line: Label = null
var save_note: Label = null
var save_hud: FieldHud = null
var run: String = ""
var campaign_error: String = ""
var _campaign_map: Dictionary = {}


## The same arrival sheet when the previous stop had no return (442).
class PassedArrival extends ArrivalSheet:
	func _ready() -> void:
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		var arrival_paper = PaperSheet.new()
		arrival_paper.name = "Sheet"
		arrival_paper.position = SHEET_AT * UiFonts.K
		sheet = arrival_paper
		add_child(arrival_paper)
		body = VBoxContainer.new()
		body.name = "Body"
		body.add_theme_constant_override("separation", 0)
		body.mouse_filter = Control.MOUSE_FILTER_IGNORE
		body.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		arrival_paper.inner.add_child(body)
		var display_g: Dictionary = g.duplicate(true)
		var now: Dictionary = FieldReturn.snapshot(display_g, t)
		var stocks: Array = []
		for pair: Array in STOCKS:
			stocks.append([String(pair[1]), whole(now[pair[0]]), ""])
		_head({"title": "둘째 역"})
		var arrive_words: Control = _runs("구벤에 닿았다. 이전 정차는 지나쳤다.", 18.0)
		arrive_words.name = "Arrive"
		body.add_child(arrive_words)
		body.add_child(_rule())
		_columns([["사람", [["귀환 없음", "", ""]]], ["물자", stocks], ["온기", [["정차를 지나쳤다.", "", ""]]]])
		body.add_child(_rule())
		_seen([])
		var bottom_room: Control = Control.new()
		bottom_room.size_flags_vertical = Control.SIZE_EXPAND_FILL
		bottom_room.mouse_filter = Control.MOUSE_FILTER_IGNORE
		body.add_child(bottom_room)
		_keys()
		_build_slip({"open": false, "line": "특별 회기를 열지 않았다."})


func _ready() -> void:
	theme = UiTheme.make(22)
	theme.default_font = UiFonts.face(UiFonts.WORD, 400)
	layer = CanvasLayer.new()
	layer.layer = 40
	add_child(layer)
	var s: Array = _starting_board()
	train_t = s[1]
	if (s[0] as Dictionary).is_empty() or train_t.is_empty():
		campaign_error = "F-CAMPAIGN-START: invalid start board"
		_build_panel()
		_show_panel("캠페인을 열 수 없다", [campaign_error], "처음으로")
		return
	var resume: Dictionary = opts.get("resume", {})
	var start_step: String = "train"
	if resume.is_empty():
		# A run id only where slots are written: a play without saves stays as it was.
		if bool(opts.get("save", false)):
			run = Crypto.new().generate_random_bytes(8).hex_encode()
		train_g = to_travel(s[0], train_t)
		if _is_campaign():
			run = String(opts.get("run", run))
			if run.is_empty():
				run = Crypto.new().generate_random_bytes(8).hex_encode()
			train_g = RouteState.start(train_g, run)
		if bool(opts.get("save", false)) and not train_g.is_empty():
			_clear_slice_field()
	else:
		run = String(resume["run"])
		train_g = (resume["g"] as Dictionary).duplicate(true)
		contract = (resume.get("contract", {}) as Dictionary).duplicate(true)
		receipt = (resume.get("receipt", {}) as Dictionary).duplicate(true)
		passed = bool(resume.get("passed", false))
		if not receipt.is_empty():
			result = result_of(receipt)
			result["reason"] = String(resume.get("result_reason", result["reason"]))
		start_step = String(resume["step"])
		if _is_campaign():
			var issue: String = RouteState.problem(train_g, train_t)
			if issue != "":
				campaign_error = issue
				_build_panel()
				_show_panel("캠페인을 열 수 없다", [issue], "처음으로")
				return
			run = String(train_g["campaign"]["run"])
			contract = train_g["campaign"]["visit"].get("contract", {}).duplicate(true)
			passed = train_g["campaign"]["visit"].get("result") == "passed"
			var board_receipt: Dictionary = SliceSave.receipt_of_board(train_g)
			if board_receipt.is_empty():
				receipt = {}
				result = {}
			else:
				if not RouteState.owns_receipt(train_g, receipt) or FieldReturn.canonical(receipt) != FieldReturn.canonical(board_receipt):
					receipt = board_receipt
				result = result_of(receipt)
			start_step = SliceSave.resume_step(train_g, start_step)
		if not _returned() and not passed and start_step in ["stop_pick", "field"]:
			var saved: Dictionary = FieldSave.read(String(opts.get("field_save_path", FieldSave.PATH)))
			var order: Dictionary = saved["departure"] if saved.get("departure") is Dictionary else {}
			var start_opts: Dictionary = saved["start_opts"] if saved.get("start_opts") is Dictionary else {}
			var belongs: bool = bool(start_opts.get("slice", false)) \
				and start_opts.get("slice_run") == run \
				and int(order.get("segment", -1)) == int(train_g["seg"]) \
				and (contract.is_empty() or order.get("departureId") == contract.get("departureId"))
			if _is_campaign():
				belongs = SliceSave.field_belongs(train_g, saved)
			if belongs and FieldSave.should_resume(saved, SliceSave.applied_ids(train_g)):
				field_resume = FieldSave.resume_opts(saved)
				contract = order.duplicate(true)
				start_step = "field"
			else:
				start_step = SliceSave.step_of_board(train_g)
				# The field writes its end before handing the return to the train.
				if belongs and saved.get("phase") == "ended":
					var ended: Dictionary = SliceSave.receipt_of_field(saved)
					if FieldReceipt.check(ended).is_empty() and FieldReturn.check_departure(order, train_t).is_empty() and FieldReturn.match_departure(order, ended).is_empty():
						contract = order.duplicate(true)
						_apply_return(ended)
						if not _is_campaign() or _returned():
							start_step = "receipt"
		if _index_of(start_step) >= _index_of("travel"):
			shop_seg = int(STEPS[_index_of("travel")][2])
	# The train's stores, so what the field brings home has somewhere to go:
	# a new run's starting scrap, wood and parts (S1's), or what a state carries.
	if train_g.get("dom") == null:
		train_g["dom"] = TrainDom.start()
	TrainDom.ensure(train_g)
	# S1's load defaults are already present before the first save.
	TrainSave.fill_defaults(train_g)
	marks = Control.new()
	marks.name = "Marks"
	marks.mouse_filter = Control.MOUSE_FILTER_IGNORE
	marks.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	marks.draw.connect(_draw_marks)
	layer.add_child(marks)
	plates = Control.new()
	plates.name = "Plates"
	plates.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plates.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(plates)
	# Over the train as the mockup stacks its world (k3_views.js world): the
	# drift, the fog and the snow, then the frost, then the dark edges and the
	# grain, and the keys over it all.
	weather = WorldWeather.new()
	weather.name = "Weather"
	weather.still = bool(opts.get("still", false))
	layer.add_child(weather)
	frost = Control.new()
	frost.name = "Frost"
	frost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frost.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	frost.add_child(_sheet(FROST_L, 0.0, 0.5))
	frost.add_child(_sheet(FROST_R, 0.5, 1.0))
	layer.add_child(frost)
	film = WorldFilm.new()
	film.name = "Film"
	layer.add_child(film)
	# The soot the keys stand on at the bottom edge (.edge--bot, 104 high; the
	# gauges bring their own at the top).
	soot_bot = _sheet(EDGE_BOT, 0.0, 1.0)
	soot_bot.anchor_top = 1.0
	soot_bot.offset_top = -UiFonts.px(104.0)
	layer.add_child(soot_bot)
	# The train's gauges read the slice's state, as the pane and the stop card do.
	gauges = TrainGauges.new()
	gauges.g = train_g
	gauges.t = train_t
	gauges.stock_pressed.connect(_open_cost)
	layer.add_child(gauges)
	_build_panel()
	loader = StopLoader.new()
	loader.name = "StopLoader"
	loader.threaded = bool(opts.get("map_threads", true))
	loader.failed.connect(_campaign_fail)
	add_child(loader)
	go(_index_of(start_step))
	if bool(opts.get("intro", false)):
		_show_intro()


## New runs only: an overlay that leaves the flow and saves as they are.
func _show_intro() -> void:
	var intro: WorldIntro = WorldIntro.new()
	intro.name = "WorldIntro"
	intro.still = bool(opts.get("still", false))
	layer.add_child(intro)


## The step now ("train", "field", …).
func current() -> String:
	return String(STEPS[step][0]) if step >= 0 else ""


func go(i: int) -> void:
	if _is_campaign():
		if i < 0 or i >= STEPS.size() or not _campaign_can_go(String(STEPS[i][0])):
			_campaign_fail("F-CAMPAIGN-TRANSITION")
			return
		if STEPS[i][0] in ["stop_pick", "field"]:
			var issue: String = _campaign_map_problem()
			if issue != "":
				_campaign_fail(issue)
				return
		if STEPS[i][0] == "field" and not is_instance_valid(pending_field):
			_campaign_map = (opts["map_data"] as Dictionary).duplicate(true) if opts.get("map_data") is Dictionary else FieldMaps.build(_field_place())
			var issue: String = CampaignRoute.map_problem(RouteState.current_stop(train_g), _campaign_map)
			if issue != "":
				_campaign_map = {}
				_campaign_fail(issue)
				return
		campaign_error = ""
	_show_step(i)
	_save_slice()


func _show_step(i: int) -> void:
	if decor_id != "":
		leave_decor()
	step = i
	var id: String = STEPS[i][0]
	_ensure_board(id)
	# The train's own screen stays a moment under the stop scene as it comes in.
	if id == "stop_pick" and _cinema_on():
		_let_stage_go(StopCinema.FADE_S)
	_clear_stage()
	_drop_cinema(id)
	if is_instance_valid(card):
		card.queue_free()
	card = null
	_drop_paper()
	going = false
	home = null
	pane = null
	bar = null
	shop = null
	mods = null
	sel = ""
	var row: Array = STEPS[i]
	# Over the train, not over the field; the slice's state, but the session's
	# own in the special session.
	gauges.visible = String(row[1]) != ""
	gauges.g = train_g
	gauges.t = train_t
	gauges.set_focus(FOCUS.get(id, []))
	# The world outside over the train, but not in the special session: there
	# the dining car is the room behind it (vCouncil: the back and its dark only).
	frost.visible = String(row[1]) != "" and id != "council"
	weather.visible = frost.visible
	film.visible = frost.visible
	# The train runs between the stops; at a stop the snow falls straight down
	# and the drift lies still (.world.run, .world.is-stop).
	weather.moving = String(row[1]) == "travel" and train_halt_line(train_g) == ""
	soot_bot.visible = gauges.visible and not SHEET_STEPS.has(id)
	if train_halt_line(train_g) != "":
		_show_train("end" if train_g.get("phase") == "end" else "travel", int(train_g.get("seg", row[2])))
		_show_panel("끝" if id == "end" else train_halt_title(train_g), load("res://game/train/turn/turn_end.gd").panel_lines(train_g, train_t, train_halt_line(train_g)), "처음으로" if id == "end" else "끝")
		return
	# The next stop is known on the train: its map is made ready off the main
	# thread while the train runs.
	if id == "train" and _cinema_on():
		_prepare_stop()
	if id == "stop_pick" and _cinema_on():
		_show_stop_cinema()
		return
	if id == "field":
		panel.visible = false
		if not _is_campaign() and bool(opts.get("skip_field", false)) and field_resume.is_empty():
			_field_done({})
		else:
			_start_field()
		return
	# Leaving a stop the technologies take their upkeep and the workshop does a
	# stretch's work, once (train_workshop.gd stretch).
	var shop_events: Array = pending_shop_events
	pending_shop_events = []
	if not _is_campaign() and id == "travel" and int(row[2]) != shop_seg:
		shop_seg = int(row[2])
		shop_events = TrainWorkshop.stretch(train_g)["events"]
	if String(row[1]) != "":
		_show_train(String(row[1]), int(train_g["seg"]) if _is_campaign() else int(row[2]))
		# What it made, for the people on the train to see (the train scene's events).
		if is_instance_valid(train) and train.has_method("post_event"):
			for ev: Dictionary in shop_events:
				train.call("post_event", ev)
	if id == "receipt":
		_show_receipt("여기까지" if _is_campaign() and int(train_g["campaign"]["cursor"]) == CampaignRoute.size() - 1 else String(row[4]))
		return
	if id == "stop_pick":
		_show_stop_pick()
		return
	if id == "council":
		_show_council()
		return
	if id == "arrive":
		_show_arrival("다음" if _is_campaign() else String(row[4]))
		return
	if id == "end":
		if _is_campaign():
			_show_panel("여기까지 — 다음 정차는 아직", [], "처음으로")
		else:
			_show_end(String(row[4]))
		return
	if HOME_STEPS.has(id):
		_show_home(String(row[4]))
		_show_paper()
		return
	_show_panel(String(row[3]), [], String(row[4]))


func next() -> void:
	if step < 0:
		get_tree().change_scene_to_file(BOOT_SCENE)
		return
	if _is_campaign():
		_campaign_next()
		return
	leave_decor()
	if train_halt_line(train_g) != "" and current() != "end":
		go(_index_of("end"))
		return
	if step + 1 >= STEPS.size():
		get_tree().change_scene_to_file(BOOT_SCENE)
		return
	go(step + 1)


## Choosing the stop: the paper card over the train at its stop. The first
## stop is Sulechów, a freight siding; the numbers are the train sample's.
func _show_stop_pick() -> void:
	panel.visible = false
	var c = StopPickCard.new()
	c.g = train_g.duplicate(true)
	c.t = train_t
	if c.g.get("stop") is Dictionary:
		c.g["stop"]["place"] = String(RouteState.current_stop(train_g)["kind"]) if _is_campaign() else "freight"
	c.stop_name = String(RouteState.current_stop(train_g)["name"]) if _is_campaign() else "술레후프"
	c.g["seg"] = int(RouteState.current_stop(train_g)["number"]) if _is_campaign() else int(STEPS[step][2])
	c.top_room = TrainGauges.BAND_H
	c.promises = _departure().get("promises", [])
	c.squad = _departure().get("roster", [])
	c.sent.connect(func(_g: Dictionary) -> void: _send_crew())
	c.passed_by.connect(_pass_stop)
	layer.add_child(c)
	card = c
	# The paper comes up folded and opens out, not all at once (사용자 2026-10-24).
	if c.sheet != null:
		PaperMotion.open(c.sheet, _seen_before())


# ---------------------------------------------------------------- the stop seen from the train

func _cinema_on() -> bool:
	return bool(opts.get("cinema", true))


## The place of the slice's field (FieldMaps; "" is its default, Sulechów).
func _field_place() -> String:
	if _is_campaign():
		return String(RouteState.current_stop(train_g).get("map", ""))
	return String(opts.get("place", ""))


## The first leg's stop the slice is at on stretch `seg` (decision 494). The field's map, when
## it is a stop's own map (the first stop's, which the slice plays on FIRST_SEG), is that
## stop, and the stops after it count on from there; any other map takes the stretch's stop.
func _stop_of(seg: int) -> int:
	if _is_campaign():
		return int(_campaign_scene_stop().get("number", CampaignRoute.size()))
	var own: Array = RouteBands.place_stop(FieldMaps.resolve(_field_place()))
	return seg if own.is_empty() else int(own[1]) + seg - FIRST_SEG


## That stop's band.
func _stop_band(seg: int) -> String:
	if _is_campaign():
		return String(_campaign_scene_stop().get("band", "K3"))
	return RouteBands.stop_band("prologue", _stop_of(seg))


## That stop's form (stop_form.gd): one asked of the slice (opts "stop_form", a check switch),
## else the route's; "" leaves it to the place.
func _stop_form(seg: int) -> String:
	if _is_campaign():
		return String(RouteState.current_stop(train_g).get("form", ""))
	if opts.has("stop_form"):
		return String(opts["stop_form"])
	return StopForm.on_route("prologue", _stop_of(seg))


## The stretch of the slice's field step: the map made ready while the train runs is its stop's.
static func _field_seg() -> int:
	for row: Array in STEPS:
		if row[0] == "field":
			return int(row[2])
	return FIRST_SEG


## The campaign's current stretch, or the slice's fixed field stretch.
func _current_field_seg() -> int:
	return int(train_g.get("seg", FIRST_SEG)) if _is_campaign() else _field_seg()


## The season table's stretch that stop stands on (route_stops.gd): the stop's weather and
## cold, not those of the table's row with the stretch's number. Before the first stop (the
## train setting out on the first stretch) it is the table's first stretch, the start.
func _season_seg(seg: int) -> int:
	var stop := _stop_of(seg)
	return 1 if stop < 1 else RouteStops.season_seg(stop)


## 「정차 고르기」: the roof of the running train, not the card at once. The
## card comes up with the station behind it (card_time).
func _show_stop_cinema() -> void:
	panel.visible = false
	gauges.visible = false
	soot_bot.visible = false
	for p in plates.get_children():
		plates.remove_child(p)
		p.queue_free()
	_prepare_stop()
	# Its own scene (scenes/stop_cinema.tscn), so the train and the weather can be dressed there.
	var c = STOP_CINEMA_SCENE.instantiate()
	c.name = "StopCinema"
	c.seen = bool(opts.get("cinema_seen", StopCinema.was_seen()))
	c.remember = not opts.has("cinema_seen")
	# The weather the field will open with, worn by the scene over it.
	c.stop_opts = _field_opts()
	# The same land on the way in as went by on the train's screen (결정 495 4절).
	c.corridor_kit = Corridor.make(journey.handoff() if is_instance_valid(journey) else {}, maxi(1, int(STEPS[step][2]) - 1), int(opts.get("seed", 1)))
	if loader.has_data():
		c.data = loader.data
	else:
		var wanted_visit: String = String(train_g["campaign"]["visit"].get("id", "")) if _is_campaign() else ""
		loader.data_ready.connect(func() -> void:
			if is_instance_valid(c):
				if _is_campaign() and (loader.visit_for != wanted_visit or not loader.error.is_empty()):
					return
				c.set_map(loader.data), CONNECT_ONE_SHOT)
	c.card_time.connect(_on_card_time)
	c.done.connect(_on_cinema_done)
	add_child(c)
	cinema = c


## The station is in sight and the train slows: the stop card over it, the
## gauges over the card as before.
func _on_card_time() -> void:
	gauges.visible = true
	gauges.set_focus(FOCUS.get("stop_pick", []))
	_show_stop_pick()


## Sent: the brakes and the look down, the field built under it meanwhile.
## Without the stop scene the field comes at once, as it did.
func _send_crew() -> void:
	if _is_campaign() and _campaign_map_problem() != "":
		_campaign_fail(_campaign_map_problem())
		return
	if not is_instance_valid(cinema):
		next()
		return
	_drop_card()
	cinema.send()
	if not _is_campaign() and bool(opts.get("skip_field", false)):
		cinema.land()
		return
	loader.field_built.connect(_on_field_built, CONNECT_ONE_SHOT)
	loader.build_field(self, _field_opts())


## Passed by: the train picks up speed and its own screen comes back.
func _pass_stop() -> void:
	if _is_campaign():
		if current() != "stop_pick" or train_g["campaign"]["visit"].get("result") != "open":
			_campaign_fail("F-CAMPAIGN-TRANSITION: pass")
			return
		var out: Dictionary = TrainAdvance.resolve_stop(train_g, train_t, false)
		_take(RouteState.mark_passed(out))
		passed = true
		if int(train_g["campaign"]["cursor"]) == CampaignRoute.size() - 1:
			_take(RouteState.activate_next_stop(train_g))
			go(_index_of("end"))
		elif not is_instance_valid(cinema):
			go(_index_of("travel"))
		else:
			_drop_card()
			cinema.pass_by()
		return
	if not passed and not _returned():
		passed = true
		_take(TrainAdvance.resolve_stop(train_g, train_t, false))
	if not is_instance_valid(cinema):
		go(_index_of("travel"))
		return
	_drop_card()
	cinema.pass_by()


func _on_field_built(f: Node) -> void:
	if _is_campaign() and (not SliceSave.field_opts_belong(train_g, f.opts) or CampaignRoute.map_problem(RouteState.current_stop(train_g), f.data) != ""):
		f.queue_free()
		_campaign_fail("F-CAMPAIGN-MAP: stale field")
		return
	pending_field = f
	loader.field = null
	if is_instance_valid(cinema):
		cinema.land()


## The stop scene's end: over the stop (the field step takes the field built
## under it) or back on the line.
func _on_cinema_done(how: String) -> void:
	if how == "sent":
		go(_index_of("field"))
	else:
		go(_index_of("travel"))


func _drop_card() -> void:
	var c: Control = card if is_instance_valid(card) else null
	card = null
	gauges.visible = false
	if c == null:
		return
	# Folded away under the finger that sent it; nothing on it answers any more.
	c.propagate_call("set", ["mouse_filter", Control.MOUSE_FILTER_IGNORE])
	var paper: Variant = c.get("sheet")
	if paper is Control:
		PaperMotion.close(paper, _seen_before()).finished.connect(c.queue_free)
	else:
		c.queue_free()


## The stop scene seen whole before: its paper comes and goes in half the time.
func _seen_before() -> bool:
	return bool(opts.get("cinema_seen", StopCinema.was_seen()))


## Leaving a step: the stop scene goes unless it is already fading out over
## the next one, and a field made ready for a stop not played goes too.
func _drop_cinema(id: String) -> void:
	if is_instance_valid(cinema) and not (cinema.beat == "out" or cinema.beat == "end"):
		cinema.queue_free()
	if not is_instance_valid(cinema) or cinema.is_queued_for_deletion():
		cinema = null
	if id != "field" and is_instance_valid(pending_field):
		pending_field.queue_free()
		pending_field = null
	if id != "field" and id != "stop_pick":
		loader.abandon()


## The stage behind goes after `seconds`, not now (the next screen fades in over it).
func _let_stage_go(seconds: float) -> void:
	if not is_instance_valid(stage):
		return
	leave_decor()
	var old: Node = stage
	stage = null
	train = null
	field = null
	# Bound to the node itself: gone first (the slice left), the call goes with it.
	get_tree().create_timer(seconds + 0.05).timeout.connect(old.queue_free)


## The special session: the session card over the dining car, off the session
## the port's sample opens with the slice's departure and receipt; the gauges
## read that state (its tables joined with the train's, which they also read).
## Closed, it goes on to the next stretch.
func _show_council() -> void:
	panel.visible = false
	for l in lines.get_children():
		lines.remove_child(l)
		l.queue_free()
	if not _open_session():
		_show_panel(String(STEPS[step][3]), [_why_no_session()], String(STEPS[step][4]))
		return
	_frame_dining_car()
	gauges.refresh(train_g, train_t)
	var c = SavedCouncil.new()
	c.name = "CouncilCard"
	c.g = train_g
	c.t = train_t
	c.board_changed.connect(_take)
	c.left.connect(func(g1: Dictionary) -> void:
		council_g = g1
		_take(g1)
		next())
	layer.add_child(c)
	card = c


## The second station: the stop's sheet saying what the train came to since the
## first stop, the session's slip beside it, over the train at the stop; the
## gauges read the station's state.
func _show_arrival(go_word: String) -> void:
	panel.visible = false
	if not FieldArrival.second_station_reached(train_g):
		_show_panel(String(STEPS[step][3]), [_why_no_station()], go_word)
		return
	arrival_g = train_g
	gauges.refresh(arrival_g, train_t)
	var c: ArrivalSheet = PassedArrival.new() if _is_campaign() and passed else ArrivalSheet.new()
	c.name = "ArrivalSheet"
	c.g = arrival_g
	c.t = train_t
	c.go_word = go_word
	c.went_on.connect(next)
	layer.add_child(c)
	card = c


## The end: the slice finished at the second station (field_arrival.gd
## finish_slice) and the port's end card on the long sheet over the train.
func _show_end(go_word: String) -> void:
	panel.visible = false
	if train_halt_line(train_g) != "":
		_show_panel("끝", load("res://game/train/turn/turn_end.gd").panel_lines(train_g, train_t, train_halt_line(train_g)), go_word)
		return
	if arrival_g.is_empty() and FieldArrival.second_station_reached(train_g):
		arrival_g = train_g
	if arrival_g.is_empty():
		var stopped: Dictionary = train_g.duplicate(true)
		stopped["phase"] = "end"
		stopped["end"] = "slice"
		_take(stopped)
		_show_panel(String(STEPS[step][3]), [_why_no_station()], go_word)
		return
	var done: Dictionary = FieldArrival.finish_slice(arrival_g, train_t)
	var g_end: Dictionary = done["g"]
	_take(g_end)
	gauges.refresh(g_end, train_t)
	var c = EndCard.new()
	c.name = "EndCard"
	c.g = g_end
	c.t = train_t
	c.go_word = go_word
	c.still = bool(opts.get("still", false))
	c.went_on.connect(next)
	layer.add_child(c)
	card = c


## The room behind the session as the mockup draws it (k3c_views.js
## councilBack: the dining car large, its inside from floor to roof filling the
## screen): the train's camera on the dining car, close, its middle at the
## car's middle height. The session card takes the screen's touches, so
## nothing moves the camera off it.
func _frame_dining_car() -> void:
	# The council keeps the section view.
	if not is_instance_valid(train) or train.camera == null:
		return
	for c: Dictionary in train.cars:
		if String((c.get("def", {}) as Dictionary).get("kind", "")) == "dining":
			train.focus_car(String(c["id"]))
			var consts: Dictionary = train.get_script().get_script_constant_map()
			var height: float = float(consts.get("CAR_HEIGHT", 3.0))
			var cam: Camera3D = train.camera
			cam.size = height + 2.0 * COUNCIL_ROOM_MARGIN
			cam.position.y += height * 0.5 - float(consts.get("CAM_LOOK_Y", -0.3))
			return


# ---------------------------------------------------------------- the slice's board

## [state, tables]: S1's new game for the slice and S1's tables (the asset START).
static func start_board() -> Array:
	if not FileAccess.file_exists(START):
		push_error("slice: no start board at " + START)
		return [{}, {}]
	var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(START))
	if not d is Dictionary or not d.get("state") is Dictionary or not d.get("tables") is Dictionary:
		push_error("slice: the start board does not read")
		return [{}, {}]
	d["state"]["lateOn"] = true
	d["state"]["eventPack"] = true
	return [d["state"], d["tables"]]


## One step of the train's turn as a step gone to straight takes it: the papers before and
## after taken on their first way (pick_first), the turn as S1 runs it. An unported step
## comes back with its _turn_port_error.
## A stopped train or a real S1 ending holds this slice without advancing the rules.
static func train_halt_line(g: Dictionary) -> String:
	if g.get("phase") == "end" and g.get("end") != "slice": return TrainTurn.end_text(g, str(g.get("end", "")))
	if g.get("stranded") != null: return TrainTurn.END_TEXT["stranded"]
	return ""


## The halt panel's head, in train_halt_line's order: a real S1 ending names
## itself as the S1 end screen does, a stopped train says it stopped.
static func train_halt_title(g: Dictionary) -> String:
	if g.get("phase") == "end" and g.get("end") != "slice": return str(TrainTurn.END_TITLE.get(str(g.get("end", "")), "끝"))
	if g.get("stranded") != null: return "열차가 멈췄다"
	return ""


static func step_train(g0: Dictionary, t: Dictionary) -> Dictionary:
	if train_halt_line(g0) != "": return g0.duplicate(true)
	var g: Dictionary = pick_first(g0.duplicate(true), t)
	if g.has("_turn_port_error") or train_halt_line(g) != "":
		return g
	var out: Dictionary = TrainAdvance.advance(g, t)
	if out.has("_turn_port_error") or train_halt_line(out) != "":
		return out
	return pick_first(out, t)


## The papers as S1's slice takes them (slice_vectors.ts pickFirst): from the front, one
## by one, each on its first way that can be taken (train_advance.gd choose_card leaves
## a card it refuses where it was), a card with none put aside. A kind the port does not
## take yet is said and put aside too, so the board never stops on a paper.
static func pick_first(g0: Dictionary, t: Dictionary) -> Dictionary:
	var g: Dictionary = g0
	for n in 50:
		if not papers_of(g) or g.has("_turn_port_error") or train_halt_line(g) != "":
			break
		var uid: int = int((g["cards"] as Array)[0]["uid"])
		var taken := false
		for i in 12:
			var out: Dictionary = TrainAdvance.choose_card(g, t, uid, i)
			if out.has("_turn_port_error"):
				push_warning("slice: paper put aside, " + String(out["_turn_port_error"]))
				break
			if not _holds(out, uid):
				g = out
				taken = true
				break
		if not taken:
			g = g.duplicate(true)
			g["cards"] = (g["cards"] as Array).filter(func(c: Dictionary) -> bool: return int(c["uid"]) != uid)
	return g


## Whether a board has papers waiting.
static func papers_of(g: Dictionary) -> bool:
	return g.get("cards") is Array and not (g["cards"] as Array).is_empty()


static func _holds(g: Dictionary, uid: int) -> bool:
	for c: Dictionary in g.get("cards", []):
		if int(c["uid"]) == uid:
			return true
	return false


## The new game on its first run: the slice starts on FIRST_SEG and takes one step. The
## papers it brings stay on the board: the train step shows them first.
static func to_travel(state: Dictionary, t: Dictionary) -> Dictionary:
	var g: Dictionary = state.duplicate(true)
	if g.is_empty() or train_halt_line(g) != "":
		return g
	g["seg"] = FIRST_SEG
	g = pick_first(g, t)
	if g.has("_turn_port_error"):
		return g
	return TrainAdvance.advance(g, t)


## The first paper waiting, over the train on its steps (turn_card.gd); none when none waits.
func _show_paper() -> void:
	_drop_paper()
	if train_halt_line(train_g) != "" or not papers_of(train_g) or not HOME_STEPS.has(current()):
		return
	var c = TurnCard.new()
	c.name = "Paper"
	# On a narrow screen the paper stops short of the car pane's words (44 in from its
	# edge), so the car's numbers stay in sight while a way is chosen.
	if is_instance_valid(pane):
		var screen: float = get_viewport().get_visible_rect().size.x / UiFonts.K
		c.fit_w = screen - CarPane.CSS_SIZE.x + PANE_WORDS_X - PAPER_GAP - TurnCard.SHEET_AT.x
	layer.add_child(c)
	c.show_card(train_g, train_t, int((train_g["cards"] as Array)[0]["uid"]))
	c.chose.connect(_paper_chosen)
	c.fold_changed.connect(_paper_folded)
	paper = c
	_update_decor_lock()


func _drop_paper() -> void:
	var was_folded: bool = is_instance_valid(paper) and (paper as TurnCard).folded
	if is_instance_valid(paper):
		paper.queue_free()
	paper = null
	_update_decor_lock()
	# The room its edge took goes back to the picked car.
	if was_folded:
		_paper_folded(false)


## The paper folded to its edge or opened again (결정 508): the picked car moves into
## the middle of what the edge and the car pane leave clear.
func _paper_folded(_folded: bool) -> void:
	_update_decor_lock()
	if sel == "" or not is_instance_valid(pane) or not is_instance_valid(train) or train.camera == null:
		return
	if str(train.get("view_mode")) == "diag":
		_set_cover()


func _update_decor_lock() -> void:
	if decor_id != "" and (DecorUiData.lock_reason(train_g, false) != "" or (is_instance_valid(paper) and not (paper as TurnCard).folded)):
		leave_decor()
	if is_instance_valid(pane):
		pane.choosing_paper = is_instance_valid(paper) and not (paper as TurnCard).folded
		pane.refresh(train_g, train_t)


## The diagonal camera's cover: the car pane's width at the right, a folded paper's
## edge at the left.
func _set_cover() -> void:
	var pane_rect: Rect2 = pane.get_global_rect()
	var covered_px: float = get_viewport().get_visible_rect().size.x - pane_rect.position.x
	if pane_rect.size.x == 0.0:
		covered_px = CarPane.CSS_SIZE.x * UiFonts.K
	if not pane.visible:
		covered_px = 0.0
	var left_px: float = 0.0
	if is_instance_valid(paper) and (paper as TurnCard).folded:
		left_px = (paper as TurnCard).folded_edge()
	train.set_pane(covered_px, left_px)


## A way chosen on the paper: the board it gives back, then the next paper, and once
## none waits the train goes on if the main key was pulled. A way the port does not
## take yet is said and its card put aside, so the slice goes on.
func _paper_chosen(g: Dictionary) -> void:
	# 7b 「키트가 바뀌는 때」: a card done, the land outside moves on to its next window.
	if is_instance_valid(journey):
		journey.next_window()
	if g.has("_turn_port_error"):
		push_warning("slice: paper put aside, " + String(g["_turn_port_error"]))
		var uid: int = int((train_g["cards"] as Array)[0]["uid"])
		var rest: Dictionary = train_g.duplicate(true)
		rest["cards"] = (rest["cards"] as Array).filter(func(c: Dictionary) -> bool: return int(c["uid"]) != uid)
		_take(rest)
	else:
		_take(g)
	if train_halt_line(train_g) != "":
		_show_step(step)
		return
	_show_paper()
	if going and not papers_of(train_g):
		going = false
		train_on()


## The main key on the train steps: with papers waiting it goes nowhere (the paper
## shakes); else the board runs to where the next step stands (to the stop, or on to
## the second station), stopping at each paper that comes, and the step goes on.
func train_on() -> void:
	if train_halt_line(train_g) != "":
		_show_step(step)
		return
	if _is_campaign():
		_campaign_train_on()
		return
	if papers_of(train_g):
		going = true
		if is_instance_valid(paper):
			# A folded paper comes open: it is what holds the train.
			(paper as TurnCard).set_folded(false)
			UiDeny.shake(paper)
		return
	var id := current()
	for i in RUN_LIMIT:
		if port_error != "" or String(train_g.get("phase", "")) == "end":
			break
		if id == "train" and String(train_g.get("phase", "")) != "travel":
			break
		if id == "travel" and (not _returned() or FieldArrival.second_station_reached(train_g)):
			break
		if id != "train" and id != "travel":
			break
		_take(TrainAdvance.advance(train_g, train_t))
		if train_halt_line(train_g) != "":
			_show_step(step)
			return
		if papers_of(train_g):
			going = true
			_show_paper()
			return
	next()


## The slice's first stop: the run, then the train standing at the stop, not yet resolved.
static func first_stop(state: Dictionary, t: Dictionary) -> Dictionary:
	return step_train(to_travel(state, t), t)


## The receipt of a stop played without anything found (the field skipped): the contract's
## searchers go and all come back, nothing gained or lost, the promises unseen.
static func quiet_receipt(d: Dictionary) -> Dictionary:
	var sent: Array = []
	var crew: Array = []
	for p: Dictionary in d.get("roster", []):
		sent.append(p["id"])
		crew.append({"person": p["id"], "exhaustion": 0, "hunger": 0, "bodyUse": {}, "gearBack": {"hands": (p["gear"]["hands"] as Array).duplicate(true), "items": {}}})
	var promises: Array = []
	for p: Dictionary in d.get("promises", []):
		promises.append({"id": p["id"], "kind": p["kind"], "witnesses": []})
	return {
		"version": 5, "receiptId": "ret_%s_%d_quiet" % [d["placeId"], int(d["segment"])], "departureId": d["departureId"], "stopId": d["stopId"],
		"source": "direct", "endReason": "departed",
		"place": {"id": d["placeId"], "type": "freight", "variant": "s2_graybox"},
		"time": {"arrive": "D1 10:30", "depart": "D1 12:30", "stayGameMinutes": 120},
		"stock": {}, "items": {"gained": [], "lost": []},
		"people": {"sent": sent, "injured": [], "bitten": [], "dead": [], "missing": [], "leftBehind": [], "rescued": [], "wounds": []},
		"witnessed": [], "placeState": {"looted": 0.0, "remainingRisk": 0}, "promises": [],
		"goal": {"kind": null, "required": 0, "earned": 0, "status": "retreat"},
		"extras": {"documents": [], "symbolCount": 0, "fragments": [], "coreCount": 0},
		"symbol": null, "fieldPromises": promises, "crew": crew, "defense": null,
	}


## The board moves on: a step the port does not have yet is said, and the board stays.
func _take(g: Dictionary) -> void:
	if g.has("_turn_port_error"):
		port_error = String(g["_turn_port_error"])
		push_error("slice: " + port_error)
		return
	leave_decor()
	if _is_campaign():
		var next_g: Dictionary = g
		if RouteState.is_campaign(next_g) and next_g["campaign"]["visit"].is_empty() and next_g.get("phase") == "stop":
			next_g = RouteState.enter_stop(next_g, int(next_g["seg"]))
		var issue: String = RouteState.problem(next_g, train_t)
		if issue != "":
			_campaign_fail(issue)
			return
		train_g = next_g
		if SliceSave.step_of_board(train_g) == "travel":
			var departure_id: String = String(train_g["campaign"]["visit"].get("departure_id", ""))
			if RouteState.workshop_due(train_g, departure_id):
				pending_shop_events = TrainWorkshop.stretch(train_g)["events"]
				train_g = RouteState.mark_workshop(train_g, departure_id)
		if is_instance_valid(gauges):
			gauges.g = train_g
		_save_slice()
		return
	var leaving: bool = SliceSave.step_of_board(g) == "travel" and SliceSave.step_of_board(train_g) != "travel"
	train_g = g
	# Departure and workshop work share one train write, including a closed vote.
	if leaving and train_halt_line(train_g) == "" and shop_seg != int(STEPS[_index_of("travel")][2]):
		shop_seg = int(STEPS[_index_of("travel")][2])
		pending_shop_events = TrainWorkshop.stretch(train_g)["events"]
	if is_instance_valid(gauges):
		gauges.g = train_g
	_save_slice()


## The field owns its slot. These notifications only write the two train-side slots.
func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_WM_CLOSE_REQUEST:
		_save_slice()


func _save_slice() -> bool:
	if not bool(opts.get("save", false)) or train_g.is_empty() or step < 0:
		return true
	var train_path := String(opts.get("train_save_path", TrainSave.DEFAULT_PATH))
	var written: Dictionary = {}
	if not SliceSave.write_train(train_g, train_path, written):
		_save_failed("F-SAVE-TRAIN")
		return false
	var slice_path := String(opts.get("slice_save_path", SliceSave.PATH))
	if current() == "end" and not _is_campaign():
		SliceSave.clear(slice_path)
		_clear_slice_field()
	else:
		var saved: Dictionary = SliceSave.capture(self)
		saved["train_sha"] = written["train_sha"]
		if not SliceSave.write(saved, slice_path):
			_save_failed("F-SAVE-SLICE")
			return false
	save_error = ""
	save_told_at = -1
	if is_instance_valid(save_note):
		save_note.hide()
		save_note.queue_free()
	save_note = null
	if is_instance_valid(save_hud):
		save_hud.drop_warning(SAVE_FAILED)
	save_hud = null
	if is_instance_valid(save_line):
		save_line.hide()
		save_line.queue_free()
	save_line = null
	return true


## Play goes on over a failed write (the old slots stay whole); the player is told, and the
## next save point (a step, a board change, the app put away) writes again.
func _save_failed(code: String) -> void:
	save_error = code
	push_warning("slice: could not save (%s), the next save point tries again" % code)
	# Told once the step's screen is up: a board change saved while a step is being built
	# would say it on the keys that step is taking away.
	_tell_save_error.call_deferred()


func _tell_save_error() -> void:
	if save_error == "" or save_told_at == step:
		return
	var hud: Variant = field.get("hud") if current() == "field" and is_instance_valid(field) else null
	if hud is FieldHud and is_instance_valid(hud):
		var target := hud as FieldHud
		if not is_instance_valid(target.toast_box):
			return
		target.toast(SAVE_FAILED, FieldHud.TOAST_WARN)
		save_hud = target
	elif is_instance_valid(bar) and bar.is_visible_in_tree():
		save_note = (bar as HomeBar).note(SAVE_FAILED, null, SAVE_NOTE_S)
		if not is_instance_valid(save_note):
			return
	elif is_instance_valid(panel) and panel.is_visible_in_tree():
		_add_save_line()
	else:
		return
	save_told_at = step


func _add_save_line() -> void:
	if is_instance_valid(save_line):
		return
	save_line = UiFonts.label(SAVE_FAILED, UiFonts.WORD, 400, 13.0, INK2)
	save_line.name = "SaveFailed"
	save_line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	save_line.custom_minimum_size.x = PANEL_W - UiFonts.px(28.0)
	lines.add_child(save_line)
	_pin()


func _clear_slice_field() -> void:
	var path := String(opts.get("field_save_path", FieldSave.PATH))
	var saved: Dictionary = FieldSave.read(path)
	var start_opts: Dictionary = saved["start_opts"] if saved.get("start_opts") is Dictionary else {}
	if start_opts.get("slice") == true and (not _is_campaign() or start_opts.get("slice_run") == run):
		FieldSave.clear(path)


func _returned() -> bool:
	if _is_campaign():
		return RouteState.returned_for_current_stop(train_g)
	return train_g.get("fieldReturns") is Dictionary and not (train_g["fieldReturns"]["records"] as Array).is_empty()


## The board up to the step `id` stands on, played once in order: the stop reached, the
## stop's return, the session sat and left, the run to the second station.
func _ensure_board(id: String) -> void:
	if train_halt_line(train_g) != "": return
	if _is_campaign():
		return
	var at: int = _index_of(id)
	if at >= _index_of("stop_pick") and not _returned() and not passed and String(train_g.get("phase", "")) == "travel" and port_error == "":
		_take(step_train(train_g, train_t))
	if train_halt_line(train_g) != "": return
	if at >= _index_of("receipt") and not _returned() and not passed and id != "field":
		_apply_return(quiet_receipt(_departure()))
	if train_halt_line(train_g) != "": return
	if at >= _index_of("travel") and _returned():
		_leave_session()
	if train_halt_line(train_g) != "": return
	if at >= _index_of("arrive"):
		_run_to_station()


## The field's receipt onto the board, once (field_return.gd: the stop closes with it).
func _apply_return(r: Dictionary) -> bool:
	if _is_campaign():
		return _campaign_apply_return(r)
	if _returned() or r.is_empty():
		return false
	var out: Dictionary = FieldReturn.apply_field_return(train_g, train_t, _departure(), r)
	receipt = r.duplicate(true)
	if result.is_empty():
		result = result_of(receipt)
	_take(out["g"])
	_after_return(train_g)
	return true


## Right after a return comes onto the board. 내정 훅 자리: the hands' share for a train
## with its domestic side on (domestic PR 638, TrainHands.settle) goes here; on the S1a
## board the turn's own settle (turn/turn_settle_care.gd hands_settle) already shares the hands.
func _after_return(_g: Dictionary) -> void:
	pass


## The special session the return opens, opened on the board; false when it opens none.
func _open_session() -> bool:
	if _is_campaign() and int(train_g["campaign"]["cursor"]) != 0:
		return false
	if not _returned():
		return false
	if String(train_g.get("phase", "")) == "council" and (train_g.get("council", {}) as Dictionary).get("special", false):
		return true
	var regular: Dictionary = CouncilAgenda.agenda_options(train_g, train_t)
	var stepped: Dictionary = FieldCouncil.next_field_step(train_g, train_t, regular["options"])
	if _is_campaign() and stepped["step"] == "choose_symbol":
		# The first return uses the same default as the field slice table.
		var chosen: Dictionary = FieldReturn.choose_symbol_use(stepped["g"], train_t, String(train_g["campaign"]["visit"]["receipt_id"]), "hang_before_session")
		if not bool(chosen["accepted"]):
			_campaign_fail("F-CAMPAIGN-SYMBOL")
			return false
		_take(chosen["g"])
		regular = CouncilAgenda.agenda_options(train_g, train_t)
		stepped = FieldCouncil.next_field_step(train_g, train_t, regular["options"])
	_take(stepped["g"])
	return String(stepped["step"]) == "council"


## A session still sitting when the slice goes on: its first agenda voted and the session
## left (as the card does with its keys), so the train can run on.
func _leave_session() -> void:
	var special: Variant = (train_g.get("fieldReturns", {}) as Dictionary).get("special")
	if _is_campaign():
		if special is Dictionary and special.get("receiptId") == train_g["campaign"]["visit"].get("receipt_id") and train_g.get("phase") == "council" and (train_g.get("council", {}) as Dictionary).get("result") is Dictionary:
			var left: Dictionary = FieldCouncil.leave_special_council(train_g, train_t)
			if bool(left["left"]):
				council_g = left["g"]
				_take(left["g"])
		return
	if special is Dictionary and special.get("status") == "opened" and String(train_g.get("phase", "")) == "council":
		if not (train_g.get("council", {}) as Dictionary).get("result") is Dictionary:
			_take(TrainAdvance.cast_vote(train_g, train_t))
		var left: Dictionary = FieldCouncil.leave_special_council(train_g, train_t)
		if bool(left["left"]):
			council_g = left["g"]
			_take(left["g"])
	elif not special is Dictionary and _open_session():
		_leave_session()


## The train runs on from the session to the second station. A stop passed by has no
## return to carry there: the slice ends at it (its arrival and end panels say so).
func _run_to_station() -> void:
	if _is_campaign():
		return
	if not _returned():
		return
	for i in RUN_LIMIT:
		if train_halt_line(train_g) != "" or FieldArrival.second_station_reached(train_g) or String(train_g.get("phase", "")) == "end" or port_error != "":
			return
		_take(step_train(train_g, train_t))


func _why_no_session() -> String:
	if port_error != "":
		return "열차 턴 이식 밖: " + port_error
	return "필드에 나가지 않아 특별 회기가 열리지 않았다." if passed else "특별 회기가 열리지 않았다."


func _why_no_station() -> String:
	if port_error != "":
		return "열차 턴 이식 밖: " + port_error
	return "필드에 나가지 않아 둘째 역의 귀환 기록이 없다." if passed else "둘째 역에 닿지 못했다."


## The train's people who stay by it while the field is out: the guard car's own,
## not in the contract, the first GUARDS_LEFT of them (stop-cam's train defense).
func _guard_ids(d: Dictionary) -> Array:
	var out: Array = []
	var going: Array = []
	for p: Dictionary in FieldDeparture.people_of(d):
		going.append(p["id"])
	for id: String in FieldDeparture.companion_candidates(train_g, train_t, "guard"):
		if not going.has(id) and out.size() < GUARDS_LEFT:
			out.append(id)
	return out


## A picture laid over the screen from `x0` to `x1` of its width, top to bottom.
func _sheet(tex: Texture2D, x0: float, x1: float) -> TextureRect:
	var r := TextureRect.new()
	r.texture = tex
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_SCALE
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.anchor_left = x0
	r.anchor_right = x1
	r.anchor_top = 0.0
	r.anchor_bottom = 1.0
	return r


func _index_of(id: String) -> int:
	for i in STEPS.size():
		if STEPS[i][0] == id:
			return i
	return 0


func _clear_stage() -> void:
	leave_decor()
	if is_instance_valid(stage):
		stage.queue_free()
	stage = null
	train = null
	field = null


## The inside of the train at `phase`, without its test panel, its people as
## the slice's state has them (warmth, ration, crowding and exposure, head
## counts and relations), so the windows' frost and the pane say the same.
func _show_train(phase: String, seg: int) -> void:
	leave_decor()
	var rules: Dictionary = TrainRules.load_default()
	rules["train"]["phase"] = phase
	rules["train"]["seg"] = seg
	rules["train"]["stranded"] = train_g["stranded"].duplicate(true) if train_g.get("stranded") is Dictionary else null
	weather.moving = phase == "travel" and train_halt_line(train_g) == ""
	# A halted board stands still, an ending without stranding too (the scene's auto motion runs it).
	if train_halt_line(train_g) != "": rules["view"]["motion"] = "stopped"
	rules["view"]["region"] = _stop_band(seg + 1 if phase == "travel" else seg)
	for c: String in (rules.get("comms", {}) as Dictionary).keys():
		if (train_g.get("comms", {}) as Dictionary).has(c):
			var sit: Array = St.situation(train_g, train_t, c)
			rules["comms"][c]["sit"] = [sit[0], sit[1], sit[2], sit[3]]
			rules["comms"][c]["pop"] = int(train_g["comms"][c]["pop"])
			rules["comms"][c]["rel"] = float(train_g["comms"][c]["rel"])
	# The hands the stretch's settle left (turn_settle.gd: have, short by post, expose), so
	# the cars look as many hands as there are (carry_people 3.6): empty posts when short.
	rules["train"]["hands"] = (train_g["hands"] as Dictionary).duplicate(true) if train_g.get("hands") is Dictionary else {}
	# Each furnished car's home stage (결정 486·517, train_decor.gd tier_of), so its light follows
	# how it is kept: a new train's cars start in rags. The cars no one furnishes are left out.
	rules["train"]["home"] = _home_of(train_g)
	train = TRAIN_SCENE.instantiate()
	train.opts = {"panel": false, "seed": int(opts.get("seed", 1))}
	if phase == "council":
		train.opts["view_mode"] = "section"
	# The values last shown, so the people react to what changed since (train_people_view.gd).
	if not last_rules.is_empty():
		train.opts["rules_before"] = last_rules
	last_rules = rules.duplicate(true)
	train.rules = rules
	train.decor_closed.connect(_on_train_decor_closed)
	add_child(train)
	stage = train
	# The world outside by the hour, the weather, the region and the cold
	# (the atmosphere frame); the snow over it falls as that look says. On the run the
	# sky is the one the train left (the stop behind it, or the start), the land ahead's.
	var look := outside_look(rules, _season_seg(seg))
	var cam: Camera3D = train.get("camera")
	if cam != null:
		outside = OutsideView.attach(cam, look, phase == "travel" and train_g.get("stranded") == null)
		outside.visible = train.view_mode == "section"
	journey = null
	if Journey.enabled():
		journey = Journey.attach(train, train, look, seg, {"seed": int(opts.get("seed", 1))})
	weather.falls = "none" if String(look["falls"]) == "none" else String(look["falls"])
	weather.drift_on = int(look["snow_level"]) > 0
	weather.light = clampf(float(look["lum"]) * 0.85 + 0.15, 0.2, 1.0)
	weather.set_haze(float(look["haze"]))
	# The corners' frost grows with the cold: none in late autumn's rain.
	frost.modulate = Color(1, 1, 1, float(look["window_frost"]))
	_quiet_labels()
	_quiet_labels.call_deferred()


## The look outside the train: opts "look" ({hour, kinds, cold, region}, for
## check shots), else the train's view (daytime, hour, cold, region), this
## stretch's weather from the season table and the cold it gives the stretch.
func outside_look(rules: Dictionary, seg: int) -> Dictionary:
	var view: Dictionary = rules.get("view", {})
	var want: Dictionary = opts.get("look", {})
	var night := String(view.get("daytime", "day")) == "night"
	var hour := float(want.get("hour", view.get("hour", 21.0 if night else 11.5)))
	var kinds: Array = want.get("kinds", view.get("weather_kinds", stop_weather(seg)["look"]))
	var cold := float(want.get("cold", view.get("cold", Atmosphere.cold_for("prologue", prologue_progress(seg)))))
	var side := float(want.get("side", view.get("side", Atmosphere.side_for("prologue"))))
	var region_name := String(want.get("region", view.get("region", Atmosphere.DEFAULT_REGION)))
	var more := {"side": side}
	if not want.has("cold") and not view.has("cold"):
		more["season"] = Atmosphere.season_at("prologue", prologue_progress(seg))
	return Atmosphere.look(hour, kinds, region_name, cold, more)


## How far into the prologue a stretch is (the slice is its first stops): the
## season table's row for that stretch, the same for the train and the stop.
static func prologue_progress(seg: int) -> float:
	return SeasonTable.seg_progress(seg)


## S1's names for a stop's weather (omens.ts WEATHER_NAME); what falls as rain reads 「비」.
const WEATHER_WORD: Dictionary = {"snow": "눈", "fog": "안개", "sleet": "진눈깨비", "overcast": "흐림", "clear": "맑은 추위", "blizzard": "눈보라"}


## The stop ahead on the departure lever's small line, 「10:00 도착 · 안개」: the arrival
## the departure contract will carry (train_stop.gd arrival_min, unless the slice is told
## one) and the weather the stop will wear (stop_weather). Only on the train before the stop.
func next_stop_line() -> String:
	if train_halt_line(train_g) != "":
		return ""
	if _is_campaign():
		if not current() in ["train", "travel"]:
			return ""
		var stop: Dictionary = _campaign_scene_stop()
		return "%d · %s · %s" % [int(stop.get("number", 0)), String(stop.get("name", "")), String(stop.get("kind", ""))]
	if String(STEPS[step][0]) != "train" or step + 1 >= STEPS.size():
		return ""
	var at := int(opts.get("arrive_min", TrainStop.arrival_min(String(train_g.get("seed", "")), int(train_g.get("seg", 1)))))
	var w: Dictionary = stop_weather(_season_seg(int(STEPS[step + 1][2])))
	var word: String = "비" if String(w["falls"]) == "rain" else String(WEATHER_WORD.get(String(w["weather"]), String(w["weather"])))
	return "%02d:%02d 도착 · %s" % [floori(at / 60.0), at % 60, word]


## A stretch's weather from the season table (코디네이터 10-25): its season's
## weights and what falls by its temperature, drawn on the slice's seed with S1's
## key, so the train outside, the stop scene and the field all wear the same.
func stop_weather(seg: int) -> Dictionary:
	if _is_campaign():
		return SeasonTable.pick_weather("prologue", prologue_progress(seg), String(train_g["seed"]))
	return SeasonTable.pick_weather("prologue", prologue_progress(seg), str(int(opts.get("seed", 1))))


## The train's own floating names and value lines are for its test bench;
## here the carriages wear name plates instead (.plate), under their floors.
func _quiet_labels() -> void:
	if not is_instance_valid(train):
		return
	for c in plates.get_children():
		plates.remove_child(c)
		c.queue_free()
	for l in train.find_children("*", "Label3D", true, false):
		var label := l as Label3D
		label.visible = false
		if label.font_size >= 60 and label.text != "":
			plates.add_child(_plate(label))


## The train's car entry (train_scene.gd cars) whose node is `node`.
func _car_of(node: Node) -> Dictionary:
	if not is_instance_valid(train):
		return {}
	for c: Dictionary in train.cars:
		if c.get("node") == node:
			return c
	return {}


## Whether car `def` has people of its own in the slice's state (a pane to show).
func _has_people(def: Dictionary) -> bool:
	var comm: String = String(def.get("comm", ""))
	return comm != "" and (train_g.get("comms", {}) as Dictionary).has(comm)


## A carriage's name plate with, when the car is cold, the paper tag beside it
## (.plate: b and .ptag, 5 apart, centred under the car). A car with people of
## its own is picked by its plate.
func _plate(name_label: Label3D) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", int(round(UiFonts.px(5.0))))
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var entry: Dictionary = _car_of(name_label.get_parent())
	var def: Dictionary = entry.get("def", {})
	var id: String = String(entry.get("id", ""))
	row.name = "Plate_" + id
	row.set_meta("car", name_label.get_parent())
	row.set_meta("x", name_label.position.x)
	row.set_meta("id", id)
	row.add_child(_enamel(name_label))
	if _has_people(def) or _decor_car(id):
		row.mouse_filter = Control.MOUSE_FILTER_STOP
		row.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		row.gui_input.connect(_plate_input.bind(id))
		if _has_people(def) and float(St.situation(train_g, train_t, String(def["comm"]))[0]) < CarPane.COLD:
			# The snow mark alone: the frost says cold (결정 417).
			var tag: Control = GlassParts.paper_tag("", "snow", -2.5)
			tag.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			row.add_child(tag)
	return row


## A tap picks the car; a drag begun on its plate still moves the train.
func _plate_input(e: InputEvent, id: String) -> void:
	var point: Vector2 = Vector2.ZERO
	var relative: Vector2 = Vector2.ZERO
	var pointer: int = -1
	var pressed: bool = false
	var released: bool = false
	if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
		point = e.position
		pressed = e.pressed
		released = not e.pressed
	elif e is InputEventScreenTouch:
		point = e.position
		pointer = e.index
		pressed = e.pressed
		released = not e.pressed
	elif e is InputEventScreenDrag:
		point = e.position
		relative = e.relative
		pointer = e.index
	elif e is InputEventMouseMotion and (e.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
		point = e.position
		relative = e.relative
	else:
		return
	# gui_input positions are local to a plate that moves with the camera.
	var plate_node: Control = plates.get_node_or_null("Plate_" + id) as Control if is_instance_valid(plates) else null
	if plate_node != null:
		var plate_transform: Transform2D = plate_node.get_global_transform_with_canvas()
		point = plate_transform * point
		relative = plate_transform.basis_xform(relative)
	if pressed:
		# A new press starts over, so a let-go lost to a rebuilt plate cannot hold the next taps.
		_plate_press_id = id
		_plate_press_pos = point
		_plate_pointer = pointer
		_plate_dragged = false
		return
	if _plate_press_id != id or _plate_pointer != pointer:
		return
	_plate_dragged = _plate_dragged or _plate_press_pos.distance_to(point) > PLATE_TAP_SLOP
	if released:
		_plate_press_id = ""
		if not _plate_dragged:
			_select(id, true)
	elif relative != Vector2.ZERO and is_instance_valid(train):
		train.drag(relative)


## A carriage's name plate (시안 .plate): a dark enamel plate, its name between
## two brass dots, where the car's floor meets its wheels.
func _enamel(name_label: Label3D) -> Control:
	var p := PanelContainer.new()
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("161d24")
	sb.set_corner_radius_all(int(round(UiFonts.px(2.0))))
	sb.border_width_top = 1
	sb.border_color = Color(1, 1, 1, 0.2)
	sb.shadow_color = Color(0, 0, 0, 0.45)
	sb.shadow_size = 3
	sb.shadow_offset = Vector2(0, 2)
	sb.content_margin_left = UiFonts.px(12.0)
	sb.content_margin_right = UiFonts.px(12.0)
	p.add_theme_stylebox_override("panel", sb)
	var word := UiFonts.label(name_label.text, UiFonts.WORD, 500, 12.0, Color("e6e1d4"), 1.44)
	word.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	word.custom_minimum_size = Vector2(0, UiFonts.px(18.0))
	p.add_child(word)
	var dots := func() -> void:
		var r: float = UiFonts.px(1.2)
		var y: float = p.size.y * 0.5
		p.draw_circle(Vector2(UiFonts.px(5.0), y), r, Color(202 / 255.0, 164 / 255.0, 92 / 255.0, 0.9))
		p.draw_circle(Vector2(p.size.x - UiFonts.px(5.0), y), r, Color(202 / 255.0, 164 / 255.0, 92 / 255.0, 0.9))
	p.draw.connect(dots)
	return p


func _process(_delta: float) -> void:
	if not is_instance_valid(marks):
		return
	if decor_id != "" and (DecorUiData.lock_reason(train_g, false) != "" or (is_instance_valid(paper) and not (paper as TurnCard).folded)):
		leave_decor()
	marks.queue_redraw()
	if is_instance_valid(journey):
		journey.quiet = _journey_quiet()
	# Under the stop scene: the snow over the screen runs with the train, and
	# the field is built in longer slices once the camera is at rest.
	if is_instance_valid(cinema):
		loader.resting = cinema.at_rest()
		var running: bool = absf(cinema.speed) > 1.0
		if weather.moving != running:
			weather.moving = running
	if is_instance_valid(train) and is_instance_valid(outside):
		outside.visible = train.view_mode == "section"
	if not is_instance_valid(train) or plates.get_child_count() == 0:
		return
	var cam: Camera3D = train.get("camera")
	if cam == null:
		return
	for p: Control in plates.get_children():
		var car = p.get_meta("car")
		if not is_instance_valid(car):
			continue
		var front_z: float = 1.40 if train.view_mode == "diag" else 0.0
		var at: Vector3 = (car as Node3D).to_global(Vector3(float(p.get_meta("x")), -0.45, front_z))
		# Over another screen no plate; with a car picked only its own.
		var shown: bool = card == null or card == home
		if sel != "" and String(p.get_meta("id")) != sel:
			shown = false
		p.visible = not cam.is_position_behind(at) and shown
		var s: Vector2 = cam.unproject_position(at)
		p.size = p.get_combined_minimum_size()
		p.position = s - p.size * 0.5


## A decision card or a room's pane is up: the land outside goes on, but no new
## outside event begins (presentation_motion.md 7b: they never get in the way of reading).
func _journey_quiet() -> bool:
	if decor_id != "":
		return true
	if is_instance_valid(paper) or (card != null and card != home):
		return true
	for p: Variant in [shop, research, mods, cost]:
		if is_instance_valid(p) and (p as CanvasItem).visible:
			return true
	return false


## The train's own screen: the picked car's pane at the right under the
## gauges, the keys along the bottom with `word` on the main key.
func _show_home(word: String) -> void:
	panel.visible = false
	var h := Control.new()
	h.name = "Home"
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var p = CarPane.new()
	p.name = "CarPane"
	p.lever_set.connect(_set_lever)
	p.folded.connect(_select.bind(""))
	p.decor_pressed.connect(open_decor)
	h.add_child(p)
	p.pin(TrainGauges.BAND_H)
	var b = HomeBar.new()
	b.name = "HomeBar"
	b.g = train_g
	b.main_word = word
	# Before the stop the main key is the departure lever, its small line the stop ahead
	# (decisions 471 B0, 474 N2, 475; the user 10-27: both the route band and this line).
	var ahead := next_stop_line()
	if ahead != "":
		b.lever = true
		b.lever_small = ahead
	b.main_pressed.connect(train_on)
	b.open_rooms = ["papers", "wrench", "gear"]
	b.room_pressed.connect(_open_room)
	h.add_child(b)
	layer.add_child(h)
	home = h
	pane = p
	bar = b
	card = h
	_select(FIRST_CAR, false)
	_tell_save_error.call_deferred()


## Pick car `id` ("" folds the pane): its pane comes up and the camera moves
## it into the middle of what the pane leaves clear.
func _select(id: String, toggle: bool = false) -> void:
	if toggle and id == sel:
		id = ""
	# A car picked over the workshop or the refit pane puts it away.
	if id != "":
		_put_rooms_away()
	var was: String = sel
	sel = ""
	var def: Dictionary = {}
	if id != "" and is_instance_valid(train):
		def = (train.car(id) as Dictionary).get("def", {})
	if _has_people(def) or _decor_car(id):
		sel = id
	if not is_instance_valid(pane):
		return
	pane.visible = sel != "" and _shows_pane(def)
	if pane.visible:
		pane.choosing_paper = is_instance_valid(paper) and not (paper as TurnCard).folded
		pane.show_car(def, train_g, train_t)
	if not is_instance_valid(train) or train.camera == null:
		return
	var at: String = sel if sel != "" else was
	if at == "":
		return
	if str(train.get("view_mode")) == "diag":
		if sel != "":
			train.focus_car(at, true)
			_set_cover()
		else:
			train.focus_car(at, false)
			train.set_pane(0.0)
		return
	train.focus_car(at)
	# The two common cars use the same glass with just its header.
	if sel != "" and pane.visible:
		var view_h: float = maxf(get_viewport().get_visible_rect().size.y, 1.0)
		train.scroll(UiFonts.px(PANE_SHIFT_CSS) * train.camera.size / view_h)


## The two common cars are picked like the living cars (결정 511·513).
func _decor_car(id: String) -> bool:
	return id != "" and not DecorGrid.of(id).is_empty()


func _shows_pane(def: Dictionary) -> bool:
	return _has_people(def) or String(def.get("id", "")) in ["captain", "dining"]


## Decorating a car (결정 506·510·511, train_scene.gd enter_decor): the train shows it alone with
## its grid, and the gauges, the plates, the keys, the pane and a folded paper go away till
## leave_decor. Not while a paper card is open to choose on, nor for a car the decor table has not.
## The strip, title, exit and gestures belong to decor_pane.gd.
func open_decor(id: String) -> bool:
	if not is_instance_valid(train) or decor_id != "":
		return false
	if is_instance_valid(paper) and not (paper as TurnCard).folded:
		return false
	if DecorUiData.lock_reason(train_g, false) != "":
		return false
	if not train.can_enter_decor(id):
		return false
	_put_rooms_away()
	if not train.enter_decor(id):
		return false
	decor_id = id
	_decor_hidden.clear()
	# The snow over the screen too: with the roof off it would fall inside the car.
	for n in [gauges, plates, marks, home, paper, next_button, soot_bot, weather]:
		if is_instance_valid(n) and n is CanvasItem and (n as CanvasItem).visible:
			(n as CanvasItem).visible = false
			_decor_hidden.append(n)
	var ui := DecorPane.new()
	ui.g = train_g
	ui.car_id = id
	ui.train = train
	ui.leave_requested.connect(leave_decor)
	ui.changed.connect(_decor_changed)
	layer.add_child(ui)
	decor_pane = ui
	return true


## Read the current furniture tiers both when showing the train and when leaving decor.
func _home_of(g: Dictionary) -> Dictionary:
	var stages: Dictionary = {}
	for car_id: String in TrainDecor.DECOR_CARS:
		stages[car_id] = TrainDecor.tier_of(g, car_id)
	return stages


## Back from decorating: restore the screens and refresh tiers with the car still picked.
func leave_decor() -> void:
	if decor_id == "":
		return
	var id: String = decor_id
	decor_id = ""
	if is_instance_valid(decor_pane):
		# The drag is let go without cancel_drag's layout of the closing pane (stop_drag → _layout),
		# most of the close's stall.
		decor_pane.drop_drag()
		decor_pane.hide()
		decor_pane.queue_free()
	decor_pane = null
	if is_instance_valid(train):
		train.exit_decor()
		_sync_decor_situation()
		var stages: Dictionary = _home_of(train_g)
		if stages != (train.rules["train"] as Dictionary).get("home", {}):
			train.rules["train"]["home"] = stages
			train.apply_rules()
	for n in _decor_hidden:
		if is_instance_valid(n):
			(n as CanvasItem).visible = true
	_decor_hidden.clear()
	if is_instance_valid(paper):
		paper.g = train_g
		# Decorating opens only over a folded paper (open_decor), and unfolding refills it
		# with what changed meanwhile (turn_card.gd set_folded), so it is not refilled under the fold.
		if not (paper as TurnCard).folded:
			paper._fill()
	_select(id, false)
	_tell_save_error.call_deferred()


## The train closed decorating on its own (its layout rebuilt): the pane, the screens put away
## and the car id follow it on the next frame, outside the rebuild (leave_decor syncs the rules).
func _on_train_decor_closed() -> void:
	if decor_id != "":
		leave_decor.call_deferred()


func _decor_changed() -> void:
	_room_changed()
	if is_instance_valid(pane):
		pane.refresh(train_g, train_t)


## Reseating while editing would replace the people that the 3D view faded.
## Apply the resulting situation after its own exit restores the people.
func _sync_decor_situation() -> void:
	if is_instance_valid(train):
		for comm: String in train_g.get("comms", {}):
			var sit: Array = St.situation(train_g, train_t, comm)
			var next_sit: Array = [sit[0], sit[1], sit[2], sit[3]]
			var current: Dictionary = train.rules.get("comms", {}).get(comm, {})
			if current.get("sit") != next_sit:
				train.set_comm(comm, "sit", next_sit)


## A room on the bottom bar with a screen of its own (home_bar.gd open_rooms).
func _open_room(icon: String) -> void:
	if icon == "gear":
		_open_workshop()
	elif icon == "wrench":
		_open_mods()
	elif icon == "papers":
		_open_research()


## The workshop's pane where the car's stands; folding it brings the car back.
func _open_workshop() -> void:
	if is_instance_valid(shop) or not is_instance_valid(home):
		return
	_room_up()
	var w = WorkshopPane.new()
	w.name = "WorkshopPane"
	w.folded.connect(_close_room)
	home.add_child(w)
	w.pin(TrainGauges.BAND_H)
	w.show_state(train_g)
	shop = w


func _close_room() -> void:
	_put_rooms_away()
	_select(shop_was, false)


## The refit pane (mods_pane.gd) where the workshop's stands, with this
## train's cars; a refit started or taken back draws the band again (its wood).
func _open_mods() -> void:
	if is_instance_valid(mods) or not is_instance_valid(home):
		return
	_room_up()
	var m = ModsPane.new()
	m.name = "ModsPane"
	if is_instance_valid(train) and train.rules is Dictionary:
		m.cars = ModsPane.formation(train.rules)
	m.folded.connect(_close_room)
	m.changed.connect(_room_changed)
	home.add_child(m)
	m.pin(TrainGauges.BAND_H)
	m.show_state(train_g)
	mods = m


## The research pane (research_pane.gd) where the workshop's stands: what
## can be restored now, its fragments and what it asks; a start, a way picked
## or a stop draws the band again (its parts and wood).
func _open_research() -> void:
	if is_instance_valid(research) or not is_instance_valid(home):
		return
	_room_up()
	var r = ResearchPane.new()
	r.name = "ResearchPane"
	r.folded.connect(_close_room)
	r.changed.connect(_room_changed)
	home.add_child(r)
	r.pin(TrainGauges.BAND_H)
	r.show_state(train_g)
	research = r


## One room's pane at a time: a room opened over another keeps the car
## picked before the first, to come back to on folding.
func _room_up() -> void:
	if not is_instance_valid(shop) and not is_instance_valid(mods) and not is_instance_valid(research) and not is_instance_valid(cost):
		shop_was = sel if sel != "" else FIRST_CAR
	_put_rooms_away()
	_select("")


func _put_rooms_away() -> void:
	if is_instance_valid(cost):
		gauges.set_focus([])
	for r in [shop, mods, research, cost]:
		if is_instance_valid(r):
			r.queue_free()
	shop = null
	mods = null
	research = null
	cost = null


## What a stretch costs in the stock pressed on the gauges and why
## (cost_pane.gd, J12), where the rooms stand; only on the train's own screen.
## The same stock pressed again folds it; the other one takes its place.
func _open_cost(id: String) -> void:
	if not is_instance_valid(home) or card != home:
		return
	if is_instance_valid(cost) and String(cost.which) == id:
		_close_room()
		return
	_room_up()
	var c = CostPane.new()
	c.name = "CostPane"
	c.which = id
	c.folded.connect(_close_room)
	home.add_child(c)
	c.pin(TrainGauges.BAND_H)
	c.show_state(train_g, train_t)
	cost = c
	# The stock it is about stays lit on the band, as under a sheet.
	gauges.set_focus([id])


func _room_changed() -> void:
	gauges.refresh(train_g, train_t)
	if is_instance_valid(bar):
		bar.g = train_g
	_save_slice()


## A lever on the pane: set it in the slice's state and draw again what reads it.
func _set_lever(comm: String, which: String, value: int) -> void:
	leave_decor()
	train_g = TrainTurn.set_lever(train_g, train_t, comm, which, float(value))
	gauges.refresh(train_g, train_t)
	if is_instance_valid(pane):
		pane.refresh(train_g, train_t)
	if is_instance_valid(bar):
		bar.g = train_g
	if is_instance_valid(train):
		var sit: Array = St.situation(train_g, train_t, comm)
		train.set_comm(comm, "sit", [sit[0], sit[1], sit[2], sit[3]])
		_quiet_labels()
	_save_slice()


## The picked car's lamp-amber corners, and the shade over the cars not picked.
func _draw_marks() -> void:
	if is_instance_valid(train) and train.view_mode == "diag":
		train.highlight(sel if (card != null and card == home) else "")
		return
	if sel == "" or card == null or card != home or not is_instance_valid(train) or train.camera == null:
		return
	var cam: Camera3D = train.camera
	var consts: Dictionary = train.get_script().get_script_constant_map()
	var length: float = float(consts.get("CAR_LENGTH", 16.0))
	var height: float = float(consts.get("CAR_HEIGHT", 3.0))
	var k: float = UiFonts.K
	for c: Dictionary in train.cars:
		var node: Node3D = c.get("node")
		if not is_instance_valid(node):
			continue
		var a: Vector3 = node.to_global(Vector3(0.0, height + 0.2, 0.0))
		var b: Vector3 = node.to_global(Vector3(length, -1.5, 0.0))
		if cam.is_position_behind(a) or cam.is_position_behind(b):
			continue
		var r := Rect2(cam.unproject_position(a), Vector2.ZERO).expand(cam.unproject_position(b))
		if String(c.get("id", "")) != sel:
			marks.draw_rect(r, Color(0, 0, 0, UNPICKED_SHADE))
			continue
		var top: Vector2 = cam.unproject_position(node.to_global(Vector3(0.15, height, 0.0)))
		var bot: Vector2 = cam.unproject_position(node.to_global(Vector3(length - 0.15, -0.15, 0.0)))
		var f := Rect2(top, Vector2.ZERO).expand(bot)
		var arm: float = SEL_ARM * k
		var th: float = 2.0 * k
		var corners: Array = [[f.position, 1.0, 1.0], [Vector2(f.end.x, f.position.y), -1.0, 1.0],
				[Vector2(f.position.x, f.end.y), 1.0, -1.0], [f.end, -1.0, -1.0]]
		# drop-shadow(0 0 5px rgba(242,166,60,.7)) under the corners, then the corners.
		for pass_i in 2:
			var grow: float = 3.0 * k if pass_i == 0 else 0.0
			var col: Color = Color(242 / 255.0, 166 / 255.0, 60 / 255.0, 0.3) if pass_i == 0 else SEL_COLOR
			for cn: Array in corners:
				var o: Vector2 = cn[0]
				var sx: float = float(cn[1])
				var sy: float = float(cn[2])
				marks.draw_rect(Rect2(o, Vector2(arm * sx, th * sy)).abs().grow(grow), col)
				marks.draw_rect(Rect2(o, Vector2(th * sx, arm * sy)).abs().grow(grow), col)


func _start_field() -> void:
	# Built under the stop scene already: it is shown and starts now.
	if is_instance_valid(pending_field):
		field = pending_field
		pending_field = null
		field.visible = true
		field.finished.connect(_field_done)
		stage = field
		field.go_live()
		# The brightness set in the settings, on a field the play makes (screen_lift.gd;
		# a tool's or a bot's field stays at 0).
		_field_ready(field)
		return
	loader.abandon()
	field = FieldGame.new()
	if field_resume.is_empty():
		field.opts = _field_opts()
	else:
		field.opts = field_resume.duplicate(true)
		field.opts["field_save"] = bool(opts.get("save", false))
		field.opts["field_save_path"] = String(opts.get("field_save_path", FieldSave.PATH))
		field_resume = {}
	if _is_campaign():
		field.opts["map_data"] = _campaign_map
		_campaign_map = {}
	field.finished.connect(_field_done)
	add_child(field)
	stage = field
	# The same, once the field is built (it may still be building here).
	if field.is_built:
		_field_ready(field)
	else:
		field.built.connect(_field_ready.bind(field), CONNECT_ONE_SHOT)


func _field_ready(game) -> void:
	ScreenLift.apply_saved(game)
	# Field notifications cover mobile pause and focus, but not a desktop close.
	# Let its own interrupt method write once on that window signal too.
	var on_close := Callable(game, "interrupt")
	if bool(opts.get("save", false)) and not get_window().close_requested.is_connected(on_close):
		get_window().close_requested.connect(on_close)
	_tell_save_error.call_deferred()


## The departure contract for the stop the slice's train stands at (field_departure.gd,
## s3 contract 2): the train's own people, made once a stop and kept for its return.
var contract: Dictionary = {}


func _departure() -> Dictionary:
	if _is_campaign():
		if _campaign_map_problem() != "":
			return {}
		var visit: Dictionary = train_g["campaign"]["visit"]
		if visit.is_empty():
			return {}
		if visit.get("contract") is Dictionary:
			contract = visit["contract"].duplicate(true)
			return contract
		if visit.get("result") != "open":
			return {}
		var built: Dictionary = FieldDeparture.build(train_g, train_t, {"placeId": visit["map"]})
		built["departureId"] = visit["departure_id"]
		built["stopId"] = visit["stop_id"]
		if not FieldReturn.check_departure(built, train_t).is_empty():
			_campaign_fail("F-CAMPAIGN-CONTRACT")
			return {}
		contract = built
		var out: Dictionary = train_g.duplicate(true)
		out["campaign"]["visit"]["contract"] = built.duplicate(true)
		_take(out)
		return contract
	if contract.is_empty() or int(contract.get("segment", -1)) != int(train_g.get("seg", -2)):
		contract = FieldDeparture.build(train_g, train_t, {"placeId": FieldMaps.resolve(_field_place())})
	return contract


## What the slice's field goes out with: the train's departure contract (who goes, their
## bodies, kit, hunger and soreness, the promises riding on the stop).
func _field_opts() -> Dictionary:
	var o := {"seed": int(opts.get("seed", 1))}
	o["field_save"] = bool(opts.get("save", false))
	o["field_save_path"] = String(opts.get("field_save_path", FieldSave.PATH))
	o["slice"] = true
	if run != "":
		o["slice_run"] = run
	# When the train comes in (decision 471 B0): the departure contract's, rolled by the train
	# from its run's seed and stretch; a contract without one, from the slice's seed and step.
	o["arrive_min"] = int(opts.get("arrive_min", _departure().get("arriveMin", FieldClock.arrival_for(int(opts.get("seed", 1)) * 1000 + step))))
	# The stop is drawn in the same cold as the stretch that brought the train
	# here (the stop pick and the field are the same stretch, so the stop scene
	# building it from the pick gives the same).
	o["act"] = "prologue"
	o["act_progress"] = prologue_progress(_season_seg(int(STEPS[step][2])))
	o["region"] = _stop_band(int(STEPS[step][2]))
	# A look asked of the slice for check shots (opts "look", as outside_look
	# reads it) is the stop's as well: the train, the stop scene and the field alike.
	var want: Dictionary = opts.get("look", {})
	if want.has("cold"):
		o["cold"] = float(want["cold"])
	# The stop's weather from the season table: the rules' kinds and the picture's.
	var w := stop_weather(_season_seg(int(STEPS[step][2])))
	o["weather"] = w["rules"]
	o["look"] = w["look"]
	if want.has("kinds"):
		o["look"] = want["kinds"]
	if want.has("hour"):
		o["look_hour"] = float(want["hour"])
	o["departure"] = _departure().duplicate(true)
	o["train_guard_ids"] = _guard_ids(o["departure"])
	# The laws standing on the train (its passed laws), for the field's own effects of them (domestic: emergency_ration).
	o["laws"] = (train_g.get("passed", {}) as Dictionary).keys()
	if opts.has("place"):
		o["place"] = String(opts["place"])
	# The stop's form (_stop_form, stop_ground.gd): the loader makes the map in it, off the
	# main thread (prepare), and the field keeps it.
	var form := _stop_form(int(STEPS[step][2]))
	if not form.is_empty():
		o["stop_form"] = form
	if opts.has("stop_form_m"):
		o["stop_form_m"] = opts["stop_form_m"]
	if _is_campaign():
		var visit: Dictionary = train_g["campaign"]["visit"]
		var stop: Dictionary = RouteState.current_stop(train_g)
		o["seed"] = int(visit["field_seed"])
		o["place"] = stop["map"]
		o["visit_id"] = visit["id"]
		o["campaign_kind"] = stop["kind"]
		o["region"] = stop["band"]
		o["stop_form"] = stop["form"]
		o["act_progress"] = prologue_progress(RouteStops.season_seg(int(stop["number"])))
	return o


## The field is over: its end card stays where it is, and a key over it goes
## on to the receipt.
func _field_done(r: Dictionary) -> void:
	if _is_campaign():
		var said: Dictionary = r.get("receipt", {}) if r.get("receipt") is Dictionary else {}
		if not _apply_return(said):
			return
		if field == null:
			go(_index_of("receipt"))
		else:
			_show_panel("", [], "귀환 영수증")
		return
	result = r
	receipt = r.get("receipt", {}) if not r.is_empty() else quiet_receipt(_departure())
	_apply_return(receipt)
	if field == null:
		go(step + 1)
		return
	_show_panel("", [], "귀환 영수증")
	panel.visible = true


## What the receipt card reads off a field result, made from a bare receipt
## when the field was skipped.
static func result_of(r: Dictionary) -> Dictionary:
	var people: Dictionary = r.get("people", {})
	var gone: int = 0
	for k in ["dead", "missing", "leftBehind"]:
		gone += (people.get(k, []) as Array).size()
	return {
		"reason": String(r.get("endReason", "departed")),
		"receipt": r,
		"stay": int((r.get("time", {}) as Dictionary).get("stayGameMinutes", 0)),
		"boarded": maxi(0, (people.get("sent", []) as Array).size() - gone),
		"hordes": 0,
	}


func _build_panel() -> void:
	panel = PanelContainer.new()
	panel.theme = theme
	# The smoked glass of a pane (B1), a faint light along its top.
	var sb := StyleBoxFlat.new()
	sb.bg_color = PANE
	sb.set_corner_radius_all(int(round(UiFonts.px(4.0))))
	sb.border_width_top = 1
	sb.border_color = Color(1, 1, 1, 0.1)
	sb.shadow_color = Color(0, 0, 0, 0.35)
	sb.shadow_size = int(round(UiFonts.px(8.0)))
	sb.set_content_margin_all(UiFonts.px(14.0))
	panel_style = sb
	panel.add_theme_stylebox_override("panel", sb)
	panel.custom_minimum_size = Vector2(PANEL_W, 0)
	layer.add_child(panel)
	# Wrapped lines settle their height after a layout pass: pin again then.
	panel.minimum_size_changed.connect(_pin)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", int(round(UiFonts.px(6.0))))
	panel.add_child(v)
	title = UiFonts.label("", UiFonts.WORD, 600, 18.0, INK, 0.36)
	v.add_child(title)
	lines = VBoxContainer.new()
	lines.add_theme_constant_override("separation", int(round(UiFonts.px(2.0))))
	v.add_child(lines)
	next_button = LampKey.new("")
	next_button.size_flags_horizontal = Control.SIZE_SHRINK_END
	next_button.pressed.connect(next)
	v.add_child(next_button)


## The receipt step: the receipt on the stop's own sheet over the train at its
## stop (receipt_sheet.gd), its key at the sheet's foot going on.
func _show_receipt(go_word: String) -> void:
	if receipt.is_empty():
		_show_panel(String(STEPS[step][3]), ["영수증 없음"], go_word)
		return
	panel.visible = false
	var c = ReceiptSheet.new()
	c.name = "ReceiptSheet"
	c.result = result if not result.is_empty() else result_of(receipt)
	c.seg = int(RouteState.current_stop(train_g)["number"]) if _is_campaign() else int(STEPS[step][2])
	c.go_word = go_word
	c.went_on.connect(next)
	layer.add_child(c)
	card = c
	if _is_campaign():
		var place_label: Label = c.find_child("Place", true, false) as Label
		if place_label != null:
			place_label.text = String(RouteState.current_stop(train_g)["name"])


func _show_panel(head: String, rows: Array, go_word: String) -> void:
	panel.add_theme_stylebox_override("panel", panel_style)
	panel.custom_minimum_size = Vector2(PANEL_W, 0)
	title.text = head
	title.visible = head != ""
	for c in lines.get_children():
		lines.remove_child(c)
		c.queue_free()
	save_line = null
	for text in rows:
		var l := UiFonts.label(String(text), UiFonts.WORD, 400, 13.0, INK2)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size.x = PANEL_W - UiFonts.px(28.0)
		lines.add_child(l)
	next_button.text = go_word
	panel.visible = true
	_pin()
	# Restoring the panel's contents is separate from telling a step once.
	if save_error != "":
		_add_save_line()
		_tell_save_error.call_deferred()


## Bottom right at its own size, growing up and to the left: the carriage's
## name line and its people stay in sight above it.
func _pin() -> void:
	panel.reset_size()
	panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT, Control.PRESET_MODE_MINSIZE, int(round(UiFonts.px(12.0))))


# ---------------------------------------------------------------- the campaign trial

func _is_campaign() -> bool:
	return opts.get("mode") == "campaign" or RouteState.is_campaign(train_g)


func _starting_board() -> Array:
	if not opts.has("start_board"):
		return start_board()
	var source: Variant = opts["start_board"]
	var state: Dictionary = {}
	var tables: Dictionary = {}
	if source is Dictionary and source.get("state") is Dictionary and source.get("tables") is Dictionary:
		state = source["state"].duplicate(true)
		tables = source["tables"].duplicate(true)
	elif source is Array and source.size() == 2 and source[0] is Dictionary and source[1] is Dictionary:
		state = source[0].duplicate(true)
		tables = source[1].duplicate(true)
	if not state.is_empty():
		state["lateOn"] = true
		state["eventPack"] = true
	return [state, tables]


func _campaign_fail(issue: String) -> void:
	campaign_error = issue
	if is_instance_valid(panel):
		_show_panel("캠페인을 진행할 수 없다", [issue], "확인")


func _campaign_scene_stop() -> Dictionary:
	var cursor: int = int(train_g["campaign"]["cursor"])
	var visit: Dictionary = train_g["campaign"]["visit"]
	if current() in ["travel", "arrive"] and visit.get("result") in ["returned", "passed"]:
		cursor += 1
	return CampaignRoute.stop_at(mini(cursor, CampaignRoute.size() - 1))


func _campaign_map_problem() -> String:
	var stop: Dictionary = RouteState.current_stop(train_g)
	if stop.is_empty():
		return "F-CAMPAIGN-MAP: no current stop"
	if opts.has("place") and opts["place"] != stop["map"]:
		return "F-CAMPAIGN-MAP: requested map differs from stop"
	if opts.has("map_data") and (not opts["map_data"] is Dictionary or (opts["map_data"] as Dictionary).is_empty()):
		return "F-CAMPAIGN-MAP: invalid map data"
	return CampaignRoute.map_problem(stop, opts.get("map_data", {}))


func _prepare_stop() -> void:
	if not _is_campaign():
		loader.prepare(_field_place(), int(opts.get("seed", 1)), _stop_form(_field_seg()), float(opts.get("stop_form_m", -1.0)))
		return
	var visit: Dictionary = train_g["campaign"]["visit"]
	if visit.is_empty():
		return
	if _campaign_map_problem() != "":
		_campaign_fail(_campaign_map_problem())
		return
	loader.prepare(_field_place(), int(visit["field_seed"]), _stop_form(_current_field_seg()), -1.0, String(visit["id"]))


func _campaign_can_go(id: String) -> bool:
	if RouteState.problem(train_g, train_t) != "":
		return false
	var board: String = SliceSave.step_of_board(train_g)
	var here: String = current()
	if here == "":
		return id == board or (id == "field" and board == "stop_pick" and not field_resume.is_empty())
	match id:
		"train":
			return here == "train" and board == "train"
		"stop_pick":
			return board == "stop_pick" and here in ["train", "arrive", "stop_pick"]
		"field":
			return board == "stop_pick" and here in ["stop_pick", "field"]
		"receipt":
			return board == "receipt" and here in ["field", "receipt"]
		"council":
			return int(train_g["campaign"]["cursor"]) == 0 and _returned() and board in ["receipt", "council"] and here in ["receipt", "council"]
		"travel":
			return board == "travel" and here in ["stop_pick", "council", "travel"]
		"arrive":
			return board == "arrive" and here in ["travel", "arrive"]
		"end":
			return board == "end" and here in ["receipt", "stop_pick", "travel", "end"]
	return false


func _campaign_next() -> void:
	leave_decor()
	match current():
		"train", "travel":
			_campaign_train_on()
		"stop_pick":
			go(_index_of("field"))
		"field":
			go(_index_of("receipt"))
		"receipt":
			if int(train_g["campaign"]["cursor"]) == CampaignRoute.size() - 1:
				_take(RouteState.activate_next_stop(train_g))
				go(_index_of("end"))
			else:
				go(_index_of("council"))
		"council":
			_leave_session()
			go(_index_of("travel"))
		"arrive":
			if _begin_campaign_stop():
				go(_index_of("stop_pick"))
		"end", "":
			_campaign_close_slots()
			get_tree().change_scene_to_file(BOOT_SCENE)
		_:
			_campaign_fail("F-CAMPAIGN-TRANSITION: next")


## Only real train turns reach the next unresolved stop. Papers keep their keys.
func _campaign_train_on() -> void:
	if not current() in ["train", "travel"]:
		_campaign_fail("F-CAMPAIGN-TRANSITION: train")
		return
	if current() == "train" and _campaign_map_problem() != "":
		_campaign_fail(_campaign_map_problem())
		return
	for _turn: int in RUN_LIMIT:
		if papers_of(train_g):
			going = true
			_show_paper()
			return
		if train_g.get("phase") == "end" or port_error != "":
			go(_index_of("end"))
			return
		if current() == "train" and train_g.get("phase") == "stop":
			go(_index_of("stop_pick"))
			return
		if current() == "travel" and FieldArrival.second_station_reached(train_g):
			go(_index_of("arrive"))
			return
		if current() == "travel" and SliceSave.step_of_board(train_g) != "travel":
			_campaign_fail("F-CAMPAIGN-TRANSITION: unresolved stop")
			return
		_take(TrainAdvance.advance(train_g, train_t))
		if campaign_error != "":
			return
		if train_halt_line(train_g) != "":
			_show_step(step)
			return
	_campaign_fail("F-CAMPAIGN-TRAIN: turn limit")


func _campaign_close_slots() -> void:
	if bool(opts.get("save", false)):
		SliceSave.clear(String(opts.get("slice_save_path", SliceSave.PATH)))
		_clear_slice_field()


## Start a fresh visit without touching the accumulated returns.
func _begin_campaign_stop() -> bool:
	var out: Dictionary = RouteState.activate_next_stop(train_g)
	if int(out["campaign"]["cursor"]) != int(train_g["campaign"]["cursor"]) + 1 or out["campaign"]["visit"].get("result") != "open":
		_campaign_fail("F-CAMPAIGN-TRANSITION: next stop")
		return false
	contract = {}
	receipt = {}
	result = {}
	passed = false
	council_g = {}
	arrival_g = {}
	field_resume = {}
	_campaign_map = {}
	pending_shop_events = []
	if is_instance_valid(pending_field):
		pending_field.queue_free()
	pending_field = null
	loader.abandon()
	_take(out)
	return campaign_error.is_empty()


func _campaign_apply_return(said: Dictionary) -> bool:
	if said.is_empty() or not FieldReceipt.check(said).is_empty() or not RouteState.owns_receipt(train_g, said):
		_campaign_fail("F-CAMPAIGN-RECEIPT: identity or shape")
		return false
	var id: String = String(said["receiptId"])
	var fingerprint: String = FieldReturn.canonical(said)
	var returns: Dictionary = train_g.get("fieldReturns", {}) if train_g.get("fieldReturns") is Dictionary else {}
	var known: Variant = (returns.get("applied", {}) as Dictionary).get(id)
	if known != null:
		if known != fingerprint or RouteState.record_for_visit(train_g).get("receiptId") != id:
			_campaign_fail("F-CAMPAIGN-RECEIPT: conflicting replay")
			return false
		return true
	if train_g["campaign"]["visit"].get("result") != "open" or not RouteState.record_for_visit(train_g).is_empty():
		_campaign_fail("F-CAMPAIGN-RECEIPT: visit already closed")
		return false
	var order: Dictionary = _departure()
	if not FieldReturn.check_departure(order, train_t).is_empty() or not FieldReturn.match_departure(order, said).is_empty():
		_campaign_fail("F-CAMPAIGN-RECEIPT: contract")
		return false
	var out: Dictionary = FieldReturn.apply_field_return(train_g, train_t, order, said)
	var g: Dictionary = out["g"]
	if out.get("status") != "applied" or RouteState.record_for_visit(g).get("receiptId") != id or g.get("fieldReturns", {}).get("applied", {}).get(id) != fingerprint:
		_campaign_fail("F-CAMPAIGN-RECEIPT: not applied")
		return false
	g = RouteState.mark_returned(g, id)
	var issue: String = RouteState.problem(g, train_t)
	if issue != "":
		_campaign_fail(issue)
		return false
	receipt = said.duplicate(true)
	result = result_of(receipt)
	_take(g)
	_after_return(train_g)
	return _returned()
