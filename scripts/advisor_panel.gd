extends Control
## Mentat-like briefing / advisor panel (S13).

signal dismissed

@onready var _backdrop: ColorRect = $Backdrop
@onready var _panel: ColorRect = $Panel
@onready var _title: Label = $Panel/Title
@onready var _advisor: Label = $Panel/Advisor
@onready var _body: Label = $Panel/Body
@onready var _objectives: Label = $Panel/Objectives
@onready var _hint: Label = $Panel/Hint


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	if _backdrop:
		_backdrop.gui_input.connect(_on_backdrop_input)


func show_briefing(title: String, advisor: String, text: String, objective_lines: PackedStringArray = PackedStringArray()) -> void:
	_title.text = title
	_advisor.text = advisor
	_body.text = text
	_objectives.text = "\n".join(objective_lines)
	_hint.text = "Enter / Space / click — continue   |   B — advisor"
	visible = true
	move_to_front()


func show_advisor(title: String, advisor: String, text: String, objective_lines: PackedStringArray) -> void:
	show_briefing(title, advisor, text, objective_lines)
	_hint.text = "B / Esc — close   |   objectives update live"


func hide_panel() -> void:
	if not visible:
		return
	visible = false
	dismissed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_accept") or event.is_action_pressed("ui_cancel"):
		hide_panel()
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_SPACE or event.keycode == KEY_ENTER:
			hide_panel()
			get_viewport().set_input_as_handled()


func _on_backdrop_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		hide_panel()
