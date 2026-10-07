extends RefCounted
## Weather for one stop. body_injury 8.3 is the single owner of these rules
## (2026-10-07 review): visible conditions change sight, sound and the body.
## No new hidden numbers: every row is something the screen shows.

const ROWS: Dictionary = {
	# sight: multiplier on sight range for people and the dead alike.
	# sound: multiplier on every sound radius. footstep: extra on footsteps only.
	"clear": {"name": "맑음", "sight": 1.25, "sound": 1.0, "footstep": 1.0, "always_cold": false, "wet": false, "ice_all": false, "particles": 0},
	"fog": {"name": "안개", "sight": 0.6, "sound": 1.0, "footstep": 1.0, "always_cold": false, "wet": false, "ice_all": false, "particles": 0},
	"snow": {"name": "눈 내림", "sight": 0.85, "sound": 1.0, "footstep": 0.75, "always_cold": false, "wet": false, "ice_all": false, "particles": 300},
	"blizzard": {"name": "눈보라", "sight": 0.4, "sound": 0.75, "footstep": 1.0, "always_cold": true, "wet": false, "ice_all": false, "particles": 900},
	"sleet": {"name": "진눈깨비", "sight": 0.85, "sound": 1.0, "footstep": 1.0, "always_cold": false, "wet": true, "ice_all": true, "particles": 400},
}
## No rain below zero; sleet only near 0 C or in the thaw (body_injury 8.3).
const SLEET_MIN_C: float = -3.0

var kinds: Array[String] = []
var ambient_c: float = -14.0
## Wind blows toward this direction on the ground plane (x, z).
var wind_dir := Vector2(1, 0)
var wind: float = 0.4


## kinds can stack (Sulechów: fog and light snow). Unknown kinds are ignored.
func _init(p_kinds: Array = ["fog", "snow"], p_ambient_c: float = -14.0, p_wind_dir := Vector2(1, 0), p_wind: float = 0.4) -> void:
	ambient_c = p_ambient_c
	for k in p_kinds:
		var key := String(k)
		if not ROWS.has(key):
			continue
		if key == "sleet" and ambient_c < SLEET_MIN_C:
			continue
		kinds.append(key)
	wind_dir = p_wind_dir.normalized() if p_wind_dir.length() > 0.001 else Vector2(1, 0)
	wind = clampf(p_wind, 0.0, 1.0)


func _product(key: String) -> float:
	var m := 1.0
	for k in kinds:
		m *= float(ROWS[k][key])
	return m


## Night cuts sight to this share (body_injury 8.3 start value).
const DARK_SIGHT: float = 0.55
## Two or more cutting conditions at once (fog and night...) do not multiply:
## the shortest one holds (stand-in until 8.3 names 'foggy night' values).


## Sight range multiplier for people and the dead alike (body_injury 8.3).
func sight_mult(dark: bool = false) -> float:
	var cuts: Array[float] = []
	var best := 1.0
	for k in kinds:
		var v := float(ROWS[k]["sight"])
		if v < 1.0:
			cuts.append(v)
		else:
			best = maxf(best, v)
	if dark:
		cuts.append(DARK_SIGHT)
	if cuts.is_empty():
		return best
	return float(cuts.min())


## Radius multiplier for a sound. Footsteps also take the footstep column.
func sound_mult(footstep: bool = false) -> float:
	var m := _product("sound")
	if footstep:
		m *= _product("footstep")
	return m


func always_cold() -> bool:
	for k in kinds:
		if ROWS[k]["always_cold"]:
			return true
	return false


func wets_clothes() -> bool:
	for k in kinds:
		if ROWS[k]["wet"]:
			return true
	return false


func ice_everywhere() -> bool:
	for k in kinds:
		if ROWS[k]["ice_all"]:
			return true
	return false


func particles() -> int:
	var n := 0
	for k in kinds:
		n = maxi(n, int(ROWS[k]["particles"]))
	return n


## Downwind stretch for smell and excessive blood: 1 upwind or sideways,
## up to 1 + wind straight downwind (8.1: "바람이 부는 쪽으로는 두 배까지").
func downwind(from: Vector3, to: Vector3) -> float:
	var d := Vector2(to.x - from.x, to.z - from.z)
	if d.length() < 0.001:
		return 1.0
	return 1.0 + wind * maxf(0.0, wind_dir.dot(d.normalized()))


## Excessive blood (body_injury 8.1): a 12 m smell event stretched by the wind
## (downwind x1.5, upwind x0.6, sideways x0.9) and cut to x0.6 below zero.
func scent_mult(from: Vector3, to: Vector3) -> float:
	var m := 0.6 if ambient_c < 0.0 else 1.0
	var d := Vector2(to.x - from.x, to.z - from.z)
	if wind <= 0.0 or d.length() < 0.001:
		return m
	var dot := wind_dir.dot(d.normalized())
	if dot >= 0.5:
		return m * 1.5
	if dot <= -0.5:
		return m * 0.6
	return m * 0.9


func label() -> String:
	var names: Array[String] = []
	for k in kinds:
		names.append(String(ROWS[k]["name"]))
	return " · ".join(names) if not names.is_empty() else "맑음"
