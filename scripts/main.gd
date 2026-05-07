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


func _ready() -> void:
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
	currency_label.text = "¥ %d" % GameState.currency
	per_sec_label.text = "%d / sec" % GameState.per_second
	click_power_label.text = "+%d / click" % GameState.click_power


func _on_currency_changed(_v: int) -> void:
	_refresh_status_bar()

func _on_per_second_changed(_v: int) -> void:
	_refresh_status_bar()

func _on_click_power_changed(_v: int) -> void:
	_refresh_status_bar()


func _on_auto_tick() -> void:
	EconomyService.tick(1.0)


func _show_toast(text: String) -> void:
	toast_label.text = text
	toast_label.modulate.a = 1.0
	var tw := create_tween()
	tw.tween_interval(1.4)
	tw.tween_property(toast_label, "modulate:a", 0.0, 0.6)
