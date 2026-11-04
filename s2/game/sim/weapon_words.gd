extends RefCounted
## The words for a weapon held long in the bag (결정 531): a line of what it
## does and a line of this world, and for a gun the line of its make. Words
## only: the bag's window reads them as they are, one line each. Every line is
## one or two plain sentences ending in a full stop; what it does and a make
## take 30 characters at most, the world 40 (test_weapon_words.gd).

const DESC_MAX: int = 30
const FLAVOR_MAX: int = 40
const QUALITY_MAX: int = 30

## What it does, by weapon id (weapons.gd DATA and IMPROVISED).
const DESC: Dictionary = {
	"knife": "가볍고 빠르지만 짧고, 거의 못 넘어뜨린다.",
	"crowbar": "가장 덜 닳고 문도 따지만 머리를 쳐도 잘 안 끝난다.",
	"axe": "잘 넘어뜨리고 끝내지만 무겁고 느려 금방 지친다.",
	"pistol": "멀리 쏘고 재장전도 빠르지만 시끄럽고 닳으면 걸린다.",
	"shotgun": "여덟 알이 퍼지지만 사거리가 짧고 매우 시끄럽다.",
	"bow": "소리 없이 멀리 쏘지만 숙련이 모자라면 잘 빗나간다.",
	"pipe_shotgun": "일곱 알을 쏘지만 재장전이 길고 잘 닳고 불발도 난다.",
	"frying_pan": "잘 넘어뜨리지만 끝내기 어렵고 쓸수록 우그러진다.",
	"broken_bottle": "가장 짧고 빠르지만 네 번쯤 베면 부서진다.",
	"wood_stake": "칼보다 조금 길게 닿지만 다섯 번쯤 찌르면 부러진다.",
}

## A line of this world, by weapon id. No year in it: the bag is the same in
## every run.
const FLAVOR: Dictionary = {
	"knife": "정차한 역에서 소리 없이 망자를 끝낸다.",
	"crowbar": "수색대가 눈 덮인 역의 잠긴 문을 따고 생필품을 찾는다.",
	"axe": "눈보라 치는 철길 위, 쓰러진 망자를 한 손으로 마저 친다.",
	"pistol": "석탄을 나르던 역에 총성이 울리자 멀리서 무리가 몰려온다.",
	"shotgun": "공장에서 나온 귀한 총이다. 추운 날엔 걸리기도 한다.",
	"bow": "공방칸에서 만든 화살 한 대, 무리는 아무것도 듣지 못한다.",
	"pipe_shotgun": "손으로 만든 단발 총이다. 쏠 때마다 속으로 빈다.",
	"frying_pan": "버려진 부엌에서 집어 든 팬이다. 달걀 부칠 날은 다시 안 온다.",
	"broken_bottle": "술병 목을 깨 날을 세웠다. 쥘 것이 이것뿐일 때 쥔다.",
	"wood_stake": "부서진 울타리에서 뽑아 끝을 깎았다. 손에 가시가 박힌다.",
}

## A gun's make, by weapons.gd QUALITY key.
const QUALITY_LINE: Dictionary = {
	"crude": "조준이 부정확하고 두 배 빨리 닳으며 가끔 터진다.",
	"usable": "터지진 않지만 조금 덜 정확하고 더 빨리 닳는다.",
	"fine": "조준도 닳는 속도도 공장제와 거의 같다.",
	"factory": "공장에서 만들어 가장 정확하고 덜 닳는다.",
}
