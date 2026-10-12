# 이 지도가 다른 판단을 만드는 것: 열차 바로 앞 갱구에서 짧게 회수할수록 같은 입구로 밀려오는 망자를 빨리 만나므로 귀환 시점을 먼저 정한다. 지하 순환로에서 한 번 더 돌지 되돌아설지 고른다.
extends RefCounted
## 지상·위층·아래 갱도. PLAN의 칸 좌표는 이 파일 안에서만 조립한다.
const FieldGrid = preload("res://game/world/field_grid.gd")
const S = FieldGrid.Solid
const F = FieldGrid.Floor
const WIDTH: int = 164
const HEIGHT: int = 98
const PLACE_ID: String = "mine_01"
const ZONE_NAMES: Dictionary = {"yard":"갱구 앞마당","stock":"저탄장","mine":"갱도","below":"아래 갱도","office":"적재 관리동"}
## 무전 문장에 쓰는 들어오는 길의 이름, 길마다의 비중, 첫 물결이 오는 길.
const ENTRY_NAMES: Dictionary = {"mine_mouth": "갱도 입구", "access_road": "진입로", "open_edge": "트인 벌판", "deep_tunnel": "깊은 갱도"}
const ENTRY_WEIGHTS: Dictionary = {"mine_mouth": 0.2, "access_road": 0.35, "open_edge": 0.3, "deep_tunnel": 0.15}
const FIRST_ENTRY: String = "access_road"
const PLAN: Dictionary = {
	"id": 1,
	"w": 164,
	"h": 98,
	"judgment": "열차 바로 앞 갱구에서 짧게 회수할수록 같은 입구로 밀려오는 망자를 빨리 만나므로 귀환 시점을 먼저 정한다. 지하 순환로에서 한 번 더 돌지 되돌아설지 고른다.",
	"train": [
		42,
		54,
		80,
		3
	],
	"bands": [
		[
			22,
			34,
			120,
			20
		],
		[
			22,
			57,
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
			164,
			28
		]
	],
	"cuts": [],
	"tunnels": [
		[
			77,
			7,
			3,
			21
		],
		[
			67,
			5,
			23,
			10
		]
	],
	"ground_rooms": [],
	"mouths": [
		{
			"cell": [
				78,
				27
			],
			"outward": [
				0,
				1
			]
		}
	],
	"down": [
		[
			78,
			8
		]
	],
	"houses": [
		{
			"id": 1,
			"name": "적재 관리동",
			"rect": [
				126,
				80,
				22,
				14
			],
			"zone": "office",
			"walls": [
				[
					137,
					81,
					1,
					12
				]
			],
			"doors": [
				[
					137,
					87
				],
				[
					129,
					93
				],
				[
					147,
					83
				]
			],
			"windows": [
				[
					129,
					80
				],
				[
					144,
					80
				],
				[
					126,
					84
				]
			],
			"rooms": [
				{
					"name": "작업실",
					"rect": [
						127,
						81,
						10,
						12
					]
				},
				{
					"name": "부품실",
					"rect": [
						138,
						81,
						9,
						12
					]
				}
			],
			"upper": [
				126,
				80,
				18,
				12
			],
			"upper_rooms": [
				{
					"name": "작업실",
					"rect": [
						127,
						81,
						8,
						10
					]
				},
				{
					"name": "부품실",
					"rect": [
						136,
						81,
						7,
						10
					]
				}
			],
			"stair": [
				128,
				82
			],
			"through": false,
			"upper_plan": {
				"id": 1,
				"name": "적재 관리동",
				"rect": [
					126,
					80,
					18,
					12
				],
				"zone": "office",
				"walls": [
					[
						135,
						81,
						1,
						10
					]
				],
				"doors": [
					[
						135,
						86
					],
					[
						129,
						91
					],
					[
						143,
						83
					]
				],
				"windows": [
					[
						129,
						80
					],
					[
						140,
						80
					],
					[
						126,
						84
					]
				],
				"rooms": [
					{
						"name": "작업실",
						"rect": [
							127,
							81,
							8,
							10
						]
					},
					{
						"name": "부품실",
						"rect": [
							136,
							81,
							7,
							10
						]
					}
				],
				"upper": [],
				"upper_rooms": [],
				"stair": [
					128,
					82
				],
				"through": false
			}
		}
	],
	"floors": [
		{
			"rect": [
				22,
				34,
				120,
				20
			],
			"kind": 7
		},
		{
			"rect": [
				22,
				57,
				120,
				22
			],
			"kind": 7
		},
		{
			"rect": [
				0,
				54,
				164,
				3
			],
			"kind": 4
		},
		{
			"rect": [
				0,
				46,
				164,
				3
			],
			"kind": 1
		},
		{
			"rect": [
				0,
				63,
				164,
				3
			],
			"kind": 1
		},
		{
			"rect": [
				35,
				31,
				4,
				53
			],
			"kind": 1
		},
		{
			"rect": [
				126,
				31,
				4,
				53
			],
			"kind": 1
		},
		{
			"rect": [
				77,
				27,
				3,
				21
			],
			"kind": 4
		},
		{
			"rect": [
				86,
				32,
				4,
				16
			],
			"kind": 1
		},
		{
			"rect": [
				36,
				32,
				94,
				1
			],
			"kind": 4
		},
		{
			"rect": [
				36,
				32,
				1,
				53
			],
			"kind": 4
		},
		{
			"rect": [
				129,
				32,
				1,
				53
			],
			"kind": 4
		},
		{
			"rect": [
				36,
				84,
				94,
				1
			],
			"kind": 4
		},
		{
			"rect": [
				31,
				84,
				36,
				1
			],
			"kind": 4
		},
		{
			"rect": [
				40,
				86,
				12,
				3
			],
			"kind": 7
		},
		{
			"rect": [
				57,
				84,
				36,
				1
			],
			"kind": 4
		},
		{
			"rect": [
				66,
				86,
				12,
				3
			],
			"kind": 7
		},
		{
			"rect": [
				126,
				94,
				22,
				3
			],
			"kind": 1
		},
		{
			"rect": [
				126,
				89,
				38,
				2
			],
			"kind": 1
		},
		{
			"rect": [
				65,
				29,
				4,
				1
			],
			"kind": 4
		},
		{
			"rect": [
				81,
				86,
				2,
				1
			],
			"kind": 4
		},
		{
			"rect": [
				78,
				33,
				1,
				4
			],
			"kind": 4
		},
		{
			"rect": [
				147,
				88,
				17,
				3
			],
			"kind": 1
		},
		{
			"rect": [
				147,
				78,
				3,
				12
			],
			"kind": 1
		},
		{
			"rect": [
				101,
				78,
				48,
				3
			],
			"kind": 1
		},
		{
			"rect": [
				101,
				56,
				3,
				24
			],
			"kind": 1
		}
	],
	"props": [
		{
			"kind": "coal_wagon",
			"rect": [
				41,
				83,
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
				67,
				83,
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
				46,
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
				47,
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
				39,
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
				38,
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
				63,
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
				62,
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
				71,
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
				73,
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
				31,
				31,
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
				40,
				31,
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
				31,
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
				31,
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
				31,
				80,
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
				40,
				80,
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
				80,
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
				80,
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
				68,
				25,
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
				84,
				25,
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
				24,
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
				128,
				3,
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
				77,
				26,
				3,
				2
			],
			"solid": "none",
			"facing": 2,
			"note": "갱구 틀"
		},
		{
			"kind": "support_frame",
			"rect": [
				77,
				22,
				3,
				1
			],
			"solid": "none",
			"facing": 0,
			"note": "버팀목 틀"
		},
		{
			"kind": "ore_cart",
			"rect": [
				66,
				29,
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
				62,
				32,
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
				75,
				33,
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
				29,
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
				71,
				30,
				2,
				2
			],
			"solid": "low",
			"facing": 0,
			"note": "넘어진 광차"
		},
		{
			"kind": "coal_heap",
			"rect": [
				26,
				82,
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
				22,
				85,
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
				19,
				80,
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
				35,
				86,
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
				77,
				83,
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
				80,
				79,
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
				65,
				80,
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
				81,
				86,
				2,
				1
			],
			"solid": "none",
			"facing": 0,
			"note": "선로 전환기"
		},
		{
			"kind": "tool_rack",
			"rect": [
				150,
				62,
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
				146,
				65,
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
				143,
				60,
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
				159,
				66,
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
				157,
				56,
				1,
				1
			],
			"solid": "low",
			"facing": 0,
			"note": "연료 드럼"
		},
		{
			"kind": "ore_truck",
			"rect": [
				110,
				84,
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
				106,
				87,
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
				113,
				89,
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
				119,
				88,
				1,
				1
			],
			"solid": "none",
			"facing": 0,
			"note": "거리 말뚝"
		},
		{
			"kind": "boulder",
			"rect": [
				5,
				50,
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
				1,
				53,
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
				8,
				55,
				3,
				1
			],
			"solid": "low",
			"facing": 0,
			"note": "침목 더미"
		},
		{
			"kind": "mine_track",
			"rect": [
				78,
				33,
				1,
				4
			],
			"solid": "none",
			"facing": 0,
			"note": "광차 선로"
		},
		{
			"kind": "buffer_stop",
			"rect": [
				55,
				84,
				1,
				2
			],
			"solid": "low",
			"facing": 0,
			"note": "선로 끝 완충기"
		},
		{
			"kind": "buffer_stop",
			"rect": [
				81,
				84,
				1,
				2
			],
			"solid": "low",
			"facing": 0,
			"note": "선로 끝 완충기"
		},
		{
			"kind": "spruce",
			"rect": [
				5,
				34,
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
				8,
				60,
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
				6,
				87,
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
				158,
				34,
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
			5,
			34
		],
		[
			7,
			35
		],
		[
			3,
			36
		],
		[
			9,
			33
		],
		[
			2,
			32
		],
		[
			6,
			38
		],
		[
			10,
			37
		],
		[
			1,
			39
		],
		[
			4,
			30
		],
		[
			8,
			40
		],
		[
			11,
			31
		],
		[
			0,
			34
		],
		[
			8,
			60
		],
		[
			4,
			61
		],
		[
			10,
			58
		],
		[
			3,
			57
		],
		[
			11,
			62
		],
		[
			1,
			59
		],
		[
			6,
			66
		],
		[
			13,
			60
		],
		[
			9,
			53
		],
		[
			4,
			67
		],
		[
			6,
			59
		],
		[
			6,
			87
		],
		[
			12,
			84
		],
		[
			5,
			83
		],
		[
			9,
			89
		],
		[
			13,
			88
		],
		[
			4,
			90
		],
		[
			7,
			81
		],
		[
			11,
			91
		],
		[
			14,
			82
		],
		[
			3,
			85
		],
		[
			8,
			92
		],
		[
			14,
			91
		],
		[
			158,
			34
		],
		[
			151,
			33
		],
		[
			155,
			39
		],
		[
			159,
			38
		],
		[
			150,
			40
		],
		[
			153,
			31
		],
		[
			157,
			41
		],
		[
			160,
			32
		],
		[
			149,
			35
		],
		[
			154,
			42
		],
		[
			160,
			41
		],
		[
			149,
			31
		],
		[
			153,
			52
		],
		[
			157,
			58
		],
		[
			161,
			57
		],
		[
			152,
			59
		],
		[
			155,
			50
		],
		[
			159,
			60
		],
		[
			162,
			51
		],
		[
			156,
			61
		],
		[
			162,
			60
		],
		[
			151,
			50
		],
		[
			149,
			57
		],
		[
			154,
			62
		],
		[
			155,
			78
		],
		[
			159,
			77
		],
		[
			150,
			79
		],
		[
			153,
			70
		],
		[
			157,
			80
		],
		[
			160,
			71
		],
		[
			149,
			74
		],
		[
			154,
			81
		],
		[
			160,
			80
		],
		[
			149,
			70
		],
		[
			161,
			75
		],
		[
			147,
			77
		],
		[
			56,
			93
		],
		[
			47,
			95
		],
		[
			50,
			86
		],
		[
			54,
			96
		],
		[
			57,
			87
		],
		[
			46,
			90
		],
		[
			51,
			97
		],
		[
			57,
			96
		],
		[
			58,
			91
		],
		[
			44,
			93
		],
		[
			59,
			95
		],
		[
			51,
			90
		],
		[
			90,
			97
		],
		[
			93,
			88
		],
		[
			100,
			89
		],
		[
			89,
			92
		],
		[
			89,
			88
		],
		[
			101,
			93
		],
		[
			87,
			95
		],
		[
			97,
			86
		],
		[
			102,
			97
		],
		[
			94,
			92
		],
		[
			96,
			93
		],
		[
			92,
			94
		]
	],
	"covers": [
		[
			62,
			46,
			2,
			2
		],
		[
			74,
			47,
			2,
			3
		],
		[
			30,
			39,
			3,
			1
		],
		[
			116,
			38,
			6,
			1
		],
		[
			62,
			63,
			2,
			2
		],
		[
			74,
			62,
			2,
			3
		],
		[
			30,
			71,
			3,
			1
		],
		[
			116,
			73,
			6,
			1
		],
		[
			40,
			31,
			4,
			3
		],
		[
			108,
			31,
			4,
			3
		],
		[
			40,
			80,
			4,
			3
		],
		[
			108,
			80,
			4,
			3
		],
		[
			66,
			29,
			2,
			1
		],
		[
			62,
			32,
			3,
			1
		],
		[
			75,
			33,
			2,
			1
		],
		[
			54,
			29,
			4,
			3
		],
		[
			71,
			30,
			2,
			2
		],
		[
			26,
			82,
			4,
			3
		],
		[
			22,
			85,
			3,
			3
		],
		[
			19,
			80,
			2,
			2
		],
		[
			65,
			80,
			6,
			1
		],
		[
			150,
			62,
			2,
			1
		],
		[
			146,
			65,
			3,
			2
		],
		[
			143,
			60,
			1,
			1
		],
		[
			159,
			66,
			1,
			1
		],
		[
			157,
			56,
			1,
			1
		],
		[
			106,
			87,
			3,
			2
		],
		[
			5,
			50,
			2,
			2
		],
		[
			8,
			55,
			3,
			1
		],
		[
			55,
			84,
			1,
			2
		],
		[
			81,
			84,
			1,
			2
		]
	],
	"gates": [
		[
			37,
			32,
			3,
			1
		],
		[
			105,
			32,
			3,
			1
		],
		[
			37,
			81,
			3,
			1
		],
		[
			105,
			81,
			3,
			1
		]
	],
	"wagons": [
		[
			41,
			83,
			10,
			3
		],
		[
			67,
			83,
			10,
			3
		]
	],
	"stores": [
		{
			"id": "house_1_0",
			"name": "적재 관리동 작업실 자재함",
			"cell": [
				128,
				82
			],
			"items": [
				"scrap",
				"wood"
			],
			"level": 0
		},
		{
			"id": "house_1_1",
			"name": "적재 관리동 부품실 자재함",
			"cell": [
				139,
				82
			],
			"items": [
				"scrap",
				"wood"
			],
			"level": 0
		},
		{
			"id": "upper_1_0",
			"name": "적재 관리동 위층 작업실 상자",
			"cell": [
				128,
				82
			],
			"items": [
				"wood",
				"scrap"
			],
			"level": 1
		},
		{
			"id": "upper_1_1",
			"name": "적재 관리동 위층 부품실 상자",
			"cell": [
				137,
				82
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
				43,
				87
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
				69,
				87
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
				78,
				21
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
				22,
				12
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
				43,
				3
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
				79,
				3
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
				90,
				11
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
				31,
				20
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
			"id": "scrap_0",
			"cell": [
				48,
				87
			],
			"name": "측선 고철",
			"amount": 3
		},
		{
			"id": "scrap_1",
			"cell": [
				74,
				87
			],
			"name": "측선 고철",
			"amount": 3
		}
	],
	"tree_centers": [
		[
			5,
			34
		],
		[
			6,
			59
		],
		[
			8,
			85
		],
		[
			154,
			35
		],
		[
			156,
			54
		],
		[
			154,
			74
		],
		[
			51,
			90
		],
		[
			94,
			92
		]
	],
	"clusters": [
		[
			66,
			29,
			"pit"
		],
		[
			26,
			82,
			"coal"
		],
		[
			72,
			82,
			"load"
		],
		[
			150,
			62,
			"repair"
		],
		[
			110,
			84,
			"road"
		],
		[
			5,
			50,
			"forest"
		]
	],
	"assumptions": [
		"1칸은 1m. 공구·부품은 scrap, 연료는 wood, 석탄은 화차 coal로 기록한다. 지하 입구와 계단 거리는 네 방향 최단 걸음으로 센다.",
		"위층은 해당 건물 범위만 만들고 나머지는 AIR, 지하는 파낸 칸과 바로 둘레만 그린다. 지하의 깊은 갱 자리는 벽 면의 예약 좌표이며 새 반환 열쇠를 만들지 않는다."
	],
	"group_members": [
		[
			26,
			27,
			28,
			29,
			30
		],
		[
			31,
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
			42,
			43
		],
		[
			44,
			45,
			46,
			47
		],
		[
			48,
			49,
			50
		]
	],
	"tree_groups": [
		[
			[
				5,
				34
			],
			[
				7,
				35
			],
			[
				3,
				36
			],
			[
				9,
				33
			],
			[
				2,
				32
			],
			[
				6,
				38
			],
			[
				10,
				37
			],
			[
				1,
				39
			],
			[
				4,
				30
			],
			[
				8,
				40
			],
			[
				11,
				31
			],
			[
				0,
				34
			]
		],
		[
			[
				8,
				60
			],
			[
				4,
				61
			],
			[
				10,
				58
			],
			[
				3,
				57
			],
			[
				11,
				62
			],
			[
				1,
				59
			],
			[
				6,
				66
			],
			[
				13,
				60
			],
			[
				9,
				53
			],
			[
				4,
				67
			],
			[
				6,
				59
			]
		],
		[
			[
				6,
				87
			],
			[
				12,
				84
			],
			[
				5,
				83
			],
			[
				9,
				89
			],
			[
				13,
				88
			],
			[
				4,
				90
			],
			[
				7,
				81
			],
			[
				11,
				91
			],
			[
				14,
				82
			],
			[
				3,
				85
			],
			[
				8,
				92
			],
			[
				14,
				91
			]
		],
		[
			[
				158,
				34
			],
			[
				151,
				33
			],
			[
				155,
				39
			],
			[
				159,
				38
			],
			[
				150,
				40
			],
			[
				153,
				31
			],
			[
				157,
				41
			],
			[
				160,
				32
			],
			[
				149,
				35
			],
			[
				154,
				42
			],
			[
				160,
				41
			],
			[
				149,
				31
			]
		],
		[
			[
				153,
				52
			],
			[
				157,
				58
			],
			[
				161,
				57
			],
			[
				152,
				59
			],
			[
				155,
				50
			],
			[
				159,
				60
			],
			[
				162,
				51
			],
			[
				156,
				61
			],
			[
				162,
				60
			],
			[
				151,
				50
			],
			[
				149,
				57
			],
			[
				154,
				62
			]
		],
		[
			[
				155,
				78
			],
			[
				159,
				77
			],
			[
				150,
				79
			],
			[
				153,
				70
			],
			[
				157,
				80
			],
			[
				160,
				71
			],
			[
				149,
				74
			],
			[
				154,
				81
			],
			[
				160,
				80
			],
			[
				149,
				70
			],
			[
				161,
				75
			],
			[
				147,
				77
			]
		],
		[
			[
				56,
				93
			],
			[
				47,
				95
			],
			[
				50,
				86
			],
			[
				54,
				96
			],
			[
				57,
				87
			],
			[
				46,
				90
			],
			[
				51,
				97
			],
			[
				57,
				96
			],
			[
				58,
				91
			],
			[
				44,
				93
			],
			[
				59,
				95
			],
			[
				51,
				90
			]
		],
		[
			[
				90,
				97
			],
			[
				93,
				88
			],
			[
				100,
				89
			],
			[
				89,
				92
			],
			[
				89,
				88
			],
			[
				101,
				93
			],
			[
				87,
				95
			],
			[
				97,
				86
			],
			[
				102,
				97
			],
			[
				94,
				92
			],
			[
				96,
				93
			],
			[
				92,
				94
			]
		]
	],
	"underground": {
		"digs": [
			[
				30,
				10,
				62,
				3
			],
			[
				30,
				19,
				62,
				3
			],
			[
				30,
				10,
				3,
				12
			],
			[
				89,
				10,
				3,
				12
			],
			[
				28,
				13,
				3,
				2
			],
			[
				44,
				6,
				2,
				5
			],
			[
				80,
				7,
				2,
				4
			],
			[
				21,
				11,
				7,
				6
			],
			[
				42,
				2,
				6,
				4
			],
			[
				78,
				2,
				6,
				5
			],
			[
				77,
				8,
				3,
				3
			]
		],
		"rooms": [
			{
				"name": "권양기 방",
				"rect": [
					21,
					11,
					7,
					6
				],
				"pocket": false
			},
			{
				"name": "공구 막장",
				"rect": [
					42,
					2,
					6,
					4
				],
				"pocket": true
			},
			{
				"name": "예비 부품 막장",
				"rect": [
					78,
					2,
					6,
					5
				],
				"pocket": true
			}
		],
		"pillars": [
			[
				26,
				12
			]
		],
		"stairs": [
			[
				78,
				8
			]
		],
		"entry": [
			43,
			21
		],
		"hoist": [
			21,
			11,
			7,
			6
		],
		"deep": [
			20,
			13
		],
		"stores": [
			{
				"id": "deep_0",
				"name": "권양기 방 자재함",
				"cell": [
					22,
					12
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
					43,
					3
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
					79,
					3
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
					90,
					11
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
					31,
					20
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
				21,
				11
			],
			[
				22,
				11
			],
			[
				42,
				2
			],
			[
				43,
				2
			],
			[
				78,
				2
			],
			[
				79,
				2
			]
		],
		"inner_room": [
			78,
			2,
			6,
			5
		]
	},
	"zones": {
		"yard": "갱구 앞마당",
		"stock": "저탄장",
		"mine": "갱도",
		"below": "아래 갱도",
		"office": "적재 관리동"
	},
	"cliffs": [],
	"face_tags": [
		[
			68,
			25,
			6,
			3
		],
		[
			84,
			25,
			6,
			3
		]
	],
	"ridge_tags": [
		[
			24,
			2,
			8,
			6
		],
		[
			128,
			3,
			8,
			6
		]
	],
	"doors": [
		[
			58,
			53
		],
		[
			58,
			57
		],
		[
			78,
			53
		],
		[
			78,
			57
		],
		[
			102,
			53
		],
		[
			102,
			57
		]
	],
	"entries": {
		"mine_mouth": [
			[
				77,
				24
			],
			[
				78,
				24
			],
			[
				79,
				24
			]
		],
		"access_road": [
			[
				163,
				89
			],
			[
				163,
				90
			]
		],
		"open_edge": [
			[
				0,
				64
			],
			[
				0,
				47
			]
		],
		"deep_tunnel": [
			[
				43,
				21
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
				41,
				83,
				10,
				3
			],
			"coal": 11,
			"work": [
				44,
				86
			]
		},
		{
			"id": "coal_1",
			"name": "석탄 화차",
			"rect": [
				67,
				83,
				10,
				3
			],
			"coal": 14,
			"work": [
				70,
				86
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
