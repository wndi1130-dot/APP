"""E 소품 78종. 외부 자원 없이 Blender에서 정점색 GLB를 만든다.

blender -b --factory-startup -P tools/blender/props_field_e.py -- --repo .
Blender X=가로, Z=위, -Y=앞; glTF +Y=위, +Z=앞. 기준점=가운데 바닥.
입력 표의 검증된 사본을 내장하여 _in 폴더 없이도 재생성할 수 있다.
"""
import sys
sys.dont_write_bytecode = True
import argparse
import collections
import hashlib
import json
import math
import os
from pathlib import Path
import re
import struct

import bmesh
import bpy
from mathutils import Vector

TRIANGLE_LIMIT = 600
SOURCE_SHA256 = "0124db77798d1c770f6285b9d84fa33726bcfe9c431379ff8f98bcddcbe01486"
# 공용 6색 그대로, 추가 6색. 선형 RGBA, alpha=1.
PALETTE = {
    "wood": (0.24, 0.17, 0.11, 1.0),
    "worn_wood": (0.38, 0.29, 0.19, 1.0),
    "iron": (0.12, 0.15, 0.17, 1.0),
    "worn_metal": (0.28, 0.32, 0.33, 1.0),
    "cloth": (0.43, 0.41, 0.31, 1.0),
    "enamel": (0.68, 0.70, 0.66, 1.0),
    "snow": (0.82, 0.87, 0.89, 1.0),
    "bark": (0.18, 0.14, 0.11, 1.0),
    "rust": (0.32, 0.18, 0.11, 1.0),
    "glass": (0.22, 0.35, 0.39, 1.0),
    "rubber": (0.055, 0.065, 0.07, 1.0),
    "stone": (0.37, 0.39, 0.38, 1.0),
}
SOURCE = json.loads(r'''{"skip_ground_like":[],"kinds":[{"kind":"garage_door_leaf","count":5,"maps":5,"has_model":false,"rects_wh_top":[[[2,1],5]],"solid":{"wall":5},"facing":{"0":5},"names_top":[],"map_families":["summit"],"ground_like":false,"rank":201},{"kind":"hive_box","count":5,"maps":1,"has_model":false,"rects_wh_top":[[[1,1],5]],"solid":{"low":5},"facing":{"0":5},"names_top":[],"map_families":["church"],"ground_like":false,"rank":202},{"kind":"inspection_pit","count":5,"maps":5,"has_model":false,"rects_wh_top":[[[14,2],5]],"solid":{"none":5},"facing":{"0":5},"names_top":[],"map_families":["summit"],"ground_like":false,"rank":203},{"kind":"log_flatcar","count":5,"maps":1,"has_model":false,"rects_wh_top":[[[12,3],5]],"solid":{"wagon":5},"facing":{"0":5},"names_top":[],"map_families":["sawmill"],"ground_like":false,"rank":204},{"kind":"millstone","count":5,"maps":1,"has_model":false,"rects_wh_top":[[[2,2],5]],"solid":{"low":5},"facing":{"0":5},"names_top":[],"map_families":["church"],"ground_like":false,"rank":205},{"kind":"mooring_post","count":5,"maps":3,"has_model":false,"rects_wh_top":[[[1,1],5]],"solid":{"low":5},"facing":{"0":2,"2":2,"1":1},"names_top":[],"map_families":["freight","houses"],"ground_like":false,"rank":206},{"kind":"rail_plow","count":5,"maps":5,"has_model":false,"rects_wh_top":[[[12,3],5]],"solid":{"wall":5},"facing":{"0":5},"names_top":[],"map_families":["summit"],"ground_like":false,"rank":207},{"kind":"siding_buffer","count":5,"maps":5,"has_model":false,"rects_wh_top":[[[2,3],5]],"solid":{"low":5},"facing":{"0":5},"names_top":[],"map_families":["summit"],"ground_like":false,"rank":208},{"kind":"wheelset","count":5,"maps":3,"has_model":false,"rects_wh_top":[[[2,1],5]],"solid":{"low":5},"facing":{"0":5},"names_top":[],"map_families":["freight"],"ground_like":false,"rank":209},{"kind":"wind_pole","count":5,"maps":5,"has_model":false,"rects_wh_top":[[[1,1],5]],"solid":{"none":5},"facing":{"0":5},"names_top":[],"map_families":["summit"],"ground_like":false,"rank":210},{"kind":"ballast_pile","count":4,"maps":3,"has_model":false,"rects_wh_top":[[[3,2],3],[[2,3],1]],"solid":{"low":4},"facing":{"0":3,"1":1},"names_top":[],"map_families":["bare_line"],"ground_like":false,"rank":211},{"kind":"dock_plate","count":4,"maps":1,"has_model":false,"rects_wh_top":[[[4,3],3],[[12,3],1]],"solid":{"none":4},"facing":{"0":2,"1":1,"3":1},"names_top":[],"map_families":["houses"],"ground_like":false,"rank":212},{"kind":"dry_grass","count":4,"maps":4,"has_model":false,"rects_wh_top":[[[2,2],4]],"solid":{"none":4},"facing":{"0":4},"names_top":[],"map_families":["mine"],"ground_like":false,"rank":213},{"kind":"evidence_shelf","count":4,"maps":1,"has_model":false,"rects_wh_top":[[[3,1],4]],"solid":{"low":2,"none":2},"facing":{"3":3,"1":1},"names_top":[],"map_families":["office"],"ground_like":false,"rank":214},{"kind":"fuel_pump","count":4,"maps":2,"has_model":false,"rects_wh_top":[[[1,2],4]],"solid":{"low":4},"facing":{"1":1,"2":1,"3":1,"0":1},"names_top":[],"map_families":["houses","office"],"ground_like":false,"rank":215},{"kind":"hose_rack","count":4,"maps":1,"has_model":false,"rects_wh_top":[[[4,1],4]],"solid":{"low":2,"none":2},"facing":{"0":2,"2":2},"names_top":[],"map_families":["office"],"ground_like":false,"rank":216},{"kind":"long_table","count":4,"maps":1,"has_model":false,"rects_wh_top":[[[4,2],4]],"solid":{"low":4},"facing":{"0":4},"names_top":[],"map_families":["church"],"ground_like":false,"rank":217},{"kind":"plank_patch","count":4,"maps":1,"has_model":false,"rects_wh_top":[[[3,1],4]],"solid":{"wall":3,"none":1},"facing":{"0":1,"1":1,"2":1,"3":1},"names_top":[],"map_families":["church"],"ground_like":false,"rank":218},{"kind":"skybridge_rail","count":4,"maps":1,"has_model":false,"rects_wh_top":[[[6,1],4]],"solid":{"none":4},"facing":{"3":1,"2":1,"1":1,"0":1},"names_top":[],"map_families":["office"],"ground_like":false,"rank":219},{"kind":"slate_board","count":4,"maps":1,"has_model":false,"rects_wh_top":[[[2,1],4]],"solid":{"low":4},"facing":{"2":4},"names_top":[],"map_families":["church"],"ground_like":false,"rank":220},{"kind":"turntable_rim","count":4,"maps":1,"has_model":false,"rects_wh_top":[[[6,1],2],[[1,6],2]],"solid":{"low":4},"facing":{"0":2,"1":2},"names_top":[],"map_families":["freight"],"ground_like":false,"rank":221},{"kind":"windbreak_fence","count":4,"maps":1,"has_model":false,"rects_wh_top":[[[8,1],4]],"solid":{"low":4},"facing":{"0":1,"1":1,"2":1,"3":1},"names_top":[],"map_families":["church"],"ground_like":false,"rank":222},{"kind":"bin_bay","count":3,"maps":1,"has_model":false,"rects_wh_top":[[[4,2],3]],"solid":{"low":3},"facing":{"0":2,"1":1},"names_top":[],"map_families":["houses"],"ground_like":false,"rank":223},{"kind":"bunk_bed","count":3,"maps":1,"has_model":false,"rects_wh_top":[[[2,1],3]],"solid":{"none":3},"facing":{"0":2,"1":1},"names_top":[],"map_families":["office"],"ground_like":false,"rank":224},{"kind":"chiller_case","count":3,"maps":1,"has_model":false,"rects_wh_top":[[[4,1],3]],"solid":{"low":3},"facing":{"3":1,"0":1,"1":1},"names_top":[],"map_families":["houses"],"ground_like":false,"rank":225},{"kind":"coal_hopper","count":3,"maps":3,"has_model":false,"rects_wh_top":[[[3,3],3]],"solid":{"wall":3},"facing":{"0":3},"names_top":[],"map_families":["freight"],"ground_like":false,"rank":226},{"kind":"dock_door","count":3,"maps":1,"has_model":false,"rects_wh_top":[[[4,1],3]],"solid":{"none":3},"facing":{"0":1,"3":1,"2":1},"names_top":[],"map_families":["houses"],"ground_like":false,"rank":227},{"kind":"fallen_pole","count":3,"maps":3,"has_model":false,"rects_wh_top":[[[5,1],3]],"solid":{"low":3},"facing":{"0":3},"names_top":[],"map_families":["bare_line"],"ground_like":false,"rank":228},{"kind":"garden_bed","count":3,"maps":2,"has_model":false,"rects_wh_top":[[[4,2],3]],"solid":{"low":3},"facing":{"0":3},"names_top":[],"map_families":["houses"],"ground_like":false,"rank":229},{"kind":"hand_pump_cart","count":3,"maps":2,"has_model":false,"rects_wh_top":[[[2,1],3]],"solid":{"low":3},"facing":{"3":1,"1":1,"2":1},"names_top":[],"map_families":["office"],"ground_like":false,"rank":230},{"kind":"hedge","count":3,"maps":1,"has_model":false,"rects_wh_top":[[[6,1],2],[[1,6],1]],"solid":{"low":3},"facing":{"0":3},"names_top":[],"map_families":["church"],"ground_like":false,"rank":231},{"kind":"laundry_line","count":3,"maps":3,"has_model":false,"rects_wh_top":[[[6,1],3]],"solid":{"none":3},"facing":{"0":2,"1":1},"names_top":[],"map_families":["houses"],"ground_like":false,"rank":232},{"kind":"rail_handcar","count":3,"maps":3,"has_model":false,"rects_wh_top":[[[3,2],3]],"solid":{"low":3},"facing":{"0":3},"names_top":[],"map_families":["bare_line"],"ground_like":false,"rank":233},{"kind":"rubble_heap","count":3,"maps":2,"has_model":false,"rects_wh_top":[[[2,5],2],[[4,3],1]],"solid":{"low":3},"facing":{"0":1,"1":1,"3":1},"names_top":[],"map_families":["church"],"ground_like":false,"rank":234},{"kind":"well_cover","count":3,"maps":2,"has_model":false,"rects_wh_top":[[[2,2],3]],"solid":{"low":3},"facing":{"0":2,"3":1},"names_top":[],"map_families":["houses"],"ground_like":false,"rank":235},{"kind":"armory_rack","count":2,"maps":1,"has_model":false,"rects_wh_top":[[[3,1],2]],"solid":{"none":2},"facing":{"2":1,"1":1},"names_top":[],"map_families":["office"],"ground_like":false,"rank":236},{"kind":"brake_shoe_pile","count":2,"maps":2,"has_model":false,"rects_wh_top":[[[2,1],2]],"solid":{"low":2},"facing":{"0":2},"names_top":[],"map_families":["freight"],"ground_like":false,"rank":237},{"kind":"curing_barrel","count":2,"maps":1,"has_model":false,"rects_wh_top":[[[1,1],2]],"solid":{"low":1,"none":1},"facing":{"0":1,"2":1},"names_top":[],"map_families":["houses"],"ground_like":false,"rank":238},{"kind":"frozen_barge","count":2,"maps":1,"has_model":false,"rects_wh_top":[[[8,3],2]],"solid":{"low":2},"facing":{"0":2},"names_top":[],"map_families":["freight"],"ground_like":false,"rank":239},{"kind":"grain_silo","count":2,"maps":1,"has_model":false,"rects_wh_top":[[[5,5],2]],"solid":{"wall":2},"facing":{"0":2},"names_top":[],"map_families":["freight"],"ground_like":false,"rank":240},{"kind":"herb_bed","count":2,"maps":1,"has_model":false,"rects_wh_top":[[[4,2],2]],"solid":{"none":2},"facing":{"1":1,"2":1},"names_top":[],"map_families":["church"],"ground_like":false,"rank":241},{"kind":"herb_rack","count":2,"maps":1,"has_model":false,"rects_wh_top":[[[3,1],2]],"solid":{"low":2},"facing":{"3":1,"0":1},"names_top":[],"map_families":["church"],"ground_like":false,"rank":242},{"kind":"lock_wheel","count":2,"maps":1,"has_model":false,"rects_wh_top":[[[1,1],2]],"solid":{"low":2},"facing":{"0":2},"names_top":[],"map_families":["freight"],"ground_like":false,"rank":243},{"kind":"log_pile","count":2,"maps":1,"has_model":false,"rects_wh_top":[[[4,2],2]],"solid":{"low":2},"facing":{"0":2},"names_top":[],"map_families":["freight"],"ground_like":false,"rank":244},{"kind":"patrol_car","count":2,"maps":1,"has_model":false,"rects_wh_top":[[[5,2],2]],"solid":{"low":2},"facing":{"2":1,"0":1},"names_top":[],"map_families":["office"],"ground_like":false,"rank":245},{"kind":"plank_fence","count":2,"maps":2,"has_model":false,"rects_wh_top":[[[6,1],2]],"solid":{"low":2},"facing":{"0":2},"names_top":[],"map_families":["church"],"ground_like":false,"rank":246},{"kind":"platform_cart","count":2,"maps":2,"has_model":false,"rects_wh_top":[[[2,1],2]],"solid":{"low":2},"facing":{"0":2},"names_top":[],"map_families":["freight"],"ground_like":false,"rank":247},{"kind":"repair_scaffold","count":2,"maps":1,"has_model":false,"rects_wh_top":[[[4,2],2]],"solid":{"low":2},"facing":{"2":1,"3":1},"names_top":[],"map_families":["church"],"ground_like":false,"rank":248},{"kind":"roof_beam_pile","count":2,"maps":1,"has_model":false,"rects_wh_top":[[[2,3],2]],"solid":{"low":2},"facing":{"0":1,"1":1},"names_top":[],"map_families":["church"],"ground_like":false,"rank":249},{"kind":"roof_tile_heap","count":2,"maps":1,"has_model":false,"rects_wh_top":[[[2,5],1],[[2,3],1]],"solid":{"low":2},"facing":{"1":1,"0":1},"names_top":[],"map_families":["church"],"ground_like":false,"rank":250},{"kind":"sluice_frame","count":2,"maps":1,"has_model":false,"rects_wh_top":[[[6,2],2]],"solid":{"wall":2},"facing":{"0":2},"names_top":[],"map_families":["freight"],"ground_like":false,"rank":251},{"kind":"strongbox","count":2,"maps":2,"has_model":false,"rects_wh_top":[[[1,1],2]],"solid":{"none":2},"facing":{"1":1,"3":1},"names_top":[],"map_families":["office"],"ground_like":false,"rank":252},{"kind":"transformer_unit","count":2,"maps":1,"has_model":false,"rects_wh_top":[[[2,2],2]],"solid":{"wall":2},"facing":{"0":2},"names_top":[],"map_families":["freight"],"ground_like":false,"rank":253},{"kind":"water_gauge","count":2,"maps":2,"has_model":false,"rects_wh_top":[[[1,1],2]],"solid":{"low":2},"facing":{"0":2},"names_top":[],"map_families":["freight"],"ground_like":false,"rank":254},{"kind":"anchor","count":1,"maps":1,"has_model":false,"rects_wh_top":[[[2,1],1]],"solid":{"low":1},"facing":{"0":1},"names_top":[],"map_families":["houses"],"ground_like":false,"rank":255},{"kind":"bridge_rail","count":1,"maps":1,"has_model":false,"rects_wh_top":[[[6,1],1]],"solid":{"low":1},"facing":{"2":1},"names_top":[],"map_families":["houses"],"ground_like":false,"rank":256},{"kind":"bridge_truss","count":1,"maps":1,"has_model":false,"rects_wh_top":[[[8,2],1]],"solid":{"wall":1},"facing":{"0":1},"names_top":[],"map_families":["freight"],"ground_like":false,"rank":257},{"kind":"dock_platform","count":1,"maps":1,"has_model":false,"rects_wh_top":[[[12,4],1]],"solid":{"none":1},"facing":{"0":1},"names_top":[],"map_families":["freight"],"ground_like":false,"rank":258},{"kind":"fallen_bell","count":1,"maps":1,"has_model":false,"rects_wh_top":[[[3,3],1]],"solid":{"low":1},"facing":{"0":1},"names_top":[],"map_families":["church"],"ground_like":false,"rank":259},{"kind":"fire_engine","count":1,"maps":1,"has_model":false,"rects_wh_top":[[[7,3],1]],"solid":{"wall":1},"facing":{"3":1},"names_top":[],"map_families":["office"],"ground_like":false,"rank":260},{"kind":"fishing_boat","count":1,"maps":1,"has_model":false,"rects_wh_top":[[[9,3],1]],"solid":{"wall":1},"facing":{"3":1},"names_top":[],"map_families":["houses"],"ground_like":false,"rank":261},{"kind":"flagpole","count":1,"maps":1,"has_model":false,"rects_wh_top":[[[1,1],1]],"solid":{"none":1},"facing":{"3":1},"names_top":[],"map_families":["office"],"ground_like":false,"rank":262},{"kind":"frozen_fountain","count":1,"maps":1,"has_model":false,"rects_wh_top":[[[4,4],1]],"solid":{"low":1},"facing":{"2":1},"names_top":[],"map_families":["church"],"ground_like":false,"rank":263},{"kind":"pallet_truck","count":1,"maps":1,"has_model":false,"rects_wh_top":[[[2,1],1]],"solid":{"low":1},"facing":{"0":1},"names_top":[],"map_families":["houses"],"ground_like":false,"rank":264},{"kind":"pit_rail_pair","count":1,"maps":1,"has_model":false,"rects_wh_top":[[[8,2],1]],"solid":{"none":1},"facing":{"0":1},"names_top":[],"map_families":["freight"],"ground_like":false,"rank":265},{"kind":"playground_frame","count":1,"maps":1,"has_model":false,"rects_wh_top":[[[4,3],1]],"solid":{"low":1},"facing":{"3":1},"names_top":[],"map_families":["houses"],"ground_like":false,"rank":266},{"kind":"quay_crane","count":1,"maps":1,"has_model":false,"rects_wh_top":[[[5,5],1]],"solid":{"wall":1},"facing":{"0":1},"names_top":[],"map_families":["freight"],"ground_like":false,"rank":267},{"kind":"reed_clump","count":1,"maps":1,"has_model":false,"rects_wh_top":[[[3,3],1]],"solid":{"none":1},"facing":{"0":1},"names_top":[],"map_families":["freight"],"ground_like":false,"rank":268},{"kind":"shop_awning","count":1,"maps":1,"has_model":false,"rects_wh_top":[[[3,1],1]],"solid":{"none":1},"facing":{"0":1},"names_top":[],"map_families":["church"],"ground_like":false,"rank":269},{"kind":"signal_bridge","count":1,"maps":1,"has_model":false,"rects_wh_top":[[[10,1],1]],"solid":{"none":1},"facing":{"0":1},"names_top":[],"map_families":["freight"],"ground_like":false,"rank":270},{"kind":"stalled_tram","count":1,"maps":1,"has_model":false,"rects_wh_top":[[[12,3],1]],"solid":{"wall":1},"facing":{"2":1},"names_top":[],"map_families":["houses"],"ground_like":false,"rank":271},{"kind":"switch_cluster","count":1,"maps":1,"has_model":false,"rects_wh_top":[[[3,2],1]],"solid":{"low":1},"facing":{"0":1},"names_top":[],"map_families":["freight"],"ground_like":false,"rank":272},{"kind":"switch_lever","count":1,"maps":1,"has_model":false,"rects_wh_top":[[[1,1],1]],"solid":{"low":1},"facing":{"0":1},"names_top":[],"map_families":["freight"],"ground_like":false,"rank":273},{"kind":"tow_truck","count":1,"maps":1,"has_model":false,"rects_wh_top":[[[7,3],1]],"solid":{"wall":1},"facing":{"3":1},"names_top":[],"map_families":["office"],"ground_like":false,"rank":274},{"kind":"training_frame","count":1,"maps":1,"has_model":false,"rects_wh_top":[[[3,3],1]],"solid":{"low":1},"facing":{"2":1},"names_top":[],"map_families":["office"],"ground_like":false,"rank":275},{"kind":"turntable_deck","count":1,"maps":1,"has_model":false,"rects_wh_top":[[[20,3],1]],"solid":{"none":1},"facing":{"0":1},"names_top":[],"map_families":["freight"],"ground_like":false,"rank":276},{"kind":"water_crane","count":1,"maps":1,"has_model":false,"rects_wh_top":[[[2,2],1]],"solid":{"wall":1},"facing":{"0":1},"names_top":[],"map_families":["freight"],"ground_like":false,"rank":277},{"kind":"water_tower","count":1,"maps":1,"has_model":false,"rects_wh_top":[[[5,5],1]],"solid":{"wall":1},"facing":{"0":1},"names_top":[],"map_families":["freight"],"ground_like":false,"rank":278}]}''')

# 높이는 m. 혼합 solid는 최빈값(동률이면 low)을 기준으로 하고 예외를 명시한다.
DESIGNS = {
    "garage_door_leaf": (2.2, "wall: 낡은 차고 문짝 하나, 잠금장치 없는 세로 판재"),
    "hive_box": (.9, "low: 층진 벌통과 작은 출입 틈, 눈 덮인 뚜껑"),
    "inspection_pit": (.12, "none: 파내지 않는 어두운 점검구와 낮은 평테두리"),
    "log_flatcar": (1.9, "wagon 예외: 사람 칸 없는 원목 화물 평판차, 적재 통나무"),
    "millstone": (.65, "low: 가운데 구멍과 방사 홈이 있는 맷돌"),
    "mooring_post": (.9, "low: 둥근 계선 기둥과 가로 머리, 사슬 없음"),
    "rail_plow": (1.8, "wall: 앞 +Z 쐐기 제설날과 유리 계기창이 있는 기관실"),
    "siding_buffer": (1.0, "low: 선로 끝 완충대와 양쪽 고무 받침"),
    "wheelset": (.9, "low: 축 하나로 연결된 철도 바퀴 두 개"),
    "wind_pole": (3.2, "none 높이 예외: 기상 바람기둥과 축 늘어진 빈 풍향포"),
    "ballast_pile": (.8, "low: 눈 사이로 드러난 각진 선로 자갈"),
    "dock_plate": (.12, "none: 경사 없는 평철판, 하역 경사로 아님"),
    "dry_grass": (.4, "none: 낮은 마른 풀 포기와 눈 사이 빈 공간"),
    "evidence_shelf": (1.2, "low/none 혼합: 종이 기록만 놓인 낮은 증거 선반, 소지품 더미 없음"),
    "fuel_pump": (1.3, "low: 계기 창·주유 손잡이·느슨한 호스가 있는 주유기"),
    "hose_rack": (1.15, "low/none 혼합: 선반에 감긴 고무 호스 두 타래"),
    "long_table": (.8, "low: 긴 널판 식탁과 네 다리"),
    "plank_patch": (1.9, "wall/none 혼합: 안쪽 수선용 널판 묶음, 창 봉쇄·빗장 아님"),
    "skybridge_rail": (1.1, "none 높이 예외: 연결다리 가장자리의 열린 난간"),
    "slate_board": (1.25, "low: 무문자 석판과 작은 나무 받침틀"),
    "turntable_rim": (.3, "low: 회차대 가장자리의 짧은 곡선 레일"),
    "windbreak_fence": (1.2, "low: 틈 있는 낮은 나무 바람막이, 철조망 없음"),
    "bin_bay": (1.1, "low: 분리된 폐자재 통 세 개, 소지품 적재 없음"),
    "bunk_bed": (1.75, "none 높이 예외: 두 층 침상과 얇은 침구, 옷 더미 없음"),
    "chiller_case": (1.15, "low: 유리 앞판과 비어 있는 냉장 진열함"),
    "coal_hopper": (2.7, "wall: 아래가 좁은 석탄 호퍼와 네 받침"),
    "dock_door": (.15, "none: 원문 평평한 하역 문에 맞춘 누운 문판, 경사로 없음"),
    "fallen_pole": (.5, "low: 쓰러진 전신주와 절연체, 발자국 안 가로대"),
    "garden_bed": (.35, "low: 낮은 테두리와 눈 덮인 빈 텃밭"),
    "hand_pump_cart": (1.2, "low: 바퀴 달린 수동 펌프와 손잡이"),
    "hedge": (1.1, "low: 잎 적은 겨울 생울타리와 작은 눈 덩어리"),
    "laundry_line": (1.8, "none 높이 예외: 빈 빨랫줄과 두 기둥, 옷·가방 더미 없음"),
    "rail_handcar": (1.2, "low: 철도 수동 대차의 펌프 지레와 네 바퀴"),
    "rubble_heap": (.8, "low: 깨진 돌·벽돌만 쌓인 낮은 잔해"),
    "well_cover": (.5, "low: 낮은 우물 돌테와 닫힌 나무 덮개"),
    "armory_rack": (1.2, "none 높이 예외: 빈 무기 거치 홈과 열린 받침틀"),
    "brake_shoe_pile": (.5, "low: 곡면 제동 블록 여섯 개, 소지품 없음"),
    "curing_barrel": (.85, "low/none 혼합: 뚜껑과 쇠테를 두른 저장 통 하나"),
    "frozen_barge": (1.1, "low: 얼어붙은 빈 평저 바지선, 승선 자리 없음"),
    "grain_silo": (6.2, "wall: 원통 곡물 사일로와 원뿔 지붕"),
    "herb_bed": (.35, "none: 낮은 약초밭의 마른 줄기와 목재 테"),
    "herb_rack": (1.2, "low: 약초를 말리는 나무 채반 세 단"),
    "lock_wheel": (1.2, "low: 수문 조작 바퀴와 수직 축, 문 잠금 아님"),
    "log_pile": (1.1, "low: 마른 원목 다섯 개와 눈 덮인 위쪽"),
    "patrol_car": (.8, "low: 눈 쌓인 순찰 승용차, 무표식·등화 효과 없음, 앞 +Z"),
    "plank_fence": (1.2, "low: 낮은 널판 울타리, 철조망·출입 잠금 없음"),
    "platform_cart": (.5, "low: 낮은 평판 운반 수레와 네 바퀴"),
    "repair_scaffold": (1.25, "low: 수선용 낮은 발판과 사선 지지대"),
    "roof_beam_pile": (.8, "low: 지붕 보 세 층, 양 끝이 보이는 목재"),
    "roof_tile_heap": (.7, "low: 겹친 회색 지붕 기와 조각, 눈 얹힘"),
    "sluice_frame": (2.8, "wall: 수문 물길의 문틀·판·조작축, 사람 칸 없음"),
    "strongbox": (.5, "none: 바닥 가까운 소형 금고와 작은 원형 손잡이"),
    "transformer_unit": (2.3, "wall: 방열핀·절연체가 있는 낡은 변압기"),
    "water_gauge": (1.2, "low: 수위 눈금판, 대기 번호·구획 없음"),
    "anchor": (.35, "low: 바닥에 누운 닻과 굽은 양 갈래, 사슬 없음"),
    "bridge_rail": (1.15, "low: 다리의 열린 나무 난간"),
    "bridge_truss": (2.8, "wall: 삼각 버팀이 이어진 교량 철골"),
    "dock_platform": (.35, "none: 평평한 부두 널판과 낮은 받침, 경사로 없음"),
    "fallen_bell": (1.1, "low: 옆으로 기운 빈 종과 두꺼운 입 테두리"),
    "fire_engine": (1.8, "wall: 사다리·장비함이 있는 소방차, 빨간 십자·등화 효과 없음"),
    "fishing_boat": (2.1, "wall: 작은 조타실과 열린 갑판 어선, 승선 자리 없음"),
    "flagpole": (4.0, "none 높이 예외: 표식 없는 깃대와 작은 빈 깃발"),
    "frozen_fountain": (1.1, "low: 얼음 찬 분수 받침과 작은 중앙 수반"),
    "pallet_truck": (1.1, "low: 포크 두 갈래·작은 바퀴·수동 운반 손잡이"),
    "pit_rail_pair": (.16, "none: 점검구 위의 두 평행 레일과 침목"),
    "playground_frame": (1.25, "low: 낮은 놀이 오르기 틀, 매달린 사슬 없음"),
    "quay_crane": (5.0, "wall: 부두 기중기와 기울어진 붐, 갈고리만 표현"),
    "reed_clump": (.5, "none: 낮은 겨울 갈대와 마른 이삭"),
    "shop_awning": (2.2, "none 높이 예외: 가게 차양 천과 열린 두 기둥"),
    "signal_bridge": (4.2, "none 높이 예외: 선로 신호교와 꺼진 신호판, 빛 없음"),
    "stalled_tram": (2.8, "wall: 창과 옆 출입구가 열린 멈춘 전차, 앞 +Z"),
    "switch_cluster": (1.1, "low: 분기 레일·연결봉·낮은 전환기"),
    "switch_lever": (1.0, "low: 받침과 기울어진 선로 전환 지레"),
    "tow_truck": (1.8, "wall: 견인 붐과 빈 갈고리 있는 트럭, 사슬 없음"),
    "training_frame": (1.2, "low: 원문의 낮은 나무 훈련 틀, 줄 세우는 자리 없음"),
    "turntable_deck": (.35, "none: 회차대 평판과 평행 레일, 낮은 중앙 회전 받침"),
    "water_crane": (3.2, "wall: 증기기관차 급수관과 굽은 주둥이, 연기 없음"),
    "water_tower": (6.0, "wall: 네 다리 위의 원통 물탱크, 연기·망루 없음"),
}


class Piece:
    def __init__(self, pid):
        self.pid = pid
        self.bm = bmesh.new()
        self.col = self.bm.loops.layers.float_color.new("Col")
        self.colours = set()

    def face(self, pts, colour, outward):
        pts = [Vector(p) for p in pts]
        normal = Vector((0, 0, 0))
        for i, a in enumerate(pts):
            b = pts[(i + 1) % len(pts)]
            normal += Vector(((a.y-b.y)*(a.z+b.z), (a.z-b.z)*(a.x+b.x), (a.x-b.x)*(a.y+b.y)))
        if normal.length < 1e-9:
            raise ValueError("넓이 없는 면 " + self.pid)
        if normal.dot(Vector(outward)) < 0:
            pts.reverse()
        face = self.bm.faces.new([self.bm.verts.new(p) for p in pts])
        for loop in face.loops:
            loop[self.col] = PALETTE[colour]
        self.colours.add(colour)

    def box(self, x, y, z, colour="wood"):
        x0, x1 = x
        y0, y1 = y
        z0, z1 = z
        assert min(x1-x0, y1-y0, z1-z0) > 0
        for at, sign in ((x0, -1), (x1, 1)):
            self.face([(at,y0,z0),(at,y1,z0),(at,y1,z1),(at,y0,z1)], colour, (sign,0,0))
        for at, sign in ((y0, -1), (y1, 1)):
            self.face([(x0,at,z0),(x1,at,z0),(x1,at,z1),(x0,at,z1)], colour, (0,sign,0))
        for at, sign in ((z0, -1), (z1, 1)):
            self.face([(x0,y0,at),(x1,y0,at),(x1,y1,at),(x0,y1,at)], colour, (0,0,sign))

    def beam(self, start, end, radius, colour="iron", sides=6, tip=None):
        a, b = Vector(start), Vector(end)
        axis = (b-a).normalized()
        guide = Vector((1,0,0)) if abs(axis.z) > .9 else Vector((0,0,1))
        u = axis.cross(guide).normalized()
        v = axis.cross(u).normalized()
        radial = [u*math.cos(i*math.tau/sides)+v*math.sin(i*math.tau/sides) for i in range(sides)]
        tip = radius if tip is None else tip
        lower, upper = [a+d*radius for d in radial], [b+d*tip for d in radial]
        self.face(lower, colour, -axis)
        self.face(upper, colour, axis)
        for i in range(sides):
            j = (i+1) % sides
            self.face([lower[i],lower[j],upper[j],upper[i]], colour, radial[i]+radial[j])

    def lathe(self, centre, profile, colour, sides=10):
        x, y = centre
        rings = [[(x+rx*math.cos(i*math.tau/sides),y+ry*math.sin(i*math.tau/sides),z)
                  for i in range(sides)] for z,rx,ry in profile]
        self.face(rings[0], colour, (0,0,-1))
        self.face(rings[-1], colour, (0,0,1))
        for lo, hi in zip(rings,rings[1:]):
            for i in range(sides):
                j = (i+1) % sides
                a = (i+.5)*math.tau/sides
                self.face([lo[i],lo[j],hi[j],hi[i]],colour,(math.cos(a),math.sin(a),0))

    def ring(self, centre, outer, inner, thickness, colour, sides=10, plane="xy"):
        # 실제 구멍을 남기는 각진 고리. 호스·맷돌·수문 바퀴에 공용.
        def point(r, a, h):
            q = (r*math.cos(a),r*math.sin(a),h)
            q = q if plane == "xy" else ((q[0],q[2],q[1]) if plane == "xz" else (q[2],q[0],q[1]))
            return Vector(centre)+Vector(q)
        for i in range(sides):
            a,b = i*math.tau/sides,(i+1)*math.tau/sides
            lo=[point(outer,a,-thickness/2),point(outer,b,-thickness/2),point(inner,b,-thickness/2),point(inner,a,-thickness/2)]
            hi=[point(outer,a,thickness/2),point(outer,b,thickness/2),point(inner,b,thickness/2),point(inner,a,thickness/2)]
            axis=Vector((0,0,1) if plane=="xy" else ((0,1,0) if plane=="xz" else (1,0,0)))
            radial=point(1,(a+b)/2,0)-Vector(centre)
            for pts,normal in ((lo,-axis),(hi,axis),([lo[0],hi[0],hi[1],lo[1]],radial),([lo[3],lo[2],hi[2],hi[3]],-radial)):
                self.face(pts,colour,normal)

    def fit(self, footprint, height, keep_aspect=False):
        lo=[min(v.co[i] for v in self.bm.verts) for i in range(3)]
        hi=[max(v.co[i] for v in self.bm.verts) for i in range(3)]
        scale=[footprint[0]*.96/(hi[0]-lo[0]),footprint[1]*.96/(hi[1]-lo[1]),height/(hi[2]-lo[2])]
        if keep_aspect:
            scale[0]=scale[1]=min(scale[:2])
        for v in self.bm.verts:
            for i in range(3):
                v.co[i]=(v.co[i]-(lo[i] if i==2 else (lo[i]+hi[i])/2))*scale[i]
        bmesh.ops.triangulate(self.bm,faces=list(self.bm.faces))
        self.bm.normal_update()
        assert all(f.calc_area()>1e-10 for f in self.bm.faces)

    def bounds(self):
        xyz=[(v.co.x,v.co.z,-v.co.y) for v in self.bm.verts]
        return [[round(fn(p[i] for p in xyz),5)+0.0 for i in range(3)] for fn in (min,max)]


def legs(p, top=.8, colour="wood", x=.42, y=.38, z=0):
    for a in (-x,x):
        for b in (-y,y):
            p.box((a-.035,a+.035),(b-.035,b+.035),(z,top),colour)


def snow(p, x=(-.45,.45), y=(-.4,.4), z=.96, thick=.04):
    p.box(x,y,(z,z+thick),"snow")


def boards(p, z=.8, n=5, colour="worn_wood"):
    for i in range(n):
        x=-.5+i/n
        p.box((x,x+.93/n),(-.45,.45),(z,z+.055),colour if i%3 else "wood")


def shelf(p, kind):
    if kind == "armory_rack":
        for x in (-.46,.46):
            p.box((x-.025,x+.025),(-.28,.28),(0,1),"wood")
        p.box((-.5,.5),(-.4,.4),(.06,.16),"worn_wood")
        p.box((-.5,.5),(.12,.2),(.7,.82),"worn_wood")
        for x in (-.4,-.2,0,.2,.4):
            p.box((x-.025,x+.025),(-.02,.2),(.75,.9),"wood")
        return
    if kind == "hose_rack":
        legs(p,1.0,"iron")
        p.box((-.5,.5),(-.4,.4),(.08,.15),"worn_wood")
        p.box((-.48,.48),(-.35,-.28),(.82,.89),"worn_metal")
        for x in (-.25,.25):
            p.ring((x,-.43,.56),.23,.13,.12,"rubber",10,"xz")
        return
    legs(p,1.0)
    for z in (.12,.5,.88):
        p.box((-.5,.5),(-.45,.45),(z,z+.06),"worn_wood")
    if kind == "evidence_shelf":
        for x in (-.3,.05,.3):
            p.box((x-.09,x+.09),(-.32,.22),(.56,.68),"enamel")
    elif kind == "herb_rack":
        for x in (-.3,0,.3):
            p.beam((x,-.25,.56),(x+.04,.28,.65),.035,"cloth",4)


def rail(p, kind):
    if kind in ("inspection_pit","dock_plate","dock_door"):
        p.box((-.49,.49),(-.46,.46),(0,.025),"rubber" if kind=="inspection_pit" else "worn_metal")
        for y in (-.45,.45):
            p.box((-.5,.5),(y-.025,y+.025),(.025,.08),"stone" if kind=="inspection_pit" else "iron")
        for x in (-.48,.48):
            p.box((x-.02,x+.02),(-.45,.45),(.025,.08),"iron")
        if kind != "inspection_pit":
            for i in range(6):
                x=-.4+i*.16
                p.box((x,x+.018),(-.4,.4),(.025,.045),"iron")
            snow(p,(-.45,-.2),(-.35,.2),.045,.025)
        return
    if kind in ("pit_rail_pair","turntable_deck","switch_cluster"):
        for i in range(7):
            x=-.45+i*.15
            p.box((x-.025,x+.025),(-.46,.46),(0,.09),"worn_wood")
        for y in (-.32,.32):
            p.box((-.5,.5),(y-.024,y+.024),(.09,.18),"iron")
        if kind == "turntable_deck":
            p.box((-.49,.49),(-.28,.28),(.09,.13),"worn_metal")
        if kind == "switch_cluster":
            p.beam((-.5,-.2,.2),(.4,.32,.2),.018,"iron",4)
            p.beam((.2,-.43,.2),(.4,-.43,.65),.025,"iron")
            p.box((.3,.5),(-.46,-.4),(.62,.72),"enamel")
        return
    if kind == "turntable_rim":
        for i in range(8):
            x=-.5+i/8
            y=.28*(1-(2*x)**2)
            nx=x+.125
            ny=.28*(1-(2*nx)**2)
            p.beam((x,y,.12),(nx,ny,.12),.03,"iron",4)
            p.box((x-.018,x+.018),(y-.18,y+.18),(0,.06),"worn_wood")
        return
    if kind == "wheelset":
        p.beam((-.48,0,.45),(.48,0,.45),.06,"iron")
        for x in (-.4,.4):
            p.beam((x-.045,0,.45),(x+.045,0,.45),.42,"worn_metal",10)
            p.beam((x-.06,0,.45),(x+.06,0,.45),.14,"iron",8)
        return
    if kind == "siding_buffer":
        for x in (-.35,.35):
            p.beam((x,-.45,0),(x,.15,.8),.06,"iron",4)
            p.beam((x,.45,0),(x,.15,.8),.06,"iron",4)
            p.box((x-.12,x+.12),(-.13,.02),(.65,.9),"rubber")
        p.box((-.5,.5),(.02,.18),(.62,.82),"worn_wood")
        snow(p,(-.48,.48),(.02,.18),.82)
        return
    if kind == "switch_lever":
        p.box((-.45,.45),(-.4,.4),(0,.12),"iron")
        p.beam((0,0,.12),(.28,0,.9),.04,"worn_metal")
        p.box((.1,.44),(-.09,.09),(.85,.95),"wood")
        p.beam((0,0,.3),(-.25,0,.42),.09,"iron",8)


def fence(p, kind):
    if kind in ("garage_door_leaf","plank_patch"):
        for i in range(7):
            x=-.49+i*.14
            p.box((x,x+.132),(-.09,.09),(.02,.96-(i%3)*.02),"worn_wood" if i%2 else "wood")
        for x in (-.4,.4):
            p.box((x-.025,x+.025),(.09,.13),(.15,.82),"iron")
        snow(p,(-.48,.48),(-.1,.12),.96)
        return
    count=5 if kind not in ("bridge_truss","signal_bridge") else 4
    top=.95
    if kind == "signal_bridge":
        for x in (-.47,.47):
            p.box((x-.025,x+.025),(-.3,.3),(0,.88),"iron")
        for z in (.78,.98):
            p.box((-.5,.5),(-.12,.12),(z,z+.04),"worn_metal")
        for x in (-.3,0,.3):
            p.box((x-.045,x+.045),(-.18,-.12),(.65,.82),"iron")
            p.beam((x,-.19,.73),(x,-.205,.73),.026,"glass",8)
        count=7
        for i in range(count):
            x=-.48+i*.137
            p.beam((x,0,.82),(x+.137,0,.98),.012,"iron",4)
        return
    if kind == "bridge_truss":
        for y in (-.4,.4):
            for z in (.06,.96):
                p.box((-.5,.5),(y-.025,y+.025),(z,z+.035),"iron")
            for i in range(4):
                x=-.48+i*.24
                p.beam((x,y,.1),(x+.12,y,.95),.022,"worn_metal",4)
                p.beam((x+.12,y,.95),(x+.24,y,.1),.022,"worn_metal",4)
        return
    for i in range(count):
        x=-.46+i*.92/(count-1)
        p.box((x-.025,x+.025),(-.09,.09),(0,top),"wood")
    for z in (.35,.85):
        p.box((-.5,.5),(-.06,.06),(z,z+.07),"worn_wood")
    if kind in ("plank_fence","windbreak_fence"):
        for i in range(12):
            x=-.48+i*.08
            p.box((x,x+.052),(-.12,-.07),(.1,.96-(i%3)*.03),"worn_wood" if i%2 else "wood")
    snow(p,(-.5,.5),(-.07,.07),.92,.025)


def vegetation(p, kind):
    if kind in ("garden_bed","herb_bed"):
        p.box((-.46,.46),(-.4,.4),(0,.07),"bark")
        for x in (-.48,.48):
            p.box((x-.02,x+.02),(-.45,.45),(0,.15),"wood")
        for y in (-.43,.43):
            p.box((-.5,.5),(y-.02,y+.02),(0,.15),"worn_wood")
        snow(p,(-.44,.44),(-.3,.0),.07,.03)
        if kind == "garden_bed":
            return
    if kind == "hedge":
        for i in range(7):
            x=-.44+i*.147
            p.beam((x,0,0),(x,0,.72),.025,"bark",5)
            p.lathe((x,0),[(.25,.09,.25),(.65,.12,.4),(.93,.04,.18)],"bark",6)
            p.lathe((x,-.02),[(.8,.09,.25),(.96,.035,.15)],"snow",6)
        return
    for i in range(9):
        x=((i*37)%89)/100-.44
        y=((i*23)%79)/100-.39
        h=.3+(i%3)*.15
        p.beam((x,y,.02),(x+.05,y+.04,h),.009,"cloth",4)
        p.beam((x,y,.04),(x-.08,y-.04,h*.7),.008,"worn_wood",4)
        if kind == "reed_clump":
            p.beam((x+.05,y+.04,h*.75),(x+.05,y+.04,h),.025,"bark",5)


def heap(p, kind):
    if kind in ("log_pile","roof_beam_pile"):
        for i in range(5):
            y=(i%3-1)*.28
            z=.15+(i//3)*.28
            if kind == "log_pile":
                p.beam((-.47,y,z),(.47,y,z),.14,"bark",8)
                p.beam((-.48,y,z),(-.47,y,z),.115,"worn_wood",8)
            else:
                p.box((-.49,.49),(y-.11,y+.11),(z-.13,z+.1),"worn_wood")
        snow(p,(-.4,.35),(-.35,-.1),.56,.04)
        return
    if kind == "brake_shoe_pile":
        for i in range(6):
            x=-.35+(i%3)*.34
            y=-.26+(i//3)*.5
            p.beam((x-.1,y,.08),(x,y,.2),.07,"iron",4)
            p.beam((x,y,.2),(x+.12,y,.19),.07,"rust",4)
        return
    for i in range(12):
        x=((i*31)%79)/100-.39
        y=((i*43)%73)/100-.36
        z=.12+(1-abs(x)-abs(y))*.2
        if kind == "roof_tile_heap":
            p.box((x-.12,x+.12),(y-.14,y+.14),(z-.08,z),"stone" if i%2 else "worn_metal")
        else:
            p.lathe((x,y),[(0,.14,.14),(z,.17,.12),(z+.08,.05,.06)],"stone" if i%3 else "rust",5)
    snow(p,(-.1,.2),(-.22,.08),.38,.035)


def wheels(p, ys=(-.32,.32), width=.42, radius=.13, z=.14):
    for y in ys:
        for x in (-width,width):
            p.beam((x-.035,y,z),(x+.035,y,z),radius,"rubber",8)
            p.beam((x-.04,y,z),(x+.04,y,z),radius*.45,"worn_metal",6)


def cart(p, kind):
    wheels(p, radius=.12)
    p.box((-.4,.4),(-.46,.46),(.22,.3),"worn_wood")
    if kind == "platform_cart":
        for x in (-.35,.35):
            p.beam((x,.38,.3),(x,.38,.7),.025,"iron")
        p.beam((-.35,.38,.7),(.35,.38,.7),.025,"iron")
    if kind in ("rail_handcar","hand_pump_cart"):
        p.beam((0,0,.3),(0,0,.8),.07,"iron")
        p.beam((0,-.38,.9),(0,.38,.7),.04,"worn_wood")
        for y,z in ((-.38,.9),(.38,.7)):
            p.beam((-.3,y,z),(.3,y,z),.03,"wood")
        if kind == "hand_pump_cart":
            p.beam((-.22,-.3,.3),(-.22,-.3,.62),.12,"worn_metal",8)
    if kind == "pallet_truck":
        # Remove bulky deck appearance with clearly protruding narrow fork tines.
        for x in (-.25,.25):
            p.box((x-.06,x+.06),(-.9,.1),(.2,.26),"worn_metal")
        p.beam((0,.35,.3),(0,.45,.95),.035,"iron")
        p.ring((0,.45,1.03),.13,.09,.04,"rubber",8,"xz")


def vehicle(p, kind):
    # 앞은 -Y(내보낸 +Z). 차체 가로/세로 비율을 보존해 좁은 rect에도 들어간다.
    length=2.8 if kind in ("log_flatcar","rail_plow","stalled_tram") else 1.7
    width=.45
    wheels(p,ys=(-length*.7,length*.7),width=width,radius=.22,z=.22)
    p.box((-.42,.42),(-length,length),(.34,.58),"worn_metal")
    if kind == "log_flatcar":
        for x in (-.26,0,.26):
            p.beam((x,-length*.9,.76),(x,length*.9,.76),.16,"bark",8)
            p.beam((x,-length*.91,.76),(x,-length*.9,.76),.14,"worn_wood",8)
        p.beam((0,-length*.8,1.04),(0,length*.8,1.04),.16,"bark",8)
        for x in (-.43,.43):
            for y in (-length*.7,length*.7):
                p.beam((x,y,.55),(x,y,1.16),.025,"iron",4)
        snow(p,(-.12,.12),(-length*.7,length*.7),1.16,.035)
        return
    if kind == "stalled_tram":
        p.box((-.42,.42),(-length,length),(.58,.95),"cloth")
        # Open side windows and an unblocked entrance; no opaque window panels.
        for y in (-length,-1.8,-.9,0,.9,1.8,length):
            for x in (-.41,.41):
                p.box((x-.025,x+.025),(y-.035,y+.035),(.95,1.7),"enamel")
        p.box((-.46,.46),(-length,length),(1.7,1.78),"enamel")
        snow(p,(-.43,.43),(-length+.08,length-.08),1.78,.05)
        p.beam((-.25,-length-.02,.78),(.25,-length-.02,.78),.045,"worn_metal")
        return
    cab_y=-.55 if kind in ("fire_engine","tow_truck","rail_plow") else 0
    front=cab_y-.55
    back=cab_y+.4
    body_colour="rust" if kind == "fire_engine" else "iron"
    p.box((-.41,.41),(-length,length),(.58,.78),body_colour)
    # Sloped cabin with separately visible glass; front facing +Z.
    p.box((-.33,.33),(front,back),(.78,1.25),"glass")
    for x in (-.35,.35):
        for y in (front,back):
            p.beam((x,y,.77),(x*.88,y*.95,1.29),.025,body_colour,4)
    p.box((-.36,.36),(front-.02,back+.02),(1.25,1.32),body_colour)
    snow(p,(-.34,.34),(front,back),1.32,.04)
    snow(p,(-.38,.38),(-length,front-.03),.78,.035)
    for x in (-.28,.28):
        p.box((x-.07,x+.07),(-length-.018,-length),(.63,.73),"enamel")
    if kind == "patrol_car":
        p.box((-.22,.22),(-.1,.12),(1.36,1.4),"worn_metal")
    elif kind == "fire_engine":
        p.box((-.42,.42),(.0,length),(.78,1.1),"rust")
        for x in (-.45,.45):
            p.box((x-.015,x+.015),(.1,length-.1),(.82,1.02),"worn_metal")
        for x in (-.22,.22):
            p.beam((x,-.05,1.42),(x,length,1.42),.025,"worn_metal",4)
        for i in range(7):
            y=i*length/7
            p.beam((-.22,y,1.42),(.22,y,1.42),.018,"iron",4)
    elif kind == "tow_truck":
        p.beam((0,.3,.78),(0,1.25,1.8),.07,"iron",4)
        p.beam((0,.6,.78),(0,1.25,1.8),.035,"rust",4)
        p.beam((0,1.25,1.8),(0,1.25,1.3),.012,"iron",4)
        p.beam((0,1.25,1.3),(0,1.37,1.22),.025,"iron",5)
    elif kind == "rail_plow":
        a=(-.65,-length+.2,.35); b=(.65,-length+.2,.35); c=(0,-length-.4,.2)
        d=(-.65,-length+.2,.95); e=(.65,-length+.2,.95); f=(0,-length-.4,.75)
        for pts,out in (([a,c,f,d],(-1,-1,0)),([c,b,e,f],(1,-1,0)),([d,f,e],(0,0,1)),([a,b,c],(0,0,-1)),([a,d,e,b],(0,1,0))):
            p.face(pts,"worn_metal",out)


def boat(p, kind):
    # Pointed bow at -Y; empty cargo hull and no boarding installation.
    p.lathe((0,0),[(0,.27,1.3),(.3,.48,1.65),(.38,.49,1.66)],"worn_wood",8)
    for x in (-.46,.46):
        p.box((x-.03,x+.03),(-1.1,1.1),(.35,.63),"iron")
    p.box((-.4,.4),(-1.1,1.1),(.38,.4),"snow")
    if kind == "fishing_boat":
        p.box((-.3,.3),(.2,.9),(.4,.8),"enamel")
        p.box((-.27,.27),(.23,.87),(.8,1.12),"glass")
        p.box((-.34,.34),(.17,.93),(1.12,1.2),"worn_wood")
        p.beam((0,-.3,.4),(0,-.3,1.45),.025,"wood")
        snow(p,(-.32,.32),(.18,.92),1.2)


def round_item(p, kind):
    if kind == "millstone":
        p.ring((0,0,.17),.5,.09,.3,"stone",12)
        for i in range(6):
            a=i*math.tau/6
            p.beam((.14*math.cos(a),.14*math.sin(a),.325),(.43*math.cos(a+.15),.43*math.sin(a+.15),.325),.008,"iron",4)
    elif kind in ("curing_barrel","hive_box"):
        if kind == "hive_box":
            for i in range(3):
                p.box((-.43,.43),(-.4,.4),(.05+i*.27,.3+i*.27),"worn_wood" if i%2 else "wood")
            p.box((-.3,.3),(-.43,-.4),(.12,.16),"iron")
            snow(p,(-.5,.5),(-.47,.47),.86,.07)
        else:
            p.lathe((0,0),[(0,.32,.32),(.12,.4,.4),(.65,.4,.4),(.8,.33,.33)],"wood",10)
            for z in (.14,.65):
                p.ring((0,0,z),.415,.385,.06,"iron",10)
            p.beam((0,0,.8),(0,0,.84),.32,"worn_wood",10)
    elif kind in ("well_cover","frozen_fountain"):
        p.ring((0,0,.2),.5,.37,.35,"stone",12)
        if kind == "well_cover":
            boards(p,.39,6)
        else:
            p.beam((0,0,.1),(0,0,.15),.36,"glass",12)
            p.beam((0,0,.14),(0,0,.7),.08,"stone",8)
            p.ring((0,0,.72),.25,.17,.12,"stone",10)
            p.beam((0,0,.7),(0,0,.73),.16,"snow",10)
    elif kind in ("grain_silo","water_tower"):
        base=.05 if kind == "grain_silo" else .48
        if kind == "water_tower":
            legs(p,.55,"iron",.28,.28)
            for x in (-.28,.28):
                p.beam((x,-.28,.05),(x,.28,.48),.018,"iron",4)
        p.lathe((0,0),[(base,.4,.4),(.88,.4,.4),(.98,.05,.05)],"worn_metal",12)
        for z in (base+.02,.72):
            p.ring((0,0,z),.412,.39,.025,"iron",12)
        p.lathe((0,0),[(.89,.37,.37),(1.0,.025,.025)],"snow",12)
    elif kind == "mooring_post":
        p.beam((0,0,0),(0,0,.8),.2,"iron",8)
        p.beam((-.4,0,.7),(.4,0,.7),.13,"worn_metal",8)
        p.beam((0,0,.8),(0,0,.84),.21,"snow",8)
    elif kind == "fallen_bell":
        for profile,sign in (([(0,.44),(.18,.36),(.55,.23),(.7,.1)],1),
                             ([(0,.38),(.18,.30),(.55,.17),(.63,.06)],-1)):
            rings=[[(r*math.cos(i*math.tau/12),r*math.sin(i*math.tau/12),z) for i in range(12)] for z,r in profile]
            for lower,upper in zip(rings,rings[1:]):
                for i in range(12):
                    j=(i+1)%12
                    a=(i+.5)*math.tau/12
                    p.face([lower[i],lower[j],upper[j],upper[i]],"rust",(sign*math.cos(a),sign*math.sin(a),0))
        p.beam((0,0,.63),(0,0,.7),.1,"rust",12)
        p.ring((0,0,.04),.5,.38,.08,"worn_metal",12)
        p.ring((0,0,.79),.13,.08,.06,"iron",8,"xz")
        # Tip onto its side, exposing the broad rim.
        from mathutils import Matrix
        turn=Matrix.Rotation(math.radians(72),3,"X")
        for v in p.bm.verts:
            v.co=turn @ v.co


def furniture(p, kind):
    if kind in ("long_table","repair_scaffold","training_frame","playground_frame"):
        legs(p,.85)
        if kind == "long_table":
            boards(p,.85,6)
        elif kind == "repair_scaffold":
            boards(p,.85,6)
            for x in (-.42,.42):
                p.beam((x,-.38,.08),(x,.38,.8),.025,"iron",4)
        else:
            for y in (-.38,.38):
                p.beam((-.44,y,.85),(.44,y,.85),.04,"wood",4)
            for x in (-.4,-.2,0,.2,.4):
                p.beam((x,-.4,.85),(x,.4,.85),.025,"worn_wood",4)
        return
    if kind == "bunk_bed":
        legs(p,1.0,"iron")
        for z in (.18,.69):
            p.box((-.45,.45),(-.4,.4),(z,z+.045),"iron")
            p.box((-.43,.43),(-.37,.37),(z+.045,z+.11),"cloth")
            p.box((-.4,-.22),(-.33,.33),(z+.11,z+.15),"enamel")
        for z in (.25,.48,.71):
            p.beam((.25,-.42,z),(.43,-.42,z),.02,"iron",4)
        return
    if kind == "slate_board":
        for x in (-.4,.4):
            p.beam((x,-.3,0),(x,0,.9),.035,"wood",4)
            p.beam((x,.3,0),(x,0,.9),.035,"wood",4)
        p.box((-.5,.5),(-.08,.04),(.4,1.0),"wood")
        p.box((-.45,.45),(-.09,-.08),(.45,.95),"iron")
        return
    if kind in ("strongbox","chiller_case","bin_bay"):
        if kind == "bin_bay":
            for x in (-.34,0,.34):
                p.box((x-.15,x+.15),(-.4,.4),(0,.8),"worn_metal")
                p.box((x-.16,x+.16),(-.43,.43),(.8,.85),"iron")
                snow(p,(x-.12,x+.12),(-.3,.3),.85,.025)
        else:
            p.box((-.5,.5),(-.4,.4),(0,.95),"enamel" if kind=="chiller_case" else "iron")
            p.box((-.44,.44),(-.42,-.4),(.12,.85),"glass" if kind=="chiller_case" else "worn_metal")
            if kind=="chiller_case":
                for x in (-.16,.16):
                    p.box((x-.01,x+.01),(-.44,-.42),(.1,.87),"iron")
            else:
                p.ring((.15,-.46,.5),.16,.11,.04,"iron",8,"xz")
        return


def machinery(p, kind):
    if kind == "fuel_pump":
        p.box((-.3,.25),(-.28,.3),(0,.85),"enamel")
        p.box((-.22,.17),(-.3,-.28),(.58,.77),"glass")
        p.box((-.18,.12),(-.31,-.3),(.61,.65),"iron")
        points=[(.26,0,.7),(.45,0,.5),(.42,0,.12),(.2,-.25,.12),(.29,-.3,.48)]
        for a,b in zip(points,points[1:]):
            p.beam(a,b,.028,"rubber",6)
        p.beam((.29,-.3,.48),(.3,-.3,.63),.04,"iron",5)
        snow(p,(-.28,.23),(-.27,.28),.85)
    elif kind == "coal_hopper":
        legs(p,.66,"iron",.19,.19)
        p.lathe((0,0),[(.25,.13,.13),(.65,.48,.48),(.9,.48,.48)],"iron",4)
        p.lathe((0,0),[(.9,.43,.43),(.98,.25,.27)],"rubber",6)
    elif kind == "transformer_unit":
        p.box((-.4,.4),(-.3,.3),(0,.68),"worn_metal")
        for x in (-.43,.43):
            for y in (-.28,-.14,0,.14,.28):
                p.box((x-.06,x+.06),(y-.025,y+.025),(.08,.6),"iron")
        for x in (-.25,0,.25):
            p.beam((x,0,.68),(x,0,1.0),.035,"iron",6)
            for z in (.76,.86,.96):
                p.beam((x,0,z),(x,0,z+.025),.07,"enamel",6)
    elif kind in ("lock_wheel","sluice_frame"):
        if kind == "sluice_frame":
            for x in (-.44,.44):
                p.box((x-.035,x+.035),(-.2,.2),(0,.95),"wood")
            p.box((-.48,.48),(-.15,.15),(.9,1.0),"iron")
            p.box((-.4,.4),(-.07,.07),(.05,.65),"worn_wood")
        else:
            p.box((-.28,.28),(-.25,.25),(0,.15),"stone")
        p.beam((0,0,.1),(0,0,.95),.035,"iron")
        p.ring((0,-.12,.9),.22,.17,.04,"iron",12,"xz")
        for a in range(0,360,90):
            r=math.radians(a)
            p.beam((0,-.12,.9),(.18*math.cos(r),-.12,.9+.18*math.sin(r)),.015,"worn_metal",4)
    elif kind == "water_gauge":
        p.box((-.1,.1),(-.12,.12),(0,1),"enamel")
        for i in range(8):
            z=.1+i*.11
            p.box((-.09,.02 if i%2 else .09),(-.13,-.12),(z,z+.022),"iron")
    elif kind == "quay_crane":
        p.box((-.35,.35),(-.35,.35),(0,.12),"stone")
        legs(p,.55,"iron",.23,.23,.1)
        p.box((-.28,.28),(-.28,.28),(.45,.65),"worn_metal")
        p.box((-.2,.2),(-.3,-.28),(.51,.61),"glass")
        p.beam((0,0,.6),(.43,-.4,1.0),.055,"iron",4)
        p.beam((0,.25,.5),(.43,-.4,1.0),.014,"iron",4)
        p.beam((.43,-.4,1.0),(.43,-.4,.45),.008,"iron",4)
        p.beam((.43,-.4,.45),(.37,-.4,.4),.022,"iron",5)
    elif kind == "water_crane":
        p.beam((0,0,0),(0,0,.86),.11,"iron",8)
        p.beam((0,0,.86),(.38,-.26,.86),.08,"worn_metal",8)
        p.beam((.38,-.26,.86),(.38,-.26,.62),.075,"iron",8)
        p.ring((0,-.13,.3),.13,.09,.035,"worn_metal",8,"xz")


def miscellaneous(p, kind):
    if kind in ("flagpole","wind_pole"):
        p.beam((0,0,0),(0,0,1),.025,"worn_metal",8)
        p.beam((0,0,0),(0,0,.06),.12,"stone",8)
        if kind == "flagpole":
            p.box((.025,.36),(-.012,.012),(.78,.97),"cloth")
        else:
            p.beam((.03,0,.9),(.3,0,.72),.08,"cloth",8,tip=.025)
    elif kind == "fallen_pole":
        p.beam((-.5,0,.1),(.5,0,.1),.07,"bark",8)
        p.box((-.32,-.25),(-.38,.38),(.12,.22),"wood")
        for y in (-.3,0,.3):
            p.beam((-.28,y,.22),(-.28,y,.35),.055,"enamel",6)
    elif kind == "laundry_line":
        for x in (-.46,.46):
            p.beam((x,0,0),(x,0,1),.025,"wood",6)
        points=[(-.46,0,.95),(-.15,0,.84),(.16,0,.83),(.46,0,.95)]
        for a,b in zip(points,points[1:]):
            p.beam(a,b,.006,"cloth",4)
    elif kind == "shop_awning":
        for x in (-.47,.47):
            p.beam((x,-.35,0),(x,-.35,.82),.018,"iron",4)
        p.face([(-.5,.45,1),(.5,.45,1),(.5,-.45,.8),(-.5,-.45,.8)],"cloth",(0,0,1))
        p.face([(-.5,-.45,.8),(.5,-.45,.8),(.5,.45,1),(-.5,.45,1)],"cloth",(0,0,-1))
        p.box((-.5,.5),(-.46,-.44),(.73,.8),"cloth")
        for x in (-.3,0,.3):
            p.beam((x,.45,1.01),(x,-.45,.81),.015,"snow",4)
    elif kind == "dock_platform":
        legs(p,.18,"wood")
        boards(p,.18,10)
        snow(p,(-.45,-.15),(-.42,.3),.235,.025)
    elif kind == "anchor":
        p.beam((0,-.35,.08),(0,.35,.08),.055,"iron",6)
        p.beam((-.35,-.16,.08),(.35,-.16,.08),.04,"iron",6)
        for sign in (-1,1):
            p.beam((0,.35,.08),(sign*.38,.18,.08),.055,"iron",6)
            p.beam((sign*.38,.18,.08),(sign*.4,.0,.08),.055,"iron",6,tip=.01)
        p.ring((0,-.42,.08),.1,.065,.06,"iron",8)


RAILS={"inspection_pit","dock_plate","dock_door","pit_rail_pair","turntable_deck","switch_cluster","turntable_rim","wheelset","siding_buffer","switch_lever"}
FENCES={"garage_door_leaf","plank_patch","skybridge_rail","windbreak_fence","plank_fence","bridge_rail","bridge_truss","signal_bridge"}
VEGETATION={"dry_grass","garden_bed","herb_bed","hedge","reed_clump"}
HEAPS={"ballast_pile","rubble_heap","log_pile","roof_beam_pile","roof_tile_heap","brake_shoe_pile"}
CARTS={"hand_pump_cart","rail_handcar","platform_cart","pallet_truck"}
VEHICLES={"log_flatcar","rail_plow","patrol_car","fire_engine","stalled_tram","tow_truck"}
ROUND={"millstone","mooring_post","hive_box","curing_barrel","well_cover","frozen_fountain","grain_silo","water_tower","fallen_bell"}
FURNITURE={"long_table","repair_scaffold","training_frame","playground_frame","bunk_bed","slate_board","strongbox","chiller_case","bin_bay"}
MACHINERY={"fuel_pump","coal_hopper","transformer_unit","lock_wheel","sluice_frame","water_gauge","quay_crane","water_crane"}


def build(p):
    k=p.pid
    for kinds,func in ((RAILS,rail),(FENCES,fence),(VEGETATION,vegetation),(HEAPS,heap),(CARTS,cart),
                       (VEHICLES,vehicle),(ROUND,round_item),(FURNITURE,furniture),(MACHINERY,machinery),
                       ({"evidence_shelf","herb_rack","hose_rack","armory_rack"},shelf),
                       ({"frozen_barge","fishing_boat"},boat)):
        if k in kinds:
            func(p,k)
            return
    miscellaneous(p,k)
    if not p.bm.faces:
        raise ValueError("조형이 없는 종류 "+k)


def export(piece,path):
    mesh=bpy.data.meshes.new(piece.pid)
    piece.bm.to_mesh(mesh)
    mesh.color_attributes.active_color=mesh.color_attributes["Col"]
    mesh.color_attributes.render_color_index=list(mesh.color_attributes).index(mesh.color_attributes["Col"])
    obj=bpy.data.objects.new(piece.pid,mesh)
    bpy.context.scene.collection.objects.link(obj)
    for other in bpy.context.scene.objects:
        other.select_set(other==obj)
    bpy.context.view_layer.objects.active=obj
    try:
        bpy.ops.export_scene.gltf(filepath=str(path),export_format="GLB",use_selection=True,export_yup=True,
            export_apply=False,export_materials="NONE",export_texcoords=False,export_normals=True,
            export_tangents=False,export_vertex_color="ACTIVE",export_extras=False,export_animations=False)
    finally:
        bpy.data.objects.remove(obj,do_unlink=True)
        bpy.data.meshes.remove(mesh)


def check_glb(path,expected_tris):
    data=path.read_bytes()
    magic,version,length=struct.unpack_from("<4sII",data)
    n,ctype=struct.unpack_from("<II",data,12)
    assert magic==b"glTF" and version==2 and length==len(data) and ctype==0x4e4f534a
    book=json.loads(data[20:20+n])
    assert len(book["meshes"])==1 and len(book["meshes"][0]["primitives"])==1
    assert sum("mesh" in node for node in book["nodes"])==1
    prim=book["meshes"][0]["primitives"][0]
    assert prim.get("mode",4)==4 and "COLOR_0" in prim["attributes"]
    assert book["accessors"][prim["indices"]]["count"]==expected_tris*3
    assert not any(book.get(k) for k in ("materials","images","textures","animations","skins","cameras","extensions"))
    assert not any("uri" in b for b in book["buffers"])
    return len(data),hashlib.sha256(data).hexdigest()


def census(repo,assets):
    totals=[]
    found=collections.Counter()
    dictionary_found=collections.Counter()
    placements=[]
    # 지도 원문의 props 사전과 압축 배열 행을 함께 읽는다. 주석 문자열은 배제.
    for path in sorted((repo/"s2/game/world/maps").glob("*.gd")):
        text=path.read_text(encoding="utf-8")
        rows=[]
        for match in re.finditer(r'\{[^{}]*"kind"\s*:\s*"[^"\n]+"[^{}]*\}',text,re.S):
            raw=match.group()
            try:
                row=json.loads(re.sub(r',\s*}', '}',raw))
            except json.JSONDecodeError:
                continue
            if "rect" in row and row["kind"] in assets:
                rows.append(row)
                dictionary_found[row["kind"]]+=1
        for match in re.finditer(r'\[\s*"([a-z_0-9]+)"\s*,\s*\[\s*(-?\d+)\s*,\s*(-?\d+)\s*,\s*(\d+)\s*,\s*(\d+)\s*\]\s*,\s*"(low|wall|none|wagon)"\s*,\s*(\d+)',text):
            k,x,y,w,d,solid,facing=match.groups()
            if k in assets:
                rows.append({"kind":k,"rect":[int(x),int(y),int(w),int(d)],"solid":solid,"facing":int(facing)})
        count=collections.Counter(r["kind"] for r in rows)
        found.update(count)
        total=sum(assets[k]["lod0_tris"]*v for k,v in count.items())
        totals.append({"map":path.name,"instances":sum(count.values()),"triangles":total,"counts":dict(count)})
        for row in rows:
            a=assets[row["kind"]]
            w,h,d=a["dimensions_m"]
            if int(row.get("facing",0))%2:
                w,d=d,w
            if w>row["rect"][2]*1.05 or d>row["rect"][3]*1.05:
                placements.append({"map":path.name,"kind":row["kind"],"rect":row["rect"],"facing":row.get("facing",0)})
    mismatches={k:[assets[k]["source_rect_count"],dictionary_found[k]] for k in assets if dictionary_found[k]!=assets[k]["source_rect_count"]}
    assert not mismatches, "원문 빈도 불일치: "+str(mismatches)
    return {"files":len(totals),"instances":sum(found.values()),"scope":"E 78종만, 원문 rect 빈도, LOD0, 가림 제거 전",
            "input_dictionary_instances":sum(dictionary_found.values()),
            "extra_compact_rows":{k:found[k]-dictionary_found[k] for k in found if found[k]!=dictionary_found[k]},
            "max_map":max(totals,key=lambda r:r["triangles"]),"maps":totals,"placement_overflow":placements}


def write_books(repo,assets,failures):
    out=repo/"s2/models/props_field"
    placement="rect 가운데 바닥, +Y 위·+Z 앞, facing은 +Y축 -90도씩. 발자국 96% 안쪽. 현재 map_view는 XZ 자동 맞춤을 하지 않는다."
    book={"version":1,"batch":"e","input":"_in/kinds_e.json","input_sha256":SOURCE_SHA256,
          "expected_kinds":[r["kind"] for r in SOURCE["kinds"]],"blender":bpy.app.version_string,
          "palette":PALETTE,"colour_encoding":"linear RGBA vertex Col, alpha 1",
          "axis":"+Y up, +Z front","origin":"footprint_center_floor","placement":placement,
          "assets":assets,"skipped":{},"failures":failures}
    if len(assets)==78:
        book["census"]=census(repo,assets)
    (out/"catalog_e.json").write_text(json.dumps(book,ensure_ascii=False,indent=2)+"\n",encoding="utf-8")
    lines=["# 지도 조립 소품 E", "", "`tools/blender/props_field_e.py` 자동 장부. 입력 201~278위, 78종·199개.","",placement,"",
           "재질·그림·빛·애니메이션 없는 단일 메시/단일 surface, 정점색 Col, 각 600삼각형 이하.",
           "차량·선박은 +Z 앞과 평면 비율을 보존하므로 긴 가로 rect를 다 채우지 않을 수 있다.","",
           "| 이름 | 수 | 발자국 m | 높이 m | solid | 삼각형 | 바이트 | SHA-256 | 놓는 법 | 판단 |",
           "|---|---:|---|---:|---|---:|---:|---|---|---|"]
    for k,a in assets.items():
        lines.append(f'| `{k}` | {a["source_rect_count"]} | {a["footprint_m"][0]}×{a["footprint_m"][1]} | {a["height_m"]} | {a["solid"]} | {a["lod0_tris"]} | {a["bytes"]} | `{a["sha256"]}` | rect 중앙 바닥/facing | {a["judgment"]} |')
    lines += ["","## 팔레트 (선형 RGBA)",""]+[f"- `{k}`: {v}" for k,v in PALETTE.items()]
    lines += ["","제외 없음. 자세한 명령·검사 출력·배치 위험은 루트 `_result_props_e.md`."]
    (out/"README_e.md").write_text("\n".join(lines)+"\n",encoding="utf-8")


def preview(repo):
    # GLB를 다시 열어 실제 출력물을 렌더. 미리보기만 캐시에 남기며 GLB에는 쓰지 않는다.
    out=repo/"s2/.godot/e-preview"
    out.mkdir(parents=True,exist_ok=True)
    keys=list(DESIGNS)
    scene=bpy.context.scene
    scene.render.engine="BLENDER_WORKBENCH"
    scene.render.image_settings.file_format="PNG"
    scene.render.resolution_x=1800
    scene.render.resolution_y=1500
    scene.render.resolution_percentage=100
    if scene.world is None:
        scene.world=bpy.data.worlds.new("preview_world")
    scene.world.color=(.14,.16,.18)
    scene.display.shading.light="STUDIO"
    scene.display.shading.color_type="VERTEX"
    scene.display.shading.show_shadows=True
    scene.display.shading.show_cavity=True
    scene.display.shading.cavity_type="BOTH"
    scene.display.shading.background_type="WORLD"
    scene.view_settings.view_transform="Standard"
    for page in range(3):
        bpy.ops.object.select_all(action="SELECT")
        bpy.ops.object.delete(use_global=False)
        direction=Vector((3,-5,4)).normalized()
        rotation=direction.to_track_quat("Z","Y")
        right=rotation @ Vector((1,0,0))
        up=rotation @ Vector((0,1,0))
        for index,k in enumerate(keys[page*26:(page+1)*26]):
            before=set(bpy.data.objects)
            bpy.ops.import_scene.gltf(filepath=str(repo/"s2/models/props_field"/(k+".glb")))
            objects=[o for o in bpy.data.objects if o not in before and o.type=="MESH"]
            bounds=[o.matrix_world @ Vector(v) for o in objects for v in o.bound_box]
            low=Vector([min(p[i] for p in bounds) for i in range(3)])
            high=Vector([max(p[i] for p in bounds) for i in range(3)])
            center=(low+high)*.5
            scale=1.7/max(high-low)
            cell=right*((index%6-2.5)*2.6)+up*((2-index//6)*2.55)
            for o in objects:
                o.matrix_world.translation=(o.matrix_world.translation-center)*scale+cell
                o.scale*=scale
            curve=bpy.data.curves.new("label","FONT")
            curve.body=k
            curve.size=.135
            curve.align_x="CENTER"
            label=bpy.data.objects.new("label",curve)
            scene.collection.objects.link(label)
            label.rotation_euler=rotation.to_euler()
            label.location=cell-up*1.04+direction*.8
            label.color=(.85,.9,.93,1)
        camdata=bpy.data.cameras.new("preview")
        cam=bpy.data.objects.new("preview",camdata)
        scene.collection.objects.link(cam)
        cam.location=direction*30
        cam.rotation_euler=rotation.to_euler()
        camdata.type="ORTHO"
        camdata.ortho_scale=16.1
        scene.camera=cam
        scene.render.filepath=str(out/f"sheet_{page+1}.png")
        bpy.ops.render.render(write_still=True)
        print("PREVIEW_READY sheet_%d.png"%(page+1),flush=True)


def main():
    parser=argparse.ArgumentParser()
    parser.add_argument("--repo",required=True)
    parser.add_argument("--preview",action="store_true")
    args=parser.parse_args(sys.argv[sys.argv.index("--")+1:] if "--" in sys.argv else [])
    repo=Path(args.repo).resolve()
    bpy.ops.wm.read_factory_settings(use_empty=True)
    if args.preview:
        preview(repo)
        return
    assert SOURCE is not None
    assert len(SOURCE["kinds"])==78 and sum(r["count"] for r in SOURCE["kinds"])==199
    assert set(DESIGNS)=={r["kind"] for r in SOURCE["kinds"]}
    out=repo/"s2/models/props_field"
    out.mkdir(parents=True,exist_ok=True)
    assets={}
    failures=[]
    for row in sorted(SOURCE["kinds"],key=lambda r:(-r["count"],r["rank"])):
        k=row["kind"]
        p=Piece(k)
        try:
            height,judgment=DESIGNS[k]
            footprint=row["rects_wh_top"][0][0]
            build(p)
            keep=k in VEHICLES or k in ("frozen_barge","fishing_boat")
            # 얇은 문판·난간·눈금판까지 rect의 깊이만큼 부풀리지 않는다.
            fit_footprint=list(footprint)
            if k in FENCES and k not in ("bridge_truss","signal_bridge"):
                fit_footprint[1]=min(footprint[1],.22)
            if k=="water_gauge":
                fit_footprint=[.22,.08]
            p.fit(fit_footprint,height,keep)
            tris=len(p.bm.faces)
            assert 0<tris<=TRIANGLE_LIMIT,(k,tris)
            bounds=p.bounds()
            path=out/(k+".glb")
            export(p,path)
            size,digest=check_glb(path,tris)
            assets[k]={"path":"res://models/props_field/"+k+".glb","status":"ready",
                "footprint_m":footprint,"height_m":height,"source_rect_count":row["count"],"rank":row["rank"],
                "solid":row["solid"],"facing":row["facing"],"map_families":row["map_families"],
                "rects_wh_top":row["rects_wh_top"],"lod0_tris":tris,"triangle_limit":600,
                "bounds_m":bounds,"dimensions_m":[round(bounds[1][i]-bounds[0][i],5) for i in range(3)],
                "bytes":size,"sha256":digest,"colours":sorted(p.colours),"judgment":judgment,
                "horizontal_fit":"preserve_aspect" if keep else "modal_rect_inset_4_percent",
                "placement":"rect 중앙 바닥, +Y 위/+Z 앞, facing -90도씩"}
            print(f"PROP_READY {k} tris={tris} bytes={size}",flush=True)
        except Exception as error:
            failures.append({"kind":k,"error":str(error)})
            print(f"PROP_FAILED {k} {error}",flush=True)
        finally:
            p.bm.free()
    write_books(repo,assets,failures)
    print(f"PROPS_FIELD_E generated={len(assets)} expected=78 failures={len(failures)}",flush=True)
    if failures:
        raise SystemExit(1)


if __name__=="__main__":
    main()
