class_name InventoryPanel
extends Control
## What the hull is carrying, down the left edge of the screen.
##
## Drawn rather than assembled from nodes. There is nothing here to click, so a
## GridContainer full of Panels and Labels would be eight more places for a
## count to disagree with the stack it is counting — and the whole point of the
## grid is that it is a picture of one array.
##
## Sized from INV_COLS and INV_ROWS rather than written into the scene, so
## widening the hold later is a change to two numbers and this file does not
## have to be reopened to agree with them.
##
## Opening it costs nothing and stops nothing: the water keeps moving, the tank
## keeps emptying, and reading your cargo is a decision made under the same
## clock as every other one. Only the harbour holds the world still.

const SLOT := 56.0
const GAP := 6.0
const PAD := 10.0
const TITLE_H := 30.0
## Distance in from the screen edge. Matches the vitals block above it, so the
## left side of the HUD reads as one column rather than two.
const EDGE := 18.0

var player: Player


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
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
			var origin := Vector2(
				PAD + col * (SLOT + GAP),
				PAD + TITLE_H + row * (SLOT + GAP))
			_draw_slot(font, origin, index, cargo)
			index += 1


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
