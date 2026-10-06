class_name HarborScreen
extends CanvasLayer
## The harbour menu: the counter, and the way back out.
##
## It sits on its own layer above the HUD with process_mode ALWAYS, so it keeps
## taking input while the tree is paused — which is the entire point of docking,
## and the reason the dock key is handled here rather than on the harbour node.
##
## The counter sells torpedoes and hull plating and buys whatever stack the
## cargo panel has highlighted; the panel sits on its own always-live layer to
## the left, so the same click that selects a stack out there is the click that
## tells this menu what you are trying to sell. Missions are still to come.

signal dock_toggled

@onready var stats: Label = $Panel/Box/Stats
@onready var torpedo_label: Label = $Panel/Box/TorpedoRow/TorpedoLabel
@onready var repair_label: Label = $Panel/Box/RepairRow/RepairLabel
@onready var buy_torpedo: Button = $Panel/Box/TorpedoRow/BuyTorpedo
@onready var buy_repair: Button = $Panel/Box/RepairRow/BuyRepair
@onready var sel_label: Label = $Panel/Box/SalesRow/SelLabel
@onready var sell_button: Button = $Panel/Box/SalesRow/SellButton
@onready var launch_button: Button = $Panel/Box/Launch

var _player: Player
var _inventory: InventoryPanel


func _ready() -> void:
	visible = false
	launch_button.pressed.connect(func() -> void: dock_toggled.emit())
	buy_torpedo.pressed.connect(_on_buy_torpedo)
	buy_repair.pressed.connect(_on_buy_repair)
	sell_button.pressed.connect(_on_sell)


## The hull's numbers are read on demand rather than pushed, because nothing
## can change while the tree is paused anyway: the only moment this needs to be
## right is the moment the menu opens or one of its buttons is pressed.
func bind(player: Player) -> void:
	_player = player


## The cargo panel keeps running while the tree is held still, which is what
## makes a sale possible at all: selecting a stack out there and reading the
## selection from here is how the counter knows what you want rid of.
func bind_shop(inventory: InventoryPanel) -> void:
	_inventory = inventory
	inventory.selection_changed.connect(_on_selection_changed)


func refresh() -> void:
	if _player == null or not is_instance_valid(_player):
		return
	stats.text = "SALVAGE  %d      HULL  %d / %d      TORPEDOES  %d / %d" % [
		_player.gold, _player.hp, _player.max_hp, _player.ammo, _player.max_ammo]
	torpedo_label.text = "TORPEDO  —  %d g" % GameConfig.TORPEDO_PRICE
	repair_label.text = "REPAIR  +%d HULL  —  %d g" % [
		GameConfig.REPAIR_AMOUNT, GameConfig.REPAIR_PRICE]
	buy_torpedo.disabled = _player.gold < GameConfig.TORPEDO_PRICE \
		or _player.ammo >= _player.max_ammo
	buy_repair.disabled = _player.gold < GameConfig.REPAIR_PRICE \
		or _player.hp >= _player.max_hp
	_sync_sell_row()


## What the Sell button is about to part you from, or the shrug if nothing is
## selected. Reads the stack through the panel's index, never by trusting the
## highlight to have moved — cargo can change underneath the panel (a sale on
## the same frame, say) and the row has to follow the hold, not the mark.
func _sync_sell_row() -> void:
	if _player == null or not is_instance_valid(_player) or _inventory == null:
		sel_label.text = ""
		sell_button.disabled = true
		return
	var stack := _player.stack_at(_inventory.selected)
	if stack == null:
		sel_label.text = "No cargo selected"
		sell_button.disabled = true
		return
	var def := Item.get_def(stack.id)
	sel_label.text = "%s  x%d   =   %d g" % [
		def.name.to_upper(), stack.count, def.value * stack.count]
	sell_button.disabled = false


func _on_buy_torpedo() -> void:
	if _player == null or not is_instance_valid(_player):
		return
	if _player.gold < GameConfig.TORPEDO_PRICE or _player.ammo >= _player.max_ammo:
		return
	if _player.spend_gold(GameConfig.TORPEDO_PRICE):
		_player.add_ammo(1)
		AudioDirector.play(get_tree(), &"item")
	refresh()


func _on_buy_repair() -> void:
	if _player == null or not is_instance_valid(_player):
		return
	if _player.gold < GameConfig.REPAIR_PRICE or _player.hp >= _player.max_hp:
		return
	if _player.spend_gold(GameConfig.REPAIR_PRICE):
		_player.repair(GameConfig.REPAIR_AMOUNT)
		AudioDirector.play(get_tree(), &"item")
	refresh()


func _on_sell() -> void:
	if _player == null or not is_instance_valid(_player) or _inventory == null:
		return
	var value := _player.sell_stack(_inventory.selected)
	if value <= 0:
		return
	AudioDirector.play(get_tree(), &"gold", GameConfig.VOL_GOLD)
	# The sold slot now holds whatever moved up behind it, so the mark has to
	# step aside before it points at a stranger.
	_inventory.clear_selection()
	refresh()


func _on_selection_changed(_index: int) -> void:
	_sync_sell_row()


## The dock key. Guarded on nothing: pressing it out at sea is a no-op, because
## the harbour node decides whether the request means anything, and this screen
## only ever reports that the key went down.
func _unhandled_input(event: InputEvent) -> void:
	if not event.is_pressed() or event.is_echo():
		return
	if event.is_action("dock"):
		get_viewport().set_input_as_handled()
		dock_toggled.emit()
