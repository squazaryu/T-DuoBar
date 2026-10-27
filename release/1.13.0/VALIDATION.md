# T-DuoBar 1.13.0 (40): validation

Checked on 27 October 2026, Apple Silicon, macOS 27.2. Publication includes the previously accepted compact-menu, network and battery improvements plus launch and disclosure fixes.

## Automated checks

The regression run passed **422 tests**, with **0 failures** and **1 skip**. The five `HardwareIntegrationTests` were explicitly excluded: they include real output/volume changes. The additional skipped test requires a real AirPods endpoint and the hardware opt-in. This is the full scheme with those hardware exclusions, not a claim of complete hardware acceptance.

Coverage includes battery-source mapping, 80–120% fitted glyphs at 1x/2x, menu layouts and last-row geometry, disclosure intermediate heights/rapid toggles/motion preferences, fake Wi-Fi scan/join and lifecycle, VPN monitoring, actual status-item close/reopen paths, Homebrew checks and bundle identity. A formerly synchronous expanded-section fixture now waits for SwiftUI's measured layout before asserting its full height.

One runtime diagnostic remains in the legacy MP4 export fixture `AudioConnectionTransitionRenderTests/testRecordWiFiAirPodsWiFiTransition`: it calls a synchronous media-writing method on the main thread. This is test-only video-generation code, not the app's Bluetooth or menu startup path. Existing XCTest linking warnings for the macOS 13 test deployment target remain.

## Startup evidence

At the previous reboot, the macOS login-item record referenced the temporary DerivedData Debug app. Test hosts and uninstalled copies now avoid all `SMAppService.mainApp` access, including status reads. Fake backends cover approval, disablement, recovery errors and ordered asynchronous unregister/register. A post-install render check left the installed registration URL unchanged. Approved installed updates refresh registration once; user-disabled and pending entries are not enabled automatically.

A live sample also captured the app's main thread waiting inside `IOBluetoothHostController.default()` before menu creation. Bluetooth reads now run on a serial utility queue, with bounded/coalesced refreshes. Subsequent live sampling showed the normal NSApplication event loop. The development installer now waits for a fresh menu-ready marker rather than only checking that a process exists.

## Packaging and boundaries

Universal 2 packaging checks arm64/x86_64, version/build metadata, strict ad-hoc signatures, DMG integrity and SHA-256. Download, mounted-app and Homebrew verification evidence is retained locally under ignored build/release-1.13.0.

No breaking changes or preference migrations. Standard remains the default; existing material/transparency and section preferences are retained. Native light/dark renders use demo data.

Real association to another Wi-Fi network, startup after the next actual login/reboot and long-duration energy profiling remain unverified. Intel and macOS 13 are compile targets; runtime checks are on Apple Silicon/macOS 27.2. The build remains experimental, ad-hoc signed and without Apple notarization or Developer ID signing.
