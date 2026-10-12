# 이 지도가 다른 판단을 만드는 것: 60칸 떨어진 두 갱구가 같은 굴로 이어져 들어간 문으로 돌아올지 반대 갱구로 빠져 화차를 나눠 회수할지 정한다. 지하에서도 두 계단을 잇는 순환로로 귀환 방향을 바꾼다.
extends RefCounted
## 지상·위층·아래 갱도. PLAN의 칸 좌표는 이 파일 안에서만 조립한다.
const FieldGrid = preload("res://game/world/field_grid.gd")
const S = FieldGrid.Solid
const F = FieldGrid.Floor
const WIDTH: int = 168
const HEIGHT: int = 100
const PLACE_ID: String = "mine_04"
const ZONE_NAMES: Dictionary = {"yard":"갱구 앞마당","stock":"저탄장","mine":"연결 갱도","below":"아래 갱도","office":"적재 관리동"}
## 무전 문장에 쓰는 들어오는 길의 이름, 길마다의 비중, 첫 물결이 오는 길.
const ENTRY_NAMES: Dictionary = {"mine_mouth": "갱도 입구", "access_road": "진입로", "open_edge": "트인 벌판", "deep_tunnel": "깊은 갱도"}
const ENTRY_WEIGHTS: Dictionary = {"mine_mouth": 0.2, "access_road": 0.35, "open_edge": 0.3, "deep_tunnel": 0.15}
const FIRST_ENTRY: String = "access_road"
const PLAN: Dictionary = {
	"id": 4,
	"w": 168,
	"h": 100,
	"judgment": "60칸 떨어진 두 갱구가 같은 굴로 이어져 들어간 문으로 돌아올지 반대 갱구로 빠져 화차를 나눠 회수할지 정한다. 지하에서도 두 계단을 잇는 순환로로 귀환 방향을 바꾼다.",
	"train": [
		44,
		54,
		80,
		3
	],
	"bands": [
		[
			24,
			34,
			120,
			20
		],
		[
			24,
			57,
			120,
			22
		]
	],
	"door_x": [
		60,
		80,
		104
	],
	"mountains": [
		[
			0,
			0,
			168,
			28
		]
	],
	"cuts": [],
	"tunnels": [
		[
			49,
			7,
			3,
			21
		],
		[
			109,
			7,
			3,
			21
		],
		[
			42,
			7,
			78,
			4
		],
		[
			42,
			7,
			4,
			15
		],
		[
			116,
			7,
			4,
			15
		],
		[
			42,
			18,
			78,
			4
		]
	],
	"ground_rooms": [],
	"mouths": [
		{
			"cell": [
				50,
				27
			],
			"outward": [
				0,
				1
			]
		},
		{
			"cell": [
				110,
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
			50,
			8
		],
		[
			110,
			8
		]
	],
	"houses": [
		{
			"id": 1,
			"name": "적재 정비동",
			"rect": [
				136,
				82,
				24,
				14
			],
			"zone": "office",
			"walls": [
				[
					148,
					83,
					1,
					12
				]
			],
			"doors": [
				[
					148,
					89
				],
				[
					139,
					95
				],
				[
					159,
					85
				]
			],
			"windows": [
				[
					139,
					82
				],
				[
					156,
					82
				],
				[
					136,
					86
				]
			],
			"rooms": [
				{
					"name": "작업실",
					"rect": [
						137,
						83,
						11,
						12
					]
				},
				{
					"name": "부품실",
					"rect": [
						149,
						83,
						10,
						12
					]
				}
			],
			"upper": [
				136,
				82,
				18,
				12
			],
			"upper_rooms": [
				{
					"name": "작업실",
					"rect": [
						137,
						83,
						8,
						10
					]
				},
				{
					"name": "부품실",
					"rect": [
						146,
						83,
						7,
						10
					]
				}
			],
			"stair": [
				138,
				84
			],
			"through": false,
			"upper_plan": {
				"id": 1,
				"name": "적재 정비동",
				"rect": [
					136,
					82,
					18,
					12
				],
				"zone": "office",
				"walls": [
					[
						145,
						83,
						1,
						10
					]
				],
				"doors": [
					[
						145,
						88
					],
					[
						139,
						93
					],
					[
						153,
						85
					]
				],
				"windows": [
					[
						139,
						82
					],
					[
						150,
						82
					],
					[
						136,
						86
					]
				],
				"rooms": [
					{
						"name": "작업실",
						"rect": [
							137,
							83,
							8,
							10
						]
					},
					{
						"name": "부품실",
						"rect": [
							146,
							83,
							7,
							10
						]
					}
				],
				"upper": [],
				"upper_rooms": [],
				"stair": [
					138,
					84
				],
				"through": false
			}
		}
	],
	"floors": [
		{
			"rect": [
				24,
				34,
				120,
				20
			],
			"kind": 7
		},
		{
			"rect": [
				24,
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
				168,
				3
			],
			"kind": 4
		},
		{
			"rect": [
				0,
				46,
				168,
				3
			],
			"kind": 1
		},
		{
			"rect": [
				0,
				63,
				168,
				3
			],
			"kind": 1
		},
		{
			"rect": [
				37,
				31,
				4,
				53
			],
			"kind": 1
		},
		{
			"rect": [
				128,
				31,
				4,
				53
			],
			"kind": 1
		},
		{
			"rect": [
				49,
				27,
				3,
				21
			],
			"kind": 4
		},
		{
			"rect": [
				58,
				32,
				4,
				16
			],
			"kind": 1
		},
		{
			"rect": [
				109,
				27,
				3,
				21
			],
			"kind": 4
		},
		{
			"rect": [
				118,
				32,
				4,
				16
			],
			"kind": 1
		},
		{
			"rect": [
				31,
				31,
				20,
				1
			],
			"kind": 4
		},
		{
			"rect": [
				110,
				31,
				21,
				1
			],
			"kind": 4
		},
		{
			"rect": [
				31,
				31,
				1,
				63
			],
			"kind": 4
		},
		{
			"rect": [
				130,
				31,
				1,
				63
			],
			"kind": 4
		},
		{
			"rect": [
				31,
				84,
				100,
				1
			],
			"kind": 4
		},
		{
			"rect": [
				31,
				93,
				100,
				1
			],
			"kind": 4
		},
		{
			"rect": [
				33,
				84,
				36,
				1
			],
			"kind": 4
		},
		{
			"rect": [
				42,
				86,
				12,
				3
			],
			"kind": 7
		},
		{
			"rect": [
				62,
				84,
				36,
				1
			],
			"kind": 4
		},
		{
			"rect": [
				71,
				86,
				12,
				3
			],
			"kind": 7
		},
		{
			"rect": [
				44,
				93,
				36,
				1
			],
			"kind": 4
		},
		{
			"rect": [
				53,
				95,
				12,
				3
			],
			"kind": 7
		},
		{
			"rect": [
				89,
				93,
				36,
				1
			],
			"kind": 4
		},
		{
			"rect": [
				98,
				95,
				12,
				3
			],
			"kind": 7
		},
		{
			"rect": [
				136,
				96,
				24,
				3
			],
			"kind": 1
		},
		{
			"rect": [
				128,
				91,
				40,
				2
			],
			"kind": 1
		},
		{
			"rect": [
				37,
				29,
				4,
				1
			],
			"kind": 4
		},
		{
			"rect": [
				115,
				29,
				4,
				1
			],
			"kind": 4
		},
		{
			"rect": [
				93,
				90,
				2,
				1
			],
			"kind": 4
		},
		{
			"rect": [
				50,
				33,
				1,
				4
			],
			"kind": 4
		},
		{
			"rect": [
				110,
				33,
				1,
				4
			],
			"kind": 4
		},
		{
			"rect": [
				159,
				90,
				9,
				3
			],
			"kind": 1
		},
		{
			"rect": [
				159,
				80,
				3,
				12
			],
			"kind": 1
		},
		{
			"rect": [
				113,
				80,
				48,
				3
			],
			"kind": 1
		},
		{
			"rect": [
				113,
				78,
				3,
				4
			],
			"kind": 1
		},
		{
			"rect": [
				103,
				78,
				12,
				3
			],
			"kind": 1
		},
		{
			"rect": [
				103,
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
				43,
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
				72,
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
				54,
				92,
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
				99,
				92,
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
				64,
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
				76,
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
				32,
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
				118,
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
				64,
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
				76,
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
				32,
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
				118,
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
				33,
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
				42,
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
				94,
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
				103,
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
				33,
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
				42,
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
				101,
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
				110,
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
				42,
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
				54,
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
				102,
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
				114,
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
				21,
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
				132,
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
				49,
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
				49,
				22,
				3,
				1
			],
			"solid": "none",
			"facing": 0,
			"note": "버팀목 틀"
		},
		{
			"kind": "mine_portal",
			"rect": [
				109,
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
				109,
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
				38,
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
				47,
				33,
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
				26,
				29,
				2,
				1
			],
			"solid": "low",
			"facing": 0,
			"note": "연장 걸이"
		},
		{
			"kind": "ore_cart",
			"rect": [
				116,
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
				112,
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
				125,
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
				128,
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
				104,
				29,
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
				32,
				86,
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
				28,
				89,
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
				25,
				84,
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
				41,
				90,
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
				84,
				86,
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
				89,
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
				87,
				91,
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
				93,
				90,
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
				152,
				70,
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
				148,
				73,
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
				145,
				68,
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
				161,
				74,
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
				64,
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
				10,
				81,
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
				6,
				84,
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
				3,
				79,
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
				19,
				85,
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
				50,
				33,
				1,
				4
			],
			"solid": "none",
			"facing": 0,
			"note": "광차 선로"
		},
		{
			"kind": "mine_track",
			"rect": [
				110,
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
				57,
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
				86,
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
				68,
				93,
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
				113,
				93,
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
				36,
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
				9,
				61,
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
				7,
				96,
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
				164,
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
			36
		],
		[
			7,
			37
		],
		[
			3,
			38
		],
		[
			9,
			35
		],
		[
			2,
			34
		],
		[
			6,
			40
		],
		[
			10,
			39
		],
		[
			1,
			41
		],
		[
			4,
			32
		],
		[
			8,
			42
		],
		[
			11,
			33
		],
		[
			0,
			36
		],
		[
			9,
			61
		],
		[
			5,
			62
		],
		[
			11,
			59
		],
		[
			4,
			58
		],
		[
			10,
			66
		],
		[
			13,
			57
		],
		[
			2,
			60
		],
		[
			7,
			67
		],
		[
			13,
			66
		],
		[
			14,
			61
		],
		[
			5,
			68
		],
		[
			7,
			60
		],
		[
			7,
			96
		],
		[
			13,
			93
		],
		[
			6,
			92
		],
		[
			10,
			98
		],
		[
			14,
			97
		],
		[
			5,
			99
		],
		[
			8,
			90
		],
		[
			15,
			91
		],
		[
			4,
			94
		],
		[
			4,
			90
		],
		[
			16,
			95
		],
		[
			2,
			97
		],
		[
			164,
			34
		],
		[
			157,
			33
		],
		[
			161,
			39
		],
		[
			165,
			38
		],
		[
			156,
			40
		],
		[
			159,
			31
		],
		[
			163,
			41
		],
		[
			166,
			32
		],
		[
			155,
			35
		],
		[
			160,
			42
		],
		[
			166,
			41
		],
		[
			155,
			31
		],
		[
			160,
			58
		],
		[
			166,
			66
		],
		[
			158,
			60
		],
		[
			163,
			67
		],
		[
			161,
			68
		],
		[
			163,
			60
		],
		[
			165,
			61
		],
		[
			161,
			62
		],
		[
			167,
			59
		],
		[
			124,
			95
		],
		[
			128,
			94
		],
		[
			119,
			96
		],
		[
			122,
			87
		],
		[
			126,
			97
		],
		[
			129,
			88
		],
		[
			118,
			91
		],
		[
			123,
			98
		],
		[
			129,
			97
		],
		[
			118,
			87
		],
		[
			116,
			94
		],
		[
			126,
			85
		],
		[
			67,
			97
		],
		[
			58,
			99
		],
		[
			61,
			90
		],
		[
			68,
			91
		],
		[
			57,
			90
		],
		[
			69,
			95
		],
		[
			55,
			97
		],
		[
			65,
			88
		],
		[
			70,
			99
		],
		[
			64,
			95
		],
		[
			63,
			98
		],
		[
			16,
			36
		],
		[
			23,
			37
		],
		[
			26,
			28
		],
		[
			15,
			31
		],
		[
			20,
			38
		],
		[
			27,
			32
		],
		[
			13,
			34
		],
		[
			18,
			39
		],
		[
			20,
			31
		],
		[
			22,
			32
		],
		[
			18,
			33
		],
		[
			24,
			30
		]
	],
	"covers": [
		[
			64,
			46,
			2,
			2
		],
		[
			76,
			47,
			2,
			3
		],
		[
			32,
			39,
			3,
			1
		],
		[
			118,
			38,
			6,
			1
		],
		[
			64,
			63,
			2,
			2
		],
		[
			76,
			62,
			2,
			3
		],
		[
			32,
			71,
			3,
			1
		],
		[
			118,
			73,
			6,
			1
		],
		[
			42,
			31,
			4,
			3
		],
		[
			103,
			31,
			4,
			3
		],
		[
			42,
			80,
			4,
			3
		],
		[
			110,
			80,
			4,
			3
		],
		[
			38,
			29,
			2,
			1
		],
		[
			47,
			33,
			3,
			1
		],
		[
			26,
			29,
			2,
			1
		],
		[
			116,
			29,
			2,
			1
		],
		[
			112,
			32,
			3,
			1
		],
		[
			125,
			33,
			2,
			1
		],
		[
			128,
			29,
			4,
			3
		],
		[
			104,
			29,
			2,
			2
		],
		[
			32,
			86,
			4,
			3
		],
		[
			28,
			89,
			3,
			3
		],
		[
			25,
			84,
			2,
			2
		],
		[
			87,
			91,
			6,
			1
		],
		[
			152,
			70,
			2,
			1
		],
		[
			148,
			73,
			3,
			2
		],
		[
			145,
			68,
			1,
			1
		],
		[
			161,
			74,
			1,
			1
		],
		[
			159,
			64,
			1,
			1
		],
		[
			6,
			84,
			3,
			2
		],
		[
			57,
			84,
			1,
			2
		],
		[
			86,
			84,
			1,
			2
		],
		[
			68,
			93,
			1,
			2
		],
		[
			113,
			93,
			1,
			2
		]
	],
	"gates": [
		[
			39,
			32,
			3,
			1
		],
		[
			100,
			32,
			3,
			1
		],
		[
			39,
			81,
			3,
			1
		],
		[
			107,
			81,
			3,
			1
		]
	],
	"wagons": [
		[
			43,
			83,
			10,
			3
		],
		[
			72,
			83,
			10,
			3
		],
		[
			54,
			92,
			10,
			3
		],
		[
			99,
			92,
			10,
			3
		]
	],
	"stores": [
		{
			"id": "house_1_0",
			"name": "적재 정비동 작업실 자재함",
			"cell": [
				138,
				84
			],
			"items": [
				"scrap",
				"wood"
			],
			"level": 0
		},
		{
			"id": "house_1_1",
			"name": "적재 정비동 부품실 자재함",
			"cell": [
				150,
				84
			],
			"items": [
				"scrap",
				"wood"
			],
			"level": 0
		},
		{
			"id": "upper_1_0",
			"name": "적재 정비동 위층 작업실 상자",
			"cell": [
				138,
				84
			],
			"items": [
				"wood",
				"scrap"
			],
			"level": 1
		},
		{
			"id": "upper_1_1",
			"name": "적재 정비동 위층 부품실 상자",
			"cell": [
				147,
				84
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
				45,
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
				74,
				87
			],
			"items": [
				"scrap",
				"wood"
			],
			"level": 0
		},
		{
			"id": "surface_2",
			"name": "저탄장 자재함",
			"cell": [
				56,
				96
			],
			"items": [
				"scrap",
				"wood"
			],
			"level": 0
		},
		{
			"id": "surface_3",
			"name": "저탄장 자재함",
			"cell": [
				101,
				96
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
				50,
				21
			],
			"items": [
				"scrap",
				"wood"
			],
			"level": 0
		},
		{
			"id": "forehall_1",
			"name": "갱구 앞방 수리함",
			"cell": [
				110,
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
				38,
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
				77,
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
				91,
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
				114,
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
				47,
				18
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
				50,
				87
			],
			"name": "측선 고철",
			"amount": 3
		},
		{
			"id": "scrap_1",
			"cell": [
				79,
				87
			],
			"name": "측선 고철",
			"amount": 3
		},
		{
			"id": "scrap_2",
			"cell": [
				61,
				96
			],
			"name": "측선 고철",
			"amount": 3
		},
		{
			"id": "scrap_3",
			"cell": [
				106,
				96
			],
			"name": "측선 고철",
			"amount": 3
		}
	],
	"tree_centers": [
		[
			5,
			36
		],
		[
			7,
			60
		],
		[
			9,
			94
		],
		[
			160,
			35
		],
		[
			163,
			60
		],
		[
			123,
			91
		],
		[
			62,
			94
		],
		[
			20,
			31
		]
	],
	"clusters": [
		[
			38,
			29,
			"pit"
		],
		[
			116,
			29,
			"pit"
		],
		[
			32,
			86,
			"coal"
		],
		[
			84,
			86,
			"load"
		],
		[
			152,
			70,
			"repair"
		],
		[
			10,
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
			32,
			33,
			34
		],
		[
			35,
			36,
			37,
			38,
			39
		],
		[
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
			50,
			51,
			52
		],
		[
			53,
			54,
			55,
			56
		]
	],
	"tree_groups": [
		[
			[
				5,
				36
			],
			[
				7,
				37
			],
			[
				3,
				38
			],
			[
				9,
				35
			],
			[
				2,
				34
			],
			[
				6,
				40
			],
			[
				10,
				39
			],
			[
				1,
				41
			],
			[
				4,
				32
			],
			[
				8,
				42
			],
			[
				11,
				33
			],
			[
				0,
				36
			]
		],
		[
			[
				9,
				61
			],
			[
				5,
				62
			],
			[
				11,
				59
			],
			[
				4,
				58
			],
			[
				10,
				66
			],
			[
				13,
				57
			],
			[
				2,
				60
			],
			[
				7,
				67
			],
			[
				13,
				66
			],
			[
				14,
				61
			],
			[
				5,
				68
			],
			[
				7,
				60
			]
		],
		[
			[
				7,
				96
			],
			[
				13,
				93
			],
			[
				6,
				92
			],
			[
				10,
				98
			],
			[
				14,
				97
			],
			[
				5,
				99
			],
			[
				8,
				90
			],
			[
				15,
				91
			],
			[
				4,
				94
			],
			[
				4,
				90
			],
			[
				16,
				95
			],
			[
				2,
				97
			]
		],
		[
			[
				164,
				34
			],
			[
				157,
				33
			],
			[
				161,
				39
			],
			[
				165,
				38
			],
			[
				156,
				40
			],
			[
				159,
				31
			],
			[
				163,
				41
			],
			[
				166,
				32
			],
			[
				155,
				35
			],
			[
				160,
				42
			],
			[
				166,
				41
			],
			[
				155,
				31
			]
		],
		[
			[
				160,
				58
			],
			[
				166,
				66
			],
			[
				158,
				60
			],
			[
				163,
				67
			],
			[
				161,
				68
			],
			[
				163,
				60
			],
			[
				165,
				61
			],
			[
				161,
				62
			],
			[
				167,
				59
			]
		],
		[
			[
				124,
				95
			],
			[
				128,
				94
			],
			[
				119,
				96
			],
			[
				122,
				87
			],
			[
				126,
				97
			],
			[
				129,
				88
			],
			[
				118,
				91
			],
			[
				123,
				98
			],
			[
				129,
				97
			],
			[
				118,
				87
			],
			[
				116,
				94
			],
			[
				126,
				85
			]
		],
		[
			[
				67,
				97
			],
			[
				58,
				99
			],
			[
				61,
				90
			],
			[
				68,
				91
			],
			[
				57,
				90
			],
			[
				69,
				95
			],
			[
				55,
				97
			],
			[
				65,
				88
			],
			[
				70,
				99
			],
			[
				64,
				95
			],
			[
				63,
				98
			]
		],
		[
			[
				16,
				36
			],
			[
				23,
				37
			],
			[
				26,
				28
			],
			[
				15,
				31
			],
			[
				20,
				38
			],
			[
				27,
				32
			],
			[
				13,
				34
			],
			[
				18,
				39
			],
			[
				20,
				31
			],
			[
				22,
				32
			],
			[
				18,
				33
			],
			[
				24,
				30
			]
		]
	],
	"underground": {
		"digs": [
			[
				46,
				10,
				70,
				3
			],
			[
				46,
				17,
				70,
				3
			],
			[
				46,
				10,
				3,
				10
			],
			[
				113,
				10,
				3,
				10
			],
			[
				44,
				13,
				3,
				2
			],
			[
				78,
				6,
				2,
				5
			],
			[
				92,
				7,
				2,
				4
			],
			[
				37,
				11,
				7,
				6
			],
			[
				76,
				2,
				6,
				4
			],
			[
				90,
				2,
				6,
				5
			],
			[
				49,
				8,
				3,
				3
			],
			[
				109,
				8,
				3,
				3
			]
		],
		"rooms": [
			{
				"name": "권양기 방",
				"rect": [
					37,
					11,
					7,
					6
				],
				"pocket": false
			},
			{
				"name": "공구 막장",
				"rect": [
					76,
					2,
					6,
					4
				],
				"pocket": true
			},
			{
				"name": "예비 부품 막장",
				"rect": [
					90,
					2,
					6,
					5
				],
				"pocket": true
			}
		],
		"pillars": [
			[
				42,
				12
			]
		],
		"stairs": [
			[
				50,
				8
			],
			[
				110,
				8
			]
		],
		"entry": [
			81,
			19
		],
		"hoist": [
			37,
			11,
			7,
			6
		],
		"deep": [
			36,
			13
		],
		"stores": [
			{
				"id": "deep_0",
				"name": "권양기 방 자재함",
				"cell": [
					38,
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
					77,
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
					91,
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
					114,
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
					47,
					18
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
				37,
				11
			],
			[
				38,
				11
			],
			[
				76,
				2
			],
			[
				77,
				2
			],
			[
				90,
				2
			],
			[
				91,
				2
			]
		],
		"inner_room": [
			90,
			2,
			6,
			5
		]
	},
	"zones": {
		"yard": "갱구 앞마당",
		"stock": "저탄장",
		"mine": "연결 갱도",
		"below": "아래 갱도",
		"office": "적재 관리동"
	},
	"cliffs": [],
	"face_tags": [
		[
			42,
			25,
			6,
			3
		],
		[
			54,
			25,
			6,
			3
		],
		[
			102,
			25,
			6,
			3
		],
		[
			114,
			25,
			6,
			3
		]
	],
	"ridge_tags": [
		[
			21,
			2,
			8,
			6
		],
		[
			132,
			3,
			8,
			6
		]
	],
	"doors": [
		[
			60,
			53
		],
		[
			60,
			57
		],
		[
			80,
			53
		],
		[
			80,
			57
		],
		[
			104,
			53
		],
		[
			104,
			57
		]
	],
	"entries": {
		"mine_mouth": [
			[
				49,
				24
			],
			[
				50,
				24
			],
			[
				51,
				24
			],
			[
				109,
				24
			],
			[
				110,
				24
			],
			[
				111,
				24
			]
		],
		"access_road": [
			[
				167,
				91
			],
			[
				167,
				92
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
				81,
				19
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
				43,
				83,
				10,
				3
			],
			"coal": 14,
			"work": [
				46,
				86
			]
		},
		{
			"id": "coal_1",
			"name": "석탄 화차",
			"rect": [
				72,
				83,
				10,
				3
			],
			"coal": 17,
			"work": [
				75,
				86
			]
		},
		{
			"id": "coal_2",
			"name": "석탄 화차",
			"rect": [
				54,
				92,
				10,
				3
			],
			"coal": 20,
			"work": [
				57,
				95
			]
		},
		{
			"id": "coal_3",
			"name": "석탄 화차",
			"rect": [
				99,
				92,
				10,
				3
			],
			"coal": 23,
			"work": [
				102,
				95
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
