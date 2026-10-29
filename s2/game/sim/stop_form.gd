extends RefCounted
## Stop times and arrival fill by form (decision 494).

const VALUES := {
	"city": {"safe_sec": 1200.0, "limit_sec": 1800.0, "fill_share": 1.0},
	"edge": {"safe_sec": 1200.0, "limit_sec": 1800.0, "fill_share": 0.5},
	"siding": {"safe_sec": 1200.0, "limit_sec": 1800.0, "fill_share": 1.0},
	"remote": {"safe_sec": 1800.0, "limit_sec": 2400.0, "fill_share": 0.0},
}
const SIDINGS := ["freight", "factory", "mine", "sawmill"]


static func resolve(opts: Dictionary, kind: String) -> String:
	var given: Variant = opts.get("stop_form", "")
	if given is String and VALUES.has(given):
		return String(given)
	return "siding" if SIDINGS.has(kind) else "city"


static func safe_sec(form: String) -> float:
	return float(VALUES.get(form, VALUES["city"])["safe_sec"])


static func limit_sec(form: String) -> float:
	return float(VALUES.get(form, VALUES["city"])["limit_sec"])


static func fill_share(form: String) -> float:
	return float(VALUES.get(form, VALUES["city"])["fill_share"])
