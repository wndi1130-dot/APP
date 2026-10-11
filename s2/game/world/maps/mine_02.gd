# 이 지도가 다른 판단을 만드는 것: 서쪽 굴의 깊은 공구와 동쪽 세 방 사무동의 예비 자재가 멀리 갈라져 먼저 보낼 사람과 포기할 쪽을 정한다. 지하의 먼 두 계단 가운데 보급 귀환 쪽을 고른다.
extends RefCounted
## 지상·위층·아래 갱도. PLAN의 칸 좌표는 이 파일 안에서만 조립한다.
const FieldGrid = preload("res://game/world/field_grid.gd")
const S = FieldGrid.Solid
const F = FieldGrid.Floor
const WIDTH: int = 172
const HEIGHT: int = 98
const PLACE_ID: String = "mine_02"
const ZONE_NAMES: Dictionary = {"yard":"갱구 앞마당","stock":"저탄장","mine":"갱도","below":"아래 갱도","office":"적재 관리동"}
## 무전 문장에 쓰는 들어오는 길의 이름, 길마다의 비중, 첫 물결이 오는 길.
const ENTRY_NAMES: Dictionary = {"mine_mouth": "갱도 입구", "access_road": "진입로", "open_edge": "트인 벌판", "deep_tunnel": "깊은 갱도"}
const ENTRY_WEIGHTS: Dictionary = {"mine_mouth": 0.2, "access_road": 0.35, "open_edge": 0.3, "deep_tunnel": 0.15}
const FIRST_ENTRY: String = "access_road"
const PLAN: Dictionary = {
	"id": 2,
	"w": 172,
	"h": 98,
	"judgment": "서쪽 굴의 깊은 공구와 동쪽 세 방 사무동의 예비 자재가 멀리 갈라져 먼저 보낼 사람과 포기할 쪽을 정한다. 지하의 먼 두 계단 가운데 보급 귀환 쪽을 고른다.",
	"train": [
		65,
		43,
		80,
		3
	],
	"bands": [
		[
			45,
			23,
			120,
			20
		],
		[
			45,
			46,
			120,
			22
		]
	],
	"door_x": [
		81,
		101,
		125
	],
	"mountains": [
		[
			0,
			0,
			38,
			84
		],
		[
			38,
			0,
			94,
			14
		]
	],
	"cuts": [],
	"tunnels": [
		[
			7,
			16,
			31,
			3
		],
		[
			7,
			16,
			4,
			51
		],
		[
			7,
			61,
			22,
			6
		],
		[
			7,
			12,
			21,
			10
		]
	],
	"ground_rooms": [],
	"mouths": [
		{
			"cell": [
				37,
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
			10,
			17
		],
		[
			25,
			64
		]
	],
	"houses": [
		{
			"id": 1,
			"name": "적재 관리동",
			"rect": [
				135,
				1,
				33,
				19
			],
			"zone": "office",
			"walls": [
				[
					136,
					15,
					31,
					1
				],
				[
					145,
					2,
					1,
					13
				],
				[
					155,
					2,
					1,
					13
				]
			],
			"doors": [
				[
					140,
					15
				],
				[
					150,
					15
				],
				[
					161,
					15
				],
				[
					151,
					19
				],
				[
					135,
					17
				]
			],
			"windows": [
				[
					138,
					1
				],
				[
					148,
					1
				],
				[
					158,
					1
				]
			],
			"rooms": [
				{
					"name": "작업실",
					"rect": [
						136,
						2,
						9,
						13
					]
				},
				{
					"name": "부품실",
					"rect": [
						146,
						2,
						9,
						13
					]
				},
				{
					"name": "기록실",
					"rect": [
						156,
						2,
						11,
						13
					]
				},
				{
					"name": "작업 복도",
					"rect": [
						136,
						16,
						31,
						3
					]
				}
			],
			"upper": [
				135,
				1,
				18,
				12
			],
			"upper_rooms": [
				{
					"name": "작업실",
					"rect": [
						136,
						2,
						8,
						10
					]
				},
				{
					"name": "부품실",
					"rect": [
						145,
						2,
						7,
						10
					]
				}
			],
			"stair": [
				137,
				3
			],
			"through": false,
			"upper_plan": {
				"id": 1,
				"name": "적재 관리동",
				"rect": [
					135,
					1,
					18,
					12
				],
				"zone": "office",
				"walls": [
					[
						144,
						2,
						1,
						10
					]
				],
				"doors": [
					[
						144,
						7
					],
					[
						138,
						12
					],
					[
						152,
						4
					]
				],
				"windows": [
					[
						138,
						1
					],
					[
						149,
						1
					],
					[
						135,
						5
					]
				],
				"rooms": [
					{
						"name": "작업실",
						"rect": [
							136,
							2,
							8,
							10
						]
					},
					{
						"name": "부품실",
						"rect": [
							145,
							2,
							7,
							10
						]
					}
				],
				"upper": [],
				"upper_rooms": [],
				"stair": [
					137,
					3
				],
				"through": false
			}
		},
		{
			"id": 2,
			"name": "정비 헛간",
			"rect": [
				144,
				72,
				20,
				12
			],
			"zone": "stock",
			"walls": [
				[
					154,
					73,
					1,
					10
				]
			],
			"doors": [
				[
					154,
					78
				],
				[
					147,
					83
				],
				[
					163,
					75
				]
			],
			"windows": [
				[
					147,
					72
				],
				[
					160,
					72
				],
				[
					144,
					76
				]
			],
			"rooms": [
				{
					"name": "작업실",
					"rect": [
						145,
						73,
						9,
						10
					]
				},
				{
					"name": "부품실",
					"rect": [
						155,
						73,
						8,
						10
					]
				}
			],
			"upper": [],
			"upper_rooms": [],
			"stair": [
				146,
				74
			],
			"through": false
		}
	],
	"floors": [
		{
			"rect": [
				45,
				23,
				120,
				20
			],
			"kind": 7
		},
		{
			"rect": [
				45,
				46,
				120,
				22
			],
			"kind": 7
		},
		{
			"rect": [
				0,
				43,
				172,
				3
			],
			"kind": 4
		},
		{
			"rect": [
				0,
				35,
				172,
				3
			],
			"kind": 1
		},
		{
			"rect": [
				0,
				52,
				172,
				3
			],
			"kind": 1
		},
		{
			"rect": [
				58,
				20,
				4,
				53
			],
			"kind": 1
		},
		{
			"rect": [
				149,
				20,
				4,
				53
			],
			"kind": 1
		},
		{
			"rect": [
				37,
				16,
				24,
				3
			],
			"kind": 4
		},
		{
			"rect": [
				56,
				74,
				36,
				1
			],
			"kind": 4
		},
		{
			"rect": [
				65,
				76,
				12,
				3
			],
			"kind": 7
		},
		{
			"rect": [
				84,
				74,
				36,
				1
			],
			"kind": 4
		},
		{
			"rect": [
				93,
				76,
				12,
				3
			],
			"kind": 7
		},
		{
			"rect": [
				135,
				20,
				33,
				3
			],
			"kind": 1
		},
		{
			"rect": [
				144,
				84,
				20,
				3
			],
			"kind": 1
		},
		{
			"rect": [
				149,
				89,
				23,
				2
			],
			"kind": 1
		},
		{
			"rect": [
				44,
				19,
				4,
				1
			],
			"kind": 4
		},
		{
			"rect": [
				110,
				79,
				2,
				1
			],
			"kind": 4
		},
		{
			"rect": [
				43,
				17,
				4,
				1
			],
			"kind": 4
		},
		{
			"rect": [
				33,
				15,
				50,
				3
			],
			"kind": 1
		},
		{
			"rect": [
				80,
				16,
				3,
				28
			],
			"kind": 1
		},
		{
			"rect": [
				157,
				88,
				15,
				3
			],
			"kind": 1
		},
		{
			"rect": [
				146,
				87,
				14,
				3
			],
			"kind": 1
		},
		{
			"rect": [
				129,
				86,
				20,
				3
			],
			"kind": 1
		},
		{
			"rect": [
				127,
				85,
				5,
				3
			],
			"kind": 1
		},
		{
			"rect": [
				127,
				67,
				3,
				20
			],
			"kind": 1
		},
		{
			"rect": [
				124,
				67,
				5,
				3
			],
			"kind": 1
		},
		{
			"rect": [
				124,
				45,
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
				66,
				73,
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
				94,
				73,
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
				85,
				35,
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
				97,
				36,
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
				53,
				28,
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
				139,
				27,
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
				85,
				52,
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
				97,
				51,
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
				53,
				60,
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
				139,
				62,
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
				54,
				20,
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
				63,
				20,
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
				122,
				20,
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
				131,
				20,
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
				54,
				69,
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
				63,
				69,
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
				122,
				69,
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
				131,
				69,
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
				32,
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
				32,
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
				7,
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
				88,
				2,
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
				36,
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
				32,
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
				19,
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
				48,
				15,
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
				43,
				23,
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
				40,
				26,
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
				52,
				18,
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
				63,
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
				59,
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
				56,
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
				72,
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
				106,
				76,
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
				78,
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
				104,
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
				110,
				79,
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
				148,
				85,
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
				144,
				88,
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
				141,
				83,
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
				89,
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
				139,
				90,
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
				47,
				88,
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
				43,
				91,
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
				40,
				86,
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
				56,
				92,
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
				118,
				87,
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
				114,
				90,
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
				111,
				85,
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
				43,
				17,
				4,
				1
			],
			"solid": "none",
			"facing": 1,
			"note": "광차 선로"
		},
		{
			"kind": "buffer_stop",
			"rect": [
				80,
				74,
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
				108,
				74,
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
				4,
				88,
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
				22,
				92,
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
				40,
				79,
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
				68,
				89,
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
			4,
			88
		],
		[
			6,
			89
		],
		[
			2,
			90
		],
		[
			8,
			87
		],
		[
			1,
			86
		],
		[
			5,
			92
		],
		[
			9,
			91
		],
		[
			0,
			93
		],
		[
			3,
			84
		],
		[
			7,
			94
		],
		[
			10,
			85
		],
		[
			4,
			95
		],
		[
			22,
			92
		],
		[
			18,
			93
		],
		[
			24,
			90
		],
		[
			17,
			89
		],
		[
			21,
			95
		],
		[
			25,
			94
		],
		[
			16,
			96
		],
		[
			19,
			87
		],
		[
			23,
			97
		],
		[
			26,
			88
		],
		[
			15,
			91
		],
		[
			26,
			97
		],
		[
			40,
			79
		],
		[
			46,
			76
		],
		[
			39,
			75
		],
		[
			43,
			81
		],
		[
			47,
			80
		],
		[
			38,
			82
		],
		[
			41,
			73
		],
		[
			45,
			83
		],
		[
			48,
			74
		],
		[
			42,
			84
		],
		[
			48,
			83
		],
		[
			49,
			78
		],
		[
			68,
			89
		],
		[
			61,
			88
		],
		[
			65,
			94
		],
		[
			69,
			93
		],
		[
			60,
			95
		],
		[
			63,
			86
		],
		[
			67,
			96
		],
		[
			70,
			87
		],
		[
			59,
			90
		],
		[
			64,
			97
		],
		[
			70,
			96
		],
		[
			59,
			86
		],
		[
			85,
			90
		],
		[
			89,
			96
		],
		[
			93,
			95
		],
		[
			84,
			97
		],
		[
			87,
			88
		],
		[
			94,
			89
		],
		[
			83,
			92
		],
		[
			83,
			88
		],
		[
			95,
			93
		],
		[
			81,
			95
		],
		[
			91,
			86
		],
		[
			96,
			97
		],
		[
			130,
			20
		],
		[
			166,
			33
		],
		[
			169,
			24
		],
		[
			165,
			28
		],
		[
			165,
			24
		],
		[
			170,
			28
		],
		[
			168,
			30
		],
		[
			167,
			26
		],
		[
			171,
			32
		],
		[
			165,
			58
		],
		[
			168,
			49
		],
		[
			169,
			60
		],
		[
			167,
			61
		],
		[
			167,
			55
		],
		[
			166,
			51
		],
		[
			170,
			57
		],
		[
			125,
			89
		],
		[
			132,
			90
		],
		[
			121,
			93
		],
		[
			121,
			89
		],
		[
			133,
			94
		],
		[
			119,
			96
		],
		[
			129,
			87
		],
		[
			126,
			93
		],
		[
			128,
			94
		],
		[
			124,
			95
		],
		[
			130,
			92
		],
		[
			123,
			91
		]
	],
	"covers": [
		[
			85,
			35,
			2,
			2
		],
		[
			97,
			36,
			2,
			3
		],
		[
			53,
			28,
			3,
			1
		],
		[
			139,
			27,
			6,
			1
		],
		[
			85,
			52,
			2,
			2
		],
		[
			97,
			51,
			2,
			3
		],
		[
			53,
			60,
			3,
			1
		],
		[
			139,
			62,
			6,
			1
		],
		[
			63,
			20,
			4,
			3
		],
		[
			131,
			20,
			4,
			3
		],
		[
			63,
			69,
			4,
			3
		],
		[
			131,
			69,
			4,
			3
		],
		[
			45,
			19,
			2,
			1
		],
		[
			48,
			15,
			3,
			1
		],
		[
			43,
			23,
			2,
			1
		],
		[
			40,
			26,
			4,
			3
		],
		[
			52,
			18,
			2,
			2
		],
		[
			63,
			76,
			4,
			3
		],
		[
			59,
			79,
			3,
			3
		],
		[
			56,
			74,
			2,
			2
		],
		[
			104,
			80,
			6,
			1
		],
		[
			148,
			85,
			2,
			1
		],
		[
			144,
			88,
			3,
			2
		],
		[
			141,
			83,
			1,
			1
		],
		[
			157,
			89,
			1,
			1
		],
		[
			139,
			90,
			1,
			1
		],
		[
			43,
			91,
			3,
			2
		],
		[
			118,
			87,
			2,
			2
		],
		[
			111,
			85,
			3,
			1
		],
		[
			80,
			74,
			1,
			2
		],
		[
			108,
			74,
			1,
			2
		]
	],
	"gates": [
		[
			60,
			21,
			3,
			1
		],
		[
			128,
			21,
			3,
			1
		],
		[
			60,
			70,
			3,
			1
		],
		[
			128,
			70,
			3,
			1
		]
	],
	"wagons": [
		[
			66,
			73,
			10,
			3
		],
		[
			94,
			73,
			10,
			3
		]
	],
	"stores": [
		{
			"id": "house_1_0",
			"name": "적재 관리동 작업실 자재함",
			"cell": [
				137,
				3
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
				147,
				3
			],
			"items": [
				"scrap",
				"wood"
			],
			"level": 0
		},
		{
			"id": "house_1_2",
			"name": "적재 관리동 기록실 자재함",
			"cell": [
				157,
				3
			],
			"items": [
				"scrap",
				"wood"
			],
			"level": 0
		},
		{
			"id": "house_1_3",
			"name": "적재 관리동 작업 복도 자재함",
			"cell": [
				137,
				17
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
				137,
				3
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
				146,
				3
			],
			"items": [
				"wood",
				"scrap"
			],
			"level": 1
		},
		{
			"id": "house_2_0",
			"name": "정비 헛간 작업실 자재함",
			"cell": [
				146,
				74
			],
			"items": [
				"scrap",
				"wood"
			],
			"level": 0
		},
		{
			"id": "house_2_1",
			"name": "정비 헛간 부품실 자재함",
			"cell": [
				156,
				74
			],
			"items": [
				"scrap",
				"wood"
			],
			"level": 0
		},
		{
			"id": "surface_0",
			"name": "저탄장 자재함",
			"cell": [
				68,
				77
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
				96,
				77
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
				31,
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
				19,
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
			"id": "deep_1",
			"name": "공구 막장 자재함",
			"cell": [
				30,
				24
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
				29,
				56
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
				23,
				67
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
				14,
				12
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
				73,
				77
			],
			"name": "측선 고철",
			"amount": 3
		},
		{
			"id": "scrap_1",
			"cell": [
				101,
				77
			],
			"name": "측선 고철",
			"amount": 3
		}
	],
	"tree_centers": [
		[
			4,
			88
		],
		[
			20,
			91
		],
		[
			42,
			77
		],
		[
			64,
			90
		],
		[
			88,
			92
		],
		[
			127,
			26
		],
		[
			170,
			28
		],
		[
			169,
			53
		],
		[
			126,
			93
		]
	],
	"clusters": [
		[
			40,
			18,
			"pit"
		],
		[
			63,
			76,
			"coal"
		],
		[
			101,
			75,
			"load"
		],
		[
			148,
			85,
			"repair"
		],
		[
			47,
			88,
			"road"
		],
		[
			118,
			87,
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
				4,
				88
			],
			[
				6,
				89
			],
			[
				2,
				90
			],
			[
				8,
				87
			],
			[
				1,
				86
			],
			[
				5,
				92
			],
			[
				9,
				91
			],
			[
				0,
				93
			],
			[
				3,
				84
			],
			[
				7,
				94
			],
			[
				10,
				85
			],
			[
				4,
				95
			]
		],
		[
			[
				22,
				92
			],
			[
				18,
				93
			],
			[
				24,
				90
			],
			[
				17,
				89
			],
			[
				21,
				95
			],
			[
				25,
				94
			],
			[
				16,
				96
			],
			[
				19,
				87
			],
			[
				23,
				97
			],
			[
				26,
				88
			],
			[
				15,
				91
			],
			[
				26,
				97
			]
		],
		[
			[
				40,
				79
			],
			[
				46,
				76
			],
			[
				39,
				75
			],
			[
				43,
				81
			],
			[
				47,
				80
			],
			[
				38,
				82
			],
			[
				41,
				73
			],
			[
				45,
				83
			],
			[
				48,
				74
			],
			[
				42,
				84
			],
			[
				48,
				83
			],
			[
				49,
				78
			]
		],
		[
			[
				68,
				89
			],
			[
				61,
				88
			],
			[
				65,
				94
			],
			[
				69,
				93
			],
			[
				60,
				95
			],
			[
				63,
				86
			],
			[
				67,
				96
			],
			[
				70,
				87
			],
			[
				59,
				90
			],
			[
				64,
				97
			],
			[
				70,
				96
			],
			[
				59,
				86
			]
		],
		[
			[
				85,
				90
			],
			[
				89,
				96
			],
			[
				93,
				95
			],
			[
				84,
				97
			],
			[
				87,
				88
			],
			[
				94,
				89
			],
			[
				83,
				92
			],
			[
				83,
				88
			],
			[
				95,
				93
			],
			[
				81,
				95
			],
			[
				91,
				86
			],
			[
				96,
				97
			]
		],
		[
			[
				130,
				20
			]
		],
		[
			[
				166,
				33
			],
			[
				169,
				24
			],
			[
				165,
				28
			],
			[
				165,
				24
			],
			[
				170,
				28
			],
			[
				168,
				30
			],
			[
				167,
				26
			],
			[
				171,
				32
			]
		],
		[
			[
				165,
				58
			],
			[
				168,
				49
			],
			[
				169,
				60
			],
			[
				167,
				61
			],
			[
				167,
				55
			],
			[
				166,
				51
			],
			[
				170,
				57
			]
		],
		[
			[
				125,
				89
			],
			[
				132,
				90
			],
			[
				121,
				93
			],
			[
				121,
				89
			],
			[
				133,
				94
			],
			[
				119,
				96
			],
			[
				129,
				87
			],
			[
				126,
				93
			],
			[
				128,
				94
			],
			[
				124,
				95
			],
			[
				130,
				92
			],
			[
				123,
				91
			]
		]
	],
	"underground": {
		"digs": [
			[
				22,
				11,
				3,
				58
			],
			[
				13,
				11,
				3,
				58
			],
			[
				13,
				11,
				12,
				3
			],
			[
				13,
				66,
				12,
				3
			],
			[
				20,
				9,
				2,
				3
			],
			[
				24,
				25,
				5,
				2
			],
			[
				24,
				57,
				4,
				2
			],
			[
				18,
				2,
				6,
				7
			],
			[
				29,
				23,
				4,
				6
			],
			[
				28,
				55,
				5,
				6
			],
			[
				10,
				16,
				4,
				3
			],
			[
				12,
				17,
				3,
				1
			],
			[
				24,
				63,
				2,
				3
			],
			[
				23,
				64,
				3,
				1
			]
		],
		"rooms": [
			{
				"name": "권양기 방",
				"rect": [
					18,
					2,
					6,
					7
				],
				"pocket": false
			},
			{
				"name": "공구 막장",
				"rect": [
					29,
					23,
					4,
					6
				],
				"pocket": true
			},
			{
				"name": "예비 부품 막장",
				"rect": [
					28,
					55,
					5,
					6
				],
				"pocket": true
			}
		],
		"pillars": [
			[
				22,
				7
			]
		],
		"stairs": [
			[
				10,
				17
			],
			[
				25,
				64
			]
		],
		"entry": [
			28,
			26
		],
		"hoist": [
			18,
			2,
			6,
			7
		],
		"deep": [
			21,
			1
		],
		"stores": [
			{
				"id": "deep_0",
				"name": "권양기 방 자재함",
				"cell": [
					19,
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
				"id": "deep_1",
				"name": "공구 막장 자재함",
				"cell": [
					30,
					24
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
					29,
					56
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
					23,
					67
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
					14,
					12
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
				18,
				2
			],
			[
				19,
				2
			],
			[
				29,
				23
			],
			[
				30,
				23
			],
			[
				28,
				55
			],
			[
				29,
				55
			]
		],
		"inner_room": [
			28,
			55,
			5,
			6
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
			32,
			8,
			6,
			3
		],
		[
			32,
			23,
			6,
			3
		]
	],
	"ridge_tags": [
		[
			7,
			2,
			8,
			6
		],
		[
			88,
			2,
			8,
			6
		]
	],
	"doors": [
		[
			81,
			42
		],
		[
			81,
			46
		],
		[
			101,
			42
		],
		[
			101,
			46
		],
		[
			125,
			42
		],
		[
			125,
			46
		]
	],
	"entries": {
		"mine_mouth": [
			[
				34,
				16
			],
			[
				34,
				17
			],
			[
				34,
				18
			]
		],
		"access_road": [
			[
				171,
				89
			],
			[
				171,
				90
			]
		],
		"open_edge": [
			[
				171,
				53
			],
			[
				171,
				36
			]
		],
		"deep_tunnel": [
			[
				28,
				26
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
				66,
				73,
				10,
				3
			],
			"coal": 12,
			"work": [
				69,
				76
			]
		},
		{
			"id": "coal_1",
			"name": "석탄 화차",
			"rect": [
				94,
				73,
				10,
				3
			],
			"coal": 15,
			"work": [
				97,
				76
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
