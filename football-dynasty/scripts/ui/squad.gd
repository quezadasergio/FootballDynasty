extends Control

const StaffSvc = preload("res://scripts/core/staff_service.gd")
const StaffScript = preload("res://scripts/core/staff_member.gd")
const Youth = preload("res://scripts/core/youth_service.gd")

@onready var list: ItemList = $Margin/Scroll/HBox/Left/PlayerList
@onready var detail: RichTextLabel = $Margin/Scroll/HBox/Left/Detail
@onready var staff_list: ItemList = $Margin/Scroll/HBox/Right/StaffList
@onready var staff_info: Label = $Margin/Scroll/HBox/Right/StaffInfo
@onready var hire_role: OptionButton = $Margin/Scroll/HBox/Right/HireRow/HireRole
@onready var hire_pick: OptionButton = $Margin/Scroll/HBox/Right/HireRow/HirePick
@onready var training_type: OptionButton = $Margin/Scroll/HBox/Right/TrainRow/TrainingType
@onready var train_msg: Label = $Margin/Scroll/HBox/Right/TrainMsg
@onready var fitness_advice_label: Label = $Margin/Scroll/HBox/Right/FitnessAdvice
@onready var doctor_report: RichTextLabel = $Margin/Scroll/HBox/Right/DoctorReport
@onready var squad_msg: Label = $Margin/Scroll/HBox/Left/SquadMsg

var _hire_candidates: Array = []
var _last_fitness_advice: Dictionary = {}


func _ready() -> void:
	list.item_selected.connect(_on_selected)
	hire_role.clear()
	for role in StaffScript.ALL_ROLES:
		hire_role.add_item(StaffScript.label_for_role(role), role)
	hire_role.item_selected.connect(_on_hire_role)
	$Margin/Scroll/HBox/Left/BtnContracts.pressed.connect(_on_open_contracts)
	$Margin/Scroll/HBox/Left/BtnYouth.pressed.connect(_on_open_youth)
	$Margin/Scroll/HBox/Left/BtnDemote.pressed.connect(_on_demote)
	$Margin/Scroll/HBox/Right/BtnInfirmary.pressed.connect(_on_open_infirmary)
	training_type.clear()
	for t in StaffSvc.TRAINING_TYPES:
		training_type.add_item(t["label"])
		training_type.set_item_metadata(training_type.item_count - 1, t["id"])
	$Margin/Scroll/HBox/Right/HireRow/BtnHire.pressed.connect(_on_hire)
	$Margin/Scroll/HBox/Right/BtnFire.pressed.connect(_on_fire)
	$Margin/Scroll/HBox/Right/TrainRow/BtnTrain.pressed.connect(_on_train)
	$Margin/Scroll/HBox/Right/BtnAskFitness.pressed.connect(_on_ask_fitness)
	$Margin/Scroll/HBox/Right/BtnApplyFitnessAdvice.pressed.connect(_on_apply_fitness_advice)
	$Margin/Scroll/HBox/Right/BtnDoctor.pressed.connect(_on_doctor)
	_on_hire_role(0)
	_populate()


func _populate() -> void:
	list.clear()
	var club := GameState.player_club
	if club == null:
		return
	var sorted := club.players.duplicate()
	sorted.sort_custom(func(a: Player, b: Player) -> bool:
		if a.position != b.position:
			return a.position < b.position
		return a.overall() > b.overall()
	)
	for p in sorted:
		var flag := ""
		if club.lineup_ids.has(p.id):
			flag = " [XI]"
		elif club.bench_ids.has(p.id):
			flag = " [BAN]"
		if p.injured:
			flag += " LES%d" % p.injury_matchdays
		if p.fatigue >= 75:
			flag += " CAN"
		if p.youth_eligible:
			flag += " JUV"
		if not p.has_contract():
			flag += " SIN CONTRATO"
		elif p.contract_years_left <= 1:
			flag += " ÚLTIMO AÑO"
		if p.transfer_listed:
			flag += " TRANSF"
		list.add_item("%s %s OVR%d%s" % [p.position_label(), p.display_name(), p.overall(), flag])
		list.set_item_metadata(list.item_count - 1, p.id)
		if not p.has_contract():
			list.set_item_custom_fg_color(list.item_count - 1, Color(1.0, 0.45, 0.4))
	if list.item_count > 0:
		list.select(0)
		_on_selected(0)
	_refresh_staff()


func _refresh_staff() -> void:
	staff_list.clear()
	var club := GameState.player_club
	for role in StaffScript.ALL_ROLES:
		var s = club.get_staff(role)
		if s:
			staff_list.add_item("%s: %s · hab.%d · %s/jornada" % [s.role_label(), s.staff_name, s.skill, _money(s.wage)])
		else:
			staff_list.add_item("%s: (vacante)" % StaffScript.label_for_role(role))
		staff_list.set_item_metadata(staff_list.item_count - 1, StaffScript.role_key(role))
	staff_info.text = "Nómina staff: %s/jornada · Entrenamiento jornada: %s\nLos aspirantes se renuevan al cambiar de jornada." % [
		_money(club.staff_wage_bill()),
		"ya hecho" if club.trained_this_matchday else "disponible",
	]


func _on_selected(index: int) -> void:
	var pid: String = list.get_item_metadata(index)
	var p := GameState.player_club.get_player(pid)
	if p == null:
		return
	var youth_line := ""
	if p.youth_eligible:
		youth_line = "\nPuede regresar a fuerzas básicas (menor de %d años)" % Youth.RETURN_AGE_LIMIT
	detail.text = "[b]%s[/b] · %d años — %s\nAtaque %d · Defensa %d · Medio %d · Físico %d\nTalento %d · Velocidad %d · Fuerza %d\nÁnimo %d · Felicidad club %d · Forma %d\nCansancio %.0f · Resistencia %.0f\nEstado: %s\nSalario %s/jornada (%s al año) · Valor %s\nContrato: %s%s\nPartidos temp. %d · Goles %d · Asist. %d%s" % [
		p.display_name(), p.age, p.position_label(),
		p.attack, p.defense, p.midfield, p.physical,
		p.talent, p.speed, p.strength,
		p.morale, p.happiness, p.form,
		p.fatigue, p.stamina, p.injury_label(),
		_money(p.salary), _money(p.annual_salary()), _money(p.value),
		p.contract_label(),
		"  ·  en transferibles" if p.transfer_listed else "",
		p.matches_played, p.goals, p.assists,
		youth_line,
	]


func _on_hire_role(_index: int) -> void:
	## La lista de aspirantes viene de la bolsa de la jornada, no se regenera al cambiar de puesto.
	var role: int = hire_role.get_item_id(hire_role.selected)
	_hire_candidates = GameState.candidates_for_role(role)
	hire_pick.clear()
	for i in _hire_candidates.size():
		var s = _hire_candidates[i]
		hire_pick.add_item("%s · hab.%d · %s/jornada" % [s.staff_name, s.skill, _money(s.wage)])
		hire_pick.set_item_metadata(i, i)


func _on_hire() -> void:
	if _hire_candidates.is_empty():
		return
	var idx: int = int(hire_pick.get_item_metadata(hire_pick.selected)) if hire_pick.item_count > 0 else 0
	var member = _hire_candidates[idx]
	var err := GameState.player_club.hire_staff(member)
	if err != "":
		staff_info.text = err
		return
	staff_info.text = "Contratado: %s (%s)" % [member.staff_name, member.role_label()]
	GameState.remove_staff_candidate(member.role, member)
	GameState.save_game()
	_refresh_staff()
	_on_hire_role(hire_role.selected)


func _on_fire() -> void:
	var sel := staff_list.get_selected_items()
	if sel.is_empty():
		staff_info.text = "Selecciona un puesto del staff."
		return
	var key: String = staff_list.get_item_metadata(sel[0])
	var role = StaffScript.role_from_key(key)
	if GameState.player_club.get_staff(role) == null:
		staff_info.text = "Ese puesto está vacante."
		return
	GameState.player_club.fire_staff(role)
	staff_info.text = "Staff despedido."
	GameState.save_game()
	_refresh_staff()


func _on_train() -> void:
	var tid: String = str(training_type.get_item_metadata(training_type.selected))
	var msg := StaffSvc.apply_training(GameState.player_club, tid, false)
	train_msg.text = msg
	_populate()


func _on_ask_fitness() -> void:
	_last_fitness_advice = StaffSvc.fitness_advice(GameState.player_club)
	fitness_advice_label.text = str(_last_fitness_advice.get("text", ""))
	if bool(_last_fitness_advice.get("ok", false)):
		_select_training(str(_last_fitness_advice["training_id"]))


func _on_apply_fitness_advice() -> void:
	if _last_fitness_advice.is_empty() or not bool(_last_fitness_advice.get("ok", false)):
		_on_ask_fitness()
	if not bool(_last_fitness_advice.get("ok", false)):
		return
	var tid: String = str(_last_fitness_advice["training_id"])
	_select_training(tid)
	var msg := StaffSvc.apply_training(GameState.player_club, tid, true)
	train_msg.text = msg
	fitness_advice_label.text = str(_last_fitness_advice.get("text", "")) + "\n" + msg
	_populate()


func _select_training(training_id: String) -> void:
	for i in training_type.item_count:
		if str(training_type.get_item_metadata(i)) == training_id:
			training_type.select(i)
			return


func _on_doctor() -> void:
	doctor_report.text = StaffSvc.doctor_checkup(GameState.player_club)
	_populate()


func _on_open_contracts() -> void:
	get_tree().change_scene_to_file("res://scenes/office/contracts.tscn")


func _on_open_youth() -> void:
	get_tree().change_scene_to_file("res://scenes/office/youth.tscn")


func _on_open_infirmary() -> void:
	get_tree().change_scene_to_file("res://scenes/office/infirmary.tscn")


func _on_demote() -> void:
	var sel := list.get_selected_items()
	if sel.is_empty():
		squad_msg.text = "Selecciona un jugador de la plantilla."
		return
	var pid: String = list.get_item_metadata(sel[0])
	squad_msg.text = Youth.demote(GameState.player_club, pid)
	GameState.save_game()
	_populate()


func _money(n: int) -> String:
	return GameState.format_money(n)
