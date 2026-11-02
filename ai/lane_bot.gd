extends RefCounted
class_name LaneBot

## Minimal, lane-bound bot (see memory ddb-bot-ai). One bot drives one hero.
## It is just an intent provider, exactly like the player's controller.

const RETREAT_HP_FRAC: float = 0.3   # below this, fall back to own tower
const AGGRO_RANGE: float = 6.0       # how far the bot looks for a target

var lane: Lane = null
var retreat_pos: Vector2 = Vector2.ZERO
var _wp: int = 0   # current waypoint along the lane

func _init(p_lane: Lane = null, p_retreat: Vector2 = Vector2.ZERO) -> void:
	lane = p_lane
	retreat_pos = p_retreat

func decide(world: World, hero: Hero) -> void:
	# dead → the world skips us while respawning; nothing to decide.
	if hero.hp < hero.max_hp * RETREAT_HP_FRAC:
		hero.attack_target = null
		hero.move_target = retreat_pos
		return

	var enemies: Array = world.enemies_of(hero)

	var enemy_hero: Unit = _nearest(hero, enemies, [Hero])
	if enemy_hero != null:
		_engage(hero, enemy_hero)
		return

	var enemy_minion: Unit = _nearest(hero, enemies, [Minion])
	if enemy_minion != null:
		_engage(hero, enemy_minion)
		return

	# nothing to fight → push the lane.
	hero.attack_target = null
	if lane != null:
		_wp = lane.next_index(hero.team, _wp)
		var dest: Vector2 = lane.waypoint(_wp)
		if hero.pos.distance_to(dest) <= 0.3:
			_wp = lane.next_index(hero.team, _wp)
			dest = lane.waypoint(_wp)
		hero.move_target = dest

func _engage(hero: Hero, target: Unit) -> void:
	hero.attack_target = target
	# step_movement will close the gap when out of range.
	hero.move_target = null

func _nearest(hero: Hero, enemies: Array, types: Array) -> Unit:
	var best: Unit = null
	var best_d: float = AGGRO_RANGE
	for e in enemies:
		if not _is_type(e, types):
			continue
		var d: float = hero.pos.distance_to(e.pos)
		if d <= best_d:
			best_d = d
			best = e
	return best

func _is_type(e: Unit, types: Array) -> bool:
	for t in types:
		if is_instance_of(e, t):
			return true
	return false
