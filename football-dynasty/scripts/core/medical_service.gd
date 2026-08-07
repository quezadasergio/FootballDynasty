class_name MedicalService
extends RefCounted

const StaffScript = preload("res://scripts/core/staff_member.gd")

## Catálogo de lesiones. min/max son jornadas de baja antes de tratamiento.
const CATALOG: Array[Dictionary] = [
	{"id": "contractura", "name": "Contractura muscular", "severity": 1, "min": 1, "max": 2, "surgery": false},
	{"id": "esguince", "name": "Esguince de tobillo", "severity": 1, "min": 1, "max": 3, "surgery": false},
	{"id": "golpe", "name": "Golpe con edema", "severity": 1, "min": 1, "max": 2, "surgery": false},
	{"id": "conmocion", "name": "Conmoción cerebral", "severity": 1, "min": 2, "max": 3, "surgery": false},
	{"id": "desgarro", "name": "Desgarro muscular", "severity": 2, "min": 3, "max": 6, "surgery": false},
	{"id": "tendinitis", "name": "Tendinitis rotuliana", "severity": 2, "min": 3, "max": 7, "surgery": true},
	{"id": "pubalgia", "name": "Pubalgia", "severity": 2, "min": 4, "max": 8, "surgery": true},
	{"id": "menisco", "name": "Lesión de menisco", "severity": 3, "min": 8, "max": 13, "surgery": true},
	{"id": "ligamento", "name": "Rotura de ligamento cruzado", "severity": 3, "min": 14, "max": 22, "surgery": true},
	{"id": "fractura", "name": "Fractura de peroné", "severity": 3, "min": 10, "max": 17, "surgery": true},
]

const TREATMENT_LABELS := {
	"reposo": "Reposo",
	"terapia": "Tratamiento largo",
	"cirugia": "Cirugía",
}


static func entry(injury_id: String) -> Dictionary:
	for e in CATALOG:
		if e["id"] == injury_id:
			return e
	return CATALOG[0]


static func random_injury(rng: RandomNumberGenerator, in_match: bool = true) -> Dictionary:
	## Las lesiones de partido tienden a ser más graves que las de entrenamiento.
	var roll := rng.randf()
	var wanted_severity := 1
	if in_match:
		if roll > 0.92:
			wanted_severity = 3
		elif roll > 0.60:
			wanted_severity = 2
	else:
		if roll > 0.97:
			wanted_severity = 3
		elif roll > 0.75:
			wanted_severity = 2
	var pool: Array[Dictionary] = []
	for e in CATALOG:
		if int(e["severity"]) == wanted_severity:
			pool.append(e)
	return pool[rng.randi_range(0, pool.size() - 1)]


static func assign_injury(player: Player, rng: RandomNumberGenerator, in_match: bool = true) -> Dictionary:
	var e := random_injury(rng, in_match)
	var weeks := rng.randi_range(int(e["min"]), int(e["max"]))
	## Los veteranos tardan algo más en recuperarse.
	if player.age >= 32:
		weeks += 1
	player.injured = true
	player.injury_id = str(e["id"])
	player.injury_name = str(e["name"])
	player.injury_severity = int(e["severity"])
	player.injury_matchdays = weeks
	player.injury_total = weeks
	player.treatment = ""
	player.stamina = 0.0
	return e


static func therapy_cost_per_matchday(player: Player) -> int:
	return int(1800 + float(player.value) * 0.0035) * maxi(1, player.injury_severity)


static func surgery_cost(player: Player) -> int:
	return int(28000 + float(player.value) * 0.05) * maxi(1, player.injury_severity)


static func treatment_options(club: Club, player: Player) -> Array:
	## Cada opción: {id, label, detail, cost, matchdays_estimate}
	if not player.injured:
		return []
	var e := entry(player.injury_id)
	var doctor = club.get_staff(StaffScript.Role.DOCTOR)
	var doc_skill: int = int(doctor.skill) if doctor else 0
	var opts: Array = []

	opts.append({
		"id": "reposo",
		"label": "Reposo",
		"detail": "Sin costo. Recuperación natural, con riesgo de recaída.",
		"cost": 0,
		"matchdays_estimate": player.injury_matchdays,
	})

	var therapy_md: int = maxi(1, int(ceil(float(player.injury_matchdays) * (0.78 - float(doc_skill) * 0.0015))))
	opts.append({
		"id": "terapia",
		"label": "Tratamiento largo",
		"detail": "Fisioterapia continua: %s por jornada mientras esté de baja. Menos riesgo de recaída." % [
			GameState.format_money(therapy_cost_per_matchday(player))
		],
		"cost": therapy_cost_per_matchday(player),
		"cost_is_per_matchday": true,
		"matchdays_estimate": therapy_md,
	})

	if bool(e["surgery"]):
		var surgery_md: int = maxi(2, int(ceil(float(player.injury_matchdays) * (0.55 - float(doc_skill) * 0.0018))))
		var risk: int = clampi(30 - doc_skill / 4, 4, 30)
		opts.append({
			"id": "cirugia",
			"label": "Cirugía",
			"detail": "Pago único. Corta mucho la baja, pero hay %d%% de riesgo de complicación (más jornadas fuera)." % risk,
			"cost": surgery_cost(player),
			"matchdays_estimate": surgery_md,
			"risk": risk,
		})
	return opts


static func apply_treatment(club: Club, player: Player, option_id: String, rng: RandomNumberGenerator) -> String:
	if not player.injured:
		return "%s no está lesionado." % player.display_name()
	if player.treatment != "":
		return "Ya se decidió un tratamiento para %s (%s)." % [
			player.display_name(), str(TREATMENT_LABELS.get(player.treatment, player.treatment))
		]
	var doctor = club.get_staff(StaffScript.Role.DOCTOR)
	if doctor == null:
		return "Necesitas un médico contratado para decidir un tratamiento."
	var opts := treatment_options(club, player)
	var chosen: Dictionary = {}
	for o in opts:
		if str(o["id"]) == option_id:
			chosen = o
			break
	if chosen.is_empty():
		return "Ese tratamiento no está disponible para esta lesión."

	match option_id:
		"reposo":
			player.treatment = "reposo"
			return "%s seguirá con reposo. Baja estimada: %d jornadas." % [
				player.display_name(), player.injury_matchdays
			]
		"terapia":
			player.treatment = "terapia"
			player.injury_matchdays = int(chosen["matchdays_estimate"])
			return "%s entra en tratamiento largo. Baja estimada: %d jornadas (%s por jornada)." % [
				player.display_name(), player.injury_matchdays,
				GameState.format_money(int(chosen["cost"]))
			]
		"cirugia":
			var cost: int = int(chosen["cost"])
			if club.budget < cost:
				return "Presupuesto insuficiente para la cirugía (cuesta %s)." % GameState.format_money(cost)
			club.budget -= cost
			club.medical_acc += cost
			player.treatment = "cirugia"
			var risk: float = float(int(chosen.get("risk", 15))) / 100.0
			if rng.randf() < risk:
				player.injury_matchdays = int(chosen["matchdays_estimate"]) + rng.randi_range(2, 5)
				return "Cirugía de %s con complicaciones. Baja estimada: %d jornadas." % [
					player.display_name(), player.injury_matchdays
				]
			player.injury_matchdays = int(chosen["matchdays_estimate"])
			return "Cirugía de %s exitosa. Baja estimada: %d jornadas." % [
				player.display_name(), player.injury_matchdays
			]
	return "Tratamiento desconocido."


static func tick_matchday(club: Club, rng: RandomNumberGenerator) -> Dictionary:
	## Avanza recuperaciones y cobra tratamientos. Devuelve resumen para el P&L y noticias.
	var doctor = club.get_staff(StaffScript.Role.DOCTOR)
	var doc_skill: int = int(doctor.skill) if doctor else 0
	var cost := 0
	var recovered: Array[String] = []
	var relapsed: Array[String] = []
	var all: Array = []
	all.append_array(club.players)
	all.append_array(club.youth_players)
	for p in all:
		if not p.injured:
			continue
		if p.treatment == "" and doctor != null:
			## Sin decisión del cuerpo técnico, el médico aplica reposo.
			p.treatment = "reposo"
		if p.treatment == "terapia":
			cost += therapy_cost_per_matchday(p)
		p.injury_matchdays -= 1
		## Un buen médico acelera la recuperación.
		if doc_skill > 0 and rng.randf() < float(doc_skill) / 190.0:
			p.injury_matchdays -= 1
		if p.injury_matchdays > 0:
			continue
		var relapse_chance := 0.0
		match p.treatment:
			"reposo":
				relapse_chance = 0.05 + float(p.injury_severity) * 0.035
			"terapia":
				relapse_chance = 0.02 + float(p.injury_severity) * 0.012
			"cirugia":
				relapse_chance = 0.01
		relapse_chance = maxf(0.0, relapse_chance - float(doc_skill) * 0.0004)
		if rng.randf() < relapse_chance:
			p.injury_matchdays = maxi(1, int(round(float(p.injury_total) * 0.4)))
			p.treatment = ""
			relapsed.append(p.display_name())
			continue
		p.injured = false
		p.injury_id = ""
		p.injury_name = ""
		p.injury_severity = 0
		p.injury_matchdays = 0
		p.injury_total = 0
		p.treatment = ""
		p.fatigue = maxf(0.0, p.fatigue - 15.0)
		recovered.append(p.display_name())
	if cost > 0:
		club.budget -= cost
		club.medical_acc += cost
	return {"cost": cost, "recovered": recovered, "relapsed": relapsed}


static func infirmary_report(club: Club) -> String:
	var doctor = club.get_staff(StaffScript.Role.DOCTOR)
	var injured: Array = []
	for p in club.players:
		if p.injured:
			injured.append(p)
	for p in club.youth_players:
		if p.injured:
			injured.append(p)
	if injured.is_empty():
		return "Enfermería vacía: no hay lesionados."
	var header := "Sin médico contratado: no puedes decidir tratamientos."
	if doctor:
		header = "Parte del Dr. %s (hab. %d)" % [doctor.staff_name, doctor.skill]
	var lines: PackedStringArray = [header, ""]
	for p in injured:
		var treat: String = "sin decidir"
		if p.treatment != "":
			treat = str(TREATMENT_LABELS.get(p.treatment, p.treatment))
		var tag := " [cantera]" if p.is_youth else ""
		lines.append("%s%s\n   %s · Tratamiento: %s" % [p.display_name(), tag, p.injury_label(), treat])
	return "\n".join(lines)
