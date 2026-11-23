# T-DuoBar 1.15.0 (42) validation

## Runtime and appearance

The regression suite finished on Apple Silicon running macOS 27.3 with 447 passes, zero failures and one skipped AirPods capture. The separate hardware integration suite was excluded. Native windows exercised disclosure clicks, visibility under both pop-up materials and simulated display sleep and wake. The appearance checks covered Standard and Compact layouts, the two color schemes and all three desktop sizes with demo readings. Localization tests cover six languages.

A controlled transfer on the local loopback interface exercised the production traffic reader. Tests cover rebasing after interface changes, counter resets, sleep gaps and cancellation. A live internal-battery probe on Apple Silicon matched the macOS cycle count. The estimated capacity differed from the value reported by macOS, as noted in the interface.

The hosted AppKit test checked the desktop panel's enable, resize and disable lifecycle, preservation of the key window and reuse of the existing status monitoring. Display disconnect and reconnect were exercised with simulated screen geometry.

## Distribution

The DMG contains a Universal 2 app targeting macOS 13. The mounted bundle's version, build, minimum system version, both architecture slices and strict ad-hoc signature were checked. The distribution uses the same bundle identifier and Homebrew cask as previous releases.

Runtime checks used Apple Silicon. Intel and macOS 13 are build targets. Physical display sleep, dragging between physical monitors, login after a restart and long-duration power use remain unverified.
