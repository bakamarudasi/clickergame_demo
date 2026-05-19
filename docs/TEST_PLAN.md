# テストプラン — clickergame_demo

> 手動テスト用チェックリスト。Godot 4.6+ で `F5` 起動し、上から順に潰していく想定。
> 自動テスト基盤なし。本プランは「機能が壊れていないか」と「データ追加で増えた分のサニティチェック」を兼ねる。
> 完了したら `[ ]` を `[x]` に置き換える運用。

---

## 0. スモーク（毎回最初に）

- [ ] 起動：エラーログ・警告がコンソールに出ない（`push_error` / `push_warning` ゼロ）
- [ ] 4タブ（Work / Room / Shop / Meta）すべて開いて即落ちしない
- [ ] 言語スイッチ ja → en → zh_CN 即時反映、未翻訳キー（生キー文字列）なし
- [ ] 1280×720 で全UIがクリップせず収まる

---

## 1. Work タブ

- [ ] クリックで通貨が増える（`click_power` 反映）
- [ ] アップグレード購入で `click_power` / `per_second` が増える
- [ ] アップグレード価格が指数で伸びる（×1.15 程度）
- [ ] `×1 / ×10 / ×100 / ×Max` 数量切替が機能する
- [ ] `×Max` で正しく「買える最大数」になる（端数で止まる）
- [ ] 数量モードを切り替えても価格表示が即時更新
- [ ] ゴールデン書類が 3〜7 分の間にランダム発火 → クリックでボーナス通貨
- [ ] クリックフィードバック（squash / +N popup / 紙吹雪 / 承認スタンプ）が出る
- [ ] AutoTimer 1秒ティックで `per_second` ぶん通貨が増える

---

## 2. Room タブ

### 2.1 立ち絵 / 表情
- [ ] オペ選択で立ち絵が切り替わる
- [ ] コスチューム変更（後述）で立ち絵差し替え
- [ ] 反応発火時に表情フラッシュが 2.5 秒入る
- [ ] 発情度（arousal）に応じて modulate が桜色に近づく
- [ ] 背景画像がオペごとに切り替わる（per-operator background）
- [ ] BackgroundView の dim（modulate 0.85）が効いて立ち絵が前に出る
- [ ] 立ち絵が上のステータスバーへはみ出さない（クリップOK）

### 2.2 ギフト
- [ ] インベントリのアイテムを選択して渡すと信頼度が上がる
- [ ] 渡したアイテムの `gift_history` が累積する
- [ ] ハラスメントカウンタがギフトごとに減衰（HARASSMENT_DECAY_PER_GIFT=1）
- [ ] ゴム T0/T1/T2 の段階分岐がトラスト＋累計回数で正しく出し分け
- [ ] `medical_protector` 累計 100/500/1000 でマイルストーン CG が解放

### 2.3 タッチ
- [ ] 15 スポット全部、解禁ステージに達すれば押せる
- [ ] ハラス系（強引/胸グロープ）押下で `harassment_counter` が増える
- [ ] 10 ポイント蓄積で `operator_locked` 発火 → 5 分ロック
- [ ] ロック中はタッチ／ギフト不可、再訪問で `LOCKED_REVISIT` 反応
- [ ] 同スポット連打で alt 台詞ローテ

### 2.4 検査
- [ ] 検査ボタン押下で `last_inspection_unix` 更新
- [ ] クールダウン中は再検査不可
- [ ] reject / compliant / underwear T0/T1/T2 の分岐が正しい
- [ ] 深夜検査 alt（midnight）が時間条件で発火する

### 2.5 紳士眼鏡（Scope / xray）
- [ ] バッテリーがある状態で ON にできる
- [ ] バッテリー秒が時間とともに減る
- [ ] xray 中、立ち絵が透視テクスチャに切替（テクスチャ null ならプレースホルダ）
- [ ] モザイクシェーダーが `ScopeData.resolution_level` に応じて変わる
- [ ] `is_inverse` スコープで base/window 関係が反転する
- [ ] `xray_suspicion` が `XRAY_SUSPICION_THRESHOLD` 到達で `xray_caught` 発火
- [ ] バッテリー切れで自動 OFF
- [ ] OFF にすると suspicion が減衰（仕様確認）

### 2.6 ダイアログログ
- [ ] 直近 10 件の会話が残る
- [ ] 新規会話で自動スクロール末尾追従
- [ ] CG 解放時の自動ポップアップ後もログ整合

### 2.7 アイドル
- [ ] 1分 / 3分 / 5分 で IDLE 段階の flavor が出る
- [ ] 6分で `apply_click_buff(×2, …)` が立つ
- [ ] バフ持続中はクリック値が×2、切れたら素の値に戻る

### 2.8 発情度・親密度
- [ ] タッチ／反応で arousal が増加（親密度ブースト込み）
- [ ] 時間で `AROUSAL_DECAY_PER_SEC` ずつ減衰
- [ ] AROUSAL_MAX 到達で 1 度だけ MAX 反応
- [ ] 80% 以下に落ちたら次回また MAX 反応が出せる
- [ ] 親密度は減らない（永続上昇のみ）

### 2.9 ステージ昇格
- [ ] trust 閾値超えで stage_advanced 発火
- [ ] 各遷移（警戒→様子見→打ち解け→親密→陥落）の STAGE_UP 反応

---

## 3. Shop タブ

- [ ] カテゴリ別タイル切替が機能
- [ ] 詳細パネルで価格／説明／信頼ゲートが表示
- [ ] 信頼ゲート未達で購入ボタン disabled
- [ ] 通貨不足で購入ボタン disabled
- [ ] `×1 / ×10 / ×100 / ×Max` 全て購入できる
- [ ] 購入で通貨が即時減り、inventory が増える
- [ ] スコープアイテム購入で `owned_scopes` に追加、Room で装備可能
- [ ] ルールアイテム購入で `active_rules` に追加、反応条件に影響

---

## 4. Meta タブ

- [ ] 累計¥100K 到達でメタタブが解放（タブボタン visible）
- [ ] 累計が 100K 未満ではメタタブが隠れる
- [ ] プレステージ実行で `prestige_count` +1、`prestige_currency` 加算
- [ ] プレステージ式 `floor(cbrt(pool / 100K))` で獲得計算
- [ ] プレステージ後、走行中ステート（currency / upgrades / click_power / per_sec / total_earned_this_run / 一時バフ）がリセット
- [ ] **保持**：trust / CG / Memory / costume / prestige_count / prestige_currency / meta_upgrade_levels / bond
- [ ] 全アンロックオペに `pending_prestige_greet` フラグが立つ
- [ ] 次回 Room で該当オペを選ぶと PRESTIGE 反応が 1 度だけ流れる
- [ ] `starter_funds` メタ強化で次周回開始通貨が増える
- [ ] `click_perm_mult` / `per_sec_perm_mult` メタが effective_* に反映

---

## 5. CG ビューア

- [ ] CG 解放時に自動全画面ポップアップ
- [ ] PORTRAIT モード（立ち絵＋顔差分＋台詞ボックス）
- [ ] FULL_CG モード（全画面イラスト＋台詞ボックス）
- [ ] クリック進行で次ステップ
- [ ] 画像 null でプレースホルダ表示
- [ ] BGM / SFX スロットが鳴る（or null で安全）
- [ ] 既見 CG の `cg_play_requested` で再生（解放履歴は触らない）
- [ ] CG 中に裏で操作不可

---

## 6. セーブ／ロード（**新規実装の重点**）

### 6.1 基本
- [ ] 初回起動：セーブ無し → デフォルト state で開始
- [ ] 何かしら操作 → ウィンドウ閉じる → 再起動で前回 state 復元
- [ ] 30 秒オートセーブが効く（user://save.json の mtime が更新される）
- [ ] 強制終了（kill / クラッシュ模擬）：直前 30s 以内のオートセーブが残る

### 6.2 復元範囲
- [ ] currency / click_power / per_second
- [ ] click_buff_multiplier + click_buff_until_unix（リロード時に残時間が反映）
- [ ] owned_upgrades（各レベル）
- [ ] unlocked_operators
- [ ] operator_runtime: trust / current_stage / equipped_costume / unlocked_costumes / gift_history / harassment_counter / locked_until / last_inspection_unix / xray_suspicion / intimacy / arousal / arousal_last_unix / arousal_peak / arousal_max_announced / pending_prestige_greet
- [ ] inventory（item_id → count）
- [ ] seen_cgs（解放済みCGリスト）
- [ ] unlocked_memories
- [ ] active_rules
- [ ] owned_scopes / equipped_scope_id / scope_battery_seconds / xray_active
- [ ] prestige_count / prestige_currency / bond / meta_upgrade_levels
- [ ] total_earned_this_run / total_earned_ever

### 6.3 UI 同期
- [ ] ロード後、Work タブの数値表示が即正しい
- [ ] Room タブの立ち絵・ゲージ・コスチュームがロード後即正しい
- [ ] Shop で過去購入済みアイテムの所持数が正しい
- [ ] Meta タブの表示・ボタン状態が累計¥100K 判定で正しい
- [ ] xray_active がロード後 true でも、battery が残っていなければ即 OFF（タブ初期化で安全側）

### 6.4 エッジ
- [ ] save.json を手動削除して起動 → デフォルト state
- [ ] save.json を意図的に破損（ランダム文字列） → push_error 出してデフォルトで起動、クラッシュしない
- [ ] バージョン不一致（version フィールド改ざん） → push_warning で続行（or デフォルト）
- [ ] プレステージ実行直後にセーブ → ロードで `prestige_count` が増えた状態になる
- [ ] AROUSAL_MAX 中にセーブ → ロード後も `arousal_max_announced` フラグが正しく残る（多重発火しない）

### 6.5 互換
- [ ] 既存セーブと CLAUDE.md/SPEC.md の現行データ整合（操作後にセーブ → コードを少し触って起動 → 復元できる）
- [ ] StringName / String の混在で型エラーなし（typed Array[StringName] / Dictionary キー）

---

## 7. i18n

- [ ] ja / en / zh_CN それぞれで起動、未翻訳キー目視ゼロ
- [ ] 言語切替が即時（`locale_changed` シグナル）
- [ ] 動的生成テキスト（`tr() + %` フォーマット）も切替で更新
- [ ] `.tscn` 静的キー（`text="UI_KEY"`）が切替で自動再翻訳
- [ ] CSV 改行・カンマ・特殊文字混在で `.translation` インポートが通る

---

## 8. テーマ / UI 統一

- [ ] フォントサイズが `UIConstants` 経由（`.tscn` にハードコードなし）
- [ ] サイバーブルー配色が全タブで一貫
- [ ] `theme_type_variation` が各 Display Button / Label で当たっている
- [ ] HUD コーナーフレーム、セグメントバーがズレない
- [ ] スコープクロスヘアが xray ON で表示／OFF で非表示

---

## 9. オーディオ

- [ ] BGM がタブ切替でクロスフェード
- [ ] 音源 null でも無音停止で落ちない
- [ ] AudioSettings ダイアログで master / bgm / sfx ボリュームが効く
- [ ] 設定が現セッション内では保持される（セーブ対象は未定 — 将来）

---

## 10. 回帰チェック（既知の落とし穴）

- [ ] スコープ装備変更で `equipped_scope_id` が空にならない
- [ ] 紳士眼鏡 OFF 直後のフレームでシェーダーが残らない
- [ ] ハラスロック解除タイミングで `is_locked()` が false に戻る
- [ ] 数量モード `×Max` のとき残金 0 → 購入ボタン disabled
- [ ] CG 自動再生中の二重発火ガード（cg_viewer.visible で弾く）
- [ ] 言語切替時、Room タブの動的台詞ログがチラつかない
- [ ] アイドル 6 分バフ発火後すぐ再起動 → buff_until_unix が残時間として復元される

---

## 11. パフォーマンス（簡易）

- [ ] 1 時間放置で fps が落ちない
- [ ] 反応ログ・ダイアログログがメモリリークしない（直近10件 cap が効いてる）
- [ ] Tween / Timer が孤児化していない（タブ切替で kill 確認）

---

## 付録：テストデータ用 cheat（実装時に追加してOK）

- 通貨ジャンプ（+1M）
- 全 CG 解放
- 全コスチューム解放
- セーブ即時実行
- プレステージ即時実行
- バッテリー満タン化

> これらは debug ビルドのみ表示。リリース版では非表示。
