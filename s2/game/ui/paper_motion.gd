extends RefCounted
## A sheet of paper coming onto the screen and going off it (사용자
## 2026-10-24: 서류가 뿅 하고 나오지 말고 펼쳐지거나 나오게). In: it slides up
## from below half shut along its crease (the line down its middle that
## paper_sheet.gdshader draws), opens out along it, leans and lies down, its
## shadow settling under it as it comes down, with a rustle. Out: it lifts,
## folds shut along the same line and slides away, with a crease of paper.
## Only the sheet's place, turn, width and shadow move; what is written on
## it and its keys stay live the whole time. Seen before, it all goes in half
## the time. The stop card uses it; the receipt and the session card can too
## (paper_sheet.gd sheets, or any Control laid like one).

const OPEN_SOUND := "res://audio/paper/paper_open.wav"
const FOLD_SOUND := "res://audio/paper/paper_fold.wav"
const UiFonts = preload("res://game/ui/ui_fonts.gd")

const OPEN_S: float = 0.62
const CLOSE_S: float = 0.42
## Seen before: this share of the time.
const SHORT: float = 0.5
## Its width while half shut along the crease.
const FOLDED: float = 0.5
## Where it comes from: this share of its width to the left, of the view's height below.
const FROM := Vector2(-0.18, 0.95)
## How much more it leans while it comes in, and its shadow's extra reach
## (mockup px) while it is held up off what is under it.
const LEAN_IN_DEG: float = -6.0
const LIFT := Vector2(14, 16)
const META_REST := "paper_motion_rest"
const META_TWEEN := "paper_motion_tween"


## Bring `sheet` in to where it lies now. Returns the tween (its finished
## signal is when it has lain down).
static func open(sheet: Control, short: bool = false) -> Tween:
	var rest := _rest(sheet)
	var span: float = OPEN_S * (SHORT if short else 1.0)
	_sound(sheet, OPEN_SOUND)
	var tw := _tween(sheet)
	tw.tween_method(func(k: float) -> void: _open_pose(sheet, rest, k), 0.0, 1.0, span)
	tw.tween_callback(func() -> void: _lay(sheet, rest))
	_open_pose(sheet, rest, 0.0)
	return tw


## Take `sheet` off: lifted, folded, slid away. Returns the tween; free the
## card on its finished signal.
static func close(sheet: Control, short: bool = false) -> Tween:
	var rest := _rest(sheet)
	_lay(sheet, rest)
	var span: float = CLOSE_S * (SHORT if short else 1.0)
	_sound(sheet, FOLD_SOUND)
	var tw := _tween(sheet)
	tw.tween_method(func(k: float) -> void: _close_pose(sheet, rest, k), 0.0, 1.0, span)
	return tw


## Where it lies (taken once, the first time it is moved).
static func _rest(sheet: Control) -> Dictionary:
	if sheet.has_meta(META_REST):
		return sheet.get_meta(META_REST)
	var shadow: Variant = sheet.get("_shadow")
	var rest := {
		"pos": sheet.position, "rot": sheet.rotation, "pivot": sheet.pivot_offset,
		"shadow": shadow if shadow is Control else null,
		"shadow_at": (shadow as Control).position if shadow is Control else Vector2.ZERO,
		# It folds along the crease down its middle: turned about its top there
		# while it moves, put back on its own corner when it lies down.
		"fold": Vector2(sheet.size.x * 0.5, 0.0),
	}
	sheet.set_meta(META_REST, rest)
	return rest


static func _tween(sheet: Control) -> Tween:
	var old: Variant = sheet.get_meta(META_TWEEN) if sheet.has_meta(META_TWEEN) else null
	if old is Tween and (old as Tween).is_valid():
		(old as Tween).kill()
	var tw := sheet.create_tween()
	sheet.set_meta(META_TWEEN, tw)
	return tw


## Set the sheet at `at` (where its fold-pivoted position would be for the
## place it rests at), turned `rot`, `wide` of its width, the shadow `lift` up.
static func _pose(sheet: Control, rest: Dictionary, at: Vector2, rot: float, wide: float, lift: float) -> void:
	sheet.pivot_offset = rest["fold"]
	sheet.position = at
	sheet.rotation = rot
	sheet.scale = Vector2(wide, 1.0)
	var shadow: Control = rest["shadow"]
	if shadow != null:
		shadow.position = Vector2(rest["shadow_at"]) + LIFT * UiFonts.K * lift


## The fold-pivoted position at which the sheet looks as it does at rest.
static func _rest_at(rest: Dictionary) -> Vector2:
	var p0: Vector2 = rest["pivot"]
	var p1: Vector2 = rest["fold"]
	return Vector2(rest["pos"]) + (p0 - p1) - (p0 - p1).rotated(float(rest["rot"]))


static func _from_at(sheet: Control, rest: Dictionary) -> Vector2:
	var view_h: float = sheet.get_viewport_rect().size.y if sheet.is_inside_tree() else 720.0
	return _rest_at(rest) + Vector2(sheet.size.x * FROM.x, view_h * FROM.y)


static func _open_pose(sheet: Control, rest: Dictionary, k: float) -> void:
	var slide: float = _out_cubic(clampf(k / 0.48, 0.0, 1.0))
	var unfold: float = _out_back(clampf((k - 0.36) / 0.42, 0.0, 1.0))
	var settle: float = _out_cubic(clampf((k - 0.62) / 0.38, 0.0, 1.0))
	var lean: float = deg_to_rad(LEAN_IN_DEG)
	var rot: float = lerpf(float(rest["rot"]) + lean, float(rest["rot"]) + lean * 0.5, slide)
	rot = lerpf(rot, float(rest["rot"]), settle) + deg_to_rad(0.7) * sin(settle * PI) * (1.0 - settle)
	_pose(sheet, rest, _from_at(sheet, rest).lerp(_rest_at(rest), slide), rot, lerpf(FOLDED, 1.0, unfold), 1.0 - settle)
	sheet.modulate.a = clampf(k / 0.12, 0.0, 1.0)


static func _close_pose(sheet: Control, rest: Dictionary, k: float) -> void:
	var lift: float = _out_cubic(clampf(k / 0.2, 0.0, 1.0))
	var fold: float = _in_out(clampf((k - 0.15) / 0.35, 0.0, 1.0))
	var away: float = _in_cubic(clampf((k - 0.45) / 0.55, 0.0, 1.0))
	var rot: float = float(rest["rot"]) + deg_to_rad(LEAN_IN_DEG) * 0.5 * lift + deg_to_rad(LEAN_IN_DEG) * 0.5 * away
	_pose(sheet, rest, _rest_at(rest).lerp(_from_at(sheet, rest), away), rot, lerpf(1.0, FOLDED, fold), lift)
	sheet.modulate.a = 1.0 - clampf((k - 0.8) / 0.2, 0.0, 1.0)


## Lying where it lies: its own corner, turn and shadow, nothing moved.
static func _lay(sheet: Control, rest: Dictionary) -> void:
	sheet.pivot_offset = rest["pivot"]
	sheet.position = rest["pos"]
	sheet.rotation = rest["rot"]
	sheet.scale = Vector2.ONE
	sheet.modulate.a = 1.0
	var shadow: Control = rest["shadow"]
	if shadow != null:
		shadow.position = rest["shadow_at"]


static func _sound(sheet: Control, path: String) -> void:
	if not ResourceLoader.exists(path) or not sheet.is_inside_tree():
		return
	var player := AudioStreamPlayer.new()
	player.stream = load(path)
	player.bus = "SFX" if AudioServer.get_bus_index("SFX") >= 0 else "Master"
	player.finished.connect(player.queue_free)
	sheet.add_child(player)
	player.play()


static func _out_cubic(x: float) -> float:
	return 1.0 - pow(1.0 - x, 3.0)


static func _in_cubic(x: float) -> float:
	return x * x * x


static func _in_out(x: float) -> float:
	return x * x * (3.0 - 2.0 * x)


## Past flat and back: the sheet springs open a little.
static func _out_back(x: float) -> float:
	var c: float = 1.4
	return 1.0 + (c + 1.0) * pow(x - 1.0, 3.0) + c * pow(x - 1.0, 2.0)
