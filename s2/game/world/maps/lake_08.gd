# 이 지도가 다른 판단을 만드는 것: 서쪽 정박지의 배 골목을 가려 건널지, 북쪽 둑길을 따라 멀리 수리소로 갈지 고른다.
extends RefCounted
## 셋째 판. 1칸은 1m. 물가의 연속된 얼음은 걸을 수 있으며 지도 끝이 깊은 물이다.
## 지하와 위층은 같은 칸의 계단으로 잇고, 깊은 창고는 순환 통로와 세 저장 주머니로 나눈다.

const FieldGrid = preload("res://game/world/field_grid.gd")
const S = FieldGrid.Solid
const F = FieldGrid.Floor

const WIDTH: int = 180

const HEIGHT: int = 104

const PLACE_ID: String = "lake_08"

const LAKE_SIDE: String = "upper"

const TRAIN: Rect2i = Rect2i(78, 49, 80, 3)

const BANDS: Dictionary = {"upper": Rect2i(58, 27, 120, 22), "lower": Rect2i(58, 52, 120, 23)}

const ZONE_NAMES: Dictionary = {"A":"얼어붙은 정박지","B":"어장 마을","C":"잔교 작업장","D":"보트 수리소","":"바깥"}
## 무전 문장에 쓰는 들어오는 길의 이름, 길마다의 비중, 첫 물결이 오는 길.
const ENTRY_NAMES: Dictionary = {"shore_west": "서쪽 호숫가", "shore_east": "동쪽 호숫가", "village_back": "마을 뒤쪽"}
const ENTRY_WEIGHTS: Dictionary = {"shore_west": 0.4, "shore_east": 0.4, "village_back": 0.2}
const FIRST_ENTRY: String = "shore_west"

const FLOOR_PATCHES: Array = [
	[Rect2i(0, 0, 91, 104), F.ICE],
	[Rect2i(75, 49, 105, 3), F.RAIL],
	[Rect2i(75, 46, 86, 3), F.PLATFORM],
	[Rect2i(75, 52, 86, 3), F.PLATFORM],
	[Rect2i(47, 18, 46, 3), F.WOOD],
	[Rect2i(55, 9, 24, 14), F.PLATFORM],
	[Rect2i(50, 14, 4, 3), F.GRAVEL],
	[Rect2i(129, 76, 4, 2), F.DEEP_SNOW],
	[Rect2i(130, 101, 4, 2), F.DEEP_SNOW],
	[Rect2i(81, 13, 1, 1), F.GRAVEL],
	[Rect2i(81, 26, 1, 1), F.GRAVEL],
	[Rect2i(81, 39, 1, 1), F.GRAVEL],
	[Rect2i(78, 55, 1, 1), F.GRAVEL],
	[Rect2i(81, 65, 1, 1), F.GRAVEL],
	[Rect2i(80, 77, 1, 1), F.GRAVEL],
	[Rect2i(81, 91, 1, 1), F.GRAVEL],
	[Rect2i(77, 86, 1, 1), F.GRAVEL],
	[Rect2i(80, 88, 1, 1), F.GRAVEL],
	[Rect2i(84, 87, 1, 1), F.GRAVEL],
	[Rect2i(97, 0, 1, 1), F.ROAD],
	[Rect2i(97, 1, 1, 1), F.ROAD],
	[Rect2i(97, 2, 1, 1), F.ROAD],
	[Rect2i(97, 3, 1, 1), F.ROAD],
	[Rect2i(97, 4, 1, 1), F.ROAD],
	[Rect2i(97, 5, 1, 1), F.ROAD],
	[Rect2i(97, 6, 1, 1), F.ROAD],
	[Rect2i(97, 7, 1, 1), F.ROAD],
	[Rect2i(97, 8, 1, 1), F.ROAD],
	[Rect2i(97, 9, 1, 1), F.ROAD],
	[Rect2i(97, 10, 1, 1), F.ROAD],
	[Rect2i(97, 11, 1, 1), F.ROAD],
	[Rect2i(97, 12, 1, 1), F.ROAD],
	[Rect2i(97, 13, 1, 1), F.ROAD],
	[Rect2i(97, 14, 1, 1), F.ROAD],
	[Rect2i(97, 15, 1, 1), F.ROAD],
	[Rect2i(97, 16, 1, 1), F.ROAD],
	[Rect2i(97, 17, 1, 1), F.ROAD],
	[Rect2i(97, 18, 1, 1), F.ROAD],
	[Rect2i(97, 19, 1, 1), F.ROAD],
	[Rect2i(97, 20, 1, 1), F.ROAD],
	[Rect2i(97, 21, 1, 1), F.ROAD],
	[Rect2i(97, 22, 1, 1), F.ROAD],
	[Rect2i(97, 23, 1, 1), F.ROAD],
	[Rect2i(97, 24, 1, 1), F.ROAD],
	[Rect2i(97, 25, 1, 1), F.ROAD],
	[Rect2i(97, 26, 1, 1), F.ROAD],
	[Rect2i(97, 27, 1, 1), F.ROAD],
	[Rect2i(97, 28, 1, 1), F.ROAD],
	[Rect2i(97, 29, 1, 1), F.ROAD],
	[Rect2i(97, 30, 1, 1), F.ROAD],
	[Rect2i(97, 31, 1, 1), F.ROAD],
	[Rect2i(97, 32, 1, 1), F.ROAD],
	[Rect2i(97, 33, 1, 1), F.ROAD],
	[Rect2i(97, 34, 1, 1), F.ROAD],
	[Rect2i(97, 35, 1, 1), F.ROAD],
	[Rect2i(97, 36, 1, 1), F.ROAD],
	[Rect2i(97, 37, 1, 1), F.ROAD],
	[Rect2i(97, 38, 1, 1), F.ROAD],
	[Rect2i(97, 39, 1, 1), F.ROAD],
	[Rect2i(97, 40, 1, 1), F.ROAD],
	[Rect2i(97, 41, 1, 1), F.ROAD],
	[Rect2i(97, 42, 1, 1), F.ROAD],
	[Rect2i(97, 43, 1, 1), F.ROAD],
	[Rect2i(97, 44, 1, 1), F.ROAD],
	[Rect2i(97, 45, 1, 1), F.ROAD],
	[Rect2i(98, 0, 1, 1), F.ROAD],
	[Rect2i(98, 1, 1, 1), F.ROAD],
	[Rect2i(98, 2, 1, 1), F.ROAD],
	[Rect2i(98, 3, 1, 1), F.ROAD],
	[Rect2i(98, 4, 1, 1), F.ROAD],
	[Rect2i(98, 5, 1, 1), F.ROAD],
	[Rect2i(98, 6, 1, 1), F.ROAD],
	[Rect2i(98, 7, 1, 1), F.ROAD],
	[Rect2i(98, 8, 1, 1), F.ROAD],
	[Rect2i(98, 9, 1, 1), F.ROAD],
	[Rect2i(98, 10, 1, 1), F.ROAD],
	[Rect2i(98, 11, 1, 1), F.ROAD],
	[Rect2i(98, 12, 1, 1), F.ROAD],
	[Rect2i(98, 13, 1, 1), F.ROAD],
	[Rect2i(98, 14, 1, 1), F.ROAD],
	[Rect2i(98, 15, 1, 1), F.ROAD],
	[Rect2i(98, 16, 1, 1), F.ROAD],
	[Rect2i(98, 17, 1, 1), F.ROAD],
	[Rect2i(98, 18, 1, 1), F.ROAD],
	[Rect2i(98, 19, 1, 1), F.ROAD],
	[Rect2i(98, 20, 1, 1), F.ROAD],
	[Rect2i(98, 21, 1, 1), F.ROAD],
	[Rect2i(98, 22, 1, 1), F.ROAD],
	[Rect2i(98, 23, 1, 1), F.ROAD],
	[Rect2i(98, 24, 1, 1), F.ROAD],
	[Rect2i(98, 25, 1, 1), F.ROAD],
	[Rect2i(98, 26, 1, 1), F.ROAD],
	[Rect2i(98, 27, 1, 1), F.ROAD],
	[Rect2i(98, 28, 1, 1), F.ROAD],
	[Rect2i(98, 29, 1, 1), F.ROAD],
	[Rect2i(98, 30, 1, 1), F.ROAD],
	[Rect2i(98, 31, 1, 1), F.ROAD],
	[Rect2i(98, 32, 1, 1), F.ROAD],
	[Rect2i(98, 33, 1, 1), F.ROAD],
	[Rect2i(98, 34, 1, 1), F.ROAD],
	[Rect2i(98, 35, 1, 1), F.ROAD],
	[Rect2i(98, 36, 1, 1), F.ROAD],
	[Rect2i(98, 37, 1, 1), F.ROAD],
	[Rect2i(98, 38, 1, 1), F.ROAD],
	[Rect2i(98, 39, 1, 1), F.ROAD],
	[Rect2i(98, 40, 1, 1), F.ROAD],
	[Rect2i(98, 41, 1, 1), F.ROAD],
	[Rect2i(98, 42, 1, 1), F.ROAD],
	[Rect2i(98, 43, 1, 1), F.ROAD],
	[Rect2i(98, 44, 1, 1), F.ROAD],
	[Rect2i(98, 45, 1, 1), F.ROAD],
	[Rect2i(179, 42, 1, 1), F.ROAD],
	[Rect2i(179, 43, 1, 1), F.ROAD],
	[Rect2i(179, 44, 1, 1), F.ROAD],
	[Rect2i(179, 45, 1, 1), F.ROAD],
	[Rect2i(179, 46, 1, 1), F.ROAD],
	[Rect2i(179, 47, 1, 1), F.ROAD],
	[Rect2i(179, 48, 1, 1), F.ROAD],
	[Rect2i(179, 52, 1, 1), F.ROAD],
	[Rect2i(179, 53, 1, 1), F.ROAD],
	[Rect2i(178, 53, 1, 1), F.ROAD],
	[Rect2i(177, 53, 1, 1), F.ROAD],
	[Rect2i(176, 53, 1, 1), F.ROAD],
	[Rect2i(175, 53, 1, 1), F.ROAD],
	[Rect2i(174, 53, 1, 1), F.ROAD],
	[Rect2i(173, 53, 1, 1), F.ROAD],
	[Rect2i(172, 53, 1, 1), F.ROAD],
	[Rect2i(171, 53, 1, 1), F.ROAD],
	[Rect2i(170, 53, 1, 1), F.ROAD],
	[Rect2i(169, 53, 1, 1), F.ROAD],
	[Rect2i(168, 53, 1, 1), F.ROAD],
	[Rect2i(167, 53, 1, 1), F.ROAD],
	[Rect2i(166, 53, 1, 1), F.ROAD],
	[Rect2i(165, 53, 1, 1), F.ROAD],
	[Rect2i(164, 53, 1, 1), F.ROAD],
	[Rect2i(163, 53, 1, 1), F.ROAD],
	[Rect2i(162, 53, 1, 1), F.ROAD],
	[Rect2i(161, 53, 1, 1), F.ROAD],
	[Rect2i(179, 43, 1, 1), F.ROAD],
	[Rect2i(179, 44, 1, 1), F.ROAD],
	[Rect2i(179, 45, 1, 1), F.ROAD],
	[Rect2i(179, 46, 1, 1), F.ROAD],
	[Rect2i(179, 47, 1, 1), F.ROAD],
	[Rect2i(179, 48, 1, 1), F.ROAD],
	[Rect2i(179, 52, 1, 1), F.ROAD],
	[Rect2i(179, 53, 1, 1), F.ROAD],
	[Rect2i(178, 53, 1, 1), F.ROAD],
	[Rect2i(177, 53, 1, 1), F.ROAD],
	[Rect2i(176, 53, 1, 1), F.ROAD],
	[Rect2i(175, 53, 1, 1), F.ROAD],
	[Rect2i(174, 53, 1, 1), F.ROAD],
	[Rect2i(173, 53, 1, 1), F.ROAD],
	[Rect2i(172, 53, 1, 1), F.ROAD],
	[Rect2i(171, 53, 1, 1), F.ROAD],
	[Rect2i(170, 53, 1, 1), F.ROAD],
	[Rect2i(169, 53, 1, 1), F.ROAD],
	[Rect2i(168, 53, 1, 1), F.ROAD],
	[Rect2i(167, 53, 1, 1), F.ROAD],
	[Rect2i(166, 53, 1, 1), F.ROAD],
	[Rect2i(165, 53, 1, 1), F.ROAD],
	[Rect2i(164, 53, 1, 1), F.ROAD],
	[Rect2i(163, 53, 1, 1), F.ROAD],
	[Rect2i(162, 53, 1, 1), F.ROAD],
	[Rect2i(161, 53, 1, 1), F.ROAD],
	[Rect2i(112, 103, 1, 1), F.ROAD],
	[Rect2i(112, 102, 1, 1), F.ROAD],
	[Rect2i(112, 101, 1, 1), F.ROAD],
	[Rect2i(112, 100, 1, 1), F.ROAD],
	[Rect2i(112, 99, 1, 1), F.ROAD],
	[Rect2i(112, 98, 1, 1), F.ROAD],
	[Rect2i(112, 97, 1, 1), F.ROAD],
	[Rect2i(112, 96, 1, 1), F.ROAD],
	[Rect2i(112, 95, 1, 1), F.ROAD],
	[Rect2i(112, 94, 1, 1), F.ROAD],
	[Rect2i(112, 93, 1, 1), F.ROAD],
	[Rect2i(112, 92, 1, 1), F.ROAD],
	[Rect2i(112, 91, 1, 1), F.ROAD],
	[Rect2i(112, 90, 1, 1), F.ROAD],
	[Rect2i(112, 89, 1, 1), F.ROAD],
	[Rect2i(112, 88, 1, 1), F.ROAD],
	[Rect2i(112, 87, 1, 1), F.ROAD],
	[Rect2i(112, 86, 1, 1), F.ROAD],
	[Rect2i(112, 85, 1, 1), F.ROAD],
	[Rect2i(112, 84, 1, 1), F.ROAD],
	[Rect2i(112, 83, 1, 1), F.ROAD],
	[Rect2i(112, 82, 1, 1), F.ROAD],
	[Rect2i(112, 81, 1, 1), F.ROAD],
	[Rect2i(112, 80, 1, 1), F.ROAD],
	[Rect2i(112, 79, 1, 1), F.ROAD],
	[Rect2i(112, 78, 1, 1), F.ROAD],
	[Rect2i(112, 77, 1, 1), F.ROAD],
	[Rect2i(112, 76, 1, 1), F.ROAD],
	[Rect2i(112, 75, 1, 1), F.ROAD],
	[Rect2i(112, 74, 1, 1), F.ROAD],
	[Rect2i(111, 74, 1, 1), F.ROAD],
	[Rect2i(110, 74, 1, 1), F.ROAD],
	[Rect2i(110, 73, 1, 1), F.ROAD],
	[Rect2i(110, 72, 1, 1), F.ROAD],
	[Rect2i(110, 71, 1, 1), F.ROAD],
	[Rect2i(110, 70, 1, 1), F.ROAD],
	[Rect2i(110, 69, 1, 1), F.ROAD],
	[Rect2i(110, 68, 1, 1), F.ROAD],
	[Rect2i(110, 67, 1, 1), F.ROAD],
	[Rect2i(110, 66, 1, 1), F.ROAD],
	[Rect2i(110, 65, 1, 1), F.ROAD],
	[Rect2i(110, 64, 1, 1), F.ROAD],
	[Rect2i(110, 63, 1, 1), F.ROAD],
	[Rect2i(110, 62, 1, 1), F.ROAD],
	[Rect2i(110, 61, 1, 1), F.ROAD],
	[Rect2i(110, 60, 1, 1), F.ROAD],
	[Rect2i(110, 59, 1, 1), F.ROAD],
	[Rect2i(110, 58, 1, 1), F.ROAD],
	[Rect2i(110, 57, 1, 1), F.ROAD],
	[Rect2i(110, 56, 1, 1), F.ROAD],
	[Rect2i(110, 55, 1, 1), F.ROAD],
	[Rect2i(113, 103, 1, 1), F.ROAD],
	[Rect2i(113, 102, 1, 1), F.ROAD],
	[Rect2i(113, 101, 1, 1), F.ROAD],
	[Rect2i(113, 100, 1, 1), F.ROAD],
	[Rect2i(113, 99, 1, 1), F.ROAD],
	[Rect2i(113, 98, 1, 1), F.ROAD],
	[Rect2i(113, 97, 1, 1), F.ROAD],
	[Rect2i(113, 96, 1, 1), F.ROAD],
	[Rect2i(113, 95, 1, 1), F.ROAD],
	[Rect2i(113, 94, 1, 1), F.ROAD],
	[Rect2i(113, 93, 1, 1), F.ROAD],
	[Rect2i(113, 92, 1, 1), F.ROAD],
	[Rect2i(113, 91, 1, 1), F.ROAD],
	[Rect2i(113, 90, 1, 1), F.ROAD],
	[Rect2i(113, 89, 1, 1), F.ROAD],
	[Rect2i(113, 88, 1, 1), F.ROAD],
	[Rect2i(113, 87, 1, 1), F.ROAD],
	[Rect2i(113, 86, 1, 1), F.ROAD],
	[Rect2i(113, 85, 1, 1), F.ROAD],
	[Rect2i(113, 84, 1, 1), F.ROAD],
	[Rect2i(113, 83, 1, 1), F.ROAD],
	[Rect2i(113, 82, 1, 1), F.ROAD],
	[Rect2i(113, 81, 1, 1), F.ROAD],
	[Rect2i(113, 80, 1, 1), F.ROAD],
	[Rect2i(113, 79, 1, 1), F.ROAD],
	[Rect2i(113, 78, 1, 1), F.ROAD],
	[Rect2i(113, 77, 1, 1), F.ROAD],
	[Rect2i(113, 76, 1, 1), F.ROAD],
	[Rect2i(113, 75, 1, 1), F.ROAD],
	[Rect2i(113, 74, 1, 1), F.ROAD],
	[Rect2i(112, 74, 1, 1), F.ROAD],
	[Rect2i(111, 74, 1, 1), F.ROAD],
	[Rect2i(110, 74, 1, 1), F.ROAD],
	[Rect2i(110, 73, 1, 1), F.ROAD],
	[Rect2i(110, 72, 1, 1), F.ROAD],
	[Rect2i(110, 71, 1, 1), F.ROAD],
	[Rect2i(110, 70, 1, 1), F.ROAD],
	[Rect2i(110, 69, 1, 1), F.ROAD],
	[Rect2i(110, 68, 1, 1), F.ROAD],
	[Rect2i(110, 67, 1, 1), F.ROAD],
	[Rect2i(110, 66, 1, 1), F.ROAD],
	[Rect2i(110, 65, 1, 1), F.ROAD],
	[Rect2i(110, 64, 1, 1), F.ROAD],
	[Rect2i(110, 63, 1, 1), F.ROAD],
	[Rect2i(110, 62, 1, 1), F.ROAD],
	[Rect2i(110, 61, 1, 1), F.ROAD],
	[Rect2i(110, 60, 1, 1), F.ROAD],
	[Rect2i(110, 59, 1, 1), F.ROAD],
	[Rect2i(110, 58, 1, 1), F.ROAD],
	[Rect2i(110, 57, 1, 1), F.ROAD],
	[Rect2i(110, 56, 1, 1), F.ROAD],
	[Rect2i(110, 55, 1, 1), F.ROAD],
	[Rect2i(117, 61, 1, 1), F.ROAD],
	[Rect2i(117, 60, 1, 1), F.ROAD],
	[Rect2i(117, 59, 1, 1), F.ROAD],
	[Rect2i(117, 58, 1, 1), F.ROAD],
	[Rect2i(117, 57, 1, 1), F.ROAD],
	[Rect2i(117, 56, 1, 1), F.ROAD],
	[Rect2i(117, 55, 1, 1), F.ROAD],
	[Rect2i(134, 61, 1, 1), F.ROAD],
	[Rect2i(134, 60, 1, 1), F.ROAD],
	[Rect2i(134, 59, 1, 1), F.ROAD],
	[Rect2i(134, 58, 1, 1), F.ROAD],
	[Rect2i(134, 57, 1, 1), F.ROAD],
	[Rect2i(134, 56, 1, 1), F.ROAD],
	[Rect2i(134, 55, 1, 1), F.ROAD],
	[Rect2i(151, 61, 1, 1), F.ROAD],
	[Rect2i(151, 60, 1, 1), F.ROAD],
	[Rect2i(151, 59, 1, 1), F.ROAD],
	[Rect2i(151, 58, 1, 1), F.ROAD],
	[Rect2i(151, 57, 1, 1), F.ROAD],
	[Rect2i(151, 56, 1, 1), F.ROAD],
	[Rect2i(151, 55, 1, 1), F.ROAD],
	[Rect2i(138, 81, 1, 1), F.ROAD],
	[Rect2i(138, 80, 1, 1), F.ROAD],
	[Rect2i(138, 79, 1, 1), F.ROAD],
	[Rect2i(138, 78, 1, 1), F.ROAD],
	[Rect2i(138, 77, 1, 1), F.ROAD],
	[Rect2i(138, 76, 1, 1), F.ROAD],
	[Rect2i(138, 75, 1, 1), F.ROAD],
	[Rect2i(138, 74, 1, 1), F.ROAD],
	[Rect2i(137, 74, 1, 1), F.ROAD],
	[Rect2i(136, 74, 1, 1), F.ROAD],
	[Rect2i(135, 74, 1, 1), F.ROAD],
	[Rect2i(134, 74, 1, 1), F.ROAD],
	[Rect2i(133, 74, 1, 1), F.ROAD],
	[Rect2i(132, 74, 1, 1), F.ROAD],
	[Rect2i(131, 74, 1, 1), F.ROAD],
	[Rect2i(130, 74, 1, 1), F.ROAD],
	[Rect2i(129, 74, 1, 1), F.ROAD],
	[Rect2i(128, 74, 1, 1), F.ROAD],
	[Rect2i(127, 74, 1, 1), F.ROAD],
	[Rect2i(127, 73, 1, 1), F.ROAD],
	[Rect2i(127, 72, 1, 1), F.ROAD],
	[Rect2i(127, 71, 1, 1), F.ROAD],
	[Rect2i(127, 70, 1, 1), F.ROAD],
	[Rect2i(127, 69, 1, 1), F.ROAD],
	[Rect2i(127, 68, 1, 1), F.ROAD],
	[Rect2i(127, 67, 1, 1), F.ROAD],
	[Rect2i(127, 66, 1, 1), F.ROAD],
	[Rect2i(127, 65, 1, 1), F.ROAD],
	[Rect2i(127, 64, 1, 1), F.ROAD],
	[Rect2i(127, 63, 1, 1), F.ROAD],
	[Rect2i(127, 62, 1, 1), F.ROAD],
	[Rect2i(127, 61, 1, 1), F.ROAD],
	[Rect2i(127, 60, 1, 1), F.ROAD],
	[Rect2i(127, 59, 1, 1), F.ROAD],
	[Rect2i(127, 58, 1, 1), F.ROAD],
	[Rect2i(127, 57, 1, 1), F.ROAD],
	[Rect2i(127, 56, 1, 1), F.ROAD],
	[Rect2i(127, 55, 1, 1), F.ROAD],
	[Rect2i(78, 55, 1, 1), F.ROAD],
	[Rect2i(96, 3, 1, 1), F.GRAVEL],
	[Rect2i(96, 4, 1, 1), F.GRAVEL],
	[Rect2i(96, 5, 1, 1), F.GRAVEL],
	[Rect2i(96, 6, 1, 1), F.GRAVEL],
	[Rect2i(96, 7, 1, 1), F.GRAVEL],
	[Rect2i(96, 8, 1, 1), F.GRAVEL],
	[Rect2i(96, 9, 1, 1), F.GRAVEL],
	[Rect2i(96, 10, 1, 1), F.GRAVEL],
	[Rect2i(96, 11, 1, 1), F.GRAVEL],
	[Rect2i(96, 12, 1, 1), F.GRAVEL],
	[Rect2i(96, 13, 1, 1), F.GRAVEL],
	[Rect2i(96, 14, 1, 1), F.GRAVEL],
	[Rect2i(96, 15, 1, 1), F.GRAVEL],
	[Rect2i(96, 16, 1, 1), F.GRAVEL],
	[Rect2i(96, 17, 1, 1), F.GRAVEL],
	[Rect2i(96, 18, 1, 1), F.GRAVEL],
	[Rect2i(96, 19, 1, 1), F.GRAVEL],
	[Rect2i(96, 20, 1, 1), F.GRAVEL],
	[Rect2i(96, 21, 1, 1), F.GRAVEL],
	[Rect2i(96, 22, 1, 1), F.GRAVEL],
	[Rect2i(96, 23, 1, 1), F.GRAVEL],
	[Rect2i(96, 24, 1, 1), F.GRAVEL],
	[Rect2i(96, 25, 1, 1), F.GRAVEL],
	[Rect2i(96, 26, 1, 1), F.GRAVEL],
	[Rect2i(96, 27, 1, 1), F.GRAVEL],
	[Rect2i(96, 28, 1, 1), F.GRAVEL],
	[Rect2i(96, 29, 1, 1), F.GRAVEL],
	[Rect2i(96, 30, 1, 1), F.GRAVEL],
	[Rect2i(96, 31, 1, 1), F.GRAVEL],
	[Rect2i(96, 32, 1, 1), F.GRAVEL],
	[Rect2i(96, 33, 1, 1), F.GRAVEL],
	[Rect2i(96, 34, 1, 1), F.GRAVEL],
	[Rect2i(96, 35, 1, 1), F.GRAVEL],
	[Rect2i(96, 36, 1, 1), F.GRAVEL],
	[Rect2i(96, 37, 1, 1), F.GRAVEL],
	[Rect2i(96, 38, 1, 1), F.GRAVEL],
	[Rect2i(96, 39, 1, 1), F.GRAVEL],
	[Rect2i(96, 40, 1, 1), F.GRAVEL],
	[Rect2i(96, 41, 1, 1), F.GRAVEL],
	[Rect2i(96, 42, 1, 1), F.GRAVEL],
	[Rect2i(96, 43, 1, 1), F.GRAVEL],
	[Rect2i(96, 44, 1, 1), F.GRAVEL],
	[Rect2i(96, 45, 1, 1), F.GRAVEL],
	[Rect2i(50, 3, 1, 1), F.GRAVEL],
	[Rect2i(51, 3, 1, 1), F.GRAVEL],
	[Rect2i(52, 3, 1, 1), F.GRAVEL],
	[Rect2i(53, 3, 1, 1), F.GRAVEL],
	[Rect2i(54, 3, 1, 1), F.GRAVEL],
	[Rect2i(55, 3, 1, 1), F.GRAVEL],
	[Rect2i(56, 3, 1, 1), F.GRAVEL],
	[Rect2i(57, 3, 1, 1), F.GRAVEL],
	[Rect2i(58, 3, 1, 1), F.GRAVEL],
	[Rect2i(59, 3, 1, 1), F.GRAVEL],
	[Rect2i(60, 3, 1, 1), F.GRAVEL],
	[Rect2i(61, 3, 1, 1), F.GRAVEL],
	[Rect2i(62, 3, 1, 1), F.GRAVEL],
	[Rect2i(63, 3, 1, 1), F.GRAVEL],
	[Rect2i(64, 3, 1, 1), F.GRAVEL],
	[Rect2i(65, 3, 1, 1), F.GRAVEL],
	[Rect2i(66, 3, 1, 1), F.GRAVEL],
	[Rect2i(67, 3, 1, 1), F.GRAVEL],
	[Rect2i(68, 3, 1, 1), F.GRAVEL],
	[Rect2i(69, 3, 1, 1), F.GRAVEL],
	[Rect2i(70, 3, 1, 1), F.GRAVEL],
	[Rect2i(71, 3, 1, 1), F.GRAVEL],
	[Rect2i(72, 3, 1, 1), F.GRAVEL],
	[Rect2i(73, 3, 1, 1), F.GRAVEL],
	[Rect2i(74, 3, 1, 1), F.GRAVEL],
	[Rect2i(75, 3, 1, 1), F.GRAVEL],
	[Rect2i(76, 3, 1, 1), F.GRAVEL],
	[Rect2i(77, 3, 1, 1), F.GRAVEL],
	[Rect2i(78, 3, 1, 1), F.GRAVEL],
	[Rect2i(79, 3, 1, 1), F.GRAVEL],
	[Rect2i(80, 3, 1, 1), F.GRAVEL],
	[Rect2i(81, 3, 1, 1), F.GRAVEL],
	[Rect2i(82, 3, 1, 1), F.GRAVEL],
	[Rect2i(83, 3, 1, 1), F.GRAVEL],
	[Rect2i(84, 3, 1, 1), F.GRAVEL],
	[Rect2i(85, 3, 1, 1), F.GRAVEL],
	[Rect2i(86, 3, 1, 1), F.GRAVEL],
	[Rect2i(87, 3, 1, 1), F.GRAVEL],
	[Rect2i(88, 3, 1, 1), F.GRAVEL],
	[Rect2i(89, 3, 1, 1), F.GRAVEL],
	[Rect2i(90, 3, 1, 1), F.GRAVEL],
	[Rect2i(91, 3, 1, 1), F.GRAVEL],
	[Rect2i(92, 3, 1, 1), F.GRAVEL],
	[Rect2i(93, 3, 1, 1), F.GRAVEL],
	[Rect2i(94, 3, 1, 1), F.GRAVEL],
	[Rect2i(95, 3, 1, 1), F.GRAVEL],
	[Rect2i(51, 17, 1, 1), F.GRAVEL],
	[Rect2i(51, 16, 1, 1), F.GRAVEL],
	[Rect2i(50, 16, 1, 1), F.GRAVEL],
	[Rect2i(50, 15, 1, 1), F.GRAVEL],
	[Rect2i(50, 14, 1, 1), F.GRAVEL],
	[Rect2i(50, 13, 1, 1), F.GRAVEL],
	[Rect2i(50, 12, 1, 1), F.GRAVEL],
	[Rect2i(50, 11, 1, 1), F.GRAVEL],
	[Rect2i(49, 11, 1, 1), F.GRAVEL],
	[Rect2i(48, 11, 1, 1), F.GRAVEL],
	[Rect2i(48, 10, 1, 1), F.GRAVEL],
	[Rect2i(48, 9, 1, 1), F.GRAVEL],
	[Rect2i(48, 8, 1, 1), F.GRAVEL],
	[Rect2i(48, 7, 1, 1), F.GRAVEL],
	[Rect2i(48, 6, 1, 1), F.GRAVEL],
	[Rect2i(48, 5, 1, 1), F.GRAVEL],
	[Rect2i(48, 4, 1, 1), F.GRAVEL],
	[Rect2i(48, 3, 1, 1), F.GRAVEL],
	[Rect2i(49, 3, 1, 1), F.GRAVEL],
	[Rect2i(121, 11, 4, 2), F.DEEP_SNOW],
	[Rect2i(143, 26, 4, 2), F.DEEP_SNOW],
	[Rect2i(118, 26, 4, 2), F.DEEP_SNOW],
	[Rect2i(52, 61, 4, 3), F.GRAVEL],
	[Rect2i(41, 62, 4, 3), F.GRAVEL],
	[Rect2i(67, 78, 4, 3), F.GRAVEL],
	[Rect2i(17, 89, 4, 3), F.GRAVEL],
]

const BUILDING_ROWS: Array = [
	["어장 주택", Rect2i(111, 62, 14, 12)],
	["어장 주택", Rect2i(128, 62, 14, 12)],
	["어장 주택", Rect2i(145, 62, 14, 12)],
	["어장 큰 집", Rect2i(129, 82, 20, 17)],
	["보트 수리소", Rect2i(5, 5, 43, 28)],
	["얼음 낚시 움막", Rect2i(79, 78, 7, 7)],
]

const LEVEL_ROWS: Array = [
	[1, 4, Rect2i(5, 5, 43, 28)],
	[1, 3, Rect2i(129, 82, 20, 17)],
	[-1, 4, Rect2i(5, 5, 43, 28)],
]

const WALL_ROWS: Array = [
	[0, Rect2i(118, 63, 1, 10)],
	[0, Rect2i(135, 63, 1, 10)],
	[0, Rect2i(152, 63, 1, 10)],
	[0, Rect2i(139, 83, 1, 15)],
	[0, Rect2i(10, 9, 33, 1)],
	[0, Rect2i(10, 28, 33, 1)],
	[0, Rect2i(10, 10, 1, 18)],
	[0, Rect2i(42, 10, 1, 18)],
	[0, Rect2i(26, 10, 1, 18)],
	[0, Rect2i(11, 19, 15, 1)],
	[1, Rect2i(10, 9, 33, 1)],
	[1, Rect2i(10, 28, 33, 1)],
	[1, Rect2i(10, 10, 1, 18)],
	[1, Rect2i(42, 10, 1, 18)],
	[1, Rect2i(26, 10, 1, 18)],
	[1, Rect2i(11, 19, 15, 1)],
	[1, Rect2i(139, 83, 1, 15)],
	[-1, Rect2i(10, 9, 33, 1)],
	[-1, Rect2i(10, 28, 33, 1)],
	[-1, Rect2i(10, 10, 1, 18)],
	[-1, Rect2i(42, 10, 1, 18)],
	[-1, Rect2i(26, 10, 1, 18)],
	[-1, Rect2i(11, 19, 15, 1)],
]

const DOOR_ROWS: Array = [
	[0, Vector2i(118, 68), "closed", 0],
	[0, Vector2i(117, 62), "closed", 0],
	[0, Vector2i(135, 68), "closed", 1],
	[0, Vector2i(134, 62), "closed", 1],
	[0, Vector2i(152, 68), "closed", 2],
	[0, Vector2i(151, 62), "closed", 2],
	[0, Vector2i(139, 90), "closed", 3],
	[0, Vector2i(138, 82), "closed", 3],
	[0, Vector2i(10, 11), "closed", 4],
	[0, Vector2i(10, 26), "closed", 4],
	[0, Vector2i(42, 11), "closed", 4],
	[0, Vector2i(47, 19), "open", 4],
	[0, Vector2i(81, 84), "closed", 5],
	[1, Vector2i(10, 11), "closed", 4],
	[1, Vector2i(10, 26), "closed", 4],
	[1, Vector2i(42, 11), "closed", 4],
	[1, Vector2i(139, 90), "closed", 3],
	[-1, Vector2i(10, 11), "closed", 4],
	[-1, Vector2i(10, 26), "closed", 4],
	[-1, Vector2i(42, 11), "closed", 4],
]

const WINDOW_ROWS: Array = [
	[0, Vector2i(114, 62), 0],
	[0, Vector2i(121, 73), 0],
	[0, Vector2i(111, 65), 0],
	[0, Vector2i(124, 70), 0],
	[0, Vector2i(131, 62), 1],
	[0, Vector2i(138, 73), 1],
	[0, Vector2i(128, 65), 1],
	[0, Vector2i(141, 70), 1],
	[0, Vector2i(148, 62), 2],
	[0, Vector2i(155, 73), 2],
	[0, Vector2i(145, 65), 2],
	[0, Vector2i(158, 70), 2],
	[0, Vector2i(132, 82), 3],
	[0, Vector2i(145, 98), 3],
	[0, Vector2i(129, 85), 3],
	[0, Vector2i(148, 95), 3],
	[0, Vector2i(8, 5), 4],
	[0, Vector2i(44, 32), 4],
	[0, Vector2i(5, 8), 4],
	[0, Vector2i(47, 29), 4],
	[0, Vector2i(81, 78), 5],
	[1, Vector2i(8, 5), 4],
	[1, Vector2i(44, 32), 4],
	[1, Vector2i(5, 8), 4],
	[1, Vector2i(47, 29), 4],
	[1, Vector2i(132, 82), 3],
	[1, Vector2i(145, 98), 3],
	[1, Vector2i(129, 85), 3],
	[1, Vector2i(148, 95), 3],
]

const STAIR_ROWS: Array = [
	[Vector2i(7, 10), 0, 1],
	[Vector2i(131, 87), 0, 1],
	[Vector2i(7, 11), -1, 0],
]

const STOVE_ROWS: Array = [
	[Vector2i(80, 79), 5, 0],
]

const CONTAINER_ROWS: Array = [
	["supply_0", "식량 찬장", Vector2i(113, 65), 0, ["food_pack"], 0],
	["supply_1", "목재 선반", Vector2i(122, 71), 0, ["plank"], 0],
	["supply_2", "식량 찬장", Vector2i(130, 65), 1, ["food_pack"], 0],
	["supply_3", "목재 선반", Vector2i(139, 71), 1, ["plank"], 0],
	["supply_4", "식량 찬장", Vector2i(147, 65), 2, ["food_pack"], 0],
	["supply_5", "목재 선반", Vector2i(156, 71), 2, ["plank"], 0],
	["supply_6", "식량 찬장", Vector2i(131, 85), 3, ["food_pack"], 0],
	["supply_7", "목재 선반", Vector2i(146, 96), 3, ["plank"], 0],
	["supply_8", "저장 식량", Vector2i(12, 11), 4, ["food_pack","food_pack"], 0],
	["supply_9", "연료 저장함", Vector2i(12, 26), 4, ["wood","wood","wood"], 0],
	["supply_10", "깊은 부품 상자", Vector2i(28, 26), 4, ["scrap","scrap","food_pack","wood"], 0],
	["supply_11", "작업 통로 선반", Vector2i(7, 7), 4, ["plank"], 0],
	["supply_12", "움막 낚시 선반", Vector2i(83, 82), 5, ["food_pack"], 0],
	["supply_13", "저장 식량", Vector2i(12, 11), 4, ["food_pack","food_pack"], 1],
	["supply_14", "연료 저장함", Vector2i(12, 26), 4, ["wood","wood","wood"], 1],
	["supply_15", "깊은 부품 상자", Vector2i(28, 26), 4, ["scrap","scrap","food_pack","wood"], 1],
	["supply_16", "작업 통로 선반", Vector2i(7, 7), 4, ["plank"], 1],
	["supply_17", "식량 찬장", Vector2i(131, 85), 3, ["food_pack"], 1],
	["supply_18", "위층 작업 선반", Vector2i(146, 96), 3, ["plank"], 1],
	["supply_19", "저장 식량", Vector2i(12, 11), 4, ["food_pack","food_pack"], -1],
	["supply_20", "연료 저장함", Vector2i(12, 26), 4, ["wood","wood","wood"], -1],
	["supply_21", "깊은 부품 상자", Vector2i(28, 26), 4, ["scrap","scrap","food_pack","wood"], -1],
	["supply_22", "작업 통로 선반", Vector2i(7, 7), 4, ["plank"], -1],
	["pier_wood", "잔교 목재 상자", Vector2i(77, 21), -1, ["plank","wood"], 0],
]

const SALVAGE_ROWS: Array = [
	["pier_repair", "잔교 수선 목재", Vector2i(48, 19), "wood", 2],
]

const ZONE_ROWS: Array = [
	["A", Rect2i(0, 0, 91, 104), Vector2i(61, 57)],
	["B", Rect2i(91, 0, 89, 104), Vector2i(113, 64)],
	["C", Rect2i(55, 9, 24, 14), Vector2i(57, 11)],
	["D", Rect2i(5, 5, 43, 28), Vector2i(7, 7)],
]

const ENTRY_CELLS: Dictionary = {
	"shore_west": [Vector2i(97, 0), Vector2i(98, 0)],
	"shore_east": [Vector2i(179, 42), Vector2i(179, 43)],
	"village_back": [Vector2i(112, 103), Vector2i(113, 103)],
}

const ENTRY_GAP: Dictionary = {"shore_west":0.6,"shore_east":0.6,"village_back":2.5}

const BARRICADE_CELLS: Array[Vector2i] = [
	Vector2i(125, 67),
	Vector2i(126, 67),
	Vector2i(127, 67),
	Vector2i(142, 67),
	Vector2i(143, 67),
	Vector2i(144, 67),
]

const PROPS: Array = [
	{"kind": "overturned_boat", "rect": Rect2i(88, 57, 4, 2), "solid": "low", "facing": 0, "note": "하역 마당 엄폐 · 뒤집힌 배"},
	{"kind": "net_drying_rack", "rect": Rect2i(106, 55, 1, 4), "solid": "low", "facing": 1, "note": "하역 마당 엄폐 · 그물 건조대"},
	{"kind": "fish_trap_stack", "rect": Rect2i(124, 58, 2, 3), "solid": "low", "facing": 1, "note": "하역 마당 엄폐 · 통발 쌓음"},
	{"kind": "firewood_stack", "rect": Rect2i(146, 57, 3, 2), "solid": "low", "facing": 0, "note": "하역 마당 엄폐 · 장작 단"},
	{"kind": "pier_deck", "rect": Rect2i(47, 18, 1, 3), "solid": "none", "facing": 1, "note": "잔교 통로 구간 · 잔교"},
	{"kind": "pier_deck", "rect": Rect2i(52, 18, 41, 3), "solid": "none", "facing": 0, "note": "잔교 통로 구간 · 잔교"},
	{"kind": "fishing_platform", "rect": Rect2i(55, 9, 24, 14), "solid": "none", "facing": 0, "note": "어장 작업 무리 · 어장 작업대"},
	{"kind": "sunken_wheelhouse", "rect": Rect2i(6, 39, 4, 3), "solid": "wall", "facing": 0, "note": "가라앉은 배 1 · 조타실 윗부분"},
	{"kind": "sunken_bow", "rect": Rect2i(14, 40, 2, 4), "solid": "wall", "facing": 1, "note": "가라앉은 배 1 · 솟은 뱃머리"},
	{"kind": "sunken_deck_section", "rect": Rect2i(7, 45, 8, 3), "solid": "low", "facing": 0, "note": "가라앉은 배 1 · 드러난 갑판 조각"},
	{"kind": "fallen_mast", "rect": Rect2i(12, 49, 7, 1), "solid": "low", "facing": 0, "note": "가라앉은 배 1 · 쓰러진 돛대"},
	{"kind": "sunken_wheelhouse", "rect": Rect2i(23, 42, 4, 3), "solid": "wall", "facing": 0, "note": "가라앉은 배 2 · 조타실 윗부분"},
	{"kind": "sunken_bow", "rect": Rect2i(31, 43, 2, 4), "solid": "wall", "facing": 1, "note": "가라앉은 배 2 · 솟은 뱃머리"},
	{"kind": "sunken_deck_section", "rect": Rect2i(24, 48, 8, 3), "solid": "low", "facing": 0, "note": "가라앉은 배 2 · 드러난 갑판 조각"},
	{"kind": "sunken_wheelhouse", "rect": Rect2i(41, 38, 4, 3), "solid": "wall", "facing": 0, "note": "가라앉은 배 3 · 조타실 윗부분"},
	{"kind": "sunken_bow", "rect": Rect2i(49, 39, 2, 4), "solid": "wall", "facing": 1, "note": "가라앉은 배 3 · 솟은 뱃머리"},
	{"kind": "sunken_deck_section", "rect": Rect2i(42, 44, 8, 3), "solid": "low", "facing": 0, "note": "가라앉은 배 3 · 드러난 갑판 조각"},
	{"kind": "fallen_mast", "rect": Rect2i(47, 48, 7, 1), "solid": "low", "facing": 0, "note": "가라앉은 배 3 · 쓰러진 돛대"},
	{"kind": "sunken_wheelhouse", "rect": Rect2i(61, 24, 4, 3), "solid": "wall", "facing": 0, "note": "가라앉은 배 4 · 조타실 윗부분"},
	{"kind": "sunken_bow", "rect": Rect2i(67, 23, 2, 4), "solid": "wall", "facing": 1, "note": "가라앉은 배 4 · 솟은 뱃머리"},
	{"kind": "sunken_wheelhouse", "rect": Rect2i(10, 65, 4, 3), "solid": "wall", "facing": 0, "note": "가라앉은 배 5 · 조타실 윗부분"},
	{"kind": "sunken_bow", "rect": Rect2i(18, 66, 2, 4), "solid": "wall", "facing": 1, "note": "가라앉은 배 5 · 솟은 뱃머리"},
	{"kind": "sunken_deck_section", "rect": Rect2i(11, 71, 8, 3), "solid": "low", "facing": 0, "note": "가라앉은 배 5 · 드러난 갑판 조각"},
	{"kind": "fallen_mast", "rect": Rect2i(16, 75, 7, 1), "solid": "low", "facing": 0, "note": "가라앉은 배 5 · 쓰러진 돛대"},
	{"kind": "sunken_wheelhouse", "rect": Rect2i(32, 78, 4, 3), "solid": "wall", "facing": 0, "note": "가라앉은 배 6 · 조타실 윗부분"},
	{"kind": "sunken_bow", "rect": Rect2i(40, 79, 2, 4), "solid": "wall", "facing": 1, "note": "가라앉은 배 6 · 솟은 뱃머리"},
	{"kind": "sunken_deck_section", "rect": Rect2i(33, 84, 8, 3), "solid": "low", "facing": 0, "note": "가라앉은 배 6 · 드러난 갑판 조각"},
	{"kind": "sunken_wheelhouse", "rect": Rect2i(59, 85, 4, 3), "solid": "wall", "facing": 0, "note": "가라앉은 배 7 · 조타실 윗부분"},
	{"kind": "sunken_bow", "rect": Rect2i(67, 86, 2, 4), "solid": "wall", "facing": 1, "note": "가라앉은 배 7 · 솟은 뱃머리"},
	{"kind": "sunken_deck_section", "rect": Rect2i(60, 91, 8, 3), "solid": "low", "facing": 0, "note": "가라앉은 배 7 · 드러난 갑판 조각"},
	{"kind": "fallen_mast", "rect": Rect2i(65, 95, 7, 1), "solid": "low", "facing": 0, "note": "가라앉은 배 7 · 쓰러진 돛대"},
	{"kind": "fish_hoist", "rect": Rect2i(56, 10, 3, 3), "solid": "wall", "facing": 0, "note": "작업대 1 · 어망 윈치 틀"},
	{"kind": "cleaning_table", "rect": Rect2i(62, 11, 4, 2), "solid": "low", "facing": 0, "note": "작업대 1 · 손질대"},
	{"kind": "fish_crate_stack", "rect": Rect2i(67, 13, 2, 2), "solid": "low", "facing": 0, "note": "작업대 1 · 생선 상자 더미"},
	{"kind": "net_pile", "rect": Rect2i(58, 16, 2, 2), "solid": "low", "facing": 0, "note": "작업대 1 · 그물 더미"},
	{"kind": "ice_saw_frame", "rect": Rect2i(74, 20, 3, 2), "solid": "low", "facing": 0, "note": "작업대 1 · 얼음 톱 틀"},
	{"kind": "ice_cut_pool", "rect": Rect2i(50, 14, 4, 3), "solid": "none", "facing": 0, "note": "작업대 1 · 잘라 낸 얼음 자리"},
	{"kind": "net_pile", "rect": Rect2i(119, 75, 2, 2), "solid": "low", "facing": 0, "note": "주택 마당 1 · 그물 더미"},
	{"kind": "dry_bush", "rect": Rect2i(112, 76, 2, 2), "solid": "none", "facing": 0, "note": "주택 마당 1 · 마른 덤불"},
	{"kind": "buoy_line", "rect": Rect2i(143, 66, 2, 1), "solid": "none", "facing": 0, "note": "주택 마당 2 · 부표 줄"},
	{"kind": "snow_drift", "rect": Rect2i(129, 76, 4, 2), "solid": "none", "facing": 0, "note": "주택 마당 2 · 눈더미"},
	{"kind": "net_pile", "rect": Rect2i(153, 75, 2, 2), "solid": "low", "facing": 0, "note": "주택 마당 3 · 그물 더미"},
	{"kind": "dry_bush", "rect": Rect2i(146, 76, 2, 2), "solid": "none", "facing": 0, "note": "주택 마당 3 · 마른 덤불"},
	{"kind": "overturned_boat", "rect": Rect2i(124, 84, 4, 2), "solid": "low", "facing": 0, "note": "주택 마당 4 · 뒤집힌 배"},
	{"kind": "net_drying_rack", "rect": Rect2i(132, 78, 4, 1), "solid": "low", "facing": 0, "note": "주택 마당 4 · 그물 건조대"},
	{"kind": "buoy_line", "rect": Rect2i(151, 87, 2, 1), "solid": "none", "facing": 0, "note": "주택 마당 4 · 부표 줄"},
	{"kind": "snow_drift", "rect": Rect2i(130, 101, 4, 2), "solid": "none", "facing": 0, "note": "주택 마당 4 · 눈더미"},
	{"kind": "frozen_reeds", "rect": Rect2i(89, 8, 3, 3), "solid": "none", "facing": 0, "note": "물가 무리 1 · 얼어붙은 갈대"},
	{"kind": "shore_ice_heap", "rect": Rect2i(84, 11, 3, 2), "solid": "low", "facing": 0, "note": "물가 무리 1 · 물가 얼음 무더기"},
	{"kind": "fishing_hole", "rect": Rect2i(81, 13, 1, 1), "solid": "none", "facing": 0, "note": "물가 무리 1 · 낚시 구멍"},
	{"kind": "frozen_reeds", "rect": Rect2i(89, 21, 3, 3), "solid": "none", "facing": 0, "note": "물가 무리 2 · 얼어붙은 갈대"},
	{"kind": "shore_ice_heap", "rect": Rect2i(84, 24, 3, 2), "solid": "low", "facing": 0, "note": "물가 무리 2 · 물가 얼음 무더기"},
	{"kind": "fishing_hole", "rect": Rect2i(81, 26, 1, 1), "solid": "none", "facing": 0, "note": "물가 무리 2 · 낚시 구멍"},
	{"kind": "frozen_reeds", "rect": Rect2i(89, 34, 3, 3), "solid": "none", "facing": 0, "note": "물가 무리 3 · 얼어붙은 갈대"},
	{"kind": "fishing_hole", "rect": Rect2i(81, 39, 1, 1), "solid": "none", "facing": 0, "note": "물가 무리 3 · 낚시 구멍"},
	{"kind": "fishing_hole", "rect": Rect2i(78, 55, 1, 1), "solid": "none", "facing": 0, "note": "물가 무리 4 · 낚시 구멍"},
	{"kind": "frozen_reeds", "rect": Rect2i(89, 60, 3, 3), "solid": "none", "facing": 0, "note": "물가 무리 5 · 얼어붙은 갈대"},
	{"kind": "fishing_hole", "rect": Rect2i(81, 65, 1, 1), "solid": "none", "facing": 0, "note": "물가 무리 5 · 낚시 구멍"},
	{"kind": "frozen_reeds", "rect": Rect2i(89, 73, 3, 3), "solid": "none", "facing": 0, "note": "물가 무리 6 · 얼어붙은 갈대"},
	{"kind": "shore_ice_heap", "rect": Rect2i(83, 75, 3, 2), "solid": "low", "facing": 0, "note": "물가 무리 6 · 물가 얼음 무더기"},
	{"kind": "fishing_hole", "rect": Rect2i(80, 77, 1, 1), "solid": "none", "facing": 0, "note": "물가 무리 6 · 낚시 구멍"},
	{"kind": "frozen_reeds", "rect": Rect2i(89, 86, 3, 3), "solid": "none", "facing": 0, "note": "물가 무리 7 · 얼어붙은 갈대"},
	{"kind": "shore_ice_heap", "rect": Rect2i(84, 89, 3, 2), "solid": "low", "facing": 0, "note": "물가 무리 7 · 물가 얼음 무더기"},
	{"kind": "fishing_hole", "rect": Rect2i(81, 91, 1, 1), "solid": "none", "facing": 0, "note": "물가 무리 7 · 낚시 구멍"},
	{"kind": "tool_bench", "rect": Rect2i(75, 80, 3, 1), "solid": "low", "facing": 0, "note": "움막 1 · 연장 작업대"},
	{"kind": "firewood_stack", "rect": Rect2i(88, 79, 3, 2), "solid": "low", "facing": 0, "note": "움막 1 · 장작 단"},
	{"kind": "fishing_hole", "rect": Rect2i(77, 86, 1, 1), "solid": "none", "facing": 0, "note": "움막 1 · 낚시 구멍"},
	{"kind": "tip_up_flag", "rect": Rect2i(78, 86, 1, 1), "solid": "none", "facing": 0, "note": "움막 1 · 낚시 깃대"},
	{"kind": "fishing_hole", "rect": Rect2i(80, 88, 1, 1), "solid": "none", "facing": 0, "note": "움막 1 · 낚시 구멍"},
	{"kind": "tip_up_flag", "rect": Rect2i(81, 88, 1, 1), "solid": "none", "facing": 0, "note": "움막 1 · 낚시 깃대"},
	{"kind": "fishing_hole", "rect": Rect2i(84, 87, 1, 1), "solid": "none", "facing": 0, "note": "움막 1 · 낚시 구멍"},
	{"kind": "tip_up_flag", "rect": Rect2i(85, 87, 1, 1), "solid": "none", "facing": 0, "note": "움막 1 · 낚시 깃대"},
	{"kind": "fish_truck", "rect": Rect2i(49, 8, 6, 3), "solid": "wall", "facing": 0, "note": "창고 앞뜰 · 생선 운반 트럭"},
	{"kind": "boat_on_blocks", "rect": Rect2i(8, 1, 5, 2), "solid": "low", "facing": 0, "note": "창고 앞뜰 · 받침대에 얹힌 배"},
	{"kind": "tool_bench", "rect": Rect2i(17, 1, 3, 1), "solid": "low", "facing": 0, "note": "창고 앞뜰 · 연장 작업대"},
	{"kind": "pallet_stack", "rect": Rect2i(42, 1, 2, 2), "solid": "low", "facing": 0, "note": "창고 앞뜰 · 상자 팔레트"},
	{"kind": "ice_block_stack", "rect": Rect2i(1, 10, 3, 2), "solid": "low", "facing": 0, "note": "창고 앞뜰 · 얼음 덩이 쌓음"},
	{"kind": "ice_sled_load", "rect": Rect2i(1, 17, 3, 1), "solid": "low", "facing": 0, "note": "창고 앞뜰 · 짐 실은 썰매"},
	{"kind": "fuel_tank", "rect": Rect2i(49, 4, 3, 3), "solid": "wall", "facing": 0, "note": "설비 뒤편 · 연료 탱크"},
	{"kind": "generator_unit", "rect": Rect2i(51, 14, 2, 2), "solid": "low", "facing": 0, "note": "설비 뒤편 · 발전기"},
	{"kind": "fuel_drum_group", "rect": Rect2i(55, 16, 2, 2), "solid": "low", "facing": 0, "note": "설비 뒤편 · 연료 드럼"},
	{"kind": "rubbish_pile", "rect": Rect2i(2, 7, 2, 1), "solid": "none", "facing": 0, "note": "설비 뒤편 · 쏟아진 쓰레기"},
	{"kind": "bare_willow", "rect": Rect2i(100, 3, 1, 1), "solid": "tree", "facing": 0, "note": "버드나무 무리 1 · 마른 버드나무"},
	{"kind": "bare_willow", "rect": Rect2i(102, 4, 1, 1), "solid": "tree", "facing": 0, "note": "버드나무 무리 1 · 마른 버드나무"},
	{"kind": "bare_willow", "rect": Rect2i(99, 6, 1, 1), "solid": "tree", "facing": 0, "note": "버드나무 무리 1 · 마른 버드나무"},
	{"kind": "bare_willow", "rect": Rect2i(103, 7, 1, 1), "solid": "tree", "facing": 0, "note": "버드나무 무리 1 · 마른 버드나무"},
	{"kind": "bare_willow", "rect": Rect2i(101, 9, 1, 1), "solid": "tree", "facing": 0, "note": "버드나무 무리 1 · 마른 버드나무"},
	{"kind": "bare_willow", "rect": Rect2i(151, 5, 1, 1), "solid": "tree", "facing": 0, "note": "버드나무 무리 2 · 마른 버드나무"},
	{"kind": "bare_willow", "rect": Rect2i(153, 6, 1, 1), "solid": "tree", "facing": 0, "note": "버드나무 무리 2 · 마른 버드나무"},
	{"kind": "bare_willow", "rect": Rect2i(150, 8, 1, 1), "solid": "tree", "facing": 0, "note": "버드나무 무리 2 · 마른 버드나무"},
	{"kind": "bare_willow", "rect": Rect2i(154, 9, 1, 1), "solid": "tree", "facing": 0, "note": "버드나무 무리 2 · 마른 버드나무"},
	{"kind": "bare_willow", "rect": Rect2i(152, 11, 1, 1), "solid": "tree", "facing": 0, "note": "버드나무 무리 2 · 마른 버드나무"},
	{"kind": "bare_willow", "rect": Rect2i(161, 20, 1, 1), "solid": "tree", "facing": 0, "note": "버드나무 무리 3 · 마른 버드나무"},
	{"kind": "bare_willow", "rect": Rect2i(163, 21, 1, 1), "solid": "tree", "facing": 0, "note": "버드나무 무리 3 · 마른 버드나무"},
	{"kind": "bare_willow", "rect": Rect2i(160, 23, 1, 1), "solid": "tree", "facing": 0, "note": "버드나무 무리 3 · 마른 버드나무"},
	{"kind": "bare_willow", "rect": Rect2i(164, 24, 1, 1), "solid": "tree", "facing": 0, "note": "버드나무 무리 3 · 마른 버드나무"},
	{"kind": "bare_willow", "rect": Rect2i(162, 26, 1, 1), "solid": "tree", "facing": 0, "note": "버드나무 무리 3 · 마른 버드나무"},
	{"kind": "bare_willow", "rect": Rect2i(101, 83, 1, 1), "solid": "tree", "facing": 0, "note": "버드나무 무리 4 · 마른 버드나무"},
	{"kind": "bare_willow", "rect": Rect2i(103, 84, 1, 1), "solid": "tree", "facing": 0, "note": "버드나무 무리 4 · 마른 버드나무"},
	{"kind": "bare_willow", "rect": Rect2i(100, 86, 1, 1), "solid": "tree", "facing": 0, "note": "버드나무 무리 4 · 마른 버드나무"},
	{"kind": "bare_willow", "rect": Rect2i(104, 87, 1, 1), "solid": "tree", "facing": 0, "note": "버드나무 무리 4 · 마른 버드나무"},
	{"kind": "bare_willow", "rect": Rect2i(102, 89, 1, 1), "solid": "tree", "facing": 0, "note": "버드나무 무리 4 · 마른 버드나무"},
	{"kind": "bare_willow", "rect": Rect2i(165, 83, 1, 1), "solid": "tree", "facing": 0, "note": "버드나무 무리 5 · 마른 버드나무"},
	{"kind": "bare_willow", "rect": Rect2i(167, 84, 1, 1), "solid": "tree", "facing": 0, "note": "버드나무 무리 5 · 마른 버드나무"},
	{"kind": "bare_willow", "rect": Rect2i(164, 86, 1, 1), "solid": "tree", "facing": 0, "note": "버드나무 무리 5 · 마른 버드나무"},
	{"kind": "bare_willow", "rect": Rect2i(168, 87, 1, 1), "solid": "tree", "facing": 0, "note": "버드나무 무리 5 · 마른 버드나무"},
	{"kind": "bare_willow", "rect": Rect2i(166, 89, 1, 1), "solid": "tree", "facing": 0, "note": "버드나무 무리 5 · 마른 버드나무"},
	{"kind": "snow_drift", "rect": Rect2i(121, 11, 4, 2), "solid": "none", "facing": 0, "note": "길가 눈 쌓임 · 눈더미"},
	{"kind": "snow_drift", "rect": Rect2i(143, 26, 4, 2), "solid": "none", "facing": 0, "note": "길가 눈 쌓임 · 눈더미"},
	{"kind": "snow_drift", "rect": Rect2i(118, 26, 4, 2), "solid": "none", "facing": 0, "note": "길가 눈 쌓임 · 눈더미"},
	{"kind": "ice_cut_pool", "rect": Rect2i(52, 61, 4, 3), "solid": "none", "facing": 0, "note": "얼음 채취 흔적 · 잘라 낸 얼음 자리"},
	{"kind": "ice_cut_pool", "rect": Rect2i(41, 62, 4, 3), "solid": "none", "facing": 0, "note": "얼음 채취 흔적 · 잘라 낸 얼음 자리"},
	{"kind": "ice_cut_pool", "rect": Rect2i(67, 78, 4, 3), "solid": "none", "facing": 0, "note": "얼음 채취 흔적 · 잘라 낸 얼음 자리"},
	{"kind": "ice_cut_pool", "rect": Rect2i(17, 89, 4, 3), "solid": "none", "facing": 0, "note": "얼음 채취 흔적 · 잘라 낸 얼음 자리"},
	{"kind": "buoy_line", "rect": Rect2i(76, 21, 2, 1), "solid": "none", "facing": 0, "note": "잔교 물자 표시 · 부표 줄"},
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
