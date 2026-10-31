# Local development

This checkout is based on `Mikeli7666/DuoBar` main at `8352201`.

Run `./script/build_and_run.sh --verify` from this directory, or use the Codex
Run button. Requires full Xcode at `/Applications/Xcode.app`; set
`DEVELOPER_DIR` if Xcode is installed elsewhere.

The script builds a local Release version (1.11.0, build 29) with an ad-hoc
signature, verifies it, stops existing DuoBar instances, and installs it in
`/Applications/DuoBar.app`. The previous installed app is moved intact to
`~/Library/Application Support/T-DuoBar/Backups/` before replacement. Launch
verification checks that the running process is actually from `/Applications`.
The local build is not a Developer ID signed or notarized public release.

`--debug` launches the temporary Debug build under LLDB instead of installing.

## Battery time

The Battery section in the popover shows estimated time until empty when
running on battery, or time until full charge while charging. The menu-bar
icon remains unchanged. Estimates come from macOS IOKit and refresh on power
notifications and every 60 seconds.

Unavailable estimates and connected-but-not-charging states have explicit
messages. Fully charged and unavailable batteries do not show a time estimate.

Focused checks:

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild \
  -project DuoBar.xcodeproj -scheme DuoBar -configuration Debug \
  -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath "$TMPDIR/T-DuoBar-DerivedData" \
  CODE_SIGN_IDENTITY=- CODE_SIGN_STYLE=Manual DEVELOPMENT_TEAM= \
  -only-testing:DuoBarTests/BatteryTimeTests \
  -only-testing:DuoBarTests/SystemStatusModelTests \
  -only-testing:DuoBarTests/LocalizationTests test
```

Use `arch=x86_64` on an Intel Mac. Charging/discharging estimates need a manual
check with a real battery and charger; automated cases use simulated states.

## Local 1.5.0 features

- Expand Network for signal, band, channel, IPv4 address, clipboard copy and Wi-Fi power.
- Expand Battery for adapter wattage and power state; keep the battery time estimate optional.
- Connected accessory batteries from Apple's local Bluetooth report. Polls while the popover section is visible; disconnected cached readings are excluded. Device support and separate AirPods/case readings depend on what macOS reports.
- Expand Audio Output to select a device or star favorite outputs. Favorites use persistent device UIDs.
- Enable Microphone in Settings → Menu sections to select the default input device. This changes Core Audio routing; DuoBar does not record microphone audio.
- Settings → Notifications enables one low-battery alert on crossing 10%, 20% or 30%. Defaults off; authorization is requested when enabling it. Initial startup below a threshold does not issue an alert. Charging or recovery above the threshold plus 5% rearms the alert.
- Menu sections can be hidden independently. Expanded content scrolls when it reaches the screen-height cap.

Charge-limit readout remains Unavailable: a reliable public source has not been identified. No limit is inferred from a paused charge or an 80% reading. Adapter wattage is the reported adapter rating, not a measurement of current charging power.

The full test suite includes hardware-dependent tests that skip when devices or explicit hardware validation flags are absent. Physical accessory and microphone selection checks still require the corresponding devices.

## Experimental DMG packaging

Run `./script/package_dmg.sh`. It builds both arm64 and x86_64, verifies the app signature and version, creates a read-only compressed DMG, verifies the image, and writes SHA256SUMS under `build/releases/1.11.0/`. Existing output is preserved; move it aside before another packaging run.

The image includes DuoBar.app, an Applications shortcut, the MIT license, and bilingual installation notes. It does not install anything or replace the currently running app. Packaging uses an ad-hoc signature, not Developer ID or notarization. GitHub publication is a separate step.

## Homebrew publishing and weekly checks

After publishing and verifying a DMG release, prepare the tap with:

```sh
./script/publish_homebrew.py 1.11.0 29 --tap-dir /path/to/homebrew-tap
```

The helper uses GitHub's uploaded-asset SHA-256 and fixed repository/asset URLs. Review, commit and push the cask and manifest together. The app reads https://raw.githubusercontent.com/squazaryu/homebrew-tap/main/updates/t-duobar.json; it checks only versions available in the tap, including our experimental releases.

A check runs at startup, on wake and from an hourly due-date timer, but makes no network request unless seven days have elapsed since a successful check. Network failures have a six-hour backoff. Check timestamps, cached version and last-notified version persist across restarts. Notifications require macOS permission. The manifest supplies only validated version/build data, never a command or script to execute.

The bundled UpdateWithHomebrew.command runs fixed Homebrew commands in Terminal after an explicit installation click. It preserves a manually installed app before adopting Homebrew management, retains preferences, and reopens DuoBar. No other casks are upgraded. App-managed installation of arbitrary downloaded binaries is not implemented.

## Local 1.6.2 stability changes

Accessory polling is owned by the actual NSPopover show/close events and its visibility preference. Rendering a retained or offscreen SwiftUI view does not start system_profiler. Closing the popover cancels both the waiting task and its detached worker; late results cannot overwrite a reopened menu. Only completed reports enter the short-lived cache. The owned helper is terminated and reaped on cancellation or timeout, with a bounded grace period before a forced termination if needed.

Background battery, network, accessory and update timers have tolerances for system timer coalescing. Event-driven updates remain immediate. AccessoryPollingLifecycleTests covers cancellation, reopening, caching, hidden-view rendering, preference changes, helper cancellation and a helper that ignores termination. Local diagnostic captures live under the ignored build/stability-audit directory. The current published release remains separate from this local development build.

## Local 1.7.0 identity

T-DuoBar has its own reproducible AppIcon and a standard native macOS About panel. Open it from Settings → General → About T-DuoBar, the popover title, the application menu, or by reopening the running app from Finder. It reads version/build directly from the installed bundle and credits the upstream author with links to both projects and the MIT license. It creates no background service. The menu-bar status glyph retains its existing behavior.

Regenerate the icon's ten macOS asset sizes from the vector drawing code with:

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift script/render_app_icon.swift
```

The display name is T-DuoBar. The installed path remains `/Applications/DuoBar.app` and the bundle identifier remains `com.mikeli.duobar`, preserving Homebrew management and existing preferences.

## Local 1.8.0 compact settings and context menu

Settings now use three native tabs: General, Notifications and Updates. Existing preference keys and values are preserved. About and version/build remain in the shared footer. General groups appearance, visible sections, battery and behavior; developer-only diagnostics are collapsed and constructed only when expanded. Update commands remain available under a disclosure group.

Right-click or Control-click the status item to open the native Settings / Check for updates / Quit menu. Left-click retains the status popover. Context-menu tracking temporarily suppresses hover popovers, closes an already open popover, and restores normal hover behavior after dismissal. Settings routing uses the actual localized SwiftUI command in the app menu rather than a hard-coded private selector.

## Local 1.9.0 menu customization and connection status

General → Menu sections supports dragging the handles to reorder the six sections. Right-click a row for Move up / Move down, or use the equivalent accessibility actions. Reset order restores the default sequence without changing visibility. The order uses stable IDs in `menu.sectionOrder`; unknown IDs and duplicates are ignored, and newly introduced or missing sections are appended. Existing preferences require no migration.

The status item has no hover tooltip. Battery details remain in the pop-up and the status view retains its VoiceOver summary. Network, battery, volume, audio-device and accessory sections have labeled links to their System Settings panes. If a pane URL cannot be opened, the opener falls back to System Settings itself. Wi-Fi privacy explanations use the actual Core Location authorization state; unavailable estimates and accessory readings are described without fabricating data or permission failures.

Network classification requires a usable, non-loopback, non-tunnel interface in the reported path. A remaining utun/tun/tap/ipsec tunnel alone does not count as a network connection; it resolves to Offline, while routed Ethernet and Wi-Fi retain priority. This uses the existing path updates and adds no reachability requests or polling. A satisfied path is not a guarantee of working Internet access.

Connected Wi-Fi marked expensive by the existing `NWPathMonitor` uses the native `personalhotspot` chain symbol in both the menu-bar glyph and the network section. [Apple documents Personal Hotspot as an example of an expensive path](https://developer.apple.com/documentation/network/nwpath/isexpensive). This is a presentation heuristic for system-reported metered Wi-Fi: it does not identify the access point hardware. A phone that is not marked expensive keeps the regular Wi-Fi symbol; another metered Wi-Fi network may use the chain. SSID names, private CoreWLAN properties, nearby-network scans and external requests are not used. Battery/volume presentation and temporary audio-device feedback retain their existing priority.

No global keyboard shortcut is registered. This local build is separate from GitHub and Homebrew publication.

Build 17 also keeps System Settings actions inside each card's shared background, with aligned right padding. Empty accessory state is a compact 48-point row matching the other sections; connected-device levels remain visible and read failures retain explanation/retry controls. Accessory view rendering still does not start polling.

The power bolt now clears the ring's inner edge. While it appears, the center glyph scales and moves slightly down using the same animation progress; unplugging restores its normal geometry and fades the bolt at its existing position. Timing, reduced-motion behavior and color preferences remain unchanged. A bounds regression test first failed on the previous geometry and now passes for all supported icon scales. The charging render gallery includes regular Wi-Fi, hotspot, Ethernet and audio glyphs at native menu-bar size and magnified in both appearances.

Build 18 aligns the root scroll view to the top of its hosting area. During disclosure changes, AppKit and SwiftUI may briefly disagree about the popover height; the default center alignment formerly introduced blank space above the title. A render regression exercises that size mismatch and verifies the title remains in the upper strip.

## Local 1.10.0 convenience settings

Appearance → Language selects System, English, Russian, Ukrainian or either Chinese localization. Custom labels, tooltips, About content and new notification text resolve against the selected bundled localization immediately, without changing macOS language preferences or requiring a restart. The setting persists under `appearance.language`. Language changes rebuild the visible content; disclosure expansion is still view-local and is not saved between app restarts. OS-owned UI may follow the system language.

Menu sections → Hide empty accessory section is off by default. When enabled, empty results are omitted but failures remain visible with recovery actions. The retained popover observes accessory service changes directly, so rows return after the next successful report with connected devices. Polling still follows popover visibility and the existing section visibility preference; hiding empty results adds no scan or timer and does not disable discovery while the menu is open.

Behavior → Adjust volume by scrolling over the icon is off by default. An app-local scroll-wheel monitor is installed only while enabled and accepts events over this status button alone. It is removed when disabled or when the controller is invalidated. Discrete steps change volume by 2%; precise input accumulates before applying a step. Natural-scroll inversion is normalized, inertial events are ignored, and accumulated fractions reset across device/gesture/direction changes. Unsupported outputs are left untouched. The existing Core Audio setter performs the write and refreshes actual state; scrolling up from mute starts at a low level. No global input monitor, Accessibility authorization, feedback sound or polling timer is added.

API references: [NSEvent](https://developer.apple.com/documentation/appkit/nsevent), [scroll inversion](https://developer.apple.com/documentation/appkit/nsevent/isdirectioninvertedfromdevice).

Local builds do not update GitHub or Homebrew. Publish the verified DMG and tap
metadata using the workflow above.

Build 21 groups each volume/battery value beside its title, using a common header
and baseline at the same font size. The volume slider uses the full text column;
no empty disclosure slot is reserved in that row. Actual disclosure indicators
share one fixed-width column. Native popover renders cover both light and dark
appearances.

Build 22 gives each disclosure button a rectangular interaction shape inside its
full-width label. Empty space between text and the chevron now toggles details;
the adjacent System Settings button keeps its independent action. A hosted native
interaction test exercises the battery icon, blank gap, closing and settings.

## Local 1.11.0 VPN information

VPN has a separate, reorderable popover card with status, profile name and optional
interface details. Older saved orders receive VPN beside Network without changing
the relative order of existing sections. Its visibility preference is independent
of Network. Expansion remains view-local.

The read-only source uses configured VPN/IPSec/L2TP services and
[SCNetworkConnectionGetStatus](https://developer.apple.com/documentation/systemconfiguration/scnetworkconnectiongetstatus(_:)).
An interface named utun alone is not treated as proof of VPN connectivity. Failed
reads, unknown states, disconnected profiles and missing profiles are distinct.
The view does not claim that all traffic passes through the VPN.

The controller starts the VPN service only while the real NSPopover is visible
and the VPN section is enabled. Changes arrive through
[SCDynamicStore](https://developer.apple.com/documentation/systemconfiguration/scdynamicstore-gb2)
notifications. Closing/hiding the section cancels observation; generations reject
late results and old callbacks. Reads run off the main actor and bursts coalesce.
There is no VPN polling timer, subprocess, external IP request, connection control,
Network Extension entitlement or extra authorization prompt.

This VPN iteration is local; the published GitHub/Homebrew release is separate.

Build 24 keeps the last known VPN snapshot while reopening triggers revalidation.
It no longer flashes an unavailable/gray icon before receiving a fresh result.
Actual read/observation failures still replace the cached state with unavailable,
and newly observed disconnections replace a previously connected snapshot.

Build 25 rejects cancelled requests before invoking the reader and propagates
cancellation to its detached worker. Repeated stop calls and identical snapshots
do not publish redundant state changes. Three regression tests reproduce these
issues on build-24 source before checking their fixes.

## Local 1.11.0 optional popover appearance (build 27)

General → Appearance → Pop-up appearance selects Classic or Liquid Glass.
Classic is the default and retains NSPopover with a solid content background.
Liquid Glass requires macOS 26 or later and uses a transparent NSPanel containing
one native NSGlassEffectView in its clear style. Build 26 only tinted NSPopover's
existing material, which did not produce a sufficiently distinct glass mode.
The dedicated panel avoids stacking glass over the system popover backdrop.

Both presentations reuse one content controller, including disclosure and scroll
state. Background transparency controls a separate tint layer, leaving the window
and its text/controls at full opacity. At 100%, the native glass material remains.
Preview menu opens the actual status menu from Settings. Style and slider changes
apply without restarting; changing the selected presentation while visible moves
the same content to the new window. Late close callbacks from the old popover
cannot stop observation in a newly opened glass panel.

The glass panel anchors below the status button, fits its screen's visible frame,
and retains its top position when details expand. Escape, loss of key focus and
outside mouse clicks dismiss it. Local/global mouse monitors exist only while
that panel is visible and are removed on close. No global keyboard monitor,
Accessibility permission or new polling timer is introduced. Hardware observation
still starts/stops from actual show/close callbacks, not SwiftUI onAppear.

The selection and slider persist under appearance.popoverStyle and
appearance.popoverTransparency. Invalid styles fall back to Classic; slider
values are clamped and non-finite values use the default 65%. Older macOS and
system Reduce Transparency use the opaque Classic presentation without discarding
the saved selection. Light/dark colors follow the effective appearance.

Native integration tests check the actual selected window/surface, live tint-layer
alpha changes, unchanged content opacity, reuse of the content controller, VPN
observation lifetime, late callbacks, Escape dismissal, event-monitor cleanup and
secondary-screen/expansion geometry. These checks supplement the model and
settings-render tests; desktop/GPU energy use remains a separate measurement.

Build 28 treats a mouse press on the status button as one owned gesture through
its mouse-up action. Focus-loss and external mouse monitors must not close the
glass panel in the middle of that press: resetting the toggle early formerly
reopened it. Left/right owner presses are protected, a cancelled drag dismisses,
and keyboard focus loss and outside clicks still dismiss. Deferred key restoration
for a pinned hover menu is generation-checked and cancelled on close; no timing
threshold or extra polling timer is used.

Build 29 moves the normal status-button toggle to mouse-down. A local mouse-down
monitor checks that exact button/window and consumes normal left presses before
NSWindow/NSButton tracking can transfer focus. The button action mask has no
left-mouse-up action, so a later release cannot reopen an already closed menu.
Control-click passes through to the native context-menu action; right-click and
accessibility/keyboard activation retain their native target/action route. The
monitor is removed on controller invalidation/deinit. This fixes the controller
input path rather than depending on panel focus callbacks to arrive in order.
StatusItemClickTests exercises that controller path, 30 repeated cycles, late
focus/up events, control-click, unrelated events and invalidation.


## Menu bar percentage style (1.12.0, build 37)

Settings → General → Appearance → Battery percentage in menu bar adds digits in a top gap of the battery ring. It is off by default and independent of percentages inside the pop-up. Missing/invalid battery readings and adaptive rings retain the original glyph. The option is hidden on Macs using an adaptive ring.

The gap adapts to the rounded monospaced text width and an optional bolt; font advance is cached. One- and two-digit readings retain more of the circular arc than 100. The center symbol is 5% larger than the original glyph (about 24% larger than the first percentage prototype). The four volume dots follow the outer circle instead of the previous inset row, with a small vertical alignment adjustment to fit the menu bar. Both percentage and non-percentage styles now share this circle, center scale and alignment. External power no longer shrinks or shifts the center symbol.

A green power ring omits the redundant bolt in both styles. With color coding off, a small centered bolt still identifies external power, including paused charging. Without digits, that bolt has its own small top cutout to keep the center unobstructed. Split-ring progress excludes the number gap, so half charge fills one visible side.

The style uses cached battery status only and adds no polling, timer or network work. Pixel-mask tests cover every reading from 0 to 100 with and without a bolt, with clearance from the rounded stroke. Geometry checks cover the dots at 80%, 100% and 105% size. All six app languages include the setting and readability hint. The 80% size remains available, but 100–105% is recommended. Physical display readability still requires user acceptance. The feature is included in release 1.12.0.

Native pixel comparison verifies the same center in both styles across external-power and color-coding states. Light/dark fixtures cover both styles at actual menu bar size and enlarged.

Battery digits are rendered as a native-size overlay after the ring canvas transform. Their font size and origin align to the current backing pixel grid (1x or 2x). Typography supplies the ring cutout using actual final font metrics and leaves space inside the 22-point menu bar viewport. The normal-size menu font is capped at 8.5 points to avoid reaching the Wi-Fi symbol at 105% icon size; enlarged previews use their own native font size. The text is never resized as a cached 32-point-canvas bitmap. Native raster comparison tests cover 80%, 100% and 105% icons with 8, 80 and 100, with and without a bolt.

Build 37 optically centers the visible digit contours using cached Core Text bounds instead of advance widths. Version 1.12.0 assets and its source tag are replaced with explicit maintainer authorization; the prior build 36 artifacts/tag identity are retained locally. Homebrew cask versions include the build number (1.12.0,37), while the app and JSON manifest retain semantic version 1.12.0 and build 37.


## Upstream additions (1.13.0)

The battery mapper now accepts only an internal-battery power-source dictionary. Rounded 100% capacity is not an authoritative full-charge flag; only `kIOPSIsChargedKey` can set it. T-DuoBar keeps adapter wattage, remaining-time fields and the existing fallback timer tolerance.

Network → Nearby Networks provides an inline list based on public CoreWLAN APIs, adapted from upstream DuoBar v1.3.2. Opening the regular pop-up does not scan. Expanding the list scans on a serial worker queue, caches results for 15 seconds and supports explicit refresh. Current SSID/security is listed first; duplicate access points are collapsed deterministically. Enterprise/unsupported security opens Wi-Fi Settings. Passwords are only passed in memory to CoreWLAN, never saved or logged. Empty, oversized or NUL-containing passwords are rejected before association. Location access is requested only when opening/refreshing the list.

Closing either Classic or Liquid Glass menus invalidates pending UI results. At most one request is in flight and repeated reopen/refresh requests coalesce into one follow-up. A synchronous CoreWLAN call already in progress cannot be forcibly cancelled; its late result is ignored. Association starts only after an explicit user selection/Join action. Tests use fake providers and do not switch the live network.

Requested icon size now ranges from 80% to 120%. Whole-circle geometry is uniformly fitted into the 22-point status-item viewport with a half-point margin; it is never made elliptical. macOS's height limit can cap visible growth before 120%, and Settings explains this. Native-size percentage rendering remains in use. Tests check actual 1x/2x ink containment, rather than only changing the maximum slider value.


## Selectable pop-up layout (1.13.0)

Settings → General → Appearance → Menu layout chooses Standard (the default) or Compact. Density is stored independently from the Classic/Liquid Glass background and transparency. Switching it updates the retained pop-up content without restarting the app. Section visibility, order, favorites and battery-summary preferences are shared between layouts.

Compact rows show a single summary line in one grouped card. Clicking the entire row reveals the existing detail controls; system-settings links move inside the expanded section. Volume reuses the same slider/mute interaction and feedback logic. Network details retain nearby Wi-Fi, and accessory read errors retain recovery actions. Expansion is transient and resets when changing layouts. This option adds no service, timer or polling work.

`PopoverLayoutTests` checks live preference changes, persistence, fallback, full-row volume disclosure, battery-summary visibility, long localized labels and native light/dark rendering. Preview fixtures use isolated preferences and fake data, without changing Wi-Fi or audio output.


## Login-item isolation and disclosure motion (1.13.0)

Launch-at-login status is now read only by an installed app in `/Applications` or the user's `Applications` directory. Test hosts and DerivedData copies must not call `SMAppService.mainApp`, even to read status: the observed macOS login-item record had been redirected to the temporary Debug bundle. Tests inject a fake backend instead. An already-enabled item is re-registered once after the installed executable changes; disabled or approval-pending items are never enabled automatically. Pending approval is shown separately from an enabled toggle, and Settings refreshes status when the app becomes active. Recovery is asynchronous and waits for unregister completion before registering again.

The footer is a 26-point utility bar with a smaller Settings label and an accessible power button for Quit. Disclosure content reveals/fades over 180 ms and chevrons rotate. The height advances only during the active transition, providing intermediate intrinsic sizes to both NSPopover and the top-anchored glass panel; there is no idle animation timer. Incoming telemetry changes do not start disclosure motion. Animations respect the app preference and Reduce Motion. Closing content immediately disables its hit testing; pending height work cancels on rapid toggles or removal.


A live startup sample also showed the main thread blocked inside `IOBluetoothHostController.default()` before the status item could be created. Bluetooth power-state reads now run on a serial utility queue; repeated refresh requests coalesce into one follow-up. A slow system Bluetooth coordinator cannot block launch or menu interaction. Only value snapshots cross back to the main actor. `BluetoothStartupTests` holds the first read to verify that startup returns and the queue remains bounded.


## Optional menu tools and local battery history (unreleased)

Settings → General → Menu options exposes five independent opt-ins, all false by default: wide popup (304 → 360 pt), row highlighting, larger/higher-contrast content text, one expanded main section at a time, and on-demand network diagnostics. Existing layout/material/transparency preferences are retained. Disabling any option restores its original behavior. The one-section rule does not collapse Network when its nested Nearby Networks list opens.

Diagnostics are idle until Check connection is pressed. An ephemeral, cookie/credential/cache-free URLSession requests the small HTTPS test page at www.apple.com, with bounded timeouts and no redirects. A successful response confirms name resolution along that request's route; DNS lookup failures are distinguished, while other failures leave name resolution unconfirmed. This is not a full Internet/VPN leak test. Network changes, section removal, option disablement and real popup closure/invalidation cancel requests and discard late results. No diagnostic timer is installed.

Battery history is always available inside expanded Battery, without an opt-in switch. It records existing internal-battery callbacks at most once per minute, retaining power-source boundaries, with a 1500-sample/24-hour cap. Data is stored only locally, at most every 15 minutes plus power changes and normal app termination. Test stores are in-memory by default. The chart shows six hours and breaks across charging changes or gaps over five minutes. Hourly consumption requires a continuous unplugged hour and a fresh reading; short or interrupted sessions are not extrapolated. History begins with this build; there is no fabricated backfill and no new polling timer.
