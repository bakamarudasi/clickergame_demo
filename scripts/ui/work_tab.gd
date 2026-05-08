extends Control

# Workタブ。クリックでの通貨生成と強化購入のみを担当。
# 他タブを直接参照しない。EconomyService 経由でのみ状態を変える。

@onready var document_button: TextureButton = %DocumentButton
@onready var upgrade_list: VBoxContainer = %UpgradeList
@onready var detail_name: Label = %DetailName
@onready var detail_desc: Label = %DetailDesc
@onready var detail_meta: Label = %DetailMeta
@onready var buy_button: Button = %BuyButton

var _click_tween: Tween
var _selected_id: StringName = &""
var _button_group: ButtonGroup


func _ready() -> void:
	_button_group = ButtonGroup.new()
	document_button.pressed.connect(_on_click_pressed)
	buy_button.pressed.connect(_on_buy_pressed)
	EventBus.currency_changed.connect(_refresh_upgrade_buttons)
	EventBus.upgrade_purchased.connect(_on_upgrade_purchased)
	_build_upgrade_buttons()
	_refresh_detail()


func _on_click_pressed() -> void:
	EconomyService.click()
	_animate_click_squash()


func _animate_click_squash() -> void:
	if _click_tween != null and _click_tween.is_valid():
		_click_tween.kill()
	document_button.pivot_offset = document_button.size / 2.0
	document_button.scale = Vector2.ONE
	var dur := UIConstants.PORTRAIT_CLICK_DURATION
	var squashed := Vector2.ONE * (1.0 - UIConstants.PORTRAIT_CLICK_SQUASH)
	_click_tween = create_tween()
	_click_tween.tween_property(document_button, "scale", squashed, dur)
	_click_tween.tween_property(document_button, "scale", Vector2.ONE, dur)


func _build_upgrade_buttons() -> void:
	for child in upgrade_list.get_children():
		child.queue_free()
	for u: UpgradeData in DataRegistry.upgrades.values():
		var b := Button.new()
		b.toggle_mode = true
		b.button_group = _button_group
		b.text = _format_upgrade(u)
		b.set_meta("upgrade_id", u.id)
		b.pressed.connect(_on_upgrade_selected.bind(u.id))
		upgrade_list.add_child(b)
	_refresh_upgrade_buttons(0)


func _on_upgrade_selected(id: StringName) -> void:
	_selected_id = id
	_refresh_detail()


func _refresh_upgrade_buttons(_v: int = 0) -> void:
	for child in upgrade_list.get_children():
		if child is Button:
			var id: StringName = child.get_meta("upgrade_id")
			var u := DataRegistry.get_upgrade(id)
			if u == null:
				continue
			child.text = _format_upgrade(u)
	_refresh_detail()


func _refresh_detail() -> void:
	if _selected_id == &"":
		detail_name.text = ""
		detail_desc.text = tr("WORK_UPGRADE_DETAIL_NONE")
		detail_meta.text = ""
		buy_button.disabled = true
		return
	var u := DataRegistry.get_upgrade(_selected_id)
	if u == null:
		_selected_id = &""
		_refresh_detail()
		return
	var lv := GameState.get_upgrade_level(_selected_id)
	var cost := EconomyService.current_cost(_selected_id)
	detail_name.text = tr(u.display_name)
	detail_desc.text = tr(u.description)
	detail_meta.text = tr("WORK_UPGRADE_DETAIL_FMT") % [lv, cost]
	buy_button.disabled = not EconomyService.can_buy_upgrade(_selected_id)


func _on_buy_pressed() -> void:
	if _selected_id == &"":
		return
	EconomyService.buy_upgrade(_selected_id)


func _on_upgrade_purchased(_id: StringName, _lv: int) -> void:
	_refresh_upgrade_buttons()


func _format_upgrade(u: UpgradeData) -> String:
	var lv := GameState.get_upgrade_level(u.id)
	var cost := EconomyService.current_cost(u.id)
	return tr("WORK_UPGRADE_FMT") % [tr(u.display_name), lv, cost]


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED:
		_refresh_upgrade_buttons()
