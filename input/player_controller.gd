extends RefCounted
class_name PlayerController

## Turns the player's raw input (a tap, an attack order) into the same kind of
## intent a bot writes. The scene layer sets these fields; the sim reads them.

var pending_move = null       # Vector2 set by a move tap, consumed next decide
var pending_attack: Unit = null

## Called once per tick by the world, just like the bot's decide().
func decide(_world: World, hero: Hero) -> void:
	if pending_attack != null:
		hero.attack_target = pending_attack
		hero.move_target = null
	elif pending_move != null:
		hero.move_target = pending_move
		hero.attack_target = null
	# Keep the last order standing until a new one arrives (don't clear it).

# --- called from the scene/ui layer ---

func order_move(world_pos: Vector2) -> void:
	pending_move = world_pos
	pending_attack = null

func order_attack(target: Unit) -> void:
	pending_attack = target
	pending_move = null
