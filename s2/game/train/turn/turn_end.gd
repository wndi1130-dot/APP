extends RefCounted
## The real end panel keeps its existing layout and at most one lookback line.
const Turn = preload("res://game/train/train_turn.gd")
const Chronicle = preload("res://game/train/train_chronicle.gd")
const LOOKBACK_LIMIT := 1


static func panel_lines(g: Dictionary, t: Dictionary, reason: String) -> Array[String]:
	var lines: Array[String] = [reason]
	if g.get("phase") != "end" or g.get("end") == "slice": return lines
	var lookback: Array = Turn.lookback_lines(g, t)
	for i: int in mini(LOOKBACK_LIMIT, lookback.size()): lines.append(String(lookback[i]))
	if Chronicle.enabled(g): lines.append(Chronicle.tone_line(g))
	return lines
