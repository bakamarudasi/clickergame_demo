extends Control

# 音量設定ダイアログ。Master / BGM / SFX / UI それぞれに
# スライダ + ミュート + パーセント表示。値変更で即 BGMService に反映、
# BGMService 側で永続化される（ConfigFile）。
#
# 開閉は AudioSettingsDialog.open() / close() で。背面の半透明 backdrop が
# マウスを吸うので、ダイアログ外側クリックでも閉じない設計（明示 close のみ）。
# ESC で閉じるのだけ ui_cancel をフックして対応。

@onready var master_slider: HSlider = %MasterSlider
@onready var master_value: Label = %MasterValue
@onready var master_mute: CheckBox = %MasterMute
@onready var bgm_slider: HSlider = %BGMSlider
@onready var bgm_value: Label = %BGMValue
@onready var bgm_mute: CheckBox = %BGMMute
@onready var sfx_slider: HSlider = %SFXSlider
@onready var sfx_value: Label = %SFXValue
@onready var sfx_mute: CheckBox = %SFXMute
@onready var ui_slider: HSlider = %UISlider
@onready var ui_value: Label = %UIValue
@onready var ui_mute: CheckBox = %UIMute
@onready var close_button: Button = %CloseButton

const _BUS_TO_NAME := {
	&"master": BGMService.BUS_MASTER,
	&"bgm": BGMService.BUS_BGM,
	&"sfx": BGMService.BUS_SFX,
	&"ui": BGMService.BUS_UI,
}


func _ready() -> void:
	visible = false
	close_button.pressed.connect(close)

	# スライダー初期化と value_changed フック。1 行で繋ぐ：
	# slider.value_changed → set_bus_volume_linear(bus, v) → value ラベル再描画
	for entry in [
		[master_slider, master_value, master_mute, BGMService.BUS_MASTER],
		[bgm_slider, bgm_value, bgm_mute, BGMService.BUS_BGM],
		[sfx_slider, sfx_value, sfx_mute, BGMService.BUS_SFX],
		[ui_slider, ui_value, ui_mute, BGMService.BUS_UI],
	]:
		var slider: HSlider = entry[0]
		var value_lbl: Label = entry[1]
		var mute_cb: CheckBox = entry[2]
		var bus_name: StringName = entry[3]
		slider.min_value = 0.0
		slider.max_value = 1.0
		slider.step = 0.01
		slider.value = BGMService.get_bus_volume_linear(bus_name)
		_refresh_value_label(value_lbl, slider.value)
		slider.value_changed.connect(_on_slider_changed.bind(bus_name, value_lbl))
		mute_cb.button_pressed = BGMService.is_bus_muted(bus_name)
		mute_cb.toggled.connect(_on_mute_toggled.bind(bus_name))


func open() -> void:
	# 開く時に現在値を再読込（外部から音量変更された場合に追従）。
	master_slider.set_value_no_signal(BGMService.get_bus_volume_linear(BGMService.BUS_MASTER))
	bgm_slider.set_value_no_signal(BGMService.get_bus_volume_linear(BGMService.BUS_BGM))
	sfx_slider.set_value_no_signal(BGMService.get_bus_volume_linear(BGMService.BUS_SFX))
	ui_slider.set_value_no_signal(BGMService.get_bus_volume_linear(BGMService.BUS_UI))
	_refresh_value_label(master_value, master_slider.value)
	_refresh_value_label(bgm_value, bgm_slider.value)
	_refresh_value_label(sfx_value, sfx_slider.value)
	_refresh_value_label(ui_value, ui_slider.value)
	master_mute.set_pressed_no_signal(BGMService.is_bus_muted(BGMService.BUS_MASTER))
	bgm_mute.set_pressed_no_signal(BGMService.is_bus_muted(BGMService.BUS_BGM))
	sfx_mute.set_pressed_no_signal(BGMService.is_bus_muted(BGMService.BUS_SFX))
	ui_mute.set_pressed_no_signal(BGMService.is_bus_muted(BGMService.BUS_UI))
	visible = true


func close() -> void:
	visible = false


func _on_slider_changed(value: float, bus_name: StringName, value_lbl: Label) -> void:
	BGMService.set_bus_volume_linear(bus_name, value)
	_refresh_value_label(value_lbl, value)


func _on_mute_toggled(pressed: bool, bus_name: StringName) -> void:
	BGMService.set_bus_muted(bus_name, pressed)


func _refresh_value_label(label: Label, linear: float) -> void:
	label.text = "%d%%" % int(round(linear * 100.0))


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()
