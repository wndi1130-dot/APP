# 이 지도가 다른 판단을 만드는 것: 문 앞 차고에서 뜯고 싣는 사람과 동쪽 비탈길을 돌아 서쪽 오두막까지 가는 사람을 몇씩 나눌지 정한다.
extends RefCounted
## 칸 계획은 이 파일에서만 조립한다. 윗층은 없고 정비 구덩이 아래만 판다.
const FieldGrid = preload("res://game/world/field_grid.gd")
const S = FieldGrid.Solid
const F = FieldGrid.Floor
const WIDTH: int = 176
const HEIGHT: int = 84
const PLACE_ID: String = "summit_01"
const ZONE_NAMES: Dictionary = {"cut_floor":"선로 바닥","plow_shed":"제설 차고","ledge_hut":"턱 위 오두막","ridge_edge":"능선 가장자리"}
const ENTRY_NAMES: Dictionary = {"track_west_upper":"서쪽 선로, 오두막 쪽","track_east_upper":"동쪽 선로, 오두막 쪽","track_west_lower":"서쪽 선로, 차고 쪽","track_east_lower":"동쪽 선로, 차고 쪽","access_road":"진입 도로","ridge_path":"능선 길"}
const ENTRY_WEIGHTS: Dictionary = {"track_west_upper":2,"track_east_upper":2,"track_west_lower":2,"track_east_lower":2,"access_road":1.5,"ridge_path":0.5}
const FIRST_ENTRY: String = "track_west_upper"
const PLAN: Dictionary = {
	"id": 1,
	"w": 176,
	"h": 84,
	"judgment": "문 앞 차고에서 뜯고 싣는 사람과 동쪽 비탈길을 돌아 서쪽 오두막까지 가는 사람을 몇씩 나눌지 정한다.",
	"train": [48,38,80,3],
	"shed_up": false,
	"bands": [
		[28,16,120,22],
		[28,41,120,22]
	],
	"floors": [
		{
			"rect": [0,8,24,2],
			"kind": 5
		},
		{
			"rect": [0,74,24,2],
			"kind": 7
		},
		{
			"rect": [10,2,2,7],
			"kind": 5
		},
		{
			"rect": [16,74,2,10],
			"kind": 7
		},
		{
			"rect": [22,10,24,2],
			"kind": 5
		},
		{
			"rect": [22,72,24,2],
			"kind": 7
		},
		{
			"rect": [32,2,2,9],
			"kind": 5
		},
		{
			"rect": [38,72,2,12],
			"kind": 7
		},
		{
			"rect": [44,6,24,2],
			"kind": 5
		},
		{
			"rect": [44,76,24,2],
			"kind": 7
		},
		{
			"rect": [54,2,2,5],
			"kind": 5
		},
		{
			"rect": [60,76,2,8],
			"kind": 7
		},
		{
			"rect": [66,8,24,2],
			"kind": 5
		},
		{
			"rect": [66,74,24,2],
			"kind": 7
		},
		{
			"rect": [76,2,2,7],
			"kind": 5
		},
		{
			"rect": [82,74,2,10],
			"kind": 7
		},
		{
			"rect": [88,10,24,2],
			"kind": 5
		},
		{
			"rect": [88,72,24,2],
			"kind": 7
		},
		{
			"rect": [98,2,2,9],
			"kind": 5
		},
		{
			"rect": [104,72,2,12],
			"kind": 7
		},
		{
			"rect": [110,6,24,2],
			"kind": 5
		},
		{
			"rect": [110,76,24,2],
			"kind": 7
		},
		{
			"rect": [120,2,2,5],
			"kind": 5
		},
		{
			"rect": [126,76,2,8],
			"kind": 7
		},
		{
			"rect": [132,8,24,2],
			"kind": 5
		},
		{
			"rect": [132,74,24,2],
			"kind": 7
		},
		{
			"rect": [142,2,2,7],
			"kind": 5
		},
		{
			"rect": [148,74,2,10],
			"kind": 7
		},
		{
			"rect": [154,10,22,2],
			"kind": 5
		},
		{
			"rect": [154,72,22,2],
			"kind": 7
		},
		{
			"rect": [164,2,2,9],
			"kind": 5
		},
		{
			"rect": [170,72,2,12],
			"kind": 7
		},
		{
			"rect": [66,52,50,12],
			"kind": 7
		},
		{
			"rect": [40,45,47,2],
			"kind": 4
		},
		{
			"rect": [84,45,2,9],
			"kind": 4
		},
		{
			"rect": [139,21,3,17],
			"kind": 5
		},
		{
			"rect": [26,16,116,2],
			"kind": 5
		},
		{
			"rect": [25,3,3,25],
			"kind": 5
		},
		{
			"rect": [122,60,3,24],
			"kind": 1
		},
		{
			"rect": [88,60,37,3],
			"kind": 1
		},
		{
			"rect": [88,45,3,18],
			"kind": 1
		},
		{
			"rect": [32,0,2,17],
			"kind": 5
		},
		{
			"rect": [0,35,176,3],
			"kind": 7
		},
		{
			"rect": [0,41,176,3],
			"kind": 7
		},
		{
			"rect": [0,38,176,3],
			"kind": 4
		},
		{
			"rect": [84,44,2,2],
			"kind": 4
		},
		{
			"rect": [139,16,3,5],
			"kind": 5
		}
	],
	"rocks": [
		[30,33,2,1],
		[30,45,2,1],
		[144,33,2,1],
		[144,45,2,1],
		[0,25,1,4],
		[0,53,1,6],
		[1,25,1,4],
		[1,53,1,6],
		[2,25,1,4],
		[2,53,1,6],
		[3,25,1,4],
		[3,53,1,6],
		[4,25,1,4],
		[4,53,1,6],
		[5,25,1,4],
		[5,53,1,6],
		[6,25,1,4],
		[6,53,1,6],
		[7,25,1,4],
		[7,53,1,6],
		[8,25,1,4],
		[8,53,1,6],
		[9,25,1,4],
		[9,53,1,6],
		[10,25,1,4],
		[10,53,1,6],
		[11,26,1,4],
		[11,53,1,6],
		[12,26,1,4],
		[12,53,1,6],
		[13,26,1,4],
		[13,52,1,6],
		[14,26,1,4],
		[14,52,1,6],
		[15,26,1,4],
		[15,52,1,6],
		[16,26,1,4],
		[16,52,1,6],
		[17,27,1,3],
		[17,52,1,6],
		[18,27,1,3],
		[18,52,1,6],
		[19,27,1,3],
		[19,52,1,5],
		[20,27,1,3],
		[20,52,1,5],
		[21,27,1,3],
		[21,52,1,5],
		[22,26,1,3],
		[22,52,1,5],
		[23,26,1,3],
		[23,52,1,5],
		[24,26,1,3],
		[24,52,1,5],
		[25,26,1,3],
		[25,52,1,5],
		[26,26,1,3],
		[26,53,1,5],
		[27,26,1,3],
		[27,53,1,5],
		[28,26,1,3],
		[28,53,1,5],
		[29,26,1,4],
		[29,49,1,6],
		[30,26,1,4],
		[30,49,1,6],
		[31,26,1,4],
		[31,49,1,6],
		[32,26,1,3],
		[32,53,1,5],
		[33,27,1,3],
		[33,53,1,5],
		[34,26,1,4],
		[34,53,1,5],
		[35,26,1,4],
		[35,53,1,5],
		[36,26,1,4],
		[36,53,1,5],
		[37,26,1,4],
		[37,53,1,5],
		[38,26,1,4],
		[38,53,1,6],
		[39,26,1,4],
		[39,52,1,6],
		[40,26,1,4],
		[40,52,1,6],
		[41,26,1,4],
		[41,52,1,6],
		[42,26,1,4],
		[42,52,1,6],
		[43,26,1,4],
		[43,52,1,6],
		[44,25,1,4],
		[44,52,1,6],
		[45,25,1,4],
		[45,52,1,6],
		[46,25,1,4],
		[46,52,1,6],
		[47,25,1,4],
		[47,52,1,6],
		[48,25,1,4],
		[48,52,1,6],
		[49,25,1,4],
		[49,52,1,6],
		[50,25,1,4],
		[50,52,1,6],
		[51,26,1,3],
		[51,52,1,6],
		[52,26,1,3],
		[52,53,1,6],
		[53,26,1,3],
		[53,53,1,6],
		[54,26,1,3],
		[54,53,1,6],
		[55,27,1,3],
		[55,53,1,6],
		[56,27,1,3],
		[56,53,1,6],
		[57,27,1,3],
		[57,53,1,5],
		[58,27,1,3],
		[58,53,1,5],
		[59,27,1,3],
		[59,53,1,5],
		[60,27,1,3],
		[60,53,1,5],
		[61,27,1,3],
		[61,53,1,5],
		[62,27,1,3],
		[62,53,1,5],
		[63,27,1,3],
		[63,53,1,5],
		[64,27,1,3],
		[64,53,1,5],
		[65,27,1,3],
		[65,52,1,5],
		[66,26,1,3],
		[66,52,1,5],
		[67,26,1,3],
		[67,52,1,5],
		[68,25,1,4],
		[68,52,1,5],
		[69,25,1,4],
		[69,52,1,5],
		[70,25,1,4],
		[70,52,1,5],
		[71,25,1,4],
		[71,52,1,5],
		[72,25,1,4],
		[72,52,1,5],
		[73,25,1,4],
		[73,52,1,5],
		[74,25,1,4],
		[74,52,1,5],
		[75,25,1,4],
		[75,52,1,5],
		[76,25,1,4],
		[76,52,1,6],
		[77,26,1,4],
		[77,52,1,6],
		[78,26,1,4],
		[78,53,1,6],
		[79,26,1,4],
		[79,53,1,6],
		[80,26,1,4],
		[81,26,1,4],
		[82,26,1,4],
		[83,26,1,4],
		[84,26,1,4],
		[85,27,1,3],
		[86,27,1,3],
		[87,27,1,3],
		[88,26,1,3],
		[89,26,1,3],
		[90,26,1,3],
		[91,26,1,3],
		[92,26,1,3],
		[93,26,1,3],
		[94,26,1,3],
		[95,26,1,3],
		[96,26,1,3],
		[97,26,1,3],
		[98,26,1,3],
		[99,27,1,3],
		[100,27,1,3],
		[101,27,1,3],
		[102,26,1,4],
		[103,26,1,4],
		[104,26,1,4],
		[105,26,1,4],
		[106,26,1,4],
		[106,53,1,5],
		[107,26,1,4],
		[107,53,1,5],
		[108,26,1,4],
		[108,53,1,5],
		[109,26,1,4],
		[109,53,1,5],
		[110,25,1,4],
		[110,53,1,5],
		[111,25,1,4],
		[111,53,1,5],
		[112,25,1,4],
		[112,53,1,5],
		[113,25,1,4],
		[113,53,1,5],
		[114,25,1,4],
		[114,53,1,6],
		[115,25,1,4],
		[115,53,1,6],
		[116,25,1,4],
		[116,53,1,6],
		[117,25,1,4],
		[117,52,1,6],
		[118,25,1,4],
		[118,52,1,6],
		[119,26,1,3],
		[119,52,1,6],
		[120,26,1,3],
		[120,52,1,6],
		[121,27,1,3],
		[121,52,1,6],
		[122,27,1,3],
		[122,52,1,6],
		[123,27,1,3],
		[123,52,1,6],
		[124,27,1,3],
		[124,52,1,6],
		[125,27,1,3],
		[125,52,1,6],
		[126,27,1,3],
		[126,52,1,6],
		[127,27,1,3],
		[127,52,1,6],
		[128,27,1,3],
		[128,52,1,6],
		[129,27,1,3],
		[129,52,1,6],
		[130,27,1,3],
		[130,53,1,6],
		[131,27,1,3],
		[131,53,1,6],
		[132,26,1,3],
		[132,53,1,6],
		[133,26,1,3],
		[133,53,1,5],
		[134,26,1,3],
		[134,53,1,5],
		[135,26,1,3],
		[135,53,1,5],
		[136,25,1,4],
		[136,53,1,5],
		[137,25,1,4],
		[137,53,1,5],
		[138,25,1,4],
		[138,53,1,5],
		[139,53,1,5],
		[140,53,1,5],
		[141,53,1,5],
		[142,25,1,4],
		[142,53,1,5],
		[143,26,1,4],
		[143,49,1,6],
		[144,26,1,4],
		[144,49,1,6],
		[145,26,1,4],
		[145,49,1,6],
		[146,26,1,4],
		[146,52,1,5],
		[147,26,1,4],
		[147,52,1,5],
		[148,26,1,4],
		[148,52,1,5],
		[149,26,1,4],
		[149,52,1,5],
		[150,26,1,4],
		[150,52,1,5],
		[151,26,1,4],
		[151,52,1,5],
		[152,26,1,4],
		[152,52,1,6],
		[153,27,1,3],
		[153,52,1,6],
		[154,26,1,3],
		[154,52,1,6],
		[155,26,1,3],
		[155,52,1,6],
		[156,26,1,3],
		[156,53,1,6],
		[157,26,1,3],
		[157,53,1,6],
		[158,26,1,3],
		[158,53,1,6],
		[159,26,1,3],
		[159,53,1,6],
		[160,26,1,3],
		[160,53,1,6],
		[161,26,1,3],
		[161,53,1,6],
		[162,26,1,3],
		[162,53,1,6],
		[163,26,1,3],
		[163,53,1,6],
		[164,26,1,3],
		[164,53,1,6],
		[165,27,1,3],
		[165,53,1,6],
		[166,27,1,3],
		[166,53,1,6],
		[167,27,1,3],
		[167,53,1,6],
		[168,27,1,3],
		[168,53,1,6],
		[169,27,1,3],
		[169,52,1,6],
		[170,26,1,4],
		[170,52,1,6],
		[171,26,1,4],
		[171,52,1,5],
		[172,26,1,4],
		[172,52,1,5],
		[173,26,1,4],
		[173,52,1,5],
		[174,26,1,4],
		[174,52,1,5],
		[175,26,1,4],
		[175,52,1,5]
	],
	"wall_columns": [
		[0,25,4,53,6],
		[1,25,4,53,6],
		[2,25,4,53,6],
		[3,25,4,53,6],
		[4,25,4,53,6],
		[5,25,4,53,6],
		[6,25,4,53,6],
		[7,25,4,53,6],
		[8,25,4,53,6],
		[9,25,4,53,6],
		[10,25,4,53,6],
		[11,26,4,53,6],
		[12,26,4,53,6],
		[13,26,4,52,6],
		[14,26,4,52,6],
		[15,26,4,52,6],
		[16,26,4,52,6],
		[17,27,3,52,6],
		[18,27,3,52,6],
		[19,27,3,52,5],
		[20,27,3,52,5],
		[21,27,3,52,5],
		[22,26,3,52,5],
		[23,26,3,52,5],
		[24,26,3,52,5],
		[25,26,3,52,5],
		[26,26,3,53,5],
		[27,26,3,53,5],
		[28,26,3,53,5],
		[29,26,4,49,6],
		[30,26,4,49,6],
		[31,26,4,49,6],
		[32,26,3,53,5],
		[33,27,3,53,5],
		[34,26,4,53,5],
		[35,26,4,53,5],
		[36,26,4,53,5],
		[37,26,4,53,5],
		[38,26,4,53,6],
		[39,26,4,52,6],
		[40,26,4,52,6],
		[41,26,4,52,6],
		[42,26,4,52,6],
		[43,26,4,52,6],
		[44,25,4,52,6],
		[45,25,4,52,6],
		[46,25,4,52,6],
		[47,25,4,52,6],
		[48,25,4,52,6],
		[49,25,4,52,6],
		[50,25,4,52,6],
		[51,26,3,52,6],
		[52,26,3,53,6],
		[53,26,3,53,6],
		[54,26,3,53,6],
		[55,27,3,53,6],
		[56,27,3,53,6],
		[57,27,3,53,5],
		[58,27,3,53,5],
		[59,27,3,53,5],
		[60,27,3,53,5],
		[61,27,3,53,5],
		[62,27,3,53,5],
		[63,27,3,53,5],
		[64,27,3,53,5],
		[65,27,3,52,5],
		[66,26,3,52,5],
		[67,26,3,52,5],
		[68,25,4,52,5],
		[69,25,4,52,5],
		[70,25,4,52,5],
		[71,25,4,52,5],
		[72,25,4,52,5],
		[73,25,4,52,5],
		[74,25,4,52,5],
		[75,25,4,52,5],
		[76,25,4,52,6],
		[77,26,4,52,6],
		[78,26,4,53,6],
		[79,26,4,53,6],
		[80,26,4,53,6],
		[81,26,4,53,6],
		[82,26,4,53,6],
		[83,26,4,53,6],
		[84,26,4,53,6],
		[85,27,3,53,6],
		[86,27,3,53,6],
		[87,27,3,53,6],
		[88,26,3,53,6],
		[89,26,3,53,6],
		[90,26,3,53,6],
		[91,26,3,52,6],
		[92,26,3,52,6],
		[93,26,3,52,6],
		[94,26,3,52,6],
		[95,26,3,52,5],
		[96,26,3,52,5],
		[97,26,3,52,5],
		[98,26,3,52,5],
		[99,27,3,52,5],
		[100,27,3,52,5],
		[101,27,3,52,5],
		[102,26,4,52,5],
		[103,26,4,52,5],
		[104,26,4,53,5],
		[105,26,4,53,5],
		[106,26,4,53,5],
		[107,26,4,53,5],
		[108,26,4,53,5],
		[109,26,4,53,5],
		[110,25,4,53,5],
		[111,25,4,53,5],
		[112,25,4,53,5],
		[113,25,4,53,5],
		[114,25,4,53,6],
		[115,25,4,53,6],
		[116,25,4,53,6],
		[117,25,4,52,6],
		[118,25,4,52,6],
		[119,26,3,52,6],
		[120,26,3,52,6],
		[121,27,3,52,6],
		[122,27,3,52,6],
		[123,27,3,52,6],
		[124,27,3,52,6],
		[125,27,3,52,6],
		[126,27,3,52,6],
		[127,27,3,52,6],
		[128,27,3,52,6],
		[129,27,3,52,6],
		[130,27,3,53,6],
		[131,27,3,53,6],
		[132,26,3,53,6],
		[133,26,3,53,5],
		[134,26,3,53,5],
		[135,26,3,53,5],
		[136,25,4,53,5],
		[137,25,4,53,5],
		[138,25,4,53,5],
		[139,25,4,53,5],
		[140,25,4,53,5],
		[141,25,4,53,5],
		[142,25,4,53,5],
		[143,26,4,49,6],
		[144,26,4,49,6],
		[145,26,4,49,6],
		[146,26,4,52,5],
		[147,26,4,52,5],
		[148,26,4,52,5],
		[149,26,4,52,5],
		[150,26,4,52,5],
		[151,26,4,52,5],
		[152,26,4,52,6],
		[153,27,3,52,6],
		[154,26,3,52,6],
		[155,26,3,52,6],
		[156,26,3,53,6],
		[157,26,3,53,6],
		[158,26,3,53,6],
		[159,26,3,53,6],
		[160,26,3,53,6],
		[161,26,3,53,6],
		[162,26,3,53,6],
		[163,26,3,53,6],
		[164,26,3,53,6],
		[165,27,3,53,6],
		[166,27,3,53,6],
		[167,27,3,53,6],
		[168,27,3,53,6],
		[169,27,3,52,6],
		[170,26,4,52,6],
		[171,26,4,52,5],
		[172,26,4,52,5],
		[173,26,4,52,5],
		[174,26,4,52,5],
		[175,26,4,52,5]
	],
	"houses": [
		{
			"id": 0,
			"name": "제설 차고",
			"rect": [66,64,50,19],
			"walls": [
				[76,65,1,17],
				[105,65,1,17],
				[77,75,16,1],
				[92,76,1,6]
			],
			"doors": [
				[76,67],
				[105,69],
				[85,75],
				[89,64],
				[90,64],
				[100,64]
			],
			"windows": [
				[66,70],
				[66,78],
				[115,71],
				[115,79]
			],
			"rooms": [
				{
					"name": "부품 창고",
					"rect": [67,65,9,17]
				},
				{
					"name": "연료 칸",
					"rect": [106,65,9,17]
				},
				{
					"name": "정비 칸",
					"rect": [77,65,28,10]
				},
				{
					"name": "난로 방",
					"rect": [77,76,15,6]
				}
			],
			"entrances": [
				{
					"cell": [89,64],
					"outward": [0,-1]
				},
				{
					"cell": [100,64],
					"outward": [0,-1]
				}
			]
		},
		{
			"id": 1,
			"name": "고갯마루 오두막",
			"rect": [22,3,22,12],
			"walls": [
				[33,4,1,10]
			],
			"doors": [
				[33,11],
				[26,14]
			],
			"windows": [
				[25,3],
				[40,3],
				[43,7]
			],
			"rooms": [
				{
					"name": "일하던 방",
					"rect": [23,4,10,10]
				},
				{
					"name": "자던 방",
					"rect": [34,4,9,10]
				}
			],
			"entrances": []
		}
	],
	"props": [
		{
			"kind": "garage_door_leaf",
			"rect": [91,64,2,1],
			"solid": "wall",
			"facing": 0,
			"note": "반쯤 닫힌 큰 문짝"
		},
		{
			"kind": "parts_rack",
			"rect": [68,66,4,1],
			"solid": "low",
			"facing": 0,
			"note": "부품 선반"
		},
		{
			"kind": "tool_rack",
			"rect": [68,70,2,1],
			"solid": "low",
			"facing": 0,
			"note": "연장 걸이"
		},
		{
			"kind": "ladder_rack",
			"rect": [68,78,4,1],
			"solid": "low",
			"facing": 0,
			"note": "사다리 걸이"
		},
		{
			"kind": "fuel_drum",
			"rect": [108,66,1,1],
			"solid": "low",
			"facing": 0,
			"note": "연료 드럼"
		},
		{
			"kind": "fuel_drum",
			"rect": [110,67,1,1],
			"solid": "low",
			"facing": 0,
			"note": "연료 드럼"
		},
		{
			"kind": "fuel_drum",
			"rect": [108,69,1,1],
			"solid": "low",
			"facing": 0,
			"note": "연료 드럼"
		},
		{
			"kind": "fuel_tank",
			"rect": [108,77,3,2],
			"solid": "low",
			"facing": 0,
			"note": "연료 탱크"
		},
		{
			"kind": "inspection_pit",
			"rect": [80,66,14,2],
			"solid": "none",
			"facing": 0,
			"note": "검수 구덩이 틀"
		},
		{
			"kind": "tool_bench",
			"rect": [78,73,2,1],
			"solid": "low",
			"facing": 0,
			"note": "연장 작업대"
		},
		{
			"kind": "tool_rack",
			"rect": [97,71,2,1],
			"solid": "low",
			"facing": 0,
			"note": "연장 걸이"
		},
		{
			"kind": "siding_buffer",
			"rect": [95,69,2,3],
			"solid": "low",
			"facing": 0,
			"note": "측선 끝 차막이"
		},
		{
			"kind": "generator",
			"rect": [99,73,2,1],
			"solid": "low",
			"facing": 0,
			"note": "발전기"
		},
		{
			"kind": "rail_plow",
			"rect": [81,69,12,3],
			"solid": "wall",
			"facing": 0,
			"note": "식은 제설기"
		},
		{
			"kind": "bed",
			"rect": [78,78,2,1],
			"solid": "low",
			"facing": 0,
			"note": "침대"
		},
		{
			"kind": "shelf",
			"rect": [86,80,3,1],
			"solid": "low",
			"facing": 0,
			"note": "선반"
		},
		{
			"kind": "firewood_pile",
			"rect": [89,78,2,1],
			"solid": "low",
			"facing": 0,
			"note": "장작 더미"
		},
		{
			"kind": "desk",
			"rect": [24,5,2,1],
			"solid": "low",
			"facing": 0,
			"note": "책상"
		},
		{
			"kind": "radio_set",
			"rect": [28,5,2,1],
			"solid": "low",
			"facing": 0,
			"note": "무전기 책상"
		},
		{
			"kind": "map_cabinet",
			"rect": [24,9,3,1],
			"solid": "low",
			"facing": 0,
			"note": "도면 서랍장"
		},
		{
			"kind": "bed",
			"rect": [35,5,2,1],
			"solid": "low",
			"facing": 0,
			"note": "침대"
		},
		{
			"kind": "shelf",
			"rect": [35,9,3,1],
			"solid": "low",
			"facing": 0,
			"note": "선반"
		},
		{
			"kind": "fuel_can_group",
			"rect": [39,7,2,1],
			"solid": "low",
			"facing": 0,
			"note": "연료통 무리"
		},
		{
			"kind": "tool_rack",
			"rect": [47,5,2,1],
			"solid": "low",
			"facing": 0,
			"note": "연장 걸이"
		},
		{
			"kind": "fuel_can_group",
			"rect": [50,7,2,1],
			"solid": "low",
			"facing": 0,
			"note": "연료통 무리"
		},
		{
			"kind": "firewood_pile",
			"rect": [47,10,2,1],
			"solid": "low",
			"facing": 0,
			"note": "장작 더미"
		},
		{
			"kind": "wind_pole",
			"rect": [53,5,1,1],
			"solid": "none",
			"facing": 0,
			"note": "바람 깃 장대"
		},
		{
			"kind": "snow_gauge_pole",
			"rect": [52,11,1,1],
			"solid": "none",
			"facing": 0,
			"note": "눈금 장대"
		},
		{
			"kind": "snow_bank",
			"rect": [54,31,6,1],
			"solid": "low",
			"facing": 0,
			"note": "눈 둑"
		},
		{
			"kind": "sleeper_stack",
			"rect": [86,31,3,1],
			"solid": "low",
			"facing": 0,
			"note": "침목 더미"
		},
		{
			"kind": "crate_stack",
			"rect": [100,30,2,2],
			"solid": "low",
			"facing": 0,
			"note": "자재 상자 더미"
		},
		{
			"kind": "fallen_log",
			"rect": [118,29,1,5],
			"solid": "low",
			"facing": 1,
			"note": "쓰러진 통나무"
		},
		{
			"kind": "rail_stack",
			"rect": [54,48,4,1],
			"solid": "low",
			"facing": 0,
			"note": "레일 토막 더미"
		},
		{
			"kind": "crate_stack",
			"rect": [86,48,2,2],
			"solid": "low",
			"facing": 0,
			"note": "자재 상자 더미"
		},
		{
			"kind": "plow_blade",
			"rect": [90,52,4,2],
			"solid": "low",
			"facing": 0,
			"note": "떼어 둔 제설 날"
		},
		{
			"kind": "sleeper_stack",
			"rect": [118,45,1,3],
			"solid": "low",
			"facing": 1,
			"note": "침목 더미"
		},
		{
			"kind": "handcart",
			"rect": [118,67,2,1],
			"solid": "low",
			"facing": 0,
			"note": "짐수레"
		},
		{
			"kind": "tool_rack",
			"rect": [121,69,2,1],
			"solid": "low",
			"facing": 0,
			"note": "연장 걸이"
		},
		{
			"kind": "snowplow_truck",
			"rect": [118,72,6,3],
			"solid": "wall",
			"facing": 0,
			"note": "제설차"
		},
		{
			"kind": "fuel_drum",
			"rect": [119,77,1,1],
			"solid": "low",
			"facing": 0,
			"note": "연료 드럼"
		},
		{
			"kind": "fuel_drum",
			"rect": [121,78,1,1],
			"solid": "low",
			"facing": 0,
			"note": "연료 드럼"
		},
		{
			"kind": "fuel_drum",
			"rect": [123,77,1,1],
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
			"rect": [2,25,6,3],
			"solid": "wall",
			"facing": 0,
			"note": "암벽 면"
		},
		{
			"kind": "rock_ridge",
			"rect": [148,0,8,6],
			"solid": "wall",
			"facing": 0,
			"note": "산 능선"
		},
		{
			"kind": "snow_drift",
			"rect": [143,6,4,2],
			"solid": "none",
			"facing": 0,
			"note": "눈더미"
		}
	],
	"trees": [
		[55,82],
		[35,2],
		[118,79],
		[158,8],
		[17,4],
		[137,80],
		[135,2],
		[136,81],
		[129,81],
		[168,4],
		[156,5],
		[169,3],
		[56,80],
		[18,81],
		[119,2],
		[15,80],
		[128,1],
		[8,77],
		[27,2],
		[64,83],
		[27,1],
		[137,82],
		[58,83],
		[17,5],
		[127,5],
		[129,3],
		[168,6],
		[169,2],
		[136,79],
		[117,79],
		[29,79],
		[118,1],
		[30,80],
		[26,79],
		[125,5],
		[10,77],
		[12,82],
		[125,79],
		[51,82],
		[156,3],
		[56,81],
		[27,82],
		[10,80],
		[127,0],
		[136,78],
		[19,82],
		[23,79],
		[51,83],
		[48,79],
		[26,76],
		[160,2],
		[18,78],
		[55,79],
		[14,78],
		[21,5],
		[24,79],
		[38,1],
		[114,3],
		[27,79],
		[124,3],
		[136,77],
		[46,81],
		[131,4],
		[20,4],
		[14,82],
		[171,6],
		[141,78],
		[46,82],
		[54,82],
		[64,81],
		[20,0],
		[130,1],
		[62,80],
		[167,8],
		[173,5],
		[157,8],
		[139,77],
		[52,83],
		[111,3],
		[140,79],
		[113,1],
		[135,77],
		[128,82],
		[157,2],
		[173,4],
		[137,79],
		[24,78],
		[9,76],
		[57,83],
		[13,82]
	],
	"gates": [
		[30,30,1,3],
		[30,46,1,3],
		[144,30,1,3],
		[144,46,1,3]
	],
	"stores": [
		{
			"id": "shed_parts",
			"name": "안쪽 부품함",
			"cell": [68,80],
			"level": 0,
			"items": ["plank","cloth"]
		},
		{
			"id": "shed_fuel",
			"name": "연료 칸 보급함",
			"cell": [113,80],
			"level": 0,
			"items": ["cloth","flare"]
		},
		{
			"id": "shed_tools",
			"name": "정비 공구함",
			"cell": [99,67],
			"level": 0,
			"items": ["cloth","bandage"]
		},
		{
			"id": "shed_food",
			"name": "난로 방 찬장",
			"cell": [83,80],
			"level": 0,
			"items": ["food_pack","cloth"]
		},
		{
			"id": "below_parts",
			"name": "지하 부품함",
			"cell": [91,67],
			"level": -1,
			"items": ["plank","cloth"]
		},
		{
			"id": "below_supply",
			"name": "지하 예비함",
			"cell": [95,74],
			"level": -1,
			"items": ["bandage","document"]
		},
		{
			"id": "hut_radio_notes",
			"name": "무전 기록함",
			"cell": [24,7],
			"level": 0,
			"items": ["document"]
		},
		{
			"id": "hut_engine_notes",
			"name": "기관 도면함",
			"cell": [28,7],
			"level": 0,
			"items": ["document"]
		},
		{
			"id": "hut_supply",
			"name": "오두막 보급함",
			"cell": [35,12],
			"level": 0,
			"items": ["food_pack","bandage"]
		}
	],
	"salvage": [
		{
			"id": "plow_drive_1",
			"name": "제설기 구동부",
			"cell": [80,69],
			"material": "scrap",
			"amount": 2
		},
		{
			"id": "plow_drive_2",
			"name": "제설기 구동부",
			"cell": [93,69],
			"material": "scrap",
			"amount": 2
		},
		{
			"id": "plow_drive_3",
			"name": "제설기 구동부",
			"cell": [81,72],
			"material": "scrap",
			"amount": 2
		},
		{
			"id": "plow_drive_4",
			"name": "제설기 구동부",
			"cell": [92,72],
			"material": "scrap",
			"amount": 2
		},
		{
			"id": "shallow_sleepers",
			"name": "선로 곁 침목",
			"cell": [85,31],
			"material": "wood",
			"amount": 3
		},
		{
			"id": "shallow_rails",
			"name": "선로 곁 레일 토막",
			"cell": [53,48],
			"material": "scrap",
			"amount": 2
		},
		{
			"id": "shallow_log",
			"name": "벽 밑 쓰러진 나무",
			"cell": [117,29],
			"material": "wood",
			"amount": 2
		}
	],
	"stoves": [
		{
			"cell": [81,80],
			"building": 0
		},
		{
			"cell": [39,12],
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
			[175,35],
			[175,36],
			[175,37]
		],
		"track_west_lower": [
			[0,41],
			[0,42],
			[0,43]
		],
		"track_east_lower": [
			[175,41],
			[175,42],
			[175,43]
		],
		"access_road": [
			[122,83],
			[123,83],
			[124,83]
		],
		"ridge_path": [
			[32,0],
			[33,0]
		]
	},
	"dead_shed": [
		[78,66],
		[79,68],
		[94,73],
		[98,69],
		[100,71],
		[72,73],
		[73,76],
		[112,72],
		[84,78],
		[88,77]
	],
	"dead_ridge": [
		[54,7],
		[56,8],
		[58,9]
	],
	"yard": [
		[66,52,50,12]
	],
	"ramp": [
		[139,16,3,22],
		[26,16,116,2]
	],
	"cut": {
		"side": 1,
		"x": 80,
		"width": 26
	},
	"slope": {
		"side": 0,
		"x": 139,
		"width": 3
	},
	"underground": {
		"stairs": [94,67],
		"digs": [
			[90,66,8,4],
			[92,70,2,2],
			[90,72,8,4]
		],
		"rooms": [
			{
				"name": "지하 작은 부품 칸",
				"rect": [90,66,8,4]
			},
			{
				"name": "지하 큰 부품 칸",
				"rect": [90,72,8,4]
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
