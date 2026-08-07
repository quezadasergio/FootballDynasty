class_name Club
extends RefCounted

const FormationUtil = preload("res://scripts/core/formation.gd")
const StaffScript = preload("res://scripts/core/staff_member.gd")

var id: String = ""
var name: String = ""
var short_name: String = ""
var league_id: String = ""
var budget: int = 500000
var stadium_capacity: int = 8000
var ticket_price: int = 15
var reputation: int = 40
var players: Array[Player] = []
var lineup_ids: Array[String] = []
var bench_ids: Array[String] = []
var mentality: int = 1 ## 0 defensive, 1 normal, 2 attacking
var formation_id: String = "442"
var primary_color: Color = Color(0.2, 0.4, 0.8)
var secondary_color: Color = Color.WHITE
## role_key -> StaffMember (máx. uno por rol)
var staff: Dictionary = {}
var trained_this_matchday: bool = false
## "" doméstico · "EUR" Europa · "SUD" Sudamérica (solo mercado internacional)
var market_region: String = ""
var country_code: String = "MEX"
## Contratos activos: type -> {partner, per_matchday, remaining, level_name}
var media_contracts: Dictionary = {}
var owner_loan_remaining: int = 0
var owner_loan_payment: int = 0


func is_foreign_market_club() -> bool:
	return market_region == "EUR" or market_region == "SUD"


func get_staff(role: int):
	var key: String = StaffScript.role_key(role)
	if staff.has(key):
		return staff[key]
	return null


func hire_staff(member) -> String:
	var key: String = StaffScript.role_key(member.role)
	if staff.has(key):
		return "Ya tienes un %s. Despídelo antes." % member.role_label()
	if budget < member.wage:
		return "Presupuesto insuficiente para el primer sueldo."
	staff[key] = member
	return ""


func fire_staff(role: int) -> void:
	var key: String = StaffScript.role_key(role)
	staff.erase(key)


func staff_wage_bill() -> int:
	var total := 0
	for key in staff.keys():
		total += int(staff[key].wage)
	return total


func get_player(player_id: String) -> Player:
	for p in players:
		if p.id == player_id:
			return p
	return null


func get_lineup_players() -> Array[Player]:
	var result: Array[Player] = []
	for pid in lineup_ids:
		var p := get_player(pid)
		if p:
			result.append(p)
	return result


func get_bench_players() -> Array[Player]:
	var result: Array[Player] = []
	for pid in bench_ids:
		var p := get_player(pid)
		if p:
			result.append(p)
	return result


func weekly_wage_bill() -> int:
	var total := 0
	for p in players:
		total += p.salary
	total += staff_wage_bill()
	return total


func count_foreigners() -> int:
	var n := 0
	for p in players:
		if p.is_foreign():
			n += 1
	return n


func can_add_foreigner(tier: int) -> bool:
	return count_foreigners() < Database.foreigner_limit_for_tier(tier)


func squad_strength() -> float:
	var lineup := get_lineup_players()
	if lineup.is_empty():
		return 40.0
	var sum := 0.0
	for p in lineup:
		sum += p.overall() * p.performance_modifier()
	return sum / lineup.size()


func ensure_default_lineup() -> void:
	if lineup_ids.size() == 11:
		return
	rebuild_lineup()


func rebuild_lineup() -> void:
	lineup_ids.clear()
	bench_ids.clear()
	var formation_slots: Array = FormationUtil.slots(formation_id)
	var pools: Dictionary = {
		Player.Position.GK: [],
		Player.Position.DEF: [],
		Player.Position.MID: [],
		Player.Position.ATT: [],
	}
	for p in players:
		if p.injured:
			continue
		if p.fatigue >= 92:
			continue
		(pools[p.position] as Array).append(p)
	for pos in pools.keys():
		(pools[pos] as Array).sort_custom(func(a: Player, b: Player) -> bool:
			return _lineup_score(a, int(pos)) > _lineup_score(b, int(pos))
		)

	var used: Dictionary = {}
	for slot_pos in formation_slots:
		var chosen := _pick_for_slot(int(slot_pos), pools, used)
		if chosen == null:
			continue
		lineup_ids.append(chosen.id)
		used[chosen.id] = true

	# Completar hasta 11 si faltan (lesiones / plantilla corta)
	var leftovers: Array[Player] = []
	for p in players:
		if not used.has(p.id) and not p.injured:
			leftovers.append(p)
	leftovers.sort_custom(func(a: Player, b: Player) -> bool: return a.overall() > b.overall())
	while lineup_ids.size() < 11 and not leftovers.is_empty():
		var p2: Player = leftovers.pop_front()
		lineup_ids.append(p2.id)
		used[p2.id] = true

	for p3 in leftovers:
		if bench_ids.size() >= 7:
			break
		bench_ids.append(p3.id)


func _lineup_score(p: Player, target_pos: int) -> float:
	var ovr := float(p.overall()) * p.performance_modifier()
	var form_bonus := p.form / 50.0
	var fatigue_pen := p.fatigue * 0.08
	if p.position == target_pos:
		return ovr + form_bonus + 8.0 - fatigue_pen
	var dist := absi(int(p.position) - target_pos)
	return ovr + form_bonus - dist * 6.0 - fatigue_pen


func _pick_for_slot(target_pos: int, pools: Dictionary, used: Dictionary) -> Player:
	var candidates: Array[Player] = []
	for pos in pools.keys():
		for p in pools[pos]:
			if not used.has(p.id):
				candidates.append(p)
	if candidates.is_empty():
		return null
	candidates.sort_custom(func(a: Player, b: Player) -> bool:
		return _lineup_score(a, target_pos) > _lineup_score(b, target_pos)
	)
	return candidates[0]


func to_dict() -> Dictionary:
	var plist: Array = []
	for p in players:
		plist.append(p.to_dict())
	var staff_data: Dictionary = {}
	for key in staff.keys():
		staff_data[key] = staff[key].to_dict()
	return {
		"id": id,
		"name": name,
		"short_name": short_name,
		"league_id": league_id,
		"budget": budget,
		"stadium_capacity": stadium_capacity,
		"ticket_price": ticket_price,
		"reputation": reputation,
		"players": plist,
		"lineup_ids": lineup_ids.duplicate(),
		"bench_ids": bench_ids.duplicate(),
		"mentality": mentality,
		"formation_id": formation_id,
		"primary_color": primary_color.to_html(),
		"secondary_color": secondary_color.to_html(),
		"staff": staff_data,
		"trained_this_matchday": trained_this_matchday,
		"market_region": market_region,
		"country_code": country_code,
		"media_contracts": media_contracts.duplicate(true),
		"owner_loan_remaining": owner_loan_remaining,
		"owner_loan_payment": owner_loan_payment,
	}


static func from_dict(d: Dictionary) -> Club:
	var c := Club.new()
	c.id = d.get("id", "")
	c.name = d.get("name", "")
	c.short_name = d.get("short_name", "")
	c.league_id = d.get("league_id", "")
	c.budget = int(d.get("budget", 500000))
	c.stadium_capacity = int(d.get("stadium_capacity", 8000))
	c.ticket_price = int(d.get("ticket_price", 15))
	c.reputation = int(d.get("reputation", 40))
	c.mentality = int(d.get("mentality", 1))
	c.formation_id = str(d.get("formation_id", FormationUtil.DEFAULT_ID))
	if not FormationUtil.CATALOG.has(c.formation_id):
		c.formation_id = FormationUtil.DEFAULT_ID
	c.primary_color = Color(d.get("primary_color", "#3366cc"))
	c.secondary_color = Color(d.get("secondary_color", "#ffffff"))
	c.trained_this_matchday = bool(d.get("trained_this_matchday", false))
	c.market_region = str(d.get("market_region", ""))
	c.country_code = str(d.get("country_code", "MEX"))
	c.media_contracts = d.get("media_contracts", {}).duplicate(true)
	c.owner_loan_remaining = int(d.get("owner_loan_remaining", 0))
	c.owner_loan_payment = int(d.get("owner_loan_payment", 0))
	c.players.clear()
	for pd in d.get("players", []):
		c.players.append(Player.from_dict(pd))
	c.lineup_ids.clear()
	for pid in d.get("lineup_ids", []):
		c.lineup_ids.append(str(pid))
	c.bench_ids.clear()
	for pid in d.get("bench_ids", []):
		c.bench_ids.append(str(pid))
	c.staff.clear()
	var staff_data: Dictionary = d.get("staff", {})
	for key in staff_data.keys():
		c.staff[str(key)] = StaffScript.from_dict(staff_data[key])
	return c
