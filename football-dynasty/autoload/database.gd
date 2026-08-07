extends Node

const StaffScript = preload("res://scripts/core/staff_member.gd")

var first_names: Array = []
var last_names: Array = []
var foreign_names: Dictionary = {}
var leagues_template: Array = []
var foreign_clubs_template: Array = []
var _player_counter: int = 0
var rng: RandomNumberGenerator = RandomNumberGenerator.new()

## Extranjeros habituales en el fútbol mexicano (códigos FIFA).
const FOREIGN_NATS: Array[String] = [
	"ARG", "BRA", "COL", "URU", "CHI", "ECU", "PER", "PAR", "VEN",
	"USA", "CAN", "ESP", "FRA", "POR", "CRO", "NGA", "GHA", "CMR", "SEN",
]


func _ready() -> void:
	_load_data()


func _load_data() -> void:
	var names_file := FileAccess.open("res://data/names.json", FileAccess.READ)
	if names_file:
		var names_data: Dictionary = JSON.parse_string(names_file.get_as_text())
		first_names = names_data.get("first_names", [])
		last_names = names_data.get("last_names", [])
		foreign_names = names_data.get("foreign_names", {})
	var leagues_file := FileAccess.open("res://data/leagues.json", FileAccess.READ)
	if leagues_file:
		var leagues_data: Dictionary = JSON.parse_string(leagues_file.get_as_text())
		leagues_template = leagues_data.get("leagues", [])
	var foreign_file := FileAccess.open("res://data/foreign_clubs.json", FileAccess.READ)
	if foreign_file:
		var foreign_data: Dictionary = JSON.parse_string(foreign_file.get_as_text())
		foreign_clubs_template = foreign_data.get("clubs", [])


func create_world(seed_value: int = 0) -> Dictionary:
	if seed_value != 0:
		rng.seed = seed_value
	else:
		rng.randomize()
	_player_counter = 0
	var clubs: Dictionary = {}
	var leagues: Dictionary = {}
	var free_agents: Array[Player] = []

	for league_data in leagues_template:
		var league := League.new()
		league.id = league_data["id"]
		league.name = league_data["name"]
		league.tier = int(league_data["tier"])
		for club_data in league_data["clubs"]:
			var club := Club.new()
			club.id = club_data["id"]
			club.name = club_data["name"]
			club.short_name = club_data["short_name"]
			club.league_id = league.id
			club.budget = int(club_data["budget"])
			club.stadium_capacity = int(club_data["stadium_capacity"])
			club.reputation = int(club_data["reputation"])
			club.ticket_price = 10 + club.reputation / 4
			club.primary_color = Color(club_data.get("color", "#3366cc"))
			var skill_base := skill_base_for_club(league.tier, club.reputation)
			club.players = _generate_squad(club.id, skill_base, league.tier)
			club.ensure_default_lineup()
			clubs[club.id] = club
			league.club_ids.append(club.id)
		league.init_standings()
		leagues[league.id] = league

	# Free agents (nivel Expansión / bajo)
	for i in 16:
		var fa_nat := "MEX"
		if rng.randf() < 0.25:
			fa_nat = random_foreign_nationality()
		var p := _make_player("", skill_base_for_free_agent(), -1, fa_nat)
		free_agents.append(p)

	var foreign_clubs: Dictionary = _create_foreign_market_clubs()

	var seasons: Dictionary = {}
	for lid in leagues.keys():
		var league: League = leagues[lid]
		var season := Season.new()
		season.year = 2026
		season.generate_round_robin(league.club_ids)
		seasons[lid] = season

	return {
		"clubs": clubs,
		"leagues": leagues,
		"seasons": seasons,
		"free_agents": free_agents,
		"foreign_clubs": foreign_clubs,
	}


func bump_player_counter_from_players(player_lists: Array) -> void:
	## Evita IDs duplicados al regenerar mercado / canteranos tras cargar partida.
	for list in player_lists:
		if list == null:
			continue
		for p in list:
			if p == null:
				continue
			var pid: String = str(p.id)
			if pid.begins_with("p_"):
				var n := int(pid.substr(2))
				if n > _player_counter:
					_player_counter = n


func _create_foreign_market_clubs() -> Dictionary:
	var result: Dictionary = {}
	for club_data in foreign_clubs_template:
		var club := Club.new()
		club.id = club_data["id"]
		club.name = club_data["name"]
		club.short_name = club_data["short_name"]
		club.league_id = "foreign_%s" % str(club_data["region"]).to_lower()
		club.market_region = str(club_data["region"])
		club.country_code = str(club_data["country"])
		club.reputation = int(club_data["reputation"])
		club.budget = 50000000
		club.stadium_capacity = 50000
		club.ticket_price = 40
		club.primary_color = Color(club_data.get("color", "#3366cc"))
		var skill_base: int = int(club_data.get("skill_base", 78))
		club.players = _generate_foreign_market_squad(club.id, skill_base, club.country_code, club.market_region)
		club.ensure_default_lineup()
		result[club.id] = club
	return result


func _generate_foreign_market_squad(club_id: String, skill_base: int, country: String, region: String) -> Array[Player]:
	## Plantilla compacta de mercado (14): mayoría del país del club + refuerzos.
	var squad: Array[Player] = []
	var composition: Array = [
		Player.Position.GK, Player.Position.GK,
		Player.Position.DEF, Player.Position.DEF, Player.Position.DEF, Player.Position.DEF,
		Player.Position.MID, Player.Position.MID, Player.Position.MID, Player.Position.MID,
		Player.Position.ATT, Player.Position.ATT, Player.Position.ATT,
		Player.Position.MID,
	]
	for i in composition.size():
		var nat := country
		## ~30% refuerzos de otras nacionalidades (mercado internacional).
		if rng.randf() < 0.3:
			if region == "EUR":
				nat = ["ESP", "FRA", "POR", "CRO", "BRA", "ARG", "NGA", "SEN"][rng.randi_range(0, 7)]
			else:
				nat = ["BRA", "ARG", "URU", "COL", "CHI", "PAR", "ECU", "VEN"][rng.randi_range(0, 7)]
		var depth_mod := rng.randi_range(-3, 5) if i < 11 else rng.randi_range(-8, 0)
		## Europa un poco más cara/fuerte de media.
		if region == "EUR":
			depth_mod += 2
		squad.append(_make_player(club_id, skill_base + depth_mod, composition[i], nat))
	return squad


func skill_base_for_club(tier: int, reputation: int) -> int:
	## Liga MX ~70–86 · Expansión ~48–60, según reputación del club.
	var tier_base := 70 if tier <= 1 else 50
	var rep_bonus := int(round((float(reputation) - 50.0) * 0.4))
	return clampi(tier_base + rep_bonus, 42, 88)


func skill_base_for_free_agent() -> int:
	return rng.randi_range(40, 58)


func foreigner_limit_for_tier(tier: int) -> int:
	## Liga MX: 5 · Expansión: máximo 2.
	return 5 if tier <= 1 else 2


func foreigner_quota_for_new_squad(tier: int) -> int:
	if tier <= 1:
		return 5
	return rng.randi_range(1, 2)


func random_foreign_nationality() -> String:
	return FOREIGN_NATS[rng.randi_range(0, FOREIGN_NATS.size() - 1)]


func _generate_squad(club_id: String, skill_base: int, tier: int = 2) -> Array[Player]:
	var squad: Array[Player] = []
	## Plantillas más profundas en Liga MX (24) que en Expansión (20).
	var composition: Array = [
		Player.Position.GK, Player.Position.GK,
		Player.Position.DEF, Player.Position.DEF, Player.Position.DEF, Player.Position.DEF, Player.Position.DEF,
		Player.Position.MID, Player.Position.MID, Player.Position.MID, Player.Position.MID, Player.Position.MID, Player.Position.MID,
		Player.Position.ATT, Player.Position.ATT, Player.Position.ATT, Player.Position.ATT,
		Player.Position.MID, Player.Position.DEF, Player.Position.ATT,
	]
	if tier <= 1:
		composition.append_array([
			Player.Position.GK,
			Player.Position.DEF,
			Player.Position.MID,
			Player.Position.ATT,
		])
	var foreign_quota := foreigner_quota_for_new_squad(tier)
	var foreign_slots: Dictionary = {} ## index -> true
	var indices: Array = range(composition.size())
	indices.shuffle()
	for i in mini(foreign_quota, indices.size()):
		foreign_slots[indices[i]] = true
	for i in composition.size():
		var pos: int = composition[i]
		## Titulares / primeros de lista un poco más fuertes; reservas más flojos.
		var depth_mod := 0
		if i < 11:
			depth_mod = rng.randi_range(0, 4)
		elif i >= composition.size() - 4:
			depth_mod = rng.randi_range(-8, -2)
		else:
			depth_mod = rng.randi_range(-4, 2)
		var nat := "MEX"
		if foreign_slots.has(i):
			nat = random_foreign_nationality()
		squad.append(_make_player(club_id, skill_base + depth_mod, pos, nat))
	return squad


func _pick_name_for_nationality(nationality: String) -> Array:
	## [first, last]
	var pool_key := nationality
	if nationality in ["COL", "URU", "CHI", "ECU", "PER", "PAR", "VEN", "ESP"]:
		pool_key = "ARG"
	elif nationality in ["CAN", "ENG"]:
		pool_key = "USA"
	elif nationality in ["POR", "CRO", "ITA", "GER"]:
		pool_key = "FRA"
	elif nationality in ["GHA", "CMR", "SEN"]:
		pool_key = "NGA"
	if foreign_names.has(pool_key):
		var pool: Dictionary = foreign_names[pool_key]
		var f: Array = pool.get("first", first_names)
		var l: Array = pool.get("last", last_names)
		return [f[rng.randi_range(0, f.size() - 1)], l[rng.randi_range(0, l.size() - 1)]]
	return [
		first_names[rng.randi_range(0, first_names.size() - 1)],
		last_names[rng.randi_range(0, last_names.size() - 1)],
	]


func _make_player(club_id: String, skill_base: int, forced_pos: int = -1, nationality: String = "MEX") -> Player:
	_player_counter += 1
	var p := Player.new()
	p.id = "p_%d" % _player_counter
	p.nationality = nationality if nationality != "" else "MEX"
	var names := _pick_name_for_nationality(p.nationality)
	p.first_name = names[0]
	p.last_name = names[1]
	## Pirámide de edades: más jugadores en 22–28.
	var age_roll := rng.randf()
	if age_roll < 0.18:
		p.age = rng.randi_range(17, 21)
	elif age_roll < 0.78:
		p.age = rng.randi_range(22, 28)
	else:
		p.age = rng.randi_range(29, 35)
	if forced_pos >= 0:
		p.position = forced_pos as Player.Position
	else:
		p.position = [Player.Position.GK, Player.Position.DEF, Player.Position.MID, Player.Position.ATT][rng.randi_range(0, 3)]
	var variance := rng.randi_range(-8, 8)
	var age_adj := 0
	if p.age <= 20:
		age_adj = -4
	elif p.age >= 32:
		age_adj = -5
	elif p.age >= 29:
		age_adj = -2
	var base := clampi(skill_base + variance + age_adj, 28, 92)
	## Extranjeros en Liga MX suelen ser un poco más fuertes de media.
	if p.is_foreign() and skill_base >= 65:
		base = clampi(base + rng.randi_range(1, 4), 28, 92)
	p.attack = clampi(base + rng.randi_range(-8, 8), 25, 95)
	p.defense = clampi(base + rng.randi_range(-8, 8), 25, 95)
	p.midfield = clampi(base + rng.randi_range(-8, 8), 25, 95)
	p.physical = clampi(base + rng.randi_range(-6, 10), 30, 95)
	match p.position:
		Player.Position.GK:
			p.defense = clampi(p.defense + 12, 30, 95)
			p.attack = clampi(p.attack - 20, 15, 60)
		Player.Position.DEF:
			p.defense = clampi(p.defense + 8, 30, 95)
		Player.Position.ATT:
			p.attack = clampi(p.attack + 8, 30, 95)
		Player.Position.MID:
			p.midfield = clampi(p.midfield + 6, 30, 95)
	p.morale = rng.randi_range(55, 85)
	p.happiness = rng.randi_range(55, 85)
	p.form = rng.randi_range(55, 85)
	p.talent = clampi(base + rng.randi_range(-6, 12), 30, 95)
	if p.age <= 21:
		p.talent = clampi(p.talent + rng.randi_range(2, 8), 35, 95)
	p.speed = clampi(base + rng.randi_range(-8, 10), 28, 95)
	p.strength = clampi(base + rng.randi_range(-6, 10), 28, 95)
	p.fatigue = float(rng.randi_range(0, 15))
	match p.position:
		Player.Position.ATT:
			p.speed = clampi(p.speed + 6, 30, 95)
		Player.Position.DEF:
			p.strength = clampi(p.strength + 6, 30, 95)
		Player.Position.GK:
			p.speed = clampi(p.speed - 8, 20, 80)
	var ovr := p.overall()
	p.salary = int(ovr * ovr * 1.8) + 200
	p.value = int(ovr * ovr * ovr * 0.9) + 10000
	if p.age >= 30:
		p.value = int(p.value * 0.7)
	if p.age <= 21:
		p.value = int(p.value * 1.15)
	p.club_id = club_id
	return p


func make_youth_prospect(region: String, scout_skill: int) -> Player:
	var skill_base := 38 + int(scout_skill * 0.22) + rng.randi_range(-4, 8)
	var p := _make_player("", skill_base, -1, "MEX")
	p.age = rng.randi_range(16, 19)
	p.origin_region = region
	p.talent = clampi(p.talent + 8 + scout_skill / 20, 40, 95)
	p.fatigue = 0.0
	p.happiness = rng.randi_range(60, 85)
	p.value = int(p.value * 0.55) + 5000
	p.salary = maxi(400, int(p.salary * 0.55))
	return p


func make_squad_replacement(club_id: String, skill_base: int, tier: int, current_foreigners: int) -> Player:
	## Respeta cupo de extranjeros al reponer plantilla.
	var nat := "MEX"
	var limit := foreigner_limit_for_tier(tier)
	if current_foreigners < limit and rng.randf() < 0.12:
		nat = random_foreign_nationality()
	return _make_player(club_id, skill_base, -1, nat)


func generate_staff_candidates(role: int, count: int = 3) -> Array:
	var result: Array = []
	for i in count:
		_player_counter += 1
		var skill := rng.randi_range(38, 88)
		var first: String = first_names[rng.randi_range(0, first_names.size() - 1)]
		var last: String = last_names[rng.randi_range(0, last_names.size() - 1)]
		result.append(StaffScript.generate(role, skill, first, last, _player_counter))
	return result
