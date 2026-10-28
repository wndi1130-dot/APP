extends RefCounted
## One snapshot per input event. No simulation, costs, damage or political effects.

const Catalog = preload("res://game/train/train_catalog.gd")
const Look = preload("res://game/train/train_look.gd")
const SeasonTable = preload("res://game/season_table.gd")
## Whose hands a car's work places stand for (train_hands.gd jobs, carry_people 3.6):
## the engine crew's shovels are the firebox shifts, the workshop's bench the repairs,
## the guard car's lanterns at the windows the roof watch.
const JOB_OF := {"engine_room": "stoker", "technical": "repair", "guard": "watch"}
## How short of hands a job may be before its second work place, then its first,
## stands empty (train_hands.gd short: 0 none missing .. 1 nobody at it).
const SECOND_GONE: float = 0.5
const FIRST_GONE: float = 0.99


static func read(rules: Dictionary, car: Dictionary) -> Dictionary:
	var train: Dictionary = rules.get("train", {})
	var view: Dictionary = rules.get("view", {})
	var dom: Dictionary = rules.get("dom", {})
	var comm: Dictionary = rules.get("comms", {}).get(car.get("comm", ""), {})
	var sit: Array = comm.get("sit", [70, 70, 0, 0])
	var laws: Dictionary = train.get("passed", {})
	var council: bool = String(train.get("phase", "")) == "council"
	var night: bool = String(view.get("daytime", "day")) == "night"
	var motion: String = String(view.get("motion", "auto"))
	if motion == "auto":
		motion = "stopped" if String(train.get("phase", "")) == "stop" or train.get("stranded") != null else "running"
	var educational: bool = laws.has("edu_letters") or laws.has("edu_trade") or laws.has("edu_engine")
	var fire: bool = (view.get("fire_cars", []) as Array).has(car.get("id", ""))
	var warm: float = float(sit[0])
	var ration: float = float(sit[1])
	var fuel: bool = float(train.get("coal", 100)) >= float(Catalog.tuning("resource_low"))
	var food: bool = float(train.get("food", 100)) >= float(Catalog.tuning("resource_low"))
	var patients: int = maxi(0, int(train.get("injured", 0)) + int(train.get("sickCount", 0)))
	var stage := stage_of(train, comm, view, fire)
	var car_stage: int = int(view.get("collapse_by_car", {}).get(car.get("id", ""), -1))
	if car_stage >= 0:
		stage = clampi(car_stage, 0, 6)
	# 불난 칸은 화면 단계를 어떻게 덮어써도 일상 자리를 열지 않는다.
	var burning: bool = fire or stage == 5
	var peaceful: bool = (stage < 3 or stage == 6) and not burning
	var work: bool = bool(view.get("work_time", false)) and not night and not council and peaceful
	# The hands the turn settled; without a share nothing is missing.
	var hands: Variant = train.get("hands")
	var short: Dictionary = (hands as Dictionary).get("short", {}) if hands is Dictionary else {}
	var job: String = String(JOB_OF.get(Catalog.layout_id(car), ""))
	var job_short: float = clampf(float(short.get(job, 0.0)), 0.0, 1.0) if job != "" else 0.0
	# Every car's stove is kept by the stove hands, whichever car it is in.
	var stove_short: float = clampf(float(short.get("stove", 0.0)), 0.0, 1.0)
	var c := {
		"car_id": String(car.get("id", "")), "layout": Catalog.layout_id(car),
		"warmth": warm, "ration": ration, "crowding": float(sit[2]), "exposure": float(sit[3]),
		"fear": float(train.get("fear", 0)), "tension": float(train.get("tension", 0)),
		"trust": float(train.get("trust", 50)), "hunger": int(train.get("hunger", 0)),
		"rel": float(comm.get("rel", 0)), "grudge": int(comm.get("grudge", 0)),
		"council": council, "voting": council and bool(train.get("voting", false)),
		"night": night, "motion": motion, "stopped": motion == "stopped", "stage": stage,
		"fire": burning, "safe": not burning,
		"recovery": stage == 6 and not burning,
		"food": food, "coal": fuel, "medicine": float(train.get("med", 20)) > 0,
		"goods": float(train.get("lux", 0)) > 0,
		"patients": patients > 0, "patient_count": patients,
		# Nobody left to keep the stoves leaves no place at them; half of them missing, room for one (train_places.gd).
		"stove": fuel and warm >= Look.WARM_FREEZING and stage < 4 and not burning and stove_short < FIRST_GONE,
		"stove_half": stove_short >= SECOND_GONE,
		"meal": food and not council and bool(view.get("meal_time", true)) and peaceful,
		"work": work,
		# A short job leaves its work places empty, the second then the first; the ones left get their breath back.
		"hands_job": job, "job_short": job_short, "work_first": work and job_short < FIRST_GONE, "work_second": work and job_short < SECOND_GONE,
		# The watch keeps its posts day and night, so they do not wait for work time.
		"post_first": job_short < FIRST_GONE, "post_second": job_short < SECOND_GONE,
		"social": not council and float(train.get("fear", 0)) < Look.FEAR_FROZEN and peaceful,
		"gather": stage >= 2 and stage <= 4 and not council and not burning,
		"memorial": (bool(view.get("memorial", false)) or (laws.has("night_of_names") and night)) and not council and peaceful,
		"classroom": educational and not night and not council and peaceful and bool(view.get("teacher_present", true)),
		"education": String(train.get("edu", {}).get("side", "")),
		"child_work": laws.has("child_labor") or laws.has("child_pack"),
		"half_class": educational and (laws.has("child_labor") or laws.has("child_pack")),
		"common_kitchen": laws.has("common_kitchen"), "contribution_ration": laws.has("contribution_ration"),
		"authority": bool(train.get("council", {}).get("martial", false)) or int(train.get("decreeLeft", 0)) > 0 or laws.has("emergency_powers"),
		"materials": float(dom.get("wood", 10)) + float(dom.get("scrap", 10)) + float(dom.get("parts", 4)) > 0,
		"insulated": (dom.get("insulated", []) as Array).has(car.get("id", "")),
		"expanded": bool(car.get("expanded", false)),
		"bedding": not (dom.get("bedding", {}) as Dictionary).has(car.get("comm", "")),
		"stored": int(train.get("stored", 0)) > 0 and laws.has("corpse_store"),
		"bed_order": dom.get("bedOrder", ""), "full_rule": dom.get("fullRule", ""),
		"martial": bool(train.get("council", {}).get("martial", false)),
		"emergency": int(train.get("decreeLeft", 0)) > 0 or laws.has("emergency_powers"),
		"weather": String(rules.get("stop", {}).get("weather", "overcast")),
		"seg": int(train.get("seg", 1)), "region": String(view.get("region", "region_01")),
		"country": String(view.get("country", "country_a")), "season": String(view.get("season", SeasonTable.season_of_seg(int(train.get("seg", 1))))),
		"outside": view.get("outside", {}), "accident": bool(view.get("accident", false)),
		# Crowding steps (train_look.gd crowd_level): more sacks, crates and bedding on the floor.
		"crowd1": Look.crowd_level(float(sit[2])) >= 1, "crowd2": Look.crowd_level(float(sit[2])) >= 2,
		"crowd3": Look.crowd_level(float(sit[2])) >= 3,
	}
	return c


static func stage_of(train: Dictionary, comm: Dictionary, view: Dictionary, fire: bool = false) -> int:
	var override: int = int(view.get("collapse_override", -1))
	if override >= 0:
		return clampi(override, 0, 6)
	if fire:
		return 5
	if bool(view.get("aftermath", false)):
		return 6
	match String(view.get("riot_stage", "none")):
		"riot": return 4
		"protest": return 3
	# These are visible bands, not the rule that starts a riot or a demand card.
	if float(train.get("fear", 0)) >= Look.FEAR_FROZEN:
		return 1
	if float(train.get("tension", 0)) >= float(Catalog.tuning("stage_protest")):
		return 3
	if float(train.get("tension", 0)) >= Look.TENSION_STIR or float(comm.get("rel", 0)) <= Look.REL_STIR or int(comm.get("grudge", 0)) >= Look.GRUDGE_STIR:
		return 2
	var sit: Array = comm.get("sit", [70, 70, 0, 0])
	return 1 if minf(float(sit[0]), float(sit[1])) < Look.LOW_BELOW or int(train.get("hunger", 0)) > 0 else 0


static func is_open(condition: String, c: Dictionary) -> bool:
	return condition == "always" or bool(c.get(condition, false))
