# 이 지도가 다른 판단을 만드는 것: 언덕의 큰 집과 회관 사이 땅길을 쓸지, 지하 통로로 돌아 얼음 굴의 저장품을 옮길지 고른다.
extends RefCounted
## 셋째 판. 1칸은 1m. 물가의 연속된 얼음은 걸을 수 있으며 지도 끝이 깊은 물이다.
## 지하와 위층은 같은 칸의 계단으로 잇고, 깊은 창고는 순환 통로와 세 저장 주머니로 나눈다.

const FieldGrid = preload("res://game/world/field_grid.gd")
const S = FieldGrid.Solid
const F = FieldGrid.Floor

const WIDTH: int = 164

const HEIGHT: int = 110

const PLACE_ID: String = "lake_09"

const LAKE_SIDE: String = "lower"

const TRAIN: Rect2i = Rect2i(42, 57, 80, 3)

const BANDS: Dictionary = {"upper": Rect2i(22, 35, 120, 22), "lower": Rect2i(22, 60, 120, 23)}

const ZONE_NAMES: Dictionary = {"A":"얼음 어장","B":"언덕 어장 마을","C":"잔교 작업장","D":"얼음 굴 창고","":"바깥"}
## 무전 문장에 쓰는 들어오는 길의 이름, 길마다의 비중, 첫 물결이 오는 길.
const ENTRY_NAMES: Dictionary = {"shore_west": "서쪽 호숫가", "shore_east": "동쪽 호숫가", "village_back": "마을 뒤쪽"}
const ENTRY_WEIGHTS: Dictionary = {"shore_west": 0.4, "shore_east": 0.4, "village_back": 0.2}
const FIRST_ENTRY: String = "shore_west"

const FLOOR_PATCHES: Array = [
	[Rect2i(0, 60, 164, 50), F.ICE],
	[Rect2i(25, 4, 76, 49), F.GRAVEL],
	[Rect2i(0, 57, 164, 3), F.RAIL],
	[Rect2i(39, 54, 86, 3), F.PLATFORM],
	[Rect2i(39, 60, 86, 3), F.PLATFORM],
	[Rect2i(78, 60, 3, 33), F.WOOD],
	[Rect2i(69, 91, 24, 14), F.PLATFORM],
	[Rect2i(64, 96, 4, 3), F.GRAVEL],
	[Rect2i(52, 52, 4, 2), F.DEEP_SNOW],
	[Rect2i(37, 27, 4, 2), F.DEEP_SNOW],
	[Rect2i(14, 54, 1, 1), F.GRAVEL],
	[Rect2i(34, 54, 1, 1), F.GRAVEL],
	[Rect2i(53, 53, 1, 1), F.GRAVEL],
	[Rect2i(72, 52, 1, 1), F.GRAVEL],
	[Rect2i(93, 53, 1, 1), F.GRAVEL],
	[Rect2i(113, 53, 1, 1), F.GRAVEL],
	[Rect2i(134, 54, 1, 1), F.GRAVEL],
	[Rect2i(10, 75, 1, 1), F.GRAVEL],
	[Rect2i(13, 77, 1, 1), F.GRAVEL],
	[Rect2i(17, 76, 1, 1), F.GRAVEL],
	[Rect2i(38, 80, 1, 1), F.GRAVEL],
	[Rect2i(41, 82, 1, 1), F.GRAVEL],
	[Rect2i(45, 81, 1, 1), F.GRAVEL],
	[Rect2i(67, 75, 1, 1), F.GRAVEL],
	[Rect2i(70, 77, 1, 1), F.GRAVEL],
	[Rect2i(74, 76, 1, 1), F.GRAVEL],
	[Rect2i(95, 80, 1, 1), F.GRAVEL],
	[Rect2i(98, 82, 1, 1), F.GRAVEL],
	[Rect2i(102, 81, 1, 1), F.GRAVEL],
	[Rect2i(128, 74, 1, 1), F.GRAVEL],
	[Rect2i(131, 76, 1, 1), F.GRAVEL],
	[Rect2i(135, 75, 1, 1), F.GRAVEL],
	[Rect2i(0, 54, 1, 1), F.ROAD],
	[Rect2i(0, 55, 1, 1), F.ROAD],
	[Rect2i(0, 56, 1, 1), F.ROAD],
	[Rect2i(0, 55, 1, 1), F.ROAD],
	[Rect2i(0, 56, 1, 1), F.ROAD],
	[Rect2i(163, 44, 1, 1), F.ROAD],
	[Rect2i(163, 45, 1, 1), F.ROAD],
	[Rect2i(163, 46, 1, 1), F.ROAD],
	[Rect2i(163, 47, 1, 1), F.ROAD],
	[Rect2i(163, 48, 1, 1), F.ROAD],
	[Rect2i(163, 49, 1, 1), F.ROAD],
	[Rect2i(163, 50, 1, 1), F.ROAD],
	[Rect2i(163, 51, 1, 1), F.ROAD],
	[Rect2i(163, 52, 1, 1), F.ROAD],
	[Rect2i(163, 53, 1, 1), F.ROAD],
	[Rect2i(163, 54, 1, 1), F.ROAD],
	[Rect2i(163, 55, 1, 1), F.ROAD],
	[Rect2i(163, 56, 1, 1), F.ROAD],
	[Rect2i(163, 45, 1, 1), F.ROAD],
	[Rect2i(163, 46, 1, 1), F.ROAD],
	[Rect2i(163, 47, 1, 1), F.ROAD],
	[Rect2i(163, 48, 1, 1), F.ROAD],
	[Rect2i(163, 49, 1, 1), F.ROAD],
	[Rect2i(163, 50, 1, 1), F.ROAD],
	[Rect2i(163, 51, 1, 1), F.ROAD],
	[Rect2i(163, 52, 1, 1), F.ROAD],
	[Rect2i(163, 53, 1, 1), F.ROAD],
	[Rect2i(163, 54, 1, 1), F.ROAD],
	[Rect2i(163, 55, 1, 1), F.ROAD],
	[Rect2i(163, 56, 1, 1), F.ROAD],
	[Rect2i(103, 0, 1, 1), F.ROAD],
	[Rect2i(103, 1, 1, 1), F.ROAD],
	[Rect2i(103, 2, 1, 1), F.ROAD],
	[Rect2i(103, 3, 1, 1), F.ROAD],
	[Rect2i(103, 4, 1, 1), F.ROAD],
	[Rect2i(103, 5, 1, 1), F.ROAD],
	[Rect2i(103, 6, 1, 1), F.ROAD],
	[Rect2i(103, 7, 1, 1), F.ROAD],
	[Rect2i(103, 8, 1, 1), F.ROAD],
	[Rect2i(103, 9, 1, 1), F.ROAD],
	[Rect2i(103, 10, 1, 1), F.ROAD],
	[Rect2i(103, 11, 1, 1), F.ROAD],
	[Rect2i(103, 12, 1, 1), F.ROAD],
	[Rect2i(103, 13, 1, 1), F.ROAD],
	[Rect2i(103, 14, 1, 1), F.ROAD],
	[Rect2i(103, 15, 1, 1), F.ROAD],
	[Rect2i(103, 16, 1, 1), F.ROAD],
	[Rect2i(103, 17, 1, 1), F.ROAD],
	[Rect2i(103, 18, 1, 1), F.ROAD],
	[Rect2i(103, 19, 1, 1), F.ROAD],
	[Rect2i(103, 20, 1, 1), F.ROAD],
	[Rect2i(103, 21, 1, 1), F.ROAD],
	[Rect2i(103, 22, 1, 1), F.ROAD],
	[Rect2i(103, 23, 1, 1), F.ROAD],
	[Rect2i(103, 24, 1, 1), F.ROAD],
	[Rect2i(103, 25, 1, 1), F.ROAD],
	[Rect2i(103, 26, 1, 1), F.ROAD],
	[Rect2i(103, 27, 1, 1), F.ROAD],
	[Rect2i(103, 28, 1, 1), F.ROAD],
	[Rect2i(103, 29, 1, 1), F.ROAD],
	[Rect2i(103, 30, 1, 1), F.ROAD],
	[Rect2i(103, 31, 1, 1), F.ROAD],
	[Rect2i(103, 32, 1, 1), F.ROAD],
	[Rect2i(103, 33, 1, 1), F.ROAD],
	[Rect2i(103, 34, 1, 1), F.ROAD],
	[Rect2i(103, 35, 1, 1), F.ROAD],
	[Rect2i(103, 36, 1, 1), F.ROAD],
	[Rect2i(103, 37, 1, 1), F.ROAD],
	[Rect2i(103, 38, 1, 1), F.ROAD],
	[Rect2i(103, 39, 1, 1), F.ROAD],
	[Rect2i(103, 40, 1, 1), F.ROAD],
	[Rect2i(103, 41, 1, 1), F.ROAD],
	[Rect2i(103, 42, 1, 1), F.ROAD],
	[Rect2i(103, 43, 1, 1), F.ROAD],
	[Rect2i(103, 44, 1, 1), F.ROAD],
	[Rect2i(103, 45, 1, 1), F.ROAD],
	[Rect2i(103, 46, 1, 1), F.ROAD],
	[Rect2i(103, 47, 1, 1), F.ROAD],
	[Rect2i(103, 48, 1, 1), F.ROAD],
	[Rect2i(103, 49, 1, 1), F.ROAD],
	[Rect2i(103, 50, 1, 1), F.ROAD],
	[Rect2i(103, 51, 1, 1), F.ROAD],
	[Rect2i(103, 52, 1, 1), F.ROAD],
	[Rect2i(103, 53, 1, 1), F.ROAD],
	[Rect2i(104, 0, 1, 1), F.ROAD],
	[Rect2i(104, 1, 1, 1), F.ROAD],
	[Rect2i(104, 2, 1, 1), F.ROAD],
	[Rect2i(104, 3, 1, 1), F.ROAD],
	[Rect2i(104, 4, 1, 1), F.ROAD],
	[Rect2i(104, 5, 1, 1), F.ROAD],
	[Rect2i(104, 6, 1, 1), F.ROAD],
	[Rect2i(104, 7, 1, 1), F.ROAD],
	[Rect2i(104, 8, 1, 1), F.ROAD],
	[Rect2i(104, 9, 1, 1), F.ROAD],
	[Rect2i(104, 10, 1, 1), F.ROAD],
	[Rect2i(104, 11, 1, 1), F.ROAD],
	[Rect2i(104, 12, 1, 1), F.ROAD],
	[Rect2i(104, 13, 1, 1), F.ROAD],
	[Rect2i(104, 14, 1, 1), F.ROAD],
	[Rect2i(104, 15, 1, 1), F.ROAD],
	[Rect2i(104, 16, 1, 1), F.ROAD],
	[Rect2i(104, 17, 1, 1), F.ROAD],
	[Rect2i(104, 18, 1, 1), F.ROAD],
	[Rect2i(104, 19, 1, 1), F.ROAD],
	[Rect2i(104, 20, 1, 1), F.ROAD],
	[Rect2i(104, 21, 1, 1), F.ROAD],
	[Rect2i(104, 22, 1, 1), F.ROAD],
	[Rect2i(104, 23, 1, 1), F.ROAD],
	[Rect2i(104, 24, 1, 1), F.ROAD],
	[Rect2i(104, 25, 1, 1), F.ROAD],
	[Rect2i(104, 26, 1, 1), F.ROAD],
	[Rect2i(104, 27, 1, 1), F.ROAD],
	[Rect2i(104, 28, 1, 1), F.ROAD],
	[Rect2i(104, 29, 1, 1), F.ROAD],
	[Rect2i(104, 30, 1, 1), F.ROAD],
	[Rect2i(104, 31, 1, 1), F.ROAD],
	[Rect2i(104, 32, 1, 1), F.ROAD],
	[Rect2i(104, 33, 1, 1), F.ROAD],
	[Rect2i(104, 34, 1, 1), F.ROAD],
	[Rect2i(104, 35, 1, 1), F.ROAD],
	[Rect2i(104, 36, 1, 1), F.ROAD],
	[Rect2i(104, 37, 1, 1), F.ROAD],
	[Rect2i(104, 38, 1, 1), F.ROAD],
	[Rect2i(104, 39, 1, 1), F.ROAD],
	[Rect2i(104, 40, 1, 1), F.ROAD],
	[Rect2i(104, 41, 1, 1), F.ROAD],
	[Rect2i(104, 42, 1, 1), F.ROAD],
	[Rect2i(104, 43, 1, 1), F.ROAD],
	[Rect2i(104, 44, 1, 1), F.ROAD],
	[Rect2i(104, 45, 1, 1), F.ROAD],
	[Rect2i(104, 46, 1, 1), F.ROAD],
	[Rect2i(104, 47, 1, 1), F.ROAD],
	[Rect2i(104, 48, 1, 1), F.ROAD],
	[Rect2i(104, 49, 1, 1), F.ROAD],
	[Rect2i(104, 50, 1, 1), F.ROAD],
	[Rect2i(104, 51, 1, 1), F.ROAD],
	[Rect2i(104, 52, 1, 1), F.ROAD],
	[Rect2i(104, 53, 1, 1), F.ROAD],
	[Rect2i(41, 51, 1, 1), F.ROAD],
	[Rect2i(41, 52, 1, 1), F.ROAD],
	[Rect2i(41, 53, 1, 1), F.ROAD],
	[Rect2i(58, 51, 1, 1), F.ROAD],
	[Rect2i(58, 52, 1, 1), F.ROAD],
	[Rect2i(58, 53, 1, 1), F.ROAD],
	[Rect2i(75, 51, 1, 1), F.ROAD],
	[Rect2i(75, 52, 1, 1), F.ROAD],
	[Rect2i(75, 53, 1, 1), F.ROAD],
	[Rect2i(44, 25, 1, 1), F.ROAD],
	[Rect2i(44, 26, 1, 1), F.ROAD],
	[Rect2i(44, 27, 1, 1), F.ROAD],
	[Rect2i(44, 28, 1, 1), F.ROAD],
	[Rect2i(44, 29, 1, 1), F.ROAD],
	[Rect2i(44, 30, 1, 1), F.ROAD],
	[Rect2i(44, 31, 1, 1), F.ROAD],
	[Rect2i(44, 32, 1, 1), F.ROAD],
	[Rect2i(44, 33, 1, 1), F.ROAD],
	[Rect2i(44, 34, 1, 1), F.ROAD],
	[Rect2i(44, 35, 1, 1), F.ROAD],
	[Rect2i(44, 36, 1, 1), F.ROAD],
	[Rect2i(44, 37, 1, 1), F.ROAD],
	[Rect2i(44, 38, 1, 1), F.ROAD],
	[Rect2i(45, 38, 1, 1), F.ROAD],
	[Rect2i(46, 38, 1, 1), F.ROAD],
	[Rect2i(47, 38, 1, 1), F.ROAD],
	[Rect2i(48, 38, 1, 1), F.ROAD],
	[Rect2i(49, 38, 1, 1), F.ROAD],
	[Rect2i(49, 39, 1, 1), F.ROAD],
	[Rect2i(49, 40, 1, 1), F.ROAD],
	[Rect2i(49, 41, 1, 1), F.ROAD],
	[Rect2i(49, 42, 1, 1), F.ROAD],
	[Rect2i(49, 43, 1, 1), F.ROAD],
	[Rect2i(49, 44, 1, 1), F.ROAD],
	[Rect2i(49, 45, 1, 1), F.ROAD],
	[Rect2i(49, 46, 1, 1), F.ROAD],
	[Rect2i(49, 47, 1, 1), F.ROAD],
	[Rect2i(49, 48, 1, 1), F.ROAD],
	[Rect2i(49, 49, 1, 1), F.ROAD],
	[Rect2i(49, 50, 1, 1), F.ROAD],
	[Rect2i(49, 51, 1, 1), F.ROAD],
	[Rect2i(48, 51, 1, 1), F.ROAD],
	[Rect2i(47, 51, 1, 1), F.ROAD],
	[Rect2i(46, 51, 1, 1), F.ROAD],
	[Rect2i(45, 51, 1, 1), F.ROAD],
	[Rect2i(44, 51, 1, 1), F.ROAD],
	[Rect2i(44, 52, 1, 1), F.ROAD],
	[Rect2i(44, 53, 1, 1), F.ROAD],
	[Rect2i(78, 25, 1, 1), F.ROAD],
	[Rect2i(78, 26, 1, 1), F.ROAD],
	[Rect2i(78, 27, 1, 1), F.ROAD],
	[Rect2i(78, 28, 1, 1), F.ROAD],
	[Rect2i(78, 29, 1, 1), F.ROAD],
	[Rect2i(78, 30, 1, 1), F.ROAD],
	[Rect2i(78, 31, 1, 1), F.ROAD],
	[Rect2i(78, 32, 1, 1), F.ROAD],
	[Rect2i(78, 33, 1, 1), F.ROAD],
	[Rect2i(78, 34, 1, 1), F.ROAD],
	[Rect2i(78, 35, 1, 1), F.ROAD],
	[Rect2i(78, 36, 1, 1), F.ROAD],
	[Rect2i(78, 37, 1, 1), F.ROAD],
	[Rect2i(78, 38, 1, 1), F.ROAD],
	[Rect2i(77, 38, 1, 1), F.ROAD],
	[Rect2i(76, 38, 1, 1), F.ROAD],
	[Rect2i(75, 38, 1, 1), F.ROAD],
	[Rect2i(74, 38, 1, 1), F.ROAD],
	[Rect2i(73, 38, 1, 1), F.ROAD],
	[Rect2i(72, 38, 1, 1), F.ROAD],
	[Rect2i(71, 38, 1, 1), F.ROAD],
	[Rect2i(70, 38, 1, 1), F.ROAD],
	[Rect2i(69, 38, 1, 1), F.ROAD],
	[Rect2i(68, 38, 1, 1), F.ROAD],
	[Rect2i(68, 39, 1, 1), F.ROAD],
	[Rect2i(68, 40, 1, 1), F.ROAD],
	[Rect2i(68, 41, 1, 1), F.ROAD],
	[Rect2i(68, 42, 1, 1), F.ROAD],
	[Rect2i(68, 43, 1, 1), F.ROAD],
	[Rect2i(68, 44, 1, 1), F.ROAD],
	[Rect2i(68, 45, 1, 1), F.ROAD],
	[Rect2i(68, 46, 1, 1), F.ROAD],
	[Rect2i(68, 47, 1, 1), F.ROAD],
	[Rect2i(68, 48, 1, 1), F.ROAD],
	[Rect2i(68, 49, 1, 1), F.ROAD],
	[Rect2i(68, 50, 1, 1), F.ROAD],
	[Rect2i(68, 51, 1, 1), F.ROAD],
	[Rect2i(68, 52, 1, 1), F.ROAD],
	[Rect2i(68, 53, 1, 1), F.ROAD],
	[Rect2i(137, 30, 1, 1), F.ROAD],
	[Rect2i(137, 31, 1, 1), F.ROAD],
	[Rect2i(137, 32, 1, 1), F.ROAD],
	[Rect2i(137, 33, 1, 1), F.ROAD],
	[Rect2i(137, 34, 1, 1), F.ROAD],
	[Rect2i(137, 35, 1, 1), F.ROAD],
	[Rect2i(137, 36, 1, 1), F.ROAD],
	[Rect2i(137, 37, 1, 1), F.ROAD],
	[Rect2i(137, 38, 1, 1), F.ROAD],
	[Rect2i(137, 39, 1, 1), F.ROAD],
	[Rect2i(137, 40, 1, 1), F.ROAD],
	[Rect2i(137, 41, 1, 1), F.ROAD],
	[Rect2i(137, 42, 1, 1), F.ROAD],
	[Rect2i(137, 43, 1, 1), F.ROAD],
	[Rect2i(137, 44, 1, 1), F.ROAD],
	[Rect2i(137, 45, 1, 1), F.ROAD],
	[Rect2i(137, 46, 1, 1), F.ROAD],
	[Rect2i(137, 47, 1, 1), F.ROAD],
	[Rect2i(137, 48, 1, 1), F.ROAD],
	[Rect2i(137, 49, 1, 1), F.ROAD],
	[Rect2i(137, 50, 1, 1), F.ROAD],
	[Rect2i(137, 51, 1, 1), F.ROAD],
	[Rect2i(137, 52, 1, 1), F.ROAD],
	[Rect2i(137, 53, 1, 1), F.ROAD],
	[Rect2i(137, 54, 1, 1), F.ROAD],
	[Rect2i(137, 55, 1, 1), F.ROAD],
	[Rect2i(137, 56, 1, 1), F.ROAD],
	[Rect2i(137, 33, 1, 1), F.ROAD],
	[Rect2i(137, 34, 1, 1), F.ROAD],
	[Rect2i(137, 35, 1, 1), F.ROAD],
	[Rect2i(137, 36, 1, 1), F.ROAD],
	[Rect2i(137, 37, 1, 1), F.ROAD],
	[Rect2i(137, 38, 1, 1), F.ROAD],
	[Rect2i(137, 39, 1, 1), F.ROAD],
	[Rect2i(137, 40, 1, 1), F.ROAD],
	[Rect2i(137, 41, 1, 1), F.ROAD],
	[Rect2i(137, 42, 1, 1), F.ROAD],
	[Rect2i(137, 43, 1, 1), F.ROAD],
	[Rect2i(137, 44, 1, 1), F.ROAD],
	[Rect2i(137, 45, 1, 1), F.ROAD],
	[Rect2i(137, 46, 1, 1), F.ROAD],
	[Rect2i(137, 47, 1, 1), F.ROAD],
	[Rect2i(137, 48, 1, 1), F.ROAD],
	[Rect2i(137, 49, 1, 1), F.ROAD],
	[Rect2i(137, 50, 1, 1), F.ROAD],
	[Rect2i(137, 51, 1, 1), F.ROAD],
	[Rect2i(137, 52, 1, 1), F.ROAD],
	[Rect2i(137, 53, 1, 1), F.ROAD],
	[Rect2i(137, 54, 1, 1), F.ROAD],
	[Rect2i(137, 55, 1, 1), F.ROAD],
	[Rect2i(136, 55, 1, 1), F.ROAD],
	[Rect2i(135, 55, 1, 1), F.ROAD],
	[Rect2i(134, 55, 1, 1), F.ROAD],
	[Rect2i(133, 55, 1, 1), F.ROAD],
	[Rect2i(132, 55, 1, 1), F.ROAD],
	[Rect2i(131, 55, 1, 1), F.ROAD],
	[Rect2i(130, 55, 1, 1), F.ROAD],
	[Rect2i(129, 55, 1, 1), F.ROAD],
	[Rect2i(128, 55, 1, 1), F.ROAD],
	[Rect2i(127, 55, 1, 1), F.ROAD],
	[Rect2i(126, 55, 1, 1), F.ROAD],
	[Rect2i(125, 55, 1, 1), F.ROAD],
	[Rect2i(149, 87, 4, 3), F.GRAVEL],
	[Rect2i(130, 91, 4, 3), F.GRAVEL],
	[Rect2i(153, 103, 4, 3), F.GRAVEL],
]

const BUILDING_ROWS: Array = [
	["어장 주택", Rect2i(35, 39, 14, 12)],
	["어장 주택", Rect2i(52, 36, 14, 12)],
	["어장 주택", Rect2i(69, 39, 14, 12)],
	["어장 큰 집", Rect2i(36, 9, 18, 16)],
	["마을 회관", Rect2i(68, 9, 22, 16)],
	["얼음 굴 창고", Rect2i(116, 3, 44, 27)],
	["얼음 낚시 움막", Rect2i(12, 67, 7, 7)],
	["얼음 낚시 움막", Rect2i(40, 72, 7, 7)],
	["얼음 낚시 움막", Rect2i(69, 67, 7, 7)],
	["얼음 낚시 움막", Rect2i(97, 72, 7, 7)],
	["얼음 낚시 움막", Rect2i(130, 66, 7, 7)],
]

const LEVEL_ROWS: Array = [
	[1, 3, Rect2i(36, 9, 18, 16)],
	[1, 4, Rect2i(68, 9, 22, 16)],
	[-1, 3, Rect2i(36, 9, 18, 16)],
	[-1, 4, Rect2i(68, 9, 22, 16)],
	[-1, 5, Rect2i(116, 3, 44, 27)],
	[-1, 3, Rect2i(51, 15, 20, 5)],
]

const WALL_ROWS: Array = [
	[0, Rect2i(42, 40, 1, 10)],
	[0, Rect2i(59, 37, 1, 10)],
	[0, Rect2i(76, 40, 1, 10)],
	[0, Rect2i(45, 10, 1, 14)],
	[0, Rect2i(79, 10, 1, 14)],
	[0, Rect2i(121, 7, 34, 1)],
	[0, Rect2i(121, 25, 34, 1)],
	[0, Rect2i(121, 8, 1, 17)],
	[0, Rect2i(154, 8, 1, 17)],
	[0, Rect2i(138, 8, 1, 17)],
	[0, Rect2i(122, 16, 16, 1)],
	[1, Rect2i(45, 10, 1, 14)],
	[1, Rect2i(73, 13, 12, 1)],
	[1, Rect2i(73, 20, 12, 1)],
	[1, Rect2i(73, 14, 1, 6)],
	[1, Rect2i(84, 14, 1, 6)],
	[1, Rect2i(79, 14, 1, 6)],
	[1, Rect2i(74, 17, 5, 1)],
	[-1, Rect2i(45, 10, 1, 14)],
	[-1, Rect2i(73, 13, 12, 1)],
	[-1, Rect2i(73, 20, 12, 1)],
	[-1, Rect2i(73, 14, 1, 6)],
	[-1, Rect2i(84, 14, 1, 6)],
	[-1, Rect2i(79, 14, 1, 6)],
	[-1, Rect2i(74, 17, 5, 1)],
	[-1, Rect2i(121, 7, 34, 1)],
	[-1, Rect2i(121, 25, 34, 1)],
	[-1, Rect2i(121, 8, 1, 17)],
	[-1, Rect2i(154, 8, 1, 17)],
	[-1, Rect2i(138, 8, 1, 17)],
	[-1, Rect2i(122, 16, 16, 1)],
]

const DOOR_ROWS: Array = [
	[0, Vector2i(42, 45), "closed", 0],
	[0, Vector2i(41, 50), "closed", 0],
	[0, Vector2i(59, 42), "closed", 1],
	[0, Vector2i(58, 47), "closed", 1],
	[0, Vector2i(76, 45), "closed", 2],
	[0, Vector2i(75, 50), "closed", 2],
	[0, Vector2i(45, 17), "closed", 3],
	[0, Vector2i(44, 24), "closed", 3],
	[0, Vector2i(79, 17), "closed", 4],
	[0, Vector2i(78, 24), "closed", 4],
	[0, Vector2i(121, 9), "closed", 5],
	[0, Vector2i(121, 23), "closed", 5],
	[0, Vector2i(154, 9), "closed", 5],
	[0, Vector2i(137, 29), "open", 5],
	[0, Vector2i(14, 73), "closed", 6],
	[0, Vector2i(42, 78), "closed", 7],
	[0, Vector2i(71, 73), "closed", 8],
	[0, Vector2i(99, 78), "closed", 9],
	[0, Vector2i(132, 72), "closed", 10],
	[1, Vector2i(45, 17), "closed", 3],
	[1, Vector2i(73, 15), "closed", 4],
	[1, Vector2i(73, 18), "closed", 4],
	[1, Vector2i(84, 15), "closed", 4],
	[-1, Vector2i(45, 17), "closed", 3],
	[-1, Vector2i(73, 15), "closed", 4],
	[-1, Vector2i(73, 18), "closed", 4],
	[-1, Vector2i(84, 15), "closed", 4],
	[-1, Vector2i(121, 9), "closed", 5],
	[-1, Vector2i(121, 23), "closed", 5],
	[-1, Vector2i(154, 9), "closed", 5],
	[-1, Vector2i(51, 17), "open", 3],
	[-1, Vector2i(70, 17), "open", 3],
]

const WINDOW_ROWS: Array = [
	[0, Vector2i(38, 39), 0],
	[0, Vector2i(45, 50), 0],
	[0, Vector2i(35, 42), 0],
	[0, Vector2i(48, 47), 0],
	[0, Vector2i(55, 36), 1],
	[0, Vector2i(62, 47), 1],
	[0, Vector2i(52, 39), 1],
	[0, Vector2i(65, 44), 1],
	[0, Vector2i(72, 39), 2],
	[0, Vector2i(79, 50), 2],
	[0, Vector2i(69, 42), 2],
	[0, Vector2i(82, 47), 2],
	[0, Vector2i(39, 9), 3],
	[0, Vector2i(50, 24), 3],
	[0, Vector2i(36, 12), 3],
	[0, Vector2i(53, 21), 3],
	[0, Vector2i(71, 9), 4],
	[0, Vector2i(86, 24), 4],
	[0, Vector2i(68, 12), 4],
	[0, Vector2i(89, 21), 4],
	[0, Vector2i(119, 3), 5],
	[0, Vector2i(156, 29), 5],
	[0, Vector2i(116, 6), 5],
	[0, Vector2i(159, 26), 5],
	[0, Vector2i(14, 67), 6],
	[0, Vector2i(42, 72), 7],
	[0, Vector2i(71, 67), 8],
	[0, Vector2i(99, 72), 9],
	[0, Vector2i(132, 66), 10],
	[1, Vector2i(39, 9), 3],
	[1, Vector2i(50, 24), 3],
	[1, Vector2i(36, 12), 3],
	[1, Vector2i(53, 21), 3],
	[1, Vector2i(71, 9), 4],
	[1, Vector2i(86, 24), 4],
	[1, Vector2i(68, 12), 4],
	[1, Vector2i(89, 21), 4],
]

const STAIR_ROWS: Array = [
	[Vector2i(38, 14), 0, 1],
	[Vector2i(70, 14), 0, 1],
	[Vector2i(52, 17), -1, 0],
	[Vector2i(69, 17), -1, 0],
	[Vector2i(118, 9), -1, 0],
]

const STOVE_ROWS: Array = [
	[Vector2i(13, 68), 6, 0],
	[Vector2i(41, 73), 7, 0],
	[Vector2i(70, 68), 8, 0],
	[Vector2i(98, 73), 9, 0],
	[Vector2i(131, 67), 10, 0],
]

const CONTAINER_ROWS: Array = [
	["supply_0", "식량 찬장", Vector2i(37, 42), 0, ["food_pack"], 0],
	["supply_1", "목재 선반", Vector2i(46, 48), 0, ["plank"], 0],
	["supply_2", "식량 찬장", Vector2i(54, 39), 1, ["food_pack"], 0],
	["supply_3", "목재 선반", Vector2i(63, 45), 1, ["plank"], 0],
	["supply_4", "식량 찬장", Vector2i(71, 42), 2, ["food_pack"], 0],
	["supply_5", "목재 선반", Vector2i(80, 48), 2, ["plank"], 0],
	["supply_6", "식량 찬장", Vector2i(38, 12), 3, ["food_pack"], 0],
	["supply_7", "목재 선반", Vector2i(51, 22), 3, ["plank"], 0],
	["supply_8", "식량 찬장", Vector2i(70, 12), 4, ["food_pack"], 0],
	["supply_9", "목재 선반", Vector2i(87, 22), 4, ["plank"], 0],
	["supply_10", "저장 식량 상자", Vector2i(123, 9), 5, ["food_pack", "food_pack"], 0],
	["supply_11", "연료 보관함", Vector2i(123, 23), 5, ["wood", "wood", "wood"], 0],
	["supply_12", "깊은 부품 상자", Vector2i(140, 23), 5, ["scrap","scrap","food_pack","wood"], 0],
	["supply_13", "작업 통로 선반", Vector2i(118, 5), 5, ["plank"], 0],
	["supply_14", "움막 낚시 선반", Vector2i(16, 71), 6, ["food_pack"], 0],
	["supply_15", "움막 낚시 선반", Vector2i(44, 76), 7, ["food_pack"], 0],
	["supply_16", "움막 낚시 선반", Vector2i(73, 71), 8, ["food_pack"], 0],
	["supply_17", "움막 낚시 선반", Vector2i(101, 76), 9, ["food_pack"], 0],
	["supply_18", "움막 낚시 선반", Vector2i(134, 70), 10, ["food_pack"], 0],
	["supply_19", "식량 찬장", Vector2i(38, 12), 3, ["food_pack"], 1],
	["supply_20", "위층 작업 선반", Vector2i(51, 22), 3, ["plank"], 1],
	["supply_21", "저장 식량 상자", Vector2i(75, 15), 4, ["food_pack", "food_pack"], 1],
	["supply_22", "연료 보관함", Vector2i(75, 18), 4, ["wood", "wood", "wood"], 1],
	["supply_23", "깊은 부품 상자", Vector2i(81, 18), 4, ["scrap","scrap","food_pack","wood"], 1],
	["supply_24", "작업 통로 선반", Vector2i(70, 11), 4, ["plank"], 1],
	["supply_25", "지하 저장 선반", Vector2i(38, 12), 3, ["food_pack","wood"], -1],
	["supply_26", "목재 선반", Vector2i(51, 22), 3, ["plank"], -1],
	["supply_27", "저장 식량 상자", Vector2i(75, 15), 4, ["food_pack", "food_pack"], -1],
	["supply_28", "연료 보관함", Vector2i(75, 18), 4, ["wood", "wood", "wood"], -1],
	["supply_29", "깊은 부품 상자", Vector2i(81, 18), 4, ["scrap","scrap","food_pack","wood"], -1],
	["supply_30", "작업 통로 선반", Vector2i(70, 11), 4, ["plank"], -1],
	["supply_31", "저장 식량 상자", Vector2i(123, 9), 5, ["food_pack", "food_pack"], -1],
	["supply_32", "연료 보관함", Vector2i(123, 23), 5, ["wood", "wood", "wood"], -1],
	["supply_33", "깊은 부품 상자", Vector2i(140, 23), 5, ["scrap","scrap","food_pack","wood"], -1],
	["supply_34", "작업 통로 선반", Vector2i(118, 5), 5, ["plank"], -1],
	["supply_35", "지하 통로 공구함", Vector2i(63, 17), 3, ["scrap"], -1],
	["pier_wood", "잔교 목재 상자", Vector2i(91, 103), -1, ["plank","wood"], 0],
]

const SALVAGE_ROWS: Array = [
	["pier_repair", "잔교 수선 목재", Vector2i(79, 61), "wood", 2],
]

const ZONE_ROWS: Array = [
	["A", Rect2i(0, 60, 164, 50), Vector2i(50, 64)],
	["B", Rect2i(0, 0, 164, 60), Vector2i(37, 41)],
	["C", Rect2i(69, 91, 24, 14), Vector2i(71, 93)],
	["D", Rect2i(116, 3, 44, 27), Vector2i(118, 5)],
]

const ENTRY_CELLS: Dictionary = {
	"shore_west": [Vector2i(0, 54), Vector2i(0, 55)],
	"shore_east": [Vector2i(163, 44), Vector2i(163, 45)],
	"village_back": [Vector2i(103, 0), Vector2i(104, 0)],
}

const ENTRY_GAP: Dictionary = {"shore_west":0.6,"shore_east":0.6,"village_back":2.5}

const BARRICADE_CELLS: Array[Vector2i] = [
	Vector2i(49, 44),
	Vector2i(50, 44),
	Vector2i(51, 44),
	Vector2i(66, 44),
	Vector2i(67, 44),
	Vector2i(68, 44),
]

const PROPS: Array = [
	{"kind": "overturned_boat", "rect": Rect2i(48, 52, 4, 2), "solid": "low", "facing": 0, "note": "하역 마당 엄폐 · 뒤집힌 배"},
	{"kind": "net_drying_rack", "rect": Rect2i(67, 45, 1, 4), "solid": "low", "facing": 1, "note": "하역 마당 엄폐 · 그물 건조대"},
	{"kind": "fish_trap_stack", "rect": Rect2i(93, 43, 2, 3), "solid": "low", "facing": 1, "note": "하역 마당 엄폐 · 통발 쌓음"},
	{"kind": "firewood_stack", "rect": Rect2i(110, 49, 3, 2), "solid": "low", "facing": 0, "note": "하역 마당 엄폐 · 장작 단"},
	{"kind": "pier_deck", "rect": Rect2i(76, 61, 3, 30), "solid": "none", "facing": 1, "note": "잔교 통로 구간 · 잔교"},
	{"kind": "fishing_platform", "rect": Rect2i(40, 91, 24, 14), "solid": "none", "facing": 0, "note": "어장 작업 무리 · 어장 작업대"},
	{"kind": "sunken_wheelhouse", "rect": Rect2i(25, 93, 4, 3), "solid": "wall", "facing": 0, "note": "가라앉은 배 1 · 조타실 윗부분"},
	{"kind": "sunken_bow", "rect": Rect2i(33, 94, 2, 4), "solid": "wall", "facing": 1, "note": "가라앉은 배 1 · 솟은 뱃머리"},
	{"kind": "sunken_deck_section", "rect": Rect2i(26, 99, 8, 3), "solid": "low", "facing": 0, "note": "가라앉은 배 1 · 드러난 갑판 조각"},
	{"kind": "fallen_mast", "rect": Rect2i(31, 103, 7, 1), "solid": "low", "facing": 0, "note": "가라앉은 배 1 · 쓰러진 돛대"},
	{"kind": "sunken_wheelhouse", "rect": Rect2i(102, 91, 4, 3), "solid": "wall", "facing": 0, "note": "가라앉은 배 2 · 조타실 윗부분"},
	{"kind": "sunken_bow", "rect": Rect2i(110, 92, 2, 4), "solid": "wall", "facing": 1, "note": "가라앉은 배 2 · 솟은 뱃머리"},
	{"kind": "sunken_deck_section", "rect": Rect2i(103, 97, 8, 3), "solid": "low", "facing": 0, "note": "가라앉은 배 2 · 드러난 갑판 조각"},
	{"kind": "fish_hoist", "rect": Rect2i(70, 92, 3, 3), "solid": "wall", "facing": 0, "note": "작업대 1 · 어망 윈치 틀"},
	{"kind": "cleaning_table", "rect": Rect2i(76, 93, 4, 2), "solid": "low", "facing": 0, "note": "작업대 1 · 손질대"},
	{"kind": "fish_crate_stack", "rect": Rect2i(81, 95, 2, 2), "solid": "low", "facing": 0, "note": "작업대 1 · 생선 상자 더미"},
	{"kind": "net_pile", "rect": Rect2i(72, 98, 2, 2), "solid": "low", "facing": 0, "note": "작업대 1 · 그물 더미"},
	{"kind": "ice_saw_frame", "rect": Rect2i(87, 102, 3, 2), "solid": "low", "facing": 0, "note": "작업대 1 · 얼음 톱 틀"},
	{"kind": "ice_cut_pool", "rect": Rect2i(64, 96, 4, 3), "solid": "none", "facing": 0, "note": "작업대 1 · 잘라 낸 얼음 자리"},
	{"kind": "fish_drying_frame", "rect": Rect2i(22, 33, 4, 2), "solid": "low", "facing": 0, "note": "주택 마당 1 · 생선 건조 틀"},
	{"kind": "fish_trap_stack", "rect": Rect2i(36, 33, 2, 2), "solid": "low", "facing": 0, "note": "주택 마당 1 · 통발 쌓음"},
	{"kind": "dry_bush", "rect": Rect2i(36, 53, 2, 2), "solid": "none", "facing": 0, "note": "주택 마당 1 · 마른 덤불"},
	{"kind": "overturned_boat", "rect": Rect2i(39, 33, 4, 2), "solid": "low", "facing": 0, "note": "주택 마당 2 · 뒤집힌 배"},
	{"kind": "net_drying_rack", "rect": Rect2i(54, 34, 4, 1), "solid": "low", "facing": 0, "note": "주택 마당 2 · 그물 건조대"},
	{"kind": "buoy_line", "rect": Rect2i(67, 43, 2, 1), "solid": "none", "facing": 0, "note": "주택 마당 2 · 부표 줄"},
	{"kind": "snow_drift", "rect": Rect2i(52, 51, 4, 2), "solid": "none", "facing": 0, "note": "주택 마당 2 · 눈더미"},
	{"kind": "fish_drying_frame", "rect": Rect2i(59, 33, 4, 2), "solid": "low", "facing": 0, "note": "주택 마당 3 · 생선 건조 틀"},
	{"kind": "fish_trap_stack", "rect": Rect2i(70, 33, 2, 2), "solid": "low", "facing": 0, "note": "주택 마당 3 · 통발 쌓음"},
	{"kind": "dry_bush", "rect": Rect2i(69, 52, 2, 2), "solid": "none", "facing": 0, "note": "주택 마당 3 · 마른 덤불"},
	{"kind": "overturned_boat", "rect": Rect2i(31, 11, 4, 2), "solid": "low", "facing": 0, "note": "주택 마당 4 · 뒤집힌 배"},
	{"kind": "net_drying_rack", "rect": Rect2i(39, 5, 4, 1), "solid": "low", "facing": 0, "note": "주택 마당 4 · 그물 건조대"},
	{"kind": "buoy_line", "rect": Rect2i(56, 14, 2, 1), "solid": "none", "facing": 0, "note": "주택 마당 4 · 부표 줄"},
	{"kind": "snow_drift", "rect": Rect2i(37, 27, 4, 2), "solid": "none", "facing": 0, "note": "주택 마당 4 · 눈더미"},
	{"kind": "fish_drying_frame", "rect": Rect2i(63, 11, 4, 2), "solid": "low", "facing": 0, "note": "주택 마당 5 · 생선 건조 틀"},
	{"kind": "fish_trap_stack", "rect": Rect2i(71, 5, 2, 2), "solid": "low", "facing": 0, "note": "주택 마당 5 · 통발 쌓음"},
	{"kind": "net_pile", "rect": Rect2i(92, 14, 2, 2), "solid": "low", "facing": 0, "note": "주택 마당 5 · 그물 더미"},
	{"kind": "dry_bush", "rect": Rect2i(69, 27, 2, 2), "solid": "none", "facing": 0, "note": "주택 마당 5 · 마른 덤불"},
	{"kind": "frozen_reeds", "rect": Rect2i(7, 60, 3, 3), "solid": "none", "facing": 0, "note": "물가 무리 1 · 얼어붙은 갈대"},
	{"kind": "shore_ice_heap", "rect": Rect2i(11, 56, 3, 2), "solid": "low", "facing": 0, "note": "물가 무리 1 · 물가 얼음 무더기"},
	{"kind": "fishing_hole", "rect": Rect2i(14, 54, 1, 1), "solid": "none", "facing": 0, "note": "물가 무리 1 · 낚시 구멍"},
	{"kind": "frozen_reeds", "rect": Rect2i(27, 60, 3, 3), "solid": "none", "facing": 0, "note": "물가 무리 2 · 얼어붙은 갈대"},
	{"kind": "shore_ice_heap", "rect": Rect2i(30, 57, 3, 2), "solid": "low", "facing": 0, "note": "물가 무리 2 · 물가 얼음 무더기"},
	{"kind": "fishing_hole", "rect": Rect2i(34, 54, 1, 1), "solid": "none", "facing": 0, "note": "물가 무리 2 · 낚시 구멍"},
	{"kind": "frozen_reeds", "rect": Rect2i(44, 63, 3, 3), "solid": "none", "facing": 0, "note": "물가 무리 3 · 얼어붙은 갈대"},
	{"kind": "fishing_hole", "rect": Rect2i(53, 53, 1, 1), "solid": "none", "facing": 0, "note": "물가 무리 3 · 낚시 구멍"},
	{"kind": "frozen_reeds", "rect": Rect2i(64, 63, 3, 3), "solid": "none", "facing": 0, "note": "물가 무리 4 · 얼어붙은 갈대"},
	{"kind": "fishing_hole", "rect": Rect2i(72, 52, 1, 1), "solid": "none", "facing": 0, "note": "물가 무리 4 · 낚시 구멍"},
	{"kind": "frozen_reeds", "rect": Rect2i(84, 63, 3, 3), "solid": "none", "facing": 0, "note": "물가 무리 5 · 얼어붙은 갈대"},
	{"kind": "fishing_hole", "rect": Rect2i(93, 53, 1, 1), "solid": "none", "facing": 0, "note": "물가 무리 5 · 낚시 구멍"},
	{"kind": "frozen_reeds", "rect": Rect2i(104, 63, 3, 3), "solid": "none", "facing": 0, "note": "물가 무리 6 · 얼어붙은 갈대"},
	{"kind": "fishing_hole", "rect": Rect2i(113, 53, 1, 1), "solid": "none", "facing": 0, "note": "물가 무리 6 · 낚시 구멍"},
	{"kind": "frozen_reeds", "rect": Rect2i(127, 60, 3, 3), "solid": "none", "facing": 0, "note": "물가 무리 7 · 얼어붙은 갈대"},
	{"kind": "shore_ice_heap", "rect": Rect2i(130, 57, 3, 2), "solid": "low", "facing": 0, "note": "물가 무리 7 · 물가 얼음 무더기"},
	{"kind": "fishing_hole", "rect": Rect2i(134, 54, 1, 1), "solid": "none", "facing": 0, "note": "물가 무리 7 · 낚시 구멍"},
	{"kind": "tool_bench", "rect": Rect2i(8, 69, 3, 1), "solid": "low", "facing": 0, "note": "움막 1 · 연장 작업대"},
	{"kind": "firewood_stack", "rect": Rect2i(17, 64, 3, 2), "solid": "low", "facing": 0, "note": "움막 1 · 장작 단"},
	{"kind": "fishing_hole", "rect": Rect2i(10, 75, 1, 1), "solid": "none", "facing": 0, "note": "움막 1 · 낚시 구멍"},
	{"kind": "tip_up_flag", "rect": Rect2i(11, 75, 1, 1), "solid": "none", "facing": 0, "note": "움막 1 · 낚시 깃대"},
	{"kind": "fishing_hole", "rect": Rect2i(13, 77, 1, 1), "solid": "none", "facing": 0, "note": "움막 1 · 낚시 구멍"},
	{"kind": "tip_up_flag", "rect": Rect2i(14, 77, 1, 1), "solid": "none", "facing": 0, "note": "움막 1 · 낚시 깃대"},
	{"kind": "fishing_hole", "rect": Rect2i(17, 76, 1, 1), "solid": "none", "facing": 0, "note": "움막 1 · 낚시 구멍"},
	{"kind": "tip_up_flag", "rect": Rect2i(18, 76, 1, 1), "solid": "none", "facing": 0, "note": "움막 1 · 낚시 깃대"},
	{"kind": "fishing_hole", "rect": Rect2i(38, 80, 1, 1), "solid": "none", "facing": 0, "note": "움막 2 · 낚시 구멍"},
	{"kind": "tip_up_flag", "rect": Rect2i(39, 80, 1, 1), "solid": "none", "facing": 0, "note": "움막 2 · 낚시 깃대"},
	{"kind": "fishing_hole", "rect": Rect2i(41, 82, 1, 1), "solid": "none", "facing": 0, "note": "움막 2 · 낚시 구멍"},
	{"kind": "tip_up_flag", "rect": Rect2i(42, 82, 1, 1), "solid": "none", "facing": 0, "note": "움막 2 · 낚시 깃대"},
	{"kind": "fishing_hole", "rect": Rect2i(45, 81, 1, 1), "solid": "none", "facing": 0, "note": "움막 2 · 낚시 구멍"},
	{"kind": "tip_up_flag", "rect": Rect2i(46, 81, 1, 1), "solid": "none", "facing": 0, "note": "움막 2 · 낚시 깃대"},
	{"kind": "fishing_hole", "rect": Rect2i(67, 75, 1, 1), "solid": "none", "facing": 0, "note": "움막 3 · 낚시 구멍"},
	{"kind": "tip_up_flag", "rect": Rect2i(68, 75, 1, 1), "solid": "none", "facing": 0, "note": "움막 3 · 낚시 깃대"},
	{"kind": "fishing_hole", "rect": Rect2i(70, 77, 1, 1), "solid": "none", "facing": 0, "note": "움막 3 · 낚시 구멍"},
	{"kind": "tip_up_flag", "rect": Rect2i(71, 77, 1, 1), "solid": "none", "facing": 0, "note": "움막 3 · 낚시 깃대"},
	{"kind": "fishing_hole", "rect": Rect2i(74, 76, 1, 1), "solid": "none", "facing": 0, "note": "움막 3 · 낚시 구멍"},
	{"kind": "tip_up_flag", "rect": Rect2i(75, 76, 1, 1), "solid": "none", "facing": 0, "note": "움막 3 · 낚시 깃대"},
	{"kind": "fishing_hole", "rect": Rect2i(95, 80, 1, 1), "solid": "none", "facing": 0, "note": "움막 4 · 낚시 구멍"},
	{"kind": "tip_up_flag", "rect": Rect2i(96, 80, 1, 1), "solid": "none", "facing": 0, "note": "움막 4 · 낚시 깃대"},
	{"kind": "fishing_hole", "rect": Rect2i(98, 82, 1, 1), "solid": "none", "facing": 0, "note": "움막 4 · 낚시 구멍"},
	{"kind": "tip_up_flag", "rect": Rect2i(99, 82, 1, 1), "solid": "none", "facing": 0, "note": "움막 4 · 낚시 깃대"},
	{"kind": "fishing_hole", "rect": Rect2i(102, 81, 1, 1), "solid": "none", "facing": 0, "note": "움막 4 · 낚시 구멍"},
	{"kind": "tip_up_flag", "rect": Rect2i(103, 81, 1, 1), "solid": "none", "facing": 0, "note": "움막 4 · 낚시 깃대"},
	{"kind": "firewood_stack", "rect": Rect2i(142, 64, 3, 2), "solid": "low", "facing": 0, "note": "움막 5 · 장작 단"},
	{"kind": "fishing_hole", "rect": Rect2i(128, 74, 1, 1), "solid": "none", "facing": 0, "note": "움막 5 · 낚시 구멍"},
	{"kind": "tip_up_flag", "rect": Rect2i(129, 74, 1, 1), "solid": "none", "facing": 0, "note": "움막 5 · 낚시 깃대"},
	{"kind": "fishing_hole", "rect": Rect2i(131, 76, 1, 1), "solid": "none", "facing": 0, "note": "움막 5 · 낚시 구멍"},
	{"kind": "tip_up_flag", "rect": Rect2i(132, 76, 1, 1), "solid": "none", "facing": 0, "note": "움막 5 · 낚시 깃대"},
	{"kind": "fishing_hole", "rect": Rect2i(135, 75, 1, 1), "solid": "none", "facing": 0, "note": "움막 5 · 낚시 구멍"},
	{"kind": "tip_up_flag", "rect": Rect2i(136, 75, 1, 1), "solid": "none", "facing": 0, "note": "움막 5 · 낚시 깃대"},
	{"kind": "boat_on_blocks", "rect": Rect2i(110, 1, 5, 2), "solid": "low", "facing": 0, "note": "창고 앞뜰 · 받침대에 얹힌 배"},
	{"kind": "tool_bench", "rect": Rect2i(126, 1, 3, 1), "solid": "low", "facing": 0, "note": "창고 앞뜰 · 연장 작업대"},
	{"kind": "pallet_stack", "rect": Rect2i(161, 1, 2, 2), "solid": "low", "facing": 0, "note": "창고 앞뜰 · 상자 팔레트"},
	{"kind": "ice_block_stack", "rect": Rect2i(111, 9, 3, 2), "solid": "low", "facing": 0, "note": "창고 앞뜰 · 얼음 덩이 쌓음"},
	{"kind": "ice_sled_load", "rect": Rect2i(111, 16, 3, 1), "solid": "low", "facing": 0, "note": "창고 앞뜰 · 짐 실은 썰매"},
	{"kind": "generator_unit", "rect": Rect2i(161, 10, 2, 2), "solid": "low", "facing": 0, "note": "설비 뒤편 · 발전기"},
	{"kind": "fuel_drum_group", "rect": Rect2i(161, 13, 2, 2), "solid": "low", "facing": 0, "note": "설비 뒤편 · 연료 드럼"},
	{"kind": "rubbish_pile", "rect": Rect2i(113, 5, 2, 1), "solid": "none", "facing": 0, "note": "설비 뒤편 · 쏟아진 쓰레기"},
	{"kind": "bare_willow", "rect": Rect2i(8, 17, 1, 1), "solid": "tree", "facing": 0, "note": "버드나무 무리 1 · 마른 버드나무"},
	{"kind": "bare_willow", "rect": Rect2i(10, 18, 1, 1), "solid": "tree", "facing": 0, "note": "버드나무 무리 1 · 마른 버드나무"},
	{"kind": "bare_willow", "rect": Rect2i(7, 20, 1, 1), "solid": "tree", "facing": 0, "note": "버드나무 무리 1 · 마른 버드나무"},
	{"kind": "bare_willow", "rect": Rect2i(11, 21, 1, 1), "solid": "tree", "facing": 0, "note": "버드나무 무리 1 · 마른 버드나무"},
	{"kind": "bare_willow", "rect": Rect2i(9, 23, 1, 1), "solid": "tree", "facing": 0, "note": "버드나무 무리 1 · 마른 버드나무"},
	{"kind": "bare_willow", "rect": Rect2i(23, 2, 1, 1), "solid": "tree", "facing": 0, "note": "버드나무 무리 2 · 마른 버드나무"},
	{"kind": "bare_willow", "rect": Rect2i(25, 3, 1, 1), "solid": "tree", "facing": 0, "note": "버드나무 무리 2 · 마른 버드나무"},
	{"kind": "bare_willow", "rect": Rect2i(22, 5, 1, 1), "solid": "tree", "facing": 0, "note": "버드나무 무리 2 · 마른 버드나무"},
	{"kind": "bare_willow", "rect": Rect2i(26, 6, 1, 1), "solid": "tree", "facing": 0, "note": "버드나무 무리 2 · 마른 버드나무"},
	{"kind": "bare_willow", "rect": Rect2i(24, 8, 1, 1), "solid": "tree", "facing": 0, "note": "버드나무 무리 2 · 마른 버드나무"},
	{"kind": "bare_willow", "rect": Rect2i(56, 25, 1, 1), "solid": "tree", "facing": 0, "note": "버드나무 무리 3 · 마른 버드나무"},
	{"kind": "bare_willow", "rect": Rect2i(58, 26, 1, 1), "solid": "tree", "facing": 0, "note": "버드나무 무리 3 · 마른 버드나무"},
	{"kind": "bare_willow", "rect": Rect2i(55, 28, 1, 1), "solid": "tree", "facing": 0, "note": "버드나무 무리 3 · 마른 버드나무"},
	{"kind": "bare_willow", "rect": Rect2i(59, 29, 1, 1), "solid": "tree", "facing": 0, "note": "버드나무 무리 3 · 마른 버드나무"},
	{"kind": "bare_willow", "rect": Rect2i(57, 31, 1, 1), "solid": "tree", "facing": 0, "note": "버드나무 무리 3 · 마른 버드나무"},
	{"kind": "bare_willow", "rect": Rect2i(96, 28, 1, 1), "solid": "tree", "facing": 0, "note": "버드나무 무리 4 · 마른 버드나무"},
	{"kind": "bare_willow", "rect": Rect2i(98, 29, 1, 1), "solid": "tree", "facing": 0, "note": "버드나무 무리 4 · 마른 버드나무"},
	{"kind": "bare_willow", "rect": Rect2i(95, 31, 1, 1), "solid": "tree", "facing": 0, "note": "버드나무 무리 4 · 마른 버드나무"},
	{"kind": "bare_willow", "rect": Rect2i(99, 32, 1, 1), "solid": "tree", "facing": 0, "note": "버드나무 무리 4 · 마른 버드나무"},
	{"kind": "bare_willow", "rect": Rect2i(97, 34, 1, 1), "solid": "tree", "facing": 0, "note": "버드나무 무리 4 · 마른 버드나무"},
	{"kind": "bare_willow", "rect": Rect2i(143, 39, 1, 1), "solid": "tree", "facing": 0, "note": "버드나무 무리 5 · 마른 버드나무"},
	{"kind": "bare_willow", "rect": Rect2i(145, 40, 1, 1), "solid": "tree", "facing": 0, "note": "버드나무 무리 5 · 마른 버드나무"},
	{"kind": "bare_willow", "rect": Rect2i(142, 42, 1, 1), "solid": "tree", "facing": 0, "note": "버드나무 무리 5 · 마른 버드나무"},
	{"kind": "bare_willow", "rect": Rect2i(146, 43, 1, 1), "solid": "tree", "facing": 0, "note": "버드나무 무리 5 · 마른 버드나무"},
	{"kind": "bare_willow", "rect": Rect2i(144, 45, 1, 1), "solid": "tree", "facing": 0, "note": "버드나무 무리 5 · 마른 버드나무"},
	{"kind": "ice_cut_pool", "rect": Rect2i(149, 87, 4, 3), "solid": "none", "facing": 0, "note": "얼음 채취 흔적 · 잘라 낸 얼음 자리"},
	{"kind": "ice_cut_pool", "rect": Rect2i(130, 91, 4, 3), "solid": "none", "facing": 0, "note": "얼음 채취 흔적 · 잘라 낸 얼음 자리"},
	{"kind": "ice_cut_pool", "rect": Rect2i(153, 103, 4, 3), "solid": "none", "facing": 0, "note": "얼음 채취 흔적 · 잘라 낸 얼음 자리"},
	{"kind": "buoy_line", "rect": Rect2i(90, 102, 2, 1), "solid": "none", "facing": 0, "note": "잔교 물자 표시 · 부표 줄"},
]


# 공용 지하 통로의 바깥 벽과 회관 안 벽을 실제 건물 외곽에 맞춘다.
const WALL_BUILDING_ROWS: Array = [
	[-1, Rect2i(54, 15, 14, 1), -1],
	[-1, Rect2i(54, 19, 14, 1), -1],
	[-1, Rect2i(68, 15, 3, 5), 4],
]

static func build() -> Dictionary:
	var g := FieldGrid.new(WIDTH, HEIGHT)
	var upper := FieldGrid.new(WIDTH, HEIGHT)
	upper.solid.fill(S.AIR)
	var cellar := FieldGrid.new(WIDTH, HEIGHT)
	cellar.solid.fill(S.BLOCK)
	var village_side: String = "lower" if LAKE_SIDE == "upper" else "upper"
	var platform_y: int = TRAIN.end.y if village_side == "lower" else TRAIN.position.y - 3
	var data: Dictionary = {
		"grid": g, "levels": {0: g, 1: upper, -1: cellar}, "stairs": [],
		"containers": {}, "spots": {}, "stoves": [], "entries": ENTRY_CELLS.duplicate(true),
		"buildings": [], "wagons": [], "train": TRAIN,
		"platform": Rect2i(TRAIN.position.x, platform_y, 80, 3),
		"spawns": {"raiders": [], "dead_levels": [], "squad": [], "train_door": []},
		"labels": [], "trees": [], "low_blocks": [], "upper_rects": [],
		"train_cars": [], "lights": [], "manholes": {}, "sewer_names": {},
		"manhole_levels": {}, "entry_levels": {}, "entry_gap": ENTRY_GAP.duplicate(),
		"entry_names": ENTRY_NAMES.duplicate(), "entry_weights": ENTRY_WEIGHTS.duplicate(), "first_entry": FIRST_ENTRY,
		"unload": Rect2i(TRAIN.position.x, TRAIN.position.y - 3, 80, 9),
		"place_id": PLACE_ID, "place_kind": "lake", "bands": BANDS.duplicate(true),
		"train_doors": {"upper": [], "lower": []}, "crossings": [],
		"barricade_slots": BARRICADE_CELLS.duplicate(),
		"interior_kind_slots": [{"zone": "D", "kinds": ["empty", "raiders", "nest", "beasts"]}],
		"zone_names": ZONE_NAMES.duplicate(), "props": PROPS.duplicate(true),
	}
	for row in FLOOR_PATCHES:
		_fill_floor(g, row[0], row[1])
	for id in range(BUILDING_ROWS.size()):
		var row: Array = BUILDING_ROWS[id]
		data["buildings"].append({"id": id, "name": row[0], "rect": row[1], "warm": false, "window_broken": false})
		_rooms(g, id, row[1], F.WOOD)
	for row in LEVEL_ROWS:
		var lg: FieldGrid = data["levels"][row[0]]
		_rooms(lg, row[1], row[2], F.GRAVEL if row[0] < 0 else F.WOOD)
		if row[0] > 0:
			data["upper_rects"].append({"building": row[1], "rect": row[2]})
	for row in WALL_ROWS:
		_fill_solid(data["levels"][row[0]], row[1], S.WALL)
	for row in DOOR_ROWS:
		var lg: FieldGrid = data["levels"][row[0]]
		var c: Vector2i = row[1]
		lg.set_solid(c, S.DOOR)
		lg.doors[c] = {"state": row[2], "hp": 8, "building": row[3], "cell": c}
	for row in WINDOW_ROWS:
		var lg: FieldGrid = data["levels"][row[0]]
		var c: Vector2i = row[1]
		lg.set_solid(c, S.WINDOW)
		lg.windows[c] = {"broken": false, "glass": true, "building": row[2], "cell": c}
	for row in WALL_BUILDING_ROWS:
		var lg: FieldGrid = data["levels"][row[0]]
		var rect: Rect2i = row[1]
		for y in range(rect.position.y, rect.end.y):
			for x in range(rect.position.x, rect.end.x):
				var c := Vector2i(x, y)
				if lg.solid_at(c) == S.WALL:
					lg.building[lg.index(c)] = row[2]
	for prop in PROPS:
		var r: Rect2i = prop["rect"]
		match prop["solid"]:
			"low":
				_fill_solid(g, r, S.LOW)
				data["low_blocks"].append(r)
			"wall":
				_fill_solid(g, r, S.WALL)
			"tree":
				g.set_solid(r.position, S.BLOCK)
				data["trees"].append(r.position)
	for row in STOVE_ROWS:
		var lg: FieldGrid = data["levels"][row[2]]
		lg.set_solid(row[0], S.LOW)
		data["stoves"].append({"cell": row[0], "building": row[1], "level": row[2], "lit": false, "upstairs": row[2] > 0})
	for row in STAIR_ROWS:
		data["stairs"].append({"cell": row[0], "low": row[1], "high": row[2], "ladder": false})
	for row in CONTAINER_ROWS:
		data["containers"][row[0]] = {"id": row[0], "name": row[1], "cell": row[2], "building": row[3], "items": row[4].duplicate(), "level": row[5], "search": 4.0 if row[5] == 0 else 6.0, "locked": false, "searched": false}
	for row in SALVAGE_ROWS:
		data["spots"][row[0]] = {"kind": "salvage", "name": row[1], "cell": row[2], "material": row[3], "amount": row[4], "state": "intact", "level": 0}
	for row in ZONE_ROWS:
		var r: Rect2i = row[1]
		for y in range(r.position.y, r.end.y):
			for x in range(r.position.x, r.end.x):
				g.zone[g.index(Vector2i(x, y))] = row[0]
		data["labels"].append({"text": ZONE_NAMES[row[0]], "cell": row[2]})
	for key in ENTRY_CELLS:
		data["spawns"]["dead_" + key] = [ENTRY_CELLS[key][0]]
	_train(g, data)
	for lv in data["levels"]:
		var lg: FieldGrid = data["levels"][lv]
		lg.zone = g.zone.duplicate()
		lg.refresh_paths()
	return data


static func _train(g: FieldGrid, data: Dictionary) -> void:
	_fill_solid(g, TRAIN, S.BLOCK)
	for side in ["upper", "lower"]:
		var y: int = TRAIN.position.y - 1 if side == "upper" else TRAIN.end.y
		for offset in [8, 24, 40, 56]:
			data["train_doors"][side].append(Vector2i(TRAIN.position.x + offset, y))
		var apron_y: int = TRAIN.position.y - 3 if side == "upper" else TRAIN.end.y
		data["spots"]["unload_" + side] = {"kind": "unload", "name": "얼음 어장 하역 자리" if side == LAKE_SIDE else "마을 하역 자리", "cell": Vector2i(TRAIN.position.x + 40, apron_y + 1), "state": "open", "zone_rect": Rect2i(TRAIN.position.x, apron_y, 80, 3)}
	data["spawns"]["train_door"] = data["train_doors"]["upper"] + data["train_doors"]["lower"]
	var village_side: String = "lower" if LAKE_SIDE == "upper" else "upper"
	data["spawns"]["squad"] = data["train_doors"][village_side].duplicate()
	for x in [TRAIN.position.x - 1, TRAIN.end.x]:
		var cells: Array[Vector2i] = []
		for y in range(TRAIN.position.y - 1, TRAIN.end.y + 1):
			var c := Vector2i(x, y)
			cells.append(c)
			g.floor[g.index(c)] = F.GRAVEL
		data["crossings"].append({"cells": cells, "who": {"person": true, "zombie": true, "carrying": true, "wounded": true, "sled": true}})
	for k in range(5):
		var r := Rect2i(TRAIN.position.x + k * 16, TRAIN.position.y, 16, 3)
		data["train_cars"].append({"rect": r, "kind": "car" if k < 4 else "engine"})
		if k == 4:
			continue
		for side in ["upper", "lower"]:
			var y: int = r.position.y if side == "upper" else r.end.y - 1
			var facing := Vector2i(0, -1) if side == "upper" else Vector2i(0, 1)
			for n in range(4):
				data["lights"].append({"id": "car%d_%s_window%d" % [k + 1, side, n + 1], "kind": "car_window", "cell": Vector2i(r.position.x + 3 + n * 3, y), "side": facing, "strength": 1.0, "falls": 0.6, "reach": 3.0, "when": "dusk", "from_min": 890})


static func _rooms(g: FieldGrid, id: int, r: Rect2i, floor_kind: int) -> void:
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			var c := Vector2i(x, y)
			g.building[g.index(c)] = id
			g.floor[g.index(c)] = floor_kind
			g.set_solid(c, S.WALL if x == r.position.x or x == r.end.x - 1 or y == r.position.y or y == r.end.y - 1 else S.NONE)


static func _fill_floor(g: FieldGrid, r: Rect2i, kind: int) -> void:
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			g.floor[g.index(Vector2i(x, y))] = kind


static func _fill_solid(g: FieldGrid, r: Rect2i, kind: int) -> void:
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			g.set_solid(Vector2i(x, y), kind)
