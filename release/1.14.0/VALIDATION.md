# T-DuoBar 1.14.0 (41): validation

Checked on 31 October 2026, Apple Silicon/macOS 27.2. Publication was authorized subject to visual inspection.

## Visual checks

The native production-view matrix exercised 192 combinations: Standard/Compact, light/dark, 304/360 pt, regular/readable text, English/Russian/German/Simplified Chinese, and collapsed menu/expanded Battery/expanded Network. Real header clicks open the panels inside offscreen test windows; demo history includes charging and sleep gaps, and diagnostics use a fake provider. Representative captures were inspected at native resolution across all four languages and both layouts/themes. Existing localization checks cover all six translations.

The pass found/fixed English AM/PM labels in Russian charts and a repeated power-source sentence. Charge-axis units are explicit. Narrow Compact battery rows now fall back to an intact percentage rather than ellipsizing a numeric duration. Full estimates remain available on expansion and in accessibility text. Native captures verify microphone/audio row alignment, visible controls and wrapped explanatory text. Wide and readable modes remain independent.

## Regression and packaging

430 regression tests passed, 0 failed, 1 opt-in hardware test skipped. The five HardwareIntegrationTests were explicitly excluded. The visual matrix ran separately (the full-matrix test plus existing component checks passed); it was not duplicated in the 430-test count. All tests use fake network joins; real Wi-Fi association was not performed.

Coverage includes independent defaults/live width/accordion behavior, history sampling/retention/reload/continuity, request coalescing/cancellation and popup closure, startup isolation, Bluetooth responsiveness, disclosure motion and prior glyph/update behavior. One existing diagnostic remains in the test-only legacy MP4 exporter; XCTest deployment/linking warnings are unchanged.

Universal 2 packaging verifies version 1.14.0/build 41, arm64/x86_64, strict ad-hoc code signatures, DMG integrity and SHA-256. Publication/download/cask/manifest/install verification is retained under ignored build/release-1.14.0. User settings and recent local history are preserved through the update.

## Limits

Battery consumption needs a fresh, continuous unplugged hour; charging, long gaps or insufficient data suppress the hourly figure. Data before installation is not fabricated. Diagnostics establish only the documented Apple endpoint along the current route, not all Internet traffic or VPN protection. No periodic diagnostic requests or new battery polling timer were added.

Actual next-login/reboot acceptance and long-duration energy measurements remain unverified. Intel/macOS 13 are compile targets only; runtime validation is on Apple Silicon/macOS 27.2. Distribution remains experimental, ad-hoc signed and without Developer ID or Apple notarization. No breaking change or preference migration.
