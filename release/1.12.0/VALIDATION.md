# T-DuoBar 1.12.0 (37): validation

Checked on 21 October 2026, Apple Silicon, macOS 27.2. The user accepted build 37 after checking the local icon and explicitly requested replacing the same 1.12.0 release rather than publishing 1.12.1.

## Automated checks

91 focused tests passed, 0 failures, 0 skips:

- MenuBarBatteryPercentageTests: valid/missing readings; adaptive ring exclusion; every reading from 0 to 100 with and without a bolt; label/ring pixel clearance; circular bottom-dot geometry; center size/position preserved across percentage, color and power states; backing-pixel typography alignment; native text raster preservation at 80%, 100% and 105%; native render fixtures at 1× and 2×.
- BatteryRingPresentationTests, MenuBarIconSizeTests and DuoGlyphStateTests.
- LocalizationTests and ConvenienceSettingsTests, including all six app languages and the new setting/hint.
- ChargingAnimationRenderTests, including network, hotspot, Ethernet and audio center states.

A separate RepositoryArtworkTests render check passed. It renders the real application views with explicit demo data and restores the original language preference. App icon, hero, light/dark menu and settings assets were inspected. The repository artwork is documentation, not a real user's desktop capture or a simulation of the Liquid Glass material.

Localization syntax, shell syntax and whitespace checks passed. Release packaging builds Universal 2, verifies strict code signatures, version/build fields, both architectures and the DMG checksum. The mounted/copied app is smoke-tested on Apple Silicon before publication; exact hashes and remote/download verification are retained in ignored build/release-1.12.0.

## Boundaries

This is a focused regression run for the changed glyph/settings/resources. No complete full-suite success is claimed. An earlier full-suite attempt for 1.11.1 stalled in Bluetooth initialization; this release does not claim a fix for that system/API wait. There are no new multi-hour energy, battery-drain or hardware-compatibility measurements. Historical 1.11.0 measurements are not new measurements for 1.12.0.

Intel and older macOS versions are compile targets, not physical test devices here. Text readability still depends on the display and selected size; 100–105% is recommended. Builds remain experimental, ad-hoc signed, without Developer ID signing or Apple notarization.

## Reproduction

Use the DuoBar Xcode scheme on macOS with full Xcode selected, ad-hoc signing and a temporary DerivedData directory. Select the seven test classes listed above. Add RepositoryArtworkTests/testRenderRepositoryArtwork to render replacement images in the temporary directory; inspect and copy them into assets/. Run script/package_dmg.sh for the Universal 2 DMG.

Build 37 also checks visible digit centering (including 89 and 90), independently from advance widths. The former build 36 files, release metadata and tag identity were saved locally before the authorized replacement.
