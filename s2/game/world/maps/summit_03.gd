# 이 지도가 다른 판단을 만드는 것: 내린 쪽의 오두막만 조용히 뒤질지 열차를 넘어 위쪽 차고에서 무거운 구동부를 뜯을지 고른다.
extends RefCounted
## 칸 계획은 이 파일에서만 조립한다. 윗층은 없고 정비 구덩이 아래만 판다.
const FieldGrid = preload("res://game/world/field_grid.gd")
const S = FieldGrid.Solid
const F = FieldGrid.Floor
const WIDTH: int = 172
const HEIGHT: int = 84
const PLACE_ID: String = "summit_03"
const ZONE_NAMES: Dictionary = {"cut_floor":"선로 바닥","plow_shed":"제설 차고","ledge_hut":"턱 위 오두막","ridge_edge":"능선 가장자리"}
const ENTRY_NAMES: Dictionary = {"track_west_upper":"서쪽 선로, 차고 쪽","track_east_upper":"동쪽 선로, 차고 쪽","track_west_lower":"서쪽 선로, 오두막 쪽","track_east_lower":"동쪽 선로, 오두막 쪽","access_road":"진입 도로","ridge_path":"능선 길"}
const ENTRY_WEIGHTS: Dictionary = {"track_west_upper":2,"track_east_upper":2,"track_west_lower":2,"track_east_lower":2,"access_road":1.5,"ridge_path":0.5}
const FIRST_ENTRY: String = "track_west_lower"
const PLAN: Dictionary = {
	"id": 3,
	"w": 172,
	"h": 84,
	"judgment": "내린 쪽의 오두막만 조용히 뒤질지 열차를 넘어 위쪽 차고에서 무거운 구동부를 뜯을지 고른다.",
	"train": [46,43,80,3],
	"shed_up": true,
	"bands": [
		[26,21,120,22],
		[26,46,120,22]
	],
	"floors": [
		{
			"rect": [0,6,24,2],
			"kind": 5
		},
		{
			"rect": [0,76,24,2],
			"kind": 7
		},
		{
			"rect": [10,2,2,5],
			"kind": 5
		},
		{
			"rect": [16,76,2,8],
			"kind": 7
		},
		{
			"rect": [22,8,24,2],
			"kind": 5
		},
		{
			"rect": [22,74,24,2],
			"kind": 7
		},
		{
			"rect": [32,2,2,7],
			"kind": 5
		},
		{
			"rect": [38,74,2,10],
			"kind": 7
		},
		{
			"rect": [44,10,24,2],
			"kind": 5
		},
		{
			"rect": [44,72,24,2],
			"kind": 7
		},
		{
			"rect": [54,2,2,9],
			"kind": 5
		},
		{
			"rect": [60,72,2,12],
			"kind": 7
		},
		{
			"rect": [66,6,24,2],
			"kind": 5
		},
		{
			"rect": [66,76,24,2],
			"kind": 7
		},
		{
			"rect": [76,2,2,5],
			"kind": 5
		},
		{
			"rect": [82,76,2,8],
			"kind": 7
		},
		{
			"rect": [88,8,24,2],
			"kind": 5
		},
		{
			"rect": [88,74,24,2],
			"kind": 7
		},
		{
			"rect": [98,2,2,7],
			"kind": 5
		},
		{
			"rect": [104,74,2,10],
			"kind": 7
		},
		{
			"rect": [110,10,24,2],
			"kind": 5
		},
		{
			"rect": [110,72,24,2],
			"kind": 7
		},
		{
			"rect": [120,2,2,9],
			"kind": 5
		},
		{
			"rect": [126,72,2,12],
			"kind": 7
		},
		{
			"rect": [132,6,24,2],
			"kind": 5
		},
		{
			"rect": [132,76,24,2],
			"kind": 7
		},
		{
			"rect": [142,2,2,5],
			"kind": 5
		},
		{
			"rect": [148,76,2,8],
			"kind": 7
		},
		{
			"rect": [154,8,18,2],
			"kind": 5
		},
		{
			"rect": [154,74,18,2],
			"kind": 7
		},
		{
			"rect": [164,2,2,7],
			"kind": 5
		},
		{
			"rect": [170,74,2,10],
			"kind": 7
		},
		{
			"rect": [26,21,50,11],
			"kind": 7
		},
		{
			"rect": [38,38,8,2],
			"kind": 4
		},
		{
			"rect": [43,21,2,19],
			"kind": 4
		},
		{
			"rect": [87,46,3,28],
			"kind": 5
		},
		{
			"rect": [87,68,24,2],
			"kind": 5
		},
		{
			"rect": [107,68,3,14],
			"kind": 5
		},
		{
			"rect": [83,0,3,24],
			"kind": 1
		},
		{
			"rect": [47,22,39,3],
			"kind": 1
		},
		{
			"rect": [47,22,3,19],
			"kind": 1
		},
		{
			"rect": [116,70,2,14],
			"kind": 5
		},
		{
			"rect": [0,40,172,3],
			"kind": 7
		},
		{
			"rect": [0,46,172,3],
			"kind": 7
		},
		{
			"rect": [0,43,172,3],
			"kind": 4
		}
	],
	"rocks": [
		[28,38,2,1],
		[28,50,2,1],
		[142,38,2,1],
		[142,50,2,1],
		[0,25,1,6],
		[0,55,1,4],
		[1,25,1,6],
		[1,55,1,4],
		[2,25,1,6],
		[2,55,1,4],
		[3,25,1,6],
		[3,55,1,4],
		[4,25,1,6],
		[4,55,1,4],
		[5,25,1,6],
		[5,55,1,4],
		[6,25,1,6],
		[6,55,1,4],
		[7,25,1,6],
		[7,55,1,4],
		[8,25,1,6],
		[8,55,1,4],
		[9,25,1,6],
		[9,55,1,4],
		[10,25,1,6],
		[10,55,1,4],
		[11,26,1,6],
		[11,55,1,4],
		[12,26,1,6],
		[12,55,1,4],
		[13,26,1,6],
		[13,54,1,4],
		[14,26,1,6],
		[14,54,1,4],
		[15,26,1,6],
		[15,54,1,4],
		[16,26,1,6],
		[16,54,1,4],
		[17,27,1,5],
		[17,54,1,4],
		[18,27,1,5],
		[18,54,1,4],
		[19,27,1,5],
		[19,54,1,3],
		[20,27,1,5],
		[20,54,1,3],
		[21,27,1,5],
		[21,54,1,3],
		[22,26,1,5],
		[22,54,1,3],
		[23,26,1,5],
		[23,54,1,3],
		[24,26,1,5],
		[24,54,1,3],
		[25,26,1,5],
		[25,54,1,3],
		[26,26,1,5],
		[26,55,1,3],
		[27,29,1,6],
		[27,54,1,4],
		[28,29,1,6],
		[28,54,1,4],
		[29,29,1,6],
		[29,54,1,4],
		[30,26,1,5],
		[30,55,1,3],
		[31,26,1,5],
		[31,55,1,3],
		[32,26,1,5],
		[32,55,1,3],
		[33,27,1,5],
		[33,55,1,3],
		[34,26,1,6],
		[34,55,1,3],
		[35,26,1,6],
		[35,55,1,3],
		[36,26,1,6],
		[36,55,1,3],
		[37,26,1,6],
		[37,55,1,3],
		[38,26,1,6],
		[38,55,1,4],
		[39,54,1,4],
		[40,54,1,4],
		[41,54,1,4],
		[42,54,1,4],
		[43,54,1,4],
		[44,54,1,4],
		[45,54,1,4],
		[46,54,1,4],
		[47,54,1,4],
		[48,54,1,4],
		[49,54,1,4],
		[50,54,1,4],
		[51,54,1,4],
		[52,55,1,4],
		[53,55,1,4],
		[54,55,1,4],
		[55,55,1,4],
		[56,55,1,4],
		[57,55,1,3],
		[58,55,1,3],
		[59,55,1,3],
		[60,55,1,3],
		[61,55,1,3],
		[62,55,1,3],
		[63,55,1,3],
		[64,55,1,3],
		[65,27,1,5],
		[65,54,1,3],
		[66,26,1,5],
		[66,54,1,3],
		[67,26,1,5],
		[67,54,1,3],
		[68,25,1,6],
		[68,54,1,3],
		[69,25,1,6],
		[69,54,1,3],
		[70,25,1,6],
		[70,54,1,3],
		[71,25,1,6],
		[71,54,1,3],
		[72,25,1,6],
		[72,54,1,3],
		[73,25,1,6],
		[73,54,1,3],
		[74,25,1,6],
		[74,54,1,3],
		[75,25,1,6],
		[75,54,1,3],
		[76,25,1,6],
		[76,54,1,4],
		[77,26,1,6],
		[77,54,1,4],
		[78,26,1,6],
		[78,55,1,4],
		[79,26,1,6],
		[79,55,1,4],
		[80,26,1,6],
		[80,55,1,4],
		[81,26,1,6],
		[81,55,1,4],
		[82,26,1,6],
		[82,55,1,4],
		[83,26,1,6],
		[83,55,1,4],
		[84,26,1,6],
		[84,55,1,4],
		[85,27,1,5],
		[85,55,1,4],
		[86,27,1,5],
		[86,55,1,4],
		[87,27,1,5],
		[88,26,1,5],
		[89,26,1,5],
		[90,26,1,5],
		[90,55,1,4],
		[91,26,1,5],
		[91,54,1,4],
		[92,26,1,5],
		[92,54,1,4],
		[93,26,1,5],
		[93,54,1,4],
		[94,26,1,5],
		[94,54,1,4],
		[95,26,1,5],
		[95,54,1,3],
		[96,26,1,5],
		[96,54,1,3],
		[97,26,1,5],
		[97,54,1,3],
		[98,26,1,5],
		[98,54,1,3],
		[99,27,1,5],
		[99,54,1,3],
		[100,27,1,5],
		[100,54,1,3],
		[101,27,1,5],
		[101,54,1,3],
		[102,26,1,6],
		[102,54,1,3],
		[103,26,1,6],
		[103,54,1,3],
		[104,26,1,6],
		[104,55,1,3],
		[105,26,1,6],
		[105,55,1,3],
		[106,26,1,6],
		[106,55,1,3],
		[107,26,1,6],
		[107,55,1,3],
		[108,26,1,6],
		[108,55,1,3],
		[109,26,1,6],
		[109,55,1,3],
		[110,25,1,6],
		[110,55,1,3],
		[111,25,1,6],
		[111,55,1,3],
		[112,25,1,6],
		[112,55,1,3],
		[113,25,1,6],
		[113,55,1,3],
		[114,25,1,6],
		[114,55,1,4],
		[115,25,1,6],
		[115,55,1,4],
		[116,25,1,6],
		[116,55,1,4],
		[117,25,1,6],
		[117,54,1,4],
		[118,25,1,6],
		[118,54,1,4],
		[119,26,1,5],
		[119,54,1,4],
		[120,26,1,5],
		[120,54,1,4],
		[121,27,1,5],
		[121,54,1,4],
		[122,27,1,5],
		[122,54,1,4],
		[123,27,1,5],
		[123,54,1,4],
		[124,27,1,5],
		[124,54,1,4],
		[125,27,1,5],
		[125,54,1,4],
		[126,27,1,5],
		[126,54,1,4],
		[127,27,1,5],
		[127,54,1,4],
		[128,27,1,5],
		[128,54,1,4],
		[129,27,1,5],
		[129,54,1,4],
		[130,27,1,5],
		[130,55,1,4],
		[131,27,1,5],
		[131,55,1,4],
		[132,26,1,5],
		[132,55,1,4],
		[133,26,1,5],
		[133,55,1,3],
		[134,26,1,5],
		[134,55,1,3],
		[135,26,1,5],
		[135,55,1,3],
		[136,25,1,6],
		[136,55,1,3],
		[137,25,1,6],
		[137,55,1,3],
		[138,25,1,6],
		[138,55,1,3],
		[139,25,1,6],
		[139,55,1,3],
		[140,25,1,6],
		[140,55,1,3],
		[141,29,1,6],
		[141,54,1,4],
		[142,29,1,6],
		[142,54,1,4],
		[143,29,1,6],
		[143,54,1,4],
		[144,26,1,6],
		[144,54,1,3],
		[145,26,1,6],
		[145,54,1,3],
		[146,26,1,6],
		[146,54,1,3],
		[147,26,1,6],
		[147,54,1,3],
		[148,26,1,6],
		[148,54,1,3],
		[149,26,1,6],
		[149,54,1,3],
		[150,26,1,6],
		[150,54,1,3],
		[151,26,1,6],
		[151,54,1,3],
		[152,26,1,6],
		[152,54,1,4],
		[153,27,1,5],
		[153,54,1,4],
		[154,26,1,5],
		[154,54,1,4],
		[155,26,1,5],
		[155,54,1,4],
		[156,26,1,5],
		[156,55,1,4],
		[157,26,1,5],
		[157,55,1,4],
		[158,26,1,5],
		[158,55,1,4],
		[159,26,1,5],
		[159,55,1,4],
		[160,26,1,5],
		[160,55,1,4],
		[161,26,1,5],
		[161,55,1,4],
		[162,26,1,5],
		[162,55,1,4],
		[163,26,1,5],
		[163,55,1,4],
		[164,26,1,5],
		[164,55,1,4],
		[165,27,1,5],
		[165,55,1,4],
		[166,27,1,5],
		[166,55,1,4],
		[167,27,1,5],
		[167,55,1,4],
		[168,27,1,5],
		[168,55,1,4],
		[169,27,1,5],
		[169,54,1,4],
		[170,26,1,6],
		[170,54,1,4],
		[171,26,1,6],
		[171,54,1,3]
	],
	"wall_columns": [
		[0,25,6,55,4],
		[1,25,6,55,4],
		[2,25,6,55,4],
		[3,25,6,55,4],
		[4,25,6,55,4],
		[5,25,6,55,4],
		[6,25,6,55,4],
		[7,25,6,55,4],
		[8,25,6,55,4],
		[9,25,6,55,4],
		[10,25,6,55,4],
		[11,26,6,55,4],
		[12,26,6,55,4],
		[13,26,6,54,4],
		[14,26,6,54,4],
		[15,26,6,54,4],
		[16,26,6,54,4],
		[17,27,5,54,4],
		[18,27,5,54,4],
		[19,27,5,54,3],
		[20,27,5,54,3],
		[21,27,5,54,3],
		[22,26,5,54,3],
		[23,26,5,54,3],
		[24,26,5,54,3],
		[25,26,5,54,3],
		[26,26,5,55,3],
		[27,29,6,54,4],
		[28,29,6,54,4],
		[29,29,6,54,4],
		[30,26,5,55,3],
		[31,26,5,55,3],
		[32,26,5,55,3],
		[33,27,5,55,3],
		[34,26,6,55,3],
		[35,26,6,55,3],
		[36,26,6,55,3],
		[37,26,6,55,3],
		[38,26,6,55,4],
		[39,26,6,54,4],
		[40,26,6,54,4],
		[41,26,6,54,4],
		[42,26,6,54,4],
		[43,26,6,54,4],
		[44,25,6,54,4],
		[45,25,6,54,4],
		[46,25,6,54,4],
		[47,25,6,54,4],
		[48,25,6,54,4],
		[49,25,6,54,4],
		[50,25,6,54,4],
		[51,26,5,54,4],
		[52,26,5,55,4],
		[53,26,5,55,4],
		[54,26,5,55,4],
		[55,27,5,55,4],
		[56,27,5,55,4],
		[57,27,5,55,3],
		[58,27,5,55,3],
		[59,27,5,55,3],
		[60,27,5,55,3],
		[61,27,5,55,3],
		[62,27,5,55,3],
		[63,27,5,55,3],
		[64,27,5,55,3],
		[65,27,5,54,3],
		[66,26,5,54,3],
		[67,26,5,54,3],
		[68,25,6,54,3],
		[69,25,6,54,3],
		[70,25,6,54,3],
		[71,25,6,54,3],
		[72,25,6,54,3],
		[73,25,6,54,3],
		[74,25,6,54,3],
		[75,25,6,54,3],
		[76,25,6,54,4],
		[77,26,6,54,4],
		[78,26,6,55,4],
		[79,26,6,55,4],
		[80,26,6,55,4],
		[81,26,6,55,4],
		[82,26,6,55,4],
		[83,26,6,55,4],
		[84,26,6,55,4],
		[85,27,5,55,4],
		[86,27,5,55,4],
		[87,27,5,55,4],
		[88,26,5,55,4],
		[89,26,5,55,4],
		[90,26,5,55,4],
		[91,26,5,54,4],
		[92,26,5,54,4],
		[93,26,5,54,4],
		[94,26,5,54,4],
		[95,26,5,54,3],
		[96,26,5,54,3],
		[97,26,5,54,3],
		[98,26,5,54,3],
		[99,27,5,54,3],
		[100,27,5,54,3],
		[101,27,5,54,3],
		[102,26,6,54,3],
		[103,26,6,54,3],
		[104,26,6,55,3],
		[105,26,6,55,3],
		[106,26,6,55,3],
		[107,26,6,55,3],
		[108,26,6,55,3],
		[109,26,6,55,3],
		[110,25,6,55,3],
		[111,25,6,55,3],
		[112,25,6,55,3],
		[113,25,6,55,3],
		[114,25,6,55,4],
		[115,25,6,55,4],
		[116,25,6,55,4],
		[117,25,6,54,4],
		[118,25,6,54,4],
		[119,26,5,54,4],
		[120,26,5,54,4],
		[121,27,5,54,4],
		[122,27,5,54,4],
		[123,27,5,54,4],
		[124,27,5,54,4],
		[125,27,5,54,4],
		[126,27,5,54,4],
		[127,27,5,54,4],
		[128,27,5,54,4],
		[129,27,5,54,4],
		[130,27,5,55,4],
		[131,27,5,55,4],
		[132,26,5,55,4],
		[133,26,5,55,3],
		[134,26,5,55,3],
		[135,26,5,55,3],
		[136,25,6,55,3],
		[137,25,6,55,3],
		[138,25,6,55,3],
		[139,25,6,55,3],
		[140,25,6,55,3],
		[141,29,6,54,4],
		[142,29,6,54,4],
		[143,29,6,54,4],
		[144,26,6,54,3],
		[145,26,6,54,3],
		[146,26,6,54,3],
		[147,26,6,54,3],
		[148,26,6,54,3],
		[149,26,6,54,3],
		[150,26,6,54,3],
		[151,26,6,54,3],
		[152,26,6,54,4],
		[153,27,5,54,4],
		[154,26,5,54,4],
		[155,26,5,54,4],
		[156,26,5,55,4],
		[157,26,5,55,4],
		[158,26,5,55,4],
		[159,26,5,55,4],
		[160,26,5,55,4],
		[161,26,5,55,4],
		[162,26,5,55,4],
		[163,26,5,55,4],
		[164,26,5,55,4],
		[165,27,5,55,4],
		[166,27,5,55,4],
		[167,27,5,55,4],
		[168,27,5,55,4],
		[169,27,5,54,4],
		[170,26,6,54,4],
		[171,26,6,54,3]
	],
	"houses": [
		{
			"id": 0,
			"name": "제설 차고",
			"rect": [26,1,50,20],
			"walls": [
				[36,2,1,18],
				[65,2,1,18],
				[37,8,16,1],
				[52,2,1,6]
			],
			"doors": [
				[36,17],
				[65,15],
				[45,8],
				[49,20],
				[50,20],
				[60,20]
			],
			"windows": [
				[26,14],
				[26,5],
				[75,13],
				[75,4]
			],
			"rooms": [
				{
					"name": "부품 창고",
					"rect": [27,2,9,18]
				},
				{
					"name": "연료 칸",
					"rect": [66,2,9,18]
				},
				{
					"name": "정비 칸",
					"rect": [37,9,28,11]
				},
				{
					"name": "난로 방",
					"rect": [37,2,15,6]
				}
			],
			"entrances": [
				{
					"cell": [49,20],
					"outward": [0,1]
				},
				{
					"cell": [60,20],
					"outward": [0,1]
				}
			]
		},
		{
			"id": 1,
			"name": "고갯마루 오두막",
			"rect": [104,70,24,12],
			"walls": [
				[116,71,1,10]
			],
			"doors": [
				[116,73],
				[108,70]
			],
			"windows": [
				[107,81],
				[124,81],
				[127,77]
			],
			"rooms": [
				{
					"name": "일하던 방",
					"rect": [105,71,11,10]
				},
				{
					"name": "자던 방",
					"rect": [117,71,10,10]
				}
			],
			"entrances": []
		}
	],
	"props": [
		{
			"kind": "garage_door_leaf",
			"rect": [51,20,2,1],
			"solid": "wall",
			"facing": 0,
			"note": "반쯤 닫힌 큰 문짝"
		},
		{
			"kind": "parts_rack",
			"rect": [28,18,4,1],
			"solid": "low",
			"facing": 0,
			"note": "부품 선반"
		},
		{
			"kind": "tool_rack",
			"rect": [28,14,2,1],
			"solid": "low",
			"facing": 0,
			"note": "연장 걸이"
		},
		{
			"kind": "ladder_rack",
			"rect": [28,5,4,1],
			"solid": "low",
			"facing": 0,
			"note": "사다리 걸이"
		},
		{
			"kind": "fuel_drum",
			"rect": [68,18,1,1],
			"solid": "low",
			"facing": 0,
			"note": "연료 드럼"
		},
		{
			"kind": "fuel_drum",
			"rect": [70,17,1,1],
			"solid": "low",
			"facing": 0,
			"note": "연료 드럼"
		},
		{
			"kind": "fuel_drum",
			"rect": [68,15,1,1],
			"solid": "low",
			"facing": 0,
			"note": "연료 드럼"
		},
		{
			"kind": "fuel_tank",
			"rect": [68,5,3,2],
			"solid": "low",
			"facing": 0,
			"note": "연료 탱크"
		},
		{
			"kind": "inspection_pit",
			"rect": [40,17,14,2],
			"solid": "none",
			"facing": 0,
			"note": "검수 구덩이 틀"
		},
		{
			"kind": "tool_bench",
			"rect": [38,11,2,1],
			"solid": "low",
			"facing": 0,
			"note": "연장 작업대"
		},
		{
			"kind": "tool_rack",
			"rect": [57,13,2,1],
			"solid": "low",
			"facing": 0,
			"note": "연장 걸이"
		},
		{
			"kind": "siding_buffer",
			"rect": [55,13,2,3],
			"solid": "low",
			"facing": 0,
			"note": "측선 끝 차막이"
		},
		{
			"kind": "generator",
			"rect": [59,11,2,1],
			"solid": "low",
			"facing": 0,
			"note": "발전기"
		},
		{
			"kind": "rail_plow",
			"rect": [41,13,12,3],
			"solid": "wall",
			"facing": 0,
			"note": "식은 제설기"
		},
		{
			"kind": "bed",
			"rect": [38,5,2,1],
			"solid": "low",
			"facing": 0,
			"note": "침대"
		},
		{
			"kind": "shelf",
			"rect": [46,3,3,1],
			"solid": "low",
			"facing": 0,
			"note": "선반"
		},
		{
			"kind": "firewood_pile",
			"rect": [49,5,2,1],
			"solid": "low",
			"facing": 0,
			"note": "장작 더미"
		},
		{
			"kind": "desk",
			"rect": [106,79,2,1],
			"solid": "low",
			"facing": 0,
			"note": "책상"
		},
		{
			"kind": "radio_set",
			"rect": [110,79,2,1],
			"solid": "low",
			"facing": 0,
			"note": "무전기 책상"
		},
		{
			"kind": "map_cabinet",
			"rect": [106,75,3,1],
			"solid": "low",
			"facing": 0,
			"note": "도면 서랍장"
		},
		{
			"kind": "bed",
			"rect": [118,79,2,1],
			"solid": "low",
			"facing": 0,
			"note": "침대"
		},
		{
			"kind": "shelf",
			"rect": [118,75,3,1],
			"solid": "low",
			"facing": 0,
			"note": "선반"
		},
		{
			"kind": "fuel_can_group",
			"rect": [122,77,2,1],
			"solid": "low",
			"facing": 0,
			"note": "연료통 무리"
		},
		{
			"kind": "tool_rack",
			"rect": [131,72,2,1],
			"solid": "low",
			"facing": 0,
			"note": "연장 걸이"
		},
		{
			"kind": "fuel_can_group",
			"rect": [134,74,2,1],
			"solid": "low",
			"facing": 0,
			"note": "연료통 무리"
		},
		{
			"kind": "firewood_pile",
			"rect": [131,77,2,1],
			"solid": "low",
			"facing": 0,
			"note": "장작 더미"
		},
		{
			"kind": "wind_pole",
			"rect": [137,72,1,1],
			"solid": "none",
			"facing": 0,
			"note": "바람 깃 장대"
		},
		{
			"kind": "snow_gauge_pole",
			"rect": [136,78,1,1],
			"solid": "none",
			"facing": 0,
			"note": "눈금 장대"
		},
		{
			"kind": "rail_stack",
			"rect": [51,36,4,1],
			"solid": "low",
			"facing": 0,
			"note": "레일 토막 더미"
		},
		{
			"kind": "crate_stack",
			"rect": [84,35,2,2],
			"solid": "low",
			"facing": 0,
			"note": "자재 상자 더미"
		},
		{
			"kind": "sleeper_stack",
			"rect": [99,36,3,1],
			"solid": "low",
			"facing": 0,
			"note": "침목 더미"
		},
		{
			"kind": "plow_blade",
			"rect": [49,30,4,2],
			"solid": "low",
			"facing": 1,
			"note": "떼어 둔 제설 날"
		},
		{
			"kind": "snow_bank",
			"rect": [51,53,6,1],
			"solid": "low",
			"facing": 0,
			"note": "눈 둑"
		},
		{
			"kind": "fallen_log",
			"rect": [79,53,5,1],
			"solid": "low",
			"facing": 0,
			"note": "쓰러진 통나무"
		},
		{
			"kind": "crate_stack",
			"rect": [99,53,2,2],
			"solid": "low",
			"facing": 0,
			"note": "자재 상자 더미"
		},
		{
			"kind": "sleeper_stack",
			"rect": [116,50,1,3],
			"solid": "low",
			"facing": 1,
			"note": "침목 더미"
		},
		{
			"kind": "handcart",
			"rect": [78,4,2,1],
			"solid": "low",
			"facing": 0,
			"note": "짐수레"
		},
		{
			"kind": "tool_rack",
			"rect": [81,6,2,1],
			"solid": "low",
			"facing": 0,
			"note": "연장 걸이"
		},
		{
			"kind": "snowplow_truck",
			"rect": [78,9,6,3],
			"solid": "wall",
			"facing": 0,
			"note": "제설차"
		},
		{
			"kind": "fuel_drum",
			"rect": [79,14,1,1],
			"solid": "low",
			"facing": 0,
			"note": "연료 드럼"
		},
		{
			"kind": "fuel_drum",
			"rect": [81,15,1,1],
			"solid": "low",
			"facing": 0,
			"note": "연료 드럼"
		},
		{
			"kind": "fuel_drum",
			"rect": [83,14,1,1],
			"solid": "low",
			"facing": 0,
			"note": "연료 드럼"
		},
		{
			"kind": "track_switch",
			"rect": [12,39,2,1],
			"solid": "none",
			"facing": 0,
			"note": "선로 전환기"
		},
		{
			"kind": "signal_post",
			"rect": [16,37,1,1],
			"solid": "wall",
			"facing": 0,
			"note": "기둥 신호등"
		},
		{
			"kind": "rail_marker",
			"rect": [18,39,1,1],
			"solid": "none",
			"facing": 0,
			"note": "거리 말뚝"
		},
		{
			"kind": "power_pole",
			"rect": [21,36,1,1],
			"solid": "wall",
			"facing": 0,
			"note": "전신주"
		},
		{
			"kind": "snow_drift",
			"rect": [10,35,4,2],
			"solid": "none",
			"facing": 0,
			"note": "눈더미"
		},
		{
			"kind": "rock_face",
			"rect": [2,25,6,3],
			"solid": "wall",
			"facing": 0,
			"note": "암벽 면"
		},
		{
			"kind": "rock_ridge",
			"rect": [144,0,8,6],
			"solid": "wall",
			"facing": 0,
			"note": "산 능선"
		},
		{
			"kind": "snow_drift",
			"rect": [139,6,4,2],
			"solid": "none",
			"facing": 0,
			"note": "눈더미"
		}
	],
	"trees": [
		[66,79],
		[54,78],
		[115,2],
		[13,81],
		[121,0],
		[14,79],
		[23,1],
		[26,81],
		[15,78],
		[125,4],
		[27,80],
		[15,81],
		[115,4],
		[25,2],
		[134,78],
		[53,77],
		[153,8],
		[111,6],
		[18,5],
		[67,78],
		[123,1],
		[128,82],
		[20,80],
		[62,82],
		[56,79],
		[113,3],
		[124,1],
		[20,5],
		[122,1],
		[8,80],
		[15,79],
		[159,6],
		[117,0],
		[125,1],
		[157,5],
		[123,6],
		[13,79],
		[133,82],
		[27,0],
		[128,77],
		[115,3],
		[116,3],
		[119,0],
		[17,3],
		[20,2],
		[63,83],
		[161,2],
		[6,80],
		[130,3],
		[30,79],
		[19,3],
		[62,77],
		[135,79],
		[150,8],
		[63,78],
		[22,0],
		[111,5],
		[19,81],
		[63,82],
		[57,83],
		[14,80],
		[18,1],
		[129,82],
		[133,79],
		[127,4],
		[118,5],
		[26,0],
		[119,6],
		[25,6],
		[59,81],
		[10,82],
		[162,2],
		[159,3],
		[151,8],
		[19,82],
		[25,80],
		[8,78],
		[27,76],
		[134,82],
		[26,82],
		[161,6],
		[131,80],
		[25,77],
		[55,77],
		[24,3],
		[51,80],
		[45,78],
		[19,80],
		[127,3],
		[166,2]
	],
	"gates": [
		[28,35,1,3],
		[28,51,1,3],
		[142,35,1,3],
		[142,51,1,3]
	],
	"stores": [
		{
			"id": "shed_parts",
			"name": "안쪽 부품 자재함",
			"cell": [28,3],
			"level": 0,
			"items": ["cloth","plank"]
		},
		{
			"id": "shed_fuel",
			"name": "연료 칸 보급 상자",
			"cell": [73,3],
			"level": 0,
			"items": ["cloth","flare"]
		},
		{
			"id": "shed_tools",
			"name": "정비 공구함",
			"cell": [59,17],
			"level": 0,
			"items": ["cloth","bandage"]
		},
		{
			"id": "shed_food",
			"name": "난로 방 찬장",
			"cell": [43,3],
			"level": 0,
			"items": ["food_pack","cloth"]
		},
		{
			"id": "below_parts",
			"name": "지하 부품 자재함",
			"cell": [51,17],
			"level": -1,
			"items": ["cloth","plank"]
		},
		{
			"id": "below_supply",
			"name": "지하 예비 상자",
			"cell": [55,10],
			"level": -1,
			"items": ["bandage","document"]
		},
		{
			"id": "hut_radio_notes",
			"name": "무전 기록 보관함",
			"cell": [106,77],
			"level": 0,
			"items": ["document"]
		},
		{
			"id": "hut_engine_notes",
			"name": "기관 도면 보관함",
			"cell": [110,77],
			"level": 0,
			"items": ["document"]
		},
		{
			"id": "hut_supply",
			"name": "오두막 보급 상자",
			"cell": [118,72],
			"level": 0,
			"items": ["food_pack","bandage"]
		}
	],
	"salvage": [
		{
			"id": "plow_drive_1",
			"name": "제설기 구동부",
			"cell": [40,13],
			"material": "scrap",
			"amount": 2
		},
		{
			"id": "plow_drive_2",
			"name": "제설기 구동부",
			"cell": [53,13],
			"material": "scrap",
			"amount": 2
		},
		{
			"id": "plow_drive_3",
			"name": "제설기 구동부",
			"cell": [41,16],
			"material": "scrap",
			"amount": 2
		},
		{
			"id": "plow_drive_4",
			"name": "제설기 구동부",
			"cell": [52,16],
			"material": "scrap",
			"amount": 2
		},
		{
			"id": "shallow_sleepers",
			"name": "선로 곁 침목",
			"cell": [98,36],
			"material": "wood",
			"amount": 3
		},
		{
			"id": "shallow_rails",
			"name": "선로 곁 레일 토막",
			"cell": [50,36],
			"material": "scrap",
			"amount": 2
		},
		{
			"id": "shallow_log",
			"name": "벽 밑 쓰러진 나무",
			"cell": [78,53],
			"material": "wood",
			"amount": 2
		}
	],
	"stoves": [
		{
			"cell": [41,3],
			"building": 0
		},
		{
			"cell": [122,72],
			"building": 1
		}
	],
	"entries": {
		"track_west_upper": [
			[0,40],
			[0,41],
			[0,42]
		],
		"track_east_upper": [
			[171,40],
			[171,41],
			[171,42]
		],
		"track_west_lower": [
			[0,46],
			[0,47],
			[0,48]
		],
		"track_east_lower": [
			[171,46],
			[171,47],
			[171,48]
		],
		"access_road": [
			[83,0],
			[84,0],
			[85,0]
		],
		"ridge_path": [
			[116,83],
			[117,83]
		]
	},
	"dead_shed": [
		[38,18],
		[39,16],
		[54,11],
		[58,15],
		[60,13],
		[32,11],
		[33,8],
		[72,12],
		[44,5],
		[48,6]
	],
	"dead_ridge": [
		[138,76],
		[140,76],
		[142,76]
	],
	"yard": [
		[26,21,50,11]
	],
	"ramp": [
		[87,46,3,28],
		[87,68,24,2]
	],
	"cut": {
		"side": 0,
		"x": 39,
		"width": 26
	},
	"slope": {
		"side": 1,
		"x": 87,
		"width": 3
	},
	"underground": {
		"stairs": [54,17],
		"digs": [
			[50,15,8,4],
			[52,13,2,2],
			[50,9,8,4]
		],
		"rooms": [
			{
				"name": "지하 작은 부품 칸",
				"rect": [50,15,8,4]
			},
			{
				"name": "지하 큰 부품 칸",
				"rect": [50,9,8,4]
			}
		]
	}
}

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

static func build() -> Dictionary:
	var g := FieldGrid.new(WIDTH, HEIGHT)
	var below := FieldGrid.new(WIDTH, HEIGHT)
	below.solid.fill(S.BLOCK)
	below.opq.fill(1)
	below.zone.fill("plow_shed")
	var train := _r(PLAN["train"])
	var data := {
		"grid": g, "levels": {0: g, -1: below}, "stairs": [],
		"containers": {}, "spots": {}, "stoves": [], "entries": {},
		"buildings": [], "wagons": [], "train": train,
		"platform": Rect2i(train.position.x, train.end.y, 80, 3),
		"spawns": {}, "labels": [], "trees": [], "low_blocks": [], "upper_rects": [],
		"train_cars": [], "lights": [], "manholes": {}, "manhole_levels": {}, "sewer_names": {},
		"entry_levels": {}, "entry_gap": {"track_west_upper": 0.6, "track_east_upper": 0.6, "track_west_lower": 0.6, "track_east_lower": 0.6, "access_road": 0.6, "ridge_path": 2.4},
		"entry_names": ENTRY_NAMES.duplicate(), "entry_weights": ENTRY_WEIGHTS.duplicate(), "first_entry": FIRST_ENTRY,
		"zone_names": ZONE_NAMES.duplicate(),
		"unload": Rect2i(train.position.x, train.position.y - 3, 80, 9),
		"place_id": PLACE_ID, "place_kind": "summit",
		"bands": {"upper": _r(PLAN["bands"][0]), "lower": _r(PLAN["bands"][1])},
		"train_doors": {"upper": [], "lower": []}, "crossings": [], "barricade_slots": [],
		"interior_kind_slots": [{"zone": "plow_shed", "kinds": ["empty", "raiders", "nest", "beasts"]}],
		"props": [],
	}
	for row: Dictionary in PLAN["floors"]:
		_paint(g, _r(row["rect"]), -1, int(row["kind"]))
	for a: Array in PLAN["rocks"]:
		_paint(g, _r(a), S.WALL)
	for row: Dictionary in PLAN["houses"]:
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
		var rooms: Array = []
		for room: Dictionary in row["rooms"]:
			var rr := _r(room["rect"])
			rooms.append({"name": room["name"], "rect": rr})
			data["labels"].append({"text": room["name"], "cell": rr.position + Vector2i.ONE, "level": 0})
		var building := {"id": id, "name": row["name"], "rect": r, "warm": false, "window_broken": false, "rooms": rooms}
		if id == 0:
			var mouths: Array = []
			for mouth: Dictionary in row["entrances"]:
				mouths.append({"cell": _c(mouth["cell"]), "outward": _c(mouth["outward"])})
			building["entrances"] = mouths
		data["buildings"].append(building)
		data["labels"].append({"text": row["name"], "cell": r.position + Vector2i.ONE, "level": 0})
	for row: Dictionary in PLAN["props"]:
		var prop: Dictionary = row.duplicate(true)
		var r := _r(row["rect"])
		prop["rect"] = r
		data["props"].append(prop)
		if row["solid"] == "low":
			_paint(g, r, S.LOW)
			data["low_blocks"].append(r)
		elif row["solid"] == "wall":
			_paint(g, r, S.WALL)
	for a: Array in PLAN["trees"]:
		var c := _c(a)
		g.set_solid(c, S.BLOCK)
		data["trees"].append(c)
	for row: Dictionary in PLAN["stoves"]:
		var c := _c(row["cell"])
		g.set_solid(c, S.LOW)
		data["stoves"].append({"cell": c, "building": row["building"], "level": 0, "lit": false, "upstairs": false})
	_paint(g, train, S.BLOCK, F.RAIL, -1)
	for offset: int in [8, 40, 56]:
		data["train_doors"]["upper"].append(Vector2i(train.position.x + offset, train.position.y - 1))
		data["train_doors"]["lower"].append(Vector2i(train.position.x + offset, train.end.y))
	for offset: int in [16, 32, 48]:
		var x: int = train.position.x + offset
		data["crossings"].append({"cells": [Vector2i(x, train.position.y), Vector2i(x, train.position.y + 1), Vector2i(x, train.position.y + 2)], "who": {"person": true, "zombie": false, "carrying": true, "wounded": false, "sled": false}})
	for a: Array in PLAN["gates"]:
		var r := _r(a)
		for y in range(r.position.y, r.end.y):
			for x in range(r.position.x, r.end.x):
				data["barricade_slots"].append(Vector2i(x, y))
	for y in range(HEIGHT):
		for x in range(WIDTH):
			var c := Vector2i(x, y)
			var wall: Array = PLAN["wall_columns"][x]
			var z := "cut_floor"
			if (not PLAN["shed_up"] and y < int(wall[1])) or (PLAN["shed_up"] and y >= int(wall[3]) + int(wall[4])):
				z = "ledge_hut"
			for a: Array in PLAN["ramp"]:
				if _r(a).has_point(c):
					z = "ledge_hut"
			for a: Array in PLAN["yard"]:
				if _r(a).has_point(c):
					z = "plow_shed"
			if g.building_at(c) == 0:
				z = "plow_shed"
			elif g.building_at(c) == 1:
				z = "ledge_hut"
			if x < 6 or y < 6 or x >= WIDTH - 6 or y >= HEIGHT - 6:
				if g.building_at(c) < 0:
					z = "ridge_edge"
			g.zone[g.index(c)] = z
	var ug: Dictionary = PLAN["underground"]
	for a: Array in ug["digs"]:
		_paint(below, _r(a), S.NONE, F.GRAVEL, 0)
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
	data["stairs"].append({"cell": _c(ug["stairs"]), "low": -1, "high": 0, "ladder": false})
	for room: Dictionary in ug["rooms"]:
		data["labels"].append({"text": room["name"], "cell": _r(room["rect"]).position + Vector2i.ONE, "level": -1})
	for row: Dictionary in PLAN["stores"]:
		var c := _c(row["cell"])
		var lv: int = row["level"]
		var lg: FieldGrid = data["levels"][lv]
		data["containers"][row["id"]] = {"id": row["id"], "name": row["name"], "cell": c, "level": lv, "building": lg.building_at(c), "search": 7 if lv < 0 else 5, "items": row["items"].duplicate(), "locked": false, "searched": false}
	for row: Dictionary in PLAN["salvage"]:
		data["spots"][row["id"]] = {"kind": "salvage", "name": row["name"], "cell": _c(row["cell"]), "material": row["material"], "amount": row["amount"], "state": "intact"}
	for name: String in PLAN["entries"]:
		var entry: Array[Vector2i] = []
		for a: Array in PLAN["entries"][name]:
			entry.append(_c(a))
		data["entries"][name] = entry
		data["entry_levels"][name] = 0
	var all_doors: Array = data["train_doors"]["lower"] + data["train_doors"]["upper"]
	var squad: Array[Vector2i] = []
	for offset in range(39, 43):
		squad.append(Vector2i(train.position.x + offset, train.end.y + 1))
	var dead_shed: Array[Vector2i] = []
	var dead_ridge: Array[Vector2i] = []
	for a: Array in PLAN["dead_shed"]:
		dead_shed.append(_c(a))
	for a: Array in PLAN["dead_ridge"]:
		dead_ridge.append(_c(a))
	data["spawns"] = {"train_door": all_doors, "squad": squad, "dead_shed": dead_shed, "dead_ridge": dead_ridge, "dead_levels": []}
	_train_lights(data)
	g.refresh_paths()
	below.refresh_paths()
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
