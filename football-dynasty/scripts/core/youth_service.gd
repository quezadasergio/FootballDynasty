class_name YouthService
extends RefCounted

const StaffScript = preload("res://scripts/core/staff_member.gd")

const MIN_SQUAD := 7
const MAX_SQUAD := 15
const PROMOTE_AGE := 17
const RETURN_AGE_LIMIT := 19

const PLANS: Array[Dictionary] = [
	{"id": "fisico", "label": "Físico y resistencia"},
	{"id": "tecnico", "label": "Técnica individual"},
	{"id": "tactico", "label": "Lectura táctica"},
	{"id": "integral", "label": "Desarrollo integral"},
]


static func plan_label(plan_id: String) -> String:
	for p in PLANS:
		if p["id"] == plan_id:
			return str(p["label"])
	return "Sin plan"


static func has_coach(club: Club) -> bool:
	return club.get_staff(StaffScript.Role.YOUTH) != null


static func suggest_plan(club: Club) -> Dictionary:
	var coach = club.get_staff(StaffScript.Role.YOUTH)
	if coach == null:
		return {"ok": false, "text": "Contrata un entrenador de fuerzas básicas para recibir un plan de trabajo."}
	if club.youth_players.is_empty():
		return {"ok": false, "text": "No hay juveniles en la cantera."}

	var n := float(club.youth_players.size())
	var avg_phys := 0.0
	var avg_tech := 0.0
	var avg_speed := 0.0
	var avg_talent := 0.0
	var avg_gap := 0.0
	for p in club.youth_players:
		avg_phys += float(p.physical + p.strength) / 2.0
		avg_tech += float(p.attack + p.defense + p.midfield) / 3.0
		avg_speed += float(p.speed)
		avg_talent += float(p.talent)
		avg_gap += float(p.potential_cap() - p.overall())
	avg_phys /= n
	avg_tech /= n
	avg_speed /= n
	avg_talent /= n
	avg_gap /= n

	var scores := {
		"fisico": (62.0 - avg_phys) * 1.2 + (60.0 - avg_speed) * 0.6,
		"tecnico": (62.0 - avg_tech) * 1.3,
		"tactico": (60.0 - avg_talent) * 0.9 + avg_gap * 0.5,
		"integral": avg_gap * 1.1,
	}
	var skill: int = int(coach.skill)
	## Un entrenador flojo tira al trabajo genérico; uno bueno detecta el cuello de botella.
	if skill < 50:
		scores["integral"] += 10.0
		scores["tecnico"] *= 0.8
	elif skill >= 70:
		var weakest: float = minf(avg_phys, minf(avg_tech, avg_speed))
		if avg_tech <= weakest + 1.0:
			scores["tecnico"] += 6.0 + float(skill) * 0.05
		if avg_phys <= weakest + 1.0:
			scores["fisico"] += 6.0 + float(skill) * 0.05

	var best_id := "integral"
	var best := -9999.0
	for pid in scores.keys():
		if float(scores[pid]) > best:
			best = float(scores[pid])
			best_id = str(pid)

	var conf := clampi(35 + skill / 2, 35, 95)
	var text := "Plan de %s (hab. %d, confianza %d%%):\nPropongo trabajar «%s».\nMargen medio de mejora de la camada: %.0f puntos.\nCon el plan activo, los chicos suben poco a poco cada jornada hasta su tope." % [
		coach.staff_name, skill, conf, plan_label(best_id), avg_gap
	]
	return {"ok": true, "plan_id": best_id, "confidence": conf, "text": text}


static func set_plan(club: Club, plan_id: String) -> String:
	if not has_coach(club):
		return "Necesitas un entrenador de fuerzas básicas."
	club.youth_plan = plan_id
	return "Plan de cantera fijado: %s." % plan_label(plan_id)


static func develop_matchday(club: Club, rng: RandomNumberGenerator) -> Array:
	## Progresión gradual con tope. Devuelve nombres de los que mejoraron.
	var coach = club.get_staff(StaffScript.Role.YOUTH)
	if club.youth_players.is_empty():
		return []
	var skill: int = int(coach.skill) if coach else 0
	var plan: String = club.youth_plan if coach else ""
	var improved: Array = []
	for p in club.youth_players:
		if p.injured:
			continue
		var cap := p.potential_cap()
		var gap := cap - p.overall()
		if gap <= 0:
			continue
		## Sin entrenador la mejora es lenta y azarosa; con plan es constante.
		var chance := 0.10 + float(skill) * 0.0045
		if plan != "":
			chance += 0.10
		## Cuanto más cerca del tope, más cuesta subir.
		chance *= clampf(float(gap) / 12.0, 0.25, 1.0)
		## Los más jóvenes progresan mejor.
		if p.age <= 16:
			chance += 0.05
		elif p.age >= 19:
			chance -= 0.04
		if rng.randf() > chance:
			continue
		var step := 1
		if skill >= 75 and rng.randf() < 0.3:
			step = 2
		_apply_growth(p, plan, step, cap, rng)
		improved.append(p.display_name())
	return improved


static func _apply_growth(p: Player, plan: String, step: int, cap: int, rng: RandomNumberGenerator) -> void:
	match plan:
		"fisico":
			p.physical = mini(cap, p.physical + step)
			p.strength = mini(cap, p.strength + step)
			if rng.randf() < 0.4:
				p.speed = mini(cap, p.speed + 1)
		"tecnico":
			match p.position:
				Player.Position.ATT:
					p.attack = mini(cap, p.attack + step)
				Player.Position.DEF, Player.Position.GK:
					p.defense = mini(cap, p.defense + step)
				_:
					p.midfield = mini(cap, p.midfield + step)
			if rng.randf() < 0.3:
				p.talent = mini(cap, p.talent + 1)
		"tactico":
			p.midfield = mini(cap, p.midfield + step)
			p.talent = mini(cap, p.talent + step)
		_:
			## Desarrollo integral o sin plan: reparto amplio pero más lento.
			var attrs := ["attack", "defense", "midfield", "physical", "speed", "strength"]
			var pick: String = attrs[rng.randi_range(0, attrs.size() - 1)]
			p.set(pick, mini(cap, int(p.get(pick)) + step))
	_refresh_market_data(p)


static func _refresh_market_data(p: Player) -> void:
	var ovr := p.overall()
	p.salary = maxi(p.salary, int(float(ovr * ovr) * 0.5) + 150)
	p.value = int(ovr * ovr * ovr * 0.9) + 10000
	if p.is_youth:
		p.value = int(float(p.value) * 0.6) + 5000


static func promote(club: Club, player_id: String) -> String:
	var p := club.get_youth_player(player_id)
	if p == null:
		return "Ese juvenil no está en la cantera."
	if p.age < PROMOTE_AGE:
		return "%s tiene %d años. Puede subir al primer equipo a partir de los %d." % [
			p.display_name(), p.age, PROMOTE_AGE
		]
	club.youth_players.erase(p)
	p.is_youth = false
	p.youth_eligible = p.age < RETURN_AGE_LIMIT
	p.club_id = club.id
	## Al subir cobra sueldo de primer equipo, aunque modesto.
	p.salary = maxi(p.salary, int(float(p.expected_salary()) * 0.6))
	club.players.append(p)
	if not club.bench_ids.has(p.id):
		club.bench_ids.append(p.id)
	return "%s sube al primer equipo." % p.display_name()


static func demote(club: Club, player_id: String) -> String:
	var p := club.get_player(player_id)
	if p == null:
		return "Ese jugador no está en el primer equipo."
	if not p.youth_eligible:
		return "%s ya no tiene edad de cantera." % p.display_name()
	if p.age >= RETURN_AGE_LIMIT:
		return "%s tiene %d años: solo pueden volver los menores de %d." % [
			p.display_name(), p.age, RETURN_AGE_LIMIT
		]
	if club.youth_players.size() >= MAX_SQUAD:
		return "La cantera está llena (%d)." % MAX_SQUAD
	if club.players.size() <= 16:
		return "Te quedarías con menos de 16 jugadores en el primer equipo."
	club.players.erase(p)
	club.lineup_ids.erase(p.id)
	club.bench_ids.erase(p.id)
	p.is_youth = true
	p.salary = maxi(200, int(float(p.salary) * 0.45))
	club.youth_players.append(p)
	club.ensure_default_lineup()
	return "%s regresa a fuerzas básicas." % p.display_name()


static func scouting_estimate(club: Club, p: Player) -> String:
	## Con mejor entrenador, la estimación del techo es más precisa.
	var coach = club.get_staff(StaffScript.Role.YOUTH)
	var cap := p.potential_cap()
	if coach == null:
		return "techo desconocido"
	var margin: int = clampi(12 - int(coach.skill) / 10, 1, 12)
	return "techo ~%d-%d" % [maxi(p.overall(), cap - margin), mini(95, cap + margin)]
