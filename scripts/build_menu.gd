extends Control
## Sidebar: place buildings (prereq/afford) + produce from selected producer (S15 tooltips).

signal status_message(text: String)

const Locale := preload("res://scripts/locale.gd")

@export var build_controller_path: NodePath
@export var selection_path: NodePath
@export var economy_path: NodePath
@export var power_grid_path: NodePath

var _build_buttons: Dictionary = {}
var _prod_box: VBoxContainer
var _queue_label: Label
var _power_hint: Label
var _faction_title: Label
var _build_title: Label
var _prod_title: Label
var _faction_id: String = "aureate"
var _ui_scale: float = 1.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	var main := get_tree().current_scene
	if main:
		var sk := main.get_node_or_null("SkirmishConfig")
		if sk:
			_faction_id = str(sk.player_faction)
	_build_ui()
	var economy := get_node_or_null(economy_path)
	if economy and economy.has_signal("credits_changed"):
		economy.credits_changed.connect(_refresh_build_buttons)
	var power := get_node_or_null(power_grid_path)
	if power and power.has_signal("power_changed"):
		power.power_changed.connect(_on_power_changed)
	var sel := get_node_or_null(selection_path)
	if sel and sel.has_signal("selection_changed"):
		sel.selection_changed.connect(_on_selection_changed)
	call_deferred("_refresh_build_buttons")


func set_faction_theme(faction_id: String) -> void:
	_faction_id = faction_id
	if _faction_title:
		_faction_title.text = FactionDatabase.display_name(faction_id)
		_faction_title.modulate = FactionDatabase.accent_color(faction_id)


func _build_ui() -> void:
	var accent := FactionDatabase.accent_color(_faction_id)
	var panel := PanelContainer.new()
	panel.anchor_left = 1.0
	panel.anchor_right = 1.0
	panel.anchor_top = 0.0
	panel.anchor_bottom = 1.0
	panel.offset_left = -230.0
	panel.offset_top = 44.0
	panel.offset_right = -8.0
	panel.offset_bottom = -8.0
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.1, 0.08, 0.9)
	style.border_color = accent
	style.set_border_width_all(2)
	style.set_corner_radius_all(2)
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	margin.add_child(vbox)

	_faction_title = Label.new()
	_faction_title.text = FactionDatabase.display_name(_faction_id)
	_faction_title.modulate = accent
	vbox.add_child(_faction_title)

	_build_title = Label.new()
	_build_title.text = Locale.t("build_title")
	vbox.add_child(_build_title)

	_power_hint = Label.new()
	_power_hint.text = Locale.t("power_ok")
	_power_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(_power_hint)

	var placeable := [
		{"id": "b_power", "key": KEY_1, "label": "1 Windtrap"},
		{"id": "b_barracks", "key": KEY_2, "label": "2 Barracks"},
		{"id": "b_factory", "key": KEY_3, "label": "3 Factory"},
		{"id": "b_turret", "key": KEY_4, "label": "4 Turret"},
		{"id": "b_radar", "key": KEY_5, "label": "5 Outpost"},
		{"id": "b_silo", "key": KEY_6, "label": "6 Silo"},
	]
	for item in placeable:
		var btn := Button.new()
		btn.text = item["label"]
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.pressed.connect(_on_build_pressed.bind(str(item["id"])))
		vbox.add_child(btn)
		_build_buttons[str(item["id"])] = {"button": btn, "key": item["key"]}

	vbox.add_child(HSeparator.new())

	_prod_title = Label.new()
	_prod_title.text = Locale.t("produce_title")
	vbox.add_child(_prod_title)

	_prod_box = VBoxContainer.new()
	_prod_box.add_theme_constant_override("separation", 4)
	vbox.add_child(_prod_box)

	_queue_label = Label.new()
	_queue_label.text = "Queue: —"
	_queue_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(_queue_label)

	var hint := Label.new()
	hint.text = "Esc/RMB cancel ghost"
	hint.modulate = Color(0.75, 0.75, 0.75)
	vbox.add_child(hint)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		for id in _build_buttons:
			if event.keycode == int(_build_buttons[id]["key"]):
				_on_build_pressed(id)
				get_viewport().set_input_as_handled()
				return
		var producer := _selected_producer()
		if producer:
			var ids: Array = producer.get_produced_unit_ids()
			var keys := [KEY_Q, KEY_W, KEY_E, KEY_R, KEY_T, KEY_Y]
			for i in mini(ids.size(), keys.size()):
				if event.keycode == keys[i]:
					_enqueue(str(ids[i]))
					get_viewport().set_input_as_handled()
					return


func _on_build_pressed(building_id: String) -> void:
	var bc := get_node_or_null(build_controller_path)
	if bc == null:
		return
	if bc.is_placing() and bc.placing_id == building_id:
		bc.cancel_place()
		status_message.emit("Placement cancelled")
		return
	if bc.begin_place(building_id):
		var def := BuildingDatabase.get_building(building_id)
		status_message.emit("Placing %s (%d cr, pwr %+d)" % [
			def.get("name", building_id),
			int(def.get("cost", 0)),
			int(def.get("power", 0)),
		])
		_play_sfx("place")
	else:
		var reasons: PackedStringArray = PackedStringArray()
		if not BuildingDatabase.meets_prereqs(get_tree(), building_id):
			reasons.append("need %s" % ", ".join(BuildingDatabase.prereq_ids(building_id)))
		var economy := get_node_or_null(economy_path)
		var cost := int(BuildingDatabase.get_building(building_id).get("cost", 0))
		if economy and not economy.can_afford(cost):
			reasons.append("credits")
		status_message.emit("Cannot place %s (%s)" % [
			building_id, ", ".join(reasons) if reasons.size() else "blocked"
		])
		_play_sfx("warn")


func refresh_locale() -> void:
	if _build_title:
		_build_title.text = Locale.t("build_title")
	if _prod_title:
		_prod_title.text = Locale.t("produce_title")
	_refresh_build_buttons()


func apply_ui_scale(scale: float) -> void:
	_ui_scale = clampf(scale, 0.85, 1.5)
	var base := 14
	for id in _build_buttons:
		var btn: Button = _build_buttons[id]["button"]
		btn.add_theme_font_size_override("font_size", int(round(base * _ui_scale)))
	if _build_title:
		_build_title.add_theme_font_size_override("font_size", int(round(15 * _ui_scale)))
	if _prod_title:
		_prod_title.add_theme_font_size_override("font_size", int(round(15 * _ui_scale)))


func _building_tooltip(building_id: String) -> String:
	var def := BuildingDatabase.get_building(building_id)
	var prereqs := BuildingDatabase.prereq_ids(building_id)
	var prereq_names: PackedStringArray = PackedStringArray()
	for pid in prereqs:
		prereq_names.append(str(BuildingDatabase.get_building(pid).get("name", pid)))
	var prereq_line := ", ".join(prereq_names) if prereq_names.size() else "—"
	return "%s\nCost: %d\nPower: %+d\nPrereq: %s\n%s" % [
		str(def.get("name", building_id)),
		int(def.get("cost", 0)),
		int(def.get("power", 0)),
		prereq_line,
		str(def.get("role", "")),
	]


func _unit_tooltip(unit_id: String) -> String:
	var udef := UnitDatabase.get_unit(unit_id)
	return "%s\nCost: %d\nBuild: %.1fs\nHP: %.0f  DPS: %.0f\n%s" % [
		str(udef.get("name", unit_id)),
		int(udef.get("cost", 0)),
		float(udef.get("build_time", 3.0)),
		float(udef.get("hp", 0)),
		float(udef.get("dps", 0)),
		str(udef.get("role", "")),
	]


func _play_sfx(kind: String) -> void:
	var main := get_tree().current_scene
	if main == null:
		return
	var bus := main.get_node_or_null("SfxBus")
	if bus and bus.has_method("play_ui"):
		bus.play_ui(kind)


func _refresh_build_buttons(_credits: int = 0) -> void:
	var economy := get_node_or_null(economy_path)
	for id in _build_buttons:
		var def := BuildingDatabase.get_building(id)
		var cost := int(def.get("cost", 0))
		var pwr := int(def.get("power", 0))
		var btn: Button = _build_buttons[id]["button"]
		var ok_prereq: bool = BuildingDatabase.meets_prereqs(get_tree(), id)
		var ok_cash: bool = economy == null or economy.can_afford(cost)
		btn.text = "%s (%d/%+d)" % [_label_for(id), cost, pwr]
		btn.disabled = not (ok_prereq and ok_cash)
		btn.tooltip_text = _building_tooltip(id)


func _on_power_changed(produced: int, consumed: int, surplus: int) -> void:
	if surplus < 0:
		_power_hint.text = Locale.t("power_low") % [produced, consumed]
		_power_hint.modulate = Color(1.0, 0.45, 0.35)
	else:
		_power_hint.text = Locale.t("power") % [surplus, produced, consumed]
		_power_hint.modulate = Color(0.7, 0.95, 0.75)
	_refresh_build_buttons()


func _label_for(building_id: String) -> String:
	match building_id:
		"b_power":
			return "1 Windtrap"
		"b_barracks":
			return "2 Barracks"
		"b_factory":
			return "3 Factory"
		"b_turret":
			return "4 Turret"
		"b_radar":
			return "5 Outpost"
		"b_silo":
			return "6 Silo"
	return building_id


func _on_selection_changed(_units: Array, buildings: Array) -> void:
	_refresh_production_ui(buildings)


func _refresh_production_ui(buildings: Array) -> void:
	for child in _prod_box.get_children():
		child.queue_free()
	var producer: Node = null
	for b in buildings:
		if b.is_in_group("producers"):
			producer = b
			break
	if producer == null:
		_queue_label.text = "Queue: —"
		return
	if producer.has_signal("queue_changed") and not producer.queue_changed.is_connected(_on_queue_changed):
		producer.queue_changed.connect(_on_queue_changed)
	var keys := ["Q", "W", "E", "R", "T", "Y"]
	var idx := 0
	for uid in producer.get_produced_unit_ids():
		var udef := UnitDatabase.get_unit(str(uid))
		var btn := Button.new()
		var key: String = keys[idx] if idx < keys.size() else str(idx + 1)
		btn.text = "%s %s (%d / %.0fs)" % [
			key,
			udef.get("name", uid),
			int(udef.get("cost", 0)),
			float(udef.get("build_time", 3.0)),
		]
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.tooltip_text = _unit_tooltip(str(uid))
		btn.add_theme_font_size_override("font_size", int(round(14 * _ui_scale)))
		btn.pressed.connect(_enqueue.bind(str(uid)))
		_prod_box.add_child(btn)
		idx += 1
	_on_queue_changed(producer.get_queue_snapshot())


func _on_queue_changed(queue: Array) -> void:
	var producer: Node = _selected_producer()
	var paused: bool = false
	if producer != null and producer.has_method("is_production_paused"):
		paused = bool(producer.is_production_paused())
	if queue.is_empty():
		_queue_label.text = "Queue: empty" + (" (LOW POWER)" if paused else "")
		return
	var parts: PackedStringArray = PackedStringArray()
	for job in queue:
		parts.append(str(job.get("id", "?")))
	_queue_label.text = "Queue: %s%s" % [", ".join(parts), " — PAUSED" if paused else ""]


func _selected_producer() -> Node:
	var sel := get_node_or_null(selection_path)
	if sel == null or not sel.has_method("get_selected_buildings"):
		return null
	for b in sel.get_selected_buildings():
		if b.is_in_group("producers"):
			return b
	return null


func _enqueue(unit_id: String) -> void:
	var producer := _selected_producer()
	if producer == null:
		status_message.emit("Select Barracks/Factory/Refinery first")
		return
	if producer.enqueue_unit(unit_id, true):
		var udef := UnitDatabase.get_unit(unit_id)
		var msg := "Queued %s (%d cr)" % [udef.get("name", unit_id), int(udef.get("cost", 0))]
		if producer.is_production_paused():
			msg += " (paused — low power)"
		status_message.emit(msg)
		_play_sfx("ok")
	else:
		status_message.emit("Cannot queue %s (credits/queue)" % unit_id)
		_play_sfx("warn")
