extends Control

# L字レイアウトの「枠」だけを管理する。タブの中身には触れない（疎結合）。
# タブの切替も、現在ロード中のタブの可視状態だけ操作する。

const TAB_WORK := &"work"
const TAB_ROOM := &"room"
const TAB_SHOP := &"shop"

@onready var currency_label: Label = %CurrencyLabel
@onready var per_sec_label: Label = %PerSecLabel
@onready var click_power_label: Label = %ClickPowerLabel

@onready var tab_work_button: Button = %TabWork
@onready var tab_room_button: Button = %TabRoom
@onready var tab_shop_button: Button = %TabShop

@onready var tab_holder: Control = %TabHolder
@onready var work_tab: Control = %WorkTab
@onready var room_tab: Control = %RoomTab
@onready var shop_tab: Control = %ShopTab

@onready var auto_timer: Timer = %AutoTimer
@onready var toast_label: Label = %ToastLabel
@onready var background: ColorRect = $Background

var _toast_tween: Tween
var _currency_pop_tween: Tween


func _ready() -> void:
	theme = ThemeFactory.build_default()
	background.color = UIConstants.COLOR_BG

	EventBus.currency_changed.connect(_on_currency_changed)
	EventBus.per_second_changed.connect(_on_per_second_changed)
	EventBus.click_power_changed.connect(_on_click_power_changed)
	EventBus.toast_requested.connect(_show_toast)

	tab_work_button.pressed.connect(_switch_to.bind(TAB_WORK))
	tab_room_button.pressed.connect(_switch_to.bind(TAB_ROOM))
	tab_shop_button.pressed.connect(_switch_to.bind(TAB_SHOP))

	auto_timer.timeout.connect(_on_auto_tick)

	_refresh_status_bar()
	_switch_to(TAB_WORK)


func _switch_to(tab_id: StringName) -> void:
	work_tab.visible = (tab_id == TAB_WORK)
	room_tab.visible = (tab_id == TAB_ROOM)
	shop_tab.visible = (tab_id == TAB_SHOP)
	tab_work_button.button_pressed = (tab_id == TAB_WORK)
	tab_room_button.button_pressed = (tab_id == TAB_ROOM)
	tab_shop_button.button_pressed = (tab_id == TAB_SHOP)


func _refresh_status_bar() -> void:
	currency_label.text = tr("UI_CURRENCY_FMT") % FormatUtils.short(GameState.currency)
	per_sec_label.text = tr("UI_PER_SEC_FMT") % FormatUtils.short(GameState.per_second)
	click_power_label.text = tr("UI_CLICK_POWER_FMT") % FormatUtils.short(GameState.click_power)


func _on_currency_changed(_v: int) -> void:
	_refresh_status_bar()
	_pop_currency_label()


func _pop_currency_label() -> void:
	if _currency_pop_tween != null and _currency_pop_tween.is_valid():
		_currency_pop_tween.kill()
	currency_label.pivot_offset = currency_label.size * 0.5
	currency_label.scale = Vector2.ONE
	var peak := Vector2.ONE * UIConstants.CURRENCY_POP_SCALE
	var dur := UIConstants.CURRENCY_POP_DURATION
	_currency_pop_tween = create_tween()
	_currency_pop_tween.tween_property(currency_label, "scale", peak, dur).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_currency_pop_tween.tween_property(currency_label, "scale", Vector2.ONE, dur).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

func _on_per_second_changed(_v: int) -> void:
	_refresh_status_bar()

func _on_click_power_changed(_v: int) -> void:
	_refresh_status_bar()


func _on_auto_tick() -> void:
	EconomyService.tick(1.0)


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED:
		_refresh_status_bar()


func _show_toast(text: String) -> void:
	if _toast_tween != null and _toast_tween.is_valid():
		_toast_tween.kill()
	toast_label.text = text
	toast_label.modulate.a = 1.0
	_toast_tween = create_tween()
	_toast_tween.tween_interval(UIConstants.TOAST_HOLD_SEC)
	_toast_tween.tween_property(toast_label, "modulate:a", 0.0, UIConstants.TOAST_FADE_SEC)
