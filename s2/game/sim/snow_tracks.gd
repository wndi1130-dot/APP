extends RefCounted
## Footprints and drag marks in lying snow (weather_fx 15장). Each cell holds
## how much of its snow is untouched: 255 fresh, lower where someone walked.
## Falling snow fills the marks back in. Picture only: no game rule reads this.
## The view writes it to the spare A channel of the sight texture.

const FRESH: int = 255
## What one pass takes off a cell (share of the full depth).
const PRESS: Dictionary = {"walk": 0.5, "run": 0.7, "drag": 0.9}
## A mark never goes below this: packed snow is still snow.
const FLOOR: float = 0.1
## Depth of a full mark, for how long snowfall takes to fill it (cm).
const MARK_CM: float = 3.0

var cells := PackedByteArray()
## Cells below FRESH (index -> true): only these are walked when snow falls.
var marked: Dictionary = {}
## Cells changed since take_changed() (index -> byte).
var _changed: Dictionary = {}
## Fill not yet applied (less than one byte step), so slow snow still adds up.
var _carry: float = 0.0


func _init(cell_count: int = 0) -> void:
	cells.resize(maxi(cell_count, 0))
	cells.fill(FRESH)


func value(i: int) -> float:
	return float(cells[i]) / float(FRESH) if i >= 0 and i < cells.size() else 1.0


## Someone crossed cell i. Returns true if the cell changed.
func press(i: int, kind: String = "walk") -> bool:
	if i < 0 or i >= cells.size():
		return false
	var amount := float(PRESS.get(kind, PRESS["walk"]))
	var b := int(round(maxf(value(i) - amount, FLOOR) * float(FRESH)))
	if b >= cells[i]:
		return false
	cells[i] = b
	marked[i] = true
	_changed[i] = b
	return true


## Snow falling for game_minutes at fall_cm_h (SnowCover.rate_cm_h; zero or
## less fills nothing: marks stay until it snows). Returns how many cells moved.
func refill(game_minutes: float, fall_cm_h: float) -> int:
	if marked.is_empty():
		_carry = 0.0
		return 0
	if game_minutes <= 0.0 or fall_cm_h <= 0.0:
		return 0
	_carry += fall_cm_h * game_minutes / 60.0 / MARK_CM * float(FRESH)
	var add := int(floor(_carry))
	if add <= 0:
		return 0
	_carry -= float(add)
	var moved := 0
	for i in marked.keys():
		var b := mini(int(cells[i]) + add, FRESH)
		cells[i] = b
		_changed[i] = b
		moved += 1
		if b >= FRESH:
			marked.erase(i)
	return moved


## Real game minutes of this snowfall until a full mark is gone.
static func minutes_to_fill(fall_cm_h: float) -> float:
	return INF if fall_cm_h <= 0.0 else MARK_CM / fall_cm_h * 60.0


## Cells changed since the last call (index -> byte), for the view to upload.
func take_changed() -> Dictionary:
	var out := _changed
	_changed = {}
	return out
