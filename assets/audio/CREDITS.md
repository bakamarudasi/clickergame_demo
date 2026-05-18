# Audio Credits

このプロジェクトで使用しているすべての音源の出典・作者・ライセンス情報。
**新しい音源を追加したら必ずこのファイルを更新すること**。CC0 でも追跡用に
出典は書いておく（後でライセンス監査するときに楽）。

ライセンス略号：
- **CC0**: パブリックドメイン。クレジット不要だが記載推奨
- **CC BY**: クレジット表記必須（作者名 + ライセンス + 元 URL）
- **CC BY-SA**: 上記 + 派生物も同ライセンスにする義務（避ける）
- **Site Custom**: サイト独自規約（魔王魂・BGMer 等。各サイトの規約に従う）
- **TODO**: 未記入。ファイル名だけ仮で書いてるので埋めること

---

## BGM

| ファイル | スロット | 曲名 | 作者 | サイト | ライセンス | 備考 |
|---|---|---|---|---|---|---|
| `bgm/work.ogg` | `&"work"` | _TODO_ | _TODO_ | _TODO_ | TODO | Work タブ作業 BGM |
| `bgm/room.ogg` | `&"room"` | _TODO_ | _TODO_ | _TODO_ | TODO | Room タブ観測 BGM |
| `bgm/shop.ogg` | `&"shop"` | _TODO_ | _TODO_ | _TODO_ | TODO | Shop タブ商業 BGM |
| `bgm/meta.ogg` | `&"meta"` | _TODO_ | _TODO_ | _TODO_ | TODO | Meta タブ覚醒 BGM |
| `bgm/prestige.ogg` | `&"prestige"` | _TODO_ | _TODO_ | _TODO_ | TODO | プレステージ実行ジングル |

<!-- 記入例:
| `bgm/room.ogg` | `&"room"` | Cyber Dream Loop | Eric Matyas | https://soundimage.org/looping-music/ | CC BY 4.0 | Room タブ観測 BGM |
-->

---

## SFX

| ファイル | 用途 | 曲名/識別子 | 作者 | サイト | ライセンス | 備考 |
|---|---|---|---|---|---|---|
| `sfx/click.ogg` | Work クリック | _TODO_ | _TODO_ | _TODO_ | TODO | |
| `sfx/purchase.ogg` | Shop 購入成功 | _TODO_ | _TODO_ | _TODO_ | TODO | |
| `sfx/unlock.ogg` | CG/衣装解禁 | _TODO_ | _TODO_ | _TODO_ | TODO | |
| `sfx/xray_caught.ogg` | 観測バレ | _TODO_ | _TODO_ | _TODO_ | TODO | |
| `sfx/stage_advance.ogg` | 信頼度ステージアップ | _TODO_ | _TODO_ | _TODO_ | TODO | |
| `sfx/toast_notice.ogg` | トースト通知 | _TODO_ | _TODO_ | _TODO_ | TODO | |
| `sfx/toast_warn.ogg` | 警戒トースト | _TODO_ | _TODO_ | _TODO_ | TODO | |
| `sfx/tab_switch.ogg` | タブ切替 | _TODO_ | _TODO_ | _TODO_ | TODO | |

---

## ライセンス全文・参照

DL 時に「ライセンス全文を含めること」が条件のものはここに転載する。
通常 CC0 / CC BY 4.0 は本リンクで参照すれば十分：

- CC0 1.0 Universal: https://creativecommons.org/publicdomain/zero/1.0/
- CC BY 4.0: https://creativecommons.org/licenses/by/4.0/
- CC BY-SA 4.0: https://creativecommons.org/licenses/by-sa/4.0/

---

## クレジット画面への反映タスク

ゲーム内クレジット画面（未実装）に表示する際の出典文字列のドラフト：

> Audio:
> - "Cyber Dream Loop" by Eric Matyas (soundimage.org) — CC BY 4.0
> - "○○○" by 魔王魂 (maou.audio)
> - UI Audio Pack by Kenney (kenney.nl) — CC0
> - ...

クレジット画面実装時に Settings ダイアログから飛ばせる導線を作る予定。
それまでは README / このファイルを「公式の出典」とみなす。

---

## 監査チェックリスト

新しい音源を追加したときに踏むチェック：

- [ ] 上の表に行を追加した（**TODO のままにしない**）
- [ ] ライセンスが **CC BY-NC ではない**ことを確認した（商用配信不可になる）
- [ ] ライセンスが **CC BY-SA ではない**ことを確認した（プロジェクト全体がコピーレフトに巻き込まれる）
- [ ] ファイル形式が `.ogg` になっている（mp3/wav を変換し忘れていない）
- [ ] ファイル名がスロット名 (`work` / `room` / `shop` / `meta` / `prestige`) と一致している
- [ ] `BGMService.set_track_stream(...)` を `scripts/main.gd` に登録した
- [ ] Godot で起動確認してクラッシュしないか確認した
- [ ] 音量設定ダイアログから音量変更が効くことを確認した
