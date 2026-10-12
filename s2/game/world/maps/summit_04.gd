# 이 지도가 다른 판단을 만드는 것: 양 끝 목을 막아도 도로와 비탈길이 목 안쪽으로 이어진다. 가운데 넓은 바닥에서 안쪽 진입을 함께 맡는다.
extends RefCounted
## 칸 계획은 이 파일에서만 조립한다. 윗층은 없고 정비 구덩이 아래만 판다.
const FieldGrid = preload("res://game/world/field_grid.gd")
const S = FieldGrid.Solid
const F = FieldGrid.Floor
const WIDTH: int = 178
const HEIGHT: int = 88
const PLACE_ID: String = "summit_04"
const ZONE_NAMES: Dictionary = {"cut_floor":"선로 바닥","plow_shed":"제설 차고","ledge_hut":"턱 위 오두막","ridge_edge":"능선 가장자리"}
const ENTRY_NAMES: Dictionary = {"track_west_upper":"서쪽 선로, 오두막 쪽","track_east_upper":"동쪽 선로, 오두막 쪽","track_west_lower":"서쪽 선로, 차고 쪽","track_east_lower":"동쪽 선로, 차고 쪽","access_road":"진입 도로","ridge_path":"능선 길"}
const ENTRY_WEIGHTS: Dictionary = {"track_west_upper":2,"track_east_upper":2,"track_west_lower":2,"track_east_lower":2,"access_road":1.5,"ridge_path":0.5}
const FIRST_ENTRY: String = "track_east_lower"
const PLAN: Dictionary = {
	"id": 4,
	"w": 178,
	"h": 88,
	"judgment": "양 끝 목을 막아도 도로와 비탈길이 목 안쪽으로 이어진다. 가운데 넓은 바닥에서 안쪽 진입을 함께 맡는다.",
	"train": [49,40,80,3],
	"shed_up": false,
	"bands": [
		[29,18,120,22],
		[29,43,120,22]
	],
	"floors": [
		{
			"rect": [0,8,24,2],
			"kind": 5
		},
		{
			"rect": [0,78,24,2],
			"kind": 7
		},
		{
			"rect": [10,2,2,7],
			"kind": 5
		},
		{
			"rect": [16,78,2,10],
			"kind": 7
		},
		{
			"rect": [22,10,24,2],
			"kind": 5
		},
		{
			"rect": [22,76,24,2],
			"kind": 7
		},
		{
			"rect": [32,2,2,9],
			"kind": 5
		},
		{
			"rect": [38,76,2,12],
			"kind": 7
		},
		{
			"rect": [44,6,24,2],
			"kind": 5
		},
		{
			"rect": [44,80,24,2],
			"kind": 7
		},
		{
			"rect": [54,2,2,5],
			"kind": 5
		},
		{
			"rect": [60,80,2,8],
			"kind": 7
		},
		{
			"rect": [66,8,24,2],
			"kind": 5
		},
		{
			"rect": [66,78,24,2],
			"kind": 7
		},
		{
			"rect": [76,2,2,7],
			"kind": 5
		},
		{
			"rect": [82,78,2,10],
			"kind": 7
		},
		{
			"rect": [88,10,24,2],
			"kind": 5
		},
		{
			"rect": [88,76,24,2],
			"kind": 7
		},
		{
			"rect": [98,2,2,9],
			"kind": 5
		},
		{
			"rect": [104,76,2,12],
			"kind": 7
		},
		{
			"rect": [110,6,24,2],
			"kind": 5
		},
		{
			"rect": [110,80,24,2],
			"kind": 7
		},
		{
			"rect": [120,2,2,5],
			"kind": 5
		},
		{
			"rect": [126,80,2,8],
			"kind": 7
		},
		{
			"rect": [132,8,24,2],
			"kind": 5
		},
		{
			"rect": [132,78,24,2],
			"kind": 7
		},
		{
			"rect": [142,2,2,7],
			"kind": 5
		},
		{
			"rect": [148,78,2,10],
			"kind": 7
		},
		{
			"rect": [154,10,24,2],
			"kind": 5
		},
		{
			"rect": [154,76,24,2],
			"kind": 7
		},
		{
			"rect": [164,2,2,9],
			"kind": 5
		},
		{
			"rect": [170,76,2,12],
			"kind": 7
		},
		{
			"rect": [176,6,2,2],
			"kind": 5
		},
		{
			"rect": [176,80,2,2],
			"kind": 7
		},
		{
			"rect": [176,2,2,5],
			"kind": 5
		},
		{
			"rect": [176,80,2,8],
			"kind": 7
		},
		{
			"rect": [113,54,59,12],
			"kind": 7
		},
		{
			"rect": [41,47,79,2],
			"kind": 4
		},
		{
			"rect": [117,47,2,9],
			"kind": 4
		},
		{
			"rect": [133,24,3,16],
			"kind": 5
		},
		{
			"rect": [10,18,126,2],
			"kind": 5
		},
		{
			"rect": [9,4,3,27],
			"kind": 5
		},
		{
			"rect": [175,62,3,26],
			"kind": 1
		},
		{
			"rect": [121,62,57,3],
			"kind": 1
		},
		{
			"rect": [121,47,3,18],
			"kind": 1
		},
		{
			"rect": [18,0,2,19],
			"kind": 5
		},
		{
			"rect": [0,37,178,3],
			"kind": 7
		},
		{
			"rect": [0,43,178,3],
			"kind": 7
		},
		{
			"rect": [0,40,178,3],
			"kind": 4
		},
		{
			"rect": [117,46,2,2],
			"kind": 4
		},
		{
			"rect": [133,18,3,6],
			"kind": 5
		}
	],
	"rocks": [
		[31,37,2,1],
		[31,45,2,1],
		[145,37,2,1],
		[145,45,2,1],
		[0,29,1,3],
		[0,54,1,5],
		[1,29,1,3],
		[1,54,1,5],
		[2,29,1,3],
		[2,54,1,5],
		[3,29,1,3],
		[3,54,1,5],
		[4,29,1,3],
		[4,54,1,5],
		[5,29,1,3],
		[5,54,1,5],
		[6,29,1,3],
		[6,54,1,5],
		[7,29,1,3],
		[7,54,1,5],
		[8,29,1,3],
		[8,54,1,5],
		[9,29,1,3],
		[9,54,1,5],
		[10,29,1,3],
		[10,54,1,5],
		[11,28,1,3],
		[11,54,1,5],
		[12,28,1,3],
		[12,54,1,5],
		[13,28,1,3],
		[13,55,1,5],
		[14,28,1,3],
		[14,55,1,5],
		[15,28,1,3],
		[15,55,1,5],
		[16,28,1,3],
		[16,55,1,5],
		[17,27,1,4],
		[17,55,1,5],
		[18,27,1,4],
		[18,55,1,5],
		[19,27,1,4],
		[19,55,1,6],
		[20,27,1,4],
		[20,55,1,6],
		[21,27,1,4],
		[21,55,1,6],
		[22,28,1,4],
		[22,55,1,6],
		[23,28,1,4],
		[23,55,1,6],
		[24,28,1,4],
		[24,55,1,6],
		[25,28,1,4],
		[25,55,1,6],
		[26,28,1,4],
		[26,54,1,6],
		[27,28,1,4],
		[27,54,1,6],
		[28,28,1,4],
		[28,54,1,6],
		[29,28,1,4],
		[29,54,1,6],
		[30,30,1,4],
		[30,49,1,6],
		[31,30,1,4],
		[31,49,1,6],
		[32,30,1,4],
		[32,49,1,6],
		[33,27,1,4],
		[33,54,1,6],
		[34,28,1,3],
		[34,54,1,6],
		[35,28,1,3],
		[35,54,1,6],
		[36,28,1,3],
		[36,54,1,6],
		[37,28,1,3],
		[37,54,1,6],
		[38,28,1,3],
		[38,54,1,5],
		[39,28,1,3],
		[39,55,1,5],
		[40,28,1,3],
		[40,55,1,5],
		[41,28,1,3],
		[41,55,1,5],
		[42,28,1,3],
		[42,55,1,5],
		[43,28,1,3],
		[43,55,1,5],
		[44,29,1,3],
		[44,55,1,5],
		[45,29,1,3],
		[45,55,1,5],
		[46,29,1,3],
		[46,55,1,5],
		[47,29,1,3],
		[47,55,1,5],
		[48,29,1,3],
		[48,55,1,5],
		[49,29,1,3],
		[49,55,1,5],
		[50,29,1,3],
		[50,55,1,5],
		[51,28,1,4],
		[51,55,1,5],
		[52,28,1,4],
		[52,54,1,5],
		[53,28,1,4],
		[53,54,1,5],
		[54,28,1,4],
		[54,54,1,5],
		[55,27,1,4],
		[55,54,1,5],
		[56,27,1,4],
		[56,54,1,5],
		[57,27,1,4],
		[57,54,1,6],
		[58,27,1,4],
		[58,54,1,6],
		[59,27,1,4],
		[59,54,1,6],
		[60,27,1,4],
		[60,54,1,6],
		[61,27,1,4],
		[61,54,1,6],
		[62,27,1,4],
		[62,54,1,6],
		[63,27,1,4],
		[63,54,1,6],
		[64,27,1,4],
		[64,54,1,6],
		[65,27,1,4],
		[65,55,1,6],
		[66,28,1,4],
		[66,55,1,6],
		[67,28,1,4],
		[67,55,1,6],
		[68,29,1,3],
		[68,55,1,6],
		[69,29,1,3],
		[69,55,1,6],
		[70,29,1,3],
		[70,55,1,6],
		[71,29,1,3],
		[71,55,1,6],
		[72,29,1,3],
		[72,55,1,6],
		[73,29,1,3],
		[73,55,1,6],
		[74,29,1,3],
		[74,55,1,6],
		[75,29,1,3],
		[75,55,1,6],
		[76,29,1,3],
		[76,55,1,5],
		[77,28,1,3],
		[77,55,1,5],
		[78,28,1,3],
		[78,54,1,5],
		[79,28,1,3],
		[79,54,1,5],
		[80,28,1,3],
		[80,54,1,5],
		[81,28,1,3],
		[81,54,1,5],
		[82,28,1,3],
		[82,54,1,5],
		[83,28,1,3],
		[83,54,1,5],
		[84,28,1,3],
		[84,54,1,5],
		[85,27,1,4],
		[85,54,1,5],
		[86,27,1,4],
		[86,54,1,5],
		[87,27,1,4],
		[87,54,1,5],
		[88,28,1,4],
		[88,54,1,5],
		[89,28,1,4],
		[89,54,1,5],
		[90,28,1,4],
		[90,54,1,5],
		[91,28,1,4],
		[91,55,1,5],
		[92,28,1,4],
		[92,55,1,5],
		[93,28,1,4],
		[93,55,1,5],
		[94,28,1,4],
		[94,55,1,5],
		[95,28,1,4],
		[95,55,1,6],
		[96,28,1,4],
		[96,55,1,6],
		[97,28,1,4],
		[97,55,1,6],
		[98,28,1,4],
		[98,55,1,6],
		[99,27,1,4],
		[99,55,1,6],
		[100,27,1,4],
		[100,55,1,6],
		[101,27,1,4],
		[101,55,1,6],
		[102,28,1,3],
		[102,55,1,6],
		[103,28,1,3],
		[103,55,1,6],
		[104,28,1,3],
		[104,54,1,6],
		[105,28,1,3],
		[105,54,1,6],
		[106,28,1,3],
		[106,54,1,6],
		[107,28,1,3],
		[107,54,1,6],
		[108,28,1,3],
		[108,54,1,6],
		[109,28,1,3],
		[109,54,1,6],
		[110,29,1,3],
		[110,54,1,6],
		[111,29,1,3],
		[111,54,1,6],
		[112,29,1,3],
		[112,54,1,6],
		[113,29,1,3],
		[114,29,1,3],
		[115,29,1,3],
		[116,29,1,3],
		[117,29,1,3],
		[118,29,1,3],
		[119,28,1,4],
		[120,28,1,4],
		[121,27,1,4],
		[122,27,1,4],
		[123,27,1,4],
		[124,27,1,4],
		[125,27,1,4],
		[126,27,1,4],
		[127,27,1,4],
		[128,27,1,4],
		[129,27,1,4],
		[130,27,1,4],
		[131,27,1,4],
		[132,28,1,4],
		[136,29,1,3],
		[137,29,1,3],
		[138,29,1,3],
		[139,29,1,3],
		[139,54,1,6],
		[140,29,1,3],
		[140,54,1,6],
		[141,29,1,3],
		[141,54,1,6],
		[142,29,1,3],
		[142,54,1,6],
		[143,28,1,3],
		[143,55,1,6],
		[144,30,1,4],
		[144,49,1,6],
		[145,30,1,4],
		[145,49,1,6],
		[146,30,1,4],
		[146,49,1,6],
		[147,28,1,3],
		[147,55,1,6],
		[148,28,1,3],
		[148,55,1,6],
		[149,28,1,3],
		[149,55,1,6],
		[150,28,1,3],
		[150,55,1,6],
		[151,28,1,3],
		[151,55,1,6],
		[152,28,1,3],
		[152,55,1,5],
		[153,27,1,4],
		[153,55,1,5],
		[154,28,1,4],
		[154,55,1,5],
		[155,28,1,4],
		[155,55,1,5],
		[156,28,1,4],
		[156,54,1,5],
		[157,28,1,4],
		[157,54,1,5],
		[158,28,1,4],
		[158,54,1,5],
		[159,28,1,4],
		[159,54,1,5],
		[160,28,1,4],
		[160,54,1,5],
		[161,28,1,4],
		[161,54,1,5],
		[162,28,1,4],
		[162,54,1,5],
		[163,28,1,4],
		[163,54,1,5],
		[164,28,1,4],
		[164,54,1,5],
		[165,27,1,4],
		[165,54,1,5],
		[166,27,1,4],
		[166,54,1,5],
		[167,27,1,4],
		[167,54,1,5],
		[168,27,1,4],
		[168,54,1,5],
		[169,27,1,4],
		[169,55,1,5],
		[170,28,1,3],
		[170,55,1,5],
		[171,28,1,3],
		[171,55,1,6],
		[172,28,1,3],
		[172,55,1,6],
		[173,28,1,3],
		[173,55,1,6],
		[174,28,1,3],
		[174,55,1,6],
		[175,28,1,3],
		[175,55,1,6],
		[176,29,1,3],
		[176,55,1,6],
		[177,29,1,3],
		[177,55,1,6]
	],
	"wall_columns": [
		[0,29,3,54,5],
		[1,29,3,54,5],
		[2,29,3,54,5],
		[3,29,3,54,5],
		[4,29,3,54,5],
		[5,29,3,54,5],
		[6,29,3,54,5],
		[7,29,3,54,5],
		[8,29,3,54,5],
		[9,29,3,54,5],
		[10,29,3,54,5],
		[11,28,3,54,5],
		[12,28,3,54,5],
		[13,28,3,55,5],
		[14,28,3,55,5],
		[15,28,3,55,5],
		[16,28,3,55,5],
		[17,27,4,55,5],
		[18,27,4,55,5],
		[19,27,4,55,6],
		[20,27,4,55,6],
		[21,27,4,55,6],
		[22,28,4,55,6],
		[23,28,4,55,6],
		[24,28,4,55,6],
		[25,28,4,55,6],
		[26,28,4,54,6],
		[27,28,4,54,6],
		[28,28,4,54,6],
		[29,28,4,54,6],
		[30,30,4,49,6],
		[31,30,4,49,6],
		[32,30,4,49,6],
		[33,27,4,54,6],
		[34,28,3,54,6],
		[35,28,3,54,6],
		[36,28,3,54,6],
		[37,28,3,54,6],
		[38,28,3,54,5],
		[39,28,3,55,5],
		[40,28,3,55,5],
		[41,28,3,55,5],
		[42,28,3,55,5],
		[43,28,3,55,5],
		[44,29,3,55,5],
		[45,29,3,55,5],
		[46,29,3,55,5],
		[47,29,3,55,5],
		[48,29,3,55,5],
		[49,29,3,55,5],
		[50,29,3,55,5],
		[51,28,4,55,5],
		[52,28,4,54,5],
		[53,28,4,54,5],
		[54,28,4,54,5],
		[55,27,4,54,5],
		[56,27,4,54,5],
		[57,27,4,54,6],
		[58,27,4,54,6],
		[59,27,4,54,6],
		[60,27,4,54,6],
		[61,27,4,54,6],
		[62,27,4,54,6],
		[63,27,4,54,6],
		[64,27,4,54,6],
		[65,27,4,55,6],
		[66,28,4,55,6],
		[67,28,4,55,6],
		[68,29,3,55,6],
		[69,29,3,55,6],
		[70,29,3,55,6],
		[71,29,3,55,6],
		[72,29,3,55,6],
		[73,29,3,55,6],
		[74,29,3,55,6],
		[75,29,3,55,6],
		[76,29,3,55,5],
		[77,28,3,55,5],
		[78,28,3,54,5],
		[79,28,3,54,5],
		[80,28,3,54,5],
		[81,28,3,54,5],
		[82,28,3,54,5],
		[83,28,3,54,5],
		[84,28,3,54,5],
		[85,27,4,54,5],
		[86,27,4,54,5],
		[87,27,4,54,5],
		[88,28,4,54,5],
		[89,28,4,54,5],
		[90,28,4,54,5],
		[91,28,4,55,5],
		[92,28,4,55,5],
		[93,28,4,55,5],
		[94,28,4,55,5],
		[95,28,4,55,6],
		[96,28,4,55,6],
		[97,28,4,55,6],
		[98,28,4,55,6],
		[99,27,4,55,6],
		[100,27,4,55,6],
		[101,27,4,55,6],
		[102,28,3,55,6],
		[103,28,3,55,6],
		[104,28,3,54,6],
		[105,28,3,54,6],
		[106,28,3,54,6],
		[107,28,3,54,6],
		[108,28,3,54,6],
		[109,28,3,54,6],
		[110,29,3,54,6],
		[111,29,3,54,6],
		[112,29,3,54,6],
		[113,29,3,54,6],
		[114,29,3,54,5],
		[115,29,3,54,5],
		[116,29,3,54,5],
		[117,29,3,55,5],
		[118,29,3,55,5],
		[119,28,4,55,5],
		[120,28,4,55,5],
		[121,27,4,55,5],
		[122,27,4,55,5],
		[123,27,4,55,5],
		[124,27,4,55,5],
		[125,27,4,55,5],
		[126,27,4,55,5],
		[127,27,4,55,5],
		[128,27,4,55,5],
		[129,27,4,55,5],
		[130,27,4,54,5],
		[131,27,4,54,5],
		[132,28,4,54,5],
		[133,28,4,54,6],
		[134,28,4,54,6],
		[135,28,4,54,6],
		[136,29,3,54,6],
		[137,29,3,54,6],
		[138,29,3,54,6],
		[139,29,3,54,6],
		[140,29,3,54,6],
		[141,29,3,54,6],
		[142,29,3,54,6],
		[143,28,3,55,6],
		[144,30,4,49,6],
		[145,30,4,49,6],
		[146,30,4,49,6],
		[147,28,3,55,6],
		[148,28,3,55,6],
		[149,28,3,55,6],
		[150,28,3,55,6],
		[151,28,3,55,6],
		[152,28,3,55,5],
		[153,27,4,55,5],
		[154,28,4,55,5],
		[155,28,4,55,5],
		[156,28,4,54,5],
		[157,28,4,54,5],
		[158,28,4,54,5],
		[159,28,4,54,5],
		[160,28,4,54,5],
		[161,28,4,54,5],
		[162,28,4,54,5],
		[163,28,4,54,5],
		[164,28,4,54,5],
		[165,27,4,54,5],
		[166,27,4,54,5],
		[167,27,4,54,5],
		[168,27,4,54,5],
		[169,27,4,55,5],
		[170,28,3,55,5],
		[171,28,3,55,6],
		[172,28,3,55,6],
		[173,28,3,55,6],
		[174,28,3,55,6],
		[175,28,3,55,6],
		[176,29,3,55,6],
		[177,29,3,55,6]
	],
	"houses": [
		{
			"id": 0,
			"name": "제설 차고",
			"rect": [120,66,52,21],
			"walls": [
				[130,67,1,19],
				[161,67,1,19],
				[131,79,16,1],
				[146,80,1,6]
			],
			"doors": [
				[130,69],
				[161,71],
				[139,79],
				[144,66],
				[145,66],
				[155,66]
			],
			"windows": [
				[120,72],
				[120,82],
				[171,73],
				[171,83]
			],
			"rooms": [
				{
					"name": "부품 창고",
					"rect": [121,67,9,19]
				},
				{
					"name": "연료 칸",
					"rect": [162,67,9,19]
				},
				{
					"name": "정비 칸",
					"rect": [131,67,30,12]
				},
				{
					"name": "난로 방",
					"rect": [131,80,15,6]
				}
			],
			"entrances": [
				{
					"cell": [144,66],
					"outward": [0,-1]
				},
				{
					"cell": [155,66],
					"outward": [0,-1]
				}
			]
		},
		{
			"id": 1,
			"name": "고갯마루 오두막",
			"rect": [6,4,22,13],
			"walls": [
				[17,5,1,11]
			],
			"doors": [
				[17,13],
				[10,16]
			],
			"windows": [
				[9,4],
				[24,4],
				[27,8]
			],
			"rooms": [
				{
					"name": "일하던 방",
					"rect": [7,5,10,11]
				},
				{
					"name": "자던 방",
					"rect": [18,5,9,11]
				}
			],
			"entrances": []
		},
		{
			"id": 2,
			"name": "자재 헛간",
			"rect": [72,70,18,13],
			"walls": [
				[81,71,1,11]
			],
			"doors": [
				[81,79],
				[76,82]
			],
			"windows": [
				[75,70],
				[86,70],
				[89,74]
			],
			"rooms": [
				{
					"name": "연장 칸",
					"rect": [73,71,8,11]
				},
				{
					"name": "자재 칸",
					"rect": [82,71,7,11]
				}
			],
			"entrances": []
		}
	],
	"props": [
		{
			"kind": "garage_door_leaf",
			"rect": [146,66,2,1],
			"solid": "wall",
			"facing": 0,
			"note": "반쯤 닫힌 큰 문짝"
		},
		{
			"kind": "parts_rack",
			"rect": [122,68,4,1],
			"solid": "low",
			"facing": 0,
			"note": "부품 선반"
		},
		{
			"kind": "tool_rack",
			"rect": [122,72,2,1],
			"solid": "low",
			"facing": 0,
			"note": "연장 걸이"
		},
		{
			"kind": "ladder_rack",
			"rect": [122,82,4,1],
			"solid": "low",
			"facing": 0,
			"note": "사다리 걸이"
		},
		{
			"kind": "fuel_drum",
			"rect": [164,68,1,1],
			"solid": "low",
			"facing": 0,
			"note": "연료 드럼"
		},
		{
			"kind": "fuel_drum",
			"rect": [166,69,1,1],
			"solid": "low",
			"facing": 0,
			"note": "연료 드럼"
		},
		{
			"kind": "fuel_drum",
			"rect": [164,71,1,1],
			"solid": "low",
			"facing": 0,
			"note": "연료 드럼"
		},
		{
			"kind": "fuel_tank",
			"rect": [164,81,3,2],
			"solid": "low",
			"facing": 0,
			"note": "연료 탱크"
		},
		{
			"kind": "inspection_pit",
			"rect": [134,68,14,2],
			"solid": "none",
			"facing": 0,
			"note": "검수 구덩이 틀"
		},
		{
			"kind": "tool_bench",
			"rect": [132,75,2,1],
			"solid": "low",
			"facing": 0,
			"note": "연장 작업대"
		},
		{
			"kind": "tool_rack",
			"rect": [151,73,2,1],
			"solid": "low",
			"facing": 0,
			"note": "연장 걸이"
		},
		{
			"kind": "siding_buffer",
			"rect": [149,71,2,3],
			"solid": "low",
			"facing": 0,
			"note": "측선 끝 차막이"
		},
		{
			"kind": "generator",
			"rect": [153,75,2,1],
			"solid": "low",
			"facing": 0,
			"note": "발전기"
		},
		{
			"kind": "rail_plow",
			"rect": [135,71,12,3],
			"solid": "wall",
			"facing": 0,
			"note": "식은 제설기"
		},
		{
			"kind": "bed",
			"rect": [132,82,2,1],
			"solid": "low",
			"facing": 0,
			"note": "침대"
		},
		{
			"kind": "shelf",
			"rect": [140,84,3,1],
			"solid": "low",
			"facing": 0,
			"note": "선반"
		},
		{
			"kind": "firewood_pile",
			"rect": [143,82,2,1],
			"solid": "low",
			"facing": 0,
			"note": "장작 더미"
		},
		{
			"kind": "desk",
			"rect": [8,6,2,1],
			"solid": "low",
			"facing": 0,
			"note": "책상"
		},
		{
			"kind": "radio_set",
			"rect": [12,6,2,1],
			"solid": "low",
			"facing": 0,
			"note": "무전기 책상"
		},
		{
			"kind": "map_cabinet",
			"rect": [8,10,3,1],
			"solid": "low",
			"facing": 0,
			"note": "도면 서랍장"
		},
		{
			"kind": "bed",
			"rect": [19,6,2,1],
			"solid": "low",
			"facing": 0,
			"note": "침대"
		},
		{
			"kind": "shelf",
			"rect": [19,10,3,1],
			"solid": "low",
			"facing": 0,
			"note": "선반"
		},
		{
			"kind": "fuel_can_group",
			"rect": [23,8,2,1],
			"solid": "low",
			"facing": 0,
			"note": "연료통 무리"
		},
		{
			"kind": "tool_rack",
			"rect": [74,72,2,1],
			"solid": "low",
			"facing": 0,
			"note": "연장 걸이"
		},
		{
			"kind": "ladder_rack",
			"rect": [74,75,4,1],
			"solid": "low",
			"facing": 0,
			"note": "사다리 걸이"
		},
		{
			"kind": "parts_rack",
			"rect": [83,72,4,1],
			"solid": "low",
			"facing": 0,
			"note": "부품 선반"
		},
		{
			"kind": "sled_load",
			"rect": [83,76,2,1],
			"solid": "low",
			"facing": 0,
			"note": "짐 실은 썰매"
		},
		{
			"kind": "tool_rack",
			"rect": [31,6,2,1],
			"solid": "low",
			"facing": 0,
			"note": "연장 걸이"
		},
		{
			"kind": "fuel_can_group",
			"rect": [34,8,2,1],
			"solid": "low",
			"facing": 0,
			"note": "연료통 무리"
		},
		{
			"kind": "firewood_pile",
			"rect": [31,11,2,1],
			"solid": "low",
			"facing": 0,
			"note": "장작 더미"
		},
		{
			"kind": "wind_pole",
			"rect": [37,6,1,1],
			"solid": "none",
			"facing": 0,
			"note": "바람 깃 장대"
		},
		{
			"kind": "snow_gauge_pole",
			"rect": [36,12,1,1],
			"solid": "none",
			"facing": 0,
			"note": "눈금 장대"
		},
		{
			"kind": "fallen_log",
			"rect": [55,33,5,1],
			"solid": "low",
			"facing": 0,
			"note": "쓰러진 통나무"
		},
		{
			"kind": "sleeper_stack",
			"rect": [86,33,3,1],
			"solid": "low",
			"facing": 0,
			"note": "침목 더미"
		},
		{
			"kind": "snow_bank",
			"rect": [101,33,6,1],
			"solid": "low",
			"facing": 0,
			"note": "눈 둑"
		},
		{
			"kind": "crate_stack",
			"rect": [119,34,2,2],
			"solid": "low",
			"facing": 1,
			"note": "자재 상자 더미"
		},
		{
			"kind": "rail_stack",
			"rect": [55,50,4,1],
			"solid": "low",
			"facing": 0,
			"note": "레일 토막 더미"
		},
		{
			"kind": "crate_stack",
			"rect": [86,50,2,2],
			"solid": "low",
			"facing": 0,
			"note": "자재 상자 더미"
		},
		{
			"kind": "plow_blade",
			"rect": [123,54,4,2],
			"solid": "low",
			"facing": 0,
			"note": "떼어 둔 제설 날"
		},
		{
			"kind": "fallen_signal",
			"rect": [119,47,1,5],
			"solid": "low",
			"facing": 1,
			"note": "쓰러진 신호기"
		},
		{
			"kind": "handcart",
			"rect": [111,69,2,1],
			"solid": "low",
			"facing": 0,
			"note": "짐수레"
		},
		{
			"kind": "tool_rack",
			"rect": [114,71,2,1],
			"solid": "low",
			"facing": 0,
			"note": "연장 걸이"
		},
		{
			"kind": "snowplow_truck",
			"rect": [111,74,6,3],
			"solid": "wall",
			"facing": 0,
			"note": "제설차"
		},
		{
			"kind": "fuel_drum",
			"rect": [112,79,1,1],
			"solid": "low",
			"facing": 0,
			"note": "연료 드럼"
		},
		{
			"kind": "fuel_drum",
			"rect": [114,80,1,1],
			"solid": "low",
			"facing": 0,
			"note": "연료 드럼"
		},
		{
			"kind": "fuel_drum",
			"rect": [116,79,1,1],
			"solid": "low",
			"facing": 0,
			"note": "연료 드럼"
		},
		{
			"kind": "track_switch",
			"rect": [12,36,2,1],
			"solid": "none",
			"facing": 0,
			"note": "선로 전환기"
		},
		{
			"kind": "signal_post",
			"rect": [16,34,1,1],
			"solid": "wall",
			"facing": 0,
			"note": "기둥 신호등"
		},
		{
			"kind": "rail_marker",
			"rect": [18,36,1,1],
			"solid": "none",
			"facing": 0,
			"note": "거리 말뚝"
		},
		{
			"kind": "power_pole",
			"rect": [21,33,1,1],
			"solid": "wall",
			"facing": 0,
			"note": "전신주"
		},
		{
			"kind": "snow_drift",
			"rect": [10,32,4,2],
			"solid": "none",
			"facing": 0,
			"note": "눈더미"
		},
		{
			"kind": "rock_face",
			"rect": [2,29,6,3],
			"solid": "wall",
			"facing": 0,
			"note": "암벽 면"
		},
		{
			"kind": "rock_ridge",
			"rect": [150,0,8,6],
			"solid": "wall",
			"facing": 0,
			"note": "산 능선"
		},
		{
			"kind": "snow_drift",
			"rect": [145,6,4,2],
			"solid": "none",
			"facing": 0,
			"note": "눈더미"
		}
	],
	"trees": [
		[118,3],
		[172,6],
		[24,1],
		[39,1],
		[64,87],
		[7,81],
		[59,83],
		[124,0],
		[53,82],
		[25,1],
		[170,3],
		[26,86],
		[57,82],
		[166,3],
		[172,7],
		[134,0],
		[35,2],
		[51,85],
		[115,3],
		[126,5],
		[166,5],
		[30,4],
		[26,2],
		[38,1],
		[169,4],
		[119,82],
		[152,6],
		[120,1],
		[26,84],
		[52,85],
		[22,86],
		[24,86],
		[124,2],
		[34,4],
		[170,4],
		[132,5],
		[24,2],
		[155,7],
		[38,2],
		[25,85],
		[21,82],
		[153,7],
		[162,4],
		[14,85],
		[113,4],
		[161,7],
		[28,81],
		[30,3],
		[20,84],
		[40,3],
		[133,2],
		[163,4],
		[173,5],
		[47,84],
		[133,4],
		[170,2],
		[53,84],
		[57,84],
		[48,83],
		[68,84],
		[174,3],
		[21,83],
		[131,5],
		[171,6],
		[168,7],
		[12,86],
		[21,1],
		[115,5],
		[114,4],
		[161,4],
		[27,1],
		[66,84],
		[65,83],
		[158,6],
		[65,86],
		[19,85],
		[21,81],
		[49,86],
		[32,0],
		[129,5],
		[23,2],
		[28,5],
		[67,86],
		[158,3],
		[7,85],
		[134,3],
		[64,85],
		[25,2],
		[160,4],
		[36,4]
	],
	"gates": [
		[31,34,1,3],
		[31,46,1,3],
		[145,34,1,3],
		[145,46,1,3]
	],
	"stores": [
		{
			"id": "shed_parts",
			"name": "안쪽 부품함",
			"cell": [122,84],
			"level": 0,
			"items": ["cloth","plank"]
		},
		{
			"id": "shed_fuel",
			"name": "연료 칸 보급함",
			"cell": [169,84],
			"level": 0,
			"items": ["cloth","flare"]
		},
		{
			"id": "shed_tools",
			"name": "정비 공구함",
			"cell": [153,69],
			"level": 0,
			"items": ["cloth","bandage"]
		},
		{
			"id": "shed_food",
			"name": "난로 방 찬장",
			"cell": [137,84],
			"level": 0,
			"items": ["food_pack","cloth"]
		},
		{
			"id": "below_parts",
			"name": "지하 부품함",
			"cell": [145,69],
			"level": -1,
			"items": ["flare","plank"]
		},
		{
			"id": "below_supply",
			"name": "지하 예비함",
			"cell": [149,76],
			"level": -1,
			"items": ["bandage","document"]
		},
		{
			"id": "hut_radio_notes",
			"name": "무전 기록함",
			"cell": [8,8],
			"level": 0,
			"items": ["document"]
		},
		{
			"id": "hut_engine_notes",
			"name": "기관 도면함",
			"cell": [12,8],
			"level": 0,
			"items": ["document"]
		},
		{
			"id": "hut_supply",
			"name": "오두막 보급함",
			"cell": [19,14],
			"level": 0,
			"items": ["food_pack","bandage"]
		},
		{
			"id": "outbuilding_tools",
			"name": "헛간 연장함",
			"cell": [75,80],
			"level": 0,
			"items": ["flare"]
		},
		{
			"id": "outbuilding_wood",
			"name": "헛간 널빤지함",
			"cell": [87,80],
			"level": 0,
			"items": ["wood","plank"]
		}
	],
	"salvage": [
		{
			"id": "plow_drive_1",
			"name": "제설기 구동부",
			"cell": [134,71],
			"material": "scrap",
			"amount": 2
		},
		{
			"id": "plow_drive_2",
			"name": "제설기 구동부",
			"cell": [147,71],
			"material": "scrap",
			"amount": 2
		},
		{
			"id": "plow_drive_3",
			"name": "제설기 구동부",
			"cell": [135,74],
			"material": "scrap",
			"amount": 2
		},
		{
			"id": "plow_drive_4",
			"name": "제설기 구동부",
			"cell": [146,74],
			"material": "scrap",
			"amount": 2
		},
		{
			"id": "shallow_sleepers",
			"name": "선로 곁 침목",
			"cell": [85,33],
			"material": "wood",
			"amount": 3
		},
		{
			"id": "shallow_rails",
			"name": "선로 곁 레일 토막",
			"cell": [54,50],
			"material": "scrap",
			"amount": 2
		},
		{
			"id": "shallow_log",
			"name": "벽 밑 쓰러진 나무",
			"cell": [54,33],
			"material": "wood",
			"amount": 2
		}
	],
	"stoves": [
		{
			"cell": [135,84],
			"building": 0
		},
		{
			"cell": [23,14],
			"building": 1
		}
	],
	"entries": {
		"track_west_upper": [
			[0,37],
			[0,38],
			[0,39]
		],
		"track_east_upper": [
			[177,37],
			[177,38],
			[177,39]
		],
		"track_west_lower": [
			[0,43],
			[0,44],
			[0,45]
		],
		"track_east_lower": [
			[177,43],
			[177,44],
			[177,45]
		],
		"access_road": [
			[175,87],
			[176,87],
			[177,87]
		],
		"ridge_path": [
			[18,0],
			[19,0]
		]
	},
	"dead_shed": [
		[132,68],
		[133,70],
		[148,75],
		[152,71],
		[154,73],
		[126,75],
		[127,78],
		[168,74],
		[138,82],
		[142,81]
	],
	"dead_ridge": [
		[38,7],
		[40,8],
		[42,9]
	],
	"yard": [
		[113,54,59,12]
	],
	"ramp": [
		[133,18,3,22],
		[10,18,126,2]
	],
	"cut": {
		"side": 1,
		"x": 113,
		"width": 26
	},
	"slope": {
		"side": 0,
		"x": 133,
		"width": 3
	},
	"underground": {
		"stairs": [148,69],
		"digs": [
			[144,68,8,4],
			[146,72,2,2],
			[144,74,8,4]
		],
		"rooms": [
			{
				"name": "지하 작은 부품 칸",
				"rect": [144,68,8,4]
			},
			{
				"name": "지하 큰 부품 칸",
				"rect": [144,74,8,4]
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
