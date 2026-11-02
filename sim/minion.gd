extends Unit
class_name Minion

## A creep: walks its lane toward the enemy nexus, auto-attacks whatever enemy
## is in range on the way. No intents from outside — it steers itself.

var lane: Lane = null
var _wp: int = -1   # current waypoint index along the path (-1 = not yet set)

func _init() -> void:
	max_hp = 60.0
	hp = 60.0
	attack_damage = 6.0
	attack_range = 1.2
	attack_cooldown = 1.0
	move_speed = 2.5

## Pick this tick's intent: hit a nearby enemy, else march to the next waypoint.
func decide(enemies: Array) -> void:
	attack_target = _nearest_enemy_in_range(enemies)
	if attack_target != null:
		move_target = null
		return
	if lane != null:
		# Start aimed at our own spawn end of the path; march toward the enemy end.
		if _wp < 0:
			_wp = 0 if team == Unit.Team.BLUE else lane.path.size() - 1
		var dest: Vector2 = lane.waypoint(_wp)
		# Advance to the next waypoint only once we've basically reached this one,
		# so we follow the lane's bends instead of cutting straight to the end.
		if pos.distance_to(dest) <= 0.2:
			_wp = lane.next_index(team, _wp)
			dest = lane.waypoint(_wp)
		move_target = dest

func _nearest_enemy_in_range(enemies: Array) -> Unit:
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
