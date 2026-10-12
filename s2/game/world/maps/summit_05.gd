# 이 지도가 다른 판단을 만드는 것: 앞마당에 나온 제설기를 도로에서 바로 볼 수 있다. 차고 안 무리를 건드리지 않고 뜯기를 끝낼지 정한다.
extends RefCounted
## 칸 계획은 이 파일에서만 조립한다. 윗층은 없고 정비 구덩이 아래만 판다.
const FieldGrid = preload("res://game/world/field_grid.gd")
const S = FieldGrid.Solid
const F = FieldGrid.Floor
const WIDTH: int = 174
const HEIGHT: int = 86
const PLACE_ID: String = "summit_05"
const ZONE_NAMES: Dictionary = {"cut_floor":"선로 바닥","plow_shed":"제설 차고","ledge_hut":"턱 위 오두막","ridge_edge":"능선 가장자리"}
const ENTRY_NAMES: Dictionary = {"track_west_upper":"서쪽 선로, 오두막 쪽","track_east_upper":"동쪽 선로, 오두막 쪽","track_west_lower":"서쪽 선로, 차고 쪽","track_east_lower":"동쪽 선로, 차고 쪽","access_road":"진입 도로","ridge_path":"능선 길"}
const ENTRY_WEIGHTS: Dictionary = {"track_west_upper":2,"track_east_upper":2,"track_west_lower":2,"track_east_lower":2,"access_road":1.5,"ridge_path":0.5}
const FIRST_ENTRY: String = "track_west_upper"
const PLAN: Dictionary = {
	"id": 5,
	"w": 174,
	"h": 86,
	"judgment": "앞마당에 나온 제설기를 도로에서 바로 볼 수 있다. 차고 안 무리를 건드리지 않고 뜯기를 끝낼지 정한다.",
	"train": [47,38,80,3],
	"shed_up": false,
	"bands": [
		[27,16,120,22],
		[27,41,120,22]
	],
	"floors": [
		{
			"rect": [0,10,24,2],
			"kind": 5
		},
		{
			"rect": [0,74,24,2],
			"kind": 7
		},
		{
			"rect": [10,2,2,9],
			"kind": 5
		},
		{
			"rect": [16,74,2,12],
			"kind": 7
		},
		{
			"rect": [22,6,24,2],
			"kind": 5
		},
		{
			"rect": [22,78,24,2],
			"kind": 7
		},
		{
			"rect": [32,2,2,5],
			"kind": 5
		},
		{
			"rect": [38,78,2,8],
			"kind": 7
		},
		{
			"rect": [44,8,24,2],
			"kind": 5
		},
		{
			"rect": [44,76,24,2],
			"kind": 7
		},
		{
			"rect": [54,2,2,7],
			"kind": 5
		},
		{
			"rect": [60,76,2,10],
			"kind": 7
		},
		{
			"rect": [66,10,24,2],
			"kind": 5
		},
		{
			"rect": [66,74,24,2],
			"kind": 7
		},
		{
			"rect": [76,2,2,9],
			"kind": 5
		},
		{
			"rect": [82,74,2,12],
			"kind": 7
		},
		{
			"rect": [88,6,24,2],
			"kind": 5
		},
		{
			"rect": [88,78,24,2],
			"kind": 7
		},
		{
			"rect": [98,2,2,5],
			"kind": 5
		},
		{
			"rect": [104,78,2,8],
			"kind": 7
		},
		{
			"rect": [110,8,24,2],
			"kind": 5
		},
		{
			"rect": [110,76,24,2],
			"kind": 7
		},
		{
			"rect": [120,2,2,7],
			"kind": 5
		},
		{
			"rect": [126,76,2,10],
			"kind": 7
		},
		{
			"rect": [132,10,24,2],
			"kind": 5
		},
		{
			"rect": [132,74,24,2],
			"kind": 7
		},
		{
			"rect": [142,2,2,9],
			"kind": 5
		},
		{
			"rect": [148,74,2,12],
			"kind": 7
		},
		{
			"rect": [154,6,20,2],
			"kind": 5
		},
		{
			"rect": [154,78,20,2],
			"kind": 7
		},
		{
			"rect": [164,2,2,5],
			"kind": 5
		},
		{
			"rect": [170,78,2,8],
			"kind": 7
		},
		{
			"rect": [82,49,68,15],
			"kind": 7
		},
		{
			"rect": [39,45,50,2],
			"kind": 4
		},
		{
			"rect": [86,45,2,6],
			"kind": 4
		},
		{
			"rect": [116,16,3,22],
			"kind": 5
		},
		{
			"rect": [86,16,33,2],
			"kind": 5
		},
		{
			"rect": [85,2,3,27],
			"kind": 5
		},
		{
			"rect": [79,60,3,26],
			"kind": 1
		},
		{
			"rect": [79,60,14,3],
			"kind": 1
		},
		{
			"rect": [90,45,3,18],
			"kind": 1
		},
		{
			"rect": [94,0,2,17],
			"kind": 5
		},
		{
			"rect": [0,35,174,3],
			"kind": 7
		},
		{
			"rect": [0,41,174,3],
			"kind": 7
		},
		{
			"rect": [0,38,174,3],
			"kind": 4
		},
		{
			"rect": [0,66,84,2],
			"kind": 5
		},
		{
			"rect": [83,44,3,42],
			"kind": 1
		}
	],
	"rocks": [
		[29,33,2,1],
		[29,45,2,1],
		[143,33,2,1],
		[143,45,2,1],
		[0,20,1,6],
		[0,50,1,4],
		[1,20,1,6],
		[1,50,1,4],
		[2,20,1,6],
		[2,50,1,4],
		[3,20,1,6],
		[3,50,1,4],
		[4,20,1,6],
		[4,50,1,4],
		[5,20,1,6],
		[5,50,1,4],
		[6,20,1,6],
		[6,50,1,4],
		[7,20,1,6],
		[7,50,1,4],
		[8,20,1,6],
		[8,50,1,4],
		[9,20,1,6],
		[9,50,1,4],
		[10,20,1,6],
		[10,50,1,4],
		[11,21,1,6],
		[11,50,1,4],
		[12,21,1,6],
		[12,50,1,4],
		[13,21,1,6],
		[13,49,1,4],
		[14,21,1,6],
		[14,49,1,4],
		[15,21,1,6],
		[15,49,1,4],
		[16,21,1,6],
		[16,49,1,4],
		[17,22,1,5],
		[17,49,1,4],
		[18,22,1,5],
		[18,49,1,4],
		[19,22,1,5],
		[19,49,1,3],
		[20,22,1,5],
		[20,49,1,3],
		[21,22,1,5],
		[21,49,1,3],
		[22,21,1,5],
		[22,49,1,3],
		[23,21,1,5],
		[23,49,1,3],
		[24,21,1,5],
		[24,49,1,3],
		[25,21,1,5],
		[25,49,1,3],
		[26,21,1,5],
		[26,50,1,3],
		[27,21,1,5],
		[27,50,1,3],
		[28,24,1,6],
		[28,49,1,4],
		[29,24,1,6],
		[29,49,1,4],
		[30,24,1,6],
		[30,49,1,4],
		[31,21,1,5],
		[31,50,1,3],
		[32,21,1,5],
		[32,50,1,3],
		[33,22,1,5],
		[33,50,1,3],
		[34,21,1,6],
		[34,50,1,3],
		[35,21,1,6],
		[35,50,1,3],
		[36,21,1,6],
		[36,50,1,3],
		[37,21,1,6],
		[37,50,1,3],
		[38,21,1,6],
		[38,50,1,4],
		[39,21,1,6],
		[39,49,1,4],
		[40,21,1,6],
		[40,49,1,4],
		[41,21,1,6],
		[41,49,1,4],
		[42,21,1,6],
		[42,49,1,4],
		[43,21,1,6],
		[43,49,1,4],
		[44,20,1,6],
		[44,49,1,4],
		[45,20,1,6],
		[45,49,1,4],
		[46,20,1,6],
		[46,49,1,4],
		[47,20,1,6],
		[47,49,1,4],
		[48,20,1,6],
		[48,49,1,4],
		[49,20,1,6],
		[49,49,1,4],
		[50,20,1,6],
		[50,49,1,4],
		[51,21,1,5],
		[51,49,1,4],
		[52,21,1,5],
		[52,50,1,4],
		[53,21,1,5],
		[53,50,1,4],
		[54,21,1,5],
		[54,50,1,4],
		[55,22,1,5],
		[55,50,1,4],
		[56,22,1,5],
		[56,50,1,4],
		[57,22,1,5],
		[57,50,1,3],
		[58,22,1,5],
		[58,50,1,3],
		[59,22,1,5],
		[59,50,1,3],
		[60,22,1,5],
		[60,50,1,3],
		[61,22,1,5],
		[61,50,1,3],
		[62,22,1,5],
		[62,50,1,3],
		[63,22,1,5],
		[63,50,1,3],
		[64,22,1,5],
		[64,50,1,3],
		[65,22,1,5],
		[65,49,1,3],
		[66,21,1,5],
		[66,49,1,3],
		[67,21,1,5],
		[67,49,1,3],
		[68,20,1,6],
		[68,49,1,3],
		[69,20,1,6],
		[69,49,1,3],
		[70,20,1,6],
		[70,49,1,3],
		[71,20,1,6],
		[71,49,1,3],
		[72,20,1,6],
		[72,49,1,3],
		[73,20,1,6],
		[73,49,1,3],
		[74,20,1,6],
		[74,49,1,3],
		[75,20,1,6],
		[75,49,1,3],
		[76,20,1,6],
		[76,49,1,4],
		[77,21,1,6],
		[77,49,1,4],
		[78,21,1,6],
		[78,50,1,4],
		[79,21,1,6],
		[79,50,1,4],
		[80,21,1,6],
		[80,50,1,4],
		[81,21,1,6],
		[81,50,1,4],
		[82,21,1,6],
		[83,21,1,6],
		[84,21,1,6],
		[85,22,1,5],
		[86,22,1,5],
		[87,22,1,5],
		[88,21,1,5],
		[89,21,1,5],
		[90,21,1,5],
		[91,21,1,5],
		[92,21,1,5],
		[93,21,1,5],
		[94,21,1,5],
		[95,21,1,5],
		[96,21,1,5],
		[97,21,1,5],
		[98,21,1,5],
		[99,22,1,5],
		[100,22,1,5],
		[101,22,1,5],
		[102,21,1,6],
		[103,21,1,6],
		[104,21,1,6],
		[105,21,1,6],
		[106,21,1,6],
		[107,21,1,6],
		[108,21,1,6],
		[108,50,1,3],
		[109,21,1,6],
		[109,50,1,3],
		[110,20,1,6],
		[110,50,1,3],
		[111,20,1,6],
		[111,50,1,3],
		[112,20,1,6],
		[112,50,1,3],
		[113,20,1,6],
		[113,50,1,3],
		[114,20,1,6],
		[114,50,1,4],
		[115,20,1,6],
		[115,50,1,4],
		[116,50,1,4],
		[117,49,1,4],
		[118,49,1,4],
		[119,21,1,5],
		[119,49,1,4],
		[120,21,1,5],
		[120,49,1,4],
		[121,22,1,5],
		[121,49,1,4],
		[122,22,1,5],
		[122,49,1,4],
		[123,22,1,5],
		[123,49,1,4],
		[124,22,1,5],
		[124,49,1,4],
		[125,22,1,5],
		[125,49,1,4],
		[126,22,1,5],
		[126,49,1,4],
		[127,22,1,5],
		[127,49,1,4],
		[128,22,1,5],
		[128,49,1,4],
		[129,22,1,5],
		[129,49,1,4],
		[130,22,1,5],
		[130,50,1,4],
		[131,22,1,5],
		[131,50,1,4],
		[132,21,1,5],
		[132,50,1,4],
		[133,21,1,5],
		[133,50,1,3],
		[134,21,1,5],
		[134,50,1,3],
		[135,21,1,5],
		[135,50,1,3],
		[136,20,1,6],
		[136,50,1,3],
		[137,20,1,6],
		[137,50,1,3],
		[138,20,1,6],
		[138,50,1,3],
		[139,20,1,6],
		[139,50,1,3],
		[140,20,1,6],
		[140,50,1,3],
		[141,20,1,6],
		[141,50,1,3],
		[142,24,1,6],
		[142,49,1,4],
		[143,24,1,6],
		[143,49,1,4],
		[144,24,1,6],
		[144,49,1,4],
		[145,21,1,6],
		[145,49,1,3],
		[146,21,1,6],
		[146,49,1,3],
		[147,21,1,6],
		[147,49,1,3],
		[148,21,1,6],
		[148,49,1,3],
		[149,21,1,6],
		[149,49,1,3],
		[150,21,1,6],
		[150,49,1,3],
		[151,21,1,6],
		[151,49,1,3],
		[152,21,1,6],
		[152,49,1,4],
		[153,22,1,5],
		[153,49,1,4],
		[154,21,1,5],
		[154,49,1,4],
		[155,21,1,5],
		[155,49,1,4],
		[156,21,1,5],
		[156,50,1,4],
		[157,21,1,5],
		[157,50,1,4],
		[158,21,1,5],
		[158,50,1,4],
		[159,21,1,5],
		[159,50,1,4],
		[160,21,1,5],
		[160,50,1,4],
		[161,21,1,5],
		[161,50,1,4],
		[162,21,1,5],
		[162,50,1,4],
		[163,21,1,5],
		[163,50,1,4],
		[164,21,1,5],
		[164,50,1,4],
		[165,22,1,5],
		[165,50,1,4],
		[166,22,1,5],
		[166,50,1,4],
		[167,22,1,5],
		[167,50,1,4],
		[168,22,1,5],
		[168,50,1,4],
		[169,22,1,5],
		[169,49,1,4],
		[170,21,1,6],
		[170,49,1,4],
		[171,21,1,6],
		[171,49,1,3],
		[172,21,1,6],
		[172,49,1,3],
		[173,21,1,6],
		[173,49,1,3]
	],
	"wall_columns": [
		[0,20,6,50,4],
		[1,20,6,50,4],
		[2,20,6,50,4],
		[3,20,6,50,4],
		[4,20,6,50,4],
		[5,20,6,50,4],
		[6,20,6,50,4],
		[7,20,6,50,4],
		[8,20,6,50,4],
		[9,20,6,50,4],
		[10,20,6,50,4],
		[11,21,6,50,4],
		[12,21,6,50,4],
		[13,21,6,49,4],
		[14,21,6,49,4],
		[15,21,6,49,4],
		[16,21,6,49,4],
		[17,22,5,49,4],
		[18,22,5,49,4],
		[19,22,5,49,3],
		[20,22,5,49,3],
		[21,22,5,49,3],
		[22,21,5,49,3],
		[23,21,5,49,3],
		[24,21,5,49,3],
		[25,21,5,49,3],
		[26,21,5,50,3],
		[27,21,5,50,3],
		[28,24,6,49,4],
		[29,24,6,49,4],
		[30,24,6,49,4],
		[31,21,5,50,3],
		[32,21,5,50,3],
		[33,22,5,50,3],
		[34,21,6,50,3],
		[35,21,6,50,3],
		[36,21,6,50,3],
		[37,21,6,50,3],
		[38,21,6,50,4],
		[39,21,6,49,4],
		[40,21,6,49,4],
		[41,21,6,49,4],
		[42,21,6,49,4],
		[43,21,6,49,4],
		[44,20,6,49,4],
		[45,20,6,49,4],
		[46,20,6,49,4],
		[47,20,6,49,4],
		[48,20,6,49,4],
		[49,20,6,49,4],
		[50,20,6,49,4],
		[51,21,5,49,4],
		[52,21,5,50,4],
		[53,21,5,50,4],
		[54,21,5,50,4],
		[55,22,5,50,4],
		[56,22,5,50,4],
		[57,22,5,50,3],
		[58,22,5,50,3],
		[59,22,5,50,3],
		[60,22,5,50,3],
		[61,22,5,50,3],
		[62,22,5,50,3],
		[63,22,5,50,3],
		[64,22,5,50,3],
		[65,22,5,49,3],
		[66,21,5,49,3],
		[67,21,5,49,3],
		[68,20,6,49,3],
		[69,20,6,49,3],
		[70,20,6,49,3],
		[71,20,6,49,3],
		[72,20,6,49,3],
		[73,20,6,49,3],
		[74,20,6,49,3],
		[75,20,6,49,3],
		[76,20,6,49,4],
		[77,21,6,49,4],
		[78,21,6,50,4],
		[79,21,6,50,4],
		[80,21,6,50,4],
		[81,21,6,50,4],
		[82,21,6,50,4],
		[83,21,6,50,4],
		[84,21,6,50,4],
		[85,22,5,50,4],
		[86,22,5,50,4],
		[87,22,5,50,4],
		[88,21,5,50,4],
		[89,21,5,50,4],
		[90,21,5,50,4],
		[91,21,5,49,4],
		[92,21,5,49,4],
		[93,21,5,49,4],
		[94,21,5,49,4],
		[95,21,5,49,3],
		[96,21,5,49,3],
		[97,21,5,49,3],
		[98,21,5,49,3],
		[99,22,5,49,3],
		[100,22,5,49,3],
		[101,22,5,49,3],
		[102,21,6,49,3],
		[103,21,6,49,3],
		[104,21,6,50,3],
		[105,21,6,50,3],
		[106,21,6,50,3],
		[107,21,6,50,3],
		[108,21,6,50,3],
		[109,21,6,50,3],
		[110,20,6,50,3],
		[111,20,6,50,3],
		[112,20,6,50,3],
		[113,20,6,50,3],
		[114,20,6,50,4],
		[115,20,6,50,4],
		[116,20,6,50,4],
		[117,20,6,49,4],
		[118,20,6,49,4],
		[119,21,5,49,4],
		[120,21,5,49,4],
		[121,22,5,49,4],
		[122,22,5,49,4],
		[123,22,5,49,4],
		[124,22,5,49,4],
		[125,22,5,49,4],
		[126,22,5,49,4],
		[127,22,5,49,4],
		[128,22,5,49,4],
		[129,22,5,49,4],
		[130,22,5,50,4],
		[131,22,5,50,4],
		[132,21,5,50,4],
		[133,21,5,50,3],
		[134,21,5,50,3],
		[135,21,5,50,3],
		[136,20,6,50,3],
		[137,20,6,50,3],
		[138,20,6,50,3],
		[139,20,6,50,3],
		[140,20,6,50,3],
		[141,20,6,50,3],
		[142,24,6,49,4],
		[143,24,6,49,4],
		[144,24,6,49,4],
		[145,21,6,49,3],
		[146,21,6,49,3],
		[147,21,6,49,3],
		[148,21,6,49,3],
		[149,21,6,49,3],
		[150,21,6,49,3],
		[151,21,6,49,3],
		[152,21,6,49,4],
		[153,22,5,49,4],
		[154,21,5,49,4],
		[155,21,5,49,4],
		[156,21,5,50,4],
		[157,21,5,50,4],
		[158,21,5,50,4],
		[159,21,5,50,4],
		[160,21,5,50,4],
		[161,21,5,50,4],
		[162,21,5,50,4],
		[163,21,5,50,4],
		[164,21,5,50,4],
		[165,22,5,50,4],
		[166,22,5,50,4],
		[167,22,5,50,4],
		[168,22,5,50,4],
		[169,22,5,49,4],
		[170,21,6,49,4],
		[171,21,6,49,3],
		[172,21,6,49,3],
		[173,21,6,49,3]
	],
	"houses": [
		{
			"id": 0,
			"name": "제설 차고",
			"rect": [98,64,52,21],
			"walls": [
				[108,65,1,19],
				[139,65,1,19],
				[109,77,16,1],
				[124,78,1,6]
			],
			"doors": [
				[108,67],
				[139,69],
				[117,77],
				[122,64],
				[123,64],
				[133,64]
			],
			"windows": [
				[98,70],
				[98,80],
				[149,71],
				[149,81]
			],
			"rooms": [
				{
					"name": "부품 창고",
					"rect": [99,65,9,19]
				},
				{
					"name": "연료 칸",
					"rect": [140,65,9,19]
				},
				{
					"name": "정비 칸",
					"rect": [109,65,30,12]
				},
				{
					"name": "난로 방",
					"rect": [109,78,15,6]
				}
			],
			"entrances": [
				{
					"cell": [122,64],
					"outward": [0,-1]
				},
				{
					"cell": [133,64],
					"outward": [0,-1]
				}
			]
		},
		{
			"id": 1,
			"name": "고갯마루 오두막",
			"rect": [82,2,24,13],
			"walls": [
				[94,3,1,11]
			],
			"doors": [
				[94,11],
				[86,14]
			],
			"windows": [
				[85,2],
				[102,2],
				[105,6]
			],
			"rooms": [
				{
					"name": "일하던 방",
					"rect": [83,3,11,11]
				},
				{
					"name": "자던 방",
					"rect": [95,3,10,11]
				}
			],
			"entrances": []
		}
	],
	"props": [
		{
			"kind": "garage_door_leaf",
			"rect": [124,64,2,1],
			"solid": "wall",
			"facing": 0,
			"note": "반쯤 닫힌 큰 문짝"
		},
		{
			"kind": "parts_rack",
			"rect": [100,66,4,1],
			"solid": "low",
			"facing": 0,
			"note": "부품 선반"
		},
		{
			"kind": "tool_rack",
			"rect": [100,70,2,1],
			"solid": "low",
			"facing": 0,
			"note": "연장 걸이"
		},
		{
			"kind": "ladder_rack",
			"rect": [100,80,4,1],
			"solid": "low",
			"facing": 0,
			"note": "사다리 걸이"
		},
		{
			"kind": "fuel_drum",
			"rect": [142,66,1,1],
			"solid": "low",
			"facing": 0,
			"note": "연료 드럼"
		},
		{
			"kind": "fuel_drum",
			"rect": [144,67,1,1],
			"solid": "low",
			"facing": 0,
			"note": "연료 드럼"
		},
		{
			"kind": "fuel_drum",
			"rect": [142,69,1,1],
			"solid": "low",
			"facing": 0,
			"note": "연료 드럼"
		},
		{
			"kind": "fuel_tank",
			"rect": [142,79,3,2],
			"solid": "low",
			"facing": 0,
			"note": "연료 탱크"
		},
		{
			"kind": "inspection_pit",
			"rect": [112,66,14,2],
			"solid": "none",
			"facing": 0,
			"note": "검수 구덩이 틀"
		},
		{
			"kind": "tool_bench",
			"rect": [110,73,2,1],
			"solid": "low",
			"facing": 0,
			"note": "연장 작업대"
		},
		{
			"kind": "tool_rack",
			"rect": [129,71,2,1],
			"solid": "low",
			"facing": 0,
			"note": "연장 걸이"
		},
		{
			"kind": "siding_buffer",
			"rect": [127,69,2,3],
			"solid": "low",
			"facing": 0,
			"note": "측선 끝 차막이"
		},
		{
			"kind": "generator",
			"rect": [131,73,2,1],
			"solid": "low",
			"facing": 0,
			"note": "발전기"
		},
		{
			"kind": "bed",
			"rect": [110,80,2,1],
			"solid": "low",
			"facing": 0,
			"note": "침대"
		},
		{
			"kind": "shelf",
			"rect": [118,82,3,1],
			"solid": "low",
			"facing": 0,
			"note": "선반"
		},
		{
			"kind": "firewood_pile",
			"rect": [121,80,2,1],
			"solid": "low",
			"facing": 0,
			"note": "장작 더미"
		},
		{
			"kind": "desk",
			"rect": [84,4,2,1],
			"solid": "low",
			"facing": 0,
			"note": "책상"
		},
		{
			"kind": "radio_set",
			"rect": [88,4,2,1],
			"solid": "low",
			"facing": 0,
			"note": "무전기 책상"
		},
		{
			"kind": "map_cabinet",
			"rect": [84,8,3,1],
			"solid": "low",
			"facing": 0,
			"note": "도면 서랍장"
		},
		{
			"kind": "bed",
			"rect": [96,4,2,1],
			"solid": "low",
			"facing": 0,
			"note": "침대"
		},
		{
			"kind": "shelf",
			"rect": [96,8,3,1],
			"solid": "low",
			"facing": 0,
			"note": "선반"
		},
		{
			"kind": "fuel_can_group",
			"rect": [100,6,2,1],
			"solid": "low",
			"facing": 0,
			"note": "연료통 무리"
		},
		{
			"kind": "tool_rack",
			"rect": [109,4,2,1],
			"solid": "low",
			"facing": 0,
			"note": "연장 걸이"
		},
		{
			"kind": "fuel_can_group",
			"rect": [112,6,2,1],
			"solid": "low",
			"facing": 0,
			"note": "연료통 무리"
		},
		{
			"kind": "firewood_pile",
			"rect": [109,9,2,1],
			"solid": "low",
			"facing": 0,
			"note": "장작 더미"
		},
		{
			"kind": "wind_pole",
			"rect": [115,4,1,1],
			"solid": "none",
			"facing": 0,
			"note": "바람 깃 장대"
		},
		{
			"kind": "snow_gauge_pole",
			"rect": [114,10,1,1],
			"solid": "none",
			"facing": 0,
			"note": "눈금 장대"
		},
		{
			"kind": "crate_stack",
			"rect": [54,30,2,2],
			"solid": "low",
			"facing": 0,
			"note": "자재 상자 더미"
		},
		{
			"kind": "rail_stack",
			"rect": [85,31,4,1],
			"solid": "low",
			"facing": 0,
			"note": "레일 토막 더미"
		},
		{
			"kind": "snow_bank",
			"rect": [98,31,6,1],
			"solid": "low",
			"facing": 0,
			"note": "눈 둑"
		},
		{
			"kind": "fallen_signal",
			"rect": [123,29,1,5],
			"solid": "low",
			"facing": 1,
			"note": "쓰러진 신호기"
		},
		{
			"kind": "snow_bank",
			"rect": [54,49,6,1],
			"solid": "low",
			"facing": 0,
			"note": "눈 둑"
		},
		{
			"kind": "crate_stack",
			"rect": [94,49,2,2],
			"solid": "low",
			"facing": 0,
			"note": "자재 상자 더미"
		},
		{
			"kind": "plow_blade",
			"rect": [98,49,4,2],
			"solid": "low",
			"facing": 0,
			"note": "떼어 둔 제설 날"
		},
		{
			"kind": "sleeper_stack",
			"rect": [117,45,1,3],
			"solid": "low",
			"facing": 1,
			"note": "침목 더미"
		},
		{
			"kind": "handcart",
			"rect": [152,67,2,1],
			"solid": "low",
			"facing": 0,
			"note": "짐수레"
		},
		{
			"kind": "tool_rack",
			"rect": [155,69,2,1],
			"solid": "low",
			"facing": 0,
			"note": "연장 걸이"
		},
		{
			"kind": "snowplow_truck",
			"rect": [152,72,6,3],
			"solid": "wall",
			"facing": 0,
			"note": "제설차"
		},
		{
			"kind": "fuel_drum",
			"rect": [153,77,1,1],
			"solid": "low",
			"facing": 0,
			"note": "연료 드럼"
		},
		{
			"kind": "fuel_drum",
			"rect": [155,78,1,1],
			"solid": "low",
			"facing": 0,
			"note": "연료 드럼"
		},
		{
			"kind": "fuel_drum",
			"rect": [157,77,1,1],
			"solid": "low",
			"facing": 0,
			"note": "연료 드럼"
		},
		{
			"kind": "track_switch",
			"rect": [12,34,2,1],
			"solid": "none",
			"facing": 0,
			"note": "선로 전환기"
		},
		{
			"kind": "signal_post",
			"rect": [16,32,1,1],
			"solid": "wall",
			"facing": 0,
			"note": "기둥 신호등"
		},
		{
			"kind": "rail_marker",
			"rect": [18,34,1,1],
			"solid": "none",
			"facing": 0,
			"note": "거리 말뚝"
		},
		{
			"kind": "power_pole",
			"rect": [21,31,1,1],
			"solid": "wall",
			"facing": 0,
			"note": "전신주"
		},
		{
			"kind": "snow_drift",
			"rect": [10,30,4,2],
			"solid": "none",
			"facing": 0,
			"note": "눈더미"
		},
		{
			"kind": "rock_face",
			"rect": [2,20,6,3],
			"solid": "wall",
			"facing": 0,
			"note": "암벽 면"
		},
		{
			"kind": "rock_ridge",
			"rect": [146,0,8,6],
			"solid": "wall",
			"facing": 0,
			"note": "산 능선"
		},
		{
			"kind": "snow_drift",
			"rect": [141,6,4,2],
			"solid": "none",
			"facing": 0,
			"note": "눈더미"
		},
		{
			"kind": "rail_plow",
			"rect": [88,55,12,3],
			"solid": "wall",
			"facing": 0,
			"note": "식은 제설기"
		},
		{
			"kind": "fallen_log",
			"rect": [36,49,5,1],
			"solid": "low",
			"facing": 0,
			"note": "쓰러진 통나무"
		}
	],
	"trees": [
		[119,1],
		[47,84],
		[51,82],
		[158,3],
		[54,83],
		[10,80],
		[113,1],
		[29,1],
		[21,6],
		[24,0],
		[25,82],
		[19,5],
		[168,2],
		[54,80],
		[64,82],
		[9,83],
		[66,83],
		[162,2],
		[19,84],
		[152,6],
		[28,4],
		[159,4],
		[40,2],
		[167,3],
		[122,4],
		[125,6],
		[123,0],
		[59,85],
		[62,83],
		[133,2],
		[30,2],
		[163,5],
		[17,1],
		[117,2],
		[129,1],
		[131,3],
		[150,7],
		[46,81],
		[20,83],
		[37,5],
		[24,4],
		[11,80],
		[116,4],
		[116,6],
		[19,80],
		[18,3],
		[22,4],
		[59,84],
		[166,2],
		[14,82],
		[9,80],
		[127,6],
		[10,79],
		[27,3],
		[28,81],
		[8,80],
		[27,84],
		[129,0],
		[31,4],
		[118,3],
		[55,81],
		[8,82],
		[23,0],
		[156,8],
		[28,3],
		[48,81],
		[45,80],
		[39,4],
		[46,83],
		[21,0],
		[126,0],
		[129,6],
		[58,82],
		[67,82],
		[16,4],
		[160,3],
		[54,79],
		[21,5],
		[49,84],
		[171,4],
		[165,8],
		[127,5],
		[154,8],
		[8,79],
		[119,4],
		[48,85],
		[35,4],
		[112,2],
		[37,3],
		[153,8]
	],
	"gates": [
		[29,30,1,3],
		[29,46,1,3],
		[143,30,1,3],
		[143,46,1,3]
	],
	"stores": [
		{
			"id": "shed_parts",
			"name": "안쪽 부품함",
			"cell": [100,82],
			"level": 0,
			"items": ["cloth","flare"]
		},
		{
			"id": "shed_fuel",
			"name": "연료 칸 보급함",
			"cell": [147,82],
			"level": 0,
			"items": ["cloth","flare"]
		},
		{
			"id": "shed_tools",
			"name": "정비 공구함",
			"cell": [131,67],
			"level": 0,
			"items": ["plank","bandage"]
		},
		{
			"id": "shed_food",
			"name": "난로 방 찬장",
			"cell": [115,82],
			"level": 0,
			"items": ["food_pack","cloth"]
		},
		{
			"id": "below_parts",
			"name": "지하 부품함",
			"cell": [123,67],
			"level": -1,
			"items": ["plank","bandage"]
		},
		{
			"id": "below_supply",
			"name": "지하 예비함",
			"cell": [127,74],
			"level": -1,
			"items": ["bandage","document"]
		},
		{
			"id": "hut_radio_notes",
			"name": "무전 기록함",
			"cell": [84,6],
			"level": 0,
			"items": ["document"]
		},
		{
			"id": "hut_engine_notes",
			"name": "기관 도면함",
			"cell": [88,6],
			"level": 0,
			"items": ["document"]
		},
		{
			"id": "hut_supply",
			"name": "오두막 보급함",
			"cell": [96,12],
			"level": 0,
			"items": ["food_pack","bandage"]
		}
	],
	"salvage": [
		{
			"id": "plow_drive_1",
			"name": "제설기 구동부",
			"cell": [87,55],
			"material": "scrap",
			"amount": 2
		},
		{
			"id": "plow_drive_2",
			"name": "제설기 구동부",
			"cell": [100,55],
			"material": "scrap",
			"amount": 2
		},
		{
			"id": "plow_drive_3",
			"name": "제설기 구동부",
			"cell": [88,58],
			"material": "scrap",
			"amount": 2
		},
		{
			"id": "plow_drive_4",
			"name": "제설기 구동부",
			"cell": [99,58],
			"material": "scrap",
			"amount": 2
		},
		{
			"id": "shallow_sleepers",
			"name": "선로 곁 침목",
			"cell": [116,45],
			"material": "wood",
			"amount": 3
		},
		{
			"id": "shallow_rails",
			"name": "선로 곁 레일 토막",
			"cell": [84,31],
			"material": "scrap",
			"amount": 2
		},
		{
			"id": "shallow_log",
			"name": "벽 밑 쓰러진 나무",
			"cell": [35,45],
			"material": "wood",
			"amount": 2
		}
	],
	"stoves": [
		{
			"cell": [113,82],
			"building": 0
		},
		{
			"cell": [100,12],
			"building": 1
		}
	],
	"entries": {
		"track_west_upper": [
			[0,35],
			[0,36],
			[0,37]
		],
		"track_east_upper": [
			[173,35],
			[173,36],
			[173,37]
		],
		"track_west_lower": [
			[0,41],
			[0,42],
			[0,43]
		],
		"track_east_lower": [
			[173,41],
			[173,42],
			[173,43]
		],
		"access_road": [
			[83,85],
			[84,85],
			[85,85]
		],
		"ridge_path": [
			[94,0],
			[95,0]
		]
	},
	"dead_shed": [
		[110,66],
		[111,68],
		[126,73],
		[130,69],
		[132,71],
		[104,73],
		[105,76],
		[146,72],
		[116,80],
		[120,79]
	],
	"dead_ridge": [
		[116,7],
		[118,8],
		[120,9]
	],
	"yard": [
		[82,49,68,15]
	],
	"ramp": [
		[116,16,3,22],
		[86,16,33,2]
	],
	"cut": {
		"side": 1,
		"x": 82,
		"width": 26
	},
	"slope": {
		"side": 0,
		"x": 116,
		"width": 3
	},
	"underground": {
		"stairs": [126,67],
		"digs": [
			[122,66,8,4],
			[124,70,2,2],
			[122,72,8,4]
		],
		"rooms": [
			{
				"name": "지하 작은 부품 칸",
				"rect": [122,66,8,4]
			},
			{
				"name": "지하 큰 부품 칸",
				"rect": [122,72,8,4]
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
