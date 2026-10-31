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


## The first line on the paper's body, to mark as stale.
func _body_label(paper) -> Label:
	var labels: Array = paper.body.find_children("*", "Label", true, false)
	for l: Label in labels:
		if l.text != "":
			return l
	return null


## The folded paper is not refilled on closing, and unfolding it refills and shows it: a line
## marked stale while decorating stays under the fold and is gone once the paper opens.
func test_the_folded_paper_is_refilled_on_unfolding_not_on_closing() -> void:
	var f = await _flow()
	var stale: Label = _body_label(f.paper)
	assert_not_null(stale, "the paper has a line to mark")
	stale.text = "STALE"
	f.leave_decor()
	await get_tree().process_frame
	assert_true((f.paper as TurnCard).folded, "the paper stays folded")
	assert_has(_texts(f.paper.body, []), "STALE", "closing left the folded paper as it was")
	f.paper.set_folded(false)
	assert_does_not_have(_texts(f.paper.body, []), "STALE", "unfolding refilled the paper")
	for _i: int in 30:
		if f.paper.sheet.modulate.a >= 1.0:
			break
		await get_tree().process_frame
	assert_true(f.paper.sheet.visible and f.paper.sheet.inner.visible, "the unfolded paper shows")
	assert_eq(f.paper.sheet.modulate.a, 1.0, "the refilled paper settles in sight")
	var shown: Array = _texts(f.paper, [])
	f.paper._fill()
	assert_eq(_texts(f.paper, []), shown, "the unfolded paper matches a fresh fill")


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


## Closed mid-drag: the pane is not laid out again (its drag is left to go with it), and the
## green place under the held thing goes with the decor view, nothing of it left in the train.
func test_closing_mid_drag_leaves_nothing_in_the_train() -> void:
	var f = await _flow()
	var pane = f.decor_pane
	pane.dragging = true
	pane.drag_kind = "chair"
	f.train.decor_hover("floor", [0, 0], true)
	var cursor: Node3D = f.train.decor.cursor
	assert_true(cursor.visible, "the place under the held thing shows")
	f.leave_decor()
	assert_true(pane.dragging, "the closing pane is not stopped and laid out again")
	assert_eq(f.train.decorating(), "", "the train left decorating")
	assert_false(cursor.is_inside_tree() and cursor.visible, "no green place left in the train")
	await get_tree().process_frame
	assert_false(is_instance_valid(pane), "the pane is freed with its drag")
	assert_eq(f.train.find_children("DecorCursor", "", true, false).size(), 0, "no place mark left in the train")


## The train closing decorating on its own (its layout rebuilt) closes the pane on the next frame.
func test_the_train_closing_decorating_closes_the_pane() -> void:
	var f = await _flow()
	var pane = f.decor_pane
	f.train.exit_decor()
	assert_eq(String(f.decor_id), "guard", "the pane follows on the next frame")
	await get_tree().process_frame
	assert_eq(String(f.decor_id), "", "decorating is closed")
	assert_null(f.decor_pane, "the pane is let go")
	await get_tree().process_frame
	assert_false(is_instance_valid(pane), "the pane is freed")
	assert_true((f.paper as TurnCard).folded, "the paper stays folded")
