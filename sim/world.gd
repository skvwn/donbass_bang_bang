extends RefCounted
class_name World

## The match simulation. Owns all state and advances it with a fixed tick.
## Knows nothing about rendering or input — it only consumes intents written
## onto units by controllers (player input or bot ai). See memory ddb-architecture.

const TICK_HZ: float = 30.0
const TICK_DT: float = 1.0 / TICK_HZ

# Creep waves: first at 10s, then every 30s, all three lanes at once (ddb-creep-waves).
const FIRST_WAVE_T: float = 10.0
const WAVE_INTERVAL: float = 30.0
const MINIONS_PER_WAVE: int = 3

# Fountain: a tiny spot right in the base corner that heals hard. Stand on your
# own nexus to top up fast.
const BASE_HEAL_RADIUS: float = 2.0
const BASE_HEAL_RATE: float = 180.0   # hp per second

var time: float = 0.0
var winner: int = -1   # Unit.Team value once decided, else -1

# Playable rectangle; units are clamped inside it so nobody walks off the map.
var map_min: Vector2 = Vector2.ZERO
var map_max: Vector2 = Vector2(40, 40)

var heroes: Array[Hero] = []
var minions: Array[Minion] = []
var towers: Array[Tower] = []
var cores: Array[BaseCore] = []
var lanes: Array[Lane] = []

# hero -> controller object exposing decide(world, hero).
var controllers: Dictionary = {}

var _next_wave_t: float = FIRST_WAVE_T

## Seconds until the next creep wave spawns on every lane. For the HUD.
func next_wave_in() -> float:
	return maxf(_next_wave_t - time, 0.0)

func all_units() -> Array:
	var out: Array = []
	out.append_array(heroes)
	out.append_array(minions)
	out.append_array(towers)
	out.append_array(cores)
	return out

func enemies_of(u: Unit) -> Array:
	var out: Array = []
	for other in all_units():
		if other != u and other.is_alive() and u.is_enemy_of(other):
			out.append(other)
	return out

## One simulation step. Order is fixed and mirrors ddb-architecture.
func tick() -> void:
	if winner != -1:
		return
	time += TICK_DT

	# 1. gather intents (player + bots)
	for h in heroes:
		if h.respawning():
			continue
		var ctrl = controllers.get(h)
		if ctrl != null:
			ctrl.decide(self, h)
	for m in minions:
		m.decide(enemies_of(m))

	# 2. movement
	for h in heroes:
		if h.respawning():
			continue
		h.tick_timers(TICK_DT)
		h.step_movement(TICK_DT)
	for m in minions:
		m.tick_timers(TICK_DT)
		m.step_movement(TICK_DT)

	# 2b. keep every mover inside the map
	for h in heroes:
		if not h.respawning():
			h.pos = h.pos.clamp(map_min, map_max)
	for m in minions:
		m.pos = m.pos.clamp(map_min, map_max)

	# 3. combat: auto-attacks (abilities land here later)
	for h in heroes:
		if not h.respawning():
			h.try_attack()
	for m in minions:
		m.try_attack()

	# 4. deaths: clear the fallen, respawn heroes
	_resolve_deaths()

	# 4b. fountain healing: alive heroes near their own nexus top up hp
	_base_heal()

	# 5. creep spawn by schedule
	while time >= _next_wave_t:
		_spawn_wave()
		_next_wave_t += WAVE_INTERVAL

	# 6. towers and nexus fire
	for t in towers:
		if t.is_alive():
			t.tick_timers(TICK_DT)
			t.act(enemies_of(t))
	for c in cores:
		if c.is_alive():
			c.tick_timers(TICK_DT)
			c.act(enemies_of(c))

	# 7. victory: an enemy nexus destroyed?
	_check_victory()

func _resolve_deaths() -> void:
	var live_minions: Array[Minion] = []
	for m in minions:
		if m.is_alive():
			live_minions.append(m)
	minions = live_minions

	var live_towers: Array[Tower] = []
	for t in towers:
		if t.is_alive():
			live_towers.append(t)
	towers = live_towers

	for h in heroes:
		if h.is_dead() and not h.respawning():
			h.start_respawn()
		elif h.respawning():
			h.tick_respawn(TICK_DT, _spawn_pos_for(h))

func _base_heal() -> void:
	for h in heroes:
		if not h.is_alive() or h.respawning() or h.hp >= h.max_hp:
			continue
		for c in cores:
			if c.team == h.team and h.pos.distance_to(c.pos) <= BASE_HEAL_RADIUS:
				h.hp = minf(h.max_hp, h.hp + BASE_HEAL_RATE * TICK_DT)
				break

func _spawn_pos_for(h: Hero) -> Vector2:
	for c in cores:
		if c.team == h.team:
			return c.pos
	return h.pos

func _spawn_wave() -> void:
	for lane in lanes:
		for team in [Unit.Team.BLUE, Unit.Team.RED]:
			for i in MINIONS_PER_WAVE:
				var m := Minion.new()
				m.team = team
				m.lane = lane
				# Spread the wave out a touch so they don't overlap exactly.
				m.pos = lane.spawn_point(team) + Vector2(0.4 * i, 0.0)
				minions.append(m)

## Break the reference cycles (units target each other, bots hold lanes) so a
## headless run exits clean. Call when done with a World.
func teardown() -> void:
	for u in all_units():
		u.attack_target = null
		u.move_target = null
	controllers.clear()
	heroes.clear()
	minions.clear()
	towers.clear()
	cores.clear()
	lanes.clear()

func _check_victory() -> void:
	var alive_team := {}
	for c in cores:
		if c.is_alive():
			alive_team[c.team] = true
	# If a team's core is gone, the other team wins.
	var blue_alive: bool = alive_team.has(Unit.Team.BLUE)
	var red_alive: bool = alive_team.has(Unit.Team.RED)
	if blue_alive and not red_alive:
		winner = Unit.Team.BLUE
	elif red_alive and not blue_alive:
		winner = Unit.Team.RED
