# Clicker Game Demo

Godot 4.6+ で作るシンプルなクリッカーゲームの雛形。

## 構成

- `project.godot` — Godot 4.6 プロジェクト設定（縦持ち 720x1280、GL Compatibility）
- `scenes/main.tscn` — メインシーン（タイトル / スコア / クリックボタン / アップグレード）
- `scripts/main.gd` — クリック・アップグレード・自動収益のロジック
- `icon.svg` — プロジェクトアイコン

## 遊び方

1. Godot 4.6+ でこのフォルダを開く（プロジェクトをインポート）
2. F5 で実行
3. `CLICK!` を押してスコアを稼ぐ
4. アップグレードでクリック威力 / 自動収益（1秒ごと）を強化

## 翻訳（i18n）

`translations/strings.csv` に key + 言語列を追加するだけで多言語化できる。

```
keys,ja,en
WORK_CLICK_BUTTON,CLICK!,CLICK!
ROOM_TRUST_FMT,信頼度 %d,Trust %d
```

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

1. `strings.csv` に列追加（例 `zh`）
2. `LocaleService.SUPPORTED_LOCALES` に `"zh"` 追加
3. `project.godot` の `locale/translations` に `strings.zh.translation` を追加
4. Godot エディタで CSV を再インポート

## 次に足せそうなもの

- セーブ / ロード（`user://save.json`）
- アップグレード追加とパッシブ倍率
- アニメーション・効果音・パーティクル
