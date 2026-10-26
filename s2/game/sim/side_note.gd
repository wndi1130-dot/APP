extends RefCounted
## A scrawled map to the side path (결정 카드 M 가, 차이 10번): on about half the stops
## that have a side path and its rare store (side_path.gd, map-layout's), one 「낙서 지도」
## lies in a dead one's pocket or in a desk. Once anyone in the squad holds it, the
## field knows where the way through the edge woods starts (FieldGame.side_hint) and
## the HUD marks that side of the screen with a stamp, no word (결정 417), until
## someone reaches it or the store has been got into. Nothing is added to what the
## stop gives: the path and its store were there already.

const FieldGrid = preload("res://game/world/field_grid.gd")

const ID: String = "note_side"
const CHANCE: float = 0.5
## Where it lies: a dead one's pocket or a desk, half and half (the reference has
## both); if one kind is missing, the other.
const DESKS: Dictionary = {"desk": true, "office_desk": true, "typewriter_desk": true}
## Not on the dead round the store itself (it would point at where one stands).
const AWAY_FROM_STORE: float = 20.0
## Reached: this close to the way in, the stamp is gone.
const REACHED: float = 3.0


## Lay the note, if this stop gets one. dead: the field's dead (zombies.list, the
## ones that can carry: not frozen). Returns where it went: "dead", "desk" or "".
static func place(data: Dictionary, dead: Array, seed: int) -> String:
	var spot: Dictionary = data.get("side_path", {})
	if spot.is_empty():
		return ""
	var rng := RandomNumberGenerator.new()
	rng.seed = ("%d:side_note" % seed).hash()
	if rng.randf() >= CHANCE:
		return ""
	var store := _store_middle(spot)
	var bodies: Array = []
	for z in dead:
		if Vector2(z["pos"].x, z["pos"].z).distance_to(store) >= AWAY_FROM_STORE:
			bodies.append(z)
	var desks: Array = []
	var ids: Array = data.get("containers", {}).keys()
	ids.sort()
	for id: String in ids:
		var c: Dictionary = data["containers"][id]
		if DESKS.has(String(c.get("furniture", ""))) and not bool(c.get("locked", false)) and not c.has("pick") \
				and not (spot.get("boxes", []) as Array).has(id):
			desks.append(id)
	var to_desk := rng.randf() < 0.5
	if bodies.is_empty() or (to_desk and not desks.is_empty()):
		if desks.is_empty():
			return ""
		var box: Dictionary = data["containers"][desks[rng.randi_range(0, desks.size() - 1)]]
		box["items"] = (box.get("items", []) as Array) + [ID]
		return "desk"
	var holder: Dictionary = bodies[rng.randi_range(0, bodies.size() - 1)]
	holder["carry"] = (holder.get("carry", []) as Array) + [ID]
	return "dead"


## Where the way in starts (the middle of the gap's two entrance cells, ground level),
## or Vector3.INF when the stop has no side path.
static func way_in(data: Dictionary) -> Vector3:
	var cells: Array = data.get("side_path", {}).get("entrance", [])
	if cells.is_empty():
		return Vector3.INF
	var at := Vector3.ZERO
	for c in cells:
		at += FieldGrid.center(c)
	return at / cells.size()


## The hint while the note is held: {"at": the way in} or {} (none yet, reached, or
## the store already got into). held: anyone in the squad has the note.
static func hint(data: Dictionary, held: bool, reached: bool, store_visited: bool) -> Dictionary:
	var at := way_in(data)
	if not held or reached or store_visited or at == Vector3.INF:
		return {}
	return {"at": at}


static func _store_middle(spot: Dictionary) -> Vector2:
	var r: Variant = spot.get("store")
	if r is Rect2i:
		var mid: Vector2 = Vector2((r as Rect2i).position) + Vector2((r as Rect2i).size) / 2.0
		return mid
	return Vector2(INF, INF)
