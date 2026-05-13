# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

Godot 4.6 GDScript project — a clicker game with character interaction (Work / Room / Shop / Status / Meta tabs). 1280×720 landscape, GL Compatibility renderer. No build/lint/test tooling: this is a pure Godot project. To run: open the folder in Godot 4.6+ and press F5. No CLI test runner exists; verification is manual via the in-editor play session. The detailed game spec lives in `SPEC.md` — read it before designing any new gameplay system.

## Architecture (strict 4-layer)

```
UI (per-tab, never reaches across)  →  Service (pure, static)  →  Autoload state  ←  EventBus signals  →  UI
                                                                       ↑
                                                            Data (.tres masters)
```

Hard rules:
- **UI tabs never reference each other.** No `get_node("../OtherTab")`. Cross-tab communication is one-way: UI calls a Service, Service mutates `GameState`, `GameState`/Service emits an `EventBus` signal, every interested tab listens.
- **Services are `class_name X extends Object` with only `static` methods.** They never hold state — `GameState` is the only source of truth. Because `Object` has no `tr()`, services use `TranslationServer.translate("KEY")` for translation.
- **Adding content should not require code changes.** Drop a `.tres` into `data/<category>/`, `DataRegistry` loads it at startup and indexes by `id`. New operators, items, costumes, scopes, upgrades, reactions all follow this.

### Autoloads (in `scripts/autoload/`)

| Autoload | Role |
|---|---|
| `EventBus` | All cross-tab signals. The single hub — UI never connects to another UI. |
| `DataRegistry` | Loads every `data/<category>/*.tres` at boot, exposes `operators`/`items`/`costumes`/... dicts keyed by id. |
| `GameState` | The only mutable state. Currency, per-operator `OperatorRuntime`, prestige, meta unlocks, xray state. |
| `ReactionDispatcher` | Funnels reaction-rule lookups (gift / touch / inspection / xray / idle / prestige) through `ReactionResolver` and emits `reaction_played`. |
| `LocaleService` | Locale switching. Emits its own `locale_changed` plus Godot's `NOTIFICATION_TRANSLATION_CHANGED`. |

### Services (in `scripts/services/`)

`EconomyService` (click / tick / upgrade purchase), `ShopService`, `GiftService`, `TouchService`, `InspectionService`, `ScopeService` (xray binoculars), `MetaUpgradeService`, `ReactionResolver` (matches `ReactionRule.tres` against trigger + trust + active rules + consecutive-count gates).

### The xray-binocular subsystem (`紳士眼鏡`)

This is the central mechanic and touches several layers. Key flow:
- `ScopeService.toggle()` flips `GameState.xray_active` and starts draining `scope_battery_seconds`. `ScopeService.tick(delta, op_id)` runs every frame from RoomTab's `_process`, accumulating `xray_suspicion` on the operator. When it hits `UIConstants.XRAY_SUSPICION_THRESHOLD`, an `xray_caught` signal fires.
- `CostumeData.sprite_xray_variants` is a `Dictionary[view_kind → Texture2D]`. A `ScopeData` picks the lookup key via its `view_kind`. Adding a new view type means new `.tres` files only — no code change.
- "Reverse mode" (`ScopeData.is_inverse`) swaps base/window: normally body=clothed and window=xray; inverse means body=xray and window=clothed. `PortraitController._refresh_scope_window` handles both.
- Mosaic resolution is keyed by `ScopeData.resolution_level` → block size; only the side currently showing the xray texture gets the shader applied.

## UI organization

Large tab scripts are split into a sibling folder of `RefCounted` helpers. Established pattern:

- `scripts/ui/work_tab.gd` (orchestrator) + `scripts/ui/work_tab/`:
  - `upgrade_card_factory.gd` — builds and refreshes upgrade cards, emits `expand_requested` / `buy_requested` / `qty_mode_changed`
  - `click_feedback.gd` — squash / flash / +N popup / paper particles / approval stamp
  - `golden_document.gd` — random bonus document spawner
- `scripts/ui/room_tab.gd` (orchestrator) + `scripts/ui/room_tab/`:
  - `portrait_controller.gd` — body / face overlay / expression flash / scope window / mosaic / scene-mode dispatch
  - `idle_flavor_tracker.gd` — 1/3/5/6-minute IDLE stage firing
  - `dialogue_log_view.gd` — log append + auto-scroll
- `scripts/ui/quantity_selector.gd` — shared ×1/×10/×100/×Max selector (used by Work cards and Shop detail).

**When splitting another tab, follow this convention:**
- Helpers are `class_name X extends RefCounted`.
- They take `host: Control` and concrete UI node refs in `_init()`.
- They expose signals for user-driven events; the host wires them to its own handlers.
- Tween/`add_child` are routed through the host (e.g. `host.create_tween()`).

## i18n

Two CSV trees: `translations/strings.csv` (UI/system text) and `translations/dialogues/<operator_id>.csv` (per-character dialogue). Both are imported by Godot into `.translation` files.

Conventions:
- **Static text in `.tscn`**: put the key directly in `text="UI_KEY"`. Godot auto-translates and re-translates on locale change.
- **Strings built in code**: `tr("UI_KEY")` from a `Node`, `TranslationServer.translate("UI_KEY")` from a `RefCounted`/`Object` (these have no `tr()`).
- **`Button.text = "KEY"` is auto-translated** — don't manually re-translate in `NOTIFICATION_TRANSLATION_CHANGED`. The dynamic UI rebuild handlers exist to refresh strings built with `tr()` and `%` formatting, not literal keys.
- **`Resource` fields like `display_name`** store the key; consumers call `tr(op.display_name)`.

Each tab implements `_notification(NOTIFICATION_TRANSLATION_CHANGED)` to rebuild its `tr()`-formatted strings.

Adding a language: add a column to every CSV, add the locale to `LocaleService.SUPPORTED_LOCALES`, register `.translation` paths in `project.godot`'s `locale/translations`, re-import in the Godot editor.

## UI styling

`scripts/ui/ui_constants.gd` is the single source of truth for font sizes / spacings / palette / animation timings / game balance constants. `scripts/ui/theme_factory.gd` builds the Theme from `UIConstants` at boot.

- `.tscn` references styles by `theme_type_variation = &"DisplayButton"` (etc), never hardcoded font sizes.
- `.gd` references `UIConstants.COLOR_BG` / `UIConstants.TOAST_HOLD_SEC` etc directly.
- Helpers that need a local design constant (e.g. card paper color in `UpgradeCardFactory`) keep it as a `const` in that file rather than polluting `UIConstants`. `UIConstants` is for values used across multiple tabs.

To add a semantic style: add `FONT_X` and `VAR_X_LABEL` to `UIConstants`, add the variation in `ThemeFactory`, reference `theme_type_variation = &"X"` from `.tscn`.

## Tooling notes

- No Godot binary is assumed to be available in the sandbox — do not try `godot --check-only`. Code correctness verification is by careful reading.
- Branch convention: develop on `claude/<task>-<hash>` (see top-level instructions). Never push to `main`.
- Built-in `addons/asset_audit/` is enabled — leave it alone unless asked.
