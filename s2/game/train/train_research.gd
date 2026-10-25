extends RefCounted
## PR 6. S1 domestic/workshop.ts and state.ts, with experts as the only knowledge source.
## Data below is copied from the S1 export and checked against tech-vectors-v1.

const TrainHands = preload("res://game/train/train_hands.gd")
const VISIBLE: Array[String] = ["w1", "e5"]
# BEGIN S1 TABLES
const TECHS: Dictionary = {
	"e1": {
		"upkeep": {},
		"like": [
			"engine"
		],
		"dislike": [],
		"id": "e1",
		"branch": "engine",
		"tier": 1,
		"name": "누설 막기",
		"effect": "눈 녹이기 당번: 온기 벌 없음, 노출 벌 절반"
	},
	"e2": {
		"upkeep": {
			"parts": 0.25
		},
		"like": [
			"engine",
			"front"
		],
		"dislike": [],
		"id": "e2",
		"branch": "engine",
		"tier": 2,
		"name": "압력 조절",
		"effect": "난방 배당: 꼬리칸·의무진 온기 −10 → −5, 경비대 벌 없음"
	},
	"e3": {
		"upkeep": {
			"parts": 0.25
		},
		"like": [],
		"dislike": [],
		"id": "e3",
		"branch": "engine",
		"tier": 2,
		"name": "난방 배관",
		"effect": "변형 둘 중 하나",
		"variants": {
			"a": {
				"name": "꼬리칸까지",
				"effect": "공동 난방의 석탄 +1.25 → +0.6/구간",
				"upkeep": {
					"parts": 0.25
				},
				"like": [
					"tail"
				],
				"dislike": [
					"front"
				],
				"label": "꼬리칸까지 놓는다",
				"say": "열은 맨 끝 칸까지 간다!"
			},
			"b": {
				"name": "앞칸 직결",
				"effect": "난방 배당: 경비대 벌 없음, 앞칸 온기 +5",
				"upkeep": {
					"parts": 0.25
				},
				"like": [
					"front"
				],
				"dislike": [
					"tail"
				],
				"label": "앞칸에 잇는다",
				"say": "앞이 얼면 열차가 멈춘다. 앞부터 데워라!"
			}
		}
	},
	"e4": {
		"upkeep": {
			"parts": 0.5
		},
		"like": [
			"engine"
		],
		"dislike": [],
		"id": "e4",
		"branch": "engine",
		"tier": 3,
		"name": "과열 증기",
		"effect": "눈 녹이기 당번: 노출 벌 없음. 대체 화부의 석탄 벌 없음"
	},
	"e5": {
		"upkeep": {},
		"like": [
			"tail"
		],
		"dislike": [
			"engine"
		],
		"id": "e5",
		"branch": "engine",
		"tier": 0,
		"name": "단열 개조",
		"effect": "단열 개조가 열린다(칸마다 목재 8). 단열한 객차는 난방 배당의 온기 벌이 없다",
		"adapt": {
			"parts": 0,
			"wood": 6
		}
	},
	"m1": {
		"upkeep": {},
		"like": [
			"medtech"
		],
		"dislike": [],
		"id": "m1",
		"branch": "med",
		"tier": 1,
		"name": "응급 처치",
		"effect": "새 부상이 하루 빨리 낫는다, 발진티푸스 사망 15% → 10%"
	},
	"m2": {
		"upkeep": {},
		"like": [
			"medtech"
		],
		"dislike": [
			"tail"
		],
		"id": "m2",
		"branch": "med",
		"tier": 2,
		"name": "환자 분류 기준",
		"effect": "중환자 분류(기준) 법이 열린다"
	},
	"m3": {
		"upkeep": {},
		"like": [],
		"dislike": [],
		"id": "m3",
		"branch": "med",
		"tier": 2,
		"name": "식량 보존",
		"effect": "변형 둘 중 하나",
		"variants": {
			"a": {
				"name": "훈제·염장",
				"effect": "종자곡 풀기에 '반만 풀기' 변형이 열린다(식량 +15, 앞칸 −10)",
				"upkeep": {
					"wood": 0.5
				},
				"like": [
					"tail"
				],
				"dislike": [
					"front"
				],
				"label": "훈제로 간다",
				"say": "연기에 걸어라. 나무는 또 주우면 된다!"
			},
			"b": {
				"name": "얼음 상자",
				"effect": "공동 식당의 식량 값 +5 → +3.5/구간, 창고칸 자재 상한 40 → 34",
				"like": [
					"tail"
				],
				"dislike": [],
				"upkeep": {},
				"label": "얼음 상자를 짠다",
				"say": "바깥 얼음을 퍼 와라. 남는 음식은 묵힌다!"
			}
		}
	},
	"m4": {
		"upkeep": {
			"coal": 1,
			"parts": 0.5
		},
		"like": [
			"tail"
		],
		"dislike": [],
		"id": "m4",
		"branch": "med",
		"tier": 3,
		"name": "온실칸",
		"effect": "칸 하나를 온실로(식량 +1.5~4.5/구간)"
	},
	"m5": {
		"upkeep": {},
		"like": [
			"tail"
		],
		"dislike": [
			"medtech"
		],
		"id": "m5",
		"branch": "med",
		"tier": 0,
		"name": "약초와 민간요법",
		"effect": "모두를 치료의 의약품 소모 ×1.6 → ×1.3, 이가 병으로 번질 확률 40% → 25%",
		"adapt": {
			"parts": 0,
			"wood": 2
		}
	},
	"w1": {
		"upkeep": {},
		"like": [
			"medtech"
		],
		"dislike": [],
		"id": "w1",
		"branch": "craft",
		"tier": 1,
		"name": "공구 수리",
		"effect": "공방 작업량 ×1.25"
	},
	"w2": {
		"upkeep": {},
		"like": [],
		"dislike": [],
		"id": "w2",
		"branch": "craft",
		"tier": 2,
		"name": "사냥과 방어",
		"effect": "변형 둘 중 하나",
		"variants": {
			"a": {
				"name": "탄약 재장전",
				"effect": "정차 부상·사망 ×0.85, 고철 0.5/구간",
				"upkeep": {
					"scrap": 0.5
				},
				"like": [
					"guard"
				],
				"dislike": [],
				"label": "탄약을 다시 만든다",
				"say": "빈 탄피도 줍는다. 한 발도 버리지 마라!"
			},
			"b": {
				"name": "활·석궁",
				"effect": "정차 부상·사망 ×0.9, 길게 머물 때 위험 −10%",
				"upkeep": {
					"wood": 0.3
				},
				"like": [
					"tail"
				],
				"dislike": [
					"guard"
				],
				"label": "활을 깎는다",
				"say": "조용히 쏘는 게 오래 산다. 활을 깎아라!"
			}
		}
	},
	"w3": {
		"upkeep": {
			"parts": 0.5
		},
		"like": [
			"guard"
		],
		"dislike": [
			"tail"
		],
		"id": "w3",
		"branch": "craft",
		"tier": 3,
		"name": "장갑 객차",
		"effect": "장갑 개조가 열린다(칸마다 고철 12). 경비대칸이면 노출 −10"
	},
	"w4": {
		"upkeep": {},
		"like": [
			"tail"
		],
		"dislike": [],
		"id": "w4",
		"branch": "craft",
		"tier": 0,
		"name": "태엽 소리 미끼",
		"effect": "정찰 뒤 미끼를 걸면 바깥 기척이 한 단계 내려간다(한 번에 부품 1)",
		"adapt": {
			"parts": 1,
			"wood": 2
		}
	},
	"r1": {
		"upkeep": {},
		"like": [
			"guard"
		],
		"dislike": [],
		"id": "r1",
		"branch": "radio",
		"tier": 1,
		"name": "단거리 무전",
		"effect": "정차 사망 ×0.85"
	},
	"r2": {
		"upkeep": {
			"parts": 0.25
		},
		"like": [],
		"dislike": [],
		"id": "r2",
		"branch": "radio",
		"tier": 2,
		"name": "무전의 쓰임",
		"effect": "변형 둘 중 하나",
		"variants": {
			"a": {
				"name": "감청",
				"effect": "회기마다 비밀 확률 +25%",
				"upkeep": {
					"parts": 0.25
				},
				"like": [
					"guard"
				],
				"dislike": [
					"tail"
				],
				"label": "감청한다",
				"say": "모든 칸의 말을 듣는다. 열차장은 알아야 한다!"
			},
			"b": {
				"name": "열차 방송",
				"effect": "긴장 증가 −1/구간, 공포 +1/구간",
				"upkeep": {
					"parts": 0.25
				},
				"like": [
					"guard",
					"engine"
				],
				"dislike": [
					"tail",
					"medtech"
				],
				"label": "방송을 튼다",
				"say": "매일 아침 열차장의 목소리를 듣게 해라!"
			}
		}
	},
	"r3": {
		"upkeep": {
			"parts": 0.5
		},
		"like": [
			"medtech"
		],
		"dislike": [],
		"id": "r3",
		"branch": "radio",
		"tier": 3,
		"name": "장거리 무전",
		"effect": "다음 정차를 미리 알고, 판에 세 번 다른 곳으로 바꾼다"
	},
	"r4": {
		"upkeep": {},
		"like": [],
		"dislike": [],
		"id": "r4",
		"branch": "radio",
		"tier": 1,
		"name": "선로 관측",
		"effect": "변형 둘 중 하나",
		"variants": {
			"a": {
				"name": "기관사 망원경",
				"effect": "정찰조 다침·못 돌아옴 ×0.4. 안개·눈보라·진눈깨비엔 효과 없음. 만들 때 부품 2 더",
				"upkeep": {},
				"like": [
					"guard"
				],
				"dislike": [],
				"label": "망원경을 닦는다",
				"say": "둑 위에서 멀리 본다. 안 들어가도 보인다!"
			},
			"b": {
				"name": "철도 수신호",
				"effect": "정찰조 2명 → 1명(표결 빠짐 한 명). 혼자라 정찰조 위험 ×2",
				"upkeep": {},
				"like": [
					"tail"
				],
				"dislike": [],
				"label": "수신호를 맞춘다",
				"say": "한 명만 들어가라. 나머지는 깃발만 본다!"
			}
		}
	},
	"x1": {
		"upkeep": {},
		"like": [
			"tail"
		],
		"dislike": [],
		"id": "x1",
		"branch": "expedition",
		"tier": 1,
		"name": "짐 꾸리기·방한 장비",
		"effect": "아동 노동에 '짐 꾸리기만' 변형이 열린다(아이들은 내리지 않는다)"
	},
	"x2": {
		"upkeep": {
			"parts": 0.25
		},
		"like": [
			"guard"
		],
		"dislike": [],
		"id": "x2",
		"branch": "expedition",
		"tier": 2,
		"name": "핸드카 정찰",
		"effect": "정차마다 장소 후보가 둘",
		"variants": {
			"a": {
				"name": "페달 핸드카",
				"effect": "정찰 산출 깎임 −20% → −10%. 고요한 곳에선 덜컹이는 소리에 기척 +1",
				"upkeep": {
					"parts": 0.25
				},
				"like": [
					"tail"
				],
				"dislike": [],
				"label": "페달을 단다",
				"say": "발로 밟아 조용히 다녀온다!"
			},
			"b": {
				"name": "발동기 핸드카",
				"effect": "정찰조 위험 ×0.4, 정찰 산출 깎임 없음. 발동기 소리에 늘 기척 +2",
				"upkeep": {
					"parts": 0.25
				},
				"like": [
					"guard"
				],
				"dislike": [
					"engine"
				],
				"label": "발동기를 얹는다",
				"say": "들어갔다 바로 빠진다. 소리는 감수한다!"
			}
		}
	},
	"x3": {
		"upkeep": {
			"parts": 0.5
		},
		"like": [
			"guard"
		],
		"dislike": [
			"engine"
		],
		"id": "x3",
		"branch": "expedition",
		"tier": 3,
		"name": "궤도 모터카",
		"effect": "지나쳐도 짧게의 절반을 얻는다(석탄 1)"
	}
}
const D: Dictionary = {
	"restoreWork": [
		3,
		3,
		6,
		12
	],
	"restoreParts": [
		0,
		0,
		0,
		4
	],
	"restoreWood": [
		0,
		4,
		10,
		0
	],
	"restoreScrap": [
		0,
		0,
		4,
		10
	],
	"restoreFrags": [
		0,
		1,
		2,
		3
	],
	"defectFrags": [
		0,
		1,
		1,
		2
	],
	"adaptWork": 3,
	"finishWork": 2,
	"work": 4,
	"workSkill": [
		0.5,
		0.75,
		1,
		1.25
	],
	"w1Work": 1.25,
	"partWork": 1,
	"partScrap": 2,
	"partWood": 1,
	"target0": 5,
	"targetMax": 10,
	"defectMult": 0.5,
	"knowledgeLow": 0.7,
	"glassParts": 2
}
const FIELDS: Array = [
	"engine",
	"med",
	"craft",
	"radio",
	"expedition"
]
const BRANCH_NAME: Dictionary = {
	"engine": "증기·기관",
	"med": "생존·의료",
	"craft": "공작·무기",
	"radio": "통신·정보",
	"expedition": "원정·파견"
}
const ZONE_WORK: Dictionary = {
	"front": 1,
	"middle": 0.8,
	"back": 0.8
}
const ZONE0: Dictionary = {
	"workshop": "front",
	"front": "front",
	"captain": "front",
	"guard": "middle",
	"dining": "middle",
	"medtech": "middle",
	"store": "back",
	"cold": "back",
	"tail1": "back",
	"tail2": "back",
	"tail3": "back"
}
const NOT_YET: Array = [
	"r3"
]
const GEAR_TECHS: Array = [
	"r4",
	"w4"
]
# END S1 TABLES


static func _dom(g: Dictionary) -> Dictionary:
	return g.get("dom", {}) if g.get("dom") is Dictionary else {}


static func _ensure(g: Dictionary) -> Dictionary:
	if not g.get("dom") is Dictionary:
		g["dom"] = {}
	var d: Dictionary = g["dom"]
	if not d.has("techs"):
		d["techs"] = {}
	if not d.has("restoring"):
		d["restoring"] = null
	if not d.has("frags"):
		d["frags"] = {}
	return d


static func top_skill(g: Dictionary, field: String) -> int:
	var top: int = 0
	for expert: Dictionary in _dom(g).get("experts", []):
		if expert.get("field") == field:
			top = maxi(top, int(expert.get("skill", 0)))
	return top


static func usable(g: Dictionary, _t: Dictionary, id: String) -> bool:
	var st: Dictionary = _dom(g).get("techs", {}).get(id, {})
	return st.get("stage") in ["done", "defective"]


static func mult(g: Dictionary, t: Dictionary, id: String) -> float:
	var st: Dictionary = _dom(g).get("techs", {}).get(id, {})
	if not TECHS.has(id) or not usable(g, t, id) or bool(st.get("off", false)):
		return 0.0
	var m: float = float(D["defectMult"]) if st.get("stage") == "defective" else 1.0
	if bool(st.get("starved", false)):
		m = minf(m, float(D["defectMult"]))
	var def: Dictionary = TECHS[id]
	var tier: int = int(def["tier"])
	var skill: int = top_skill(g, String(def["branch"]))
	if tier == 0 or skill >= 3:
		return m
	if skill == 2:
		return m * (float(D["knowledgeLow"]) if tier == 3 and top_skill(g, "craft") < 3 else 1.0)
	if skill == 1:
		return m * (float(D["knowledgeLow"]) if tier >= 2 else 1.0)
	return 0.0


## S1's screen filter, separate from decision 446's narrower S2 exposure.
static func visible_techs(g: Dictionary) -> Array[String]:
	var out: Array[String] = []
	for id: String in TECHS:
		if not GEAR_TECHS.has(id) or bool(g.get("gearOn", false)):
			out.append(id)
	return out


static func visible(g: Dictionary, _t: Dictionary = {}) -> Array[String]:
	var out: Array[String] = []
	# Keep existing rows in place when another working effect becomes visible.
	var shown: Array[String] = visible_techs(g)
	for id: String in VISIBLE:
		if shown.has(id) and not NOT_YET.has(id):
			out.append(id)
	return out


static func prereqs(id: String) -> Array[String]:
	var def: Dictionary = TECHS[id]
	var out: Array[String] = []
	if int(def["tier"]) <= 1:
		return out
	for other: String in TECHS:
		if TECHS[other]["branch"] == def["branch"] and int(TECHS[other]["tier"]) == int(def["tier"]) - 1:
			out.append(other)
	return out


static func restore_cost(id: String) -> Dictionary:
	var def: Dictionary = TECHS[id]
	var tier: int = int(def["tier"])
	if tier == 0:
		var adapt: Dictionary = def.get("adapt", {})
		return {"parts": adapt.get("parts", 0), "frags": 0, "defectFrags": 0, "core": 0,
			"wood": adapt.get("wood", 0), "scrap": 0, "work": D["adaptWork"]}
	return {"parts": D["restoreParts"][tier], "frags": D["restoreFrags"][tier], "defectFrags": D["defectFrags"][tier],
		"core": 1 if tier == 3 else 0, "wood": D["restoreWood"][tier], "scrap": D["restoreScrap"][tier], "work": D["restoreWork"][tier]}


static func restore_block(g: Dictionary, id: String) -> Variant:
	var d: Dictionary = _dom(g)
	var def: Dictionary = TECHS[id]
	if d.get("techs", {}).has(id):
		return "이미 손댔다"
	if NOT_YET.has(id) or (GEAR_TECHS.has(id) and not bool(g.get("gearOn", false))):
		return "아직 이 열차에서 못 쓴다"
	var pre: Array[String] = prereqs(id)
	var known: bool = false
	for p: String in pre:
		known = known or usable(g, {}, p)
	if not pre.is_empty() and not known:
		return String(TECHS[pre[0]]["name"]) + "부터"
	var tier: int = int(def["tier"])
	var skill: int = top_skill(g, String(def["branch"]))
	var second: bool = tier == 3 and def["branch"] != "craft" and skill >= 2 and top_skill(g, "craft") >= 3
	if skill < tier and not second:
		return ["", "견습", "숙련", "장인"][tier] + " 이상이 없다" + ("(숙련 + 공작 장인이어도 된다)" if tier == 3 else "")
	if int(restore_cost(id)["core"]) > float(d.get("cores", 0)):
		return "코어가 없다"
	return null


static func restore_check(g: Dictionary, id: String) -> Dictionary:
	var d: Dictionary = _dom(g)
	var cost: Dictionary = restore_cost(id)
	var out: Dictionary = {"offer": false, "fragsNeed": cost["frags"], "defectNeed": cost["defectFrags"],
		"parts": cost["parts"], "core": cost["core"], "wood": cost["wood"], "scrap": cost["scrap"]}
	var blocked: Variant = restore_block(g, id)
	if blocked != null:
		out["full"] = blocked
		out["defect"] = blocked
		return out
	var frags: float = float(d.get("frags", {}).get(TECHS[id]["branch"], 0))
	var has_defect: bool = int(cost["defectFrags"]) < int(cost["frags"])
	out["offer"] = frags >= float(cost["defectFrags"] if has_defect else cost["frags"])
	var common: Variant = null
	if d.get("restoring") != null:
		common = "공방이 다른 복원 중"
	elif float(d.get("parts", 0)) < float(cost["parts"]):
		common = "부품이 모자라다"
	elif float(d.get("wood", 0)) < float(cost["wood"]):
		common = "목재가 모자라다"
	elif float(d.get("scrap", 0)) < float(cost["scrap"]):
		common = "고철이 모자라다"
	var full: Variant = "설계도 조각이 모자라다" if frags < float(cost["frags"]) else common
	var defect: Variant = common
	if not has_defect:
		defect = "없다"
	elif frags < float(cost["defectFrags"]):
		defect = "설계도 조각이 모자라다"
	elif frags >= float(cost["frags"]):
		defect = "완성판으로 된다"
	if full != null:
		out["full"] = full
	if defect != null:
		out["defect"] = defect
	return out


static func finish_check(g: Dictionary, id: String) -> Variant:
	var d: Dictionary = _dom(g)
	var st: Dictionary = d.get("techs", {}).get(id, {})
	if st.get("stage") != "defective" or bool(st.get("finishing", false)):
		return "결함판이 아니다"
	var cost: Dictionary = restore_cost(id)
	if float(d.get("frags", {}).get(TECHS[id]["branch"], 0)) < float(cost["frags"]) - float(cost["defectFrags"]):
		return "설계도 조각이 모자라다"
	if d.get("restoring") != null:
		return "공방이 다른 복원 중"
	return null


static func variants(g: Dictionary, id: String) -> Dictionary:
	return {} if id == "x2" and not bool(g.get("gearOn", false)) else TECHS[id].get("variants", {})


static func start_restore(g: Dictionary, id: String, mode: String, variant: Variant = null) -> bool:
	if not TECHS.has(id) or mode not in ["full", "defect"]:
		return false
	if restore_check(g, id).get(mode) != null:
		return false
	if not variants(g, id).is_empty() and variant == null:
		return false
	if variant != null and variant not in ["a", "b"]:
		return false
	var cost: Dictionary = restore_cost(id)
	var extra: float = float(D["glassParts"]) if id == "r4" and variant == "a" else 0.0
	if float(_dom(g).get("parts", 0)) < float(cost["parts"]) + extra:
		return false
	var d: Dictionary = _ensure(g)
	for key: String in ["parts", "wood", "scrap"]:
		d[key] = float(d.get(key, 0)) - float(cost[key]) - (extra if key == "parts" else 0.0)
	var field: String = String(TECHS[id]["branch"])
	d["frags"][field] = float(d["frags"].get(field, 0)) - float(cost["frags"] if mode == "full" else cost["defectFrags"])
	d["cores"] = float(d.get("cores", 0)) - float(cost["core"])
	var st: Dictionary = {"stage": "restoring", "defect": mode == "defect", "progress": 0, "need": cost["work"]}
	if variant != null:
		st["variant"] = variant
	if id == "e3":
		st["pending"] = true
	d["techs"][id] = st
	d["restoring"] = id
	return true


static func start_finish(g: Dictionary, id: String) -> bool:
	if finish_check(g, id) != null:
		return false
	var d: Dictionary = _ensure(g)
	var cost: Dictionary = restore_cost(id)
	var field: String = String(TECHS[id]["branch"])
	d["frags"][field] = float(d["frags"].get(field, 0)) - float(cost["frags"]) + float(cost["defectFrags"])
	var st: Dictionary = d["techs"][id]
	st["finishing"] = true
	st["progress"] = 0
	st["need"] = D["finishWork"]
	d["restoring"] = id
	return true


static func cancel_restore(g: Dictionary) -> void:
	var d: Dictionary = _dom(g)
	if d.get("restoring") == null:
		return
	var id: String = String(d["restoring"])
	var st: Dictionary = d.get("techs", {}).get(id, {})
	var cost: Dictionary = restore_cost(id)
	var field: String = String(TECHS[id]["branch"])
	if bool(st.get("finishing", false)):
		d["frags"][field] = float(d["frags"].get(field, 0)) + float(cost["frags"]) - float(cost["defectFrags"])
		st["finishing"] = false
		st["progress"] = 0
	elif not st.is_empty():
		d["frags"][field] = float(d["frags"].get(field, 0)) + float(cost["defectFrags"] if bool(st.get("defect", false)) else cost["frags"])
		d["cores"] = float(d.get("cores", 0)) + float(cost["core"])
		d["techs"].erase(id)
	d["restoring"] = null


## Spend only the work remaining after parts and the S2 making line.
static func advance_restore(g: Dictionary, work: float) -> Dictionary:
	var d: Dictionary = _dom(g)
	if work <= 0.0 or d.get("restoring") == null:
		return {"used": 0.0, "did": []}
	var id: String = String(d["restoring"])
	var st: Dictionary = d["techs"][id]
	var spend: float = minf(work, float(st["need"]) - float(st["progress"]))
	st["progress"] = float(st["progress"]) + spend
	var did: Array[String] = []
	if float(st["progress"]) >= float(st["need"]) - 1e-9 and not bool(st.get("pending", false)):
		d["restoring"] = null
		if bool(st.get("finishing", false)):
			st["finishing"] = false
			st["stage"] = "done"
		else:
			st["stage"] = "defective" if bool(st.get("defect", false)) else "done"
		did.append(String(TECHS[id]["name"]) + " 복원")
	return {"used": spend, "did": did}


static func upkeep_of(g: Dictionary, id: String) -> Dictionary:
	var def: Dictionary = TECHS[id]
	var variant: Variant = _dom(g).get("techs", {}).get(id, {}).get("variant")
	return def["variants"][variant]["upkeep"].duplicate(true) if def.has("variants") and variant != null else def["upkeep"].duplicate(true)


static func pay_upkeep(g: Dictionary) -> Array[String]:
	var d: Dictionary = _dom(g)
	var starved: Array[String] = []
	for id: String in TECHS:
		var st: Dictionary = d.get("techs", {}).get(id, {})
		if st.is_empty():
			continue
		st["starved"] = false
		if bool(st.get("off", false)) or not usable(g, {}, id) or mult(g, {}, id) <= 0.0:
			continue
		var upkeep: Dictionary = upkeep_of(g, id)
		var enough: bool = true
		for key: String in ["parts", "wood", "scrap"]:
			enough = enough and float(d.get(key, 0)) >= float(upkeep.get(key, 0))
		if not enough:
			st["starved"] = true
			starved.append(id)
			continue
		for key: String in ["parts", "wood", "scrap"]:
			d[key] = float(d.get(key, 0)) - float(upkeep.get(key, 0))
	return starved


static func work_power(g: Dictionary, t: Dictionary = {}) -> float:
	# Old S1a saves have no expert roster: preserve their already-ported 4 work.
	var craft: int = top_skill(g, "craft") if _dom(g).has("experts") else 2
	# PR 6 has the original front workshop; moving cars is a later contract.
	return float(D["work"]) * float(D["workSkill"][craft]) * float(ZONE_WORK[ZONE0["workshop"]]) * (1.0 + (float(D["w1Work"]) - 1.0) * mult(g, t, "w1")) * TrainHands.hands_work_mult(g, t)
