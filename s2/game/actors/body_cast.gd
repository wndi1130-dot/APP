extends RefCounted
## Who of the field's living wears which baked body. Each body is a folder
## pair in models/people: <body>_p with the living's own motions
## (body_bake.gd PERSON_CLIPS, baked the same way as person_visual.gd
## OWN_FOLDER) and <body> beside it, the same mesh with the dead's motions
## (the struck pose). Named people go by their id, the rest by what they do,
## then from all of them; no two in one scene wear the same body while there
## are bodies to go round. The body the dead wear (dead_body.gd BUILT_IN) is
## not among these, so a living person is never drawn as one of the dead.

const ROOT: String = "res://models/people/"
const OWN_SUFFIX: String = "_p"

## The squad that goes out (field_game.gd default_squad).
const BY_ID: Dictionary = {
	"p_chief": "n5-crew_railman-old",       # the train's chief: an old railwayman's jacket and cap
	"p_guard_marek": "n5-crew_guard",       # the guard car: a dark coat over a jumper, no uniform
	"p_med_joanna": "n5-crew_medic",        # the medical car: blouse and apron
	"p_tail_tomasz": "n3-body_sheepskin",   # the tail car: a big man in a sheepskin coat
}
## Everyone else by what they do, the first one not yet worn.
const BY_ROLE: Dictionary = {
	"raider": ["n3-body_lumberjack", "n10-body_woodsman-m", "n10-body_duffel-m"],
	"worker": ["n5-crew_stoker", "n5-crew_fitter", "n10-body_overalls-m", "n5-crew_driver"],
	"escort": ["n5-crew_guard-f", "n5-crew_hunter-f"],
	"companion": ["n10-body_duffel-m", "n5-crew_driver", "n5-crew_hunter-f"],
}
## Every body baked for the living, in the order a person no list names
## takes them.
const ALL: Array = [
	"n5-crew_railman-old", "n5-crew_guard", "n5-crew_medic", "n3-body_sheepskin",
	"n3-body_lumberjack", "n10-body_woodsman-m", "n10-body_duffel-m",
	"n5-crew_stoker", "n5-crew_fitter", "n10-body_overalls-m", "n5-crew_driver",
	"n5-crew_guard-f", "n5-crew_hunter-f",
]


## The body one person wears, given those already worn in this scene (body ->
## how many wear it; the one picked is counted in). When every body is worn,
## or `cap` bodies are (a phone that cannot hold more pictures; 0 is no cap),
## the one fewest wear of those worn (the first such in ALL).
static func pick(pid: String, role: String, taken: Dictionary, cap: int = 0) -> String:
	var wants: Array = []
	if BY_ID.has(pid):
		wants.append(BY_ID[pid])
	wants.append_array(BY_ROLE.get(role, []))
	wants.append_array(ALL)
	var worn := 0
	for b: String in taken:
		if int(taken[b]) > 0:
			worn += 1
	var body := ""
	if cap <= 0 or worn < cap:
		for b: String in wants:
			if int(taken.get(b, 0)) == 0:
				body = b
				break
	if body == "":
		for b: String in ALL:
			if worn > 0 and int(taken.get(b, 0)) == 0:
				continue
			if body == "" or int(taken.get(b, 0)) < int(taken.get(body, 0)):
				body = b
	taken[body] = int(taken.get(body, 0)) + 1
	return body


static func own_folder(body: String) -> String:
	return ROOT + body + OWN_SUFFIX


static func dead_folder(body: String) -> String:
	return ROOT + body
