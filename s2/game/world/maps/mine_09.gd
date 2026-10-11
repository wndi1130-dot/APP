# 이 지도가 다른 판단을 만드는 것: 북쪽 화차 사이를 건너 남쪽 갱구로 갈지 선로 마당을 더 회수할지 고르며 지하의 남쪽 순환로에서 돌아 나올 때를 정한다.
extends RefCounted
## 지상·위층·아래 갱도. PLAN의 칸 좌표는 이 파일 안에서만 조립한다.
const FieldGrid = preload("res://game/world/field_grid.gd")
const S = FieldGrid.Solid
const F = FieldGrid.Floor
const WIDTH: int = 180
const HEIGHT: int = 96
const PLACE_ID: String = "mine_09"
const ZONE_NAMES: Dictionary = {"yard":"갱구 앞마당","stock":"저탄장","mine":"갱도","below":"아래 갱도","office":"적재 관리동"}
## 무전 문장에 쓰는 들어오는 길의 이름, 길마다의 비중, 첫 물결이 오는 길.
const ENTRY_NAMES: Dictionary = {"mine_mouth": "갱도 입구", "access_road": "진입로", "open_edge": "트인 벌판", "deep_tunnel": "깊은 갱도"}
const ENTRY_WEIGHTS: Dictionary = {"mine_mouth": 0.2, "access_road": 0.35, "open_edge": 0.3, "deep_tunnel": 0.15}
const FIRST_ENTRY: String = "access_road"
const PLAN: Dictionary = {
	"id": 9,
	"w": 180,
	"h": 96,
	"judgment": "북쪽 화차 사이를 건너 남쪽 갱구로 갈지 선로 마당을 더 회수할지 고르며 지하의 남쪽 순환로에서 돌아 나올 때를 정한다.",
	"train": [
		50,
		45,
		80,
		3
	],
	"bands": [
		[
			30,
			25,
			120,
			20
		],
		[
			30,
			48,
			120,
			20
		]
	],
	"door_x": [
		66,
		86,
		110
	],
	"mountains": [
		[
			0,
			72,
			180,
			24
		]
	],
	"cuts": [],
	"tunnels": [
		[
			89,
			72,
			3,
			19
		],
		[
			78,
			81,
			25,
			11
		]
	],
	"ground_rooms": [],
	"mouths": [
		{
			"cell": [
				90,
				72
			],
			"outward": [
				0,
				-1
			]
		}
	],
	"down": [
		[
			90,
			89
		]
	],
	"houses": [
		{
			"id": 1,
			"name": "선로 정비동",
			"rect": [
				153,
				4,
				22,
				14
			],
			"zone": "office",
			"walls": [
				[
					164,
					5,
					1,
					12
				]
			],
			"doors": [
				[
					164,
					11
				],
				[
					156,
					17
				],
				[
					174,
					7
				]
			],
			"windows": [
				[
					156,
					4
				],
				[
					171,
					4
				],
				[
					153,
					8
				]
			],
			"rooms": [
				{
					"name": "작업실",
					"rect": [
						154,
						5,
						10,
						12
					]
				},
				{
					"name": "부품실",
					"rect": [
						165,
						5,
						9,
						12
					]
				}
			],
			"upper": [
				153,
				4,
				18,
				12
			],
			"upper_rooms": [
				{
					"name": "작업실",
					"rect": [
						154,
						5,
						8,
						10
					]
				},
				{
					"name": "부품실",
					"rect": [
						163,
						5,
						7,
						10
					]
				}
			],
			"stair": [
				155,
				6
			],
			"through": false,
			"upper_plan": {
				"id": 1,
				"name": "선로 정비동",
				"rect": [
					153,
					4,
					18,
					12
				],
				"zone": "office",
				"walls": [
					[
						162,
						5,
						1,
						10
					]
				],
				"doors": [
					[
						162,
						10
					],
					[
						156,
						15
					],
					[
						170,
						7
					]
				],
				"windows": [
					[
						156,
						4
					],
					[
						167,
						4
					],
					[
						153,
						8
					]
				],
				"rooms": [
					{
						"name": "작업실",
						"rect": [
							154,
							5,
							8,
							10
						]
					},
					{
						"name": "부품실",
						"rect": [
							163,
							5,
							7,
							10
						]
					}
				],
				"upper": [],
				"upper_rooms": [],
				"stair": [
					155,
					6
				],
				"through": false
			}
		},
		{
			"id": 2,
			"name": "화차 정비동",
			"rect": [
				3,
				34,
				22,
				14
			],
			"zone": "yard",
			"walls": [
				[
					14,
					35,
					1,
					12
				]
			],
			"doors": [
				[
					14,
					41
				],
				[
					6,
					47
				],
				[
					24,
					37
				]
			],
			"windows": [
				[
					6,
					34
				],
				[
					21,
					34
				],
				[
					3,
					38
				]
			],
			"rooms": [
				{
					"name": "작업실",
					"rect": [
						4,
						35,
						10,
						12
					]
				},
				{
					"name": "부품실",
					"rect": [
						15,
						35,
						9,
						12
					]
				}
			],
			"upper": [],
			"upper_rooms": [],
			"stair": [
				5,
				36
			],
			"through": false
		}
	],
	"floors": [
		{
			"rect": [
				30,
				25,
				120,
				20
			],
			"kind": 7
		},
		{
			"rect": [
				30,
				48,
				120,
				20
			],
			"kind": 7
		},
		{
			"rect": [
				0,
				45,
				180,
				3
			],
			"kind": 4
		},
		{
			"rect": [
				0,
				37,
				180,
				3
			],
			"kind": 1
		},
		{
			"rect": [
				0,
				54,
				180,
				3
			],
			"kind": 1
		},
		{
			"rect": [
				43,
				22,
				4,
				53
			],
			"kind": 1
		},
		{
			"rect": [
				134,
				22,
				4,
				53
			],
			"kind": 1
		},
		{
			"rect": [
				89,
				55,
				3,
				18
			],
			"kind": 4
		},
		{
			"rect": [
				98,
				55,
				4,
				13
			],
			"kind": 1
		},
		{
			"rect": [
				23,
				23,
				36,
				1
			],
			"kind": 4
		},
		{
			"rect": [
				32,
				25,
				12,
				3
			],
			"kind": 7
		},
		{
			"rect": [
				36,
				23,
				36,
				1
			],
			"kind": 4
		},
		{
			"rect": [
				45,
				25,
				12,
				3
			],
			"kind": 7
		},
		{
			"rect": [
				81,
				17,
				36,
				1
			],
			"kind": 4
		},
		{
			"rect": [
				90,
				19,
				12,
				3
			],
			"kind": 7
		},
		{
			"rect": [
				94,
				17,
				36,
				1
			],
			"kind": 4
		},
		{
			"rect": [
				103,
				19,
				12,
				3
			],
			"kind": 7
		},
		{
			"rect": [
				55,
				11,
				36,
				1
			],
			"kind": 4
		},
		{
			"rect": [
				64,
				13,
				12,
				3
			],
			"kind": 7
		},
		{
			"rect": [
				107,
				5,
				36,
				1
			],
			"kind": 4
		},
		{
			"rect": [
				116,
				7,
				12,
				3
			],
			"kind": 7
		},
		{
			"rect": [
				153,
				18,
				22,
				3
			],
			"kind": 1
		},
		{
			"rect": [
				3,
				48,
				22,
				3
			],
			"kind": 1
		},
		{
			"rect": [
				134,
				58,
				46,
				2
			],
			"kind": 1
		},
		{
			"rect": [
				73,
				68,
				4,
				1
			],
			"kind": 4
		},
		{
			"rect": [
				28,
				9,
				2,
				1
			],
			"kind": 4
		},
		{
			"rect": [
				76,
				7,
				2,
				1
			],
			"kind": 4
		},
		{
			"rect": [
				90,
				63,
				1,
				4
			],
			"kind": 4
		},
		{
			"rect": [
				0,
				54,
				13,
				3
			],
			"kind": 1
		},
		{
			"rect": [
				9,
				52,
				3,
				4
			],
			"kind": 1
		},
		{
			"rect": [
				10,
				52,
				58,
				3
			],
			"kind": 1
		},
		{
			"rect": [
				65,
				47,
				3,
				7
			],
			"kind": 1
		},
		{
			"rect": [
				0,
				37,
				5,
				3
			],
			"kind": 1
		},
		{
			"rect": [
				1,
				38,
				3,
				12
			],
			"kind": 1
		},
		{
			"rect": [
				2,
				47,
				66,
				3
			],
			"kind": 1
		},
		{
			"rect": [
				164,
				6,
				12,
				3
			],
			"kind": 1
		},
		{
			"rect": [
				164,
				7,
				3,
				6
			],
			"kind": 1
		},
		{
			"rect": [
				155,
				10,
				11,
				3
			],
			"kind": 1
		},
		{
			"rect": [
				155,
				11,
				3,
				9
			],
			"kind": 1
		},
		{
			"rect": [
				118,
				17,
				39,
				3
			],
			"kind": 1
		},
		{
			"rect": [
				109,
				18,
				12,
				3
			],
			"kind": 1
		},
		{
			"rect": [
				109,
				19,
				3,
				27
			],
			"kind": 1
		}
	],
	"props": [
		{
			"kind": "coal_wagon",
			"rect": [
				33,
				22,
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
				46,
				22,
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
				91,
				16,
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
				104,
				16,
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
				65,
				10,
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
				117,
				4,
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
				70,
				37,
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
				82,
				38,
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
				38,
				30,
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
				124,
				29,
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
				70,
				54,
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
				82,
				53,
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
				38,
				62,
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
				124,
				64,
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
				39,
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
				48,
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
				107,
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
				116,
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
				80,
				72,
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
				95,
				72,
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
				85,
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
				153,
				86,
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
				73,
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
				73,
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
				89,
				72,
				3,
				2
			],
			"solid": "none",
			"facing": 0,
			"note": "갱구 틀"
		},
		{
			"kind": "support_frame",
			"rect": [
				89,
				77,
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
				74,
				68,
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
				70,
				71,
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
				86,
				68,
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
				62,
				68,
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
				79,
				69,
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
				19,
				5,
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
				15,
				8,
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
				12,
				3,
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
				28,
				9,
				2,
				1
			],
			"solid": "none",
			"facing": 0,
			"note": "선로 전환기"
		},
		{
			"kind": "coal_sorter",
			"rect": [
				67,
				3,
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
				6,
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
				60,
				1,
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
				76,
				7,
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
				130,
				4,
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
				126,
				7,
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
				123,
				2,
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
				8,
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
				121,
				9,
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
				158,
				53,
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
				154,
				56,
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
				151,
				51,
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
				167,
				57,
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
				3,
				57,
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
				11,
				54,
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
				6,
				62,
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
				12,
				61,
				4,
				1
			],
			"solid": "none",
			"facing": 0,
			"note": "배수 도랑"
		},
		{
			"kind": "mine_track",
			"rect": [
				90,
				63,
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
				60,
				23,
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
				118,
				17,
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
				79,
				11,
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
				131,
				5,
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
				19,
				23,
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
				2,
				63,
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
				29,
				68,
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
			18
		],
		[
			7,
			19
		],
		[
			3,
			20
		],
		[
			9,
			17
		],
		[
			2,
			16
		],
		[
			6,
			22
		],
		[
			10,
			21
		],
		[
			1,
			23
		],
		[
			4,
			14
		],
		[
			8,
			24
		],
		[
			11,
			15
		],
		[
			0,
			18
		],
		[
			19,
			23
		],
		[
			15,
			24
		],
		[
			21,
			21
		],
		[
			14,
			20
		],
		[
			18,
			26
		],
		[
			22,
			25
		],
		[
			13,
			27
		],
		[
			16,
			18
		],
		[
			20,
			28
		],
		[
			23,
			19
		],
		[
			12,
			22
		],
		[
			17,
			29
		],
		[
			2,
			63
		],
		[
			8,
			60
		],
		[
			1,
			59
		],
		[
			5,
			65
		],
		[
			9,
			64
		],
		[
			0,
			66
		],
		[
			7,
			67
		],
		[
			10,
			58
		],
		[
			4,
			68
		],
		[
			10,
			67
		],
		[
			11,
			62
		],
		[
			2,
			69
		],
		[
			29,
			68
		],
		[
			36,
			69
		],
		[
			28,
			63
		],
		[
			33,
			70
		],
		[
			28,
			59
		],
		[
			26,
			66
		],
		[
			31,
			71
		],
		[
			41,
			68
		],
		[
			153,
			69
		],
		[
			157,
			68
		],
		[
			148,
			70
		],
		[
			151,
			61
		],
		[
			155,
			71
		],
		[
			158,
			62
		],
		[
			158,
			71
		],
		[
			159,
			66
		],
		[
			145,
			68
		],
		[
			160,
			70
		],
		[
			152,
			65
		],
		[
			154,
			66
		],
		[
			175,
			30
		],
		[
			179,
			29
		],
		[
			170,
			31
		],
		[
			173,
			22
		],
		[
			177,
			32
		],
		[
			169,
			26
		],
		[
			174,
			33
		],
		[
			169,
			22
		],
		[
			167,
			29
		],
		[
			177,
			20
		],
		[
			172,
			34
		],
		[
			174,
			26
		],
		[
			168,
			49
		],
		[
			171,
			40
		],
		[
			175,
			50
		],
		[
			178,
			41
		],
		[
			167,
			44
		],
		[
			172,
			51
		],
		[
			178,
			50
		],
		[
			167,
			40
		],
		[
			170,
			52
		],
		[
			172,
			44
		],
		[
			176,
			43
		],
		[
			169,
			42
		],
		[
			167,
			68
		],
		[
			174,
			69
		],
		[
			177,
			60
		],
		[
			166,
			63
		],
		[
			171,
			70
		],
		[
			177,
			69
		],
		[
			178,
			64
		],
		[
			164,
			66
		],
		[
			174,
			57
		],
		[
			169,
			71
		],
		[
			179,
			68
		],
		[
			171,
			63
		]
	],
	"covers": [
		[
			70,
			37,
			2,
			2
		],
		[
			82,
			38,
			2,
			3
		],
		[
			38,
			30,
			3,
			1
		],
		[
			124,
			29,
			6,
			1
		],
		[
			70,
			54,
			2,
			2
		],
		[
			82,
			53,
			2,
			3
		],
		[
			38,
			62,
			3,
			1
		],
		[
			124,
			64,
			6,
			1
		],
		[
			48,
			69,
			4,
			3
		],
		[
			116,
			69,
			4,
			3
		],
		[
			74,
			68,
			2,
			1
		],
		[
			70,
			71,
			3,
			1
		],
		[
			86,
			68,
			2,
			1
		],
		[
			62,
			68,
			4,
			3
		],
		[
			79,
			69,
			2,
			2
		],
		[
			12,
			3,
			6,
			1
		],
		[
			60,
			1,
			6,
			1
		],
		[
			130,
			4,
			2,
			1
		],
		[
			126,
			7,
			3,
			2
		],
		[
			123,
			2,
			1,
			1
		],
		[
			139,
			8,
			1,
			1
		],
		[
			121,
			9,
			1,
			1
		],
		[
			154,
			56,
			3,
			2
		],
		[
			3,
			57,
			4,
			3
		],
		[
			11,
			54,
			3,
			3
		],
		[
			6,
			62,
			2,
			2
		],
		[
			60,
			23,
			1,
			2
		],
		[
			118,
			17,
			1,
			2
		],
		[
			79,
			11,
			1,
			2
		],
		[
			131,
			5,
			1,
			2
		]
	],
	"gates": [
		[
			43,
			23,
			3,
			1
		],
		[
			101,
			17,
			3,
			1
		],
		[
			45,
			70,
			3,
			1
		],
		[
			113,
			70,
			3,
			1
		]
	],
	"wagons": [
		[
			33,
			22,
			10,
			3
		],
		[
			46,
			22,
			10,
			3
		],
		[
			91,
			16,
			10,
			3
		],
		[
			104,
			16,
			10,
			3
		],
		[
			65,
			10,
			10,
			3
		],
		[
			117,
			4,
			10,
			3
		]
	],
	"stores": [
		{
			"id": "house_1_0",
			"name": "선로 정비동 작업실 자재함",
			"cell": [
				155,
				6
			],
			"items": [
				"scrap",
				"wood"
			],
			"level": 0
		},
		{
			"id": "house_1_1",
			"name": "선로 정비동 부품실 자재함",
			"cell": [
				166,
				6
			],
			"items": [
				"scrap",
				"wood"
			],
			"level": 0
		},
		{
			"id": "upper_1_0",
			"name": "선로 정비동 위층 작업실 상자",
			"cell": [
				155,
				6
			],
			"items": [
				"wood",
				"scrap"
			],
			"level": 1
		},
		{
			"id": "upper_1_1",
			"name": "선로 정비동 위층 부품실 상자",
			"cell": [
				164,
				6
			],
			"items": [
				"wood",
				"scrap"
			],
			"level": 1
		},
		{
			"id": "house_2_0",
			"name": "화차 정비동 작업실 자재함",
			"cell": [
				5,
				36
			],
			"items": [
				"scrap",
				"wood"
			],
			"level": 0
		},
		{
			"id": "house_2_1",
			"name": "화차 정비동 부품실 자재함",
			"cell": [
				16,
				36
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
				35,
				26
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
				48,
				26
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
				93,
				20
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
				106,
				20
			],
			"items": [
				"scrap",
				"wood"
			],
			"level": 0
		},
		{
			"id": "surface_4",
			"name": "저탄장 자재함",
			"cell": [
				67,
				14
			],
			"items": [
				"scrap",
				"wood"
			],
			"level": 0
		},
		{
			"id": "surface_5",
			"name": "저탄장 자재함",
			"cell": [
				119,
				8
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
				90,
				78
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
				46,
				84
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
				67,
				75
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
				107,
				75
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
				118,
				83
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
				55,
				90
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
				40,
				26
			],
			"name": "측선 고철",
			"amount": 3
		},
		{
			"id": "scrap_1",
			"cell": [
				53,
				26
			],
			"name": "측선 고철",
			"amount": 3
		},
		{
			"id": "scrap_2",
			"cell": [
				98,
				20
			],
			"name": "측선 고철",
			"amount": 3
		},
		{
			"id": "scrap_3",
			"cell": [
				111,
				20
			],
			"name": "측선 고철",
			"amount": 3
		},
		{
			"id": "scrap_4",
			"cell": [
				72,
				14
			],
			"name": "측선 고철",
			"amount": 3
		},
		{
			"id": "scrap_5",
			"cell": [
				124,
				8
			],
			"name": "측선 고철",
			"amount": 3
		}
	],
	"tree_centers": [
		[
			5,
			18
		],
		[
			17,
			22
		],
		[
			4,
			61
		],
		[
			33,
			63
		],
		[
			152,
			65
		],
		[
			174,
			26
		],
		[
			172,
			44
		],
		[
			171,
			63
		]
	],
	"clusters": [
		[
			74,
			68,
			"pit"
		],
		[
			19,
			5,
			"load"
		],
		[
			67,
			3,
			"load"
		],
		[
			130,
			4,
			"repair"
		],
		[
			158,
			53,
			"road"
		],
		[
			3,
			57,
			"coal"
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
			50,
			51
		]
	],
	"tree_groups": [
		[
			[
				5,
				18
			],
			[
				7,
				19
			],
			[
				3,
				20
			],
			[
				9,
				17
			],
			[
				2,
				16
			],
			[
				6,
				22
			],
			[
				10,
				21
			],
			[
				1,
				23
			],
			[
				4,
				14
			],
			[
				8,
				24
			],
			[
				11,
				15
			],
			[
				0,
				18
			]
		],
		[
			[
				19,
				23
			],
			[
				15,
				24
			],
			[
				21,
				21
			],
			[
				14,
				20
			],
			[
				18,
				26
			],
			[
				22,
				25
			],
			[
				13,
				27
			],
			[
				16,
				18
			],
			[
				20,
				28
			],
			[
				23,
				19
			],
			[
				12,
				22
			],
			[
				17,
				29
			]
		],
		[
			[
				2,
				63
			],
			[
				8,
				60
			],
			[
				1,
				59
			],
			[
				5,
				65
			],
			[
				9,
				64
			],
			[
				0,
				66
			],
			[
				7,
				67
			],
			[
				10,
				58
			],
			[
				4,
				68
			],
			[
				10,
				67
			],
			[
				11,
				62
			],
			[
				2,
				69
			]
		],
		[
			[
				29,
				68
			],
			[
				36,
				69
			],
			[
				28,
				63
			],
			[
				33,
				70
			],
			[
				28,
				59
			],
			[
				26,
				66
			],
			[
				31,
				71
			],
			[
				41,
				68
			]
		],
		[
			[
				153,
				69
			],
			[
				157,
				68
			],
			[
				148,
				70
			],
			[
				151,
				61
			],
			[
				155,
				71
			],
			[
				158,
				62
			],
			[
				158,
				71
			],
			[
				159,
				66
			],
			[
				145,
				68
			],
			[
				160,
				70
			],
			[
				152,
				65
			],
			[
				154,
				66
			]
		],
		[
			[
				175,
				30
			],
			[
				179,
				29
			],
			[
				170,
				31
			],
			[
				173,
				22
			],
			[
				177,
				32
			],
			[
				169,
				26
			],
			[
				174,
				33
			],
			[
				169,
				22
			],
			[
				167,
				29
			],
			[
				177,
				20
			],
			[
				172,
				34
			],
			[
				174,
				26
			]
		],
		[
			[
				168,
				49
			],
			[
				171,
				40
			],
			[
				175,
				50
			],
			[
				178,
				41
			],
			[
				167,
				44
			],
			[
				172,
				51
			],
			[
				178,
				50
			],
			[
				167,
				40
			],
			[
				170,
				52
			],
			[
				172,
				44
			],
			[
				176,
				43
			],
			[
				169,
				42
			]
		],
		[
			[
				167,
				68
			],
			[
				174,
				69
			],
			[
				177,
				60
			],
			[
				166,
				63
			],
			[
				171,
				70
			],
			[
				177,
				69
			],
			[
				178,
				64
			],
			[
				164,
				66
			],
			[
				174,
				57
			],
			[
				169,
				71
			],
			[
				179,
				68
			],
			[
				171,
				63
			]
		]
	],
	"underground": {
		"digs": [
			[
				54,
				82,
				66,
				3
			],
			[
				54,
				89,
				66,
				3
			],
			[
				54,
				82,
				3,
				10
			],
			[
				117,
				82,
				3,
				10
			],
			[
				52,
				85,
				3,
				2
			],
			[
				68,
				78,
				2,
				5
			],
			[
				108,
				79,
				2,
				4
			],
			[
				45,
				83,
				7,
				6
			],
			[
				66,
				74,
				6,
				4
			],
			[
				106,
				74,
				6,
				5
			],
			[
				89,
				89,
				3,
				1
			]
		],
		"rooms": [
			{
				"name": "권양기 방",
				"rect": [
					45,
					83,
					7,
					6
				],
				"pocket": false
			},
			{
				"name": "공구 막장",
				"rect": [
					66,
					74,
					6,
					4
				],
				"pocket": true
			},
			{
				"name": "예비 부품 막장",
				"rect": [
					106,
					74,
					6,
					5
				],
				"pocket": true
			}
		],
		"pillars": [
			[
				50,
				84
			]
		],
		"stairs": [
			[
				90,
				89
			]
		],
		"entry": [
			83,
			82
		],
		"hoist": [
			45,
			83,
			7,
			6
		],
		"deep": [
			44,
			85
		],
		"stores": [
			{
				"id": "deep_0",
				"name": "권양기 방 자재함",
				"cell": [
					46,
					84
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
					67,
					75
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
					107,
					75
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
					118,
					83
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
					55,
					90
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
				45,
				83
			],
			[
				46,
				83
			],
			[
				66,
				74
			],
			[
				67,
				74
			],
			[
				106,
				74
			],
			[
				107,
				74
			]
		],
		"inner_room": [
			106,
			74,
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
			80,
			72,
			6,
			3
		],
		[
			95,
			72,
			6,
			3
		]
	],
	"ridge_tags": [
		[
			17,
			85,
			8,
			6
		],
		[
			153,
			86,
			8,
			6
		]
	],
	"doors": [
		[
			66,
			44
		],
		[
			66,
			48
		],
		[
			86,
			44
		],
		[
			86,
			48
		],
		[
			110,
			44
		],
		[
			110,
			48
		]
	],
	"entries": {
		"mine_mouth": [
			[
				89,
				75
			],
			[
				90,
				75
			],
			[
				91,
				75
			]
		],
		"access_road": [
			[
				179,
				58
			],
			[
				179,
				59
			]
		],
		"open_edge": [
			[
				0,
				55
			],
			[
				0,
				38
			]
		],
		"deep_tunnel": [
			[
				83,
				82
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
				33,
				22,
				10,
				3
			],
			"coal": 19,
			"work": [
				36,
				25
			]
		},
		{
			"id": "coal_1",
			"name": "석탄 화차",
			"rect": [
				46,
				22,
				10,
				3
			],
			"coal": 22,
			"work": [
				49,
				25
			]
		},
		{
			"id": "coal_2",
			"name": "석탄 화차",
			"rect": [
				91,
				16,
				10,
				3
			],
			"coal": 25,
			"work": [
				94,
				19
			]
		},
		{
			"id": "coal_3",
			"name": "석탄 화차",
			"rect": [
				104,
				16,
				10,
				3
			],
			"coal": 28,
			"work": [
				107,
				19
			]
		},
		{
			"id": "coal_4",
			"name": "석탄 화차",
			"rect": [
				65,
				10,
				10,
				3
			],
			"coal": 31,
			"work": [
				68,
				13
			]
		},
		{
			"id": "coal_5",
			"name": "석탄 화차",
			"rect": [
				117,
				4,
				10,
				3
			],
			"coal": 34,
			"work": [
				120,
				7
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
