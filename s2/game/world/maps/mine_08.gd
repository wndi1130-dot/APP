# 이 지도가 다른 판단을 만드는 것: 두 번 꺾이는 골짜기에서 긴 왕복 시간을 계산하고 지하 옆굴의 고철보다 귀환 여유를 먼저 남긴다.
extends RefCounted
## 지상·위층·아래 갱도. PLAN의 칸 좌표는 이 파일 안에서만 조립한다.
const FieldGrid = preload("res://game/world/field_grid.gd")
const S = FieldGrid.Solid
const F = FieldGrid.Floor
const WIDTH: int = 156
const HEIGHT: int = 110
const PLACE_ID: String = "mine_08"
const ZONE_NAMES: Dictionary = {"yard":"골짜기 앞마당","stock":"저탄장","mine":"갱도","below":"아래 갱도","office":"적재 관리동"}
## 무전 문장에 쓰는 들어오는 길의 이름, 길마다의 비중, 첫 물결이 오는 길.
const ENTRY_NAMES: Dictionary = {"mine_mouth": "갱도 입구", "access_road": "진입로", "open_edge": "트인 벌판", "deep_tunnel": "깊은 갱도"}
const ENTRY_WEIGHTS: Dictionary = {"mine_mouth": 0.2, "access_road": 0.35, "open_edge": 0.3, "deep_tunnel": 0.15}
const FIRST_ENTRY: String = "access_road"
const PLAN: Dictionary = {
	"id": 8,
	"w": 156,
	"h": 110,
	"judgment": "두 번 꺾이는 골짜기에서 긴 왕복 시간을 계산하고 지하 옆굴의 고철보다 귀환 여유를 먼저 남긴다.",
	"train": [
		42,
		78,
		80,
		3
	],
	"bands": [
		[
			22,
			58,
			120,
			20
		],
		[
			22,
			81,
			120,
			22
		]
	],
	"door_x": [
		58,
		78,
		102
	],
	"mountains": [
		[
			0,
			0,
			156,
			65
		]
	],
	"cuts": [
		[
			60,
			44,
			22,
			21
		],
		[
			60,
			30,
			67,
			22
		],
		[
			105,
			10,
			22,
			42
		],
		[
			40,
			6,
			87,
			22
		],
		[
			127,
			33,
			18,
			9
		]
	],
	"tunnels": [
		[
			14,
			16,
			26,
			3
		],
		[
			14,
			10,
			12,
			15
		]
	],
	"ground_rooms": [],
	"mouths": [
		{
			"cell": [
				39,
				17
			],
			"outward": [
				1,
				0
			]
		}
	],
	"down": [
		[
			18,
			17
		]
	],
	"houses": [
		{
			"id": 1,
			"name": "골짜기 관리동",
			"rect": [
				65,
				57,
				12,
				16
			],
			"zone": "office",
			"walls": [
				[
					71,
					58,
					1,
					14
				]
			],
			"doors": [
				[
					71,
					65
				],
				[
					68,
					72
				],
				[
					76,
					60
				]
			],
			"windows": [
				[
					68,
					57
				],
				[
					73,
					57
				],
				[
					65,
					61
				]
			],
			"rooms": [
				{
					"name": "작업실",
					"rect": [
						66,
						58,
						5,
						14
					]
				},
				{
					"name": "부품실",
					"rect": [
						72,
						58,
						4,
						14
					]
				}
			],
			"upper": [
				65,
				57,
				12,
				12
			],
			"upper_rooms": [
				{
					"name": "작업실",
					"rect": [
						66,
						58,
						5,
						10
					]
				},
				{
					"name": "부품실",
					"rect": [
						72,
						58,
						4,
						10
					]
				}
			],
			"stair": [
				67,
				59
			],
			"through": false,
			"upper_plan": {
				"id": 1,
				"name": "골짜기 관리동",
				"rect": [
					65,
					57,
					12,
					12
				],
				"zone": "office",
				"walls": [
					[
						71,
						58,
						1,
						10
					]
				],
				"doors": [
					[
						71,
						63
					],
					[
						68,
						68
					],
					[
						76,
						60
					]
				],
				"windows": [
					[
						68,
						57
					],
					[
						73,
						57
					],
					[
						65,
						61
					]
				],
				"rooms": [
					{
						"name": "작업실",
						"rect": [
							66,
							58,
							5,
							10
						]
					},
					{
						"name": "부품실",
						"rect": [
							72,
							58,
							4,
							10
						]
					}
				],
				"upper": [],
				"upper_rooms": [],
				"stair": [
					67,
					59
				],
				"through": false
			}
		}
	],
	"floors": [
		{
			"rect": [
				22,
				58,
				120,
				20
			],
			"kind": 7
		},
		{
			"rect": [
				22,
				81,
				120,
				22
			],
			"kind": 7
		},
		{
			"rect": [
				0,
				78,
				156,
				3
			],
			"kind": 4
		},
		{
			"rect": [
				0,
				70,
				156,
				3
			],
			"kind": 1
		},
		{
			"rect": [
				0,
				87,
				156,
				3
			],
			"kind": 1
		},
		{
			"rect": [
				35,
				55,
				4,
				53
			],
			"kind": 1
		},
		{
			"rect": [
				126,
				55,
				4,
				53
			],
			"kind": 1
		},
		{
			"rect": [
				37,
				16,
				3,
				3
			],
			"kind": 4
		},
		{
			"rect": [
				70,
				46,
				2,
				32
			],
			"kind": 4
		},
		{
			"rect": [
				70,
				40,
				46,
				2
			],
			"kind": 4
		},
		{
			"rect": [
				114,
				17,
				2,
				24
			],
			"kind": 4
		},
		{
			"rect": [
				40,
				17,
				76,
				2
			],
			"kind": 4
		},
		{
			"rect": [
				115,
				36,
				28,
				1
			],
			"kind": 4
		},
		{
			"rect": [
				18,
				103,
				36,
				1
			],
			"kind": 4
		},
		{
			"rect": [
				27,
				105,
				12,
				3
			],
			"kind": 7
		},
		{
			"rect": [
				79,
				103,
				36,
				1
			],
			"kind": 4
		},
		{
			"rect": [
				88,
				105,
				12,
				3
			],
			"kind": 7
		},
		{
			"rect": [
				65,
				73,
				12,
				3
			],
			"kind": 1
		},
		{
			"rect": [
				126,
				101,
				30,
				2
			],
			"kind": 1
		},
		{
			"rect": [
				44,
				8,
				4,
				1
			],
			"kind": 4
		},
		{
			"rect": [
				60,
				109,
				2,
				1
			],
			"kind": 4
		},
		{
			"rect": [
				45,
				17,
				4,
				1
			],
			"kind": 4
		}
	],
	"props": [
		{
			"kind": "coal_wagon",
			"rect": [
				28,
				102,
				10,
				3
			],
			"solid": "wagon",
			"facing": 0,
			"note": "석탄 화차"
		},
		{
			"kind": "coal_wagon",
			"rect": [
				89,
				102,
				10,
				3
			],
			"solid": "wagon",
			"facing": 0,
			"note": "석탄 화차"
		},
		{
			"kind": "crate_stack",
			"rect": [
				62,
				70,
				2,
				2
			],
			"solid": "low",
			"facing": 0,
			"note": "자재 상자 더미"
		},
		{
			"kind": "scrap_stack",
			"rect": [
				77,
				71,
				2,
				3
			],
			"solid": "low",
			"facing": 1,
			"note": "고철 더미"
		},
		{
			"kind": "sleeper_stack",
			"rect": [
				30,
				68,
				3,
				1
			],
			"solid": "low",
			"facing": 0,
			"note": "침목 더미"
		},
		{
			"kind": "snow_bank",
			"rect": [
				116,
				68,
				6,
				1
			],
			"solid": "low",
			"facing": 0,
			"note": "눈 둑"
		},
		{
			"kind": "crate_stack",
			"rect": [
				62,
				87,
				2,
				2
			],
			"solid": "low",
			"facing": 0,
			"note": "자재 상자 더미"
		},
		{
			"kind": "scrap_stack",
			"rect": [
				74,
				86,
				2,
				3
			],
			"solid": "low",
			"facing": 1,
			"note": "고철 더미"
		},
		{
			"kind": "sleeper_stack",
			"rect": [
				30,
				95,
				3,
				1
			],
			"solid": "low",
			"facing": 0,
			"note": "침목 더미"
		},
		{
			"kind": "snow_bank",
			"rect": [
				116,
				97,
				6,
				1
			],
			"solid": "low",
			"facing": 0,
			"note": "눈 둑"
		},
		{
			"kind": "rock_face",
			"rect": [
				38,
				104,
				6,
				3
			],
			"solid": "wall",
			"facing": 0,
			"note": "암벽 면"
		},
		{
			"kind": "coal_heap",
			"rect": [
				47,
				104,
				4,
				3
			],
			"solid": "low",
			"facing": 0,
			"note": "석탄 더미"
		},
		{
			"kind": "rock_face",
			"rect": [
				99,
				104,
				6,
				3
			],
			"solid": "wall",
			"facing": 0,
			"note": "암벽 면"
		},
		{
			"kind": "coal_heap",
			"rect": [
				108,
				104,
				4,
				3
			],
			"solid": "low",
			"facing": 0,
			"note": "석탄 더미"
		},
		{
			"kind": "rock_face",
			"rect": [
				34,
				8,
				6,
				3
			],
			"solid": "wall",
			"facing": 0,
			"note": "암벽 면"
		},
		{
			"kind": "rock_face",
			"rect": [
				34,
				23,
				6,
				3
			],
			"solid": "wall",
			"facing": 0,
			"note": "암벽 면"
		},
		{
			"kind": "rock_ridge",
			"rect": [
				3,
				2,
				8,
				6
			],
			"solid": "wall",
			"facing": 0,
			"note": "산 능선"
		},
		{
			"kind": "rock_ridge",
			"rect": [
				139,
				8,
				8,
				6
			],
			"solid": "wall",
			"facing": 0,
			"note": "산 능선"
		},
		{
			"kind": "vent_pipe",
			"rect": [
				3,
				1,
				1,
				1
			],
			"solid": "wall",
			"facing": 0,
			"note": "환기관"
		},
		{
			"kind": "vent_pipe",
			"rect": [
				6,
				1,
				1,
				1
			],
			"solid": "wall",
			"facing": 0,
			"note": "환기관"
		},
		{
			"kind": "mine_portal",
			"rect": [
				38,
				16,
				2,
				3
			],
			"solid": "none",
			"facing": 1,
			"note": "갱구 틀"
		},
		{
			"kind": "support_frame",
			"rect": [
				34,
				16,
				1,
				3
			],
			"solid": "none",
			"facing": 0,
			"note": "버팀목 틀"
		},
		{
			"kind": "ore_cart",
			"rect": [
				45,
				8,
				2,
				1
			],
			"solid": "low",
			"facing": 0,
			"note": "광차"
		},
		{
			"kind": "pit_props",
			"rect": [
				41,
				11,
				3,
				1
			],
			"solid": "low",
			"facing": 0,
			"note": "갱목 더미"
		},
		{
			"kind": "tool_rack",
			"rect": [
				48,
				13,
				2,
				1
			],
			"solid": "low",
			"facing": 0,
			"note": "연장 걸이"
		},
		{
			"kind": "rubble_pile",
			"rect": [
				54,
				12,
				4,
				3
			],
			"solid": "low",
			"facing": 0,
			"note": "낙반 더미"
		},
		{
			"kind": "ore_cart_tipped",
			"rect": [
				45,
				16,
				2,
				2
			],
			"solid": "low",
			"facing": 0,
			"note": "넘어진 광차"
		},
		{
			"kind": "tool_rack",
			"rect": [
				84,
				34,
				2,
				1
			],
			"solid": "low",
			"facing": 0,
			"note": "연장 걸이"
		},
		{
			"kind": "scrap_stack",
			"rect": [
				80,
				37,
				3,
				2
			],
			"solid": "low",
			"facing": 0,
			"note": "고철 더미"
		},
		{
			"kind": "fuel_drum",
			"rect": [
				77,
				32,
				1,
				1
			],
			"solid": "low",
			"facing": 0,
			"note": "연료 드럼"
		},
		{
			"kind": "fuel_drum",
			"rect": [
				93,
				38,
				1,
				1
			],
			"solid": "low",
			"facing": 0,
			"note": "연료 드럼"
		},
		{
			"kind": "fuel_drum",
			"rect": [
				75,
				39,
				1,
				1
			],
			"solid": "low",
			"facing": 0,
			"note": "연료 드럼"
		},
		{
			"kind": "boulder",
			"rect": [
				109,
				8,
				2,
				2
			],
			"solid": "low",
			"facing": 0,
			"note": "큰 바위"
		},
		{
			"kind": "dry_grass",
			"rect": [
				105,
				11,
				2,
				2
			],
			"solid": "none",
			"facing": 0,
			"note": "마른 풀 무리"
		},
		{
			"kind": "sleeper_stack",
			"rect": [
				102,
				6,
				3,
				1
			],
			"solid": "low",
			"facing": 0,
			"note": "침목 더미"
		},
		{
			"kind": "coal_heap",
			"rect": [
				11,
				76,
				4,
				3
			],
			"solid": "low",
			"facing": 0,
			"note": "석탄 더미"
		},
		{
			"kind": "slag_heap",
			"rect": [
				7,
				79,
				3,
				3
			],
			"solid": "low",
			"facing": 0,
			"note": "폐석 더미"
		},
		{
			"kind": "water_barrel",
			"rect": [
				4,
				74,
				2,
				2
			],
			"solid": "low",
			"facing": 0,
			"note": "리벳 쇠 물통"
		},
		{
			"kind": "drain_ditch",
			"rect": [
				20,
				80,
				4,
				1
			],
			"solid": "none",
			"facing": 0,
			"note": "배수 도랑"
		},
		{
			"kind": "coal_sorter",
			"rect": [
				51,
				105,
				4,
				3
			],
			"solid": "wall",
			"facing": 0,
			"note": "선탄기"
		},
		{
			"kind": "hopper",
			"rect": [
				63,
				105,
				3,
				3
			],
			"solid": "wall",
			"facing": 0,
			"note": "석탄 호퍼"
		},
		{
			"kind": "conveyor",
			"rect": [
				44,
				103,
				6,
				1
			],
			"solid": "low",
			"facing": 0,
			"note": "컨베이어 토막"
		},
		{
			"kind": "track_switch",
			"rect": [
				60,
				109,
				2,
				1
			],
			"solid": "none",
			"facing": 0,
			"note": "선로 전환기"
		},
		{
			"kind": "ore_truck",
			"rect": [
				140,
				78,
				6,
				3
			],
			"solid": "wall",
			"facing": 0,
			"note": "광석 트럭"
		},
		{
			"kind": "weigh_scale",
			"rect": [
				125,
				79,
				3,
				2
			],
			"solid": "low",
			"facing": 0,
			"note": "계량대"
		},
		{
			"kind": "power_pole",
			"rect": [
				144,
				81,
				1,
				1
			],
			"solid": "wall",
			"facing": 0,
			"note": "전신주"
		},
		{
			"kind": "rail_marker",
			"rect": [
				142,
				89,
				1,
				1
			],
			"solid": "none",
			"facing": 0,
			"note": "거리 말뚝"
		},
		{
			"kind": "mine_track",
			"rect": [
				45,
				17,
				4,
				1
			],
			"solid": "none",
			"facing": 1,
			"note": "광차 선로"
		},
		{
			"kind": "scrap_stack",
			"rect": [
				137,
				38,
				3,
				2
			],
			"solid": "low",
			"facing": 0,
			"note": "고철 더미"
		},
		{
			"kind": "boulder",
			"rect": [
				143,
				34,
				2,
				2
			],
			"solid": "low",
			"facing": 0,
			"note": "큰 바위"
		},
		{
			"kind": "spruce",
			"rect": [
				3,
				69,
				1,
				1
			],
			"solid": "tree",
			"facing": 0,
			"note": "눈 얹힌 가문비"
		},
		{
			"kind": "spruce",
			"rect": [
				10,
				86,
				1,
				1
			],
			"solid": "tree",
			"facing": 0,
			"note": "눈 얹힌 가문비"
		},
		{
			"kind": "spruce",
			"rect": [
				11,
				106,
				1,
				1
			],
			"solid": "tree",
			"facing": 0,
			"note": "눈 얹힌 가문비"
		},
		{
			"kind": "spruce",
			"rect": [
				150,
				67,
				1,
				1
			],
			"solid": "tree",
			"facing": 0,
			"note": "눈 얹힌 가문비"
		}
	],
	"trees": [
		[
			3,
			69
		],
		[
			7,
			68
		],
		[
			0,
			67
		],
		[
			4,
			73
		],
		[
			2,
			65
		],
		[
			6,
			75
		],
		[
			9,
			66
		],
		[
			3,
			76
		],
		[
			9,
			75
		],
		[
			1,
			77
		],
		[
			11,
			74
		],
		[
			10,
			86
		],
		[
			3,
			85
		],
		[
			7,
			91
		],
		[
			11,
			90
		],
		[
			2,
			92
		],
		[
			5,
			83
		],
		[
			9,
			93
		],
		[
			12,
			84
		],
		[
			6,
			94
		],
		[
			12,
			93
		],
		[
			1,
			83
		],
		[
			4,
			95
		],
		[
			11,
			106
		],
		[
			17,
			103
		],
		[
			10,
			102
		],
		[
			14,
			108
		],
		[
			18,
			107
		],
		[
			9,
			109
		],
		[
			12,
			100
		],
		[
			19,
			101
		],
		[
			8,
			104
		],
		[
			8,
			100
		],
		[
			20,
			105
		],
		[
			6,
			107
		],
		[
			150,
			67
		],
		[
			143,
			66
		],
		[
			142,
			73
		],
		[
			149,
			74
		],
		[
			152,
			65
		],
		[
			146,
			75
		],
		[
			152,
			74
		],
		[
			153,
			69
		],
		[
			144,
			76
		],
		[
			154,
			73
		],
		[
			146,
			68
		],
		[
			148,
			69
		],
		[
			146,
			86
		],
		[
			150,
			92
		],
		[
			154,
			91
		],
		[
			145,
			93
		],
		[
			148,
			84
		],
		[
			152,
			94
		],
		[
			155,
			85
		],
		[
			149,
			95
		],
		[
			155,
			94
		],
		[
			144,
			84
		],
		[
			142,
			91
		],
		[
			152,
			82
		],
		[
			148,
			109
		],
		[
			152,
			108
		],
		[
			142,
			105
		],
		[
			154,
			106
		],
		[
			140,
			108
		],
		[
			150,
			99
		],
		[
			147,
			105
		],
		[
			149,
			106
		],
		[
			145,
			107
		],
		[
			151,
			104
		],
		[
			144,
			103
		],
		[
			46,
			107
		],
		[
			44,
			108
		],
		[
			97,
			108
		],
		[
			104,
			109
		],
		[
			107,
			109
		],
		[
			109,
			108
		],
		[
			102,
			107
		],
		[
			106,
			106
		],
		[
			17,
			69
		],
		[
			13,
			73
		],
		[
			13,
			69
		],
		[
			21,
			67
		],
		[
			16,
			81
		],
		[
			18,
			73
		],
		[
			20,
			74
		],
		[
			16,
			75
		],
		[
			19,
			77
		],
		[
			148,
			82
		],
		[
			151,
			73
		],
		[
			145,
			83
		],
		[
			151,
			82
		],
		[
			152,
			77
		],
		[
			143,
			84
		],
		[
			153,
			81
		],
		[
			145,
			76
		],
		[
			147,
			77
		],
		[
			149,
			75
		],
		[
			142,
			74
		]
	],
	"covers": [
		[
			62,
			70,
			2,
			2
		],
		[
			77,
			71,
			2,
			3
		],
		[
			30,
			68,
			3,
			1
		],
		[
			116,
			68,
			6,
			1
		],
		[
			62,
			87,
			2,
			2
		],
		[
			74,
			86,
			2,
			3
		],
		[
			30,
			95,
			3,
			1
		],
		[
			116,
			97,
			6,
			1
		],
		[
			47,
			104,
			4,
			3
		],
		[
			108,
			104,
			4,
			3
		],
		[
			45,
			8,
			2,
			1
		],
		[
			41,
			11,
			3,
			1
		],
		[
			48,
			13,
			2,
			1
		],
		[
			54,
			12,
			4,
			3
		],
		[
			45,
			16,
			2,
			2
		],
		[
			84,
			34,
			2,
			1
		],
		[
			80,
			37,
			3,
			2
		],
		[
			77,
			32,
			1,
			1
		],
		[
			93,
			38,
			1,
			1
		],
		[
			75,
			39,
			1,
			1
		],
		[
			109,
			8,
			2,
			2
		],
		[
			102,
			6,
			3,
			1
		],
		[
			11,
			76,
			4,
			3
		],
		[
			7,
			79,
			3,
			3
		],
		[
			4,
			74,
			2,
			2
		],
		[
			44,
			103,
			6,
			1
		],
		[
			125,
			79,
			3,
			2
		],
		[
			137,
			38,
			3,
			2
		],
		[
			143,
			34,
			2,
			2
		]
	],
	"gates": [
		[
			62,
			61,
			3,
			1
		],
		[
			77,
			61,
			3,
			1
		],
		[
			44,
			105,
			3,
			1
		],
		[
			105,
			105,
			3,
			1
		]
	],
	"wagons": [
		[
			28,
			102,
			10,
			3
		],
		[
			89,
			102,
			10,
			3
		]
	],
	"stores": [
		{
			"id": "side_valley_spares",
			"name": "옆골짜기 예비 부품함",
			"cell": [
				141,
				40
			],
			"items": [
				"scrap",
				"wood"
			],
			"level": 0
		},
		{
			"id": "house_1_0",
			"name": "골짜기 관리동 작업실 자재함",
			"cell": [
				67,
				59
			],
			"items": [
				"scrap",
				"wood"
			],
			"level": 0
		},
		{
			"id": "house_1_1",
			"name": "골짜기 관리동 부품실 자재함",
			"cell": [
				73,
				59
			],
			"items": [
				"scrap",
				"wood"
			],
			"level": 0
		},
		{
			"id": "upper_1_0",
			"name": "골짜기 관리동 위층 작업실 상자",
			"cell": [
				67,
				59
			],
			"items": [
				"wood",
				"scrap"
			],
			"level": 1
		},
		{
			"id": "upper_1_1",
			"name": "골짜기 관리동 위층 부품실 상자",
			"cell": [
				73,
				59
			],
			"items": [
				"wood",
				"scrap"
			],
			"level": 1
		},
		{
			"id": "surface_0",
			"name": "저탄장 자재함",
			"cell": [
				30,
				106
			],
			"items": [
				"scrap",
				"wood"
			],
			"level": 0
		},
		{
			"id": "surface_1",
			"name": "저탄장 자재함",
			"cell": [
				91,
				106
			],
			"items": [
				"scrap",
				"wood"
			],
			"level": 0
		},
		{
			"id": "forehall_0",
			"name": "갱구 앞방 수리함",
			"cell": [
				33,
				17
			],
			"items": [
				"scrap",
				"wood"
			],
			"level": 0
		},
		{
			"id": "deep_0",
			"name": "권양기 방 자재함",
			"cell": [
				12,
				4
			],
			"items": [
				"scrap",
				"wood",
				"scrap"
			],
			"level": -1
		},
		{
			"id": "deep_1",
			"name": "공구 막장 자재함",
			"cell": [
				3,
				25
			],
			"items": [
				"scrap",
				"wood",
				"scrap"
			],
			"level": -1
		},
		{
			"id": "deep_2",
			"name": "예비 부품 막장 자재함",
			"cell": [
				3,
				38
			],
			"items": [
				"scrap",
				"wood",
				"scrap"
			],
			"level": -1
		},
		{
			"id": "deep_reserve",
			"name": "갱도 예비 공구함",
			"cell": [
				11,
				49
			],
			"items": [
				"scrap",
				"wood"
			],
			"level": -1
		},
		{
			"id": "deep_fuel",
			"name": "안쪽 연료함",
			"cell": [
				20,
				13
			],
			"items": [
				"wood",
				"wood",
				"scrap"
			],
			"level": -1
		}
	],
	"salvage": [
		{
			"id": "side_valley_scrap",
			"cell": [
				142,
				37
			],
			"name": "옆골짜기 고철",
			"amount": 4
		},
		{
			"id": "scrap_0",
			"cell": [
				35,
				106
			],
			"name": "측선 고철",
			"amount": 3
		},
		{
			"id": "scrap_1",
			"cell": [
				96,
				106
			],
			"name": "측선 고철",
			"amount": 3
		}
	],
	"tree_centers": [
		[
			3,
			69
		],
		[
			6,
			87
		],
		[
			13,
			104
		],
		[
			146,
			68
		],
		[
			149,
			88
		],
		[
			147,
			105
		],
		[
			46,
			100
		],
		[
			101,
			103
		],
		[
			18,
			73
		],
		[
			145,
			76
		]
	],
	"clusters": [
		[
			45,
			8,
			"pit"
		],
		[
			84,
			34,
			"repair"
		],
		[
			109,
			8,
			"forest"
		],
		[
			11,
			76,
			"coal"
		],
		[
			51,
			105,
			"load"
		],
		[
			132,
			81,
			"road"
		]
	],
	"assumptions": [
		"1칸은 1m. 공구·부품은 scrap, 연료는 wood, 석탄은 화차 coal로 기록한다. 지하 입구와 계단 거리는 네 방향 최단 걸음으로 센다.",
		"위층은 해당 건물 범위만 만들고 나머지는 AIR, 지하는 파낸 칸과 바로 둘레만 그린다. 지하의 깊은 갱 자리는 벽 면의 예약 좌표이며 새 반환 열쇠를 만들지 않는다."
	],
	"group_members": [
		[
			22,
			23,
			24,
			25,
			26
		],
		[
			27,
			28,
			29,
			30,
			31
		],
		[
			32,
			33,
			34
		],
		[
			35,
			36,
			37,
			38
		],
		[
			39,
			40,
			41,
			42
		],
		[
			43,
			44,
			45,
			46
		]
	],
	"tree_groups": [
		[
			[
				3,
				69
			],
			[
				7,
				68
			],
			[
				0,
				67
			],
			[
				4,
				73
			],
			[
				2,
				65
			],
			[
				6,
				75
			],
			[
				9,
				66
			],
			[
				3,
				76
			],
			[
				9,
				75
			],
			[
				1,
				77
			],
			[
				11,
				74
			]
		],
		[
			[
				10,
				86
			],
			[
				3,
				85
			],
			[
				7,
				91
			],
			[
				11,
				90
			],
			[
				2,
				92
			],
			[
				5,
				83
			],
			[
				9,
				93
			],
			[
				12,
				84
			],
			[
				6,
				94
			],
			[
				12,
				93
			],
			[
				1,
				83
			],
			[
				4,
				95
			]
		],
		[
			[
				11,
				106
			],
			[
				17,
				103
			],
			[
				10,
				102
			],
			[
				14,
				108
			],
			[
				18,
				107
			],
			[
				9,
				109
			],
			[
				12,
				100
			],
			[
				19,
				101
			],
			[
				8,
				104
			],
			[
				8,
				100
			],
			[
				20,
				105
			],
			[
				6,
				107
			]
		],
		[
			[
				150,
				67
			],
			[
				143,
				66
			],
			[
				142,
				73
			],
			[
				149,
				74
			],
			[
				152,
				65
			],
			[
				146,
				75
			],
			[
				152,
				74
			],
			[
				153,
				69
			],
			[
				144,
				76
			],
			[
				154,
				73
			],
			[
				146,
				68
			],
			[
				148,
				69
			]
		],
		[
			[
				146,
				86
			],
			[
				150,
				92
			],
			[
				154,
				91
			],
			[
				145,
				93
			],
			[
				148,
				84
			],
			[
				152,
				94
			],
			[
				155,
				85
			],
			[
				149,
				95
			],
			[
				155,
				94
			],
			[
				144,
				84
			],
			[
				142,
				91
			],
			[
				152,
				82
			]
		],
		[
			[
				148,
				109
			],
			[
				152,
				108
			],
			[
				142,
				105
			],
			[
				154,
				106
			],
			[
				140,
				108
			],
			[
				150,
				99
			],
			[
				147,
				105
			],
			[
				149,
				106
			],
			[
				145,
				107
			],
			[
				151,
				104
			],
			[
				144,
				103
			]
		],
		[
			[
				46,
				107
			],
			[
				44,
				108
			]
		],
		[
			[
				97,
				108
			],
			[
				104,
				109
			],
			[
				107,
				109
			],
			[
				109,
				108
			],
			[
				102,
				107
			],
			[
				106,
				106
			]
		],
		[
			[
				17,
				69
			],
			[
				13,
				73
			],
			[
				13,
				69
			],
			[
				21,
				67
			],
			[
				16,
				81
			],
			[
				18,
				73
			],
			[
				20,
				74
			],
			[
				16,
				75
			],
			[
				19,
				77
			]
		],
		[
			[
				148,
				82
			],
			[
				151,
				73
			],
			[
				145,
				83
			],
			[
				151,
				82
			],
			[
				152,
				77
			],
			[
				143,
				84
			],
			[
				153,
				81
			],
			[
				145,
				76
			],
			[
				147,
				77
			],
			[
				149,
				75
			],
			[
				142,
				74
			]
		]
	],
	"underground": {
		"digs": [
			[
				10,
				12,
				3,
				39
			],
			[
				19,
				12,
				3,
				39
			],
			[
				10,
				12,
				12,
				3
			],
			[
				10,
				48,
				12,
				3
			],
			[
				13,
				10,
				2,
				3
			],
			[
				6,
				26,
				5,
				2
			],
			[
				7,
				39,
				4,
				2
			],
			[
				11,
				3,
				6,
				7
			],
			[
				2,
				24,
				4,
				6
			],
			[
				2,
				37,
				5,
				6
			],
			[
				18,
				16,
				2,
				3
			],
			[
				18,
				17,
				3,
				1
			]
		],
		"rooms": [
			{
				"name": "권양기 방",
				"rect": [
					11,
					3,
					6,
					7
				],
				"pocket": false
			},
			{
				"name": "공구 막장",
				"rect": [
					2,
					24,
					4,
					6
				],
				"pocket": true
			},
			{
				"name": "예비 부품 막장",
				"rect": [
					2,
					37,
					5,
					6
				],
				"pocket": true
			}
		],
		"pillars": [
			[
				12,
				8
			]
		],
		"stairs": [
			[
				18,
				17
			]
		],
		"entry": [
			10,
			45
		],
		"hoist": [
			11,
			3,
			6,
			7
		],
		"deep": [
			13,
			2
		],
		"stores": [
			{
				"id": "deep_0",
				"name": "권양기 방 자재함",
				"cell": [
					12,
					4
				],
				"items": [
					"scrap",
					"wood",
					"scrap"
				],
				"level": -1
			},
			{
				"id": "deep_1",
				"name": "공구 막장 자재함",
				"cell": [
					3,
					25
				],
				"items": [
					"scrap",
					"wood",
					"scrap"
				],
				"level": -1
			},
			{
				"id": "deep_2",
				"name": "예비 부품 막장 자재함",
				"cell": [
					3,
					38
				],
				"items": [
					"scrap",
					"wood",
					"scrap"
				],
				"level": -1
			},
			{
				"id": "deep_reserve",
				"name": "갱도 예비 공구함",
				"cell": [
					11,
					49
				],
				"items": [
					"scrap",
					"wood"
				],
				"level": -1
			},
			{
				"id": "deep_fuel",
				"name": "안쪽 연료함",
				"cell": [
					20,
					13
				],
				"items": [
					"wood",
					"wood",
					"scrap"
				],
				"level": -1
			}
		],
		"dead": [
			[
				11,
				3
			],
			[
				12,
				3
			],
			[
				2,
				24
			],
			[
				3,
				24
			],
			[
				2,
				37
			],
			[
				3,
				37
			]
		],
		"inner_room": [
			2,
			37,
			5,
			6
		]
	},
	"zones": {
		"yard": "골짜기 앞마당",
		"stock": "저탄장",
		"mine": "갱도",
		"below": "아래 갱도",
		"office": "적재 관리동"
	},
	"cliffs": [
		[
			60,
			60,
			2,
			3
		],
		[
			80,
			60,
			2,
			3
		]
	],
	"face_tags": [
		[
			34,
			8,
			6,
			3
		],
		[
			34,
			23,
			6,
			3
		]
	],
	"ridge_tags": [
		[
			3,
			2,
			8,
			6
		],
		[
			139,
			8,
			8,
			6
		]
	],
	"doors": [
		[
			58,
			77
		],
		[
			58,
			81
		],
		[
			78,
			77
		],
		[
			78,
			81
		],
		[
			102,
			77
		],
		[
			102,
			81
		]
	],
	"entries": {
		"mine_mouth": [
			[
				36,
				16
			],
			[
				36,
				17
			],
			[
				36,
				18
			]
		],
		"access_road": [
			[
				155,
				101
			],
			[
				155,
				102
			]
		],
		"open_edge": [
			[
				0,
				88
			],
			[
				0,
				71
			]
		],
		"deep_tunnel": [
			[
				10,
				45
			]
		]
	},
	"entry_gap": {
		"mine_mouth": 2.5,
		"access_road": 0.6,
		"open_edge": 0.6,
		"deep_tunnel": 2.5
	},
	"wagon_rows": [
		{
			"id": "coal_0",
			"name": "석탄 화차",
			"rect": [
				28,
				102,
				10,
				3
			],
			"coal": 18,
			"work": [
				31,
				105
			]
		},
		{
			"id": "coal_1",
			"name": "석탄 화차",
			"rect": [
				89,
				102,
				10,
				3
			],
			"coal": 21,
			"work": [
				92,
				105
			]
		}
	]
}
# END_PLAN

static func _r(a: Array) -> Rect2i:
	return Rect2i(int(a[0]), int(a[1]), int(a[2]), int(a[3]))

static func _c(a: Array) -> Vector2i:
	return Vector2i(int(a[0]), int(a[1]))

static func _paint(g: FieldGrid, r: Rect2i, solid: int = -1, floor_kind: int = -1, building: int = -2) -> void:
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			var c := Vector2i(x, y)
			if solid >= 0:
				g.set_solid(c, solid)
			if floor_kind >= 0:
				g.floor[g.index(c)] = floor_kind
			if building >= -1:
				g.building[g.index(c)] = building

static func _house(g: FieldGrid, row: Dictionary) -> void:
	var r := _r(row["rect"])
	var id: int = row["id"]
	_paint(g, r, S.WALL, F.WOOD, id)
	_paint(g, r.grow(-1), S.NONE)
	for a: Array in row["walls"]:
		_paint(g, _r(a), S.WALL)
	for a: Array in row["doors"]:
		var c := _c(a)
		g.set_solid(c, S.DOOR)
		g.doors[c] = {"state": "open", "hp": 8, "building": id, "cell": c}
	for a: Array in row["windows"]:
		var c := _c(a)
		g.set_solid(c, S.WINDOW)
		g.windows[c] = {"broken": false, "glass": false, "building": id, "cell": c}

static func build() -> Dictionary:
	var g := FieldGrid.new(WIDTH, HEIGHT)
	var up := FieldGrid.new(WIDTH, HEIGHT)
	up.solid.fill(S.AIR)
	var below := FieldGrid.new(WIDTH, HEIGHT)
	below.solid.fill(S.BLOCK)
	below.opq.fill(1)
	var train := _r(PLAN["train"])
	var upper := _r(PLAN["bands"][0])
	var lower := _r(PLAN["bands"][1])
	var data := {
		"grid": g, "levels": {0: g, 1: up, -1: below}, "stairs": [],
		"containers": {}, "spots": {}, "stoves": [], "entries": {},
		"buildings": [], "wagons": [], "train": train,
		"platform": Rect2i(train.position.x, train.end.y, 80, 3),
		"spawns": {}, "labels": [], "trees": [], "low_blocks": [], "upper_rects": [],
		"train_cars": [], "lights": [], "manholes": {}, "manhole_levels": {}, "sewer_names": {},
		"entry_levels": {}, "entry_gap": PLAN["entry_gap"].duplicate(),
		"entry_names": ENTRY_NAMES.duplicate(), "entry_weights": ENTRY_WEIGHTS.duplicate(), "first_entry": FIRST_ENTRY,
		"zone_names": ZONE_NAMES.duplicate(),
		"unload": Rect2i(train.position.x, train.position.y - 3, 80, 9),
		"place_id": PLACE_ID, "place_kind": "mine", "bands": {"upper": upper, "lower": lower},
		"train_doors": {"upper": [], "lower": []}, "crossings": [], "barricade_slots": [],
		"interior_kind_slots": [{"zone": "below", "kinds": ["empty", "raiders", "nest", "beasts"]}],
		"props": [],
	}
	for row: Dictionary in PLAN["floors"]:
		_paint(g, _r(row["rect"]), -1, int(row["kind"]))
	var mountain_bounds := _r(PLAN["mountains"][0])
	for a: Array in PLAN["mountains"]:
		var r := _r(a)
		_paint(g, r, S.WALL, F.GRAVEL, 0)
		mountain_bounds = mountain_bounds.merge(r)
	for a: Array in PLAN["cuts"]:
		_paint(g, _r(a), S.NONE, F.GRAVEL, -1)
	for a: Array in PLAN["tunnels"]:
		_paint(g, _r(a), S.NONE, F.GRAVEL, 0)
	for a: Array in PLAN["cliffs"]:
		_paint(g, _r(a), S.WALL, F.GRAVEL, 0)
	for row: Dictionary in PLAN["floors"]:
		var r := _r(row["rect"])
		for y in range(r.position.y, r.end.y):
			for x in range(r.position.x, r.end.x):
				var c := Vector2i(x, y)
				if g.solid_at(c) == S.NONE:
					g.floor[g.index(c)] = int(row["kind"])
	var mouths: Array = []
	for row: Dictionary in PLAN["mouths"]:
		mouths.append({"cell": _c(row["cell"]), "outward": _c(row["outward"])})
	data["buildings"].append({"id": 0, "name": ZONE_NAMES["mine"], "rect": mountain_bounds, "warm": false, "window_broken": false, "rooms": [], "entrances": mouths})
	for row: Dictionary in PLAN["houses"]:
		_house(g, row)
		var rooms: Array = []
		for room: Dictionary in row["rooms"]:
			rooms.append({"name": room["name"], "rect": _r(room["rect"])})
		data["buildings"].append({"id": row["id"], "name": row["name"], "rect": _r(row["rect"]), "warm": false, "window_broken": false, "rooms": rooms})
		if not row["upper"].is_empty():
			_house(up, row["upper_plan"])
			data["upper_rects"].append({"building": row["id"], "rect": _r(row["upper"])})
			data["stairs"].append({"cell": _c(row["stair"]), "low": 0, "high": 1, "ladder": false})
		data["labels"].append({"text": row["name"], "cell": _c(row["stair"]), "level": 0})
	for row: Dictionary in PLAN["props"]:
		var prop: Dictionary = row.duplicate(true)
		var r := _r(row["rect"])
		prop["rect"] = r
		data["props"].append(prop)
		match String(row["solid"]):
			"low":
				_paint(g, r, S.LOW)
				data["low_blocks"].append(r)
			"wall": _paint(g, r, S.WALL)
			"tree", "wagon": _paint(g, r, S.BLOCK)
	for a: Array in PLAN["trees"]:
		var c := _c(a)
		g.set_solid(c, S.BLOCK)
		data["trees"].append(c)
	for row: Dictionary in PLAN["wagon_rows"]:
		var wagon: Dictionary = row.duplicate(true)
		wagon["rect"] = _r(row["rect"])
		wagon["work"] = _c(row["work"])
		data["wagons"].append(wagon)
	_paint(g, train, S.BLOCK, F.RAIL, -1)
	_paint(g, Rect2i(train.position.x, train.position.y - 3, 80, 3), -1, F.PLATFORM)
	_paint(g, data["platform"], -1, F.PLATFORM)
	for x: int in PLAN["door_x"]:
		data["train_doors"]["upper"].append(Vector2i(x, train.position.y - 1))
		data["train_doors"]["lower"].append(Vector2i(x, train.end.y))
	for x: int in [train.position.x - 2, train.end.x + 1]:
		var crossing: Array[Vector2i] = []
		for y in range(train.position.y - 3, train.end.y + 3):
			crossing.append(Vector2i(x, y))
		data["crossings"].append({"cells": crossing, "who": {"person": true, "zombie": true, "carrying": true, "wounded": true, "sled": true}})
	for a: Array in PLAN["gates"]:
		var r := _r(a)
		for y in range(r.position.y, r.end.y):
			for x in range(r.position.x, r.end.x):
				data["barricade_slots"].append(Vector2i(x, y))
	for y in range(HEIGHT):
		for x in range(WIDTH):
			var c := Vector2i(x, y)
			var zone := "stock" if y >= train.end.y else "yard"
			if g.building_at(c) == 0:
				zone = "mine"
			for row: Dictionary in PLAN["houses"]:
				if g.building_at(c) == int(row["id"]):
					zone = row["zone"]
			g.zone[g.index(c)] = zone
	var ug: Dictionary = PLAN["underground"]
	for a: Array in ug["digs"]:
		_paint(below, _r(a), S.NONE, F.GRAVEL, 0)
	for a: Array in ug["pillars"]:
		_paint(below, Rect2i(_c(a), Vector2i.ONE), S.WALL, F.GRAVEL, 0)
	# Draw only the immediate rock faces around excavations, not an entire buried slab.
	for y in range(HEIGHT):
		for x in range(WIDTH):
			var c := Vector2i(x, y)
			if below.solid_at(c) != S.NONE:
				continue
			for dy in range(-1, 2):
				for dx in range(-1, 2):
					var edge := c + Vector2i(dx, dy)
					if below.inside(edge) and below.solid_at(edge) == S.BLOCK:
						_paint(below, Rect2i(edge, Vector2i.ONE), S.WALL, F.GRAVEL, 0)
	for y in range(HEIGHT):
		for x in range(WIDTH):
			var c := Vector2i(x, y)
			if below.building_at(c) == 0:
				below.zone[below.index(c)] = "below"
	for a: Array in ug["stairs"]:
		data["stairs"].append({"cell": _c(a), "low": -1, "high": 0, "ladder": false})
	for room: Dictionary in ug["rooms"]:
		var r := _r(room["rect"])
		data["labels"].append({"text": room["name"], "cell": r.position + Vector2i(1, 1), "level": -1})
	for row: Dictionary in PLAN["stores"]:
		var c := _c(row["cell"])
		var lv: int = row["level"]
		var lg: FieldGrid = data["levels"][lv]
		data["containers"][row["id"]] = {"id": row["id"], "name": row["name"], "cell": c, "level": lv, "building": lg.building_at(c), "search": 7 if lv < 0 else 5, "items": row["items"].duplicate(), "locked": false, "searched": false}
	for row: Dictionary in PLAN["salvage"]:
		data["spots"][row["id"]] = {"kind": "salvage", "name": row["name"], "cell": _c(row["cell"]), "material": "scrap", "amount": row["amount"], "state": "intact"}
	data["spots"]["work_site"] = {"kind": "work_site", "cell": _c(PLAN["wagon_rows"][0]["work"]), "name": "석탄 작업 구역", "state": "closed", "zone_rect": lower}
	for name: String in PLAN["entries"]:
		var entry: Array[Vector2i] = []
		for a: Array in PLAN["entries"][name]:
			entry.append(_c(a))
		data["entries"][name] = entry
		data["entry_levels"][name] = -1 if name == "deep_tunnel" else 0
	var dead_levels: Array = []
	for a: Array in ug["dead"]:
		dead_levels.append([_c(a), -1])
	var all_doors: Array = data["train_doors"]["upper"] + data["train_doors"]["lower"]
	var first: Vector2i = all_doors[0]
	data["spawns"] = {"dead_access_road": data["entries"]["access_road"].duplicate(), "dead_open_edge": data["entries"]["open_edge"].duplicate(), "squad": [first, first + Vector2i(-1, -1), first + Vector2i(1, -1), first + Vector2i(0, -2)], "train_door": all_doors, "dead_levels": dead_levels}
	_train_lights(data)
	for lg: FieldGrid in [g, up, below]:
		lg.refresh_paths()
	return data

static func _train_lights(data: Dictionary) -> void:
	var train: Rect2i = data["train"]
	for k in range(5):
		var r := Rect2i(train.position.x + k * 16, train.position.y, 16, 3)
		data["train_cars"].append({"rect": r, "kind": "car" if k < 4 else "engine"})
		if k == 4:
			data["lights"].append({"id": "firebox", "kind": "firebox", "cell": Vector2i(r.position.x + 2, r.end.y - 1), "side": Vector2i(0, 1), "strength": 0.8, "falls": 0.8, "reach": 4.0, "when": "always", "from_min": 0})
			continue
		for side: int in [-1, 1]:
			var y := r.position.y if side < 0 else r.end.y - 1
			for w in range(4):
				data["lights"].append({"id": "car%d_%d_window%d" % [k + 1, side, w + 1], "kind": "car_window", "cell": Vector2i(r.position.x + 3 + w * 3, y), "side": Vector2i(0, side), "strength": 1.0, "falls": 0.6, "reach": 3.0, "when": "dusk", "from_min": 890})
