extends Control

# Shopタブ。アイテム購入のみを担当。
# 他タブを直接参照しない。ShopService 経由でのみ購入処理を行う。

@onready var category_select: OptionButton = %CategorySelect
@onready var item_list: VBoxContainer = %ItemList

const CATEGORY_ENTRIES := [
	{ "label": "日常", "value": Enums.ItemCategory.DAILY },
	{ "label": "趣味", "value": Enums.ItemCategory.HOBBY },
	{ "label": "ボディケア", "value": Enums.ItemCategory.BODY_CARE },
	{ "label": "ロマン", "value": Enums.ItemCategory.ROMANCE },
	{ "label": "玩具", "value": Enums.ItemCategory.DIRECT_TOY },
	{ "label": "薬品", "value": Enums.ItemCategory.DIRECT_DRUG },
	{ "label": "拘束", "value": Enums.ItemCategory.DIRECT_BIND },
	{ "label": "保護", "value": Enums.ItemCategory.DIRECT_PROT },
	{ "label": "衣装", "value": Enums.ItemCategory.COS_OUTFIT },
	{ "label": "パーツ", "value": Enums.ItemCategory.COS_PARTS },
	{ "label": "招待状", "value": Enums.ItemCategory.INVITATION },
]


func _ready() -> void:
	EventBus.currency_changed.connect(_refresh_buttons)
	EventBus.item_purchased.connect(_on_item_purchased)
	category_select.item_selected.connect(_on_category_changed)
	_populate_categories()
	_rebuild_item_list()


func _populate_categories() -> void:
	category_select.clear()
	for i in CATEGORY_ENTRIES.size():
		category_select.add_item(CATEGORY_ENTRIES[i].label, i)


func _selected_category() -> int:
	var idx := category_select.selected
	if idx < 0:
		idx = 0
	return CATEGORY_ENTRIES[idx].value


func _on_category_changed(_idx: int) -> void:
	_rebuild_item_list()


func _rebuild_item_list() -> void:
	for child in item_list.get_children():
		child.queue_free()
	for it: ItemData in DataRegistry.get_items_by_category(_selected_category()):
		var b := Button.new()
		b.text = "%s — ¥%d" % [it.display_name, it.price]
		b.set_meta("item_id", it.id)
		b.pressed.connect(ShopService.buy.bind(it.id))
		item_list.add_child(b)
	_refresh_buttons(0)


func _refresh_buttons(_v: int = 0) -> void:
	for child in item_list.get_children():
		if child is Button:
			var id: StringName = child.get_meta("item_id")
			child.disabled = not ShopService.can_buy(id)


func _on_item_purchased(_id: StringName) -> void:
	_refresh_buttons()
