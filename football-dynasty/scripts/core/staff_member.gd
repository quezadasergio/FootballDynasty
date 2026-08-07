extends RefCounted

enum Role { ASSISTANT, FITNESS, DOCTOR, SCOUT, YOUTH, LEGAL }

const ALL_ROLES: Array[int] = [
	Role.ASSISTANT, Role.FITNESS, Role.DOCTOR, Role.SCOUT, Role.YOUTH, Role.LEGAL
]

var id: String = ""
var staff_name: String = ""
var role: int = Role.ASSISTANT
var skill: int = 50
var wage: int = 1000


func role_label() -> String:
	return label_for_role(role)


static func label_for_role(role_value: int) -> String:
	match role_value:
		Role.ASSISTANT: return "Auxiliar técnico"
		Role.FITNESS: return "Preparador físico"
		Role.DOCTOR: return "Médico"
		Role.SCOUT: return "Scouter"
		Role.YOUTH: return "Entrenador de fuerzas básicas"
		Role.LEGAL: return "Consejero legal y financiero"
	return "Staff"


static func role_from_key(key: String) -> int:
	match key:
		"assistant": return Role.ASSISTANT
		"fitness": return Role.FITNESS
		"doctor": return Role.DOCTOR
		"scout": return Role.SCOUT
		"youth": return Role.YOUTH
		"legal": return Role.LEGAL
	return Role.ASSISTANT


static func role_key(role_value: int) -> String:
	match role_value:
		Role.ASSISTANT: return "assistant"
		Role.FITNESS: return "fitness"
		Role.DOCTOR: return "doctor"
		Role.SCOUT: return "scout"
		Role.YOUTH: return "youth"
		Role.LEGAL: return "legal"
	return "assistant"


static func wage_for_skill(skill_value: int) -> int:
	return int(skill_value * skill_value * 0.55) + 400


static func generate(role_value: int, skill_value: int, first: String, last: String, counter: int):
	var s = new()
	s.id = "st_%s_%d" % [role_key(role_value), counter]
	s.staff_name = "%s %s" % [first, last]
	s.role = role_value
	s.skill = clampi(skill_value, 30, 95)
	s.wage = wage_for_skill(s.skill)
	return s


func to_dict() -> Dictionary:
	return {
		"id": id,
		"staff_name": staff_name,
		"role": role_key(role),
		"skill": skill,
		"wage": wage,
	}


static func from_dict(d: Dictionary):
	var s = new()
	s.id = d.get("id", "")
	s.staff_name = d.get("staff_name", "")
	s.role = role_from_key(str(d.get("role", "assistant")))
	s.skill = int(d.get("skill", 50))
	s.wage = int(d.get("wage", wage_for_skill(s.skill)))
	return s
