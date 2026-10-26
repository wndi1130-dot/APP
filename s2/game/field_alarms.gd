extends RefCounted
## Buildings' alarms in the field (gap audit J17; the rules in
## sim/alarm_rules.gd). field_actions tells it when a building is broken
## into; it rings through the field's one sound path (make_sound), so the dead
## hear it as they hear anything. Only the first ring counts on the stop's
## score (noise.gd SOURCES "building_alarm"); the rest only call
## ("building_alarm_ring"), or one alarm would bring every horde at once.

const FieldGrid = preload("res://game/world/field_grid.gd")
const AlarmRules = preload("res://game/sim/alarm_rules.gd")

var game  # field_game.gd
## Buildings already broken into once: true if theirs went off.
var decided: Dictionary = {}
## Ringing now: {"building", "at", "rings": [times]}.
var ringing: Array = []


func _init(field_game) -> void:
	game = field_game


## A building was broken into at cell c (a door kicked through or pried
## open, a window broken), by p (null: by nobody, a shot or a throw). Its
## alarm rolls the first time only. Returns true if it went off now.
func broken_into(building: int, c: Vector2i) -> bool:
	if building < 0 or decided.has(building):
		return false
	var kind: String = ""
	var rows: Array = game.data.get("buildings", [])
	if building < rows.size():
		kind = AlarmRules.kind_of(rows[building])
	var on := AlarmRules.goes_off(game.rng.seed, building, kind)
	decided[building] = on
	if not on:
		return false
	var at: Vector3 = FieldGrid.center(c)
	ringing.append({"building": building, "at": at, "rings": AlarmRules.rings(game.clock.elapsed)})
	if game.hud != null and game.player != null and game.player.position.distance_to(at) <= AlarmRules.REACH * 35.0:
		game.hud.toast("경보기가 울린다. 근처 것들이 몰려온다.")
	return true


func tick() -> void:
	if ringing.is_empty():
		return
	var now: float = game.clock.elapsed
	var keep: Array = []
	for a: Dictionary in ringing:
		var left: Array = a["rings"]
		while not left.is_empty() and float(left[0]) <= now:
			var first: bool = left.size() == AlarmRules.rings(0.0).size()
			left.pop_front()
			game.make_sound(a["at"], AlarmRules.LEVEL, "building_alarm" if first else "building_alarm_ring")
		if not left.is_empty():
			keep.append(a)
	ringing = keep


## Ringing anywhere now (the HUD, tests).
func any_ringing() -> bool:
	return not ringing.is_empty()
