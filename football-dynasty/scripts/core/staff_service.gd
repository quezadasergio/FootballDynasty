class_name StaffService
extends RefCounted

const FormationUtil = preload("res://scripts/core/formation.gd")
const StaffScript = preload("res://scripts/core/staff_member.gd")

const TRAINING_TYPES := [
	{"id": "recovery", "label": "Recuperación"},
	{"id": "endurance", "label": "Resistencia"},
	{"id": "strength", "label": "Fuerza"},
	{"id": "speed", "label": "Velocidad"},
	{"id": "technical", "label": "Técnico"},
	{"id": "tactical", "label": "Táctico"},
]

const REGIONS := ["América", "Europa", "Asia", "África", "Oceanía"]


static func _training_label(training_id: String) -> String:
	for t in TRAINING_TYPES:
		if t["id"] == training_id:
			return t["label"]
	return training_id


## Analiza la plantilla y sugiere un entrenamiento. Más habilidad = mejor diagnóstico y mejores efectos al aplicar.
static func fitness_advice(club: Club) -> Dictionary:
	var fitness = club.get_staff(StaffScript.Role.FITNESS)
	if fitness == null:
		return {"ok": false, "text": "Contrata un preparador físico para recibir asesoría de entrenamiento."}
	var active: Array = []
	for p in club.players:
		if not p.injured:
			active.append(p)
	if active.is_empty():
		return {"ok": false, "text": "No hay jugadores disponibles para entrenar."}

	var n: float = float(active.size())
	var avg_fatigue := 0.0
	var avg_form := 0.0
	var avg_speed := 0.0
	var avg_strength := 0.0
	var avg_physical := 0.0
	var avg_talent := 0.0
	var avg_tech := 0.0
	for p in active:
		avg_fatigue += p.fatigue
		avg_form += float(p.form)
		avg_speed += float(p.speed)
		avg_strength += float(p.strength)
		avg_physical += float(p.physical)
		avg_talent += float(p.talent)
		avg_tech += float(p.attack + p.defense + p.midfield) / 3.0
	avg_fatigue /= n
	avg_form /= n
	avg_speed /= n
	avg_strength /= n
	avg_physical /= n
	avg_talent /= n
	avg_tech /= n

	var scores := {
		"recovery": avg_fatigue * 1.4 + (20.0 if avg_fatigue >= 55.0 else 0.0),
		"endurance": (70.0 - avg_physical) * 1.1 + avg_fatigue * 0.15,
		"strength": (70.0 - avg_strength) * 1.15,
		"speed": (70.0 - avg_speed) * 1.15,
		"technical": (72.0 - avg_tech) * 1.05 + (68.0 - avg_talent) * 0.4,
		"tactical": (72.0 - avg_form) * 1.2,
	}
	# Preparadores flojos priorizan mal o se quedan en lo básico
	var skill: int = int(fitness.skill)
	if skill < 45:
		scores["recovery"] += 8.0
		scores["technical"] *= 0.7
		scores["tactical"] *= 0.75
	elif skill < 60:
		scores["endurance"] += 4.0
		scores["technical"] *= 0.9
	else:
		# Los buenos detectan mejor cuellos de botella
		var weakest: float = minf(avg_speed, minf(avg_strength, minf(avg_physical, avg_tech)))
		if avg_speed <= weakest + 1.0:
			scores["speed"] += 6.0 + skill * 0.04
		if avg_strength <= weakest + 1.0:
			scores["strength"] += 6.0 + skill * 0.04
		if avg_tech <= weakest + 1.0:
			scores["technical"] += 5.0 + skill * 0.05
		if avg_form < 58.0:
			scores["tactical"] += 5.0 + skill * 0.04
		if avg_fatigue >= 50.0:
			scores["recovery"] += 4.0 + skill * 0.03

	var ranked: Array = []
	for tid in scores.keys():
		ranked.append({"id": tid, "score": float(scores[tid])})
	ranked.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["score"] > b["score"])

	var pick: Dictionary = ranked[0]
	# Con poca habilidad, a veces elige la 2ª opción
	if skill < 50 and ranked.size() > 1 and randf() > skill / 80.0:
		pick = ranked[1]

	var conf := clampi(35 + skill / 2, 35, 96)
	var reason := _fitness_reason(str(pick["id"]), avg_fatigue, avg_form, avg_speed, avg_strength, avg_physical, avg_tech)
	var text := "Asesoría de %s (hab. %d, confianza %d%%):\nSugiero entrenamiento «%s».\n%s\nCon más nivel, el trabajo rinde más al aplicarlo." % [
		fitness.staff_name, skill, conf, _training_label(str(pick["id"])), reason
	]
	return {
		"ok": true,
		"training_id": str(pick["id"]),
		"confidence": conf,
		"text": text,
	}


static func _fitness_reason(tid: String, fatigue: float, form: float, speed: float, strength: float, physical: float, tech: float) -> String:
	match tid:
		"recovery":
			return "La fatiga media está en %.0f; conviene recuperar antes de exigir." % fatigue
		"endurance":
			return "El físico medio (%.0f) pide trabajo de resistencia." % physical
		"strength":
			return "La fuerza media (%.0f) es el punto más mejorable ahora." % strength
		"speed":
			return "La velocidad media (%.0f) está por debajo del resto." % speed
		"technical":
			return "El bloque técnico (%.0f) puede subir con trabajo de calidad." % tech
		"tactical":
			return "La forma media (%.0f) mejorará con sesión táctica." % form
	return "Es la sesión más equilibrada para el momento del equipo."


static func apply_training(club: Club, training_id: String, use_coach_peak: bool = false) -> String:
	var fitness = club.get_staff(StaffScript.Role.FITNESS)
	if fitness == null:
		return "Necesitas un preparador físico contratado."
	if club.trained_this_matchday:
		return "Ya entrenaste esta jornada."
	var skill: int = int(fitness.skill)
	var boost := 1 + int(skill / 35)
	if use_coach_peak:
		# Al aplicar su propia sugerencia, rinde según capacidad real
		boost = 1 + int(skill / 28)
		if skill >= 70:
			boost += 1
		if skill >= 85:
			boost += 1
	var fatigue_extra: float = 0.0
	if use_coach_peak and skill >= 65:
		fatigue_extra = -skill * 0.04  # sesiones mejor dirigidas cansan un poco menos
	var touched := 0
	var talent_hits := 0
	for p in club.players:
		if p.injured:
			continue
		touched += 1
		match training_id:
			"recovery":
				var heal: float = 12.0 + skill * 0.18
				if use_coach_peak:
					heal += skill * 0.08
				p.fatigue = maxf(0.0, p.fatigue - heal)
				p.stamina = minf(100.0, p.stamina + 10.0 + (2.0 if use_coach_peak and skill >= 60 else 0.0))
			"endurance":
				var gain := boost if randf() < (0.45 + skill / 200.0) else maxi(0, boost - 1)
				if gain > 0:
					p.physical = mini(95, p.physical + gain)
				p.fatigue = minf(100.0, p.fatigue + 8.0 + (100 - skill) * 0.05 + fatigue_extra)
			"strength":
				p.strength = mini(95, p.strength + boost)
				p.fatigue = minf(100.0, p.fatigue + 10.0 + fatigue_extra)
			"speed":
				p.speed = mini(95, p.speed + boost)
				p.fatigue = minf(100.0, p.fatigue + 9.0 + fatigue_extra)
			"technical":
				match p.position:
					Player.Position.ATT:
						p.attack = mini(95, p.attack + boost)
					Player.Position.DEF:
						p.defense = mini(95, p.defense + boost)
					Player.Position.GK:
						p.defense = mini(95, p.defense + boost)
					_:
						p.midfield = mini(95, p.midfield + boost)
				var talent_chance: float = skill / 120.0
				if use_coach_peak:
					talent_chance += skill / 250.0
				if randf() < talent_chance:
					p.talent = mini(95, p.talent + 1)
					talent_hits += 1
				p.fatigue = minf(100.0, p.fatigue + 7.0 + fatigue_extra)
			"tactical":
				p.midfield = mini(95, p.midfield + maxi(1, boost - 1))
				p.form = clampi(p.form + 2 + int(skill / 40) + (1 if use_coach_peak and skill >= 70 else 0), 40, 95)
				p.fatigue = minf(100.0, p.fatigue + 6.0 + fatigue_extra)
			_:
				p.fatigue = minf(100.0, p.fatigue + 5.0)
	club.trained_this_matchday = true
	var extra := ""
	if use_coach_peak:
		extra = " (sesión dirigida por el preparador)"
		if talent_hits > 0:
			extra += " · +talento en %d jugadores" % talent_hits
	return "Entrenamiento «%s» aplicado a %d jugadores (nivel prep. %d).%s" % [_training_label(training_id), touched, skill, extra]


static func doctor_checkup(club: Club) -> String:
	var doctor = club.get_staff(StaffScript.Role.DOCTOR)
	if doctor == null:
		return "Contrata un médico para la revisión."
	var healed := 0
	var rested := 0
	var lines: PackedStringArray = []
	var shown := 0
	for p in club.players:
		var line := "%s: cansancio %.0f" % [p.display_name(), p.fatigue]
		if p.injured:
			line += " · LESIONADO"
			if randf() < doctor.skill / 130.0:
				p.injured = false
				healed += 1
				line += " → recuperado"
		var reduce: float = 6.0 + float(doctor.skill) * 0.12
		if p.fatigue > 0:
			p.fatigue = maxf(0.0, p.fatigue - reduce)
			rested += 1
		if p.fatigue >= 75:
			line += " · ALERTA fatiga"
		if shown < 8:
			lines.append(line)
			shown += 1
	return "Revisión del Dr. %s (hab. %d)\nCuraciones: %d · Aliviados: %d\n\n%s" % [
		doctor.staff_name, doctor.skill, healed, rested, "\n".join(lines)
	]


static func assistant_advice(club: Club) -> Dictionary:
	var assistant = club.get_staff(StaffScript.Role.ASSISTANT)
	if assistant == null:
		return {"ok": false, "text": "Contrata un auxiliar técnico para recibir asesoría."}
	var avail := {
		Player.Position.GK: 0,
		Player.Position.DEF: 0,
		Player.Position.MID: 0,
		Player.Position.ATT: 0,
	}
	var strength := {
		Player.Position.GK: 0.0,
		Player.Position.DEF: 0.0,
		Player.Position.MID: 0.0,
		Player.Position.ATT: 0.0,
	}
	for p in club.players:
		if p.injured or p.fatigue >= 85:
			continue
		avail[p.position] = int(avail[p.position]) + 1
		strength[p.position] = float(strength[p.position]) + p.overall() * p.performance_modifier()

	var best_id := "442"
	var best_score := -9999.0
	for fid in FormationUtil.ids():
		var need: Dictionary = FormationUtil.counts(fid)
		var score := 0.0
		score += mini(int(avail[1]), int(need[1])) * 12.0
		score += mini(int(avail[2]), int(need[2])) * 12.0
		score += mini(int(avail[3]), int(need[3])) * 12.0
		score -= maxi(0, int(need[1]) - int(avail[1])) * 18.0
		score -= maxi(0, int(need[2]) - int(avail[2])) * 18.0
		score -= maxi(0, int(need[3]) - int(avail[3])) * 18.0
		if int(need[3]) >= 3:
			score += float(strength[3]) * 0.08
		if int(need[1]) >= 5:
			score += float(strength[1]) * 0.08
		if int(need[2]) >= 5:
			score += float(strength[2]) * 0.07
		score += assistant.skill * 0.05
		if score > best_score:
			best_score = score
			best_id = fid

	var att_power: float = float(strength[3]) + float(strength[2]) * 0.4
	var def_power: float = float(strength[1]) + float(strength[0]) + float(strength[2]) * 0.3
	var mentality := 1
	var ment_label := "Normal"
	if att_power > def_power * 1.15:
		mentality = 2
		ment_label = "Ofensiva"
	elif def_power > att_power * 1.15:
		mentality = 0
		ment_label = "Defensiva"

	var conf := clampi(40 + int(assistant.skill / 2), 40, 95)
	var text := "Asesoría de %s (hab. %d, confianza %d%%):\nTe recomiendo formación %s y mentalidad %s, según tus efectivos disponibles y su estado." % [
		assistant.staff_name, assistant.skill, conf, FormationUtil.label(best_id), ment_label
	]
	return {"ok": true, "formation_id": best_id, "mentality": mentality, "text": text}


static func maybe_scout_find(club: Club, rng: RandomNumberGenerator) -> Dictionary:
	var scout = club.get_staff(StaffScript.Role.SCOUT)
	if scout == null:
		return {}
	var chance: float = 0.12 + float(scout.skill) / 250.0
	if rng.randf() > chance:
		return {}
	var region: String = REGIONS[rng.randi_range(0, REGIONS.size() - 1)]
	return {"region": region, "scout_skill": scout.skill}
