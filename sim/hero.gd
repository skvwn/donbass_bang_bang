extends Unit
class_name Hero

## Player- or bot-controlled champion. Gets its move/attack intent from the
## outside (input/ or ai/); adds level, gold and a respawn timer on top of Unit.

var hero_name: String = "hero"
var level: int = 1
var gold: int = 0

var respawn_time: float = 6.0
var _respawn_timer: float = 0.0

func _init() -> void:
	max_hp = 200.0
	hp = 200.0
	attack_damage = 18.0
	attack_range = 2.0
	attack_cooldown = 0.8
	move_speed = 3.5

func is_dead() -> bool:
	return not is_alive()

## Called by the world when this hero hits 0 hp.
func start_respawn() -> void:
	_respawn_timer = respawn_time

func respawning() -> bool:
	return _respawn_timer > 0.0

## Seconds left until this hero comes back (0 if alive). For the HUD/indicator.
func respawn_remaining() -> float:
	return maxf(_respawn_timer, 0.0)

## Returns true on the tick the hero comes back to life.
func tick_respawn(delta: float, spawn_pos: Vector2) -> bool:
	if _respawn_timer <= 0.0:
		return false
	_respawn_timer -= delta
	if _respawn_timer <= 0.0:
		hp = max_hp
		pos = spawn_pos
		move_target = null
		attack_target = null
		return true
	return false
