class_name Item
extends RefCounted
## One definition per thing that can be picked up, and the only place it is
## written down.
##
## Mirrors Species for the same reason Species exists: the name, the stack limit
## and the colour are each needed by three different readers — the hull that
## carries it, the pickup that drops it, and the panel that draws it — and three
## copies of a number is how two of them end up disagreeing later.

## Ids live here rather than in GameConfig, so the numbering and the table built
## from it sit in one file. `get_def` indexes by id, which only holds while the
## two stay in step; the comment below is the whole mechanism.
const FISH_MEAT := 0
const CRAB_MEAT := 1
const CRAB_SHELL := 2
## The harbourmaster's crate, used for two errands: the one you carry out to
## the outpost, and the one you recover from the wreck. Value zero on purpose:
## it is errand cargo, never merchandise, so the counter refuses to sell it.
const CARGO_CRATE := 3


## One kind of cargo.
class Def extends RefCounted:
	var id: int
	var name: String
	## How many one slot will hold. One means it never stacks.
	var stack: int
	## Used both for the pickup in the water and the disc in the hold, so the
	## thing you swim over is recognisably the thing you already have.
	var color: Color
	## What one unit sells for at the harbour counter. The shop shows this
	## number, and a highlighted stack is worth value * count.
	var value := 0

	func _init(id_: int = 0, name_: String = "", stack_: int = 1, color_: Color = Color.WHITE,
			value_: int = 0) -> void:
		id = id_
		name = name_
		stack = stack_
		color = color_
		value = value_


## One stack sitting in one slot. A real type rather than a pair of numbers,
## because every reader below would otherwise be remembering which of the two
## was the count.
class Stack extends RefCounted:
	var id: int
	var count := 1

	func _init(id_: int = 0, count_: int = 1) -> void:
		id = id_
		count = count_


static var DEFS: Array[Def] = []


static func _static_init() -> void:
	# Index is the id.
	DEFS = [
		Def.new(FISH_MEAT, "Fish Meat", 5, Color(0.86, 0.62, 0.55), 5),
		Def.new(CRAB_MEAT, "Crab Meat", 3, Color(0.88, 0.44, 0.36), 20),
		Def.new(CRAB_SHELL, "Crab Shell", 1, Color(0.58, 0.80, 0.74), 50),
		Def.new(CARGO_CRATE, "Cargo Crate", 1, Color(0.72, 0.60, 0.40), 0),
	]


static func get_def(id: int) -> Def:
	return DEFS[id]
