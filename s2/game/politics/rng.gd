extends RefCounted
## Seeded random numbers for the train politics rules (S3). A port of s1/src/core/rng.ts
## ("mulberry32-v1"): the same seed must give the same draws as the TypeScript reference.
## tests/politics/test_rng.gd checks it against tests/game/fixtures/s3/calc_algo.json.
##
## The state is one uint32 kept in an int. Nothing here holds state: pass it in, get it back.

const ALGORITHM := "mulberry32-v1"
const MASK := 0xFFFFFFFF
const SIZE := 0x100000000
const STEP := 0x6D2B79F5
const FNV_OFFSET := 0x811C9DC5
const FNV_PRIME := 0x01000193


## 32-bit wrapping multiply (JS Math.imul, read as uint32). Split so no product passes 2^48.
static func imul(a: int, b: int) -> int:
	a &= MASK
	b &= MASK
	return ((a & 0xFFFF) * b + ((((a >> 16) * b) & 0xFFFF) << 16)) & MASK


## Text seeds hash their UTF-8 bytes with FNV-1a; number seeds fold to uint32 (-1 -> 4294967295).
static func seed_state(seed: Variant) -> int:
	if seed is String or seed is StringName:
		var h := FNV_OFFSET
		for b: int in String(seed).to_utf8_buffer():
			h = imul(h ^ b, FNV_PRIME)
		return h
	return int(seed) & MASK


## The state after one draw.
static func step(state: int) -> int:
	return (state + STEP) & MASK


## The uint32 a draw yields, read from the state that draw moved to (see step).
static func u32(stepped: int) -> int:
	var m := imul(stepped ^ (stepped >> 15), stepped | 1)
	m ^= (m + imul(m ^ (m >> 7), m | 61)) & MASK
	return (m ^ (m >> 14)) & MASK


## One draw in [0, 1): returns [value, next_state].
static func next(state: int) -> Array:
	var s := step(state)
	return [float(u32(s)) / float(SIZE), s]


## One integer in [lo, hi] (both ends included): returns [value, next_state]. Draws again while the
## value falls in the uneven tail, so every value is equally likely. Moves the state even when lo == hi.
static func next_int(state: int, lo: int, hi: int) -> Array:
	var span := hi - lo + 1
	assert(span >= 1 and span <= SIZE, "rng.next_int: bad range")
	@warning_ignore("integer_division")
	var limit := (SIZE / span) * span
	var s := step(state)
	while u32(s) >= limit:
		s = step(s)
	return [lo + (u32(s) % span), s]
