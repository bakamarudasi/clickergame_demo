extends Control

var score: int = 0
var click_power: int = 1
var per_second: int = 0

var click_upgrade_cost: int = 10
var auto_cost: int = 25

@onready var score_label: Label = %ScoreLabel
@onready var per_second_label: Label = %PerSecondLabel
@onready var upgrade_click_button: Button = %UpgradeClick
@onready var buy_auto_button: Button = %BuyAuto


func _ready() -> void:
	_refresh_ui()


func _on_click_pressed() -> void:
	score += click_power
	_refresh_ui()


func _on_upgrade_click_pressed() -> void:
	if score < click_upgrade_cost:
		return
	score -= click_upgrade_cost
	click_power += 1
	click_upgrade_cost = int(click_upgrade_cost * 1.5) + 1
	_refresh_ui()


func _on_buy_auto_pressed() -> void:
	if score < auto_cost:
		return
	score -= auto_cost
	per_second += 1
	auto_cost = int(auto_cost * 1.6) + 1
	_refresh_ui()


func _on_auto_timer_timeout() -> void:
	if per_second <= 0:
		return
	score += per_second
	_refresh_ui()


func _refresh_ui() -> void:
	score_label.text = str(score)
	per_second_label.text = "%d / sec" % per_second
	upgrade_click_button.text = "Upgrade Click (+1) — Cost: %d" % click_upgrade_cost
	buy_auto_button.text = "Buy Auto-Clicker (+1/sec) — Cost: %d" % auto_cost
	upgrade_click_button.disabled = score < click_upgrade_cost
	buy_auto_button.disabled = score < auto_cost
