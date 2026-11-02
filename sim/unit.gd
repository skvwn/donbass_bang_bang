extends RefCounted
class_name Unit

## Base for anything that lives on the map: heroes, minions, towers, nexus.
## Pure data + behaviour, no Node / no rendering (see memory ddb-architecture).

enum Team { BLUE, RED }

var team: int = Team.BLUE
var pos: Vector2 = Vector2.ZERO

var max_hp: float = 100.0
var hp: float = 100.0

var attack_damage: float = 10.0
var attack_range: float = 1.5      # world units
var attack_cooldown: float = 1.0   # seconds between hits
var move_speed: float = 3.0        # world units / second

# Filled by intent providers (player input or bot ai); the sim only reads them.
var move_target = null             # Vector2 or null
var attack_target = null           # Unit or null

var _attack_timer: float = 0.0     # counts down to next allowed attack

func is_alive() -> bool:
	return hp > 0.0

func is_enemy_of(other: Unit) -> bool:
	return other != null and other.team != team

func take_damage(amount: float) -> void:
	hp = maxf(0.0, hp - amount)

## Advance per-unit timers. Called once per tick by the world.
func tick_timers(delta: float) -> void:
	if _attack_timer > 0.0:
		_attack_timer -= delta

func can_attack() -> bool:
	return _attack_timer <= 0.0

func _in_range(target: Unit) -> bool:
	return pos.distance_to(target.pos) <= attack_range

## Try to hit attack_target this tick. Returns true if a hit landed.
func try_attack() -> bool:
	if attack_target == null or not attack_target.is_alive():
		return false
	if not is_enemy_of(attack_target):
		return false
	if not _in_range(attack_target) or not can_attack():
		return false
	attack_target.take_damage(attack_damage)
	_attack_timer = attack_cooldown
	return true

## Move toward move_target (or toward attack_target if out of range).
func step_movement(delta: float) -> void:
	var dest = move_target
	if dest == null and attack_target != null and attack_target.is_alive():
		if not _in_range(attack_target):
			dest = attack_target.pos
	if dest == null:
		return
	var to_dest: Vector2 = dest - pos
	var dist: float = to_dest.length()
	if dist <= 0.001:
		return
	var step: float = move_speed * delta
	if step >= dist:
		pos = dest
	else:
		pos += to_dest / dist * step
