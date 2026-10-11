# 이 지도가 다른 판단을 만드는 것: 갱구까지 짧게 가려면 여러 방 선탄장의 열린 통과 복도를 지나야 하므로 실내를 통과할지 동쪽으로 크게 우회할지 정한다. 지하의 옆 주머니를 돌 때 선탄장 귀환 시간을 남긴다.
extends RefCounted
## 지상·위층·아래 갱도. PLAN의 칸 좌표는 이 파일 안에서만 조립한다.
const FieldGrid = preload("res://game/world/field_grid.gd")
const S = FieldGrid.Solid
const F = FieldGrid.Floor
const WIDTH: int = 160
const HEIGHT: int = 106
const PLACE_ID: String = "mine_05"
const ZONE_NAMES: Dictionary = {"yard":"갱구 앞마당","stock":"저탄장","mine":"갱도","below":"아래 갱도","sorter":"선탄장"}
## 무전 문장에 쓰는 들어오는 길의 이름, 길마다의 비중, 첫 물결이 오는 길.
const ENTRY_NAMES: Dictionary = {"mine_mouth": "갱도 입구", "access_road": "진입로", "open_edge": "트인 벌판", "deep_tunnel": "깊은 갱도"}
const ENTRY_WEIGHTS: Dictionary = {"mine_mouth": 0.2, "access_road": 0.35, "open_edge": 0.3, "deep_tunnel": 0.15}
const FIRST_ENTRY: String = "access_road"
const PLAN: Dictionary = {
	"id": 5,
	"w": 160,
	"h": 106,
	"judgment": "갱구까지 짧게 가려면 여러 방 선탄장의 열린 통과 복도를 지나야 하므로 실내를 통과할지 동쪽으로 크게 우회할지 정한다. 지하의 옆 주머니를 돌 때 선탄장 귀환 시간을 남긴다.",
	"train": [
		40,
		70,
		80,
		3
	],
	"bands": [
		[
			20,
			50,
			120,
			20
		],
		[
			20,
			73,
			120,
			22
		]
	],
	"door_x": [
		56,
		76,
		100
	],
	"mountains": [
		[
			0,
			0,
			160,
			26
		]
	],
	"cuts": [],
	"tunnels": [
		[
			69,
			6,
			3,
			20
		],
		[
			59,
			3,
			23,
			11
		]
	],
	"ground_rooms": [],
	"mouths": [
		{
			"cell": [
				70,
				25
			],
			"outward": [
				0,
				1
			]
		}
	],
	"down": [
		[
			70,
			7
		]
	],
	"houses": [
		{
			"id": 1,
			"name": "선탄장",
			"rect": [
				50,
				31,
				38,
				19
			],
			"zone": "sorter",
			"walls": [
				[
					66,
					32,
					1,
					17
				],
				[
					72,
					32,
					1,
					17
				],
				[
					51,
					40,
					15,
					1
				]
			],
			"doors": [
				[
					69,
					31
				],
				[
					69,
					49
				],
				[
					66,
					35
				],
				[
					66,
					45
				],
				[
					72,
					36
				],
				[
					87,
					46
				]
			],
			"windows": [
				[
					54,
					31
				],
				[
					83,
					31
				],
				[
					54,
					49
				],
				[
					83,
					49
				]
			],
			"rooms": [
				{
					"name": "선별 작업실",
					"rect": [
						51,
						32,
						15,
						8
					]
				},
				{
					"name": "부품실",
					"rect": [
						51,
						41,
						15,
						8
					]
				},
				{
					"name": "선탄기 작업 칸",
					"rect": [
						73,
						32,
						14,
						17
					]
				},
				{
					"name": "통과 복도",
					"rect": [
						67,
						32,
						5,
						17
					]
				}
			],
			"upper": [
				50,
				31,
				18,
				12
			],
			"upper_rooms": [
				{
					"name": "작업실",
					"rect": [
						51,
						32,
						8,
						10
					]
				},
				{
					"name": "부품실",
					"rect": [
						60,
						32,
						7,
						10
					]
				}
			],
			"stair": [
				52,
				33
			],
			"through": true,
			"upper_plan": {
				"id": 1,
				"name": "선탄장",
				"rect": [
					50,
					31,
					18,
					12
				],
				"zone": "sorter",
				"walls": [
					[
						59,
						32,
						1,
						10
					]
				],
				"doors": [
					[
						59,
						37
					],
					[
						53,
						42
					],
					[
						67,
						34
					]
				],
				"windows": [
					[
						53,
						31
					],
					[
						64,
						31
					],
					[
						50,
						35
					]
				],
				"rooms": [
					{
						"name": "작업실",
						"rect": [
							51,
							32,
							8,
							10
						]
					},
					{
						"name": "부품실",
						"rect": [
							60,
							32,
							7,
							10
						]
					}
				],
				"upper": [],
				"upper_rooms": [],
				"stair": [
					52,
					33
				],
				"through": false
			}
		}
	],
	"floors": [
		{
			"rect": [
				20,
				50,
				120,
				20
			],
			"kind": 7
		},
		{
			"rect": [
				20,
				73,
				120,
				22
			],
			"kind": 7
		},
		{
			"rect": [
				0,
				70,
				160,
				3
			],
			"kind": 4
		},
		{
			"rect": [
				0,
				62,
				160,
				3
			],
			"kind": 1
		},
		{
			"rect": [
				0,
				79,
				160,
				3
			],
			"kind": 1
		},
		{
			"rect": [
				33,
				47,
				4,
				53
			],
			"kind": 1
		},
		{
			"rect": [
				124,
				47,
				4,
				53
			],
			"kind": 1
		},
		{
			"rect": [
				69,
				25,
				3,
				39
			],
			"kind": 4
		},
		{
			"rect": [
				78,
				30,
				4,
				34
			],
			"kind": 1
		},
		{
			"rect": [
				69,
				25,
				3,
				44
			],
			"kind": 4
		},
		{
			"rect": [
				99,
				28,
				4,
				43
			],
			"kind": 1
		},
		{
			"rect": [
				72,
				27,
				31,
				3
			],
			"kind": 1
		},
		{
			"rect": [
				101,
				36,
				36,
				1
			],
			"kind": 4
		},
		{
			"rect": [
				110,
				38,
				12,
				3
			],
			"kind": 7
		},
		{
			"rect": [
				118,
				46,
				36,
				1
			],
			"kind": 4
		},
		{
			"rect": [
				127,
				48,
				12,
				3
			],
			"kind": 7
		},
		{
			"rect": [
				50,
				50,
				38,
				3
			],
			"kind": 1
		},
		{
			"rect": [
				124,
				97,
				36,
				2
			],
			"kind": 1
		},
		{
			"rect": [
				32,
				28,
				4,
				1
			],
			"kind": 4
		},
		{
			"rect": [
				98,
				35,
				2,
				1
			],
			"kind": 4
		}
	],
	"props": [
		{
			"kind": "coal_wagon",
			"rect": [
				111,
				35,
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
				128,
				45,
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
				60,
				62,
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
				72,
				63,
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
				28,
				55,
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
				114,
				54,
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
				60,
				79,
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
				72,
				78,
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
				28,
				87,
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
				114,
				89,
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
				29,
				47,
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
				38,
				47,
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
				97,
				47,
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
				106,
				47,
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
				29,
				96,
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
				38,
				96,
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
				97,
				96,
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
				106,
				96,
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
				60,
				23,
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
				76,
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
				18,
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
				69,
				24,
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
				69,
				20,
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
				33,
				28,
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
				29,
				31,
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
				26,
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
				42,
				32,
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
				24,
				33,
				2,
				2
			],
			"solid": "low",
			"facing": 0,
			"note": "넘어진 광차"
		},
		{
			"kind": "coal_sorter",
			"rect": [
				89,
				31,
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
				97,
				28,
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
				82,
				29,
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
				98,
				35,
				2,
				1
			],
			"solid": "none",
			"facing": 0,
			"note": "선로 전환기"
		},
		{
			"kind": "coal_heap",
			"rect": [
				122,
				37,
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
				118,
				40,
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
				125,
				42,
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
				131,
				41,
				4,
				1
			],
			"solid": "none",
			"facing": 0,
			"note": "배수 도랑"
		},
		{
			"kind": "ore_truck",
			"rect": [
				119,
				95,
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
				110,
				97,
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
				117,
				99,
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
				123,
				98,
				1,
				1
			],
			"solid": "none",
			"facing": 0,
			"note": "거리 말뚝"
		},
		{
			"kind": "coal_heap",
			"rect": [
				26,
				100,
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
				23,
				95,
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
				33,
				102,
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
				39,
				101,
				4,
				1
			],
			"solid": "none",
			"facing": 0,
			"note": "배수 도랑"
		},
		{
			"kind": "tool_rack",
			"rect": [
				4,
				64,
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
				0,
				67,
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
				7,
				69,
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
				13,
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
				11,
				58,
				1,
				1
			],
			"solid": "low",
			"facing": 0,
			"note": "연료 드럼"
		},
		{
			"kind": "conveyor",
			"rect": [
				76,
				41,
				6,
				1
			],
			"solid": "low",
			"facing": 0,
			"note": "컨베이어 토막"
		},
		{
			"kind": "conveyor",
			"rect": [
				85,
				41,
				6,
				1
			],
			"solid": "low",
			"facing": 0,
			"note": "컨베이어 토막"
		},
		{
			"kind": "buffer_stop",
			"rect": [
				142,
				46,
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
				32,
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
				54,
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
				5,
				90,
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
				25,
				99,
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
			32
		],
		[
			9,
			33
		],
		[
			5,
			34
		],
		[
			11,
			31
		],
		[
			4,
			30
		],
		[
			8,
			36
		],
		[
			12,
			35
		],
		[
			3,
			37
		],
		[
			6,
			28
		],
		[
			10,
			38
		],
		[
			13,
			29
		],
		[
			2,
			32
		],
		[
			10,
			54
		],
		[
			6,
			55
		],
		[
			12,
			52
		],
		[
			5,
			51
		],
		[
			9,
			57
		],
		[
			13,
			56
		],
		[
			4,
			58
		],
		[
			7,
			49
		],
		[
			11,
			59
		],
		[
			14,
			50
		],
		[
			3,
			53
		],
		[
			8,
			60
		],
		[
			5,
			90
		],
		[
			11,
			87
		],
		[
			4,
			86
		],
		[
			8,
			92
		],
		[
			12,
			91
		],
		[
			3,
			93
		],
		[
			6,
			84
		],
		[
			10,
			94
		],
		[
			13,
			85
		],
		[
			2,
			88
		],
		[
			7,
			95
		],
		[
			13,
			94
		],
		[
			25,
			99
		],
		[
			18,
			98
		],
		[
			22,
			104
		],
		[
			26,
			103
		],
		[
			17,
			105
		],
		[
			20,
			96
		],
		[
			27,
			97
		],
		[
			16,
			100
		],
		[
			16,
			96
		],
		[
			14,
			103
		],
		[
			29,
			105
		],
		[
			21,
			100
		],
		[
			54,
			98
		],
		[
			58,
			104
		],
		[
			62,
			103
		],
		[
			53,
			105
		],
		[
			56,
			96
		],
		[
			63,
			97
		],
		[
			52,
			100
		],
		[
			52,
			96
		],
		[
			64,
			101
		],
		[
			50,
			103
		],
		[
			65,
			105
		],
		[
			57,
			100
		],
		[
			148,
			36
		],
		[
			152,
			35
		],
		[
			143,
			37
		],
		[
			146,
			28
		],
		[
			150,
			38
		],
		[
			153,
			29
		],
		[
			142,
			32
		],
		[
			147,
			39
		],
		[
			153,
			38
		],
		[
			142,
			28
		],
		[
			154,
			33
		],
		[
			140,
			35
		],
		[
			154,
			59
		],
		[
			145,
			61
		],
		[
			148,
			52
		],
		[
			155,
			53
		],
		[
			144,
			56
		],
		[
			144,
			52
		],
		[
			156,
			57
		],
		[
			142,
			59
		],
		[
			152,
			50
		],
		[
			157,
			61
		],
		[
			149,
			56
		],
		[
			151,
			57
		],
		[
			147,
			90
		],
		[
			154,
			91
		],
		[
			157,
			82
		],
		[
			146,
			85
		],
		[
			151,
			92
		],
		[
			157,
			91
		],
		[
			158,
			86
		],
		[
			144,
			88
		],
		[
			149,
			93
		],
		[
			159,
			90
		],
		[
			151,
			85
		],
		[
			153,
			86
		],
		[
			83,
			98
		],
		[
			90,
			99
		],
		[
			79,
			102
		],
		[
			79,
			98
		],
		[
			91,
			103
		],
		[
			77,
			105
		],
		[
			87,
			96
		],
		[
			84,
			102
		],
		[
			86,
			103
		],
		[
			82,
			104
		],
		[
			88,
			101
		],
		[
			81,
			100
		]
	],
	"covers": [
		[
			60,
			62,
			2,
			2
		],
		[
			72,
			63,
			2,
			3
		],
		[
			28,
			55,
			3,
			1
		],
		[
			114,
			54,
			6,
			1
		],
		[
			60,
			79,
			2,
			2
		],
		[
			72,
			78,
			2,
			3
		],
		[
			28,
			87,
			3,
			1
		],
		[
			114,
			89,
			6,
			1
		],
		[
			38,
			47,
			4,
			3
		],
		[
			106,
			47,
			4,
			3
		],
		[
			38,
			96,
			4,
			3
		],
		[
			106,
			96,
			4,
			3
		],
		[
			33,
			28,
			2,
			1
		],
		[
			29,
			31,
			3,
			1
		],
		[
			26,
			26,
			2,
			1
		],
		[
			42,
			32,
			4,
			3
		],
		[
			24,
			33,
			2,
			2
		],
		[
			82,
			29,
			6,
			1
		],
		[
			122,
			37,
			4,
			3
		],
		[
			118,
			40,
			3,
			3
		],
		[
			125,
			42,
			2,
			2
		],
		[
			110,
			97,
			3,
			2
		],
		[
			26,
			100,
			4,
			3
		],
		[
			23,
			95,
			3,
			3
		],
		[
			33,
			102,
			2,
			2
		],
		[
			4,
			64,
			2,
			1
		],
		[
			0,
			67,
			3,
			2
		],
		[
			7,
			69,
			1,
			1
		],
		[
			13,
			68,
			1,
			1
		],
		[
			11,
			58,
			1,
			1
		],
		[
			76,
			41,
			6,
			1
		],
		[
			85,
			41,
			6,
			1
		],
		[
			142,
			46,
			1,
			2
		]
	],
	"gates": [
		[
			35,
			48,
			3,
			1
		],
		[
			103,
			48,
			3,
			1
		],
		[
			35,
			97,
			3,
			1
		],
		[
			103,
			97,
			3,
			1
		]
	],
	"wagons": [
		[
			111,
			35,
			10,
			3
		],
		[
			128,
			45,
			10,
			3
		]
	],
	"stores": [
		{
			"id": "house_1_0",
			"name": "선탄장 선별 작업실 자재함",
			"cell": [
				52,
				33
			],
			"items": [
				"scrap",
				"wood"
			],
			"level": 0
		},
		{
			"id": "house_1_1",
			"name": "선탄장 부품실 자재함",
			"cell": [
				52,
				42
			],
			"items": [
				"scrap",
				"wood"
			],
			"level": 0
		},
		{
			"id": "house_1_2",
			"name": "선탄장 선탄기 작업 칸 자재함",
			"cell": [
				74,
				33
			],
			"items": [
				"scrap",
				"wood"
			],
			"level": 0
		},
		{
			"id": "house_1_3",
			"name": "선탄장 통과 복도 자재함",
			"cell": [
				68,
				33
			],
			"items": [
				"scrap",
				"wood"
			],
			"level": 0
		},
		{
			"id": "upper_1_0",
			"name": "선탄장 위층 작업실 상자",
			"cell": [
				52,
				33
			],
			"items": [
				"wood",
				"scrap"
			],
			"level": 1
		},
		{
			"id": "upper_1_1",
			"name": "선탄장 위층 부품실 상자",
			"cell": [
				61,
				33
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
				113,
				39
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
				130,
				49
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
				70,
				19
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
				51,
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
				88,
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
				118,
				39
			],
			"name": "측선 고철",
			"amount": 3
		},
		{
			"id": "scrap_1",
			"cell": [
				135,
				49
			],
			"name": "측선 고철",
			"amount": 3
		}
	],
	"tree_centers": [
		[
			7,
			32
		],
		[
			8,
			53
		],
		[
			7,
			88
		],
		[
			21,
			100
		],
		[
			57,
			100
		],
		[
			147,
			32
		],
		[
			149,
			56
		],
		[
			151,
			85
		],
		[
			84,
			102
		]
	],
	"clusters": [
		[
			33,
			28,
			"pit"
		],
		[
			89,
			31,
			"load"
		],
		[
			122,
			37,
			"coal"
		],
		[
			114,
			94,
			"road"
		],
		[
			30,
			97,
			"coal"
		],
		[
			4,
			64,
			"repair"
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
			49,
			50,
			51
		]
	],
	"tree_groups": [
		[
			[
				7,
				32
			],
			[
				9,
				33
			],
			[
				5,
				34
			],
			[
				11,
				31
			],
			[
				4,
				30
			],
			[
				8,
				36
			],
			[
				12,
				35
			],
			[
				3,
				37
			],
			[
				6,
				28
			],
			[
				10,
				38
			],
			[
				13,
				29
			],
			[
				2,
				32
			]
		],
		[
			[
				10,
				54
			],
			[
				6,
				55
			],
			[
				12,
				52
			],
			[
				5,
				51
			],
			[
				9,
				57
			],
			[
				13,
				56
			],
			[
				4,
				58
			],
			[
				7,
				49
			],
			[
				11,
				59
			],
			[
				14,
				50
			],
			[
				3,
				53
			],
			[
				8,
				60
			]
		],
		[
			[
				5,
				90
			],
			[
				11,
				87
			],
			[
				4,
				86
			],
			[
				8,
				92
			],
			[
				12,
				91
			],
			[
				3,
				93
			],
			[
				6,
				84
			],
			[
				10,
				94
			],
			[
				13,
				85
			],
			[
				2,
				88
			],
			[
				7,
				95
			],
			[
				13,
				94
			]
		],
		[
			[
				25,
				99
			],
			[
				18,
				98
			],
			[
				22,
				104
			],
			[
				26,
				103
			],
			[
				17,
				105
			],
			[
				20,
				96
			],
			[
				27,
				97
			],
			[
				16,
				100
			],
			[
				16,
				96
			],
			[
				14,
				103
			],
			[
				29,
				105
			],
			[
				21,
				100
			]
		],
		[
			[
				54,
				98
			],
			[
				58,
				104
			],
			[
				62,
				103
			],
			[
				53,
				105
			],
			[
				56,
				96
			],
			[
				63,
				97
			],
			[
				52,
				100
			],
			[
				52,
				96
			],
			[
				64,
				101
			],
			[
				50,
				103
			],
			[
				65,
				105
			],
			[
				57,
				100
			]
		],
		[
			[
				148,
				36
			],
			[
				152,
				35
			],
			[
				143,
				37
			],
			[
				146,
				28
			],
			[
				150,
				38
			],
			[
				153,
				29
			],
			[
				142,
				32
			],
			[
				147,
				39
			],
			[
				153,
				38
			],
			[
				142,
				28
			],
			[
				154,
				33
			],
			[
				140,
				35
			]
		],
		[
			[
				154,
				59
			],
			[
				145,
				61
			],
			[
				148,
				52
			],
			[
				155,
				53
			],
			[
				144,
				56
			],
			[
				144,
				52
			],
			[
				156,
				57
			],
			[
				142,
				59
			],
			[
				152,
				50
			],
			[
				157,
				61
			],
			[
				149,
				56
			],
			[
				151,
				57
			]
		],
		[
			[
				147,
				90
			],
			[
				154,
				91
			],
			[
				157,
				82
			],
			[
				146,
				85
			],
			[
				151,
				92
			],
			[
				157,
				91
			],
			[
				158,
				86
			],
			[
				144,
				88
			],
			[
				149,
				93
			],
			[
				159,
				90
			],
			[
				151,
				85
			],
			[
				153,
				86
			]
		],
		[
			[
				83,
				98
			],
			[
				90,
				99
			],
			[
				79,
				102
			],
			[
				79,
				98
			],
			[
				91,
				103
			],
			[
				77,
				105
			],
			[
				87,
				96
			],
			[
				84,
				102
			],
			[
				86,
				103
			],
			[
				82,
				104
			],
			[
				88,
				101
			],
			[
				81,
				100
			]
		]
	],
	"underground": {
		"digs": [
			[
				38,
				10,
				52,
				3
			],
			[
				38,
				17,
				52,
				3
			],
			[
				38,
				10,
				3,
				10
			],
			[
				87,
				10,
				3,
				10
			],
			[
				36,
				13,
				3,
				2
			],
			[
				52,
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
				50,
				2,
				6,
				4
			],
			[
				76,
				2,
				6,
				5
			],
			[
				69,
				7,
				3,
				4
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
					50,
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
					6,
					5
				],
				"pocket": true
			}
		],
		"pillars": [
			[
				34,
				12
			]
		],
		"stairs": [
			[
				70,
				7
			]
		],
		"entry": [
			57,
			19
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
					51,
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
					88,
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
				29,
				11
			],
			[
				30,
				11
			],
			[
				50,
				2
			],
			[
				51,
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
			6,
			5
		]
	},
	"zones": {
		"yard": "갱구 앞마당",
		"stock": "저탄장",
		"mine": "갱도",
		"below": "아래 갱도",
		"sorter": "선탄장"
	},
	"cliffs": [],
	"face_tags": [
		[
			60,
			23,
			6,
			3
		],
		[
			76,
			23,
			6,
			3
		]
	],
	"ridge_tags": [
		[
			18,
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
			56,
			69
		],
		[
			56,
			73
		],
		[
			76,
			69
		],
		[
			76,
			73
		],
		[
			100,
			69
		],
		[
			100,
			73
		]
	],
	"entries": {
		"mine_mouth": [
			[
				69,
				22
			],
			[
				70,
				22
			],
			[
				71,
				22
			]
		],
		"access_road": [
			[
				159,
				97
			],
			[
				159,
				98
			]
		],
		"open_edge": [
			[
				0,
				80
			],
			[
				0,
				63
			]
		],
		"deep_tunnel": [
			[
				57,
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
				111,
				35,
				10,
				3
			],
			"coal": 15,
			"work": [
				114,
				38
			]
		},
		{
			"id": "coal_1",
			"name": "석탄 화차",
			"rect": [
				128,
				45,
				10,
				3
			],
			"coal": 18,
			"work": [
				131,
				48
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
