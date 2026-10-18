# 이 지도가 다른 판단을 만드는 것: 객차 안으로 지르면 앞뒤가 막히고, 끝으로 돌면 서른 칸을 더 걷는다.
# 위쪽의 판단: 무겁지만 많은 철판과 레일을 얻는 대신, 화차 틈이 좁은 길목이라 짐 실은 썰매가 틈에서 막히고 서쪽 철판 마당이 늘 열려 있어 작업조가 드러난다.
extends RefCounted

const MapShift = preload("res://game/world/map_shift.gd")
const FieldGrid = preload("res://game/world/field_grid.gd")
const S = FieldGrid.Solid
const F = FieldGrid.Floor
const PLACE_ID: String = "freight_05"
const WIDTH: int = 170
const SOUTH_HEIGHT: int = 95
const HEIGHT: int = SOUTH_HEIGHT + 45

# 좌표는 한 칸 단위다. 각 층의 방·문·가구를 독립적으로 기록한다.
const PLAN: Dictionary = {
  "id": "freight_05",
  "size": [170,95],
  "judgment": "객차 안으로 지르면 앞뒤가 막히고, 끝으로 돌면 서른 칸을 더 걷는다.",
  "resource": "document",
  "zones": [
    ["A","승강장",[0,0,170,95]],
    ["B","옛 객차 줄",[10,10,111,8]],
    ["C","계량 작업 마당",[0,18,112,25]],
    ["D","문서 창고",[0,43,66,34]],
    ["E","구내 생활 구획",[66,43,64,18]],
    ["F","동쪽 부품 구획",[120,20,50,55]],
    ["G","동남 수선 구획",[120,75,50,20]],
    ["H","남쪽 문서 마당",[0,77,120,18]]
  ],
  "floors": [
    [0,20,15,49,23,7],
    [0,91,19,29,18,7],
    [0,68,60,52,17,7],
    [0,124,28,42,10,7],
    [0,0,38,170,6,1],
    [0,84,43,6,52,1],
    [0,16,18,4,61,1],
    [0,120,18,4,60,1],
    [0,22,10,84,5,4],
    [0,37,23,4,2,5]
  ],
  "buildings": [
    {"id":0,"name":"문서 창고","rect":[20,46,44,26],"warm":false,"window_broken":false},
    {"id":1,"name":"계량소","rect":[11,12,7,8],"warm":false,"window_broken":false},
    {"id":2,"name":"숙직소","rect":[90,47,22,12],"warm":false,"window_broken":false},
    {"id":3,"name":"매점","rect":[116,46,12,9],"warm":false,"window_broken":false},
    {"id":4,"name":"신호 취급소","rect":[112,12,8,7],"warm":false,"window_broken":false},
    {"id":5,"name":"부품 창고","rect":[124,62,20,12],"warm":false,"window_broken":false},
    {"id":6,"name":"사무소","rect":[70,20,20,14],"warm":false,"window_broken":false},
    {"id":7,"name":"수선 헛간","rect":[146,75,18,10],"warm":false,"window_broken":false},
    {"id":8,"name":"모래 창고","rect":[4,24,10,8],"warm":false,"window_broken":false},
    {"id":9,"name":"변전실","rect":[144,20,10,8],"warm":false,"window_broken":false},
    {"id":10,"name":"공구 창고","rect":[6,80,16,10],"warm":false,"window_broken":false},
    {"id":11,"name":"하역 창고","rect":[94,78,24,12],"warm":false,"window_broken":false},
    {"id":12,"name":"급수 펌프실","rect":[26,78,8,8],"warm":false,"window_broken":false},
    {"id":13,"name":"차장 휴게실","rect":[43,81,12,9],"warm":false,"window_broken":false},
    {"id":14,"name":"문서 별채","rect":[60,81,16,10],"warm":false,"window_broken":false},
    {"id":15,"name":"옛 객차 가","rect":[22,10,14,5],"warm":false,"window_broken":false},
    {"id":16,"name":"옛 객차 나","rect":[36,10,14,5],"warm":false,"window_broken":false},
    {"id":17,"name":"옛 객차 다","rect":[50,10,14,5],"warm":false,"window_broken":false},
    {"id":18,"name":"옛 객차 라","rect":[64,10,14,5],"warm":false,"window_broken":false},
    {"id":19,"name":"옛 객차 마","rect":[78,10,14,5],"warm":false,"window_broken":false},
    {"id":20,"name":"옛 객차 바","rect":[92,10,14,5],"warm":false,"window_broken":false}
  ],
  "shells": [
    [0,0,20,46,44,26],
    [0,1,20,46,44,26],
    [0,2,20,46,44,26],
    [0,-1,20,46,44,26],
    [1,0,11,12,7,8],
    [2,0,90,47,22,12],
    [2,1,90,47,22,12],
    [3,0,116,46,12,9],
    [4,0,112,12,8,7],
    [4,1,112,12,8,7],
    [5,0,124,62,20,12],
    [6,0,70,20,20,14],
    [6,1,70,20,20,14],
    [7,0,146,75,18,10],
    [8,0,4,24,10,8],
    [9,0,144,20,10,8],
    [10,0,6,80,16,10],
    [11,0,94,78,24,12],
    [12,0,26,78,8,8],
    [13,0,43,81,12,9],
    [14,0,60,81,16,10],
    [15,0,22,10,14,5],
    [16,0,36,10,14,5],
    [17,0,50,10,14,5],
    [18,0,64,10,14,5],
    [19,0,78,10,14,5],
    [20,0,92,10,14,5]
  ],
  "walls": [
    [0,21,57,42,1],
    [0,21,60,42,1],
    [0,27,47,1,10],
    [0,34,47,1,10],
    [0,41,47,1,10],
    [0,48,47,1,10],
    [0,55,47,1,10],
    [0,27,61,1,10],
    [0,34,61,1,10],
    [0,41,61,1,10],
    [0,48,61,1,10],
    [0,55,61,1,10],
    [1,21,57,42,1],
    [1,21,60,42,1],
    [1,27,47,1,10],
    [1,34,47,1,10],
    [1,41,47,1,10],
    [1,48,47,1,10],
    [1,55,47,1,10],
    [1,27,61,1,10],
    [1,34,61,1,10],
    [1,41,61,1,10],
    [1,48,61,1,10],
    [1,55,61,1,10],
    [2,21,57,42,1],
    [2,21,60,42,1],
    [2,27,47,1,10],
    [2,34,47,1,10],
    [2,41,47,1,10],
    [2,48,47,1,10],
    [2,55,47,1,10],
    [2,27,61,1,10],
    [2,34,61,1,10],
    [2,41,61,1,10],
    [2,48,61,1,10],
    [2,55,61,1,10],
    [-1,21,57,42,1],
    [-1,21,60,42,1],
    [-1,27,47,1,10],
    [-1,34,47,1,10],
    [-1,41,47,1,10],
    [-1,48,47,1,10],
    [-1,55,47,1,10],
    [-1,27,61,1,10],
    [-1,34,61,1,10],
    [-1,41,61,1,10],
    [-1,48,61,1,10],
    [-1,55,61,1,10],
    [0,101,48,1,10],
    [1,101,48,1,10],
    [0,117,50,10,1],
    [0,134,63,1,10],
    [0,80,21,1,12],
    [1,80,21,1,12],
    [0,155,76,1,8],
    [0,14,81,1,8],
    [0,106,79,1,10],
    [0,49,82,1,7],
    [0,68,82,1,8],
    [0,29,11,1,3],
    [0,57,11,1,3],
    [0,85,11,1,3]
  ],
  "openings": [
    [0,26,10,1,1],
    [0,31,14,1,1],
    [0,43,10,1,1],
    [0,43,14,1,1],
    [0,54,10,1,1],
    [0,59,14,1,1],
    [0,71,10,1,1],
    [0,71,14,1,1],
    [0,82,10,1,1],
    [0,87,14,1,1],
    [0,99,10,1,1],
    [0,99,14,1,1]
  ],
  "doors": [
    [0,23,57,0,"closed",0,1],
    [0,30,57,0,"closed",0,1],
    [0,37,57,0,"closed",0,1],
    [0,44,57,0,"closed",0,1],
    [0,51,57,0,"closed",0,1],
    [0,59,57,0,"closed",0,1],
    [0,23,60,0,"closed",0,-1],
    [0,30,60,0,"closed",0,-1],
    [0,37,60,0,"closed",0,-1],
    [0,44,60,0,"closed",0,-1],
    [0,51,60,0,"closed",0,-1],
    [0,59,60,0,"closed",0,-1],
    [1,23,57,0,"closed",0,1],
    [1,30,57,0,"closed",0,1],
    [1,37,57,0,"closed",0,1],
    [1,44,57,0,"closed",0,1],
    [1,51,57,0,"closed",0,1],
    [1,59,57,0,"closed",0,1],
    [1,23,60,0,"closed",0,-1],
    [1,30,60,0,"closed",0,-1],
    [1,37,60,0,"closed",0,-1],
    [1,44,60,0,"closed",0,-1],
    [1,51,60,0,"closed",0,-1],
    [1,59,60,0,"closed",0,-1],
    [2,23,57,0,"closed",0,1],
    [2,30,57,0,"closed",0,1],
    [2,37,57,0,"closed",0,1],
    [2,44,57,0,"closed",0,1],
    [2,51,57,0,"closed",0,1],
    [2,59,57,0,"closed",0,1],
    [2,23,60,0,"closed",0,-1],
    [2,30,60,0,"closed",0,-1],
    [2,37,60,0,"closed",0,-1],
    [2,44,60,0,"closed",0,-1],
    [2,51,60,0,"closed",0,-1],
    [2,59,60,0,"closed",0,-1],
    [-1,23,57,0,"closed",0,1],
    [-1,30,57,0,"closed",0,1],
    [-1,37,57,0,"closed",0,1],
    [-1,44,57,0,"closed",0,1],
    [-1,51,57,0,"closed",0,1],
    [-1,59,57,0,"closed",0,1],
    [-1,23,60,0,"closed",0,-1],
    [-1,30,60,0,"closed",0,-1],
    [-1,37,60,0,"closed",0,-1],
    [-1,44,60,0,"closed",0,-1],
    [-1,51,60,0,"closed",0,-1],
    [-1,59,60,0,"closed",0,-1],
    [0,34,46,0,"closed",0,-1],
    [0,61,71,0,"closed",0,1],
    [0,20,58,0,"closed",-1,0],
    [0,11,16,1,"closed",-1,0],
    [0,101,53,2,"closed",1,0],
    [1,101,53,2,"closed",1,0],
    [0,97,47,2,"closed",0,-1],
    [0,109,58,2,"closed",0,1],
    [0,125,50,3,"closed",0,1],
    [0,120,46,3,"closed",0,-1],
    [0,125,54,3,"closed",0,1],
    [0,119,15,4,"closed",1,0],
    [0,134,68,5,"closed",1,0],
    [0,130,62,5,"closed",0,-1],
    [0,141,73,5,"closed",0,1],
    [0,80,27,6,"closed",1,0],
    [1,80,27,6,"closed",1,0],
    [0,76,20,6,"closed",0,-1],
    [0,87,33,6,"closed",0,1],
    [0,155,80,7,"closed",1,0],
    [0,152,75,7,"closed",0,-1],
    [0,163,80,7,"closed",1,0],
    [0,7,24,8,"closed",0,-1],
    [0,11,31,8,"closed",0,1],
    [0,147,20,9,"closed",0,-1],
    [0,151,27,9,"closed",0,1],
    [0,14,85,10,"closed",1,0],
    [0,11,80,10,"closed",0,-1],
    [0,19,89,10,"closed",0,1],
    [0,106,84,11,"closed",1,0],
    [0,102,78,11,"closed",0,-1],
    [0,115,89,11,"closed",0,1],
    [0,28,78,12,"closed",0,-1],
    [0,31,85,12,"closed",0,1],
    [0,49,85,13,"closed",1,0],
    [0,47,81,13,"closed",0,-1],
    [0,52,89,13,"closed",0,1],
    [0,68,86,14,"closed",1,0],
    [0,65,81,14,"closed",0,-1],
    [0,73,90,14,"closed",0,1]
  ],
  "windows": [
    [0,23,46,0],
    [0,30,46,0],
    [0,37,46,0],
    [0,44,46,0],
    [0,51,46,0],
    [0,58,46,0],
    [0,63,49,0],
    [0,63,55,0],
    [0,63,61,0],
    [0,63,67,0],
    [1,23,46,0],
    [1,30,46,0],
    [1,37,46,0],
    [1,44,46,0],
    [1,51,46,0],
    [1,58,46,0],
    [1,63,49,0],
    [1,63,55,0],
    [1,63,61,0],
    [1,63,67,0],
    [2,23,46,0],
    [2,30,46,0],
    [2,37,46,0],
    [2,44,46,0],
    [2,51,46,0],
    [2,58,46,0],
    [2,63,49,0],
    [2,63,55,0],
    [2,63,61,0],
    [2,63,67,0],
    [0,14,12,1],
    [0,17,15,1],
    [0,93,47,2],
    [0,100,47,2],
    [0,107,47,2],
    [0,111,50,2],
    [0,111,56,2],
    [1,93,47,2],
    [1,100,47,2],
    [1,107,47,2],
    [1,111,50,2],
    [1,111,56,2],
    [0,119,46,3],
    [0,127,49,3],
    [0,115,12,4],
    [0,119,15,4],
    [1,115,12,4],
    [1,119,15,4],
    [0,127,62,5],
    [0,134,62,5],
    [0,141,62,5],
    [0,143,65,5],
    [0,143,71,5],
    [0,73,20,6],
    [0,80,20,6],
    [0,87,20,6],
    [0,89,23,6],
    [0,89,29,6],
    [1,73,20,6],
    [1,80,20,6],
    [1,87,20,6],
    [1,89,23,6],
    [1,89,29,6],
    [0,149,75,7],
    [0,156,75,7],
    [0,163,78,7],
    [0,7,24,8],
    [0,13,27,8],
    [0,147,20,9],
    [0,153,23,9],
    [0,9,80,10],
    [0,16,80,10],
    [0,21,83,10],
    [0,97,78,11],
    [0,104,78,11],
    [0,111,78,11],
    [0,117,81,11],
    [0,117,87,11],
    [0,29,78,12],
    [0,33,81,12],
    [0,46,81,13],
    [0,54,84,13],
    [0,63,81,14],
    [0,70,81,14],
    [0,75,84,14],
    [0,24,10,15],
    [0,33,14,15],
    [0,38,10,16],
    [0,47,14,16],
    [0,52,10,17],
    [0,61,14,17],
    [0,66,10,18],
    [0,75,14,18],
    [0,80,10,19],
    [0,89,14,19],
    [0,94,10,20],
    [0,103,14,20]
  ],
  "rooms": [
    {"building":0,"level":0,"rect":[21,47,6,10],"name":"사무실"},
    {"building":0,"level":0,"rect":[28,47,6,10],"name":"선별실"},
    {"building":0,"level":0,"rect":[35,47,6,10],"name":"선반 칸"},
    {"building":0,"level":0,"rect":[42,47,6,10],"name":"계량실"},
    {"building":0,"level":0,"rect":[49,47,6,10],"name":"안쪽 창고"},
    {"building":0,"level":0,"rect":[56,47,7,10],"name":"기록실"},
    {"building":0,"level":0,"rect":[21,61,6,10],"name":"사무실"},
    {"building":0,"level":0,"rect":[28,61,6,10],"name":"선별실"},
    {"building":0,"level":0,"rect":[35,61,6,10],"name":"선반 칸"},
    {"building":0,"level":0,"rect":[42,61,6,10],"name":"계량실"},
    {"building":0,"level":0,"rect":[49,61,6,10],"name":"안쪽 창고"},
    {"building":0,"level":0,"rect":[56,61,7,10],"name":"기록실"},
    {"building":0,"level":1,"rect":[21,47,6,10],"name":"사무실"},
    {"building":0,"level":1,"rect":[28,47,6,10],"name":"선별실"},
    {"building":0,"level":1,"rect":[35,47,6,10],"name":"선반 칸"},
    {"building":0,"level":1,"rect":[42,47,6,10],"name":"계량실"},
    {"building":0,"level":1,"rect":[49,47,6,10],"name":"안쪽 창고"},
    {"building":0,"level":1,"rect":[56,47,7,10],"name":"기록실"},
    {"building":0,"level":1,"rect":[21,61,6,10],"name":"사무실"},
    {"building":0,"level":1,"rect":[28,61,6,10],"name":"선별실"},
    {"building":0,"level":1,"rect":[35,61,6,10],"name":"선반 칸"},
    {"building":0,"level":1,"rect":[42,61,6,10],"name":"계량실"},
    {"building":0,"level":1,"rect":[49,61,6,10],"name":"안쪽 창고"},
    {"building":0,"level":1,"rect":[56,61,7,10],"name":"기록실"},
    {"building":0,"level":2,"rect":[21,47,6,10],"name":"사무실"},
    {"building":0,"level":2,"rect":[28,47,6,10],"name":"선별실"},
    {"building":0,"level":2,"rect":[35,47,6,10],"name":"선반 칸"},
    {"building":0,"level":2,"rect":[42,47,6,10],"name":"계량실"},
    {"building":0,"level":2,"rect":[49,47,6,10],"name":"안쪽 창고"},
    {"building":0,"level":2,"rect":[56,47,7,10],"name":"기록실"},
    {"building":0,"level":2,"rect":[21,61,6,10],"name":"사무실"},
    {"building":0,"level":2,"rect":[28,61,6,10],"name":"선별실"},
    {"building":0,"level":2,"rect":[35,61,6,10],"name":"선반 칸"},
    {"building":0,"level":2,"rect":[42,61,6,10],"name":"계량실"},
    {"building":0,"level":2,"rect":[49,61,6,10],"name":"안쪽 창고"},
    {"building":0,"level":2,"rect":[56,61,7,10],"name":"기록실"},
    {"building":0,"level":-1,"rect":[21,47,6,10],"name":"저장고"},
    {"building":0,"level":-1,"rect":[28,47,6,10],"name":"냉기 칸"},
    {"building":0,"level":-1,"rect":[35,47,6,10],"name":"안쪽 보관실"},
    {"building":0,"level":-1,"rect":[42,47,6,10],"name":"저장고"},
    {"building":0,"level":-1,"rect":[49,47,6,10],"name":"냉기 칸"},
    {"building":0,"level":-1,"rect":[56,47,7,10],"name":"안쪽 보관실"},
    {"building":0,"level":-1,"rect":[21,61,6,10],"name":"저장고"},
    {"building":0,"level":-1,"rect":[28,61,6,10],"name":"냉기 칸"},
    {"building":0,"level":-1,"rect":[35,61,6,10],"name":"안쪽 보관실"},
    {"building":0,"level":-1,"rect":[42,61,6,10],"name":"저장고"},
    {"building":0,"level":-1,"rect":[49,61,6,10],"name":"냉기 칸"},
    {"building":0,"level":-1,"rect":[56,61,7,10],"name":"안쪽 보관실"},
    {"building":1,"level":0,"rect":[12,13,5,6],"name":"작업실"},
    {"building":2,"level":0,"rect":[91,48,10,10],"name":"앞방"},
    {"building":2,"level":0,"rect":[102,48,9,10],"name":"안쪽 방"},
    {"building":2,"level":1,"rect":[91,48,10,10],"name":"앞방"},
    {"building":2,"level":1,"rect":[102,48,9,10],"name":"안쪽 방"},
    {"building":3,"level":0,"rect":[117,47,10,3],"name":"매장"},
    {"building":3,"level":0,"rect":[117,51,10,3],"name":"뒤 창고"},
    {"building":4,"level":0,"rect":[113,13,6,5],"name":"작업실"},
    {"building":4,"level":1,"rect":[113,13,6,5],"name":"작업실"},
    {"building":5,"level":0,"rect":[125,63,9,10],"name":"앞방"},
    {"building":5,"level":0,"rect":[135,63,8,10],"name":"안쪽 방"},
    {"building":6,"level":0,"rect":[71,21,9,12],"name":"앞방"},
    {"building":6,"level":0,"rect":[81,21,8,12],"name":"안쪽 방"},
    {"building":6,"level":1,"rect":[71,21,9,12],"name":"앞방"},
    {"building":6,"level":1,"rect":[81,21,8,12],"name":"안쪽 방"},
    {"building":7,"level":0,"rect":[147,76,8,8],"name":"앞방"},
    {"building":7,"level":0,"rect":[156,76,7,8],"name":"안쪽 방"},
    {"building":8,"level":0,"rect":[5,25,8,6],"name":"작업실"},
    {"building":9,"level":0,"rect":[145,21,8,6],"name":"작업실"},
    {"building":10,"level":0,"rect":[7,81,7,8],"name":"앞방"},
    {"building":10,"level":0,"rect":[15,81,6,8],"name":"안쪽 방"},
    {"building":11,"level":0,"rect":[95,79,11,10],"name":"앞방"},
    {"building":11,"level":0,"rect":[107,79,10,10],"name":"안쪽 방"},
    {"building":12,"level":0,"rect":[27,79,6,6],"name":"작업실"},
    {"building":13,"level":0,"rect":[44,82,5,7],"name":"앞방"},
    {"building":13,"level":0,"rect":[50,82,4,7],"name":"안쪽 방"},
    {"building":14,"level":0,"rect":[61,82,7,8],"name":"앞방"},
    {"building":14,"level":0,"rect":[69,82,6,8],"name":"안쪽 방"},
    {"building":15,"level":0,"rect":[23,11,6,3],"name":"북쪽 수납칸"},
    {"building":15,"level":0,"rect":[30,11,5,3],"name":"남쪽 수납칸"},
    {"building":16,"level":0,"rect":[37,11,12,3],"name":"객차 통로"},
    {"building":17,"level":0,"rect":[51,11,6,3],"name":"북쪽 수납칸"},
    {"building":17,"level":0,"rect":[58,11,5,3],"name":"남쪽 수납칸"},
    {"building":18,"level":0,"rect":[65,11,12,3],"name":"객차 통로"},
    {"building":19,"level":0,"rect":[79,11,6,3],"name":"북쪽 수납칸"},
    {"building":19,"level":0,"rect":[86,11,5,3],"name":"남쪽 수납칸"},
    {"building":20,"level":0,"rect":[93,11,12,3],"name":"객차 통로"}
  ],
  "stairs": [
    {"cell":[22,58],"low":0,"high":1,"ladder":false},
    {"cell":[22,58],"low":1,"high":2,"ladder":false},
    {"cell":[22,58],"low":-1,"high":0,"ladder":false},
    {"cell":[61,58],"low":0,"high":1,"ladder":false},
    {"cell":[61,58],"low":1,"high":2,"ladder":false},
    {"cell":[61,58],"low":-1,"high":0,"ladder":false},
    {"cell":[92,49],"low":0,"high":1,"ladder":false},
    {"cell":[114,14],"low":0,"high":1,"ladder":false},
    {"cell":[72,22],"low":0,"high":1,"ladder":false}
  ],
  "props": [
    {"kind":"old_coach","rect":[22,10,14,5],"solid":"none","facing":0,"note":"옛 객차","level":0},
    {"kind":"old_coach","rect":[36,10,14,5],"solid":"none","facing":0,"note":"옛 객차","level":0},
    {"kind":"old_coach","rect":[50,10,14,5],"solid":"none","facing":0,"note":"옛 객차","level":0},
    {"kind":"old_coach","rect":[64,10,14,5],"solid":"none","facing":0,"note":"옛 객차","level":0},
    {"kind":"old_coach","rect":[78,10,14,5],"solid":"none","facing":0,"note":"옛 객차","level":0},
    {"kind":"old_coach","rect":[92,10,14,5],"solid":"none","facing":0,"note":"옛 객차","level":0},
    {"kind":"car","rect":[132,44,4,2],"solid":"low","facing":0,"note":"버려진 차","level":0},
    {"kind":"car","rect":[77,72,4,2],"solid":"low","facing":0,"note":"버려진 차","level":0},
    {"kind":"weigh_platform","rect":[18,21,3,2],"solid":"low","facing":0,"note":"계량대","level":0},
    {"kind":"sleeper_pile","rect":[28,8,3,2],"solid":"low","facing":0,"note":"침목 더미","level":0},
    {"kind":"bench","rect":[59,8,3,1],"solid":"low","facing":0,"note":"긴 의자","level":0},
    {"kind":"crate_stack","rect":[98,24,2,2],"solid":"low","facing":0,"note":"나무 상자 더미","level":0},
    {"kind":"sack_pile","rect":[23,25,2,2],"solid":"low","facing":0,"note":"자루 더미","level":0},
    {"kind":"file_cabinet","rect":[21,47,2,1],"solid":"low","facing":0,"note":"문서 창고 사무실 기술 서류함","level":0},
    {"kind":"conductor_log_chest","rect":[24,56,2,1],"solid":"low","facing":0,"note":"문서 창고 사무실 차장 일지 궤","level":0},
    {"kind":"part_crate","rect":[26,47,1,1],"solid":"low","facing":0,"note":"사무실 부품 상자","level":0},
    {"kind":"file_cabinet","rect":[28,47,2,1],"solid":"low","facing":0,"note":"문서 창고 선별실 기술 서류함","level":0},
    {"kind":"conductor_log_chest","rect":[31,56,2,1],"solid":"low","facing":0,"note":"문서 창고 선별실 차장 일지 궤","level":0},
    {"kind":"part_crate","rect":[33,47,1,1],"solid":"low","facing":0,"note":"선별실 부품 상자","level":0},
    {"kind":"file_cabinet","rect":[35,47,2,1],"solid":"low","facing":0,"note":"문서 창고 선반 칸 기술 서류함","level":0},
    {"kind":"conductor_log_chest","rect":[38,56,2,1],"solid":"low","facing":0,"note":"문서 창고 선반 칸 차장 일지 궤","level":0},
    {"kind":"part_crate","rect":[40,47,1,1],"solid":"low","facing":0,"note":"선반 칸 부품 상자","level":0},
    {"kind":"file_cabinet","rect":[42,47,2,1],"solid":"low","facing":0,"note":"문서 창고 계량실 기술 서류함","level":0},
    {"kind":"conductor_log_chest","rect":[45,56,2,1],"solid":"low","facing":0,"note":"문서 창고 계량실 차장 일지 궤","level":0},
    {"kind":"part_crate","rect":[47,47,1,1],"solid":"low","facing":0,"note":"계량실 부품 상자","level":0},
    {"kind":"file_cabinet","rect":[49,47,2,1],"solid":"low","facing":0,"note":"문서 창고 안쪽 창고 기술 서류함","level":0},
    {"kind":"conductor_log_chest","rect":[52,56,2,1],"solid":"low","facing":0,"note":"문서 창고 안쪽 창고 차장 일지 궤","level":0},
    {"kind":"part_crate","rect":[54,47,1,1],"solid":"low","facing":0,"note":"안쪽 창고 부품 상자","level":0},
    {"kind":"file_cabinet","rect":[56,47,2,1],"solid":"low","facing":0,"note":"문서 창고 기록실 기술 서류함","level":0},
    {"kind":"conductor_log_chest","rect":[60,56,2,1],"solid":"low","facing":0,"note":"문서 창고 기록실 차장 일지 궤","level":0},
    {"kind":"shelf","rect":[56,56,3,1],"solid":"low","facing":0,"note":"문서 창고 기록실 선반","level":0},
    {"kind":"file_cabinet","rect":[21,61,2,1],"solid":"low","facing":0,"note":"문서 창고 사무실 기술 서류함","level":0},
    {"kind":"conductor_log_chest","rect":[24,70,2,1],"solid":"low","facing":0,"note":"문서 창고 사무실 차장 일지 궤","level":0},
    {"kind":"shelf","rect":[21,70,3,1],"solid":"low","facing":0,"note":"문서 창고 사무실 선반","level":0},
    {"kind":"file_cabinet","rect":[28,61,2,1],"solid":"low","facing":0,"note":"문서 창고 선별실 기술 서류함","level":0},
    {"kind":"conductor_log_chest","rect":[31,70,2,1],"solid":"low","facing":0,"note":"문서 창고 선별실 차장 일지 궤","level":0},
    {"kind":"shelf","rect":[28,70,3,1],"solid":"low","facing":0,"note":"문서 창고 선별실 선반","level":0},
    {"kind":"file_cabinet","rect":[35,61,2,1],"solid":"low","facing":0,"note":"문서 창고 선반 칸 기술 서류함","level":0},
    {"kind":"conductor_log_chest","rect":[38,70,2,1],"solid":"low","facing":0,"note":"문서 창고 선반 칸 차장 일지 궤","level":0},
    {"kind":"shelf","rect":[35,70,3,1],"solid":"low","facing":0,"note":"문서 창고 선반 칸 선반","level":0},
    {"kind":"file_cabinet","rect":[42,61,2,1],"solid":"low","facing":0,"note":"문서 창고 계량실 기술 서류함","level":0},
    {"kind":"conductor_log_chest","rect":[45,70,2,1],"solid":"low","facing":0,"note":"문서 창고 계량실 차장 일지 궤","level":0},
    {"kind":"shelf","rect":[42,70,3,1],"solid":"low","facing":0,"note":"문서 창고 계량실 선반","level":0},
    {"kind":"file_cabinet","rect":[49,61,2,1],"solid":"low","facing":0,"note":"문서 창고 안쪽 창고 기술 서류함","level":0},
    {"kind":"conductor_log_chest","rect":[52,70,2,1],"solid":"low","facing":0,"note":"문서 창고 안쪽 창고 차장 일지 궤","level":0},
    {"kind":"shelf","rect":[49,70,3,1],"solid":"low","facing":0,"note":"문서 창고 안쪽 창고 선반","level":0},
    {"kind":"file_cabinet","rect":[56,61,2,1],"solid":"low","facing":0,"note":"문서 창고 기록실 기술 서류함","level":0},
    {"kind":"conductor_log_chest","rect":[56,70,2,1],"solid":"low","facing":0,"note":"문서 창고 기록실 차장 일지 궤","level":0},
    {"kind":"part_crate","rect":[62,61,1,1],"solid":"low","facing":0,"note":"기록실 부품 상자","level":0},
    {"kind":"file_cabinet","rect":[21,47,2,1],"solid":"none","facing":0,"note":"문서 창고 사무실 기술 서류함","level":1},
    {"kind":"conductor_log_chest","rect":[24,56,2,1],"solid":"none","facing":0,"note":"문서 창고 사무실 차장 일지 궤","level":1},
    {"kind":"part_crate","rect":[26,55,1,1],"solid":"none","facing":0,"note":"사무실 부품 상자","level":1},
    {"kind":"file_cabinet","rect":[28,47,2,1],"solid":"none","facing":0,"note":"문서 창고 선별실 기술 서류함","level":1},
    {"kind":"conductor_log_chest","rect":[31,56,2,1],"solid":"none","facing":0,"note":"문서 창고 선별실 차장 일지 궤","level":1},
    {"kind":"part_crate","rect":[33,55,1,1],"solid":"none","facing":0,"note":"선별실 부품 상자","level":1},
    {"kind":"file_cabinet","rect":[35,47,2,1],"solid":"none","facing":0,"note":"문서 창고 선반 칸 기술 서류함","level":1},
    {"kind":"conductor_log_chest","rect":[38,56,2,1],"solid":"none","facing":0,"note":"문서 창고 선반 칸 차장 일지 궤","level":1},
    {"kind":"part_crate","rect":[40,55,1,1],"solid":"none","facing":0,"note":"선반 칸 부품 상자","level":1},
    {"kind":"file_cabinet","rect":[42,47,2,1],"solid":"none","facing":0,"note":"문서 창고 계량실 기술 서류함","level":1},
    {"kind":"conductor_log_chest","rect":[45,56,2,1],"solid":"none","facing":0,"note":"문서 창고 계량실 차장 일지 궤","level":1},
    {"kind":"part_crate","rect":[47,55,1,1],"solid":"none","facing":0,"note":"계량실 부품 상자","level":1},
    {"kind":"file_cabinet","rect":[49,47,2,1],"solid":"none","facing":0,"note":"문서 창고 안쪽 창고 기술 서류함","level":1},
    {"kind":"conductor_log_chest","rect":[52,56,2,1],"solid":"none","facing":0,"note":"문서 창고 안쪽 창고 차장 일지 궤","level":1},
    {"kind":"part_crate","rect":[54,55,1,1],"solid":"none","facing":0,"note":"안쪽 창고 부품 상자","level":1},
    {"kind":"file_cabinet","rect":[56,47,2,1],"solid":"none","facing":0,"note":"문서 창고 기록실 기술 서류함","level":1},
    {"kind":"conductor_log_chest","rect":[60,56,2,1],"solid":"none","facing":0,"note":"문서 창고 기록실 차장 일지 궤","level":1},
    {"kind":"shelf","rect":[56,56,3,1],"solid":"none","facing":0,"note":"문서 창고 기록실 선반","level":1},
    {"kind":"file_cabinet","rect":[21,61,2,1],"solid":"none","facing":0,"note":"문서 창고 사무실 기술 서류함","level":1},
    {"kind":"conductor_log_chest","rect":[24,70,2,1],"solid":"none","facing":0,"note":"문서 창고 사무실 차장 일지 궤","level":1},
    {"kind":"shelf","rect":[21,70,3,1],"solid":"none","facing":0,"note":"문서 창고 사무실 선반","level":1},
    {"kind":"file_cabinet","rect":[28,61,2,1],"solid":"none","facing":0,"note":"문서 창고 선별실 기술 서류함","level":1},
    {"kind":"conductor_log_chest","rect":[31,70,2,1],"solid":"none","facing":0,"note":"문서 창고 선별실 차장 일지 궤","level":1},
    {"kind":"shelf","rect":[28,70,3,1],"solid":"none","facing":0,"note":"문서 창고 선별실 선반","level":1},
    {"kind":"file_cabinet","rect":[35,61,2,1],"solid":"none","facing":0,"note":"문서 창고 선반 칸 기술 서류함","level":1},
    {"kind":"conductor_log_chest","rect":[38,70,2,1],"solid":"none","facing":0,"note":"문서 창고 선반 칸 차장 일지 궤","level":1},
    {"kind":"shelf","rect":[35,70,3,1],"solid":"none","facing":0,"note":"문서 창고 선반 칸 선반","level":1},
    {"kind":"file_cabinet","rect":[42,61,2,1],"solid":"none","facing":0,"note":"문서 창고 계량실 기술 서류함","level":1},
    {"kind":"conductor_log_chest","rect":[45,70,2,1],"solid":"none","facing":0,"note":"문서 창고 계량실 차장 일지 궤","level":1},
    {"kind":"shelf","rect":[42,70,3,1],"solid":"none","facing":0,"note":"문서 창고 계량실 선반","level":1},
    {"kind":"file_cabinet","rect":[49,61,2,1],"solid":"none","facing":0,"note":"문서 창고 안쪽 창고 기술 서류함","level":1},
    {"kind":"conductor_log_chest","rect":[52,70,2,1],"solid":"none","facing":0,"note":"문서 창고 안쪽 창고 차장 일지 궤","level":1},
    {"kind":"shelf","rect":[49,70,3,1],"solid":"none","facing":0,"note":"문서 창고 안쪽 창고 선반","level":1},
    {"kind":"file_cabinet","rect":[56,61,2,1],"solid":"none","facing":0,"note":"문서 창고 기록실 기술 서류함","level":1},
    {"kind":"conductor_log_chest","rect":[60,70,2,1],"solid":"none","facing":0,"note":"문서 창고 기록실 차장 일지 궤","level":1},
    {"kind":"shelf","rect":[56,70,3,1],"solid":"none","facing":0,"note":"문서 창고 기록실 선반","level":1},
    {"kind":"file_cabinet","rect":[21,47,2,1],"solid":"none","facing":0,"note":"문서 창고 사무실 기술 서류함","level":2},
    {"kind":"conductor_log_chest","rect":[24,56,2,1],"solid":"none","facing":0,"note":"문서 창고 사무실 차장 일지 궤","level":2},
    {"kind":"part_crate","rect":[26,55,1,1],"solid":"none","facing":0,"note":"사무실 부품 상자","level":2},
    {"kind":"file_cabinet","rect":[28,47,2,1],"solid":"none","facing":0,"note":"문서 창고 선별실 기술 서류함","level":2},
    {"kind":"conductor_log_chest","rect":[31,56,2,1],"solid":"none","facing":0,"note":"문서 창고 선별실 차장 일지 궤","level":2},
    {"kind":"part_crate","rect":[33,55,1,1],"solid":"none","facing":0,"note":"선별실 부품 상자","level":2},
    {"kind":"file_cabinet","rect":[35,47,2,1],"solid":"none","facing":0,"note":"문서 창고 선반 칸 기술 서류함","level":2},
    {"kind":"conductor_log_chest","rect":[38,56,2,1],"solid":"none","facing":0,"note":"문서 창고 선반 칸 차장 일지 궤","level":2},
    {"kind":"part_crate","rect":[40,55,1,1],"solid":"none","facing":0,"note":"선반 칸 부품 상자","level":2},
    {"kind":"file_cabinet","rect":[42,47,2,1],"solid":"none","facing":0,"note":"문서 창고 계량실 기술 서류함","level":2},
    {"kind":"conductor_log_chest","rect":[45,56,2,1],"solid":"none","facing":0,"note":"문서 창고 계량실 차장 일지 궤","level":2},
    {"kind":"part_crate","rect":[47,55,1,1],"solid":"none","facing":0,"note":"계량실 부품 상자","level":2},
    {"kind":"file_cabinet","rect":[49,47,2,1],"solid":"none","facing":0,"note":"문서 창고 안쪽 창고 기술 서류함","level":2},
    {"kind":"conductor_log_chest","rect":[52,56,2,1],"solid":"none","facing":0,"note":"문서 창고 안쪽 창고 차장 일지 궤","level":2},
    {"kind":"part_crate","rect":[54,55,1,1],"solid":"none","facing":0,"note":"안쪽 창고 부품 상자","level":2},
    {"kind":"file_cabinet","rect":[56,47,2,1],"solid":"none","facing":0,"note":"문서 창고 기록실 기술 서류함","level":2},
    {"kind":"conductor_log_chest","rect":[60,56,2,1],"solid":"none","facing":0,"note":"문서 창고 기록실 차장 일지 궤","level":2},
    {"kind":"shelf","rect":[56,56,3,1],"solid":"none","facing":0,"note":"문서 창고 기록실 선반","level":2},
    {"kind":"file_cabinet","rect":[21,61,2,1],"solid":"none","facing":0,"note":"문서 창고 사무실 기술 서류함","level":2},
    {"kind":"conductor_log_chest","rect":[24,70,2,1],"solid":"none","facing":0,"note":"문서 창고 사무실 차장 일지 궤","level":2},
    {"kind":"shelf","rect":[21,70,3,1],"solid":"none","facing":0,"note":"문서 창고 사무실 선반","level":2},
    {"kind":"file_cabinet","rect":[28,61,2,1],"solid":"none","facing":0,"note":"문서 창고 선별실 기술 서류함","level":2},
    {"kind":"conductor_log_chest","rect":[31,70,2,1],"solid":"none","facing":0,"note":"문서 창고 선별실 차장 일지 궤","level":2},
    {"kind":"shelf","rect":[28,70,3,1],"solid":"none","facing":0,"note":"문서 창고 선별실 선반","level":2},
    {"kind":"file_cabinet","rect":[35,61,2,1],"solid":"none","facing":0,"note":"문서 창고 선반 칸 기술 서류함","level":2},
    {"kind":"conductor_log_chest","rect":[38,70,2,1],"solid":"none","facing":0,"note":"문서 창고 선반 칸 차장 일지 궤","level":2},
    {"kind":"shelf","rect":[35,70,3,1],"solid":"none","facing":0,"note":"문서 창고 선반 칸 선반","level":2},
    {"kind":"file_cabinet","rect":[42,61,2,1],"solid":"none","facing":0,"note":"문서 창고 계량실 기술 서류함","level":2},
    {"kind":"conductor_log_chest","rect":[45,70,2,1],"solid":"none","facing":0,"note":"문서 창고 계량실 차장 일지 궤","level":2},
    {"kind":"shelf","rect":[42,70,3,1],"solid":"none","facing":0,"note":"문서 창고 계량실 선반","level":2},
    {"kind":"file_cabinet","rect":[49,61,2,1],"solid":"none","facing":0,"note":"문서 창고 안쪽 창고 기술 서류함","level":2},
    {"kind":"conductor_log_chest","rect":[52,70,2,1],"solid":"none","facing":0,"note":"문서 창고 안쪽 창고 차장 일지 궤","level":2},
    {"kind":"shelf","rect":[49,70,3,1],"solid":"none","facing":0,"note":"문서 창고 안쪽 창고 선반","level":2},
    {"kind":"file_cabinet","rect":[56,61,2,1],"solid":"none","facing":0,"note":"문서 창고 기록실 기술 서류함","level":2},
    {"kind":"conductor_log_chest","rect":[60,70,2,1],"solid":"none","facing":0,"note":"문서 창고 기록실 차장 일지 궤","level":2},
    {"kind":"shelf","rect":[56,70,3,1],"solid":"none","facing":0,"note":"문서 창고 기록실 선반","level":2},
    {"kind":"file_cabinet","rect":[21,47,2,1],"solid":"none","facing":0,"note":"문서 창고 저장고 기술 서류함","level":-1},
    {"kind":"conductor_log_chest","rect":[24,56,2,1],"solid":"none","facing":0,"note":"문서 창고 저장고 차장 일지 궤","level":-1},
    {"kind":"part_crate","rect":[26,55,1,1],"solid":"none","facing":0,"note":"저장고 부품 상자","level":-1},
    {"kind":"file_cabinet","rect":[28,47,2,1],"solid":"none","facing":0,"note":"문서 창고 냉기 칸 기술 서류함","level":-1},
    {"kind":"conductor_log_chest","rect":[31,56,2,1],"solid":"none","facing":0,"note":"문서 창고 냉기 칸 차장 일지 궤","level":-1},
    {"kind":"part_crate","rect":[33,55,1,1],"solid":"none","facing":0,"note":"냉기 칸 부품 상자","level":-1},
    {"kind":"file_cabinet","rect":[35,47,2,1],"solid":"none","facing":0,"note":"문서 창고 안쪽 보관실 기술 서류함","level":-1},
    {"kind":"conductor_log_chest","rect":[38,56,2,1],"solid":"none","facing":0,"note":"문서 창고 안쪽 보관실 차장 일지 궤","level":-1},
    {"kind":"part_crate","rect":[40,55,1,1],"solid":"none","facing":0,"note":"안쪽 보관실 부품 상자","level":-1},
    {"kind":"file_cabinet","rect":[42,47,2,1],"solid":"none","facing":0,"note":"문서 창고 저장고 기술 서류함","level":-1},
    {"kind":"conductor_log_chest","rect":[45,56,2,1],"solid":"none","facing":0,"note":"문서 창고 저장고 차장 일지 궤","level":-1},
    {"kind":"part_crate","rect":[47,55,1,1],"solid":"none","facing":0,"note":"저장고 부품 상자","level":-1},
    {"kind":"file_cabinet","rect":[49,47,2,1],"solid":"none","facing":0,"note":"문서 창고 냉기 칸 기술 서류함","level":-1},
    {"kind":"conductor_log_chest","rect":[52,56,2,1],"solid":"none","facing":0,"note":"문서 창고 냉기 칸 차장 일지 궤","level":-1},
    {"kind":"part_crate","rect":[54,55,1,1],"solid":"none","facing":0,"note":"냉기 칸 부품 상자","level":-1},
    {"kind":"file_cabinet","rect":[56,47,2,1],"solid":"none","facing":0,"note":"문서 창고 안쪽 보관실 기술 서류함","level":-1},
    {"kind":"conductor_log_chest","rect":[60,56,2,1],"solid":"none","facing":0,"note":"문서 창고 안쪽 보관실 차장 일지 궤","level":-1},
    {"kind":"shelf","rect":[56,56,3,1],"solid":"none","facing":0,"note":"문서 창고 안쪽 보관실 선반","level":-1},
    {"kind":"file_cabinet","rect":[21,61,2,1],"solid":"none","facing":0,"note":"문서 창고 저장고 기술 서류함","level":-1},
    {"kind":"conductor_log_chest","rect":[24,70,2,1],"solid":"none","facing":0,"note":"문서 창고 저장고 차장 일지 궤","level":-1},
    {"kind":"shelf","rect":[21,70,3,1],"solid":"none","facing":0,"note":"문서 창고 저장고 선반","level":-1},
    {"kind":"file_cabinet","rect":[28,61,2,1],"solid":"none","facing":0,"note":"문서 창고 냉기 칸 기술 서류함","level":-1},
    {"kind":"conductor_log_chest","rect":[31,70,2,1],"solid":"none","facing":0,"note":"문서 창고 냉기 칸 차장 일지 궤","level":-1},
    {"kind":"shelf","rect":[28,70,3,1],"solid":"none","facing":0,"note":"문서 창고 냉기 칸 선반","level":-1},
    {"kind":"file_cabinet","rect":[35,61,2,1],"solid":"none","facing":0,"note":"문서 창고 안쪽 보관실 기술 서류함","level":-1},
    {"kind":"conductor_log_chest","rect":[38,70,2,1],"solid":"none","facing":0,"note":"문서 창고 안쪽 보관실 차장 일지 궤","level":-1},
    {"kind":"shelf","rect":[35,70,3,1],"solid":"none","facing":0,"note":"문서 창고 안쪽 보관실 선반","level":-1},
    {"kind":"file_cabinet","rect":[42,61,2,1],"solid":"none","facing":0,"note":"문서 창고 저장고 기술 서류함","level":-1},
    {"kind":"conductor_log_chest","rect":[45,70,2,1],"solid":"none","facing":0,"note":"문서 창고 저장고 차장 일지 궤","level":-1},
    {"kind":"shelf","rect":[42,70,3,1],"solid":"none","facing":0,"note":"문서 창고 저장고 선반","level":-1},
    {"kind":"file_cabinet","rect":[49,61,2,1],"solid":"none","facing":0,"note":"문서 창고 냉기 칸 기술 서류함","level":-1},
    {"kind":"conductor_log_chest","rect":[52,70,2,1],"solid":"none","facing":0,"note":"문서 창고 냉기 칸 차장 일지 궤","level":-1},
    {"kind":"shelf","rect":[49,70,3,1],"solid":"none","facing":0,"note":"문서 창고 냉기 칸 선반","level":-1},
    {"kind":"file_cabinet","rect":[56,61,2,1],"solid":"none","facing":0,"note":"문서 창고 안쪽 보관실 기술 서류함","level":-1},
    {"kind":"conductor_log_chest","rect":[60,70,2,1],"solid":"none","facing":0,"note":"문서 창고 안쪽 보관실 차장 일지 궤","level":-1},
    {"kind":"shelf","rect":[56,70,3,1],"solid":"none","facing":0,"note":"문서 창고 안쪽 보관실 선반","level":-1},
    {"kind":"file_cabinet","rect":[91,48,2,1],"solid":"low","facing":0,"note":"숙직소 앞방 기술 서류함","level":0},
    {"kind":"conductor_log_chest","rect":[98,57,2,1],"solid":"low","facing":0,"note":"숙직소 앞방 차장 일지 궤","level":0},
    {"kind":"shelf","rect":[91,57,3,1],"solid":"low","facing":0,"note":"숙직소 앞방 선반","level":0},
    {"kind":"file_cabinet","rect":[102,48,2,1],"solid":"low","facing":0,"note":"숙직소 안쪽 방 기술 서류함","level":0},
    {"kind":"conductor_log_chest","rect":[102,57,2,1],"solid":"low","facing":0,"note":"숙직소 안쪽 방 차장 일지 궤","level":0},
    {"kind":"part_crate","rect":[110,48,1,1],"solid":"low","facing":0,"note":"안쪽 방 부품 상자","level":0},
    {"kind":"file_cabinet","rect":[91,48,2,1],"solid":"none","facing":0,"note":"숙직소 앞방 기술 서류함","level":1},
    {"kind":"conductor_log_chest","rect":[98,57,2,1],"solid":"none","facing":0,"note":"숙직소 앞방 차장 일지 궤","level":1},
    {"kind":"shelf","rect":[91,57,3,1],"solid":"none","facing":0,"note":"숙직소 앞방 선반","level":1},
    {"kind":"file_cabinet","rect":[102,48,2,1],"solid":"none","facing":0,"note":"숙직소 안쪽 방 기술 서류함","level":1},
    {"kind":"conductor_log_chest","rect":[108,57,2,1],"solid":"none","facing":0,"note":"숙직소 안쪽 방 차장 일지 궤","level":1},
    {"kind":"shelf","rect":[102,57,3,1],"solid":"none","facing":0,"note":"숙직소 안쪽 방 선반","level":1},
    {"kind":"file_cabinet","rect":[117,47,2,1],"solid":"low","facing":0,"note":"매점 매장 기술 서류함","level":0},
    {"kind":"conductor_log_chest","rect":[117,49,2,1],"solid":"low","facing":0,"note":"매점 매장 차장 일지 궤","level":0},
    {"kind":"part_crate","rect":[126,47,1,1],"solid":"low","facing":0,"note":"매장 부품 상자","level":0},
    {"kind":"file_cabinet","rect":[117,51,2,1],"solid":"low","facing":0,"note":"매점 뒤 창고 기술 서류함","level":0},
    {"kind":"conductor_log_chest","rect":[117,53,2,1],"solid":"low","facing":0,"note":"매점 뒤 창고 차장 일지 궤","level":0},
    {"kind":"part_crate","rect":[126,51,1,1],"solid":"low","facing":0,"note":"뒤 창고 부품 상자","level":0},
    {"kind":"file_cabinet","rect":[113,13,2,1],"solid":"none","facing":0,"note":"신호 취급소 작업실 기술 서류함","level":1},
    {"kind":"conductor_log_chest","rect":[116,17,2,1],"solid":"none","facing":0,"note":"신호 취급소 작업실 차장 일지 궤","level":1},
    {"kind":"shelf","rect":[113,17,3,1],"solid":"none","facing":0,"note":"신호 취급소 작업실 선반","level":1},
    {"kind":"file_cabinet","rect":[125,63,2,1],"solid":"low","facing":0,"note":"부품 창고 앞방 기술 서류함","level":0},
    {"kind":"conductor_log_chest","rect":[131,72,2,1],"solid":"low","facing":0,"note":"부품 창고 앞방 차장 일지 궤","level":0},
    {"kind":"shelf","rect":[125,72,3,1],"solid":"low","facing":0,"note":"부품 창고 앞방 선반","level":0},
    {"kind":"file_cabinet","rect":[135,63,2,1],"solid":"low","facing":0,"note":"부품 창고 안쪽 방 기술 서류함","level":0},
    {"kind":"conductor_log_chest","rect":[135,72,2,1],"solid":"low","facing":0,"note":"부품 창고 안쪽 방 차장 일지 궤","level":0},
    {"kind":"part_crate","rect":[142,63,1,1],"solid":"low","facing":0,"note":"안쪽 방 부품 상자","level":0},
    {"kind":"file_cabinet","rect":[71,21,2,1],"solid":"none","facing":0,"note":"사무소 앞방 기술 서류함","level":1},
    {"kind":"conductor_log_chest","rect":[77,32,2,1],"solid":"none","facing":0,"note":"사무소 앞방 차장 일지 궤","level":1},
    {"kind":"shelf","rect":[71,32,3,1],"solid":"none","facing":0,"note":"사무소 앞방 선반","level":1},
    {"kind":"file_cabinet","rect":[81,21,2,1],"solid":"none","facing":0,"note":"사무소 안쪽 방 기술 서류함","level":1},
    {"kind":"conductor_log_chest","rect":[86,32,2,1],"solid":"none","facing":0,"note":"사무소 안쪽 방 차장 일지 궤","level":1},
    {"kind":"shelf","rect":[81,32,3,1],"solid":"none","facing":0,"note":"사무소 안쪽 방 선반","level":1},
    {"kind":"file_cabinet","rect":[147,76,2,1],"solid":"low","facing":0,"note":"수선 헛간 앞방 기술 서류함","level":0},
    {"kind":"conductor_log_chest","rect":[152,83,2,1],"solid":"low","facing":0,"note":"수선 헛간 앞방 차장 일지 궤","level":0},
    {"kind":"shelf","rect":[147,83,3,1],"solid":"low","facing":0,"note":"수선 헛간 앞방 선반","level":0},
    {"kind":"file_cabinet","rect":[156,76,2,1],"solid":"low","facing":0,"note":"수선 헛간 안쪽 방 기술 서류함","level":0},
    {"kind":"conductor_log_chest","rect":[160,83,2,1],"solid":"low","facing":0,"note":"수선 헛간 안쪽 방 차장 일지 궤","level":0},
    {"kind":"shelf","rect":[156,83,3,1],"solid":"low","facing":0,"note":"수선 헛간 안쪽 방 선반","level":0},
    {"kind":"file_cabinet","rect":[145,21,2,1],"solid":"low","facing":0,"note":"변전실 작업실 기술 서류함","level":0},
    {"kind":"conductor_log_chest","rect":[145,26,2,1],"solid":"low","facing":0,"note":"변전실 작업실 차장 일지 궤","level":0},
    {"kind":"part_crate","rect":[152,21,1,1],"solid":"low","facing":0,"note":"작업실 부품 상자","level":0},
    {"kind":"file_cabinet","rect":[7,81,2,1],"solid":"low","facing":0,"note":"공구 창고 앞방 기술 서류함","level":0},
    {"kind":"conductor_log_chest","rect":[11,88,2,1],"solid":"low","facing":0,"note":"공구 창고 앞방 차장 일지 궤","level":0},
    {"kind":"shelf","rect":[7,88,3,1],"solid":"low","facing":0,"note":"공구 창고 앞방 선반","level":0},
    {"kind":"file_cabinet","rect":[15,81,2,1],"solid":"low","facing":0,"note":"공구 창고 안쪽 방 기술 서류함","level":0},
    {"kind":"conductor_log_chest","rect":[15,88,2,1],"solid":"low","facing":0,"note":"공구 창고 안쪽 방 차장 일지 궤","level":0},
    {"kind":"part_crate","rect":[20,81,1,1],"solid":"low","facing":0,"note":"안쪽 방 부품 상자","level":0},
    {"kind":"file_cabinet","rect":[95,79,2,1],"solid":"low","facing":0,"note":"하역 창고 앞방 기술 서류함","level":0},
    {"kind":"conductor_log_chest","rect":[103,88,2,1],"solid":"low","facing":0,"note":"하역 창고 앞방 차장 일지 궤","level":0},
    {"kind":"shelf","rect":[95,88,3,1],"solid":"low","facing":0,"note":"하역 창고 앞방 선반","level":0},
    {"kind":"file_cabinet","rect":[107,79,2,1],"solid":"low","facing":0,"note":"하역 창고 안쪽 방 기술 서류함","level":0},
    {"kind":"conductor_log_chest","rect":[107,88,2,1],"solid":"low","facing":0,"note":"하역 창고 안쪽 방 차장 일지 궤","level":0},
    {"kind":"part_crate","rect":[116,79,1,1],"solid":"low","facing":0,"note":"안쪽 방 부품 상자","level":0},
    {"kind":"file_cabinet","rect":[27,84,2,1],"solid":"low","facing":0,"note":"급수 펌프실 작업실 기술 서류함","level":0},
    {"kind":"conductor_log_chest","rect":[31,79,2,1],"solid":"low","facing":0,"note":"급수 펌프실 작업실 차장 일지 궤","level":0},
    {"kind":"part_crate","rect":[27,79,1,1],"solid":"low","facing":0,"note":"작업실 부품 상자","level":0},
    {"kind":"file_cabinet","rect":[44,82,2,1],"solid":"low","facing":0,"note":"차장 휴게실 앞방 기술 서류함","level":0},
    {"kind":"conductor_log_chest","rect":[46,88,2,1],"solid":"low","facing":0,"note":"차장 휴게실 앞방 차장 일지 궤","level":0},
    {"kind":"part_crate","rect":[48,82,1,1],"solid":"low","facing":0,"note":"앞방 부품 상자","level":0},
    {"kind":"file_cabinet","rect":[50,82,2,1],"solid":"low","facing":0,"note":"차장 휴게실 안쪽 방 기술 서류함","level":0},
    {"kind":"conductor_log_chest","rect":[50,88,2,1],"solid":"low","facing":0,"note":"차장 휴게실 안쪽 방 차장 일지 궤","level":0},
    {"kind":"part_crate","rect":[53,82,1,1],"solid":"low","facing":0,"note":"안쪽 방 부품 상자","level":0},
    {"kind":"file_cabinet","rect":[61,82,2,1],"solid":"low","facing":0,"note":"문서 별채 앞방 기술 서류함","level":0},
    {"kind":"conductor_log_chest","rect":[65,89,2,1],"solid":"low","facing":0,"note":"문서 별채 앞방 차장 일지 궤","level":0},
    {"kind":"shelf","rect":[61,89,3,1],"solid":"low","facing":0,"note":"문서 별채 앞방 선반","level":0},
    {"kind":"file_cabinet","rect":[69,82,2,1],"solid":"low","facing":0,"note":"문서 별채 안쪽 방 기술 서류함","level":0},
    {"kind":"conductor_log_chest","rect":[69,89,2,1],"solid":"low","facing":0,"note":"문서 별채 안쪽 방 차장 일지 궤","level":0},
    {"kind":"part_crate","rect":[74,82,1,1],"solid":"low","facing":0,"note":"안쪽 방 부품 상자","level":0},
    {"kind":"file_cabinet","rect":[101,66,2,1],"solid":"low","facing":0,"note":"기술 서류함 작업 흔적","level":0},
    {"kind":"pallet_stack","rect":[105,66,2,2],"solid":"low","facing":0,"note":"팰릿 더미 작업 흔적","level":0},
    {"kind":"part_crate","rect":[109,66,1,1],"solid":"low","facing":0,"note":"부품 상자 작업 흔적","level":0},
    {"kind":"conductor_log_chest","rect":[130,52,2,1],"solid":"low","facing":0,"note":"차장 일지 궤 작업 흔적","level":0},
    {"kind":"weigh_platform","rect":[134,52,3,2],"solid":"low","facing":0,"note":"계량대 작업 흔적","level":0},
    {"kind":"tool_cart","rect":[151,62,2,1],"solid":"low","facing":0,"note":"공구 수레 작업 흔적","level":0},
    {"kind":"coupler_set","rect":[155,62,1,1],"solid":"low","facing":0,"note":"연결기 한 벌 작업 흔적","level":0},
    {"kind":"wheelset","rect":[159,62,2,1],"solid":"low","facing":0,"note":"차륜 한 쌍 작업 흔적","level":0},
    {"kind":"rail_pile","rect":[6,70,3,1],"solid":"low","facing":0,"note":"레일 더미 작업 흔적","level":0},
    {"kind":"part_crate","rect":[10,70,1,1],"solid":"low","facing":0,"note":"부품 상자 작업 흔적","level":0},
    {"kind":"barrel","rect":[14,70,1,1],"solid":"low","facing":0,"note":"통 작업 흔적","level":0},
    {"kind":"bare_tree","rect":[2,45,1,1],"solid":"tree","facing":0,"note":"길가 마른 나무","level":0},
    {"kind":"bare_tree","rect":[2,50,1,1],"solid":"tree","facing":0,"note":"길가 마른 나무","level":0},
    {"kind":"bare_tree","rect":[2,55,1,1],"solid":"tree","facing":0,"note":"길가 마른 나무","level":0},
    {"kind":"bare_tree","rect":[2,60,1,1],"solid":"tree","facing":0,"note":"길가 마른 나무","level":0},
    {"kind":"bare_tree","rect":[2,65,1,1],"solid":"tree","facing":0,"note":"길가 마른 나무","level":0},
    {"kind":"bare_tree","rect":[2,70,1,1],"solid":"tree","facing":0,"note":"길가 마른 나무","level":0},
    {"kind":"bare_tree","rect":[2,75,1,1],"solid":"tree","facing":0,"note":"길가 마른 나무","level":0},
    {"kind":"bare_tree","rect":[2,80,1,1],"solid":"tree","facing":0,"note":"길가 마른 나무","level":0},
    {"kind":"bare_tree","rect":[2,85,1,1],"solid":"tree","facing":0,"note":"길가 마른 나무","level":0},
    {"kind":"bare_tree","rect":[167,47,1,1],"solid":"tree","facing":0,"note":"길가 마른 나무","level":0},
    {"kind":"bare_tree","rect":[167,53,1,1],"solid":"tree","facing":0,"note":"길가 마른 나무","level":0},
    {"kind":"bare_tree","rect":[167,59,1,1],"solid":"tree","facing":0,"note":"길가 마른 나무","level":0},
    {"kind":"bare_tree","rect":[167,65,1,1],"solid":"tree","facing":0,"note":"길가 마른 나무","level":0},
    {"kind":"bare_tree","rect":[167,71,1,1],"solid":"tree","facing":0,"note":"길가 마른 나무","level":0},
    {"kind":"bare_tree","rect":[167,77,1,1],"solid":"tree","facing":0,"note":"길가 마른 나무","level":0},
    {"kind":"bare_tree","rect":[167,83,1,1],"solid":"tree","facing":0,"note":"길가 마른 나무","level":0},
    {"kind":"bare_tree","rect":[167,89,1,1],"solid":"tree","facing":0,"note":"길가 마른 나무","level":0},
    {"kind":"bare_tree","rect":[128,81,1,1],"solid":"tree","facing":0,"note":"길가 마른 나무","level":0},
    {"kind":"bare_tree","rect":[133,82,1,1],"solid":"tree","facing":0,"note":"길가 마른 나무","level":0},
    {"kind":"bare_tree","rect":[138,83,1,1],"solid":"tree","facing":0,"note":"길가 마른 나무","level":0},
    {"kind":"bare_tree","rect":[143,84,1,1],"solid":"tree","facing":0,"note":"길가 마른 나무","level":0},
    {"kind":"bare_tree","rect":[69,49,1,1],"solid":"tree","facing":0,"note":"길가 마른 나무","level":0},
    {"kind":"bare_tree","rect":[69,55,1,1],"solid":"tree","facing":0,"note":"길가 마른 나무","level":0},
    {"kind":"bare_tree","rect":[69,61,1,1],"solid":"tree","facing":0,"note":"길가 마른 나무","level":0},
    {"kind":"bare_tree","rect":[69,67,1,1],"solid":"tree","facing":0,"note":"길가 마른 나무","level":0},
    {"kind":"bare_tree","rect":[69,73,1,1],"solid":"tree","facing":0,"note":"길가 마른 나무","level":0},
    {"kind":"bare_tree","rect":[69,79,1,1],"solid":"tree","facing":0,"note":"길가 마른 나무","level":0},
    {"kind":"bare_tree","rect":[39,75,1,1],"solid":"tree","facing":0,"note":"길가 마른 나무","level":0},
    {"kind":"bare_tree","rect":[44,75,1,1],"solid":"tree","facing":0,"note":"길가 마른 나무","level":0},
    {"kind":"bare_tree","rect":[49,75,1,1],"solid":"tree","facing":0,"note":"길가 마른 나무","level":0},
    {"kind":"bare_tree","rect":[54,75,1,1],"solid":"tree","facing":0,"note":"길가 마른 나무","level":0},
    {"kind":"bare_tree","rect":[59,75,1,1],"solid":"tree","facing":0,"note":"길가 마른 나무","level":0}
  ],
  "containers": [
    {"id":"box_1","name":"문서 창고 사무실 상자","cell":[26,56],"building":0,"search":5,"items":["document","food_pack"],"locked":false,"level":0,"searched":false},
    {"id":"box_2","name":"문서 창고 선별실 상자","cell":[33,56],"building":0,"search":5,"items":["document","food_pack"],"locked":false,"level":0,"searched":false},
    {"id":"box_3","name":"문서 창고 선반 칸 상자","cell":[40,56],"building":0,"search":5,"items":["document","document"],"locked":false,"level":0,"searched":false},
    {"id":"box_4","name":"문서 창고 계량실 상자","cell":[47,56],"building":0,"search":5,"items":["document","food_pack"],"locked":false,"level":0,"searched":false},
    {"id":"box_5","name":"문서 창고 안쪽 창고 상자","cell":[54,56],"building":0,"search":5,"items":["document","food_pack"],"locked":false,"level":0,"searched":false},
    {"id":"box_6","name":"문서 창고 기록실 상자","cell":[62,56],"building":0,"search":5,"items":["document","document"],"locked":false,"level":0,"searched":false},
    {"id":"box_7","name":"문서 창고 사무실 상자","cell":[26,70],"building":0,"search":5,"items":["document","food_pack"],"locked":false,"level":0,"searched":false},
    {"id":"box_8","name":"문서 창고 선별실 상자","cell":[33,70],"building":0,"search":5,"items":["document","food_pack"],"locked":false,"level":0,"searched":false},
    {"id":"box_9","name":"문서 창고 선반 칸 상자","cell":[40,70],"building":0,"search":5,"items":["document","document"],"locked":false,"level":0,"searched":false},
    {"id":"box_10","name":"문서 창고 계량실 상자","cell":[47,70],"building":0,"search":5,"items":["document","food_pack"],"locked":false,"level":0,"searched":false},
    {"id":"box_11","name":"문서 창고 안쪽 창고 상자","cell":[54,70],"building":0,"search":5,"items":["document","food_pack"],"locked":false,"level":0,"searched":false},
    {"id":"box_12","name":"문서 창고 기록실 상자","cell":[62,70],"building":0,"search":5,"items":["document","document"],"locked":false,"level":0,"searched":false},
    {"id":"box_13","name":"문서 창고 사무실 상자","cell":[26,56],"building":0,"search":5,"items":["document","food_pack"],"locked":false,"level":1,"searched":false},
    {"id":"box_14","name":"문서 창고 선별실 상자","cell":[33,56],"building":0,"search":5,"items":["document","food_pack"],"locked":false,"level":1,"searched":false},
    {"id":"box_15","name":"문서 창고 선반 칸 상자","cell":[40,56],"building":0,"search":5,"items":["document","document"],"locked":false,"level":1,"searched":false},
    {"id":"box_16","name":"문서 창고 계량실 상자","cell":[47,56],"building":0,"search":5,"items":["document","food_pack"],"locked":false,"level":1,"searched":false},
    {"id":"box_17","name":"문서 창고 안쪽 창고 상자","cell":[54,56],"building":0,"search":5,"items":["document","food_pack"],"locked":false,"level":1,"searched":false},
    {"id":"box_18","name":"문서 창고 기록실 상자","cell":[62,56],"building":0,"search":5,"items":["document","document"],"locked":false,"level":1,"searched":false},
    {"id":"box_19","name":"문서 창고 사무실 상자","cell":[26,70],"building":0,"search":5,"items":["document","food_pack"],"locked":false,"level":1,"searched":false},
    {"id":"box_20","name":"문서 창고 선별실 상자","cell":[33,70],"building":0,"search":5,"items":["document","food_pack"],"locked":false,"level":1,"searched":false},
    {"id":"box_21","name":"문서 창고 선반 칸 상자","cell":[40,70],"building":0,"search":5,"items":["document","document"],"locked":false,"level":1,"searched":false},
    {"id":"box_22","name":"문서 창고 계량실 상자","cell":[47,70],"building":0,"search":5,"items":["document","food_pack"],"locked":false,"level":1,"searched":false},
    {"id":"box_23","name":"문서 창고 안쪽 창고 상자","cell":[54,70],"building":0,"search":5,"items":["document","food_pack"],"locked":false,"level":1,"searched":false},
    {"id":"box_24","name":"문서 창고 기록실 상자","cell":[62,70],"building":0,"search":5,"items":["document","document"],"locked":false,"level":1,"searched":false},
    {"id":"box_25","name":"문서 창고 사무실 상자","cell":[26,56],"building":0,"search":5,"items":["document","food_pack"],"locked":false,"level":2,"searched":false},
    {"id":"box_26","name":"문서 창고 선별실 상자","cell":[33,56],"building":0,"search":5,"items":["document","food_pack"],"locked":false,"level":2,"searched":false},
    {"id":"box_27","name":"문서 창고 선반 칸 상자","cell":[40,56],"building":0,"search":5,"items":["document","document"],"locked":false,"level":2,"searched":false},
    {"id":"box_28","name":"문서 창고 계량실 상자","cell":[47,56],"building":0,"search":5,"items":["document","food_pack"],"locked":false,"level":2,"searched":false},
    {"id":"box_29","name":"문서 창고 안쪽 창고 상자","cell":[54,56],"building":0,"search":5,"items":["document","food_pack"],"locked":false,"level":2,"searched":false},
    {"id":"box_30","name":"문서 창고 기록실 상자","cell":[62,56],"building":0,"search":5,"items":["document","document"],"locked":false,"level":2,"searched":false},
    {"id":"box_31","name":"문서 창고 사무실 상자","cell":[26,70],"building":0,"search":5,"items":["document","food_pack"],"locked":false,"level":2,"searched":false},
    {"id":"box_32","name":"문서 창고 선별실 상자","cell":[33,70],"building":0,"search":5,"items":["document","food_pack"],"locked":false,"level":2,"searched":false},
    {"id":"box_33","name":"문서 창고 선반 칸 상자","cell":[40,70],"building":0,"search":5,"items":["document","document"],"locked":false,"level":2,"searched":false},
    {"id":"box_34","name":"문서 창고 계량실 상자","cell":[47,70],"building":0,"search":5,"items":["document","food_pack"],"locked":false,"level":2,"searched":false},
    {"id":"box_35","name":"문서 창고 안쪽 창고 상자","cell":[54,70],"building":0,"search":5,"items":["document","food_pack"],"locked":false,"level":2,"searched":false},
    {"id":"box_36","name":"문서 창고 기록실 상자","cell":[62,70],"building":0,"search":5,"items":["document","document"],"locked":false,"level":2,"searched":false},
    {"id":"box_37","name":"문서 창고 저장고 상자","cell":[26,56],"building":0,"search":5,"items":["document","food_pack"],"locked":false,"level":-1,"searched":false},
    {"id":"box_38","name":"문서 창고 냉기 칸 상자","cell":[33,56],"building":0,"search":5,"items":["document","food_pack"],"locked":false,"level":-1,"searched":false},
    {"id":"box_39","name":"문서 창고 안쪽 보관실 상자","cell":[40,56],"building":0,"search":5,"items":["document","document"],"locked":false,"level":-1,"searched":false},
    {"id":"box_40","name":"문서 창고 저장고 상자","cell":[47,56],"building":0,"search":5,"items":["document","food_pack"],"locked":false,"level":-1,"searched":false},
    {"id":"box_41","name":"문서 창고 냉기 칸 상자","cell":[54,56],"building":0,"search":5,"items":["document","food_pack"],"locked":false,"level":-1,"searched":false},
    {"id":"box_42","name":"문서 창고 안쪽 보관실 상자","cell":[62,56],"building":0,"search":5,"items":["document","document"],"locked":false,"level":-1,"searched":false},
    {"id":"box_43","name":"문서 창고 저장고 상자","cell":[26,70],"building":0,"search":5,"items":["document","food_pack"],"locked":false,"level":-1,"searched":false},
    {"id":"box_44","name":"문서 창고 냉기 칸 상자","cell":[33,70],"building":0,"search":5,"items":["document","food_pack"],"locked":false,"level":-1,"searched":false},
    {"id":"box_45","name":"문서 창고 안쪽 보관실 상자","cell":[40,70],"building":0,"search":5,"items":["document","document"],"locked":false,"level":-1,"searched":false},
    {"id":"box_46","name":"문서 창고 저장고 상자","cell":[47,70],"building":0,"search":5,"items":["document","food_pack"],"locked":false,"level":-1,"searched":false},
    {"id":"box_47","name":"문서 창고 냉기 칸 상자","cell":[54,70],"building":0,"search":5,"items":["document","food_pack"],"locked":false,"level":-1,"searched":false},
    {"id":"box_48","name":"문서 창고 안쪽 보관실 상자","cell":[62,70],"building":0,"search":5,"items":["document","document"],"locked":false,"level":-1,"searched":false},
    {"id":"box_49","name":"계량소 작업실 상자","cell":[16,18],"building":1,"search":5,"items":["document","food_pack"],"locked":false,"level":0,"searched":false},
    {"id":"box_50","name":"숙직소 앞방 상자","cell":[100,57],"building":2,"search":5,"items":["document","food_pack"],"locked":false,"level":0,"searched":false},
    {"id":"box_51","name":"숙직소 안쪽 방 상자","cell":[110,57],"building":2,"search":5,"items":["document","document"],"locked":false,"level":0,"searched":false},
    {"id":"box_52","name":"숙직소 앞방 상자","cell":[100,57],"building":2,"search":5,"items":["document","food_pack"],"locked":false,"level":1,"searched":false},
    {"id":"box_53","name":"숙직소 안쪽 방 상자","cell":[110,57],"building":2,"search":5,"items":["document","food_pack"],"locked":false,"level":1,"searched":false},
    {"id":"box_54","name":"매점 매장 상자","cell":[126,49],"building":3,"search":5,"items":["document","document"],"locked":false,"level":0,"searched":false},
    {"id":"box_55","name":"매점 뒤 창고 상자","cell":[126,53],"building":3,"search":5,"items":["document","food_pack"],"locked":false,"level":0,"searched":false},
    {"id":"box_56","name":"신호 취급소 작업실 상자","cell":[118,17],"building":4,"search":5,"items":["document","food_pack"],"locked":false,"level":0,"searched":false},
    {"id":"box_57","name":"신호 취급소 작업실 상자","cell":[118,17],"building":4,"search":5,"items":["document","document"],"locked":false,"level":1,"searched":false},
    {"id":"box_58","name":"부품 창고 앞방 상자","cell":[133,72],"building":5,"search":5,"items":["document","food_pack"],"locked":false,"level":0,"searched":false},
    {"id":"box_59","name":"부품 창고 안쪽 방 상자","cell":[142,72],"building":5,"search":5,"items":["document","food_pack"],"locked":false,"level":0,"searched":false},
    {"id":"box_60","name":"사무소 앞방 상자","cell":[79,32],"building":6,"search":5,"items":["document","document"],"locked":false,"level":0,"searched":false},
    {"id":"box_61","name":"사무소 안쪽 방 상자","cell":[88,32],"building":6,"search":5,"items":["document","food_pack"],"locked":false,"level":0,"searched":false},
    {"id":"box_62","name":"사무소 앞방 상자","cell":[79,32],"building":6,"search":5,"items":["document","food_pack"],"locked":false,"level":1,"searched":false},
    {"id":"box_63","name":"사무소 안쪽 방 상자","cell":[88,32],"building":6,"search":5,"items":["document","document"],"locked":false,"level":1,"searched":false},
    {"id":"box_64","name":"수선 헛간 앞방 상자","cell":[154,83],"building":7,"search":5,"items":["document","food_pack"],"locked":false,"level":0,"searched":false},
    {"id":"box_65","name":"수선 헛간 안쪽 방 상자","cell":[162,83],"building":7,"search":5,"items":["document","food_pack"],"locked":false,"level":0,"searched":false},
    {"id":"box_66","name":"모래 창고 작업실 상자","cell":[12,30],"building":8,"search":5,"items":["document","document"],"locked":false,"level":0,"searched":false},
    {"id":"box_67","name":"변전실 작업실 상자","cell":[152,26],"building":9,"search":5,"items":["document","food_pack"],"locked":false,"level":0,"searched":false},
    {"id":"box_68","name":"공구 창고 앞방 상자","cell":[13,88],"building":10,"search":5,"items":["document","food_pack"],"locked":false,"level":0,"searched":false},
    {"id":"box_69","name":"공구 창고 안쪽 방 상자","cell":[20,88],"building":10,"search":5,"items":["document","document"],"locked":false,"level":0,"searched":false},
    {"id":"box_70","name":"하역 창고 앞방 상자","cell":[105,88],"building":11,"search":5,"items":["document","food_pack"],"locked":false,"level":0,"searched":false},
    {"id":"box_71","name":"하역 창고 안쪽 방 상자","cell":[116,88],"building":11,"search":5,"items":["document","food_pack"],"locked":false,"level":0,"searched":false},
    {"id":"box_72","name":"급수 펌프실 작업실 상자","cell":[32,84],"building":12,"search":5,"items":["document","document"],"locked":false,"level":0,"searched":false},
    {"id":"box_73","name":"차장 휴게실 앞방 상자","cell":[48,88],"building":13,"search":5,"items":["document","food_pack"],"locked":false,"level":0,"searched":false},
    {"id":"box_74","name":"차장 휴게실 안쪽 방 상자","cell":[53,88],"building":13,"search":5,"items":["document","food_pack"],"locked":false,"level":0,"searched":false},
    {"id":"box_75","name":"문서 별채 앞방 상자","cell":[67,89],"building":14,"search":5,"items":["document","document"],"locked":false,"level":0,"searched":false},
    {"id":"box_76","name":"문서 별채 안쪽 방 상자","cell":[74,89],"building":14,"search":5,"items":["document","food_pack"],"locked":false,"level":0,"searched":false},
    {"id":"box_platform","name":"승강장 보급 상자","cell":[38,8],"building":-1,"search":4,"items":["document","food_pack"],"locked":false,"level":0,"searched":false}
  ],
  "wagons": [],
  "entries": [
    ["west_yard",[[0,38],[0,39],[0,40],[0,41]],0.6],
    ["east_yard",[[169,38],[169,39],[169,40],[169,41]],0.6],
    ["south_road",[[84,94],[85,94],[86,94],[87,94]],0.6],
    ["east_track",[[169,1],[169,2],[169,3]],0.6]
  ],
  "holes": [
    ["manhole_01",[86,40],"구내 길 맨홀"],
    ["manhole_02",[150,40],"동쪽 길 맨홀"],
    ["drain_01",[96,30],"객차 남쪽 배수구"]
  ],
  "barricades": [
    [19,13],
    [21,13],
    [107,14],
    [110,14]
  ],
  "dead": [
    [95,30],
    [132,42],
    [84,67],
    [143,75],
    [22,76]
  ],
  "deep": [
    ["D","문서 창고"],
    ["G","수선 헛간"]
  ],
  "assumptions": ["띠 전체의 낮은 엄폐 네 덩이 제한을 우선해 막힌 객차 세 량은 고정 수납벽과 상자로 좌우 주머니를 분리했다. 긴 의자와 낮은 상자 더미로 막는 세부 표현은 미충족이다.","가로 구내 길은 여섯 칸으로 넓혔다. 배수구는 띠 밖 발생 규칙에 맞춰 남쪽으로 여덟 칸 옮겼다. 난로와 불 소재는 두지 않았다."],
  "salvage": [
    ["salvage_1","버려진 차",[131,44],"scrap"],
    ["salvage_2","버려진 차",[76,72],"scrap"],
    ["salvage_3","사무실 부품 상자",[25,47],"scrap"],
    ["salvage_4","선별실 부품 상자",[32,47],"scrap"],
    ["salvage_5","선반 칸 부품 상자",[39,47],"scrap"],
    ["salvage_6","계량실 부품 상자",[46,47],"scrap"]
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
		data["spots"]["work_site"] = {"kind": "work_site", "cell": _cell(work["cell"]), "name": "문서 계량 구역", "state": "closed", "zone_rect": _rect(work["rect"])}
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
    "8": {
      "kind": "weigh_platform",
      "rect": [
        18,
        32,
        3,
        2
      ],
      "solid": "low",
      "facing": 0,
      "note": "계량대",
      "level": 0
    },
    "11": {
      "kind": "crate_stack",
      "rect": [
        28,
        11,
        1,
        3
      ],
      "solid": "low",
      "facing": 0,
      "note": "나무 상자 더미",
      "level": 0
    },
    "12": {
      "kind": "crate_stack",
      "rect": [
        84,
        11,
        1,
        3
      ],
      "solid": "low",
      "facing": 0,
      "note": "나무 상자 더미",
      "level": 0
    },
    "237": {
      "kind": "bare_tree",
      "rect": [
        4,
        55,
        1,
        1
      ],
      "solid": "tree",
      "facing": 0,
      "note": "길가 마른 나무",
      "level": 0
    },
    "238": {
      "kind": "bare_tree",
      "rect": [
        7,
        56,
        1,
        1
      ],
      "solid": "tree",
      "facing": 0,
      "note": "길가 마른 나무",
      "level": 0
    },
    "239": {
      "kind": "bare_tree",
      "rect": [
        2,
        58,
        1,
        1
      ],
      "solid": "tree",
      "facing": 0,
      "note": "길가 마른 나무",
      "level": 0
    },
    "240": {
      "kind": "bare_tree",
      "rect": [
        6,
        60,
        1,
        1
      ],
      "solid": "tree",
      "facing": 0,
      "note": "길가 마른 나무",
      "level": 0
    },
    "241": {
      "kind": "bare_tree",
      "rect": [
        1,
        61,
        1,
        1
      ],
      "solid": "tree",
      "facing": 0,
      "note": "길가 마른 나무",
      "level": 0
    },
    "242": {
      "kind": "bare_tree",
      "rect": [
        35,
        72,
        1,
        1
      ],
      "solid": "tree",
      "facing": 0,
      "note": "길가 마른 나무",
      "level": 0
    },
    "243": {
      "kind": "bare_tree",
      "rect": [
        38,
        72,
        1,
        1
      ],
      "solid": "tree",
      "facing": 0,
      "note": "길가 마른 나무",
      "level": 0
    },
    "244": {
      "kind": "bare_tree",
      "rect": [
        33,
        74,
        1,
        1
      ],
      "solid": "tree",
      "facing": 0,
      "note": "길가 마른 나무",
      "level": 0
    },
    "245": {
      "kind": "bare_tree",
      "rect": [
        37,
        76,
        1,
        1
      ],
      "solid": "tree",
      "facing": 0,
      "note": "길가 마른 나무",
      "level": 0
    },
    "246": {
      "kind": "bare_tree",
      "rect": [
        32,
        77,
        1,
        1
      ],
      "solid": "tree",
      "facing": 0,
      "note": "길가 마른 나무",
      "level": 0
    },
    "247": {
      "kind": "bare_tree",
      "rect": [
        163,
        65,
        1,
        1
      ],
      "solid": "tree",
      "facing": 0,
      "note": "길가 마른 나무",
      "level": 0
    },
    "248": {
      "kind": "bare_tree",
      "rect": [
        166,
        66,
        1,
        1
      ],
      "solid": "tree",
      "facing": 0,
      "note": "길가 마른 나무",
      "level": 0
    },
    "249": {
      "kind": "bare_tree",
      "rect": [
        161,
        68,
        1,
        1
      ],
      "solid": "tree",
      "facing": 0,
      "note": "길가 마른 나무",
      "level": 0
    },
    "250": {
      "kind": "bare_tree",
      "rect": [
        165,
        70,
        1,
        1
      ],
      "solid": "tree",
      "facing": 0,
      "note": "길가 마른 나무",
      "level": 0
    },
    "251": {
      "kind": "bare_tree",
      "rect": [
        160,
        71,
        1,
        1
      ],
      "solid": "tree",
      "facing": 0,
      "note": "길가 마른 나무",
      "level": 0
    },
    "252": {
      "kind": "bare_tree",
      "rect": [
        147,
        85,
        1,
        1
      ],
      "solid": "tree",
      "facing": 0,
      "note": "길가 마른 나무",
      "level": 0
    },
    "253": {
      "kind": "bare_tree",
      "rect": [
        150,
        85,
        1,
        1
      ],
      "solid": "tree",
      "facing": 0,
      "note": "길가 마른 나무",
      "level": 0
    },
    "254": {
      "kind": "bare_tree",
      "rect": [
        145,
        87,
        1,
        1
      ],
      "solid": "tree",
      "facing": 0,
      "note": "길가 마른 나무",
      "level": 0
    },
    "255": {
      "kind": "bare_tree",
      "rect": [
        149,
        89,
        1,
        1
      ],
      "solid": "tree",
      "facing": 0,
      "note": "길가 마른 나무",
      "level": 0
    },
    "256": {
      "kind": "bare_tree",
      "rect": [
        144,
        90,
        1,
        1
      ],
      "solid": "tree",
      "facing": 0,
      "note": "길가 마른 나무",
      "level": 0
    },
    "257": {
      "kind": "bare_tree",
      "rect": [
        84,
        63,
        1,
        1
      ],
      "solid": "tree",
      "facing": 0,
      "note": "길가 마른 나무",
      "level": 0
    },
    "258": {
      "kind": "bare_tree",
      "rect": [
        87,
        64,
        1,
        1
      ],
      "solid": "tree",
      "facing": 0,
      "note": "길가 마른 나무",
      "level": 0
    },
    "259": {
      "kind": "bare_tree",
      "rect": [
        82,
        66,
        1,
        1
      ],
      "solid": "tree",
      "facing": 0,
      "note": "길가 마른 나무",
      "level": 0
    },
    "260": {
      "kind": "bare_tree",
      "rect": [
        86,
        68,
        1,
        1
      ],
      "solid": "tree",
      "facing": 0,
      "note": "길가 마른 나무",
      "level": 0
    },
    "261": {
      "kind": "bare_tree",
      "rect": [
        81,
        69,
        1,
        1
      ],
      "solid": "tree",
      "facing": 0,
      "note": "길가 마른 나무",
      "level": 0
    },
    "262": {
      "kind": "bare_tree",
      "rect": [
        54,
        75,
        1,
        1
      ],
      "solid": "tree",
      "facing": 0,
      "note": "길가 마른 나무",
      "level": 0
    },
    "263": {
      "kind": "bare_tree",
      "rect": [
        57,
        76,
        1,
        1
      ],
      "solid": "tree",
      "facing": 0,
      "note": "길가 마른 나무",
      "level": 0
    },
    "264": {
      "kind": "bare_tree",
      "rect": [
        52,
        78,
        1,
        1
      ],
      "solid": "tree",
      "facing": 0,
      "note": "길가 마른 나무",
      "level": 0
    },
    "265": {
      "kind": "bare_tree",
      "rect": [
        56,
        80,
        1,
        1
      ],
      "solid": "tree",
      "facing": 0,
      "note": "길가 마른 나무",
      "level": 0
    },
    "266": {
      "kind": "bare_tree",
      "rect": [
        51,
        80,
        1,
        1
      ],
      "solid": "tree",
      "facing": 0,
      "note": "길가 마른 나무",
      "level": 0
    },
    "267": {
      "kind": "bare_tree",
      "rect": [
        57,
        75,
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
        60,
        76,
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
    0,
    1,
    2,
    3,
    4,
    5
  ],
  "append": [
    {
      "kind": "bench",
      "rect": [
        56,
        11,
        1,
        3
      ],
      "solid": "low",
      "facing": 0,
      "note": "통로를 막은 객차 안 긴 의자",
      "level": 0
    }
  ],
  "work_site": {
    "cell": [
      66,
      18
    ],
    "rect": [
      66,
      18,
      39,
      21
    ]
  },
  "changed": [
    [
      2,
      45,
      1,
      1
    ],
    [
      4,
      55,
      1,
      1
    ],
    [
      2,
      50,
      1,
      1
    ],
    [
      7,
      56,
      1,
      1
    ],
    [
      2,
      55,
      1,
      1
    ],
    [
      2,
      58,
      1,
      1
    ],
    [
      2,
      60,
      1,
      1
    ],
    [
      6,
      60,
      1,
      1
    ],
    [
      2,
      65,
      1,
      1
    ],
    [
      1,
      61,
      1,
      1
    ],
    [
      2,
      70,
      1,
      1
    ],
    [
      35,
      72,
      1,
      1
    ],
    [
      2,
      75,
      1,
      1
    ],
    [
      38,
      72,
      1,
      1
    ],
    [
      2,
      80,
      1,
      1
    ],
    [
      33,
      74,
      1,
      1
    ],
    [
      2,
      85,
      1,
      1
    ],
    [
      37,
      76,
      1,
      1
    ],
    [
      167,
      47,
      1,
      1
    ],
    [
      32,
      77,
      1,
      1
    ],
    [
      167,
      53,
      1,
      1
    ],
    [
      163,
      65,
      1,
      1
    ],
    [
      167,
      59,
      1,
      1
    ],
    [
      166,
      66,
      1,
      1
    ],
    [
      167,
      65,
      1,
      1
    ],
    [
      161,
      68,
      1,
      1
    ],
    [
      167,
      71,
      1,
      1
    ],
    [
      165,
      70,
      1,
      1
    ],
    [
      167,
      77,
      1,
      1
    ],
    [
      160,
      71,
      1,
      1
    ],
    [
      167,
      83,
      1,
      1
    ],
    [
      147,
      85,
      1,
      1
    ],
    [
      167,
      89,
      1,
      1
    ],
    [
      150,
      85,
      1,
      1
    ],
    [
      128,
      81,
      1,
      1
    ],
    [
      145,
      87,
      1,
      1
    ],
    [
      133,
      82,
      1,
      1
    ],
    [
      149,
      89,
      1,
      1
    ],
    [
      138,
      83,
      1,
      1
    ],
    [
      144,
      90,
      1,
      1
    ],
    [
      143,
      84,
      1,
      1
    ],
    [
      84,
      63,
      1,
      1
    ],
    [
      69,
      49,
      1,
      1
    ],
    [
      87,
      64,
      1,
      1
    ],
    [
      69,
      55,
      1,
      1
    ],
    [
      82,
      66,
      1,
      1
    ],
    [
      69,
      61,
      1,
      1
    ],
    [
      86,
      68,
      1,
      1
    ],
    [
      69,
      67,
      1,
      1
    ],
    [
      81,
      69,
      1,
      1
    ],
    [
      69,
      73,
      1,
      1
    ],
    [
      54,
      75,
      1,
      1
    ],
    [
      69,
      79,
      1,
      1
    ],
    [
      57,
      76,
      1,
      1
    ],
    [
      39,
      75,
      1,
      1
    ],
    [
      52,
      78,
      1,
      1
    ],
    [
      44,
      75,
      1,
      1
    ],
    [
      56,
      80,
      1,
      1
    ],
    [
      49,
      75,
      1,
      1
    ],
    [
      51,
      80,
      1,
      1
    ],
    [
      54,
      75,
      1,
      1
    ],
    [
      57,
      75,
      1,
      1
    ],
    [
      59,
      75,
      1,
      1
    ],
    [
      60,
      76,
      1,
      1
    ],
    [
      18,
      21,
      3,
      2
    ],
    [
      18,
      32,
      3,
      2
    ],
    [
      98,
      24,
      2,
      2
    ],
    [
      29,
      11,
      1,
      3
    ],
    [
      23,
      25,
      2,
      2
    ],
    [
      85,
      11,
      1,
      3
    ],
    [
      57,
      11,
      1,
      3
    ],
    [
      28,
      11,
      1,
      3
    ],
    [
      84,
      11,
      1,
      3
    ],
    [
      56,
      11,
      1,
      3
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
  "id": "freight_05",
  "size": [
    170,
    140
  ],
  "offset": 21,
  "judgment": "무겁지만 많은 철판과 레일을 얻는 대신, 화차 틈이 좁은 길목이라 짐 실은 썰매가 틈에서 막히고 서쪽 철판 마당이 늘 열려 있어 작업조가 드러난다.",
  "zones": [
    [
      "I",
      "서쪽 철판 마당",
      [
        0,
        0,
        22,
        46
      ]
    ],
    [
      "J",
      "가운데 철재 선별",
      [
        22,
        0,
        94,
        46
      ]
    ],
    [
      "K",
      "동쪽 철판 가공",
      [
        116,
        0,
        54,
        46
      ]
    ]
  ],
  "floors": [
    [
      0,
      0,
      0,
      170,
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
      54,
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
      0,
      170,
      4,
      1
    ],
    [
      0,
      0,
      14,
      88,
      4,
      1
    ],
    [
      0,
      44,
      4,
      4,
      10,
      1
    ],
    [
      0,
      44,
      18,
      6,
      25,
      1
    ],
    [
      0,
      74,
      18,
      5,
      25,
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
      42,
      74,
      4,
      1
    ],
    [
      0,
      153,
      4,
      5,
      4,
      7
    ]
  ],
  "buildings": [
    {
      "id": 21,
      "name": "철재 사무소",
      "rect": [
        24,
        8,
        20,
        6
      ],
      "warm": false,
      "window_broken": false
    },
    {
      "id": 22,
      "name": "철재 선별 창고",
      "rect": [
        48,
        4,
        40,
        10
      ],
      "warm": false,
      "window_broken": false
    },
    {
      "id": 23,
      "name": "철재 계량소",
      "rect": [
        6,
        6,
        8,
        6
      ],
      "warm": false,
      "window_broken": false
    },
    {
      "id": 24,
      "name": "수선 헛간",
      "rect": [
        88,
        12,
        28,
        12
      ],
      "warm": false,
      "window_broken": false
    },
    {
      "id": 25,
      "name": "레일 보관 창고",
      "rect": [
        118,
        6,
        20,
        9
      ],
      "warm": false,
      "window_broken": false
    },
    {
      "id": 26,
      "name": "동력실",
      "rect": [
        140,
        14,
        10,
        8
      ],
      "warm": false,
      "window_broken": false
    },
    {
      "id": 27,
      "name": "철판 보관 헛간",
      "rect": [
        150,
        8,
        18,
        10
      ],
      "warm": false,
      "window_broken": false
    },
    {
      "id": 28,
      "name": "철판 가공장",
      "rect": [
        116,
        24,
        22,
        18
      ],
      "warm": false,
      "window_broken": false
    }
  ],
  "shells": [
    [
      21,
      0,
      24,
      8,
      20,
      6
    ],
    [
      22,
      -1,
      48,
      4,
      40,
      10
    ],
    [
      22,
      0,
      48,
      4,
      40,
      10
    ],
    [
      22,
      1,
      48,
      4,
      40,
      10
    ],
    [
      22,
      2,
      48,
      4,
      40,
      10
    ],
    [
      23,
      0,
      6,
      6,
      8,
      6
    ],
    [
      24,
      0,
      88,
      12,
      28,
      12
    ],
    [
      24,
      1,
      88,
      12,
      28,
      12
    ],
    [
      25,
      0,
      118,
      6,
      20,
      9
    ],
    [
      26,
      0,
      140,
      14,
      10,
      8
    ],
    [
      27,
      -1,
      150,
      8,
      18,
      10
    ],
    [
      27,
      0,
      150,
      8,
      18,
      10
    ],
    [
      28,
      0,
      116,
      24,
      22,
      18
    ],
    [
      28,
      1,
      116,
      24,
      22,
      18
    ]
  ],
  "walls": [
    [
      0,
      34,
      9,
      1,
      4
    ],
    [
      -1,
      49,
      7,
      38,
      1
    ],
    [
      -1,
      54,
      8,
      1,
      5
    ],
    [
      -1,
      61,
      8,
      1,
      5
    ],
    [
      -1,
      67,
      8,
      1,
      5
    ],
    [
      -1,
      74,
      8,
      1,
      5
    ],
    [
      -1,
      80,
      8,
      1,
      5
    ],
    [
      0,
      49,
      7,
      38,
      1
    ],
    [
      0,
      54,
      8,
      1,
      5
    ],
    [
      0,
      61,
      8,
      1,
      5
    ],
    [
      0,
      67,
      8,
      1,
      5
    ],
    [
      0,
      74,
      8,
      1,
      5
    ],
    [
      0,
      80,
      8,
      1,
      5
    ],
    [
      1,
      49,
      7,
      38,
      1
    ],
    [
      1,
      54,
      8,
      1,
      5
    ],
    [
      1,
      61,
      8,
      1,
      5
    ],
    [
      1,
      67,
      8,
      1,
      5
    ],
    [
      1,
      74,
      8,
      1,
      5
    ],
    [
      1,
      80,
      8,
      1,
      5
    ],
    [
      2,
      49,
      7,
      38,
      1
    ],
    [
      2,
      54,
      8,
      1,
      5
    ],
    [
      2,
      61,
      8,
      1,
      5
    ],
    [
      2,
      67,
      8,
      1,
      5
    ],
    [
      2,
      74,
      8,
      1,
      5
    ],
    [
      2,
      80,
      8,
      1,
      5
    ],
    [
      0,
      102,
      13,
      1,
      10
    ],
    [
      1,
      102,
      13,
      1,
      10
    ],
    [
      0,
      128,
      7,
      1,
      7
    ],
    [
      -1,
      151,
      11,
      16,
      1
    ],
    [
      -1,
      158,
      12,
      1,
      5
    ],
    [
      0,
      159,
      9,
      1,
      8
    ],
    [
      0,
      117,
      27,
      20,
      1
    ],
    [
      0,
      126,
      28,
      1,
      13
    ],
    [
      1,
      117,
      27,
      20,
      1
    ],
    [
      1,
      126,
      28,
      1,
      13
    ]
  ],
  "openings": [
    [
      -1,
      50,
      5,
      1,
      2
    ],
    [
      0,
      50,
      5,
      1,
      2
    ],
    [
      0,
      50,
      5,
      1,
      2
    ],
    [
      1,
      50,
      5,
      1,
      2
    ],
    [
      1,
      50,
      5,
      1,
      2
    ],
    [
      2,
      50,
      5,
      1,
      2
    ],
    [
      -1,
      85,
      5,
      1,
      2
    ],
    [
      0,
      85,
      5,
      1,
      2
    ],
    [
      0,
      85,
      5,
      1,
      2
    ],
    [
      1,
      85,
      5,
      1,
      2
    ],
    [
      1,
      85,
      5,
      1,
      2
    ],
    [
      2,
      85,
      5,
      1,
      2
    ],
    [
      0,
      90,
      18,
      1,
      2
    ],
    [
      1,
      90,
      18,
      1,
      2
    ],
    [
      -1,
      152,
      9,
      1,
      6
    ],
    [
      0,
      152,
      13,
      1,
      2
    ],
    [
      0,
      118,
      25,
      1,
      2
    ],
    [
      1,
      118,
      25,
      1,
      2
    ],
    [
      0,
      135,
      25,
      1,
      2
    ],
    [
      1,
      135,
      25,
      1,
      2
    ]
  ],
  "doors": [
    [
      0,
      34,
      11,
      21,
      "closed",
      1,
      0
    ],
    [
      0,
      29,
      8,
      21,
      "closed",
      0,
      1
    ],
    [
      -1,
      51,
      7,
      22,
      "closed",
      0,
      1
    ],
    [
      -1,
      58,
      7,
      22,
      "closed",
      0,
      1
    ],
    [
      -1,
      64,
      7,
      22,
      "closed",
      0,
      1
    ],
    [
      -1,
      71,
      7,
      22,
      "closed",
      0,
      1
    ],
    [
      -1,
      77,
      7,
      22,
      "closed",
      0,
      1
    ],
    [
      -1,
      84,
      7,
      22,
      "closed",
      0,
      1
    ],
    [
      0,
      51,
      7,
      22,
      "closed",
      0,
      1
    ],
    [
      0,
      58,
      7,
      22,
      "closed",
      0,
      1
    ],
    [
      0,
      64,
      7,
      22,
      "closed",
      0,
      1
    ],
    [
      0,
      71,
      7,
      22,
      "closed",
      0,
      1
    ],
    [
      0,
      77,
      7,
      22,
      "closed",
      0,
      1
    ],
    [
      0,
      84,
      7,
      22,
      "closed",
      0,
      1
    ],
    [
      1,
      51,
      7,
      22,
      "closed",
      0,
      1
    ],
    [
      1,
      58,
      7,
      22,
      "closed",
      0,
      1
    ],
    [
      1,
      64,
      7,
      22,
      "closed",
      0,
      1
    ],
    [
      1,
      71,
      7,
      22,
      "closed",
      0,
      1
    ],
    [
      1,
      77,
      7,
      22,
      "closed",
      0,
      1
    ],
    [
      1,
      84,
      7,
      22,
      "closed",
      0,
      1
    ],
    [
      2,
      51,
      7,
      22,
      "closed",
      0,
      1
    ],
    [
      2,
      58,
      7,
      22,
      "closed",
      0,
      1
    ],
    [
      2,
      64,
      7,
      22,
      "closed",
      0,
      1
    ],
    [
      2,
      71,
      7,
      22,
      "closed",
      0,
      1
    ],
    [
      2,
      77,
      7,
      22,
      "closed",
      0,
      1
    ],
    [
      2,
      84,
      7,
      22,
      "closed",
      0,
      1
    ],
    [
      0,
      84,
      13,
      22,
      "closed",
      0,
      1
    ],
    [
      0,
      13,
      9,
      23,
      "closed",
      1,
      0
    ],
    [
      0,
      102,
      18,
      24,
      "closed",
      1,
      0
    ],
    [
      1,
      102,
      18,
      24,
      "closed",
      1,
      0
    ],
    [
      0,
      95,
      12,
      24,
      "closed",
      0,
      1
    ],
    [
      0,
      128,
      10,
      25,
      "closed",
      1,
      0
    ],
    [
      0,
      123,
      6,
      25,
      "closed",
      0,
      1
    ],
    [
      0,
      145,
      14,
      26,
      "closed",
      0,
      1
    ],
    [
      -1,
      154,
      11,
      27,
      "closed",
      0,
      1
    ],
    [
      -1,
      163,
      11,
      27,
      "closed",
      0,
      1
    ],
    [
      0,
      159,
      13,
      27,
      "closed",
      1,
      0
    ],
    [
      0,
      155,
      8,
      27,
      "closed",
      0,
      1
    ],
    [
      0,
      121,
      27,
      28,
      "closed",
      0,
      1
    ],
    [
      0,
      132,
      27,
      28,
      "closed",
      0,
      1
    ],
    [
      1,
      121,
      27,
      28,
      "closed",
      0,
      1
    ],
    [
      1,
      132,
      27,
      28,
      "closed",
      0,
      1
    ],
    [
      0,
      137,
      25,
      28,
      "closed",
      1,
      0
    ]
  ],
  "windows": [
    [
      0,
      27,
      8,
      21
    ],
    [
      0,
      34,
      8,
      21
    ],
    [
      0,
      41,
      8,
      21
    ],
    [
      0,
      43,
      11,
      21
    ],
    [
      0,
      51,
      4,
      22
    ],
    [
      0,
      58,
      4,
      22
    ],
    [
      0,
      65,
      4,
      22
    ],
    [
      0,
      72,
      4,
      22
    ],
    [
      0,
      79,
      4,
      22
    ],
    [
      0,
      87,
      7,
      22
    ],
    [
      1,
      51,
      4,
      22
    ],
    [
      1,
      58,
      4,
      22
    ],
    [
      1,
      65,
      4,
      22
    ],
    [
      1,
      72,
      4,
      22
    ],
    [
      1,
      79,
      4,
      22
    ],
    [
      1,
      87,
      7,
      22
    ],
    [
      2,
      51,
      4,
      22
    ],
    [
      2,
      58,
      4,
      22
    ],
    [
      2,
      65,
      4,
      22
    ],
    [
      2,
      72,
      4,
      22
    ],
    [
      2,
      79,
      4,
      22
    ],
    [
      2,
      87,
      7,
      22
    ],
    [
      0,
      9,
      6,
      23
    ],
    [
      0,
      13,
      9,
      23
    ],
    [
      0,
      91,
      12,
      24
    ],
    [
      0,
      98,
      12,
      24
    ],
    [
      0,
      105,
      12,
      24
    ],
    [
      0,
      112,
      12,
      24
    ],
    [
      0,
      115,
      15,
      24
    ],
    [
      0,
      115,
      20,
      24
    ],
    [
      1,
      91,
      12,
      24
    ],
    [
      1,
      98,
      12,
      24
    ],
    [
      1,
      105,
      12,
      24
    ],
    [
      1,
      112,
      12,
      24
    ],
    [
      1,
      115,
      15,
      24
    ],
    [
      1,
      115,
      20,
      24
    ],
    [
      0,
      121,
      6,
      25
    ],
    [
      0,
      128,
      6,
      25
    ],
    [
      0,
      135,
      6,
      25
    ],
    [
      0,
      137,
      9,
      25
    ],
    [
      0,
      143,
      14,
      26
    ],
    [
      0,
      149,
      17,
      26
    ],
    [
      0,
      153,
      8,
      27
    ],
    [
      0,
      160,
      8,
      27
    ],
    [
      0,
      167,
      11,
      27
    ],
    [
      0,
      119,
      24,
      28
    ],
    [
      0,
      126,
      24,
      28
    ],
    [
      0,
      133,
      24,
      28
    ],
    [
      0,
      137,
      27,
      28
    ],
    [
      0,
      137,
      32,
      28
    ],
    [
      0,
      137,
      37,
      28
    ],
    [
      1,
      119,
      24,
      28
    ],
    [
      1,
      126,
      24,
      28
    ],
    [
      1,
      133,
      24,
      28
    ],
    [
      1,
      137,
      27,
      28
    ],
    [
      1,
      137,
      32,
      28
    ],
    [
      1,
      137,
      37,
      28
    ]
  ],
  "rooms": [
    {
      "building": 21,
      "level": 0,
      "rect": [
        25,
        9,
        9,
        4
      ],
      "name": "앞 작업 칸"
    },
    {
      "building": 21,
      "level": 0,
      "rect": [
        35,
        9,
        8,
        4
      ],
      "name": "안쪽 보관실"
    },
    {
      "building": 22,
      "level": -1,
      "rect": [
        49,
        8,
        5,
        5
      ],
      "name": "철재 앞 저장고"
    },
    {
      "building": 22,
      "level": -1,
      "rect": [
        55,
        8,
        6,
        5
      ],
      "name": "철재 안쪽 보관실"
    },
    {
      "building": 22,
      "level": -1,
      "rect": [
        62,
        8,
        5,
        5
      ],
      "name": "철재 앞 저장고"
    },
    {
      "building": 22,
      "level": -1,
      "rect": [
        68,
        8,
        6,
        5
      ],
      "name": "철재 안쪽 보관실"
    },
    {
      "building": 22,
      "level": -1,
      "rect": [
        75,
        8,
        5,
        5
      ],
      "name": "철재 앞 저장고"
    },
    {
      "building": 22,
      "level": -1,
      "rect": [
        81,
        8,
        6,
        5
      ],
      "name": "철재 안쪽 보관실"
    },
    {
      "building": 22,
      "level": 0,
      "rect": [
        49,
        8,
        5,
        5
      ],
      "name": "선별실"
    },
    {
      "building": 22,
      "level": 0,
      "rect": [
        55,
        8,
        6,
        5
      ],
      "name": "계량실"
    },
    {
      "building": 22,
      "level": 0,
      "rect": [
        62,
        8,
        5,
        5
      ],
      "name": "사무 칸"
    },
    {
      "building": 22,
      "level": 0,
      "rect": [
        68,
        8,
        6,
        5
      ],
      "name": "원료 칸"
    },
    {
      "building": 22,
      "level": 0,
      "rect": [
        75,
        8,
        5,
        5
      ],
      "name": "공구 칸"
    },
    {
      "building": 22,
      "level": 0,
      "rect": [
        81,
        8,
        6,
        5
      ],
      "name": "안쪽 보관실"
    },
    {
      "building": 22,
      "level": 1,
      "rect": [
        49,
        8,
        5,
        5
      ],
      "name": "선별실"
    },
    {
      "building": 22,
      "level": 1,
      "rect": [
        55,
        8,
        6,
        5
      ],
      "name": "계량실"
    },
    {
      "building": 22,
      "level": 1,
      "rect": [
        62,
        8,
        5,
        5
      ],
      "name": "사무 칸"
    },
    {
      "building": 22,
      "level": 1,
      "rect": [
        68,
        8,
        6,
        5
      ],
      "name": "원료 칸"
    },
    {
      "building": 22,
      "level": 1,
      "rect": [
        75,
        8,
        5,
        5
      ],
      "name": "공구 칸"
    },
    {
      "building": 22,
      "level": 1,
      "rect": [
        81,
        8,
        6,
        5
      ],
      "name": "안쪽 보관실"
    },
    {
      "building": 22,
      "level": 2,
      "rect": [
        49,
        8,
        5,
        5
      ],
      "name": "선별실"
    },
    {
      "building": 22,
      "level": 2,
      "rect": [
        55,
        8,
        6,
        5
      ],
      "name": "계량실"
    },
    {
      "building": 22,
      "level": 2,
      "rect": [
        62,
        8,
        5,
        5
      ],
      "name": "사무 칸"
    },
    {
      "building": 22,
      "level": 2,
      "rect": [
        68,
        8,
        6,
        5
      ],
      "name": "원료 칸"
    },
    {
      "building": 22,
      "level": 2,
      "rect": [
        75,
        8,
        5,
        5
      ],
      "name": "공구 칸"
    },
    {
      "building": 22,
      "level": 2,
      "rect": [
        81,
        8,
        6,
        5
      ],
      "name": "안쪽 보관실"
    },
    {
      "building": 23,
      "level": 0,
      "rect": [
        7,
        7,
        6,
        4
      ],
      "name": "작업 칸"
    },
    {
      "building": 24,
      "level": 0,
      "rect": [
        89,
        13,
        13,
        10
      ],
      "name": "앞 작업 칸"
    },
    {
      "building": 24,
      "level": 0,
      "rect": [
        103,
        13,
        12,
        10
      ],
      "name": "안쪽 보관실"
    },
    {
      "building": 24,
      "level": 1,
      "rect": [
        89,
        13,
        13,
        10
      ],
      "name": "앞 작업 칸"
    },
    {
      "building": 24,
      "level": 1,
      "rect": [
        103,
        13,
        12,
        10
      ],
      "name": "안쪽 보관실"
    },
    {
      "building": 25,
      "level": 0,
      "rect": [
        119,
        7,
        9,
        7
      ],
      "name": "앞 작업 칸"
    },
    {
      "building": 25,
      "level": 0,
      "rect": [
        129,
        7,
        8,
        7
      ],
      "name": "안쪽 보관실"
    },
    {
      "building": 26,
      "level": 0,
      "rect": [
        141,
        15,
        8,
        6
      ],
      "name": "작업 칸"
    },
    {
      "building": 27,
      "level": -1,
      "rect": [
        151,
        12,
        7,
        5
      ],
      "name": "철재 앞 저장고"
    },
    {
      "building": 27,
      "level": -1,
      "rect": [
        159,
        12,
        8,
        5
      ],
      "name": "철재 안쪽 보관실"
    },
    {
      "building": 27,
      "level": 0,
      "rect": [
        151,
        9,
        8,
        8
      ],
      "name": "앞 작업 칸"
    },
    {
      "building": 27,
      "level": 0,
      "rect": [
        160,
        9,
        7,
        8
      ],
      "name": "안쪽 보관실"
    },
    {
      "building": 28,
      "level": 0,
      "rect": [
        117,
        28,
        9,
        13
      ],
      "name": "선별실"
    },
    {
      "building": 28,
      "level": 0,
      "rect": [
        127,
        28,
        10,
        13
      ],
      "name": "계량실"
    },
    {
      "building": 28,
      "level": 1,
      "rect": [
        117,
        28,
        9,
        13
      ],
      "name": "선별실"
    },
    {
      "building": 28,
      "level": 1,
      "rect": [
        127,
        28,
        10,
        13
      ],
      "name": "계량실"
    }
  ],
  "stairs": [
    {
      "cell": [
        50,
        5
      ],
      "low": -1,
      "high": 0,
      "ladder": false
    },
    {
      "cell": [
        50,
        5
      ],
      "low": 0,
      "high": 1,
      "ladder": false
    },
    {
      "cell": [
        50,
        5
      ],
      "low": 1,
      "high": 2,
      "ladder": false
    },
    {
      "cell": [
        85,
        6
      ],
      "low": -1,
      "high": 0,
      "ladder": false
    },
    {
      "cell": [
        85,
        6
      ],
      "low": 0,
      "high": 1,
      "ladder": false
    },
    {
      "cell": [
        85,
        6
      ],
      "low": 1,
      "high": 2,
      "ladder": false
    },
    {
      "cell": [
        90,
        18
      ],
      "low": 0,
      "high": 1,
      "ladder": false
    },
    {
      "cell": [
        152,
        13
      ],
      "low": -1,
      "high": 0,
      "ladder": false
    },
    {
      "cell": [
        118,
        25
      ],
      "low": 0,
      "high": 1,
      "ladder": false
    },
    {
      "cell": [
        135,
        26
      ],
      "low": 0,
      "high": 1,
      "ladder": false
    }
  ],
  "props": [
    {
      "kind": "rail_pile",
      "rect": [
        48,
        37,
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
        64,
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
      "kind": "plate_stack",
      "rect": [
        82,
        33,
        3,
        2
      ],
      "solid": "low",
      "facing": 0,
      "note": "철판 더미",
      "level": 0
    },
    {
      "kind": "rail_pile",
      "rect": [
        100,
        41,
        6,
        1
      ],
      "solid": "low",
      "facing": 0,
      "note": "레일 더미",
      "level": 0
    },
    {
      "kind": "flat_wagon",
      "rect": [
        20,
        19,
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
        32,
        19,
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
        50,
        19,
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
        62,
        19,
        12,
        3
      ],
      "solid": "wagon",
      "facing": 0,
      "note": "문 열린 평판 화차",
      "level": 0
    },
    {
      "kind": "plate_stack",
      "rect": [
        79,
        20,
        3,
        2
      ],
      "solid": "low",
      "facing": 0,
      "note": "철판 더미",
      "level": 0
    },
    {
      "kind": "plate_stack",
      "rect": [
        82,
        20,
        3,
        2
      ],
      "solid": "low",
      "facing": 0,
      "note": "철판 더미",
      "level": 0
    },
    {
      "kind": "plate_stack",
      "rect": [
        85,
        20,
        3,
        2
      ],
      "solid": "low",
      "facing": 0,
      "note": "철판 더미",
      "level": 0
    },
    {
      "kind": "bare_tree",
      "rect": [
        2,
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
        20,
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
        14,
        5,
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
        17,
        9,
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
        12,
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
        20,
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
        154,
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
        162,
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
        168,
        20,
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
        26,
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
        165,
        25,
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
        8,
        12,
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
        25,
        9,
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
        30,
        9,
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
        32,
        9,
        2,
        1
      ],
      "solid": "low",
      "facing": 0,
      "note": "앞 작업 칸 곁 서류함",
      "level": 0
    },
    {
      "kind": "plate_stack",
      "rect": [
        35,
        9,
        3,
        2
      ],
      "solid": "low",
      "facing": 0,
      "note": "안쪽 보관실 곁 철판 더미",
      "level": 0
    },
    {
      "kind": "pallet_stack",
      "rect": [
        38,
        9,
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
        40,
        9,
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
        49,
        8,
        2,
        1
      ],
      "solid": "none",
      "facing": 0,
      "note": "철재 앞 저장고 곁 공구 수레",
      "level": -1
    },
    {
      "kind": "part_crate",
      "rect": [
        52,
        8,
        1,
        1
      ],
      "solid": "none",
      "facing": 0,
      "note": "철재 앞 저장고 곁 부품 상자",
      "level": -1
    },
    {
      "kind": "coupler_set",
      "rect": [
        53,
        8,
        1,
        1
      ],
      "solid": "none",
      "facing": 0,
      "note": "철재 앞 저장고 곁 연결기 한 벌",
      "level": -1
    },
    {
      "kind": "sack_pile",
      "rect": [
        55,
        8,
        2,
        2
      ],
      "solid": "none",
      "facing": 0,
      "note": "철재 안쪽 보관실 곁 자루 더미",
      "level": -1
    },
    {
      "kind": "handcart",
      "rect": [
        59,
        8,
        2,
        1
      ],
      "solid": "none",
      "facing": 0,
      "note": "철재 안쪽 보관실 곁 손수레",
      "level": -1
    },
    {
      "kind": "barrel",
      "rect": [
        57,
        8,
        1,
        1
      ],
      "solid": "none",
      "facing": 0,
      "note": "철재 안쪽 보관실 곁 통",
      "level": -1
    },
    {
      "kind": "shelf",
      "rect": [
        62,
        11,
        3,
        1
      ],
      "solid": "none",
      "facing": 0,
      "note": "철재 앞 저장고 곁 선반",
      "level": -1
    },
    {
      "kind": "crate_stack",
      "rect": [
        62,
        8,
        2,
        2
      ],
      "solid": "none",
      "facing": 0,
      "note": "철재 앞 저장고 곁 나무 상자 더미",
      "level": -1
    },
    {
      "kind": "rope_coil",
      "rect": [
        65,
        8,
        1,
        1
      ],
      "solid": "none",
      "facing": 0,
      "note": "철재 앞 저장고 곁 밧줄 더미",
      "level": -1
    },
    {
      "kind": "plate_stack",
      "rect": [
        68,
        8,
        3,
        2
      ],
      "solid": "none",
      "facing": 0,
      "note": "철재 안쪽 보관실 곁 철판 더미",
      "level": -1
    },
    {
      "kind": "part_crate",
      "rect": [
        72,
        8,
        1,
        1
      ],
      "solid": "none",
      "facing": 0,
      "note": "철재 안쪽 보관실 곁 부품 상자",
      "level": -1
    },
    {
      "kind": "barrel",
      "rect": [
        73,
        8,
        1,
        1
      ],
      "solid": "none",
      "facing": 0,
      "note": "철재 안쪽 보관실 곁 통",
      "level": -1
    },
    {
      "kind": "shelf",
      "rect": [
        75,
        11,
        3,
        1
      ],
      "solid": "none",
      "facing": 0,
      "note": "철재 앞 저장고 곁 선반",
      "level": -1
    },
    {
      "kind": "desk",
      "rect": [
        75,
        8,
        2,
        1
      ],
      "solid": "none",
      "facing": 0,
      "note": "철재 앞 저장고 곁 책상",
      "level": -1
    },
    {
      "kind": "file_cabinet",
      "rect": [
        78,
        8,
        2,
        1
      ],
      "solid": "none",
      "facing": 0,
      "note": "철재 앞 저장고 곁 서류함",
      "level": -1
    },
    {
      "kind": "plate_stack",
      "rect": [
        81,
        8,
        3,
        2
      ],
      "solid": "none",
      "facing": 0,
      "note": "철재 안쪽 보관실 곁 철판 더미",
      "level": -1
    },
    {
      "kind": "pallet_stack",
      "rect": [
        85,
        8,
        2,
        2
      ],
      "solid": "none",
      "facing": 0,
      "note": "철재 안쪽 보관실 곁 팰릿 더미",
      "level": -1
    },
    {
      "kind": "barrel",
      "rect": [
        81,
        10,
        1,
        1
      ],
      "solid": "none",
      "facing": 0,
      "note": "철재 안쪽 보관실 곁 통",
      "level": -1
    },
    {
      "kind": "tool_cart",
      "rect": [
        49,
        8,
        2,
        1
      ],
      "solid": "low",
      "facing": 0,
      "note": "선별실 곁 공구 수레",
      "level": 0
    },
    {
      "kind": "part_crate",
      "rect": [
        52,
        8,
        1,
        1
      ],
      "solid": "low",
      "facing": 0,
      "note": "선별실 곁 부품 상자",
      "level": 0
    },
    {
      "kind": "coupler_set",
      "rect": [
        53,
        8,
        1,
        1
      ],
      "solid": "low",
      "facing": 0,
      "note": "선별실 곁 연결기 한 벌",
      "level": 0
    },
    {
      "kind": "sack_pile",
      "rect": [
        55,
        8,
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
        59,
        8,
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
        57,
        8,
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
        62,
        11,
        3,
        1
      ],
      "solid": "low",
      "facing": 0,
      "note": "사무 칸 곁 선반",
      "level": 0
    },
    {
      "kind": "crate_stack",
      "rect": [
        62,
        8,
        2,
        2
      ],
      "solid": "low",
      "facing": 0,
      "note": "사무 칸 곁 나무 상자 더미",
      "level": 0
    },
    {
      "kind": "rope_coil",
      "rect": [
        65,
        8,
        1,
        1
      ],
      "solid": "low",
      "facing": 0,
      "note": "사무 칸 곁 밧줄 더미",
      "level": 0
    },
    {
      "kind": "plate_stack",
      "rect": [
        68,
        8,
        3,
        2
      ],
      "solid": "low",
      "facing": 0,
      "note": "원료 칸 곁 철판 더미",
      "level": 0
    },
    {
      "kind": "part_crate",
      "rect": [
        72,
        8,
        1,
        1
      ],
      "solid": "low",
      "facing": 0,
      "note": "원료 칸 곁 부품 상자",
      "level": 0
    },
    {
      "kind": "barrel",
      "rect": [
        73,
        8,
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
        75,
        11,
        3,
        1
      ],
      "solid": "low",
      "facing": 0,
      "note": "공구 칸 곁 선반",
      "level": 0
    },
    {
      "kind": "desk",
      "rect": [
        75,
        8,
        2,
        1
      ],
      "solid": "low",
      "facing": 0,
      "note": "공구 칸 곁 책상",
      "level": 0
    },
    {
      "kind": "file_cabinet",
      "rect": [
        78,
        8,
        2,
        1
      ],
      "solid": "low",
      "facing": 0,
      "note": "공구 칸 곁 서류함",
      "level": 0
    },
    {
      "kind": "plate_stack",
      "rect": [
        81,
        8,
        3,
        2
      ],
      "solid": "low",
      "facing": 0,
      "note": "안쪽 보관실 곁 철판 더미",
      "level": 0
    },
    {
      "kind": "pallet_stack",
      "rect": [
        85,
        8,
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
        81,
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
      "kind": "tool_cart",
      "rect": [
        49,
        8,
        2,
        1
      ],
      "solid": "none",
      "facing": 0,
      "note": "선별실 곁 공구 수레",
      "level": 1
    },
    {
      "kind": "part_crate",
      "rect": [
        52,
        8,
        1,
        1
      ],
      "solid": "none",
      "facing": 0,
      "note": "선별실 곁 부품 상자",
      "level": 1
    },
    {
      "kind": "coupler_set",
      "rect": [
        53,
        8,
        1,
        1
      ],
      "solid": "none",
      "facing": 0,
      "note": "선별실 곁 연결기 한 벌",
      "level": 1
    },
    {
      "kind": "sack_pile",
      "rect": [
        55,
        8,
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
        59,
        8,
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
        57,
        8,
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
        62,
        11,
        3,
        1
      ],
      "solid": "none",
      "facing": 0,
      "note": "사무 칸 곁 선반",
      "level": 1
    },
    {
      "kind": "crate_stack",
      "rect": [
        62,
        8,
        2,
        2
      ],
      "solid": "none",
      "facing": 0,
      "note": "사무 칸 곁 나무 상자 더미",
      "level": 1
    },
    {
      "kind": "rope_coil",
      "rect": [
        65,
        8,
        1,
        1
      ],
      "solid": "none",
      "facing": 0,
      "note": "사무 칸 곁 밧줄 더미",
      "level": 1
    },
    {
      "kind": "plate_stack",
      "rect": [
        68,
        8,
        3,
        2
      ],
      "solid": "none",
      "facing": 0,
      "note": "원료 칸 곁 철판 더미",
      "level": 1
    },
    {
      "kind": "part_crate",
      "rect": [
        72,
        8,
        1,
        1
      ],
      "solid": "none",
      "facing": 0,
      "note": "원료 칸 곁 부품 상자",
      "level": 1
    },
    {
      "kind": "barrel",
      "rect": [
        73,
        8,
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
        75,
        11,
        3,
        1
      ],
      "solid": "none",
      "facing": 0,
      "note": "공구 칸 곁 선반",
      "level": 1
    },
    {
      "kind": "desk",
      "rect": [
        75,
        8,
        2,
        1
      ],
      "solid": "none",
      "facing": 0,
      "note": "공구 칸 곁 책상",
      "level": 1
    },
    {
      "kind": "file_cabinet",
      "rect": [
        78,
        8,
        2,
        1
      ],
      "solid": "none",
      "facing": 0,
      "note": "공구 칸 곁 서류함",
      "level": 1
    },
    {
      "kind": "plate_stack",
      "rect": [
        81,
        8,
        3,
        2
      ],
      "solid": "none",
      "facing": 0,
      "note": "안쪽 보관실 곁 철판 더미",
      "level": 1
    },
    {
      "kind": "pallet_stack",
      "rect": [
        85,
        8,
        2,
        2
      ],
      "solid": "none",
      "facing": 0,
      "note": "안쪽 보관실 곁 팰릿 더미",
      "level": 1
    },
    {
      "kind": "barrel",
      "rect": [
        81,
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
      "kind": "tool_cart",
      "rect": [
        49,
        8,
        2,
        1
      ],
      "solid": "none",
      "facing": 0,
      "note": "선별실 곁 공구 수레",
      "level": 2
    },
    {
      "kind": "part_crate",
      "rect": [
        52,
        8,
        1,
        1
      ],
      "solid": "none",
      "facing": 0,
      "note": "선별실 곁 부품 상자",
      "level": 2
    },
    {
      "kind": "coupler_set",
      "rect": [
        53,
        8,
        1,
        1
      ],
      "solid": "none",
      "facing": 0,
      "note": "선별실 곁 연결기 한 벌",
      "level": 2
    },
    {
      "kind": "sack_pile",
      "rect": [
        55,
        8,
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
        59,
        8,
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
        57,
        8,
        1,
        1
      ],
      "solid": "none",
      "facing": 0,
      "note": "계량실 곁 통",
      "level": 2
    },
    {
      "kind": "shelf",
      "rect": [
        62,
        11,
        3,
        1
      ],
      "solid": "none",
      "facing": 0,
      "note": "사무 칸 곁 선반",
      "level": 2
    },
    {
      "kind": "crate_stack",
      "rect": [
        62,
        8,
        2,
        2
      ],
      "solid": "none",
      "facing": 0,
      "note": "사무 칸 곁 나무 상자 더미",
      "level": 2
    },
    {
      "kind": "rope_coil",
      "rect": [
        65,
        8,
        1,
        1
      ],
      "solid": "none",
      "facing": 0,
      "note": "사무 칸 곁 밧줄 더미",
      "level": 2
    },
    {
      "kind": "plate_stack",
      "rect": [
        68,
        8,
        3,
        2
      ],
      "solid": "none",
      "facing": 0,
      "note": "원료 칸 곁 철판 더미",
      "level": 2
    },
    {
      "kind": "part_crate",
      "rect": [
        72,
        8,
        1,
        1
      ],
      "solid": "none",
      "facing": 0,
      "note": "원료 칸 곁 부품 상자",
      "level": 2
    },
    {
      "kind": "barrel",
      "rect": [
        73,
        8,
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
        75,
        11,
        3,
        1
      ],
      "solid": "none",
      "facing": 0,
      "note": "공구 칸 곁 선반",
      "level": 2
    },
    {
      "kind": "desk",
      "rect": [
        75,
        8,
        2,
        1
      ],
      "solid": "none",
      "facing": 0,
      "note": "공구 칸 곁 책상",
      "level": 2
    },
    {
      "kind": "file_cabinet",
      "rect": [
        78,
        8,
        2,
        1
      ],
      "solid": "none",
      "facing": 0,
      "note": "공구 칸 곁 서류함",
      "level": 2
    },
    {
      "kind": "plate_stack",
      "rect": [
        81,
        8,
        3,
        2
      ],
      "solid": "none",
      "facing": 0,
      "note": "안쪽 보관실 곁 철판 더미",
      "level": 2
    },
    {
      "kind": "pallet_stack",
      "rect": [
        85,
        8,
        2,
        2
      ],
      "solid": "none",
      "facing": 0,
      "note": "안쪽 보관실 곁 팰릿 더미",
      "level": 2
    },
    {
      "kind": "barrel",
      "rect": [
        81,
        10,
        1,
        1
      ],
      "solid": "none",
      "facing": 0,
      "note": "안쪽 보관실 곁 통",
      "level": 2
    },
    {
      "kind": "tool_cart",
      "rect": [
        7,
        7,
        2,
        1
      ],
      "solid": "low",
      "facing": 0,
      "note": "작업 칸 곁 공구 수레",
      "level": 0
    },
    {
      "kind": "part_crate",
      "rect": [
        9,
        7,
        1,
        1
      ],
      "solid": "low",
      "facing": 0,
      "note": "작업 칸 곁 부품 상자",
      "level": 0
    },
    {
      "kind": "coupler_set",
      "rect": [
        10,
        7,
        1,
        1
      ],
      "solid": "low",
      "facing": 0,
      "note": "작업 칸 곁 연결기 한 벌",
      "level": 0
    },
    {
      "kind": "sack_pile",
      "rect": [
        89,
        13,
        2,
        2
      ],
      "solid": "low",
      "facing": 0,
      "note": "앞 작업 칸 곁 자루 더미",
      "level": 0
    },
    {
      "kind": "handcart",
      "rect": [
        91,
        13,
        2,
        1
      ],
      "solid": "low",
      "facing": 0,
      "note": "앞 작업 칸 곁 손수레",
      "level": 0
    },
    {
      "kind": "barrel",
      "rect": [
        93,
        13,
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
        103,
        13,
        3,
        1
      ],
      "solid": "low",
      "facing": 0,
      "note": "안쪽 보관실 곁 선반",
      "level": 0
    },
    {
      "kind": "crate_stack",
      "rect": [
        106,
        13,
        2,
        2
      ],
      "solid": "low",
      "facing": 0,
      "note": "안쪽 보관실 곁 나무 상자 더미",
      "level": 0
    },
    {
      "kind": "rope_coil",
      "rect": [
        108,
        13,
        1,
        1
      ],
      "solid": "low",
      "facing": 0,
      "note": "안쪽 보관실 곁 밧줄 더미",
      "level": 0
    },
    {
      "kind": "plate_stack",
      "rect": [
        89,
        13,
        3,
        2
      ],
      "solid": "none",
      "facing": 0,
      "note": "앞 작업 칸 곁 철판 더미",
      "level": 1
    },
    {
      "kind": "part_crate",
      "rect": [
        92,
        13,
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
        93,
        13,
        1,
        1
      ],
      "solid": "none",
      "facing": 0,
      "note": "앞 작업 칸 곁 통",
      "level": 1
    },
    {
      "kind": "shelf",
      "rect": [
        103,
        13,
        3,
        1
      ],
      "solid": "none",
      "facing": 0,
      "note": "안쪽 보관실 곁 선반",
      "level": 1
    },
    {
      "kind": "desk",
      "rect": [
        106,
        13,
        2,
        1
      ],
      "solid": "none",
      "facing": 0,
      "note": "안쪽 보관실 곁 책상",
      "level": 1
    },
    {
      "kind": "file_cabinet",
      "rect": [
        108,
        13,
        2,
        1
      ],
      "solid": "none",
      "facing": 0,
      "note": "안쪽 보관실 곁 서류함",
      "level": 1
    },
    {
      "kind": "plate_stack",
      "rect": [
        119,
        7,
        3,
        2
      ],
      "solid": "low",
      "facing": 0,
      "note": "앞 작업 칸 곁 철판 더미",
      "level": 0
    },
    {
      "kind": "pallet_stack",
      "rect": [
        124,
        7,
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
        122,
        7,
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
        129,
        7,
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
        131,
        7,
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
        132,
        7,
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
        141,
        15,
        2,
        2
      ],
      "solid": "low",
      "facing": 0,
      "note": "작업 칸 곁 자루 더미",
      "level": 0
    },
    {
      "kind": "handcart",
      "rect": [
        143,
        15,
        2,
        1
      ],
      "solid": "low",
      "facing": 0,
      "note": "작업 칸 곁 손수레",
      "level": 0
    },
    {
      "kind": "barrel",
      "rect": [
        146,
        15,
        1,
        1
      ],
      "solid": "low",
      "facing": 0,
      "note": "작업 칸 곁 통",
      "level": 0
    },
    {
      "kind": "plate_stack",
      "rect": [
        155,
        12,
        3,
        2
      ],
      "solid": "none",
      "facing": 0,
      "note": "철재 앞 저장고 곁 철판 더미",
      "level": -1
    },
    {
      "kind": "part_crate",
      "rect": [
        151,
        12,
        1,
        1
      ],
      "solid": "none",
      "facing": 0,
      "note": "철재 앞 저장고 곁 부품 상자",
      "level": -1
    },
    {
      "kind": "barrel",
      "rect": [
        152,
        12,
        1,
        1
      ],
      "solid": "none",
      "facing": 0,
      "note": "철재 앞 저장고 곁 통",
      "level": -1
    },
    {
      "kind": "tool_cart",
      "rect": [
        151,
        14,
        2,
        1
      ],
      "solid": "none",
      "facing": 0,
      "note": "철재 앞 저장고 곁 공구 수레",
      "level": -1
    },
    {
      "kind": "plate_stack",
      "rect": [
        159,
        12,
        3,
        2
      ],
      "solid": "none",
      "facing": 0,
      "note": "철재 안쪽 보관실 곁 철판 더미",
      "level": -1
    },
    {
      "kind": "part_crate",
      "rect": [
        162,
        12,
        1,
        1
      ],
      "solid": "none",
      "facing": 0,
      "note": "철재 안쪽 보관실 곁 부품 상자",
      "level": -1
    },
    {
      "kind": "barrel",
      "rect": [
        164,
        12,
        1,
        1
      ],
      "solid": "none",
      "facing": 0,
      "note": "철재 안쪽 보관실 곁 통",
      "level": -1
    },
    {
      "kind": "tool_cart",
      "rect": [
        165,
        12,
        2,
        1
      ],
      "solid": "none",
      "facing": 0,
      "note": "철재 안쪽 보관실 곁 공구 수레",
      "level": -1
    },
    {
      "kind": "plate_stack",
      "rect": [
        151,
        9,
        3,
        2
      ],
      "solid": "low",
      "facing": 0,
      "note": "앞 작업 칸 곁 철판 더미",
      "level": 0
    },
    {
      "kind": "part_crate",
      "rect": [
        154,
        9,
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
        156,
        9,
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
        157,
        9,
        2,
        1
      ],
      "solid": "low",
      "facing": 0,
      "note": "앞 작업 칸 곁 공구 수레",
      "level": 0
    },
    {
      "kind": "plate_stack",
      "rect": [
        160,
        9,
        3,
        2
      ],
      "solid": "low",
      "facing": 0,
      "note": "안쪽 보관실 곁 철판 더미",
      "level": 0
    },
    {
      "kind": "part_crate",
      "rect": [
        163,
        9,
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
        164,
        9,
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
        165,
        9,
        2,
        1
      ],
      "solid": "low",
      "facing": 0,
      "note": "안쪽 보관실 곁 공구 수레",
      "level": 0
    },
    {
      "kind": "tool_cart",
      "rect": [
        117,
        28,
        2,
        1
      ],
      "solid": "low",
      "facing": 0,
      "note": "선별실 곁 공구 수레",
      "level": 0
    },
    {
      "kind": "part_crate",
      "rect": [
        119,
        28,
        1,
        1
      ],
      "solid": "low",
      "facing": 0,
      "note": "선별실 곁 부품 상자",
      "level": 0
    },
    {
      "kind": "coupler_set",
      "rect": [
        120,
        28,
        1,
        1
      ],
      "solid": "low",
      "facing": 0,
      "note": "선별실 곁 연결기 한 벌",
      "level": 0
    },
    {
      "kind": "sack_pile",
      "rect": [
        127,
        28,
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
        129,
        28,
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
        131,
        28,
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
        117,
        28,
        3,
        1
      ],
      "solid": "none",
      "facing": 0,
      "note": "선별실 곁 선반",
      "level": 1
    },
    {
      "kind": "crate_stack",
      "rect": [
        122,
        28,
        2,
        2
      ],
      "solid": "none",
      "facing": 0,
      "note": "선별실 곁 나무 상자 더미",
      "level": 1
    },
    {
      "kind": "rope_coil",
      "rect": [
        120,
        28,
        1,
        1
      ],
      "solid": "none",
      "facing": 0,
      "note": "선별실 곁 밧줄 더미",
      "level": 1
    },
    {
      "kind": "plate_stack",
      "rect": [
        127,
        28,
        3,
        2
      ],
      "solid": "none",
      "facing": 0,
      "note": "계량실 곁 철판 더미",
      "level": 1
    },
    {
      "kind": "part_crate",
      "rect": [
        130,
        28,
        1,
        1
      ],
      "solid": "none",
      "facing": 0,
      "note": "계량실 곁 부품 상자",
      "level": 1
    },
    {
      "kind": "barrel",
      "rect": [
        131,
        28,
        1,
        1
      ],
      "solid": "none",
      "facing": 0,
      "note": "계량실 곁 통",
      "level": 1
    },
    {
      "kind": "plate_stack",
      "rect": [
        18,
        8,
        3,
        2
      ],
      "solid": "low",
      "facing": 0,
      "note": "하역 준비 자리의 철판 더미",
      "level": 0
    },
    {
      "kind": "coupler_set",
      "rect": [
        14,
        8,
        1,
        1
      ],
      "solid": "low",
      "facing": 0,
      "note": "하역 준비 자리의 연결기 한 벌",
      "level": 0
    },
    {
      "kind": "part_crate",
      "rect": [
        15,
        8,
        1,
        1
      ],
      "solid": "low",
      "facing": 0,
      "note": "하역 준비 자리의 부품 상자",
      "level": 0
    },
    {
      "kind": "wheelset",
      "rect": [
        146,
        30,
        2,
        1
      ],
      "solid": "low",
      "facing": 0,
      "note": "하역 준비 자리의 차륜 한 쌍",
      "level": 0
    },
    {
      "kind": "tool_cart",
      "rect": [
        148,
        30,
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
        150,
        30,
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
      "name": "철재 사무소 앞 작업 칸 상자",
      "cell": [
        33,
        12
      ],
      "building": 21,
      "search": 6,
      "items": [
        "scrap"
      ],
      "locked": false,
      "level": 0,
      "searched": false
    },
    {
      "id": "north_box_2",
      "name": "철재 사무소 안쪽 보관실 상자",
      "cell": [
        42,
        12
      ],
      "building": 21,
      "search": 6,
      "items": [
        "scrap"
      ],
      "locked": false,
      "level": 0,
      "searched": false
    },
    {
      "id": "north_box_3",
      "name": "철재 선별 창고 철재 앞 저장고 상자",
      "cell": [
        53,
        12
      ],
      "building": 22,
      "search": 6,
      "items": [
        "scrap"
      ],
      "locked": false,
      "level": -1,
      "searched": false
    },
    {
      "id": "north_box_4",
      "name": "철재 선별 창고 철재 안쪽 보관실 상자",
      "cell": [
        60,
        12
      ],
      "building": 22,
      "search": 6,
      "items": [
        "scrap"
      ],
      "locked": false,
      "level": -1,
      "searched": false
    },
    {
      "id": "north_box_5",
      "name": "철재 선별 창고 철재 앞 저장고 상자",
      "cell": [
        66,
        12
      ],
      "building": 22,
      "search": 6,
      "items": [
        "scrap"
      ],
      "locked": false,
      "level": -1,
      "searched": false
    },
    {
      "id": "north_box_6",
      "name": "철재 선별 창고 철재 안쪽 보관실 상자",
      "cell": [
        73,
        12
      ],
      "building": 22,
      "search": 6,
      "items": [
        "scrap"
      ],
      "locked": false,
      "level": -1,
      "searched": false
    },
    {
      "id": "north_box_7",
      "name": "철재 선별 창고 철재 앞 저장고 상자",
      "cell": [
        79,
        12
      ],
      "building": 22,
      "search": 6,
      "items": [
        "scrap"
      ],
      "locked": false,
      "level": -1,
      "searched": false
    },
    {
      "id": "north_box_8",
      "name": "철재 선별 창고 철재 안쪽 보관실 상자",
      "cell": [
        86,
        12
      ],
      "building": 22,
      "search": 6,
      "items": [
        "scrap"
      ],
      "locked": false,
      "level": -1,
      "searched": false
    },
    {
      "id": "north_box_9",
      "name": "철재 선별 창고 선별실 상자",
      "cell": [
        53,
        12
      ],
      "building": 22,
      "search": 6,
      "items": [
        "scrap"
      ],
      "locked": false,
      "level": 0,
      "searched": false
    },
    {
      "id": "north_box_10",
      "name": "철재 선별 창고 계량실 상자",
      "cell": [
        60,
        12
      ],
      "building": 22,
      "search": 6,
      "items": [
        "scrap"
      ],
      "locked": false,
      "level": 0,
      "searched": false
    },
    {
      "id": "north_box_11",
      "name": "철재 선별 창고 사무 칸 상자",
      "cell": [
        66,
        12
      ],
      "building": 22,
      "search": 6,
      "items": [
        "scrap"
      ],
      "locked": false,
      "level": 0,
      "searched": false
    },
    {
      "id": "north_box_12",
      "name": "철재 선별 창고 원료 칸 상자",
      "cell": [
        73,
        12
      ],
      "building": 22,
      "search": 6,
      "items": [
        "scrap"
      ],
      "locked": false,
      "level": 0,
      "searched": false
    },
    {
      "id": "north_box_13",
      "name": "철재 선별 창고 공구 칸 상자",
      "cell": [
        79,
        12
      ],
      "building": 22,
      "search": 6,
      "items": [
        "scrap"
      ],
      "locked": false,
      "level": 0,
      "searched": false
    },
    {
      "id": "north_box_14",
      "name": "철재 선별 창고 안쪽 보관실 상자",
      "cell": [
        86,
        12
      ],
      "building": 22,
      "search": 6,
      "items": [
        "scrap"
      ],
      "locked": false,
      "level": 0,
      "searched": false
    },
    {
      "id": "north_box_15",
      "name": "철재 선별 창고 선별실 상자",
      "cell": [
        53,
        12
      ],
      "building": 22,
      "search": 6,
      "items": [
        "scrap"
      ],
      "locked": false,
      "level": 1,
      "searched": false
    },
    {
      "id": "north_box_16",
      "name": "철재 선별 창고 계량실 상자",
      "cell": [
        60,
        12
      ],
      "building": 22,
      "search": 6,
      "items": [
        "scrap"
      ],
      "locked": false,
      "level": 1,
      "searched": false
    },
    {
      "id": "north_box_17",
      "name": "철재 선별 창고 사무 칸 상자",
      "cell": [
        66,
        12
      ],
      "building": 22,
      "search": 6,
      "items": [
        "scrap"
      ],
      "locked": false,
      "level": 1,
      "searched": false
    },
    {
      "id": "north_box_18",
      "name": "철재 선별 창고 원료 칸 상자",
      "cell": [
        73,
        12
      ],
      "building": 22,
      "search": 6,
      "items": [
        "scrap"
      ],
      "locked": false,
      "level": 1,
      "searched": false
    },
    {
      "id": "north_box_19",
      "name": "철재 선별 창고 공구 칸 상자",
      "cell": [
        79,
        12
      ],
      "building": 22,
      "search": 6,
      "items": [
        "scrap"
      ],
      "locked": false,
      "level": 1,
      "searched": false
    },
    {
      "id": "north_box_20",
      "name": "철재 선별 창고 안쪽 보관실 상자",
      "cell": [
        86,
        12
      ],
      "building": 22,
      "search": 6,
      "items": [
        "scrap"
      ],
      "locked": false,
      "level": 1,
      "searched": false
    },
    {
      "id": "north_box_21",
      "name": "철재 선별 창고 선별실 상자",
      "cell": [
        53,
        12
      ],
      "building": 22,
      "search": 6,
      "items": [
        "scrap"
      ],
      "locked": false,
      "level": 2,
      "searched": false
    },
    {
      "id": "north_box_22",
      "name": "철재 선별 창고 계량실 상자",
      "cell": [
        60,
        12
      ],
      "building": 22,
      "search": 6,
      "items": [
        "scrap"
      ],
      "locked": false,
      "level": 2,
      "searched": false
    },
    {
      "id": "north_box_23",
      "name": "철재 선별 창고 사무 칸 상자",
      "cell": [
        66,
        12
      ],
      "building": 22,
      "search": 6,
      "items": [
        "scrap"
      ],
      "locked": false,
      "level": 2,
      "searched": false
    },
    {
      "id": "north_box_24",
      "name": "철재 선별 창고 원료 칸 상자",
      "cell": [
        73,
        12
      ],
      "building": 22,
      "search": 6,
      "items": [
        "scrap"
      ],
      "locked": false,
      "level": 2,
      "searched": false
    },
    {
      "id": "north_box_25",
      "name": "철재 선별 창고 공구 칸 상자",
      "cell": [
        79,
        12
      ],
      "building": 22,
      "search": 6,
      "items": [
        "scrap"
      ],
      "locked": false,
      "level": 2,
      "searched": false
    },
    {
      "id": "north_box_26",
      "name": "철재 선별 창고 안쪽 보관실 상자",
      "cell": [
        86,
        12
      ],
      "building": 22,
      "search": 6,
      "items": [
        "scrap"
      ],
      "locked": false,
      "level": 2,
      "searched": false
    },
    {
      "id": "north_box_27",
      "name": "철재 계량소 작업 칸 상자",
      "cell": [
        12,
        10
      ],
      "building": 23,
      "search": 6,
      "items": [
        "scrap"
      ],
      "locked": false,
      "level": 0,
      "searched": false
    },
    {
      "id": "north_box_28",
      "name": "수선 헛간 앞 작업 칸 상자",
      "cell": [
        101,
        22
      ],
      "building": 24,
      "search": 6,
      "items": [
        "scrap"
      ],
      "locked": false,
      "level": 0,
      "searched": false
    },
    {
      "id": "north_box_29",
      "name": "수선 헛간 안쪽 보관실 상자",
      "cell": [
        114,
        22
      ],
      "building": 24,
      "search": 6,
      "items": [
        "scrap"
      ],
      "locked": false,
      "level": 0,
      "searched": false
    },
    {
      "id": "north_box_30",
      "name": "수선 헛간 앞 작업 칸 상자",
      "cell": [
        101,
        22
      ],
      "building": 24,
      "search": 6,
      "items": [
        "scrap"
      ],
      "locked": false,
      "level": 1,
      "searched": false
    },
    {
      "id": "north_box_31",
      "name": "수선 헛간 안쪽 보관실 상자",
      "cell": [
        114,
        22
      ],
      "building": 24,
      "search": 6,
      "items": [
        "scrap"
      ],
      "locked": false,
      "level": 1,
      "searched": false
    },
    {
      "id": "north_box_32",
      "name": "레일 보관 창고 앞 작업 칸 상자",
      "cell": [
        127,
        13
      ],
      "building": 25,
      "search": 6,
      "items": [
        "scrap"
      ],
      "locked": false,
      "level": 0,
      "searched": false
    },
    {
      "id": "north_box_33",
      "name": "레일 보관 창고 안쪽 보관실 상자",
      "cell": [
        136,
        13
      ],
      "building": 25,
      "search": 6,
      "items": [
        "scrap"
      ],
      "locked": false,
      "level": 0,
      "searched": false
    },
    {
      "id": "north_box_34",
      "name": "동력실 작업 칸 상자",
      "cell": [
        148,
        20
      ],
      "building": 26,
      "search": 6,
      "items": [
        "scrap"
      ],
      "locked": false,
      "level": 0,
      "searched": false
    },
    {
      "id": "north_box_35",
      "name": "철판 보관 헛간 철재 앞 저장고 상자",
      "cell": [
        157,
        16
      ],
      "building": 27,
      "search": 6,
      "items": [
        "scrap"
      ],
      "locked": false,
      "level": -1,
      "searched": false
    },
    {
      "id": "north_box_36",
      "name": "철판 보관 헛간 철재 안쪽 보관실 상자",
      "cell": [
        166,
        16
      ],
      "building": 27,
      "search": 6,
      "items": [
        "scrap"
      ],
      "locked": false,
      "level": -1,
      "searched": false
    },
    {
      "id": "north_box_37",
      "name": "철판 보관 헛간 앞 작업 칸 상자",
      "cell": [
        158,
        16
      ],
      "building": 27,
      "search": 6,
      "items": [
        "scrap"
      ],
      "locked": false,
      "level": 0,
      "searched": false
    },
    {
      "id": "north_box_38",
      "name": "철판 보관 헛간 안쪽 보관실 상자",
      "cell": [
        166,
        16
      ],
      "building": 27,
      "search": 6,
      "items": [
        "scrap"
      ],
      "locked": false,
      "level": 0,
      "searched": false
    },
    {
      "id": "north_box_39",
      "name": "철판 가공장 선별실 상자",
      "cell": [
        125,
        40
      ],
      "building": 28,
      "search": 6,
      "items": [
        "scrap"
      ],
      "locked": false,
      "level": 0,
      "searched": false
    },
    {
      "id": "north_box_40",
      "name": "철판 가공장 계량실 상자",
      "cell": [
        136,
        40
      ],
      "building": 28,
      "search": 6,
      "items": [
        "scrap"
      ],
      "locked": false,
      "level": 0,
      "searched": false
    },
    {
      "id": "north_box_41",
      "name": "철판 가공장 선별실 상자",
      "cell": [
        125,
        40
      ],
      "building": 28,
      "search": 6,
      "items": [
        "scrap"
      ],
      "locked": false,
      "level": 1,
      "searched": false
    },
    {
      "id": "north_box_42",
      "name": "철판 가공장 계량실 상자",
      "cell": [
        136,
        40
      ],
      "building": 28,
      "search": 6,
      "items": [
        "scrap"
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
        "scrap"
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
        20,
        19,
        12,
        3
      ],
      "coal": 0,
      "work": [
        21,
        22
      ]
    },
    {
      "id": "north_wagon_1",
      "name": "문 열린 평판 화차",
      "rect": [
        32,
        19,
        12,
        3
      ],
      "coal": 0,
      "work": [
        33,
        22
      ]
    },
    {
      "id": "north_wagon_2",
      "name": "문 열린 평판 화차",
      "rect": [
        50,
        19,
        12,
        3
      ],
      "coal": 0,
      "work": [
        51,
        22
      ]
    },
    {
      "id": "north_wagon_3",
      "name": "문 열린 평판 화차",
      "rect": [
        62,
        19,
        12,
        3
      ],
      "coal": 0,
      "work": [
        63,
        22
      ]
    }
  ],
  "entries": [
    [
      "서쪽 화차길",
      [
        [
          0,
          14
        ],
        [
          0,
          15
        ],
        [
          0,
          16
        ],
        [
          0,
          17
        ]
      ],
      0.6
    ],
    [
      "북쪽 철재길",
      [
        [
          104,
          0
        ],
        [
          105,
          0
        ],
        [
          106,
          0
        ],
        [
          107,
          0
        ]
      ],
      0.6
    ],
    [
      "동쪽 둘레길",
      [
        [
          169,
          0
        ],
        [
          169,
          1
        ],
        [
          169,
          2
        ],
        [
          169,
          3
        ]
      ],
      0.6
    ]
  ],
  "holes": [
    [
      "manhole_03",
      [
        58,
        15
      ],
      "화차 곁 맨홀"
    ]
  ],
  "barricades": [
    [
      45,
      20
    ],
    [
      48,
      20
    ],
    [
      75,
      20
    ],
    [
      77,
      20
    ],
    [
      116,
      43
    ],
    [
      116,
      44
    ]
  ],
  "deep": [
    [
      "K",
      "철판 보관 헛간"
    ]
  ],
  "dead": [],
  "salvage": [],
  "work_site": {},
  "cross": [
    48,
    64
  ],
  "court": [
    153,
    4,
    5,
    4
  ]
}


## 무전 문장에 쓰는 들어오는 길의 이름, 길마다의 비중, 첫 물결이 오는 길.
const ENTRY_NAMES: Dictionary = {"west_yard": "서쪽 야적장", "east_yard": "동쪽 야적장", "south_road": "남쪽 길", "east_track": "동쪽 선로", "manhole_01": "첫째 맨홀", "manhole_02": "둘째 맨홀", "drain_01": "배수구", "서쪽 화차길": "서쪽 화차길", "북쪽 철재길": "북쪽 철재길", "동쪽 둘레길": "동쪽 둘레길", "manhole_03": "셋째 맨홀"}
const ENTRY_WEIGHTS: Dictionary = {"west_yard": 1.0, "east_yard": 1.0, "south_road": 1.0, "east_track": 1.0, "manhole_01": 0.3, "manhole_02": 0.3, "drain_01": 1.0, "서쪽 화차길": 1.0, "북쪽 철재길": 1.0, "동쪽 둘레길": 1.0, "manhole_03": 0.3}
const FIRST_ENTRY: String = "west_yard"


static func build() -> Dictionary:
	var data: Dictionary = _build_plain()
	data["entry_names"] = ENTRY_NAMES.duplicate()
	data["entry_weights"] = ENTRY_WEIGHTS.duplicate()
	data["first_entry"] = FIRST_ENTRY
	return data
