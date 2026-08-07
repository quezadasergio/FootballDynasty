extends Control

const Medical = preload("res://scripts/core/medical_service.gd")
const StaffScript = preload("res://scripts/core/staff_member.gd")

@onready var info: Label = $Margin/Scroll/VBox/Info
@onready var injured_list: ItemList = $Margin/Scroll/VBox/InjuredList
@onready var detail: RichTextLabel = $Margin/Scroll/VBox/Detail
@onready var treat_pick: OptionButton = $Margin/Scroll/VBox/TreatRow/TreatPick
@onready var status: Label = $Margin/Scroll/VBox/Status
@onready var report: RichTextLabel = $Margin/Scroll/VBox/Report

var _injured: Array = []
var _options: Array = []
var _selected_index: int = -1
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	injured_list.item_selected.connect(_on_selected)
	treat_pick.item_selected.connect(func(_i): _refresh_detail())
	$Margin/Scroll/VBox/TreatRow/BtnApply.pressed.connect(_on_apply)
	_populate()


func _populate() -> void:
	var club := GameState.player_club
	if club == null:
		return
	var doctor = club.get_staff(StaffScript.Role.DOCTOR)
	if doctor:
		info.text = "Médico: %s (hab. %d) · Presupuesto: %s\nUn médico con más nivel acorta las bajas, reduce recaídas y baja el riesgo quirúrgico." % [
			doctor.staff_name, doctor.skill, _money(club.budget)
		]
	else:
		info.text = "No tienes médico contratado. Contrata uno en la pantalla de Plantilla para decidir tratamientos."

	_injured.clear()
	injured_list.clear()
	for p in club.players:
		if p.injured:
			_injured.append(p)
	for p in club.youth_players:
		if p.injured:
			_injured.append(p)
	for p in _injured:
		var treat: String = "sin decidir"
		if p.treatment != "":
			treat = str(Medical.TREATMENT_LABELS.get(p.treatment, p.treatment))
		var tag := " [cantera]" if p.is_youth else ""
		injured_list.add_item("%s%s — %s · %s" % [p.display_name(), tag, p.injury_label(), treat])
		injured_list.set_item_metadata(injured_list.item_count - 1, p.id)

	report.text = Medical.infirmary_report(club)
	if _injured.is_empty():
		detail.text = "No hay lesionados. El cuerpo médico se dedica a la prevención."
		treat_pick.clear()
		return
	injured_list.select(0)
	_on_selected(0)


func _on_selected(index: int) -> void:
	if index < 0 or index >= _injured.size():
		return
	_selected_index = index
	var p: Player = _injured[index]
	_options = Medical.treatment_options(GameState.player_club, p)
	treat_pick.clear()
	for o in _options:
		var cost_txt := "sin costo"
		if int(o["cost"]) > 0:
			cost_txt = _money(int(o["cost"]))
			if bool(o.get("cost_is_per_matchday", false)):
				cost_txt += "/jornada"
		treat_pick.add_item("%s — %s · baja ~%d jor." % [
			o["label"], cost_txt, int(o["matchdays_estimate"])
		])
	_refresh_detail()


func _refresh_detail() -> void:
	if _selected_index < 0 or _selected_index >= _injured.size():
		return
	var p: Player = _injured[_selected_index]
	var text := "[b]%s[/b] · %d años — %s\nDiagnóstico: %s\nBaja restante: %d de %d jornadas\nTratamiento actual: %s\nValor de mercado: %s" % [
		p.display_name(), p.age, p.position_label(),
		p.injury_name,
		p.injury_matchdays, p.injury_total,
		str(Medical.TREATMENT_LABELS.get(p.treatment, "sin decidir")),
		_money(p.value),
	]
	if treat_pick.selected >= 0 and treat_pick.selected < _options.size():
		text += "\n\n%s" % str(_options[treat_pick.selected]["detail"])
	detail.text = text


func _on_apply() -> void:
	var sel := injured_list.get_selected_items()
	if sel.is_empty():
		status.text = "Selecciona un jugador lesionado."
		return
	if treat_pick.selected < 0 or treat_pick.selected >= _options.size():
		status.text = "Elige un tratamiento."
		return
	var p: Player = _injured[sel[0]]
	var option_id: String = str(_options[treat_pick.selected]["id"])
	status.text = Medical.apply_treatment(GameState.player_club, p, option_id, _rng)
	GameState.save_game()
	GameState.state_changed.emit()
	_populate()


func _money(n: int) -> String:
	return GameState.format_money(n)
