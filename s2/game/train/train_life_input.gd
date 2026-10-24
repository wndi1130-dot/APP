extends RefCounted
## Optional display input validation. Old snapshots remain valid.
const Catalog = preload("res://game/train/train_catalog.gd")


static func check(d: Dictionary, car_ids: Array) -> PackedStringArray:
	var bad := PackedStringArray()
	for path in ["train", "comms", "view", "dom", "stop"]:
		if d.has(path) and not d[path] is Dictionary:
			bad.append("%s: not an object" % path)
	var train: Dictionary = d.get("train") if d.get("train") is Dictionary else {}
	for key in ["coal", "food", "med", "lux", "hunger", "injured", "sickCount", "stored", "decreeLeft", "seg"]:
		if train.has(key) and not number(train[key], 0, 1000000):
			bad.append("train.%s: nonnegative number required" % key)
	for key in ["fear", "tension", "trust"]:
		if train.has(key) and not finite_number(train[key]):
			bad.append("train.%s: finite number required" % key)
	if train.has("phase") and not train["phase"] is String:
		bad.append("train.phase: not a string")
	if train.has("voting") and not train["voting"] is bool:
		bad.append("train.voting: not boolean")
	for key in ["passed", "council", "edu"]:
		if train.has(key) and not train[key] is Dictionary:
			bad.append("train.%s: not an object" % key)
	var council: Dictionary = train.get("council") if train.get("council") is Dictionary else {}
	if council.has("martial") and not council["martial"] is bool:
		bad.append("train.council.martial: not boolean")
	var edu: Dictionary = train.get("edu") if train.get("edu") is Dictionary else {}
	if edu.has("side") and not edu["side"] is String:
		bad.append("train.edu.side: not a string")
	var comms: Dictionary = d.get("comms") if d.get("comms") is Dictionary else {}
	for id in comms:
		if not comms[id] is Dictionary:
			bad.append("comms.%s: not an object" % str(id))
			continue
		var comm: Dictionary = comms[id]
		for key in ["rel", "grudge"]:
			if comm.has(key) and not finite_number(comm[key]):
				bad.append("comms.%s.%s: finite number required" % [str(id), key])
		if comm.has("sit"):
			if not comm["sit"] is Array or comm["sit"].size() < 4:
				bad.append("comms.%s.sit: at least four numbers required" % str(id))
			else:
				# Context consumes the first four entries.
				for i in 4:
					if not finite_number(comm["sit"][i]):
						bad.append("comms.%s.sit[%d]: finite number required" % [str(id), i])
	var view: Dictionary = d.get("view") if d.get("view") is Dictionary else {}
	var enums := {"daytime": ["day", "night"], "motion": ["auto", "running", "stopped", "departing"],
		"season": ["late_autumn", "early_winter", "deep_winter", "early_thaw"], "riot_stage": ["none", "protest", "riot"]}
	for key in enums:
		if view.has(key) and (not view[key] is String or not enums[key].has(view[key])):
			bad.append("view.%s: unknown value" % key)
	for key in ["region", "country"]:
		if view.has(key) and not view[key] is String:
			bad.append("view.%s: not a string" % key)
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
				if not index is String or not String(index).is_valid_int() or not rows[index] is Dictionary:
					bad.append("view.actors: numeric proxy index and object required")
					continue
				var traits: Dictionary = rows[index]
				for key in ["child", "injured", "sick", "mourning"]:
					if traits.has(key) and not traits[key] is bool:
						bad.append("view.actors.%s.%s.%s: not boolean" % [str(id), index, key])
				if traits.has("role") and not traits["role"] is String:
					bad.append("view.actors.%s.%s.role: not a string" % [str(id), index])
	var dom: Dictionary = d.get("dom") if d.get("dom") is Dictionary else {}
	for key in ["wood", "scrap", "parts"]:
		if dom.has(key) and not number(dom[key], 0, 1000000):
			bad.append("dom.%s: nonnegative number required" % key)
	for key in ["insulated", "extraCars"]:
		if dom.has(key) and not dom[key] is Array:
			bad.append("dom.%s: not a list" % key)
	if dom.get("insulated") is Array and dom["insulated"].any(func(id): return not id is String):
		bad.append("dom.insulated: car id strings required")
	if dom.get("extraCars") is Array and dom["extraCars"].any(func(kind): return not kind in ["coach", "store"]):
		bad.append("dom.extraCars: coach or store required")
	if dom.has("cars") and not dom["cars"] is Array:
		bad.append("dom.cars: not a list")
	if dom.has("bedding") and not dom["bedding"] is Dictionary:
		bad.append("dom.bedding: not an object")
	var stop: Dictionary = d.get("stop") if d.get("stop") is Dictionary else {}
	if stop.has("weather") and not stop["weather"] is String:
		bad.append("stop.weather: not a string")
	if d.has("cars") and not d["cars"] is Array:
		bad.append("cars: not a list")
	if d.get("cars") is Array:
		for car in d["cars"]:
			if not car is Dictionary:
				bad.append("cars: car object required")
				continue
			for key in ["id", "kind", "comm"]:
				if car.has(key) and not car[key] is String:
					bad.append("cars.%s: not a string" % key)
			if car.has("expanded") and not car["expanded"] is bool:
				bad.append("cars.expanded: not boolean")
			if car.has("interior") and (not car["interior"] is String or not Catalog.data()["layouts"].has(car["interior"])):
				bad.append("cars.interior: unknown layout")
	return bad


static func finite_number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value))


static func number(value, lo: float, hi: float) -> bool:
	return finite_number(value) and float(value) >= lo and float(value) <= hi


static func stage(value) -> bool:
	return number(value, -1, 6) and float(value) == floorf(float(value))
