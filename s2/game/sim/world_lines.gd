extends RefCounted
## Lines of this world, one shown under the pause veil's word each time the
## field is paused (pause_veil.gd: the place a loading screen's line would have,
## S2 having no loading screen). Words only. Each is one plain sentence ending in
## a full stop, 40 characters at most (test_world_lines.gd), and true in the game
## as it is: a line about something the game does not do yet waits until it does.

const LINE_MAX: int = 40

const LINES: Array[String] = [
	"망자는 소리와 빛에 끌려 무리로 몰려온다.",
	"망자는 머리를 맞혀야 완전히 끝난다.",
	"갓 일어난 자는 죽은 지 얼마 안 돼 걸음이 빠르다.",
	"눈 속에 멈춘 얼어붙은 자는 소리나 다가오는 발걸음에 깨어난다.",
	"두꺼운 옷을 껴입은 자는 날과 물림을 막는다.",
	"모두가 이미 감염돼 있어 어떻게 죽든 잠시 뒤 일어난다.",
	"망자에게 물린 팔다리는 제때 잘라 내야 감염을 막는다.",
	"오래 머물수록 무리가 늘고 잦아진다.",
	"기적은 떠날 때만 울리며, 그 소리가 다시 무리를 부른다.",
	"쟁기가 선로 위 망자를 밀어내도 밖에 남은 사람은 못 데려온다.",
	"회기가 열리면 칸 대표들이 법과 안건을 표결한다.",
	"붕괴 전에 일을 배운 장인들은 늙어 가고, 그 솜씨는 갈수록 귀해진다.",
	"여섯 해가 지나 휘발유와 경유는 거의 다 상했다.",
	"추위가 왜 왔는지를 두고 열차 안에서도 말이 갈린다.",
	"나중에 탄 꼬리칸 사람들이 가장 많고 또 가장 춥다.",
]

## 기다리는 줄 — 회기에 불신임 안건이 들어오면(council_vote.gd의 지원 동의에 들고
## train_advance.gd의 F-NOT-PORTED 거절이 풀리면) LINES로 되살린다.
# "불신임 동의가 통과하면 열차장은 자리에서 물러난다.",
