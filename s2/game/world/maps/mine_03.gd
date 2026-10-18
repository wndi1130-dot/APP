# 이 지도가 다른 판단을 만드는 것: 동쪽 선로 끝의 좁은 앞마당을 지나 굴로 갈지 넓은 남쪽 저탄장의 두 측선에서 석탄을 더 챙길지 정한다. 긴 지하 측굴에서 안쪽 공구와 출구 거리를 맞바꾼다.
extends RefCounted
## 지상·위층·아래 갱도. PLAN의 칸 좌표는 이 파일 안에서만 조립한다.
const FieldGrid = preload("res://game/world/field_grid.gd")
const S = FieldGrid.Solid
const F = FieldGrid.Floor
const WIDTH: int = 178
const HEIGHT: int = 96
const PLACE_ID: String = "mine_03"
const ZONE_NAMES: Dictionary = {"yard":"갱구 앞마당","stock":"저탄장","mine":"갱도","below":"아래 갱도","office":"적재 관리동"}
## 무전 문장에 쓰는 들어오는 길의 이름, 길마다의 비중, 첫 물결이 오는 길.
const ENTRY_NAMES: Dictionary = {"mine_mouth": "갱도 입구", "access_road": "진입로", "open_edge": "트인 벌판", "deep_tunnel": "깊은 갱도"}
const ENTRY_WEIGHTS: Dictionary = {"mine_mouth": 0.2, "access_road": 0.35, "open_edge": 0.3, "deep_tunnel": 0.15}
const FIRST_ENTRY: String = "access_road"
const PLAN: Dictionary = {
	"id": 3,
	"w": 178,
	"h": 96,
	"judgment": "동쪽 선로 끝의 좁은 앞마당을 지나 굴로 갈지 넓은 남쪽 저탄장의 두 측선에서 석탄을 더 챙길지 정한다. 긴 지하 측굴에서 안쪽 공구와 출구 거리를 맞바꾼다.",
	"train": [
		32,
		27,
		80,
		3
	],
	"bands": [
		[
			12,
			7,
			120,
			20
		],
		[
			12,
			30,
			120,
			22
		]
	],
	"door_x": [
		48,
		68,
		92
	],
	"mountains": [
		[
			148,
			12,
			30,
			84
		],
		[
			156,
			0,
			22,
			12
		]
	],
	"cuts": [],
	"tunnels": [
		[
			148,
			46,
			25,
			3
		],
		[
			160,
			39,
			13,
			15
		]
	],
	"ground_rooms": [],
	"mouths": [
		{
			"cell": [
				148,
				47
			],
			"outward": [
				-1,
				0
			]
		}
	],
	"down": [
		[
			169,
			47
		]
	],
	"houses": [
		{
			"id": 1,
			"name": "선로 관리동",
			"rect": [
				100,
				2,
				29,
				14
			],
			"zone": "office",
			"walls": [
				[
					101,
					11,
					27,
					1
				],
				[
					109,
					3,
					1,
					8
				],
				[
					118,
					3,
					1,
					8
				]
			],
			"doors": [
				[
					105,
					11
				],
				[
					114,
					11
				],
				[
					123,
					11
				],
				[
					114,
					15
				],
				[
					100,
					13
				]
			],
			"windows": [
				[
					103,
					2
				],
				[
					112,
					2
				],
				[
					121,
					2
				]
			],
			"rooms": [
				{
					"name": "작업실",
					"rect": [
						101,
						3,
						8,
						8
					]
				},
				{
					"name": "부품실",
					"rect": [
						110,
						3,
						8,
						8
					]
				},
				{
					"name": "기록실",
					"rect": [
						119,
						3,
						9,
						8
					]
				},
				{
					"name": "작업 복도",
					"rect": [
						101,
						12,
						27,
						3
					]
				}
			],
			"upper": [
				100,
				2,
				18,
				12
			],
			"upper_rooms": [
				{
					"name": "작업실",
					"rect": [
						101,
						3,
						8,
						10
					]
				},
				{
					"name": "부품실",
					"rect": [
						110,
						3,
						7,
						10
					]
				}
			],
			"stair": [
				102,
				4
			],
			"through": false,
			"upper_plan": {
				"id": 1,
				"name": "선로 관리동",
				"rect": [
					100,
					2,
					18,
					12
				],
				"zone": "office",
				"walls": [
					[
						109,
						3,
						1,
						10
					]
				],
				"doors": [
					[
						109,
						8
					],
					[
						103,
						13
					],
					[
						117,
						5
					]
				],
				"windows": [
					[
						103,
						2
					],
					[
						114,
						2
					],
					[
						100,
						6
					]
				],
				"rooms": [
					{
						"name": "작업실",
						"rect": [
							101,
							3,
							8,
							10
						]
					},
					{
						"name": "부품실",
						"rect": [
							110,
							3,
							7,
							10
						]
					}
				],
				"upper": [],
				"upper_rooms": [],
				"stair": [
					102,
					4
				],
				"through": false
			}
		}
	],
	"floors": [
		{
			"rect": [
				12,
				7,
				120,
				20
			],
			"kind": 7
		},
		{
			"rect": [
				12,
				30,
				120,
				22
			],
			"kind": 7
		},
		{
			"rect": [
				0,
				27,
				178,
				3
			],
			"kind": 4
		},
		{
			"rect": [
				0,
				19,
				178,
				3
			],
			"kind": 1
		},
		{
			"rect": [
				0,
				36,
				178,
				3
			],
			"kind": 1
		},
		{
			"rect": [
				25,
				4,
				4,
				53
			],
			"kind": 1
		},
		{
			"rect": [
				116,
				4,
				4,
				53
			],
			"kind": 1
		},
		{
			"rect": [
				27,
				46,
				122,
				3
			],
			"kind": 4
		},
		{
			"rect": [
				137,
				28,
				1,
				60
			],
			"kind": 4
		},
		{
			"rect": [
				29,
				72,
				109,
				1
			],
			"kind": 4
		},
		{
			"rect": [
				82,
				87,
				56,
				1
			],
			"kind": 4
		},
		{
			"rect": [
				19,
				72,
				36,
				1
			],
			"kind": 4
		},
		{
			"rect": [
				28,
				74,
				12,
				3
			],
			"kind": 7
		},
		{
			"rect": [
				47,
				72,
				36,
				1
			],
			"kind": 4
		},
		{
			"rect": [
				56,
				74,
				12,
				3
			],
			"kind": 7
		},
		{
			"rect": [
				72,
				87,
				36,
				1
			],
			"kind": 4
		},
		{
			"rect": [
				81,
				89,
				12,
				3
			],
			"kind": 7
		},
		{
			"rect": [
				98,
				87,
				36,
				1
			],
			"kind": 4
		},
		{
			"rect": [
				107,
				89,
				12,
				3
			],
			"kind": 7
		},
		{
			"rect": [
				100,
				16,
				29,
				3
			],
			"kind": 1
		},
		{
			"rect": [
				8,
				95,
				109,
				1
			],
			"kind": 1
		},
		{
			"rect": [
				134,
				42,
				4,
				1
			],
			"kind": 4
		},
		{
			"rect": [
				120,
				87,
				2,
				1
			],
			"kind": 4
		},
		{
			"rect": [
				139,
				47,
				4,
				1
			],
			"kind": 4
		},
		{
			"rect": [
				7,
				94,
				41,
				2
			],
			"kind": 1
		},
		{
			"rect": [
				45,
				85,
				3,
				11
			],
			"kind": 1
		},
		{
			"rect": [
				46,
				84,
				3,
				4
			],
			"kind": 1
		},
		{
			"rect": [
				47,
				29,
				3,
				58
			],
			"kind": 1
		}
	],
	"props": [
		{
			"kind": "coal_wagon",
			"rect": [
				29,
				71,
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
				57,
				71,
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
				82,
				86,
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
				108,
				86,
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
				52,
				19,
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
				64,
				20,
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
				31,
				12,
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
				88,
				11,
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
				52,
				36,
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
				64,
				35,
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
				31,
				47,
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
				106,
				46,
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
				21,
				4,
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
				30,
				4,
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
				82,
				4,
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
				91,
				4,
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
				21,
				53,
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
				30,
				53,
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
				89,
				53,
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
				98,
				53,
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
				142,
				40,
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
				142,
				52,
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
				148,
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
				140,
				75,
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
				151,
				11,
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
				154,
				11,
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
				148,
				46,
				2,
				3
			],
			"solid": "none",
			"facing": 3,
			"note": "갱구 틀"
		},
		{
			"kind": "support_frame",
			"rect": [
				153,
				46,
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
				135,
				42,
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
				143,
				39,
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
				138,
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
				132,
				38,
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
				142,
				36,
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
				20,
				78,
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
				16,
				81,
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
				13,
				76,
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
				29,
				82,
				4,
				1
			],
			"solid": "none",
			"facing": 0,
			"note": "배수 도랑"
		},
		{
			"kind": "coal_heap",
			"rect": [
				51,
				84,
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
				47,
				87,
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
				44,
				82,
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
				60,
				88,
				4,
				1
			],
			"solid": "none",
			"facing": 0,
			"note": "배수 도랑"
		},
		{
			"kind": "coal_heap",
			"rect": [
				78,
				75,
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
				74,
				78,
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
				71,
				73,
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
				87,
				79,
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
				111,
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
				119,
				80,
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
				81,
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
				120,
				87,
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
				133,
				70,
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
				129,
				73,
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
				126,
				68,
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
				74,
				1,
				1
			],
			"solid": "none",
			"facing": 0,
			"note": "거리 말뚝"
		},
		{
			"kind": "tool_rack",
			"rect": [
				92,
				1,
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
				77,
				2,
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
				81,
				0,
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
				96,
				4,
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
				72,
				4,
				1,
				1
			],
			"solid": "low",
			"facing": 0,
			"note": "연료 드럼"
		},
		{
			"kind": "mine_track",
			"rect": [
				139,
				46,
				4,
				1
			],
			"solid": "none",
			"facing": 1,
			"note": "광차 선로"
		},
		{
			"kind": "coal_heap",
			"rect": [
				18,
				59,
				5,
				3
			],
			"solid": "low",
			"facing": 0,
			"note": "석탄 더미"
		},
		{
			"kind": "slag_heap",
			"rect": [
				24,
				63,
				3,
				3
			],
			"solid": "low",
			"facing": 0,
			"note": "폐석 더미"
		},
		{
			"kind": "coal_heap",
			"rect": [
				58,
				63,
				3,
				4
			],
			"solid": "low",
			"facing": 0,
			"note": "석탄 더미"
		},
		{
			"kind": "slag_heap",
			"rect": [
				64,
				67,
				3,
				3
			],
			"solid": "low",
			"facing": 0,
			"note": "폐석 더미"
		},
		{
			"kind": "coal_heap",
			"rect": [
				102,
				55,
				6,
				2
			],
			"solid": "low",
			"facing": 0,
			"note": "석탄 더미"
		},
		{
			"kind": "slag_heap",
			"rect": [
				112,
				61,
				3,
				3
			],
			"solid": "low",
			"facing": 0,
			"note": "폐석 더미"
		},
		{
			"kind": "conveyor",
			"rect": [
				119,
				69,
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
				43,
				72,
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
				96,
				87,
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
				122,
				87,
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
				18,
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
				65,
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
				41,
				6,
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
			18
		],
		[
			0,
			17
		],
		[
			4,
			23
		],
		[
			8,
			22
		],
		[
			2,
			15
		],
		[
			6,
			25
		],
		[
			9,
			16
		],
		[
			3,
			26
		],
		[
			9,
			25
		],
		[
			11,
			24
		],
		[
			7,
			65
		],
		[
			3,
			66
		],
		[
			9,
			63
		],
		[
			2,
			62
		],
		[
			6,
			68
		],
		[
			10,
			67
		],
		[
			1,
			69
		],
		[
			4,
			60
		],
		[
			8,
			70
		],
		[
			11,
			61
		],
		[
			0,
			64
		],
		[
			5,
			71
		],
		[
			7,
			92
		],
		[
			13,
			89
		],
		[
			6,
			88
		],
		[
			10,
			94
		],
		[
			14,
			93
		],
		[
			5,
			95
		],
		[
			8,
			86
		],
		[
			15,
			87
		],
		[
			4,
			90
		],
		[
			4,
			86
		],
		[
			16,
			91
		],
		[
			2,
			93
		],
		[
			41,
			6
		],
		[
			34,
			5
		],
		[
			36,
			3
		],
		[
			43,
			4
		],
		[
			32,
			3
		],
		[
			40,
			1
		],
		[
			67,
			4
		],
		[
			69,
			2
		],
		[
			76,
			3
		],
		[
			65,
			6
		],
		[
			65,
			2
		],
		[
			73,
			0
		],
		[
			70,
			6
		],
		[
			74,
			5
		],
		[
			138,
			9
		],
		[
			142,
			8
		],
		[
			133,
			10
		],
		[
			136,
			1
		],
		[
			140,
			11
		],
		[
			143,
			2
		],
		[
			132,
			5
		],
		[
			137,
			12
		],
		[
			143,
			11
		],
		[
			132,
			1
		],
		[
			144,
			6
		],
		[
			135,
			13
		],
		[
			147,
			31
		],
		[
			138,
			33
		],
		[
			141,
			24
		],
		[
			145,
			34
		],
		[
			142,
			35
		],
		[
			137,
			24
		],
		[
			135,
			31
		],
		[
			145,
			22
		],
		[
			140,
			30
		],
		[
			139,
			26
		],
		[
			143,
			32
		],
		[
			136,
			66
		],
		[
			139,
			57
		],
		[
			143,
			67
		],
		[
			146,
			58
		],
		[
			135,
			61
		],
		[
			140,
			68
		],
		[
			146,
			67
		],
		[
			135,
			57
		],
		[
			147,
			62
		],
		[
			133,
			64
		],
		[
			143,
			55
		],
		[
			138,
			69
		],
		[
			144,
			85
		],
		[
			140,
			89
		],
		[
			140,
			85
		],
		[
			138,
			92
		],
		[
			145,
			89
		],
		[
			147,
			90
		],
		[
			143,
			91
		],
		[
			142,
			87
		],
		[
			146,
			93
		],
		[
			141,
			94
		],
		[
			51,
			89
		],
		[
			40,
			92
		],
		[
			40,
			88
		],
		[
			52,
			93
		],
		[
			48,
			86
		],
		[
			45,
			92
		],
		[
			47,
			93
		],
		[
			43,
			94
		],
		[
			49,
			91
		],
		[
			42,
			90
		],
		[
			44,
			88
		]
	],
	"covers": [
		[
			52,
			19,
			2,
			2
		],
		[
			64,
			20,
			2,
			3
		],
		[
			31,
			12,
			3,
			1
		],
		[
			88,
			11,
			6,
			1
		],
		[
			52,
			36,
			2,
			2
		],
		[
			64,
			35,
			2,
			3
		],
		[
			31,
			47,
			3,
			1
		],
		[
			106,
			46,
			6,
			1
		],
		[
			30,
			4,
			4,
			3
		],
		[
			91,
			4,
			4,
			3
		],
		[
			30,
			53,
			4,
			3
		],
		[
			98,
			53,
			4,
			3
		],
		[
			135,
			42,
			2,
			1
		],
		[
			143,
			39,
			3,
			1
		],
		[
			138,
			47,
			2,
			1
		],
		[
			132,
			38,
			4,
			3
		],
		[
			142,
			36,
			2,
			2
		],
		[
			20,
			78,
			4,
			3
		],
		[
			16,
			81,
			3,
			3
		],
		[
			13,
			76,
			2,
			2
		],
		[
			51,
			84,
			4,
			3
		],
		[
			47,
			87,
			3,
			3
		],
		[
			44,
			82,
			2,
			2
		],
		[
			78,
			75,
			4,
			3
		],
		[
			74,
			78,
			3,
			3
		],
		[
			71,
			73,
			2,
			2
		],
		[
			104,
			81,
			6,
			1
		],
		[
			129,
			73,
			3,
			2
		],
		[
			92,
			1,
			2,
			1
		],
		[
			77,
			2,
			3,
			2
		],
		[
			81,
			0,
			1,
			1
		],
		[
			96,
			4,
			1,
			1
		],
		[
			72,
			4,
			1,
			1
		],
		[
			18,
			59,
			5,
			3
		],
		[
			24,
			63,
			3,
			3
		],
		[
			58,
			63,
			3,
			4
		],
		[
			64,
			67,
			3,
			3
		],
		[
			102,
			55,
			6,
			2
		],
		[
			112,
			61,
			3,
			3
		],
		[
			119,
			69,
			6,
			1
		],
		[
			43,
			72,
			1,
			2
		],
		[
			96,
			87,
			1,
			2
		],
		[
			122,
			87,
			1,
			2
		]
	],
	"gates": [
		[
			27,
			5,
			3,
			1
		],
		[
			88,
			5,
			3,
			1
		],
		[
			27,
			54,
			3,
			1
		],
		[
			95,
			54,
			3,
			1
		]
	],
	"wagons": [
		[
			29,
			71,
			10,
			3
		],
		[
			57,
			71,
			10,
			3
		],
		[
			82,
			86,
			10,
			3
		],
		[
			108,
			86,
			10,
			3
		]
	],
	"stores": [
		{
			"id": "house_1_0",
			"name": "선로 관리동 작업실 자재함",
			"cell": [
				102,
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
			"name": "선로 관리동 부품실 자재함",
			"cell": [
				111,
				4
			],
			"items": [
				"scrap",
				"wood"
			],
			"level": 0
		},
		{
			"id": "house_1_2",
			"name": "선로 관리동 기록실 자재함",
			"cell": [
				120,
				4
			],
			"items": [
				"scrap",
				"wood"
			],
			"level": 0
		},
		{
			"id": "house_1_3",
			"name": "선로 관리동 작업 복도 자재함",
			"cell": [
				102,
				13
			],
			"items": [
				"scrap",
				"wood"
			],
			"level": 0
		},
		{
			"id": "upper_1_0",
			"name": "선로 관리동 위층 작업실 상자",
			"cell": [
				102,
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
			"name": "선로 관리동 위층 부품실 상자",
			"cell": [
				111,
				4
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
				31,
				75
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
				59,
				75
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
				84,
				90
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
				110,
				90
			],
			"items": [
				"scrap",
				"wood"
			],
			"level": 0
		},
		{
			"id": "forehall_0",
			"name": "갱구 앞방 공구함",
			"cell": [
				154,
				47
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
				162,
				2
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
				153,
				23
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
				153,
				61
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
				161,
				72
			],
			"items": [
				"scrap",
				"wood"
			],
			"level": -1
		},
		{
			"id": "deep_fuel",
			"name": "안쪽 연료 보관함",
			"cell": [
				168,
				11
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
				36,
				75
			],
			"name": "측선 고철",
			"amount": 3
		},
		{
			"id": "scrap_1",
			"cell": [
				64,
				75
			],
			"name": "측선 고철",
			"amount": 3
		},
		{
			"id": "scrap_2",
			"cell": [
				89,
				90
			],
			"name": "측선 고철",
			"amount": 3
		},
		{
			"id": "scrap_3",
			"cell": [
				115,
				90
			],
			"name": "측선 고철",
			"amount": 3
		}
	],
	"tree_centers": [
		[
			3,
			19
		],
		[
			5,
			64
		],
		[
			9,
			90
		],
		[
			37,
			7
		],
		[
			70,
			6
		],
		[
			137,
			5
		],
		[
			142,
			28
		],
		[
			140,
			61
		],
		[
			145,
			89
		],
		[
			45,
			92
		]
	],
	"clusters": [
		[
			135,
			42,
			"pit"
		],
		[
			20,
			78,
			"coal"
		],
		[
			51,
			84,
			"coal"
		],
		[
			78,
			75,
			"coal"
		],
		[
			111,
			83,
			"load"
		],
		[
			133,
			70,
			"road"
		],
		[
			84,
			4,
			"repair"
		]
	],
	"assumptions": [
		"1칸은 1m. 공구·부품은 scrap, 연료는 wood, 석탄은 화차 coal로 기록한다. 지하 입구와 계단 거리는 네 방향 최단 걸음으로 센다.",
		"위층은 해당 건물 범위만 만들고 나머지는 AIR, 지하는 파낸 칸과 바로 둘레만 그린다. 지하의 깊은 갱 자리는 벽 면의 예약 좌표이며 새 반환 열쇠를 만들지 않는다."
	],
	"group_members": [
		[
			28,
			29,
			30,
			31,
			32
		],
		[
			33,
			34,
			35,
			36
		],
		[
			37,
			38,
			39,
			40
		],
		[
			41,
			42,
			43,
			44
		],
		[
			45,
			46,
			47,
			48
		],
		[
			49,
			50,
			51,
			52
		],
		[
			53,
			54,
			55,
			56,
			57
		]
	],
	"tree_groups": [
		[
			[
				7,
				18
			],
			[
				0,
				17
			],
			[
				4,
				23
			],
			[
				8,
				22
			],
			[
				2,
				15
			],
			[
				6,
				25
			],
			[
				9,
				16
			],
			[
				3,
				26
			],
			[
				9,
				25
			],
			[
				11,
				24
			]
		],
		[
			[
				7,
				65
			],
			[
				3,
				66
			],
			[
				9,
				63
			],
			[
				2,
				62
			],
			[
				6,
				68
			],
			[
				10,
				67
			],
			[
				1,
				69
			],
			[
				4,
				60
			],
			[
				8,
				70
			],
			[
				11,
				61
			],
			[
				0,
				64
			],
			[
				5,
				71
			]
		],
		[
			[
				7,
				92
			],
			[
				13,
				89
			],
			[
				6,
				88
			],
			[
				10,
				94
			],
			[
				14,
				93
			],
			[
				5,
				95
			],
			[
				8,
				86
			],
			[
				15,
				87
			],
			[
				4,
				90
			],
			[
				4,
				86
			],
			[
				16,
				91
			],
			[
				2,
				93
			]
		],
		[
			[
				41,
				6
			],
			[
				34,
				5
			],
			[
				36,
				3
			],
			[
				43,
				4
			],
			[
				32,
				3
			],
			[
				40,
				1
			]
		],
		[
			[
				67,
				4
			],
			[
				69,
				2
			],
			[
				76,
				3
			],
			[
				65,
				6
			],
			[
				65,
				2
			],
			[
				73,
				0
			],
			[
				70,
				6
			],
			[
				74,
				5
			]
		],
		[
			[
				138,
				9
			],
			[
				142,
				8
			],
			[
				133,
				10
			],
			[
				136,
				1
			],
			[
				140,
				11
			],
			[
				143,
				2
			],
			[
				132,
				5
			],
			[
				137,
				12
			],
			[
				143,
				11
			],
			[
				132,
				1
			],
			[
				144,
				6
			],
			[
				135,
				13
			]
		],
		[
			[
				147,
				31
			],
			[
				138,
				33
			],
			[
				141,
				24
			],
			[
				145,
				34
			],
			[
				142,
				35
			],
			[
				137,
				24
			],
			[
				135,
				31
			],
			[
				145,
				22
			],
			[
				140,
				30
			],
			[
				139,
				26
			],
			[
				143,
				32
			]
		],
		[
			[
				136,
				66
			],
			[
				139,
				57
			],
			[
				143,
				67
			],
			[
				146,
				58
			],
			[
				135,
				61
			],
			[
				140,
				68
			],
			[
				146,
				67
			],
			[
				135,
				57
			],
			[
				147,
				62
			],
			[
				133,
				64
			],
			[
				143,
				55
			],
			[
				138,
				69
			]
		],
		[
			[
				144,
				85
			],
			[
				140,
				89
			],
			[
				140,
				85
			],
			[
				138,
				92
			],
			[
				145,
				89
			],
			[
				147,
				90
			],
			[
				143,
				91
			],
			[
				142,
				87
			],
			[
				146,
				93
			],
			[
				141,
				94
			]
		],
		[
			[
				51,
				89
			],
			[
				40,
				92
			],
			[
				40,
				88
			],
			[
				52,
				93
			],
			[
				48,
				86
			],
			[
				45,
				92
			],
			[
				47,
				93
			],
			[
				43,
				94
			],
			[
				49,
				91
			],
			[
				42,
				90
			],
			[
				44,
				88
			]
		]
	],
	"underground": {
		"digs": [
			[
				160,
				10,
				3,
				64
			],
			[
				167,
				10,
				3,
				64
			],
			[
				160,
				10,
				10,
				3
			],
			[
				160,
				71,
				10,
				3
			],
			[
				163,
				8,
				2,
				3
			],
			[
				156,
				24,
				5,
				2
			],
			[
				157,
				62,
				4,
				2
			],
			[
				161,
				1,
				6,
				7
			],
			[
				152,
				22,
				4,
				6
			],
			[
				152,
				60,
				5,
				6
			],
			[
				168,
				47,
				3,
				1
			]
		],
		"rooms": [
			{
				"name": "권양기 방",
				"rect": [
					161,
					1,
					6,
					7
				],
				"pocket": false
			},
			{
				"name": "공구 막장",
				"rect": [
					152,
					22,
					4,
					6
				],
				"pocket": true
			},
			{
				"name": "예비 부품 막장",
				"rect": [
					152,
					60,
					5,
					6
				],
				"pocket": true
			}
		],
		"pillars": [
			[
				162,
				6
			]
		],
		"stairs": [
			[
				169,
				47
			]
		],
		"entry": [
			160,
			36
		],
		"hoist": [
			161,
			1,
			6,
			7
		],
		"deep": [
			163,
			0
		],
		"stores": [
			{
				"id": "deep_0",
				"name": "권양기 방 자재함",
				"cell": [
					162,
					2
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
					153,
					23
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
					153,
					61
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
					161,
					72
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
					168,
					11
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
				161,
				1
			],
			[
				162,
				1
			],
			[
				152,
				22
			],
			[
				153,
				22
			],
			[
				152,
				60
			],
			[
				153,
				60
			]
		],
		"inner_room": [
			152,
			60,
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
			148,
			40,
			6,
			3
		],
		[
			148,
			52,
			6,
			3
		]
	],
	"ridge_tags": [
		[
			160,
			2,
			8,
			6
		],
		[
			162,
			68,
			8,
			6
		]
	],
	"doors": [
		[
			48,
			26
		],
		[
			48,
			30
		],
		[
			68,
			26
		],
		[
			68,
			30
		],
		[
			92,
			26
		],
		[
			92,
			30
		]
	],
	"entries": {
		"mine_mouth": [
			[
				151,
				46
			],
			[
				151,
				47
			],
			[
				151,
				48
			]
		],
		"access_road": [
			[
				8,
				95
			],
			[
				9,
				95
			]
		],
		"open_edge": [
			[
				0,
				37
			],
			[
				0,
				20
			]
		],
		"deep_tunnel": [
			[
				160,
				36
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
				29,
				71,
				10,
				3
			],
			"coal": 13,
			"work": [
				32,
				74
			]
		},
		{
			"id": "coal_1",
			"name": "석탄 화차",
			"rect": [
				57,
				71,
				10,
				3
			],
			"coal": 16,
			"work": [
				60,
				74
			]
		},
		{
			"id": "coal_2",
			"name": "석탄 화차",
			"rect": [
				82,
				86,
				10,
				3
			],
			"coal": 19,
			"work": [
				85,
				89
			]
		},
		{
			"id": "coal_3",
			"name": "석탄 화차",
			"rect": [
				108,
				86,
				10,
				3
			],
			"coal": 22,
			"work": [
				111,
				89
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
	# 구역과 수납 속성을 채운 뒤 암벽만 건물 키트에서 뺀다.
	for lg: FieldGrid in [g, up, below]:
		for index in range(WIDTH * HEIGHT):
			if lg.solid[index] == S.WALL and lg.building[index] == 0:
				lg.building[index] = -1
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
