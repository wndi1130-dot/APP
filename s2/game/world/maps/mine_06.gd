# 이 지도가 다른 판단을 만드는 것: 작은 바깥 적재장에서 바로 떠날지 여러 순환 통로와 막장을 더 돌아 공구·부품·연료를 늘릴지 남은 시간을 재며 정한다. 가장 큰 지하 순환로에서 두 계단 사이 회수 범위를 정한다.
extends RefCounted
## 지상·위층·아래 갱도. PLAN의 칸 좌표는 이 파일 안에서만 조립한다.
const FieldGrid = preload("res://game/world/field_grid.gd")
const S = FieldGrid.Solid
const F = FieldGrid.Floor
const WIDTH: int = 176
const HEIGHT: int = 106
const PLACE_ID: String = "mine_06"
const ZONE_NAMES: Dictionary = {"yard":"갱구 앞마당","stock":"작은 적재장","mine":"갱도","below":"아래 갱도","office":"적재 관리동"}
## 무전 문장에 쓰는 들어오는 길의 이름, 길마다의 비중, 첫 물결이 오는 길.
const ENTRY_NAMES: Dictionary = {"mine_mouth": "갱도 입구", "access_road": "진입로", "open_edge": "트인 벌판", "deep_tunnel": "깊은 갱도"}
const ENTRY_WEIGHTS: Dictionary = {"mine_mouth": 0.2, "access_road": 0.35, "open_edge": 0.3, "deep_tunnel": 0.15}
const FIRST_ENTRY: String = "access_road"
const PLAN: Dictionary = {
	"id": 6,
	"w": 176,
	"h": 106,
	"judgment": "작은 바깥 적재장에서 바로 떠날지 여러 순환 통로와 막장을 더 돌아 공구·부품·연료를 늘릴지 남은 시간을 재며 정한다. 가장 큰 지하 순환로에서 두 계단 사이 회수 범위를 정한다.",
	"train": [
		48,
		71,
		80,
		3
	],
	"bands": [
		[
			28,
			51,
			120,
			20
		],
		[
			28,
			74,
			120,
			22
		]
	],
	"door_x": [
		64,
		84,
		108
	],
	"mountains": [
		[
			0,
			0,
			176,
			47
		]
	],
	"cuts": [],
	"tunnels": [
		[
			83,
			7,
			3,
			40
		],
		[
			27,
			7,
			115,
			4
		],
		[
			27,
			7,
			4,
			31
		],
		[
			138,
			7,
			4,
			31
		],
		[
			27,
			34,
			115,
			4
		],
		[
			54,
			7,
			4,
			31
		],
		[
			103,
			7,
			4,
			31
		],
		[
			36,
			8,
			10,
			8
		],
		[
			115,
			21,
			12,
			9
		],
		[
			115,
			24,
			27,
			3
		]
	],
	"ground_rooms": [],
	"mouths": [
		{
			"cell": [
				84,
				46
			],
			"outward": [
				0,
				1
			]
		}
	],
	"down": [
		[
			42,
			8
		],
		[
			102,
			8
		]
	],
	"houses": [
		{
			"id": 1,
			"name": "갱구 관리동",
			"rect": [
				3,
				72,
				21,
				14
			],
			"zone": "office",
			"walls": [
				[
					13,
					73,
					1,
					12
				]
			],
			"doors": [
				[
					13,
					79
				],
				[
					6,
					85
				],
				[
					23,
					75
				]
			],
			"windows": [
				[
					6,
					72
				],
				[
					20,
					72
				],
				[
					3,
					76
				]
			],
			"rooms": [
				{
					"name": "작업실",
					"rect": [
						4,
						73,
						9,
						12
					]
				},
				{
					"name": "부품실",
					"rect": [
						14,
						73,
						9,
						12
					]
				}
			],
			"upper": [
				3,
				72,
				18,
				12
			],
			"upper_rooms": [
				{
					"name": "작업실",
					"rect": [
						4,
						73,
						8,
						10
					]
				},
				{
					"name": "부품실",
					"rect": [
						13,
						73,
						7,
						10
					]
				}
			],
			"stair": [
				5,
				74
			],
			"through": false,
			"upper_plan": {
				"id": 1,
				"name": "갱구 관리동",
				"rect": [
					3,
					72,
					18,
					12
				],
				"zone": "office",
				"walls": [
					[
						12,
						73,
						1,
						10
					]
				],
				"doors": [
					[
						12,
						78
					],
					[
						6,
						83
					],
					[
						20,
						75
					]
				],
				"windows": [
					[
						6,
						72
					],
					[
						17,
						72
					],
					[
						3,
						76
					]
				],
				"rooms": [
					{
						"name": "작업실",
						"rect": [
							4,
							73,
							8,
							10
						]
					},
					{
						"name": "부품실",
						"rect": [
							13,
							73,
							7,
							10
						]
					}
				],
				"upper": [],
				"upper_rooms": [],
				"stair": [
					5,
					74
				],
				"through": false
			}
		}
	],
	"floors": [
		{
			"rect": [
				28,
				51,
				120,
				20
			],
			"kind": 7
		},
		{
			"rect": [
				28,
				74,
				120,
				22
			],
			"kind": 7
		},
		{
			"rect": [
				0,
				71,
				176,
				3
			],
			"kind": 4
		},
		{
			"rect": [
				0,
				63,
				176,
				3
			],
			"kind": 1
		},
		{
			"rect": [
				0,
				80,
				176,
				3
			],
			"kind": 1
		},
		{
			"rect": [
				41,
				48,
				4,
				53
			],
			"kind": 1
		},
		{
			"rect": [
				132,
				48,
				4,
				53
			],
			"kind": 1
		},
		{
			"rect": [
				83,
				46,
				3,
				19
			],
			"kind": 4
		},
		{
			"rect": [
				92,
				51,
				4,
				14
			],
			"kind": 1
		},
		{
			"rect": [
				34,
				99,
				36,
				1
			],
			"kind": 4
		},
		{
			"rect": [
				43,
				101,
				12,
				3
			],
			"kind": 7
		},
		{
			"rect": [
				69,
				99,
				36,
				1
			],
			"kind": 4
		},
		{
			"rect": [
				78,
				101,
				12,
				3
			],
			"kind": 7
		},
		{
			"rect": [
				3,
				86,
				21,
				3
			],
			"kind": 1
		},
		{
			"rect": [
				132,
				97,
				44,
				2
			],
			"kind": 1
		},
		{
			"rect": [
				69,
				47,
				4,
				1
			],
			"kind": 4
		},
		{
			"rect": [
				39,
				103,
				2,
				1
			],
			"kind": 4
		},
		{
			"rect": [
				84,
				52,
				1,
				4
			],
			"kind": 4
		},
		{
			"rect": [
				0,
				80,
				5,
				3
			],
			"kind": 1
		},
		{
			"rect": [
				1,
				70,
				3,
				12
			],
			"kind": 1
		},
		{
			"rect": [
				2,
				70,
				47,
				3
			],
			"kind": 1
		},
		{
			"rect": [
				46,
				69,
				20,
				3
			],
			"kind": 1
		},
		{
			"rect": [
				22,
				74,
				44,
				3
			],
			"kind": 1
		},
		{
			"rect": [
				63,
				73,
				3,
				3
			],
			"kind": 1
		}
	],
	"props": [
		{
			"kind": "coal_wagon",
			"rect": [
				44,
				98,
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
				79,
				98,
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
				68,
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
				80,
				64,
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
				36,
				56,
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
				122,
				55,
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
				68,
				80,
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
				80,
				79,
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
				36,
				88,
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
				122,
				90,
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
				37,
				48,
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
				46,
				48,
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
				105,
				48,
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
				114,
				48,
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
				30,
				97,
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
				39,
				97,
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
				105,
				97,
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
				114,
				97,
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
				74,
				44,
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
				90,
				44,
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
				17,
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
				151,
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
				83,
				45,
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
				83,
				41,
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
				70,
				47,
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
				66,
				50,
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
				58,
				47,
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
				75,
				48,
				4,
				3
			],
			"solid": "low",
			"facing": 0,
			"note": "낙반 더미"
		},
		{
			"kind": "coal_heap",
			"rect": [
				122,
				99,
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
				113,
				101,
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
				120,
				103,
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
				126,
				102,
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
				103,
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
				57,
				102,
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
				41,
				96,
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
				39,
				103,
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
				6,
				89,
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
				2,
				92,
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
				9,
				94,
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
				15,
				93,
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
				6,
				97,
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
				150,
				93,
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
				146,
				96,
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
				153,
				98,
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
				159,
				97,
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
				157,
				49,
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
				153,
				52,
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
				150,
				47,
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
				84,
				52,
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
				58,
				99,
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
				93,
				99,
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
				7,
				52,
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
				67,
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
				101,
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
				170,
				53,
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
			7,
			52
		],
		[
			9,
			53
		],
		[
			5,
			54
		],
		[
			11,
			51
		],
		[
			4,
			50
		],
		[
			8,
			56
		],
		[
			12,
			55
		],
		[
			3,
			57
		],
		[
			6,
			48
		],
		[
			10,
			58
		],
		[
			13,
			49
		],
		[
			2,
			52
		],
		[
			11,
			67
		],
		[
			7,
			68
		],
		[
			10,
			70
		],
		[
			14,
			69
		],
		[
			8,
			62
		],
		[
			4,
			66
		],
		[
			4,
			62
		],
		[
			16,
			67
		],
		[
			2,
			69
		],
		[
			12,
			60
		],
		[
			9,
			66
		],
		[
			7,
			101
		],
		[
			13,
			98
		],
		[
			10,
			103
		],
		[
			14,
			102
		],
		[
			5,
			104
		],
		[
			8,
			95
		],
		[
			12,
			105
		],
		[
			15,
			96
		],
		[
			4,
			99
		],
		[
			15,
			105
		],
		[
			4,
			95
		],
		[
			16,
			100
		],
		[
			170,
			53
		],
		[
			163,
			52
		],
		[
			167,
			58
		],
		[
			171,
			57
		],
		[
			162,
			59
		],
		[
			165,
			50
		],
		[
			169,
			60
		],
		[
			172,
			51
		],
		[
			161,
			54
		],
		[
			166,
			61
		],
		[
			172,
			60
		],
		[
			161,
			50
		],
		[
			170,
			78
		],
		[
			174,
			77
		],
		[
			165,
			79
		],
		[
			168,
			70
		],
		[
			164,
			74
		],
		[
			164,
			70
		],
		[
			162,
			77
		],
		[
			172,
			68
		],
		[
			169,
			74
		],
		[
			171,
			75
		],
		[
			167,
			76
		],
		[
			168,
			101
		],
		[
			172,
			100
		],
		[
			163,
			102
		],
		[
			166,
			93
		],
		[
			170,
			103
		],
		[
			173,
			94
		],
		[
			167,
			104
		],
		[
			173,
			103
		],
		[
			162,
			93
		],
		[
			160,
			100
		],
		[
			170,
			91
		],
		[
			165,
			105
		],
		[
			35,
			96
		],
		[
			26,
			98
		],
		[
			25,
			93
		],
		[
			30,
			100
		],
		[
			25,
			89
		],
		[
			23,
			96
		],
		[
			28,
			101
		],
		[
			27,
			91
		],
		[
			94,
			103
		],
		[
			80,
			105
		],
		[
			90,
			96
		],
		[
			89,
			103
		],
		[
			85,
			104
		],
		[
			91,
			101
		],
		[
			92,
			105
		]
	],
	"covers": [
		[
			68,
			63,
			2,
			2
		],
		[
			80,
			64,
			2,
			3
		],
		[
			36,
			56,
			3,
			1
		],
		[
			122,
			55,
			6,
			1
		],
		[
			68,
			80,
			2,
			2
		],
		[
			80,
			79,
			2,
			3
		],
		[
			36,
			88,
			3,
			1
		],
		[
			122,
			90,
			6,
			1
		],
		[
			46,
			48,
			4,
			3
		],
		[
			114,
			48,
			4,
			3
		],
		[
			39,
			97,
			4,
			3
		],
		[
			114,
			97,
			4,
			3
		],
		[
			70,
			47,
			2,
			1
		],
		[
			66,
			50,
			3,
			1
		],
		[
			58,
			47,
			2,
			1
		],
		[
			75,
			48,
			4,
			3
		],
		[
			122,
			99,
			4,
			3
		],
		[
			113,
			101,
			3,
			3
		],
		[
			120,
			103,
			2,
			2
		],
		[
			41,
			96,
			6,
			1
		],
		[
			6,
			89,
			2,
			1
		],
		[
			2,
			92,
			3,
			2
		],
		[
			9,
			94,
			1,
			1
		],
		[
			15,
			93,
			1,
			1
		],
		[
			6,
			97,
			1,
			1
		],
		[
			146,
			96,
			3,
			2
		],
		[
			157,
			49,
			2,
			2
		],
		[
			150,
			47,
			3,
			1
		],
		[
			58,
			99,
			1,
			2
		],
		[
			93,
			99,
			1,
			2
		]
	],
	"gates": [
		[
			43,
			49,
			3,
			1
		],
		[
			111,
			49,
			3,
			1
		],
		[
			36,
			98,
			3,
			1
		],
		[
			111,
			98,
			3,
			1
		]
	],
	"wagons": [
		[
			44,
			98,
			10,
			3
		],
		[
			79,
			98,
			10,
			3
		]
	],
	"stores": [
		{
			"id": "house_1_0",
			"name": "갱구 관리동 작업실 자재함",
			"cell": [
				5,
				74
			],
			"items": [
				"scrap",
				"wood"
			],
			"level": 0
		},
		{
			"id": "house_1_1",
			"name": "갱구 관리동 부품실 자재함",
			"cell": [
				15,
				74
			],
			"items": [
				"scrap",
				"wood"
			],
			"level": 0
		},
		{
			"id": "upper_1_0",
			"name": "갱구 관리동 위층 작업실 상자",
			"cell": [
				5,
				74
			],
			"items": [
				"wood",
				"scrap"
			],
			"level": 1
		},
		{
			"id": "upper_1_1",
			"name": "갱구 관리동 위층 부품실 상자",
			"cell": [
				14,
				74
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
				46,
				102
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
				81,
				102
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
				84,
				40
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
				30,
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
				65,
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
			"id": "deep_reserve",
			"name": "갱도 예비 공구함",
			"cell": [
				108,
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
				39,
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
				51,
				102
			],
			"name": "측선 고철",
			"amount": 3
		},
		{
			"id": "scrap_1",
			"cell": [
				86,
				102
			],
			"name": "측선 고철",
			"amount": 3
		}
	],
	"tree_centers": [
		[
			7,
			52
		],
		[
			9,
			66
		],
		[
			9,
			99
		],
		[
			166,
			54
		],
		[
			169,
			74
		],
		[
			167,
			97
		],
		[
			30,
			93
		],
		[
			87,
			102
		]
	],
	"clusters": [
		[
			70,
			47,
			"pit"
		],
		[
			117,
			98,
			"coal"
		],
		[
			48,
			98,
			"load"
		],
		[
			6,
			89,
			"repair"
		],
		[
			150,
			93,
			"road"
		],
		[
			157,
			49,
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
			29
		],
		[
			30,
			31,
			32,
			33
		],
		[
			34,
			35,
			36,
			37
		],
		[
			38,
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
		],
		[
			47,
			48,
			49
		]
	],
	"tree_groups": [
		[
			[
				7,
				52
			],
			[
				9,
				53
			],
			[
				5,
				54
			],
			[
				11,
				51
			],
			[
				4,
				50
			],
			[
				8,
				56
			],
			[
				12,
				55
			],
			[
				3,
				57
			],
			[
				6,
				48
			],
			[
				10,
				58
			],
			[
				13,
				49
			],
			[
				2,
				52
			]
		],
		[
			[
				11,
				67
			],
			[
				7,
				68
			],
			[
				10,
				70
			],
			[
				14,
				69
			],
			[
				8,
				62
			],
			[
				4,
				66
			],
			[
				4,
				62
			],
			[
				16,
				67
			],
			[
				2,
				69
			],
			[
				12,
				60
			],
			[
				9,
				66
			]
		],
		[
			[
				7,
				101
			],
			[
				13,
				98
			],
			[
				10,
				103
			],
			[
				14,
				102
			],
			[
				5,
				104
			],
			[
				8,
				95
			],
			[
				12,
				105
			],
			[
				15,
				96
			],
			[
				4,
				99
			],
			[
				15,
				105
			],
			[
				4,
				95
			],
			[
				16,
				100
			]
		],
		[
			[
				170,
				53
			],
			[
				163,
				52
			],
			[
				167,
				58
			],
			[
				171,
				57
			],
			[
				162,
				59
			],
			[
				165,
				50
			],
			[
				169,
				60
			],
			[
				172,
				51
			],
			[
				161,
				54
			],
			[
				166,
				61
			],
			[
				172,
				60
			],
			[
				161,
				50
			]
		],
		[
			[
				170,
				78
			],
			[
				174,
				77
			],
			[
				165,
				79
			],
			[
				168,
				70
			],
			[
				164,
				74
			],
			[
				164,
				70
			],
			[
				162,
				77
			],
			[
				172,
				68
			],
			[
				169,
				74
			],
			[
				171,
				75
			],
			[
				167,
				76
			]
		],
		[
			[
				168,
				101
			],
			[
				172,
				100
			],
			[
				163,
				102
			],
			[
				166,
				93
			],
			[
				170,
				103
			],
			[
				173,
				94
			],
			[
				167,
				104
			],
			[
				173,
				103
			],
			[
				162,
				93
			],
			[
				160,
				100
			],
			[
				170,
				91
			],
			[
				165,
				105
			]
		],
		[
			[
				35,
				96
			],
			[
				26,
				98
			],
			[
				25,
				93
			],
			[
				30,
				100
			],
			[
				25,
				89
			],
			[
				23,
				96
			],
			[
				28,
				101
			],
			[
				27,
				91
			]
		],
		[
			[
				94,
				103
			],
			[
				80,
				105
			],
			[
				90,
				96
			],
			[
				89,
				103
			],
			[
				85,
				104
			],
			[
				91,
				101
			],
			[
				92,
				105
			]
		]
	],
	"underground": {
		"digs": [
			[
				38,
				10,
				72,
				3
			],
			[
				38,
				19,
				72,
				3
			],
			[
				38,
				10,
				3,
				12
			],
			[
				107,
				10,
				3,
				12
			],
			[
				36,
				13,
				3,
				2
			],
			[
				66,
				6,
				2,
				5
			],
			[
				78,
				7,
				2,
				4
			],
			[
				29,
				11,
				7,
				6
			],
			[
				64,
				2,
				6,
				4
			],
			[
				76,
				2,
				7,
				5
			],
			[
				41,
				8,
				3,
				3
			],
			[
				101,
				8,
				3,
				3
			]
		],
		"rooms": [
			{
				"name": "권양기 방",
				"rect": [
					29,
					11,
					7,
					6
				],
				"pocket": false
			},
			{
				"name": "공구 막장",
				"rect": [
					64,
					2,
					6,
					4
				],
				"pocket": true
			},
			{
				"name": "예비 부품 막장",
				"rect": [
					76,
					2,
					7,
					5
				],
				"pocket": true
			}
		],
		"pillars": [
			[
				34,
				12
			],
			[
				79,
				4
			]
		],
		"stairs": [
			[
				42,
				8
			],
			[
				102,
				8
			]
		],
		"entry": [
			75,
			21
		],
		"hoist": [
			29,
			11,
			7,
			6
		],
		"deep": [
			28,
			13
		],
		"stores": [
			{
				"id": "deep_0",
				"name": "권양기 방 자재함",
				"cell": [
					30,
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
					65,
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
				"id": "deep_reserve",
				"name": "갱도 예비 공구함",
				"cell": [
					108,
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
					39,
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
				29,
				11
			],
			[
				30,
				11
			],
			[
				64,
				2
			],
			[
				65,
				2
			],
			[
				76,
				2
			],
			[
				77,
				2
			]
		],
		"inner_room": [
			76,
			2,
			7,
			5
		]
	},
	"zones": {
		"yard": "갱구 앞마당",
		"stock": "작은 적재장",
		"mine": "갱도",
		"below": "아래 갱도",
		"office": "적재 관리동"
	},
	"cliffs": [],
	"face_tags": [
		[
			74,
			44,
			6,
			3
		],
		[
			90,
			44,
			6,
			3
		]
	],
	"ridge_tags": [
		[
			17,
			2,
			8,
			6
		],
		[
			151,
			3,
			8,
			6
		]
	],
	"doors": [
		[
			64,
			70
		],
		[
			64,
			74
		],
		[
			84,
			70
		],
		[
			84,
			74
		],
		[
			108,
			70
		],
		[
			108,
			74
		]
	],
	"entries": {
		"mine_mouth": [
			[
				83,
				43
			],
			[
				84,
				43
			],
			[
				85,
				43
			]
		],
		"access_road": [
			[
				175,
				97
			],
			[
				175,
				98
			]
		],
		"open_edge": [
			[
				0,
				81
			],
			[
				0,
				64
			]
		],
		"deep_tunnel": [
			[
				75,
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
				44,
				98,
				10,
				3
			],
			"coal": 16,
			"work": [
				47,
				101
			]
		},
		{
			"id": "coal_1",
			"name": "석탄 화차",
			"rect": [
				79,
				98,
				10,
				3
			],
			"coal": 19,
			"work": [
				82,
				101
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
