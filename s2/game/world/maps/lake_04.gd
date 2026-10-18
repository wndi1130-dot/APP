# 이 지도가 다른 판단을 만드는 것: 열차 북쪽 집들과 남쪽 선착장 창고가 갈라져 있어 물자를 옮길 때 어느 열차 끝을 돌지 고른다.
extends RefCounted
## 셋째 판. 1칸은 1m. 물가의 연속된 얼음은 걸을 수 있으며 지도 끝이 깊은 물이다.
## 지하와 위층은 같은 칸의 계단으로 잇고, 깊은 창고는 순환 통로와 세 저장 주머니로 나눈다.

const FieldGrid = preload("res://game/world/field_grid.gd")
const S = FieldGrid.Solid
const F = FieldGrid.Floor

const WIDTH: int = 170

const HEIGHT: int = 106

const PLACE_ID: String = "lake_04"

const LAKE_SIDE: String = "lower"

const TRAIN: Rect2i = Rect2i(44, 46, 80, 3)

const BANDS: Dictionary = {"upper": Rect2i(24, 24, 120, 22), "lower": Rect2i(24, 49, 120, 23)}

const ZONE_NAMES: Dictionary = {"A":"얼음 어장","B":"어장 마을","C":"잔교 작업장","D":"보트 창고","":"바깥"}
## 무전 문장에 쓰는 들어오는 길의 이름, 길마다의 비중, 첫 물결이 오는 길.
const ENTRY_NAMES: Dictionary = {"shore_west": "서쪽 호숫가", "shore_east": "동쪽 호숫가", "village_back": "마을 뒤쪽"}
const ENTRY_WEIGHTS: Dictionary = {"shore_west": 0.4, "shore_east": 0.4, "village_back": 0.2}
const FIRST_ENTRY: String = "shore_west"

const FLOOR_PATCHES: Array = [
	[Rect2i(0, 49, 170, 57), F.ICE],
	[Rect2i(0, 46, 170, 3), F.RAIL],
	[Rect2i(41, 43, 86, 3), F.PLATFORM],
	[Rect2i(41, 49, 86, 3), F.PLATFORM],
	[Rect2i(104, 49, 3, 28), F.WOOD],
	[Rect2i(91, 75, 24, 14), F.PLATFORM],
	[Rect2i(87, 79, 4, 3), F.GRAVEL],
	[Rect2i(57, 18, 4, 2), F.DEEP_SNOW],
	[Rect2i(40, 33, 4, 2), F.DEEP_SNOW],
	[Rect2i(75, 39, 4, 2), F.DEEP_SNOW],
	[Rect2i(14, 43, 1, 1), F.GRAVEL],
	[Rect2i(35, 43, 1, 1), F.GRAVEL],
	[Rect2i(55, 42, 1, 1), F.GRAVEL],
	[Rect2i(76, 42, 1, 1), F.GRAVEL],
	[Rect2i(97, 42, 1, 1), F.GRAVEL],
	[Rect2i(118, 42, 1, 1), F.GRAVEL],
	[Rect2i(140, 43, 1, 1), F.GRAVEL],
	[Rect2i(125, 86, 1, 1), F.GRAVEL],
	[Rect2i(128, 88, 1, 1), F.GRAVEL],
	[Rect2i(132, 87, 1, 1), F.GRAVEL],
	[Rect2i(0, 38, 1, 1), F.ROAD],
	[Rect2i(0, 39, 1, 1), F.ROAD],
	[Rect2i(0, 40, 1, 1), F.ROAD],
	[Rect2i(0, 41, 1, 1), F.ROAD],
	[Rect2i(0, 42, 1, 1), F.ROAD],
	[Rect2i(0, 43, 1, 1), F.ROAD],
	[Rect2i(0, 44, 1, 1), F.ROAD],
	[Rect2i(0, 45, 1, 1), F.ROAD],
	[Rect2i(0, 39, 1, 1), F.ROAD],
	[Rect2i(0, 40, 1, 1), F.ROAD],
	[Rect2i(0, 41, 1, 1), F.ROAD],
	[Rect2i(0, 42, 1, 1), F.ROAD],
	[Rect2i(0, 43, 1, 1), F.ROAD],
	[Rect2i(0, 44, 1, 1), F.ROAD],
	[Rect2i(0, 45, 1, 1), F.ROAD],
	[Rect2i(108, 0, 1, 1), F.ROAD],
	[Rect2i(108, 1, 1, 1), F.ROAD],
	[Rect2i(108, 2, 1, 1), F.ROAD],
	[Rect2i(108, 3, 1, 1), F.ROAD],
	[Rect2i(108, 4, 1, 1), F.ROAD],
	[Rect2i(108, 5, 1, 1), F.ROAD],
	[Rect2i(108, 6, 1, 1), F.ROAD],
	[Rect2i(107, 6, 1, 1), F.ROAD],
	[Rect2i(107, 7, 1, 1), F.ROAD],
	[Rect2i(107, 8, 1, 1), F.ROAD],
	[Rect2i(107, 9, 1, 1), F.ROAD],
	[Rect2i(107, 10, 1, 1), F.ROAD],
	[Rect2i(107, 11, 1, 1), F.ROAD],
	[Rect2i(106, 11, 1, 1), F.ROAD],
	[Rect2i(106, 12, 1, 1), F.ROAD],
	[Rect2i(106, 13, 1, 1), F.ROAD],
	[Rect2i(106, 14, 1, 1), F.ROAD],
	[Rect2i(106, 15, 1, 1), F.ROAD],
	[Rect2i(106, 16, 1, 1), F.ROAD],
	[Rect2i(106, 17, 1, 1), F.ROAD],
	[Rect2i(106, 18, 1, 1), F.ROAD],
	[Rect2i(106, 19, 1, 1), F.ROAD],
	[Rect2i(106, 20, 1, 1), F.ROAD],
	[Rect2i(106, 21, 1, 1), F.ROAD],
	[Rect2i(106, 22, 1, 1), F.ROAD],
	[Rect2i(106, 23, 1, 1), F.ROAD],
	[Rect2i(106, 24, 1, 1), F.ROAD],
	[Rect2i(106, 25, 1, 1), F.ROAD],
	[Rect2i(106, 26, 1, 1), F.ROAD],
	[Rect2i(106, 27, 1, 1), F.ROAD],
	[Rect2i(106, 28, 1, 1), F.ROAD],
	[Rect2i(106, 29, 1, 1), F.ROAD],
	[Rect2i(106, 30, 1, 1), F.ROAD],
	[Rect2i(106, 31, 1, 1), F.ROAD],
	[Rect2i(106, 32, 1, 1), F.ROAD],
	[Rect2i(106, 33, 1, 1), F.ROAD],
	[Rect2i(106, 34, 1, 1), F.ROAD],
	[Rect2i(106, 35, 1, 1), F.ROAD],
	[Rect2i(106, 36, 1, 1), F.ROAD],
	[Rect2i(106, 37, 1, 1), F.ROAD],
	[Rect2i(106, 38, 1, 1), F.ROAD],
	[Rect2i(106, 39, 1, 1), F.ROAD],
	[Rect2i(106, 40, 1, 1), F.ROAD],
	[Rect2i(106, 41, 1, 1), F.ROAD],
	[Rect2i(106, 42, 1, 1), F.ROAD],
	[Rect2i(109, 0, 1, 1), F.ROAD],
	[Rect2i(109, 1, 1, 1), F.ROAD],
	[Rect2i(109, 2, 1, 1), F.ROAD],
	[Rect2i(109, 3, 1, 1), F.ROAD],
	[Rect2i(109, 4, 1, 1), F.ROAD],
	[Rect2i(109, 5, 1, 1), F.ROAD],
	[Rect2i(109, 6, 1, 1), F.ROAD],
	[Rect2i(109, 7, 1, 1), F.ROAD],
	[Rect2i(109, 8, 1, 1), F.ROAD],
	[Rect2i(109, 9, 1, 1), F.ROAD],
	[Rect2i(108, 9, 1, 1), F.ROAD],
	[Rect2i(108, 10, 1, 1), F.ROAD],
	[Rect2i(108, 11, 1, 1), F.ROAD],
	[Rect2i(108, 12, 1, 1), F.ROAD],
	[Rect2i(108, 13, 1, 1), F.ROAD],
	[Rect2i(108, 14, 1, 1), F.ROAD],
	[Rect2i(108, 15, 1, 1), F.ROAD],
	[Rect2i(108, 16, 1, 1), F.ROAD],
	[Rect2i(108, 17, 1, 1), F.ROAD],
	[Rect2i(108, 18, 1, 1), F.ROAD],
	[Rect2i(108, 19, 1, 1), F.ROAD],
	[Rect2i(107, 19, 1, 1), F.ROAD],
	[Rect2i(107, 20, 1, 1), F.ROAD],
	[Rect2i(107, 21, 1, 1), F.ROAD],
	[Rect2i(107, 22, 1, 1), F.ROAD],
	[Rect2i(107, 23, 1, 1), F.ROAD],
	[Rect2i(107, 24, 1, 1), F.ROAD],
	[Rect2i(107, 25, 1, 1), F.ROAD],
	[Rect2i(107, 26, 1, 1), F.ROAD],
	[Rect2i(107, 27, 1, 1), F.ROAD],
	[Rect2i(107, 28, 1, 1), F.ROAD],
	[Rect2i(107, 29, 1, 1), F.ROAD],
	[Rect2i(107, 30, 1, 1), F.ROAD],
	[Rect2i(107, 31, 1, 1), F.ROAD],
	[Rect2i(107, 32, 1, 1), F.ROAD],
	[Rect2i(107, 33, 1, 1), F.ROAD],
	[Rect2i(107, 34, 1, 1), F.ROAD],
	[Rect2i(107, 35, 1, 1), F.ROAD],
	[Rect2i(107, 36, 1, 1), F.ROAD],
	[Rect2i(107, 37, 1, 1), F.ROAD],
	[Rect2i(107, 38, 1, 1), F.ROAD],
	[Rect2i(107, 39, 1, 1), F.ROAD],
	[Rect2i(107, 40, 1, 1), F.ROAD],
	[Rect2i(107, 41, 1, 1), F.ROAD],
	[Rect2i(107, 42, 1, 1), F.ROAD],
	[Rect2i(46, 17, 1, 1), F.ROAD],
	[Rect2i(46, 18, 1, 1), F.ROAD],
	[Rect2i(46, 19, 1, 1), F.ROAD],
	[Rect2i(45, 19, 1, 1), F.ROAD],
	[Rect2i(44, 19, 1, 1), F.ROAD],
	[Rect2i(43, 19, 1, 1), F.ROAD],
	[Rect2i(42, 19, 1, 1), F.ROAD],
	[Rect2i(41, 19, 1, 1), F.ROAD],
	[Rect2i(40, 19, 1, 1), F.ROAD],
	[Rect2i(39, 19, 1, 1), F.ROAD],
	[Rect2i(39, 20, 1, 1), F.ROAD],
	[Rect2i(39, 21, 1, 1), F.ROAD],
	[Rect2i(39, 22, 1, 1), F.ROAD],
	[Rect2i(39, 23, 1, 1), F.ROAD],
	[Rect2i(39, 24, 1, 1), F.ROAD],
	[Rect2i(39, 25, 1, 1), F.ROAD],
	[Rect2i(39, 26, 1, 1), F.ROAD],
	[Rect2i(39, 27, 1, 1), F.ROAD],
	[Rect2i(39, 28, 1, 1), F.ROAD],
	[Rect2i(39, 29, 1, 1), F.ROAD],
	[Rect2i(39, 30, 1, 1), F.ROAD],
	[Rect2i(39, 31, 1, 1), F.ROAD],
	[Rect2i(39, 32, 1, 1), F.ROAD],
	[Rect2i(40, 32, 1, 1), F.ROAD],
	[Rect2i(41, 32, 1, 1), F.ROAD],
	[Rect2i(42, 32, 1, 1), F.ROAD],
	[Rect2i(42, 33, 1, 1), F.ROAD],
	[Rect2i(42, 34, 1, 1), F.ROAD],
	[Rect2i(42, 35, 1, 1), F.ROAD],
	[Rect2i(42, 36, 1, 1), F.ROAD],
	[Rect2i(42, 37, 1, 1), F.ROAD],
	[Rect2i(42, 38, 1, 1), F.ROAD],
	[Rect2i(42, 39, 1, 1), F.ROAD],
	[Rect2i(42, 40, 1, 1), F.ROAD],
	[Rect2i(42, 41, 1, 1), F.ROAD],
	[Rect2i(42, 42, 1, 1), F.ROAD],
	[Rect2i(63, 17, 1, 1), F.ROAD],
	[Rect2i(63, 18, 1, 1), F.ROAD],
	[Rect2i(63, 19, 1, 1), F.ROAD],
	[Rect2i(62, 19, 1, 1), F.ROAD],
	[Rect2i(61, 19, 1, 1), F.ROAD],
	[Rect2i(60, 19, 1, 1), F.ROAD],
	[Rect2i(59, 19, 1, 1), F.ROAD],
	[Rect2i(58, 19, 1, 1), F.ROAD],
	[Rect2i(57, 19, 1, 1), F.ROAD],
	[Rect2i(56, 19, 1, 1), F.ROAD],
	[Rect2i(56, 20, 1, 1), F.ROAD],
	[Rect2i(56, 21, 1, 1), F.ROAD],
	[Rect2i(56, 22, 1, 1), F.ROAD],
	[Rect2i(56, 23, 1, 1), F.ROAD],
	[Rect2i(56, 24, 1, 1), F.ROAD],
	[Rect2i(56, 25, 1, 1), F.ROAD],
	[Rect2i(56, 26, 1, 1), F.ROAD],
	[Rect2i(56, 27, 1, 1), F.ROAD],
	[Rect2i(56, 28, 1, 1), F.ROAD],
	[Rect2i(56, 29, 1, 1), F.ROAD],
	[Rect2i(56, 30, 1, 1), F.ROAD],
	[Rect2i(56, 31, 1, 1), F.ROAD],
	[Rect2i(56, 32, 1, 1), F.ROAD],
	[Rect2i(56, 33, 1, 1), F.ROAD],
	[Rect2i(56, 34, 1, 1), F.ROAD],
	[Rect2i(56, 35, 1, 1), F.ROAD],
	[Rect2i(56, 36, 1, 1), F.ROAD],
	[Rect2i(56, 37, 1, 1), F.ROAD],
	[Rect2i(55, 37, 1, 1), F.ROAD],
	[Rect2i(54, 37, 1, 1), F.ROAD],
	[Rect2i(53, 37, 1, 1), F.ROAD],
	[Rect2i(53, 38, 1, 1), F.ROAD],
	[Rect2i(53, 39, 1, 1), F.ROAD],
	[Rect2i(53, 40, 1, 1), F.ROAD],
	[Rect2i(53, 41, 1, 1), F.ROAD],
	[Rect2i(53, 42, 1, 1), F.ROAD],
	[Rect2i(80, 17, 1, 1), F.ROAD],
	[Rect2i(80, 18, 1, 1), F.ROAD],
	[Rect2i(80, 19, 1, 1), F.ROAD],
	[Rect2i(79, 19, 1, 1), F.ROAD],
	[Rect2i(78, 19, 1, 1), F.ROAD],
	[Rect2i(77, 19, 1, 1), F.ROAD],
	[Rect2i(76, 19, 1, 1), F.ROAD],
	[Rect2i(75, 19, 1, 1), F.ROAD],
	[Rect2i(74, 19, 1, 1), F.ROAD],
	[Rect2i(73, 19, 1, 1), F.ROAD],
	[Rect2i(73, 20, 1, 1), F.ROAD],
	[Rect2i(73, 21, 1, 1), F.ROAD],
	[Rect2i(73, 22, 1, 1), F.ROAD],
	[Rect2i(73, 23, 1, 1), F.ROAD],
	[Rect2i(73, 24, 1, 1), F.ROAD],
	[Rect2i(73, 25, 1, 1), F.ROAD],
	[Rect2i(73, 26, 1, 1), F.ROAD],
	[Rect2i(73, 27, 1, 1), F.ROAD],
	[Rect2i(73, 28, 1, 1), F.ROAD],
	[Rect2i(73, 29, 1, 1), F.ROAD],
	[Rect2i(73, 30, 1, 1), F.ROAD],
	[Rect2i(73, 31, 1, 1), F.ROAD],
	[Rect2i(73, 32, 1, 1), F.ROAD],
	[Rect2i(73, 33, 1, 1), F.ROAD],
	[Rect2i(73, 34, 1, 1), F.ROAD],
	[Rect2i(73, 35, 1, 1), F.ROAD],
	[Rect2i(73, 36, 1, 1), F.ROAD],
	[Rect2i(73, 37, 1, 1), F.ROAD],
	[Rect2i(73, 38, 1, 1), F.ROAD],
	[Rect2i(73, 39, 1, 1), F.ROAD],
	[Rect2i(73, 40, 1, 1), F.ROAD],
	[Rect2i(73, 41, 1, 1), F.ROAD],
	[Rect2i(73, 42, 1, 1), F.ROAD],
	[Rect2i(46, 32, 1, 1), F.ROAD],
	[Rect2i(46, 33, 1, 1), F.ROAD],
	[Rect2i(46, 34, 1, 1), F.ROAD],
	[Rect2i(46, 35, 1, 1), F.ROAD],
	[Rect2i(46, 36, 1, 1), F.ROAD],
	[Rect2i(46, 37, 1, 1), F.ROAD],
	[Rect2i(46, 38, 1, 1), F.ROAD],
	[Rect2i(46, 39, 1, 1), F.ROAD],
	[Rect2i(46, 40, 1, 1), F.ROAD],
	[Rect2i(46, 41, 1, 1), F.ROAD],
	[Rect2i(46, 42, 1, 1), F.ROAD],
	[Rect2i(63, 32, 1, 1), F.ROAD],
	[Rect2i(63, 33, 1, 1), F.ROAD],
	[Rect2i(63, 34, 1, 1), F.ROAD],
	[Rect2i(63, 35, 1, 1), F.ROAD],
	[Rect2i(63, 36, 1, 1), F.ROAD],
	[Rect2i(63, 37, 1, 1), F.ROAD],
	[Rect2i(63, 38, 1, 1), F.ROAD],
	[Rect2i(63, 39, 1, 1), F.ROAD],
	[Rect2i(63, 40, 1, 1), F.ROAD],
	[Rect2i(63, 41, 1, 1), F.ROAD],
	[Rect2i(63, 42, 1, 1), F.ROAD],
	[Rect2i(83, 37, 1, 1), F.ROAD],
	[Rect2i(83, 38, 1, 1), F.ROAD],
	[Rect2i(83, 39, 1, 1), F.ROAD],
	[Rect2i(83, 40, 1, 1), F.ROAD],
	[Rect2i(83, 41, 1, 1), F.ROAD],
	[Rect2i(83, 42, 1, 1), F.ROAD],
	[Rect2i(25, 45, 1, 1), F.ROAD],
	[Rect2i(25, 44, 1, 1), F.ROAD],
	[Rect2i(26, 44, 1, 1), F.ROAD],
	[Rect2i(27, 44, 1, 1), F.ROAD],
	[Rect2i(28, 44, 1, 1), F.ROAD],
	[Rect2i(29, 44, 1, 1), F.ROAD],
	[Rect2i(30, 44, 1, 1), F.ROAD],
	[Rect2i(31, 44, 1, 1), F.ROAD],
	[Rect2i(32, 44, 1, 1), F.ROAD],
	[Rect2i(33, 44, 1, 1), F.ROAD],
	[Rect2i(34, 44, 1, 1), F.ROAD],
	[Rect2i(35, 44, 1, 1), F.ROAD],
	[Rect2i(36, 44, 1, 1), F.ROAD],
	[Rect2i(37, 44, 1, 1), F.ROAD],
	[Rect2i(38, 44, 1, 1), F.ROAD],
	[Rect2i(39, 44, 1, 1), F.ROAD],
	[Rect2i(40, 44, 1, 1), F.ROAD],
	[Rect2i(129, 11, 4, 2), F.DEEP_SNOW],
	[Rect2i(131, 27, 4, 2), F.DEEP_SNOW],
	[Rect2i(154, 33, 4, 2), F.DEEP_SNOW],
	[Rect2i(20, 61, 4, 3), F.GRAVEL],
	[Rect2i(148, 60, 4, 3), F.GRAVEL],
	[Rect2i(46, 66, 4, 3), F.GRAVEL],
	[Rect2i(67, 65, 4, 3), F.GRAVEL],
	[Rect2i(89, 64, 4, 3), F.GRAVEL],
	[Rect2i(126, 63, 4, 3), F.GRAVEL],
	[Rect2i(159, 77, 4, 3), F.GRAVEL],
]

const BUILDING_ROWS: Array = [
	["어장 주택", Rect2i(40, 6, 14, 11)],
	["어장 주택", Rect2i(57, 8, 14, 11)],
	["어장 주택", Rect2i(74, 6, 14, 11)],
	["어장 주택", Rect2i(40, 20, 14, 12)],
	["어장 주택", Rect2i(57, 22, 14, 12)],
	["어장 큰 집", Rect2i(74, 20, 20, 17)],
	["선착장 사무소", Rect2i(67, 78, 20, 17)],
	["보트 창고", Rect2i(5, 77, 42, 26)],
	["얼음 낚시 움막", Rect2i(127, 78, 7, 7)],
]

const LEVEL_ROWS: Array = [
	[1, 5, Rect2i(74, 20, 20, 17)],
	[1, 6, Rect2i(67, 78, 20, 17)],
	[-1, 6, Rect2i(67, 78, 20, 17)],
]

const WALL_ROWS: Array = [
	[0, Rect2i(47, 7, 1, 9)],
	[0, Rect2i(64, 9, 1, 9)],
	[0, Rect2i(81, 7, 1, 9)],
	[0, Rect2i(47, 21, 1, 10)],
	[0, Rect2i(64, 23, 1, 10)],
	[0, Rect2i(84, 21, 1, 15)],
	[0, Rect2i(77, 79, 1, 15)],
	[0, Rect2i(10, 81, 32, 1)],
	[0, Rect2i(10, 98, 32, 1)],
	[0, Rect2i(10, 82, 1, 16)],
	[0, Rect2i(41, 82, 1, 16)],
	[0, Rect2i(26, 82, 1, 16)],
	[0, Rect2i(11, 90, 15, 1)],
	[1, Rect2i(84, 21, 1, 15)],
	[1, Rect2i(77, 79, 1, 15)],
	[-1, Rect2i(77, 79, 1, 15)],
]

const DOOR_ROWS: Array = [
	[0, Vector2i(47, 11), "closed", 0],
	[0, Vector2i(46, 16), "closed", 0],
	[0, Vector2i(64, 13), "closed", 1],
	[0, Vector2i(63, 18), "closed", 1],
	[0, Vector2i(81, 11), "closed", 2],
	[0, Vector2i(80, 16), "closed", 2],
	[0, Vector2i(47, 26), "closed", 3],
	[0, Vector2i(46, 31), "closed", 3],
	[0, Vector2i(64, 28), "closed", 4],
	[0, Vector2i(63, 33), "closed", 4],
	[0, Vector2i(84, 28), "closed", 5],
	[0, Vector2i(83, 36), "closed", 5],
	[0, Vector2i(77, 86), "closed", 6],
	[0, Vector2i(76, 94), "closed", 6],
	[0, Vector2i(10, 83), "closed", 7],
	[0, Vector2i(10, 96), "closed", 7],
	[0, Vector2i(41, 83), "closed", 7],
	[0, Vector2i(25, 77), "open", 7],
	[0, Vector2i(129, 84), "closed", 8],
	[1, Vector2i(84, 28), "closed", 5],
	[1, Vector2i(77, 86), "closed", 6],
	[-1, Vector2i(77, 86), "closed", 6],
]

const WINDOW_ROWS: Array = [
	[0, Vector2i(43, 6), 0],
	[0, Vector2i(50, 16), 0],
	[0, Vector2i(40, 9), 0],
	[0, Vector2i(53, 13), 0],
	[0, Vector2i(60, 8), 1],
	[0, Vector2i(67, 18), 1],
	[0, Vector2i(57, 11), 1],
	[0, Vector2i(70, 15), 1],
	[0, Vector2i(77, 6), 2],
	[0, Vector2i(84, 16), 2],
	[0, Vector2i(74, 9), 2],
	[0, Vector2i(87, 13), 2],
	[0, Vector2i(43, 20), 3],
	[0, Vector2i(50, 31), 3],
	[0, Vector2i(40, 23), 3],
	[0, Vector2i(53, 28), 3],
	[0, Vector2i(60, 22), 4],
	[0, Vector2i(67, 33), 4],
	[0, Vector2i(57, 25), 4],
	[0, Vector2i(70, 30), 4],
	[0, Vector2i(77, 20), 5],
	[0, Vector2i(90, 36), 5],
	[0, Vector2i(74, 23), 5],
	[0, Vector2i(93, 33), 5],
	[0, Vector2i(70, 78), 6],
	[0, Vector2i(83, 94), 6],
	[0, Vector2i(67, 81), 6],
	[0, Vector2i(86, 91), 6],
	[0, Vector2i(8, 77), 7],
	[0, Vector2i(43, 102), 7],
	[0, Vector2i(5, 80), 7],
	[0, Vector2i(46, 99), 7],
	[0, Vector2i(129, 78), 8],
	[1, Vector2i(77, 20), 5],
	[1, Vector2i(90, 36), 5],
	[1, Vector2i(74, 23), 5],
	[1, Vector2i(93, 33), 5],
	[1, Vector2i(70, 78), 6],
	[1, Vector2i(83, 94), 6],
	[1, Vector2i(67, 81), 6],
	[1, Vector2i(86, 91), 6],
]

const STAIR_ROWS: Array = [
	[Vector2i(76, 25), 0, 1],
	[Vector2i(69, 83), 0, 1],
	[Vector2i(69, 84), -1, 0],
]

const STOVE_ROWS: Array = [
	[Vector2i(128, 79), 8, 0],
]

const CONTAINER_ROWS: Array = [
	["supply_0", "식량 찬장", Vector2i(42, 9), 0, ["food_pack"], 0],
	["supply_1", "목재 선반", Vector2i(51, 14), 0, ["plank"], 0],
	["supply_2", "식량 찬장", Vector2i(59, 11), 1, ["food_pack"], 0],
	["supply_3", "목재 선반", Vector2i(68, 16), 1, ["plank"], 0],
	["supply_4", "식량 찬장", Vector2i(76, 9), 2, ["food_pack"], 0],
	["supply_5", "목재 선반", Vector2i(85, 14), 2, ["plank"], 0],
	["supply_6", "식량 찬장", Vector2i(42, 23), 3, ["food_pack"], 0],
	["supply_7", "목재 선반", Vector2i(51, 29), 3, ["plank"], 0],
	["supply_8", "식량 찬장", Vector2i(59, 25), 4, ["food_pack"], 0],
	["supply_9", "목재 선반", Vector2i(68, 31), 4, ["plank"], 0],
	["supply_10", "식량 찬장", Vector2i(76, 23), 5, ["food_pack"], 0],
	["supply_11", "목재 선반", Vector2i(91, 34), 5, ["plank"], 0],
	["supply_12", "식량 찬장", Vector2i(69, 81), 6, ["food_pack"], 0],
	["supply_13", "목재 선반", Vector2i(84, 92), 6, ["plank"], 0],
	["supply_14", "저장 식량 상자", Vector2i(12, 83), 7, ["food_pack", "food_pack"], 0],
	["supply_15", "연료 보관함", Vector2i(12, 96), 7, ["wood", "wood", "wood"], 0],
	["supply_16", "깊은 부품 상자", Vector2i(28, 96), 7, ["scrap","scrap","food_pack","wood"], 0],
	["supply_17", "작업 통로 선반", Vector2i(7, 79), 7, ["plank"], 0],
	["supply_18", "움막 낚시 선반", Vector2i(131, 82), 8, ["food_pack"], 0],
	["supply_19", "식량 찬장", Vector2i(76, 23), 5, ["food_pack"], 1],
	["supply_20", "위층 작업 선반", Vector2i(91, 34), 5, ["plank"], 1],
	["supply_21", "식량 찬장", Vector2i(69, 81), 6, ["food_pack"], 1],
	["supply_22", "위층 작업 선반", Vector2i(84, 92), 6, ["plank"], 1],
	["supply_23", "지하 저장 선반", Vector2i(69, 81), 6, ["food_pack","wood"], -1],
	["supply_24", "목재 선반", Vector2i(84, 92), 6, ["plank"], -1],
	["pier_wood", "잔교 목재 상자", Vector2i(113, 87), -1, ["plank","wood"], 0],
]

const SALVAGE_ROWS: Array = [
	["pier_repair", "잔교 수선 목재", Vector2i(105, 50), "wood", 2],
]

const ZONE_ROWS: Array = [
	["A", Rect2i(0, 49, 170, 57), Vector2i(52, 53)],
	["B", Rect2i(0, 0, 170, 49), Vector2i(42, 8)],
	["C", Rect2i(91, 75, 24, 14), Vector2i(93, 77)],
	["D", Rect2i(5, 77, 42, 26), Vector2i(7, 79)],
]

const ENTRY_CELLS: Dictionary = {
	"shore_west": [Vector2i(0, 38), Vector2i(0, 39)],
	"shore_east": [Vector2i(169, 57), Vector2i(169, 58)],
	"village_back": [Vector2i(108, 0), Vector2i(109, 0)],
}

const ENTRY_GAP: Dictionary = {"shore_west":0.6,"shore_east":0.6,"village_back":2.5}

const BARRICADE_CELLS: Array[Vector2i] = [
	Vector2i(54, 26),
	Vector2i(55, 26),
	Vector2i(56, 26),
	Vector2i(71, 26),
	Vector2i(72, 26),
	Vector2i(73, 26),
]

const PROPS: Array = [
	{"kind": "overturned_boat", "rect": Rect2i(54, 38, 4, 2), "solid": "low", "facing": 0, "note": "하역 마당 엄폐 · 뒤집힌 배"},
	{"kind": "net_drying_rack", "rect": Rect2i(72, 36, 1, 4), "solid": "low", "facing": 1, "note": "하역 마당 엄폐 · 그물 건조대"},
	{"kind": "fish_trap_stack", "rect": Rect2i(95, 32, 2, 3), "solid": "low", "facing": 1, "note": "하역 마당 엄폐 · 통발 쌓음"},
	{"kind": "firewood_stack", "rect": Rect2i(112, 38, 3, 2), "solid": "low", "facing": 0, "note": "하역 마당 엄폐 · 장작 단"},
	{"kind": "pier_deck", "rect": Rect2i(102, 50, 3, 25), "solid": "none", "facing": 1, "note": "잔교 통로 구간 · 잔교"},
	{"kind": "fishing_platform", "rect": Rect2i(114, 89, 24, 14), "solid": "none", "facing": 0, "note": "어장 작업 무리 · 어장 작업대"},
	{"kind": "sunken_wheelhouse", "rect": Rect2i(50, 88, 4, 3), "solid": "wall", "facing": 0, "note": "가라앉은 배 1 · 조타실 윗부분"},
	{"kind": "sunken_bow", "rect": Rect2i(58, 89, 2, 4), "solid": "wall", "facing": 1, "note": "가라앉은 배 1 · 솟은 뱃머리"},
	{"kind": "sunken_deck_section", "rect": Rect2i(51, 94, 8, 3), "solid": "low", "facing": 0, "note": "가라앉은 배 1 · 드러난 갑판 조각"},
	{"kind": "fallen_mast", "rect": Rect2i(56, 98, 7, 1), "solid": "low", "facing": 0, "note": "가라앉은 배 1 · 쓰러진 돛대"},
	{"kind": "sunken_wheelhouse", "rect": Rect2i(104, 90, 4, 3), "solid": "wall", "facing": 0, "note": "가라앉은 배 2 · 조타실 윗부분"},
	{"kind": "sunken_bow", "rect": Rect2i(112, 91, 2, 4), "solid": "wall", "facing": 1, "note": "가라앉은 배 2 · 솟은 뱃머리"},
	{"kind": "sunken_deck_section", "rect": Rect2i(105, 96, 8, 3), "solid": "low", "facing": 0, "note": "가라앉은 배 2 · 드러난 갑판 조각"},
	{"kind": "sunken_wheelhouse", "rect": Rect2i(148, 89, 4, 3), "solid": "wall", "facing": 0, "note": "가라앉은 배 3 · 조타실 윗부분"},
	{"kind": "sunken_bow", "rect": Rect2i(156, 90, 2, 4), "solid": "wall", "facing": 1, "note": "가라앉은 배 3 · 솟은 뱃머리"},
	{"kind": "sunken_deck_section", "rect": Rect2i(149, 95, 8, 3), "solid": "low", "facing": 0, "note": "가라앉은 배 3 · 드러난 갑판 조각"},
	{"kind": "fallen_mast", "rect": Rect2i(154, 99, 7, 1), "solid": "low", "facing": 0, "note": "가라앉은 배 3 · 쓰러진 돛대"},
	{"kind": "fish_hoist", "rect": Rect2i(92, 76, 3, 3), "solid": "wall", "facing": 0, "note": "작업대 1 · 어망 윈치 틀"},
	{"kind": "cleaning_table", "rect": Rect2i(98, 77, 4, 2), "solid": "low", "facing": 0, "note": "작업대 1 · 손질대"},
	{"kind": "fish_crate_stack", "rect": Rect2i(103, 79, 2, 2), "solid": "low", "facing": 0, "note": "작업대 1 · 생선 상자 더미"},
	{"kind": "net_pile", "rect": Rect2i(94, 82, 2, 2), "solid": "low", "facing": 0, "note": "작업대 1 · 그물 더미"},
	{"kind": "ice_saw_frame", "rect": Rect2i(109, 86, 3, 2), "solid": "low", "facing": 0, "note": "작업대 1 · 얼음 톱 틀"},
	{"kind": "ice_cut_pool", "rect": Rect2i(87, 78, 4, 3), "solid": "none", "facing": 0, "note": "작업대 1 · 잘라 낸 얼음 자리"},
	{"kind": "fish_drying_frame", "rect": Rect2i(35, 8, 4, 2), "solid": "low", "facing": 0, "note": "주택 마당 1 · 생선 건조 틀"},
	{"kind": "fish_trap_stack", "rect": Rect2i(43, 2, 2, 2), "solid": "low", "facing": 0, "note": "주택 마당 1 · 통발 쌓음"},
	{"kind": "net_pile", "rect": Rect2i(48, 3, 2, 2), "solid": "low", "facing": 0, "note": "주택 마당 1 · 그물 더미"},
	{"kind": "dry_bush", "rect": Rect2i(38, 18, 2, 2), "solid": "none", "facing": 0, "note": "주택 마당 1 · 마른 덤불"},
	{"kind": "overturned_boat", "rect": Rect2i(51, 3, 4, 2), "solid": "low", "facing": 0, "note": "주택 마당 2 · 뒤집힌 배"},
	{"kind": "net_drying_rack", "rect": Rect2i(60, 2, 4, 1), "solid": "low", "facing": 0, "note": "주택 마당 2 · 그물 건조대"},
	{"kind": "buoy_line", "rect": Rect2i(72, 10, 2, 1), "solid": "none", "facing": 0, "note": "주택 마당 2 · 부표 줄"},
	{"kind": "snow_drift", "rect": Rect2i(57, 19, 4, 2), "solid": "none", "facing": 0, "note": "주택 마당 2 · 눈더미"},
	{"kind": "fish_drying_frame", "rect": Rect2i(65, 3, 4, 2), "solid": "low", "facing": 0, "note": "주택 마당 3 · 생선 건조 틀"},
	{"kind": "fish_trap_stack", "rect": Rect2i(77, 2, 2, 2), "solid": "low", "facing": 0, "note": "주택 마당 3 · 통발 쌓음"},
	{"kind": "net_pile", "rect": Rect2i(90, 11, 2, 2), "solid": "low", "facing": 0, "note": "주택 마당 3 · 그물 더미"},
	{"kind": "dry_bush", "rect": Rect2i(72, 18, 2, 2), "solid": "none", "facing": 0, "note": "주택 마당 3 · 마른 덤불"},
	{"kind": "overturned_boat", "rect": Rect2i(35, 22, 4, 2), "solid": "low", "facing": 0, "note": "주택 마당 4 · 뒤집힌 배"},
	{"kind": "net_drying_rack", "rect": Rect2i(40, 18, 4, 1), "solid": "low", "facing": 0, "note": "주택 마당 4 · 그물 건조대"},
	{"kind": "buoy_line", "rect": Rect2i(55, 24, 2, 1), "solid": "none", "facing": 0, "note": "주택 마당 4 · 부표 줄"},
	{"kind": "snow_drift", "rect": Rect2i(40, 33, 4, 2), "solid": "none", "facing": 0, "note": "주택 마당 4 · 눈더미"},
	{"kind": "dry_bush", "rect": Rect2i(58, 34, 2, 2), "solid": "none", "facing": 0, "note": "주택 마당 5 · 마른 덤불"},
	{"kind": "net_drying_rack", "rect": Rect2i(74, 18, 4, 1), "solid": "low", "facing": 0, "note": "주택 마당 6 · 그물 건조대"},
	{"kind": "buoy_line", "rect": Rect2i(96, 25, 2, 1), "solid": "none", "facing": 0, "note": "주택 마당 6 · 부표 줄"},
	{"kind": "snow_drift", "rect": Rect2i(75, 39, 4, 2), "solid": "none", "facing": 0, "note": "주택 마당 6 · 눈더미"},
	{"kind": "frozen_reeds", "rect": Rect2i(7, 49, 3, 3), "solid": "none", "facing": 0, "note": "물가 무리 1 · 얼어붙은 갈대"},
	{"kind": "shore_ice_heap", "rect": Rect2i(11, 45, 3, 2), "solid": "low", "facing": 0, "note": "물가 무리 1 · 물가 얼음 무더기"},
	{"kind": "fishing_hole", "rect": Rect2i(14, 43, 1, 1), "solid": "none", "facing": 0, "note": "물가 무리 1 · 낚시 구멍"},
	{"kind": "frozen_reeds", "rect": Rect2i(28, 49, 3, 3), "solid": "none", "facing": 0, "note": "물가 무리 2 · 얼어붙은 갈대"},
	{"kind": "shore_ice_heap", "rect": Rect2i(31, 46, 3, 2), "solid": "low", "facing": 0, "note": "물가 무리 2 · 물가 얼음 무더기"},
	{"kind": "fishing_hole", "rect": Rect2i(35, 43, 1, 1), "solid": "none", "facing": 0, "note": "물가 무리 2 · 낚시 구멍"},
	{"kind": "frozen_reeds", "rect": Rect2i(46, 52, 3, 3), "solid": "none", "facing": 0, "note": "물가 무리 3 · 얼어붙은 갈대"},
	{"kind": "fishing_hole", "rect": Rect2i(55, 42, 1, 1), "solid": "none", "facing": 0, "note": "물가 무리 3 · 낚시 구멍"},
	{"kind": "frozen_reeds", "rect": Rect2i(67, 52, 3, 3), "solid": "none", "facing": 0, "note": "물가 무리 4 · 얼어붙은 갈대"},
	{"kind": "fishing_hole", "rect": Rect2i(76, 42, 1, 1), "solid": "none", "facing": 0, "note": "물가 무리 4 · 낚시 구멍"},
	{"kind": "frozen_reeds", "rect": Rect2i(88, 52, 3, 3), "solid": "none", "facing": 0, "note": "물가 무리 5 · 얼어붙은 갈대"},
	{"kind": "fishing_hole", "rect": Rect2i(97, 42, 1, 1), "solid": "none", "facing": 0, "note": "물가 무리 5 · 낚시 구멍"},
	{"kind": "frozen_reeds", "rect": Rect2i(109, 52, 3, 3), "solid": "none", "facing": 0, "note": "물가 무리 6 · 얼어붙은 갈대"},
	{"kind": "fishing_hole", "rect": Rect2i(118, 42, 1, 1), "solid": "none", "facing": 0, "note": "물가 무리 6 · 낚시 구멍"},
	{"kind": "frozen_reeds", "rect": Rect2i(133, 49, 3, 3), "solid": "none", "facing": 0, "note": "물가 무리 7 · 얼어붙은 갈대"},
	{"kind": "shore_ice_heap", "rect": Rect2i(136, 46, 3, 2), "solid": "low", "facing": 0, "note": "물가 무리 7 · 물가 얼음 무더기"},
	{"kind": "fishing_hole", "rect": Rect2i(140, 43, 1, 1), "solid": "none", "facing": 0, "note": "물가 무리 7 · 낚시 구멍"},
	{"kind": "tool_bench", "rect": Rect2i(123, 80, 3, 1), "solid": "low", "facing": 0, "note": "움막 1 · 연장 작업대"},
	{"kind": "firewood_stack", "rect": Rect2i(136, 79, 3, 2), "solid": "low", "facing": 0, "note": "움막 1 · 장작 단"},
	{"kind": "fishing_hole", "rect": Rect2i(125, 86, 1, 1), "solid": "none", "facing": 0, "note": "움막 1 · 낚시 구멍"},
	{"kind": "tip_up_flag", "rect": Rect2i(126, 86, 1, 1), "solid": "none", "facing": 0, "note": "움막 1 · 낚시 깃대"},
	{"kind": "fishing_hole", "rect": Rect2i(128, 88, 1, 1), "solid": "none", "facing": 0, "note": "움막 1 · 낚시 구멍"},
	{"kind": "tip_up_flag", "rect": Rect2i(129, 88, 1, 1), "solid": "none", "facing": 0, "note": "움막 1 · 낚시 깃대"},
	{"kind": "fishing_hole", "rect": Rect2i(132, 87, 1, 1), "solid": "none", "facing": 0, "note": "움막 1 · 낚시 구멍"},
	{"kind": "tip_up_flag", "rect": Rect2i(133, 87, 1, 1), "solid": "none", "facing": 0, "note": "움막 1 · 낚시 깃대"},
	{"kind": "fish_truck", "rect": Rect2i(51, 83, 6, 3), "solid": "wall", "facing": 0, "note": "창고 앞뜰 · 생선 운반 트럭"},
	{"kind": "boat_on_blocks", "rect": Rect2i(9, 72, 5, 2), "solid": "low", "facing": 0, "note": "창고 앞뜰 · 받침대에 얹힌 배"},
	{"kind": "tool_bench", "rect": Rect2i(17, 73, 3, 1), "solid": "low", "facing": 0, "note": "창고 앞뜰 · 연장 작업대"},
	{"kind": "pallet_stack", "rect": Rect2i(42, 72, 2, 2), "solid": "low", "facing": 0, "note": "창고 앞뜰 · 상자 팔레트"},
	{"kind": "ice_block_stack", "rect": Rect2i(1, 82, 3, 2), "solid": "low", "facing": 0, "note": "창고 앞뜰 · 얼음 덩이 쌓음"},
	{"kind": "ice_sled_load", "rect": Rect2i(1, 89, 3, 1), "solid": "low", "facing": 0, "note": "창고 앞뜰 · 짐 실은 썰매"},
	{"kind": "fuel_tank", "rect": Rect2i(90, 81, 3, 3), "solid": "wall", "facing": 0, "note": "설비 뒤편 · 연료 탱크"},
	{"kind": "generator_unit", "rect": Rect2i(90, 87, 2, 2), "solid": "low", "facing": 0, "note": "설비 뒤편 · 발전기"},
	{"kind": "fuel_drum_group", "rect": Rect2i(94, 89, 2, 2), "solid": "low", "facing": 0, "note": "설비 뒤편 · 연료 드럼"},
	{"kind": "rubbish_pile", "rect": Rect2i(64, 80, 2, 1), "solid": "none", "facing": 0, "note": "설비 뒤편 · 쏟아진 쓰레기"},
	{"kind": "fish_truck", "rect": Rect2i(28, 72, 6, 3), "solid": "wall", "facing": 0, "note": "열차 끝 운반 길 · 생선 운반 트럭"},
	{"kind": "ice_sled_load", "rect": Rect2i(36, 72, 3, 1), "solid": "low", "facing": 0, "note": "열차 끝 운반 길 · 짐 실은 썰매"},
	{"kind": "fish_truck", "rect": Rect2i(120, 72, 6, 3), "solid": "wall", "facing": 0, "note": "열차 끝 운반 길 · 생선 운반 트럭"},
	{"kind": "ice_sled_load", "rect": Rect2i(128, 72, 3, 1), "solid": "low", "facing": 0, "note": "열차 끝 운반 길 · 짐 실은 썰매"},
	{"kind": "bare_willow", "rect": Rect2i(8, 21, 1, 1), "solid": "tree", "facing": 0, "note": "버드나무 무리 1 · 마른 버드나무"},
	{"kind": "bare_willow", "rect": Rect2i(10, 22, 1, 1), "solid": "tree", "facing": 0, "note": "버드나무 무리 1 · 마른 버드나무"},
	{"kind": "bare_willow", "rect": Rect2i(7, 24, 1, 1), "solid": "tree", "facing": 0, "note": "버드나무 무리 1 · 마른 버드나무"},
	{"kind": "bare_willow", "rect": Rect2i(11, 25, 1, 1), "solid": "tree", "facing": 0, "note": "버드나무 무리 1 · 마른 버드나무"},
	{"kind": "bare_willow", "rect": Rect2i(9, 27, 1, 1), "solid": "tree", "facing": 0, "note": "버드나무 무리 1 · 마른 버드나무"},
	{"kind": "bare_willow", "rect": Rect2i(24, 5, 1, 1), "solid": "tree", "facing": 0, "note": "버드나무 무리 2 · 마른 버드나무"},
	{"kind": "bare_willow", "rect": Rect2i(26, 6, 1, 1), "solid": "tree", "facing": 0, "note": "버드나무 무리 2 · 마른 버드나무"},
	{"kind": "bare_willow", "rect": Rect2i(23, 8, 1, 1), "solid": "tree", "facing": 0, "note": "버드나무 무리 2 · 마른 버드나무"},
	{"kind": "bare_willow", "rect": Rect2i(27, 9, 1, 1), "solid": "tree", "facing": 0, "note": "버드나무 무리 2 · 마른 버드나무"},
	{"kind": "bare_willow", "rect": Rect2i(25, 11, 1, 1), "solid": "tree", "facing": 0, "note": "버드나무 무리 2 · 마른 버드나무"},
	{"kind": "bare_willow", "rect": Rect2i(106, 6, 1, 1), "solid": "tree", "facing": 0, "note": "버드나무 무리 3 · 마른 버드나무"},
	{"kind": "bare_willow", "rect": Rect2i(108, 7, 1, 1), "solid": "tree", "facing": 0, "note": "버드나무 무리 3 · 마른 버드나무"},
	{"kind": "bare_willow", "rect": Rect2i(105, 9, 1, 1), "solid": "tree", "facing": 0, "note": "버드나무 무리 3 · 마른 버드나무"},
	{"kind": "bare_willow", "rect": Rect2i(109, 10, 1, 1), "solid": "tree", "facing": 0, "note": "버드나무 무리 3 · 마른 버드나무"},
	{"kind": "bare_willow", "rect": Rect2i(107, 12, 1, 1), "solid": "tree", "facing": 0, "note": "버드나무 무리 3 · 마른 버드나무"},
	{"kind": "bare_willow", "rect": Rect2i(109, 17, 1, 1), "solid": "tree", "facing": 0, "note": "버드나무 무리 4 · 마른 버드나무"},
	{"kind": "bare_willow", "rect": Rect2i(111, 18, 1, 1), "solid": "tree", "facing": 0, "note": "버드나무 무리 4 · 마른 버드나무"},
	{"kind": "bare_willow", "rect": Rect2i(108, 20, 1, 1), "solid": "tree", "facing": 0, "note": "버드나무 무리 4 · 마른 버드나무"},
	{"kind": "bare_willow", "rect": Rect2i(112, 21, 1, 1), "solid": "tree", "facing": 0, "note": "버드나무 무리 4 · 마른 버드나무"},
	{"kind": "bare_willow", "rect": Rect2i(110, 23, 1, 1), "solid": "tree", "facing": 0, "note": "버드나무 무리 4 · 마른 버드나무"},
	{"kind": "bare_willow", "rect": Rect2i(148, 13, 1, 1), "solid": "tree", "facing": 0, "note": "버드나무 무리 5 · 마른 버드나무"},
	{"kind": "bare_willow", "rect": Rect2i(150, 14, 1, 1), "solid": "tree", "facing": 0, "note": "버드나무 무리 5 · 마른 버드나무"},
	{"kind": "bare_willow", "rect": Rect2i(147, 16, 1, 1), "solid": "tree", "facing": 0, "note": "버드나무 무리 5 · 마른 버드나무"},
	{"kind": "bare_willow", "rect": Rect2i(151, 17, 1, 1), "solid": "tree", "facing": 0, "note": "버드나무 무리 5 · 마른 버드나무"},
	{"kind": "bare_willow", "rect": Rect2i(149, 19, 1, 1), "solid": "tree", "facing": 0, "note": "버드나무 무리 5 · 마른 버드나무"},
	{"kind": "snow_drift", "rect": Rect2i(129, 11, 4, 2), "solid": "none", "facing": 0, "note": "길가 눈 쌓임 · 눈더미"},
	{"kind": "snow_drift", "rect": Rect2i(131, 27, 4, 2), "solid": "none", "facing": 0, "note": "길가 눈 쌓임 · 눈더미"},
	{"kind": "snow_drift", "rect": Rect2i(154, 33, 4, 2), "solid": "none", "facing": 0, "note": "길가 눈 쌓임 · 눈더미"},
	{"kind": "ice_cut_pool", "rect": Rect2i(20, 61, 4, 3), "solid": "none", "facing": 0, "note": "얼음 채취 흔적 · 잘라 낸 얼음 자리"},
	{"kind": "ice_cut_pool", "rect": Rect2i(148, 60, 4, 3), "solid": "none", "facing": 0, "note": "얼음 채취 흔적 · 잘라 낸 얼음 자리"},
	{"kind": "ice_cut_pool", "rect": Rect2i(46, 66, 4, 3), "solid": "none", "facing": 0, "note": "얼음 채취 흔적 · 잘라 낸 얼음 자리"},
	{"kind": "ice_cut_pool", "rect": Rect2i(67, 65, 4, 3), "solid": "none", "facing": 0, "note": "얼음 채취 흔적 · 잘라 낸 얼음 자리"},
	{"kind": "ice_cut_pool", "rect": Rect2i(89, 64, 4, 3), "solid": "none", "facing": 0, "note": "얼음 채취 흔적 · 잘라 낸 얼음 자리"},
	{"kind": "ice_cut_pool", "rect": Rect2i(126, 63, 4, 3), "solid": "none", "facing": 0, "note": "얼음 채취 흔적 · 잘라 낸 얼음 자리"},
	{"kind": "ice_cut_pool", "rect": Rect2i(159, 77, 4, 3), "solid": "none", "facing": 0, "note": "얼음 채취 흔적 · 잘라 낸 얼음 자리"},
	{"kind": "buoy_line", "rect": Rect2i(112, 86, 2, 1), "solid": "none", "facing": 0, "note": "잔교 물자 표시 · 부표 줄"},
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
