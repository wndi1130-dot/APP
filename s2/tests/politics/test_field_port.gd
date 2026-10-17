extends "res://addons/gut/test.gd"

const V = preload("res://tests/politics/field_vectors.gd")
const FieldReturn = preload("res://game/politics/field_return.gd")
const CouncilVote = preload("res://game/politics/council_vote.gd")
const FieldCouncil = preload("res://game/politics/field_council.gd")
const FieldArrival = preload("res://game/politics/field_arrival.gd")

var _tables: Dictionary


func before_all() -> void:
	_tables = V.tables()


func _check(bad: Array[String], label: String, want: Variant, got: Variant) -> void:
	var problem := V.diff(want, got, label)
	if problem != "" and bad.size() < 40:
		bad.append(problem)


func test_fixture_contract_has_all_requested_examples() -> void:
	assert_eq(V.data().get("format"), "field-vectors-v1")
	assert_eq(V.cases().size(), 27)
	var votes := 0
	var arrivals := 0
	for row: Dictionary in V.cases():
		votes += (row["votes"] as Array).size()
		if row["arrival"] != null:
			arrivals += 1
	assert_eq(votes, 72)
	assert_eq(arrivals, 24)


func test_field_return_council_votes_and_arrival_match_s1() -> void:
	var bad: Array[String] = []
	var seen_cases := 0
	var seen_votes := 0
	for row: Dictionary in V.cases():
		seen_cases += 1
		var at := V.where(row)
		var departure := V.departure(row["departure"])
		var receipt := V.receipt(row["receipt"])
		var input_before := JSON.stringify(row["start"])
		var applied := FieldReturn.apply_field_return(row["start"], _tables, departure, receipt)
		_check(bad, at + " apply status", row["apply"]["status"], applied["status"])
		_check(bad, at + " apply record", row["apply"]["record"], applied["record"])
		_check(bad, at + " apply after", row["apply"]["after"], applied["g"])
		_check(bad, at + " apply input unchanged", input_before, JSON.stringify(row["start"]))
		var duplicate := FieldReturn.apply_field_return(applied["g"], _tables, departure, receipt)
		_check(bad, at + " duplicate status", row["duplicate"]["status"], duplicate["status"])
		_check(bad, at + " duplicate changed", row["duplicate"]["changed"], V.diff(applied["g"], duplicate["g"]) != "")
		var current: Dictionary = applied["g"]
		if row["symbol"] != null:
			var receipt_id: String = applied["record"]["receiptId"]
			_check(bad, at + " symbol options", row["symbol"]["options"], FieldReturn.symbol_options(current, _tables, receipt_id))
			var locked := FieldReturn.choose_symbol_use(current, _tables, receipt_id, "hang_in_car")
			_check(bad, at + " symbol locked", row["symbol"]["hangInCarAccepted"], locked["accepted"])
			if row["symbol"]["use"] != null:
				var chosen := FieldReturn.choose_symbol_use(current, _tables, receipt_id, row["symbol"]["use"])
				assert_true(chosen["accepted"], at + " symbol choice accepted")
				current = chosen["g"]
			_check(bad, at + " symbol after", row["symbol"]["after"], current)
		var regular: Array = row["open"]["regular"]
		var stepped := FieldCouncil.next_field_step(current, _tables, regular)
		_check(bad, at + " step before", row["open"]["stepBefore"], stepped["step"])
		_check(bad, at + " next step", row["open"]["nextStep"], stepped["step"])
		var opened: Dictionary = stepped["g"]
		var candidates: Array = []
		if opened.get("fieldReturns") is Dictionary and opened["fieldReturns"].get("special") is Dictionary and opened["fieldReturns"]["special"].get("status") == "opened":
			candidates = FieldCouncil.special_candidates(opened, _tables, opened["fieldReturns"]["records"][0], regular)
		_check(bad, at + " candidates", row["open"]["candidates"], candidates)
		_check(bad, at + " open reasons", row["open"]["reasons"], FieldCouncil.special_reasons(opened))
		_check(bad, at + " open after", row["open"]["after"], opened)
		if row["open"]["nextStep"] != "council":
			continue
		for preview: Dictionary in row["preview"]:
			var agenda: Dictionary = preview["agenda"]
			var stances := {}
			for comm: String in _tables["COMMS"]:
				stances[comm] = CouncilVote.stance(opened, _tables, comm, agenda)
			var bloc_map := CouncilVote.blocs(opened, _tables, agenda, [])
			_check(bad, at + " preview stance " + JSON.stringify(agenda), preview["stance"], stances)
			_check(bad, at + " preview blocs " + JSON.stringify(agenda), preview["blocs"], bloc_map)
			_check(bad, at + " preview expected " + JSON.stringify(agenda), preview["expected"], CouncilVote.expected(bloc_map, _tables))
		for vote: Dictionary in row["votes"]:
			seen_votes += 1
			var vote_input: Dictionary = opened.duplicate(true)
			vote_input["council"]["idx"] = int(vote["idx"])
			var voted := CouncilVote.cast_vote(vote_input, _tables)
			_check(bad, "%s vote %d result" % [at, int(vote["idx"])], vote["result"], voted["result"])
			_check(bad, "%s vote %d after" % [at, int(vote["idx"])], vote["after"], voted["g"])
		if row["leave"] != null:
			var leave_input: Dictionary = opened.duplicate(true)
			leave_input["council"]["idx"] = 0
			var first_vote := CouncilVote.cast_vote(leave_input, _tables)
			var left := FieldCouncil.leave_special_council(first_vote["g"], _tables)
			_check(bad, at + " leave flag", row["leave"]["left"], left["left"])
			_check(bad, at + " leave after", row["leave"]["after"], left["g"])
			_check(bad, at + " leave reasons", row["leave"]["reasons"], FieldCouncil.special_reasons(left["g"]))
		if row["arrival"] != null:
			var arrival: Dictionary = row["arrival"]
			var arrival_state: Dictionary = arrival["state"]
			_check(bad, at + " arrival reached", arrival["reached"], FieldArrival.second_station_reached(arrival_state))
			_check(bad, at + " arrival now", arrival["now"], FieldReturn.snapshot(arrival_state, _tables))
			_check(bad, at + " arrival sections", arrival["sections"], FieldArrival.arrival_summary(arrival_state, _tables))
			_check(bad, at + " arrival end card", arrival["endCard"], FieldArrival.end_card(arrival_state))
			var finished := FieldArrival.finish_slice(arrival_state, _tables)
			_check(bad, at + " arrival finished", arrival["finished"], finished["finished"])
			_check(bad, at + " arrival after", arrival["after"], finished["g"])
			_check(bad, at + " arrival reached after", arrival["reachedAfter"], FieldArrival.second_station_reached(finished["g"]))
	assert_eq(seen_cases, 27)
	assert_eq(seen_votes, 72)
	assert_eq(bad, [] as Array[String])
