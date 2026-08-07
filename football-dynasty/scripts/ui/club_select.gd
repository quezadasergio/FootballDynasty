extends Control

@onready var list: ItemList = $Margin/Scroll/VBox/ClubList
@onready var info: Label = $Margin/Scroll/VBox/Info
@onready var filter_box: OptionButton = $Margin/Scroll/VBox/Filter
var _clubs: Array = []
var _filtered: Array = []


func _ready() -> void:
	$Margin/Scroll/VBox/Title.text = "Elige tu club"
	$Margin/Scroll/VBox/BtnStart.pressed.connect(_on_start)
	list.item_selected.connect(_on_selected)
	filter_box.clear()
	filter_box.add_item("Todas las ligas", 0)
	filter_box.add_item("Liga MX", 1)
	filter_box.add_item("Liga de Expansión MX", 2)
	filter_box.item_selected.connect(func(_i): _rebuild_list())
	_clubs = GameState.list_selectable_clubs()
	_rebuild_list()


func _rebuild_list() -> void:
	list.clear()
	_filtered.clear()
	var mode: int = filter_box.get_selected_id() if filter_box.selected >= 0 else 0
	for c in _clubs:
		var tier: int = int(c.get("tier", 2))
		if mode == 1 and tier != 1:
			continue
		if mode == 2 and tier != 2:
			continue
		_filtered.append(c)
		list.add_item("%s  ·  %s  ·  %s" % [
			c["name"], c.get("league_name", ""), _money(int(c["budget"]))
		])
	if _filtered.size() > 0:
		list.select(0)
		_on_selected(0)
	else:
		info.text = "No hay clubes en este filtro."


func _on_selected(index: int) -> void:
	if index < 0 or index >= _filtered.size():
		return
	var c: Dictionary = _filtered[index]
	var league_name: String = str(c.get("league_name", ""))
	var hint := "Empiezas en Liga MX. ¡Defiende el título o pelea el campeonato!"
	if int(c.get("tier", 2)) > 1:
		hint = "Empiezas en la Liga de Expansión MX. ¡A por el ascenso a Liga MX!"
	info.text = "%s (%s)\n%s\nEstadio: %d · Reputación: %d\n%s" % [
		c["name"], c["short_name"], league_name, c["stadium_capacity"], c["reputation"], hint
	]


func _on_start() -> void:
	var selected := list.get_selected_items()
	if selected.is_empty():
		return
	var c: Dictionary = _filtered[selected[0]]
	GameState.start_new_career(c["id"])
	GameState.save_game()
	get_tree().change_scene_to_file("res://scenes/office/office_hub.tscn")


func _money(n: int) -> String:
	return GameState.format_money(n)
