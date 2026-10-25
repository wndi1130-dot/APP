extends RefCounted
## 소품 종류와 그리기 대체표. 칸의 solid나 지도 자료는 바꾸지 않는다.

const STOP_DIR := "res://models/props_stop01/"
const COMMON_DIR := "res://models/props_common/"
## 지도 조립 소품(종류 이름 = 파일 이름). 파일이 있을 때만 쓴다. preload하지 않는다.
const FIELD_DIR := "res://models/props_field/"

## 첫 정차의 같은 이름 26종, 뜻이 가까운 가구, 아직 모델이 없는 종류.
## 빈 경로는 low 덩이 또는 기존 비표시로 돌아간다는 뜻이다.
const MODELS: Dictionary = {
	"arrow_set": STOP_DIR + "arrow_set.glb",
	"bookcase": STOP_DIR + "bookcase.glb",
	"canvas_windbreak": STOP_DIR + "canvas_windbreak.glb",
	"chopping_block": STOP_DIR + "chopping_block.glb",
	"concrete_barrier": STOP_DIR + "concrete_barrier.glb",
	"crt_monitor": STOP_DIR + "crt_monitor.glb",
	"dining_set": STOP_DIR + "dining_set.glb",
	"drawer_chest_spilled": STOP_DIR + "drawer_chest_spilled.glb",
	"folding_workbench": STOP_DIR + "folding_workbench.glb",
	"garden_wall": STOP_DIR + "garden_wall.glb",
	"hand_basket": STOP_DIR + "hand_basket.glb",
	"iron_bed": STOP_DIR + "iron_bed.glb",
	"kitchen_knife": STOP_DIR + "kitchen_knife.glb",
	"machete": STOP_DIR + "machete.glb",
	"mine_track": STOP_DIR + "mine_track.glb",
	"office_desk": STOP_DIR + "office_desk.glb",
	"plank_barricade": STOP_DIR + "plank_barricade.glb",
	"scattered_tools": STOP_DIR + "scattered_tools.glb",
	"shop_shelf": STOP_DIR + "shop_shelf.glb",
	"sleeper_fence": STOP_DIR + "sleeper_fence.glb",
	"table_overturned": STOP_DIR + "table_overturned.glb",
	"tiled_stove": STOP_DIR + "tiled_stove.glb",
	"toolbox": STOP_DIR + "toolbox.glb",
	"wardrobe": STOP_DIR + "wardrobe.glb",
	"workbench": STOP_DIR + "workbench.glb",
	"yard_gate": STOP_DIR + "yard_gate.glb",
	# 가구의 쓰임을 유지하는 대체: 선반, 책상, 침대, 식은 난로.
	"shelf": STOP_DIR + "shop_shelf.glb",
	"desk": STOP_DIR + "office_desk.glb",
	"bed": STOP_DIR + "iron_bed.glb",
	"cold_stove": STOP_DIR + "tiled_stove.glb",
	# 자료에서 확인한 진열 선반, 작업대, 타자기 책상, 항아리 선반.
	"display_shelf": STOP_DIR + "shop_shelf.glb",
	"tool_bench": STOP_DIR + "workbench.glb",
	"typewriter_desk": STOP_DIR + "office_desk.glb",
	"jar_shelf": STOP_DIR + "shop_shelf.glb",
	"file_cabinet": STOP_DIR + "bookcase.glb", # 서류를 담는 가구
	"tool_chest": STOP_DIR + "toolbox.glb", # 공구 수납
	# 맞는 첫 정차 모델이 없으면 공용 모델이 들어올 때까지 기존 표시.
	"barrel": "", "bare_tree": "", "crate_stack": "", "sack_pile": "",
	"part_crate": "", "handcart": "", "blanket_chest": "", "fridge_open": "",
	"iv_stand": "", "paper_cart": "", "oxygen_cylinder": "", "pallet_stack": "",
	"dresser": "", "chair": "", "nightstand": "", "counter": "", "sink": "", "cupboard": "",
	"settee": "", "armchair": "", "low_table": "", "side_table": "",
	"toilet": "", "washstand": "", "bathtub": "", "towel_shelf": "", "small_shelf": "",
}

## 새 방 가구의 기본 바닥 크기. 모델은 별도 제작하며 경로는 비워 둔다.
const ROOM_SIZES: Dictionary = {
	"dresser": Vector2i(2, 1), "chair": Vector2i(1, 1), "nightstand": Vector2i(1, 1),
	"counter": Vector2i(1, 1), "sink": Vector2i(1, 1), "cupboard": Vector2i(1, 1),
	"settee": Vector2i(2, 1), "armchair": Vector2i(1, 1), "low_table": Vector2i(1, 1),
	"side_table": Vector2i(1, 1), "toilet": Vector2i(1, 1), "washstand": Vector2i(1, 1),
	"bathtub": Vector2i(2, 1), "towel_shelf": Vector2i(1, 1), "small_shelf": Vector2i(1, 1),
}

## 상위 20종은 공용 파일이 실제로 있을 때만 우선한다. preload하지 않는다.
const COMMON_MODELS: Dictionary = {
	"shelf": COMMON_DIR + "shelf.glb",
	"cold_stove": COMMON_DIR + "cold_stove.glb",
	"desk": COMMON_DIR + "desk.glb",
	"barrel": COMMON_DIR + "barrel.glb",
	"bed": COMMON_DIR + "bed.glb",
	"bare_tree": COMMON_DIR + "bare_tree.glb",
	"crate_stack": COMMON_DIR + "crate_stack.glb",
	"sack_pile": COMMON_DIR + "sack_pile.glb",
	"file_cabinet": COMMON_DIR + "file_cabinet.glb",
	"part_crate": COMMON_DIR + "part_crate.glb",
	"handcart": COMMON_DIR + "handcart.glb",
	"wardrobe": COMMON_DIR + "wardrobe.glb",
	"blanket_chest": COMMON_DIR + "blanket_chest.glb",
	"fridge_open": COMMON_DIR + "fridge_open.glb",
	"iv_stand": COMMON_DIR + "iv_stand.glb",
	"workbench": COMMON_DIR + "workbench.glb",
	"tool_chest": COMMON_DIR + "tool_chest.glb",
	"paper_cart": COMMON_DIR + "paper_cart.glb",
	"oxygen_cylinder": COMMON_DIR + "oxygen_cylinder.glb",
	"pallet_stack": COMMON_DIR + "pallet_stack.glb",
}


static func candidates(kind: String) -> Array[String]:
	var paths: Array[String] = []
	if COMMON_MODELS.has(kind):
		paths.append(COMMON_MODELS[kind])
	if MODELS.has(kind) and not String(MODELS[kind]).is_empty():
		paths.append(MODELS[kind])
	paths.append(FIELD_DIR + kind + ".glb")
	return paths


static func model_path(kind: String) -> String:
	for path in candidates(kind):
		if ResourceLoader.exists(path):
			return path
	return ""


static func fallback_for(solid: String) -> String:
	return "low" if solid == "low" else "hidden"
