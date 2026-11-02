extends Unit
class_name BaseCore

## The nexus. Destroying the enemy's one ends the match (see memory ddb-map).

func _init() -> void:
	max_hp = 2000.0
	hp = 2000.0
	# The nexus defends itself: a short, dangerous range right around the corner.
	attack_damage = 35.0
	attack_range = 3.0
	attack_cooldown = 1.0
	move_speed = 0.0

## Same shoot-what's-in-range behaviour as a tower. The world calls this each tick.
func act(enemies: Array) -> void:
	if attack_target == null or not attack_target.is_alive() or not _in_range(attack_target):
		attack_target = _acquire(enemies)
	try_attack()

func _acquire(enemies: Array) -> Unit:
	var best: Unit = null
	var best_d: float = attack_range
	for e in enemies:
		if e == null or not e.is_alive() or not is_enemy_of(e):
			continue
		var d: float = pos.distance_to(e.pos)
		if d <= best_d:
			best_d = d
			best = e
	return best
