extends Control

# メタ強化（プレステージ強化）タブ。3柱（Affinity / Economy / Catalog）に分けて表示し、
# 各柱のメタ強化を源石片で購入する。
# Work タブと同様、他タブを直接参照せず Service / EventBus 経由でだけ状態を変える。
# カードの組み立ては MetaCardFactory に委譲。

@onready var currency_label: Label = %CurrencyLabel
@onready var tab_affinity: Button = %TabAffinity
@onready var tab_economy: Button = %TabEconomy
@onready var tab_catalog: Button = %TabCatalog
@onready var meta_grid: GridContainer = %MetaGrid

var _current_pillar: Enums.MetaPillar = Enums.MetaPillar.ECONOMY
var _cards: Dictionary = {}     # meta_id -> PanelContainer
var _card_factory: MetaCardFactory


func _ready() -> void:
	_card_factory = MetaCardFactory.new(self)
	_card_factory.buy_requested.connect(_on_buy_pressed)

	var pillar_group := ButtonGroup.new()
	tab_affinity.button_group = pillar_group
	tab_economy.button_group = pillar_group
	tab_catalog.button_group = pillar_group

	tab_affinity.pressed.connect(_on_pillar_pressed.bind(Enums.MetaPillar.AFFINITY))
	tab_economy.pressed.connect(_on_pillar_pressed.bind(Enums.MetaPillar.ECONOMY))
	tab_catalog.pressed.connect(_on_pillar_pressed.bind(Enums.MetaPillar.CATALOG))

	EventBus.prestige_currency_changed.connect(_on_prestige_currency_changed)
	EventBus.meta_upgrade_purchased.connect(_on_meta_purchased)

	_refresh_currency_label()
	_build_cards()


func _on_pillar_pressed(pillar: Enums.MetaPillar) -> void:
	if _current_pillar == pillar:
		return
	_current_pillar = pillar
	_build_cards()


func _refresh_currency_label() -> void:
	currency_label.text = tr("META_CURRENCY_LABEL") % FormatUtils.short(GameState.prestige_currency)


func _on_prestige_currency_changed(_v: int) -> void:
	_refresh_currency_label()
	for id in _cards.keys():
		_refresh_card(id)


func _on_meta_purchased(_id: StringName, _lv: int) -> void:
	_refresh_currency_label()
	for id in _cards.keys():
		_refresh_card(id)


func _build_cards() -> void:
	for child in meta_grid.get_children():
		child.queue_free()
	_cards.clear()
	var entries: Array = []
	for m: MetaUpgradeData in DataRegistry.meta_upgrades.values():
		if m.pillar == _current_pillar:
			entries.append(m)
	# 安価なものから順に並べる
	entries.sort_custom(func(a: MetaUpgradeData, b: MetaUpgradeData) -> bool:
		return a.base_cost < b.base_cost)
	for m: MetaUpgradeData in entries:
		var card := _card_factory.build(m)
		meta_grid.add_child(card)
		_cards[m.id] = card
		_card_factory.refresh(card, m)


func _refresh_card(id: StringName) -> void:
	var card: PanelContainer = _cards.get(id)
	if card == null:
		return
	var m := DataRegistry.get_meta_upgrade(id)
	if m == null:
		return
	_card_factory.refresh(card, m)


func _on_buy_pressed(id: StringName) -> void:
	MetaUpgradeService.buy(id)


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		_refresh_currency_label()
		for id in _cards.keys():
			var m := DataRegistry.get_meta_upgrade(id)
			if m == null:
				continue
			_card_factory.rebuild_static_text(_cards[id], m)
			_refresh_card(id)
