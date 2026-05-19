class_name Enums
extends Object

enum Personality {
	SAINTLY_DUAL,
	ANCIENT_FREE,
	SISTERLY_TEASE,
}

# この13カテゴリで確定。新コンテンツは「既存カテゴリのどれかに入る」前提で考え、
# 増やしたくなったら PROGRESSION.md §1.2 を見直してから議論する。
enum ItemCategory {
	DAILY,
	HOBBY,
	BODY_CARE,
	ROMANCE,
	DIRECT_TOY,
	DIRECT_DRUG,
	DIRECT_BIND,
	DIRECT_PROT,
	COS_OUTFIT,
	COS_PARTS,
	INVITATION,
	RULE,
	SCOPE,
	RECIPE,    # コンボレシピ（情報アイテム）。買うと recipe_known_* フラグが立つ
}

enum Reaction {
	DELIGHTED,
	HAPPY,
	SHY,
	CONFUSED,
	REJECTED,
	SLAPPED,
	DOMINATED,
	GUILT_BREAK,
	UNSHAKEN,
	LOCKED_OUT,
}

enum EffectKind {
	TRUST_ADD,
	CG_UNLOCK,
	OPERATOR_UNLOCK,
	COSTUME_UNLOCK,
	HARASSMENT_LOCK,
	RULE_ACTIVATE,
	SCOPE_BATTERY_REFILL,
	SCOPE_GRANT,
	INTIMACY_ADD,        # 親密度（永続・上昇のみ）
	AROUSAL_ADD,         # 発情度（時間で減衰、親密度で増加補正）
	MEMORY_UNLOCK,       # GameState.unlock_memory(target_id) を呼ぶ
	CG_PLAY,             # 解放状態に関わらず target_id の CG を即時再生（既視 CG の再演出に使う）
}

enum TriggerKind {
	ITEM,
	TOUCH,
	HARASSMENT,
	INSPECTION,
	XRAY_CAUGHT,
	STAGE_UP,         # ステージ昇格瞬間。trigger_id は &"1" / &"2" ... 新ステージ番号
	PRESTIGE,         # prestige 完了直後の再会。trigger_id は空
	AROUSAL_MAX,      # 発情度が AROUSAL_MAX に到達した瞬間。trigger_id は空
	LOCKED_REVISIT,   # ロック中のオペにアクション試行。trigger_id は空
	IDLE,             # アイドルフレーバー。trigger_id は &"stage_1" / &"stage_2" / &"stage_3" / &"fire"
}

# CG ビューアの 1 ステップ表示モード。
enum CGStepMode {
	PORTRAIT,    # 立ち絵 + 台詞ボックス（Room と同じ画面構成）
	FULL_CG,     # 全画面イラスト + 台詞ボックス
}

# CG ステップ突入時の演出。素材が無くてもこれで「動き」を出す。
# 既存 CG はデフォルト NONE のままなので影響なし。
enum CGStepTransition {
	NONE,       # 無演出（即時切替）
	FADE,       # 立ち絵 / CG をフェードイン
	SHAKE,      # ルート全体を短く揺らす（衝撃/赤面/銃口など）
	FLASH,      # 白フラッシュを 1 回かぶせる（覚醒/視線交差など）
}

enum UpgradeEffectKind {
	ADD_CLICK,
	ADD_PER_SEC,
	MULT_CLICK,
}

enum UpgradeRarity {
	COMMON,
	RARE,
	EPIC,
	LEGENDARY,
}

enum UnlockTrigger {
	AUTO_ON_STAGE,
	ITEM_USE,
	TIME_OF_DAY,
}

enum CostumeUnlockVia {
	STAGE,
	SHOP_PURCHASE,
}

enum MetaPillar {
	AFFINITY,    # 親愛度・絆系
	ECONOMY,     # クリック・自動収益・新強化解放
	CATALOG,     # ショップ品揃え・カテゴリ解放
}
