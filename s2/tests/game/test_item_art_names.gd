extends "res://addons/gut/test.gd"

const ItemArt = preload("res://game/ui/item_art.gd")
const InventoryPane = preload("res://game/ui/inventory_pane.gd")


func test_candidates_keep_the_panes_priority() -> void:
	assert_eq(ItemArt.candidates("note_side", "book"), ["note_side", "note_map", "herbal_book", "book"])
	assert_eq(ItemArt.candidates("can_dented_bad", "it_can"), ["can_dented_bad", "can_dented", "it_can"])
	assert_eq(InventoryPane.ART_ALIAS, ItemArt.ART_ALIAS)
	assert_eq(InventoryPane.ICON_ALIAS, ItemArt.ICON_ALIAS)


func test_empty_and_repeated_names_are_removed_in_order() -> void:
	assert_eq(ItemArt.candidates("", ""), [])
	assert_eq(ItemArt.candidates("", "book"), ["herbal_book", "book"])
	assert_eq(ItemArt.candidates("book", "book"), ["book", "herbal_book"])
	assert_eq(ItemArt.candidates("note_side", "note_map"), ["note_side", "note_map"])
	assert_eq(ItemArt.candidates("knife", ""), ["knife"])


func test_art_name_is_the_first_existing_candidate() -> void:
	for pair: Array in [["note_side", "book"], ["can_dented_bad", "it_can"], ["", ""], ["missing_ground_art", "book"], ["knife", "knife"]]:
		var expected: String = ""
		for candidate: String in ItemArt.candidates(pair[0], pair[1]):
			if ResourceLoader.exists(InventoryPane.ART_PATH % candidate):
				expected = candidate
				break
		assert_eq(InventoryPane.art_name(pair[0], pair[1]), expected, str(pair))
