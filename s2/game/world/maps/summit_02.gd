# 이 지도가 다른 판단을 만드는 것: 서쪽 선로 끝으로 오는 무리의 길을 건너 먼 차고에 간다. 길게 뻗은 측선에서 돌아올 때를 먼저 정한다.
extends RefCounted
## 칸 계획은 이 파일에서만 조립한다. 윗층은 없고 정비 구덩이 아래만 판다.
const FieldGrid = preload("res://game/world/field_grid.gd")
const S = FieldGrid.Solid
const F = FieldGrid.Floor
const WIDTH: int = 180
const HEIGHT: int = 82
const PLACE_ID: String = "summit_02"
const ZONE_NAMES: Dictionary = {"cut_floor":"선로 바닥","plow_shed":"제설 차고","ledge_hut":"턱 위 오두막","ridge_edge":"능선 가장자리"}
const ENTRY_NAMES: Dictionary = {"track_west_upper":"서쪽 선로, 오두막 쪽","track_east_upper":"동쪽 선로, 오두막 쪽","track_west_lower":"서쪽 선로, 차고 쪽","track_east_lower":"동쪽 선로, 차고 쪽","access_road":"진입 도로","ridge_path":"능선 길"}
const ENTRY_WEIGHTS: Dictionary = {"track_west_upper":2,"track_east_upper":2,"track_west_lower":2,"track_east_lower":2,"access_road":1.5,"ridge_path":0.5}
const FIRST_ENTRY: String = "track_east_upper"
const PLAN: Dictionary = {
	"id": 2,
	"w": 180,
	"h": 82,
	"judgment": "서쪽 선로 끝으로 오는 무리의 길을 건너 먼 차고에 간다. 길게 뻗은 측선에서 돌아올 때를 먼저 정한다.",
	"train": [50,36,80,3],
	"shed_up": false,
	"bands": [
		[30,14,120,22],
		[30,39,120,22]
	],
	"floors": [
		{
			"rect": [0,10,24,2],
			"kind": 5
		},
		{
			"rect": [0,70,24,2],
			"kind": 7
		},
		{
			"rect": [10,2,2,9],
			"kind": 5
		},
		{
			"rect": [16,70,2,12],
			"kind": 7
		},
		{
			"rect": [22,6,24,2],
			"kind": 5
		},
		{
			"rect": [22,74,24,2],
			"kind": 7
		},
		{
			"rect": [32,2,2,5],
			"kind": 5
		},
		{
			"rect": [38,74,2,8],
			"kind": 7
		},
		{
			"rect": [44,8,24,2],
			"kind": 5
		},
		{
			"rect": [44,72,24,2],
			"kind": 7
		},
		{
			"rect": [54,2,2,7],
			"kind": 5
		},
		{
			"rect": [60,72,2,10],
			"kind": 7
		},
		{
			"rect": [66,10,24,2],
			"kind": 5
		},
		{
			"rect": [66,70,24,2],
			"kind": 7
		},
		{
			"rect": [76,2,2,9],
			"kind": 5
		},
		{
			"rect": [82,70,2,12],
			"kind": 7
		},
		{
			"rect": [88,6,24,2],
			"kind": 5
		},
		{
			"rect": [88,74,24,2],
			"kind": 7
		},
		{
			"rect": [98,2,2,5],
			"kind": 5
		},
		{
			"rect": [104,74,2,8],
			"kind": 7
		},
		{
			"rect": [110,8,24,2],
			"kind": 5
		},
		{
			"rect": [110,72,24,2],
			"kind": 7
		},
		{
			"rect": [120,2,2,7],
			"kind": 5
		},
		{
			"rect": [126,72,2,10],
			"kind": 7
		},
		{
			"rect": [132,10,24,2],
			"kind": 5
		},
		{
			"rect": [132,70,24,2],
			"kind": 7
		},
		{
			"rect": [142,2,2,9],
			"kind": 5
		},
		{
			"rect": [148,70,2,12],
			"kind": 7
		},
		{
			"rect": [154,6,24,2],
			"kind": 5
		},
		{
			"rect": [154,74,24,2],
			"kind": 7
		},
		{
			"rect": [164,2,2,5],
			"kind": 5
		},
		{
			"rect": [170,74,2,8],
			"kind": 7
		},
		{
			"rect": [176,8,4,2],
			"kind": 5
		},
		{
			"rect": [176,72,4,2],
			"kind": 7
		},
		{
			"rect": [178,2,2,7],
			"kind": 5
		},
		{
			"rect": [178,72,2,10],
			"kind": 7
		},
		{
			"rect": [3,47,54,15],
			"kind": 7
		},
		{
			"rect": [8,43,37,2],
			"kind": 4
		},
		{
			"rect": [8,43,2,6],
			"kind": 4
		},
		{
			"rect": [111,16,3,20],
			"kind": 5
		},
		{
			"rect": [85,14,29,2],
			"kind": 5
		},
		{
			"rect": [84,1,3,25],
			"kind": 5
		},
		{
			"rect": [1,58,3,24],
			"kind": 1
		},
		{
			"rect": [1,58,14,3],
			"kind": 1
		},
		{
			"rect": [12,43,3,18],
			"kind": 1
		},
		{
			"rect": [92,0,2,15],
			"kind": 5
		},
		{
			"rect": [0,33,180,3],
			"kind": 7
		},
		{
			"rect": [0,39,180,3],
			"kind": 7
		},
		{
			"rect": [0,36,180,3],
			"kind": 4
		},
		{
			"rect": [55,62,87,2],
			"kind": 7
		},
		{
			"rect": [8,42,2,2],
			"kind": 4
		}
	],
	"rocks": [
		[32,31,2,1],
		[32,43,2,1],
		[146,31,2,1],
		[146,43,2,1],
		[0,20,1,5],
		[0,47,1,3],
		[1,20,1,5],
		[1,47,1,3],
		[2,20,1,5],
		[2,47,1,3],
		[3,20,1,5],
		[3,47,1,3],
		[4,20,1,5],
		[5,20,1,5],
		[6,20,1,5],
		[7,20,1,5],
		[8,20,1,5],
		[9,20,1,5],
		[10,20,1,5],
		[11,19,1,5],
		[12,19,1,5],
		[13,19,1,5],
		[14,19,1,5],
		[15,19,1,5],
		[16,19,1,5],
		[17,18,1,6],
		[18,18,1,6],
		[19,18,1,6],
		[20,18,1,6],
		[21,18,1,6],
		[22,19,1,6],
		[23,19,1,6],
		[24,19,1,6],
		[25,19,1,6],
		[26,19,1,6],
		[27,19,1,6],
		[28,19,1,6],
		[28,47,1,4],
		[29,19,1,6],
		[29,47,1,4],
		[30,19,1,6],
		[30,47,1,4],
		[31,22,1,6],
		[31,47,1,4],
		[32,22,1,6],
		[32,47,1,4],
		[33,22,1,6],
		[33,47,1,4],
		[34,19,1,5],
		[34,47,1,4],
		[35,19,1,5],
		[35,47,1,4],
		[36,19,1,5],
		[36,47,1,4],
		[37,19,1,5],
		[37,47,1,4],
		[38,19,1,5],
		[38,47,1,3],
		[39,19,1,5],
		[39,48,1,3],
		[40,19,1,5],
		[40,48,1,3],
		[41,19,1,5],
		[41,48,1,3],
		[42,19,1,5],
		[42,48,1,3],
		[43,19,1,5],
		[43,48,1,3],
		[44,20,1,5],
		[44,48,1,3],
		[45,20,1,5],
		[45,48,1,3],
		[46,20,1,5],
		[46,48,1,3],
		[47,20,1,5],
		[47,48,1,3],
		[48,20,1,5],
		[48,48,1,3],
		[49,20,1,5],
		[49,48,1,3],
		[50,20,1,5],
		[50,48,1,3],
		[51,19,1,6],
		[51,48,1,3],
		[52,19,1,6],
		[52,47,1,3],
		[53,19,1,6],
		[53,47,1,3],
		[54,19,1,6],
		[54,47,1,3],
		[55,18,1,6],
		[55,47,1,3],
		[56,18,1,6],
		[56,47,1,3],
		[57,18,1,6],
		[57,47,1,4],
		[58,18,1,6],
		[58,47,1,4],
		[59,18,1,6],
		[59,47,1,4],
		[60,18,1,6],
		[60,47,1,4],
		[61,18,1,6],
		[61,47,1,4],
		[62,18,1,6],
		[62,47,1,4],
		[63,18,1,6],
		[63,47,1,4],
		[64,18,1,6],
		[64,47,1,4],
		[65,18,1,6],
		[65,48,1,4],
		[66,19,1,6],
		[66,48,1,4],
		[67,19,1,6],
		[67,48,1,4],
		[68,20,1,5],
		[68,48,1,4],
		[69,20,1,5],
		[69,48,1,4],
		[70,20,1,5],
		[70,48,1,4],
		[71,20,1,5],
		[71,48,1,4],
		[72,20,1,5],
		[72,48,1,4],
		[73,20,1,5],
		[73,48,1,4],
		[74,20,1,5],
		[74,48,1,4],
		[75,20,1,5],
		[75,48,1,4],
		[76,20,1,5],
		[76,48,1,3],
		[77,19,1,5],
		[77,48,1,3],
		[78,19,1,5],
		[78,47,1,3],
		[79,19,1,5],
		[79,47,1,3],
		[80,19,1,5],
		[80,47,1,3],
		[81,19,1,5],
		[81,47,1,3],
		[82,19,1,5],
		[82,47,1,3],
		[83,19,1,5],
		[83,47,1,3],
		[84,19,1,5],
		[84,47,1,3],
		[85,18,1,6],
		[85,47,1,3],
		[86,18,1,6],
		[86,47,1,3],
		[87,18,1,6],
		[87,47,1,3],
		[88,19,1,6],
		[88,47,1,3],
		[89,19,1,6],
		[89,47,1,3],
		[90,19,1,6],
		[90,47,1,3],
		[91,19,1,6],
		[91,48,1,3],
		[92,19,1,6],
		[92,48,1,3],
		[93,19,1,6],
		[93,48,1,3],
		[94,19,1,6],
		[94,48,1,3],
		[95,19,1,6],
		[95,48,1,4],
		[96,19,1,6],
		[96,48,1,4],
		[97,19,1,6],
		[97,48,1,4],
		[98,19,1,6],
		[98,48,1,4],
		[99,18,1,6],
		[99,48,1,4],
		[100,18,1,6],
		[100,48,1,4],
		[101,18,1,6],
		[101,48,1,4],
		[102,19,1,5],
		[102,48,1,4],
		[103,19,1,5],
		[103,48,1,4],
		[104,19,1,5],
		[104,47,1,4],
		[105,19,1,5],
		[105,47,1,4],
		[106,19,1,5],
		[106,47,1,4],
		[107,19,1,5],
		[107,47,1,4],
		[108,19,1,5],
		[108,47,1,4],
		[109,19,1,5],
		[109,47,1,4],
		[110,20,1,5],
		[110,47,1,4],
		[111,47,1,4],
		[112,47,1,4],
		[113,47,1,4],
		[114,20,1,5],
		[114,47,1,3],
		[115,20,1,5],
		[115,47,1,3],
		[116,20,1,5],
		[116,47,1,3],
		[117,20,1,5],
		[117,48,1,3],
		[118,20,1,5],
		[118,48,1,3],
		[119,19,1,6],
		[119,48,1,3],
		[120,19,1,6],
		[120,48,1,3],
		[121,18,1,6],
		[121,48,1,3],
		[122,18,1,6],
		[122,48,1,3],
		[123,18,1,6],
		[123,48,1,3],
		[124,18,1,6],
		[124,48,1,3],
		[125,18,1,6],
		[125,48,1,3],
		[126,18,1,6],
		[126,48,1,3],
		[127,18,1,6],
		[127,48,1,3],
		[128,18,1,6],
		[128,48,1,3],
		[129,18,1,6],
		[129,48,1,3],
		[130,18,1,6],
		[130,47,1,3],
		[131,18,1,6],
		[131,47,1,3],
		[132,19,1,6],
		[132,47,1,3],
		[133,19,1,6],
		[133,47,1,4],
		[134,19,1,6],
		[134,47,1,4],
		[135,19,1,6],
		[135,47,1,4],
		[136,20,1,5],
		[136,47,1,4],
		[137,20,1,5],
		[137,47,1,4],
		[138,20,1,5],
		[138,47,1,4],
		[139,20,1,5],
		[139,47,1,4],
		[140,20,1,5],
		[140,47,1,4],
		[141,20,1,5],
		[141,47,1,4],
		[142,20,1,5],
		[142,47,1,4],
		[143,19,1,5],
		[143,48,1,4],
		[144,19,1,5],
		[144,48,1,4],
		[145,22,1,6],
		[145,47,1,4],
		[146,22,1,6],
		[146,47,1,4],
		[147,22,1,6],
		[147,47,1,4],
		[148,19,1,5],
		[148,48,1,4],
		[149,19,1,5],
		[149,48,1,4],
		[150,19,1,5],
		[150,48,1,4],
		[151,19,1,5],
		[151,48,1,4],
		[152,19,1,5],
		[152,48,1,3],
		[153,18,1,6],
		[153,48,1,3],
		[154,19,1,6],
		[154,48,1,3],
		[155,19,1,6],
		[155,48,1,3],
		[156,19,1,6],
		[156,47,1,3],
		[157,19,1,6],
		[157,47,1,3],
		[158,19,1,6],
		[158,47,1,3],
		[159,19,1,6],
		[159,47,1,3],
		[160,19,1,6],
		[160,47,1,3],
		[161,19,1,6],
		[161,47,1,3],
		[162,19,1,6],
		[162,47,1,3],
		[163,19,1,6],
		[163,47,1,3],
		[164,19,1,6],
		[164,47,1,3],
		[165,18,1,6],
		[165,47,1,3],
		[166,18,1,6],
		[166,47,1,3],
		[167,18,1,6],
		[167,47,1,3],
		[168,18,1,6],
		[168,47,1,3],
		[169,18,1,6],
		[169,48,1,3],
		[170,19,1,5],
		[170,48,1,3],
		[171,19,1,5],
		[171,48,1,4],
		[172,19,1,5],
		[172,48,1,4],
		[173,19,1,5],
		[173,48,1,4],
		[174,19,1,5],
		[174,48,1,4],
		[175,19,1,5],
		[175,48,1,4],
		[176,20,1,5],
		[176,48,1,4],
		[177,20,1,5],
		[177,48,1,4],
		[178,20,1,5],
		[178,48,1,4],
		[179,20,1,5],
		[179,48,1,4]
	],
	"wall_columns": [
		[0,20,5,47,3],
		[1,20,5,47,3],
		[2,20,5,47,3],
		[3,20,5,47,3],
		[4,20,5,47,3],
		[5,20,5,47,3],
		[6,20,5,47,3],
		[7,20,5,47,3],
		[8,20,5,47,3],
		[9,20,5,47,3],
		[10,20,5,47,3],
		[11,19,5,47,3],
		[12,19,5,47,3],
		[13,19,5,48,3],
		[14,19,5,48,3],
		[15,19,5,48,3],
		[16,19,5,48,3],
		[17,18,6,48,3],
		[18,18,6,48,3],
		[19,18,6,48,4],
		[20,18,6,48,4],
		[21,18,6,48,4],
		[22,19,6,48,4],
		[23,19,6,48,4],
		[24,19,6,48,4],
		[25,19,6,48,4],
		[26,19,6,47,4],
		[27,19,6,47,4],
		[28,19,6,47,4],
		[29,19,6,47,4],
		[30,19,6,47,4],
		[31,22,6,47,4],
		[32,22,6,47,4],
		[33,22,6,47,4],
		[34,19,5,47,4],
		[35,19,5,47,4],
		[36,19,5,47,4],
		[37,19,5,47,4],
		[38,19,5,47,3],
		[39,19,5,48,3],
		[40,19,5,48,3],
		[41,19,5,48,3],
		[42,19,5,48,3],
		[43,19,5,48,3],
		[44,20,5,48,3],
		[45,20,5,48,3],
		[46,20,5,48,3],
		[47,20,5,48,3],
		[48,20,5,48,3],
		[49,20,5,48,3],
		[50,20,5,48,3],
		[51,19,6,48,3],
		[52,19,6,47,3],
		[53,19,6,47,3],
		[54,19,6,47,3],
		[55,18,6,47,3],
		[56,18,6,47,3],
		[57,18,6,47,4],
		[58,18,6,47,4],
		[59,18,6,47,4],
		[60,18,6,47,4],
		[61,18,6,47,4],
		[62,18,6,47,4],
		[63,18,6,47,4],
		[64,18,6,47,4],
		[65,18,6,48,4],
		[66,19,6,48,4],
		[67,19,6,48,4],
		[68,20,5,48,4],
		[69,20,5,48,4],
		[70,20,5,48,4],
		[71,20,5,48,4],
		[72,20,5,48,4],
		[73,20,5,48,4],
		[74,20,5,48,4],
		[75,20,5,48,4],
		[76,20,5,48,3],
		[77,19,5,48,3],
		[78,19,5,47,3],
		[79,19,5,47,3],
		[80,19,5,47,3],
		[81,19,5,47,3],
		[82,19,5,47,3],
		[83,19,5,47,3],
		[84,19,5,47,3],
		[85,18,6,47,3],
		[86,18,6,47,3],
		[87,18,6,47,3],
		[88,19,6,47,3],
		[89,19,6,47,3],
		[90,19,6,47,3],
		[91,19,6,48,3],
		[92,19,6,48,3],
		[93,19,6,48,3],
		[94,19,6,48,3],
		[95,19,6,48,4],
		[96,19,6,48,4],
		[97,19,6,48,4],
		[98,19,6,48,4],
		[99,18,6,48,4],
		[100,18,6,48,4],
		[101,18,6,48,4],
		[102,19,5,48,4],
		[103,19,5,48,4],
		[104,19,5,47,4],
		[105,19,5,47,4],
		[106,19,5,47,4],
		[107,19,5,47,4],
		[108,19,5,47,4],
		[109,19,5,47,4],
		[110,20,5,47,4],
		[111,20,5,47,4],
		[112,20,5,47,4],
		[113,20,5,47,4],
		[114,20,5,47,3],
		[115,20,5,47,3],
		[116,20,5,47,3],
		[117,20,5,48,3],
		[118,20,5,48,3],
		[119,19,6,48,3],
		[120,19,6,48,3],
		[121,18,6,48,3],
		[122,18,6,48,3],
		[123,18,6,48,3],
		[124,18,6,48,3],
		[125,18,6,48,3],
		[126,18,6,48,3],
		[127,18,6,48,3],
		[128,18,6,48,3],
		[129,18,6,48,3],
		[130,18,6,47,3],
		[131,18,6,47,3],
		[132,19,6,47,3],
		[133,19,6,47,4],
		[134,19,6,47,4],
		[135,19,6,47,4],
		[136,20,5,47,4],
		[137,20,5,47,4],
		[138,20,5,47,4],
		[139,20,5,47,4],
		[140,20,5,47,4],
		[141,20,5,47,4],
		[142,20,5,47,4],
		[143,19,5,48,4],
		[144,19,5,48,4],
		[145,22,6,47,4],
		[146,22,6,47,4],
		[147,22,6,47,4],
		[148,19,5,48,4],
		[149,19,5,48,4],
		[150,19,5,48,4],
		[151,19,5,48,4],
		[152,19,5,48,3],
		[153,18,6,48,3],
		[154,19,6,48,3],
		[155,19,6,48,3],
		[156,19,6,47,3],
		[157,19,6,47,3],
		[158,19,6,47,3],
		[159,19,6,47,3],
		[160,19,6,47,3],
		[161,19,6,47,3],
		[162,19,6,47,3],
		[163,19,6,47,3],
		[164,19,6,47,3],
		[165,18,6,47,3],
		[166,18,6,47,3],
		[167,18,6,47,3],
		[168,18,6,47,3],
		[169,18,6,48,3],
		[170,19,5,48,3],
		[171,19,5,48,4],
		[172,19,5,48,4],
		[173,19,5,48,4],
		[174,19,5,48,4],
		[175,19,5,48,4],
		[176,20,5,48,4],
		[177,20,5,48,4],
		[178,20,5,48,4],
		[179,20,5,48,4]
	],
	"houses": [
		{
			"id": 0,
			"name": "제설 차고",
			"rect": [3,62,54,19],
			"walls": [
				[13,63,1,17],
				[46,63,1,17],
				[14,73,16,1],
				[29,74,1,6]
			],
			"doors": [
				[13,65],
				[46,67],
				[22,73],
				[28,62],
				[29,62],
				[39,62]
			],
			"windows": [
				[3,68],
				[3,76],
				[56,69],
				[56,77]
			],
			"rooms": [
				{
					"name": "부품 창고",
					"rect": [4,63,9,17]
				},
				{
					"name": "연료 칸",
					"rect": [47,63,9,17]
				},
				{
					"name": "정비 칸",
					"rect": [14,63,32,10]
				},
				{
					"name": "난로 방",
					"rect": [14,74,15,6]
				}
			],
			"entrances": [
				{
					"cell": [28,62],
					"outward": [0,-1]
				},
				{
					"cell": [39,62],
					"outward": [0,-1]
				}
			]
		},
		{
			"id": 1,
			"name": "고갯마루 오두막",
			"rect": [81,1,24,12],
			"walls": [
				[93,2,1,10]
			],
			"doors": [
				[93,9],
				[85,12]
			],
			"windows": [
				[84,1],
				[101,1],
				[104,5]
			],
			"rooms": [
				{
					"name": "일하던 방",
					"rect": [82,2,11,10]
				},
				{
					"name": "자던 방",
					"rect": [94,2,10,10]
				}
			],
			"entrances": []
		},
		{
			"id": 2,
			"name": "자재 헛간",
			"rect": [140,65,18,12],
			"walls": [
				[149,66,1,10]
			],
			"doors": [
				[149,73],
				[144,76]
			],
			"windows": [
				[143,65],
				[154,65],
				[157,69]
			],
			"rooms": [
				{
					"name": "연장 칸",
					"rect": [141,66,8,10]
				},
				{
					"name": "자재 칸",
					"rect": [150,66,7,10]
				}
			],
			"entrances": []
		}
	],
	"props": [
		{
			"kind": "garage_door_leaf",
			"rect": [30,62,2,1],
			"solid": "wall",
			"facing": 0,
			"note": "반쯤 닫힌 큰 문짝"
		},
		{
			"kind": "parts_rack",
			"rect": [5,64,4,1],
			"solid": "low",
			"facing": 0,
			"note": "부품 선반"
		},
		{
			"kind": "tool_rack",
			"rect": [5,68,2,1],
			"solid": "low",
			"facing": 0,
			"note": "연장 걸이"
		},
		{
			"kind": "ladder_rack",
			"rect": [5,76,4,1],
			"solid": "low",
			"facing": 0,
			"note": "사다리 걸이"
		},
		{
			"kind": "fuel_drum",
			"rect": [49,64,1,1],
			"solid": "low",
			"facing": 0,
			"note": "연료 드럼"
		},
		{
			"kind": "fuel_drum",
			"rect": [51,65,1,1],
			"solid": "low",
			"facing": 0,
			"note": "연료 드럼"
		},
		{
			"kind": "fuel_drum",
			"rect": [49,67,1,1],
			"solid": "low",
			"facing": 0,
			"note": "연료 드럼"
		},
		{
			"kind": "fuel_tank",
			"rect": [49,75,3,2],
			"solid": "low",
			"facing": 0,
			"note": "연료 탱크"
		},
		{
			"kind": "inspection_pit",
			"rect": [17,64,14,2],
			"solid": "none",
			"facing": 0,
			"note": "검수 구덩이 틀"
		},
		{
			"kind": "tool_bench",
			"rect": [15,71,2,1],
			"solid": "low",
			"facing": 0,
			"note": "연장 작업대"
		},
		{
			"kind": "tool_rack",
			"rect": [34,69,2,1],
			"solid": "low",
			"facing": 0,
			"note": "연장 걸이"
		},
		{
			"kind": "siding_buffer",
			"rect": [32,67,2,3],
			"solid": "low",
			"facing": 0,
			"note": "측선 끝 차막이"
		},
		{
			"kind": "generator",
			"rect": [36,71,2,1],
			"solid": "low",
			"facing": 0,
			"note": "발전기"
		},
		{
			"kind": "rail_plow",
			"rect": [18,67,12,3],
			"solid": "wall",
			"facing": 0,
			"note": "식은 제설기"
		},
		{
			"kind": "bed",
			"rect": [15,76,2,1],
			"solid": "low",
			"facing": 0,
			"note": "침대"
		},
		{
			"kind": "shelf",
			"rect": [23,78,3,1],
			"solid": "low",
			"facing": 0,
			"note": "선반"
		},
		{
			"kind": "firewood_pile",
			"rect": [26,76,2,1],
			"solid": "low",
			"facing": 0,
			"note": "장작 더미"
		},
		{
			"kind": "desk",
			"rect": [83,3,2,1],
			"solid": "low",
			"facing": 0,
			"note": "책상"
		},
		{
			"kind": "radio_set",
			"rect": [87,3,2,1],
			"solid": "low",
			"facing": 0,
			"note": "무전기 책상"
		},
		{
			"kind": "map_cabinet",
			"rect": [83,7,3,1],
			"solid": "low",
			"facing": 0,
			"note": "도면 서랍장"
		},
		{
			"kind": "bed",
			"rect": [95,3,2,1],
			"solid": "low",
			"facing": 0,
			"note": "침대"
		},
		{
			"kind": "shelf",
			"rect": [95,7,3,1],
			"solid": "low",
			"facing": 0,
			"note": "선반"
		},
		{
			"kind": "fuel_can_group",
			"rect": [99,5,2,1],
			"solid": "low",
			"facing": 0,
			"note": "연료통 무리"
		},
		{
			"kind": "tool_rack",
			"rect": [142,67,2,1],
			"solid": "low",
			"facing": 0,
			"note": "연장 걸이"
		},
		{
			"kind": "ladder_rack",
			"rect": [142,70,4,1],
			"solid": "low",
			"facing": 0,
			"note": "사다리 걸이"
		},
		{
			"kind": "parts_rack",
			"rect": [151,67,4,1],
			"solid": "low",
			"facing": 0,
			"note": "부품 선반"
		},
		{
			"kind": "sled_load",
			"rect": [151,71,2,1],
			"solid": "low",
			"facing": 0,
			"note": "짐 실은 썰매"
		},
		{
			"kind": "tool_rack",
			"rect": [108,3,2,1],
			"solid": "low",
			"facing": 0,
			"note": "연장 걸이"
		},
		{
			"kind": "fuel_can_group",
			"rect": [111,5,2,1],
			"solid": "low",
			"facing": 0,
			"note": "연료통 무리"
		},
		{
			"kind": "firewood_pile",
			"rect": [108,8,2,1],
			"solid": "low",
			"facing": 0,
			"note": "장작 더미"
		},
		{
			"kind": "wind_pole",
			"rect": [114,3,1,1],
			"solid": "none",
			"facing": 0,
			"note": "바람 깃 장대"
		},
		{
			"kind": "snow_gauge_pole",
			"rect": [113,9,1,1],
			"solid": "none",
			"facing": 0,
			"note": "눈금 장대"
		},
		{
			"kind": "fallen_signal",
			"rect": [57,29,5,1],
			"solid": "low",
			"facing": 0,
			"note": "쓰러진 신호기"
		},
		{
			"kind": "crate_stack",
			"rect": [87,28,2,2],
			"solid": "low",
			"facing": 0,
			"note": "자재 상자 더미"
		},
		{
			"kind": "rail_stack",
			"rect": [101,29,4,1],
			"solid": "low",
			"facing": 0,
			"note": "레일 토막 더미"
		},
		{
			"kind": "snow_bank",
			"rect": [120,26,1,6],
			"solid": "low",
			"facing": 1,
			"note": "눈 둑"
		},
		{
			"kind": "snow_bank",
			"rect": [57,46,6,1],
			"solid": "low",
			"facing": 0,
			"note": "눈 둑"
		},
		{
			"kind": "plow_blade",
			"rect": [87,46,4,2],
			"solid": "low",
			"facing": 0,
			"note": "떼어 둔 제설 날"
		},
		{
			"kind": "crate_stack",
			"rect": [101,46,2,2],
			"solid": "low",
			"facing": 0,
			"note": "자재 상자 더미"
		},
		{
			"kind": "fallen_log",
			"rect": [120,43,1,5],
			"solid": "low",
			"facing": 1,
			"note": "쓰러진 통나무"
		},
		{
			"kind": "handcart",
			"rect": [59,65,2,1],
			"solid": "low",
			"facing": 0,
			"note": "짐수레"
		},
		{
			"kind": "tool_rack",
			"rect": [62,67,2,1],
			"solid": "low",
			"facing": 0,
			"note": "연장 걸이"
		},
		{
			"kind": "snowplow_truck",
			"rect": [59,70,6,3],
			"solid": "wall",
			"facing": 0,
			"note": "제설차"
		},
		{
			"kind": "fuel_drum",
			"rect": [60,75,1,1],
			"solid": "low",
			"facing": 0,
			"note": "연료 드럼"
		},
		{
			"kind": "fuel_drum",
			"rect": [62,76,1,1],
			"solid": "low",
			"facing": 0,
			"note": "연료 드럼"
		},
		{
			"kind": "fuel_drum",
			"rect": [64,75,1,1],
			"solid": "low",
			"facing": 0,
			"note": "연료 드럼"
		},
		{
			"kind": "track_switch",
			"rect": [12,32,2,1],
			"solid": "none",
			"facing": 0,
			"note": "선로 전환기"
		},
		{
			"kind": "signal_post",
			"rect": [16,30,1,1],
			"solid": "wall",
			"facing": 0,
			"note": "기둥 신호등"
		},
		{
			"kind": "rail_marker",
			"rect": [18,32,1,1],
			"solid": "none",
			"facing": 0,
			"note": "거리 말뚝"
		},
		{
			"kind": "power_pole",
			"rect": [21,29,1,1],
			"solid": "wall",
			"facing": 0,
			"note": "전신주"
		},
		{
			"kind": "snow_drift",
			"rect": [10,28,4,2],
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
			"rect": [152,0,8,6],
			"solid": "wall",
			"facing": 0,
			"note": "산 능선"
		},
		{
			"kind": "snow_drift",
			"rect": [147,6,4,2],
			"solid": "none",
			"facing": 0,
			"note": "눈더미"
		},
		{
			"kind": "sleeper_stack",
			"rect": [39,43,3,1],
			"solid": "low",
			"facing": 0,
			"note": "침목 더미"
		},
		{
			"kind": "plow_blade",
			"rect": [14,48,4,2],
			"solid": "low",
			"facing": 0,
			"note": "서쪽 앞마당의 두 갈래 길 사이 제설 날"
		}
	],
	"trees": [
		[117,5],
		[28,2],
		[125,78],
		[36,5],
		[21,1],
		[26,3],
		[29,3],
		[37,2],
		[122,0],
		[130,74],
		[137,1],
		[138,79],
		[144,79],
		[119,5],
		[24,5],
		[139,74],
		[59,78],
		[160,3],
		[135,77],
		[29,5],
		[136,78],
		[28,1],
		[132,78],
		[62,75],
		[125,80],
		[65,77],
		[123,4],
		[29,1],
		[134,79],
		[133,3],
		[120,0],
		[122,6],
		[63,76],
		[139,76],
		[125,4],
		[18,2],
		[35,0],
		[35,4],
		[116,3],
		[135,75],
		[175,5],
		[116,2],
		[118,0],
		[58,77],
		[131,2],
		[172,4],
		[123,79],
		[35,3],
		[67,76],
		[139,3],
		[137,2],
		[173,4],
		[122,1],
		[123,0],
		[22,3],
		[132,80],
		[129,74],
		[68,79],
		[142,77],
		[58,78],
		[133,75],
		[29,0],
		[166,2],
		[65,79],
		[167,3],
		[57,76],
		[127,1],
		[118,4],
		[58,75],
		[25,0],
		[131,75],
		[138,76],
		[122,75],
		[36,0],
		[39,3],
		[65,76],
		[130,0],
		[171,3],
		[119,6],
		[139,2],
		[162,3],
		[129,6],
		[142,78],
		[31,2],
		[134,6],
		[134,75],
		[135,76],
		[132,77],
		[132,5],
		[51,81]
	],
	"gates": [
		[32,28,1,3],
		[32,44,1,3],
		[146,28,1,3],
		[146,44,1,3]
	],
	"stores": [
		{
			"id": "shed_parts",
			"name": "안쪽 부품 자재함",
			"cell": [5,78],
			"level": 0,
			"items": ["plank","cloth"]
		},
		{
			"id": "shed_fuel",
			"name": "연료 칸 보급 상자",
			"cell": [54,78],
			"level": 0,
			"items": ["cloth","flare"]
		},
		{
			"id": "shed_tools",
			"name": "정비 공구함",
			"cell": [36,65],
			"level": 0,
			"items": ["cloth","bandage"]
		},
		{
			"id": "shed_food",
			"name": "난로 방 찬장",
			"cell": [20,78],
			"level": 0,
			"items": ["food_pack","cloth"]
		},
		{
			"id": "below_parts",
			"name": "지하 부품 자재함",
			"cell": [28,65],
			"level": -1,
			"items": ["plank","cloth"]
		},
		{
			"id": "below_supply",
			"name": "지하 예비 상자",
			"cell": [32,72],
			"level": -1,
			"items": ["bandage","document"]
		},
		{
			"id": "hut_radio_notes",
			"name": "무전 기록 보관함",
			"cell": [83,5],
			"level": 0,
			"items": ["document"]
		},
		{
			"id": "hut_engine_notes",
			"name": "기관 도면 보관함",
			"cell": [87,5],
			"level": 0,
			"items": ["document"]
		},
		{
			"id": "hut_supply",
			"name": "오두막 보급 상자",
			"cell": [95,10],
			"level": 0,
			"items": ["food_pack","bandage"]
		},
		{
			"id": "outbuilding_tools",
			"name": "헛간 공구함",
			"cell": [143,74],
			"level": 0,
			"items": ["cloth"]
		},
		{
			"id": "outbuilding_wood",
			"name": "헛간 널빤지 자재함",
			"cell": [155,74],
			"level": 0,
			"items": ["wood","plank"]
		}
	],
	"salvage": [
		{
			"id": "plow_drive_1",
			"name": "제설기 구동부",
			"cell": [17,67],
			"material": "scrap",
			"amount": 2
		},
		{
			"id": "plow_drive_2",
			"name": "제설기 구동부",
			"cell": [30,67],
			"material": "scrap",
			"amount": 2
		},
		{
			"id": "plow_drive_3",
			"name": "제설기 구동부",
			"cell": [18,70],
			"material": "scrap",
			"amount": 2
		},
		{
			"id": "plow_drive_4",
			"name": "제설기 구동부",
			"cell": [29,70],
			"material": "scrap",
			"amount": 2
		},
		{
			"id": "shallow_sleepers",
			"name": "선로 곁 침목",
			"cell": [38,43],
			"material": "wood",
			"amount": 3
		},
		{
			"id": "shallow_rails",
			"name": "선로 곁 레일 토막",
			"cell": [100,29],
			"material": "scrap",
			"amount": 2
		},
		{
			"id": "shallow_log",
			"name": "벽 밑 쓰러진 나무",
			"cell": [119,43],
			"material": "wood",
			"amount": 2
		}
	],
	"stoves": [
		{
			"cell": [18,78],
			"building": 0
		},
		{
			"cell": [99,10],
			"building": 1
		}
	],
	"entries": {
		"track_west_upper": [
			[0,33],
			[0,34],
			[0,35]
		],
		"track_east_upper": [
			[179,33],
			[179,34],
			[179,35]
		],
		"track_west_lower": [
			[0,39],
			[0,40],
			[0,41]
		],
		"track_east_lower": [
			[179,39],
			[179,40],
			[179,41]
		],
		"access_road": [
			[1,81],
			[2,81],
			[3,81]
		],
		"ridge_path": [
			[92,0],
			[93,0]
		]
	},
	"dead_shed": [
		[15,64],
		[16,66],
		[31,71],
		[35,67],
		[37,69],
		[9,71],
		[10,74],
		[53,70],
		[21,76],
		[25,75]
	],
	"dead_ridge": [
		[115,7],
		[117,8],
		[119,9]
	],
	"yard": [
		[3,47,54,15]
	],
	"ramp": [
		[111,16,3,20],
		[85,14,29,2]
	],
	"cut": {
		"side": 1,
		"x": 4,
		"width": 24
	},
	"slope": {
		"side": 0,
		"x": 111,
		"width": 3
	},
	"underground": {
		"stairs": [31,65],
		"digs": [
			[27,64,8,4],
			[29,68,2,2],
			[27,70,8,4]
		],
		"rooms": [
			{
				"name": "지하 작은 부품 칸",
				"rect": [27,64,8,4]
			},
			{
				"name": "지하 큰 부품 칸",
				"rect": [27,70,8,4]
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
