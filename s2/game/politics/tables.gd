extends RefCounted
## Reads the number tables of the politics rules (S3). The tables are not typed in by hand: they are
## the values s1/src/game/data.ts exports, written out by s1/tools/s3_dump.ts (tables) as
## {"format": "s3-tables-v1", "tables": {NAME: value}}. Names and shapes are those of data.ts.
## JSON gives every number back as a float, so the helpers here hand out ints where the rules count.

const FORMAT := "s3-tables-v1"
## Tables the council arithmetic cannot run without.
const REQUIRED: Array[String] = ["COMMS", "P", "POP0", "REL0", "COH0", "IDEO", "STAGES", "START", "LAWS"]


## Parses the JSON text. Returns the tables, or {} when the text is not a tables file (see problems).
static func parse(text: String) -> Dictionary:
	if not problems(text).is_empty():
		return {}
	return (JSON.parse_string(text) as Dictionary)["tables"]


static func load_file(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	return parse(FileAccess.get_file_as_string(path))


## What is wrong with a tables file, as plain lines. Empty when it can be used.
static func problems(text: String) -> Array[String]:
	var out: Array[String] = []
	var root: Variant = JSON.parse_string(text)
	if not root is Dictionary:
		out.append("not a JSON object")
		return out
	if root.get("format") != FORMAT:
		out.append("format is not %s" % FORMAT)
	var tables: Variant = root.get("tables")
	if not tables is Dictionary:
		out.append("tables is missing")
		return out
	for name: String in REQUIRED:
		if not tables.has(name):
			out.append("table %s is missing" % name)
	if tables.get("COMMS") is Array:
		for name: String in ["POP0", "REL0", "COH0", "IDEO", "START"]:
			if not tables.get(name) is Dictionary:
				continue
			for c: Variant in tables["COMMS"]:
				if not (tables[name] as Dictionary).has(c):
					out.append("table %s has no entry for %s" % [name, c])
	return out


## A per-community table as an array in community order, e.g. by_comm(tables, "POP0").
static func by_comm(tables: Dictionary, name: String) -> Array:
	var out: Array = []
	for c: Variant in tables["COMMS"]:
		out.append(tables[name][c])
	return out


## The same, as whole numbers (head counts, relations).
static func ints_by_comm(tables: Dictionary, name: String) -> Array[int]:
	var out: Array[int] = []
	for v: Variant in by_comm(tables, name):
		out.append(int(v))
	return out


## Seats a law needs to pass: 67 for rule changes, 51 otherwise (lawNeed in politics.ts).
static func law_need(tables: Dictionary, law: String) -> int:
	return 67 if tables["LAWS"][law]["kind"] == "rule" else 51
