# 이 지도가 다른 판단을 만드는 것: 얼음 위 가공동까지 두 잔교의 좁은 목을 지킬지, 배 뒤의 얼음 길로 크게 돌아갈지 고른다.
extends RefCounted
## 셋째 판. 1칸은 1m. 물가의 연속된 얼음은 걸을 수 있으며 지도 끝이 깊은 물이다.
## 지하와 위층은 같은 칸의 계단으로 잇고, 깊은 창고는 순환 통로와 세 저장 주머니로 나눈다.

const FieldGrid = preload("res://game/world/field_grid.gd")
const S = FieldGrid.Solid
const F = FieldGrid.Floor

const WIDTH: int = 170

const HEIGHT: int = 104

const PLACE_ID: String = "lake_07"

const LAKE_SIDE: String = "upper"

const TRAIN: Rect2i = Rect2i(44, 52, 80, 3)

const BANDS: Dictionary = {"upper": Rect2i(24, 30, 120, 22), "lower": Rect2i(24, 55, 120, 23)}

const ZONE_NAMES: Dictionary = {"A":"얼음 어장","B":"어장 마을","C":"얼음 위 작업대","D":"어장 가공동","":"바깥"}
## 무전 문장에 쓰는 들어오는 길의 이름, 길마다의 비중, 첫 물결이 오는 길.
const ENTRY_NAMES: Dictionary = {"shore_west": "서쪽 호숫가", "shore_east": "동쪽 호숫가", "village_back": "마을 뒤쪽"}
const ENTRY_WEIGHTS: Dictionary = {"shore_west": 0.4, "shore_east": 0.4, "village_back": 0.2}
const FIRST_ENTRY: String = "shore_west"

const FLOOR_PATCHES: Array = [
	[Rect2i(0, 0, 170, 50), F.ICE],
	[Rect2i(0, 52, 170, 3), F.RAIL],
	[Rect2i(41, 49, 86, 3), F.PLATFORM],
	[Rect2i(41, 55, 86, 3), F.PLATFORM],
	[Rect2i(71, 20, 3, 32), F.WOOD],
	[Rect2i(118, 30, 3, 22), F.WOOD],
	[Rect2i(90, 18, 10, 3), F.WOOD],
	[Rect2i(97, 18, 3, 15), F.WOOD],
	[Rect2i(97, 30, 28, 3), F.WOOD],
	[Rect2i(65, 8, 28, 14), F.PLATFORM],
	[Rect2i(60, 13, 4, 3), F.GRAVEL],
	[Rect2i(58, 82, 4, 2), F.DEEP_SNOW],
	[Rect2i(14, 44, 1, 1), F.GRAVEL],
	[Rect2i(35, 44, 1, 1), F.GRAVEL],
	[Rect2i(56, 44, 1, 1), F.GRAVEL],
	[Rect2i(79, 46, 1, 1), F.GRAVEL],
	[Rect2i(98, 44, 1, 1), F.GRAVEL],
	[Rect2i(119, 44, 1, 1), F.GRAVEL],
	[Rect2i(140, 44, 1, 1), F.GRAVEL],
	[Rect2i(147, 32, 1, 1), F.GRAVEL],
	[Rect2i(150, 34, 1, 1), F.GRAVEL],
	[Rect2i(154, 33, 1, 1), F.GRAVEL],
	[Rect2i(62, 47, 1, 1), F.GRAVEL],
	[Rect2i(63, 47, 1, 1), F.GRAVEL],
	[Rect2i(69, 48, 1, 1), F.GRAVEL],
	[Rect2i(72, 47, 1, 1), F.GRAVEL],
	[Rect2i(73, 47, 1, 1), F.GRAVEL],
	[Rect2i(79, 48, 1, 1), F.GRAVEL],
	[Rect2i(109, 47, 1, 1), F.GRAVEL],
	[Rect2i(110, 47, 1, 1), F.GRAVEL],
	[Rect2i(116, 48, 1, 1), F.GRAVEL],
	[Rect2i(119, 47, 1, 1), F.GRAVEL],
	[Rect2i(120, 47, 1, 1), F.GRAVEL],
	[Rect2i(126, 48, 1, 1), F.GRAVEL],
	[Rect2i(0, 63, 1, 1), F.ROAD],
	[Rect2i(0, 62, 1, 1), F.ROAD],
	[Rect2i(0, 61, 1, 1), F.ROAD],
	[Rect2i(0, 60, 1, 1), F.ROAD],
	[Rect2i(0, 59, 1, 1), F.ROAD],
	[Rect2i(0, 58, 1, 1), F.ROAD],
	[Rect2i(0, 57, 1, 1), F.ROAD],
	[Rect2i(0, 56, 1, 1), F.ROAD],
	[Rect2i(1, 56, 1, 1), F.ROAD],
	[Rect2i(2, 56, 1, 1), F.ROAD],
	[Rect2i(3, 56, 1, 1), F.ROAD],
	[Rect2i(4, 56, 1, 1), F.ROAD],
	[Rect2i(5, 56, 1, 1), F.ROAD],
	[Rect2i(6, 56, 1, 1), F.ROAD],
	[Rect2i(7, 56, 1, 1), F.ROAD],
	[Rect2i(8, 56, 1, 1), F.ROAD],
	[Rect2i(9, 56, 1, 1), F.ROAD],
	[Rect2i(10, 56, 1, 1), F.ROAD],
	[Rect2i(11, 56, 1, 1), F.ROAD],
	[Rect2i(12, 56, 1, 1), F.ROAD],
	[Rect2i(13, 56, 1, 1), F.ROAD],
	[Rect2i(14, 56, 1, 1), F.ROAD],
	[Rect2i(15, 56, 1, 1), F.ROAD],
	[Rect2i(16, 56, 1, 1), F.ROAD],
	[Rect2i(17, 56, 1, 1), F.ROAD],
	[Rect2i(18, 56, 1, 1), F.ROAD],
	[Rect2i(19, 56, 1, 1), F.ROAD],
	[Rect2i(20, 56, 1, 1), F.ROAD],
	[Rect2i(21, 56, 1, 1), F.ROAD],
	[Rect2i(22, 56, 1, 1), F.ROAD],
	[Rect2i(23, 56, 1, 1), F.ROAD],
	[Rect2i(24, 56, 1, 1), F.ROAD],
	[Rect2i(25, 56, 1, 1), F.ROAD],
	[Rect2i(26, 56, 1, 1), F.ROAD],
	[Rect2i(27, 56, 1, 1), F.ROAD],
	[Rect2i(28, 56, 1, 1), F.ROAD],
	[Rect2i(29, 56, 1, 1), F.ROAD],
	[Rect2i(30, 56, 1, 1), F.ROAD],
	[Rect2i(31, 56, 1, 1), F.ROAD],
	[Rect2i(32, 56, 1, 1), F.ROAD],
	[Rect2i(33, 56, 1, 1), F.ROAD],
	[Rect2i(34, 56, 1, 1), F.ROAD],
	[Rect2i(35, 56, 1, 1), F.ROAD],
	[Rect2i(36, 56, 1, 1), F.ROAD],
	[Rect2i(37, 56, 1, 1), F.ROAD],
	[Rect2i(38, 56, 1, 1), F.ROAD],
	[Rect2i(39, 56, 1, 1), F.ROAD],
	[Rect2i(40, 56, 1, 1), F.ROAD],
	[Rect2i(0, 64, 1, 1), F.ROAD],
	[Rect2i(0, 63, 1, 1), F.ROAD],
	[Rect2i(0, 62, 1, 1), F.ROAD],
	[Rect2i(0, 61, 1, 1), F.ROAD],
	[Rect2i(0, 60, 1, 1), F.ROAD],
	[Rect2i(0, 59, 1, 1), F.ROAD],
	[Rect2i(0, 58, 1, 1), F.ROAD],
	[Rect2i(0, 57, 1, 1), F.ROAD],
	[Rect2i(0, 56, 1, 1), F.ROAD],
	[Rect2i(1, 56, 1, 1), F.ROAD],
	[Rect2i(2, 56, 1, 1), F.ROAD],
	[Rect2i(3, 56, 1, 1), F.ROAD],
	[Rect2i(4, 56, 1, 1), F.ROAD],
	[Rect2i(5, 56, 1, 1), F.ROAD],
	[Rect2i(6, 56, 1, 1), F.ROAD],
	[Rect2i(7, 56, 1, 1), F.ROAD],
	[Rect2i(8, 56, 1, 1), F.ROAD],
	[Rect2i(9, 56, 1, 1), F.ROAD],
	[Rect2i(10, 56, 1, 1), F.ROAD],
	[Rect2i(11, 56, 1, 1), F.ROAD],
	[Rect2i(12, 56, 1, 1), F.ROAD],
	[Rect2i(13, 56, 1, 1), F.ROAD],
	[Rect2i(14, 56, 1, 1), F.ROAD],
	[Rect2i(15, 56, 1, 1), F.ROAD],
	[Rect2i(16, 56, 1, 1), F.ROAD],
	[Rect2i(17, 56, 1, 1), F.ROAD],
	[Rect2i(18, 56, 1, 1), F.ROAD],
	[Rect2i(19, 56, 1, 1), F.ROAD],
	[Rect2i(20, 56, 1, 1), F.ROAD],
	[Rect2i(21, 56, 1, 1), F.ROAD],
	[Rect2i(22, 56, 1, 1), F.ROAD],
	[Rect2i(23, 56, 1, 1), F.ROAD],
	[Rect2i(24, 56, 1, 1), F.ROAD],
	[Rect2i(25, 56, 1, 1), F.ROAD],
	[Rect2i(26, 56, 1, 1), F.ROAD],
	[Rect2i(27, 56, 1, 1), F.ROAD],
	[Rect2i(28, 56, 1, 1), F.ROAD],
	[Rect2i(29, 56, 1, 1), F.ROAD],
	[Rect2i(30, 56, 1, 1), F.ROAD],
	[Rect2i(31, 56, 1, 1), F.ROAD],
	[Rect2i(32, 56, 1, 1), F.ROAD],
	[Rect2i(33, 56, 1, 1), F.ROAD],
	[Rect2i(34, 56, 1, 1), F.ROAD],
	[Rect2i(35, 56, 1, 1), F.ROAD],
	[Rect2i(36, 56, 1, 1), F.ROAD],
	[Rect2i(37, 56, 1, 1), F.ROAD],
	[Rect2i(38, 56, 1, 1), F.ROAD],
	[Rect2i(39, 56, 1, 1), F.ROAD],
	[Rect2i(40, 56, 1, 1), F.ROAD],
	[Rect2i(169, 59, 1, 1), F.ROAD],
	[Rect2i(169, 58, 1, 1), F.ROAD],
	[Rect2i(169, 57, 1, 1), F.ROAD],
	[Rect2i(169, 56, 1, 1), F.ROAD],
	[Rect2i(168, 56, 1, 1), F.ROAD],
	[Rect2i(167, 56, 1, 1), F.ROAD],
	[Rect2i(166, 56, 1, 1), F.ROAD],
	[Rect2i(165, 56, 1, 1), F.ROAD],
	[Rect2i(164, 56, 1, 1), F.ROAD],
	[Rect2i(163, 56, 1, 1), F.ROAD],
	[Rect2i(162, 56, 1, 1), F.ROAD],
	[Rect2i(161, 56, 1, 1), F.ROAD],
	[Rect2i(160, 56, 1, 1), F.ROAD],
	[Rect2i(159, 56, 1, 1), F.ROAD],
	[Rect2i(158, 56, 1, 1), F.ROAD],
	[Rect2i(157, 56, 1, 1), F.ROAD],
	[Rect2i(156, 56, 1, 1), F.ROAD],
	[Rect2i(155, 56, 1, 1), F.ROAD],
	[Rect2i(154, 56, 1, 1), F.ROAD],
	[Rect2i(153, 56, 1, 1), F.ROAD],
	[Rect2i(152, 56, 1, 1), F.ROAD],
	[Rect2i(151, 56, 1, 1), F.ROAD],
	[Rect2i(150, 56, 1, 1), F.ROAD],
	[Rect2i(149, 56, 1, 1), F.ROAD],
	[Rect2i(148, 56, 1, 1), F.ROAD],
	[Rect2i(147, 56, 1, 1), F.ROAD],
	[Rect2i(146, 56, 1, 1), F.ROAD],
	[Rect2i(145, 56, 1, 1), F.ROAD],
	[Rect2i(144, 56, 1, 1), F.ROAD],
	[Rect2i(143, 56, 1, 1), F.ROAD],
	[Rect2i(142, 56, 1, 1), F.ROAD],
	[Rect2i(141, 56, 1, 1), F.ROAD],
	[Rect2i(140, 56, 1, 1), F.ROAD],
	[Rect2i(139, 56, 1, 1), F.ROAD],
	[Rect2i(138, 56, 1, 1), F.ROAD],
	[Rect2i(137, 56, 1, 1), F.ROAD],
	[Rect2i(136, 56, 1, 1), F.ROAD],
	[Rect2i(135, 56, 1, 1), F.ROAD],
	[Rect2i(134, 56, 1, 1), F.ROAD],
	[Rect2i(133, 56, 1, 1), F.ROAD],
	[Rect2i(132, 56, 1, 1), F.ROAD],
	[Rect2i(131, 56, 1, 1), F.ROAD],
	[Rect2i(130, 56, 1, 1), F.ROAD],
	[Rect2i(129, 56, 1, 1), F.ROAD],
	[Rect2i(128, 56, 1, 1), F.ROAD],
	[Rect2i(127, 56, 1, 1), F.ROAD],
	[Rect2i(169, 60, 1, 1), F.ROAD],
	[Rect2i(169, 59, 1, 1), F.ROAD],
	[Rect2i(169, 58, 1, 1), F.ROAD],
	[Rect2i(169, 57, 1, 1), F.ROAD],
	[Rect2i(169, 56, 1, 1), F.ROAD],
	[Rect2i(168, 56, 1, 1), F.ROAD],
	[Rect2i(167, 56, 1, 1), F.ROAD],
	[Rect2i(166, 56, 1, 1), F.ROAD],
	[Rect2i(165, 56, 1, 1), F.ROAD],
	[Rect2i(164, 56, 1, 1), F.ROAD],
	[Rect2i(163, 56, 1, 1), F.ROAD],
	[Rect2i(162, 56, 1, 1), F.ROAD],
	[Rect2i(161, 56, 1, 1), F.ROAD],
	[Rect2i(160, 56, 1, 1), F.ROAD],
	[Rect2i(159, 56, 1, 1), F.ROAD],
	[Rect2i(158, 56, 1, 1), F.ROAD],
	[Rect2i(157, 56, 1, 1), F.ROAD],
	[Rect2i(156, 56, 1, 1), F.ROAD],
	[Rect2i(155, 56, 1, 1), F.ROAD],
	[Rect2i(154, 56, 1, 1), F.ROAD],
	[Rect2i(153, 56, 1, 1), F.ROAD],
	[Rect2i(152, 56, 1, 1), F.ROAD],
	[Rect2i(151, 56, 1, 1), F.ROAD],
	[Rect2i(150, 56, 1, 1), F.ROAD],
	[Rect2i(149, 56, 1, 1), F.ROAD],
	[Rect2i(148, 56, 1, 1), F.ROAD],
	[Rect2i(147, 56, 1, 1), F.ROAD],
	[Rect2i(146, 56, 1, 1), F.ROAD],
	[Rect2i(145, 56, 1, 1), F.ROAD],
	[Rect2i(144, 56, 1, 1), F.ROAD],
	[Rect2i(143, 56, 1, 1), F.ROAD],
	[Rect2i(142, 56, 1, 1), F.ROAD],
	[Rect2i(141, 56, 1, 1), F.ROAD],
	[Rect2i(140, 56, 1, 1), F.ROAD],
	[Rect2i(139, 56, 1, 1), F.ROAD],
	[Rect2i(138, 56, 1, 1), F.ROAD],
	[Rect2i(137, 56, 1, 1), F.ROAD],
	[Rect2i(136, 56, 1, 1), F.ROAD],
	[Rect2i(135, 56, 1, 1), F.ROAD],
	[Rect2i(134, 56, 1, 1), F.ROAD],
	[Rect2i(133, 56, 1, 1), F.ROAD],
	[Rect2i(132, 56, 1, 1), F.ROAD],
	[Rect2i(131, 56, 1, 1), F.ROAD],
	[Rect2i(130, 56, 1, 1), F.ROAD],
	[Rect2i(129, 56, 1, 1), F.ROAD],
	[Rect2i(128, 56, 1, 1), F.ROAD],
	[Rect2i(127, 56, 1, 1), F.ROAD],
	[Rect2i(91, 103, 1, 1), F.ROAD],
	[Rect2i(91, 102, 1, 1), F.ROAD],
	[Rect2i(91, 101, 1, 1), F.ROAD],
	[Rect2i(91, 100, 1, 1), F.ROAD],
	[Rect2i(91, 99, 1, 1), F.ROAD],
	[Rect2i(91, 98, 1, 1), F.ROAD],
	[Rect2i(91, 97, 1, 1), F.ROAD],
	[Rect2i(91, 96, 1, 1), F.ROAD],
	[Rect2i(91, 95, 1, 1), F.ROAD],
	[Rect2i(91, 94, 1, 1), F.ROAD],
	[Rect2i(91, 93, 1, 1), F.ROAD],
	[Rect2i(91, 92, 1, 1), F.ROAD],
	[Rect2i(91, 91, 1, 1), F.ROAD],
	[Rect2i(91, 90, 1, 1), F.ROAD],
	[Rect2i(91, 89, 1, 1), F.ROAD],
	[Rect2i(91, 88, 1, 1), F.ROAD],
	[Rect2i(91, 87, 1, 1), F.ROAD],
	[Rect2i(91, 86, 1, 1), F.ROAD],
	[Rect2i(91, 85, 1, 1), F.ROAD],
	[Rect2i(91, 84, 1, 1), F.ROAD],
	[Rect2i(91, 83, 1, 1), F.ROAD],
	[Rect2i(91, 82, 1, 1), F.ROAD],
	[Rect2i(91, 81, 1, 1), F.ROAD],
	[Rect2i(91, 80, 1, 1), F.ROAD],
	[Rect2i(91, 79, 1, 1), F.ROAD],
	[Rect2i(91, 78, 1, 1), F.ROAD],
	[Rect2i(91, 77, 1, 1), F.ROAD],
	[Rect2i(91, 76, 1, 1), F.ROAD],
	[Rect2i(91, 75, 1, 1), F.ROAD],
	[Rect2i(91, 74, 1, 1), F.ROAD],
	[Rect2i(91, 73, 1, 1), F.ROAD],
	[Rect2i(91, 72, 1, 1), F.ROAD],
	[Rect2i(91, 71, 1, 1), F.ROAD],
	[Rect2i(91, 70, 1, 1), F.ROAD],
	[Rect2i(91, 69, 1, 1), F.ROAD],
	[Rect2i(91, 68, 1, 1), F.ROAD],
	[Rect2i(91, 67, 1, 1), F.ROAD],
	[Rect2i(91, 66, 1, 1), F.ROAD],
	[Rect2i(91, 65, 1, 1), F.ROAD],
	[Rect2i(91, 64, 1, 1), F.ROAD],
	[Rect2i(91, 63, 1, 1), F.ROAD],
	[Rect2i(91, 62, 1, 1), F.ROAD],
	[Rect2i(91, 61, 1, 1), F.ROAD],
	[Rect2i(91, 60, 1, 1), F.ROAD],
	[Rect2i(91, 59, 1, 1), F.ROAD],
	[Rect2i(91, 58, 1, 1), F.ROAD],
	[Rect2i(92, 103, 1, 1), F.ROAD],
	[Rect2i(92, 102, 1, 1), F.ROAD],
	[Rect2i(92, 101, 1, 1), F.ROAD],
	[Rect2i(92, 100, 1, 1), F.ROAD],
	[Rect2i(92, 99, 1, 1), F.ROAD],
	[Rect2i(92, 98, 1, 1), F.ROAD],
	[Rect2i(92, 97, 1, 1), F.ROAD],
	[Rect2i(92, 96, 1, 1), F.ROAD],
	[Rect2i(92, 95, 1, 1), F.ROAD],
	[Rect2i(92, 94, 1, 1), F.ROAD],
	[Rect2i(92, 93, 1, 1), F.ROAD],
	[Rect2i(92, 92, 1, 1), F.ROAD],
	[Rect2i(92, 91, 1, 1), F.ROAD],
	[Rect2i(92, 90, 1, 1), F.ROAD],
	[Rect2i(92, 89, 1, 1), F.ROAD],
	[Rect2i(92, 88, 1, 1), F.ROAD],
	[Rect2i(92, 87, 1, 1), F.ROAD],
	[Rect2i(92, 86, 1, 1), F.ROAD],
	[Rect2i(92, 85, 1, 1), F.ROAD],
	[Rect2i(92, 84, 1, 1), F.ROAD],
	[Rect2i(92, 83, 1, 1), F.ROAD],
	[Rect2i(92, 82, 1, 1), F.ROAD],
	[Rect2i(92, 81, 1, 1), F.ROAD],
	[Rect2i(92, 80, 1, 1), F.ROAD],
	[Rect2i(92, 79, 1, 1), F.ROAD],
	[Rect2i(92, 78, 1, 1), F.ROAD],
	[Rect2i(92, 77, 1, 1), F.ROAD],
	[Rect2i(92, 76, 1, 1), F.ROAD],
	[Rect2i(92, 75, 1, 1), F.ROAD],
	[Rect2i(92, 74, 1, 1), F.ROAD],
	[Rect2i(92, 73, 1, 1), F.ROAD],
	[Rect2i(92, 72, 1, 1), F.ROAD],
	[Rect2i(92, 71, 1, 1), F.ROAD],
	[Rect2i(92, 70, 1, 1), F.ROAD],
	[Rect2i(92, 69, 1, 1), F.ROAD],
	[Rect2i(92, 68, 1, 1), F.ROAD],
	[Rect2i(92, 67, 1, 1), F.ROAD],
	[Rect2i(92, 66, 1, 1), F.ROAD],
	[Rect2i(92, 65, 1, 1), F.ROAD],
	[Rect2i(92, 64, 1, 1), F.ROAD],
	[Rect2i(92, 63, 1, 1), F.ROAD],
	[Rect2i(92, 62, 1, 1), F.ROAD],
	[Rect2i(92, 61, 1, 1), F.ROAD],
	[Rect2i(92, 60, 1, 1), F.ROAD],
	[Rect2i(92, 59, 1, 1), F.ROAD],
	[Rect2i(92, 58, 1, 1), F.ROAD],
	[Rect2i(46, 67, 1, 1), F.ROAD],
	[Rect2i(46, 66, 1, 1), F.ROAD],
	[Rect2i(46, 65, 1, 1), F.ROAD],
	[Rect2i(46, 64, 1, 1), F.ROAD],
	[Rect2i(46, 63, 1, 1), F.ROAD],
	[Rect2i(46, 62, 1, 1), F.ROAD],
	[Rect2i(46, 61, 1, 1), F.ROAD],
	[Rect2i(46, 60, 1, 1), F.ROAD],
	[Rect2i(46, 59, 1, 1), F.ROAD],
	[Rect2i(46, 58, 1, 1), F.ROAD],
	[Rect2i(63, 67, 1, 1), F.ROAD],
	[Rect2i(63, 66, 1, 1), F.ROAD],
	[Rect2i(63, 65, 1, 1), F.ROAD],
	[Rect2i(63, 64, 1, 1), F.ROAD],
	[Rect2i(63, 63, 1, 1), F.ROAD],
	[Rect2i(63, 62, 1, 1), F.ROAD],
	[Rect2i(63, 61, 1, 1), F.ROAD],
	[Rect2i(63, 60, 1, 1), F.ROAD],
	[Rect2i(63, 59, 1, 1), F.ROAD],
	[Rect2i(63, 58, 1, 1), F.ROAD],
	[Rect2i(80, 67, 1, 1), F.ROAD],
	[Rect2i(80, 66, 1, 1), F.ROAD],
	[Rect2i(80, 65, 1, 1), F.ROAD],
	[Rect2i(80, 64, 1, 1), F.ROAD],
	[Rect2i(80, 63, 1, 1), F.ROAD],
	[Rect2i(80, 62, 1, 1), F.ROAD],
	[Rect2i(80, 61, 1, 1), F.ROAD],
	[Rect2i(80, 60, 1, 1), F.ROAD],
	[Rect2i(80, 59, 1, 1), F.ROAD],
	[Rect2i(80, 58, 1, 1), F.ROAD],
	[Rect2i(107, 80, 1, 1), F.ROAD],
	[Rect2i(107, 79, 1, 1), F.ROAD],
	[Rect2i(107, 78, 1, 1), F.ROAD],
	[Rect2i(107, 77, 1, 1), F.ROAD],
	[Rect2i(107, 76, 1, 1), F.ROAD],
	[Rect2i(107, 75, 1, 1), F.ROAD],
	[Rect2i(107, 74, 1, 1), F.ROAD],
	[Rect2i(107, 73, 1, 1), F.ROAD],
	[Rect2i(107, 72, 1, 1), F.ROAD],
	[Rect2i(107, 71, 1, 1), F.ROAD],
	[Rect2i(107, 70, 1, 1), F.ROAD],
	[Rect2i(107, 69, 1, 1), F.ROAD],
	[Rect2i(107, 68, 1, 1), F.ROAD],
	[Rect2i(107, 67, 1, 1), F.ROAD],
	[Rect2i(107, 66, 1, 1), F.ROAD],
	[Rect2i(107, 65, 1, 1), F.ROAD],
	[Rect2i(107, 64, 1, 1), F.ROAD],
	[Rect2i(107, 63, 1, 1), F.ROAD],
	[Rect2i(107, 62, 1, 1), F.ROAD],
	[Rect2i(107, 61, 1, 1), F.ROAD],
	[Rect2i(107, 60, 1, 1), F.ROAD],
	[Rect2i(107, 59, 1, 1), F.ROAD],
	[Rect2i(107, 58, 1, 1), F.ROAD],
	[Rect2i(120, 47, 1, 1), F.ROAD],
	[Rect2i(151, 50, 1, 1), F.ROAD],
	[Rect2i(151, 51, 1, 1), F.ROAD],
	[Rect2i(151, 55, 1, 1), F.ROAD],
	[Rect2i(151, 56, 1, 1), F.ROAD],
	[Rect2i(150, 56, 1, 1), F.ROAD],
	[Rect2i(149, 56, 1, 1), F.ROAD],
	[Rect2i(148, 56, 1, 1), F.ROAD],
	[Rect2i(147, 56, 1, 1), F.ROAD],
	[Rect2i(146, 56, 1, 1), F.ROAD],
	[Rect2i(145, 56, 1, 1), F.ROAD],
	[Rect2i(144, 56, 1, 1), F.ROAD],
	[Rect2i(143, 56, 1, 1), F.ROAD],
	[Rect2i(142, 56, 1, 1), F.ROAD],
	[Rect2i(141, 56, 1, 1), F.ROAD],
	[Rect2i(140, 56, 1, 1), F.ROAD],
	[Rect2i(139, 56, 1, 1), F.ROAD],
	[Rect2i(138, 56, 1, 1), F.ROAD],
	[Rect2i(137, 56, 1, 1), F.ROAD],
	[Rect2i(136, 56, 1, 1), F.ROAD],
	[Rect2i(135, 56, 1, 1), F.ROAD],
	[Rect2i(134, 56, 1, 1), F.ROAD],
	[Rect2i(133, 56, 1, 1), F.ROAD],
	[Rect2i(132, 56, 1, 1), F.ROAD],
	[Rect2i(131, 56, 1, 1), F.ROAD],
	[Rect2i(130, 56, 1, 1), F.ROAD],
	[Rect2i(129, 56, 1, 1), F.ROAD],
	[Rect2i(128, 56, 1, 1), F.ROAD],
	[Rect2i(127, 56, 1, 1), F.ROAD],
	[Rect2i(132, 69, 4, 2), F.DEEP_SNOW],
	[Rect2i(154, 82, 4, 2), F.DEEP_SNOW],
	[Rect2i(47, 96, 4, 2), F.DEEP_SNOW],
	[Rect2i(155, 96, 4, 2), F.DEEP_SNOW],
]

const BUILDING_ROWS: Array = [
	["어장 주택", Rect2i(40, 68, 14, 12)],
	["어장 주택", Rect2i(57, 71, 14, 12)],
	["어장 주택", Rect2i(74, 68, 14, 12)],
	["어장 관리소", Rect2i(98, 81, 20, 17)],
	["어장 가공동", Rect2i(101, 3, 44, 27)],
	["얼음 낚시 움막", Rect2i(149, 24, 7, 7)],
	["얼음 낚시 움막", Rect2i(64, 39, 7, 7)],
	["얼음 낚시 움막", Rect2i(74, 39, 7, 7)],
	["얼음 낚시 움막", Rect2i(111, 39, 7, 7)],
	["얼음 낚시 움막", Rect2i(121, 39, 7, 7)],
]

const LEVEL_ROWS: Array = [
	[1, 4, Rect2i(101, 3, 44, 27)],
	[-1, 4, Rect2i(101, 3, 44, 27)],
]

const WALL_ROWS: Array = [
	[0, Rect2i(47, 69, 1, 10)],
	[0, Rect2i(64, 72, 1, 10)],
	[0, Rect2i(81, 69, 1, 10)],
	[0, Rect2i(108, 82, 1, 15)],
	[0, Rect2i(106, 7, 34, 1)],
	[0, Rect2i(106, 25, 34, 1)],
	[0, Rect2i(106, 8, 1, 17)],
	[0, Rect2i(139, 8, 1, 17)],
	[0, Rect2i(123, 8, 1, 17)],
	[0, Rect2i(107, 16, 16, 1)],
	[1, Rect2i(106, 7, 34, 1)],
	[1, Rect2i(106, 25, 34, 1)],
	[1, Rect2i(106, 8, 1, 17)],
	[1, Rect2i(139, 8, 1, 17)],
	[1, Rect2i(123, 8, 1, 17)],
	[1, Rect2i(107, 16, 16, 1)],
	[-1, Rect2i(106, 7, 34, 1)],
	[-1, Rect2i(106, 25, 34, 1)],
	[-1, Rect2i(106, 8, 1, 17)],
	[-1, Rect2i(139, 8, 1, 17)],
	[-1, Rect2i(123, 8, 1, 17)],
	[-1, Rect2i(107, 16, 16, 1)],
]

const DOOR_ROWS: Array = [
	[0, Vector2i(47, 74), "closed", 0],
	[0, Vector2i(46, 68), "closed", 0],
	[0, Vector2i(64, 77), "closed", 1],
	[0, Vector2i(63, 71), "closed", 1],
	[0, Vector2i(81, 74), "closed", 2],
	[0, Vector2i(80, 68), "closed", 2],
	[0, Vector2i(108, 89), "closed", 3],
	[0, Vector2i(107, 81), "closed", 3],
	[0, Vector2i(106, 9), "closed", 4],
	[0, Vector2i(106, 23), "closed", 4],
	[0, Vector2i(139, 9), "closed", 4],
	[0, Vector2i(122, 29), "open", 4],
	[0, Vector2i(151, 30), "closed", 5],
	[0, Vector2i(66, 45), "closed", 6],
	[0, Vector2i(76, 45), "closed", 7],
	[0, Vector2i(113, 45), "closed", 8],
	[0, Vector2i(123, 45), "closed", 9],
	[1, Vector2i(106, 9), "closed", 4],
	[1, Vector2i(106, 23), "closed", 4],
	[1, Vector2i(139, 9), "closed", 4],
	[-1, Vector2i(106, 9), "closed", 4],
	[-1, Vector2i(106, 23), "closed", 4],
	[-1, Vector2i(139, 9), "closed", 4],
]

const WINDOW_ROWS: Array = [
	[0, Vector2i(43, 68), 0],
	[0, Vector2i(50, 79), 0],
	[0, Vector2i(40, 71), 0],
	[0, Vector2i(53, 76), 0],
	[0, Vector2i(60, 71), 1],
	[0, Vector2i(67, 82), 1],
	[0, Vector2i(57, 74), 1],
	[0, Vector2i(70, 79), 1],
	[0, Vector2i(77, 68), 2],
	[0, Vector2i(84, 79), 2],
	[0, Vector2i(74, 71), 2],
	[0, Vector2i(87, 76), 2],
	[0, Vector2i(101, 81), 3],
	[0, Vector2i(114, 97), 3],
	[0, Vector2i(98, 84), 3],
	[0, Vector2i(117, 94), 3],
	[0, Vector2i(104, 3), 4],
	[0, Vector2i(141, 29), 4],
	[0, Vector2i(101, 6), 4],
	[0, Vector2i(144, 26), 4],
	[0, Vector2i(151, 24), 5],
	[0, Vector2i(66, 39), 6],
	[0, Vector2i(76, 39), 7],
	[0, Vector2i(113, 39), 8],
	[0, Vector2i(123, 39), 9],
	[1, Vector2i(104, 3), 4],
	[1, Vector2i(141, 29), 4],
	[1, Vector2i(101, 6), 4],
	[1, Vector2i(144, 26), 4],
]

const STAIR_ROWS: Array = [
	[Vector2i(103, 8), 0, 1],
	[Vector2i(103, 9), -1, 0],
]

const STOVE_ROWS: Array = [
	[Vector2i(150, 25), 5, 0],
	[Vector2i(65, 40), 6, 0],
	[Vector2i(75, 40), 7, 0],
	[Vector2i(112, 40), 8, 0],
	[Vector2i(122, 40), 9, 0],
]

const CONTAINER_ROWS: Array = [
	["supply_0", "식량 찬장", Vector2i(42, 71), 0, ["food_pack"], 0],
	["supply_1", "목재 선반", Vector2i(51, 77), 0, ["plank"], 0],
	["supply_2", "식량 찬장", Vector2i(59, 74), 1, ["food_pack"], 0],
	["supply_3", "목재 선반", Vector2i(68, 80), 1, ["plank"], 0],
	["supply_4", "식량 찬장", Vector2i(76, 71), 2, ["food_pack"], 0],
	["supply_5", "목재 선반", Vector2i(85, 77), 2, ["plank"], 0],
	["supply_6", "식량 찬장", Vector2i(100, 84), 3, ["food_pack"], 0],
	["supply_7", "목재 선반", Vector2i(115, 95), 3, ["plank"], 0],
	["supply_8", "저장 식량 상자", Vector2i(108, 9), 4, ["food_pack", "food_pack"], 0],
	["supply_9", "연료 보관함", Vector2i(108, 23), 4, ["wood", "wood", "wood"], 0],
	["supply_10", "깊은 부품 상자", Vector2i(125, 23), 4, ["scrap","scrap","food_pack","wood"], 0],
	["supply_11", "작업 통로 선반", Vector2i(103, 5), 4, ["plank"], 0],
	["supply_12", "움막 낚시 선반", Vector2i(153, 28), 5, ["food_pack"], 0],
	["supply_13", "움막 낚시 선반", Vector2i(68, 43), 6, ["food_pack"], 0],
	["supply_14", "움막 낚시 선반", Vector2i(78, 43), 7, ["food_pack"], 0],
	["supply_15", "움막 낚시 선반", Vector2i(115, 43), 8, ["food_pack"], 0],
	["supply_16", "움막 낚시 선반", Vector2i(125, 43), 9, ["food_pack"], 0],
	["supply_17", "저장 식량 상자", Vector2i(108, 9), 4, ["food_pack", "food_pack"], 1],
	["supply_18", "연료 보관함", Vector2i(108, 23), 4, ["wood", "wood", "wood"], 1],
	["supply_19", "깊은 부품 상자", Vector2i(125, 23), 4, ["scrap","scrap","food_pack","wood"], 1],
	["supply_20", "작업 통로 선반", Vector2i(103, 5), 4, ["plank"], 1],
	["supply_21", "저장 식량 상자", Vector2i(108, 9), 4, ["food_pack", "food_pack"], -1],
	["supply_22", "연료 보관함", Vector2i(108, 23), 4, ["wood", "wood", "wood"], -1],
	["supply_23", "깊은 부품 상자", Vector2i(125, 23), 4, ["scrap","scrap","food_pack","wood"], -1],
	["supply_24", "작업 통로 선반", Vector2i(103, 5), 4, ["plank"], -1],
	["pier_wood", "잔교 목재 상자", Vector2i(91, 20), -1, ["plank","wood"], 0],
]

const SALVAGE_ROWS: Array = [
	["pier_repair", "잔교 수선 목재", Vector2i(72, 21), "wood", 2],
]

const ZONE_ROWS: Array = [
	["A", Rect2i(0, 0, 170, 50), Vector2i(52, 47)],
	["B", Rect2i(0, 50, 170, 54), Vector2i(42, 70)],
	["C", Rect2i(65, 8, 28, 14), Vector2i(67, 10)],
	["D", Rect2i(101, 3, 44, 27), Vector2i(103, 5)],
]

const ENTRY_CELLS: Dictionary = {
	"shore_west": [Vector2i(0, 63), Vector2i(0, 64)],
	"shore_east": [Vector2i(169, 59), Vector2i(169, 60)],
	"village_back": [Vector2i(91, 103), Vector2i(92, 103)],
}

const ENTRY_GAP: Dictionary = {"shore_west":0.6,"shore_east":0.6,"village_back":2.5}

const BARRICADE_CELLS: Array[Vector2i] = [
	Vector2i(54, 73),
	Vector2i(55, 73),
	Vector2i(56, 73),
	Vector2i(71, 73),
	Vector2i(72, 73),
	Vector2i(73, 73),
	Vector2i(71, 43),
	Vector2i(72, 43),
	Vector2i(73, 43),
	Vector2i(118, 43),
	Vector2i(119, 43),
	Vector2i(120, 43),
]

const PROPS: Array = [
	{"kind": "overturned_boat", "rect": Rect2i(54, 60, 4, 2), "solid": "low", "facing": 0, "note": "하역 마당 엄폐 · 뒤집힌 배"},
	{"kind": "net_drying_rack", "rect": Rect2i(72, 58, 1, 4), "solid": "low", "facing": 1, "note": "하역 마당 엄폐 · 그물 건조대"},
	{"kind": "fish_trap_stack", "rect": Rect2i(95, 66, 2, 3), "solid": "low", "facing": 1, "note": "하역 마당 엄폐 · 통발 쌓음"},
	{"kind": "firewood_stack", "rect": Rect2i(112, 60, 3, 2), "solid": "low", "facing": 0, "note": "하역 마당 엄폐 · 장작 단"},
	{"kind": "pier_deck", "rect": Rect2i(61, 20, 3, 23), "solid": "none", "facing": 1, "note": "잔교 통로 구간 · 잔교"},
	{"kind": "pier_deck", "rect": Rect2i(74, 47, 3, 5), "solid": "none", "facing": 1, "note": "잔교 통로 구간 · 잔교"},
	{"kind": "pier_deck", "rect": Rect2i(118, 34, 3, 9), "solid": "none", "facing": 1, "note": "잔교 통로 구간 · 잔교"},
	{"kind": "pier_deck", "rect": Rect2i(121, 47, 3, 5), "solid": "none", "facing": 1, "note": "잔교 통로 구간 · 잔교"},
	{"kind": "pier_deck", "rect": Rect2i(87, 22, 10, 3), "solid": "none", "facing": 0, "note": "잔교 통로 구간 · 잔교"},
	{"kind": "pier_deck", "rect": Rect2i(94, 25, 3, 15), "solid": "none", "facing": 1, "note": "잔교 통로 구간 · 잔교"},
	{"kind": "pier_deck", "rect": Rect2i(97, 30, 23, 3), "solid": "none", "facing": 0, "note": "잔교 통로 구간 · 잔교"},
	{"kind": "fishing_platform", "rect": Rect2i(65, 25, 28, 14), "solid": "none", "facing": 0, "note": "어장 작업 무리 · 어장 작업대"},
	{"kind": "sunken_wheelhouse", "rect": Rect2i(7, 5, 4, 3), "solid": "wall", "facing": 0, "note": "가라앉은 배 1 · 조타실 윗부분"},
	{"kind": "sunken_bow", "rect": Rect2i(15, 6, 2, 4), "solid": "wall", "facing": 1, "note": "가라앉은 배 1 · 솟은 뱃머리"},
	{"kind": "sunken_deck_section", "rect": Rect2i(8, 11, 8, 3), "solid": "low", "facing": 0, "note": "가라앉은 배 1 · 드러난 갑판 조각"},
	{"kind": "fallen_mast", "rect": Rect2i(13, 15, 7, 1), "solid": "low", "facing": 0, "note": "가라앉은 배 1 · 쓰러진 돛대"},
	{"kind": "sunken_wheelhouse", "rect": Rect2i(35, 3, 4, 3), "solid": "wall", "facing": 0, "note": "가라앉은 배 2 · 조타실 윗부분"},
	{"kind": "sunken_bow", "rect": Rect2i(43, 4, 2, 4), "solid": "wall", "facing": 1, "note": "가라앉은 배 2 · 솟은 뱃머리"},
	{"kind": "sunken_deck_section", "rect": Rect2i(36, 9, 8, 3), "solid": "low", "facing": 0, "note": "가라앉은 배 2 · 드러난 갑판 조각"},
	{"kind": "sunken_wheelhouse", "rect": Rect2i(7, 23, 4, 3), "solid": "wall", "facing": 0, "note": "가라앉은 배 3 · 조타실 윗부분"},
	{"kind": "sunken_bow", "rect": Rect2i(15, 24, 2, 4), "solid": "wall", "facing": 1, "note": "가라앉은 배 3 · 솟은 뱃머리"},
	{"kind": "sunken_deck_section", "rect": Rect2i(8, 29, 8, 3), "solid": "low", "facing": 0, "note": "가라앉은 배 3 · 드러난 갑판 조각"},
	{"kind": "fallen_mast", "rect": Rect2i(13, 33, 7, 1), "solid": "low", "facing": 0, "note": "가라앉은 배 3 · 쓰러진 돛대"},
	{"kind": "sunken_wheelhouse", "rect": Rect2i(42, 20, 4, 3), "solid": "wall", "facing": 0, "note": "가라앉은 배 4 · 조타실 윗부분"},
	{"kind": "sunken_bow", "rect": Rect2i(50, 21, 2, 4), "solid": "wall", "facing": 1, "note": "가라앉은 배 4 · 솟은 뱃머리"},
	{"kind": "sunken_deck_section", "rect": Rect2i(43, 26, 8, 3), "solid": "low", "facing": 0, "note": "가라앉은 배 4 · 드러난 갑판 조각"},
	{"kind": "sunken_wheelhouse", "rect": Rect2i(151, 5, 4, 3), "solid": "wall", "facing": 0, "note": "가라앉은 배 5 · 조타실 윗부분"},
	{"kind": "sunken_bow", "rect": Rect2i(159, 6, 2, 4), "solid": "wall", "facing": 1, "note": "가라앉은 배 5 · 솟은 뱃머리"},
	{"kind": "sunken_deck_section", "rect": Rect2i(152, 11, 8, 3), "solid": "low", "facing": 0, "note": "가라앉은 배 5 · 드러난 갑판 조각"},
	{"kind": "fallen_mast", "rect": Rect2i(157, 15, 7, 1), "solid": "low", "facing": 0, "note": "가라앉은 배 5 · 쓰러진 돛대"},
	{"kind": "fish_hoist", "rect": Rect2i(66, 9, 3, 3), "solid": "wall", "facing": 0, "note": "작업대 1 · 어망 윈치 틀"},
	{"kind": "cleaning_table", "rect": Rect2i(72, 10, 4, 2), "solid": "low", "facing": 0, "note": "작업대 1 · 손질대"},
	{"kind": "fish_crate_stack", "rect": Rect2i(77, 12, 2, 2), "solid": "low", "facing": 0, "note": "작업대 1 · 생선 상자 더미"},
	{"kind": "net_pile", "rect": Rect2i(68, 15, 2, 2), "solid": "low", "facing": 0, "note": "작업대 1 · 그물 더미"},
	{"kind": "ice_saw_frame", "rect": Rect2i(87, 19, 3, 2), "solid": "low", "facing": 0, "note": "작업대 1 · 얼음 톱 틀"},
	{"kind": "ice_cut_pool", "rect": Rect2i(60, 13, 4, 3), "solid": "none", "facing": 0, "note": "작업대 1 · 잘라 낸 얼음 자리"},
	{"kind": "fish_drying_frame", "rect": Rect2i(27, 78, 4, 2), "solid": "low", "facing": 0, "note": "주택 마당 1 · 생선 건조 틀"},
	{"kind": "net_pile", "rect": Rect2i(48, 81, 2, 2), "solid": "low", "facing": 0, "note": "주택 마당 1 · 그물 더미"},
	{"kind": "dry_bush", "rect": Rect2i(41, 82, 2, 2), "solid": "none", "facing": 0, "note": "주택 마당 1 · 마른 덤불"},
	{"kind": "buoy_line", "rect": Rect2i(72, 72, 2, 1), "solid": "none", "facing": 0, "note": "주택 마당 2 · 부표 줄"},
	{"kind": "snow_drift", "rect": Rect2i(58, 83, 4, 2), "solid": "none", "facing": 0, "note": "주택 마당 2 · 눈더미"},
	{"kind": "net_pile", "rect": Rect2i(89, 78, 2, 2), "solid": "low", "facing": 0, "note": "주택 마당 3 · 그물 더미"},
	{"kind": "dry_bush", "rect": Rect2i(75, 82, 2, 2), "solid": "none", "facing": 0, "note": "주택 마당 3 · 마른 덤불"},
	{"kind": "frozen_reeds", "rect": Rect2i(7, 50, 3, 3), "solid": "none", "facing": 0, "note": "물가 무리 1 · 얼어붙은 갈대"},
	{"kind": "shore_ice_heap", "rect": Rect2i(11, 46, 3, 2), "solid": "low", "facing": 0, "note": "물가 무리 1 · 물가 얼음 무더기"},
	{"kind": "fishing_hole", "rect": Rect2i(14, 44, 1, 1), "solid": "none", "facing": 0, "note": "물가 무리 1 · 낚시 구멍"},
	{"kind": "frozen_reeds", "rect": Rect2i(29, 50, 3, 3), "solid": "none", "facing": 0, "note": "물가 무리 2 · 얼어붙은 갈대"},
	{"kind": "shore_ice_heap", "rect": Rect2i(26, 52, 3, 2), "solid": "low", "facing": 0, "note": "물가 무리 2 · 물가 얼음 무더기"},
	{"kind": "fishing_hole", "rect": Rect2i(35, 44, 1, 1), "solid": "none", "facing": 0, "note": "물가 무리 2 · 낚시 구멍"},
	{"kind": "fishing_hole", "rect": Rect2i(56, 44, 1, 1), "solid": "none", "facing": 0, "note": "물가 무리 3 · 낚시 구멍"},
	{"kind": "fishing_hole", "rect": Rect2i(79, 46, 1, 1), "solid": "none", "facing": 0, "note": "물가 무리 4 · 낚시 구멍"},
	{"kind": "fishing_hole", "rect": Rect2i(98, 44, 1, 1), "solid": "none", "facing": 0, "note": "물가 무리 5 · 낚시 구멍"},
	{"kind": "fishing_hole", "rect": Rect2i(119, 44, 1, 1), "solid": "none", "facing": 0, "note": "물가 무리 6 · 낚시 구멍"},
	{"kind": "frozen_reeds", "rect": Rect2i(134, 50, 3, 3), "solid": "none", "facing": 0, "note": "물가 무리 7 · 얼어붙은 갈대"},
	{"kind": "shore_ice_heap", "rect": Rect2i(131, 52, 3, 2), "solid": "low", "facing": 0, "note": "물가 무리 7 · 물가 얼음 무더기"},
	{"kind": "fishing_hole", "rect": Rect2i(140, 44, 1, 1), "solid": "none", "facing": 0, "note": "물가 무리 7 · 낚시 구멍"},
	{"kind": "tool_bench", "rect": Rect2i(146, 22, 3, 1), "solid": "low", "facing": 0, "note": "움막 1 · 연장 작업대"},
	{"kind": "firewood_stack", "rect": Rect2i(158, 25, 3, 2), "solid": "low", "facing": 0, "note": "움막 1 · 장작 단"},
	{"kind": "fishing_hole", "rect": Rect2i(147, 32, 1, 1), "solid": "none", "facing": 0, "note": "움막 1 · 낚시 구멍"},
	{"kind": "tip_up_flag", "rect": Rect2i(148, 32, 1, 1), "solid": "none", "facing": 0, "note": "움막 1 · 낚시 깃대"},
	{"kind": "fishing_hole", "rect": Rect2i(150, 34, 1, 1), "solid": "none", "facing": 0, "note": "움막 1 · 낚시 구멍"},
	{"kind": "tip_up_flag", "rect": Rect2i(151, 34, 1, 1), "solid": "none", "facing": 0, "note": "움막 1 · 낚시 깃대"},
	{"kind": "fishing_hole", "rect": Rect2i(154, 33, 1, 1), "solid": "none", "facing": 0, "note": "움막 1 · 낚시 구멍"},
	{"kind": "tip_up_flag", "rect": Rect2i(155, 33, 1, 1), "solid": "none", "facing": 0, "note": "움막 1 · 낚시 깃대"},
	{"kind": "fishing_hole", "rect": Rect2i(62, 47, 1, 1), "solid": "none", "facing": 0, "note": "움막 2 · 낚시 구멍"},
	{"kind": "tip_up_flag", "rect": Rect2i(64, 47, 1, 1), "solid": "none", "facing": 0, "note": "움막 2 · 낚시 깃대"},
	{"kind": "fishing_hole", "rect": Rect2i(63, 47, 1, 1), "solid": "none", "facing": 0, "note": "움막 2 · 낚시 구멍"},
	{"kind": "tip_up_flag", "rect": Rect2i(63, 46, 1, 1), "solid": "none", "facing": 0, "note": "움막 2 · 낚시 깃대"},
	{"kind": "fishing_hole", "rect": Rect2i(69, 48, 1, 1), "solid": "none", "facing": 0, "note": "움막 2 · 낚시 구멍"},
	{"kind": "tip_up_flag", "rect": Rect2i(70, 48, 1, 1), "solid": "none", "facing": 0, "note": "움막 2 · 낚시 깃대"},
	{"kind": "fishing_hole", "rect": Rect2i(72, 47, 1, 1), "solid": "none", "facing": 0, "note": "움막 3 · 낚시 구멍"},
	{"kind": "tip_up_flag", "rect": Rect2i(73, 48, 1, 1), "solid": "none", "facing": 0, "note": "움막 3 · 낚시 깃대"},
	{"kind": "fishing_hole", "rect": Rect2i(73, 47, 1, 1), "solid": "none", "facing": 0, "note": "움막 3 · 낚시 구멍"},
	{"kind": "tip_up_flag", "rect": Rect2i(73, 46, 1, 1), "solid": "none", "facing": 0, "note": "움막 3 · 낚시 깃대"},
	{"kind": "fishing_hole", "rect": Rect2i(79, 48, 1, 1), "solid": "none", "facing": 0, "note": "움막 3 · 낚시 구멍"},
	{"kind": "tip_up_flag", "rect": Rect2i(80, 48, 1, 1), "solid": "none", "facing": 0, "note": "움막 3 · 낚시 깃대"},
	{"kind": "fishing_hole", "rect": Rect2i(109, 47, 1, 1), "solid": "none", "facing": 0, "note": "움막 4 · 낚시 구멍"},
	{"kind": "tip_up_flag", "rect": Rect2i(111, 47, 1, 1), "solid": "none", "facing": 0, "note": "움막 4 · 낚시 깃대"},
	{"kind": "fishing_hole", "rect": Rect2i(110, 47, 1, 1), "solid": "none", "facing": 0, "note": "움막 4 · 낚시 구멍"},
	{"kind": "tip_up_flag", "rect": Rect2i(110, 46, 1, 1), "solid": "none", "facing": 0, "note": "움막 4 · 낚시 깃대"},
	{"kind": "fishing_hole", "rect": Rect2i(116, 48, 1, 1), "solid": "none", "facing": 0, "note": "움막 4 · 낚시 구멍"},
	{"kind": "tip_up_flag", "rect": Rect2i(117, 48, 1, 1), "solid": "none", "facing": 0, "note": "움막 4 · 낚시 깃대"},
	{"kind": "fishing_hole", "rect": Rect2i(119, 47, 1, 1), "solid": "none", "facing": 0, "note": "움막 5 · 낚시 구멍"},
	{"kind": "tip_up_flag", "rect": Rect2i(120, 46, 1, 1), "solid": "none", "facing": 0, "note": "움막 5 · 낚시 깃대"},
	{"kind": "fishing_hole", "rect": Rect2i(120, 47, 1, 1), "solid": "none", "facing": 0, "note": "움막 5 · 낚시 구멍"},
	{"kind": "tip_up_flag", "rect": Rect2i(125, 49, 1, 1), "solid": "none", "facing": 0, "note": "움막 5 · 낚시 깃대"},
	{"kind": "fishing_hole", "rect": Rect2i(126, 48, 1, 1), "solid": "none", "facing": 0, "note": "움막 5 · 낚시 구멍"},
	{"kind": "tip_up_flag", "rect": Rect2i(127, 48, 1, 1), "solid": "none", "facing": 0, "note": "움막 5 · 낚시 깃대"},
	{"kind": "fish_truck", "rect": Rect2i(146, 15, 6, 3), "solid": "wall", "facing": 0, "note": "창고 앞뜰 · 생선 운반 트럭"},
	{"kind": "boat_on_blocks", "rect": Rect2i(95, 1, 5, 2), "solid": "low", "facing": 0, "note": "창고 앞뜰 · 받침대에 얹힌 배"},
	{"kind": "tool_bench", "rect": Rect2i(111, 1, 3, 1), "solid": "low", "facing": 0, "note": "창고 앞뜰 · 연장 작업대"},
	{"kind": "pallet_stack", "rect": Rect2i(146, 1, 2, 2), "solid": "low", "facing": 0, "note": "창고 앞뜰 · 상자 팔레트"},
	{"kind": "ice_block_stack", "rect": Rect2i(96, 9, 3, 2), "solid": "low", "facing": 0, "note": "창고 앞뜰 · 얼음 덩이 쌓음"},
	{"kind": "ice_sled_load", "rect": Rect2i(96, 16, 3, 1), "solid": "low", "facing": 0, "note": "창고 앞뜰 · 짐 실은 썰매"},
	{"kind": "fuel_tank", "rect": Rect2i(121, 84, 3, 3), "solid": "wall", "facing": 0, "note": "설비 뒤편 · 연료 탱크"},
	{"kind": "generator_unit", "rect": Rect2i(121, 90, 2, 2), "solid": "low", "facing": 0, "note": "설비 뒤편 · 발전기"},
	{"kind": "fuel_drum_group", "rect": Rect2i(125, 92, 2, 2), "solid": "low", "facing": 0, "note": "설비 뒤편 · 연료 드럼"},
	{"kind": "rubbish_pile", "rect": Rect2i(95, 83, 2, 1), "solid": "none", "facing": 0, "note": "설비 뒤편 · 쏟아진 쓰레기"},
	{"kind": "bare_willow", "rect": Rect2i(8, 70, 1, 1), "solid": "tree", "facing": 0, "note": "버드나무 무리 1 · 마른 버드나무"},
	{"kind": "bare_willow", "rect": Rect2i(10, 71, 1, 1), "solid": "tree", "facing": 0, "note": "버드나무 무리 1 · 마른 버드나무"},
	{"kind": "bare_willow", "rect": Rect2i(7, 73, 1, 1), "solid": "tree", "facing": 0, "note": "버드나무 무리 1 · 마른 버드나무"},
	{"kind": "bare_willow", "rect": Rect2i(11, 74, 1, 1), "solid": "tree", "facing": 0, "note": "버드나무 무리 1 · 마른 버드나무"},
	{"kind": "bare_willow", "rect": Rect2i(9, 76, 1, 1), "solid": "tree", "facing": 0, "note": "버드나무 무리 1 · 마른 버드나무"},
	{"kind": "bare_willow", "rect": Rect2i(24, 92, 1, 1), "solid": "tree", "facing": 0, "note": "버드나무 무리 2 · 마른 버드나무"},
	{"kind": "bare_willow", "rect": Rect2i(26, 93, 1, 1), "solid": "tree", "facing": 0, "note": "버드나무 무리 2 · 마른 버드나무"},
	{"kind": "bare_willow", "rect": Rect2i(23, 95, 1, 1), "solid": "tree", "facing": 0, "note": "버드나무 무리 2 · 마른 버드나무"},
	{"kind": "bare_willow", "rect": Rect2i(27, 96, 1, 1), "solid": "tree", "facing": 0, "note": "버드나무 무리 2 · 마른 버드나무"},
	{"kind": "bare_willow", "rect": Rect2i(25, 98, 1, 1), "solid": "tree", "facing": 0, "note": "버드나무 무리 2 · 마른 버드나무"},
	{"kind": "bare_willow", "rect": Rect2i(67, 93, 1, 1), "solid": "tree", "facing": 0, "note": "버드나무 무리 3 · 마른 버드나무"},
	{"kind": "bare_willow", "rect": Rect2i(69, 94, 1, 1), "solid": "tree", "facing": 0, "note": "버드나무 무리 3 · 마른 버드나무"},
	{"kind": "bare_willow", "rect": Rect2i(66, 96, 1, 1), "solid": "tree", "facing": 0, "note": "버드나무 무리 3 · 마른 버드나무"},
	{"kind": "bare_willow", "rect": Rect2i(70, 97, 1, 1), "solid": "tree", "facing": 0, "note": "버드나무 무리 3 · 마른 버드나무"},
	{"kind": "bare_willow", "rect": Rect2i(68, 99, 1, 1), "solid": "tree", "facing": 0, "note": "버드나무 무리 3 · 마른 버드나무"},
	{"kind": "bare_willow", "rect": Rect2i(131, 84, 1, 1), "solid": "tree", "facing": 0, "note": "버드나무 무리 4 · 마른 버드나무"},
	{"kind": "bare_willow", "rect": Rect2i(133, 85, 1, 1), "solid": "tree", "facing": 0, "note": "버드나무 무리 4 · 마른 버드나무"},
	{"kind": "bare_willow", "rect": Rect2i(130, 87, 1, 1), "solid": "tree", "facing": 0, "note": "버드나무 무리 4 · 마른 버드나무"},
	{"kind": "bare_willow", "rect": Rect2i(134, 88, 1, 1), "solid": "tree", "facing": 0, "note": "버드나무 무리 4 · 마른 버드나무"},
	{"kind": "bare_willow", "rect": Rect2i(132, 90, 1, 1), "solid": "tree", "facing": 0, "note": "버드나무 무리 4 · 마른 버드나무"},
	{"kind": "bare_willow", "rect": Rect2i(154, 61, 1, 1), "solid": "tree", "facing": 0, "note": "버드나무 무리 5 · 마른 버드나무"},
	{"kind": "bare_willow", "rect": Rect2i(156, 62, 1, 1), "solid": "tree", "facing": 0, "note": "버드나무 무리 5 · 마른 버드나무"},
	{"kind": "bare_willow", "rect": Rect2i(153, 64, 1, 1), "solid": "tree", "facing": 0, "note": "버드나무 무리 5 · 마른 버드나무"},
	{"kind": "bare_willow", "rect": Rect2i(157, 65, 1, 1), "solid": "tree", "facing": 0, "note": "버드나무 무리 5 · 마른 버드나무"},
	{"kind": "bare_willow", "rect": Rect2i(155, 67, 1, 1), "solid": "tree", "facing": 0, "note": "버드나무 무리 5 · 마른 버드나무"},
	{"kind": "snow_drift", "rect": Rect2i(132, 69, 4, 2), "solid": "none", "facing": 0, "note": "길가 눈 쌓임 · 눈더미"},
	{"kind": "snow_drift", "rect": Rect2i(154, 82, 4, 2), "solid": "none", "facing": 0, "note": "길가 눈 쌓임 · 눈더미"},
	{"kind": "snow_drift", "rect": Rect2i(47, 96, 4, 2), "solid": "none", "facing": 0, "note": "길가 눈 쌓임 · 눈더미"},
	{"kind": "snow_drift", "rect": Rect2i(155, 96, 4, 2), "solid": "none", "facing": 0, "note": "길가 눈 쌓임 · 눈더미"},
	{"kind": "buoy_line", "rect": Rect2i(90, 19, 2, 1), "solid": "none", "facing": 0, "note": "잔교 물자 표시 · 부표 줄"},
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
