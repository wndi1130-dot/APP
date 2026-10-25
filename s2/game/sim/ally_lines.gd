extends RefCounted
## What a companion shouts when something happens to them (user 2026-10-12:
## 'lines too: the companions, as it would really sound'). Words on the screen
## only: no voice. The bank of lines is the content stream's
## (coord/fun/콘텐츠_다양성_동료_대사.md, decision 117); LINES holds the
## user's own examples, which anyone may say.
##
## Who speaks: the one it happened to (or, for "rage", the companion nearest
## to one who fell; for a door, the one nearest it). The chief does not speak.
## The one place he does is not here: his aside beside the stop's risk line
## (user decision 187, the lines are FieldHoldout.RISK_FEEL). Nowhere else is
## he given words.
## How often: one person at most once in GAP_SELF seconds, the squad at most
## once in GAP_SQUAD, so four people hurt at once do not all shout at once.
##
## Richer, fitting the moment, the person and how they stand with the chief
## (user's morning word, 2026-10-18): each person keeps a voice (voice) and
## a standing with the chief (rel_of: "bad", "normal", "good"). One who stands
## badly or well says the lines of REL_LINES besides their voice's own, or,
## for what is said to the chief (TOWARD_CHIEF), instead of them.

const LINES: Dictionary = {
	"hurt": ["시발", "시이이이발..."],
	"bite_leg": ["다리가 물렸어!!"],
	"grabbed": ["살려줘 살려줘!!"],
	"rage": ["이 개새끼들"],
	"left_behind": ["제발... 두고 가지 마"],
	# Left on the platform as the train goes (user 2026-10-12, in these words).
	"left_platform": ["나도 데리고 가 시발새끼들아!!"],
}
## What the companions say of what they see (decision 406, bundle 4). Lines
## from the content stream's bank (coord/fun/콘텐츠_다양성_동료_대사.md, decision
## 117), three voices: each person keeps one voice (voice). "{이름}" is the
## name of the one who fell; a line that needs it is not said without one.
const VOICED: Dictionary = {
	"horde_near": {
		"fear": ["저, 저기... 저게 다 뭐야...", "너무 많아... 너무 많아!", "떼로 와요! 떼로!!", "도망가야 해, 지금!"],
		"rough": ["시발... 저게 다 몇이냐.", "이 개새끼들... 떼로 온다!", "망했다, 다 튀어!!"],
		"quiet": ["...무리다.", "많다. 셀 수가 없어.", "조용히. 지금 빠진다."],
	},
	"ammo_out": {
		"fear": ["총알! 총알이 없어!!", "안 나가, 안 나간다고!", "어떡해, 다 썼어...!"],
		"rough": ["시발, 비었어!!", "탄! 탄 남은 사람!!", "에이 씨... 몸으로 때운다!"],
		"quiet": ["...비었다.", "탄 없다. 붙는다.", "마지막 발이었다."],
	},
	"kill": {
		"fear": ["주, 죽었어...? 죽은 거지?", "했어... 내가 했어...", "다시 안 일어나겠지...?"],
		"rough": ["뒈져, 뒈지라고!!", "꺼져, 이 개새끼들아!", "하나 보냈다! 다음!!"],
		"quiet": ["...하나.", "됐다. 다음.", "조용해졌다."],
	},
	"freed": {
		"fear": ["하악, 하악... 떨어졌어...", "죽는 줄 알았어...", "손이... 아직 떨려..."],
		"rough": ["하... 시발, 살았다.", "떨어져, 이 개새끼야!", "한 번만 더 붙어 봐라..."],
		"quiet": ["...풀렸다.", "괜찮다. 안 물렸다.", "...가까웠다."],
	},
	"ally_down": {
		"fear": ["{이름}! 눈 떠, 눈 좀 떠!", "안 돼, 안 돼, 안 돼...!", "누가 좀 도와줘요!!", "{이름}...? 대답 좀 해..."],
		"rough": ["{이름}! 야, 정신 차려!!", "시발... 쓰러졌어, 쓰러졌다고!", "일으켜! 끌고 간다!!"],
		"quiet": ["...{이름}.", "쓰러졌다. 내가 업는다.", "...아직 숨은 붙어 있다."],
	},
	"retreat": {
		"fear": ["가요, 가요! 얼른 가요!", "열차다... 살았다...", "기다려요, 같이 가요!"],
		"rough": ["들었지! 다 튀어!!", "알았어, 간다, 가!", "아직 덜 챙겼는데, 에이 씨."],
		"quiet": ["...간다.", "알았다. 뒤는 내가 본다.", "짐 챙겼다. 돌아간다."],
	},
	# The bank's lines for moments the field already has (decision 117).
	"bite_leg": {
		"fear": ["아아악! 떼 줘, 떼 줘!!", "못 걷겠어... 못 걷겠어...", "다리... 내 다리...!"],
		"rough": ["시발, 다리! 다리 물렸어!", "이 개새끼가... 놔, 놔!!", "아악, 빌어먹을...!", "부축 좀 해! 빨리!!"],
		"quiet": ["...다리. 물렸다.", "윽... 종아리다.", "못 뛴다. 어깨 좀.", "열차까지... 시간 없다."],
	},
	"bite_arm": {
		"fear": ["팔이! 내 팔이!!", "아파, 아파, 아파아!!", "물렸어... 나 물렸어...", "어떡해, 나 어떡해..."],
		"rough": ["아악! 팔 물렸다, 시발!!", "이 개새끼, 이거 놔!!", "끝났다... 끝났어, 젠장...", "열차! 열차로 데려가!!"],
		"quiet": ["...팔이다. 물렸어.", "큭... 깊다.", "끈. 팔 위쪽 묶어.", "아직 걷는다. 가자."],
	},
	"bite_torso": {
		"fear": ["옆구리, 옆구리가...!!", "여긴... 여긴 어떡해...", "싫어, 싫어, 죽기 싫어...", "거짓말... 거짓말이지...?"],
		"rough": ["커헉... 시발, 옆구리...!", "하필 여기냐, 개새끼야...", "하... 개같네, 진짜...", "됐어... 난 틀렸어, 가!"],
		"quiet": ["...옆구리다.", "여긴... 손쓸 데가 없다.", "됐다. 짐 가져가.", "...가라. 나는 늦었다."],
	},
	"grabbed": {
		"fear": ["잡혔어! 잡혔어!!", "놔! 놔, 놔줘!!", "누가 좀...! 여기!!"],
		"rough": ["시발, 시이이이발...!", "이거 놔, 개새끼야!!", "붙었어! 떼, 떼!!", "으아아, 꺼져!!"],
		"quiet": ["...잡혔다!", "등 뒤! 떼 줘!", "큭... 밀어, 밀어!"],
	},
	"scratch": {
		"fear": ["긁혔어... 이거 긁힌 거야?", "피 나... 나 괜찮은 거지?", "물린 거 아냐, 아니라고..."],
		"rough": ["악! 손톱, 시발...!", "긁혔네. 재수 없게.", "스친 거야, 스친 거라고!"],
		"quiet": ["...긁혔다.", "스쳤다. 얕아.", "괜찮다. ...아마."],
	},
	"cut": {
		"fear": ["아야! 손, 손 베였어!", "피... 피가 계속 나...", "유리야, 유리 박혔어..."],
		"rough": ["아 씨, 베였네!", "젠장, 유리 조각...!", "별거 아냐... 아, 아파."],
		"quiet": ["...베였다.", "윽. 깊진 않아.", "천 좀. 묶게."],
	},
	"fall": {
		"fear": ["으악! 미끄러졌어!", "아야야... 잠깐, 잠깐만...", "기다려! 금방 일어날게!"],
		"rough": ["아 씨...! 넘어졌네.", "젠장, 발을 헛디뎠어!", "괜찮아, 괜찮다고! 가!"],
		"quiet": ["...윽.", "미끄럽다. 조심.", "괜찮다. 일어난다."],
	},
	"fracture": {
		"fear": ["으아악! 부러졌어!!", "뚝 했어, 뚝 소리 났어...!", "못 움직이겠어, 아파...!"],
		"rough": ["아악, 시발, 뼈...!", "부러졌네, 젠장할...!", "건드리지 마! 아프다고!"],
		"quiet": ["...부러졌다.", "큭... 판자. 부목 대.", "혼자는 못 일어난다."],
	},
	"downed": {
		"fear": ["못 일어나겠어...", "여기야... 나 여기 있어...", "엄마... 엄마..."],
		"rough": ["하... 다리에 힘이, 시발...", "야... 나 좀 끌고 가라...", "여기서 뒈지긴 싫다..."],
		"quiet": ["...더는 못 간다.", "...짐부터 챙겨.", "...먼저들 가."],
	},
	"window_closed": {
		"fear": ["몸이 뜨거워... 이상해...", "추운데... 땀이 나...", "나... 변하는 거야...?"],
		"rough": ["하... 열나네. 망했네.", "올 게 왔네, 시발...", "야. 나 일어나면... 알지?"],
		"quiet": ["...열이 난다.", "얼마 안 남았다.", "때 되면... 망설이지 마."],
	},
	"treated": {
		"fear": ["아야, 아야야...! 살살...", "고마워... 진짜 고마워...", "이제 괜찮은 거지...?"],
		"rough": ["악! 살살 해, 살살!", "됐어, 됐어. 걸을 만해.", "하... 좀 살겠네."],
		"quiet": ["...됐다.", "고맙다.", "움직일 수 있다."],
	},
	"left_behind": {
		"fear": ["가지 마... 가지 마, 제발...", "나 아직 살아 있어...!", "여기야! 나 여기 있다고!!"],
		"rough": ["야! 어디 가, 시발!!", "나 아직 안 죽었어!!", "돌아와! 돌아오라고!!"],
		"quiet": ["...아직 여기 있다.", "...돌아와라.", "혼자서는... 못 버틴다."],
	},
	"rage": {
		"fear": ["{이름}...? 거짓말이지...?", "싫어... 이런 건 싫어...", "방금까지 말했는데..."],
		"rough": ["{이름}! 시발, 안 돼...!", "개새끼들... 다 죽여 버린다.", "...일어나기 전에 가자."],
		"quiet": ["...{이름}. 수고했다.", "늦었다. ...가자.", "곧 일어난다. 물러나."],
	},
	# Moments the field has that had no line yet (the morning word).
	"search_start": {
		"fear": ["제가 이거 뒤질게요.", "뭐 튀어나오는 거 아니지...?", "금방 할게요, 금방."],
		"rough": ["이건 내가 깐다.", "비켜, 내가 뒤진다.", "뭐 좀 있어라, 제발."],
		"quiet": ["여긴 내가.", "...뒤진다. 뒤 봐 줘.", "조용히 연다."],
	},
	"found": {
		"fear": ["있어요! 뭐 있어요!", "이거... 쓸 만하죠?", "다 챙겼어요, 챙겼어요."],
		"rough": ["오, 건졌다!", "이 정도면 쏠쏠하네.", "챙겼어. 다음 거."],
		"quiet": ["...챙겼다.", "쓸 만한 게 있다.", "넣었다. 다음."],
	},
	"bag_full": {
		"fear": ["가방이 꽉 찼어요...", "더는 못 넣어요...", "이거 다 못 들고 가요..."],
		"rough": ["에이, 가방 터지겠다.", "더는 안 들어가, 젠장.", "누가 좀 들어 줘!"],
		"quiet": ["가방이 찼다.", "...더는 못 든다.", "두고 간다. 자리 없다."],
	},
	# One of the dead is gone through, and a companion sees it (decision 423 card 12).
	"body_search": {
		"fear": ["죽은 사람 주머니를... 꼭 뒤져야 해요?", "미안해요... 미안해요...", "눈 뜨고 있는 것 같아..."],
		"rough": ["죽은 놈한텐 필요 없지.", "뭐 좀 있냐? 빨리 해.", "안됐지만... 어쩔 수 없지."],
		"quiet": ["...미안하다.", "이 사람도 누군가 기다렸겠지.", "...챙기고 가자."],
	},
	"empty": {
		"fear": ["아무것도 없어요...", "텅 비었어... 텅...", "괜히 열었나 봐..."],
		"rough": ["텅 비었네, 시발.", "누가 벌써 털어 갔어.", "헛짓했네, 에이 씨."],
		"quiet": ["...빈 통이다.", "없다. 다음.", "먼저 다녀간 놈이 있다."],
	},
	"order_follow": {
		"fear": ["네, 네! 따라갈게요!", "같이 가요, 같이!", "바로 뒤에 있을게요."],
		"rough": ["알았어, 간다.", "어, 붙어 있을게.", "앞장서. 뒤는 맡겨."],
		"quiet": ["따라간다.", "...뒤에 붙는다.", "알았다."],
	},
	"order_wait": {
		"fear": ["여, 여기서요? 혼자요?", "빨리 와야 돼요...", "알았어요... 기다릴게요."],
		"rough": ["여기 박혀 있으라고?", "알았어. 오래는 못 있어.", "여기서 버틴다."],
		"quiet": ["여기 있겠다.", "...기다린다.", "자리 지킨다."],
	},
	"order_search": {
		"fear": ["뒤져 볼게요... 조심해서.", "이 근처요? 알았어요.", "뭐 있으면 부를게요."],
		"rough": ["좋지, 털어 보자.", "다 뒤집어 놓을게.", "쓸 만한 건 다 챙긴다."],
		"quiet": ["주변 뒤진다.", "...살펴본다.", "찾으면 알린다."],
	},
	"order_cover": {
		"fear": ["제, 제가 막아요?", "쏠게요... 쏠 수 있어요.", "뒤는 제가 볼게요."],
		"rough": ["다가오면 다 쏜다.", "등은 맡겨.", "오기만 해 봐라."],
		"quiet": ["엄호한다.", "...본다. 가.", "시야 잡았다."],
	},
	"door_bang": {
		"fear": ["문, 문 두드려요!!", "들어오면 어떡해...!", "문이 버틸까요...?"],
		"rough": ["두드려 봐라, 개새끼들.", "문 잡아! 밀린다!", "시끄러워, 시발!"],
		"quiet": ["...문이다.", "문에 붙었다.", "몇 놈이다. 문 뒤에."],
	},
	"ready": {
		"fear": ["됐대요! 이제 가요!", "살았다... 살았어...", "빨리 타요, 빨리!"],
		"rough": ["드디어! 뜨자!", "됐다, 이제 튀자!", "늦었어, 어서 가."],
		"quiet": ["채비 끝났다.", "...이제 간다.", "탈 준비 해."],
	},
	"last_call": {
		"fear": ["가요, 가요! 문 닫혀요!", "기다려요!! 아직 안 탔어요!!", "뛰어요, 빨리 뛰어요!!"],
		"rough": ["뛰어! 안 기다린다!", "다 타! 지금!!", "늦으면 두고 간다!!"],
		"quiet": ["셋이다. 뛰어.", "...지금 탄다.", "문 닫힌다. 가."],
	},
	"left_platform": {
		"fear": ["가지 마요!! 제발요!!", "저 아직 여기 있어요!!"],
		"rough": ["야!! 세워, 세우라고!!", "기다려!! 나 아직 있어!!"],
		"quiet": ["...두고 가는구나.", "...기다려라."],
	},
}
const VOICES: Array = ["fear", "rough", "quiet"]
## How one stands with the chief: the rel of their car on the train, in the
## train's own seven stages (s1 STAGES): 호의 (15) and up is "good", below
## 중립 (-14) is "bad", between is "normal".
const REL_GOOD: float = 15.0
const REL_BAD: float = -14.0
const RELS: Array = ["bad", "normal", "good"]
## What one who stands badly says (blames the chief, mocks him, thinks of
## getting by alone) or well (trusts him, looks out for him, follows), on top
## of the voice's own lines. The swearing stays on the dead and the plight,
## not on the chief.
const REL_LINES: Dictionary = {
	"kill": {
		"bad": {"fear": ["제가 왜 이런 걸 해야 돼요...", "열차장님은 구경만 하죠..."], "rough": ["봤냐? 너 없이도 한다.", "이 짓 시킨 게 누군데."], "quiet": ["...내 몫은 했다.", "다음엔 직접 해라."]},
		"good": {"fear": ["열차장님, 저 했어요!", "보셨어요? 저도 할 수 있어요."], "rough": ["대장! 하나 치웠다!", "대장 쪽으론 못 간다!"], "quiet": ["열차장. 하나 줄였다.", "...이쪽은 맡겨."]},
	},
	"horde_near": {
		"bad": {"fear": ["그러니까 빨리 가자고 했잖아요!", "여기 서자고 한 게 누군데요..."], "rough": ["잘하는 짓이다, 열차장 나리.", "이래서 니 말 듣는 게 아닌데."], "quiet": ["...이럴 줄 알았다.", "나는 내 길로 빠진다."]},
		"good": {"fear": ["열차장님, 어떡해요? 말만 해요!", "열차장님 옆에 있을게요...!"], "rough": ["대장, 신호만 줘!", "대장 뒤로 붙어! 막는다!"], "quiet": ["열차장. 지시해.", "...옆에 있다. 정해."]},
	},
	"ammo_out": {
		"bad": {"fear": ["탄 좀 넉넉히 주지 그랬어요..."], "rough": ["탄도 안 주고 내보내냐."], "quiet": ["...배급이 짰다."]},
		"good": {"fear": ["열차장님, 저 탄 없어요!"], "rough": ["대장, 탄 남았으면 던져!"], "quiet": ["열차장. 탄 남았나."]},
	},
	"freed": {
		"bad": {"fear": ["이러다 여기서 죽어요..."], "rough": ["이런 데 데려온 게 누구냐, 시발."], "quiet": ["...여기 오는 게 아니었다."]},
		"good": {"fear": ["열차장님, 저 괜찮아요!"], "rough": ["살았다! 대장, 아직 멀쩡해!"], "quiet": ["...괜찮다. 계속 가."]},
	},
	"ally_down": {
		"bad": {"fear": ["이게 다 열차장님 때문이에요...!"], "rough": ["보라고! 니 명령 때문이야!"], "quiet": ["...또 하나. 누구 탓이지."]},
		"good": {"fear": ["열차장님! {이름} 좀 봐 줘요!"], "rough": ["대장! {이름} 쓰러졌어!"], "quiet": ["열차장. {이름} 쓰러졌다."]},
	},
	"rage": {
		"bad": {"fear": ["오지 말았어야 했어..."], "rough": ["누가 책임질 건데, 어?"], "quiet": ["...또 하나 갔다. 누구 덕에."]},
		"good": {"fear": ["열차장님... 어떡해요..."], "rough": ["대장, {이름} 몫까지 산다."], "quiet": ["...{이름}. 열차장, 가자."]},
	},
	"grabbed": {
		"bad": {"fear": ["열차장님은 뭐 해요!!"], "rough": ["열차장! 구경만 할 거야?!"], "quiet": ["...역시 혼자다."]},
		"good": {"fear": ["열차장님!! 열차장님!!"], "rough": ["대장! 여기, 여기!!"], "quiet": ["열차장. 떼 줘."]},
	},
	"bite_leg": {
		"bad": {"fear": ["거봐요... 오지 말자니까요..."], "rough": ["니 말 듣다 이 꼴이다, 시발."], "quiet": ["...이래서 오기 싫었다."]},
		"good": {"fear": ["두고 가지 마요, 열차장님..."], "rough": ["대장, 나 끌고라도 가!"], "quiet": ["열차장. 나 짐 된다."]},
	},
	"bite_arm": {
		"bad": {"fear": ["이게 다... 누구 때문인데..."], "rough": ["좋냐? 이게 니 작전이냐?"], "quiet": ["...고맙다. 덕분에 물렸다."]},
		"good": {"fear": ["열차장님, 저 괜찮은 거죠...?"], "rough": ["대장... 나 아직 쓸 만해."], "quiet": ["열차장. 아직 싸운다."]},
	},
	"bite_torso": {
		"bad": {"fear": ["열차장님이... 데려왔잖아요..."], "rough": ["끝까지 개같은 판이었다."], "quiet": ["...계산 잘못했다, 열차장."]},
		"good": {"fear": ["열차장님... 무서워요..."], "rough": ["대장... 먼저 가. 진짜로."], "quiet": ["열차장. 짐 챙겨 가."]},
	},
	"downed": {
		"bad": {"fear": ["두고 갈 거죠... 알아요..."], "rough": ["어차피 버릴 거잖아, 응?"], "quiet": ["...기대 안 한다."]},
		"good": {"fear": ["열차장님... 와 줄 거죠...?"], "rough": ["대장... 금방 일어난다."], "quiet": ["열차장... 기다린다."]},
	},
	"window_closed": {
		"bad": {"fear": ["이렇게 될 줄 알았어요..."], "rough": ["열차장, 니가 끝내라. 책임져."], "quiet": ["...약속은 지켜라. 이번엔."]},
		"good": {"fear": ["열차장님... 저 무서워요..."], "rough": ["대장, 때 되면 니 손으로."], "quiet": ["열차장. 때 되면 부탁한다."]},
	},
	"treated": {
		"bad": {"fear": ["이제 와서요...?", "치료하면 다예요...?"], "rough": ["고맙긴. 여기 끌고 온 게 누군데.", "빚 갚은 줄 알지 마."], "quiet": ["...된 걸로 친다.", "이걸로 빚 없다."]},
		"good": {"fear": ["열차장님 옆으로 갈게요...", "이제 안 아파요, 진짜요."], "rough": ["좋아, 대장. 다시 간다.", "하, 살겠다. 가자, 대장."], "quiet": ["...됐다. 다시 붙는다.", "움직인다. 열차장 옆으로."]},
	},
	"door_bang": {
		"bad": {"fear": ["버티자고 한 게 누군데요...", "우리 여기서 다 죽어요..."], "rough": ["버티자며? 잘 버텨 봐라.", "문 깨지면 니 책임이다."], "quiet": ["...문보다 사람이 먼저 깨진다.", "...길 열리면 나는 뜬다."]},
		"good": {"fear": ["열차장님, 문 버텨요! 버텨요!", "열차장님 있으면 괜찮아요..."], "rough": ["대장 말대로 버틴다!", "문은 내가 잡는다, 대장!"], "quiet": ["열차장. 문은 맡겨.", "...안 열린다. 걱정 마."]},
	},
	# What is said to the chief: these stand instead of the voice's own.
	"retreat": {
		"bad": {"fear": ["이제야요? 진작 가자니까요!", "또 이렇게 도망가는 거예요...", "저 먼저 갈게요, 먼저!"], "rough": ["이제 와서 튀자고? 웃기네.", "진작 그럴 것이지.", "알아서 갈 테니 신경 꺼."], "quiet": ["...늦었다. 그래도 간다.", "내 짐부터 챙긴다.", "...각자 간다."]},
		"good": {"fear": ["네! 열차장님 따라갈게요!", "같이 가요, 열차장님!", "열차장님 먼저요, 빨리요!"], "rough": ["알았어, 대장! 뒤는 맡겨!", "대장 먼저 가! 따라간다!", "들었지! 대장 따라 철수!"], "quiet": ["알았다. 열차장 뒤를 본다.", "...철수. 열차장 먼저.", "다 챙겼다. 가자, 열차장."]},
	},
	"order_follow": {
		"bad": {"fear": ["또 어디 가는데요...", "따라가면 살긴 해요...?", "...알았어요. 알았다고요."], "rough": ["어디 또 끌고 가게.", "따라는 간다. 믿진 않아.", "앞장서 봐, 나리."], "quiet": ["...별수 없다. 간다.", "거리는 둔다.", "...이번만이다."]},
		"good": {"fear": ["네! 바로 뒤에 붙을게요!", "열차장님 따라갈게요!", "안 놓칠게요!"], "rough": ["가자, 대장!", "대장 등은 내가 본다.", "말만 해, 어디든."], "quiet": ["열차장 뒤에 선다.", "...가자.", "따른다."]},
	},
	"order_wait": {
		"bad": {"fear": ["또 혼자 두고 가요...?", "안 돌아오면요...? 네?", "여기서 죽으라는 거예요?"], "rough": ["여기 버리고 가겠다?", "안 오면 나 혼자 간다.", "기다리긴 한다. 오래는 안 해."], "quiet": ["...시간 지나면 빠진다.", "늦으면 먼저 간다.", "...그래, 또 대기."]},
		"good": {"fear": ["꼭 돌아와요, 네?", "여기 있을게요. 꼭요.", "조심해요, 열차장님!"], "rough": ["걱정 말고 다녀와, 대장.", "여긴 내가 지킨다.", "빨리 와, 대장."], "quiet": ["기다린다. 다녀와.", "...여기 지킨다. 조심해.", "열차장. 늦지 마."]},
	},
	"order_search": {
		"bad": {"fear": ["뒤지는 건 또 우리죠...", "찾은 건 누가 갖는데요..."], "rough": ["찾으면 내 몫부터다.", "시키는 건 잘하네."], "quiet": ["...찾은 건 내가 갖는다.", "알아서 뒤진다."]},
		"good": {"fear": ["네! 뭐든 찾아올게요!", "열차장님 필요한 거 찾을게요!"], "rough": ["좋아, 싹 털어 온다!", "대장 몫까지 챙긴다!"], "quiet": ["찾아온다.", "...뭐가 필요하지?"]},
	},
	"order_cover": {
		"bad": {"fear": ["저보고 막으라고요...?", "왜 맨날 저예요..."], "rough": ["총알받이 하라고?", "엄호는 한다. 빨리나 해."], "quiet": ["...이번만 막는다.", "등은 본다. 믿진 마."]},
		"good": {"fear": ["열차장님 뒤는 제가요!", "쏠게요! 안 놓쳐요!"], "rough": ["대장, 등은 맡겨!", "하나도 안 보낸다!"], "quiet": ["열차장. 등 맡겨.", "...아무것도 못 지나간다."]},
	},
	"search_start": {
		"bad": {"fear": ["이거라도 챙겨야지...", "제 몫은 제가 챙길게요.", "뭐 나오면 제 거예요..."], "rough": ["찾는 건 내 거다.", "내 몫은 내가 챙긴다.", "나눠 줄 생각 없다."], "quiet": ["...내 것부터 챙긴다.", "따로 챙겨 둔다.", "여긴 내가 뒤진다. 혼자."]},
		"good": {"fear": ["열차장님, 여긴 제가 볼게요!", "필요한 거 찾아 둘게요!", "같이 쓸 거 찾을게요!"], "rough": ["대장, 여긴 내가 깐다!", "열차 몫 챙겨 보자.", "쓸 만한 거 찾아 줄게."], "quiet": ["열차장. 여기 본다.", "...열차에 필요한 거.", "찾으면 넘긴다."]},
	},
	"found": {
		"bad": {"fear": ["이건 제가 가질게요...", "몰래 하나 챙겼어요...", "제 거예요, 이건..."], "rough": ["이건 내 거다. 손대지 마.", "열차엔 안 넘긴다.", "내릴 때 쓸 거다."], "quiet": ["...내 가방에 넣는다.", "이건 남겨 둔다. 나를 위해.", "...챙겼다. 내 몫."]},
		"good": {"fear": ["열차장님! 이거 봐요!", "이거 열차에 필요하죠?", "열차장님 몫도 챙겼어요!"], "rough": ["대장! 건졌다!", "이 정도면 열차 좀 버티겠다.", "대장 몫 따로 빼 놨다."], "quiet": ["열차장. 쓸 만한 거다.", "...열차에 가져간다.", "챙겼다. 열차장 거다."]},
	},
	"bag_full": {
		"bad": {"fear": ["이 무거운 걸 왜 제가...", "제 짐은 누가 들어 줘요..."], "rough": ["짐꾼 취급이냐, 시발.", "더 들라고? 니가 들어."], "quiet": ["...짐꾼이 아니다.", "더는 안 든다."]},
		"good": {"fear": ["더 못 들어요... 죄송해요...", "열차장님, 이건 못 넣었어요..."], "rough": ["대장, 가방 꽉 찼다!", "한 번 더 오자, 대장."], "quiet": ["열차장. 가방 찼다.", "...다음에 다시 온다."]},
	},
	"empty": {
		"bad": {"fear": ["거봐요, 없잖아요...", "이러려고 여기 왔어요...?", "헛걸음이에요, 또..."], "rough": ["좋은 데 데려왔네, 나리.", "털린 데만 고르냐.", "이럴 거면 왜 왔냐."], "quiet": ["...헛걸음이다. 또.", "판단이 틀렸다.", "...시간만 버렸다."]},
		"good": {"fear": ["죄송해요, 아무것도 없어요...", "다음 데는 있을 거예요!", "여긴 꽝이에요, 열차장님."], "rough": ["대장, 여긴 꽝이다.", "괜찮아, 다음 거 까자.", "털렸네. 다음 가자, 대장."], "quiet": ["열차장. 여긴 없다.", "...다음으로 간다.", "비었다. 딴 데 보자."]},
	},
	"left_behind": {
		"bad": {"fear": ["역시... 두고 가는구나...", "알았어요... 버리는 거죠...", "다들 똑같아..."], "rough": ["그럴 줄 알았다, 시발!", "버리고 가냐? 그래, 가라!", "두고 봐, 살아서 간다."], "quiet": ["...예상했다.", "...혼자 간다. 원래.", "버린 건 기억한다."]},
		"good": {"fear": ["열차장님...! 여기예요...!", "돌아올 거죠...? 그쵸...?", "열차장님... 기다릴게요..."], "rough": ["대장! 나 여기 있어!!", "대장, 안 버리는 거 알아!", "어이, 대장! 여기!!"], "quiet": ["열차장... 여기다.", "...믿는다. 돌아와.", "열차장. 아직 숨 쉰다."]},
	},
	"left_platform": {
		"bad": {"fear": ["결국 버리는구나...!!", "이럴 줄 알았어요!!"], "rough": ["끝까지 버리네, 시발!!", "살아서 쫓아간다, 두고 봐!!"], "quiet": ["...역시.", "...기억해 둔다."]},
		"good": {"fear": ["열차장님!! 저 여기 있어요!!", "열차장님, 기다려요!!"], "rough": ["대장!! 대장!! 세워!!", "대장, 나 아직 있어!!"], "quiet": ["열차장...! 여기다...!", "...다시 와라. 기다린다."]},
	},
	"ready": {
		"bad": {"fear": ["이제야요...?", "진작 갔어야죠..."], "rough": ["이제야냐? 다 죽을 뻔했다.", "타자마자 나는 쉰다."], "quiet": ["...늦었다.", "타면 각자다."]},
		"good": {"fear": ["열차장님, 됐대요! 가요!", "살았어요, 열차장님 덕분에!"], "rough": ["대장, 됐다! 가자!", "역시 대장이다!"], "quiet": ["열차장. 됐다.", "...잘 버텼다. 가자."]},
	},
	"last_call": {
		"bad": {"fear": ["두고 가면 안 돼요!! 안 돼!!", "기다려요!! 제발!!"], "rough": ["나 두고 출발하기만 해!!", "세워! 아직 안 탔어!!"], "quiet": ["...안 기다리겠지.", "알아서 탄다."]},
		"good": {"fear": ["열차장님 먼저 타요!!", "같이 타요, 같이!!"], "rough": ["대장, 먼저 타! 따라간다!", "다 탔나 본다, 대장 타!"], "quiet": ["열차장 먼저. 내가 마지막.", "...다 탔다. 가자."]},
	},
}
## What one remembers of an earlier stop (people-memory design 1.8, decision
## 439): the departure sheet carries each person's memory keys (cues), and the
## first time this stop they answer an order or the squad is ready, they say
## one of these instead, once. "saved_by:<id>" puts that companion's name in.
const MEMORY_LINES: Dictionary = {
	"saved_me": {
		"fear": ["그때 열차장님이 안 끌어냈으면... 저 지금 없어요.", "이번에도 옆에 있을게요."],
		"rough": ["빚진 건 안 잊는다, 대장.", "그날 잡아 준 손, 이번엔 내가 갚는다."],
		"quiet": ["...그날 일은 기억한다. 등은 맡겨.", "한 번 구해 줬다. 이번엔 내 차례다."],
	},
	"left_me": {
		"fear": ["또 두고 갈 거예요...? 그때처럼요?", "이번엔 안 보이는 데 가지 마요."],
		"rough": ["한 번 버린 놈은 두 번도 버려.", "등 돌리는 거, 한 번 봤다."],
		"quiet": ["...그때 멀어지던 등, 기억한다.", "이번엔 내 눈에 보이는 데 있어라."],
	},
	"saw_shot_surrendered": {
		"fear": ["손 든 사람이었잖아요...", "빈손이었는데... 꼭 쏴야 했어요?"],
		"rough": ["손 든 놈까지 쏘더라, 우리 대장은."],
		"quiet": ["...손을 들고 있었다."],
	},
	"saw_mercy": {
		"fear": ["그 사람... 보낸 거 잘한 거죠?"],
		"rough": ["그 약탈자 놈, 다시 보이면 그땐 내가 쏜다."],
		"quiet": ["...살려 보낸 건 잘했다."],
	},
	"saved_by": {
		"fear": ["{이름} 씨 아니었으면 저 거기서 못 나왔어요."],
		"rough": ["{이름}, 그날 빚 아직이다."],
		"quiet": ["...{이름}. 고맙다는 말 아직 못 했다."],
	},
}
## The moments a memory may be said in place of the moment's own line.
const MEMORY_MOMENTS: Array = ["order_follow", "order_wait", "order_search", "order_cover", "ready"]

## Said to the chief, so how one stands with him is the whole of it: one who
## stands badly or well says only their REL_LINES here.
const TOWARD_CHIEF: Array = ["retreat", "order_follow", "order_wait", "order_search", "order_cover",
		"search_start", "found", "bag_full", "empty", "left_behind", "left_platform", "ready", "last_call"]
## An event with no lines of its own borrows another's.
const FALLBACK: Dictionary = {"bite": "hurt"}
const GAP_SELF: float = 6.0
const GAP_SQUAD: float = 2.0
## Lying hurt or held, and the chief this far off: "left_behind", this often.
const LEFT_BEHIND_M: float = 10.0
const LEFT_BEHIND_GAP: float = 12.0
## A companion this near to one who fell is the one who rages.
const RAGE_NEAR: float = 8.0
## Said often, so one person says it at most this often (the bank's 4th part).
## A search begun, as often as a kill.
const EVENT_GAP: Dictionary = {"left_behind": LEFT_BEHIND_GAP, "kill": 30.0, "search_start": 30.0}
## Seen by several at once, so only one of the squad says it this often. The
## dead at a door strike it every 1.3 s: one word of it as seldom as a horde.
const SQUAD_GAP: Dictionary = {"horde_near": 20.0, "ally_down": 3.0, "door_bang": 20.0}

var _last_self: Dictionary = {}     # pid -> when they last spoke
var _last_event: Dictionary = {}    # "pid/event" -> when
var _last_any: float = -1000.0
var _last_line: Dictionary = {}     # pid -> the line they said last
var _rng := RandomNumberGenerator.new()
## pid -> how they stand with the chief ("bad", "normal", "good"); set as the
## squad is made (field_game.gd), "normal" for anyone not in it.
var rel_of: Dictionary = {}
## pid -> the voice they carry ("fear", "rough", "quiet"), from their row
## (field_game.gd default_squad); voice_of for anyone who carries none.
var voice_by: Dictionary = {}
## pid -> their own standing with the chief from what they lived through
## ("good", "bad"), from the departure sheet. It stands in place of their
## car's rel_of: one the chief pulled free does not distrust him because of
## how their car stands (people-memory design 1.4, R15).
var stance_by: Dictionary = {}
## pid -> their memory keys, newest first (the departure sheet's cues).
var cues_by: Dictionary = {}
## pid -> name, for a memory that names a companion.
var names_by: Dictionary = {}
var _memory_said: Dictionary = {}   # pid -> true once they said one this stop


func _init(seed_value: int = 0x11e5) -> void:
	_rng.seed = seed_value


## The stage of a car's rel with the chief (RELS).
static func rel_stage(rel: float) -> String:
	if rel >= REL_GOOD:
		return "good"
	if rel < REL_BAD:
		return "bad"
	return "normal"


## The lines of `event` for `voice` ("" = every voice) standing `rel` with the
## chief: the user's own, the voice's, and how they stand.
static func lines_for(event: String, voice: String = "", rel: String = "normal") -> Array:
	var voices: Array = [voice] if VOICES.has(voice) else VOICES
	var own: Array = []
	var stand: Array = []
	for v in voices:
		own.append_array(VOICED.get(event, {}).get(v, []))
		stand.append_array(REL_LINES.get(event, {}).get(rel, {}).get(v, []))
	if not stand.is_empty() and TOWARD_CHIEF.has(event):
		own = stand
	else:
		own.append_array(stand)
	var out: Array = (LINES.get(event, []) as Array) + own
	if out.is_empty() and FALLBACK.has(event):
		return lines_for(String(FALLBACK[event]), voice, rel)
	return out


## Every line there is, each once.
static func count_all() -> int:
	var seen := {}
	for e in LINES:
		for line in LINES[e]:
			seen[line] = true
	for e in VOICED:
		for v in VOICED[e]:
			for line in VOICED[e][v]:
				seen[line] = true
	for e in REL_LINES:
		for r in REL_LINES[e]:
			for v in REL_LINES[e][r]:
				for line in REL_LINES[e][r][v]:
					seen[line] = true
	return seen.size()


## The voice of one who carries none, from their id.
static func voice_of(pid: String) -> String:
	return String(VOICES[absi(pid.hash()) % VOICES.size()])


## The voice `pid` speaks in: their own, or voice_of.
func voice(pid: String) -> String:
	var v: String = String(voice_by.get(pid, ""))
	return v if VOICES.has(v) else voice_of(pid)


## How `pid` stands with the chief: their own memory's standing if they have
## one, else their car's.
func standing(pid: String) -> String:
	var s: String = String(stance_by.get(pid, ""))
	return s if RELS.has(s) else String(rel_of.get(pid, "normal"))


## The memory line `pid` would say now, "" for none: the newest of their cues
## that has a line in their voice (and, for saved_by, a known name).
func memory_line(pid: String) -> String:
	for cue: Variant in cues_by.get(pid, []):
		var key: String = String(cue)
		var who: String = ""
		if key.begins_with("saved_by:"):
			who = String(names_by.get(key.substr(9), ""))
			key = "saved_by"
			if who == "":
				continue
		var bank: Array = MEMORY_LINES.get(key, {}).get(voice(pid), [])
		if bank.is_empty():
			continue
		return String(bank[_rng.randi() % bank.size()]).replace("{이름}", who)
	return ""


## The line `pid` shouts for `event` at `now`, or "" if they keep quiet (no
## such line, or someone has only just spoken).
## `always`: this one is shouted whoever spoke just before (everyone left on
## the platform shouts at once).
## `name`: who fell, for the lines that call them by name.
func pick(pid: String, event: String, now: float, always: bool = false, name: String = "") -> String:
	var bank: Array = []
	for line in lines_for(event, voice(pid), standing(pid)):
		if name != "" or not String(line).contains("{이름}"):
			bank.append(line)
	if bank.is_empty():
		return ""
	if not always and (now - float(_last_self.get(pid, -1000.0)) < GAP_SELF or now - _last_any < GAP_SQUAD):
		return ""
	var key: String = pid + "/" + event
	if now - float(_last_event.get(key, -1000.0)) < float(EVENT_GAP.get(event, 0.0)):
		return ""
	if now - float(_last_event.get("*/" + event, -1000.0)) < float(SQUAD_GAP.get(event, 0.0)):
		return ""
	_last_self[pid] = now
	_last_event[key] = now
	_last_event["*/" + event] = now
	_last_any = now
	# Once a stop, the first order answered or the squad ready brings back what they remember.
	if MEMORY_MOMENTS.has(event) and not _memory_said.has(pid):
		var memory := memory_line(pid)
		if memory != "":
			_memory_said[pid] = true
			_last_line[pid] = memory
			return memory
	# Not the same line twice running.
	var line: String = String(bank[_rng.randi() % bank.size()])
	if bank.size() > 1 and line == String(_last_line.get(pid, "")):
		line = String(bank[(bank.find(line) + 1) % bank.size()])
	_last_line[pid] = line
	return line.replace("{이름}", name)
