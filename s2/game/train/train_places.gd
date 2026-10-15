extends RefCounted
## Reservations include people still walking here. Closing releases both groups.

const Catalog = preload("res://game/train/train_catalog.gd")
const Context = preload("res://game/train/train_context.gd")
var spots: Dictionary = {}
var bookings: Dictionary = {}  # actor id -> spot id


func add_car(car: Dictionary, x0: float) -> void:
	var replacement: Dictionary = {}
	for source in Catalog.layout(car)["spots"]:
		var row: Dictionary = source.duplicate(true)
		var id := "%s/%s" % [car["id"], row["id"]]
		row["car"] = String(car["id"])
		row["id"] = id
		row["x0"] = x0
		row["members"] = {}
		row["base_capacity"] = int(row["capacity"])
		row["enabled"] = true
		row["open"] = true
		row["cycle_open"] = true
		row["remaining"] = float(row["cycle"][0])
		replacement[id] = row
	# New anchors replace every old place in this car, including removed spots.
	var old_spots: Array = []
	for id in spots:
		if spots[id]["car"] == String(car["id"]):
			old_spots.append(id)
	for actor in bookings.keys():
		if old_spots.has(bookings[actor]):
			release(int(actor))
	for id in old_spots:
		spots.erase(id)
	spots.merge(replacement, true)


func refresh(contexts: Dictionary) -> Array:
	var released: Array = []
	for id in spots:
		var s: Dictionary = spots[id]
		var c: Dictionary = contexts.get(s["car"], {})
		s["capacity"] = int(Catalog.tuning("half_class_capacity")) if String(id).ends_with("/classroom") and c.get("half_class", false) else s["base_capacity"]
		for actor in s["members"].keys():
			if int(s["members"][actor]["anchor"]) >= int(s["capacity"]):
				released.append(actor)
				release(actor)
		s["enabled"] = contexts.has(s["car"]) and Context.is_open(String(s["when"]), c)
		s["open"] = s["enabled"] and s["cycle_open"]
		if not bool(s["open"]):
			released.append_array(close_members(id))
	return released


func advance(delta: float) -> Array:
	var released: Array = []
	for id in spots:
		var s: Dictionary = spots[id]
		var cycle: Array = s["cycle"]
		if float(cycle[0]) <= 0 or not bool(s["enabled"]):
			continue
		s["remaining"] = float(s["remaining"]) - delta
		if float(s["remaining"]) <= 0:
			s["cycle_open"] = not bool(s["cycle_open"])
			s["open"] = s["cycle_open"]
			s["remaining"] = float(cycle[0] if s["cycle_open"] else cycle[1])
			if not s["open"]:
				released.append_array(close_members(id))
	return released


func reserve(actor: int, id: String, blocked: Array = []) -> bool:
	if bookings.has(actor):
		return bookings[actor] == id
	if not spots.has(id):
		return false
	var s: Dictionary = spots[id]
	var members: Dictionary = s["members"]
	if not bool(s["open"]) or members.size() >= int(s["capacity"]):
		return false
	var used: Array = members.values().map(func(v): return int(v["anchor"]))
	for i in int(s["capacity"]):
		if not used.has(i):
			var at := Catalog.vector(s["anchors"][i]) + Vector3(float(s["x0"]), 0, 0)
			if blocked.any(func(p): return at.distance_to(p) < float(Catalog.tuning("actor_clearance"))):
				continue
			var occupied := false
			for other in bookings:
				if at.distance_to(target(int(other))) < float(Catalog.tuning("actor_clearance")):
					occupied = true
					break
			if occupied:
				continue
			members[actor] = {"phase": "approaching", "anchor": i}
			bookings[actor] = id
			return true
	return false


func arrive(actor: int) -> bool:
	if not bookings.has(actor):
		return false
	spots[bookings[actor]]["members"][actor]["phase"] = "present"
	return true


func transfer(actor: int, id: String, blocked: Array = []) -> bool:
	return reserve_group([actor], id, blocked)


func reserve_group(actors: Array, id: String, blocked: Array = []) -> bool:
	# All roles get places, or every old booking (including phase) survives.
	var old_bookings: Dictionary = bookings.duplicate(true)
	var old_members: Dictionary = {}
	for key in spots:
		old_members[key] = spots[key]["members"].duplicate(true)
	for actor in actors:
		release(int(actor))
	for actor in actors:
		if not reserve(int(actor), id, blocked):
			bookings = old_bookings
			for key in old_members:
				spots[key]["members"] = old_members[key]
			return false
	return true


func release(actor: int) -> void:
	if bookings.has(actor):
		spots[bookings[actor]]["members"].erase(actor)
		bookings.erase(actor)


func close_members(id: String) -> Array:
	var members: Array = spots[id]["members"].keys()
	for actor in members:
		release(int(actor))
	return members


func approaching(id: String) -> int:
	return (spots[id]["members"] as Dictionary).values().filter(func(v): return v["phase"] == "approaching").size()


func present(id: String) -> int:
	return (spots[id]["members"] as Dictionary).values().filter(func(v): return v["phase"] == "present").size()


func target(actor: int) -> Vector3:
	var s: Dictionary = spots[bookings[actor]]
	var n: int = int(s["members"][actor]["anchor"])
	return Catalog.vector(s["anchors"][n]) + Vector3(float(s["x0"]), 0, 0)


func candidates(car_id: String, activities: Array) -> Array:
	var out: Array = []
	for activity in activities:
		for id in spots:
			var s: Dictionary = spots[id]
			if s["car"] == car_id and s["activity"] == activity and s["open"] and s["members"].size() < int(s["capacity"]):
				out.append(id)
	return out
