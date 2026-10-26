extends RefCounted
## Sound levels, scores and radii (field_unified 6, body_injury 8).

enum Level { QUIET, NORMAL, LOUD, VERY_LOUD }

const SCORE := [0, 1, 3, 6]
const RADIUS := [3.0, 12.0, 35.0, 1000.0]
## Seconds zombies inside the radius stay at the spot.
const LINGER := [0.0, 30.0, 60.0, 90.0]
const NAMES := ["조용함", "보통", "시끄러움", "매우 시끄러움"]

const WALK_RADIUS := 3.0
const RUN_RADIUS := 12.0
const CROUCH_MULT := 0.5
const STEALTH_STEP := 0.04
const STEALTH_MAX := 0.40
const WHOLE_MAP_MIN := 500.0
const INDOOR_MULT := 0.5
const STEP_EVERY := 0.5
## Footsteps go by the walk (decision 425, as the reference game times them):
## two to a round of the gait, at these points of it, the round being the
## metres the living's own walk, run and crouched walk cover (their baked
## "round"; tests check they match). Loudness and reach are as they were.
const STEP_AT := [0.2, 0.65]
const STEP_ROUND := {"walk": 1.64, "run": 2.27, "crouch": 1.19}
const EVENT_DISPLAY_SECONDS := 1.6

## Every sound the field makes, by its tag (gap audit J04): where it is made,
## how loud it may be, and whether it counts on the score that brings the next
## horde earlier ("pull") and tells the director the squad is about ("notice":
## the sewer, the raiders and the "lost" breather read that). Every sound in
## the table is heard by the dead within its radius and shows on the HUD the
## same way (field_game make_sound); a test reads the code's calls against it.
## "at": maker (whoever made it), spot (a door, window, lid or lure),
## train (the train's own place: the engine end). "reach": times its level's
## radius (1 when not said): a building's alarm carries twice as far.
## The brakes and the guards at the train pull nothing (decision 416): the
## first horde's 4.5 minutes already count them, and the dead they call come
## to the train, not after the squad.
const SOURCES := {
	"walk": {"levels": [Level.QUIET], "at": "maker", "pull": true},
	"run": {"levels": [Level.NORMAL], "at": "maker", "pull": true},
	"crouch": {"levels": [Level.QUIET], "at": "maker", "pull": true},
	"melee": {"levels": [Level.QUIET, Level.NORMAL], "at": "maker", "pull": true},
	"impact": {"levels": [Level.QUIET], "at": "spot", "pull": true},
	"fight": {"levels": [Level.NORMAL], "at": "maker", "pull": true},
	"fall": {"levels": [Level.NORMAL], "at": "maker", "pull": true},
	"gun": {"levels": [Level.LOUD, Level.VERY_LOUD], "at": "maker", "pull": true},
	"bow": {"levels": [Level.QUIET], "at": "maker", "pull": true},
	"bang": {"levels": [Level.NORMAL], "at": "spot", "pull": true},
	"pry": {"levels": [Level.QUIET, Level.NORMAL], "at": "spot", "pull": true},
	"latch": {"levels": [Level.QUIET], "at": "spot", "pull": true},
	"kick": {"levels": [Level.LOUD], "at": "spot", "pull": true},
	"glass": {"levels": [Level.LOUD], "at": "spot", "pull": true},
	"hammer": {"levels": [Level.NORMAL], "at": "spot", "pull": true},
	"salvage": {"levels": [Level.NORMAL, Level.LOUD], "at": "spot", "pull": true},
	"axe": {"levels": [Level.LOUD], "at": "maker", "pull": true},
	"search": {"levels": [Level.QUIET], "at": "maker", "pull": true},
	"glass_step": {"levels": [Level.QUIET], "at": "maker", "pull": true},
	"ladder": {"levels": [Level.QUIET, Level.NORMAL], "at": "maker", "pull": true},
	"lid": {"levels": [Level.NORMAL], "at": "spot", "pull": true},
	"floor_creak": {"levels": [Level.QUIET], "at": "spot", "pull": true},
	"pickaxe": {"levels": [Level.NORMAL], "at": "spot", "pull": true},
	"smoke": {"levels": [Level.NORMAL], "at": "spot", "pull": true},
	"light": {"levels": [Level.NORMAL], "at": "maker", "pull": true},
	"bell": {"levels": [Level.NORMAL], "at": "spot", "pull": true},
	"lure": {"levels": [Level.NORMAL], "at": "spot", "pull": true},
	"alarm": {"levels": [Level.NORMAL], "at": "maker", "pull": true},
	"can_bash": {"levels": [Level.NORMAL], "at": "maker", "pull": true},
	"scream": {"levels": [Level.VERY_LOUD], "at": "maker", "pull": true},
	"whistle": {"levels": [Level.VERY_LOUD], "at": "train", "pull": true},
	"train_brake": {"levels": [Level.LOUD], "at": "train", "pull": false},
	"train_guard": {"levels": [Level.QUIET], "at": "train", "pull": false},
	"building_alarm": {"levels": [Level.LOUD], "at": "spot", "pull": true, "reach": 2.0},
	"building_alarm_ring": {"levels": [Level.LOUD], "at": "spot", "pull": false, "reach": 2.0},
}


## Times its level's radius a sound of this tag carries.
static func reach(tag: String) -> float:
	return float((SOURCES.get(tag, {}) as Dictionary).get("reach", 1.0))


## Points a sound of this tag adds to the stop's score (0 for one that pulls nothing).
static func tag_score(level: int, tag: String) -> int:
	return score(level) if pulls(tag) else 0


## Does this tag count on the score? A tag outside the table does, as before.
static func pulls(tag: String) -> bool:
	return bool((SOURCES.get(tag, {}) as Dictionary).get("pull", true))


## Does a loud one of this tag tell the director (and the raiders) the squad
## is about? What pulls nothing does not: the dead it calls come to the train.
static func notices(tag: String) -> bool:
	return pulls(tag)


static func clamp_level(level: int) -> int:
	return clampi(level, Level.QUIET, Level.VERY_LOUD)


static func score(level: int) -> int:
	return SCORE[clamp_level(level)]


## Indoor halves the radius, then range_mult applies. VERY_LOUD always reaches the whole map.
static func radius(level: int, indoor: bool, range_mult: float = 1.0) -> float:
	var lv := clamp_level(level)
	var r: float = RADIUS[lv]
	if lv == Level.VERY_LOUD:
		return maxf(r * maxf(range_mult, 0.0), WHOLE_MAP_MIN)
	if indoor:
		r *= INDOOR_MULT
	return r * maxf(range_mult, 0.0)


## Walk 3m, run 12m (glass: walking counts as 12m too). Crouch (walk only) x0.5 and
## stealth -4%/level (max -40%, crouched only). Then floor and trait multipliers.
static func footstep_radius(running: bool, floor_mult: float, trait_mult: float, crouched: bool, stealth_skill: int, on_glass: bool = false, indoor: bool = false) -> float:
	var r: float = RUN_RADIUS if (running or on_glass) else WALK_RADIUS
	if crouched and not running:
		r *= CROUCH_MULT
		var cut: float = minf(STEALTH_STEP * float(maxi(stealth_skill, 0)), STEALTH_MAX)
		r *= 1.0 - cut
	return r * maxf(floor_mult, 0.0) * maxf(trait_mult, 0.0) * (INDOOR_MULT if indoor else 1.0)


static func footstep_level(running: bool, on_glass: bool) -> int:
	if running or on_glass:
		return Level.NORMAL
	return Level.QUIET
