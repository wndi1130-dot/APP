extends RefCounted
## How high a container is searched at, by the last word of its name (the kinds
## the maps have; tests/game/test_all_maps_open.gd checks that every container of
## every map is here). Looks only (decision 422): the search's time and what it
## finds do not change. A word not here is searched at chest height.

const FLOOR: String = "floor"      # lying on the ground: knelt at
const LOW: String = "low"          # bent over
const MID: String = "mid"          # at chest height
const HIGH: String = "high"        # reached up to

const BY_WORD: Dictionary = {
	"상자": LOW, "자재함": LOW, "궤": LOW, "트렁크": LOW, "금고": LOW, "서랍": LOW,
	"침실": LOW, "다락": LOW,
	"묶음": FLOOR, "더미": FLOOR, "밑": FLOOR,
	"보관함": MID, "공구함": MID, "부엌": MID, "책상": MID, "옷장": MID, "사물함": MID,
	"칸": MID, "장부": MID, "계산대": MID, "탁자": MID, "냉장고": MID,
	"조리대": LOW,
	"선반": HIGH, "찬장": HIGH, "창고": HIGH, "장": HIGH, "종": HIGH,
}
## The living's own motion for each height.
const CLIP: Dictionary = {FLOOR: "p_kneel_work", LOW: "p_search_low", MID: "p_search_mid", HIGH: "p_search_high"}


## The last word of a container's name ("" with none).
static func word_of(name: String) -> String:
	var words := name.strip_edges().split(" ", false)
	return String(words[words.size() - 1]) if words.size() > 0 else ""


static func height_of(container: Dictionary) -> String:
	return String(BY_WORD.get(word_of(String(container.get("name", ""))), MID))


static func clip_of(container: Dictionary) -> String:
	return String(CLIP[height_of(container)])
