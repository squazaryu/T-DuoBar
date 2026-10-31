<p align="center">
  <img src="assets/app-icon.png" width="96" alt="T-DuoBar app icon">
</p>
<h1 align="center">T-DuoBar</h1>
<p align="center"><strong>Battery, network and audio — one place in your menu bar.</strong></p>
<p align="center">
  <img alt="macOS 13 or later" src="https://img.shields.io/badge/macOS-13%2B-222222?logo=apple&amp;logoColor=white">
  <img alt="Apple Silicon and Intel" src="https://img.shields.io/badge/Universal_2-Apple_Silicon_%2B_Intel-248A3D">
  <a href="LICENSE"><img alt="MIT license" src="https://img.shields.io/badge/license-MIT-blue"></a>
  <a href="https://github.com/squazaryu/T-DuoBar/releases/tag/v1.14.0"><img alt="Experimental release 1.14.0" src="https://img.shields.io/badge/release-1.14.0_experimental-orange"></a>
</p>
<p align="center"><a href="https://github.com/squazaryu/T-DuoBar/releases/tag/v1.14.0">Download</a> · <a href="README.ru.md">Русский</a> · <a href="docs/COMPARISON.md">Compare forks</a> · <a href="DEVELOPMENT.md">Source &amp; build</a></p>

An independent community fork of [DuoBar by Mike Li (Mikeli7666)](https://github.com/Mikeli7666/DuoBar). Keep battery, network and audio together in one menu bar indicator, with a more capable pop-up when you need the details.

## Why T-DuoBar

- **A readable, configurable glyph.** Choose the circular icon or add battery digits in an adaptive cutout. Both use the same full-size center symbol and circular volume dots. Digits render at native pixel-aligned size; a green power ring omits the redundant bolt.
- **Battery context.** Remaining time or time to full charge when macOS provides an estimate, accessory batteries and optional low-battery alerts.
- **Network and VPN at a glance.** Signal, band, channel, IP copying, Personal Hotspot indication, nearby Wi-Fi discovery and joining, and a separate VPN card with the macOS-reported profile and interface.
- **Useful audio controls.** Output selection, favorites, microphone selection, mute and optional scrolling over the menu bar icon to adjust volume. The four lower dots show output volume.
- **Your pop-up layout.** Reorder or hide sections; choose Classic or native Liquid Glass, adjust background transparency and preview the actual menu. Glass requires macOS 26+ and respects Reduce Transparency.
- **Six languages.** English, German, Russian, Ukrainian, Simplified Chinese and Traditional Chinese, with a system-language option.
- **Homebrew updates.** Weekly checks while the app is running, a clear installed/available version display and an explicit installation action.

## Two menu layouts

**Available since 1.13.0.** Choose familiar cards or a compact list; both retain the same sections and actions.

Choose **Standard** for separate cards and immediately accessible volume controls, or **Compact** for a single group of summary rows. Click a compact row to reveal its controls, devices and system-settings link. Both layouts share your section order, visibility and favorites.

| Standard · light | Compact · light |
| --- | --- |
| <img src="assets/layouts/standard-light.png" width="304" alt="Standard layout with separate cards in light appearance"> | <img src="assets/layouts/compact-light.png" width="304" alt="Compact layout with summary rows in light appearance"> |

| Standard · dark | Compact · dark |
| --- | --- |
| <img src="assets/layouts/standard-dark.png" width="304" alt="Standard layout in dark appearance"> | <img src="assets/layouts/compact-dark.png" width="304" alt="Compact layout in dark appearance"> |

Choose in **Settings → General → Appearance → Menu layout**. Standard remains the default. Layout is independent of the Classic / Liquid Glass background and transparency; you can combine either layout with either material.

<details>
<summary>Layout selection in Settings</summary>

| Light appearance | Dark appearance |
| --- | --- |
| <img src="assets/layouts/settings-light.png" width="440" alt="General settings showing the Menu layout picker set to Compact"> | <img src="assets/layouts/settings-dark.png" width="440" alt="General settings in dark appearance with the independent layout and background choices"> |

</details>

<details>
<summary>Published 1.12.2 interface</summary>

![T-DuoBar 1.12.2: menu bar glyphs and the control pop-up](assets/t-duobar-hero.png)

| Light appearance | Dark appearance |
| --- | --- |
| <img src="assets/popup-light.png" width="304" alt="Published T-DuoBar 1.12.2 light pop-up"> | <img src="assets/popup-dark.png" width="304" alt="Published T-DuoBar 1.12.2 dark pop-up"> |

<img src="assets/settings-general.png" width="560" alt="Published 1.12.2 General settings, before the layout picker">

</details>

*Native application-view renders with demonstration values, not personal desktop or connection data. Menu images use the Classic background; they do not simulate Liquid Glass. The new interface images show version 1.13.0.*

## Optional menu tools and battery history

**Settings → General → Menu options** adds five independent opt-ins: a wider popup (360 instead of 304 pt), row highlighting, larger/higher-contrast text, one expanded section at a time and network diagnostics. **All five are off by default.** Layout and Classic / Liquid Glass material remain independent.

Battery history is always available inside expanded Battery, without a toggle: a six-hour graph and consumption over a continuous unplugged hour. Readings stay local for up to 24 hours, using existing callbacks instead of a new polling timer. Charging sessions and gaps are separated; data before installation is not backfilled.

| Battery history | Wider, readable menu |
| --- | --- |
| <img src="assets/menu-tools/history-light.png" width="304" alt="Expanded Battery showing local history and hourly consumption"> | <img src="assets/menu-tools/readable-light.png" width="360" alt="Wide Compact menu with larger text and microphone enabled"> |

<details>
<summary>Dark appearance and the new settings</summary>

| Battery history · dark | Readable menu · dark |
| --- | --- |
| <img src="assets/menu-tools/history-dark.png" width="304" alt="Local battery history in dark appearance"> | <img src="assets/menu-tools/readable-dark.png" width="360" alt="Wide readable menu in dark appearance"> |

<img src="assets/menu-tools/overview-light.png" width="1000" alt="Native light renders: menu, history and all five opt-in controls">
<img src="assets/menu-tools/overview-dark.png" width="1000" alt="The same menu options and history in dark appearance">

</details>

*Native demo readings; options are enabled for illustration. If the narrow menu cannot fit a battery estimate, it keeps the percentage readable; expand Battery for the full estimate.*

After enabling diagnostics, Network offers **Check connection**. It checks HTTPS reachability of www.apple.com, distinguishes DNS failures and does not follow redirects. This does not test every application or VPN protection. There are no background checks.

## Install and update

[Download the 1.14.0 DMG](https://github.com/squazaryu/T-DuoBar/releases/download/v1.14.0/T-DuoBar-1.14.0.dmg?build=41) · [Release notes and SHA-256](https://github.com/squazaryu/T-DuoBar/releases/tag/v1.14.0)

```sh
brew install --cask squazaryu/tap/t-duobar
```

For an existing Homebrew installation, quit DuoBar, then run:

```sh
brew update
brew upgrade --cask squazaryu/tap/t-duobar
open /Applications/DuoBar.app
```

Settings → Updates can check manually or weekly and open Terminal to install through Homebrew, then restart the app. Checks run only while DuoBar is open; failed checks retry after six hours. Installation starts only after an explicit click. Homebrew is not installed automatically, and unrelated packages are not upgraded by the in-app install action.

If adopting a manually installed app, quit it and back up `/Applications/DuoBar.app` first. `--adopt` requires an identical copy; do not use `--force` to discard the existing app. Existing DuoBar preferences are shared and retained. The original app and this fork should not run simultaneously.

**Distribution status:** this is an experimental ad-hoc signed community build, without Developer ID signing or Apple notarization. Homebrew verifies SHA-256 but does not add notarization. An Internet-downloaded app may need [Apple's individual-app approval procedure](https://support.apple.com/en-us/102445). Do not disable system protections globally.

## What makes this fork different?

T-DuoBar keeps the four dots dedicated to **volume**, and builds out the battery/network/audio pop-up, VPN visibility, appearance settings, localization and Homebrew update flow. For example, [hummusaki/DuoBar](https://github.com/hummusaki/DuoBar#readme) focuses on configurable Bluetooth dots and classic/split-ring styles. Percentages and accessory readings also appear in other forks; we do not claim them as exclusive features.

See the [documented comparison with upstream and another fork](docs/COMPARISON.md), checked on 21 October 2026.

## New in 1.14.0 · build 41

Five optional menu tools and local battery history. Chart time labels follow the app language and its axis shows charge percentages. Duplicate power-source text is removed; narrow Compact rows keep numeric battery readings legible. New opt-ins are not enabled automatically and existing preferences are retained.

[Release notes](release/1.14.0/RELEASE_NOTES_1.14.0.md) · [Validation and limits](release/1.14.0/VALIDATION.md)

## Privacy and practical limits

System readings are processed locally. There is no analytics backend or upload of battery, network or device readings. The updater makes an HTTPS request to the version manifest in our Homebrew tap. Selecting a microphone changes the Core Audio input device; it does not record audio. Battery history stays local. Optional diagnostics request www.apple.com only after an explicit button press.

VPN status includes only configured connections reported by macOS. It does not prove that all traffic is protected. A tunnel interface alone is not treated as proof of a VPN connection. Device battery data and time estimates depend on macOS/device support; missing readings remain explicit. Joining Wi-Fi starts only after explicit selection of a network; password-protected networks also require the Join button. Passwords are passed in memory to CoreWLAN and are never saved or logged. Enterprise and unsupported networks open macOS Wi-Fi Settings. T-DuoBar does not pair Bluetooth devices, and the charge-limit readout is unavailable.

See [VALIDATION.md](release/1.14.0/VALIDATION.md) for release checks. Joining another real Wi-Fi network and login after a reboot remain unverified. Intel is compiled; runtime validation is on Apple Silicon. New long-duration energy measurements are not claimed.

## Build, source and credits

[Development and local installation](DEVELOPMENT.md) · [MIT license](LICENSE) · [Original DuoBar](https://github.com/Mikeli7666/DuoBar)

Thanks to Mike Li for DuoBar and to [CTeipen](https://github.com/CTeipen) for the German translation. Historical upstream marketing material is retained separately; the images above are T-DuoBar-specific native renders.
