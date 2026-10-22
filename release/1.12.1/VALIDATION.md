# T-DuoBar 1.12.1 (38): validation

Checked on 22 October 2026, Apple Silicon, macOS 27.2. The maintainer accepted the local icon alignment before authorizing this release.

## Automated checks

97 focused tests passed, 0 failures, 0 skips and no test runtime warnings:

- CenterGlyphAlignmentTests: visible bounds of 19 network/audio/performance states at 80%, 100% and 105%; pixel-identical percentage positioning against the prior layout; light/dark galleries at enlarged and actual menu bar sizes.
- MenuBarBatteryPercentageTests, DuoGlyphStateTests, BatteryRingPresentationTests, MenuBarIconSizeTests and PersonalHotspotTests.
- AppIdentityTests and HomebrewUpdateTests.
- ChargingAnimationRenderTests and AudioConnectionTransitionRenderTests/testRenderAudioConnectionTransitionStoryboard.

The new Ethernet mark follows the monochrome reference attached to issue #4. Both appearances were inspected. These are native component renders with demo data, not screenshots proving physical network/audio connectivity.

Shell syntax, Python syntax and whitespace checks are part of release preparation. Packaging builds Universal 2 and checks strict ad-hoc signatures, version/build fields, both architectures and the DMG checksum. Exact artifact hashes and release/download/Homebrew verification are retained locally in ignored build/release-1.12.1.

## Boundaries

This is targeted regression validation, not a complete full-suite run or a new energy audit. Intel and older macOS versions are compile targets, not physical test devices here. Builds remain experimental and ad-hoc signed, without Developer ID signing or Apple notarization. No settings migrations are required.

## Reproduction

Use the DuoBar Xcode scheme on macOS with full Xcode selected, ad-hoc signing and a temporary DerivedData directory. Select the test classes and single audio render test listed above. Native alignment galleries are written into the temporary T-DuoBar-CenterAlignment folder. Run script/package_dmg.sh for the Universal 2 DMG.
