# T-DuoBar 1.12.2 (39): validation

Checked on 23 October 2026, Apple Silicon, macOS 27.2. Publication was authorized after the local icon comparison and tunnel-only path correction were presented.

## Automated checks

106 focused tests passed, 0 failures, 0 skips and no test runtime warnings:

- DuoCenterOpticalAlignmentTests: 14 representative network/audio/performance states, both percentage layouts, 80%/100%/105% sizes and 1x/2x backing; alpha-weighted ink centers compared in backing pixels, with a 1.1-pixel native-hinting tolerance. Light/dark galleries include magnified and actual menu bar sizes.
- CenterGlyphAlignmentTests: 19 states, including Wi-Fi signal variants; safe clearance inside the ring; battery label/ring/dot positions independent of the selected center symbol.
- NetworkPathResolutionTests: satisfied VPN-only paths, Wi-Fi removal/return while the tunnel remains, routed Ethernet priority, unused/loopback interfaces, and valid bridge/cellular/other connections.
- MenuBarBatteryPercentageTests, MenuBarIconSizeTests, DuoGlyphStateTests, PersonalHotspotTests and SSIDAccessTests.
- StatusTooltipTests, HoverPopoverInteractionTests and ChargingAnimationRenderTests.
- HomebrewUpdateTests and AppIdentityTests.

Native fixtures were inspected in both appearances. The comparison image uses native component renders and demo values, not a user's desktop screenshot. A read-only NWPath snapshot during development showed both the Wi-Fi interface and the VPN tunnel; live Wi-Fi was not disabled.

Shell/Python syntax and whitespace checks are included in release preparation. Packaging checks Universal 2 architectures, version/build fields, strict ad-hoc signatures and the DMG checksum. Exact hashes and download/Homebrew verification are kept locally in ignored build/release-1.12.2.

## Boundaries

This is targeted regression validation, not a full-suite or energy-audit result. An earlier real-click test waited in the system Bluetooth API; that run was stopped and is not counted as successful. This release does not claim to fix that wait. Physical Wi-Fi removal/reconnection with VPN remains unverified; path transitions are tested synthetically. Network-path availability is not an active Internet reachability test.

Intel and older macOS versions are compile targets only. Builds remain experimental and ad-hoc signed, without Developer ID signing or Apple notarization. Existing preferences require no migration.

## Reproduction

Use the DuoBar Xcode scheme with full Xcode, ad-hoc signing and temporary DerivedData. Select the 13 test classes listed above. Render fixtures are written into the temporary T-DuoBar-OpticalAlignment and T-DuoBar-CenterAlignment folders. Run script/package_dmg.sh for the Universal 2 DMG.
