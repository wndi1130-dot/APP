# 이 지도가 다른 판단을 만드는 것: 다리 둘을 막으면 조용하지만 건너간 사람이 돌아올 길이 없다.
# 위쪽의 판단: 무겁지만 많은 석탄을 얻는 대신, 사방이 트인 마당에서 싣게 되어 작업조가 드러나고 서쪽 야적 마당이 늘 열려 있다.
extends RefCounted

const MapShift = preload("res://game/world/map_shift.gd")
const FieldGrid = preload("res://game/world/field_grid.gd")
const S = FieldGrid.Solid
const F = FieldGrid.Floor
const PLACE_ID: String = "freight_06"
const WIDTH: int = 180
const SOUTH_HEIGHT: int = 105
const HEIGHT: int = SOUTH_HEIGHT + 45

# 좌표는 한 칸 단위다. 각 층의 방·문·가구를 독립적으로 기록한다.
const PLAN: Dictionary = {
  "id": "freight_06",
  "size": [180,105],
  "judgment": "다리 둘을 막으면 조용하지만 건너간 사람이 돌아올 길이 없다.",
  "resource": "scrap",
  "zones": [
    ["A","승강장과 측선",[0,0,180,105]],
    ["B","서쪽 창고 구획",[0,30,60,36]],
    ["C","큰 창고",[60,38,42,27]],
    ["D","동쪽 큰길",[102,22,78,30]],
    ["E","북쪽 부두",[100,52,80,20]],
    ["F","서쪽 부두",[0,66,100,6]],
    ["G","운하",[0,72,180,15]],
    ["H","남쪽 수문 구획",[0,87,180,18]]
  ],
  "floors": [
    [0,31,9,30,11,7],
    [0,89,10,27,21,7],
    [0,100,50,16,16,7],
    [0,4,60,34,6,7],
    [0,46,87,13,13,7],
    [0,108,89,16,11,7],
    [0,0,32,108,6,1],
    [0,102,32,6,18,1],
    [0,102,44,78,6,1],
    [0,40,32,6,66,1],
    [0,20,66,132,5,1],
    [0,132,70,4,20,1],
    [0,39,87,88,5,1],
    [0,39,100,115,4,1],
    [0,35,13,77,1,4],
    [0,35,19,77,1,4],
    [0,100,72,8,3,6],
    [0,114,78,8,3,6]
  ],
  "buildings": [
    {"id":0,"name":"창고 가","rect":[60,40,40,22],"warm":false,"window_broken":false},
    {"id":1,"name":"창고 나","rect":[116,52,28,14],"warm":false,"window_broken":false},
    {"id":2,"name":"창고 다","rect":[14,42,23,17],"warm":false,"window_broken":false},
    {"id":3,"name":"선구점","rect":[48,54,12,10],"warm":false,"window_broken":false},
    {"id":4,"name":"부두 사무소","rect":[12,10,18,12],"warm":false,"window_broken":false},
    {"id":5,"name":"신호 취급소","rect":[66,10,8,7],"warm":false,"window_broken":false},
    {"id":6,"name":"계량소","rect":[79,12,10,7],"warm":false,"window_broken":false},
    {"id":7,"name":"석탄 창고","rect":[118,22,17,11],"warm":false,"window_broken":false},
    {"id":8,"name":"구내 매점","rect":[14,23,12,9],"warm":false,"window_broken":false},
    {"id":9,"name":"밧줄 창고","rect":[148,24,14,10],"warm":false,"window_broken":false},
    {"id":10,"name":"공구 창고","rect":[155,54,12,9],"warm":false,"window_broken":false},
    {"id":11,"name":"변전실","rect":[166,12,10,8],"warm":false,"window_broken":false},
    {"id":12,"name":"숙직소","rect":[40,20,22,10],"warm":false,"window_broken":false},
    {"id":13,"name":"모래 창고","rect":[163,34,10,8],"warm":false,"window_broken":false},
    {"id":14,"name":"수문 관리소","rect":[126,90,25,14],"warm":false,"window_broken":false},
    {"id":15,"name":"장비 헛간","rect":[60,90,16,10],"warm":false,"window_broken":false},
    {"id":16,"name":"배 수리 헛간","rect":[90,90,16,10],"warm":false,"window_broken":false}
  ],
  "shells": [
    [0,0,60,40,40,22],
    [0,1,60,40,40,22],
    [0,2,60,40,40,22],
    [0,-1,60,40,40,22],
    [1,0,116,52,28,14],
    [1,1,116,52,28,14],
    [2,0,14,42,23,17],
    [2,1,14,42,23,17],
    [3,0,48,54,12,10],
    [4,0,12,10,18,12],
    [4,1,12,10,18,12],
    [5,0,66,10,8,7],
    [5,1,66,10,8,7],
    [6,0,79,12,10,7],
    [7,0,118,22,17,11],
    [8,0,14,23,12,9],
    [9,0,148,24,14,10],
    [10,0,155,54,12,9],
    [11,0,166,12,10,8],
    [12,0,40,20,22,10],
    [12,1,40,20,22,10],
    [13,0,163,34,10,8],
    [14,0,126,90,25,14],
    [14,1,126,90,25,14],
    [15,0,60,90,16,10],
    [16,0,90,90,16,10]
  ],
  "walls": [
    [0,61,49,38,1],
    [0,61,52,38,1],
    [0,66,41,1,8],
    [0,73,41,1,8],
    [0,79,41,1,8],
    [0,86,41,1,8],
    [0,92,41,1,8],
    [0,66,53,1,8],
    [0,73,53,1,8],
    [0,79,53,1,8],
    [0,86,53,1,8],
    [0,92,53,1,8],
    [1,61,49,38,1],
    [1,61,52,38,1],
    [1,66,41,1,8],
    [1,73,41,1,8],
    [1,79,41,1,8],
    [1,86,41,1,8],
    [1,92,41,1,8],
    [1,66,53,1,8],
    [1,73,53,1,8],
    [1,79,53,1,8],
    [1,86,53,1,8],
    [1,92,53,1,8],
    [2,61,49,38,1],
    [2,61,52,38,1],
    [2,66,41,1,8],
    [2,73,41,1,8],
    [2,79,41,1,8],
    [2,86,41,1,8],
    [2,92,41,1,8],
    [2,66,53,1,8],
    [2,73,53,1,8],
    [2,79,53,1,8],
    [2,86,53,1,8],
    [2,92,53,1,8],
    [-1,61,49,38,1],
    [-1,61,52,38,1],
    [-1,66,41,1,8],
    [-1,73,41,1,8],
    [-1,79,41,1,8],
    [-1,86,41,1,8],
    [-1,92,41,1,8],
    [-1,66,53,1,8],
    [-1,73,53,1,8],
    [-1,79,53,1,8],
    [-1,86,53,1,8],
    [-1,92,53,1,8],
    [0,117,57,26,1],
    [0,117,60,26,1],
    [0,129,53,1,4],
    [0,129,61,1,4],
    [1,117,57,26,1],
    [1,117,60,26,1],
    [1,129,53,1,4],
    [1,129,61,1,4],
    [0,15,48,21,1],
    [0,15,51,21,1],
    [0,25,43,1,5],
    [0,25,52,1,6],
    [1,15,48,21,1],
    [1,15,51,21,1],
    [1,25,43,1,5],
    [1,25,52,1,6],
    [0,49,59,10,1],
    [0,21,11,1,10],
    [1,21,11,1,10],
    [0,126,23,1,9],
    [0,15,27,10,1],
    [0,155,25,1,8],
    [0,161,55,1,7],
    [0,51,21,1,8],
    [1,51,21,1,8],
    [0,138,91,1,12],
    [1,138,91,1,12],
    [0,68,91,1,8],
    [0,98,91,1,8]
  ],
  "openings": [],
  "doors": [
    [0,63,49,0,"closed",0,1],
    [0,69,49,0,"closed",0,1],
    [0,76,49,0,"closed",0,1],
    [0,82,49,0,"closed",0,1],
    [0,89,49,0,"closed",0,1],
    [0,95,49,0,"closed",0,1],
    [0,63,52,0,"closed",0,-1],
    [0,69,52,0,"closed",0,-1],
    [0,76,52,0,"closed",0,-1],
    [0,82,52,0,"closed",0,-1],
    [0,89,52,0,"closed",0,-1],
    [0,95,52,0,"closed",0,-1],
    [1,63,49,0,"closed",0,1],
    [1,69,49,0,"closed",0,1],
    [1,76,49,0,"closed",0,1],
    [1,82,49,0,"closed",0,1],
    [1,89,49,0,"closed",0,1],
    [1,95,49,0,"closed",0,1],
    [1,63,52,0,"closed",0,-1],
    [1,69,52,0,"closed",0,-1],
    [1,76,52,0,"closed",0,-1],
    [1,82,52,0,"closed",0,-1],
    [1,89,52,0,"closed",0,-1],
    [1,95,52,0,"closed",0,-1],
    [2,63,49,0,"closed",0,1],
    [2,69,49,0,"closed",0,1],
    [2,76,49,0,"closed",0,1],
    [2,82,49,0,"closed",0,1],
    [2,89,49,0,"closed",0,1],
    [2,95,49,0,"closed",0,1],
    [2,63,52,0,"closed",0,-1],
    [2,69,52,0,"closed",0,-1],
    [2,76,52,0,"closed",0,-1],
    [2,82,52,0,"closed",0,-1],
    [2,89,52,0,"closed",0,-1],
    [2,95,52,0,"closed",0,-1],
    [-1,63,49,0,"closed",0,1],
    [-1,69,49,0,"closed",0,1],
    [-1,76,49,0,"closed",0,1],
    [-1,82,49,0,"closed",0,1],
    [-1,89,49,0,"closed",0,1],
    [-1,95,49,0,"closed",0,1],
    [-1,63,52,0,"closed",0,-1],
    [-1,69,52,0,"closed",0,-1],
    [-1,76,52,0,"closed",0,-1],
    [-1,82,52,0,"closed",0,-1],
    [-1,89,52,0,"closed",0,-1],
    [-1,95,52,0,"closed",0,-1],
    [0,73,40,0,"closed",0,-1],
    [0,60,50,0,"closed",-1,0],
    [0,99,50,0,"closed",1,0],
    [0,122,57,1,"closed",0,1],
    [0,136,57,1,"closed",0,1],
    [0,122,60,1,"closed",0,-1],
    [0,136,60,1,"closed",0,-1],
    [1,122,57,1,"closed",0,1],
    [1,136,57,1,"closed",0,1],
    [1,122,60,1,"closed",0,-1],
    [1,136,60,1,"closed",0,-1],
    [0,116,58,1,"closed",-1,0],
    [0,143,58,1,"closed",1,0],
    [0,19,48,2,"closed",0,1],
    [0,30,48,2,"closed",0,1],
    [0,19,51,2,"closed",0,-1],
    [0,30,51,2,"closed",0,-1],
    [1,19,48,2,"closed",0,1],
    [1,30,48,2,"closed",0,1],
    [1,19,51,2,"closed",0,-1],
    [1,30,51,2,"closed",0,-1],
    [0,14,49,2,"closed",-1,0],
    [0,36,49,2,"closed",1,0],
    [0,57,59,3,"closed",0,1],
    [0,52,54,3,"closed",0,-1],
    [0,57,63,3,"closed",0,1],
    [0,21,16,4,"closed",1,0],
    [1,21,16,4,"closed",1,0],
    [0,18,10,4,"closed",0,-1],
    [0,27,21,4,"closed",0,1],
    [0,68,10,5,"closed",0,-1],
    [0,71,16,5,"closed",0,1],
    [0,82,12,6,"closed",0,-1],
    [0,86,18,6,"closed",0,1],
    [0,126,27,7,"closed",1,0],
    [0,123,22,7,"closed",0,-1],
    [0,132,32,7,"closed",0,1],
    [0,23,27,8,"closed",0,1],
    [0,14,25,8,"closed",-1,0],
    [0,25,29,8,"closed",1,0],
    [0,155,29,9,"closed",1,0],
    [0,152,24,9,"closed",0,-1],
    [0,159,33,9,"closed",0,1],
    [0,161,58,10,"closed",1,0],
    [0,159,54,10,"closed",0,-1],
    [0,164,62,10,"closed",0,1],
    [0,169,12,11,"closed",0,-1],
    [0,173,19,11,"closed",0,1],
    [0,51,25,12,"closed",1,0],
    [1,51,25,12,"closed",1,0],
    [0,47,20,12,"closed",0,-1],
    [0,59,29,12,"closed",0,1],
    [0,166,34,13,"closed",0,-1],
    [0,170,41,13,"closed",0,1],
    [0,138,97,14,"closed",1,0],
    [1,138,97,14,"closed",1,0],
    [0,126,97,14,"closed",-1,0],
    [0,150,97,14,"closed",1,0],
    [0,68,95,15,"closed",1,0],
    [0,65,90,15,"closed",0,-1],
    [0,73,99,15,"closed",0,1],
    [0,98,95,16,"closed",1,0],
    [0,95,90,16,"closed",0,-1],
    [0,103,99,16,"closed",0,1]
  ],
  "windows": [
    [0,63,40,0],
    [0,70,40,0],
    [0,77,40,0],
    [0,84,40,0],
    [0,91,40,0],
    [0,99,43,0],
    [0,99,49,0],
    [0,99,55,0],
    [1,63,40,0],
    [1,70,40,0],
    [1,77,40,0],
    [1,84,40,0],
    [1,91,40,0],
    [1,99,43,0],
    [1,99,49,0],
    [1,99,55,0],
    [2,63,40,0],
    [2,70,40,0],
    [2,77,40,0],
    [2,84,40,0],
    [2,91,40,0],
    [2,99,43,0],
    [2,99,49,0],
    [2,99,55,0],
    [0,119,52,1],
    [0,126,52,1],
    [0,133,52,1],
    [0,140,52,1],
    [0,143,55,1],
    [0,143,61,1],
    [1,119,52,1],
    [1,126,52,1],
    [1,133,52,1],
    [1,140,52,1],
    [1,143,55,1],
    [1,143,61,1],
    [0,17,42,2],
    [0,24,42,2],
    [0,31,42,2],
    [0,36,45,2],
    [0,36,51,2],
    [1,17,42,2],
    [1,24,42,2],
    [1,31,42,2],
    [1,36,45,2],
    [1,36,51,2],
    [0,51,54,3],
    [0,59,57,3],
    [0,15,10,4],
    [0,22,10,4],
    [0,29,13,4],
    [0,29,19,4],
    [1,15,10,4],
    [1,22,10,4],
    [1,29,13,4],
    [1,29,19,4],
    [0,69,10,5],
    [0,73,13,5],
    [1,69,10,5],
    [1,73,13,5],
    [0,82,12,6],
    [0,88,15,6],
    [0,121,22,7],
    [0,128,22,7],
    [0,134,25,7],
    [0,17,23,8],
    [0,25,26,8],
    [0,151,24,9],
    [0,158,24,9],
    [0,161,27,9],
    [0,158,54,10],
    [0,166,57,10],
    [0,169,12,11],
    [0,175,15,11],
    [0,43,20,12],
    [0,50,20,12],
    [0,57,20,12],
    [0,61,23,12],
    [1,43,20,12],
    [1,50,20,12],
    [1,57,20,12],
    [1,61,23,12],
    [0,166,34,13],
    [0,172,37,13],
    [0,129,90,14],
    [0,136,90,14],
    [0,143,90,14],
    [0,150,93,14],
    [0,150,99,14],
    [1,129,90,14],
    [1,136,90,14],
    [1,143,90,14],
    [1,150,93,14],
    [1,150,99,14],
    [0,63,90,15],
    [0,70,90,15],
    [0,75,93,15],
    [0,93,90,16],
    [0,100,90,16],
    [0,105,93,16]
  ],
  "rooms": [
    {"building":0,"level":0,"rect":[61,41,5,8],"name":"사무실"},
    {"building":0,"level":0,"rect":[67,41,6,8],"name":"선별실"},
    {"building":0,"level":0,"rect":[74,41,5,8],"name":"선반 칸"},
    {"building":0,"level":0,"rect":[80,41,6,8],"name":"계량실"},
    {"building":0,"level":0,"rect":[87,41,5,8],"name":"안쪽 창고"},
    {"building":0,"level":0,"rect":[93,41,6,8],"name":"기록실"},
    {"building":0,"level":0,"rect":[61,53,5,8],"name":"사무실"},
    {"building":0,"level":0,"rect":[67,53,6,8],"name":"선별실"},
    {"building":0,"level":0,"rect":[74,53,5,8],"name":"선반 칸"},
    {"building":0,"level":0,"rect":[80,53,6,8],"name":"계량실"},
    {"building":0,"level":0,"rect":[87,53,5,8],"name":"안쪽 창고"},
    {"building":0,"level":0,"rect":[93,53,6,8],"name":"기록실"},
    {"building":0,"level":1,"rect":[61,41,5,8],"name":"사무실"},
    {"building":0,"level":1,"rect":[67,41,6,8],"name":"선별실"},
    {"building":0,"level":1,"rect":[74,41,5,8],"name":"선반 칸"},
    {"building":0,"level":1,"rect":[80,41,6,8],"name":"계량실"},
    {"building":0,"level":1,"rect":[87,41,5,8],"name":"안쪽 창고"},
    {"building":0,"level":1,"rect":[93,41,6,8],"name":"기록실"},
    {"building":0,"level":1,"rect":[61,53,5,8],"name":"사무실"},
    {"building":0,"level":1,"rect":[67,53,6,8],"name":"선별실"},
    {"building":0,"level":1,"rect":[74,53,5,8],"name":"선반 칸"},
    {"building":0,"level":1,"rect":[80,53,6,8],"name":"계량실"},
    {"building":0,"level":1,"rect":[87,53,5,8],"name":"안쪽 창고"},
    {"building":0,"level":1,"rect":[93,53,6,8],"name":"기록실"},
    {"building":0,"level":2,"rect":[61,41,5,8],"name":"사무실"},
    {"building":0,"level":2,"rect":[67,41,6,8],"name":"선별실"},
    {"building":0,"level":2,"rect":[74,41,5,8],"name":"선반 칸"},
    {"building":0,"level":2,"rect":[80,41,6,8],"name":"계량실"},
    {"building":0,"level":2,"rect":[87,41,5,8],"name":"안쪽 창고"},
    {"building":0,"level":2,"rect":[93,41,6,8],"name":"기록실"},
    {"building":0,"level":2,"rect":[61,53,5,8],"name":"사무실"},
    {"building":0,"level":2,"rect":[67,53,6,8],"name":"선별실"},
    {"building":0,"level":2,"rect":[74,53,5,8],"name":"선반 칸"},
    {"building":0,"level":2,"rect":[80,53,6,8],"name":"계량실"},
    {"building":0,"level":2,"rect":[87,53,5,8],"name":"안쪽 창고"},
    {"building":0,"level":2,"rect":[93,53,6,8],"name":"기록실"},
    {"building":0,"level":-1,"rect":[61,41,5,8],"name":"저장고"},
    {"building":0,"level":-1,"rect":[67,41,6,8],"name":"냉기 칸"},
    {"building":0,"level":-1,"rect":[74,41,5,8],"name":"안쪽 보관실"},
    {"building":0,"level":-1,"rect":[80,41,6,8],"name":"저장고"},
    {"building":0,"level":-1,"rect":[87,41,5,8],"name":"냉기 칸"},
    {"building":0,"level":-1,"rect":[93,41,6,8],"name":"안쪽 보관실"},
    {"building":0,"level":-1,"rect":[61,53,5,8],"name":"저장고"},
    {"building":0,"level":-1,"rect":[67,53,6,8],"name":"냉기 칸"},
    {"building":0,"level":-1,"rect":[74,53,5,8],"name":"안쪽 보관실"},
    {"building":0,"level":-1,"rect":[80,53,6,8],"name":"저장고"},
    {"building":0,"level":-1,"rect":[87,53,5,8],"name":"냉기 칸"},
    {"building":0,"level":-1,"rect":[93,53,6,8],"name":"안쪽 보관실"},
    {"building":1,"level":0,"rect":[117,53,12,4],"name":"사무실"},
    {"building":1,"level":0,"rect":[130,53,13,4],"name":"선별실"},
    {"building":1,"level":0,"rect":[117,61,12,4],"name":"사무실"},
    {"building":1,"level":0,"rect":[130,61,13,4],"name":"선별실"},
    {"building":1,"level":1,"rect":[117,53,12,4],"name":"사무실"},
    {"building":1,"level":1,"rect":[130,53,13,4],"name":"선별실"},
    {"building":1,"level":1,"rect":[117,61,12,4],"name":"사무실"},
    {"building":1,"level":1,"rect":[130,61,13,4],"name":"선별실"},
    {"building":2,"level":0,"rect":[15,43,10,5],"name":"사무실"},
    {"building":2,"level":0,"rect":[26,43,10,5],"name":"선별실"},
    {"building":2,"level":0,"rect":[15,52,10,6],"name":"사무실"},
    {"building":2,"level":0,"rect":[26,52,10,6],"name":"선별실"},
    {"building":2,"level":1,"rect":[15,43,10,5],"name":"사무실"},
    {"building":2,"level":1,"rect":[26,43,10,5],"name":"선별실"},
    {"building":2,"level":1,"rect":[15,52,10,6],"name":"사무실"},
    {"building":2,"level":1,"rect":[26,52,10,6],"name":"선별실"},
    {"building":3,"level":0,"rect":[49,55,10,4],"name":"매장"},
    {"building":3,"level":0,"rect":[49,60,10,3],"name":"뒤 창고"},
    {"building":4,"level":0,"rect":[13,11,8,10],"name":"앞방"},
    {"building":4,"level":0,"rect":[22,11,7,10],"name":"안쪽 방"},
    {"building":4,"level":1,"rect":[13,11,8,10],"name":"앞방"},
    {"building":4,"level":1,"rect":[22,11,7,10],"name":"안쪽 방"},
    {"building":5,"level":0,"rect":[67,11,6,5],"name":"작업실"},
    {"building":5,"level":1,"rect":[67,11,6,5],"name":"작업실"},
    {"building":6,"level":0,"rect":[80,13,8,5],"name":"작업실"},
    {"building":7,"level":0,"rect":[119,23,7,9],"name":"앞방"},
    {"building":7,"level":0,"rect":[127,23,7,9],"name":"안쪽 방"},
    {"building":8,"level":0,"rect":[15,24,10,3],"name":"매장"},
    {"building":8,"level":0,"rect":[15,28,10,3],"name":"뒤 창고"},
    {"building":9,"level":0,"rect":[149,25,6,8],"name":"앞방"},
    {"building":9,"level":0,"rect":[156,25,5,8],"name":"안쪽 방"},
    {"building":10,"level":0,"rect":[156,55,5,7],"name":"앞방"},
    {"building":10,"level":0,"rect":[162,55,4,7],"name":"안쪽 방"},
    {"building":11,"level":0,"rect":[167,13,8,6],"name":"작업실"},
    {"building":12,"level":0,"rect":[41,21,10,8],"name":"앞방"},
    {"building":12,"level":0,"rect":[52,21,9,8],"name":"안쪽 방"},
    {"building":12,"level":1,"rect":[41,21,10,8],"name":"앞방"},
    {"building":12,"level":1,"rect":[52,21,9,8],"name":"안쪽 방"},
    {"building":13,"level":0,"rect":[164,35,8,6],"name":"작업실"},
    {"building":14,"level":0,"rect":[127,91,11,12],"name":"앞방"},
    {"building":14,"level":0,"rect":[139,91,11,12],"name":"안쪽 방"},
    {"building":14,"level":1,"rect":[127,91,11,12],"name":"앞방"},
    {"building":14,"level":1,"rect":[139,91,11,12],"name":"안쪽 방"},
    {"building":15,"level":0,"rect":[61,91,7,8],"name":"앞방"},
    {"building":15,"level":0,"rect":[69,91,6,8],"name":"안쪽 방"},
    {"building":16,"level":0,"rect":[91,91,7,8],"name":"앞방"},
    {"building":16,"level":0,"rect":[99,91,6,8],"name":"안쪽 방"}
  ],
  "stairs": [
    {"cell":[62,50],"low":0,"high":1,"ladder":false},
    {"cell":[62,50],"low":1,"high":2,"ladder":false},
    {"cell":[62,50],"low":-1,"high":0,"ladder":false},
    {"cell":[97,50],"low":0,"high":1,"ladder":false},
    {"cell":[97,50],"low":1,"high":2,"ladder":false},
    {"cell":[97,50],"low":-1,"high":0,"ladder":false},
    {"cell":[118,58],"low":0,"high":1,"ladder":false},
    {"cell":[141,58],"low":0,"high":1,"ladder":false},
    {"cell":[16,49],"low":0,"high":1,"ladder":false},
    {"cell":[34,49],"low":0,"high":1,"ladder":false},
    {"cell":[14,12],"low":0,"high":1,"ladder":false},
    {"cell":[68,12],"low":0,"high":1,"ladder":false},
    {"cell":[42,22],"low":0,"high":1,"ladder":false},
    {"cell":[128,92],"low":0,"high":1,"ladder":false}
  ],
  "props": [
    {"kind":"flat_wagon","rect":[35,12,12,3],"solid":"wagon","facing":0,"note":"평판 화차","level":0},
    {"kind":"flat_wagon","rect":[52,12,9,3],"solid":"wagon","facing":0,"note":"평판 화차","level":0},
    {"kind":"flat_wagon","rect":[93,18,12,3],"solid":"wagon","facing":0,"note":"평판 화차","level":0},
    {"kind":"sluice_frame","rect":[126,70,6,2],"solid":"wall","facing":0,"note":"수문 틀","level":0},
    {"kind":"sluice_frame","rect":[136,87,6,2],"solid":"wall","facing":0,"note":"수문 틀","level":0},
    {"kind":"lock_wheel","rect":[131,69,1,1],"solid":"low","facing":0,"note":"수문 바퀴","level":0},
    {"kind":"lock_wheel","rect":[136,89,1,1],"solid":"low","facing":0,"note":"수문 바퀴","level":0},
    {"kind":"quay_crane","rect":[108,66,5,5],"solid":"wall","facing":0,"note":"부두 기중기","level":0},
    {"kind":"car","rect":[39,98,4,2],"solid":"low","facing":0,"note":"버려진 차","level":0},
    {"kind":"car","rect":[44,97,4,2],"solid":"low","facing":0,"note":"버려진 차","level":0},
    {"kind":"car","rect":[166,48,4,2],"solid":"low","facing":0,"note":"버려진 차","level":0},
    {"kind":"frozen_barge","rect":[100,72,8,3],"solid":"low","facing":0,"note":"언 바지선","level":0},
    {"kind":"frozen_barge","rect":[114,78,8,3],"solid":"low","facing":0,"note":"언 바지선","level":0},
    {"kind":"sleeper_pile","rect":[28,8,3,2],"solid":"low","facing":0,"note":"침목 더미","level":0},
    {"kind":"rail_pile","rect":[59,8,3,1],"solid":"low","facing":0,"note":"레일 더미","level":0},
    {"kind":"sack_pile","rect":[99,24,2,2],"solid":"low","facing":0,"note":"자루 더미","level":0},
    {"kind":"crate_stack","rect":[5,24,2,2],"solid":"low","facing":0,"note":"나무 상자 더미","level":0},
    {"kind":"water","rect":[0,72,40,11],"solid":"low","facing":0,"note":"물","level":0},
    {"kind":"water","rect":[46,77,30,10],"solid":"low","facing":0,"note":"물","level":0},
    {"kind":"water","rect":[76,75,30,7],"solid":"low","facing":0,"note":"물","level":0},
    {"kind":"water","rect":[76,73,24,2],"solid":"low","facing":0,"note":"물","level":0},
    {"kind":"water","rect":[106,81,26,6],"solid":"low","facing":0,"note":"물","level":0},
    {"kind":"water","rect":[106,79,8,2],"solid":"low","facing":0,"note":"물","level":0},
    {"kind":"water","rect":[122,79,10,2],"solid":"low","facing":0,"note":"물","level":0},
    {"kind":"water","rect":[136,72,44,9],"solid":"low","facing":0,"note":"물","level":0},
    {"kind":"shelf","rect":[61,41,3,1],"solid":"low","facing":0,"note":"창고 가 사무실 선반","level":0},
    {"kind":"part_crate","rect":[61,48,1,1],"solid":"low","facing":0,"note":"창고 가 사무실 부품 상자","level":0},
    {"kind":"barrel","rect":[64,41,1,1],"solid":"low","facing":0,"note":"창고 가 사무실 통","level":0},
    {"kind":"shelf","rect":[67,41,3,1],"solid":"low","facing":0,"note":"창고 가 선별실 선반","level":0},
    {"kind":"part_crate","rect":[70,48,1,1],"solid":"low","facing":0,"note":"창고 가 선별실 부품 상자","level":0},
    {"kind":"barrel","rect":[67,48,1,1],"solid":"low","facing":0,"note":"창고 가 선별실 통","level":0},
    {"kind":"shelf","rect":[74,41,3,1],"solid":"low","facing":0,"note":"창고 가 선반 칸 선반","level":0},
    {"kind":"part_crate","rect":[74,48,1,1],"solid":"low","facing":0,"note":"창고 가 선반 칸 부품 상자","level":0},
    {"kind":"barrel","rect":[77,41,1,1],"solid":"low","facing":0,"note":"창고 가 선반 칸 통","level":0},
    {"kind":"shelf","rect":[80,41,3,1],"solid":"low","facing":0,"note":"창고 가 계량실 선반","level":0},
    {"kind":"part_crate","rect":[83,48,1,1],"solid":"low","facing":0,"note":"창고 가 계량실 부품 상자","level":0},
    {"kind":"barrel","rect":[80,48,1,1],"solid":"low","facing":0,"note":"창고 가 계량실 통","level":0},
    {"kind":"shelf","rect":[87,41,3,1],"solid":"low","facing":0,"note":"창고 가 안쪽 창고 선반","level":0},
    {"kind":"part_crate","rect":[87,48,1,1],"solid":"low","facing":0,"note":"창고 가 안쪽 창고 부품 상자","level":0},
    {"kind":"barrel","rect":[90,41,1,1],"solid":"low","facing":0,"note":"창고 가 안쪽 창고 통","level":0},
    {"kind":"shelf","rect":[93,41,3,1],"solid":"low","facing":0,"note":"창고 가 기록실 선반","level":0},
    {"kind":"part_crate","rect":[96,48,1,1],"solid":"low","facing":0,"note":"창고 가 기록실 부품 상자","level":0},
    {"kind":"barrel","rect":[93,48,1,1],"solid":"low","facing":0,"note":"창고 가 기록실 통","level":0},
    {"kind":"shelf","rect":[61,60,3,1],"solid":"low","facing":0,"note":"창고 가 사무실 선반","level":0},
    {"kind":"part_crate","rect":[61,53,1,1],"solid":"low","facing":0,"note":"창고 가 사무실 부품 상자","level":0},
    {"kind":"barrel","rect":[64,53,1,1],"solid":"low","facing":0,"note":"창고 가 사무실 통","level":0},
    {"kind":"shelf","rect":[67,60,3,1],"solid":"low","facing":0,"note":"창고 가 선별실 선반","level":0},
    {"kind":"part_crate","rect":[67,53,1,1],"solid":"low","facing":0,"note":"창고 가 선별실 부품 상자","level":0},
    {"kind":"barrel","rect":[70,60,1,1],"solid":"low","facing":0,"note":"창고 가 선별실 통","level":0},
    {"kind":"shelf","rect":[74,60,3,1],"solid":"low","facing":0,"note":"창고 가 선반 칸 선반","level":0},
    {"kind":"part_crate","rect":[74,53,1,1],"solid":"low","facing":0,"note":"창고 가 선반 칸 부품 상자","level":0},
    {"kind":"barrel","rect":[77,53,1,1],"solid":"low","facing":0,"note":"창고 가 선반 칸 통","level":0},
    {"kind":"shelf","rect":[80,60,3,1],"solid":"low","facing":0,"note":"창고 가 계량실 선반","level":0},
    {"kind":"part_crate","rect":[80,53,1,1],"solid":"low","facing":0,"note":"창고 가 계량실 부품 상자","level":0},
    {"kind":"barrel","rect":[83,60,1,1],"solid":"low","facing":0,"note":"창고 가 계량실 통","level":0},
    {"kind":"shelf","rect":[87,60,3,1],"solid":"low","facing":0,"note":"창고 가 안쪽 창고 선반","level":0},
    {"kind":"part_crate","rect":[87,53,1,1],"solid":"low","facing":0,"note":"창고 가 안쪽 창고 부품 상자","level":0},
    {"kind":"barrel","rect":[90,53,1,1],"solid":"low","facing":0,"note":"창고 가 안쪽 창고 통","level":0},
    {"kind":"shelf","rect":[93,60,3,1],"solid":"low","facing":0,"note":"창고 가 기록실 선반","level":0},
    {"kind":"part_crate","rect":[93,53,1,1],"solid":"low","facing":0,"note":"창고 가 기록실 부품 상자","level":0},
    {"kind":"barrel","rect":[96,60,1,1],"solid":"low","facing":0,"note":"창고 가 기록실 통","level":0},
    {"kind":"shelf","rect":[61,41,3,1],"solid":"none","facing":0,"note":"창고 가 사무실 선반","level":1},
    {"kind":"part_crate","rect":[61,48,1,1],"solid":"none","facing":0,"note":"창고 가 사무실 부품 상자","level":1},
    {"kind":"barrel","rect":[64,41,1,1],"solid":"none","facing":0,"note":"창고 가 사무실 통","level":1},
    {"kind":"shelf","rect":[67,41,3,1],"solid":"none","facing":0,"note":"창고 가 선별실 선반","level":1},
    {"kind":"part_crate","rect":[70,48,1,1],"solid":"none","facing":0,"note":"창고 가 선별실 부품 상자","level":1},
    {"kind":"barrel","rect":[67,48,1,1],"solid":"none","facing":0,"note":"창고 가 선별실 통","level":1},
    {"kind":"shelf","rect":[74,41,3,1],"solid":"none","facing":0,"note":"창고 가 선반 칸 선반","level":1},
    {"kind":"part_crate","rect":[74,48,1,1],"solid":"none","facing":0,"note":"창고 가 선반 칸 부품 상자","level":1},
    {"kind":"barrel","rect":[77,41,1,1],"solid":"none","facing":0,"note":"창고 가 선반 칸 통","level":1},
    {"kind":"shelf","rect":[80,41,3,1],"solid":"none","facing":0,"note":"창고 가 계량실 선반","level":1},
    {"kind":"part_crate","rect":[83,48,1,1],"solid":"none","facing":0,"note":"창고 가 계량실 부품 상자","level":1},
    {"kind":"barrel","rect":[80,48,1,1],"solid":"none","facing":0,"note":"창고 가 계량실 통","level":1},
    {"kind":"shelf","rect":[87,41,3,1],"solid":"none","facing":0,"note":"창고 가 안쪽 창고 선반","level":1},
    {"kind":"part_crate","rect":[87,48,1,1],"solid":"none","facing":0,"note":"창고 가 안쪽 창고 부품 상자","level":1},
    {"kind":"barrel","rect":[90,41,1,1],"solid":"none","facing":0,"note":"창고 가 안쪽 창고 통","level":1},
    {"kind":"shelf","rect":[93,41,3,1],"solid":"none","facing":0,"note":"창고 가 기록실 선반","level":1},
    {"kind":"part_crate","rect":[96,48,1,1],"solid":"none","facing":0,"note":"창고 가 기록실 부품 상자","level":1},
    {"kind":"barrel","rect":[93,48,1,1],"solid":"none","facing":0,"note":"창고 가 기록실 통","level":1},
    {"kind":"shelf","rect":[61,60,3,1],"solid":"none","facing":0,"note":"창고 가 사무실 선반","level":1},
    {"kind":"part_crate","rect":[61,53,1,1],"solid":"none","facing":0,"note":"창고 가 사무실 부품 상자","level":1},
    {"kind":"barrel","rect":[64,53,1,1],"solid":"none","facing":0,"note":"창고 가 사무실 통","level":1},
    {"kind":"shelf","rect":[67,60,3,1],"solid":"none","facing":0,"note":"창고 가 선별실 선반","level":1},
    {"kind":"part_crate","rect":[67,53,1,1],"solid":"none","facing":0,"note":"창고 가 선별실 부품 상자","level":1},
    {"kind":"barrel","rect":[70,60,1,1],"solid":"none","facing":0,"note":"창고 가 선별실 통","level":1},
    {"kind":"shelf","rect":[74,60,3,1],"solid":"none","facing":0,"note":"창고 가 선반 칸 선반","level":1},
    {"kind":"part_crate","rect":[74,53,1,1],"solid":"none","facing":0,"note":"창고 가 선반 칸 부품 상자","level":1},
    {"kind":"barrel","rect":[77,53,1,1],"solid":"none","facing":0,"note":"창고 가 선반 칸 통","level":1},
    {"kind":"shelf","rect":[80,60,3,1],"solid":"none","facing":0,"note":"창고 가 계량실 선반","level":1},
    {"kind":"part_crate","rect":[80,53,1,1],"solid":"none","facing":0,"note":"창고 가 계량실 부품 상자","level":1},
    {"kind":"barrel","rect":[83,60,1,1],"solid":"none","facing":0,"note":"창고 가 계량실 통","level":1},
    {"kind":"shelf","rect":[87,60,3,1],"solid":"none","facing":0,"note":"창고 가 안쪽 창고 선반","level":1},
    {"kind":"part_crate","rect":[87,53,1,1],"solid":"none","facing":0,"note":"창고 가 안쪽 창고 부품 상자","level":1},
    {"kind":"barrel","rect":[90,53,1,1],"solid":"none","facing":0,"note":"창고 가 안쪽 창고 통","level":1},
    {"kind":"shelf","rect":[93,60,3,1],"solid":"none","facing":0,"note":"창고 가 기록실 선반","level":1},
    {"kind":"part_crate","rect":[93,53,1,1],"solid":"none","facing":0,"note":"창고 가 기록실 부품 상자","level":1},
    {"kind":"barrel","rect":[96,60,1,1],"solid":"none","facing":0,"note":"창고 가 기록실 통","level":1},
    {"kind":"shelf","rect":[61,41,3,1],"solid":"none","facing":0,"note":"창고 가 사무실 선반","level":2},
    {"kind":"part_crate","rect":[61,48,1,1],"solid":"none","facing":0,"note":"창고 가 사무실 부품 상자","level":2},
    {"kind":"barrel","rect":[64,41,1,1],"solid":"none","facing":0,"note":"창고 가 사무실 통","level":2},
    {"kind":"shelf","rect":[67,41,3,1],"solid":"none","facing":0,"note":"창고 가 선별실 선반","level":2},
    {"kind":"part_crate","rect":[70,48,1,1],"solid":"none","facing":0,"note":"창고 가 선별실 부품 상자","level":2},
    {"kind":"barrel","rect":[67,48,1,1],"solid":"none","facing":0,"note":"창고 가 선별실 통","level":2},
    {"kind":"shelf","rect":[74,41,3,1],"solid":"none","facing":0,"note":"창고 가 선반 칸 선반","level":2},
    {"kind":"part_crate","rect":[74,48,1,1],"solid":"none","facing":0,"note":"창고 가 선반 칸 부품 상자","level":2},
    {"kind":"barrel","rect":[77,41,1,1],"solid":"none","facing":0,"note":"창고 가 선반 칸 통","level":2},
    {"kind":"shelf","rect":[80,41,3,1],"solid":"none","facing":0,"note":"창고 가 계량실 선반","level":2},
    {"kind":"part_crate","rect":[83,48,1,1],"solid":"none","facing":0,"note":"창고 가 계량실 부품 상자","level":2},
    {"kind":"barrel","rect":[80,48,1,1],"solid":"none","facing":0,"note":"창고 가 계량실 통","level":2},
    {"kind":"shelf","rect":[87,41,3,1],"solid":"none","facing":0,"note":"창고 가 안쪽 창고 선반","level":2},
    {"kind":"part_crate","rect":[87,48,1,1],"solid":"none","facing":0,"note":"창고 가 안쪽 창고 부품 상자","level":2},
    {"kind":"barrel","rect":[90,41,1,1],"solid":"none","facing":0,"note":"창고 가 안쪽 창고 통","level":2},
    {"kind":"shelf","rect":[93,41,3,1],"solid":"none","facing":0,"note":"창고 가 기록실 선반","level":2},
    {"kind":"part_crate","rect":[96,48,1,1],"solid":"none","facing":0,"note":"창고 가 기록실 부품 상자","level":2},
    {"kind":"barrel","rect":[93,48,1,1],"solid":"none","facing":0,"note":"창고 가 기록실 통","level":2},
    {"kind":"shelf","rect":[61,60,3,1],"solid":"none","facing":0,"note":"창고 가 사무실 선반","level":2},
    {"kind":"part_crate","rect":[61,53,1,1],"solid":"none","facing":0,"note":"창고 가 사무실 부품 상자","level":2},
    {"kind":"barrel","rect":[64,53,1,1],"solid":"none","facing":0,"note":"창고 가 사무실 통","level":2},
    {"kind":"shelf","rect":[67,60,3,1],"solid":"none","facing":0,"note":"창고 가 선별실 선반","level":2},
    {"kind":"part_crate","rect":[67,53,1,1],"solid":"none","facing":0,"note":"창고 가 선별실 부품 상자","level":2},
    {"kind":"barrel","rect":[70,60,1,1],"solid":"none","facing":0,"note":"창고 가 선별실 통","level":2},
    {"kind":"shelf","rect":[74,60,3,1],"solid":"none","facing":0,"note":"창고 가 선반 칸 선반","level":2},
    {"kind":"part_crate","rect":[74,53,1,1],"solid":"none","facing":0,"note":"창고 가 선반 칸 부품 상자","level":2},
    {"kind":"barrel","rect":[77,53,1,1],"solid":"none","facing":0,"note":"창고 가 선반 칸 통","level":2},
    {"kind":"shelf","rect":[80,60,3,1],"solid":"none","facing":0,"note":"창고 가 계량실 선반","level":2},
    {"kind":"part_crate","rect":[80,53,1,1],"solid":"none","facing":0,"note":"창고 가 계량실 부품 상자","level":2},
    {"kind":"barrel","rect":[83,60,1,1],"solid":"none","facing":0,"note":"창고 가 계량실 통","level":2},
    {"kind":"shelf","rect":[87,60,3,1],"solid":"none","facing":0,"note":"창고 가 안쪽 창고 선반","level":2},
    {"kind":"part_crate","rect":[87,53,1,1],"solid":"none","facing":0,"note":"창고 가 안쪽 창고 부품 상자","level":2},
    {"kind":"barrel","rect":[90,53,1,1],"solid":"none","facing":0,"note":"창고 가 안쪽 창고 통","level":2},
    {"kind":"shelf","rect":[93,60,3,1],"solid":"none","facing":0,"note":"창고 가 기록실 선반","level":2},
    {"kind":"part_crate","rect":[93,53,1,1],"solid":"none","facing":0,"note":"창고 가 기록실 부품 상자","level":2},
    {"kind":"barrel","rect":[96,60,1,1],"solid":"none","facing":0,"note":"창고 가 기록실 통","level":2},
    {"kind":"shelf","rect":[61,41,3,1],"solid":"none","facing":0,"note":"창고 가 저장고 선반","level":-1},
    {"kind":"part_crate","rect":[61,48,1,1],"solid":"none","facing":0,"note":"창고 가 저장고 부품 상자","level":-1},
    {"kind":"barrel","rect":[64,41,1,1],"solid":"none","facing":0,"note":"창고 가 저장고 통","level":-1},
    {"kind":"shelf","rect":[67,41,3,1],"solid":"none","facing":0,"note":"창고 가 냉기 칸 선반","level":-1},
    {"kind":"part_crate","rect":[70,48,1,1],"solid":"none","facing":0,"note":"창고 가 냉기 칸 부품 상자","level":-1},
    {"kind":"barrel","rect":[67,48,1,1],"solid":"none","facing":0,"note":"창고 가 냉기 칸 통","level":-1},
    {"kind":"shelf","rect":[74,41,3,1],"solid":"none","facing":0,"note":"창고 가 안쪽 보관실 선반","level":-1},
    {"kind":"part_crate","rect":[74,48,1,1],"solid":"none","facing":0,"note":"창고 가 안쪽 보관실 부품 상자","level":-1},
    {"kind":"barrel","rect":[77,41,1,1],"solid":"none","facing":0,"note":"창고 가 안쪽 보관실 통","level":-1},
    {"kind":"shelf","rect":[80,41,3,1],"solid":"none","facing":0,"note":"창고 가 저장고 선반","level":-1},
    {"kind":"part_crate","rect":[83,48,1,1],"solid":"none","facing":0,"note":"창고 가 저장고 부품 상자","level":-1},
    {"kind":"barrel","rect":[80,48,1,1],"solid":"none","facing":0,"note":"창고 가 저장고 통","level":-1},
    {"kind":"shelf","rect":[87,41,3,1],"solid":"none","facing":0,"note":"창고 가 냉기 칸 선반","level":-1},
    {"kind":"part_crate","rect":[87,48,1,1],"solid":"none","facing":0,"note":"창고 가 냉기 칸 부품 상자","level":-1},
    {"kind":"barrel","rect":[90,41,1,1],"solid":"none","facing":0,"note":"창고 가 냉기 칸 통","level":-1},
    {"kind":"shelf","rect":[93,41,3,1],"solid":"none","facing":0,"note":"창고 가 안쪽 보관실 선반","level":-1},
    {"kind":"part_crate","rect":[96,48,1,1],"solid":"none","facing":0,"note":"창고 가 안쪽 보관실 부품 상자","level":-1},
    {"kind":"barrel","rect":[93,48,1,1],"solid":"none","facing":0,"note":"창고 가 안쪽 보관실 통","level":-1},
    {"kind":"shelf","rect":[61,60,3,1],"solid":"none","facing":0,"note":"창고 가 저장고 선반","level":-1},
    {"kind":"part_crate","rect":[61,53,1,1],"solid":"none","facing":0,"note":"창고 가 저장고 부품 상자","level":-1},
    {"kind":"barrel","rect":[64,53,1,1],"solid":"none","facing":0,"note":"창고 가 저장고 통","level":-1},
    {"kind":"shelf","rect":[67,60,3,1],"solid":"none","facing":0,"note":"창고 가 냉기 칸 선반","level":-1},
    {"kind":"part_crate","rect":[67,53,1,1],"solid":"none","facing":0,"note":"창고 가 냉기 칸 부품 상자","level":-1},
    {"kind":"barrel","rect":[70,60,1,1],"solid":"none","facing":0,"note":"창고 가 냉기 칸 통","level":-1},
    {"kind":"shelf","rect":[74,60,3,1],"solid":"none","facing":0,"note":"창고 가 안쪽 보관실 선반","level":-1},
    {"kind":"part_crate","rect":[74,53,1,1],"solid":"none","facing":0,"note":"창고 가 안쪽 보관실 부품 상자","level":-1},
    {"kind":"barrel","rect":[77,53,1,1],"solid":"none","facing":0,"note":"창고 가 안쪽 보관실 통","level":-1},
    {"kind":"shelf","rect":[80,60,3,1],"solid":"none","facing":0,"note":"창고 가 저장고 선반","level":-1},
    {"kind":"part_crate","rect":[80,53,1,1],"solid":"none","facing":0,"note":"창고 가 저장고 부품 상자","level":-1},
    {"kind":"barrel","rect":[83,60,1,1],"solid":"none","facing":0,"note":"창고 가 저장고 통","level":-1},
    {"kind":"shelf","rect":[87,60,3,1],"solid":"none","facing":0,"note":"창고 가 냉기 칸 선반","level":-1},
    {"kind":"part_crate","rect":[87,53,1,1],"solid":"none","facing":0,"note":"창고 가 냉기 칸 부품 상자","level":-1},
    {"kind":"barrel","rect":[90,53,1,1],"solid":"none","facing":0,"note":"창고 가 냉기 칸 통","level":-1},
    {"kind":"shelf","rect":[93,60,3,1],"solid":"none","facing":0,"note":"창고 가 안쪽 보관실 선반","level":-1},
    {"kind":"part_crate","rect":[93,53,1,1],"solid":"none","facing":0,"note":"창고 가 안쪽 보관실 부품 상자","level":-1},
    {"kind":"barrel","rect":[96,60,1,1],"solid":"none","facing":0,"note":"창고 가 안쪽 보관실 통","level":-1},
    {"kind":"shelf","rect":[117,53,3,1],"solid":"low","facing":0,"note":"창고 나 사무실 선반","level":0},
    {"kind":"part_crate","rect":[126,56,1,1],"solid":"low","facing":0,"note":"창고 나 사무실 부품 상자","level":0},
    {"kind":"barrel","rect":[117,56,1,1],"solid":"low","facing":0,"note":"창고 나 사무실 통","level":0},
    {"kind":"shelf","rect":[130,53,3,1],"solid":"low","facing":0,"note":"창고 나 선별실 선반","level":0},
    {"kind":"part_crate","rect":[140,56,1,1],"solid":"low","facing":0,"note":"창고 나 선별실 부품 상자","level":0},
    {"kind":"barrel","rect":[130,56,1,1],"solid":"low","facing":0,"note":"창고 나 선별실 통","level":0},
    {"kind":"shelf","rect":[117,61,3,1],"solid":"low","facing":0,"note":"창고 나 사무실 선반","level":0},
    {"kind":"part_crate","rect":[126,64,1,1],"solid":"low","facing":0,"note":"창고 나 사무실 부품 상자","level":0},
    {"kind":"barrel","rect":[117,64,1,1],"solid":"low","facing":0,"note":"창고 나 사무실 통","level":0},
    {"kind":"shelf","rect":[130,61,3,1],"solid":"low","facing":0,"note":"창고 나 선별실 선반","level":0},
    {"kind":"part_crate","rect":[140,64,1,1],"solid":"low","facing":0,"note":"창고 나 선별실 부품 상자","level":0},
    {"kind":"barrel","rect":[130,64,1,1],"solid":"low","facing":0,"note":"창고 나 선별실 통","level":0},
    {"kind":"shelf","rect":[117,53,3,1],"solid":"none","facing":0,"note":"창고 나 사무실 선반","level":1},
    {"kind":"part_crate","rect":[126,56,1,1],"solid":"none","facing":0,"note":"창고 나 사무실 부품 상자","level":1},
    {"kind":"barrel","rect":[117,56,1,1],"solid":"none","facing":0,"note":"창고 나 사무실 통","level":1},
    {"kind":"shelf","rect":[130,53,3,1],"solid":"none","facing":0,"note":"창고 나 선별실 선반","level":1},
    {"kind":"part_crate","rect":[140,56,1,1],"solid":"none","facing":0,"note":"창고 나 선별실 부품 상자","level":1},
    {"kind":"barrel","rect":[130,56,1,1],"solid":"none","facing":0,"note":"창고 나 선별실 통","level":1},
    {"kind":"shelf","rect":[117,61,3,1],"solid":"none","facing":0,"note":"창고 나 사무실 선반","level":1},
    {"kind":"part_crate","rect":[126,64,1,1],"solid":"none","facing":0,"note":"창고 나 사무실 부품 상자","level":1},
    {"kind":"barrel","rect":[117,64,1,1],"solid":"none","facing":0,"note":"창고 나 사무실 통","level":1},
    {"kind":"shelf","rect":[130,61,3,1],"solid":"none","facing":0,"note":"창고 나 선별실 선반","level":1},
    {"kind":"part_crate","rect":[140,64,1,1],"solid":"none","facing":0,"note":"창고 나 선별실 부품 상자","level":1},
    {"kind":"barrel","rect":[130,64,1,1],"solid":"none","facing":0,"note":"창고 나 선별실 통","level":1},
    {"kind":"shelf","rect":[15,43,3,1],"solid":"low","facing":0,"note":"창고 다 사무실 선반","level":0},
    {"kind":"part_crate","rect":[22,47,1,1],"solid":"low","facing":0,"note":"창고 다 사무실 부품 상자","level":0},
    {"kind":"barrel","rect":[15,47,1,1],"solid":"low","facing":0,"note":"창고 다 사무실 통","level":0},
    {"kind":"shelf","rect":[26,43,3,1],"solid":"low","facing":0,"note":"창고 다 선별실 선반","level":0},
    {"kind":"part_crate","rect":[33,47,1,1],"solid":"low","facing":0,"note":"창고 다 선별실 부품 상자","level":0},
    {"kind":"barrel","rect":[26,47,1,1],"solid":"low","facing":0,"note":"창고 다 선별실 통","level":0},
    {"kind":"shelf","rect":[15,52,3,1],"solid":"low","facing":0,"note":"창고 다 사무실 선반","level":0},
    {"kind":"part_crate","rect":[22,57,1,1],"solid":"low","facing":0,"note":"창고 다 사무실 부품 상자","level":0},
    {"kind":"barrel","rect":[15,57,1,1],"solid":"low","facing":0,"note":"창고 다 사무실 통","level":0},
    {"kind":"shelf","rect":[26,52,3,1],"solid":"low","facing":0,"note":"창고 다 선별실 선반","level":0},
    {"kind":"part_crate","rect":[33,57,1,1],"solid":"low","facing":0,"note":"창고 다 선별실 부품 상자","level":0},
    {"kind":"barrel","rect":[26,57,1,1],"solid":"low","facing":0,"note":"창고 다 선별실 통","level":0},
    {"kind":"shelf","rect":[15,43,3,1],"solid":"none","facing":0,"note":"창고 다 사무실 선반","level":1},
    {"kind":"part_crate","rect":[22,47,1,1],"solid":"none","facing":0,"note":"창고 다 사무실 부품 상자","level":1},
    {"kind":"barrel","rect":[15,47,1,1],"solid":"none","facing":0,"note":"창고 다 사무실 통","level":1},
    {"kind":"shelf","rect":[26,43,3,1],"solid":"none","facing":0,"note":"창고 다 선별실 선반","level":1},
    {"kind":"part_crate","rect":[33,47,1,1],"solid":"none","facing":0,"note":"창고 다 선별실 부품 상자","level":1},
    {"kind":"barrel","rect":[26,47,1,1],"solid":"none","facing":0,"note":"창고 다 선별실 통","level":1},
    {"kind":"shelf","rect":[15,52,3,1],"solid":"none","facing":0,"note":"창고 다 사무실 선반","level":1},
    {"kind":"part_crate","rect":[22,57,1,1],"solid":"none","facing":0,"note":"창고 다 사무실 부품 상자","level":1},
    {"kind":"barrel","rect":[15,57,1,1],"solid":"none","facing":0,"note":"창고 다 사무실 통","level":1},
    {"kind":"shelf","rect":[26,52,3,1],"solid":"none","facing":0,"note":"창고 다 선별실 선반","level":1},
    {"kind":"part_crate","rect":[33,57,1,1],"solid":"none","facing":0,"note":"창고 다 선별실 부품 상자","level":1},
    {"kind":"barrel","rect":[26,57,1,1],"solid":"none","facing":0,"note":"창고 다 선별실 통","level":1},
    {"kind":"display_shelf","rect":[49,58,4,1],"solid":"low","facing":0,"note":"선구점 매장 진열대","level":0},
    {"kind":"shop_counter","rect":[49,55,3,1],"solid":"low","facing":0,"note":"선구점 매장 가게 계산대","level":0},
    {"kind":"bread_rack","rect":[56,58,1,1],"solid":"low","facing":0,"note":"선구점 매장 빵 선반","level":0},
    {"kind":"sack_pile","rect":[49,60,2,2],"solid":"low","facing":0,"note":"선구점 뒤 창고 자루 더미","level":0},
    {"kind":"freezer_chest","rect":[49,62,2,1],"solid":"low","facing":0,"note":"선구점 뒤 창고 냉동 궤","level":0},
    {"kind":"part_crate","rect":[58,60,1,1],"solid":"low","facing":0,"note":"뒤 창고 부품 상자","level":0},
    {"kind":"desk","rect":[13,11,2,1],"solid":"none","facing":0,"note":"부두 사무소 앞방 책상","level":1},
    {"kind":"file_cabinet","rect":[18,20,2,1],"solid":"none","facing":0,"note":"부두 사무소 앞방 기술 서류함","level":1},
    {"kind":"conductor_log_chest","rect":[13,20,2,1],"solid":"none","facing":0,"note":"부두 사무소 앞방 차장 일지 궤","level":1},
    {"kind":"desk","rect":[22,11,2,1],"solid":"none","facing":0,"note":"부두 사무소 안쪽 방 책상","level":1},
    {"kind":"file_cabinet","rect":[26,20,2,1],"solid":"none","facing":0,"note":"부두 사무소 안쪽 방 기술 서류함","level":1},
    {"kind":"conductor_log_chest","rect":[22,20,2,1],"solid":"none","facing":0,"note":"부두 사무소 안쪽 방 차장 일지 궤","level":1},
    {"kind":"desk","rect":[67,11,2,1],"solid":"none","facing":0,"note":"신호 취급소 작업실 책상","level":1},
    {"kind":"file_cabinet","rect":[70,15,2,1],"solid":"none","facing":0,"note":"신호 취급소 작업실 기술 서류함","level":1},
    {"kind":"conductor_log_chest","rect":[67,15,2,1],"solid":"none","facing":0,"note":"신호 취급소 작업실 차장 일지 궤","level":1},
    {"kind":"shelf","rect":[119,23,3,1],"solid":"low","facing":0,"note":"석탄 창고 앞방 선반","level":0},
    {"kind":"part_crate","rect":[123,31,1,1],"solid":"low","facing":0,"note":"석탄 창고 앞방 부품 상자","level":0},
    {"kind":"barrel","rect":[119,31,1,1],"solid":"low","facing":0,"note":"석탄 창고 앞방 통","level":0},
    {"kind":"shelf","rect":[127,23,3,1],"solid":"low","facing":0,"note":"석탄 창고 안쪽 방 선반","level":0},
    {"kind":"part_crate","rect":[131,31,1,1],"solid":"low","facing":0,"note":"석탄 창고 안쪽 방 부품 상자","level":0},
    {"kind":"barrel","rect":[127,31,1,1],"solid":"low","facing":0,"note":"석탄 창고 안쪽 방 통","level":0},
    {"kind":"shelf","rect":[149,25,3,1],"solid":"low","facing":0,"note":"밧줄 창고 앞방 선반","level":0},
    {"kind":"part_crate","rect":[152,32,1,1],"solid":"low","facing":0,"note":"밧줄 창고 앞방 부품 상자","level":0},
    {"kind":"barrel","rect":[149,32,1,1],"solid":"low","facing":0,"note":"밧줄 창고 앞방 통","level":0},
    {"kind":"shelf","rect":[156,25,3,1],"solid":"low","facing":0,"note":"밧줄 창고 안쪽 방 선반","level":0},
    {"kind":"part_crate","rect":[158,32,1,1],"solid":"low","facing":0,"note":"밧줄 창고 안쪽 방 부품 상자","level":0},
    {"kind":"barrel","rect":[156,32,1,1],"solid":"low","facing":0,"note":"밧줄 창고 안쪽 방 통","level":0},
    {"kind":"shelf","rect":[156,55,3,1],"solid":"low","facing":0,"note":"공구 창고 앞방 선반","level":0},
    {"kind":"part_crate","rect":[158,61,1,1],"solid":"low","facing":0,"note":"공구 창고 앞방 부품 상자","level":0},
    {"kind":"barrel","rect":[156,61,1,1],"solid":"low","facing":0,"note":"공구 창고 앞방 통","level":0},
    {"kind":"shelf","rect":[162,55,3,1],"solid":"low","facing":0,"note":"공구 창고 안쪽 방 선반","level":0},
    {"kind":"part_crate","rect":[163,61,1,1],"solid":"low","facing":0,"note":"공구 창고 안쪽 방 부품 상자","level":0},
    {"kind":"barrel","rect":[162,61,1,1],"solid":"low","facing":0,"note":"공구 창고 안쪽 방 통","level":0},
    {"kind":"shelf","rect":[167,18,3,1],"solid":"low","facing":0,"note":"변전실 작업실 선반","level":0},
    {"kind":"part_crate","rect":[167,13,1,1],"solid":"low","facing":0,"note":"변전실 작업실 부품 상자","level":0},
    {"kind":"barrel","rect":[172,18,1,1],"solid":"low","facing":0,"note":"변전실 작업실 통","level":0},
    {"kind":"bed","rect":[41,21,2,1],"solid":"none","facing":0,"note":"숙직소 앞방 침대","level":1},
    {"kind":"desk","rect":[48,28,2,1],"solid":"none","facing":0,"note":"숙직소 앞방 책상","level":1},
    {"kind":"shelf","rect":[41,28,3,1],"solid":"none","facing":0,"note":"숙직소 앞방 선반","level":1},
    {"kind":"bed","rect":[52,21,2,1],"solid":"none","facing":0,"note":"숙직소 안쪽 방 침대","level":1},
    {"kind":"desk","rect":[58,28,2,1],"solid":"none","facing":0,"note":"숙직소 안쪽 방 책상","level":1},
    {"kind":"shelf","rect":[52,28,3,1],"solid":"none","facing":0,"note":"숙직소 안쪽 방 선반","level":1},
    {"kind":"shelf","rect":[164,40,3,1],"solid":"low","facing":0,"note":"모래 창고 작업실 선반","level":0},
    {"kind":"part_crate","rect":[164,35,1,1],"solid":"low","facing":0,"note":"모래 창고 작업실 부품 상자","level":0},
    {"kind":"barrel","rect":[169,40,1,1],"solid":"low","facing":0,"note":"모래 창고 작업실 통","level":0},
    {"kind":"desk","rect":[127,91,2,1],"solid":"low","facing":0,"note":"수문 관리소 앞방 책상","level":0},
    {"kind":"file_cabinet","rect":[135,102,2,1],"solid":"low","facing":0,"note":"수문 관리소 앞방 기술 서류함","level":0},
    {"kind":"conductor_log_chest","rect":[127,102,2,1],"solid":"low","facing":0,"note":"수문 관리소 앞방 차장 일지 궤","level":0},
    {"kind":"desk","rect":[139,91,2,1],"solid":"low","facing":0,"note":"수문 관리소 안쪽 방 책상","level":0},
    {"kind":"file_cabinet","rect":[147,102,2,1],"solid":"low","facing":0,"note":"수문 관리소 안쪽 방 기술 서류함","level":0},
    {"kind":"conductor_log_chest","rect":[139,102,2,1],"solid":"low","facing":0,"note":"수문 관리소 안쪽 방 차장 일지 궤","level":0},
    {"kind":"desk","rect":[127,91,2,1],"solid":"none","facing":0,"note":"수문 관리소 앞방 책상","level":1},
    {"kind":"file_cabinet","rect":[135,102,2,1],"solid":"none","facing":0,"note":"수문 관리소 앞방 기술 서류함","level":1},
    {"kind":"conductor_log_chest","rect":[127,102,2,1],"solid":"none","facing":0,"note":"수문 관리소 앞방 차장 일지 궤","level":1},
    {"kind":"desk","rect":[139,91,2,1],"solid":"none","facing":0,"note":"수문 관리소 안쪽 방 책상","level":1},
    {"kind":"file_cabinet","rect":[147,102,2,1],"solid":"none","facing":0,"note":"수문 관리소 안쪽 방 기술 서류함","level":1},
    {"kind":"conductor_log_chest","rect":[139,102,2,1],"solid":"none","facing":0,"note":"수문 관리소 안쪽 방 차장 일지 궤","level":1},
    {"kind":"shelf","rect":[61,91,3,1],"solid":"low","facing":0,"note":"장비 헛간 앞방 선반","level":0},
    {"kind":"part_crate","rect":[65,98,1,1],"solid":"low","facing":0,"note":"장비 헛간 앞방 부품 상자","level":0},
    {"kind":"barrel","rect":[61,98,1,1],"solid":"low","facing":0,"note":"장비 헛간 앞방 통","level":0},
    {"kind":"shelf","rect":[69,91,3,1],"solid":"low","facing":0,"note":"장비 헛간 안쪽 방 선반","level":0},
    {"kind":"part_crate","rect":[72,98,1,1],"solid":"low","facing":0,"note":"장비 헛간 안쪽 방 부품 상자","level":0},
    {"kind":"barrel","rect":[69,98,1,1],"solid":"low","facing":0,"note":"장비 헛간 안쪽 방 통","level":0},
    {"kind":"shelf","rect":[91,91,3,1],"solid":"low","facing":0,"note":"배 수리 헛간 앞방 선반","level":0},
    {"kind":"part_crate","rect":[95,98,1,1],"solid":"low","facing":0,"note":"배 수리 헛간 앞방 부품 상자","level":0},
    {"kind":"barrel","rect":[91,98,1,1],"solid":"low","facing":0,"note":"배 수리 헛간 앞방 통","level":0},
    {"kind":"shelf","rect":[99,91,3,1],"solid":"low","facing":0,"note":"배 수리 헛간 안쪽 방 선반","level":0},
    {"kind":"part_crate","rect":[102,98,1,1],"solid":"low","facing":0,"note":"배 수리 헛간 안쪽 방 부품 상자","level":0},
    {"kind":"barrel","rect":[99,98,1,1],"solid":"low","facing":0,"note":"배 수리 헛간 안쪽 방 통","level":0},
    {"kind":"rope_coil","rect":[48,44,1,1],"solid":"low","facing":0,"note":"밧줄 더미 작업 흔적","level":0},
    {"kind":"barrel","rect":[52,44,1,1],"solid":"low","facing":0,"note":"통 작업 흔적","level":0},
    {"kind":"handcart","rect":[56,44,2,1],"solid":"low","facing":0,"note":"손수레 작업 흔적","level":0},
    {"kind":"pallet_stack","rect":[104,53,2,2],"solid":"low","facing":0,"note":"팰릿 더미 작업 흔적","level":0},
    {"kind":"coupler_set","rect":[108,53,1,1],"solid":"low","facing":0,"note":"연결기 한 벌 작업 흔적","level":0},
    {"kind":"tool_cart","rect":[112,53,2,1],"solid":"low","facing":0,"note":"공구 수레 작업 흔적","level":0},
    {"kind":"rope_coil","rect":[7,63,1,1],"solid":"low","facing":0,"note":"밧줄 더미 작업 흔적","level":0},
    {"kind":"barrel","rect":[11,63,1,1],"solid":"low","facing":0,"note":"통 작업 흔적","level":0},
    {"kind":"part_crate","rect":[15,63,1,1],"solid":"low","facing":0,"note":"부품 상자 작업 흔적","level":0},
    {"kind":"mooring_post","rect":[151,65,1,1],"solid":"low","facing":0,"note":"계류 말뚝 작업 흔적","level":0},
    {"kind":"rope_coil","rect":[155,65,1,1],"solid":"low","facing":0,"note":"밧줄 더미 작업 흔적","level":0},
    {"kind":"water_gauge","rect":[159,65,1,1],"solid":"low","facing":0,"note":"수위표 작업 흔적","level":0},
    {"kind":"bare_tree","rect":[5,37,1,1],"solid":"tree","facing":0,"note":"길가 마른 나무","level":0},
    {"kind":"bare_tree","rect":[5,42,1,1],"solid":"tree","facing":0,"note":"길가 마른 나무","level":0},
    {"kind":"bare_tree","rect":[5,47,1,1],"solid":"tree","facing":0,"note":"길가 마른 나무","level":0},
    {"kind":"bare_tree","rect":[5,52,1,1],"solid":"tree","facing":0,"note":"길가 마른 나무","level":0},
    {"kind":"bare_tree","rect":[5,57,1,1],"solid":"tree","facing":0,"note":"길가 마른 나무","level":0},
    {"kind":"bare_tree","rect":[5,62,1,1],"solid":"tree","facing":0,"note":"길가 마른 나무","level":0},
    {"kind":"bare_tree","rect":[5,67,1,1],"solid":"tree","facing":0,"note":"길가 마른 나무","level":0},
    {"kind":"bare_tree","rect":[175,51,1,1],"solid":"tree","facing":0,"note":"길가 마른 나무","level":0},
    {"kind":"bare_tree","rect":[175,56,1,1],"solid":"tree","facing":0,"note":"길가 마른 나무","level":0},
    {"kind":"bare_tree","rect":[175,61,1,1],"solid":"tree","facing":0,"note":"길가 마른 나무","level":0},
    {"kind":"bare_tree","rect":[175,66,1,1],"solid":"tree","facing":0,"note":"길가 마른 나무","level":0},
    {"kind":"bare_tree","rect":[175,71,1,1],"solid":"tree","facing":0,"note":"길가 마른 나무","level":0},
    {"kind":"bare_tree","rect":[9,91,1,1],"solid":"tree","facing":0,"note":"길가 마른 나무","level":0},
    {"kind":"bare_tree","rect":[14,93,1,1],"solid":"tree","facing":0,"note":"길가 마른 나무","level":0},
    {"kind":"bare_tree","rect":[19,95,1,1],"solid":"tree","facing":0,"note":"길가 마른 나무","level":0},
    {"kind":"bare_tree","rect":[24,97,1,1],"solid":"tree","facing":0,"note":"길가 마른 나무","level":0},
    {"kind":"bare_tree","rect":[29,99,1,1],"solid":"tree","facing":0,"note":"길가 마른 나무","level":0},
    {"kind":"bare_tree","rect":[155,90,1,1],"solid":"tree","facing":0,"note":"길가 마른 나무","level":0},
    {"kind":"bare_tree","rect":[158,93,1,1],"solid":"tree","facing":0,"note":"길가 마른 나무","level":0},
    {"kind":"bare_tree","rect":[161,96,1,1],"solid":"tree","facing":0,"note":"길가 마른 나무","level":0},
    {"kind":"bare_tree","rect":[164,99,1,1],"solid":"tree","facing":0,"note":"길가 마른 나무","level":0},
    {"kind":"bare_tree","rect":[76,64,1,1],"solid":"tree","facing":0,"note":"길가 마른 나무","level":0},
    {"kind":"bare_tree","rect":[82,64,1,1],"solid":"tree","facing":0,"note":"길가 마른 나무","level":0},
    {"kind":"bare_tree","rect":[88,64,1,1],"solid":"tree","facing":0,"note":"길가 마른 나무","level":0},
    {"kind":"bare_tree","rect":[94,64,1,1],"solid":"tree","facing":0,"note":"길가 마른 나무","level":0},
    {"kind":"bare_tree","rect":[100,64,1,1],"solid":"tree","facing":0,"note":"길가 마른 나무","level":0}
  ],
  "containers": [
    {"id":"box_1","name":"창고 가 사무실 상자","cell":[65,48],"building":0,"search":5,"items":["scrap","food_pack"],"locked":false,"level":0,"searched":false},
    {"id":"box_2","name":"창고 가 선별실 상자","cell":[72,48],"building":0,"search":5,"items":["scrap","food_pack"],"locked":false,"level":0,"searched":false},
    {"id":"box_3","name":"창고 가 선반 칸 상자","cell":[78,48],"building":0,"search":5,"items":["scrap","document"],"locked":false,"level":0,"searched":false},
    {"id":"box_4","name":"창고 가 계량실 상자","cell":[85,48],"building":0,"search":5,"items":["scrap","food_pack"],"locked":false,"level":0,"searched":false},
    {"id":"box_5","name":"창고 가 안쪽 창고 상자","cell":[91,48],"building":0,"search":5,"items":["scrap","food_pack"],"locked":false,"level":0,"searched":false},
    {"id":"box_6","name":"창고 가 기록실 상자","cell":[98,48],"building":0,"search":5,"items":["scrap","document"],"locked":false,"level":0,"searched":false},
    {"id":"box_7","name":"창고 가 사무실 상자","cell":[65,60],"building":0,"search":5,"items":["scrap","food_pack"],"locked":false,"level":0,"searched":false},
    {"id":"box_8","name":"창고 가 선별실 상자","cell":[72,60],"building":0,"search":5,"items":["scrap","food_pack"],"locked":false,"level":0,"searched":false},
    {"id":"box_9","name":"창고 가 선반 칸 상자","cell":[78,60],"building":0,"search":5,"items":["scrap","document"],"locked":false,"level":0,"searched":false},
    {"id":"box_10","name":"창고 가 계량실 상자","cell":[85,60],"building":0,"search":5,"items":["scrap","food_pack"],"locked":false,"level":0,"searched":false},
    {"id":"box_11","name":"창고 가 안쪽 창고 상자","cell":[91,60],"building":0,"search":5,"items":["scrap","food_pack"],"locked":false,"level":0,"searched":false},
    {"id":"box_12","name":"창고 가 기록실 상자","cell":[98,60],"building":0,"search":5,"items":["scrap","document"],"locked":false,"level":0,"searched":false},
    {"id":"box_13","name":"창고 가 사무실 상자","cell":[65,48],"building":0,"search":5,"items":["scrap","food_pack"],"locked":false,"level":1,"searched":false},
    {"id":"box_14","name":"창고 가 선별실 상자","cell":[72,48],"building":0,"search":5,"items":["scrap","food_pack"],"locked":false,"level":1,"searched":false},
    {"id":"box_15","name":"창고 가 선반 칸 상자","cell":[78,48],"building":0,"search":5,"items":["scrap","document"],"locked":false,"level":1,"searched":false},
    {"id":"box_16","name":"창고 가 계량실 상자","cell":[85,48],"building":0,"search":5,"items":["scrap","food_pack"],"locked":false,"level":1,"searched":false},
    {"id":"box_17","name":"창고 가 안쪽 창고 상자","cell":[91,48],"building":0,"search":5,"items":["scrap","food_pack"],"locked":false,"level":1,"searched":false},
    {"id":"box_18","name":"창고 가 기록실 상자","cell":[98,48],"building":0,"search":5,"items":["scrap","document"],"locked":false,"level":1,"searched":false},
    {"id":"box_19","name":"창고 가 사무실 상자","cell":[65,60],"building":0,"search":5,"items":["scrap","food_pack"],"locked":false,"level":1,"searched":false},
    {"id":"box_20","name":"창고 가 선별실 상자","cell":[72,60],"building":0,"search":5,"items":["scrap","food_pack"],"locked":false,"level":1,"searched":false},
    {"id":"box_21","name":"창고 가 선반 칸 상자","cell":[78,60],"building":0,"search":5,"items":["scrap","document"],"locked":false,"level":1,"searched":false},
    {"id":"box_22","name":"창고 가 계량실 상자","cell":[85,60],"building":0,"search":5,"items":["scrap","food_pack"],"locked":false,"level":1,"searched":false},
    {"id":"box_23","name":"창고 가 안쪽 창고 상자","cell":[91,60],"building":0,"search":5,"items":["scrap","food_pack"],"locked":false,"level":1,"searched":false},
    {"id":"box_24","name":"창고 가 기록실 상자","cell":[98,60],"building":0,"search":5,"items":["scrap","document"],"locked":false,"level":1,"searched":false},
    {"id":"box_25","name":"창고 가 사무실 상자","cell":[65,48],"building":0,"search":5,"items":["scrap","food_pack"],"locked":false,"level":2,"searched":false},
    {"id":"box_26","name":"창고 가 선별실 상자","cell":[72,48],"building":0,"search":5,"items":["scrap","food_pack"],"locked":false,"level":2,"searched":false},
    {"id":"box_27","name":"창고 가 선반 칸 상자","cell":[78,48],"building":0,"search":5,"items":["scrap","document"],"locked":false,"level":2,"searched":false},
    {"id":"box_28","name":"창고 가 계량실 상자","cell":[85,48],"building":0,"search":5,"items":["scrap","food_pack"],"locked":false,"level":2,"searched":false},
    {"id":"box_29","name":"창고 가 안쪽 창고 상자","cell":[91,48],"building":0,"search":5,"items":["scrap","food_pack"],"locked":false,"level":2,"searched":false},
    {"id":"box_30","name":"창고 가 기록실 상자","cell":[98,48],"building":0,"search":5,"items":["scrap","document"],"locked":false,"level":2,"searched":false},
    {"id":"box_31","name":"창고 가 사무실 상자","cell":[65,60],"building":0,"search":5,"items":["scrap","food_pack"],"locked":false,"level":2,"searched":false},
    {"id":"box_32","name":"창고 가 선별실 상자","cell":[72,60],"building":0,"search":5,"items":["scrap","food_pack"],"locked":false,"level":2,"searched":false},
    {"id":"box_33","name":"창고 가 선반 칸 상자","cell":[78,60],"building":0,"search":5,"items":["scrap","document"],"locked":false,"level":2,"searched":false},
    {"id":"box_34","name":"창고 가 계량실 상자","cell":[85,60],"building":0,"search":5,"items":["scrap","food_pack"],"locked":false,"level":2,"searched":false},
    {"id":"box_35","name":"창고 가 안쪽 창고 상자","cell":[91,60],"building":0,"search":5,"items":["scrap","food_pack"],"locked":false,"level":2,"searched":false},
    {"id":"box_36","name":"창고 가 기록실 상자","cell":[98,60],"building":0,"search":5,"items":["scrap","document"],"locked":false,"level":2,"searched":false},
    {"id":"box_37","name":"창고 가 저장고 상자","cell":[65,48],"building":0,"search":5,"items":["scrap","food_pack"],"locked":false,"level":-1,"searched":false},
    {"id":"box_38","name":"창고 가 냉기 칸 상자","cell":[72,48],"building":0,"search":5,"items":["scrap","food_pack"],"locked":false,"level":-1,"searched":false},
    {"id":"box_39","name":"창고 가 안쪽 보관실 상자","cell":[78,48],"building":0,"search":5,"items":["scrap","document"],"locked":false,"level":-1,"searched":false},
    {"id":"box_40","name":"창고 가 저장고 상자","cell":[85,48],"building":0,"search":5,"items":["scrap","food_pack"],"locked":false,"level":-1,"searched":false},
    {"id":"box_41","name":"창고 가 냉기 칸 상자","cell":[91,48],"building":0,"search":5,"items":["scrap","food_pack"],"locked":false,"level":-1,"searched":false},
    {"id":"box_42","name":"창고 가 안쪽 보관실 상자","cell":[98,48],"building":0,"search":5,"items":["scrap","document"],"locked":false,"level":-1,"searched":false},
    {"id":"box_43","name":"창고 가 저장고 상자","cell":[65,60],"building":0,"search":5,"items":["scrap","food_pack"],"locked":false,"level":-1,"searched":false},
    {"id":"box_44","name":"창고 가 냉기 칸 상자","cell":[72,60],"building":0,"search":5,"items":["scrap","food_pack"],"locked":false,"level":-1,"searched":false},
    {"id":"box_45","name":"창고 가 안쪽 보관실 상자","cell":[78,60],"building":0,"search":5,"items":["scrap","document"],"locked":false,"level":-1,"searched":false},
    {"id":"box_46","name":"창고 가 저장고 상자","cell":[85,60],"building":0,"search":5,"items":["scrap","food_pack"],"locked":false,"level":-1,"searched":false},
    {"id":"box_47","name":"창고 가 냉기 칸 상자","cell":[91,60],"building":0,"search":5,"items":["scrap","food_pack"],"locked":false,"level":-1,"searched":false},
    {"id":"box_48","name":"창고 가 안쪽 보관실 상자","cell":[98,60],"building":0,"search":5,"items":["scrap","document"],"locked":false,"level":-1,"searched":false},
    {"id":"box_49","name":"창고 나 사무실 상자","cell":[128,56],"building":1,"search":5,"items":["scrap","food_pack"],"locked":false,"level":0,"searched":false},
    {"id":"box_50","name":"창고 나 선별실 상자","cell":[142,56],"building":1,"search":5,"items":["scrap","food_pack"],"locked":false,"level":0,"searched":false},
    {"id":"box_51","name":"창고 나 사무실 상자","cell":[128,64],"building":1,"search":5,"items":["scrap","document"],"locked":false,"level":0,"searched":false},
    {"id":"box_52","name":"창고 나 선별실 상자","cell":[142,64],"building":1,"search":5,"items":["scrap","food_pack"],"locked":false,"level":0,"searched":false},
    {"id":"box_53","name":"창고 나 사무실 상자","cell":[128,56],"building":1,"search":5,"items":["scrap","food_pack"],"locked":false,"level":1,"searched":false},
    {"id":"box_54","name":"창고 나 선별실 상자","cell":[142,56],"building":1,"search":5,"items":["scrap","document"],"locked":false,"level":1,"searched":false},
    {"id":"box_55","name":"창고 나 사무실 상자","cell":[128,64],"building":1,"search":5,"items":["scrap","food_pack"],"locked":false,"level":1,"searched":false},
    {"id":"box_56","name":"창고 나 선별실 상자","cell":[142,64],"building":1,"search":5,"items":["scrap","food_pack"],"locked":false,"level":1,"searched":false},
    {"id":"box_57","name":"창고 다 사무실 상자","cell":[24,47],"building":2,"search":5,"items":["scrap","document"],"locked":false,"level":0,"searched":false},
    {"id":"box_58","name":"창고 다 선별실 상자","cell":[35,47],"building":2,"search":5,"items":["scrap","food_pack"],"locked":false,"level":0,"searched":false},
    {"id":"box_59","name":"창고 다 사무실 상자","cell":[24,57],"building":2,"search":5,"items":["scrap","food_pack"],"locked":false,"level":0,"searched":false},
    {"id":"box_60","name":"창고 다 선별실 상자","cell":[35,57],"building":2,"search":5,"items":["scrap","document"],"locked":false,"level":0,"searched":false},
    {"id":"box_61","name":"창고 다 사무실 상자","cell":[24,47],"building":2,"search":5,"items":["scrap","food_pack"],"locked":false,"level":1,"searched":false},
    {"id":"box_62","name":"창고 다 선별실 상자","cell":[35,47],"building":2,"search":5,"items":["scrap","food_pack"],"locked":false,"level":1,"searched":false},
    {"id":"box_63","name":"창고 다 사무실 상자","cell":[24,57],"building":2,"search":5,"items":["scrap","document"],"locked":false,"level":1,"searched":false},
    {"id":"box_64","name":"창고 다 선별실 상자","cell":[35,57],"building":2,"search":5,"items":["scrap","food_pack"],"locked":false,"level":1,"searched":false},
    {"id":"box_65","name":"선구점 매장 상자","cell":[58,58],"building":3,"search":5,"items":["scrap","food_pack"],"locked":false,"level":0,"searched":false},
    {"id":"box_66","name":"선구점 뒤 창고 상자","cell":[58,62],"building":3,"search":5,"items":["scrap","document"],"locked":false,"level":0,"searched":false},
    {"id":"box_67","name":"부두 사무소 앞방 상자","cell":[20,20],"building":4,"search":5,"items":["scrap","food_pack"],"locked":false,"level":0,"searched":false},
    {"id":"box_68","name":"부두 사무소 안쪽 방 상자","cell":[28,20],"building":4,"search":5,"items":["scrap","food_pack"],"locked":false,"level":0,"searched":false},
    {"id":"box_69","name":"부두 사무소 앞방 상자","cell":[20,20],"building":4,"search":5,"items":["scrap","document"],"locked":false,"level":1,"searched":false},
    {"id":"box_70","name":"부두 사무소 안쪽 방 상자","cell":[28,20],"building":4,"search":5,"items":["scrap","food_pack"],"locked":false,"level":1,"searched":false},
    {"id":"box_71","name":"신호 취급소 작업실 상자","cell":[72,15],"building":5,"search":5,"items":["scrap","food_pack"],"locked":false,"level":0,"searched":false},
    {"id":"box_72","name":"신호 취급소 작업실 상자","cell":[72,15],"building":5,"search":5,"items":["scrap","document"],"locked":false,"level":1,"searched":false},
    {"id":"box_73","name":"계량소 작업실 상자","cell":[87,17],"building":6,"search":5,"items":["scrap","food_pack"],"locked":false,"level":0,"searched":false},
    {"id":"box_74","name":"석탄 창고 앞방 상자","cell":[125,31],"building":7,"search":5,"items":["scrap","food_pack"],"locked":false,"level":0,"searched":false},
    {"id":"box_75","name":"석탄 창고 안쪽 방 상자","cell":[133,31],"building":7,"search":5,"items":["scrap","document"],"locked":false,"level":0,"searched":false},
    {"id":"box_76","name":"구내 매점 매장 상자","cell":[24,26],"building":8,"search":5,"items":["scrap","food_pack"],"locked":false,"level":0,"searched":false},
    {"id":"box_77","name":"구내 매점 뒤 창고 상자","cell":[24,30],"building":8,"search":5,"items":["scrap","food_pack"],"locked":false,"level":0,"searched":false},
    {"id":"box_78","name":"밧줄 창고 앞방 상자","cell":[154,32],"building":9,"search":5,"items":["scrap","document"],"locked":false,"level":0,"searched":false},
    {"id":"box_79","name":"밧줄 창고 안쪽 방 상자","cell":[160,32],"building":9,"search":5,"items":["scrap","food_pack"],"locked":false,"level":0,"searched":false},
    {"id":"box_80","name":"공구 창고 앞방 상자","cell":[160,61],"building":10,"search":5,"items":["scrap","food_pack"],"locked":false,"level":0,"searched":false},
    {"id":"box_81","name":"공구 창고 안쪽 방 상자","cell":[165,61],"building":10,"search":5,"items":["scrap","document"],"locked":false,"level":0,"searched":false},
    {"id":"box_82","name":"변전실 작업실 상자","cell":[174,18],"building":11,"search":5,"items":["scrap","food_pack"],"locked":false,"level":0,"searched":false},
    {"id":"box_83","name":"숙직소 앞방 상자","cell":[50,28],"building":12,"search":5,"items":["scrap","food_pack"],"locked":false,"level":0,"searched":false},
    {"id":"box_84","name":"숙직소 안쪽 방 상자","cell":[60,28],"building":12,"search":5,"items":["scrap","document"],"locked":false,"level":0,"searched":false},
    {"id":"box_85","name":"숙직소 앞방 상자","cell":[50,28],"building":12,"search":5,"items":["scrap","food_pack"],"locked":false,"level":1,"searched":false},
    {"id":"box_86","name":"숙직소 안쪽 방 상자","cell":[60,28],"building":12,"search":5,"items":["scrap","food_pack"],"locked":false,"level":1,"searched":false},
    {"id":"box_87","name":"모래 창고 작업실 상자","cell":[171,40],"building":13,"search":5,"items":["scrap","document"],"locked":false,"level":0,"searched":false},
    {"id":"box_88","name":"수문 관리소 앞방 상자","cell":[137,102],"building":14,"search":5,"items":["scrap","food_pack"],"locked":false,"level":0,"searched":false},
    {"id":"box_89","name":"수문 관리소 안쪽 방 상자","cell":[149,102],"building":14,"search":5,"items":["scrap","food_pack"],"locked":false,"level":0,"searched":false},
    {"id":"box_90","name":"수문 관리소 앞방 상자","cell":[137,102],"building":14,"search":5,"items":["scrap","document"],"locked":false,"level":1,"searched":false},
    {"id":"box_91","name":"수문 관리소 안쪽 방 상자","cell":[149,102],"building":14,"search":5,"items":["scrap","food_pack"],"locked":false,"level":1,"searched":false},
    {"id":"box_92","name":"장비 헛간 앞방 상자","cell":[67,98],"building":15,"search":5,"items":["scrap","food_pack"],"locked":false,"level":0,"searched":false},
    {"id":"box_93","name":"장비 헛간 안쪽 방 상자","cell":[74,98],"building":15,"search":5,"items":["scrap","document"],"locked":false,"level":0,"searched":false},
    {"id":"box_94","name":"배 수리 헛간 앞방 상자","cell":[97,98],"building":16,"search":5,"items":["scrap","food_pack"],"locked":false,"level":0,"searched":false},
    {"id":"box_95","name":"배 수리 헛간 안쪽 방 상자","cell":[104,98],"building":16,"search":5,"items":["scrap","food_pack"],"locked":false,"level":0,"searched":false},
    {"id":"box_platform","name":"승강장 보급 상자","cell":[38,8],"building":-1,"search":4,"items":["scrap","food_pack"],"locked":false,"level":0,"searched":false}
  ],
  "wagons": [
    {"id":"wagon_1","name":"평판 화차","rect":[35,12,12,3],"coal":0,"work":[36,15]},
    {"id":"wagon_2","name":"평판 화차","rect":[52,12,9,3],"coal":0,"work":[53,15]},
    {"id":"wagon_3","name":"평판 화차","rect":[93,18,12,3],"coal":0,"work":[94,21]}
  ],
  "entries": [
    ["west_road",[[0,32],[0,33],[0,34],[0,35]],0.6],
    ["east_track",[[179,1],[179,2],[179,3]],0.6],
    ["east_road",[[179,44],[179,45],[179,46],[179,47]],0.6]
  ],
  "holes": [
    ["manhole_01",[90,34],"큰길 맨홀"],
    ["manhole_02",[56,68],"부두 길 맨홀"],
    ["drain_01",[118,70],"부두 배수구"]
  ],
  "barricades": [
    [31,13],
    [33,13],
    [61,13],
    [64,13],
    [75,13],
    [77,13]
  ],
  "dead": [
    [44,44],
    [101,61],
    [151,48],
    [115,67],
    [40,62]
  ],
  "deep": [
    ["C","창고 가"],
    ["H","수문 관리소"]
  ],
  "assumptions": ["열 칸을 넘는 낮은 덩이를 만들지 않도록 바지선을 여덟 칸 길이로 줄였다.","수문 관리소는 남쪽으로 두 칸 옮겨 틀과 문 앞을 분리했다. 다리와 보도에는 문 장치를 두지 않았다. 좌우 고체 대칭을 피하려고 운하의 북쪽 부두와 남쪽 둑을 불규칙하게 내밀되 건넘은 두 곳만 남겼다."],
  "salvage": [
    ["salvage_1","버려진 차",[38,98],"scrap"],
    ["salvage_2","버려진 차",[43,97],"scrap"],
    ["salvage_3","버려진 차",[165,48],"scrap"],
    ["salvage_4","레일 더미",[58,8],"scrap"],
    ["salvage_5","창고 가 사무실 부품 상자",[62,48],"scrap"],
    ["salvage_6","창고 가 선별실 부품 상자",[71,48],"scrap"]
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
		data["spots"]["work_site"] = {"kind": "work_site", "cell": _cell(work["cell"]), "name": "고철 작업 구역", "state": "closed", "zone_rect": _rect(work["rect"])}
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
    "298": {
      "kind": "bare_tree",
      "rect": [
        5,
        47,
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
        8,
        48,
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
        3,
        50,
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
        7,
        52,
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
        2,
        53,
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
        107,
        59,
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
        110,
        60,
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
        105,
        62,
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
        109,
        64,
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
        104,
        65,
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
        78,
        83,
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
        81,
        84,
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
        76,
        86,
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
        80,
        88,
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
        89,
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
        106,
        95,
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
        108,
        96,
        1,
        1
      ],
      "solid": "tree",
      "facing": 0,
      "note": "길가 마른 나무",
      "level": 0
    },
    "315": {
      "kind": "bare_tree",
      "rect": [
        106,
        98,
        1,
        1
      ],
      "solid": "tree",
      "facing": 0,
      "note": "길가 마른 나무",
      "level": 0
    },
    "316": {
      "kind": "bare_tree",
      "rect": [
        107,
        100,
        1,
        1
      ],
      "solid": "tree",
      "facing": 0,
      "note": "길가 마른 나무",
      "level": 0
    },
    "317": {
      "kind": "bare_tree",
      "rect": [
        102,
        101,
        1,
        1
      ],
      "solid": "tree",
      "facing": 0,
      "note": "길가 마른 나무",
      "level": 0
    },
    "318": {
      "kind": "bare_tree",
      "rect": [
        6,
        91,
        1,
        1
      ],
      "solid": "tree",
      "facing": 0,
      "note": "길가 마른 나무",
      "level": 0
    },
    "319": {
      "kind": "bare_tree",
      "rect": [
        10,
        94,
        1,
        1
      ],
      "solid": "tree",
      "facing": 0,
      "note": "길가 마른 나무",
      "level": 0
    },
    "320": {
      "kind": "bare_tree",
      "rect": [
        13,
        89,
        1,
        1
      ],
      "solid": "tree",
      "facing": 0,
      "note": "길가 마른 나무",
      "level": 0
    },
    "321": {
      "kind": "bare_tree",
      "rect": [
        150,
        14,
        1,
        1
      ],
      "solid": "tree",
      "facing": 0,
      "note": "길가 마른 나무",
      "level": 0
    },
    "322": {
      "kind": "bare_tree",
      "rect": [
        154,
        19,
        1,
        1
      ],
      "solid": "tree",
      "facing": 0,
      "note": "길가 마른 나무",
      "level": 0
    },
    "323": {
      "kind": "bare_tree",
      "rect": [
        158,
        15,
        1,
        1
      ],
      "solid": "tree",
      "facing": 0,
      "note": "길가 마른 나무",
      "level": 0
    }
  },
  "remove": [
    26,
    27,
    32,
    33,
    38,
    39,
    44,
    45,
    50,
    51,
    56,
    57,
    62,
    63,
    68,
    69,
    74,
    75,
    80,
    81,
    86,
    87,
    92,
    93,
    98,
    99,
    104,
    105,
    110,
    111,
    116,
    117,
    122,
    123,
    128,
    129,
    134,
    135,
    140,
    141,
    146,
    147,
    152,
    153,
    158,
    159,
    164,
    165,
    170,
    171,
    176,
    177,
    182,
    183,
    188,
    189,
    194,
    195,
    200,
    201,
    206,
    207,
    212,
    213,
    236,
    237,
    242,
    243,
    248,
    249,
    260,
    261,
    278,
    279,
    284,
    285
  ],
  "append": [],
  "work_site": {
    "cell": [
      96,
      62
    ],
    "rect": [
      96,
      62,
      39,
      10
    ]
  },
  "changed": [
    [
      5,
      37,
      1,
      1
    ],
    [
      5,
      47,
      1,
      1
    ],
    [
      5,
      42,
      1,
      1
    ],
    [
      8,
      48,
      1,
      1
    ],
    [
      5,
      47,
      1,
      1
    ],
    [
      3,
      50,
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
      7,
      52,
      1,
      1
    ],
    [
      5,
      57,
      1,
      1
    ],
    [
      2,
      53,
      1,
      1
    ],
    [
      5,
      62,
      1,
      1
    ],
    [
      107,
      59,
      1,
      1
    ],
    [
      5,
      67,
      1,
      1
    ],
    [
      110,
      60,
      1,
      1
    ],
    [
      175,
      51,
      1,
      1
    ],
    [
      105,
      62,
      1,
      1
    ],
    [
      175,
      56,
      1,
      1
    ],
    [
      109,
      64,
      1,
      1
    ],
    [
      175,
      61,
      1,
      1
    ],
    [
      104,
      65,
      1,
      1
    ],
    [
      175,
      66,
      1,
      1
    ],
    [
      78,
      83,
      1,
      1
    ],
    [
      175,
      71,
      1,
      1
    ],
    [
      81,
      84,
      1,
      1
    ],
    [
      9,
      91,
      1,
      1
    ],
    [
      76,
      86,
      1,
      1
    ],
    [
      14,
      93,
      1,
      1
    ],
    [
      80,
      88,
      1,
      1
    ],
    [
      19,
      95,
      1,
      1
    ],
    [
      75,
      89,
      1,
      1
    ],
    [
      24,
      97,
      1,
      1
    ],
    [
      106,
      95,
      1,
      1
    ],
    [
      29,
      99,
      1,
      1
    ],
    [
      108,
      96,
      1,
      1
    ],
    [
      155,
      90,
      1,
      1
    ],
    [
      106,
      98,
      1,
      1
    ],
    [
      158,
      93,
      1,
      1
    ],
    [
      107,
      100,
      1,
      1
    ],
    [
      161,
      96,
      1,
      1
    ],
    [
      102,
      101,
      1,
      1
    ],
    [
      164,
      99,
      1,
      1
    ],
    [
      101,
      71,
      1,
      1
    ],
    [
      76,
      64,
      1,
      1
    ],
    [
      104,
      71,
      1,
      1
    ],
    [
      82,
      64,
      1,
      1
    ],
    [
      99,
      72,
      1,
      1
    ],
    [
      88,
      64,
      1,
      1
    ],
    [
      106,
      76,
      1,
      1
    ],
    [
      94,
      64,
      1,
      1
    ],
    [
      98,
      82,
      1,
      1
    ],
    [
      100,
      64,
      1,
      1
    ],
    [
      100,
      64,
      1,
      1
    ],
    [
      61,
      48,
      1,
      1
    ],
    [
      64,
      41,
      1,
      1
    ],
    [
      74,
      48,
      1,
      1
    ],
    [
      77,
      41,
      1,
      1
    ],
    [
      87,
      48,
      1,
      1
    ],
    [
      90,
      41,
      1,
      1
    ],
    [
      61,
      53,
      1,
      1
    ],
    [
      64,
      53,
      1,
      1
    ],
    [
      74,
      53,
      1,
      1
    ],
    [
      77,
      53,
      1,
      1
    ],
    [
      87,
      53,
      1,
      1
    ],
    [
      90,
      53,
      1,
      1
    ],
    [
      61,
      48,
      1,
      1
    ],
    [
      64,
      41,
      1,
      1
    ],
    [
      74,
      48,
      1,
      1
    ],
    [
      77,
      41,
      1,
      1
    ],
    [
      87,
      48,
      1,
      1
    ],
    [
      90,
      41,
      1,
      1
    ],
    [
      61,
      53,
      1,
      1
    ],
    [
      64,
      53,
      1,
      1
    ],
    [
      74,
      53,
      1,
      1
    ],
    [
      77,
      53,
      1,
      1
    ],
    [
      87,
      53,
      1,
      1
    ],
    [
      90,
      53,
      1,
      1
    ],
    [
      61,
      48,
      1,
      1
    ],
    [
      64,
      41,
      1,
      1
    ],
    [
      74,
      48,
      1,
      1
    ],
    [
      77,
      41,
      1,
      1
    ],
    [
      87,
      48,
      1,
      1
    ],
    [
      90,
      41,
      1,
      1
    ],
    [
      61,
      53,
      1,
      1
    ],
    [
      64,
      53,
      1,
      1
    ],
    [
      74,
      53,
      1,
      1
    ],
    [
      77,
      53,
      1,
      1
    ],
    [
      87,
      53,
      1,
      1
    ],
    [
      90,
      53,
      1,
      1
    ],
    [
      61,
      48,
      1,
      1
    ],
    [
      64,
      41,
      1,
      1
    ],
    [
      74,
      48,
      1,
      1
    ],
    [
      77,
      41,
      1,
      1
    ],
    [
      87,
      48,
      1,
      1
    ],
    [
      90,
      41,
      1,
      1
    ],
    [
      61,
      53,
      1,
      1
    ],
    [
      64,
      53,
      1,
      1
    ],
    [
      74,
      53,
      1,
      1
    ],
    [
      77,
      53,
      1,
      1
    ],
    [
      87,
      53,
      1,
      1
    ],
    [
      90,
      53,
      1,
      1
    ],
    [
      126,
      56,
      1,
      1
    ],
    [
      117,
      56,
      1,
      1
    ],
    [
      126,
      64,
      1,
      1
    ],
    [
      117,
      64,
      1,
      1
    ],
    [
      126,
      56,
      1,
      1
    ],
    [
      117,
      56,
      1,
      1
    ],
    [
      126,
      64,
      1,
      1
    ],
    [
      117,
      64,
      1,
      1
    ],
    [
      22,
      47,
      1,
      1
    ],
    [
      15,
      47,
      1,
      1
    ],
    [
      22,
      57,
      1,
      1
    ],
    [
      15,
      57,
      1,
      1
    ],
    [
      22,
      47,
      1,
      1
    ],
    [
      15,
      47,
      1,
      1
    ],
    [
      22,
      57,
      1,
      1
    ],
    [
      15,
      57,
      1,
      1
    ],
    [
      131,
      31,
      1,
      1
    ],
    [
      127,
      31,
      1,
      1
    ],
    [
      158,
      32,
      1,
      1
    ],
    [
      156,
      32,
      1,
      1
    ],
    [
      163,
      61,
      1,
      1
    ],
    [
      162,
      61,
      1,
      1
    ],
    [
      164,
      35,
      1,
      1
    ],
    [
      169,
      40,
      1,
      1
    ],
    [
      72,
      98,
      1,
      1
    ],
    [
      69,
      98,
      1,
      1
    ],
    [
      102,
      98,
      1,
      1
    ],
    [
      99,
      98,
      1,
      1
    ],
    [
      6,
      91,
      1,
      1
    ],
    [
      10,
      94,
      1,
      1
    ],
    [
      13,
      89,
      1,
      1
    ],
    [
      150,
      14,
      1,
      1
    ],
    [
      154,
      19,
      1,
      1
    ],
    [
      158,
      15,
      1,
      1
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
  "id": "freight_06",
  "size": [
    180,
    150
  ],
  "offset": 17,
  "judgment": "무겁지만 많은 석탄을 얻는 대신, 사방이 트인 마당에서 싣게 되어 작업조가 드러나고 서쪽 야적 마당이 늘 열려 있다.",
  "zones": [
    [
      "I",
      "서쪽 석탄 구획",
      [
        0,
        0,
        66,
        46
      ]
    ],
    [
      "J",
      "가운데 호퍼 마당",
      [
        66,
        0,
        46,
        46
      ]
    ],
    [
      "K",
      "동쪽 석탄 설비",
      [
        112,
        0,
        68,
        46
      ]
    ]
  ],
  "floors": [
    [
      0,
      0,
      0,
      180,
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
      64,
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
      3,
      68,
      5,
      1
    ],
    [
      0,
      110,
      3,
      70,
      5,
      1
    ],
    [
      0,
      68,
      2,
      42,
      11,
      1
    ],
    [
      0,
      86,
      0,
      4,
      3,
      1
    ],
    [
      0,
      66,
      13,
      6,
      30,
      1
    ],
    [
      0,
      104,
      13,
      6,
      30,
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
      20,
      6,
      1
    ],
    [
      0,
      116,
      24,
      4,
      6,
      1
    ],
    [
      0,
      162,
      5,
      5,
      4,
      7
    ]
  ],
  "buildings": [
    {
      "id": 17,
      "name": "석탄 선별 건물",
      "rect": [
        72,
        13,
        32,
        11
      ],
      "warm": false,
      "window_broken": false
    },
    {
      "id": 18,
      "name": "서쪽 석탄 창고",
      "rect": [
        24,
        11,
        42,
        13
      ],
      "warm": false,
      "window_broken": false
    },
    {
      "id": 19,
      "name": "동쪽 석탄 창고",
      "rect": [
        110,
        10,
        20,
        14
      ],
      "warm": false,
      "window_broken": false
    },
    {
      "id": 20,
      "name": "석탄 사무소",
      "rect": [
        4,
        8,
        12,
        8
      ],
      "warm": false,
      "window_broken": false
    },
    {
      "id": 21,
      "name": "수선 헛간",
      "rect": [
        134,
        10,
        16,
        10
      ],
      "warm": false,
      "window_broken": false
    },
    {
      "id": 22,
      "name": "동북 석탄 저장고",
      "rect": [
        160,
        9,
        16,
        11
      ],
      "warm": false,
      "window_broken": false
    },
    {
      "id": 23,
      "name": "동력실",
      "rect": [
        116,
        30,
        14,
        16
      ],
      "warm": false,
      "window_broken": false
    },
    {
      "id": 24,
      "name": "모래 창고",
      "rect": [
        140,
        38,
        10,
        8
      ],
      "warm": false,
      "window_broken": false
    }
  ],
  "shells": [
    [
      17,
      -1,
      72,
      13,
      32,
      11
    ],
    [
      17,
      0,
      72,
      13,
      32,
      11
    ],
    [
      17,
      1,
      72,
      13,
      32,
      11
    ],
    [
      17,
      2,
      72,
      13,
      32,
      11
    ],
    [
      18,
      0,
      24,
      11,
      42,
      13
    ],
    [
      19,
      0,
      110,
      10,
      20,
      14
    ],
    [
      19,
      1,
      110,
      10,
      20,
      14
    ],
    [
      20,
      0,
      4,
      8,
      12,
      8
    ],
    [
      21,
      0,
      134,
      10,
      16,
      10
    ],
    [
      22,
      -1,
      160,
      9,
      16,
      11
    ],
    [
      22,
      0,
      160,
      9,
      16,
      11
    ],
    [
      23,
      0,
      116,
      30,
      14,
      16
    ],
    [
      24,
      0,
      140,
      38,
      10,
      8
    ]
  ],
  "walls": [
    [
      -1,
      73,
      20,
      30,
      1
    ],
    [
      -1,
      77,
      14,
      1,
      6
    ],
    [
      -1,
      82,
      14,
      1,
      6
    ],
    [
      -1,
      87,
      14,
      1,
      6
    ],
    [
      -1,
      92,
      14,
      1,
      6
    ],
    [
      -1,
      97,
      14,
      1,
      6
    ],
    [
      0,
      73,
      20,
      30,
      1
    ],
    [
      0,
      77,
      14,
      1,
      6
    ],
    [
      0,
      82,
      14,
      1,
      6
    ],
    [
      0,
      87,
      14,
      1,
      6
    ],
    [
      0,
      92,
      14,
      1,
      6
    ],
    [
      0,
      97,
      14,
      1,
      6
    ],
    [
      1,
      73,
      20,
      30,
      1
    ],
    [
      1,
      77,
      14,
      1,
      6
    ],
    [
      1,
      82,
      14,
      1,
      6
    ],
    [
      1,
      87,
      14,
      1,
      6
    ],
    [
      1,
      92,
      14,
      1,
      6
    ],
    [
      1,
      97,
      14,
      1,
      6
    ],
    [
      2,
      73,
      20,
      30,
      1
    ],
    [
      2,
      77,
      14,
      1,
      6
    ],
    [
      2,
      82,
      14,
      1,
      6
    ],
    [
      2,
      87,
      14,
      1,
      6
    ],
    [
      2,
      92,
      14,
      1,
      6
    ],
    [
      2,
      97,
      14,
      1,
      6
    ],
    [
      0,
      25,
      20,
      40,
      1
    ],
    [
      0,
      30,
      12,
      1,
      8
    ],
    [
      0,
      37,
      12,
      1,
      8
    ],
    [
      0,
      44,
      12,
      1,
      8
    ],
    [
      0,
      51,
      12,
      1,
      8
    ],
    [
      0,
      58,
      12,
      1,
      8
    ],
    [
      0,
      120,
      11,
      1,
      12
    ],
    [
      1,
      120,
      11,
      1,
      12
    ],
    [
      0,
      142,
      11,
      1,
      8
    ],
    [
      -1,
      161,
      12,
      14,
      1
    ],
    [
      -1,
      167,
      13,
      1,
      6
    ],
    [
      0,
      168,
      10,
      1,
      9
    ],
    [
      0,
      123,
      31,
      1,
      14
    ]
  ],
  "openings": [
    [
      -1,
      74,
      21,
      1,
      2
    ],
    [
      0,
      74,
      21,
      1,
      2
    ],
    [
      0,
      74,
      21,
      1,
      2
    ],
    [
      1,
      74,
      21,
      1,
      2
    ],
    [
      1,
      74,
      21,
      1,
      2
    ],
    [
      2,
      74,
      21,
      1,
      2
    ],
    [
      -1,
      101,
      21,
      1,
      2
    ],
    [
      0,
      101,
      21,
      1,
      2
    ],
    [
      0,
      101,
      21,
      1,
      2
    ],
    [
      1,
      101,
      21,
      1,
      2
    ],
    [
      1,
      101,
      21,
      1,
      2
    ],
    [
      2,
      101,
      21,
      1,
      2
    ],
    [
      0,
      112,
      17,
      1,
      2
    ],
    [
      1,
      112,
      17,
      1,
      2
    ],
    [
      -1,
      162,
      10,
      1,
      6
    ],
    [
      0,
      162,
      14,
      1,
      2
    ]
  ],
  "doors": [
    [
      -1,
      75,
      20,
      17,
      "closed",
      0,
      1
    ],
    [
      -1,
      80,
      20,
      17,
      "closed",
      0,
      1
    ],
    [
      -1,
      85,
      20,
      17,
      "closed",
      0,
      1
    ],
    [
      -1,
      90,
      20,
      17,
      "closed",
      0,
      1
    ],
    [
      -1,
      95,
      20,
      17,
      "closed",
      0,
      1
    ],
    [
      -1,
      100,
      20,
      17,
      "closed",
      0,
      1
    ],
    [
      0,
      75,
      20,
      17,
      "closed",
      0,
      1
    ],
    [
      0,
      80,
      20,
      17,
      "closed",
      0,
      1
    ],
    [
      0,
      85,
      20,
      17,
      "closed",
      0,
      1
    ],
    [
      0,
      90,
      20,
      17,
      "closed",
      0,
      1
    ],
    [
      0,
      95,
      20,
      17,
      "closed",
      0,
      1
    ],
    [
      0,
      100,
      20,
      17,
      "closed",
      0,
      1
    ],
    [
      1,
      75,
      20,
      17,
      "closed",
      0,
      1
    ],
    [
      1,
      80,
      20,
      17,
      "closed",
      0,
      1
    ],
    [
      1,
      85,
      20,
      17,
      "closed",
      0,
      1
    ],
    [
      1,
      90,
      20,
      17,
      "closed",
      0,
      1
    ],
    [
      1,
      95,
      20,
      17,
      "closed",
      0,
      1
    ],
    [
      1,
      100,
      20,
      17,
      "closed",
      0,
      1
    ],
    [
      2,
      75,
      20,
      17,
      "closed",
      0,
      1
    ],
    [
      2,
      80,
      20,
      17,
      "closed",
      0,
      1
    ],
    [
      2,
      85,
      20,
      17,
      "closed",
      0,
      1
    ],
    [
      2,
      90,
      20,
      17,
      "closed",
      0,
      1
    ],
    [
      2,
      95,
      20,
      17,
      "closed",
      0,
      1
    ],
    [
      2,
      100,
      20,
      17,
      "closed",
      0,
      1
    ],
    [
      0,
      75,
      13,
      17,
      "closed",
      0,
      1
    ],
    [
      0,
      27,
      20,
      18,
      "closed",
      0,
      1
    ],
    [
      0,
      34,
      20,
      18,
      "closed",
      0,
      1
    ],
    [
      0,
      41,
      20,
      18,
      "closed",
      0,
      1
    ],
    [
      0,
      48,
      20,
      18,
      "closed",
      0,
      1
    ],
    [
      0,
      55,
      20,
      18,
      "closed",
      0,
      1
    ],
    [
      0,
      62,
      20,
      18,
      "closed",
      0,
      1
    ],
    [
      0,
      27,
      11,
      18,
      "closed",
      0,
      1
    ],
    [
      0,
      120,
      17,
      19,
      "closed",
      1,
      0
    ],
    [
      1,
      120,
      17,
      19,
      "closed",
      1,
      0
    ],
    [
      0,
      115,
      10,
      19,
      "closed",
      0,
      1
    ],
    [
      0,
      15,
      12,
      20,
      "closed",
      1,
      0
    ],
    [
      0,
      142,
      15,
      21,
      "closed",
      1,
      0
    ],
    [
      0,
      138,
      10,
      21,
      "closed",
      0,
      1
    ],
    [
      -1,
      164,
      12,
      22,
      "closed",
      0,
      1
    ],
    [
      -1,
      171,
      12,
      22,
      "closed",
      0,
      1
    ],
    [
      0,
      168,
      14,
      22,
      "closed",
      1,
      0
    ],
    [
      0,
      164,
      9,
      22,
      "closed",
      0,
      1
    ],
    [
      0,
      123,
      38,
      23,
      "closed",
      1,
      0
    ],
    [
      0,
      129,
      38,
      23,
      "closed",
      1,
      0
    ],
    [
      0,
      149,
      42,
      24,
      "closed",
      1,
      0
    ]
  ],
  "windows": [
    [
      0,
      75,
      13,
      17
    ],
    [
      0,
      82,
      13,
      17
    ],
    [
      0,
      89,
      13,
      17
    ],
    [
      0,
      96,
      13,
      17
    ],
    [
      0,
      103,
      16,
      17
    ],
    [
      0,
      103,
      21,
      17
    ],
    [
      1,
      75,
      13,
      17
    ],
    [
      1,
      82,
      13,
      17
    ],
    [
      1,
      89,
      13,
      17
    ],
    [
      1,
      96,
      13,
      17
    ],
    [
      1,
      103,
      16,
      17
    ],
    [
      1,
      103,
      21,
      17
    ],
    [
      2,
      75,
      13,
      17
    ],
    [
      2,
      82,
      13,
      17
    ],
    [
      2,
      89,
      13,
      17
    ],
    [
      2,
      96,
      13,
      17
    ],
    [
      2,
      103,
      16,
      17
    ],
    [
      2,
      103,
      21,
      17
    ],
    [
      0,
      27,
      11,
      18
    ],
    [
      0,
      34,
      11,
      18
    ],
    [
      0,
      41,
      11,
      18
    ],
    [
      0,
      48,
      11,
      18
    ],
    [
      0,
      55,
      11,
      18
    ],
    [
      0,
      62,
      11,
      18
    ],
    [
      0,
      65,
      14,
      18
    ],
    [
      0,
      65,
      19,
      18
    ],
    [
      0,
      113,
      10,
      19
    ],
    [
      0,
      120,
      10,
      19
    ],
    [
      0,
      127,
      10,
      19
    ],
    [
      0,
      129,
      13,
      19
    ],
    [
      0,
      129,
      18,
      19
    ],
    [
      1,
      113,
      10,
      19
    ],
    [
      1,
      120,
      10,
      19
    ],
    [
      1,
      127,
      10,
      19
    ],
    [
      1,
      129,
      13,
      19
    ],
    [
      1,
      129,
      18,
      19
    ],
    [
      0,
      7,
      8,
      20
    ],
    [
      0,
      15,
      11,
      20
    ],
    [
      0,
      137,
      10,
      21
    ],
    [
      0,
      144,
      10,
      21
    ],
    [
      0,
      149,
      13,
      21
    ],
    [
      0,
      163,
      9,
      22
    ],
    [
      0,
      170,
      9,
      22
    ],
    [
      0,
      175,
      12,
      22
    ],
    [
      0,
      175,
      17,
      22
    ],
    [
      0,
      119,
      30,
      23
    ],
    [
      0,
      126,
      30,
      23
    ],
    [
      0,
      129,
      33,
      23
    ],
    [
      0,
      129,
      38,
      23
    ],
    [
      0,
      129,
      43,
      23
    ],
    [
      0,
      143,
      38,
      24
    ],
    [
      0,
      149,
      41,
      24
    ]
  ],
  "rooms": [
    {
      "building": 17,
      "level": -1,
      "rect": [
        73,
        14,
        4,
        6
      ],
      "name": "석탄 앞 저장고"
    },
    {
      "building": 17,
      "level": -1,
      "rect": [
        78,
        14,
        4,
        6
      ],
      "name": "석탄 안쪽 보관실"
    },
    {
      "building": 17,
      "level": -1,
      "rect": [
        83,
        14,
        4,
        6
      ],
      "name": "석탄 앞 저장고"
    },
    {
      "building": 17,
      "level": -1,
      "rect": [
        88,
        14,
        4,
        6
      ],
      "name": "석탄 안쪽 보관실"
    },
    {
      "building": 17,
      "level": -1,
      "rect": [
        93,
        14,
        4,
        6
      ],
      "name": "석탄 앞 저장고"
    },
    {
      "building": 17,
      "level": -1,
      "rect": [
        98,
        14,
        5,
        6
      ],
      "name": "석탄 안쪽 보관실"
    },
    {
      "building": 17,
      "level": 0,
      "rect": [
        73,
        14,
        4,
        6
      ],
      "name": "선별실"
    },
    {
      "building": 17,
      "level": 0,
      "rect": [
        78,
        14,
        4,
        6
      ],
      "name": "계량실"
    },
    {
      "building": 17,
      "level": 0,
      "rect": [
        83,
        14,
        4,
        6
      ],
      "name": "사무 칸"
    },
    {
      "building": 17,
      "level": 0,
      "rect": [
        88,
        14,
        4,
        6
      ],
      "name": "원료 칸"
    },
    {
      "building": 17,
      "level": 0,
      "rect": [
        93,
        14,
        4,
        6
      ],
      "name": "공구 칸"
    },
    {
      "building": 17,
      "level": 0,
      "rect": [
        98,
        14,
        5,
        6
      ],
      "name": "안쪽 보관실"
    },
    {
      "building": 17,
      "level": 1,
      "rect": [
        73,
        14,
        4,
        6
      ],
      "name": "선별실"
    },
    {
      "building": 17,
      "level": 1,
      "rect": [
        78,
        14,
        4,
        6
      ],
      "name": "계량실"
    },
    {
      "building": 17,
      "level": 1,
      "rect": [
        83,
        14,
        4,
        6
      ],
      "name": "사무 칸"
    },
    {
      "building": 17,
      "level": 1,
      "rect": [
        88,
        14,
        4,
        6
      ],
      "name": "원료 칸"
    },
    {
      "building": 17,
      "level": 1,
      "rect": [
        93,
        14,
        4,
        6
      ],
      "name": "공구 칸"
    },
    {
      "building": 17,
      "level": 1,
      "rect": [
        98,
        14,
        5,
        6
      ],
      "name": "안쪽 보관실"
    },
    {
      "building": 17,
      "level": 2,
      "rect": [
        73,
        14,
        4,
        6
      ],
      "name": "선별실"
    },
    {
      "building": 17,
      "level": 2,
      "rect": [
        78,
        14,
        4,
        6
      ],
      "name": "계량실"
    },
    {
      "building": 17,
      "level": 2,
      "rect": [
        83,
        14,
        4,
        6
      ],
      "name": "사무 칸"
    },
    {
      "building": 17,
      "level": 2,
      "rect": [
        88,
        14,
        4,
        6
      ],
      "name": "원료 칸"
    },
    {
      "building": 17,
      "level": 2,
      "rect": [
        93,
        14,
        4,
        6
      ],
      "name": "공구 칸"
    },
    {
      "building": 17,
      "level": 2,
      "rect": [
        98,
        14,
        5,
        6
      ],
      "name": "안쪽 보관실"
    },
    {
      "building": 18,
      "level": 0,
      "rect": [
        25,
        12,
        5,
        8
      ],
      "name": "선별실"
    },
    {
      "building": 18,
      "level": 0,
      "rect": [
        31,
        12,
        6,
        8
      ],
      "name": "계량실"
    },
    {
      "building": 18,
      "level": 0,
      "rect": [
        38,
        12,
        6,
        8
      ],
      "name": "사무 칸"
    },
    {
      "building": 18,
      "level": 0,
      "rect": [
        45,
        12,
        6,
        8
      ],
      "name": "원료 칸"
    },
    {
      "building": 18,
      "level": 0,
      "rect": [
        52,
        12,
        6,
        8
      ],
      "name": "공구 칸"
    },
    {
      "building": 18,
      "level": 0,
      "rect": [
        59,
        12,
        6,
        8
      ],
      "name": "안쪽 보관실"
    },
    {
      "building": 19,
      "level": 0,
      "rect": [
        111,
        11,
        9,
        12
      ],
      "name": "앞 작업 칸"
    },
    {
      "building": 19,
      "level": 0,
      "rect": [
        121,
        11,
        8,
        12
      ],
      "name": "안쪽 보관실"
    },
    {
      "building": 19,
      "level": 1,
      "rect": [
        111,
        11,
        9,
        12
      ],
      "name": "앞 작업 칸"
    },
    {
      "building": 19,
      "level": 1,
      "rect": [
        121,
        11,
        8,
        12
      ],
      "name": "안쪽 보관실"
    },
    {
      "building": 20,
      "level": 0,
      "rect": [
        5,
        9,
        10,
        6
      ],
      "name": "작업 칸"
    },
    {
      "building": 21,
      "level": 0,
      "rect": [
        135,
        11,
        7,
        8
      ],
      "name": "앞 작업 칸"
    },
    {
      "building": 21,
      "level": 0,
      "rect": [
        143,
        11,
        6,
        8
      ],
      "name": "안쪽 보관실"
    },
    {
      "building": 22,
      "level": -1,
      "rect": [
        161,
        13,
        6,
        6
      ],
      "name": "석탄 앞 저장고"
    },
    {
      "building": 22,
      "level": -1,
      "rect": [
        168,
        13,
        7,
        6
      ],
      "name": "석탄 안쪽 보관실"
    },
    {
      "building": 22,
      "level": 0,
      "rect": [
        161,
        10,
        7,
        9
      ],
      "name": "앞 작업 칸"
    },
    {
      "building": 22,
      "level": 0,
      "rect": [
        169,
        10,
        6,
        9
      ],
      "name": "안쪽 보관실"
    },
    {
      "building": 23,
      "level": 0,
      "rect": [
        117,
        31,
        6,
        14
      ],
      "name": "앞 작업 칸"
    },
    {
      "building": 23,
      "level": 0,
      "rect": [
        124,
        31,
        5,
        14
      ],
      "name": "안쪽 보관실"
    },
    {
      "building": 24,
      "level": 0,
      "rect": [
        141,
        39,
        8,
        6
      ],
      "name": "작업 칸"
    }
  ],
  "stairs": [
    {
      "cell": [
        74,
        21
      ],
      "low": -1,
      "high": 0,
      "ladder": false
    },
    {
      "cell": [
        74,
        21
      ],
      "low": 0,
      "high": 1,
      "ladder": false
    },
    {
      "cell": [
        74,
        21
      ],
      "low": 1,
      "high": 2,
      "ladder": false
    },
    {
      "cell": [
        101,
        22
      ],
      "low": -1,
      "high": 0,
      "ladder": false
    },
    {
      "cell": [
        101,
        22
      ],
      "low": 0,
      "high": 1,
      "ladder": false
    },
    {
      "cell": [
        101,
        22
      ],
      "low": 1,
      "high": 2,
      "ladder": false
    },
    {
      "cell": [
        112,
        17
      ],
      "low": 0,
      "high": 1,
      "ladder": false
    },
    {
      "cell": [
        162,
        14
      ],
      "low": -1,
      "high": 0,
      "ladder": false
    }
  ],
  "props": [
    {
      "kind": "coal_heap",
      "rect": [
        31,
        38,
        3,
        2
      ],
      "solid": "low",
      "facing": 0,
      "note": "석탄 더미",
      "level": 0
    },
    {
      "kind": "crate_stack",
      "rect": [
        48,
        37,
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
        96,
        36,
        1,
        2
      ],
      "solid": "low",
      "facing": 0,
      "note": "손수레",
      "level": 0
    },
    {
      "kind": "coal_heap",
      "rect": [
        78,
        30,
        4,
        2
      ],
      "solid": "low",
      "facing": 0,
      "note": "석탄 더미",
      "level": 0
    },
    {
      "kind": "coal_hopper",
      "rect": [
        88,
        5,
        3,
        3
      ],
      "solid": "wall",
      "facing": 0,
      "note": "석탄 호퍼",
      "level": 0
    },
    {
      "kind": "coal_wagon",
      "rect": [
        74,
        4,
        10,
        3
      ],
      "solid": "wagon",
      "facing": 0,
      "note": "옆문 열린 석탄 화차",
      "level": 0
    },
    {
      "kind": "coal_wagon",
      "rect": [
        95,
        4,
        10,
        3
      ],
      "solid": "wagon",
      "facing": 0,
      "note": "옆문 열린 석탄 화차",
      "level": 0
    },
    {
      "kind": "bare_tree",
      "rect": [
        2,
        17,
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
        12,
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
        20,
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
        29,
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
        42,
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
        50,
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
        150,
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
      "kind": "bare_tree",
      "rect": [
        155,
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
        164,
        27,
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
        173,
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
      "kind": "bare_tree",
      "rect": [
        177,
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
      "kind": "car",
      "rect": [
        142,
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
        73,
        14,
        3,
        1
      ],
      "solid": "none",
      "facing": 0,
      "note": "석탄 앞 저장고 곁 선반",
      "level": -1
    },
    {
      "kind": "desk",
      "rect": [
        73,
        15,
        2,
        1
      ],
      "solid": "none",
      "facing": 0,
      "note": "석탄 앞 저장고 곁 책상",
      "level": -1
    },
    {
      "kind": "file_cabinet",
      "rect": [
        75,
        15,
        2,
        1
      ],
      "solid": "none",
      "facing": 0,
      "note": "석탄 앞 저장고 곁 서류함",
      "level": -1
    },
    {
      "kind": "coal_heap",
      "rect": [
        78,
        14,
        3,
        2
      ],
      "solid": "none",
      "facing": 0,
      "note": "석탄 안쪽 보관실 곁 석탄 더미",
      "level": -1
    },
    {
      "kind": "pallet_stack",
      "rect": [
        78,
        16,
        2,
        2
      ],
      "solid": "none",
      "facing": 0,
      "note": "석탄 안쪽 보관실 곁 팰릿 더미",
      "level": -1
    },
    {
      "kind": "barrel",
      "rect": [
        81,
        14,
        1,
        1
      ],
      "solid": "none",
      "facing": 0,
      "note": "석탄 안쪽 보관실 곁 통",
      "level": -1
    },
    {
      "kind": "tool_cart",
      "rect": [
        83,
        14,
        2,
        1
      ],
      "solid": "none",
      "facing": 0,
      "note": "석탄 앞 저장고 곁 공구 수레",
      "level": -1
    },
    {
      "kind": "part_crate",
      "rect": [
        85,
        14,
        1,
        1
      ],
      "solid": "none",
      "facing": 0,
      "note": "석탄 앞 저장고 곁 부품 상자",
      "level": -1
    },
    {
      "kind": "coupler_set",
      "rect": [
        86,
        14,
        1,
        1
      ],
      "solid": "none",
      "facing": 0,
      "note": "석탄 앞 저장고 곁 연결기 한 벌",
      "level": -1
    },
    {
      "kind": "sack_pile",
      "rect": [
        88,
        14,
        2,
        2
      ],
      "solid": "none",
      "facing": 0,
      "note": "석탄 안쪽 보관실 곁 자루 더미",
      "level": -1
    },
    {
      "kind": "handcart",
      "rect": [
        90,
        14,
        2,
        1
      ],
      "solid": "none",
      "facing": 0,
      "note": "석탄 안쪽 보관실 곁 손수레",
      "level": -1
    },
    {
      "kind": "barrel",
      "rect": [
        91,
        15,
        1,
        1
      ],
      "solid": "none",
      "facing": 0,
      "note": "석탄 안쪽 보관실 곁 통",
      "level": -1
    },
    {
      "kind": "shelf",
      "rect": [
        93,
        14,
        3,
        1
      ],
      "solid": "none",
      "facing": 0,
      "note": "석탄 앞 저장고 곁 선반",
      "level": -1
    },
    {
      "kind": "crate_stack",
      "rect": [
        93,
        15,
        2,
        2
      ],
      "solid": "none",
      "facing": 0,
      "note": "석탄 앞 저장고 곁 나무 상자 더미",
      "level": -1
    },
    {
      "kind": "rope_coil",
      "rect": [
        96,
        14,
        1,
        1
      ],
      "solid": "none",
      "facing": 0,
      "note": "석탄 앞 저장고 곁 밧줄 더미",
      "level": -1
    },
    {
      "kind": "coal_heap",
      "rect": [
        98,
        14,
        3,
        2
      ],
      "solid": "none",
      "facing": 0,
      "note": "석탄 안쪽 보관실 곁 석탄 더미",
      "level": -1
    },
    {
      "kind": "part_crate",
      "rect": [
        101,
        14,
        1,
        1
      ],
      "solid": "none",
      "facing": 0,
      "note": "석탄 안쪽 보관실 곁 부품 상자",
      "level": -1
    },
    {
      "kind": "barrel",
      "rect": [
        102,
        14,
        1,
        1
      ],
      "solid": "none",
      "facing": 0,
      "note": "석탄 안쪽 보관실 곁 통",
      "level": -1
    },
    {
      "kind": "desk",
      "rect": [
        73,
        14,
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
        73,
        15,
        2,
        1
      ],
      "solid": "low",
      "facing": 0,
      "note": "선별실 곁 서류함",
      "level": 0
    },
    {
      "kind": "coal_heap",
      "rect": [
        78,
        14,
        3,
        2
      ],
      "solid": "low",
      "facing": 0,
      "note": "계량실 곁 석탄 더미",
      "level": 0
    },
    {
      "kind": "pallet_stack",
      "rect": [
        78,
        16,
        2,
        2
      ],
      "solid": "low",
      "facing": 0,
      "note": "계량실 곁 팰릿 더미",
      "level": 0
    },
    {
      "kind": "barrel",
      "rect": [
        81,
        14,
        1,
        1
      ],
      "solid": "low",
      "facing": 0,
      "note": "계량실 곁 통",
      "level": 0
    },
    {
      "kind": "tool_cart",
      "rect": [
        83,
        14,
        2,
        1
      ],
      "solid": "low",
      "facing": 0,
      "note": "사무 칸 곁 공구 수레",
      "level": 0
    },
    {
      "kind": "part_crate",
      "rect": [
        85,
        14,
        1,
        1
      ],
      "solid": "low",
      "facing": 0,
      "note": "사무 칸 곁 부품 상자",
      "level": 0
    },
    {
      "kind": "coupler_set",
      "rect": [
        86,
        14,
        1,
        1
      ],
      "solid": "low",
      "facing": 0,
      "note": "사무 칸 곁 연결기 한 벌",
      "level": 0
    },
    {
      "kind": "sack_pile",
      "rect": [
        88,
        14,
        2,
        2
      ],
      "solid": "low",
      "facing": 0,
      "note": "원료 칸 곁 자루 더미",
      "level": 0
    },
    {
      "kind": "handcart",
      "rect": [
        90,
        14,
        2,
        1
      ],
      "solid": "low",
      "facing": 0,
      "note": "원료 칸 곁 손수레",
      "level": 0
    },
    {
      "kind": "barrel",
      "rect": [
        91,
        15,
        1,
        1
      ],
      "solid": "low",
      "facing": 0,
      "note": "원료 칸 곁 통",
      "level": 0
    },
    {
      "kind": "shelf",
      "rect": [
        93,
        14,
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
        93,
        15,
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
        96,
        14,
        1,
        1
      ],
      "solid": "low",
      "facing": 0,
      "note": "공구 칸 곁 밧줄 더미",
      "level": 0
    },
    {
      "kind": "coal_heap",
      "rect": [
        98,
        14,
        3,
        2
      ],
      "solid": "low",
      "facing": 0,
      "note": "안쪽 보관실 곁 석탄 더미",
      "level": 0
    },
    {
      "kind": "part_crate",
      "rect": [
        101,
        14,
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
        102,
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
        73,
        14,
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
        73,
        15,
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
        75,
        15,
        2,
        1
      ],
      "solid": "none",
      "facing": 0,
      "note": "선별실 곁 서류함",
      "level": 1
    },
    {
      "kind": "coal_heap",
      "rect": [
        78,
        14,
        3,
        2
      ],
      "solid": "none",
      "facing": 0,
      "note": "계량실 곁 석탄 더미",
      "level": 1
    },
    {
      "kind": "pallet_stack",
      "rect": [
        78,
        16,
        2,
        2
      ],
      "solid": "none",
      "facing": 0,
      "note": "계량실 곁 팰릿 더미",
      "level": 1
    },
    {
      "kind": "barrel",
      "rect": [
        81,
        14,
        1,
        1
      ],
      "solid": "none",
      "facing": 0,
      "note": "계량실 곁 통",
      "level": 1
    },
    {
      "kind": "tool_cart",
      "rect": [
        83,
        14,
        2,
        1
      ],
      "solid": "none",
      "facing": 0,
      "note": "사무 칸 곁 공구 수레",
      "level": 1
    },
    {
      "kind": "part_crate",
      "rect": [
        85,
        14,
        1,
        1
      ],
      "solid": "none",
      "facing": 0,
      "note": "사무 칸 곁 부품 상자",
      "level": 1
    },
    {
      "kind": "coupler_set",
      "rect": [
        86,
        14,
        1,
        1
      ],
      "solid": "none",
      "facing": 0,
      "note": "사무 칸 곁 연결기 한 벌",
      "level": 1
    },
    {
      "kind": "sack_pile",
      "rect": [
        88,
        14,
        2,
        2
      ],
      "solid": "none",
      "facing": 0,
      "note": "원료 칸 곁 자루 더미",
      "level": 1
    },
    {
      "kind": "handcart",
      "rect": [
        90,
        14,
        2,
        1
      ],
      "solid": "none",
      "facing": 0,
      "note": "원료 칸 곁 손수레",
      "level": 1
    },
    {
      "kind": "barrel",
      "rect": [
        91,
        15,
        1,
        1
      ],
      "solid": "none",
      "facing": 0,
      "note": "원료 칸 곁 통",
      "level": 1
    },
    {
      "kind": "shelf",
      "rect": [
        93,
        14,
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
        93,
        15,
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
        96,
        14,
        1,
        1
      ],
      "solid": "none",
      "facing": 0,
      "note": "공구 칸 곁 밧줄 더미",
      "level": 1
    },
    {
      "kind": "coal_heap",
      "rect": [
        98,
        14,
        3,
        2
      ],
      "solid": "none",
      "facing": 0,
      "note": "안쪽 보관실 곁 석탄 더미",
      "level": 1
    },
    {
      "kind": "part_crate",
      "rect": [
        101,
        14,
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
        102,
        14,
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
        73,
        14,
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
        73,
        15,
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
        75,
        15,
        2,
        1
      ],
      "solid": "none",
      "facing": 0,
      "note": "선별실 곁 서류함",
      "level": 2
    },
    {
      "kind": "coal_heap",
      "rect": [
        78,
        14,
        3,
        2
      ],
      "solid": "none",
      "facing": 0,
      "note": "계량실 곁 석탄 더미",
      "level": 2
    },
    {
      "kind": "pallet_stack",
      "rect": [
        78,
        16,
        2,
        2
      ],
      "solid": "none",
      "facing": 0,
      "note": "계량실 곁 팰릿 더미",
      "level": 2
    },
    {
      "kind": "barrel",
      "rect": [
        81,
        14,
        1,
        1
      ],
      "solid": "none",
      "facing": 0,
      "note": "계량실 곁 통",
      "level": 2
    },
    {
      "kind": "tool_cart",
      "rect": [
        83,
        14,
        2,
        1
      ],
      "solid": "none",
      "facing": 0,
      "note": "사무 칸 곁 공구 수레",
      "level": 2
    },
    {
      "kind": "part_crate",
      "rect": [
        85,
        14,
        1,
        1
      ],
      "solid": "none",
      "facing": 0,
      "note": "사무 칸 곁 부품 상자",
      "level": 2
    },
    {
      "kind": "coupler_set",
      "rect": [
        86,
        14,
        1,
        1
      ],
      "solid": "none",
      "facing": 0,
      "note": "사무 칸 곁 연결기 한 벌",
      "level": 2
    },
    {
      "kind": "sack_pile",
      "rect": [
        88,
        14,
        2,
        2
      ],
      "solid": "none",
      "facing": 0,
      "note": "원료 칸 곁 자루 더미",
      "level": 2
    },
    {
      "kind": "handcart",
      "rect": [
        90,
        14,
        2,
        1
      ],
      "solid": "none",
      "facing": 0,
      "note": "원료 칸 곁 손수레",
      "level": 2
    },
    {
      "kind": "barrel",
      "rect": [
        91,
        15,
        1,
        1
      ],
      "solid": "none",
      "facing": 0,
      "note": "원료 칸 곁 통",
      "level": 2
    },
    {
      "kind": "shelf",
      "rect": [
        93,
        14,
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
        93,
        15,
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
        96,
        14,
        1,
        1
      ],
      "solid": "none",
      "facing": 0,
      "note": "공구 칸 곁 밧줄 더미",
      "level": 2
    },
    {
      "kind": "coal_heap",
      "rect": [
        98,
        14,
        3,
        2
      ],
      "solid": "none",
      "facing": 0,
      "note": "안쪽 보관실 곁 석탄 더미",
      "level": 2
    },
    {
      "kind": "part_crate",
      "rect": [
        101,
        14,
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
        102,
        14,
        1,
        1
      ],
      "solid": "none",
      "facing": 0,
      "note": "안쪽 보관실 곁 통",
      "level": 2
    },
    {
      "kind": "shelf",
      "rect": [
        25,
        15,
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
        25,
        12,
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
        28,
        12,
        2,
        1
      ],
      "solid": "low",
      "facing": 0,
      "note": "선별실 곁 서류함",
      "level": 0
    },
    {
      "kind": "coal_heap",
      "rect": [
        31,
        12,
        3,
        2
      ],
      "solid": "low",
      "facing": 0,
      "note": "계량실 곁 석탄 더미",
      "level": 0
    },
    {
      "kind": "pallet_stack",
      "rect": [
        34,
        12,
        2,
        2
      ],
      "solid": "low",
      "facing": 0,
      "note": "계량실 곁 팰릿 더미",
      "level": 0
    },
    {
      "kind": "barrel",
      "rect": [
        36,
        12,
        1,
        1
      ],
      "solid": "low",
      "facing": 0,
      "note": "계량실 곁 통",
      "level": 0
    },
    {
      "kind": "tool_cart",
      "rect": [
        38,
        12,
        2,
        1
      ],
      "solid": "low",
      "facing": 0,
      "note": "사무 칸 곁 공구 수레",
      "level": 0
    },
    {
      "kind": "part_crate",
      "rect": [
        40,
        12,
        1,
        1
      ],
      "solid": "low",
      "facing": 0,
      "note": "사무 칸 곁 부품 상자",
      "level": 0
    },
    {
      "kind": "coupler_set",
      "rect": [
        41,
        12,
        1,
        1
      ],
      "solid": "low",
      "facing": 0,
      "note": "사무 칸 곁 연결기 한 벌",
      "level": 0
    },
    {
      "kind": "sack_pile",
      "rect": [
        45,
        12,
        2,
        2
      ],
      "solid": "low",
      "facing": 0,
      "note": "원료 칸 곁 자루 더미",
      "level": 0
    },
    {
      "kind": "handcart",
      "rect": [
        47,
        12,
        2,
        1
      ],
      "solid": "low",
      "facing": 0,
      "note": "원료 칸 곁 손수레",
      "level": 0
    },
    {
      "kind": "barrel",
      "rect": [
        49,
        12,
        1,
        1
      ],
      "solid": "low",
      "facing": 0,
      "note": "원료 칸 곁 통",
      "level": 0
    },
    {
      "kind": "shelf",
      "rect": [
        52,
        12,
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
        55,
        12,
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
        57,
        12,
        1,
        1
      ],
      "solid": "low",
      "facing": 0,
      "note": "공구 칸 곁 밧줄 더미",
      "level": 0
    },
    {
      "kind": "coal_heap",
      "rect": [
        59,
        12,
        3,
        2
      ],
      "solid": "low",
      "facing": 0,
      "note": "안쪽 보관실 곁 석탄 더미",
      "level": 0
    },
    {
      "kind": "part_crate",
      "rect": [
        62,
        12,
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
        63,
        12,
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
        111,
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
        116,
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
        118,
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
      "kind": "coal_heap",
      "rect": [
        121,
        11,
        3,
        2
      ],
      "solid": "low",
      "facing": 0,
      "note": "안쪽 보관실 곁 석탄 더미",
      "level": 0
    },
    {
      "kind": "pallet_stack",
      "rect": [
        124,
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
        126,
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
        111,
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
        113,
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
        114,
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
        121,
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
        123,
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
        125,
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
        5,
        9,
        3,
        1
      ],
      "solid": "low",
      "facing": 0,
      "note": "작업 칸 곁 선반",
      "level": 0
    },
    {
      "kind": "crate_stack",
      "rect": [
        8,
        9,
        2,
        2
      ],
      "solid": "low",
      "facing": 0,
      "note": "작업 칸 곁 나무 상자 더미",
      "level": 0
    },
    {
      "kind": "rope_coil",
      "rect": [
        10,
        9,
        1,
        1
      ],
      "solid": "low",
      "facing": 0,
      "note": "작업 칸 곁 밧줄 더미",
      "level": 0
    },
    {
      "kind": "coal_heap",
      "rect": [
        135,
        11,
        3,
        2
      ],
      "solid": "low",
      "facing": 0,
      "note": "앞 작업 칸 곁 석탄 더미",
      "level": 0
    },
    {
      "kind": "part_crate",
      "rect": [
        139,
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
        140,
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
      "kind": "shelf",
      "rect": [
        143,
        11,
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
        146,
        11,
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
        143,
        12,
        2,
        1
      ],
      "solid": "low",
      "facing": 0,
      "note": "안쪽 보관실 곁 서류함",
      "level": 0
    },
    {
      "kind": "coal_heap",
      "rect": [
        161,
        15,
        3,
        2
      ],
      "solid": "none",
      "facing": 0,
      "note": "석탄 앞 저장고 곁 석탄 더미",
      "level": -1
    },
    {
      "kind": "part_crate",
      "rect": [
        161,
        13,
        1,
        1
      ],
      "solid": "none",
      "facing": 0,
      "note": "석탄 앞 저장고 곁 부품 상자",
      "level": -1
    },
    {
      "kind": "barrel",
      "rect": [
        162,
        13,
        1,
        1
      ],
      "solid": "none",
      "facing": 0,
      "note": "석탄 앞 저장고 곁 통",
      "level": -1
    },
    {
      "kind": "tool_cart",
      "rect": [
        165,
        13,
        2,
        1
      ],
      "solid": "none",
      "facing": 0,
      "note": "석탄 앞 저장고 곁 공구 수레",
      "level": -1
    },
    {
      "kind": "coal_heap",
      "rect": [
        168,
        13,
        3,
        2
      ],
      "solid": "none",
      "facing": 0,
      "note": "석탄 안쪽 보관실 곁 석탄 더미",
      "level": -1
    },
    {
      "kind": "part_crate",
      "rect": [
        172,
        13,
        1,
        1
      ],
      "solid": "none",
      "facing": 0,
      "note": "석탄 안쪽 보관실 곁 부품 상자",
      "level": -1
    },
    {
      "kind": "barrel",
      "rect": [
        173,
        13,
        1,
        1
      ],
      "solid": "none",
      "facing": 0,
      "note": "석탄 안쪽 보관실 곁 통",
      "level": -1
    },
    {
      "kind": "tool_cart",
      "rect": [
        173,
        14,
        2,
        1
      ],
      "solid": "none",
      "facing": 0,
      "note": "석탄 안쪽 보관실 곁 공구 수레",
      "level": -1
    },
    {
      "kind": "coal_heap",
      "rect": [
        161,
        10,
        3,
        2
      ],
      "solid": "low",
      "facing": 0,
      "note": "앞 작업 칸 곁 석탄 더미",
      "level": 0
    },
    {
      "kind": "part_crate",
      "rect": [
        165,
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
      "kind": "barrel",
      "rect": [
        166,
        10,
        1,
        1
      ],
      "solid": "low",
      "facing": 0,
      "note": "앞 작업 칸 곁 통",
      "level": 0
    },
    {
      "kind": "coal_heap",
      "rect": [
        169,
        10,
        3,
        2
      ],
      "solid": "low",
      "facing": 0,
      "note": "안쪽 보관실 곁 석탄 더미",
      "level": 0
    },
    {
      "kind": "part_crate",
      "rect": [
        172,
        10,
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
        173,
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
      "kind": "coal_heap",
      "rect": [
        117,
        31,
        3,
        2
      ],
      "solid": "low",
      "facing": 0,
      "note": "앞 작업 칸 곁 석탄 더미",
      "level": 0
    },
    {
      "kind": "part_crate",
      "rect": [
        120,
        31,
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
        121,
        31,
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
        31,
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
        31,
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
        32,
        2,
        1
      ],
      "solid": "low",
      "facing": 0,
      "note": "안쪽 보관실 곁 서류함",
      "level": 0
    },
    {
      "kind": "coal_heap",
      "rect": [
        141,
        39,
        3,
        2
      ],
      "solid": "low",
      "facing": 0,
      "note": "작업 칸 곁 석탄 더미",
      "level": 0
    },
    {
      "kind": "pallet_stack",
      "rect": [
        144,
        39,
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
        146,
        39,
        1,
        1
      ],
      "solid": "low",
      "facing": 0,
      "note": "작업 칸 곁 통",
      "level": 0
    },
    {
      "kind": "coal_heap",
      "rect": [
        24,
        8,
        3,
        2
      ],
      "solid": "low",
      "facing": 0,
      "note": "하역 준비 자리의 석탄 더미",
      "level": 0
    },
    {
      "kind": "sack_pile",
      "rect": [
        28,
        8,
        2,
        2
      ],
      "solid": "low",
      "facing": 0,
      "note": "하역 준비 자리의 자루 더미",
      "level": 0
    },
    {
      "kind": "barrel",
      "rect": [
        30,
        8,
        1,
        1
      ],
      "solid": "low",
      "facing": 0,
      "note": "하역 준비 자리의 통",
      "level": 0
    },
    {
      "kind": "sack_pile",
      "rect": [
        152,
        31,
        2,
        2
      ],
      "solid": "low",
      "facing": 0,
      "note": "하역 준비 자리의 자루 더미",
      "level": 0
    },
    {
      "kind": "tool_cart",
      "rect": [
        154,
        31,
        2,
        1
      ],
      "solid": "low",
      "facing": 0,
      "note": "하역 준비 자리의 공구 수레",
      "level": 0
    },
    {
      "kind": "part_crate",
      "rect": [
        156,
        31,
        1,
        1
      ],
      "solid": "low",
      "facing": 0,
      "note": "하역 준비 자리의 부품 상자",
      "level": 0
    }
  ],
  "containers": [
    {
      "id": "north_box_1",
      "name": "석탄 선별 건물 석탄 앞 저장고 상자",
      "cell": [
        76,
        19
      ],
      "building": 17,
      "search": 6,
      "items": [
        "plank"
      ],
      "locked": false,
      "level": -1,
      "searched": false
    },
    {
      "id": "north_box_2",
      "name": "석탄 선별 건물 석탄 안쪽 보관실 상자",
      "cell": [
        81,
        19
      ],
      "building": 17,
      "search": 6,
      "items": [
        "plank"
      ],
      "locked": false,
      "level": -1,
      "searched": false
    },
    {
      "id": "north_box_3",
      "name": "석탄 선별 건물 석탄 앞 저장고 상자",
      "cell": [
        86,
        19
      ],
      "building": 17,
      "search": 6,
      "items": [
        "plank"
      ],
      "locked": false,
      "level": -1,
      "searched": false
    },
    {
      "id": "north_box_4",
      "name": "석탄 선별 건물 석탄 안쪽 보관실 상자",
      "cell": [
        91,
        19
      ],
      "building": 17,
      "search": 6,
      "items": [
        "plank"
      ],
      "locked": false,
      "level": -1,
      "searched": false
    },
    {
      "id": "north_box_5",
      "name": "석탄 선별 건물 석탄 앞 저장고 상자",
      "cell": [
        96,
        19
      ],
      "building": 17,
      "search": 6,
      "items": [
        "plank"
      ],
      "locked": false,
      "level": -1,
      "searched": false
    },
    {
      "id": "north_box_6",
      "name": "석탄 선별 건물 석탄 안쪽 보관실 상자",
      "cell": [
        102,
        19
      ],
      "building": 17,
      "search": 6,
      "items": [
        "plank"
      ],
      "locked": false,
      "level": -1,
      "searched": false
    },
    {
      "id": "north_box_7",
      "name": "석탄 선별 건물 선별실 상자",
      "cell": [
        76,
        19
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
      "id": "north_box_8",
      "name": "석탄 선별 건물 계량실 상자",
      "cell": [
        81,
        19
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
      "id": "north_box_9",
      "name": "석탄 선별 건물 사무 칸 상자",
      "cell": [
        86,
        19
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
      "id": "north_box_10",
      "name": "석탄 선별 건물 원료 칸 상자",
      "cell": [
        91,
        19
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
      "id": "north_box_11",
      "name": "석탄 선별 건물 공구 칸 상자",
      "cell": [
        96,
        19
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
      "id": "north_box_12",
      "name": "석탄 선별 건물 안쪽 보관실 상자",
      "cell": [
        102,
        19
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
      "id": "north_box_13",
      "name": "석탄 선별 건물 선별실 상자",
      "cell": [
        76,
        19
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
      "id": "north_box_14",
      "name": "석탄 선별 건물 계량실 상자",
      "cell": [
        81,
        19
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
      "id": "north_box_15",
      "name": "석탄 선별 건물 사무 칸 상자",
      "cell": [
        86,
        19
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
      "id": "north_box_16",
      "name": "석탄 선별 건물 원료 칸 상자",
      "cell": [
        91,
        19
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
      "id": "north_box_17",
      "name": "석탄 선별 건물 공구 칸 상자",
      "cell": [
        96,
        19
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
      "id": "north_box_18",
      "name": "석탄 선별 건물 안쪽 보관실 상자",
      "cell": [
        102,
        19
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
      "id": "north_box_19",
      "name": "석탄 선별 건물 선별실 상자",
      "cell": [
        76,
        19
      ],
      "building": 17,
      "search": 6,
      "items": [
        "plank"
      ],
      "locked": false,
      "level": 2,
      "searched": false
    },
    {
      "id": "north_box_20",
      "name": "석탄 선별 건물 계량실 상자",
      "cell": [
        81,
        19
      ],
      "building": 17,
      "search": 6,
      "items": [
        "plank"
      ],
      "locked": false,
      "level": 2,
      "searched": false
    },
    {
      "id": "north_box_21",
      "name": "석탄 선별 건물 사무 칸 상자",
      "cell": [
        86,
        19
      ],
      "building": 17,
      "search": 6,
      "items": [
        "plank"
      ],
      "locked": false,
      "level": 2,
      "searched": false
    },
    {
      "id": "north_box_22",
      "name": "석탄 선별 건물 원료 칸 상자",
      "cell": [
        91,
        19
      ],
      "building": 17,
      "search": 6,
      "items": [
        "plank"
      ],
      "locked": false,
      "level": 2,
      "searched": false
    },
    {
      "id": "north_box_23",
      "name": "석탄 선별 건물 공구 칸 상자",
      "cell": [
        96,
        19
      ],
      "building": 17,
      "search": 6,
      "items": [
        "plank"
      ],
      "locked": false,
      "level": 2,
      "searched": false
    },
    {
      "id": "north_box_24",
      "name": "석탄 선별 건물 안쪽 보관실 상자",
      "cell": [
        102,
        19
      ],
      "building": 17,
      "search": 6,
      "items": [
        "plank"
      ],
      "locked": false,
      "level": 2,
      "searched": false
    },
    {
      "id": "north_box_25",
      "name": "서쪽 석탄 창고 선별실 상자",
      "cell": [
        29,
        19
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
      "id": "north_box_26",
      "name": "서쪽 석탄 창고 계량실 상자",
      "cell": [
        36,
        19
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
      "id": "north_box_27",
      "name": "서쪽 석탄 창고 사무 칸 상자",
      "cell": [
        43,
        19
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
      "id": "north_box_28",
      "name": "서쪽 석탄 창고 원료 칸 상자",
      "cell": [
        50,
        19
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
      "id": "north_box_29",
      "name": "서쪽 석탄 창고 공구 칸 상자",
      "cell": [
        57,
        19
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
      "id": "north_box_30",
      "name": "서쪽 석탄 창고 안쪽 보관실 상자",
      "cell": [
        64,
        19
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
      "id": "north_box_31",
      "name": "동쪽 석탄 창고 앞 작업 칸 상자",
      "cell": [
        119,
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
      "id": "north_box_32",
      "name": "동쪽 석탄 창고 안쪽 보관실 상자",
      "cell": [
        128,
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
      "id": "north_box_33",
      "name": "동쪽 석탄 창고 앞 작업 칸 상자",
      "cell": [
        119,
        22
      ],
      "building": 19,
      "search": 6,
      "items": [
        "plank"
      ],
      "locked": false,
      "level": 1,
      "searched": false
    },
    {
      "id": "north_box_34",
      "name": "동쪽 석탄 창고 안쪽 보관실 상자",
      "cell": [
        128,
        22
      ],
      "building": 19,
      "search": 6,
      "items": [
        "plank"
      ],
      "locked": false,
      "level": 1,
      "searched": false
    },
    {
      "id": "north_box_35",
      "name": "석탄 사무소 작업 칸 상자",
      "cell": [
        14,
        14
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
      "id": "north_box_36",
      "name": "수선 헛간 앞 작업 칸 상자",
      "cell": [
        141,
        18
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
      "id": "north_box_37",
      "name": "수선 헛간 안쪽 보관실 상자",
      "cell": [
        148,
        18
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
      "id": "north_box_38",
      "name": "동북 석탄 저장고 석탄 앞 저장고 상자",
      "cell": [
        166,
        18
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
      "id": "north_box_39",
      "name": "동북 석탄 저장고 석탄 안쪽 보관실 상자",
      "cell": [
        174,
        18
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
      "id": "north_box_40",
      "name": "동북 석탄 저장고 앞 작업 칸 상자",
      "cell": [
        167,
        18
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
      "id": "north_box_41",
      "name": "동북 석탄 저장고 안쪽 보관실 상자",
      "cell": [
        174,
        18
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
      "id": "north_box_42",
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
      "id": "north_box_43",
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
      "id": "north_box_44",
      "name": "모래 창고 작업 칸 상자",
      "cell": [
        148,
        44
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
      "name": "옆문 열린 석탄 화차",
      "rect": [
        74,
        4,
        10,
        3
      ],
      "coal": 10,
      "work": [
        75,
        7
      ]
    },
    {
      "id": "north_wagon_1",
      "name": "옆문 열린 석탄 화차",
      "rect": [
        95,
        4,
        10,
        3
      ],
      "coal": 10,
      "work": [
        96,
        7
      ]
    }
  ],
  "entries": [
    [
      "서쪽 석탄길",
      [
        [
          0,
          3
        ],
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
        ]
      ],
      0.6
    ],
    [
      "북쪽 호퍼길",
      [
        [
          86,
          0
        ],
        [
          87,
          0
        ],
        [
          88,
          0
        ],
        [
          89,
          0
        ]
      ],
      0.6
    ],
    [
      "동쪽 저장길",
      [
        [
          179,
          3
        ],
        [
          179,
          4
        ],
        [
          179,
          5
        ],
        [
          179,
          6
        ]
      ],
      0.6
    ]
  ],
  "holes": [
    [
      "drain_02",
      [
        36,
        9
      ],
      "석탄 더미 곁 배수구"
    ]
  ],
  "barricades": [
    [
      67,
      22
    ],
    [
      70,
      22
    ],
    [
      105,
      22
    ],
    [
      108,
      22
    ],
    [
      116,
      26
    ],
    [
      116,
      28
    ]
  ],
  "deep": [
    [
      "K",
      "동북 석탄 저장고"
    ]
  ],
  "dead": [],
  "salvage": [],
  "work_site": {},
  "cross": [
    32,
    48
  ],
  "court": [
    162,
    5,
    5,
    4
  ]
}


## 무전 문장에 쓰는 들어오는 길의 이름, 길마다의 비중, 첫 물결이 오는 길.
const ENTRY_NAMES: Dictionary = {"west_road": "서쪽 길", "east_track": "동쪽 선로", "east_road": "동쪽 길", "manhole_01": "첫째 맨홀", "manhole_02": "둘째 맨홀", "drain_01": "첫째 배수구", "서쪽 석탄길": "서쪽 석탄길", "북쪽 호퍼길": "북쪽 호퍼길", "동쪽 저장길": "동쪽 저장길", "drain_02": "둘째 배수구"}
const ENTRY_WEIGHTS: Dictionary = {"west_road": 1.0, "east_track": 1.0, "east_road": 1.0, "manhole_01": 0.3, "manhole_02": 0.3, "drain_01": 1.0, "서쪽 석탄길": 1.0, "북쪽 호퍼길": 1.0, "동쪽 저장길": 1.0, "drain_02": 1.0}
const FIRST_ENTRY: String = "west_road"


static func build() -> Dictionary:
	var data: Dictionary = _build_plain()
	data["entry_names"] = ENTRY_NAMES.duplicate()
	data["entry_weights"] = ENTRY_WEIGHTS.duplicate()
	data["first_entry"] = FIRST_ENTRY
	return data
