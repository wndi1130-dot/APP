extends RefCounted
## Normal difficulty, by canonical act position (decisions 383, 387, 134, 250).

const EVOLVED_READY := false
const LUNGER_SHARE: float = 0.10
const ACT2_EVOLVED_START: float = 0.001
const ACT2_EVOLVED_SHARE: float = 0.010
const ACT3_EVOLVED_START: float = 0.03
const ACT3_EVOLVED_SHARE: float = 0.05
# Changes once act slot counts are fixed (campaign skeleton; decisions 383, 387).
const ACT1_LUNGER_START: float = 7.0 / 12.0
const ACT12_MIX_END: float = 11.0 / 12.0
const ACT3_MIX_END: float = 5.0 / 6.0


static func of(act: String, act_progress: float) -> Dictionary:
	# A NaN progress reads as the act's start; clampf would pass it through.
	var progress: float = 0.0 if is_nan(act_progress) else clampf(act_progress, 0.0, 1.0)
	var lunger_share: float = 0.0
	var evolved_share: float = 0.0
	match act:
		"act1":
			lunger_share = LUNGER_SHARE * clampf((progress - ACT1_LUNGER_START) / (ACT12_MIX_END - ACT1_LUNGER_START), 0.0, 1.0)
		"act2":
			lunger_share = LUNGER_SHARE
			evolved_share = lerpf(ACT2_EVOLVED_START, ACT2_EVOLVED_SHARE, minf(progress / ACT12_MIX_END, 1.0))
		"act3":
			lunger_share = LUNGER_SHARE
			evolved_share = lerpf(ACT3_EVOLVED_START, ACT3_EVOLVED_SHARE, minf(progress / ACT3_MIX_END, 1.0))
	return {"lunger_share": lunger_share, "evolved_share": evolved_share}
