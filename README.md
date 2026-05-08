# Clicker Game Demo

Godot 4.6+ で作るシンプルなクリッカーゲームの雛形。

## 構成

- `project.godot` — Godot 4.6 プロジェクト設定（横持ち 1280x720、GL Compatibility）
- `scenes/main.tscn` — メインシーン（タイトル / スコア / クリックボタン / アップグレード）
- `scripts/main.gd` — クリック・アップグレード・自動収益のロジック
- `icon.svg` — プロジェクトアイコン

## 遊び方

1. Godot 4.6+ でこのフォルダを開く（プロジェクトをインポート）
2. F5 で実行
3. `CLICK!` を押してスコアを稼ぐ
4. アップグレードでクリック威力 / 自動収益（1秒ごと）を強化

## UI 共通定数

UI関連のハードコーディングを `scripts/ui/ui_constants.gd` に集約。

- フォントサイズ・余白・色・アニメーション時間 → `UIConstants.*`
- Theme は `ThemeFactory.build_default()` が `UIConstants` を読んで動的生成し、`Main` の `theme` に設定 → 子全部に伝播
- `.tscn` 側は `theme_override_font_sizes/font_size = 64` ではなく `theme_type_variation = &"DisplayButton"` で参照

```
DisplayButton  → CLICKボタン等
TabButton      → サイドバー
DisplayLabel   → オペ名（特大）
LargeLabel     → 通貨バー
TitleLabel     → セクション見出し
SubtitleLabel  → トースト・タブ見出し
```

`.gd` 側はトースト時間や色を `UIConstants.TOAST_HOLD_SEC` / `UIConstants.COLOR_BG` のように直接参照。

新しい semantic スタイルを足したいときは：
1. `UIConstants` に `FONT_X` と `VAR_X_LABEL` を追加
2. `ThemeFactory` に `_add_label_variation` の行を1つ追加
3. `.tscn` で `theme_type_variation` に名前を書く

## 翻訳（i18n）

UI / システム文言は `translations/strings.csv` に、キャラごとの会話台詞は `translations/dialogues/<operator_id>.csv` に分けて置く。どちらも CSV → `.translation` をエディタが自動生成する形式。

```
keys,ja,en
WORK_CLICK_BUTTON,CLICK!,CLICK!
ROOM_TRUST_FMT,信頼度 %d,Trust %d
```

```
# translations/dialogues/lemuen.csv
keys,ja,en,zh_CN
DIALOGUE_LEMUEN_GIFT_TEA,"あら、…","Oh? …",哎呀，…
```

`DIALOGUE_<OP>_*` キーは必ずキャラ別ファイルに置く（行数増加に強くするため）。新キャラを足したら同名 CSV を追加し、`project.godot` の `locale/translations` に 3 言語ぶんの `.translation` パスを追記する。

### 使い方の規約

- **UI 静的文字列**：`.tscn` の `text="UI_KEY"` に翻訳キーを書く（auto_translate が効く）
- **コードで動的に組む文字列**：`tr("UI_KEY")` を使う
- **Resource データ（display_name 等）**：`.tres` に翻訳キーを入れておけば `tr(op.display_name)` で解決される。リテラル文字列のままでも `tr()` は素通しなので壊れない
- **静的メソッドから呼ぶ**：services は `extends Object` なので `TranslationServer.translate("KEY")` を使う

### locale 切替

```gdscript
LocaleService.change_locale("en")  # 即時反映
```

`LocaleService.locale_changed` シグナル＋ Godot 標準の `NOTIFICATION_TRANSLATION_CHANGED` の両方が飛ぶので、各タブで `_notification` を実装して動的UIを再構築する。

### 言語追加

1. `strings.csv` および `translations/dialogues/*.csv` 全部に列追加（例 `zh`）
2. `LocaleService.SUPPORTED_LOCALES` に `"zh"` 追加
3. `project.godot` の `locale/translations` に `strings.zh.translation` および各キャラの `dialogues/<op>.zh.translation` を追加
4. Godot エディタで CSV を再インポート

## 次に足せそうなもの

- セーブ / ロード（`user://save.json`）
- アップグレード追加とパッシブ倍率
- アニメーション・効果音・パーティクル
