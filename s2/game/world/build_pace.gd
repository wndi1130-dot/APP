extends RefCounted
## Spreads one long build over frames, so the screen keeps moving while a stop
## is made ready (정차 연출, 결정 421-3). A builder calls
## `await BuildPace.rest(pace)` between pieces: while the work since the last
## frame is under the budget it goes straight on; past it the build waits for
## the next frame. A null pace, or one that is off, never waits, so the build
## runs in one call exactly as before.

## Waits only when on (a tree to wait on and a staged build).
var on: bool = false
var tree: SceneTree
## Microseconds of building one frame may take before the build waits.
var budget_usec: int = 10000
## The picture over the build is still (the camera at rest): a piece too big
## for a moving frame (heavy) may go. True unless the one watching says not.
var still: bool = true
## Frames the build was spread over, less one, and the longest run of work
## between two waits (the frame it cost), for the measurements.
var waits: int = 0
var longest_usec: int = 0
var started_usec: int = 0
var ended_usec: int = 0
var _since: int = 0


func _init(t: SceneTree = null, staged: bool = false) -> void:
	tree = t
	on = staged and t != null
	started_usec = Time.get_ticks_usec()
	_since = started_usec


## Wait a frame if this frame's share of the build is spent.
static func rest(pace) -> void:
	if pace == null or not pace.on:
		return
	await pace.breath()


## Before a piece that cannot be cut and takes many frames' worth (a few
## tenths of a second): wait till the picture is still, so the hitch falls
## where nothing moves.
static func heavy(pace) -> void:
	if pace == null or not pace.on:
		return
	await pace.until_still()


func until_still() -> void:
	while on and not still:
		await tree.process_frame
		_since = Time.get_ticks_usec()


func breath() -> void:
	var used: int = Time.get_ticks_usec() - _since
	if used < budget_usec:
		return
	longest_usec = maxi(longest_usec, used)
	waits += 1
	await tree.process_frame
	_since = Time.get_ticks_usec()


## The build is done: the last run of work counts too.
func finish() -> void:
	ended_usec = Time.get_ticks_usec()
	longest_usec = maxi(longest_usec, ended_usec - _since)


## Milliseconds from the first piece to the last.
func total_ms() -> float:
	return float(maxi(ended_usec, started_usec) - started_usec) / 1000.0
