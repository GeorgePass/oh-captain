class_name InventoryPanel
extends Control
## What the hull is carrying, down the left edge of the screen.
##
## Drawn rather than assembled from nodes: the grid is a picture of one array,
## not eight places for a count to disagree with the stack it is counting.
## Everything here — hover, click-to-select, drag-to-drop and the counter's sale
## — reads that same array through the same slot geometry, so the hold has no
## second estimate of itself anywhere.
##
## Sized from INV_COLS and INV_ROWS rather than written into the scene, so
## widening the hold later is a change to two numbers and this file does not
## have to be reopened to agree with them.
##
## It lives on its own always-processing layer, above the HUD and above the
## harbour menu. That is what lets it sit open and clickable while the tree is
## paused: alongside, the same selection that routes the name plate here is what
## tells the counter what you are trying to sell.
##
## Selecting is a click; dropping is a drag that ends outside the panel. A drop
## only happens at sea — from the paused menu it would just throw cargo into a
## world that is not moving.

const SLOT := 56.0
const GAP := 6.0
const PAD := 10.0
const TITLE_H := 30.0
## Distance in from the screen edge. Matches the vitals block above it, so the
## left side of the HUD reads as one column rather than two.
const EDGE := 18.0

signal selection_changed(index: int)

var player: Player
## The highlighted slot, or -1 for none. Survives until the panel closes or a
## sale clears it; see set_open.
var selected := -1

var _press_slot := -1


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	_resize()


## Pinned to the left edge and centred vertically. Because both anchors sit on
## the left and on the midline, the offsets are enough: the plate stays where it
## is put and stays centred if the window changes shape.
func _resize() -> void:
	var w := PAD * 2.0 + GameConfig.INV_COLS * SLOT + (GameConfig.INV_COLS - 1) * GAP
	var h := PAD * 2.0 + TITLE_H + GameConfig.INV_ROWS * SLOT + (GameConfig.INV_ROWS - 1) * GAP
	offset_left = EDGE
	offset_right = EDGE + w
	offset_top = -h * 0.5
	offset_bottom = h * 0.5


## The harbour menu opens and closes this with the dock: alongside it is the
## counter's window, at sea it is the captain's. Closing always clears the
## selection, so nothing is ever highlighted for anyone who cannot see it.
func set_open(open: bool) -> void:
	_press_slot = -1
	if open:
		visible = true
	elif visible:
		visible = false
		_set_selected(-1)
	queue_redraw()


## The counter calls this after a sale: the sold slot now belongs to somebody
## else's cargo, so the mark has to move before it points at a stranger.
func clear_selection() -> void:
	_set_selected(-1)


func _process(_delta: float) -> void:
	# Hover ring and name plate both follow the cursor, so the panel redraws
	# every frame the way the radar does. Nothing here changes the simulation.
	if visible:
		queue_redraw()


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if not (event is InputEventMouseButton) or event.button_index != MOUSE_BUTTON_LEFT:
		return
	if event.pressed:
		var idx := _slot_at(get_local_mouse_position())
		if idx >= 0 and _has_stack(idx):
			_press_slot = idx
	else:
		_finish_press()


## A press is resolved where the button comes up, not where it went down, so a
## click and a drag are one gesture read at its end:
##   - released inside the panel — select what is under the pointer, or none;
##   - carried right out of it     — drop that stack over the side.
func _finish_press() -> void:
	var press_slot := _press_slot
	_press_slot = -1
	if press_slot < 0:
		return
	if not Rect2(Vector2.ZERO, size).has_point(get_local_mouse_position()):
		# Dropping is a decision made at sea, never from the paused menu.
		if not get_tree().paused:
			_drop_stack(press_slot)
		return
	var idx := _slot_at(get_local_mouse_position())
	if idx >= 0 and _has_stack(idx):
		# Clicking the selected slot again puts it back.
		_set_selected(-1 if idx == selected else idx)
	else:
		_set_selected(-1)


## Lifts the stack out of the hold and sets it adrift ahead of the bow, with the
## magnet switched off so it stays where it was thrown. Bumping it still
## collects it — the point of the drop is that it no longer comes to you.
func _drop_stack(slot: int) -> void:
	if player == null or not is_instance_valid(player):
		return
	var stack := player.remove_stack_at(slot)
	if stack == null:
		return
	var at := player.global_position + Vector2.RIGHT.rotated(player.rotation) * 72.0
	var dropped := Pickup.spawn(get_tree().get_first_node_in_group(Pickup.GROUP), at)
	if dropped != null:
		dropped.kind = Pickup.Kind.ITEM
		dropped.item_id = stack.id
		dropped.amount = stack.count
		dropped.attracted = false
		dropped.scatter()
		AudioDirector.play(get_tree(), &"item", GameConfig.VOL_GOLD)
	_set_selected(-1)


func _set_selected(index: int) -> void:
	if selected == index:
		return
	selected = index
	selection_changed.emit(index)
	queue_redraw()


func _has_stack(index: int) -> bool:
	return player != null and is_instance_valid(player) and index < player.cargo.size()


func _slot_rect(index: int) -> Rect2:
	var row := index / GameConfig.INV_COLS
	var col := index % GameConfig.INV_COLS
	var origin := Vector2(
		PAD + col * (SLOT + GAP),
		PAD + TITLE_H + row * (SLOT + GAP))
	return Rect2(origin, Vector2(SLOT, SLOT))


func _slot_at(pos: Vector2) -> int:
	var index := 0
	for row in GameConfig.INV_ROWS:
		for col in GameConfig.INV_COLS:
			if _slot_rect(index).has_point(pos):
				return index
			index += 1
	return -1


func _draw() -> void:
	var font := ThemeDB.fallback_font

	# Backing plate, so the grid reads as a panel on the screen rather than as
	# eight rectangles floating over open water.
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.03, 0.07, 0.10, 0.86))
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.35, 0.62, 0.70, 0.50), false, 1.5)
	draw_string(font, Vector2(PAD, PAD + 17.0), "CARGO",
		HORIZONTAL_ALIGNMENT_LEFT, -1.0, 16, Color(0.70, 0.86, 0.92))

	var cargo: Array[Item.Stack] = []
	if player != null and is_instance_valid(player):
		cargo = player.cargo

	var index := 0
	for row in GameConfig.INV_ROWS:
		for col in GameConfig.INV_COLS:
			_draw_slot(font, _slot_rect(index).position, index, cargo)
			index += 1

	_draw_marks(cargo)
	_draw_tooltip(font, cargo)


## Hover lies under the cursor ring and the name plate, so the three read as one
## answer; the selected slot is drawn bright so the counter's price label and the
## hold agree on what is being sold.
func _draw_marks(cargo: Array[Item.Stack]) -> void:
	var hover := _slot_at(get_local_mouse_position())
	for index in cargo.size():
		if not _has_stack(index):
			continue
		var rect := _slot_rect(index)
		if index == selected:
			draw_rect(rect, Color(1.0, 0.84, 0.42, 0.14))
			draw_rect(rect, Color(1.0, 0.84, 0.42, 0.95), false, 2.0)
		elif index == hover:
			draw_rect(rect, Color(0.9, 0.97, 1.0, 0.08))
			draw_rect(rect, Color(0.62, 0.86, 0.94, 0.9), false, 1.8)


## Name, count and counter value in a small plate pinned inside the panel next
## to the cursor. At sea this is a reminder of what you are carrying; alongside
## it is exactly what the Sell button is about to part you from.
func _draw_tooltip(font: Font, cargo: Array[Item.Stack]) -> void:
	var cursor := get_local_mouse_position()
	var index := _slot_at(cursor)
	if index < 0 or index >= cargo.size():
		return
	var stack := cargo[index]
	var def := Item.get_def(stack.id)
	var box := Rect2(cursor + Vector2(12.0, 10.0), Vector2(116.0, 38.0))
	box.position.x = clampf(box.position.x, PAD, size.x - PAD - box.size.x)
	box.position.y = clampf(box.position.y, PAD + TITLE_H, size.y - PAD - box.size.y)
	draw_rect(box, Color(0.02, 0.10, 0.14, 0.95))
	draw_rect(box, Color(0.45, 0.72, 0.80, 0.7), false, 1.2)
	draw_string(font, box.position + Vector2(6.0, 15.0),
		"%s  x%d" % [def.name.to_upper(), stack.count],
		HORIZONTAL_ALIGNMENT_LEFT, -1.0, 13, Color(0.8, 0.9, 0.95))
	draw_string(font, box.position + Vector2(6.0, 30.0),
		"sells for  %d g" % (def.value * stack.count),
		HORIZONTAL_ALIGNMENT_LEFT, -1.0, 12, Color(1.0, 0.85, 0.5))


func _draw_slot(font: Font, origin: Vector2, index: int, cargo: Array[Item.Stack]) -> void:
	var rect := Rect2(origin, Vector2(SLOT, SLOT))
	draw_rect(rect, Color(0.10, 0.16, 0.20, 0.92))
	draw_rect(rect, Color(0.30, 0.48, 0.55, 0.55), false, 1.5)
	if index >= cargo.size():
		return

	var stack := cargo[index]
	var def := Item.get_def(stack.id)
	# The disc sits up and left so the count has the far corner to itself, and
	# both are drawn in the colour the pickup uses in the water: the thing you
	# swam over and the thing you are holding should not need translating.
	var disc := origin + Vector2(SLOT, SLOT) * 0.5 + Vector2(-5.0, -4.0)
	draw_circle(disc, 15.0, def.color)
	draw_arc(disc, 15.0, 0.0, TAU, 24, def.color.darkened(0.45), 1.6, true)
	draw_string(font, origin + Vector2(4.0, SLOT - 6.0), str(stack.count),
		HORIZONTAL_ALIGNMENT_RIGHT, SLOT - 8.0, 14, Color(1.0, 1.0, 1.0, 0.92))
