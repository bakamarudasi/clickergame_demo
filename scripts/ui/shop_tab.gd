extends Control

# Shopタブ。雑貨店ではなく「ターミナル端末で物資をオーダー」する想定。
# 他タブを直接参照しない。ShopService 経由でのみ購入処理を行う。
#
# 役割は orchestrator に絞り、カード組み立て・更新は ItemCardFactory に委譲。
# 見出し・カテゴリピル等のスタイルは ThemeFactory が一元管理。

@onready var category_bar: HBoxContainer = %CategoryBar
@onready var item_grid: GridContainer = %ItemGrid
@onready var empty_label: Label = %EmptyLabel

const CATEGORY_ENTRIES := [
	{ "label_key": "CATEGORY_DAILY", "value": Enums.ItemCategory.DAILY },
	{ "label_key": "CATEGORY_HOBBY", "value": Enums.ItemCategory.HOBBY },
	{ "label_key": "CATEGORY_BODY_CARE", "value": Enums.ItemCategory.BODY_CARE },
	{ "label_key": "CATEGORY_ROMANCE", "value": Enums.ItemCategory.ROMANCE },
	{ "label_key": "CATEGORY_DIRECT_TOY", "value": Enums.ItemCategory.DIRECT_TOY },
	{ "label_key": "CATEGORY_DIRECT_DRUG", "value": Enums.ItemCategory.DIRECT_DRUG },
	{ "label_key": "CATEGORY_DIRECT_BIND", "value": Enums.ItemCategory.DIRECT_BIND },
	{ "label_key": "CATEGORY_DIRECT_PROT", "value": Enums.ItemCategory.DIRECT_PROT },
	{ "label_key": "CATEGORY_COS_OUTFIT", "value": Enums.ItemCategory.COS_OUTFIT },
	{ "label_key": "CATEGORY_COS_PARTS", "value": Enums.ItemCategory.COS_PARTS },
	{ "label_key": "CATEGORY_INVITATION", "value": Enums.ItemCategory.INVITATION },
	{ "label_key": "CATEGORY_RULE", "value": Enums.ItemCategory.RULE },
	{ "label_key": "CATEGORY_SCOPE", "value": Enums.ItemCategory.SCOPE },
]

var _selected_category: int = Enums.ItemCategory.DAILY
var _card_factory: ItemCardFactory
var _cards: Dictionary = {}
var _category_group: ButtonGroup
var _category_buttons: Dictionary = {}


func _ready() -> void:
	_card_factory = ItemCardFactory.new(self)
	_card_factory.buy_requested.connect(_on_buy_requested)

	EventBus.currency_changed.connect(_refresh_all_cards)
	EventBus.item_purchased.connect(_on_item_purchased)
	EventBus.inventory_changed.connect(_on_inventory_changed)
	EventBus.meta_upgrade_purchased.connect(_on_meta_upgrade_purchased)

	_build_category_buttons()
	_rebuild_item_grid()


# --- カテゴリバー -------------------------------------------------------

func _build_category_buttons() -> void:
	_category_group = ButtonGroup.new()
	_category_buttons.clear()
	for child in category_bar.get_children():
		child.queue_free()
	for entry in CATEGORY_ENTRIES:
		var b := _make_category_button(entry.label_key, entry.value)
		category_bar.add_child(b)
		_category_buttons[entry.value] = b
	# 初期選択
	var initial: Button = _category_buttons.get(_selected_category)
	if initial != null:
		initial.set_pressed_no_signal(true)


func _make_category_button(label_key: String, cat: int) -> Button:
	var b := Button.new()
	b.toggle_mode = true
	b.button_group = _category_group
	b.text = label_key  # Button.text に翻訳キー → 自動 tr 追従
	b.theme_type_variation = UIConstants.VAR_PILL_BUTTON
	b.custom_minimum_size = Vector2(0, 32)
	b.pressed.connect(_on_category_pressed.bind(cat))
	return b


func _on_category_pressed(cat: int) -> void:
	if _selected_category == cat:
		return
	_selected_category = cat
	_rebuild_item_grid()


# --- 商品グリッド -------------------------------------------------------

func _rebuild_item_grid() -> void:
	for child in item_grid.get_children():
		child.queue_free()
	_cards.clear()

	var items: Array = []
	for it: ItemData in DataRegistry.get_items_by_category(_selected_category):
		# メタ強化によるゲート：requires_meta が未解放なら陳列しない
		if it.requires_meta != &"" and not GameState.has_meta_unlock(it.requires_meta):
			continue
		items.append(it)
	# 価格昇順で並べる
	items.sort_custom(func(a: ItemData, b: ItemData) -> bool: return a.price < b.price)

	empty_label.visible = items.is_empty()
	for it: ItemData in items:
		var card := _card_factory.build(it)
		item_grid.add_child(card)
		_cards[it.id] = card
		_card_factory.refresh(card, it)


func _refresh_all_cards(_v: int = 0) -> void:
	for id in _cards.keys():
		var it := DataRegistry.get_item(id)
		if it != null:
			_card_factory.refresh(_cards[id], it)


# --- イベントハンドラ ---------------------------------------------------

func _on_buy_requested(id: StringName, qty: int) -> void:
	ShopService.buy(id, qty)


func _on_item_purchased(id: StringName) -> void:
	var card: PanelContainer = _cards.get(id)
	if card != null:
		var it := DataRegistry.get_item(id)
		if it != null:
			_card_factory.play_purchase_feedback(card, it)
	_refresh_all_cards()


func _on_inventory_changed(id: StringName, _new_count: int) -> void:
	var card: PanelContainer = _cards.get(id)
	if card == null:
		return
	var it := DataRegistry.get_item(id)
	if it != null:
		_card_factory.refresh(card, it)


func _on_meta_upgrade_purchased(_meta_id: StringName, _new_level: int) -> void:
	_rebuild_item_grid()


# --- i18n ---------------------------------------------------------------

func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		# カテゴリボタンは Button.text に翻訳キーが入っているので Godot が自動再翻訳する。
		# カード側は tr() 経由で組み立てた文言を含むため、明示的に貼り直し＋数値再描画する。
		for id in _cards.keys():
			var it := DataRegistry.get_item(id)
			if it == null:
				continue
			_card_factory.rebuild_static_text(_cards[id], it)
		_refresh_all_cards()
