# T-DuoBar 1.12.1 — Ethernet icon and centered symbols

Build 38 · Universal 2 (Apple Silicon and Intel) · macOS 13+.
Experimental ad-hoc signed community build; not Developer ID signed or Apple notarized.

## Fixes / Исправления

- Replace the cable connector with the macOS-style Ethernet status mark (‹•••›) in the menu bar ring and Network section. Thanks to [cojonesnaut](https://github.com/cojonesnaut) for the reference in [issue #4](https://github.com/squazaryu/T-DuoBar/issues/4).
- Center network, audio and performance symbols within the ring when battery percentages are hidden. Account for asymmetric AirPods Pro and temperature-symbol padding.
- Keep existing symbol placement when battery percentages are displayed.
- Preserve build-number tracking when preparing Homebrew releases.

Новая Ethernet-иконка по примеру macOS; центральные значки без процентов выровнены внутри кольца. Положение в режиме с процентами сохранено. Подготовка Homebrew-релизов сохраняет номер сборки.

No breaking changes or migrations. Existing preferences are retained. No new polling, background workers or timers.
Несовместимых изменений и миграций нет. Настройки сохраняются; новых опросов, фоновых процессов и таймеров нет.

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

97 focused tests passed, with no failures or skips. Checks include 19 center states at 80%, 100% and 105% icon sizes, pixel-identical percentage placement, battery digits/ring clearance, charging renders, audio transition rendering and Homebrew update behavior. [Validation details](https://github.com/squazaryu/T-DuoBar/blob/v1.12.1/release/1.12.1/VALIDATION.md).

Intel is compiled; runtime checks are on Apple Silicon. No full-suite pass or new long-duration energy audit is claimed. Homebrew verifies the DMG SHA-256 but does not add notarization. Downloaded apps may require [Apple's individual-app approval procedure](https://support.apple.com/en-us/102445).
