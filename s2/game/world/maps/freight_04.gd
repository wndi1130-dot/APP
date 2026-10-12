# 이 지도가 다른 판단을 만드는 것: 강 쪽은 무리도 퇴로도 없고, 돌아올 길이 둑길 하나로 좁아진다.
# 위쪽의 판단: 가볍고 값진 약 상자를 얻는 대신, 둑 창고 깊은 곳은 둑길 하나로만 돌아올 수 있어 한 번 들어가면 나오는 길이 좁다.
extends RefCounted

const MapShift = preload("res://game/world/map_shift.gd")
const FieldGrid = preload("res://game/world/field_grid.gd")
const S = FieldGrid.Solid
const F = FieldGrid.Floor
const PLACE_ID: String = "freight_04"
const WIDTH: int = 175
const SOUTH_HEIGHT: int = 100
const HEIGHT: int = SOUTH_HEIGHT + 45

# 좌표는 한 칸 단위다. 각 층의 방·문·가구를 독립적으로 기록한다.
const PLAN: Dictionary = {
  "id": "freight_04",
  "size": [175,100],
  "judgment": "강 쪽은 무리도 퇴로도 없고, 돌아올 길이 둑길 하나로 좁아진다.",
  "resource": "food",
  "zones": [
    ["A","승강장 마당",[0,0,175,100]],
    ["B","서쪽 가게",[0,11,97,35]],
    ["C","마을 뒷길",[0,46,97,27]],
    ["D","둑길",[97,29,10,71]],
    ["E","북쪽 강변 창고",[107,10,38,44]],
    ["F","강변 큰 창고",[107,54,38,46]],
    ["G","서남 곡물 구획",[0,73,97,27]],
    ["H","철교와 강",[145,0,30,100]]
  ],
  "floors": [
    [0,40,24,56,7,7],
    [0,20,58,15,15,7],
    [0,106,15,6,14,7],
    [0,34,10,6,42,1],
    [0,34,46,70,6,1],
    [0,98,29,6,71,1],
    [0,36,52,4,48,1],
    [0,0,52,104,4,1],
    [0,140,10,5,90,1],
    [0,98,29,47,4,1],
    [0,98,51,47,4,1],
    [0,98,81,47,4,1],
    [0,30,72,68,4,1]
  ],
  "buildings": [
    {"id":0,"name":"강변 창고 가","rect":[109,55,31,26],"warm":false,"window_broken":false},
    {"id":1,"name":"강변 창고 나","rect":[112,14,28,15],"warm":false,"window_broken":false},
    {"id":2,"name":"강변 창고 다","rect":[107,33,25,18],"warm":false,"window_broken":false},
    {"id":3,"name":"강변 창고 라","rect":[114,85,26,14],"warm":false,"window_broken":false},
    {"id":4,"name":"역사","rect":[10,11,24,14],"warm":false,"window_broken":false},
    {"id":5,"name":"화물 사무소","rect":[59,12,14,10],"warm":false,"window_broken":false},
    {"id":6,"name":"소화물 창고","rect":[79,12,18,12],"warm":false,"window_broken":false},
    {"id":7,"name":"신호 취급소","rect":[102,8,8,7],"warm":false,"window_broken":false},
    {"id":8,"name":"식료품점","rect":[40,12,14,10],"warm":false,"window_broken":false},
    {"id":9,"name":"빵집","rect":[10,33,12,9],"warm":false,"window_broken":false},
    {"id":10,"name":"잡화점","rect":[47,32,12,10],"warm":false,"window_broken":false},
    {"id":11,"name":"철도원 주택 가","rect":[67,32,12,10],"warm":false,"window_broken":false},
    {"id":12,"name":"철도원 주택 나","rect":[8,58,12,10],"warm":false,"window_broken":false},
    {"id":13,"name":"철도원 주택 다","rect":[47,60,11,10],"warm":false,"window_broken":false},
    {"id":14,"name":"모래 창고","rect":[82,60,10,8],"warm":false,"window_broken":false},
    {"id":15,"name":"곡물 건조 창고","rect":[8,75,22,14],"warm":false,"window_broken":false},
    {"id":16,"name":"공구 창고","rect":[57,79,12,9],"warm":false,"window_broken":false},
    {"id":17,"name":"계량소","rect":[82,88,8,6],"warm":false,"window_broken":false}
  ],
  "shells": [
    [0,0,109,55,31,26],
    [0,1,109,55,31,26],
    [0,2,109,55,31,26],
    [0,-1,109,55,31,26],
    [1,0,112,14,28,15],
    [1,1,112,14,28,15],
    [2,0,107,33,25,18],
    [2,1,107,33,25,18],
    [3,0,114,85,26,14],
    [3,1,114,85,26,14],
    [4,0,10,11,24,14],
    [4,1,10,11,24,14],
    [5,0,59,12,14,10],
    [6,0,79,12,18,12],
    [7,0,102,8,8,7],
    [7,1,102,8,8,7],
    [8,0,40,12,14,10],
    [9,0,10,33,12,9],
    [10,0,47,32,12,10],
    [11,0,67,32,12,10],
    [11,1,67,32,12,10],
    [12,0,8,58,12,10],
    [12,1,8,58,12,10],
    [13,0,47,60,11,10],
    [14,0,82,60,10,8],
    [15,0,8,75,22,14],
    [16,0,57,79,12,9],
    [17,0,82,88,8,6]
  ],
  "walls": [
    [0,110,66,29,1],
    [0,110,69,29,1],
    [0,115,56,1,10],
    [0,121,56,1,10],
    [0,127,56,1,10],
    [0,133,56,1,10],
    [0,115,70,1,10],
    [0,121,70,1,10],
    [0,127,70,1,10],
    [0,133,70,1,10],
    [1,110,66,29,1],
    [1,110,69,29,1],
    [1,115,56,1,10],
    [1,121,56,1,10],
    [1,127,56,1,10],
    [1,133,56,1,10],
    [1,115,70,1,10],
    [1,121,70,1,10],
    [1,127,70,1,10],
    [1,133,70,1,10],
    [2,110,66,29,1],
    [2,110,69,29,1],
    [2,115,56,1,10],
    [2,121,56,1,10],
    [2,127,56,1,10],
    [2,133,56,1,10],
    [2,115,70,1,10],
    [2,121,70,1,10],
    [2,127,70,1,10],
    [2,133,70,1,10],
    [-1,110,66,29,1],
    [-1,110,69,29,1],
    [-1,115,56,1,10],
    [-1,121,56,1,10],
    [-1,127,56,1,10],
    [-1,133,56,1,10],
    [-1,115,70,1,10],
    [-1,121,70,1,10],
    [-1,127,70,1,10],
    [-1,133,70,1,10],
    [0,113,19,26,1],
    [0,113,22,26,1],
    [0,125,15,1,4],
    [0,125,23,1,5],
    [1,113,19,26,1],
    [1,113,22,26,1],
    [1,125,15,1,4],
    [1,125,23,1,5],
    [0,108,40,23,1],
    [0,108,43,23,1],
    [0,119,34,1,6],
    [0,119,44,1,6],
    [1,108,40,23,1],
    [1,108,43,23,1],
    [1,119,34,1,6],
    [1,119,44,1,6],
    [0,127,86,1,12],
    [1,127,86,1,12],
    [0,22,12,1,12],
    [1,22,12,1,12],
    [0,66,13,1,8],
    [0,88,13,1,10],
    [0,41,17,12,1],
    [0,11,37,10,1],
    [0,48,37,10,1],
    [0,73,33,1,8],
    [1,73,33,1,8],
    [0,14,59,1,8],
    [1,14,59,1,8],
    [0,52,61,1,8],
    [0,19,76,1,12],
    [0,63,80,1,7]
  ],
  "openings": [],
  "doors": [
    [0,112,66,0,"closed",0,1],
    [0,118,66,0,"closed",0,1],
    [0,124,66,0,"closed",0,1],
    [0,130,66,0,"closed",0,1],
    [0,136,66,0,"closed",0,1],
    [0,112,69,0,"closed",0,-1],
    [0,118,69,0,"closed",0,-1],
    [0,124,69,0,"closed",0,-1],
    [0,130,69,0,"closed",0,-1],
    [0,136,69,0,"closed",0,-1],
    [1,112,66,0,"closed",0,1],
    [1,118,66,0,"closed",0,1],
    [1,124,66,0,"closed",0,1],
    [1,130,66,0,"closed",0,1],
    [1,136,66,0,"closed",0,1],
    [1,112,69,0,"closed",0,-1],
    [1,118,69,0,"closed",0,-1],
    [1,124,69,0,"closed",0,-1],
    [1,130,69,0,"closed",0,-1],
    [1,136,69,0,"closed",0,-1],
    [2,112,66,0,"closed",0,1],
    [2,118,66,0,"closed",0,1],
    [2,124,66,0,"closed",0,1],
    [2,130,66,0,"closed",0,1],
    [2,136,66,0,"closed",0,1],
    [2,112,69,0,"closed",0,-1],
    [2,118,69,0,"closed",0,-1],
    [2,124,69,0,"closed",0,-1],
    [2,130,69,0,"closed",0,-1],
    [2,136,69,0,"closed",0,-1],
    [-1,112,66,0,"closed",0,1],
    [-1,118,66,0,"closed",0,1],
    [-1,124,66,0,"closed",0,1],
    [-1,130,66,0,"closed",0,1],
    [-1,136,66,0,"closed",0,1],
    [-1,112,69,0,"closed",0,-1],
    [-1,118,69,0,"closed",0,-1],
    [-1,124,69,0,"closed",0,-1],
    [-1,130,69,0,"closed",0,-1],
    [-1,136,69,0,"closed",0,-1],
    [0,109,67,0,"closed",-1,0],
    [0,139,67,0,"closed",1,0],
    [0,118,19,1,"closed",0,1],
    [0,132,19,1,"closed",0,1],
    [0,118,22,1,"closed",0,-1],
    [0,132,22,1,"closed",0,-1],
    [1,118,19,1,"closed",0,1],
    [1,132,19,1,"closed",0,1],
    [1,118,22,1,"closed",0,-1],
    [1,132,22,1,"closed",0,-1],
    [0,112,20,1,"closed",-1,0],
    [0,139,20,1,"closed",1,0],
    [0,113,40,2,"closed",0,1],
    [0,125,40,2,"closed",0,1],
    [0,113,43,2,"closed",0,-1],
    [0,125,43,2,"closed",0,-1],
    [1,113,40,2,"closed",0,1],
    [1,125,40,2,"closed",0,1],
    [1,113,43,2,"closed",0,-1],
    [1,125,43,2,"closed",0,-1],
    [0,107,41,2,"closed",-1,0],
    [0,131,41,2,"closed",1,0],
    [0,127,92,3,"closed",1,0],
    [1,127,92,3,"closed",1,0],
    [0,114,92,3,"closed",-1,0],
    [0,139,92,3,"closed",1,0],
    [0,22,18,4,"closed",1,0],
    [1,22,18,4,"closed",1,0],
    [0,18,11,4,"closed",0,-1],
    [0,31,24,4,"closed",0,1],
    [0,66,17,5,"closed",1,0],
    [0,63,12,5,"closed",0,-1],
    [0,70,21,5,"closed",0,1],
    [0,88,18,6,"closed",1,0],
    [0,85,12,6,"closed",0,-1],
    [0,94,23,6,"closed",0,1],
    [0,104,8,7,"closed",0,-1],
    [0,107,14,7,"closed",0,1],
    [0,51,17,8,"closed",0,1],
    [0,44,12,8,"closed",0,-1],
    [0,51,21,8,"closed",0,1],
    [0,19,37,9,"closed",0,1],
    [0,14,33,9,"closed",0,-1],
    [0,19,41,9,"closed",0,1],
    [0,56,37,10,"closed",0,1],
    [0,51,32,10,"closed",0,-1],
    [0,56,41,10,"closed",0,1],
    [0,73,37,11,"closed",1,0],
    [1,73,37,11,"closed",1,0],
    [0,71,32,11,"closed",0,-1],
    [0,76,41,11,"closed",0,1],
    [0,14,63,12,"closed",1,0],
    [1,14,63,12,"closed",1,0],
    [0,12,58,12,"closed",0,-1],
    [0,17,67,12,"closed",0,1],
    [0,52,65,13,"closed",1,0],
    [0,50,60,13,"closed",0,-1],
    [0,55,69,13,"closed",0,1],
    [0,85,60,14,"closed",0,-1],
    [0,89,67,14,"closed",0,1],
    [0,19,82,15,"closed",1,0],
    [0,15,75,15,"closed",0,-1],
    [0,29,82,15,"closed",1,0],
    [0,63,83,16,"closed",1,0],
    [0,61,79,16,"closed",0,-1],
    [0,66,87,16,"closed",0,1],
    [0,84,88,17,"closed",0,-1],
    [0,87,93,17,"closed",0,1]
  ],
  "windows": [
    [0,112,55,0],
    [0,119,55,0],
    [0,126,55,0],
    [0,133,55,0],
    [0,139,58,0],
    [0,139,64,0],
    [0,139,70,0],
    [0,139,76,0],
    [1,112,55,0],
    [1,119,55,0],
    [1,126,55,0],
    [1,133,55,0],
    [1,139,58,0],
    [1,139,64,0],
    [1,139,70,0],
    [1,139,76,0],
    [2,112,55,0],
    [2,119,55,0],
    [2,126,55,0],
    [2,133,55,0],
    [2,139,58,0],
    [2,139,64,0],
    [2,139,70,0],
    [2,139,76,0],
    [0,115,14,1],
    [0,122,14,1],
    [0,129,14,1],
    [0,136,14,1],
    [0,139,17,1],
    [0,139,23,1],
    [1,115,14,1],
    [1,122,14,1],
    [1,129,14,1],
    [1,136,14,1],
    [1,139,17,1],
    [1,139,23,1],
    [0,110,33,2],
    [0,117,33,2],
    [0,124,33,2],
    [0,131,36,2],
    [0,131,42,2],
    [0,131,48,2],
    [1,110,33,2],
    [1,117,33,2],
    [1,124,33,2],
    [1,131,36,2],
    [1,131,42,2],
    [1,131,48,2],
    [0,117,85,3],
    [0,124,85,3],
    [0,131,85,3],
    [0,139,88,3],
    [0,139,94,3],
    [1,117,85,3],
    [1,124,85,3],
    [1,131,85,3],
    [1,139,88,3],
    [1,139,94,3],
    [0,13,11,4],
    [0,20,11,4],
    [0,27,11,4],
    [0,33,14,4],
    [0,33,20,4],
    [1,13,11,4],
    [1,20,11,4],
    [1,27,11,4],
    [1,33,14,4],
    [1,33,20,4],
    [0,62,12,5],
    [0,69,12,5],
    [0,72,15,5],
    [0,82,12,6],
    [0,89,12,6],
    [0,96,15,6],
    [0,96,21,6],
    [0,105,8,7],
    [0,109,11,7],
    [1,105,8,7],
    [1,109,11,7],
    [0,43,12,8],
    [0,50,12,8],
    [0,53,15,8],
    [0,13,33,9],
    [0,21,36,9],
    [0,50,32,10],
    [0,58,35,10],
    [0,70,32,11],
    [0,78,35,11],
    [1,70,32,11],
    [1,78,35,11],
    [0,11,58,12],
    [0,19,61,12],
    [1,11,58,12],
    [1,19,61,12],
    [0,50,60,13],
    [0,57,63,13],
    [0,85,60,14],
    [0,91,63,14],
    [0,11,75,15],
    [0,18,75,15],
    [0,25,75,15],
    [0,29,78,15],
    [0,29,84,15],
    [0,60,79,16],
    [0,68,82,16],
    [0,85,88,17],
    [0,89,91,17]
  ],
  "rooms": [
    {"building":0,"level":0,"rect":[110,56,5,10],"name":"사무실"},
    {"building":0,"level":0,"rect":[116,56,5,10],"name":"선별실"},
    {"building":0,"level":0,"rect":[122,56,5,10],"name":"선반 칸"},
    {"building":0,"level":0,"rect":[128,56,5,10],"name":"계량실"},
    {"building":0,"level":0,"rect":[134,56,5,10],"name":"안쪽 창고"},
    {"building":0,"level":0,"rect":[110,70,5,10],"name":"사무실"},
    {"building":0,"level":0,"rect":[116,70,5,10],"name":"선별실"},
    {"building":0,"level":0,"rect":[122,70,5,10],"name":"선반 칸"},
    {"building":0,"level":0,"rect":[128,70,5,10],"name":"계량실"},
    {"building":0,"level":0,"rect":[134,70,5,10],"name":"안쪽 창고"},
    {"building":0,"level":1,"rect":[110,56,5,10],"name":"사무실"},
    {"building":0,"level":1,"rect":[116,56,5,10],"name":"선별실"},
    {"building":0,"level":1,"rect":[122,56,5,10],"name":"선반 칸"},
    {"building":0,"level":1,"rect":[128,56,5,10],"name":"계량실"},
    {"building":0,"level":1,"rect":[134,56,5,10],"name":"안쪽 창고"},
    {"building":0,"level":1,"rect":[110,70,5,10],"name":"사무실"},
    {"building":0,"level":1,"rect":[116,70,5,10],"name":"선별실"},
    {"building":0,"level":1,"rect":[122,70,5,10],"name":"선반 칸"},
    {"building":0,"level":1,"rect":[128,70,5,10],"name":"계량실"},
    {"building":0,"level":1,"rect":[134,70,5,10],"name":"안쪽 창고"},
    {"building":0,"level":2,"rect":[110,56,5,10],"name":"사무실"},
    {"building":0,"level":2,"rect":[116,56,5,10],"name":"선별실"},
    {"building":0,"level":2,"rect":[122,56,5,10],"name":"선반 칸"},
    {"building":0,"level":2,"rect":[128,56,5,10],"name":"계량실"},
    {"building":0,"level":2,"rect":[134,56,5,10],"name":"안쪽 창고"},
    {"building":0,"level":2,"rect":[110,70,5,10],"name":"사무실"},
    {"building":0,"level":2,"rect":[116,70,5,10],"name":"선별실"},
    {"building":0,"level":2,"rect":[122,70,5,10],"name":"선반 칸"},
    {"building":0,"level":2,"rect":[128,70,5,10],"name":"계량실"},
    {"building":0,"level":2,"rect":[134,70,5,10],"name":"안쪽 창고"},
    {"building":0,"level":-1,"rect":[110,56,5,10],"name":"저장고"},
    {"building":0,"level":-1,"rect":[116,56,5,10],"name":"냉기 칸"},
    {"building":0,"level":-1,"rect":[122,56,5,10],"name":"안쪽 보관실"},
    {"building":0,"level":-1,"rect":[128,56,5,10],"name":"저장고"},
    {"building":0,"level":-1,"rect":[134,56,5,10],"name":"냉기 칸"},
    {"building":0,"level":-1,"rect":[110,70,5,10],"name":"저장고"},
    {"building":0,"level":-1,"rect":[116,70,5,10],"name":"냉기 칸"},
    {"building":0,"level":-1,"rect":[122,70,5,10],"name":"안쪽 보관실"},
    {"building":0,"level":-1,"rect":[128,70,5,10],"name":"저장고"},
    {"building":0,"level":-1,"rect":[134,70,5,10],"name":"냉기 칸"},
    {"building":1,"level":0,"rect":[113,15,12,4],"name":"사무실"},
    {"building":1,"level":0,"rect":[126,15,13,4],"name":"선별실"},
    {"building":1,"level":0,"rect":[113,23,12,5],"name":"사무실"},
    {"building":1,"level":0,"rect":[126,23,13,5],"name":"선별실"},
    {"building":1,"level":1,"rect":[113,15,12,4],"name":"사무실"},
    {"building":1,"level":1,"rect":[126,15,13,4],"name":"선별실"},
    {"building":1,"level":1,"rect":[113,23,12,5],"name":"사무실"},
    {"building":1,"level":1,"rect":[126,23,13,5],"name":"선별실"},
    {"building":2,"level":0,"rect":[108,34,11,6],"name":"사무실"},
    {"building":2,"level":0,"rect":[120,34,11,6],"name":"선별실"},
    {"building":2,"level":0,"rect":[108,44,11,6],"name":"사무실"},
    {"building":2,"level":0,"rect":[120,44,11,6],"name":"선별실"},
    {"building":2,"level":1,"rect":[108,34,11,6],"name":"사무실"},
    {"building":2,"level":1,"rect":[120,34,11,6],"name":"선별실"},
    {"building":2,"level":1,"rect":[108,44,11,6],"name":"사무실"},
    {"building":2,"level":1,"rect":[120,44,11,6],"name":"선별실"},
    {"building":3,"level":0,"rect":[115,86,12,12],"name":"앞방"},
    {"building":3,"level":0,"rect":[128,86,11,12],"name":"안쪽 방"},
    {"building":3,"level":1,"rect":[115,86,12,12],"name":"앞방"},
    {"building":3,"level":1,"rect":[128,86,11,12],"name":"안쪽 방"},
    {"building":4,"level":0,"rect":[11,12,11,12],"name":"앞방"},
    {"building":4,"level":0,"rect":[23,12,10,12],"name":"안쪽 방"},
    {"building":4,"level":1,"rect":[11,12,11,12],"name":"앞방"},
    {"building":4,"level":1,"rect":[23,12,10,12],"name":"안쪽 방"},
    {"building":5,"level":0,"rect":[60,13,6,8],"name":"앞방"},
    {"building":5,"level":0,"rect":[67,13,5,8],"name":"안쪽 방"},
    {"building":6,"level":0,"rect":[80,13,8,10],"name":"앞방"},
    {"building":6,"level":0,"rect":[89,13,7,10],"name":"안쪽 방"},
    {"building":7,"level":0,"rect":[103,9,6,5],"name":"작업실"},
    {"building":7,"level":1,"rect":[103,9,6,5],"name":"작업실"},
    {"building":8,"level":0,"rect":[41,13,12,4],"name":"매장"},
    {"building":8,"level":0,"rect":[41,18,12,3],"name":"뒤 창고"},
    {"building":9,"level":0,"rect":[11,34,10,3],"name":"매장"},
    {"building":9,"level":0,"rect":[11,38,10,3],"name":"뒤 창고"},
    {"building":10,"level":0,"rect":[48,33,10,4],"name":"매장"},
    {"building":10,"level":0,"rect":[48,38,10,3],"name":"뒤 창고"},
    {"building":11,"level":0,"rect":[68,33,5,8],"name":"앞방"},
    {"building":11,"level":0,"rect":[74,33,4,8],"name":"안쪽 방"},
    {"building":11,"level":1,"rect":[68,33,5,8],"name":"앞방"},
    {"building":11,"level":1,"rect":[74,33,4,8],"name":"안쪽 방"},
    {"building":12,"level":0,"rect":[9,59,5,8],"name":"앞방"},
    {"building":12,"level":0,"rect":[15,59,4,8],"name":"안쪽 방"},
    {"building":12,"level":1,"rect":[9,59,5,8],"name":"앞방"},
    {"building":12,"level":1,"rect":[15,59,4,8],"name":"안쪽 방"},
    {"building":13,"level":0,"rect":[48,61,4,8],"name":"앞방"},
    {"building":13,"level":0,"rect":[53,61,4,8],"name":"안쪽 방"},
    {"building":14,"level":0,"rect":[83,61,8,6],"name":"작업실"},
    {"building":15,"level":0,"rect":[9,76,10,12],"name":"앞방"},
    {"building":15,"level":0,"rect":[20,76,9,12],"name":"안쪽 방"},
    {"building":16,"level":0,"rect":[58,80,5,7],"name":"앞방"},
    {"building":16,"level":0,"rect":[64,80,4,7],"name":"안쪽 방"},
    {"building":17,"level":0,"rect":[83,89,6,4],"name":"작업실"}
  ],
  "stairs": [
    {"cell":[111,67],"low":0,"high":1,"ladder":false},
    {"cell":[111,67],"low":1,"high":2,"ladder":false},
    {"cell":[111,67],"low":-1,"high":0,"ladder":false},
    {"cell":[137,67],"low":0,"high":1,"ladder":false},
    {"cell":[137,67],"low":1,"high":2,"ladder":false},
    {"cell":[137,67],"low":-1,"high":0,"ladder":false},
    {"cell":[114,20],"low":0,"high":1,"ladder":false},
    {"cell":[137,20],"low":0,"high":1,"ladder":false},
    {"cell":[109,41],"low":0,"high":1,"ladder":false},
    {"cell":[129,41],"low":0,"high":1,"ladder":false},
    {"cell":[116,87],"low":0,"high":1,"ladder":false},
    {"cell":[12,13],"low":0,"high":1,"ladder":false},
    {"cell":[104,10],"low":0,"high":1,"ladder":false},
    {"cell":[69,34],"low":0,"high":1,"ladder":false},
    {"cell":[10,60],"low":0,"high":1,"ladder":false}
  ],
  "props": [
    {"kind":"bridge_truss","rect":[150,4,8,2],"solid":"wall","facing":0,"note":"철교 트러스","level":0},
    {"kind":"car","rect":[41,56,4,2],"solid":"low","facing":0,"note":"버려진 차","level":0},
    {"kind":"car","rect":[87,78,4,2],"solid":"low","facing":0,"note":"버려진 차","level":0},
    {"kind":"dock_platform","rect":[132,51,12,4],"solid":"none","facing":0,"note":"평평한 하역장","level":0},
    {"kind":"reed_clump","rect":[141,72,3,3],"solid":"none","facing":0,"note":"갈대 무리","level":0},
    {"kind":"sleeper_pile","rect":[27,8,3,2],"solid":"low","facing":0,"note":"침목 더미","level":0},
    {"kind":"platform_cart","rect":[60,8,2,1],"solid":"low","facing":0,"note":"승강장 짐수레","level":0},
    {"kind":"handcart","rect":[6,26,2,1],"solid":"low","facing":0,"note":"손수레","level":0},
    {"kind":"crate_stack","rect":[87,25,2,2],"solid":"low","facing":0,"note":"나무 상자 더미","level":0},
    {"kind":"water","rect":[145,4,5,2],"solid":"low","facing":0,"note":"물","level":0},
    {"kind":"water","rect":[158,4,17,2],"solid":"low","facing":0,"note":"물","level":0},
    {"kind":"water","rect":[145,6,30,94],"solid":"low","facing":1,"note":"물","level":0},
    {"kind":"shelf","rect":[110,56,3,1],"solid":"low","facing":0,"note":"강변 창고 가 사무실 선반","level":0},
    {"kind":"part_crate","rect":[110,65,1,1],"solid":"low","facing":0,"note":"강변 창고 가 사무실 부품 상자","level":0},
    {"kind":"barrel","rect":[113,56,1,1],"solid":"low","facing":0,"note":"강변 창고 가 사무실 통","level":0},
    {"kind":"shelf","rect":[116,56,3,1],"solid":"low","facing":0,"note":"강변 창고 가 선별실 선반","level":0},
    {"kind":"part_crate","rect":[116,65,1,1],"solid":"low","facing":0,"note":"강변 창고 가 선별실 부품 상자","level":0},
    {"kind":"barrel","rect":[119,56,1,1],"solid":"low","facing":0,"note":"강변 창고 가 선별실 통","level":0},
    {"kind":"shelf","rect":[122,56,3,1],"solid":"low","facing":0,"note":"강변 창고 가 선반 칸 선반","level":0},
    {"kind":"part_crate","rect":[122,65,1,1],"solid":"low","facing":0,"note":"강변 창고 가 선반 칸 부품 상자","level":0},
    {"kind":"barrel","rect":[125,56,1,1],"solid":"low","facing":0,"note":"강변 창고 가 선반 칸 통","level":0},
    {"kind":"shelf","rect":[128,56,3,1],"solid":"low","facing":0,"note":"강변 창고 가 계량실 선반","level":0},
    {"kind":"part_crate","rect":[128,65,1,1],"solid":"low","facing":0,"note":"강변 창고 가 계량실 부품 상자","level":0},
    {"kind":"barrel","rect":[131,56,1,1],"solid":"low","facing":0,"note":"강변 창고 가 계량실 통","level":0},
    {"kind":"shelf","rect":[134,56,3,1],"solid":"low","facing":0,"note":"강변 창고 가 안쪽 창고 선반","level":0},
    {"kind":"part_crate","rect":[134,65,1,1],"solid":"low","facing":0,"note":"강변 창고 가 안쪽 창고 부품 상자","level":0},
    {"kind":"barrel","rect":[137,56,1,1],"solid":"low","facing":0,"note":"강변 창고 가 안쪽 창고 통","level":0},
    {"kind":"shelf","rect":[110,79,3,1],"solid":"low","facing":0,"note":"강변 창고 가 사무실 선반","level":0},
    {"kind":"part_crate","rect":[110,70,1,1],"solid":"low","facing":0,"note":"강변 창고 가 사무실 부품 상자","level":0},
    {"kind":"barrel","rect":[113,70,1,1],"solid":"low","facing":0,"note":"강변 창고 가 사무실 통","level":0},
    {"kind":"shelf","rect":[116,79,3,1],"solid":"low","facing":0,"note":"강변 창고 가 선별실 선반","level":0},
    {"kind":"part_crate","rect":[116,70,1,1],"solid":"low","facing":0,"note":"강변 창고 가 선별실 부품 상자","level":0},
    {"kind":"barrel","rect":[119,70,1,1],"solid":"low","facing":0,"note":"강변 창고 가 선별실 통","level":0},
    {"kind":"shelf","rect":[122,79,3,1],"solid":"low","facing":0,"note":"강변 창고 가 선반 칸 선반","level":0},
    {"kind":"part_crate","rect":[122,70,1,1],"solid":"low","facing":0,"note":"강변 창고 가 선반 칸 부품 상자","level":0},
    {"kind":"barrel","rect":[125,70,1,1],"solid":"low","facing":0,"note":"강변 창고 가 선반 칸 통","level":0},
    {"kind":"shelf","rect":[128,79,3,1],"solid":"low","facing":0,"note":"강변 창고 가 계량실 선반","level":0},
    {"kind":"part_crate","rect":[128,70,1,1],"solid":"low","facing":0,"note":"강변 창고 가 계량실 부품 상자","level":0},
    {"kind":"barrel","rect":[131,70,1,1],"solid":"low","facing":0,"note":"강변 창고 가 계량실 통","level":0},
    {"kind":"shelf","rect":[134,79,3,1],"solid":"low","facing":0,"note":"강변 창고 가 안쪽 창고 선반","level":0},
    {"kind":"part_crate","rect":[134,70,1,1],"solid":"low","facing":0,"note":"강변 창고 가 안쪽 창고 부품 상자","level":0},
    {"kind":"barrel","rect":[137,70,1,1],"solid":"low","facing":0,"note":"강변 창고 가 안쪽 창고 통","level":0},
    {"kind":"shelf","rect":[110,56,3,1],"solid":"none","facing":0,"note":"강변 창고 가 사무실 선반","level":1},
    {"kind":"part_crate","rect":[110,65,1,1],"solid":"none","facing":0,"note":"강변 창고 가 사무실 부품 상자","level":1},
    {"kind":"barrel","rect":[113,56,1,1],"solid":"none","facing":0,"note":"강변 창고 가 사무실 통","level":1},
    {"kind":"shelf","rect":[116,56,3,1],"solid":"none","facing":0,"note":"강변 창고 가 선별실 선반","level":1},
    {"kind":"part_crate","rect":[116,65,1,1],"solid":"none","facing":0,"note":"강변 창고 가 선별실 부품 상자","level":1},
    {"kind":"barrel","rect":[119,56,1,1],"solid":"none","facing":0,"note":"강변 창고 가 선별실 통","level":1},
    {"kind":"shelf","rect":[122,56,3,1],"solid":"none","facing":0,"note":"강변 창고 가 선반 칸 선반","level":1},
    {"kind":"part_crate","rect":[122,65,1,1],"solid":"none","facing":0,"note":"강변 창고 가 선반 칸 부품 상자","level":1},
    {"kind":"barrel","rect":[125,56,1,1],"solid":"none","facing":0,"note":"강변 창고 가 선반 칸 통","level":1},
    {"kind":"shelf","rect":[128,56,3,1],"solid":"none","facing":0,"note":"강변 창고 가 계량실 선반","level":1},
    {"kind":"part_crate","rect":[128,65,1,1],"solid":"none","facing":0,"note":"강변 창고 가 계량실 부품 상자","level":1},
    {"kind":"barrel","rect":[131,56,1,1],"solid":"none","facing":0,"note":"강변 창고 가 계량실 통","level":1},
    {"kind":"shelf","rect":[134,56,3,1],"solid":"none","facing":0,"note":"강변 창고 가 안쪽 창고 선반","level":1},
    {"kind":"part_crate","rect":[134,65,1,1],"solid":"none","facing":0,"note":"강변 창고 가 안쪽 창고 부품 상자","level":1},
    {"kind":"barrel","rect":[137,56,1,1],"solid":"none","facing":0,"note":"강변 창고 가 안쪽 창고 통","level":1},
    {"kind":"shelf","rect":[110,79,3,1],"solid":"none","facing":0,"note":"강변 창고 가 사무실 선반","level":1},
    {"kind":"part_crate","rect":[110,70,1,1],"solid":"none","facing":0,"note":"강변 창고 가 사무실 부품 상자","level":1},
    {"kind":"barrel","rect":[113,70,1,1],"solid":"none","facing":0,"note":"강변 창고 가 사무실 통","level":1},
    {"kind":"shelf","rect":[116,79,3,1],"solid":"none","facing":0,"note":"강변 창고 가 선별실 선반","level":1},
    {"kind":"part_crate","rect":[116,70,1,1],"solid":"none","facing":0,"note":"강변 창고 가 선별실 부품 상자","level":1},
    {"kind":"barrel","rect":[119,70,1,1],"solid":"none","facing":0,"note":"강변 창고 가 선별실 통","level":1},
    {"kind":"shelf","rect":[122,79,3,1],"solid":"none","facing":0,"note":"강변 창고 가 선반 칸 선반","level":1},
    {"kind":"part_crate","rect":[122,70,1,1],"solid":"none","facing":0,"note":"강변 창고 가 선반 칸 부품 상자","level":1},
    {"kind":"barrel","rect":[125,70,1,1],"solid":"none","facing":0,"note":"강변 창고 가 선반 칸 통","level":1},
    {"kind":"shelf","rect":[128,79,3,1],"solid":"none","facing":0,"note":"강변 창고 가 계량실 선반","level":1},
    {"kind":"part_crate","rect":[128,70,1,1],"solid":"none","facing":0,"note":"강변 창고 가 계량실 부품 상자","level":1},
    {"kind":"barrel","rect":[131,70,1,1],"solid":"none","facing":0,"note":"강변 창고 가 계량실 통","level":1},
    {"kind":"shelf","rect":[134,79,3,1],"solid":"none","facing":0,"note":"강변 창고 가 안쪽 창고 선반","level":1},
    {"kind":"part_crate","rect":[134,70,1,1],"solid":"none","facing":0,"note":"강변 창고 가 안쪽 창고 부품 상자","level":1},
    {"kind":"barrel","rect":[137,70,1,1],"solid":"none","facing":0,"note":"강변 창고 가 안쪽 창고 통","level":1},
    {"kind":"shelf","rect":[110,56,3,1],"solid":"none","facing":0,"note":"강변 창고 가 사무실 선반","level":2},
    {"kind":"part_crate","rect":[110,65,1,1],"solid":"none","facing":0,"note":"강변 창고 가 사무실 부품 상자","level":2},
    {"kind":"barrel","rect":[113,56,1,1],"solid":"none","facing":0,"note":"강변 창고 가 사무실 통","level":2},
    {"kind":"shelf","rect":[116,56,3,1],"solid":"none","facing":0,"note":"강변 창고 가 선별실 선반","level":2},
    {"kind":"part_crate","rect":[116,65,1,1],"solid":"none","facing":0,"note":"강변 창고 가 선별실 부품 상자","level":2},
    {"kind":"barrel","rect":[119,56,1,1],"solid":"none","facing":0,"note":"강변 창고 가 선별실 통","level":2},
    {"kind":"shelf","rect":[122,56,3,1],"solid":"none","facing":0,"note":"강변 창고 가 선반 칸 선반","level":2},
    {"kind":"part_crate","rect":[122,65,1,1],"solid":"none","facing":0,"note":"강변 창고 가 선반 칸 부품 상자","level":2},
    {"kind":"barrel","rect":[125,56,1,1],"solid":"none","facing":0,"note":"강변 창고 가 선반 칸 통","level":2},
    {"kind":"shelf","rect":[128,56,3,1],"solid":"none","facing":0,"note":"강변 창고 가 계량실 선반","level":2},
    {"kind":"part_crate","rect":[128,65,1,1],"solid":"none","facing":0,"note":"강변 창고 가 계량실 부품 상자","level":2},
    {"kind":"barrel","rect":[131,56,1,1],"solid":"none","facing":0,"note":"강변 창고 가 계량실 통","level":2},
    {"kind":"shelf","rect":[134,56,3,1],"solid":"none","facing":0,"note":"강변 창고 가 안쪽 창고 선반","level":2},
    {"kind":"part_crate","rect":[134,65,1,1],"solid":"none","facing":0,"note":"강변 창고 가 안쪽 창고 부품 상자","level":2},
    {"kind":"barrel","rect":[137,56,1,1],"solid":"none","facing":0,"note":"강변 창고 가 안쪽 창고 통","level":2},
    {"kind":"shelf","rect":[110,79,3,1],"solid":"none","facing":0,"note":"강변 창고 가 사무실 선반","level":2},
    {"kind":"part_crate","rect":[110,70,1,1],"solid":"none","facing":0,"note":"강변 창고 가 사무실 부품 상자","level":2},
    {"kind":"barrel","rect":[113,70,1,1],"solid":"none","facing":0,"note":"강변 창고 가 사무실 통","level":2},
    {"kind":"shelf","rect":[116,79,3,1],"solid":"none","facing":0,"note":"강변 창고 가 선별실 선반","level":2},
    {"kind":"part_crate","rect":[116,70,1,1],"solid":"none","facing":0,"note":"강변 창고 가 선별실 부품 상자","level":2},
    {"kind":"barrel","rect":[119,70,1,1],"solid":"none","facing":0,"note":"강변 창고 가 선별실 통","level":2},
    {"kind":"shelf","rect":[122,79,3,1],"solid":"none","facing":0,"note":"강변 창고 가 선반 칸 선반","level":2},
    {"kind":"part_crate","rect":[122,70,1,1],"solid":"none","facing":0,"note":"강변 창고 가 선반 칸 부품 상자","level":2},
    {"kind":"barrel","rect":[125,70,1,1],"solid":"none","facing":0,"note":"강변 창고 가 선반 칸 통","level":2},
    {"kind":"shelf","rect":[128,79,3,1],"solid":"none","facing":0,"note":"강변 창고 가 계량실 선반","level":2},
    {"kind":"part_crate","rect":[128,70,1,1],"solid":"none","facing":0,"note":"강변 창고 가 계량실 부품 상자","level":2},
    {"kind":"barrel","rect":[131,70,1,1],"solid":"none","facing":0,"note":"강변 창고 가 계량실 통","level":2},
    {"kind":"shelf","rect":[134,79,3,1],"solid":"none","facing":0,"note":"강변 창고 가 안쪽 창고 선반","level":2},
    {"kind":"part_crate","rect":[134,70,1,1],"solid":"none","facing":0,"note":"강변 창고 가 안쪽 창고 부품 상자","level":2},
    {"kind":"barrel","rect":[137,70,1,1],"solid":"none","facing":0,"note":"강변 창고 가 안쪽 창고 통","level":2},
    {"kind":"shelf","rect":[110,56,3,1],"solid":"none","facing":0,"note":"강변 창고 가 저장고 선반","level":-1},
    {"kind":"part_crate","rect":[110,65,1,1],"solid":"none","facing":0,"note":"강변 창고 가 저장고 부품 상자","level":-1},
    {"kind":"barrel","rect":[113,56,1,1],"solid":"none","facing":0,"note":"강변 창고 가 저장고 통","level":-1},
    {"kind":"shelf","rect":[116,56,3,1],"solid":"none","facing":0,"note":"강변 창고 가 냉기 칸 선반","level":-1},
    {"kind":"part_crate","rect":[116,65,1,1],"solid":"none","facing":0,"note":"강변 창고 가 냉기 칸 부품 상자","level":-1},
    {"kind":"barrel","rect":[119,56,1,1],"solid":"none","facing":0,"note":"강변 창고 가 냉기 칸 통","level":-1},
    {"kind":"shelf","rect":[122,56,3,1],"solid":"none","facing":0,"note":"강변 창고 가 안쪽 보관실 선반","level":-1},
    {"kind":"part_crate","rect":[122,65,1,1],"solid":"none","facing":0,"note":"강변 창고 가 안쪽 보관실 부품 상자","level":-1},
    {"kind":"barrel","rect":[125,56,1,1],"solid":"none","facing":0,"note":"강변 창고 가 안쪽 보관실 통","level":-1},
    {"kind":"shelf","rect":[128,56,3,1],"solid":"none","facing":0,"note":"강변 창고 가 저장고 선반","level":-1},
    {"kind":"part_crate","rect":[128,65,1,1],"solid":"none","facing":0,"note":"강변 창고 가 저장고 부품 상자","level":-1},
    {"kind":"barrel","rect":[131,56,1,1],"solid":"none","facing":0,"note":"강변 창고 가 저장고 통","level":-1},
    {"kind":"shelf","rect":[134,56,3,1],"solid":"none","facing":0,"note":"강변 창고 가 냉기 칸 선반","level":-1},
    {"kind":"part_crate","rect":[134,65,1,1],"solid":"none","facing":0,"note":"강변 창고 가 냉기 칸 부품 상자","level":-1},
    {"kind":"barrel","rect":[137,56,1,1],"solid":"none","facing":0,"note":"강변 창고 가 냉기 칸 통","level":-1},
    {"kind":"shelf","rect":[110,79,3,1],"solid":"none","facing":0,"note":"강변 창고 가 저장고 선반","level":-1},
    {"kind":"part_crate","rect":[110,70,1,1],"solid":"none","facing":0,"note":"강변 창고 가 저장고 부품 상자","level":-1},
    {"kind":"barrel","rect":[113,70,1,1],"solid":"none","facing":0,"note":"강변 창고 가 저장고 통","level":-1},
    {"kind":"shelf","rect":[116,79,3,1],"solid":"none","facing":0,"note":"강변 창고 가 냉기 칸 선반","level":-1},
    {"kind":"part_crate","rect":[116,70,1,1],"solid":"none","facing":0,"note":"강변 창고 가 냉기 칸 부품 상자","level":-1},
    {"kind":"barrel","rect":[119,70,1,1],"solid":"none","facing":0,"note":"강변 창고 가 냉기 칸 통","level":-1},
    {"kind":"shelf","rect":[122,79,3,1],"solid":"none","facing":0,"note":"강변 창고 가 안쪽 보관실 선반","level":-1},
    {"kind":"part_crate","rect":[122,70,1,1],"solid":"none","facing":0,"note":"강변 창고 가 안쪽 보관실 부품 상자","level":-1},
    {"kind":"barrel","rect":[125,70,1,1],"solid":"none","facing":0,"note":"강변 창고 가 안쪽 보관실 통","level":-1},
    {"kind":"shelf","rect":[128,79,3,1],"solid":"none","facing":0,"note":"강변 창고 가 저장고 선반","level":-1},
    {"kind":"part_crate","rect":[128,70,1,1],"solid":"none","facing":0,"note":"강변 창고 가 저장고 부품 상자","level":-1},
    {"kind":"barrel","rect":[131,70,1,1],"solid":"none","facing":0,"note":"강변 창고 가 저장고 통","level":-1},
    {"kind":"shelf","rect":[134,79,3,1],"solid":"none","facing":0,"note":"강변 창고 가 냉기 칸 선반","level":-1},
    {"kind":"part_crate","rect":[134,70,1,1],"solid":"none","facing":0,"note":"강변 창고 가 냉기 칸 부품 상자","level":-1},
    {"kind":"barrel","rect":[137,70,1,1],"solid":"none","facing":0,"note":"강변 창고 가 냉기 칸 통","level":-1},
    {"kind":"shelf","rect":[126,15,3,1],"solid":"low","facing":0,"note":"강변 창고 나 선별실 선반","level":0},
    {"kind":"part_crate","rect":[136,18,1,1],"solid":"low","facing":0,"note":"강변 창고 나 선별실 부품 상자","level":0},
    {"kind":"barrel","rect":[126,18,1,1],"solid":"low","facing":0,"note":"강변 창고 나 선별실 통","level":0},
    {"kind":"shelf","rect":[126,23,3,1],"solid":"low","facing":0,"note":"강변 창고 나 선별실 선반","level":0},
    {"kind":"part_crate","rect":[136,27,1,1],"solid":"low","facing":0,"note":"강변 창고 나 선별실 부품 상자","level":0},
    {"kind":"barrel","rect":[126,27,1,1],"solid":"low","facing":0,"note":"강변 창고 나 선별실 통","level":0},
    {"kind":"shelf","rect":[113,15,3,1],"solid":"none","facing":0,"note":"강변 창고 나 사무실 선반","level":1},
    {"kind":"part_crate","rect":[122,18,1,1],"solid":"none","facing":0,"note":"강변 창고 나 사무실 부품 상자","level":1},
    {"kind":"barrel","rect":[113,18,1,1],"solid":"none","facing":0,"note":"강변 창고 나 사무실 통","level":1},
    {"kind":"shelf","rect":[126,15,3,1],"solid":"none","facing":0,"note":"강변 창고 나 선별실 선반","level":1},
    {"kind":"part_crate","rect":[136,18,1,1],"solid":"none","facing":0,"note":"강변 창고 나 선별실 부품 상자","level":1},
    {"kind":"barrel","rect":[126,18,1,1],"solid":"none","facing":0,"note":"강변 창고 나 선별실 통","level":1},
    {"kind":"shelf","rect":[113,23,3,1],"solid":"none","facing":0,"note":"강변 창고 나 사무실 선반","level":1},
    {"kind":"part_crate","rect":[122,27,1,1],"solid":"none","facing":0,"note":"강변 창고 나 사무실 부품 상자","level":1},
    {"kind":"barrel","rect":[113,27,1,1],"solid":"none","facing":0,"note":"강변 창고 나 사무실 통","level":1},
    {"kind":"shelf","rect":[126,23,3,1],"solid":"none","facing":0,"note":"강변 창고 나 선별실 선반","level":1},
    {"kind":"part_crate","rect":[136,27,1,1],"solid":"none","facing":0,"note":"강변 창고 나 선별실 부품 상자","level":1},
    {"kind":"barrel","rect":[126,27,1,1],"solid":"none","facing":0,"note":"강변 창고 나 선별실 통","level":1},
    {"kind":"shelf","rect":[108,34,3,1],"solid":"low","facing":0,"note":"강변 창고 다 사무실 선반","level":0},
    {"kind":"part_crate","rect":[116,39,1,1],"solid":"low","facing":0,"note":"강변 창고 다 사무실 부품 상자","level":0},
    {"kind":"barrel","rect":[108,39,1,1],"solid":"low","facing":0,"note":"강변 창고 다 사무실 통","level":0},
    {"kind":"shelf","rect":[120,34,3,1],"solid":"low","facing":0,"note":"강변 창고 다 선별실 선반","level":0},
    {"kind":"part_crate","rect":[128,39,1,1],"solid":"low","facing":0,"note":"강변 창고 다 선별실 부품 상자","level":0},
    {"kind":"barrel","rect":[120,39,1,1],"solid":"low","facing":0,"note":"강변 창고 다 선별실 통","level":0},
    {"kind":"shelf","rect":[108,44,3,1],"solid":"low","facing":0,"note":"강변 창고 다 사무실 선반","level":0},
    {"kind":"part_crate","rect":[116,49,1,1],"solid":"low","facing":0,"note":"강변 창고 다 사무실 부품 상자","level":0},
    {"kind":"barrel","rect":[108,49,1,1],"solid":"low","facing":0,"note":"강변 창고 다 사무실 통","level":0},
    {"kind":"shelf","rect":[120,44,3,1],"solid":"low","facing":0,"note":"강변 창고 다 선별실 선반","level":0},
    {"kind":"part_crate","rect":[128,49,1,1],"solid":"low","facing":0,"note":"강변 창고 다 선별실 부품 상자","level":0},
    {"kind":"barrel","rect":[120,49,1,1],"solid":"low","facing":0,"note":"강변 창고 다 선별실 통","level":0},
    {"kind":"shelf","rect":[108,34,3,1],"solid":"none","facing":0,"note":"강변 창고 다 사무실 선반","level":1},
    {"kind":"part_crate","rect":[116,39,1,1],"solid":"none","facing":0,"note":"강변 창고 다 사무실 부품 상자","level":1},
    {"kind":"barrel","rect":[108,39,1,1],"solid":"none","facing":0,"note":"강변 창고 다 사무실 통","level":1},
    {"kind":"shelf","rect":[120,34,3,1],"solid":"none","facing":0,"note":"강변 창고 다 선별실 선반","level":1},
    {"kind":"part_crate","rect":[128,39,1,1],"solid":"none","facing":0,"note":"강변 창고 다 선별실 부품 상자","level":1},
    {"kind":"barrel","rect":[120,39,1,1],"solid":"none","facing":0,"note":"강변 창고 다 선별실 통","level":1},
    {"kind":"shelf","rect":[108,44,3,1],"solid":"none","facing":0,"note":"강변 창고 다 사무실 선반","level":1},
    {"kind":"part_crate","rect":[116,49,1,1],"solid":"none","facing":0,"note":"강변 창고 다 사무실 부품 상자","level":1},
    {"kind":"barrel","rect":[108,49,1,1],"solid":"none","facing":0,"note":"강변 창고 다 사무실 통","level":1},
    {"kind":"shelf","rect":[120,44,3,1],"solid":"none","facing":0,"note":"강변 창고 다 선별실 선반","level":1},
    {"kind":"part_crate","rect":[128,49,1,1],"solid":"none","facing":0,"note":"강변 창고 다 선별실 부품 상자","level":1},
    {"kind":"barrel","rect":[120,49,1,1],"solid":"none","facing":0,"note":"강변 창고 다 선별실 통","level":1},
    {"kind":"shelf","rect":[115,86,3,1],"solid":"low","facing":0,"note":"강변 창고 라 앞방 선반","level":0},
    {"kind":"part_crate","rect":[124,97,1,1],"solid":"low","facing":0,"note":"강변 창고 라 앞방 부품 상자","level":0},
    {"kind":"barrel","rect":[115,97,1,1],"solid":"low","facing":0,"note":"강변 창고 라 앞방 통","level":0},
    {"kind":"shelf","rect":[128,86,3,1],"solid":"low","facing":0,"note":"강변 창고 라 안쪽 방 선반","level":0},
    {"kind":"part_crate","rect":[136,97,1,1],"solid":"low","facing":0,"note":"강변 창고 라 안쪽 방 부품 상자","level":0},
    {"kind":"barrel","rect":[128,97,1,1],"solid":"low","facing":0,"note":"강변 창고 라 안쪽 방 통","level":0},
    {"kind":"shelf","rect":[115,86,3,1],"solid":"none","facing":0,"note":"강변 창고 라 앞방 선반","level":1},
    {"kind":"part_crate","rect":[124,97,1,1],"solid":"none","facing":0,"note":"강변 창고 라 앞방 부품 상자","level":1},
    {"kind":"barrel","rect":[115,97,1,1],"solid":"none","facing":0,"note":"강변 창고 라 앞방 통","level":1},
    {"kind":"shelf","rect":[128,86,3,1],"solid":"none","facing":0,"note":"강변 창고 라 안쪽 방 선반","level":1},
    {"kind":"part_crate","rect":[136,97,1,1],"solid":"none","facing":0,"note":"강변 창고 라 안쪽 방 부품 상자","level":1},
    {"kind":"barrel","rect":[128,97,1,1],"solid":"none","facing":0,"note":"강변 창고 라 안쪽 방 통","level":1},
    {"kind":"desk","rect":[11,12,2,1],"solid":"none","facing":0,"note":"역사 앞방 책상","level":1},
    {"kind":"file_cabinet","rect":[19,23,2,1],"solid":"none","facing":0,"note":"역사 앞방 기술 서류함","level":1},
    {"kind":"conductor_log_chest","rect":[11,23,2,1],"solid":"none","facing":0,"note":"역사 앞방 차장 일지 궤","level":1},
    {"kind":"desk","rect":[23,12,2,1],"solid":"none","facing":0,"note":"역사 안쪽 방 책상","level":1},
    {"kind":"file_cabinet","rect":[30,23,2,1],"solid":"none","facing":0,"note":"역사 안쪽 방 기술 서류함","level":1},
    {"kind":"conductor_log_chest","rect":[23,23,2,1],"solid":"none","facing":0,"note":"역사 안쪽 방 차장 일지 궤","level":1},
    {"kind":"desk","rect":[103,9,2,1],"solid":"none","facing":0,"note":"신호 취급소 작업실 책상","level":1},
    {"kind":"file_cabinet","rect":[106,13,2,1],"solid":"none","facing":0,"note":"신호 취급소 작업실 기술 서류함","level":1},
    {"kind":"conductor_log_chest","rect":[103,13,2,1],"solid":"none","facing":0,"note":"신호 취급소 작업실 차장 일지 궤","level":1},
    {"kind":"shop_counter","rect":[11,34,3,1],"solid":"low","facing":0,"note":"빵집 매장 가게 계산대","level":0},
    {"kind":"bread_rack","rect":[18,36,1,1],"solid":"low","facing":0,"note":"빵집 매장 빵 선반","level":0},
    {"kind":"part_crate","rect":[20,34,1,1],"solid":"low","facing":0,"note":"매장 부품 상자","level":0},
    {"kind":"sack_pile","rect":[11,38,2,2],"solid":"low","facing":0,"note":"빵집 뒤 창고 자루 더미","level":0},
    {"kind":"freezer_chest","rect":[11,40,2,1],"solid":"low","facing":0,"note":"빵집 뒤 창고 냉동 궤","level":0},
    {"kind":"part_crate","rect":[20,38,1,1],"solid":"low","facing":0,"note":"뒤 창고 부품 상자","level":0},
    {"kind":"display_shelf","rect":[48,36,4,1],"solid":"low","facing":0,"note":"잡화점 매장 진열대","level":0},
    {"kind":"shop_counter","rect":[48,33,3,1],"solid":"low","facing":0,"note":"잡화점 매장 가게 계산대","level":0},
    {"kind":"bread_rack","rect":[55,36,1,1],"solid":"low","facing":0,"note":"잡화점 매장 빵 선반","level":0},
    {"kind":"sack_pile","rect":[48,38,2,2],"solid":"low","facing":0,"note":"잡화점 뒤 창고 자루 더미","level":0},
    {"kind":"freezer_chest","rect":[48,40,2,1],"solid":"low","facing":0,"note":"잡화점 뒤 창고 냉동 궤","level":0},
    {"kind":"part_crate","rect":[57,38,1,1],"solid":"low","facing":0,"note":"뒤 창고 부품 상자","level":0},
    {"kind":"bed","rect":[68,33,2,1],"solid":"low","facing":0,"note":"철도원 주택 가 앞방 침대","level":0},
    {"kind":"desk","rect":[70,40,2,1],"solid":"low","facing":0,"note":"철도원 주택 가 앞방 책상","level":0},
    {"kind":"part_crate","rect":[72,33,1,1],"solid":"low","facing":0,"note":"앞방 부품 상자","level":0},
    {"kind":"bed","rect":[74,33,2,1],"solid":"low","facing":0,"note":"철도원 주택 가 안쪽 방 침대","level":0},
    {"kind":"desk","rect":[74,40,2,1],"solid":"low","facing":0,"note":"철도원 주택 가 안쪽 방 책상","level":0},
    {"kind":"part_crate","rect":[77,33,1,1],"solid":"low","facing":0,"note":"안쪽 방 부품 상자","level":0},
    {"kind":"bed","rect":[68,33,2,1],"solid":"none","facing":0,"note":"철도원 주택 가 앞방 침대","level":1},
    {"kind":"desk","rect":[70,40,2,1],"solid":"none","facing":0,"note":"철도원 주택 가 앞방 책상","level":1},
    {"kind":"part_crate","rect":[72,39,1,1],"solid":"none","facing":0,"note":"앞방 부품 상자","level":1},
    {"kind":"bed","rect":[74,33,2,1],"solid":"none","facing":0,"note":"철도원 주택 가 안쪽 방 침대","level":1},
    {"kind":"desk","rect":[75,40,2,1],"solid":"none","facing":0,"note":"철도원 주택 가 안쪽 방 책상","level":1},
    {"kind":"part_crate","rect":[77,39,1,1],"solid":"none","facing":0,"note":"안쪽 방 부품 상자","level":1},
    {"kind":"bed","rect":[9,59,2,1],"solid":"low","facing":0,"note":"철도원 주택 나 앞방 침대","level":0},
    {"kind":"desk","rect":[11,66,2,1],"solid":"low","facing":0,"note":"철도원 주택 나 앞방 책상","level":0},
    {"kind":"part_crate","rect":[13,59,1,1],"solid":"low","facing":0,"note":"앞방 부품 상자","level":0},
    {"kind":"bed","rect":[15,59,2,1],"solid":"low","facing":0,"note":"철도원 주택 나 안쪽 방 침대","level":0},
    {"kind":"desk","rect":[15,66,2,1],"solid":"low","facing":0,"note":"철도원 주택 나 안쪽 방 책상","level":0},
    {"kind":"part_crate","rect":[18,59,1,1],"solid":"low","facing":0,"note":"안쪽 방 부품 상자","level":0},
    {"kind":"bed","rect":[9,59,2,1],"solid":"none","facing":0,"note":"철도원 주택 나 앞방 침대","level":1},
    {"kind":"desk","rect":[11,66,2,1],"solid":"none","facing":0,"note":"철도원 주택 나 앞방 책상","level":1},
    {"kind":"part_crate","rect":[13,65,1,1],"solid":"none","facing":0,"note":"앞방 부품 상자","level":1},
    {"kind":"bed","rect":[15,59,2,1],"solid":"none","facing":0,"note":"철도원 주택 나 안쪽 방 침대","level":1},
    {"kind":"desk","rect":[16,66,2,1],"solid":"none","facing":0,"note":"철도원 주택 나 안쪽 방 책상","level":1},
    {"kind":"part_crate","rect":[18,65,1,1],"solid":"none","facing":0,"note":"안쪽 방 부품 상자","level":1},
    {"kind":"bed","rect":[48,61,2,1],"solid":"low","facing":0,"note":"철도원 주택 다 앞방 침대","level":0},
    {"kind":"desk","rect":[49,68,2,1],"solid":"low","facing":0,"note":"철도원 주택 다 앞방 책상","level":0},
    {"kind":"part_crate","rect":[51,61,1,1],"solid":"low","facing":0,"note":"앞방 부품 상자","level":0},
    {"kind":"bed","rect":[53,61,2,1],"solid":"low","facing":0,"note":"철도원 주택 다 안쪽 방 침대","level":0},
    {"kind":"desk","rect":[53,68,2,1],"solid":"low","facing":0,"note":"철도원 주택 다 안쪽 방 책상","level":0},
    {"kind":"part_crate","rect":[56,61,1,1],"solid":"low","facing":0,"note":"안쪽 방 부품 상자","level":0},
    {"kind":"shelf","rect":[83,66,3,1],"solid":"low","facing":0,"note":"모래 창고 작업실 선반","level":0},
    {"kind":"part_crate","rect":[83,61,1,1],"solid":"low","facing":0,"note":"모래 창고 작업실 부품 상자","level":0},
    {"kind":"barrel","rect":[88,66,1,1],"solid":"low","facing":0,"note":"모래 창고 작업실 통","level":0},
    {"kind":"shelf","rect":[9,76,3,1],"solid":"low","facing":0,"note":"곡물 건조 창고 앞방 선반","level":0},
    {"kind":"part_crate","rect":[16,87,1,1],"solid":"low","facing":0,"note":"곡물 건조 창고 앞방 부품 상자","level":0},
    {"kind":"barrel","rect":[9,87,1,1],"solid":"low","facing":0,"note":"곡물 건조 창고 앞방 통","level":0},
    {"kind":"shelf","rect":[20,76,3,1],"solid":"low","facing":0,"note":"곡물 건조 창고 안쪽 방 선반","level":0},
    {"kind":"part_crate","rect":[26,87,1,1],"solid":"low","facing":0,"note":"곡물 건조 창고 안쪽 방 부품 상자","level":0},
    {"kind":"barrel","rect":[20,87,1,1],"solid":"low","facing":0,"note":"곡물 건조 창고 안쪽 방 통","level":0},
    {"kind":"shelf","rect":[58,80,3,1],"solid":"low","facing":0,"note":"공구 창고 앞방 선반","level":0},
    {"kind":"part_crate","rect":[60,86,1,1],"solid":"low","facing":0,"note":"공구 창고 앞방 부품 상자","level":0},
    {"kind":"barrel","rect":[58,86,1,1],"solid":"low","facing":0,"note":"공구 창고 앞방 통","level":0},
    {"kind":"shelf","rect":[64,80,3,1],"solid":"low","facing":0,"note":"공구 창고 안쪽 방 선반","level":0},
    {"kind":"part_crate","rect":[65,86,1,1],"solid":"low","facing":0,"note":"공구 창고 안쪽 방 부품 상자","level":0},
    {"kind":"barrel","rect":[64,86,1,1],"solid":"low","facing":0,"note":"공구 창고 안쪽 방 통","level":0},
    {"kind":"desk","rect":[83,92,2,1],"solid":"low","facing":0,"note":"계량소 작업실 책상","level":0},
    {"kind":"file_cabinet","rect":[87,89,2,1],"solid":"low","facing":0,"note":"계량소 작업실 기술 서류함","level":0},
    {"kind":"part_crate","rect":[83,89,1,1],"solid":"low","facing":0,"note":"작업실 부품 상자","level":0},
    {"kind":"firewood_pile","rect":[23,61,2,1],"solid":"low","facing":0,"note":"장작 더미 작업 흔적","level":0},
    {"kind":"barrel","rect":[27,61,1,1],"solid":"low","facing":0,"note":"통 작업 흔적","level":0},
    {"kind":"handcart","rect":[31,61,2,1],"solid":"low","facing":0,"note":"손수레 작업 흔적","level":0},
    {"kind":"sack_pile","rect":[62,60,2,2],"solid":"low","facing":0,"note":"자루 더미 작업 흔적","level":0},
    {"kind":"crate_stack","rect":[66,60,2,2],"solid":"low","facing":0,"note":"나무 상자 더미 작업 흔적","level":0},
    {"kind":"barrel","rect":[70,60,1,1],"solid":"low","facing":0,"note":"통 작업 흔적","level":0},
    {"kind":"handcart","rect":[71,80,2,1],"solid":"low","facing":0,"note":"손수레 작업 흔적","level":0},
    {"kind":"sack_pile","rect":[75,80,2,2],"solid":"low","facing":0,"note":"자루 더미 작업 흔적","level":0},
    {"kind":"crate_stack","rect":[79,80,2,2],"solid":"low","facing":0,"note":"나무 상자 더미 작업 흔적","level":0},
    {"kind":"mooring_post","rect":[132,40,1,1],"solid":"low","facing":0,"note":"계류 말뚝 작업 흔적","level":0},
    {"kind":"rope_coil","rect":[136,40,1,1],"solid":"low","facing":0,"note":"밧줄 더미 작업 흔적","level":0},
    {"kind":"water_gauge","rect":[140,40,1,1],"solid":"low","facing":0,"note":"수위표 작업 흔적","level":0},
    {"kind":"bare_tree","rect":[3,32,1,1],"solid":"tree","facing":0,"note":"길가 마른 나무","level":0},
    {"kind":"bare_tree","rect":[3,39,1,1],"solid":"tree","facing":0,"note":"길가 마른 나무","level":0},
    {"kind":"bare_tree","rect":[3,46,1,1],"solid":"tree","facing":0,"note":"길가 마른 나무","level":0},
    {"kind":"bare_tree","rect":[3,53,1,1],"solid":"tree","facing":0,"note":"길가 마른 나무","level":0},
    {"kind":"bare_tree","rect":[3,60,1,1],"solid":"tree","facing":0,"note":"길가 마른 나무","level":0},
    {"kind":"bare_tree","rect":[3,67,1,1],"solid":"tree","facing":0,"note":"길가 마른 나무","level":0},
    {"kind":"bare_tree","rect":[3,74,1,1],"solid":"tree","facing":0,"note":"길가 마른 나무","level":0},
    {"kind":"bare_tree","rect":[3,81,1,1],"solid":"tree","facing":0,"note":"길가 마른 나무","level":0},
    {"kind":"bare_tree","rect":[3,88,1,1],"solid":"tree","facing":0,"note":"길가 마른 나무","level":0},
    {"kind":"bare_tree","rect":[93,33,1,1],"solid":"tree","facing":0,"note":"길가 마른 나무","level":0},
    {"kind":"bare_tree","rect":[93,40,1,1],"solid":"tree","facing":0,"note":"길가 마른 나무","level":0},
    {"kind":"bare_tree","rect":[93,47,1,1],"solid":"tree","facing":0,"note":"길가 마른 나무","level":0},
    {"kind":"bare_tree","rect":[93,54,1,1],"solid":"tree","facing":0,"note":"길가 마른 나무","level":0},
    {"kind":"bare_tree","rect":[93,61,1,1],"solid":"tree","facing":0,"note":"길가 마른 나무","level":0},
    {"kind":"bare_tree","rect":[93,68,1,1],"solid":"tree","facing":0,"note":"길가 마른 나무","level":0},
    {"kind":"bare_tree","rect":[93,75,1,1],"solid":"tree","facing":0,"note":"길가 마른 나무","level":0},
    {"kind":"bare_tree","rect":[93,82,1,1],"solid":"tree","facing":0,"note":"길가 마른 나무","level":0},
    {"kind":"bare_tree","rect":[93,89,1,1],"solid":"tree","facing":0,"note":"길가 마른 나무","level":0},
    {"kind":"bare_tree","rect":[93,96,1,1],"solid":"tree","facing":0,"note":"길가 마른 나무","level":0},
    {"kind":"bare_tree","rect":[44,53,1,1],"solid":"tree","facing":0,"note":"길가 마른 나무","level":0},
    {"kind":"bare_tree","rect":[44,58,1,1],"solid":"tree","facing":0,"note":"길가 마른 나무","level":0},
    {"kind":"bare_tree","rect":[44,63,1,1],"solid":"tree","facing":0,"note":"길가 마른 나무","level":0},
    {"kind":"bare_tree","rect":[44,68,1,1],"solid":"tree","facing":0,"note":"길가 마른 나무","level":0},
    {"kind":"bare_tree","rect":[44,73,1,1],"solid":"tree","facing":0,"note":"길가 마른 나무","level":0},
    {"kind":"bare_tree","rect":[44,78,1,1],"solid":"tree","facing":0,"note":"길가 마른 나무","level":0},
    {"kind":"bare_tree","rect":[44,83,1,1],"solid":"tree","facing":0,"note":"길가 마른 나무","level":0},
    {"kind":"bare_tree","rect":[44,88,1,1],"solid":"tree","facing":0,"note":"길가 마른 나무","level":0},
    {"kind":"bare_tree","rect":[44,93,1,1],"solid":"tree","facing":0,"note":"길가 마른 나무","level":0},
    {"kind":"bare_tree","rect":[73,80,1,1],"solid":"tree","facing":0,"note":"길가 마른 나무","level":0},
    {"kind":"bare_tree","rect":[73,85,1,1],"solid":"tree","facing":0,"note":"길가 마른 나무","level":0},
    {"kind":"bare_tree","rect":[73,90,1,1],"solid":"tree","facing":0,"note":"길가 마른 나무","level":0}
  ],
  "containers": [
    {"id":"box_1","name":"강변 창고 가 사무실 상자","cell":[114,65],"building":0,"search":5,"items":["food_pack","food_pack"],"locked":false,"level":0,"searched":false},
    {"id":"box_2","name":"강변 창고 가 선별실 상자","cell":[120,65],"building":0,"search":5,"items":["food_pack","food_pack"],"locked":false,"level":0,"searched":false},
    {"id":"box_3","name":"강변 창고 가 선반 칸 상자","cell":[126,65],"building":0,"search":5,"items":["food_pack","document"],"locked":false,"level":0,"searched":false},
    {"id":"box_4","name":"강변 창고 가 계량실 상자","cell":[132,65],"building":0,"search":5,"items":["food_pack","food_pack"],"locked":false,"level":0,"searched":false},
    {"id":"box_5","name":"강변 창고 가 안쪽 창고 상자","cell":[138,65],"building":0,"search":5,"items":["food_pack","food_pack"],"locked":false,"level":0,"searched":false},
    {"id":"box_6","name":"강변 창고 가 사무실 상자","cell":[114,79],"building":0,"search":5,"items":["food_pack","document"],"locked":false,"level":0,"searched":false},
    {"id":"box_7","name":"강변 창고 가 선별실 상자","cell":[120,79],"building":0,"search":5,"items":["food_pack","food_pack"],"locked":false,"level":0,"searched":false},
    {"id":"box_8","name":"강변 창고 가 선반 칸 상자","cell":[126,79],"building":0,"search":5,"items":["food_pack","food_pack"],"locked":false,"level":0,"searched":false},
    {"id":"box_9","name":"강변 창고 가 계량실 상자","cell":[132,79],"building":0,"search":5,"items":["food_pack","document"],"locked":false,"level":0,"searched":false},
    {"id":"box_10","name":"강변 창고 가 안쪽 창고 상자","cell":[138,79],"building":0,"search":5,"items":["food_pack","food_pack"],"locked":false,"level":0,"searched":false},
    {"id":"box_11","name":"강변 창고 가 사무실 상자","cell":[114,65],"building":0,"search":5,"items":["food_pack","food_pack"],"locked":false,"level":1,"searched":false},
    {"id":"box_12","name":"강변 창고 가 선별실 상자","cell":[120,65],"building":0,"search":5,"items":["food_pack","document"],"locked":false,"level":1,"searched":false},
    {"id":"box_13","name":"강변 창고 가 선반 칸 상자","cell":[126,65],"building":0,"search":5,"items":["food_pack","food_pack"],"locked":false,"level":1,"searched":false},
    {"id":"box_14","name":"강변 창고 가 계량실 상자","cell":[132,65],"building":0,"search":5,"items":["food_pack","food_pack"],"locked":false,"level":1,"searched":false},
    {"id":"box_15","name":"강변 창고 가 안쪽 창고 상자","cell":[138,65],"building":0,"search":5,"items":["food_pack","document"],"locked":false,"level":1,"searched":false},
    {"id":"box_16","name":"강변 창고 가 사무실 상자","cell":[114,79],"building":0,"search":5,"items":["food_pack","food_pack"],"locked":false,"level":1,"searched":false},
    {"id":"box_17","name":"강변 창고 가 선별실 상자","cell":[120,79],"building":0,"search":5,"items":["food_pack","food_pack"],"locked":false,"level":1,"searched":false},
    {"id":"box_18","name":"강변 창고 가 선반 칸 상자","cell":[126,79],"building":0,"search":5,"items":["food_pack","document"],"locked":false,"level":1,"searched":false},
    {"id":"box_19","name":"강변 창고 가 계량실 상자","cell":[132,79],"building":0,"search":5,"items":["food_pack","food_pack"],"locked":false,"level":1,"searched":false},
    {"id":"box_20","name":"강변 창고 가 안쪽 창고 상자","cell":[138,79],"building":0,"search":5,"items":["food_pack","food_pack"],"locked":false,"level":1,"searched":false},
    {"id":"box_21","name":"강변 창고 가 사무실 상자","cell":[114,65],"building":0,"search":5,"items":["food_pack","document"],"locked":false,"level":2,"searched":false},
    {"id":"box_22","name":"강변 창고 가 선별실 상자","cell":[120,65],"building":0,"search":5,"items":["food_pack","food_pack"],"locked":false,"level":2,"searched":false},
    {"id":"box_23","name":"강변 창고 가 선반 칸 상자","cell":[126,65],"building":0,"search":5,"items":["food_pack","food_pack"],"locked":false,"level":2,"searched":false},
    {"id":"box_24","name":"강변 창고 가 계량실 상자","cell":[132,65],"building":0,"search":5,"items":["food_pack","document"],"locked":false,"level":2,"searched":false},
    {"id":"box_25","name":"강변 창고 가 안쪽 창고 상자","cell":[138,65],"building":0,"search":5,"items":["food_pack","food_pack"],"locked":false,"level":2,"searched":false},
    {"id":"box_26","name":"강변 창고 가 사무실 상자","cell":[114,79],"building":0,"search":5,"items":["food_pack","food_pack"],"locked":false,"level":2,"searched":false},
    {"id":"box_27","name":"강변 창고 가 선별실 상자","cell":[120,79],"building":0,"search":5,"items":["food_pack","document"],"locked":false,"level":2,"searched":false},
    {"id":"box_28","name":"강변 창고 가 선반 칸 상자","cell":[126,79],"building":0,"search":5,"items":["food_pack","food_pack"],"locked":false,"level":2,"searched":false},
    {"id":"box_29","name":"강변 창고 가 계량실 상자","cell":[132,79],"building":0,"search":5,"items":["food_pack","food_pack"],"locked":false,"level":2,"searched":false},
    {"id":"box_30","name":"강변 창고 가 안쪽 창고 상자","cell":[138,79],"building":0,"search":5,"items":["food_pack","document"],"locked":false,"level":2,"searched":false},
    {"id":"box_31","name":"강변 창고 가 저장고 상자","cell":[114,65],"building":0,"search":5,"items":["food_pack","food_pack"],"locked":false,"level":-1,"searched":false},
    {"id":"box_32","name":"강변 창고 가 냉기 칸 상자","cell":[120,65],"building":0,"search":5,"items":["food_pack","food_pack"],"locked":false,"level":-1,"searched":false},
    {"id":"box_33","name":"강변 창고 가 안쪽 보관실 상자","cell":[126,65],"building":0,"search":5,"items":["food_pack","document"],"locked":false,"level":-1,"searched":false},
    {"id":"box_34","name":"강변 창고 가 저장고 상자","cell":[132,65],"building":0,"search":5,"items":["food_pack","food_pack"],"locked":false,"level":-1,"searched":false},
    {"id":"box_35","name":"강변 창고 가 냉기 칸 상자","cell":[138,65],"building":0,"search":5,"items":["food_pack","food_pack"],"locked":false,"level":-1,"searched":false},
    {"id":"box_36","name":"강변 창고 가 저장고 상자","cell":[114,79],"building":0,"search":5,"items":["food_pack","document"],"locked":false,"level":-1,"searched":false},
    {"id":"box_37","name":"강변 창고 가 냉기 칸 상자","cell":[120,79],"building":0,"search":5,"items":["food_pack","food_pack"],"locked":false,"level":-1,"searched":false},
    {"id":"box_38","name":"강변 창고 가 안쪽 보관실 상자","cell":[126,79],"building":0,"search":5,"items":["food_pack","food_pack"],"locked":false,"level":-1,"searched":false},
    {"id":"box_39","name":"강변 창고 가 저장고 상자","cell":[132,79],"building":0,"search":5,"items":["food_pack","document"],"locked":false,"level":-1,"searched":false},
    {"id":"box_40","name":"강변 창고 가 냉기 칸 상자","cell":[138,79],"building":0,"search":5,"items":["food_pack","food_pack"],"locked":false,"level":-1,"searched":false},
    {"id":"box_41","name":"강변 창고 나 사무실 상자","cell":[124,18],"building":1,"search":5,"items":["food_pack","food_pack"],"locked":false,"level":0,"searched":false},
    {"id":"box_42","name":"강변 창고 나 선별실 상자","cell":[138,18],"building":1,"search":5,"items":["food_pack","document"],"locked":false,"level":0,"searched":false},
    {"id":"box_43","name":"강변 창고 나 사무실 상자","cell":[124,27],"building":1,"search":5,"items":["food_pack","food_pack"],"locked":false,"level":0,"searched":false},
    {"id":"box_44","name":"강변 창고 나 선별실 상자","cell":[138,27],"building":1,"search":5,"items":["food_pack","food_pack"],"locked":false,"level":0,"searched":false},
    {"id":"box_45","name":"강변 창고 나 사무실 상자","cell":[124,18],"building":1,"search":5,"items":["food_pack","document"],"locked":false,"level":1,"searched":false},
    {"id":"box_46","name":"강변 창고 나 선별실 상자","cell":[138,18],"building":1,"search":5,"items":["food_pack","food_pack"],"locked":false,"level":1,"searched":false},
    {"id":"box_47","name":"강변 창고 나 사무실 상자","cell":[124,27],"building":1,"search":5,"items":["food_pack","food_pack"],"locked":false,"level":1,"searched":false},
    {"id":"box_48","name":"강변 창고 나 선별실 상자","cell":[138,27],"building":1,"search":5,"items":["food_pack","document"],"locked":false,"level":1,"searched":false},
    {"id":"box_49","name":"강변 창고 다 사무실 상자","cell":[118,39],"building":2,"search":5,"items":["food_pack","food_pack"],"locked":false,"level":0,"searched":false},
    {"id":"box_50","name":"강변 창고 다 선별실 상자","cell":[130,39],"building":2,"search":5,"items":["food_pack","food_pack"],"locked":false,"level":0,"searched":false},
    {"id":"box_51","name":"강변 창고 다 사무실 상자","cell":[118,49],"building":2,"search":5,"items":["food_pack","document"],"locked":false,"level":0,"searched":false},
    {"id":"box_52","name":"강변 창고 다 선별실 상자","cell":[130,49],"building":2,"search":5,"items":["food_pack","food_pack"],"locked":false,"level":0,"searched":false},
    {"id":"box_53","name":"강변 창고 다 사무실 상자","cell":[118,39],"building":2,"search":5,"items":["food_pack","food_pack"],"locked":false,"level":1,"searched":false},
    {"id":"box_54","name":"강변 창고 다 선별실 상자","cell":[130,39],"building":2,"search":5,"items":["food_pack","document"],"locked":false,"level":1,"searched":false},
    {"id":"box_55","name":"강변 창고 다 사무실 상자","cell":[118,49],"building":2,"search":5,"items":["food_pack","food_pack"],"locked":false,"level":1,"searched":false},
    {"id":"box_56","name":"강변 창고 다 선별실 상자","cell":[130,49],"building":2,"search":5,"items":["food_pack","food_pack"],"locked":false,"level":1,"searched":false},
    {"id":"box_57","name":"강변 창고 라 앞방 상자","cell":[126,97],"building":3,"search":5,"items":["food_pack","document"],"locked":false,"level":0,"searched":false},
    {"id":"box_58","name":"강변 창고 라 안쪽 방 상자","cell":[138,97],"building":3,"search":5,"items":["food_pack","food_pack"],"locked":false,"level":0,"searched":false},
    {"id":"box_59","name":"강변 창고 라 앞방 상자","cell":[126,97],"building":3,"search":5,"items":["food_pack","food_pack"],"locked":false,"level":1,"searched":false},
    {"id":"box_60","name":"강변 창고 라 안쪽 방 상자","cell":[138,97],"building":3,"search":5,"items":["food_pack","document"],"locked":false,"level":1,"searched":false},
    {"id":"box_61","name":"역사 앞방 상자","cell":[21,23],"building":4,"search":5,"items":["food_pack","food_pack"],"locked":false,"level":0,"searched":false},
    {"id":"box_62","name":"역사 안쪽 방 상자","cell":[32,23],"building":4,"search":5,"items":["food_pack","food_pack"],"locked":false,"level":0,"searched":false},
    {"id":"box_63","name":"역사 앞방 상자","cell":[21,23],"building":4,"search":5,"items":["food_pack","document"],"locked":false,"level":1,"searched":false},
    {"id":"box_64","name":"역사 안쪽 방 상자","cell":[32,23],"building":4,"search":5,"items":["food_pack","food_pack"],"locked":false,"level":1,"searched":false},
    {"id":"box_65","name":"화물 사무소 앞방 상자","cell":[65,20],"building":5,"search":5,"items":["food_pack","food_pack"],"locked":false,"level":0,"searched":false},
    {"id":"box_66","name":"화물 사무소 안쪽 방 상자","cell":[71,20],"building":5,"search":5,"items":["food_pack","document"],"locked":false,"level":0,"searched":false},
    {"id":"box_67","name":"소화물 창고 앞방 상자","cell":[87,22],"building":6,"search":5,"items":["food_pack","food_pack"],"locked":false,"level":0,"searched":false},
    {"id":"box_68","name":"소화물 창고 안쪽 방 상자","cell":[95,22],"building":6,"search":5,"items":["food_pack","food_pack"],"locked":false,"level":0,"searched":false},
    {"id":"box_69","name":"신호 취급소 작업실 상자","cell":[108,13],"building":7,"search":5,"items":["food_pack","document"],"locked":false,"level":0,"searched":false},
    {"id":"box_70","name":"신호 취급소 작업실 상자","cell":[108,13],"building":7,"search":5,"items":["food_pack","food_pack"],"locked":false,"level":1,"searched":false},
    {"id":"box_71","name":"식료품점 매장 상자","cell":[52,16],"building":8,"search":5,"items":["food_pack","food_pack"],"locked":false,"level":0,"searched":false},
    {"id":"box_72","name":"식료품점 뒤 창고 상자","cell":[52,20],"building":8,"search":5,"items":["food_pack","document"],"locked":false,"level":0,"searched":false},
    {"id":"box_73","name":"빵집 매장 상자","cell":[20,36],"building":9,"search":5,"items":["food_pack","food_pack"],"locked":false,"level":0,"searched":false},
    {"id":"box_74","name":"빵집 뒤 창고 상자","cell":[20,40],"building":9,"search":5,"items":["food_pack","food_pack"],"locked":false,"level":0,"searched":false},
    {"id":"box_75","name":"잡화점 매장 상자","cell":[57,36],"building":10,"search":5,"items":["food_pack","document"],"locked":false,"level":0,"searched":false},
    {"id":"box_76","name":"잡화점 뒤 창고 상자","cell":[57,40],"building":10,"search":5,"items":["food_pack","food_pack"],"locked":false,"level":0,"searched":false},
    {"id":"box_77","name":"철도원 주택 가 앞방 상자","cell":[72,40],"building":11,"search":5,"items":["food_pack","food_pack"],"locked":false,"level":0,"searched":false},
    {"id":"box_78","name":"철도원 주택 가 안쪽 방 상자","cell":[77,40],"building":11,"search":5,"items":["food_pack","document"],"locked":false,"level":0,"searched":false},
    {"id":"box_79","name":"철도원 주택 가 앞방 상자","cell":[72,40],"building":11,"search":5,"items":["food_pack","food_pack"],"locked":false,"level":1,"searched":false},
    {"id":"box_80","name":"철도원 주택 가 안쪽 방 상자","cell":[77,40],"building":11,"search":5,"items":["food_pack","food_pack"],"locked":false,"level":1,"searched":false},
    {"id":"box_81","name":"철도원 주택 나 앞방 상자","cell":[13,66],"building":12,"search":5,"items":["food_pack","document"],"locked":false,"level":0,"searched":false},
    {"id":"box_82","name":"철도원 주택 나 안쪽 방 상자","cell":[18,66],"building":12,"search":5,"items":["food_pack","food_pack"],"locked":false,"level":0,"searched":false},
    {"id":"box_83","name":"철도원 주택 나 앞방 상자","cell":[13,66],"building":12,"search":5,"items":["food_pack","food_pack"],"locked":false,"level":1,"searched":false},
    {"id":"box_84","name":"철도원 주택 나 안쪽 방 상자","cell":[18,66],"building":12,"search":5,"items":["food_pack","document"],"locked":false,"level":1,"searched":false},
    {"id":"box_85","name":"철도원 주택 다 앞방 상자","cell":[51,68],"building":13,"search":5,"items":["food_pack","food_pack"],"locked":false,"level":0,"searched":false},
    {"id":"box_86","name":"철도원 주택 다 안쪽 방 상자","cell":[56,68],"building":13,"search":5,"items":["food_pack","food_pack"],"locked":false,"level":0,"searched":false},
    {"id":"box_87","name":"모래 창고 작업실 상자","cell":[90,66],"building":14,"search":5,"items":["food_pack","document"],"locked":false,"level":0,"searched":false},
    {"id":"box_88","name":"곡물 건조 창고 앞방 상자","cell":[18,87],"building":15,"search":5,"items":["food_pack","food_pack"],"locked":false,"level":0,"searched":false},
    {"id":"box_89","name":"곡물 건조 창고 안쪽 방 상자","cell":[28,87],"building":15,"search":5,"items":["food_pack","food_pack"],"locked":false,"level":0,"searched":false},
    {"id":"box_90","name":"공구 창고 앞방 상자","cell":[62,86],"building":16,"search":5,"items":["food_pack","document"],"locked":false,"level":0,"searched":false},
    {"id":"box_91","name":"공구 창고 안쪽 방 상자","cell":[67,86],"building":16,"search":5,"items":["food_pack","food_pack"],"locked":false,"level":0,"searched":false},
    {"id":"box_92","name":"계량소 작업실 상자","cell":[88,92],"building":17,"search":5,"items":["food_pack","food_pack"],"locked":false,"level":0,"searched":false},
    {"id":"box_platform","name":"승강장 보급 상자","cell":[38,8],"building":-1,"search":4,"items":["food_pack","food_pack"],"locked":false,"level":0,"searched":false}
  ],
  "wagons": [],
  "entries": [
    ["west_track",[[0,1],[0,2],[0,3]],0.6],
    ["west_road",[[0,52],[0,53],[0,54],[0,55]],0.6],
    ["south_lane",[[36,99],[37,99],[38,99],[39,99]],2.5],
    ["south_bank",[[100,99],[101,99],[102,99],[103,99]],0.6]
  ],
  "holes": [
    ["manhole_01",[38,50],"큰길 꺾임 맨홀"],
    ["manhole_02",[101,70],"둑길 맨홀"],
    ["culvert_01",[60,90],"남쪽 둑 밑 암거",[0,-1]]
  ],
  "barricades": [
    [35,13],
    [37,13],
    [39,13],
    [55,15],
    [57,15],
    [74,15],
    [77,15]
  ],
  "dead": [
    [38,60],
    [70,51],
    [103,83],
    [31,74],
    [106,54]
  ],
  "deep": [
    ["F","강변 창고 가"],
    ["G","곡물 건조 창고"]
  ],
  "assumptions": ["강 위 선로와 맨 위 눈 한 줄은 공통 철도 계약을 따른다.","창고 이름의 글자는 한국어 가·나·다·라로 바꿨다. 강변에는 외부 발생점을 두지 않았다."],
  "salvage": [
    ["salvage_1","버려진 차",[40,56],"scrap"],
    ["salvage_2","버려진 차",[86,78],"scrap"],
    ["salvage_3","강변 창고 가 사무실 부품 상자",[111,65],"scrap"],
    ["salvage_4","강변 창고 가 선별실 부품 상자",[117,65],"scrap"],
    ["salvage_5","강변 창고 가 선반 칸 부품 상자",[123,65],"scrap"],
    ["salvage_6","강변 창고 가 계량실 부품 상자",[129,65],"scrap"]
  ],
  "work_site": {}
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
		data["spots"]["work_site"] = {"kind": "work_site", "cell": _cell(work["cell"]), "name": "식량 하역 구역", "state": "closed", "zone_rect": _rect(work["rect"])}
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
    "267": {
      "kind": "bare_tree",
      "rect": [
        4,
        46,
        1,
        1
      ],
      "solid": "tree",
      "facing": 0,
      "note": "길가 마른 나무",
      "level": 0
    },
    "268": {
      "kind": "bare_tree",
      "rect": [
        7,
        47,
        1,
        1
      ],
      "solid": "tree",
      "facing": 0,
      "note": "길가 마른 나무",
      "level": 0
    },
    "269": {
      "kind": "bare_tree",
      "rect": [
        2,
        49,
        1,
        1
      ],
      "solid": "tree",
      "facing": 0,
      "note": "길가 마른 나무",
      "level": 0
    },
    "270": {
      "kind": "bare_tree",
      "rect": [
        6,
        51,
        1,
        1
      ],
      "solid": "tree",
      "facing": 0,
      "note": "길가 마른 나무",
      "level": 0
    },
    "271": {
      "kind": "bare_tree",
      "rect": [
        1,
        52,
        1,
        1
      ],
      "solid": "tree",
      "facing": 0,
      "note": "길가 마른 나무",
      "level": 0
    },
    "272": {
      "kind": "bare_tree",
      "rect": [
        21,
        69,
        1,
        1
      ],
      "solid": "tree",
      "facing": 0,
      "note": "길가 마른 나무",
      "level": 0
    },
    "273": {
      "kind": "bare_tree",
      "rect": [
        24,
        70,
        1,
        1
      ],
      "solid": "tree",
      "facing": 0,
      "note": "길가 마른 나무",
      "level": 0
    },
    "274": {
      "kind": "bare_tree",
      "rect": [
        19,
        72,
        1,
        1
      ],
      "solid": "tree",
      "facing": 0,
      "note": "길가 마른 나무",
      "level": 0
    },
    "275": {
      "kind": "bare_tree",
      "rect": [
        23,
        74,
        1,
        1
      ],
      "solid": "tree",
      "facing": 0,
      "note": "길가 마른 나무",
      "level": 0
    },
    "276": {
      "kind": "bare_tree",
      "rect": [
        18,
        74,
        1,
        1
      ],
      "solid": "tree",
      "facing": 0,
      "note": "길가 마른 나무",
      "level": 0
    },
    "277": {
      "kind": "bare_tree",
      "rect": [
        93,
        54,
        1,
        1
      ],
      "solid": "tree",
      "facing": 0,
      "note": "길가 마른 나무",
      "level": 0
    },
    "278": {
      "kind": "bare_tree",
      "rect": [
        96,
        55,
        1,
        1
      ],
      "solid": "tree",
      "facing": 0,
      "note": "길가 마른 나무",
      "level": 0
    },
    "279": {
      "kind": "bare_tree",
      "rect": [
        91,
        57,
        1,
        1
      ],
      "solid": "tree",
      "facing": 0,
      "note": "길가 마른 나무",
      "level": 0
    },
    "280": {
      "kind": "bare_tree",
      "rect": [
        95,
        59,
        1,
        1
      ],
      "solid": "tree",
      "facing": 0,
      "note": "길가 마른 나무",
      "level": 0
    },
    "281": {
      "kind": "bare_tree",
      "rect": [
        90,
        59,
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
        83,
        79,
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
        86,
        80,
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
        81,
        82,
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
        85,
        84,
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
        80,
        85,
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
        44,
        68,
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
        46,
        69,
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
        42,
        71,
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
        46,
        73,
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
        41,
        74,
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
        56,
        86,
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
        59,
        88,
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
        54,
        89,
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
        58,
        91,
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
        53,
        92,
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
        73,
        90,
        1,
        1
      ],
      "solid": "tree",
      "facing": 0,
      "note": "길가 마른 나무",
      "level": 0
    }
  },
  "remove": [],
  "append": [],
  "work_site": {
    "cell": [
      138,
      30
    ],
    "rect": [
      138,
      30,
      7,
      33
    ]
  },
  "changed": [
    [
      3,
      32,
      1,
      1
    ],
    [
      4,
      46,
      1,
      1
    ],
    [
      3,
      39,
      1,
      1
    ],
    [
      7,
      47,
      1,
      1
    ],
    [
      3,
      46,
      1,
      1
    ],
    [
      2,
      49,
      1,
      1
    ],
    [
      3,
      53,
      1,
      1
    ],
    [
      6,
      51,
      1,
      1
    ],
    [
      3,
      60,
      1,
      1
    ],
    [
      1,
      52,
      1,
      1
    ],
    [
      3,
      67,
      1,
      1
    ],
    [
      21,
      69,
      1,
      1
    ],
    [
      3,
      74,
      1,
      1
    ],
    [
      24,
      70,
      1,
      1
    ],
    [
      3,
      81,
      1,
      1
    ],
    [
      19,
      72,
      1,
      1
    ],
    [
      3,
      88,
      1,
      1
    ],
    [
      23,
      74,
      1,
      1
    ],
    [
      93,
      33,
      1,
      1
    ],
    [
      18,
      74,
      1,
      1
    ],
    [
      93,
      40,
      1,
      1
    ],
    [
      93,
      54,
      1,
      1
    ],
    [
      93,
      47,
      1,
      1
    ],
    [
      96,
      55,
      1,
      1
    ],
    [
      93,
      54,
      1,
      1
    ],
    [
      91,
      57,
      1,
      1
    ],
    [
      93,
      61,
      1,
      1
    ],
    [
      95,
      59,
      1,
      1
    ],
    [
      93,
      68,
      1,
      1
    ],
    [
      90,
      59,
      1,
      1
    ],
    [
      93,
      75,
      1,
      1
    ],
    [
      83,
      79,
      1,
      1
    ],
    [
      93,
      82,
      1,
      1
    ],
    [
      86,
      80,
      1,
      1
    ],
    [
      93,
      89,
      1,
      1
    ],
    [
      81,
      82,
      1,
      1
    ],
    [
      93,
      96,
      1,
      1
    ],
    [
      85,
      84,
      1,
      1
    ],
    [
      44,
      53,
      1,
      1
    ],
    [
      80,
      85,
      1,
      1
    ],
    [
      44,
      58,
      1,
      1
    ],
    [
      44,
      68,
      1,
      1
    ],
    [
      44,
      63,
      1,
      1
    ],
    [
      46,
      69,
      1,
      1
    ],
    [
      44,
      68,
      1,
      1
    ],
    [
      42,
      71,
      1,
      1
    ],
    [
      44,
      73,
      1,
      1
    ],
    [
      46,
      73,
      1,
      1
    ],
    [
      44,
      78,
      1,
      1
    ],
    [
      41,
      74,
      1,
      1
    ],
    [
      44,
      83,
      1,
      1
    ],
    [
      56,
      86,
      1,
      1
    ],
    [
      44,
      88,
      1,
      1
    ],
    [
      59,
      88,
      1,
      1
    ],
    [
      44,
      93,
      1,
      1
    ],
    [
      54,
      89,
      1,
      1
    ],
    [
      73,
      80,
      1,
      1
    ],
    [
      58,
      91,
      1,
      1
    ],
    [
      73,
      85,
      1,
      1
    ],
    [
      53,
      92,
      1,
      1
    ],
    [
      73,
      90,
      1,
      1
    ],
    [
      73,
      90,
      1,
      1
    ]
  ]
}

const NORTH_PLAN: Dictionary = {
  "id": "freight_04",
  "size": [
    175,
    145
  ],
  "offset": 18,
  "judgment": "가볍고 값진 약 상자를 얻는 대신, 둑 창고 깊은 곳은 둑길 하나로만 돌아올 수 있어 한 번 들어가면 나오는 길이 좁다.",
  "zones": [
    [
      "I",
      "서쪽 붕대 구획",
      [
        0,
        0,
        40,
        46
      ]
    ],
    [
      "J",
      "가운데 선별 구획",
      [
        40,
        0,
        76,
        46
      ]
    ],
    [
      "K",
      "동쪽 둑 구획",
      [
        116,
        0,
        59,
        46
      ]
    ]
  ],
  "floors": [
    [
      0,
      0,
      0,
      175,
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
      59,
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
      4,
      140,
      5,
      1
    ],
    [
      0,
      140,
      0,
      5,
      46,
      1
    ],
    [
      0,
      36,
      9,
      4,
      34,
      1
    ],
    [
      0,
      82,
      9,
      5,
      34,
      1
    ],
    [
      0,
      20,
      0,
      4,
      9,
      1
    ],
    [
      0,
      14,
      12,
      4,
      31,
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
      49,
      6,
      1
    ],
    [
      0,
      140,
      24,
      5,
      5,
      7
    ]
  ],
  "buildings": [
    {
      "id": 18,
      "name": "수레 차고",
      "rect": [
        0,
        12,
        14,
        12
      ],
      "warm": false,
      "window_broken": false
    },
    {
      "id": 19,
      "name": "붕대와 솜 창고",
      "rect": [
        18,
        9,
        18,
        15
      ],
      "warm": false,
      "window_broken": false
    },
    {
      "id": 20,
      "name": "선별 창고",
      "rect": [
        40,
        10,
        42,
        14
      ],
      "warm": false,
      "window_broken": false
    },
    {
      "id": 21,
      "name": "냉장 약품 창고",
      "rect": [
        87,
        10,
        19,
        14
      ],
      "warm": false,
      "window_broken": false
    },
    {
      "id": 22,
      "name": "약품 계량소",
      "rect": [
        106,
        17,
        10,
        7
      ],
      "warm": false,
      "window_broken": false
    },
    {
      "id": 23,
      "name": "구급 사무소",
      "rect": [
        116,
        12,
        10,
        8
      ],
      "warm": false,
      "window_broken": false
    },
    {
      "id": 24,
      "name": "둑 창고",
      "rect": [
        128,
        10,
        12,
        32
      ],
      "warm": false,
      "window_broken": false
    }
  ],
  "shells": [
    [
      18,
      0,
      0,
      12,
      14,
      12
    ],
    [
      19,
      0,
      18,
      9,
      18,
      15
    ],
    [
      19,
      1,
      18,
      9,
      18,
      15
    ],
    [
      20,
      -1,
      40,
      10,
      42,
      14
    ],
    [
      20,
      0,
      40,
      10,
      42,
      14
    ],
    [
      20,
      1,
      40,
      10,
      42,
      14
    ],
    [
      20,
      2,
      40,
      10,
      42,
      14
    ],
    [
      21,
      -1,
      87,
      10,
      19,
      14
    ],
    [
      21,
      0,
      87,
      10,
      19,
      14
    ],
    [
      21,
      1,
      87,
      10,
      19,
      14
    ],
    [
      22,
      0,
      106,
      17,
      10,
      7
    ],
    [
      23,
      0,
      116,
      12,
      10,
      8
    ],
    [
      24,
      -1,
      128,
      10,
      12,
      32
    ],
    [
      24,
      0,
      128,
      10,
      12,
      32
    ],
    [
      24,
      1,
      128,
      10,
      12,
      32
    ]
  ],
  "walls": [
    [
      0,
      7,
      13,
      1,
      10
    ],
    [
      0,
      27,
      10,
      1,
      13
    ],
    [
      1,
      27,
      10,
      1,
      13
    ],
    [
      -1,
      41,
      14,
      40,
      1
    ],
    [
      -1,
      41,
      17,
      40,
      1
    ],
    [
      -1,
      53,
      11,
      1,
      3
    ],
    [
      -1,
      67,
      11,
      1,
      3
    ],
    [
      -1,
      53,
      18,
      1,
      5
    ],
    [
      -1,
      67,
      18,
      1,
      5
    ],
    [
      0,
      41,
      14,
      40,
      1
    ],
    [
      0,
      41,
      17,
      40,
      1
    ],
    [
      0,
      53,
      11,
      1,
      3
    ],
    [
      0,
      67,
      11,
      1,
      3
    ],
    [
      0,
      53,
      18,
      1,
      5
    ],
    [
      0,
      67,
      18,
      1,
      5
    ],
    [
      1,
      41,
      14,
      40,
      1
    ],
    [
      1,
      41,
      17,
      40,
      1
    ],
    [
      1,
      53,
      11,
      1,
      3
    ],
    [
      1,
      67,
      11,
      1,
      3
    ],
    [
      1,
      53,
      18,
      1,
      5
    ],
    [
      1,
      67,
      18,
      1,
      5
    ],
    [
      2,
      41,
      14,
      40,
      1
    ],
    [
      2,
      41,
      17,
      40,
      1
    ],
    [
      2,
      53,
      11,
      1,
      3
    ],
    [
      2,
      67,
      11,
      1,
      3
    ],
    [
      2,
      53,
      18,
      1,
      5
    ],
    [
      2,
      67,
      18,
      1,
      5
    ],
    [
      -1,
      96,
      11,
      1,
      12
    ],
    [
      0,
      96,
      11,
      1,
      12
    ],
    [
      1,
      96,
      11,
      1,
      12
    ],
    [
      -1,
      129,
      13,
      10,
      1
    ],
    [
      -1,
      133,
      14,
      1,
      27
    ],
    [
      0,
      134,
      11,
      1,
      30
    ],
    [
      1,
      134,
      11,
      1,
      30
    ]
  ],
  "openings": [
    [
      0,
      20,
      16,
      1,
      2
    ],
    [
      1,
      20,
      16,
      1,
      2
    ],
    [
      -1,
      42,
      15,
      1,
      2
    ],
    [
      0,
      42,
      15,
      1,
      2
    ],
    [
      0,
      42,
      15,
      1,
      2
    ],
    [
      1,
      42,
      15,
      1,
      2
    ],
    [
      1,
      42,
      15,
      1,
      2
    ],
    [
      2,
      42,
      15,
      1,
      2
    ],
    [
      -1,
      79,
      15,
      1,
      2
    ],
    [
      0,
      79,
      15,
      1,
      2
    ],
    [
      0,
      79,
      15,
      1,
      2
    ],
    [
      1,
      79,
      15,
      1,
      2
    ],
    [
      1,
      79,
      15,
      1,
      2
    ],
    [
      2,
      79,
      15,
      1,
      2
    ],
    [
      -1,
      89,
      17,
      1,
      2
    ],
    [
      0,
      89,
      17,
      1,
      2
    ],
    [
      0,
      89,
      17,
      1,
      2
    ],
    [
      1,
      89,
      17,
      1,
      2
    ],
    [
      -1,
      130,
      11,
      1,
      17
    ],
    [
      0,
      130,
      26,
      1,
      2
    ],
    [
      0,
      130,
      26,
      1,
      2
    ],
    [
      1,
      130,
      26,
      1,
      2
    ]
  ],
  "doors": [
    [
      0,
      7,
      18,
      18,
      "closed",
      1,
      0
    ],
    [
      0,
      4,
      12,
      18,
      "closed",
      0,
      1
    ],
    [
      0,
      27,
      16,
      19,
      "closed",
      1,
      0
    ],
    [
      1,
      27,
      16,
      19,
      "closed",
      1,
      0
    ],
    [
      0,
      23,
      9,
      19,
      "closed",
      0,
      1
    ],
    [
      -1,
      47,
      14,
      20,
      "closed",
      0,
      1
    ],
    [
      -1,
      60,
      14,
      20,
      "closed",
      0,
      1
    ],
    [
      -1,
      74,
      14,
      20,
      "closed",
      0,
      1
    ],
    [
      -1,
      47,
      17,
      20,
      "closed",
      0,
      1
    ],
    [
      -1,
      60,
      17,
      20,
      "closed",
      0,
      1
    ],
    [
      -1,
      74,
      17,
      20,
      "closed",
      0,
      1
    ],
    [
      0,
      47,
      14,
      20,
      "closed",
      0,
      1
    ],
    [
      0,
      60,
      14,
      20,
      "closed",
      0,
      1
    ],
    [
      0,
      74,
      14,
      20,
      "closed",
      0,
      1
    ],
    [
      0,
      47,
      17,
      20,
      "closed",
      0,
      1
    ],
    [
      0,
      60,
      17,
      20,
      "closed",
      0,
      1
    ],
    [
      0,
      74,
      17,
      20,
      "closed",
      0,
      1
    ],
    [
      1,
      47,
      14,
      20,
      "closed",
      0,
      1
    ],
    [
      1,
      60,
      14,
      20,
      "closed",
      0,
      1
    ],
    [
      1,
      74,
      14,
      20,
      "closed",
      0,
      1
    ],
    [
      1,
      47,
      17,
      20,
      "closed",
      0,
      1
    ],
    [
      1,
      60,
      17,
      20,
      "closed",
      0,
      1
    ],
    [
      1,
      74,
      17,
      20,
      "closed",
      0,
      1
    ],
    [
      2,
      47,
      14,
      20,
      "closed",
      0,
      1
    ],
    [
      2,
      60,
      14,
      20,
      "closed",
      0,
      1
    ],
    [
      2,
      74,
      14,
      20,
      "closed",
      0,
      1
    ],
    [
      2,
      47,
      17,
      20,
      "closed",
      0,
      1
    ],
    [
      2,
      60,
      17,
      20,
      "closed",
      0,
      1
    ],
    [
      2,
      74,
      17,
      20,
      "closed",
      0,
      1
    ],
    [
      0,
      74,
      23,
      20,
      "closed",
      0,
      1
    ],
    [
      -1,
      96,
      17,
      21,
      "closed",
      1,
      0
    ],
    [
      0,
      96,
      17,
      21,
      "closed",
      1,
      0
    ],
    [
      1,
      96,
      17,
      21,
      "closed",
      1,
      0
    ],
    [
      0,
      92,
      10,
      21,
      "closed",
      0,
      1
    ],
    [
      0,
      111,
      17,
      22,
      "closed",
      0,
      1
    ],
    [
      0,
      121,
      12,
      23,
      "closed",
      0,
      1
    ],
    [
      -1,
      131,
      13,
      24,
      "closed",
      0,
      1
    ],
    [
      -1,
      136,
      13,
      24,
      "closed",
      0,
      1
    ],
    [
      0,
      134,
      26,
      24,
      "closed",
      1,
      0
    ],
    [
      1,
      134,
      26,
      24,
      "closed",
      1,
      0
    ],
    [
      0,
      139,
      26,
      24,
      "closed",
      1,
      0
    ]
  ],
  "windows": [
    [
      0,
      3,
      12,
      18
    ],
    [
      0,
      10,
      12,
      18
    ],
    [
      0,
      13,
      15,
      18
    ],
    [
      0,
      13,
      20,
      18
    ],
    [
      0,
      21,
      9,
      19
    ],
    [
      0,
      28,
      9,
      19
    ],
    [
      0,
      35,
      12,
      19
    ],
    [
      0,
      35,
      17,
      19
    ],
    [
      1,
      21,
      9,
      19
    ],
    [
      1,
      28,
      9,
      19
    ],
    [
      1,
      35,
      12,
      19
    ],
    [
      1,
      35,
      17,
      19
    ],
    [
      0,
      43,
      10,
      20
    ],
    [
      0,
      50,
      10,
      20
    ],
    [
      0,
      57,
      10,
      20
    ],
    [
      0,
      64,
      10,
      20
    ],
    [
      0,
      71,
      10,
      20
    ],
    [
      0,
      78,
      10,
      20
    ],
    [
      0,
      81,
      13,
      20
    ],
    [
      0,
      81,
      18,
      20
    ],
    [
      1,
      43,
      10,
      20
    ],
    [
      1,
      50,
      10,
      20
    ],
    [
      1,
      57,
      10,
      20
    ],
    [
      1,
      64,
      10,
      20
    ],
    [
      1,
      71,
      10,
      20
    ],
    [
      1,
      78,
      10,
      20
    ],
    [
      1,
      81,
      13,
      20
    ],
    [
      1,
      81,
      18,
      20
    ],
    [
      2,
      43,
      10,
      20
    ],
    [
      2,
      50,
      10,
      20
    ],
    [
      2,
      57,
      10,
      20
    ],
    [
      2,
      64,
      10,
      20
    ],
    [
      2,
      71,
      10,
      20
    ],
    [
      2,
      78,
      10,
      20
    ],
    [
      2,
      81,
      13,
      20
    ],
    [
      2,
      81,
      18,
      20
    ],
    [
      0,
      90,
      10,
      21
    ],
    [
      0,
      97,
      10,
      21
    ],
    [
      0,
      105,
      13,
      21
    ],
    [
      0,
      105,
      18,
      21
    ],
    [
      1,
      90,
      10,
      21
    ],
    [
      1,
      97,
      10,
      21
    ],
    [
      1,
      105,
      13,
      21
    ],
    [
      1,
      105,
      18,
      21
    ],
    [
      0,
      109,
      17,
      22
    ],
    [
      0,
      115,
      20,
      22
    ],
    [
      0,
      119,
      12,
      23
    ],
    [
      0,
      125,
      15,
      23
    ],
    [
      0,
      131,
      10,
      24
    ],
    [
      0,
      139,
      13,
      24
    ],
    [
      0,
      139,
      18,
      24
    ],
    [
      0,
      139,
      23,
      24
    ],
    [
      0,
      139,
      28,
      24
    ],
    [
      0,
      139,
      33,
      24
    ],
    [
      0,
      139,
      38,
      24
    ],
    [
      1,
      131,
      10,
      24
    ],
    [
      1,
      139,
      13,
      24
    ],
    [
      1,
      139,
      18,
      24
    ],
    [
      1,
      139,
      23,
      24
    ],
    [
      1,
      139,
      28,
      24
    ],
    [
      1,
      139,
      33,
      24
    ],
    [
      1,
      139,
      38,
      24
    ]
  ],
  "rooms": [
    {
      "building": 18,
      "level": 0,
      "rect": [
        1,
        13,
        6,
        10
      ],
      "name": "앞 작업 칸"
    },
    {
      "building": 18,
      "level": 0,
      "rect": [
        8,
        13,
        5,
        10
      ],
      "name": "안쪽 보관실"
    },
    {
      "building": 19,
      "level": 0,
      "rect": [
        19,
        10,
        8,
        13
      ],
      "name": "앞 작업 칸"
    },
    {
      "building": 19,
      "level": 0,
      "rect": [
        28,
        10,
        7,
        13
      ],
      "name": "안쪽 보관실"
    },
    {
      "building": 19,
      "level": 1,
      "rect": [
        19,
        10,
        8,
        13
      ],
      "name": "앞 작업 칸"
    },
    {
      "building": 19,
      "level": 1,
      "rect": [
        28,
        10,
        7,
        13
      ],
      "name": "안쪽 보관실"
    },
    {
      "building": 20,
      "level": -1,
      "rect": [
        41,
        11,
        12,
        3
      ],
      "name": "약품 앞 저장고"
    },
    {
      "building": 20,
      "level": -1,
      "rect": [
        54,
        11,
        13,
        3
      ],
      "name": "약품 안쪽 보관실"
    },
    {
      "building": 20,
      "level": -1,
      "rect": [
        68,
        11,
        13,
        3
      ],
      "name": "약품 앞 저장고"
    },
    {
      "building": 20,
      "level": -1,
      "rect": [
        41,
        18,
        12,
        5
      ],
      "name": "약품 안쪽 보관실"
    },
    {
      "building": 20,
      "level": -1,
      "rect": [
        54,
        18,
        13,
        5
      ],
      "name": "약품 앞 저장고"
    },
    {
      "building": 20,
      "level": -1,
      "rect": [
        68,
        18,
        13,
        5
      ],
      "name": "약품 안쪽 보관실"
    },
    {
      "building": 20,
      "level": 0,
      "rect": [
        41,
        11,
        12,
        3
      ],
      "name": "선별실"
    },
    {
      "building": 20,
      "level": 0,
      "rect": [
        54,
        11,
        13,
        3
      ],
      "name": "원료 칸"
    },
    {
      "building": 20,
      "level": 0,
      "rect": [
        68,
        11,
        13,
        3
      ],
      "name": "가공 칸"
    },
    {
      "building": 20,
      "level": 0,
      "rect": [
        41,
        18,
        12,
        5
      ],
      "name": "계량실"
    },
    {
      "building": 20,
      "level": 0,
      "rect": [
        54,
        18,
        13,
        5
      ],
      "name": "공구 칸"
    },
    {
      "building": 20,
      "level": 0,
      "rect": [
        68,
        18,
        13,
        5
      ],
      "name": "안쪽 보관실"
    },
    {
      "building": 20,
      "level": 1,
      "rect": [
        41,
        11,
        12,
        3
      ],
      "name": "선별실"
    },
    {
      "building": 20,
      "level": 1,
      "rect": [
        54,
        11,
        13,
        3
      ],
      "name": "원료 칸"
    },
    {
      "building": 20,
      "level": 1,
      "rect": [
        68,
        11,
        13,
        3
      ],
      "name": "가공 칸"
    },
    {
      "building": 20,
      "level": 1,
      "rect": [
        41,
        18,
        12,
        5
      ],
      "name": "계량실"
    },
    {
      "building": 20,
      "level": 1,
      "rect": [
        54,
        18,
        13,
        5
      ],
      "name": "공구 칸"
    },
    {
      "building": 20,
      "level": 1,
      "rect": [
        68,
        18,
        13,
        5
      ],
      "name": "안쪽 보관실"
    },
    {
      "building": 20,
      "level": 2,
      "rect": [
        41,
        11,
        12,
        3
      ],
      "name": "선별실"
    },
    {
      "building": 20,
      "level": 2,
      "rect": [
        54,
        11,
        13,
        3
      ],
      "name": "원료 칸"
    },
    {
      "building": 20,
      "level": 2,
      "rect": [
        68,
        11,
        13,
        3
      ],
      "name": "가공 칸"
    },
    {
      "building": 20,
      "level": 2,
      "rect": [
        41,
        18,
        12,
        5
      ],
      "name": "계량실"
    },
    {
      "building": 20,
      "level": 2,
      "rect": [
        54,
        18,
        13,
        5
      ],
      "name": "공구 칸"
    },
    {
      "building": 20,
      "level": 2,
      "rect": [
        68,
        18,
        13,
        5
      ],
      "name": "안쪽 보관실"
    },
    {
      "building": 21,
      "level": -1,
      "rect": [
        88,
        11,
        8,
        12
      ],
      "name": "약품 앞 저장고"
    },
    {
      "building": 21,
      "level": -1,
      "rect": [
        97,
        11,
        8,
        12
      ],
      "name": "약품 안쪽 보관실"
    },
    {
      "building": 21,
      "level": 0,
      "rect": [
        88,
        11,
        8,
        12
      ],
      "name": "앞 작업 칸"
    },
    {
      "building": 21,
      "level": 0,
      "rect": [
        97,
        11,
        8,
        12
      ],
      "name": "안쪽 보관실"
    },
    {
      "building": 21,
      "level": 1,
      "rect": [
        88,
        11,
        8,
        12
      ],
      "name": "앞 작업 칸"
    },
    {
      "building": 21,
      "level": 1,
      "rect": [
        97,
        11,
        8,
        12
      ],
      "name": "안쪽 보관실"
    },
    {
      "building": 22,
      "level": 0,
      "rect": [
        107,
        18,
        8,
        5
      ],
      "name": "작업 칸"
    },
    {
      "building": 23,
      "level": 0,
      "rect": [
        117,
        13,
        8,
        6
      ],
      "name": "작업 칸"
    },
    {
      "building": 24,
      "level": -1,
      "rect": [
        129,
        14,
        4,
        27
      ],
      "name": "약품 앞 저장고"
    },
    {
      "building": 24,
      "level": -1,
      "rect": [
        134,
        14,
        5,
        27
      ],
      "name": "약품 안쪽 보관실"
    },
    {
      "building": 24,
      "level": 0,
      "rect": [
        129,
        11,
        5,
        30
      ],
      "name": "앞 작업 칸"
    },
    {
      "building": 24,
      "level": 0,
      "rect": [
        135,
        11,
        4,
        30
      ],
      "name": "안쪽 보관실"
    },
    {
      "building": 24,
      "level": 1,
      "rect": [
        129,
        11,
        5,
        30
      ],
      "name": "앞 작업 칸"
    },
    {
      "building": 24,
      "level": 1,
      "rect": [
        135,
        11,
        4,
        30
      ],
      "name": "안쪽 보관실"
    }
  ],
  "stairs": [
    {
      "cell": [
        20,
        16
      ],
      "low": 0,
      "high": 1,
      "ladder": false
    },
    {
      "cell": [
        42,
        15
      ],
      "low": -1,
      "high": 0,
      "ladder": false
    },
    {
      "cell": [
        42,
        15
      ],
      "low": 0,
      "high": 1,
      "ladder": false
    },
    {
      "cell": [
        42,
        15
      ],
      "low": 1,
      "high": 2,
      "ladder": false
    },
    {
      "cell": [
        79,
        16
      ],
      "low": -1,
      "high": 0,
      "ladder": false
    },
    {
      "cell": [
        79,
        16
      ],
      "low": 0,
      "high": 1,
      "ladder": false
    },
    {
      "cell": [
        79,
        16
      ],
      "low": 1,
      "high": 2,
      "ladder": false
    },
    {
      "cell": [
        89,
        17
      ],
      "low": -1,
      "high": 0,
      "ladder": false
    },
    {
      "cell": [
        89,
        17
      ],
      "low": 0,
      "high": 1,
      "ladder": false
    },
    {
      "cell": [
        130,
        26
      ],
      "low": -1,
      "high": 0,
      "ladder": false
    },
    {
      "cell": [
        130,
        26
      ],
      "low": 0,
      "high": 1,
      "ladder": false
    }
  ],
  "props": [
    {
      "kind": "sack_pile",
      "rect": [
        31,
        38,
        2,
        2
      ],
      "solid": "low",
      "facing": 0,
      "note": "자루 더미",
      "level": 0
    },
    {
      "kind": "crate_stack",
      "rect": [
        64,
        36,
        2,
        2
      ],
      "solid": "low",
      "facing": 0,
      "note": "나무 상자 더미",
      "level": 0
    },
    {
      "kind": "handcart",
      "rect": [
        100,
        41,
        2,
        1
      ],
      "solid": "low",
      "facing": 0,
      "note": "손수레",
      "level": 0
    },
    {
      "kind": "rail_pile",
      "rect": [
        88,
        30,
        1,
        3
      ],
      "solid": "low",
      "facing": 0,
      "note": "레일 더미",
      "level": 0
    },
    {
      "kind": "water",
      "rect": [
        145,
        0,
        30,
        46
      ],
      "solid": "low",
      "facing": 0,
      "note": "강물",
      "level": 0
    },
    {
      "kind": "bare_tree",
      "rect": [
        3,
        28,
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
        32,
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
        29,
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
        60,
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
        66,
        2,
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
        73,
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
        78,
        2,
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
        116,
        30,
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
        121,
        33,
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
        124,
        38,
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
        118,
        37,
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
        126,
        29,
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
        30,
        1,
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
        1,
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
      "kind": "desk",
      "rect": [
        5,
        13,
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
        1,
        14,
        2,
        1
      ],
      "solid": "low",
      "facing": 0,
      "note": "앞 작업 칸 곁 서류함",
      "level": 0
    },
    {
      "kind": "crate_stack",
      "rect": [
        5,
        14,
        2,
        2
      ],
      "solid": "low",
      "facing": 0,
      "note": "앞 작업 칸 곁 나무 상자 더미",
      "level": 0
    },
    {
      "kind": "pallet_stack",
      "rect": [
        1,
        15,
        2,
        2
      ],
      "solid": "low",
      "facing": 0,
      "note": "앞 작업 칸 곁 팰릿 더미",
      "level": 0
    },
    {
      "kind": "crate_stack",
      "rect": [
        11,
        14,
        2,
        2
      ],
      "solid": "low",
      "facing": 0,
      "note": "안쪽 보관실 곁 나무 상자 더미",
      "level": 0
    },
    {
      "kind": "pallet_stack",
      "rect": [
        8,
        15,
        2,
        2
      ],
      "solid": "low",
      "facing": 0,
      "note": "안쪽 보관실 곁 팰릿 더미",
      "level": 0
    },
    {
      "kind": "tool_cart",
      "rect": [
        19,
        10,
        2,
        1
      ],
      "solid": "low",
      "facing": 0,
      "note": "앞 작업 칸 곁 공구 수레",
      "level": 0
    },
    {
      "kind": "part_crate",
      "rect": [
        21,
        10,
        1,
        1
      ],
      "solid": "low",
      "facing": 0,
      "note": "앞 작업 칸 곁 부품 상자",
      "level": 0
    },
    {
      "kind": "coupler_set",
      "rect": [
        22,
        10,
        1,
        1
      ],
      "solid": "low",
      "facing": 0,
      "note": "앞 작업 칸 곁 연결기 한 벌",
      "level": 0
    },
    {
      "kind": "crate_stack",
      "rect": [
        24,
        10,
        2,
        2
      ],
      "solid": "low",
      "facing": 0,
      "note": "앞 작업 칸 곁 나무 상자 더미",
      "level": 0
    },
    {
      "kind": "pallet_stack",
      "rect": [
        19,
        11,
        2,
        2
      ],
      "solid": "low",
      "facing": 0,
      "note": "앞 작업 칸 곁 팰릿 더미",
      "level": 0
    },
    {
      "kind": "sack_pile",
      "rect": [
        28,
        10,
        2,
        2
      ],
      "solid": "low",
      "facing": 0,
      "note": "안쪽 보관실 곁 자루 더미",
      "level": 0
    },
    {
      "kind": "handcart",
      "rect": [
        30,
        10,
        2,
        1
      ],
      "solid": "low",
      "facing": 0,
      "note": "안쪽 보관실 곁 손수레",
      "level": 0
    },
    {
      "kind": "barrel",
      "rect": [
        32,
        10,
        1,
        1
      ],
      "solid": "low",
      "facing": 0,
      "note": "안쪽 보관실 곁 통",
      "level": 0
    },
    {
      "kind": "crate_stack",
      "rect": [
        33,
        10,
        2,
        2
      ],
      "solid": "low",
      "facing": 0,
      "note": "안쪽 보관실 곁 나무 상자 더미",
      "level": 0
    },
    {
      "kind": "pallet_stack",
      "rect": [
        28,
        12,
        2,
        2
      ],
      "solid": "low",
      "facing": 0,
      "note": "안쪽 보관실 곁 팰릿 더미",
      "level": 0
    },
    {
      "kind": "shelf",
      "rect": [
        19,
        10,
        3,
        1
      ],
      "solid": "none",
      "facing": 0,
      "note": "앞 작업 칸 곁 선반",
      "level": 1
    },
    {
      "kind": "crate_stack",
      "rect": [
        22,
        10,
        2,
        2
      ],
      "solid": "none",
      "facing": 0,
      "note": "앞 작업 칸 곁 나무 상자 더미",
      "level": 1
    },
    {
      "kind": "rope_coil",
      "rect": [
        24,
        10,
        1,
        1
      ],
      "solid": "none",
      "facing": 0,
      "note": "앞 작업 칸 곁 밧줄 더미",
      "level": 1
    },
    {
      "kind": "crate_stack",
      "rect": [
        25,
        10,
        2,
        2
      ],
      "solid": "none",
      "facing": 0,
      "note": "앞 작업 칸 곁 나무 상자 더미",
      "level": 1
    },
    {
      "kind": "pallet_stack",
      "rect": [
        19,
        11,
        2,
        2
      ],
      "solid": "none",
      "facing": 0,
      "note": "앞 작업 칸 곁 팰릿 더미",
      "level": 1
    },
    {
      "kind": "medicine_crate",
      "rect": [
        28,
        10,
        1,
        1
      ],
      "solid": "none",
      "facing": 0,
      "note": "안쪽 보관실 곁 약 상자",
      "level": 1
    },
    {
      "kind": "part_crate",
      "rect": [
        29,
        10,
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
        30,
        10,
        1,
        1
      ],
      "solid": "none",
      "facing": 0,
      "note": "안쪽 보관실 곁 통",
      "level": 1
    },
    {
      "kind": "crate_stack",
      "rect": [
        31,
        10,
        2,
        2
      ],
      "solid": "none",
      "facing": 0,
      "note": "안쪽 보관실 곁 나무 상자 더미",
      "level": 1
    },
    {
      "kind": "pallet_stack",
      "rect": [
        33,
        10,
        2,
        2
      ],
      "solid": "none",
      "facing": 0,
      "note": "안쪽 보관실 곁 팰릿 더미",
      "level": 1
    },
    {
      "kind": "shelf",
      "rect": [
        41,
        11,
        3,
        1
      ],
      "solid": "none",
      "facing": 0,
      "note": "약품 앞 저장고 곁 선반",
      "level": -1
    },
    {
      "kind": "desk",
      "rect": [
        44,
        11,
        2,
        1
      ],
      "solid": "none",
      "facing": 0,
      "note": "약품 앞 저장고 곁 책상",
      "level": -1
    },
    {
      "kind": "file_cabinet",
      "rect": [
        48,
        11,
        2,
        1
      ],
      "solid": "none",
      "facing": 0,
      "note": "약품 앞 저장고 곁 서류함",
      "level": -1
    },
    {
      "kind": "crate_stack",
      "rect": [
        50,
        11,
        2,
        2
      ],
      "solid": "none",
      "facing": 0,
      "note": "약품 앞 저장고 곁 나무 상자 더미",
      "level": -1
    },
    {
      "kind": "pallet_stack",
      "rect": [
        41,
        12,
        2,
        2
      ],
      "solid": "none",
      "facing": 0,
      "note": "약품 앞 저장고 곁 팰릿 더미",
      "level": -1
    },
    {
      "kind": "medicine_crate",
      "rect": [
        54,
        11,
        1,
        1
      ],
      "solid": "none",
      "facing": 0,
      "note": "약품 안쪽 보관실 곁 약 상자",
      "level": -1
    },
    {
      "kind": "pallet_stack",
      "rect": [
        55,
        11,
        2,
        2
      ],
      "solid": "none",
      "facing": 0,
      "note": "약품 안쪽 보관실 곁 팰릿 더미",
      "level": -1
    },
    {
      "kind": "barrel",
      "rect": [
        57,
        11,
        1,
        1
      ],
      "solid": "none",
      "facing": 0,
      "note": "약품 안쪽 보관실 곁 통",
      "level": -1
    },
    {
      "kind": "crate_stack",
      "rect": [
        58,
        11,
        2,
        2
      ],
      "solid": "none",
      "facing": 0,
      "note": "약품 안쪽 보관실 곁 나무 상자 더미",
      "level": -1
    },
    {
      "kind": "pallet_stack",
      "rect": [
        61,
        11,
        2,
        2
      ],
      "solid": "none",
      "facing": 0,
      "note": "약품 안쪽 보관실 곁 팰릿 더미",
      "level": -1
    },
    {
      "kind": "tool_cart",
      "rect": [
        68,
        11,
        2,
        1
      ],
      "solid": "none",
      "facing": 0,
      "note": "약품 앞 저장고 곁 공구 수레",
      "level": -1
    },
    {
      "kind": "part_crate",
      "rect": [
        70,
        11,
        1,
        1
      ],
      "solid": "none",
      "facing": 0,
      "note": "약품 앞 저장고 곁 부품 상자",
      "level": -1
    },
    {
      "kind": "coupler_set",
      "rect": [
        71,
        11,
        1,
        1
      ],
      "solid": "none",
      "facing": 0,
      "note": "약품 앞 저장고 곁 연결기 한 벌",
      "level": -1
    },
    {
      "kind": "crate_stack",
      "rect": [
        72,
        11,
        2,
        2
      ],
      "solid": "none",
      "facing": 0,
      "note": "약품 앞 저장고 곁 나무 상자 더미",
      "level": -1
    },
    {
      "kind": "pallet_stack",
      "rect": [
        75,
        11,
        2,
        2
      ],
      "solid": "none",
      "facing": 0,
      "note": "약품 앞 저장고 곁 팰릿 더미",
      "level": -1
    },
    {
      "kind": "sack_pile",
      "rect": [
        41,
        18,
        2,
        2
      ],
      "solid": "none",
      "facing": 0,
      "note": "약품 안쪽 보관실 곁 자루 더미",
      "level": -1
    },
    {
      "kind": "handcart",
      "rect": [
        43,
        18,
        2,
        1
      ],
      "solid": "none",
      "facing": 0,
      "note": "약품 안쪽 보관실 곁 손수레",
      "level": -1
    },
    {
      "kind": "barrel",
      "rect": [
        45,
        18,
        1,
        1
      ],
      "solid": "none",
      "facing": 0,
      "note": "약품 안쪽 보관실 곁 통",
      "level": -1
    },
    {
      "kind": "crate_stack",
      "rect": [
        48,
        18,
        2,
        2
      ],
      "solid": "none",
      "facing": 0,
      "note": "약품 안쪽 보관실 곁 나무 상자 더미",
      "level": -1
    },
    {
      "kind": "pallet_stack",
      "rect": [
        50,
        18,
        2,
        2
      ],
      "solid": "none",
      "facing": 0,
      "note": "약품 안쪽 보관실 곁 팰릿 더미",
      "level": -1
    },
    {
      "kind": "shelf",
      "rect": [
        54,
        18,
        3,
        1
      ],
      "solid": "none",
      "facing": 0,
      "note": "약품 앞 저장고 곁 선반",
      "level": -1
    },
    {
      "kind": "crate_stack",
      "rect": [
        57,
        18,
        2,
        2
      ],
      "solid": "none",
      "facing": 0,
      "note": "약품 앞 저장고 곁 나무 상자 더미",
      "level": -1
    },
    {
      "kind": "rope_coil",
      "rect": [
        59,
        18,
        1,
        1
      ],
      "solid": "none",
      "facing": 0,
      "note": "약품 앞 저장고 곁 밧줄 더미",
      "level": -1
    },
    {
      "kind": "crate_stack",
      "rect": [
        61,
        18,
        2,
        2
      ],
      "solid": "none",
      "facing": 0,
      "note": "약품 앞 저장고 곁 나무 상자 더미",
      "level": -1
    },
    {
      "kind": "pallet_stack",
      "rect": [
        63,
        18,
        2,
        2
      ],
      "solid": "none",
      "facing": 0,
      "note": "약품 앞 저장고 곁 팰릿 더미",
      "level": -1
    },
    {
      "kind": "medicine_crate",
      "rect": [
        68,
        18,
        1,
        1
      ],
      "solid": "none",
      "facing": 0,
      "note": "약품 안쪽 보관실 곁 약 상자",
      "level": -1
    },
    {
      "kind": "part_crate",
      "rect": [
        69,
        18,
        1,
        1
      ],
      "solid": "none",
      "facing": 0,
      "note": "약품 안쪽 보관실 곁 부품 상자",
      "level": -1
    },
    {
      "kind": "barrel",
      "rect": [
        70,
        18,
        1,
        1
      ],
      "solid": "none",
      "facing": 0,
      "note": "약품 안쪽 보관실 곁 통",
      "level": -1
    },
    {
      "kind": "crate_stack",
      "rect": [
        71,
        18,
        2,
        2
      ],
      "solid": "none",
      "facing": 0,
      "note": "약품 안쪽 보관실 곁 나무 상자 더미",
      "level": -1
    },
    {
      "kind": "pallet_stack",
      "rect": [
        75,
        18,
        2,
        2
      ],
      "solid": "none",
      "facing": 0,
      "note": "약품 안쪽 보관실 곁 팰릿 더미",
      "level": -1
    },
    {
      "kind": "shelf",
      "rect": [
        41,
        11,
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
        44,
        11,
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
        48,
        11,
        2,
        1
      ],
      "solid": "low",
      "facing": 0,
      "note": "선별실 곁 서류함",
      "level": 0
    },
    {
      "kind": "crate_stack",
      "rect": [
        50,
        11,
        2,
        2
      ],
      "solid": "low",
      "facing": 0,
      "note": "선별실 곁 나무 상자 더미",
      "level": 0
    },
    {
      "kind": "pallet_stack",
      "rect": [
        41,
        12,
        2,
        2
      ],
      "solid": "low",
      "facing": 0,
      "note": "선별실 곁 팰릿 더미",
      "level": 0
    },
    {
      "kind": "medicine_crate",
      "rect": [
        54,
        11,
        1,
        1
      ],
      "solid": "low",
      "facing": 0,
      "note": "원료 칸 곁 약 상자",
      "level": 0
    },
    {
      "kind": "pallet_stack",
      "rect": [
        55,
        11,
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
        57,
        11,
        1,
        1
      ],
      "solid": "low",
      "facing": 0,
      "note": "원료 칸 곁 통",
      "level": 0
    },
    {
      "kind": "crate_stack",
      "rect": [
        58,
        11,
        2,
        2
      ],
      "solid": "low",
      "facing": 0,
      "note": "원료 칸 곁 나무 상자 더미",
      "level": 0
    },
    {
      "kind": "pallet_stack",
      "rect": [
        61,
        11,
        2,
        2
      ],
      "solid": "low",
      "facing": 0,
      "note": "원료 칸 곁 팰릿 더미",
      "level": 0
    },
    {
      "kind": "tool_cart",
      "rect": [
        68,
        11,
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
        70,
        11,
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
        71,
        11,
        1,
        1
      ],
      "solid": "low",
      "facing": 0,
      "note": "가공 칸 곁 연결기 한 벌",
      "level": 0
    },
    {
      "kind": "crate_stack",
      "rect": [
        72,
        11,
        2,
        2
      ],
      "solid": "low",
      "facing": 0,
      "note": "가공 칸 곁 나무 상자 더미",
      "level": 0
    },
    {
      "kind": "pallet_stack",
      "rect": [
        75,
        11,
        2,
        2
      ],
      "solid": "low",
      "facing": 0,
      "note": "가공 칸 곁 팰릿 더미",
      "level": 0
    },
    {
      "kind": "sack_pile",
      "rect": [
        41,
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
        43,
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
        45,
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
      "kind": "crate_stack",
      "rect": [
        48,
        18,
        2,
        2
      ],
      "solid": "low",
      "facing": 0,
      "note": "계량실 곁 나무 상자 더미",
      "level": 0
    },
    {
      "kind": "pallet_stack",
      "rect": [
        50,
        18,
        2,
        2
      ],
      "solid": "low",
      "facing": 0,
      "note": "계량실 곁 팰릿 더미",
      "level": 0
    },
    {
      "kind": "shelf",
      "rect": [
        54,
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
        57,
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
        59,
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
      "kind": "crate_stack",
      "rect": [
        61,
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
      "kind": "pallet_stack",
      "rect": [
        63,
        18,
        2,
        2
      ],
      "solid": "low",
      "facing": 0,
      "note": "공구 칸 곁 팰릿 더미",
      "level": 0
    },
    {
      "kind": "medicine_crate",
      "rect": [
        68,
        18,
        1,
        1
      ],
      "solid": "low",
      "facing": 0,
      "note": "안쪽 보관실 곁 약 상자",
      "level": 0
    },
    {
      "kind": "part_crate",
      "rect": [
        69,
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
        70,
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
      "kind": "crate_stack",
      "rect": [
        71,
        18,
        2,
        2
      ],
      "solid": "low",
      "facing": 0,
      "note": "안쪽 보관실 곁 나무 상자 더미",
      "level": 0
    },
    {
      "kind": "pallet_stack",
      "rect": [
        75,
        18,
        2,
        2
      ],
      "solid": "low",
      "facing": 0,
      "note": "안쪽 보관실 곁 팰릿 더미",
      "level": 0
    },
    {
      "kind": "shelf",
      "rect": [
        41,
        11,
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
        44,
        11,
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
        48,
        11,
        2,
        1
      ],
      "solid": "none",
      "facing": 0,
      "note": "선별실 곁 서류함",
      "level": 1
    },
    {
      "kind": "crate_stack",
      "rect": [
        50,
        11,
        2,
        2
      ],
      "solid": "none",
      "facing": 0,
      "note": "선별실 곁 나무 상자 더미",
      "level": 1
    },
    {
      "kind": "pallet_stack",
      "rect": [
        41,
        12,
        2,
        2
      ],
      "solid": "none",
      "facing": 0,
      "note": "선별실 곁 팰릿 더미",
      "level": 1
    },
    {
      "kind": "medicine_crate",
      "rect": [
        54,
        11,
        1,
        1
      ],
      "solid": "none",
      "facing": 0,
      "note": "원료 칸 곁 약 상자",
      "level": 1
    },
    {
      "kind": "pallet_stack",
      "rect": [
        55,
        11,
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
        57,
        11,
        1,
        1
      ],
      "solid": "none",
      "facing": 0,
      "note": "원료 칸 곁 통",
      "level": 1
    },
    {
      "kind": "crate_stack",
      "rect": [
        58,
        11,
        2,
        2
      ],
      "solid": "none",
      "facing": 0,
      "note": "원료 칸 곁 나무 상자 더미",
      "level": 1
    },
    {
      "kind": "pallet_stack",
      "rect": [
        61,
        11,
        2,
        2
      ],
      "solid": "none",
      "facing": 0,
      "note": "원료 칸 곁 팰릿 더미",
      "level": 1
    },
    {
      "kind": "tool_cart",
      "rect": [
        68,
        11,
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
        70,
        11,
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
        71,
        11,
        1,
        1
      ],
      "solid": "none",
      "facing": 0,
      "note": "가공 칸 곁 연결기 한 벌",
      "level": 1
    },
    {
      "kind": "crate_stack",
      "rect": [
        72,
        11,
        2,
        2
      ],
      "solid": "none",
      "facing": 0,
      "note": "가공 칸 곁 나무 상자 더미",
      "level": 1
    },
    {
      "kind": "pallet_stack",
      "rect": [
        75,
        11,
        2,
        2
      ],
      "solid": "none",
      "facing": 0,
      "note": "가공 칸 곁 팰릿 더미",
      "level": 1
    },
    {
      "kind": "sack_pile",
      "rect": [
        41,
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
        43,
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
        45,
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
      "kind": "crate_stack",
      "rect": [
        48,
        18,
        2,
        2
      ],
      "solid": "none",
      "facing": 0,
      "note": "계량실 곁 나무 상자 더미",
      "level": 1
    },
    {
      "kind": "pallet_stack",
      "rect": [
        50,
        18,
        2,
        2
      ],
      "solid": "none",
      "facing": 0,
      "note": "계량실 곁 팰릿 더미",
      "level": 1
    },
    {
      "kind": "shelf",
      "rect": [
        54,
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
        57,
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
        59,
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
      "kind": "crate_stack",
      "rect": [
        61,
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
      "kind": "pallet_stack",
      "rect": [
        63,
        18,
        2,
        2
      ],
      "solid": "none",
      "facing": 0,
      "note": "공구 칸 곁 팰릿 더미",
      "level": 1
    },
    {
      "kind": "medicine_crate",
      "rect": [
        68,
        18,
        1,
        1
      ],
      "solid": "none",
      "facing": 0,
      "note": "안쪽 보관실 곁 약 상자",
      "level": 1
    },
    {
      "kind": "part_crate",
      "rect": [
        69,
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
        70,
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
      "kind": "crate_stack",
      "rect": [
        71,
        18,
        2,
        2
      ],
      "solid": "none",
      "facing": 0,
      "note": "안쪽 보관실 곁 나무 상자 더미",
      "level": 1
    },
    {
      "kind": "pallet_stack",
      "rect": [
        75,
        18,
        2,
        2
      ],
      "solid": "none",
      "facing": 0,
      "note": "안쪽 보관실 곁 팰릿 더미",
      "level": 1
    },
    {
      "kind": "shelf",
      "rect": [
        41,
        11,
        3,
        1
      ],
      "solid": "none",
      "facing": 0,
      "note": "선별실 곁 선반",
      "level": 2
    },
    {
      "kind": "desk",
      "rect": [
        44,
        11,
        2,
        1
      ],
      "solid": "none",
      "facing": 0,
      "note": "선별실 곁 책상",
      "level": 2
    },
    {
      "kind": "file_cabinet",
      "rect": [
        48,
        11,
        2,
        1
      ],
      "solid": "none",
      "facing": 0,
      "note": "선별실 곁 서류함",
      "level": 2
    },
    {
      "kind": "crate_stack",
      "rect": [
        50,
        11,
        2,
        2
      ],
      "solid": "none",
      "facing": 0,
      "note": "선별실 곁 나무 상자 더미",
      "level": 2
    },
    {
      "kind": "pallet_stack",
      "rect": [
        41,
        12,
        2,
        2
      ],
      "solid": "none",
      "facing": 0,
      "note": "선별실 곁 팰릿 더미",
      "level": 2
    },
    {
      "kind": "medicine_crate",
      "rect": [
        54,
        11,
        1,
        1
      ],
      "solid": "none",
      "facing": 0,
      "note": "원료 칸 곁 약 상자",
      "level": 2
    },
    {
      "kind": "pallet_stack",
      "rect": [
        55,
        11,
        2,
        2
      ],
      "solid": "none",
      "facing": 0,
      "note": "원료 칸 곁 팰릿 더미",
      "level": 2
    },
    {
      "kind": "barrel",
      "rect": [
        57,
        11,
        1,
        1
      ],
      "solid": "none",
      "facing": 0,
      "note": "원료 칸 곁 통",
      "level": 2
    },
    {
      "kind": "crate_stack",
      "rect": [
        58,
        11,
        2,
        2
      ],
      "solid": "none",
      "facing": 0,
      "note": "원료 칸 곁 나무 상자 더미",
      "level": 2
    },
    {
      "kind": "pallet_stack",
      "rect": [
        61,
        11,
        2,
        2
      ],
      "solid": "none",
      "facing": 0,
      "note": "원료 칸 곁 팰릿 더미",
      "level": 2
    },
    {
      "kind": "tool_cart",
      "rect": [
        68,
        11,
        2,
        1
      ],
      "solid": "none",
      "facing": 0,
      "note": "가공 칸 곁 공구 수레",
      "level": 2
    },
    {
      "kind": "part_crate",
      "rect": [
        70,
        11,
        1,
        1
      ],
      "solid": "none",
      "facing": 0,
      "note": "가공 칸 곁 부품 상자",
      "level": 2
    },
    {
      "kind": "coupler_set",
      "rect": [
        71,
        11,
        1,
        1
      ],
      "solid": "none",
      "facing": 0,
      "note": "가공 칸 곁 연결기 한 벌",
      "level": 2
    },
    {
      "kind": "crate_stack",
      "rect": [
        72,
        11,
        2,
        2
      ],
      "solid": "none",
      "facing": 0,
      "note": "가공 칸 곁 나무 상자 더미",
      "level": 2
    },
    {
      "kind": "pallet_stack",
      "rect": [
        75,
        11,
        2,
        2
      ],
      "solid": "none",
      "facing": 0,
      "note": "가공 칸 곁 팰릿 더미",
      "level": 2
    },
    {
      "kind": "sack_pile",
      "rect": [
        41,
        18,
        2,
        2
      ],
      "solid": "none",
      "facing": 0,
      "note": "계량실 곁 자루 더미",
      "level": 2
    },
    {
      "kind": "handcart",
      "rect": [
        43,
        18,
        2,
        1
      ],
      "solid": "none",
      "facing": 0,
      "note": "계량실 곁 손수레",
      "level": 2
    },
    {
      "kind": "barrel",
      "rect": [
        45,
        18,
        1,
        1
      ],
      "solid": "none",
      "facing": 0,
      "note": "계량실 곁 통",
      "level": 2
    },
    {
      "kind": "crate_stack",
      "rect": [
        48,
        18,
        2,
        2
      ],
      "solid": "none",
      "facing": 0,
      "note": "계량실 곁 나무 상자 더미",
      "level": 2
    },
    {
      "kind": "pallet_stack",
      "rect": [
        50,
        18,
        2,
        2
      ],
      "solid": "none",
      "facing": 0,
      "note": "계량실 곁 팰릿 더미",
      "level": 2
    },
    {
      "kind": "shelf",
      "rect": [
        54,
        18,
        3,
        1
      ],
      "solid": "none",
      "facing": 0,
      "note": "공구 칸 곁 선반",
      "level": 2
    },
    {
      "kind": "crate_stack",
      "rect": [
        57,
        18,
        2,
        2
      ],
      "solid": "none",
      "facing": 0,
      "note": "공구 칸 곁 나무 상자 더미",
      "level": 2
    },
    {
      "kind": "rope_coil",
      "rect": [
        59,
        18,
        1,
        1
      ],
      "solid": "none",
      "facing": 0,
      "note": "공구 칸 곁 밧줄 더미",
      "level": 2
    },
    {
      "kind": "crate_stack",
      "rect": [
        61,
        18,
        2,
        2
      ],
      "solid": "none",
      "facing": 0,
      "note": "공구 칸 곁 나무 상자 더미",
      "level": 2
    },
    {
      "kind": "pallet_stack",
      "rect": [
        63,
        18,
        2,
        2
      ],
      "solid": "none",
      "facing": 0,
      "note": "공구 칸 곁 팰릿 더미",
      "level": 2
    },
    {
      "kind": "medicine_crate",
      "rect": [
        68,
        18,
        1,
        1
      ],
      "solid": "none",
      "facing": 0,
      "note": "안쪽 보관실 곁 약 상자",
      "level": 2
    },
    {
      "kind": "part_crate",
      "rect": [
        69,
        18,
        1,
        1
      ],
      "solid": "none",
      "facing": 0,
      "note": "안쪽 보관실 곁 부품 상자",
      "level": 2
    },
    {
      "kind": "barrel",
      "rect": [
        70,
        18,
        1,
        1
      ],
      "solid": "none",
      "facing": 0,
      "note": "안쪽 보관실 곁 통",
      "level": 2
    },
    {
      "kind": "crate_stack",
      "rect": [
        71,
        18,
        2,
        2
      ],
      "solid": "none",
      "facing": 0,
      "note": "안쪽 보관실 곁 나무 상자 더미",
      "level": 2
    },
    {
      "kind": "pallet_stack",
      "rect": [
        75,
        18,
        2,
        2
      ],
      "solid": "none",
      "facing": 0,
      "note": "안쪽 보관실 곁 팰릿 더미",
      "level": 2
    },
    {
      "kind": "shelf",
      "rect": [
        88,
        11,
        3,
        1
      ],
      "solid": "none",
      "facing": 0,
      "note": "약품 앞 저장고 곁 선반",
      "level": -1
    },
    {
      "kind": "desk",
      "rect": [
        91,
        11,
        2,
        1
      ],
      "solid": "none",
      "facing": 0,
      "note": "약품 앞 저장고 곁 책상",
      "level": -1
    },
    {
      "kind": "file_cabinet",
      "rect": [
        93,
        11,
        2,
        1
      ],
      "solid": "none",
      "facing": 0,
      "note": "약품 앞 저장고 곁 서류함",
      "level": -1
    },
    {
      "kind": "crate_stack",
      "rect": [
        88,
        12,
        2,
        2
      ],
      "solid": "none",
      "facing": 0,
      "note": "약품 앞 저장고 곁 나무 상자 더미",
      "level": -1
    },
    {
      "kind": "pallet_stack",
      "rect": [
        94,
        12,
        2,
        2
      ],
      "solid": "none",
      "facing": 0,
      "note": "약품 앞 저장고 곁 팰릿 더미",
      "level": -1
    },
    {
      "kind": "medicine_crate",
      "rect": [
        97,
        11,
        1,
        1
      ],
      "solid": "none",
      "facing": 0,
      "note": "약품 안쪽 보관실 곁 약 상자",
      "level": -1
    },
    {
      "kind": "pallet_stack",
      "rect": [
        98,
        11,
        2,
        2
      ],
      "solid": "none",
      "facing": 0,
      "note": "약품 안쪽 보관실 곁 팰릿 더미",
      "level": -1
    },
    {
      "kind": "barrel",
      "rect": [
        100,
        11,
        1,
        1
      ],
      "solid": "none",
      "facing": 0,
      "note": "약품 안쪽 보관실 곁 통",
      "level": -1
    },
    {
      "kind": "crate_stack",
      "rect": [
        101,
        11,
        2,
        2
      ],
      "solid": "none",
      "facing": 0,
      "note": "약품 안쪽 보관실 곁 나무 상자 더미",
      "level": -1
    },
    {
      "kind": "pallet_stack",
      "rect": [
        103,
        11,
        2,
        2
      ],
      "solid": "none",
      "facing": 0,
      "note": "약품 안쪽 보관실 곁 팰릿 더미",
      "level": -1
    },
    {
      "kind": "tool_cart",
      "rect": [
        88,
        11,
        2,
        1
      ],
      "solid": "low",
      "facing": 0,
      "note": "앞 작업 칸 곁 공구 수레",
      "level": 0
    },
    {
      "kind": "part_crate",
      "rect": [
        90,
        11,
        1,
        1
      ],
      "solid": "low",
      "facing": 0,
      "note": "앞 작업 칸 곁 부품 상자",
      "level": 0
    },
    {
      "kind": "coupler_set",
      "rect": [
        91,
        11,
        1,
        1
      ],
      "solid": "low",
      "facing": 0,
      "note": "앞 작업 칸 곁 연결기 한 벌",
      "level": 0
    },
    {
      "kind": "crate_stack",
      "rect": [
        93,
        11,
        2,
        2
      ],
      "solid": "low",
      "facing": 0,
      "note": "앞 작업 칸 곁 나무 상자 더미",
      "level": 0
    },
    {
      "kind": "pallet_stack",
      "rect": [
        88,
        12,
        2,
        2
      ],
      "solid": "low",
      "facing": 0,
      "note": "앞 작업 칸 곁 팰릿 더미",
      "level": 0
    },
    {
      "kind": "sack_pile",
      "rect": [
        97,
        11,
        2,
        2
      ],
      "solid": "low",
      "facing": 0,
      "note": "안쪽 보관실 곁 자루 더미",
      "level": 0
    },
    {
      "kind": "handcart",
      "rect": [
        99,
        11,
        2,
        1
      ],
      "solid": "low",
      "facing": 0,
      "note": "안쪽 보관실 곁 손수레",
      "level": 0
    },
    {
      "kind": "barrel",
      "rect": [
        101,
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
      "kind": "crate_stack",
      "rect": [
        102,
        11,
        2,
        2
      ],
      "solid": "low",
      "facing": 0,
      "note": "안쪽 보관실 곁 나무 상자 더미",
      "level": 0
    },
    {
      "kind": "pallet_stack",
      "rect": [
        97,
        13,
        2,
        2
      ],
      "solid": "low",
      "facing": 0,
      "note": "안쪽 보관실 곁 팰릿 더미",
      "level": 0
    },
    {
      "kind": "shelf",
      "rect": [
        88,
        11,
        3,
        1
      ],
      "solid": "none",
      "facing": 0,
      "note": "앞 작업 칸 곁 선반",
      "level": 1
    },
    {
      "kind": "crate_stack",
      "rect": [
        91,
        11,
        2,
        2
      ],
      "solid": "none",
      "facing": 0,
      "note": "앞 작업 칸 곁 나무 상자 더미",
      "level": 1
    },
    {
      "kind": "rope_coil",
      "rect": [
        93,
        11,
        1,
        1
      ],
      "solid": "none",
      "facing": 0,
      "note": "앞 작업 칸 곁 밧줄 더미",
      "level": 1
    },
    {
      "kind": "crate_stack",
      "rect": [
        94,
        11,
        2,
        2
      ],
      "solid": "none",
      "facing": 0,
      "note": "앞 작업 칸 곁 나무 상자 더미",
      "level": 1
    },
    {
      "kind": "pallet_stack",
      "rect": [
        88,
        12,
        2,
        2
      ],
      "solid": "none",
      "facing": 0,
      "note": "앞 작업 칸 곁 팰릿 더미",
      "level": 1
    },
    {
      "kind": "medicine_crate",
      "rect": [
        97,
        11,
        1,
        1
      ],
      "solid": "none",
      "facing": 0,
      "note": "안쪽 보관실 곁 약 상자",
      "level": 1
    },
    {
      "kind": "part_crate",
      "rect": [
        98,
        11,
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
        99,
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
      "kind": "crate_stack",
      "rect": [
        100,
        11,
        2,
        2
      ],
      "solid": "none",
      "facing": 0,
      "note": "안쪽 보관실 곁 나무 상자 더미",
      "level": 1
    },
    {
      "kind": "pallet_stack",
      "rect": [
        102,
        11,
        2,
        2
      ],
      "solid": "none",
      "facing": 0,
      "note": "안쪽 보관실 곁 팰릿 더미",
      "level": 1
    },
    {
      "kind": "shelf",
      "rect": [
        107,
        18,
        3,
        1
      ],
      "solid": "low",
      "facing": 0,
      "note": "작업 칸 곁 선반",
      "level": 0
    },
    {
      "kind": "file_cabinet",
      "rect": [
        107,
        19,
        2,
        1
      ],
      "solid": "low",
      "facing": 0,
      "note": "작업 칸 곁 서류함",
      "level": 0
    },
    {
      "kind": "crate_stack",
      "rect": [
        113,
        19,
        2,
        2
      ],
      "solid": "low",
      "facing": 0,
      "note": "작업 칸 곁 나무 상자 더미",
      "level": 0
    },
    {
      "kind": "pallet_stack",
      "rect": [
        107,
        20,
        2,
        2
      ],
      "solid": "low",
      "facing": 0,
      "note": "작업 칸 곁 팰릿 더미",
      "level": 0
    },
    {
      "kind": "barrel",
      "rect": [
        120,
        13,
        1,
        1
      ],
      "solid": "low",
      "facing": 0,
      "note": "작업 칸 곁 통",
      "level": 0
    },
    {
      "kind": "crate_stack",
      "rect": [
        122,
        13,
        2,
        2
      ],
      "solid": "low",
      "facing": 0,
      "note": "작업 칸 곁 나무 상자 더미",
      "level": 0
    },
    {
      "kind": "pallet_stack",
      "rect": [
        117,
        15,
        2,
        2
      ],
      "solid": "low",
      "facing": 0,
      "note": "작업 칸 곁 팰릿 더미",
      "level": 0
    },
    {
      "kind": "medicine_crate",
      "rect": [
        129,
        14,
        1,
        1
      ],
      "solid": "none",
      "facing": 0,
      "note": "약품 앞 저장고 곁 약 상자",
      "level": -1
    },
    {
      "kind": "part_crate",
      "rect": [
        130,
        14,
        1,
        1
      ],
      "solid": "none",
      "facing": 0,
      "note": "약품 앞 저장고 곁 부품 상자",
      "level": -1
    },
    {
      "kind": "barrel",
      "rect": [
        132,
        14,
        1,
        1
      ],
      "solid": "none",
      "facing": 0,
      "note": "약품 앞 저장고 곁 통",
      "level": -1
    },
    {
      "kind": "tool_cart",
      "rect": [
        129,
        15,
        2,
        1
      ],
      "solid": "none",
      "facing": 0,
      "note": "약품 앞 저장고 곁 공구 수레",
      "level": -1
    },
    {
      "kind": "crate_stack",
      "rect": [
        129,
        16,
        2,
        2
      ],
      "solid": "none",
      "facing": 0,
      "note": "약품 앞 저장고 곁 나무 상자 더미",
      "level": -1
    },
    {
      "kind": "pallet_stack",
      "rect": [
        131,
        17,
        2,
        2
      ],
      "solid": "none",
      "facing": 0,
      "note": "약품 앞 저장고 곁 팰릿 더미",
      "level": -1
    },
    {
      "kind": "medicine_crate",
      "rect": [
        134,
        14,
        1,
        1
      ],
      "solid": "none",
      "facing": 0,
      "note": "약품 안쪽 보관실 곁 약 상자",
      "level": -1
    },
    {
      "kind": "part_crate",
      "rect": [
        135,
        14,
        1,
        1
      ],
      "solid": "none",
      "facing": 0,
      "note": "약품 안쪽 보관실 곁 부품 상자",
      "level": -1
    },
    {
      "kind": "barrel",
      "rect": [
        137,
        14,
        1,
        1
      ],
      "solid": "none",
      "facing": 0,
      "note": "약품 안쪽 보관실 곁 통",
      "level": -1
    },
    {
      "kind": "tool_cart",
      "rect": [
        134,
        15,
        2,
        1
      ],
      "solid": "none",
      "facing": 0,
      "note": "약품 안쪽 보관실 곁 공구 수레",
      "level": -1
    },
    {
      "kind": "crate_stack",
      "rect": [
        137,
        15,
        2,
        2
      ],
      "solid": "none",
      "facing": 0,
      "note": "약품 안쪽 보관실 곁 나무 상자 더미",
      "level": -1
    },
    {
      "kind": "pallet_stack",
      "rect": [
        134,
        16,
        2,
        2
      ],
      "solid": "none",
      "facing": 0,
      "note": "약품 안쪽 보관실 곁 팰릿 더미",
      "level": -1
    },
    {
      "kind": "medicine_crate",
      "rect": [
        129,
        11,
        1,
        1
      ],
      "solid": "low",
      "facing": 0,
      "note": "앞 작업 칸 곁 약 상자",
      "level": 0
    },
    {
      "kind": "part_crate",
      "rect": [
        130,
        11,
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
        131,
        11,
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
        132,
        11,
        2,
        1
      ],
      "solid": "low",
      "facing": 0,
      "note": "앞 작업 칸 곁 공구 수레",
      "level": 0
    },
    {
      "kind": "crate_stack",
      "rect": [
        129,
        12,
        2,
        2
      ],
      "solid": "low",
      "facing": 0,
      "note": "앞 작업 칸 곁 나무 상자 더미",
      "level": 0
    },
    {
      "kind": "pallet_stack",
      "rect": [
        132,
        12,
        2,
        2
      ],
      "solid": "low",
      "facing": 0,
      "note": "앞 작업 칸 곁 팰릿 더미",
      "level": 0
    },
    {
      "kind": "pallet_stack",
      "rect": [
        135,
        13,
        2,
        2
      ],
      "solid": "low",
      "facing": 0,
      "note": "안쪽 보관실 곁 팰릿 더미",
      "level": 0
    },
    {
      "kind": "medicine_crate",
      "rect": [
        129,
        11,
        1,
        1
      ],
      "solid": "none",
      "facing": 0,
      "note": "앞 작업 칸 곁 약 상자",
      "level": 1
    },
    {
      "kind": "part_crate",
      "rect": [
        130,
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
      "kind": "barrel",
      "rect": [
        131,
        11,
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
        132,
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
      "kind": "crate_stack",
      "rect": [
        129,
        12,
        2,
        2
      ],
      "solid": "none",
      "facing": 0,
      "note": "앞 작업 칸 곁 나무 상자 더미",
      "level": 1
    },
    {
      "kind": "pallet_stack",
      "rect": [
        132,
        12,
        2,
        2
      ],
      "solid": "none",
      "facing": 0,
      "note": "앞 작업 칸 곁 팰릿 더미",
      "level": 1
    },
    {
      "kind": "medicine_crate",
      "rect": [
        135,
        11,
        1,
        1
      ],
      "solid": "none",
      "facing": 0,
      "note": "안쪽 보관실 곁 약 상자",
      "level": 1
    },
    {
      "kind": "part_crate",
      "rect": [
        136,
        11,
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
        137,
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
      "kind": "tool_cart",
      "rect": [
        135,
        12,
        2,
        1
      ],
      "solid": "none",
      "facing": 0,
      "note": "안쪽 보관실 곁 공구 수레",
      "level": 1
    },
    {
      "kind": "crate_stack",
      "rect": [
        137,
        12,
        2,
        2
      ],
      "solid": "none",
      "facing": 0,
      "note": "안쪽 보관실 곁 나무 상자 더미",
      "level": 1
    },
    {
      "kind": "pallet_stack",
      "rect": [
        135,
        13,
        2,
        2
      ],
      "solid": "none",
      "facing": 0,
      "note": "안쪽 보관실 곁 팰릿 더미",
      "level": 1
    },
    {
      "kind": "medicine_crate",
      "rect": [
        127,
        36,
        1,
        1
      ],
      "solid": "low",
      "facing": 0,
      "note": "하역 준비 자리의 약 상자",
      "level": 0
    },
    {
      "kind": "barrel",
      "rect": [
        127,
        37,
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
      "name": "수레 차고 앞 작업 칸 상자",
      "cell": [
        6,
        22
      ],
      "building": 18,
      "search": 6,
      "items": [
        "med_box"
      ],
      "locked": false,
      "level": 0,
      "searched": false
    },
    {
      "id": "north_box_2",
      "name": "수레 차고 안쪽 보관실 상자",
      "cell": [
        12,
        22
      ],
      "building": 18,
      "search": 6,
      "items": [
        "med_box"
      ],
      "locked": false,
      "level": 0,
      "searched": false
    },
    {
      "id": "north_box_3",
      "name": "붕대와 솜 창고 앞 작업 칸 상자",
      "cell": [
        26,
        22
      ],
      "building": 19,
      "search": 6,
      "items": [
        "med_box"
      ],
      "locked": false,
      "level": 0,
      "searched": false
    },
    {
      "id": "north_box_4",
      "name": "붕대와 솜 창고 안쪽 보관실 상자",
      "cell": [
        34,
        22
      ],
      "building": 19,
      "search": 6,
      "items": [
        "med_box"
      ],
      "locked": false,
      "level": 0,
      "searched": false
    },
    {
      "id": "north_box_5",
      "name": "붕대와 솜 창고 앞 작업 칸 상자",
      "cell": [
        26,
        22
      ],
      "building": 19,
      "search": 6,
      "items": [
        "med_box"
      ],
      "locked": false,
      "level": 1,
      "searched": false
    },
    {
      "id": "north_box_6",
      "name": "붕대와 솜 창고 안쪽 보관실 상자",
      "cell": [
        34,
        22
      ],
      "building": 19,
      "search": 6,
      "items": [
        "med_box"
      ],
      "locked": false,
      "level": 1,
      "searched": false
    },
    {
      "id": "north_box_7",
      "name": "선별 창고 약품 앞 저장고 상자",
      "cell": [
        52,
        13
      ],
      "building": 20,
      "search": 6,
      "items": [
        "med_box"
      ],
      "locked": false,
      "level": -1,
      "searched": false
    },
    {
      "id": "north_box_8",
      "name": "선별 창고 약품 안쪽 보관실 상자",
      "cell": [
        66,
        13
      ],
      "building": 20,
      "search": 6,
      "items": [
        "med_box"
      ],
      "locked": false,
      "level": -1,
      "searched": false
    },
    {
      "id": "north_box_9",
      "name": "선별 창고 약품 앞 저장고 상자",
      "cell": [
        80,
        13
      ],
      "building": 20,
      "search": 6,
      "items": [
        "med_box"
      ],
      "locked": false,
      "level": -1,
      "searched": false
    },
    {
      "id": "north_box_10",
      "name": "선별 창고 약품 안쪽 보관실 상자",
      "cell": [
        52,
        22
      ],
      "building": 20,
      "search": 6,
      "items": [
        "med_box"
      ],
      "locked": false,
      "level": -1,
      "searched": false
    },
    {
      "id": "north_box_11",
      "name": "선별 창고 약품 앞 저장고 상자",
      "cell": [
        66,
        22
      ],
      "building": 20,
      "search": 6,
      "items": [
        "med_box"
      ],
      "locked": false,
      "level": -1,
      "searched": false
    },
    {
      "id": "north_box_12",
      "name": "선별 창고 약품 안쪽 보관실 상자",
      "cell": [
        80,
        22
      ],
      "building": 20,
      "search": 6,
      "items": [
        "med_box"
      ],
      "locked": false,
      "level": -1,
      "searched": false
    },
    {
      "id": "north_box_13",
      "name": "선별 창고 선별실 상자",
      "cell": [
        52,
        13
      ],
      "building": 20,
      "search": 6,
      "items": [
        "med_box"
      ],
      "locked": false,
      "level": 0,
      "searched": false
    },
    {
      "id": "north_box_14",
      "name": "선별 창고 원료 칸 상자",
      "cell": [
        66,
        13
      ],
      "building": 20,
      "search": 6,
      "items": [
        "med_box"
      ],
      "locked": false,
      "level": 0,
      "searched": false
    },
    {
      "id": "north_box_15",
      "name": "선별 창고 가공 칸 상자",
      "cell": [
        80,
        13
      ],
      "building": 20,
      "search": 6,
      "items": [
        "med_box"
      ],
      "locked": false,
      "level": 0,
      "searched": false
    },
    {
      "id": "north_box_16",
      "name": "선별 창고 계량실 상자",
      "cell": [
        52,
        22
      ],
      "building": 20,
      "search": 6,
      "items": [
        "med_box"
      ],
      "locked": false,
      "level": 0,
      "searched": false
    },
    {
      "id": "north_box_17",
      "name": "선별 창고 공구 칸 상자",
      "cell": [
        66,
        22
      ],
      "building": 20,
      "search": 6,
      "items": [
        "med_box"
      ],
      "locked": false,
      "level": 0,
      "searched": false
    },
    {
      "id": "north_box_18",
      "name": "선별 창고 안쪽 보관실 상자",
      "cell": [
        80,
        22
      ],
      "building": 20,
      "search": 6,
      "items": [
        "med_box"
      ],
      "locked": false,
      "level": 0,
      "searched": false
    },
    {
      "id": "north_box_19",
      "name": "선별 창고 선별실 상자",
      "cell": [
        52,
        13
      ],
      "building": 20,
      "search": 6,
      "items": [
        "med_box"
      ],
      "locked": false,
      "level": 1,
      "searched": false
    },
    {
      "id": "north_box_20",
      "name": "선별 창고 원료 칸 상자",
      "cell": [
        66,
        13
      ],
      "building": 20,
      "search": 6,
      "items": [
        "med_box"
      ],
      "locked": false,
      "level": 1,
      "searched": false
    },
    {
      "id": "north_box_21",
      "name": "선별 창고 가공 칸 상자",
      "cell": [
        80,
        13
      ],
      "building": 20,
      "search": 6,
      "items": [
        "med_box"
      ],
      "locked": false,
      "level": 1,
      "searched": false
    },
    {
      "id": "north_box_22",
      "name": "선별 창고 계량실 상자",
      "cell": [
        52,
        22
      ],
      "building": 20,
      "search": 6,
      "items": [
        "med_box"
      ],
      "locked": false,
      "level": 1,
      "searched": false
    },
    {
      "id": "north_box_23",
      "name": "선별 창고 공구 칸 상자",
      "cell": [
        66,
        22
      ],
      "building": 20,
      "search": 6,
      "items": [
        "med_box"
      ],
      "locked": false,
      "level": 1,
      "searched": false
    },
    {
      "id": "north_box_24",
      "name": "선별 창고 안쪽 보관실 상자",
      "cell": [
        80,
        22
      ],
      "building": 20,
      "search": 6,
      "items": [
        "med_box"
      ],
      "locked": false,
      "level": 1,
      "searched": false
    },
    {
      "id": "north_box_25",
      "name": "선별 창고 선별실 상자",
      "cell": [
        52,
        13
      ],
      "building": 20,
      "search": 6,
      "items": [
        "med_box"
      ],
      "locked": false,
      "level": 2,
      "searched": false
    },
    {
      "id": "north_box_26",
      "name": "선별 창고 원료 칸 상자",
      "cell": [
        66,
        13
      ],
      "building": 20,
      "search": 6,
      "items": [
        "med_box"
      ],
      "locked": false,
      "level": 2,
      "searched": false
    },
    {
      "id": "north_box_27",
      "name": "선별 창고 가공 칸 상자",
      "cell": [
        80,
        13
      ],
      "building": 20,
      "search": 6,
      "items": [
        "med_box"
      ],
      "locked": false,
      "level": 2,
      "searched": false
    },
    {
      "id": "north_box_28",
      "name": "선별 창고 계량실 상자",
      "cell": [
        52,
        22
      ],
      "building": 20,
      "search": 6,
      "items": [
        "med_box"
      ],
      "locked": false,
      "level": 2,
      "searched": false
    },
    {
      "id": "north_box_29",
      "name": "선별 창고 공구 칸 상자",
      "cell": [
        66,
        22
      ],
      "building": 20,
      "search": 6,
      "items": [
        "med_box"
      ],
      "locked": false,
      "level": 2,
      "searched": false
    },
    {
      "id": "north_box_30",
      "name": "선별 창고 안쪽 보관실 상자",
      "cell": [
        80,
        22
      ],
      "building": 20,
      "search": 6,
      "items": [
        "med_box"
      ],
      "locked": false,
      "level": 2,
      "searched": false
    },
    {
      "id": "north_box_31",
      "name": "냉장 약품 창고 약품 앞 저장고 상자",
      "cell": [
        95,
        22
      ],
      "building": 21,
      "search": 6,
      "items": [
        "med_box"
      ],
      "locked": false,
      "level": -1,
      "searched": false
    },
    {
      "id": "north_box_32",
      "name": "냉장 약품 창고 약품 안쪽 보관실 상자",
      "cell": [
        104,
        22
      ],
      "building": 21,
      "search": 6,
      "items": [
        "med_box"
      ],
      "locked": false,
      "level": -1,
      "searched": false
    },
    {
      "id": "north_box_33",
      "name": "냉장 약품 창고 앞 작업 칸 상자",
      "cell": [
        95,
        22
      ],
      "building": 21,
      "search": 6,
      "items": [
        "med_box"
      ],
      "locked": false,
      "level": 0,
      "searched": false
    },
    {
      "id": "north_box_34",
      "name": "냉장 약품 창고 안쪽 보관실 상자",
      "cell": [
        104,
        22
      ],
      "building": 21,
      "search": 6,
      "items": [
        "med_box"
      ],
      "locked": false,
      "level": 0,
      "searched": false
    },
    {
      "id": "north_box_35",
      "name": "냉장 약품 창고 앞 작업 칸 상자",
      "cell": [
        95,
        22
      ],
      "building": 21,
      "search": 6,
      "items": [
        "med_box"
      ],
      "locked": false,
      "level": 1,
      "searched": false
    },
    {
      "id": "north_box_36",
      "name": "냉장 약품 창고 안쪽 보관실 상자",
      "cell": [
        104,
        22
      ],
      "building": 21,
      "search": 6,
      "items": [
        "med_box"
      ],
      "locked": false,
      "level": 1,
      "searched": false
    },
    {
      "id": "north_box_37",
      "name": "약품 계량소 작업 칸 상자",
      "cell": [
        114,
        22
      ],
      "building": 22,
      "search": 6,
      "items": [
        "med_box"
      ],
      "locked": false,
      "level": 0,
      "searched": false
    },
    {
      "id": "north_box_38",
      "name": "구급 사무소 작업 칸 상자",
      "cell": [
        124,
        18
      ],
      "building": 23,
      "search": 6,
      "items": [
        "med_box"
      ],
      "locked": false,
      "level": 0,
      "searched": false
    },
    {
      "id": "north_box_39",
      "name": "둑 창고 약품 앞 저장고 상자",
      "cell": [
        132,
        40
      ],
      "building": 24,
      "search": 6,
      "items": [
        "med_box"
      ],
      "locked": false,
      "level": -1,
      "searched": false
    },
    {
      "id": "north_box_40",
      "name": "둑 창고 약품 안쪽 보관실 상자",
      "cell": [
        138,
        40
      ],
      "building": 24,
      "search": 6,
      "items": [
        "med_box"
      ],
      "locked": false,
      "level": -1,
      "searched": false
    },
    {
      "id": "north_box_41",
      "name": "둑 창고 앞 작업 칸 상자",
      "cell": [
        133,
        40
      ],
      "building": 24,
      "search": 6,
      "items": [
        "med_box"
      ],
      "locked": false,
      "level": 0,
      "searched": false
    },
    {
      "id": "north_box_42",
      "name": "둑 창고 안쪽 보관실 상자",
      "cell": [
        138,
        40
      ],
      "building": 24,
      "search": 6,
      "items": [
        "med_box"
      ],
      "locked": false,
      "level": 0,
      "searched": false
    },
    {
      "id": "north_box_43",
      "name": "둑 창고 앞 작업 칸 상자",
      "cell": [
        133,
        40
      ],
      "building": 24,
      "search": 6,
      "items": [
        "med_box"
      ],
      "locked": false,
      "level": 1,
      "searched": false
    },
    {
      "id": "north_box_44",
      "name": "둑 창고 안쪽 보관실 상자",
      "cell": [
        138,
        40
      ],
      "building": 24,
      "search": 6,
      "items": [
        "med_box"
      ],
      "locked": false,
      "level": 1,
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
        "med_box"
      ],
      "locked": false,
      "level": 0,
      "searched": false
    }
  ],
  "wagons": [],
  "entries": [
    [
      "북쪽 둑길",
      [
        [
          141,
          0
        ],
        [
          142,
          0
        ],
        [
          143,
          0
        ],
        [
          144,
          0
        ]
      ],
      0.6
    ],
    [
      "북쪽 붕대길",
      [
        [
          20,
          0
        ],
        [
          21,
          0
        ],
        [
          22,
          0
        ],
        [
          23,
          0
        ]
      ],
      0.6
    ],
    [
      "서쪽 약품길",
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
    ]
  ],
  "holes": [
    [
      "drain_01",
      [
        100,
        6
      ],
      "북로 가장자리 배수구"
    ]
  ],
  "barricades": [
    [
      15,
      22
    ],
    [
      16,
      22
    ],
    [
      37,
      22
    ],
    [
      38,
      22
    ],
    [
      83,
      22
    ],
    [
      85,
      22
    ]
  ],
  "deep": [
    [
      "K",
      "둑 창고"
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
    140,
    24,
    5,
    5
  ]
}


## 무전 문장에 쓰는 들어오는 길의 이름, 길마다의 비중, 첫 물결이 오는 길.
const ENTRY_NAMES: Dictionary = {"west_track": "서쪽 선로", "west_road": "서쪽 길", "south_lane": "남쪽 샛길", "south_bank": "남쪽 둑", "manhole_01": "첫째 맨홀", "manhole_02": "둘째 맨홀", "culvert_01": "암거", "북쪽 둑길": "북쪽 둑길", "북쪽 붕대길": "북쪽 붕대길", "서쪽 약품길": "서쪽 약품길", "drain_01": "배수구"}
const ENTRY_WEIGHTS: Dictionary = {"west_track": 1.0, "west_road": 1.0, "south_lane": 0.5, "south_bank": 1.0, "manhole_01": 0.3, "manhole_02": 0.3, "culvert_01": 1.0, "북쪽 둑길": 1.0, "북쪽 붕대길": 1.0, "서쪽 약품길": 1.0, "drain_01": 1.0}
const FIRST_ENTRY: String = "west_track"


static func build() -> Dictionary:
	var data: Dictionary = _build_plain()
	data["entry_names"] = ENTRY_NAMES.duplicate()
	data["entry_weights"] = ENTRY_WEIGHTS.duplicate()
	data["first_entry"] = FIRST_ENTRY
	return data
