extends RefCounted
## "Can't press" (ui_states P3). The button is not switched off: it looks dim,
## and a press says why in a note and shakes the button once, left and right.
## Same size and timing as the S1 page (styles.css `denied`).

const SHAKE_PX: float = 3.0
const SHAKE_S: float = 0.24
const DIM: float = 0.45
## Offsets from rest and how long each leg takes: rest -> left -> right -> rest.
const STEPS: Array = [[-1.0, 0.25], [1.0, 0.5], [0.0, 0.25]]


## Dim a button that cannot act right now, or bring it back.
static func dim(b: Control, blocked: bool) -> void:
	b.modulate.a = DIM if blocked else 1.0


## Shake `b` once on its x. A second press during a shake starts over from rest.
static func shake(b: Control) -> void:
	if not b.is_inside_tree():
		return
	if b.has_meta("deny_tween"):
		var old: Tween = b.get_meta("deny_tween")
		if old != null and old.is_valid():
			old.kill()
		b.position.x = float(b.get_meta("deny_x"))
	var rest: float = b.position.x
	b.set_meta("deny_x", rest)
	var tw := b.create_tween()
	for s in STEPS:
		tw.tween_property(b, "position:x", rest + SHAKE_PX * float(s[0]), SHAKE_S * float(s[1]))
	b.set_meta("deny_tween", tw)


static func is_shaking(b: Control) -> bool:
	if not b.has_meta("deny_tween"):
		return false
	var tw: Tween = b.get_meta("deny_tween")
	return tw != null and tw.is_running()
