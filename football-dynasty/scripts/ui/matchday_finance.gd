extends Control

@onready var body: RichTextLabel = $Margin/Scroll/VBox/Body


func _ready() -> void:
	$Margin/Scroll/VBox/BtnContinue.pressed.connect(_on_continue)
	_fill()


func _fill() -> void:
	var f: Dictionary = GameState.last_matchday_finance
	if f.is_empty():
		body.text = "Sin resumen financiero de la jornada."
		return
	var net: int = int(f.get("net", 0))
	var net_color := "green" if net >= 0 else "red"
	var loan_line := ""
	if int(f.get("loan_payment", 0)) > 0 or int(f.get("loan_remaining", 0)) > 0:
		loan_line = "  Pago préstamo dueño: %s  (resta %s)\n" % [
			_money(int(f.get("loan_payment", 0))), _money(int(f.get("loan_remaining", 0)))
		]
	body.text = "[b]Ganancias y pérdidas — %s[/b]\n%s\n\n[b]Ingresos del partido[/b] (ya cobrados al finalizar)\n  Entradas / taquilla:  %s\n  Premio por resultado: %s\n  Subtotal partido:     %s\n\n[b]Contratos y derechos de la jornada[/b]\n  Televisión (%s):   %s\n  Radio (%s):        %s\n  Streaming (%s):    %s\n  Patrocinio (%s):   %s\n  Subtotal contratos/media: %s\n\n[b]Gastos[/b]\n  Sueldos jugadores: %s\n  Sueldos staff:     %s\n%s  Subtotal gastos:   %s\n\n────────────────────────\nBalance liquidación (media − gastos): [color=%s]%s[/color]\n\nPresupuesto antes de liquidar: %s\nPresupuesto actual: [b]%s[/b]" % [
		str(f.get("league_name", "")),
		"Liga MX" if int(f.get("tier", 2)) <= 1 else "Expansión MX",
		_money(int(f.get("gate", 0))),
		_money(int(f.get("prize", 0))),
		_money(int(f.get("match_income_total", 0))),
		str(f.get("tv_partner", "")), _money(int(f.get("tv", 0))),
		str(f.get("radio_partner", "")), _money(int(f.get("radio", 0))),
		str(f.get("streaming_partner", "")), _money(int(f.get("streaming", 0))),
		str(f.get("commercial_partner", "")), _money(int(f.get("commercial", 0))),
		_money(int(f.get("media_total", 0))),
		_money(int(f.get("player_wages", 0))),
		_money(int(f.get("staff_wages", 0))),
		loan_line,
		_money(int(f.get("expense_total", 0))),
		net_color,
		_money(net),
		_money(int(f.get("budget_before", 0))),
		_money(int(f.get("budget_after", 0))),
	]


func _on_continue() -> void:
	get_tree().change_scene_to_file("res://scenes/office/matchday_results.tscn")


func _money(n: int) -> String:
	return GameState.format_money(n)
