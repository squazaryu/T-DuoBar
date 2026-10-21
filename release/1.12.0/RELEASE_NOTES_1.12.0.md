# T-DuoBar 1.12.0 — adaptive battery percentages

Build 36 · Universal 2 (Apple Silicon and Intel) · macOS 13+.
Experimental ad-hoc signed community build; not Developer ID signed or Apple notarized.

## What's new / Что нового

- Optional battery digits in the menu bar ring, with a cutout that adapts to the label width. Enable **Battery percentage in menu bar** in Settings → General → Appearance; off by default.
- A shared circular silhouette, larger center symbol and volume dots that follow the outer circle, with and without percentages. External power no longer shrinks the center.
- A green power ring omits the duplicate lightning bolt. Monochrome mode retains a bolt to identify connected power.
- Sharper percentage text: digits render at their final point size with backing-pixel alignment, rather than being resized with the ring canvas. Includes 1× / 2× rendering checks.
- Updated GitHub presentation with the app icon, native light/dark menu and settings renders, and a sourced comparison of fork focus.

Проценты батареи в адаптивном вырезе кольца, общий круглый силуэт обоих режимов, более крупный центральный значок и чёткие цифры без повторного масштабирования. При зелёном кольце молния скрыта, в монохромном режиме сохраняется. Новая настройка по умолчанию отключена.

No breaking changes or migrations. Existing preferences are retained. The glyph option uses existing cached battery readings and adds no polling or timers.
Несовместимых изменений и миграций нет. Настройки сохраняются; новых таймеров и опросов батареи не добавлено.

## Install / Update

```sh
brew install --cask squazaryu/tap/t-duobar
```

For an existing installation, quit DuoBar, then:

```sh
brew update
brew upgrade --cask squazaryu/tap/t-duobar
open /Applications/DuoBar.app
```

The in-app Homebrew action also updates and restarts the app.

## Validation and limits

90 focused glyph, typography, charging, settings and localization tests passed, plus one repository-artwork render check. Tests cover all readings 0–100 with/without a bolt, ring clearance, the shared center across both modes and power states, and native raster preservation at the supported icon sizes. Native fixtures were inspected in both appearances. This is targeted validation, not a complete full-suite run or a long-duration energy audit. [Validation details](https://github.com/squazaryu/T-DuoBar/blob/v1.12.0/release/1.12.0/VALIDATION.md).

Intel is compiled; runtime checks run on Apple Silicon. Very small icon sizes remain limited by available pixels; 100–105% is recommended for percentage readability. Homebrew verifies the DMG SHA-256 but does not add notarization. Downloaded apps may require [Apple's individual-app approval procedure](https://support.apple.com/en-us/102445).
