extends RefCounted
class_name Lane

## A lane is just a path (list of waypoints) plus the two teams' spawn points.
## Minions walk the path toward the enemy nexus. See memory ddb-map.

enum Which { TOP, MID, BOT }

var which: int = Which.MID
# Waypoints ordered from BLUE's base to RED's base.
var path: PackedVector2Array = PackedVector2Array()

func spawn_point(team: int) -> Vector2:
	if path.is_empty():
		return Vector2.ZERO
	return path[0] if team == Unit.Team.BLUE else path[path.size() - 1]

## Index of the next waypoint to walk toward, given team's travel direction.
func next_index(team: int, current: int) -> int:
	if team == Unit.Team.BLUE:
		return mini(current + 1, path.size() - 1)
	return maxi(current - 1, 0)

func waypoint(i: int) -> Vector2:
	return path[clampi(i, 0, path.size() - 1)]
