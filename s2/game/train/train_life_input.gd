extends RefCounted
## Optional display input validation. Old snapshots remain valid.
const Catalog = preload("res://game/train/train_catalog.gd")


static func check(d: Dictionary, car_ids: Array) -> PackedStringArray:
	var bad := PackedStringArray()
	for path in ["view", "dom", "stop"]:
		if d.has(path) and not d[path] is Dictionary:
			bad.append("%s: not an object" % path)
	var train: Dictionary = d.get("train") if d.get("train") is Dictionary else {}
	for key in ["coal", "food", "med", "lux", "hunger", "injured", "sickCount", "stored", "decreeLeft", "seg"]:
		if train.has(key) and not number(train[key], 0, 1000000):
			bad.append("train.%s: nonnegative number required" % key)
	for key in ["passed", "council", "edu"]:
		if train.has(key) and not train[key] is Dictionary:
			bad.append("train.%s: not an object" % key)
	var view: Dictionary = d.get("view") if d.get("view") is Dictionary else {}
	var enums := {"daytime": ["day", "night"], "motion": ["auto", "running", "stopped", "departing"],
		"season": ["deep_winter", "late_winter", "thaw"], "riot_stage": ["none", "protest", "riot"]}
	for key in enums:
		if view.has(key) and not enums[key].has(view[key]):
			bad.append("view.%s: unknown value" % key)
	for key in ["work_time", "meal_time", "memorial", "accident", "teacher_present", "aftermath"]:
		if view.has(key) and not view[key] is bool:
			bad.append("view.%s: not boolean" % key)
	if view.has("collapse_override") and not stage(view["collapse_override"]):
		bad.append("view.collapse_override: integer -1 to 6 required")
	if view.has("fire_cars"):
		if not view["fire_cars"] is Array or (view["fire_cars"] as Array).any(func(id): return not car_ids.has(id)):
			bad.append("view.fire_cars: known car ids required")
	for key in ["actors", "outside", "collapse_by_car"]:
		if view.has(key) and not view[key] is Dictionary:
			bad.append("view.%s: not an object" % key)
	if view.get("collapse_by_car") is Dictionary:
		for id in view["collapse_by_car"]:
			if not car_ids.has(id) or not stage(view["collapse_by_car"][id]):
				bad.append("view.collapse_by_car: known car and stage required")
	if view.get("actors") is Dictionary:
		for id in view["actors"]:
			var rows = view["actors"][id]
			if not car_ids.has(id) or not rows is Dictionary:
				bad.append("view.actors: known car and object required")
				continue
			for index in rows:
				if not String(index).is_valid_int() or not rows[index] is Dictionary:
					bad.append("view.actors: numeric proxy index and object required")
	var dom: Dictionary = d.get("dom") if d.get("dom") is Dictionary else {}
	for key in ["wood", "scrap", "parts"]:
		if dom.has(key) and not number(dom[key], 0, 1000000):
			bad.append("dom.%s: nonnegative number required" % key)
	for key in ["insulated", "extraCars"]:
		if dom.has(key) and not dom[key] is Array:
			bad.append("dom.%s: not a list" % key)
	if dom.get("extraCars") is Array and dom["extraCars"].any(func(kind): return not kind in ["coach", "store"]):
		bad.append("dom.extraCars: coach or store required")
	if dom.has("cars") and not dom["cars"] is Array:
		bad.append("dom.cars: not a list")
	if dom.has("bedding") and not dom["bedding"] is Dictionary:
		bad.append("dom.bedding: not an object")
	if d.get("cars") is Array:
		for car in d["cars"]:
			if car is Dictionary and car.has("interior") and not Catalog.data()["layouts"].has(car["interior"]):
				bad.append("cars.interior: unknown layout")
	return bad


static func number(value, lo: float, hi: float) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) >= lo and float(value) <= hi


static func stage(value) -> bool:
	return number(value, -1, 6) and float(value) == floorf(float(value))
