# T-DuoBar

A community fork of [DuoBar by Mikeli7666](https://github.com/Mikeli7666/DuoBar), with extended battery, network, and audio controls for the macOS menu bar.

[Русский](README.ru.md) · [Development and local installation](DEVELOPMENT.md) · [Original project](https://github.com/Mikeli7666/DuoBar)

## Homebrew installation and updates

```sh
brew install --cask squazaryu/tap/t-duobar
brew update
brew upgrade --cask squazaryu/tap/t-duobar
```

If DuoBar was installed manually, quit it and back up `/Applications/DuoBar.app` before the first Homebrew install. `--adopt` only accepts an identical copy; do not use `--force` to discard an existing installation.

Starting with 1.6.0, DuoBar checks the published Homebrew manifest weekly while running and after launch/wake when a check is due. It notifies once per new version, subject to macOS notification permission. Click **Install with Homebrew** to open Terminal and run the bundled update script, then restart DuoBar. Updates are not installed without a click. If Homebrew is missing, the script displays instructions instead of installing the package manager automatically.

Settings → Updates provides a weekly-check toggle, manual check, installation prompt, release notes and a copyable update command. No update check is performed while DuoBar is closed; a missed check runs after the next launch. Failed checks retry after six hours, not continuously.

Starting with 1.6.1, settings always show the installed version and build number. Every manual check shows a dialog: the installed and available versions with an installation button, confirmation that the installed version is current, or a connection error. Weekly update notifications also identify the installed and available versions. Manual-check dialogs do not require macOS notification permission.

## Version 1.11.1 (build 30)

- Complete German localization, including VPN, Liquid Glass, update dialogs and permission descriptions. Select **Deutsch** in Settings → General → Language, or use a German system language.
- Thanks to [CTeipen](https://github.com/CTeipen) for the translation in [PR #1](https://github.com/squazaryu/T-DuoBar/pull/1).
- All 232 English keys are covered; format arguments and regional German language selection are tested. No breaking changes or migration steps.

The localization checks and native German renders passed 16 tests. The attempted full suite was interrupted while waiting in the existing Bluetooth API initialization test; see [1.11.1 validation](release/1.11.1/VALIDATION.md).

### Previous improvements (1.11.0, build 29)

- A separate VPN card shows the status and profile name reported by macOS, with optional interface details and a link to VPN settings. It can be hidden or reordered independently.
- Choose Classic or native Liquid Glass in Appearance. Glass requires macOS 26+, has a background-transparency slider, and keeps text and controls at normal opacity. Classic is the default; older systems and Reduce Transparency use the opaque presentation.
- Preview the actual menu from Settings. Both styles share the same content and disclosure state.
- Normal status-button presses toggle once on mouse-down, preventing a delayed mouse-up from reopening the menu. Context-menu and hover behavior are retained.
- VPN observation follows actual menu visibility, preserves the last snapshot while refreshing, coalesces changes and rejects cancelled or late reads.

No breaking changes or migration steps. Existing preferences are retained; a new VPN section is inserted beside Network in older saved orders.

### Previous improvements (1.10.0)

- Select the app language in Appearance: System, English, Russian, Ukrainian, Simplified Chinese or Traditional Chinese. Custom labels update without restarting.
- Optionally hide the empty accessory section. Connected devices return automatically; read failures remain visible.
- Optionally adjust volume by scrolling over the menu-bar icon. Both new behavior switches default to off.
- Battery and volume percentages sit beside their titles with consistent typography. The slider uses the available row width.
- Clicking the empty space between a section's text and chevron now opens and closes its details. System Settings buttons keep their separate action.

No breaking changes or preference migration. Existing settings are retained.

### Earlier improvements (1.9.0)

- Native General, Notifications and Updates settings tabs, plus a right-click menu for settings, update checks and quitting.
- Reorder the six popover sections with drag handles or Move up / Move down actions. Order and visibility are saved independently.
- A battery tooltip with percentage, power state and the current time estimate, using the existing status readings.
- Quick System Settings links and explanations for missing network, battery, audio and accessory data.
- A Personal Hotspot chain symbol for Wi-Fi that macOS marks as expensive; see the detection limitation below.
- A distinct T-DuoBar icon and native About panel with version, build and project links.
- Cancelled accessory reads no longer continue after closing the popover or overwrite newer results. Background timers can be coalesced by macOS.
- Aligned card buttons, a compact empty accessory row, a power bolt clear of the ring, and a title that stays at the top while details expand.

### Existing controls

- Battery time estimates until empty or fully charged, displayed inside the popover.
- Expandable battery details with the reported power-adapter wattage.
- Connected accessory battery readings, including separate AirPods components when macOS reports them. Disconnected cached readings are excluded.
- Expandable network details: Wi-Fi signal, band, channel, local IPv4 address, and address copying.
- Audio-output selection with persistent favorites and optional default-microphone selection.
- Configurable low-battery notifications at 10%, 20%, or 30%, with optional sound. Notifications are off by default and require system authorization.
- Independent visibility settings for menu sections and battery time. Expanded content scrolls when necessary.
- Original DuoBar battery ring, volume controls and color coding retained.

## Experimental DMG

[Download T-DuoBar 1.11.1](https://github.com/squazaryu/T-DuoBar/releases/download/v1.11.1/T-DuoBar-1.11.1.dmg) · [Release notes and SHA-256](https://github.com/squazaryu/T-DuoBar/releases/tag/v1.11.1)

**The DMG is an experimental ad-hoc signed build, not Developer ID signed or Apple notarized.** Quit DuoBar, back up the installed copy, mount the DMG, and drag `DuoBar.app` to Applications. Launch it from Applications. macOS may block a downloaded copy; use [Apple's documented individual-app procedure](https://support.apple.com/en-us/102445) only if you trust the release. Do not disable system protections globally.

## Build and install

Requires macOS 13 or newer and full Xcode. This version has been built and tested on Apple Silicon; compatibility with every supported macOS version and accessory has not been physically verified.

```sh
git clone https://github.com/squazaryu/T-DuoBar.git
cd T-DuoBar
./script/build_and_run.sh --verify
```

The script builds Release, verifies the local signature, installs `/Applications/DuoBar.app`, and checks that the process runs from that location. It moves any previous installed copy intact to `~/Library/Application Support/T-DuoBar/Backups/`.

**This fork does not yet provide a Developer ID signed and notarized download.** The experimental DMG and local builds use ad-hoc signing. The display name is T-DuoBar; the `DuoBar.app` filename and original bundle identifier are retained. It shares preferences and replaces the installed DuoBar copy; the fork and original are not intended to run simultaneously. See [DEVELOPMENT.md](DEVELOPMENT.md) for test and debugging commands.

## Validation and limitations

The 1.11.0 implementation passed 352 tests; six hardware-dependent checks were skipped. Release compiled for both architectures; runtime checks ran on Apple Silicon. Native integration tests exercise the real menu controller, glass surface, background opacity, observer cleanup and repeated clicks. See the [performance and lifecycle report](release/1.11.0/VALIDATION.md) for short desktop measurements and their limits. These checks do not establish compatibility with every device, leak freedom or long-duration energy use.

- VPN status covers configured connections reported by macOS; a tunnel interface alone is not proof of a VPN, and the app does not claim all traffic uses it. No VPN connection is started or stopped.
- Battery duration is the estimate supplied by macOS and may be unavailable.
- Accessory support and individual earbud/case readings depend on the macOS Bluetooth report. Reads occur locally while the accessory section is shown.
- A reliable public source for the charge limit has not been identified, so it remains **Unavailable**. The app does not infer a limit from an 80% reading or a paused charge.
- Adapter wattage is the reported adapter rating, not a measurement of charging power.
- Wi-Fi details can be withheld by macOS permissions. Device-managed volume may not be adjustable.
- Hotspot detection is a presentation heuristic based on macOS's expensive-path flag, not a device identification. A phone that is not marked expensive keeps the Wi-Fi symbol; other metered Wi-Fi networks may use the chain. No SSID-name guessing or nearby-network scan is used.
- Low-battery notifications fire on a threshold crossing, not simply on startup below the threshold.

System-status processing is local. The updater makes an HTTPS request to this project’s Homebrew version manifest; it does not upload system-status data. There is no backend, tracking, or system-status upload. Selecting a microphone changes the default Core Audio input; the app does not record audio.

## Upstream and license

Based on upstream `main` at `83522010048124876c2e54c8232ad31d1920577c`. Historical marketing files and release notes retained in this repository describe the original project, not a signed release of this fork.

DuoBar was created by Mike Li / Mikeli7666. Original copyright and the [MIT license](LICENSE) are preserved. T-DuoBar is an independent community fork and is not affiliated with Apple.
