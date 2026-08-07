extends Control

## Pixel highlight presenter: simple pitch + silhouettes reacting to MatchEvent types.

@onready var pitch: ColorRect = $Pitch
@onready var ball: ColorRect = $Ball
@onready var label: Label = $Label
@onready var home_sprite: ColorRect = $HomePlayer
@onready var away_sprite: ColorRect = $AwayPlayer

var _tween: Tween


func _ready() -> void:
	_reset_positions()


func play_event(event: MatchEvent, home_color: Color, away_color: Color) -> void:
	home_sprite.color = home_color
	away_sprite.color = away_color
	label.text = "%d'  %s" % [event.minute, event.text]
	if _tween and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	match event.type:
		MatchEvent.Type.GOAL:
			_animate_goal(event.team_id == GameState.player_club_id or event.team_id != "")
		MatchEvent.Type.CHANCE:
			_animate_chance()
		MatchEvent.Type.CARD_YELLOW, MatchEvent.Type.CARD_RED:
			_animate_card(event.type == MatchEvent.Type.CARD_RED)
		MatchEvent.Type.INJURY:
			_animate_injury()
		MatchEvent.Type.HALFTIME, MatchEvent.Type.FULLTIME:
			_pulse_label()
		_:
			_idle_move()
	await _tween.finished


func _reset_positions() -> void:
	var pr := pitch.get_rect()
	home_sprite.position = Vector2(pr.position.x + 40, pr.position.y + pr.size.y * 0.5 - 8)
	away_sprite.position = Vector2(pr.position.x + pr.size.x - 56, pr.position.y + pr.size.y * 0.5 - 8)
	ball.position = Vector2(pr.position.x + pr.size.x * 0.5 - 4, pr.position.y + pr.size.y * 0.5 - 4)


func _animate_goal(_for_player_side: bool) -> void:
	_reset_positions()
	var goal_x := pitch.position.x + pitch.size.x - 30
	_tween.tween_property(ball, "position", Vector2(goal_x, pitch.position.y + pitch.size.y * 0.4), 0.45)
	_tween.parallel().tween_property(home_sprite, "position:x", goal_x - 40, 0.45)
	_tween.tween_property(label, "modulate", Color(1, 1, 0.4), 0.15)
	_tween.tween_property(label, "modulate", Color.WHITE, 0.25)


func _animate_chance() -> void:
	_reset_positions()
	var mid := Vector2(pitch.position.x + pitch.size.x * 0.7, pitch.position.y + pitch.size.y * 0.45)
	_tween.tween_property(ball, "position", mid, 0.35)
	_tween.tween_property(ball, "position", mid + Vector2(20, -30), 0.25)
	_tween.tween_property(ball, "position", Vector2(pitch.position.x + pitch.size.x * 0.5, pitch.position.y + pitch.size.y * 0.5), 0.2)


func _animate_card(is_red: bool) -> void:
	label.modulate = Color(1, 0.2, 0.2) if is_red else Color(1, 1, 0.2)
	_tween.tween_property(away_sprite, "modulate", Color(1, 0.5, 0.5), 0.2)
	_tween.tween_property(away_sprite, "modulate", Color.WHITE, 0.3)
	_tween.tween_property(label, "modulate", Color.WHITE, 0.2)


func _animate_injury() -> void:
	_tween.tween_property(home_sprite, "modulate", Color(0.6, 0.6, 0.6), 0.3)
	_tween.tween_property(home_sprite, "position:y", home_sprite.position.y + 10, 0.3)
	_tween.tween_interval(0.2)
	_tween.tween_property(home_sprite, "modulate", Color.WHITE, 0.2)


func _pulse_label() -> void:
	_tween.tween_property(label, "scale", Vector2(1.05, 1.05), 0.2)
	_tween.tween_property(label, "scale", Vector2.ONE, 0.2)


func _idle_move() -> void:
	_reset_positions()
	_tween.tween_property(ball, "position:x", ball.position.x + 30, 0.25)
	_tween.tween_property(ball, "position:x", ball.position.x - 10, 0.25)
