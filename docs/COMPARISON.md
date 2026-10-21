# How T-DuoBar differs

Compared on 21 October 2026 using the projects' public READMEs. This is a comparison of documented focus, not an exhaustive audit of every fork or a claim of exclusive features.

| Project | Documented focus | What to consider |
| --- | --- | --- |
| [Original DuoBar](https://github.com/Mikeli7666/DuoBar#readme) | A compact Battery / Network / Volume indicator, MacBook battery ring and desktop adaptive ring, audio-device transitions and native controls. | The upstream project and original design. Its distribution and signing are separate from this community build. |
| [hummusaki/DuoBar](https://github.com/hummusaki/DuoBar#readme) | Bluetooth-oriented lower dots: radio state, device count, pinned devices or an accessory battery; classic/split-ring styles and a threshold for battery percentages. | A useful alternative when the four dots should describe Bluetooth devices. |
| [T-DuoBar](https://github.com/squazaryu/T-DuoBar#readme) | Lower dots retain output volume. Adds battery time estimates, accessory batteries, expanded network/audio controls, a separate macOS-reported VPN card, reorderable sections, optional Liquid Glass, six languages and Homebrew installation/update checks. Optional battery digits use a size-aware ring cutout and native pixel-aligned text. | A broader control pop-up with configurable appearance and an explicit Homebrew update flow. |

Battery percentages and accessory readings also exist in other forks. T-DuoBar's distinction is the combination of its control pop-up, volume-dot behavior, interface refinements and release/update workflow.

## Boundaries

- T-DuoBar is an independent MIT-licensed community fork, based on DuoBar by Mike Li (Mikeli7666).
- Its builds are currently experimental, ad-hoc signed, and not Apple notarized. Homebrew checksum verification does not change that signing status.
- VPN data describes configured connections reported by macOS; it does not establish the route taken by every application or provide a public-IP leak test.
- Hardware data depends on macOS and device support. There are no universal accessory-compatibility or long-duration energy-efficiency claims.
- Recheck the linked projects before relying on this comparison for a later version.
