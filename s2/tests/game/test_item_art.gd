extends "res://addons/gut/test.gd"
## 얻을 수 있는 물건마다 제 그림(사용자 2026-11-06 23시 「얻을 수 있는 것들 아이콘 굽는 거는 … 전부」,
## 코디 전달): 파밍 창이 그림을 찾는 차례(inventory_pane.art_name)로 물건마다 그림을 정하면, 일부러 같이
## 쓰는 짝(SHARED) 말고는 두 물건이 한 그림을 쓰지 않고, 그림 없는 물건은 필드에서 안 나오는 것(NO_ART)
## 뿐이다. 별칭은 쓰이는 것만, 그림 파일은 어떤 물건이 쓰는 것만 둔다(옛 그림 정리).

const InventoryPane = preload("res://game/ui/inventory_pane.gd")
const FieldItems = preload("res://game/sim/field_items.gd")
const Wear = preload("res://game/sim/wear.gd")
const Carry = preload("res://game/sim/carry.gd")
const Weapons = preload("res://game/sim/weapons.gd")
const FieldGame = preload("res://game/field_game.gd")

## Things that show one picture on purpose: the same thing to the eye.
const SHARED: Dictionary = {
	"can_dented": ["can_dented", "can_dented_bad"],   # a can that is off looks as the dented one
	"note_map": ["note_map", "note_side"],            # both are 「쪽지」
	"clock": ["wrist_watch", "wrist_watch_set"],      # a wrist watch, one with its alarm set
}
## Things with no picture: no table, map or bundle of the field hands them out (11-07 count).
const NO_ART: Array[String] = ["ammo_box", "tourniquet"]
## A house key of the field's, standing for every key number.
const KEY: String = FieldItems.KEY_PREFIX + "1"

## Every thing the game names, by its line icon (field_game.item_icon).
var things: Dictionary = {}
## Each thing's picture name (InventoryPane.art_name).
var art: Dictionary = {}


func before_all() -> void:
	var game = FieldGame.new()
	for table: Dictionary in [FieldItems.ITEMS, FieldItems.RARE, Wear.KINDS, Carry.ITEM_NAMES, Weapons.DATA, FieldGame.BUNDLE_ICONS]:
		for id: String in table:
			things[id] = String(game.item_icon(id))
	# A house's key (결정 423 P12): every number is the same key to the eye, so one stands for all.
	things[KEY] = String(game.item_icon(KEY))
	game.free()
	for id: String in things:
		art[id] = InventoryPane.art_name(id, things[id])


func test_the_count_is_the_game_s() -> void:
	assert_gt(things.size(), 140, "the tables the field draws its things from")
	for id: String in Wear.KINDS:
		assert_true(things.has(id), id)


func test_every_thing_found_in_the_field_has_a_picture() -> void:
	for id: String in things:
		if NO_ART.has(id):
			assert_eq(art[id], "", id + " still has none: take it off NO_ART once it can be found")
			continue
		assert_ne(art[id], "", id + " has a picture")
		assert_not_null(InventoryPane.art_texture(id, things[id]), id + " loads")


func test_no_two_things_share_a_picture_but_the_listed_pairs() -> void:
	var by_picture: Dictionary = {}
	for id: String in things:
		if art[id] == "":
			continue
		if not by_picture.has(art[id]):
			by_picture[art[id]] = []
		(by_picture[art[id]] as Array).append(id)
	for picture: String in by_picture:
		var ids: Array = by_picture[picture]
		ids.sort()
		if ids.size() > 1:
			var listed: Array = (SHARED.get(picture, []) as Array).duplicate()
			listed.sort()
			assert_eq(ids, listed, picture + " is shown by " + ", ".join(ids))
	for picture: String in SHARED:
		for id: String in SHARED[picture]:
			assert_eq(art.get(id, ""), picture, id + " shows " + picture)


func test_a_house_key_has_the_key_picture() -> void:
	assert_true(FieldItems.is_key(KEY))
	assert_eq(art[KEY], "it_key", "every key shows the one key picture, not a line icon")


func test_every_clothing_thing_has_its_own_picture() -> void:
	for id: String in Wear.KINDS:
		assert_eq(art[id], id, id + " is drawn as itself, not as its kind")


func test_every_alias_is_still_used() -> void:
	for id: String in InventoryPane.ART_ALIAS:
		assert_eq(art.get(id, ""), String(InventoryPane.ART_ALIAS[id]), id + "'s alias is what shows it")
	for icon: String in InventoryPane.ICON_ALIAS:
		var used: bool = false
		for id: String in things:
			if things[id] == icon and art[id] == String(InventoryPane.ICON_ALIAS[icon]) and not InventoryPane.ART_ALIAS.has(id) and art[id] != id:
				used = true
		assert_true(used, icon + "'s alias shows some thing")


func test_every_picture_file_shows_some_thing() -> void:
	var shown: Dictionary = {}
	for id: String in art:
		shown[art[id]] = true
	var dir := DirAccess.open("res://assets/icons/items")
	assert_not_null(dir)
	if dir == null:
		return
	var files: int = 0
	for file: String in dir.get_files():
		if not file.ends_with(".png"):
			continue
		files += 1
		assert_true(shown.has(file.get_basename()), file + " is shown by a thing (else it is an old picture to clear)")
	assert_gt(files, 140)
