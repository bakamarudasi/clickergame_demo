extends Control

# Workタブ。クリックでの通貨生成と強化購入のみを担当。
# 他タブを直接参照しない。EconomyService 経由でのみ状態を変える。

@onready var document_button: TextureButton = %DocumentButton
@onready var upgrade_list: VBoxContainer = %UpgradeList

var _click_tween: Tween


func _ready() -> void:
	document_button.pressed.connect(_on_click_pressed)
	EventBus.currency_changed.connect(_refresh_upgrade_buttons)
	EventBus.upgrade_purchased.connect(_on_upgrade_purchased)
	_build_upgrade_buttons()


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
		b.text = _format_upgrade(u)
		b.pressed.connect(EconomyService.buy_upgrade.bind(u.id))
		b.set_meta("upgrade_id", u.id)
		upgrade_list.add_child(b)
	_refresh_upgrade_buttons(0)


func _refresh_upgrade_buttons(_v: int = 0) -> void:
	for child in upgrade_list.get_children():
		if child is Button:
			var id: StringName = child.get_meta("upgrade_id")
			var u := DataRegistry.get_upgrade(id)
			if u == null:
				continue
			child.text = _format_upgrade(u)
			child.disabled = not EconomyService.can_buy_upgrade(id)


func _on_upgrade_purchased(_id: StringName, _lv: int) -> void:
	_refresh_upgrade_buttons()


func _format_upgrade(u: UpgradeData) -> String:
	var lv := GameState.get_upgrade_level(u.id)
	var cost := EconomyService.current_cost(u.id)
	return tr("WORK_UPGRADE_FMT") % [tr(u.display_name), lv, cost]


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED:
		_refresh_upgrade_buttons()
