extends RefCounted
## Stop times and arrival fill by form (decision 494).

const VALUES := {
	"city": {"safe_sec": 1200.0, "limit_sec": 1800.0, "fill_share": 1.0},
	"edge": {"safe_sec": 1200.0, "limit_sec": 1800.0, "fill_share": 0.5},
	"siding": {"safe_sec": 1200.0, "limit_sec": 1800.0, "fill_share": 1.0},
	"remote": {"safe_sec": 1800.0, "limit_sec": 2400.0, "fill_share": 0.0},
}
const SIDINGS := ["freight", "factory", "mine", "sawmill"]
## The forms of the route's direct stops, by act and stop as route_bands.gd keeps their bands
## (decision 494: values only, the places stay out of the repository). "" is a stop that is not
## a direct one: it takes its place's form (resolve).
const ROUTE: Dictionary = {
	"prologue": ["city", "edge", "siding", "city", "city"],
	"act1": ["siding", "", "siding", "edge", "", "", "city", "city", "", "city", "siding", "edge"],
	"act2": ["remote", "", "remote", "", "edge", "remote", "", "remote", "city", "", "edge", "city"],
	"act3": ["remote", "", "city", "", "city", "edge"],
}


## The form the route gives stop `stop` of `act` ("" when it gives none). A first-leg stop past
## its ends reads the nearest one, as its band and season do (route_bands.gd, route_stops.gd).
static func on_route(act: String, stop: int) -> String:
	if not ROUTE.has(act):
		return ""
	var forms: Array = ROUTE[act]
	if act == "prologue":
		stop = clampi(stop, 1, forms.size())
	elif stop < 1 or stop > forms.size():
		return ""
	return String(forms[stop - 1])


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
