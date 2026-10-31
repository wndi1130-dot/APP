extends RefCounted
## The people who live at a stop (J21, people-memory design 3, decision 439
## card 3): an old railwayman who would not leave the rails and his daughter
## who stayed with him, upstairs in the signal box. They do not shoot first;
## they warn from the top of the ladder. What the chief does with them — help,
## take, or pass by — goes home as a witnessed row (template resident_aid,
## resident_robbed or resident_ignored) for the train's people to remember
## (memory.ts), and taking is minded by the cars of those who saw it and came
## back (field_receipt.ts RESIDENT_ROBBED_REL).
##
## Which of the place's situations a run opens is the run's seed's. This first
## cut has one: "b", the daughter's hand cut on glass and festering, no wood to
## melt snow and wash it. The card shows only what each choice costs now
## (decisions 239, 364). They are not of the squad: the companions do not
## follow, heal or count them, and they are not on the receipt's lists.

const FieldGrid = preload("res://game/world/field_grid.gd")

const PATTERNS: Array = ["b"]
## The chief this near (metres, the same floor) meets them.
const MEET_M: float = 4.0
## A companion this near, or under the same roof, sees what is done.
const SEE_M: float = 15.0
const ROWS: Array = [
	{"id": "npc_resident_old", "name": "선로원", "role": "resident", "hands": [["crowbar", "factory", 0.7]]},
	{"id": "npc_resident_daughter", "name": "선로원의 딸", "role": "resident"},
]
const WARN: String = "거기서 멈춰. 뭘 원하는지 말해."
const CARD_B: String = "신호소 위층의 늙은 선로원과 딸. 딸의 손이 곪았다.\n선로원: 「유리에 베였어. 눈 녹일 땔감이 없어 상처를 못 헹궜다. …붕대랑 약 좀.」\n딸: 「아버지, 됐어요. 저 사람들도 모자랄 거예요.」"
const AFTER: Dictionary = {
	"aid": "선로 사정은 이 종이에 다 있다. 북쪽 분기는 얼어 있어.",
	"robbed": "이건 겨울 몫이야. 가져가면 우린 끝이다.",
}
## What one who saw it says after (people-memory design 3.6), by voice.
const SEEN_LINE: Dictionary = {
	"robbed": {"quiet": "...그 집 단지, 그 사람들 겨울 몫이었다."},
	"ignored": {"fear": "약은... 우리도 모자라요."},
}

var game
var pattern: String = ""
var people: Array = []
var met: bool = false
## "" until the chief chooses; then aid, robbed or ignored.
var outcome: String = ""
var _spot: Dictionary = {}


func _init(g) -> void:
	game = g


## Puts them in, if the map has a place for them (data "residents") and the
## start screen has not turned them off.
func place() -> void:
	_spot = game.data.get("residents", {})
	if _spot.is_empty() or not bool(game.opts.get("residents", true)):
		return
	var pick: String = String(PATTERNS[absi(("%d:residents" % game.rng.seed).hash()) % PATTERNS.size()])
	pattern = String(game.opts.get("resident_pattern", pick))
	if not PATTERNS.has(pattern):
		pattern = pick
	var cells: Array = _spot.get("cells", [])
	var level: int = int(_spot.get("level", 0))
	for i in range(mini(ROWS.size(), cells.size())):
		var p = game.make_person(ROWS[i], game.lift(cells[i], level))
		p.team = "resident"
		game.people.erase(p)
		people.append(p)
	# Back after the app was put away: what was chosen stays chosen (the receipt keeps it).
	for row: Dictionary in game.receipt.to_dict().get("witnessed", []):
		var t: String = String(row.get("template", ""))
		if t.begins_with("resident_"):
			outcome = t.substr("resident_".length())
			met = true


func tick(_delta: float) -> void:
	if met or people.is_empty() or game.player == null or not game.player.is_alive():
		return
	for p in people:
		if _near(game.player, p, MEET_M):
			meet()
			return


## The chief comes up to them: a warning, then the card.
func meet() -> void:
	if met or people.is_empty():
		return
	met = true
	game.say(people[0], WARN)
	if game.hud == null:
		return
	game.hud.card("residents", CARD_B, options(), Callable(self, "choose"))


## The card's choices, each with what it costs now.
func options() -> Array:
	var give: Array = ["붕대 1"]
	if _holder("medkit") != null:
		give.append("구급 상자 1")
	return [
		{"id": "aid", "label": "붕대와 약을 준다 (%s)" % "·".join(PackedStringArray(give)), "say": "\"이거 써라. 손부터 헹구고.\""},
		{"id": "robbed", "label": "단지와 지도를 그냥 가져간다 (먹을 것 2·선로 지도)", "say": "\"비켜라. 우리도 굶는다.\""},
		{"id": "ignored", "label": "줄 게 없다고 한다", "say": "\"줄 게 없다. 미안하다.\""},
	]


## What the chief chose. Once a stop; a second choice is not taken.
func choose(choice: String) -> void:
	if outcome != "" or people.is_empty():
		return
	if choice == "aid" and _holder("bandage") == null:
		choice = "ignored"
	if not ["aid", "robbed", "ignored"].has(choice):
		return
	met = true
	outcome = choice
	game.decisions.append({"id": "residents", "choice": choice})
	match choice:
		"aid":
			_holder("bandage").take_item("bandage", 1)
			var kit = _holder("medkit")
			if kit != null:
				kit.take_item("medkit", 1)
			game.receipt.add_stock("info", 1)
			game.receipt.add_stock("food", 1)
		"robbed":
			game.receipt.add_stock("food", 2)
			game.receipt.add_stock("info", 1)
	if AFTER.has(choice):
		game.say(people[0], String(AFTER[choice]))
	var seen := witnesses()
	game.receipt.witness(game.player.pid, "signal_box_" + pattern, "signal_box", game.clock.label(), "residents", seen, "resident_" + choice)
	_said_after(choice, seen)


## The companions who see it: near, on the same floor, or under the same roof.
func witnesses() -> Array:
	var out: Array = []
	for q in game.squad:
		if q == game.player or not q.is_alive():
			continue
		for p in people:
			if _near(q, p, SEE_M) or _same_roof(q, p):
				out.append(q.pid)
				break
	return out


func _said_after(choice: String, seen: Array) -> void:
	var lines: Dictionary = SEEN_LINE.get(choice, {})
	for q in game.squad:
		if not seen.has(q.pid):
			continue
		var line: String = String(lines.get(game.lines.voice(String(q.pid)), ""))
		if line != "":
			game.say(q, line)
			return


## The first of the squad carrying `item`: the chief first.
func _holder(item: String):
	var order: Array = [game.player]
	for q in game.squad:
		if q != game.player:
			order.append(q)
	for q in order:
		if q != null and q.is_alive() and int(q.items.get(item, 0)) > 0:
			return q
	return null


func _near(a, b, metres: float) -> bool:
	return game.level_of(a.position) == game.level_of(b.position) and a.position.distance_to(b.position) <= metres


func _same_roof(a, b) -> bool:
	var building: int = int(_spot.get("building", -1))
	if building < 0:
		return false
	var at: int = game.grid_at(a.position).building_at(FieldGrid.cell_of(a.position))
	return at == building and game.level_of(a.position) == game.level_of(b.position)
