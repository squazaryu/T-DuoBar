# T-DuoBar 1.12.2 — balanced icons and reliable offline state

Build 39 · Universal 2 (Apple Silicon and Intel) · macOS 13+.
Experimental ad-hoc signed community build; not Developer ID signed or Apple notarized.

## Fixes / Исправления

- Align the visible ink of network, audio and performance symbols in both ring layouts. Wi-Fi sits lower, while the offline globe sits higher and is more compact. Battery digits, the ring and volume dots retain their anchors.
- Stop treating a remaining VPN tunnel (utun/tun/tap/ipsec) alone as an active network connection. With no usable underlying interface, the status becomes Offline instead of Other. Routed Ethernet and Wi-Fi keep priority; legitimate other interface types remain supported.
- Remove the battery tooltip on menu bar hover and the subscription that maintained it. Battery details remain in the pop-up, and the status view retains its VoiceOver summary.

Значки выровнены по видимому рисунку в обоих режимах кольца. Исправлен ложный Other при оставшемся VPN-туннеле без обычного подключения. Подсказка батареи при наведении удалена.

![Before and after: native component renders with demo values](https://raw.githubusercontent.com/squazaryu/T-DuoBar/v1.12.2/release/1.12.2/icon-alignment.png)

No breaking changes or settings migrations. No new timers, reachability probes or background workers. Network status still describes the macOS path; it does not guarantee that Internet requests will succeed.
Несовместимых изменений и миграций настроек нет. Новых таймеров и проверочных сетевых запросов нет. Состояние сети не является гарантией доступа в Интернет.

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

106 focused tests passed, with no failures, skips or runtime warnings. They cover center states, backing-pixel placement, ring/dot clearance, battery typography, hover behavior, SSID access, synthetic VPN-only/Wi-Fi-removal paths and Homebrew update behavior. [Validation details](https://github.com/squazaryu/T-DuoBar/blob/v1.12.2/release/1.12.2/VALIDATION.md).

Wi-Fi removal was verified on synthetic path snapshots; the live network was not disconnected. Intel is compiled; runtime checks are on Apple Silicon. No full-suite pass or new long-duration energy audit is claimed. Homebrew verifies the DMG SHA-256 but does not add notarization. Downloaded apps may require [Apple's individual-app approval procedure](https://support.apple.com/en-us/102445).
