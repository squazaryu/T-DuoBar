# T-DuoBar 1.11.1 — German localization

Build 30 · Universal 2 (Apple Silicon and Intel) · macOS 13+.
Experimental community build with an ad-hoc signature; not Developer ID signed or Apple notarized.

## Changes / Что нового

- Complete German localization: 232 app strings, plus Bluetooth and location permission descriptions. Includes VPN, Liquid Glass appearance, transparency, battery time and Homebrew update dialogs.
- Select **Deutsch** in Settings → General → Language. German system languages, including Germany, Austria and Switzerland, resolve to German resources.
- Thanks to [CTeipen](https://github.com/CTeipen) for [PR #1](https://github.com/squazaryu/T-DuoBar/pull/1). The contribution was supplemented with the strings added in 1.11.0 and regression checks.

Полная немецкая локализация. Выберите **Deutsch** в настройках языка или используйте немецкий язык системы. Переведены VPN, оформление, прозрачность, сведения о батарее и обновления.

No breaking changes or migrations. Existing settings and the DuoBar.app filename are retained.
Несовместимых изменений и миграций нет; прежние настройки сохраняются.

## Installation and update

```sh
brew install --cask squazaryu/tap/t-duobar
```

To update an existing installation, quit DuoBar, then run:

```sh
brew update
brew upgrade --cask squazaryu/tap/t-duobar
open /Applications/DuoBar.app
```

The in-app Homebrew installation action also updates and restarts the app.

## Validation and limitations

16 focused localization, settings and native-render tests passed. German resources cover all English keys with matching format arguments and no duplicate keys. Light/dark German menu and settings renders were inspected. The full suite was interrupted while an existing glass-menu test waited for Bluetooth initialization; a complete full-suite pass is not claimed for this release. See [validation](https://github.com/squazaryu/T-DuoBar/blob/v1.11.1/release/1.11.1/VALIDATION.md).

Homebrew verifies the DMG checksum but does not add notarization. Downloaded copies may require individual approval using [Apple’s documented procedure](https://support.apple.com/en-us/102445). Intel is compiled; runtime verification is on Apple Silicon.
