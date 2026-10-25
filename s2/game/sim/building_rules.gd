extends RefCounted
## One rule for every door and window (J08): boards on each face, window
## latches, curtains, and the glass a broken window leaves on the floor. What a
## door or window does never depends on which building it belongs to or where
## that building comes in the map's list; a building's own part in a stop is its
## `role` (raider_den, lookout), read by role_of.
##
## A door or window has two faces, 0 and 1: the cells either side of it across
## the wall it stands in, the lower coordinate first (FieldGrid.faces).

## Boards: up to four on a face, each a plank and a nail, eight seconds of
## hammering (decision 423 P22). From the third on either face the eye no
## longer gets through a window. Both faces can be boarded.
const PLANKS_PER_FACE: int = 4
const SIGHT_PLANKS: int = 3
const NAILS_PER_PLANK: int = 1
## Each plank on a door takes this many blows of the dead, the planks on the
## side they strike from first (decision 423: a boarded door, three more blows).
const PLANK_HP: int = 3
## Taking a plank off is twice the hammering of putting it on, with a bar or a
## crowbar's claw, and quiet; the plank comes back, its nail does not.
const UNBOARD_SECONDS: float = 16.0
## A window opens and shuts as quickly as a door. A latched one tried from
## outside is a struggle, one try a second and a half, again and again until
## it gives or the latch snaps; from inside the latch is simply lifted.
const WINDOW_SECONDS: float = 0.5
const LATCH_TRY_SECONDS: float = 1.5
## Each try from outside may snap the latch for good: then only breaking opens it.
const LATCH_STUCK_CHANCE: float = 0.1
## A try lifts the latch this often, by strength (the first row the strength
## reaches; weaker than all of them, the last chance).
const LATCH_LIFT: Array = [[7, 0.25], [5, 0.15], [3, 0.1], [1, 0.05]]
const LATCH_LIFT_WEAKEST: float = 0.02
## How many of a map's whole windows are latched, and how many of the curtains
## in a home's rooms are drawn, when the party first comes (fixed per map and
## window, like the furniture).
const LATCHED_SHARE: float = 0.6
const CURTAIN_SHUT_SHARE: float = 0.3
## Rooms whose windows have curtains (room_furnish classes).
const CURTAIN_CLASSES: Dictionary = {"bed": true, "kitchen": true, "living": true}
## A curtain is drawn or opened at once, without a sound.
const CURTAIN_SECONDS: float = 0.5
## Barefoot onto broken glass: the foot is cut. Booted, only the crunch is heard.
const BAREFOOT_GLASS_CUT: float = 1.0


# ---------------------------------------------------------------- boards

static func planks(d: Dictionary, face: int) -> int:
	var pl: Variant = d.get("planks")
	return int(pl[face]) if pl is Array else 0


static func planks_total(d: Dictionary) -> int:
	var pl: Variant = d.get("planks")
	return int(pl[0]) + int(pl[1]) if pl is Array else 0


static func most_on_a_face(d: Dictionary) -> int:
	var pl: Variant = d.get("planks")
	return maxi(int(pl[0]), int(pl[1])) if pl is Array else 0


static func can_add_plank(d: Dictionary, face: int) -> bool:
	return not d.is_empty() and planks(d, face) < PLANKS_PER_FACE


## One more plank on `face`: its blows go on the door's (a window's are kept
## for when the dead strike windows).
static func add_plank(d: Dictionary, face: int) -> void:
	if not can_add_plank(d, face):
		return
	if not d.get("planks") is Array:
		d["planks"] = [0, 0]
	d["planks"][face] = int(d["planks"][face]) + 1
	d["plank_hp"] = int(d.get("plank_hp", 0)) + PLANK_HP
	if d.has("hp"):
		d["hp"] = int(d["hp"]) + PLANK_HP


## One plank off `face` (the outer one, worn or not): what it still held goes
## with it. False when there was none.
static func remove_plank(d: Dictionary, face: int) -> bool:
	if planks(d, face) <= 0:
		return false
	d["planks"][face] = int(d["planks"][face]) - 1
	var held: int = int(d.get("plank_hp", 0))
	var left: int = mini(held, planks_total(d) * PLANK_HP)
	d["plank_hp"] = left
	if d.has("hp"):
		d["hp"] = int(d["hp"]) - (held - left)
	return true


## A blow of the dead from `face` has already come off the door's hp: the
## planks take it while they hold, and those on the struck face give way first.
static func wear_planks(d: Dictionary, face: int) -> void:
	var held: int = int(d.get("plank_hp", 0))
	if held <= 0:
		return
	held -= 1
	d["plank_hp"] = held
	var keep: int = ceili(float(held) / PLANK_HP)
	while planks_total(d) > keep:
		var from: int = face if planks(d, face) > 0 else 1 - face
		d["planks"][from] = int(d["planks"][from]) - 1


# ---------------------------------------------------------------- windows

## Can be gone through now: broken or open, and no plank on either face.
static func window_passable(w: Dictionary) -> bool:
	return (bool(w.get("broken", false)) or bool(w.get("open", false))) and planks_total(w) == 0


## Stops the eye: a drawn curtain, or the third plank on a face.
static func window_opaque(w: Dictionary) -> bool:
	return String(w.get("curtain", "")) == "closed" or most_on_a_face(w) >= SIGHT_PLANKS


## Whole, shut, unboarded and its latch not snapped: it can be opened.
static func can_open(w: Dictionary) -> bool:
	return not w.is_empty() and not bool(w.get("broken", false)) and not bool(w.get("open", false)) \
		and planks_total(w) == 0 and not bool(w.get("stuck", false))


static func can_shut(w: Dictionary) -> bool:
	return not w.is_empty() and bool(w.get("open", false)) and not bool(w.get("broken", false))


## One try at a latched window from outside: "open", "stuck" (the latch snapped
## and the window will not open again) or "struggle" (try again).
static func try_latch(strength: int, roll_stuck: float, roll_lift: float) -> String:
	if roll_stuck < LATCH_STUCK_CHANCE:
		return "stuck"
	return "open" if roll_lift < latch_lift(strength) else "struggle"


static func latch_lift(strength: int) -> float:
	for row: Array in LATCH_LIFT:
		if strength >= int(row[0]):
			return float(row[1])
	return LATCH_LIFT_WEAKEST


static func has_curtain(w: Dictionary) -> bool:
	return String(w.get("curtain", "")) != ""


## The face a person at `from` stands on, of the two cells `faces` gives.
static func face_toward(faces: Array, from: Vector3) -> int:
	var a: Vector2i = faces[0]
	var b: Vector2i = faces[1]
	var da := Vector2(from.x - (a.x + 0.5), from.z - (a.y + 0.5)).length_squared()
	var db := Vector2(from.x - (b.x + 0.5), from.z - (b.y + 0.5)).length_squared()
	return 0 if da <= db else 1


## The latch and curtain of every window, fixed per map and window. A home
## room's window got its curtain from room_furnish ("curtain": "open"); this
## draws some of them. `homes` are building ids whose every window has one
## (a map laid out by hand names them by role "home").
static func dress_windows(data: Dictionary) -> void:
	var place := String(data.get("place_id", ""))
	var homes: Dictionary = {}
	for b: Dictionary in data.get("buildings", []):
		if String(b.get("role", "")) == "home":
			homes[int(b["id"])] = true
	var levels: Dictionary = data.get("levels", {0: data.get("grid")})
	for lv: int in levels:
		var g = levels[lv]
		if g == null:
			continue
		for c: Vector2i in g.windows:
			var w: Dictionary = g.windows[c]
			var rng := RandomNumberGenerator.new()
			rng.seed = ("%s|win|%d|%d|%d" % [place, lv, c.x, c.y]).hash()
			var latch_roll := rng.randf()
			var curtain_roll := rng.randf()
			w["open"] = false
			w["stuck"] = false
			w["latched"] = not bool(w.get("broken", false)) and latch_roll < LATCHED_SHARE
			if not w.has("planks"):
				w["planks"] = [0, 0]
			if homes.has(int(w.get("building", -1))) and not w.has("curtain"):
				w["curtain"] = "open"
			if has_curtain(w):
				w["curtain"] = "closed" if curtain_roll < CURTAIN_SHUT_SHARE else "open"
				if w["curtain"] == "closed":
					g.refresh_cell(c)


# ---------------------------------------------------------------- buildings

## The building row of id `b` (a map's list need not be in id order).
static func building(data: Dictionary, b: int) -> Dictionary:
	var rows: Array = data.get("buildings", [])
	if b >= 0 and b < rows.size() and int(rows[b].get("id", -1)) == b:
		return rows[b]
	for row: Dictionary in rows:
		if int(row.get("id", -1)) == b:
			return row
	return {}


static func role_of(data: Dictionary, b: int) -> String:
	return String(building(data, b).get("role", ""))


## A building lets the cold in through an open window, or a broken one not
## boarded to the third plank on a face (body_injury 3.1: the warmth goes).
static func lets_cold_in(levels: Dictionary, b: int) -> bool:
	for g in levels.values():
		for c: Vector2i in g.windows:
			var w: Dictionary = g.windows[c]
			if int(w.get("building", -1)) != b:
				continue
			if bool(w.get("open", false)):
				return true
			if bool(w.get("broken", false)) and most_on_a_face(w) < SIGHT_PLANKS:
				return true
	return false
