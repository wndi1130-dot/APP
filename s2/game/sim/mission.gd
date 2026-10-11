extends RefCounted
## What a stop is for, as goals that are each counted on their own
## (content_variety_first_build 2부). A goal is a list of parts; with every
## part it is done, with some it is part done. A goal with an "amount" is
## done when that much is in, and part done with any of it. Goals marked
## "extra" are there to go to or not: leaving one alone is not a part-done stop.
## Nothing here ends the stop: the player calls the departure.

const GOALS: Dictionary = {
	"survey": [
		{"id": "outside", "name": "바깥 설비", "parts": ["switch", "signal"]},
		{"id": "records", "name": "선로 기록", "parts": ["log"]},
		{"id": "deep", "name": "지하 보관실", "parts": ["store"], "extra": true},
	],
	"depot": [
		{"id": "load", "name": "석탄 싣기", "amount": 12.0},
		{"id": "repair", "name": "설비 고치기", "parts": ["begun", "running"], "extra": true},
	],
}
## How a goal stands when the stop is over.
const DONE := "done"          # 다 함
const PART := "part"          # 일부
const RETREAT := "retreat"    # 물러남: the train left with it untouched
const FAILED := "failed"      # 못 함: the stop was lost before it was touched
const NONE := "none"          # an extra goal nobody went for

var kind: String = ""
var goals: Array = []           # {"id", "name", "parts", "got", "amount", "have", "t", "extra"}
var facts: Array[String] = []   # what was learnt, as keys (S1 reads them later)


func _init(p_kind: String = "") -> void:
	kind = p_kind
	for row: Dictionary in GOALS.get(kind, []):
		goals.append({"id": row["id"], "name": row["name"], "parts": (row.get("parts", []) as Array).duplicate(), "got": [], "amount": float(row.get("amount", 0.0)), "have": 0.0, "t": -1.0, "extra": bool(row.get("extra", false))})


func goal(id: String) -> Dictionary:
	for g: Dictionary in goals:
		if g["id"] == id:
			return g
	return {}


## One part of a goal is done at field second t. True the first time only.
func mark(id: String, part: String, t: float) -> bool:
	var g := goal(id)
	if g.is_empty() or not (g["parts"] as Array).has(part) or (g["got"] as Array).has(part):
		return false
	g["got"].append(part)
	if is_done(id):
		g["t"] = t
	return true


## How much of an amount goal is in by field second t. True when that finished it.
func fill(id: String, have: float, t: float) -> bool:
	var g := goal(id)
	if g.is_empty() or float(g["amount"]) <= 0.0 or is_done(id):
		return false
	g["have"] = maxf(float(g["have"]), have)
	if is_done(id):
		g["t"] = t
		return true
	return false


func is_done(id: String) -> bool:
	var g := goal(id)
	if g.is_empty():
		return false
	if float(g["amount"]) > 0.0:
		return float(g["have"]) >= float(g["amount"]) - 0.001
	return (g["got"] as Array).size() == (g["parts"] as Array).size()


## Every goal that is not an extra is done.
func all_done() -> bool:
	if goals.is_empty():
		return false
	for g: Dictionary in goals:
		if not g["extra"] and not is_done(g["id"]):
			return false
	return true


## A fact is learnt once, wherever it was read.
func learn(fact: String) -> bool:
	if facts.has(fact):
		return false
	facts.append(fact)
	return true


func state(id: String, end_reason: String) -> String:
	var g := goal(id)
	if g.is_empty():
		return NONE
	if is_done(id):
		return DONE
	if not (g["got"] as Array).is_empty() or float(g["have"]) > 0.0:
		return PART
	if g["extra"]:
		return NONE
	return RETREAT if end_reason == "departed" else FAILED


func states(end_reason: String) -> Dictionary:
	var out := {}
	for g: Dictionary in goals:
		out[g["id"]] = state(g["id"], end_reason)
	return out


## For the run log: each goal, how it stood, and when it was finished (-1: never).
func log_rows(end_reason: String) -> Array:
	var out: Array = []
	for g: Dictionary in goals:
		out.append({"id": g["id"], "state": state(g["id"], end_reason), "t": snappedf(float(g["t"]), 0.1)})
	return out


func progress_line(id: String) -> String:
	var g := goal(id)
	if float(g["amount"]) > 0.0:
		return "%s %.1f/%.0f" % [g["name"], float(g["have"]), float(g["amount"])]
	return "%s %d/%d" % [g["name"], (g["got"] as Array).size(), (g["parts"] as Array).size()]
