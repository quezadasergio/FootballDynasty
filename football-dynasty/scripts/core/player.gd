class_name Player
extends RefCounted

enum Position { GK, DEF, MID, ATT }

var id: String = ""
var first_name: String = ""
var last_name: String = ""
var age: int = 20
var position: Position = Position.MID
var attack: int = 50
var defense: int = 50
var midfield: int = 50
var physical: int = 50
var talent: int = 50
var speed: int = 50
var strength: int = 50
var morale: int = 70
var happiness: int = 70
var form: int = 70
var stamina: float = 100.0
var fatigue: float = 0.0
var salary: int = 1000
var value: int = 50000
var goals: int = 0
var assists: int = 0
var yellow_cards: int = 0
var red_cards: int = 0
var injured: bool = false
var club_id: String = ""
var matches_played: int = 0
var origin_region: String = ""
var nationality: String = "MEX" ## Código FIFA de 3 letras
## Parte médico
var injury_id: String = ""
var injury_name: String = ""
var injury_severity: int = 0 ## 1 leve · 2 media · 3 grave
var injury_matchdays: int = 0 ## jornadas de baja restantes
var injury_total: int = 0 ## jornadas de baja iniciales (para el parte)
var treatment: String = "" ## "" sin decidir · reposo · terapia · cirugia
## Cantera
var is_youth: bool = false
var youth_eligible: bool = false ## puede volver a la juvenil (menor de 19)
var potential: int = 0 ## tope de habilidad alcanzable


func display_name() -> String:
	var code := nationality if nationality != "" else "MEX"
	return "%s %s (%s)" % [first_name, last_name, code]


func potential_cap() -> int:
	if potential > 0:
		return potential
	return clampi(overall() + 6, 30, 95)


func injury_label() -> String:
	if not injured:
		return "Sano"
	if injury_name == "":
		return "Lesionado"
	var severities: Array[String] = ["", "leve", "media", "grave"]
	var sev: String = severities[clampi(injury_severity, 0, 3)]
	return "%s (%s) — %d jor. de baja" % [injury_name, sev, injury_matchdays]


func is_foreign() -> bool:
	return nationality != "" and nationality != "MEX"


func overall() -> int:
	var base := 50.0
	match position:
		Position.GK:
			base = defense * 0.4 + physical * 0.2 + strength * 0.15 + talent * 0.15 + midfield * 0.1
		Position.DEF:
			base = defense * 0.4 + strength * 0.2 + physical * 0.15 + speed * 0.1 + talent * 0.15
		Position.MID:
			base = midfield * 0.35 + attack * 0.15 + defense * 0.15 + speed * 0.15 + talent * 0.2
		Position.ATT:
			base = attack * 0.4 + speed * 0.2 + talent * 0.2 + physical * 0.1 + strength * 0.1
	var fatigue_pen := (100.0 - fatigue) / 100.0
	return int(base * (0.85 + fatigue_pen * 0.15))


func expected_salary() -> int:
	var ovr := overall()
	return int(ovr * ovr * 1.8) + 200


func performance_modifier() -> float:
	var f := 1.0 - fatigue / 180.0
	var m := 0.85 + morale / 400.0
	var h := 0.9 + happiness / 500.0
	var form_m := 0.8 + form / 250.0
	if injured:
		return 0.35
	return clampf(f * m * h * form_m, 0.55, 1.12)


func position_label() -> String:
	match position:
		Position.GK: return "POR"
		Position.DEF: return "DEF"
		Position.MID: return "MED"
		Position.ATT: return "DEL"
	return "?"


func apply_age_decline() -> void:
	if age < 30:
		return
	var steps := age - 29
	var loss := steps
	attack = maxi(20, attack - loss)
	defense = maxi(20, defense - loss)
	midfield = maxi(20, midfield - loss)
	physical = maxi(20, physical - loss)
	speed = maxi(18, speed - loss - 1)
	strength = maxi(20, strength - maxi(0, loss - 1))
	if age >= 33:
		talent = maxi(25, talent - 1)


func should_retire(rng: RandomNumberGenerator) -> bool:
	if age >= 38:
		return true
	if age >= 35:
		return rng.randf() < 0.35 + (age - 35) * 0.15
	if age >= 33:
		return rng.randf() < 0.08
	return false


func to_dict() -> Dictionary:
	return {
		"id": id,
		"first_name": first_name,
		"last_name": last_name,
		"age": age,
		"position": position,
		"attack": attack,
		"defense": defense,
		"midfield": midfield,
		"physical": physical,
		"talent": talent,
		"speed": speed,
		"strength": strength,
		"morale": morale,
		"happiness": happiness,
		"form": form,
		"stamina": stamina,
		"fatigue": fatigue,
		"salary": salary,
		"value": value,
		"goals": goals,
		"assists": assists,
		"yellow_cards": yellow_cards,
		"red_cards": red_cards,
		"injured": injured,
		"club_id": club_id,
		"matches_played": matches_played,
		"origin_region": origin_region,
		"nationality": nationality,
		"injury_id": injury_id,
		"injury_name": injury_name,
		"injury_severity": injury_severity,
		"injury_matchdays": injury_matchdays,
		"injury_total": injury_total,
		"treatment": treatment,
		"is_youth": is_youth,
		"youth_eligible": youth_eligible,
		"potential": potential,
	}


static func from_dict(d: Dictionary) -> Player:
	var p := Player.new()
	p.id = d.get("id", "")
	p.first_name = d.get("first_name", "")
	p.last_name = d.get("last_name", "")
	p.age = int(d.get("age", 20))
	p.position = int(d.get("position", Position.MID)) as Position
	p.attack = int(d.get("attack", 50))
	p.defense = int(d.get("defense", 50))
	p.midfield = int(d.get("midfield", 50))
	p.physical = int(d.get("physical", 50))
	p.talent = int(d.get("talent", d.get("physical", 50)))
	p.speed = int(d.get("speed", d.get("physical", 50)))
	p.strength = int(d.get("strength", d.get("physical", 50)))
	p.morale = int(d.get("morale", 70))
	p.happiness = int(d.get("happiness", d.get("morale", 70)))
	p.form = int(d.get("form", 70))
	p.stamina = float(d.get("stamina", 100.0))
	p.fatigue = float(d.get("fatigue", 0.0))
	p.salary = int(d.get("salary", 1000))
	p.value = int(d.get("value", 50000))
	p.goals = int(d.get("goals", 0))
	p.assists = int(d.get("assists", 0))
	p.yellow_cards = int(d.get("yellow_cards", 0))
	p.red_cards = int(d.get("red_cards", 0))
	p.injured = bool(d.get("injured", false))
	p.club_id = d.get("club_id", "")
	p.matches_played = int(d.get("matches_played", 0))
	p.origin_region = d.get("origin_region", "")
	p.nationality = str(d.get("nationality", "MEX")).to_upper()
	if p.nationality == "":
		p.nationality = "MEX"
	p.injury_id = str(d.get("injury_id", ""))
	p.injury_name = str(d.get("injury_name", ""))
	p.injury_severity = int(d.get("injury_severity", 0))
	p.injury_matchdays = int(d.get("injury_matchdays", 0))
	p.injury_total = int(d.get("injury_total", p.injury_matchdays))
	p.treatment = str(d.get("treatment", ""))
	p.is_youth = bool(d.get("is_youth", false))
	p.youth_eligible = bool(d.get("youth_eligible", false))
	p.potential = int(d.get("potential", 0))
	## Partidas viejas: lesión sin parte médico detallado.
	if p.injured and p.injury_matchdays <= 0:
		p.injury_id = "contractura"
		p.injury_name = "Molestia sin diagnosticar"
		p.injury_severity = 1
		p.injury_matchdays = 2
		p.injury_total = 2
	return p
