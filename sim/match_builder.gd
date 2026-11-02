extends RefCounted
class_name MatchBuilder

## Builds a fresh, symmetric 3-lane match (see memory ddb-map). Both the match
## scene and the headless test use this, so they simulate the exact same world.
## NOTE: these numbers will migrate to data/map.tres + data/balance.tres later.

const BLUE_BASE := Vector2(0, 0)
const RED_BASE := Vector2(40, 40)

# Tower distances from the base along the lane (world units). The outer one (6)
# is just past the nexus' 3-unit defence range, so you can hit it without the
# base hitting you back.
const TOWER_DISTS := [6.0, 12.0, 18.0]

## Returns a World populated with lanes, cores, towers and heroes.
## bot_lane_script: the LaneBot script, injected so sim/ stays free of ai/.
static func build(bot_lane_script: GDScript) -> World:
	var w := World.new()
	# Map bounds = the rectangle spanned by the two base corners.
	w.map_min = Vector2(minf(BLUE_BASE.x, RED_BASE.x), minf(BLUE_BASE.y, RED_BASE.y))
	w.map_max = Vector2(maxf(BLUE_BASE.x, RED_BASE.x), maxf(BLUE_BASE.y, RED_BASE.y))

	# --- lanes: three corridors from BLUE base to RED base ---
	var top := Lane.new()
	top.which = Lane.Which.TOP
	top.path = PackedVector2Array([BLUE_BASE, Vector2(0, 40), RED_BASE])

	var mid := Lane.new()
	mid.which = Lane.Which.MID
	mid.path = PackedVector2Array([BLUE_BASE, Vector2(20, 20), RED_BASE])

	var bot := Lane.new()
	bot.which = Lane.Which.BOT
	bot.path = PackedVector2Array([BLUE_BASE, Vector2(40, 0), RED_BASE])

	w.lanes = [top, mid, bot]

	# --- nexus per team ---
	for team in [Unit.Team.BLUE, Unit.Team.RED]:
		var core := BaseCore.new()
		core.team = team
		core.pos = BLUE_BASE if team == Unit.Team.BLUE else RED_BASE
		w.cores.append(core)

	# --- three towers per lane per team, clustered near the base. Placed by
	#     absolute distance from the base along the lane, so the outer one sits
	#     almost against the base (but outside the nexus' defence range) and the
	#     others step a little way up the lane. ---
	for lane in w.lanes:
		var bend: Vector2 = lane.waypoint(1)
		var blue_dir: Vector2 = (bend - BLUE_BASE).normalized()
		var red_dir: Vector2 = (bend - RED_BASE).normalized()
		for d in TOWER_DISTS:
			w.towers.append(_tower(Unit.Team.BLUE, BLUE_BASE + blue_dir * d))
			w.towers.append(_tower(Unit.Team.RED, RED_BASE + red_dir * d))

	# --- one hero per lane per team, each driven by a lane bot ---
	for lane in w.lanes:
		_add_hero(w, Unit.Team.BLUE, lane, BLUE_BASE, bot_lane_script)
		_add_hero(w, Unit.Team.RED, lane, RED_BASE, bot_lane_script)

	return w

static func _tower(team: int, pos: Vector2) -> Tower:
	var t := Tower.new()
	t.team = team
	t.pos = pos
	return t

static func _add_hero(w: World, team: int, lane: Lane, base: Vector2, bot_script: GDScript) -> void:
	var h := Hero.new()
	h.team = team
	h.pos = lane.spawn_point(team)
	h.hero_name = "%s-%d" % [["blue", "red"][team], lane.which]
	w.heroes.append(h)
	var bot = bot_script.new(lane, base)
	w.controllers[h] = bot
