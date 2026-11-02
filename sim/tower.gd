extends Unit
class_name Tower

## Stationary defender. Locks onto one enemy in radius and fires; prefers the
## nearest minion over a hero (classic MOBA aggro is more nuanced — kept simple).

func _init() -> void:
	max_hp = 800.0
	hp = 800.0
	# Minimal poke — it just plinks whatever wanders into range.
	attack_damage = 12.0
	attack_range = 5.0
	attack_cooldown = 1.0
	move_speed = 0.0   # never moves

## Acquire/keep a target among enemies, then fire if able.
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
