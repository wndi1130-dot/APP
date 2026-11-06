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
const FieldMaps = preload("res://game/world/field_maps.gd")
const LootDress = preload("res://game/sim/loot_dress.gd")

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
const ART_DIR: String = "res://assets/icons/items"
## Two pictures nearer than NEAR_LIMIT (mean difference per channel, 0–255) once
## both are shrunk to NEAR_SIDE square are one picture to the eye. The nearest
## two meant apart, the blueprint pieces that differ only in their stamp, were
## about 1.6 apart on 11-07; a second bake of one model under two names is ~0.
const NEAR_SIDE: int = 32
const NEAR_LIMIT: float = 0.5
## Things a map hands out that no table names yet (so no name, weight or picture):
## church_04's yard coal sack gives "coal" (11-07, sent to 코디 — what it should
## become is a rule to set, not this test's). Each must still be handed out: once
## it is set right, take it off here.
const KNOWN_GAPS: Array[String] = ["coal"]
const DRESS_SEED: int = 1107

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


func test_the_things_without_a_picture_are_things() -> void:
	for id: String in NO_ART:
		assert_true(things.has(id), id + " is still a thing (else take it off NO_ART)")


## The tables above are the field's whole stock: every map, built and dressed
## as a stop is (its boxes, the parts to tear off, the cores), hands out only
## things they name — and none of NO_ART, so those stay out of the field.
## (11-07 read of every other way a thing is made — bodies, loose finds, the
## departure kit — found them all inside the tables too.) Building every map is
## slow, as in test_all_maps_open: about a minute and a half on CI.
func test_every_map_built_and_dressed_hands_out_only_known_things() -> void:
	var found: Dictionary = {}   # id -> the first map it is in
	var maps: int = 0
	for place: String in FieldMaps.all_ids():
		var data: Dictionary = FieldMaps.build(place)
		assert_false(data.is_empty(), place + " builds")
		if data.is_empty():
			continue
		maps += 1
		LootDress.dress(data, DRESS_SEED)
		for box: String in data.get("containers", {}):
			for entry: Variant in (data["containers"][box] as Dictionary).get("items", []):
				var id: String = _handed_out(entry)
				if id != "" and not found.has(id):
					found[id] = place
		for spot_id: String in data.get("spots", {}):
			var spot: Dictionary = data["spots"][spot_id]
			for key: String in ["material", "item"]:
				var id: String = String(spot.get(key, ""))
				if id != "" and not found.has(id):
					found[id] = place
	assert_eq(maps, FieldMaps.all_ids().size(), "every map built")
	assert_gt(found.size(), 80, "the maps hand out a field's worth of things (90 kinds on 11-07)")
	for id: String in found:
		if KNOWN_GAPS.has(id):
			continue
		var known: bool = things.has(id) or FieldItems.has(id)
		assert_true(known, "%s (in %s) is named by no table: no name, weight or picture" % [id, found[id]])
		assert_false(NO_ART.has(id), "%s (in %s) is handed out: give it a picture and take it off NO_ART" % [id, found[id]])
	for id: String in KNOWN_GAPS:
		assert_true(found.has(id), id + " is no longer handed out as it was: take it off KNOWN_GAPS")
		assert_false(things.has(id), id + " is named now: take it off KNOWN_GAPS")


## A box's entry as the thing it hands over: an id, or a thing written out
## ({"id": …} for clothes and hand weapons); "" for rounds that go straight to
## the ammo pool ({"ammo": kind}).
func _handed_out(entry: Variant) -> String:
	if entry is String or entry is StringName:
		return String(entry)
	if entry is Dictionary:
		if (entry as Dictionary).has("ammo"):
			return ""
		return String((entry as Dictionary).get("id", "<entry without an id>"))
	return "<entry of type %s>" % type_string(typeof(entry))


## By what is drawn, not by name: no two files hold the same pixels (SHARED
## pairs share one file, so there are no exceptions here).
func test_no_two_picture_files_hold_the_same_pixels() -> void:
	var pictures: Dictionary = _pictures()
	var seen: Dictionary = {}
	for name: String in pictures:
		var image: Image = pictures[name]
		var digest := HashingContext.new()
		digest.start(HashingContext.HASH_SHA256)
		digest.update(image.get_data())
		var key: String = "%dx%d:%s" % [image.get_width(), image.get_height(), digest.finish().hex_encode()]
		if seen.has(key):
			fail_test(name + ".png holds the same pixels as " + String(seen[key]) + ".png")
		seen[key] = name
	assert_gt(seen.size(), 140, "every picture read")


## Nor two that only differ by a hair: shrunk to a few dozen pixels a side, as
## near as the pane's small square, each pair stays NEAR_LIMIT apart.
func test_no_two_pictures_are_near_copies() -> void:
	var pictures: Dictionary = _pictures()
	var names: Array = pictures.keys()
	names.sort()
	var small: Array[Image] = []
	for name: String in names:
		var copy: Image = (pictures[name] as Image).duplicate()
		copy.resize(NEAR_SIDE, NEAR_SIDE, Image.INTERPOLATE_BILINEAR)
		small.append(copy)
	var nearest: float = INF
	var nearest_pair: String = ""
	for i: int in names.size():
		for j: int in range(i + 1, names.size()):
			var metrics: Dictionary = small[i].compute_image_metrics(small[j], false)
			var mean: float = float(metrics.get("mean", -1.0))
			assert_true(mean >= 0.0, "%s / %s compare" % [names[i], names[j]])
			if mean >= 0.0 and mean < nearest:
				nearest = mean
				nearest_pair = "%s / %s" % [names[i], names[j]]
			if mean >= 0.0 and mean < NEAR_LIMIT:
				fail_test("%s and %s are %.2f apart: one picture to the eye" % [names[i], names[j], mean])
	gut.p("nearest two pictures: %s, %.2f apart" % [nearest_pair, nearest])
	assert_gt(names.size(), 140, "every picture compared")


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
	var dir := DirAccess.open(ART_DIR)
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


## Every picture file as it was baked: the PNG's own pixels in RGBA8, by name
## (not the imported texture, which may be compressed).
func _pictures() -> Dictionary:
	var pictures: Dictionary = {}
	for file: String in DirAccess.get_files_at(ART_DIR):
		if not file.ends_with(".png"):
			continue
		var image := Image.new()
		var error: Error = image.load_png_from_buffer(FileAccess.get_file_as_bytes(ART_DIR.path_join(file)))
		assert_eq(error, OK, file + " reads as a PNG")
		if error != OK or image.is_empty():
			continue
		image.convert(Image.FORMAT_RGBA8)
		pictures[file.get_basename()] = image
	return pictures
