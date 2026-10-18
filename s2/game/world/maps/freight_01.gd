# 이 지도가 다른 판단을 만드는 것: 석탄은 동쪽 끝, 마을은 남쪽 끝이라 한쪽만 깊이 간다.
# 위쪽의 판단: 목재를 썰매 가득 얻는 대신 아래쪽 석탄 싣기에서 사람이 빠지고, 썰매를 끌고 제재 마당을 오가는 길이 길다.
extends RefCounted

const MapShift = preload("res://game/world/map_shift.gd")
const FieldGrid = preload("res://game/world/field_grid.gd")
const S = FieldGrid.Solid
const F = FieldGrid.Floor
const PLACE_ID: String = "freight_01"
const WIDTH: int = 160
const SOUTH_HEIGHT: int = 95
const HEIGHT: int = SOUTH_HEIGHT + 45

# 좌표는 한 칸 단위다. 각 층의 방·문·가구를 독립적으로 기록한다.
const PLAN: Dictionary = {
  "id": "freight_01",
  "size": [160,95],
  "judgment": "석탄은 동쪽 끝, 마을은 남쪽 끝이라 한쪽만 깊이 간다.",
  "resource": "coal",
  "zones": [
    ["A","역 앞 마당",[0,0,160,95]],
    ["B","측선",[60,10,100,23]],
    ["C","마을 큰길",[0,30,108,33]],
    ["D","곡물 상회",[58,63,48,32]],
    ["E","농가 마당",[106,59,54,36]],
    ["F","남쪽 주택",[0,63,58,32]],
    ["G","석탄 하역장",[96,12,64,31]],
    ["H","공구 마당",[108,43,52,16]]
  ],
  "floors": [
    [0,62,33,78,7,7],
    [0,90,40,30,14,7],
    [0,61,61,41,6,7],
    [0,106,63,6,27,7],
    [0,126,61,27,13,7],
    [0,47,10,6,52,1],
    [0,47,56,27,6,1],
    [0,68,56,6,11,1],
    [0,102,43,4,52,1],
    [0,0,39,54,5,1],
    [0,47,32,72,6,1],
    [0,97,43,23,6,1],
    [0,106,77,54,5,1],
    [0,106,59,40,4,1],
    [0,62,15,78,1,4],
    [0,62,22,78,1,4]
  ],
  "buildings": [
    {"id":0,"name":"역사","rect":[16,11,30,14],"warm":false,"window_broken":false},
    {"id":1,"name":"소화물 창고","rect":[53,11,18,10],"warm":false,"window_broken":false},
    {"id":2,"name":"신호 취급소","rect":[77,12,8,7],"warm":false,"window_broken":false},
    {"id":3,"name":"석탄 적치 창고","rect":[124,22,24,12],"warm":false,"window_broken":false},
    {"id":4,"name":"하역 사무소","rect":[145,44,10,8],"warm":false,"window_broken":false},
    {"id":5,"name":"공구 창고","rect":[124,48,12,9],"warm":false,"window_broken":false},
    {"id":6,"name":"역장 관사","rect":[6,28,12,10],"warm":false,"window_broken":false},
    {"id":7,"name":"곡물 상회","rect":[62,67,40,24],"warm":false,"window_broken":false},
    {"id":8,"name":"빵집","rect":[29,29,12,9],"warm":false,"window_broken":false},
    {"id":9,"name":"식료품점","rect":[54,40,14,10],"warm":false,"window_broken":false},
    {"id":10,"name":"철물점","rect":[78,43,12,10],"warm":false,"window_broken":false},
    {"id":11,"name":"주택 가","rect":[8,48,12,10],"warm":false,"window_broken":false},
    {"id":12,"name":"주택 나","rect":[28,59,12,10],"warm":false,"window_broken":false},
    {"id":13,"name":"주택 다","rect":[8,65,11,10],"warm":false,"window_broken":false},
    {"id":14,"name":"주택 라","rect":[40,78,12,10],"warm":false,"window_broken":false},
    {"id":15,"name":"농가 집","rect":[112,65,14,10],"warm":false,"window_broken":false},
    {"id":16,"name":"농가 헛간","rect":[135,76,16,10],"warm":false,"window_broken":false}
  ],
  "shells": [
    [0,0,16,11,30,14],
    [0,1,16,11,30,14],
    [1,0,53,11,18,10],
    [2,0,77,12,8,7],
    [2,1,77,12,8,7],
    [3,0,124,22,24,12],
    [4,0,145,44,10,8],
    [5,0,124,48,12,9],
    [6,0,6,28,12,10],
    [6,1,6,28,12,10],
    [7,0,62,67,40,24],
    [7,1,62,67,40,24],
    [7,2,62,67,40,24],
    [7,-1,62,67,40,24],
    [8,0,29,29,12,9],
    [9,0,54,40,14,10],
    [10,0,78,43,12,10],
    [11,0,8,48,12,10],
    [11,1,8,48,12,10],
    [12,0,28,59,12,10],
    [12,1,28,59,12,10],
    [13,0,8,65,11,10],
    [14,0,40,78,12,10],
    [14,1,40,78,12,10],
    [15,0,112,65,14,10],
    [15,1,112,65,14,10],
    [16,0,135,76,16,10]
  ],
  "walls": [
    [0,17,16,28,1],
    [0,17,19,28,1],
    [0,30,12,1,4],
    [0,30,20,1,4],
    [1,17,16,28,1],
    [1,17,19,28,1],
    [1,30,12,1,4],
    [1,30,20,1,4],
    [0,62,12,1,8],
    [0,136,23,1,10],
    [0,130,49,1,7],
    [0,12,29,1,8],
    [1,12,29,1,8],
    [0,63,76,38,1],
    [0,63,81,38,1],
    [0,81,68,1,8],
    [0,88,68,1,8],
    [0,94,68,1,8],
    [0,68,82,1,8],
    [0,75,82,1,8],
    [0,81,82,1,8],
    [0,88,82,1,8],
    [0,94,82,1,8],
    [1,63,76,38,1],
    [1,63,81,38,1],
    [1,68,68,1,8],
    [1,75,68,1,8],
    [1,81,68,1,8],
    [1,88,68,1,8],
    [1,94,68,1,8],
    [1,68,82,1,8],
    [1,75,82,1,8],
    [1,81,82,1,8],
    [1,88,82,1,8],
    [1,94,82,1,8],
    [2,63,76,38,1],
    [2,63,81,38,1],
    [2,68,68,1,8],
    [2,75,68,1,8],
    [2,81,68,1,8],
    [2,88,68,1,8],
    [2,94,68,1,8],
    [2,68,82,1,8],
    [2,75,82,1,8],
    [2,81,82,1,8],
    [2,88,82,1,8],
    [2,94,82,1,8],
    [-1,63,76,38,1],
    [-1,63,81,38,1],
    [-1,68,68,1,8],
    [-1,75,68,1,8],
    [-1,81,68,1,8],
    [-1,88,68,1,8],
    [-1,94,68,1,8],
    [-1,68,82,1,8],
    [-1,75,82,1,8],
    [-1,81,82,1,8],
    [-1,88,82,1,8],
    [-1,94,82,1,8],
    [0,30,33,10,1],
    [0,55,45,12,1],
    [0,79,48,10,1],
    [0,14,49,1,8],
    [1,14,49,1,8],
    [0,34,60,1,8],
    [1,34,60,1,8],
    [0,13,66,1,8],
    [0,46,79,1,8],
    [1,46,79,1,8],
    [0,119,66,1,8],
    [1,119,66,1,8],
    [0,143,77,1,8]
  ],
  "openings": [],
  "doors": [
    [0,23,16,0,"closed",0,1],
    [0,37,16,0,"closed",0,1],
    [0,23,19,0,"closed",0,-1],
    [0,37,19,0,"closed",0,-1],
    [1,23,16,0,"closed",0,1],
    [1,37,16,0,"closed",0,1],
    [1,23,19,0,"closed",0,-1],
    [1,37,19,0,"closed",0,-1],
    [0,26,11,0,"closed",0,-1],
    [0,43,24,0,"closed",0,1],
    [0,62,16,1,"closed",1,0],
    [0,59,11,1,"closed",0,-1],
    [0,68,20,1,"closed",0,1],
    [0,79,12,2,"closed",0,-1],
    [0,82,18,2,"closed",0,1],
    [0,136,28,3,"closed",1,0],
    [0,124,28,3,"closed",-1,0],
    [0,147,28,3,"closed",1,0],
    [0,148,44,4,"closed",0,-1],
    [0,152,51,4,"closed",0,1],
    [0,130,52,5,"closed",1,0],
    [0,128,48,5,"closed",0,-1],
    [0,133,56,5,"closed",0,1],
    [0,12,33,6,"closed",1,0],
    [1,12,33,6,"closed",1,0],
    [0,10,28,6,"closed",0,-1],
    [0,15,37,6,"closed",0,1],
    [0,71,76,7,"closed",0,1],
    [0,84,76,7,"closed",0,1],
    [0,91,76,7,"closed",0,1],
    [0,97,76,7,"closed",0,1],
    [0,65,81,7,"closed",0,-1],
    [0,71,81,7,"closed",0,-1],
    [0,78,81,7,"closed",0,-1],
    [0,84,81,7,"closed",0,-1],
    [0,91,81,7,"closed",0,-1],
    [0,97,81,7,"closed",0,-1],
    [1,65,76,7,"closed",0,1],
    [1,71,76,7,"closed",0,1],
    [1,78,76,7,"closed",0,1],
    [1,84,76,7,"closed",0,1],
    [1,91,76,7,"closed",0,1],
    [1,97,76,7,"closed",0,1],
    [1,65,81,7,"closed",0,-1],
    [1,71,81,7,"closed",0,-1],
    [1,78,81,7,"closed",0,-1],
    [1,84,81,7,"closed",0,-1],
    [1,91,81,7,"closed",0,-1],
    [1,97,81,7,"closed",0,-1],
    [2,65,76,7,"closed",0,1],
    [2,71,76,7,"closed",0,1],
    [2,78,76,7,"closed",0,1],
    [2,84,76,7,"closed",0,1],
    [2,91,76,7,"closed",0,1],
    [2,97,76,7,"closed",0,1],
    [2,65,81,7,"closed",0,-1],
    [2,71,81,7,"closed",0,-1],
    [2,78,81,7,"closed",0,-1],
    [2,84,81,7,"closed",0,-1],
    [2,91,81,7,"closed",0,-1],
    [2,97,81,7,"closed",0,-1],
    [-1,65,76,7,"closed",0,1],
    [-1,71,76,7,"closed",0,1],
    [-1,78,76,7,"closed",0,1],
    [-1,84,76,7,"closed",0,1],
    [-1,91,76,7,"closed",0,1],
    [-1,97,76,7,"closed",0,1],
    [-1,65,81,7,"closed",0,-1],
    [-1,71,81,7,"closed",0,-1],
    [-1,78,81,7,"closed",0,-1],
    [-1,84,81,7,"closed",0,-1],
    [-1,91,81,7,"closed",0,-1],
    [-1,97,81,7,"closed",0,-1],
    [0,75,67,7,"closed",0,-1],
    [0,62,77,7,"closed",-1,0],
    [0,101,77,7,"closed",1,0],
    [0,38,33,8,"closed",0,1],
    [0,33,29,8,"closed",0,-1],
    [0,38,37,8,"closed",0,1],
    [0,65,45,9,"closed",0,1],
    [0,58,40,9,"closed",0,-1],
    [0,65,49,9,"closed",0,1],
    [0,87,48,10,"closed",0,1],
    [0,82,43,10,"closed",0,-1],
    [0,87,52,10,"closed",0,1],
    [0,14,53,11,"closed",1,0],
    [1,14,53,11,"closed",1,0],
    [0,12,48,11,"closed",0,-1],
    [0,17,57,11,"closed",0,1],
    [0,34,64,12,"closed",1,0],
    [1,34,64,12,"closed",1,0],
    [0,32,59,12,"closed",0,-1],
    [0,37,68,12,"closed",0,1],
    [0,13,70,13,"closed",1,0],
    [0,11,65,13,"closed",0,-1],
    [0,16,74,13,"closed",0,1],
    [0,46,83,14,"closed",1,0],
    [1,46,83,14,"closed",1,0],
    [0,44,78,14,"closed",0,-1],
    [0,49,87,14,"closed",0,1],
    [0,119,70,15,"closed",1,0],
    [1,119,70,15,"closed",1,0],
    [0,116,65,15,"closed",0,-1],
    [0,123,74,15,"closed",0,1],
    [0,143,81,16,"closed",1,0],
    [0,140,76,16,"closed",0,-1],
    [0,148,85,16,"closed",0,1]
  ],
  "windows": [
    [0,19,11,0],
    [0,26,11,0],
    [0,33,11,0],
    [0,40,11,0],
    [0,45,14,0],
    [0,45,20,0],
    [1,19,11,0],
    [1,26,11,0],
    [1,33,11,0],
    [1,40,11,0],
    [1,45,14,0],
    [1,45,20,0],
    [0,56,11,1],
    [0,63,11,1],
    [0,70,14,1],
    [0,80,12,2],
    [0,84,15,2],
    [1,80,12,2],
    [1,84,15,2],
    [0,127,22,3],
    [0,134,22,3],
    [0,141,22,3],
    [0,147,25,3],
    [0,147,31,3],
    [0,148,44,4],
    [0,154,47,4],
    [0,127,48,5],
    [0,135,51,5],
    [0,9,28,6],
    [0,17,31,6],
    [1,9,28,6],
    [1,17,31,6],
    [0,65,67,7],
    [0,72,67,7],
    [0,79,67,7],
    [0,86,67,7],
    [0,93,67,7],
    [0,101,70,7],
    [0,101,76,7],
    [0,101,82,7],
    [0,101,88,7],
    [1,65,67,7],
    [1,72,67,7],
    [1,79,67,7],
    [1,86,67,7],
    [1,93,67,7],
    [1,101,70,7],
    [1,101,76,7],
    [1,101,82,7],
    [1,101,88,7],
    [2,65,67,7],
    [2,72,67,7],
    [2,79,67,7],
    [2,86,67,7],
    [2,93,67,7],
    [2,101,70,7],
    [2,101,76,7],
    [2,101,82,7],
    [2,101,88,7],
    [0,32,29,8],
    [0,40,32,8],
    [0,57,40,9],
    [0,64,40,9],
    [0,67,43,9],
    [0,81,43,10],
    [0,89,46,10],
    [0,11,48,11],
    [0,19,51,11],
    [1,11,48,11],
    [1,19,51,11],
    [0,31,59,12],
    [0,39,62,12],
    [1,31,59,12],
    [1,39,62,12],
    [0,11,65,13],
    [0,18,68,13],
    [0,43,78,14],
    [0,51,81,14],
    [1,43,78,14],
    [1,51,81,14],
    [0,115,65,15],
    [0,122,65,15],
    [0,125,68,15],
    [1,115,65,15],
    [1,122,65,15],
    [1,125,68,15],
    [0,138,76,16],
    [0,145,76,16],
    [0,150,79,16]
  ],
  "rooms": [
    {"building":0,"level":0,"rect":[17,12,13,4],"name":"사무실"},
    {"building":0,"level":0,"rect":[31,12,14,4],"name":"선별실"},
    {"building":0,"level":0,"rect":[17,20,13,4],"name":"사무실"},
    {"building":0,"level":0,"rect":[31,20,14,4],"name":"선별실"},
    {"building":0,"level":1,"rect":[17,12,13,4],"name":"사무실"},
    {"building":0,"level":1,"rect":[31,12,14,4],"name":"선별실"},
    {"building":0,"level":1,"rect":[17,20,13,4],"name":"사무실"},
    {"building":0,"level":1,"rect":[31,20,14,4],"name":"선별실"},
    {"building":1,"level":0,"rect":[54,12,8,8],"name":"앞방"},
    {"building":1,"level":0,"rect":[63,12,7,8],"name":"안쪽 방"},
    {"building":2,"level":0,"rect":[78,13,6,5],"name":"작업실"},
    {"building":2,"level":1,"rect":[78,13,6,5],"name":"작업실"},
    {"building":3,"level":0,"rect":[125,23,11,10],"name":"앞방"},
    {"building":3,"level":0,"rect":[137,23,10,10],"name":"안쪽 방"},
    {"building":4,"level":0,"rect":[146,45,8,6],"name":"작업실"},
    {"building":5,"level":0,"rect":[125,49,5,7],"name":"앞방"},
    {"building":5,"level":0,"rect":[131,49,4,7],"name":"안쪽 방"},
    {"building":6,"level":0,"rect":[7,29,5,8],"name":"앞방"},
    {"building":6,"level":0,"rect":[13,29,4,8],"name":"안쪽 방"},
    {"building":6,"level":1,"rect":[7,29,5,8],"name":"앞방"},
    {"building":6,"level":1,"rect":[13,29,4,8],"name":"안쪽 방"},
    {"building":7,"level":0,"rect":[63,68,18,8],"name":"판매 홀"},
    {"building":7,"level":0,"rect":[82,68,6,8],"name":"계량실"},
    {"building":7,"level":0,"rect":[89,68,5,8],"name":"안쪽 창고"},
    {"building":7,"level":0,"rect":[95,68,6,8],"name":"기록실"},
    {"building":7,"level":0,"rect":[63,82,5,8],"name":"사무실"},
    {"building":7,"level":0,"rect":[69,82,6,8],"name":"선별실"},
    {"building":7,"level":0,"rect":[76,82,5,8],"name":"선반 칸"},
    {"building":7,"level":0,"rect":[82,82,6,8],"name":"계량실"},
    {"building":7,"level":0,"rect":[89,82,5,8],"name":"안쪽 창고"},
    {"building":7,"level":0,"rect":[95,82,6,8],"name":"기록실"},
    {"building":7,"level":1,"rect":[63,68,5,8],"name":"사무실"},
    {"building":7,"level":1,"rect":[69,68,6,8],"name":"선별실"},
    {"building":7,"level":1,"rect":[76,68,5,8],"name":"판매 홀"},
    {"building":7,"level":1,"rect":[82,68,6,8],"name":"계량실"},
    {"building":7,"level":1,"rect":[89,68,5,8],"name":"안쪽 창고"},
    {"building":7,"level":1,"rect":[95,68,6,8],"name":"기록실"},
    {"building":7,"level":1,"rect":[63,82,5,8],"name":"사무실"},
    {"building":7,"level":1,"rect":[69,82,6,8],"name":"선별실"},
    {"building":7,"level":1,"rect":[76,82,5,8],"name":"선반 칸"},
    {"building":7,"level":1,"rect":[82,82,6,8],"name":"계량실"},
    {"building":7,"level":1,"rect":[89,82,5,8],"name":"안쪽 창고"},
    {"building":7,"level":1,"rect":[95,82,6,8],"name":"기록실"},
    {"building":7,"level":2,"rect":[63,68,5,8],"name":"사무실"},
    {"building":7,"level":2,"rect":[69,68,6,8],"name":"선별실"},
    {"building":7,"level":2,"rect":[76,68,5,8],"name":"판매 홀"},
    {"building":7,"level":2,"rect":[82,68,6,8],"name":"계량실"},
    {"building":7,"level":2,"rect":[89,68,5,8],"name":"안쪽 창고"},
    {"building":7,"level":2,"rect":[95,68,6,8],"name":"기록실"},
    {"building":7,"level":2,"rect":[63,82,5,8],"name":"사무실"},
    {"building":7,"level":2,"rect":[69,82,6,8],"name":"선별실"},
    {"building":7,"level":2,"rect":[76,82,5,8],"name":"선반 칸"},
    {"building":7,"level":2,"rect":[82,82,6,8],"name":"계량실"},
    {"building":7,"level":2,"rect":[89,82,5,8],"name":"안쪽 창고"},
    {"building":7,"level":2,"rect":[95,82,6,8],"name":"기록실"},
    {"building":7,"level":-1,"rect":[63,68,5,8],"name":"저장고"},
    {"building":7,"level":-1,"rect":[69,68,6,8],"name":"냉기 칸"},
    {"building":7,"level":-1,"rect":[76,68,5,8],"name":"안쪽 보관실"},
    {"building":7,"level":-1,"rect":[82,68,6,8],"name":"저장고"},
    {"building":7,"level":-1,"rect":[89,68,5,8],"name":"냉기 칸"},
    {"building":7,"level":-1,"rect":[95,68,6,8],"name":"안쪽 보관실"},
    {"building":7,"level":-1,"rect":[63,82,5,8],"name":"저장고"},
    {"building":7,"level":-1,"rect":[69,82,6,8],"name":"냉기 칸"},
    {"building":7,"level":-1,"rect":[76,82,5,8],"name":"안쪽 보관실"},
    {"building":7,"level":-1,"rect":[82,82,6,8],"name":"저장고"},
    {"building":7,"level":-1,"rect":[89,82,5,8],"name":"냉기 칸"},
    {"building":7,"level":-1,"rect":[95,82,6,8],"name":"안쪽 보관실"},
    {"building":8,"level":0,"rect":[30,30,10,3],"name":"매장"},
    {"building":8,"level":0,"rect":[30,34,10,3],"name":"뒤 창고"},
    {"building":9,"level":0,"rect":[55,41,12,4],"name":"매장"},
    {"building":9,"level":0,"rect":[55,46,12,3],"name":"뒤 창고"},
    {"building":10,"level":0,"rect":[79,44,10,4],"name":"매장"},
    {"building":10,"level":0,"rect":[79,49,10,3],"name":"뒤 창고"},
    {"building":11,"level":0,"rect":[9,49,5,8],"name":"앞방"},
    {"building":11,"level":0,"rect":[15,49,4,8],"name":"안쪽 방"},
    {"building":11,"level":1,"rect":[9,49,5,8],"name":"앞방"},
    {"building":11,"level":1,"rect":[15,49,4,8],"name":"안쪽 방"},
    {"building":12,"level":0,"rect":[29,60,5,8],"name":"앞방"},
    {"building":12,"level":0,"rect":[35,60,4,8],"name":"안쪽 방"},
    {"building":12,"level":1,"rect":[29,60,5,8],"name":"앞방"},
    {"building":12,"level":1,"rect":[35,60,4,8],"name":"안쪽 방"},
    {"building":13,"level":0,"rect":[9,66,4,8],"name":"앞방"},
    {"building":13,"level":0,"rect":[14,66,4,8],"name":"안쪽 방"},
    {"building":14,"level":0,"rect":[41,79,5,8],"name":"앞방"},
    {"building":14,"level":0,"rect":[47,79,4,8],"name":"안쪽 방"},
    {"building":14,"level":1,"rect":[41,79,5,8],"name":"앞방"},
    {"building":14,"level":1,"rect":[47,79,4,8],"name":"안쪽 방"},
    {"building":15,"level":0,"rect":[113,66,6,8],"name":"앞방"},
    {"building":15,"level":0,"rect":[120,66,5,8],"name":"안쪽 방"},
    {"building":15,"level":1,"rect":[113,66,6,8],"name":"앞방"},
    {"building":15,"level":1,"rect":[120,66,5,8],"name":"안쪽 방"},
    {"building":16,"level":0,"rect":[136,77,7,8],"name":"앞방"},
    {"building":16,"level":0,"rect":[144,77,6,8],"name":"안쪽 방"}
  ],
  "stairs": [
    {"cell":[18,17],"low":0,"high":1,"ladder":false},
    {"cell":[43,17],"low":0,"high":1,"ladder":false},
    {"cell":[79,14],"low":0,"high":1,"ladder":false},
    {"cell":[8,30],"low":0,"high":1,"ladder":false},
    {"cell":[64,77],"low":0,"high":1,"ladder":false},
    {"cell":[64,77],"low":1,"high":2,"ladder":false},
    {"cell":[64,77],"low":-1,"high":0,"ladder":false},
    {"cell":[99,77],"low":0,"high":1,"ladder":false},
    {"cell":[99,77],"low":1,"high":2,"ladder":false},
    {"cell":[99,77],"low":-1,"high":0,"ladder":false},
    {"cell":[10,50],"low":0,"high":1,"ladder":false},
    {"cell":[30,61],"low":0,"high":1,"ladder":false},
    {"cell":[42,80],"low":0,"high":1,"ladder":false},
    {"cell":[114,67],"low":0,"high":1,"ladder":false}
  ],
  "props": [
    {"kind":"coal_wagon","rect":[90,15,10,3],"solid":"wagon","facing":0,"note":"석탄 화차","level":0},
    {"kind":"coal_wagon","rect":[106,15,10,3],"solid":"wagon","facing":0,"note":"석탄 화차","level":0},
    {"kind":"box_wagon","rect":[88,22,11,3],"solid":"wagon","facing":0,"note":"문 열린 화차","level":0},
    {"kind":"coal_hopper","rect":[137,15,3,3],"solid":"wall","facing":0,"note":"석탄 호퍼","level":0},
    {"kind":"water_tower","rect":[149,23,5,5],"solid":"wall","facing":0,"note":"급수탑","level":0},
    {"kind":"coal_heap","rect":[124,17,3,2],"solid":"low","facing":0,"note":"석탄 더미","level":0},
    {"kind":"car","rect":[42,45,4,2],"solid":"low","facing":0,"note":"버려진 차","level":0},
    {"kind":"car","rect":[108,80,4,2],"solid":"low","facing":0,"note":"버려진 차","level":0},
    {"kind":"platform_cart","rect":[28,8,2,1],"solid":"low","facing":0,"note":"승강장 짐수레","level":0},
    {"kind":"sleeper_pile","rect":[54,8,3,2],"solid":"low","facing":0,"note":"침목 더미","level":0},
    {"kind":"bench","rect":[18,26,3,1],"solid":"low","facing":0,"note":"긴 의자","level":0},
    {"kind":"crate_stack","rect":[87,24,2,2],"solid":"low","facing":0,"note":"나무 상자 더미","level":0},
    {"kind":"desk","rect":[17,12,2,1],"solid":"none","facing":0,"note":"역사 사무실 책상","level":1},
    {"kind":"file_cabinet","rect":[27,15,2,1],"solid":"none","facing":0,"note":"역사 사무실 기술 서류함","level":1},
    {"kind":"conductor_log_chest","rect":[17,15,2,1],"solid":"none","facing":0,"note":"역사 사무실 차장 일지 궤","level":1},
    {"kind":"desk","rect":[31,12,2,1],"solid":"none","facing":0,"note":"역사 선별실 책상","level":1},
    {"kind":"file_cabinet","rect":[42,15,2,1],"solid":"none","facing":0,"note":"역사 선별실 기술 서류함","level":1},
    {"kind":"conductor_log_chest","rect":[31,15,2,1],"solid":"none","facing":0,"note":"역사 선별실 차장 일지 궤","level":1},
    {"kind":"desk","rect":[17,20,2,1],"solid":"none","facing":0,"note":"역사 사무실 책상","level":1},
    {"kind":"file_cabinet","rect":[27,23,2,1],"solid":"none","facing":0,"note":"역사 사무실 기술 서류함","level":1},
    {"kind":"conductor_log_chest","rect":[17,23,2,1],"solid":"none","facing":0,"note":"역사 사무실 차장 일지 궤","level":1},
    {"kind":"desk","rect":[31,20,2,1],"solid":"none","facing":0,"note":"역사 선별실 책상","level":1},
    {"kind":"file_cabinet","rect":[42,23,2,1],"solid":"none","facing":0,"note":"역사 선별실 기술 서류함","level":1},
    {"kind":"conductor_log_chest","rect":[31,23,2,1],"solid":"none","facing":0,"note":"역사 선별실 차장 일지 궤","level":1},
    {"kind":"desk","rect":[78,13,2,1],"solid":"none","facing":0,"note":"신호 취급소 작업실 책상","level":1},
    {"kind":"file_cabinet","rect":[81,17,2,1],"solid":"none","facing":0,"note":"신호 취급소 작업실 기술 서류함","level":1},
    {"kind":"conductor_log_chest","rect":[78,17,2,1],"solid":"none","facing":0,"note":"신호 취급소 작업실 차장 일지 궤","level":1},
    {"kind":"shelf","rect":[125,23,3,1],"solid":"low","facing":0,"note":"석탄 적치 창고 앞방 선반","level":0},
    {"kind":"part_crate","rect":[133,32,1,1],"solid":"low","facing":0,"note":"석탄 적치 창고 앞방 부품 상자","level":0},
    {"kind":"barrel","rect":[125,32,1,1],"solid":"low","facing":0,"note":"석탄 적치 창고 앞방 통","level":0},
    {"kind":"shelf","rect":[137,23,3,1],"solid":"low","facing":0,"note":"석탄 적치 창고 안쪽 방 선반","level":0},
    {"kind":"part_crate","rect":[144,32,1,1],"solid":"low","facing":0,"note":"석탄 적치 창고 안쪽 방 부품 상자","level":0},
    {"kind":"barrel","rect":[137,32,1,1],"solid":"low","facing":0,"note":"석탄 적치 창고 안쪽 방 통","level":0},
    {"kind":"desk","rect":[146,45,2,1],"solid":"low","facing":0,"note":"하역 사무소 작업실 책상","level":0},
    {"kind":"file_cabinet","rect":[146,50,2,1],"solid":"low","facing":0,"note":"하역 사무소 작업실 기술 서류함","level":0},
    {"kind":"conductor_log_chest","rect":[152,45,2,1],"solid":"low","facing":0,"note":"하역 사무소 작업실 차장 일지 궤","level":0},
    {"kind":"shelf","rect":[125,49,3,1],"solid":"low","facing":0,"note":"공구 창고 앞방 선반","level":0},
    {"kind":"part_crate","rect":[127,55,1,1],"solid":"low","facing":0,"note":"공구 창고 앞방 부품 상자","level":0},
    {"kind":"barrel","rect":[125,55,1,1],"solid":"low","facing":0,"note":"공구 창고 앞방 통","level":0},
    {"kind":"shelf","rect":[131,49,3,1],"solid":"low","facing":0,"note":"공구 창고 안쪽 방 선반","level":0},
    {"kind":"part_crate","rect":[132,55,1,1],"solid":"low","facing":0,"note":"공구 창고 안쪽 방 부품 상자","level":0},
    {"kind":"barrel","rect":[131,55,1,1],"solid":"low","facing":0,"note":"공구 창고 안쪽 방 통","level":0},
    {"kind":"bed","rect":[7,29,2,1],"solid":"none","facing":0,"note":"역장 관사 앞방 침대","level":1},
    {"kind":"desk","rect":[9,36,2,1],"solid":"none","facing":0,"note":"역장 관사 앞방 책상","level":1},
    {"kind":"part_crate","rect":[11,35,1,1],"solid":"none","facing":0,"note":"앞방 부품 상자","level":1},
    {"kind":"bed","rect":[13,29,2,1],"solid":"none","facing":0,"note":"역장 관사 안쪽 방 침대","level":1},
    {"kind":"desk","rect":[14,36,2,1],"solid":"none","facing":0,"note":"역장 관사 안쪽 방 책상","level":1},
    {"kind":"part_crate","rect":[16,35,1,1],"solid":"none","facing":0,"note":"안쪽 방 부품 상자","level":1},
    {"kind":"display_shelf","rect":[64,69,4,1],"solid":"low","facing":0,"note":"진열대","level":0},
    {"kind":"display_shelf","rect":[76,69,4,1],"solid":"low","facing":0,"note":"진열대","level":0},
    {"kind":"display_shelf","rect":[64,72,4,1],"solid":"low","facing":0,"note":"진열대","level":0},
    {"kind":"display_shelf","rect":[76,72,4,1],"solid":"low","facing":0,"note":"진열대","level":0},
    {"kind":"checkout","rect":[68,68,2,1],"solid":"low","facing":0,"note":"계산대","level":0},
    {"kind":"checkout","rect":[71,68,2,1],"solid":"low","facing":0,"note":"계산대","level":0},
    {"kind":"shopping_cart","rect":[80,68,1,1],"solid":"low","facing":0,"note":"장보기 수레","level":0},
    {"kind":"shelf","rect":[82,68,3,1],"solid":"low","facing":0,"note":"곡물 상회 계량실 선반","level":0},
    {"kind":"part_crate","rect":[85,75,1,1],"solid":"low","facing":0,"note":"곡물 상회 계량실 부품 상자","level":0},
    {"kind":"barrel","rect":[82,75,1,1],"solid":"low","facing":0,"note":"곡물 상회 계량실 통","level":0},
    {"kind":"shelf","rect":[89,68,3,1],"solid":"low","facing":0,"note":"곡물 상회 안쪽 창고 선반","level":0},
    {"kind":"part_crate","rect":[89,75,1,1],"solid":"low","facing":0,"note":"곡물 상회 안쪽 창고 부품 상자","level":0},
    {"kind":"barrel","rect":[92,68,1,1],"solid":"low","facing":0,"note":"곡물 상회 안쪽 창고 통","level":0},
    {"kind":"shelf","rect":[95,68,3,1],"solid":"low","facing":0,"note":"곡물 상회 기록실 선반","level":0},
    {"kind":"part_crate","rect":[98,75,1,1],"solid":"low","facing":0,"note":"곡물 상회 기록실 부품 상자","level":0},
    {"kind":"barrel","rect":[95,75,1,1],"solid":"low","facing":0,"note":"곡물 상회 기록실 통","level":0},
    {"kind":"shelf","rect":[63,89,3,1],"solid":"low","facing":0,"note":"곡물 상회 사무실 선반","level":0},
    {"kind":"part_crate","rect":[63,82,1,1],"solid":"low","facing":0,"note":"곡물 상회 사무실 부품 상자","level":0},
    {"kind":"barrel","rect":[66,82,1,1],"solid":"low","facing":0,"note":"곡물 상회 사무실 통","level":0},
    {"kind":"shelf","rect":[69,89,3,1],"solid":"low","facing":0,"note":"곡물 상회 선별실 선반","level":0},
    {"kind":"part_crate","rect":[69,82,1,1],"solid":"low","facing":0,"note":"곡물 상회 선별실 부품 상자","level":0},
    {"kind":"barrel","rect":[72,89,1,1],"solid":"low","facing":0,"note":"곡물 상회 선별실 통","level":0},
    {"kind":"shelf","rect":[76,89,3,1],"solid":"low","facing":0,"note":"곡물 상회 선반 칸 선반","level":0},
    {"kind":"part_crate","rect":[76,82,1,1],"solid":"low","facing":0,"note":"곡물 상회 선반 칸 부품 상자","level":0},
    {"kind":"barrel","rect":[79,82,1,1],"solid":"low","facing":0,"note":"곡물 상회 선반 칸 통","level":0},
    {"kind":"shelf","rect":[82,89,3,1],"solid":"low","facing":0,"note":"곡물 상회 계량실 선반","level":0},
    {"kind":"part_crate","rect":[82,82,1,1],"solid":"low","facing":0,"note":"곡물 상회 계량실 부품 상자","level":0},
    {"kind":"barrel","rect":[85,89,1,1],"solid":"low","facing":0,"note":"곡물 상회 계량실 통","level":0},
    {"kind":"shelf","rect":[89,89,3,1],"solid":"low","facing":0,"note":"곡물 상회 안쪽 창고 선반","level":0},
    {"kind":"part_crate","rect":[89,82,1,1],"solid":"low","facing":0,"note":"곡물 상회 안쪽 창고 부품 상자","level":0},
    {"kind":"barrel","rect":[92,82,1,1],"solid":"low","facing":0,"note":"곡물 상회 안쪽 창고 통","level":0},
    {"kind":"shelf","rect":[95,89,3,1],"solid":"low","facing":0,"note":"곡물 상회 기록실 선반","level":0},
    {"kind":"part_crate","rect":[95,82,1,1],"solid":"low","facing":0,"note":"곡물 상회 기록실 부품 상자","level":0},
    {"kind":"barrel","rect":[98,89,1,1],"solid":"low","facing":0,"note":"곡물 상회 기록실 통","level":0},
    {"kind":"shelf","rect":[63,68,3,1],"solid":"none","facing":0,"note":"곡물 상회 사무실 선반","level":1},
    {"kind":"part_crate","rect":[63,75,1,1],"solid":"none","facing":0,"note":"곡물 상회 사무실 부품 상자","level":1},
    {"kind":"barrel","rect":[66,68,1,1],"solid":"none","facing":0,"note":"곡물 상회 사무실 통","level":1},
    {"kind":"shelf","rect":[69,68,3,1],"solid":"none","facing":0,"note":"곡물 상회 선별실 선반","level":1},
    {"kind":"part_crate","rect":[72,75,1,1],"solid":"none","facing":0,"note":"곡물 상회 선별실 부품 상자","level":1},
    {"kind":"barrel","rect":[69,75,1,1],"solid":"none","facing":0,"note":"곡물 상회 선별실 통","level":1},
    {"kind":"display_shelf","rect":[76,68,4,1],"solid":"none","facing":0,"note":"곡물 상회 판매 홀 진열대","level":1},
    {"kind":"checkout","rect":[76,75,2,1],"solid":"none","facing":0,"note":"곡물 상회 판매 홀 계산대","level":1},
    {"kind":"part_crate","rect":[80,74,1,1],"solid":"none","facing":0,"note":"판매 홀 부품 상자","level":1},
    {"kind":"shelf","rect":[82,68,3,1],"solid":"none","facing":0,"note":"곡물 상회 계량실 선반","level":1},
    {"kind":"part_crate","rect":[85,75,1,1],"solid":"none","facing":0,"note":"곡물 상회 계량실 부품 상자","level":1},
    {"kind":"barrel","rect":[82,75,1,1],"solid":"none","facing":0,"note":"곡물 상회 계량실 통","level":1},
    {"kind":"shelf","rect":[89,68,3,1],"solid":"none","facing":0,"note":"곡물 상회 안쪽 창고 선반","level":1},
    {"kind":"part_crate","rect":[89,75,1,1],"solid":"none","facing":0,"note":"곡물 상회 안쪽 창고 부품 상자","level":1},
    {"kind":"barrel","rect":[92,68,1,1],"solid":"none","facing":0,"note":"곡물 상회 안쪽 창고 통","level":1},
    {"kind":"shelf","rect":[95,68,3,1],"solid":"none","facing":0,"note":"곡물 상회 기록실 선반","level":1},
    {"kind":"part_crate","rect":[98,75,1,1],"solid":"none","facing":0,"note":"곡물 상회 기록실 부품 상자","level":1},
    {"kind":"barrel","rect":[95,75,1,1],"solid":"none","facing":0,"note":"곡물 상회 기록실 통","level":1},
    {"kind":"shelf","rect":[63,89,3,1],"solid":"none","facing":0,"note":"곡물 상회 사무실 선반","level":1},
    {"kind":"part_crate","rect":[63,82,1,1],"solid":"none","facing":0,"note":"곡물 상회 사무실 부품 상자","level":1},
    {"kind":"barrel","rect":[66,82,1,1],"solid":"none","facing":0,"note":"곡물 상회 사무실 통","level":1},
    {"kind":"shelf","rect":[69,89,3,1],"solid":"none","facing":0,"note":"곡물 상회 선별실 선반","level":1},
    {"kind":"part_crate","rect":[69,82,1,1],"solid":"none","facing":0,"note":"곡물 상회 선별실 부품 상자","level":1},
    {"kind":"barrel","rect":[72,89,1,1],"solid":"none","facing":0,"note":"곡물 상회 선별실 통","level":1},
    {"kind":"shelf","rect":[76,89,3,1],"solid":"none","facing":0,"note":"곡물 상회 선반 칸 선반","level":1},
    {"kind":"part_crate","rect":[76,82,1,1],"solid":"none","facing":0,"note":"곡물 상회 선반 칸 부품 상자","level":1},
    {"kind":"barrel","rect":[79,82,1,1],"solid":"none","facing":0,"note":"곡물 상회 선반 칸 통","level":1},
    {"kind":"shelf","rect":[82,89,3,1],"solid":"none","facing":0,"note":"곡물 상회 계량실 선반","level":1},
    {"kind":"part_crate","rect":[82,82,1,1],"solid":"none","facing":0,"note":"곡물 상회 계량실 부품 상자","level":1},
    {"kind":"barrel","rect":[85,89,1,1],"solid":"none","facing":0,"note":"곡물 상회 계량실 통","level":1},
    {"kind":"shelf","rect":[89,89,3,1],"solid":"none","facing":0,"note":"곡물 상회 안쪽 창고 선반","level":1},
    {"kind":"part_crate","rect":[89,82,1,1],"solid":"none","facing":0,"note":"곡물 상회 안쪽 창고 부품 상자","level":1},
    {"kind":"barrel","rect":[92,82,1,1],"solid":"none","facing":0,"note":"곡물 상회 안쪽 창고 통","level":1},
    {"kind":"shelf","rect":[95,89,3,1],"solid":"none","facing":0,"note":"곡물 상회 기록실 선반","level":1},
    {"kind":"part_crate","rect":[95,82,1,1],"solid":"none","facing":0,"note":"곡물 상회 기록실 부품 상자","level":1},
    {"kind":"barrel","rect":[98,89,1,1],"solid":"none","facing":0,"note":"곡물 상회 기록실 통","level":1},
    {"kind":"shelf","rect":[63,68,3,1],"solid":"none","facing":0,"note":"곡물 상회 사무실 선반","level":2},
    {"kind":"part_crate","rect":[63,75,1,1],"solid":"none","facing":0,"note":"곡물 상회 사무실 부품 상자","level":2},
    {"kind":"barrel","rect":[66,68,1,1],"solid":"none","facing":0,"note":"곡물 상회 사무실 통","level":2},
    {"kind":"shelf","rect":[69,68,3,1],"solid":"none","facing":0,"note":"곡물 상회 선별실 선반","level":2},
    {"kind":"part_crate","rect":[72,75,1,1],"solid":"none","facing":0,"note":"곡물 상회 선별실 부품 상자","level":2},
    {"kind":"barrel","rect":[69,75,1,1],"solid":"none","facing":0,"note":"곡물 상회 선별실 통","level":2},
    {"kind":"display_shelf","rect":[76,68,4,1],"solid":"none","facing":0,"note":"곡물 상회 판매 홀 진열대","level":2},
    {"kind":"checkout","rect":[76,75,2,1],"solid":"none","facing":0,"note":"곡물 상회 판매 홀 계산대","level":2},
    {"kind":"part_crate","rect":[80,74,1,1],"solid":"none","facing":0,"note":"판매 홀 부품 상자","level":2},
    {"kind":"shelf","rect":[82,68,3,1],"solid":"none","facing":0,"note":"곡물 상회 계량실 선반","level":2},
    {"kind":"part_crate","rect":[85,75,1,1],"solid":"none","facing":0,"note":"곡물 상회 계량실 부품 상자","level":2},
    {"kind":"barrel","rect":[82,75,1,1],"solid":"none","facing":0,"note":"곡물 상회 계량실 통","level":2},
    {"kind":"shelf","rect":[89,68,3,1],"solid":"none","facing":0,"note":"곡물 상회 안쪽 창고 선반","level":2},
    {"kind":"part_crate","rect":[89,75,1,1],"solid":"none","facing":0,"note":"곡물 상회 안쪽 창고 부품 상자","level":2},
    {"kind":"barrel","rect":[92,68,1,1],"solid":"none","facing":0,"note":"곡물 상회 안쪽 창고 통","level":2},
    {"kind":"shelf","rect":[95,68,3,1],"solid":"none","facing":0,"note":"곡물 상회 기록실 선반","level":2},
    {"kind":"part_crate","rect":[98,75,1,1],"solid":"none","facing":0,"note":"곡물 상회 기록실 부품 상자","level":2},
    {"kind":"barrel","rect":[95,75,1,1],"solid":"none","facing":0,"note":"곡물 상회 기록실 통","level":2},
    {"kind":"shelf","rect":[63,89,3,1],"solid":"none","facing":0,"note":"곡물 상회 사무실 선반","level":2},
    {"kind":"part_crate","rect":[63,82,1,1],"solid":"none","facing":0,"note":"곡물 상회 사무실 부품 상자","level":2},
    {"kind":"barrel","rect":[66,82,1,1],"solid":"none","facing":0,"note":"곡물 상회 사무실 통","level":2},
    {"kind":"shelf","rect":[69,89,3,1],"solid":"none","facing":0,"note":"곡물 상회 선별실 선반","level":2},
    {"kind":"part_crate","rect":[69,82,1,1],"solid":"none","facing":0,"note":"곡물 상회 선별실 부품 상자","level":2},
    {"kind":"barrel","rect":[72,89,1,1],"solid":"none","facing":0,"note":"곡물 상회 선별실 통","level":2},
    {"kind":"shelf","rect":[76,89,3,1],"solid":"none","facing":0,"note":"곡물 상회 선반 칸 선반","level":2},
    {"kind":"part_crate","rect":[76,82,1,1],"solid":"none","facing":0,"note":"곡물 상회 선반 칸 부품 상자","level":2},
    {"kind":"barrel","rect":[79,82,1,1],"solid":"none","facing":0,"note":"곡물 상회 선반 칸 통","level":2},
    {"kind":"shelf","rect":[82,89,3,1],"solid":"none","facing":0,"note":"곡물 상회 계량실 선반","level":2},
    {"kind":"part_crate","rect":[82,82,1,1],"solid":"none","facing":0,"note":"곡물 상회 계량실 부품 상자","level":2},
    {"kind":"barrel","rect":[85,89,1,1],"solid":"none","facing":0,"note":"곡물 상회 계량실 통","level":2},
    {"kind":"shelf","rect":[89,89,3,1],"solid":"none","facing":0,"note":"곡물 상회 안쪽 창고 선반","level":2},
    {"kind":"part_crate","rect":[89,82,1,1],"solid":"none","facing":0,"note":"곡물 상회 안쪽 창고 부품 상자","level":2},
    {"kind":"barrel","rect":[92,82,1,1],"solid":"none","facing":0,"note":"곡물 상회 안쪽 창고 통","level":2},
    {"kind":"shelf","rect":[95,89,3,1],"solid":"none","facing":0,"note":"곡물 상회 기록실 선반","level":2},
    {"kind":"part_crate","rect":[95,82,1,1],"solid":"none","facing":0,"note":"곡물 상회 기록실 부품 상자","level":2},
    {"kind":"barrel","rect":[98,89,1,1],"solid":"none","facing":0,"note":"곡물 상회 기록실 통","level":2},
    {"kind":"shelf","rect":[63,68,3,1],"solid":"none","facing":0,"note":"곡물 상회 저장고 선반","level":-1},
    {"kind":"part_crate","rect":[63,75,1,1],"solid":"none","facing":0,"note":"곡물 상회 저장고 부품 상자","level":-1},
    {"kind":"barrel","rect":[66,68,1,1],"solid":"none","facing":0,"note":"곡물 상회 저장고 통","level":-1},
    {"kind":"shelf","rect":[69,68,3,1],"solid":"none","facing":0,"note":"곡물 상회 냉기 칸 선반","level":-1},
    {"kind":"part_crate","rect":[72,75,1,1],"solid":"none","facing":0,"note":"곡물 상회 냉기 칸 부품 상자","level":-1},
    {"kind":"barrel","rect":[69,75,1,1],"solid":"none","facing":0,"note":"곡물 상회 냉기 칸 통","level":-1},
    {"kind":"shelf","rect":[76,68,3,1],"solid":"none","facing":0,"note":"곡물 상회 안쪽 보관실 선반","level":-1},
    {"kind":"part_crate","rect":[76,75,1,1],"solid":"none","facing":0,"note":"곡물 상회 안쪽 보관실 부품 상자","level":-1},
    {"kind":"barrel","rect":[79,68,1,1],"solid":"none","facing":0,"note":"곡물 상회 안쪽 보관실 통","level":-1},
    {"kind":"shelf","rect":[82,68,3,1],"solid":"none","facing":0,"note":"곡물 상회 저장고 선반","level":-1},
    {"kind":"part_crate","rect":[85,75,1,1],"solid":"none","facing":0,"note":"곡물 상회 저장고 부품 상자","level":-1},
    {"kind":"barrel","rect":[82,75,1,1],"solid":"none","facing":0,"note":"곡물 상회 저장고 통","level":-1},
    {"kind":"shelf","rect":[89,68,3,1],"solid":"none","facing":0,"note":"곡물 상회 냉기 칸 선반","level":-1},
    {"kind":"part_crate","rect":[89,75,1,1],"solid":"none","facing":0,"note":"곡물 상회 냉기 칸 부품 상자","level":-1},
    {"kind":"barrel","rect":[92,68,1,1],"solid":"none","facing":0,"note":"곡물 상회 냉기 칸 통","level":-1},
    {"kind":"shelf","rect":[95,68,3,1],"solid":"none","facing":0,"note":"곡물 상회 안쪽 보관실 선반","level":-1},
    {"kind":"part_crate","rect":[98,75,1,1],"solid":"none","facing":0,"note":"곡물 상회 안쪽 보관실 부품 상자","level":-1},
    {"kind":"barrel","rect":[95,75,1,1],"solid":"none","facing":0,"note":"곡물 상회 안쪽 보관실 통","level":-1},
    {"kind":"shelf","rect":[63,89,3,1],"solid":"none","facing":0,"note":"곡물 상회 저장고 선반","level":-1},
    {"kind":"part_crate","rect":[63,82,1,1],"solid":"none","facing":0,"note":"곡물 상회 저장고 부품 상자","level":-1},
    {"kind":"barrel","rect":[66,82,1,1],"solid":"none","facing":0,"note":"곡물 상회 저장고 통","level":-1},
    {"kind":"shelf","rect":[69,89,3,1],"solid":"none","facing":0,"note":"곡물 상회 냉기 칸 선반","level":-1},
    {"kind":"part_crate","rect":[69,82,1,1],"solid":"none","facing":0,"note":"곡물 상회 냉기 칸 부품 상자","level":-1},
    {"kind":"barrel","rect":[72,89,1,1],"solid":"none","facing":0,"note":"곡물 상회 냉기 칸 통","level":-1},
    {"kind":"shelf","rect":[76,89,3,1],"solid":"none","facing":0,"note":"곡물 상회 안쪽 보관실 선반","level":-1},
    {"kind":"part_crate","rect":[76,82,1,1],"solid":"none","facing":0,"note":"곡물 상회 안쪽 보관실 부품 상자","level":-1},
    {"kind":"barrel","rect":[79,82,1,1],"solid":"none","facing":0,"note":"곡물 상회 안쪽 보관실 통","level":-1},
    {"kind":"shelf","rect":[82,89,3,1],"solid":"none","facing":0,"note":"곡물 상회 저장고 선반","level":-1},
    {"kind":"part_crate","rect":[82,82,1,1],"solid":"none","facing":0,"note":"곡물 상회 저장고 부품 상자","level":-1},
    {"kind":"barrel","rect":[85,89,1,1],"solid":"none","facing":0,"note":"곡물 상회 저장고 통","level":-1},
    {"kind":"shelf","rect":[89,89,3,1],"solid":"none","facing":0,"note":"곡물 상회 냉기 칸 선반","level":-1},
    {"kind":"part_crate","rect":[89,82,1,1],"solid":"none","facing":0,"note":"곡물 상회 냉기 칸 부품 상자","level":-1},
    {"kind":"barrel","rect":[92,82,1,1],"solid":"none","facing":0,"note":"곡물 상회 냉기 칸 통","level":-1},
    {"kind":"shelf","rect":[95,89,3,1],"solid":"none","facing":0,"note":"곡물 상회 안쪽 보관실 선반","level":-1},
    {"kind":"part_crate","rect":[95,82,1,1],"solid":"none","facing":0,"note":"곡물 상회 안쪽 보관실 부품 상자","level":-1},
    {"kind":"barrel","rect":[98,89,1,1],"solid":"none","facing":0,"note":"곡물 상회 안쪽 보관실 통","level":-1},
    {"kind":"shop_counter","rect":[30,30,3,1],"solid":"low","facing":0,"note":"빵집 매장 가게 계산대","level":0},
    {"kind":"bread_rack","rect":[37,32,1,1],"solid":"low","facing":0,"note":"빵집 매장 빵 선반","level":0},
    {"kind":"part_crate","rect":[39,30,1,1],"solid":"low","facing":0,"note":"매장 부품 상자","level":0},
    {"kind":"sack_pile","rect":[30,34,2,2],"solid":"low","facing":0,"note":"빵집 뒤 창고 자루 더미","level":0},
    {"kind":"freezer_chest","rect":[30,36,2,1],"solid":"low","facing":0,"note":"빵집 뒤 창고 냉동 궤","level":0},
    {"kind":"part_crate","rect":[39,34,1,1],"solid":"low","facing":0,"note":"뒤 창고 부품 상자","level":0},
    {"kind":"display_shelf","rect":[55,44,4,1],"solid":"low","facing":0,"note":"식료품점 매장 진열대","level":0},
    {"kind":"shop_counter","rect":[55,41,3,1],"solid":"low","facing":0,"note":"식료품점 매장 가게 계산대","level":0},
    {"kind":"bread_rack","rect":[64,44,1,1],"solid":"low","facing":0,"note":"식료품점 매장 빵 선반","level":0},
    {"kind":"sack_pile","rect":[55,46,2,2],"solid":"low","facing":0,"note":"식료품점 뒤 창고 자루 더미","level":0},
    {"kind":"freezer_chest","rect":[55,48,2,1],"solid":"low","facing":0,"note":"식료품점 뒤 창고 냉동 궤","level":0},
    {"kind":"part_crate","rect":[66,46,1,1],"solid":"low","facing":0,"note":"뒤 창고 부품 상자","level":0},
    {"kind":"display_shelf","rect":[79,47,4,1],"solid":"low","facing":0,"note":"철물점 매장 진열대","level":0},
    {"kind":"shop_counter","rect":[79,44,3,1],"solid":"low","facing":0,"note":"철물점 매장 가게 계산대","level":0},
    {"kind":"bread_rack","rect":[86,47,1,1],"solid":"low","facing":0,"note":"철물점 매장 빵 선반","level":0},
    {"kind":"sack_pile","rect":[79,49,2,2],"solid":"low","facing":0,"note":"철물점 뒤 창고 자루 더미","level":0},
    {"kind":"freezer_chest","rect":[79,51,2,1],"solid":"low","facing":0,"note":"철물점 뒤 창고 냉동 궤","level":0},
    {"kind":"part_crate","rect":[88,49,1,1],"solid":"low","facing":0,"note":"뒤 창고 부품 상자","level":0},
    {"kind":"bed","rect":[9,49,2,1],"solid":"low","facing":0,"note":"주택 가 앞방 침대","level":0},
    {"kind":"desk","rect":[11,56,2,1],"solid":"low","facing":0,"note":"주택 가 앞방 책상","level":0},
    {"kind":"part_crate","rect":[13,49,1,1],"solid":"low","facing":0,"note":"앞방 부품 상자","level":0},
    {"kind":"bed","rect":[15,49,2,1],"solid":"low","facing":0,"note":"주택 가 안쪽 방 침대","level":0},
    {"kind":"desk","rect":[15,56,2,1],"solid":"low","facing":0,"note":"주택 가 안쪽 방 책상","level":0},
    {"kind":"part_crate","rect":[18,49,1,1],"solid":"low","facing":0,"note":"안쪽 방 부품 상자","level":0},
    {"kind":"bed","rect":[9,49,2,1],"solid":"none","facing":0,"note":"주택 가 앞방 침대","level":1},
    {"kind":"desk","rect":[11,56,2,1],"solid":"none","facing":0,"note":"주택 가 앞방 책상","level":1},
    {"kind":"part_crate","rect":[13,55,1,1],"solid":"none","facing":0,"note":"앞방 부품 상자","level":1},
    {"kind":"bed","rect":[15,49,2,1],"solid":"none","facing":0,"note":"주택 가 안쪽 방 침대","level":1},
    {"kind":"desk","rect":[16,56,2,1],"solid":"none","facing":0,"note":"주택 가 안쪽 방 책상","level":1},
    {"kind":"part_crate","rect":[18,55,1,1],"solid":"none","facing":0,"note":"안쪽 방 부품 상자","level":1},
    {"kind":"bed","rect":[29,60,2,1],"solid":"low","facing":0,"note":"주택 나 앞방 침대","level":0},
    {"kind":"desk","rect":[31,67,2,1],"solid":"low","facing":0,"note":"주택 나 앞방 책상","level":0},
    {"kind":"part_crate","rect":[33,60,1,1],"solid":"low","facing":0,"note":"앞방 부품 상자","level":0},
    {"kind":"bed","rect":[35,60,2,1],"solid":"low","facing":0,"note":"주택 나 안쪽 방 침대","level":0},
    {"kind":"desk","rect":[35,67,2,1],"solid":"low","facing":0,"note":"주택 나 안쪽 방 책상","level":0},
    {"kind":"part_crate","rect":[38,60,1,1],"solid":"low","facing":0,"note":"안쪽 방 부품 상자","level":0},
    {"kind":"bed","rect":[29,60,2,1],"solid":"none","facing":0,"note":"주택 나 앞방 침대","level":1},
    {"kind":"desk","rect":[31,67,2,1],"solid":"none","facing":0,"note":"주택 나 앞방 책상","level":1},
    {"kind":"part_crate","rect":[33,66,1,1],"solid":"none","facing":0,"note":"앞방 부품 상자","level":1},
    {"kind":"bed","rect":[35,60,2,1],"solid":"none","facing":0,"note":"주택 나 안쪽 방 침대","level":1},
    {"kind":"desk","rect":[36,67,2,1],"solid":"none","facing":0,"note":"주택 나 안쪽 방 책상","level":1},
    {"kind":"part_crate","rect":[38,66,1,1],"solid":"none","facing":0,"note":"안쪽 방 부품 상자","level":1},
    {"kind":"bed","rect":[9,66,2,1],"solid":"low","facing":0,"note":"주택 다 앞방 침대","level":0},
    {"kind":"desk","rect":[10,73,2,1],"solid":"low","facing":0,"note":"주택 다 앞방 책상","level":0},
    {"kind":"part_crate","rect":[12,66,1,1],"solid":"low","facing":0,"note":"앞방 부품 상자","level":0},
    {"kind":"bed","rect":[14,66,2,1],"solid":"low","facing":0,"note":"주택 다 안쪽 방 침대","level":0},
    {"kind":"desk","rect":[14,73,2,1],"solid":"low","facing":0,"note":"주택 다 안쪽 방 책상","level":0},
    {"kind":"part_crate","rect":[17,66,1,1],"solid":"low","facing":0,"note":"안쪽 방 부품 상자","level":0},
    {"kind":"bed","rect":[41,79,2,1],"solid":"low","facing":0,"note":"주택 라 앞방 침대","level":0},
    {"kind":"desk","rect":[43,86,2,1],"solid":"low","facing":0,"note":"주택 라 앞방 책상","level":0},
    {"kind":"part_crate","rect":[45,79,1,1],"solid":"low","facing":0,"note":"앞방 부품 상자","level":0},
    {"kind":"bed","rect":[47,79,2,1],"solid":"low","facing":0,"note":"주택 라 안쪽 방 침대","level":0},
    {"kind":"desk","rect":[47,86,2,1],"solid":"low","facing":0,"note":"주택 라 안쪽 방 책상","level":0},
    {"kind":"part_crate","rect":[50,79,1,1],"solid":"low","facing":0,"note":"안쪽 방 부품 상자","level":0},
    {"kind":"bed","rect":[41,79,2,1],"solid":"none","facing":0,"note":"주택 라 앞방 침대","level":1},
    {"kind":"desk","rect":[43,86,2,1],"solid":"none","facing":0,"note":"주택 라 앞방 책상","level":1},
    {"kind":"part_crate","rect":[45,85,1,1],"solid":"none","facing":0,"note":"앞방 부품 상자","level":1},
    {"kind":"bed","rect":[47,79,2,1],"solid":"none","facing":0,"note":"주택 라 안쪽 방 침대","level":1},
    {"kind":"desk","rect":[48,86,2,1],"solid":"none","facing":0,"note":"주택 라 안쪽 방 책상","level":1},
    {"kind":"part_crate","rect":[50,85,1,1],"solid":"none","facing":0,"note":"안쪽 방 부품 상자","level":1},
    {"kind":"bed","rect":[113,66,2,1],"solid":"low","facing":0,"note":"농가 집 앞방 침대","level":0},
    {"kind":"desk","rect":[116,73,2,1],"solid":"low","facing":0,"note":"농가 집 앞방 책상","level":0},
    {"kind":"shelf","rect":[113,73,3,1],"solid":"low","facing":0,"note":"농가 집 앞방 선반","level":0},
    {"kind":"bed","rect":[120,66,2,1],"solid":"low","facing":0,"note":"농가 집 안쪽 방 침대","level":0},
    {"kind":"desk","rect":[120,73,2,1],"solid":"low","facing":0,"note":"농가 집 안쪽 방 책상","level":0},
    {"kind":"part_crate","rect":[124,66,1,1],"solid":"low","facing":0,"note":"안쪽 방 부품 상자","level":0},
    {"kind":"bed","rect":[113,66,2,1],"solid":"none","facing":0,"note":"농가 집 앞방 침대","level":1},
    {"kind":"desk","rect":[116,73,2,1],"solid":"none","facing":0,"note":"농가 집 앞방 책상","level":1},
    {"kind":"shelf","rect":[113,73,3,1],"solid":"none","facing":0,"note":"농가 집 앞방 선반","level":1},
    {"kind":"bed","rect":[120,66,2,1],"solid":"none","facing":0,"note":"농가 집 안쪽 방 침대","level":1},
    {"kind":"desk","rect":[122,73,2,1],"solid":"none","facing":0,"note":"농가 집 안쪽 방 책상","level":1},
    {"kind":"part_crate","rect":[124,72,1,1],"solid":"none","facing":0,"note":"안쪽 방 부품 상자","level":1},
    {"kind":"shelf","rect":[136,77,3,1],"solid":"low","facing":0,"note":"농가 헛간 앞방 선반","level":0},
    {"kind":"part_crate","rect":[140,84,1,1],"solid":"low","facing":0,"note":"농가 헛간 앞방 부품 상자","level":0},
    {"kind":"barrel","rect":[136,84,1,1],"solid":"low","facing":0,"note":"농가 헛간 앞방 통","level":0},
    {"kind":"shelf","rect":[144,77,3,1],"solid":"low","facing":0,"note":"농가 헛간 안쪽 방 선반","level":0},
    {"kind":"part_crate","rect":[147,84,1,1],"solid":"low","facing":0,"note":"농가 헛간 안쪽 방 부품 상자","level":0},
    {"kind":"barrel","rect":[144,84,1,1],"solid":"low","facing":0,"note":"농가 헛간 안쪽 방 통","level":0},
    {"kind":"rail_pile","rect":[108,46,3,1],"solid":"low","facing":0,"note":"레일 더미 작업 흔적","level":0},
    {"kind":"tool_cart","rect":[112,46,2,1],"solid":"low","facing":0,"note":"공구 수레 작업 흔적","level":0},
    {"kind":"part_crate","rect":[116,46,1,1],"solid":"low","facing":0,"note":"부품 상자 작업 흔적","level":0},
    {"kind":"coupler_set","rect":[108,49,1,1],"solid":"low","facing":0,"note":"연결기 한 벌 작업 흔적","level":0},
    {"kind":"sack_pile","rect":[116,57,2,2],"solid":"low","facing":0,"note":"자루 더미 작업 흔적","level":0},
    {"kind":"barrel","rect":[120,57,1,1],"solid":"low","facing":0,"note":"통 작업 흔적","level":0},
    {"kind":"handcart","rect":[124,57,2,1],"solid":"low","facing":0,"note":"손수레 작업 흔적","level":0},
    {"kind":"firewood_pile","rect":[7,81,2,1],"solid":"low","facing":0,"note":"장작 더미 작업 흔적","level":0},
    {"kind":"barrel","rect":[11,81,1,1],"solid":"low","facing":0,"note":"통 작업 흔적","level":0},
    {"kind":"crate_stack","rect":[15,81,2,2],"solid":"low","facing":0,"note":"나무 상자 더미 작업 흔적","level":0},
    {"kind":"handcart","rect":[137,66,2,1],"solid":"low","facing":0,"note":"손수레 작업 흔적","level":0},
    {"kind":"sack_pile","rect":[141,66,2,2],"solid":"low","facing":0,"note":"자루 더미 작업 흔적","level":0},
    {"kind":"barrel","rect":[145,66,1,1],"solid":"low","facing":0,"note":"통 작업 흔적","level":0},
    {"kind":"bare_tree","rect":[66,36,1,1],"solid":"tree","facing":0,"note":"길가 마른 나무","level":0},
    {"kind":"bare_tree","rect":[72,36,1,1],"solid":"tree","facing":0,"note":"길가 마른 나무","level":0},
    {"kind":"bare_tree","rect":[78,36,1,1],"solid":"tree","facing":0,"note":"길가 마른 나무","level":0},
    {"kind":"bare_tree","rect":[84,36,1,1],"solid":"tree","facing":0,"note":"길가 마른 나무","level":0},
    {"kind":"bare_tree","rect":[90,36,1,1],"solid":"tree","facing":0,"note":"길가 마른 나무","level":0},
    {"kind":"bare_tree","rect":[96,36,1,1],"solid":"tree","facing":0,"note":"길가 마른 나무","level":0},
    {"kind":"bare_tree","rect":[102,36,1,1],"solid":"tree","facing":0,"note":"길가 마른 나무","level":0},
    {"kind":"bare_tree","rect":[108,36,1,1],"solid":"tree","facing":0,"note":"길가 마른 나무","level":0},
    {"kind":"bare_tree","rect":[114,36,1,1],"solid":"tree","facing":0,"note":"길가 마른 나무","level":0},
    {"kind":"bare_tree","rect":[111,85,1,1],"solid":"tree","facing":0,"note":"길가 마른 나무","level":0},
    {"kind":"bare_tree","rect":[116,86,1,1],"solid":"tree","facing":0,"note":"길가 마른 나무","level":0},
    {"kind":"bare_tree","rect":[121,87,1,1],"solid":"tree","facing":0,"note":"길가 마른 나무","level":0},
    {"kind":"bare_tree","rect":[126,88,1,1],"solid":"tree","facing":0,"note":"길가 마른 나무","level":0},
    {"kind":"bare_tree","rect":[131,89,1,1],"solid":"tree","facing":0,"note":"길가 마른 나무","level":0},
    {"kind":"bare_tree","rect":[136,90,1,1],"solid":"tree","facing":0,"note":"길가 마른 나무","level":0},
    {"kind":"bare_tree","rect":[141,91,1,1],"solid":"tree","facing":0,"note":"길가 마른 나무","level":0},
    {"kind":"bare_tree","rect":[146,92,1,1],"solid":"tree","facing":0,"note":"길가 마른 나무","level":0},
    {"kind":"bare_tree","rect":[5,45,1,1],"solid":"tree","facing":0,"note":"길가 마른 나무","level":0},
    {"kind":"bare_tree","rect":[5,52,1,1],"solid":"tree","facing":0,"note":"길가 마른 나무","level":0},
    {"kind":"bare_tree","rect":[5,59,1,1],"solid":"tree","facing":0,"note":"길가 마른 나무","level":0},
    {"kind":"bare_tree","rect":[5,66,1,1],"solid":"tree","facing":0,"note":"길가 마른 나무","level":0},
    {"kind":"bare_tree","rect":[5,73,1,1],"solid":"tree","facing":0,"note":"길가 마른 나무","level":0},
    {"kind":"bare_tree","rect":[5,80,1,1],"solid":"tree","facing":0,"note":"길가 마른 나무","level":0},
    {"kind":"bare_tree","rect":[5,87,1,1],"solid":"tree","facing":0,"note":"길가 마른 나무","level":0},
    {"kind":"bare_tree","rect":[145,57,1,1],"solid":"tree","facing":0,"note":"길가 마른 나무","level":0},
    {"kind":"bare_tree","rect":[147,62,1,1],"solid":"tree","facing":0,"note":"길가 마른 나무","level":0},
    {"kind":"bare_tree","rect":[149,67,1,1],"solid":"tree","facing":0,"note":"길가 마른 나무","level":0},
    {"kind":"bare_tree","rect":[151,72,1,1],"solid":"tree","facing":0,"note":"길가 마른 나무","level":0},
    {"kind":"bare_tree","rect":[153,77,1,1],"solid":"tree","facing":0,"note":"길가 마른 나무","level":0},
    {"kind":"bare_tree","rect":[155,82,1,1],"solid":"tree","facing":0,"note":"길가 마른 나무","level":0},
    {"kind":"bare_tree","rect":[157,87,1,1],"solid":"tree","facing":0,"note":"길가 마른 나무","level":0},
    {"kind":"bare_tree","rect":[43,44,1,1],"solid":"tree","facing":0,"note":"길가 마른 나무","level":0},
    {"kind":"bare_tree","rect":[43,49,1,1],"solid":"tree","facing":0,"note":"길가 마른 나무","level":0},
    {"kind":"bare_tree","rect":[43,54,1,1],"solid":"tree","facing":0,"note":"길가 마른 나무","level":0}
  ],
  "containers": [
    {"id":"box_1","name":"역사 사무실 상자","cell":[29,15],"building":0,"search":5,"items":["plank","food_pack"],"locked":false,"level":0,"searched":false},
    {"id":"box_2","name":"역사 선별실 상자","cell":[44,15],"building":0,"search":5,"items":["plank","food_pack"],"locked":false,"level":0,"searched":false},
    {"id":"box_3","name":"역사 사무실 상자","cell":[29,23],"building":0,"search":5,"items":["plank","document"],"locked":false,"level":0,"searched":false},
    {"id":"box_4","name":"역사 선별실 상자","cell":[44,23],"building":0,"search":5,"items":["plank","food_pack"],"locked":false,"level":0,"searched":false},
    {"id":"box_5","name":"역사 사무실 상자","cell":[29,15],"building":0,"search":5,"items":["plank","food_pack"],"locked":false,"level":1,"searched":false},
    {"id":"box_6","name":"역사 선별실 상자","cell":[44,15],"building":0,"search":5,"items":["plank","document"],"locked":false,"level":1,"searched":false},
    {"id":"box_7","name":"역사 사무실 상자","cell":[29,23],"building":0,"search":5,"items":["plank","food_pack"],"locked":false,"level":1,"searched":false},
    {"id":"box_8","name":"역사 선별실 상자","cell":[44,23],"building":0,"search":5,"items":["plank","food_pack"],"locked":false,"level":1,"searched":false},
    {"id":"box_9","name":"소화물 창고 앞방 상자","cell":[61,19],"building":1,"search":5,"items":["plank","document"],"locked":false,"level":0,"searched":false},
    {"id":"box_10","name":"소화물 창고 안쪽 방 상자","cell":[69,19],"building":1,"search":5,"items":["plank","food_pack"],"locked":false,"level":0,"searched":false},
    {"id":"box_11","name":"신호 취급소 작업실 상자","cell":[83,17],"building":2,"search":5,"items":["plank","food_pack"],"locked":false,"level":0,"searched":false},
    {"id":"box_12","name":"신호 취급소 작업실 상자","cell":[83,17],"building":2,"search":5,"items":["plank","document"],"locked":false,"level":1,"searched":false},
    {"id":"box_13","name":"석탄 적치 창고 앞방 상자","cell":[135,32],"building":3,"search":5,"items":["plank","food_pack"],"locked":false,"level":0,"searched":false},
    {"id":"box_14","name":"석탄 적치 창고 안쪽 방 상자","cell":[146,32],"building":3,"search":5,"items":["plank","food_pack"],"locked":false,"level":0,"searched":false},
    {"id":"box_15","name":"하역 사무소 작업실 상자","cell":[153,50],"building":4,"search":5,"items":["plank","document"],"locked":false,"level":0,"searched":false},
    {"id":"box_16","name":"공구 창고 앞방 상자","cell":[129,55],"building":5,"search":5,"items":["plank","food_pack"],"locked":false,"level":0,"searched":false},
    {"id":"box_17","name":"공구 창고 안쪽 방 상자","cell":[134,55],"building":5,"search":5,"items":["plank","food_pack"],"locked":false,"level":0,"searched":false},
    {"id":"box_18","name":"역장 관사 앞방 상자","cell":[11,36],"building":6,"search":5,"items":["plank","document"],"locked":false,"level":0,"searched":false},
    {"id":"box_19","name":"역장 관사 안쪽 방 상자","cell":[16,36],"building":6,"search":5,"items":["plank","food_pack"],"locked":false,"level":0,"searched":false},
    {"id":"box_20","name":"역장 관사 앞방 상자","cell":[11,36],"building":6,"search":5,"items":["plank","food_pack"],"locked":false,"level":1,"searched":false},
    {"id":"box_21","name":"역장 관사 안쪽 방 상자","cell":[16,36],"building":6,"search":5,"items":["plank","document"],"locked":false,"level":1,"searched":false},
    {"id":"box_22","name":"곡물 상회 판매 홀 상자","cell":[80,75],"building":7,"search":5,"items":["plank","food_pack"],"locked":false,"level":0,"searched":false},
    {"id":"box_23","name":"곡물 상회 계량실 상자","cell":[87,75],"building":7,"search":5,"items":["plank","food_pack"],"locked":false,"level":0,"searched":false},
    {"id":"box_24","name":"곡물 상회 안쪽 창고 상자","cell":[93,75],"building":7,"search":5,"items":["plank","document"],"locked":false,"level":0,"searched":false},
    {"id":"box_25","name":"곡물 상회 기록실 상자","cell":[100,75],"building":7,"search":5,"items":["plank","food_pack"],"locked":false,"level":0,"searched":false},
    {"id":"box_26","name":"곡물 상회 사무실 상자","cell":[67,89],"building":7,"search":5,"items":["plank","food_pack"],"locked":false,"level":0,"searched":false},
    {"id":"box_27","name":"곡물 상회 선별실 상자","cell":[74,89],"building":7,"search":5,"items":["plank","document"],"locked":false,"level":0,"searched":false},
    {"id":"box_28","name":"곡물 상회 선반 칸 상자","cell":[80,89],"building":7,"search":5,"items":["plank","food_pack"],"locked":false,"level":0,"searched":false},
    {"id":"box_29","name":"곡물 상회 계량실 상자","cell":[87,89],"building":7,"search":5,"items":["plank","food_pack"],"locked":false,"level":0,"searched":false},
    {"id":"box_30","name":"곡물 상회 안쪽 창고 상자","cell":[93,89],"building":7,"search":5,"items":["plank","document"],"locked":false,"level":0,"searched":false},
    {"id":"box_31","name":"곡물 상회 기록실 상자","cell":[100,89],"building":7,"search":5,"items":["plank","food_pack"],"locked":false,"level":0,"searched":false},
    {"id":"box_32","name":"곡물 상회 사무실 상자","cell":[67,75],"building":7,"search":5,"items":["plank","food_pack"],"locked":false,"level":1,"searched":false},
    {"id":"box_33","name":"곡물 상회 선별실 상자","cell":[74,75],"building":7,"search":5,"items":["plank","document"],"locked":false,"level":1,"searched":false},
    {"id":"box_34","name":"곡물 상회 판매 홀 상자","cell":[80,75],"building":7,"search":5,"items":["plank","food_pack"],"locked":false,"level":1,"searched":false},
    {"id":"box_35","name":"곡물 상회 계량실 상자","cell":[87,75],"building":7,"search":5,"items":["plank","food_pack"],"locked":false,"level":1,"searched":false},
    {"id":"box_36","name":"곡물 상회 안쪽 창고 상자","cell":[93,75],"building":7,"search":5,"items":["plank","document"],"locked":false,"level":1,"searched":false},
    {"id":"box_37","name":"곡물 상회 기록실 상자","cell":[100,75],"building":7,"search":5,"items":["plank","food_pack"],"locked":false,"level":1,"searched":false},
    {"id":"box_38","name":"곡물 상회 사무실 상자","cell":[67,89],"building":7,"search":5,"items":["plank","food_pack"],"locked":false,"level":1,"searched":false},
    {"id":"box_39","name":"곡물 상회 선별실 상자","cell":[74,89],"building":7,"search":5,"items":["plank","document"],"locked":false,"level":1,"searched":false},
    {"id":"box_40","name":"곡물 상회 선반 칸 상자","cell":[80,89],"building":7,"search":5,"items":["plank","food_pack"],"locked":false,"level":1,"searched":false},
    {"id":"box_41","name":"곡물 상회 계량실 상자","cell":[87,89],"building":7,"search":5,"items":["plank","food_pack"],"locked":false,"level":1,"searched":false},
    {"id":"box_42","name":"곡물 상회 안쪽 창고 상자","cell":[93,89],"building":7,"search":5,"items":["plank","document"],"locked":false,"level":1,"searched":false},
    {"id":"box_43","name":"곡물 상회 기록실 상자","cell":[100,89],"building":7,"search":5,"items":["plank","food_pack"],"locked":false,"level":1,"searched":false},
    {"id":"box_44","name":"곡물 상회 사무실 상자","cell":[67,75],"building":7,"search":5,"items":["plank","food_pack"],"locked":false,"level":2,"searched":false},
    {"id":"box_45","name":"곡물 상회 선별실 상자","cell":[74,75],"building":7,"search":5,"items":["plank","document"],"locked":false,"level":2,"searched":false},
    {"id":"box_46","name":"곡물 상회 판매 홀 상자","cell":[80,75],"building":7,"search":5,"items":["plank","food_pack"],"locked":false,"level":2,"searched":false},
    {"id":"box_47","name":"곡물 상회 계량실 상자","cell":[87,75],"building":7,"search":5,"items":["plank","food_pack"],"locked":false,"level":2,"searched":false},
    {"id":"box_48","name":"곡물 상회 안쪽 창고 상자","cell":[93,75],"building":7,"search":5,"items":["plank","document"],"locked":false,"level":2,"searched":false},
    {"id":"box_49","name":"곡물 상회 기록실 상자","cell":[100,75],"building":7,"search":5,"items":["plank","food_pack"],"locked":false,"level":2,"searched":false},
    {"id":"box_50","name":"곡물 상회 사무실 상자","cell":[67,89],"building":7,"search":5,"items":["plank","food_pack"],"locked":false,"level":2,"searched":false},
    {"id":"box_51","name":"곡물 상회 선별실 상자","cell":[74,89],"building":7,"search":5,"items":["plank","document"],"locked":false,"level":2,"searched":false},
    {"id":"box_52","name":"곡물 상회 선반 칸 상자","cell":[80,89],"building":7,"search":5,"items":["plank","food_pack"],"locked":false,"level":2,"searched":false},
    {"id":"box_53","name":"곡물 상회 계량실 상자","cell":[87,89],"building":7,"search":5,"items":["plank","food_pack"],"locked":false,"level":2,"searched":false},
    {"id":"box_54","name":"곡물 상회 안쪽 창고 상자","cell":[93,89],"building":7,"search":5,"items":["plank","document"],"locked":false,"level":2,"searched":false},
    {"id":"box_55","name":"곡물 상회 기록실 상자","cell":[100,89],"building":7,"search":5,"items":["plank","food_pack"],"locked":false,"level":2,"searched":false},
    {"id":"box_56","name":"곡물 상회 저장고 상자","cell":[67,75],"building":7,"search":5,"items":["plank","food_pack"],"locked":false,"level":-1,"searched":false},
    {"id":"box_57","name":"곡물 상회 냉기 칸 상자","cell":[74,75],"building":7,"search":5,"items":["plank","document"],"locked":false,"level":-1,"searched":false},
    {"id":"box_58","name":"곡물 상회 안쪽 보관실 상자","cell":[80,75],"building":7,"search":5,"items":["plank","food_pack"],"locked":false,"level":-1,"searched":false},
    {"id":"box_59","name":"곡물 상회 저장고 상자","cell":[87,75],"building":7,"search":5,"items":["plank","food_pack"],"locked":false,"level":-1,"searched":false},
    {"id":"box_60","name":"곡물 상회 냉기 칸 상자","cell":[93,75],"building":7,"search":5,"items":["plank","document"],"locked":false,"level":-1,"searched":false},
    {"id":"box_61","name":"곡물 상회 안쪽 보관실 상자","cell":[100,75],"building":7,"search":5,"items":["plank","food_pack"],"locked":false,"level":-1,"searched":false},
    {"id":"box_62","name":"곡물 상회 저장고 상자","cell":[67,89],"building":7,"search":5,"items":["plank","food_pack"],"locked":false,"level":-1,"searched":false},
    {"id":"box_63","name":"곡물 상회 냉기 칸 상자","cell":[74,89],"building":7,"search":5,"items":["plank","document"],"locked":false,"level":-1,"searched":false},
    {"id":"box_64","name":"곡물 상회 안쪽 보관실 상자","cell":[80,89],"building":7,"search":5,"items":["plank","food_pack"],"locked":false,"level":-1,"searched":false},
    {"id":"box_65","name":"곡물 상회 저장고 상자","cell":[87,89],"building":7,"search":5,"items":["plank","food_pack"],"locked":false,"level":-1,"searched":false},
    {"id":"box_66","name":"곡물 상회 냉기 칸 상자","cell":[93,89],"building":7,"search":5,"items":["plank","document"],"locked":false,"level":-1,"searched":false},
    {"id":"box_67","name":"곡물 상회 안쪽 보관실 상자","cell":[100,89],"building":7,"search":5,"items":["plank","food_pack"],"locked":false,"level":-1,"searched":false},
    {"id":"box_68","name":"빵집 매장 상자","cell":[39,32],"building":8,"search":5,"items":["plank","food_pack"],"locked":false,"level":0,"searched":false},
    {"id":"box_69","name":"빵집 뒤 창고 상자","cell":[39,36],"building":8,"search":5,"items":["plank","document"],"locked":false,"level":0,"searched":false},
    {"id":"box_70","name":"식료품점 매장 상자","cell":[66,44],"building":9,"search":5,"items":["plank","food_pack"],"locked":false,"level":0,"searched":false},
    {"id":"box_71","name":"식료품점 뒤 창고 상자","cell":[66,48],"building":9,"search":5,"items":["plank","food_pack"],"locked":false,"level":0,"searched":false},
    {"id":"box_72","name":"철물점 매장 상자","cell":[88,47],"building":10,"search":5,"items":["plank","document"],"locked":false,"level":0,"searched":false},
    {"id":"box_73","name":"철물점 뒤 창고 상자","cell":[88,51],"building":10,"search":5,"items":["plank","food_pack"],"locked":false,"level":0,"searched":false},
    {"id":"box_74","name":"주택 가 앞방 상자","cell":[13,56],"building":11,"search":5,"items":["plank","food_pack"],"locked":false,"level":0,"searched":false},
    {"id":"box_75","name":"주택 가 안쪽 방 상자","cell":[18,56],"building":11,"search":5,"items":["plank","document"],"locked":false,"level":0,"searched":false},
    {"id":"box_76","name":"주택 가 앞방 상자","cell":[13,56],"building":11,"search":5,"items":["plank","food_pack"],"locked":false,"level":1,"searched":false},
    {"id":"box_77","name":"주택 가 안쪽 방 상자","cell":[18,56],"building":11,"search":5,"items":["plank","food_pack"],"locked":false,"level":1,"searched":false},
    {"id":"box_78","name":"주택 나 앞방 상자","cell":[33,67],"building":12,"search":5,"items":["plank","document"],"locked":false,"level":0,"searched":false},
    {"id":"box_79","name":"주택 나 안쪽 방 상자","cell":[38,67],"building":12,"search":5,"items":["plank","food_pack"],"locked":false,"level":0,"searched":false},
    {"id":"box_80","name":"주택 나 앞방 상자","cell":[33,67],"building":12,"search":5,"items":["plank","food_pack"],"locked":false,"level":1,"searched":false},
    {"id":"box_81","name":"주택 나 안쪽 방 상자","cell":[38,67],"building":12,"search":5,"items":["plank","document"],"locked":false,"level":1,"searched":false},
    {"id":"box_82","name":"주택 다 앞방 상자","cell":[12,73],"building":13,"search":5,"items":["plank","food_pack"],"locked":false,"level":0,"searched":false},
    {"id":"box_83","name":"주택 다 안쪽 방 상자","cell":[17,73],"building":13,"search":5,"items":["plank","food_pack"],"locked":false,"level":0,"searched":false},
    {"id":"box_84","name":"주택 라 앞방 상자","cell":[45,86],"building":14,"search":5,"items":["plank","document"],"locked":false,"level":0,"searched":false},
    {"id":"box_85","name":"주택 라 안쪽 방 상자","cell":[50,86],"building":14,"search":5,"items":["plank","food_pack"],"locked":false,"level":0,"searched":false},
    {"id":"box_86","name":"주택 라 앞방 상자","cell":[45,86],"building":14,"search":5,"items":["plank","food_pack"],"locked":false,"level":1,"searched":false},
    {"id":"box_87","name":"주택 라 안쪽 방 상자","cell":[50,86],"building":14,"search":5,"items":["plank","document"],"locked":false,"level":1,"searched":false},
    {"id":"box_88","name":"농가 집 앞방 상자","cell":[118,73],"building":15,"search":5,"items":["plank","food_pack"],"locked":false,"level":0,"searched":false},
    {"id":"box_89","name":"농가 집 안쪽 방 상자","cell":[124,73],"building":15,"search":5,"items":["plank","food_pack"],"locked":false,"level":0,"searched":false},
    {"id":"box_90","name":"농가 집 앞방 상자","cell":[118,73],"building":15,"search":5,"items":["plank","document"],"locked":false,"level":1,"searched":false},
    {"id":"box_91","name":"농가 집 안쪽 방 상자","cell":[124,73],"building":15,"search":5,"items":["plank","food_pack"],"locked":false,"level":1,"searched":false},
    {"id":"box_92","name":"농가 헛간 앞방 상자","cell":[142,84],"building":16,"search":5,"items":["plank","food_pack"],"locked":false,"level":0,"searched":false},
    {"id":"box_93","name":"농가 헛간 안쪽 방 상자","cell":[149,84],"building":16,"search":5,"items":["plank","document"],"locked":false,"level":0,"searched":false},
    {"id":"box_platform","name":"승강장 보급 상자","cell":[38,8],"building":-1,"search":4,"items":["scrap","food_pack"],"locked":false,"level":0,"searched":false}
  ],
  "wagons": [
    {"id":"wagon_1","name":"석탄 화차","rect":[90,15,10,3],"coal":10,"work":[91,18]},
    {"id":"wagon_2","name":"석탄 화차","rect":[106,15,10,3],"coal":10,"work":[107,18]},
    {"id":"wagon_3","name":"문 열린 화차","rect":[88,22,11,3],"coal":0,"work":[89,25]}
  ],
  "entries": [
    ["west_road",[[0,40],[0,41],[0,42],[0,43]],0.6],
    ["south_lane",[[102,94],[103,94],[104,94],[105,94]],2.5],
    ["east_track",[[159,1],[159,2],[159,3]],0.6],
    ["farm_lane",[[159,78],[159,79],[159,80],[159,81]],2.5]
  ],
  "holes": [
    ["manhole_01",[50,40],"큰길 맨홀"],
    ["culvert_01",[126,36],"측선 둑 밑 암거",[0,1]]
  ],
  "barricades": [
    [48,12],
    [50,12],
    [52,12],
    [73,15],
    [75,15],
    [86,16],
    [88,16]
  ],
  "dead": [
    [115,33],
    [117,36],
    [93,41],
    [102,60],
    [39,57],
    [106,89]
  ],
  "deep": [
    ["D","곡물 상회"],
    ["G","석탄 적치 창고"]
  ],
  "assumptions": ["석탄 창고는 암거와 겹치지 않도록 동쪽으로 네 칸 옮겼다.","석탄은 기존 화차의 coal 값으로 제공하며 상자에는 기존 물건 이름만 사용한다."],
  "salvage": [
    ["salvage_1","버려진 차",[41,45],"scrap"],
    ["salvage_2","버려진 차",[107,80],"scrap"],
    ["salvage_3","석탄 적치 창고 앞방 부품 상자",[132,32],"scrap"],
    ["salvage_4","석탄 적치 창고 안쪽 방 부품 상자",[143,32],"scrap"],
    ["salvage_5","공구 창고 앞방 부품 상자",[126,55],"scrap"],
    ["salvage_6","공구 창고 안쪽 방 부품 상자",[132,54],"scrap"]
  ],
  "work_site": {"cell":[108,20],"rect":[98,12,42,21]}
}


static func _build_plain() -> Dictionary:
	var data: Dictionary = _build_south()
	# 여기까지는 옛 좌표(열차가 맨 위 y 1~3), 아래부터는 새 좌표(열차 y 46~48)
	data = MapShift.shift_rows(data, 45)
	assert(data["train"] == Rect2i(16, 46, 80, 3))
	assert(data["grid"].height == HEIGHT)
	_add_north(data)
	data["bands"]["upper"] = Rect2i(-4, 24, 120, 22).intersection(Rect2i(0, 0, WIDTH, HEIGHT))
	data["train_doors"]["upper"] = []
	for lower: Vector2i in data["train_doors"]["lower"]:
		var upper := Vector2i(lower.x, 45)
		data["train_doors"]["upper"].append(upper)
		for cell in [upper + Vector2i.UP, lower + Vector2i.DOWN]:
			if not data["barricade_slots"].has(cell):
				data["barricade_slots"].append(cell)
	for x in NORTH_PLAN["cross"]:
		data["crossings"].append({"cells": [Vector2i(x, 46), Vector2i(x, 47), Vector2i(x, 48)], "who": {"person": true, "zombie": false, "carrying": true, "wounded": false, "sled": false}})
	for lv in data["levels"]:
		data["levels"][lv].refresh_paths()
	return data


static func _repair_south_plan(plan: Dictionary) -> void:
	for index in SOUTH_REPAIRS["replace"]:
		plan["props"][int(index)] = SOUTH_REPAIRS["replace"][index].duplicate(true)
	var removed: Array = SOUTH_REPAIRS["remove"].duplicate()
	removed.sort()
	removed.reverse()
	for index in removed:
		plan["props"].remove_at(int(index))
	for prop in SOUTH_REPAIRS["append"]:
		plan["props"].append(prop.duplicate(true))
	plan["work_site"] = SOUTH_REPAIRS["work_site"].duplicate(true)
	# 서쪽 승강장 곁 길을 북쪽 길과 같은 폭으로 잇는다.
	for row in SOUTH_REPAIRS["floors"]:
		plan["floors"].append(row.duplicate())


static func _add_north(data: Dictionary) -> void:
	var g: FieldGrid = data["grid"]
	var levels: Dictionary = data["levels"]
	for row in NORTH_PLAN["zones"]:
		data["zone_names"][row[0]] = row[1]
		var r := _rect(row[2])
		for y in range(r.position.y, r.end.y):
			for x in range(r.position.x, r.end.x):
				g.zone[g.index(Vector2i(x, y))] = row[0]
	for row in NORTH_PLAN["floors"]:
		_fill_floor(levels[int(row[0])], Rect2i(row[1], row[2], row[3], row[4]), int(row[5]))
	for row in NORTH_PLAN["buildings"]:
		var b: Dictionary = row.duplicate(true)
		b["rect"] = _rect(row["rect"])
		data["buildings"].append(b)
	for row in NORTH_PLAN["shells"]:
		var lv: int = int(row[1])
		var r := Rect2i(row[2], row[3], row[4], row[5])
		_shell(levels[lv], int(row[0]), r, lv)
		if lv > 0:
			data["upper_rects"].append({"building": int(row[0]), "rect": r})
	for row in NORTH_PLAN["walls"]:
		_fill_solid(levels[int(row[0])], Rect2i(row[1], row[2], row[3], row[4]), S.WALL)
	for row in NORTH_PLAN["openings"]:
		_fill_solid(levels[int(row[0])], Rect2i(row[1], row[2], row[3], row[4]), S.NONE)
	for row in NORTH_PLAN["windows"]:
		var lg: FieldGrid = levels[int(row[0])]
		var c := Vector2i(row[1], row[2])
		lg.set_solid(c, S.WINDOW)
		lg.windows[c] = {"broken": false, "glass": false, "building": int(row[3]), "cell": c}
	for row in NORTH_PLAN["doors"]:
		var lg: FieldGrid = levels[int(row[0])]
		var c := Vector2i(row[1], row[2])
		lg.windows.erase(c)
		lg.set_solid(c, S.DOOR)
		lg.doors[c] = {"state": row[4], "hp": 8, "building": int(row[3]), "cell": c}
	for row in NORTH_PLAN["stairs"]:
		var st: Dictionary = row.duplicate(true)
		st["cell"] = _cell(row["cell"])
		data["stairs"].append(st)
	for row in NORTH_PLAN["props"]:
		var pr: Dictionary = row.duplicate(true)
		var r := _rect(row["rect"])
		pr["rect"] = r
		data["props"].append(pr)
		if int(pr["level"]) != 0:
			continue
		match String(pr["solid"]):
			"low":
				_fill_solid(g, r, S.LOW)
				if pr["kind"] == "water":
					_fill_floor(g, r, F.ICE)
				else:
					data["low_blocks"].append(r)
			"wall":
				_fill_solid(g, r, S.WALL)
			"tree":
				_fill_solid(g, r, S.BLOCK)
				data["trees"].append(r.position)
			"wagon":
				_fill_solid(g, r, S.BLOCK)
	for row in NORTH_PLAN["wagons"]:
		var w: Dictionary = row.duplicate(true)
		w["rect"] = _rect(row["rect"])
		w["work"] = _cell(row["work"])
		data["wagons"].append(w)
	for row in NORTH_PLAN["containers"]:
		var box: Dictionary = row.duplicate(true)
		box["cell"] = _cell(row["cell"])
		data["containers"][box["id"]] = box
	for row in NORTH_PLAN["entries"]:
		var cs: Array[Vector2i] = []
		for c in row[1]:
			cs.append(_cell(c))
		data["entries"][row[0]] = cs
		data["entry_gap"][row[0]] = float(row[2])
	for row in NORTH_PLAN["holes"]:
		var c := _cell(row[1])
		var id: String = row[0]
		data["manholes"][id] = c
		data["entries"][id] = [c]
		data["entry_gap"][id] = 3.0 if id.begins_with("manhole_") else 0.6
		data["sewer_names"][id] = row[2]
		if id.begins_with("manhole_"):
			data["labels"].append({"text": "맨홀", "cell": c + Vector2i(0, -1)})
		if id.begins_with("culvert_"):
			data["hole_faces"][id] = _cell(row[3])
	for row in NORTH_PLAN["barricades"]:
		data["barricade_slots"].append(_cell(row))
	for row in NORTH_PLAN["deep"]:
		data["interior_kind_slots"].append({"zone": row[0], "kinds": ["empty", "raiders", "nest", "beasts"]})
	for lv in levels:
		if lv != 0:
			levels[lv].zone = g.zone.duplicate()


static func _build_south(repaired: bool = true) -> Dictionary:
	var plan: Dictionary = PLAN.duplicate(true)
	if repaired:
		_repair_south_plan(plan)
	var g := FieldGrid.new(WIDTH, SOUTH_HEIGHT)
	var levels: Dictionary = {0: g}
	for lv in [-1, 1, 2]:
		var lg := FieldGrid.new(WIDTH, SOUTH_HEIGHT)
		lg.solid.fill(S.BLOCK if lv == -1 else S.AIR)
		lg.opq.fill(1 if lv == -1 else 0)
		levels[lv] = lg
	var data: Dictionary = {
		"grid": g, "levels": levels, "stairs": [], "containers": {}, "spots": {},
		"stoves": [], "entries": {}, "entry_gap": {}, "entry_levels": {},
		"buildings": [], "wagons": [], "train": Rect2i(16, 1, 80, 3),
		"platform": Rect2i(16, 4, 82, 6), "unload": Rect2i(16, 4, 82, 3),
		"train_cars": [], "spawns": {}, "labels": [], "trees": [], "low_blocks": [],
		"upper_rects": [], "lights": [], "manholes": {}, "manhole_levels": {},
		"sewer_names": {}, "anchors": {}, "zone_names": {}, "place_id": PLACE_ID,
		"place_kind": "freight", "bands": {"lower": Rect2i(0, 4, 116, 26)},
		"train_doors": {"lower": [Vector2i(34, 4), Vector2i(50, 4), Vector2i(66, 4)]},
		"crossings": [], "barricade_slots": [], "interior_kind_slots": [],
		"props": [], "hole_faces": {},
	}
	for row in plan["zones"]:
		data["zone_names"][row[0]] = row[1]
		var r := _rect(row[2])
		for y in range(r.position.y, r.end.y):
			for x in range(r.position.x, r.end.x):
				g.zone[g.index(Vector2i(x, y))] = row[0]
	for row in plan["floors"]:
		_fill_floor(levels[int(row[0])], Rect2i(row[1], row[2], row[3], row[4]), int(row[5]))
	_fill_floor(g, Rect2i(0, 1, WIDTH, 3), F.RAIL)
	_fill_floor(g, data["platform"], F.PLATFORM)
	_fill_solid(g, data["train"], S.BLOCK)
	for row in plan["buildings"]:
		var b: Dictionary = row.duplicate(true)
		b["rect"] = _rect(row["rect"])
		data["buildings"].append(b)
	for row in plan["shells"]:
		var lv: int = int(row[1])
		var r := Rect2i(row[2], row[3], row[4], row[5])
		_shell(levels[lv], int(row[0]), r, lv)
		if lv > 0:
			data["upper_rects"].append({"building": int(row[0]), "rect": r})
	for row in plan["walls"]:
		_fill_solid(levels[int(row[0])], Rect2i(row[1], row[2], row[3], row[4]), S.WALL)
	for row in plan["openings"]:
		_fill_solid(levels[int(row[0])], Rect2i(row[1], row[2], row[3], row[4]), S.NONE)
	for row in plan["windows"]:
		var lg: FieldGrid = levels[int(row[0])]
		var c := Vector2i(row[1], row[2])
		lg.set_solid(c, S.WINDOW)
		lg.windows[c] = {"broken": false, "glass": false, "building": int(row[3]), "cell": c}
	for row in plan["doors"]:
		var lg: FieldGrid = levels[int(row[0])]
		var c := Vector2i(row[1], row[2])
		lg.windows.erase(c)
		lg.set_solid(c, S.DOOR)
		lg.doors[c] = {"state": row[4], "hp": 8, "building": int(row[3]), "cell": c}
	for row in plan["stairs"]:
		var st: Dictionary = row.duplicate(true)
		st["cell"] = _cell(row["cell"])
		data["stairs"].append(st)
	for row in plan["props"]:
		var pr: Dictionary = row.duplicate(true)
		var r := _rect(row["rect"])
		pr["rect"] = r
		data["props"].append(pr)
		if int(pr["level"]) != 0:
			continue
		match String(pr["solid"]):
			"low":
				_fill_solid(g, r, S.LOW)
				if pr["kind"] == "water":
					_fill_floor(g, r, F.ICE)
				else:
					data["low_blocks"].append(r)
			"wall":
				_fill_solid(g, r, S.WALL)
			"tree":
				_fill_solid(g, r, S.BLOCK)
				data["trees"].append(r.position)
			"wagon":
				_fill_solid(g, r, S.BLOCK)
	for row in plan["wagons"]:
		var w: Dictionary = row.duplicate(true)
		w["rect"] = _rect(row["rect"])
		w["work"] = _cell(row["work"])
		data["wagons"].append(w)
	for row in plan["containers"]:
		var box: Dictionary = row.duplicate(true)
		box["cell"] = _cell(row["cell"])
		data["containers"][box["id"]] = box
	for row in plan["entries"]:
		var cs: Array[Vector2i] = []
		for c in row[1]:
			cs.append(_cell(c))
		data["entries"][row[0]] = cs
		data["entry_gap"][row[0]] = float(row[2])
	for row in plan["holes"]:
		var c := _cell(row[1])
		var id: String = row[0]
		data["manholes"][id] = c
		data["entries"][id] = [c]
		data["entry_gap"][id] = 3.0 if id.begins_with("manhole_") else 0.6
		data["sewer_names"][id] = row[2]
		if id.begins_with("manhole_"):
			data["labels"].append({"text": "맨홀", "cell": c + Vector2i(0, -1)})
		if id.begins_with("culvert_"):
			data["hole_faces"][id] = _cell(row[3])
	for row in plan["barricades"]:
		data["barricade_slots"].append(_cell(row))
	for row in plan["deep"]:
		data["interior_kind_slots"].append({"zone": row[0], "kinds": ["empty", "raiders", "nest", "beasts"]})
	for k in range(5):
		data["train_cars"].append({"rect": Rect2i(16 + 16 * k, 1, 16, 3), "kind": "engine" if k == 4 else "car"})
	var dead: Array[Vector2i] = []
	for c in plan["dead"]:
		dead.append(_cell(c))
	data["spawns"] = {"dead_yard": dead, "dead_levels": [], "squad": [Vector2i(50, 6), Vector2i(48, 7), Vector2i(52, 7), Vector2i(50, 8)], "train_door": data["train_doors"]["lower"].duplicate()}
	data["anchors"] = {"horde_home": Vector2i(50, 8), "whistle": Vector2i(90, 4), "flee_exit": _cell(plan["entries"][0][1][0]), "engine": Vector2i(92, 2)}
	if plan["work_site"].size() > 0:
		var work: Dictionary = plan["work_site"]
		data["spots"]["work_site"] = {"kind": "work_site", "cell": _cell(work["cell"]), "name": "석탄 작업 구역", "state": "closed", "zone_rect": _rect(work["rect"])}
	for row in plan["salvage"]:
		data["spots"][row[0]] = {"kind": "salvage", "name": row[1], "cell": _cell(row[2]), "material": row[3], "amount": 2, "state": "intact"}
	for lv in levels:
		var lg: FieldGrid = levels[lv]
		if lv != 0:
			lg.zone = g.zone.duplicate()
		lg.refresh_paths()
	return data


static func _cell(a: Array) -> Vector2i:
	return Vector2i(int(a[0]), int(a[1]))


static func _rect(a: Array) -> Rect2i:
	return Rect2i(int(a[0]), int(a[1]), int(a[2]), int(a[3]))


static func _fill_floor(g: FieldGrid, r: Rect2i, kind: int) -> void:
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			g.floor[g.index(Vector2i(x, y))] = kind


static func _fill_solid(g: FieldGrid, r: Rect2i, kind: int) -> void:
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			g.set_solid(Vector2i(x, y), kind)


static func _shell(g: FieldGrid, id: int, r: Rect2i, lv: int) -> void:
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			var c := Vector2i(x, y)
			g.building[g.index(c)] = id
			g.floor[g.index(c)] = F.GRAVEL if lv == -1 else F.WOOD
			var edge: bool = x == r.position.x or y == r.position.y or x == r.end.x - 1 or y == r.end.y - 1
			g.set_solid(c, S.WALL if edge else S.NONE)


# 보수 전 남쪽 배치는 PLAN에 그대로 보존한다. changed는 옛 좌표의 보수 범위다.
const SOUTH_REPAIRS: Dictionary = {
  "replace": {
    "281": {
      "kind": "bare_tree",
      "rect": [
        78,
        36,
        1,
        1
      ],
      "solid": "tree",
      "facing": 0,
      "note": "길가 마른 나무",
      "level": 0
    },
    "282": {
      "kind": "bare_tree",
      "rect": [
        81,
        37,
        1,
        1
      ],
      "solid": "tree",
      "facing": 0,
      "note": "길가 마른 나무",
      "level": 0
    },
    "283": {
      "kind": "bare_tree",
      "rect": [
        76,
        39,
        1,
        1
      ],
      "solid": "tree",
      "facing": 0,
      "note": "길가 마른 나무",
      "level": 0
    },
    "284": {
      "kind": "bare_tree",
      "rect": [
        80,
        41,
        1,
        1
      ],
      "solid": "tree",
      "facing": 0,
      "note": "길가 마른 나무",
      "level": 0
    },
    "285": {
      "kind": "bare_tree",
      "rect": [
        75,
        42,
        1,
        1
      ],
      "solid": "tree",
      "facing": 0,
      "note": "길가 마른 나무",
      "level": 0
    },
    "286": {
      "kind": "bare_tree",
      "rect": [
        106,
        46,
        1,
        1
      ],
      "solid": "tree",
      "facing": 0,
      "note": "길가 마른 나무",
      "level": 0
    },
    "287": {
      "kind": "bare_tree",
      "rect": [
        109,
        47,
        1,
        1
      ],
      "solid": "tree",
      "facing": 0,
      "note": "길가 마른 나무",
      "level": 0
    },
    "288": {
      "kind": "bare_tree",
      "rect": [
        104,
        49,
        1,
        1
      ],
      "solid": "tree",
      "facing": 0,
      "note": "길가 마른 나무",
      "level": 0
    },
    "289": {
      "kind": "bare_tree",
      "rect": [
        108,
        51,
        1,
        1
      ],
      "solid": "tree",
      "facing": 0,
      "note": "길가 마른 나무",
      "level": 0
    },
    "290": {
      "kind": "bare_tree",
      "rect": [
        103,
        52,
        1,
        1
      ],
      "solid": "tree",
      "facing": 0,
      "note": "길가 마른 나무",
      "level": 0
    },
    "291": {
      "kind": "bare_tree",
      "rect": [
        126,
        88,
        1,
        1
      ],
      "solid": "tree",
      "facing": 0,
      "note": "길가 마른 나무",
      "level": 0
    },
    "292": {
      "kind": "bare_tree",
      "rect": [
        129,
        89,
        1,
        1
      ],
      "solid": "tree",
      "facing": 0,
      "note": "길가 마른 나무",
      "level": 0
    },
    "293": {
      "kind": "bare_tree",
      "rect": [
        124,
        91,
        1,
        1
      ],
      "solid": "tree",
      "facing": 0,
      "note": "길가 마른 나무",
      "level": 0
    },
    "294": {
      "kind": "bare_tree",
      "rect": [
        128,
        93,
        1,
        1
      ],
      "solid": "tree",
      "facing": 0,
      "note": "길가 마른 나무",
      "level": 0
    },
    "295": {
      "kind": "bare_tree",
      "rect": [
        123,
        94,
        1,
        1
      ],
      "solid": "tree",
      "facing": 0,
      "note": "길가 마른 나무",
      "level": 0
    },
    "296": {
      "kind": "bare_tree",
      "rect": [
        60,
        68,
        1,
        1
      ],
      "solid": "tree",
      "facing": 0,
      "note": "길가 마른 나무",
      "level": 0
    },
    "297": {
      "kind": "bare_tree",
      "rect": [
        61,
        69,
        1,
        1
      ],
      "solid": "tree",
      "facing": 0,
      "note": "길가 마른 나무",
      "level": 0
    },
    "298": {
      "kind": "bare_tree",
      "rect": [
        58,
        71,
        1,
        1
      ],
      "solid": "tree",
      "facing": 0,
      "note": "길가 마른 나무",
      "level": 0
    },
    "299": {
      "kind": "bare_tree",
      "rect": [
        61,
        73,
        1,
        1
      ],
      "solid": "tree",
      "facing": 0,
      "note": "길가 마른 나무",
      "level": 0
    },
    "300": {
      "kind": "bare_tree",
      "rect": [
        57,
        74,
        1,
        1
      ],
      "solid": "tree",
      "facing": 0,
      "note": "길가 마른 나무",
      "level": 0
    },
    "301": {
      "kind": "bare_tree",
      "rect": [
        33,
        73,
        1,
        1
      ],
      "solid": "tree",
      "facing": 0,
      "note": "길가 마른 나무",
      "level": 0
    },
    "302": {
      "kind": "bare_tree",
      "rect": [
        36,
        74,
        1,
        1
      ],
      "solid": "tree",
      "facing": 0,
      "note": "길가 마른 나무",
      "level": 0
    },
    "303": {
      "kind": "bare_tree",
      "rect": [
        31,
        76,
        1,
        1
      ],
      "solid": "tree",
      "facing": 0,
      "note": "길가 마른 나무",
      "level": 0
    },
    "304": {
      "kind": "bare_tree",
      "rect": [
        35,
        78,
        1,
        1
      ],
      "solid": "tree",
      "facing": 0,
      "note": "길가 마른 나무",
      "level": 0
    },
    "305": {
      "kind": "bare_tree",
      "rect": [
        30,
        79,
        1,
        1
      ],
      "solid": "tree",
      "facing": 0,
      "note": "길가 마른 나무",
      "level": 0
    },
    "306": {
      "kind": "bare_tree",
      "rect": [
        151,
        72,
        1,
        1
      ],
      "solid": "tree",
      "facing": 0,
      "note": "길가 마른 나무",
      "level": 0
    },
    "307": {
      "kind": "bare_tree",
      "rect": [
        154,
        73,
        1,
        1
      ],
      "solid": "tree",
      "facing": 0,
      "note": "길가 마른 나무",
      "level": 0
    },
    "308": {
      "kind": "bare_tree",
      "rect": [
        149,
        75,
        1,
        1
      ],
      "solid": "tree",
      "facing": 0,
      "note": "길가 마른 나무",
      "level": 0
    },
    "309": {
      "kind": "bare_tree",
      "rect": [
        153,
        77,
        1,
        1
      ],
      "solid": "tree",
      "facing": 0,
      "note": "길가 마른 나무",
      "level": 0
    },
    "310": {
      "kind": "bare_tree",
      "rect": [
        151,
        78,
        1,
        1
      ],
      "solid": "tree",
      "facing": 0,
      "note": "길가 마른 나무",
      "level": 0
    },
    "311": {
      "kind": "bare_tree",
      "rect": [
        72,
        59,
        1,
        1
      ],
      "solid": "tree",
      "facing": 0,
      "note": "길가 마른 나무",
      "level": 0
    },
    "312": {
      "kind": "bare_tree",
      "rect": [
        75,
        60,
        1,
        1
      ],
      "solid": "tree",
      "facing": 0,
      "note": "길가 마른 나무",
      "level": 0
    },
    "313": {
      "kind": "bare_tree",
      "rect": [
        70,
        62,
        1,
        1
      ],
      "solid": "tree",
      "facing": 0,
      "note": "길가 마른 나무",
      "level": 0
    },
    "314": {
      "kind": "bare_tree",
      "rect": [
        74,
        64,
        1,
        1
      ],
      "solid": "tree",
      "facing": 0,
      "note": "길가 마른 나무",
      "level": 0
    },
    "11": {
      "kind": "crate_stack",
      "rect": [
        86,
        24,
        2,
        2
      ],
      "solid": "low",
      "facing": 0,
      "note": "나무 상자 더미",
      "level": 0
    }
  },
  "remove": [],
  "append": [],
  "work_site": {
    "cell": [
      108,
      20
    ],
    "rect": [
      98,
      12,
      42,
      21
    ]
  },
  "changed": [
    [
      66,
      36,
      1,
      1
    ],
    [
      78,
      36,
      1,
      1
    ],
    [
      72,
      36,
      1,
      1
    ],
    [
      81,
      37,
      1,
      1
    ],
    [
      78,
      36,
      1,
      1
    ],
    [
      76,
      39,
      1,
      1
    ],
    [
      84,
      36,
      1,
      1
    ],
    [
      80,
      41,
      1,
      1
    ],
    [
      90,
      36,
      1,
      1
    ],
    [
      75,
      42,
      1,
      1
    ],
    [
      96,
      36,
      1,
      1
    ],
    [
      106,
      46,
      1,
      1
    ],
    [
      102,
      36,
      1,
      1
    ],
    [
      109,
      47,
      1,
      1
    ],
    [
      108,
      36,
      1,
      1
    ],
    [
      104,
      49,
      1,
      1
    ],
    [
      114,
      36,
      1,
      1
    ],
    [
      108,
      51,
      1,
      1
    ],
    [
      111,
      85,
      1,
      1
    ],
    [
      103,
      52,
      1,
      1
    ],
    [
      116,
      86,
      1,
      1
    ],
    [
      126,
      88,
      1,
      1
    ],
    [
      121,
      87,
      1,
      1
    ],
    [
      129,
      89,
      1,
      1
    ],
    [
      126,
      88,
      1,
      1
    ],
    [
      124,
      91,
      1,
      1
    ],
    [
      131,
      89,
      1,
      1
    ],
    [
      128,
      93,
      1,
      1
    ],
    [
      136,
      90,
      1,
      1
    ],
    [
      123,
      94,
      1,
      1
    ],
    [
      141,
      91,
      1,
      1
    ],
    [
      60,
      68,
      1,
      1
    ],
    [
      146,
      92,
      1,
      1
    ],
    [
      61,
      69,
      1,
      1
    ],
    [
      5,
      45,
      1,
      1
    ],
    [
      58,
      71,
      1,
      1
    ],
    [
      5,
      52,
      1,
      1
    ],
    [
      61,
      73,
      1,
      1
    ],
    [
      5,
      59,
      1,
      1
    ],
    [
      57,
      74,
      1,
      1
    ],
    [
      5,
      66,
      1,
      1
    ],
    [
      33,
      73,
      1,
      1
    ],
    [
      5,
      73,
      1,
      1
    ],
    [
      36,
      74,
      1,
      1
    ],
    [
      5,
      80,
      1,
      1
    ],
    [
      31,
      76,
      1,
      1
    ],
    [
      5,
      87,
      1,
      1
    ],
    [
      35,
      78,
      1,
      1
    ],
    [
      145,
      57,
      1,
      1
    ],
    [
      30,
      79,
      1,
      1
    ],
    [
      147,
      62,
      1,
      1
    ],
    [
      151,
      72,
      1,
      1
    ],
    [
      149,
      67,
      1,
      1
    ],
    [
      154,
      73,
      1,
      1
    ],
    [
      151,
      72,
      1,
      1
    ],
    [
      149,
      75,
      1,
      1
    ],
    [
      153,
      77,
      1,
      1
    ],
    [
      153,
      77,
      1,
      1
    ],
    [
      155,
      82,
      1,
      1
    ],
    [
      151,
      78,
      1,
      1
    ],
    [
      157,
      87,
      1,
      1
    ],
    [
      72,
      59,
      1,
      1
    ],
    [
      43,
      44,
      1,
      1
    ],
    [
      75,
      60,
      1,
      1
    ],
    [
      43,
      49,
      1,
      1
    ],
    [
      70,
      62,
      1,
      1
    ],
    [
      43,
      54,
      1,
      1
    ],
    [
      74,
      64,
      1,
      1
    ],
    [
      87,
      24,
      2,
      2
    ],
    [
      86,
      24,
      2,
      2
    ],
    [
      0,
      4,
      16,
      6
    ]
  ],
  "floors": [
    [
      0,
      0,
      4,
      16,
      6,
      1
    ]
  ]
}

const NORTH_PLAN: Dictionary = {
  "id": "freight_01",
  "size": [
    160,
    140
  ],
  "offset": 17,
  "judgment": "목재를 썰매 가득 얻는 대신 아래쪽 석탄 싣기에서 사람이 빠지고, 썰매를 끌고 제재 마당을 오가는 길이 길다.",
  "zones": [
    [
      "I",
      "서쪽 제재 마당",
      [
        0,
        0,
        64,
        46
      ]
    ],
    [
      "J",
      "건조 마당",
      [
        64,
        0,
        52,
        46
      ]
    ],
    [
      "K",
      "동쪽 인입선 구내",
      [
        116,
        0,
        44,
        46
      ]
    ]
  ],
  "floors": [
    [
      0,
      0,
      0,
      160,
      24,
      7
    ],
    [
      0,
      0,
      24,
      116,
      22,
      0
    ],
    [
      0,
      116,
      24,
      44,
      22,
      7
    ],
    [
      0,
      0,
      25,
      18,
      14,
      5
    ],
    [
      0,
      0,
      2,
      132,
      6,
      1
    ],
    [
      0,
      64,
      8,
      6,
      35,
      1
    ],
    [
      0,
      94,
      8,
      5,
      35,
      1
    ],
    [
      0,
      116,
      8,
      4,
      38,
      1
    ],
    [
      0,
      0,
      40,
      16,
      6,
      1
    ],
    [
      0,
      96,
      40,
      64,
      6,
      1
    ],
    [
      0,
      76,
      0,
      4,
      10,
      1
    ],
    [
      0,
      118,
      17,
      42,
      3,
      4
    ],
    [
      0,
      154,
      6,
      5,
      5,
      7
    ]
  ],
  "buildings": [
    {
      "id": 17,
      "name": "제재소 본동",
      "rect": [
        30,
        9,
        34,
        15
      ],
      "warm": false,
      "window_broken": false
    },
    {
      "id": 18,
      "name": "건조 창고 가",
      "rect": [
        70,
        10,
        24,
        14
      ],
      "warm": false,
      "window_broken": false
    },
    {
      "id": 19,
      "name": "장작 창고",
      "rect": [
        99,
        12,
        17,
        12
      ],
      "warm": false,
      "window_broken": false
    },
    {
      "id": 20,
      "name": "목재 사무소",
      "rect": [
        8,
        10,
        10,
        8
      ],
      "warm": false,
      "window_broken": false
    },
    {
      "id": 21,
      "name": "날 수선 헛간",
      "rect": [
        116,
        24,
        16,
        10
      ],
      "warm": false,
      "window_broken": false
    },
    {
      "id": 22,
      "name": "목재 선별 창고",
      "rect": [
        134,
        26,
        24,
        14
      ],
      "warm": false,
      "window_broken": false
    },
    {
      "id": 23,
      "name": "동력실",
      "rect": [
        116,
        38,
        14,
        8
      ],
      "warm": false,
      "window_broken": false
    },
    {
      "id": 24,
      "name": "건조 헛간",
      "rect": [
        134,
        3,
        20,
        10
      ],
      "warm": false,
      "window_broken": false
    }
  ],
  "shells": [
    [
      17,
      0,
      30,
      9,
      34,
      15
    ],
    [
      17,
      1,
      30,
      9,
      34,
      15
    ],
    [
      18,
      0,
      70,
      10,
      24,
      14
    ],
    [
      18,
      1,
      70,
      10,
      24,
      14
    ],
    [
      19,
      0,
      99,
      12,
      17,
      12
    ],
    [
      20,
      0,
      8,
      10,
      10,
      8
    ],
    [
      21,
      0,
      116,
      24,
      16,
      10
    ],
    [
      22,
      -1,
      134,
      26,
      24,
      14
    ],
    [
      22,
      0,
      134,
      26,
      24,
      14
    ],
    [
      22,
      1,
      134,
      26,
      24,
      14
    ],
    [
      22,
      2,
      134,
      26,
      24,
      14
    ],
    [
      23,
      0,
      116,
      38,
      14,
      8
    ],
    [
      24,
      -1,
      134,
      3,
      20,
      10
    ],
    [
      24,
      0,
      134,
      3,
      20,
      10
    ]
  ],
  "walls": [
    [
      0,
      31,
      14,
      32,
      1
    ],
    [
      0,
      31,
      17,
      32,
      1
    ],
    [
      0,
      41,
      10,
      1,
      4
    ],
    [
      0,
      52,
      10,
      1,
      4
    ],
    [
      0,
      41,
      18,
      1,
      5
    ],
    [
      0,
      52,
      18,
      1,
      5
    ],
    [
      1,
      31,
      14,
      32,
      1
    ],
    [
      1,
      31,
      17,
      32,
      1
    ],
    [
      1,
      41,
      10,
      1,
      4
    ],
    [
      1,
      52,
      10,
      1,
      4
    ],
    [
      1,
      41,
      18,
      1,
      5
    ],
    [
      1,
      52,
      18,
      1,
      5
    ],
    [
      0,
      82,
      11,
      1,
      12
    ],
    [
      1,
      82,
      11,
      1,
      12
    ],
    [
      0,
      107,
      13,
      1,
      10
    ],
    [
      0,
      124,
      25,
      1,
      8
    ],
    [
      -1,
      146,
      27,
      1,
      12
    ],
    [
      0,
      146,
      27,
      1,
      12
    ],
    [
      1,
      146,
      27,
      1,
      12
    ],
    [
      2,
      146,
      27,
      1,
      12
    ],
    [
      0,
      123,
      39,
      1,
      6
    ],
    [
      -1,
      135,
      6,
      18,
      1
    ],
    [
      -1,
      143,
      7,
      1,
      5
    ],
    [
      0,
      144,
      4,
      1,
      8
    ]
  ],
  "openings": [
    [
      0,
      32,
      15,
      1,
      2
    ],
    [
      1,
      32,
      15,
      1,
      2
    ],
    [
      0,
      61,
      15,
      1,
      2
    ],
    [
      1,
      61,
      15,
      1,
      2
    ],
    [
      0,
      72,
      17,
      1,
      2
    ],
    [
      1,
      72,
      17,
      1,
      2
    ],
    [
      -1,
      136,
      33,
      1,
      2
    ],
    [
      0,
      136,
      33,
      1,
      2
    ],
    [
      0,
      136,
      33,
      1,
      2
    ],
    [
      1,
      136,
      33,
      1,
      2
    ],
    [
      1,
      136,
      33,
      1,
      2
    ],
    [
      2,
      136,
      33,
      1,
      2
    ],
    [
      -1,
      136,
      4,
      1,
      6
    ],
    [
      0,
      136,
      8,
      1,
      2
    ]
  ],
  "doors": [
    [
      0,
      36,
      14,
      17,
      "closed",
      0,
      1
    ],
    [
      0,
      47,
      14,
      17,
      "closed",
      0,
      1
    ],
    [
      0,
      58,
      14,
      17,
      "closed",
      0,
      1
    ],
    [
      0,
      36,
      17,
      17,
      "closed",
      0,
      1
    ],
    [
      0,
      47,
      17,
      17,
      "closed",
      0,
      1
    ],
    [
      0,
      58,
      17,
      17,
      "closed",
      0,
      1
    ],
    [
      1,
      36,
      14,
      17,
      "closed",
      0,
      1
    ],
    [
      1,
      47,
      14,
      17,
      "closed",
      0,
      1
    ],
    [
      1,
      58,
      14,
      17,
      "closed",
      0,
      1
    ],
    [
      1,
      36,
      17,
      17,
      "closed",
      0,
      1
    ],
    [
      1,
      47,
      17,
      17,
      "closed",
      0,
      1
    ],
    [
      1,
      58,
      17,
      17,
      "closed",
      0,
      1
    ],
    [
      0,
      58,
      23,
      17,
      "closed",
      0,
      1
    ],
    [
      0,
      82,
      17,
      18,
      "closed",
      1,
      0
    ],
    [
      1,
      82,
      17,
      18,
      "closed",
      1,
      0
    ],
    [
      0,
      76,
      10,
      18,
      "closed",
      0,
      1
    ],
    [
      0,
      107,
      18,
      19,
      "closed",
      1,
      0
    ],
    [
      0,
      103,
      12,
      19,
      "closed",
      0,
      1
    ],
    [
      0,
      17,
      14,
      20,
      "closed",
      1,
      0
    ],
    [
      0,
      124,
      29,
      21,
      "closed",
      1,
      0
    ],
    [
      0,
      131,
      29,
      21,
      "closed",
      1,
      0
    ],
    [
      -1,
      146,
      33,
      22,
      "closed",
      1,
      0
    ],
    [
      0,
      146,
      33,
      22,
      "closed",
      1,
      0
    ],
    [
      1,
      146,
      33,
      22,
      "closed",
      1,
      0
    ],
    [
      2,
      146,
      33,
      22,
      "closed",
      1,
      0
    ],
    [
      0,
      134,
      33,
      22,
      "closed",
      1,
      0
    ],
    [
      0,
      123,
      42,
      23,
      "closed",
      1,
      0
    ],
    [
      0,
      129,
      42,
      23,
      "closed",
      1,
      0
    ],
    [
      -1,
      139,
      6,
      24,
      "closed",
      0,
      1
    ],
    [
      -1,
      148,
      6,
      24,
      "closed",
      0,
      1
    ],
    [
      0,
      144,
      8,
      24,
      "closed",
      1,
      0
    ],
    [
      0,
      153,
      8,
      24,
      "closed",
      1,
      0
    ]
  ],
  "windows": [
    [
      0,
      33,
      9,
      17
    ],
    [
      0,
      40,
      9,
      17
    ],
    [
      0,
      47,
      9,
      17
    ],
    [
      0,
      54,
      9,
      17
    ],
    [
      0,
      61,
      9,
      17
    ],
    [
      0,
      63,
      12,
      17
    ],
    [
      0,
      63,
      17,
      17
    ],
    [
      1,
      33,
      9,
      17
    ],
    [
      1,
      40,
      9,
      17
    ],
    [
      1,
      47,
      9,
      17
    ],
    [
      1,
      54,
      9,
      17
    ],
    [
      1,
      61,
      9,
      17
    ],
    [
      1,
      63,
      12,
      17
    ],
    [
      1,
      63,
      17,
      17
    ],
    [
      0,
      73,
      10,
      18
    ],
    [
      0,
      80,
      10,
      18
    ],
    [
      0,
      87,
      10,
      18
    ],
    [
      0,
      93,
      13,
      18
    ],
    [
      0,
      93,
      18,
      18
    ],
    [
      1,
      73,
      10,
      18
    ],
    [
      1,
      80,
      10,
      18
    ],
    [
      1,
      87,
      10,
      18
    ],
    [
      1,
      93,
      13,
      18
    ],
    [
      1,
      93,
      18,
      18
    ],
    [
      0,
      102,
      12,
      19
    ],
    [
      0,
      109,
      12,
      19
    ],
    [
      0,
      115,
      15,
      19
    ],
    [
      0,
      115,
      20,
      19
    ],
    [
      0,
      11,
      10,
      20
    ],
    [
      0,
      17,
      13,
      20
    ],
    [
      0,
      119,
      24,
      21
    ],
    [
      0,
      126,
      24,
      21
    ],
    [
      0,
      131,
      27,
      21
    ],
    [
      0,
      137,
      26,
      22
    ],
    [
      0,
      144,
      26,
      22
    ],
    [
      0,
      151,
      26,
      22
    ],
    [
      0,
      157,
      29,
      22
    ],
    [
      0,
      157,
      34,
      22
    ],
    [
      1,
      137,
      26,
      22
    ],
    [
      1,
      144,
      26,
      22
    ],
    [
      1,
      151,
      26,
      22
    ],
    [
      1,
      157,
      29,
      22
    ],
    [
      1,
      157,
      34,
      22
    ],
    [
      2,
      137,
      26,
      22
    ],
    [
      2,
      144,
      26,
      22
    ],
    [
      2,
      151,
      26,
      22
    ],
    [
      2,
      157,
      29,
      22
    ],
    [
      2,
      157,
      34,
      22
    ],
    [
      0,
      119,
      38,
      23
    ],
    [
      0,
      126,
      38,
      23
    ],
    [
      0,
      129,
      41,
      23
    ],
    [
      0,
      137,
      3,
      24
    ],
    [
      0,
      144,
      3,
      24
    ],
    [
      0,
      151,
      3,
      24
    ],
    [
      0,
      153,
      6,
      24
    ]
  ],
  "rooms": [
    {
      "building": 17,
      "level": 0,
      "rect": [
        31,
        10,
        10,
        4
      ],
      "name": "선별실"
    },
    {
      "building": 17,
      "level": 0,
      "rect": [
        42,
        10,
        10,
        4
      ],
      "name": "원료 칸"
    },
    {
      "building": 17,
      "level": 0,
      "rect": [
        53,
        10,
        10,
        4
      ],
      "name": "가공 칸"
    },
    {
      "building": 17,
      "level": 0,
      "rect": [
        31,
        18,
        10,
        5
      ],
      "name": "계량실"
    },
    {
      "building": 17,
      "level": 0,
      "rect": [
        42,
        18,
        10,
        5
      ],
      "name": "공구 칸"
    },
    {
      "building": 17,
      "level": 0,
      "rect": [
        53,
        18,
        10,
        5
      ],
      "name": "안쪽 보관실"
    },
    {
      "building": 17,
      "level": 1,
      "rect": [
        31,
        10,
        10,
        4
      ],
      "name": "선별실"
    },
    {
      "building": 17,
      "level": 1,
      "rect": [
        42,
        10,
        10,
        4
      ],
      "name": "원료 칸"
    },
    {
      "building": 17,
      "level": 1,
      "rect": [
        53,
        10,
        10,
        4
      ],
      "name": "가공 칸"
    },
    {
      "building": 17,
      "level": 1,
      "rect": [
        31,
        18,
        10,
        5
      ],
      "name": "계량실"
    },
    {
      "building": 17,
      "level": 1,
      "rect": [
        42,
        18,
        10,
        5
      ],
      "name": "공구 칸"
    },
    {
      "building": 17,
      "level": 1,
      "rect": [
        53,
        18,
        10,
        5
      ],
      "name": "안쪽 보관실"
    },
    {
      "building": 18,
      "level": 0,
      "rect": [
        71,
        11,
        11,
        12
      ],
      "name": "앞 작업 칸"
    },
    {
      "building": 18,
      "level": 0,
      "rect": [
        83,
        11,
        10,
        12
      ],
      "name": "안쪽 보관실"
    },
    {
      "building": 18,
      "level": 1,
      "rect": [
        71,
        11,
        11,
        12
      ],
      "name": "앞 작업 칸"
    },
    {
      "building": 18,
      "level": 1,
      "rect": [
        83,
        11,
        10,
        12
      ],
      "name": "안쪽 보관실"
    },
    {
      "building": 19,
      "level": 0,
      "rect": [
        100,
        13,
        7,
        10
      ],
      "name": "앞 작업 칸"
    },
    {
      "building": 19,
      "level": 0,
      "rect": [
        108,
        13,
        7,
        10
      ],
      "name": "안쪽 보관실"
    },
    {
      "building": 20,
      "level": 0,
      "rect": [
        9,
        11,
        8,
        6
      ],
      "name": "작업 칸"
    },
    {
      "building": 21,
      "level": 0,
      "rect": [
        117,
        25,
        7,
        8
      ],
      "name": "앞 작업 칸"
    },
    {
      "building": 21,
      "level": 0,
      "rect": [
        125,
        25,
        6,
        8
      ],
      "name": "안쪽 보관실"
    },
    {
      "building": 22,
      "level": -1,
      "rect": [
        135,
        27,
        11,
        12
      ],
      "name": "목재 앞 저장고"
    },
    {
      "building": 22,
      "level": -1,
      "rect": [
        147,
        27,
        10,
        12
      ],
      "name": "목재 안쪽 보관실"
    },
    {
      "building": 22,
      "level": 0,
      "rect": [
        135,
        27,
        11,
        12
      ],
      "name": "앞 작업 칸"
    },
    {
      "building": 22,
      "level": 0,
      "rect": [
        147,
        27,
        10,
        12
      ],
      "name": "안쪽 보관실"
    },
    {
      "building": 22,
      "level": 1,
      "rect": [
        135,
        27,
        11,
        12
      ],
      "name": "앞 작업 칸"
    },
    {
      "building": 22,
      "level": 1,
      "rect": [
        147,
        27,
        10,
        12
      ],
      "name": "안쪽 보관실"
    },
    {
      "building": 22,
      "level": 2,
      "rect": [
        135,
        27,
        11,
        12
      ],
      "name": "앞 작업 칸"
    },
    {
      "building": 22,
      "level": 2,
      "rect": [
        147,
        27,
        10,
        12
      ],
      "name": "안쪽 보관실"
    },
    {
      "building": 23,
      "level": 0,
      "rect": [
        117,
        39,
        6,
        6
      ],
      "name": "앞 작업 칸"
    },
    {
      "building": 23,
      "level": 0,
      "rect": [
        124,
        39,
        5,
        6
      ],
      "name": "안쪽 보관실"
    },
    {
      "building": 24,
      "level": -1,
      "rect": [
        135,
        7,
        8,
        5
      ],
      "name": "목재 앞 저장고"
    },
    {
      "building": 24,
      "level": -1,
      "rect": [
        144,
        7,
        9,
        5
      ],
      "name": "목재 안쪽 보관실"
    },
    {
      "building": 24,
      "level": 0,
      "rect": [
        135,
        4,
        9,
        8
      ],
      "name": "앞 작업 칸"
    },
    {
      "building": 24,
      "level": 0,
      "rect": [
        145,
        4,
        8,
        8
      ],
      "name": "안쪽 보관실"
    }
  ],
  "stairs": [
    {
      "cell": [
        32,
        15
      ],
      "low": 0,
      "high": 1,
      "ladder": false
    },
    {
      "cell": [
        61,
        16
      ],
      "low": 0,
      "high": 1,
      "ladder": false
    },
    {
      "cell": [
        72,
        17
      ],
      "low": 0,
      "high": 1,
      "ladder": false
    },
    {
      "cell": [
        136,
        33
      ],
      "low": -1,
      "high": 0,
      "ladder": false
    },
    {
      "cell": [
        136,
        33
      ],
      "low": 0,
      "high": 1,
      "ladder": false
    },
    {
      "cell": [
        136,
        33
      ],
      "low": 1,
      "high": 2,
      "ladder": false
    },
    {
      "cell": [
        136,
        8
      ],
      "low": -1,
      "high": 0,
      "ladder": false
    }
  ],
  "props": [
    {
      "kind": "sleeper_pile",
      "rect": [
        31,
        38,
        3,
        2
      ],
      "solid": "low",
      "facing": 0,
      "note": "침목 더미",
      "level": 0
    },
    {
      "kind": "log_pile",
      "rect": [
        62,
        36,
        4,
        2
      ],
      "solid": "low",
      "facing": 0,
      "note": "통나무 더미",
      "level": 0
    },
    {
      "kind": "rail_pile",
      "rect": [
        84,
        33,
        1,
        3
      ],
      "solid": "low",
      "facing": 0,
      "note": "레일 더미",
      "level": 0
    },
    {
      "kind": "sack_pile",
      "rect": [
        100,
        28,
        2,
        2
      ],
      "solid": "low",
      "facing": 0,
      "note": "자루 더미",
      "level": 0
    },
    {
      "kind": "flat_wagon",
      "rect": [
        122,
        17,
        12,
        3
      ],
      "solid": "wagon",
      "facing": 0,
      "note": "문 열린 평판 화차",
      "level": 0
    },
    {
      "kind": "flat_wagon",
      "rect": [
        139,
        17,
        12,
        3
      ],
      "solid": "wagon",
      "facing": 0,
      "note": "문 열린 평판 화차",
      "level": 0
    },
    {
      "kind": "buffer_stop",
      "rect": [
        118,
        18,
        2,
        1
      ],
      "solid": "low",
      "facing": 0,
      "note": "선로 끝 완충기",
      "level": 0
    },
    {
      "kind": "bare_tree",
      "rect": [
        40,
        0,
        1,
        1
      ],
      "solid": "tree",
      "facing": 0,
      "note": "마른 나무",
      "level": 0
    },
    {
      "kind": "bare_tree",
      "rect": [
        45,
        1,
        1,
        1
      ],
      "solid": "tree",
      "facing": 0,
      "note": "마른 나무",
      "level": 0
    },
    {
      "kind": "bare_tree",
      "rect": [
        49,
        0,
        1,
        1
      ],
      "solid": "tree",
      "facing": 0,
      "note": "마른 나무",
      "level": 0
    },
    {
      "kind": "bare_tree",
      "rect": [
        54,
        1,
        1,
        1
      ],
      "solid": "tree",
      "facing": 0,
      "note": "마른 나무",
      "level": 0
    },
    {
      "kind": "bare_tree",
      "rect": [
        58,
        0,
        1,
        1
      ],
      "solid": "tree",
      "facing": 0,
      "note": "마른 나무",
      "level": 0
    },
    {
      "kind": "bare_tree",
      "rect": [
        3,
        18,
        1,
        1
      ],
      "solid": "tree",
      "facing": 0,
      "note": "마른 나무",
      "level": 0
    },
    {
      "kind": "bare_tree",
      "rect": [
        6,
        21,
        1,
        1
      ],
      "solid": "tree",
      "facing": 0,
      "note": "마른 나무",
      "level": 0
    },
    {
      "kind": "bare_tree",
      "rect": [
        10,
        19,
        1,
        1
      ],
      "solid": "tree",
      "facing": 0,
      "note": "마른 나무",
      "level": 0
    },
    {
      "kind": "bare_tree",
      "rect": [
        13,
        22,
        1,
        1
      ],
      "solid": "tree",
      "facing": 0,
      "note": "마른 나무",
      "level": 0
    },
    {
      "kind": "bare_tree",
      "rect": [
        140,
        23,
        1,
        1
      ],
      "solid": "tree",
      "facing": 0,
      "note": "마른 나무",
      "level": 0
    },
    {
      "kind": "bare_tree",
      "rect": [
        148,
        22,
        1,
        1
      ],
      "solid": "tree",
      "facing": 0,
      "note": "마른 나무",
      "level": 0
    },
    {
      "kind": "bare_tree",
      "rect": [
        156,
        24,
        1,
        1
      ],
      "solid": "tree",
      "facing": 0,
      "note": "마른 나무",
      "level": 0
    },
    {
      "kind": "car",
      "rect": [
        20,
        0,
        4,
        2
      ],
      "solid": "low",
      "facing": 1,
      "note": "구내 길가에 비스듬히 세운 차",
      "level": 0
    },
    {
      "kind": "shelf",
      "rect": [
        31,
        10,
        3,
        1
      ],
      "solid": "low",
      "facing": 0,
      "note": "선별실 곁 선반",
      "level": 0
    },
    {
      "kind": "desk",
      "rect": [
        34,
        10,
        2,
        1
      ],
      "solid": "low",
      "facing": 0,
      "note": "선별실 곁 책상",
      "level": 0
    },
    {
      "kind": "file_cabinet",
      "rect": [
        36,
        10,
        2,
        1
      ],
      "solid": "low",
      "facing": 0,
      "note": "선별실 곁 서류함",
      "level": 0
    },
    {
      "kind": "pallet_stack",
      "rect": [
        42,
        10,
        2,
        2
      ],
      "solid": "low",
      "facing": 0,
      "note": "원료 칸 곁 팰릿 더미",
      "level": 0
    },
    {
      "kind": "barrel",
      "rect": [
        44,
        10,
        1,
        1
      ],
      "solid": "low",
      "facing": 0,
      "note": "원료 칸 곁 통",
      "level": 0
    },
    {
      "kind": "tool_cart",
      "rect": [
        53,
        10,
        2,
        1
      ],
      "solid": "low",
      "facing": 0,
      "note": "가공 칸 곁 공구 수레",
      "level": 0
    },
    {
      "kind": "part_crate",
      "rect": [
        55,
        10,
        1,
        1
      ],
      "solid": "low",
      "facing": 0,
      "note": "가공 칸 곁 부품 상자",
      "level": 0
    },
    {
      "kind": "coupler_set",
      "rect": [
        56,
        10,
        1,
        1
      ],
      "solid": "low",
      "facing": 0,
      "note": "가공 칸 곁 연결기 한 벌",
      "level": 0
    },
    {
      "kind": "sack_pile",
      "rect": [
        31,
        18,
        2,
        2
      ],
      "solid": "low",
      "facing": 0,
      "note": "계량실 곁 자루 더미",
      "level": 0
    },
    {
      "kind": "handcart",
      "rect": [
        33,
        18,
        2,
        1
      ],
      "solid": "low",
      "facing": 0,
      "note": "계량실 곁 손수레",
      "level": 0
    },
    {
      "kind": "barrel",
      "rect": [
        35,
        18,
        1,
        1
      ],
      "solid": "low",
      "facing": 0,
      "note": "계량실 곁 통",
      "level": 0
    },
    {
      "kind": "shelf",
      "rect": [
        42,
        18,
        3,
        1
      ],
      "solid": "low",
      "facing": 0,
      "note": "공구 칸 곁 선반",
      "level": 0
    },
    {
      "kind": "crate_stack",
      "rect": [
        45,
        18,
        2,
        2
      ],
      "solid": "low",
      "facing": 0,
      "note": "공구 칸 곁 나무 상자 더미",
      "level": 0
    },
    {
      "kind": "rope_coil",
      "rect": [
        48,
        18,
        1,
        1
      ],
      "solid": "low",
      "facing": 0,
      "note": "공구 칸 곁 밧줄 더미",
      "level": 0
    },
    {
      "kind": "part_crate",
      "rect": [
        53,
        18,
        1,
        1
      ],
      "solid": "low",
      "facing": 0,
      "note": "안쪽 보관실 곁 부품 상자",
      "level": 0
    },
    {
      "kind": "barrel",
      "rect": [
        54,
        18,
        1,
        1
      ],
      "solid": "low",
      "facing": 0,
      "note": "안쪽 보관실 곁 통",
      "level": 0
    },
    {
      "kind": "shelf",
      "rect": [
        31,
        10,
        3,
        1
      ],
      "solid": "none",
      "facing": 0,
      "note": "선별실 곁 선반",
      "level": 1
    },
    {
      "kind": "desk",
      "rect": [
        34,
        10,
        2,
        1
      ],
      "solid": "none",
      "facing": 0,
      "note": "선별실 곁 책상",
      "level": 1
    },
    {
      "kind": "file_cabinet",
      "rect": [
        36,
        10,
        2,
        1
      ],
      "solid": "none",
      "facing": 0,
      "note": "선별실 곁 서류함",
      "level": 1
    },
    {
      "kind": "pallet_stack",
      "rect": [
        42,
        10,
        2,
        2
      ],
      "solid": "none",
      "facing": 0,
      "note": "원료 칸 곁 팰릿 더미",
      "level": 1
    },
    {
      "kind": "barrel",
      "rect": [
        44,
        10,
        1,
        1
      ],
      "solid": "none",
      "facing": 0,
      "note": "원료 칸 곁 통",
      "level": 1
    },
    {
      "kind": "tool_cart",
      "rect": [
        53,
        10,
        2,
        1
      ],
      "solid": "none",
      "facing": 0,
      "note": "가공 칸 곁 공구 수레",
      "level": 1
    },
    {
      "kind": "part_crate",
      "rect": [
        55,
        10,
        1,
        1
      ],
      "solid": "none",
      "facing": 0,
      "note": "가공 칸 곁 부품 상자",
      "level": 1
    },
    {
      "kind": "coupler_set",
      "rect": [
        56,
        10,
        1,
        1
      ],
      "solid": "none",
      "facing": 0,
      "note": "가공 칸 곁 연결기 한 벌",
      "level": 1
    },
    {
      "kind": "sack_pile",
      "rect": [
        31,
        18,
        2,
        2
      ],
      "solid": "none",
      "facing": 0,
      "note": "계량실 곁 자루 더미",
      "level": 1
    },
    {
      "kind": "handcart",
      "rect": [
        33,
        18,
        2,
        1
      ],
      "solid": "none",
      "facing": 0,
      "note": "계량실 곁 손수레",
      "level": 1
    },
    {
      "kind": "barrel",
      "rect": [
        35,
        18,
        1,
        1
      ],
      "solid": "none",
      "facing": 0,
      "note": "계량실 곁 통",
      "level": 1
    },
    {
      "kind": "shelf",
      "rect": [
        42,
        18,
        3,
        1
      ],
      "solid": "none",
      "facing": 0,
      "note": "공구 칸 곁 선반",
      "level": 1
    },
    {
      "kind": "crate_stack",
      "rect": [
        45,
        18,
        2,
        2
      ],
      "solid": "none",
      "facing": 0,
      "note": "공구 칸 곁 나무 상자 더미",
      "level": 1
    },
    {
      "kind": "rope_coil",
      "rect": [
        48,
        18,
        1,
        1
      ],
      "solid": "none",
      "facing": 0,
      "note": "공구 칸 곁 밧줄 더미",
      "level": 1
    },
    {
      "kind": "lumber_rack",
      "rect": [
        53,
        21,
        6,
        2
      ],
      "solid": "none",
      "facing": 0,
      "note": "안쪽 보관실 곁 제재 목재",
      "level": 1
    },
    {
      "kind": "part_crate",
      "rect": [
        53,
        18,
        1,
        1
      ],
      "solid": "none",
      "facing": 0,
      "note": "안쪽 보관실 곁 부품 상자",
      "level": 1
    },
    {
      "kind": "barrel",
      "rect": [
        54,
        18,
        1,
        1
      ],
      "solid": "none",
      "facing": 0,
      "note": "안쪽 보관실 곁 통",
      "level": 1
    },
    {
      "kind": "shelf",
      "rect": [
        71,
        11,
        3,
        1
      ],
      "solid": "low",
      "facing": 0,
      "note": "앞 작업 칸 곁 선반",
      "level": 0
    },
    {
      "kind": "desk",
      "rect": [
        74,
        11,
        2,
        1
      ],
      "solid": "low",
      "facing": 0,
      "note": "앞 작업 칸 곁 책상",
      "level": 0
    },
    {
      "kind": "file_cabinet",
      "rect": [
        77,
        11,
        2,
        1
      ],
      "solid": "low",
      "facing": 0,
      "note": "앞 작업 칸 곁 서류함",
      "level": 0
    },
    {
      "kind": "lumber_rack",
      "rect": [
        83,
        11,
        6,
        2
      ],
      "solid": "low",
      "facing": 0,
      "note": "안쪽 보관실 곁 제재 목재",
      "level": 0
    },
    {
      "kind": "pallet_stack",
      "rect": [
        89,
        11,
        2,
        2
      ],
      "solid": "low",
      "facing": 0,
      "note": "안쪽 보관실 곁 팰릿 더미",
      "level": 0
    },
    {
      "kind": "barrel",
      "rect": [
        91,
        11,
        1,
        1
      ],
      "solid": "low",
      "facing": 0,
      "note": "안쪽 보관실 곁 통",
      "level": 0
    },
    {
      "kind": "tool_cart",
      "rect": [
        71,
        11,
        2,
        1
      ],
      "solid": "none",
      "facing": 0,
      "note": "앞 작업 칸 곁 공구 수레",
      "level": 1
    },
    {
      "kind": "part_crate",
      "rect": [
        73,
        11,
        1,
        1
      ],
      "solid": "none",
      "facing": 0,
      "note": "앞 작업 칸 곁 부품 상자",
      "level": 1
    },
    {
      "kind": "coupler_set",
      "rect": [
        74,
        11,
        1,
        1
      ],
      "solid": "none",
      "facing": 0,
      "note": "앞 작업 칸 곁 연결기 한 벌",
      "level": 1
    },
    {
      "kind": "sack_pile",
      "rect": [
        83,
        11,
        2,
        2
      ],
      "solid": "none",
      "facing": 0,
      "note": "안쪽 보관실 곁 자루 더미",
      "level": 1
    },
    {
      "kind": "handcart",
      "rect": [
        85,
        11,
        2,
        1
      ],
      "solid": "none",
      "facing": 0,
      "note": "안쪽 보관실 곁 손수레",
      "level": 1
    },
    {
      "kind": "barrel",
      "rect": [
        87,
        11,
        1,
        1
      ],
      "solid": "none",
      "facing": 0,
      "note": "안쪽 보관실 곁 통",
      "level": 1
    },
    {
      "kind": "shelf",
      "rect": [
        100,
        13,
        3,
        1
      ],
      "solid": "low",
      "facing": 0,
      "note": "앞 작업 칸 곁 선반",
      "level": 0
    },
    {
      "kind": "crate_stack",
      "rect": [
        104,
        13,
        2,
        2
      ],
      "solid": "low",
      "facing": 0,
      "note": "앞 작업 칸 곁 나무 상자 더미",
      "level": 0
    },
    {
      "kind": "rope_coil",
      "rect": [
        106,
        13,
        1,
        1
      ],
      "solid": "low",
      "facing": 0,
      "note": "앞 작업 칸 곁 밧줄 더미",
      "level": 0
    },
    {
      "kind": "lumber_rack",
      "rect": [
        108,
        13,
        6,
        2
      ],
      "solid": "low",
      "facing": 0,
      "note": "안쪽 보관실 곁 제재 목재",
      "level": 0
    },
    {
      "kind": "part_crate",
      "rect": [
        114,
        13,
        1,
        1
      ],
      "solid": "low",
      "facing": 0,
      "note": "안쪽 보관실 곁 부품 상자",
      "level": 0
    },
    {
      "kind": "barrel",
      "rect": [
        114,
        14,
        1,
        1
      ],
      "solid": "low",
      "facing": 0,
      "note": "안쪽 보관실 곁 통",
      "level": 0
    },
    {
      "kind": "shelf",
      "rect": [
        9,
        11,
        3,
        1
      ],
      "solid": "low",
      "facing": 0,
      "note": "작업 칸 곁 선반",
      "level": 0
    },
    {
      "kind": "desk",
      "rect": [
        12,
        11,
        2,
        1
      ],
      "solid": "low",
      "facing": 0,
      "note": "작업 칸 곁 책상",
      "level": 0
    },
    {
      "kind": "file_cabinet",
      "rect": [
        14,
        11,
        2,
        1
      ],
      "solid": "low",
      "facing": 0,
      "note": "작업 칸 곁 서류함",
      "level": 0
    },
    {
      "kind": "lumber_rack",
      "rect": [
        117,
        25,
        6,
        2
      ],
      "solid": "low",
      "facing": 0,
      "note": "앞 작업 칸 곁 제재 목재",
      "level": 0
    },
    {
      "kind": "pallet_stack",
      "rect": [
        117,
        27,
        2,
        2
      ],
      "solid": "low",
      "facing": 0,
      "note": "앞 작업 칸 곁 팰릿 더미",
      "level": 0
    },
    {
      "kind": "barrel",
      "rect": [
        123,
        25,
        1,
        1
      ],
      "solid": "low",
      "facing": 0,
      "note": "앞 작업 칸 곁 통",
      "level": 0
    },
    {
      "kind": "tool_cart",
      "rect": [
        125,
        25,
        2,
        1
      ],
      "solid": "low",
      "facing": 0,
      "note": "안쪽 보관실 곁 공구 수레",
      "level": 0
    },
    {
      "kind": "part_crate",
      "rect": [
        127,
        25,
        1,
        1
      ],
      "solid": "low",
      "facing": 0,
      "note": "안쪽 보관실 곁 부품 상자",
      "level": 0
    },
    {
      "kind": "coupler_set",
      "rect": [
        128,
        25,
        1,
        1
      ],
      "solid": "low",
      "facing": 0,
      "note": "안쪽 보관실 곁 연결기 한 벌",
      "level": 0
    },
    {
      "kind": "sack_pile",
      "rect": [
        135,
        27,
        2,
        2
      ],
      "solid": "none",
      "facing": 0,
      "note": "목재 앞 저장고 곁 자루 더미",
      "level": -1
    },
    {
      "kind": "handcart",
      "rect": [
        137,
        27,
        2,
        1
      ],
      "solid": "none",
      "facing": 0,
      "note": "목재 앞 저장고 곁 손수레",
      "level": -1
    },
    {
      "kind": "barrel",
      "rect": [
        139,
        27,
        1,
        1
      ],
      "solid": "none",
      "facing": 0,
      "note": "목재 앞 저장고 곁 통",
      "level": -1
    },
    {
      "kind": "shelf",
      "rect": [
        147,
        27,
        3,
        1
      ],
      "solid": "none",
      "facing": 0,
      "note": "목재 안쪽 보관실 곁 선반",
      "level": -1
    },
    {
      "kind": "crate_stack",
      "rect": [
        150,
        27,
        2,
        2
      ],
      "solid": "none",
      "facing": 0,
      "note": "목재 안쪽 보관실 곁 나무 상자 더미",
      "level": -1
    },
    {
      "kind": "rope_coil",
      "rect": [
        152,
        27,
        1,
        1
      ],
      "solid": "none",
      "facing": 0,
      "note": "목재 안쪽 보관실 곁 밧줄 더미",
      "level": -1
    },
    {
      "kind": "lumber_rack",
      "rect": [
        135,
        27,
        6,
        2
      ],
      "solid": "low",
      "facing": 0,
      "note": "앞 작업 칸 곁 제재 목재",
      "level": 0
    },
    {
      "kind": "part_crate",
      "rect": [
        141,
        27,
        1,
        1
      ],
      "solid": "low",
      "facing": 0,
      "note": "앞 작업 칸 곁 부품 상자",
      "level": 0
    },
    {
      "kind": "barrel",
      "rect": [
        142,
        27,
        1,
        1
      ],
      "solid": "low",
      "facing": 0,
      "note": "앞 작업 칸 곁 통",
      "level": 0
    },
    {
      "kind": "shelf",
      "rect": [
        147,
        27,
        3,
        1
      ],
      "solid": "low",
      "facing": 0,
      "note": "안쪽 보관실 곁 선반",
      "level": 0
    },
    {
      "kind": "desk",
      "rect": [
        150,
        27,
        2,
        1
      ],
      "solid": "low",
      "facing": 0,
      "note": "안쪽 보관실 곁 책상",
      "level": 0
    },
    {
      "kind": "file_cabinet",
      "rect": [
        152,
        27,
        2,
        1
      ],
      "solid": "low",
      "facing": 0,
      "note": "안쪽 보관실 곁 서류함",
      "level": 0
    },
    {
      "kind": "lumber_rack",
      "rect": [
        135,
        27,
        6,
        2
      ],
      "solid": "none",
      "facing": 0,
      "note": "앞 작업 칸 곁 제재 목재",
      "level": 1
    },
    {
      "kind": "pallet_stack",
      "rect": [
        141,
        27,
        2,
        2
      ],
      "solid": "none",
      "facing": 0,
      "note": "앞 작업 칸 곁 팰릿 더미",
      "level": 1
    },
    {
      "kind": "barrel",
      "rect": [
        143,
        27,
        1,
        1
      ],
      "solid": "none",
      "facing": 0,
      "note": "앞 작업 칸 곁 통",
      "level": 1
    },
    {
      "kind": "tool_cart",
      "rect": [
        147,
        27,
        2,
        1
      ],
      "solid": "none",
      "facing": 0,
      "note": "안쪽 보관실 곁 공구 수레",
      "level": 1
    },
    {
      "kind": "part_crate",
      "rect": [
        149,
        27,
        1,
        1
      ],
      "solid": "none",
      "facing": 0,
      "note": "안쪽 보관실 곁 부품 상자",
      "level": 1
    },
    {
      "kind": "coupler_set",
      "rect": [
        150,
        27,
        1,
        1
      ],
      "solid": "none",
      "facing": 0,
      "note": "안쪽 보관실 곁 연결기 한 벌",
      "level": 1
    },
    {
      "kind": "sack_pile",
      "rect": [
        135,
        27,
        2,
        2
      ],
      "solid": "none",
      "facing": 0,
      "note": "앞 작업 칸 곁 자루 더미",
      "level": 2
    },
    {
      "kind": "handcart",
      "rect": [
        137,
        27,
        2,
        1
      ],
      "solid": "none",
      "facing": 0,
      "note": "앞 작업 칸 곁 손수레",
      "level": 2
    },
    {
      "kind": "barrel",
      "rect": [
        139,
        27,
        1,
        1
      ],
      "solid": "none",
      "facing": 0,
      "note": "앞 작업 칸 곁 통",
      "level": 2
    },
    {
      "kind": "shelf",
      "rect": [
        147,
        27,
        3,
        1
      ],
      "solid": "none",
      "facing": 0,
      "note": "안쪽 보관실 곁 선반",
      "level": 2
    },
    {
      "kind": "crate_stack",
      "rect": [
        150,
        27,
        2,
        2
      ],
      "solid": "none",
      "facing": 0,
      "note": "안쪽 보관실 곁 나무 상자 더미",
      "level": 2
    },
    {
      "kind": "rope_coil",
      "rect": [
        152,
        27,
        1,
        1
      ],
      "solid": "none",
      "facing": 0,
      "note": "안쪽 보관실 곁 밧줄 더미",
      "level": 2
    },
    {
      "kind": "lumber_rack",
      "rect": [
        117,
        39,
        6,
        2
      ],
      "solid": "low",
      "facing": 0,
      "note": "앞 작업 칸 곁 제재 목재",
      "level": 0
    },
    {
      "kind": "part_crate",
      "rect": [
        117,
        41,
        1,
        1
      ],
      "solid": "low",
      "facing": 0,
      "note": "앞 작업 칸 곁 부품 상자",
      "level": 0
    },
    {
      "kind": "barrel",
      "rect": [
        122,
        41,
        1,
        1
      ],
      "solid": "low",
      "facing": 0,
      "note": "앞 작업 칸 곁 통",
      "level": 0
    },
    {
      "kind": "shelf",
      "rect": [
        124,
        39,
        3,
        1
      ],
      "solid": "low",
      "facing": 0,
      "note": "안쪽 보관실 곁 선반",
      "level": 0
    },
    {
      "kind": "desk",
      "rect": [
        127,
        39,
        2,
        1
      ],
      "solid": "low",
      "facing": 0,
      "note": "안쪽 보관실 곁 책상",
      "level": 0
    },
    {
      "kind": "file_cabinet",
      "rect": [
        124,
        40,
        2,
        1
      ],
      "solid": "low",
      "facing": 0,
      "note": "안쪽 보관실 곁 서류함",
      "level": 0
    },
    {
      "kind": "lumber_rack",
      "rect": [
        135,
        10,
        6,
        2
      ],
      "solid": "none",
      "facing": 0,
      "note": "목재 앞 저장고 곁 제재 목재",
      "level": -1
    },
    {
      "kind": "part_crate",
      "rect": [
        135,
        7,
        1,
        1
      ],
      "solid": "none",
      "facing": 0,
      "note": "목재 앞 저장고 곁 부품 상자",
      "level": -1
    },
    {
      "kind": "barrel",
      "rect": [
        136,
        7,
        1,
        1
      ],
      "solid": "none",
      "facing": 0,
      "note": "목재 앞 저장고 곁 통",
      "level": -1
    },
    {
      "kind": "tool_cart",
      "rect": [
        137,
        7,
        2,
        1
      ],
      "solid": "none",
      "facing": 0,
      "note": "목재 앞 저장고 곁 공구 수레",
      "level": -1
    },
    {
      "kind": "lumber_rack",
      "rect": [
        144,
        10,
        6,
        2
      ],
      "solid": "none",
      "facing": 0,
      "note": "목재 안쪽 보관실 곁 제재 목재",
      "level": -1
    },
    {
      "kind": "part_crate",
      "rect": [
        144,
        7,
        1,
        1
      ],
      "solid": "none",
      "facing": 0,
      "note": "목재 안쪽 보관실 곁 부품 상자",
      "level": -1
    },
    {
      "kind": "barrel",
      "rect": [
        145,
        7,
        1,
        1
      ],
      "solid": "none",
      "facing": 0,
      "note": "목재 안쪽 보관실 곁 통",
      "level": -1
    },
    {
      "kind": "tool_cart",
      "rect": [
        146,
        7,
        2,
        1
      ],
      "solid": "none",
      "facing": 0,
      "note": "목재 안쪽 보관실 곁 공구 수레",
      "level": -1
    },
    {
      "kind": "lumber_rack",
      "rect": [
        135,
        4,
        6,
        2
      ],
      "solid": "low",
      "facing": 0,
      "note": "앞 작업 칸 곁 제재 목재",
      "level": 0
    },
    {
      "kind": "part_crate",
      "rect": [
        141,
        4,
        1,
        1
      ],
      "solid": "low",
      "facing": 0,
      "note": "앞 작업 칸 곁 부품 상자",
      "level": 0
    },
    {
      "kind": "barrel",
      "rect": [
        142,
        4,
        1,
        1
      ],
      "solid": "low",
      "facing": 0,
      "note": "앞 작업 칸 곁 통",
      "level": 0
    },
    {
      "kind": "lumber_rack",
      "rect": [
        145,
        4,
        6,
        2
      ],
      "solid": "low",
      "facing": 0,
      "note": "안쪽 보관실 곁 제재 목재",
      "level": 0
    },
    {
      "kind": "part_crate",
      "rect": [
        151,
        4,
        1,
        1
      ],
      "solid": "low",
      "facing": 0,
      "note": "안쪽 보관실 곁 부품 상자",
      "level": 0
    },
    {
      "kind": "barrel",
      "rect": [
        152,
        4,
        1,
        1
      ],
      "solid": "low",
      "facing": 0,
      "note": "안쪽 보관실 곁 통",
      "level": 0
    },
    {
      "kind": "log_pile",
      "rect": [
        18,
        18,
        4,
        2
      ],
      "solid": "low",
      "facing": 0,
      "note": "하역 준비 자리의 통나무 더미",
      "level": 0
    },
    {
      "kind": "lumber_rack",
      "rect": [
        22,
        18,
        6,
        2
      ],
      "solid": "low",
      "facing": 0,
      "note": "하역 준비 자리의 제재 목재",
      "level": 0
    },
    {
      "kind": "barrel",
      "rect": [
        18,
        20,
        1,
        1
      ],
      "solid": "low",
      "facing": 0,
      "note": "하역 준비 자리의 통",
      "level": 0
    },
    {
      "kind": "handcart",
      "rect": [
        19,
        20,
        2,
        1
      ],
      "solid": "low",
      "facing": 0,
      "note": "하역 준비 자리의 손수레",
      "level": 0
    },
    {
      "kind": "pallet_stack",
      "rect": [
        142,
        41,
        2,
        2
      ],
      "solid": "low",
      "facing": 0,
      "note": "하역 준비 자리의 팰릿 더미",
      "level": 0
    },
    {
      "kind": "tool_cart",
      "rect": [
        144,
        41,
        2,
        1
      ],
      "solid": "low",
      "facing": 0,
      "note": "하역 준비 자리의 공구 수레",
      "level": 0
    },
    {
      "kind": "barrel",
      "rect": [
        146,
        41,
        1,
        1
      ],
      "solid": "low",
      "facing": 0,
      "note": "하역 준비 자리의 통",
      "level": 0
    }
  ],
  "containers": [
    {
      "id": "north_box_1",
      "name": "제재소 본동 선별실 상자",
      "cell": [
        40,
        13
      ],
      "building": 17,
      "search": 6,
      "items": [
        "plank"
      ],
      "locked": false,
      "level": 0,
      "searched": false
    },
    {
      "id": "north_box_2",
      "name": "제재소 본동 원료 칸 상자",
      "cell": [
        51,
        13
      ],
      "building": 17,
      "search": 6,
      "items": [
        "plank"
      ],
      "locked": false,
      "level": 0,
      "searched": false
    },
    {
      "id": "north_box_3",
      "name": "제재소 본동 가공 칸 상자",
      "cell": [
        62,
        13
      ],
      "building": 17,
      "search": 6,
      "items": [
        "plank"
      ],
      "locked": false,
      "level": 0,
      "searched": false
    },
    {
      "id": "north_box_4",
      "name": "제재소 본동 계량실 상자",
      "cell": [
        40,
        22
      ],
      "building": 17,
      "search": 6,
      "items": [
        "plank"
      ],
      "locked": false,
      "level": 0,
      "searched": false
    },
    {
      "id": "north_box_5",
      "name": "제재소 본동 공구 칸 상자",
      "cell": [
        51,
        22
      ],
      "building": 17,
      "search": 6,
      "items": [
        "plank"
      ],
      "locked": false,
      "level": 0,
      "searched": false
    },
    {
      "id": "north_box_6",
      "name": "제재소 본동 안쪽 보관실 상자",
      "cell": [
        62,
        22
      ],
      "building": 17,
      "search": 6,
      "items": [
        "plank"
      ],
      "locked": false,
      "level": 0,
      "searched": false
    },
    {
      "id": "north_box_7",
      "name": "제재소 본동 선별실 상자",
      "cell": [
        40,
        13
      ],
      "building": 17,
      "search": 6,
      "items": [
        "plank"
      ],
      "locked": false,
      "level": 1,
      "searched": false
    },
    {
      "id": "north_box_8",
      "name": "제재소 본동 원료 칸 상자",
      "cell": [
        51,
        13
      ],
      "building": 17,
      "search": 6,
      "items": [
        "plank"
      ],
      "locked": false,
      "level": 1,
      "searched": false
    },
    {
      "id": "north_box_9",
      "name": "제재소 본동 가공 칸 상자",
      "cell": [
        62,
        13
      ],
      "building": 17,
      "search": 6,
      "items": [
        "plank"
      ],
      "locked": false,
      "level": 1,
      "searched": false
    },
    {
      "id": "north_box_10",
      "name": "제재소 본동 계량실 상자",
      "cell": [
        40,
        22
      ],
      "building": 17,
      "search": 6,
      "items": [
        "plank"
      ],
      "locked": false,
      "level": 1,
      "searched": false
    },
    {
      "id": "north_box_11",
      "name": "제재소 본동 공구 칸 상자",
      "cell": [
        51,
        22
      ],
      "building": 17,
      "search": 6,
      "items": [
        "plank"
      ],
      "locked": false,
      "level": 1,
      "searched": false
    },
    {
      "id": "north_box_12",
      "name": "제재소 본동 안쪽 보관실 상자",
      "cell": [
        62,
        22
      ],
      "building": 17,
      "search": 6,
      "items": [
        "plank"
      ],
      "locked": false,
      "level": 1,
      "searched": false
    },
    {
      "id": "north_box_13",
      "name": "건조 창고 가 앞 작업 칸 상자",
      "cell": [
        81,
        22
      ],
      "building": 18,
      "search": 6,
      "items": [
        "plank"
      ],
      "locked": false,
      "level": 0,
      "searched": false
    },
    {
      "id": "north_box_14",
      "name": "건조 창고 가 안쪽 보관실 상자",
      "cell": [
        92,
        22
      ],
      "building": 18,
      "search": 6,
      "items": [
        "plank"
      ],
      "locked": false,
      "level": 0,
      "searched": false
    },
    {
      "id": "north_box_15",
      "name": "건조 창고 가 앞 작업 칸 상자",
      "cell": [
        81,
        22
      ],
      "building": 18,
      "search": 6,
      "items": [
        "plank"
      ],
      "locked": false,
      "level": 1,
      "searched": false
    },
    {
      "id": "north_box_16",
      "name": "건조 창고 가 안쪽 보관실 상자",
      "cell": [
        92,
        22
      ],
      "building": 18,
      "search": 6,
      "items": [
        "plank"
      ],
      "locked": false,
      "level": 1,
      "searched": false
    },
    {
      "id": "north_box_17",
      "name": "장작 창고 앞 작업 칸 상자",
      "cell": [
        106,
        22
      ],
      "building": 19,
      "search": 6,
      "items": [
        "plank"
      ],
      "locked": false,
      "level": 0,
      "searched": false
    },
    {
      "id": "north_box_18",
      "name": "장작 창고 안쪽 보관실 상자",
      "cell": [
        114,
        22
      ],
      "building": 19,
      "search": 6,
      "items": [
        "plank"
      ],
      "locked": false,
      "level": 0,
      "searched": false
    },
    {
      "id": "north_box_19",
      "name": "목재 사무소 작업 칸 상자",
      "cell": [
        16,
        16
      ],
      "building": 20,
      "search": 6,
      "items": [
        "plank"
      ],
      "locked": false,
      "level": 0,
      "searched": false
    },
    {
      "id": "north_box_20",
      "name": "날 수선 헛간 앞 작업 칸 상자",
      "cell": [
        123,
        32
      ],
      "building": 21,
      "search": 6,
      "items": [
        "plank"
      ],
      "locked": false,
      "level": 0,
      "searched": false
    },
    {
      "id": "north_box_21",
      "name": "날 수선 헛간 안쪽 보관실 상자",
      "cell": [
        130,
        32
      ],
      "building": 21,
      "search": 6,
      "items": [
        "plank"
      ],
      "locked": false,
      "level": 0,
      "searched": false
    },
    {
      "id": "north_box_22",
      "name": "목재 선별 창고 목재 앞 저장고 상자",
      "cell": [
        145,
        38
      ],
      "building": 22,
      "search": 6,
      "items": [
        "plank"
      ],
      "locked": false,
      "level": -1,
      "searched": false
    },
    {
      "id": "north_box_23",
      "name": "목재 선별 창고 목재 안쪽 보관실 상자",
      "cell": [
        156,
        38
      ],
      "building": 22,
      "search": 6,
      "items": [
        "plank"
      ],
      "locked": false,
      "level": -1,
      "searched": false
    },
    {
      "id": "north_box_24",
      "name": "목재 선별 창고 앞 작업 칸 상자",
      "cell": [
        145,
        38
      ],
      "building": 22,
      "search": 6,
      "items": [
        "plank"
      ],
      "locked": false,
      "level": 0,
      "searched": false
    },
    {
      "id": "north_box_25",
      "name": "목재 선별 창고 안쪽 보관실 상자",
      "cell": [
        156,
        38
      ],
      "building": 22,
      "search": 6,
      "items": [
        "plank"
      ],
      "locked": false,
      "level": 0,
      "searched": false
    },
    {
      "id": "north_box_26",
      "name": "목재 선별 창고 앞 작업 칸 상자",
      "cell": [
        145,
        38
      ],
      "building": 22,
      "search": 6,
      "items": [
        "plank"
      ],
      "locked": false,
      "level": 1,
      "searched": false
    },
    {
      "id": "north_box_27",
      "name": "목재 선별 창고 안쪽 보관실 상자",
      "cell": [
        156,
        38
      ],
      "building": 22,
      "search": 6,
      "items": [
        "plank"
      ],
      "locked": false,
      "level": 1,
      "searched": false
    },
    {
      "id": "north_box_28",
      "name": "목재 선별 창고 앞 작업 칸 상자",
      "cell": [
        145,
        38
      ],
      "building": 22,
      "search": 6,
      "items": [
        "plank"
      ],
      "locked": false,
      "level": 2,
      "searched": false
    },
    {
      "id": "north_box_29",
      "name": "목재 선별 창고 안쪽 보관실 상자",
      "cell": [
        156,
        38
      ],
      "building": 22,
      "search": 6,
      "items": [
        "plank"
      ],
      "locked": false,
      "level": 2,
      "searched": false
    },
    {
      "id": "north_box_30",
      "name": "동력실 앞 작업 칸 상자",
      "cell": [
        122,
        44
      ],
      "building": 23,
      "search": 6,
      "items": [
        "plank"
      ],
      "locked": false,
      "level": 0,
      "searched": false
    },
    {
      "id": "north_box_31",
      "name": "동력실 안쪽 보관실 상자",
      "cell": [
        128,
        44
      ],
      "building": 23,
      "search": 6,
      "items": [
        "plank"
      ],
      "locked": false,
      "level": 0,
      "searched": false
    },
    {
      "id": "north_box_32",
      "name": "건조 헛간 목재 앞 저장고 상자",
      "cell": [
        142,
        11
      ],
      "building": 24,
      "search": 6,
      "items": [
        "plank"
      ],
      "locked": false,
      "level": -1,
      "searched": false
    },
    {
      "id": "north_box_33",
      "name": "건조 헛간 목재 안쪽 보관실 상자",
      "cell": [
        152,
        11
      ],
      "building": 24,
      "search": 6,
      "items": [
        "plank"
      ],
      "locked": false,
      "level": -1,
      "searched": false
    },
    {
      "id": "north_box_34",
      "name": "건조 헛간 앞 작업 칸 상자",
      "cell": [
        143,
        11
      ],
      "building": 24,
      "search": 6,
      "items": [
        "plank"
      ],
      "locked": false,
      "level": 0,
      "searched": false
    },
    {
      "id": "north_box_35",
      "name": "건조 헛간 안쪽 보관실 상자",
      "cell": [
        152,
        11
      ],
      "building": 24,
      "search": 6,
      "items": [
        "plank"
      ],
      "locked": false,
      "level": 0,
      "searched": false
    },
    {
      "id": "north_loading_box",
      "name": "위쪽 문 곁 운반 상자",
      "cell": [
        55,
        40
      ],
      "building": -1,
      "search": 4,
      "items": [
        "plank"
      ],
      "locked": false,
      "level": 0,
      "searched": false
    }
  ],
  "wagons": [
    {
      "id": "north_wagon_0",
      "name": "문 열린 평판 화차",
      "rect": [
        122,
        17,
        12,
        3
      ],
      "coal": 0,
      "work": [
        123,
        20
      ]
    },
    {
      "id": "north_wagon_1",
      "name": "문 열린 평판 화차",
      "rect": [
        139,
        17,
        12,
        3
      ],
      "coal": 0,
      "work": [
        140,
        20
      ]
    }
  ],
  "entries": [
    [
      "서쪽 북로 끝",
      [
        [
          0,
          4
        ],
        [
          0,
          5
        ],
        [
          0,
          6
        ],
        [
          0,
          7
        ]
      ],
      0.6
    ],
    [
      "북쪽 건조길",
      [
        [
          76,
          0
        ],
        [
          77,
          0
        ],
        [
          78,
          0
        ],
        [
          79,
          0
        ]
      ],
      0.6
    ],
    [
      "동쪽 인입선 끝",
      [
        [
          159,
          17
        ],
        [
          159,
          18
        ],
        [
          159,
          19
        ]
      ],
      0.6
    ]
  ],
  "holes": [
    [
      "manhole_02",
      [
        100,
        5
      ],
      "북로 맨홀"
    ]
  ],
  "barricades": [
    [
      65,
      22
    ],
    [
      68,
      22
    ],
    [
      95,
      22
    ],
    [
      97,
      22
    ],
    [
      116,
      35
    ],
    [
      116,
      36
    ]
  ],
  "deep": [
    [
      "K",
      "건조 헛간"
    ]
  ],
  "dead": [],
  "salvage": [],
  "work_site": {},
  "cross": [
    32,
    64
  ],
  "court": [
    154,
    6,
    5,
    5
  ]
}


## 무전 문장에 쓰는 들어오는 길의 이름, 길마다의 비중, 첫 물결이 오는 길.
const ENTRY_NAMES: Dictionary = {"west_road": "서쪽 길", "south_lane": "남쪽 샛길", "east_track": "동쪽 선로", "farm_lane": "농장 샛길", "manhole_01": "첫째 맨홀", "culvert_01": "암거", "서쪽 북로 끝": "서쪽 북로 끝", "북쪽 건조길": "북쪽 건조길", "동쪽 인입선 끝": "동쪽 인입선 끝", "manhole_02": "둘째 맨홀"}
const ENTRY_WEIGHTS: Dictionary = {"west_road": 1.0, "south_lane": 0.5, "east_track": 1.0, "farm_lane": 0.5, "manhole_01": 0.3, "culvert_01": 1.0, "서쪽 북로 끝": 1.0, "북쪽 건조길": 1.0, "동쪽 인입선 끝": 1.0, "manhole_02": 0.3}
const FIRST_ENTRY: String = "west_road"


static func build() -> Dictionary:
	var data: Dictionary = _build_plain()
	data["entry_names"] = ENTRY_NAMES.duplicate()
	data["entry_weights"] = ENTRY_WEIGHTS.duplicate()
	data["first_entry"] = FIRST_ENTRY
	return data
