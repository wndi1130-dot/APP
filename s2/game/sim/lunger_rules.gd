extends RefCounted
## The dead that lunge. One in ten of the dead that stand, and one in ten of
## those who died at this stop and get up again, is a lunger: seeing a person close by it
## drops low for a beat (the tell), runs at where that person was in a straight
## line, and is then spent for a while. It does this once. Few do it at a time.
##
## Every number here is a first value, not a measured one. They are all here
## so that they are changed in one place.

const OPTION: String = "lungers"        # true forces SHARE; otherwise follow act progress (decisions 383, 387, 134)
const SHARE: float = 0.1                # of the dead that stand (not the ones that drift)
const SEES: float = 8.0                 # a person seen within this many metres sets it off
const TELL: float = 1.2                 # seconds it stays low before it runs
const DASH: float = 3.0                 # seconds it runs
const DASH_SPEED: float = 4.3           # m/s (a person runs at 3.9)
const SPENT: float = 6.0                # seconds it staggers afterwards
const SPENT_SPEED: float = 1.6          # m/s while it does
const AT_ONCE: int = 2                  # no more than this many in the tell or the run together


## Whether one of the dead is a lunger, from one roll (0..1) made when it is put in the field.
static func picks(roll: float, stander: bool, share: float = SHARE) -> bool:
	return stander and roll < share
