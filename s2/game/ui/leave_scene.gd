extends RefCounted
## What a stop closes on as the train goes (user decision 183): a head line and
## four columns side by side, all read off the stop's own record, so two stops
## say different things only where they went differently. No dice, no new
## counts. People are numbers here, never names.
##
## The shape is head lines plus a list of [title, [rows]] columns, so another
## ending can hand the same beat its own columns (user decision 185).

const Carry = preload("res://game/sim/carry.gd")

const STOCK_NAMES: Dictionary = {"coal": "석탄", "food": "식량", "medicine": "의약품", "luxury": "사치품", "symbol": "상징물", "info": "정보", "scrap": "고철", "wood": "목재", "ammo_pistol": "권총탄", "ammo_shell": "산탄", "ammo_craft": "공방탄", "supplies": "생필품"}
const ROWS_MOST: int = 4


static func _count(result: Dictionary, list_name: String) -> int:
	return (result["receipt"].get("people", {}).get(list_name, []) as Array).size()


## What went up, most first: [[key, n], ...].
static func loaded(result: Dictionary) -> Array:
	var out: Array = []
	var stock: Dictionary = result["receipt"].get("stock", {})
	for key in stock:
		if int(stock[key]) > 0:
			out.append([key, int(stock[key])])
	out.sort_custom(func(a: Array, b: Array) -> bool: return a[1] > b[1])
	return out


## 을 or 를 after a Korean word, by its last sound.
static func object_mark(word: String) -> String:
	var code: int = word.unicode_at(word.length() - 1)
	if code < 0xAC00 or code > 0xD7A3:
		return "을"
	return "를" if (code - 0xAC00) % 28 == 0 else "을"


## The two lines over a stop no train was held at: what the stop comes to, by
## the heaviest thing in its record, then how long it was.
static func head(result: Dictionary) -> Array:
	var top: String = "빈손으로 떠났다"
	var got: Array = loaded(result)
	if _count(result, "dead") > 0:
		top = "돌아오지 못한 사람이 있다"
	elif _count(result, "leftBehind") > 0:
		top = "다 태우지 못하고 떠났다"
	elif _count(result, "bitten") > 0:
		top = "물린 사람을 태우고 떠났다"
	elif _count(result, "injured") > 0:
		top = "다친 사람을 태우고 떠났다"
	elif not got.is_empty():
		var word: String = STOCK_NAMES.get(got[0][0], got[0][0])
		top = "%s%s 싣고 떠났다" % [word, object_mark(word)]
	var stay: String = "게임 %d분을 머물렀다" % int(result["stay"])
	var hordes: int = int(result.get("hordes", 0))
	stay += " · 무리는 오지 않았다" if hordes == 0 else " · 무리 %d번" % hordes
	return [top, stay]


## The four columns: what was loaded, who boarded, who is hurt, what stayed.
static func columns(result: Dictionary) -> Array:
	var r: Dictionary = result["receipt"]
	var goods: Array = []
	for row: Array in loaded(result):
		if goods.size() < ROWS_MOST:
			goods.append("%s %d" % [STOCK_NAMES.get(row[0], row[0]), row[1]])
	# A thing with no name of its own (a symbol the train named) is not spelled
	# out as its id: its count is in the stock above.
	for id in r.get("items", {}).get("gained", []):
		if goods.size() < ROWS_MOST and Carry.ITEM_NAMES.has(id):
			goods.append(String(Carry.ITEM_NAMES[id]))
	var dead: int = _count(result, "dead")
	var stayed: int = _count(result, "leftBehind")
	var aboard: Array = ["%d명" % int(result["boarded"])]
	if dead == 0 and stayed == 0:
		aboard.append("모두 탔다")
	var harmed: Array = []
	for pair: Array in [["bitten", "물린 사람 %d"], ["injured", "다친 사람 %d"], ["dead", "죽은 사람 %d"]]:
		if _count(result, pair[0]) > 0:
			harmed.append(pair[1] % _count(result, pair[0]))
	var left: Array = []
	if stayed > 0:
		left.append("못 탄 사람 %d" % stayed)
	var place: Dictionary = r.get("placeState", {})
	# A map with nothing to search has nothing unsearched.
	var looted: float = float(place.get("looted", 1.0)) if int(result.get("places", 1)) > 0 else 1.0
	if looted < 0.5:
		left.append("뒤지지 않은 곳이 많다")
	elif looted < 1.0:
		left.append("뒤지지 못한 곳이 있다")
	if String(place.get("waterTower", "")) == "frozen":
		left.append("얼어 있는 급수탑")
	if int(result.get("dead_about", 0)) > 0:
		left.append("망자")
	var out: Array = [["실은 것", goods], ["탄 사람", aboard], ["다친 사람", harmed], ["남긴 것", left]]
	for column: Array in out:
		if column[1].is_empty():
			column[1].append("없다")
	return out
