# 이 지도가 다른 판단을 만드는 것: 네 집의 적은 물자를 챙긴 뒤 외딴 얼음 창고까지 굽은 호숫가 길로 갈지 얼음을 가로지를지 고른다.
extends RefCounted
## 셋째 판. 1칸은 1m. 물가의 연속된 얼음은 걸을 수 있으며 지도 끝이 깊은 물이다.
## 지하와 위층은 같은 칸의 계단으로 잇고, 깊은 창고는 순환 통로와 세 저장 주머니로 나눈다.

const FieldGrid = preload("res://game/world/field_grid.gd")
const S = FieldGrid.Solid
const F = FieldGrid.Floor

const WIDTH: int = 180

const HEIGHT: int = 108

const PLACE_ID: String = "lake_06"

const LAKE_SIDE: String = "lower"

const TRAIN: Rect2i = Rect2i(50, 50, 80, 3)

const BANDS: Dictionary = {"upper": Rect2i(30, 28, 120, 22), "lower": Rect2i(30, 53, 120, 23)}

const ZONE_NAMES: Dictionary = {"A":"얼음 어장","B":"어장 마을","C":"잔교 작업장","D":"얼음 창고","":"바깥"}
## 무전 문장에 쓰는 들어오는 길의 이름, 길마다의 비중, 첫 물결이 오는 길.
const ENTRY_NAMES: Dictionary = {"shore_west": "서쪽 호숫가", "shore_east": "동쪽 호숫가", "village_back": "마을 뒤쪽"}
const ENTRY_WEIGHTS: Dictionary = {"shore_west": 0.4, "shore_east": 0.4, "village_back": 0.2}
const FIRST_ENTRY: String = "shore_west"

const FLOOR_PATCHES: Array = [
	[Rect2i(0, 53, 180, 55), F.ICE],
	[Rect2i(0, 50, 180, 3), F.RAIL],
	[Rect2i(47, 47, 86, 3), F.PLATFORM],
	[Rect2i(47, 53, 86, 3), F.PLATFORM],
	[Rect2i(30, 53, 3, 26), F.WOOD],
	[Rect2i(103, 92, 24, 12), F.PLATFORM],
	[Rect2i(98, 97, 4, 3), F.GRAVEL],
	[Rect2i(34, 43, 4, 2), F.DEEP_SNOW],
	[Rect2i(68, 43, 4, 2), F.DEEP_SNOW],
	[Rect2i(14, 47, 1, 1), F.GRAVEL],
	[Rect2i(36, 47, 1, 1), F.GRAVEL],
	[Rect2i(57, 46, 1, 1), F.GRAVEL],
	[Rect2i(79, 46, 1, 1), F.GRAVEL],
	[Rect2i(101, 46, 1, 1), F.GRAVEL],
	[Rect2i(123, 46, 1, 1), F.GRAVEL],
	[Rect2i(146, 47, 1, 1), F.GRAVEL],
	[Rect2i(7, 89, 1, 1), F.GRAVEL],
	[Rect2i(10, 91, 1, 1), F.GRAVEL],
	[Rect2i(14, 90, 1, 1), F.GRAVEL],
	[Rect2i(47, 88, 1, 1), F.GRAVEL],
	[Rect2i(50, 90, 1, 1), F.GRAVEL],
	[Rect2i(54, 89, 1, 1), F.GRAVEL],
	[Rect2i(87, 95, 1, 1), F.GRAVEL],
	[Rect2i(90, 97, 1, 1), F.GRAVEL],
	[Rect2i(94, 96, 1, 1), F.GRAVEL],
	[Rect2i(114, 87, 1, 1), F.GRAVEL],
	[Rect2i(117, 89, 1, 1), F.GRAVEL],
	[Rect2i(121, 88, 1, 1), F.GRAVEL],
	[Rect2i(0, 45, 1, 1), F.ROAD],
	[Rect2i(0, 46, 1, 1), F.ROAD],
	[Rect2i(0, 47, 1, 1), F.ROAD],
	[Rect2i(0, 48, 1, 1), F.ROAD],
	[Rect2i(0, 49, 1, 1), F.ROAD],
	[Rect2i(0, 46, 1, 1), F.ROAD],
	[Rect2i(0, 47, 1, 1), F.ROAD],
	[Rect2i(0, 48, 1, 1), F.ROAD],
	[Rect2i(0, 49, 1, 1), F.ROAD],
	[Rect2i(179, 36, 1, 1), F.ROAD],
	[Rect2i(179, 37, 1, 1), F.ROAD],
	[Rect2i(179, 38, 1, 1), F.ROAD],
	[Rect2i(179, 39, 1, 1), F.ROAD],
	[Rect2i(179, 40, 1, 1), F.ROAD],
	[Rect2i(179, 41, 1, 1), F.ROAD],
	[Rect2i(179, 42, 1, 1), F.ROAD],
	[Rect2i(179, 43, 1, 1), F.ROAD],
	[Rect2i(179, 44, 1, 1), F.ROAD],
	[Rect2i(179, 45, 1, 1), F.ROAD],
	[Rect2i(179, 46, 1, 1), F.ROAD],
	[Rect2i(179, 47, 1, 1), F.ROAD],
	[Rect2i(179, 48, 1, 1), F.ROAD],
	[Rect2i(179, 49, 1, 1), F.ROAD],
	[Rect2i(179, 37, 1, 1), F.ROAD],
	[Rect2i(179, 38, 1, 1), F.ROAD],
	[Rect2i(179, 39, 1, 1), F.ROAD],
	[Rect2i(179, 40, 1, 1), F.ROAD],
	[Rect2i(179, 41, 1, 1), F.ROAD],
	[Rect2i(179, 42, 1, 1), F.ROAD],
	[Rect2i(179, 43, 1, 1), F.ROAD],
	[Rect2i(179, 44, 1, 1), F.ROAD],
	[Rect2i(179, 45, 1, 1), F.ROAD],
	[Rect2i(179, 46, 1, 1), F.ROAD],
	[Rect2i(179, 47, 1, 1), F.ROAD],
	[Rect2i(179, 48, 1, 1), F.ROAD],
	[Rect2i(179, 49, 1, 1), F.ROAD],
	[Rect2i(85, 0, 1, 1), F.ROAD],
	[Rect2i(85, 1, 1, 1), F.ROAD],
	[Rect2i(85, 2, 1, 1), F.ROAD],
	[Rect2i(85, 3, 1, 1), F.ROAD],
	[Rect2i(85, 4, 1, 1), F.ROAD],
	[Rect2i(85, 5, 1, 1), F.ROAD],
	[Rect2i(85, 6, 1, 1), F.ROAD],
	[Rect2i(85, 7, 1, 1), F.ROAD],
	[Rect2i(85, 8, 1, 1), F.ROAD],
	[Rect2i(85, 9, 1, 1), F.ROAD],
	[Rect2i(85, 10, 1, 1), F.ROAD],
	[Rect2i(85, 11, 1, 1), F.ROAD],
	[Rect2i(85, 12, 1, 1), F.ROAD],
	[Rect2i(85, 13, 1, 1), F.ROAD],
	[Rect2i(85, 14, 1, 1), F.ROAD],
	[Rect2i(85, 15, 1, 1), F.ROAD],
	[Rect2i(85, 16, 1, 1), F.ROAD],
	[Rect2i(85, 17, 1, 1), F.ROAD],
	[Rect2i(85, 18, 1, 1), F.ROAD],
	[Rect2i(85, 19, 1, 1), F.ROAD],
	[Rect2i(85, 20, 1, 1), F.ROAD],
	[Rect2i(85, 21, 1, 1), F.ROAD],
	[Rect2i(85, 22, 1, 1), F.ROAD],
	[Rect2i(85, 23, 1, 1), F.ROAD],
	[Rect2i(85, 24, 1, 1), F.ROAD],
	[Rect2i(85, 25, 1, 1), F.ROAD],
	[Rect2i(85, 26, 1, 1), F.ROAD],
	[Rect2i(85, 27, 1, 1), F.ROAD],
	[Rect2i(85, 28, 1, 1), F.ROAD],
	[Rect2i(85, 29, 1, 1), F.ROAD],
	[Rect2i(85, 30, 1, 1), F.ROAD],
	[Rect2i(85, 31, 1, 1), F.ROAD],
	[Rect2i(85, 32, 1, 1), F.ROAD],
	[Rect2i(85, 33, 1, 1), F.ROAD],
	[Rect2i(85, 34, 1, 1), F.ROAD],
	[Rect2i(85, 35, 1, 1), F.ROAD],
	[Rect2i(85, 36, 1, 1), F.ROAD],
	[Rect2i(85, 37, 1, 1), F.ROAD],
	[Rect2i(85, 38, 1, 1), F.ROAD],
	[Rect2i(85, 39, 1, 1), F.ROAD],
	[Rect2i(85, 40, 1, 1), F.ROAD],
	[Rect2i(85, 41, 1, 1), F.ROAD],
	[Rect2i(85, 42, 1, 1), F.ROAD],
	[Rect2i(85, 43, 1, 1), F.ROAD],
	[Rect2i(85, 44, 1, 1), F.ROAD],
	[Rect2i(85, 45, 1, 1), F.ROAD],
	[Rect2i(85, 46, 1, 1), F.ROAD],
	[Rect2i(86, 0, 1, 1), F.ROAD],
	[Rect2i(86, 1, 1, 1), F.ROAD],
	[Rect2i(86, 2, 1, 1), F.ROAD],
	[Rect2i(86, 3, 1, 1), F.ROAD],
	[Rect2i(86, 4, 1, 1), F.ROAD],
	[Rect2i(86, 5, 1, 1), F.ROAD],
	[Rect2i(86, 6, 1, 1), F.ROAD],
	[Rect2i(86, 7, 1, 1), F.ROAD],
	[Rect2i(86, 8, 1, 1), F.ROAD],
	[Rect2i(86, 9, 1, 1), F.ROAD],
	[Rect2i(86, 10, 1, 1), F.ROAD],
	[Rect2i(86, 11, 1, 1), F.ROAD],
	[Rect2i(86, 12, 1, 1), F.ROAD],
	[Rect2i(86, 13, 1, 1), F.ROAD],
	[Rect2i(86, 14, 1, 1), F.ROAD],
	[Rect2i(86, 15, 1, 1), F.ROAD],
	[Rect2i(86, 16, 1, 1), F.ROAD],
	[Rect2i(86, 17, 1, 1), F.ROAD],
	[Rect2i(86, 18, 1, 1), F.ROAD],
	[Rect2i(86, 19, 1, 1), F.ROAD],
	[Rect2i(86, 20, 1, 1), F.ROAD],
	[Rect2i(86, 21, 1, 1), F.ROAD],
	[Rect2i(86, 22, 1, 1), F.ROAD],
	[Rect2i(86, 23, 1, 1), F.ROAD],
	[Rect2i(86, 24, 1, 1), F.ROAD],
	[Rect2i(86, 25, 1, 1), F.ROAD],
	[Rect2i(86, 26, 1, 1), F.ROAD],
	[Rect2i(86, 27, 1, 1), F.ROAD],
	[Rect2i(86, 28, 1, 1), F.ROAD],
	[Rect2i(86, 29, 1, 1), F.ROAD],
	[Rect2i(86, 30, 1, 1), F.ROAD],
	[Rect2i(86, 31, 1, 1), F.ROAD],
	[Rect2i(86, 32, 1, 1), F.ROAD],
	[Rect2i(86, 33, 1, 1), F.ROAD],
	[Rect2i(86, 34, 1, 1), F.ROAD],
	[Rect2i(86, 35, 1, 1), F.ROAD],
	[Rect2i(86, 36, 1, 1), F.ROAD],
	[Rect2i(86, 37, 1, 1), F.ROAD],
	[Rect2i(86, 38, 1, 1), F.ROAD],
	[Rect2i(86, 39, 1, 1), F.ROAD],
	[Rect2i(86, 40, 1, 1), F.ROAD],
	[Rect2i(86, 41, 1, 1), F.ROAD],
	[Rect2i(86, 42, 1, 1), F.ROAD],
	[Rect2i(86, 43, 1, 1), F.ROAD],
	[Rect2i(86, 44, 1, 1), F.ROAD],
	[Rect2i(86, 45, 1, 1), F.ROAD],
	[Rect2i(86, 46, 1, 1), F.ROAD],
	[Rect2i(40, 27, 1, 1), F.ROAD],
	[Rect2i(40, 28, 1, 1), F.ROAD],
	[Rect2i(40, 29, 1, 1), F.ROAD],
	[Rect2i(41, 29, 1, 1), F.ROAD],
	[Rect2i(42, 29, 1, 1), F.ROAD],
	[Rect2i(43, 29, 1, 1), F.ROAD],
	[Rect2i(44, 29, 1, 1), F.ROAD],
	[Rect2i(45, 29, 1, 1), F.ROAD],
	[Rect2i(46, 29, 1, 1), F.ROAD],
	[Rect2i(47, 29, 1, 1), F.ROAD],
	[Rect2i(48, 29, 1, 1), F.ROAD],
	[Rect2i(48, 30, 1, 1), F.ROAD],
	[Rect2i(48, 31, 1, 1), F.ROAD],
	[Rect2i(48, 32, 1, 1), F.ROAD],
	[Rect2i(48, 33, 1, 1), F.ROAD],
	[Rect2i(48, 34, 1, 1), F.ROAD],
	[Rect2i(48, 35, 1, 1), F.ROAD],
	[Rect2i(48, 36, 1, 1), F.ROAD],
	[Rect2i(48, 37, 1, 1), F.ROAD],
	[Rect2i(48, 38, 1, 1), F.ROAD],
	[Rect2i(48, 39, 1, 1), F.ROAD],
	[Rect2i(48, 40, 1, 1), F.ROAD],
	[Rect2i(48, 41, 1, 1), F.ROAD],
	[Rect2i(48, 42, 1, 1), F.ROAD],
	[Rect2i(48, 43, 1, 1), F.ROAD],
	[Rect2i(48, 44, 1, 1), F.ROAD],
	[Rect2i(48, 45, 1, 1), F.ROAD],
	[Rect2i(48, 46, 1, 1), F.ROAD],
	[Rect2i(40, 42, 1, 1), F.ROAD],
	[Rect2i(40, 43, 1, 1), F.ROAD],
	[Rect2i(40, 44, 1, 1), F.ROAD],
	[Rect2i(40, 45, 1, 1), F.ROAD],
	[Rect2i(40, 46, 1, 1), F.ROAD],
	[Rect2i(40, 47, 1, 1), F.ROAD],
	[Rect2i(40, 48, 1, 1), F.ROAD],
	[Rect2i(40, 49, 1, 1), F.ROAD],
	[Rect2i(57, 42, 1, 1), F.ROAD],
	[Rect2i(57, 43, 1, 1), F.ROAD],
	[Rect2i(57, 44, 1, 1), F.ROAD],
	[Rect2i(57, 45, 1, 1), F.ROAD],
	[Rect2i(57, 46, 1, 1), F.ROAD],
	[Rect2i(74, 42, 1, 1), F.ROAD],
	[Rect2i(74, 43, 1, 1), F.ROAD],
	[Rect2i(74, 44, 1, 1), F.ROAD],
	[Rect2i(74, 45, 1, 1), F.ROAD],
	[Rect2i(74, 46, 1, 1), F.ROAD],
	[Rect2i(108, 32, 1, 1), F.ROAD],
	[Rect2i(108, 33, 1, 1), F.ROAD],
	[Rect2i(108, 34, 1, 1), F.ROAD],
	[Rect2i(108, 35, 1, 1), F.ROAD],
	[Rect2i(108, 36, 1, 1), F.ROAD],
	[Rect2i(108, 37, 1, 1), F.ROAD],
	[Rect2i(108, 38, 1, 1), F.ROAD],
	[Rect2i(108, 39, 1, 1), F.ROAD],
	[Rect2i(108, 40, 1, 1), F.ROAD],
	[Rect2i(108, 41, 1, 1), F.ROAD],
	[Rect2i(108, 42, 1, 1), F.ROAD],
	[Rect2i(108, 43, 1, 1), F.ROAD],
	[Rect2i(108, 44, 1, 1), F.ROAD],
	[Rect2i(108, 45, 1, 1), F.ROAD],
	[Rect2i(108, 46, 1, 1), F.ROAD],
	[Rect2i(155, 49, 1, 1), F.ROAD],
	[Rect2i(155, 48, 1, 1), F.ROAD],
	[Rect2i(154, 48, 1, 1), F.ROAD],
	[Rect2i(153, 48, 1, 1), F.ROAD],
	[Rect2i(152, 48, 1, 1), F.ROAD],
	[Rect2i(151, 48, 1, 1), F.ROAD],
	[Rect2i(150, 48, 1, 1), F.ROAD],
	[Rect2i(149, 48, 1, 1), F.ROAD],
	[Rect2i(148, 48, 1, 1), F.ROAD],
	[Rect2i(147, 48, 1, 1), F.ROAD],
	[Rect2i(146, 48, 1, 1), F.ROAD],
	[Rect2i(145, 48, 1, 1), F.ROAD],
	[Rect2i(144, 48, 1, 1), F.ROAD],
	[Rect2i(143, 48, 1, 1), F.ROAD],
	[Rect2i(142, 48, 1, 1), F.ROAD],
	[Rect2i(141, 48, 1, 1), F.ROAD],
	[Rect2i(140, 48, 1, 1), F.ROAD],
	[Rect2i(139, 48, 1, 1), F.ROAD],
	[Rect2i(138, 48, 1, 1), F.ROAD],
	[Rect2i(137, 48, 1, 1), F.ROAD],
	[Rect2i(136, 48, 1, 1), F.ROAD],
	[Rect2i(135, 48, 1, 1), F.ROAD],
	[Rect2i(134, 48, 1, 1), F.ROAD],
	[Rect2i(133, 48, 1, 1), F.ROAD],
	[Rect2i(170, 36, 1, 1), F.GRAVEL],
	[Rect2i(170, 37, 1, 1), F.GRAVEL],
	[Rect2i(170, 38, 1, 1), F.GRAVEL],
	[Rect2i(170, 39, 1, 1), F.GRAVEL],
	[Rect2i(170, 40, 1, 1), F.GRAVEL],
	[Rect2i(170, 41, 1, 1), F.GRAVEL],
	[Rect2i(170, 42, 1, 1), F.GRAVEL],
	[Rect2i(170, 43, 1, 1), F.GRAVEL],
	[Rect2i(170, 44, 1, 1), F.GRAVEL],
	[Rect2i(170, 45, 1, 1), F.GRAVEL],
	[Rect2i(170, 46, 1, 1), F.GRAVEL],
	[Rect2i(170, 47, 1, 1), F.GRAVEL],
	[Rect2i(170, 48, 1, 1), F.GRAVEL],
	[Rect2i(170, 49, 1, 1), F.GRAVEL],
	[Rect2i(170, 53, 1, 1), F.GRAVEL],
	[Rect2i(170, 54, 1, 1), F.GRAVEL],
	[Rect2i(169, 54, 1, 1), F.GRAVEL],
	[Rect2i(168, 54, 1, 1), F.GRAVEL],
	[Rect2i(167, 54, 1, 1), F.GRAVEL],
	[Rect2i(166, 54, 1, 1), F.GRAVEL],
	[Rect2i(165, 54, 1, 1), F.GRAVEL],
	[Rect2i(164, 54, 1, 1), F.GRAVEL],
	[Rect2i(163, 54, 1, 1), F.GRAVEL],
	[Rect2i(162, 54, 1, 1), F.GRAVEL],
	[Rect2i(161, 54, 1, 1), F.GRAVEL],
	[Rect2i(160, 54, 1, 1), F.GRAVEL],
	[Rect2i(159, 54, 1, 1), F.GRAVEL],
	[Rect2i(158, 54, 1, 1), F.GRAVEL],
	[Rect2i(157, 54, 1, 1), F.GRAVEL],
	[Rect2i(156, 54, 1, 1), F.GRAVEL],
	[Rect2i(155, 54, 1, 1), F.GRAVEL],
	[Rect2i(154, 54, 1, 1), F.GRAVEL],
	[Rect2i(153, 54, 1, 1), F.GRAVEL],
	[Rect2i(152, 54, 1, 1), F.GRAVEL],
	[Rect2i(151, 54, 1, 1), F.GRAVEL],
	[Rect2i(150, 54, 1, 1), F.GRAVEL],
	[Rect2i(149, 54, 1, 1), F.GRAVEL],
	[Rect2i(148, 54, 1, 1), F.GRAVEL],
	[Rect2i(147, 54, 1, 1), F.GRAVEL],
	[Rect2i(146, 54, 1, 1), F.GRAVEL],
	[Rect2i(145, 54, 1, 1), F.GRAVEL],
	[Rect2i(144, 54, 1, 1), F.GRAVEL],
	[Rect2i(143, 54, 1, 1), F.GRAVEL],
	[Rect2i(142, 54, 1, 1), F.GRAVEL],
	[Rect2i(141, 54, 1, 1), F.GRAVEL],
	[Rect2i(140, 54, 1, 1), F.GRAVEL],
	[Rect2i(139, 54, 1, 1), F.GRAVEL],
	[Rect2i(138, 54, 1, 1), F.GRAVEL],
	[Rect2i(137, 54, 1, 1), F.GRAVEL],
	[Rect2i(136, 54, 1, 1), F.GRAVEL],
	[Rect2i(135, 54, 1, 1), F.GRAVEL],
	[Rect2i(134, 54, 1, 1), F.GRAVEL],
	[Rect2i(133, 54, 1, 1), F.GRAVEL],
	[Rect2i(178, 61, 1, 1), F.GRAVEL],
	[Rect2i(178, 60, 1, 1), F.GRAVEL],
	[Rect2i(178, 59, 1, 1), F.GRAVEL],
	[Rect2i(178, 58, 1, 1), F.GRAVEL],
	[Rect2i(178, 57, 1, 1), F.GRAVEL],
	[Rect2i(178, 56, 1, 1), F.GRAVEL],
	[Rect2i(178, 55, 1, 1), F.GRAVEL],
	[Rect2i(178, 54, 1, 1), F.GRAVEL],
	[Rect2i(178, 53, 1, 1), F.GRAVEL],
	[Rect2i(178, 49, 1, 1), F.GRAVEL],
	[Rect2i(178, 48, 1, 1), F.GRAVEL],
	[Rect2i(178, 47, 1, 1), F.GRAVEL],
	[Rect2i(178, 46, 1, 1), F.GRAVEL],
	[Rect2i(178, 45, 1, 1), F.GRAVEL],
	[Rect2i(178, 44, 1, 1), F.GRAVEL],
	[Rect2i(178, 43, 1, 1), F.GRAVEL],
	[Rect2i(178, 42, 1, 1), F.GRAVEL],
	[Rect2i(178, 41, 1, 1), F.GRAVEL],
	[Rect2i(178, 40, 1, 1), F.GRAVEL],
	[Rect2i(178, 39, 1, 1), F.GRAVEL],
	[Rect2i(178, 38, 1, 1), F.GRAVEL],
	[Rect2i(178, 37, 1, 1), F.GRAVEL],
	[Rect2i(178, 36, 1, 1), F.GRAVEL],
	[Rect2i(177, 36, 1, 1), F.GRAVEL],
	[Rect2i(176, 36, 1, 1), F.GRAVEL],
	[Rect2i(175, 36, 1, 1), F.GRAVEL],
	[Rect2i(174, 36, 1, 1), F.GRAVEL],
	[Rect2i(173, 36, 1, 1), F.GRAVEL],
	[Rect2i(172, 36, 1, 1), F.GRAVEL],
	[Rect2i(171, 36, 1, 1), F.GRAVEL],
	[Rect2i(178, 72, 1, 1), F.GRAVEL],
	[Rect2i(178, 71, 1, 1), F.GRAVEL],
	[Rect2i(178, 70, 1, 1), F.GRAVEL],
	[Rect2i(178, 69, 1, 1), F.GRAVEL],
	[Rect2i(178, 68, 1, 1), F.GRAVEL],
	[Rect2i(178, 67, 1, 1), F.GRAVEL],
	[Rect2i(178, 66, 1, 1), F.GRAVEL],
	[Rect2i(178, 65, 1, 1), F.GRAVEL],
	[Rect2i(178, 64, 1, 1), F.GRAVEL],
	[Rect2i(178, 63, 1, 1), F.GRAVEL],
	[Rect2i(178, 62, 1, 1), F.GRAVEL],
	[Rect2i(155, 73, 1, 1), F.GRAVEL],
	[Rect2i(155, 72, 1, 1), F.GRAVEL],
	[Rect2i(156, 72, 1, 1), F.GRAVEL],
	[Rect2i(157, 72, 1, 1), F.GRAVEL],
	[Rect2i(158, 72, 1, 1), F.GRAVEL],
	[Rect2i(159, 72, 1, 1), F.GRAVEL],
	[Rect2i(160, 72, 1, 1), F.GRAVEL],
	[Rect2i(161, 72, 1, 1), F.GRAVEL],
	[Rect2i(162, 72, 1, 1), F.GRAVEL],
	[Rect2i(163, 72, 1, 1), F.GRAVEL],
	[Rect2i(164, 72, 1, 1), F.GRAVEL],
	[Rect2i(165, 72, 1, 1), F.GRAVEL],
	[Rect2i(166, 72, 1, 1), F.GRAVEL],
	[Rect2i(167, 72, 1, 1), F.GRAVEL],
	[Rect2i(168, 72, 1, 1), F.GRAVEL],
	[Rect2i(169, 72, 1, 1), F.GRAVEL],
	[Rect2i(170, 72, 1, 1), F.GRAVEL],
	[Rect2i(171, 72, 1, 1), F.GRAVEL],
	[Rect2i(172, 72, 1, 1), F.GRAVEL],
	[Rect2i(173, 72, 1, 1), F.GRAVEL],
	[Rect2i(174, 72, 1, 1), F.GRAVEL],
	[Rect2i(175, 72, 1, 1), F.GRAVEL],
	[Rect2i(176, 72, 1, 1), F.GRAVEL],
	[Rect2i(177, 72, 1, 1), F.GRAVEL],
	[Rect2i(65, 11, 4, 2), F.DEEP_SNOW],
	[Rect2i(163, 14, 4, 2), F.DEEP_SNOW],
	[Rect2i(164, 29, 4, 2), F.DEEP_SNOW],
	[Rect2i(20, 65, 4, 3), F.GRAVEL],
	[Rect2i(54, 67, 4, 3), F.GRAVEL],
	[Rect2i(80, 70, 4, 3), F.GRAVEL],
	[Rect2i(101, 69, 4, 3), F.GRAVEL],
	[Rect2i(123, 68, 4, 3), F.GRAVEL],
]

const BUILDING_ROWS: Array = [
	["어장 주택", Rect2i(34, 15, 14, 12)],
	["어장 주택", Rect2i(34, 30, 14, 12)],
	["어장 주택", Rect2i(51, 27, 14, 12)],
	["어장 주택", Rect2i(68, 30, 14, 12)],
	["어장 관리소", Rect2i(99, 15, 20, 17)],
	["얼음 창고", Rect2i(136, 77, 40, 27)],
	["얼음 낚시 움막", Rect2i(9, 81, 7, 7)],
	["얼음 낚시 움막", Rect2i(49, 80, 7, 7)],
	["얼음 낚시 움막", Rect2i(89, 87, 7, 7)],
	["얼음 낚시 움막", Rect2i(116, 79, 7, 7)],
]

const LEVEL_ROWS: Array = [
	[1, 4, Rect2i(99, 15, 20, 17)],
	[-1, 5, Rect2i(136, 77, 40, 27)],
]

const WALL_ROWS: Array = [
	[0, Rect2i(41, 16, 1, 10)],
	[0, Rect2i(41, 31, 1, 10)],
	[0, Rect2i(58, 28, 1, 10)],
	[0, Rect2i(75, 31, 1, 10)],
	[0, Rect2i(109, 16, 1, 15)],
	[0, Rect2i(141, 81, 30, 1)],
	[0, Rect2i(141, 99, 30, 1)],
	[0, Rect2i(141, 82, 1, 17)],
	[0, Rect2i(170, 82, 1, 17)],
	[0, Rect2i(156, 82, 1, 17)],
	[0, Rect2i(142, 90, 14, 1)],
	[1, Rect2i(109, 16, 1, 15)],
	[-1, Rect2i(141, 81, 30, 1)],
	[-1, Rect2i(141, 99, 30, 1)],
	[-1, Rect2i(141, 82, 1, 17)],
	[-1, Rect2i(170, 82, 1, 17)],
	[-1, Rect2i(156, 82, 1, 17)],
	[-1, Rect2i(142, 90, 14, 1)],
]

const DOOR_ROWS: Array = [
	[0, Vector2i(41, 21), "closed", 0],
	[0, Vector2i(40, 26), "closed", 0],
	[0, Vector2i(41, 36), "closed", 1],
	[0, Vector2i(40, 41), "closed", 1],
	[0, Vector2i(58, 33), "closed", 2],
	[0, Vector2i(57, 38), "closed", 2],
	[0, Vector2i(75, 36), "closed", 3],
	[0, Vector2i(74, 41), "closed", 3],
	[0, Vector2i(109, 23), "closed", 4],
	[0, Vector2i(108, 31), "closed", 4],
	[0, Vector2i(141, 83), "closed", 5],
	[0, Vector2i(141, 97), "closed", 5],
	[0, Vector2i(170, 83), "closed", 5],
	[0, Vector2i(155, 77), "open", 5],
	[0, Vector2i(11, 87), "closed", 6],
	[0, Vector2i(51, 86), "closed", 7],
	[0, Vector2i(91, 93), "closed", 8],
	[0, Vector2i(118, 85), "closed", 9],
	[1, Vector2i(109, 23), "closed", 4],
	[-1, Vector2i(141, 83), "closed", 5],
	[-1, Vector2i(141, 97), "closed", 5],
	[-1, Vector2i(170, 83), "closed", 5],
]

const WINDOW_ROWS: Array = [
	[0, Vector2i(37, 15), 0],
	[0, Vector2i(44, 26), 0],
	[0, Vector2i(34, 18), 0],
	[0, Vector2i(47, 23), 0],
	[0, Vector2i(37, 30), 1],
	[0, Vector2i(44, 41), 1],
	[0, Vector2i(34, 33), 1],
	[0, Vector2i(47, 38), 1],
	[0, Vector2i(54, 27), 2],
	[0, Vector2i(61, 38), 2],
	[0, Vector2i(51, 30), 2],
	[0, Vector2i(64, 35), 2],
	[0, Vector2i(71, 30), 3],
	[0, Vector2i(78, 41), 3],
	[0, Vector2i(68, 33), 3],
	[0, Vector2i(81, 38), 3],
	[0, Vector2i(102, 15), 4],
	[0, Vector2i(115, 31), 4],
	[0, Vector2i(99, 18), 4],
	[0, Vector2i(118, 28), 4],
	[0, Vector2i(139, 77), 5],
	[0, Vector2i(172, 103), 5],
	[0, Vector2i(136, 80), 5],
	[0, Vector2i(175, 100), 5],
	[0, Vector2i(11, 81), 6],
	[0, Vector2i(51, 80), 7],
	[0, Vector2i(91, 87), 8],
	[0, Vector2i(118, 79), 9],
	[1, Vector2i(102, 15), 4],
	[1, Vector2i(115, 31), 4],
	[1, Vector2i(99, 18), 4],
	[1, Vector2i(118, 28), 4],
]

const STAIR_ROWS: Array = [
	[Vector2i(101, 20), 0, 1],
	[Vector2i(138, 83), -1, 0],
]

const STOVE_ROWS: Array = [
	[Vector2i(10, 82), 6, 0],
	[Vector2i(50, 81), 7, 0],
	[Vector2i(90, 88), 8, 0],
	[Vector2i(117, 80), 9, 0],
]

const CONTAINER_ROWS: Array = [
	["supply_0", "식량 찬장", Vector2i(36, 18), 0, ["food_pack"], 0],
	["supply_1", "목재 선반", Vector2i(45, 24), 0, ["plank"], 0],
	["supply_2", "식량 찬장", Vector2i(36, 33), 1, ["food_pack"], 0],
	["supply_3", "목재 선반", Vector2i(45, 39), 1, ["plank"], 0],
	["supply_4", "식량 찬장", Vector2i(53, 30), 2, ["food_pack"], 0],
	["supply_5", "목재 선반", Vector2i(62, 36), 2, ["plank"], 0],
	["supply_6", "식량 찬장", Vector2i(70, 33), 3, ["food_pack"], 0],
	["supply_7", "목재 선반", Vector2i(79, 39), 3, ["plank"], 0],
	["supply_8", "식량 찬장", Vector2i(101, 18), 4, ["food_pack"], 0],
	["supply_9", "목재 선반", Vector2i(116, 29), 4, ["plank"], 0],
	["supply_10", "저장 식량 상자", Vector2i(143, 83), 5, ["food_pack", "food_pack"], 0],
	["supply_11", "연료 보관함", Vector2i(143, 97), 5, ["wood", "wood", "wood"], 0],
	["supply_12", "깊은 부품 상자", Vector2i(158, 97), 5, ["scrap","scrap","food_pack","wood"], 0],
	["supply_13", "작업 통로 선반", Vector2i(138, 79), 5, ["plank"], 0],
	["supply_14", "움막 낚시 선반", Vector2i(13, 85), 6, ["food_pack"], 0],
	["supply_15", "움막 낚시 선반", Vector2i(53, 84), 7, ["food_pack"], 0],
	["supply_16", "움막 낚시 선반", Vector2i(93, 91), 8, ["food_pack"], 0],
	["supply_17", "움막 낚시 선반", Vector2i(120, 83), 9, ["food_pack"], 0],
	["supply_18", "식량 찬장", Vector2i(101, 18), 4, ["food_pack"], 1],
	["supply_19", "위층 작업 선반", Vector2i(116, 29), 4, ["plank"], 1],
	["supply_20", "저장 식량 상자", Vector2i(143, 83), 5, ["food_pack", "food_pack"], -1],
	["supply_21", "연료 보관함", Vector2i(143, 97), 5, ["wood", "wood", "wood"], -1],
	["supply_22", "깊은 부품 상자", Vector2i(158, 97), 5, ["scrap","scrap","food_pack","wood"], -1],
	["supply_23", "작업 통로 선반", Vector2i(138, 79), 5, ["plank"], -1],
	["pier_wood", "잔교 목재 상자", Vector2i(125, 102), -1, ["plank","wood"], 0],
]

const SALVAGE_ROWS: Array = [
	["pier_repair", "잔교 수선 목재", Vector2i(31, 54), "wood", 2],
]

const ZONE_ROWS: Array = [
	["A", Rect2i(0, 53, 180, 55), Vector2i(58, 57)],
	["B", Rect2i(0, 0, 180, 53), Vector2i(36, 17)],
	["C", Rect2i(103, 92, 24, 12), Vector2i(105, 94)],
	["D", Rect2i(136, 77, 40, 27), Vector2i(138, 79)],
]

const ENTRY_CELLS: Dictionary = {
	"shore_west": [Vector2i(0, 45), Vector2i(0, 46)],
	"shore_east": [Vector2i(179, 36), Vector2i(179, 37)],
	"village_back": [Vector2i(85, 0), Vector2i(86, 0)],
}

const ENTRY_GAP: Dictionary = {"shore_west":0.6,"shore_east":0.6,"village_back":2.5}

const BARRICADE_CELLS: Array[Vector2i] = [
	Vector2i(48, 35),
	Vector2i(49, 35),
	Vector2i(50, 35),
	Vector2i(65, 35),
	Vector2i(66, 35),
	Vector2i(67, 35),
]

const PROPS: Array = [
	{"kind": "overturned_boat", "rect": Rect2i(60, 43, 4, 2), "solid": "low", "facing": 0, "note": "하역 마당 엄폐 · 뒤집힌 배"},
	{"kind": "net_drying_rack", "rect": Rect2i(77, 43, 1, 4), "solid": "low", "facing": 1, "note": "하역 마당 엄폐 · 그물 건조대"},
	{"kind": "fish_trap_stack", "rect": Rect2i(101, 36, 2, 3), "solid": "low", "facing": 1, "note": "하역 마당 엄폐 · 통발 쌓음"},
	{"kind": "firewood_stack", "rect": Rect2i(118, 42, 3, 2), "solid": "low", "facing": 0, "note": "하역 마당 엄폐 · 장작 단"},
	{"kind": "pier_deck", "rect": Rect2i(32, 53, 3, 26), "solid": "none", "facing": 1, "note": "잔교 통로 구간 · 잔교"},
	{"kind": "fishing_platform", "rect": Rect2i(88, 75, 24, 12), "solid": "none", "facing": 0, "note": "어장 작업 무리 · 어장 작업대"},
	{"kind": "sunken_wheelhouse", "rect": Rect2i(23, 92, 4, 3), "solid": "wall", "facing": 0, "note": "가라앉은 배 1 · 조타실 윗부분"},
	{"kind": "sunken_bow", "rect": Rect2i(31, 93, 2, 4), "solid": "wall", "facing": 1, "note": "가라앉은 배 1 · 솟은 뱃머리"},
	{"kind": "sunken_deck_section", "rect": Rect2i(24, 98, 8, 3), "solid": "low", "facing": 0, "note": "가라앉은 배 1 · 드러난 갑판 조각"},
	{"kind": "fallen_mast", "rect": Rect2i(29, 102, 7, 1), "solid": "low", "facing": 0, "note": "가라앉은 배 1 · 쓰러진 돛대"},
	{"kind": "sunken_wheelhouse", "rect": Rect2i(67, 91, 4, 3), "solid": "wall", "facing": 0, "note": "가라앉은 배 2 · 조타실 윗부분"},
	{"kind": "sunken_bow", "rect": Rect2i(75, 92, 2, 4), "solid": "wall", "facing": 1, "note": "가라앉은 배 2 · 솟은 뱃머리"},
	{"kind": "sunken_deck_section", "rect": Rect2i(68, 97, 8, 3), "solid": "low", "facing": 0, "note": "가라앉은 배 2 · 드러난 갑판 조각"},
	{"kind": "fish_hoist", "rect": Rect2i(104, 93, 3, 3), "solid": "wall", "facing": 0, "note": "작업대 1 · 어망 윈치 틀"},
	{"kind": "cleaning_table", "rect": Rect2i(110, 94, 4, 2), "solid": "low", "facing": 0, "note": "작업대 1 · 손질대"},
	{"kind": "fish_crate_stack", "rect": Rect2i(115, 96, 2, 2), "solid": "low", "facing": 0, "note": "작업대 1 · 생선 상자 더미"},
	{"kind": "net_pile", "rect": Rect2i(106, 99, 2, 2), "solid": "low", "facing": 0, "note": "작업대 1 · 그물 더미"},
	{"kind": "ice_saw_frame", "rect": Rect2i(121, 101, 3, 2), "solid": "low", "facing": 0, "note": "작업대 1 · 얼음 톱 틀"},
	{"kind": "ice_cut_pool", "rect": Rect2i(98, 97, 4, 3), "solid": "none", "facing": 0, "note": "작업대 1 · 잘라 낸 얼음 자리"},
	{"kind": "fish_drying_frame", "rect": Rect2i(29, 17, 4, 2), "solid": "low", "facing": 0, "note": "주택 마당 1 · 생선 건조 틀"},
	{"kind": "fish_trap_stack", "rect": Rect2i(37, 11, 2, 2), "solid": "low", "facing": 0, "note": "주택 마당 1 · 통발 쌓음"},
	{"kind": "net_pile", "rect": Rect2i(50, 20, 2, 2), "solid": "low", "facing": 0, "note": "주택 마당 1 · 그물 더미"},
	{"kind": "dry_bush", "rect": Rect2i(34, 28, 2, 2), "solid": "none", "facing": 0, "note": "주택 마당 1 · 마른 덤불"},
	{"kind": "overturned_boat", "rect": Rect2i(26, 29, 4, 2), "solid": "low", "facing": 0, "note": "주택 마당 2 · 뒤집힌 배"},
	{"kind": "net_drying_rack", "rect": Rect2i(29, 20, 4, 1), "solid": "low", "facing": 0, "note": "주택 마당 2 · 그물 건조대"},
	{"kind": "buoy_line", "rect": Rect2i(49, 34, 2, 1), "solid": "none", "facing": 0, "note": "주택 마당 2 · 부표 줄"},
	{"kind": "snow_drift", "rect": Rect2i(34, 43, 4, 2), "solid": "none", "facing": 0, "note": "주택 마당 2 · 눈더미"},
	{"kind": "fish_drying_frame", "rect": Rect2i(49, 25, 4, 2), "solid": "low", "facing": 0, "note": "주택 마당 3 · 생선 건조 틀"},
	{"kind": "fish_trap_stack", "rect": Rect2i(54, 25, 2, 2), "solid": "low", "facing": 0, "note": "주택 마당 3 · 통발 쌓음"},
	{"kind": "net_pile", "rect": Rect2i(58, 25, 2, 2), "solid": "low", "facing": 0, "note": "주택 마당 3 · 그물 더미"},
	{"kind": "dry_bush", "rect": Rect2i(52, 44, 2, 2), "solid": "none", "facing": 0, "note": "주택 마당 3 · 마른 덤불"},
	{"kind": "overturned_boat", "rect": Rect2i(61, 25, 4, 2), "solid": "low", "facing": 0, "note": "주택 마당 4 · 뒤집힌 배"},
	{"kind": "net_drying_rack", "rect": Rect2i(71, 26, 4, 1), "solid": "low", "facing": 0, "note": "주택 마당 4 · 그물 건조대"},
	{"kind": "buoy_line", "rect": Rect2i(84, 35, 2, 1), "solid": "none", "facing": 0, "note": "주택 마당 4 · 부표 줄"},
	{"kind": "snow_drift", "rect": Rect2i(68, 43, 4, 2), "solid": "none", "facing": 0, "note": "주택 마당 4 · 눈더미"},
	{"kind": "frozen_reeds", "rect": Rect2i(7, 53, 3, 3), "solid": "none", "facing": 0, "note": "물가 무리 1 · 얼어붙은 갈대"},
	{"kind": "shore_ice_heap", "rect": Rect2i(11, 49, 3, 2), "solid": "low", "facing": 0, "note": "물가 무리 1 · 물가 얼음 무더기"},
	{"kind": "fishing_hole", "rect": Rect2i(14, 47, 1, 1), "solid": "none", "facing": 0, "note": "물가 무리 1 · 낚시 구멍"},
	{"kind": "frozen_reeds", "rect": Rect2i(28, 53, 3, 3), "solid": "none", "facing": 0, "note": "물가 무리 2 · 얼어붙은 갈대"},
	{"kind": "shore_ice_heap", "rect": Rect2i(32, 50, 3, 2), "solid": "low", "facing": 0, "note": "물가 무리 2 · 물가 얼음 무더기"},
	{"kind": "fishing_hole", "rect": Rect2i(36, 47, 1, 1), "solid": "none", "facing": 0, "note": "물가 무리 2 · 낚시 구멍"},
	{"kind": "frozen_reeds", "rect": Rect2i(48, 56, 3, 3), "solid": "none", "facing": 0, "note": "물가 무리 3 · 얼어붙은 갈대"},
	{"kind": "fishing_hole", "rect": Rect2i(57, 46, 1, 1), "solid": "none", "facing": 0, "note": "물가 무리 3 · 낚시 구멍"},
	{"kind": "frozen_reeds", "rect": Rect2i(70, 56, 3, 3), "solid": "none", "facing": 0, "note": "물가 무리 4 · 얼어붙은 갈대"},
	{"kind": "fishing_hole", "rect": Rect2i(79, 46, 1, 1), "solid": "none", "facing": 0, "note": "물가 무리 4 · 낚시 구멍"},
	{"kind": "frozen_reeds", "rect": Rect2i(92, 56, 3, 3), "solid": "none", "facing": 0, "note": "물가 무리 5 · 얼어붙은 갈대"},
	{"kind": "fishing_hole", "rect": Rect2i(101, 46, 1, 1), "solid": "none", "facing": 0, "note": "물가 무리 5 · 낚시 구멍"},
	{"kind": "frozen_reeds", "rect": Rect2i(114, 56, 3, 3), "solid": "none", "facing": 0, "note": "물가 무리 6 · 얼어붙은 갈대"},
	{"kind": "fishing_hole", "rect": Rect2i(123, 46, 1, 1), "solid": "none", "facing": 0, "note": "물가 무리 6 · 낚시 구멍"},
	{"kind": "frozen_reeds", "rect": Rect2i(139, 53, 3, 3), "solid": "none", "facing": 0, "note": "물가 무리 7 · 얼어붙은 갈대"},
	{"kind": "shore_ice_heap", "rect": Rect2i(142, 50, 3, 2), "solid": "low", "facing": 0, "note": "물가 무리 7 · 물가 얼음 무더기"},
	{"kind": "fishing_hole", "rect": Rect2i(146, 47, 1, 1), "solid": "none", "facing": 0, "note": "물가 무리 7 · 낚시 구멍"},
	{"kind": "tool_bench", "rect": Rect2i(5, 83, 3, 1), "solid": "low", "facing": 0, "note": "움막 1 · 연장 작업대"},
	{"kind": "firewood_stack", "rect": Rect2i(18, 82, 3, 2), "solid": "low", "facing": 0, "note": "움막 1 · 장작 단"},
	{"kind": "fishing_hole", "rect": Rect2i(7, 89, 1, 1), "solid": "none", "facing": 0, "note": "움막 1 · 낚시 구멍"},
	{"kind": "tip_up_flag", "rect": Rect2i(8, 89, 1, 1), "solid": "none", "facing": 0, "note": "움막 1 · 낚시 깃대"},
	{"kind": "fishing_hole", "rect": Rect2i(10, 91, 1, 1), "solid": "none", "facing": 0, "note": "움막 1 · 낚시 구멍"},
	{"kind": "tip_up_flag", "rect": Rect2i(11, 91, 1, 1), "solid": "none", "facing": 0, "note": "움막 1 · 낚시 깃대"},
	{"kind": "fishing_hole", "rect": Rect2i(14, 90, 1, 1), "solid": "none", "facing": 0, "note": "움막 1 · 낚시 구멍"},
	{"kind": "tip_up_flag", "rect": Rect2i(15, 90, 1, 1), "solid": "none", "facing": 0, "note": "움막 1 · 낚시 깃대"},
	{"kind": "tool_bench", "rect": Rect2i(45, 82, 3, 1), "solid": "low", "facing": 0, "note": "움막 2 · 연장 작업대"},
	{"kind": "firewood_stack", "rect": Rect2i(58, 81, 3, 2), "solid": "low", "facing": 0, "note": "움막 2 · 장작 단"},
	{"kind": "fishing_hole", "rect": Rect2i(47, 88, 1, 1), "solid": "none", "facing": 0, "note": "움막 2 · 낚시 구멍"},
	{"kind": "tip_up_flag", "rect": Rect2i(48, 88, 1, 1), "solid": "none", "facing": 0, "note": "움막 2 · 낚시 깃대"},
	{"kind": "fishing_hole", "rect": Rect2i(50, 90, 1, 1), "solid": "none", "facing": 0, "note": "움막 2 · 낚시 구멍"},
	{"kind": "tip_up_flag", "rect": Rect2i(51, 90, 1, 1), "solid": "none", "facing": 0, "note": "움막 2 · 낚시 깃대"},
	{"kind": "fishing_hole", "rect": Rect2i(54, 89, 1, 1), "solid": "none", "facing": 0, "note": "움막 2 · 낚시 구멍"},
	{"kind": "tip_up_flag", "rect": Rect2i(55, 89, 1, 1), "solid": "none", "facing": 0, "note": "움막 2 · 낚시 깃대"},
	{"kind": "tool_bench", "rect": Rect2i(85, 89, 3, 1), "solid": "low", "facing": 0, "note": "움막 3 · 연장 작업대"},
	{"kind": "firewood_stack", "rect": Rect2i(98, 88, 3, 2), "solid": "low", "facing": 0, "note": "움막 3 · 장작 단"},
	{"kind": "fishing_hole", "rect": Rect2i(87, 95, 1, 1), "solid": "none", "facing": 0, "note": "움막 3 · 낚시 구멍"},
	{"kind": "tip_up_flag", "rect": Rect2i(88, 95, 1, 1), "solid": "none", "facing": 0, "note": "움막 3 · 낚시 깃대"},
	{"kind": "fishing_hole", "rect": Rect2i(90, 97, 1, 1), "solid": "none", "facing": 0, "note": "움막 3 · 낚시 구멍"},
	{"kind": "tip_up_flag", "rect": Rect2i(91, 97, 1, 1), "solid": "none", "facing": 0, "note": "움막 3 · 낚시 깃대"},
	{"kind": "fishing_hole", "rect": Rect2i(94, 96, 1, 1), "solid": "none", "facing": 0, "note": "움막 3 · 낚시 구멍"},
	{"kind": "tip_up_flag", "rect": Rect2i(95, 96, 1, 1), "solid": "none", "facing": 0, "note": "움막 3 · 낚시 깃대"},
	{"kind": "tool_bench", "rect": Rect2i(112, 81, 3, 1), "solid": "low", "facing": 0, "note": "움막 4 · 연장 작업대"},
	{"kind": "firewood_stack", "rect": Rect2i(125, 80, 3, 2), "solid": "low", "facing": 0, "note": "움막 4 · 장작 단"},
	{"kind": "fishing_hole", "rect": Rect2i(114, 87, 1, 1), "solid": "none", "facing": 0, "note": "움막 4 · 낚시 구멍"},
	{"kind": "tip_up_flag", "rect": Rect2i(115, 87, 1, 1), "solid": "none", "facing": 0, "note": "움막 4 · 낚시 깃대"},
	{"kind": "fishing_hole", "rect": Rect2i(117, 89, 1, 1), "solid": "none", "facing": 0, "note": "움막 4 · 낚시 구멍"},
	{"kind": "tip_up_flag", "rect": Rect2i(118, 89, 1, 1), "solid": "none", "facing": 0, "note": "움막 4 · 낚시 깃대"},
	{"kind": "fishing_hole", "rect": Rect2i(121, 88, 1, 1), "solid": "none", "facing": 0, "note": "움막 4 · 낚시 구멍"},
	{"kind": "tip_up_flag", "rect": Rect2i(122, 88, 1, 1), "solid": "none", "facing": 0, "note": "움막 4 · 낚시 깃대"},
	{"kind": "fish_truck", "rect": Rect2i(170, 73, 6, 3), "solid": "wall", "facing": 0, "note": "창고 앞뜰 · 생선 운반 트럭"},
	{"kind": "boat_on_blocks", "rect": Rect2i(150, 62, 5, 2), "solid": "low", "facing": 0, "note": "창고 앞뜰 · 받침대에 얹힌 배"},
	{"kind": "tool_bench", "rect": Rect2i(150, 71, 3, 1), "solid": "low", "facing": 0, "note": "창고 앞뜰 · 연장 작업대"},
	{"kind": "pallet_stack", "rect": Rect2i(169, 70, 2, 2), "solid": "low", "facing": 0, "note": "창고 앞뜰 · 상자 팔레트"},
	{"kind": "ice_block_stack", "rect": Rect2i(131, 83, 3, 2), "solid": "low", "facing": 0, "note": "창고 앞뜰 · 얼음 덩이 쌓음"},
	{"kind": "ice_sled_load", "rect": Rect2i(131, 90, 3, 1), "solid": "low", "facing": 0, "note": "창고 앞뜰 · 짐 실은 썰매"},
	{"kind": "fuel_tank", "rect": Rect2i(122, 18, 3, 3), "solid": "wall", "facing": 0, "note": "설비 뒤편 · 연료 탱크"},
	{"kind": "generator_unit", "rect": Rect2i(122, 24, 2, 2), "solid": "low", "facing": 0, "note": "설비 뒤편 · 발전기"},
	{"kind": "fuel_drum_group", "rect": Rect2i(126, 26, 2, 2), "solid": "low", "facing": 0, "note": "설비 뒤편 · 연료 드럼"},
	{"kind": "rubbish_pile", "rect": Rect2i(96, 17, 2, 1), "solid": "none", "facing": 0, "note": "설비 뒤편 · 쏟아진 쓰레기"},
	{"kind": "bare_willow", "rect": Rect2i(8, 20, 1, 1), "solid": "tree", "facing": 0, "note": "버드나무 무리 1 · 마른 버드나무"},
	{"kind": "bare_willow", "rect": Rect2i(10, 21, 1, 1), "solid": "tree", "facing": 0, "note": "버드나무 무리 1 · 마른 버드나무"},
	{"kind": "bare_willow", "rect": Rect2i(7, 23, 1, 1), "solid": "tree", "facing": 0, "note": "버드나무 무리 1 · 마른 버드나무"},
	{"kind": "bare_willow", "rect": Rect2i(11, 24, 1, 1), "solid": "tree", "facing": 0, "note": "버드나무 무리 1 · 마른 버드나무"},
	{"kind": "bare_willow", "rect": Rect2i(9, 26, 1, 1), "solid": "tree", "facing": 0, "note": "버드나무 무리 1 · 마른 버드나무"},
	{"kind": "bare_willow", "rect": Rect2i(24, 3, 1, 1), "solid": "tree", "facing": 0, "note": "버드나무 무리 2 · 마른 버드나무"},
	{"kind": "bare_willow", "rect": Rect2i(26, 4, 1, 1), "solid": "tree", "facing": 0, "note": "버드나무 무리 2 · 마른 버드나무"},
	{"kind": "bare_willow", "rect": Rect2i(23, 6, 1, 1), "solid": "tree", "facing": 0, "note": "버드나무 무리 2 · 마른 버드나무"},
	{"kind": "bare_willow", "rect": Rect2i(27, 7, 1, 1), "solid": "tree", "facing": 0, "note": "버드나무 무리 2 · 마른 버드나무"},
	{"kind": "bare_willow", "rect": Rect2i(25, 9, 1, 1), "solid": "tree", "facing": 0, "note": "버드나무 무리 2 · 마른 버드나무"},
	{"kind": "bare_willow", "rect": Rect2i(79, 4, 1, 1), "solid": "tree", "facing": 0, "note": "버드나무 무리 3 · 마른 버드나무"},
	{"kind": "bare_willow", "rect": Rect2i(81, 5, 1, 1), "solid": "tree", "facing": 0, "note": "버드나무 무리 3 · 마른 버드나무"},
	{"kind": "bare_willow", "rect": Rect2i(78, 7, 1, 1), "solid": "tree", "facing": 0, "note": "버드나무 무리 3 · 마른 버드나무"},
	{"kind": "bare_willow", "rect": Rect2i(82, 8, 1, 1), "solid": "tree", "facing": 0, "note": "버드나무 무리 3 · 마른 버드나무"},
	{"kind": "bare_willow", "rect": Rect2i(80, 10, 1, 1), "solid": "tree", "facing": 0, "note": "버드나무 무리 3 · 마른 버드나무"},
	{"kind": "bare_willow", "rect": Rect2i(141, 13, 1, 1), "solid": "tree", "facing": 0, "note": "버드나무 무리 4 · 마른 버드나무"},
	{"kind": "bare_willow", "rect": Rect2i(143, 14, 1, 1), "solid": "tree", "facing": 0, "note": "버드나무 무리 4 · 마른 버드나무"},
	{"kind": "bare_willow", "rect": Rect2i(140, 16, 1, 1), "solid": "tree", "facing": 0, "note": "버드나무 무리 4 · 마른 버드나무"},
	{"kind": "bare_willow", "rect": Rect2i(144, 17, 1, 1), "solid": "tree", "facing": 0, "note": "버드나무 무리 4 · 마른 버드나무"},
	{"kind": "bare_willow", "rect": Rect2i(142, 19, 1, 1), "solid": "tree", "facing": 0, "note": "버드나무 무리 4 · 마른 버드나무"},
	{"kind": "bare_willow", "rect": Rect2i(156, 37, 1, 1), "solid": "tree", "facing": 0, "note": "버드나무 무리 5 · 마른 버드나무"},
	{"kind": "bare_willow", "rect": Rect2i(158, 38, 1, 1), "solid": "tree", "facing": 0, "note": "버드나무 무리 5 · 마른 버드나무"},
	{"kind": "bare_willow", "rect": Rect2i(155, 40, 1, 1), "solid": "tree", "facing": 0, "note": "버드나무 무리 5 · 마른 버드나무"},
	{"kind": "bare_willow", "rect": Rect2i(159, 41, 1, 1), "solid": "tree", "facing": 0, "note": "버드나무 무리 5 · 마른 버드나무"},
	{"kind": "bare_willow", "rect": Rect2i(157, 43, 1, 1), "solid": "tree", "facing": 0, "note": "버드나무 무리 5 · 마른 버드나무"},
	{"kind": "snow_drift", "rect": Rect2i(65, 11, 4, 2), "solid": "none", "facing": 0, "note": "길가 눈 쌓임 · 눈더미"},
	{"kind": "snow_drift", "rect": Rect2i(163, 14, 4, 2), "solid": "none", "facing": 0, "note": "길가 눈 쌓임 · 눈더미"},
	{"kind": "snow_drift", "rect": Rect2i(164, 29, 4, 2), "solid": "none", "facing": 0, "note": "길가 눈 쌓임 · 눈더미"},
	{"kind": "ice_cut_pool", "rect": Rect2i(20, 65, 4, 3), "solid": "none", "facing": 0, "note": "얼음 채취 흔적 · 잘라 낸 얼음 자리"},
	{"kind": "ice_cut_pool", "rect": Rect2i(54, 67, 4, 3), "solid": "none", "facing": 0, "note": "얼음 채취 흔적 · 잘라 낸 얼음 자리"},
	{"kind": "ice_cut_pool", "rect": Rect2i(80, 70, 4, 3), "solid": "none", "facing": 0, "note": "얼음 채취 흔적 · 잘라 낸 얼음 자리"},
	{"kind": "ice_cut_pool", "rect": Rect2i(101, 69, 4, 3), "solid": "none", "facing": 0, "note": "얼음 채취 흔적 · 잘라 낸 얼음 자리"},
	{"kind": "ice_cut_pool", "rect": Rect2i(123, 68, 4, 3), "solid": "none", "facing": 0, "note": "얼음 채취 흔적 · 잘라 낸 얼음 자리"},
	{"kind": "buoy_line", "rect": Rect2i(124, 101, 2, 1), "solid": "none", "facing": 0, "note": "잔교 물자 표시 · 부표 줄"},
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
