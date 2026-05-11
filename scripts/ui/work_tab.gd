extends Control

# Workタブ。クリックでの通貨生成と強化購入のみを担当。
# 他タブを直接参照しない。EconomyService 経由でのみ状態を変える。

const GOLDEN_TEXTURE := preload("res://assets/paperwork.svg")

@onready var document_button: TextureButton = %DocumentButton
@onready var upgrade_list: VBoxContainer = %UpgradeList
@onready var detail_name: Label = %DetailName
@onready var detail_desc: Label = %DetailDesc
@onready var detail_meta: Label = %DetailMeta
@onready var buy_button: Button = %BuyButton

var _click_tween: Tween
var _selected_id: StringName = &""
var _button_group: ButtonGroup

var _golden_timer: Timer
var _golden_active_node: TextureButton = null


func _ready() -> void:
	_button_group = ButtonGroup.new()
	document_button.pressed.connect(_on_click_pressed)
	buy_button.pressed.connect(_on_buy_pressed)
	EventBus.currency_changed.connect(_refresh_upgrade_buttons)
	EventBus.upgrade_purchased.connect(_on_upgrade_purchased)
	_build_upgrade_buttons()
	_refresh_detail()
	_setup_golden_timer()


func _setup_golden_timer() -> void:
	_golden_timer = Timer.new()
	_golden_timer.one_shot = true
	add_child(_golden_timer)
	_golden_timer.timeout.connect(_spawn_golden)
	_restart_golden_timer()


func _on_click_pressed() -> void:
	var gained := GameState.click_power
	EconomyService.click()
	_animate_click_squash()
	_spawn_click_popup(gained)


func _animate_click_squash() -> void:
	if _click_tween != null and _click_tween.is_valid():
		_click_tween.kill()
	document_button.pivot_offset = document_button.size / 2.0
	document_button.scale = Vector2.ONE
	var dur := UIConstants.PORTRAIT_CLICK_DURATION
	var squashed := Vector2.ONE * (1.0 - UIConstants.PORTRAIT_CLICK_SQUASH)
	var wiggle := deg_to_rad(randf_range(-UIConstants.CLICK_WIGGLE_DEG, UIConstants.CLICK_WIGGLE_DEG))
	_click_tween = create_tween().set_parallel(true)
	_click_tween.tween_property(document_button, "scale", squashed, dur)
	_click_tween.chain().tween_property(document_button, "scale", Vector2.ONE, dur)
	_click_tween.tween_property(document_button, "rotation", wiggle, dur)
	_click_tween.chain().tween_property(document_button, "rotation", 0.0, dur * 1.5)


func _spawn_click_popup(amount: int) -> void:
	if amount <= 0:
		return
	var popup := Label.new()
	popup.text = "+%s" % FormatUtils.short(amount)
	popup.theme_type_variation = UIConstants.VAR_TITLE_LABEL
	popup.modulate = UIConstants.COLOR_ACCENT
	popup.mouse_filter = Control.MOUSE_FILTER_IGNORE
	popup.z_index = 100
	add_child(popup)
	var btn_rect := document_button.get_global_rect()
	var local_origin := btn_rect.position - global_position
	var jitter := Vector2(randf_range(-30.0, 30.0), randf_range(-10.0, 10.0))
	var start_pos := local_origin + Vector2(btn_rect.size.x * 0.5, btn_rect.size.y * 0.35) + jitter
	popup.position = start_pos
	popup.pivot_offset = popup.size * 0.5
	var end_pos := start_pos + Vector2(0, -UIConstants.CLICK_POPUP_RISE_PX)
	var dur := UIConstants.CLICK_POPUP_DURATION
	var tw := create_tween().set_parallel(true)
	tw.tween_property(popup, "position", end_pos, dur).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(popup, "modulate:a", 0.0, dur).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(popup, "scale", Vector2(1.25, 1.25), dur * 0.3).from(Vector2.ONE)
	tw.chain().tween_callback(popup.queue_free)


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
	detail_meta.text = tr("WORK_UPGRADE_DETAIL_FMT") % [lv, FormatUtils.short(cost)]
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
	return tr("WORK_UPGRADE_FMT") % [tr(u.display_name), lv, FormatUtils.short(cost)]


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		_refresh_upgrade_buttons()


# --- ゴールデン書類 -----------------------------------------------------

func _restart_golden_timer() -> void:
	_golden_timer.wait_time = randf_range(
		UIConstants.GOLDEN_INTERVAL_MIN_SEC,
		UIConstants.GOLDEN_INTERVAL_MAX_SEC
	)
	_golden_timer.start()


func _spawn_golden() -> void:
	# Workタブが画面に出てない時はスポーンを見送って次の時刻を引き直す
	if not is_visible_in_tree():
		_restart_golden_timer()
		return
	if _golden_active_node != null and is_instance_valid(_golden_active_node):
		_restart_golden_timer()
		return
	var btn := TextureButton.new()
	btn.texture_normal = GOLDEN_TEXTURE
	btn.modulate = UIConstants.GOLDEN_TINT_COLOR
	btn.ignore_texture_size = true
	btn.stretch_mode = 5
	var sz := UIConstants.GOLDEN_SIZE_PX
	btn.custom_minimum_size = Vector2(sz, sz)
	btn.size = Vector2(sz, sz)
	# WorkTab の中で適当な高さのランダム位置に出す
	var w := size.x
	var h := size.y
	var y := randf_range(h * 0.2, h * 0.7)
	btn.position = Vector2(-sz, y)
	btn.z_index = 50
	add_child(btn)
	_golden_active_node = btn
	btn.pressed.connect(_on_golden_clicked.bind(btn))
	# 横断アニメ + ゆっくり回転で目立たせる
	var dur := UIConstants.GOLDEN_LIFETIME_SEC
	var tw := create_tween().set_parallel(true)
	tw.tween_property(btn, "position:x", w + sz, dur)
	tw.tween_property(btn, "rotation", deg_to_rad(20.0), dur)
	tw.chain().tween_callback(func() -> void: _expire_golden(btn))


func _on_golden_clicked(btn: TextureButton) -> void:
	if not is_instance_valid(btn):
		return
	var bonus := UIConstants.GOLDEN_BONUS_FLOOR
	bonus = max(bonus, GameState.effective_click_power() * UIConstants.GOLDEN_BONUS_PER_CLICK)
	bonus = max(bonus, int(float(GameState.currency) * UIConstants.GOLDEN_BONUS_PCT_OF_PILE))
	GameState.add_currency(bonus)
	EventBus.toast_requested.emit(tr("TOAST_GOLDEN_BONUS") % FormatUtils.short(bonus))
	_expire_golden(btn)


func _expire_golden(btn: TextureButton) -> void:
	if is_instance_valid(btn):
		btn.queue_free()
	_golden_active_node = null
	_restart_golden_timer()
