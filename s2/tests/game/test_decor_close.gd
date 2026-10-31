extends GutTest
## Closing the decorating view (slice_flow.leave_decor) does less work than it used to: the closing
## pane is not laid out again and the folded paper is not refilled under the fold. What the player
## ends up with must be the same: the same rules, the same cars, the same pane and paper.

const SliceFlow = preload("res://game/slice_flow.gd")
const TrainDecor = preload("res://game/train/train_decor.gd")
const Dom = preload("res://game/train/train_dom.gd")
const Mods = preload("res://game/train/train_mods.gd")
const TurnCard = preload("res://game/ui/turn_card.gd")


func _flow() -> Node:
	var f = SliceFlow.new()
	f.opts = {"skip_field": true, "cinema": false, "seed": 7}
	add_child_autofree(f)
	await get_tree().process_frame
	f.train_g["dom"] = Dom.start()
	var store: Dictionary = TrainDecor.read_store(f.train_g)
	for kind: String in ["chair", "table"]:
		TrainDecor.add_stored(store, kind)
	f._select("guard", false)
	f.train_g["phase"] = "travel"
	f.paper.set_folded(true)
	assert_true(f.open_decor("guard"), "decorating opens")
	for kind: String in ["chair", "table"]:
		assert_true(Mods.place(f.train_g, "guard", kind, "floor")["ok"], kind + " placed")
	return f


## The close as it was before this change, step for step.
func _old_close(f) -> void:
	var id: String = f.decor_id
	f.decor_id = ""
	f.decor_pane.cancel_drag()
	f.decor_pane.hide()
	f.decor_pane.queue_free()
	f.decor_pane = null
	f.train.exit_decor()
	f._sync_decor_situation()
	var stages: Dictionary = f._home_of(f.train_g)
	if stages != (f.train.rules["train"] as Dictionary).get("home", {}):
		f.train.rules["train"]["home"] = stages
		f.train.apply_rules()
	for n in f._decor_hidden:
		if is_instance_valid(n):
			(n as CanvasItem).visible = true
	f._decor_hidden.clear()
	f.paper.g = f.train_g
	f.paper._fill()
	f._select(id, false)


func _texts(node: Node, out: Array) -> Array:
	if node is Label or node is Button:
		out.append(String(node.get("text")))
	elif node is RichTextLabel:
		out.append((node as RichTextLabel).get_parsed_text())
	for child: Node in node.get_children():
		_texts(child, out)
	return out


## What the player sees and what the rules hold after the close and one settled frame,
## then with the paper unfolded.
func _snapshot(f) -> Dictionary:
	var cars: Dictionary = {}
	for c: Dictionary in f.train.cars:
		cars[String(c["id"])] = [int(c.get("home_stage", -1)), float(c.get("stove_share", -1.0)),
			(c["lamp"] as OmniLight3D).omni_range if c.get("lamp") is OmniLight3D else -1.0]
	var snap: Dictionary = {
		"rules": f.train.rules.duplicate(true),
		"cars": cars,
		"sel": String(f.sel),
		"decor_id": String(f.decor_id),
		"pane_visible": bool(f.pane.visible),
		"pane": _texts(f.pane, []),
		"paper_folded": bool((f.paper as TurnCard).folded),
	}
	f.paper.set_folded(false)
	snap["paper"] = _texts(f.paper, [])
	return snap


func test_the_lighter_close_leaves_the_same_train_pane_and_paper() -> void:
	var old_flow = await _flow()
	_old_close(old_flow)
	await get_tree().process_frame
	var before: Dictionary = _snapshot(old_flow)
	old_flow.queue_free()
	await get_tree().process_frame
	var new_flow = await _flow()
	new_flow.leave_decor()
	await get_tree().process_frame
	var after: Dictionary = _snapshot(new_flow)
	assert_eq(int(after["cars"]["guard"][0]), 1, "the guard car shows its first stage")
	assert_eq(after["decor_id"], "", "decorating is closed")
	assert_true(after["paper_folded"], "the paper stays folded on closing")
	for key: String in ["rules", "cars", "sel", "decor_id", "pane_visible", "pane", "paper_folded", "paper"]:
		assert_eq(after[key], before[key], key + ": the same as the old close")
	assert_gt((after["paper"] as Array).size(), 0, "the unfolded paper has its lines")


## Unfolding after the close shows the paper refilled with what decorating changed.
func test_the_paper_unfolded_after_closing_matches_a_fresh_fill() -> void:
	var f = await _flow()
	f.leave_decor()
	await get_tree().process_frame
	f.paper.set_folded(false)
	var shown: Array = _texts(f.paper, [])
	f.paper._fill()
	assert_eq(_texts(f.paper, []), shown, "unfolding refilled the paper")


## The closing pane is let go and freed (its drag goes with it; the decor view's hover goes
## with the decor view, train_scene.gd decor_hover acts only while decorating).
func test_closing_lets_the_pane_go() -> void:
	var f = await _flow()
	var pane = f.decor_pane
	assert_true(is_instance_valid(pane), "the decor pane is open")
	f.leave_decor()
	assert_null(f.decor_pane, "the pane is let go")
	assert_eq(String(f.decor_id), "", "decorating is closed")
	await get_tree().process_frame
	assert_false(is_instance_valid(pane), "the pane is freed")
